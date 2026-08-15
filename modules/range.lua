--[[ Equadis' OmniBars :: ranged distance check

  Can I hit my target from here, and how far away is it.

  One bar, coloured by state. Five states, each with its own colour:

    in range     the equipped ranged weapon can reach the target
    too close    inside its minimum range -- the hunter dead zone
    too far      past its maximum
    no line of sight  something is in the way (opt in)
    no target    nothing selected

  The question is deliberately about the *equipped weapon* rather than some
  generic interaction distance. A bow, a gun, a wand and a thrown axe do not
  share a range, and vanilla's CheckInteractDistance knows about none of them --
  it answers "could I trade with this person", which is a different question that
  merely happens to be roughly the right size.

  So: read the ranged slot, work out what kind of weapon it holds, and look up
  the range of the auto-attack that weapon uses. What can answer that depends on
  which client mods are loaded, so it is probed best-first:

    precise   a true distance (Nampower's optional GetUnitDistance extension,
              UnitXP, or SuperWoW for friendly units) plus the real min and max
              from Nampower -- every state, and a yardage readout
    spell     Nampower's IsSpellInRange -- the engine's own answer, but boolean
    action    IsActionInRange on a watched action slot -- likewise boolean
    bands     CheckInteractDistance -- always available, always coarse

  The boolean backends cannot tell "too close" from "too far" by themselves,
  because both come back as the same "no". They split it with a melee check:
  unable to shoot *and* within melee reach means you are standing on top of the
  target, which is the dead zone.

  One warning for whoever reads this next. **Do not treat UnitPosition as an
  exact hostile-distance API.** SuperWoW deliberately exposes coordinates for
  friendly units only. UnitXP was loaded on this installation when hostile
  yardage worked, but has since been disabled. Stock Nampower gives the hostile
  in/out answer; a Nampower build exposing GetUnitDistance supplies the exact
  hostile number without UnitXP.
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
     not an error, and not a range either: with no ranged attack the bar hides
     entirely rather than advertising a fallback it invented. ]]--
--[[ Candidates, in the order they are tried. The player has exactly one of each
     row and which one depends on the class, not on the weapon.

     This is the correction that mattered most: a hunter with a gun fires **Auto
     Shot**; a warrior with the same gun fires **Shoot Gun**, which is a different
     spell with a different range -- 8-30 against Auto Shot's 8-35. Mapping every
     bow, gun and crossbow to Auto Shot gave every non-hunter a range five yards
     too long and, on a client that could answer, a hunter's numbers outright. It
     read as in range at forty yards with a gun that stops at thirty. ]]--
local weaponSpell = {
    ["Bows"] = { "Auto Shot", "Shoot Bow" },
    ["Guns"] = { "Auto Shot", "Shoot Gun" },
    ["Crossbows"] = { "Auto Shot", "Shoot Crossbow" },
    ["Thrown"] = { "Throw" },
    ["Wands"] = { "Shoot" },
}

--[[ Ranges to assume when nothing can be asked for the real ones:
     { minimum, maximum }.

     Keyed by **spell**, not by weapon, because that is the thing the range
     belongs to. Auto Shot and Shoot Gun fire out of the same gun and do not
     reach the same distance, and keying this by "Guns" made that impossible to
     express.

     These are the classic vanilla numbers and they are **assumptions**. Nampower
     supersedes every one with the client's own DBC values, so they only matter on
     an install without it -- but they matter a lot there, because without a
     minimum the dead zone cannot exist and a hunter standing on top of a mob
     would read as in range while unable to shoot.

     If Turtle has retuned any of this, here is the one place to correct it. ]]--
local spellRange = {
    ["Auto Shot"] = { 8, 35 },
    ["Shoot Bow"] = { 8, 30 },
    ["Shoot Gun"] = { 8, 30 },
    ["Shoot Crossbow"] = { 8, 30 },
    ["Throw"] = { 0, 30 },
    ["Shoot"] = { 0, 30 },
}

--[[ Does the player actually have this spell?

     The **spellbook**, and deliberately not Nampower. `GetSpellIdForName` is a
     DBC lookup: it answers "does this spell exist in the game", which is true of
     Auto Shot for a warrior who will never cast it. Asking it here is what let a
     warrior with a gun keep a hunter's range.

     The walk runs on a probe -- login and inventory changes -- never on a draw. ]]--
local function playerKnows(name)
    if type(GetSpellName) ~= "function" then return false end

    local i = 1
    while true do
        local spell = GetSpellName(i, BOOKTYPE_SPELL)
        if not spell then return false end
        if spell == name then return true end
        i = i + 1
    end
end

-- ---------------------------------------------------------------------------
-- optional client mods
--
-- Every one of these is probed rather than assumed, and every call is pcall'd:
-- they are injected by a DLL, so there is no version to read and a missing one
-- is a call into nothing.
-- ---------------------------------------------------------------------------

--[[ Whether UnitXP_SP3's command dispatcher is present.

     Vanilla already owns the global name `UnitXP`: it is the ordinary experience
     API and it takes a unit token, so `type(UnitXP) == "function"` is true on
     every stock client and means nothing. SP3 replaces that function with a
     dispatcher taking a command name.

     The discriminator has to be a **positive** one, and this is the second
     attempt at it. The first asked the *stock* question -- `UnitXP("player")`,
     concluding "this is the experience API" if a number came back. That was a
     bet on SP3 rejecting a unit token, and it is the wrong bet: SP3 is a
     compatible replacement, so it can perfectly well pass an unrecognised
     command through to the function it displaced. On such a build the probe saw
     a number, concluded "stock", and switched the extension off on a machine
     where it was installed and working.

     So probe on a **shape the experience API cannot produce**. It returns a
     number or nothing; there is no path through it that yields a boolean. A
     boolean back is therefore proof that the dispatcher answered, and it does
     not depend on guessing what SP3 does with input meant for something else. ]]--
function OB.HasUnitXP()
    if type(UnitXP) ~= "function" then return false end

    local ok, sight = pcall(UnitXP, "inSight", "player", "player")
    if ok and type(sight) == "boolean" then return true end

    --[[ An SP3 build too old for inSight. Weaker, so it is second and it is
         guarded: distance from yourself to yourself is exactly zero, and the
         stock API has to have *failed* to answer its own question first. Without
         that guard a client whose UnitXP returns 0 for an unknown unit would be
         read as SP3, and every distance would come back 0 -- a bar stuck on "too
         close" is worse than one that admits it cannot measure. ]]--
    local okX, xp = pcall(UnitXP, "player")
    if okX and type(xp) == "number" then return false end

    local okD, yards = pcall(UnitXP, "distanceBetween", "player", "player")
    return (okD and type(yards) == "number" and yards == 0) and true or false
end

--[[ A true distance in yards, or nil.

     A Nampower build with GetUnitDistance is preferred because it uses the
     object manager already maintained by Nampower and supports hostile units.
     UnitXP remains compatible. SuperWoW's UnitPosition is the final fallback,
     but deliberately returns coordinates for friendly units only. ]]--
function OB.UnitDistance(unit)
    if type(GetUnitDistance) == "function" then
        local ok, yards = pcall(GetUnitDistance, unit)
        if ok and type(yards) == "number" and yards >= 0 then return yards end
    end

    if OB.HasUnitXP() then
        local ok, yards = pcall(UnitXP, "distanceBetween", "player", unit)
        if ok and type(yards) == "number" and yards >= 0 then return yards end
    end

    local function position(token)
        if not token then return nil, nil, nil end

        local ok, x, y, z = pcall(UnitPosition, token)
        if not ok or type(x) ~= "number" or type(y) ~= "number" then
            return nil, nil, nil
        end
        return x, y, z or 0
    end

    if type(UnitPosition) == "function" then
        local x1, y1, z1 = position("player")
        local x2, y2, z2 = position(unit)

        if x1 and x2 then
            local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
            return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        end
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
--[[ Is the unit in line of sight *continuously*, or nil if this client cannot
     tell. The reactive latch below is the fallback and answers a weaker
     question; this is the one that can be polled.

     No stock 1.12 API answers it, so both sources are native extensions:

       IsUnitInSight   a Nampower build extended the way this installation's
                       GetUnitDistance was -- see native/. Preferred, because
                       Nampower is already loaded here and UnitXP_SP3 breaks
                       this client.
       UnitXP inSight  UnitXP_SP3, which SuperCleveRoidMacros uses the same way
                       (Conditionals.lua:7743). A *different* client mod from
                       SuperWoW and from Nampower.

     nil and false are deliberately different: nil is "cannot tell", false is
     "definitely blocked". Treating the first as the second would put a wall in
     front of every target on a client that simply has no opinion. ]]--
function OB.InSight(unit)
    --[[ Named and shaped to match GetUnitDistance: one unit token, and a plain
         boolean rather than a number, so "cannot tell" stays distinguishable
         from "blocked" without a sentinel value. ]]--
    if type(IsUnitInSight) == "function" then
        local ok, sight = pcall(IsUnitInSight, unit)
        if ok and type(sight) == "boolean" then return sight end
    end

    --[[ OB.HasUnitXP, not `type(UnitXP) == "function"`. **Vanilla already owns
         the global name `UnitXP`** -- it is the ordinary experience API -- so the
         plain type check passes on every stock client and this went on to call
         it with "inSight" and two unit tokens. That returned a number, the
         boolean test rejected it, and the whole feature answered "cannot tell"
         forever while looking like it was wired up. ]]--
    if not OB.HasUnitXP() then return nil end

    local ok, sight = pcall(UnitXP, "inSight", "player", unit)
    if not ok or type(sight) ~= "boolean" then return nil end
    return sight
end

--[[ Line of sight without any client mod at all.

     Vanilla will not let you *ask*, but it does tell you: a shot refused for line
     of sight raises UI_ERROR_MESSAGE carrying SPELL_FAILED_LINE_OF_SIGHT, which
     is the same "Target not in line of sight" the client puts on screen. Several
     addons here key off UI_ERROR_MESSAGE the same way (pfUI's autoshift,
     ShaguTweaks' auto-dismount).

     That makes the check **reactive rather than continuous**: it knows only after
     something has been refused, and it cannot know when the obstruction clears.
     So the latch expires, and its *absence is never evidence of sight* -- this
     returns false while blocked and nil otherwise, never true. Reporting "in
     sight" from silence would paint the bar green behind a wall, which is worse
     than not knowing.

     The window is short because it is a guess about the future: it says "you
     were blocked a moment ago", and a moment is all that entitles it to. ]]--
local LOS_WINDOW = 2

--[[ Built on first use rather than at load, so the client's own strings are
     guaranteed to be in place however the files were ordered, and so a locale
     that spells the refusal differently still matches: the comparison is against
     whatever *this* client would print, never against English.

     The literal is the floor, not the answer -- it covers an enUS client that
     somehow lacks the global, and costs nothing anywhere else. ]]--
local losStrings = nil

local function lineOfSightStrings()
    if losStrings then return losStrings end

    losStrings = { ["Target not in line of sight"] = true }

    local names = { "SPELL_FAILED_LINE_OF_SIGHT",
                    "SPELL_FAILED_NOT_IN_LINE_OF_SIGHT",
                    "ERR_NOT_IN_LINE_OF_SIGHT" }

    for i = 1, table.getn(names) do
        local text = getglobal(names[i])
        if type(text) == "string" and text ~= "" then losStrings[text] = true end
    end

    return losStrings
end

function OB.IsLineOfSightError(message)
    if type(message) ~= "string" then return false end
    return lineOfSightStrings()[message] and true or false
end

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
-- the range ladder
--
-- A distance, on a client that has no distance API, out of a call that only
-- answers yes or no.
--
-- IsSpellInRange is boolean, but a boolean against a *known threshold* is one
-- bit of a distance. Ask about a spell that reaches 35 yards and one that
-- reaches 40: 0 then 1 puts the target between them. Enough thresholds and the
-- answer narrows to a band.
--
-- Three facts from the client make it work, all verified with /eqob rangedebug
-- rather than assumed, and the whole idea collapses without any of them:
--
--   * **Asking by id works for spells you do not know.** By name it fails --
--     Nampower says so outright and tells you to use the id instead. A rogue
--     got clean answers for Fireball, Holy Light and Hunter's Mark.
--   * **Targeting restrictions are not applied.** Holy Light, a heal, answered
--     about a hostile mob. So any spell is a plain distance threshold, and the
--     ladder does not need one set for friends and another for enemies.
--   * **It answers about hostile units at all**, which nothing else on a stock
--     client does. CheckInteractDistance returns nil for anything attackable
--     and SuperWoW will not give coordinates for one.
--
-- What it cannot do is produce a number. The output is a band -- "30-35y" --
-- and that is reported honestly rather than dressed up as a reading.
-- ---------------------------------------------------------------------------

--[[ Candidate rungs, as spell ids.

     **None of these is trusted.** Each is looked up in the client's own spell
     data at login and kept only if that data says it is usable; a wrong id
     resolves to nothing and is dropped, and a right id whose range Turtle has
     changed calibrates to the changed value. So the list can be generous, wrong
     in places, and it costs nothing to add to.

     Which is the point: 25, 45 and 50 yard rungs would fill the two gaps this
     list leaves, and finding spells at those ranges is a matter of adding ids
     here rather than of changing any code. ]]--
local LADDER_IDS = {
    -- verified in game, with the ranges the client reported
    2974,   -- Wing Clip, 5
    853,    -- Hammer of Justice, 10
    19503,  -- Scatter Shot, 15
    5782,   -- Fear, 20
    116,    -- Frostbolt, 30
    133,    -- Fireball, 35
    635,    -- Holy Light, 40
    1130,   -- Hunter's Mark, 100

    --[[ Unverified, and here to be tried. Any that resolve to a range the list
         above does not already cover make the ladder finer; any that do not
         resolve, or that duplicate a range already present, are dropped without
         comment. Adding a wrong id here cannot break anything. ]]--
    921,    -- Pick Pocket
    1725,   -- Distract
    20271,  -- Judgement
    5019,   -- Shoot (wand)
    2764,   -- Throw
    3044,   -- Arcane Shot
    136,    -- Mend Pet
    982,    -- Revive Pet
    1064,   -- Chain Heal
    2050,   -- Lesser Heal
    6197,   -- Eagle Eye
    6196,   -- Far Sight
}

--[[ Build the ladder from the client's own spell data.

     Run once, at login. Two filters, and the first is the one that matters:

     **A rung must have no minimum range.** Charge reads "out of range" both past
     25 yards and inside 8, so it is not one threshold but two, and a search that
     assumed the answers were ordered would walk straight past the target. Its id
     is in the candidate list deliberately, so that this filter is exercised
     rather than trusted.

     The second is housekeeping: one rung per distinct maximum, because two
     spells that reach the same distance ask the same question twice. ]]--
function OB.BuildRangeLadder()
    local rungs = {}

    if type(GetSpellRecField) ~= "function" then return rungs end
    if type(GetSpellRangeData) ~= "function" then return rungs end
    if type(IsSpellInRange) ~= "function" then return rungs end

    local seen = {}

    for i = 1, table.getn(LADDER_IDS) do
        local id = LADDER_IDS[i]

        local okIndex, index = pcall(GetSpellRecField, id, "rangeIndex")
        if okIndex and index then
            local okRange, minRange, maxRange = pcall(GetSpellRangeData, index)

            if okRange and type(maxRange) == "number" and maxRange > 0
                    and (minRange or 0) == 0 and not seen[maxRange] then
                seen[maxRange] = true
                table.insert(rungs, { id = id, max = maxRange })
            end
        end
    end

    table.sort(rungs, function(a, b) return a.max < b.max end)
    return rungs
end

--[[ Narrow the target's distance to a band, as `low, high`.

     `high` is nil past the longest rung -- "further than we can ask", which is
     an honest answer and a different one from any band.

     A binary search rather than a walk: eight rungs cost three calls instead of
     eight, and each call crosses into a client mod. The invariant is the usual
     one -- everything below `low` has answered "in range", everything at or
     above `high` has answered "out of range" -- and it holds only because the
     no-minimum filter above guarantees the answers are ordered. ]]--
function OB.LadderBand(rungs)
    local count = table.getn(rungs)
    if count == 0 then return nil, nil end

    local lo, hi = 1, count

    while lo < hi do
        local mid = math.floor((lo + hi) / 2)

        local ok, result = pcall(IsSpellInRange, rungs[mid].id, "target")
        if not ok or result == nil or result == -1 then return nil, nil end

        if result == 1 then hi = mid else lo = mid + 1 end
    end

    --[[ `lo` is now the shortest rung that reaches. One confirming call, because
         the loop never tests the final candidate: with every rung answering
         "out of range" the search converges on the longest one without ever
         having asked it. ]]--
    local ok, result = pcall(IsSpellInRange, rungs[lo].id, "target")
    if not ok or result == nil or result == -1 then return nil, nil end

    -- past everything we can ask about
    if result ~= 1 then return rungs[count].max, nil end

    if lo == 1 then return 0, rungs[1].max end
    return rungs[lo - 1].max, rungs[lo].max
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

    --[[ Asked about the **target** whenever there is one.

         It used to ask only about "player", and that is a question every client
         answers yes to: you are always friendly to yourself, so SuperWoW's
         friendly-only UnitPosition satisfied it. The backend was then selected,
         declined for every hostile unit, and the cascade quietly carried the
         state on a weaker backend that has no yardage to give. The bar looked
         chosen-and-working while the number it exists to show appeared on
         friendly targets only -- which is exactly what was reported.

         "player" remains the fallback because Probe runs with no target, and a
         capability question has to be answerable then too. ]]--
    Available = function(m)
        if UnitExists("target") then return OB.UnitDistance("target") ~= nil end
        return OB.UnitDistance("player") ~= nil
    end,

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

    --[[ A spell **name** is enough. This used to demand `spellId`, which only
         exists when GetSpellRecField and GetSpellRangeData both answer -- a
         different, newer part of Nampower than IsSpellInRange itself. So an
         install with the range check but not the range *data* never used it, fell
         all the way to CheckInteractDistance, and reported every hostile target
         as out of range, because CheckInteractDistance cannot see one.

         IsSpellInRange takes a name or an id, so the id is a bonus rather than a
         requirement. Needing a strictly newer API than the one you are about to
         call is the shape of mistake to watch for. ]]--
    Available = function(m)
        return type(IsSpellInRange) == "function" and m.spell ~= nil
    end,

    Read = function(m)
        local ok, result = pcall(IsSpellInRange, m.spellId or m.spell, "target")
        if not ok or result == nil or result == -1 then return nil, nil end
        if result == 1 then return "inrange", nil end
        return closeOrFar(m), nil
    end,
}

--[[ The auto-attack's own action button, found rather than configured -- see
     M:FindActionSlot. Weaker than the spell check only because it depends on the
     attack being on a bar at all, and stronger than bands because 1.12's
     IsActionInRange honours a minimum range: pfUI's hunter bar swaps pages on
     exactly that. ]]--
OB.rangeBackends.action = {
    id = "action",
    name = "Action Range",

    Available = function(m)
        if type(IsActionInRange) ~= "function" then return false end
        return (m.actionSlot and m.actionSlot > 0) and true or false
    end,

    Read = function(m)
        local result = IsActionInRange(m.actionSlot)

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

        --[[ Nothing answered. For a friendly target that genuinely means far;
             for anything you can attack it means CheckInteractDistance cannot
             see it at all, which is true of every hostile mob in the game.

             Both still read as "too far", because there is no better answer to
             give -- but the second case is a capability gap rather than a
             reading, and saying so once is the difference between "this addon is
             broken on mobs" and "this needs Nampower". ]]--
        if UnitCanAttack("player", "target") then m.blindToHostiles = true end
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

--[[ The ladder's own, slower cadence. A band costs three or four calls into a
     client mod and only changes when a five-yard rung is crossed, so it does not
     need the colour's ten-a-second. ]]--
local LADDER_POLL = 0.25

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

        --[[ Off, because it needs UnitXP SP3 and most installs do not have it.
             Switching it on without that says so once rather than doing nothing
             quietly -- a setting that appears to work and does not is worse than
             one that is honestly unavailable. ]]--
        losCheck = false,

        inRangeColor = { 0.20, 0.80, 0.25, 1 },
        tooCloseColor = { 0.95, 0.55, 0.10, 1 },
        tooFarColor = { 0.80, 0.20, 0.20, 1 },

        --[[ Violet, because it has to be unmistakably not-red: too far and no
             line of sight are different problems with different fixes, and the
             colour is the only thing telling them apart. ]]--
        noLosColor = { 0.55, 0.35, 0.85, 1 },

        --[[ #1f1f1f, a dark grey that is unmistakably *on*.

             This used to be fully transparent, which hid the bar outright and
             read as the feature being broken: the first thing anyone does after
             enabling a bar is look for it, and with no target selected there was
             nothing to find. A drawn placeholder answers that -- the bar is here,
             it is working, it has nothing to say yet.

             Any visible opacity switches OnDraw from hiding to drawing, so
             taking the alpha back to 0 still hides it for anyone who preferred
             that. ]]--
        noTargetColor = { 0.12, 0.12, 0.12, 1 },

    },

    options = {
        { "Backend", "backend", OB.Enum(
                { "auto", "precise", "spell", "action", "bands" },
                { "Automatic", "Precise Distance", "Spell Range",
                  "Action Range", "Bands" }) },
        { "In Range Color", "inRangeColor", "color", true },
        { "Too Close Color", "tooCloseColor", "color", true },
        { "Too Far Color", "tooFarColor", "color", true },
        { "No Line Of Sight Color", "noLosColor", "color", true },
        { "No Target Color", "noTargetColor", "color", true },
        { "Show Yards", "showText", "boolean" },
        { "Check Line Of Sight", "losCheck", "boolean" },
        { "Fallback Maximum Range", "maxRange", "slider", 5, 100, 1 },
        { "Fallback Dead Zone", "deadZone", "slider", 0, 20, 1 },
    },

    --[[ Nothing from a client mod is listed. Every one is expected to be missing
         on some install -- that is the entire reason there are four backends --
         so requiring one would make a working addon report a failure. ]]--
    requires = { "CheckInteractDistance", "IsActionInRange", "UnitExists",
                 "GetInventoryItemLink", "GetItemInfo" },

    events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        "UI_ERROR_MESSAGE",
        "UNIT_INVENTORY_CHANGED",
        "ACTIONBAR_SLOT_CHANGED",
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

    --[[ Which auto-attack this weapon fires *for this player*. A hunter with a
         gun fires Auto Shot; a warrior with the same gun fires Shoot Gun, and
         they do not reach the same distance. The candidates are tried in order
         and the first the player actually has wins.

         A relic, an idol or a totem matches no row at all: no ranged attack, so
         the configured fallback stands and the bar becomes a plain distance
         readout. ]]--
    local candidates = weaponSpell[subtype]
    if not candidates then return end

    for i = 1, table.getn(candidates) do
        if playerKnows(candidates[i]) then
            self.spell = candidates[i]
            break
        end
    end

    --[[ Nothing matched, which means a client that can answer neither question:
         no Nampower and no readable spellbook. Assume the last candidate -- the
         non-hunter one, which is both the commoner case and the shorter range,
         so a wrong guess errs towards saying "too far" rather than promising a
         shot that will not fire. ]]--
    if not self.spell then self.spell = candidates[table.getn(candidates)] end

    --[[ Three sources, weakest first, each overwriting the last. The assumed
         range beats the configured one because knowing which spell is real
         information; the engine's own numbers beat both because they are not a
         guess at all. ]]--
    local assumed = spellRange[self.spell]
    if assumed then self.minRange, self.maxRange = assumed[1], assumed[2] end

    local minRange, maxRange, spellId = OB.SpellRange(self.spell)
    if minRange then
        self.minRange, self.maxRange = minRange, maxRange
        self.spellId = spellId
    end

    self.actionSlot = self:FindActionSlot()
end

--[[ Which action bar slot holds this player's ranged auto-attack, or nil.

     This used to be two settings -- a 0-120 slider and a "capture the next
     action you press" arming switch -- and neither survived contact with the
     game. The slider asked for a number nobody can look up: action slots are not
     the numbers on your bars, and there is no screen anywhere that shows them.
     The capture replaced the global `UseAction`, which only catches a press if
     every bar addon in the chain still calls the global at press time; a bar
     replacement that took its own reference at load simply never reaches ours.

     Both were asking the user to supply something the addon already knows. The
     auto-attack's name is worked out just above, so the slot can be found by
     looking for it -- no configuration, nothing to get wrong, and nothing on the
     panel.

     Read by tooltip, because 1.12 has no GetActionSpell -- through the addon's
     own hidden tooltip rather than the player's, which would flicker on screen
     a hundred and twenty times. Scanning that many slots is affordable here and
     only here: this runs on login and on inventory changes, never on a draw. ]]--
function M:FindActionSlot()
    if not self.spell then return nil end
    if type(HasAction) ~= "function" then return nil end

    local tip = OB.ScanTooltip()
    if type(tip.SetAction) ~= "function" then return nil end

    for slot = 1, 120 do
        if HasAction(slot) and pcall(tip.SetAction, tip, slot) then
            if OB.ScanLine(1) == self.spell then return slot end
        end
    end

    return nil
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

    -- built from the client's own spell data, so a login is the moment to do it
    self.ladder = OB.BuildRangeLadder()

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

--[[ The current state, and a distance when one can be measured.

     **A backend that cannot answer must not read as "no target".** They were the
     same nil, and that is the whole of this bug: the moment the preferred backend
     declined for a particular target -- IsSpellInRange answering -1, UnitPosition
     answering nothing for that unit -- the bar fell to the no-target colour while
     something was plainly targeted.

     So a decline falls through to the weaker backends rather than giving up.
     `bands` is always available and always answers, so a target always produces a
     state; nil now means only what it says.

     Which backend actually answered is worth knowing, so the self-test can say
     when the preferred one is quietly never used. ]]--
function M:Read()
    if OB.testMode then
        --[[ nil range is the preview's no-target phase, which exists so the
             fourth colour is visible without dropping target. ]]--
        local yards = OB.test.range
        if not yards then return nil, nil end

        if (self.minRange or 0) > 0 and yards < self.minRange then
            return "tooclose", yards
        end
        if self.maxRange and yards > self.maxRange then return "toofar", yards end
        return "inrange", yards
    end

    if not UnitExists("target") then
        self.answered = nil
        return nil, nil
    end

    --[[ Asked only when it can answer *this* target. The preferred backend is
         chosen once, at login, and whether it can measure a given unit is not a
         property of the client -- it is a property of the unit. A client with
         SuperWoW and nothing else picks `precise` from a standing start and then
         cannot touch a single hostile mob, so calling it first was a wasted trip
         through a client mod ten times a second, and it left the readout
         reporting a backend that never once answered. ]]--
    local state, yards
    if self.backend.Available(self) then
        state, yards = self.backend.Read(self)
    end

    if state then
        self.answered = self.backend
    else
        for i = 1, table.getn(OB.rangeOrder) do
            local backend = OB.rangeBackends[OB.rangeOrder[i]]
            if backend ~= self.backend and backend.Available(self) then
                state, yards = backend.Read(self)
                if state then
                    self.answered = backend
                    break
                end
            end
        end
    end

    if not state then
        self.answered = nil
        return nil, nil
    end

    --[[ **The yard count is a separate question from the state**, and it is asked
         separately.

         It used to come only from whichever backend produced the state, so a
         client that could measure the distance perfectly well showed no number
         whenever the engine's boolean check happened to answer first -- and the
         boolean check is the *preferred* backend on any Nampower install. The
         readout was blank on exactly the targets Nampower is best at. Asking
         here means an exact source is used wherever it exists, whatever decided
         the colour. ]]--
    if not yards then yards = OB.UnitDistance("target") end

    --[[ Failing an exact source, narrow it to a band.

         Deliberately last, and deliberately not a backend. The ladder is a
         *distance* source, not a state source: the state is already correct
         everywhere -- Nampower's check on the equipped weapon accounts for the
         target's combat reach and the weapon's own minimum, which no
         reconstruction from rungs would match -- and the only thing missing was
         a number. Keeping the two apart means the ladder cannot make a working
         colour worse.

         Cleared when an exact source answered, so the two can never both be on
         screen claiming different things.

         Measured on its own slower clock. Each band costs three or four calls
         into a client mod, and at the ten-a-second the colour is read that is
         forty; a band only changes when you cross a rung five yards away, so
         asking that often buys nothing. A target change resets the clock, so the
         first reading on a new target is still immediate. ]]--
    if yards or not self:Config().showText or not self.ladder then
        self.bandLow, self.bandHigh = nil, nil

    elseif not self.nextLadder or GetTime() >= self.nextLadder then
        self.nextLadder = GetTime() + LADDER_POLL
        self.bandLow, self.bandHigh = OB.LadderBand(self.ladder)
    end

    --[[ A hostile target with a state but no number is its own complaint, and a
         different one from having no state at all.

         The client this was diagnosed on proves the case exists and is not rare:
         Nampower answers the range question for mobs perfectly well, so the
         colour is right, while every source of an exact yard count is either
         absent or friendly-only. Saying "range does not work on hostiles" there
         would be wrong; saying nothing leaves someone watching a label that is
         blank on the only targets they care about. ]]--
    if not yards and not self.bandLow and self:Config().showText
            and UnitCanAttack("player", "target") then
        self:WarnNoHostileYardage()
    end

    --[[ Line of sight overrides everything: a target you cannot see is one you
         cannot shoot, whatever the distance says. Applied after the backends
         rather than inside them so it holds for all four.

         Only when the client can actually tell. A nil answer means "no opinion",
         not "blocked" -- see OB.InSight. ]]--
    --[[ Its own state and its own colour, rather than folded into "too far".

         They are different problems with different fixes: too far means walk
         closer, no line of sight means step around the thing in the way. Painting
         both red tells you to do the wrong one half the time -- and at the moment
         you are standing well inside range wondering why nothing is firing, that
         is exactly the half you needed. ]]--
    if self:Config().losCheck then
        if self:Sight() == false then return "nolos", yards end
        if not OB.HasUnitXP() then self:WarnLineOfSightIsReactive() end
    end

    if self.blindToHostiles then self:WarnBlindToHostiles() end

    return state, yards
end

--[[ Can the player see the target: true, false, or nil for "cannot tell".

     Two sources that answer in different shapes. UnitXP is continuous and can
     say yes, so it is asked first and its answer stands. The reactive latch can
     only ever say no, so it is the fallback and never contradicts a real yes. ]]--
function M:Sight()
    local sight = OB.InSight("target")
    if sight ~= nil then return sight end

    if self.losBlockedAt and (GetTime() - self.losBlockedAt) < LOS_WINDOW then
        return false
    end

    return nil
end

--[[ Said once per session, not once per frame: both of these are conditions of
     the client rather than events, so they are true continuously and a message
     per reading would be ten a second. ]]--
--[[ Not a failure -- the check works without any client mod. But it works
     *reactively*, and a user who expects a bar that turns colour the moment they
     step behind a pillar deserves to be told once that it will not: nothing in
     vanilla can be asked about line of sight, so the only signal is the refusal
     that comes back after a shot has already been attempted. ]]--
function M:WarnLineOfSightIsReactive()
    if self.warnedLos then return end
    self.warnedLos = true

    OB.Print("line of sight is reactive on this client: the bar turns only after"
            .. " a shot is refused for it, and clears a couple of seconds later."
            .. " Only a native |cff69ccf0IsUnitInSight|r can make it continuous.")
end

function M:WarnBlindToHostiles()
    self.blindToHostiles = nil
    if self.warnedHostile then return end
    self.warnedHostile = true

    OB.Print("nothing on this client can range check a hostile target."
            .. " Nampower covers it, as does putting your ranged attack on an"
            .. " action bar.")
end

--[[ Said once, and only about the yard count.

     Deliberately not phrased as a fault: the bar is doing the thing it exists
     for. `native/` holds the Nampower patch that supplies the missing call, so
     the message names the fix rather than the failure. ]]--
function M:WarnNoHostileYardage()
    if self.warnedYardage then return end
    self.warnedYardage = true

    OB.Print("the distance colour works on hostile targets, but no exact yard"
            .. " count is available for them here -- that needs Nampower's"
            .. " |cff69ccf0GetUnitDistance|r or UnitXP_SP3. SuperWoW measures"
            .. " friendly units only.")
end

function M:OnBind(slot)
    self:Probe()
    self.nextPoll = 0
end

function M:OnEvent()
    if event == "UI_ERROR_MESSAGE" then
        --[[ Every refused action arrives here -- out of range, facing the wrong
             way, not enough rage, a dozen more -- so anything that is not the
             line of sight refusal is none of this module's business and must not
             cost it a re-read. ]]--
        if not OB.IsLineOfSightError(arg1) then return end
        self.losBlockedAt = GetTime()

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 and arg1 ~= "player" then return end
        self:Probe()

    elseif event == "PLAYER_ENTERING_WORLD" then
        self:Probe()

        --[[ And queue a second sweep a moment later, unconditionally.

             Probe scans the bars immediately, which is the run most likely to
             see a half-built bar. Relying on ACTIONBAR_SLOT_CHANGED to correct
             it only works if a button *subsequently* moves -- so a login that
             failed and then sat still never looked again, which is a slot found
             on one session and missing on the next with nothing changed in
             between. ]]--
        self.actionScanDue = true
        self.lastActionScan = nil

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        --[[ Marked, not scanned. Two reasons, and both are about when this
             fires: it arrives once per button while the bars populate at login,
             so scanning here would run the 120-slot sweep dozens of times in a
             second; and the sweep run *during* that populate is the one that
             finds nothing, which is why the slot was found on one session and
             not the next. Deferring to the next tick lets the bars settle. ]]--
        self.actionScanDue = true
        return

    elseif event == "PLAYER_TARGET_CHANGED" then
        --[[ The latch is about one target. Carrying it across a target change
             would paint the new one blocked for the rest of the window on the
             strength of a refusal that had nothing to do with it. ]]--
        self.losBlockedAt = nil

        -- likewise the band, which describes a distance to somebody else
        self.nextLadder = nil
        self.bandLow, self.bandHigh = nil, nil
    end

    -- every event that gets this far invalidates the reading, and a target
    -- change is the moment a stale one is actively misleading: it describes
    -- somebody else
    self.nextPoll = 0
    OB.SetDirty(self)
end

-- how long the action bars are given to settle before the slot sweep re-runs
local ACTION_RESCAN = 2

function M:OnUpdate(now)
    if self.nextPoll and now < self.nextPoll then return end
    self.nextPoll = now + POLL

    --[[ The deferred sweep, collapsed into one run however many buttons moved.
         Bounded on both sides: it cannot run more than once per window, and it
         only runs at all when something actually changed. ]]--
    if self.actionScanDue and now > (self.lastActionScan or 0) + ACTION_RESCAN then
        self.actionScanDue = nil
        self.lastActionScan = now
        self.actionSlot = self:FindActionSlot()
    end

    --[[ Read sets the band as a side effect, so it is snapshotted here and
         compared like the other two. Without that a band that changed while the
         state and the exact yardage did not would never reach the screen. ]]--
    local state, yards = self:Read()
    local low, high = self.bandLow, self.bandHigh

    if state == self.state and yards == self.yards
            and low == self.shownLow and high == self.shownHigh then
        return
    end

    self.state, self.yards = state, yards
    self.shownLow, self.shownHigh = low, high
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
    if state == "nolos" then return cfg.noLosColor end
    return cfg.noTargetColor
end

--[[ Text has two independent jobs, matching the swing bars:

       left    the exact current distance
       right   the equipped attack's complete good range, in brackets

     An exact source fills the left side with a number. Failing that the ladder
     fills it with a **band**, and the band is written as a band -- "30-35y" --
     because it is one. Rounding it to a midpoint would fit the label better and
     claim a precision that was never measured, and the whole reason the ladder
     exists is that this client cannot measure. The two are never both present:
     Read clears the band whenever an exact source answered.

     Past the longest rung there is no upper bound to give, so it reads "100+y". ]]--
function M:YardsText()
    if self.yards then return tostring(OB.Round(self.yards)) .. "y" end

    if self.bandLow and self.bandHigh then
        return tostring(OB.Round(self.bandLow)) .. "-"
                .. tostring(OB.Round(self.bandHigh)) .. "y"
    end
    if self.bandLow then return tostring(OB.Round(self.bandLow)) .. "+y" end

    return ""
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
    --[[ No ranged attack at all: the bar goes, whatever is targeted.

         A warrior with an empty ranged slot, or a paladin, shaman or druid with
         a relic in it, has nothing that can be in or out of range -- so "can I
         hit my target from here" has no answer rather than a pessimistic one.

         It used to fall back to the configured range instead and advertise it,
         which is where a warrior holding no gun got told `[8-90y]`: a confident
         interval describing a weapon that did not exist. Constraint 24 -- a bar
         with nothing to draw hides itself. ]]--
    if not self.spell then
        OB.SetBarShown(self, false)
        return
    end

    if not self.state and (color[4] or 1) <= 0 then
        OB.SetBarShown(self, false)
        return
    end

    OB.SetBarShown(self, true)

    --[[ **Always full.** The colour is the entire reading, and a bar that is
         sometimes a block of colour and sometimes a partial fill is two readouts
         wearing one rectangle -- you end up asking whether the bar is short
         because the target is far or because the reading failed.

         An earlier draft drained the fill in proportion to distance. It looked
         informative and it was not: at the exact moment the answer matters --
         crossing in or out of range -- the fill is at its smallest and the
         colour has already told you. So the fill carries nothing and the whole
         bar carries the state.

         The yardage and good range use the left/right text pair, just like the
         swing timer and weapon speed. ]]--
    OB.SetBarFill(bar, 1, slot.flip)
    OB.SetBarColor(bar, color)

    --[[ One piece of text, and only when there is a real live distance to put in
         it. There used to be a second, `[8-90y]`, spelling out the equipped
         attack's whole good range on the other side.

         It went because it was the wrong shape of fact. A static interval next to
         a live counter reads as though both are measurements, and without a live
         counter -- which is every stock install, since no vanilla API and no
         loadable client mod here gives an exact distance to a *hostile* unit --
         it is the only number on the bar, and it never changes. A number that
         never changes on a bar whose whole job is to change is worse than no
         number: it invites you to read it as the answer. The colour is the
         answer. ]]--
    local yardsText = ""
    if cfg.showText then yardsText = self:YardsText() end

    bar.left:SetText("")
    bar.right:SetText("")
    bar.center:SetText(yardsText)

    -- the dead zone edge used to be ticked, marking where a draining fill would
    -- cross it. With nothing draining there is no crossing to mark.
    OB.HideBarTicks(bar)
end

--[[ The fallback ranges feed ScanWeapon, so changing one has to re-scan before
     it means anything. Probe re-runs the scan and then re-picks the backend. ]]--
M.onChange = {
    backend = function() M:Probe() end,
    maxRange = function() M:Probe() end,
    deadZone = function() M:Probe() end,
}

-- ---------------------------------------------------------------------------
-- test mode
--
-- Walk out past the maximum, back in to nothing, then drop target for two
-- seconds before starting again.
--
-- The hold is why the preview is worth having: without it the fourth colour is
-- the one you can never see while setting the other three, because seeing it
-- means dropping target and losing the preview you were looking at.
-- ---------------------------------------------------------------------------

local HOLD = 2

function M:TestStart(now)
    OB.test.range = 0
    OB.test.rangeOut = true
    OB.test.rangeHeld = nil
    OB.test.rangeAt = now
end

function M:TestStop()
    self.state, self.yards = nil, nil
    OB.test.rangeHeld = nil
    self.nextPoll = 0
end

function M:TestStep(now)
    --[[ The hold runs on its own clock rather than on the step interval, so its
         length is two seconds however fast the sweep is stepping. ]]--
    if OB.test.rangeHeld then
        if (now - OB.test.rangeHeld) < HOLD then return end

        OB.test.rangeHeld = nil
        OB.test.range = 0
        OB.test.rangeOut = true
        OB.test.rangeAt = now
        return
    end

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
        return
    end

    OB.test.range = OB.test.range - step
    if OB.test.range <= 0 then
        -- back at nothing: drop target for a beat, which is the only way the
        -- no-target colour appears in a preview
        OB.test.range = nil
        OB.test.rangeHeld = now
    end
end
