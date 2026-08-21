--[[ Equadis' Classic Overhaul :: test run

  Loads the addon into the fake client in tests/wow_stub.lua and drives it.

    luajit tests/run.lua        (from the addon folder)

  These are not unit tests. They boot the real addon, fire real events and read
  the resulting widget state, which is the only kind of test worth writing for
  something whose entire job is to draw the right rectangle at the right time.
]]--

local root = (arg and arg[0] or ""):gsub("[^/\\]*$", "")
if root == "" then root = "./" end
local function path(p) return root .. "../" .. p end

dofile(root .. "wow_stub.lua")

-- ---------------------------------------------------------------------------
-- harness
-- ---------------------------------------------------------------------------

local passed, failed = 0, 0
local failures = {}
local context = ""

local function check(ok, label, detail)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        table.insert(failures, context .. label .. (detail and ("  -- " .. detail) or ""))
    end
end

local function eq(got, want, label)
    check(got == want, label, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local function near(got, want, tol, label)
    local ok = type(got) == "number" and math.abs(got - want) <= tol
    check(ok, label, "got " .. tostring(got) .. ", want ~" .. tostring(want))
end

-- any Lua error inside the addon is a test failure with its message
local function try(label, fn)
    local ok, err = pcall(fn)
    check(ok, label, err)
    return ok
end

-- ---------------------------------------------------------------------------
-- load the addon, in TOC order
-- ---------------------------------------------------------------------------

--[[ **Read from the TOC, not written out again here.**

     This was a hand-kept copy of the load order, and it drifted the first time a
     module was added: `modules/chat.lua` went into the TOC, the game would have
     loaded it, and the suite would not -- so the module was untested while every
     test passed. A second list of the same thing is a second thing to forget.

     The TOC *is* the load order, which is the only reason this is safe: the game
     reads these lines in this sequence, so the harness loading them in the same
     sequence is not an approximation of a login, it is the same list. ]]--
local function tocFiles()
    local out = {}
    local toc = io.open(path("EquadisClassicOverhaul.toc"), "r")
    if not toc then error("cannot read EquadisClassicOverhaul.toc") end

    for line in toc:lines() do
        -- strip whitespace and the trailing CR a Windows checkout leaves
        line = string.gsub(line, "%s+$", "")

        --[[ Directives start with `##` and comments with `#`; everything else
             that names a .lua file is a file to load. Backslashes are the TOC's
             separator and mean nothing to io.open. ]]--
        if string.find(line, "%.lua$") and not string.find(line, "^#") then
            table.insert(out, (string.gsub(line, "\\", "/")))
        end
    end

    toc:close()

    if table.getn(out) < 10 then
        error("the TOC listed " .. table.getn(out) .. " files, which cannot be right")
    end

    return out
end

local files = tocFiles()

local function loadAddon()
    for i = 1, table.getn(files) do
        local chunk, err = loadfile(path(files[i]))
        if not chunk then error("load " .. files[i] .. ": " .. tostring(err)) end
        chunk()
    end
end

--[[ Every simulated character starts from a clean interpreter. The addon builds
     frames and captures state at file scope, so reloading in-process would test
     a second boot on top of the first rather than a fresh login. ]]--
local function boot(class, powerType, opts)
    opts = opts or {}

    --[[ Session facts the addon learns by watching rather than by asking, and a
         boot is a fresh login. `dualWieldSeen` in particular is deliberately
         sticky within a session -- it only ever *stops* the off hand section
         being greyed -- so without clearing it here one character's off hand
         would vouch for the next one's. ]]--
    if EquadisClassicOverhaul then EquadisClassicOverhaul.dualWieldSeen = nil end

    Stub.player.class = class
    Stub.player.localizedClass = class
    Stub.player.powerType = powerType
    Stub.player.name = opts.name or ("Test" .. class)
    Stub.player.power = opts.power or 100
    Stub.player.powerMax = opts.powerMax or 100
    Stub.player.combo = 0
    Stub.player.offSpeed = opts.offSpeed or 1.7
    Stub.player.rangedSpeed = opts.rangedSpeed or 2.9
    Stub.player.buffs = opts.buffs or {}
    Stub.loadedAddons = opts.loadedAddons or {}

    -- everything the range and druid mana modules read from the world
    Stub.player.hasTarget = opts.hasTarget and true or false
    Stub.player.targetDistance = opts.distance or 0
    Stub.player.stats = opts.stats or { 20, 20, 20, 100, 80 }
    Stub.player.spellbook = opts.spellbook or {}

    --[[ Which auto-attack this character knows. Hunters get Auto Shot; everyone
         else with a gun gets Shoot Gun, and the two do not reach the same
         distance -- which is exactly what the distance readout has to tell
         apart. Defaults by class so a test only names it when it cares. ]]--
    if opts.spellNames then
        Stub.player.spellNames = opts.spellNames
    elseif class == "HUNTER" then
        Stub.player.spellNames = { "Auto Shot" }
    else
        Stub.player.spellNames = { "Shoot Bow", "Shoot Gun", "Shoot Crossbow", "Shoot", "Throw" }
    end
    Stub.player.spellCount = opts.spellCount or 0
    Stub.player.talents = opts.talents or {}
    Stub.tooltips = opts.tooltips or {}
    Stub.interactRefuses = false
    Stub.actionRange = opts.actionRange
    Stub.actionBar = opts.actionBar or {}

    --[[ A client mod either injected its API before Lua ran or it did not, so
         each is off unless a test asks for it. Defaulting them *off* is
         deliberate: the addon spent three versions assuming UnitXP was present
         when it was not, and a harness where the good path is always available
         would have hidden that rather than caught it. ]]--
    Stub.unitXPPassthrough = opts.unitXPPassthrough and true or false
    Stub.SetUnitXP(opts.unitXP)
    Stub.SetLineOfSight(opts.lineOfSight)
    Stub.SetNampowerSight(opts.nampowerSight)
    Stub.player.inSight = true
    Stub.player.friendlyTarget = opts.friendlyTarget and true or false
    Stub.SetUnitPosition(opts.unitPosition)
    Stub.SetNampower(opts.nampower)
    Stub.SetNampowerDistance(opts.nampowerDistance)

    --[[ Ranged slot contents, as GetItemInfo would report the subtype. Bows and
         guns fire Auto Shot, wands fire Shoot, and a relic fires nothing -- which
         is what a paladin, shaman or druid has there. ]]--
    --[[ Deliberately *not* the numbers the module assumes for each weapon type.
         Auto Shot here is a Hawk Eye hunter's 9-41 rather than the built-in
         8-35, so a test can tell which of the two sources actually answered --
         identical numbers would let the engine path silently stop working. ]]--
    Stub.spellRanges = opts.spellRanges or {
        ["Auto Shot"] = { 9, 41 },
        ["Shoot"] = { 0, 30 },
        ["Throw"] = { 0, 30 },
    }
    Stub.SetRanged(opts.ranged)

    --[[ Every boot starts from an empty saved-variables table unless a test
         hands one in deliberately. Sharing one across tests looks convenient and
         is not: an assignment made in one section then silently changes what the
         next section boots into. ]]--
    EquadisClassicOverhaulDB = opts.savedVariables or nil

    loadAddon()
    Stub.FireEvent("VARIABLES_LOADED")
    Stub.FireEvent("PLAYER_ENTERING_WORLD")
    Stub.Tick(0.05, 3)

    return EquadisClassicOverhaul
end

-- ---------------------------------------------------------------------------
-- 1. every class boots, and lands on the right occupants
-- ---------------------------------------------------------------------------

--[[ One bar, one module, fixed. The only two that vary by class are the ones
     gated on it: Extras (combo points, so rogues and druids) and Secondary
     Resource (the druid mana estimate). Everything else is the same everywhere,
     which is the whole point of dropping the assignment layer. ]]--
local expected = {
    WARRIOR = { power = 1, extras = nil,           secondary = nil },
    PALADIN = { power = 0, extras = nil,           secondary = nil },
    HUNTER  = { power = 0, extras = nil,           secondary = nil },
    ROGUE   = { power = 3, extras = "combopoints", secondary = nil },
    PRIEST  = { power = 0, extras = nil,           secondary = nil },
    SHAMAN  = { power = 0, extras = nil,           secondary = nil },
    MAGE    = { power = 0, extras = nil,           secondary = nil },
    WARLOCK = { power = 0, extras = nil,           secondary = nil },
    DRUID   = { power = 3, extras = "combopoints", secondary = "druidmana" },
}

local order = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
                "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local geometry   -- captured from the first class, compared against the rest

for i = 1, table.getn(order) do
    local class = order[i]
    local want = expected[class]
    context = class .. ": "

    local OB
    if not try("boots without error", function()
        OB = boot(class, want.power)
    end) then
        break
    end

    eq(OB.class, class, "class detected")

    local function occupant(slot)
        local m = OB.bound[slot]
        return m and m.id or nil
    end

    eq(occupant("resource"), "power", "resource slot holds power")
    eq(occupant("health"), "health", "health slot holds health")
    eq(occupant("mainhand"), "mainhand", "the main hand bar holds the main hand timer")
    eq(occupant("offhand"), "offhand", "the off hand bar holds the off hand timer")
    eq(occupant("ranged"), "ranged", "the ranged bar holds the ranged timer")
    eq(occupant("distance"), "distance", "the distance bar holds the distance readout")
    eq(occupant("extras"), want.extras, "extras occupant")
    eq(occupant("secondary"), want.secondary, "secondary resource occupant")

    -- a bar no module on this class can fill is not offered in the panel at all
    local listed = {}
    local bars = OB.BarsForClass()
    for b = 1, table.getn(bars) do listed[bars[b]] = true end

    check(listed.health and listed.resource, "every class lists the universal bars")
    eq(listed.extras and true or false, want.extras ~= nil,
            "the extras bar is listed only when this class has one")
    eq(listed.secondary and true or false, want.secondary ~= nil,
            "the secondary resource bar likewise")

    -- the whole promise of the slot model: same rectangles everywhere
    local slots = OB.profile.slots
    if not geometry then
        geometry = {}
        for id, s in pairs(slots) do
            geometry[id] = s.x .. "," .. s.y .. "," .. s.w .. "," .. s.h
        end
    else
        local same = true
        for id, s in pairs(slots) do
            if geometry[id] ~= (s.x .. "," .. s.y .. "," .. s.w .. "," .. s.h) then
                same = false
            end
        end
        check(same, "slot geometry matches the other classes")
    end

    -- the resource bar picked up this class's power type and colour
    local power = OB.modules.power
    eq(power.ptype, want.power, "power module adopted the power type")

    local variant = power:VariantTable()
    local fill = power.frame.fill
    check(fill.vertex ~= nil, "resource fill has a colour")
    if fill.vertex then
        near(fill.vertex[1], variant.color[1], 0.001, "resource fill colour matches the variant")
    end

    -- rage does not tick; energy and mana do
    if want.power == 1 then
        check(power.ticker == nil, "rage has no ticker")
    else
        check(power.ticker ~= nil, "ticking resource has a ticker")
    end
end

-- ---------------------------------------------------------------------------
-- 1a. every text mode formats
--
-- Shared by three modules, so "Current / Max" has to mean the same thing on the
-- resource bar, the health bar and a druid's mana estimate.
-- ---------------------------------------------------------------------------

context = "text modes: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

eq(OB.FormatValue(1234, 2200, "none"), "", "none shows nothing")
eq(OB.FormatValue(1234, 2200, "value"), "1234", "value shows the number")
eq(OB.FormatValue(1234, 2200, "percent"), "56%", "percent rounds to whole")
eq(OB.FormatValue(1234, 2200, "max"), "1234/2200", "max shows both")
eq(OB.FormatValue(1234, 2200, "valuepct"), "1234 (56%)", "current with a percentage")
eq(OB.FormatValue(1234, 2200, "maxpct"), "1234/2200 (56%)", "and current over max with one")

-- a zero maximum must not divide by it
eq(OB.FormatValue(0, 0, "percent"), "0%", "a zero maximum reads as zero percent")
eq(OB.FormatValue(0, 0, "maxpct"), "0/0 (0%)", "in every mode that shows one")

-- ---------------------------------------------------------------------------
-- 1b. growing a bar pushes the others away
--
-- Only x and y went through the collision path, so with Allow Bar Overlap off --
-- the setting that exists to say bars must not stack -- dragging a bar was
-- refused while *growing* one silently overlapped its neighbour.
-- ---------------------------------------------------------------------------

context = "resize: "
OB.TogglePanel()

local resizeSlots = OB.profile.slots
eq(OB.profile.allowOverlap, false, "overlap is off by default")

--[[ Asserted on edges, not on the stored coordinate, because the coordinate is
     the bar's *centre*: two centres being far apart says nothing about whether
     the rectangles overlap. ]]--
local function clearOfEachOther()
    local _, _, aboveT, aboveB = OB.EdgesOf(resizeSlots.resource)
    local _, _, belowT, belowB = OB.EdgesOf(resizeSlots.mainhand)
    return belowT <= aboveB
end

local belowBefore = resizeSlots.mainhand.y
check(clearOfEachOther(), "the bars start clear of each other")

OB.panel.bar = "resource"
OB.ApplyOption(OB.optionIndex.slot.h, 40)

eq(resizeSlots.resource.h, 40, "the bar really grew")
check(clearOfEachOther(), "and the bar below was pushed clear rather than overlapped")
check(resizeSlots.mainhand.y < belowBefore, "which means it moved")

-- with overlap allowed, nothing is pushed
OB.profile.allowOverlap = true
local untouched = resizeSlots.mainhand.y
OB.ApplyOption(OB.optionIndex.slot.h, 24)
eq(resizeSlots.mainhand.y, untouched, "allowing overlap leaves the others alone")

-- ---------------------------------------------------------------------------
-- 2. the rendering rules that cost real debugging time
-- ---------------------------------------------------------------------------

context = "render: "
local OB = boot("ROGUE", 3, { power = 50, powerMax = 100 })

local bar = OB.modules.power.frame
eq(bar.width, 200, "resource bar took the slot width")
eq(bar.height, 24, "resource bar took the slot height")

-- fill width and texture crop must come from the same fraction, or the art
-- stretches (HANDOFF 5.2)
OB.SetBarFill(bar, 0.5, false)
eq(bar.fill.width, 100, "half fill is half the bar width")
near(bar.fill.texcoord[2], 0.5, 0.0001, "half fill crops the texture to half")
check(bar.fill.shown, "half fill is shown")

OB.SetBarFill(bar, 1, false)
eq(bar.fill.width, 200, "full fill is the whole bar")
near(bar.fill.texcoord[2], 1, 0.0001, "full fill crops nothing")

OB.SetBarFill(bar, 0, false)
check(not bar.fill.shown, "empty fill is hidden rather than 0 wide")

-- flipped fills anchor right and crop from the other end
OB.SetBarFill(bar, 0.25, true)
eq(bar.fill.width, 50, "flipped quarter fill is a quarter wide")
near(bar.fill.texcoord[1], 0.75, 0.0001, "flipped fill crops from the right")
eq(bar.fill.points[1][1], "TOPRIGHT", "flipped fill anchors to the right edge")

-- out of range fractions clamp rather than overflow
OB.SetBarFill(bar, 5, false)
eq(bar.fill.width, 200, "fraction above 1 clamps")

-- ---------------------------------------------------------------------------
-- 3. the ticker: wrap, do not clamp (HANDOFF 5.5)
-- ---------------------------------------------------------------------------

context = "ticker: "

local seen = {}
for step = 0, 8 do
    OB.DrawSpark(bar, 1000, 2, 1000 + step * 0.5, false)
    local x = bar.spark.points[1][4]
    table.insert(seen, x)
end

near(seen[1], 0, 0.001, "spark starts at the left edge")
near(seen[2], 50, 0.001, "spark is a quarter across at 0.5s")
near(seen[3], 100, 0.001, "spark is halfway at 1.0s")
near(seen[5], 0, 0.001, "spark wraps back to the start at 2.0s")
near(seen[9], 0, 0.001, "spark still wraps two cycles later, never parks")

-- a stale anchor far in the past still sweeps
OB.DrawSpark(bar, 0, 2, 100000.75, false)
near(bar.spark.points[1][4], 75, 0.5, "a stale anchor still produces a live sweep")

-- the sweep mirrors when the slot is flipped
OB.DrawSpark(bar, 1000, 2, 1000.5, true)
eq(bar.spark.points[1][3], "RIGHT", "flipped ticker sweeps from the right")

-- ---------------------------------------------------------------------------
-- 4. the pulse strategy holds its phase when capped
-- ---------------------------------------------------------------------------

context = "pulse: "
local t = { start = 0, period = 2 }
OB.tickers.pulse.Reset(t, 100)
eq(t.start, 100, "reset anchors to now")

--[[ The first gain after a reset anchors the cycle, because there is nothing to
     compare it to yet. From then on there is. ]]--
check(OB.tickers.pulse.Observe(t, 102, 60, 40), "the first gain anchors")
eq(t.start, 102, "and the cycle starts there")

--[[ **Energy does not only arrive on the tick, and a gain that is not the tick
     must not move the phase.**

     A rogue with Vigor gets 2 energy back on every poison application. Each one
     used to re-anchor the cycle, so the sweep restarted mid-beat and the spark
     stopped predicting the one thing it exists to predict -- worst while
     actually fighting, which is the only time anyone watches it. ]]--
check(not OB.tickers.pulse.Observe(t, 102.7, 62, 60),
        "a two-energy refund mid-cycle is not a tick")
eq(t.start, 102, "and leaves the phase exactly where it was")

check(not OB.tickers.pulse.Observe(t, 103.4, 64, 62),
        "nor is the next one")
eq(t.start, 102, "however many of them arrive")

check(OB.tickers.pulse.Observe(t, 104, 84, 64), "a gain on the beat is the tick")
eq(t.start, 104, "and re-anchors the cycle")

-- capped: no gain for four seconds, so the cycle advances by whole periods and
-- the phase stays on the beat rather than restarting off it
check(not OB.tickers.pulse.Observe(t, 108, 100, 100), "no gain is not a tick")
eq(t.start, 108, "capped cycles advance by whole periods")
near((108 - t.start) / t.period, 0, 0.0001, "phase stays on the beat")

--[[ **The desync, which was the roll-forward eating the anchor.**

     `start` is the drawing anchor and rolls forward whenever a period elapses,
     so the sweep keeps running when nothing is observed. Measuring "how long
     since the last tick" from *that* meant the roll happened first: the instant
     the true interval ran a hair over the assumed two seconds -- which it always
     does, between server latency and the frame the gain is noticed on -- `start`
     had already jumped, the real tick read as a few hundredths old, and was
     rejected. Every tick after it was rejected too, and the cycle free-ran on a
     perfect two-second beat anchored to one stale observation.

     So the interval is measured from `lastTick`, which only an observation ever
     moves. Here every tick lands 2.1 seconds apart and every one is believed. ]]--
local slow = { start = 0, period = 2 }
OB.tickers.pulse.Reset(slow, 200)
OB.tickers.pulse.Observe(slow, 200, 40, 20)

local believed, at = 0, 200
for i = 1, 10 do
    at = at + 2.1

    -- the frames in between, which are what roll `start` forward
    OB.tickers.pulse.Observe(slow, at - 0.05, 60, 60)

    if OB.tickers.pulse.Observe(slow, at, 80, 60) then believed = believed + 1 end
end

eq(believed, 10, "a tick slower than two seconds is believed every time")
near(slow.start, at, 0.001, "so the cycle stays anchored to the real one")

--[[ And the period is **measured**, not assumed. Two seconds is the number
     everyone quotes and it is not what a client observes, so rather than pick a
     better constant the interval between believed ticks is folded into a running
     estimate -- the same way the rage decay rate is. A server that ticks
     differently is then something the bar follows rather than argues with. ]]--
near(slow.period, 2.1, 0.05, "and the estimate follows the real interval")

--[[ A gain bigger than anything seen is believed whatever the timing says,
     because the timing is only as good as the anchor it came from and a bigger
     gain proves that anchor was not a full tick.

     This is what rescues a login whose first observation happened to be a
     refund: the next real tick is ten times larger and takes the phase back at
     once, rather than over the two cycles the timing test alone would need. ]]--
local cold = { start = 0, period = 2 }
OB.tickers.pulse.Reset(cold, 300)
check(OB.tickers.pulse.Observe(cold, 300.4, 42, 40),
        "a refund anchors when nothing better is known")
eq(cold.start, 300.4, "so the phase starts wrong")

check(OB.tickers.pulse.Observe(cold, 301, 62, 42),
        "and the next real tick is believed despite arriving early")
eq(cold.start, 301, "taking the phase back immediately")

-- ---------------------------------------------------------------------------

context = "five second rule: "
local m = { start = 0, period = 2 }
OB.tickers.fsr.Reset(m, 200)

check(OB.tickers.fsr.Observe(m, 201, 900, 1000), "spending is reported")
eq(m.period, 5, "spending opens a five second window")
eq(m.start, 201, "the window starts when the mana was spent")

-- mp5 keeps paying out during the rule and must not be mistaken for a tick
OB.tickers.fsr.Observe(m, 202, 905, 900)
eq(m.period, 5, "a small trickle does not end the window")

OB.tickers.fsr.Observe(m, 207, 905, 905)
eq(m.period, 2, "the window rolls back to a normal tick when it expires")

-- ---------------------------------------------------------------------------
-- 6. swing attribution goes to the hand that has waited longest
-- ---------------------------------------------------------------------------

context = "swings: "
OB = boot("ROGUE", 3)

local swing = OB.swing
Stub.player.mainSpeed, Stub.player.offSpeed = 2.6, 1.7

Stub.FireEvent("PLAYER_ENTER_COMBAT")
check(swing.attacking, "entering melee starts the timers")

-- both hands stalled for a long time, the main hand far more overdue
local now = Stub.Clock()
swing.mainStart = now - 10
swing.offStart = now - 3

Stub.FireEvent("CHAT_MSG_COMBAT_SELF_HITS")
near(swing.mainStart, now, 0.2, "the most overdue hand is re-anchored first")
near(swing.offStart, now - 3, 0.2, "the less overdue hand is left alone")

-- and then the other one catches up, which is the self-healing property
Stub.FireEvent("CHAT_MSG_COMBAT_SELF_HITS")
near(swing.offStart, Stub.Clock(), 0.2, "the starved hand recovers on the next swing")

Stub.FireEvent("PLAYER_LEAVE_COMBAT")
check(not swing.attacking, "leaving melee stops the timers")
eq(swing.mainStart, 0, "stopped timers are cleared, not left at full")

-- an idle swing bar reads as ready rather than empty
Stub.Tick(0.05, 2)
local mh = OB.modules.mainhand.frame
near(mh.fill.width, 200, 1, "an idle swing bar reads as ready")

-- ---------------------------------------------------------------------------
-- 7. druid form change: recolour in place, no phantom tick
-- ---------------------------------------------------------------------------

context = "druid forms: "
OB = boot("DRUID", 0, { power = 1200, powerMax = 2000 })

local resource = OB.modules.power
local before = OB.profile.slots.resource
local beforeGeom = before.x .. "," .. before.y .. "," .. before.w .. "," .. before.h

eq(resource.ptype, 0, "caster form uses mana")
eq(resource.ticker, OB.tickers.fsr, "mana uses the five second rule ticker")

-- shift to cat: energy
Stub.player.powerType = 3
Stub.player.power = 100
Stub.player.powerMax = 100
Stub.FireEvent("UNIT_DISPLAYPOWER", "player")
Stub.Tick(0.05, 2)

eq(resource.ptype, 3, "cat form uses energy")
eq(resource.ticker, OB.tickers.pulse, "energy uses the pulse ticker")
eq(resource.last, 100, "the last value is re-seeded, so the jump is not read as a tick")

local after = OB.profile.slots.resource
eq(after.x .. "," .. after.y .. "," .. after.w .. "," .. after.h, beforeGeom,
        "the bar did not move or resize across the form change")

local energyColor = OB.profile.modules.power.byType[3].color
near(resource.frame.fill.vertex[1], energyColor[1], 0.001, "the bar took the energy colour")

-- shift to bear: rage, no ticker
Stub.player.powerType = 1
Stub.player.power = 0
Stub.player.powerMax = 100
Stub.FireEvent("UNIT_DISPLAYPOWER", "player")
Stub.Tick(0.05, 2)

eq(resource.ptype, 1, "bear form uses rage")
check(resource.ticker == nil, "rage has no ticker")
check(not (resource.frame.spark and resource.frame.spark.shown), "the spark is hidden for rage")

-- ---------------------------------------------------------------------------
-- 8. combo points
-- ---------------------------------------------------------------------------

context = "combo points: "
OB = boot("ROGUE", 3)

local combo = OB.modules.combopoints
eq(combo.frame.count, 5, "five segments")

Stub.player.combo = 3
Stub.FireEvent("PLAYER_COMBO_POINTS")
Stub.Tick(0.05, 2)

local cfg = OB.profile.modules.combopoints
for i = 1, 5 do
    local seg = combo.frame.bars[i]
    local wantAlpha = (i <= 3) and (cfg.colors[i][4] or 1)
            or ((cfg.colors[i][4] or 1) * cfg.dim)
    near(seg.fill.vertex[4], wantAlpha, 0.001,
            "point " .. i .. " alpha reflects active state")
    near(seg.fill.width, seg.width, 1, "point " .. i .. " is always drawn full")
end

-- dimming must never touch frame alpha, or the border fades with it
check(combo.frame.bars[5]:GetAlpha() == 1, "inactive points keep frame alpha at 1")

-- segments sit edge to edge and add up to the slot width
local total = 0
for i = 1, 5 do total = total + combo.frame.bars[i].width end
check(total <= OB.profile.slots.extras.w and total >= OB.profile.slots.extras.w - 5,
        "segments fill the slot width", "total " .. total)

--[[ Hiding at zero has to survive a refresh, and this is the worse half of that
     bug: combo points are **not** `tickly`, so nothing redraws them on the next
     frame. OB.Toggle re-showed the bar and there it stayed, five dim pips with no
     combo points, until the count next changed.

     The distance readout had the same fault and merely flickered, because it is
     tickly and corrected itself a frame later. Whether a bug was visible or
     permanent came down to a flag on the module, which is why the fix belongs in
     Toggle rather than in either module. ]]--
OB.profile.modules.combopoints.hideWhenZero = true
Stub.player.combo = 0
Stub.FireEvent("PLAYER_COMBO_POINTS")
Stub.Tick(0.05, 2)
check(not combo.frame:IsShown(), "combo points hide themselves at zero")

OB.Refresh(true)
check(not combo.frame:IsShown(), "and stay hidden through a refresh")
Stub.Tick(0.05, 3)
check(not combo.frame:IsShown(), "including three frames later, with nothing to redraw them")

Stub.player.combo = 3
Stub.FireEvent("PLAYER_COMBO_POINTS")
Stub.Tick(0.05, 2)
check(combo.frame:IsShown(), "and come back when there are points to show")

OB.profile.modules.combopoints.hideWhenZero = false

-- ---------------------------------------------------------------------------
-- 9. movement: one code path, join, collision
-- ---------------------------------------------------------------------------

context = "movement: "
OB = boot("ROGUE", 3)

local slots = OB.profile.slots
local startY = {}
for id, s in pairs(slots) do startY[id] = s.y end

-- joined: everything moves together and keeps its spacing
OB.profile.join = true
OB.NudgeSlot("resource", 0, -10)
local moved = true
for id, s in pairs(slots) do
    if s.y ~= startY[id] - 10 then moved = false end
end
check(moved, "a joined nudge moves every slot by the same amount")

-- unjoined: only the target moves, and nothing inverts
OB.profile.join = false
OB.profile.allowOverlap = true
local otherBefore = slots.health.y
OB.NudgeSlot("resource", 5, 0)
eq(slots.resource.x, 5, "an unjoined nudge moves the target")
eq(slots.health.y, otherBefore, "an unjoined nudge leaves the others alone")

--[[ Collision, in isolation: every slot but resource and health is hidden, so
     the only thing that can block the move is the one under test. Leaving the
     rest of the stack in play would prove nothing -- an earlier version of this
     test passed against the wrong bar. ]]--
OB.profile.allowOverlap = false
for id, s in pairs(slots) do s.show = false end
slots.resource.show = true
slots.health.show = true
slots.resource.x, slots.resource.y = 0, 80
slots.health.x, slots.health.y = 0, 55
OB.BindSlots()

local blockedFrom = slots.health.y
OB.NudgeSlot("health", 0, 20)   -- straight up into the resource bar
eq(slots.health.y, blockedFrom, "collision refuses a step that would stack bars")

-- away from the obstruction is always allowed
OB.NudgeSlot("health", 0, -5)
eq(slots.health.y, blockedFrom - 5, "moving away from an obstruction is allowed")
slots.health.y = blockedFrom

-- and a hidden slot blocks nothing
slots.resource.show = false
OB.BindSlots()
OB.NudgeSlot("health", 0, 20)
eq(slots.health.y, blockedFrom + 20, "a hidden slot does not block movement")

for id, s in pairs(slots) do s.show = true end
OB.BindSlots()

--[[ **Coordinates clamp to the screen, not to the storage range.**

     +/-2000 is a bound on the number and says nothing about the monitor: a bar
     dragged to 900 was saved, restored and invisible, with no way back except a
     slider nobody would guess is the cause. That was the report.

     The limit is half the screen less half the bar, because a bar is anchored by
     its centre to the middle of the screen. ]]--
OB.NudgeSlot("health", 999999, 0)

local edge = (GetScreenWidth() / 2) - (slots.health.w / 2)
eq(slots.health.x, edge, "x stops at the screen's edge, not at the number's")
check(edge < OB.POS_MAX, "which is well inside the storage range")

--[[ The whole bar, not its centre: the right edge lands on the screen's, so
     nothing is cut off at the limit. ]]--
eq(slots.health.x + (slots.health.w / 2), GetScreenWidth() / 2,
        "with the bar's far edge exactly on the screen's")

OB.NudgeSlot("health", -999999, 0)
eq(slots.health.x, -edge, "and symmetrically on the other side")

--[[ Taller screens allow more; the limit is read at the time, not baked in. ]]--
OB.NudgeSlot("health", 0, 999999)
eq(slots.health.y, (GetScreenHeight() / 2) - (slots.health.h / 2),
        "y uses the screen's height and the bar's own")

--[[ **Bar Spacing**, which the stack had no setting for at all: it was always
     edge to edge plus whatever the border needed, and there was no way to
     loosen it.

     It changes where Restack *puts* things rather than moving anything by
     itself. Geometry is account-wide, so a setting that silently relaid every
     character's HUD is the reflow bug this addon is built to avoid. ]]--
--[[ A function, not a bare block: the main chunk is at Lua 5.0's two hundred
     local limit, and `do ... end` does not help once the *top level* is full --
     only a new function gets a fresh scope to spend. ]]--
local function barSpacingTests()
    OB.profile.barGap = 0
    OB.RestackBars()

    local tightA = slots[OB.barOrder[1]].y
    local tightB = slots[OB.barOrder[2]].y

    OB.profile.barGap = 6
    eq(slots[OB.barOrder[1]].y, tightA,
            "changing the spacing moves nothing by itself")

    OB.RestackBars()

    eq((slots[OB.barOrder[1]].y - slots[OB.barOrder[2]].y)
            - (tightA - tightB), 6,
            "and a restack leaves exactly the gap asked for")

    OB.profile.barGap = 0
    OB.RestackBars()
end

barSpacingTests()

-- ---------------------------------------------------------------------------
-- 10. one bar, one module, and nothing to assign
--
-- This section used to test reassignment -- putting any module in any slot, with
-- "auto" and "none" sentinels. That whole layer is gone, so what is left to
-- prove is the property that replaced it: the pairing is fixed, declared by the
-- module, and unreachable from the config.
-- ---------------------------------------------------------------------------

context = "bars: "
OB = boot("ROGUE", 3)

check(OB.profile.assign == nil, "a profile carries no assignment table at all")
check(OB.AssignSlot == nil, "and there is no way to write one")

-- every bound module sits in the bar its descriptor names
for barId, m in pairs(OB.bound) do
    eq(m.bar, barId, m.id .. " is bound to the bar it declares")
    eq(m.slotId, barId, "and knows which bar it holds")
end

--[[ Disabling a module empties its bar rather than handing the bar to something
     else. There is no "something else" to hand it to any more. ]]--
OB.profile.modulesEnabled.combopoints = false
OB.BindSlots()
check(OB.bound.extras == nil, "disabling a module empties its bar")

OB.profile.modulesEnabled.combopoints = nil
OB.BindSlots()
eq(OB.bound.extras and OB.bound.extras.id, "combopoints", "re-enabling refills it")

--[[ The bar still appears in the panel list while its module is switched off --
     otherwise there would be nowhere to switch it back on from. Class
     applicability and the enable toggle are different questions. ]]--
OB.profile.modulesEnabled.combopoints = false
local listedWhileOff = false
local bars = OB.BarsForClass()
for i = 1, table.getn(bars) do
    if bars[i] == "extras" then listedWhileOff = true end
end
check(listedWhileOff, "a disabled module's bar is still listed, so it can be re-enabled")
OB.profile.modulesEnabled.combopoints = nil

-- a hunter has no combo points, so no Extras bar exists to list
OB = boot("HUNTER", 0)
check(OB.bound.extras == nil, "a hunter has no extras occupant")

local hunterBars = {}
bars = OB.BarsForClass()
for i = 1, table.getn(bars) do hunterBars[bars[i]] = true end
check(not hunterBars.extras, "and no extras bar in the list")
check(not hunterBars.secondary, "nor a secondary resource bar")
check(hunterBars.ranged and hunterBars.distance,
        "but the ranged timer and the distance readout are both there")

-- ---------------------------------------------------------------------------
-- 11. events are registered from the bound set, not hardcoded
-- ---------------------------------------------------------------------------

context = "events: "
OB = boot("WARRIOR", 1)

check(OB.events:IsEventRegistered("UNIT_RAGE"), "a bound module's events are registered")
check(OB.events:IsEventRegistered("VARIABLES_LOADED"), "core events survive a rebind")
check(not OB.events:IsEventRegistered("PLAYER_COMBO_POINTS"),
        "a warrior does not register combo point events")

OB = boot("ROGUE", 3)
check(OB.events:IsEventRegistered("PLAYER_COMBO_POINTS"),
        "a rogue does register combo point events")

-- ---------------------------------------------------------------------------
-- 12. module toggles
-- ---------------------------------------------------------------------------

context = "module toggle: "
OB = boot("ROGUE", 3)

OB.profile.modulesEnabled.health = false
OB.BindSlots()
check(OB.bound.health == nil, "a disabled module is not bound")

OB.profile.modulesEnabled.health = true
OB.BindSlots()
check(OB.bound.health ~= nil, "re-enabling rebinds it")

-- absent means enabled, so a module a later version adds is on by default
OB.profile.modulesEnabled.health = nil
OB.BindSlots()
check(OB.bound.health ~= nil, "an unset flag means enabled")

-- ---------------------------------------------------------------------------
-- 13. config: merge, migration and the RogueBars import
-- ---------------------------------------------------------------------------

context = "config: "
OB = boot("ROGUE", 3)

-- a colour is a leaf and is replaced whole, not merged channel by channel
local dst = { color = { 1, 1, 1, 1 }, nested = { a = 1, b = 2 } }
OB.DeepMerge(dst, { color = { 0, 0, 0, 0.5 }, nested = { b = 9 } })
eq(dst.color[1], 0, "a saved colour replaces the default outright")
eq(dst.color[4], 0.5, "including its alpha")
eq(dst.nested.a, 1, "a record keeps defaults the save did not mention")
eq(dst.nested.b, 9, "and takes the ones it did")

-- byType is numerically keyed but holds tables, so it must merge, not replace:
-- otherwise a profile saved before a power type existed would delete it
local byType = { [0] = { color = { 1, 1, 1, 1 }, ticker = "always" },
                 [3] = { color = { 1, 1, 0, 1 }, ticker = "always" } }
OB.DeepMerge(byType, { [3] = { ticker = "never" } })
check(byType[0] ~= nil, "a power type the save omits survives the merge")
eq(byType[3].ticker, "never", "the saved value wins where it exists")
eq(byType[3].color[2], 1, "and the rest of that entry is kept")

--[[ **An empty saved table must not wipe its defaults.**

     A leaf is replaced wholesale, and an empty table used to count as one --
     the "only numeric keys, only scalars" loop never runs, so it fell through to
     true. So a profile written before a table had any contents replaced the
     shipped defaults with nothing at all.

     `modulesEnabled` is what caught it: every profile saved before the threat
     meter existed carries an empty one, and replacing the defaults with it
     switched on every feature that had shipped off. The same hole sat under
     every other table in the profile.

     Merging is right because an empty table carries no information -- recursing
     into nothing leaves the destination alone, which is exactly what "the user
     saved no opinion about this" should mean. ]]--
local shipped = { modulesEnabled = { threat = false }, slots = { health = { w = 200 } } }
OB.DeepMerge(shipped, { modulesEnabled = {}, slots = {} })
eq(shipped.modulesEnabled.threat, false, "an empty saved table keeps the defaults under it")
eq(shipped.slots.health.w, 200, "however deep they go")

-- and a non-empty one still merges key by key rather than replacing
OB.DeepMerge(shipped, { modulesEnabled = { damage = false } })
eq(shipped.modulesEnabled.threat, false, "a partial save keeps what it did not mention")
eq(shipped.modulesEnabled.damage, false, "and takes what it did")

-- dotted option keys read and write nested values
local root = { colors = { { 1, 0, 0, 1 }, { 0, 1, 0, 1 } } }
eq(OB.Get(root, "colors.2.2"), 1, "a dotted path reads a nested value")
OB.Set(root, "colors.1.1", 0.5)
eq(root.colors[1][1], 0.5, "a dotted path writes one")

-- ---------------------------------------------------------------------------
-- 14. RogueBars import
-- ---------------------------------------------------------------------------

context = "roguebars import: "

EquadisClassicOverhaulDB = nil
RogueBarsConfig = {
    Scale = 1.3,
    Join = false,
    Texture = "ElvUI",
    Border = "thin",
    Elements = {
        Combo = { Width = 180, Height = 10, X = 4, Y = 130, TextSize = 11,
                  BGColor = { 0, 0, 0, 0.4 }, Flip = true, Hide = false,
                  Colors = { { 1, 0, 0, 1 }, { 1, 0, 0, 1 }, { 1, 0, 0, 1 },
                             { 1, 0, 0, 1 }, { 1, 0, 0, 1 } } },
        MainHand = { Width = 180, Height = 14, X = 4, Y = 100, Color = { 1, 0.5, 0, 1 },
                     Decimals = 2, Deplete = true },
        OffHand = { Width = 180, Height = 14, X = 4, Y = 115, Color = { 1, 0.7, 0.3, 1 } },
        Energy = { Width = 180, Height = 26, X = 4, Y = 80, Color = { 0.9, 0.9, 0, 1 },
                   Ticker = "nofull", TickerColor = { 1, 0, 0, 1 }, TextMode = "percent" },
    },
}

OB = boot("ROGUE", 3)

near(OB.profile.scale, 1.3, 0.001, "global scale imported")
eq(OB.profile.join, false, "join imported")
eq(OB.profile.texture, 4, "texture name mapped to an index")
eq(OB.profile.border, 2, "border name mapped to an index")

eq(OB.profile.slots.extras.w, 180, "combo geometry landed on the points slot")
eq(OB.profile.slots.extras.y, 130, "including its position")
eq(OB.profile.slots.extras.flip, true, "and its flip")
eq(OB.profile.slots.resource.h, 26, "energy geometry landed on the resource slot")
eq(OB.profile.slots.mainhand.y, 100, "main hand geometry landed on swingA")
eq(OB.profile.slots.offhand.y, 115, "off hand geometry landed on swingB")

eq(OB.profile.modules.mainhand.decimals, 2, "main hand behaviour imported")
eq(OB.profile.modules.mainhand.deplete, true, "including deplete")
eq(OB.profile.modules.power.textMode, "percent", "energy text mode imported")
eq(OB.profile.modules.power.byType[3].ticker, "nofull", "energy ticker mode imported")
near(OB.profile.modules.power.byType[0].color[3], 0.90, 0.001,
        "the other power types kept their own defaults")
near(OB.profile.modules.combopoints.colors[1][1], 1, 0.001, "combo colours imported")

-- imports run once: a second boot must not overwrite tuned values
OB.profile.scale = 1.4
local saved = EquadisClassicOverhaulDB
RogueBarsConfig.Scale = 0.7
OB = boot("ROGUE", 3, { savedVariables = saved })
near(OB.profile.scale, 1.4, 0.001, "a second login does not re-import over tuned values")

--[[ A scale saved before the ceiling came down is brought inside it rather than
     refused, so the slider can always reach the value the profile holds. ]]--
OB.profile.scale = 1.9
saved = EquadisClassicOverhaulDB
OB = boot("ROGUE", 3, { savedVariables = saved })
near(OB.profile.scale, OB.SCALE_MAX, 0.001, "a scale above the ceiling clamps on load")

RogueBarsConfig = nil

-- ---------------------------------------------------------------------------
-- 15. profiles are shared, and switching works
-- ---------------------------------------------------------------------------

context = "profiles: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { name = "Rogueone" })

OB.profile.slots.resource.y = 42
local db = EquadisClassicOverhaulDB

-- a second character on the same profile sees the same geometry
OB = boot("WARRIOR", 1, { name = "Warrtwo", savedVariables = db })
eq(OB.profileName, "Default", "a new character joins the Default profile")
eq(OB.profile.slots.resource.y, 42, "and inherits the geometry the first one set")

OB.NewProfile("Raiding")
eq(OB.profileName, "Raiding", "a new profile becomes active")
eq(OB.profile.slots.resource.y, 42, "and starts as a copy of the current one")

OB.profile.slots.resource.y = 7
OB.SetProfile("Default")
eq(OB.profile.slots.resource.y, 42, "switching back restores the other profile")

OB.SetProfile("Raiding")
eq(OB.profile.slots.resource.y, 7, "and forward again")

OB.ResetProfile()
eq(OB.profile.slots.resource.y, 86, "resetting restores this profile's defaults")
eq(EquadisClassicOverhaulDB.profiles.Default.slots.resource.y, 42,
        "and leaves the other profile alone")

OB.SetProfile("Default")
OB.DeleteProfile("Raiding")
check(EquadisClassicOverhaulDB.profiles.Raiding == nil, "a deleted profile is gone")

OB.DeleteProfile("Default")
check(EquadisClassicOverhaulDB.profiles.Default ~= nil, "Default cannot be deleted")

--[[ **Named at the moment the name is wanted.**

     Creating a profile used to be a text box that sat on the page whether or not
     anybody was making one, labelled with nothing, beside a button that only
     worked once something had been typed into it -- so pressing the button was
     the natural first move and being told off was the natural first result. The
     popup cannot be pressed too early. ]]--
Stub.AcceptPopup("EQOB_NEW_PROFILE", "Dungeons")
eq(OB.profileName, "Dungeons", "the popup creates and switches to the profile")

-- Enter in the box is its own handler in 1.12, and a dialog that ignores it is
-- one people type into and then wonder at
Stub.PopupEnter("EQOB_NEW_PROFILE", "Battlegrounds")
eq(OB.profileName, "Battlegrounds", "and the enter key does the same thing")

-- an empty name creates nothing rather than a profile called ""
local before = OB.profileName
Stub.AcceptPopup("EQOB_NEW_PROFILE", "")
eq(OB.profileName, before, "an empty name is refused")
check(EquadisClassicOverhaulDB.profiles[""] == nil, "and leaves no nameless profile")

OB.SetProfile("Default")

--[[ Switching from the panel has to leave the panel telling the truth.

     LoadConfig replaces OB.profile wholesale, so every control is left reading a
     table that no longer exists. The profile dropdown is the one that shows it:
     it kept naming the profile you had just switched *away from*, which made
     switching look broken when it had actually worked. The slash path called
     RefreshPanel; the panel path did not. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.NewProfile("Raiding")
OB.TogglePanel()

local profileDrop = _G["EqOBProfileDrop"]
check(profileDrop ~= nil, "the profile dropdown exists")

if profileDrop then
    eq(OB.profileName, "Raiding", "a new profile becomes the active one")
    eq(profileDrop.selectedValue, "Raiding", "and the dropdown says so")
    eq(profileDrop.selectedText, "Raiding", "including its label")

    check(Stub.ChooseMenu(profileDrop, "Default"), "picking another profile applies")
    eq(OB.profileName, "Default", "the profile really changed")
    eq(profileDrop.selectedValue, "Default", "and the dropdown followed it")
    eq(profileDrop.selectedText, "Default", "label included")

    -- and back again, because the bug was direction-independent
    Stub.ChooseMenu(profileDrop, "Raiding")
    eq(OB.profileName, "Raiding", "switching back works too")
    eq(profileDrop.selectedText, "Raiding", "and is still reported correctly")
end

-- ---------------------------------------------------------------------------
-- 16. visibility rules
-- ---------------------------------------------------------------------------

context = "visibility: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

check(OB.container:IsVisible(), "the HUD is visible by default")

OB.profile.show = false
OB.Toggle()
check(not OB.container:IsVisible(), "the master switch hides it")
OB.profile.show = true

OB.profile.hideOOC = true
OB.inCombat = false
OB.Toggle()
check(not OB.container:IsVisible(), "hide out of combat hides it out of combat")

Stub.FireEvent("PLAYER_REGEN_DISABLED")
check(OB.container:IsVisible(), "and shows it in combat")
Stub.FireEvent("PLAYER_REGEN_ENABLED")
check(not OB.container:IsVisible(), "and hides it again after")

-- test mode overrides the very rules it exists to help you set up
OB.SetTestMode(true)
check(OB.container:IsVisible(), "test mode forces the HUD visible")
OB.SetTestMode(false)
check(not OB.container:IsVisible(), "and stops overriding when it ends")
OB.profile.hideOOC = false

-- stealth
Stub.player.buffs = { "Interface\\Icons\\Ability_Stealth" }
OB.profile.hideStealth = true
Stub.FireEvent("PLAYER_AURAS_CHANGED")
check(not OB.container:IsVisible(), "hide when stealthed hides it while stealthed")
Stub.player.buffs = {}
Stub.FireEvent("PLAYER_AURAS_CHANGED")
check(OB.container:IsVisible(), "and shows it again when stealth drops")
OB.profile.hideStealth = false

-- a hidden slot hides only itself
OB.profile.slots.health.show = false
OB.Toggle()
check(not OB.modules.health.frame:IsShown(), "a hidden slot hides its bar")
check(OB.modules.power.frame:IsShown(), "and leaves the others alone")
OB.profile.slots.health.show = true

-- ---------------------------------------------------------------------------
-- 17. test mode drives every bound module
-- ---------------------------------------------------------------------------

context = "test mode: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { power = 100, powerMax = 100 })

OB.SetTestMode(true)
check(OB.testMode, "test mode is on")

local powerSeen, comboSeen, healthSeen = {}, {}, {}
for i = 1, 200 do
    Stub.Tick(0.05, 1)
    powerSeen[OB.test.power] = true
    comboSeen[OB.test.combo] = true
    healthSeen[OB.test.health] = true
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

check(countKeys(powerSeen) > 3, "the resource preview moves through several values")
check(countKeys(comboSeen) >= 5, "the combo preview cycles the points")
check(countKeys(healthSeen) > 3, "the health preview moves")
check(OB.swing.attacking, "the swing preview runs the timers")

OB.SetTestMode(false)
eq(OB.modules.power.last, Stub.player.power,
        "stopping re-seeds the tick tracker, so no phantom tick follows")

-- ---------------------------------------------------------------------------
-- 18. the options panel builds and drives the config
-- ---------------------------------------------------------------------------

context = "panel: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

try("panel builds", function() OB.TogglePanel() end)
check(OB.settings and OB.settings:IsVisible(), "the panel opens")
try("panel refreshes", function() OB.RefreshPanel() end)

-- a checkbox writes through to the config
local check1 = _G["EqOBCheck_global_x_locked"]
check(check1 ~= nil, "the Lock Bars checkbox exists")
if check1 then
    local before = OB.profile.locked
    check1:SetChecked(not before)
    Stub.Click(check1)
    eq(OB.profile.locked, not before, "clicking a checkbox writes the config")
end

-- a slider writes through, honouring its factor
local scale = _G["EqOBSlider_global_x_scale"]
check(scale ~= nil, "the Scale slider exists")
if scale then
    scale:SetValue(150)
    near(OB.profile.scale, 1.5, 0.001, "the slider factor converts 150 to 1.5")
    near(OB.container:GetScale(), 1.5, 0.001, "and the change reaches the frame")
end

-- position sliders must route through the nudge path so Join still applies
OB.panel.bar = "resource"
OB.profile.join = true
local ySlider = _G["EqOBSlider_slot_x_y"]
check(ySlider ~= nil, "the Y slider exists")
if ySlider then
    local healthBefore = OB.profile.slots.health.y
    local delta = 15
    ySlider:SetValue(OB.profile.slots.resource.y + delta)
    eq(OB.profile.slots.health.y, healthBefore + delta,
            "a joined Y slider move takes every slot with it")
end

-- every page lays out without error, on every slot, with every occupant
try("all pages lay out for every slot", function()
    for i = 1, table.getn(OB.barOrder) do
        OB.panel.bar = OB.barOrder[i]
        OB.RefreshPanel()
    end
end)

--[[ **The bar selector is the second navigation column, not a dropdown.**

     A dropdown hides its list until clicked, so the one question the Bars page
     has to answer at a glance -- which bar am I looking at, and what else is
     there -- cost a click to ask. A column answers it by existing.

     The occupant dropdown that used to sit beside it went earlier, with the
     assignment layer. ]]--
check(_G["EqOBBarSelector"] == nil, "the bar dropdown is gone")
check(_G["EqOBOccupant"] == nil, "and so is the occupant one")

OB.SelectCategory("OmniBars")

local shownSub = 0
for i = 1, table.getn(OB.settings.subButtons) do
    if OB.settings.subButtons[i]:IsShown() then shownSub = shownSub + 1 end
end
--[[ General, then this class's bars. General leads because scale, texture,
     font and the movement switches are settings *about* the bars. ]]--
eq(shownSub, table.getn(OB.BarsForClass()) + 1,
        "the column offers General and exactly this class's bars")
eq(OB.settings.subButtons[1].label:GetText(), "General",
        "with General first")

-- picking one moves the page, which is the whole of what the dropdown did
OB.settings.subPick("extras")
OB.RefreshPanel()
eq(OB.panel.bar, "extras", "and picking one moves the page")

--[[ **Move Bars Together exists once.**

     It used to be on General *and* mirrored onto Bars, as one setting shown
     twice -- with a `mirror` name so the two frames did not collide, because two
     frames sharing one global name means the second silently displaces the
     first.

     General is the first entry in the Bars column now, so the mirror became the
     same row on the same page twice. The whole mechanism went with it: one page,
     one row, nothing to keep in step. ]]--
local joinBars = _G["EqOBCheck_global_x_join"]

check(joinBars ~= nil, "the movement switch is on the Bars page")
check(_G["EqOBCheck_global_x_join_bars"] == nil,
        "and there is no mirrored second copy of it")

if joinBars then
    local before = OB.profile.join

    -- the stub does not toggle a CheckButton on click the way the client does,
    -- so the state is set first
    joinBars:SetChecked(not before)
    Stub.Click(joinBars)
    eq(OB.profile.join, not before, "ticking it writes the global setting")

    joinBars:SetChecked(before)
    Stub.Click(joinBars)
    eq(OB.profile.join, before, "and back again")
end

check(_G["EqOBCheck_global_x_allowOverlap"] ~= nil,
        "Allow Bar Overlap is there too, once")

--[[ No single-select dropdown may set info.checked.

     1.12's AddButton shows a check when it is truthy and never hides one, and
     the check textures are global and shared across every dropdown in the
     client -- so one menu's tick stays lit beside the next menu's. Selection is
     driven by SetSelectedValue alone, which both shows and hides. Setting both
     is what put several ticks in the profile dropdown at once.

     Every entry must still carry a `value`, because that is what Refresh
     matches against to decide which row is selected. ]]--
local checkedRows, valuelessRows, menusSeen = 0, 0, 0

for i = 1, table.getn(OB.settings.categories) do
    local page = OB.settings.categories[i].page
    for r = 1, table.getn(page.rows) do
        local widget = page.rows[r]
        if widget.initialize then
            menusSeen = menusSeen + 1
            local buttons = Stub.OpenMenu(widget)
            for b = 1, table.getn(buttons) do
                if buttons[b].checked ~= nil then checkedRows = checkedRows + 1 end
                if buttons[b].value == nil then valuelessRows = valuelessRows + 1 end
            end
        end
    end
end

check(menusSeen > 3, "several dropdowns were inspected")
eq(checkedRows, 0, "no dropdown entry sets info.checked")
eq(valuelessRows, 0, "and every entry carries a value for Refresh to match")

-- module rows appear only for the occupying module
OB.panel.bar = "resource"
OB.RefreshPanel()
local tickerDrop = _G["EqOBDrop_variant_power_ticker"]
check(tickerDrop ~= nil, "the power ticker dropdown exists")
if tickerDrop then
    check(tickerDrop:IsShown(), "power's rows show while power holds the slot")
end
local comboSwatch = _G["EqOBSwatch_module_combopoints_colors_1"]
check(comboSwatch ~= nil, "the combo point swatch exists")
if comboSwatch then
    check(not comboSwatch:IsShown(),
            "combo point rows are hidden while the resource slot is selected")
end

OB.panel.bar = "extras"
OB.RefreshPanel()
if comboSwatch then
    check(comboSwatch:IsShown(), "and shown when the extras bar is selected")
end

-- an enum dropdown stores its string, not an index
OB.panel.bar = "resource"
OB.RefreshPanel()
if tickerDrop then
    Stub.ChooseMenu(tickerDrop, 2)
    eq(OB.profile.modules.power.byType[3].ticker, "nofull",
            "an enum dropdown stores the string")
end

-- a colour swatch round-trips through the picker
local barColor = _G["EqOBSwatch_variant_power_color"]
check(barColor ~= nil, "the resource colour swatch exists")
if barColor then
    --[[ Click first, then pick. Opening the swatch seeds the picker with the
         *current* colour, which is the fix for the picker firing opacityFunc
         from its own OnShow and writing the previous swatch's colour back. A
         test that set the colour before clicking would just have it overwritten
         -- as this one did until it was corrected. ]]--
    Stub.Click(barColor)
    near(ColorPickerFrame.rgb[1], 0.87, 0.01, "the picker opens seeded with the current colour")

    ColorPickerFrame:SetColorRGB(0.25, 0.5, 0.75)
    OpacitySliderFrame:SetValue(0.2)   -- vanilla's slider is inverted
    ColorPickerFrame.func()
    local c = OB.profile.modules.power.byType[3].color
    near(c[1], 0.25, 0.001, "the picked red channel is stored")
    near(c[4], 0.8, 0.001, "the inverted opacity slider is flipped on the way in")
end

--[[ A dependent row hides when its condition is off.

     Uses the `@predicate` form, which is the only one with live users: the five
     second rule rows belong to mana and nothing else, so a rogue on energy must
     not see them. ]]--
OB.panel.bar = "resource"
OB.RefreshPanel()

local fsrColor = _G["EqOBSwatch_module_power_fsrColor"]
check(fsrColor ~= nil, "the five second rule colour swatch exists")

if fsrColor then
    eq(OB.modules.power.ptype, 3, "this rogue is on energy")
    check(not fsrColor:IsShown(), "so a mana-only row is hidden")

    OB.modules.power.ptype = 0
    OB.RefreshPanel()
    check(fsrColor:IsShown(), "and shown for a caster")

    OB.modules.power.ptype = 3
    OB.RefreshPanel()
end

--[[ The shape the panel is supposed to have, asserted directly.

     This is the exact symptom that shipped: one sidebar entry and no rows. It
     was invisible to the suite because nothing checked that the panel had been
     built *completely* -- only that individual controls worked once it had. ]]--
--[[ Profiles, OmniBars, twelve subsystems, Modules. Counted rather than listed
     so a tab added without a test failing is a tab nobody checked. ]]--

--[[ **A dropdown with no values opens onto nothing**, and looks exactly like a
     dropdown that will not open.

     It happens when the row is built before the list it names exists -- which is
     easy, because a module's options table is built the moment `RegisterModule`
     runs, and a list declared beside the code that uses it may be hundreds of
     lines below that. `OB.linkFormats` was, and the Item Links dropdown shipped
     empty.

     Every list row on every module, so the next one is caught here rather than
     by somebody clicking it. ]]--
context = "panel: "

GLOBAL_empty = {}

for GLOBAL_id, GLOBAL_m in pairs(OB.modules) do
    for GLOBAL_i = 1, table.getn(GLOBAL_m.options or {}) do
        GLOBAL_opt = GLOBAL_m.options[GLOBAL_i]
        GLOBAL_v = GLOBAL_opt[3]

        --[[ A list row is one whose third column is neither a kind name nor a
             section marker: it is the values themselves, or an enum wrapping
             them. ]]--
        if type(GLOBAL_v) == "table" then
            local values = GLOBAL_v

            if values.enum then values = values.values end

            if type(values) ~= "table" or table.getn(values) == 0 then
                table.insert(GLOBAL_empty,
                        GLOBAL_id .. ":" .. tostring(GLOBAL_opt[2]))
            end
        end
    end
end

eq(table.getn(GLOBAL_empty), 0, "no dropdown is built with an empty list",
        table.concat(GLOBAL_empty, ", "))

eq(table.getn(OB.settings.categories), 14, "the panel has every category")

--[[ **And in the order somebody asked for**, which a count cannot see.

     Written out because it is a decision rather than a consequence: the registry
     is in load order, which is a dependency graph -- the parser loads before the
     meters that read it, and nobody looking for the damage meter thinks that.

     Roughly most-reached-for first, with the things that draw the same rectangle
     next to each other: the bars, the frames around them, the meters, then the
     pages about information rather than about the screen. ]]--
GLOBAL_wanted = { "Profiles", "OmniBars", "Action Bars", "Unit Frames",
                  "Nameplates", "Damage Meter", "Threat Meter", "UnitScan",
                  "Tooltip", "Waypoints", "Chat", "Map",
                  "Quality Of Life", "Modules" }

for GLOBAL_i = 1, table.getn(GLOBAL_wanted) do
    eq(OB.settings.categories[GLOBAL_i] and OB.settings.categories[GLOBAL_i].name,
            GLOBAL_wanted[GLOBAL_i],
            "tab " .. GLOBAL_i .. " is " .. GLOBAL_wanted[GLOBAL_i])
end

--[[ **A feature the tab list has never heard of configures nothing anybody can
     reach.** The list is written by hand, so a module registered and left off it
     has a settings table, a switch on the Modules page, and no page.

     Reachable does not mean *has a tab*: an entry may name several modules, one
     tab built from all of them -- which is how Players ended up inside Chat. So
     the assertion is membership in the list, flattened. ]]--
GLOBAL_reachable = {}

for GLOBAL_i = 1, table.getn(OB.featureTabs) do
    GLOBAL_entry = OB.featureTabs[GLOBAL_i]

    if type(GLOBAL_entry) == "table" then
        for GLOBAL_k = 1, table.getn(GLOBAL_entry) do
            GLOBAL_reachable[GLOBAL_entry[GLOBAL_k]] = true
        end
    else
        GLOBAL_reachable[GLOBAL_entry] = true
    end
end

for GLOBAL_id, GLOBAL_m in pairs(OB.modules) do
    if GLOBAL_m.feature then
        check(GLOBAL_reachable[GLOBAL_id],
                "the " .. GLOBAL_m.name .. " module is reachable from a tab")
    end
end

--[[ **The roster keeps its own module and loses only its tab.** Nameplates and
     unit frames read from it, so folding it into chat's settings table would put
     one subsystem's storage inside another's. Its rows are scoped to it and
     drawn on Chat's page, which is what `sectionOf` is for. ]]--
check(OB.modules.roster ~= nil, "the roster is still its own module")
check(OB.widgets["moduleToggle::roster@list"] ~= nil,
        "with its own switch on the Modules page")
check(OB.widgets["module:roster:scanNames"] ~= nil,
        "and its rows still scoped to it")

local totalRows, unplaced, brokenRows = 0, 0, 0
for i = 1, table.getn(OB.settings.categories) do
    local cat = OB.settings.categories[i]
    local n = table.getn(cat.page.rows)

    check(n > 0, "the " .. cat.name .. " page has rows")
    totalRows = totalRows + n

    for r = 1, n do
        local widget = cat.page.rows[r]
        if widget.broken then brokenRows = brokenRows + 1 end
        if widget.visible and widget:GetNumPoints() == 0 then
            unplaced = unplaced + 1
        end
    end
end

eq(brokenRows, 0, "no row gave up during a healthy build")
eq(unplaced, 0, "every visible row is anchored")
check(totalRows > 50, "the panel built a plausible number of rows")

-- every font string the addon made has a font. The bug that shipped, as a check.
local unfonted = 0
for i = 1, table.getn(OB.texts) do
    if not OB.texts[i]:GetFont() then unfonted = unfonted + 1 end
end
eq(unfonted, 0, "every registered font string has a font")
check(table.getn(OB.texts) > 0, "and the registry is not empty")

-- every option the prompt offers has a control behind it
local orphaned = 0
local function crossCheck(index)
    for key, w in pairs(index) do
        if not OB.widgets[OB.WidgetKey(w)] then orphaned = orphaned + 1 end
    end
end
crossCheck(OB.optionIndex.global)
crossCheck(OB.optionIndex.slot)
for id, index in pairs(OB.optionIndex.modules) do crossCheck(index) end
eq(orphaned, 0, "every indexed option has a control on the panel")

-- closing the panel stops the preview
OB.SetTestMode(true)
OB.settings:Hide()
-- OnHide is not fired by Hide() in the stub, so call it the way the client would
if OB.settings.scripts.OnHide then OB.settings.scripts.OnHide() end
check(not OB.testMode, "closing the panel stops test mode")

-- ---------------------------------------------------------------------------
-- 19. slash commands
-- ---------------------------------------------------------------------------

context = "slash: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local run = SlashCmdList["EQUADISOMNIBARS"]
check(run ~= nil, "the slash handler is registered")

try("help prints without error", function() run("help") end)

run("scale 120")
near(OB.profile.scale, 1.2, 0.001, "a global option is settable")

-- camelCase keys have to work from a prompt nobody shift-types
run("hideooc on")
eq(OB.profile.hideOOC, true, "a camelCase key resolves case-insensitively")
run("hideooc off")

run("bar resource h 20")
eq(OB.profile.slots.resource.h, 20, "a bar option is settable")

run("power textMode percent")
eq(OB.profile.modules.power.textMode, "percent", "a module option is settable")

--[[ `/eqob assign` is gone with the assignment layer. A bar is emptied by
     switching its module off, which is a different question with a different
     answer, and the prompt should say so rather than silently doing nothing. ]]--
Stub.chat = {}
run("assign extras none")
local complained = false
for i = 1, table.getn(Stub.chat) do
    if string.find(Stub.chat[i], "unknown option") then complained = true end
end
check(complained, "a retired command is reported rather than ignored")

local before = OB.profile.locked
run("locked")
eq(OB.profile.locked, not before, "a bare boolean flips")

try("an unknown option is reported, not thrown", function() run("nonsense 5") end)
try("a bad value is reported, not thrown", function() run("scale banana") end)
try("profile list prints", function() run("profile") end)

run("test")
check(OB.testMode, "test starts the preview")
run("test")
check(not OB.testMode, "and stops it")

run("restack")
try("restack leaves a sane layout", function()
    for id, s in pairs(OB.profile.slots) do
        assert(s.y >= OB.POS_MIN and s.y <= OB.POS_MAX, id .. " y out of range")
    end
end)

-- ---------------------------------------------------------------------------
-- 20. bar ticks
-- ---------------------------------------------------------------------------

context = "ticks: "
OB = boot("WARRIOR", 1)

local tickBar = OB.modules.power.frame
local tickWidth = tickBar:GetWidth()

OB.SetBarTick(tickBar, 1, 0.5, false, 1, 1, 1, 1)
check(tickBar.ticks and tickBar.ticks[1], "a tick is built on demand")
check(tickBar.ticks[1].shown, "and shown once placed")
near(tickBar.ticks[1].points[1][4], tickWidth * 0.5, 0.01,
        "a tick sits at its fraction of the drawn width")

-- the same discipline as the fill and the spark: measured off the bar, and
-- mirrored rather than reversed when flipped
OB.SetBarTick(tickBar, 1, 0.25, true, 1, 1, 1, 1)
near(tickBar.ticks[1].points[1][4], -(tickWidth * 0.25), 0.01,
        "a flipped tick measures in from the other end")

OB.SetBarTick(tickBar, 1, nil, false, 1, 1, 1, 1)
check(not tickBar.ticks[1].shown, "no fraction hides the tick")

-- ---------------------------------------------------------------------------
-- 21. the distance readout reads the weapon, then picks a backend
-- ---------------------------------------------------------------------------

context = "distance weapon: "

--[[ What is in the ranged slot decides whose range is being asked about. A bow
     has a dead zone, a wand does not, and a relic is not a weapon at all. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true })
local range = OB.modules.distance

eq(range.weapon, "Bows", "the ranged slot is read")
eq(range.spell, "Auto Shot", "and mapped to the auto-attack it fires")
eq(range.minRange, 9, "with that spell's real minimum, from the engine")
eq(range.maxRange, 41, "and its real maximum")

--[[ **Which** auto-attack depends on the class, not on the weapon.

     A hunter with a gun fires Auto Shot; a warrior with the same gun fires Shoot
     Gun, and they do not reach the same distance. Mapping every gun to Auto Shot
     gave a warrior a hunter's range, and a target at forty yards read as in range
     with a gun that stops at thirty.

     The check has to be the *spellbook*. Nampower's GetSpellIdForName is a DBC
     lookup -- it answers "does this spell exist", which is true of Auto Shot for
     a warrior who will never cast it -- and asking it here is precisely what let
     the bug through. ]]--
OB = boot("WARRIOR", 1, { ranged = "Guns", nampower = true,
                          spellNames = { "Shoot Gun" },
                          spellRanges = { ["Auto Shot"] = { 9, 41 },
                                          ["Shoot Gun"] = { 8, 30 } } })
range = OB.modules.distance
eq(range.spell, "Shoot Gun", "a warrior with a gun fires Shoot Gun, not Auto Shot")
eq(range.maxRange, 30, "and gets its range, not the hunter's")

OB = boot("HUNTER", 0, { ranged = "Guns", nampower = true,
                         spellNames = { "Auto Shot" },
                         spellRanges = { ["Auto Shot"] = { 9, 41 },
                                         ["Shoot Gun"] = { 8, 30 } } })
range = OB.modules.distance
eq(range.spell, "Auto Shot", "a hunter with the same gun fires Auto Shot")
eq(range.maxRange, 41, "and reaches further")

-- and the reading follows: the warrior's forty-yard target is out of reach
OB = boot("WARRIOR", 1, { ranged = "Guns", nampower = true, unitPosition = true,
                          hasTarget = true, spellNames = { "Shoot Gun" },
                          spellRanges = { ["Shoot Gun"] = { 8, 30 } } })
range = OB.modules.distance
Stub.player.targetDistance = 40
range.nextPoll = 0
Stub.Tick(0.05, 2)
eq(range.state, "toofar", "forty yards is too far for a gun that stops at thirty")

--[[ A client that can answer neither question falls back to the *last*
     candidate -- the non-hunter one, which is both commoner and shorter, so a
     wrong guess errs towards refusing a shot rather than promising one. ]]--
OB = boot("WARRIOR", 1, { ranged = "Guns", spellNames = {} })
range = OB.modules.distance
eq(range.spell, "Shoot Gun", "with no spellbook to read, the shorter guess wins")
eq(range.maxRange, 30, "and its range with it")

--[[ Without Nampower there is nothing to ask, so the weapon *type* supplies the
     range instead. A guess, but an informed one -- and the alternative is no
     minimum at all, which would mean a hunter standing on top of a mob reading
     as in range while being unable to shoot. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows" })
range = OB.modules.distance
eq(range.minRange, 8, "with no engine to ask, the weapon type supplies a minimum")
eq(range.maxRange, 35, "and a maximum")

OB = boot("MAGE", 0, { ranged = "Wands", nampower = true })
range = OB.modules.distance
eq(range.spell, "Shoot", "a wand fires Shoot")
eq(range.minRange, 0, "and has no dead zone")

--[[ Paladins, shamans and druids carry a relic there. No auto-attack exists, so
     an assumed range stands and the bar stays a plain distance readout rather
     than nothing at all.

     That assumption used to be two sliders, Fallback Maximum Range and Fallback
     Dead Zone. They went because they were settings asking the wrong person:
     Nampower supersedes both with the client's own numbers and the assumed
     table covers every weapon without it, so the only case they ever reached was
     this one -- and nobody can usefully tune how far they can shoot with an idol
     they are not shooting. ]]--
OB = boot("PALADIN", 0, { ranged = "Librams", nampower = true })
range = OB.modules.distance
eq(range.weapon, "Librams", "a relic is still read")
check(range.spell == nil, "but fires nothing")
eq(range.maxRange, 30, "so an assumed range stands")
check(OB.profile.modules.distance.maxRange == nil,
        "and the fallback sliders are gone")

-- an empty ranged slot is the same case
OB = boot("WARRIOR", 1, { nampower = true })
check(OB.modules.distance.spell == nil, "an empty ranged slot has no auto-attack")

context = "distance backend: "

--[[ Probed best first, and every source is optional. Defaulting them off in the
     harness is deliberate -- see the note in boot(). ]]--
OB = boot("HUNTER", 0, { ranged = "Bows" })
eq(OB.modules.distance.backend.id, "bands",
        "a plain client falls back to interaction bands")
check(not OB.HasUnitXP(), "the stock UnitXP name is not mistaken for UnitXP_SP3")

OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true })
eq(OB.modules.distance.backend.id, "spell",
        "Nampower alone gives the engine's own range check")

OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true,
                         nampowerDistance = true })
eq(OB.modules.distance.backend.id, "precise",
        "a Nampower distance extension measures hostile units")

OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, unitPosition = true,
                         friendlyTarget = true })
eq(OB.modules.distance.backend.id, "precise",
        "and a position API beats it for a friendly unit it can measure")

--[[ **The same client, pointed at something it cannot measure.**

     SuperWoW's UnitPosition is friendly-only, and the availability question used
     to be asked about "player" -- which every client answers yes to, because you
     are always friendly to yourself. So precise was selected, declined for the
     hostile target, and the cascade carried the state on a backend with no
     yardage to give. Chosen-and-working on the panel, no number on screen: the
     reported "only works on friendly targets", exactly. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, unitPosition = true,
                         hasTarget = true, friendlyTarget = false })
eq(OB.modules.distance.backend.id, "spell",
        "a friendly-only measurer is not chosen for a hostile target")

--[[ And a *preferred* backend that cannot answer this unit is not asked.

     The backend is chosen once, at login, but whether it can measure a given
     unit is a property of the unit rather than of the client. On a SuperWoW-only
     install `precise` is picked from a standing start and then cannot touch a
     single mob -- so asking it first was a wasted trip through a client mod ten
     times a second, and it left the readout naming a backend that never once
     answered.

     Confirmed in game before it was fixed: `selected=precise available=false
     answered=spell`. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, unitPosition = true,
                         friendlyTarget = true, hasTarget = true })
range = OB.modules.distance
eq(range.backend.id, "precise", "a friendly target picks the measuring backend")

Stub.player.friendlyTarget = false
Stub.player.targetDistance = 20
local hostileState = range:Read()
eq(hostileState, "inrange", "and a hostile one still gets a state")
eq(range.answered.id, "spell", "from the backend that can actually answer it")

-- UnitXP is the older distance source and still works where it exists
OB = boot("HUNTER", 0, { ranged = "Bows", unitXP = true })
eq(OB.modules.distance.backend.id, "precise", "UnitXP measures too")
check(OB.HasUnitXP(), "the UnitXP_SP3 command probe recognises the extension")

--[[ **And recognises a build that passes unit tokens through.**

     SP3 replaces a global vanilla already owns, so a compatible build answering
     `UnitXP("player")` with the player's experience is entirely reasonable. A
     probe that concluded "stock API" from that number switched the extension off
     on a machine where it was installed and working -- which is what "we should
     have UnitXP_SP3 working now" turned out to mean.

     So the probe is on a shape the experience API cannot produce: it returns a
     number or nothing, never a boolean. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", unitXP = true, lineOfSight = true,
                         unitXPPassthrough = true })
eq(UnitXP("player"), Stub.player.xp or 0, "this build answers the stock question")
check(OB.HasUnitXP(), "and is still recognised as the extension")
eq(OB.modules.distance.backend.id, "precise", "so it is still used to measure")

-- a forced backend that cannot run here falls back rather than drawing nothing
OB = boot("HUNTER", 0, { ranged = "Bows" })
OB.profile.modules.distance.backend = "precise"
OB.modules.distance:Probe()
eq(OB.modules.distance.backend.id, "bands", "a forced backend that cannot run falls back")

--[[ Forcing a backend that cannot run usually falls back to the one already in
     use, so a message keyed off a *change* of backend would say nothing in the
     one case where the user is waiting to be told something. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows" })
local chatBefore = table.getn(Stub.chat)
OB.profile.modules.distance.backend = "precise"
OB.modules.distance:Probe()
check(table.getn(Stub.chat) > chatBefore,
        "forcing an unavailable backend says so even when the fallback is unchanged")

-- and does not keep saying it on every loading screen
chatBefore = table.getn(Stub.chat)
OB.modules.distance:Probe()
Stub.FireEvent("PLAYER_ENTERING_WORLD")
eq(table.getn(Stub.chat), chatBefore, "but only once")

--[[ **Yardage is a separate question from the state, and is asked separately.**

     It used to come only from whichever backend produced the state. On a
     Nampower client the engine's boolean check is the preferred backend, so it
     answered first, every time -- and it has no number to give. The readout sat
     blank on a client that could measure the distance perfectly well, which is
     the other half of "yardage is not working across all target types".

     Here the boolean check decides the colour and the exact source still fills
     in the number. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, nampowerDistance = true,
                         hasTarget = true })
range = OB.modules.distance
OB.profile.modules.distance.backend = "spell"
range:Probe()
eq(range.backend.id, "spell", "the boolean backend is the one selected")

Stub.player.targetDistance = 22
local spellState, spellYards = range:Read()
eq(spellState, "inrange", "and it is what decides the state")
eq(range.answered.id, "spell", "on its own terms")
near(spellYards, 22, 0.01, "but the yard count comes from the exact source anyway")

--[[ And nothing is invented where nothing can be measured: a client with no
     exact source still gets a state, and an empty number rather than a made-up
     one. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, hasTarget = true })
Stub.player.targetDistance = 22
local noState, noYards = OB.modules.distance:Read()
eq(noState, "inrange", "a client with no exact source still gets a state")
eq(noYards, nil, "and an empty yard count rather than an invented one")

-- ---------------------------------------------------------------------------
-- the range ladder: a distance out of a call that only answers yes or no
-- ---------------------------------------------------------------------------

context = "range ladder: "

--[[ IsSpellInRange is boolean, but a boolean against a *known threshold* is one
     bit of a distance. Ask about a spell reaching 35 yards and one reaching 40:
     0 then 1 puts the target between them.

     Three client facts make it work, all verified with /eqob rangedebug against
     a hostile NPC and all modelled in the stub. Asking by **id** answers for
     spells the player does not know, where asking by name does not; targeting
     restrictions are not applied, so a heal answers about a mob; and it answers
     about hostile units at all, which nothing else on a stock client does. ]]--
OB = boot("ROGUE", 0, { ranged = "Crossbows", nampower = true, hasTarget = true })
range = OB.modules.distance

local rungs = range.ladder
check(table.getn(rungs) > 0, "a ladder is built from the client's spell data")

--[[ Ordered, and **no rung has a minimum range**. Charge is in the candidate
     list precisely so this is exercised: it reads "out of range" both past 25
     yards and inside 8, so it is not one threshold but two, and a binary search
     over answers that are not ordered walks straight past the target. ]]--
local lastMax, sawCharge = 0, false
for i = 1, table.getn(rungs) do
    check(rungs[i].max > lastMax, "rung " .. i .. " is longer than the one before")
    lastMax = rungs[i].max
    if rungs[i].id == 100 then sawCharge = true end
end
check(not sawCharge, "and Charge, which has a dead zone, is filtered out")

--[[ The rungs the scan bought. 25 and 45 were the two worst gaps; 50 and 60
     extend the top. Five-yard resolution now runs unbroken from 0 to 50. ]]--
local byMax = {}
for i = 1, table.getn(rungs) do byMax[rungs[i].max] = true end

check(byMax[25], "a 25 yard rung, which closes the old 20-30 gap")
check(byMax[45], "and a 45")
check(byMax[50], "and a 50")
eq(lastMax, 100, "with 100 the longest, not the client's 50000 row")

--[[ **Capped, and the cap is not cosmetic.** The client holds a 0-50000 row --
     Eye of Kilrogg uses it -- and without a ceiling that becomes the top rung
     and the longest band reads "100-50000y", which is worse than admitting
     there is no upper bound at all. ]]--
check(not byMax[50000], "the 50000 yard row is not a rung")

--[[ The band, at distances chosen to land in different gaps between rungs. The
     35-40 case is the one the game actually produced: Fireball 0, Holy Light 1,
     on a rogue who knows neither spell. ]]--
local function bandAt(distance)
    Stub.player.targetDistance = distance
    local low, high = OB.LadderBand(range.ladder)
    return tostring(low) .. "-" .. tostring(high)
end

eq(bandAt(37), "35-40", "a target past Fireball but inside Holy Light")
eq(bandAt(3), "0-5", "one inside the shortest rung")
eq(bandAt(12), "10-15", "and one in the middle")
eq(bandAt(32), "30-35", "the band the crossbow's own limit falls in")
eq(bandAt(23), "20-25", "and the gap the scan closed is a band of its own now")
eq(bandAt(47), "45-50", "as is the far end")

--[[ Past the longest rung there is no upper bound to give, and saying so is a
     different answer from any band. ]]--
Stub.player.targetDistance = 250
local farLow, farHigh = OB.LadderBand(range.ladder)
eq(farLow, 100, "past everything askable, the longest rung is the floor")
eq(farHigh, nil, "with no ceiling invented above it")

--[[ It reaches the screen as a band, written as one. Rounding to a midpoint
     would fit the label better and claim a precision never measured -- which is
     the whole reason the ladder exists. ]]--
--[[ **One number, stepped to five yards, and the same steps for every kind of
     target.**

     A band is already on a step, because every rung is a multiple of five. An
     exact distance is floored onto the same steps -- so a friendly unit measured
     at 23 yards and a mob narrowed to the 20-25 band both read "20y", and the
     readout stops changing character depending on what is selected. It used to:
     exact sources cover friendly units and the ladder covers everything else, so
     one showed "23y" and the other "20-25y" for the same distance. ]]--
range.yards = nil
range.bandLow, range.bandHigh = 20, 25
eq(range:DistanceText(), "20y", "a band reads as its lower step")

range.yards = 23
eq(range:DistanceText(), "20y", "and an exact distance floors onto the same one")

--[[ The first step reads 5y rather than 0y: nothing is ever at zero, and "0y"
     reads as a failure rather than a distance. ]]--
range.yards = nil
range.bandLow, range.bandHigh = 0, 5
eq(range:DistanceText(), "<5y", "the closest band is open at the bottom and says so")
range.yards = 1
eq(range:DistanceText(), "<5y", "as is an exact distance inside it")

--[[ Past fifty the exact figure stops being useful and the rungs get coarse, so
     one honest ceiling beats a number pretending otherwise. ]]--
range.yards = nil
range.bandLow, range.bandHigh = 60, 100
eq(range:DistanceText(), "50y+", "everything past fifty shares a ceiling")
range.bandLow, range.bandHigh = 100, nil
eq(range:DistanceText(), "50y+", "including past the longest rung")
range.yards = 200
eq(range:DistanceText(), "50y+", "and an exact distance out there too")

--[[ The equipped attack's whole range is a separate, static fact and sits on the
     other side of the bar. Off by default: a number that never changes, on a bar
     whose job is to change, invites being read as the answer. ]]--
eq(OB.profile.modules.distance.showRange, false, "the spell range label ships off")
eq(range:SpellRangeText(), "[8-30y]", "and spells out the equipped attack's range")

--[[ **Walking out of the dead zone must not flash red on the way to green.**

     The too-close/too-far split used to be decided by CheckInteractDistance's
     duel band, about 9.9 yards, against a bow's real minimum -- and the two
     measure differently, one counting the target's combat reach and the other
     not. Crossing that disagreement painted the too-far colour for a moment
     between too-close and in-range: a red flicker at the exact moment the player
     is watching for green.

     The measured distance settles it instead. Coarse, but "below the minimum or
     not" is a coarse question, and unlike the interaction bands it answers for
     hostile units at all. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, hasTarget = true })
local walker = OB.modules.distance
check(walker.minRange > 0, "a bow has a dead zone")

local walk = {}
for step = 0, 30 do
    Stub.player.targetDistance = 2 + (step * 0.5)
    walker.nextPoll = 0
    Stub.Tick(0.05, 2)
    table.insert(walk, walker.state)
end

local flashed, seenClose = nil, false
for i = 1, table.getn(walk) do
    if walk[i] == "tooclose" then seenClose = true end
    if seenClose and walk[i] == "toofar" then flashed = i end
end

check(seenClose, "standing on top of the target reads as too close")
check(flashed == nil, "and walking out of it never flashes the too-far colour",
        "flashed at step " .. tostring(flashed))
eq(walk[table.getn(walk)], "inrange", "the walk ends in range")

--[[ End to end: a hostile target on a client with no exact-distance source at
     all -- which is this installation -- now gets a number where it used to get
     an empty label. ]]--
OB = boot("ROGUE", 0, { ranged = "Crossbows", nampower = true, hasTarget = true })
range = OB.modules.distance
Stub.player.targetDistance = 37
Stub.Tick(0.1, 6)
eq(OB.UnitDistance("target"), nil, "nothing here can measure exactly")
eq(range.bandLow, 35, "yet the ladder still brackets the target")
eq(range.bandHigh, 40, "from both sides")

--[[ **Measured every poll, not on a slower clock.**

     It was throttled to a quarter second while it only fed the readout. That
     stopped being safe once the too-close/too-far split started reading it: a
     band a quarter second old is a *wrong colour* for a quarter second while
     moving, which is worse than the flicker the split was changed to fix. Four
     DBC lookups ten times a second is not a cost worth a staleness bug. ]]--
Stub.player.targetDistance = 12
Stub.Tick(0.1, 1)
eq(range.bandLow, 10, "a band tracks the colour rather than lagging it")

--[[ And a target change measures at once rather than showing the previous
     target's distance until the clock comes round. ]]--
Stub.player.targetDistance = 3
Stub.FireEvent("PLAYER_TARGET_CHANGED")
eq(range.bandLow, nil, "a new target drops the old band immediately")
Stub.Tick(0.1, 2)
eq(range.bandHigh, 5, "and measures the new one without waiting")

-- and it stands down the moment something can measure exactly
OB = boot("ROGUE", 0, { ranged = "Crossbows", nampower = true, hasTarget = true,
                        nampowerDistance = true })
range = OB.modules.distance
Stub.player.targetDistance = 37
Stub.Tick(0.1, 6)
eq(range.bandLow, nil, "an exact source leaves no band behind")
near(range.yards, 37, 0.01, "and supplies the number itself")

--[[ **The scan that finds rungs nobody knew about.**

     "Is there a 25 yard rung?" is not a question to answer from memory. The
     client holds it in two tables -- the distinct min/max pairs, and which
     spells point at which pair -- so the scan reads the first to learn which
     bands exist at all and walks the second only to put a name to them.

     The stub deliberately has no 0-25 row. Whether vanilla has one is the open
     question, and a stub that supplied one would be answering it itself. ]]--
context = "range scan: "

OB = boot("ROGUE", 0, { ranged = "Crossbows", nampower = true })
local chatBase = table.getn(Stub.chat)
OB.RunRangeScan()

local scanText = ""
for i = chatBase + 1, table.getn(Stub.chat) do
    scanText = scanText .. Stub.chat[i] .. "\n"
end

check(string.find(scanText, "0%-5", 1) ~= nil, "the scan lists the range rows")
check(string.find(scanText, "0%-100", 1) ~= nil, "including the longest")
check(string.find(scanText, "dead zone", 1) ~= nil,
        "and marks the one with a minimum range as unusable")

--[[ A spell named for each usable band, which is what makes the output
     actionable: the id goes straight into LADDER_IDS. ]]--
check(string.find(scanText, "5y: id 2974  Wing Clip", 1) ~= nil,
        "each usable band names a spell that uses it")
check(string.find(scanText, "40y: id 635  Holy Light", 1) ~= nil, "all of them")

--[[ The question that prompted the scan, answered: there **is** a zero-minimum
     25 yard row, so the worst gap in the ladder closes. Note that the client
     also has a 10-25 row -- the two are different rows and only one is a
     threshold. ]]--
check(string.find(scanText, "25y: id 1906", 1) ~= nil,
        "a 25 yard rung exists and is named")

--[[ Rows with a minimum are listed so they can be seen, and never offered as
     rungs. A spell answering "out of range" from both directions is two
     thresholds rather than one, and the search assumes one. ]]--
check(string.find(scanText, "10%-40", 1) ~= nil,
        "a row with a minimum range is still listed")

local _, deadZones = string.gsub(scanText, "dead zone", "")
eq(deadZones, 5, "all five of them marked unusable")

context = "distance backend: "

--[[ The action backend **finds** its slot rather than being told.

     It used to be two settings: a 0-120 slider, and a "capture the next action
     you press" switch that replaced the global UseAction. The slider asked for a
     number that appears on no screen in the game, and the capture only worked if
     every bar addon in the chain still called the global at press time -- one
     that took its own reference at load never reached it. Both asked the user to
     supply something the addon already knows, since it works out the
     auto-attack's name two functions earlier. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows" })
OB.profile.modules.distance.backend = "action"
OB.modules.distance:Probe()
eq(OB.modules.distance.backend.id, "bands",
        "with the attack on no bar there is nothing to watch")

OB = boot("HUNTER", 0, { ranged = "Bows",
                         actionBar = { [25] = "Auto Shot", [3] = "Aimed Shot" } })
OB.profile.modules.distance.backend = "action"
OB.modules.distance:Probe()
eq(OB.modules.distance.actionSlot, 25, "the auto-attack is found on the bars")
eq(OB.modules.distance.backend.id, "action", "and the backend runs off it")

--[[ **And it re-scans when the bars change**, because the sweep run at login is
     the one most likely to find nothing.

     Confirmed in game: two runs of the same command on the same character, one
     reporting slot 42 and the next reporting no slot at all. ACTIONBAR_SLOT_CHANGED
     fires once per button while the bars populate, so the scan that happens
     during that populate sees a half-built bar. The rescan is deferred and
     collapsed rather than run per event, or a login would sweep 120 slots dozens
     of times in a second. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows" })
range = OB.modules.distance
eq(range.actionSlot, nil, "an empty bar at login finds nothing")

Stub.actionBar[64] = "Auto Shot"
Stub.FireEvent("ACTIONBAR_SLOT_CHANGED", 64)
eq(range.actionSlot, nil, "and the event alone does not sweep")

Stub.Tick(0.5, 8)
eq(range.actionSlot, 64, "but the deferred rescan finds it once the bars settle")

--[[ And a login queues that sweep on its own, without waiting for a button to
     move. Relying on the event alone meant a login that scanned a half-built bar
     and then sat still never looked again -- observed in game as a slot found on
     one session and missing on the next with nothing changed in between. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows" })
range = OB.modules.distance
Stub.actionBar[64] = "Auto Shot"
eq(range.actionSlot, nil, "the login sweep can miss a bar still populating")

Stub.FireEvent("PLAYER_ENTERING_WORLD")
Stub.Tick(0.5, 8)
eq(range.actionSlot, 64, "and a second sweep follows without any button moving")

--[[ The *player's* auto-attack, not any ranged spell that happens to be bound.
     A warrior with a gun fires Shoot Gun, so a bar holding Auto Shot is
     somebody else's button and watching it would read a hunter's range. ]]--
OB = boot("WARRIOR", 0, { ranged = "Guns", actionBar = { [11] = "Auto Shot" } })
eq(OB.modules.distance.spell, "Shoot Gun", "a warrior fires Shoot Gun")
eq(OB.modules.distance.actionSlot, nil, "so a bar holding Auto Shot is not a match")

-- ---------------------------------------------------------------------------
-- 22. the four states, from every backend
--
-- One bar coloured by state, so the state *is* the reading. Every backend has to
-- produce the same vocabulary, or a colour would mean different things depending
-- on what the client happens to have loaded.
-- ---------------------------------------------------------------------------

context = "distance states: "

local function readAt(m, distance)
    Stub.player.targetDistance = distance
    m.nextPoll = 0
    Stub.Tick(0.05, 2)
    return m.state
end

-- precise: a real distance against the weapon's real minimum and maximum
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true,
                         nampowerDistance = true,
                         hasTarget = true })
range = OB.modules.distance
eq(range.backend.id, "precise", "measuring")

eq(readAt(range, 3), "tooclose", "inside the dead zone is too close")
eq(readAt(range, 20), "inrange", "between the two is in range")
eq(readAt(range, 60), "toofar", "past the maximum is too far")
eq(range.yards, 60, "and the distance itself is reported")
eq(range.answered.id, "precise", "Nampower measures a hostile target")

-- a wand has no dead zone, so point blank is simply in range
OB = boot("MAGE", 0, { ranged = "Wands", nampower = true,
                       nampowerDistance = true,
                       hasTarget = true })
eq(readAt(OB.modules.distance, 1), "inrange", "point blank with a wand is fine")

--[[ The boolean backends cannot tell too-close from too-far by themselves --
     both come back as the same "no" -- so they split it on a melee check.
     Standing on top of a target you cannot shoot is the dead zone. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, hasTarget = true,
                         friendlyTarget = true })
range = OB.modules.distance
eq(range.backend.id, "spell", "the engine's own boolean")

eq(readAt(range, 3), "tooclose", "unable to shoot and in melee reads as too close")
eq(readAt(range, 20), "inrange", "in range is in range")
eq(readAt(range, 60), "toofar", "unable to shoot and far away reads as too far")
check(range.yards == nil, "a boolean backend reports no distance")

-- bands, the always-available fallback
OB = boot("HUNTER", 0, { ranged = "Bows", hasTarget = true,
                         friendlyTarget = true })
range = OB.modules.distance
eq(range.backend.id, "bands", "the coarse fallback")
eq(readAt(range, 5), "tooclose", "duel range with a dead zone is too close")
eq(readAt(range, 20), "inrange", "inspect range is shootable")
eq(readAt(range, 40), "toofar", "beyond it is not")

--[[ CheckInteractDistance answers nil for a unit you cannot interact with, which
     every hostile mob is. Reading that as an error rather than as "too far"
     would blank the readout on precisely the targets it exists for. ]]--
Stub.interactRefuses = true
eq(readAt(range, 5), "toofar", "a unit that refuses interaction reads as far")
Stub.interactRefuses = false

-- no target is its own state, in every backend
Stub.player.hasTarget = false
range.nextPoll = 0
Stub.Tick(0.05, 2)
check(range.state == nil, "no target means no state at all")

--[[ A backend that cannot answer must not read as "no target".

     They were the same nil, and that is the whole of the bug: the moment the
     preferred backend declined for a particular target -- IsSpellInRange
     answering -1, UnitPosition answering nothing for that unit -- the bar fell to
     the no-target colour with something plainly targeted. It looked like the
     colour never changing.

     A decline now falls through to the weaker backends. `bands` always answers,
     so a target always produces a state, and nil means only what it says. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, unitPosition = true,
                         hasTarget = true, friendlyTarget = true })
range = OB.modules.distance
eq(range.backend.id, "precise", "the preferred backend is the measuring one")

readAt(range, 20)
eq(range.state, "inrange", "which answers normally")
eq(range.answered.id, "precise", "and is the one that answered")

-- take the measurement away mid-session, as a client mod failing for one unit would
Stub.SetUnitPosition(false)
Stub.SetUnitXP(false)
readAt(range, 20)

check(range.state ~= nil, "a backend that declines does not read as no target")
check(range.answered ~= nil, "something else answered instead")
check(range.answered.id ~= "precise", "specifically a weaker backend",
        "got " .. tostring(range.answered and range.answered.id))

-- and no target is still no target, however many backends decline
Stub.player.hasTarget = false
range.nextPoll = 0
Stub.Tick(0.05, 2)
check(range.state == nil, "no target still reads as no target")
check(range.answered == nil, "with nothing having answered")

-- ---------------------------------------------------------------------------
-- 23. drawing: one bar, coloured by state
-- ---------------------------------------------------------------------------

context = "distance drawing: "
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true,
                         nampowerDistance = true,
                         hasTarget = true })
range = OB.modules.distance
local rangeCfg = OB.profile.modules.distance
local rangeBar = range.frame

check(rangeBar.fill ~= nil, "the readout is a single bar")
check(rangeBar.bars == nil, "with no segment children at all")

--[[ The live distance, stepped to five yards whatever the source. An exact
     measurement is floored onto the same steps a band already sits on, so the
     label does not change character depending on whether the target is friendly
     or hostile. ]]--
local stepped = { [1] = "<5y", [23] = "20y", [55] = "50y+" }
for _, yards in ipairs({ 1, 23, 55 }) do
    readAt(range, yards)
    eq(rangeBar.center.text, stepped[yards],
            "an exact " .. tostring(yards) .. " yards steps to " .. stepped[yards])
end

eq(rangeBar.left.text, "", "nothing is drawn on the left")
eq(rangeBar.right.text, "", "and the spell range is off by default")

rangeCfg.showText = false
OB.SetDirty(range)
Stub.Tick(0.05, 1)
eq(rangeBar.center.text, "", "the distance label can be switched off")
rangeCfg.showText = true

--[[ The equipped attack's whole range is the other, static fact, and it sits on
     the far side so it cannot be mistaken for the live one. ]]--
rangeCfg.showRange = true
readAt(range, 23)
eq(rangeBar.right.text, "[9-41y]", "and the spell range can be switched on")
eq(rangeBar.center.text, "20y", "alongside the live one, not instead of it")
rangeCfg.showRange = false

--[[ No ranged attack at all: the bar goes, whatever is targeted.

     A warrior with an empty ranged slot has nothing that can be in or out of
     range, so the question has no answer rather than a pessimistic one. It used
     to fall back to the configured range and advertise it, which is how a warrior
     holding no gun got told `[8-90y]` -- a confident interval describing a weapon
     that did not exist. ]]--
local noWeapon = boot("WARRIOR", 1, { hasTarget = true, nampower = true })
check(noWeapon.modules.distance.spell == nil, "an empty ranged slot has no auto-attack")
noWeapon.modules.distance.nextPoll = 0
Stub.Tick(0.05, 3)
check(not noWeapon.modules.distance.frame:IsShown(),
        "so the bar hides rather than inventing a range")

-- a relic is the same case: paladins, shamans and druids have no ranged attack
noWeapon = boot("PALADIN", 0, { ranged = "Librams", hasTarget = true, nampower = true })
noWeapon.modules.distance.nextPoll = 0
Stub.Tick(0.05, 3)
check(not noWeapon.modules.distance.frame:IsShown(), "a relic hides it too")

--[[ No line of sight is its **own** state and its own colour.

     Too far means walk closer; no line of sight means step around the thing in
     the way. Painting both red tells you to do the wrong one half the time, and
     standing well inside range wondering why nothing fires is exactly the half
     you needed. ]]--
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, nampowerDistance = true,
                         hasTarget = true, unitXP = true, lineOfSight = true })
range = OB.modules.distance
rangeBar = range.frame
rangeCfg = OB.profile.modules.distance
rangeCfg.losCheck = true

Stub.player.inSight = true
eq(readAt(range, 20), "inrange", "in sight and in range is in range")

Stub.player.inSight = false
eq(readAt(range, 20), "nolos", "blocked at the same distance is its own state")
near(rangeBar.fill.vertex[1], rangeCfg.noLosColor[1], 0.01, "with its own colour")
check(rangeCfg.noLosColor[1] ~= rangeCfg.tooFarColor[1],
        "which is not the too-far colour")

-- and the check is opt-in
rangeCfg.losCheck = false
eq(readAt(range, 20), "inrange", "with the check off, sight is not consulted")

--[[ **Without any client mod at all**, which is the case that actually ships.

     Vanilla will not let the addon *ask* about line of sight, but it does say
     so: a shot refused for it raises UI_ERROR_MESSAGE carrying
     SPELL_FAILED_LINE_OF_SIGHT. That makes the check reactive -- it knows only
     after something has been refused -- so it is a latch with an expiry, and the
     whole of the design follows from one asymmetry: silence is not sight. ]]--
context = "line of sight without a client mod: "

OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, nampowerDistance = true,
                         hasTarget = true })
range = OB.modules.distance
rangeBar = range.frame
rangeCfg = OB.profile.modules.distance
rangeCfg.losCheck = true

check(not OB.HasUnitXP(), "no UnitXP here, which is the point")
eq(readAt(range, 20), "inrange", "and with nothing refused yet, range is the answer")

Stub.FireEvent("UI_ERROR_MESSAGE", SPELL_FAILED_LINE_OF_SIGHT)
eq(readAt(range, 20), "nolos", "the client's own refusal is the signal")
near(rangeBar.fill.vertex[1], rangeCfg.noLosColor[1], 0.01, "and it gets the same colour")

--[[ It expires, because it is a claim about the future: it says "you were
     blocked a moment ago", and a moment is all that entitles it to. Nothing ever
     tells the addon the obstruction has cleared. ]]--
Stub.Tick(0.5, 5)
eq(readAt(range, 20), "inrange", "and it expires rather than sticking")

--[[ **How long it holds is the player's call.**

     Nothing ever confirms the wall has gone, so the window is a guess about the
     future and only the player knows how long a guess they want. A short one
     flickers; a long one lies for longer after stepping clear. ]]--
eq(rangeCfg.losWindow, 2, "the window ships at two seconds")

rangeCfg.losWindow = 0.5
Stub.FireEvent("UI_ERROR_MESSAGE", SPELL_FAILED_LINE_OF_SIGHT)
eq(readAt(range, 20), "nolos", "a shorter window still latches")
Stub.Tick(0.1, 3)
eq(readAt(range, 20), "nolos", "and holds inside it")
Stub.Tick(0.1, 4)
eq(readAt(range, 20), "inrange", "then clears sooner than the default would")

-- and the latch is left cold, so the checks below start from nothing
rangeCfg.losWindow = 2
Stub.FireEvent("PLAYER_TARGET_CHANGED")

--[[ Every refused action comes through UI_ERROR_MESSAGE. Reacting to all of
     them would put a wall in front of a target that was merely out of range, or
     that the player was facing away from. ]]--
Stub.FireEvent("UI_ERROR_MESSAGE", "Out of range.")
eq(readAt(range, 20), "inrange", "another error message is not this one")
check(not OB.IsLineOfSightError(nil), "and neither is nothing at all")

--[[ The latch describes one target. Carrying it across a target change would
     paint the new one blocked on the strength of a refusal about somebody
     else. ]]--
Stub.FireEvent("UI_ERROR_MESSAGE", SPELL_FAILED_LINE_OF_SIGHT)
Stub.FireEvent("PLAYER_TARGET_CHANGED")
eq(readAt(range, 20), "inrange", "and a new target starts the question again")

-- opt-in here too: the latch is still set, it is simply not consulted
rangeCfg.losCheck = false
Stub.FireEvent("UI_ERROR_MESSAGE", SPELL_FAILED_LINE_OF_SIGHT)
eq(readAt(range, 20), "inrange", "with the check off, the refusal is ignored")
rangeCfg.losCheck = true

--[[ A native query, which is the only thing that turns the check from reactive
     into continuous: it can be *polled*, so it answers before a shot is fired
     and it notices the obstruction clearing. Shaped like GetUnitDistance and
     preferred over UnitXP, because Nampower is what actually loads here. ]]--
context = "line of sight from a native query: "

OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, nampowerDistance = true,
                         hasTarget = true, nampowerSight = true })
range = OB.modules.distance
rangeCfg = OB.profile.modules.distance
rangeCfg.losCheck = true

Stub.player.inSight = false
eq(readAt(range, 20), "nolos", "blocked without anything having been fired")

Stub.player.inSight = true
eq(readAt(range, 20), "inrange", "and clear again the moment it is, with no expiry")

--[[ Continuous beats reactive: the latch can only ever say "blocked", so a
     stale refusal must not overrule a live query that says otherwise. ]]--
Stub.FireEvent("UI_ERROR_MESSAGE", SPELL_FAILED_LINE_OF_SIGHT)
eq(readAt(range, 20), "inrange", "a live yes outranks a stale refusal")

context = "distance drawing: "
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true, nampowerDistance = true,
                         hasTarget = true, unitXP = true, lineOfSight = true })
range = OB.modules.distance
rangeBar = range.frame
rangeCfg = OB.profile.modules.distance
Stub.player.inSight = true
Stub.player.inSight = true
readAt(range, 3)
near(rangeBar.fill.vertex[1], rangeCfg.tooCloseColor[1], 0.01, "too close has its colour")
readAt(range, 20)
near(rangeBar.fill.vertex[1], rangeCfg.inRangeColor[1], 0.01, "in range has its own")
readAt(range, 60)
near(rangeBar.fill.vertex[1], rangeCfg.tooFarColor[1], 0.01, "and too far another")

--[[ **Always full**, in every state and at every distance. The colour is the
     entire reading.

     An earlier draft drained the fill in proportion to distance. It looked
     informative and was not: at the moment the answer matters -- crossing in or
     out of range -- the fill is at its smallest and the colour has already said
     it. A bar that is sometimes a block of colour and sometimes a partial fill
     is two readouts wearing one rectangle. ]]--
for _, yards in ipairs({ 0, 3, 20, 41, 80 }) do
    readAt(range, yards)
    near(rangeBar.fill.width, rangeBar:GetWidth(), 0.5,
            "the bar is full at " .. yards .. " yards")
    check(rangeBar.fill.shown, "and drawn at " .. yards .. " yards")
end

-- nothing drains, so there is no crossing for a dead zone tick to mark
readAt(range, 20)
check(not (rangeBar.ticks and rangeBar.ticks[1] and rangeBar.ticks[1].shown),
        "no tick is drawn, because nothing moves past it")

-- The Nampower extension is the exact hostile-distance source when installed.
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true,
                         nampowerDistance = true,
                         hasTarget = true })
range = OB.modules.distance
rangeBar = range.frame
eq(readAt(range, 20), "inrange", "a hostile still gets a range state")
eq(range.yards, 20, "Nampower reports the hostile target's exact distance")
eq(rangeBar.center.text, "20y", "the exact hostile yards are shown")
eq(rangeBar.left.text, "", "and nothing is bracketed beside them")

-- return to a measured readout for the remaining draw and preview checks
OB = boot("HUNTER", 0, { ranged = "Bows", nampower = true,
                         nampowerDistance = true,
                         hasTarget = true })
range = OB.modules.distance
rangeCfg = OB.profile.modules.distance
rangeBar = range.frame

--[[ No target ships **visible**: #1f1f1f, a dark grey that is unmistakably on.

     It used to ship fully transparent, and that read as the feature being
     broken. The first thing anyone does after enabling a bar is look for it, and
     with nothing targeted there was nothing to find. A drawn placeholder answers
     the question the empty screen could not: the bar is here, it works, it has
     nothing to say yet. ]]--
near(rangeCfg.noTargetColor[1], 0.12, 0.01, "the no-target colour ships dark grey")
eq(rangeCfg.noTargetColor[4], 1, "and opaque")

Stub.player.hasTarget = false
range.nextPoll = 0
Stub.Tick(0.05, 2)
check(rangeBar:IsShown(), "so no target draws a placeholder")
near(rangeBar.fill.vertex[1], 0.12, 0.01, "in that colour")

--[[ Taking the alpha to 0 still hides the bar outright, background included,
     for anyone who preferred that -- the behaviour did not go away, it stopped
     being the default. ]]--
rangeCfg.noTargetColor = { 0, 0, 0, 0 }
range.nextPoll = 0
OB.SetDirty(range)
Stub.Tick(0.05, 2)
check(not rangeBar:IsShown(), "and zero opacity still hides it outright")

--[[ And it stays hidden through a refresh.

     OB.Toggle re-asserts every bar's visibility from its Show Bar setting, and
     it used to overrule a module that had decided it had nothing to draw. The
     bar came back with whatever colour it last held, which is what "the bar does
     not change colour from no target" looked like from the outside: a stale
     green with nothing targeted.

     OB.Refresh runs on combat, on every setting change and on every profile
     switch, so this was not a rare path. ]]--
OB.Refresh(true)
check(not rangeBar:IsShown(), "and stays hidden through a refresh")
Stub.Tick(0.05, 2)
check(not rangeBar:IsShown(), "and a frame later")

--[[ The preview has to walk **every** state the live readout can produce, or
     someone choosing their colours is picking swatches they cannot see.

     Four of the five fall out of a distance, so the sweep runs out past the
     readout's last step and back. The fifth does not: no amount of walking
     produces "blocked", so the preview stages it at the far end of the sweep.
     And the no-target colour is only reachable by dropping target -- which is
     exactly what ends the preview -- so that is staged too. ]]--
Stub.player.hasTarget = true
OB.SetTestMode(true)

local statesSeen = {}
local noTargetFrames = 0

for i = 1, 700 do
    Stub.Tick(0.05, 1)
    if range.state then
        statesSeen[range.state] = true
    else
        noTargetFrames = noTargetFrames + 1
    end
end

OB.SetTestMode(false)

local stateCount = 0
for _ in pairs(statesSeen) do stateCount = stateCount + 1 end
eq(stateCount, 4, "the preview walks every state a target can be in")
check(statesSeen["nolos"], "including the blocked colour, which no distance produces")

--[[ And then drops target for two seconds, which is the only way the fourth
     colour appears in a preview: seeing it for real means dropping target, and
     dropping target is exactly what ends the preview you were looking at. ]]--
check(noTargetFrames > 0, "the preview also shows the no-target state")
check(noTargetFrames > 20, "and holds it long enough to see",
        "held for " .. noTargetFrames .. " frames of 0.05s")

-- ---------------------------------------------------------------------------
-- 24. the ranged swing timer
-- ---------------------------------------------------------------------------

context = "ranged swing: "
OB = boot("HUNTER", 0, { rangedSpeed = 3.0 })

Stub.FireEvent("START_AUTOREPEAT_SPELL")
check(OB.swing.shooting, "autorepeat starts the ranged cycle")
local anchor = OB.swing.rangedStart

--[[ CHAT_MSG_SPELL_SELF_DAMAGE carries every spell, not just the auto shot, and
     this phase cannot read the source out of the message. It is filtered by
     timing instead: a shot can only land at the end of its own cycle. ]]--
Stub.Tick(0.5, 1)
Stub.FireEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
eq(OB.swing.rangedStart, anchor,
        "an instant cast early in the cycle does not move the anchor")

Stub.Tick(0.5, 5)
Stub.FireEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
check(OB.swing.rangedStart > anchor, "a shot landing late in the cycle re-anchors it")

-- melee and ranged are separate cycles with separate toggles
check(not OB.swing.attacking, "shooting is not auto attacking")

Stub.FireEvent("STOP_AUTOREPEAT_SPELL")
check(not OB.swing.shooting, "stopping autorepeat stops the cycle")

-- ---------------------------------------------------------------------------
-- 25. rage decay is measured, never assumed
-- ---------------------------------------------------------------------------

context = "rage decay: "
OB = boot("WARRIOR", 1, { power = 100, powerMax = 100 })

local rage = OB.modules.power
OB.profile.modules.power.rageDecay = true

local function setRage(value)
    Stub.player.power = value
    Stub.Tick(0.5, 1)
end

-- rage sitting still does not start a run, or a bar parked at full would grow a
-- marker pointing at a number it is never going to reach
setRage(100)
check(rage.decayFrom == nil, "rage holding still does not start a run")

setRage(98)     -- the first actual fall anchors it
setRage(96)
check(rage.rageRate ~= nil, "a run of falling rage yields a rate")
near(rage.rageRate, 4, 0.01, "and it is the rate that was actually fed in")

-- spending rage is a cost, not the bar draining. Averaging it in would put the
-- marker on the floor.
rage.rageRate, rage.decayFrom = nil, nil
setRage(100)
setRage(60)
check(rage.rageRate == nil, "a spend does not become a decay rate")
check(rage.decayFrom == nil, "and it ends the run")

rage.decayFrom = { at = Stub.Clock(), value = 60 }
setRage(70)
check(rage.decayFrom == nil, "a gain ends the run too")

-- the marker points at where the rate says rage will be, and only while it falls
rage.rageRate = 3
rage.decayFrom = { at = Stub.Clock(), value = 70 }
OB.profile.modules.power.rageDecaySeconds = 5
OB.SetDirty(rage)
Stub.Tick(0.05, 2)

local rageTick = rage.frame.ticks and rage.frame.ticks[1]
check(rageTick and rageTick.shown, "the marker is drawn while rage is falling")
near(rageTick.points[1][4], rage.frame:GetWidth() * ((70 - 15) / 100), 0.5,
        "at the projected value")

rage.decayFrom = nil
OB.SetDirty(rage)
Stub.Tick(0.05, 2)
check(not rageTick.shown, "and hidden once it stops falling")

-- ---------------------------------------------------------------------------
-- 26. the druid secondary mana estimate
-- ---------------------------------------------------------------------------

context = "druid mana: "

local druidWorld = {
    power = 3000, powerMax = 3000,
    stats = { 20, 20, 20, 120, 100 },        -- 4 intellect, 5 spirit
    spellbook = { "Interface\\Icons\\Ability_Racial_BearForm" },
    spellCount = 1,
    tooltips = {
        spell1 = { "Bear Form", "60 Mana" },
        item1 = { "A Helm", "Equip: Restores 10 mana per 5 sec." },
    },
}

OB = boot("DRUID", 0, druidWorld)
local mana = OB.modules.druidmana

eq(OB.bound.secondary and OB.bound.secondary.id, "druidmana",
        "a druid has a secondary resource bar")
eq(mana.shiftCost, 60, "the shapeshift cost is read off the spellbook tooltip")

--[[ ceil((10 * 2) / 5): mana per five seconds restated per two second tick. The
     source library's accumulator was `extra or 0 + n`, which is `extra or (0+n)`
     -- and extra starts at 0, which is truthy -- so gear never counted at all. ]]--
eq(mana.gearTick, 4, "gear mana per five is counted, and restated per tick")

eq(mana.max, 3000, "caster form seeds the estimate from the real pool")
eq(mana.cur, 3000, "including the current value")
check(mana.seeded, "and marks the estimate as having a baseline")

-- shifting costs mana, and once shifted nothing reports it any more
Stub.player.powerType = 3
Stub.FireEvent("UPDATE_SHAPESHIFT_FORMS")
eq(mana.cur, 2940, "shifting pays the cost the tooltip named")

--[[ While shifted UNIT_MANA still fires, for energy -- on the same two second
     cadence mana regeneration runs on. The event nobody can use for mana is
     used as the clock for it. ]]--
Stub.FireEvent("UNIT_MANA", "player")
eq(mana.cur, 2940 + (math.ceil(100 / 5) + 15) + 4,
        "each tick accrues spirit regeneration plus gear")

-- intellect moving while shifted moves the ceiling with it
Stub.player.stats[4] = 130
Stub.FireEvent("UNIT_MAXMANA", "player")
eq(mana.max, 3000 + (10 * 15), "intellect gained while shifted raises the maximum")

Stub.player.powerType = 0
Stub.player.power = 1000
Stub.FireEvent("UPDATE_SHAPESHIFT_FORMS")
eq(mana.cur, 1000, "returning to caster form resyncs from an API telling the truth")

--[[ Logging in already shifted means the real pool has never been visible this
     session. The source library shipped a maximum of 10 for that case and drew a
     full bar on it; there is nothing to estimate from, so nothing is drawn. ]]--
OB = boot("DRUID", 3, druidWorld)
mana = OB.modules.druidmana
OB.profile.slots.distance.show = true
OB.Refresh(true)
Stub.Tick(0.05, 2)

check(not mana.seeded, "a druid who logs in shifted has no baseline")
check(not mana.frame:IsShown(), "and the bar stays hidden rather than inventing one")

-- ---------------------------------------------------------------------------
-- 26b. a bar with nothing to draw hides itself
--
-- SetBarFill(0) hides the fill and leaves the background painted, which is an
-- empty trough -- and an empty trough reads as a bar that has broken rather than
-- one with nothing to say. The first thing anyone asked about it was why their
-- off hand timer was stuck at zero.
-- ---------------------------------------------------------------------------

context = "empty bars: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { offSpeed = 1.7, ranged = "Bows" })
OB.profile.slots.distance.show = true
OB.Refresh(true)
Stub.Tick(0.05, 2)

check(OB.modules.offhand.frame:IsShown(), "an equipped off hand draws its bar")

-- unequip it
Stub.player.offSpeed = 0
Stub.Tick(0.05, 2)
check(not OB.modules.offhand.frame:IsShown(),
        "with nothing in the off hand the whole bar goes, background and all")

Stub.player.offSpeed = 1.7
Stub.Tick(0.05, 2)
check(OB.modules.offhand.frame:IsShown(), "and comes back when something is equipped")

--[[ The distance readout is the deliberate exception, and only for no target: it
     paints a dark grey placeholder instead of vanishing, because a bar that is
     simply absent reads as a bar that is broken. It still hides outright for the
     cases where it has nothing it *could* say -- no ranged weapon at all -- and
     it hides for no target too if the colour is taken to zero opacity. ]]--
Stub.player.hasTarget = true
OB.modules.distance.nextPoll = 0
Stub.Tick(0.05, 3)
check(OB.modules.distance.frame:IsShown(), "a target gives the distance bar something to say")

Stub.player.hasTarget = false
OB.modules.distance.nextPoll = 0
Stub.Tick(0.05, 3)
check(OB.modules.distance.frame:IsShown(), "and no target leaves a visible placeholder")

-- ---------------------------------------------------------------------------
-- 27. slots became bars
--
-- The migration that renamed six slots into eight bars, dropped the assignment
-- layer and restacked. A tuned layout has to survive the rename intact -- the
-- rename is the whole reason a migration exists rather than a defaults change.
-- ---------------------------------------------------------------------------

context = "migration: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { savedVariables = {
    version = 1,
    migrated = { roguebars = true },
    chars = { ["Turtle WoW - TestROGUE"] = "Default" },
    profiles = { Default = {
        schema = 2,
        assign = { ["*"] = { aux = "none" }, ROGUE = { points = "health" } },
        slots = {
            -- a layout somebody tuned: narrower, taller, nudged right
            -- a schema 2 profile carries `hide`, not `show`
            swingA = { x = 40, y = 93, w = 150, h = 20, textSize = 14,
                       hide = false, flip = true, bg = { 1, 0, 0, 0.3 } },
            points = { x = 40, y = 115, w = 150, h = 10, hide = true },
            aux    = { x = 40, y = 38,  w = 150, h = 14 },
        },
        modules = {
            swing_main = { decimals = 2, deplete = true, swap = true },
            --[[ Saved values, not absences: a merged-in default would satisfy
                 the schema 9 and 10 assertions without either migration running
                 at all, which is exactly the kind of test that passes forever
                 and checks nothing. ]]--
            range = { maxRange = 41, actionSlot = 25, capture = true,
                      noTargetColor = { 0, 0, 0, 0 } },

            --[[ The threat meter as it was phrased before the panel settled on
                 one wording for the idea. Saved as `false`, which is the value
                 that would be silently lost: a migration that only renamed the
                 key would hand this profile the new default and switch the
                 meter back on out of combat. ]]--
            threat = { showOutOfCombat = false },
            --[[ Same shape of problem one schema later: a boolean whose whole
                 caption was a sentence, replaced by a two-entry list. ]]--
            chat = { localTime = false, nameColorMode = 3, nameCommon = true,
                     nameColor = { 0.2, 0.4, 0.9, 1 },
                     urlBrackets = false, space = false, format = 11 },
        },
    } },
} })

eq(OB.profile.schema, 20, "an old profile is migrated forward")

--[[ **A rename that inverts has to invert the saved value too.** "Show Out Of
     Combat" and "Hide Out Of Combat" are the same checkbox facing opposite
     ways, and carrying the old value across unchanged means everybody who had
     turned the meter off out of combat gets it turned back on. ]]--
eq(OB.profile.modules.threat.hideOutOfCombat, true,
        "a meter that was not shown out of combat is now hidden out of combat")
check(OB.profile.modules.threat.showOutOfCombat == nil, "and the old key is gone")

--[[ **A boolean that became a list carries its answer across.** `localTime =
     false` meant the server's clock, which is entry two -- dropping the key and
     letting the default supply one would put everybody back on their own. ]]--
eq(OB.profile.modules.chat.timeSource, 2,
        "a profile reading the server clock still reads the server clock")
check(OB.profile.modules.chat.localTime == nil, "and that old key is gone too")

--[[ **A three-way list becomes a checkbox and a second swatch.** Mode one was
     by class, so the checkbox goes on; the other two were not, so it goes off
     and whatever the one colour was becomes both swatches -- which is what those
     modes actually looked like. ]]--
eq(OB.profile.modules.chat.nameClassColor, false,
        "a profile not colouring by class still is not")
eq(OB.profile.modules.chat.nameKnownColor[3], 0.9,
        "and its one colour became the known swatch")
check(OB.profile.modules.chat.nameColorMode == nil, "the old list is gone")
check(OB.profile.modules.chat.nameCommon == nil, "and so is its companion")

--[[ **False was bare, which is entry three** -- not entry two. Getting that
     backwards would put angle brackets on the links of everybody who had turned
     them off. ]]--
eq(OB.profile.modules.chat.urlBrackets, 3,
        "a profile with link brackets off gets the bare entry")
check(OB.profile.modules.chat.space == nil,
        "and the timestamp space stops being a setting")

--[[ **Twelve combinations become three answers.** Index 11 was a twelve-hour
     clock with seconds, a meridiem and no padding, so it maps to all three of
     those rather than to the nearest single thing. ]]--
eq(OB.profile.modules.chat.hour12, true, "an old format index gives its clock")
eq(OB.profile.modules.chat.meridiem, true, "its meridiem")
eq(OB.profile.modules.chat.timeShape, 2, "and its shape")
check(OB.profile.modules.chat.format == nil, "and the index is gone")

--[[ `hide` became `show`, inverted. A schema-2 profile carries no `show` at all,
     so the default supplies one and the migration has to overwrite it from the
     saved `hide` -- getting that backwards would silently reveal every bar
     somebody had switched off. ]]--
eq(OB.profile.slots.mainhand.show, true, "a bar that was not hidden is now shown")
eq(OB.profile.slots.extras.show, false, "and one that was hidden stays switched off")
check(OB.profile.slots.mainhand.hide == nil, "the old key is gone")

-- geometry survives the rename, all of it except the Y the restack rewrites
local mainhand = OB.profile.slots.mainhand
check(mainhand ~= nil, "swingA became mainhand")
eq(mainhand.w, 150, "a tuned width survives")
eq(mainhand.h, 20, "and height")
eq(mainhand.x, 115, "and X converts to a centre: 40 + half of 150")
eq(mainhand.textSize, 14, "and text size")
eq(mainhand.flip, true, "and flip")
near(mainhand.bg[1], 1, 0.001, "and background colour")

check(OB.profile.slots.swingA == nil, "the old id is gone")
check(OB.profile.slots.extras ~= nil, "points became extras")
check(OB.profile.slots.distance ~= nil, "aux became distance")
check(OB.profile.slots.ranged ~= nil, "and the two new bars arrive from defaults")
check(OB.profile.slots.secondary ~= nil, "both of them")

-- module settings move with their ids
eq(OB.profile.modules.mainhand.decimals, 2, "module settings follow the rename")
eq(OB.profile.modules.mainhand.deplete, true, "all of them")
eq(OB.profile.modules.distance.showText, true, "range became distance")
check(OB.profile.modules.swing_main == nil, "and the old keys are gone")

--[[ Schema 10: text sides became text positions, and the fallback range sliders
     went. A saved Swap Text Sides converts to the two endpoints of the position
     slider, so nothing anybody had set moves. ]]--
eq(OB.profile.modules.mainhand.timerPos, 100, "a swapped timer lands on the right")
eq(OB.profile.modules.mainhand.speedPos, 0, "and its speed on the left")
check(OB.profile.modules.mainhand.swap == nil, "with the boolean gone")
check(OB.profile.modules.distance.maxRange == nil, "the fallback range is dropped")
check(OB.profile.modules.distance.deadZone == nil, "and the fallback dead zone")

--[[ Schema 9: an invisible no-target bar was never a decision.

     Zero opacity was the *shipped* default, so anyone still on it got an
     invisible bar rather than choosing one -- constraint 29 again. It converts.
     The two action settings go with it: the slot is found now, so a stored
     number is a stale answer to a question nobody is asked any more. ]]--
near(OB.profile.modules.distance.noTargetColor[1], 0.12,
        0.001, "an untouched invisible no-target colour becomes the grey")
near(OB.profile.modules.distance.noTargetColor[4], 1, 0.001, "and opaque")
check(OB.profile.modules.distance.actionSlot == nil, "the watched slot is dropped")
check(OB.profile.modules.distance.capture == nil, "and so is capture")

-- the assignment layer is dropped outright, including a deliberate one
check(OB.profile.assign == nil, "the assignment table is dropped")
eq(OB.bound.extras and OB.bound.extras.id, "combopoints",
        "so a slot that had been reassigned goes back to its own module")

--[[ Restacked in the new order, and the cluster stays where it was rather than
     jumping to the shipped default -- the top of the old stack becomes the top
     of the new one. ]]--
eq(OB.profile.slots.health.y + (OB.profile.slots.health.h / 2), 115,
        "the stack keeps its old top edge")

local lastY
for i = 1, table.getn(OB.barOrder) do
    local bar = OB.profile.slots[OB.barOrder[i]]
    if lastY then
        check(bar.y < lastY, OB.barOrder[i] .. " sits below the bar before it")
    end
    lastY = bar.y
end

--[[ A profile already on schema 3 is left entirely alone.

     The tuned value has to be somewhere the bar can actually sit: positions are
     bounded to the screen on load now, so a test coordinate off the edge would
     be corrected and read as a restack that did not happen. ]]--
local tuned = EquadisClassicOverhaulDB
tuned.profiles.Default.slots.health.y = 200
OB = boot("ROGUE", 3, { savedVariables = tuned })
eq(OB.profile.slots.health.y, 200, "a current profile is not restacked again")

--[[ The Distance bar survives the upgrade switched on.

     This is the regression the schema 5 step exists for, and it is worth a test
     of its own because the migration that caused it was *correct* in isolation:
     `aux` shipped hidden, so inverting `hide` into `show` faithfully produced
     `show = false` -- turning a shipped default into what looks like a decision.
     Every existing profile lost the Distance bar while new ones kept it.

     Booted from a profile shaped exactly the way v0.2 wrote one, rather than a
     synthetic fragment, because the whole failure was in what the *defaults* of
     that version happened to be. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("WARRIOR", 1, { name = "Upgrader", savedVariables = {
    version = 1,
    migrated = { roguebars = true },
    chars = { ["Turtle WoW - Upgrader"] = "Default" },
    profiles = { Default = {
        schema = 2,
        assign = { ["*"] = { points = "auto", swingB = "auto", swingA = "auto",
                             resource = "auto", health = "auto", aux = "auto" } },
        slots = {
            points   = { x = 0, y = 115, w = 200, h = 8,  hide = false },
            swingB   = { x = 0, y = 106, w = 200, h = 12, hide = false },
            swingA   = { x = 0, y = 93,  w = 200, h = 12, hide = false },
            resource = { x = 0, y = 80,  w = 200, h = 24, hide = false },
            health   = { x = 0, y = 55,  w = 200, h = 16, hide = false },
            aux      = { x = 0, y = 38,  w = 200, h = 12, hide = true },
        },
    } },
} })

eq(OB.profile.slots.distance.show, true,
        "the Distance bar is on after upgrading from a v0.2 profile")

-- every other bar came through switched on too, since all of them shipped visible
local anyOff
for i = 1, table.getn(OB.barOrder) do
    local id = OB.barOrder[i]
    if not OB.profile.slots[id].show then anyOff = id end
end
check(anyOff == nil, "and no bar came out of the upgrade switched off",
        "found " .. tostring(anyOff))

-- a bar the user really did switch off after the flip stays off
OB.profile.slots.mainhand.show = false
local kept = EquadisClassicOverhaulDB
OB = boot("WARRIOR", 1, { name = "Upgrader", savedVariables = kept })
eq(OB.profile.slots.mainhand.show, false, "a deliberate choice made since is kept")

--[[ The other half of constraint 29, and the half that is easy to forget: a
     colour somebody picked is a decision and survives schema 9 untouched, even
     though the default it replaced did not. Only an exact match against what
     shipped is rewritten. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("HUNTER", 0, { name = "Picky", savedVariables = {
    version = 1,
    migrated = { roguebars = true },
    chars = { ["Turtle WoW - Picky"] = "Default" },
    profiles = { Default = {
        schema = 8,
        modules = { distance = { noTargetColor = { 0.4, 0.1, 0.6, 0.25 } } },
    } },
} })
near(OB.profile.modules.distance.noTargetColor[1], 0.4, 0.001,
        "a chosen no-target colour survives schema 9")
near(OB.profile.modules.distance.noTargetColor[4], 0.25, 0.001, "alpha and all")

--[[ One background for every bar: black at 50%, and the distance readout
     transparent because it is always full and coloured, so its background can
     only ever muddy the state colour.

     Constraint 29 applied properly this time: only a value that still equals the
     old shipped default is rewritten. The swing bars shipped at 80% and nobody
     chose that; a background somebody picked themselves is left alone. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { name = "Backgrounds", savedVariables = {
    version = 1,
    migrated = { roguebars = true },
    chars = { ["Turtle WoW - Backgrounds"] = "Default" },
    profiles = { Default = {
        schema = 6,
        slots = {
            mainhand  = { bg = { 0, 0, 0, 0.8 } },   -- the old default
            offhand   = { bg = { 0, 0, 0, 0.8 } },   -- likewise
            ranged    = { bg = { 0.2, 0.4, 0.6, 1 } },  -- a picked colour
            distance  = { bg = { 0, 0, 0, 0.5 } },   -- the old default
            health    = { bg = { 0, 0, 0, 0.5 } },   -- already correct
        },
    } },
} })

near(OB.profile.slots.mainhand.bg[4], 0.5, 0.001, "an untouched swing background normalises")
near(OB.profile.slots.offhand.bg[4], 0.5, 0.001, "both of them")
near(OB.profile.slots.distance.bg[4], 0, 0.001, "and the distance readout goes transparent")
near(OB.profile.slots.health.bg[4], 0.5, 0.001, "one already correct is untouched")

near(OB.profile.slots.ranged.bg[1], 0.2, 0.001, "a background somebody picked is left alone")
near(OB.profile.slots.ranged.bg[4], 1, 0.001, "opacity included")

-- and every shipped default now agrees
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
for i = 1, table.getn(OB.barOrder) do
    local id = OB.barOrder[i]
    local bg = OB.profile.slots[id].bg
    local want = 0.5
    if id == "distance" then want = 0 end

    near(bg[1] + bg[2] + bg[3], 0, 0.001, id .. " ships black")
    near(bg[4], want, 0.001, id .. " ships at the right opacity")
end

--[[ x and y are the bar's **centre**, and x = 0 is the middle of the screen.

     They used to be the top-left corner, so x = 0 put a 200-wide bar half its
     width off to the right -- every layout began by working out a number nobody
     should have had to.

     Y always converts, so nothing moves vertically. X only converts when it was
     *not* the untouched default of 0, which is constraint 29: nobody chose the
     off-centre position, so an untouched bar lands where the setting always
     claimed it would. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { name = "Centred", savedVariables = {
    version = 1,
    migrated = { roguebars = true },
    chars = { ["Turtle WoW - Centred"] = "Default" },
    profiles = { Default = {
        schema = 7,
        slots = {
            health   = { x = 0,  y = 115, w = 200, h = 16 },  -- untouched
            resource = { x = 40, y = 98,  w = 150, h = 24 },  -- positioned
        },
    } },
} })

local centred = OB.profile.slots.health
eq(centred.y, 107, "an untouched bar's centre is half its height below the old top")
eq(centred.x, 0, "and its X stays 0, which now means centred")

local cl, cr, ct, cb = OB.EdgesOf(centred)
eq(ct, 115, "so it spans exactly where it did vertically")
eq(cb, 99, "top and bottom both")
eq(cl, -100, "and is now centred horizontally")
eq(cr, 100, "half its width each side of zero")

local moved = OB.profile.slots.resource
eq(moved.x, 115, "a bar somebody positioned converts instead")
local ml, mr, mt = OB.EdgesOf(moved)
eq(ml, 40, "so its left edge is exactly where they left it")
eq(mt, 98, "and its top")

-- every shipped default is centred
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
for i = 1, table.getn(OB.barOrder) do
    local id = OB.barOrder[i]
    local s = OB.profile.slots[id]
    local l, r = OB.EdgesOf(s)
    eq(s.x, 0, id .. " ships at x = 0")
    eq(l, -(s.w / 2), id .. " sits half its width left of centre")
    eq(r, s.w / 2, "and half to the right")
end

-- and the frame is anchored centre to centre, not corner to corner
local anchored = OB.bound.health.frame.points[1]
eq(anchored[1], "CENTER", "bars anchor by their centre")
eq(anchored[3], "CENTER", "to the container's centre")
eq(anchored[5], OB.profile.slots.health.y, "at exactly the stored offset")

-- ---------------------------------------------------------------------------
-- 28. the panel fails one control at a time
--
-- A settings panel is a hundred small independent controls, so the blast radius
-- of one bad control ought to be that control. It was not: a font string with no
-- font object threw inside one row, which took its page, which took the whole
-- build, which left a window with one category and no rows -- cached as the
-- panel for the rest of the session.
--
-- Faults are injected by wrapping CreateFrame to throw for one chosen name,
-- which is the same seam the real bug came through.
-- ---------------------------------------------------------------------------

context = "fail-soft: "

local realCreateFrame = CreateFrame

-- throw for one frame name, leave every other creation alone
local function breakFrame(target)
    CreateFrame = function(ftype, name, parent, template)
        if name == target then error("injected fault in " .. tostring(name), 0) end
        return realCreateFrame(ftype, name, parent, template)
    end
end

local function unbreakFrame()
    CreateFrame = realCreateFrame
end

-- (1) a construction fault costs exactly one row
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
breakFrame("EqOBCheck_global_x_audible")
try("a bad control does not stop the build", function() OB.TogglePanel() end)
unbreakFrame()

check(OB.settings ~= nil, "the panel is still built")
eq(table.getn(OB.settings.categories), 14, "and still has every category")
check(OB.widgets["global::audible"] == nil, "the failed row was dropped, not half-placed")
eq(table.getn(OB.panelFaults), 1, "exactly one fault was recorded")
check(string.find(OB.panelFaults[1].label or "", "audible") ~= nil,
        "and it names the control that failed")

-- (2) a page fault costs that page's remainder, not the pages after it.
--     This is the regression, in the exact shape it shipped.
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
breakFrame("EqOBProfileName")
try("a bad page does not stop the panel", function() OB.TogglePanel() end)
unbreakFrame()

check(OB.settings ~= nil, "the panel survives a page that throws")
eq(table.getn(OB.settings.categories), 14, "every category still exists")
check(OB.settings.btnTest ~= nil, "the chrome after the pages is still built")
eq(OB.settings.selected, "OmniBars", "and a category is selected")

--[[ **And it is a category that exists**, which is not the same assertion and is
     the one that was failing silently.

     The panel opened on "General" for as long as there was a General tab. There
     has not been one since its rows became the first entry in the bars column,
     and nothing noticed: `selectCategory` matches by name, so a name matching
     nothing hides every page, highlights no button and leaves the window blank
     until somebody clicks something. The old assertion passed the whole time,
     because it compared the stored name against the same wrong literal.

     Driven off the category list rather than a literal, so it cannot rot the
     same way when a tab is next renamed. ]]--
--[[ Not a local: the main chunk is at Lua 5.0's two hundred limit. ]]--
opensOn = false

for i = 1, table.getn(OB.settings.categories) do
    if OB.settings.categories[i].name == OB.settings.selected then
        opensOn = true
    end
end

check(opensOn, "and it is a category that actually exists",
        "opens on: " .. tostring(OB.settings.selected))

-- (3) an update fault hides one row, and says so exactly once
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

--[[ A list whose values function throws reaches the fault through Update rather
     than through construction, which is the other half of the guard. ]]--
table.insert(OB.modules.health.options,
        { "Exploding Row", "__boom", function() error("boom", 0) end })
OB.optionIndex.modules.health["__boom"] = nil

try("a row that throws on update does not stop the panel", function()
    OB.TogglePanel()
end)

local boom = OB.widgets["module:health:__boom"]
check(boom ~= nil, "the exploding row was built")
if boom then
    check(boom.broken, "a row that throws on update is marked broken")
    check(not boom:IsShown(), "and hidden")
end

-- the remaining rows on that page are untouched
local healthPageOk = true
for i = 1, table.getn(OB.settings.categories) do
    local page = OB.settings.categories[i].page
    for r = 1, table.getn(page.rows) do
        local widget = page.rows[r]
        if widget.visible and widget:GetNumPoints() == 0 then healthPageOk = false end
    end
end
check(healthPageOk, "every other visible row is still anchored")

--[[ The anti-spam property, and the reason `broken` is a flag rather than a
     report: RefreshPanel runs from a slider's OnValueChanged, so a fault that
     merely printed would say the same sentence every frame while dragging. ]]--
local faultsAfterFirst = table.getn(OB.panelFaults)
for i = 1, 5 do OB.RefreshPanel() end
eq(table.getn(OB.panelFaults), faultsAfterFirst,
        "a broken row is reported once, not on every refresh")

-- (4) a fault in the chrome leaves no panel at all, rather than a corpse
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
breakFrame("EquadisClassicOverhaulSettings")
try("an unbuildable panel does not raise", function() OB.TogglePanel() end)
unbreakFrame()

check(OB.settings == nil, "a failed build is not cached as the panel")
check(type(OB.panelDead) == "string", "the reason is kept")

local framesBefore = table.getn(Stub.Frames())
try("a second attempt does not rebuild", function() OB.TogglePanel() end)
eq(table.getn(Stub.Frames()), framesBefore,
        "and does not leak a second set of globally named widgets")

-- (5) layout is pure: running it twice with no update between changes nothing
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.TogglePanel()

local firstPage = OB.settings.categories[1].page
local firstRow = firstPage.rows[1]
local pointsBefore = firstRow:GetNumPoints()

try("LayoutPage is safe to run twice", function()
    OB.LayoutPage(firstPage)
    OB.LayoutPage(firstPage)
end)
eq(firstRow:GetNumPoints(), pointsBefore, "and leaves positions stable")

-- ---------------------------------------------------------------------------
-- 29. the self-test passes on a healthy boot
-- ---------------------------------------------------------------------------

context = "selftest: "
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

try("the self-test runs", function() OB.RunSelfTest() end)
check(OB.selfTestResult ~= nil, "it records a result")

if OB.selfTestResult then
    eq(OB.selfTestResult.failed, 0, "a healthy boot has no failures",
            table.concat(OB.selfTestResult.failures or {}, " // "))
    check(OB.selfTestResult.passed > 40, "and a plausible number of checks")
end

-- it builds the panel to check it, but must not put it on screen
check(OB.settings ~= nil, "it builds the panel")
check(not OB.settings:IsShown(), "without showing it")

--[[ Side-effect freedom, asserted rather than asserted-in-a-comment: a check
     that changes the thing it is checking is not one. ]]--
local scaleBefore, lockedBefore = OB.profile.scale, OB.profile.locked
local firstPassed = OB.selfTestResult.passed

OB.RunSelfTest()
eq(OB.profile.scale, scaleBefore, "the self-test does not touch the config")
eq(OB.profile.locked, lockedBefore, "any of it")
eq(OB.testMode, false, "and does not leave test mode on")
eq(OB.selfTestResult.passed, firstPassed, "running it twice gives the same answer")

-- the command seam is wired into the generated help
Stub.chat = {}
SlashCmdList["EQUADISOMNIBARS"]("help")
local mentionsSelftest = false
for i = 1, table.getn(Stub.chat) do
    if string.find(Stub.chat[i], "selftest") then mentionsSelftest = true end
end
check(mentionsSelftest, "a registered command appears in the generated help")

try("the command runs from the prompt", function()
    SlashCmdList["EQUADISOMNIBARS"]("selftest")
end)

-- The client-only range trace is available without changing any settings.
Stub.chat = {}
try("the range debug command runs", function()
    SlashCmdList["EQUADISOMNIBARS"]("rangedebug")
end)

local rangeDebugHasPosition, rangeDebugHasBackend = false, false
for i = 1, table.getn(Stub.chat) do
    if string.find(Stub.chat[i], "UnitPosition target", 1, true) then
        rangeDebugHasPosition = true
    end
    if string.find(Stub.chat[i], "selected=", 1, true) then
        rangeDebugHasBackend = true
    end
end
check(rangeDebugHasPosition, "range debug reports the target position call")
check(rangeDebugHasBackend, "and the backend that actually answered")

-- ---------------------------------------------------------------------------
-- 30. the self-test detects what it exists to detect
--
-- A check that cannot fail is not a check. Each case below breaks one thing the
-- real client could plausibly break, and asserts the right section noticed.
-- ---------------------------------------------------------------------------

context = "selftest detects: "

local function failureMentioning(needle)
    local result = OB.selfTestResult
    if not result then return false end
    for i = 1, table.getn(result.failures) do
        if string.find(result.failures[i], needle, 1, true) then return true end
    end
    return false
end

-- a missing client API
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local savedUnitMana = UnitMana
UnitMana = nil
OB.RunSelfTest()
UnitMana = savedUnitMana

check(OB.selfTestResult.failed > 0, "a missing API fails the run")
check(failureMentioning("UnitMana"), "and the failure names it")

-- a font string with no font: the bug that shipped
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
table.insert(OB.texts, OB.container:CreateFontString(nil, "OVERLAY"))
OB.RunSelfTest()
check(failureMentioning("font strings have no font"),
        "an unfonted font string is caught")

-- a widget that lost its anchor
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.bound.resource.frame:ClearAllPoints()
OB.RunSelfTest()
check(failureMentioning("not anchored"), "an unanchored bar is caught")
OB.Refresh(true)

-- a value outside its own maximum
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3, { power = 100, powerMax = 100 })
Stub.player.health = 5000
Stub.player.healthMax = 3000
OB.RunSelfTest()
check(failureMentioning("out of a maximum"), "a value above its maximum is caught")
Stub.player.health = 2400

-- the backend note reports what actually happened
EquadisClassicOverhaulDB = nil
OB = boot("HUNTER", 0, { unitXP = true })
Stub.chat = {}
OB.RunSelfTest()

local sawPrecise = false
for i = 1, table.getn(Stub.chat) do
    if string.find(Stub.chat[i], "Precise") then sawPrecise = true end
end
check(sawPrecise, "the report names the backend actually in use")

-- ---------------------------------------------------------------------------
-- 31. a long soak, to catch anything that only fails on the hundredth frame
-- ---------------------------------------------------------------------------

context = "soak: "
for i = 1, table.getn(order) do
    local class = order[i]
    EquadisClassicOverhaulDB = nil

    try(class .. " survives a soak", function()
        local addon = boot(class, expected[class].power)
        addon.SetTestMode(true)

        for frame = 1, 300 do
            Stub.Tick(0.05, 1)
            if frame % 40 == 0 then
                Stub.FireEvent("UNIT_DISPLAYPOWER", "player")
            end
            if frame % 25 == 0 then
                Stub.FireEvent("PLAYER_ENTER_COMBAT")
                Stub.FireEvent("CHAT_MSG_COMBAT_SELF_HITS")
            end
            if frame % 60 == 0 then
                Stub.FireEvent("PLAYER_LEAVE_COMBAT")
            end
        end

        addon.SetTestMode(false)
        addon.TogglePanel()
        addon.RefreshPanel()
        Stub.Tick(0.05, 20)
    end)
end

-- ---------------------------------------------------------------------------
-- 27. text positions
-- ---------------------------------------------------------------------------

--[[ A label's place on the bar is a position, not a side.

     Every label used to be nailed to an edge, and one boolean per pair -- Swap
     Text Sides -- was the only way between them. A 0-100 slider is the same
     choice with the whole width in between, and it costs one control instead of
     one mode. ]]--
context = "text position: "

EquadisClassicOverhaulDB = nil
OB = boot("HUNTER", 0, { mainSpeed = 2.6 })

local posBar = OB.modules.mainhand.frame
local posCfg = OB.profile.modules.mainhand

local function textX(text)
    -- SetPoint records { point, relativeTo, relativePoint, x, y }
    local p = text.points[1]
    return p and p[4]
end

--[[ Anchored by its **centre**, always, so the position is one number rather
     than a point-and-offset pair that means different things at each end. ]]--
posCfg.timerPos = 50
Stub.Tick(0.05, 2)
eq(posBar.left.points[1][1], "CENTER", "a label is anchored by its centre")
eq(posBar.left.points[1][3], "LEFT", "measured from the bar's left edge")
near(textX(posBar.left), posBar:GetWidth() / 2, 1, "so fifty is the middle")

posCfg.timerPos = 0
Stub.Tick(0.05, 2)
local atLeft = textX(posBar.left)

posCfg.timerPos = 100
Stub.Tick(0.05, 2)
local atRight = textX(posBar.left)

check(atRight > atLeft, "and a hundred is further right than zero")

--[[ **The travel stops at the edge.** The anchor is the label's centre, so
     without a clamp half of it would hang off the end at either extreme. ]]--
check(atLeft > 0, "a label at zero is not half off the left edge")
check(atRight < posBar:GetWidth(),
        "nor is one at a hundred off the right")

--[[ A wider label stops sooner, because the clamp is against the text's own
     width rather than a fixed inset. ]]--
posCfg.decimals = 2
posCfg.timerPos = 100
Stub.Tick(0.05, 2)
check(textX(posBar.left) <= atRight,
        "a longer label stops further from the edge")

--[[ The two labels are independent, which is the thing the swap boolean could
     not express: both on the same side, or crossed over, or anywhere. ]]--
posCfg.timerPos, posCfg.speedPos = 100, 0
Stub.Tick(0.05, 2)
check(textX(posBar.left) > textX(posBar.right),
        "the timer can sit to the right of the speed")

posCfg.timerPos, posCfg.speedPos = 40, 60
Stub.Tick(0.05, 2)
check(textX(posBar.left) < textX(posBar.right),
        "and back, without a mode to switch")

-- ---------------------------------------------------------------------------
-- 28. the health colour ramp
-- ---------------------------------------------------------------------------

--[[ **Three colours, not two, and the middle one is why it works.**

     A straight blend from green to red passes through (0.5, 0.5, 0) at halfway
     -- olive-brown, dark, and it reads as a fault rather than as half health.
     Equadis' Threat Meter solves it the same way, splitting at 50 and running
     green-to-yellow then yellow-to-red; the difference here is that all three
     are settings rather than literals in the draw path. ]]--
context = "health ramp: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local hp = OB.modules.health
local hpCfg = OB.profile.modules.health
hpCfg.healthGradient = true

local function rampAt(fraction)
    return hp:RampColor(fraction)
end

local function sameColor(a, b, label)
    near(a[1], b[1], 0.001, label .. " red")
    near(a[2], b[2], 0.001, label .. " green")
    near(a[3], b[3], 0.001, label .. " blue")
end

sameColor(rampAt(1), hpCfg.fullColor, "full health is the full colour")
sameColor(rampAt(0.5), hpCfg.halfColor, "half is the half colour")
sameColor(rampAt(0), hpCfg.lowColor, "and empty is the low one")

--[[ The midpoint of each segment lands exactly between its two ends, which is
     what makes the three swatches predictable: someone setting them can see the
     result without doing arithmetic. ]]--
local quarter = rampAt(0.25)
near(quarter[1], (hpCfg.lowColor[1] + hpCfg.halfColor[1]) / 2, 0.001,
        "a quarter is halfway from low to half")
near(quarter[2], (hpCfg.lowColor[2] + hpCfg.halfColor[2]) / 2, 0.001,
        "on every channel")

--[[ It never goes through mud, which is the entire reason for the middle
     colour. With the shipped green/yellow/red, every point on the ramp keeps a
     bright channel -- a straight green-to-red blend would sag to 0.5/0.5 at the
     middle. ]]--
local dimmest = 1
for i = 0, 20 do
    local c = rampAt(i / 20)
    local brightest = c[1]
    if c[2] > brightest then brightest = c[2] end
    if brightest < dimmest then dimmest = brightest end
end
check(dimmest > 0.7, "no point on the ramp goes muddy",
        "dimmest was " .. tostring(dimmest))

-- out of range values are clamped rather than extrapolated into nonsense
sameColor(rampAt(2), hpCfg.fullColor, "above full clamps to full")
sameColor(rampAt(-1), hpCfg.lowColor, "and below empty to low")

--[[ One precedence, and the panel's dimming is derived from it: class wins
     outright, the ramp beats the swatch, the swatch is what is left. Class is on
     top because it is the one choice about *you* rather than about the bar's
     value. ]]--
context = "health color precedence: "

hpCfg.healthGradient, hpCfg.classColor = false, false
sameColor(hp:CurrentColor(0.5), hpCfg.color, "with neither on, the swatch wins")

hpCfg.healthGradient = true
sameColor(hp:CurrentColor(0.5), hpCfg.halfColor, "the ramp beats the swatch")

hpCfg.classColor = true
local cr, cg, cb = OB.ClassColor(OB.class)
sameColor(hp:CurrentColor(0.5), { cr, cg, cb }, "and class beats the ramp")

--[[ **Greyed out is not hidden**, and that distinction is the whole point of
     the row state.

     An earlier version expressed "class colour overrides the swatch" by hiding
     the swatch, which read as the setting having been deleted and was reported
     as exactly that. Dimmed and disabled, the same fact reads as "your colour is
     still there, something else is winning" -- which is what is true. ]]--
context = "greyed rows: "

OB.TogglePanel()

local swatch = OB.widgets["module:health:color"]
local ramp = OB.widgets["module:health:healthGradient"]
local fullSwatch = OB.widgets["module:health:fullColor"]
local byClass = OB.widgets["module:health:classColor"]

check(swatch ~= nil, "the health swatch has a control")
check(ramp ~= nil and fullSwatch ~= nil and byClass ~= nil, "so do the ramp rows")

hpCfg.classColor, hpCfg.healthGradient = true, true
OB.RefreshPanel()

check(swatch.visible, "class colour leaves the swatch on the page")
eq(swatch.greyed, true, "greyed rather than removed")
near(swatch:GetAlpha(), 0.35, 0.001, "and visibly dimmed")
eq(swatch.enabled, false, "with the control actually disabled, not just faded")

eq(ramp.greyed, true, "the ramp switch is greyed too")
eq(fullSwatch.greyed, true, "and every ramp colour under it")
eq(byClass.greyed, false, "but the one in charge is not")

hpCfg.classColor = false
OB.RefreshPanel()

eq(swatch.greyed, false, "turning class colour off gives the swatch back")
near(swatch:GetAlpha(), 1, 0.001, "at full opacity")
eq(swatch.enabled, true, "and working again")
eq(fullSwatch.greyed, false, "with the ramp colours live")

--[[ The ramp's own colours dim when the ramp is off, so the panel still shows
     what it *would* look like while you are deciding whether to switch it on. ]]--
hpCfg.healthGradient = false
OB.RefreshPanel()

eq(fullSwatch.greyed, true, "a ramp colour dims when the ramp is off")
check(fullSwatch.visible, "without leaving the page")
eq(ramp.greyed, false, "and the switch itself stays live")

-- ---------------------------------------------------------------------------
-- 29. every switch greys what it governs
-- ---------------------------------------------------------------------------

--[[ **A setting that has stopped doing anything is dimmed, never removed.**

     The standing rule: if unticking a switch makes the settings under it inert,
     those settings grey out. Removing them from the page says they do not
     exist; dimming them says they are not currently in charge, which is the true
     thing and the one that survives switching the toggle back on.

     Hiding is kept for a different case, and the two must not be confused. A
     rage setting on a mana bar has no meaning *at all* -- there is no switch to
     put back -- so that one still goes. ]]--
context = "greyed by its switch: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.TogglePanel()

--[[ Each row against the switch that governs it, and the value of that switch
     which should dim it. Driven from a table so a new governed setting is one
     line here rather than a new block. ]]--
local governed = {
    { "global", nil, "hideOOC", "show", false },
    { "global", nil, "hideStealth", "show", false },
    { "global", nil, "hideDead", "show", false },

    { "module", "mainhand", "timerPos", "showTimer", false, "mainhand" },
    { "module", "mainhand", "decimals", "showTimer", false, "mainhand" },
    { "module", "mainhand", "speedPos", "showSpeed", false, "mainhand" },

    { "module", "distance", "distancePos", "showText", false, "distance" },
    { "module", "distance", "rangePos", "showRange", false, "distance" },
    { "module", "distance", "noLosColor", "losCheck", false, "distance" },
    { "module", "distance", "losWindow", "losCheck", false, "distance" },

    { "module", "health", "color", "classColor", true, "health" },
    { "module", "health", "healthGradient", "classColor", true, "health" },
}

local function widgetFor(row)
    if row[1] == "global" then return OB.widgets["global::" .. row[3]] end
    return OB.widgets["module:" .. row[2] .. ":" .. row[3]]
end

local function settingsFor(row)
    if row[1] == "global" then return OB.profile end
    return OB.profile.modules[row[2]]
end

local missing, notGreyed, notRestored, vanished = {}, {}, {}, {}

for i = 1, table.getn(governed) do
    local row = governed[i]
    local widget = widgetFor(row)
    local cfg = settingsFor(row)
    local label = (row[2] or "global") .. "." .. row[3]

    if not widget or not cfg then
        table.insert(missing, label)
    else
        local restore = cfg[row[4]]

        --[[ A row only appears while its own entry in the Bars column is the one
             selected: a bar module's while that bar is, and a global one while
             General is -- which is where the general settings live now. ]]--
        if row[6] then
            OB.panel.bar = row[6]
        elseif row[1] == "global" then
            OB.panel.bar = "__general"
        end

        -- the switch in the state that makes this row inert
        cfg[row[4]] = row[5]
        OB.RefreshPanel()

        if not widget.greyed then table.insert(notGreyed, label) end
        if not widget.visible then table.insert(vanished, label) end

        -- and back
        cfg[row[4]] = not row[5]
        OB.RefreshPanel()

        if widget.greyed then table.insert(notRestored, label) end

        --[[ Visible in *both* states, which is the check that catches a greyWhen
             written into the dependsOn slot by mistake: that inverts the row so
             it is shown only while its switch is off, and a test that looked at
             the off state alone would call that a pass. ]]--
        if not widget.visible then table.insert(vanished, label .. " (switch on)") end

        cfg[row[4]] = restore
    end
end

OB.RefreshPanel()

eq(table.getn(missing), 0, "every governed row has a control",
        table.concat(missing, ", "))
check(table.getn(notGreyed) == 0,
        "and greys out when its switch says it is inert",
        "still live: " .. table.concat(notGreyed, ", "))
eq(table.getn(notRestored), 0, "and comes back when the switch does",
        table.concat(notRestored, ", "))

--[[ The half of the rule that is easy to lose: **greyed is not hidden**. Every
     one of these stays on the page while dimmed, because the whole point is that
     the setting is still there. ]]--
eq(table.getn(vanished), 0, "and none of them leaves the page while dimmed",
        table.concat(vanished, ", "))

--[[ **The other case, kept deliberately distinct: a setting the class can never
     use is removed outright, not dimmed.**

     Greying says "not in charge right now", which invites looking for the switch
     that would put it back. A rogue has no rage and a mage has no rage, so there
     is no such switch and implying one is a lie. Rage decay is gone from both,
     and the mana-only rows are gone from the rogue for the same reason.

     Driven per class rather than asserted once, because the two halves of the
     rule are only meaningful against each other. ]]--
context = "hidden by class: "

local function powerRowShown(key)
    local widget = OB.widgets["module:power:" .. key]
    if not widget then return nil end
    return widget.visible, widget.greyed
end

local classCases = {
    { "ROGUE", 3, "rageDecay", "a rogue never sees rage decay" },
    { "MAGE", 0, "rageDecay", "and neither does a mage" },
    { "ROGUE", 3, "fsrShade", "nor a rogue the five second rule" },
    { "WARRIOR", 1, "fsrShade", "nor a warrior" },
}

for i = 1, table.getn(classCases) do
    local case = classCases[i]

    EquadisClassicOverhaulDB = nil
    OB = boot(case[1], case[2])
    OB.TogglePanel()
    OB.panel.bar = "resource"
    OB.RefreshPanel()

    local shown, greyed = powerRowShown(case[3])
    check(shown == false, case[4])
    eq(greyed, false, "  removed rather than dimmed, so no switch is implied")
end

--[[ And the same row is present and live for the class it belongs to, or the
     checks above would pass on a panel that had failed to build at all. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("WARRIOR", 1)
OB.TogglePanel()
OB.panel.bar = "resource"
OB.RefreshPanel()

local warriorDecay, warriorGreyed = powerRowShown("rageDecay")
check(warriorDecay, "a warrior does see rage decay")
eq(warriorGreyed, false, "and it is live, not dimmed")

-- ---------------------------------------------------------------------------
-- 30. the off hand bar, for a class that cannot dual wield
-- ---------------------------------------------------------------------------

--[[ **Greyed rather than hidden, and this is the one place the class rule
     bends.**

     A setting the class can never use normally goes, because there is no switch
     to put back and dimming would imply one. Bar geometry is the exception: it
     is **account-wide**, so the rectangle a mage is looking at is the one their
     warrior actually uses. Take it off the mage's page and the profile holds
     settings with no way to reach them. ]]--
context = "off hand without dual wield: "

EquadisClassicOverhaulDB = nil
-- offSpeed 0: nothing in the off hand, so nothing vouches for the class
OB = boot("MAGE", 0, { offSpeed = 0 })
OB.TogglePanel()
OB.panel.bar = "offhand"
OB.RefreshPanel()

local offColor = OB.widgets["module:offhand:color"]
local offTimerPos = OB.widgets["module:offhand:timerPos"]
local offWidth = OB.widgets["slot::w"]

check(offColor ~= nil and offTimerPos ~= nil, "the off hand rows exist for a mage")
check(offWidth ~= nil, "and so does the shared geometry")

eq(offColor.greyed, true, "the module rows are dimmed")
check(offColor.visible, "and stay on the page")
eq(offWidth.greyed, true, "the account-wide geometry is dimmed with them")
check(offWidth.visible, "and stays reachable rather than vanishing")

--[[ Two reasons at once is still one dimmed row. A mage's off hand timer
     position is inert both because the class cannot dual wield and because Show
     Timer could be off, so greyWhen ORs its reasons rather than taking one. ]]--
OB.profile.modules.offhand.showTimer = false
OB.RefreshPanel()
eq(offTimerPos.greyed, true, "a row inert for two reasons is dimmed once")

OB.profile.modules.offhand.showTimer = true
OB.RefreshPanel()
eq(offTimerPos.greyed, true, "and stays dimmed while the other reason holds")

--[[ The geometry dims only while the Off Hand bar is the one selected, because
     those rows are shared by every bar. Any other bar and they are live. ]]--
OB.panel.bar = "health"
OB.RefreshPanel()
eq(offWidth.greyed, false, "another bar's geometry is untouched")

--[[ A class that can dual wield sees all of it live. Without this the checks
     above would pass on a panel that had dimmed everything. ]]--
EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.TogglePanel()
OB.panel.bar = "offhand"
OB.RefreshPanel()

eq(OB.widgets["module:offhand:color"].greyed, false, "a rogue's off hand is live")
eq(OB.widgets["slot::w"].greyed, false, "geometry and all")

--[[ **And an off hand that actually swings overrules the list.**

     1.12 has no CanDualWield, so the class list is a list, and lists about class
     abilities age badly -- a server is free to hand dual wield to somebody
     vanilla never did. An observed off hand speed is proof, remembered for the
     session, and it only ever *stops* the greying: unequipping again does not
     make the settings flicker back to dim. ]]--
EquadisClassicOverhaulDB = nil
-- offSpeed 0: nothing in the off hand, so nothing vouches for the class
OB = boot("MAGE", 0, { offSpeed = 0 })
OB.TogglePanel()
OB.panel.bar = "offhand"
OB.RefreshPanel()
eq(OB.widgets["module:offhand:color"].greyed, true, "a mage starts dimmed")

Stub.player.offSpeed = 1.7
OB.modules.offhand.nextPoll = 0
Stub.Tick(0.05, 4)
OB.RefreshPanel()
eq(OB.widgets["module:offhand:color"].greyed, false,
        "but a swinging off hand proves the list wrong and undims it")

Stub.player.offSpeed = nil
Stub.Tick(0.05, 4)
OB.RefreshPanel()
eq(OB.widgets["module:offhand:color"].greyed, false,
        "and unequipping does not make it flicker back")

OB.dualWieldSeen = nil

-- ---------------------------------------------------------------------------
-- 31. the threat meter: the first feature module
-- ---------------------------------------------------------------------------

--[[ Scoped, because the main chunk is near Lua 5.0's two hundred local limit
     and this section declares a dozen. A block closes its registers, so the
     ceiling is about how many are live at once rather than how many the file
     ever names. ]]--
do

--[[ **The packet is the whole protocol**, so parsing it is the only thing that
     has to be exactly right -- and it is a pure function over a string, driven
     here directly rather than through a window.

     Turtle broadcasts threat to the party over the addon channel with a `TWTv4=`
     prefix. There is no combat log parsing anywhere in the threat meter, which
     is why it did not have to wait for the parser the damage meter needs. ]]--
context = "threat packet: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

-- built from the real player name, so "does this player find themselves in
-- the packet" is a question the test can actually ask
local me = UnitName("player")

local packet = "TWTv4=" ..
        "Tankman:1:12000:100:1;" ..
        me .. ":0:9600:80:1;" ..
        "Somemage:0:4800:40:0"

local threat = OB.ParseThreatPacket(packet)
check(threat ~= nil, "a v4 packet parses")

eq(threat.Tankman.threat, 12000, "the tank's threat is read")
eq(threat.Tankman.tank, true, "and the tank flag with it")
eq(threat[me].percent, 80, "a percentage is read per player")
eq(threat[me].melee, true, "and the melee flag")
eq(threat.Somemage.melee, false, "which is false for a caster")

--[[ Percent is percent **of the tank's threat**, so it runs past 100 for
     whoever holds aggro. Not a bug to clamp -- it is the number the whole
     readout is about. ]]--
local pulled = OB.ParseThreatPacket(
        "TWTv4=Tankman:0:9000:75:1;" .. me .. ":1:12000:133:1")
eq(pulled[me].percent, 133, "a percentage past a hundred survives")

--[[ nil for a message that is not ours, and an empty table for a packet that
     named nobody. The two mean different things: empty is a real answer that
     should clear the window, nil must leave it exactly as it was. ]]--
check(OB.ParseThreatPacket("SomeOtherAddon:hello") == nil,
        "another addon's message is not a packet")
check(OB.ParseThreatPacket(nil) == nil, "and neither is nothing at all")

local empty = OB.ParseThreatPacket("TWTv4=")
check(empty ~= nil, "an empty packet is still a packet")
eq(next(empty), nil, "naming nobody")

--[[ One malformed entry costs that entry, not the raid. The packet arrives
     whole, so rejecting all of it would blank a window that was right a moment
     ago. ]]--
local partial = OB.ParseThreatPacket("TWTv4=Tankman:1:12000:100:1;Broken:0:9600;Somemage:0:4800:40:0")
check(partial.Tankman ~= nil, "a short entry does not cost the ones around it")
check(partial.Somemage ~= nil, "on either side of it")
check(partial.Broken == nil, "and is dropped rather than half read")

local nonNumeric = OB.ParseThreatPacket("TWTv4=Tankman:1:lots:100:1")
eq(next(nonNumeric), nil, "a non-numeric threat is dropped too")

-- a sixth field exists in the wild and is read by nothing; it must not confuse
-- the five that are
local extra = OB.ParseThreatPacket("TWTv4=Tankman:1:12000:100:1:extra")
eq(extra.Tankman.threat, 12000, "an unread sixth field is ignored, not rejected")

--[[ The tank is read out of the entries rather than tracked alongside them: the
     packet is rebuilt whole each time, so a remembered name is a second source
     of truth that can only ever disagree with the first. ]]--
eq(OB.ThreatTank(threat).name, "Tankman", "the tank is found in the packet")
check(OB.ThreatTank(OB.ParseThreatPacket("TWTv4=Somemage:0:4800:40:0")) == nil,
        "and is nil when the packet names none")
check(OB.ThreatTank(nil) == nil, "or when there is no packet")

--[[ Melee pull aggro at 110% of the tank and everyone else at 130%, because a
     ranged attacker has to exceed the tank by more to rip. That asymmetry is the
     most useful thing the readout knows. ]]--
eq(OB.ThreatPullAt(true), 110, "melee rip at 110 percent")
eq(OB.ThreatPullAt(false), 130, "and ranged at 130")

-- ---------------------------------------------------------------------------

--[[ **A feature module owns a window, not a bar**, so the binder cannot find it
     by walking the bar order and must not hand it a bar frame it never asked
     for. What it shares is everything else: the event map, the dirty-flag
     redraw, the enable flag, the class gate. ]]--
context = "feature modules: "

local threatModule = OB.modules.threat
check(threatModule ~= nil, "the threat meter registers")
eq(threatModule.feature, true, "as a feature")
check(threatModule.bar == nil, "occupying no bar")

--[[ Off by default while the window is unwritten. A feature that is on and draws
     nothing is indistinguishable from one that is broken. ]]--
eq(OB.ModuleEnabled("threat"), false, "and ships switched off")
check(OB.features.threat == nil, "so nothing binds it")

--[[ **Every subsystem has a tab of its own**, rather than a row on a shared
     page. A threat meter has as much to configure as the whole bar cluster
     does, and burying it one level down said the opposite. ]]--
OB.TogglePanel()
OB.SelectCategory("Threat Meter")

--[[ **No Show switch on a subsystem's own page.** There was one on every tab
     answering "do I want this on screen right now" while the Modules page
     answered "should this run at all" -- two switches for one subsystem, on two
     pages, whose difference took a paragraph to state. ]]--
check(OB.widgets["moduleShow::threat"] == nil,
        "a tab carries no Show switch of its own")
--[[ **Two stores, not one key with two captions.** That was the bug: hiding a
     meter for one pull unbound it, so it stopped counting, and the numbers you
     hid it to stop watching were gone when you looked again. ]]--
check(OB.scopes.moduleShow() ~= OB.scopes.moduleToggle(),
        "and Enable is a separate store, not the same setting twice")

--[[ Switched on, it binds, takes its events and joins the redraw -- through the
     same dispatch a bar uses, which is the whole point of sharing it. ]]--
OB.profile.modulesEnabled.threat = true
OB.BindSlots()

check(OB.features.threat ~= nil, "enabling it binds the feature")
check(OB.eventMap["CHAT_MSG_ADDON"] ~= nil, "and registers the events it asked for")

Stub.FireEvent("CHAT_MSG_ADDON", "TWT", packet)
eq(OB.modules.threat.entries.Tankman.threat, 12000,
        "a packet on the addon channel reaches it")

local mine = OB.modules.threat:Mine()
check(mine ~= nil, "and this player finds themselves in it")
eq(mine.percent, 80, "at the percentage the packet gave")

--[[ A loading screen clears it. Threat does not survive one, and the packet
     arrives again within a second of combat -- showing the previous zone's raid
     until then would be a confident lie. ]]--
Stub.FireEvent("PLAYER_ENTERING_WORLD")
eq(next(OB.modules.threat.entries), nil, "entering the world clears the table")

-- and switching it off unbinds it again
OB.profile.modulesEnabled.threat = false
OB.BindSlots()
check(OB.features.threat == nil, "switching it off unbinds it")

OB.profile.modulesEnabled.threat = nil

-- ---------------------------------------------------------------------------
-- 32. the threat meter's window
-- ---------------------------------------------------------------------------

--[[ A function, not a bare block. The main chunk is at Lua 5.0's two hundred
     local limit, and a `do ... end` does not help once the *top level* is that
     full -- only a new function gets a fresh scope to spend. ]]--
local function threatWindowTests()

context = "threat window: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local me = UnitName("player")
OB.profile.modulesEnabled.threat = true
OB.BindSlots()

--[[ **In a group for the whole section.** Solo the meter hides itself by
     design -- threat arrives over the party/raid channel, so alone there is no
     channel to hear it on -- and every test below is about what the window does
     when it *can* have data. The solo rule gets its own block further down. ]]--
Stub.SetGroup({ { name = "Tank", class = "WARRIOR" } }, true)

local meter = OB.modules.threat
local cfg = OB.profile.modules.threat

check(meter.frame ~= nil, "the window is built on bind")
eq(meter.frame:GetWidth(), cfg.width, "at the configured width")
eq(meter.frame:GetHeight(),
        OB.HEADER_H + meter:RowStep(cfg) + (meter:RowStep(cfg) * cfg.rows)
                + (OB.BorderPad("threat") * 2),
        "and tall enough for its header, every row, and the border art")

--[[ **A header, at the same height and with the same art as the damage
     meter's.** Three buttons rather than seven: four of the damage meter's
     answer questions this window does not have -- one segment, one statistic,
     one window, and nothing to reset, since the packet rebuilds the list whole
     every time it arrives. What is left is what both share. ]]--
local head = meter.frame.head
check(head ~= nil, "the window has a header")
check(head.settings and head.lock, "with its two buttons")

eq(head.lock.icon:GetTexture(), OB.icons.unlock,
        "the padlock shows the state the window is in")

cfg.locked = true
meter:OnStyle()
eq(head.lock.icon:GetTexture(), OB.icons.lock, "which follows the lock")
cfg.locked = false
meter:OnStyle()

--[[ Rows start below the header rather than under it, which is the arithmetic
     that goes wrong when a header is added to a window that never had one. ]]--
local firstRowY = meter.rows[1].points[1][5]
check(firstRowY <= -OB.HEADER_H, "and no row is drawn behind it",
        "first row at " .. firstRowY)

--[[ The header drags. It is a child with the mouse enabled, so it swallows the
     press before the window under it sees one -- meaning it has to carry the
     drag itself or the strip everybody grabs is dead. ]]--
check(head:GetScript("OnDragStart") ~= nil, "the header starts a drag")
check(head:GetScript("OnDragStop") ~= nil, "and finishes one")

--[[ **The client holds it on screen while it is moving.** The arithmetic clamp
     only runs when a drag *stops*, and a drag that ends with the mouse released
     outside the window does not reliably deliver an OnDragStop at all -- so
     until this, the window could simply be pulled off the edge. ]]--
--[[ **Not clamped by the client.** 1.12 predates widescreen: UIParent is not
     the monitor, so its clamp pulls anything outside *its* idea of the screen
     back to that edge -- every window to the same edge, which stacked two damage
     windows on an ultrawide after every reload. Our own rescue does less, on
     purpose. ]]--
check(not meter.frame:IsClampedToScreen(),
        "the window is not clamped by the client")

--[[ The header takes its colour from the setting, exactly as the damage meter's
     does -- same key, same default, so the two windows match without being
     coloured twice. ]]--
cfg.headerColor = { 0.4, 0.1, 0.2, 1 }
meter:OnStyle()
near(head.bg.rgba[1], 0.4, 0.001, "the header is painted from the setting")
cfg.headerColor = { 0.16, 0.16, 0.18, 1 }
meter:OnStyle()

--[[ **The padlock, clicked.** Reported as "unlock/lock isn't working, attempt to
     index local cfg a nil value" -- so the handler is *run* here rather than
     inspected. A script that is present and throws is exactly as broken as one
     that is missing, and only one of those two the harness used to notice. ]]--
Stub.Click(head.lock)
eq(cfg.locked, true, "clicking the padlock locks the window")
eq(head.lock.icon:GetTexture(), OB.icons.lock, "and the icon follows")

Stub.Click(head.lock)
eq(cfg.locked, false, "and clicking it again unlocks")

Stub.Click(head.settings)
check(true, "the settings button runs without error")

--[[ **No packet is a state, not an absence.** The window used to hide itself
     whenever the list was empty, which is solo, and anywhere the server does not
     broadcast. That reads as a subsystem that failed to load -- and a hidden
     window cannot be dragged, so there was no way to place it before a raid. ]]--
meter.entries = {}
meter.seenPacket = nil
meter:OnDraw()

check(meter.frame:IsShown(), "an empty meter is still on screen")
check(meter.frame.empty:IsShown(), "with a line saying why")
check(not meter.rows[1]:IsShown(), "and no rows")

--[[ Why it is empty, not merely that it is. Solo is nothing to fix; in a group
     with no packet is a server that does not send one; in a group with one is
     simply waiting. Saying "no data" to all three sends somebody hunting for a
     setting in two of them. ]]--
Stub.SetGroup({}, false)
check(string.find(meter:EmptyReason(), "solo", 1, true), "solo says so")

Stub.SetGroup({ { name = "Tank", class = "WARRIOR" } }, true)
check(string.find(meter:EmptyReason(), "server", 1, true),
        "in a group with no packet, the server is named")

meter.seenPacket = true
check(string.find(meter:EmptyReason(), "pull", 1, true),
        "and with one, it is just waiting")

Stub.SetGroup({}, false)

--[[ **Solo, the window is gone rather than empty -- and that is off by
     default.**

     The one exception to "no data is a state, not an absence", and it earns it:
     threat is broadcast to your party or raid, so alone there is no channel to
     hear it on. The window is not waiting for data, it is waiting for a group,
     and a permanent "no threat solo" over the world while you quest is a label
     rather than a readout. ]]--
eq(cfg.showSolo, false, "the meter is hidden when solo by default")

Stub.SetGroup({}, false)
meter.entries = {}
meter:OnDraw()
check(not meter.frame:IsShown(), "so a solo player sees no window at all")

cfg.showSolo = true
meter:OnDraw()
check(meter.frame:IsShown(), "unless they ask for it")
check(string.find(meter.frame.empty:GetText(), "solo", 1, true),
        "and then it says why it is empty")
cfg.showSolo = false

--[[ Every *other* empty state still shows itself, because those are real waits
     rather than a state the meter cannot leave. ]]--
Stub.SetGroup({ { name = "Tank", class = "WARRIOR" } }, true)
meter:OnDraw()
check(meter.frame:IsShown(), "in a group with no packet it is still there")

--[[ Test mode overrides it. You configure this window standing alone in a city,
     and a preview that vanished exactly when somebody went looking for it would
     be the trap this setting exists to avoid. ]]--
Stub.SetGroup({}, false)
OB.SetTestMode(true)
Stub.Tick(0.1, 2)
check(meter.frame:IsShown(), "and the preview shows solo regardless")
OB.SetTestMode(false)

Stub.SetGroup({ { name = "Tank", class = "WARRIOR" } }, true)

--[[ Rows come back the moment a packet does, and the line goes. ]]--
meter.entries = { Tank = { name = "Tank", tank = true, threat = 100,
                           percent = 100, melee = true } }
meter:OnDraw()
check(not meter.frame.empty:IsShown(), "a packet clears the line")
check(meter.rows[1]:IsShown(), "and brings the rows back")

--[[ **No chat button.** Removed on request, and asserted so it does not come
     back with the next header edit. ]]--
check(head.chat == nil, "the header has no chat button")
check(meter.Report == nil, "and no reporting code behind it")

--[[ **Highest threat first**, which is the order the question is asked in: who
     has aggro, then who is closest to taking it.

     By percent rather than raw threat -- the two agree while everyone is on one
     target and disagree the moment somebody is not, and percent is already
     relative to the tank, which is what "am I about to pull" means. ]]--
local sorted = OB.SortThreat(OB.ParseThreatPacket(
        "TWTv4=Low:0:2000:20:0;Tank:1:12000:100:1;Middle:0:7000:60:1"))

eq(sorted[1].name, "Tank", "the leader is first")
eq(sorted[2].name, "Middle", "then the next")
eq(sorted[3].name, "Low", "and so on down")

--[[ Name breaks a tie, so the list does not shuffle between identical readings.
     Two players on exactly equal threat is common at a pull, and a list that
     reorders itself every packet is unreadable. ]]--
local tied = OB.SortThreat(OB.ParseThreatPacket(
        "TWTv4=Zeta:0:5000:50:0;Alpha:0:5000:50:0"))
eq(tied[1].name, "Alpha", "equal threat sorts by name")
eq(tied[2].name, "Zeta", "stably, so the list does not shuffle")

--[[ Rows are scaled against the **leader**, not against a hundred. A raid where
     nobody is near the tank should still show who is ahead of whom; scaling to a
     fixed hundred would squash the whole list into the left edge. ]]--
Stub.FireEvent("CHAT_MSG_ADDON", "TWT",
        "TWTv4=Tank:1:12000:100:1;" .. me .. ":0:6000:50:1")
Stub.Tick(0.05, 2)

check(meter.frame:IsShown(), "a packet shows the window")

--[[ The list is sorted by percentage, highest first. Your own row is *not*
     pinned -- the headline bar above the list carries the reading that is
     actually about you, which is what a pinned row was reaching for. ]]--
--[[ Ranked, like the damage meter's rows: the number answers "am I third"
     without counting down the list. ]]--
eq(meter.rows[1].left.text, "1. Tank", "the leader is first, and numbered")
eq(meter.rows[2].left.text, "2. " .. me, "and the rest follow in threat order")

cfg.showRank = false
meter:OnDraw()
eq(meter.rows[1].left.text, "Tank", "the number can be switched off")
cfg.showRank = true
meter:OnDraw()

near(meter.rows[1].fill:GetWidth(), cfg.width, 1, "the leader's row is full")
near(meter.rows[2].fill:GetWidth(), cfg.width / 2, 1,
        "and half the leader's threat is half wide")

--[[ **The headline, pinned above the list**: how much threat you can still gain
     before you rip. Not a row about a player -- a reading about the gap between
     two of them, which is why it is not hung off either one. ]]--
local pull = meter.frame.pull
check(pull and pull:IsShown(), "the Threat Until Pull bar is above the list")
eq(pull.left.text, "Threat Until Pull", "and says what it is")

--[[ Melee rip at 110%% of the tank, so at 6000 against a 12000 tank there are
     13200 - 6000 = 7200 to go. ]]--
near(OB.ThreatUntilPull(meter:Mine(), OB.ThreatTank(meter.entries)), 7200, 1,
        "the headroom is the tank's pull threshold less your own threat")

check(OB.ThreatUntilPull(nil, nil) == nil, "with no tank there is no headroom")

--[[ **The bar's length and the number beside it are one quantity.**

     Reported as "the top bar does not fill all the way". The fill used to be
     `percent / pullAt` while the number was the headroom -- two routes to the
     same idea, and two routes disagree: the percentage arrives rounded to whole
     numbers and the headroom does not, so the number reached zero while the bar
     was still short.

     Now the fill is derived from the headroom it is showing. When the bar says
     nothing is left, it is full, because those are the same fact. ]]--
cfg.fillUntilPull = true
meter:OnDraw()

check(pull.fillFraction and pull.fillFraction < 1,
        "with headroom left the bar is not full",
        tostring(pull.fillFraction))

--[[ At the pull threshold exactly: no headroom, and a full bar. ]]--
Stub.FireEvent("CHAT_MSG_ADDON", "TWT",
        "TWTv4=Tank:1:12000:100:1;" .. me .. ":0:13200:110:1")
Stub.Tick(0.05, 2)

--[[ `near` rather than `eq`, because 13200 minus 12000 times 1.1 is not zero in
     binary -- it is 1.8e-12. Nothing user-visible: ShortNumber writes it as 0
     and the bar is 99.9999% full. But asserting exact equality on arithmetic
     the client does in floats is asserting something that was never true. ]]--
near(OB.ThreatUntilPull(meter:Mine(), OB.ThreatTank(meter.entries)), 0, 0.001,
        "at the threshold there is no headroom")
near(pull.fillFraction, 1, 0.001, "and the bar is full, which is the same fact")

--[[ Past it, still full rather than wrapping round. ]]--
Stub.FireEvent("CHAT_MSG_ADDON", "TWT",
        "TWTv4=Tank:1:12000:100:1;" .. me .. ":0:20000:166:1")
Stub.Tick(0.05, 2)
near(pull.fillFraction, 1, 0.001, "and past it, still full")

cfg.fillUntilPull = false
Stub.FireEvent("CHAT_MSG_ADDON", "TWT",
        "TWTv4=Tank:1:12000:100:1;" .. me .. ":0:6000:50:1")
Stub.Tick(0.05, 2)

--[[ **Two columns, not three.**

     The change column answered "your threat moved by this much" and the question
     underneath it was always "because of what" -- which the per-ability
     measurement answers properly. A column that raises a question it cannot
     answer is worse than the space it takes.

     Asserted, because the width came out of the alignment as well as out of the
     drawing: leaving the measurement behind would keep an eight-pixel gap with
     nothing in it, and that reads as the numbers being misaligned rather than as
     a column having been removed. ]]--
eq(meter.rows[1].extra:GetText(), "", "no row draws a third figure")
eq(meter.frame.pull.extra:GetText(), "", "and neither does the headline")

check(OB.ThreatChangeText == nil, "and the function that wrote it is gone")

changeRows = 0

for i = 1, table.getn(OB.modules.threat.options) do
    local key = OB.modules.threat.options[i][2]
    if key == "showChange" or key == "showTPS" then changeRows = changeRows + 1 end
end

eq(changeRows, 0, "with no setting left offering it")

-- ---------------------------------------------------------------------------
-- what each of your abilities costs in threat
-- ---------------------------------------------------------------------------

--[[ **The question the meter could not answer: how much does *this* cost?**

     The window says where everybody stands. It has never said what to stop
     doing about it, and the answer to "I keep pulling" is almost always one
     ability rather than all of them.

     Nothing in the game will tell you. There is no threat-per-spell API, the
     packet carries totals only, and the published coefficients are a wiki page
     that is wrong for half the abilities on a private server. So it is
     measured: the packet gives your total twice a second, the combat log says
     what you did in between, and a window with exactly one thing in it
     attributes cleanly. ]]--
EquadisClassicOverhaulDB.threatPerSpell = {}
OB.threatPerSpell = EquadisClassicOverhaulDB.threatPerSpell

eq(OB.ThreatFor("Sinister Strike"), nil, "nothing is known to begin with")

OB.LearnThreatFor("Sinister Strike", 500)
OB.LearnThreatFor("Sinister Strike", 600)

local perUse, samples = OB.ThreatFor("Sinister Strike")
eq(perUse, 550, "two samples average")
eq(samples, 2, "and the count comes with the number")

--[[ **The sample count is not decoration.** One is an anecdote and thirty is a
     measurement, and a readout showing both the same way invites somebody to
     rebuild a rotation around one lucky window. ]]--
OB.LearnThreatFor("Feint", -900)
eq(OB.ThreatFor("Feint"), -900, "a threat drop is measured the same way")

--[[ Zero teaches nothing and there are a lot of them -- any window where the
     packet arrived before the server had processed the hit. Left out rather
     than averaged in, where they would drag every figure towards nothing. ]]--
eq(OB.LearnThreatFor("Sinister Strike", 0), false, "a zero is not a sample")

local _, stillTwo = OB.ThreatFor("Sinister Strike")
eq(stillTwo, 2, "and does not count towards the average")

--[[ **A window with two different things in it teaches nothing.** Rather than
     count events and check later, the second one poisons the window outright:
     what is carried between packets is a name or the fact that it is now
     ambiguous, never a list. ]]--
meter.windowSpell = nil
meter.windowCount = nil

meter:NoteAction({ source = me, attack = "Eviscerate" })
eq(meter.windowSpell, "Eviscerate", "one action is a clean window")

meter:NoteAction({ source = me, attack = "Sinister Strike" })
eq(meter.windowSpell, false, "a second, different one poisons it")

eq(meter:CloseWindow(1000), false, "so nothing is learned from it")

--[[ **The same ability twice is still one ability.** A rogue's off hand lands
     beside the main hand constantly and both are "Auto Hit"; throwing that away
     would discard most of the auto-attack samples for no reason. What the
     window teaches is unambiguous -- it is simply worth twice as much, so the
     amount is divided by how many times it happened. ]]--
meter.windowSpell = nil
meter.windowCount = nil

meter:NoteAction({ source = me, attack = "Auto Hit" })
meter:NoteAction({ source = me, attack = "Auto Hit" })
eq(meter.windowCount, 2, "two of the same is counted rather than rejected")

meter:CloseWindow(400)
eq(OB.ThreatFor("Auto Hit"), 200, "and the amount is divided between them")

--[[ Only your own lines. Somebody else's damage does not move your threat. ]]--
meter.windowSpell = nil
meter:NoteAction({ source = "Tankman", attack = "Heroic Strike" })
eq(meter.windowSpell, nil, "another player's action is not yours to attribute")

meter.windowSpell = nil
meter.windowCount = nil

cfg.showUntilPull = false
meter:OnDraw()
check(not pull:IsShown(), "and it can be switched off")
cfg.showUntilPull = true
meter:OnDraw()

--[[ The figures share the right-hand label rather than one of them sitting at
     the row's midpoint. Two numbers that belong to each other read as a pair
     only when they are next to each other. ]]--
check(string.find(meter.rows[1].right.text, "100%", 1, true),
        "and carries its percentage")
check(string.find(meter.rows[2].right.text, "50%", 1, true), "per row")

--[[ Threat is shortened: four digits is noise on a sixteen pixel row and the
     digit that matters is the leading one. ]]--
eq(OB.ShortNumber(12345), "12.3k", "a big number is shortened")
eq(OB.ShortNumber(950), "950", "a small one is not")
check(string.find(meter.rows[1].center.text, "12.0k", 1, true),
        "and the row shows it, in the figures column")
check(string.find(meter.rows[1].right.text, "%%") ~= nil,
        "with the percentage in a column of its own")

cfg.showThreat = false
OB.SetDirty(meter)
Stub.Tick(0.05, 2)
eq(meter.rows[1].center.text, "", "which can be switched off")
cfg.showThreat = true

-- rows past the end of the list are hidden rather than left showing stale names
check(not meter.rows[3]:IsShown(), "a row with nobody in it is hidden")

--[[ An empty packet empties the rows and **keeps the window**.

     This used to hide the whole thing, and that was wrong twice over: the packet
     stops arriving the moment a fight ends, so between pulls the meter simply
     was not there -- which reads as a subsystem that failed to load -- and a
     hidden window cannot be dragged, so there was no way to place it. ]]--
Stub.FireEvent("CHAT_MSG_ADDON", "TWT", "TWTv4=")
Stub.Tick(0.05, 2)
check(meter.frame:IsShown(), "an empty packet leaves the window up")
check(not meter.rows[1]:IsShown(), "with no rows")

-- ---------------------------------------------------------------------------

--[[ **The ramp runs the other way here.**

     On the health bar full is good, so it runs low-to-full. On the threat meter
     high is bad, so the "full" anchor is the pull colour and safe is the low
     end. Same OB.Ramp, opposite direction -- which is why the arithmetic is
     shared and the three colours are not. ]]--
context = "threat colours: "

Stub.FireEvent("CHAT_MSG_ADDON", "TWT",
        "TWTv4=Tank:1:12000:100:1;" .. me .. ":0:0:0:1")
Stub.Tick(0.05, 2)

local safe = meter:RowColor(meter:Mine(), meter:Mine())
near(safe[1], cfg.safeColor[1], 0.001, "no threat at all is the safe colour")

Stub.FireEvent("CHAT_MSG_ADDON", "TWT",
        "TWTv4=Tank:1:12000:100:1;" .. me .. ":0:13200:110:1")
Stub.Tick(0.05, 2)

local pulling = meter:RowColor(meter:Mine(), meter:Mine())
near(pulling[1], cfg.pullColor[1], 0.05, "and 110 percent as melee is the pull colour")

--[[ Melee rip at 110% and ranged at 130%, so the same percentage is a different
     colour depending on which you are. That asymmetry is the most useful thing
     the readout knows. ]]--
local ranged = { name = me, percent = 110, threat = 13200, melee = false }
local rampedRanged = meter:RowColor(ranged, ranged)
check(rampedRanged[1] < pulling[1] or rampedRanged[2] > pulling[2],
        "the same percentage is safer for a ranged player")

--[[ Everybody else is coloured by class, which is how you find them in a list.
     The packet does not carry a class, so it is looked up in the group -- and a
     name the client has never seen falls back to the ramp rather than inventing
     one. ]]--
Stub.SetGroup({ { name = "Tank", class = "WARRIOR" } }, true)
local tankColor = meter:RowColor({ name = "Tank", percent = 100 }, meter:Mine())
local wr, wg, wb = OB.ClassColor("WARRIOR")
near(tankColor[1], wr, 0.001, "a group member takes their class colour")
near(tankColor[2], wg, 0.001, "on every channel")

--[[ **Somebody outside the group falls back to the bar colour, not the ramp.**

     This is the reported bug, and it wore two disguises. The fallback here used
     to be the pull ramp, so every row whose class could not be resolved -- which
     in a preview is all of them -- came out coloured as though it were about to
     rip. That reads as "the pull gradient is applying to all bars" *and* as
     "color rows by class isn't working", and it is one mistake: **a fallback
     must be the dullest of the options, never the loudest.** ]]--
Stub.SetGroup({}, false)
local strangerColor = meter:RowColor({ name = "Nobody", percent = 100 }, meter:Mine())
eq(strangerColor, cfg.barColor, "somebody with no class takes the bar colour")

local ramped = OB.Ramp(cfg.safeColor, cfg.closeColor, cfg.pullColor, 1)
check(strangerColor[1] ~= ramped[1] or strangerColor[2] ~= ramped[2],
        "and emphatically not the about-to-pull color")

--[[ Your own row still ramps, which is the reading the window exists for and
     the thing the broken fallback was drowning out. ]]--
local mineRamped = meter:RowColor(meter:Mine(), meter:Mine())
check(mineRamped[1] ~= cfg.barColor[1] or mineRamped[2] ~= cfg.barColor[2],
        "your own row is still coloured by threat, not by the bar color")

--[[ **The preview moves**, here for the same reason as on the damage meter: a
     still window shows the colours and hides the one thing the meter is for,
     which is a row climbing towards the tank's. ]]--
OB.SetTestMode(true)

local seeded = meter:Mine()
check(seeded ~= nil, "the preview puts the player in the list")

local firstThreat = seeded.threat
local threatMoved = false

for i = 1, 8 do
    Stub.Tick(0.5, 3)
    local mine = meter:Mine()
    if mine and mine.threat ~= firstThreat then threatMoved = true end
end

check(threatMoved, "and re-seeds it every second so the rows move")

--[[ The tank keeps the tag through every re-seed. A preview where aggro flickers
     between rows is showing a state the meter never reports. ]]--
local tanks = 0
for name, entry in pairs(meter.entries) do
    if entry.tank then tanks = tanks + 1 end
end
eq(tanks, 1, "with exactly one tank throughout")

--[[ **Name left, numbers together on the right**, the same shape the damage
     meter uses. The threat figure used to sit at the middle of the row, stranded
     between the name and the percentage with a gulf on both sides: two numbers
     that belong to each other read as a pair only when they are next to each
     other. ]]--
meter.entries = { Tank = { name = "Tank", tank = true, threat = 12000,
                           percent = 100, melee = true } }
cfg.showThreat = true
meter:OnDraw()

--[[ **Two numeric columns, each flush with itself.** The percentage used to
     ride on the end of one combined string, so its left edge moved with
     whatever preceded it -- a four digit threat figure on one row and a two
     digit one on the next put the percent signs in different places. ]]--
eq(meter.rows[1].center:GetText(), "12.0k", "the threat figure has its own column")
eq(meter.rows[1].right:GetText(), "100%", "and the percentage its own")

eq(meter.rows[1].right.points[1][4], meter.rows[2].right.points[1][4],
        "so the percent signs line up whatever precedes them")

cfg.showThreat = false
meter:OnDraw()
eq(meter.rows[1].center:GetText(), "",
        "and switching the figure off empties its column")
eq(meter.rows[1].right:GetText(), "100%", "leaving the percentage")
cfg.showThreat = true

--[[ And the preview's rows carry a class, so the colour scheme somebody opened
     the preview to look at is the one they are shown. ]]--
local wc = meter:RowColor({ name = "Warrior", percent = 100 }, meter:Mine())
local pr, pg = OB.ClassColor("WARRIOR")
near(wc[1], pr, 0.001, "a preview row is coloured by the class it names")
near(wc[2], pg, 0.001, "on every channel")

OB.SetTestMode(false)
eq(OB.classHint["Warrior"], nil, "and the hint is cleared when it stops")

OB.profile.modulesEnabled.threat = nil
OB.BindSlots()
end

threatWindowTests()
end

-- ---------------------------------------------------------------------------
-- 33. two navigation columns
-- ---------------------------------------------------------------------------

--[[ A function rather than a bare block: the main chunk is at Lua 5.0's two
     hundred local limit -- see section 32. ]]--
local function navigationTests()

--[[ **The section, then what is in it.** The left column is General / Bars /
     Modules / Profiles; the second is the eight bars or the five subsystems.

     The second used to be a dropdown on the Bars page, and a dropdown is the
     wrong shape: it hides the list until clicked, so the question the page
     exists to answer -- which one am I looking at, and what else is there --
     cost a click to ask. ]]--
context = "navigation: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.TogglePanel()

local panel = OB.settings

local function shownSubs()
    local out = {}
    for i = 1, table.getn(panel.subButtons) do
        if panel.subButtons[i]:IsShown() then
            table.insert(out, panel.subButtons[i])
        end
    end
    return out
end

--[[ Sections with nothing in them show no second column at all, rather than an
     empty one. General and Profiles are single pages; a bare divider beside them
     would imply a list that failed to load. ]]--
OB.SelectCategory("General")
eq(table.getn(shownSubs()), 0, "General has no second column")
check(not panel.subDivider:IsShown(), "and no divider to imply one")

OB.SelectCategory("Profiles")
eq(table.getn(shownSubs()), 0, "nor does Profiles")

OB.SelectCategory("OmniBars")
local barButtons = shownSubs()
eq(table.getn(barButtons), table.getn(OB.BarsForClass()) + 1,
        "Bars lists General and this class's bars")
check(panel.subDivider:IsShown(), "and the divider earns its place")

--[[ The selected entry is highlighted, which is the other half of what the
     column is for: knowing where you are without clicking anything. ]]--
OB.panel.bar = "health"
OB.RefreshPanel()

local highlighted
for i = 1, table.getn(barButtons) do
    if barButtons[i].value == "health" then highlighted = barButtons[i] end
end
check(highlighted ~= nil, "the selected bar has a button")

--[[ **Every subsystem has a tab of its own**, planned ones included, and the
     tab order is a reading order: Profiles first because it decides what every
     other tab is editing, Modules last because it is the shortest question. ]]--
local order = {}
for i = 1, table.getn(panel.categories) do
    order[i] = panel.categories[i].name
end

--[[ Profiles first because it decides what every other tab edits. Bars second
     because General folded into it -- scale, texture, font and the movement
     switches are settings about the bars, and they are the first entry in its
     column. ]]--
eq(order[1], "Profiles", "Profiles is the first tab")
eq(order[2], "OmniBars", "then OmniBars")
local hasGeneralTab = false
for i = 1, table.getn(order) do
    if order[i] == "General" then hasGeneralTab = true end
end
check(not hasGeneralTab, "and General is no longer a tab of its own")
eq(order[table.getn(order)], "Modules", "and Modules is last")

local hasTab = {}
for i = 1, table.getn(order) do hasTab[order[i]] = true end

check(hasTab["Unit Frames"], "unit frames have a tab")
check(hasTab["Nameplates"], "nameplates too")
check(hasTab["Threat Meter"], "the threat meter")
check(hasTab["Damage Meter"], "and the damage meter")

--[[ **A meter's second column is its sections**, built from the markers in its
     own options list -- so declaring one is what creates the column entry, and a
     module cannot have an entry with no rows behind it or rows with no way to
     reach them. ]]--
OB.SelectCategory("Threat Meter")

local threatSubs = shownSubs()
eq(table.getn(threatSubs), 3, "the threat meter has three sections")

OB.SelectCategory("Damage Meter")
eq(table.getn(shownSubs()), 3, "and so does the damage meter")

--[[ Same three, in the same order, because two meters side by side that group
     their settings differently make you learn the layout twice. ]]--
eq(threatSubs[1].label:GetText(), "Window", "starting at Window")
eq(threatSubs[2].label:GetText(), "Bar", "then Bar")
eq(threatSubs[3].label:GetText(), "Text", "then Text")

--[[ Picking a section shows its rows and hides the others'. The Gap slider is
     on Bar, so it is absent while Text is selected -- which is the whole point
     of the column and the thing a page-long list could not do. ]]--
OB.panel.section.damage = "bar"
OB.RefreshPanel()
check(OB.widgets["module:damage:windows.1.gap"].visible,
        "the gap slider is on the Bar section")

OB.panel.section.damage = "text"
OB.RefreshPanel()
check(not OB.widgets["module:damage:windows.1.gap"].visible,
        "and gone when another section is picked")

check(OB.widgets["module:damage:windows.1.showRank"].visible,
        "while the Text section's own rows are there")

OB.panel.section.damage = nil

--[[ **A page gets a second column exactly when its module declares sections**,
     which is the rule rather than a list of which pages have one.

     Unit Frames was the page that proved the "no sections, no column" half --
     it declared none, so it was one long list. It declares five now that the
     port has landed, and the assertion moves with it rather than being deleted:
     the same rule, seen from the other side.

     Profiles is the page with no sections now, and it is a better example
     anyway -- it is a list of profiles, and sections of a list would be an
     invention. ]]--
OB.SelectCategory("Profiles")
eq(table.getn(shownSubs()), 0, "a page that declares no sections has no column")

OB.SelectCategory("Unit Frames")
check(table.getn(shownSubs()) > 0,
        "and one that declares them gets one",
        "sections: " .. table.getn(shownSubs()))

--[[ **Unit frames and nameplates are live subsystems now**, not development
     placeholders: their settings are yours to set, Show works, and they carry a
     switch on the Modules page like anything else.

     What is still missing is the drawing -- both are `renders = "none"` until
     their port lands. That order is deliberate. A greyed page cannot be
     configured in advance, and configuring in advance is exactly what somebody
     does while waiting for a subsystem they have been promised. ]]--
check(not OB.modules.unitframes.development,
        "unit frames are no longer in development")
check(OB.widgets["moduleShow::unitframes"] == nil,
        "and carry no Show switch, which no tab does any more")

check(OB.widgets["moduleToggle::threat@list"] ~= nil,
        "a finished subsystem has a switch on the Modules page")
check(OB.widgets["moduleToggle::unitframes@list"] ~= nil,
        "and so does one whose drawing is still to come")

--[[ **Its settings are listed and live.**

     The list is still the plan -- a name says what a subsystem will be, the
     settings say what it will actually let you *do*, which is the part worth
     arguing about before it is written. They were dimmed while the module was
     flagged development; now they are not, so somebody can set them up before
     the drawing arrives rather than after. ]]--
OB.SelectCategory("Unit Frames")

local plannedRows, plannedLive = 0, 0
for i = 1, table.getn(OB.modules.unitframes.options) do
    local key = OB.modules.unitframes.options[i][2]
    local widget = OB.widgets["module:unitframes:" .. key]

    if widget and widget.visible then
        plannedRows = plannedRows + 1
        if not widget.greyed then plannedLive = plannedLive + 1 end
    end
end

--[[ Only the selected section's rows are on the page now, so ten is the wrong
     bar -- a section holds five. What is being asserted is that the page has
     real settings on it rather than how many, and five is the smallest section
     unit frames has. ]]--
check(plannedRows >= 4, "unit frames list their settings",
        "listed " .. plannedRows)
eq(plannedLive, plannedRows, "and every one of them is live")

-- and the same for nameplates, so the rule is the module's flag and not a
-- per-row decision somebody has to remember
check(table.getn(OB.modules.nameplates.options) > 10, "and so do nameplates")
eq(OB.widgets["module:threat:width"].greyed, false,
        "a finished module's settings stay live")

eq(OB.modules.threat.development, false, "the threat meter is not")

--[[ A finished subsystem's settings stay live, or the dimming checks above
     would pass on a panel that had greyed everything. ]]--
OB.SelectCategory("Threat Meter")
local threatRow = OB.widgets["module:threat:width"]
check(threatRow ~= nil, "the threat meter has its own settings rows")
check(threatRow.visible, "which are on its own tab")
eq(threatRow.greyed, false, "and live rather than dimmed")

end


-- ---------------------------------------------------------------------------
-- 34. one look, shared by every subsystem
-- ---------------------------------------------------------------------------

local function lookTests()

--[[ **Texture, font, font size, outline and border are the five settings that
     make five separate addons look like five separate addons.**

     They belong to the profile, so setting them once sets them everywhere --
     that is the premise of this addon. A subsystem may still disagree, because
     nameplates want a smaller font than a HUD bar does, so each carries the same
     five keys and a switch that is off by default. ]]--
context = "shared look: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

--[[ Every feature gets the full lists, not a subset. A subsystem offering four
     of the twenty fonts would be exactly the fragmentation this replaces. ]]--
local look = OB.LookOptions()
local offered = {}
for i = 1, table.getn(look) do offered[look[i][2]] = look[i][3] end

eq(offered.texture, OB.textures, "every subsystem offers every texture")
eq(offered.font, OB.fonts, "and every font")
check(table.getn(OB.fonts) > 15, "which is the whole list, not a subset",
        table.getn(OB.fonts) .. " fonts")

--[[ **There is no switch, and that is the point.**

     There was a `Use The Shared Look` toggle with the five settings greyed out
     beneath it, which made the common case -- change this subsystem's font --
     two clicks and a moment working out why the control was dead. Setting one
     *is* the override; leaving it alone *is* sharing. ]]--
check(OB.profile.modules.threat.texture == nil, "a subsystem stores no texture of its own")
eq(OB.Look("threat").texture, OB.profile.texture, "so it reads the shared one")
eq(OB.TexturePath("threat"), OB.TexturePath(), "and resolves to the same path")

-- the shared setting still reaches it after the fact, which a copied default
-- would have broken
OB.profile.texture = 3
eq(OB.Look("threat").texture, 3, "changing the shared one changes it too")

--[[ Setting one key overrides that key and nothing else. A subsystem that wants
     a smaller font still follows the shared texture. ]]--
OB.profile.modules.threat.texture = 6
eq(OB.Look("threat").texture, 6, "an override wins for the key it sets")
eq(OB.Look("threat").font, OB.profile.font, "and inherits the ones it does not")

OB.profile.modules.threat.texture = nil
eq(OB.Look("threat").texture, 3, "clearing it goes back to sharing")

--[[ The rows are on every subsystem's page, from one place, so a new subsystem
     cannot arrive with four of the five and a differently worded fifth. ]]--
OB.TogglePanel()

local tabs = { "threat", "damage", "unitframes", "nameplates" }
local missing = {}

for i = 1, table.getn(tabs) do
    for k = 1, table.getn(look) do
        local key = look[k][2]
        if key ~= "__h_look" then
            if not OB.widgets["module:" .. tabs[i] .. ":" .. key] then
                table.insert(missing, tabs[i] .. "." .. key)
            end
        end
    end
end

eq(table.getn(missing), 0, "all four subsystems carry the appearance block",
        table.concat(missing, ", "))

check(OB.widgets["module:threat:ownLook"] == nil, "and none of them has a switch")

end

lookTests()

-- ---------------------------------------------------------------------------
-- 35. the combat log parser, and the damage meter on top of it
-- ---------------------------------------------------------------------------

local function damageTests()

--[[ **The parser never reads English.** It turns the client's own format
     strings into Lua patterns, so whatever language the client speaks is what it
     understands. Derived from ShaguDPS -- see NOTICE.

     Driven directly with lines rather than through the meter, because it is a
     pure function of a line and an event and that is the whole reason it is
     separable. ]]--
context = "combat log: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local me = UnitName("player")

local function read(ev, line) return OB.ReadCombatLine(ev, line) end

local swing = read("CHAT_MSG_COMBAT_SELF_HITS", "You hit Sprite Darter for 143.")
check(swing ~= nil, "a white swing parses")
eq(swing.source, me, "attributed to the player")
eq(swing.target, "Sprite Darter", "against the target named")
eq(swing.amount, 143, "for the amount stated")
eq(swing.kind, "damage", "as damage")

local strike = read("CHAT_MSG_SPELL_SELF_DAMAGE",
        "Your Sinister Strike hits Sprite Darter for 212.")
eq(strike.spell, "Sinister Strike", "a spell carries its name")
eq(strike.amount, 212, "and its amount")

--[[ A crit with a school is the longest sentence in the set and the one where
     the greedy-name problem bites: without numbers taking priority over strings,
     the name capture swallows the target and the digits with it. ]]--
local crit = read("CHAT_MSG_SPELL_SELF_DAMAGE",
        "Your Fireball crits Sprite Darter for 480 Fire damage.")
eq(crit.spell, "Fireball", "a crit with a school still finds the spell")
eq(crit.target, "Sprite Darter", "and the target")
eq(crit.amount, 480, "and the number rather than eating it into the name")

-- somebody else's damage, which is a different sentence entirely
local ally = read("CHAT_MSG_COMBAT_PARTY_HITS", "Tankman hits Sprite Darter for 98.")
eq(ally.source, "Tankman", "another player's swing names them")
eq(ally.amount, 98, "for their amount")

-- healing is its own kind, not damage with a different sign
local heal = read("CHAT_MSG_SPELL_SELF_BUFF",
        "Your Healing Touch heals Tankman for 620.")
eq(heal.kind, "heal", "a heal parses as a heal")
eq(heal.target, "Tankman", "on the player healed")
eq(heal.amount, 620, "for the amount")

local hot = read("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
        "Sprite Darter suffers 45 Shadow damage from your Corruption.")
eq(hot.spell, "Corruption", "a periodic effect names its spell")
eq(hot.source, me, "and credits whoever applied it")

--[[ Absorb and resist are suffixes on an otherwise ordinary sentence, so they
     are stripped before matching. Left in place they break the trailing capture
     of every pattern they follow. ]]--
local absorbed = read("CHAT_MSG_COMBAT_SELF_HITS",
        "You hit Sprite Darter for 143. (30 absorbed)")
check(absorbed ~= nil, "an absorb suffix does not stop the line parsing")
eq(absorbed.amount, 143, "and the damage is still read")

-- a line the parser has no sentence for is nil, not a zero-damage row
check(read("CHAT_MSG_SAY", "hello") == nil, "an unrelated event reads as nothing")
check(read("CHAT_MSG_COMBAT_SELF_HITS", "something else entirely") == nil,
        "and so does a line no sentence matches")

-- ---------------------------------------------------------------------------

--[[ **Two segments, always both.** Overall runs until reset, current starts
     fresh at each pull. Kept simultaneously rather than switched, because the
     moment anyone wants the other one the fight is over and recomputing it is
     impossible. ]]--
context = "damage meter: "

OB.profile.modulesEnabled.damage = true
OB.BindSlots()

local meter = OB.modules.damage
local cfg = OB.profile.modules.damage

check(meter.frames and meter.frames[1] ~= nil, "the window is built on bind")
eq(meter.development, false, "and the damage meter is no longer a plan")

meter:Reset()
Stub.SetGroup({ { name = "Tankman", class = "WARRIOR" } }, true)

local function hit(name, amount)
    OB.AddCombatLine(meter.data,
            { source = name, target = "Sprite Darter", amount = amount,
              kind = "damage" }, GetTime())
end

hit(me, 1000)
hit("Tankman", 400)
hit(me, 500)

local rows = OB.DamageRows(meter.data.current, "damage")
eq(table.getn(rows), 2, "one row per source")
eq(rows[1].name, me, "highest total first")
eq(rows[1].total, 1500, "with the hits summed")
eq(rows[2].total, 400, "and the next below it")

--[[ Share is of the segment's own total, so the top row is not automatically a
     hundred percent -- it is however much of the work it actually did. ]]--
near(rows[1].share, 1500 / 1900, 0.001, "share is of the whole segment")
near(rows[2].share, 400 / 1900, 0.001, "for every row")

--[[ Duration is floored at a second. The first line of a fight arrives at zero
     elapsed, and dividing by that is an error or an infinity depending on the
     platform -- neither belongs in a number somebody reads mid-pull. ]]--
eq(OB.SegmentDuration(meter.data.current), 1, "a fight that just started lasts a second")
eq(rows[1].perSecond, 1500, "so a rate is finite from the first hit")

--[[ Healing is counted separately, not as damage with a different sign. A meter
     that mixed them would rank a healer against a rogue on one axis neither of
     them is on. ]]--
OB.AddCombatLine(meter.data,
        { source = "Tankman", target = me, amount = 900, kind = "heal" }, GetTime())

eq(table.getn(OB.DamageRows(meter.data.current, "heal")), 1, "a heal lands in healing")
eq(OB.DamageRows(meter.data.current, "damage")[2].total, 400,
        "and does not touch the damage totals")

--[[ A pull clears the current segment and leaves overall alone. That asymmetry
     is why both are kept: overall is the thing you would have lost by
     switching. ]]--
cfg.resetOnPull = true
Stub.FireEvent("PLAYER_REGEN_DISABLED")

eq(table.getn(OB.DamageRows(meter.data.current, "damage")), 0, "a pull clears the fight")
eq(OB.DamageRows(meter.data.overall, "damage")[1].total, 1500,
        "and leaves the overall totals standing")

--[[ End to end: a real combat log line, through the event handler, into the
     totals. Everything above tested the pieces; this is the seam between
     them. ]]--
meter:Reset()
Stub.FireEvent("CHAT_MSG_SPELL_SELF_DAMAGE",
        "Your Eviscerate crits Sprite Darter for 750.")

local live = OB.DamageRows(meter.data.current, "damage")
eq(table.getn(live), 1, "a combat log event reaches the meter")
eq(live[1].name, me, "credited to the player")
eq(live[1].total, 750, "for the amount the log said")

--[[ Off by default the meter follows the group: a boss's own damage is noise
     you cannot improve and it dwarfs everybody. ]]--
cfg.trackAll = false
Stub.FireEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS",
        "Sprite Darter hits Tankman for 300.")
eq(table.getn(OB.DamageRows(meter.data.current, "damage")), 1,
        "a mob outside the group is not counted")

cfg.trackAll = true
Stub.FireEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS",
        "Sprite Darter hits Tankman for 300.")
eq(table.getn(OB.DamageRows(meter.data.current, "damage")), 1,
        "and asking for everything does not mean asking for the mobs")

--[[ **"Nearby players" means players.** It used to return true for every line
     in the log, so the boss, its adds and every critter in earshot arrived in
     the list under their own names -- which is "track everything" rather than
     what the row says.

     The roster is what tells the two apart: every path into it is player-only,
     so a name being in it is proof. A name that is not in it is not proof of
     anything, which is the honest limit -- 1.12 hands the combat log over as
     text and nothing in a line says what kind of thing said it. ]]--
OB.roster["Stranger"] = { class = "MAGE" }

Stub.FireEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS",
        "Stranger hits Sprite Darter for 300.")
eq(table.getn(OB.DamageRows(meter.data.current, "damage")), 2,
        "a player the roster knows is counted")

OB.roster["Stranger"] = nil
cfg.trackAll = false

OB.profile.modulesEnabled.damage = nil
OB.BindSlots()

end

damageTests()

-- ---------------------------------------------------------------------------
-- 36. damage taken, the header bar, and rows that wrap
-- ---------------------------------------------------------------------------

local function meterHeaderTests()

--[[ **Damage taken is a third bucket, not a filter on the first.**

     Damage and healing are keyed by who did it. Taken is keyed by who it
     happened to, which is the whole reason it is separate: a tank wants to know
     what they are absorbing, and the source of it is a boss they cannot
     influence. Same lines, opposite end. ]]--
context = "damage taken: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local me = UnitName("player")

OB.profile.modulesEnabled.damage = true
OB.BindSlots()

local meter = OB.modules.damage
local cfg = OB.profile.modules.damage

meter:Reset()

OB.AddCombatLine(meter.data, { source = me, target = "Boss",
        amount = 500, kind = "damage" }, GetTime())
OB.AddCombatLine(meter.data, { source = "Boss", target = "Tankman",
        amount = 1200, kind = "damage" }, GetTime())
OB.AddCombatLine(meter.data, { source = "Boss", target = me,
        amount = 300, kind = "damage" }, GetTime())

local done = OB.DamageRows(meter.data.current, "damage")
eq(done[1].name, "Boss", "damage done still credits the source")
eq(done[1].total, 1500, "summing what it dealt")

local taken = OB.DamageRows(meter.data.current, "taken")
eq(taken[1].name, "Tankman", "taken credits whoever received it")
eq(taken[1].total, 1200, "for what landed on them")
--[[ The boss is in this list too, and correctly: the player hit it for 500, so
     500 landed on it. A taken list that only held players would be answering a
     different question than the one it is named for. ]]--
eq(taken[2].name, "Boss", "including whatever the group hit")
eq(taken[2].total, 500, "for what landed on it")
eq(taken[3].name, me, "and everybody else below")
eq(taken[3].total, 300, "for theirs")

--[[ Healing does not enter the taken bucket. Healing taken is healing done seen
     from the other side, and counting it here would double every healer. ]]--
OB.AddCombatLine(meter.data, { source = "Priestly", target = "Tankman",
        amount = 900, kind = "heal" }, GetTime())

eq(OB.DamageRows(meter.data.current, "taken")[1].total, 1200,
        "a heal does not add to damage taken")
eq(OB.DamageRows(meter.data.current, "heal")[1].total, 900, "it lands in healing")

--[[ The grand total is summed rather than counted alongside. A running counter
     is a second source of truth for something already stored, and the two only
     ever diverge one way: silently. ]]--
eq(OB.SegmentTotal(meter.data.current, "damage"), 2000,
        "the segment total sums every source, not just the top one")
eq(OB.SegmentTotal(meter.data.current, "heal"), 900, "per bucket")
eq(OB.SegmentTotal(nil, "damage"), 0, "and answers zero for no segment")

-- ---------------------------------------------------------------------------

--[[ **The header is where the window is controlled**, and it carries six
     buttons in ShaguDPS's order -- chat, settings, segment, mode, add/remove
     window, reset -- because that is the order anybody coming from it already
     knows. ]]--
context = "meter header: "

local win = meter:Window(1)

eq(win.segment, "current", "a window starts on the current fight")
eq(win.mode, "damage", "showing damage")

local head = meter.frames[1].head
check(head ~= nil, "the header is built with the window")

local buttons = { head.settings, head.lock, head.segment,
                  head.mode, head.close, head.new }
local built = 0
for i = 1, table.getn(buttons) do
    if buttons[i] then built = built + 1 end
end
eq(built, 6, "with every button")

eq(head.segment.text:GetText(), "Current", "the segment button names the segment")
eq(head.mode.text:GetText(), "Damage", "and the mode button the statistic")

--[[ **The four icon buttons carry art, not letters.** A missing texture is an
     invisible button, so this asserts the path is set rather than that it
     renders -- but a typo in OB.icons is exactly the failure it catches. ]]--
local icons = { head.settings, head.lock, head.close, head.new }
for i = 1, table.getn(icons) do
    check(icons[i].icon and icons[i].icon:GetTexture() ~= nil,
            "icon button " .. i .. " has a texture")
end

--[[ The padlock shows the state it is *in*, never the state clicking reaches.
     Both readings of the other choice are equally plausible, so half the people
     looking at it would guess wrong. ]]--
eq(win.locked, false, "a window starts unlocked")
eq(head.lock.icon:GetTexture(), OB.icons.unlock, "and shows an open padlock")

win.locked = true
meter:StyleWindow(meter.frames[1])
eq(head.lock.icon:GetTexture(), OB.icons.lock, "a locked one shows it closed")

win.locked = false
meter:StyleWindow(meter.frames[1])

--[[ **One button in that position: + on the master, X on the rest.** Neither
     ever needs the other's action, so showing both is one dead control per
     window -- and on the master a dead X beside numbers nobody can recompute. ]]--
check(not head.close:IsShown(), "the master window has no close button")
check(head.new:IsShown(), "only a plus")

--[[ **The padlock, clicked**, for the reason the threat meter's is: it was
     reported throwing "attempt to index local cfg", and a script that is present
     and dies is exactly as broken as one that is missing. ]]--
Stub.Click(head.lock)
eq(win.locked, true, "clicking the padlock locks the window")
eq(head.lock.icon:GetTexture(), OB.icons.lock, "and the icon follows")

Stub.Click(head.lock)
eq(win.locked, false, "and clicking it again unlocks")

--[[ **A lock holds the window still. It does not freeze what the window is
     showing.**

     Which segment and which statistic are questions about the *readout*, and
     they are asked most often mid-fight -- exactly when the window is locked so
     it cannot be knocked out of place. A lock that took those with it would make
     "stop this moving" and "stop me changing this" the same switch, and nobody
     wants the second one.

     Driven rather than inspected: the buttons are the only way to reach these
     two, so a lock that quietly disabled them would look identical to a lock
     that did not. ]]--
win.locked = true
meter:StyleWindow(meter.frames[1])

Stub.Click(head.segment)
check(meter.frames[1].menu and meter.frames[1].menu:IsShown(), "a locked window still opens its menus")

Stub.Click(meter.frames[1].menu.items[2])
eq(win.segment, "overall", "and picking from one still changes the segment")

Stub.Click(head.mode)
Stub.Click(meter.frames[1].menu.items[2])
eq(win.mode, "heal", "the statistic too")

eq(win.locked, true, "none of which unlocked the window")

--[[ What the lock *does* hold: the window cannot be dragged and cannot be
     resized. Both are position and size -- the things a lock is for. ]]--
check(not meter.frames[1].grip:IsShown(), "a locked window has no resize grip")

local heldX = win.x
Stub.cursorX, Stub.cursorY = 0, 0
meter.frames[1].sizing = true
meter.frames[1].sizeFrom = { 0, 0 }
Stub.cursorX = 400
meter:StepResize(meter.frames[1])

local heldWidth = win.width
meter:StepResize(meter.frames[1])
eq(win.width, heldWidth, "and the grip cannot resize it")
eq(win.x, heldX, "nor can it be moved")
check(not meter.frames[1].sizing, "the resize drops rather than lingering")

win.segment = "current"
win.mode = "damage"
win.locked = false
meter:StyleWindow(meter.frames[1])

--[[ **Buttons carry their window rather than walking up to it.** Two GetParent
     calls is one refactor from resolving to a frame with no index, and then the
     handler dies on the next line -- which is what happened. ]]--
eq(head.lock.window, meter.frames[1], "a header button knows its own window")
eq(head.new.window, meter.frames[1], "all of them do")

--[[ No chat button, removed on request, asserted so it does not return with the
     next header edit. ]]--
check(head.chat == nil, "the header has no chat button")
check(meter.Report == nil, "and no reporting code behind it")

check(not meter.frames[1]:IsClampedToScreen(),
        "the window is not clamped by the client -- see the threat meter")

--[[ **Three groups: window controls left, the two menus centred, add/close
     right.** They are three kinds of thing and reading them as one strip of
     seven meant scanning it every time. ]]--
eq(head.lock.points[1][1], "LEFT", "the padlock is anchored left")
eq(head.settings.points[1][1], "LEFT", "and the cog beside it")
eq(head.new.points[1][1], "RIGHT", "the corner button is anchored right")
eq(head.segment.points[1][3], "CENTER", "the menus hang off the centre")

--[[ Centred as a *pair*, so the two together sit on the midline rather than one
     of them landing there and the other beside it. ]]--
local pairWidth = head.segment:GetWidth() + head.mode:GetWidth() + 2
eq(head.segment.points[1][4], -(pairWidth / 2),
        "offset by half their combined width")

--[[ **The window's body carries the background, not each row**, so raising the
     gap cannot cut stripes of whatever is behind the window through it. ]]--
win.gap = 6
OB.Refresh(true)

check(meter.frames[1].body ~= nil,
        "the window has one background behind every row")
eq(meter.frames[1].body.rgba[4], win.bg[4],
        "painted with the window's own colour")
eq(meter.frames[1].rows[1].bg.rgba[4], 0,
        "and the rows have none of their own")

eq(meter:RowStep(win), win.height + (OB.BorderPad("damage") * 2) + 6,
        "the gap still spaces the rows")

win.gap = 0
OB.Refresh(true)

win.segment = "overall"
win.mode = "taken"
meter:StyleWindow(meter.frames[1])

eq(head.segment.text:GetText(), "Overall", "both follow the window")
eq(head.mode.text:GetText(), "Taken", "as it changes")

win.segment = "current"
win.mode = "damage"

--[[ **A second window, over the same totals.** Window one carries the plus and
     is never removable -- it is the one the settings page edits, and a meter
     with no windows is a subsystem you can only switch off. ]]--
eq(table.getn(meter:Config().windows), 1, "one window to start")

meter:AddWindow()
eq(table.getn(meter:Config().windows), 2, "the plus adds another")
check(meter.frames[2] ~= nil, "and it is built")
check(meter:Window(2).x ~= meter:Window(1).x,
        "offset from the first, so it is not hidden underneath it")

check(meter.frames[2].head.close:IsShown(), "which does have a close button")
check(not meter.frames[2].head.new:IsShown(), "and no plus")

--[[ **Windows do not overlap.** Two stacked on each other are unreadable and,
     worse, unrecoverable -- the one underneath cannot be grabbed to move it, so
     the only way out is a slider for a window you cannot see.

     Dropped straight on top of window one, it lands clear below it. ]]--
local second = meter.frames[2]
Stub.cursorX, Stub.cursorY = 0, 0

second:ClearAllPoints()
second:SetPoint("CENTER", UIParent, "CENTER",
        meter:Window(1).x, meter:Window(1).y)
meter:StoreWindowPosition(second)

local one, two = meter:Window(1), meter:Window(2)
local clearance = (meter.frames[1]:GetHeight() + second:GetHeight()) / 2

check(math.abs(one.y - two.y) >= clearance
                or math.abs(one.x - two.x) >= ((one.width + two.width) / 2),
        "a window dropped on another is pushed clear of it",
        "one at " .. one.y .. ", two at " .. two.y)

--[[ Downwards, never sideways. A window pushed horizontally lands where the
     next one is going to go, so a third drop cascades; down is the direction a
     list of windows grows anyway, and the one that can be predicted. ]]--
check(two.y < one.y, "and pushed downwards")

meter:RemoveWindow(1)
eq(table.getn(meter:Config().windows), 2, "window one cannot be removed")

meter:RemoveWindow(2)
eq(table.getn(meter:Config().windows), 1, "but the others can")

--[[ Both windows read one set of totals, which is the whole reason to have two:
     damage in one and healing beside it, from the same fight. ]]--
meter:Reset()
OB.AddCombatLine(meter.data, { source = me, target = "Boss",
        amount = 2500, kind = "damage" }, GetTime())

meter:AddWindow()
meter:Window(2).mode = "heal"

eq(OB.DamageRows(meter.data.current, "damage")[1].total, 2500,
        "the totals are shared")
eq(table.getn(OB.DamageRows(meter.data.current, "heal")), 0,
        "and each window asks its own question of them")

meter:RemoveWindow(2)

--[[ **Rows are inset by the border's own width**, so two of them cannot draw
     their borders over each other and none hangs over the window's edge.

     This is the bug RogueBars had: a border is art *outside* the bar, so bars
     packed edge to edge overlap by twice the pad however carefully the heights
     line up. ]]--
context = "meter layout: "

OB.profile.border = 3
OB.Refresh(true)

local pad = OB.BorderPad("damage")
check(pad > 0, "a standard border has a pad")

local step = meter:RowStep(win)
check(step > win.height + pad, "rows are spaced by more than their own height",
        "step " .. step .. " for height " .. win.height)

local frame = meter.frames[1]
eq(frame.rows[1]:GetWidth(), win.width - (pad * 2),
        "and inset on both sides, so no border hangs over the edge")

--[[ **And by exactly the pad, never a pixel more.** A spare pixel is invisible
     against border art and is a stripe of window background between every pair
     of rows once the border is off. That gap was reported from the game and the
     harness had no opinion about it, so it gets one. ]]--
eq(step, win.height + (pad * 2), "spaced by exactly the border's own width")

--[[ Two adjacent rows clear each other by at least the border art's width,
     which is the property the overlap actually turns on. ]]--
local firstY = frame.rows[1].points[1][5]
local secondY = frame.rows[2].points[1][5]
check((firstY - secondY) >= (win.height + pad),
        "and adjacent rows clear each other's border art")

--[[ **No border, no gap.** With nothing drawn outside the bar there is nothing
     to clear, so consecutive rows touch and the window background never shows
     between them. This is the direction the reported bug was in. ]]--
OB.profile.border = 1
OB.Refresh(true)

eq(OB.BorderPad("damage"), 0, "the plain border has no pad")
eq(meter:RowStep(win), win.height, "so rows are spaced by exactly their height")

local touchA = frame.rows[1].points[1][5]
local touchB = frame.rows[2].points[1][5]
eq(touchA - touchB, win.height, "and two of them touch, with no gap between")

--[[ **Text is sized by the font setting, not by the bar.**

     It used to be `height - 5`, which tied the text to the row's height and left
     this subsystem's Font Size slider doing nothing: dragging the height resized
     the text, and the control meant to resize the text did not. ]]--
local function rowFontSize()
    local _, size = frame.rows[1].left:GetFont()
    return size
end

OB.profile.modules.damage.fontSize = 9
OB.Refresh(true)
eq(rowFontSize(), 9, "a row's text takes the font size")

local wasHeight = win.height
win.height = 28
OB.Refresh(true)
eq(rowFontSize(), 9, "and does not follow the row's height")

--[[ **And every column takes it, not just the first.**

     `extra` -- the threat meter's rate column -- was added to the bar and not to
     the styling pass, so it kept whatever `GameFontHighlight` is while its
     neighbours followed the setting. One column ignoring the font picker, which
     reads as the picker being broken.

     Driven off `OB.BAR_TEXTS` rather than naming the four, so the next column
     added is caught by this the moment it exists. That is the only version of
     this test worth having: the bug was a list that got out of step with
     itself, and a test with its own copy of the list would go out of step the
     same way. ]]--
local unstyled = {}

for i = 1, table.getn(OB.BAR_TEXTS) do
    local name = OB.BAR_TEXTS[i]
    local text = frame.rows[1][name]

    if not text then
        table.insert(unstyled, name .. " (missing)")
    else
        local _, size = text:GetFont()
        if size ~= 9 then
            table.insert(unstyled, name .. " (" .. tostring(size) .. ")")
        end
    end
end

check(table.getn(OB.BAR_TEXTS) >= 4, "a bar has all four of its texts named",
        table.concat(OB.BAR_TEXTS, ", "))
eq(table.getn(unstyled), 0, "and every one of them follows the font size",
        table.concat(unstyled, ", "))

win.height = wasHeight
OB.profile.modules.damage.fontSize = nil
OB.Refresh(true)

--[[ **Redraws per second, one to ten.** A real speed rather than a throttle: the
     totals only move on an event, but the seconds they are divided by do not. ]]--
eq(meter:Config().updateRate, 2, "the meter redraws twice a second by default")
near(meter:RedrawStep(), 0.5, 0.001, "which is half a second between draws")

meter:Config().updateRate = 10
near(meter:RedrawStep(), 0.1, 0.001, "ten a second is a tenth of a second")

-- a saved value from some future build cannot stop the meter redrawing at all
meter:Config().updateRate = 900
near(meter:RedrawStep(), 0.1, 0.001, "and it is clamped to the slider's bounds")

--[[ **The preview re-seeds at that rate too.**

     It was pinned at once a second, so dragging the slider to ten changed
     nothing you could see: the redraw was ten a second over numbers that moved
     once. The setting read as broken, and a preview that cannot show what a
     setting does is not previewing it. ]]--
meter:Config().updateRate = 10
OB.SetTestMode(true)

local seeds = 0
local lastTop = nil

for i = 1, 12 do
    Stub.Tick(0.1, 1)
    local now = OB.DamageRows(meter.data.current, "damage")
    if now[1] and now[1].total ~= lastTop then
        seeds = seeds + 1
        lastTop = now[1].total
    end
end

check(seeds > 4, "ten a second re-seeds several times in a second",
        "re-seeded " .. seeds .. " times over 1.2s")

OB.SetTestMode(false)
meter:Config().updateRate = 2

--[[ The grip resizes, and a locked window has none: a lock that still lets the
     window be resized is not a lock. ]]--
check(frame.grip ~= nil, "the window has a resize grip")

win.locked = true
meter:StyleWindow(frame)
check(not frame.grip:IsShown(), "which is hidden when the window is locked")

win.locked = false
meter:StyleWindow(frame)
check(frame.grip:IsShown(), "and back when it is not")

--[[ **The grip writes width and row count**, not a frame size, so the window is
     always a whole number of rows tall. Dragging it is the same edit the two
     sliders make, which is why the two can never disagree. ]]--
local wasWidth, wasRows = win.width, win.rows

Stub.cursorX, Stub.cursorY = 500, 500
frame.sizing = true
frame.sizeFrom = { 500, 500 }

-- right and down: wider, and taller by whole rows
Stub.cursorX, Stub.cursorY = 560, 500 - (meter:RowStep(win) * 2)
meter:StepResize(frame)

eq(win.width, wasWidth + 60, "dragging right widens the window")
eq(win.rows, wasRows + 2, "and dragging down adds whole rows")

eq(frame:GetHeight(), frame.head:GetHeight() + (meter:RowStep(win) * win.rows)
        + (OB.BorderPad("damage") * 2),
        "the frame follows, so no row is drawn outside the window")

--[[ The drag stops at the sliders' own bounds. A value that arrived by dragging
     must not reach somewhere the panel could never set it. ]]--
Stub.cursorX, Stub.cursorY = Stub.cursorX + 4000, Stub.cursorY - 4000
meter:StepResize(frame)

eq(win.width, 500, "and it stops at the widest the slider allows")
eq(win.rows, 40, "and the most rows")

-- a locked window ignores a drag already in progress
win.locked = true
Stub.cursorX = Stub.cursorX - 200
meter:StepResize(frame)
eq(win.width, 500, "locking mid-drag stops the resize")
check(not frame.sizing, "and drops the drag")

win.locked = false
win.width, win.rows = wasWidth, wasRows
frame.sizing = nil
OB.Refresh(true)

--[[ **All four columns, independently.** Rank answers "am I third" without
     counting rows; the other three answer how much, how fast and what share. ]]--
context = "meter columns: "

eq(win.showRank, true, "ranks ship on")
eq(win.showTotal, true, "totals too")
eq(win.showPerSecond, true, "rates")
eq(win.showPercent, true, "and shares")

meter:Reset()
OB.AddCombatLine(meter.data, { source = me, target = "Boss",
        amount = 2500, kind = "damage" }, GetTime())

local row = OB.DamageRows(meter.data.current, "damage")[1]

eq(meter:RowName(win, 1, row), "1. " .. me, "a row is numbered")
win.showRank = false
eq(meter:RowName(win, 1, row), me, "and the number can be switched off")
win.showRank = true

local text = meter:RowText(win, row)
check(string.find(text, "2.5k", 1, true) ~= nil, "a row shows its total")
check(string.find(text, "%%") ~= nil, "and its share")

win.showPercent = false
check(string.find(meter:RowText(win, row), "%%") == nil,
        "any column can be switched off")
win.showPercent = true

--[[ **Bar colour, then class -- and the fallback is the dull one.**

     The bug this pins: the fallback used to be a hardcoded grey here and the
     *threat ramp* on the threat meter, so a row whose class could not be
     resolved came out either arbitrary or coloured as though it were about to
     pull. Both read as "class colouring isn't working", and on the threat meter
     also as "the gradient is applying to all bars". ]]--
context = "meter colors: "

win.classColor = false
local plain = meter:RowColor(win, { name = "Nobody" })
eq(plain, win.barColor, "with class colouring off a row is the bar colour")

win.classColor = true
Stub.SetGroup({}, false)

eq(meter:RowColor(win, { name = "Nobody" }), win.barColor,
        "and a name with no class falls back to it, not to something louder")

--[[ A name the roster *can* answer for takes its class colour, which is the
     path that was never once exercised. ]]--
local rr, rg, rb = OB.ClassColor("ROGUE")
local mineColor = meter:RowColor(win, { name = me })
near(mineColor[1], rr, 0.001, "your own row takes your class colour")
near(mineColor[2], rg, 0.001, "on every channel")

--[[ And the preview asserts its rows' classes, because a preview row is in no
     group and the roster can never answer for it. Without that the colour
     preview showed the fallback seven times and nothing else. ]]--
OB.SetTestMode(true)

local mageColor = meter:RowColor(win, { name = "Mage" })
local mr, mg, mb = OB.ClassColor("MAGE")
near(mageColor[1], mr, 0.001, "a preview row is coloured by the class it names")
near(mageColor[3], mb, 0.001, "on every channel")

OB.SetTestMode(false)
eq(OB.classHint["Mage"], nil, "and the hint is cleared when the preview stops")

--[[ **The preview moves.** A still one shows the colours and hides everything
     about the motion -- whether the ordering settles, whether a row overtaking
     another is readable. Those are what is worth looking at before a raid. ]]--
context = "meter preview: "

OB.SetTestMode(true)

local before = OB.DamageRows(meter.data.current, "damage")
check(table.getn(before) > 3, "the preview seeds a plausible raid",
        "seeded " .. table.getn(before))

local firstTotal = before[1].total
local moved = false

for i = 1, 8 do
    Stub.Tick(0.5, 3)
    local now = OB.DamageRows(meter.data.current, "damage")
    if now[1] and now[1].total ~= firstTotal then moved = true end
end

check(moved, "and re-seeds it so the bars actually move")

--[[ The real totals come back untouched. A preview that overwrote them would
     cost somebody the fight they were reading. ]]--
OB.SetTestMode(false)
eq(OB.DamageRows(meter.data.current, "damage")[1].total, 2500,
        "and the real totals survive it")

--[[ **Every option on the page actually writes.**

     Reported as "many damage meter options aren't working", which is a class of
     bug rather than a list: a row whose key does not resolve is written to
     nothing and reads back its old value, silently, and the panel looks fine
     the whole time. The nested `windows.1.*` keys are exactly the shape that
     goes wrong.

     So the whole list is walked rather than a handful spot-checked -- one row
     added with a typo'd key gets caught the first time this runs. ]]--
context = "meter options: "

--[[ Position is the one pair that deliberately does not round-trip: it is bound
     to the screen, so a slider dragged to its end lands on the edge rather than
     at the number. Tested separately, just below, rather than waved through
     here -- "this one is special" has to be an assertion or it is an excuse. ]]--
local bounded = { ["windows.1.x"] = true, ["windows.1.y"] = true,
                  ["x"] = true, ["y"] = true }

local function exercise(moduleId, label)
    local m = OB.modules[moduleId]
    local broken = {}

    for r = 1, table.getn(m.options) do
        local opt = m.options[r]
        local kind, key = opt[3], opt[2]

        if kind ~= "header" and kind ~= "section" and not bounded[key] then
            local w = { scope = "module", module = moduleId, key = key,
                        kind = kind == "boolean" and "boolean" or "slider" }

            local before = OB.ReadOption(w)
            local want

            if kind == "boolean" then
                want = not before
            elseif kind == "slider" then
                want = (before == opt[4]) and opt[5] or opt[4]
            elseif kind == "color" then
                want = { 0.11, 0.22, 0.33, 1 }
            end

            if want ~= nil then
                OB.ApplyOption(w, want)
                local after = OB.ReadOption(w)

                local ok
                if kind == "color" then
                    ok = after and after[1] == 0.11
                else
                    ok = (after == want)
                end

                if not ok then table.insert(broken, key) end
                OB.ApplyOption(w, before)
            end
        end
    end

    check(table.getn(broken) == 0, "every " .. label .. " option writes through",
            table.concat(broken, ", "))
end

--[[ **Where the number came from**, on hover. A total answers "who", and the
     next question is always "off what" -- which cannot be recovered from a total
     afterwards, so the per-spell tables are kept as the lines arrive. ]]--
context = "meter breakdown: "

meter:Reset()

local function hit(spell, amount)
    OB.AddCombatLine(meter.data, { source = me, target = "Boss",
            spell = spell, amount = amount, kind = "damage" }, GetTime())
end

hit("Sinister Strike", 3000)
hit("Sinister Strike", 2000)
hit("Eviscerate", 4000)
hit(nil, 1500)

local spells = OB.DamageSpells(meter.data.current, "damage", me)

eq(table.getn(spells), 3, "three sources of damage")
eq(spells[1].name, "Sinister Strike", "biggest first")
eq(spells[1].total, 5000, "with repeats of one spell summed")
eq(spells[2].name, "Eviscerate", "then the next")

--[[ A swing has no spell and is still the answer to "where did that come from"
     -- usually most of it, for a warrior. Named rather than dropped. ]]--
eq(spells[3].name, "Melee", "a swing is named rather than skipped")
eq(spells[3].total, 1500, "for its amount")

-- the shares are of this player's own damage, not of the raid's
near(spells[1].share, 5000 / 10500, 0.001, "shares are of their own total")

--[[ Damage taken breaks down the same way, which is the reading a tank wants:
     not how much they took but what took it off them. ]]--
local taken = OB.DamageSpells(meter.data.current, "taken", "Boss")
eq(table.getn(taken), 3, "damage taken breaks down by spell too")

--[[ **Hovering a row builds it.** Run rather than inspected: a handler that is
     present and throws is exactly as broken as one that is missing. ]]--
OB.Refresh(true)
Stub.Tick(0.6, 2)

local row = meter.frames[1].rows[1]
eq(row.entryName, me, "a drawn row remembers whose it is")

Stub.Hover(row)

check(GameTooltip:NumLines() > 1, "hovering a row fills the tooltip",
        "lines: " .. GameTooltip:NumLines())
check(string.find(GameTooltip:Line(1):GetText(), me, 1, true),
        "headed by the player's name")
eq(GameTooltip:Line(2):GetText(), "Sinister Strike",
        "then their biggest spell")
check(string.find(GameTooltip:RightLine(2), "5.0k", 1, true),
        "with what it did")
check(string.find(GameTooltip:RightLine(2), "48%%") ~= nil,
        "and its share of their own damage")

--[[ A row with nobody on it says so rather than showing a name and nothing
     under it, which reads as a tooltip that failed to load. ]]--
row.entryName = "Nobody"
Stub.Hover(row)
eq(GameTooltip:Line(2):GetText(), "no breakdown recorded",
        "an unknown row says so")

row.entryName = me

--[[ **A window's position survives a reload.**

     Reported straight from the game, and the shape is worth pinning rather than
     spot-checking: a nested key that writes fine in a session and does not come
     back is the same silent class the option sweep exists for, one level deeper.
     Everything here goes through the real save path -- the profile table the
     addon writes *is* the one in the saved variables. ]]--
context = "meter reload: "

meter:Window(1).x = 173
meter:Window(1).y = -211
meter:Window(1).width = 320
meter:Window(1).gap = 5

--[[ The scenario from the report: window one switched to Overall, a second
     window opened beside it. Both are things the header does, and neither was
     covered -- the old test only checked window one's geometry. ]]--
meter:Window(1).segment = "overall"
meter:AddWindow()
meter:Window(2).x = 400

local saved = EquadisClassicOverhaulDB
OB = boot("ROGUE", 3, { savedVariables = saved })

local after = OB.profile.modules.damage.windows[1]

eq(after.x, 173, "a window's x comes back after a reload")
eq(after.y, -211, "and its y")
eq(after.width, 320, "with everything else about it")
eq(after.gap, 5, "including settings added after the profile was written")
eq(after.segment, "overall", "and which segment the header was left on")

local windows = OB.profile.modules.damage.windows
eq(table.getn(windows), 2, "a second window survives the reload too")
if windows[2] then
    --[[ **Not flattened to the edge.** Both windows are the same width, so a
         hard clamp on every draw would push both to the same limit and stack
         them -- which is how two meters came back from a reload as one meter
         with its header drawn twice. ]]--
    eq(windows[2].x, 400, "at where it was left")
    check(windows[2].x ~= windows[1].x, "and not on top of the first")
end

meter = OB.modules.damage
OB.profile.modulesEnabled.damage = true
OB.BindSlots()
meter:RemoveWindow(2)
meter:Window(1).segment = "current"

meter = OB.modules.damage
OB.profile.modulesEnabled.damage = true
OB.BindSlots()
Stub.Tick(0.6, 2)

eq(meter.frames[1].points[1][4], 173, "and the window is drawn where it was left")
eq(meter.frames[1].points[1][5], -211, "on both axes")

meter:Window(1).width = 220
meter:Window(1).gap = 0
meter:Window(1).x = 0
meter:Window(1).y = 0
OB.Refresh(true)

--[[ **Drawing never moves a window.**

     Three separate mechanisms were caught doing it -- the client's
     SetClampedToScreen, a hard clamp on the draw pass, and a gentler rescue in
     the same place. Each decided for itself where "the screen" ends, and on an
     ultrawide none of them agreed with the monitor, so each one rearranged a
     layout somebody had built, on every load.

     So the property is asserted directly and at an extreme: a coordinate far
     outside any plausible screen survives a draw untouched. If a fourth
     mechanism ever appears, this fails the moment it lands. ]]--
context = "meter placement: "

meter:Window(1).x = 1800
meter:Window(1).y = -1500

OB.Refresh(true)
Stub.Tick(0.6, 2)

eq(meter:Window(1).x, 1800, "a draw leaves the stored x alone")
eq(meter:Window(1).y, -1500, "and the stored y")

-- and again, because the first draw is not the one that historically moved it
OB.Refresh(true)
Stub.Tick(0.6, 2)
eq(meter:Window(1).x, 1800, "however many times it is drawn")

--[[ The drag still clamps. That is a deliberate act on one window, where
     snapping to the edge is help rather than a silent rearrangement. ]]--
local dragged = { scope = "module", module = "damage",
                  key = "windows.1.x", kind = "slider" }
OB.ApplyOption(dragged, 1800)
check(OB.ReadOption(dragged) < 1800, "but typing a coordinate still bounds it")

meter:Window(1).x = 0
meter:Window(1).y = 0
OB.Refresh(true)

--[[ **The page edits every window, not just the first.**

     Its rows are `windows.1.*` because a page needs one concrete thing to bind
     to, and it used to mean exactly that: colour the meter and only the master
     changed. There is no second column of settings for window two, so a setting
     that reached only window one left the rest unreachable. ]]--
context = "meter settings reach: "

meter:AddWindow()

local gapRow = { scope = "module", module = "damage",
                 key = "windows.1.gap", kind = "slider" }

OB.ApplyOption(gapRow, 7)
eq(meter:Window(2).gap, 7, "a setting reaches the windows the page cannot show")

local colorRow = { scope = "module", module = "damage",
                   key = "windows.1.headerColor", kind = "color" }

OB.ApplyOption(colorRow, { 0.3, 0.6, 0.9, 1 })
near(meter:Window(2).headerColor[3], 0.9, 0.001, "colours too")

--[[ Copied, never shared: handing every window the same table would make
     editing any of them edit all of them by accident rather than by rule. ]]--
meter:Window(2).headerColor[3] = 0.1
near(meter:Window(1).headerColor[3], 0.9, 0.001, "each window owns its copy")

--[[ Lock is one of them, which is what makes the page's row **Lock All
     Windows** rather than a control over the master alone. ]]--
local lockRow = { scope = "module", module = "damage",
                  key = "windows.1.locked", kind = "boolean" }

OB.ApplyOption(lockRow, true)
eq(meter:Window(2).locked, true, "locking from the page locks every window")
OB.ApplyOption(lockRow, false)

--[[ Position and the two the header owns stay per-window. Pushing window one's
     coordinates onto the rest would stack them; a second window exists to show
     something the first does not. ]]--
local wasX = meter:Window(2).x
OB.ApplyOption({ scope = "module", module = "damage",
                 key = "windows.1.x", kind = "slider" }, 90)

eq(meter:Window(2).x, wasX, "but position stays a property of one window")

meter:RemoveWindow(2)
OB.ApplyOption(gapRow, 0)

context = "meter options: "
--[[ **A pull-reset segment is a real segment.** This one was hand-built, so
     when `spells` arrived for the hover breakdown it came into the world
     without it -- and every hit after the next pull threw in game. ]]--
Stub.FireEvent("PLAYER_REGEN_DISABLED")
Stub.Tick(0.1, 1)

try("a hit after a pull-reset does not throw", function()
    OB.AddCombatLine(meter.data, { source = me, target = "Boss",
            spell = "Backstab", amount = 900, kind = "damage" }, GetTime())
end)

eq(table.getn(OB.DamageSpells(meter.data.current, "damage", me)), 1,
        "and the breakdown records it")

exercise("damage", "damage meter")

--[[ The threat meter's list too. Its keys are flat rather than nested, so it is
     the less likely of the two to break -- which is exactly why it is worth
     asserting: the day somebody nests one, this says so. ]]--
exercise("threat", "threat meter")

--[[ Position writes like anything else inside the screen... ]]--
local posX = { scope = "module", module = "damage",
               key = "windows.1.x", kind = "slider" }

OB.ApplyOption(posX, 120)
eq(OB.ReadOption(posX), 120, "a position inside the screen writes through")

--[[ ...and is bounded outside it, rather than saved somewhere the window can
     never be seen or dragged back from. ]]--
OB.ApplyOption(posX, 1900)

local frame = meter.frames[1]
local edge = (GetScreenWidth() / 2) - (frame:GetWidth() / 2)

eq(OB.ReadOption(posX), edge, "and one outside it stops at the screen's edge")
check(edge < 2000, "which is well inside the slider's declared range")

OB.ApplyOption(posX, 0)

--[[ **Show and Enable are two settings, not one with two captions.**

     *Enable*, on the Modules page, decides whether the subsystem runs -- binds,
     registers events, ticks and counts. *Show*, on this page, decides only
     whether its windows are on screen.

     They were the same key, which meant neither question could be answered:
     hiding a meter for one pull unbound it, so it stopped counting, and the
     numbers you hid it to stop watching were gone when you looked again. ]]--
context = "meter show: "

meter:AddWindow()
OB.Refresh(true)
Stub.Tick(0.6, 2)

check(meter.frames[1]:IsShown(), "both windows are up")
check(meter.frames[2]:IsShown(), "including the second")

--[[ Hidden, but still counting. This is the whole reason the two are separate:
     hide it for a pull, show it at the end, and the fight is there. ]]--
meter:Reset()
OB.profile.modulesShown.damage = false
OB.Refresh(true)
Stub.Tick(0.6, 2)

check(not meter.frames[1]:IsShown(), "unticking Show hides the window")
check(not meter.frames[2]:IsShown(), "and every other one too")

check(OB.ModuleEnabled("damage"), "the subsystem is still enabled")
check(not OB.ModuleShown("damage"), "just not shown")

OB.AddCombatLine(meter.data, { source = me, target = "Boss",
        amount = 700, kind = "damage" }, GetTime())

eq(OB.DamageRows(meter.data.current, "damage")[1].total, 700,
        "and it keeps counting while hidden")

OB.profile.modulesShown.damage = nil
OB.Refresh(true)
Stub.Tick(0.6, 2)
check(meter.frames[1]:IsShown(), "and ticking it brings them back")

eq(OB.DamageRows(meter.data.current, "damage")[1].total, 700,
        "with the fight it counted while it was away")

--[[ Enable is the heavier one: switching it off unbinds the module entirely, so
     nothing ticks and nothing counts. ]]--
OB.profile.modulesEnabled.damage = false
OB.BindSlots()

check(not meter.frames[1]:IsShown(), "unticking Enable hides it too")
check(OB.features.damage == nil, "and unbinds the subsystem altogether")

OB.profile.modulesEnabled.damage = true
OB.BindSlots()
Stub.Tick(0.6, 2)
check(meter.frames[1]:IsShown(), "re-enabling brings it back")

--[[ **Closing a window closes it for good.** The frame pool used to be
     `table.remove`d alongside the config, which took the frame out of the list
     while leaving it on screen -- and once it is out of the list nothing can
     ever hide it again, because the sweep walks exactly that list. One orphan
     per close, each permanent. That is the second meter that would not go
     away. ]]--
meter:RemoveWindow(2)
OB.Refresh(true)
Stub.Tick(0.6, 2)

eq(table.getn(meter:Config().windows), 1, "one window configured")
check(not meter.frames[2]:IsShown(), "and the closed one is off the screen")
check(meter.frames[2] ~= nil, "still pooled, so it can be hidden again")

--[[ A new window inherits the first one's look, so one opened beside a window
     you spent ten minutes colouring does not arrive in the shipped grey. ]]--
meter:Window(1).headerColor = { 0.5, 0.1, 0.1, 1 }
meter:Window(1).gap = 4

meter:AddWindow()
local made = meter:Window(2)

eq(made.headerColor[1], 0.5, "a new window takes the first one's header color")
eq(made.gap, 4, "and the rest of its appearance")

--[[ Except the mode: a second window showing exactly what the first shows is
     never what anybody meant by opening a second window. ]]--
check(made.mode ~= meter:Window(1).mode, "but not its statistic")

--[[ Copied, not shared. Two windows that cannot differ are one window drawn
     twice, and the whole point is damage in one and healing in the other. ]]--
made.headerColor[1] = 0.9
eq(meter:Window(1).headerColor[1], 0.5, "and the copy is its own table")

meter:RemoveWindow(2)

OB.profile.modulesEnabled.damage = nil
OB.BindSlots()

-- ---------------------------------------------------------------------------

--[[ **A wrapped paragraph is as tall as it wraps to.**

     The options layout advances by a per-kind height, which is one control's
     worth. A subsystem description wraps to four or five lines, so every row
     under it was drawn on top of it -- which is what "the options menu is
     broken" turned out to be. A row may now declare its own height. ]]--
context = "options layout: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.TogglePanel()
OB.SelectCategory("Unit Frames")
OB.RefreshPanel()

local page
for i = 1, table.getn(OB.settings.categories) do
    if OB.settings.categories[i].name == "Unit Frames" then
        page = OB.settings.categories[i].page
    end
end

check(page ~= nil, "the unit frames page exists")

--[[ **No description paragraph on a live subsystem's page.**

     It was a wrapped block of grey text above the settings, and it was
     overlapping the Show checkbox -- a fair summary of how much it was earning.
     Once a subsystem is real, its settings say what it does better than a
     paragraph does.

     The *mechanism* it needed stays and is what the rest of this section
     checks: a row may declare its own height, because the layout otherwise
     advances by one control's worth and draws anything taller on top of
     whatever follows. That is what "the options menu is broken" turned out to
     be, and it will be true again of the next multi-line row. ]]--
local described
for i = 1, table.getn(page.rows) do
    if page.rows[i].advance then described = page.rows[i] end
end

check(described == nil, "a live subsystem's page carries no description")

--[[ And nothing overlaps it. Each visible row in a column sits strictly below
     the one before -- which is the property the per-kind advance quietly broke
     and the reason this is checked rather than eyeballed. ]]--
local lastY, overlaps = nil, 0
for i = 1, table.getn(page.rows) do
    local widget = page.rows[i]

    if widget.visible and (widget.placedColumn or widget.column or 1) == 1 then
        local point = widget.points[1]
        local y = point and point[5]

        if y and lastY and y >= lastY then overlaps = overlaps + 1 end
        lastY = y
    end
end

eq(overlaps, 0, "and no row is drawn on top of another")

end

meterHeaderTests()

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- 38. chat: timestamps
--
-- The first slice of the Prat port. What is asserted here is deliberately the
-- *decision* rather than the drawing: what a message becomes is arithmetic on
-- strings, and only putting it on screen needs a client.
-- ---------------------------------------------------------------------------

local function chatTests()

context = "chat: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local chat = OB.modules.chat
check(chat ~= nil, "the chat module registers")
eq(chat.feature, true, "as a feature")
eq(chat.renders, "none", "that owns no window of its own")

--[[ Off by default. It hooks the chat frames, and anything touching chat next
     to another chat addon should be a decision rather than a surprise. ]]--
eq(OB.ModuleEnabled("chat"), false, "and ships switched off")

OB.profile.modulesEnabled.chat = true
OB.BindSlots()

local cfg = OB.profile.modules.chat

--[[ **Window one only, by default.** People use window one for conversation and
     window three for combat spam: a timestamp is worth having on the first and
     is noise on the second. ]]--
eq(cfg.stamp[1], true, "window one is stamped")
eq(cfg.stamp[3], false, "and the rest are not")

--[[ The prefix a message gets, which is the whole of the behaviour. ]]--
cfg.timeSource = 1
cfg.colorStamp = false

local stamp = chat:Stamp(1)
check(string.find(stamp, "^%d%d:%d%d "), "a stamped window gets a time and a space",
        "got '" .. stamp .. "'")

eq(chat:Stamp(3), "", "an unstamped one gets nothing at all")

--[[ **Always a space.** It was a checkbox, and "01:23Bob: hi" is not a thing
     anybody wanted -- a setting whose off state nobody chooses is a row of noise
     above the ones they do. ]]--
check(OB.modules.chat.defaults.space == nil,
        "and there is no switch to take it away")

--[[ Colour is a wrapper, not a replacement: the time is still in there. ]]--
cfg.colorStamp = true
cfg.stampColor = { 1, 0, 0, 1 }

local colored = chat:Stamp(1)
check(string.find(colored, "|cffff0000", 1, true), "a coloured stamp carries its code")
check(string.find(colored, "|r", 1, true), "and closes it")
check(string.find(colored, "%d%d:%d%d"), "with the time still inside")

--[[ The shape is picked rather than typed. Prat took a raw strftime string
     because a chat command cannot offer a menu; a panel can, and nobody
     remembers which of %X and %H:%M is locale-dependent. ]]--
cfg.colorStamp = false
cfg.timeShape = 4
check(string.find(chat:Stamp(1), "^%d%d:%d%d:%d%d"), "a longer shape has seconds")
cfg.timeShape = 3

--[[ **Three answers, not one of twelve combinations.**

     The list wrote out every pairing of three independent choices, which makes
     the reader find their answer in a set rather than give it -- and several of
     the twelve differed only after ten in the morning, so it could not be read
     without knowing the time. ]]--
GLOBAL_when = time({ year = 2024, month = 6, day = 1, hour = 14, min = 36, sec = 5 })
GLOBAL_morning = time({ year = 2024, month = 6, day = 1, hour = 9, min = 5, sec = 3 })

eq(table.getn(OB.timeShapes), 4, "four shapes are offered")

cfg.hour12 = false
cfg.meridiem = false
cfg.timeShape = 3

eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_when), "14:36", "24-hour padded")
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_morning), "09:05", "pads before ten")

cfg.timeShape = 4
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_when), "14:36:05", "and with seconds")

--[[ **Unpadded means every field, not just the hour**: `h:m` at five past nine
     is "9:5", which is what the notation says and what somebody choosing it
     asked for. 1.12's strftime has no unpadded specifier -- no `%-I`, no
     `%-M` -- so it is a padded clock with the zeroes taken off. ]]--
cfg.timeShape = 1
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_morning), "9:5", "unpadded is every field")
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_when), "14:36", "with nothing to take off")

cfg.timeShape = 2
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_morning), "9:5:3", "seconds included")

--[[ Twelve-hour with and without the meridiem. ]]--
cfg.hour12 = true
cfg.meridiem = true
cfg.timeShape = 3

eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_when), "02:36 PM", "12-hour says which half")

cfg.meridiem = false
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_when), "02:36", "and can leave it off")

--[[ **The meridiem is ignored on a twenty-four hour clock**, because "14:36 PM"
     is not a time. The row is greyed rather than dropped: it is still your
     answer, it just has nothing to attach to. ]]--
cfg.hour12 = false
cfg.meridiem = true
eq(OB.FormatTime(chat:TimeSpec(), GLOBAL_when), "14:36",
        "a 24-hour clock ignores it rather than printing nonsense")

cfg.hour12 = false
cfg.meridiem = true
cfg.timeShape = 3

--[[ **The unpadded hour only loses a leading zero.**

     "09:05" becomes "9:05" and "10:05" is left alone -- a blunter substitution
     would turn "10:05" into "1:5", which is not a time. ]]--
eq(OB.FormatTime({ "%H:%M", strip = true }, GLOBAL_morning), "9:05",
        "the hour unpads and the minute does not")
eq(OB.FormatTime({ "%H:%M", strip = true }, GLOBAL_when), "14:36",
        "an hour with no leading zero is left alone")
eq(OB.FormatTime({ "%H:%M:%S", strip = true, stripAll = true }, GLOBAL_when), "14:36:5",
        "stripAll reaches the later fields too")

--[[ The three answers driven through the module, which is the path the panel
     actually uses.

     **Asserted on the property, not on a shape**, because `Stamp` reads the live
     clock: "an unpadded format has no leading zero" is true at every hour, while
     `^%d:%d%d` is true only between one and ten and a test written that way duly
     passed for three releases and failed at ten past ten at night. ]]--
cfg.hour12 = true
cfg.meridiem = true
cfg.timeShape = 1

GLOBAL_stamp = chat:Stamp(1)

check(string.find(GLOBAL_stamp, "^%d%d?:%d+ %u%u"),
        "twelve-hour with a meridiem", "got '" .. GLOBAL_stamp .. "'")
check(not string.find(GLOBAL_stamp, "^0"),
        "and no leading zero on the hour", "got '" .. GLOBAL_stamp .. "'")

cfg.timeShape = 4
cfg.hour12 = false
cfg.meridiem = false

check(string.find(chat:Stamp(1), "^%d%d:%d%d:%d%d"),
        "and a padded one with seconds", "got '" .. chat:Stamp(1) .. "'")

cfg.timeShape = 3

--[[ **Server time has no seconds**, so they are recovered by watching the minute
     roll over and measuring the offset from the local clock at that instant.
     Prat's trick, from FuBar_ClockFu, carried across intact -- getting it subtly
     wrong shows up as a clock that jumps, which is worse than one that is
     plainly wrong. ]]--
cfg.timeSource = 2
Stub.gameTime = { hour = 9, minute = 5 }

local server = chat:Stamp(1)
check(string.find(server, "^09:05"), "server time reads the game clock",
        "got '" .. server .. "'")

Stub.gameTime = { hour = 9, minute = 6 }
check(string.find(chat:Stamp(1), "^09:06"), "and follows it over a minute roll")

cfg.timeSource = 1

--[[ **The hook is installed once and never removed.**

     1.12 has no hooksecurefunc, so hooking is replacing a method -- which makes
     unhooking the hazard: another addon may have hooked the same method after
     us, and restoring our saved original silently deletes theirs. Prat unhooked
     whenever a window's toggle went off, which is exactly that. ]]--
check(chat.hooked ~= nil, "the frames are hooked on bind")

local frame = Stub.chatFrames[1]
frame.lines = {}
frame:AddMessage("hello")

eq(table.getn(frame.lines), 1, "a message still reaches the frame")
check(string.find(frame.lines[1], "hello", 1, true), "with its text intact")
check(string.find(frame.lines[1], "%d%d:%d%d"), "and a timestamp in front of it")

--[[ Switching the window off empties the prefix rather than removing the hook,
     which costs a table lookup per message and cannot break a neighbour. ]]--
cfg.stamp[1] = false
frame.lines = {}
frame:AddMessage("plain")
eq(frame.lines[1], "plain", "an unstamped window passes the text through untouched")
cfg.stamp[1] = true

--[[ And switching the *module* off does the same, because the hook outlives the
     binding by design and has to cope with being unbound. ]]--
OB.profile.modulesEnabled.chat = false
OB.BindSlots()

frame.lines = {}
frame:AddMessage("disabled")
eq(frame.lines[1], "disabled", "a disabled module leaves messages alone")

--[[ **Window appearance: size, justification and fading.**

     Prat's Justify, Fading and FontSize were three modules doing one thing each
     to the same seven frames. One section here, and one apply pass. ]]--
OB.profile.modulesEnabled.chat = true
OB.BindSlots()

local was = frame.fontSize
eq(cfg.restyle, false, "the windows are left alone by default")

cfg.restyle = true
cfg.fontSize = 16
cfg.justify = 3
cfg.fadeAfter = 25
chat:OnStyle()

eq(frame.fontSize, 16, "restyling sets the font size")
eq(frame.justify, "RIGHT", "and the justification")
eq(frame.fadeDuration, 25, "and how long before a window fades")


--[[ **The chat windows get their own font.**

     Chat is the one place a different face genuinely earns its keep: these
     windows are read as prose rather than glanced at as numbers, and the
     client's Friz Quadrata is a headline face doing a body job.

     It kept the client's face and changed only the size, which made "restyle"
     mean "resize". ]]--
cfg.restyle = true
cfg.font = OB.fontIndex["Roboto"]
cfg.fontSize = 14
chat:OnStyle()

eq(frame.font, OB.fontPaths[OB.fontIndex["Roboto"]],
        "restyling sets the font that was chosen", tostring(frame.font))

cfg.font = OB.fontIndex["Friz Quadrata"]
chat:OnStyle()
eq(frame.font, OB.fontPaths[OB.fontIndex["Friz Quadrata"]],
        "and follows the row when it changes")

--[[ **It goes through `OB.Look`**, so a chat with no font of its own takes the
     profile's -- share unless you say otherwise, the same rule as everywhere
     else in the addon. ]]--
cfg.font = nil
OB.profile.font = OB.fontIndex["Expressway"]
chat:OnStyle()

eq(frame.font, OB.fontPaths[OB.fontIndex["Expressway"]],
        "and inherits the shared font when it has none of its own")

OB.profile.font = OB.fontIndex["Roboto"]
cfg.font = OB.fontIndex["Roboto"]

-- ---------------------------------------------------------------------------
-- the box you type into
-- ---------------------------------------------------------------------------

--[[ **The client's edit box is three pieces of 2004 gold filigree**, and it is
     the one part of the chat window that sits on top of the game rather than
     beside it -- while everything else this addon draws is a flat panel with a
     border it chose. ]]--
eq(cfg.editBorder, true, "the client's border is off by default")

chat:ApplyEditBox()

check(not getglobal("ChatFrameEditBoxLeft"):IsShown(), "so its three pieces go")
check(not getglobal("ChatFrameEditBoxMid"):IsShown(), "all of them")
check(not getglobal("ChatFrameEditBoxRight"):IsShown(), "including the right")

cfg.editBorder = false
chat:ApplyEditBox()
check(getglobal("ChatFrameEditBoxLeft"):IsShown(), "and come back when asked for")

cfg.editBorder = true
chat:ApplyEditBox()

--[[ **No colour setting and no frame behind it**, after four attempts. The last
     drew a flat `WHITE8X8` tinted to the chosen colour, which is the right way
     to draw a flat colour, and it still broke chat in the game -- whatever a
     frame behind an EditBox costs on this client, it is more than a colour is
     worth. See constraints 98 and 99. ]]--
check(OB.modules.chat.defaults.editColor == nil, "there is no colour setting")
check(chat.EditBackdrop == nil, "and no function that would draw one")
check(ChatFrameEditBox.eqBack == nil, "nor anything of ours behind the box")

--[[ **There is no anchor dropdown any more.**

     It answered a question nobody had: the client's own place is under the chat
     frame, and somebody who wants it elsewhere wants it *exactly* elsewhere,
     which is what dragging is for. Untouched, the box stays wherever the client
     and any other addon left it -- the same rule the rest of this module
     follows. ]]--
check(OB.modules.chat.defaults.editAnchor == nil, "the anchor setting is gone")

cfg.editLocked = true
cfg.editPos = {}
check(not chat:PlaceEditBox(), "and an undragged box is left where it was")

--[[ **Moved anywhere, and still the width it was.**

     The client anchors this box by two corners, and two corners are where its
     width comes from -- so clearing the points to move it leaves a box with no
     width at all, which is a box you cannot see. That was "anchoring is not
     moving": it moved, to a place zero pixels wide. ]]--
ChatFrameEditBox:ClearAllPoints()
ChatFrameEditBox:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", 0, -6)
ChatFrameEditBox:SetPoint("TOPRIGHT", ChatFrame1, "BOTTOMRIGHT", 0, -6)
ChatFrameEditBox:SetWidth(420)

cfg.editLocked = false
cfg.editPos = { x = 120, y = -260 }

check(chat:PlaceEditBox(), "a dragged box is put where it was dropped")
eq(ChatFrameEditBox:GetWidth(), 420, "and keeps the width it had")

--[[ Measured from the centre of the screen, the rule the meters, the bars, the
     frames and the popup all follow: a position measured from an edge is a
     different place on a different resolution. ]]--
chat:LockEditBox()
check(ChatFrameEditBox:GetScript("OnDragStart"),
        "an unlocked box can be picked up")

ChatFrameEditBox:ClearAllPoints()
ChatFrameEditBox:SetPoint("CENTER", UIParent, "CENTER", -300, 90)
chat:StoreEditBox()

eq(chat:Config().editPos.x, -300, "and where it was dropped is what is kept")
eq(chat:Config().editPos.y, 90, "on both axes")

cfg.editLocked = true
chat:LockEditBox()
check(not ChatFrameEditBox:GetScript("OnDragStart"),
        "while a locked one cannot be picked up at all")

--[[ Reset puts the client's anchors back, and the width with them: an explicit
     width left over from being moved would fight the two corners. ]]--
chat:ResetEditBox()
eq(chat:Config().editPos.x, nil, "reset forgets where it was dropped")
check(not chat:PlaceEditBox(), "so nothing moves it any more")

cfg.editPos = {}


cfg.editBorder = true
chat:ApplyEditBox()

--[[ **The client puts its own art back, which is why hiding it once was not
     enough.**

     It shows and hides both texture sets itself as focus comes and goes, so a
     `Hide` on the settings pass lasted until the next time you pressed Enter --
     the only moment any of it is on screen. That is why it came back looking
     broken in a different way each time. ]]--
cfg.editBorder = true
chat:ApplyEditBox()

GLOBAL_art = getglobal("ChatFrameEditBoxLeft")
check(not GLOBAL_art:IsShown(), "the art is hidden")
eq(GLOBAL_art.texture, nil, "and taken off, because hiding alone did not hold")

--[[ **The path is remembered before anything is taken off**, which is what
     makes clearing acceptable: it was refused before precisely because the path
     is the client's and this addon never knew it. ]]--
check(GLOBAL_art.eqPath ~= nil, "with the path kept so it can go back")

cfg.editBorder = false
chat:ApplyEditBox()
check(GLOBAL_art:IsShown(), "and it does go back")
check(GLOBAL_art.texture ~= nil, "with its texture on it")

--[[ Put back by the client, then taken off again the moment the box opens --
     which is the pass that makes it stick. ]]--
cfg.editBorder = true
chat:ApplyEditBox()
GLOBAL_art:Show()

ChatFrameEditBox:GetScript("OnShow")()
check(not GLOBAL_art:IsShown(), "showing the box takes it off again")

GLOBAL_art:Show()
ChatFrameEditBox:GetScript("OnEditFocusGained")()
check(not GLOBAL_art:IsShown(), "and so does taking focus, which is the later of the two")
cfg.editBorder = true
chat:ApplyEditBox()

-- ---------------------------------------------------------------------------
-- what you said last
-- ---------------------------------------------------------------------------

--[[ **1.12 has none of this**: the edit box opens empty every time, so
     correcting a typo in a long whisper means typing the whole thing again. ]]--
chat.history = nil
chat.historyAt = nil

chat:Remember("first thing")
chat:Remember("second thing")
chat:Remember("third thing")

eq(chat:HistoryStep(true), "third thing", "Up gives the newest line")
eq(chat:HistoryStep(true), "second thing", "and again the one before it")
eq(chat:HistoryStep(true), "first thing", "and the one before that")

--[[ **It stops at the oldest rather than wrapping**, because wrapping from the
     oldest to the newest is a keypress that looks like a bug. ]]--
eq(chat:HistoryStep(true), "first thing", "and stops at the oldest")

eq(chat:HistoryStep(false), "second thing", "Down comes back")
eq(chat:HistoryStep(false), "third thing", "line by line")

--[[ The empty box below the newest is a real position: it is what you had
     before you started paging. ]]--
eq(chat:HistoryStep(false), "", "and past the newest is the empty box")
eq(chat:HistoryStep(false), "", "which is where it stops")

--[[ The same line twice running is one line: sending "bump" four times is not
     four things to page through. ]]--
chat:Remember("bump")
check(not chat:Remember("bump"), "the same line twice running is one line")

--[[ **Sending puts the cursor back at the end**, so the next Up is the newest
     line rather than wherever you had paged to. ]]--
chat:HistoryStep(true)
chat:HistoryStep(true)
chat:Remember("something new")
eq(chat:HistoryStep(true), "something new", "sending starts the paging over")

--[[ **And so does closing the box.** Somebody who closed chat and came back is
     starting a new thought, not continuing to page through an old one. ]]--
chat:HistoryStep(true)
chat:HistoryStep(true)
chat:ResetHistory()
eq(chat:HistoryStep(true), "something new", "and so does closing the box")

--[[ Nothing said, nothing to page through -- and no error for asking. ]]--
chat.history = nil
chat.historyAt = nil
eq(chat:HistoryStep(true), nil, "an empty history answers nothing at all")
--[[ **Unlocked is a state rather than a mode**, unlike the bars and the popup:
     the box is only on screen while you are typing into it, so a draggable one
     is never in the way of something else. ]]--
cfg.editLocked = false
chat:LockEditBox()
check(ChatFrameEditBox:IsMovable(), "unlocking makes it draggable")

ChatFrameEditBox:ClearAllPoints()
ChatFrameEditBox:SetPoint("CENTER", UIParent, "CENTER", -220, 40)
ChatFrameEditBox:SetWidth(300)
ChatFrameEditBox:SetHeight(20)
chat:StoreEditBox()

eq(cfg.editPos.x, -220, "and where it lands is remembered")
eq(cfg.editPos.y, 40, "on both axes")

--[[ A dragged box keeps where it was put: the anchor row answers "where should
     it start", and somebody who has moved it has answered that already. ]]--
cfg.editLocked = true
chat:PlaceEditBox()
GLOBAL_p, GLOBAL_rel, GLOBAL_rp, GLOBAL_x = ChatFrameEditBox:GetPoint()
eq(GLOBAL_x, -220, "which the anchor rows do not overrule")

chat:ResetEditBox()
GLOBAL_p, GLOBAL_rel, GLOBAL_rp = ChatFrameEditBox:GetPoint()
eq(GLOBAL_rp, "BOTTOMLEFT", "until it is put back")

chat:LockEditBox()
check(not ChatFrameEditBox:IsMovable(), "and locking stops it moving again")

-- ---------------------------------------------------------------------------
-- the window, scaled
-- ---------------------------------------------------------------------------

--[[ **Font size changes the letters and leaves the frame the size it was.**
     This changes both, which is what somebody asking for a smaller chat window
     means. ]]--
cfg.restyle = true
cfg.scale = 0.8
chat:OnStyle()
eq(frame.scale, 0.8, "the window takes the scale")

cfg.scale = 1.4
chat:OnStyle()
eq(frame.scale, 1.4, "and follows the slider")

--[[ Remembered on the first pass like the font, so switching the section off
     puts back what was there rather than a number this addon invented. ]]--
cfg.restyle = false
chat:OnStyle()
eq(frame.scale, 1, "and switching it off restores what the client had")

cfg.restyle = true
cfg.scale = 1
--[[ **One switch for all seven.** It was one per window because Prat had one
     per window, and nobody has ever wanted the first to fade and the third not
     to -- seven rows for a decision made once. ]]--
cfg.fade = false
chat:OnStyle()
check(not frame.fading, "fading can be switched off")

cfg.fade = true
chat:OnStyle()
check(frame.fading, "and on again")

--[[ **Switching it off restores what was there**, rather than a hardcoded
     default. Prat put back 12pt and LEFT on disable, which is not "off" -- it is
     "off, and also I have changed your font". ]]--
cfg.restyle = false
chat:OnStyle()
eq(frame.fontSize, was, "switching it off puts the original size back")

--[[ **Raid warnings as a group of their own.** The client lumps them in with
     plain raid, so a window showing raid cannot avoid showing warnings. ]]--
eq(cfg.separate, false, "the channel groups are untouched by default")

local originalRaid = ChatTypeGroup.RAID

cfg.separate = true
chat:OnStyle()
check(table.getn(ChatTypeGroup.RAID) > 1, "separating splits the raid group")
check(ChatTypeGroup.OFFICER ~= nil, "and gives officer one of its own")

--[[ **The settings menu is extended, never replaced**, and this is the bug that
     was reported as "leave World, join Raid and Officer, reload, undone".

     The client builds the chat settings checkboxes from
     `ChannelMenuChatTypeGroups` *and* walks it when saving which groups a window
     shows. This used to assign a hardcoded list of the eight obvious groups --
     so loot, system messages, creature emotes and everything else stopped being
     selectable and stopped being saved.

     Raid and Officer are two of the five groups the separator touches, which is
     what made it look like those two specifically. ]]--
cfg.separate = true
chat:OnStyle()

check(table.getn(ChannelMenuChatTypeGroups) >= 12,
        "the client's own list of selectable groups is kept whole",
        "entries: " .. table.getn(ChannelMenuChatTypeGroups))

local keptLoot = false
for i = 1, table.getn(ChannelMenuChatTypeGroups) do
    if ChannelMenuChatTypeGroups[i] == "LOOT" then keptLoot = true end
end

check(keptLoot, "including the ones this module has no opinion about")

cfg.separate = false
chat:OnStyle()
eq(ChatTypeGroup.RAID, originalRaid, "and switching it off restores the client's")

--[[ **Short channel names**, from Prat's ChannelNames. `[Guild]` becomes `[G]`,
     which on a busy screen is the difference between reading the message and
     reading the label.

     No hook: the client builds every line from a format string, so renaming a
     channel is rewriting the string rather than catching the message after it
     has already been formatted. ]]--
local originalGuild = CHAT_GUILD_GET

eq(cfg.shorten, false, "channel names are the client's by default")
eq(CHAT_GUILD_GET, originalGuild, "so the format string is untouched")

cfg.shorten = true
chat:OnStyle()

check(string.find(CHAT_GUILD_GET, "%[G%]"), "shortening renames the guild channel",
        "got '" .. CHAT_GUILD_GET .. "'")

--[[ **The speaker survives.** `%s` is what the client substitutes the name
     into, and a replacement that dropped it would lose whoever was talking --
     which is worse than a long channel name. ]]--
check(string.find(CHAT_GUILD_GET, "%%s", 1, false), "and keeps the speaker")
check(string.find(CHAT_GUILD_GET, ":", 1, true), "with a colon after it")

cfg.colon = false
chat:OnStyle()
check(not string.find(CHAT_GUILD_GET, ":", 1, true), "which can be switched off")
cfg.colon = true

--[[ Each name is yours: the defaults are the abbreviations people already use,
     so the common case is one switch rather than ten fields. ]]--
cfg.shortGuild = "gld"
chat:OnStyle()
check(string.find(CHAT_GUILD_GET, "%[gld%]"), "and each one can be renamed")

cfg.shorten = false
chat:OnStyle()
eq(CHAT_GUILD_GET, originalGuild, "switching it off restores the client's string")

-- ---------------------------------------------------------------------------
-- one question about wrapping, asked once
-- ---------------------------------------------------------------------------

--[[ **Square, angled or bare, for all four of them.**

     Player names, links, channel labels and timestamps all get wrapped in
     something, and four different answers to "how is a thing wrapped" would be
     four things to learn. They share the list, so `[Guild]` and `[Bobby]` cannot
     drift apart. ]]--
eq(cfg.channelBrackets, 1, "channels are square, which is what they always were")
eq(cfg.stampBrackets, 3, "and timestamps are bare, which is what they always were")

cfg.shorten = true
cfg.colon = true
cfg.shortGuild = "Guild"

chat:OnStyle()
check(string.find(CHAT_GUILD_GET, "[Guild]", 1, true),
        "square wraps the channel name", CHAT_GUILD_GET)

cfg.channelBrackets = 2
chat:OnStyle()
check(string.find(CHAT_GUILD_GET, "<Guild>", 1, true),
        "angled wraps it the other way", CHAT_GUILD_GET)

cfg.channelBrackets = 3
chat:OnStyle()
check(string.find(CHAT_GUILD_GET, "Guild %s:", 1, true),
        "and None leaves it bare", CHAT_GUILD_GET)

--[[ `%s` is the speaker, substituted by the client. It has to survive every one
     of the three or the line loses whoever said it. ]]--
check(string.find(CHAT_GUILD_GET, "%%s"),
        "with the speaker still in it", CHAT_GUILD_GET)

cfg.channelBrackets = 1

--[[ The timestamp takes the same three, and the brackets are wrapped before the
     colour so they are part of the stamp rather than part of the line. ]]--
GLOBAL_wasStamp, GLOBAL_wasColor = cfg.stamp[1], cfg.colorStamp
cfg.stamp[1] = true
cfg.colorStamp = false
cfg.stampBrackets = 1

check(string.find(chat:Stamp(1), "^%["), "square wraps the timestamp",
        chat:Stamp(1))

cfg.stampBrackets = 2
check(string.find(chat:Stamp(1), "^<"), "angled wraps it the other way",
        chat:Stamp(1))

cfg.stampBrackets = 3
check(string.find(chat:Stamp(1), "^%d"), "and None leaves it bare",
        chat:Stamp(1))

cfg.stampBrackets = 1
cfg.colorStamp = true

check(string.find(chat:Stamp(1), "|cff%x%x%x%x%x%x%["),
        "with the brackets inside the colour, not outside it", chat:Stamp(1))

cfg.stampBrackets = 3
cfg.stamp[1], cfg.colorStamp = GLOBAL_wasStamp, GLOBAL_wasColor
cfg.shorten = false
chat:OnStyle()

--[[ **Numbered channels are the noisy half**: `[1. General]` is wider than most
     of the messages in it. They cannot be renamed by a format string -- the
     client builds them from the channel list at runtime -- so this is the one
     part that has to catch a message already assembled. ]]--
cfg.stamp[1] = false
eq(cfg.shortenNumbered, false, "numbered channels are left alone by default")
eq(chat:Decorate(1, "[1. General] Bob: hi"), "[1. General] Bob: hi",
        "so a line passes through untouched")

cfg.shortenNumbered = true

--[[ **The name, always.** This was a three-way choice between the number, the
     name and its first letter. The number is what the client already shows and
     the reason anybody wants this changed; a single letter is ambiguous the
     moment you are in two channels starting with the same one. ]]--
eq(chat:Decorate(1, "[1. General] Bob: hi"), "[General] Bob: hi",
        "the list position and the zone go, the name stays")
eq(chat:Decorate(1, "[2. Trade - Stormwind] Bob: hi"), "[Trade - Stormwind] Bob: hi",
        "and a channel with a zone in its name keeps it")

--[[ **The pattern is narrow on purpose.** Prat matched loosely and anchored on
     a player link, which catches lines that carry a link and no channel. A
     bracket holding "number dot text" is specific enough that a false positive
     would have to be somebody typing one. ]]--
eq(chat:Decorate(1, "Bob hits you for 12. Ouch"), "Bob hits you for 12. Ouch",
        "a sentence with a number and a dot is not a channel")
eq(chat:Decorate(1, "[Guild] Bob: hi"), "[Guild] Bob: hi",
        "and a named channel is left to the format string")

cfg.shortenNumbered = false
cfg.stamp[1] = true

--[[ **Scrollback.** Prat's Scroll and History, which were two modules and one
     subject: how far back you can read, and how fast the wheel gets you there.

     The only thing in this file that ships on. 1.12's chat frames are not
     wheel-scrollable at all, so this is the one behaviour where off is the
     surprising state rather than the polite one. ]]--
eq(cfg.wheel, true, "the wheel scrolls the chat windows by default")
eq(Stub.chatFrames[1]:IsMouseWheelEnabled(), true, "so the frame takes the event")

Stub.chatFrames[1].scrollOffset = 0
Stub.Wheel(1, 1)
eq(Stub.chatFrames[1].scrollOffset, 1, "one notch is one line")

Stub.Wheel(1, -1)
eq(Stub.chatFrames[1].scrollOffset, 0, "and back down again")

--[[ Down from the bottom does nothing, which is the frame's rule rather than
     the module's -- worth asserting so a future speed change cannot drive the
     offset negative and take the window somewhere it cannot come back from. ]]--
Stub.Wheel(1, -1)
eq(Stub.chatFrames[1].scrollOffset, 0, "and stops at the bottom")

cfg.wheelLines = 4
Stub.Wheel(1, 1)
eq(Stub.chatFrames[1].scrollOffset, 4, "the speed setting is the number of lines")
cfg.wheelLines = 1

--[[ Ctrl is the coarse version. A separate number rather than a multiplier, so
     "one line normally, ten with Ctrl" is expressible. ]]--
Stub.chatFrames[1].scrollOffset = 0
Stub.Wheel(1, 1, "CTRL")
eq(Stub.chatFrames[1].scrollOffset, cfg.wheelFast, "Ctrl uses its own number")

--[[ **Shift jumps rather than hurries**, which is Prat's decision and the right
     one: "back a little" and "back to now" are the two things wanted from a chat
     log, and a modifier that only changed the speed would waste the second. ]]--
Stub.Wheel(1, -1, "SHIFT")
eq(Stub.chatFrames[1].scrollOffset, 0, "Shift down goes straight to the bottom")

Stub.Wheel(1, 1, "SHIFT")
check(Stub.chatFrames[1].scrollOffset > 100, "and Shift up to the top",
        "offset: " .. Stub.chatFrames[1].scrollOffset)
Stub.chatFrames[1]:ScrollToBottom()

--[[ Off means out of the way, not absent. The handler stays -- a script is one
     slot per frame, so clearing ours clears whatever a neighbour put there
     afterwards, which is what Prat's disable path did. ]]--
cfg.wheel = false
Stub.Wheel(1, 1)
eq(Stub.chatFrames[1].scrollOffset, 0, "switched off, the wheel moves nothing")
eq(Stub.chatFrames[1]:GetScript("OnMouseWheel") ~= nil, true,
        "but the handler stays, so a neighbour's is not cleared with it")
cfg.wheel = true

--[[ **Lines kept, applied for real at login.**

     Prat's History compared the new value against the stored one and returned
     early when they matched -- and the login path passed exactly the stored
     value, so the number was saved to the profile and never reached a frame
     until you changed it by hand. The assertion is that the frame agrees with
     the setting without anybody touching a slider. ]]--
eq(Stub.chatFrames[1]:GetMaxLines(), cfg.scrollback,
        "the frame keeps as many lines as the setting says")

cfg.scrollback = 400
chat:OnStyle()
eq(Stub.chatFrames[1]:GetMaxLines(), 400, "and follows it when it changes")
eq(Stub.chatFrames[7]:GetMaxLines(), 400, "in every window, not just the first")

--[[ **And it is not written when it has not changed**, which is the bug that
     was reported as "chat resets every time a setting is changed".

     `SetMaxLines` empties the frame -- the client's behaviour, not a bug in it:
     a new buffer does not carry the old one's contents. The style pass runs on
     every settings change, so writing unconditionally wiped somebody's chat
     every time they touched any slider on any page.

     Prat's History had a guard against exactly this and it was removed here as a
     saved call that cost nothing. The guard was right. What was wrong was what
     it compared against -- its own stored copy, which the login path handed back
     unchanged, so it never applied at all. Asking the frame fixes both halves
     with one comparison. ]]--
Stub.chatFrames[1].lines = { "a line somebody wants to keep" }

chat:OnStyle()
eq(table.getn(Stub.chatFrames[1].lines), 1,
        "a style pass that changes nothing leaves the history alone")

--[[ And a real change still goes through, buffer wipe and all -- that part is
     the client's and there is nothing to be done about it. ]]--
cfg.scrollback = 250
chat:OnStyle()
eq(Stub.chatFrames[1]:GetMaxLines(), 250, "a real change is still applied")
cfg.scrollback = 128
chat:OnStyle()

chat.announced = nil

--[[ **A channel you took out of a window, put back by the client, every login.**

     Different from the never-join list and reported separately. That one is
     about being *in* a channel at all; this is about which window it shows in.
     You want World -- you want it in the window you put it in.

     The client's join handler adds a channel to a window whenever you join it,
     and there is nowhere it remembers that you took it out again. So a server
     that force-joins World re-adds it on every reload, forever. ]]--
EquadisClassicOverhaulDB.chatRemovals = { [OB.CharacterKey()] = {} }
OB.chatRemovals = EquadisClassicOverhaulDB.chatRemovals[OB.CharacterKey()]

local window = Stub.chatFrames[2]
window.channelList = {}

chat.chatReady = nil
chat.channelMemoryInstalled = nil
chat:InstallChannelMemory()

--[[ **Nothing is recorded before the world is in.** During login the client adds
     and removes channels itself while restoring each window, and filing those as
     decisions would record the client's own bookkeeping as the player's. ]]--
ChatFrame_AddChannel(window, "World")
ChatFrame_RemoveChannel(window, "World")
eq(chat:WasRemoved(2, "World"), false,
        "a removal during the client's own setup is not a decision")

chat.chatReady = true

--[[ From here a removal is somebody deciding something, and it is remembered.
     **Not a setting**: nobody should have to type a list to undo what they just
     did with the interface. The removal is the statement. ]]--
ChatFrame_AddChannel(window, "World")
eq(table.getn(window.channelList), 1, "the channel is in the window")

ChatFrame_RemoveChannel(window, "World")
eq(chat:WasRemoved(2, "World"), true, "taking it out is remembered")
eq(table.getn(window.channelList), 0, "and it is out")

--[[ **The fix.** The client adds it again on the next join; that add is the
     client repeating itself rather than anybody asking, and it is refused. ]]--
ChatFrame_AddChannel(window, "World")
eq(table.getn(window.channelList), 0, "and it stays out when the client re-adds it")

--[[ Per window, not per channel. World kept out of window two says nothing about
     window one, which is where the player actually reads it. ]]--
local mainWindow = Stub.chatFrames[1]
mainWindow.channelList = {}

ChatFrame_AddChannel(mainWindow, "World")
eq(table.getn(mainWindow.channelList), 1,
        "the window they do want it in is untouched")

--[[ Matched on the base name, like the never-join list: "1. World" and "World"
     are the same channel under two spellings, and the client uses both. ]]--
ChatFrame_AddChannel(window, "2. World")
eq(table.getn(window.channelList), 0, "the numbered spelling is the same channel")

--[[ Adding it back is somebody changing their mind, which has to clear the
     record -- or the change of mind lasts until the next login and no further. ]]--
chat:ForgetRemoval(2, "World")
ChatFrame_AddChannel(window, "World")
eq(table.getn(window.channelList), 1, "putting it back works")
eq(chat:WasRemoved(2, "World"), false, "and is remembered as the new answer")

--[[ **The sweep, for the adds that happened before the gate opened.** The hook
     cannot refuse what it was not yet allowed to judge, so once the world is in
     every window is checked against what was taken out of it. ]]--
chat:RememberRemoval(2, "World")
window.channelList = { "World", "Trade" }

eq(chat:ApplyChannelMemory(), 1, "the sweep takes back out what came back")
eq(table.getn(window.channelList), 1, "leaving the rest alone")
eq(window.channelList[1], "Trade", "and the right one behind")

OB.chatRemovals = {}
chat.chatReady = nil
window.channelList = {}
mainWindow.channelList = {}

-- ---------------------------------------------------------------------------
-- typing, furniture, links and colours
-- ---------------------------------------------------------------------------

--[[ **Reopening in the channel you last used is not a setting any more.**

     It was two: sticky, and "the dangerous ones too". Neither is a decision
     anybody makes twice -- it is what every chat client does and what everybody
     expects -- and leaving yell out meant the one time you used it the box went
     quietly back to say without telling you. ]]--
chat:OnStyle()

eq(ChatTypeInfo["SAY"].sticky, 1, "the edit box remembers where you were talking")
eq(ChatTypeInfo["WHISPER"].sticky, 1, "on the ordinary channels")
eq(ChatTypeInfo["YELL"].sticky, 1, "and on the loud ones too")
eq(ChatTypeInfo["RAID_WARNING"].sticky, 1, "including a raid warning")
eq(ChatTypeInfo["EMOTE"].sticky, 1, "and an emote")

check(OB.modules.chat.defaults.sticky == nil, "and there is no switch for it")

--[[ **The chat frame's furniture.** The scroll arrows and the menu button take
     up the corner of every window and do nothing the mouse wheel and a
     right-click do not. ]]--
eq(cfg.hideButtons, false, "the client's buttons are left alone by default")

chat:ApplyButtons()
eq(getglobal("ChatFrame1UpButton").shown, true, "so they are shown")

cfg.hideButtons = true
cfg.hideMenuButton = true
chat:ApplyButtons()

eq(getglobal("ChatFrame1UpButton").shown, false, "hiding them hides them")
eq(getglobal("ChatFrame3BottomButton").shown, false, "on every window")
eq(ChatFrameMenuButton.shown, false, "and the menu button with them")

cfg.hideButtons = false
cfg.hideMenuButton = false
chat:ApplyButtons()
eq(getglobal("ChatFrame1UpButton").shown, true, "and they come back")

--[[ **Links.** 1.12 cannot open a browser and never will, so "clickable" means
     a box with the text already selected. That is the whole feature, and the
     alternative is reading a URL off the screen and typing it by hand. ]]--
cfg.stamp[1] = false

local linked = chat:Decorate(1, "have a look at http://turtle-wow.org/rules")
check(string.find(linked, "|Heqourl:", 1, true) ~= nil,
        "a URL becomes a link", linked)
check(string.find(linked, "%[http://turtle%-wow%.org/rules%]") ~= nil,
        "in brackets", linked)

--[[ Three shapes, not one clever pattern: a scheme with `://`, and `www.`
     without one. A single expression that caught both caught a great deal
     else. ]]--
local bare = chat:Decorate(1, "www.wowhead.com/item=12345 is the one")
check(string.find(bare, "|Heqourl:www.wowhead.com", 1, true) ~= nil,
        "and so does a bare www address", bare)

eq(chat:Decorate(1, "no links here at all"), "no links here at all",
        "a line with no URL in it is untouched")

cfg.urlCopy = false
eq(chat:Decorate(1, "http://turtle-wow.org"), "http://turtle-wow.org",
        "and nothing happens with it switched off")
cfg.urlCopy = true

--[[ **Three ways to wrap a link, from the same list the player names use.**

     It was a checkbox, so it could say square or nothing and angled was not on
     offer -- a boolean cannot offer three things. "How is a thing wrapped" is
     one question, and answering it two ways on one page is two things to
     learn. ]]--
eq(cfg.urlBrackets, 1, "square is the default wrapping")

cfg.urlBrackets = 2
check(string.find(chat:Decorate(1, "see www.wowhead.com now"), "<www", 1, true),
        "angled is offered too", chat:Decorate(1, "see www.wowhead.com now"))

cfg.urlBrackets = 3
GLOBAL_bare = chat:Decorate(1, "see www.wowhead.com now")
check(not string.find(GLOBAL_bare, "[www", 1, true), "and none leaves it bare")
check(not string.find(GLOBAL_bare, "<www", 1, true), "on both counts")

cfg.urlBrackets = 1

cfg.stamp[1] = true

--[[ **Channel colours, keyed by name rather than by number.**

     1.12 stores them by number and the numbers move: leave one channel and
     every channel below it shifts up, taking your colours with it. The green
     you set on your guild channel is now on Trade. ]]--
EquadisClassicOverhaulDB.channelColors = {}
OB.channelColors = EquadisClassicOverhaulDB.channelColors

Stub.channels = { "General", "Trade", "GuildRecruitment" }
Stub.chatColors = {}

chat:RememberColor("Trade", 0.1, 0.9, 0.2)
check(OB.channelColors["trade"] ~= nil, "a colour is remembered by name")

--[[ **The channel moves and the colour follows it**, which is the entire point.
     Trade was number two; somebody leaves General and it becomes number one. ]]--
Stub.channels = { "Trade", "GuildRecruitment" }

eq(chat:ApplyRememberedColor("Trade"), true, "it is put back")
check(Stub.chatColors["CHANNEL1"] ~= nil,
        "under the number the channel has now, not the one it had")
eq(Stub.chatColors["CHANNEL1"][2], 0.9, "with the colour that was saved")

cfg.rememberColors = false
Stub.chatColors = {}
eq(chat:ApplyRememberedColor("Trade"), false, "and nothing is put back when off")
cfg.rememberColors = true

--[[ **`/tt`** -- whisper whoever you are looking at. Eleven lines, and one of
     the most-used things Prat ships. ]]--
Stub.chatSent = nil
Stub.player.hasTarget = false

eq(chat:TellTarget("hello"), false, "with no target there is nobody to whisper")
eq(Stub.chatSent, nil, "and nothing is sent")

Stub.player.hasTarget = true
Stub.target = { name = "Sylvie", isPlayer = true }

eq(chat:TellTarget("hello"), true, "with one, the whisper goes")
eq(Stub.chatSent.kind, "WHISPER", "as a whisper")
eq(Stub.chatSent.target, "Sylvie", "to them")
eq(Stub.chatSent.message, "hello", "with what was typed")

--[[ Nothing typed opens the box addressed to them rather than sending nothing:
     `/tt` on its own is somebody about to type. ]]--
Stub.chatSent = nil
eq(chat:TellTarget(""), true, "an empty /tt still does something")
eq(Stub.chatSent, nil, "but does not send an empty whisper")

Stub.target = nil
Stub.player.hasTarget = false

--[[ **Player names**, the feature people install a chat addon for: the sender of
     a line coloured by class, so a wall of text becomes a list of people.

     What it reads from is the roster -- what the addon knows about other
     players -- which lives at the root of the saved variables rather than in a
     profile, because "Grimtusk is a level 60 warrior" is a fact about the world
     and not a setting your rogue might disagree with. ]]--
cfg.stamp[1] = false
eq(cfg.names, true, "names are colored by default")

local function said(who)
    return "|Hplayer:" .. who .. "|h[" .. who .. "]|h: hello"
end

--[[ Yourself, learned at bind: the one player guaranteed present, and otherwise
     the only uncolored thing on screen until somebody else spoke. ]]--
local me = Stub.player.name

check(OB.roster[me] ~= nil, "you are in the roster after binding")
eq(OB.roster[me].class, "ROGUE", "with the class the client gave")

local mine = chat:Decorate(1, said(me))
check(string.find(mine, "|cff", 1, true) ~= nil, "so your own name is colored",
        mine)

--[[ The link survives. Only what is drawn between |h and |h is replaced, so
     clicking the name still whispers the right person -- and the brackets move
     outside the link, because that is where the client draws them. ]]--
check(string.find(mine, "|Hplayer:" .. me .. "|h", 1, true) ~= nil,
        "and the link is left intact, so the name is still clickable", mine)

--[[ **Only the first link, which is the sender.** Equadis' fix over upstream
     Prat: a message can carry player links of its own -- somebody typing a
     clickable name into what they say -- and rewriting every match paints the
     body of the message in the sender's colour. ]]--
local quoted = said(me) .. " ask |Hplayer:Grimtusk|h[Grimtusk]|h"
local out = chat:Decorate(1, quoted)
eq(string.find(out, "|Hplayer:Grimtusk|h[Grimtusk]|h", 1, true) ~= nil, true,
        "a link inside the message body is left exactly as it came", out)

--[[ Learned from the six rosters, each of which orders its answer differently.
     Guild is the trap: name, rank, rankIndex, level, class -- put the class one
     column left and every guildmate is coloured by the string "Officer". ]]--
Stub.guild = {
    { name = "Grimtusk", rank = "Officer", level = 60, class = "WARRIOR" },
}
event = "GUILD_ROSTER_UPDATE"
OB.modules.roster:OnEvent()

--[[ **A token, converted from the localized name the client actually answers.**

     `GetGuildRosterInfo` says "Warrior"; every colour table in the addon is
     keyed "WARRIOR". Storing what arrives leaves every guildmate white, and
     white is also what an unknown player looks like, so nothing shows. This is
     the whole job of the Babble library Prat carried for it. ]]--
eq(OB.roster["Grimtusk"].class, "WARRIOR", "a guildmate's class, not their rank")
eq(OB.roster["Grimtusk"].className, "Warrior",
        "with the client's own spelling kept beside it, for /who to query with")
eq(OB.roster["Grimtusk"].level, 60, "and their level")

local warrior = chat:Decorate(1, said("Grimtusk"))
local r, g, b = OB.ClassColor("WARRIOR")
check(string.find(warrior, string.format("%02x%02x%02x", r * 255, g * 255, b * 255),
        1, true) ~= nil, "so the name comes out in the warrior's color", warrior)

Stub.friends = { { name = "Sylvie", level = 42, class = "PRIEST" } }
event = "FRIENDLIST_UPDATE"
OB.modules.roster:OnEvent()
eq(OB.roster["Sylvie"].class, "PRIEST", "a friend's class, from a different order")

Stub.whoResults = {
    { name = "Dunkel", guild = "Nightfall", level = 31, class = "MAGE" },
}
event = "WHO_LIST_UPDATE"
OB.modules.roster:OnEvent()
eq(OB.roster["Dunkel"].class, "MAGE", "and a /who result, from a third")

--[[ Levels only go up. `/who` answers from a cache the server does not always
     refresh, so a lower level arriving later is the past catching up rather
     than somebody losing a level -- which cannot happen. ]]--
Stub.whoResults = { { name = "Dunkel", level = 12, class = "MAGE" } }
OB.modules.roster:OnEvent()
eq(OB.roster["Dunkel"].level, 31, "a lower level arriving later is stale, not new")

--[[ **The level is colored by level, not by class.** The two say different
     things and this is the one that cannot be had any other way: red through
     grey answers "is this a 60" without arithmetic, and painting it in the
     class colour would spend that space on a fact already shown to its right. ]]--
cfg.nameLevel = true

local low = chat:Decorate(1, said("Dunkel"))
local high = chat:Decorate(1, said("Grimtusk"))

check(string.find(low, "31|r", 1, true) ~= nil, "the level is shown", low)

--[[ Level 31 to a level 60 is grey; level 60 to a level 60 is yellow. Different
     colours for the same feature is the whole assertion -- one shared colour
     would pass a test that only checked a colour was present. ]]--
local _, _, lowColor = string.find(low, "|cff(%x%x%x%x%x%x)31|r")
local _, _, highColor = string.find(high, "|cff(%x%x%x%x%x%x)60|r")

check(lowColor ~= nil and highColor ~= nil, "each level carries its own color",
        tostring(lowColor) .. " / " .. tostring(highColor))
check(lowColor ~= highColor, "and a level far below you is not a level at yours",
        tostring(lowColor) .. " / " .. tostring(highColor))
eq(highColor, "ffff00", "your own level reads yellow, as the client colors it")

cfg.nameLevel = false

--[[ Brackets, which are the client's square by default and can be dropped
     entirely -- the quietest a name gets while still being clickable. ]]--
cfg.nameBrackets = 3
local bare = chat:Decorate(1, said("Grimtusk"))
check(string.find(bare, "[", 1, true) == nil, "brackets off means no brackets",
        bare)
check(string.find(bare, "|Hplayer:Grimtusk|h", 1, true) ~= nil,
        "and the name is still a link", bare)
cfg.nameBrackets = 1

--[[ Off is off: the line comes through as the client built it. ]]--
cfg.names = false
eq(chat:Decorate(1, said("Grimtusk")), said("Grimtusk"),
        "switched off, a line is left exactly as it came")
cfg.names = true
cfg.stamp[1] = true

--[[ **One idea, one phrasing.** Every checkbox that hides something when you
     leave combat says "Hide Out Of Combat" -- the bars' and the threat meter's.
     The meter's used to say "Show Out Of Combat", which is the same switch
     inverted, and two of those on one panel costs a moment's thought every
     visit working out which way round this one is.

     Asserted by sweeping the option tables rather than by naming the two, so a
     third one cannot arrive phrased the other way. ]]--
local combatRows, combatKeys = {}, {}

local function sweepCombat(options, where)
    for i = 1, table.getn(options) do
        local caption, key = options[i][1], options[i][2]

        if type(caption) == "string" and string.find(caption, "Out Of Combat") then
            table.insert(combatRows, where .. ": " .. caption)
            table.insert(combatKeys, tostring(key))
        end
    end
end

sweepCombat(OB.generalOptions or {}, "general")

for id, m in pairs(OB.modules) do
    if m.options then sweepCombat(m.options, id) end
end

local wrongWay = {}

for i = 1, table.getn(combatRows) do
    if not string.find(combatRows[i], "Hide Out Of Combat", 1, true) then
        table.insert(wrongWay, combatRows[i])
    end
end

check(table.getn(combatRows) >= 2, "there is more than one of these to agree",
        table.concat(combatRows, ", "))
eq(table.getn(wrongWay), 0, "and every one of them says Hide, not Show",
        table.concat(wrongWay, ", "))

--[[ And the key follows the caption. A caption that says hide over a key that
     means show is the same confusion moved one layer down, where the slash
     command finds it instead. ]]--
local wrongKey = {}

for i = 1, table.getn(combatKeys) do
    if not string.find(string.lower(combatKeys[i]), "hide", 1, true) then
        table.insert(wrongKey, combatKeys[i])
    end
end

eq(table.getn(wrongKey), 0, "and so does the key behind it",
        table.concat(wrongKey, ", "))

--[[ **The roster is not a setting and neither reset reaches it.** Somebody
     resetting their layout has not asked to forget what they know about a
     guildmate, and there is a separate way to say that when they mean it. ]]--
check(OB.defaults.modules.chat.names ~= nil, "names is a setting, in the profile")
eq(OB.profile.roster, nil, "the roster is not")
eq(EquadisClassicOverhaulDB.roster ~= nil, true, "it sits beside the profiles, not in one")

--[[ **Every gate in this module dims, none of them hides.**

     Both live in the same option row and are one position apart -- `dependsOn`
     at 8, `greyWhen` at 9 -- and the arguments before them differ by row kind,
     so a list row and a slider row put their gate in different columns. Counting
     wrong is silent: the row still gates, just the wrong way, and section 29's
     sweep does not reach a feature tab to notice.

     Chat has no hiding case at all. Nothing here is meaningless for your class
     the way rage decay is on a mage -- every switched-off setting is a setting
     that is still yours and merely not in charge. So the assertion is flat:
     column 8 is empty on every row in the file. ]]--
local misgated = {}

for i = 1, table.getn(chat.options) do
    local opt = chat.options[i]
    if opt[8] ~= nil then
        table.insert(misgated, tostring(opt[1]))
    end
end

eq(table.getn(misgated), 0, "no chat row hides itself rather than dimming",
        table.concat(misgated, ", "))

--[[ And the other half, so the check above cannot be satisfied by a module that
     gates nothing at all. ]]--
local gated = 0

for i = 1, table.getn(chat.options) do
    if chat.options[i][9] ~= nil then gated = gated + 1 end

end

check(gated > 10, "and the ones that depend on a switch do carry one",
        "rows carrying a greyWhen: " .. gated)


-- ---------------------------------------------------------------------------
-- item links that survive a custom channel
-- ---------------------------------------------------------------------------

--[[ **The server strips `|Hitem:` escapes out of any channel it did not make.**

     Paste an item into General and it arrives as a link; paste it into a guild's
     own channel and it arrives as nothing. Encoded as plain text on the way out
     and decoded on the way in, which is Prat's answer and the right one --
     anybody without the addon reads a name rather than a blank. ]]--
cfg.itemLinks = true
cfg.linkFormat = "ChatLink"

GLOBAL_link = "|cff1eff00|Hitem:4583:0:0:0|h[Thick Furry Mane]|h|r"

GLOBAL_wire = chat:EncodeLinks("look at " .. GLOBAL_link)
check(string.find(GLOBAL_wire, "{CLINK:ff1eff00:4583:0:0:0:Thick Furry Mane}",
        1, true), "an item link goes out as text", GLOBAL_wire)
check(not string.find(GLOBAL_wire, "|H", 1, true),
        "with nothing left for the server to strip")

eq(chat:DecodeLinks(GLOBAL_wire), "look at " .. GLOBAL_link,
        "and comes back the way it went")

--[[ **Both formats are read, whichever is sent.** Prat reads only what it sends,
     which means two people with the same addon and different settings cannot
     see each other's links. Decoding costs one substitution on a line that has
     to be scanned anyway. ]]--
Stub.items[4583] = { name = "Thick Furry Mane", rarity = 2 }

GLOBAL_cm = chat:DecodeLinks("look at [Thick Furry Mane]{4583:0:0:0}\b\b\b")
check(string.find(GLOBAL_cm, "|Hitem:4583", 1, true),
        "ChatManager's format is read too", GLOBAL_cm)
check(string.find(GLOBAL_cm, "|cff1eff00", 1, true),
        "with the quality colour the cache knows", GLOBAL_cm)

--[[ **An item nobody has seen still arrives clickable.** The local cache is the
     first answer and the backspaces are the second -- ChatManager encodes
     rarity as a count of them, invisible in a chat window, which is the whole
     trick. Failing both, the link is built uncoloured: an item you cannot colour
     beats an item you cannot click. ]]--
Stub.items[4583] = nil

GLOBAL_cm = chat:DecodeLinks("look at [Thick Furry Mane]{4583:0:0:0}\b\b\b")
check(string.find(GLOBAL_cm, "|Hitem:4583:0:0:0|h[Thick Furry Mane]|h", 1, true),
        "an uncached item is still a link", GLOBAL_cm)
check(string.find(GLOBAL_cm, "|cff1eff00", 1, true),
        "coloured from the backspace count instead", GLOBAL_cm)

--[[ Sending in ChatManager's format, for a channel where that is what everybody
     else is using. ]]--
cfg.linkFormat = "ChatManager"
GLOBAL_wire = chat:EncodeLinks(GLOBAL_link)

check(string.find(GLOBAL_wire, "[Thick Furry Mane]{4583:0:0:0}", 1, true),
        "the other format goes out too", GLOBAL_wire)
check(string.find(GLOBAL_wire, "\b", 1, true),
        "with the rarity in backspaces")
cfg.linkFormat = "ChatLink"

--[[ **Only the channels the client cannot already handle.**

     General, Trade, LookingForGroup and the defense channels carry links fine.
     Encoding into those would turn a working link into text for everybody --
     including the people without this addon, who can currently see the item. ]]--
Stub.channels = { "General - Stormwind", "GuildTrade", "Trade - Ironforge" }

check(not chat:ChannelNeedsEncoding(1), "General is left alone")
check(not chat:ChannelNeedsEncoding(3), "and Trade, in whatever city")
check(chat:ChannelNeedsEncoding(2), "a channel somebody made needs the encoding")

--[[ **The send hook is installed once and reads the switch inside**, on the rule
     the rest of this addon follows: a global function slot is one deep, so
     restoring our saved original would silently delete whatever a neighbour
     installed after us. ]]--
check(EquadisOverhaulBlizzSendChat ~= nil, "the original send is saved")
check(SendChatMessage ~= EquadisOverhaulBlizzSendChat, "and ours is in front of it")

Stub.sent = {}
SendChatMessage(GLOBAL_link, "CHANNEL", nil, 2)
check(string.find(Stub.sent[1].message, "{CLINK:", 1, true),
        "sending to a custom channel encodes", Stub.sent[1].message)

SendChatMessage(GLOBAL_link, "CHANNEL", nil, 1)
check(not string.find(Stub.sent[2].message, "{CLINK:", 1, true),
        "sending to General does not", Stub.sent[2].message)

SendChatMessage(GLOBAL_link, "SAY")
check(not string.find(Stub.sent[3].message, "{CLINK:", 1, true),
        "and neither does saying it out loud")

--[[ Off means the client's own behaviour, unchanged -- which is what a switched
     off setting has to look like. ]]--
cfg.itemLinks = false
SendChatMessage(GLOBAL_link, "CHANNEL", nil, 2)
eq(Stub.sent[4].message, GLOBAL_link, "switched off, nothing is encoded")
eq(chat:DecodeLinks(GLOBAL_wire), GLOBAL_wire, "and nothing is decoded")
cfg.itemLinks = true


-- ---------------------------------------------------------------------------
-- your name, lit up
-- ---------------------------------------------------------------------------

--[[ **Prat's Highlight module returns the text it was handed, unchanged.** It
     is a settings page with a switch wired to an empty function, and always has
     been. So this is not a port -- it is the feature that page promises. ]]--
cfg.highlight = true
cfg.highlightName = true
cfg.highlightColor = { 1, 0.85, 0.2, 1 }

--[[ **Say and Yell are two rows.** A yell carries across a zone and a say does
     not, which is the whole difference between them. ]]--
cfg.popup = true
cfg.popupSay = true
cfg.popupYell = false
chat.lastEvent = "CHAT_MSG_SAY"
check(chat:PopupChannelWanted(), "say can be wanted on its own")

chat.lastEvent = "CHAT_MSG_YELL"
check(not chat:PopupChannelWanted(), "without yell coming with it")

cfg.popupYell = true
check(chat:PopupChannelWanted(), "and the other way round")

--[[ **A numbered channel is answered by its number.** General, Trade and
     whatever a guild has made for itself are three rooms that share a naming
     scheme, and wanting one is not wanting all three. The client hands the
     number over as arg8, which is why the hook keeps it. ]]--
chat.lastEvent = "CHAT_MSG_CHANNEL"
cfg.popupChannel[2] = true
cfg.popupChannel[5] = false

chat.lastChannel = 2
check(chat:PopupChannelWanted(), "the channel that was asked for")

chat.lastChannel = 5
check(not chat:PopupChannelWanted(), "and not the one beside it")

chat.lastChannel = nil
check(not chat:PopupChannelWanted(), "and a line with no number at all is not one")

cfg.popupChannel[2] = false

--[[ **Your own name has its own switch**, rather than borrowing the Highlights
     column's. That was the bug: turning highlighting off, or turning your name
     off over there, silently stopped popups working for your name. ]]--
chat.lastEvent = "CHAT_MSG_GUILD"
cfg.popupGuild = true
cfg.popupName = true
cfg.highlight = false
cfg.highlightName = false

check(chat:ShouldPopup(1, "|Hplayer:Sylvie|h[Sylvie]|h: hey TestROGUE"),
        "your name pops up with highlighting switched off entirely")

cfg.popupName = false
check(not chat:ShouldPopup(1, "|Hplayer:Sylvie|h[Sylvie]|h: hey TestROGUE"),
        "and its own switch is what turns it off")

cfg.popupName = true
cfg.highlight = true
cfg.highlightName = true

--[[ **A search result keeps the time the line was said and gains no second
     one.** Stamping it again would put the moment you searched in front of the
     moment somebody spoke, and the one nearest the left margin reads as the
     authoritative one. ]]--
cfg.stamp[1] = true
chat.printing = true
eq(chat:Decorate(1, "a remembered line"), "a remembered line",
        "a search result is not stamped again")

chat.printing = nil
check(string.find(chat:Decorate(1, "a live line"), "^%d"),
        "while a live one still is")

eq(Stub.player.name, "TestROGUE", "the player is who the test thinks")

--[[ Built rather than written out, because "%02x" of 0.85 * 255 truncates to d8
     and an expectation typed by hand gets that wrong -- as this one did. ]]--
GLOBAL_hl = string.format("|cff%02x%02x%02x", cfg.highlightColor[1] * 255,
        cfg.highlightColor[2] * 255, cfg.highlightColor[3] * 255)

GLOBAL_lit = chat:Highlight("hey TestROGUE are you there")
check(string.find(GLOBAL_lit, GLOBAL_hl .. "TestROGUE|r", 1, true),
        "your own name is lit up", GLOBAL_lit)

--[[ **Whole words only.** 1.12's matcher has no word-boundary escape and no
     `%f`, so the character either side is matched and put back. Without it
     "Ollie" lights up inside "Ollies", which is worse than not lighting up. ]]--
GLOBAL_lit = chat:Highlight("TestROGUEs are the best")
check(not string.find(GLOBAL_lit, "|cff", 1, true),
        "and not when it is part of a longer word", GLOBAL_lit)

--[[ The start and end of a line are the two positions a character class cannot
     reach, so they are matched separately. ]]--
--[[ Plain search anchored by position rather than by `^`: with plain matching
     on, `^` is a literal caret and matches nothing. ]]--
check(string.find(chat:Highlight("TestROGUE hello"), GLOBAL_hl, 1, true) == 1,
        "a name at the very start still lights",
        chat:Highlight("TestROGUE hello"))
check(string.find(chat:Highlight("hello TestROGUE"), "|r$"),
        "and one at the very end")

--[[ **Links are lifted out of the way first, and that is not a nicety.**

     A chat line already carries `|Hplayer:Name|h[Name]|h`, and colouring the
     word inside it splits the escape -- the link stops working and the line
     renders as its own markup. This is the regression the suite caught while
     the feature was being written. ]]--
GLOBAL_linked = "|Hplayer:TestROGUE|h[TestROGUE]|h: hello TestROGUE"
GLOBAL_lit = chat:Highlight(GLOBAL_linked)

check(string.find(GLOBAL_lit, "|Hplayer:TestROGUE|h[TestROGUE]|h", 1, true),
        "a player link comes through untouched", GLOBAL_lit)
check(string.find(GLOBAL_lit, GLOBAL_hl .. "TestROGUE|r", 1, true),
        "while the same name outside it still lights", GLOBAL_lit)

--[[ **No custom word list.** A box of arbitrary text went straight into a Lua
     pattern, and a word holding a magic character makes an invalid one -- `gsub`
     throws, the throw happens inside `AddMessage`, and the chat frame stops
     rendering. The three sources left are ones whose text this addon controls
     and none of them can arrive holding a pattern. ]]--
check(chat.CustomWords == nil, "the custom word list is gone")
check(chat.AddHighlightWord == nil, "and so is the way to add to it")

--[[ **A gsub callback must never fall off its end.**

     1.12 replaces the match with an empty string when a replacement function
     returns nothing; 5.1, which this harness runs, keeps the original. So a
     callback with a conditional return works here and deletes every match in
     game -- which is what happened: the known-player pass matched `(%a+)` and
     every run of letters in every chat line vanished.

     This cannot be caught by running the code, because the harness has the
     forgiving rule. It is caught by reading it: every `function` handed to
     `gsub` in this addon must end in a `return`. ]]--
GLOBAL_src = io.open(path("modules/chat.lua")):read("*a")
GLOBAL_bad = 0

for GLOBAL_body in string.gfind(GLOBAL_src, "gsub%b()") do
    --[[ Only the ones taking a function. A string replacement has no end to
         fall off. ]]--
    if string.find(GLOBAL_body, "function", 1, true) then
        --[[ The last statement before the closing `end` of the callback. A
             callback whose final line is not a return leaves the nil path
             open. ]]--
        local _, _, tail = string.find(GLOBAL_body, "([^\n]*)\n%s*end%)?%s*$")

        if tail and not string.find(tail, "return") then
            GLOBAL_bad = GLOBAL_bad + 1
        end
    end
end

eq(GLOBAL_bad, 0, "every gsub callback ends in a return",
        "callbacks that can return nil: " .. GLOBAL_bad)

--[[ **And the whole chain is fail-safe**, because the alternative is chat that
     has stopped working. Everything in it runs inside `AddMessage`, and a throw
     there does not lose one message -- it takes the chat frame with it, and the
     only way back is a reload. Twice now. ]]--
GLOBAL_saved = chat.Decorated
chat.Decorated = function() error("deliberate") end
chat.decorateFailed = nil

eq(chat:Decorate(1, "a line somebody said"), "a line somebody said",
        "a pass that throws hands back the line it was given")

Stub.chat = {}
chat:Decorate(1, "another line")
eq(table.getn(Stub.chat), 0, "and says so once rather than once per line")

chat.Decorated = GLOBAL_saved
chat.decorateFailed = nil

--[[ **The fade is its own clock**, because it has to keep running while nothing
     else is happening -- which is the whole case this exists for. ]]--
cfg.popupSeconds = 10
chat:Popup("|Hplayer:Sylvie|h[Sylvie]|h: hey TestROGUE")

GLOBAL_pop = chat.popups[1]
check(GLOBAL_pop:IsShown(), "showing one shows the frame")
eq(GLOBAL_pop.left, 10, "with the time it was given")

chat:PopupFade(GLOBAL_pop, 9.5)
eq(GLOBAL_pop.alpha, 1, "still solid while its time is running")

chat:PopupFade(GLOBAL_pop, 1)
check(GLOBAL_pop.alpha < 1, "then fading", tostring(GLOBAL_pop.alpha))

chat:PopupFade(GLOBAL_pop, 1)
check(not GLOBAL_pop:IsShown(), "and gone when the fade finishes")

--[[ **They stack, and that is the bug this fixes.**

     One frame meant a second mention overwrote the first -- worst in exactly the
     case the feature exists for: two people speak to you while you are looking
     elsewhere, and you come back to one of them with no sign there was
     another. ]]--
chat:Popup("|Hplayer:Sylvie|h[Sylvie]|h: first")
chat:Popup("|Hplayer:Dunkel|h[Dunkel]|h: second")

check(chat.popups[1]:IsShown(), "the first is still up")
check(chat.popups[2]:IsShown(), "and the second is beside it")
check(string.find(chat.popups[1].text:GetText(), "first", 1, true),
        "each holding its own line")
check(string.find(chat.popups[2].text:GetText(), "second", 1, true),
        "not one overwriting the other")

--[[ Stacked downwards from the anchor, so a gap left by the middle of three
     closes rather than staying as a hole -- which reads as a popup that failed
     to draw. ]]--
GLOBAL_p1, GLOBAL_r1, GLOBAL_rp1, GLOBAL_x1, GLOBAL_y1 = chat.popups[1]:GetPoint()
GLOBAL_p2, GLOBAL_r2, GLOBAL_rp2, GLOBAL_x2, GLOBAL_y2 = chat.popups[2]:GetPoint()

eq(GLOBAL_x1, GLOBAL_x2, "both on the same column")
check(GLOBAL_y2 < GLOBAL_y1, "with the newer one below",
        tostring(GLOBAL_y1) .. " / " .. tostring(GLOBAL_y2))

--[[ **Capped**, and a new mention past the cap takes the oldest slot rather than
     growing the pile: the newest is the one nobody has read, and dropping it to
     protect a line that has been up for nine seconds is the wrong way round. ]]--
chat:Popup("third")
chat:Popup("fourth")
chat:Popup("fifth")

GLOBAL_up = 0
for GLOBAL_i = 1, 8 do
    if chat.popups[GLOBAL_i] and chat.popups[GLOBAL_i]:IsShown() then
        GLOBAL_up = GLOBAL_up + 1
    end
end

eq(GLOBAL_up, 4, "no more than four are ever on screen")
check(string.find(chat.popups[1].text:GetText(), "fifth", 1, true),
        "and the newest took the oldest slot",
        chat.popups[1].text:GetText())

for GLOBAL_i = 1, 4 do chat.popups[GLOBAL_i]:Hide() end

--[[ **The scale is re-applied on every settings pass.**

     It used to be set only when a popup appeared and when the mover was switched
     on, so moving the slider did nothing you could see: the frame in front of
     you kept the size it was built at. A scale you cannot watch change is a
     scale you cannot set. ]]--
cfg.popupScale = 1.4
chat:ApplyPopups()
eq(chat.popups[1].scale, 1.4, "the slider reaches a popup already on screen")
cfg.popupScale = 1

--[[ A mode rather than a lock, the same shape the bars and frames use. It shows
     a sample, because placing a frame that only appears when somebody speaks to
     you is otherwise a matter of waiting to be spoken to. ]]--
eq(chat:PopupMoving(), false, "the mover ships off")

chat:SetPopupMoving(true)
check(chat.popups[1]:IsShown(), "switching it on shows a sample")
check(chat.popups[1]:IsMovable(), "which can be dragged")

--[[ Held at full while it is being placed, or you would be chasing something
     that disappears. ]]--
chat:PopupFade(chat.popups[1], 30)
eq(chat.popups[1].alpha, 1, "and does not fade out from under you")

chat.popups[1]:ClearAllPoints()
chat.popups[1]:SetPoint("CENTER", UIParent, "CENTER", -100, 250)
chat:StorePopup()

eq(cfg.popupPos.x, -100, "where it was dropped is remembered")
eq(cfg.popupPos.y, 250, "on both axes")

chat:SetPopupMoving(false)
check(not chat.popups[1]:IsShown(), "and switching the mover off puts it away")
check(not chat.popups[1]:IsMovable(), "leaving nothing draggable behind")

cfg.popup = false
check(not chat:ShouldPopup(1, "|Hplayer:Sylvie|h[Sylvie]|h: hey TestROGUE"),
        "switched off, nothing pops up")


--[[ **Once per message, not once per window that shows it.**

     The client hands one line to every window subscribed to its channel, and the
     decoration chain runs for each -- so somebody with guild in three windows
     got three popups saying the same thing. Matched on text and moment
     together: all of those calls happen inside one frame, and the same line
     said twice a second apart is two mentions. ]]--
chat.lastPopped = nil
chat.lastPoppedAt = nil
chat.lastEvent = "CHAT_MSG_GUILD"
cfg.popup = true
cfg.popupGuild = true
cfg.popupName = true

GLOBAL_line = "|Hplayer:Sylvie|h[Sylvie]|h: hey TestROGUE"

check(chat:ShouldPopup(1, GLOBAL_line), "the first window pops it up")
check(not chat:ShouldPopup(2, GLOBAL_line), "and the second does not")
check(not chat:ShouldPopup(3, GLOBAL_line), "nor the third")

--[[ A different line in the same frame is a different mention. ]]--
check(chat:ShouldPopup(1, "|Hplayer:Dunkel|h[Dunkel]|h: TestROGUE hello"),
        "while another line still does")
OB.profile.modulesEnabled.chat = nil
OB.BindSlots()

end

chatTests()

-- 39. the roster: what the addon knows about other players, and how it asks
--
-- The passive half is Prat's PlayerNames readers. The half that talks to the
-- server is the part Prat had no answer for: most of the names in General
-- belong to people you have never grouped with, so no client roster ever
-- mentions them and they stay uncoloured forever.
-- ---------------------------------------------------------------------------

local function rosterTests()

context = "roster: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local roster = OB.modules.roster
check(roster ~= nil, "the roster module registers")
eq(OB.ModuleEnabled("roster"), true, "and ships on, unlike the chat module")

--[[ On because it is passive and free -- a table write when the client hands
     over a roster it was going to build anyway -- and because everything that
     colours a name reads from it. The half that costs something is a separate
     switch. ]]--
local cfg = OB.profile.modules.roster
eq(cfg.scan, false, "but asking the server is off")

Stub.whoSent = {}
Stub.whoToUI = 0

--[[ **Nothing is sent while neither half is wanted**, however much anybody wants
     to know. This is the assertion that matters most in this section: an addon
     that quietly queries the server on your behalf is exactly what these
     switches exist to prevent. ]]--
cfg.scanNames = false
OB.WantPlayer("Stranger")
roster:OnUpdate(1000)
eq(table.getn(Stub.whoSent), 0, "a name wanted while scanning is off asks nothing")

cfg.scan = true
cfg.scanNames = true

--[[ Wanted, then asked -- on the queue's clock rather than in the middle of
     drawing a chat line. ]]--
OB.WantPlayer("Stranger")
roster:OnUpdate(1000)
eq(table.getn(Stub.whoSent), 1, "with it on, the name is queried")
eq(Stub.whoSent[1], "Stranger", "by name")

--[[ Results answer into the interface, not into the chat frame. Without this a
     scan pours its output into chat, which is the opposite of the point. ]]--
eq(Stub.whoToUI, 1, "and the answer is pointed at the interface, not chat")

--[[ **One at a time.** A second query before the first is answered loses the
     first, because there is one result list and the server overwrites it. ]]--
OB.WantPlayer("Another")
roster:OnUpdate(1005)
eq(table.getn(Stub.whoSent), 1, "nothing else is sent while a query is pending")

Stub.WhoAnswer({ { name = "Stranger", level = 44, class = "SHAMAN" } })

eq(OB.roster["Stranger"].class, "SHAMAN", "the answer is learned")
eq(OB.roster["Stranger"].level, 44, "with the level")
eq(Stub.whoToUI, 0, "and the switch is handed back")

--[[ Handing it back matters: it is global, and left at 1 the next `/who` a
     player types answers into a frame they are not looking at. ]]--

--[[ **The gap is no longer a setting.** It starts at what a busy realm allows
     and the server widens or narrows it from there, so the tests read it off
     the module rather than off a slider that is not there any more. ]]--
roster.backoff = 0
GLOBAL_gap = roster:Wait()

--[[ **The interval holds even once the answer is in.** An answered query frees
     the queue but does not reset the clock -- the throttle is on the server, and
     a fast reply is not permission to ask again sooner. ]]--
roster:OnUpdate(1000 + GLOBAL_gap - 1)
eq(table.getn(Stub.whoSent), 1, "an early tick sends nothing, answer or no answer")

roster:OnUpdate(1000 + GLOBAL_gap + 1)
eq(table.getn(Stub.whoSent), 2, "and the next query goes once the interval passes")
eq(Stub.whoSent[2], "Another", "in the order they were wanted")

Stub.WhoAnswer({})

--[[ **A name is asked about once.** A busy channel repeats the same handful of
     people constantly; without this the queue would be that handful, over and
     over, forever. An empty answer counts as an answer -- they are offline, and
     asking again in four seconds learns the same nothing. ]]--
OB.WantPlayer("Another")
OB.WantPlayer("Another")
roster:OnUpdate(9000)
eq(table.getn(Stub.whoSent), 2, "a name already asked about is not asked again")

--[[ And a name already known is never queued at all. ]]--
OB.WantPlayer("Stranger")
roster:OnUpdate(9000)
eq(table.getn(Stub.whoSent), 2, "nor is one whose class is already known")

--[[ **Anybody unknown who speaks is asked about**, which is what Automatically
     Scan Unknown Players has always claimed to do and did not.

     It used to hang off name decoration: the roster heard about a speaker only
     if the chat module happened to be drawing their name, so turning player
     colouring off turned the lookups off with it, and a whisper was never asked
     about at all. The messages themselves are the right thing to listen to. ]]--
roster.queue = {}
roster.wanted = {}

event = "CHAT_MSG_SAY"
arg2 = "Talker"
roster:OnEvent()

eq(table.getn(roster.queue), 1, "somebody unknown speaking is queued for a query")
eq(roster.queue[1].query, "Talker", "by name")

--[[ A whisper counts, and it is the one the old path missed completely. ]]--
event = "CHAT_MSG_WHISPER"
arg2 = "Whisperer"
roster:OnEvent()
eq(table.getn(roster.queue), 2, "and a whisper counts, which it never used to")

--[[ `WantPlayer` is still the one place that decides, so everything it already
     refused it goes on refusing: somebody known, somebody queued, anybody at
     all while the setting is off. ]]--
event = "CHAT_MSG_SAY"
arg2 = "Stranger"
roster:OnEvent()
eq(table.getn(roster.queue), 2, "somebody already known is not queued")

arg2 = "Talker"
roster:OnEvent()
eq(table.getn(roster.queue), 2, "nor somebody already waiting to be asked about")

cfg.scanNames = false
arg2 = "Ignored"
roster:OnEvent()
eq(table.getn(roster.queue), 2, "and nobody at all while the setting is off")

cfg.scanNames = true
roster.queue = {}
roster.wanted = {}
event = nil
arg2 = nil

--[[ **Not while somebody is reading the Who list.** The query redirects results
     away from the interface, so scanning under an open Friends frame empties
     the list being read. ]]--
FriendsFrame:Show()
OB.WantPlayer("Thirdparty")
roster:OnUpdate(20000)
eq(table.getn(Stub.whoSent), 2, "nothing is sent while the Who list is open")

FriendsFrame:Hide()
roster:OnUpdate(30000)
eq(table.getn(Stub.whoSent), 3, "and it resumes when it closes")
Stub.WhoAnswer({})

--[[ Nor in combat, which is courtesy rather than correctness -- the query would
     work, it just should not be competing with a fight. ]]--
OB.inCombat = true
OB.WantPlayer("Fourth")
roster:OnUpdate(40000)
eq(table.getn(Stub.whoSent), 3, "nothing is sent in combat")

OB.inCombat = false
roster:OnUpdate(50000)
eq(table.getn(Stub.whoSent), 4, "and it resumes out of it")
Stub.WhoAnswer({})

-- ---------------------------------------------------------------------------
-- the census
-- ---------------------------------------------------------------------------

--[[ **A band that comes back full has not answered its own question.**

     Forty-nine results does not mean forty-nine players; it means at least
     forty-nine, and the rest are not coming. So the range is halved and asked
     again, which is the whole of the level/class splitting. ]]--
Stub.whoSent = {}
roster.queue = {}
roster:StartCensus()

eq(table.getn(roster.queue), 6, "the sweep queues one query per ten levels")

roster:OnUpdate(100000)
eq(Stub.whoSent[1], "1-10", "starting at the bottom")

--[[ Under the cap: the band is done and nothing is split. ]]--
local few = {}
for i = 1, 3 do table.insert(few, { name = "Low" .. i, level = 5, class = "MAGE" }) end
Stub.WhoAnswer(few)
eq(table.getn(roster.queue), 5, "a band that fits is finished with")

roster:OnUpdate(200000)
eq(Stub.whoSent[2], "11-20", "and the sweep moves on")

--[[ At the cap: halved, and **both halves go to the front**.

     They used to go on the end, which meant an overflow anywhere left a tail of
     re-asks after every level had been walked -- and with the report naming no
     levels, that tail was indistinguishable from a sweep going round in
     circles. Splitting a band is finishing that band. ]]--
local many = {}
for i = 1, 49 do table.insert(many, { name = "Mid" .. i, level = 15, class = "ROGUE" }) end
Stub.WhoAnswer(many)

eq(table.getn(roster.queue), 6, "a band that comes back full is split in two")

roster:OnUpdate(300000)
eq(Stub.whoSent[3], "11-15", "and its own halves are what gets asked next")

Stub.WhoAnswer({})
roster:OnUpdate(400000)
eq(Stub.whoSent[4], "16-20", "the second half after the first, in order")

Stub.WhoAnswer({})
roster:OnUpdate(500000)
eq(Stub.whoSent[5], "21-30", "and only then does the sweep move on")

--[[ **The class split is the last cut, and it uses the client's own spelling.**

     A single level that still comes back full cannot be narrowed by level any
     further. The class names come from what the roster has actually seen rather
     than from a hardcoded English list, which would send nine queries matching
     nothing on a German realm. ]]--
Stub.WhoAnswer({})
roster.queue = {}
roster.pending = nil

roster:Split({ kind = "band", low = 60, high = 60 })

local classQueries = table.getn(roster.queue)
check(classQueries > 0, "a single level splits by class instead",
        "queued: " .. classQueries)

local sawClass = false
for i = 1, classQueries do
    if string.find(roster.queue[i].query, 'c-"', 1, true) then sawClass = true end
end
check(sawClass, "using the client's own spelling of the class name",
        roster.queue[1] and roster.queue[1].query or "nothing")

--[[ And it stops there. A class query that still comes back full keeps its
     forty-nine, which is forty-nine more than it had -- there is nothing left
     to cut by. ]]--
local before = table.getn(roster.queue)
roster:Split({ kind = "band", low = 60, high = 60, byClass = true })
eq(table.getn(roster.queue), before, "a class query is not split again")

--[[ **Level sixty splits, and then the sweep is over.**

     The last level is the one that overflows on any realm worth scanning, and
     its class queries are the last work there is -- so when they are done the
     sweep finishes rather than carrying on. That falls out of putting them at
     the front: they are level sixty's own queries, asked in level sixty's turn,
     and there is nothing behind them. ]]--
OB.roster = {}
roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.nextAsk = nil
roster.autoHeld = nil
cfg.scan = true
cfg.scanNames = false

roster:StartFullScan()

--[[ Every level below sixty answered and done with, which is where a sweep is
     by the time this matters. ]]--
while table.getn(roster.queue) > 1 do table.remove(roster.queue, 1) end

eq(roster.queue[1].query, "60", "the last query of a sweep is level sixty")

roster:OnUpdate(600000)

Stub.chat = {}
GLOBAL_full = {}
for GLOBAL_i = 1, 49 do
    table.insert(GLOBAL_full,
            { name = "Sixty" .. GLOBAL_i, level = 60, class = "Rogue" })
end

Stub.WhoAnswer(GLOBAL_full)

check(table.getn(roster.queue) > 1, "coming back full queues it again by class",
        table.getn(roster.queue) .. " queued")

--[[ **Said once**, because this is the one moment the sweep stops being one
     query per level and there is nothing else to tell the reader: without it,
     nine more identical lines look exactly like a sweep going round in
     circles. ]]--
check(string.find(table.concat(Stub.chat, " "), "came back full", 1, true),
        "and says so, once", table.concat(Stub.chat, " "))

--[[ Nine, not ten. The player's own class used to arrive as "MAGE" while
     everybody else's arrived as "Mage", so an overflowing level was asked about
     twice for one class -- a wasted query, and one more line in a stretch the
     reader was already struggling to tell apart. ]]--
OB.roster["Selfy"] = { className = "MAGE", class = "MAGE" }
OB.roster["Otherguy"] = { className = "Mage", class = "MAGE" }

GLOBAL_seen = 0
GLOBAL_names = roster:ClassNames()
for GLOBAL_i = 1, table.getn(GLOBAL_names) do
    if string.lower(GLOBAL_names[GLOBAL_i]) == "mage" then
        GLOBAL_seen = GLOBAL_seen + 1
    end
end

eq(GLOBAL_seen, 1, "one spelling per class, whatever case it arrived in")

--[[ And when the class queries run out, so does the sweep. ]]--
roster.queue = {}
roster.pending = { kind = "band", low = 60, high = 60, byClass = true,
                   query = '60 c-"Druid"', label = "level 60 Druids" }
roster.pendingAt = GetTime()
Stub.chat = {}

Stub.WhoAnswer({})

check(string.find(table.concat(Stub.chat, " "), "Scan finished...", 1, true),
        "the last class query ends the sweep", table.concat(Stub.chat, " "))
eq(roster.scanTotal, nil, "with nothing left queued behind it")

OB.roster = {}
roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
cfg.scan = false

--[[ **Switching the sweep off drops what it queued**, or it is a switch that
     does not work. Names are kept: somebody is looking at one right now. ]]--
roster.queue = {}
roster:StartCensus()
table.insert(roster.queue, { kind = "name", query = "Someone" })

--[[ The sweep is stopped by its button now rather than by a checkbox, and
     stopping it empties the queue whole -- names included, because the button
     says Stop rather than Stop Except. ]]--
roster:SetScanning(false)

local bands, names = 0, 0
for i = 1, table.getn(roster.queue) do
    if roster.queue[i].kind == "band" then bands = bands + 1 else names = names + 1 end
end

eq(bands, 0, "stopping the sweep drops the bands")
eq(names, 0, "and everything else queued with them")

--[[ Switching the whole thing off drops everything and hands the global switch
     back, which is the one piece of client state this module borrows. ]]--
roster.pending = { kind = "name", query = "Someone" }
SetWhoToUI(1)

cfg.scan = false
cfg.scanNames = false
roster:AfterSet("scan", false)

eq(table.getn(roster.queue), 0, "switching scanning off drops the queue")
eq(Stub.whoToUI, 0, "and hands back the switch it borrowed")


-- ---------------------------------------------------------------------------
-- saying what each query was worth
-- ---------------------------------------------------------------------------

--[[ **One line per query: what it was worth, and when the next one is.**

     A sweep is otherwise twenty seconds of nothing followed by twenty seconds
     of nothing, and the only sign of life is a counter on a button you have to
     go and look at. One line per query is the same rate as the queries
     themselves -- slow enough to read, often enough to believe. ]]--
OB.roster = {}
roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.nextAsk = nil
cfg.scan = true

roster:StartFullScan()
roster:OnUpdate(9000)

Stub.chat = {}
Stub.WhoAnswer({ { name = "Onenew", level = 1, class = "MAGE" },
                 { name = "Twonew", level = 1, class = "ROGUE" } })

GLOBAL_said = table.concat(Stub.chat, " ")
check(string.find(GLOBAL_said, "2 results added to database", 1, true),
        "the line says what the query was worth", GLOBAL_said)

--[[ It does not name the query at either end any more. With the sweep walking
     the levels in order, "scanned for level 3 players" is the reader being told
     what they can already count. ]]--
check(not string.find(GLOBAL_said, "scanned for", 1, true),
        "and does not narrate what it asked for", GLOBAL_said)

--[[ **What was new, not what came back.** A query answering fifty names you
     already had is worth nothing, and a line claiming fifty would say the
     sweep was working when it was treading water. ]]--
roster:OnUpdate(9000 + GLOBAL_gap + 1)

Stub.chat = {}
Stub.WhoAnswer({ { name = "Onenew", level = 1, class = "MAGE" } })

check(string.find(table.concat(Stub.chat, " "), "0 results added", 1, true),
        "somebody already known counts for nothing",
        table.concat(Stub.chat, " "))

--[[ **And the countdown to the next one**, which is the half that cannot be
     worked out from the outside: the gap widens and narrows with whatever the
     server is allowing. ]]--
Stub.SetClock(9000)
Stub.chat = {}

roster.queue = { { kind = "band", low = 3, high = 3, query = "3",
                   label = "level 3 players" } }
roster.pending = { kind = "band", low = 2, high = 2, query = "2",
                   label = "level 2 players" }
roster.pendingAt = GetTime()
roster.nextAsk = GetTime() + 17

Stub.WhoAnswer({})

check(string.find(table.concat(Stub.chat, " "), "next scan in 17 seconds", 1, true),
        "the same line counts down to the next query",
        table.concat(Stub.chat, " "))

--[[ Counted off `nextAsk` rather than off the gap, because the gap is what was
     asked for and `nextAsk` is what is happening -- the two differ by however
     much the server has widened it. ]]--
Stub.chat = {}
roster.queue = { { kind = "band", low = 4, high = 4, query = "4",
                   label = "level 4 players" } }
roster.pending = { kind = "band", low = 3, high = 3, query = "3",
                   label = "level 3 players" }
roster.pendingAt = GetTime()
roster.nextAsk = GetTime() + 41

Stub.WhoAnswer({})

check(string.find(table.concat(Stub.chat, " "), "next scan in 41 seconds", 1, true),
        "so a widened gap is the one it counts down",
        table.concat(Stub.chat, " "))

--[[ The last query has no next one to count down to, so it says the sweep is
     over instead -- which it never used to, because the line was gated on the
     queue being non-empty and by then it never was. ]]--
Stub.chat = {}
roster.queue = {}
roster.pending = { kind = "band", low = 5, high = 5, query = "5",
                   label = "level 5 players" }
roster.pendingAt = GetTime()

Stub.WhoAnswer({})

check(string.find(table.concat(Stub.chat, " "), "Scan finished...", 1, true),
        "and the last one says the sweep is over",
        table.concat(Stub.chat, " "))

--[[ **One shape, and class only where a level spills.**

     There were three of them on a dropdown, and two were strictly worse:
     level-and-class is five hundred and forty queries to pre-empt an overflow
     that happens at a handful of levels, and by zone misses instances and
     anywhere this addon has no level range for. A choice where two answers are
     wrong is not a choice, it is a trap with a label on it. ]]--
check(OB.scanModes == nil, "there is no shape left to choose")
check(roster.QueueZones == nil, "and no zone sweep to choose it")

roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.nextAsk = nil

roster:StartFullScan()
eq(table.getn(roster.queue), 60, "a sweep is sixty queries, one per level")
eq(roster.queue[1].query, "1", "each level asked on its own")
eq(roster.queue[60].query, "60", "up to sixty")

--[[ **Fifty is a cap, not a count.** A level answering with the cap has not
     answered, so that level alone is asked again once per class -- which cannot
     overflow on any realm anybody plays on. In practice this is sixty, and
     wherever the levelling crowd happens to be. ]]--
roster.queue = {}
OB.roster = {}

roster:Split({ kind = "band", low = 60, high = 60, query = "60",
               label = "level 60 players" })

eq(table.getn(roster.queue), 9, "a full level splits into nine class queries")
check(string.find(roster.queue[1].query, 'c-"', 1, true),
        "each naming a class", roster.queue[1].query)
check(string.find(roster.queue[1].query, "60", 1, true),
        "at that level and no other", roster.queue[1].query)

--[[ From the English nine when nothing has been seen yet, or a fresh install
     would split a full level into no queries at all. ]]--
check(roster.queue[1].byClass, "and marked, so it is never split a second time")

roster.queue = {}
OB.roster = {}

-- ---------------------------------------------------------------------------
-- a query that is never answered
-- ---------------------------------------------------------------------------

--[[ **The server drops a `/who` that arrives inside its throttle and sends
     nothing back at all.**

     `MayAsk` refuses while one is outstanding, because there is one result list
     and a second query overwrites the first. That is right, and on its own it is
     a trap: `pending` stays set and the queue never moves again. One lost answer
     and the sweep is over for the session, silently -- which is what "the scan
     does not appear to be working" looked like from the outside.

     Abandoned after twice the interval, which is long enough that an answer
     arriving beside the next ask is not mistaken for a loss. ]]--
roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.nextAsk = nil
Stub.whoSent = {}
Stub.whoToUI = 0
cfg.scan = true

roster:StartFullScan()
roster:OnUpdate(5000)
eq(table.getn(Stub.whoSent), 1, "the sweep sends its first query")

--[[ Nothing comes back. Inside the window, the sweep waits, which is correct. ]]--
roster:OnUpdate(5000 + GLOBAL_gap * 2 - 1)
eq(table.getn(Stub.whoSent), 1, "and waits while an answer might still arrive")

roster:OnUpdate(5000 + GLOBAL_gap * 2 + 1)
eq(table.getn(Stub.whoSent), 2, "then gives up on it and carries on")
eq(Stub.whoToUI, 1, "taking the switch again for the new query")

--[[ **The server's throttle is not the one in the settings, and it wins.**

     Twenty seconds between queries was doing level 1, skipping level 2, doing
     level 3: reports a flat sixty seconds apart on a twenty-second interval,
     with every second level missing. That arithmetic is the whole diagnosis --
     twenty seconds to ask, forty to give up on an answer that was never coming,
     then ask again. Every other query was arriving inside a throttle longer
     than the one this addon was keeping.

     So the setting is a floor and the gap is the floor plus whatever the server
     has taught it. ]]--
eq(roster.backoff, GLOBAL_gap, "a dropped query widens the gap by an interval")
eq(roster:Wait(), GLOBAL_gap * 2, "which is what it waits from then on")

--[[ And the dropped query is asked again rather than written off. It used to be
     discarded, which was defensible only while dropping was rare -- and it was
     every other query. ]]--
eq(Stub.whoSent[2], Stub.whoSent[1], "the dropped query is the one asked again")

--[[ Once. A retry the server also ignores is a query it is not going to answer,
     and re-queueing forever would stop the sweep at that level. ]]--
GLOBAL_left = table.getn(roster.queue)
roster:OnUpdate(5000 + GLOBAL_gap * 7)
eq(table.getn(roster.queue), GLOBAL_left - 1, "but only once, so the sweep moves on")

--[[ An answer is the server saying this rate is fine, so the gap eases back
     towards the setting a second at a time -- coming to rest just above the real
     limit rather than snapping back to a rate already refused once. ]]--
roster.backoff = GLOBAL_gap
roster.pending = { kind = "name", query = "Someone" }
roster.pendingAt = GetTime()

Stub.WhoAnswer({})
eq(roster.backoff, GLOBAL_gap - 1, "an answer eases it back a second")

--[[ Handed back on the way out, so a sweep that gives up does not leave the
     next `/who` anybody types answering into a frame they are not looking at. ]]--
roster.pending = nil
roster.pendingAt = nil
roster.queue = {}
Stub.whoToUI = 0

-- ---------------------------------------------------------------------------
-- the Who window never opens
-- ---------------------------------------------------------------------------

--[[ **Stopped from opening, rather than closed afterwards.**

     Closing it afterwards was two panel sounds and a flicker every twenty
     seconds, which is fine for a minute and unbearable for an hour.

     The chat route is not available, tempting as it looks: `SetWhoToUI(0)`
     prints the answer as text and nothing else -- `GetWhoInfo` stays empty and
     `WHO_LIST_UPDATE` never fires -- so names, levels and classes would have to
     be parsed out of sentences in whatever language the client is running in.
     The structured answer exists only in UI mode. ]]--
roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.nextAsk = nil
roster.showPanel = nil
FriendsFrame:Hide()

GLOBAL_realShow = ShowUIPanel

roster:Ask({ kind = "name", query = "Someone" }, 900000)

check(ShowUIPanel ~= GLOBAL_realShow, "a query of ours holds the panel opener")

--[[ Only this one frame. Everything else opens exactly as it did -- the point
     is a window nobody asked for, not a UI that stops working for a second. ]]--
ShowUIPanel(FriendsFrame)
check(not FriendsFrame:IsVisible(), "and the Who window is not opened by it")

ShowUIPanel(GameTooltip)
check(GameTooltip:IsVisible(), "while anything else still opens")
GameTooltip:Hide()

--[[ Handed back the moment the answer lands, because it is a global and holding
     one a second longer than the query is a bug waiting for somebody else's
     addon to find. ]]--
Stub.WhoAnswer({})

eq(ShowUIPanel, GLOBAL_realShow, "and it is handed back when the answer lands")

--[[ Handed back on the way out too: a query that is never answered would
     otherwise leave the opener held for the rest of the session. ]]--
roster.queue = {}
roster:Ask({ kind = "name", query = "Nobody", retried = true }, 900000)
check(ShowUIPanel ~= GLOBAL_realShow, "held again for the next query")

roster:OnUpdate(900000 + roster:Wait() * 3)
eq(ShowUIPanel, GLOBAL_realShow, "and released when one is given up on")

roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.wanted = {}

-- ---------------------------------------------------------------------------
-- lookups stand aside while a sweep runs
-- ---------------------------------------------------------------------------

--[[ **They spend the same allowance, and the setting is left alone.**

     Automatically Scan Unknown Players and the sweep both cost `/who` queries
     out of one throttle, and there is a single result list between them -- so
     every name a busy channel triggers is a level the sweep never gets to ask
     about. On a realm where General does not stop, that is most of them.

     An earlier version unticked the box and put it back afterwards, which was a
     lie about who had decided what: the reader's answer is still yes, it is just
     not in charge for the next twenty minutes. ]]--
roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.nextAsk = nil
roster.autoHeld = nil
OB.roster = {}
Stub.chat = {}

cfg.scanNames = true
roster:SetScanning(true)

eq(cfg.scanNames, true, "starting a sweep leaves the setting exactly as it was")
check(roster:Sweeping(), "with a sweep running")

--[[ It just does not happen. The refusal is in `WantPlayer`, which is the one
     place that decides, so it holds for every caller. ]]--
GLOBAL_before = table.getn(roster.queue)

event = "CHAT_MSG_SAY"
arg2 = "Newvoice"
roster:OnEvent()
event = nil
arg2 = nil

eq(table.getn(roster.queue), GLOBAL_before,
        "and an unknown player speaking is not queued while it runs")

--[[ Said once, so somebody watching knows why the names stopped colouring. ]]--
check(string.find(table.concat(Stub.chat, " "),
                "Automatic lookup turned off while scan is running", 1, true),
        "the reader is told why", table.concat(Stub.chat, " "))

--[[ **And the row is greyed rather than unticked**, which is the same fact said
     in the panel: still yours, not in charge. `greyWhen` cannot express it --
     it reads config keys and "a sweep is running" is not one -- so the module
     answers for its own row. ]]--
check(roster:RowGreyed({ key = "scanNames" }),
        "the row is dimmed while the sweep runs")
check(not roster:RowGreyed({ key = "announceScan" }),
        "and nothing else on the page is")

--[[ Stopping says what the sweep was worth and gives the lookups back. ]]--
roster.sweepAdded = 137
Stub.chat = {}
roster:SetScanning(false)

GLOBAL_said = table.concat(Stub.chat, " ")
check(string.find(GLOBAL_said, "Scan stopped... 137 entries were added to database",
                1, true),
        "stopping says what it was worth", GLOBAL_said)
check(string.find(GLOBAL_said, "Automatic scan re-enabled", 1, true),
        "and that the lookups are back", GLOBAL_said)

eq(cfg.scanNames, true, "the setting having never been touched")
check(not roster:RowGreyed({ key = "scanNames" }), "and the row is live again")

--[[ Somebody who had lookups off is not told they are back on, because they
     never went off. ]]--
cfg.scanNames = false
roster:SetScanning(true)

Stub.chat = {}
roster:SetScanning(false)

check(not string.find(table.concat(Stub.chat, " "), "re-enabled", 1, true),
        "nothing is announced to somebody who had them off",
        table.concat(Stub.chat, " "))

--[[ **The count only goes forwards.**

     It used to be `total - remaining`, and remaining is not a countdown: a level
     that comes back full puts nine more on the queue, so the number went
     backwards -- and between the last query going out and its answer coming
     back the queue was empty, which read as no sweep at all and turned Stop back
     into Begin. ]]--
cfg.scanNames = true
roster.queue = {}
roster:SetScanning(true)

eq(roster:ScanProgress(), "0 of 60", "a fresh sweep has asked nothing")

roster:OnUpdate(700000)
eq(roster:ScanProgress(), "1 of 60", "and counts what it asks")

--[[ The queue is empty here -- the query is out and the answer is not back --
     and the button still says Stop, because a sweep is running. ]]--
roster.queue = {}
check(roster:ScanProgress(), "an outstanding query is still a sweep in progress")
check(roster:Sweeping(), "so the button offers to stop rather than to begin")

roster.queue = {}
roster.pending = nil
roster.pendingAt = nil
roster.autoHeld = nil
roster.scanTotal = nil
roster.sweepAdded = nil
cfg.scan = false
cfg.scanNames = true
Stub.chat = {}

-- ---------------------------------------------------------------------------
-- saying what the sweep found
-- ---------------------------------------------------------------------------

--[[ **A three-hour sweep with no visible output is one nobody believes is
     running.** The only other evidence was a counter on a button you had to go
     and look at. ]]--
OB.roster = {}
roster.queue = {}

cfg.announceScan = false

Stub.chat = {}
roster:Learn("Healingcow", "Priest", 14)
eq(table.getn(Stub.chat), 0, "nothing is said with the switch off")

cfg.announceScan = true

Stub.chat = {}
roster:Learn("Tankface", "Warrior", 22)

check(string.find(table.concat(Stub.chat, " "), "Player added to database:", 1, true),
        "a new player is named", table.concat(Stub.chat, " "))

--[[ **`22:Tankface`, in two colours answering two different questions.**

     The level takes the client's difficulty colours -- where they are relative
     to you -- and the name takes the class colour, which is who they are.
     Between them the line says everything the database just learned. ]]--
GLOBAL_said = table.concat(Stub.chat, " ")
GLOBAL_r, GLOBAL_g, GLOBAL_b = OB.LevelColor(22)

check(string.find(GLOBAL_said, string.format("|cff%02x%02x%02x22|r:",
                GLOBAL_r * 255, GLOBAL_g * 255, GLOBAL_b * 255), 1, true),
        "the level wears its difficulty colour", GLOBAL_said)

GLOBAL_r, GLOBAL_g, GLOBAL_b = OB.ClassColor("WARRIOR")

check(string.find(GLOBAL_said, string.format("|cff%02x%02x%02xTankface|r",
                GLOBAL_r * 255, GLOBAL_g * 255, GLOBAL_b * 255), 1, true),
        "and the name its class colour", GLOBAL_said)

--[[ **Only the first time.** Somebody whose level went up is not new, and
     re-announcing would make the stream unreadable -- the line means "here is
     one more". ]]--
Stub.chat = {}
roster:Learn("Tankface", "Warrior", 23)
eq(table.getn(Stub.chat), 0, "and not again when the same one is seen")

--[[ Off again, and nothing is said -- a guild roster hands over forty names the
     moment you log in, which is why this is a switch and why it is off. ]]--
cfg.announceScan = false

Stub.chat = {}
roster:Learn("Somebodyelse", "Mage", 60)
eq(table.getn(Stub.chat), 0, "and nothing once it is switched off again")

OB.roster = {}
FriendsFrame:Hide()
Stub.whoSent = {}
Stub.whoResults = {}

end

rosterTests()

-- 40. quality of life: the small things
--
-- Nothing here is a subsystem. Each is one behaviour the client does not have,
-- and the only thing they share is that none is worth an addon of its own --
-- which is exactly what makes them worth one tab of a bundle.
-- ---------------------------------------------------------------------------

--[[ **Not a local.** The main chunk is at Lua 5.0's two hundred local limit,
     which is the same ceiling the addon's own functions live under -- and one
     more `local function` here is a compile error rather than a warning.

     A global costs nothing in a test file and leaves the headroom for the next
     section, which will want a name too. ]]--
function qolTests()

context = "qol: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local qol = OB.modules.qol
check(qol ~= nil, "the quality of life module registers")

--[[ The module is on and everything in it is off. The module itself does
     nothing -- every behaviour has its own switch -- so leaving it disabled as
     well would mean two switches to reach one setting. ]]--
eq(OB.ModuleEnabled("qol"), true, "and is enabled, because it does nothing itself")

local cfg = OB.profile.modules.qol
eq(cfg.tipLevelColor, false, "level colouring is off until asked for")
eq(cfg.tipFlee, false, "so is the flee note")
eq(cfg.cameraSpeed, false, "and so is the camera")

-- ---------------------------------------------------------------------------
-- reading the level line
-- ---------------------------------------------------------------------------

--[[ **1.12 has no `mouseover` unit token.** The tooltip for a mob you hover is
     filled in by the client rather than by Lua, so there is nothing to ask
     "which unit is this" -- which is why an addon that hooks SetUnit misses the
     common case entirely.

     The text is there and it is unambiguous, so that is what gets read. ]]--
local level, kind = qol:ReadLevelLine("Level 60 Humanoid")
eq(level, "60", "the level comes out of the line")
eq(kind, "Humanoid", "and so does the creature type")

level, kind = qol:ReadLevelLine("Level 42 Elite Beast")
eq(level, "42", "elite does not get in the way of the level")
eq(kind, "Beast", "nor of the type")

--[[ `??` is a real level and means "at least ten above you", which is why the
     level comes back as a string rather than a number. ]]--
level = qol:ReadLevelLine("Level ?? Boss")
eq(level, "??", "an unknown level is read as itself, not dropped")

eq(qol:ReadLevelLine("Thunderfury, Blessed Blade of the Windseeker"), nil,
        "a line with no level in it is not one")
eq(qol:ReadLevelLine(nil), nil, "and neither is nothing at all")

-- ---------------------------------------------------------------------------
-- whether it runs
-- ---------------------------------------------------------------------------

--[[ **There is no API for this.** Fleeing is a per-creature flag on the server
     and the client tells you only by doing it, at the worst possible moment,
     when the thing you have nearly killed runs into the next camp.

     The creature type is knowable and predicts it well: things with a mind and a
     body run, things with neither do not. ]]--
eq(qol:Flees("Humanoid"), true, "humanoids run")
eq(qol:Flees("Beast"), true, "so do beasts")
eq(qol:Flees("Undead"), false, "the undead do not")
eq(qol:Flees("Elemental"), false, "nor do elementals")
eq(qol:Flees("Mechanical"), false, "nor constructs")

--[[ **Three answers, not two.** A type the table has never heard of is genuinely
     unknown, and saying nothing is the honest form of that -- a boolean would
     have to pick a side, and picking the confident side is the one that gets
     somebody killed. ]]--
eq(qol:Flees("Not specified"), nil, "an unfamiliar type is unknown, not a guess")
eq(qol:Flees(nil), nil, "and no type at all is the same")

-- ---------------------------------------------------------------------------
-- decorating what is on screen
-- ---------------------------------------------------------------------------

GameTooltip:SetMob("Defias Thug", 18, "Humanoid")

local levelLine = getglobal("GameTooltipTextLeft2")
eq(levelLine:GetText(), "Level 18 Humanoid", "the client writes the level line")
eq(levelLine.color, nil, "and nothing has touched its colour while both are off")
eq(GameTooltip:NumLines(), 2, "nor added a line to it")

cfg.tipLevelColor = true
GameTooltip:SetMob("Defias Thug", 18, "Humanoid")

--[[ Recoloured rather than added to: the level is already written down, and a
     second copy of it in a different colour is worse than the white one. ]]--
check(levelLine.color ~= nil, "with colouring on, the existing line is recoloured")
eq(GameTooltip:NumLines(), 2, "and no line is added to say it twice")

--[[ Level 18 to a level 60 is grey; level 60 is yellow. Different colours for
     the same feature is the assertion -- one shared colour would pass a test
     that only checked a colour was present. ]]--
local lowColor = levelLine.color[1] .. "," .. levelLine.color[2]

GameTooltip:SetMob("Onyxia", 60, "Dragonkin")
local atColor = levelLine.color[1] .. "," .. levelLine.color[2]

check(lowColor ~= atColor, "a level far below you is not a level at yours",
        lowColor .. " / " .. atColor)

--[[ **`??` is the most dangerous answer there is**, and `tonumber` makes it nil,
     which LevelColor would read as "unknown" and paint grey -- the colour that
     means "beneath notice". Sent through as red instead. ]]--
GameTooltip:SetMob("Lord Kazzak", "??", nil)
eq(levelLine.color[1], OB.levelColors.red[1], "an unknown level reads as red")
eq(levelLine.color[2], OB.levelColors.red[2], "not as grey")

cfg.tipLevelColor = false

-- the flee note, which is new information and so is a new line
cfg.tipFlee = true

GameTooltip:SetMob("Defias Thug", 18, "Humanoid")
eq(GameTooltip:NumLines(), 3, "the flee note is added as its own line")
check(string.find(getglobal("GameTooltipTextLeft3"):GetText(), "flee", 1, true) ~= nil,
        "and says so", getglobal("GameTooltipTextLeft3"):GetText())

GameTooltip:SetMob("Skeletal Warrior", 22, "Undead")
check(string.find(getglobal("GameTooltipTextLeft3"):GetText(), "death", 1, true) ~= nil,
        "something that does not run says that instead",
        getglobal("GameTooltipTextLeft3"):GetText())

--[[ Unknown stays quiet. This is the whole reason `Flees` has three answers. ]]--
GameTooltip:SetMob("Something Strange", 30, nil)
eq(GameTooltip:NumLines(), 2, "and an unfamiliar type says nothing at all")

cfg.tipFlee = false

--[[ **A tooltip with no level passes through untouched**, which is the
     difference between decorating tooltips and taking them over. ]]--
cfg.tipLevelColor = true
GameTooltip:ClearLines()
GameTooltip:AddLine("Thunderfury")
GameTooltip:AddLine("Binds when picked up")
qol:DecorateTooltip(GameTooltip)
eq(GameTooltip:NumLines(), 2, "an item tooltip is left alone")
cfg.tipLevelColor = false

-- ---------------------------------------------------------------------------
-- the camera
-- ---------------------------------------------------------------------------

--[[ `cameraYawMoveSpeed` is how fast the camera swings when you turn it, shipped
     at 180 with no interface short of typing `/console`. Tripling it is the
     most-recommended fix in every "vanilla feels sluggish" thread, and it has
     been one line nobody could find for twenty years. ]]--
Stub.cvars.cameraYawMoveSpeed = "180"

qol:ApplyCamera()
eq(Stub.cvars.cameraYawMoveSpeed, "180", "the camera is left alone while off")

cfg.cameraSpeed = true
cfg.cameraYaw = 360
qol:ApplyCamera()
eq(Stub.cvars.cameraYawMoveSpeed, "360", "and set from the slider once on")

--[[ **Never written back on the way off.** There is no honest value to restore:
     whatever it was before might have been another addon, a `/console` line in
     somebody's notes, or the client's default, and this cannot tell those apart.
     Off means "stops changing it", not "puts it back to 180" -- guessing would
     quietly undo a setting somebody made deliberately. ]]--
cfg.cameraSpeed = false
qol:ApplyCamera()
eq(Stub.cvars.cameraYawMoveSpeed, "360",
        "switching off stops changing it rather than guessing what it was")

-- ---------------------------------------------------------------------------
-- vendors
-- ---------------------------------------------------------------------------

--[[ Two chores nobody has enjoyed: paying the repair bill, and emptying a bag of
     grey items one right-click at a time. Both entirely mechanical, both safe --
     a repair is money you owed anyway and a sale can be bought back -- and
     neither is something the client will ever do for you. ]]--
Stub.SetBag(0, {
    { name = "Broken Fang", quality = 0 },
    { name = "Tough Jerky", quality = 1 },
    { name = "Cracked Sword", quality = 0 },
})
Stub.SetBag(1, { { name = "Wolf Meat", quality = 1 } })

Stub.sold, Stub.used = {}, {}
Stub.money = 1000000
Stub.repairCost = 5000
Stub.repaired = 0
MerchantFrame:Show()

--[[ **The hazard, asserted before anything else.**

     `UseContainerItem` sells while a merchant window is open and *uses* the item
     everywhere else -- eats the food, opens the lockbox, equips the weapon. So
     the guard is not "did MERCHANT_SHOW fire", it is "is the window open right
     now", and a closed window has to produce nothing at all rather than a bag of
     used items. ]]--
MerchantFrame:Hide()
cfg.autoSell = true
eq(qol:SellJunk(), 0, "nothing is sold with the merchant window closed")
eq(table.getn(Stub.used), 0, "and nothing is used, which is the real danger")
MerchantFrame:Show()

--[[ Grey only. "Sell my whites too" is how somebody vendors their alt's gear,
     and the non-grey things worth selling are exactly the ones worth thinking
     about. ]]--
eq(qol:SellJunk(), 2, "both grey items are sold")
eq(table.getn(Stub.sold), 2, "and that is all that changed hands")

local soldJerky = false
for i = 1, table.getn(Stub.sold) do

-- ---------------------------------------------------------------------------
-- the framerate readout
-- ---------------------------------------------------------------------------

--[[ **The client has one and forgets it every login.** `ToggleFramerate` flips
     it and nothing persists the answer, so somebody who wants to see their
     framerate wants to see it *again* after every reload and reaches for the
     same key every time. ]]--
eq(cfg.showMetrics, false, "the readout is left alone by default")

FramerateFrame:Hide()
qol.metricsDone = nil
qol:OnBind()
check(not FramerateFrame:IsShown(), "so nothing is turned on")

cfg.showMetrics = true
qol.metricsDone = nil
qol:OnBind()
check(FramerateFrame:IsShown(), "switched on, it is showing after a login")

--[[ **Once per session.** `OnBind` runs again on every settings change, and a
     toggle called twice is a toggle that undid itself -- which is the whole
     hazard of an API that flips rather than sets. ]]--
qol:OnBind()
qol:OnBind()
check(FramerateFrame:IsShown(), "and a second bind does not toggle it back off")

--[[ **Read from the frame, not remembered.** Another addon may have shown it
     already, and toggling a shown display turns it off. ]]--
qol.metricsDone = nil
qol:OnBind()
check(FramerateFrame:IsShown(), "one already shown is left alone")

--[[ Turned on, never off: switching the display off by hand mid-session stays
     off, which is what somebody pressing the key is asking for. ]]--
FramerateFrame:Hide()
qol:OnBind()
check(not FramerateFrame:IsShown(), "and turning it off by hand sticks")

cfg.showMetrics = false
    if Stub.sold[i] == "Tough Jerky" then soldJerky = true end
end
check(not soldJerky, "the white item is left alone")

--[[ **Marked for this visit only**, which is a different act from deciding you
     never want it again -- that one is a setting. ]]--
Stub.sold = {}
cfg.autoSell = false

eq(qol:SellJunk(), 0, "with junk selling off, nothing goes by itself")

qol:MarkForSale("wolf meat")
eq(qol:SellJunk(), 1, "but a marked item does")
eq(Stub.sold[1], "Wolf Meat", "the one that was marked, matched without case")

--[[ And it stops being true when the window closes. "This once" is what it
     means, and a mark that outlived the visit would sell it at the next vendor
     to somebody who had forgotten. ]]--
event = "MERCHANT_CLOSED"
qol:OnEvent()
eq(qol:IsMarked("wolf meat"), false, "closing the merchant forgets the marks")

-- ---------------------------------------------------------------------------
-- repairing
-- ---------------------------------------------------------------------------

Stub.money = 1000000
Stub.repairCost = 5000
Stub.repaired = 0
cfg.autoRepair = false

eq(qol:Repair(), nil, "nothing is repaired while the switch is off")
eq(Stub.repaired, 0, "and no money moves")

cfg.autoRepair = true
local cost = qol:Repair()
eq(cost, 5000, "with it on, the bill is paid and reported")
eq(Stub.repaired, 1, "once")

--[[ **Three refusals, each a different thing being wrong**, and each said out
     loud -- a repair that silently did not happen is a repair you find out about
     when your weapon breaks. ]]--
Stub.repairCost = 400000
Stub.money = 1000000
cfg.repairLimit = 10

local _, why = qol:Repair()
check(why ~= nil and string.find(why, "limit", 1, true) ~= nil,
        "a bill over the ceiling is refused, and says so", tostring(why))
eq(Stub.repaired, 1, "and nothing is paid")

cfg.repairLimit = 0
Stub.money = 100

local _, broke = qol:Repair()
check(broke ~= nil and string.find(broke, "afford", 1, true) ~= nil,
        "so is one you cannot afford", tostring(broke))
eq(Stub.money, 100, "with your money left where it was")

Stub.money = 1000000
Stub.canRepair = false
eq(qol:Repair(), nil, "and a merchant who does not repair is simply nothing")
Stub.canRepair = true

--[[ Money reads the way the client writes it: copper is dropped once there is
     gold to say, because "12g 40s 3c" is three facts where two were wanted. ]]--
eq(OB.Money(124003), "12g 40s", "gold and silver")
eq(OB.Money(4003), "40s 3c", "silver and copper")
eq(OB.Money(37), "37c", "and copper alone")

cfg.autoRepair = false
cfg.autoSell = false
MerchantFrame:Hide()

-- ---------------------------------------------------------------------------
-- the never-keep list
-- ---------------------------------------------------------------------------

--[[ **The only thing in this addon that destroys anything.**

     Everything else here can be undone: a repair is money you owed, a sale has a
     buyback window, a camera setting is a number. A destroyed item is gone, and
     no amount of care in the code changes that -- which is why the switch is off
     and why the list lives outside the profile. ]]--
eq(cfg.autoTrash, false, "destroying things is off")
eq(OB.TrashList(), "", "and the list is empty")

Stub.SetBag(0, {
    { name = "Broken Fang", quality = 0 },
    { name = "Runecloth", quality = 1 },
    { name = "Staff of Jordan", quality = 3 },
})
Stub.destroyed = {}
Stub.cursor = nil

event = "BAG_UPDATE"
qol:OnEvent()
eq(table.getn(Stub.destroyed), 0, "so nothing is destroyed while it is off")

cfg.autoTrash = true
EquadisClassicOverhaulDB.trash = "Broken Fang"

qol:OnEvent()
eq(table.getn(Stub.destroyed), 1, "with it on, the named item goes")
eq(Stub.destroyed[1], "Broken Fang", "that one and no other")

--[[ **Whole names only, and this is the most important line here.** "Cloth" as a
     substring eats Runecloth, Mageweave and the Silk Cloth somebody is levelling
     tailoring with. The list is short and typed deliberately; matching it loosely
     to be helpful would be helpful exactly once. ]]--
Stub.destroyed = {}
EquadisClassicOverhaulDB.trash = "Cloth"

qol:OnEvent()
eq(table.getn(Stub.destroyed), 0, "a partial name matches nothing at all")
eq(qol:OnTrashList("Runecloth"), false, "Runecloth is not Cloth")
eq(qol:OnTrashList("Cloth"), true, "and Cloth is")

--[[ **A quality gate, as a guardrail rather than a preference.** The list is
     typed by hand and one slip away from naming something that took a month to
     get. Greens and above are skipped and said out loud, because silence would
     look like the list not working. ]]--
Stub.destroyed = {}
EquadisClassicOverhaulDB.trash = "Staff of Jordan"

qol:OnEvent()
eq(table.getn(Stub.destroyed), 0, "something too good to be junk is left alone")

--[[ Whites are junk enough. The gate is at common, not at grey, because plenty
     of genuinely worthless things are white. ]]--
Stub.destroyed = {}
EquadisClassicOverhaulDB.trash = "Runecloth"

qol:OnEvent()
eq(Stub.destroyed[1], "Runecloth", "a white item on the list does go")

--[[ **Not while something is being dragged.** `PickupContainerItem` onto an
     occupied cursor swaps -- it would put what the player is carrying into the
     bag and pick up the item, and the delete that follows would destroy the
     wrong thing. There is no way to ask 1.12 what is on the cursor, so the only
     safe move is to refuse. ]]--
Stub.SetBag(0, { { name = "Broken Fang", quality = 0 } })
Stub.destroyed = {}
Stub.cursor = { name = "Thunderfury", quality = 5 }
EquadisClassicOverhaulDB.trash = "Broken Fang"

qol:OnEvent()
eq(table.getn(Stub.destroyed), 0, "nothing is destroyed while the cursor is full")
check(Stub.cursor ~= nil, "and what the player is carrying is still theirs",
        tostring(Stub.cursor and Stub.cursor.name))

Stub.cursor = nil

--[[ **One item per pass.** Deleting causes a BAG_UPDATE, which comes straight
     back here with the bags in their new shape -- so the loop is the event
     rather than a `for`, and every delete acts on a slot read a moment ago
     rather than on a list assembled before anything moved. ]]--
Stub.SetBag(0, {
    { name = "Broken Fang", quality = 0 },
    { name = "Broken Fang", quality = 0 },
})
Stub.destroyed = {}

eq(qol:TrashPass(), true, "one pass destroys one item")
eq(table.getn(Stub.destroyed), 1, "not both")

eq(qol:TrashPass(), true, "the next pass takes the next")
eq(table.getn(Stub.destroyed), 2, "and now both are gone")

eq(qol:TrashPass(), false, "and a pass with nothing to do says so")

--[[ The list is account-wide and survives the reset that empties every profile.
     Silently emptying a list that destroys things is bad; silently *refilling*
     one would be worse, and a reset that dropped it would do exactly that the
     next time somebody retyped it from memory and got a name slightly wrong. ]]--
eq(OB.profile.trash, nil, "the list is not in the profile")
check(EquadisClassicOverhaulDB.trash ~= nil, "it sits beside the profiles")

cfg.autoTrash = false
EquadisClassicOverhaulDB.trash = ""
Stub.bags = {}
Stub.destroyed = {}

-- ---------------------------------------------------------------------------
-- what level a zone is for
-- ---------------------------------------------------------------------------

--[[ **The world map does not say what level anything is**, which is the one
     thing you want from it while levelling and the reason everybody has at some
     point had a browser open beside the game. ]]--
eq(cfg.zoneLevels, true, "zone level ranges are shown")

local zoneRange, zoneSide = OB.ZoneLevelText("Westfall")
eq(zoneRange, "10-20", "a zone's range comes out of the table")
eq(zoneSide, "alliance", "with the faction that owns it")

eq(OB.ZoneLevelText("Durotar"), "1-10", "and the other side's zones are there too")

--[[ The zones Turtle added are the half that could not have been written from
     memory: most of them exist nowhere else. ]]--
check(OB.ZoneLevelText("Gilneas") ~= nil, "including the ones Turtle added")

--[[ **nil for anything not in the table**, which is the right answer rather than
     a fallback: a city is not a zone with an unknown level range, it is a zone
     the question does not apply to. ]]--
eq(OB.ZoneLevelText("Stormwind City"), nil, "a city has no level range")
eq(OB.ZoneLevelText(nil), nil, "and nothing has none either")

--[[ **Appended to the label the client already writes**, rather than to a
     tooltip of its own -- no frame to make, nothing to hide when the cursor
     leaves, because the client blanks the label itself. ]]--
Stub.hoveredZone = "Westfall"
WorldMapButton_OnUpdate(0)

check(string.find(WorldMapFrameAreaLabel:GetText(), "10-20", 1, true) ~= nil,
        "the range is appended to the map label",
        WorldMapFrameAreaLabel:GetText())

check(string.find(WorldMapFrameAreaLabel:GetText(), "Westfall", 1, true) ~= nil,
        "and the zone's own name is still there")

--[[ **The client rewrites this every frame**, so without a guard the range would
     be appended sixty times a second until the string was longer than the
     screen. ]]--
local afterOne = WorldMapFrameAreaLabel:GetText()

WorldMapButton_OnUpdate(0)
WorldMapButton_OnUpdate(0)

eq(WorldMapFrameAreaLabel:GetText(), afterOne,
        "and holding the cursor still does not append it again")

--[[ Turtle ships at least one zone whose name carries a trailing space, which
     matches nothing. Trimmed at the label rather than in the table, so the table
     stays the zone names as everybody writes them. ]]--
Stub.hoveredZone = "Westfall "
WorldMapButton_OnUpdate(0)
check(string.find(WorldMapFrameAreaLabel:GetText(), "10-20", 1, true) ~= nil,
        "a trailing space in the client's name does not lose the zone")

--[[ A zone with no range is left exactly as the client drew it. ]]--
Stub.hoveredZone = "Stormwind City"
WorldMapButton_OnUpdate(0)
eq(WorldMapFrameAreaLabel:GetText(), "Stormwind City",
        "and a zone with no range is untouched")

cfg.zoneLevels = false
Stub.hoveredZone = "Westfall"
WorldMapButton_OnUpdate(0)
eq(WorldMapFrameAreaLabel:GetText(), "Westfall",
        "switched off, the label is the client's own")
cfg.zoneLevels = true

Stub.hoveredZone = nil
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- attacking by accident
-- ---------------------------------------------------------------------------

--[[ **Right-clicking a mob starts an auto-attack and 1.12 has no setting for
     it.** It is the commonest way to pull something you were not ready for: you
     right-click to turn the camera, the cursor crosses a mob, and you are in
     combat. A rogue loses stealth and everybody loses the pull. ]]--
eq(cfg.noRightClickAttack, false, "the client's behaviour is left alone by default")

Stub.cvars.AutoInteract = "1"
eq(qol:ApplyRightClick(), false, "so the CVar is not touched")
eq(Stub.cvars.AutoInteract, "1", "and keeps whatever it had")

cfg.noRightClickAttack = true
eq(qol:ApplyRightClick(), true, "switching it on writes the CVar")
eq(Stub.cvars.AutoInteract, "0", "which is what stops the interaction")

--[[ **Never written back on the way off**, for the reason the camera setting
     gives: whatever it was before might be another addon or a line in somebody's
     notes, and this cannot tell those apart. ]]--
cfg.noRightClickAttack = false
qol:ApplyRightClick()
eq(Stub.cvars.AutoInteract, "0",
        "switching it off stops changing it rather than guessing")

cfg.noRightClickAttack = true

--[[ **The half a CVar cannot cover: an attack that started anyway.**

     Some builds still reach auto-attack through a different path. The client
     announces every swing start, so an attack that began while nothing asked for
     one is stopped. `AttackTarget` toggles -- there is no separate stop call --
     which is why cancelling means calling it again. ]]--
qol.attackWatchInstalled = nil
qol:InstallAttackWatch()

qol.attackWanted = nil
Stub.attackCalls = 0

eq(qol:OnAttackStarted(), true, "an attack nobody asked for is stopped")
eq(Stub.attackCalls, 1, "by calling the toggle again")

--[[ **And the ones you meant are kept**, which is the whole difficulty. Stopping
     every auto-attack would be useless. A button press and a macro both set the
     flag; a right-click reaches the client's C code and sets nothing, and that
     absence is the signal. ]]--
Stub.attackCalls = 0
AttackTarget()

eq(qol.attackWanted, true, "asking for an attack is recorded")
eq(qol:OnAttackStarted(), false, "so it is left alone")

--[[ The flag is set before the call, because the client can raise the combat
     event synchronously inside it -- set afterwards it would arrive too late to
     protect the attack that set it. ]]--
qol.attackWanted = nil

cfg.noRightClickAttack = false
eq(qol:OnAttackStarted(), false, "and with the switch off, nothing is stopped")

Stub.attacking = false
Stub.attackCalls = 0

-- ---------------------------------------------------------------------------
-- mounts
-- ---------------------------------------------------------------------------

--[[ **1.12 has no `Dismount()`.** A mount is a buff and you get off it by
     cancelling the buff -- which means finding it, and a 1.12 buff has no id and
     no reliable name, only an icon path. Every buff test in this addon is a
     texture comparison for that reason. ]]--
local MOUNT = "Interface\\Icons\\Ability_Mount_JungleTiger"

Stub.player.buffs = { "Interface\\Icons\\Spell_Holy_PowerWordShield" }
eq(qol:Mounted(), false, "a buff that is not a mount is not a mount")

Stub.player.buffs = { "Interface\\Icons\\Spell_Holy_PowerWordShield", MOUNT }
eq(qol:Mounted(), true, "and one that is, is")

local index, texture = qol:MountBuff()
eq(index, 1, "found at its own index, which is what cancelling needs")
eq(texture, MOUNT, "with the icon that identifies it")

--[[ Off by default, and off means the cast goes out untouched -- which is
     exactly what happens today, refusal and all. ]]--
eq(cfg.dismount, false, "dismounting to cast is off")
eq(qol:ShouldDismount(nil), false, "so nothing dismounts you")

cfg.dismount = true
eq(qol:ShouldDismount(nil), true, "with it on, a cast gets you off first")

--[[ **Except the mount itself.** Pressing your mount while mounted is already
     how you get off; intercepting it would cancel the buff and then re-cast the
     mount, leaving you where you started and a global cooldown poorer.

     Told apart by icon, which is the only identity available -- and they are the
     same art, which is what makes it work at all. ]]--
eq(qol:ShouldDismount(MOUNT), false, "pressing the mount is left to the client")
eq(qol:ShouldDismount("Interface\\Icons\\Ability_Rogue_Sinistercalling"), true,
        "while a spell still dismounts you")

--[[ The cancel really happens, and really takes the buff off. Asserting the call
     alone would pass for code that cancelled the wrong index. ]]--
eq(qol:Dismount(), true, "dismounting works")
eq(qol:Mounted(), false, "and you are off")
eq(table.getn(Stub.player.buffs), 1, "with your other buff untouched")
eq(Stub.player.buffs[1], "Interface\\Icons\\Spell_Holy_PowerWordShield",
        "and it is the right one")

eq(qol:Dismount(), false, "dismounting when you are not mounted does nothing")

--[[ **The fallback, which exists because of a hole this addon already found.**

     `range.lua` wrote it down: replacing the global `UseAction` only catches a
     press if every bar addon in the chain still calls the global at press time.
     One that took its own reference at load never reaches ours, and nothing can
     be done about that from here.

     So the client's own refusal is watched as well. It cannot save the first
     press, but it means the second one works rather than repeating the refusal. ]]--
Stub.player.buffs = { MOUNT }

eq(qol:OnCastRefused("Your target is out of range."), false,
        "an unrelated refusal is not one of ours")
eq(qol:Mounted(), true, "and leaves you on your mount")

eq(qol:OnCastRefused("You are mounted."), true, "the mounted refusal is")
eq(qol:Mounted(), false, "so the next press will work")

--[[ **`IsMounted` wins where it exists.** It is a 2.0 call, absent from a plain
     1.12 client and backported by several private-server ones, and a real answer
     beats a good heuristic every time.

     The stub leaves it undefined on purpose -- always providing it would leave
     the texture path, which is what most people will run, never once executed. ]]--
Stub.player.buffs = {}
IsMounted = function() return true end
eq(qol:Mounted(), true, "the real call is believed over the icon scan")

IsMounted = nil
eq(qol:Mounted(), false, "and without it, no mount buff means not mounted")

cfg.dismount = false
Stub.player.buffs = {}

-- ---------------------------------------------------------------------------
-- trash mode
-- ---------------------------------------------------------------------------

--[[ **Choose several things, then deal with all of them at once.** The chore
     this replaces is a bag full of leftovers after a dungeon, cleared one
     right-click-delete-confirm at a time.

     Kept entirely separate from the never-keep list, which is automatic and
     guarded to the point of paranoia. This is not automatic: everything in the
     selection is there because somebody clicked it, and the friction that
     belongs on an automatic list is noise on a deliberate one. ]]--
Stub.SetBag(0, {
    { name = "Broken Fang", quality = 0 },
    { name = "Tattered Cloak", quality = 0 },
    { name = "Staff of Jordan", quality = 3 },
})
Stub.destroyed = {}
Stub.cursor = nil

eq(qol:SelectMode(), false, "trash mode is off")
eq(table.getn(qol:SelectedItems()), 0, "and nothing is chosen")

qol:SetSelectMode(true)
eq(qol:SelectMode(), true, "it turns on")

eq(qol:ToggleSlot(0, 1), true, "a slot with something in it can be chosen")
eq(qol:SlotSelected(0, 1), true, "and is")
eq(qol:ToggleSlot(0, 1), true, "clicking it again")
eq(qol:SlotSelected(0, 1), false, "unchooses it")

eq(qol:ToggleSlot(0, 4), false, "an empty slot cannot be chosen")

qol:ToggleSlot(0, 1)
qol:ToggleSlot(0, 2)
eq(table.getn(qol:SelectedItems()), 2, "two things are chosen")

--[[ In bag order rather than table order. `pairs` would answer in whatever
     order it felt like, and a confirmation naming things differently every time
     is harder to read than one that names them in the order they sit in. ]]--
local chosen = qol:SelectedItems()
eq(chosen[1].name, "Broken Fang", "listed in the order they sit in")
eq(chosen[2].name, "Tattered Cloak", "not in whatever order the table felt like")

--[[ **Backwards through the list**, which is why this is written out rather than
     reusing the never-keep sweep. Removing an item shifts every slot after it up
     one; forwards would leave every remaining reference pointing one slot too
     far along. Backwards, the shifted slots are the ones already dealt with. ]]--
eq(qol:DestroySelected(), 2, "both are destroyed")
eq(table.getn(Stub.destroyed), 2, "and both really went")

local wentFang, wentCloak = false, false
for i = 1, table.getn(Stub.destroyed) do
    if Stub.destroyed[i] == "Broken Fang" then wentFang = true end
    if Stub.destroyed[i] == "Tattered Cloak" then wentCloak = true end
end
check(wentFang and wentCloak, "the two that were chosen, not two others",
        table.concat(Stub.destroyed, ", "))

eq(table.getn(qol:SelectedItems()), 0, "and the selection is emptied after")

--[[ **A deliberate choice is allowed to be deliberate.** Unlike the automatic
     list, a green is not refused here -- it is *named*, so the confirmation says
     what is about to happen rather than quietly doing less than asked. ]]--
Stub.SetBag(0, {
    { name = "Broken Fang", quality = 0 },
    { name = "Staff of Jordan", quality = 3 },
})
Stub.destroyed = {}

qol:ToggleSlot(0, 1)
qol:ToggleSlot(0, 2)

local valuable = qol:ValuableInSelection()
eq(table.getn(valuable), 1, "the good item is picked out to be named")
eq(valuable[1], "Staff of Jordan", "by name")

--[[ Or hand them to a vendor instead, which is the better answer whenever the
     vendor will take them -- written into the same marks `/eqob sell` uses, so
     there is one idea of "sell these now" rather than two. ]]--
Stub.sold = {}
MerchantFrame:Show()

eq(qol:SellSelected(), 2, "both are sold instead")
eq(table.getn(Stub.destroyed), 0, "and nothing was destroyed")
eq(table.getn(qol:SelectedItems()), 0, "the selection is emptied after that too")

MerchantFrame:Hide()

--[[ Turning the mode off forgets what was chosen. A selection that survived the
     mode would be waiting, invisible, for the next time somebody turned it on. ]]--
qol:ToggleSlot(0, 1)
qol:SetSelectMode(false)
eq(table.getn(qol:SelectedItems()), 0, "leaving the mode forgets the selection")

Stub.bags = {}
Stub.destroyed = {}
Stub.sold = {}

-- ---------------------------------------------------------------------------
-- cheap junk
-- ---------------------------------------------------------------------------

--[[ **The rule is simple; the value is the hard part.**

     "Grey, worth less than this, gone" is exactly right and exactly what people
     ask for. But 1.12 has no call that answers what an item sells for, and
     prints it in one place only -- an item's tooltip, while a merchant window is
     open. The price of the grey in your bag is unknowable in the cave where you
     want to know it.

     So the store learns. A vendor price seen once is true forever, and it is
     account-wide, which turns "only at a vendor" into "at a vendor, once, ever". ]]--
Stub.SetBag(0, {
    { name = "Broken Fang", quality = 0, price = 250 },
    { name = "Chipped Claw", quality = 0, price = 4000 },
    { name = "Linen Cloth", quality = 1, price = 100 },
})
Stub.destroyed = {}
EquadisClassicOverhaulDB.prices = {}
OB.prices = EquadisClassicOverhaulDB.prices
MerchantFrame:Hide()

cfg.trashJunk = true
cfg.junkValue = 5

--[[ **Not knowing is a refusal, not a zero.** Away from a vendor nothing has a
     price yet, and guessing at the value of something before destroying it is
     the one thing this must never do. ]]--
eq(OB.SellValue("Broken Fang", 0, 1), nil, "away from a vendor, nothing is known")
eq(qol:IsCheapJunk("Broken Fang", 0, 1), false, "so nothing is cheap enough to go")

event = "BAG_UPDATE"
qol:OnEvent()
eq(table.getn(Stub.destroyed), 0, "and nothing is destroyed")

--[[ At a vendor the client prints it -- into a money frame rather than into
     text, which is why the stub models the frame. A scraper that only read lines
     would find nothing in the real client. ]]--
MerchantFrame:Show()
eq(OB.SellValue("Broken Fang", 0, 1), 250, "at a vendor the price is readable")

--[[ And it is remembered, which is the whole point. ]]--
MerchantFrame:Hide()
eq(OB.prices["Broken Fang"], 250, "learned once")
eq(OB.SellValue("Broken Fang", 0, 1), 250, "and known from then on, anywhere")

qol:OnEvent()
eq(Stub.destroyed[1], "Broken Fang", "so now it goes")

--[[ Above the threshold it stays, which is the other half of the rule. ]]--
Stub.destroyed = {}
MerchantFrame:Show()
OB.SellValue("Chipped Claw", 0, 2)
MerchantFrame:Hide()

eq(OB.prices["Chipped Claw"], 4000, "a more valuable grey is learned too")
eq(qol:IsCheapJunk("Chipped Claw", 0, 2), false, "and is not cheap junk")

--[[ Nor is anything that is not grey, whatever it is worth. Quality is the first
     gate and value is the second. ]]--
eq(qol:IsCheapJunk("Linen Cloth", 0, 3), false, "a white item is never cheap junk")

--[[ **Per item, not per stack.** The client prints the price for everything in
     the slot, so a stack of twenty cheap greys would read as one valuable item
     and be kept. The threshold is about the thing rather than how many of it you
     happen to be carrying. ]]--
EquadisClassicOverhaulDB.prices = {}
OB.prices = EquadisClassicOverhaulDB.prices
Stub.SetBag(0, { { name = "Small Scale", quality = 0, price = 30, count = 20 } })
MerchantFrame:Show()

eq(OB.SellValue("Small Scale", 0, 1), 30, "a stack is divided back down to one")
MerchantFrame:Hide()
eq(qol:IsCheapJunk("Small Scale", 0, 1), true, "so the stack is still junk")

--[[ **`GetSellValue` wins where it exists.** It is the community's de-facto
     standard -- Auctioneer defines it and every vendor-value addon since has
     either defined it or been built against something that does -- and a real
     answer costs one call instead of a tooltip. ]]--
EquadisClassicOverhaulDB.prices = {}
OB.prices = EquadisClassicOverhaulDB.prices
Stub.SetBag(0, { { name = "Cracked Egg", quality = 0, price = 700 } })

GetSellValue = function(link) return 111 end
eq(OB.SellValue("Cracked Egg", 0, 1), 111, "the addon's answer is taken")
GetSellValue = nil

--[[ And the text form, for the ones that add a line rather than a money frame.
     Both exist in the wild, so both are read. ]]--
EquadisClassicOverhaulDB.prices = {}
OB.prices = EquadisClassicOverhaulDB.prices
Stub.SetBag(0, { { name = "Torn Hide", quality = 0, price = 320, priceAsText = true } })
MerchantFrame:Show()

eq(OB.SellValue("Torn Hide", 0, 1), 320, "a written sell price is read too")
MerchantFrame:Hide()

--[[ The two ways in are separate switches. Somebody may want their Broken Fangs
     gone and every other grey kept, or the reverse. ]]--
cfg.trashJunk = false
cfg.autoTrash = false
eq(qol:TrashPass(), false, "with both off, the sweep does nothing")

cfg.trashJunk = false
EquadisClassicOverhaulDB.prices = {}
Stub.bags = {}
Stub.destroyed = {}

-- ---------------------------------------------------------------------------
-- quests
-- ---------------------------------------------------------------------------

--[[ **Handing in a quest you have already read**, from QuestHaste by WobLight.

     The design is the good part and it is kept: **it is per quest**. The obvious
     version of this accepts and hands in everything, and that is the version
     that makes you miss the one quest you had not read. Opt-in, one at a time,
     and the thing it is really for -- an Alterac Valley turn-in read forty times
     -- is on the list after the first Ctrl-click. ]]--
EquadisClassicOverhaulDB.quests = {}
OB.quests = EquadisClassicOverhaulDB.quests

Stub.questCalls = {}
Stub.quest = { title = "Kill Ten Rats", completable = true, choices = 0 }
Stub.shiftDown, Stub.ctrlDown, Stub.altDown = false, false, false

eq(cfg.questHaste, false, "quest handling is off")

event = "QUEST_DETAIL"
qol:OnEvent()
eq(table.getn(Stub.questCalls), 0, "so a quest window is left alone")

cfg.questHaste = true

--[[ Nothing remembered, no modifier: nothing happens. This is the whole safety
     of the design -- a quest you have not opted into behaves exactly as it does
     with the addon switched off. ]]--
qol:OnEvent()
eq(table.getn(Stub.questCalls), 0, "an unremembered quest is still left alone")

--[[ **Ctrl remembers and proceeds**, which is how a quest gets on the list: you
     are already looking at it. ]]--
Stub.ctrlDown = true
qol:OnEvent()
Stub.ctrlDown = false

eq(Stub.questCalls[1], "accept", "Ctrl accepts it")
eq(OB.quests["Kill Ten Rats"].accept, true, "and remembers it for next time")

Stub.questCalls = {}
qol:OnEvent()
eq(Stub.questCalls[1], "accept", "so next time it goes by itself")

--[[ **Shift inverts**, which is one key doing two useful things: pushing an
     unremembered quest through, and holding a remembered one while you read it. ]]--
Stub.questCalls = {}
Stub.shiftDown = true
qol:OnEvent()
Stub.shiftDown = false
eq(table.getn(Stub.questCalls), 0, "Shift holds a remembered quest")

Stub.quest.title = "A Quest Nobody Saved"
Stub.questCalls = {}
Stub.shiftDown = true
qol:OnEvent()
Stub.shiftDown = false
eq(Stub.questCalls[1], "accept", "and pushes an unremembered one through")
eq(OB.quests["A Quest Nobody Saved"], nil, "without remembering it")

--[[ Alt forgets, and forgets one half rather than the entry. A quest you
     auto-accept but want to read the reward text for is a real thing, and
     dropping the whole entry would quietly undo the other half. ]]--
OB.quests["Kill Ten Rats"] = { accept = true, complete = true }
Stub.quest.title = "Kill Ten Rats"
Stub.questCalls = {}

Stub.altDown = true
qol:OnEvent()
Stub.altDown = false

eq(OB.quests["Kill Ten Rats"].accept, nil, "Alt forgets the half it is shown")
eq(OB.quests["Kill Ten Rats"].complete, true, "and leaves the other half alone")
eq(table.getn(Stub.questCalls), 0, "and does nothing else")

-- ---------------------------------------------------------------------------
-- the reward window
-- ---------------------------------------------------------------------------

--[[ **Never when there is a choice of reward.** `GetQuestReward` takes an index,
     and picking for somebody is picking wrong -- the whole point of a choice is
     that only they know which. So a quest with rewards to choose between stops
     and waits, however firmly it is on the list.

     Not a setting. There is no version of "pick a reward for me" that is a good
     idea, and offering it would be offering a way to lose an item. ]]--
OB.quests["Kill Ten Rats"] = { accept = true, complete = true }
Stub.questCalls = {}
Stub.quest.choices = 0

event = "QUEST_COMPLETE"
qol:OnEvent()
eq(Stub.questCalls[1], "reward", "a quest with one reward is taken")

Stub.questCalls = {}
Stub.quest.choices = 3
qol:OnEvent()
eq(table.getn(Stub.questCalls), 0, "a quest with a choice of rewards is not")

Stub.quest.choices = 0

--[[ And the middle window only presses on when the items are there. Pressing
     otherwise asks the client to do something it will refuse. ]]--
Stub.questCalls = {}
Stub.quest.completable = false
event = "QUEST_PROGRESS"
qol:OnEvent()
eq(table.getn(Stub.questCalls), 0, "an incomplete quest is not handed in")

Stub.quest.completable = true
qol:OnEvent()
eq(Stub.questCalls[1], "complete", "and a complete one is")

-- ---------------------------------------------------------------------------
-- an NPC with several quests
-- ---------------------------------------------------------------------------

--[[ **Shift rather than automatic**, and this is deliberate: a gossip menu is
     also how you reach a flight master, a bank and a trainer, and an addon that
     jumped to a quest every time you opened one would be taking the menu away. ]]--
Stub.gossipAvailable = { "Scrap Metal", "Ram Riding Harnesses" }
Stub.gossipActive = { "Kill Ten Rats" }
Stub.gossipPicked = nil

event = "GOSSIP_SHOW"
qol:OnEvent()
eq(Stub.gossipPicked, nil, "without Shift the menu is left as it is")

Stub.shiftDown = true
qol:OnEvent()
Stub.shiftDown = false

--[[ Available before active: taking a repeatable is what starts the loop, and
     "Kill Ten Rats" is the one on the list. ]]--
check(Stub.gossipPicked ~= nil, "with Shift, a quest is chosen")
eq(Stub.gossipPicked.kind, "active", "the remembered one, whichever list it is in")
eq(Stub.gossipPicked.index, 1, "by its position in that list")

--[[ Nothing remembered means nothing chosen, so Shift on a menu of quests you
     have never seen still just opens the menu. ]]--
OB.quests = {}
EquadisClassicOverhaulDB.quests = OB.quests
Stub.gossipPicked = nil

Stub.shiftDown = true
qol:OnEvent()
Stub.shiftDown = false
eq(Stub.gossipPicked, nil, "a menu of unremembered quests is left alone")

--[[ **1.12 answers a gossip list as one flat run of title, level, title, level.**
     Pulling the titles back out of that is the part that can be got wrong, and
     getting it wrong silently picks a level number as a quest name. ]]--
OB.quests = { ["Ram Riding Harnesses"] = { accept = true } }
EquadisClassicOverhaulDB.quests = OB.quests
Stub.gossipPicked = nil

Stub.shiftDown = true
qol:OnEvent()
Stub.shiftDown = false

eq(Stub.gossipPicked.kind, "available", "the second available quest is found")
eq(Stub.gossipPicked.index, 2, "at its own index, not at twice it")

--[[ "Every quest" is the repeatables machine, and it should stay off for anyone
     levelling: the first read of a quest is the only chance to notice it is the
     wrong one. ]]--
OB.quests = {}
EquadisClassicOverhaulDB.quests = OB.quests
Stub.quest.title = "Something Brand New"
Stub.questCalls = {}

event = "QUEST_DETAIL"
qol:OnEvent()
eq(table.getn(Stub.questCalls), 0, "a new quest is not accepted")

cfg.questAll = true
qol:OnEvent()
eq(Stub.questCalls[1], "accept", "unless every quest is switched on")
cfg.questAll = false

cfg.questHaste = false
Stub.questCalls = {}
Stub.gossipAvailable, Stub.gossipActive = {}, {}

end

qolTests()

-- 41. action bars
--
-- Ported from DragonflightUI-Reforged's Bars module. Blizzard's 1.12 bars are
-- one fixed arrangement of real, named, movable frames -- what cannot be done
-- is any of it from an interface, because there is none. That is the gap, and
-- it is why the port is mostly arithmetic.
-- ---------------------------------------------------------------------------

function actionBarTests()

context = "action bars: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local bars = OB.modules.actionbars
check(bars ~= nil, "the action bar module registers")
eq(bars.renders, "none", "and draws nothing of its own")

--[[ Off. It moves and re-parents Blizzard's frames, which is the loudest thing
     in this addon after destroying an item -- and next to any other action bar
     addon it is a fight rather than a feature. ]]--
eq(OB.ModuleEnabled("actionbars"), false, "and ships switched off")

OB.profile.modulesEnabled.actionbars = true
OB.BindSlots()

local cfg = OB.profile.modules.actionbars

-- ---------------------------------------------------------------------------
-- where a button goes
-- ---------------------------------------------------------------------------

--[[ **Left to right, then top to bottom**, which is the order the keybinds are
     in and therefore the only order that does not surprise anybody. ]]--
local wide = { rows = 1, cols = 12 }

local bx, by = bars:ButtonOffset(1, wide, 6)
eq(bx, 0, "the first button is at the origin")
eq(by, 0, "on both axes")

bx, by = bars:ButtonOffset(2, wide, 6)
eq(bx, 42, "the second is one button and one gap along")
eq(by, 0, "still on the first row")

--[[ **The Y is negative**, because a bar grows downwards from its anchor. Button
     seven of a six-wide layout sits under button one rather than over it, and
     getting the sign wrong builds the bar upwards through whatever is there. ]]--
local twoRows = { rows = 2, cols = 6 }

bx, by = bars:ButtonOffset(7, twoRows, 6)
eq(bx, 0, "the seventh button of a six-wide bar starts the next row")
eq(by, -42, "below the first, not above it")

bx, by = bars:ButtonOffset(12, twoRows, 6)
eq(bx, 210, "and the last one ends it")
eq(by, -42, "on that row")

--[[ Spacing is added to the button rather than between them, which makes the
     arithmetic one multiplication instead of a special case for the first. ]]--
bx = bars:ButtonOffset(2, wide, 0)
eq(bx, 36, "with no spacing, buttons touch")

-- ---------------------------------------------------------------------------
-- laying out a family
-- ---------------------------------------------------------------------------

anchorFrame = CreateFrame("Frame", nil, nil)

eq(bars:LayoutFamily("ActionButton", 12, anchorFrame, 1, 6, 1, 1), 12,
        "all twelve main bar buttons are placed")

--[[ **The scale and the fade land on the container, not on the buttons.**

     They are its children now, so they inherit both -- and putting them there is
     what makes the container's box the bar's box: sized in unscaled button
     units, drawn at whatever scale was asked for. `StorePosition` divides by the
     container's scale and only makes sense that way round, so a bar at 0.8 with
     the scale on the buttons remembered a position measured against a box a
     quarter too wide. ]]--
bars:LayoutFamily("ActionButton", 12, anchorFrame, 1, 6, 0.8, 0.5)
eq(anchorFrame.scale, 0.8, "the container takes the scale")
eq(anchorFrame.alpha, 0.5, "and the opacity")
eq(getglobal("ActionButton1").scale, 1, "while a button stays at one")
eq(getglobal("ActionButton1").alpha, 1, "on both")

--[[ **The container is sized to what it holds**, so anything anchored above it
     lands above the buttons rather than above where twelve of them would have
     been. A druid's four stances are not ten. ]]--
bars:LayoutFamily("ActionButton", 12, anchorFrame, 1, 6, 1, 1)
eq(anchorFrame.width, (12 * 42) - 6, "a full row is twelve buttons wide")
eq(anchorFrame.height, 36, "and one button tall")

bars:LayoutFamily("ActionButton", 12, anchorFrame, 2, 6, 1, 1)
eq(anchorFrame.width, (6 * 42) - 6, "two rows of six is half as wide")
eq(anchorFrame.height, (2 * 42) - 6, "and twice as tall")

--[[ Ten buttons, not twelve. The pet and stance bars are shorter, and a layout
     that assumed twelve would size their container for two that do not exist. ]]--
petFrame = CreateFrame("Frame", nil, nil)
eq(bars:LayoutFamily("PetActionButton", 10, petFrame, 1, 6, 1, 1), 10,
        "the pet bar has ten buttons")

-- ---------------------------------------------------------------------------
-- keybind text
-- ---------------------------------------------------------------------------

--[[ **The single most useful thing in the port.** 1.12 writes SHIFT-BUTTON4
     across the corner of a 36 pixel icon in a font nobody can read, so everybody
     leaves keybind text on and nobody reads it. ]]--
eq(bars:ShortenKey("SHIFT-BUTTON4"), "sM4", "a modifier and a mouse button fit")
eq(bars:ShortenKey("CTRL-1"), "c1", "so does a modified number")
eq(bars:ShortenKey("ALT-F"), "aF", "and a modified letter")
eq(bars:ShortenKey("MOUSEWHEELUP"), "MwU", "the wheel gets initials")
eq(bars:ShortenKey("NUMPAD7"), "N7", "and so does the numpad")
eq(bars:ShortenKey(nil), "", "nothing shortens to nothing")

--[[ Blizzard's own font strings are restyled rather than replaced. The client
     rewrites its string whenever a binding changes, so a replacement would have
     to notice that and copy it across; restyling means the client goes on
     maintaining the text and this only decides how it looks. ]]--
Stub.bindings["ACTIONBUTTON1"] = "SHIFT-BUTTON4"

cfg.hotkeySize = 14
bars:ApplyText()

hotkeyText = getglobal("ActionButton1HotKey")
local _, hotkeySize = hotkeyText:GetFont()
eq(hotkeySize, 14, "the keybind takes the font size from the setting")
eq(hotkeyText:GetText(), "sM4", "and is rewritten short")

cfg.showHotkeys = false
bars:ApplyText()
eq(hotkeyText.shown, false, "switching it off hides it")

cfg.showHotkeys = true
bars:ApplyText()
eq(hotkeyText.shown, true, "and switching it back shows it again")

-- ---------------------------------------------------------------------------
-- Blizzard's art
-- ---------------------------------------------------------------------------

eq(cfg.hideArt, true, "the bar art is hidden by default")

bars:StyleArt()
eq(getglobal("MainMenuBarLeftEndCap").shown, false, "so the end caps go")

--[[ **A missing texture is not a reason to abandon the layout.** The set differs
     between 1.12 builds and a private server may have removed or renamed one, so
     every lookup is guarded -- an unguarded SetTexture on a client that lacks it
     takes the module down on login, which is the failure that looks like the
     whole addon being broken.

     Asserted by taking one away, which is exactly what a client mod does. ]]--
keptTexture = _G["SlidingActionBarTexture0"]
_G["SlidingActionBarTexture0"] = nil

bars:StyleArt()
eq(getglobal("MainMenuBarRightEndCap").shown, false,
        "with one texture missing, the rest are still hidden")

_G["SlidingActionBarTexture0"] = keptTexture

-- ---------------------------------------------------------------------------
-- whose child a button is
-- ---------------------------------------------------------------------------

--[[ **`SetPoint` is not enough, and the difference is everything this module
     does.**

     Every action button is a child of one of Blizzard's bar frames, and a child
     inherits its parent's visibility, alpha and scale. Anchoring a button to a
     container of ours while leaving it parented to `MainMenuBarArtFrame` means
     the client can still hide it, fade it and -- through
     `UIPARENT_MANAGED_FRAME_POSITIONS` -- move the frame it is measured
     against.

     The port's own comment said the containers exist so that argument never
     happens. The code only ever called `SetPoint`, so it happened every
     time. ]]--
bars:ApplyBars()

eq(getglobal("ActionButton1"):GetParent(), bars.anchors["Main"],
        "a laid-out button is re-parented to its container")
eq(getglobal("PetActionButton1"):GetParent(), bars.anchors["Pet"],
        "and so is a pet button")

--[[ **Which is what makes hiding the art safe.** `PetActionBarFrame` is both the
     art behind the pet bar and the parent of all ten pet buttons: hiding it
     without re-parenting first takes the buttons with it, and the bug reads as
     "the pet bar disappeared when I turned the module on". ]]--
cfg.hideArt = true
bars:Apply()

check(getglobal("PetActionButton1"):IsVisible(),
        "hiding the pet bar art leaves the pet buttons visible")
check(getglobal("ActionButton1"):IsVisible(),
        "and the main bar's buttons too")


--[[ **Whether a bar is shown at all stays the client's decision.**

     It used to be one for free: the buttons were Blizzard's children, so hiding
     `MultiBarBottomLeft` hid its twelve buttons. Re-parenting them onto a
     container of ours takes that away -- so the container copies the frame the
     buttons came off.

     **The frame, not a rule of our own.** "The four multibar CVars, plus does
     the player have a pet, plus how many forms" is a list that is wrong on a
     private server and right nowhere for long. The client already knows, and it
     says so by showing or hiding exactly these eight frames. ]]--
getglobal("MultiBarBottomLeft"):Hide()
bars:ApplyBars()

check(not getglobal("MultiBarBottomLeftButton1"):IsVisible(),
        "a bar the client has switched off stays off after re-parenting")
check(getglobal("ActionButton1"):IsVisible(), "while the main bar is unaffected")

getglobal("MultiBarBottomLeft"):Show()
bars:ApplyBars()
check(getglobal("MultiBarBottomLeftButton1"):IsVisible(), "and comes back with it")

--[[ The pet bar is the same question asked a different way: no pet means the
     client hides `PetActionBarFrame`, which is why that frame is not in the art
     list -- hiding it for its background would answer "no pet" forever. ]]--
getglobal("PetActionBarFrame"):Hide()
bars:Apply()
check(not getglobal("PetActionButton1"):IsVisible(), "no pet, no pet bar")

getglobal("PetActionBarFrame"):Show()
bars:Apply()
check(getglobal("PetActionButton1"):IsVisible(),
        "and the art pass has not quietly hidden it again")
--[[ **The art comes back when the switch goes off.**

     It was hidden with `SetTexture(nil)`, which cannot be undone -- the path is
     gone and this addon never knew it. So the region is hidden and faded
     instead, both of which reverse, and the switch works in both directions
     rather than only until the next reload. Constraint 88. ]]--
cfg.hideArt = false
bars:Apply()

eq(getglobal("MainMenuBarLeftEndCap").shown, true, "the end caps come back")
check(getglobal("MainMenuBarLeftEndCap").texture ~= nil,
        "with their texture still on them")

cfg.hideArt = true
bars:Apply()
eq(getglobal("MainMenuBarLeftEndCap").shown, false, "and go again")

-- ---------------------------------------------------------------------------
-- the client rewriting the keybind text
-- ---------------------------------------------------------------------------

--[[ **`ActionButton_UpdateHotkeys` writes the binding out in full**, and it runs
     every time a spell is dragged onto a bar, every time a binding changes, and
     on entering the world. Shortening the text once and stopping there means it
     is long again after the next spell drag.

     Same problem as the unit frame strings, same answer: replace the client's
     function once, read the settings inside, and delegate for any button that is
     not ours. Constraint 86. ]]--
Stub.buttonCommand = { ActionButton1 = "ACTIONBUTTON1" }
Stub.bindings["ACTIONBUTTON1"] = "SHIFT-BUTTON4"

cfg.showHotkeys = true
bars:ApplyText()
eq(getglobal("ActionButton1HotKey"):GetText(), "sM4", "the short form is written")

--[[ The client's own pass, which is the thing that used to undo it. ]]--
ActionButton_UpdateHotkeys(getglobal("ActionButton1"))
eq(getglobal("ActionButton1HotKey"):GetText(), "sM4",
        "and survives the client rewriting the same string")

--[[ Off, and the client's own text is what is there -- a switched-off setting
     has to look like this module not existing. ]]--
cfg.showHotkeys = false
ActionButton_UpdateHotkeys(getglobal("ActionButton1"))
eq(getglobal("ActionButton1HotKey"):GetText(), "SHIFT-BUTTON4",
        "with the setting off, the client's own text stands")
cfg.showHotkeys = true

-- ---------------------------------------------------------------------------
-- moving the bars
-- ---------------------------------------------------------------------------

--[[ **This threw the moment anybody pressed the button.**

     `BARS` was declared at the bottom of the file and walked by two functions
     defined above it, so both saw a nil global. `local` is not hoisted. Shipped
     in v0.57.0 with no test that ever called either one, which is the whole
     reason it got out. ]]--
eq(bars:DragMode(), false, "drag mode ships off")

bars:SetDragMode(true)
eq(bars:DragMode(), true, "and switches on without throwing")
check(bars.anchors["Main"]:IsMovable(), "which makes the containers movable")
check(bars.anchors["Main"].dragHint:IsShown(),
        "and shows something to aim at -- an invisible frame is not grabbable")

bars:SetDragMode(false)
eq(bars:DragMode(), false, "off again")
check(not bars.anchors["Main"]:IsMovable(), "and the containers are left alone")
check(not bars.anchors["Main"].dragHint:IsShown(), "with the hint gone")

--[[ A position is stored as an offset from the centre of the screen, which is
     the rule the meters follow: measured from an edge it is a different place on
     a different resolution. ]]--
bars.anchors["Main"]:ClearAllPoints()
bars.anchors["Main"]:SetPoint("CENTER", UIParent, "CENTER", -216, -300)

bars:StorePosition({ key = "main", name = "Main" }, bars.anchors["Main"])
check(cfg.positions["main"] ~= nil, "a dragged bar remembers where it went")

--[[ **The bonus bar shares the main bar's key**, because they are two button
     families in one rectangle: a druid in form is looking at the same place on
     screen, and keying them apart meant a dragged bar sprang back to the default
     the moment they shifted. ]]--
bars:ApplyBars()
GLOBAL_p, GLOBAL_rel, GLOBAL_relPoint, GLOBAL_bx, GLOBAL_by =
        bars.anchors["Bonus"]:GetPoint()
eq(GLOBAL_bx, -216, "and the bonus bar follows it")
eq(GLOBAL_by, -300, "on both axes")

--[[ And is put back there on the next styling pass rather than only at login,
     which is otherwise where a dragged position quietly reverts. ]]--
bars:ApplyBars()
GLOBAL_p, GLOBAL_rel, GLOBAL_relPoint = bars.anchors["Main"]:GetPoint()
eq(GLOBAL_relPoint, "CENTER", "and is placed from the centre afterwards")

bars:ResetPositions()
eq(next(cfg.positions), nil, "reset forgets rather than choosing a new place")

-- ---------------------------------------------------------------------------
-- bind mode
-- ---------------------------------------------------------------------------

--[[ **Hover a button, press a key, that is the binding.**

     The client's own binding interface is two hundred command names with a box
     beside each, and finding "the third button on my bottom right bar" in it
     means counting. Nobody does it twice. ]]--
Stub.bindings, Stub.boundTo = {}, {}
Stub.bindingsSaved, Stub.windowsClosed = 0, false
Stub.shiftDown, Stub.ctrlDown, Stub.altDown = false, false, false

eq(bars:BindMode(), false, "bind mode is off")

--[[ The command a frame answers to, anchored at both ends. "ActionButton1" is a
     prefix of "ActionButton12", and a loose match would bind the wrong slot on
     every second button. ]]--
eq(bars:CommandForFrame("ActionButton1"), "ACTIONBUTTON1", "a main bar button")
eq(bars:CommandForFrame("ActionButton12"), "ACTIONBUTTON12", "and the twelfth")
eq(bars:CommandForFrame("MultiBarBottomLeftButton3"), "MULTIACTIONBAR1BUTTON3",
        "a bar the client numbers differently from its name")
eq(bars:CommandForFrame("PetActionButton2"), "BONUSACTIONBUTTON2",
        "and the pet bar, which shares a namespace with the bonus bar")

eq(bars:CommandForFrame("SomeOtherFrame"), nil, "anything else is not bindable")
eq(bars:CommandForFrame("PetActionButton11"), nil,
        "and neither is a button past the end of its family")

--[[ **Modifiers in the client's own order.** SetBinding("CTRL-ALT-F") and
     SetBinding("ALT-CTRL-F") are two different strings and only one of them is
     what the client looks up when the keys are pressed. ]]--
eq(bars:BindingName("F"), "F", "a plain key is itself")

Stub.shiftDown = true
eq(bars:BindingName("F"), "SHIFT-F", "Shift goes in front")

Stub.ctrlDown = true
Stub.altDown = true
eq(bars:BindingName("F"), "ALT-CTRL-SHIFT-F", "and all three in the client's order")

Stub.shiftDown, Stub.ctrlDown, Stub.altDown = false, false, false

--[[ A modifier on its own is somebody reaching for a combination, not a binding.
     Treating it as one would bind Shift to whatever is under the cursor the
     instant they pressed it. ]]--
eq(bars:BindingName("LSHIFT"), nil, "a modifier alone is not a binding")
eq(bars:BindingName("RALT"), nil, "on either side of the keyboard")
eq(bars:BindingName("UNKNOWN"), nil, "and neither is a key the client cannot name")

--[[ **Found by geometry, not by focus.** The capture frame has to take the mouse
     or a left click casts the spell instead of binding to it -- and the moment it
     does, GetMouseFocus answers the capture frame rather than the button. ]]--
Stub.mouseOver = nil
eq(bars:Bind("F"), false, "with the mouse over nothing, nothing is bound")

Stub.mouseOver = getglobal("ActionButton5")
eq(bars:Bind("F"), true, "over a button, the key is bound")
eq(Stub.boundTo["F"], "ACTIONBUTTON5", "to that button's command")

--[[ **What a key was taken from is named**, because the commonest thing that
     goes wrong here is quietly moving a key off something you wanted, and the
     client says nothing when it does. ]]--
Stub.mouseOver = getglobal("ActionButton6")
eq(bars:Bind("F"), true, "the same key can be moved to another button")
eq(Stub.boundTo["F"], "ACTIONBUTTON6", "and moves")
eq(Stub.bindings["ACTIONBUTTON5"], nil, "leaving the first one unbound")

--[[ Clearing, which is the other half. A hover-to-bind mode with no way to
     unbind is one you can only ever add with. ]]--
Stub.mouseOver = getglobal("ActionButton6")
eq(bars:Unbind(), true, "the button's bindings are cleared")
eq(Stub.bindings["ACTIONBUTTON6"], nil, "and it has none left")
eq(bars:Unbind(), false, "clearing a button with nothing on it does nothing")

--[[ **Everything closes on the way in.** The point is an unobstructed view of
     the bars, and the settings panel is the largest thing likely to be over them
     -- it is where somebody was standing when they decided to do this. ]]--
bars:SetBindMode(true)
eq(bars:BindMode(), true, "the mode turns on")
eq(Stub.windowsClosed, true, "and closes what is in the way")

--[[ Written to disk on the way out rather than on every key: a binding set is
     saved whole, and eighty writes while somebody works down a bar is eighty
     writes for one result. ]]--
eq(Stub.bindingsSaved, 0, "nothing is written while the mode is on")

bars:SetBindMode(false)
eq(bars:BindMode(), false, "the mode turns off")
eq(Stub.bindingsSaved, 1, "and the bindings are written once")

cfg.hideArt = false
OB.profile.modulesEnabled.actionbars = nil
OB.BindSlots()

end

actionBarTests()

-- 42. everything is reachable from the panel
--
-- The standing rule, asserted rather than trusted. Prat's whole shape was
-- behaviour that existed and a settings window that did not know about it, and
-- every action added here since has been one slash command away from the same
-- mistake.
-- ---------------------------------------------------------------------------

function panelReachTests()

context = "reachable: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

--[[ Every feature switched on, because a module's rows are only built while it
     is -- and a page nobody built cannot be swept for what is missing. ]]--
for id, m in pairs(OB.modules) do
    if m.feature then OB.profile.modulesEnabled[id] = true end
end

OB.BindSlots()
OB.TogglePanel()

--[[ **Every action the slash prompt offers has a control somewhere.**

     The list is short and hand-written on purpose. The point is to name the
     actions that exist, so adding one and forgetting the panel fails here
     rather than in somebody's session. ]]--
slashActions = {
    { "bind", "actionbars", "bind mode" },
    { "bars", "actionbars", "moving the bars" },
    { "select", "qol", "choosing items in your bags" },
    { "sell", "qol", "selling junk now" },
    { "roster", "roster", "reporting on known players" },
    { "trash", "qol", "the never-keep list" },
}

--[[ What each module's page can do. An action row is the only kind with a
     function behind it and no value, which is what makes it findable. ]]--
declaredActions = {}

for id, m in pairs(OB.modules) do
    declaredActions[id] = 0

    if m.options then
        for i = 1, table.getn(m.options) do
            if m.options[i][3] == "action" then
                declaredActions[id] = declaredActions[id] + 1
            end
        end
    end
end

unreachable = {}

for i = 1, table.getn(slashActions) do
    local entry = slashActions[i]
    local reached = (declaredActions[entry[2]] or 0) > 0

    --[[ The never-keep list is the one that is a *setting* rather than an
         action: the panel edits the string directly, which is better than a
         button, so a text row is what counts as reaching it. ]]--
    if entry[1] == "trash" then
        reached = false

        for j = 1, table.getn(OB.modules.qol.options) do
            if OB.modules.qol.options[j][2] == "@account:trash" then reached = true end
        end
    end

    if not reached then
        table.insert(unreachable, "/eqob " .. entry[1] .. " (" .. entry[3] .. ")")
    end
end

eq(table.getn(unreachable), 0,
        "every action reachable by typing is reachable from the panel",
        table.concat(unreachable, ", "))

--[[ And the rows are really built rather than only declared. A row that throws
     during construction is dropped and the page carries on -- which is right,
     and means "declared" and "on screen" are two different claims. ]]--
builtActions = 0

for key, widget in pairs(OB.widgets) do
    if widget.kind == "action" then builtActions = builtActions + 1 end
end

check(builtActions >= 8, "and the action rows are built, not just declared",
        "built: " .. builtActions)

--[[ **An action is not a setting.** It has a key, which makes it look
     addressable, and there is nothing at the end of it -- so the slash prompt
     must not offer one and the self-test must not try to read one. ]]--
offered = {}

for id, index in pairs(OB.optionIndex.modules) do
    for key, w in pairs(index) do
        if w.kind == "action" then table.insert(offered, id .. " " .. key) end
    end
end

eq(table.getn(offered), 0, "and no action is offered as a typed option",
        table.concat(offered, ", "))

--[[ **The shared look goes only on pages that draw with it.**

     Texture, font, font size, outline and border are added to a subsystem's page
     from one place, so a new one cannot arrive with four of them and a
     differently worded fifth. That block used to go on *every* feature page --
     which put "Bar Texture" and "Border" on the chat page, five controls that do
     nothing on a module owning no bar and no border. Reported as exactly that.

     The flag is declared rather than inferred, and `renders` cannot stand in for
     it: nameplates, action bars and unit frames all say "none" because they draw
     into the client's own frames, and all three use the shared look. ]]--
styledWithout, unstyledWith = {}, {}

for id, m in pairs(OB.modules) do
    if m.feature then
        local hasLook = OB.widgets["module:" .. id .. ":texture"] ~= nil

        if m.styled and not hasLook then
            table.insert(styledWithout, id)
        elseif not m.styled and hasLook then
            table.insert(unstyledWith, id)
        end
    end
end

eq(table.getn(unstyledWith), 0,
        "a subsystem that draws nothing styled is offered no texture or border",
        table.concat(unstyledWith, ", "))

eq(table.getn(styledWithout), 0, "and one that does is offered both",
        table.concat(styledWithout, ", "))

--[[ Named directly as well, because the two sweeps above would both pass on an
     addon where nothing was flagged at all. ]]--
check(OB.modules.damage.styled, "the damage meter draws with it")
check(OB.modules.nameplates.styled, "so do nameplates")
check(not OB.modules.chat.styled, "and chat does not")
check(not OB.modules.qol.styled, "nor does quality of life")

OB.TogglePanel()

end

panelReachTests()

-- 44. the rename
--
-- The addon was Equadis' OmniBars and its saved variables were named after it.
-- Renaming the addon renames the store, and a rename with nothing behind it is
-- somebody logging in to find every profile gone -- with the old data still in
-- the file, unreachable, looking exactly like a bug.
-- ---------------------------------------------------------------------------

function renameTests()

context = "rename: "

OB = boot("ROGUE", 3)

--[[ A store written under the old name, with things in it worth keeping.

     `LoadConfig` is called directly rather than through a boot, because the test
     harness clears the new-name store on every boot as part of starting clean --
     which is exactly the state this is about, and driving it through boot would
     be testing the harness rather than the adoption. ]]--
EquadisClassicOverhaulDB = nil
EquadisOmniBarsDB = {
    version = 0,
    profiles = { Default = { scale = 1.25 } },
    chars = {},
    migrated = {},
    roster = { Grimtusk = { class = "WARRIOR", level = 60 } },
    trash = "Broken Fang",
}

OB.adoptedOldSaves = nil
OB.LoadConfig()

check(EquadisClassicOverhaulDB ~= nil, "the new name has a store after loading")
eq(OB.profile.scale, 1.25, "and the old profile is in it")
eq(OB.roster["Grimtusk"].class, "WARRIOR", "along with what was known")
eq(OB.TrashList(), "Broken Fang", "and the list that destroys things")

--[[ **The same table, not a copy.** Copying would leave two stores that drift,
     and the one being written would not be the one anybody looked at. ]]--
check(EquadisClassicOverhaulDB == EquadisOmniBarsDB,
        "adopted by reference rather than copied")

--[[ **The old one is not deleted.** A saved variable the TOC no longer declares
     stops being written the moment the name changes, so it is already frozen --
     and leaving it means going back a version still works. A few kilobytes is
     the difference between a rename you can undo and one you cannot. ]]--
check(EquadisOmniBarsDB ~= nil, "and the old name is left where it was")

--[[ Said once, because somebody who has just watched an addon vanish from their
     list and a differently named one appear deserves telling. ]]--
eq(OB.adoptedOldSaves, true, "the adoption is announced")

--[[ **And it only happens when there is nothing under the new name.** A store
     already written by the new name is the current one, and adopting over it
     would throw away everything since the rename. ]]--
EquadisClassicOverhaulDB = {
    version = 0, profiles = { Default = { scale = 0.75 } }, chars = {}, migrated = {},
}
EquadisOmniBarsDB = {
    version = 0, profiles = { Default = { scale = 1.25 } }, chars = {}, migrated = {},
}

OB.adoptedOldSaves = nil
OB.LoadConfig()

eq(OB.profile.scale, 0.75, "an existing new store wins over the old one")
eq(OB.adoptedOldSaves, nil, "and nothing is announced")

EquadisOmniBarsDB = nil

end

renameTests()

-- 43. nameplates
--
-- A 1.12 nameplate cannot be asked for. There is no GetNamePlateForUnit, no
-- unit token and no event when one appears -- the client makes an unnamed frame,
-- parents it to WorldFrame and tells nobody. Everything here follows from that
-- one fact and none of it is how anybody would design it.
-- ---------------------------------------------------------------------------

function nameplateTests()

context = "nameplates: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local plates = OB.modules.nameplates
check(plates ~= nil, "the nameplate module registers")
eq(OB.ModuleEnabled("nameplates"), false, "and ships off")

OB.profile.modulesEnabled.nameplates = true
OB.BindSlots()

local cfg = OB.profile.modules.nameplates

-- ---------------------------------------------------------------------------
-- hostility, read off a colour
-- ---------------------------------------------------------------------------

--[[ **There is no unit to ask.** Nothing to give UnitReaction, so the only thing
     that knows is the bar the client already coloured. Reading a colour to find
     out whether something wants to kill you is absurd, and it is the only way
     there is. ]]--
eq(OB.PlateKind(1, 0, 0), "ENEMY_NPC", "red is an enemy")
eq(OB.PlateKind(1, 1, 0), "NEUTRAL_NPC", "yellow is neutral")
eq(OB.PlateKind(0, 1, 0), "FRIENDLY_NPC", "green is a friendly NPC")
eq(OB.PlateKind(0, 0, 1), "FRIENDLY_PLAYER", "blue is a friendly player")

--[[ Anything else is left alone rather than guessed at. The client's colours are
     exact, so one landing on none of the four is something this does not
     understand -- and a plate coloured by a guess is worse than one left as the
     client drew it. ]]--
eq(OB.PlateKind(0.5, 0.5, 0.5), nil, "grey is nothing this knows")
eq(OB.PlateKind(nil), nil, "and no colour at all is the same")

-- ---------------------------------------------------------------------------
-- finding one
-- ---------------------------------------------------------------------------

--[[ **The signature is the border texture on the first region.** Nothing else
     about a 1.12 plate is distinctive: no name, no type of its own, no field. ]]--
notAPlate = CreateFrame("Button", nil, WorldFrame)
notAPlate.frameType = "Button"
notAPlate:CreateTexture(nil, "ARTWORK")

eq(plates:IsNamePlate(notAPlate), false,
        "a button with a plain texture is not a nameplate")

plates.plates, plates.order, plates.seen = {}, {}, 0
plates:Scan()

enemyPlate = Stub.NewNamePlate("Bloodscalp Berserker", 34, 1, 0, 0, 60)
eq(plates:IsNamePlate(enemyPlate), true, "one with the border texture is")
eq(plates:IsNamePlate(nil), false, "and nothing is not one either")

--[[ Watching a number go up is the whole of detection. There is no event, so the
     child count is compared and only the new tail is walked -- children are
     appended, never inserted. ]]--
check(plates:Scan() >= 1, "a scan finds the plate that is there")
check(plates.plates[enemyPlate] ~= nil, "and takes it over")

platesBefore = table.getn(plates.order)
eq(plates:Scan(), 0, "a second scan with nothing new finds nothing")
eq(table.getn(plates.order), platesBefore, "and adopts nothing twice")

-- ---------------------------------------------------------------------------
-- taking one over
-- ---------------------------------------------------------------------------

--[[ **The originals are kept, not discarded.** They are the only source of
     everything -- the name, the level, the health, and the colour that says
     whether the thing is hostile. Silencing them and then reading them is the
     entire technique. ]]--
adoptedEnemy = plates.plates[enemyPlate]

check(adoptedEnemy.original.name ~= nil, "the client's name string is kept")
check(adoptedEnemy.original.level ~= nil, "and its level string")
check(adoptedEnemy.original.health ~= nil, "and its health bar")

eq(adoptedEnemy.original.name:GetText(), "Bloodscalp Berserker",
        "the name is read from the region the client wrote it into")
eq(adoptedEnemy.original.level:GetText(), "34", "and the level from the next one")

--[[ Order is the whole of the identification: regions answered in a different
     order would let this read the level as the name and pass. ]]--
check(adoptedEnemy.original.border ~= nil, "the border is the first region")

-- ---------------------------------------------------------------------------
-- drawing one
-- ---------------------------------------------------------------------------

plates:Refresh(adoptedEnemy)

eq(adoptedEnemy.health.value, 0.6, "health is a fraction of the original bar")
eq(adoptedEnemy.kind, "ENEMY_NPC", "and the kind comes from its colour")

--[[ **Abbreviated rather than truncated.** "Bloodscalp Berserker" on a 120 wide
     plate has to give somewhere, and everything-but-the-last-word-as-an-initial
     keeps the part that tells one mob from the next. Truncating gives
     "Bloodscalp Ber", which does not. ]]--
eq(plates:ShortName("Bloodscalp Berserker"), "B. Berserker", "long names shorten")
eq(plates:ShortName("Kobold"), "Kobold", "short ones are left alone")

cfg.shortenNames = false
eq(plates:ShortName("Bloodscalp Berserker"), "Bloodscalp Berserker",
        "and nothing shortens with it switched off")
cfg.shortenNames = true

--[[ The colour follows the setting rather than the client, which is the point of
     taking the plate over at all. ]]--
cfg.enemyColor = { 1, 0, 1, 1 }
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.health.barColor[1], 1, "an enemy takes the enemy colour")
eq(adoptedEnemy.health.barColor[2], 0, "as set")
eq(adoptedEnemy.health.barColor[3], 1, "on the panel")

--[[ **Which plates show at all.** Enemies on, friendlies off, which is what
     makes a nameplate useful: they exist to tell you what is attacking you. ]]--
eq(cfg.friendlyPlayer, false, "friendly players are hidden by default")

friendPlate = Stub.NewNamePlate("Sylvie", 60, 0, 0, 1, 100)
plates:Scan()

adoptedFriend = plates.plates[friendPlate]
plates:Refresh(adoptedFriend)

eq(adoptedFriend.kind, "FRIENDLY_PLAYER", "a friendly player is recognised")
eq(adoptedFriend.overlay.shown, false, "and hidden, because the setting says so")

cfg.friendlyPlayer = true
plates:Refresh(adoptedFriend)
eq(adoptedFriend.overlay.shown, true, "switching it on shows them")

--[[ **Health as a number can only be a percentage.** There is no unit, so there
     is no current and no maximum -- only a fraction of a bar whose real numbers
     the client never wrote down. ]]--
cfg.healthText = "max"
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.text:GetText(), "60%",
        "even 'current / max' can only honestly answer the percentage")

cfg.healthText = "none"
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.text.shown, false, "and none means none")

-- ---------------------------------------------------------------------------
-- the one plate that has a unit
-- ---------------------------------------------------------------------------

--[[ **The client raises the targeted plate's alpha to 1 and dims the rest.**
     That is the only signal there is, and it is enough.

     What makes it worth the trouble is not the highlight. The target is the one
     nameplate in the world with a unit token, so everything the game will not
     tell you about a plate -- is it casting, is it attacking me -- becomes
     answerable the moment you know the plate you are looking at is "target". ]]--
Stub.player.hasTarget = false
enemyPlate:SetAlpha(1)
eq(plates:IsTarget(adoptedEnemy), false, "with no target, no plate is the target")

Stub.player.hasTarget = true
eq(plates:IsTarget(adoptedEnemy), true, "a plate at full alpha is the target's")

friendPlate:SetAlpha(0.5)
eq(plates:IsTarget(adoptedFriend), false, "and a dimmed one is not")

--[[ Told apart from the wall: bigger, and everything else faded. Forty identical
     rectangles with no way to see which your spells are going to is the thing
     nameplates are worst at. ]]--
cfg.markTarget = true
plates:Refresh(adoptedEnemy)
plates:Refresh(adoptedFriend)

eq(adoptedEnemy.overlay.scale, cfg.targetScale, "the target's plate grows")
eq(adoptedFriend.overlay.alpha, cfg.otherAlpha, "and the others fade")

--[[ Only while there *is* a target. With none, every plate is equally
     interesting and dimming them all says nothing. ]]--
Stub.player.hasTarget = false
plates:Refresh(adoptedFriend)
eq(adoptedFriend.overlay.alpha, 1, "with no target, nothing is faded")
Stub.player.hasTarget = true

-- ---------------------------------------------------------------------------
-- threat, for the target only
-- ---------------------------------------------------------------------------

--[[ `UnitIsUnit("targettarget", "player")` is the whole question: the thing you
     are looking at is attacking you, or it is attacking somebody else.

     **Only the target, and not because it was easier.** There is no unit token
     for any other plate, so for the rest the question cannot be asked at all.
     ShaguPlates reaches it through SuperWoW's GUID support, which is a client
     mod rather than an API -- and the standing rule here is that a client mod
     may improve an answer, never be required for one. ]]--
Stub.player.targetsTarget = nil
Stub.player.targetFriendly = nil

eq(plates:TargetThreat(), nil, "nothing attacking your target is no answer")

Stub.player.targetsTarget = "player"
eq(plates:TargetThreat(), true, "your target attacking you is threat")

Stub.player.targetsTarget = "someone"
eq(plates:TargetThreat(), false, "attacking somebody else is not")

--[[ A friendly target's target is not a threat relationship, it is a healer
     looking at a tank. ]]--
Stub.player.targetFriendly = true
eq(plates:TargetThreat(), nil, "and a friendly target has no threat to describe")
Stub.player.targetFriendly = nil

cfg.colorByThreat = true
Stub.player.targetsTarget = "player"
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.health.barColor[1], cfg.threatColor[1],
        "a target on you takes the threat colour")

Stub.player.targetsTarget = "someone"
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.health.barColor[1], cfg.noThreatColor[1],
        "and one on somebody else takes the other")

--[[ Nil keeps the ordinary colour rather than being painted as though the
     answer were no -- "nobody is attacking it" and "it is not attacking you"
     are different facts. ]]--
Stub.player.targetsTarget = nil
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.health.barColor[1], cfg.enemyColor[1],
        "and no relationship at all keeps the plate's own colour")

cfg.colorByThreat = false

-- ---------------------------------------------------------------------------
-- combo points
-- ---------------------------------------------------------------------------

--[[ On the target's plate and nowhere else. They are the player's points *on
     that unit*, so any other plate would be a lie. ]]--
cfg.showCombo = true
Stub.player.combo = 3

plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.combo[3].shown, true, "three points show three")
eq(adoptedEnemy.combo[4].shown, false, "and not four")

plates:Refresh(adoptedFriend)
eq(adoptedFriend.combo[1].shown, false, "a plate that is not the target shows none")

Stub.player.combo = 0
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.combo[1].shown, false, "and none means none")

cfg.showCombo = false

-- ---------------------------------------------------------------------------
-- cast bars, which are the one thing here that is not target-only
-- ---------------------------------------------------------------------------

--[[ **1.12 has no UnitCastingInfo and no UnitChannelInfo.** They arrive in 2.0.
     So every vanilla addon that draws a cast bar for anything but the player has
     built this layer itself.

     `modules/casts.lua` is keyed by unit **name**, not by token, and that is the
     whole reason cast bars work on every plate while threat and combo points do
     not: a nameplate has a name and no token. ]]--
OB.casting = {}
EquadisClassicOverhaulDB.castTimes = {}
OB.castTimes = EquadisClassicOverhaulDB.castTimes

eq(OB.CastInfo("Bloodscalp Berserker"), nil, "nobody is casting anything")

--[[ A mob's cast is read out of the combat log, through the client's own
     sentence rather than by matching English -- the same rule every other line
     in this addon follows. ]]--
local caster, spellName = OB.casts:ReadCastLine("Bloodscalp Berserker begins to cast Fireball.")
eq(caster, "Bloodscalp Berserker", "the caster comes out of the line")
eq(spellName, "Fireball", "and the spell")

eq(OB.casts:ReadCastLine("Bloodscalp Berserker hits you for 40."), nil,
        "a line that is not a cast is not one")

--[[ **A cast with no known duration still draws.** The combat log says a cast
     has begun and nothing about how long it takes -- and *what* is being cast is
     the useful half, so "I do not know how far through this is" is not a reason
     to say nothing. ]]--
OB.StartCast("Bloodscalp Berserker", "Fireball")

local castSpell, castFraction = OB.CastInfo("Bloodscalp Berserker")
eq(castSpell, "Fireball", "the spell is known")
eq(castFraction, nil, "and its progress is not, which is said rather than faked")

--[[ **The duration is learned, not shipped.** ShaguPlates carries a database of
     every spell in the game; every spell the player casts reports its exact
     duration to the client, and mobs cast a great many of the same spells that
     players do. Fireball is Fireball. ]]--
OB.StartCast(Stub.player.name, "Fireball", 3000)
eq(OB.castTimes["Fireball"], 3000, "casting it yourself teaches its duration")

OB.StartCast("Bloodscalp Berserker", "Fireball")
castSpell, castFraction = OB.CastInfo("Bloodscalp Berserker")
check(castFraction ~= nil, "so the next mob to cast it gets a filling bar")

--[[ **The longest seen wins**, which is the opposite of the levels rule and
     right for the opposite reason: a cast time shortens with haste and with
     talents and lengthens with nothing, so the largest seen is the base. A bar
     drawn from a hasted duration finishes early on somebody who is not hasted,
     which reads as an interrupt that did not happen. ]]--
OB.LearnCastTime("Fireball", 2500)
eq(OB.castTimes["Fireball"], 3000, "a shorter time seen later is haste, not news")

OB.LearnCastTime("Fireball", 3500)
eq(OB.castTimes["Fireball"], 3500, "and a longer one replaces it")

--[[ A channel empties rather than fills. Same number read the other way round,
     and getting it backwards is what nobody notices until they watch a Drain
     Life. ]]--
OB.StartCast("Sylvie", "Drain Life", 5000, true)
local _, drainFraction = OB.CastInfo("Sylvie")
check(drainFraction and drainFraction > 0.9,
        "a channel starts full", tostring(drainFraction))

--[[ **Expiry happens when somebody asks**, rather than on a timer. It costs
     nothing, there is no sweep to schedule, and nothing leaks when a caster dies
     mid-cast and never sends another line. ]]--
OB.casting["Ghost"] = { spell = "Fireball", start = GetTime() - 60, duration = 3000 }
eq(OB.CastInfo("Ghost"), nil, "a cast that ran out is gone when next asked about")
eq(OB.casting["Ghost"], nil, "and forgotten rather than left behind")

--[[ And the plate draws it, for any plate, because the lookup is by name. ]]--
cfg.castbar = true
OB.StartCast("Bloodscalp Berserker", "Fireball", 3000)

plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.cast.shown, true, "a plate whose unit is casting shows a bar")
eq(adoptedEnemy.castName:GetText(), "Fireball", "with the spell on it")

OB.StopCast("Bloodscalp Berserker")
plates:Refresh(adoptedEnemy)
eq(adoptedEnemy.cast.shown, false, "and hides it when the cast ends")

--[[ The friendly plate is not the target and has no token, and it draws a cast
     bar all the same -- which is the point of keying by name. ]]--
OB.StartCast("Sylvie", "Renew", 1500)
plates:Refresh(adoptedFriend)
eq(adoptedFriend.cast.shown, true,
        "a plate that is not the target shows one too")

OB.casting = {}
cfg.castbar = false

OB.profile.modulesEnabled.nameplates = nil
OB.BindSlots()

end

nameplateTests()

-- 45. unit frames
--
-- These are Blizzard's frames, restyled. Not replacements -- they already know
-- which unit they show, already update on the right events, and already handle
-- ghosts, tapped mobs and pet happiness. What they do badly is look like 2004
-- and refuse to say how much health anybody has, and both of those are texture
-- and font work on frames that are already correct.
-- ---------------------------------------------------------------------------

function unitFrameTests()

context = "unit frames: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

local frames = OB.modules.unitframes
check(frames ~= nil, "the unit frame module registers")
eq(OB.ModuleEnabled("unitframes"), false, "and ships off")

OB.profile.modulesEnabled.unitframes = true
OB.BindSlots()

local cfg = OB.profile.modules.unitframes

-- ---------------------------------------------------------------------------
-- what colour a unit is
-- ---------------------------------------------------------------------------

--[[ **An NPC has a class and it is meaningless.** The server gives every
     creature one -- a wolf is a warrior -- so NPCs get their reaction instead,
     and the class option for them is a separate switch that ships off. ]]--
Stub.player.hasTarget = true
Stub.target = { name = "Sylvie", isPlayer = true, class = "PRIEST" }
Stub.reaction = 5

local color = frames:UnitColor("target")
local pr, pg, pb = OB.ClassColor("PRIEST")
eq(color[1], pr, "a player takes their class colour")
eq(color[2], pg, "all three channels")
eq(color[3], pb, "of it")

Stub.target = { name = "Wolf", isPlayer = false, class = "WARRIOR" }

color = frames:UnitColor("target")
eq(color[1], cfg.friendlyColor[1], "an NPC takes its reaction instead")

cfg.npcClassColor = true
color = frames:UnitColor("target")
local wr = OB.ClassColor("WARRIOR")
eq(color[1], wr, "unless you have asked for their class too")
cfg.npcClassColor = false

--[[ Blizzard's own reaction thresholds: above four is friendly, exactly four is
     neutral, below is hostile. The middle is `== 4` rather than a range because
     it is the only value meaning "will not attack you and will not help you". ]]--
Stub.reaction = 4
eq(frames:ReactionColor("target")[1], cfg.neutralColor[1], "four is neutral")

Stub.reaction = 2
eq(frames:ReactionColor("target")[1], cfg.hostileColor[1], "below it is hostile")

Stub.reaction = 6
eq(frames:ReactionColor("target")[1], cfg.friendlyColor[1], "above it is friendly")

-- ---------------------------------------------------------------------------
-- what the bars say
-- ---------------------------------------------------------------------------

--[[ **1.12 writes health in full or not at all**, and "4382/4382" on a frame the
     size of a postage stamp is four characters of information in nine. ]]--
eq(frames:BarText(4382, 8000, "none"), "", "none is none")
eq(frames:BarText(4382, 8000, "percent"), "55%", "a percentage rounds")
eq(frames:BarText(4382, 8000, "value"), "4.4k", "and a value shortens")
eq(frames:BarText(4382, 8000, "max"), "4.4k/8.0k", "as does a pair")
eq(frames:BarText(4382, 8000, "maxpct"), "4.4k/8.0k (55%)", "and all three")

--[[ The decimal count is the one thing this does differently from the meters'
     shortener: a unit frame is small enough that somebody genuinely wants 4.4k
     on the target and 4.38k on themselves. ]]--
cfg.decimals = 2
eq(frames:BarText(4382, 8000, "value"), "4.38k", "with the places asked for")
cfg.decimals = 1

--[[ Under a thousand is written out. "0.4k" is not shorter than "437" and is
     harder to read. ]]--
eq(frames:BarText(437, 8000, "value"), "437", "a small number is left alone")

cfg.shortNumbers = false
eq(frames:BarText(4382, 8000, "value"), "4382", "and nothing shortens when off")
cfg.shortNumbers = true

-- ---------------------------------------------------------------------------
-- the client, which owns these strings and keeps writing to them
-- ---------------------------------------------------------------------------

--[[ **The whole difficulty of restyling Blizzard's frames rather than replacing
     them.**

     `TextStatusBar_UpdateTextString` is the client's, it owns every one of these
     strings, and it runs from the bar's own `OnValueChanged` -- so it fires
     *after* any handler that took a damage event as its cue. Writing the text on
     an event and stopping there means the client overwrites it a frame later,
     which reads as a setting that does nothing.

     The addon this is ported from replaces the function outright, and that is
     the only thing that works: there is no `hooksecurefunc` in 1.12 and no
     ordering guarantee that would make an event handler win.

     So the test is the client's own path, not the module's: call what Blizzard
     calls and assert the module's answer comes out. ]]--
--[[ Driven from the *unit*, not from the bar. The bar is the fallback for a
     frame with no unit behind it; where there is one, its health is the truth
     and the bar is only where the client happened to leave the number. ]]--
Stub.player.health, Stub.player.healthMax = 4382, 8000

GLOBAL_hp = _G["PlayerFrameHealthBar"]
GLOBAL_hp:SetMinMaxValues(0, 8000)
GLOBAL_hp:SetValue(4382)

cfg.healthText = "maxpct"
TextStatusBar_UpdateTextString(GLOBAL_hp)

eq(GLOBAL_hp.TextString:GetText(), "4.4k/8.0k (55%)",
        "the client's own update writes the format that was asked for")

--[[ **And shows it.** Blizzard hides the string unless the `statusBarText` CVar
     is on, which it is not by default -- so a port that writes the right text
     into a hidden string has a setting that silently does nothing for almost
     everybody. ]]--
check(GLOBAL_hp.TextString:IsShown(),
        "and shows a string the client would have hidden")

--[[ "None" is the one mode that agrees with the client: no text, and hidden. ]]--
cfg.healthText = "none"
TextStatusBar_UpdateTextString(GLOBAL_hp)
eq(GLOBAL_hp.TextString:GetText(), "", "none writes nothing")
check(not GLOBAL_hp.TextString:IsShown(), "and hides the string")
cfg.healthText = "maxpct"

--[[ The power bar reads its own setting, not the health one. They are two rows
     on the panel and a single format key would make one of them a lie. ]]--
Stub.player.power, Stub.player.powerMax = 60, 100

GLOBAL_mp = _G["PlayerFrameManaBar"]
GLOBAL_mp:SetMinMaxValues(0, 100)
GLOBAL_mp:SetValue(60)

cfg.powerText = "percent"
TextStatusBar_UpdateTextString(GLOBAL_mp)
eq(GLOBAL_mp.TextString:GetText(), "60%", "the power bar reads the power format")

--[[ **The colour, which the client rewrites just as often.**

     `HealthBar_OnValueChanged` paints every health bar green on every value
     change. A module that sets the colour on an event gets one frame of its own
     colour and then Blizzard's. ]]--
Stub.player.class = "ROGUE"
cfg.classColorHealth = true

this = GLOBAL_hp
HealthBar_OnValueChanged(4382, nil)
this = nil

GLOBAL_r, GLOBAL_g, GLOBAL_b = OB.ClassColor("ROGUE")
eq(select(1, GLOBAL_hp:GetStatusBarColor()), GLOBAL_r,
        "the client's own colour pass leaves the class colour alone")
eq(select(2, GLOBAL_hp:GetStatusBarColor()), GLOBAL_g,
        "on every channel")

--[[ Off, and the player's own swatch is used -- which is a setting the original
     has and this one needs, because "not class coloured" still has to be some
     colour and green is the client's, not a choice. ]]--
cfg.classColorHealth = false

this = GLOBAL_hp
HealthBar_OnValueChanged(4382, nil)
this = nil

eq(select(1, GLOBAL_hp:GetStatusBarColor()), cfg.playerColor[1],
        "and off, the player's own swatch")
cfg.classColorHealth = true

--[[ **A bar that is not the player's is left to the client.** Target, pet and
     party health are coloured by reaction through the styling pass; the
     replacement only has an opinion about the player's own bar, which is the
     one the client insists on painting green. ]]--
GLOBAL_tot = _G["TargetofTargetHealthBar"]
GLOBAL_tot:SetMinMaxValues(0, 100)

this = GLOBAL_tot
HealthBar_OnValueChanged(50, nil)
this = nil

eq(select(2, GLOBAL_tot:GetStatusBarColor()), 1,
        "another bar still gets the client's own green")

-- ---------------------------------------------------------------------------
-- where the text sits
-- ---------------------------------------------------------------------------

--[[ **A nudge that can be nudged back.**

     Applying the offset only when it is non-zero leaves the text wherever it was
     last put once somebody returns the slider to zero -- a setting that works
     going out and not coming back, which is worse than one that never worked.
     So the anchor is set every pass. ]]--
cfg.healthX, cfg.healthY = 12, -3
frames:Apply()

GLOBAL_point, GLOBAL_rel, GLOBAL_relPoint, GLOBAL_x, GLOBAL_y =
        _G["PlayerFrameHealthBarText"]:GetPoint()
eq(GLOBAL_x, 12, "the health text takes the offset across")
eq(GLOBAL_y, -3, "and up")

cfg.healthX, cfg.healthY = 0, 0
frames:Apply()

GLOBAL_point, GLOBAL_rel, GLOBAL_relPoint, GLOBAL_x, GLOBAL_y =
        _G["PlayerFrameHealthBarText"]:GetPoint()
eq(GLOBAL_x, 0, "and comes back when the slider does")
eq(GLOBAL_y, 0, "on both axes")

--[[ **The name anchors to the health bar's top edge, not the frame's centre.**

     Which is the original's anchor, and it is not a detail: a name centred on
     the frame lands in the middle of the portrait. It also means the player and
     target names stay level with each other automatically, because their bars
     are the same size at the same height. ]]--
cfg.nameX, cfg.nameY = 0, 0
frames:Apply()

GLOBAL_point, GLOBAL_rel, GLOBAL_relPoint, GLOBAL_x, GLOBAL_y =
        _G["PlayerName"]:GetPoint()
eq(GLOBAL_relPoint, "TOP", "the name hangs off the top of the health bar")
eq(GLOBAL_rel, _G["PlayerFrameHealthBar"], "its own bar, not the frame")

--[[ The target's X is mirrored, because the target frame's art is. Nudging the
     player's name right and the target's name right would move them apart. ]]--
cfg.nameX = 8
frames:Apply()

GLOBAL_point, GLOBAL_rel, GLOBAL_relPoint, GLOBAL_x = _G["PlayerName"]:GetPoint()
eq(GLOBAL_x, 8, "the player's name moves the way the slider says")

GLOBAL_point, GLOBAL_rel, GLOBAL_relPoint, GLOBAL_x =
        _G["TargetFrameTextureFrameName"]:GetPoint()
eq(GLOBAL_x, -8, "and the target's mirrors it")
cfg.nameX = 0

--[[ **A bar that is not ours is left to the client, exactly as it was.**

     Which is what makes replacing the function safe rather than rude: the focus
     frame, a raid frame and any other addon's status bar all still get
     Blizzard's own text. Switching a frame off here has to be indistinguishable
     from this module not existing. ]]--
cfg.replacePet = false
GLOBAL_pet = _G["PetFrameHealthBar"]
GLOBAL_pet:SetMinMaxValues(0, 500)
GLOBAL_pet:SetValue(250)

TextStatusBar_UpdateTextString(GLOBAL_pet)
eq(GLOBAL_pet.TextString:GetText(), "250/500",
        "a frame switched off gets the client's own text back")
cfg.replacePet = true

--[[ **The pet's numbers, hidden as a whole.**

     The original's Hide Pet Text, which is a separate switch from the format --
     a pet bar is small and its exact health is rarely the thing being read, but
     that is a decision about the pet rather than about the format. ]]--
Stub.player.health, Stub.player.healthMax = 250, 500
cfg.hidePetText = true

TextStatusBar_UpdateTextString(GLOBAL_pet)
check(not GLOBAL_pet.TextString:IsShown(), "the pet's numbers can be hidden")

cfg.hidePetText = false
TextStatusBar_UpdateTextString(GLOBAL_pet)
check(GLOBAL_pet.TextString:IsShown(), "and shown again")
cfg.hidePetText = true

Stub.player.health, Stub.player.healthMax = 4382, 8000

-- ---------------------------------------------------------------------------
-- shortening, which is one band and not everything
-- ---------------------------------------------------------------------------

--[[ **The switch is about the thousand-to-ten-thousand band and nothing else**,
     which is what the original's "Format HP<10k" means.

     Above ten thousand always shortens: five digits do not fit on a unit frame
     and nobody reads them, so that is not offered as a preference. The port had
     the switch governing everything above a thousand, which made it mean
     something its own label did not say. ]]--
cfg.shortNumbers = false
cfg.decimals = 2

eq(frames:Number(4382), "4382", "off, the middle band is written out")
eq(frames:Number(43820), "43.82k", "but five digits shorten regardless")
eq(frames:Number(4382000), "4.38m", "and millions do too")

cfg.shortNumbers = true
eq(frames:Number(4382), "4.38k", "on, the middle band shortens as well")
eq(frames:Number(437), "437", "and under a thousand is left alone either way")

cfg.decimals = 3
eq(frames:Number(4382), "4.382k", "the original offers three places")
cfg.decimals = 1

-- ---------------------------------------------------------------------------
-- the rest of what the original does
-- ---------------------------------------------------------------------------

--[[ **The combat glow**, which is the client's own art and the only sign that
     you are in a fight rather than beside one. Cleared to nil rather than
     hidden, because the client shows and hides these itself -- a hidden texture
     would come back on the next event that showed it. ]]--
cfg.statusGlow = true
frames:Apply()
check(_G["PlayerStatusTexture"].texture ~= nil, "the combat glow can be switched on")

cfg.statusGlow = false
frames:Apply()
check(_G["PlayerStatusTexture"].texture == nil, "and cleared rather than hidden")
check(_G["PetAttackModeTexture"].texture == nil, "the pet's flash with it")

--[[ **The pet frame drawn as a target-of-target frame**, which is the right size
     for a bar three units tall -- Blizzard's pet art is a full-size frame.
     Happiness becomes a colour instead of a meter, which says the same thing in
     space the bar already occupies. ]]--
Stub.player.class = "HUNTER"
OB.class = "HUNTER"
cfg.improvedPet = true
Stub.petHappiness = 3

frames:Apply()
check(not _G["PetFrameHappiness"]:IsShown(), "the happiness meter goes")
eq(select(1, _G["PetFrameHealthBar"]:GetStatusBarColor()), cfg.friendlyColor[1],
        "a fed pet reads friendly")

Stub.petHappiness = 2
frames:Apply()
eq(select(1, _G["PetFrameHealthBar"]:GetStatusBarColor()), cfg.neutralColor[1],
        "a content one reads neutral")

Stub.petHappiness = 1
frames:Apply()
eq(select(1, _G["PetFrameHealthBar"]:GetStatusBarColor()), cfg.hostileColor[1],
        "and an unhappy one reads hostile")

--[[ **Only a hunter's pet has happiness.** A warlock's demon, a totem and a
     water elemental are friendly and nothing else; giving them the unhappy
     colour because `GetPetHappiness` answered oddly would invent a problem the
     player does not have. ]]--
Stub.player.class = "WARLOCK"
OB.class = "WARLOCK"
frames:Apply()
eq(select(1, _G["PetFrameHealthBar"]:GetStatusBarColor()), cfg.friendlyColor[1],
        "a demon is friendly whatever the happiness call says")

Stub.player.class = "ROGUE"
OB.class = "ROGUE"
cfg.improvedPet = false
frames:Apply()
check(_G["PetFrameHappiness"]:IsShown(), "and the meter comes back when off")

--[[ **`lockColor` is how the client is told to keep off a bar.** Without it
     `UnitFrame_Update` repaints the colour the moment the unit changes, and the
     one this module set lasts until the next target -- a colour setting that
     works for a second. ]]--
frames:Apply()
check(_G["TargetFrameHealthBar"].lockColor == true,
        "a bar this module colours is locked against the client")

--[[ The player's bar is the exception, and has to be: 1.12 gives it no such
     flag, which is the whole reason `HealthBar_OnValueChanged` is replaced. ]]--
this = _G["PlayerFrameHealthBar"]
HealthBar_OnValueChanged(4382, nil)
this = nil

cfg.classColorHealth = true
GLOBAL_r = OB.ClassColor("ROGUE")

this = _G["PlayerFrameHealthBar"]
HealthBar_OnValueChanged(4382, nil)
this = nil

eq(select(1, _G["PlayerFrameHealthBar"]:GetStatusBarColor()), GLOBAL_r,
        "so the player's colour survives the client's own pass instead")


-- ---------------------------------------------------------------------------
-- what colour the numbers are
-- ---------------------------------------------------------------------------

--[[ **Not the colour of the bar, which is what the port had.**

     On a class-coloured bar that makes a warlock's health purple text on a
     purple bar -- the one arrangement that cannot be read. The original colours
     each by what it *means*: health ramps red to green by what is left, and
     resource takes its power type's own colour. ]]--
cfg.colorText = true

GLOBAL_health = OB.profile.modules.health

--[[ Compared to two places, because a ramp is arithmetic and the ends come back
     as 0.10000000000001 rather than as the anchor that was put in. ]]--
function rampChannel(value, max)
    return OB.Round(frames:TextColor("health", value, max) * 100)
end

eq(rampChannel(8000, 8000), OB.Round(GLOBAL_health.fullColor[1] * 100),
        "full health reads as full")
eq(rampChannel(0, 8000), OB.Round(GLOBAL_health.lowColor[1] * 100),
        "and empty reads as empty")

--[[ The anchors are the health module's own, so a number on a unit frame and
     the bar in the HUD agree about what half looks like rather than being two
     opinions that drift. ]]--
eq(rampChannel(4000, 8000), OB.Round(GLOBAL_health.halfColor[1] * 100),
        "and half is the health module's half")

--[[ **Resource goes by power type, not by class.** A druid in cat form is on
     energy and in bear form on rage; reading the class would give both of them
     mana blue. ]]--
Stub.player.powerType = 3
eq(OB.Round(frames:TextColor("power", 50, 100) * 255), 250, "energy is pale")

Stub.player.powerType = 1
eq(OB.Round(frames:TextColor("power", 50, 100) * 255), 250, "rage is red")
eq(OB.Round(select(2, frames:TextColor("power", 50, 100)) * 255), 108,
        "on the channel that tells them apart")

Stub.player.powerType = 0
eq(frames:TextColor("power", 50, 100), 0.6, "and mana is blue")
Stub.player.powerType = 3

cfg.colorText = false
eq(frames:TextColor("health", 0, 8000), 1, "off, everything is white")
cfg.colorText = true

-- ---------------------------------------------------------------------------
-- moving the frames
-- ---------------------------------------------------------------------------

--[[ **The original's Unlock button, as a mode rather than a lock.**

     On, drag, off -- the same shape the action bars use, because a permanently
     draggable player frame is one you move by accident every time you
     right-click your own buffs. ]]--
eq(frames:DragMode(), false, "drag mode ships off")
GLOBAL_ok, GLOBAL_err = pcall(function() OB.modules.actionbars:SetDragMode(true) end)
check(GLOBAL_ok, "DEBUG actionbars drag mode does not throw", tostring(GLOBAL_err))
GLOBAL_ok, GLOBAL_err = pcall(function() OB.modules.actionbars:ResetPositions() end)
check(GLOBAL_ok, "DEBUG actionbars reset does not throw", tostring(GLOBAL_err))

frames:SetDragMode(true)
eq(frames:DragMode(), true, "and can be switched on")
check(_G["PlayerFrame"]:IsMovable(), "which makes the player frame movable")
check(_G["TargetFrame"]:IsMovable(), "and the target frame")

--[[ The border art tinted green while the mode is on, which is the original's
     own signal: these frames are always on screen, so "can I drag this right
     now" is not otherwise answerable without trying it. ]]--
eq(select(2, _G["PlayerFrameTexture"]:GetVertexColor()), 1,
        "and tints the art so you can see which")

frames:SetDragMode(false)
eq(frames:DragMode(), false, "off again")
check(not _G["PlayerFrame"]:IsMovable(), "and the frame is left alone")

--[[ **Back to whatever dark mode says, not to white.** Restoring white here
     would undo the tint every time the mode was switched off, which is a setting
     that quietly loses to a button. ]]--
cfg.darkMode = true
cfg.darkness = 0.4
frames:SetDragMode(true)
frames:SetDragMode(false)

eq(OB.Round(select(1, _G["PlayerFrameTexture"]:GetVertexColor()) * 100), 60,
        "the dark mode tint survives a trip through drag mode")
cfg.darkMode = false

--[[ **A position is stored as an offset from the centre of the screen**, which
     is the rule the meters and the action bars already follow: measured from an
     edge it is a different place on a different resolution. ]]--
--[[ Anchored CENTER-on-CENTER because that is the only anchor the stub resolves
     into screen coordinates -- see its GetLeft. In the client any anchor works;
     here anything else answers nil and the test would be measuring the stub. ]]--
_G["PlayerFrame"]:ClearAllPoints()
_G["PlayerFrame"]:SetPoint("CENTER", UIParent, "CENTER", -300, 150)
_G["PlayerFrame"]:SetWidth(200)
_G["PlayerFrame"]:SetHeight(100)

frames:StorePosition(_G["PlayerFrame"])

check(cfg.positions["PlayerFrame"] ~= nil, "a dragged frame remembers where it went")

--[[ Put back on the next load, and forgotten rather than moved back on reset --
     the client's own anchor is a place that exists on every resolution, which is
     more than any coordinate this addon could pick. ]]--
frames:PlaceFrames()
GLOBAL_point, GLOBAL_rel, GLOBAL_relPoint = _G["PlayerFrame"]:GetPoint()
eq(GLOBAL_relPoint, "CENTER", "and is placed from the centre on the next load")
check(_G["PlayerFrame"]:IsUserPlaced(),
        "marked user-placed, or the client puts it back")

frames:ResetPositions()
eq(next(cfg.positions), nil, "reset forgets rather than choosing a new place")
-- ---------------------------------------------------------------------------
-- taking a frame over
-- ---------------------------------------------------------------------------

--[[ **Per frame, not all at once.** Somebody who has turned the pet frame off
     should keep Blizzard's pet frame exactly as it was. ]]--
eq(frames:Owns({ setting = "replacePlayer" }), true, "the player frame is ours")

cfg.replacePet = false
eq(frames:Owns({ setting = "replacePet" }), false, "and the pet frame is not")
cfg.replacePet = true

frames:Apply()

--[[ The bar takes this addon's texture, which is what makes a unit frame look
     like it belongs beside the HUD rather than beside the client's own art. ]]--
check(getglobal("PlayerFrameHealthBar").barTexture ~= nil,
        "the health bar takes the shared texture")

--[[ **The client's naming is not consistent and cannot be derived.** The
     player's name string is `PlayerName`; the target's is
     `TargetFrameTextureFrameName`. A stub that regularised those would agree
     with a port that assumed a pattern, and one frame would be silently left
     alone in game. ]]--
local _, nameSize = getglobal("PlayerName"):GetFont()
eq(nameSize, cfg.nameSize, "the player's name takes the font size")

local _, targetSize = getglobal("TargetFrameTextureFrameName"):GetFont()
eq(targetSize, cfg.nameSize, "and so does the target's, under its own name")

--[[ The numbers are written on. The client keeps writing its own into these
     strings, so this rides the same events the frames do rather than hooking
     them. ]]--
Stub.player.health = 4382
Stub.player.healthMax = 8000
cfg.healthText = "maxpct"

frames:Apply()
eq(getglobal("PlayerFrameHealthBarText"):GetText(), "4.4k/8.0k (55%)",
        "and the health text says what was asked for")

--[[ **The power bar keeps the client's colour.** Mana is blue, rage is red and
     energy is yellow, and those are not preferences -- they are what the numbers
     mean. Only the font and the position are ours. ]]--
frames:StyleBar(getglobal("PlayerFrameManaBar"), 10, 0, 0, false, nil)
eq(getglobal("PlayerFrameManaBar").barColor, nil,
        "the power bar's colour is left to the client")

-- ---------------------------------------------------------------------------
-- portraits and dark mode
-- ---------------------------------------------------------------------------

--[[ **The art is the client's own**, not a copy. The addon this comes from ships
     Blizzard's UI-CLASSES-CIRCLES; it is already installed, so the client's path
     is used and there is nothing to relicense or keep in step with a patch. ]]--
Stub.target = { name = "Sylvie", isPlayer = true, class = "PRIEST" }
cfg.classPortrait = true

eq(frames:StylePortrait({ portrait = "TargetPortrait", unit = "target" }), true,
        "a player's portrait becomes their class icon")

--[[ Only for players. A wolf with a warrior's crest on it is worse than the
     model it replaced. ]]--
Stub.target = { name = "Wolf", isPlayer = false, class = "WARRIOR" }
eq(frames:StylePortrait({ portrait = "TargetPortrait", unit = "target" }), false,
        "an NPC keeps the model the client draws")

cfg.classPortrait = false

--[[ Dark mode tints rather than replaces, so it works whatever the client's art
     actually is -- which matters on a server that has restyled its frames. ]]--
cfg.darkMode = true
cfg.darkness = 0.4
frames:StyleFrameArt({ frame = "PlayerFrame" })

local tint = getglobal("PlayerFrameTexture").vertex
check(tint and tint[1] < 1, "dark mode tints the frame art", tostring(tint and tint[1]))

cfg.darkMode = false
frames:StyleFrameArt({ frame = "PlayerFrame" })
eq(getglobal("PlayerFrameTexture").vertex[1], 1, "and switching it off restores it")

-- ---------------------------------------------------------------------------
-- how much health a mob actually has
-- ---------------------------------------------------------------------------

--[[ **1.12 will not tell you, and MobHealth3 worked out that it does not have
     to.**

     `UnitHealthMax` on a mob answers 100, because what the client gives is a
     percentage. But the percentage and the damage you deal are two views of the
     same number: hit something for 340, watch it drop four percent, and it has
     eight and a half thousand. ]]--
EquadisClassicOverhaulDB.mobHealth = {}
OB.mobHealth = EquadisClassicOverhaulDB.mobHealth

eq(OB.MobHealthMax("Defias Thug", 22), nil, "nothing is known to begin with")

OB.LearnMobHealth("Defias Thug", 22, 340, 4)
eq(OB.MobHealthMax("Defias Thug", 22), 8500, "one observation gives an estimate")

--[[ Both halves accumulate rather than being divided on the spot. A hit that
     took "four percent" might have taken 3.6 or 4.4, and one sample carries
     that error into the answer where twenty average it away. ]]--
OB.LearnMobHealth("Defias Thug", 22, 850, 10)
eq(OB.MobHealthMax("Defias Thug", 22), 8500, "and a second refines it")

--[[ **Keyed by name and level together**, which is not fussiness: a level 22
     Defias Thug and a level 24 one are different creatures with the same name,
     and averaging them gives a number that is wrong for both. ]]--
eq(OB.MobHealthMax("Defias Thug", 24), nil,
        "the same name at another level is another creature")

--[[ **nil rather than a guess.** The frames fall back to the percentage, which
     is what the client would have shown anyway -- so a mob nobody has hit reads
     exactly as it does without any of this. ]]--
eq(OB.LearnMobHealth("Ghost", 10, 0, 4), false, "no damage teaches nothing")
eq(OB.LearnMobHealth("Ghost", 10, 400, 0), false, "and neither does no loss")

-- ---------------------------------------------------------------------------
-- a hunter who is not actually dead
-- ---------------------------------------------------------------------------

--[[ **Feign Death reports as death, at zero health** -- which in a raid is a
     healer watching somebody they believe is a corpse.

     **Kept internal rather than overriding UnitHealth.** The addon this comes
     from replaces the global, which fixes it for every addon at once and is
     exactly why it is wrong: a core function that lies is one every neighbour is
     now reading wrong, and none of them consented. ]]--
OB.feignedHealth = {}
Stub.player.hasTarget = true
Stub.target = { name = "Hunter", isPlayer = true, class = "HUNTER" }
Stub.player.dead = false
Stub.player.health = 3200

eq(frames:NoteFeign("target"), true, "a living player's health is remembered")

--[[ Recorded while alive and read while "dead". A value recorded at the moment
     of death would be zero, which is the number this exists to avoid. ]]--
Stub.player.dead = true
eq(frames:NoteFeign("target"), false, "and not overwritten once they drop")

local feignHealth = frames:HealthOf("target")
eq(feignHealth, 3200, "so the remembered number is what shows")

cfg.feignHealth = false
eq(frames:HealthOf("target"), Stub.player.health,
        "and the client's answer is used with it switched off")
cfg.feignHealth = true

Stub.player.dead = false

-- ---------------------------------------------------------------------------
-- compact, and re-targeting
-- ---------------------------------------------------------------------------

--[[ Sizes rather than a replacement texture, so it works on a server that has
     restyled its frames -- where a replacement would sit on top of something it
     was never drawn for. ]]--
cfg.compact = true
frames:StyleCompact()
eq(getglobal("TargetFrameHealthBar").height, 20, "compact shortens the health bar")

cfg.compact = false
frames:StyleCompact()
eq(getglobal("TargetFrameHealthBar").height, 29,
        "and switching it off restores the client's own number")

--[[ **Re-target somebody who vanished.** Feign Death, Vanish and Invisibility
     all clear your target, and the target you had is almost always the target
     you still want. Off, because it is the one thing here that acts on its
     own. ]]--
eq(cfg.retarget, false, "re-targeting is off")

frames.lastTarget = nil
Stub.target = { name = "Sylvie", isPlayer = true, class = "PRIEST" }
frames:NoteTarget()
eq(frames.lastTarget, "Sylvie", "who you were looking at is remembered")

cfg.retarget = true
Stub.player.hasTarget = false

eq(frames:Retarget(), false, "and with nobody there, nothing comes back")
eq(frames.lastTarget, nil, "so they are forgotten rather than chased")

cfg.retarget = false

Stub.target = nil
Stub.player.hasTarget = false
OB.profile.modulesEnabled.unitframes = nil
OB.BindSlots()

end

unitFrameTests()

-- 46. the names the panel answers to
--
-- The addon was Equadis' OmniBars and is Equadis' Classic Overhaul. Both sets
-- are kept, because nobody should have to relearn a slash command because a
-- title changed.
-- ---------------------------------------------------------------------------

function slashNameTests()

context = "slash names: "

wanted = { "/eqob", "/ob", "/omnibars", "/eq", "/co", "/eqco", "/equadis",
           "/classicoverhaul" }

registered = {}

for i = 1, 20 do
    local name = _G["SLASH_EQUADISOMNIBARS" .. i]
    if name then registered[name] = true end
end

missing = {}

for i = 1, table.getn(wanted) do
    if not registered[wanted[i]] then table.insert(missing, wanted[i]) end
end

eq(table.getn(missing), 0, "every name opens the panel",
        table.concat(missing, ", "))

--[[ **Numbered without a gap**, which is not a style point: the client stops
     reading at the first missing index, so `SLASH_X1` and `SLASH_X3` registers
     one command and silently drops the third. ]]--
gap = false
seenEnd = false

for i = 1, 20 do
    if _G["SLASH_EQUADISOMNIBARS" .. i] then
        if seenEnd then gap = true end
    else
        seenEnd = true
    end
end

check(not gap, "and the numbering has no hole for the client to stop at")

--[[ The handler is registered under the same key the names point at. A name
     with no handler is a command that silently does nothing. ]]--
check(SlashCmdList["EQUADISOMNIBARS"] ~= nil, "with a handler behind them")

end

slashNameTests()

-- 47. the Escape menu button
--
-- Where somebody looks for settings when they have forgotten the slash command,
-- which is most people most of the time.
-- ---------------------------------------------------------------------------

function gameMenuTests()

context = "game menu: "

OB = boot("ROGUE", 3)

--[[ The button is already there -- logging in installs it -- so what is checked
     is the result rather than the transition. ]]--
menuButton = OB.InstallGameMenuButton()
check(menuButton ~= nil, "a button is added to the game menu")
eq(menuButton:GetText(), OB.addonName, "carrying the addon's name")

--[[ **Under Options**, which is where it was asked for and where anybody
     looking for settings looks second. ]]--
local _, anchoredTo = menuButton:GetPoint(1)
eq(anchoredTo, GameMenuButtonOptions, "directly under Options")

--[[ **And whatever was under Options moves under us**, or two buttons sit on
     top of each other. Found by asking rather than by name: which button is
     there differs between clients, and a server may have added its own. ]]--
local _, keysAnchor = GameMenuButtonKeybindings:GetPoint(1)
eq(keysAnchor, menuButton, "and the button that was there moves below it")

--[[ **Made once, and this is the assertion that matters.**

     The guard is on the *frame* rather than on the namespace, because the
     namespace is rebuilt on a reload and the frame is not. A guard that checked
     only the namespace would add a second button every reload -- and the
     re-anchor above would find nothing to move, because the first insertion had
     already moved it. Two buttons on top of each other, and a menu taller every
     time. ]]--
menuHeightBefore = GameMenuFrame:GetHeight()

eq(OB.InstallGameMenuButton(), menuButton, "asking again gives the same one")
eq(GameMenuFrame:GetHeight(), menuHeightBefore,
        "and does not grow the menu a second time")

--[[ And the menu did grow once, or the bottom button is outside it -- which
     reads as the menu being broken rather than as one button being added. ]]--
check(GameMenuFrame:GetHeight() > 200,
        "the menu grew to hold it",
        "height: " .. GameMenuFrame:GetHeight())

end

gameMenuTests()

-- 48. one naming convention, everywhere
--
-- Twelve modules written over many sessions, each one reasonable on its own.
-- Consistency between them is the thing that decays quietly: nothing breaks,
-- the panel just reads like four people wrote it. Asserted rather than
-- reviewed, because a review is a thing somebody has to remember to do.
-- ---------------------------------------------------------------------------

function namingTests()

context = "naming: "

OB = boot("ROGUE", 3)

--[[ Every option row in the addon, gathered once. ]]--
allRows = {}

for i = 1, table.getn(OB.generalOptions or {}) do
    table.insert(allRows, { "general", OB.generalOptions[i] })
end

for id, m in pairs(OB.modules) do
    for i = 1, table.getn(m.options or {}) do
        table.insert(allRows, { id, m.options[i] })
    end
end

check(table.getn(allRows) > 200, "there are enough rows for this to matter",
        "rows: " .. table.getn(allRows))

--[[ **A switch is named for the thing, with the verb in front.**

     `showHotkeys`, not `hotkeyShow`. Both read fine alone and the second is
     wrong the moment there are two of them: a list sorted by key puts every
     `show*` together and scatters the `*Show`s through the alphabet, which is
     exactly what the slash prompt's generated help does. ]]--
badPrefix = {}

for i = 1, table.getn(allRows) do
    local key = allRows[i][2][2]

    if type(key) == "string" then
        if string.find(key, "Show$") or string.find(key, "Hide$") then
            table.insert(badPrefix, allRows[i][1] .. "." .. key)
        end
    end
end

eq(table.getn(badPrefix), 0, "the verb goes in front of the noun, not behind",
        table.concat(badPrefix, ", "))

--[[ **American spelling**, which is a standing instruction and the sort of thing
     that slips in one caption at a time. Checked on what the player reads
     rather than on the code, because a key nobody sees is not the point. ]]--
british = {}

for i = 1, table.getn(allRows) do
    local caption = allRows[i][2][1]

    if type(caption) == "string" then
        for _, word in ipairs({ "Colour", "Centre", "Grey", "Behaviour",
                                "Organise", "Customise" }) do
            if string.find(caption, word) then
                table.insert(british, caption)
            end
        end
    end
end

eq(table.getn(british), 0, "and the spelling is American throughout",
        table.concat(british, ", "))

--[[ **A colour setting is keyed `<thing>Color` -- unless it is the only one.**

     The rule exists to stop `headerColor` and `headerColour` living in
     different modules, and to make a module with four colours name them the
     same way. It does not apply to a module with *one*: `color` is the bar's
     colour and `bg` is the background, and `barColor` would be saying the same
     word twice.

     So three shapes are allowed and everything else is a slip: suffixed,
     indexed (`colors.1` for a combo point), and the two whole-subject names. ]]--
badColor = {}

for i = 1, table.getn(allRows) do
    local row = allRows[i][2]

    if row[3] == "color" and type(row[2]) == "string" then
        --[[ The name, with everything that is not the name taken off.

             A row can carry a scope in front -- `@variant:color`, which is how
             the power bar offers one swatch for a druid's three resources -- and
             a path behind, as `windows.1.bg` does. Neither is the name, and a
             rule that judged either would be judging the addressing rather than
             the naming. ]]--
        local leaf = row[2]

        local colon = string.find(leaf, ":")
        if colon then leaf = string.sub(leaf, colon + 1) end

        local dot = string.find(leaf, "%.[^%.]*$")
        if dot then leaf = string.sub(leaf, dot + 1) end

        local ok = string.find(leaf, "Color$")
                or string.find(row[2], "^colors%.")
                or leaf == "color" or leaf == "bg"

        if not ok then
            table.insert(badColor, allRows[i][1] .. "." .. row[2])
        end
    end
end

eq(table.getn(badColor), 0, "a colour setting says so in its key",
        table.concat(badColor, ", "))

--[[ **Every caption is Title Case**, which is the panel's own voice. Checked on
     the first letter of the first word, which is where it actually goes wrong --
     a lowercase caption in a column of capitals is visible from across the
     room. ]]--
lowerStart = {}

for i = 1, table.getn(allRows) do
    local caption = allRows[i][2][1]

    if type(caption) == "string" and caption ~= "" then
        local first = string.sub(caption, 1, 1)
        if first == string.lower(first) and first ~= string.upper(first) then
            table.insert(lowerStart, caption)
        end
    end
end

eq(table.getn(lowerStart), 0, "and every caption starts with a capital",
        table.concat(lowerStart, ", "))

--[[ **No two rows in one module share a key**, which is not a naming rule so
     much as the thing bad naming eventually causes: two settings that look
     different on the page and are the same value underneath. ]]--
dupes = {}

for id, m in pairs(OB.modules) do
    local seen = {}

    for i = 1, table.getn(m.options or {}) do
        local key = m.options[i][2]

        --[[ Section and header markers carry made-up keys that are allowed to
             repeat across modules but not within one. ]]--
        if type(key) == "string" then
            if seen[key] then table.insert(dupes, id .. "." .. key) end
            seen[key] = true
        end
    end
end

eq(table.getn(dupes), 0, "and no module names one key twice",
        table.concat(dupes, ", "))

end

namingTests()

-- 37. no row is built twice
-- ---------------------------------------------------------------------------

local function duplicateTests()

--[[ **A row built on two pages is one bug wearing three faces.**

     The Bars page builds every bar module's rows and lets visibility decide
     which are shown. Features have pages of their own, so building them there
     too built them twice -- and the second build claimed the same generated
     frame names, which took the first copy's caption away.

     In game that looked like three separate faults: the threat meter's settings
     appended to the Bars page, its sliders and checkboxes with no labels, and
     the damage meter's own tab coming up empty. ]]--
context = "no duplicate rows: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)
OB.TogglePanel()

--[[ Counted across every page rather than checked on one, because the failure
     is precisely that a row exists somewhere it should not. ]]--
local seen, duplicated = {}, {}

for c = 1, table.getn(OB.settings.categories) do
    local cat = OB.settings.categories[c]

    for r = 1, table.getn(cat.page.rows) do
        local widget = cat.page.rows[r]
        local w = widget.w

        if w and w.key and w.key ~= "" then
            local key = OB.WidgetKey(w)

            if seen[key] and seen[key] ~= cat.name then
                table.insert(duplicated, key
                        .. " (" .. seen[key] .. " and " .. cat.name .. ")")
            end

            seen[key] = cat.name
        end
    end
end

eq(table.getn(duplicated), 0, "no row is built on two pages",
        table.concat(duplicated, ", "))

--[[ Specifically: a feature's settings belong to its own tab and nowhere else.
     The Bars page is where this went wrong, so it is named rather than left to
     the sweep above. ]]--
local barsPage
for c = 1, table.getn(OB.settings.categories) do
    if OB.settings.categories[c].name == "OmniBars" then
        barsPage = OB.settings.categories[c].page
    end
end

local strays = {}
for r = 1, table.getn(barsPage.rows) do
    local w = barsPage.rows[r].w
    if w and w.module then
        local m = OB.modules[w.module]
        if m and m.feature then table.insert(strays, w.module .. "." .. w.key) end
    end
end

eq(table.getn(strays), 0, "and no subsystem's settings sit under Bars",
        table.concat(strays, ", "))

--[[ The threat meter's own tab still has them, so the fix removed a copy rather
     than the row. ]]--
check(OB.widgets["module:threat:width"] ~= nil, "the threat meter keeps its rows")
check(OB.widgets["module:damage:windows.1.width"] ~= nil,
        "and so does the damage meter")

--[[ **Every caption survives.** A label is a font string this file creates, not
     one the template names after the frame -- so two controls can no longer
     share one by generating the same name. Colour swatches always built their
     own, which is why they were the only kind that kept their labels. ]]--
local unlabelled = {}

for c = 1, table.getn(OB.settings.categories) do
    local cat = OB.settings.categories[c]

    for r = 1, table.getn(cat.page.rows) do
        local widget = cat.page.rows[r]
        local w = widget.w

        if w and w.caption and w.caption ~= "" and widget.label then
            if widget.label:GetText() ~= w.caption then
                table.insert(unlabelled, cat.name .. ":" .. w.key)
            end
        end
    end
end

eq(table.getn(unlabelled), 0, "and every control still carries its caption",
        table.concat(unlabelled, ", "))

end

duplicateTests()
navigationTests()
-- ---------------------------------------------------------------------------
-- report
-- ---------------------------------------------------------------------------

print("")
-- ---------------------------------------------------------------------------
-- 49. chat commands
--
-- A slash command is a keybinding you can type, and 1.12 gives you one of those
-- and not the other. A fixed list: /fps, /hud, /combatlog, /cl, /walk, /sit,
-- /sheath, /autorun.
-- ---------------------------------------------------------------------------

function chatCommandTests()

context = "chat commands: "

EquadisClassicOverhaulDB = nil
OB = boot("ROGUE", 3)

OB.RegisterCommands()

check(SlashCmdList["EQOBCMD_WALK"] ~= nil, "the commands are registered")
eq(getglobal("SLASH_EQOBCMD_WALK1"), "/walk", "under the word they answer to")
check(SlashCmdList["EQOBCMD_CL"] ~= nil,
        "and a second word is a second command, not an alias inside one")

-- ---------------------------------------------------------------------------
-- what a command does when you type it
-- ---------------------------------------------------------------------------

--[[ **The client's own binding, run through the API it is defined in terms of.**

     1.12 has no way to invoke a binding by name -- the Lua is held internally,
     keyed to a key -- so `TOGGLERUN` is run by calling `ToggleRun`, which is the
     same thing said twice rather than a workaround. ]]--
Stub.ran = {}
SlashCmdList["EQOBCMD_WALK"]("")
eq(Stub.lastRan, "ToggleRun", "typing the command runs the binding's own call")

--[[ Sitting is the one that needs two answers: vanilla and the clients built on
     it disagree about which function sits you down, and the emote works on all
     of them. The stub deliberately lacks the specific call, so the fallback is
     what a test gets without asking. ]]--
SlashCmdList["EQOBCMD_SIT"]("")
eq(Stub.lastRan, "DoEmote", "and falls back to the emote where it must")

--[[ A builtin is this addon's own, for the things the client has no binding for
     -- or where the useful version does more. `/fps` reports latency as well,
     which is the number you actually wanted. ]]--
Stub.chat = {}
SlashCmdList["EQOBCMD_FPS"]("")

GLOBAL_said = table.concat(Stub.chat, " ")
check(string.find(GLOBAL_said, "60.0 fps", 1, true), "a builtin runs too")
check(string.find(GLOBAL_said, "42 ms", 1, true),
        "and says the part the client will not")

--[[ Combat logging is a toggle the client exposes only as a setter that also
     answers: no argument reads, an argument writes and returns what it became. ]]--
Stub.combatLogging = false
SlashCmdList["EQOBCMD_CL"]("")
eq(Stub.combatLogging, true, "combat logging goes on")
SlashCmdList["EQOBCMD_CL"]("")
eq(Stub.combatLogging, false, "and off again")

-- ---------------------------------------------------------------------------
-- not taking somebody else's word
-- ---------------------------------------------------------------------------

--[[ **`SlashCmdList` is flat and first come wins.** Nothing owns a word:
     writing `SLASH_FOO1 = "/sit"` takes `/sit` from whoever had it, silently,
     and they find out when a player complains. So every name is checked against
     the same walk the client does before it is taken. ]]--
SlashCmdList["SOMEBODYELSE"] = function() end
SLASH_SOMEBODYELSE1 = "/dance"

eq(OB.SlashOwner("dance"), "SOMEBODYELSE", "an owned word is seen to be owned")
eq(OB.SlashOwner("nobodyhasthis"), nil, "and a free one is free")

--[[ One of our own answering to a word is not a collision -- registering twice
     in a session is this function running twice. ]]--
eq(OB.SlashTakenByOther("walk"), nil, "and one of ours does not count")

--[[ A word somebody else has is left alone and said out loud, rather than
     taken. Said once with the whole list, because three lines about words you
     did not know you had is noise and one is information. ]]--
SLASH_SOMEBODYELSE1 = "/walk"
SlashCmdList["EQOBCMD_WALK"] = nil
setglobal("SLASH_EQOBCMD_WALK1", nil)

Stub.chat = {}
OB.RegisterCommands()

check(SlashCmdList["EQOBCMD_WALK"] == nil, "a word somebody else has is not taken")
check(string.find(table.concat(Stub.chat, " "), "walk", 1, true),
        "and the addon says which it left alone")

SLASH_SOMEBODYELSE1 = nil
SlashCmdList["SOMEBODYELSE"] = nil
OB.RegisterCommands()

-- ---------------------------------------------------------------------------
-- the client that can run a binding properly
-- ---------------------------------------------------------------------------

--[[ **`RunBinding` where the client has it**, because that is the client doing
     exactly what it does when the key is pressed, including anything a server
     has changed about the binding. The table is the fallback, not the
     preference. ]]--
RunBinding = function(command) Stub.lastRan = "RunBinding:" .. command end

check(OB.CanRunBinding("STRAFELEFT"),
        "with RunBinding present, any binding can be run")

OB.RunBinding("TOGGLERUN")
eq(Stub.lastRan, "RunBinding:TOGGLERUN",
        "and is run by the client rather than by us")

RunBinding = nil
check(not OB.CanRunBinding("STRAFELEFT"),
        "and without it, only what the table knows")

--[[ **The label is the client's own string**, which is what somebody read in the
     Key Bindings panel. The raw command is the fallback, which is what a
     server's own binding answers to. ]]--
eq(OB.BindingLabel("TOGGLERUN"), "Toggle Run/Walk", "the client's label is used")
eq(OB.BindingLabel("SERVERTHING"), "SERVERTHING",
        "and an unlabelled one falls back to its command name")

--[[ A builtin is written `@fps`, which is not decoration: `@` cannot appear in a
     binding command name, so one namespace holds both kinds and no binding a
     server invents can collide with one of ours. ]]--
check(OB.CommandBuiltin("@fps") ~= nil, "a builtin is found by its marker")
check(OB.CommandBuiltin("TOGGLERUN") == nil, "and a binding is not one")

Stub.chat = {}
eq(OB.PrintCommands(), 8, "and the whole list can be printed")

-- ---------------------------------------------------------------------------
-- hiding the interface without losing the way back
-- ---------------------------------------------------------------------------

--[[ **`UIParent:Hide()` takes the chat frame with it**, so the command that
     brings the interface back cannot be typed. While it is hidden the chat frame
     and its edit box move onto WorldFrame for as long as the box is open.

     The watcher that notices cannot be a UIParent child either, or its OnUpdate
     stops with everything else. ]]--
OB.ToggleHud()
check(not UIParent:IsShown(), "the interface goes")
eq(OB.hudWatcher:GetParent(), WorldFrame, "watched from outside what was hidden")
check(OB.hudWatcher:IsShown(), "and watching")

ChatFrameEditBox:Show()
OB.WatchHudChat()
eq(ChatFrameEditBox:GetParent(), WorldFrame,
        "opening chat moves it out from under the hidden interface")

ChatFrameEditBox:Hide()
OB.WatchHudChat()
eq(ChatFrameEditBox:GetParent(), UIParent, "and closing it puts it back")

OB.ToggleHud()
check(UIParent:IsShown(), "the interface comes back")
check(not OB.hudWatcher:IsShown(), "and the watcher stops")

end

chatCommandTests()


-- ---------------------------------------------------------------------------
-- 50. long comments, which 1.12 and the harness disagree about
--
-- **Lua 5.0 nests long brackets and Lua 5.1 does not.** A `[[` inside an open
-- long comment opens a second level in the client, so it takes two `]]` to
-- close -- while the LuaJIT this suite runs closes at the first.
--
-- A file with one nested opener therefore compiles here and, in the game,
-- swallows the next comment and every line of code between the two. Sometimes
-- that is a syntax error and sometimes it silently deletes a function. Either
-- way the client says nothing: it abandons the file, carries on with the next,
-- and the module never registers.
--
-- That is what happened to the Chat tab. An edit split a comment in two and
-- left the head unterminated, the next comment nested inside it, and chat.lua
-- stopped compiling on 1.12 while every test here passed.
--
-- Both rules are checked, because they fail differently: an unterminated
-- comment is caught by either Lua, and a nested one only by 5.0.
-- ---------------------------------------------------------------------------

context = "long comments: "

function scanComments(path)
    local handle = io.open(path)
    if not handle then return nil end

    local src = handle:read("*a")
    handle:close()

    local depth, i, line = 0, 1, 1
    local opened, nested = nil, nil

    while i <= string.len(src) do
        if string.sub(src, i, i) == "\n" then line = line + 1 end

        if string.sub(src, i, i + 3) == "--[[" and depth == 0 then
            depth, opened, i = 1, line, i + 4

        --[[ The 5.0 rule. Any long bracket while already inside one opens a
             level there and does not here. ]]--
        elseif string.sub(src, i, i + 1) == "[[" and depth > 0 then
            depth = depth + 1
            if not nested then nested = line end
            i = i + 2

        elseif string.sub(src, i, i + 1) == "]]" and depth > 0 then
            depth, i = depth - 1, i + 2
        else
            i = i + 1
        end
    end

    return depth, opened, nested
end

GLOBAL_files = { "core.lua", "config.lua", "render.lua", "layout.lua",
                 "hud.lua", "commands.lua", "options.lua", "slash.lua",
                 "selftest.lua" }

GLOBAL_handle = io.open(path("EquadisClassicOverhaul.toc"))

for GLOBAL_line in GLOBAL_handle:lines() do
    GLOBAL_line = string.gsub(GLOBAL_line, "%s+$", "")

    if string.find(GLOBAL_line, "%.lua$") and not string.find(GLOBAL_line, "^#") then
        table.insert(GLOBAL_files, (string.gsub(GLOBAL_line, "\\", "/")))
    end
end

GLOBAL_handle:close()

for GLOBAL_i = 1, table.getn(GLOBAL_files) do
    GLOBAL_f = GLOBAL_files[GLOBAL_i]
    GLOBAL_depth, GLOBAL_opened, GLOBAL_nested = scanComments(path(GLOBAL_f))

    if GLOBAL_depth then
        eq(GLOBAL_nested, nil, GLOBAL_f .. " has no nested long bracket",
                "1.12 nests it; a comment at line " .. tostring(GLOBAL_nested)
                        .. " would swallow the next one and the code between")

        eq(GLOBAL_depth, 0, GLOBAL_f .. " closes every long comment it opens",
                "unterminated from line " .. tostring(GLOBAL_opened))
    end
end

check(table.getn(GLOBAL_files) > 20, "and every file in the TOC was scanned",
        table.getn(GLOBAL_files) .. " files")

-- ---------------------------------------------------------------------------
-- §51 one prefix, one colour, and it says which part is talking
-- ---------------------------------------------------------------------------

--[[ **`Eq <part>:` in `#008b8b` on every line this addon writes.**

     Recognisable in a channel scrolling past without anybody having to read it,
     and it names the part -- so a line about the chat scan says so instead of
     eleven features all announcing themselves as the same word. ]]--
Stub.chat = {}
OB.Print("something happened", "ChatScan")

GLOBAL_said = table.concat(Stub.chat, " ")
check(string.find(GLOBAL_said, "|cff008b8bEq ChatScan:", 1, true),
        "the prefix is teal and names the part", GLOBAL_said)

--[[ The body stays white: colouring a whole message makes it a banner rather
     than a sentence, and several of these run to three lines. ]]--
check(string.find(GLOBAL_said, "|cffffffff something happened", 1, true),
        "and the message itself is not coloured with it", GLOBAL_said)

Stub.chat = {}
OB.Print("no part given")
check(string.find(table.concat(Stub.chat, " "), "Eq Overhaul:", 1, true),
        "an unnamed message is the addon itself",
        table.concat(Stub.chat, " "))

--[[ **Every file that prints names itself once, at the top.**

     A source check rather than a behavioural one, because the failure it
     catches is a new `OB.Print` written directly in a module: it works, it
     looks right, and it quietly says "Overhaul" where the reader needed to know
     which of eleven things was talking. Nothing observable tells that apart
     from a correct call, so the test has to read the source.

     `core.lua` defines it and `hud.lua` speaks for the addon as a whole -- the
     login banner and the missing-dependency warnings belong to no one part.

     Written as a function rather than inline because the main chunk is close to
     1.12's two-hundred-local ceiling and every `for` control variable is one of
     them. See the constraint in HANDOFF. ]]--
GLOBAL_direct = (function()
    local owners = { ["core.lua"] = true, ["hud.lua"] = true }
    local out = {}

    for i = 1, table.getn(GLOBAL_files) do
        local name = GLOBAL_files[i]

        if not owners[name] then
            local handle = io.open(path(name))

            if handle then
                local n = 0

                for line in handle:lines() do
                    n = n + 1

                    --[[ The declaration itself is the one legitimate mention. ]]--
                    if string.find(line, "OB%.Print%(")
                            and not string.find(line, "local function Say") then
                        table.insert(out, name .. ":" .. n)
                    end
                end

                handle:close()
            end
        end
    end

    return out
end)()

eq(table.getn(GLOBAL_direct), 0,
        "no file prints without naming itself",
        table.concat(GLOBAL_direct, ", "))

print(string.rep("-", 70))
for i = 1, table.getn(failures) do
    print("FAIL  " .. failures[i])
end
if failed == 0 then print("no failures") end
print(string.rep("-", 70))
print(string.format("%d passed, %d failed", passed, failed))



local faked = Stub.UnknownMethods()
if table.getn(faked) > 0 then
    print("")
    print("stubbed by fallback (check for typos in API names):")
    for i = 1, table.getn(faked) do print("  " .. faked[i]) end
end

os.exit(failed == 0 and 0 or 1)
