--[[ Equadis' Classic Overhaul :: Buff Frames

  A deliberately small replacement for the player's top-right aura layout.
  DragonflightUI-Reforged proves the client's aura region can be moved directly;
  VCB proves the useful controls are row count, growth direction and spacing.
  This first ECO version owns only those essentials and does not depend on either
  addon at runtime.
]]--

local OB = EquadisClassicOverhaul
local floor = math.floor
local ceil = math.ceil

local function Say(msg) OB.Print(msg, "Buff Frames") end

local M = OB.RegisterModule({
    id = "buffframes",
    name = "Buff Frames",
    feature = true,
    renders = "none",
    defaultEnabled = false,
    tickly = true,

    defaults = {
        buffSize = 30,
        buffPerRow = 8,
        buffMax = 24,
        buffSpacingX = 4,
        buffSpacingY = 12,
        buffGrowX = "left",
        buffGrowY = "down",

        debuffSize = 30,
        debuffPerRow = 8,
        debuffMax = 16,
        debuffSpacingX = 4,
        debuffSpacingY = 12,
        debuffGrowX = "left",
        debuffGrowY = "down",

        showDuration = true,
        durationSize = 10,
        countSize = 12,

        positions = {},
    },

    options = {
        { "Buffs", "__s_buffs", "section", "buffs" },
        { "Icon Size", "buffSize", "slider", 18, 48, 1 },
        { "Buffs Per Row", "buffPerRow", "slider", 1, 16, 1 },
        { "Maximum Buffs", "buffMax", "slider", 1, 32, 1 },
        { "Horizontal Spacing", "buffSpacingX", "slider", 0, 20, 1 },
        { "Vertical Spacing", "buffSpacingY", "slider", 0, 24, 1 },
        { "Grow Horizontally", "buffGrowX", OB.Enum(
            { "left", "right" }, { "Left", "Right" }) },
        { "Grow Vertically", "buffGrowY", OB.Enum(
            { "down", "up" }, { "Down", "Up" }) },

        { "Debuffs", "__s_debuffs", "section", "debuffs" },
        { "Icon Size", "debuffSize", "slider", 18, 48, 1 },
        { "Debuffs Per Row", "debuffPerRow", "slider", 1, 16, 1 },
        { "Maximum Debuffs", "debuffMax", "slider", 1, 16, 1 },
        { "Horizontal Spacing", "debuffSpacingX", "slider", 0, 20, 1 },
        { "Vertical Spacing", "debuffSpacingY", "slider", 0, 24, 1 },
        { "Grow Horizontally", "debuffGrowX", OB.Enum(
            { "left", "right" }, { "Left", "Right" }) },
        { "Grow Vertically", "debuffGrowY", OB.Enum(
            { "down", "up" }, { "Down", "Up" }) },

        { "Text", "__s_text", "section", "text" },
        { "Show Duration", "showDuration", "boolean" },
        { "Duration Size", "durationSize", "slider", 6, 18, 1,
          nil, nil, "!showDuration" },
        { "Stack Count Size", "countSize", "slider", 8, 20, 1 },

        { "Position", "__s_position", "section", "position" },
        { "Move Buff / Debuff Frames", "__a_move", "action",
          function() OB.modules.buffframes:SetDragMode(
              not OB.modules.buffframes:DragMode()) end,
          function()
              if OB.modules.buffframes:DragMode() then return "Done Moving" end
              return "Move Buff / Debuff Frames"
          end },
        { "Put Them Back", "__a_reset", "action",
          function() OB.modules.buffframes:ResetPositions() end },
    },

    events = { "PLAYER_ENTERING_WORLD", "PLAYER_AURAS_CHANGED" },
})

local AURA_COLORS = {
    Magic   = { 0.25, 0.55, 1.00, 1 },
    Curse   = { 0.72, 0.32, 0.92, 1 },
    Disease = { 0.75, 0.60, 0.18, 1 },
    Poison  = { 0.25, 0.82, 0.28, 1 },
}
local NORMAL_BORDER = { 0.12, 0.12, 0.14, 1 }

function M:Config()
    return OB.profile.modules.buffframes
end

local function solid(parent, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    return t
end

local function lineBorder(parent)
    local b = {}
    b.top = solid(parent, "OVERLAY")
    b.bottom = solid(parent, "OVERLAY")
    b.left = solid(parent, "OVERLAY")
    b.right = solid(parent, "OVERLAY")

    b.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    b.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    b.top:SetHeight(1)
    b.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    b.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    b.bottom:SetHeight(1)
    b.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    b.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    b.left:SetWidth(1)
    b.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    b.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    b.right:SetWidth(1)

    return b
end

local function borderColor(border, color)
    local r, g, b, a = color[1], color[2], color[3], color[4] or 1
    border.top:SetVertexColor(r, g, b, a)
    border.bottom:SetVertexColor(r, g, b, a)
    border.left:SetVertexColor(r, g, b, a)
    border.right:SetVertexColor(r, g, b, a)
end

local function formatTime(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds >= 3600 then return floor(seconds / 3600 + 0.5) .. "h" end
    if seconds >= 60 then return floor(seconds / 60 + 0.5) .. "m" end
    if seconds >= 10 then return floor(seconds + 0.5) .. "" end
    return string.format("%.1f", seconds)
end

function M:CreateAnchor(name, defaultPoint, x, y)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(260)
    f:SetHeight(90)
    f:SetPoint(defaultPoint, UIParent, defaultPoint, x, y)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)

    f.hint = solid(f, "BACKGROUND")
    f.hint:SetAllPoints(f)
    f.hint:SetVertexColor(0.10, 0.60, 1.00, 0.20)
    f.hint:Hide()

    return f
end

function M:EnsureFrames()
    if self.buffAnchor then return end

    self.buffAnchor = self:CreateAnchor("EquadisOverhaulBuffAnchor", "TOPRIGHT", -24, -24)
    self.debuffAnchor = self:CreateAnchor("EquadisOverhaulDebuffAnchor", "TOPRIGHT", -24, -116)
    self.frames = { self.buffAnchor, self.debuffAnchor }

    self.buffButtons = {}
    self.debuffButtons = {}

    for i = 1, 32 do
        self.buffButtons[i] = self:CreateAuraButton(
            "EquadisOverhaulBuff" .. i, self.buffAnchor, "HELPFUL")
    end

    for i = 1, 16 do
        self.debuffButtons[i] = self:CreateAuraButton(
            "EquadisOverhaulDebuff" .. i, self.debuffAnchor, "HARMFUL")
    end
end

function M:CreateAuraButton(name, parent, filter)
    local b = CreateFrame("Button", name, parent)
    b.filter = filter
    b:SetWidth(30)
    b:SetHeight(30)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    b.border = lineBorder(b)
    borderColor(b.border, NORMAL_BORDER)

    b.count = OB.NewText(b, "OVERLAY", "GameFontHighlight")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.count:SetJustifyH("RIGHT")

    b.duration = OB.NewText(b, "OVERLAY", "GameFontHighlight")
    b.duration:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.duration:SetJustifyH("CENTER")

    b:SetScript("OnEnter", function()
        if this.buffIndex and GameTooltip and GameTooltip.SetPlayerBuff then
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetPlayerBuff(this.buffIndex)
        end
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    b:Hide()
    return b
end

function M:ApplyPosition(frame, key, point, x, y)
    local saved = self:Config().positions and self:Config().positions[key]
    frame:ClearAllPoints()
    if saved then
        frame:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
    else
        frame:SetPoint(point, UIParent, point, x, y)
    end
end

function M:StorePosition(key, frame)
    if not frame:GetLeft() then return end
    local cfg = self:Config()
    cfg.positions = cfg.positions or {}
    cfg.positions[key] = {
        x = (frame:GetLeft() + frame:GetWidth() / 2) - GetScreenWidth() / 2,
        y = (frame:GetBottom() + frame:GetHeight() / 2) - GetScreenHeight() / 2,
    }
end

function M:DragMode()
    return self.dragging and true or false
end

function M:SetDragMode(on)
    self:EnsureFrames()
    self.dragging = on and true or nil

    local pair = {
        { self.buffAnchor, "buffs" },
        { self.debuffAnchor, "debuffs" },
    }

    for i = 1, 2 do
        local frame, key = pair[i][1], pair[i][2]
        frame.ecoMoveKey = key
        frame:EnableMouse(self.dragging and true or false)
        frame:SetMovable(self.dragging and true or false)
        if self.dragging then
            frame:RegisterForDrag("LeftButton")
            frame.hint:Show()
            frame:SetScript("OnDragStart", function() this:StartMoving() end)
            frame:SetScript("OnDragStop", function()
                this:StopMovingOrSizing()
                OB.modules.buffframes:StorePosition(this.ecoMoveKey, this)
            end)
        else
            frame.hint:Hide()
        end
    end

    Say(self.dragging and "move mode on." or "move mode off.")
end

function M:ResetPositions()
    self:Config().positions = {}
    self:EnsureFrames()
    self:ApplyPosition(self.buffAnchor, "buffs", "TOPRIGHT", -24, -24)
    self:ApplyPosition(self.debuffAnchor, "debuffs", "TOPRIGHT", -24, -116)
    Say("buff and debuff positions reset.")
end

function M:Layout(list, anchor, size, perRow, maxShown, spacingX, spacingY, growX, growY)
    local xdir = growX == "right" and 1 or -1
    local ydir = growY == "up" and 1 or -1
    local stepX = size + spacingX
    local stepY = size + spacingY

    local columns = perRow
    if maxShown < columns then columns = maxShown end
    local rows = ceil(maxShown / perRow)
    anchor:SetWidth((columns * stepX) - spacingX)
    anchor:SetHeight((rows * stepY) - spacingY)

    local origin = xdir > 0 and "TOPLEFT" or "TOPRIGHT"
    local verticalOrigin = ydir > 0 and "BOTTOM" or "TOP"
    if verticalOrigin == "BOTTOM" then origin = xdir > 0 and "BOTTOMLEFT" or "BOTTOMRIGHT" end

    for i = 1, table.getn(list) do
        local b = list[i]
        b:SetWidth(size)
        b:SetHeight(size)
        b:ClearAllPoints()

        local zero = i - 1
        local col = mod(zero, perRow)
        local row = floor(zero / perRow)
        b:SetPoint(origin, anchor, origin, xdir * col * stepX, ydir * row * stepY)
    end
end

function M:UpdateAuraList(list, filter, maxShown)
    local cfg = self:Config()

    for i = 1, table.getn(list) do
        local b = list[i]
        if i > maxShown then
            b.buffIndex = nil
            b:Hide()
        else
            local buffIndex = GetPlayerBuff(i - 1, filter)
            if buffIndex and buffIndex >= 0 then
                b.buffIndex = buffIndex
                b.icon:SetTexture(GetPlayerBuffTexture(buffIndex))

                local count = GetPlayerBuffApplications(buffIndex) or 0
                if count > 1 then b.count:SetText(count) else b.count:SetText("") end

                local color = NORMAL_BORDER
                if filter == "HARMFUL" and type(GetPlayerBuffDispelType) == "function" then
                    local dtype = GetPlayerBuffDispelType(buffIndex)
                    color = AURA_COLORS[dtype] or NORMAL_BORDER
                end
                borderColor(b.border, color)

                OB.ApplyFont(b.count, cfg.countSize)
                OB.ApplyFont(b.duration, cfg.durationSize)
                b:Show()
            else
                b.buffIndex = nil
                b:Hide()
            end
        end
    end
end

function M:HideBlizzard()
    if BuffFrame and BuffFrame.Hide then BuffFrame:Hide() end
end

function M:RestoreBlizzard()
    if BuffFrame and BuffFrame.Show then BuffFrame:Show() end
end

function M:ApplyLayout()
    self:EnsureFrames()
    local cfg = self:Config()

    self:ApplyPosition(self.buffAnchor, "buffs", "TOPRIGHT", -24, -24)
    self:ApplyPosition(self.debuffAnchor, "debuffs", "TOPRIGHT", -24, -116)

    self:Layout(self.buffButtons, self.buffAnchor, cfg.buffSize, cfg.buffPerRow,
        cfg.buffMax, cfg.buffSpacingX, cfg.buffSpacingY, cfg.buffGrowX, cfg.buffGrowY)
    self:Layout(self.debuffButtons, self.debuffAnchor, cfg.debuffSize, cfg.debuffPerRow,
        cfg.debuffMax, cfg.debuffSpacingX, cfg.debuffSpacingY, cfg.debuffGrowX, cfg.debuffGrowY)
end

function M:OnBind()
    self:EnsureFrames()
    self:ApplyLayout()
    OB.SetDirty(self)
end

function M:OnUnbind()
    self.dragging = nil
    if self.buffAnchor then self.buffAnchor:Hide() end
    if self.debuffAnchor then self.debuffAnchor:Hide() end
    self:RestoreBlizzard()
end

function M:OnEvent()
    OB.SetDirty(self)
end

function M:OnStyle()
    if not OB.ModuleShown("buffframes") then
        self:RestoreBlizzard()
        return
    end
    self:ApplyLayout()
    OB.SetDirty(self)
end

function M:OnDraw()
    if not OB.ModuleShown("buffframes") then return end
    self:EnsureFrames()
    self:HideBlizzard()

    self.buffAnchor:Show()
    self.debuffAnchor:Show()

    local cfg = self:Config()
    self:UpdateAuraList(self.buffButtons, "HELPFUL", cfg.buffMax)
    self:UpdateAuraList(self.debuffButtons, "HARMFUL", cfg.debuffMax)
end

function M:OnUpdate(now)
    if not OB.ModuleShown("buffframes") then
        self:RestoreBlizzard()
        return
    end

    self:HideBlizzard()
    if not self.buffButtons then return end

    if self.lastDuration and now - self.lastDuration < 0.15 then return end
    self.lastDuration = now

    local cfg = self:Config()
    local lists = { self.buffButtons, self.debuffButtons }
    for l = 1, 2 do
        for i = 1, table.getn(lists[l]) do
            local b = lists[l][i]
            if b:IsShown() and b.buffIndex then
                if cfg.showDuration then
                    b.duration:SetText(formatTime(GetPlayerBuffTimeLeft(b.buffIndex)))
                else
                    b.duration:SetText("")
                end
            end
        end
    end
end
