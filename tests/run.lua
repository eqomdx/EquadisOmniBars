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
    "modules/health.lua", "options.lua", "slash.lua",
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
    Stub.loadedAddons = opts.loadedAddons or {}

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

local expected = {
    WARRIOR = { power = 1, points = nil,           swingB = "swing_off" },
    PALADIN = { power = 0, points = nil,           swingB = "swing_off" },
    HUNTER  = { power = 0, points = nil,           swingB = nil },
    ROGUE   = { power = 3, points = "combopoints", swingB = "swing_off" },
    PRIEST  = { power = 0, points = nil,           swingB = "swing_off" },
    SHAMAN  = { power = 0, points = nil,           swingB = "swing_off" },
    MAGE    = { power = 0, points = nil,           swingB = "swing_off" },
    WARLOCK = { power = 0, points = nil,           swingB = "swing_off" },
    DRUID   = { power = 3, points = "combopoints", swingB = "swing_off" },
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
    eq(occupant("swingA"), "swing_main", "swingA holds main hand")
    eq(occupant("swingB"), want.swingB, "swingB occupant")
    eq(occupant("points"), want.points, "points occupant")

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
local mh = OB.modules.swing_main.frame
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
check(total <= OB.profile.slots.points.w and total >= OB.profile.slots.points.w - 5,
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
-- 10. reassignment: a hunter's range slot, done by hand
-- ---------------------------------------------------------------------------

context = "assignment: "
OB = boot("ROGUE", 3)

-- put health where the combo points are; combo points must vacate
OB.AssignSlot("points", "health")
OB.BindSlots()
eq(OB.bound.points and OB.bound.points.id, "health", "the slot took the new occupant")
check(OB.bound.health == nil, "the module vacated its previous slot")

-- and back to automatic
OB.AssignSlot("points", "auto")
OB.AssignSlot("health", "auto")
OB.BindSlots()
eq(OB.bound.points and OB.bound.points.id, "combopoints", "auto resolves again")
eq(OB.bound.health and OB.bound.health.id, "health", "the vacated slot refills")

-- "none" empties a slot outright
OB.AssignSlot("points", "none")
OB.BindSlots()
check(OB.bound.points == nil, "none empties a slot")

-- a hunter ships with range in the points slot; it stays empty until the module
-- exists, rather than erroring
OB = boot("HUNTER", 0)
eq(OB.profile.assign.HUNTER.points, "range", "the hunter default seeds a range assignment")
check(OB.bound.points == nil, "an assignment to a module that does not exist yet is simply empty")

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

eq(OB.profile.slots.points.w, 180, "combo geometry landed on the points slot")
eq(OB.profile.slots.points.y, 130, "including its position")
eq(OB.profile.slots.points.flip, true, "and its flip")
eq(OB.profile.slots.resource.h, 26, "energy geometry landed on the resource slot")
eq(OB.profile.slots.swingA.y, 100, "main hand geometry landed on swingA")
eq(OB.profile.slots.swingB.y, 115, "off hand geometry landed on swingB")

eq(OB.profile.modules.swing_main.decimals, 2, "main hand behaviour imported")
eq(OB.profile.modules.swing_main.deplete, true, "including deplete")
eq(OB.profile.modules.power.textMode, "percent", "energy text mode imported")
eq(OB.profile.modules.power.byType[3].ticker, "nofull", "energy ticker mode imported")
near(OB.profile.modules.power.byType[0].color[3], 0.90, 0.001,
        "the other power types kept their own defaults")
near(OB.profile.modules.combopoints.colors[1][1], 1, 0.001, "combo colours imported")

-- imports run once: a second boot must not overwrite tuned values
OB.profile.scale = 1.9
local saved = EquadisOmniBarsDB
RogueBarsConfig.Scale = 0.7
OB = boot("ROGUE", 3, { savedVariables = saved })
near(OB.profile.scale, 1.9, 0.001, "a second login does not re-import over tuned values")

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
eq(OB.profile.slots.resource.y, 80, "resetting restores this profile's defaults")
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
OB.panel.slot = "resource"
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
    for i = 1, table.getn(OB.slotOrder) do
        OB.panel.slot = OB.slotOrder[i]
        OB.RefreshPanel()
    end
end)

-- the occupant dropdown offers a real list and applying one rebinds
OB.panel.slot = "points"
local occupantDrop = _G["EqOBOccupant"]
check(occupantDrop ~= nil, "the occupant dropdown exists")
if occupantDrop then
    local buttons = Stub.OpenMenu(occupantDrop)
    check(table.getn(buttons) >= 3, "it offers auto, none and the modules",
            "got " .. table.getn(buttons))

    check(Stub.ChooseMenu(occupantDrop, "health"), "choosing health applies")
    eq(OB.bound.points and OB.bound.points.id, "health",
            "the panel reassigned the slot")

    --[[ Moving a module vacates the slot it came from, so the health slot is now
         empty. Nothing puts it back on its own -- one module, one slot -- so the
         test restores it the same way a user would. ]]--
    check(OB.bound.health == nil, "its previous slot was vacated")

    Stub.ChooseMenu(occupantDrop, "auto")
    eq(OB.bound.points and OB.bound.points.id, "combopoints", "and back to auto")

    OB.AssignSlot("health", "auto")
    OB.BindSlots()
    eq(OB.bound.health and OB.bound.health.id, "health", "and health is restored")
end

-- module rows appear only for the occupying module
OB.panel.slot = "resource"
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

OB.panel.slot = "points"
OB.RefreshPanel()
if comboSwatch then
    check(comboSwatch:IsShown(), "and shown when the points slot is selected")
end

-- an enum dropdown stores its string, not an index
OB.panel.slot = "resource"
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
OB.panel.slot = "health"
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

run("slot resource h 20")
eq(OB.profile.slots.resource.h, 20, "a slot option is settable")

run("power textMode percent")
eq(OB.profile.modules.power.textMode, "percent", "a module option is settable")

run("assign points none")
check(OB.bound.points == nil, "assign empties a slot")
run("assign points auto")
eq(OB.bound.points and OB.bound.points.id, "combopoints", "and fills it again")

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
-- 20. a long soak, to catch anything that only fails on the hundredth frame
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
