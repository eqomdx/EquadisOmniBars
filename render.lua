--[[ Equadis' OmniBars :: render

  The bar and segment factories, and everything that paints them.

  Nothing here knows what a slot contains or which module is drawing. A module
  asks for a bar, hands it a fraction, and gets a bar filled to that fraction.

  One rule governs this whole file, and it is the most important constraint in
  the codebase (RogueBars HANDOFF section 5.2):

      A bar draws its own fill texture. The StatusBar widget's built-in fill is
      never used for anything partial or reversed.

  Vanilla 1.12 has no SetReverseFill, and the widget re-lays its texture out
  internally on a schedule Lua cannot see, so anything set from here is applied
  inconsistently and shows up as stretched art or gaps. Three separate attempts
  to work around that failed in three different ways.

  RogueBars kept combo points on the native fill because they are always drawn
  at 100%, and its own handover notes flagged that as a trap waiting to be
  sprung. Here every bar owns a fill without exception, and the frames are plain
  Frames rather than StatusBars -- with no native fill in the object at all, the
  rule cannot be broken by accident.
]]--

local OB = EquadisOmniBars

local floor = math.floor

-- ---------------------------------------------------------------------------
-- fonts
-- ---------------------------------------------------------------------------

function OB.FontPath()
    return OB.fontPaths[OB.profile.font]
            or OB.fontPaths[OB.fontIndex["Roboto"]]
            or STANDARD_TEXT_FONT
end

--[[ Apply the configured family, size and outline. A missing or unreadable .ttf
     makes SetFont fail silently and leaves the string invisible, so fall back to
     the client font when that happens. ]]--
function OB.ApplyFont(fontstring, size)
    if not fontstring then return end

    local outline
    if OB.profile.fontOutline then outline = "OUTLINE" end

    size = size or OB.profile.fontSize
    fontstring:SetFont(OB.FontPath(), size, outline)

    if not fontstring:GetFont() then
        fontstring:SetFont(STANDARD_TEXT_FONT, size, outline)
    end
end

-- ---------------------------------------------------------------------------
-- text
-- ---------------------------------------------------------------------------

--[[ Shared by every module that shows a value, so "Current / Max" means the same
     thing on the resource bar and the health bar. RogueBars had this reading the
     energy element's setting directly; the mode is a parameter here. ]]--
function OB.FormatValue(value, max, mode)
    if mode == "none" then return "" end

    value = value or 0
    max = max or 0

    if mode == "percent" then
        if max == 0 then return "0%" end
        return floor((value / max) * 100 + 0.5) .. "%"
    end

    if mode == "max" then return value .. "/" .. max end

    return "" .. value
end

-- ---------------------------------------------------------------------------
-- geometry helpers
-- ---------------------------------------------------------------------------

function OB.BorderPad()
    return OB.borderPads[OB.profile.border] or 0
end

function OB.TexturePath()
    return OB.textures[OB.profile.texture] or OB.textures[1]
end

-- ---------------------------------------------------------------------------
-- bars
-- ---------------------------------------------------------------------------

--[[ Build a bar.

     Frame layering, lowest first:

       bar          the rect itself; mouse enabled for drag and right-click
         bg         background colour, edge to edge
         fill       the only fill that matters
         overlay    lazily built: five-second-rule shading, band tinting
         spark      lazily built: the regeneration ticker
       border       its own frame one level up
       textLayer    one level above the border

     The border sits on a dedicated frame above the bar, and the text one level
     above that. Putting the text on the bar itself leaves it *below* the border,
     and a Standard border then cuts through the numbers. ]]--
function OB.CreateBar(name, parent)
    local bar = CreateFrame("Frame", name, parent)
    bar:SetFrameLevel(parent:GetFrameLevel() + 2)
    bar:EnableMouse(true)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.fill:Hide()

    bar.border = CreateFrame("Frame", nil, bar)
    bar.border:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.border:Hide()

    bar.textLayer = CreateFrame("Frame", nil, bar)
    bar.textLayer:SetAllPoints(bar)
    bar.textLayer:SetFrameLevel(bar.border:GetFrameLevel() + 1)

    bar.left = bar.textLayer:CreateFontString(nil, "OVERLAY")
    bar.left:SetJustifyH("LEFT")
    bar.left:SetPoint("LEFT", bar, "LEFT", 3, 0)

    bar.right = bar.textLayer:CreateFontString(nil, "OVERLAY")
    bar.right:SetJustifyH("RIGHT")
    bar.right:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    bar.center = bar.textLayer:CreateFontString(nil, "OVERLAY")
    bar.center:SetJustifyH("CENTER")
    bar.center:SetPoint("CENTER", bar, "CENTER", 0, 0)

    return bar
end

-- built on demand: most bars never shade anything
function OB.BarOverlay(bar)
    if not bar.overlay then
        bar.overlay = bar:CreateTexture(nil, "ARTWORK")
        bar.overlay:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        bar.overlay:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        bar.overlay:Hide()
    end
    return bar.overlay
end

-- likewise: only ticking resources have a spark
function OB.BarSpark(bar)
    if not bar.spark then
        bar.spark = bar.textLayer:CreateTexture(nil, "OVERLAY")
        bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        bar.spark:SetBlendMode("ADD")
        bar.spark:SetWidth(20)
        bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
        bar.spark:Hide()
    end
    return bar.spark
end

--[[ Fill a bar to `fraction` (0-1) from the left, or from the right when
     flipped.

     Lifted from RogueBars, comment and all, because the reasoning is what
     matters. The crop and the drawn width are always derived from the *same*
     fraction: if those two ever diverge the art stretches, and a stretched
     texture is a subtle enough fault to lose an afternoon to. ]]--
function OB.SetBarFill(bar, fraction, flip)
    local fill = bar.fill
    if not fill then return end

    if not fraction or fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end

    local width = bar:GetWidth() * fraction
    if width < 1 then
        fill:Hide()
        return
    end

    fill:ClearAllPoints()
    if flip then
        fill:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        fill:SetTexCoord(1 - fraction, 1, 0, 1)
    else
        fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        fill:SetTexCoord(0, fraction, 0, 1)
    end

    fill:SetWidth(width)
    fill:Show()
end

-- the same discipline for the shading overlay, which spans 0..fraction too
function OB.SetBarOverlay(bar, fraction, flip, r, g, b, a)
    local overlay = OB.BarOverlay(bar)

    if not fraction or fraction <= 0 then
        overlay:Hide()
        return
    end
    if fraction > 1 then fraction = 1 end

    local width = bar:GetWidth() * fraction
    if width < 1 then
        overlay:Hide()
        return
    end

    overlay:ClearAllPoints()
    if flip then
        overlay:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        overlay:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    else
        overlay:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        overlay:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    end

    overlay:SetTexture(r, g, b, a)
    overlay:SetWidth(width)
    overlay:Show()
end

--[[ A 1px full-height marker at a fixed point along the bar: the range readout's
     dead zone edge, the rage decay projection.

     Ticks are indexed because a bar may carry several, and they are built on
     demand like the spark and the overlay -- most bars never grow one.

     They live on textLayer rather than on the bar, so a tick sits above the fill
     and above the border. A tick under the fill is invisible exactly when the
     bar is full, which is when it is being read. ]]--
function OB.BarTick(bar, index)
    bar.ticks = bar.ticks or {}

    if not bar.ticks[index] then
        local tick = bar.textLayer:CreateTexture(nil, "OVERLAY")
        tick:SetWidth(1)
        tick:Hide()
        bar.ticks[index] = tick
    end

    return bar.ticks[index]
end

--[[ Place tick `index` at `fraction` along the bar.

     The span is bar:GetWidth() for the same reason the spark's is -- see
     OB.DrawSpark. A tick measured against the configured width drifts away from
     the fill it is meant to annotate as soon as the two disagree. ]]--
function OB.SetBarTick(bar, index, fraction, flip, r, g, b, a)
    local tick = OB.BarTick(bar, index)

    if not fraction then
        tick:Hide()
        return
    end

    if fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end

    local x = fraction * bar:GetWidth()

    tick:ClearAllPoints()
    if flip then
        tick:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -x, 0)
        tick:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -x, 0)
    else
        tick:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
        tick:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
    end

    tick:SetTexture(r, g, b, a or 1)
    tick:SetWidth(1)
    tick:Show()
end

function OB.HideBarTicks(bar)
    if not bar.ticks then return end
    for i = 1, table.getn(bar.ticks) do bar.ticks[i]:Hide() end
end

--[[ Sweep the ticker spark across the bar.

     Two things here have both been the cause of a bug that looked like something
     else entirely:

     The phase is *wrapped*, not clamped. Clamping parks the spark against the
     far edge whenever the cycle anchor is stale or sits in the future; wrapping
     makes it always sweep and restart.

     The span is bar:GetWidth(), never the slot's configured width. A different
     span makes the spark arrive early or late, which reads as a *timing* fault
     and sends you hunting a clock bug that does not exist. ]]--
function OB.DrawSpark(bar, start, period, now, flip)
    local spark = OB.BarSpark(bar)

    if not period or period <= 0 then
        spark:Hide()
        return
    end

    local phase = (now - start) / period
    phase = phase - floor(phase)

    local x = phase * bar:GetWidth()

    spark:ClearAllPoints()
    if flip then
        spark:SetPoint("CENTER", bar, "RIGHT", -x, 0)
    else
        spark:SetPoint("CENTER", bar, "LEFT", x, 0)
    end
end

--[[ Re-apply every appearance setting to a bar. Cheap enough to run on each
     refresh, which is what makes a texture or border change instant.

     `width` overrides the slot's own -- combo points and range bands pass their
     segment width. ]]--
function OB.StyleBar(bar, slot, width)
    if not bar then return end

    bar:SetWidth(width or slot.w)
    bar:SetHeight(slot.h)

    bar.fill:SetTexture(OB.TexturePath())

    local bg = slot.bg or { 0, 0, 0, 0.5 }
    bar.bg:SetTexture(bg[1], bg[2], bg[3], bg[4] or 0.5)

    local pad = OB.BorderPad()
    local edge = OB.borderEdges[OB.profile.border]

    if pad > 0 and edge then
        bar.border:ClearAllPoints()
        bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -pad, pad)
        bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pad, -pad)
        bar.border:SetBackdrop(edge)
        bar.border:SetBackdropBorderColor(1, 1, 1, 1)
        bar.border:Show()
    else
        bar.border:SetBackdrop(nil)
        bar.border:Hide()
    end

    local size = slot.textSize or OB.profile.fontSize
    OB.ApplyFont(bar.left, size)
    OB.ApplyFont(bar.right, size)
    OB.ApplyFont(bar.center, size)

    if bar.spark then bar.spark:SetHeight(slot.h * 2) end
end

--[[ Paint the fill.

     Alpha rides on the fill's vertex colour rather than the frame's. Frame alpha
     would also fade the border, which has to stay solid -- that is RogueBars
     HANDOFF section 5.7, generalised: only leaf regions ever take an alpha. ]]--
function OB.SetBarColor(bar, color, alpha)
    local a = color[4] or 1
    if alpha then a = a * alpha end
    bar.fill:SetVertexColor(color[1], color[2], color[3], a)
end

function OB.ClearBarText(bar)
    bar.left:SetText("")
    bar.right:SetText("")
    bar.center:SetText("")
end

-- ---------------------------------------------------------------------------
-- segments
-- ---------------------------------------------------------------------------

--[[ A row of equal bars inside one slot rect: five for combo points, four for
     the range bands.

     The container is a plain frame with no art of its own. Each segment is a
     full bar, so a segment can be filled, coloured and dimmed exactly like any
     other bar, and one code path covers both shapes. ]]--
function OB.CreateSegments(name, parent, count)
    local group = CreateFrame("Frame", name, parent)
    group:SetFrameLevel(parent:GetFrameLevel() + 1)
    group.bars = {}

    for i = 1, count do
        group.bars[i] = OB.CreateBar(name .. i, group)
    end

    group.count = count
    return group
end

--[[ Lay the segments out edge to edge across the slot.

     The segment width is floored to a whole pixel so the row sits flush with no
     sub-pixel overlap. When a border is on, the segments are spaced apart inside
     the same total width -- otherwise each point's border stacks on its
     neighbour's, which reads as a double-thick line between them.

     `shown` lays out fewer than were built and hides the rest, which is how one
     frame serves a module whose shape depends on something only known at
     runtime: the range readout is four bands on one client and a single
     continuous bar on another. Growing and shrinking the frame set instead would
     mean creating and destroying frames mid-session, which 1.12 does not really
     allow -- so the maximum is built once and the surplus is parked. ]]--
function OB.StyleSegments(group, slot, shown)
    local count = shown or group.count
    if count < 1 then count = 1 end
    if count > group.count then count = group.count end

    group.visible = count

    local pad = OB.BorderPad()

    local gap = 0
    if pad > 0 then gap = (pad * 2) + 1 end

    local segment = floor((slot.w - (gap * (count - 1))) / count)
    if segment < 1 then segment = 1 end

    group:SetWidth(slot.w)
    group:SetHeight(slot.h)

    for i = 1, count do
        local bar = group.bars[i]
        OB.StyleBar(bar, slot, segment)

        bar:ClearAllPoints()
        if i == 1 then
            bar:SetPoint("TOPLEFT", group, "TOPLEFT", 0, 0)
        else
            bar:SetPoint("TOPLEFT", group.bars[i - 1], "TOPRIGHT", gap, 0)
        end

        bar:Show()
    end

    for i = count + 1, group.count do
        group.bars[i]:Hide()
    end

    group.segmentWidth = segment
end
