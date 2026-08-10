--[[ Equadis' OmniBars :: swing timers

  Main hand and off hand, as two module ids over one implementation table. A
  third (swing_ranged) drops in the same way once the ranged timer lands.

  Swing tracking is a data source rather than a renderer, so it runs on its own
  event frame instead of on either module. Hanging it off swing_main would break
  the off-hand bar the moment someone emptied the main hand slot, and having both
  modules register the same events would attribute every swing twice.
]]--

local OB = EquadisOmniBars

local swing = {
    attacking = false,
    mainStart = 0,
    offStart = 0,
}

OB.swing = swing

-- ---------------------------------------------------------------------------
-- tracking
-- ---------------------------------------------------------------------------

local function startSwings()
    if OB.testMode then return end
    local now = GetTime()
    swing.attacking = true
    swing.mainStart = now
    swing.offStart = now
end

--[[ Auto attack stopped: the target died, moved out of range, or the player
     toggled attack off. The bars go idle rather than freezing at full.

     Without handling the stop, nothing ever clears the timers and both bars sit
     at 100% forever -- which looks exactly like a working, permanently ready
     swing. ]]--
local function stopSwings()
    if OB.testMode then return end
    swing.attacking = false
    swing.mainStart = 0
    swing.offStart = 0
end

--[[ A white swing landed (hit or miss). Vanilla's combat log does not say which
     hand it came from, so it is attributed to whichever hand has been ready
     longest.

     "Ready longest" -- largest overdue value -- and NOT "closest to its due
     time". When anything stops the swings for a while (a stun, a knockdown,
     running out of range, facing away) both hands end up overdue by different
     amounts. Ranking by distance from due lets the less-overdue hand win every
     single comparison, so the other hand is never re-anchored and its bar stays
     pinned at 100% forever. Ranking by most-overdue always re-anchors the
     starved hand first, so the pair recovers on its own within a swing or two.

     This is the single subtlest piece of logic carried over from RogueBars and
     the self-healing property is the entire reason for it. ]]--
local function swingLanded()
    if OB.testMode then return end

    local now = GetTime()
    local mainSpeed, offSpeed = UnitAttackSpeed("player")

    --[[ A landed swing proves we are attacking even if the toggle event was
         missed -- already swinging on login, or the event was eaten -- so the
         bars recover on their own rather than staying idle. ]]--
    if not swing.attacking then
        swing.attacking = true
        swing.mainStart = now
        swing.offStart = now
    end

    if offSpeed and offSpeed > 0 then
        local mainReady = now - (swing.mainStart + (mainSpeed or 0))
        local offReady = now - (swing.offStart + offSpeed)

        if mainReady >= offReady then
            swing.mainStart = now
        else
            swing.offStart = now
        end
    else
        swing.mainStart = now
    end
end

local tracker = CreateFrame("Frame", "EquadisOmniBarsSwing", UIParent)

tracker:SetScript("OnEvent", function()
    --[[ PLAYER_ENTER_COMBAT and PLAYER_LEAVE_COMBAT are the melee auto-attack
         toggle in vanilla, not combat state. Combat state is
         PLAYER_REGEN_DISABLED / ENABLED, which hud.lua uses separately for
         visibility. Confusing the two is why the timers used to never stop. ]]--
    if event == "PLAYER_ENTER_COMBAT" then
        startSwings()
    elseif event == "PLAYER_LEAVE_COMBAT" then
        stopSwings()
    elseif event == "PLAYER_DEAD" then
        stopSwings()
    else
        swingLanded()
    end
end)

tracker:RegisterEvent("PLAYER_ENTER_COMBAT")
tracker:RegisterEvent("PLAYER_LEAVE_COMBAT")
tracker:RegisterEvent("PLAYER_DEAD")
tracker:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
tracker:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")

-- ---------------------------------------------------------------------------
-- shared implementation
-- ---------------------------------------------------------------------------

local function swingOptions()
    return {
        { "Bar Colour", "color", "color", true },
        { "Show Timer", "showTimer", "boolean" },
        { "Show Weapon Speed", "showSpeed", "boolean" },
        { "Swap Text Sides", "swap", "boolean" },
        { "Decimal Places", "decimals", "slider", 0, 2, 1 },
        { "Deplete Instead Of Fill", "deplete", "boolean" },
    }
end

local impl = {}

function impl:Config()
    return OB.profile.modules[self.id]
end

-- main and off hand speeds come from one call, so which one this module wants
-- is a property of the module, not a separate API
function impl:GetSpeed()
    local mainSpeed, offSpeed = UnitAttackSpeed("player")

    local speed, start
    if self.hand == "off" then
        speed, start = offSpeed, OB.swing.offStart
    else
        speed, start = mainSpeed, OB.swing.mainStart
    end

    --[[ Unarmed, or no off hand equipped: the preview still has to animate, so
         test mode substitutes a plausible speed. Live play leaves it nil and the
         bar draws empty. ]]--
    if OB.testMode and (not speed or speed <= 0) then
        if self.hand == "off" then speed = 1.7 else speed = 2.6 end
    end

    return speed, start
end

function impl:OnStyle(slot)
    local cfg = self:Config()
    OB.SetBarColor(self.frame, cfg.color)
end

function impl:OnEvent()
    OB.SetDirty(self)
end

function impl:OnUpdate(now)
    local cfg = self:Config()
    local slot = OB.profile.slots[self.slotId]
    local bar = self.frame

    local speed, start = self:GetSpeed()

    if not speed or speed <= 0 then
        OB.SetBarFill(bar, 0, slot.flip)
        bar.left:SetText("")
        bar.right:SetText("")
        return
    end

    --[[ The bar shows how charged the swing is, so idle -- not auto attacking --
         reads as ready rather than empty. The swing really is available. ]]--
    local elapsed = speed
    if OB.swing.attacking then
        elapsed = now - start
        if elapsed > speed then elapsed = speed end
        if elapsed < 0 then elapsed = 0 end
    end

    local timerText, speedText = "", ""

    if cfg.showTimer then
        timerText = string.format("%." .. (cfg.decimals or 1) .. "f", speed - elapsed)
    end
    if cfg.showSpeed then
        speedText = string.format("[%.2f]", speed)
    end

    -- fill: empty right after swinging, full when ready. deplete: the reverse.
    local shown = elapsed
    if cfg.deplete then shown = speed - elapsed end

    OB.SetBarFill(bar, shown / speed, slot.flip)

    if cfg.swap then
        bar.left:SetText(speedText)
        bar.right:SetText(timerText)
    else
        bar.left:SetText(timerText)
        bar.right:SetText(speedText)
    end
end

-- the sweep is continuous, so OnUpdate does the drawing and OnDraw only has to
-- catch the frame an event lands on
function impl:OnDraw()
    self:OnUpdate(GetTime())
end

function impl:TestStart(now)
    OB.swing.attacking = true
    OB.swing.mainStart = now
    OB.swing.offStart = now
end

function impl:TestStop()
    OB.swing.attacking = false
    OB.swing.mainStart = 0
    OB.swing.offStart = 0
end

function impl:TestStep(now)
    local speed = self:GetSpeed()
    if not speed or speed <= 0 then return end

    OB.swing.attacking = true

    if self.hand == "off" then
        if (now - OB.swing.offStart) >= speed then OB.swing.offStart = now end
    else
        if (now - OB.swing.mainStart) >= speed then OB.swing.mainStart = now end
    end
end

-- ---------------------------------------------------------------------------
-- the module ids
-- ---------------------------------------------------------------------------

local function defineSwing(id, name, hand, slot, color)
    local m = OB.RegisterModule({
        id = id,
        name = name,
        slot = slot,
        priority = 10,
        renders = "bar",
        tickly = true,

        defaults = {
            color = color,
            showTimer = true,
            showSpeed = true,
            swap = false,
            decimals = 1,
            deplete = false,
        },

        options = swingOptions(),
        events = { "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED" },
    })

    m.hand = hand

    for key, fn in pairs(impl) do
        m[key] = fn
    end

    return m
end

defineSwing("swing_main", "Main Hand", "main", "swingA", { 1.0, 0.635, 0.0, 1 })
defineSwing("swing_off", "Off Hand", "off", "swingB", { 1.0, 0.745, 0.31, 1 })
