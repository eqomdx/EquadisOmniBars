--[[ Equadis' Classic Overhaul :: nameplates

  ShaguPlates parity pass.

  This module keeps the Overhaul's existing 1.12 nameplate detection and shared
  style system, then ports the high-value behaviours from ShaguPlates 5.4.21:

    * verified player/NPC identity and player class colours
    * target glow, target scaling and non-target fade
    * raid-marker sizing and positioning
    * elite/rare labels when the client exposes a classification
    * level colours and optional combat-coloured names
    * learned real mob-health estimates, stored in OB.mobHealth
    * per-plate debuff caches which are cleared when a plate is recycled
    * exact target/mouseover debuff scans plus optional name-based guessing
    * whitelist/blacklist debuff filters and top/bottom positioning
    * target-only cast-bar mode
    * optional hiding of the health bar for selected unit classes
    * click-through plates and vertical/offset presentation options

  Things deliberately not copied here are the parts which require SuperWoW,
  ShaguPlates' large shipped spell/debuff databases, or its locale-specific
  critter/totem name tables. The Overhaul already has cast/aura/roster services;
  this module consumes them instead of installing a second parallel framework.
]]--

local OB = EquadisClassicOverhaul
local floor, ceil, abs = math.floor, math.ceil, math.abs

-- ---------------------------------------------------------------------------
-- vanilla plate identity
-- ---------------------------------------------------------------------------

local PLATE_TYPE = "Button"
local PLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"

local PLATE_REGIONS = {
    "border", "glow", "name", "level", "levelicon", "raidicon",
}

OB.plateKinds = {
    "ENEMY_NPC", "NEUTRAL_NPC", "FRIENDLY_NPC",
    "ENEMY_PLAYER", "FRIENDLY_PLAYER",
}

function OB.PlateKind(r, g, b)
    if not r then return nil end
    if r > 0.9 and g < 0.2 and b < 0.2 then return "ENEMY_NPC" end
    if r > 0.9 and g > 0.9 and b < 0.2 then return "NEUTRAL_NPC" end
    if r < 0.2 and g > 0.9 and b < 0.2 then return "FRIENDLY_NPC" end
    if r < 0.2 and g < 0.2 and b > 0.9 then return "FRIENDLY_PLAYER" end
    return nil
end

local SHOWN_BY = {
    ENEMY_NPC = "enemyNpc",
    NEUTRAL_NPC = "neutralNpc",
    FRIENDLY_NPC = "friendlyNpc",
    ENEMY_PLAYER = "enemyPlayer",
    FRIENDLY_PLAYER = "friendlyPlayer",
}

local COLOR_KEY = {
    ENEMY_NPC = "enemyColor",
    NEUTRAL_NPC = "neutralColor",
    FRIENDLY_NPC = "friendlyNpcColor",
    ENEMY_PLAYER = "enemyColor",
    FRIENDLY_PLAYER = "friendlyPlayerColor",
}

local HIDE_HEALTH_KEY = {
    ENEMY_NPC = "hideEnemyNpcHealth",
    NEUTRAL_NPC = "hideNeutralNpcHealth",
    FRIENDLY_NPC = "hideFriendlyNpcHealth",
    ENEMY_PLAYER = "hideEnemyPlayerHealth",
    FRIENDLY_PLAYER = "hideFriendlyPlayerHealth",
}

local CLASS_SUFFIX = {
    elite = "+",
    rareelite = "R+",
    rare = "R",
    worldboss = "B",
    boss = "B",
}

OB.predicates = OB.predicates or {}
OB.predicates.plates_no_combo = function()
    return OB.class ~= "ROGUE" and OB.class ~= "DRUID"
end

local M = OB.RegisterModule({
    id = "nameplates",
    name = "Nameplates",
    feature = true,
    styled = true,
    renders = "none",
    defaultEnabled = false,
    tickly = true,

    defaults = {
        -- Which nameplates are allowed to remain visible once the client creates
        -- them. Hostile and neutral are on; friendlies are opt-in.
        enemyNpc = true,
        neutralNpc = true,
        enemyPlayer = true,
        friendlyNpc = false,
        friendlyPlayer = false,

        width = 120,
        height = 8,
        verticalHealth = false,
        verticalOffset = -10,
        backgroundColor = { 0.04, 0.04, 0.04, 0.72 },

        showName = true,
        nameSize = 10,
        shortenNames = true,
        nameMaxLength = 20,
        nameInCombatColor = true,
        friendlyNameClassColor = false,

        showLevel = true,
        healthText = "none",
        healthTextPos = "CENTER",

        enemyColor = { 0.90, 0.20, 0.30, 0.90 },
        neutralColor = { 1.00, 1.00, 0.30, 0.90 },
        friendlyNpcColor = { 0.60, 1.00, 0.00, 0.90 },
        friendlyPlayerColor = { 0.20, 0.60, 1.00, 0.90 },
        enemyClassColor = true,
        friendlyClassColor = true,

        -- Hide only the health rectangle, not the nameplate itself. The critter
        -- and totem checks are exact once that plate has been target/mouseover.
        hideEnemyNpcHealth = false,
        hideNeutralNpcHealth = false,
        hideEnemyPlayerHealth = false,
        hideFriendlyNpcHealth = false,
        hideFriendlyPlayerHealth = false,
        hideCritterHealth = true,
        hideTotemHealth = true,

        -- Target treatment closely follows the reference defaults.
        markTarget = true,
        targetScale = 1.15,
        otherAlpha = 0.75,
        targetGlow = true,
        targetGlowColor = { 1.00, 1.00, 1.00, 0.75 },
        targetBorder = false,
        targetBorderColor = { 1.00, 1.00, 1.00, 1.00 },

        colorByThreat = false,
        threatColor = { 0.85, 0.20, 0.20, 1 },
        noThreatColor = { 0.20, 0.75, 0.25, 1 },

        showCombo = false,
        comboColor = { 1.00, 0.85, 0.20, 1 },

        castbar = true,
        castTargetOnly = false,
        castbarHeight = 8,
        castColor = { 0.90, 0.80, 0.00, 1 },
        showCastName = true,

        debuffs = true,
        guessDebuffs = true,
        debuffSize = 14,
        debuffCount = 8,
        debuffPosition = "TOP",
        debuffOffset = 4,
        debuffFilter = "none",
        debuffList = "",

        raidIconSize = 16,
        raidIconPosition = "CENTER",
        raidIconX = 0,
        raidIconY = -5,

        clickThrough = false,

        -- ShaguPlates' libhealth defaults: require four observed health changes
        -- and five percent of total damage before trusting an inferred maximum.
        healthEstimateHits = 4,
        healthEstimateDamage = 5,
    },

    options = {
        { "Which Plates", "__s_which", "section", "which" },
        { "Show Enemy NPCs", "enemyNpc", "boolean" },
        { "Show Neutral NPCs", "neutralNpc", "boolean" },
        { "Show Enemy Players", "enemyPlayer", "boolean" },
        { "Show Friendly NPCs", "friendlyNpc", "boolean" },
        { "Show Friendly Players", "friendlyPlayer", "boolean" },

        { "Size And Position", "__s_geometry", "section", "geometry" },
        { "Width", "width", "slider", 60, 240, 5 },
        { "Health Height", "height", "slider", 4, 30, 1 },
        { "Vertical Health Fill", "verticalHealth", "boolean" },
        { "Vertical Offset", "verticalOffset", "slider", -50, 50, 1 },
        { "Background Color", "backgroundColor", "color", true },

        { "Names And Levels", "__s_text", "section", "text" },
        { "Show Name", "showName", "boolean" },
        { "Name Size", "nameSize", "slider", 6, 20, 1,
          nil, nil, "!showName" },
        { "Shorten Long Names", "shortenNames", "boolean",
          nil, nil, nil, nil, nil, "!showName" },
        { "Shorten After", "nameMaxLength", "slider", 12, 40, 1,
          nil, nil, "!shortenNames" },
        { "Color Name When In Combat", "nameInCombatColor", "boolean" },
        { "Class Color Friendly Player Names", "friendlyNameClassColor", "boolean" },
        { "Show Level", "showLevel", "boolean" },

        { "Health Text", "healthText", OB.Enum(
                { "none", "value", "percent", "max", "valuepct", "maxpct", "deficit" },
                { "None", "Current Only", "Percentage", "Current / Max",
                  "Current (Percent)", "Current / Max (Percent)", "Deficit" }) },
        { "Health Text Position", "healthTextPos", OB.Enum(
                { "LEFT", "CENTER", "RIGHT" },
                { "Left", "Center", "Right" }) },

        { "Health Colors", "__s_colors", "section", "colors" },
        { "Enemy", "enemyColor", "color", true },
        { "Neutral", "neutralColor", "color", true },
        { "Friendly NPC", "friendlyNpcColor", "color", true },
        { "Friendly Player", "friendlyPlayerColor", "color", true },
        { "Class Color Enemy Players", "enemyClassColor", "boolean" },
        { "Class Color Friendly Players", "friendlyClassColor", "boolean" },

        { "Hide Health Bars", "__s_hidebars", "section", "hidebars" },
        { "Enemy NPC", "hideEnemyNpcHealth", "boolean" },
        { "Neutral NPC", "hideNeutralNpcHealth", "boolean" },
        { "Enemy Player", "hideEnemyPlayerHealth", "boolean" },
        { "Friendly NPC", "hideFriendlyNpcHealth", "boolean" },
        { "Friendly Player", "hideFriendlyPlayerHealth", "boolean" },
        { "Critters", "hideCritterHealth", "boolean" },
        { "Totems", "hideTotemHealth", "boolean" },

        { "Your Target", "__s_target", "section", "target" },
        { "Mark Your Target", "markTarget", "boolean" },
        { "Target Size", "targetScale", "slider", 100, 200, 5, 0.01,
          nil, "!markTarget" },
        { "Fade Other Plates To", "otherAlpha", "slider", 20, 100, 5, 0.01,
          nil, "!markTarget" },
        { "Target Glow", "targetGlow", "boolean" },
        { "Target Glow Color", "targetGlowColor", "color", true,
          nil, nil, nil, nil, "!targetGlow" },
        { "Highlight Target Border", "targetBorder", "boolean" },
        { "Target Border Color", "targetBorderColor", "color", true,
          nil, nil, nil, nil, "!targetBorder" },
        { "Color Target By Threat", "colorByThreat", "boolean" },
        { "It Is On You", "threatColor", "color", true,
          nil, nil, nil, nil, "!colorByThreat" },
        { "It Is On Somebody Else", "noThreatColor", "color", true,
          nil, nil, nil, nil, "!colorByThreat" },
        { "Show Combo Points On Target", "showCombo", "boolean",
          nil, nil, nil, nil, nil, "@plates_no_combo" },
        { "Combo Point Color", "comboColor", "color", true,
          nil, nil, nil, nil, "!showCombo" },

        { "Casting", "__s_cast", "section", "cast" },
        { "Show Cast Bars", "castbar", "boolean" },
        { "Only On Your Target", "castTargetOnly", "boolean",
          nil, nil, nil, nil, nil, "!castbar" },
        { "Cast Bar Height", "castbarHeight", "slider", 2, 20, 1,
          nil, nil, "!castbar" },
        { "Cast Bar Color", "castColor", "color", true,
          nil, nil, nil, nil, "!castbar" },
        { "Show Spell Name", "showCastName", "boolean",
          nil, nil, nil, nil, nil, "!castbar" },

        { "Debuffs", "__s_debuffs", "section", "debuffs" },
        { "Show Debuffs", "debuffs", "boolean" },
        { "Guess Debuffs Away From Target", "guessDebuffs", "boolean",
          nil, nil, nil, nil, nil, "!debuffs" },
        { "Icon Size", "debuffSize", "slider", 8, 32, 1,
          nil, nil, "!debuffs" },
        { "How Many", "debuffCount", "slider", 1, 16, 1,
          nil, nil, "!debuffs" },
        { "Position", "debuffPosition", OB.Enum(
                { "TOP", "BOTTOM" }, { "Above", "Below" }) },
        { "Offset", "debuffOffset", "slider", 0, 20, 1,
          nil, nil, "!debuffs" },
        { "Filter", "debuffFilter", OB.Enum(
                { "none", "whitelist", "blacklist" },
                { "None", "Whitelist", "Blacklist" }) },
        { "Debuff List", "debuffList", "text", 200, 255 },

        { "Raid Marker", "__s_raid", "section", "raid" },
        { "Marker Size", "raidIconSize", "slider", 8, 40, 1 },
        { "Marker Position", "raidIconPosition", OB.Enum(
                { "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM",
                  "BOTTOMLEFT", "LEFT", "TOPLEFT", "CENTER" },
                { "Top", "Top Right", "Right", "Bottom Right", "Bottom",
                  "Bottom Left", "Left", "Top Left", "Center" }) },
        { "Marker X Offset", "raidIconX", "slider", -50, 50, 1 },
        { "Marker Y Offset", "raidIconY", "slider", -50, 50, 1 },

        { "Interaction", "__s_input", "section", "input" },
        { "Click Through Nameplates", "clickThrough", "boolean" },

        { "Health Estimation", "__s_estimate", "section", "estimate" },
        { "Minimum Health Changes", "healthEstimateHits", "slider", 1, 10, 1 },
        { "Required Damage Percent", "healthEstimateDamage", "slider", 1, 25, 1 },
    },
})

function M:Config()
    return OB.profile.modules.nameplates
end

-- ---------------------------------------------------------------------------
-- learned mob health (ShaguPlates libhealth technique)
-- ---------------------------------------------------------------------------

local healthLearn = {
    key = nil,
    damage = 0,
    startPercent = nil,
}

local function plateLevelText(unit)
    if not UnitExists(unit) then return nil end
    local level = UnitLevel(unit)
    if level and level > 0 then return level end
    return nil
end

local function mobHealthKey(name, level)
    if not name or name == "" then return nil end
    if not level or level <= 0 then return nil end
    return name .. ":" .. level
end

local function resetHealthLearning()
    healthLearn.key = nil
    healthLearn.damage = 0
    healthLearn.startPercent = nil

    if not UnitExists("target") then return end
    if UnitIsPlayer and UnitIsPlayer("target") then return end

    local max = UnitHealthMax("target") or 0
    if max ~= 100 then return end

    local name = UnitName("target")
    local level = plateLevelText("target")
    local key = mobHealthKey(name, level)
    if not key then return end

    healthLearn.key = key
    healthLearn.startPercent = UnitHealth("target") or 100
end

local function recordHealthChange()
    if not healthLearn.key or not healthLearn.startPercent then return end
    if not OB.mobHealth then return end

    local percent = UnitHealth("target") or healthLearn.startPercent
    local diff = healthLearn.startPercent - percent

    -- Healing, evade/reset, or a recycled target invalidates the cumulative
    -- sample. Start again from the new percentage rather than poisoning the DB.
    if diff < 0 then
        healthLearn.damage = 0
        healthLearn.startPercent = percent
        return
    end

    if healthLearn.damage <= 0 or diff <= 0 then return end

    local estimate = ceil((healthLearn.damage / diff) * 100)
    if estimate <= 0 then return end

    local record = OB.mobHealth[healthLearn.key]
    if type(record) ~= "table" then
        record = { max = estimate, diff = diff, hits = 1 }
        OB.mobHealth[healthLearn.key] = record
        return
    end

    record.hits = (record.hits or 0) + 1

    -- The widest observed percentage delta is the least rounded measurement,
    -- which is why ShaguPlates keeps it in preference to a later smaller one.
    if not record.diff or diff > record.diff then
        record.max = estimate
        record.diff = diff
    end
end

local healthFrame = CreateFrame("Frame", "EquadisOverhaulNameplateHealth", UIParent)
healthFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
healthFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
healthFrame:RegisterEvent("UNIT_HEALTH")
healthFrame:RegisterEvent("UNIT_COMBAT")
healthFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" then
        resetHealthLearning()
        return
    end

    if event == "UNIT_COMBAT" and arg1 == "target" and healthLearn.key then
        if arg2 == "HEAL" then
            healthLearn.damage = 0
            healthLearn.startPercent = UnitHealth("target") or healthLearn.startPercent
            return
        end

        local amount = tonumber(arg4)
        if amount and amount > 0 then healthLearn.damage = healthLearn.damage + amount end
        return
    end

    if event == "UNIT_HEALTH" and arg1 == "target" then recordHealthChange() end
end)

function M:EstimatedHealth(name, level, fraction)
    local cfg = self:Config()
    if not OB.mobHealth then return nil end

    local key = mobHealthKey(name, level)
    if not key then return nil end

    local record = OB.mobHealth[key]
    if type(record) ~= "table" then return nil end
    if not record.max or record.max <= 0 then return nil end
    if (record.hits or 0) < cfg.healthEstimateHits then return nil end
    if (record.diff or 0) < cfg.healthEstimateDamage then return nil end

    return ceil(record.max * fraction), record.max, true
end

-- ---------------------------------------------------------------------------
-- finding and adopting client plates
-- ---------------------------------------------------------------------------

function M:IsNamePlate(frame)
    if not frame or not frame.GetObjectType then return false end
    if frame:GetObjectType() ~= PLATE_TYPE then return false end

    local region = frame:GetRegions()
    if not region or not region.GetObjectType or not region.GetTexture then return false end
    if region:GetObjectType() ~= "Texture" then return false end

    return region:GetTexture() == PLATE_BORDER
end

function M:Scan()
    local count = WorldFrame:GetNumChildren()
    if count <= (self.seen or 0) then return 0 end

    local children = { WorldFrame:GetChildren() }
    local found = 0

    for i = (self.seen or 0) + 1, count do
        local frame = children[i]
        if self:IsNamePlate(frame) and not self.plates[frame] then
            self:Adopt(frame)
            found = found + 1
        end
    end

    self.seen = count
    return found
end

local function silence(object)
    if not object or not object.GetObjectType then return end
    local kind = object:GetObjectType()

    if kind == "Texture" then
        object:SetTexture("")
        object:SetTexCoord(0, 0, 0, 0)
    elseif kind == "FontString" then
        object:SetWidth(0.001)
    elseif kind == "StatusBar" then
        object:SetStatusBarTexture("")
    end
end

local function newBorder(parent, level)
    local border = CreateFrame("Frame", nil, parent)
    border:SetFrameLevel(level)
    border:Hide()
    return border
end

function M:ResetPlateIdentity(plate)
    plate.identityName = nil
    plate.identityLevel = nil
    plate.playerVerified = nil
    plate.playerClass = nil
    plate.classification = nil
    plate.creatureType = nil
    plate.debuffVerify = nil
    plate.nextAuraScan = 0

    if plate.debuffCache then
        for i = 1, 16 do plate.debuffCache[i] = nil end
    end
end

function M:Adopt(frame)
    local plate = {
        frame = frame,
        original = {},
        debuffs = {},
        combo = {},
        debuffCache = {},
    }

    local health, cast = frame:GetChildren()
    plate.original.health = health
    plate.original.cast = cast
    silence(health)
    silence(cast)

    local regions = { frame:GetRegions() }
    for i = 1, table.getn(regions) do
        local key = PLATE_REGIONS[i]

        if key == "raidicon" then
            plate.raidicon = regions[i]
        elseif key then
            plate.original[key] = regions[i]
            silence(regions[i])
        else
            silence(regions[i])
        end
    end

    plate.overlay = CreateFrame("Frame", nil, frame)
    plate.overlay:SetFrameLevel(frame:GetFrameLevel() + 2)

    plate.targetGlow = newBorder(plate.overlay, plate.overlay:GetFrameLevel() + 1)

    plate.health = CreateFrame("StatusBar", nil, plate.overlay)
    plate.health:SetFrameLevel(plate.overlay:GetFrameLevel() + 2)

    plate.background = plate.health:CreateTexture(nil, "BACKGROUND")
    plate.background:SetAllPoints(plate.health)

    plate.healthBorder = newBorder(plate.overlay, plate.health:GetFrameLevel() + 1)

    plate.healthTextLayer = CreateFrame("Frame", nil, plate.overlay)
    plate.healthTextLayer:SetFrameLevel(plate.healthBorder:GetFrameLevel() + 1)
    plate.healthTextLayer:SetAllPoints(plate.health)

    plate.name = OB.NewText(plate.overlay, "OVERLAY", "GameFontNormal")
    plate.level = OB.NewText(plate.overlay, "OVERLAY", "GameFontNormalSmall")
    plate.text = OB.NewText(plate.healthTextLayer, "OVERLAY", "GameFontHighlight")
    plate.text:SetTextColor(1, 1, 1, 1)

    plate.cast = CreateFrame("StatusBar", nil, plate.overlay)
    plate.cast:SetFrameLevel(plate.health:GetFrameLevel())
    plate.cast:Hide()

    plate.castBackground = plate.cast:CreateTexture(nil, "BACKGROUND")
    plate.castBackground:SetAllPoints(plate.cast)

    plate.castBorder = newBorder(plate.overlay, plate.cast:GetFrameLevel() + 1)

    plate.castTextLayer = CreateFrame("Frame", nil, plate.overlay)
    plate.castTextLayer:SetFrameLevel(plate.castBorder:GetFrameLevel() + 1)
    plate.castTextLayer:SetAllPoints(plate.cast)

    plate.castName = OB.NewText(plate.castTextLayer, "OVERLAY", "GameFontHighlight")
    plate.castName:SetTextColor(1, 1, 1, 1)

    for i = 1, 16 do
        local icon = plate.overlay:CreateTexture(nil, "OVERLAY")
        icon:SetTexCoord(0.078, 0.92, 0.079, 0.937)
        icon:Hide()
        plate.debuffs[i] = icon
    end

    for i = 1, 5 do
        local point = plate.overlay:CreateTexture(nil, "OVERLAY")
        point:SetWidth(6)
        point:SetHeight(6)
        point:Hide()
        plate.combo[i] = point
    end

    if plate.raidicon and plate.raidicon.SetParent then
        plate.raidicon:SetParent(plate.overlay)
    end

    self.plates[frame] = plate
    table.insert(self.order, plate)

    self:ResetPlateIdentity(plate)
    self:Style(plate)
    return plate
end

-- ---------------------------------------------------------------------------
-- shared-look styling
-- ---------------------------------------------------------------------------

function M:StyleBorder(border, anchor, moduleId)
    local pad = OB.BorderPad(moduleId)
    local edge = OB.borderEdges[OB.Look(moduleId).border]

    if pad > 0 and edge then
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
        border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
        border:SetBackdrop(edge)
        border:SetBackdropBorderColor(1, 1, 1, 1)
        border:Show()
    else
        border:SetBackdrop(nil)
        border:Hide()
    end
end

function M:StyleTargetGlow(plate)
    local cfg = self:Config()
    local edge = OB.borderEdges[3] or OB.borderEdges[2]

    plate.targetGlow:ClearAllPoints()
    plate.targetGlow:SetPoint("TOPLEFT", plate.health, "TOPLEFT", -8, 8)
    plate.targetGlow:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 8, -8)
    plate.targetGlow:SetBackdrop(edge)

    local c = cfg.targetGlowColor
    plate.targetGlow:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
end

function M:StyleHealthText(plate)
    local cfg = self:Config()
    local pos = cfg.healthTextPos or "CENTER"

    plate.text:ClearAllPoints()
    plate.text:SetJustifyH(pos)

    if pos == "LEFT" then
        plate.text:SetPoint("LEFT", plate.health, "LEFT", 2, 0)
    elseif pos == "RIGHT" then
        plate.text:SetPoint("RIGHT", plate.health, "RIGHT", -2, 0)
    else
        plate.text:SetPoint("CENTER", plate.health, "CENTER", 0, 0)
    end
end

function M:PositionDebuffs(plate)
    local cfg = self:Config()
    local size = cfg.debuffSize
    local anchor = plate.name
    local point, relativePoint, y

    if cfg.debuffPosition == "BOTTOM" then
        anchor = plate.cast:IsShown() and plate.cast or plate.health
        point, relativePoint, y = "TOPLEFT", "BOTTOMLEFT", -cfg.debuffOffset
    else
        point, relativePoint, y = "BOTTOMLEFT", "TOPLEFT", cfg.debuffOffset
    end

    for i = 1, 16 do
        local icon = plate.debuffs[i]
        icon:SetWidth(size)
        icon:SetHeight(size)
        icon:ClearAllPoints()
        icon:SetPoint(point, anchor, relativePoint, (i - 1) * (size + 2), y)
    end
end

function M:Style(plate)
    local cfg = self:Config()
    local look = OB.Look("nameplates")
    local texture = OB.textures[look.texture] or OB.textures[1]
    local bg = cfg.backgroundColor

    plate.overlay:ClearAllPoints()
    plate.overlay:SetPoint("CENTER", plate.frame, "CENTER", 0, cfg.verticalOffset)
    plate.overlay:SetWidth(cfg.width + 80)
    plate.overlay:SetHeight(cfg.height + cfg.castbarHeight + cfg.debuffSize + 50)

    plate.health:SetWidth(cfg.width)
    plate.health:SetHeight(cfg.height)
    plate.health:ClearAllPoints()
    plate.health:SetPoint("CENTER", plate.overlay, "CENTER", 0, 0)
    plate.health:SetStatusBarTexture(texture)
    plate.health:SetOrientation(cfg.verticalHealth and "VERTICAL" or "HORIZONTAL")
    plate.background:SetTexture(bg[1], bg[2], bg[3], bg[4] or 0.72)

    self:StyleBorder(plate.healthBorder, plate.health, "nameplates")
    self:StyleTargetGlow(plate)

    plate.name:ClearAllPoints()
    plate.name:SetPoint("BOTTOM", plate.health, "TOP", 0, 2)
    OB.ApplyFont(plate.name, cfg.nameSize, "nameplates")

    plate.level:ClearAllPoints()
    plate.level:SetPoint("RIGHT", plate.health, "LEFT", -3, 0)
    OB.ApplyFont(plate.level, cfg.nameSize, "nameplates")

    OB.ApplyFont(plate.text, cfg.nameSize - 2, "nameplates")
    self:StyleHealthText(plate)

    plate.cast:ClearAllPoints()
    plate.cast:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", 0, -3)
    plate.cast:SetPoint("TOPRIGHT", plate.health, "BOTTOMRIGHT", 0, -3)
    plate.cast:SetHeight(cfg.castbarHeight)
    plate.cast:SetStatusBarTexture(texture)
    plate.castBackground:SetTexture(bg[1], bg[2], bg[3], bg[4] or 0.72)
    self:StyleBorder(plate.castBorder, plate.cast, "nameplates")

    plate.castName:ClearAllPoints()
    plate.castName:SetPoint("CENTER", plate.cast, "CENTER", 0, 0)
    OB.ApplyFont(plate.castName, cfg.nameSize - 1, "nameplates")

    self:PositionDebuffs(plate)

    for i = 1, 5 do
        plate.combo[i]:ClearAllPoints()
        plate.combo[i]:SetPoint("TOPRIGHT", plate.health, "BOTTOMRIGHT",
                -((i - 1) * 8), -2)
    end

    if plate.raidicon then
        plate.raidicon:ClearAllPoints()
        plate.raidicon:SetPoint(cfg.raidIconPosition, plate.health,
                cfg.raidIconPosition, cfg.raidIconX, cfg.raidIconY)
        plate.raidicon:SetWidth(cfg.raidIconSize)
        plate.raidicon:SetHeight(cfg.raidIconSize)
    end

    if plate.frame.EnableMouse then plate.frame:EnableMouse(not cfg.clickThrough) end
end

-- ---------------------------------------------------------------------------
-- plate metadata
-- ---------------------------------------------------------------------------

function M:OriginalLevel(plate)
    local original = plate.original.level
    if not original then return nil, "??" end

    local text = original:GetText()
    local numeric = tonumber(text)
    return numeric, text or "??"
end

function M:IsTarget(plate)
    if not UnitExists("target") then return false end
    if not plate.frame.GetAlpha then return false end
    return plate.frame:GetAlpha() == 1
end

function M:ExactUnit(plate, name)
    if plate.istarget and UnitExists("target") and UnitName("target") == name then
        return "target"
    end

    if UnitExists("mouseover") and UnitName("mouseover") == name then
        local glow = plate.original.glow
        if not glow or not glow.IsShown or glow:IsShown() then return "mouseover" end
    end

    return nil
end

function M:RefreshIdentity(plate, name, level, unit)
    if plate.identityName ~= name or plate.identityLevel ~= level then
        self:ResetPlateIdentity(plate)
        plate.identityName = name
        plate.identityLevel = level
    end

    if not unit or not UnitExists(unit) or UnitName(unit) ~= name then return end

    if UnitIsPlayer then
        plate.playerVerified = UnitIsPlayer(unit) and true or false
    end

    if plate.playerVerified then
        local localized, token = UnitClass(unit)
        plate.playerClass = token or OB.ClassToken(localized) or plate.playerClass
    end

    if type(UnitClassification) == "function" then
        local classification = UnitClassification(unit)
        if classification and classification ~= "normal" then
            plate.classification = classification
        elseif classification == "normal" then
            plate.classification = nil
        end
    end

    if type(UnitCreatureType) == "function" then
        plate.creatureType = UnitCreatureType(unit)
    end
end

function M:KindForPlate(plate, base)
    if base == "FRIENDLY_PLAYER" then return "FRIENDLY_PLAYER" end
    if base == "ENEMY_NPC" and plate.playerVerified == true then return "ENEMY_PLAYER" end
    return base
end

function M:PlayerClass(plate, name, kind)
    -- Blue stock plates are intrinsically players. Red plates are not: enemy
    -- players and enemy NPCs share the same stock colour, so they must have been
    -- verified through target/mouseover before roster data is trusted.
    if kind ~= "FRIENDLY_PLAYER" and not plate.playerVerified then return nil end
    if plate.playerClass then return plate.playerClass end

    -- The roster may fill the class after /who, but it never gets to decide that
    -- a red plate is a player. This is the recent ShaguPlates NPC-name bugfix
    -- carried over while still allowing friendly blue plates to use the roster.
    local known = OB.roster and OB.roster[name]
    if known and known.class then return known.class end
    return nil
end

function M:ShouldShow(kind)
    local key = SHOWN_BY[kind]
    if not key then return true end
    return self:Config()[key] and true or false
end

function M:PlateColor(plate, kind, name)
    local cfg = self:Config()

    if (kind == "ENEMY_PLAYER" and cfg.enemyClassColor)
            or (kind == "FRIENDLY_PLAYER" and cfg.friendlyClassColor) then
        local class = self:PlayerClass(plate, name, kind)
        if class then
            local r, g, b = OB.ClassColor(class)
            return { r, g, b, 1 }
        end
    end

    return cfg[COLOR_KEY[kind] or "enemyColor"] or cfg.enemyColor
end

function M:ClassificationSuffix(plate)
    local value = plate.classification
    if value and CLASS_SUFFIX[value] then return CLASS_SUFFIX[value] end

    -- The stock level icon appears only for special NPC classifications and is
    -- never a player marker. When there is no exact token, '+' is the honest
    -- amount of detail rather than guessing rare vs elite.
    if plate.playerVerified ~= true and plate.original.levelicon
            and plate.original.levelicon.IsShown
            and plate.original.levelicon:IsShown() then
        return "+"
    end

    return ""
end

function M:CreatureIs(plate, globalName, fallback)
    if not plate.creatureType then return false end
    local expected = getglobal(globalName) or fallback
    return expected and string.lower(plate.creatureType) == string.lower(expected)
end

function M:ShouldHideHealth(plate, kind)
    local cfg = self:Config()
    local key = HIDE_HEALTH_KEY[kind]
    if key and cfg[key] then return true end

    if cfg.hideCritterHealth and self:CreatureIs(plate, "CREATURE_TYPE_CRITTER", "Critter") then
        return true
    end

    if cfg.hideTotemHealth and self:CreatureIs(plate, "CREATURE_TYPE_TOTEM", "Totem") then
        return true
    end

    return false
end

function M:ShortName(name)
    if not name or name == "" then return "" end
    local cfg = self:Config()
    if not cfg.shortenNames then return name end
    if string.len(name) <= cfg.nameMaxLength then return name end

    -- ShaguPlates first abbreviates only the first word, preserving as much of
    -- the readable name as possible. Only if that still overflows do all leading
    -- words collapse to initials.
    local first = string.gsub(name, "^(%S+) ", function(word)
        return string.sub(word, 1, 1) .. ". "
    end)

    if string.len(first) <= cfg.nameMaxLength then return first end

    return string.gsub(name, "([^%s]+) ", function(word)
        return string.sub(word, 1, 1) .. ". "
    end)
end

-- ---------------------------------------------------------------------------
-- target state
-- ---------------------------------------------------------------------------

function M:TargetThreat()
    if not UnitExists("target") or not UnitExists("targettarget") then return nil end
    if UnitCanAssist and UnitCanAssist("player", "target") then return nil end
    return UnitIsUnit("targettarget", "player") and true or false
end

function M:ComboPoints()
    if type(GetComboPoints) ~= "function" then return 0 end
    return GetComboPoints() or 0
end

function M:RefreshTargetTreatment(plate, target)
    local cfg = self:Config()

    if cfg.markTarget then
        if target then
            plate.overlay:SetScale(cfg.targetScale)
            plate.overlay:SetAlpha(1)
            plate.overlay:SetFrameStrata("LOW")
        else
            plate.overlay:SetScale(1)
            plate.overlay:SetFrameStrata("BACKGROUND")
            if UnitExists("target") then
                plate.overlay:SetAlpha(cfg.otherAlpha)
            else
                plate.overlay:SetAlpha(1)
            end
        end
    else
        plate.overlay:SetScale(1)
        plate.overlay:SetAlpha(1)
        plate.overlay:SetFrameStrata(target and "LOW" or "BACKGROUND")
    end

    if target and cfg.targetGlow then plate.targetGlow:Show() else plate.targetGlow:Hide() end

    if plate.healthBorder:IsShown() then
        if target and cfg.targetBorder then
            local c = cfg.targetBorderColor
            plate.healthBorder:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
        else
            plate.healthBorder:SetBackdropBorderColor(1, 1, 1, 1)
        end
    end
end

-- ---------------------------------------------------------------------------
-- cast bars
-- ---------------------------------------------------------------------------

function M:RefreshCast(plate)
    local cfg = self:Config()

    if not cfg.castbar or (cfg.castTargetOnly and not plate.istarget)
            or not plate.original.name then
        plate.cast:Hide()
        plate.castBorder:Hide()
        return
    end

    local who = plate.original.name:GetText()
    local spell, fraction = OB.CastInfo(who)

    if not spell then
        plate.cast:Hide()
        plate.castBorder:Hide()
        return
    end

    plate.cast:SetMinMaxValues(0, 1)
    plate.cast:SetValue(fraction or 1)
    plate.cast:SetStatusBarColor(cfg.castColor[1], cfg.castColor[2],
            cfg.castColor[3], cfg.castColor[4] or 1)

    if cfg.showCastName then
        plate.castName:SetText(spell)
        plate.castName:Show()
    else
        plate.castName:Hide()
    end

    plate.cast:Show()
    self:StyleBorder(plate.castBorder, plate.cast, "nameplates")
end

-- ---------------------------------------------------------------------------
-- debuff cache / filtering
-- ---------------------------------------------------------------------------

local function trim(text)
    if not text then return "" end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

function M:BuildDebuffFilter()
    local cfg = self:Config()
    local signature = (cfg.debuffFilter or "none") .. "\031" .. (cfg.debuffList or "")

    if self.debuffFilterSignature == signature then return end
    self.debuffFilterSignature = signature
    self.debuffFilterMode = cfg.debuffFilter or "none"
    self.debuffFilterSet = {}

    local raw = string.gsub(cfg.debuffList or "", "[#;]", ",") .. ","
    string.gsub(raw, "([^,]*),", function(token)
        token = string.lower(trim(token))
        if token ~= "" then self.debuffFilterSet[token] = true end
        return ""
    end)
end

function M:DebuffAllowed(spell)
    self:BuildDebuffFilter()
    if self.debuffFilterMode == "none" then return true end
    if not spell then return self.debuffFilterMode ~= "whitelist" end

    local listed = self.debuffFilterSet[string.lower(spell)] and true or false
    if self.debuffFilterMode == "whitelist" then return listed end
    if self.debuffFilterMode == "blacklist" then return not listed end
    return true
end

function M:ScanExactDebuffs(plate, unit, verify)
    if not unit or not UnitExists(unit) then return false end
    if not plate.original.name or UnitName(unit) ~= plate.original.name:GetText() then return false end

    local tip = OB.ScanTooltip()
    local fresh = {}

    for i = 1, 16 do
        local texture, stacks = UnitDebuff(unit, i)
        if not texture then break end

        local spell
        if type(tip.SetUnitDebuff) == "function" then
            tip:ClearLines()
            if pcall(tip.SetUnitDebuff, tip, unit, i) then spell = OB.ScanLine(1) end
        end

        if spell == "" then spell = nil end
        fresh[i] = {
            spell = spell,
            icon = texture,
            stacks = tonumber(stacks) or 0,
            seen = GetTime(),
        }

        if spell then OB.AddAura(UnitName(unit), spell, texture) end
    end

    plate.debuffCache = fresh
    plate.debuffVerify = verify
    return true
end

function M:CachedDebuffs(plate, verify)
    if plate.debuffVerify ~= verify then return nil end
    local out = {}

    for i = 1, 16 do
        local entry = plate.debuffCache[i]
        if entry then table.insert(out, entry) end
    end

    return out
end

function M:DebuffSource(plate, unit, name, level)
    local cfg = self:Config()
    local verify = (name or "") .. ":" .. tostring(level or "??")
    local now = GetTime()

    if unit and now >= (plate.nextAuraScan or 0) then
        self:ScanExactDebuffs(plate, unit, verify)
        plate.nextAuraScan = now + 0.25
    end

    local cached = self:CachedDebuffs(plate, verify)
    if cached and table.getn(cached) > 0 then return cached end

    if cfg.guessDebuffs then return OB.AuraList(name, 16) end
    return {}
end

function M:RefreshDebuffs(plate, unit, name, level)
    local cfg = self:Config()
    local drawn = 0
    local list = {}

    if cfg.debuffs then list = self:DebuffSource(plate, unit, name, level) end

    for i = 1, table.getn(list) do
        local entry = list[i]
        if drawn >= cfg.debuffCount then break end

        if entry and entry.icon and self:DebuffAllowed(entry.spell) then
            drawn = drawn + 1
            plate.debuffs[drawn]:SetTexture(entry.icon)
            plate.debuffs[drawn]:Show()
        end
    end

    for i = drawn + 1, 16 do plate.debuffs[i]:Hide() end
    self:PositionDebuffs(plate)
end

-- ---------------------------------------------------------------------------
-- health / text formatting
-- ---------------------------------------------------------------------------

function M:HealthValues(plate, name, level, fraction, unit)
    -- If an exact unit actually exposes real values, take them first.
    if unit and UnitExists(unit) then
        local cur = UnitHealth(unit) or 0
        local max = UnitHealthMax(unit) or 0
        if max > 100 then return cur, max, true end
    end

    -- Compatibility with MobHealth3 if somebody already runs it.
    if plate.istarget and (MobHealth3 or MobHealthFrame)
            and type(MobHealth_GetTargetCurHP) == "function"
            and type(MobHealth_GetTargetMaxHP) == "function" then
        local cur = MobHealth_GetTargetCurHP()
        local max = MobHealth_GetTargetMaxHP()
        if cur and max and max > 0 then return cur, max, true end
    end

    return self:EstimatedHealth(name, level, fraction)
end

function M:FormatHealth(plate, name, level, fraction, unit)
    local cfg = self:Config()
    if cfg.healthText == "none" then return "" end

    local cur, max, known = self:HealthValues(plate, name, level, fraction, unit)
    local percent = floor(fraction * 100 + 0.5)

    if not known or not cur or not max or max <= 0 then
        -- Never invent current/max values. A mode which asks for something we do
        -- not know degrades to the one value the stock plate actually supplies.
        return percent .. "%"
    end

    if cfg.healthText == "deficit" then return "-" .. (max - cur) end
    return OB.FormatValue(cur, max, cfg.healthText)
end

-- ---------------------------------------------------------------------------
-- one complete plate refresh
-- ---------------------------------------------------------------------------

function M:RefreshNameColor(plate, kind, name)
    local cfg = self:Config()

    if kind == "FRIENDLY_PLAYER" and cfg.friendlyNameClassColor then
        local class = self:PlayerClass(plate, name, kind)
        if class then
            local r, g, b = OB.ClassColor(class)
            plate.name:SetTextColor(r, g, b, 1)
            return
        end
    end

    if cfg.nameInCombatColor and plate.original.name
            and plate.original.name.GetTextColor then
        local r, g, b = plate.original.name:GetTextColor()
        if r > 0.9 and g < 0.2 and b < 0.2 then
            plate.name:SetTextColor(1, 0.4, 0.2, 1)
            return
        end
    end

    plate.name:SetTextColor(1, 1, 1, 1)
end

function M:RefreshLevelColor(plate)
    if plate.original.level and plate.original.level.GetTextColor then
        local r, g, b = plate.original.level:GetTextColor()
        plate.level:SetTextColor(math.min(1, r + 0.3),
                math.min(1, g + 0.3), math.min(1, b + 0.3), 1)
    else
        plate.level:SetTextColor(1, 1, 1, 1)
    end
end

function M:Refresh(plate)
    local original = plate.original
    if not original.health then return end

    local cfg = self:Config()
    local value = original.health:GetValue() or 0
    local low, high = original.health:GetMinMaxValues()
    low, high = low or 0, high or 1

    local span = high - low
    if span <= 0 then span = 1 end

    local fraction = (value - low) / span
    if fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end

    local name = original.name and original.name:GetText() or ""
    local level, levelText = self:OriginalLevel(plate)

    plate.istarget = self:IsTarget(plate)
    local unit = self:ExactUnit(plate, name)
    self:RefreshIdentity(plate, name, level, unit)

    local base
    if original.health.GetStatusBarColor then
        base = OB.PlateKind(original.health:GetStatusBarColor())
    end
    base = base or "ENEMY_NPC"

    local kind = self:KindForPlate(plate, base)
    plate.kind = kind

    -- An exact hostile player is valuable roster data. Queue its class lookup if
    -- it is not known already, but verification still came from UnitIsPlayer.
    if (kind == "ENEMY_PLAYER" or kind == "FRIENDLY_PLAYER") and OB.WantPlayer then
        OB.WantPlayer(name)
    end

    if not self:ShouldShow(kind) then
        plate.overlay:Hide()
        return
    end
    plate.overlay:Show()

    plate.health:SetMinMaxValues(0, 1)
    plate.health:SetValue(fraction)

    local color = self:PlateColor(plate, kind, name)
    if plate.istarget and cfg.colorByThreat then
        local onMe = self:TargetThreat()
        if onMe == true then color = cfg.threatColor
        elseif onMe == false then color = cfg.noThreatColor end
    end
    plate.health:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)

    local hideHealth = self:ShouldHideHealth(plate, kind)
    if hideHealth then
        plate.health:Hide()
        plate.healthBorder:Hide()
        plate.text:Hide()
    else
        plate.health:Show()
        self:StyleBorder(plate.healthBorder, plate.health, "nameplates")
    end

    self:RefreshTargetTreatment(plate, plate.istarget)

    if cfg.showName and original.name then
        plate.name:SetText(self:ShortName(name))
        self:RefreshNameColor(plate, kind, name)
        plate.name:Show()
    else
        plate.name:Hide()
    end

    if cfg.showLevel and original.level then
        plate.level:SetText((levelText or "??") .. self:ClassificationSuffix(plate))
        self:RefreshLevelColor(plate)
        plate.level:Show()
    else
        plate.level:Hide()
    end

    if not hideHealth and cfg.healthText ~= "none" then
        plate.text:SetText(self:FormatHealth(plate, name, level, fraction, unit))
        plate.text:Show()
    else
        plate.text:Hide()
    end

    self:RefreshCast(plate)
    self:RefreshDebuffs(plate, unit, name, level)

    local points = 0
    if plate.istarget and cfg.showCombo then points = self:ComboPoints() end
    for i = 1, 5 do
        if i <= points then
            plate.combo[i]:SetTexture(cfg.comboColor[1], cfg.comboColor[2],
                    cfg.comboColor[3], cfg.comboColor[4] or 1)
            plate.combo[i]:Show()
        else
            plate.combo[i]:Hide()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Blizzard plate visibility switches
-- ---------------------------------------------------------------------------

function M:ApplyGameVisibility()
    local cfg = self:Config()

    if type(ShowNameplates) == "function" and type(HideNameplates) == "function" then
        if cfg.enemyNpc or cfg.neutralNpc or cfg.enemyPlayer then
            ShowNameplates()
        else
            HideNameplates()
        end
    end

    if type(ShowFriendNameplates) == "function" and type(HideFriendNameplates) == "function" then
        if cfg.friendlyNpc or cfg.friendlyPlayer then
            ShowFriendNameplates()
        else
            HideFriendNameplates()
        end
    end
end

-- ---------------------------------------------------------------------------
-- binding / update
-- ---------------------------------------------------------------------------

function M:OnUpdate(now)
    if not OB.ModuleEnabled("nameplates") then return end

    self:Scan()

    for i = 1, table.getn(self.order) do
        local plate = self.order[i]
        local visible = plate.frame:IsVisible()

        if visible then
            -- Nameplate frames are recycled. A hide->show transition can be a
            -- different mob with the same name and level, so no per-plate aura
            -- or identity cache survives it. This is the latest ShaguPlates
            -- stale-debuff-cache fix, adapted to the Overhaul's polling model.
            if not plate.wasVisible then self:ResetPlateIdentity(plate) end
            plate.wasVisible = true
            self:Refresh(plate)
        else
            plate.wasVisible = false
            plate.overlay:Hide()
        end
    end
end

function M:OnBind()
    self.plates = self.plates or {}
    self.order = self.order or {}
    self.seen = 0
    self.debuffFilterSignature = nil
    self:ApplyGameVisibility()
end

function M:OnStyle()
    if not self.order then return end

    self.debuffFilterSignature = nil
    self:ApplyGameVisibility()

    for i = 1, table.getn(self.order) do self:Style(self.order[i]) end
end

function M:OnDraw() end
