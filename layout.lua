--[[ Equadis' OmniBars :: layout

  The container, slot placement, collision, dragging and the movement overlay.

  Nothing here knows what a slot contains -- it moves rectangles. Which module
  draws into a rectangle is hud.lua's problem.

  Two rules carried over from RogueBars, both of which cost real debugging time:

  The container is an anchor, not a box. RogueBars pinned it at a fixed 200x56
  and its handover notes warn in capitals never to resize it: it is centre/bottom
  anchored, so growing it shifts its TOPLEFT -- the point every slot hangs from
  -- and moving one unjoined slot pushed the others the opposite way, while
  moving the bottom one was exactly cancelled. With six slots reaching 115px
  *above* that corner the rect bounds nothing it draws anyway, so it is 1x1 here.
  The rule becomes "the anchor is a point", which cannot be violated by accident.

  There is exactly one movement code path. The X/Y sliders, the arrow buttons and
  the mouse all call OB.NudgeSlot, and every one of them shares OB.POS_MIN/MAX.
  Two ways to move a bar is two chances for them to disagree.
]]--

local OB = EquadisOmniBars

local floor = math.floor

-- mouse drag state. Positions are computed from a snapshot taken at drag start,
-- so rounding never accumulates over a long drag.
local drag = {
    active = false,
    slot = nil,
    cursorX = 0,
    cursorY = 0,
    start = {},
}

-- ---------------------------------------------------------------------------
-- container
-- ---------------------------------------------------------------------------

OB.container = CreateFrame("Frame", "EquadisOmniBarsAnchor", UIParent)
OB.container:SetWidth(1)
OB.container:SetHeight(1)
OB.container:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)

function OB.ApplyScale()
    OB.container:SetScale(OB.profile.scale)
end

--[[ Write every slot's offset to its frame.

     The container's size is re-asserted on every call. It is a point, and any
     future code that grows it would silently reintroduce the drift bug above. ]]--
function OB.ApplyPositions()
    if not OB.profile then return end

    OB.container:SetWidth(1)
    OB.container:SetHeight(1)

    for i = 1, table.getn(OB.slotOrder) do
        local slotId = OB.slotOrder[i]
        local m = OB.bound[slotId]

        if m and m.frame then
            local slot = OB.profile.slots[slotId]
            m.frame:ClearAllPoints()
            m.frame:SetPoint("TOPLEFT", OB.container, "TOPLEFT", slot.x, slot.y)
        end
    end

    -- keep the overlay glued to its target while bars move under it
    if OB.moveTarget and OB.mover and OB.mover:IsVisible() then
        OB.PositionMover()
    end
end

-- ---------------------------------------------------------------------------
-- collision
-- ---------------------------------------------------------------------------

-- a slot only participates in collision when something is actually drawn in it
local function slotActive(slotId)
    if not OB.bound[slotId] then return false end
    return not OB.profile.slots[slotId].hide
end

--[[ True when placing `slotId` at (x, y) would overlap another drawn slot.

     Rects are expanded by the border pad so border art participates: two bars
     may sit exactly edge to edge, they just cannot stack. The test is strict
     overlap for that reason.

     Hidden and unoccupied slots are skipped -- in RogueBars an invisible element
     still blocked a visible one, which looked like the bar had simply stopped
     moving for no reason. ]]--
function OB.SlotCollides(slotId, x, y)
    if not OB.profile or OB.profile.allowOverlap then return false end

    local slots = OB.profile.slots
    local pad = OB.BorderPad()
    local el = slots[slotId]

    local aL, aR = x - pad, x + el.w + pad
    local aT, aB = y + pad, y - el.h - pad

    for i = 1, table.getn(OB.slotOrder) do
        local otherId = OB.slotOrder[i]
        if otherId ~= slotId and slotActive(otherId) then
            local other = slots[otherId]
            local bL, bR = other.x - pad, other.x + other.w + pad
            local bT, bB = other.y + pad, other.y - other.h - pad

            if (aL < bR) and (aR > bL) and (aB < bT) and (aT > bB) then
                return true
            end
        end
    end

    return false
end

--[[ After the border style grows, slots that sat closer together than the new
     border footprint would show overlapping border art. Drop each offending slot
     straight down until its border just touches the one above -- touching is
     allowed, stacking is not. ]]--
function OB.ResolveBorderOverlap()
    if not OB.profile or OB.profile.allowOverlap then return end

    local pad = OB.BorderPad()
    if pad == 0 then return end

    local slots = OB.profile.slots

    local order = {}
    for i = 1, table.getn(OB.slotOrder) do
        local id = OB.slotOrder[i]
        if slotActive(id) then table.insert(order, id) end
    end
    table.sort(order, function(a, b) return slots[a].y > slots[b].y end)

    for i = 2, table.getn(order) do
        local el = slots[order[i]]
        for j = 1, i - 1 do
            local above = slots[order[j]]
            if ((el.x - pad) < (above.x + above.w + pad))
                    and ((el.x + el.w + pad) > (above.x - pad))
                    and ((el.y + pad) > (above.y - above.h - pad))
                    and ((el.y - el.h - pad) < (above.y + pad)) then
                local limit = above.y - above.h - (pad * 2)
                if el.y > limit then el.y = OB.ClampCoord(limit) end
            end
        end
    end
end

--[[ Re-stack every drawn slot from the topmost one downwards, at their current
     heights plus room for borders.

     Offered as a button rather than done automatically. Automatic reflow is the
     bug class the fixed anchor exists to prevent, and it would break the promise
     that two characters on one profile line up: the moment their occupancy
     differs, an automatic stack would put their bars in different places. ]]--
function OB.RestackSlots()
    local slots = OB.profile.slots
    local pad = OB.BorderPad()

    local order = {}
    for i = 1, table.getn(OB.slotOrder) do
        local id = OB.slotOrder[i]
        if slotActive(id) then table.insert(order, id) end
    end
    table.sort(order, function(a, b) return slots[a].y > slots[b].y end)

    local count = table.getn(order)
    if count == 0 then return end

    local y = slots[order[1]].y

    for i = 1, count do
        local el = slots[order[i]]
        el.y = OB.ClampCoord(y)
        y = y - el.h - (pad * 2)
    end

    OB.ApplyPositions()
end

-- ---------------------------------------------------------------------------
-- movement
-- ---------------------------------------------------------------------------

--[[ Move a slot by a whole-pixel offset, honouring Join.

     This is the single movement code path: the X/Y sliders, the arrow buttons
     and dragging all end up here. ]]--
function OB.NudgeSlot(slotId, dx, dy)
    if not OB.profile then return end
    local slots = OB.profile.slots
    if not slots[slotId] then return end

    if not OB.profile.join then
        local nx = OB.ClampCoord(slots[slotId].x + dx)
        local ny = OB.ClampCoord(slots[slotId].y + dy)

        --[[ Refuse a step that would create an overlap. A slot that already
             overlaps may always move, so it can escape. Joined moves keep
             relative positions and can never create one, hence only this
             branch checks. ]]--
        if OB.SlotCollides(slotId, nx, ny)
                and not OB.SlotCollides(slotId, slots[slotId].x, slots[slotId].y) then
            OB.RefreshPanel()
            return
        end

        slots[slotId].x = nx
        slots[slotId].y = ny
    else
        -- shrink the shared step so no slot leaves the allowed range, which
        -- keeps the relative spacing intact
        for id, el in pairs(slots) do
            if (el.x + dx) > OB.POS_MAX then dx = OB.POS_MAX - el.x end
            if (el.x + dx) < OB.POS_MIN then dx = OB.POS_MIN - el.x end
            if (el.y + dy) > OB.POS_MAX then dy = OB.POS_MAX - el.y end
            if (el.y + dy) < OB.POS_MIN then dy = OB.POS_MIN - el.y end
        end

        for id, el in pairs(slots) do
            el.x = el.x + dx
            el.y = el.y + dy
        end
    end

    OB.ApplyPositions()
    OB.RefreshPanel()
end

-- set an absolute coordinate through the nudge path, so Join still applies
function OB.SetSlotCoord(slotId, axis, value)
    local slot = OB.profile.slots[slotId]
    if not slot then return end

    value = OB.ClampCoord(floor(value + 0.5))

    if axis == "x" then
        local delta = value - slot.x
        if delta ~= 0 then OB.NudgeSlot(slotId, delta, 0) end
    else
        local delta = value - slot.y
        if delta ~= 0 then OB.NudgeSlot(slotId, 0, delta) end
    end
end

--[[ The arrow overlay nudges whatever it targets. With Join on the target is the
     whole group, and NudgeSlot's joined branch moves every slot, so any slot id
     stands in for the group. ]]--
function OB.NudgeTarget(dx, dy)
    local target = OB.moveTarget
    if not target then return end
    if target == "ALL" then target = OB.slotOrder[1] end
    OB.NudgeSlot(target, dx, dy)
end

-- ---------------------------------------------------------------------------
-- dragging
-- ---------------------------------------------------------------------------

function OB.StartDrag(frame)
    if not OB.profile or OB.profile.locked then return end

    local slotId = OB.dragMap[frame]
    if not slotId then return end

    drag.active = true
    drag.slot = slotId
    drag.cursorX, drag.cursorY = GetCursorPosition()
    drag.start = {}

    for id, el in pairs(OB.profile.slots) do
        drag.start[id] = { x = el.x, y = el.y }
    end
end

function OB.StopDrag()
    if not drag.active then return end
    drag.active = false
    OB.RefreshPanel()
end

function OB.UpdateDrag()
    if not drag.active then return end

    local cx, cy = GetCursorPosition()
    local scale = OB.container:GetEffectiveScale()
    local dx = floor((cx - drag.cursorX) / scale + 0.5)
    local dy = floor((cy - drag.cursorY) / scale + 0.5)

    local slots = OB.profile.slots

    if not OB.profile.join then
        local id = drag.slot
        local nx = OB.ClampCoord(drag.start[id].x + dx)
        local ny = OB.ClampCoord(drag.start[id].y + dy)

        -- slide along the free axis when the full move would collide; a slot
        -- that already collides drags freely so it can escape
        if OB.SlotCollides(id, nx, ny)
                and not OB.SlotCollides(id, slots[id].x, slots[id].y) then
            if not OB.SlotCollides(id, nx, slots[id].y) then
                ny = slots[id].y
            elseif not OB.SlotCollides(id, slots[id].x, ny) then
                nx = slots[id].x
            else
                nx, ny = slots[id].x, slots[id].y
            end
        end

        slots[id].x = nx
        slots[id].y = ny
    else
        for id, el in pairs(slots) do
            local s = drag.start[id]
            if (s.x + dx) > OB.POS_MAX then dx = OB.POS_MAX - s.x end
            if (s.x + dx) < OB.POS_MIN then dx = OB.POS_MIN - s.x end
            if (s.y + dy) > OB.POS_MAX then dy = OB.POS_MAX - s.y end
            if (s.y + dy) < OB.POS_MIN then dy = OB.POS_MIN - s.y end
        end

        for id, el in pairs(slots) do
            el.x = drag.start[id].x + dx
            el.y = drag.start[id].y + dy
        end
    end

    OB.ApplyPositions()
end

--[[ Left-drag moves, right-click opens the arrow overlay. Attached by hud.lua
     when a frame is bound, and to every segment of a segmented slot so grabbing
     any pip drags the row. ]]--
function OB.AttachMouse(frame, slotId)
    OB.dragMap[frame] = slotId

    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then
            OB.StartDrag(this)
        elseif arg1 == "RightButton" then
            OB.ToggleMoveMode(this)
        end
    end)
    frame:SetScript("OnMouseUp", function() OB.StopDrag() end)
end

function OB.SetMouseEnabled(enabled)
    for frame in pairs(OB.dragMap) do
        frame:EnableMouse(enabled)
    end
end

-- ---------------------------------------------------------------------------
-- movement overlay
--
-- A single shared frame with the classic Blizzard scroll arrows around it,
-- shown on right-click and sized at runtime to wrap either one slot or the whole
-- joined layout. Each click moves exactly one pixel.
-- ---------------------------------------------------------------------------

local function arrowButton(parent, point, relativePoint, dx, dy, art, texCoord)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(16)
    button:SetHeight(16)
    button:SetPoint(point, parent, relativePoint, 0, 0)

    button:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. art .. "Button-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. art .. "Button-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. art .. "Button-Highlight", "ADD")

    -- the left and right arrows reuse the up arrow art, rotated with the eight
    -- argument SetTexCoord
    if texCoord then
        button:GetNormalTexture():SetTexCoord(unpack(texCoord))
        button:GetPushedTexture():SetTexCoord(unpack(texCoord))
        button:GetHighlightTexture():SetTexCoord(unpack(texCoord))
    end

    button:SetScript("OnClick", function() OB.NudgeTarget(dx, dy) end)
    return button
end

function OB.CreateMover()
    if OB.mover then return OB.mover end

    local mover = CreateFrame("Frame", "EquadisOmniBarsMover", OB.container)
    mover:SetFrameStrata("HIGH")
    mover:SetWidth(200)
    mover:SetHeight(56)
    mover:Hide()

    arrowButton(mover, "BOTTOM", "TOP", 0, 1, "Up")
    arrowButton(mover, "TOP", "BOTTOM", 0, -1, "Down")
    arrowButton(mover, "RIGHT", "LEFT", -1, 0, "Up", { 1, 0, 0, 0, 1, 1, 0, 1 })
    arrowButton(mover, "LEFT", "RIGHT", 1, 0, "Up", { 0, 1, 1, 1, 0, 0, 1, 0 })

    OB.mover = mover
    return mover
end

-- wrap one slot when unjoined, or the bounding box of every drawn slot when not
function OB.PositionMover()
    if not OB.profile or not OB.mover then return end

    local slots = OB.profile.slots
    local target = OB.moveTarget
    local left, right, top, bottom

    if target and target ~= "ALL" and slots[target] then
        local el = slots[target]
        left, right, top, bottom = el.x, el.x + el.w, el.y, el.y - el.h
    else
        for i = 1, table.getn(OB.slotOrder) do
            local id = OB.slotOrder[i]
            if slotActive(id) then
                local el = slots[id]
                if not left or el.x < left then left = el.x end
                if not right or (el.x + el.w) > right then right = el.x + el.w end
                if not top or el.y > top then top = el.y end
                if not bottom or (el.y - el.h) < bottom then bottom = el.y - el.h end
            end
        end
    end

    if not left then return end
    if (right - left) < 1 then right = left + 1 end
    if (top - bottom) < 1 then bottom = top - 1 end

    OB.mover:ClearAllPoints()
    OB.mover:SetPoint("TOPLEFT", OB.container, "TOPLEFT", left, top)
    OB.mover:SetWidth(right - left)
    OB.mover:SetHeight(top - bottom)
end

--[[ Right-clicking a bar toggles the overlay. Joined: one overlay wraps the
     whole layout whichever bar was clicked. Unjoined: it wraps that bar, and
     right-clicking another retargets it. ]]--
function OB.ToggleMoveMode(frame)
    if not OB.profile or OB.profile.locked then return end

    local slotId = OB.dragMap[frame]
    if not slotId then return end

    local target = slotId
    if OB.profile.join then target = "ALL" end

    if OB.moveTarget == target then
        OB.moveTarget = nil
    else
        OB.moveTarget = target
    end

    OB.UpdateMoveControls()
end

function OB.ExitMoveMode()
    OB.moveTarget = nil
    OB.UpdateMoveControls()
end

-- the overlay is a temporary editing aid: visible only while a right-click
-- target is live, and never while the bars are locked
function OB.UpdateMoveControls()
    local mover = OB.CreateMover()

    if not OB.profile or OB.profile.locked then OB.moveTarget = nil end

    if OB.moveTarget then
        OB.PositionMover()
        mover:Show()
    else
        mover:Hide()
    end
end
