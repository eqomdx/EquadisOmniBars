--[[ Equadis' Classic Overhaul :: tooltip

  Presentation only.

  Loot knowledge lives in modules/itemdatabase.lua. This module decides where
  GameTooltip sits, how it looks, and how much of the database is previewed on
  mouseover. Sorting and tooltip-filter policy live in Item Database; the full
  Ctrl+Alt browser intentionally ignores those filters and always shows every
  known drop.
]]--

local OB = EquadisClassicOverhaul

local HEALTH_TEXT_KEYS = { "none", "current", "percent", "max", "currentpct", "maxpct" }
local HEALTH_TEXT_LABELS = { "None", "Current Only", "Percentage", "Current / Max",
                             "Current (Percent)", "Current / Max (Percent)" }
local DEAD_BAR_COLOR = { 0.45, 0.45, 0.45 }
local HEALTH_BG_COLOR = { 0.055, 0.055, 0.055, 1 }

-- Money colours are intentionally fixed rather than item-quality colours. These
-- are the exact gold/silver/copper display colours used by the Tooltip money
-- formatter and by the dropdown previews below.
local MONEY_GOLD_HEX = "f7d742"
local MONEY_SILVER_HEX = "a5a4a5"
local MONEY_COPPER_HEX = "b06e48"
local MONEY_FORMAT_KEYS = { "values", "denominations", "suffixes" }
local MONEY_FORMAT_LABELS = {
    "|cfff7d7421|r.|cffa5a4a502|r.|cffb06e4803|r",
    "|cfff7d7421g|r |cffa5a4a523s|r |cffb06e4845c|r",
    "|cffffffff1|r|cfff7d742g|r |cffffffff23|r|cffa5a4a5s|r |cffffffff45|r|cffb06e48c|r",
}

local M = OB.RegisterModule({
    id = "tooltip",
    name = "Tooltip",
    feature = true,
    renders = "none",
    -- Tooltip owns a deliberately different appearance block from HUD bars:
    -- its health bar needs a second font and its frame has a background colour.
    -- Keep the rows explicit instead of auto-appending OB.LookOptions().
    styled = false,
    defaultEnabled = true,

    defaults = {
        atMouse = false,
        offsetX = 0,
        offsetY = 0,
        mouseOffsetX = 0,
        mouseOffsetY = 0,

        enableFade = true,
        fadeDelay = 0.35,
        healthTextMode = "max",

        showQuestIds = false,
        showItemValues = true,
        showHiddenItemText = false,
        moneyFormat = "denominations",
        hideQuestItems = false,
        hideWorldDrops = false,

        showItemDrops = true,
        minimumDropQuality = 0,
        itemDropLines = 5,

        scale = 1,
        texture = 8,
        background = { 0, 0, 0, 0.85 },
        border = 1,
        font = OB.fontIndex["Roboto"] or 1,
        fontSize = 12,
        barFont = OB.fontIndex["Roboto"] or 1,
        barFontSize = 12,
        -- 16 is the current effective default: the stock bar is expanded to
        -- fit the default 12px bar font with 4px of vertical breathing room.
        barHeight = 16,
        barTextColor = { 1.00, 0.82, 0.00, 1 },
        fontOutline = true,

        -- Name colour is reaction-based. Player Target is intentionally separate:
        -- it colours the explicit (Player) marker, while the player's actual name
        -- still communicates friendly / neutral / hostile at a glance.
        friendlyTarget = { 0.20, 1.00, 0.20, 1 },
        neutralTarget = { 1.00, 1.00, 0.00, 1 },
        hostileTarget = { 1.00, 0.10, 0.10, 1 },
        playerTarget = { 0.00, 0.65, 1.00, 1 },
    },

    options = {
        { "Frame", "__s_frame", "section", "frame" },
        { "Anchor Tooltip To Cursor", "atMouse", "boolean" },
        -- Fixed placement: (0,0) is the centre of UIParent. Keep this range
        -- intentionally practical; dragging writes the exact same coordinates.
        { "X Position", "offsetX", "slider", -800, 800, 1, nil, "!atMouse" },
        { "Y Position", "offsetY", "slider", -500, 500, 1, nil, "!atMouse" },
        { "Move Tooltip", "__a_drag", "action",
          function() OB.modules.tooltip:ToggleMoveMode() end,
          function()
              local m = OB.modules.tooltip
              if m.moveMode then return "Done Placing" end
              return "Move Tooltip"
          end, nil, nil, "!atMouse" },
        -- Cursor placement gets its own offsets. Reusing fixed X/Y here caused
        -- the old ANCHOR_CURSOR bug because screen coordinates are not cursor
        -- offsets. Zero means exactly the stock cursor anchor.
        { "Mouse X Offset", "mouseOffsetX", "slider", -300, 300, 1, nil, "atMouse" },
        { "Mouse Y Offset", "mouseOffsetY", "slider", -300, 300, 1, nil, "atMouse" },
        { "Enable Tooltip Fade", "enableFade", "boolean" },
        { "Fade Delay", "fadeDelay", "slider", 0.1, 3.0, 0.1,
          nil, nil, "!enableFade" },
        { "Show Quest IDs", "showQuestIds", "boolean" },
        { "Show Item Values", "showItemValues", "boolean" },
        { "Show Hidden Item Text", "showHiddenItemText", "boolean" },
        { "Money Format", "moneyFormat",
          OB.Enum(MONEY_FORMAT_KEYS, MONEY_FORMAT_LABELS),
          190, nil, nil, nil, nil, "!showItemValues" },
        { "Show Item Drops On Tooltip", "showItemDrops", "boolean" },
        { "Minimum Rarity", "minimumDropQuality",
          OB.Enum({ 0, 1, 2, 3, 4, 5, 6 },
                  { "Junk", "Normal", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" }),
          160, nil, nil, nil, nil, "!showItemDrops" },
        { "Hide Quest Items In Loot", "hideQuestItems", "boolean",
          nil, nil, nil, nil, nil, "!showItemDrops" },
        { "Hide World Drops", "hideWorldDrops", "boolean",
          nil, nil, nil, nil, nil, "!showItemDrops" },
        { "Number Of Items Shown", "itemDropLines", "slider", 1, 20, 1,
          nil, nil, "!showItemDrops" },

        { "Appearance", "__s_appearance", "section", "appearance" },

        -- Left column: the frame / bar itself.
        { "Scale", "scale", "slider", 50, 150, 5, 0.01 },
        { "Bar Texture", "texture", OB.textures, 200 },
        { "Bar Height", "barHeight", "slider", 8, 50, 1 },
        { "Background Color", "background", "color", true },
        { "Border", "border", OB.borders, 200 },
        { "Friendly Target Color", "friendlyTarget", "color", false },
        { "Neutral Target Color", "neutralTarget", "color", false },
        { "Hostile Target Color", "hostileTarget", "color", false },
        { "Player Target Color", "playerTarget", "color", false },

        -- Right column: every text setting, including the health-bar text.
        { "", "__c_text", "column", 2 },
        { "Font", "font", OB.fonts, 200 },
        { "Font Size", "fontSize", "slider", 6, 24, 1 },
        { "Bar Font", "barFont", OB.fonts, 200 },
        { "Bar Font Size", "barFontSize", "slider", 6, 24, 1 },
        { "Bar Text Color", "barTextColor", "color", false },
        { "Health Text", "healthTextMode", OB.Enum(HEALTH_TEXT_KEYS, HEALTH_TEXT_LABELS) },
        { "Font Outline", "fontOutline", "boolean" },
    },

    events = { "UPDATE_MOUSEOVER_UNIT", "PLAYER_ENTERING_WORLD" },
})

function M:Config()
    return OB.profile.modules.tooltip
end

local function tooltipLine(tip, side, index)
    if not tip or not tip.GetName then return nil end
    local name = tip:GetName()
    if not name then return nil end

    local line = getglobal(name .. "Text" .. side .. index)
    if not line or not line.GetText then return nil end
    return line
end

local function plain(text)
    if not text then return nil end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function trim(text)
    if not text then return nil end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

-- Aux and ShaguTweaks both add value information to item tooltips. Aux writes
-- ordinary text lines while ShaguTweaks' Vendor Values module calls
-- SetTooltipMoney(), which creates a separate coin-icon MoneyFrame on a blank
-- tooltip line. ECO leaves both addons' databases alone and owns only the final
-- presentation: Auction, Today, Vendor as three readable lines.
local function priceLineKind(text)
    text = string.lower(trim(plain(text) or "") or "")
    -- Vendor Buy belongs to Aux's source presentation, but ECO intentionally
    -- does not expose it. Still classify the row so it can be removed/collapsed.
    if string.find(text, "^vendor buy") then return "unused" end
    if string.find(text, "^vendor sell") then return "vendor" end
    if string.find(text, "^vendor:") then return "vendor" end
    if string.find(text, "^value:") then return "auction" end
    if string.find(text, "^11day avg:") then return "auction" end
    if string.find(text, "^auction:") then return "auction" end
    if string.find(text, "^today:") then return "today" end
    if string.find(text, "^min %+10%%:") then return "unused" end
    return nil
end

local function priceValueText(text)
    if not text then return nil end
    local colon = string.find(text, ":", 1, true)
    if not colon then return nil end
    local value = trim(string.sub(text, colon + 1))
    if not value or value == "" then return nil end
    -- Aux commonly colours the label and closes the colour immediately after
    -- the colon. Keeping a leading |r is harmless but ugly when we supply our
    -- own label, so consume it here.
    value = string.gsub(value, "^|r%s*", "")
    return value
end

local function clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function hex(r, g, b)
    return string.format("%02x%02x%02x",
            math.floor(clamp01(r) * 255 + 0.5),
            math.floor(clamp01(g) * 255 + 0.5),
            math.floor(clamp01(b) * 255 + 0.5))
end

local function chanceColor(chance)
    if pfMap and pfMap.tooltip and type(pfMap.tooltip.GetColor) == "function" then
        local r, g, b = pfMap.tooltip:GetColor(tonumber(chance) or 0, 100)
        if r and g and b then return r, g, b end
    end

    local p = clamp01((tonumber(chance) or 0) / 100)
    if p < 0.5 then return 1, p * 2, 0 end
    return (1 - p) * 2, 1, 0
end

-- ---------------------------------------------------------------------------
-- anchoring
-- ---------------------------------------------------------------------------

local CURSOR_BASE_X = 16
local CURSOR_BASE_Y = 16
local FADE_SPEED = 0.35

function M:UpdateCursorPosition(tip)
    if not tip or not tip.ClearAllPoints or not tip.SetPoint then return end
    local cfg = self:Config()
    if not cfg.atMouse then return end

    local x, y = GetCursorPosition()
    if not x or not y then return end

    -- GetCursorPosition is in physical screen pixels while SetPoint uses UI
    -- coordinates. Convert using UIParent's effective scale, then apply ECO's
    -- cursor offsets ourselves. This avoids ANCHOR_CURSOR's ignored offsets on
    -- 1.12 clients.
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    elseif UIParent and UIParent.GetScale then
        scale = UIParent:GetScale() or 1
    end
    if not scale or scale == 0 then scale = 1 end

    local cursorX = x / scale
    local cursorY = y / scale
    local offsetX = tonumber(cfg.mouseOffsetX) or 0
    local offsetY = tonumber(cfg.mouseOffsetY) or 0
    local anchorX = cursorX + CURSOR_BASE_X + offsetX
    local anchorY = cursorY + CURSOR_BASE_Y + offsetY

    -- Position the tooltip body first. The health bar is deliberately excluded
    -- from this calculation: pfUI-style tooltip bars are separate children above
    -- GameTooltip, and moving the entire tooltip because that child overflows is
    -- what made the previous edge handling unreliable. AnchorHealthBar() flips
    -- only the bar below the tooltip when necessary.
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", anchorX, anchorY)

    local parentTop = UIParent and UIParent.GetTop and UIParent:GetTop() or nil
    local parentRight = UIParent and UIParent.GetRight and UIParent:GetRight() or nil
    local tipTop = tip.GetTop and tip:GetTop() or nil
    local tipRight = tip.GetRight and tip:GetRight() or nil
    local flipY = parentTop and tipTop and tipTop > parentTop
    local flipX = parentRight and tipRight and tipRight > parentRight

    if flipY or flipX then
        tip:ClearAllPoints()
        if flipY and flipX then
            tip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT",
                    cursorX - CURSOR_BASE_X + offsetX,
                    cursorY - CURSOR_BASE_Y + offsetY)
        elseif flipY then
            tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                    anchorX,
                    cursorY - CURSOR_BASE_Y + offsetY)
        else
            tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT",
                    cursorX - CURSOR_BASE_X + offsetX,
                    anchorY)
        end
    end

    self:AnchorHealthBar(tip)
end

function M:UpdateFadeCursorPosition()
    local tip = self.fadeTooltip
    if not self.fading or not tip or not tip.IsShown or not tip:IsShown() then return end
    local cfg = self:Config()
    if not cfg.atMouse then return end

    local x, y = GetCursorPosition()
    if not x or not y then return end

    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    elseif UIParent and UIParent.GetScale then
        scale = UIParent:GetScale() or 1
    end
    if not scale or scale == 0 then scale = 1 end

    local cursorX = x / scale
    local cursorY = y / scale
    local offsetX = tonumber(cfg.mouseOffsetX) or 0
    local offsetY = tonumber(cfg.mouseOffsetY) or 0
    local anchorX = cursorX + CURSOR_BASE_X + offsetX
    local anchorY = cursorY + CURSOR_BASE_Y + offsetY

    -- The fade copy is display-only, but while cursor anchoring is enabled it
    -- should behave exactly like the live tooltip: keep following the mouse for
    -- both the delay and the fade instead of freezing at the leave position.
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", anchorX, anchorY)

    local parentTop = UIParent and UIParent.GetTop and UIParent:GetTop() or nil
    local parentRight = UIParent and UIParent.GetRight and UIParent:GetRight() or nil
    local tipTop = tip.GetTop and tip:GetTop() or nil
    local tipRight = tip.GetRight and tip:GetRight() or nil
    local flipY = parentTop and tipTop and tipTop > parentTop
    local flipX = parentRight and tipRight and tipRight > parentRight

    if flipY or flipX then
        tip:ClearAllPoints()
        if flipY and flipX then
            tip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT",
                    cursorX - CURSOR_BASE_X + offsetX,
                    cursorY - CURSOR_BASE_Y + offsetY)
        elseif flipY then
            tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                    anchorX,
                    cursorY - CURSOR_BASE_Y + offsetY)
        else
            tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT",
                    cursorX - CURSOR_BASE_X + offsetX,
                    anchorY)
        end
    end

    -- The copied health bar is parented to the copied tooltip, so only its
    -- above/below relationship needs to be refreshed as the mouse moves near the
    -- top edge. This mirrors AnchorHealthBar without touching GameTooltipStatusBar.
    local bar = self.fadeBar
    if bar and bar.IsShown and bar:IsShown() and bar.ClearAllPoints and bar.SetPoint then
        local copyTop = tip.GetTop and tip:GetTop() or nil
        local uiTop = UIParent and UIParent.GetTop and UIParent:GetTop() or nil
        local tipScale = tip.GetEffectiveScale and tip:GetEffectiveScale() or 1
        local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        local barScale = bar.GetEffectiveScale and bar:GetEffectiveScale() or tipScale
        local barHeight = bar.GetHeight and bar:GetHeight() or 12
        if not tipScale or tipScale == 0 then tipScale = 1 end
        if not uiScale or uiScale == 0 then uiScale = 1 end
        if not barScale or barScale == 0 then barScale = tipScale end

        local placeBelow = false
        if copyTop and uiTop then
            local proposedTopPx = (copyTop * tipScale) + ((barHeight + 4) * barScale)
            local screenTopPx = uiTop * uiScale
            placeBelow = proposedTopPx > (screenTopPx - 1)
        end

        bar:ClearAllPoints()
        if placeBelow then
            bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -2)
            bar:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", 0, -2)
        else
            bar:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, 2)
            bar:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 0, 2)
        end
    end
end

function M:PlaceTooltip(tip, owner)
    if not tip then return end
    local cfg = self:Config()

    if cfg.atMouse then
        -- Do not use ANCHOR_CURSOR here. Vanilla/Turtle 1.12 clients commonly
        -- ignore its X/Y offset parameters, which made the sliders appear dead.
        -- Keep the tooltip on a normal manual anchor and move it from OnUpdate.
        if tip.SetOwner then tip:SetOwner(owner or UIParent, "ANCHOR_NONE") end
        self:UpdateCursorPosition(tip)
        return
    end

    -- Fixed placement is screen-centred. (0,0) is exactly the centre of UIParent;
    -- the two sliders and drag preview both write this same coordinate system.
    if tip.SetOwner then tip:SetOwner(owner or UIParent, "ANCHOR_NONE") end
    if tip.ClearAllPoints then tip:ClearAllPoints() end
    if tip.SetPoint then
        tip:SetPoint("CENTER", UIParent, "CENTER",
                tonumber(cfg.offsetX) or 0, tonumber(cfg.offsetY) or 0)
    end
end

function M:InstallAnchor()
    if type(GameTooltip_SetDefaultAnchor) ~= "function" then return false end
    if self.anchorWrapper and GameTooltip_SetDefaultAnchor == self.anchorWrapper then return true end

    -- Another addon may replace the global after ECO binds. Wrap whatever is
    -- current rather than assuming our first startup order remained intact.
    local previous = GameTooltip_SetDefaultAnchor
    if not self.originalDefaultAnchor then self.originalDefaultAnchor = previous end

    local wrapper
    wrapper = function(tip, owner)
        local m = EquadisClassicOverhaul.modules.tooltip
        if not m or not EquadisClassicOverhaul.ModuleEnabled("tooltip") then
            return previous(tip, owner)
        end
        m:PlaceTooltip(tip, owner)
    end

    self.anchorWrapper = wrapper
    GameTooltip_SetDefaultAnchor = wrapper
    return true
end

local function round(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function compactHealthValue(value)
    value = tonumber(value) or 0
    if value >= 1000000 then
        local text = string.format("%.2fm", value / 1000000)
        text = string.gsub(text, "%.00m$", "m")
        text = string.gsub(text, "(%.[0-9])0m$", "%1m")
        return text
    end
    if value >= 1000 then
        local text = string.format("%.2fk", value / 1000)
        text = string.gsub(text, "%.00k$", "k")
        text = string.gsub(text, "(%.[0-9])0k$", "%1k")
        return text
    end
    return tostring(math.floor(value + 0.5))
end

local function healthTextLabel(mode, current, maximum)
    mode = mode or "max"
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    if mode == "none" or maximum <= 0 then return nil end

    local pct = math.floor((current / maximum) * 100 + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end

    local cur = compactHealthValue(current)
    local max = compactHealthValue(maximum)
    if mode == "current" then return cur end
    if mode == "percent" then return tostring(pct) .. "%" end
    if mode == "currentpct" then return cur .. " (" .. tostring(pct) .. "%)" end
    if mode == "maxpct" then return cur .. " / " .. max .. " (" .. tostring(pct) .. "%)" end
    return cur .. " / " .. max
end

function M:StyleMovePreview()
    local f = self.movePreview
    if not f then return end
    local cfg = self:Config()
    local look = OB.Look("tooltip")

    f:SetScale(tonumber(cfg.scale) or 1)
    f:SetBackdrop(self:TooltipBackdrop())
    local bg = cfg.background or { 0, 0, 0, 0.85 }
    f:SetBackdropColor(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.85)
    f:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)

    OB.ApplyFont(f.name, look.fontSize or 12, "tooltip")
    OB.ApplyFont(f.level, look.fontSize or 12, "tooltip")
    OB.ApplyFont(f.target, look.fontSize or 12, "tooltip")

    local fontIndex = tonumber(cfg.barFont) or tonumber(cfg.font) or (OB.fontIndex["Roboto"] or 1)
    local fontPath = OB.fontPaths[fontIndex] or STANDARD_TEXT_FONT
    local size = tonumber(cfg.barFontSize) or tonumber(cfg.fontSize) or 12
    local flags = cfg.fontOutline and "OUTLINE" or nil
    if f.healthText and f.healthText.SetFont then
        f.healthText:SetFont(fontPath, size, flags)
        if not f.healthText:GetFont() then f.healthText:SetFont(STANDARD_TEXT_FONT, size, flags) end
        self:ApplyBarTextColor(f.healthText)
    end

    if f.health then
        if f.health.SetStatusBarTexture then f.health:SetStatusBarTexture(OB.TexturePath("tooltip")) end
        local barHeight = tonumber(cfg.barHeight) or math.max(12, size + 4)
        if f.health.SetHeight then f.health:SetHeight(barHeight) end
        -- Grow the preview frame with the bar so tall bars do not overlap the
        -- example unit text. 108px is the old frame height at the 16px default.
        if f.SetHeight then f:SetHeight(92 + barHeight) end
        if f.health.SetStatusBarColor then f.health:SetStatusBarColor(0.85, 0.05, 0.05) end
    end
    if f.healthBorder then
        f.healthBorder:ClearAllPoints()
        f.healthBorder:SetPoint("TOPLEFT", f.health, "TOPLEFT", -1, 1)
        f.healthBorder:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 1, -1)
        f.healthBorder:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })
        f.healthBorder:SetBackdropColor(0, 0, 0, 0)
        f.healthBorder:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
    end

    if f.healthText then
        local text = healthTextLabel(cfg.healthTextMode, 4390, 4390)
        if text then
            f.healthText:SetText(text)
            f.healthText:Show()
        else
            f.healthText:SetText("")
            f.healthText:Hide()
        end
    end
end

function M:CreateMovePreview()
    if self.movePreview then return self.movePreview end

    local f = CreateFrame("Frame", "EquadisClassicOverhaulTooltipMovePreview", UIParent)
    f:SetWidth(270)
    f:SetHeight(108)
    f:SetFrameStrata("TOOLTIP")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()

    f.name = OB.NewText(f, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    f.name:SetText("Firegut Brute")
    f.name:SetTextColor(1, 0.1, 0.1)
    f.name:SetJustifyH("LEFT")

    f.level = OB.NewText(f, "OVERLAY", "GameFontNormal")
    f.level:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -5)
    f.level:SetText("Level 52 Humanoid")
    f.level:SetTextColor(1, 1, 1)
    f.level:SetJustifyH("LEFT")

    f.target = OB.NewText(f, "OVERLAY", "GameFontNormal")
    f.target:SetPoint("TOPLEFT", f.level, "BOTTOMLEFT", 0, -5)
    f.target:SetText("Target: Equadis")
    f.target:SetTextColor(0.2, 1, 0.2)
    f.target:SetJustifyH("LEFT")

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
    f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    f.health:SetHeight(16)
    f.health:SetMinMaxValues(0, 4390)
    f.health:SetValue(4390)

    f.healthBorder = CreateFrame("Frame", nil, f)
    f.healthBorder:SetFrameLevel((f.health.GetFrameLevel and f.health:GetFrameLevel() or 1) + 1)

    f.healthText = f.health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.healthText:SetPoint("CENTER", f.health, "CENTER", 0, 0)
    f.healthText:SetJustifyH("CENTER")
    if f.healthText.SetJustifyV then f.healthText:SetJustifyV("MIDDLE") end

    f:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then this:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function()
        this:StopMovingOrSizing()
        local cx, cy = this:GetCenter()
        local px, py = UIParent:GetCenter()
        if cx and cy and px and py then
            local cfg = M:Config()
            cfg.offsetX = clamp(round(cx - px), -800, 800)
            cfg.offsetY = clamp(round(cy - py), -500, 500)
            this:ClearAllPoints()
            this:SetPoint("CENTER", UIParent, "CENTER", cfg.offsetX, cfg.offsetY)
            if type(OB.RefreshPanel) == "function" then OB.RefreshPanel() end
        end
    end)

    self.movePreview = f
    return f
end

function M:ToggleMoveMode()
    local cfg = self:Config()
    -- Dragging edits the fixed screen anchor. While cursor anchoring is active,
    -- X/Y have no meaning, so do not leave a misleading draggable preview up.
    if cfg.atMouse then
        self.moveMode = false
        if self.movePreview then self.movePreview:Hide() end
        return
    end

    local f = self:CreateMovePreview()
    self.moveMode = not self.moveMode

    if self.moveMode then
        local cfg = self:Config()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER",
                tonumber(cfg.offsetX) or 0, tonumber(cfg.offsetY) or 0)
        self:StyleMovePreview()
        f:Show()
    else
        f:Hide()
    end

    if type(OB.RefreshPanel) == "function" then OB.RefreshPanel() end
end

-- ---------------------------------------------------------------------------
-- visual style
-- ---------------------------------------------------------------------------

function M:RememberVisuals()
    if self.visualsRemembered or not GameTooltip then return end
    self.visualsRemembered = true

    if GameTooltip.GetScale then self.originalScale = GameTooltip:GetScale() end
    if GameTooltip.GetBackdrop then self.originalBackdrop = GameTooltip:GetBackdrop() end

    self.originalFonts = {}
    for i = 1, 60 do
        for _, side in pairs({ "Left", "Right" }) do
            local line = tooltipLine(GameTooltip, side, i)
            if line and line.GetFont then
                local path, size, flags = line:GetFont()
                self.originalFonts[side .. i] = { path, size, flags }
            end
        end
    end

    local bar = GameTooltipStatusBar
    if bar then
        if bar.GetHeight then self.originalBarHeight = bar:GetHeight() end
        if bar.GetStatusBarColor then
            local r, g, b = bar:GetStatusBarColor()
            self.originalBarColor = { r, g, b }
        end
        if bar.GetStatusBarTexture then
            local texture = bar:GetStatusBarTexture()
            if texture and texture.GetTexture then self.originalBarTexture = texture:GetTexture() end
        end
        if bar.GetBackdrop then self.originalBarBackdrop = bar:GetBackdrop() end
        if bar.GetBackdropColor then
            local r, g, b, a = bar:GetBackdropColor()
            self.originalBarBackdropColor = { r, g, b, a }
        end
        if bar.GetBackdropBorderColor then
            local r, g, b, a = bar:GetBackdropBorderColor()
            self.originalBarBackdropBorderColor = { r, g, b, a }
        end
        if bar.GetPoint then
            self.originalBarPoints = {}
            local count = bar.GetNumPoints and bar:GetNumPoints() or 1
            if not count or count < 1 then count = 1 end
            for i = 1, count do
                local point, relative, relativePoint, x, y = bar:GetPoint(i)
                if point then
                    table.insert(self.originalBarPoints, { point, relative, relativePoint, x, y })
                end
            end
        end
    end
end

function M:TooltipBackdrop()
    local look = OB.Look("tooltip")
    local border = tonumber(look.border) or 1
    local edge = OB.borderEdges[border]

    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }

    if edge then
        backdrop.edgeFile = edge.edgeFile
        backdrop.edgeSize = edge.edgeSize
    end

    return backdrop
end

function M:StyleText(tip)
    if not tip or not tip.NumLines then return end

    local lines = tip:NumLines() or 0
    for i = 1, lines do
        OB.ApplyFont(tooltipLine(tip, "Left", i), nil, "tooltip")
        OB.ApplyFont(tooltipLine(tip, "Right", i), nil, "tooltip")
    end
end

function M:StyleAllFontStrings()
    if not GameTooltip then return end
    for i = 1, 60 do
        OB.ApplyFont(tooltipLine(GameTooltip, "Left", i), nil, "tooltip")
        OB.ApplyFont(tooltipLine(GameTooltip, "Right", i), nil, "tooltip")
    end
end

local function tooltipBarFonts(bar)
    local out, seen, seenFrames = {}, {}, {}

    local function add(fs)
        if fs and fs.SetFont and fs.GetText and not seen[fs] then
            table.insert(out, fs)
            seen[fs] = true
        end
    end

    local function anchoredTo(frame, target)
        if not frame or not target or not frame.GetPoint then return false end
        local count = frame.GetNumPoints and frame:GetNumPoints() or 1
        if not count or count < 1 then count = 1 end
        for pointIndex = 1, count do
            local _, relative = frame:GetPoint(pointIndex)
            if relative == target then return true end
        end
        return false
    end

    local function scanFrame(frame, inheritedBarAnchor)
        if not frame or seenFrames[frame] then return end
        seenFrames[frame] = true

        -- Some tooltip addons put their number on a child frame which is itself
        -- anchored to GameTooltipStatusBar. The FontString then anchors to that
        -- child, not directly to the bar, so the old one-level scan missed it.
        local barOwned = inheritedBarAnchor or frame == bar or anchoredTo(frame, bar)

        if frame.GetRegions then
            local regions = { frame:GetRegions() }
            for i = 1, table.getn(regions) do
                local region = regions[i]
                if region and region.SetFont and region.GetText then
                    if barOwned or anchoredTo(region, bar) then add(region) end
                end
            end
        end

        if frame.GetChildren then
            local children = { frame:GetChildren() }
            for i = 1, table.getn(children) do
                scanFrame(children[i], barOwned)
            end
        end
    end

    local names = {
        "GameTooltipStatusBarText",
        "GameTooltipStatusBarTextLeft",
        "GameTooltipStatusBarTextRight",
        "GameTooltipStatusBarHealthText",
        "GameTooltipHealthText",
    }

    for i = 1, table.getn(names) do add(getglobal(names[i])) end

    -- Known pfUI location, retained as a fast path. The recursive scan below is
    -- deliberately generic so the same suppression also works with other 1.12
    -- tooltip/health addons which create an intermediate child frame.
    if pfUI and pfUI.tooltipStatusBar then
        add(pfUI.tooltipStatusBar.HP)
    end

    scanFrame(bar, true)
    if GameTooltip then scanFrame(GameTooltip, false) end

    return out
end

function M:EnsureHealthText(bar)
    if self.healthText then return self.healthText end
    if not bar or not bar.CreateFontString then return nil end

    local fs = bar:CreateFontString("EquadisClassicOverhaulTooltipHealthText", "OVERLAY", "GameFontNormal")
    -- Use live left/right anchors rather than a fixed width. GameTooltipStatusBar
    -- is often resized after this FontString is created (especially by pfUI),
    -- so caching bar:GetWidth() here can leave the text region much narrower
    -- than the visible bar and make WoW ellipsize strings unnecessarily.
    fs:SetPoint("LEFT", bar, "LEFT", 3, 0)
    fs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    if fs.SetJustifyH then fs:SetJustifyH("CENTER") end
    if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
    self.healthText = fs
    return fs
end

function M:IsUnitDead(unit)
    if not unit then return false end
    if type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost(unit) then return true end
    if type(UnitIsDead) == "function" and UnitIsDead(unit) then return true end
    return false
end

function M:EnsureDeadBarFill(bar)
    if self.deadBarFill then return self.deadBarFill end
    if not bar or not bar.CreateTexture then return nil end

    -- A dead unit has zero health, so tinting the StatusBar itself cannot make the
    -- bar visibly grey: a zero-value status texture has zero width. ECO owns a
    -- full-width texture for the dead state instead and keeps it hidden otherwise.
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints(bar)
    fill:SetTexture(OB.TexturePath("tooltip"))
    fill:SetVertexColor(DEAD_BAR_COLOR[1], DEAD_BAR_COLOR[2], DEAD_BAR_COLOR[3])
    fill:Hide()
    self.deadBarFill = fill
    return fill
end

function M:ApplyDeadBarState(bar, unit)
    local dead = self:IsUnitDead(unit)
    self.healthIsDead = dead and true or nil

    local fill = self:EnsureDeadBarFill(bar)
    if fill then
        if dead then
            fill:SetTexture(OB.TexturePath("tooltip"))
            fill:SetVertexColor(DEAD_BAR_COLOR[1], DEAD_BAR_COLOR[2], DEAD_BAR_COLOR[3])
            fill:Show()
        else
            fill:Hide()
        end
    end
    return dead
end

function M:UpdateHealthText(bar, unit)
    local fs = self:EnsureHealthText(bar)
    if not fs then return end

    if self:ApplyDeadBarState(bar, unit) then
        fs:SetText("Dead")
        fs:Show()
        return
    end

    local current, maximum
    if unit and type(UnitHealth) == "function" and type(UnitHealthMax) == "function" then
        current = UnitHealth(unit)
        maximum = UnitHealthMax(unit)
    end

    if (not maximum or maximum <= 0) and bar and bar.GetMinMaxValues and bar.GetValue then
        local minimum
        minimum, maximum = bar:GetMinMaxValues()
        current = bar:GetValue()
    end

    if maximum and maximum > 0 then
        local text = healthTextLabel(self:Config().healthTextMode, current, maximum)
        if text then
            fs:SetText(text)
            fs:Show()
        else
            fs:SetText("")
            fs:Hide()
        end
    else
        fs:SetText("")
        fs:Hide()
    end
end

function M:InstallHealthBarValueHook(bar)
    if not bar or not bar.GetScript or not bar.SetScript then return end

    local current = bar:GetScript("OnValueChanged")
    if self.healthValueWrapper and current == self.healthValueWrapper then return end

    local previous = current
    local wrapper
    wrapper = function()
        if previous then previous() end
        local m = EquadisClassicOverhaul.modules.tooltip
        if m and EquadisClassicOverhaul.ModuleEnabled("tooltip") then
            -- Health can reach zero while the same tooltip remains open. Refresh
            -- both the text and the bar colour/fill from the live unit state.
            m:UpdateHealthText(this, m.healthUnit)
            local color = m:HealthBarColor(m.healthUnit)
            if color then
                if this.SetStatusBarColor_orig then
                    this:SetStatusBarColor_orig(color[1] or 1, color[2] or 1, color[3] or 1)
                elseif this.SetStatusBarColor then
                    this:SetStatusBarColor(color[1] or 1, color[2] or 1, color[3] or 1)
                end
            end
        end
    end

    self.healthValueWrapper = wrapper
    bar:SetScript("OnValueChanged", wrapper)
end

function M:SuppressForeignHealthText(bar)
    if not bar then return end
    local stock = tooltipBarFonts(bar)
    self.originalBarFontAlpha = self.originalBarFontAlpha or {}
    local hidden = {}

    local function suppress(fs)
        if not fs or fs == self.healthText or not fs.SetAlpha or hidden[fs] then return end
        hidden[fs] = true
        if self.originalBarFontAlpha[fs] == nil and fs.GetAlpha then
            self.originalBarFontAlpha[fs] = fs:GetAlpha()
        end
        -- Do this repeatedly while the tooltip is visible. A few 1.12 UI
        -- addons restore their own health FontString alpha every OnUpdate.
        fs:SetAlpha(0)
    end

    for i = 1, table.getn(stock) do suppress(stock[i]) end

    -- Some unit-frame addons create their health number on GameTooltip itself
    -- rather than as a child of GameTooltipStatusBar. It therefore looks like a
    -- second value floating above our bar and evades the bar-anchored scan above.
    -- Find that duplicate by its *displayed value*, but never touch Blizzard's
    -- normal GameTooltipTextLeft/Right rows. This is deliberately narrow: only a
    -- non-line FontString whose text exactly equals the current health label is
    -- suppressed.
    local expected
    if bar.GetMinMaxValues and bar.GetValue then
        local _, maximum = bar:GetMinMaxValues()
        local current = bar:GetValue()
        if maximum and maximum > 0 then
            expected = healthTextLabel(self:Config().healthTextMode, current, maximum)
        end
    end
    expected = expected and trim(plain(expected)) or nil

    if expected and expected ~= "" and GameTooltip then
        local seenFrames = {}
        local function standardTooltipLine(fs)
            local n = fs and fs.GetName and fs:GetName() or nil
            if not n then return false end
            return string.find(n, "^GameTooltipTextLeft%d+$")
                    or string.find(n, "^GameTooltipTextRight%d+$")
        end
        local function scan(frame)
            if not frame or seenFrames[frame] then return end
            seenFrames[frame] = true
            if frame.GetRegions then
                local regions = { frame:GetRegions() }
                for i = 1, table.getn(regions) do
                    local region = regions[i]
                    if region and region.GetText and region.SetAlpha
                            and region ~= self.healthText and not standardTooltipLine(region) then
                        local text = trim(plain(region:GetText()))
                        if text == expected then suppress(region) end
                    end
                end
            end
            if frame.GetChildren then
                local children = { frame:GetChildren() }
                for i = 1, table.getn(children) do scan(children[i]) end
            end
        end
        scan(GameTooltip)
    end
end

function M:ApplyBarTextColor(fs)
    if not fs or not fs.SetTextColor then return end
    local color = self:Config().barTextColor or { 1.00, 0.82, 0.00, 1 }
    fs:SetTextColor(color[1] or 1, color[2] or 0.82, color[3] or 0,
            color[4] == nil and 1 or color[4])
end

function M:AnchorHealthBar(tip)
    local bar = GameTooltipStatusBar
    if not tip or not bar or not bar.ClearAllPoints or not bar.SetPoint then return end

    -- pfUI intentionally anchors GameTooltipStatusBar above GameTooltip. The
    -- tooltip frame itself is clamped to the screen, but a child hanging above it
    -- can still be outside the visible area. ECO therefore owns the bar anchor
    -- while enabled: above in the normal case, below when the above position
    -- would cross the physical top edge.
    local tipTop = tip.GetTop and tip:GetTop() or nil
    local uiTop = UIParent and UIParent.GetTop and UIParent:GetTop() or nil
    local tipScale = tip.GetEffectiveScale and tip:GetEffectiveScale() or 1
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local barScale = bar.GetEffectiveScale and bar:GetEffectiveScale() or tipScale
    local barHeight = bar.GetHeight and bar:GetHeight() or 12
    if not tipScale or tipScale == 0 then tipScale = 1 end
    if not uiScale or uiScale == 0 then uiScale = 1 end
    if not barScale or barScale == 0 then barScale = tipScale end

    local placeBelow = false
    if tipTop and uiTop then
        local proposedTopPx = (tipTop * tipScale) + ((barHeight + 4) * barScale)
        local screenTopPx = uiTop * uiScale
        placeBelow = proposedTopPx > (screenTopPx - 1)
    end

    bar:ClearAllPoints()
    if placeBelow then
        bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -2)
        bar:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", 0, -2)
    else
        bar:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, 2)
        bar:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 0, 2)
    end
    self.healthBarBelow = placeBelow
end

function M:StyleBarFont(bar)
    if not bar then return end
    local cfg = self:Config()
    local fontIndex = tonumber(cfg.barFont) or tonumber(cfg.font) or (OB.fontIndex["Roboto"] or 1)
    local fontPath = OB.fontPaths[fontIndex] or STANDARD_TEXT_FONT
    local size = tonumber(cfg.barFontSize) or tonumber(cfg.fontSize) or 12
    local flags = cfg.fontOutline and "OUTLINE" or nil

    -- The stock status text is anchored for Blizzard's fixed font and several
    -- 1.12/Turtle builds expose more than one FontString. Styling all of them is
    -- what caused text to appear above/outside the bar. ECO therefore owns one
    -- centred FontString and makes the stock copies transparent while enabled.
    self:SuppressForeignHealthText(bar)

    -- Bar height is user-controlled. Profiles created before this setting
    -- existed keep the previous automatic sizing behaviour as their fallback.
    if bar.SetHeight then
        local stockHeight = tonumber(self.originalBarHeight) or (bar.GetHeight and bar:GetHeight()) or 0
        local barHeight = tonumber(cfg.barHeight) or math.max(stockHeight, size + 4)
        bar:SetHeight(barHeight)
    end

    local fs = self:EnsureHealthText(bar)
    if fs then
        fs:SetFont(fontPath, size, flags)
        if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, flags) end
        fs:ClearAllPoints()
        -- Keep the text region tied to the bar edges so it automatically grows
        -- and shrinks with tooltip/pfUI re-anchoring. A fixed SetWidth here was
        -- the cause of values such as "3.11k / ..." despite ample bar space.
        fs:SetPoint("LEFT", bar, "LEFT", 3, 0)
        fs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
        if fs.SetJustifyH then fs:SetJustifyH("CENTER") end
        if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
        if fs.SetHeight and bar.GetHeight then fs:SetHeight(bar:GetHeight()) end
        self:ApplyBarTextColor(fs)
        fs:SetAlpha(1)
    end

    self:InstallHealthBarValueHook(bar)
end

function M:HealthBarColor(unit)
    if not unit then return nil end

    if self:IsUnitDead(unit) then
        return { DEAD_BAR_COLOR[1], DEAD_BAR_COLOR[2], DEAD_BAR_COLOR[3] }
    end

    if type(UnitIsPlayer) == "function" and UnitIsPlayer(unit) then
        local className, classToken
        if type(UnitClass) == "function" then className, classToken = UnitClass(unit) end
        if not classToken then classToken = OB.ClassToken(className) end
        local r, g, b = OB.ClassColor(classToken)
        return { r, g, b }
    end

    return self:ReactionColor(unit)
end

function M:SuppressForeignHealthChrome(bar)
    if not bar then return end

    -- pfUI does not skin GameTooltipStatusBar with the StatusBar's own backdrop.
    -- It creates child frames at bar.backdrop / backdrop_border / backdrop_shadow.
    -- ECO used to draw its own healthBorder on top of those, so the live bar had
    -- two border systems while the fade copy only had ECO's. Own the chrome here:
    -- hide those foreign layers and provide one ECO background + one ECO border.
    self.foreignHealthChromeState = self.foreignHealthChromeState or {}
    local frames = { bar.backdrop, bar.backdrop_border, bar.backdrop_shadow }
    for i = 1, table.getn(frames) do
        local frame = frames[i]
        if frame then
            if self.foreignHealthChromeState[frame] == nil then
                self.foreignHealthChromeState[frame] = frame.IsShown and frame:IsShown() and true or false
            end
            if frame.Hide then frame:Hide() end
        end
    end

    -- Clear a legacy/direct backdrop too. This catches other tooltip skins which
    -- use SetBackdrop on the StatusBar rather than pfUI's child-frame approach.
    if bar.SetBackdrop then bar:SetBackdrop(nil) end

    if not self.healthBackground then
        self.healthBackground = bar:CreateTexture(nil, "BACKGROUND")
        self.healthBackground:SetAllPoints(bar)
    end
    self.healthBackground:SetTexture(OB.TexturePath("tooltip"))
    self.healthBackground:SetVertexColor(HEALTH_BG_COLOR[1], HEALTH_BG_COLOR[2],
            HEALTH_BG_COLOR[3])
    if self.healthBackground.SetAlpha then self.healthBackground:SetAlpha(HEALTH_BG_COLOR[4]) end
    self.healthBackground:Show()
end

function M:StyleHealthBar(tip)
    local bar = GameTooltipStatusBar
    if not bar then return end

    local cfg = self:Config()
    if bar.SetStatusBarTexture then bar:SetStatusBarTexture(OB.TexturePath("tooltip")) end
    self:SuppressForeignHealthChrome(bar)

    -- GameTooltipStatusBar is a StatusBar, and on the 1.12 client drawing an edge
    -- directly on that frame is inconsistent: the status texture can cover part
    -- of it and some client builds simply ignore one side. A dedicated child
    -- frame one level above the bar owns the border instead. Because it is a child
    -- it follows the bar's position/visibility without another update loop.
    if not self.healthBorder then
        local border = CreateFrame("Frame", nil, bar)
        border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        if border.SetFrameLevel and bar.GetFrameLevel then
            border:SetFrameLevel(bar:GetFrameLevel() + 1)
        end
        self.healthBorder = border
    end

    local look = OB.Look("tooltip")
    local edge = OB.borderEdges[tonumber(look.border) or 1]
    if edge then
        self.healthBorder:SetBackdrop({
            edgeFile = edge.edgeFile,
            edgeSize = edge.edgeSize,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        self.healthBorder:SetBackdropColor(0, 0, 0, 0)
        self.healthBorder:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
        -- Snapshot code uses these exact live edge metrics and compensates for
        -- effective-scale differences between GameTooltipStatusBar and the copy.
        self.healthBorderEdgeFile = edge.edgeFile
        self.healthBorderEdgeSize = edge.edgeSize
        self.healthBorder:Show()
    else
        self.healthBorderEdgeFile = nil
        self.healthBorderEdgeSize = nil
        self.healthBorder:Hide()
    end

    local unit
    if tip and tip.GetUnit then
        local _, token = tip:GetUnit()
        if token and (type(UnitExists) ~= "function" or UnitExists(token)) then unit = token end
    end

    -- Some 1.12 clients expose GameTooltip:GetUnit but return nil for normal
    -- mouseover tooltips. Fall back only when the tooltip's first line actually
    -- matches the current mouseover unit, so an item tooltip cannot inherit it.
    if not unit and type(UnitExists) == "function" and UnitExists("mouseover")
            and type(UnitName) == "function" then
        local mouseName = UnitName("mouseover")
        local first = tooltipLine(tip, "Left", 1)
        local firstText = first and plain(first:GetText()) or nil
        if mouseName and firstText and firstText == mouseName then unit = "mouseover" end
    end

    if unit then
        self.healthUnit = unit
        self.healthName = type(UnitName) == "function" and UnitName(unit) or nil

        -- A world-unit tooltip must stay under ECO's watch for its entire live
        -- lifetime. Octo/1.12 can begin the native tooltip fade internally,
        -- before UPDATE_MOUSEOVER_UNIT or our FadeOut wrapper gets a chance to
        -- take control. Keeping the feature tickly while the mouseover tooltip
        -- is live lets OnUpdate see the mouseover token disappear first and
        -- start ECO's own delay/fade state machine proactively.
        self.liveUnitTooltip = true
        self.tickly = true
        local color = self:HealthBarColor(unit)
        if color then
            if bar.SetStatusBarColor_orig then
                bar:SetStatusBarColor_orig(color[1] or 1, color[2] or 1, color[3] or 1)
            elseif bar.SetStatusBarColor then
                bar:SetStatusBarColor(color[1] or 1, color[2] or 1, color[3] or 1)
            end
        end
        -- Bar font/height styling must be applied after the unit is known and
        -- before the border's next render.
        self:StyleBarFont(bar)
        self:UpdateHealthText(bar, unit)
        bar:Show()
        self:AnchorHealthBar(tip)
    else
        self.healthUnit = nil
        self.healthName = nil
        self.liveUnitTooltip = nil
        if self.healthText then self.healthText:Hide() end
        bar:Hide()
    end
end

function M:StyleTooltip(tip)
    if not tip then return end
    local cfg = self:Config()

    if tip.SetScale then tip:SetScale(tonumber(cfg.scale) or 1) end
    if tip.SetBackdrop then tip:SetBackdrop(self:TooltipBackdrop()) end

    if tip.SetBackdropColor then
        local bg = cfg.background or { 0, 0, 0, 0.85 }
        tip:SetBackdropColor(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.85)
    end
    if tip.SetBackdropBorderColor then tip:SetBackdropBorderColor(0.45, 0.45, 0.5, 1) end

    self:StyleText(tip)
    self:StyleHealthBar(tip)
end

function M:RestoreVisuals()
    if not GameTooltip or not self.visualsRemembered then return end

    if self.originalScale and GameTooltip.SetScale then GameTooltip:SetScale(self.originalScale) end
    if self.originalBackdrop and GameTooltip.SetBackdrop then GameTooltip:SetBackdrop(self.originalBackdrop) end

    for key, font in pairs(self.originalFonts or {}) do
        local _, _, side, index = string.find(key, "^(%a+)(%d+)$")
        local line = side and tooltipLine(GameTooltip, side, tonumber(index))
        if line and font[1] then line:SetFont(font[1], font[2], font[3]) end
    end

    local bar = GameTooltipStatusBar
    if bar then
        if self.originalBarHeight and bar.SetHeight then bar:SetHeight(self.originalBarHeight) end
        if self.originalBarTexture and bar.SetStatusBarTexture then
            bar:SetStatusBarTexture(self.originalBarTexture)
        end
        if self.originalBarColor then
            if bar.SetStatusBarColor_orig then
                bar:SetStatusBarColor_orig(self.originalBarColor[1], self.originalBarColor[2],
                        self.originalBarColor[3])
            elseif bar.SetStatusBarColor then
                bar:SetStatusBarColor(self.originalBarColor[1], self.originalBarColor[2],
                        self.originalBarColor[3])
            end
        end
        if self.originalBarPoints and bar.ClearAllPoints and bar.SetPoint then
            bar:ClearAllPoints()
            for i = 1, table.getn(self.originalBarPoints) do
                local a = self.originalBarPoints[i]
                bar:SetPoint(a[1], a[2], a[3], a[4] or 0, a[5] or 0)
            end
        end

        local unit
        if GameTooltip and GameTooltip.GetUnit then
            local _, token = GameTooltip:GetUnit()
            unit = token
        elseif type(UnitExists) == "function" and UnitExists("mouseover") then
            unit = "mouseover"
        end
        if unit and (type(UnitExists) ~= "function" or UnitExists(unit)) then
            bar:Show()
        else
            bar:Hide()
        end
    end

    if self.healthBorder then self.healthBorder:Hide() end
    if self.healthText then self.healthText:Hide() end
    if self.deadBarFill then self.deadBarFill:Hide() end
    if self.healthBackground then self.healthBackground:Hide() end

    if bar then
        if bar.SetBackdrop then bar:SetBackdrop(self.originalBarBackdrop) end
        if self.originalBarBackdropColor and bar.SetBackdropColor then
            bar:SetBackdropColor(unpack(self.originalBarBackdropColor))
        end
        if self.originalBarBackdropBorderColor and bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(unpack(self.originalBarBackdropBorderColor))
        end
    end
    for frame, wasShown in pairs(self.foreignHealthChromeState or {}) do
        if frame then
            if wasShown and frame.Show then frame:Show()
            elseif frame.Hide then frame:Hide() end
        end
    end

    self.healthUnit = nil
    self.healthName = nil
    self.healthIsDead = nil

    for fs, alpha in pairs(self.originalBarFontAlpha or {}) do
        if fs and fs.SetAlpha then fs:SetAlpha(alpha or 1) end
    end
end

-- ---------------------------------------------------------------------------
-- unit identity / colours
-- ---------------------------------------------------------------------------

local function rgbText(text, color)
    if text == nil then return "" end
    color = color or { 1, 1, 1 }
    return "|cff" .. hex(color[1] or 1, color[2] or 1, color[3] or 1)
            .. tostring(text) .. "|r"
end

local function whiteText(text)
    return rgbText(text, { 1, 1, 1 })
end

function M:TooltipUnit(tip)
    if not tip then return nil end

    -- World-player tooltips are frequently rewritten by pfUI/other tooltip mods
    -- before ECO's deferred decoration pass. Line one may therefore be
    -- "High Warlord Name", "Name [Rank]", or already contain ECO colour markup
    -- instead of being byte-for-byte equal to UnitName("mouseover"). On 1.12,
    -- GameTooltip:GetUnit() can simultaneously return nil. Treat the live
    -- mouseover token as authoritative when its name appears as a complete name
    -- inside the first tooltip line.
    if type(UnitExists) == "function" and UnitExists("mouseover")
            and type(UnitName) == "function" then
        local name = UnitName("mouseover")
        local first = tooltipLine(tip, "Left", 1)
        local firstText = first and plain(first:GetText()) or nil
        if name and firstText then
            if firstText == name then return name, "mouseover" end

            local pvpName = type(UnitPVPName) == "function" and UnitPVPName("mouseover") or nil
            if pvpName and pvpName ~= "" and firstText == pvpName then
                return name, "mouseover"
            end

            local a, b = string.find(firstText, name, 1, true)
            if a then
                local before = a > 1 and string.sub(firstText, a - 1, a - 1) or ""
                local after = b < string.len(firstText) and string.sub(firstText, b + 1, b + 1) or ""
                local beforeOK = a == 1 or before == " " or before == "[" or before == "(" or before == "<"
                local afterOK = b == string.len(firstText) or after == " " or after == "]" or after == ")" or after == ">"
                if beforeOK and afterOK then return name, "mouseover" end
            end
        end
    end

    if tip.GetUnit then
        local name, unit = tip:GetUnit()
        if name and name ~= "" and unit
                and (type(UnitExists) ~= "function" or UnitExists(unit)) then
            return name, unit
        end
    end

    return nil
end

function M:ReactionColor(unit)
    local cfg = self:Config()
    local reaction
    if type(UnitReaction) == "function" then reaction = UnitReaction(unit, "player") end

    if reaction then
        if reaction >= 5 then return cfg.friendlyTarget end
        if reaction == 4 then return cfg.neutralTarget end
        return cfg.hostileTarget
    end

    if type(UnitCanAttack) == "function" and UnitCanAttack("player", unit) then
        return cfg.hostileTarget
    end
    if type(UnitIsFriend) == "function" and UnitIsFriend("player", unit) then
        return cfg.friendlyTarget
    end
    return cfg.neutralTarget
end

function M:PVPRankName(unit)
    if type(UnitPVPRank) ~= "function" or type(GetPVPRankInfo) ~= "function" then return nil end
    local rank = UnitPVPRank(unit)
    if not rank or rank <= 0 then return nil end

    local ok, name = pcall(GetPVPRankInfo, rank, unit)
    if not ok or not name or name == "" then
        ok, name = pcall(GetPVPRankInfo, rank)
    end
    if ok and name and name ~= "" then
        -- Some 1.12 rank strings contain a trailing space (for example "Scout ").
        -- Strip only surrounding whitespace so the visible tag is [Scout], not
        -- [Scout ].  Internal punctuation/spacing such as Knight-Champion is kept.
        name = string.gsub(name, "^%s+", "")
        name = string.gsub(name, "%s+$", "")
        if name ~= "" then return name end
    end
    return nil
end

function M:LevelMarkup(level)
    local r, g, b
    if not level or level <= 0 then
        r, g, b = unpack(OB.levelColors.red or { 1, 0, 0 })
        return rgbText("??", { r, g, b })
    end
    r, g, b = OB.LevelColor(level)
    return rgbText(level, { r, g, b })
end

function M:ColorUnitInfo(tip)
    local name, unit = self:TooltipUnit(tip)
    if not name or not unit then return false end

    local first = tooltipLine(tip, "Left", 1)
    if first then
        local display = rgbText(name, self:ReactionColor(unit))
        if type(UnitIsPlayer) == "function" and UnitIsPlayer(unit) then
            local rank = self:PVPRankName(unit)
            if rank then
                -- PvP rank is intentionally subdued beside the reaction-coloured
                -- player name. #858585 keeps it readable without competing with
                -- the name/class colours.
                display = display .. " " .. "|cff858585[" .. rank .. "]|r"
            end
        end
        first:SetText(display)
        first:SetTextColor(1, 1, 1)
    end

    local level = type(UnitLevel) == "function" and UnitLevel(unit) or nil
    local levelMarkup = self:LevelMarkup(level)
    local player = type(UnitIsPlayer) == "function" and UnitIsPlayer(unit)
    local replacement

    if player then
        local race = type(UnitRace) == "function" and UnitRace(unit) or nil
        local className, classToken
        if type(UnitClass) == "function" then className, classToken = UnitClass(unit) end
        if not classToken then classToken = OB.ClassToken(className) end
        local cr, cg, cb = OB.ClassColor(classToken)
        local playerColor = self:Config().playerTarget or { 0, 0.65, 1, 1 }

        replacement = whiteText("Level") .. " " .. levelMarkup
        if race and race ~= "" then replacement = replacement .. " " .. whiteText(race) end
        if className and className ~= "" then
            replacement = replacement .. " " .. rgbText(className, { cr, cg, cb })
        end
        replacement = replacement .. " " .. rgbText("(Player)", playerColor)
    else
        local creatureType = type(UnitCreatureType) == "function" and UnitCreatureType(unit) or nil
        replacement = whiteText("Level") .. " " .. levelMarkup
        if creatureType and creatureType ~= "" then
            replacement = replacement .. " " .. whiteText(creatureType)
        end
    end

    -- Guild/faction text can move the level row down, so find the existing Level
    -- row rather than assuming it is line two. Only the numeric level gets the
    -- difficulty colour; all surrounding words are explicitly white.
    for i = 2, (tip:NumLines() or 0) do
        local line = tooltipLine(tip, "Left", i)
        local text = line and plain(line:GetText())
        if text and string.find(text, "^Level%s") then
            line:SetText(replacement)
            line:SetTextColor(1, 1, 1)
            return true
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- item database preview
-- ---------------------------------------------------------------------------

function M:TooltipUnitName(tip)
    return self:TooltipUnit(tip)
end

function M:TooltipNpcId(tip)
    if not tip or not tip.NumLines then return nil end

    -- pfQuest/pfUI extensions commonly print this exact line on creature
    -- tooltips. Prefer it over a name reverse lookup: it identifies the mob the
    -- player is actually hovering, even when several NPCs share a name.
    for i = 1, (tip:NumLines() or 0) do
        local line = tooltipLine(tip, "Left", i)
        local text = line and plain(line:GetText()) or nil
        if text then
            local _, _, id = string.find(text, "^NPC%s*ID%s*:%s*(%d+)")
            if not id then _, _, id = string.find(text, "^NPC%s*ID%s+(%d+)") end
            if id then return tonumber(id) end
        end
    end

    return nil
end

function M:DatabaseSource(tip)
    local db = OB.modules.itemdatabase
    if not db or not OB.ModuleEnabled("itemdatabase") then return nil end

    local npcId = self:TooltipNpcId(tip)
    local name, unit = self:TooltipUnitName(tip)

    -- The explicit NPC-ID row is stronger evidence than GetUnit on 1.12. Some
    -- clients/addon stacks cannot return a unit token here even though pfQuest
    -- has already identified the creature and printed its ID. In that case line
    -- one is safe to use as the display name because the NPC-ID row proves this
    -- is a creature tooltip rather than an item tooltip.
    if (not name or name == "") and npcId then
        local first = tooltipLine(tip, "Left", 1)
        name = first and plain(first:GetText()) or nil
    end
    if not name or name == "" then return nil end

    if unit and type(UnitExists) == "function" and not UnitExists(unit) then return nil end
    if unit and type(UnitPlayerControlled) == "function" and UnitPlayerControlled(unit) then
        return nil
    end

    if npcId and type(db.GetSourceByUnitId) == "function" then
        local source, state = db:GetSourceByUnitId(npcId, name)
        if source or state == "building" then return source, state end
    end

    return db:GetSourceByName(name)
end

function M:ApplyQuestIdVisibility(tip)
    if not tip or not tip.NumLines or not tip.GetName then return end

    local showIds = self:Config().showQuestIds and true or false
    local tipName = tip:GetName()
    if not tipName then return end

    for i = 1, (tip:NumLines() or 0) do
        local line = getglobal(tipName .. "TextLeft" .. i)
        if line and line.GetText and line.SetText then
            local current = line:GetText()
            if current and current ~= "" then
                -- If ECO already hid this line, inspect the stored original so
                -- the checkbox can restore it immediately without requiring a
                -- new mouseover.
                local source = current
                if line.eqEcoQuestIdOriginal and line.eqEcoQuestIdStripped
                        and current == line.eqEcoQuestIdStripped then
                    source = line.eqEcoQuestIdOriginal
                end

                local clean = plain(source)
                local questId = clean and string.match(clean, "%((%d+)%)%s*$") or nil
                local isQuestTitle = clean and string.find(clean, "^%[%d+%]") and questId

                if isQuestTitle then
                    -- Keep all colour markup intact: remove only the exact final
                    -- " (12345)" token from the raw FontString text.
                    local stripped = string.gsub(source,
                            "%s+%(" .. questId .. "%)", "", 1)

                    line.eqEcoQuestIdOriginal = source
                    line.eqEcoQuestIdStripped = stripped

                    local wanted = showIds and source or stripped
                    if current ~= wanted then line:SetText(wanted) end
                else
                    line.eqEcoQuestIdOriginal = nil
                    line.eqEcoQuestIdStripped = nil
                end
            end
        end
    end
end

local MAX_TOOLTIP_WIDTH = 420
local UNIT_TOOLTIP_HORIZONTAL_PAD = 16

function M:Resize(tip, added)
    if not tip or not tip.NumLines or not tip.GetName then return end
    local name = tip:GetName()
    if not name then return end

    -- Unit tooltips can arrive with different stock heights depending on how the
    -- unit was entered. A direct world-body mouseover may reserve extra blank
    -- rows that a name/nameplate mouseover does not. ECO rewrites the visible
    -- rows, so remember whether this is a live unit tooltip and allow only this
    -- class of tooltip to shrink back to its actual rendered content below.
    local _, resizeUnit = self:TooltipUnit(tip)
    local isUnitTooltip = resizeUnit ~= nil

    -- Blizzard sizes a tooltip before ECO changes its font and before ECO
    -- replaces unit lines. Measure rendered strings, but cap the frame and wrap
    -- anything longer than the cap so text can never paint outside the backdrop.
    local widest = 0
    local textHeight = 0
    local hasVisibleRight = false
    local innerMax = MAX_TOOLTIP_WIDTH - 24

    for i = 1, (tip:NumLines() or 0) do
        local left = getglobal(name .. "TextLeft" .. i)
        local right = getglobal(name .. "TextRight" .. i)

        -- A FontString containing only " " still reports the height of one full
        -- line on the 1.12 client. Several unit-tooltip paths use such spacer
        -- rows, which is why the body-hover tooltip could keep a large empty
        -- block even though there was no visible text there.
        local leftText = left and left.GetText and trim(plain(left:GetText())) or ""
        local rightText = right and right.GetText and trim(plain(right:GetText())) or ""

        -- Do not size the frame around hidden FontStrings. Several tooltip addons
        -- keep old rows populated but Hide() them, and GetStringWidth() still
        -- reports the hidden text. That was the remaining source of large empty
        -- space on the right of otherwise short player tooltips.
        local leftShown = left and (not left.IsVisible or left:IsVisible())
        local rightShown = right and (not right.IsVisible or right:IsVisible())
        local leftVisible = leftShown and leftText ~= ""
        local rightVisible = rightShown and rightText ~= ""
        if rightVisible then hasVisibleRight = true end

        local lw = 0
        if left and leftVisible then
            if left.GetStringWidth then lw = left:GetStringWidth() or 0
            elseif left.GetWidth then lw = left:GetWidth() or 0 end
        end
        local rw = 0
        if right and rightVisible then
            if right.GetStringWidth then rw = right:GetStringWidth() or 0
            elseif right.GetWidth then rw = right:GetWidth() or 0 end
        end

        -- Most unit/loot rows are left-only. Give two-column rows whatever is
        -- left after the right value, and let the FontString wrap vertically.
        local budget = innerMax
        if rw > 0 then budget = math.max(80, innerMax - rw - 12) end
        if left and leftVisible and lw > budget and left.SetWidth then
            left:SetWidth(budget)
            if left.SetNonSpaceWrap then left:SetNonSpaceWrap(true) end
            lw = budget
        end

        local width = lw
        if rw > 0 then width = width + rw + 12 end
        if width > innerMax then width = innerMax end
        if width > widest then widest = width end

        local lh = 0
        if left and leftVisible then
            if left.GetStringHeight then lh = left:GetStringHeight() or 0
            elseif left.GetHeight then lh = left:GetHeight() or 0 end
        end
        local rh = 0
        if right and rightVisible then
            if right.GetStringHeight then rh = right:GetStringHeight() or 0
            elseif right.GetHeight then rh = right:GetHeight() or 0 end
        end
        if rh > lh then lh = rh end
        if lh > 0 then textHeight = textHeight + lh + 2 end
    end

    if tip.SetWidth then
        local current = tip.GetWidth and tip:GetWidth() or 0
        local padding = isUnitTooltip and UNIT_TOOLTIP_HORIZONTAL_PAD or 24
        local wanted = math.min(widest + padding, MAX_TOOLTIP_WIDTH)
        if wanted < padding then wanted = padding end

        -- Unit tooltips have no artificial minimum width. They hug the widest
        -- *visible* line plus a small amount of backdrop padding, shrinking and
        -- growing whenever the content changes. The 420px value is only a
        -- maximum so a very long guild/challenge line cannot run off-screen.
        -- Generic item/spell/help tooltips remain conservative.
        if isUnitTooltip then
            if hasVisibleRight then
                -- Two-column tooltip rows are laid out by the 1.12 client when
                -- AddDoubleLine() is called. Shrinking the GameTooltip frame
                -- afterwards does not reliably reflow the already-positioned
                -- right FontString; pfQuest quest states such as "(Available)"
                -- can therefore remain at the old X coordinate outside ECO's
                -- newly-smaller backdrop. Preserve the width the live tooltip
                -- had immediately after all pre-existing OnShow handlers ran.
                -- If a right column appeared later, still allow measured content
                -- to grow the frame, but never shrink a genuine two-column row.
                local natural = tonumber(tip.eqEcoNaturalWidth) or 0
                if natural > wanted then wanted = math.min(natural, MAX_TOOLTIP_WIDTH) end
                if wanted > current + 0.5 then tip:SetWidth(wanted) end
            elseif math.abs(current - wanted) > 0.5 then
                tip:SetWidth(wanted)
            end
        elseif current > MAX_TOOLTIP_WIDTH then
            if math.abs(current - wanted) > 0.5 then tip:SetWidth(wanted) end
        elseif wanted > current then
            tip:SetWidth(wanted)
        end
    end

    -- Generic item/spell tooltips retain the conservative grow-only behaviour.
    -- Unit tooltips are different: the stock client/addons can leave them taller
    -- than the rows ECO ultimately displays, so set their measured height in
    -- both directions. This makes world-body and name/nameplate mouseovers use
    -- the same compact frame without changing item/ability layout.
    if tip.SetHeight then
        -- GameTooltipStatusBar is anchored outside the tooltip frame (above in
        -- the normal case, below only near the top screen edge). Counting its
        -- height here creates a fake empty block at the bottom of every unit
        -- tooltip, so size only around the actual tooltip rows.
        local wanted = textHeight + 20
        if wanted < 20 then wanted = 20 end
        local current = tip.GetHeight and tip:GetHeight() or 0
        if isUnitTooltip then
            if math.abs(current - wanted) > 0.5 then tip:SetHeight(wanted) end
        elseif wanted > current then
            tip:SetHeight(wanted)
        end
    end
end

function M:AddDatabaseLines(tip, source)
    local db = OB.modules.itemdatabase
    if not db or not source then return false end

    local cfg = self:Config()
    local dbcfg = db:Config()
    local sorted = db:SortedItems(source)
    local visible = {}
    local worldHidden = 0
    local qualityHidden = 0
    local questHidden = 0
    local minimumQuality = tonumber(cfg.minimumDropQuality) or 0

    for i = 1, table.getn(sorted) do
        local row = sorted[i]
        local hidden = false

        if cfg.hideWorldDrops and db:IsWorldDrop(row, dbcfg.worldDropCutoff) then
            worldHidden = worldHidden + 1
            hidden = true
        end

        if not hidden and cfg.hideQuestItems and db:IsQuestItem(row.id) then
            questHidden = questHidden + 1
            hidden = true
        end

        -- Keep an uncached item rather than guessing that it is low quality.
        -- This matches pfExtend's filter semantics: once GetItemInfo knows the
        -- quality it can be filtered, but an unknown quality never disappears
        -- merely because the client has not cached that item yet.
        if not hidden and minimumQuality > 0 then
            local _, _, quality = db:ItemInfo(row.id)
            if type(quality) == "number" and quality < minimumQuality then
                qualityHidden = qualityHidden + 1
                hidden = true
            end
        end

        if not hidden then table.insert(visible, row) end
    end

    local added = 0
    local total = table.getn(sorted)
    local eligible = table.getn(visible)

    local heading
    if source.instance then
        heading = "Drops: " .. eligible .. " / " .. total .. "  |cff777777" .. source.instance .. "|r"
    else
        heading = "Drops: " .. eligible .. " / " .. total
    end

    tip:AddLine(heading, 0.55, 0.75, 1)
    added = added + 1

    local limit = tonumber(cfg.itemDropLines) or 5
    local shown = math.min(limit, eligible)

    for i = 1, shown do
        local row = visible[i]
        local name, link = db:ItemInfo(row.id)
        local label = link or (name and ("[" .. name .. "]")) or ("Item " .. tostring(row.id))
        if row.quantityText then label = label .. " |cffbbbbbb" .. row.quantityText .. "|r" end

        local chance = tonumber(row.chance) or 0
        local chanceLabel = "?"
        local chanceHex = "aaaaaa"
        if chance > 0 then
            local r, g, b = chanceColor(chance)
            chanceHex = hex(r, g, b)
            chanceLabel = string.format("%.2f%%", chance)
        end

        tip:AddLine(label .. " |cff555555[|r|cff" .. chanceHex
                .. chanceLabel .. "|r|cff555555]|r", 1, 1, 1)
        added = added + 1
    end

    -- Omission summaries are useful while tuning filters, but they are visual
    -- noise during normal play. Keep them behind one explicit frame option.
    -- This includes the item-limit summary as well as world/quality/quest filters:
    -- all four describe items ECO deliberately did not print in the preview.
    if cfg.showHiddenItemText then
        local capped = eligible - shown
        if capped > 0 then
            tip:AddLine("... " .. capped .. " more drops in Item Database ...", 0.55, 0.55, 0.55)
            added = added + 1
        end

        if worldHidden > 0 then
            tip:AddLine("... " .. worldHidden .. " world drops hidden on tooltip ...",
                    0.55, 0.55, 0.55)
            added = added + 1
        end

        if qualityHidden > 0 then
            tip:AddLine("... " .. qualityHidden .. " drops below rarity filter ...",
                    0.55, 0.55, 0.55)
            added = added + 1
        end

        if questHidden > 0 then
            tip:AddLine("... " .. questHidden .. " quest items hidden from loot preview ...",
                    0.55, 0.55, 0.55)
            added = added + 1
        end
    end

    tip:AddLine("Ctrl+Alt: open full item database", 0.45, 0.7, 0.95)
    added = added + 1

    self:Resize(tip, added)
    self:StyleText(tip)
    return true
end

-- ---------------------------------------------------------------------------
-- item value presentation
-- ---------------------------------------------------------------------------

function M:TooltipItemIdentity(tip)
    if not tip or not tip.NumLines or (tip:NumLines() or 0) < 1 then return nil end
    local first = tooltipLine(tip, "Left", 1)
    local name = first and first.GetText and trim(plain(first:GetText())) or nil
    if not name or name == "" then return nil end

    local itemId, suffixId, link
    if type(GetItemInfo) == "function" then
        local _, itemLink = GetItemInfo(name)
        link = itemLink
    end

    if link then
        local _, _, id, suffix = string.find(link,
                "item:(%d+):%-?%d*:(%-?%d*)")
        itemId = tonumber(id)
        suffixId = tonumber(suffix) or 0
    end

    -- Item identity is a shared market concern, not an Aux concern. The current
    -- market service can ask Aux, and a future ECO Auction House database can
    -- become the provider without Tooltip changing again.
    local market = OB.Market
    if not itemId and market and type(market.ItemIdByName) == "function" then
        itemId = tonumber(market:ItemIdByName(name))
    end

    if not itemId then return nil end
    return itemId, suffixId or 0, name
end

function M:TooltipMoneyFrame(tip)
    if not tip or not tip.GetName then return nil end
    local name = tip:GetName()
    if not name then return nil end
    -- Stock 1.12 uses GameTooltipMoneyFrame. A few forks/addons use the numbered
    -- form, so recognise both without assuming which implementation won load order.
    return getglobal(name .. "MoneyFrame") or getglobal(name .. "MoneyFrame1")
end

function M:SuppressTooltipMoneyFrame(tip)
    if not tip or not tip.GetName then return end
    local name = tip:GetName()
    if not name then return end

    local frame = getglobal(name .. "MoneyFrame")
    if frame and frame.Hide then frame:Hide() end
    frame = getglobal(name .. "MoneyFrame1")
    if frame and frame.Hide then frame:Hide() end
end

function M:PriceSlots(tip)
    local slots, seen, parsed = {}, {}, {}
    local lines = tip and tip.NumLines and (tip:NumLines() or 0) or 0

    for i = 1, lines do
        local left = tooltipLine(tip, "Left", i)
        local text = left and left.GetText and left:GetText() or nil
        local kind = priceLineKind(text)
        if kind then
            table.insert(slots, i)
            seen[i] = true
            if kind ~= "unused" and not parsed[kind] then
                parsed[kind] = priceValueText(text)
            end
        end
    end

    -- SetTooltipMoney() in stock 1.12 creates a literal blank AddLine(" ") and
    -- anchors the icon money frame onto it. Reuse that exact row for our fourth
    -- text value instead of leaving a blank gap after hiding the coin frame.
    local money = self:TooltipMoneyFrame(tip)
    if money and money.IsShown and money:IsShown() then
        for i = lines, 1, -1 do
            if not seen[i] then
                local left = tooltipLine(tip, "Left", i)
                local text = left and left.GetText and left:GetText() or nil
                if text == " " or text == "" then
                    table.insert(slots, i)
                    seen[i] = true
                    break
                end
            end
        end
    end

    table.sort(slots)
    return slots, parsed
end

local function coinColor(hex, text)
    return "|cff" .. hex .. tostring(text) .. "|r"
end

local function priceMoney(value, style)
    value = tonumber(value)
    if not value then return nil end
    if value < 0 then value = 0 end
    value = math.floor(value + 0.5)

    local gold = math.floor(value / 10000)
    local silver = math.floor(mod(value, 10000) / 100)
    local copper = mod(value, 100)
    style = style or "denominations"

    if style == "values" then
        -- Compact ledger style: 1.02.03. Silver/copper are two digits whenever
        -- a higher denomination exists, so 1g 2s 3c cannot be mistaken for 1/2/3.
        if gold > 0 then
            return coinColor(MONEY_GOLD_HEX, gold)
                    .. "." .. coinColor(MONEY_SILVER_HEX, string.format("%02d", silver))
                    .. "." .. coinColor(MONEY_COPPER_HEX, string.format("%02d", copper))
        end
        if silver > 0 then
            return coinColor(MONEY_SILVER_HEX, silver)
                    .. "." .. coinColor(MONEY_COPPER_HEX, string.format("%02d", copper))
        end
        return coinColor(MONEY_COPPER_HEX, copper)
    end

    if style == "suffixes" then
        local out = {}
        if gold > 0 then
            table.insert(out, "|cffffffff" .. tostring(gold) .. "|r" .. coinColor(MONEY_GOLD_HEX, "g"))
        end
        if silver > 0 or gold > 0 then
            table.insert(out, "|cffffffff" .. tostring(silver) .. "|r" .. coinColor(MONEY_SILVER_HEX, "s"))
        end
        if copper > 0 or table.getn(out) == 0 then
            table.insert(out, "|cffffffff" .. tostring(copper) .. "|r" .. coinColor(MONEY_COPPER_HEX, "c"))
        end
        return table.concat(out, " ")
    end

    -- Default: colour the complete denomination, including both number and suffix.
    local out = {}
    if gold > 0 then table.insert(out, coinColor(MONEY_GOLD_HEX, tostring(gold) .. "g")) end
    if silver > 0 or gold > 0 then
        table.insert(out, coinColor(MONEY_SILVER_HEX, tostring(silver) .. "s"))
    end
    if copper > 0 or table.getn(out) == 0 then
        table.insert(out, coinColor(MONEY_COPPER_HEX, tostring(copper) .. "c"))
    end
    return table.concat(out, " ")
end

local function priceRow(label, value, vendor)
    -- Labels remain restrained; the denomination formatter owns the value colours.
    local labelHex = vendor and "d89b55" or "ffd86b"
    value = tostring(value or "")
    if not string.find(value, "|c", 1, true) then
        value = "|cffffffff" .. value .. "|r"
    end
    return "|cff" .. labelHex .. label .. ":|r " .. value
end

function M:RememberBagStack(tip, bag, slot)
    if not tip then return end

    local count = 1
    if type(GetContainerItemInfo) == "function" then
        local _, stackCount = GetContainerItemInfo(bag, slot)
        count = tonumber(stackCount) or 1
    end
    if count < 1 then count = 1 end

    tip.eqEcoBag = bag
    tip.eqEcoBagSlot = slot
    tip.eqEcoStackCount = count
end

function M:TooltipStackCount(tip, itemId)
    if not tip then return 1 end

    local bag = tip.eqEcoBag
    local slot = tip.eqEcoBagSlot
    if bag == nil or slot == nil then return 1 end

    -- Validate the remembered bag source against the item currently shown. The
    -- same GameTooltip frame is reused everywhere, so a stale stack from the last
    -- bag hover must never multiply a merchant/unit/other-item tooltip.
    if type(GetContainerItemLink) == "function" then
        local link = GetContainerItemLink(bag, slot)
        if link then
            local _, _, id = string.find(link, "item:(%d+)")
            if id and tonumber(id) ~= tonumber(itemId) then return 1 end
        end
    end

    local count = tonumber(tip.eqEcoStackCount) or 1
    if type(GetContainerItemInfo) == "function" then
        local _, liveCount = GetContainerItemInfo(bag, slot)
        count = tonumber(liveCount) or count
        tip.eqEcoStackCount = count
    end

    if count < 1 then count = 1 end
    return count
end

function M:PriceStackMultiplier(tip, itemId)
    if type(IsShiftKeyDown) ~= "function" or not IsShiftKeyDown() then return 1 end
    return self:TooltipStackCount(tip, itemId)
end

function M:NormalizeItemValues(tip)
    local cfg = self:Config()
    if not cfg.showItemValues then
        if tip then
            tip.eqEcoPriceActive = nil
            tip.eqEcoPriceKey = nil
        end
        return false
    end

    local itemId, suffixId, name = self:TooltipItemIdentity(tip)
    if not itemId then return false end

    local key = tostring(itemId) .. ":" .. tostring(suffixId or 0)
    local slots, parsed = self:PriceSlots(tip)

    -- All price discovery now goes through the shared market service. Tooltip
    -- owns only the three-line presentation below. Aux, ShaguTweaks and the future
    -- ECO Auction House are interchangeable providers behind this call.
    local prices = OB.Market and OB.Market:GetPrices(itemId, suffixId or 0) or nil
    local vendor = prices and prices.vendor or nil
    local auction = prices and prices.auction or nil
    local today = prices and prices.today or nil

    -- Prefer Aux's already-formatted visible values when present. This preserves
    -- useful suffixes such as Today's percentage-vs-history annotation and also
    -- supports older Aux builds that label the history row "Value:".
    local moneyFormat = cfg.moneyFormat or "denominations"
    local multiplier = self:PriceStackMultiplier(tip, itemId)
    local auctionText = priceMoney(auction and auction * multiplier, moneyFormat) or parsed.auction or "Unknown"
    local todayText = priceMoney(today and today * multiplier, moneyFormat) or parsed.today or "Unknown"
    local vendorText = priceMoney(vendor and vendor * multiplier, moneyFormat) or parsed.vendor or "Unknown"

    local rows = {
        priceRow("Auction", auctionText, false),
        priceRow("Today", todayText, false),
        priceRow("Vendor", vendorText, true),
    }

    -- Rewrite Aux's existing price rows (plus SetTooltipMoney's blank row) in
    -- place. This is what removes the visual conflict without modifying either
    -- external addon or leaving a duplicate price block underneath them.
    for i = 1, table.getn(rows) do
        local slot = slots[i]
        if slot then
            local left = tooltipLine(tip, "Left", slot)
            local right = tooltipLine(tip, "Right", slot)
            if left and left.SetText then
                left:SetText(rows[i])
                if left.SetTextColor then left:SetTextColor(1, 1, 1) end
                if left.Show then left:Show() end
            end
            if right and right.SetText then right:SetText("") end
        else
            self.addingPriceLines = true
            tip:AddLine(rows[i], 1, 1, 1, true)
            self.addingPriceLines = nil
        end
    end

    -- Aux/Shagu may expose extra source rows such as "Min +10%", Vendor Buy,
    -- or the old money-frame spacer. Collapse anything beyond ECO's three rows.
    -- Collapse any extras as far as the 1.12 FontString API allows.
    for i = table.getn(rows) + 1, table.getn(slots) do
        local left = tooltipLine(tip, "Left", slots[i])
        local right = tooltipLine(tip, "Right", slots[i])
        if left and left.SetText then left:SetText("") end
        if left and left.SetHeight then left:SetHeight(1) end
        if right and right.SetText then right:SetText("") end
        if right and right.SetHeight then right:SetHeight(1) end
    end

    self:SuppressTooltipMoneyFrame(tip)
    tip.eqEcoPriceActive = true
    tip.eqEcoPriceKey = key
    tip.eqEcoPriceShift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and true or false
    self:StyleText(tip)
    return true
end

-- ---------------------------------------------------------------------------
-- lifecycle and Ctrl+Alt browser shortcut
-- ---------------------------------------------------------------------------

function M:Decorate(tip)
    if not OB.ModuleEnabled("tooltip") then return true end
    if not tip or not tip.NumLines then return true end
    -- Fade delay keeps the live GameTooltip intact; decoration therefore remains
    -- attached to the one real tooltip throughout the hold and native fade.

    -- Do not call SetOwner here. Decorate runs just after GameTooltip:OnShow,
    -- and re-owning an already-visible 1.12 tooltip can make the client tear it
    -- down on its next tooltip update. Placement belongs in the default-anchor
    -- hook before the tooltip is populated; this pass only decorates the live frame.
    self:StyleTooltip(tip)
    self:ColorUnitInfo(tip)
    self:ApplyQuestIdVisibility(tip)
    self:NormalizeItemValues(tip)
    self:Resize(tip)

    local source, state = self:DatabaseSource(tip)

    if not source then
        if state == "building" then return false end
        return true
    end

    local key = source.key or source.name

    -- UPDATE_MOUSEOVER_UNIT and GameTooltip:OnShow can both schedule the same
    -- unit tooltip. Appending twice would duplicate every loot line. The marker
    -- lives on the actual tooltip frame so it survives duplicate queue requests,
    -- and is cleared when the client really changes/rebuilds the mouseover.
    if self:Config().showItemDrops and tip.eqEcoLootKey ~= key then
        self:AddDatabaseLines(tip, source)
        tip.eqEcoLootKey = key
    end
    return true
end

function M:QueueTooltip(resetDecoration)
    -- UPDATE_MOUSEOVER_UNIT can fire as the mouse leaves the unit which started
    -- a fade. That replay is already complete; queueing it again is what created
    -- duplicate "Drops:" sections during the delay/fade window.
    if self.fading then return end
    self.pendingTooltip = true
    self.pendingAt = GetTime()
    if resetDecoration and GameTooltip then GameTooltip.eqEcoLootKey = nil end
    self.tickly = true
end

function M:EnsureFadeTooltip()
    if self.fadeTooltip then return self.fadeTooltip end
    if type(CreateFrame) ~= "function" then return nil end

    local tip = CreateFrame("GameTooltip", "EquadisClassicOverhaulFadeTooltip",
            UIParent, "GameTooltipTemplate")
    if not tip then return nil end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:Hide()

    local bar = CreateFrame("StatusBar", nil, tip)
    bar:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, 2)
    bar:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 0, 2)
    if bar.SetStatusBarTexture then bar:SetStatusBarTexture(OB.TexturePath("tooltip")) end

    -- GameTooltipStatusBar has stock/background art in addition to its status
    -- texture. A bare StatusBar does not, so the old fade copy became transparent
    -- behind an empty bar. This texture is populated from the live bar each time
    -- a snapshot is taken, making the held/fading bar visually identical.
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:Hide()
    self.fadeBarBackground = background

    -- Mirrors the live dead-state fill. It is separate from the StatusBar value
    -- because a dead unit's value is zero and therefore has no visible fill area.
    local deadFill = bar:CreateTexture(nil, "ARTWORK")
    deadFill:SetAllPoints(bar)
    deadFill:SetTexture(OB.TexturePath("tooltip"))
    deadFill:SetVertexColor(DEAD_BAR_COLOR[1], DEAD_BAR_COLOR[2], DEAD_BAR_COLOR[3])
    deadFill:Hide()
    self.fadeDeadBarFill = deadFill

    bar:Hide()
    self.fadeBar = bar

    local border = CreateFrame("Frame", nil, bar)
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    if border.SetFrameLevel and bar.GetFrameLevel then
        border:SetFrameLevel(bar:GetFrameLevel() + 1)
    end
    self.fadeBarBorder = border

    local fs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", bar, "LEFT", 3, 0)
    fs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    if fs.SetJustifyH then fs:SetJustifyH("CENTER") end
    if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
    self.fadeHealthText = fs

    self.fadeTooltip = tip
    return tip
end

function M:SnapshotForFade(source, keepHidden)
    local copy = self:EnsureFadeTooltip()
    if not copy or not source or not source.NumLines then return false end

    copy:Hide()
    copy:ClearLines()
    copy:SetOwner(UIParent, "ANCHOR_NONE")
    copy:SetAlpha(1)

    local cfg = self:Config()
    if copy.SetScale then copy:SetScale(tonumber(cfg.scale) or 1) end
    if copy.SetBackdrop then copy:SetBackdrop(self:TooltipBackdrop()) end
    if copy.SetBackdropColor then
        local bg = cfg.background or { 0, 0, 0, 0.85 }
        copy:SetBackdropColor(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.85)
    end
    if copy.SetBackdropBorderColor then copy:SetBackdropBorderColor(0.45, 0.45, 0.5, 1) end

    local lines = source:NumLines() or 0
    if lines < 1 then return false end

    -- Capture the live frame dimensions before rebuilding the display-only copy.
    -- The copy is deliberately locked back to these exact dimensions after its
    -- lines are created so OnLeave cannot make the tooltip jump in width/height.
    local sourceWidth = source.GetWidth and source:GetWidth() or nil
    local sourceHeight = source.GetHeight and source:GetHeight() or nil

    for i = 1, lines do
        local left = tooltipLine(source, "Left", i)
        local right = tooltipLine(source, "Right", i)
        local lt = left and left.GetText and left:GetText() or nil
        local rt = right and right.GetText and right:GetText() or nil

        -- A hidden FontString can still retain old text on 1.12. The live tooltip
        -- correctly ignores those rows, but the old fade copy read GetText() and
        -- recreated them as visible rows -- the source of stray "Rank 1" /
        -- "10 yd range" text after mouse leave. Snapshot only what is actually
        -- visible on the live frame.
        local leftShown = left and (not left.IsVisible or left:IsVisible())
        local rightShown = right and (not right.IsVisible or right:IsVisible())
        local hasLeft = leftShown and lt and lt ~= ""
        local hasRight = rightShown and rt and rt ~= ""

        if hasLeft or hasRight then
            local lr, lg, lb = 1, 1, 1
            local rr, rg, rb = 1, 1, 1
            if left and left.GetTextColor then lr, lg, lb = left:GetTextColor() end
            if right and right.GetTextColor then rr, rg, rb = right:GetTextColor() end
            if hasRight then
                copy:AddDoubleLine(hasLeft and lt or "", rt, lr or 1, lg or 1, lb or 1,
                        rr or 1, rg or 1, rb or 1)
            else
                copy:AddLine(lt, lr or 1, lg or 1, lb or 1, true)
            end
        end
    end

    self:StyleText(copy)
    if sourceWidth and sourceWidth > 0 and copy.SetWidth then copy:SetWidth(sourceWidth) end
    if sourceHeight and sourceHeight > 0 and copy.SetHeight then copy:SetHeight(sourceHeight) end

    local point, relative, relativePoint, px, py
    if source.GetPoint then point, relative, relativePoint, px, py = source:GetPoint(1) end
    copy:ClearAllPoints()
    if point then
        copy:SetPoint(point, relative or UIParent, relativePoint or point, px or 0, py or 0)
    else
        copy:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Copy ECO's health bar separately. The stock GameTooltipStatusBar belongs to
    -- the live tooltip and must never be re-shown merely to animate a fade.
    local liveBar = GameTooltipStatusBar
    local showBar = self.healthUnit and liveBar
    if showBar then
        local min, max = 0, 1
        if liveBar.GetMinMaxValues then min, max = liveBar:GetMinMaxValues() end
        local value = liveBar.GetValue and liveBar:GetValue() or min
        self.fadeBar:SetMinMaxValues(min or 0, max or 1)
        self.fadeBar:SetValue(value or 0)
        if liveBar.GetStatusBarColor and self.fadeBar.SetStatusBarColor then
            local r, g, b = liveBar:GetStatusBarColor()
            self.fadeBar:SetStatusBarColor(r or 1, g or 0, b or 0)
        end
        if liveBar.GetAlpha and self.fadeBar.SetAlpha then
            self.fadeBar:SetAlpha(liveBar:GetAlpha() or 1)
        end

        -- ECO owns the live health-bar chrome, so the fade copy must not inherit
        -- or reconstruct any third-party StatusBar backdrop. Both sides use the
        -- same single dark background texture and the same ECO border below.
        if self.fadeBar.SetBackdrop then self.fadeBar:SetBackdrop(nil) end

        local fadeBackground = self.fadeBarBackground
        if fadeBackground then
            fadeBackground:SetTexture(OB.TexturePath("tooltip"))
            fadeBackground:SetVertexColor(HEALTH_BG_COLOR[1], HEALTH_BG_COLOR[2],
                    HEALTH_BG_COLOR[3])
            if fadeBackground.SetAlpha then fadeBackground:SetAlpha(HEALTH_BG_COLOR[4]) end
            fadeBackground:Show()
        end
        local h = liveBar.GetHeight and liveBar:GetHeight() or 12
        self.fadeBar:SetHeight(h or 12)
        self.fadeBar:ClearAllPoints()
        if self.healthBarBelow then
            self.fadeBar:SetPoint("TOPLEFT", copy, "BOTTOMLEFT", 0, -2)
            self.fadeBar:SetPoint("TOPRIGHT", copy, "BOTTOMRIGHT", 0, -2)
        else
            self.fadeBar:SetPoint("BOTTOMLEFT", copy, "TOPLEFT", 0, 2)
            self.fadeBar:SetPoint("BOTTOMRIGHT", copy, "TOPRIGHT", 0, 2)
        end

        -- Match the live border in physical pixels, not just nominal UI units.
        -- GameTooltipStatusBar can inherit a different effective scale from pfUI
        -- than the display-only GameTooltip copy. Reusing edgeSize=8 at a smaller
        -- scale is why the old fade border looked visibly thinner.
        local look = OB.Look("tooltip")
        local edge = OB.borderEdges[tonumber(look.border) or 1]
        if edge and self.healthBorder and self.healthBorder.IsShown
                and self.healthBorder:IsShown() then
            local liveScale = self.healthBorder.GetEffectiveScale
                    and self.healthBorder:GetEffectiveScale() or 1
            local fadeScale = self.fadeBarBorder.GetEffectiveScale
                    and self.fadeBarBorder:GetEffectiveScale() or 1
            if not liveScale or liveScale <= 0 then liveScale = 1 end
            if not fadeScale or fadeScale <= 0 then fadeScale = 1 end
            local ratio = liveScale / fadeScale
            local pad = 2 * ratio
            local edgeSize = (tonumber(self.healthBorderEdgeSize) or tonumber(edge.edgeSize) or 8) * ratio

            self.fadeBarBorder:ClearAllPoints()
            self.fadeBarBorder:SetPoint("TOPLEFT", self.fadeBar, "TOPLEFT", -pad, pad)
            self.fadeBarBorder:SetPoint("BOTTOMRIGHT", self.fadeBar, "BOTTOMRIGHT", pad, -pad)
            self.fadeBarBorder:SetBackdrop({
                edgeFile = self.healthBorderEdgeFile or edge.edgeFile,
                edgeSize = edgeSize,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            self.fadeBarBorder:SetBackdropColor(0, 0, 0, 0)
            if self.healthBorder.GetBackdropBorderColor then
                local r, g, b, a = self.healthBorder:GetBackdropBorderColor()
                self.fadeBarBorder:SetBackdropBorderColor(r or 0.45, g or 0.45,
                        b or 0.5, a == nil and 1 or a)
            else
                self.fadeBarBorder:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
            end
            self.fadeBarBorder:Show()
        else
            self.fadeBarBorder:Hide()
        end

        if self.fadeDeadBarFill then
            if self.healthIsDead then
                self.fadeDeadBarFill:SetTexture(OB.TexturePath("tooltip"))
                self.fadeDeadBarFill:SetVertexColor(DEAD_BAR_COLOR[1], DEAD_BAR_COLOR[2], DEAD_BAR_COLOR[3])
                self.fadeDeadBarFill:Show()
            else
                self.fadeDeadBarFill:Hide()
            end
        end

        local fontIndex = tonumber(cfg.barFont) or tonumber(cfg.font) or (OB.fontIndex["Roboto"] or 1)
        local fontPath = OB.fontPaths[fontIndex] or STANDARD_TEXT_FONT
        local size = tonumber(cfg.barFontSize) or tonumber(cfg.fontSize) or 12
        local flags = cfg.fontOutline and "OUTLINE" or nil
        self.fadeHealthText:SetFont(fontPath, size, flags)
        if not self.fadeHealthText:GetFont() then
            self.fadeHealthText:SetFont(STANDARD_TEXT_FONT, size, flags)
        end
        local text = self.healthText and self.healthText.GetText and self.healthText:GetText() or ""
        self.fadeHealthText:SetText(text or "")
        self:ApplyBarTextColor(self.fadeHealthText)
        if text and text ~= "" then self.fadeHealthText:Show() else self.fadeHealthText:Hide() end
        self.fadeBar:Show()
    else
        self.fadeBar:Hide()
        if self.fadeBarBackground then self.fadeBarBackground:Hide() end
        if self.fadeDeadBarFill then self.fadeDeadBarFill:Hide() end
        self.fadeBarBorder:Hide()
        self.fadeHealthText:Hide()
    end

    if keepHidden then
        copy:Hide()
    else
        copy:Show()
    end

    -- GameTooltipTemplate may run one final auto-size pass when it is shown.
    -- Reassert the live dimensions afterwards so the held/fading tooltip is
    -- pixel-for-pixel the same frame size as the tooltip the player just left.
    if sourceWidth and sourceWidth > 0 and copy.SetWidth then copy:SetWidth(sourceWidth) end
    if sourceHeight and sourceHeight > 0 and copy.SetHeight then copy:SetHeight(sourceHeight) end
    return true
end

-- Cache the finished visual tooltip *before* its owner gets a chance to call
-- GameTooltip:Hide(). Action buttons, buffs and several UI/unit frames tear the
-- live tooltip down immediately on OnLeave, which makes OnHide too late to copy
-- it reliably on this 1.12 client. The cache is display-only and is refreshed
-- while GameTooltip is still visible.
function M:CacheVisibleFadeSnapshot(tip, force)
    if not OB.ModuleEnabled("tooltip") then return false end
    if not self:Config().enableFade then
        self.fadeCacheValid = nil
        return false
    end
    if self.fading or not tip or not tip.IsShown or not tip:IsShown() then return false end
    if not tip.NumLines or (tip:NumLines() or 0) < 1 then return false end

    local now = GetTime()
    if not force and self.fadeCacheAt and now - self.fadeCacheAt < 0.05 then
        return self.fadeCacheValid and true or false
    end

    local ok = self:SnapshotForFade(tip, true)
    self.fadeCacheValid = ok and true or nil
    self.fadeCacheAt = now
    return ok and true or false
end

function M:StartCachedFade()
    if not self.fadeCacheValid or not self.fadeTooltip then return false end
    if not self:Config().enableFade then
        self.fadeCacheValid = nil
        return false
    end

    self.pendingTooltip = nil
    self.pendingAt = nil
    self.liveUnitTooltip = nil
    self.fading = true
    self.fadeStarted = GetTime()
    self.fadeTip = nil
    self.fadeCacheValid = nil
    self.tickly = true
    self.fadeTooltip:SetAlpha(1)
    self.fadeTooltip:Show()
    return true
end

function M:CancelFade()
    -- The fade copy is display-only. Cancelling it must never touch or rebuild the
    -- live GameTooltip; a new tooltip can therefore replace it cleanly.
    self.fading = nil
    self.fadeStarted = nil
    self.fadeTip = nil
    self.fadeCacheValid = nil
    self.fadeCacheAt = nil
    if self.fadeTooltip then
        self.fadeTooltip:SetAlpha(1)
        self.fadeTooltip:Hide()
    end
end

function M:BeginFade(tip)
    if not OB.ModuleEnabled("tooltip") then return false end
    if not tip or not tip.IsShown or not tip:IsShown() then return false end

    self.pendingTooltip = nil
    self.pendingAt = nil
    self.liveUnitTooltip = nil

    local cfg = self:Config()
    if not cfg.enableFade then
        -- Fade disabled means exactly that: hide the live tooltip now.
        self:CancelFade()
        self.hidingLiveTooltip = true
        if tip.SetAlpha then tip:SetAlpha(1) end
        if tip.Hide then tip:Hide() end
        self.hidingLiveTooltip = nil
        return true
    end

    if self.fading then return true end

    -- World/unit FadeOut requests arrive while GameTooltip is still alive, so
    -- take a fresh snapshot here. Direct-Hide UI owners use the pre-cached copy
    -- instead and never depend on reconstructing a hidden GameTooltip.
    if tip.SetAlpha then tip:SetAlpha(1) end
    self.fadeCacheValid = nil
    local snapped = self:SnapshotForFade(tip, false)
    if not snapped then
        self.hidingLiveTooltip = true
        if tip.Hide then tip:Hide() end
        self.hidingLiveTooltip = nil
        return true
    end

    self.fading = true
    self.fadeStarted = GetTime()
    self.fadeTip = nil
    self.tickly = true

    -- From this point onward only the display-only copy is visible.
    self.hidingLiveTooltip = true
    if tip.Hide then tip:Hide() end
    self.hidingLiveTooltip = nil

    if self.fadeTooltip then
        self.fadeTooltip:SetAlpha(1)
        self.fadeTooltip:Show()
    end
    return true
end

function M:InterceptNativeFade(tip)
    if self.fading then return true end
    if not tip or not tip.IsShown or not tip:IsShown() then return false end
    return self:BeginFade(tip)
end

function M:FinishFade()
    self.fading = nil
    self.fadeStarted = nil
    self.fadeTip = nil
    self.fadeCacheValid = nil
    self.fadeCacheAt = nil
    if self.fadeTooltip then
        self.fadeTooltip:SetAlpha(1)
        self.fadeTooltip:Hide()
    end
end

function M:InstallTooltip()
    if not GameTooltip or not GameTooltip.GetScript or not GameTooltip.SetScript then
        return false
    end

    self:RememberVisuals()

    local currentShow = GameTooltip:GetScript("OnShow")
    local currentHide = GameTooltip:GetScript("OnHide")
    local currentUpdate = GameTooltip:GetScript("OnUpdate")
    local currentFadeOut = GameTooltip.FadeOut
    local currentSetBagItem = GameTooltip.SetBagItem

    -- Capture the exact stack belonging to the bag slot that populated this
    -- tooltip. Pricing stays per-item by default; Shift can then turn it into the
    -- total value of this one visible stack without scanning every bag.
    if type(currentSetBagItem) == "function"
            and (not self.bagItemWrapper or currentSetBagItem ~= self.bagItemWrapper) then
        local previousSetBagItem = currentSetBagItem
        local wrapper
        wrapper = function(tip, bag, slot)
            local a, b, c, d, e = previousSetBagItem(tip, bag, slot)
            local m = EquadisClassicOverhaul.modules.tooltip
            if m then m:RememberBagStack(tip, bag, slot) end
            return a, b, c, d, e
        end
        self.previousSetBagItem = previousSetBagItem
        self.bagItemWrapper = wrapper
        GameTooltip.SetBagItem = wrapper
    end

    if not self.showWrapper or currentShow ~= self.showWrapper then
        local previousShow = currentShow
        local wrapper
        wrapper = function()
            local m = EquadisClassicOverhaul.modules.tooltip
            if previousShow then previousShow() end
            if m and EquadisClassicOverhaul.ModuleEnabled("tooltip") then
                m:CancelFade()
                m.fadeCacheValid = nil
                m.fadeCacheAt = nil
                if GameTooltip then
                    -- Capture the fully-built width before ECO's own decoration
                    -- or autosizing changes it. previousShow above includes the
                    -- client and tooltip addons that add genuine two-column rows.
                    local naturalWidth = GameTooltip.GetWidth and GameTooltip:GetWidth() or nil
                    GameTooltip.eqEcoNaturalWidth = naturalWidth and naturalWidth > 0
                            and naturalWidth or nil
                    GameTooltip.eqEcoPriceActive = nil
                    GameTooltip.eqEcoPriceKey = nil
                    GameTooltip.eqEcoPriceShift = nil
                    GameTooltip.eqEcoBag = nil
                    GameTooltip.eqEcoBagSlot = nil
                    GameTooltip.eqEcoStackCount = nil
                end
                if GameTooltip and GameTooltip.SetAlpha then GameTooltip:SetAlpha(1) end
                -- OnShow is shared by unit, item and UI tooltips. Do not let the
                -- previous unit's monitor survive into a newly-built tooltip;
                -- StyleHealthBar will re-arm it a moment later if this new
                -- tooltip really belongs to a unit.
                m.liveUnitTooltip = nil
                m:QueueTooltip(false)
            end
        end
        self.showWrapper = wrapper
        GameTooltip:SetScript("OnShow", wrapper)
    end

    -- Vanilla 1.12 unit frames call GameTooltip:FadeOut() on mouse leave. ECO
    -- intercepts that request before the live frame can enter its internal fade,
    -- snapshots the finished tooltip, and hides the real GameTooltip immediately.
    if currentFadeOut and (not self.fadeOutWrapper or currentFadeOut ~= self.fadeOutWrapper) then
        local previousFadeOut = currentFadeOut
        if not self.originalFadeOut then self.originalFadeOut = previousFadeOut end
        local fadeWrapper
        fadeWrapper = function(tip)
            local m = EquadisClassicOverhaul.modules.tooltip
            if m and EquadisClassicOverhaul.ModuleEnabled("tooltip") then
                if m:InterceptNativeFade(tip or GameTooltip) then return end
            end
            return previousFadeOut(tip)
        end
        self.fadeOutWrapper = fadeWrapper
        self.previousFadeOut = previousFadeOut
        GameTooltip.FadeOut = fadeWrapper
    end

    if not self.hideWrapper or currentHide ~= self.hideWrapper then
        local previousHide = currentHide
        local wrapper
        wrapper = function()
            local m = EquadisClassicOverhaul.modules.tooltip
            if m then
                m.pendingTooltip = nil
                m.pendingAt = nil
            end

            -- Direct-Hide owners (action buttons, buffs, many UI frames) have
            -- already torn the live GameTooltip down by the time OnHide runs. Do
            -- not try to reconstruct it here. If the visible-tooltip cache was
            -- populated beforehand, simply reveal that already-finished copy and
            -- run the normal hold + fade lifecycle.
            if m and EquadisClassicOverhaul.ModuleEnabled("tooltip")
                    and not m.hidingLiveTooltip and not m.fading
                    and m:Config().enableFade then
                m:StartCachedFade()
            end

            if previousHide then previousHide() end

            if GameTooltip then
                GameTooltip.eqEcoLootKey = nil
                GameTooltip.eqEcoPriceActive = nil
                GameTooltip.eqEcoPriceKey = nil
                GameTooltip.eqEcoPriceShift = nil
                GameTooltip.eqEcoBag = nil
                GameTooltip.eqEcoBagSlot = nil
                GameTooltip.eqEcoStackCount = nil
                GameTooltip.eqEcoNaturalWidth = nil
            end
            -- The display-only copy owns any active fade; normal hides simply end
            -- the live frame. Never clear tickly while a snapshot is running.
            if m and not m.fading then m.tickly = false end
        end
        self.hideWrapper = wrapper
        GameTooltip:SetScript("OnHide", wrapper)
    end

    -- Cursor anchoring must run after any existing GameTooltip OnUpdate (DFRL
    -- included), otherwise another addon can overwrite our point immediately.
    -- Wrapping rather than replacing preserves the other addon's behaviour.
    if not self.updateWrapper or currentUpdate ~= self.updateWrapper then
        local previousUpdate = currentUpdate
        local wrapper
        wrapper = function()
            if previousUpdate then previousUpdate() end
            local m = EquadisClassicOverhaul.modules.tooltip
            if m and EquadisClassicOverhaul.ModuleEnabled("tooltip")
                    and GameTooltip:IsShown() then
                -- pfUI and other tooltip mods may rewrite player name/level/class
                -- text after ECO's deferred Decorate pass. Reassert the unit
                -- colours after their OnUpdate so the final visible frame always
                -- keeps ECO's difficulty/class colours.
                if type(UnitExists) == "function" and UnitExists("mouseover") then
                    m:ColorUnitInfo(GameTooltip)

                    -- Other tooltip addons can append/change player rows from
                    -- their own OnUpdate (PvP, challenges, notes, etc.). Resize
                    -- after their handler has run so those late rows are included
                    -- in both width and height. SetWidth/SetHeight only fire when
                    -- the measured dimensions actually differ, so the steady-state
                    -- path does not continuously mutate the frame.
                    m:Resize(GameTooltip)
                end

                -- Reassert suppression after other tooltip addons have had their
                -- OnUpdate. This catches health text/chrome that pfUI or another
                -- tooltip skin restores on its own update pass.
                m:SuppressForeignHealthText(GameTooltipStatusBar)
                m:SuppressForeignHealthChrome(GameTooltipStatusBar)

                -- ShaguTweaks can re-show its coin MoneyFrame after ECO's deferred
                -- decoration. Once ECO owns this item's value block, keep that
                -- duplicate presentation hidden on the final visible frame.
                if GameTooltip.eqEcoPriceActive then
                    m:SuppressTooltipMoneyFrame(GameTooltip)

                    -- Modifier state changes do not rebuild a 1.12 tooltip. Detect
                    -- Shift here so the same visible tooltip switches immediately
                    -- between one-item value and this stack's total value.
                    local shifted = type(IsShiftKeyDown) == "function"
                            and IsShiftKeyDown() and true or false
                    if shifted ~= GameTooltip.eqEcoPriceShift then
                        m:NormalizeItemValues(GameTooltip)
                        m:Resize(GameTooltip)
                    end
                end

                if m:Config().atMouse then
                    m:UpdateCursorPosition(GameTooltip)
                else
                    m:AnchorHealthBar(GameTooltip)
                end

                -- Pre-cache the fully rendered tooltip while it is still alive.
                -- This is the reliable fade source for UI owners that call Hide()
                -- directly on mouse leave instead of requesting FadeOut().
                m:CacheVisibleFadeSnapshot(GameTooltip, false)
            end
        end
        self.updateWrapper = wrapper
        GameTooltip:SetScript("OnUpdate", wrapper)
    end

    self.tooltipInstalled = true
    return true
end

function M:OnEvent()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Reassert against addons that replaced tooltip hooks later in startup.
        self:InstallAnchor()
        self:InstallTooltip()
        self:StyleAllFontStrings()
        if GameTooltip then self:StyleTooltip(GameTooltip) end
        return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
        local hasMouseover = type(UnitExists) == "function" and UnitExists("mouseover")
        if hasMouseover then
            -- A new unit always owns the screen; remove an old snapshot before
            -- Blizzard builds/decorates the new tooltip.
            if self.fading then self:FinishFade() end
            self:QueueTooltip(true)
        else
            -- World mouseovers notify us here before/while the client requests
            -- FadeOut. Snapshot now so the requested delay is independent of the
            -- live GameTooltip's internal fade state.
            if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()
                    and self.healthUnit then
                local first = tooltipLine(GameTooltip, "Left", 1)
                local firstText = first and first.GetText and plain(first:GetText()) or nil
                -- Do not hide a UI/item tooltip which happened to replace the
                -- world-unit tooltip in the same frame as mouseover became nil.
                if not self.healthName or firstText == self.healthName then
                    self:BeginFade(GameTooltip)
                end
            end
        end
    end
end

function M:OnUpdate(now)
    -- Primary world-tooltip fade trigger. As soon as the mouseover token is lost,
    -- snapshot the completed tooltip and hide the real GameTooltip before the
    -- client can begin its own fade. The copy owns hold + fade from here.
    if self.liveUnitTooltip and not self.fading
            and self.healthUnit == "mouseover"
            and GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()
            and type(UnitExists) == "function" and not UnitExists("mouseover") then
        self:BeginFade(GameTooltip)
    end

    -- DFRL can replace GameTooltip's OnUpdate when its own cursor-tooltip option
    -- is toggled. Re-wrap lazily so ECO's cursor offsets remain authoritative.
    if GameTooltip and GameTooltip.GetScript
            and ((GameTooltip:GetScript("OnUpdate") ~= self.updateWrapper)
                or (self.fadeOutWrapper and GameTooltip.FadeOut ~= self.fadeOutWrapper)) then
        self:InstallTooltip()
    end

    if self.fading then
        local cfg = self:Config()

        -- A cursor-anchored tooltip should keep following the cursor even after
        -- the real GameTooltip has been replaced by the display-only fade copy.
        if cfg.atMouse then self:UpdateFadeCursorPosition() end

        if not cfg.enableFade then
            -- Live setting: disabling fade during the hold/fade removes the copy
            -- immediately; the real tooltip is already hidden.
            self:FinishFade()
        else
            local delay = tonumber(cfg.fadeDelay) or 0.35
            if delay < 0 then delay = 0 end
            local elapsed = now - (self.fadeStarted or now)

            if elapsed < delay then
                -- Fade Delay is ONLY the fully-opaque hold time.
                if self.fadeTooltip and self.fadeTooltip.SetAlpha then
                    self.fadeTooltip:SetAlpha(1)
                end
            else
                -- Preserve the established visual fade speed. This is the same
                -- 0.35-second transition ECO used when the fade itself was working
                -- correctly; only the start time is configurable.
                local fadeElapsed = elapsed - delay
                if fadeElapsed >= FADE_SPEED then
                    self:FinishFade()
                elseif self.fadeTooltip and self.fadeTooltip.SetAlpha then
                    self.fadeTooltip:SetAlpha(1 - (fadeElapsed / FADE_SPEED))
                end
            end
        end
    end

    if self.pendingTooltip then
        if self.pendingAt and now - self.pendingAt < 0.01 then return end

        if not GameTooltip or not GameTooltip.IsShown or not GameTooltip:IsShown() then
            self.pendingTooltip = nil
            self.pendingAt = nil
        else
            local finished = self:Decorate(GameTooltip)
            if finished then
                self.pendingTooltip = nil
                self.pendingAt = nil
                self:CacheVisibleFadeSnapshot(GameTooltip, true)
            end
        end
    end

    -- Keep the single ECO OnUpdate alive while a world-unit tooltip is live so
    -- the proactive mouseover-loss check above cannot be skipped.
    if not self.pendingTooltip and not self.fading and not self.liveUnitTooltip then
        self.tickly = false
    end
end

function M:OnBind()
    self:InstallAnchor()
    self:InstallTooltip()
    self:RememberVisuals()
    self:StyleAllFontStrings()
    self:StyleTooltip(GameTooltip)
end

function M:OnUnbind()
    self.pendingTooltip = nil
    self.pendingAt = nil
    self.liveUnitTooltip = nil
    self.fadeCacheValid = nil
    self.fadeCacheAt = nil
    self:FinishFade()
    if GameTooltip then
        GameTooltip.eqEcoLootKey = nil
        GameTooltip.eqEcoPriceActive = nil
        GameTooltip.eqEcoPriceKey = nil
        GameTooltip.eqEcoPriceShift = nil
        GameTooltip.eqEcoBag = nil
        GameTooltip.eqEcoBagSlot = nil
        GameTooltip.eqEcoStackCount = nil
        if GameTooltip.SetAlpha then GameTooltip:SetAlpha(1) end
        if self.fadeOutWrapper and GameTooltip.FadeOut == self.fadeOutWrapper
                and self.originalFadeOut then
            GameTooltip.FadeOut = self.originalFadeOut
        end
        if self.bagItemWrapper and GameTooltip.SetBagItem == self.bagItemWrapper
                and self.previousSetBagItem then
            GameTooltip.SetBagItem = self.previousSetBagItem
        end
    end
    self.tickly = false
    self:RestoreVisuals()
end

function M:OnStyle()
    self:StyleAllFontStrings()

    -- Boolean settings are live. Turning fade off removes the display-only copy
    -- immediately; no reload is required.
    if not self:Config().enableFade and self.fading then
        self:FinishFade()
    end

    -- Switching to cursor anchoring makes the fixed-position drag preview
    -- irrelevant. Close it immediately instead of leaving a frame on screen
    -- that can no longer affect the active tooltip position.
    if self:Config().atMouse and self.moveMode then
        self.moveMode = false
        if self.movePreview then self.movePreview:Hide() end
        if type(OB.RefreshPanel) == "function" then OB.RefreshPanel() end
    end

    if GameTooltip then
        self:StyleTooltip(GameTooltip)
        self:ApplyQuestIdVisibility(GameTooltip)
        self:Resize(GameTooltip)
        -- Position settings are ordinary live settings. Re-place a currently
        -- visible tooltip as well as updating the next tooltip that opens.
        if GameTooltip.IsShown and GameTooltip:IsShown() then
            self:PlaceTooltip(GameTooltip, UIParent)
            self:AnchorHealthBar(GameTooltip)
        end
    end
    if self.movePreview and self.movePreview.IsShown and self.movePreview:IsShown() then
        self:StyleMovePreview()
    end

    -- Do not re-run loot decoration on a tooltip that is already visible. The
    -- extra drop lines are appended to Blizzard's unit tooltip, so decorating
    -- the same live frame twice would duplicate them. Presentation changes land
    -- immediately; sorting/filter/content changes land on the next mouseover,
    -- when Blizzard has rebuilt the base tooltip from scratch.
end

function M:OnDraw() end
