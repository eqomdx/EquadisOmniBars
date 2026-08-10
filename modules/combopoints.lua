--[[ Equadis' OmniBars :: combo points

  Five segments, each with its own colour.

  Inactive points dim the *fill colour's* alpha, never the frame's. Frame alpha
  fades the border too, and the border has to stay solid or the row of empty
  points loses its outline and the bar reads as shorter than it is.
]]--

local OB = EquadisOmniBars

local M = OB.RegisterModule({
    id = "combopoints",
    name = "Combo Points",
    slot = "points",
    priority = 10,
    classes = { ROGUE = true, DRUID = true },
    renders = "segments",
    segments = 5,
    tickly = false,

    defaults = {
        -- #f5de11 through #f52811: yellow at one point, red at five
        colors = {
            { 245 / 255, 222 / 255, 17 / 255, 1 },
            { 245 / 255, 177 / 255, 17 / 255, 1 },
            { 245 / 255, 135 / 255, 17 / 255, 1 },
            { 245 / 255, 82 / 255, 17 / 255, 1 },
            { 245 / 255, 40 / 255, 17 / 255, 1 },
        },
        dim = 0.3,
        hideWhenZero = false,
    },

    options = {
        { "Point 1 Colour", "colors.1", "color", true },
        { "Point 2 Colour", "colors.2", "color", true },
        { "Point 3 Colour", "colors.3", "color", true },
        { "Point 4 Colour", "colors.4", "color", true },
        { "Point 5 Colour", "colors.5", "color", true },
        { "Inactive Opacity", "dim", "slider", 0, 100, 5, 0.01 },
        { "Hide At Zero Points", "hideWhenZero", "boolean" },
    },

    events = { "PLAYER_COMBO_POINTS", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED" },
})

function M:Config()
    return OB.profile.modules.combopoints
end

--[[ Vanilla's GetComboPoints takes no arguments. Some client mods add a
     (unit, target) signature, so it is called bare and any extra returns are
     ignored. ]]--
function M:GetValue()
    if OB.testMode then return OB.test.combo or 0 end
    return GetComboPoints() or 0
end

function M:OnEvent()
    OB.SetDirty(self)
end

function M:OnStyle(slot)
    -- every segment is always drawn at 100%; only the colour says whether the
    -- point is active
    for i = 1, self.frame.count do
        OB.SetBarFill(self.frame.bars[i], 1, false)
    end
end

function M:OnDraw()
    local cfg = self:Config()
    local slot = OB.profile.slots[self.slotId]
    local count = self:GetValue()

    if cfg.hideWhenZero and count == 0 then
        self.frame:Hide()
        return
    end
    if not slot.hide then self.frame:Show() end

    for i = 1, self.frame.count do
        -- flipping reverses which end lights up first, not the fill direction:
        -- a segment is either lit or it is not
        local index = i
        if slot.flip then index = (self.frame.count + 1) - i end

        local color = cfg.colors[index] or { 1, 1, 1, 1 }
        local bar = self.frame.bars[i]

        OB.SetBarFill(bar, 1, false)

        if index <= count then
            OB.SetBarColor(bar, color)
        else
            OB.SetBarColor(bar, color, cfg.dim)
        end
    end
end

-- climb one a second and wrap past five
function M:TestStart(now)
    OB.test.combo = 0
    OB.test.comboAt = now
end

function M:TestStep(now)
    if (now - (OB.test.comboAt or 0)) < 1 then return end

    OB.test.comboAt = now
    OB.test.combo = (OB.test.combo or 0) + 1
    if OB.test.combo > 5 then OB.test.combo = 0 end

    OB.SetDirty(self)
end
