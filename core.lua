--[[ Equadis' OmniBars :: core

  Namespace, shared media, table helpers and the module registry.

  Loaded first, so every later file can pick the namespace up as a file local
  ("local OB = EquadisOmniBars"). The TOC load order is the dependency graph:
  nothing here may reach into config, frames or modules.

  The namespace is a plain table rather than a Frame. Equadis' Threat Meter
  makes its namespace the event frame, which means every key it stores risks
  shadowing a widget method (TWT.Show, TWT.Hide, TWT.GetName) and forces the
  whole addon through one event handler. Frames hang off this table instead.
]]--

local _G = getfenv(0)

EquadisOmniBars = {}
local OB = EquadisOmniBars

OB.version = "0.5.8"
OB.addonName = "Equadis' OmniBars"

--[[ The addon folder name is load-bearing: every media path below hardcodes it,
     so renaming the folder silently breaks every custom texture and font. The
     repo name has to match too, or a plain clone into Interface\AddOns does not
     work. ]]--
OB.mediaPath = "Interface\\AddOns\\EquadisOmniBars\\"

local _, playerClass = UnitClass("player")
OB.class = playerClass or "WARRIOR"

-- ---------------------------------------------------------------------------
-- chat
-- ---------------------------------------------------------------------------

function OB.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffabd473OmniBars:|cffffffff " .. tostring(msg))
end

-- unprefixed, for the generated help listing
function OB.Raw(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- ---------------------------------------------------------------------------
-- table helpers
-- ---------------------------------------------------------------------------

local floor = math.floor

function OB.Round(num)
    if num >= 0 then return floor(num + 0.5) end
    return -floor(-num + 0.5)
end

function OB.DeepCopy(src)
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = OB.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

--[[ A table is a *leaf* when it is a plain tuple of scalars under numeric keys:
     a colour, {r, g, b, a}. Anything else -- a named record, or a numeric table
     whose entries are themselves tables -- is a structure worth recursing into.

     The distinction matters in both directions. A colour must be replaced
     wholesale, because merging one index by index would leave a green channel
     from the default under a red the user picked. But power.byType is numeric
     too ([0] mana through [4] happiness) and must be merged, or a saved profile
     from before a type existed would delete it. ]]--
local function isLeaf(t)
    for k, v in pairs(t) do
        if type(k) ~= "number" then return false end
        if type(v) == "table" then return false end
    end
    return true
end

--[[ Merge `src` over `dst` in place, recursing into structures and replacing
     leaves.

     ShaguDPS merges one level deep, so its nested per-window tables come
     straight out of the saved variables and never pick up a new default. That is
     the bug this avoids -- and with five addons' settings eventually landing in
     one profile, it would have bitten repeatedly. ]]--
function OB.DeepMerge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table"
                and not isLeaf(v) and not isLeaf(dst[k]) then
            OB.DeepMerge(dst[k], v)
        elseif type(v) == "table" then
            dst[k] = OB.DeepCopy(v)
        else
            dst[k] = v
        end
    end
end

-- "colors.1" -> the table holding it and the final key, so a nested option key
-- reads and writes like a flat one
function OB.Resolve(root, path)
    if not root then return nil, nil end

    local container, key = root, path
    local pos = string.find(key, "%.")

    while pos do
        local head = string.sub(key, 1, pos - 1)
        local index = tonumber(head)
        if index then head = index end

        container = container[head]
        if type(container) ~= "table" then return nil, nil end

        key = string.sub(key, pos + 1)
        pos = string.find(key, "%.")
    end

    local index = tonumber(key)
    if index then key = index end

    return container, key
end

function OB.Get(root, path)
    local container, key = OB.Resolve(root, path)
    if not container then return nil end
    return container[key]
end

function OB.Set(root, path, value)
    local container, key = OB.Resolve(root, path)
    if not container then return end
    container[key] = value
end

-- ---------------------------------------------------------------------------
-- media
-- ---------------------------------------------------------------------------

--[[ Statusbar textures. The config stores the index and the panel derives the
     label by stripping everything up to the last backslash, so appending an
     entry here is all that is needed to ship a new texture. ]]--
OB.textures = {
    OB.mediaPath .. "textures\\Smooth",
    OB.mediaPath .. "textures\\ShaguPlates",
    OB.mediaPath .. "textures\\TukUI",
    OB.mediaPath .. "textures\\ElvUI",
    OB.mediaPath .. "textures\\Gradient",
    OB.mediaPath .. "textures\\Striped",
    "Interface\\BUTTONS\\WHITE8X8",
    "Interface\\TargetingFrame\\UI-StatusBar",
    "Interface\\Tooltips\\UI-Tooltip-Background",
    "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
}

--[[ Fonts as { display name, path } pairs. The four Blizzard faces ship with the
     client and live outside the addon folder, which is why their path is carried
     here rather than rebuilt from the name. ]]--
local fontDefs = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" },
    { "Morpheus", "Fonts\\MORPHEUS.TTF" },

    { "BalooBhaina" }, { "BigNoodleTitling" }, { "Continuum" }, { "DieDieDie" },
    { "Expressway" }, { "Homespun" }, { "Hooge" }, { "LondrinaSolid" },
    { "Myriad-Pro" }, { "PT-Sans-Narrow-Bold" }, { "PT-Sans-Narrow-Regular" },
    { "Roboto" }, { "RobotoMono" }, { "Share" }, { "ShareBold" },
    { "Sniglet" }, { "SquadaOne" },
}

OB.fonts = {}      -- display names, in panel order
OB.fontPaths = {}  -- parallel list of paths
OB.fontIndex = {}  -- name -> index

for i, def in ipairs(fontDefs) do
    OB.fonts[i] = def[1]
    OB.fontPaths[i] = def[2] or (OB.mediaPath .. "fonts\\" .. def[1] .. ".ttf")
    OB.fontIndex[def[1]] = i
end

--[[ 1.12 knows OUTLINE and nothing else usable here -- THINOUTLINE was never a
     real font flag and rendered identically -- so the outline is a plain on/off
     flag rather than a list. ]]--

OB.borders = { "None", "Thin", "Standard" }

-- how far the border art sits outside the bar, per OB.borders index
OB.borderPads = { 0, 3, 5 }

--[[ One table for bars and (later) meter windows, so Thin and Standard mean the
     same thing everywhere. ]]--
OB.borderEdges = {
    [2] = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
    [3] = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 },
}

OB.backdrop = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

-- media entries are paths; menus and the slash prompt show the file name only
function OB.CleanLabel(label)
    local _, _, clean = string.find(label or "", ".+\\(.+)")
    return clean or label or ""
end

--[[ A dropdown whose stored value is one of its own strings rather than an index
     into it.

     Media lists (textures, fonts, borders) store an index, because the list can
     grow and a path is a poor thing to keep in saved variables. A setting like a
     ticker mode is the opposite: "nofull" should survive the list being
     reordered, and it reads far better at the slash prompt than "2". ]]--
function OB.Enum(values, labels)
    return { enum = true, values = values, labels = labels }
end

-- ---------------------------------------------------------------------------
-- scanning
--
-- Vanilla hides a good deal behind tooltip text and nowhere else: an item's mana
-- per five seconds, a spell's cost. Reading it means loading the thing into a
-- tooltip nobody can see and reading the font strings back out.
-- ---------------------------------------------------------------------------

--[[ The shared hidden tooltip, built on first use.

     One instance for the whole addon. Several things want it -- the druid mana
     estimate now, mob health and the feign-death health override later -- and a
     tooltip per caller means loading the same eighteen items several times over
     for the same answer. ]]--
function OB.ScanTooltip()
    if not OB.scanTip then
        OB.scanTip = CreateFrame("GameTooltip", "EquadisOmniBarsScanTooltip",
                nil, "GameTooltipTemplate")
        OB.scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return OB.scanTip
end

-- the text of the scanning tooltip's Nth left-hand line, or nil past the end
function OB.ScanLine(index)
    local line = getglobal("EquadisOmniBarsScanTooltipTextLeft" .. index)
    if not line then return nil end
    return line:GetText()
end

--[[ True when any of `textures` (a set keyed by icon path) is on the player.

     Icon paths are the only identity a 1.12 buff has from Lua -- there is no id
     and the name is localised -- so every buff test in the addon is a texture
     comparison, and they all come through here. ]]--
function OB.HasPlayerBuff(textures)
    local i = 0
    local texture = GetPlayerBuffTexture(i)

    while texture do
        if textures[texture] then return true end
        i = i + 1
        texture = GetPlayerBuffTexture(i)
    end

    return false
end

-- ---------------------------------------------------------------------------
-- bars
--
-- A bar is a rectangle with a style, and one module draws into it. The rectangle
-- and the drawing stay separate tables -- render.lua and layout.lua are handed
-- geometry and must never learn what is drawn in it -- but the pairing is fixed:
-- one bar, one module, declared by the module and never reassigned.
--
-- An earlier version made that pairing a user setting, with an "occupant"
-- dropdown per slot. It bought nothing: every bar can be dragged anywhere, so
-- ordering was already the user's to choose, and the indirection only added a
-- concept and a control to get wrong. What is left is a flat list of named bars.
--
-- The order here is the order they appear in the panel *and* the order they are
-- stacked on screen by default, which is one less thing to reconcile.
-- ---------------------------------------------------------------------------

OB.barOrder = {
    "health", "resource", "mainhand", "offhand",
    "ranged", "distance", "secondary", "extras",
}

OB.barLabels = {
    health    = "Health",
    resource  = "Resource",
    mainhand  = "Main Hand",
    offhand   = "Off Hand",
    ranged    = "Ranged Attack",
    distance  = "Ranged Distance Check",
    secondary = "Secondary Resource",
    extras    = "Extras",
}

--[[ The one bar whose occupant depends on the class, and so the one whose name
     does too. A rogue's is combo points; a warrior's will be stances.

     Only combo points exists. The rest are named here rather than left blank
     because the name is the cheap half and it says what the bar is for before
     anything fills it. A class with no module naming `extras` simply has no
     Extras bar -- see OB.BarsForClass. ]]--
OB.extrasLabels = {
    ROGUE = "Combo Points",
    DRUID = "Combo Points",

    -- reserved, not implemented:
    -- WARRIOR = "Stances", PALADIN = "Auras", SHAMAN = "Totems",
    -- HUNTER = "Aspects", PRIEST = "Forms",
}

function OB.BarLabel(barId)
    if barId == "extras" then
        return OB.extrasLabels[OB.class] or OB.barLabels.extras
    end
    return OB.barLabels[barId] or barId
end

-- ---------------------------------------------------------------------------
-- power types
-- ---------------------------------------------------------------------------

OB.powerNames = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [4] = "Happiness",
}

--[[ Class colours. RAID_CLASS_COLORS exists in 1.12 but a client mod may have
     replaced or trimmed it, so this is the fallback and the lookup goes through
     OB.ClassColor. ]]--
OB.classColors = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

function OB.ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then c = OB.classColors[class] end
    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

-- ---------------------------------------------------------------------------
-- module registry
-- ---------------------------------------------------------------------------

OB.modules = {}      -- id -> descriptor
OB.moduleOrder = {}  -- registration order, which is also panel order
OB.bound = {}        -- slotId -> descriptor
OB.eventMap = {}     -- event -> { descriptor, ... }
OB.dragMap = {}      -- frame -> slotId

--[[ Cross-cutting notifications, ShaguDPS's parser.callbacks.refresh. Phase 1
     has a single subscriber, but this is the seam the combat log parser and the
     meters join at later, so it exists from the start. ]]--
OB.callbacks = { refresh = {} }

function OB.Subscribe(list, fn)
    table.insert(OB.callbacks[list], fn)
end

function OB.Fire(list)
    local subs = OB.callbacks[list]
    for i = 1, table.getn(subs) do
        subs[i]()
    end
end

--[[ Register a module.

     A module owns behaviour, colour and semantics; it never owns geometry. Its
     `defaults` are copied straight into OB.defaults.modules[id], so config.lua
     never has to know any module exists -- the merge in LoadConfig makes new
     settings appear for existing users on its own. Modules load after config.lua
     but before LoadConfig runs at VARIABLES_LOADED, so the timing works out.

     One id occupies at most one slot, which makes the binder a single pass. That
     is why the swing timers are three ids from one implementation table rather
     than one module with instances, and it is why state can live on the
     descriptor itself (self.start, self.last) with no instance objects. ]]--
function OB.RegisterModule(m)
    if not m or not m.id then return end

    if OB.modules[m.id] then
        OB.Print("duplicate module id '" .. m.id .. "' ignored.")
        return
    end

    m.priority = m.priority or 0
    m.renders = m.renders or "bar"
    m.name = m.name or m.id
    m.events = m.events or {}

    --[[ The client APIs this module cannot work without, by name.

         Documentation the self-test reads, and never a load gate. Refusing to
         register a module because one API is missing would silently drop it on a
         client with a slightly different surface, which is strictly worse than a
         module that draws nothing and can tell you exactly which call it wanted.

         An API the module is *expected* to survive without does not belong here.
         The range readout probes for UnitXP and has two fallbacks ready, so
         listing it would make every plain install report a failure for working
         as designed. ]]--
    m.requires = m.requires or {}

    --[[ `feature = true` marks a whole optional subsystem -- the threat meter,
         the damage meter, nameplates, unit frames -- rather than a bar. Only
         features are listed on the Modules page, because switching one off is a
         real decision about whether you would rather run somebody else's.

         A bar is not that. "I do not want an off hand timer" is answered by Show
         Bar, on the Bars page, next to that bar's own settings. Every module
         still has an enable flag; only features offer it as a control. ]]--
    m.feature = m.feature and true or false

    OB.modules[m.id] = m
    table.insert(OB.moduleOrder, m.id)

    if m.defaults then
        OB.defaults.modules = OB.defaults.modules or {}
        OB.defaults.modules[m.id] = OB.DeepCopy(m.defaults)
    end

    return m
end

-- true when this class may run the module at all
function OB.ClassAllows(m)
    if not m then return false end
    if not m.classes then return true end
    return m.classes[OB.class] and true or false
end

function OB.ModuleEnabled(id)
    local m = OB.modules[id]
    if not m then return false end
    if not OB.ClassAllows(m) then return false end
    if not OB.profile then return true end

    local flag = OB.profile.modulesEnabled[id]
    if flag == nil then return true end
    return flag and true or false
end

--[[ Which module draws in a bar: the one that names it and whose class gate
     passes. A bar with no such module is simply empty.

     `priority` breaks a tie between two modules claiming the same bar for the
     same class. That should never happen -- Extras is the only bar more than one
     module will ever name, and each of those names a different class -- so a tie
     is a bug rather than a feature. It costs one comparison to fail loudly-ish
     instead of arbitrarily. ]]--
function OB.Occupant(barId)
    local best, bestPriority

    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local m = OB.modules[id]
        if m.bar == barId and OB.ModuleEnabled(id) then
            if not best or m.priority > bestPriority then
                best, bestPriority = id, m.priority
            end
        end
    end

    return best
end

--[[ The bars this class actually has, in panel order.

     A bar no module on this class can fill is left out of the list entirely
     rather than shown empty: a warrior has no Extras and no Secondary Resource,
     and offering rows for a rectangle that will never be drawn is just a way to
     waste somebody's afternoon. Note this asks about the *class*, not about the
     enable toggles -- a module you switched off still has its bar listed, or you
     would have no way to switch it back on from the Bars page. ]]--
function OB.BarsForClass()
    local list = {}

    for i = 1, table.getn(OB.barOrder) do
        local barId = OB.barOrder[i]
        local possible = false

        for m = 1, table.getn(OB.moduleOrder) do
            local mod = OB.modules[OB.moduleOrder[m]]
            if mod.bar == barId and OB.ClassAllows(mod) then possible = true end
        end

        if possible then table.insert(list, barId) end
    end

    return list
end

-- ---------------------------------------------------------------------------
-- frames
--
-- Created here so later files have something to attach to (ShaguDPS's core.lua
-- does the same). Neither carries a script yet.
-- ---------------------------------------------------------------------------

OB.events = CreateFrame("Frame", "EquadisOmniBarsEvents", UIParent)
OB.hud = CreateFrame("Frame", "EquadisOmniBarsHUD", UIParent)

--[[ Events the addon always wants, independent of which modules are bound.
     BindSlots re-registers the whole set, so this list and the per-module lists
     are the only two sources. ]]--
OB.coreEvents = {
    "VARIABLES_LOADED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_AURAS_CHANGED",
    "UPDATE_SHAPESHIFT_FORMS",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
}
