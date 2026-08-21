--[[ Equadis' Classic Overhaul :: action bars

  **The baseline**, ported from DragonflightUI-Reforged's Bars module by Guzruul
  and Stormhand (MIT -- see NOTICE). What is here is the load-bearing half: where
  the buttons go and what the text on them looks like.

  Blizzard's 1.12 action bars are one fixed arrangement. The buttons are real
  frames with real names and they can be moved, scaled and re-parented -- what
  cannot be done is any of it *from the interface*, because there is none. That
  is the entire gap this fills, and it is why the port is mostly arithmetic.

  **What is deliberately not here yet, and why.**

  The Dragonflight *look* -- the bar backing plate, the gryphons -- is art, and
  art is the one thing a port cannot simply take. Some of those files are
  reworked Blizzard textures, which nobody downstream can relicense, so they need
  a decision rather than a copy. The layout engine is useful without them and
  they drop in on top when it is made.

  Also absent: the paging buttons, dark mode and the bar tinting. None is load
  bearing and each is a slice of its own.

  Nothing here is a bar in this addon's sense. There is no `OB.NewBar`, no slot
  and no geometry table -- these are the client's own frames, moved. Same shape
  as the chat module: `renders = "none"`, and what it owns is somebody else's
  furniture.
]]--

local OB = EquadisClassicOverhaul

--[[ **Every line this file writes says which part of the addon it came from.**

     One prefix, one colour, and the name after it -- so a message about the
     chat scan says so, rather than leaving the reader to work out which of
     eleven things is talking. See OB.Print. ]]--
local function Say(msg) OB.Print(msg, "Action Bars") end

-- ---------------------------------------------------------------------------
-- what the client calls things
-- ---------------------------------------------------------------------------

--[[ **Every action button family in 1.12, and the binding prefix each answers
     to.**

     The two halves are not the same and cannot be derived from one another,
     which is exactly the sort of thing that gets written as one list and is
     wrong for two of the entries. `PetActionButton` binds to
     `BONUSACTIONBUTTON`, which reads like a mistake and is not -- 1.12's bonus
     bar and pet bar share a binding namespace. `BonusActionButton` binds to
     `ACTIONBUTTON`, because it *is* the action bar while you are in a form.

     Taken from DragonflightUI's map, which had already found this out. ]]--
local FAMILIES = {
    { prefix = "ActionButton", binding = "ACTIONBUTTON", count = 12 },
    { prefix = "BonusActionButton", binding = "ACTIONBUTTON", count = 12 },
    { prefix = "MultiBarBottomLeftButton", binding = "MULTIACTIONBAR1BUTTON", count = 12 },
    { prefix = "MultiBarBottomRightButton", binding = "MULTIACTIONBAR2BUTTON", count = 12 },
    { prefix = "MultiBarRightButton", binding = "MULTIACTIONBAR3BUTTON", count = 12 },
    { prefix = "MultiBarLeftButton", binding = "MULTIACTIONBAR4BUTTON", count = 12 },
    { prefix = "ShapeshiftButton", binding = "SHAPESHIFTBUTTON", count = 10 },
    { prefix = "PetActionButton", binding = "BONUSACTIONBUTTON", count = 10 },
}

--[[ The shapes twelve buttons can be arranged in, which is every pair of whole
     numbers that multiplies to twelve. Stored as rows and columns rather than as
     "wrap after N" because that is how somebody thinks about it: one row of
     twelve, two of six, three of four.

     DragonflightUI's list, and the order is its order -- widest first, because
     that is the default and a list of layouts is read from the familiar one. ]]--
OB.barLayouts = {
    { rows = 1, cols = 12 },
    { rows = 2, cols = 6 },
    { rows = 3, cols = 4 },
    { rows = 4, cols = 3 },
    { rows = 6, cols = 2 },
    { rows = 12, cols = 1 },
}

OB.barLayoutNames = {
    "1 x 12", "2 x 6", "3 x 4", "4 x 3", "6 x 2", "12 x 1",
}

--[[ A button is 36 across in 1.12 and always has been. Not read from the frame,
     because the frame may already have been scaled by the time this runs and the
     spacing arithmetic wants the unscaled size. ]]--
local BUTTON = 36

--[[ **The eight bars, and where each one starts.**

     `FAMILIES` above is what the client calls the buttons; this is what this
     addon calls the bars they make up, which is not the same list -- the main
     bar and the bonus bar are two families in one place, because a druid in form
     is looking at the same rectangle.

     The positions are the client's own defaults expressed as offsets from the
     screen edges, so switching the module on leaves everything where it already
     was and only the shape and spacing change.

     **Declared here, above everything that reads it.** It was at the bottom of
     the file, which put it out of scope for the two functions that walk it --
     `SetDragMode` and `ResetPositions` saw a nil global, and both threw the
     moment anybody pressed the button. `local` is not hoisted; a table used by a
     function defined earlier in the chunk has to be declared earlier in the
     chunk. ]]--
local BARS = {
    { name = "Main", prefix = "ActionButton", count = 12, key = "main",
      owner = "MainMenuBarArtFrame", point = "BOTTOM", x = -216, y = 30 },
    { name = "Bonus", prefix = "BonusActionButton", count = 12, key = "main",
      owner = "BonusActionBarFrame", point = "BOTTOM", x = -216, y = 30 },
    { name = "BottomLeft", prefix = "MultiBarBottomLeftButton", count = 12,
      key = "bottomLeft", owner = "MultiBarBottomLeft",
      point = "BOTTOM", x = -216, y = 72 },
    { name = "BottomRight", prefix = "MultiBarBottomRightButton", count = 12,
      key = "bottomRight", owner = "MultiBarBottomRight",
      point = "BOTTOM", x = -216, y = 114 },
    { name = "Right", prefix = "MultiBarRightButton", count = 12,
      key = "right", owner = "MultiBarRight",
      point = "RIGHT", x = -40, y = 180 },
    { name = "Left", prefix = "MultiBarLeftButton", count = 12,
      key = "left", owner = "MultiBarLeft",
      point = "RIGHT", x = -80, y = 180 },
    { name = "Pet", prefix = "PetActionButton", count = 10, key = "pet",
      owner = "PetActionBarFrame", point = "BOTTOM", x = -180, y = 156 },
    { name = "Stance", prefix = "ShapeshiftButton", count = 10,
      key = "shapeshift", owner = "ShapeshiftBarFrame",
      point = "BOTTOM", x = -180, y = 198 },
}

local M = OB.RegisterModule({
    id = "actionbars",
    name = "Action Bars",

    feature = true,

    --[[ Draws nothing of its own. Every rectangle it touches belongs to the
         client; this decides where they sit. Same shape as the chat module. ]]--
    renders = "none",

    --[[ Off. It moves and re-parents Blizzard's frames, which is the loudest
         thing in this addon after destroying an item -- and next to any other
         action bar addon it is a fight rather than a feature. ]]--
    defaultEnabled = false,

    defaults = {
        --[[ **The main bar.** Scale, spacing and shape, which are the three
             things people actually change and the three the client offers no
             way to change at all. ]]--
        mainScale = 1,
        mainSpacing = 6,
        mainAlpha = 1,
        mainLayout = 1,

        --[[ The four extra bars. Each carries the same four settings, because
             they are the same kind of thing and giving one of them a shorter
             list would only mean explaining why.

             Shown state is **not** here: `SHOW_MULTI_ACTIONBAR_1` and friends
             are the client's own CVars, set from its own interface options, and
             a second switch for the same thing is two switches that disagree. ]]--
        bottomLeftScale = 1,
        bottomLeftSpacing = 6,
        bottomLeftAlpha = 1,
        bottomLeftLayout = 1,

        bottomRightScale = 1,
        bottomRightSpacing = 6,
        bottomRightAlpha = 1,
        bottomRightLayout = 1,

        rightScale = 0.8,
        rightSpacing = 6,
        rightAlpha = 1,
        rightLayout = 6,

        leftScale = 0.8,
        leftSpacing = 6,
        leftAlpha = 1,
        leftLayout = 6,

        petScale = 0.8,
        petSpacing = 6,
        petAlpha = 1,

        shapeshiftScale = 0.8,
        shapeshiftSpacing = 6,
        shapeshiftAlpha = 1,

        --[[ **Keybind and macro text.**

             The reason this is worth porting rather than leaving to the client:
             1.12 draws `SHIFT-BUTTON4` in full, in a nine point font, over the
             corner of the icon. Nobody can read it and everybody leaves it on
             because the alternative is not knowing what is bound.

             The abbreviations below are what make it legible. ]]--
        showHotkeys = true,
        hotkeySize = 12,
        hotkeyColor = { 1, 0.82, 0, 1 },

        showMacroNames = true,
        macroSize = 10,
        macroColor = { 1, 1, 1, 1 },

        --[[ Blizzard's bar art: the plate behind the buttons, the end caps, the
             sliding textures. Off means the buttons float, which is the point of
             moving them anywhere. ]]--
        hideArt = true,

        --[[ Where each bar has been dragged to, keyed by bar. A bar nobody has
             moved has no entry and keeps following the client's own default, so
             turning drag mode on and off leaves everything where it was. ]]--
        positions = {},
    },

    options = {
        { "Main Bar", "__s_main", "section", "main" },

        { "Scale", "mainScale", "slider", 50, 200, 5, 0.01 },
        { "Spacing", "mainSpacing", "slider", 0, 20, 1 },
        { "Opacity", "mainAlpha", "slider", 10, 100, 5, 0.01 },
        { "Shape", "mainLayout", OB.barLayoutNames, 120 },
        { "Hide Blizzard's Bar Art", "hideArt", "boolean" },

        --[[ A mode rather than a lock: on, drag, off. A permanently draggable
             action bar is one you move by accident while clicking a spell. ]]--
        { "Move The Bars", "__a_drag", "action",
          function() OB.modules.actionbars:SetDragMode(
                  not OB.modules.actionbars:DragMode()) end,
          function()
              if OB.modules.actionbars:DragMode() then return "Done Moving" end
              return "Move The Bars"
          end },

        { "Put Them Back", "__a_dragreset", "action",
          function() OB.modules.actionbars:ResetPositions() end },

        { "Bottom Left Bar", "__s_bl", "section", "bottomleft" },

        { "Scale", "bottomLeftScale", "slider", 20, 200, 5, 0.01 },
        { "Spacing", "bottomLeftSpacing", "slider", 0, 20, 1 },
        { "Opacity", "bottomLeftAlpha", "slider", 10, 100, 5, 0.01 },
        { "Shape", "bottomLeftLayout", OB.barLayoutNames, 120 },

        { "Bottom Right Bar", "__s_br", "section", "bottomright" },

        { "Scale", "bottomRightScale", "slider", 20, 200, 5, 0.01 },
        { "Spacing", "bottomRightSpacing", "slider", 0, 20, 1 },
        { "Opacity", "bottomRightAlpha", "slider", 10, 100, 5, 0.01 },
        { "Shape", "bottomRightLayout", OB.barLayoutNames, 120 },

        { "Right Bar", "__s_r", "section", "right" },

        { "Scale", "rightScale", "slider", 20, 200, 5, 0.01 },
        { "Spacing", "rightSpacing", "slider", 0, 20, 1 },
        { "Opacity", "rightAlpha", "slider", 10, 100, 5, 0.01 },
        { "Shape", "rightLayout", OB.barLayoutNames, 120 },

        { "Left Bar", "__s_l", "section", "left" },

        { "Scale", "leftScale", "slider", 20, 200, 5, 0.01 },
        { "Spacing", "leftSpacing", "slider", 0, 20, 1 },
        { "Opacity", "leftAlpha", "slider", 10, 100, 5, 0.01 },
        { "Shape", "leftLayout", OB.barLayoutNames, 120 },

        { "Pet And Stance", "__s_pet", "section", "pet" },

        { "Pet Bar Scale", "petScale", "slider", 20, 200, 5, 0.01 },
        { "Pet Bar Spacing", "petSpacing", "slider", 0, 20, 1 },
        { "Pet Bar Opacity", "petAlpha", "slider", 10, 100, 5, 0.01 },

        { "Stance Bar Scale", "shapeshiftScale", "slider", 20, 200, 5, 0.01 },
        { "Stance Bar Spacing", "shapeshiftSpacing", "slider", 0, 20, 1 },
        { "Stance Bar Opacity", "shapeshiftAlpha", "slider", 10, 100, 5, 0.01 },

        { "Keybinds", "__s_bind", "section", "bind" },

        --[[ The action reads the mode back, so one button says both "enter" and
             "leave" -- the panel has no other way to show that a mode is on, and
             two buttons for one mode is two things to look at. ]]--
        { "Enter Bind Mode", "__a_bind", "action",
          function() OB.modules.actionbars:SetBindMode(
                  not OB.modules.actionbars:BindMode()) end,
          function()
              if OB.modules.actionbars:BindMode() then return "Leave Bind Mode" end
              return "Enter Bind Mode"
          end },

        { "Button Text", "__s_text", "section", "text" },

        { "Show Keybinds", "showHotkeys", "boolean" },
        { "Keybind Size", "hotkeySize", "slider", 6, 20, 1,
          nil, nil, "!showHotkeys" },
        { "Keybind Color", "hotkeyColor", "color", true,
          nil, nil, nil, nil, "!showHotkeys" },

        { "Show Macro Names", "showMacroNames", "boolean" },
        { "Macro Name Size", "macroSize", "slider", 6, 20, 1,
          nil, nil, "!showMacroNames" },
        { "Macro Name Color", "macroColor", "color", true,
          nil, nil, nil, nil, "!showMacroNames" },
    },

    --[[ The bars appear and disappear as the client's own options are changed
         and as a druid changes form, and every one of those needs the layout
         re-applied to frames that were not there a moment ago. ]]--
    events = { "PLAYER_ENTERING_WORLD", "UPDATE_BONUS_ACTIONBAR",
               "ACTIONBAR_PAGE_CHANGED", "PET_BAR_UPDATE",
               "UPDATE_SHAPESHIFT_FORMS", "CVAR_UPDATE",

               --[[ A binding changing is the client rewriting every keybind
                    string on every button. The replacement handles each one as
                    it is rewritten; this is what re-applies the *font* and
                    colour, which the client does not touch. ]]--
               "UPDATE_BINDINGS" },
})

function M:Config()
    return OB.profile.modules.actionbars
end

-- ---------------------------------------------------------------------------
-- laying a bar out
-- ---------------------------------------------------------------------------

--[[ **Where one button goes**, which is the whole engine and is four lines of
     arithmetic.

     Buttons fill left to right and then top to bottom, which is the order the
     keybinds are in and therefore the only order that does not surprise
     somebody. The Y is negative because a bar grows downwards from its anchor:
     the first row is the top one, so button thirteen of a two-row layout sits
     under button one rather than over it.

     Spacing is added to the button rather than between them, which makes the
     arithmetic one multiplication instead of a special case for the first. ]]--
function M:ButtonOffset(index, layout, spacing)
    local step = BUTTON + spacing

    local column = mod(index - 1, layout.cols)
    local row = math.floor((index - 1) / layout.cols)

    return column * step, -(row * step)
end

--[[ One bar: every button in the family placed on a container, at a scale, with
     an opacity.

     **The container is re-parented to, not created per call.** A button that
     changed parent every time a slider moved would lose its position for a frame
     each time, which reads as a flicker and is the sort of thing that gets
     blamed on the client. ]]--
function M:LayoutFamily(prefix, count, anchor, layoutIndex, spacing, scale, alpha)
    local layout = OB.barLayouts[layoutIndex] or OB.barLayouts[1]
    local placed = 0

    for i = 1, count do
        local button = getglobal(prefix .. i)

        if button and button.SetPoint then
            local x, y = self:ButtonOffset(i, layout, spacing)

            --[[ **Re-parented, not merely re-anchored.**

                 A button is a child of one of Blizzard's bar frames, and a
                 child inherits its parent's visibility, alpha and scale.
                 Anchoring to a container of ours while leaving the button on
                 `MainMenuBarArtFrame` means the client can still hide it, fade
                 it, and move the frame it is measured against through
                 `UIPARENT_MANAGED_FRAME_POSITIONS`.

                 **Only when it has moved.** Re-parenting every pass would drop
                 and rebuild the frame's position each time a slider moved,
                 which reads as a flicker and gets blamed on the client. ]]--
            if button.SetParent and button:GetParent() ~= anchor then
                button:SetParent(anchor)
            end

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)

            --[[ **The scale and the fade are the container's, not the button's.**

                 Now that the buttons are its children they inherit both, and
                 putting them on the container is what makes its box the bar's
                 box: sized in unscaled button units, drawn at whatever scale
                 was asked for. `StorePosition` divides by the container's scale
                 and only makes sense that way round -- it was written for this
                 and the buttons were being scaled instead, so a bar at 0.8
                 remembered a position measured against a box 25% too wide.

                 Reset to 1 rather than left, because a profile written by the
                 version that scaled buttons still has that scale on them. ]]--
            if button.SetScale then button:SetScale(1) end
            if button.SetAlpha then button:SetAlpha(1) end

            placed = placed + 1
        end
    end

    --[[ The container is sized to what it actually holds, so anything anchored
         above it lands above the buttons rather than above where twelve of them
         would have been. A druid's four stances are not ten. ]]--
    if anchor and anchor.SetWidth and placed > 0 then
        local layoutCols = layout.cols
        if placed < layoutCols then layoutCols = placed end

        local rows = math.ceil(placed / layout.cols)

        anchor:SetWidth((layoutCols * (BUTTON + spacing)) - spacing)
        anchor:SetHeight((rows * (BUTTON + spacing)) - spacing)

        if anchor.SetScale then anchor:SetScale(scale) end
        if anchor.SetAlpha then anchor:SetAlpha(alpha) end
    end

    return placed
end

-- ---------------------------------------------------------------------------
-- the frames this addon owns
-- ---------------------------------------------------------------------------

--[[ **One container per bar, made once.**

     Blizzard's own bar frames carry art, mouse handling and a place in
     `UIPARENT_MANAGED_FRAME_POSITIONS`, which is the thing that quietly moves a
     frame back where the client wants it. Anchoring to a container of our own
     instead of to `MainMenuBar` is what stops that argument happening at all.

     DragonflightUI does the same and for the same reason. ]]--
function M:Anchor(name, point, x, y)
    self.anchors = self.anchors or {}

    if not self.anchors[name] then
        local frame = CreateFrame("Frame", "EquadisOverhaulBar" .. name, UIParent)

        frame:SetWidth(BUTTON)
        frame:SetHeight(BUTTON)
        frame:SetFrameStrata("LOW")
        frame:SetPoint(point, UIParent, point, x, y)

        self.anchors[name] = frame
    end

    return self.anchors[name]
end


-- ---------------------------------------------------------------------------
-- moving them
-- ---------------------------------------------------------------------------

--[[ **A mode, not a lock.**

     The bars sit where the client's defaults put them until somebody says
     otherwise, and "otherwise" is a mode you turn on, drag in, and turn off --
     the same shape as bind mode and for the same reason. A permanently draggable
     action bar is one you move by accident while clicking a spell on it.

     **Where a bar has been dragged to is remembered per bar**, in the profile
     next to its scale and spacing. A bar nobody has moved has no saved position
     and keeps following the default, so switching this on and off again leaves
     everything exactly where it was. ]]--
function M:DragMode()
    return self.dragging and true or false
end

function M:SetDragMode(on)
    if on and not OB.ModuleEnabled("actionbars") then
        Say("switch the Action Bars module on first.")
        return false
    end

    self.dragging = on and true or nil

    for i = 1, table.getn(BARS) do
        local anchor = self:Anchor(BARS[i].name, BARS[i].point,
                BARS[i].x, BARS[i].y)

        self:MakeDraggable(anchor, BARS[i])
    end

    if self.dragging then
        Say("drag mode on. Move the bars, then switch it off. "
                .. "'/eqob bars reset' puts them back.")
    else
        Say("drag mode off.")
    end

    return true
end

--[[ One container, made movable or not.

     **The handle is the container rather than the buttons.** A button is a
     button -- it casts things -- and making one draggable means every press is a
     potential drag. The container is the empty rectangle behind them, which is
     exactly the part with nothing else to do.

     A backdrop appears with the mode so there is something to aim at: an
     invisible frame the size of a bar is not a thing anybody can grab. ]]--
function M:MakeDraggable(anchor, bar)
    if not anchor then return false end

    if not anchor.dragHint then
        local hint = anchor:CreateTexture(nil, "BACKGROUND")
        hint:SetAllPoints(anchor)
        hint:SetTexture(0.1, 0.6, 1, 0.25)
        hint:Hide()

        anchor.dragHint = hint
    end

    if not self.dragging then
        anchor:EnableMouse(false)
        anchor:SetMovable(false)
        anchor.dragHint:Hide()
        return true
    end

    anchor:EnableMouse(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")
    anchor.dragHint:Show()

    anchor:SetScript("OnDragStart", function() this:StartMoving() end)

    anchor:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        OB.modules.actionbars:StorePosition(bar, this)
    end)

    return true
end

--[[ Where a bar ended up, as an offset from the centre of the screen.

     **From the centre, not from a corner**, which is the rule the meters already
     follow: a position measured from an edge means a different place on a
     different resolution, and this addon has been bitten by that before -- see
     OB.ScreenLimit. The centre is the one point every screen shares. ]]--
function M:StorePosition(bar, frame)
    if not frame or not frame.GetLeft or not frame:GetLeft() then return false end

    local cfg = self:Config()
    cfg.positions = cfg.positions or {}

    local scale = frame:GetScale() or 1
    if scale <= 0 then scale = 1 end

    --[[ **Keyed by the bar, not by the button family.** The main bar and the
         bonus bar are two families in one rectangle -- a druid in form is
         looking at the same place on screen -- so they share a key and moving
         either moves both. Keyed by name they did not, and a druid who dragged
         their bar found it back at the default the moment they shifted.

         No migration: drag mode threw on every use until now, so there is no
         saved position anywhere written under the old key. ]]--
    cfg.positions[bar.key] = {
        x = OB.Round((frame:GetLeft() + (frame:GetWidth() / 2))
                - ((GetScreenWidth() / 2) / scale)),
        y = OB.Round((frame:GetBottom() + (frame:GetHeight() / 2))
                - ((GetScreenHeight() / 2) / scale)),
    }

    return true
end

--[[ **Where a bar goes: the saved position if there is one, the default if not.**

     Applied on the style pass rather than only at login, so a bar dragged with
     the mode on stays where it was put when the next setting changes -- which is
     otherwise where a position quietly reverts.

     A bar nobody has moved has no saved position and keeps following the
     default, so turning the mode on and off again leaves everything exactly
     where it was. ]]--
function M:PlaceAnchor(anchor, bar)
    if not anchor then return false end

    --[[ Not while it is being dragged. Re-anchoring a frame somebody is holding
         takes it out from under the cursor. ]]--
    if self.dragging then return false end

    local saved = self:Config().positions
    saved = saved and saved[bar.key]

    anchor:ClearAllPoints()

    if saved then
        anchor:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
    else
        anchor:SetPoint(bar.point, UIParent, bar.point, bar.x, bar.y)
    end

    return true
end

--[[ Put every bar back where the client would have had it. ]]--
function M:ResetPositions()
    self:Config().positions = {}

    for i = 1, table.getn(BARS) do
        local anchor = self.anchors and self.anchors[BARS[i].name]

        if anchor then
            anchor:ClearAllPoints()
            anchor:SetPoint(BARS[i].point, UIParent, BARS[i].point,
                    BARS[i].x, BARS[i].y)
        end
    end

    Say("action bars put back where they started.")
end

--[[ Blizzard's bar art, hidden -- and put back when the switch goes off.

     Every one of these is guarded, because the set differs between 1.12 builds
     and a private server may have removed or renamed one. A missing texture is
     not a reason to abandon the rest of the layout -- and an unguarded
     `SlidingActionBarTexture0:SetTexture` on a client that lacks it takes the
     whole module down on login, which is the failure that looks like the addon
     being broken. ]]--
local ART = {
    "MainMenuBarTexture0", "MainMenuBarTexture1",
    "MainMenuBarTexture2", "MainMenuBarTexture3",
    "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
    "SlidingActionBarTexture0", "SlidingActionBarTexture1",
    "BonusActionBarTexture0", "BonusActionBarTexture1",
    "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",

    --[[ `PetActionBarFrame` is **not** here, though its art is what everybody
         means by "the pet bar background". It is a frame, and it is the frame
         the client shows and hides to say whether you have a pet -- which is
         the signal the layout pass mirrors onto its own container. Hiding it
         would make that answer always "no". Its mouse handling is switched off
         below instead, which is the part that was actually in the way. ]]--
}

--[[ The frames that keep their mouse handling otherwise, which means an
     invisible plate swallowing clicks over an empty part of the screen. ]]--
local ART_FRAMES = { "MainMenuBar", "MainMenuBarArtFrame", "PetActionBarFrame" }

--[[ **Hidden and faded, never `SetTexture(nil)`.**

     Clearing the texture cannot be undone: the path is gone and this addon never
     knew it, so unticking the box left the art missing until a reload. Hiding
     and fading both reverse, so the switch works in both directions.

     Frames get their mouse switched off rather than hidden -- an invisible
     plate that still swallows clicks over an empty part of the screen is the
     complaint this answers, and hiding `PetActionBarFrame` outright would
     destroy the signal the layout pass reads to know whether you have a
     pet. ]]--
function M:StyleArt()
    local hide = self:Config().hideArt

    for i = 1, table.getn(ART) do
        local region = getglobal(ART[i])

        if region then
            if hide then
                if region.SetAlpha then region:SetAlpha(0) end
                if region.Hide then region:Hide() end
            else
                if region.SetAlpha then region:SetAlpha(1) end
                if region.Show then region:Show() end
            end
        end
    end

    for i = 1, table.getn(ART_FRAMES) do
        local frame = getglobal(ART_FRAMES[i])
        if frame and frame.EnableMouse then frame:EnableMouse(not hide) end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- the text on a button
-- ---------------------------------------------------------------------------

--[[ **A keybind, shortened until it fits.**

     This is the single most useful thing in the port. 1.12 writes
     `SHIFT-BUTTON4` across the corner of a 36 pixel icon in a font nobody can
     read, and the result is that everybody leaves keybind text on and nobody
     reads it.

     The substitutions are DragonflightUI's and they are well chosen: the
     modifier keeps its initial, the mouse button becomes M, and the long words
     that only ever appear alone get initials. Order matters -- `NUMPAD` before
     anything that could match inside it. ]]--
local SHORTEN = {
    { "SHIFT%-", "s" },
    { "CTRL%-", "c" },
    { "ALT%-", "a" },
    { "BUTTON", "M" },
    { "MOUSEWHEELUP", "MwU" },
    { "MOUSEWHEELDOWN", "MwD" },
    { "NUMPAD", "N" },
    { "SPACE", "Sp" },
    { "PAGEUP", "PU" },
    { "PAGEDOWN", "PD" },
}

function M:ShortenKey(key)
    if not key or key == "" then return "" end

    for i = 1, table.getn(SHORTEN) do
        key = string.gsub(key, SHORTEN[i][1], SHORTEN[i][2])
    end

    return key
end

--[[ The keybind and macro strings on every button, restyled.

     Blizzard's own font strings are used rather than replaced. DragonflightUI
     hides them and makes its own, which is more control and one more thing to
     keep in step -- the client updates its string when a binding changes, and a
     replacement has to notice that and copy it across. Restyling the original
     means the client goes on maintaining the text and this only decides how it
     looks.

     **The keybind text itself goes through the replaced client function**, not
     through here, so the same code runs whether this module asked for the update
     or the client did. See `M:UpdateHotkey`. This pass sets the font and colour,
     which the client does not touch, and then asks for the text. ]]--
function M:ApplyText()
    local cfg = self:Config()
    --[[ **The addon-wide font, with no per-module override.**

         Action bars use a font and nothing else from the shared look -- there is
         no bar to texture and no border to draw -- so offering the five-row
         appearance block here would be three controls that do nothing. Asking
         for the font with no module id is asking for the profile's own.

         The size is a setting of this module's, because keybind text wants to
         be smaller than anything else on screen and sharing that number with the
         meters would be wrong for both. ]]--
    local font = OB.FontPath()

    for f = 1, table.getn(FAMILIES) do
        local family = FAMILIES[f]

        for i = 1, family.count do
            local name = family.prefix .. i
            local hotkey = getglobal(name .. "HotKey")
            local macro = getglobal(name .. "Name")

            if hotkey then
                if cfg.showHotkeys then
                    hotkey:SetFont(font, cfg.hotkeySize, "OUTLINE")
                    hotkey:SetTextColor(cfg.hotkeyColor[1], cfg.hotkeyColor[2],
                            cfg.hotkeyColor[3], cfg.hotkeyColor[4] or 1)

                    self:UpdateHotkey(getglobal(name))
                else
                    hotkey:Hide()
                end
            end

            if macro then
                if cfg.showMacroNames then
                    macro:SetFont(font, cfg.macroSize, "OUTLINE")
                    macro:SetTextColor(cfg.macroColor[1], cfg.macroColor[2],
                            cfg.macroColor[3], cfg.macroColor[4] or 1)
                    macro:Show()
                else
                    macro:Hide()
                end
            end
        end
    end
end

--[[ **The client rewrites this text, and often.**

     `ActionButton_UpdateHotkeys` writes the binding out in full and runs from
     `ActionButton_Update` -- every time a spell is dragged onto a bar, every
     time a binding changes, and on entering the world. Shortening the text on
     the module's own events and stopping there means it is long again after the
     next spell drag, which reads as the setting working until you use the bar.

     Same problem as the unit frame strings and the same answer: replace the
     client's function once, read the settings inside, and delegate for any
     button that is not one of ours. Constraint 86.

     **Guarded on the saved original**, which is the durable artefact -- guard
     and payload one object, in `_G`, which is where the replaced function lives.
     Constraint 87: the wrapper reaches the module by global name, never through
     the `OB` upvalue, because `core.lua` rebuilds that namespace on every
     load. ]]--
function M:UpdateHotkey(button)
    if not button or not button.GetName then return end

    local name = button:GetName()
    local command = self:CommandForFrame(name)

    --[[ Not one of ours -- another addon's bar, or a button family this client
         has that 1.12 did not. The client's own version, unchanged. ]]--
    if not command then return EquadisOverhaulBlizzHotkeys(button) end

    local cfg = self:Config()

    --[[ Switched off is switched off: the client's own text, in the client's own
         font. A module that is not doing this has to be indistinguishable from
         one that is not installed. ]]--
    if not OB.ModuleEnabled("actionbars") or not cfg.showHotkeys then
        return EquadisOverhaulBlizzHotkeys(button)
    end

    local hotkey = getglobal(name .. "HotKey")
    if not hotkey then return end

    local bound
    if type(GetBindingKey) == "function" then bound = GetBindingKey(command) end

    hotkey:SetText(self:ShortenKey(bound or ""))
    hotkey:Show()

    return true
end

function M:InstallHotkeyHook()
    if EquadisOverhaulBlizzHotkeys then return false end

    EquadisOverhaulBlizzHotkeys = ActionButton_UpdateHotkeys

    ActionButton_UpdateHotkeys = function(button, buttonType)
        local target = button or this
        if not target then return end

        return EquadisClassicOverhaul.modules.actionbars:UpdateHotkey(target)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- bind mode
-- ---------------------------------------------------------------------------

--[[ **Hover a button, press a key, that is the binding.**

     The client's own binding interface is a list of two hundred command names
     with a box beside each, and finding "the third button on my bottom right
     bar" in it means counting. Nobody does it twice. Everybody who has used a
     hover-to-bind mode wants it in every game they play afterwards, and it is
     about eighty lines.

     Three pieces, and only the first is interesting.

     **Which button the mouse is over.** `GetMouseFocus` would answer this, and
     cannot be used: the capture frame has to take the mouse to stop a left click
     casting the spell instead of binding to it, and the moment it does,
     GetMouseFocus answers the capture frame. So the button is found by geometry
     instead -- `MouseIsOver` against each one -- which is unaffected by who owns
     the mouse and is a scan of eighty-eight rectangles once per keypress.

     **Which command that button answers to**, which the FAMILIES map above
     already knows because the text pass needed the same thing.

     **What key was pressed**, which is the key plus whatever modifiers were held,
     in the client's own order. ]]--
function M:BindMode()
    return self.binding and true or false
end

--[[ The command a frame is bound by, or nothing if it is not a button that can
     be bound.

     Anchored at both ends -- `^prefix(%d+)$` -- because "ActionButton1" is a
     prefix of "ActionButton12" and a loose match would bind the wrong slot on
     every second button. ]]--
function M:CommandForFrame(name)
    if not name then return nil end

    for f = 1, table.getn(FAMILIES) do
        local family = FAMILIES[f]
        local _, _, index = string.find(name, "^" .. family.prefix .. "(%d+)$")

        if index and tonumber(index) <= family.count then
            return family.binding .. index
        end
    end

    return nil
end

--[[ The key as the client spells it: modifiers in ALT, CTRL, SHIFT order, then
     the key. That order is not cosmetic -- `SetBinding("CTRL-ALT-F")` and
     `SetBinding("ALT-CTRL-F")` are two different strings, and only one of them
     is the one the client will look up when the keys are pressed. ]]--
function M:BindingName(key)
    if not key or key == "" then return nil end

    --[[ A modifier on its own is somebody reaching for a combination, not a
         binding. Treating it as one would bind Shift to the button under the
         cursor the instant they pressed it. ]]--
    if key == "LSHIFT" or key == "RSHIFT" then return nil end
    if key == "LCTRL" or key == "RCTRL" then return nil end
    if key == "LALT" or key == "RALT" then return nil end
    if key == "UNKNOWN" then return nil end

    local name = key

    if IsShiftKeyDown() then name = "SHIFT-" .. name end
    if IsControlKeyDown() then name = "CTRL-" .. name end
    if IsAltKeyDown() then name = "ALT-" .. name end

    return name
end

--[[ Every bindable button, asked by geometry rather than by focus. See BindMode
     for why. ]]--
function M:ButtonUnderMouse()
    if type(MouseIsOver) ~= "function" then return nil end

    for f = 1, table.getn(FAMILIES) do
        local family = FAMILIES[f]

        for i = 1, family.count do
            local button = getglobal(family.prefix .. i)

            if button and button:IsVisible() and MouseIsOver(button) then
                return family.prefix .. i, family.binding .. i
            end
        end
    end

    return nil
end

--[[ One binding, set and said out loud.

     **What was there before is named**, because the commonest thing that goes
     wrong with a hover-to-bind mode is taking a key off something you wanted --
     and the client says nothing when it does. Knowing you have just moved
     `CTRL-1` off your main bar is the difference between noticing now and
     noticing in a fight. ]]--
function M:Bind(key)
    local name = self:BindingName(key)
    if not name then return false end

    local buttonName, command = self:ButtonUnderMouse()
    if not command then return false end

    if type(SetBinding) ~= "function" then return false end

    --[[ Whatever held this key, before it stops holding it. ]]--
    local previous
    if type(GetBindingAction) == "function" then
        previous = GetBindingAction(name)
    end

    SetBinding(name, command)

    if previous and previous ~= "" and previous ~= command then
        Say(name .. " bound to " .. buttonName
                .. " -- taken from " .. previous .. ".")
    else
        Say(name .. " bound to " .. buttonName .. ".")
    end

    return true
end

--[[ Clearing one, which is the other half and is what the delete keys are for.
     A hover-to-bind mode with no way to unbind is a mode you can only ever add
     with. ]]--
function M:Unbind()
    local buttonName, command = self:ButtonUnderMouse()
    if not command then return false end

    if type(GetBindingKey) ~= "function" then return false end
    if type(SetBinding) ~= "function" then return false end

    local cleared = 0
    local key = GetBindingKey(command)

    while key do
        SetBinding(key)
        cleared = cleared + 1
        key = GetBindingKey(command)

        --[[ A guard, not a formality: if SetBinding fails silently -- a
             read-only binding set, a client mod -- GetBindingKey keeps answering
             the same key and this never returns. ]]--
        if cleared > 8 then break end
    end

    if cleared > 0 then
        Say("cleared " .. cleared .. " binding"
                .. (cleared == 1 and "" or "s") .. " from " .. buttonName .. ".")
    end

    return cleared > 0
end

--[[ The frame that takes the keyboard while the mode is on.

     Made once and hidden, rather than made on entry: a frame that grabs the
     keyboard is not a thing to be creating and destroying, and hiding one
     releases the keyboard just as well. ]]--
function M:BindFrame()
    if self.bindFrame then return self.bindFrame end

    local frame = CreateFrame("Frame", "EquadisOverhaulBindMode", UIParent)

    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:EnableMouseWheel(true)
    frame:Hide()

    --[[ Escape leaves. It is the one key that cannot be bound here, and that is
         the right trade: a mode with no way out that does not involve binding
         something is a trap. ]]--
    frame:SetScript("OnKeyDown", function()
        local m = OB.modules.actionbars

        if arg1 == "ESCAPE" then m:SetBindMode(false) return end
        if arg1 == "DELETE" or arg1 == "BACKSPACE" then m:Unbind() return end

        m:Bind(arg1)
    end)

    --[[ Mouse buttons, which is why this frame takes the mouse at all. Left and
         right have to be caught here or they cast the spell instead of binding
         to it. ]]--
    frame:SetScript("OnMouseDown", function()
        local m = OB.modules.actionbars
        local key = arg1

        if key == "LeftButton" then key = "BUTTON1" end
        if key == "RightButton" then key = "BUTTON2" end
        if key == "MiddleButton" then key = "BUTTON3" end
        if key == "Button4" then key = "BUTTON4" end
        if key == "Button5" then key = "BUTTON5" end

        m:Bind(key)
    end)

    frame:SetScript("OnMouseWheel", function()
        local m = OB.modules.actionbars
        m:Bind(arg1 > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)

    self.bindFrame = frame
    return frame
end

--[[ In and out of the mode.

     **Everything closes on the way in.** The whole point is an unobstructed
     view of the bars, and the settings panel is by some distance the largest
     thing likely to be over them -- it is where somebody was standing when they
     decided to do this. ]]--
function M:SetBindMode(on)
    if on and not OB.ModuleEnabled("actionbars") then
        Say("switch the Action Bars module on first.")
        return
    end

    self.binding = on and true or nil

    local frame = self:BindFrame()

    if self.binding then
        if OB.settings then OB.settings:Hide() end
        if type(CloseAllWindows) == "function" then CloseAllWindows() end

        frame:Show()

        Say("bind mode on. Hover a button and press a key. "
                .. "Delete clears it, Escape finishes.")
    else
        frame:Hide()

        --[[ Written to disk on the way out rather than on every key. A binding
             set is saved whole, and saving it eighty times while somebody works
             down a bar is eighty writes for one result. ]]--
        if type(SaveBindings) == "function" then
            local which = 1
            if type(GetCurrentBindingSet) == "function" then
                which = GetCurrentBindingSet()
            end

            SaveBindings(which)
        end

        Say("bind mode off. Bindings saved.")

        --[[ The text on the buttons is now wrong: the client rewrites its
             keybind strings, but the short form is ours to redo. ]]--
        self:ApplyText()
    end
end

-- ---------------------------------------------------------------------------
-- applying the lot
-- ---------------------------------------------------------------------------


function M:ApplyBars()
    local cfg = self:Config()

    for i = 1, table.getn(BARS) do
        local bar = BARS[i]
        local anchor = self:Anchor(bar.name, bar.point, bar.x, bar.y)
        self:PlaceAnchor(anchor, bar)

        --[[ The pet and stance bars have no shape setting -- ten buttons in a
             row is the only arrangement anybody wants for either -- so they fall
             back to the widest layout rather than carrying a slider that would
             only ever be left alone. ]]--
        local layout = cfg[bar.key .. "Layout"] or 1

        self:LayoutFamily(bar.prefix, bar.count, anchor, layout,
                cfg[bar.key .. "Spacing"] or 6,
                cfg[bar.key .. "Scale"] or 1,
                cfg[bar.key .. "Alpha"] or 1)

        self:MirrorVisibility(anchor, bar)
    end
end

--[[ **Whether a bar is shown at all stays the client's decision.**

     It used to be one for free: the buttons were children of Blizzard's frames,
     so hiding `MultiBarBottomLeft` hid its twelve buttons and there was nothing
     to do. Re-parenting them onto a container of ours takes that away -- the
     container is always shown, so every bar would appear whether the client
     wanted it or not, including the pet bar with no pet and the stance bar on a
     warrior who has not learned a stance.

     So the container copies the frame the buttons came off. **The frame, not a
     rule of our own**: "the four multibar CVars, plus does the player have a
     pet, plus how many forms" is a list that is wrong on a private server and
     right nowhere for long. The client already knows, and it says so by showing
     or hiding exactly these eight frames.

     This is also why `PetActionBarFrame` is not in the art list. Hiding it
     would make its answer permanently "no pet". ]]--
function M:MirrorVisibility(anchor, bar)
    if not anchor or not bar.owner then return false end

    local owner = getglobal(bar.owner)
    if not owner or not owner.IsShown then return false end

    if owner:IsShown() then anchor:Show() else anchor:Hide() end

    return true
end

function M:Apply()
    if not OB.ModuleEnabled("actionbars") then return end

    --[[ Bars before art: the buttons have to be off Blizzard's frames before
         anything is done to those frames. ]]--
    self:ApplyBars()
    self:StyleArt()
    self:ApplyText()
end

function M:OnEvent()
    self:Apply()
end

function M:OnBind()
    self:InstallHotkeyHook()
    self:Apply()
end

function M:OnStyle()
    self:Apply()
end

function M:OnDraw() end
