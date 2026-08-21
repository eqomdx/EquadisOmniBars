--[[ Equadis' Classic Overhaul :: Dragonflight-inspired action-bar chrome

  First visual pass for the DragonflightUI-Reforged migration.  The existing
  actionbars.lua remains the layout/binding engine.  This file only paints the
  bottom action-button families and the ECO containers behind them.

  No Dragonflight/Blizzard-derived texture files are copied.  The look is built
  from flat client textures so it stays redistributable with ECO.
]]--

local OB = EquadisClassicOverhaul
local M = OB.modules and OB.modules.actionbars
if not M then return end

-- Defaults are added after actionbars.lua registered but before VARIABLES_LOADED
-- merges the saved profile, so old profiles pick them up automatically.
OB.defaults.modules.actionbars.chromeEnabled = true
OB.defaults.modules.actionbars.chromePanels = true
OB.defaults.modules.actionbars.chromePanelAlpha = 0.78
OB.defaults.modules.actionbars.chromeBorderColor = { 0.18, 0.18, 0.20, 1 }
OB.defaults.modules.actionbars.chromeHoverColor = { 1.00, 0.72, 0.18, 0.32 }

local BOTTOM_FAMILIES = {
    { prefix = "ActionButton", count = 12 },
    { prefix = "BonusActionButton", count = 12 },
    { prefix = "MultiBarBottomLeftButton", count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "ShapeshiftButton", count = 10 },
}

local BOTTOM_ANCHORS = { "Main", "Bonus", "BottomLeft", "BottomRight", "Pet", "Stance" }

local function solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    return t
end

local function setColor(texture, c)
    if not texture or not c then return end
    texture:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
end

local function makeLines(parent, layer)
    local lines = {
        top = solid(parent, layer, 0, 0, 0, 1),
        bottom = solid(parent, layer, 0, 0, 0, 1),
        left = solid(parent, layer, 0, 0, 0, 1),
        right = solid(parent, layer, 0, 0, 0, 1),
    }

    lines.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    lines.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    lines.top:SetHeight(1)

    lines.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    lines.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    lines.bottom:SetHeight(1)

    lines.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    lines.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    lines.left:SetWidth(1)

    lines.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    lines.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    lines.right:SetWidth(1)

    return lines
end

local function colorLines(lines, color)
    if not lines then return end
    setColor(lines.top, color)
    setColor(lines.bottom, color)
    setColor(lines.left, color)
    setColor(lines.right, color)
end

function M:ChromeButton(button)
    if not button then return end

    if not button.ecoChrome then
        local chrome = {}
        chrome.bg = solid(button, "BACKGROUND", 0.035, 0.035, 0.045, 0.94)
        chrome.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        chrome.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

        chrome.lines = makeLines(button, "OVERLAY")

        chrome.hover = solid(button, "OVERLAY", 1, 0.72, 0.18, 0.32)
        chrome.hover:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        chrome.hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        chrome.hover:Hide()

        local oldEnter = button:GetScript("OnEnter")
        local oldLeave = button:GetScript("OnLeave")

        button:SetScript("OnEnter", function()
            if oldEnter then oldEnter() end
            if this.ecoChrome and this.ecoChrome.enabled then
                this.ecoChrome.hover:Show()
            end
        end)

        button:SetScript("OnLeave", function()
            if oldLeave then oldLeave() end
            if this.ecoChrome then this.ecoChrome.hover:Hide() end
        end)

        local normal = button.GetNormalTexture and button:GetNormalTexture()
        if normal and normal.GetAlpha then chrome.normalAlpha = normal:GetAlpha() end
        chrome.normal = normal

        button.ecoChrome = chrome
    end

    local cfg = self:Config()
    local chrome = button.ecoChrome
    chrome.enabled = cfg.chromeEnabled and true or false

    if not chrome.enabled then
        chrome.bg:Hide()
        chrome.hover:Hide()
        chrome.lines.top:Hide(); chrome.lines.bottom:Hide()
        chrome.lines.left:Hide(); chrome.lines.right:Hide()
        if chrome.normal and chrome.normal.SetAlpha then
            chrome.normal:SetAlpha(chrome.normalAlpha or 1)
        end
        return
    end

    chrome.bg:Show()
    chrome.lines.top:Show(); chrome.lines.bottom:Show()
    chrome.lines.left:Show(); chrome.lines.right:Show()
    colorLines(chrome.lines, cfg.chromeBorderColor)
    setColor(chrome.hover, cfg.chromeHoverColor)

    if chrome.normal and chrome.normal.SetAlpha then chrome.normal:SetAlpha(0) end

    local icon = getglobal(button:GetName() .. "Icon")
    if icon and icon.SetTexCoord then icon:SetTexCoord(0.06, 0.94, 0.06, 0.94) end
end

function M:ChromeAnchor(anchor)
    if not anchor then return end

    if not anchor.ecoChromePanel then
        local panel = {}
        panel.bg = solid(anchor, "BACKGROUND", 0.025, 0.025, 0.035, 0.78)
        panel.bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
        panel.bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)

        -- Border lines live on an extra frame because the anchor itself changes
        -- size whenever the user changes rows/columns.
        panel.edge = CreateFrame("Frame", nil, anchor)
        panel.edge:SetFrameLevel(anchor:GetFrameLevel() + 1)
        panel.edge:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
        panel.edge:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
        panel.lines = makeLines(panel.edge, "OVERLAY")

        anchor.ecoChromePanel = panel
    end

    local cfg = self:Config()
    local panel = anchor.ecoChromePanel

    if cfg.chromeEnabled and cfg.chromePanels then
        panel.bg:SetVertexColor(0.025, 0.025, 0.035, cfg.chromePanelAlpha or 0.78)
        colorLines(panel.lines, cfg.chromeBorderColor)
        panel.bg:Show()
        panel.edge:Show()
    else
        panel.bg:Hide()
        panel.edge:Hide()
    end
end

function M:ApplyChrome()
    local cfg = self:Config()

    for f = 1, table.getn(BOTTOM_FAMILIES) do
        local family = BOTTOM_FAMILIES[f]
        for i = 1, family.count do
            self:ChromeButton(getglobal(family.prefix .. i))
        end
    end

    if self.anchors then
        for i = 1, table.getn(BOTTOM_ANCHORS) do
            self:ChromeAnchor(self.anchors[BOTTOM_ANCHORS[i]])
        end
    end
end

-- Keep the visual pass on the same lifecycle as the existing layout engine.
if not M.ecoChromeWrapped then
    M.ecoChromeWrapped = true
    local oldApply = M.Apply

    M.Apply = function(self)
        oldApply(self)
        self:ApplyChrome()
    end
end

-- New settings live as another section on the existing Action Bars page.
table.insert(M.options, { "Dragonflight Style", "__s_chrome", "section", "chrome" })
table.insert(M.options, { "Use Dragonflight-Style Buttons", "chromeEnabled", "boolean" })
table.insert(M.options, { "Draw Backing Panels", "chromePanels", "boolean",
                          nil, nil, "!chromeEnabled" })
table.insert(M.options, { "Panel Opacity", "chromePanelAlpha", "slider", 10, 100, 5, 0.01,
                          nil, "!chromeEnabled" })
table.insert(M.options, { "Button / Panel Border", "chromeBorderColor", "color", true,
                          nil, nil, nil, nil, "!chromeEnabled" })
table.insert(M.options, { "Mouseover Highlight", "chromeHoverColor", "color", true,
                          nil, nil, nil, nil, "!chromeEnabled" })
