--[[ Equadis' Classic Overhaul :: Party Frames

  First utility pass layered on top of Blizzard's party frames (and compatible
  with ECO's Unit Frames styling).  It owns group scale/layout, resource-bar
  visibility, party debuff placement and an obvious dispel/decurse cue.
]]--

local OB = EquadisClassicOverhaul
local function Say(msg) OB.Print(msg, "Party Frames") end

local M = OB.RegisterModule({
    id = "partyframes",
    name = "Party Frames",
    feature = true,
    renders = "none",
    defaultEnabled = false,

    defaults = {
        scale = 1.10,
        spacing = 4,
        grow = "down",
        showResource = true,
        resourceHeight = 7,

        maxDebuffs = 4,
        debuffSize = 16,
        debuffSpacing = 2,
        highlightDispellable = true,
        highlightThickness = 2,

        position = nil,
    },

    options = {
        { "Size And Layout", "__s_layout", "section", "layout" },
        { "Party Frame Scale", "scale", "slider", 70, 180, 5, 0.01 },
        { "Space Between Members", "spacing", "slider", 0, 24, 1 },
        { "Grow", "grow", OB.Enum({ "down", "up" }, { "Down", "Up" }) },
        { "Move Party Frames", "__a_move", "action",
          function() OB.modules.partyframes:SetDragMode(
              not OB.modules.partyframes:DragMode()) end,
          function()
              if OB.modules.partyframes:DragMode() then return "Done Moving" end
              return "Move Party Frames"
          end },
        { "Put Them Back", "__a_reset", "action",
          function() OB.modules.partyframes:ResetPosition() end },

        { "Resource", "__s_resource", "section", "resource" },
        { "Show Mana / Energy / Rage", "showResource", "boolean" },
        { "Resource Bar Height", "resourceHeight", "slider", 2, 14, 1,
          nil, nil, "!showResource" },

        { "Debuffs And Dispels", "__s_debuffs", "section", "debuffs" },
        { "Debuffs Shown", "maxDebuffs", "slider", 1, 4, 1 },
        { "Debuff Icon Size", "debuffSize", "slider", 10, 28, 1 },
        { "Debuff Spacing", "debuffSpacing", "slider", 0, 12, 1 },
        { "Highlight What I Can Remove", "highlightDispellable", "boolean" },
        { "Highlight Thickness", "highlightThickness", "slider", 1, 5, 1,
          nil, nil, "!highlightDispellable" },
    },

    events = {
        "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "UNIT_AURA",
        "UNIT_MANA", "UNIT_MAXMANA", "UNIT_ENERGY", "UNIT_RAGE", "UNIT_FOCUS",
        "UNIT_DISPLAYPOWER", "LEARNED_SPELL_IN_TAB",
    },
})

local TYPE_COLORS = {
    Magic   = { 0.20, 0.55, 1.00, 1 },
    Curse   = { 0.72, 0.28, 0.92, 1 },
    Disease = { 0.80, 0.62, 0.18, 1 },
    Poison  = { 0.25, 0.85, 0.25, 1 },
}

-- Exact spell names keep the first version honest: a type is advertised only
-- once a spell that removes it is actually in the character's spellbook.
local DISPEL_SPELLS = {
    ["Remove Lesser Curse"] = { Curse = true },
    ["Remove Curse"] = { Curse = true },
    ["Cure Poison"] = { Poison = true },
    ["Abolish Poison"] = { Poison = true },
    ["Cure Disease"] = { Disease = true },
    ["Abolish Disease"] = { Disease = true },
    ["Dispel Magic"] = { Magic = true },
    ["Purify"] = { Poison = true, Disease = true },
    ["Cleanse"] = { Poison = true, Disease = true, Magic = true },
}

function M:Config()
    return OB.profile.modules.partyframes
end

local function solid(parent, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    return t
end

local function makeBorder(parent)
    local b = {}
    b.top = solid(parent); b.bottom = solid(parent)
    b.left = solid(parent); b.right = solid(parent)
    return b
end

local function placeBorder(border, target, thickness)
    border.top:ClearAllPoints(); border.bottom:ClearAllPoints()
    border.left:ClearAllPoints(); border.right:ClearAllPoints()

    border.top:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
    border.top:SetPoint("TOPRIGHT", target, "TOPRIGHT", 1, 1)
    border.top:SetHeight(thickness)
    border.bottom:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -1, -1)
    border.bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
    border.bottom:SetHeight(thickness)
    border.left:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
    border.left:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -1, -1)
    border.left:SetWidth(thickness)
    border.right:SetPoint("TOPRIGHT", target, "TOPRIGHT", 1, 1)
    border.right:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
    border.right:SetWidth(thickness)
end

local function setBorder(border, color, shown)
    local list = { border.top, border.bottom, border.left, border.right }
    for i = 1, 4 do
        if shown then
            list[i]:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
            list[i]:Show()
        else
            list[i]:Hide()
        end
    end
end

function M:EnsureAnchor()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "EquadisOverhaulPartyAnchor", UIParent)
    f:SetWidth(130)
    f:SetHeight(220)
    f:SetPoint("LEFT", UIParent, "LEFT", 10, 220)
    f:EnableMouse(false)

    f.hint = solid(f, "BACKGROUND")
    f.hint:SetAllPoints(f)
    f.hint:SetVertexColor(0.10, 0.60, 1.00, 0.20)
    f.hint:Hide()

    self.frame = f
    return f
end

function M:CaptureOriginals()
    if self.original then return end
    self.original = {}

    for i = 1, 4 do
        local frame = getglobal("PartyMemberFrame" .. i)
        local mana = getglobal("PartyMemberFrame" .. i .. "ManaBar")
        if frame then
            local point, relative, relativePoint, x, y = frame:GetPoint(1)
            self.original[i] = {
                point = point, relative = relative, relativePoint = relativePoint,
                x = x or 0, y = y or 0,
                scale = frame:GetScale() or 1,
                manaHeight = mana and mana:GetHeight() or nil,
                manaAlpha = mana and mana:GetAlpha() or nil,
            }
        end
    end
end

function M:RestoreOriginals()
    if not self.original then return end

    for i = 1, 4 do
        local saved = self.original[i]
        local frame = getglobal("PartyMemberFrame" .. i)
        local mana = getglobal("PartyMemberFrame" .. i .. "ManaBar")
        if saved and frame then
            frame:SetScale(saved.scale or 1)
            frame:ClearAllPoints()
            frame:SetPoint(saved.point, saved.relative, saved.relativePoint, saved.x, saved.y)
        end
        if saved and mana then
            if saved.manaHeight then mana:SetHeight(saved.manaHeight) end
            mana:SetAlpha(saved.manaAlpha or 1)
        end

        for d = 1, 4 do
            local button = getglobal("PartyMemberFrame" .. i .. "Debuff" .. d)
            if button and button.ecoPartyOriginal then
                local o = button.ecoPartyOriginal
                button:SetWidth(o.w); button:SetHeight(o.h); button:SetAlpha(o.alpha)
                button:ClearAllPoints()
                button:SetPoint(o.point, o.relative, o.relativePoint, o.x, o.y)
                if button.ecoPartyBorder then
                    setBorder(button.ecoPartyBorder, {1,1,1,1}, false)
                end
            end
        end

        if frame and frame.ecoDispelBorder then
            setBorder(frame.ecoDispelBorder, {1,1,1,1}, false)
        end
    end
end

function M:ApplyAnchorPosition()
    local anchor = self:EnsureAnchor()
    anchor:ClearAllPoints()
    local saved = self:Config().position
    if saved then
        anchor:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
    else
        anchor:SetPoint("LEFT", UIParent, "LEFT", 10, 220)
    end
end

function M:StorePosition()
    local f = self:EnsureAnchor()
    if not f:GetLeft() then return end
    self:Config().position = {
        x = (f:GetLeft() + f:GetWidth() / 2) - GetScreenWidth() / 2,
        y = (f:GetBottom() + f:GetHeight() / 2) - GetScreenHeight() / 2,
    }
end

function M:DragMode()
    return self.dragging and true or false
end

function M:SetDragMode(on)
    local f = self:EnsureAnchor()
    self.dragging = on and true or nil
    f:EnableMouse(self.dragging and true or false)
    f:SetMovable(self.dragging and true or false)
    if self.dragging then
        f:RegisterForDrag("LeftButton")
        f.hint:Show()
        f:SetScript("OnDragStart", function() this:StartMoving() end)
        f:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            OB.modules.partyframes:StorePosition()
        end)
    else
        f.hint:Hide()
    end
    Say(self.dragging and "move mode on." or "move mode off.")
end

function M:ResetPosition()
    self:Config().position = nil
    self:ApplyAnchorPosition()
    Say("party frames put back at their ECO starting point.")
end

function M:ScanDispels()
    self.canDispel = {}
    if type(GetSpellName) ~= "function" then return end

    local index = 1
    while true do
        local name = GetSpellName(index, BOOKTYPE_SPELL or "spell")
        if not name then break end
        local types = DISPEL_SPELLS[name]
        if types then
            for dtype in pairs(types) do self.canDispel[dtype] = true end
        end
        index = index + 1
    end
end

function M:EnsureDispelBorder(frame)
    if not frame.ecoDispelBorder then
        frame.ecoDispelBorder = makeBorder(frame)
    end
    placeBorder(frame.ecoDispelBorder, frame, self:Config().highlightThickness)
    return frame.ecoDispelBorder
end

function M:StyleDebuffButton(button, frame, index, dtype)
    local cfg = self:Config()
    if not button then return end

    if not button.ecoPartyOriginal then
        local point, relative, relativePoint, x, y = button:GetPoint(1)
        button.ecoPartyOriginal = {
            point = point, relative = relative, relativePoint = relativePoint,
            x = x or 0, y = y or 0,
            w = button:GetWidth(), h = button:GetHeight(), alpha = button:GetAlpha(),
        }
    end

    button:SetWidth(cfg.debuffSize)
    button:SetHeight(cfg.debuffSize)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPRIGHT",
        3 + ((index - 1) * (cfg.debuffSize + cfg.debuffSpacing)), -8)

    if index > cfg.maxDebuffs then button:SetAlpha(0) else button:SetAlpha(1) end

    if not button.ecoPartyBorder then button.ecoPartyBorder = makeBorder(button) end
    placeBorder(button.ecoPartyBorder, button, 1)
    setBorder(button.ecoPartyBorder, TYPE_COLORS[dtype] or {0.15,0.15,0.15,1}, index <= cfg.maxDebuffs)
end

function M:UpdateMember(i)
    local cfg = self:Config()
    local frame = getglobal("PartyMemberFrame" .. i)
    local mana = getglobal("PartyMemberFrame" .. i .. "ManaBar")
    if not frame then return end

    frame:SetScale(cfg.scale)

    if mana then
        mana:SetHeight(cfg.resourceHeight)
        mana:SetAlpha(cfg.showResource and 1 or 0)
    end

    local removableType
    local unit = "party" .. i
    for d = 1, 4 do
        local texture, count, dtype = UnitDebuff(unit, d)
        local button = getglobal("PartyMemberFrame" .. i .. "Debuff" .. d)
        self:StyleDebuffButton(button, frame, d, dtype)
        if texture and dtype and self.canDispel and self.canDispel[dtype] and not removableType then
            removableType = dtype
        end
    end

    local border = self:EnsureDispelBorder(frame)
    if cfg.highlightDispellable and removableType then
        setBorder(border, TYPE_COLORS[removableType] or {1,1,1,1}, true)
    else
        setBorder(border, {1,1,1,1}, false)
    end
end

function M:ApplyLayout()
    local cfg = self:Config()
    local anchor = self:EnsureAnchor()
    self:ApplyAnchorPosition()

    local previous
    for i = 1, 4 do
        local frame = getglobal("PartyMemberFrame" .. i)
        if frame then
            frame:ClearAllPoints()
            if i == 1 then
                if cfg.grow == "up" then
                    frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
                else
                    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
                end
            else
                if cfg.grow == "up" then
                    frame:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, cfg.spacing)
                else
                    frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -cfg.spacing)
                end
            end
            previous = frame
        end
    end
end

function M:Apply()
    if not OB.ModuleShown("partyframes") then
        self:RestoreOriginals()
        return
    end

    self:CaptureOriginals()
    self:ApplyLayout()
    for i = 1, 4 do self:UpdateMember(i) end
end

function M:OnBind()
    self:EnsureAnchor()
    self:CaptureOriginals()
    self:ScanDispels()
    self:Apply()
end

function M:OnUnbind()
    self.dragging = nil
    if self.frame and self.frame.hint then self.frame.hint:Hide() end
    self:RestoreOriginals()
end

function M:OnEvent()
    if event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_ENTERING_WORLD" then
        self:ScanDispels()
    end
    OB.SetDirty(self)
end

function M:OnStyle()
    self:Apply()
end

function M:OnDraw()
    self:Apply()
end
