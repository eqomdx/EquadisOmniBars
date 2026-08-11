--[[ Equadis' OmniBars :: ranged distance check

  Can I hit my target from here, and how far away is it.

  One bar, coloured by state. Four states, each with its own colour:

    in range     the equipped ranged weapon can reach the target
    too close    inside its minimum range -- the hunter dead zone
    too far      past its maximum
    no target    nothing selected

  The question is deliberately about the *equipped weapon* rather than some
  generic interaction distance. A bow, a gun, a wand and a thrown axe do not
  share a range, and vanilla's CheckInteractDistance knows about none of them --
  it answers "could I trade with this person", which is a different question that
  merely happens to be roughly the right size.

  So: read the ranged slot, work out what kind of weapon it holds, and look up
  the range of the auto-attack that weapon uses. What can answer that depends on
  which client mods are loaded, so it is probed best-first:

    precise   a true distance (SuperWoW's UnitPosition, or UnitXP) plus the real
              min and max from Nampower -- every state, and a yardage readout
    spell     Nampower's IsSpellInRange -- the engine's own answer, but boolean
    action    IsActionInRange on a watched action slot -- likewise boolean
    bands     CheckInteractDistance -- always available, always coarse

  The boolean backends cannot tell "too close" from "too far" by themselves,
  because both come back as the same "no". They split it with a melee check:
  unable to shoot *and* within melee reach means you are standing on top of the
  target, which is the dead zone.

  One warning for whoever reads this next. **Do not assume a client mod is
  present because another addon references it.** Phase 2 recorded UnitXP as
  "confirmed present on this install" on the strength of SuperCleveRoidMacros
  calling it; it is not in dlls.txt and never was, so the precise backend never
  ran once and every reading came from `bands` for three versions. Nampower and
  SuperWoW *are* loaded, which is why they are what this file reaches for.
]]--

local OB = EquadisOmniBars

-- ---------------------------------------------------------------------------
-- what is in the ranged slot
-- ---------------------------------------------------------------------------

local RANGED_SLOT = 18

--[[ Weapon subtype -> the auto-attack it fires, keyed by GetItemInfo's sixth
     return. The strings are plural and English; a localised client needs a
     translation here, which is the same debt the druid mana scrape carries and
     which Phase 3's parser work should pay off for both.

     Paladins, shamans and druids carry a relic in this slot rather than a
     weapon, so they match nothing here and have no ranged attack at all. That is
     not an error: the bar falls back to a plain distance readout for them, which
     is still worth having. ]]--
local weaponSpell = {
    ["Bows"] = "Auto Shot",
    ["Guns"] = "Auto Shot",
    ["Crossbows"] = "Auto Shot",
    ["Thrown"] = "Throw",
    ["Wands"] = "Shoot",
}

--[[ Ranges to assume per weapon type when nothing can be asked for the real
     ones: { minimum, maximum }.

     These are the classic vanilla numbers and they are **assumptions**. Nampower
     supersedes every one of them with the client's own DBC values, so they only
     matter on an install without it -- but they matter a lot there, because
     without a minimum the dead zone cannot exist and a hunter standing on top of
     a mob would read as in range while being unable to shoot.

     Knowing the *type* is what makes even a guess worth having: a bow has a dead
     zone and a wand does not, and that much is certain from the slot alone. If
     Turtle has retuned any of this, here is the one place to correct it. ]]--
local weaponRange = {
    ["Bows"] = { 8, 35 },
    ["Guns"] = { 8, 35 },
    ["Crossbows"] = { 8, 35 },
    ["Thrown"] = { 0, 30 },
    ["Wands"] = { 0, 30 },
}

-- ---------------------------------------------------------------------------
-- optional client mods
--
-- Every one of these is probed rather than assumed, and every call is pcall'd:
-- they are injected by a DLL, so there is no version to read and a missing one
-- is a call into nothing.
-- ---------------------------------------------------------------------------

--[[ A true distance in yards, or nil.

     SuperWoW's UnitPosition gives world coordinates, so this is honest
     three-dimensional Pythagoras rather than an approximation. UnitXP answers
     directly where it exists. ]]--
function OB.UnitDistance(unit)
    if type(UnitPosition) == "function" then
        local ok, x1, y1, z1 = pcall(UnitPosition, "player")
        if ok and x1 then
            local ok2, x2, y2, z2 = pcall(UnitPosition, unit)
            if ok2 and x2 then
                local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
                return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
            end
        end
    end

    if type(UnitXP) == "function" then
        local ok, yards = pcall(UnitXP, "distanceBetween", "player", unit)
        if ok and type(yards) == "number" then return yards end
    end

    return nil
end

--[[ A spell's real minimum and maximum range, from Nampower's SpellRange.dbc
     lookup, or nil.

     The minimum is the whole point of going here. Every other source on this
     client throws it away -- SuperCleveRoidMacros' own GetSpellRange returns the
     maximum and discards the minimum -- which is exactly why nothing else can
     draw a dead zone.

     The values are raw DBC, taken before the target's combat reach is added, so
     they disagree with the engine's own boolean check by a yard or two against a
     large target. Good enough to draw with; the boolean is the authority. ]]--
function OB.SpellRange(name)
    if type(GetSpellIdForName) ~= "function" then return nil end
    if type(GetSpellRecField) ~= "function" then return nil end
    if type(GetSpellRangeData) ~= "function" then return nil end

    local ok, id = pcall(GetSpellIdForName, name)
    if not ok or not id then return nil end

    local okIndex, index = pcall(GetSpellRecField, id, "rangeIndex")
    if not okIndex or not index then return nil end

    local okRange, minRange, maxRange = pcall(GetSpellRangeData, index)
    if not okRange or type(maxRange) ~= "number" or maxRange <= 0 then return nil end

    return minRange or 0, maxRange, id
end

-- ---------------------------------------------------------------------------
-- backends
-- ---------------------------------------------------------------------------

OB.rangeBackends = {}
OB.rangeOrder = { "precise", "spell", "action", "bands" }

--[[ Standing inside melee reach while unable to shoot means too close rather
     than too far. The boolean backends have no other way to tell them apart.

     Only when the weapon has a minimum range at all: a wand has none, so being
     unable to shoot with one always means too far. ]]--
local function closeOrFar(m)
    if (m.minRange or 0) > 0 and CheckInteractDistance("target", 3) then
        return "tooclose"
    end
    return "toofar"
end

OB.rangeBackends.precise = {
    id = "precise",
    name = "Precise Distance",

    Available = function(m) return OB.UnitDistance("player") ~= nil end,

    Read = function(m)
        local yards = OB.UnitDistance("target")
        if not yards then return nil, nil end

        if (m.minRange or 0) > 0 and yards < m.minRange then
            return "tooclose", yards
        end
        if m.maxRange and yards > m.maxRange then return "toofar", yards end
        return "inrange", yards
    end,
}

--[[ The engine's own answer, via Nampower. It accounts for the target's combat
     reach and the weapon's minimum range in one call, which no arithmetic here
     would get exactly right. ]]--
OB.rangeBackends.spell = {
    id = "spell",
    name = "Spell Range",

    Available = function(m)
        return type(IsSpellInRange) == "function" and m.spellId ~= nil
    end,

    Read = function(m)
        local ok, result = pcall(IsSpellInRange, m.spellId, "target")
        if not ok or result == nil or result == -1 then return nil, nil end
        if result == 1 then return "inrange", nil end
        return closeOrFar(m), nil
    end,
}

--[[ One watched action's range. Weaker than the spell check only because it
     needs a slot number, and stronger than bands because 1.12's IsActionInRange
     honours a minimum range -- pfUI's hunter bar swaps pages on exactly that. ]]--
OB.rangeBackends.action = {
    id = "action",
    name = "Action Range",

    Available = function(m)
        if type(IsActionInRange) ~= "function" then return false end
        local slot = m:Config().actionSlot
        return (slot and slot > 0) and true or false
    end,

    Read = function(m)
        local result = IsActionInRange(m:Config().actionSlot)

        -- nil means the slot holds nothing that is range checked, which is a
        -- configuration problem rather than a reading. Say nothing.
        if result == nil then return nil, nil end
        if result == 1 then return "inrange", nil end
        return closeOrFar(m), nil
    end,
}

--[[ Always available, because CheckInteractDistance ships with the client, and
     always coarse -- it knows about trading and duelling, not about your bow.

     A nil return means the unit is not a valid interaction target, which every
     hostile mob is, and it must read as "too far for this test" rather than as
     an error. Treating nil as a failure would blank the readout on precisely the
     targets it exists for. ]]--
OB.rangeBackends.bands = {
    id = "bands",
    name = "Bands",

    -- what those indices are believed to be worth in yards. Used only to walk
    -- the preview through every state; the live path never needs a number.
    edges = { 9.9, 11.11, 28 },

    Available = function(m) return true end,

    Read = function(m)
        if CheckInteractDistance("target", 3) then
            if (m.minRange or 0) > 0 then return "tooclose", nil end
            return "inrange", nil
        end

        if CheckInteractDistance("target", 1) then return "inrange", nil end
        return "toofar", nil
    end,
}

-- ---------------------------------------------------------------------------
-- module
-- ---------------------------------------------------------------------------

--[[ A distance does not change fast enough to be worth reading every frame, and
     three of the four backends cross into a client mod to answer. Polling on a
     fixed interval keeps a tickly module cheap; a target change resets the timer
     so the first reading on a new target is immediate. ]]--
local POLL = 0.1

local M = OB.RegisterModule({
    id = "distance",
    name = "Ranged Distance Check",
    bar = "distance",
    renders = "bar",
    tickly = true,

    defaults = {
        backend = "auto",

        --[[ Used only when nothing can supply the weapon's real range: a class
             with a relic in the ranged slot, or a client without Nampower. ]]--
        maxRange = 30,
        deadZone = 0,

        showText = true,
        actionSlot = 0,
        capture = false,

        inRangeColor = { 0.20, 0.80, 0.25, 1 },
        tooCloseColor = { 0.95, 0.55, 0.10, 1 },
        tooFarColor = { 0.80, 0.20, 0.20, 1 },

        --[[ Fully transparent, which hides the bar outright rather than leaving
             an empty trough. Give it any visible opacity and it becomes a drawn
             placeholder instead -- see OnDraw. ]]--
        noTargetColor = { 0, 0, 0, 0 },

    },

    options = {
        { "Backend", "backend", OB.Enum(
                { "auto", "precise", "spell", "action", "bands" },
                { "Automatic", "Precise Distance", "Spell Range",
                  "Action Range", "Bands" }) },
        { "In Range Color", "inRangeColor", "color", true },
        { "Too Close Color", "tooCloseColor", "color", true },
        { "Too Far Color", "tooFarColor", "color", true },
        { "No Target Color", "noTargetColor", "color", true },
        { "Show Yards", "showText", "boolean" },
        { "Fallback Maximum Range", "maxRange", "slider", 5, 100, 1 },
        { "Fallback Dead Zone", "deadZone", "slider", 0, 20, 1 },
        { "Watched Action Slot", "actionSlot", "slider", 0, 120, 1 },
        { "Capture Next Action", "capture", "boolean" },
    },

    --[[ Nothing from a client mod is listed. Every one is expected to be missing
         on some install -- that is the entire reason there are four backends --
         so requiring one would make a working addon report a failure. ]]--
    requires = { "CheckInteractDistance", "IsActionInRange", "UnitExists",
                 "GetInventoryItemLink", "GetItemInfo" },

    events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        "UNIT_INVENTORY_CHANGED",
    },
})

-- the always-available backend, until the probe runs. Styling and drawing can
-- both be reached before any event has fired, so this is never nil.
M.backend = OB.rangeBackends.bands

function M:Config()
    return OB.profile.modules.distance
end

-- ---------------------------------------------------------------------------
-- the weapon
-- ---------------------------------------------------------------------------

--[[ Work out what is in the ranged slot and what its auto-attack can reach.

     Everything downstream keys off this: the backend probe needs `spellId`, and
     three of the four readings need `minRange`. Re-run whenever the inventory
     changes, which is the only thing that can alter the answer. ]]--
function M:ScanWeapon()
    local cfg = self:Config()

    self.weapon, self.spell, self.spellId = nil, nil, nil
    self.minRange, self.maxRange = cfg.deadZone, cfg.maxRange

    local link = GetInventoryItemLink("player", RANGED_SLOT)
    if not link then return end

    local _, _, itemId = string.find(link, "item:(%d+)")
    if not itemId then return end

    -- GetItemInfo answers nil for an item the client has not cached yet, which
    -- is why that is not treated as "no weapon"
    local ok, _, _, _, _, _, subtype = pcall(GetItemInfo, itemId)
    if not ok or not subtype then return end

    self.weapon = subtype
    self.spell = weaponSpell[subtype]

    -- a relic, an idol, a totem: no ranged attack, so the configured fallback
    -- stands and the bar becomes a plain distance readout
    if not self.spell then return end

    --[[ Three sources, weakest first, each overwriting the last. The assumed
         range beats the configured one because knowing the weapon type is real
         information; the engine's own numbers beat both because they are not a
         guess at all. ]]--
    local assumed = weaponRange[subtype]
    if assumed then self.minRange, self.maxRange = assumed[1], assumed[2] end

    local minRange, maxRange, spellId = OB.SpellRange(self.spell)
    if minRange then
        self.minRange, self.maxRange = minRange, maxRange
        self.spellId = spellId
    end
end

-- ---------------------------------------------------------------------------
-- backend selection
-- ---------------------------------------------------------------------------

function M:SelectBackend()
    local cfg = self:Config()
    local want = cfg.backend

    if want ~= "auto" then
        local forced = OB.rangeBackends[want]
        if forced and forced.Available(self) then return forced, nil end
    end

    for i = 1, table.getn(OB.rangeOrder) do
        local backend = OB.rangeBackends[OB.rangeOrder[i]]
        if backend.Available(self) then
            local complaint
            if want ~= "auto" then complaint = want end
            return backend, complaint
        end
    end

    return OB.rangeBackends.bands, nil
end

function M:Probe()
    self:ScanWeapon()

    local chosen, complaint = self:SelectBackend()

    --[[ The complaint is tracked separately from the backend, because the usual
         way to hit it is to force one the client cannot run -- and the fallback
         is then often the backend already in use, so keying the message off a
         *change* of backend would say nothing in the one case where the user is
         waiting to be told something.

         Tracked rather than printed every time, because PLAYER_ENTERING_WORLD
         fires on every loading screen. ]]--
    if complaint ~= self.complained then
        self.complained = complaint
        if complaint then
            OB.Print("the '" .. complaint .. "' distance backend is not available"
                    .. " here -- using " .. chosen.name .. ".")
        end
    end

    self.backend = chosen
    OB.SetDirty(self)
end

-- ---------------------------------------------------------------------------
-- reading
-- ---------------------------------------------------------------------------

function M:Read()
    if OB.testMode then
        local yards = OB.test.range or 0
        if (self.minRange or 0) > 0 and yards < self.minRange then
            return "tooclose", yards
        end
        if self.maxRange and yards > self.maxRange then return "toofar", yards end
        return "inrange", yards
    end

    if not UnitExists("target") then return nil, nil end
    return self.backend.Read(self)
end

function M:OnBind(slot)
    self:Probe()
    self.nextPoll = 0
end

function M:OnEvent()
    if event == "UNIT_INVENTORY_CHANGED" and arg1 and arg1 ~= "player" then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_INVENTORY_CHANGED" then
        self:Probe()
    end

    -- both remaining events invalidate the reading, and a target change is the
    -- moment a stale one is actively misleading: it describes somebody else
    self.nextPoll = 0
    OB.SetDirty(self)
end

function M:OnUpdate(now)
    if self.nextPoll and now < self.nextPoll then return end
    self.nextPoll = now + POLL

    local state, yards = self:Read()
    if state == self.state and yards == self.yards then return end

    self.state, self.yards = state, yards
    OB.SetDirty(self)
end

-- ---------------------------------------------------------------------------
-- drawing
-- ---------------------------------------------------------------------------

function M:StateColor(state)
    local cfg = self:Config()
    if state == "inrange" then return cfg.inRangeColor end
    if state == "tooclose" then return cfg.tooCloseColor end
    if state == "toofar" then return cfg.tooFarColor end
    return cfg.noTargetColor
end

function M:OnStyle(slot)
    OB.SetBarColor(self.frame, self:StateColor(self.state))
end

function M:OnDraw()
    local cfg = self:Config()
    local slot = OB.profile.slots[self.slotId]
    local bar = self.frame

    local color = self:StateColor(self.state)

    --[[ No target and a fully transparent colour: the whole bar goes, background
         included, rather than leaving an empty trough -- which reads as a broken
         bar rather than an absent one.

         Any visible opacity turns it back into a drawn placeholder, which is
         what makes the No Target colour a setting worth having rather than an
         elaborate way of spelling "hidden". ]]--
    if not self.state and (color[4] or 1) <= 0 then
        bar:Hide()
        return
    end

    if slot.show then bar:Show() end

    --[[ **Always full.** The colour is the entire reading, and a bar that is
         sometimes a block of colour and sometimes a partial fill is two readouts
         wearing one rectangle -- you end up asking whether the bar is short
         because the target is far or because the reading failed.

         An earlier draft drained the fill in proportion to distance. It looked
         informative and it was not: at the exact moment the answer matters --
         crossing in or out of range -- the fill is at its smallest and the
         colour has already told you. So the fill carries nothing and the whole
         bar carries the state.

         The yardage still goes in the centre text, where a number belongs. ]]--
    OB.SetBarFill(bar, 1, slot.flip)
    OB.SetBarColor(bar, color)

    if self.yards and cfg.showText then
        bar.center:SetText(OB.Round(self.yards) .. "y")
    else
        bar.center:SetText("")
    end

    -- the dead zone edge used to be ticked, marking where a draining fill would
    -- cross it. With nothing draining there is no crossing to mark.
    OB.HideBarTicks(bar)
end

-- ---------------------------------------------------------------------------
-- capturing an action
-- ---------------------------------------------------------------------------

--[[ Arming replaces the global UseAction. There is no hooksecurefunc in 1.12, so
     a global is the only join available, and the wrapper calls whatever it
     displaced.

     It is installed the first time capture is armed and never removed. A global
     another addon may have chained onto since cannot be restored without
     silently unhooking them, and a pass-through guarded by one boolean is
     cheaper than the bookkeeping needed to try. Someone who never captures never
     has UseAction touched at all. ]]--
local hooked = false

local function installCapture()
    if hooked then return end
    hooked = true

    local previous = UseAction

    UseAction = function(slot, checkCursor, onSelf)
        if M.capturing then
            M.capturing = false

            local cfg = M:Config()
            cfg.actionSlot = slot
            cfg.capture = false

            OB.Print("distance: now watching action slot " .. tostring(slot) .. ".")
            M:Probe()
            OB.Refresh(true)
            OB.RefreshPanel()
        end

        return previous(slot, checkCursor, onSelf)
    end
end

M.onChange = {
    backend = function() M:Probe() end,
    actionSlot = function() M:Probe() end,
    maxRange = function() M:Probe() end,
    deadZone = function() M:Probe() end,

    capture = function()
        local cfg = M:Config()

        if not cfg.capture then
            M.capturing = false
            return
        end

        installCapture()
        M.capturing = true
        OB.Print("distance: press the action you want watched.")
    end,
}

-- ---------------------------------------------------------------------------
-- test mode
--
-- Walk out past the maximum and back, so every state and both ends of the bar
-- are seen without needing a target.
-- ---------------------------------------------------------------------------

function M:TestStart(now)
    OB.test.range = 0
    OB.test.rangeOut = true
    OB.test.rangeAt = now
end

function M:TestStop()
    self.state, self.yards = nil, nil
    self.nextPoll = 0
end

function M:TestStep(now)
    if (now - (OB.test.rangeAt or 0)) < 0.1 then return end
    OB.test.rangeAt = now

    local ceiling = (self.maxRange or 30) + 5
    local step = ceiling / 60

    if OB.test.rangeOut then
        OB.test.range = OB.test.range + step
        if OB.test.range >= ceiling then
            OB.test.range = ceiling
            OB.test.rangeOut = false
        end
    else
        OB.test.range = OB.test.range - step
        if OB.test.range <= 0 then
            OB.test.range = 0
            OB.test.rangeOut = true
        end
    end
end
