--[[ Equadis' Classic Overhaul :: core

  Namespace, shared media, table helpers and the module registry.

  Loaded first, so every later file can pick the namespace up as a file local
  ("local OB = EquadisClassicOverhaul"). The TOC load order is the dependency graph:
  nothing here may reach into config, frames or modules.

  The namespace is a plain table rather than a Frame. Equadis' Threat Meter
  makes its namespace the event frame, which means every key it stores risks
  shadowing a widget method (TWT.Show, TWT.Hide, TWT.GetName) and forces the
  whole addon through one event handler. Frames hang off this table instead.
]]--

local _G = getfenv(0)

EquadisClassicOverhaul = {}
local OB = EquadisClassicOverhaul

OB.version = "0.86.3"
OB.addonName = "Equadis' Classic Overhaul"

--[[ The addon folder name is load-bearing: every media path below hardcodes it,
     so renaming the folder silently breaks every custom texture and font. The
     repo name has to match too, or a plain clone into Interface\AddOns does not
     work. ]]--
OB.mediaPath = "Interface\\AddOns\\EquadisClassicOverhaul\\"

local _, playerClass = UnitClass("player")
OB.class = playerClass or "WARRIOR"

-- ---------------------------------------------------------------------------
-- chat
-- ---------------------------------------------------------------------------

--[[ **One prefix, one colour, and it names where the message came from.**

     `Eq <part>:` in `#008b8b` on every line this addon writes, so an Overhaul
     message is recognisable in a channel scrolling past without anybody having
     to read it -- and so a line about the chat scan says which part it is,
     rather than eleven different features all announcing themselves as the same
     word.

     **The body stays white.** Colouring a whole message teal makes it a banner
     rather than a sentence, and several of these run to three lines. The colour
     is the label's job.

     Each file names itself once, at the top, in a local `Say`. That is why this
     takes the name as an argument rather than working it out: there is no
     caller to inspect in 5.0 worth the trouble, and a constant per file is
     something a reader can see. ]]--
OB.tagColor = "|cff008b8b"

function OB.Print(msg, from)
    DEFAULT_CHAT_FRAME:AddMessage(OB.tagColor .. "Eq " .. (from or "Overhaul")
            .. ":|cffffffff " .. tostring(msg))
end

-- unprefixed, for the generated help listing
function OB.Raw(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- ---------------------------------------------------------------------------
-- reload-required warning
-- ---------------------------------------------------------------------------

--[[ A setting that cannot take effect immediately must say so where the user is
     looking, not bury the fact in chat.  The banner is created lazily because
     core.lua loads before the settings panel and most sessions never need it. ]]--
function OB.RequireReload(reason)
    if not OB.reloadWarning then
        local f = CreateFrame("Frame", "EquadisClassicOverhaulReloadWarning", UIParent)
        f:SetWidth(560)
        f:SetHeight(54)
        f:SetPoint("TOP", UIParent, "TOP", 0, -18)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.08, 0.03, 0.03, 0.96)
        f:SetBackdropBorderColor(1, 0.35, 0.2, 1)
        f:Hide()

        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("LEFT", f, "LEFT", 14, 0)
        f.text:SetWidth(390)
        f.text:SetJustifyH("LEFT")

        f.reload = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.reload:SetWidth(92)
        f.reload:SetHeight(22)
        f.reload:SetPoint("RIGHT", f, "RIGHT", -34, 0)
        f.reload:SetText("Reload UI")
        f.reload:SetScript("OnClick", function()
            if ReloadUI then ReloadUI() end
        end)

        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 2)
        f.close:SetScript("OnClick", function() f:Hide() end)

        OB.reloadWarning = f
    end

    local text = "Reload required"
    if reason and reason ~= "" then text = text .. ": " .. tostring(reason) end
    OB.reloadWarning.text:SetText(text)
    OB.reloadWarning:Show()
end

-- ---------------------------------------------------------------------------
-- table helpers
-- ---------------------------------------------------------------------------

local floor = math.floor

function OB.Round(num)
    if num >= 0 then return floor(num + 0.5) end
    return -floor(-num + 0.5)
end

--[[ A value held inside a range. The same bounds the sliders use, so a value
     arriving by drag cannot reach somewhere the panel could never set. ]]--
function OB.Clamp(v, low, high)
    if v < low then return low end
    if v > high then return high end
    return v
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
    --[[ **An empty table is not a leaf**, and getting that backwards silently
         deleted defaults.

         The loop below never runs for one, so it used to fall through to `true`
         -- and a leaf is *replaced* wholesale. So a saved profile written before
         a table had any contents, `modulesEnabled = {}` being the one that
         caught it, replaced the shipped defaults with nothing at all. Every
         module registered since was suddenly on, and every default under any
         other empty table was gone.

         Merging is the right answer because an empty table carries no
         information: recursing into nothing leaves the destination alone, which
         is exactly what "the user saved no opinion about this" should mean. ]]--
    if next(t) == nil then return false end

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

--[[ Window chrome. Line art on transparent, 32x32, drawn in near-white so
     SetVertexColor can tint it -- which is how a button dims when its action is
     unavailable rather than being swapped for a second file.

     Power-of-two and uncompressed 32-bit TGA, both of which 1.12 requires: a
     non-power-of-two texture loads as a black square, which looks like a broken
     button rather than a broken file. ]]--
OB.icons = {
    settings = OB.mediaPath .. "textures\\icons\\settings",
    lock     = OB.mediaPath .. "textures\\icons\\lock",
    unlock   = OB.mediaPath .. "textures\\icons\\unlock",
    close    = OB.mediaPath .. "textures\\icons\\close",
    new      = OB.mediaPath .. "textures\\icons\\new",
    reset    = OB.mediaPath .. "textures\\icons\\reset",
}

--[[ Every window with a header sits at the same height, so two meters open side
     by side line up. Shared for the same reason the icons are. ]]--
OB.HEADER_H = 18

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

--[[ **The look, as option rows, for any subsystem that wants them.**

     Texture, font, font size, outline and border are the five settings that make
     five separate addons look like five separate addons. Every subsystem gets
     the same five, from here, so a new one cannot arrive with four of them and a
     differently worded fifth.

     `Use The Shared Look` is on by default and the other five grey out beneath
     it, which is the panel's usual rule doing exactly what it is for: the
     overrides still say what they say, and they apply the moment you switch the
     sharing off.

     Two arguments' worth of care in the defaults, though. `ownLook = false` is
     the switch; the five values are **absent**, not copied from the profile,
     because OB.Look falls back key by key. Copying them would freeze a
     subsystem's look at whatever the shared one was the day it was registered,
     and then quietly stop following it. ]]--
function OB.LookOptions()
    return {
        { "Appearance", "__h_look", "header" },

        { "Bar Texture", "texture", OB.textures, 200 },
        { "Font", "font", OB.fonts, 200 },
        { "Font Size", "fontSize", "slider", 6, 24, 1 },
        { "Font Outline", "fontOutline", "boolean" },
        { "Border", "border", OB.borders, 200 },
    }
end

--[[ Nothing. There is no switch, and that is the point.

     There was a `Use The Shared Look` toggle here and the five settings greyed
     out beneath it, which made the common case -- change this subsystem's font --
     take two clicks and a moment working out why the control was dead. Setting
     one *is* the override, and leaving it alone *is* sharing.

     So the values stay absent by default and OB.Look falls back to the profile
     key by key. A subsystem that has never been touched follows the shared look
     exactly as before; one that has, differs in precisely the keys somebody
     changed. Nothing to switch, nothing to explain. ]]--
function OB.LookDefaults()
    return {}
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
        OB.scanTip = CreateFrame("GameTooltip", "EquadisClassicOverhaulScanTooltip",
                nil, "GameTooltipTemplate")
        OB.scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return OB.scanTip
end

-- the text of the scanning tooltip's Nth left-hand line, or nil past the end
function OB.ScanLine(index)
    local line = getglobal("EquadisClassicOverhaulScanTooltipTextLeft" .. index)
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

--[[ **The roster APIs answer a localized class name; everything else wants a
     token.**

     `UnitClass` is the only one that gives both -- "Rogue" and "ROGUE". The six
     roster readers give one string each, and in 1.12 that string is the
     localized name: `GetGuildRosterInfo` says "Warrior", not "WARRIOR". Feed
     that to a colour lookup keyed by token and every guildmate comes back white,
     silently, which is also what an unknown player looks like.

     This is the whole job of Ace's BabbleClass, which Prat carried for it. On an
     enUS client the mapping is `string.upper` -- every token is one word -- so
     the map is built rather than shipped, and a name that does not land on a
     known class is handed back as nil so the caller can tell "not a class I
     know" from "a class whose colour I could not find".

     A different locale needs a real table here. Recorded rather than pretended
     away: this returns nil there, and an uncoloured name is the correct failure. ]]--
function OB.ClassToken(class)
    if not class or class == "" then return nil end

    local token = string.upper(class)
    if OB.classColors[token] then return token end

    return nil
end

--[[ A point between two colours, alpha included.

     Alpha blends with the rest rather than being taken from one end, so a ramp
     whose ends have different opacities fades as smoothly as it shades. Taking
     it from either end alone would make a bar jump in opacity at the midpoint
     while its colour moved continuously. ]]--
function OB.Blend(from, to, t)
    local function mix(i, default)
        local a, b = from[i] or default, to[i] or default
        return a + ((b - a) * t)
    end

    return { mix(1, 0), mix(2, 0), mix(3, 0), mix(4, 1) }
end

--[[ **Three anchors, not two, and the middle one is why it is legible.**

     A straight blend from green to red passes through (0.5, 0.5, 0) at halfway
     -- olive-brown, dark, and it reads as a fault rather than as a middling
     value. A bright midpoint keeps every point on the ramp bright. Anyone
     wanting a plain two-colour blend sets the middle to the average of the ends.

     Shared rather than owned by the health bar, because the threat meter wants
     exactly the same ramp pointed the other way: health runs full to empty and
     threat runs safe to about-to-pull, and the arithmetic does not care which.
     Equadis' Threat Meter had this hardcoded green/yellow/red in its row
     painter with nothing on its panel able to reach it; here all three are
     settings, in both places. ]]--
function OB.Ramp(low, half, full, fraction)
    if not fraction or fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end

    if fraction >= 0.5 then return OB.Blend(half, full, (fraction - 0.5) * 2) end
    return OB.Blend(low, half, fraction * 2)
end

function OB.ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then c = OB.classColors[class] end
    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

--[[ **A level's colour is the client's difficulty colour**, which says something
     a class colour cannot: not who they are, but where they are relative to you.
     Red is above you, grey is beneath, and the eye reads the five steps without
     doing the subtraction.

     The thresholds are the client's own -- five above is red, three is orange,
     within two is yellow -- and the green band is asked for rather than
     hardcoded, because `GetQuestGreenRange` widens it as you level and a fixed
     number would be wrong everywhere except one level.

     Computed here rather than borrowed from `GetDifficultyColor`: that function
     exists in 1.12 but is FrameXML rather than the API, so a client mod may have
     replaced it and a UI-hiding addon may have unloaded it. The arithmetic is
     four comparisons. ]]--
OB.levelColors = {
    red = { 1.00, 0.10, 0.10 },
    orange = { 1.00, 0.50, 0.25 },
    yellow = { 1.00, 1.00, 0.00 },
    green = { 0.25, 0.75, 0.25 },
    grey = { 0.50, 0.50, 0.50 },
}

function OB.LevelColor(level, relativeTo)
    local mine = relativeTo or UnitLevel("player") or 1
    local c = OB.levelColors

    if not level or level <= 0 then return unpack(c.grey) end

    local difference = level - mine

    if difference >= 5 then return unpack(c.red) end
    if difference >= 3 then return unpack(c.orange) end
    if difference >= -2 then return unpack(c.yellow) end

    --[[ Below yellow, green until the gap is wide enough to be beneath notice.
         Nine levels at sixty, five at ten -- the client's number, asked for. ]]--
    local green = 5
    if type(GetQuestGreenRange) == "function" then
        green = GetQuestGreenRange() or green
    end

    if -difference <= green then return unpack(c.green) end
    return unpack(c.grey)
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

    --[[ Listed, described, and not yet real. A subsystem on the roadmap appears
         on the Modules page from the day it is planned rather than the day it
         works, so the page is the roadmap and there is one place to look.

         Its switch is disabled rather than absent -- an entry you cannot enable
         says "coming", where a missing entry says "never". ]]--
    m.development = m.development and true or false

    OB.modules[m.id] = m
    table.insert(OB.moduleOrder, m.id)

    --[[ Absent from `modulesEnabled` means on, which is what lets a module added
         by a later version work without the user going to find it. A module that
         wants the opposite has to say so, and only here: writing `enabled` into
         the module's *own* defaults looks like it would do this and does not --
         the binder reads modulesEnabled and nothing else.

         Used by a feature that is not finished. One that is switched on and
         draws nothing is indistinguishable from one that is broken. ]]--
    if m.defaultEnabled == false then
        OB.defaults.modulesEnabled = OB.defaults.modulesEnabled or {}
        OB.defaults.modulesEnabled[m.id] = false
    end

    if m.defaults then
        OB.defaults.modules = OB.defaults.modules or {}
        OB.defaults.modules[m.id] = OB.DeepCopy(m.defaults)

        --[[ Every **feature** carries the shared-look switch, whether or not it
             asked for one. The panel gives every subsystem the same appearance
             block, so the default that block reads has to exist for all of them
             -- and putting it here means a module cannot forget it. ]]--
        if m.feature then
            OB.DeepMerge(OB.defaults.modules[m.id], OB.LookDefaults())
        end
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

--[[ **Shown is not Enabled, and they were the same checkbox with two captions.**

     *Enable*, on the Modules page, decides whether the subsystem **runs**: it
     binds, registers events, ticks and counts. Switching it off is about what
     the addon costs.

     *Show*, on the subsystem's own page, decides only whether its windows are on
     screen. An enabled-but-hidden meter keeps counting, which is the whole
     reason the two are separate: hide the damage meter for a pull, show it again
     at the end, and the numbers are there. If Show unbound the module those
     numbers would not exist, and "hide this for a moment" would silently cost
     you the fight.

     Absent means shown, the same rule `modulesEnabled` follows and for the same
     reason: a subsystem added by a later version is visible until somebody says
     otherwise. ]]--
function OB.ModuleShown(id)
    if not OB.ModuleEnabled(id) then return false end
    if not OB.profile or not OB.profile.modulesShown then return true end

    local flag = OB.profile.modulesShown[id]
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

OB.events = CreateFrame("Frame", "EquadisClassicOverhaulEvents", UIParent)
OB.hud = CreateFrame("Frame", "EquadisClassicOverhaulHUD", UIParent)

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
