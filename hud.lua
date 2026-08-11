--[[ Equadis' OmniBars :: hud

  The driver. Binds modules to slots, routes events, and owns the single
  OnUpdate.

  Modules never draw from an event handler. They mutate their own state and call
  OB.SetDirty; the redraw is batched here on the next frame. That is ShaguDPS's
  dirty-flag decoupling applied to a HUD, and it is why a module that only
  changes on an event -- combo points, health -- costs nothing per frame.
  RogueBars recomputed every bar every frame regardless.
]]--

local OB = EquadisOmniBars

local floor = math.floor

-- replaced by options.lua once the panel exists
function OB.RefreshPanel() end

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

OB.inCombat = false
OB.inStealth = false
OB.testMode = false

--[[ Shared scratch space for the test cycle. Every module reads its value
     through its own GetValue, which checks OB.testMode, so simulated numbers are
     substituted in one place per module and the rendering path stays byte for
     byte identical to live play. ]]--
OB.test = {}

local stealthTextures = {
    ["Interface\\Icons\\Ability_Stealth"] = true,
    ["Interface\\Icons\\Ability_Ambush"] = true,
    ["Interface\\Icons\\ability_druid_prowl"] = true,
}

function OB.IsStealthed()
    return OB.HasPlayerBuff(stealthTextures)
end

-- ---------------------------------------------------------------------------
-- binding
-- ---------------------------------------------------------------------------

function OB.SetDirty(m)
    if m then m.needsDraw = true end
    OB.hud.needsDraw = true
end

--[[ Resolve every slot's occupant and wire it up.

     Frames are built once and reused: a module that gets unbound is hidden, not
     destroyed, so switching a slot back and forth costs nothing.

     Only the events some bound module actually asked for are registered. This is
     RogueBars' RegisterEvents -- a hardcoded fifteen-line if/else that either
     registered everything or nothing depending on the class -- generalised into
     a table walk. ]]--
function OB.BindSlots()
    for slotId, m in pairs(OB.bound) do
        if m.OnUnbind then m:OnUnbind() end
        if m.frame then m.frame:Hide() end
        m.slotId = nil
        OB.bound[slotId] = nil
    end

    OB.eventMap = {}

    for i = 1, table.getn(OB.barOrder) do
        local slotId = OB.barOrder[i]
        local id = OB.Occupant(slotId)
        local m = id and OB.modules[id]

        --[[ There was a guard here against one module being bound to two bars.
             It is unreachable now: a module names exactly one bar, so two bars
             cannot resolve to it. The invariant is structural rather than
             defended -- which is the good kind. ]]--

        if m then
            local slot = OB.profile.slots[slotId]
            m.slotId = slotId

            if not m.frame then
                if m.renders == "segments" then
                    m.frame = OB.CreateSegments("EqOB_" .. m.id, OB.container,
                            m.segments or 5)
                    for s = 1, m.frame.count do
                        OB.AttachMouse(m.frame.bars[s], slotId)
                    end
                else
                    m.frame = OB.CreateBar("EqOB_" .. m.id, OB.container)
                    OB.AttachMouse(m.frame, slotId)
                end
            else
                -- the frame may have been bound to a different slot last time
                if m.renders == "segments" then
                    for s = 1, m.frame.count do
                        OB.dragMap[m.frame.bars[s]] = slotId
                    end
                else
                    OB.dragMap[m.frame] = slotId
                end
            end

            OB.bound[slotId] = m

            for e = 1, table.getn(m.events) do
                local ev = m.events[e]
                OB.eventMap[ev] = OB.eventMap[ev] or {}
                table.insert(OB.eventMap[ev], m)
            end

            if m.OnBind then m:OnBind(slot) end
            m.needsDraw = true
        end
    end

    OB.events:UnregisterAllEvents()
    for ev in pairs(OB.eventMap) do OB.events:RegisterEvent(ev) end
    for i = 1, table.getn(OB.coreEvents) do
        OB.events:RegisterEvent(OB.coreEvents[i])
    end

    OB.hud.needsDraw = true
end

-- ---------------------------------------------------------------------------
-- refresh
-- ---------------------------------------------------------------------------

--[[ Re-apply appearance to everything and queue a redraw.

     `force` re-styles as well as redrawing. Styling is cheap and this is not a
     per-frame path, so almost every caller passes true -- that is what makes a
     texture, border or size change land instantly. ]]--
function OB.Refresh(force)
    if not OB.profile then return end

    if force then
        OB.ApplyScale()

        for slotId, m in pairs(OB.bound) do
            local slot = OB.profile.slots[slotId]

            if m.renders == "segments" then
                OB.StyleSegments(m.frame, slot)
            else
                OB.StyleBar(m.frame, slot)
            end

            if m.OnStyle then m:OnStyle(slot) end
            m.needsDraw = true
        end

        OB.ApplyPositions()
        OB.UpdateMoveControls()
    end

    OB.hud.needsDraw = true
    OB.Toggle()
    OB.Fire("refresh")
end

--[[ Show or hide the whole HUD.

     Priority: the master switch, then hide-when-stealthed, then
     hide-out-of-combat. Test mode overrides all of it -- the preview must not be
     hidden by the very visibility rules it exists to help you set up. ]]--
function OB.Toggle()
    if not OB.profile then return end

    local visible = OB.profile.show and true or false

    if visible and OB.profile.hideDead and UnitIsDeadOrGhost("player") then
        visible = false
    end
    if visible and OB.profile.hideStealth and OB.inStealth then
        visible = false
    end
    if visible and OB.profile.hideOOC and not OB.inCombat then
        visible = false
    end

    if OB.testMode then visible = true end

    if visible then
        OB.container:Show()
    else
        OB.container:Hide()
    end

    -- per-bar visibility: a bar can be switched off without unbinding its module
    for slotId, m in pairs(OB.bound) do
        if OB.profile.slots[slotId].show then
            m.frame:Show()
        else
            m.frame:Hide()
        end
    end

    OB.SetMouseEnabled(not OB.profile.locked)
    OB.UpdateMoveControls()
end

-- ---------------------------------------------------------------------------
-- test mode
-- ---------------------------------------------------------------------------

function OB.SetTestMode(on)
    if on == OB.testMode then return end

    OB.testMode = on and true or false
    OB.test.startedAt = GetTime()

    for slotId, m in pairs(OB.bound) do
        if OB.testMode then
            if m.TestStart then m:TestStart(OB.test.startedAt) end
        else
            if m.TestStop then m:TestStop() end
        end
        m.needsDraw = true
    end

    OB.Refresh(true)
    OB.RefreshPanel()
end

function OB.ToggleTestMode()
    OB.SetTestMode(not OB.testMode)
end

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------

local coreHandlers = {}

coreHandlers.VARIABLES_LOADED = function()
    OB.LoadConfig()
    OB.CreateMover()
    OB.BindSlots()
    OB.Refresh(true)

    --[[ RogueBars draws the same cluster, so both running at once shows two of
         everything. Say so once and leave it at that: forbidding the pair would
         make it impossible to compare them side by side, which is exactly what
         this version is for. ]]--
    if IsAddOnLoaded("RogueBars") then
        OB.Print("RogueBars is also loaded -- you will see two sets of bars. "
                .. "Disable it when you are done comparing.")
    end
end

coreHandlers.PLAYER_ENTERING_WORLD = function()
    OB.inCombat = UnitAffectingCombat("player") and true or false
    OB.inStealth = OB.IsStealthed()
    OB.Refresh(true)
end

coreHandlers.PLAYER_REGEN_DISABLED = function()
    OB.inCombat = true
    OB.Toggle()
end

coreHandlers.PLAYER_REGEN_ENABLED = function()
    OB.inCombat = false
    OB.Toggle()
end

-- stealth can start or stop without any other signal, and a druid changing form
-- reaches here too
local function auraChanged()
    OB.inStealth = OB.IsStealthed()
    OB.Toggle()
end

coreHandlers.PLAYER_AURAS_CHANGED = auraChanged
coreHandlers.UPDATE_SHAPESHIFT_FORMS = auraChanged
coreHandlers.PLAYER_DEAD = auraChanged
coreHandlers.PLAYER_ALIVE = auraChanged
coreHandlers.PLAYER_UNGHOST = auraChanged

OB.events:SetScript("OnEvent", function()
    local list = OB.eventMap[event]

    if list then
        for i = 1, table.getn(list) do
            local m = list[i]
            -- 'event' and 'arg1' are still in scope for the module
            if m.OnEvent then m:OnEvent() end
        end
    end

    if coreHandlers[event] then coreHandlers[event]() end
end)

for i = 1, table.getn(OB.coreEvents) do
    OB.events:RegisterEvent(OB.coreEvents[i])
end

-- ---------------------------------------------------------------------------
-- the single OnUpdate
-- ---------------------------------------------------------------------------

OB.hud:SetScript("OnUpdate", function()
    if not OB.profile then return end

    local now = GetTime()

    OB.UpdateDrag()

    if OB.testMode then
        for slotId, m in pairs(OB.bound) do
            if m.TestStep then m:TestStep(now) end
        end
    end

    -- modules that animate continuously: a sweeping swing bar, a ticker spark
    for slotId, m in pairs(OB.bound) do
        if m.tickly and m.OnUpdate then m:OnUpdate(now) end
    end

    if this.needsDraw then
        this.needsDraw = nil
        for slotId, m in pairs(OB.bound) do
            if m.needsDraw then
                m.needsDraw = nil
                if m.OnDraw then m:OnDraw() end
            end
        end
    end
end)
