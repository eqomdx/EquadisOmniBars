--[[ Equadis' OmniBars :: health

  The player's health, as one more bar in the cluster.

  Purely event driven -- no OnUpdate at all. Health only changes when the game
  says it changed, and a bar that costs nothing per frame is the point of the
  dirty-flag dispatch in hud.lua.

  Target, pet and party health are deliberately out of scope: this is a HUD bar,
  not a unit frame.
]]--

local OB = EquadisOmniBars

local M = OB.RegisterModule({
    id = "health",
    name = "Health",
    slot = "health",
    priority = 10,
    renders = "bar",
    tickly = false,

    defaults = {
        color = { 0.10, 0.75, 0.20, 1 },
        classColor = false,
        textMode = "max",

        --[[ Recolour below a threshold. Off by default, but it is the single
             most useful thing a small health bar can do: at a glance the bar
             says "low" without you having to read the number. ]]--
        lowEnable = false,
        lowThreshold = 0.35,
        lowColor = { 0.90, 0.10, 0.10, 1 },
    },

    options = {
        { "Bar Colour", "color", "color", true, nil, nil, nil, "!classColor" },
        { "Colour By Class", "classColor", "boolean" },
        { "Text", "textMode", OB.Enum(
                { "none", "value", "percent", "max" },
                { "None", "Current Only", "Percentage", "Current / Max" }) },
        { "Recolour When Low", "lowEnable", "boolean" },
        { "Low Threshold", "lowThreshold", "slider", 5, 95, 5, 0.01, "lowEnable" },
        { "Low Colour", "lowColor", "color", true, nil, nil, nil, "lowEnable" },
    },

    events = {
        "UNIT_HEALTH", "UNIT_MAXHEALTH",
        "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    },
})

function M:Config()
    return OB.profile.modules.health
end

--[[ Deliberately the global UnitHealth rather than a cached value. When the
     feign-death override lands with the unit frames module it replaces that
     global, and this bar picks the corrected number up for free. ]]--
function M:GetValue()
    if OB.testMode then
        return OB.test.health or 0, OB.test.healthMax or 100
    end
    return UnitHealth("player") or 0, UnitHealthMax("player") or 0
end

function M:OnEvent()
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 ~= "player" then return end
    end
    OB.SetDirty(self)
end

--[[ Player-only means the class is fixed and known at login, so this is three
     lines. Equadis' UnitFrames needs a hundred for the same idea because it has
     to handle arbitrary units, reactions, tapped mobs and pet happiness. ]]--
function M:CurrentColor(fraction)
    local cfg = self:Config()

    if cfg.lowEnable and fraction <= cfg.lowThreshold then
        return cfg.lowColor
    end

    if cfg.classColor then
        local r, g, b = OB.ClassColor(OB.class)
        return { r, g, b, cfg.color[4] or 1 }
    end

    return cfg.color
end

function M:OnDraw()
    local cfg = self:Config()
    local value, max = self:GetValue()

    local fraction = 0
    if max > 0 then fraction = value / max end

    local slot = OB.profile.slots[self.slotId]

    OB.SetBarColor(self.frame, self:CurrentColor(fraction))
    OB.SetBarFill(self.frame, fraction, slot.flip)
    self.frame.center:SetText(OB.FormatValue(value, max, cfg.textMode))
end

-- the low-health colour is chosen per draw, so styling only has to seed it
function M:OnStyle(slot)
    OB.SetBarColor(self.frame, self:Config().color)
end

-- drain to near-death and heal back, so the low-health recolour is previewable
function M:TestStart(now)
    local realMax = UnitHealthMax("player")
    if not realMax or realMax < 1 then realMax = 100 end

    OB.test.healthMax = realMax
    OB.test.health = realMax
    OB.test.healthAt = now
    OB.test.healthFalling = true
end

function M:TestStep(now)
    if (now - (OB.test.healthAt or 0)) < 0.2 then return end
    OB.test.healthAt = now

    local max = OB.test.healthMax or 100
    local step = max * 0.05

    if OB.test.healthFalling then
        OB.test.health = OB.test.health - step
        if OB.test.health <= max * 0.1 then
            OB.test.health = max * 0.1
            OB.test.healthFalling = false
        end
    else
        OB.test.health = OB.test.health + (step * 2)
        if OB.test.health >= max then
            OB.test.health = max
            OB.test.healthFalling = true
        end
    end

    OB.test.health = math.floor(OB.test.health)
    OB.SetDirty(self)
end
