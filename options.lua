--[[ Equadis' Classic Overhaul :: options

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

local OB = EquadisClassicOverhaul

--[[ **Every line this file writes says which part of the addon it came from.**

     One prefix, one colour, and the name after it -- so a message about the
     chat scan says so, rather than leaving the reader to work out which of
     eleven things is talking. See OB.Print. ]]--
local function Say(msg) OB.Print(msg, "Settings") end

--[[ Two of the panel's buttons do a thing rather than change a setting, and
     what they say belongs to the thing. ]]--
local function SayBars(msg) OB.Print(msg, "Bars") end
local function SayQol(msg) OB.Print(msg, "QoL") end

--[[ Two navigation columns, not one and a dropdown.

     The left column is the section -- General, Bars, Modules, Profiles. The
     second is what is *in* that section: the eight bars, or the five subsystems.

     The second used to be a dropdown on the Bars page, and a dropdown is the
     wrong shape for this. It hides the list until clicked, so the one question
     the page has to answer at a glance -- which bar am I looking at, and what
     else is there -- takes a click to ask. A column answers it by existing.

     The panel is wider to pay for it. The content area keeps its old width, so
     nothing inside a page had to be re-laid out. ]]--
local PANEL_W, PANEL_H = 840, 600
local SIDEBAR_W = 108
local SUBBAR_X = 18 + SIDEBAR_W + 10
local SUBBAR_W = 128
local CONTENT_X = SUBBAR_X + SUBBAR_W + 24
local CONTENT_Y = -62

local PAGE_W = PANEL_W - CONTENT_X - 20
local PAGE_H = PANEL_H + CONTENT_Y - 60
local COLUMN_X = 288   -- left edge of the second column

-- how far down the page the next control sits, per kind
local ROW_ADVANCE = {
    boolean = 24,
    slider = 44,
    text = 40,
    action = 26,
    color = 26,
    list = 50,
    header = 24,
    button = 28,
    editbox = 28,
}

--[[ Which bar the second column has selected. Only Bars has one: every
     subsystem is a tab of its own, so there is nothing else to remember. ]]--
OB.panel = { bar = "health" }

-- ---------------------------------------------------------------------------
-- scopes
-- ---------------------------------------------------------------------------

OB.scopes = {
    global = function(w) return OB.profile end,
    slot = function(w) return OB.profile.slots[OB.panel.bar] end,
    moduleToggle = function(w) return OB.profile.modulesEnabled end,

    --[[ Visibility, which is a different question from whether the subsystem
         runs at all. See OB.ModuleShown. ]]--
    moduleShow = function(w) return OB.profile.modulesShown end,

    module = function(w) return OB.profile.modules[w.module] end,

    --[[ The saved variables themselves, for the handful of things that are not
         about this profile at all. The never-keep list is the one: "I never want
         another Broken Fang" is not a statement about how your interface looks
         on this character, and a list that destroys things is the last one that
         should quietly empty itself when somebody switches profile. ]]--
    account = function(w) return EquadisClassicOverhaulDB end,

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

        --[[ A module's chance to spread one write to wherever else it belongs.

             The damage meter uses it to push an appearance setting out to every
             window: the page edits window one, and a page that only ever
             configured window one would leave the others unreachable -- there is
             no second column of settings for them and no plan to add one. ]]--
        if m and m.AfterSet then m:AfterSet(w.key, value) end
    end

    if w.rebind then OB.BindSlots() end

    if w.requiresReload then
        local reason = w.requiresReload == true and w.caption or w.requiresReload
        OB.RequireReload(reason)
    end

    OB.Refresh(true)
    OB.RefreshPanel()
end

-- ---------------------------------------------------------------------------
-- row visibility
-- ---------------------------------------------------------------------------

--[[ Added to rather than assigned, because the modules load first and a module
     is the right place to keep a predicate about its own settings. This file
     should not have to know what "the class colour is overriding the swatch"
     means, any more than layout.lua knows what a slot contains. ]]--
OB.predicates = OB.predicates or {}

OB.predicates.power_mana = function()
    local m = OB.modules.power
    return m and (m.ptype == 0)
end

OB.predicates.power_rage = function()
    local m = OB.modules.power
    return m and (m.ptype == 1)
end

--[[ Generalises Equadis' Threat Meter's dependsOn: a plain key, a negated key,
     or a named predicate for anything that is not a simple flag. ]]--
local function testDependency(w, dep)
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

--[[ Which section of a subsystem's page is showing, keyed by module id.

     A page rather than a global, because switching from the threat meter's Text
     section to the damage meter's tab should not land you on its Text section --
     you asked for the damage meter, not for a section of it. ]]--
OB.panel = OB.panel or {}
OB.panel.section = OB.panel.section or {}

--[[ The first section a module declares, which is where its page opens. ]]--
function OB.DefaultSection(moduleId)
    local m = OB.modules[moduleId]
    if not m or not m.options then return nil end

    for i = 1, table.getn(m.options) do
        if m.options[i][3] == "section" then return m.options[i][4] end
    end

    return nil
end

function OB.SelectedSection(moduleId)
    return OB.panel.section[moduleId] or OB.DefaultSection(moduleId)
end

local function rowVisible(w)
    --[[ A row belonging to a section nobody is looking at. The second column is
         the only thing that changes this, so a row with no section -- which is
         every row on every page that has no second column -- is unaffected. ]]--
    --[[ **`sectionOf` wins over `module`**, which is what lets one page carry
         another module's rows: the Players settings are scoped to the roster
         module -- that is where their values live -- while their section belongs
         to the Chat tab they are drawn on. Without the override they would key
         their section off a tab that no longer exists. ]]--
    local sectionOwner = w.sectionOf or w.module
    if w.section and sectionOwner then
        if w.section ~= OB.SelectedSection(sectionOwner) then return false end
    end

    --[[ The Bars column begins with General, so its page carries two sets of
         rows: the general ones, and everything about the selected bar. A row can
         claim one entry, or claim everything except it. ]]--
    if w.onBar and OB.panel.bar ~= w.onBar then return false end
    if w.notOnBar and OB.panel.bar == w.notOnBar then return false end

    --[[ A **bar** module has no page of its own: you pick the bar, and whatever
         occupies it comes with, so its rows appear when it occupies the selected
         bar. A **feature** has a whole tab to itself, so its rows are separated
         by being on that page and need no test here at all.

         That asymmetry is the difference between owning a window and being
         handed a rectangle, and it is why only one of the two needs a rule. ]]--
    if w.module and w.scope ~= "moduleToggle" and w.scope ~= "moduleShow" then
        local m = OB.modules[w.module]

        if not (m and m.feature) then
            local occupant = OB.bound[OB.panel.bar]
            if not occupant or occupant.id ~= w.module then return false end
        end
    end

    return testDependency(w, w.dependsOn)
end

--[[ Greyed out is **not** hidden, and the two mean different things.

     `dependsOn` removes a row that has no meaning yet -- the five second rule
     shading has nothing to shade when the ticker is off, so there is nothing to
     say about it and the row goes.

     `greyWhen` keeps a row that still means something but is not currently in
     charge. Colour By Class overrides the health swatch rather than replacing
     it, and an earlier version expressed that by hiding the swatch -- which read
     as the setting having been deleted, and was reported as exactly that. Left
     visible and dimmed, the same fact reads as "your colour is still there,
     something else is winning", which is what is actually true. ]]--
local function rowGreyed(w)
    --[[ Every row of a subsystem that is not written yet, without any of them
         having to say so. The settings are listed because the list *is* the
         plan -- you can see what the thing will be before it exists -- and
         dimmed because none of them does anything.

         Greyed rather than hidden for the usual reason, and it holds unusually
         well here: the switch that would make them live is the module getting
         written, so the row is exactly "yours to set, not in charge yet". ]]--
    if w.module then
        local m = OB.modules[w.module]
        if m and m.development then return true end

        --[[ **And whatever else the module knows about itself.**

             `greyWhen` reads config keys, which covers "this setting is not in
             charge because that one is off" and nothing else. A row can also be
             inert for a reason that is not a setting at all -- Automatically
             Scan Unknown Players while a full sweep is running -- and the module
             is the only thing that can answer that. ]]--
        if m and m.RowGreyed and m:RowGreyed(w) then return true end
    end

    if not w.greyWhen then return false end

    --[[ Comma separated and OR'd: a row can be inert for more than one reason at
         a time -- an off hand timer position on a mage is dimmed both by Show
         Timer being off and by the class never dual wielding -- and any one
         reason is enough. `dependsOn` stays single, because a row is either on
         the page or it is not and there is nothing to combine. ]]--
    for dep in string.gfind(w.greyWhen, "[^,]+") do
        if testDependency(w, dep) then return true end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- widgets
-- ---------------------------------------------------------------------------

OB.widgets = {}

--[[ Scope, module and key together, so a slot's "flip" and a module's "flip"
     cannot collide the way a single flat key would.

     `mirror` is for a row that deliberately appears twice -- the same setting
     offered on two pages, so it is to hand wherever you happen to be. Both
     copies read and write the identical config key; only their identity differs,
     because two frames cannot share a global name in 1.12 and the second would
     silently displace the first.

     Exposed on the namespace as well as kept local, because the self-test walks
     OB.optionIndex and asks whether each descriptor actually grew a control --
     which is the panel bug's *symptom* rather than its cause, and so catches the
     next one whatever causes it. ]]--
function OB.WidgetKey(w)
    local key = w.scope .. ":" .. (w.module or "") .. ":" .. w.key
    if w.mirror then key = key .. "@" .. w.mirror end
    return key
end

local widgetKey = OB.WidgetKey

local function uniqueName(prefix, w)
    local name = prefix .. w.scope .. "_" .. (w.module or "x") .. "_" .. w.key
    if w.mirror then name = name .. "_" .. w.mirror end
    return (string.gsub(name, "[^%w_]", "_"))
end

local function addCheck(page, w)
    local check = CreateFrame("CheckButton", uniqueName("EqOBCheck_", w), page,
            "UICheckButtonTemplate")
    check:SetWidth(20)
    check:SetHeight(20)

    --[[ **Our own font string, not the template's.**

         `UICheckButtonTemplate` creates one and names it after the frame, so
         reaching it means `getglobal(name .. "Text")` -- and that is a global
         lookup keyed on a name we generate. Two controls that generate the same
         name share one global, and the second to be built silently takes the
         first one's label away. That is what emptied the captions on a page
         where the colour swatches -- the one kind that already built its own --
         kept theirs.

         Building it here costs one font string and removes the whole class of
         failure: nothing about this label depends on what it is called. ]]--
    local text = OB.NewText(check, "OVERLAY", "GameFontNormalSmall")
    text:SetJustifyH("LEFT")
    -- wide enough for the longest caption, narrow enough that a column-one row
    -- cannot run under column two
    text:SetWidth(210)
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(w.caption)

    --[[ The template's own label is emptied rather than left underneath. It is
         still there, still named after the frame, and would otherwise print the
         caption a second time a few pixels off. ]]--
    local templateText = getglobal(check:GetName() .. "Text")
    if templateText then templateText:SetText("") end

    check.label = text

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

    -- Do not ClearFocus from OnEditFocusLost. In 1.12 ClearFocus fires
    -- OnEditFocusLost synchronously, so the old shared handler called itself
    -- until the client raised "C stack overflow". Enter may clear focus; the
    -- focus-lost pass only commits the value it was handed.
    local committing = false
    local function commit(clearFocus)
        if committing then return end
        committing = true

        local value = tonumber(box:GetText())
        if value then
            if value < min then value = min end
            if value > max then value = max end
            slider:SetValue(value)
        end
        box:SetText(display(slider:GetValue()))

        if clearFocus then box:ClearFocus() end
        committing = false
    end

    box:SetScript("OnEnterPressed", function() commit(true) end)
    box:SetScript("OnEditFocusLost", function() commit(false) end)
    box:SetScript("OnEscapePressed", function()
        if committing then return end
        committing = true
        box:SetText(display(slider:GetValue()))
        box:ClearFocus()
        committing = false
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

--[[ **A row that holds typed text.**

     The panel had no such row until the chat port needed one: a channel's short
     name is whatever you want it to be, and no list of presets covers "what I
     call the trade channel". A slider cannot express it and a dropdown cannot
     either.

     Committed on Enter and on losing focus, both, because people do both --
     clicking away from a box you have just typed in means the same as pressing
     Enter, and a box that quietly discarded it would be the panel losing work
     the user watched themselves do.

     Escape restores the stored value, which is the one way out that does not
     write: a box you have half-edited needs an undo that is not "remember what
     it said before you started". ]]--
local function addInput(page, w)
    local box = CreateFrame("EditBox", uniqueName("EqOBInput_", w), page,
            "InputBoxTemplate")
    box:SetWidth(w.width or 110)
    box:SetHeight(18)
    box:SetAutoFocus(false)
    box:SetMaxLetters(w.maxLetters or 24)

    local label = OB.NewText(page, "OVERLAY", "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    label:SetText(w.caption)
    label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 2)

    box.label = label

    local function commit()
        --[[ `syncing` guards the write the same way the slider's does: setting
             the text to show a stored value must not be mistaken for somebody
             typing it, or every refresh writes the profile back to itself. ]]--
        if box.syncing then return end
        OB.ApplyOption(box.w, box:GetText() or "")
    end

    box:SetScript("OnEnterPressed", function()
        commit()
        this:ClearFocus()
    end)

    box:SetScript("OnEditFocusLost", function() commit() end)

    box:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        if this.Update then this:Update() end
    end)

    box.Update = function(self)
        self.syncing = true
        self:SetText(tostring(readValue(self.w) or ""))
        self.syncing = false
    end

    return box
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

       boolean  { caption, key, "boolean", nil, nil, nil, nil, dependsOn, greyWhen }
       slider   { caption, key, "slider", min, max, step, factor, dependsOn, greyWhen }
       colour   { caption, key, "color", withAlpha, nil, nil, nil, dependsOn, greyWhen }
       list     { caption, key, values, width, nil, nil, nil, dependsOn, greyWhen }

     `dependsOn` removes a row that has no meaning; `greyWhen` dims one that has
     a meaning but is not currently in charge. Both take the same predicate
     syntax -- a key, a !negated key, or an @named predicate.

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
        greyWhen = opt[9],
        requiresReload = opt[10],
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
    elseif kind == "text" then
        --[[ Typed text: a channel's short name, and anything else no list of
             presets can cover. opt[4] is the box width, opt[5] its limit. ]]--
        w.kind = "text"
        w.width, w.maxLetters = opt[4], opt[5]
    elseif kind == "header" then
        w.kind = "header"
    elseif kind == "action" then
        --[[ **A thing to do, rather than a thing to set.**

             Bind mode, trash mode, forgetting the roster: every one of them was
             reachable only from the slash prompt, which is the same mistake Prat
             made -- the behaviour existed and the panel did not know about it.

             A row rather than a bespoke button on a hand-written page, because a
             module declaring an action gets it placed, ordered, sectioned and
             hidden by exactly the machinery that already does that for its
             settings. The alternative is a button somebody has to remember to
             wire into three places.

             opt[4] is the function. There is no value behind an action, so it
             has no scope and nothing to read -- which is why `key` is only ever
             an identity here, and why refreshRow leaves it alone. ]]--
        w.kind = "action"
        w.action = opt[4]

        --[[ An optional function answering what the button should say right now,
             for the actions whose name is the state. ]]--
        w.label = opt[5]
    elseif kind == "section" then
        --[[ Not a row. A marker in the options list saying "everything after me
             belongs to this section", which is what the second column picks
             between. Expressed as a marker rather than by nesting the list,
             because the list is walked by the slash prompt, the self test and
             the duplicate-row sweep as well as by the page builder -- and a
             nested shape would have to be understood by all four. ]]--
        w.kind = "section"
        w.section = opt[4]
    elseif kind == "column" then
        --[[ Not a row either. A marker saying "everything after me goes in the
             other column", which is how one section gets two of them -- the
             popup on the left and the highlighting on the right, read side by
             side because they are two halves of one decision.

             A marker rather than a per-row argument, because the column is a
             property of a *run* of rows: written per row it would be a number
             repeated fifteen times and wrong the first time somebody inserted
             one. Reset to column one by the next section marker. ]]--
        w.kind = "column"
        w.column = opt[4] or 2
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
    text = { 4, -14 },
    action = { 0, -2 },
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

--[[ Dim a row and stop it responding, without moving or removing it.

     Alpha *and* Disable, because neither alone is honest: alpha alone leaves a
     control that looks unavailable and still works, and Disable alone leaves one
     that looks available and does nothing. Between them the appearance and the
     behaviour agree.

     `Enable` and `Disable` exist on buttons, check buttons and sliders and not
     on plain frames, so they are called only where they are found rather than
     assumed by widget kind -- there is no reliable kind to switch on here, and
     probing the method is what the rest of this file does for client mods. ]]--
local GREYED = 0.35

local function setEnabled(widget, enabled)
    if widget.greyed == (not enabled) then return end
    widget.greyed = not enabled

    local alpha = enabled and 1 or GREYED

    widget:SetAlpha(alpha)
    if widget.label then widget.label:SetAlpha(alpha) end
    if widget.box then
        widget.box:SetAlpha(alpha)
        widget.box:EnableMouse(enabled)
    end

    if enabled then
        if widget.Enable then widget:Enable() end
    elseif widget.Disable then
        widget:Disable()
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

    Say("|cffff5511settings panel:|r " .. label .. " failed -- " .. tostring(err))
    Say("the rest of the panel still works. |cff69ccf0/eqob selftest|r lists this again.")
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

    if widget.w then setEnabled(widget, not rowGreyed(widget.w)) end
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

--[[ **A declared action, rendered as a button that carries its own caption.**

     No left-hand label. A setting needs one because the control beside it is a
     tick or a number that means nothing alone; a button that says what it does
     needs nothing said about it.

     `Update` exists for one case, and it is the case that makes an action row
     worth having over a bespoke button: a name that changes with the state it
     controls. "Enter Bind Mode" becoming "Leave Bind Mode" is one control
     describing itself, and it is the only way the panel can show that a mode is
     currently on. ]]--
local function addAction(page, w)
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")

    button:SetWidth(200)
    button:SetHeight(20)
    button:SetText(w.caption)

    button:SetScript("OnClick", function()
        if w.action then w.action() end

        --[[ Rebuilt after every action, because most of them change something a
             row on this page is showing -- and working out which would be more
             code than redrawing a page nobody is looking at closely enough to
             see it happen. ]]--
        OB.RefreshPanel()
    end)

    button.Update = function(self)
        if w.label then self:SetText(w.label()) end
    end

    return button
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
    elseif w.kind == "text" then
        widget = addInput(page, w)
    elseif w.kind == "action" then
        widget = addAction(page, w)
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
            local advance = widget.advance or ROW_ADVANCE[widget.kind] or 24

            --[[ **A column that would overflow spills into the next one.**

                 A page's rows are assigned a column when they are built, which
                 is a guess made before anyone knows how many rows a class,
                 a profile and a set of dependencies will actually show. The
                 damage meter has seventeen settings and column one holds about
                 twelve, so the rest were being drawn off the bottom of the
                 panel where there is no way to reach them.

                 Overflowing is better than clipping and far better than a
                 scrollbar: 1.12's scroll frames are fiddly, and the page has a
                 second column sitting right there. Rows keep their build order,
                 so what lands in column two is the tail of column one rather
                 than an arbitrary subset. ]]--
            if column == 1 and (y[1] - advance) < -PAGE_H then column = 2 end

            --[[ Recorded, because `widget.column` is where the row was *asked*
                 to go and this is where it ended up. Anything reasoning about
                 the finished layout -- the self test, the overlap check -- has
                 to read the second, or a spilled row looks like it jumped back
                 up the page. ]]--
            widget.placedColumn = column

            local x = 0
            if column == 2 then x = COLUMN_X end

            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", page, "TOPLEFT",
                    x + (widget.xoff or 0), y[column] + (widget.yoff or 0))
            setShown(widget, true)

            --[[ `advance` is a row declaring its own height, and one kind has
                 to: a description wraps to four or five lines and the per-kind
                 figure is a single control's worth. Without it every row under
                 the paragraph is drawn on top of it. ]]--
            y[column] = y[column] - advance
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
    --[[ The three conditions only ever *narrow* Show HUD -- hud.lua starts from
         it and each of these can take the bars away, never bring them back -- so
         with it off none of them does anything. Greyed rather than removed: a
         condition somebody set is still their setting, and it applies again the
         moment the HUD is switched back on. ]]--
    { "Show HUD", "show", "boolean" },
    { "Hide Out Of Combat", "hideOOC", "boolean", nil, nil, nil, nil, nil, "!show" },
    { "Hide When Stealthed", "hideStealth", "boolean", nil, nil, nil, nil, nil, "!show" },
    { "Hide While Dead", "hideDead", "boolean", nil, nil, nil, nil, nil, "!show" },
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

--[[ Every row dims when the selected bar is one this character cannot use --
     today that means the Off Hand bar without dual wield.

     Dimmed rather than removed, and this is the one place the class rule bends.
     A setting the class can never use normally goes, because there is no switch
     to put back and dimming would imply one. Bar geometry is the exception: it
     is **account-wide**, so the rectangle a mage is looking at is the one their
     warrior actually uses. Take it off the mage's page and the profile holds
     settings with no way to reach them.

     One name, used nine times, because a reason repeated nine times is a reason
     that drifts. ]]--
local UNUSABLE = "@offhand_bar_unusable"

local slotGeometry = {
    { "Geometry", "__h_geo", "header" },
    { "Show Bar", "show", "boolean", nil, nil, nil, nil, nil, UNUSABLE },
    { "Flip Fill", "flip", "boolean", nil, nil, nil, nil, nil, UNUSABLE },
    { "Width", "w", "slider", 0, 400, 1, nil, nil, UNUSABLE },
    { "Height", "h", "slider", 1, 40, 1, nil, nil, UNUSABLE },
    { "X Position", "x", "slider", -2000, 2000, 1, nil, nil, UNUSABLE },
    { "Y Position", "y", "slider", -2000, 2000, 1, nil, nil, UNUSABLE },
    { "Text Size", "textSize", "slider", 6, 40, 1, nil, nil, UNUSABLE },
    { "Background Color", "bg", "color", true, nil, nil, nil, nil, UNUSABLE },
}

--[[ Two General settings, repeated on the Bars page.

     They are *not* per bar and are not meant to look it: both write the same
     profile-wide key the General page writes, so ticking either copy moves the
     other. They are here because they are the two settings you reach for while
     dragging a bar, and walking back to General to find them breaks the loop you
     are in.

     The `@global:` prefix retargets the scope -- the same mechanism that puts a
     druid's current-form colour on the panel -- and `mirror` keeps the duplicate
     from colliding with the original's frame name. ]]--
--[[ `barsMirror` lived here: the movement switches copied onto the Bars page
     with an `@global:` scope and a mirror name, so the duplicate frames did not
     collide with the originals on the General tab.

     It existed only because General was a separate tab. General *is* the first
     entry on this page now, so the mirror became the same rows on the same page
     twice -- which is precisely what the duplicate-row sweep exists to catch,
     and it caught it. ]]--

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
--[[ Kinds that are not settings and so are not indexed: nothing types them at
     the prompt, and the self test would otherwise look for a control behind a
     caption and a divider. ]]--
--[[ Rows with no value behind them. They are built and placed like any other,
     and they are not settings -- so the slash prompt must not offer them and the
     self-test must not try to read one. An action is the newest member and the
     one most likely to be forgotten: it has a key, which makes it look
     addressable, and there is nothing at the end of it. ]]--
local decorative = { header = true, section = true, action = true,
                     column = true }

local function indexRows(rows, scope, moduleId, target)
    for i = 1, table.getn(rows) do
        local w = describeRow(rows[i], scope, moduleId)
        if not decorative[w.kind] then target[w.key] = w end
    end
end

indexRows(generalLeft, "global", nil, OB.optionIndex.global)
indexRows(generalRight, "global", nil, OB.optionIndex.global)

--[[ The general rows as one list, which the index cannot stand in for: the index
     is keyed by setting and drops the decorative ones, so it can answer "does
     this key exist" but not "how is this row worded". A sweep that checks every
     caption phrases a rule the same way needs the captions. ]]--
OB.generalOptions = {}

for i = 1, table.getn(generalLeft) do
    table.insert(OB.generalOptions, generalLeft[i])
end

for i = 1, table.getn(generalRight) do
    table.insert(OB.generalOptions, generalRight[i])
end

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
            --[[ Compared as text, because an enum's values do not have to be
                 strings. Decimal Points stores 0, 1 or 2 as numbers -- it was a
                 slider and the saved values are numeric -- and a raw `==`
                 against the typed argument could never match one, so the prompt
                 silently rejected every value the panel offered. ]]--
            for i = 1, table.getn(values) do
                if tostring(values[i]) == args then
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

--[[ What the second column holds for each section, as { value, caption } pairs,
     and what picking one does.

     Built fresh each time rather than cached: the bar list is class dependent
     and its captions carry "- empty", which changes as modules are toggled. A
     cached column would be right until the first thing that mattered changed. ]]--
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

local subItems = {}

--[[ **General is the first entry in the Bars column, above Health.**

     It was a tab of its own, one click away from the bars it mostly describes:
     scale, texture, font, border and the movement switches are all settings
     *about the bars*, and reading them meant leaving the page where you could
     see what they did. As the first entry here they are where you already are,
     and the bars follow underneath in the order they stack. ]]--
local GENERAL_BAR = "__general"

subItems.OmniBars = function()
    local out = { { value = GENERAL_BAR, caption = "General" } }
    local bars = OB.BarsForClass()

    for i = 1, table.getn(bars) do
        table.insert(out, { value = bars[i], caption = barCaption(bars[i]) })
    end

    return out, OB.panel.bar, function(value)
        OB.panel.bar = value
    end
end

--[[ A subsystem's own second column, built from the section markers in its
     options list -- so declaring one is what creates it, and a module cannot
     have a column entry with no rows behind it or rows with no way to reach
     them.

     The Modules page still has no sub-list: every subsystem has a tab, and a
     second route to one page is how a setting ends up somewhere nobody looks. ]]--
--[[ **A tab may be built from more than one module.**

     Every entry here is either a module id or a list of them. A list means one
     tab, named for the first, carrying the rows of all of them -- which is how
     Players ended up inside Chat: the roster is a subsystem of its own that
     nameplates and unit frames also read from, so it keeps its module, its
     switch on the Modules page and its own place to store settings. What it
     stopped needing was a tab, because everything you do with it you do while
     reading chat.

     The rows keep their own module for *scope* and take the tab's for
     *section*. See rowVisible. ]]--
local function tabModules(entry)
    if type(entry) == "table" then return entry end
    return { entry }
end

local function sectionItems(entry)
    local ids = tabModules(entry)
    local out = {}

    for k = 1, table.getn(ids) do
        local m = OB.modules[ids[k]]

        for i = 1, table.getn((m and m.options) or {}) do
            local opt = m.options[i]

            if opt[3] == "section" then
                table.insert(out, { value = opt[4], caption = opt[1] })
            end
        end
    end

    return out
end

--[[ Registered per tab name rather than per module id, because the second column
     is looked up by the selected category and a category is named for what it
     configures. ]]--
local function sectionSubItems(entry)
    --[[ Keyed by the tab's own module, which is the first of them -- so a page
         built from two modules has one selected section rather than two that
         disagree. ]]--
    local moduleId = tabModules(entry)[1]

    return function()
        return sectionItems(entry), OB.SelectedSection(moduleId),
                function(value)
                    OB.panel.section[moduleId] = value
                end
    end
end

--[[ Rebuild the second column for the selected section.

     Buttons are pooled and reused, never destroyed, for the reason every other
     pool here exists: switching sections back and forth must not leak a frame
     each time. ]]--
local function refreshSubColumn()
    local panel = OB.settings
    if not panel then return end

    local build = subItems[panel.selected]
    local items, selected, pick = {}, nil, nil
    if build then items, selected, pick = build() end

    panel.subPick = pick

    for i = 1, table.getn(items) do
        local button = panel.subButtons[i]

        if not button then
            button = CreateFrame("Button", nil, panel)
            button:SetWidth(SUBBAR_W)
            button:SetHeight(20)
            button:SetHighlightTexture(
                    "Interface\\QuestFrame\\UI-QuestTitleHighlight")

            local label = OB.NewText(button, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", button, 6, 0)
            label:SetJustifyH("LEFT")
            button:SetFontString(label)
            button.label = label

            button:SetScript("OnClick", function()
                if OB.settings.subPick then OB.settings.subPick(this.value) end
                OB.RefreshPanel()
            end)

            panel.subButtons[i] = button
        end

        button.value = items[i].value
        button:SetPoint("TOPLEFT", panel, SUBBAR_X, CONTENT_Y + 4 - (i - 1) * 21)
        button.label:SetText(items[i].caption)

        if items[i].value == selected then
            button:LockHighlight()
            button.label:SetTextColor(1, 0.82, 0)
        else
            button:UnlockHighlight()
            button.label:SetTextColor(0.7, 0.7, 0.7)
        end

        button:Show()
    end

    for i = table.getn(items) + 1, table.getn(panel.subButtons) do
        panel.subButtons[i]:Hide()
    end

    -- the divider only earns its place when there is a column to divide off
    if table.getn(items) > 0 then
        panel.subDivider:Show()
    else
        panel.subDivider:Hide()
    end
end

OB.RefreshSubColumn = refreshSubColumn

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
    OB.RefreshPanel()
end

-- exposed so the tests can drive the navigation the way a click does
OB.SelectCategory = selectCategory

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


local function buildBarsPage(page)
    --[[ The bar selector was a dropdown here and is now the second navigation
         column. A dropdown hides its list until clicked, so the one question
         this page has to answer at a glance -- which bar am I looking at, and
         what else is there -- cost a click to ask.

         There was an "Occupant" dropdown before that, choosing which module drew
         in the selected slot. It went for a different reason: a bar and its
         module are one thing now, and the ordering it existed to express is done
         by dragging. ]]--

    --[[ General's rows live on this page too, shown when its entry is selected.

         Built once and hidden by selection, the way every other page here works:
         `rowVisible` already decides what is on screen, and rebuilding a page on
         each click is how a pooled frame gets leaked. ]]--
    for i = 1, table.getn(generalLeft) do
        local w = describeRow(generalLeft[i], "global", nil)
        w.onBar = GENERAL_BAR
        buildRow(page, w, 1)
    end

    for i = 1, table.getn(generalRight) do
        local w = describeRow(generalRight[i], "global", nil)
        w.onBar = GENERAL_BAR
        buildRow(page, w, 2)
    end

    for i = 1, table.getn(slotGeometry) do
        local w = describeRow(slotGeometry[i], "slot", nil)
        w.notOnBar = GENERAL_BAR
        buildRow(page, w, 1)
    end

    --[[ Marked as mirrors so they get their own frame names. They are otherwise
         identical to the General rows -- same key, same scope, same write path --
         which is what keeps the two copies in step: ticking one writes the
         profile and refreshes the panel, and the other re-reads it. ]]--

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
        SayBars("bars restacked -- this moves them for every character on the '"
                .. OB.profileName .. "' profile.")
    end)

    --[[ Every **bar** module's rows are built once, for every bar module, in the
         second column; the reflow hides the ones whose module is not in this
         slot. Building them on demand would mean creating and destroying frames
         as the selector moves, which 1.12 does not really allow.

         **Features are skipped, and that exclusion is load bearing.** They have
         pages of their own now, so building them here builds them twice -- and
         the second build claims the same generated frame names, which quietly
         takes the first copy's caption away. That is one bug wearing three
         faces: the threat meter's settings appearing under the Bars page, its
         sliders and checkboxes losing their labels, and the damage meter's own
         tab coming up empty. ]]--
    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local m = OB.modules[id]

        if m.options and not m.feature then
            buildRow(page, describeRow({ m.name, "__h_" .. id, "header" },
                    "global", id), 2)

            for r = 1, table.getn(m.options) do
                buildRow(page, describeRow(m.options[r], "module", id), 2)
            end
        end
    end
end

--[[ Which subsystems get a tab of their own, in the order they appear.

     Listed rather than derived from the registry's order, because the tab order
     is a reading order -- the things you touch most, first -- and the registry's
     is a load order. Tying one to the other would mean renaming a file to move
     a tab. ]]--
--[[ Damage before threat: it is the one people open, and a tab list is read
     top down. Unit frames, nameplates and action bars lead because that is what
     the group is -- the furniture the other two sit on top of, whether or not a
     given piece of it is built yet. ]]--
--[[ **The tab order, which is the one thing on this panel nobody should have to
     learn twice.**

     Written out rather than taken from the module registry, because the registry
     is in *load* order -- which is a dependency graph, not a reading order. The
     parser has to load before the meters that read it; nobody looking for the
     damage meter thinks that.

     The order is what somebody reaches for, roughly most to least often, with
     the things that draw the same rectangle next to each other: the bars, then
     the frames around them, then the meters, then the pages that are about
     information rather than about the screen.

     **Profiles is first and Modules is last**, and neither is here -- both are
     hand-built. Profiles because it is the switch above everything else on the
     panel, and Modules because "which of these do I want at all" is the biggest
     question and the least often asked.

     A module not in this list has no tab, which is a way to lose a page
     silently. The self test walks the registry against this and says so. ]]--
--[[ Exported, because two things outside this file need it: the self test, which
     checks that every feature module is reachable, and the login check that says
     so out loud when one is not. ]]--
OB.featureTabs = {
    "actionbars", "unitframes", "nameplates",
    "damage", "threat",
    "unitscan", "itemdatabase", "tooltip", "waypoints",
    { "chat", "roster" }, "map", "qol",
}

--[[ One subsystem's whole page: what it is, whether it is on, and its settings.

     Returned as a builder rather than written out four times, so a module added
     later gets a tab by registering and a tab cannot drift out of step with the
     module it configures.

     Rows are on their own page, so nothing here needs `rowVisible` to hide one
     module's settings from another's -- which is what the shared Modules page
     needed and got wrong once already. ]]--
local function featurePage(entry)
    local ids = tabModules(entry)
    local id = ids[1]

    return function(page)
        local m = OB.modules[id]
        if not m then return end

        buildRow(page, describeRow({ m.name, "__h_" .. id, "header" },
                "global", nil), 1)

        --[[ The description, and for a subsystem that is not written yet it is
             the only thing on the page that is not dimmed. It is why a planned
             module gets a tab at all: the page says what it will be, rather
             than teasing a name. ]]--
        --[[ **Only while the subsystem is unwritten.**

             The description exists so a planned tab says what it will be rather
             than teasing a name. Once the thing works, the settings below say
             what it does far better than a paragraph does -- and the paragraph
             was overlapping the Show checkbox, which is a fair summary of how
             much it was earning by then. ]]--
        if m.description and m.development then
            local note = OB.NewText(page, "OVERLAY", "GameFontDisableSmall")
            note:SetJustifyH("LEFT")
            note:SetWidth(COLUMN_X - 24)
            note:SetText(m.description)

            local holder = CreateFrame("Frame", nil, page)
            holder:SetWidth(1)
            holder:SetHeight(1)
            note:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)

            holder.label = note

            --[[ Measured, not guessed. Wrapped text is however many lines the
                 width makes it, and the height is re-read on every update
                 because the font size is a setting -- a paragraph that fitted at
                 ten point does not at eighteen. ]]--
            --[[ Measured on update, never at build time. A font string has no
                 font until ApplyFont reaches it, and asking a fontless one for
                 its height is an error rather than a zero on 1.12 -- thrown
                 here, inside the page builder, it abandons the rest of the page.
                 The description is built first, so the whole tab would come up
                 empty.

                 RefreshPanel updates every row before it lays any out, so the
                 height is always known by the time it is needed. ]]--
            holder.Update = function(self)
                local ok, height = pcall(note.GetStringHeight, note)
                if not ok or not height or height < 12 then height = 12 end
                self.advance = height + 12
            end

            place(page, holder, { kind = "button", key = "", scope = "global" }, 1)
            holder.alwaysShow = true
        end

        --[[ A module still in development gets no switch rather than a dead
             one. A disabled checkbox invites clicking; the sentence above it has
             already said why there is nothing to click. ]]--
        --[[ **No Show checkbox on a subsystem's own page.**

             There was one on every tab, answering "do I want this on screen
             right now" while the Modules page answered "should this run at
             all". Two switches for one subsystem, on two pages, and the
             difference between them was a paragraph -- which is a sign the
             difference was not worth having. Enable is the one that means
             something, and it is where the list of subsystems is. ]]--

        --[[ A section marker is not built; it stamps every row after it, so the
             second column can show one group at a time. A module that declares
             none leaves every row unstamped and its page is one list, exactly as
             before. ]]--
        local section = nil

        --[[ **Every module this tab is built from**, in order, sharing one
             section column. Each row keeps its own module for scope -- that is
             where its value lives -- and takes this tab's for section, which is
             what `sectionOf` is for. ]]--
        local column = 1

        for k = 1, table.getn(ids) do
            local owner = OB.modules[ids[k]]

            for r = 1, table.getn((owner and owner.options) or {}) do
                local w = describeRow(owner.options[r], "module", ids[k])

                if w.kind == "section" then
                    section = w.section

                    --[[ A new section starts on the left again. Carrying the
                         column across would put the next section's first rows
                         in whichever column the last one happened to end
                         in. ]]--
                    column = 1
                elseif w.kind == "column" then
                    column = w.column
                else
                    w.section = section
                    w.sectionOf = id
                    buildRow(page, w, column)
                end
            end
        end

        --[[ **Every subsystem gets the same appearance block, from one place.**

             Added here rather than written into each module's own options, so a
             subsystem cannot arrive with four of the five settings and a
             differently worded fifth -- and so adding a sixth later reaches all
             of them at once.

             Second column, because it is the same five questions on every page
             and putting them beside that page's own settings keeps the thing you
             came for at the top. ]]--
        --[[ **Only for a subsystem that draws with them.**

             The block used to go on every feature page, which put "Bar Texture"
             and "Border" on the chat page -- five controls that do nothing, on a
             module that owns no bar and no border. Reported as exactly that.

             The flag is declared rather than inferred. `renders` cannot answer
             it: nameplates, action bars and unit frames all say "none" because
             they draw into the client's frames, and all three use the shared
             look. There is no property of a module that implies this, so it is
             stated. ]]--
        if m.styled then
            local look = OB.LookOptions()
            for r = 1, table.getn(look) do
                buildRow(page, describeRow(look[r], "module", id), 2)
            end
        end
    end
end

--[[ The Modules page is the shortest question: which of these do I want at all.

     It was every subsystem's settings as well, until each got a tab. What is
     left is one switch per subsystem and nothing else -- which is why it is
     last in the list rather than first. A bar is deliberately absent: "I do not
     want an off hand timer" is answered by Show Bar on the Bars page, next to
     that bar's own settings, where you are already standing when you decide
     it. ]]--
local function buildModulesPage(page)
    buildRow(page, describeRow({ "Subsystems", "__h_modules", "header" },
            "global", nil), 1)

    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local m = OB.modules[id]

        if m.feature and not m.development then
            local w = {
                caption = m.name,
                key = id,
                scope = "moduleToggle",
                kind = "boolean",
                rebind = true,
                mirror = "list",
            }

            local check = buildRow(page, w, 1)

            if check then
                check.alwaysShow = true

                check.Update = function(self)
                    local flag = OB.profile.modulesEnabled[id]
                    self:SetChecked(flag == nil or flag)
                end
                check:Update()

                if not OB.ClassAllows(m) then check:Disable() end
            end
        end
    end

    --[[ Named rather than left off, so the page is the whole roster and not just
         the part that happens to be finished. Each has a tab of its own with the
         detail; this is the one line saying it exists and does not work yet. ]]--
    local planned = {}
    for i = 1, table.getn(OB.moduleOrder) do
        local m = OB.modules[OB.moduleOrder[i]]
        if m.feature and m.development then
            table.insert(planned, m.name)
        end
    end

    if table.getn(planned) > 0 then
        buildRow(page, describeRow({ "Not Written Yet", "__h_planned", "header" },
                "global", nil), 1)

        local note = OB.NewText(page, "OVERLAY", "GameFontDisableSmall")
        note:SetJustifyH("LEFT")
        note:SetWidth(PAGE_W - 20)
        note:SetText(table.concat(planned, ", ")
                .. ".\n\nEach has its own tab, with what it will be and every"
                .. " setting it will have -- greyed, because none of them does"
                .. " anything yet.")

        local holder = CreateFrame("Frame", nil, page)
        holder:SetWidth(1)
        holder:SetHeight(1)
        note:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)

        holder.label = note

        -- measured on update, never at build time -- see the note on the
        -- description holder above
        holder.Update = function(self)
            local ok, height = pcall(note.GetStringHeight, note)
            if not ok or not height or height < 12 then height = 12 end
            self.advance = height + 12
        end

        place(page, holder, { kind = "button", key = "", scope = "global" }, 1)
        holder.alwaysShow = true
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

    --[[ A button and a popup, not a text box and a button.

         The box sat on the page whether or not anybody was making a profile,
         labelled with nothing, next to a button that only worked once something
         had been typed into it -- so the usual first experience of it was
         pressing the button and being told off. The popup asks for the name at
         the moment the name is wanted, and cannot be pressed too early. ]]--
    addButton(page, "Create New Profile", 190, 1, function()
        StaticPopup_Show("EQOB_NEW_PROFILE")
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

--[[ `buildGeneralPage` lived here. Its rows are built by `buildBarsPage` now,
     which owns the page they moved onto -- leaving this behind would have been a
     second builder for the same rows, and the duplicate-row sweep would have
     gone on catching it. ]]--

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

    local panel = CreateFrame("Frame", "EquadisClassicOverhaulSettings", UIParent)
    panel.categories = {}

    --[[ The second navigation column: a pool of buttons, refilled per section.
         Pooled and reused, never destroyed, so switching sections back and forth
         cannot leak a frame each time. ]]--
    panel.subButtons = {}

    panel.subDivider = panel:CreateTexture(nil, "ARTWORK")
    panel.subDivider:SetTexture(1, 1, 1, 0.12)
    panel.subDivider:SetWidth(1)
    panel.subDivider:SetHeight(PANEL_H - 130)
    panel.subDivider:SetPoint("TOPLEFT", panel, SUBBAR_X - 12, CONTENT_Y + 4)

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

    --[[ **Each subsystem is a tab of its own**, rather than a row on a shared
         Modules page. A threat meter has as much to configure as the whole bar
         cluster does, and burying it one level down said the opposite.

         Profiles is first because it is the one thing that decides what every
         other tab is editing. Modules is last because it is the shortest
         question -- which of these do I want at all -- and the least often
         asked.

         The four subsystem pages are built from the module registry rather than
         hand-written, so a module added later gets a tab by registering, and a
         tab cannot drift out of step with the module it configures. ]]--
    buildPage("Profiles", buildProfilesPage, addCategory(panel, "Profiles"))

    --[[ No General tab. Its rows are the first entry in the Bars column now,
         because scale, texture, font, border and the movement switches are all
         settings *about the bars* -- reading them from a page of their own meant
         leaving the one place you could see what they did. ]]--
    buildPage("OmniBars", buildBarsPage, addCategory(panel, "OmniBars"))

    for i = 1, table.getn(OB.featureTabs) do
        local entry = OB.featureTabs[i]
        local id = tabModules(entry)[1]
        local m = OB.modules[id]

        --[[ **A named tab whose module is not there is a page that vanishes
             without a word**, which is the worst way for this to fail: the
             addon looks fine, one subsystem is simply gone, and nothing says
             so. It happens when a module file throws while loading -- the
             client carries on with the next file and the registration never
             ran.

             Recorded rather than skipped. `OB.panelFaults` already exists for
             faults the panel survives, and this is one. ]]--
        if not m then
            table.insert(OB.panelFaults, { label = "tab " .. id,
                    err = "no module registered -- did " .. id
                            .. " fail to load?" })
        end

        if m then
            --[[ A tab gets a second column exactly when its module declares
                 sections, so the two cannot drift apart: adding a section marker
                 adds the column entry, and removing the last one removes the
                 column. ]]--
            if table.getn(sectionItems(entry)) > 0 then
                subItems[m.name] = sectionSubItems(entry)
            end

            buildPage(m.name, featurePage(entry), addCategory(panel, m.name))
        end
    end

    buildPage("Modules", buildModulesPage, addCategory(panel, "Modules"))

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

    selectCategory("OmniBars")
    tinsert(UISpecialFrames, "EquadisClassicOverhaulSettings")

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

    --[[ Before the rows, because a row's visibility can depend on which entry
         the second column has selected -- a feature's settings appear when that
         feature is picked. Refreshing the rows against last frame's selection
         would show the previous module's page for one frame. ]]--
    refreshSubColumn()

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

--[[ Open the panel on a named tab.

     For a window's own settings button: the shortest path from "this is wrong"
     to the control that fixes it, without going through the panel's front
     door and finding the tab yourself. ]]--
function OB.OpenPanelAt(category)
    local panel = OB.EnsurePanel()
    if not panel then return end

    OB.SelectCategory(category)
    panel:Show()
    OB.RefreshPanel(true)
end

function OB.TogglePanel()
    local panel = OB.EnsurePanel()

    --[[ A dead panel is an inconvenience, not a loss of function, and saying so
         is the whole return on generating the panel and the prompt from one
         table: every setting the window would have shown is still reachable by
         typing. ]]--
    if not panel then
        Say("the settings panel could not be built: " .. tostring(OB.panelDead))
        Say("every option is still available at the prompt -- type "
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
-- the Escape menu
-- ---------------------------------------------------------------------------

--[[ **A button in the game menu, under Options.**

     Where somebody looks for settings when they have forgotten the slash
     command -- which is most people, most of the time. It is one button and it
     removes the only remaining way to be stuck.

     **The menu is a fixed stack of buttons with no layout of its own.** Every
     one is anchored to the one above it and the frame's height is a number in
     the XML, so inserting one means three things and missing any of them is
     visible: place ours, re-anchor whatever was under Options, and grow the
     frame or the bottom button falls outside it.

     Which button *is* under Options differs -- the client has Key Bindings there
     and a server may have added its own -- so it is found rather than named. A
     hardcoded neighbour would work on one client and shuffle two buttons on top
     of each other on the next. ]]--
function OB.InstallGameMenuButton()
    --[[ **Guarded on the frame, not on the namespace.**

         The namespace is rebuilt on a reload and the frame is not, so a guard
         that only checked `OB.gameMenuButton` would add a second button every
         time -- and worse, the re-anchor below would find nothing to move,
         because the first insertion already moved it. Two buttons, one on top
         of the other, growing the menu each time.

         The frame has a name, so asking for it is the durable question. ]]--
    local existing = getglobal("EquadisOverhaulMenuButton")

    if existing then
        OB.gameMenuButton = existing
        return existing
    end

    if not GameMenuFrame or not GameMenuButtonOptions then return nil end
    if type(CreateFrame) ~= "function" then return nil end

    local button = CreateFrame("Button", "EquadisOverhaulMenuButton",
            GameMenuFrame, "GameMenuButtonTemplate")

    if not button then return nil end

    button:SetText(OB.addonName)
    button:SetWidth(GameMenuButtonOptions:GetWidth() or 144)
    button:SetHeight(GameMenuButtonOptions:GetHeight() or 21)

    --[[ **Whatever was under Options, moved under us instead.**

         Found by asking each button what it is anchored to rather than by
         knowing its name. `GetPoint` is the only way to ask, and a button with
         no points -- which happens if a server built its menu differently -- is
         skipped rather than treated as the answer. ]]--
    local below

    for _, name in ipairs({ "GameMenuButtonKeybindings", "GameMenuButtonMacros",
                            "GameMenuButtonUIOptions", "GameMenuButtonSoundOptions",
                            "GameMenuButtonLogout", "GameMenuButtonQuit" }) do
        local candidate = getglobal(name)

        if candidate and candidate.GetPoint and not below then
            local _, relative = candidate:GetPoint(1)
            if relative == GameMenuButtonOptions then below = candidate end
        end
    end

    button:ClearAllPoints()
    button:SetPoint("TOP", GameMenuButtonOptions, "BOTTOM", 0, -1)

    if below then
        below:ClearAllPoints()
        below:SetPoint("TOP", button, "BOTTOM", 0, -1)
    end

    --[[ Grown by exactly what was inserted, or the bottom button ends up outside
         the frame -- which reads as the menu being broken rather than as one
         button having been added. ]]--
    if GameMenuFrame.SetHeight and GameMenuFrame.GetHeight then
        GameMenuFrame:SetHeight((GameMenuFrame:GetHeight() or 0)
                + (button:GetHeight() or 21) + 1)
    end

    button:SetScript("OnClick", function()
        --[[ The menu closes first. Opening a settings window behind a modal
             game menu is a window nobody can reach. ]]--
        if type(HideUIPanel) == "function" then
            HideUIPanel(GameMenuFrame)
        else
            GameMenuFrame:Hide()
        end

        OB.TogglePanel()
    end)

    OB.gameMenuButton = button
    return button
end

-- ---------------------------------------------------------------------------
-- confirmations
-- ---------------------------------------------------------------------------

--[[ 1.12's StaticPopup grows an edit box from `hasEditBox` and hands it to the
     handlers as the dialog's child, which is why the name is read back off
     `this` rather than from a frame this file holds a reference to.

     OnAccept and the box's own enter key both have to be wired: a dialog with a
     text field that ignores Enter is one people type into and then wonder at. ]]--
local function createProfileFrom(dialog)
    local box = dialog and getglobal(dialog:GetName() .. "EditBox")
    local name = box and box:GetText()

    if not name or name == "" then
        Say("a new profile needs a name.")
        return
    end

    OB.NewProfile(name)
    OB.RefreshPanel()
end

StaticPopupDialogs["EQOB_NEW_PROFILE"] = {
    text = "Name the new profile.\n\nIt starts as a copy of the one in use.",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 24,

    OnShow = function()
        local box = getglobal(this:GetName() .. "EditBox")
        if box then
            box:SetText("")
            box:SetFocus()
        end
    end,

    OnAccept = function() createProfileFrom(this:GetParent()) end,

    EditBoxOnEnterPressed = function()
        local dialog = this:GetParent()
        createProfileFrom(dialog)
        if dialog and dialog.Hide then dialog:Hide() end
    end,

    EditBoxOnEscapePressed = function()
        local dialog = this:GetParent()
        if dialog and dialog.Hide then dialog:Hide() end
    end,

    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

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

--[[ **The one confirmation that matters**, because what follows it cannot be
     undone and the client's own dialog is being bypassed.

     Its text is built when it is shown rather than written here: how many, and
     the name of anything green or better. Naming the valuable ones is the whole
     safety measure -- not refusing, because a deliberate selection is allowed to
     be deliberate, but making sure the deliberate part was actually deliberate. ]]--
--[[ **A URL you can select the text out of**, which is what "clickable" means on
     a client that cannot open a browser and never will.

     `hasEditBox` with the text pre-selected, so the whole interaction is click,
     Control-C, Escape. Prat did the same because there is nothing else to do. ]]--
StaticPopupDialogs["EQOB_COPY_URL"] = {
    text = "Copy this link:",
    button1 = "Close",
    hasEditBox = 1,

    OnShow = function()
        local box = getglobal(this:GetName() .. "EditBox")
        if not box then return end

        box:SetText(OB.modules.chat.pendingUrl or "")
        box:HighlightText()
        box:SetFocus()
    end,

    --[[ Escape and Enter both close it. There is nothing to confirm -- the box
         is the whole dialog -- so both keys doing the obvious thing is right. ]]--
    EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
    EditBoxOnEnterPressed = function() this:GetParent():Hide() end,

    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

StaticPopupDialogs["EQOB_TRASH_SELECTED"] = {
    text = "Destroy the selected items?\n\nThis cannot be undone.",
    button1 = "Destroy",
    button2 = "Cancel",
    OnAccept = function()
        local gone = OB.modules.qol:DestroySelected()
        SayQol("destroyed " .. gone .. " item" .. (gone == 1 and "" or "s") .. ".")
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
