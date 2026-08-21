--[[ Equadis' Classic Overhaul :: health

  The player's health, as one more bar in the cluster.

  Purely event driven -- no OnUpdate at all. Health only changes when the game
  says it changed, and a bar that costs nothing per frame is the point of the
  dirty-flag dispatch in hud.lua.

  Target, pet and party health are deliberately out of scope: this is a HUD bar,
  not a unit frame.
]]--

local OB = EquadisClassicOverhaul

--[[ Predicates for this module's own rows, registered here rather than in
     options.lua: that file should not have to know what "the class colour is
     overriding the swatch" means.

     Both express the same precedence the draw path uses -- class beats gradient
     beats swatch -- so a row that is not in charge says so by being dimmed
     rather than by disappearing. ]]--
OB.predicates = OB.predicates or {}

local function healthConfig()
    return OB.profile and OB.profile.modules and OB.profile.modules.health
end

OB.predicates.health_class = function()
    local cfg = healthConfig()
    return (cfg and cfg.classColor) and true or false
end

OB.predicates.health_no_text = function()
    local cfg = healthConfig()
    return (cfg and cfg.textMode == "none") and true or false
end

OB.predicates.health_no_ramp = function()
    local cfg = healthConfig()
    if not cfg then return false end
    return (cfg.classColor or not cfg.healthGradient) and true or false
end

local M = OB.RegisterModule({
    id = "health",
    name = "Health",
    bar = "health",
    priority = 10,
    renders = "bar",
    tickly = false,

    defaults = {
        color = { 0.10, 0.75, 0.20, 1 },
        classColor = false,
        textMode = "max",
        textPos = 50,

        --[[ A bar that slides from green to red as health falls. It replaced a
             three-setting "recolor when low" -- an enable, a threshold and a
             colour -- which did roughly the same job in one step rather than
             continuously. Those are gone rather than kept alongside: two
             overlapping ways to colour a health bar by its own value is one
             too many. ]]--
        healthGradient = false,

        --[[ **Three colours, not two, and the middle one is why it works.**

             A straight blend from green to red passes through (0.5, 0.5, 0) at
             halfway -- olive-brown, dark, and it reads as a fault rather than as
             half health. Routing through a bright midpoint keeps every value on
             the ramp legible.

             This is what Equadis' Threat Meter does, in
             EquadisThreatMeter.lua's row painter: below 50% it runs green to
             yellow, above it yellow to red, with a `colorLimit` of 50 in the
             middle. The difference here is that all three are settings. The
             threat meter's are literals in the draw path and nothing on its
             panel reaches them -- its configurable colours are for the glow.
             Porting this back to it is the plan. ]]--
        fullColor = { 0.10, 0.75, 0.20, 1 },
        halfColor = { 0.95, 0.85, 0.15, 1 },
        lowColor  = { 0.80, 0.15, 0.15, 1 },
    },

    options = {
        --[[ Nothing here is ever hidden by another setting, only dimmed.

             Class colour *overrides* the swatch rather than replacing it, and an
             earlier version said so by hiding the swatch -- which read as the
             colour having been deleted, and was reported as exactly that. The
             three ramp colours are dimmed the same way when the ramp is off, so
             the panel shows what the ramp *would* look like while you are
             deciding whether to switch it on. ]]--
        { "Bar Color", "color", "color", true,
          nil, nil, nil, nil, "@health_class" },

        { "Color By Remaining Health", "healthGradient", "boolean",
          nil, nil, nil, nil, nil, "@health_class" },
        { "Full Health Color", "fullColor", "color", true,
          nil, nil, nil, nil, "@health_no_ramp" },
        { "Half Health Color", "halfColor", "color", true,
          nil, nil, nil, nil, "@health_no_ramp" },
        { "Low Health Color", "lowColor", "color", true,
          nil, nil, nil, nil, "@health_no_ramp" },

        { "Color By Class", "classColor", "boolean" },

        { "Text", "textMode", OB.Enum(
                { "none", "value", "percent", "max", "valuepct", "maxpct" },
                { "None", "Current Only", "Percentage", "Current / Max",
                  "Current (Percent)", "Current / Max (Percent)" }) },
        { "Text Position", "textPos", "slider", 0, 100, 1,
          nil, nil, "@health_no_text" },
    },

    requires = { "UnitHealth", "UnitHealthMax" },

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
--[[ The health ramp: low at empty, half at half, full at full.

     The arithmetic is OB.Ramp, shared with the threat meter, because the two
     want the same ramp pointed in opposite directions -- health runs full to
     empty, threat runs safe to about-to-pull -- and it does not care which. The
     three colours and which end they belong to stay here. ]]--
function M:RampColor(fraction)
    local cfg = self:Config()
    return OB.Ramp(cfg.lowColor, cfg.halfColor, cfg.fullColor, fraction)
end

--[[ One precedence, stated once, and the panel's dimming is derived from it:

       Color By Class            wins outright
       Color By Remaining Health wins over the swatch
       Bar Color                 what is left

     Class is on top because it is the one choice that is about *you* rather than
     about the bar's value, so it should not be silently overruled by a ramp
     somebody set months ago. ]]--
function M:CurrentColor(fraction)
    local cfg = self:Config()

    if cfg.classColor then
        local r, g, b = OB.ClassColor(OB.class)
        return { r, g, b, cfg.color[4] or 1 }
    end

    if cfg.healthGradient then return self:RampColor(fraction or 1) end

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
    OB.SetBarText(self.frame, self.frame.center,
            OB.FormatValue(value, max, cfg.textMode), cfg.textPos)
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
