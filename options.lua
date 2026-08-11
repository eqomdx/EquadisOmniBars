--[[ Equadis' OmniBars :: options

  The settings panel, generated from a table.

  Equadis' Threat Meter's declarative options table with one addition -- a
  *scope* on every row -- and that single field is what makes per-slot and
  per-module controls data driven rather than ninety lines of Show() and Hide().

    global       the profile
    slot         the slot the selector is on
    module       the module occupying that slot
    variant      that module's variant table, e.g. the druid's current form
    moduleToggle the per-module enable flags

  A module never touches the panel. It publishes an `options` table in its
  descriptor and those rows appear under whichever slot it currently occupies.
  RogueBars did the same job with an element dropdown and an if/else chain that
  showed and hid two dozen named widgets by hand.
]]--

local OB = EquadisOmniBars

local PANEL_W, PANEL_H = 700, 600
local SIDEBAR_W = 108
local CONTENT_X = SIDEBAR_W + 30
local CONTENT_Y = -62

local PAGE_W = PANEL_W - CONTENT_X - 20
local PAGE_H = PANEL_H + CONTENT_Y - 60
local COLUMN_X = 288   -- left edge of the second column

-- how far down the page the next control sits, per kind
local ROW_ADVANCE = {
    boolean = 24,
    slider = 44,
    color = 26,
    list = 50,
    header = 24,
    button = 28,
    editbox = 28,
}

OB.panel = { bar = "health" }

-- ---------------------------------------------------------------------------
-- scopes
-- ---------------------------------------------------------------------------

OB.scopes = {
    global = function(w) return OB.profile end,
    slot = function(w) return OB.profile.slots[OB.panel.bar] end,
    moduleToggle = function(w) return OB.profile.modulesEnabled end,

    module = function(w) return OB.profile.modules[w.module] end,

    --[[ Exists so a druid's three resource colours are one panel row instead of
         three: the module hands back whichever sub-table applies right now. ]]--
    variant = function(w)
        local m = OB.modules[w.module]
        if not m or not m.VariantTable then return nil end
        return m:VariantTable()
    end,
}

-- side effects that need more than a repaint
OB.onChange = {
    border = function()
        -- a heavier border may not fit between bars placed edge to edge, so
        -- spread them before applying or the border art stacks
        OB.ResolveOverlap()
    end,
    join = function() OB.ExitMoveMode() end,
    locked = function() OB.ExitMoveMode() end,
    font = function() OB.profile.fontName = OB.fonts[OB.profile.font] end,
}

-- ---------------------------------------------------------------------------
-- read / write
-- ---------------------------------------------------------------------------

local function container(w)
    local fn = OB.scopes[w.scope]
    if not fn then return nil end
    return fn(w)
end

local function readValue(w)
    local t = container(w)
    if not t then return nil end
    return OB.Get(t, w.key)
end

OB.ReadOption = readValue

--[[ One write path for every control, whatever its scope. The slash prompt comes
     through here too, so a value typed and a value clicked take exactly the same
     route -- including the side effects. ]]--
function OB.ApplyOption(w, value)
    local t = container(w)
    if not t then return end

    --[[ Position is the one setting that cannot be written directly: it has to
         go through the nudge path, or Join and collision are bypassed and the
         sliders become a second, disagreeing way to move a bar. ]]--
    if w.scope == "slot" and (w.key == "x" or w.key == "y") then
        OB.SetSlotCoord(OB.panel.bar, w.key, value)
        return
    end

    OB.Set(t, w.key, value)

    --[[ Growing a bar can push it into the one below, and Allow Bar Overlap
         being off is the user saying that must not happen. Position already goes
         through the collision path above; size has to be resolved after the
         fact, because a bar has to be allowed to grow -- it is the *other* bars
         that move. ]]--
    if w.scope == "slot" and (w.key == "w" or w.key == "h") then
        OB.ResolveOverlap()
    end

    if w.scope == "global" and OB.onChange[w.key] then OB.onChange[w.key]() end

    if w.module then
        local m = OB.modules[w.module]
        if m and m.onChange and m.onChange[w.key] then m.onChange[w.key]() end
    end

    if w.rebind then OB.BindSlots() end

    OB.Refresh(true)
    OB.RefreshPanel()
end

-- ---------------------------------------------------------------------------
-- row visibility
-- ---------------------------------------------------------------------------

OB.predicates = {
    power_mana = function()
        local m = OB.modules.power
        return m and (m.ptype == 0)
    end,

    power_rage = function()
        local m = OB.modules.power
        return m and (m.ptype == 1)
    end,
}

--[[ Generalises Equadis' Threat Meter's dependsOn: a plain key, a negated key,
     or a named predicate for anything that is not a simple flag. ]]--
local function dependencyMet(w)
    local dep = w.dependsOn
    if not dep then return true end

    if string.sub(dep, 1, 1) == "@" then
        local fn = OB.predicates[string.sub(dep, 2)]
        if not fn then return true end
        return fn() and true or false
    end

    local negate = false
    if string.sub(dep, 1, 1) == "!" then
        negate = true
        dep = string.sub(dep, 2)
    end

    local t = container(w)
    local truthy = (t and OB.Get(t, dep)) and true or false

    if negate then return not truthy end
    return truthy
end

local function rowVisible(w)
    -- a module's rows only appear while that module occupies the selected slot
    if w.module and w.scope ~= "moduleToggle" then
        local occupant = OB.bound[OB.panel.bar]
        if not occupant or occupant.id ~= w.module then return false end
    end

    return dependencyMet(w)
end

-- ---------------------------------------------------------------------------
-- widgets
-- ---------------------------------------------------------------------------

OB.widgets = {}

--[[ Scope, module and key together, so a slot's "flip" and a module's "flip"
     cannot collide the way a single flat key would.

     Exposed on the namespace as well as kept local, because the self-test walks
     OB.optionIndex and asks whether each descriptor actually grew a control --
     which is the panel bug's *symptom* rather than its cause, and so catches the
     next one whatever causes it. ]]--
function OB.WidgetKey(w)
    return w.scope .. ":" .. (w.module or "") .. ":" .. w.key
end

local widgetKey = OB.WidgetKey

local function uniqueName(prefix, w)
    local name = prefix .. w.scope .. "_" .. (w.module or "x") .. "_" .. w.key
    return (string.gsub(name, "[^%w_]", "_"))
end

local function addCheck(page, w)
    local check = CreateFrame("CheckButton", uniqueName("EqOBCheck_", w), page,
            "UICheckButtonTemplate")
    check:SetWidth(20)
    check:SetHeight(20)

    local text = getglobal(check:GetName() .. "Text")
    text:SetJustifyH("LEFT")
    -- wide enough for the longest caption, narrow enough that a column-one row
    -- cannot run under column two
    text:SetWidth(210)
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(w.caption)

    check.Update = function(self)
        self:SetChecked(readValue(self.w) and true or false)
    end

    check:SetScript("OnClick", function()
        OB.ApplyOption(w, this:GetChecked() and true or false)
    end)

    return check
end

--[[ Slider plus an edit box for typing an exact value. `factor` converts between
     the stored value and the shown one, so a threshold lives in the config as
     0-1 and reads as 0-100.

     Two guards, both load bearing: `syncing` stops the slider and the box
     retriggering each other, and `quiet` moves the slider without writing back,
     which is what lets a refresh show a value without re-applying it. ]]--
local function addSlider(page, w)
    local min, max, step, factor = w.min, w.max, w.step or 1, w.factor

    local slider = CreateFrame("Slider", uniqueName("EqOBSlider_", w), page,
            "OptionsSliderTemplate")
    slider:SetWidth(170)
    slider:SetHeight(16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)

    getglobal(slider:GetName() .. "Low"):SetText("")
    getglobal(slider:GetName() .. "High"):SetText("")
    getglobal(slider:GetName() .. "Text"):SetText(w.caption)

    local box = CreateFrame("EditBox", slider:GetName() .. "Box", page,
            "InputBoxTemplate")
    box:SetWidth(50)
    box:SetHeight(18)
    box:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    box:SetFont(STANDARD_TEXT_FONT, 10)
    box:SetAutoFocus(false)
    box:SetMaxLetters(6)
    box:SetJustifyH("CENTER")

    slider.box = box

    local function display(value)
        if step < 1 then return string.format("%.2f", value) end
        return "" .. value
    end

    slider.Update = function(self)
        local value = readValue(self.w) or min
        if factor then value = OB.Round(value / factor) end

        self.quiet = true
        self:SetValue(value)
        self.quiet = false

        self.syncing = true
        box:SetText(display(self:GetValue()))
        self.syncing = false
    end

    slider:SetScript("OnValueChanged", function()
        local value = slider:GetValue()

        if not slider.syncing then
            slider.syncing = true
            box:SetText(display(value))
            slider.syncing = false
        end

        if not slider.quiet then
            if factor then value = value * factor end
            OB.ApplyOption(w, value)
        end
    end)

    local commit = function()
        local value = tonumber(box:GetText())
        if value then
            if value < min then value = min end
            if value > max then value = max end
            slider:SetValue(value)
        end
        box:SetText(display(slider:GetValue()))
        box:ClearFocus()
    end

    box:SetScript("OnEnterPressed", commit)
    box:SetScript("OnEditFocusLost", commit)
    box:SetScript("OnEscapePressed", function()
        box:SetText(display(slider:GetValue()))
        box:ClearFocus()
    end)

    return slider
end

-- an enum stores one of its own strings; every other list stores an index
local function listEntries(w)
    local values = w.values
    if type(values) == "function" then values = values() end

    if type(values) == "table" and values.enum then
        return values.values, values.labels, true
    end

    return values, nil, false
end

local function listLabel(w, index)
    local values, labels, enum = listEntries(w)
    if not values then return "" end

    if enum then return (labels and labels[index]) or values[index] or "" end
    return OB.CleanLabel(values[index])
end

local function listIndex(w, value)
    local values, _, enum = listEntries(w)
    if not values then return 1 end
    if not enum then return value or 1 end

    for i = 1, table.getn(values) do
        if values[i] == value then return i end
    end
    return 1
end

--[[ A dropdown carries its caption on the page rather than on itself, because
     1.12's UIDropDownMenuTemplate has no label of its own. The reflow has to
     show and hide the two together or the caption is left hanging over whatever
     row takes its place. ]]--
local function labelFor(page, drop, caption)
    local label = OB.NewText(page, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", drop, "TOPLEFT", 20, 2)
    label:SetText(caption)
    drop.label = label
    return label
end

local function addDropDown(page, w)
    local drop = CreateFrame("Frame", uniqueName("EqOBDrop_", w), page,
            "UIDropDownMenuTemplate")

    labelFor(page, drop, w.caption)

    --[[ No `info.checked` anywhere in here, and that is the whole point.

         1.12's UIDropDownMenu_AddButton *shows* a check when info.checked is
         truthy and never *hides* one when it is not -- only UIDropDownMenu_Refresh,
         which SetSelectedValue calls, does both. And the check textures
         (DropDownList1Button<N>Check) are process-global, shared by every
         dropdown in the client. So setting info.checked as well as calling
         SetSelectedValue means one path lights checks the other never clears,
         and opening a second menu shows the first one's tick still lit beside
         its own. That is exactly what was happening on the Profiles page.

         Blizzard's own 1.12 dropdowns and RogueBars both omit info.checked
         entirely and drive selection purely through SetSelectedValue. info.checked
         is only correct for multi-select toggle menus, of which there are none
         here.

         SetText is gone for the same reason: Refresh already sets the label from
         the matching button, and having it here masked the bug -- the label read
         correctly while the tick sat on the wrong row. ]]--
    local function build()
        local values, _, enum = listEntries(w)
        if not values then return end

        for i = 1, table.getn(values) do
            local info = {}
            info.text = listLabel(w, i)

            -- REQUIRED: Refresh matches button.value against selectedValue. With
            -- no value nothing is ever checked and the label never updates.
            info.value = i

            info.func = function()
                local index = this.value
                UIDropDownMenu_SetSelectedValue(drop, index)
                if enum then
                    OB.ApplyOption(w, values[index])
                else
                    OB.ApplyOption(w, index)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(drop, build)
    UIDropDownMenu_SetWidth(w.width or 150, drop)

    drop.Update = function(self)
        UIDropDownMenu_Initialize(self, build)
        UIDropDownMenu_SetSelectedValue(self, listIndex(self.w, readValue(self.w)))
    end

    return drop
end

--[[ Colour swatch. `withAlpha` enables the picker's opacity slider, which in
     vanilla runs inverted -- 0 is opaque -- so the value is flipped on the way
     in and out.

     Colours are stored as {r, g, b, a} arrays rather than {r=,g=,b=} records,
     because that is the shape SetVertexColor and SetTexture want and it keeps
     the render layer free of conversions. ]]--
local function addSwatch(page, w)
    local button = CreateFrame("Button", uniqueName("EqOBSwatch_", w), page)
    button:SetWidth(18)
    button:SetHeight(18)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    button.edge = button:CreateTexture(nil, "BACKGROUND")
    button.edge:SetTexture(0.35, 0.35, 0.35)
    button.edge:SetPoint("TOPLEFT", button, -1, 1)
    button.edge:SetPoint("BOTTOMRIGHT", button, 1, -1)

    button.color = button:CreateTexture(nil, "ARTWORK")
    button.color:SetAllPoints(button)

    button.label = OB.NewText(page, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("LEFT", button, "RIGHT", 6, 0)
    button.label:SetText(w.caption)

    --[[ Always drawn solid. Painting the swatch at the configured alpha means a
         black colour at 0% shows as the grey of whatever is behind it, which
         reads as the wrong colour rather than as transparent. ]]--
    button.Update = function(self)
        local c = readValue(self.w) or { 1, 1, 1, 1 }
        self.color:SetTexture(c[1], c[2], c[3], 1)
    end

    local function apply(r, g, b, a)
        local value = { r, g, b, 1 }
        if w.withAlpha then value[4] = a end
        OB.ApplyOption(w, value)
    end

    button:SetScript("OnClick", function()
        local c = readValue(w) or { 1, 1, 1, 1 }
        local alpha = c[4] or 1

        local function pick()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            if not w.withAlpha then return apply(r, g, b, 1) end
            apply(r, g, b, 1 - OpacitySliderFrame:GetValue())
        end

        ColorPickerFrame.hasOpacity = w.withAlpha and 1 or nil
        ColorPickerFrame.opacity = 1 - alpha
        ColorPickerFrame.previousValues =
                { r = c[1], g = c[2], b = c[3], opacity = 1 - alpha }

        ColorPickerFrame.func = pick
        ColorPickerFrame.opacityFunc = pick
        ColorPickerFrame.cancelFunc = function(previous)
            if previous then
                apply(previous.r, previous.g, previous.b, 1 - (previous.opacity or 0))
            end
        end

        -- the panel sits at DIALOG strata, so the picker has to come up above it
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")

        --[[ Seed the colour *before* showing. Showing first fires opacityFunc
             from the frame's own OnShow while it still holds the previous
             swatch's colour, which writes that stale colour into the config. ]]--
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ShowUIPanel(ColorPickerFrame)
    end)

    return button
end

-- a FontString is not a Frame, so a header needs a carrier the reflow can move
local function addHeader(page, w)
    local holder = CreateFrame("Frame", nil, page)
    holder:SetWidth(1)
    holder:SetHeight(1)

    local text = OB.NewText(page, "OVERLAY", "GameFontNormal")
    text:SetTextColor(1, 0.82, 0)
    text:SetText(w.caption)
    text:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, -14)

    holder.label = text
    holder.Update = function() end
    return holder
end

--[[ There was a font preview row here, showing a sample in the chosen face. It
     is gone: the HUD is already a sample, and the panel does not cover it.

     Its wreckage is worth keeping though. It was the row that created a font
     string with no font object, which is an error rather than a no-op on 1.12,
     which aborted the panel build, which shipped a settings window with one
     category and nothing in it. OB.NewText, OB.texts and the fail-soft panel all
     exist because of this row. See constraint 22. ]]--

-- ---------------------------------------------------------------------------
-- rows
-- ---------------------------------------------------------------------------

--[[ Turn one positional option row into a widget descriptor.

     The positional shape is Equadis' Threat Meter's, so a row lifted from there
     needs no translation:

       boolean  { caption, key, "boolean", nil, nil, nil, nil, dependsOn }
       slider   { caption, key, "slider", min, max, step, factor, dependsOn }
       colour   { caption, key, "color", withAlpha, nil, nil, nil, dependsOn }
       list     { caption, key, values, width, nil, nil, nil, dependsOn }

     A key may carry its own scope as "@variant:color", which is how the power
     module puts the current form's colour on the panel without one row per
     form. ]]--
local function describeRow(opt, scope, moduleId)
    local key = opt[2]
    local rowScope = scope

    local _, _, prefix, rest = string.find(key or "", "^@(%a+):(.+)$")
    if prefix then
        rowScope = prefix
        key = rest
    end

    local w = {
        caption = opt[1],
        key = key,
        scope = rowScope,
        module = moduleId,
        dependsOn = opt[8],
    }

    local kind = opt[3]

    if kind == "boolean" then
        w.kind = "boolean"
    elseif kind == "slider" then
        w.kind = "slider"
        w.min, w.max, w.step, w.factor = opt[4], opt[5], opt[6], opt[7]
    elseif kind == "color" then
        w.kind = "color"
        w.withAlpha = opt[4]
    elseif kind == "header" then
        w.kind = "header"
    else
        w.kind = "list"
        w.values = kind
        w.width = opt[4]
    end

    return w
end

-- per-kind nudges so controls of different shapes line up on the same grid
local OFFSETS = {
    boolean = { 0, 0 },
    slider = { 10, -12 },
    color = { 2, -2 },
    list = { 0, -18 },
    header = { 0, 0 },
    button = { 4, -2 },
    editbox = { 8, -4 },
}

local function place(page, widget, w, column)
    widget.w = w
    widget.kind = w.kind
    widget.column = column or 1

    -- a row that never reaches an update pass still shows, rather than vanishing
    widget.visible = true

    local off = OFFSETS[w.kind] or { 0, 0 }
    widget.xoff, widget.yoff = off[1], off[2]

    if w.key and w.key ~= "" then OB.widgets[widgetKey(w)] = widget end
    table.insert(page.rows, widget)
    return widget
end

--[[ Show or hide a control together with the pieces of it that live on the page
     rather than on the control: a slider's edit box, a dropdown's or swatch's
     caption. Missing one leaves an orphaned label floating over the next row. ]]--
local function setShown(widget, shown)
    if shown then widget:Show() else widget:Hide() end
    if widget.box then
        if shown then widget.box:Show() else widget.box:Hide() end
    end
    if widget.label then
        if shown then widget.label:Show() else widget.label:Hide() end
    end
end

-- ---------------------------------------------------------------------------
-- failing soft
--
-- A settings panel is built from a hundred small independent controls, so the
-- blast radius of one bad control ought to be that control. It was not: a
-- FontString created without a font object threw inside one row's constructor,
-- which aborted the page loop, which aborted CreateSettingsPanel, which left the
-- window with one sidebar entry, no rows and no Test button -- and cached that
-- as the panel forever, because OB.settings had already been assigned.
--
-- Nothing here tries to make a broken control work. It contains the damage and
-- says which control it was, which is the difference between a bug report that
-- names a row and one that says "the settings do not open".
-- ---------------------------------------------------------------------------

OB.panelFaults = {}

-- what to call the thing that broke, in the user's terms first and the
-- developer's second
local function faultLabel(w)
    if not w then return "a control" end

    local label = w.caption
    if not label or label == "" then label = w.key or "?" end

    if w.module then return label .. " (" .. w.module .. "." .. (w.key or "?") .. ")" end
    return label .. " (" .. (w.scope or "?") .. "." .. (w.key or "?") .. ")"
end

-- neutral wording, because the same call reports a single control and a whole
-- page and the label already says which
local function fault(label, err)
    table.insert(OB.panelFaults, { label = label, err = tostring(err) })

    OB.Print("|cffff5511settings panel:|r " .. label .. " failed -- " .. tostring(err))
    OB.Print("the rest of the panel still works. |cff69ccf0/eqob selftest|r lists this again.")
end

--[[ Everything about a row that can throw, in one place.

     Visibility used to be decided inside OB.LayoutPage, which meant the reflow
     reached through rowVisible into dependsOn predicates and a module's
     VariantTable -- config and module concerns evaluated in the middle of pure
     geometry, and a throw there took the whole page's layout with it. Deciding
     it here leaves LayoutPage unable to fail at all, which is the same
     separation that keeps layout.lua from knowing what a slot contains. ]]--
local function updateRow(widget)
    if widget.Update then widget:Update() end

    local visible = true
    if not widget.alwaysShow and widget.w and widget.w.key ~= "" then
        visible = rowVisible(widget.w)
    end

    widget.visible = visible
end

--[[ The one protected call on the refresh path.

     `broken` is the de-duplication as well as the flag. RefreshPanel runs from
     ApplyOption, which runs from a slider's OnValueChanged -- every frame while
     the mouse is down -- so a fault that merely printed would say the same
     sentence four hundred times in five seconds. A row that has thrown once is
     never called again, so it cannot.

     A failed update hides the row rather than removing it. It is already placed
     and already positioned, table.remove during iteration is index churn, and a
     transient fault -- a variant scope momentarily nil mid-shapeshift -- would
     otherwise permanently delete a control that works. ]]--
local function refreshRow(widget)
    if widget.broken then return end

    local ok, err = pcall(updateRow, widget)
    if ok then return end

    widget.broken = true
    widget.visible = false
    setShown(widget, false)
    fault(faultLabel(widget.w), err)
end

local function constructRow(page, w, column)
    local widget

    if w.kind == "boolean" then
        widget = addCheck(page, w)
    elseif w.kind == "slider" then
        widget = addSlider(page, w)
    elseif w.kind == "color" then
        widget = addSwatch(page, w)
    elseif w.kind == "header" then
        widget = addHeader(page, w)
    else
        widget = addDropDown(page, w)
    end

    return place(page, widget, w, column)
end

--[[ Build one row, or none.

     A construction fault drops the row outright, because `place` is the last
     thing constructRow does: a throw means the widget was never inserted, and
     what is left may be missing its edit box, its caption or the frame itself.
     There is nothing there to keep.

     Callers must cope with nil. The seeding update goes through refreshRow like
     every later one, which keeps the ordering the old comment insisted on --
     after placement, before any handler can fire, so building the panel never
     writes to the config -- while making it guarded too. ]]--
local function buildRow(page, w, column)
    local ok, widget = pcall(constructRow, page, w, column)

    if not ok then
        fault(faultLabel(w), widget)
        return nil
    end

    refreshRow(widget)
    return widget
end

local function addButton(page, caption, width, column, onClick)
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    button:SetWidth(width or 150)
    button:SetHeight(20)
    button:SetText(caption)
    button:SetScript("OnClick", onClick)
    button.Update = function() end

    place(page, button, { kind = "button", key = "", scope = "global" }, column)
    button.alwaysShow = true
    return button
end

--[[ Reflow a page from the top, one running offset per column.

     Equadis' Threat Meter can only hide rows that sit last on their page,
     because it assigns fixed coordinates once at build time and a hidden row in
     the middle leaves a hole. That will not do here: the module rows on the
     Slots page change completely with the selector, so every row is
     repositioned on every layout.

     Pure geometry, and deliberately so: it reads `visible`, it does not decide
     it. Whether a row belongs on the page is a question about config, module
     state and dependsOn predicates, all of which can throw, and none of which
     should be able to leave a page unpositioned. updateRow answers it first.

     The invariant that buys: **an update pass must run over a page before this
     does.** There is exactly one caller and it does both in order. ]]--
function OB.LayoutPage(page)
    local y = { 0, 0 }

    for i = 1, table.getn(page.rows) do
        local widget = page.rows[i]
        local column = widget.column or 1

        if widget.visible and not widget.broken then
            local x = 0
            if column == 2 then x = COLUMN_X end

            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", page, "TOPLEFT",
                    x + (widget.xoff or 0), y[column] + (widget.yoff or 0))
            setShown(widget, true)

            y[column] = y[column] - (ROW_ADVANCE[widget.kind] or 24)
        else
            setShown(widget, false)
        end
    end
end

-- ---------------------------------------------------------------------------
-- page contents
-- ---------------------------------------------------------------------------

local generalLeft = {
    { "Visibility", "__h_vis", "header" },
    { "Show HUD", "show", "boolean" },
    { "Hide Out Of Combat", "hideOOC", "boolean" },
    { "Hide When Stealthed", "hideStealth", "boolean" },
    { "Hide While Dead", "hideDead", "boolean" },
    { "Movement", "__h_move", "header" },
    { "Lock Bars", "locked", "boolean" },
    { "Move Bars Together", "join", "boolean" },
    { "Allow Bar Overlap", "allowOverlap", "boolean" },
    { "Feedback", "__h_fb", "header" },
    { "Resource Tick Noise", "audible", "boolean" },
}

local generalRight = {
    { "Appearance", "__h_look", "header" },
    -- the bounds come from OB.SCALE_MIN/MAX so the slider and the load-time
    -- clamp cannot drift apart
    { "Scale", "scale", "slider", OB.SCALE_MIN * 100, OB.SCALE_MAX * 100, 5, 0.01 },
    { "Bar Texture", "texture", OB.textures, 150 },
    { "Bar Border", "border", OB.borders, 150 },
    { "Font", "font", OB.fonts, 150 },
    { "Font Outline", "fontOutline", "boolean" },

    --[[ There is no global Font Size row, and that is deliberate rather than an
         oversight. Every bar sets its own Text Size and always wins -- StyleBar
         reads `slot.textSize` -- so a global size control did nothing at all,
         which is worse than not having one. Face and outline stay here because
         they *do* apply everywhere.

         `profile.fontSize` still exists as the fallback for a font string with
         no bar behind it, and OB.ApplyFont uses it when called without a size. ]]--
}

local slotGeometry = {
    { "Geometry", "__h_geo", "header" },
    { "Show Bar", "show", "boolean" },
    { "Flip Fill", "flip", "boolean" },
    { "Width", "w", "slider", 0, 400, 1 },
    { "Height", "h", "slider", 1, 40, 1 },
    { "X Position", "x", "slider", -2000, 2000, 1 },
    { "Y Position", "y", "slider", -2000, 2000, 1 },
    { "Text Size", "textSize", "slider", 6, 40, 1 },
    { "Background Color", "bg", "color", true },
}

-- ---------------------------------------------------------------------------
-- the flat index
--
-- Built from the very same row tables the panel is built from, so the slash
-- prompt can never drift out of step with the panel. Equadis' Threat Meter does
-- this with a byKey table; the only difference here is that a key alone is not
-- unique, so the index is split by scope.
-- ---------------------------------------------------------------------------

OB.optionIndex = { global = {}, slot = {}, modules = {} }

-- decoration carries a caption and no value, so it has nothing to offer the
-- prompt and would only clutter the generated help
local decorative = { header = true }

local function indexRows(rows, scope, moduleId, target)
    for i = 1, table.getn(rows) do
        local w = describeRow(rows[i], scope, moduleId)
        if not decorative[w.kind] then target[w.key] = w end
    end
end

indexRows(generalLeft, "global", nil, OB.optionIndex.global)
indexRows(generalRight, "global", nil, OB.optionIndex.global)
indexRows(slotGeometry, "slot", nil, OB.optionIndex.slot)

for i = 1, table.getn(OB.moduleOrder) do
    local id = OB.moduleOrder[i]
    local m = OB.modules[id]
    if m.options then
        OB.optionIndex.modules[id] = {}
        indexRows(m.options, "module", id, OB.optionIndex.modules[id])
    end
end

--[[ How a stored value reads in chat. The list cases have to resolve their own
     labels, because an index means nothing at the prompt. ]]--
function OB.DescribeOption(w)
    local value = readValue(w)

    if w.kind == "boolean" then
        if value then return "on" end
        return "off"
    end

    if w.kind == "color" then
        local c = value or { 1, 1, 1, 1 }
        return string.format("%02x%02x%02x",
                OB.Round(c[1] * 255), OB.Round(c[2] * 255), OB.Round(c[3] * 255))
    end

    if w.kind == "list" then
        local values, _, enum = listEntries(w)
        local index = listIndex(w, value)
        local label = listLabel(w, index)
        if enum then return label .. " (" .. tostring(value) .. ")" end
        return label .. " (" .. index .. "/" .. table.getn(values) .. ")"
    end

    if w.factor then return OB.Round((value or 0) / w.factor) .. "" end
    return tostring(value)
end

--[[ Apply a value typed at the prompt. Returns an error string on bad input so
     the caller can report the valid range rather than silently doing nothing. ]]--
function OB.ParseOption(w, args)
    if w.kind == "boolean" then
        local on
        if args == "1" or args == "on" or args == "true" then on = true end
        if args == "0" or args == "off" or args == "false" then on = false end
        if on == nil then return "valid values are on/off" end
        OB.ApplyOption(w, on)
        return nil
    end

    if w.kind == "color" then
        local _, _, hex = string.find(args, "^#?(%x%x%x%x%x%x)$")
        if not hex then return "give a color as rrggbb, e.g. ffcc00" end

        -- the prompt sets the colour only; an alpha the picker stored survives
        local previous = readValue(w) or {}
        OB.ApplyOption(w, {
            tonumber(string.sub(hex, 1, 2), 16) / 255,
            tonumber(string.sub(hex, 3, 4), 16) / 255,
            tonumber(string.sub(hex, 5, 6), 16) / 255,
            previous[4] or 1,
        })
        return nil
    end

    if w.kind == "list" then
        local values, _, enum = listEntries(w)
        if not values then return "no values for this option" end

        if enum then
            for i = 1, table.getn(values) do
                if values[i] == args then
                    OB.ApplyOption(w, values[i])
                    return nil
                end
            end
            return "valid values are " .. table.concat(values, ", ")
        end

        local index = tonumber(args)
        if not index or not values[index] then
            return "valid values are 1-" .. table.getn(values)
        end
        OB.ApplyOption(w, index)
        return nil
    end

    local value = tonumber(args)
    if not value then return "valid values are " .. w.min .. "-" .. w.max end
    if value < w.min or value > w.max then
        return "valid values are " .. w.min .. "-" .. w.max
    end

    if w.factor then value = value * w.factor end
    OB.ApplyOption(w, value)
    return nil
end

-- ---------------------------------------------------------------------------
-- panel
-- ---------------------------------------------------------------------------

local function selectCategory(name)
    local panel = OB.settings
    if not panel then return end

    for i = 1, table.getn(panel.categories) do
        local cat = panel.categories[i]
        if cat.name == name then
            cat.page:Show()
            cat.button:LockHighlight()
            cat.label:SetTextColor(1, 0.82, 0)
        else
            cat.page:Hide()
            cat.button:UnlockHighlight()
            cat.label:SetTextColor(0.7, 0.7, 0.7)
        end
    end

    panel.selected = name
end

local function addCategory(panel, name)
    local index = table.getn(panel.categories) + 1

    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", panel, CONTENT_X, CONTENT_Y)
    page:SetWidth(PAGE_W)
    page:SetHeight(PAGE_H)
    page:Hide()
    page.rows = {}

    local button = CreateFrame("Button", nil, panel)
    button:SetWidth(SIDEBAR_W)
    button:SetHeight(22)
    button:SetPoint("TOPLEFT", panel, 18, CONTENT_Y + 4 - (index - 1) * 24)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    -- a bare Button has no font string of its own in 1.12, so build one
    local label = OB.NewText(button, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", button, 6, 0)
    label:SetJustifyH("LEFT")
    label:SetText(name)
    button:SetFontString(label)

    button:SetScript("OnClick", function() selectCategory(name) end)

    table.insert(panel.categories,
            { name = name, page = page, button = button, label = label })

    return page
end

--[[ The bar's name, and what is drawn in it when those differ.

     They differ for exactly one bar: Extras, whose occupant depends on the class
     and whose label already says so ("Combo Points"). Everywhere else the bar and
     the module are the same thing under two names, so repeating the module name
     would just be noise. ]]--
local function barCaption(barId)
    local label = OB.BarLabel(barId)
    if OB.bound[barId] then return label end
    return label .. " - empty"
end

local function buildBarsPage(page)
    -- the bar selector is a row like any other, so it flows with the page
    local selector = CreateFrame("Frame", "EqOBBarSelector", page,
            "UIDropDownMenuTemplate")
    labelFor(page, selector, "Bar")

    -- rebuilt on every update: the captions carry "- empty", which changes as
    -- modules are toggled, and re-initialising is required before selecting
    -- anyway. See addDropDown for why.
    local function buildBars()
        local bars = OB.BarsForClass()
        for i = 1, table.getn(bars) do
            local info = {}
            info.text = barCaption(bars[i])
            info.value = bars[i]
            info.func = function()
                OB.panel.bar = this.value
                OB.RefreshPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(selector, buildBars)
    UIDropDownMenu_SetWidth(200, selector)

    selector.Update = function(self)
        UIDropDownMenu_Initialize(self, buildBars)
        UIDropDownMenu_SetSelectedValue(self, OB.panel.bar)
    end

    place(page, selector, { kind = "list", key = "", scope = "global" }, 1)
    selector.alwaysShow = true

    --[[ There was an "Occupant" dropdown here, choosing which module drew in the
         selected slot. It is gone: a bar and its module are one thing now, and
         the ordering that dropdown existed to express is done by dragging the
         bars, which was always possible. ]]--

    for i = 1, table.getn(slotGeometry) do
        buildRow(page, describeRow(slotGeometry[i], "slot", nil), 1)
    end

    --[[ Restack is offered rather than done automatically. Automatic reflow is
         the exact bug class the fixed anchor exists to prevent, and it would
         break the promise that two characters on one profile line up the moment
         their occupancy differed.

         It matters more now than it did with six slots: eight bars and most
         classes filling six leaves a gap where the ones they cannot use sit. ]]--
    addButton(page, "Restack Occupied Bars", 190, 1, function()
        OB.RestackBars()
        OB.Refresh(true)
        OB.RefreshPanel()
        OB.Print("bars restacked -- this moves them for every character on the '"
                .. OB.profileName .. "' profile.")
    end)

    --[[ Every module's rows are built once, for every module, in the second
         column; the reflow hides the ones whose module is not in this slot.
         Building them on demand would mean creating and destroying frames as the
         selector moves, which 1.12 does not really allow. ]]--
    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local m = OB.modules[id]

        if m.options then
            buildRow(page, describeRow({ m.name, "__h_" .. id, "header" },
                    "global", id), 2)

            for r = 1, table.getn(m.options) do
                buildRow(page, describeRow(m.options[r], "module", id), 2)
            end
        end
    end
end

local function buildModulesPage(page)
    buildRow(page, describeRow({ "Modules", "__h_modules", "header" },
            "global", nil), 1)

    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local m = OB.modules[id]

        local caption = m.name
        if not OB.ClassAllows(m) then
            caption = m.name .. " |cff888888(not for your class)|r"
        end

        local w = {
            caption = caption,
            key = id,
            scope = "moduleToggle",
            kind = "boolean",
            rebind = true,
        }

        -- buildRow returns nil for a row that failed to build; the loop carries
        -- on so one module's toggle cannot cost the rest of the page
        local check = buildRow(page, w, 1)

        if check then
            check.alwaysShow = true

            --[[ Absent means enabled, so a module shipped by a later version is
                 on until the user says otherwise -- the same principle as the
                 defaults merge. The checkbox has to read that, not plain
                 truthiness. ]]--
            check.Update = function(self)
                local flag = OB.profile.modulesEnabled[id]
                self:SetChecked(flag == nil or flag)
            end
            check:Update()

            if not OB.ClassAllows(m) then check:Disable() end
        end
    end
end

local function buildProfilesPage(page)
    buildRow(page, describeRow({ "Profile", "__h_profile", "header" },
            "global", nil), 1)

    local drop = CreateFrame("Frame", "EqOBProfileDrop", page, "UIDropDownMenuTemplate")
    labelFor(page, drop, "Active profile")

    --[[ Rebuilt on every update rather than once, because the list changes: a
         new or deleted profile has to appear or vanish. That also satisfies the
         re-initialise-before-select rule -- see addDropDown for why every
         dropdown here has to. ]]--
    local function buildProfiles()
        local names = OB.ProfileNames()
        for i = 1, table.getn(names) do
            local info = {}
            info.text = names[i]
            info.value = names[i]
            info.func = function() OB.SetProfile(this.value) end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(drop, buildProfiles)
    UIDropDownMenu_SetWidth(200, drop)

    drop.Update = function(self)
        UIDropDownMenu_Initialize(self, buildProfiles)
        UIDropDownMenu_SetSelectedValue(self, OB.profileName)
    end

    place(page, drop, { kind = "list", key = "", scope = "global" }, 1)
    drop.alwaysShow = true

    local box = CreateFrame("EditBox", "EqOBProfileName", page, "InputBoxTemplate")
    box:SetWidth(180)
    box:SetHeight(20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(24)
    box:SetFont(STANDARD_TEXT_FONT, 11)
    box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    box.Update = function() end
    place(page, box, { kind = "editbox", key = "", scope = "global" }, 1)
    box.alwaysShow = true

    addButton(page, "Create From Current", 190, 1, function()
        local name = box:GetText()
        if not name or name == "" then
            OB.Print("type a name for the new profile first.")
            return
        end
        box:SetText("")
        box:ClearFocus()
        OB.NewProfile(name)
        OB.RefreshPanel()
    end)

    addButton(page, "Reset This Profile", 190, 1, function()
        StaticPopup_Show("EQOB_RESET_PROFILE")
    end)

    addButton(page, "Delete This Profile", 190, 1, function()
        StaticPopup_Show("EQOB_DELETE_PROFILE")
    end)

    buildRow(page, describeRow({ "Everything", "__h_all", "header" },
            "global", nil), 2)

    addButton(page, "Reset Every Profile", 190, 2, function()
        StaticPopup_Show("EQOB_RESET_ALL")
    end)
end

local function buildGeneralPage(page)
    for i = 1, table.getn(generalLeft) do
        buildRow(page, describeRow(generalLeft[i], "global", nil), 1)
    end
    for i = 1, table.getn(generalRight) do
        buildRow(page, describeRow(generalRight[i], "global", nil), 2)
    end
end

--[[ Build one page, or as much of it as survives.

     Rows are already guarded individually, but a page builder does plenty that
     is not a row -- the slot selector, the occupant dropdown, the profile edit
     box, four buttons -- and a throw in any of that used to take every *later*
     page down with it. That is the precise shape of the failure this is here to
     prevent: a half-built Slots page is a far better outcome than no Modules and
     no Profiles. ]]--
local function buildPage(name, fn, page)
    local ok, err = pcall(fn, page)
    if not ok then fault(name .. " page", err) end
    return page
end

function OB.CreateSettingsPanel()
    if OB.settings then return OB.settings end

    local panel = CreateFrame("Frame", "EquadisOmniBarsSettings", UIParent)
    panel.categories = {}

    panel:Hide()
    panel:SetWidth(PANEL_W)
    panel:SetHeight(PANEL_H)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 32)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetBackdropColor(0, 0, 0, 1)
    panel:SetBackdropBorderColor(0.2, 0.2, 0.2)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    panel:SetFrameStrata("DIALOG")

    --[[ The panel is in UISpecialFrames, so ESC hides it without ever calling
         the toggle. Anything that has to happen on close belongs here, or an ESC
         leaves the test bars running -- which keeps the HUD forced visible and
         makes Hide Out Of Combat look broken. ]]--
    panel:SetScript("OnHide", function()
        if OB.testMode then OB.SetTestMode(false) end
        OB.ExitMoveMode()
        OB.Refresh(true)
    end)

    panel.btnClose = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.btnClose:SetPoint("TOPRIGHT", -6, -6)
    panel.btnClose:SetScript("OnClick", function() panel:Hide() end)

    panel.header = panel:CreateTexture(nil, "ARTWORK")
    panel.header:SetWidth(340)
    panel.header:SetHeight(64)
    panel.header:SetPoint("TOP", panel, 0, 12)
    panel.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    panel.header:SetVertexColor(0.2, 0.2, 0.2)

    panel.caption = OB.NewText(panel, "ARTWORK", "GameFontNormal")
    panel.caption:SetPoint("TOP", panel.header, 0, -14)
    panel.caption:SetText(OB.addonName)

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetTexture(1, 1, 1, 0.12)
    panel.divider:SetWidth(1)
    panel.divider:SetHeight(PANEL_H - 130)
    panel.divider:SetPoint("TOPLEFT", panel, CONTENT_X - 14, CONTENT_Y + 4)

    buildPage("General", buildGeneralPage, addCategory(panel, "General"))
    buildPage("Bars", buildBarsPage, addCategory(panel, "Bars"))
    buildPage("Modules", buildModulesPage, addCategory(panel, "Modules"))
    buildPage("Profiles", buildProfilesPage, addCategory(panel, "Profiles"))

    panel.btnTest = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.btnTest:SetWidth(120)
    panel.btnTest:SetHeight(20)
    panel.btnTest:SetPoint("BOTTOMLEFT", panel, 25, 22)
    panel.btnTest:SetScript("OnClick", function() OB.ToggleTestMode() end)

    panel.status = OB.NewText(panel, "OVERLAY", "GameFontDisableSmall")
    panel.status:SetPoint("BOTTOMRIGHT", panel, -25, 28)

    --[[ Published only once there is something worth publishing.

         This used to be the second statement in the function, which meant a
         throw anywhere below left OB.settings pointing at a half-built window --
         and since every entry point starts `if OB.settings then return it`, that
         corpse *was* the settings panel for the rest of the session. Assigning
         last costs nothing: nothing above reads it. ]]--
    OB.settings = panel

    selectCategory("General")
    tinsert(UISpecialFrames, "EquadisOmniBarsSettings")

    return panel
end

--[[ The panel, built on first ask, or nil if it cannot be built.

     Deliberately does not retry. 1.12 cannot destroy a frame, and every widget
     in here takes a global name -- uniqueName's, EqOBOccupant, EqOBProfileDrop,
     the dropdown children Blizzard's template derives from $parent. A second
     attempt would rebind all of them to a fresh set and orphan the first,
     leaking the whole panel on every /eqob. With rows and pages guarded
     individually the only thing left that can throw is the deterministic chrome,
     which would fail identically anyway, so the reason is cached instead. ]]--
function OB.EnsurePanel()
    if OB.settings then return OB.settings end
    if OB.panelDead then return nil end

    local ok, built = pcall(OB.CreateSettingsPanel)
    if ok then return built end

    OB.panelDead = tostring(built)
    return nil
end

-- ---------------------------------------------------------------------------
-- refresh
-- ---------------------------------------------------------------------------

--[[ Re-read every control from the config and reflow every page.

     `force` refreshes a panel that is not on screen, which is otherwise skipped
     because there would be nothing to see. The self-test uses it to build and
     lay the panel out while it stays hidden -- so checking the panel neither
     flashes a window open nor trips its OnHide, which would stop a preview the
     user had running. hud.lua's placeholder takes no arguments and ignores this
     one, which is fine: it only exists before options.lua has loaded. ]]--
function OB.RefreshPanel(force)
    local panel = OB.settings
    if not panel or not OB.profile then return end
    if not force and not panel:IsVisible() then return end

    for i = 1, table.getn(panel.categories) do
        local page = panel.categories[i].page

        -- update first, then lay out: LayoutPage reads `visible` rather than
        -- deciding it, so the pass that decides has to have run
        for r = 1, table.getn(page.rows) do
            refreshRow(page.rows[r])
        end

        OB.LayoutPage(page)
    end

    if OB.testMode then
        panel.btnTest:SetText("Stop Test")
    else
        panel.btnTest:SetText("Test Bars")
    end

    panel.status:SetText("Profile: " .. OB.profileName .. "  |  " .. OB.class)
end

function OB.TogglePanel()
    local panel = OB.EnsurePanel()

    --[[ A dead panel is an inconvenience, not a loss of function, and saying so
         is the whole return on generating the panel and the prompt from one
         table: every setting the window would have shown is still reachable by
         typing. ]]--
    if not panel then
        OB.Print("the settings panel could not be built: " .. tostring(OB.panelDead))
        OB.Print("every option is still available at the prompt -- type "
                .. "|cff69ccf0/eqob help|r. A /reload will try again.")
        return
    end

    if panel:IsVisible() then
        panel:Hide()
        return
    end

    panel:Show()
    OB.RefreshPanel()
end

-- ---------------------------------------------------------------------------
-- confirmations
-- ---------------------------------------------------------------------------

StaticPopupDialogs["EQOB_RESET_PROFILE"] = {
    text = "Restore this profile to its defaults?\n\nOther profiles are left alone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        OB.ResetProfile()
        OB.RefreshPanel()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

StaticPopupDialogs["EQOB_DELETE_PROFILE"] = {
    text = "Delete this profile?\n\nAny character using it falls back to Default.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        OB.DeleteProfile(OB.profileName)
        OB.RefreshPanel()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

StaticPopupDialogs["EQOB_RESET_ALL"] = {
    text = "Restore EVERY profile to defaults?\n\nThis cannot be undone.",
    button1 = "Reset All",
    button2 = "Cancel",
    OnAccept = function()
        OB.ResetAll()
        OB.RefreshPanel()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
