--[[ Equadis' OmniBars :: test run

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

local files = {
    "core.lua", "config.lua", "render.lua", "layout.lua", "hud.lua",
    "modules/power.lua", "modules/combopoints.lua", "modules/swing.lua",
    "modules/health.lua", "modules/range.lua", "modules/druidmana.lua",
    "options.lua", "slash.lua", "selftest.lua",
}

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
    Stub.player.spellCount = opts.spellCount or 0
    Stub.player.talents = opts.talents or {}
    Stub.tooltips = opts.tooltips or {}
    Stub.interactRefuses = false
    Stub.actionRange = opts.actionRange

    -- a client mod either injected UnitXP before Lua ran or it did not
    Stub.SetUnitXP(opts.unitXP)

    --[[ Every boot starts from an empty saved-variables table unless a test
         hands one in deliberately. Sharing one across tests looks convenient and
         is not: an assignment made in one section then silently changes what the
         next section boots into. ]]--
    EquadisOmniBarsDB = opts.savedVariables or nil

    loadAddon()
    Stub.FireEvent("VARIABLES_LOADED")
    Stub.FireEvent("PLAYER_ENTERING_WORLD")
    Stub.Tick(0.05, 3)

    return EquadisOmniBars
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

check(OB.tickers.pulse.Observe(t, 101, 60, 40), "a gain is reported as a tick")
eq(t.start, 101, "a real tick re-anchors the cycle")

-- capped: no gain for six seconds, so the cycle advances by whole periods and
-- the phase stays on the beat rather than restarting off it
check(not OB.tickers.pulse.Observe(t, 107, 100, 100), "no gain is not a tick")
eq(t.start, 107, "capped cycles advance by whole periods")
near((107 - t.start) / t.period, 0, 0.0001, "phase stays on the beat")

-- ---------------------------------------------------------------------------
-- 5. the five second rule
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
for id, s in pairs(slots) do s.hide = true end
slots.resource.hide = false
slots.health.hide = false
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
slots.resource.hide = true
OB.BindSlots()
OB.NudgeSlot("health", 0, 20)
eq(slots.health.y, blockedFrom + 20, "a hidden slot does not block movement")

for id, s in pairs(slots) do s.hide = false end
OB.BindSlots()

-- coordinates clamp to one shared range
OB.NudgeSlot("health", 999999, 0)
eq(slots.health.x, OB.POS_MAX, "x clamps to the shared maximum")

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

-- dotted option keys read and write nested values
local root = { colors = { { 1, 0, 0, 1 }, { 0, 1, 0, 1 } } }
eq(OB.Get(root, "colors.2.2"), 1, "a dotted path reads a nested value")
OB.Set(root, "colors.1.1", 0.5)
eq(root.colors[1][1], 0.5, "a dotted path writes one")

-- ---------------------------------------------------------------------------
-- 14. RogueBars import
-- ---------------------------------------------------------------------------

context = "roguebars import: "

EquadisOmniBarsDB = nil
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
local saved = EquadisOmniBarsDB
RogueBarsConfig.Scale = 0.7
OB = boot("ROGUE", 3, { savedVariables = saved })
near(OB.profile.scale, 1.4, 0.001, "a second login does not re-import over tuned values")

--[[ A scale saved before the ceiling came down is brought inside it rather than
     refused, so the slider can always reach the value the profile holds. ]]--
OB.profile.scale = 1.9
saved = EquadisOmniBarsDB
OB = boot("ROGUE", 3, { savedVariables = saved })
near(OB.profile.scale, OB.SCALE_MAX, 0.001, "a scale above the ceiling clamps on load")

RogueBarsConfig = nil

-- ---------------------------------------------------------------------------
-- 15. profiles are shared, and switching works
-- ---------------------------------------------------------------------------

context = "profiles: "
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3, { name = "Rogueone" })

OB.profile.slots.resource.y = 42
local db = EquadisOmniBarsDB

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
eq(OB.profile.slots.resource.y, 98, "resetting restores this profile's defaults")
eq(EquadisOmniBarsDB.profiles.Default.slots.resource.y, 42,
        "and leaves the other profile alone")

OB.SetProfile("Default")
OB.DeleteProfile("Raiding")
check(EquadisOmniBarsDB.profiles.Raiding == nil, "a deleted profile is gone")

OB.DeleteProfile("Default")
check(EquadisOmniBarsDB.profiles.Default ~= nil, "Default cannot be deleted")

-- ---------------------------------------------------------------------------
-- 16. visibility rules
-- ---------------------------------------------------------------------------

context = "visibility: "
EquadisOmniBarsDB = nil
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
OB.profile.slots.health.hide = true
OB.Toggle()
check(not OB.modules.health.frame:IsShown(), "a hidden slot hides its bar")
check(OB.modules.power.frame:IsShown(), "and leaves the others alone")
OB.profile.slots.health.hide = false

-- ---------------------------------------------------------------------------
-- 17. test mode drives every bound module
-- ---------------------------------------------------------------------------

context = "test mode: "
EquadisOmniBarsDB = nil
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
EquadisOmniBarsDB = nil
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

--[[ The bar selector offers this class's bars, and picking one moves the page.

     The occupant dropdown that used to sit beside it is gone with the assignment
     layer, so what is left to check is that the selector alone drives the page. ]]--
local selector = _G["EqOBBarSelector"]
check(selector ~= nil, "the bar selector exists")
if selector then
    local buttons = Stub.OpenMenu(selector)
    eq(table.getn(buttons), table.getn(OB.BarsForClass()),
            "it offers exactly this class's bars")

    check(Stub.ChooseMenu(selector, "extras"), "choosing a bar applies")
    eq(OB.panel.bar, "extras", "and the page follows it")
end

check(_G["EqOBOccupant"] == nil, "there is no occupant dropdown any more")

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

-- a dependent row hides when its condition is off
OB.panel.bar = "health"
OB.RefreshPanel()
local lowColor = _G["EqOBSwatch_module_health_lowColor"]
check(lowColor ~= nil, "the low health colour swatch exists")
if lowColor then
    check(not lowColor:IsShown(), "it is hidden while the low health option is off")
    OB.profile.modules.health.lowEnable = true
    OB.RefreshPanel()
    check(lowColor:IsShown(), "and shown once the option is on")
    OB.profile.modules.health.lowEnable = false
end

--[[ The shape the panel is supposed to have, asserted directly.

     This is the exact symptom that shipped: one sidebar entry and no rows. It
     was invisible to the suite because nothing checked that the panel had been
     built *completely* -- only that individual controls worked once it had. ]]--
eq(table.getn(OB.settings.categories), 4, "the panel has all four categories")

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
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)

local run = SlashCmdList["EQUADISOMNIBARS"]
check(run ~= nil, "the slash handler is registered")

try("help prints without error", function() run("help") end)

run("scale 120")
near(OB.profile.scale, 1.2, 0.001, "a global option is settable")

-- camelCase keys have to work from a prompt nobody shift-types
run("fontsize 16")
eq(OB.profile.fontSize, 16, "a camelCase key resolves case-insensitively")

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
-- 21. the range readout picks a backend the client can actually run
-- ---------------------------------------------------------------------------

context = "range backend: "

OB = boot("HUNTER", 0)
eq(OB.modules.distance.backend.id, "bands",
        "with no distance API the readout falls back to bands")
eq(OB.modules.distance.frame.visible, 4, "and draws four segments")

OB = boot("HUNTER", 0, { unitXP = true })
eq(OB.modules.distance.backend.id, "precise",
        "a client that can measure gets the precise readout")
eq(OB.modules.distance.frame.visible, 1, "which is one continuous bar")

-- the surplus segments are parked, not destroyed, so the shape can change back
check(OB.modules.distance.frame.count == 4, "the frames the shape does not need still exist")
check(not OB.modules.distance.frame.bars[4]:IsShown(), "they are simply hidden")

-- a forced backend that cannot run here falls back rather than drawing nothing
OB.profile.modules.distance.backend = "precise"
Stub.SetUnitXP(false)
OB.modules.distance:Probe()
eq(OB.modules.distance.backend.id, "bands", "a forced backend that cannot run falls back")
eq(OB.modules.distance.frame.visible, 4, "and the shape follows it back")

--[[ Forcing a backend that cannot run usually falls back to the one already in
     use, so a message keyed off a *change* of backend would say nothing in the
     one case where the user is waiting to be told something. ]]--
OB = boot("HUNTER", 0)
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

-- the action backend is unavailable until it is told which action to watch
OB.profile.modules.distance.backend = "action"
OB.modules.distance:Probe()
eq(OB.modules.distance.backend.id, "bands", "the action backend needs a slot to watch")

OB.profile.modules.distance.actionSlot = 25
OB.modules.distance:Probe()
eq(OB.modules.distance.backend.id, "action", "and runs once it has one")

--[[ Capture arms a wrapper around the global UseAction -- there is no
     hooksecurefunc in 1.12 -- which records the next action pressed and then
     stands down. The wrapper must still call whatever it displaced, or arming
     capture once would break the player's action bars for the session. ]]--
local capture = OB.optionIndex.modules.distance.capture
OB.ApplyOption(capture, true)
check(OB.modules.distance.capturing, "arming capture watches for the next action")

UseAction(42, nil, nil)
eq(OB.profile.modules.distance.actionSlot, 42, "pressing an action captures its slot")
eq(Stub.lastAction, 42, "and the action itself still fires")
check(not OB.modules.distance.capturing, "capture stands down after one press")
check(not OB.profile.modules.distance.capture, "and the checkbox clears itself")

UseAction(7, nil, nil)
eq(OB.profile.modules.distance.actionSlot, 42, "a later press is not captured")
eq(Stub.lastAction, 7, "but still fires")

-- ---------------------------------------------------------------------------
-- 22. bands, including the answer that is not an answer
-- ---------------------------------------------------------------------------

context = "range bands: "
OB = boot("HUNTER", 0, { hasTarget = true })

local range = OB.modules.distance

local function readRange(distance)
    Stub.player.targetDistance = distance
    range.nextPoll = 0
    Stub.Tick(0.05, 2)
    return range.band
end

eq(readRange(5), 1, "inside duel range is the dead zone")
eq(readRange(10.5), 2, "past duel but inside trade is the dead zone edge")
eq(readRange(20), 3, "past trade but inside inspect is shootable")
eq(readRange(40), 4, "past inspect is out of range")

--[[ CheckInteractDistance answers nil for a unit you cannot interact with, which
     every hostile mob is. Reading that as an error rather than as "too far"
     would blank the readout on precisely the targets it exists for. ]]--
Stub.interactRefuses = true
eq(readRange(5), 4, "a unit that refuses interaction reads as far, not as an error")
Stub.interactRefuses = false

Stub.player.hasTarget = false
range.nextPoll = 0
Stub.Tick(0.05, 2)
check(range.band == nil, "no target means no reading at all")

--[[ The preview has to walk every band the live readout can produce, including
     the ~1.2 yard sliver between duel and trade range. A sweep coarse enough to
     step over it would leave a user convinced that band is broken. ]]--
OB.SetTestMode(true)

local bandsSeen = {}
for i = 1, 400 do
    Stub.Tick(0.05, 1)
    if range.band then bandsSeen[range.band] = true end
end

OB.SetTestMode(false)

local bandsCount = 0
for _ in pairs(bandsSeen) do bandsCount = bandsCount + 1 end
eq(bandsCount, 4, "the preview walks every band, narrow ones included")

-- ---------------------------------------------------------------------------
-- 23. the precise readout
-- ---------------------------------------------------------------------------

context = "range precise: "
OB = boot("HUNTER", 0, { unitXP = true, hasTarget = true })

range = OB.modules.distance
local rangeCfg = OB.profile.modules.distance
rangeCfg.maxRange = 40
rangeCfg.deadZone = 8

local rangeBar = range.frame.bars[1]

local function readPrecise(distance)
    Stub.player.targetDistance = distance
    range.nextPoll = 0
    Stub.Tick(0.05, 2)
    return range.band
end

eq(readPrecise(0), 1, "point blank is inside the dead zone")
eq(range.yards, 0, "and the distance is reported, not just the band")
near(rangeBar.fill.width, rangeBar:GetWidth(), 0.5, "adjacent fills the bar")

eq(readPrecise(20), 3, "past the dead zone and inside the maximum is shootable")
near(rangeBar.fill.width, rangeBar:GetWidth() * 0.5, 0.5,
        "half the maximum range is half a bar")

eq(readPrecise(80), 4, "past the maximum is out of range")
check(not rangeBar.fill.shown, "and the bar is empty rather than negative")

check(rangeBar.ticks and rangeBar.ticks[1] and rangeBar.ticks[1].shown,
        "the dead zone edge is marked")
near(rangeBar.ticks[1].points[1][4], rangeBar:GetWidth() * (1 - 8 / 40), 0.5,
        "at the point the fill crosses it")

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
OB.profile.slots.distance.hide = false
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

EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3, { offSpeed = 1.7 })
OB.profile.slots.distance.hide = false
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

-- the distance readout does the same with no target
Stub.player.hasTarget = true
OB.modules.distance.nextPoll = 0
Stub.Tick(0.05, 3)
check(OB.modules.distance.frame:IsShown(), "a target gives the distance bar something to say")

Stub.player.hasTarget = false
OB.modules.distance.nextPoll = 0
Stub.Tick(0.05, 3)
check(not OB.modules.distance.frame:IsShown(), "no target and it hides rather than sitting empty")

-- ---------------------------------------------------------------------------
-- 27. slots became bars
--
-- The migration that renamed six slots into eight bars, dropped the assignment
-- layer and restacked. A tuned layout has to survive the rename intact -- the
-- rename is the whole reason a migration exists rather than a defaults change.
-- ---------------------------------------------------------------------------

context = "migration: "

EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3, { savedVariables = {
    version = 1,
    migrated = { roguebars = true },
    chars = { ["Turtle WoW - TestROGUE"] = "Default" },
    profiles = { Default = {
        schema = 2,
        assign = { ["*"] = { aux = "none" }, ROGUE = { points = "health" } },
        slots = {
            -- a layout somebody tuned: narrower, taller, nudged right
            swingA = { x = 40, y = 93, w = 150, h = 20, textSize = 14,
                       hide = false, flip = true, bg = { 1, 0, 0, 0.3 } },
            points = { x = 40, y = 115, w = 150, h = 10 },
            aux    = { x = 40, y = 38,  w = 150, h = 14 },
        },
        modules = {
            swing_main = { decimals = 2, deplete = true },
            range = { maxRange = 41 },
        },
    } },
} })

eq(OB.profile.schema, 3, "an old profile is migrated forward")

-- geometry survives the rename, all of it except the Y the restack rewrites
local mainhand = OB.profile.slots.mainhand
check(mainhand ~= nil, "swingA became mainhand")
eq(mainhand.w, 150, "a tuned width survives")
eq(mainhand.h, 20, "and height")
eq(mainhand.x, 40, "and X")
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
eq(OB.profile.modules.distance.maxRange, 41, "range became distance")
check(OB.profile.modules.swing_main == nil, "and the old keys are gone")

-- the assignment layer is dropped outright, including a deliberate one
check(OB.profile.assign == nil, "the assignment table is dropped")
eq(OB.bound.extras and OB.bound.extras.id, "combopoints",
        "so a slot that had been reassigned goes back to its own module")

--[[ Restacked in the new order, and the cluster stays where it was rather than
     jumping to the shipped default -- the top of the old stack becomes the top
     of the new one. ]]--
eq(OB.profile.slots.health.y, 115, "the stack keeps its old top")

local lastY
for i = 1, table.getn(OB.barOrder) do
    local bar = OB.profile.slots[OB.barOrder[i]]
    if lastY then
        check(bar.y < lastY, OB.barOrder[i] .. " sits below the bar before it")
    end
    lastY = bar.y
end

-- a profile already on schema 3 is left entirely alone
local tuned = EquadisOmniBarsDB
tuned.profiles.Default.slots.health.y = 400
OB = boot("ROGUE", 3, { savedVariables = tuned })
eq(OB.profile.slots.health.y, 400, "a current profile is not restacked again")

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
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)
breakFrame("EqOBCheck_global_x_audible")
try("a bad control does not stop the build", function() OB.TogglePanel() end)
unbreakFrame()

check(OB.settings ~= nil, "the panel is still built")
eq(table.getn(OB.settings.categories), 4, "and still has all four categories")
check(OB.widgets["global::audible"] == nil, "the failed row was dropped, not half-placed")
eq(table.getn(OB.panelFaults), 1, "exactly one fault was recorded")
check(string.find(OB.panelFaults[1].label or "", "audible") ~= nil,
        "and it names the control that failed")

-- (2) a page fault costs that page's remainder, not the pages after it.
--     This is the regression, in the exact shape it shipped.
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)
breakFrame("EqOBProfileName")
try("a bad page does not stop the panel", function() OB.TogglePanel() end)
unbreakFrame()

check(OB.settings ~= nil, "the panel survives a page that throws")
eq(table.getn(OB.settings.categories), 4, "every category still exists")
check(OB.settings.btnTest ~= nil, "the chrome after the pages is still built")
eq(OB.settings.selected, "General", "and a category is selected")

-- (3) an update fault hides one row, and says so exactly once
EquadisOmniBarsDB = nil
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
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)
breakFrame("EquadisOmniBarsSettings")
try("an unbuildable panel does not raise", function() OB.TogglePanel() end)
unbreakFrame()

check(OB.settings == nil, "a failed build is not cached as the panel")
check(type(OB.panelDead) == "string", "the reason is kept")

local framesBefore = table.getn(Stub.Frames())
try("a second attempt does not rebuild", function() OB.TogglePanel() end)
eq(table.getn(Stub.Frames()), framesBefore,
        "and does not leak a second set of globally named widgets")

-- (5) layout is pure: running it twice with no update between changes nothing
EquadisOmniBarsDB = nil
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
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)

try("the self-test runs", function() OB.RunSelfTest() end)
check(OB.selfTestResult ~= nil, "it records a result")

if OB.selfTestResult then
    eq(OB.selfTestResult.failed, 0, "a healthy boot has no failures")
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
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)

local savedUnitMana = UnitMana
UnitMana = nil
OB.RunSelfTest()
UnitMana = savedUnitMana

check(OB.selfTestResult.failed > 0, "a missing API fails the run")
check(failureMentioning("UnitMana"), "and the failure names it")

-- a font string with no font: the bug that shipped
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)
table.insert(OB.texts, OB.container:CreateFontString(nil, "OVERLAY"))
OB.RunSelfTest()
check(failureMentioning("font strings have no font"),
        "an unfonted font string is caught")

-- a widget that lost its anchor
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3)
OB.bound.resource.frame:ClearAllPoints()
OB.RunSelfTest()
check(failureMentioning("not anchored"), "an unanchored bar is caught")
OB.Refresh(true)

-- a value outside its own maximum
EquadisOmniBarsDB = nil
OB = boot("ROGUE", 3, { power = 100, powerMax = 100 })
Stub.player.health = 5000
Stub.player.healthMax = 3000
OB.RunSelfTest()
check(failureMentioning("out of a maximum"), "a value above its maximum is caught")
Stub.player.health = 2400

-- the backend note reports what actually happened
EquadisOmniBarsDB = nil
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
    EquadisOmniBarsDB = nil

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
-- report
-- ---------------------------------------------------------------------------

print("")
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
