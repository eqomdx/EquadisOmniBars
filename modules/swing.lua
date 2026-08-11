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

    -- the ranged cycle runs independently: a hunter shooting is not swinging,
    -- and the two toggles are different events
    shooting = false,
    rangedStart = 0,
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

-- ---------------------------------------------------------------------------
-- ranged
-- ---------------------------------------------------------------------------

local function startShooting()
    if OB.testMode then return end
    swing.shooting = true
    swing.rangedStart = GetTime()
end

local function stopShooting()
    if OB.testMode then return end
    swing.shooting = false
    swing.rangedStart = 0
end

--[[ Re-anchor the ranged cycle on a shot that landed.

     CHAT_MSG_SPELL_SELF_DAMAGE carries every spell the player lands, not just
     the auto shot, and vanilla's combat log does not name the source in any form
     this phase can read -- recovering that needs the localisation-aware parser
     Phase 3 brings. So the event is filtered by *timing* instead: an auto shot
     can only land at the end of its own cycle, and anything arriving early in
     the cycle is some other spell and must not move the anchor.

     Three quarters of a cycle is the threshold. Too strict and a shot fired at a
     moving target never re-anchors; too loose and an instant cast fired while
     the shot is pending drags the bar backwards. Getting it wrong is
     self-correcting either way -- the next START_AUTOREPEAT_SPELL re-seeds --
     which is why a heuristic is acceptable here and was not acceptable for the
     main and off hand pair. ]]--
local function shotLanded()
    if OB.testMode or not swing.shooting then return end

    local now = GetTime()
    local speed = UnitRangedDamage("player")
    if not speed or speed <= 0 then return end

    if (now - swing.rangedStart) < (speed * 0.75) then return end

    swing.rangedStart = now
end

local tracker = CreateFrame("Frame", "EquadisOmniBarsSwing", UIParent)

tracker:SetScript("OnEvent", function()
    if event == "START_AUTOREPEAT_SPELL" then
        startShooting()
        return
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        stopShooting()
        return
    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        shotLanded()
        return
    end

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
        stopShooting()
    else
        swingLanded()
    end
end)

tracker:RegisterEvent("PLAYER_ENTER_COMBAT")
tracker:RegisterEvent("PLAYER_LEAVE_COMBAT")
tracker:RegisterEvent("PLAYER_DEAD")
tracker:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
tracker:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
tracker:RegisterEvent("START_AUTOREPEAT_SPELL")
tracker:RegisterEvent("STOP_AUTOREPEAT_SPELL")
tracker:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

-- ---------------------------------------------------------------------------
-- shared implementation
-- ---------------------------------------------------------------------------

local function swingOptions()
    return {
        { "Bar Color", "color", "color", true },
        { "Show Timer", "showTimer", "boolean" },
        { "Show Weapon Speed", "showSpeed", "boolean" },
        { "Swap Text Sides", "swap", "boolean" },
        { "Decimal Places", "decimals", "slider", 0, 2, 1 },
        { "Deplete Instead Of Fill", "deplete", "boolean" },
    }
end

-- plausible speeds for the preview, per hand, when nothing is equipped
local TEST_SPEED = { main = 2.6, off = 1.7, ranged = 2.9 }

local impl = {}

function impl:Config()
    return OB.profile.modules[self.id]
end

-- main and off hand speeds come from one call, so which one this module wants
-- is a property of the module, not a separate API
function impl:GetSpeed()
    local speed, start

    if self.hand == "ranged" then
        speed, start = UnitRangedDamage("player"), OB.swing.rangedStart
    else
        local mainSpeed, offSpeed = UnitAttackSpeed("player")
        if self.hand == "off" then
            speed, start = offSpeed, OB.swing.offStart
        else
            speed, start = mainSpeed, OB.swing.mainStart
        end
    end

    --[[ Unarmed, no off hand equipped, nothing ranged in the slot: the preview
         still has to animate, so test mode substitutes a plausible speed. Live
         play leaves it nil and the bar draws empty. ]]--
    if OB.testMode and (not speed or speed <= 0) then
        speed = TEST_SPEED[self.hand]
    end

    return speed, start
end

-- whether this hand's cycle is running. Melee and ranged have separate toggles,
-- and a hunter shooting is emphatically not auto attacking.
function impl:Active()
    if self.hand == "ranged" then return OB.swing.shooting end
    return OB.swing.attacking
end

function impl:SetStart(now)
    if self.hand == "ranged" then
        OB.swing.rangedStart = now
    elseif self.hand == "off" then
        OB.swing.offStart = now
    else
        OB.swing.mainStart = now
    end
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

    --[[ Nothing in that hand: hide the bar outright rather than draw an empty
         one. SetBarFill(0) only hides the *fill*, which leaves the background
         painted -- an empty trough that reads as a broken bar rather than an
         absent one, and the first thing anyone asks about it is why their off
         hand timer is stuck at zero. ]]--
    if not speed or speed <= 0 then
        self.frame:Hide()
        return
    end

    if slot.show then self.frame:Show() end

    --[[ The bar shows how charged the swing is, so idle -- not auto attacking --
         reads as ready rather than empty. The swing really is available. ]]--
    local elapsed = speed
    if self:Active() then
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

--[[ Each module starts only its own cycle. The three share one state table, so
     a module setting a flag it does not own would start a bar the user is not
     previewing -- and stop it again when a different module's TestStop ran. ]]--
function impl:TestStart(now)
    if self.hand == "ranged" then
        OB.swing.shooting = true
    else
        OB.swing.attacking = true
    end
    self:SetStart(now)
end

function impl:TestStop()
    if self.hand == "ranged" then
        OB.swing.shooting = false
    else
        OB.swing.attacking = false
    end
    self:SetStart(0)
end

function impl:TestStep(now)
    local speed, start = self:GetSpeed()
    if not speed or speed <= 0 then return end

    if (now - start) >= speed then self:SetStart(now) end
end

-- ---------------------------------------------------------------------------
-- the module ids
-- ---------------------------------------------------------------------------

local function defineSwing(id, name, hand, bar, color)
    local m = OB.RegisterModule({
        id = id,
        name = name,
        bar = bar,
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
        requires = { "UnitAttackSpeed", "UnitRangedDamage" },
        events = { "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED" },
    })

    m.hand = hand

    for key, fn in pairs(impl) do
        m[key] = fn
    end

    return m
end

defineSwing("mainhand", "Main Hand", "main", "mainhand", { 1.0, 0.635, 0.0, 1 })
defineSwing("offhand", "Off Hand", "off", "offhand", { 1.0, 0.745, 0.31, 1 })

--[[ The ranged timer has a bar of its own rather than sharing the main hand's.
     No class gate: a warrior with a gun gets it too, and anyone holding nothing
     ranged just sees the bar hide itself. ]]--
defineSwing("ranged", "Ranged", "ranged", "ranged", { 0.45, 0.75, 1.0, 1 })
