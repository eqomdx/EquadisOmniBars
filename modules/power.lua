--[[ Equadis' OmniBars :: power

  The resource bar. One module for every power type in the game.

  In vanilla, UnitMana() and UnitManaMax() return the *current* power whatever
  its type -- mana, rage, energy, focus, happiness -- so there is exactly one
  accessor and RogueBars' energy rendering path generalises without a single
  branch. The work is entirely in the ticker.

  A druid changing form does not change which module holds the slot. It changes
  which *variant* of this module is active: cfg.byType[UnitPowerType] carries the
  colour and the ticker mode. Geometry, texture, border, background, text size
  and flip all belong to the slot, so the bar recolours in place and does not
  move a pixel. That is the whole point of the slot model.
]]--

local OB = EquadisOmniBars

local floor = math.floor

-- ---------------------------------------------------------------------------
-- ticker strategies
--
-- Both produce the same thing -- a cycle start and a cycle length -- and both
-- feed the same renderer. Which one runs is chosen by power type.
-- ---------------------------------------------------------------------------

OB.tickers = {}

--[[ Energy and focus: regeneration arrives as a visible pulse, so the cycle can
     be anchored to a real observation.

     When no gain is seen -- capped, or draining faster than it regenerates --
     the cycle advances by *whole* periods rather than restarting. Restarting
     would put the sweep off-beat, so the spark would be in the wrong place the
     moment you dumped energy, which is precisely when it matters. ]]--
OB.tickers.pulse = {
    Reset = function(t, now)
        t.start = now
        t.period = 2
    end,

    Observe = function(t, now, current, previous)
        if current > previous then
            t.start = now
            t.period = 2
            return true
        end

        while now >= t.start + t.period do
            t.start = t.start + t.period
        end

        return false
    end,
}

--[[ Mana: there is no pulse to observe, because spirit and mp5 both trickle in
     between ticks. The sweep is inferred from what the last change looked like.

     Spending starts a five second window -- the five-second rule, during which
     spirit regen is suppressed and only mp5 gear keeps paying out. A gain large
     enough to stand out from the remembered trickle is a real tick and starts a
     two second window.

     Restructured from Equadis' UnitFrames, where the same logic was spread over
     manaStart / manaPeriod / manaRestart / manaTrickle plus a deferred-restart
     flag. The sweep length is one piece of state here. ]]--
OB.tickers.fsr = {
    Reset = function(t, now)
        t.start = now
        t.period = 2
        t.trickle = nil
    end,

    Observe = function(t, now, current, previous)
        local diff = current - previous

        if diff < 0 then
            t.start = now
            t.period = 5
            return true
        end

        if diff > 0 then
            local threshold = 5
            if t.trickle then threshold = t.trickle * 1.2 end

            if t.period ~= 5 and diff > threshold then
                t.start = now
                t.period = 2
                return true
            end

            t.trickle = diff
        end

        -- ticks keep coming whether or not mana moved, so roll the window over
        if now >= t.start + t.period then
            t.start = now
            t.period = 2
        end

        return false
    end,
}

-- rage and happiness do not tick
OB.powerTickers = { [0] = "fsr", [2] = "pulse", [3] = "pulse" }

-- ---------------------------------------------------------------------------
-- rage decay
--
-- Rage is the one resource that leaks while you stand still, and the rate is a
-- server constant the 1.12 client never handed to Lua. Turtle may well have
-- retuned it. So it is measured rather than assumed: the marker points wherever
-- this server's own behaviour says it will, and needs no constant to keep up to
-- date.
--
-- A run of falling values is anchored and then divided. Two things end a run:
-- any gain, and a step too abrupt to be decay -- spending rage is not the bar
-- draining, and averaging a cost into the rate would put the marker on the
-- floor. The estimate is taken once enough rage has actually been lost rather
-- than after a fixed wait, so it holds whether the server ticks four times a
-- second or once.
-- ---------------------------------------------------------------------------

local DECAY_MIN_DROP = 2    -- rage that must be lost before a rate is believed
local DECAY_SPEND = 5       -- a single step larger than this is a cost

-- ---------------------------------------------------------------------------
-- module
-- ---------------------------------------------------------------------------

local M = OB.RegisterModule({
    id = "power",
    name = "Resource",
    bar = "resource",
    priority = 10,
    renders = "bar",
    tickly = true,

    defaults = {
        textMode = "value",
        tickerColor = { 1, 1, 1, 1 },
        fsrShade = true,
        fsrColor = { 0.3, 0.5, 1.0, 0.25 },

        rageDecay = false,
        rageDecaySeconds = 3,
        rageDecayColor = { 1.0, 0.85, 0.35, 0.9 },

        --[[ Keyed by UnitPowerType. Only colour and ticker mode live here: the
             per-type entry is what a druid swaps between, and everything else
             about the bar has to stay put across that swap. ]]--
        byType = {
            [0] = { color = { 0.20, 0.40, 0.90, 1 }, ticker = "always" },
            [1] = { color = { 0.90, 0.20, 0.20, 1 }, ticker = "never" },
            [2] = { color = { 1.00, 0.50, 0.25, 1 }, ticker = "always" },
            [3] = { color = { 0.87, 0.86, 0.00, 1 }, ticker = "always" },
            [4] = { color = { 0.00, 0.80, 0.20, 1 }, ticker = "never" },
        },
    },

    options = {
        { "Bar Colour", "@variant:color", "color", true },
        { "Ticker", "@variant:ticker", OB.Enum(
                { "always", "nofull", "never" },
                { "Show Always", "Hide When Full", "Never Show" }) },
        { "Ticker Colour", "tickerColor", "color", true },
        { "Text", "textMode", OB.Enum(
                { "none", "value", "percent", "max" },
                { "None", "Current Only", "Percentage", "Current / Max" }) },
        { "Shade Five Second Rule", "fsrShade", "boolean", nil, nil, nil, nil, "@power_mana" },
        { "Five Second Rule Colour", "fsrColor", "color", true, nil, nil, nil, "@power_mana" },
        { "Mark Rage Decay", "rageDecay", "boolean", nil, nil, nil, nil, "@power_rage" },
        { "Decay Look Ahead", "rageDecaySeconds", "slider", 1, 10, 1, nil, "@power_rage" },
        { "Decay Marker Colour", "rageDecayColor", "color", true, nil, nil, nil, "@power_rage" },
    },

    requires = { "UnitMana", "UnitManaMax", "UnitPowerType" },

    events = {
        "UNIT_MANA", "UNIT_MAXMANA",
        "UNIT_RAGE", "UNIT_MAXRAGE",
        "UNIT_ENERGY", "UNIT_MAXENERGY",
        "UNIT_FOCUS", "UNIT_MAXFOCUS",
        "UNIT_HAPPINESS",
        "UNIT_DISPLAYPOWER",
        "PLAYER_ENTERING_WORLD",
    },
})

M.state = { start = 0, period = 2 }

function M:Config()
    return OB.profile.modules.power
end

--[[ The variant for the power type in play. Also the panel's "variant" scope, so
     a druid editing the bar colour edits the colour of the form they are in. ]]--
function M:VariantTable()
    local cfg = self:Config()
    local t = self.ptype or UnitPowerType("player") or 0
    return cfg.byType[t] or cfg.byType[0]
end

--[[ The one accessor, and the one place test mode substitutes. Everything below
     draws from this, so the preview path and the live path are identical. ]]--
function M:GetValue()
    if OB.testMode then
        return OB.test.power or 0, OB.test.powerMax or 100
    end
    return UnitMana("player") or 0, UnitManaMax("player") or 0
end

--[[ Adopt the current power type: pick the ticker, restart it, and re-seed the
     last-known value.

     That last step is not optional. Shifting form changes what UnitMana reports
     in a single step, and without re-seeding, the jump reads as an enormous
     regeneration tick and yanks the sweep to the wrong phase. ]]--
function M:AdoptPowerType(now)
    self.ptype = UnitPowerType("player") or 0

    local strategy = OB.powerTickers[self.ptype]
    self.ticker = strategy and OB.tickers[strategy] or nil

    if self.ticker then self.ticker.Reset(self.state, now) end

    local value = self:GetValue()
    self.last = value
end

function M:OnBind(slot)
    self:AdoptPowerType(GetTime())
end

--[[ Watch a run of falling rage and keep a rate estimate. See the note above the
     constants for why this is measured and not assumed.

     `decayFrom` doubles as the "rage is falling right now" flag, which is what
     the marker keys off: a projection drawn while rage is climbing points at a
     number that will never happen. ]]--
function M:ObserveRageDecay(now, current, previous)
    local diff = current - previous

    if diff > 0 or diff < -DECAY_SPEND then
        self.decayFrom = nil
        return
    end

    --[[ Rage held still. Not a gain, so an open run continues -- the client
         reports rage in whole numbers and a slow drain shows as flat frames
         between steps -- but it must not *start* one. Without this, sitting at
         full rage arms a run and the marker appears on a bar that is not going
         anywhere. ]]--
    if diff == 0 then return end

    if not self.decayFrom then
        self.decayFrom = { at = now, value = current }
        return
    end

    local elapsed = now - self.decayFrom.at
    local lost = self.decayFrom.value - current

    if elapsed <= 0 or lost < DECAY_MIN_DROP then return end

    self.rageRate = lost / elapsed

    -- re-anchor so the estimate keeps tracking instead of freezing on the first
    -- sample it ever took
    self.decayFrom = { at = now, value = current }
end

function M:OnStyle(slot)
    local cfg = self:Config()
    local variant = self:VariantTable()

    OB.SetBarColor(self.frame, variant.color)

    local spark = OB.BarSpark(self.frame)
    spark:SetHeight(slot.h * 2)
    spark:SetVertexColor(cfg.tickerColor[1], cfg.tickerColor[2],
            cfg.tickerColor[3], cfg.tickerColor[4] or 1)
end

function M:OnEvent()
    if event == "UNIT_DISPLAYPOWER" or event == "PLAYER_ENTERING_WORLD" then
        self:AdoptPowerType(GetTime())
        OB.SetDirty(self)
        -- the colour belongs to the new variant, so the bar has to be restyled
        if self.frame and self.slotId then
            self:OnStyle(OB.profile.slots[self.slotId])
        end
        return
    end

    if arg1 and arg1 ~= "player" then return end
    OB.SetDirty(self)
end

function M:OnUpdate(now)
    local cfg = self:Config()
    local value, max = self:GetValue()

    if self.last == nil then self.last = value end

    --[[ Test mode drives the cycle itself, so the observer is skipped: otherwise
         the simulated numbers would be read as real regeneration and fight the
         script for control of the phase. ]]--
    if self.ticker and not OB.testMode then
        if self.ticker.Observe(self.state, now, value, self.last) then
            OB.SetDirty(self)
            if OB.profile.audible and value > self.last then
                PlaySound("UChatScrollButton")
            end
        end
    end

    --[[ Unlike the tickers, this one runs in test mode too. It has no cycle for
         the preview to fight over -- it only learns a number -- and letting the
         simulated drain feed it is what puts the marker on screen before anyone
         has stood in a field waiting for real rage to leak away. ]]--
    if self.ptype == 1 then
        self:ObserveRageDecay(now, value, self.last)
    end

    self.last = value

    local bar = self.frame
    local slot = OB.profile.slots[self.slotId]
    local variant = self:VariantTable()

    -- three-state visibility, kept per power type so a druid can tick in cat
    -- form and stay silent in bear
    local mode = variant.ticker
    local show = self.ticker
            and (mode == "always" or (mode == "nofull" and value < max))

    if show then
        OB.DrawSpark(bar, self.state.start, self.state.period, now, slot.flip)
        OB.BarSpark(bar):Show()
    elseif bar.spark then
        bar.spark:Hide()
    end

    --[[ Shade the five second rule as a shrinking region over the fill. An
         invisible state you have to count out in your head is not a readout. ]]--
    if cfg.fsrShade and self.ticker and self.state.period == 5 then
        local phase = (now - self.state.start) / self.state.period
        if phase < 0 then phase = 0 end
        if phase > 1 then phase = 1 end
        local c = cfg.fsrColor
        OB.SetBarOverlay(bar, 1 - phase, slot.flip, c[1], c[2], c[3], c[4] or 0.25)
    elseif bar.overlay then
        bar.overlay:Hide()
    end
end

function M:OnDraw()
    local cfg = self:Config()
    local value, max = self:GetValue()

    local fraction = 0
    if max > 0 then fraction = value / max end

    local slot = OB.profile.slots[self.slotId]
    OB.SetBarFill(self.frame, fraction, slot.flip)
    self.frame.center:SetText(OB.FormatValue(value, max, cfg.textMode))

    --[[ Where rage will have leaked to by the time the look-ahead is up, as a
         line on the bar. Drawn only while it is actually leaking and only once a
         rate has been observed, so it never asserts a number the addon has not
         watched this server produce. ]]--
    if cfg.rageDecay and self.ptype == 1 and self.decayFrom and self.rageRate
            and max > 0 then
        local projected = value - (self.rageRate * cfg.rageDecaySeconds)
        if projected < 0 then projected = 0 end

        local c = cfg.rageDecayColor
        OB.SetBarTick(self.frame, 1, projected / max, slot.flip,
                c[1], c[2], c[3], c[4] or 1)
    else
        OB.HideBarTicks(self.frame)
    end
end

-- ---------------------------------------------------------------------------
-- test mode
--
-- The cycle keys off the power type actually in play, so a warrior previews rage
-- building and dumping rather than watching an energy pattern in red.
-- ---------------------------------------------------------------------------

function M:TestStart(now)
    self.ptype = UnitPowerType("player") or 0

    -- read the real maximum straight from the API: OB.testMode is already on by
    -- the time this runs, so GetValue would hand back the (empty) test values
    local realMax = UnitManaMax("player")
    if not realMax or realMax < 1 then realMax = 100 end

    OB.test.powerMax = realMax
    OB.test.powerRefill = false
    OB.test.powerSpendAt = now + 1
    OB.test.powerTickAt = now + 2

    if self.ptype == 1 then
        -- rage starts empty and builds
        OB.test.power = 0
        OB.test.powerRefill = true
        OB.test.powerDecayAt = now + 1
    else
        OB.test.power = realMax
    end

    self.state.start = now
    self.state.period = 2
end

function M:TestStop()
    -- the observer was idle throughout, so a stale value would read as a
    -- phantom tick the moment it resumes
    self.last = self:GetValue()
    self.state.start = GetTime()
end

function M:TestStep(now)
    local max = OB.test.powerMax or 100
    local step = max * 0.2
    local spend = max * 0.4
    local changed = false

    if now >= OB.test.powerTickAt then
        OB.test.powerTickAt = now + 2

        OB.test.power = OB.test.power + step
        if OB.test.power > max then OB.test.power = max end
        if OB.test.powerRefill and OB.test.power >= max then
            OB.test.powerRefill = false
        end
        if not OB.test.powerRefill then OB.test.powerSpendAt = now + 1 end

        -- keep the spark phase-locked to the simulated tick
        self.state.start = now
        self.state.period = 2

        if OB.profile.audible then PlaySound("UChatScrollButton") end
        changed = true
    end

    if not OB.test.powerRefill and OB.test.powerSpendAt > 0
            and now >= OB.test.powerSpendAt then
        OB.test.powerSpendAt = 0
        OB.test.power = OB.test.power - spend

        if OB.test.power <= 0 then
            OB.test.power = 0
            OB.test.powerRefill = true
        end

        -- a spend is what starts the five second rule, so the preview shows it
        if self.ticker == OB.tickers.fsr then
            self.state.start = now
            self.state.period = 5
        end

        changed = true
    end

    --[[ Rage leaks in the preview because the decay marker has nothing to point
         at otherwise. A whole number once a second, so the floor below cannot
         eat a fractional step -- and the rate the observer then measures off
         this is the preview's rate, not a claim about any server. ]]--
    if self.ptype == 1 and not OB.test.powerRefill
            and now >= (OB.test.powerDecayAt or 0) then
        OB.test.powerDecayAt = now + 1

        OB.test.power = OB.test.power - 3
        if OB.test.power < 0 then OB.test.power = 0 end
        changed = true
    end

    OB.test.power = floor(OB.test.power)
    if changed then OB.SetDirty(self) end
end
