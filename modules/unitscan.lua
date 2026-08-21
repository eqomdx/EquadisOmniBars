--[[ Equadis' Classic Overhaul :: UnitScan

  A native 1.12 named-unit scanner, implemented inside ECO from the behaviour of
  Shirsig's unitscan-vanilla rather than bundling its unlicensed source/assets.

  Vanilla's name-targeting calls are the useful primitive, but 1.12-derived
  clients can fall back to fuzzy/prefix matches. ECO therefore uses only
  TargetByName(name, true), treats it as a probe, and verifies UnitName("target")
  itself before declaring a hit. Automatic probes pause whenever the player
  already has a target. A successful passive probe is immediately cleared unless
  the optional Auto Target setting is enabled. The failed lookup is noisy, so
  the client error/sound handlers are muted only across the call and restored
  immediately afterwards. A hit is announced once, then that watched name enters
  a short per-target re-alert cooldown instead of being removed from the scan list.
]]--

local OB = EquadisClassicOverhaul
local Say = function(msg) OB.Print(msg, "UnitScan") end

local CHECK_INTERVAL = 0.10
local PROBE_INTERVAL = 0.50

local M = OB.RegisterModule({
    id = "unitscan",
    name = "UnitScan",
    feature = true,
    renders = "none",
    -- Empty scan lists cost effectively nothing, so keep the feature running by
    -- default.  The old build accepted targets while the module itself could
    -- still be disabled, which made a perfectly valid target list look broken.
    defaultEnabled = true,
    requires = {},

    defaults = {
        targetInput = "",
        alertSound = true,
        screenFlash = true,
        showAlert = true,
        autoTarget = false,
        addMarkerOnTarget = false,
        reAlertMinutes = 2,
    },

    options = {
        { "Targets", "__s_targets", "section", "targets" },
        { "Target", "targetInput", "text", 220, 100 },
        { "Add Target", "__a_add", "action",
          function() OB.modules.unitscan:AddInputTarget() end },
        { "Remove Target", "__a_remove", "action",
          function() OB.modules.unitscan:RemoveInputTarget() end },
        { "List All Targets", "__a_list", "action",
          function() OB.modules.unitscan:PrintTargets() end },
        { "Clear All Targets", "__a_clear", "action",
          function() OB.modules.unitscan:RequestClearTargets() end },

        { "Alerts", "__s_alerts", "section", "alerts" },
        { "Play Alert Sound", "alertSound", "boolean" },
        { "Flash Screen", "screenFlash", "boolean" },
        { "Show Found Unit Popup", "showAlert", "boolean" },
        { "Auto Target", "autoTarget", "boolean" },
        { "Add Marker on Target", "addMarkerOnTarget", "boolean" },
        { "Re-alert Cooldown (Minutes)", "reAlertMinutes", "slider", 1, 10, 1 },
    },
})

function M:Config()
    if OB.profile and OB.profile.modules then
        return OB.profile.modules.unitscan or self.defaults
    end
    return self.defaults
end

local function trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function upper(text)
    if strupper then return strupper(text) end
    return string.upper(text)
end

function M:TargetText()
    if not EquadisClassicOverhaulDB then return "" end
    return EquadisClassicOverhaulDB.unitScanTargets or ""
end

function M:ReadTargets()
    self.targets = {}
    self.targetKeys = {}
    self.seen = self.seen or {}
    self.cooldownUntil = self.cooldownUntil or {}

    for entry in string.gfind(self:TargetText(), "[^,]+") do
        local name = trim(entry)
        if name ~= "" then
            local key = upper(name)
            if not self.targets[key] then
                self.targets[key] = name
                table.insert(self.targetKeys, key)
            end
        end
    end

    table.sort(self.targetKeys, function(a, b)
        return string.lower(self.targets[a]) < string.lower(self.targets[b])
    end)
end

function M:WriteTargets()
    if not EquadisClassicOverhaulDB then return end

    local names = {}
    self.targetKeys = {}

    for key, name in pairs(self.targets or {}) do
        table.insert(self.targetKeys, key)
        table.insert(names, name)
    end

    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    table.sort(self.targetKeys, function(a, b)
        return string.lower(self.targets[a]) < string.lower(self.targets[b])
    end)

    EquadisClassicOverhaulDB.unitScanTargets = table.concat(names, ", ")
end

function M:TargetCount()
    self:ReadTargets()
    return table.getn(self.targetKeys)
end

function M:InputTarget()
    local cfg = self:Config()

    -- Action buttons do not make a focused 1.12 EditBox fire OnEnterPressed.
    -- Prefer the text the user can currently see in UnitScan's target box and
    -- commit it before Add/Remove reads it, so clicking either button behaves
    -- exactly like pressing Enter first. If the options page is not built, the
    -- stored config remains the fallback used by slash/programmatic callers.
    local box = OB.widgets and OB.widgets["module:unitscan:targetInput"]
    if box and box.GetText then
        local text = box:GetText() or ""
        cfg.targetInput = text
        return trim(text)
    end

    return trim(cfg.targetInput or "")
end

function M:ClearInput()
    local cfg = self:Config()
    cfg.targetInput = ""
    if OB.RefreshPanel then OB.RefreshPanel() end
end

function M:EnsureRunning()
    if not OB.profile or not OB.profile.modulesEnabled then return end
    if OB.profile.modulesEnabled.unitscan ~= false then return end

    -- Adding a scan target is an explicit request to use UnitScan.  Earlier
    -- builds let the list change while the feature remained disabled on the
    -- Modules page, so nothing ever scanned and there was no feedback why.
    OB.profile.modulesEnabled.unitscan = true
    if OB.BindSlots then OB.BindSlots() end
    Say("enabled.")
end

function M:AddTarget(name, quiet)
    name = trim(name)
    if name == "" then
        if not quiet then Say("enter a target name first.") end
        return false
    end

    self:ReadTargets()
    local key = upper(name)

    if self.targets[key] then
        if not quiet then Say(name .. " is already in the scan list.") end
        return false
    end

    self.targets[key] = name
    self.seen[key] = nil
    self.cooldownUntil[key] = nil
    self:WriteTargets()
    self:EnsureRunning()

    if not quiet then Say("+ " .. name) end
    return true
end

function M:RemoveTarget(name, quiet)
    name = trim(name)
    if name == "" then
        if not quiet then Say("enter a target name first.") end
        return false
    end

    self:ReadTargets()
    local key = upper(name)
    local old = self.targets[key]

    if not old then
        if not quiet then Say(name .. " is not in the scan list.") end
        return false
    end

    self.targets[key] = nil
    self.seen[key] = nil
    self.cooldownUntil[key] = nil
    self:WriteTargets()

    if not quiet then Say("- " .. old) end
    return true
end

function M:AddInputTarget()
    local name = self:InputTarget()
    if self:AddTarget(name, false) then self:ClearInput() end
end

function M:RemoveInputTarget()
    local name = self:InputTarget()
    if self:RemoveTarget(name, false) then self:ClearInput() end
end

function M:ClearTargets()
    self.targets = {}
    self.targetKeys = {}
    self.seen = {}
    self.cooldownUntil = {}
    if EquadisClassicOverhaulDB then EquadisClassicOverhaulDB.unitScanTargets = "" end
    Say("scan list cleared.")
end

function M:EnsureClearPopup()
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    if StaticPopupDialogs.EQUADIS_UNITSCAN_CLEAR_ALL then return true end

    StaticPopupDialogs.EQUADIS_UNITSCAN_CLEAR_ALL = {
        text = "Clear all UnitScan targets?",
        button1 = ACCEPT or "Yes",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            local m = EquadisClassicOverhaul and EquadisClassicOverhaul.modules
                    and EquadisClassicOverhaul.modules.unitscan
            if m then
                m:ClearTargets()
                if EquadisClassicOverhaul.RefreshPanel then
                    EquadisClassicOverhaul.RefreshPanel()
                end
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }

    return true
end

function M:RequestClearTargets()
    local count = self:TargetCount()
    if count == 0 then
        Say("scan list is already empty.")
        return
    end

    if self:EnsureClearPopup() then
        StaticPopupDialogs.EQUADIS_UNITSCAN_CLEAR_ALL.text =
                "Clear all " .. count .. " UnitScan target"
                .. (count == 1 and "" or "s") .. "?"
        StaticPopup_Show("EQUADIS_UNITSCAN_CLEAR_ALL")
        return
    end

    -- Very old/custom clients without Blizzard's popup helper keep the data
    -- untouched rather than turning a destructive button into an instant clear.
    Say("confirmation popup is unavailable; targets were not cleared.")
end

function M:ToggleTarget(name)
    name = trim(name)
    if name == "" then return end

    self:ReadTargets()
    local key = upper(name)

    if self.targets[key] then
        self:RemoveTarget(name, false)
    else
        self:AddTarget(name, false)
    end

    if OB.RefreshPanel then OB.RefreshPanel() end
end

function M:PrintTargets()
    self:ReadTargets()
    if table.getn(self.targetKeys) == 0 then
        Say("no active scan targets.")
        return
    end

    Say("active scan targets:")
    for i = 1, table.getn(self.targetKeys) do
        OB.Raw("  " .. self.targets[self.targetKeys[i]])
    end
end

function M:AfterSet(key)
    if key == "unitScanTargets" then
        self:ReadTargets()
        self:WriteTargets() -- trim whitespace and collapse duplicates
    end
end

-- ---------------------------------------------------------------------------
-- quiet exact targeting
-- ---------------------------------------------------------------------------

local function exactName(a, b)
    return a and b and upper(a) == upper(b)
end

function M:CurrentTargetName()
    if type(UnitName) ~= "function" then return nil end
    return UnitName("target")
end

function M:RestoreTarget(beforeName, afterName)
    -- A failed/partial probe must not leave some unrelated D/T/etc. unit
    -- selected.  TargetByName without a working exact-match implementation can
    -- legitimately pick the nearest prefix match on 1.12-derived clients.
    if exactName(beforeName, afterName) then return end

    if beforeName then
        if type(TargetLastTarget) == "function" then
            TargetLastTarget()
        elseif type(TargetByName) == "function" then
            -- Last-resort restoration for custom clients without TargetLastTarget.
            pcall(TargetByName, beforeName, true)
        end
    elseif afterName and type(ClearTarget) == "function" then
        ClearTarget()
    end
end

function M:CallTargetAPI(fn, name)
    if type(fn) ~= "function" then return false end

    -- Match the vanilla UnitScan technique as narrowly as possible: suppress
    -- only the UI error callback generated by a failed name lookup.  Earlier
    -- ECO builds also replaced the global PlaySound function for every probe;
    -- doing that repeatedly is unnecessary and can interfere with unrelated UI
    -- work dispatched synchronously by the target-change event.
    local errors = UIErrorsFrame_OnEvent
    local quiet = function() end

    UIErrorsFrame_OnEvent = quiet
    local ok = pcall(fn, name, true)
    UIErrorsFrame_OnEvent = errors

    return ok and true or false
end

function M:QuietTarget(name)
    if type(UnitName) ~= "function" then return false end

    -- If the player has already selected the exact mob, that is stronger proof
    -- than any name-search API and also covers clients whose TargetByName is
    -- patched or partially broken.
    local current = self:CurrentTargetName()
    if exactName(current, name) then return true end

    -- TargetByName(name, true) is the vanilla 1.12 primitive UnitScan is built
    -- around. Do NOT use TargetUnit here: TargetUnit expects a unit token on
    -- vanilla clients and custom implementations can interpret arbitrary text
    -- unpredictably, causing repeated/fuzzy retargeting.
    if type(TargetByName) ~= "function" then return false end

    local before = self:CurrentTargetName()
    self:CallTargetAPI(TargetByName, name)
    local after = self:CurrentTargetName()

    if exactName(after, name) then return true end

    -- A custom client may still ignore the exact-match argument. Never let a
    -- fuzzy result survive the probe. If the call actually selected a wrong
    -- unit, the client's exact-name primitive is unsafe for passive scanning;
    -- disable automatic probes for this session rather than flickering targets
    -- every 0.1 seconds. Direct target/mouseover detection remains available.
    self:RestoreTarget(before, after)
    if after and not exactName(after, name) then
        self.nameProbeUnsafe = true
        if not self.nameProbeWarningShown then
            self.nameProbeWarningShown = true
            Say("exact name targeting is unreliable on this client; automatic probes paused. Target/mouseover detection is still active.")
        end
    end
    return false
end

function M:ReAlertSeconds()
    local minutes = tonumber(self:Config().reAlertMinutes) or 2
    if minutes < 1 then minutes = 1 end
    return minutes * 60
end

function M:TargetReady(key, now)
    self.seen = self.seen or {}
    self.cooldownUntil = self.cooldownUntil or {}

    local untilAt = self.cooldownUntil[key]
    if untilAt and now < untilAt then return false end

    -- The mute window has expired. Re-arm this watched name automatically;
    -- the user should never have to remove/re-add short-respawn mobs manually.
    if untilAt then
        self.cooldownUntil[key] = nil
        self.seen[key] = nil
    end

    return not self.seen[key]
end

function M:KnownUnitHit()
    if type(UnitName) ~= "function" then return false end
    if not self.targets then self:ReadTargets() end

    -- These two tokens give us a zero-risk fallback even if the client's
    -- TargetByName implementation is faulty.  Manually targeting or merely
    -- mousing over a watched rare will still trigger the alert immediately.
    local units = { "target", "mouseover" }
    for i = 1, table.getn(units) do
        local name = UnitName(units[i])
        if name then
            local key = upper(name)
            local watched = self.targets[key]
            if watched and self:TargetReady(key, GetTime()) then
                self:Found(key, name, false)
                return true
            end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- alert presentation
-- ---------------------------------------------------------------------------

function M:EnsureFlash()
    if self.flash then return self.flash end

    local f = CreateFrame("Frame", "EquadisClassicOverhaulUnitScanFlash", UIParent)
    f:SetAllPoints(UIParent)
    -- Keep the red world flash underneath normal UI elements.  Putting this
    -- on FULLSCREEN_DIALOG tinted the action bars themselves red, which looked
    -- like the stock out-of-range feedback.
    f:SetFrameStrata("LOW")
    if f.EnableMouse then f:EnableMouse(false) end
    f:SetAlpha(0)
    f:Hide()

    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(f)
    t:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    t:SetBlendMode("ADD")

    self.flash = f
    return f
end

function M:EnsureAlert()
    if self.alert then return self.alert end

    local f = CreateFrame("Button", "EquadisClassicOverhaulUnitScanAlert", UIParent)
    f:SetWidth(300)
    f:SetHeight(72)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    -- Always keep the interactive alert above the non-interactive flash and
    -- make mouse handling explicit for older/custom 1.12 clients.
    f:SetFrameStrata("TOOLTIP")
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForClicks then f:RegisterForClicks("LeftButtonUp") end
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
    f:SetBackdropBorderColor(0.95, 0.55, 0.08, 1)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
    f.title:SetText("|cffffd100Unit Found!|r")

    f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.nameText:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.nameText:SetPoint("RIGHT", f, "RIGHT", -34, 0)
    f.nameText:SetJustifyH("LEFT")

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 8)
    f.hint:SetText("Click to target + star  |  Ctrl-drag to move")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    f.close:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnClick", function()
        if f.suppressClick then
            -- A Ctrl-drag release can skip Button:OnClick on some 1.12 clients.
            -- Do not leave a permanent stale flag that eats the next real click.
            if not f.suppressClickUntil or GetTime() <= f.suppressClickUntil then
                f.suppressClick = nil
                f.suppressClickUntil = nil
                return
            end
            f.suppressClick = nil
            f.suppressClickUntil = nil
        end
        if f.foundName and M:QuietTarget(f.foundName) then
            M:ApplyStarMarker()
        end
    end)

    f:SetScript("OnMouseDown", function()
        if IsControlKeyDown() then
            f.moving = true
            f.suppressClick = true
            f.suppressClickUntil = GetTime() + 0.25
            f:StartMoving()
        elseif f.suppressClickUntil and GetTime() > f.suppressClickUntil then
            -- Clean up a drag suppression flag if the client never emitted the
            -- corresponding OnClick after the previous drag.
            f.suppressClick = nil
            f.suppressClickUntil = nil
        end
    end)

    f:SetScript("OnMouseUp", function()
        if f.moving then
            f.moving = nil
            f:StopMovingOrSizing()
        end
    end)

    self.alert = f
    return f
end

function M:PlayAlertSound(now)
    local cfg = self:Config()
    if not cfg.alertSound or type(PlaySound) ~= "function" then return end

    if self.lastSound and now - self.lastSound < 8 then return end
    PlaySound("RaidWarning")
    self.lastSound = now
end

function M:StartFlash(now)
    if not self:Config().screenFlash then return end
    local f = self:EnsureFlash()
    self.flashStarted = now
    f:SetAlpha(0)
    f:Show()
end

function M:UpdateFlash(now)
    if not self.flashStarted or not self.flash then return end

    local elapsed = now - self.flashStarted
    if elapsed >= 3.6 then
        self.flashStarted = nil
        self.flash:SetAlpha(0)
        self.flash:Hide()
        return
    end

    local cycle = elapsed - math.floor(elapsed / 1.2) * 1.2
    local alpha
    if cycle < 0.20 then
        alpha = cycle / 0.20
    elseif cycle < 0.55 then
        alpha = 1
    else
        alpha = 1 - ((cycle - 0.55) / 0.65)
    end

    if alpha < 0 then alpha = 0 end
    if alpha > 0.70 then alpha = 0.70 end
    self.flash:SetAlpha(alpha)
end

function M:ShowFoundAlert(name)
    if not self:Config().showAlert then return end
    local f = self:EnsureAlert()
    f.foundName = name
    f.nameText:SetText(name)
    f.suppressClick = nil
    f.suppressClickUntil = nil
    f:Show()
    if f.Raise then f:Raise() end
end

function M:ApplyStarMarker()
    if type(SetRaidTarget) ~= "function" then return false end
    if type(UnitName) ~= "function" or not UnitName("target") then return false end

    -- Raid marker 1 is the yellow star.  In groups the server may reject this
    -- when the player lacks marker permissions, so keep the popup click safe.
    local ok = pcall(SetRaidTarget, "target", 1)
    return ok and true or false
end

function M:Alert(name, isTest)
    local now = GetTime()

    self:PlayAlertSound(now)
    self:StartFlash(now)
    self:ShowFoundAlert(name)

    if not isTest then
        if type(FlashClientIcon) == "function" then FlashClientIcon() end
        Say("found |cffffd100" .. name .. "|r.")
    end
end


-- ---------------------------------------------------------------------------
-- scanning
-- ---------------------------------------------------------------------------

function M:Found(key, name, fromProbe)
    local cfg = self:Config()

    -- TargetByName is the only passive discovery primitive available to a
    -- vanilla 1.12 addon, so an automatic scan briefly has to select the unit
    -- in order to prove that it exists.  Auto Target controls whether that
    -- discovered unit remains selected.  With the option off (the default),
    -- immediately clear only targets created by our probe; never clear a unit
    -- the player selected themselves.
    if fromProbe and not cfg.autoTarget and exactName(self:CurrentTargetName(), name) then
        if type(ClearTarget) == "function" then ClearTarget() end
    elseif cfg.autoTarget and not exactName(self:CurrentTargetName(), name) then
        self:QuietTarget(name)
    end

    -- Optional automatic marker application is deliberately separate from
    -- Auto Target.  It only marks when the watched unit is actually the
    -- player's current target, so a mouseover-only discovery never marks some
    -- unrelated target. Clicking the found-unit popup still targets + stars
    -- unconditionally, matching the explicit popup behaviour.
    if cfg.addMarkerOnTarget and exactName(self:CurrentTargetName(), name) then
        self:ApplyStarMarker()
    end

    -- Keep watched names registered. A discovery only mutes that specific name
    -- for a short window; after the cooldown it automatically becomes eligible
    -- again. This preserves rare-mob usage while also supporting creatures with
    -- ten-minute-ish respawns such as Devilsaurs.
    self.seen = self.seen or {}
    self.cooldownUntil = self.cooldownUntil or {}
    self.seen[key] = true
    self.cooldownUntil[key] = GetTime() + self:ReAlertSeconds()

    self:Alert(name, false)
end

function M:Scan(now)
    if not self.targetKeys then self:ReadTargets() end
    if table.getn(self.targetKeys) == 0 then return end

    -- First trust actual unit tokens.  This catches a watched unit the player
    -- targets or hovers even on servers with a broken exact-name search API.
    if self:KnownUnitHit() then return end

    if type(TargetByName) ~= "function" then return end
    if self.nameProbeUnsafe then return end

    -- Never run name-target probes while the alert is on screen.  The old code
    -- kept probing other watched names behind the popup, which could generate
    -- PLAYER_TARGET_CHANGED traffic at the same moment the user clicked it.
    if self.alert and self.alert.IsShown and self.alert:IsShown() then return end

    -- UnitScan's only way to discover an arbitrary nearby named unit on 1.12 is
    -- to use the targeting API. Never steal an active target from the player.
    -- Actual target/mouseover matches were already handled by KnownUnitHit().
    if self:CurrentTargetName() then return end

    -- Keep target/mouseover checks responsive at 10 Hz, but passive name probes
    -- are far more invasive: they can cause PLAYER_TARGET_CHANGED/range updates
    -- even when a custom client ultimately reports no target.  Two probes per
    -- second is still effectively instant for rare/Devilsaur discovery without
    -- hammering the action bar state machine.
    now = now or GetTime()
    if self.lastProbe and now - self.lastProbe < PROBE_INTERVAL then return end
    self.lastProbe = now

    for i = 1, table.getn(self.targetKeys) do
        local key = self.targetKeys[i]
        local name = self.targets[key]

        -- A watched name is probed only when its per-target cooldown has
        -- expired. This prevents repeated Auto Target / sound / popup spam.
        if name and self:TargetReady(key, GetTime()) then
            local hit = self:QuietTarget(name)
            if hit then
                local foundName = UnitName("target") or name
                self:Found(key, foundName, true)
                -- Stop immediately after a real hit. Continuing through the
                -- list could replace the unit we just found with another probe.
                return
            end
        end
    end
end

function M:OnUpdate(now)
    self:UpdateFlash(now)

    if not self.lastCheck or now - self.lastCheck >= CHECK_INTERVAL then
        self.lastCheck = now
        self:Scan(now)
    end
end

function M:OnBind()
    self:ReadTargets()
    self.lastCheck = 0
    self.lastProbe = nil
    self.nameProbeUnsafe = false
    self.nameProbeWarningShown = false
    self.seen = self.seen or {}
    self.cooldownUntil = self.cooldownUntil or {}
    self.tickly = true
end

function M:OnUnbind()
    self.tickly = false
    self.flashStarted = nil
    if self.flash then
        self.flash:SetAlpha(0)
        self.flash:Hide()
    end
    if self.alert then self.alert:Hide() end
end

-- Keep the familiar upstream command while the settings page remains the main
-- way to maintain the list. The second spelling avoids a collision while the
-- standalone unitscan addon is still installed during migration/testing.
SLASH_EQOUNITSCAN1 = "/unitscan"
SLASH_EQOUNITSCAN2 = "/equnitscan"
SlashCmdList.EQOUNITSCAN = function(parameter)
    local name = trim(parameter)
    if name == "" then
        M:PrintTargets()
    elseif string.lower(name) == "clear" then
        M:ClearTargets()
        if OB.RefreshPanel then OB.RefreshPanel() end
    else
        M:ToggleTarget(name)
    end
end
