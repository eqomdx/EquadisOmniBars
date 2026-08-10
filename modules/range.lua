--[[ Equadis' OmniBars :: range

  How far away the target is, drawn by whichever of three backends this client
  can actually support.

  Vanilla exposes no distance API. Client mods add one, and where they are
  present the readout is a real number of yards; where they are not, the best
  available answer is which of four coarse bands the target sits in. Rather than
  shipping the worst of those everywhere, the backend is probed and the module
  changes shape to match what it can measure:

    precise   UnitXP("distanceBetween", ...) from SuperWoW -- one continuous bar
    action    IsActionInRange(slot) -- one block, lit or not, at true spell range
    bands     CheckInteractDistance -- four segments, exactly one lit

  Every backend reports the same thing, a band from 1 to 4, and precise reports a
  distance alongside it. That single shared reading is what keeps the colouring,
  the class semantics and the panel identical across all three: only the number
  of rectangles differs.

    1  inside the dead zone     2  at its edge
    3  shootable                4  out of range

  Bands 1 and 2 collapse into one for a backend that can measure, because an
  exact distance makes the distinction between "too close" and "only just too
  close" a thing you can read off the bar.
]]--

local OB = EquadisOmniBars

-- ---------------------------------------------------------------------------
-- backends
-- ---------------------------------------------------------------------------

OB.rangeBackends = {}

-- probed in this order, best first
OB.rangeOrder = { "precise", "action", "bands" }

--[[ SuperWoW's UnitXP. Availability is probed exactly the way
     SuperCleveRoidMacros probes it (Init.lua:275) -- a pcall of a query that
     does nothing -- because the function is injected by the client rather than
     declared by an addon, so there is no version or flag to read. ]]--
OB.rangeBackends.precise = {
    id = "precise",
    name = "Precise",
    segments = 1,

    Available = function(cfg)
        if type(UnitXP) ~= "function" then return false end
        return pcall(UnitXP, "nop", "nop") and true or false
    end,

    Read = function(m, unit)
        local cfg = m:Config()
        local ok, yards = pcall(UnitXP, "distanceBetween", "player", unit)
        if not ok or type(yards) ~= "number" then return nil, nil end
        return m:BandFor(yards), yards
    end,
}

--[[ One action's true spell range, straight from the game. For a hunter's Auto
     Shot this beats every heuristic in this file, because it is the same check
     the client makes before refusing the shot -- talents, buffs and the weapon
     all already counted.

     It costs a slot number, which is why it is not the automatic choice: an
     unset slot makes the backend unavailable rather than wrong. ]]--
OB.rangeBackends.action = {
    id = "action",
    name = "Action",
    segments = 1,

    Available = function(cfg)
        if type(IsActionInRange) ~= "function" then return false end
        return (cfg and cfg.actionSlot and cfg.actionSlot > 0) and true or false
    end,

    Read = function(m, unit)
        local result = IsActionInRange(m:Config().actionSlot)

        -- nil means the slot holds nothing that is range checked, which is a
        -- configuration problem rather than a reading. Say nothing.
        if result == nil then return nil, nil end
        if result == 1 then return 3, nil end
        return 4, nil
    end,
}

--[[ Always available, because CheckInteractDistance ships with the client.

     Four bands from three tests, each narrowing the one before:

       (u, 3) duel      ~9.9yd    inside the dead zone
       (u, 2) trade    ~11.1yd    its edge
       (u, 1) inspect    ~28yd    shootable
       none                       out of range

     A nil return means the unit is not a valid interaction target -- a hostile
     mob is exactly that -- and it must read as "too far for this test", never as
     an error. Treating nil as a failure would make the whole readout blank on
     precisely the targets it exists for. ]]--
OB.rangeBackends.bands = {
    id = "bands",
    name = "Bands",
    segments = 4,

    --[[ The yardages those three indices are believed to correspond to. The live
         path never needs a number -- it asks the client -- so these exist only to
         drive the preview, and they are the one place to correct if Turtle turns
         out to have retuned them. If indices 2 and 3 stop being distinguishable
         the band count drops to three and this list is what says so. ]]--
    edges = { 9.9, 11.11, 28 },

    Available = function(cfg) return true end,

    Read = function(m, unit)
        if CheckInteractDistance(unit, 3) then return 1, nil end
        if CheckInteractDistance(unit, 2) then return 2, nil end
        if CheckInteractDistance(unit, 1) then return 3, nil end
        return 4, nil
    end,
}

-- ---------------------------------------------------------------------------
-- module
-- ---------------------------------------------------------------------------

--[[ A distance does not change fast enough to be worth reading every frame, and
     the precise backend crosses into the client mod to answer. Polling on a
     fixed interval keeps a tickly module cheap; a target change resets the timer
     so the first reading on a new target is immediate rather than up to a
     tenth of a second stale. ]]--
local POLL = 0.1

local M = OB.RegisterModule({
    id = "range",
    name = "Range",
    slot = "aux",
    priority = 10,
    renders = "segments",
    segments = 4,       -- the most any backend needs; the surplus is parked
    tickly = true,

    defaults = {
        backend = "auto",
        maxRange = 35,
        deadZone = 8,
        showText = true,

        actionSlot = 0,
        capture = false,

        inColor = { 0.25, 0.80, 0.35, 1 },
        nearColor = { 0.95, 0.75, 0.20, 1 },
        outColor = { 0.75, 0.20, 0.20, 1 },
        tickColor = { 1, 1, 1, 0.7 },
        dim = 0.25,
    },

    options = {
        { "Backend", "backend", OB.Enum(
                { "auto", "precise", "action", "bands" },
                { "Automatic", "Precise (UnitXP)", "Action Range", "Bands" }) },
        { "Maximum Range", "maxRange", "slider", 5, 100, 1 },
        { "Dead Zone", "deadZone", "slider", 0, 20, 1 },
        { "Show Yards", "showText", "boolean" },
        { "Watched Action Slot", "actionSlot", "slider", 0, 120, 1 },
        { "Capture Next Action", "capture", "boolean" },
        { "In Range Colour", "inColor", "color", true },
        { "Too Close Colour", "nearColor", "color", true },
        { "Out Of Range Colour", "outColor", "color", true },
        { "Marker Colour", "tickColor", "color", true },
        { "Inactive Opacity", "dim", "slider", 0, 100, 5, 0.01 },
    },

    events = { "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED" },
})

--[[ The always-available backend, until the probe runs. The module's shape is
     read during styling and drawing, both of which can be reached before any
     event has fired, so this field is never nil. ]]--
M.backend = OB.rangeBackends.bands

function M:Config()
    return OB.profile.modules.range
end

-- ---------------------------------------------------------------------------
-- backend selection
-- ---------------------------------------------------------------------------

--[[ The best backend this client can run, or the one the user insisted on.

     A forced choice that cannot run falls back rather than leaving the slot
     blank, and says so once. Silently drawing nothing because a client mod is
     missing is the failure mode that gets reported as "the range bar is
     broken". ]]--
function M:SelectBackend()
    local cfg = self:Config()
    local want = cfg.backend

    if want ~= "auto" then
        local forced = OB.rangeBackends[want]
        if forced and forced.Available(cfg) then return forced, nil end
    end

    for i = 1, table.getn(OB.rangeOrder) do
        local backend = OB.rangeBackends[OB.rangeOrder[i]]
        if backend.Available(cfg) then
            local complaint
            if want ~= "auto" then complaint = want end
            return backend, complaint
        end
    end

    return OB.rangeBackends.bands, nil
end

--[[ Adopt a backend. Its segment count is the module's shape, so a change has to
     re-lay the row out before the next draw. ]]--
function M:Probe()
    local chosen, complaint = self:SelectBackend()

    --[[ The complaint is tracked separately from the backend, because the usual
         way to hit it is to force `precise` on a client that cannot run it --
         and the fallback is then the backend already in use, so keying the
         message off a *change* of backend would say nothing at all. Which is the
         one case where the user is actively waiting to be told something.

         Tracked rather than printed every time, because PLAYER_ENTERING_WORLD
         fires on every loading screen and nobody needs telling twice. ]]--
    if complaint ~= self.complained then
        self.complained = complaint
        if complaint then
            OB.Print("the '" .. complaint .. "' range backend is not available"
                    .. " here -- using " .. chosen.name .. ".")
        end
    end

    if chosen == self.backend then return end
    self.backend = chosen

    if self.frame and self.slotId then
        self:OnStyle(OB.profile.slots[self.slotId])
    end

    OB.SetDirty(self)
end

-- ---------------------------------------------------------------------------
-- reading
-- ---------------------------------------------------------------------------

-- a measured distance placed into the shared band vocabulary
function M:BandFor(yards)
    local cfg = self:Config()

    if yards >= cfg.maxRange then return 4 end
    if cfg.deadZone > 0 and yards < cfg.deadZone then return 1 end
    return 3
end

--[[ Take a reading, or nil when there is nothing to measure against.

     Test mode substitutes a distance rather than a band, so the preview drives
     whichever backend is really in play: on a client with UnitXP it sweeps a
     continuous bar, and on one without it steps through the four bands. Both are
     what that user will actually see. ]]--
function M:Read()
    if OB.testMode then
        local yards = OB.test.range or 0

        if self.backend.segments == 1 then return self:BandFor(yards), yards end

        --[[ A segmented backend has no distance to show, and its bands are not
             the configured ones -- they are the client's fixed thresholds. The
             preview walks those, so a user without a distance API sees the
             readout step through every band it will really produce. ]]--
        local edges = self.backend.edges
        if not edges then return self:BandFor(yards), nil end

        for i = 1, table.getn(edges) do
            if yards < edges[i] then return i, nil end
        end
        return table.getn(edges) + 1, nil
    end

    if not UnitExists("target") then return nil, nil end
    return self.backend.Read(self, "target")
end

function M:OnBind(slot)
    self:Probe()
    self.nextPoll = 0
end

function M:OnEvent()
    if event == "PLAYER_ENTERING_WORLD" then self:Probe() end

    -- both events invalidate the reading, and a target change is the moment a
    -- stale one is actively misleading: it describes somebody else
    self.nextPoll = 0
    OB.SetDirty(self)
end

function M:OnUpdate(now)
    if self.nextPoll and now < self.nextPoll then return end
    self.nextPoll = now + POLL

    local band, yards = self:Read()
    if band == self.band and yards == self.yards then return end

    self.band, self.yards = band, yards
    OB.SetDirty(self)
end

-- ---------------------------------------------------------------------------
-- drawing
-- ---------------------------------------------------------------------------

function M:BandColor(band)
    local cfg = self:Config()
    if band == 4 then return cfg.outColor end
    if band == 3 then return cfg.inColor end
    return cfg.nearColor
end

function M:OnStyle(slot)
    OB.StyleSegments(self.frame, slot, self.backend.segments)
end

local function blank(group, slot)
    for i = 1, group.count do
        local bar = group.bars[i]
        OB.SetBarFill(bar, 0, slot.flip)
        OB.ClearBarText(bar)
        OB.HideBarTicks(bar)
    end
end

function M:OnDraw()
    local cfg = self:Config()
    local slot = OB.profile.slots[self.slotId]
    local group = self.frame

    -- no target, or a backend that could not answer: an empty readout is the
    -- honest one. A stale distance to a target you no longer have is worse.
    if not self.band then
        blank(group, slot)
        return
    end

    if self.backend.segments > 1 then
        for i = 1, group.visible or group.count do
            -- flipping reverses which end the bands read from, not the fill:
            -- a band is either lit or it is not
            local index = i
            if slot.flip then index = (group.visible or group.count) + 1 - i end

            local bar = group.bars[i]
            local color = self:BandColor(index)

            OB.SetBarFill(bar, 1, false)
            if index == self.band then
                OB.SetBarColor(bar, color)
            else
                OB.SetBarColor(bar, color, cfg.dim)
            end
        end
        return
    end

    local bar = group.bars[1]

    --[[ Closer reads as fuller, so the bar drains as the target walks away and
         the moment it empties is the moment the shot stops landing. Without a
         measured distance there is nothing to interpolate, so the block is
         simply full or empty. ]]--
    local fraction = 1
    if self.yards then
        local d = self.yards
        if d > cfg.maxRange then d = cfg.maxRange end
        fraction = 1 - (d / cfg.maxRange)
    elseif self.band == 4 then
        fraction = 0
    end

    OB.SetBarFill(bar, fraction, slot.flip)
    OB.SetBarColor(bar, self:BandColor(self.band))

    if self.yards and cfg.showText then
        bar.center:SetText(OB.Round(self.yards) .. "y")
    else
        bar.center:SetText("")
    end

    --[[ The dead zone edge is a fixed point on the bar, so it is drawn as a
         static tick rather than inferred from the colour change. A hunter
         backing out of the dead zone is watching for the fill to cross this
         line, and a line is a much finer thing to aim at than a hue. ]]--
    if self.yards and cfg.deadZone > 0 and cfg.deadZone < cfg.maxRange then
        local c = cfg.tickColor
        OB.SetBarTick(bar, 1, 1 - (cfg.deadZone / cfg.maxRange), slot.flip,
                c[1], c[2], c[3], c[4] or 1)
    else
        OB.HideBarTicks(bar)
    end
end

-- ---------------------------------------------------------------------------
-- capturing an action
-- ---------------------------------------------------------------------------

--[[ Arming replaces the global UseAction. There is no hooksecurefunc in 1.12, so
     a global is the only join available, and the wrapper calls whatever it
     displaced.

     It is installed the first time capture is armed and never removed. A global
     that another addon may have chained onto since cannot be restored without
     silently unhooking that addon, and a pass-through guarded by one boolean is
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

            OB.Print("range: now watching action slot " .. tostring(slot) .. ".")
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

    capture = function()
        local cfg = M:Config()

        if not cfg.capture then
            M.capturing = false
            return
        end

        installCapture()
        M.capturing = true
        OB.Print("range: press the action you want watched.")
    end,
}

-- ---------------------------------------------------------------------------
-- test mode
--
-- Walk out to well past the configured maximum and back, so every band and both
-- ends of the bar are seen without needing a target.
-- ---------------------------------------------------------------------------

function M:TestStart(now)
    OB.test.range = 0
    OB.test.rangeOut = true
    OB.test.rangeAt = now
end

function M:TestStop()
    self.band, self.yards = nil, nil
    self.nextPoll = 0
end

function M:TestStep(now)
    if (now - (OB.test.rangeAt or 0)) < 0.1 then return end
    OB.test.rangeAt = now

    --[[ Sixty steps, not a round forty, because the band between duel and trade
         range is only about 1.2 yards wide and a coarser sweep steps straight
         over it -- so the preview would never show a band the live readout
         really does produce. ]]--
    local ceiling = self:Config().maxRange + 5
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
