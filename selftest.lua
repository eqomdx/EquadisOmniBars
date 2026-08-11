--[[ Equadis' OmniBars :: self test

  /eqob selftest -- what the offline suite cannot prove.

  tests/run.lua boots the real addon against a fake 1.12 client and checks that
  it is internally consistent. It is thorough and it is not enough, because a
  stub that agrees with a wrong assumption still passes. That is not a
  hypothetical caveat: a font string created without a font object threw on the
  real client, aborted the options panel build, and shipped a settings window
  with one sidebar entry and no controls -- past a green suite, because the
  stub's SetTextColor recorded the value and said nothing.

  So this half asks the questions only the client can answer. Does every API a
  module names actually exist here? Did the widgets end up with a size and an
  anchor? Does every font string have a font? Does GetValue return a number? Did
  the range readout find a backend? Did the panel build all four pages with every
  row placed?

  Three rules:

  It writes nothing. No ApplyOption, no SetTestMode, no touching the profile.
  Running it
  must never be the reason something changed. The one exception is building the
  settings panel, which is idempotent and is done hidden.

  Every section runs inside pcall. A self-test that dies partway through is worse
  than useless -- it reports a clean bill of health for everything it never
  reached.

  It counts propositions, not rows. "No visible row on the General page is
  unanchored" is one check with the count in its label. Sixty lines is a report;
  four hundred is a wall nobody reads.
]]--

local OB = EquadisOmniBars

local GREEN = "|cff00ff00"
local RED = "|cffff5511"
local GREY = "|cffcccccc"
local WHITE = "|cffffffff"

-- ---------------------------------------------------------------------------
-- what the addon needs from the client, beyond what the modules declare
--
-- This list is here rather than split across core, render, layout and options
-- because no one of those owns it and four lists is four lists nobody keeps up
-- to date. A module gets its own `requires` because a module is a self-contained
-- unit with a descriptor to hang it on.
-- ---------------------------------------------------------------------------

local coreAPI = {
    "CreateFrame", "getglobal", "GetTime", "GetCursorPosition",
    "UnitClass", "UnitName", "GetRealmName",
    "UnitAffectingCombat", "UnitIsDeadOrGhost", "GetPlayerBuffTexture",
    "PlaySound", "IsAddOnLoaded",
    "UIDropDownMenu_Initialize", "UIDropDownMenu_AddButton",
    "UIDropDownMenu_SetWidth", "UIDropDownMenu_SetText",
    "UIDropDownMenu_SetSelectedValue",
    "StaticPopup_Show", "ShowUIPanel",
}

--[[ Widget methods the addon calls. The in-game counterpart of the stub's
     UnknownMethods() list, and deliberately a *subset* of what we really use:
     probing a method we never call would put a new entry in that list and break
     the "an unexpected entry is a typo'd API name" workflow.

     This section cannot fail under the stub, whose metatable fabricates a
     function for any PascalCase lookup. That is precisely why it belongs here
     and not in run.lua. ]]--
local frameMethods = {
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetClampedToScreen", "SetFrameStrata", "SetFrameLevel",
    "RegisterForDrag",
    "GetNumPoints", "CreateTexture", "CreateFontString", "EnableMouse",
}

--[[ StartMoving and StopMovingOrSizing are deliberately not probed, though the
     panel does call them. They live inside drag handlers the offline suite never
     fires, so probing them would add two entries to Stub.UnknownMethods() -- and
     that list earns its keep by being short enough that an unexpected entry
     reads as a typo'd API name. Two permanent, harmless entries would cost more
     than the check is worth, and a missing StartMoving would announce itself the
     first time anyone dragged the window. ]]--

local textureMethods = { "SetTexCoord", "SetVertexColor", "SetBlendMode", "SetTexture" }
local textMethods = { "SetFont", "GetFont", "SetText", "SetTextColor", "SetJustifyH" }

-- ---------------------------------------------------------------------------
-- the recorder
-- ---------------------------------------------------------------------------

local sections = {}

local function section(name, fn)
    table.insert(sections, { name = name, Run = fn })
end

local function newRecorder()
    local t = { passed = 0, failed = 0, failures = {}, notes = {} }

    function t:ok(condition, label)
        if condition then
            self.passed = self.passed + 1
        else
            self.failed = self.failed + 1
            table.insert(self.failures, label)
        end
    end

    -- context for the summary line: never counted, never a failure
    function t:note(text)
        table.insert(self.notes, text)
    end

    return t
end

local function exists(name)
    return type(getglobal(name)) == "function"
end

-- ---------------------------------------------------------------------------
-- 1. the client has the APIs everything here is built on
-- ---------------------------------------------------------------------------

section("client API", function(t)
    for i = 1, table.getn(coreAPI) do
        t:ok(exists(coreAPI[i]), "the client has no " .. coreAPI[i])
    end

    --[[ Every registered module, not just the ones this class can run. The API
         surface does not vary by class, so a warrior's report should be worth
         exactly as much as a rogue's -- otherwise a missing GetComboPoints only
         ever shows up for the two classes that would notice anyway. ]]--
    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local m = OB.modules[id]

        for r = 1, table.getn(m.requires) do
            t:ok(exists(m.requires[r]), id .. " needs " .. m.requires[r])
        end
    end
end)

-- ---------------------------------------------------------------------------
-- 2. the widget methods the addon calls
-- ---------------------------------------------------------------------------

local probe

local function probeFrame()
    if not probe then
        probe = CreateFrame("Frame", "EquadisOmniBarsProbe", UIParent)
        probe:Hide()
        probe.tex = probe:CreateTexture(nil, "ARTWORK")
        probe.text = OB.NewText(probe, "OVERLAY", "GameFontNormal")
    end
    return probe
end

section("widget methods", function(t)
    local frame = probeFrame()

    for i = 1, table.getn(frameMethods) do
        t:ok(type(frame[frameMethods[i]]) == "function",
                "Frame has no " .. frameMethods[i])
    end
    for i = 1, table.getn(textureMethods) do
        t:ok(type(frame.tex[textureMethods[i]]) == "function",
                "Texture has no " .. textureMethods[i])
    end
    for i = 1, table.getn(textMethods) do
        t:ok(type(frame.text[textMethods[i]]) == "function",
                "FontString has no " .. textMethods[i])
    end
end)

-- ---------------------------------------------------------------------------
-- 3. the bars actually got built
-- ---------------------------------------------------------------------------

local function checkBar(t, bar, label)
    if not bar then
        t:ok(false, label .. " has no frame")
        return
    end

    t:ok(bar:GetWidth() > 0, label .. " has zero width")
    t:ok(bar:GetHeight() > 0, label .. " has zero height")
    t:ok(bar:GetNumPoints() > 0, label .. " is not anchored to anything")
end

section("bound modules", function(t)
    local seen = {}
    local count = 0

    for i = 1, table.getn(OB.barOrder) do
        local slotId = OB.barOrder[i]
        local m = OB.bound[slotId]

        if m then
            count = count + 1
            local slot = OB.profile.slots[slotId]

            -- the invariant hud.lua enforces at bind time, checked against what
            -- actually ended up bound
            t:ok(not seen[m.id], m.id .. " is bound to two slots at once")
            seen[m.id] = true
            t:ok(m.slotId == slotId,
                    m.id .. " thinks it is in " .. tostring(m.slotId)
                    .. " but is bound to " .. slotId)

            if m.renders == "segments" then
                checkBar(t, m.frame, slotId .. " group")
                for s = 1, (m.frame.visible or m.frame.count) do
                    checkBar(t, m.frame.bars[s], slotId .. " segment " .. s)
                end
            else
                checkBar(t, m.frame, slotId)
            end

            --[[ Only the hard direction is a check. A hidden slot must hide its
                 module, with no exceptions. The reverse is not a rule: combo
                 points hide themselves at zero, and a druid with no mana
                 baseline hides on purpose (constraint 19). A check that fails on
                 correct behaviour teaches people to ignore it, and then to
                 ignore the one next to it. ]]--
            if not slot.show and m.frame then
                t:ok(not m.frame:IsShown(),
                        slotId .. " is switched off but " .. m.id .. " is showing")
            end
        end
    end

    t:note(count .. " modules bound")

    --[[ IsShown, never IsVisible: IsVisible walks up to OB.container, which
         hideOOC legitimately hides, so out of combat every bar would "fail". ]]--
    local state = "shown"
    if not OB.container:IsShown() then state = "hidden" end

    t:note("HUD " .. state
            .. "  show=" .. tostring(OB.profile.show)
            .. " hideOOC=" .. tostring(OB.profile.hideOOC)
            .. " combat=" .. tostring(OB.inCombat)
            .. " stealth=" .. tostring(OB.inStealth))
end)

-- ---------------------------------------------------------------------------
-- 4. every font string has a font
--
-- The check for the bug that shipped. One proposition for the whole registry,
-- with the offenders named.
-- ---------------------------------------------------------------------------

section("font strings", function(t)
    local total = table.getn(OB.texts)
    local bad = 0
    local first

    for i = 1, total do
        if not OB.texts[i]:GetFont() then
            bad = bad + 1
            if not first then
                local ok, text = pcall(OB.texts[i].GetText, OB.texts[i])
                if ok and text and text ~= "" then first = text else first = "?" end
            end
        end
    end

    t:ok(bad == 0, bad .. " of " .. total .. " font strings have no font"
            .. " (first: " .. tostring(first) .. ")")

    -- a refactor that stops registering would otherwise pass by having nothing
    -- to check
    t:ok(total > 0, "the font string registry is empty")
    t:note(total .. " registered, all fonted")
end)

-- ---------------------------------------------------------------------------
-- 5. the numbers the bars draw from are numbers
-- ---------------------------------------------------------------------------

section("module values", function(t)
    local without = 0

    for slotId, m in pairs(OB.bound) do
        if not m.GetValue then
            without = without + 1
        else
            local ok, value, max = pcall(m.GetValue, m)

            if not ok then
                t:ok(false, m.id .. ":GetValue raised " .. tostring(value))
            else
                t:ok(type(value) == "number", m.id .. ":GetValue is not a number")

                -- the only NaN test available without math.huge
                if type(value) == "number" then
                    t:ok(value == value, m.id .. ":GetValue is NaN")
                end

                if type(max) == "number" then
                    t:ok(max == max, m.id .. ":GetValue max is NaN")
                    t:ok(value <= max,
                            m.id .. " reads " .. tostring(value)
                            .. " out of a maximum of " .. tostring(max))
                end
            end
        end
    end

    if without > 0 then t:note(without .. " modules have no GetValue") end
    if OB.testMode then t:note("test mode is on -- these are simulated") end
end)

-- ---------------------------------------------------------------------------
-- 6. the range readout found a backend it can actually run
-- ---------------------------------------------------------------------------

section("range backend", function(t)
    local m = OB.modules.distance
    if not m then
        t:note("the range module is not registered")
        return
    end

    t:ok(m.backend ~= nil, "the range readout has no backend at all")
    if not m.backend then return end

    local cfg = m:Config()

    -- not "did it probe once" but "would it still choose this now"
    t:ok(m.backend.Available(cfg) and true or false,
            "the " .. m.backend.id .. " backend is no longer available")

    if cfg.backend ~= "auto" then
        t:ok(m.backend.id == cfg.backend,
                "backend forced to " .. cfg.backend
                .. " but running " .. m.backend.id)
    end

    local note = m.backend.name
    if type(UnitXP) == "function" then
        note = note .. " (UnitXP present)"
    else
        note = note .. " (no UnitXP -- bands is the best available)"
    end
    if not OB.bound.distance then note = note .. ", bar not drawn" end

    t:note(note)
end)

-- ---------------------------------------------------------------------------
-- 7. the settings panel
-- ---------------------------------------------------------------------------

section("settings panel", function(t)
    local panel = OB.EnsurePanel()

    t:ok(panel ~= nil, "the panel could not be built: " .. tostring(OB.panelDead))
    if not panel then return end

    local faults = table.getn(OB.panelFaults)
    t:ok(faults == 0, faults .. " controls failed to build or update")
    for i = 1, faults do
        t:ok(false, "  " .. OB.panelFaults[i].label .. ": " .. OB.panelFaults[i].err)
    end

    t:ok(table.getn(panel.categories) == 4,
            "expected 4 categories, found " .. table.getn(panel.categories))

    --[[ Laid out with force, so the panel is measured while it stays hidden.
         Showing it would trip its OnHide on the way back out, which stops a
         preview the user might have running -- a self-test that changes what it
         is testing is not one. ]]--
    OB.RefreshPanel(true)

    local rows, unplaced, broken = 0, 0, 0

    for i = 1, table.getn(panel.categories) do
        local cat = panel.categories[i]
        local n = table.getn(cat.page.rows)

        t:ok(n > 0, "the " .. cat.name .. " page has no rows")
        rows = rows + n

        for r = 1, n do
            local widget = cat.page.rows[r]
            if widget.broken then broken = broken + 1 end
            if widget.visible and widget:GetNumPoints() == 0 then
                unplaced = unplaced + 1
            end
        end
    end

    t:ok(broken == 0, broken .. " rows gave up and were hidden")
    t:ok(unplaced == 0, unplaced .. " visible rows are unanchored")

    --[[ Every option the prompt offers has a control behind it. This catches the
         panel bug by its *symptom* rather than its cause, which is what makes it
         worth having: the next one will have a different cause. ]]--
    local missing = 0

    local function crossCheck(index)
        for key, w in pairs(index) do
            if not OB.widgets[OB.WidgetKey(w)] then missing = missing + 1 end
        end
    end

    crossCheck(OB.optionIndex.global)
    crossCheck(OB.optionIndex.slot)
    for id, index in pairs(OB.optionIndex.modules) do crossCheck(index) end

    t:ok(missing == 0, missing .. " options have no control on the panel")
    t:note(table.getn(panel.categories) .. " categories, " .. rows .. " rows")
end)

-- ---------------------------------------------------------------------------
-- running it
-- ---------------------------------------------------------------------------

-- pad a name out so the counts line up in a proportional font well enough to read
local function pad(name)
    local text = name
    while string.len(text) < 18 do text = text .. "." end
    return text
end

function OB.RunSelfTest()
    local passed, failed = 0, 0
    local failures = {}

    OB.Raw(GREY .. "OmniBars self-test " .. WHITE .. OB.version
            .. GREY .. ", " .. OB.class .. ", profile '" .. OB.profileName .. "'")

    for i = 1, table.getn(sections) do
        local s = sections[i]
        local t = newRecorder()

        --[[ Each section in its own pcall. One that throws reports itself as a
             single failure and the rest still run -- a self-test that stops
             early is one that silently passes everything it never reached. ]]--
        local ok, err = pcall(s.Run, t)
        if not ok then
            t.failed = t.failed + 1
            table.insert(t.failures, "the check itself raised: " .. tostring(err))
        end

        passed = passed + t.passed
        failed = failed + t.failed

        local line = "  " .. pad(s.name) .. " "
        if t.failed > 0 then
            line = line .. RED .. t.failed .. " failed" .. WHITE
        else
            line = line .. GREEN .. t.passed .. " ok" .. WHITE
        end

        if table.getn(t.notes) > 0 then
            line = line .. "   " .. GREY .. table.concat(t.notes, "  ")
        end

        OB.Raw(line)

        for f = 1, table.getn(t.failures) do
            table.insert(failures, t.failures[f])
        end
    end

    for i = 1, table.getn(failures) do
        OB.Raw("  " .. RED .. "FAIL " .. WHITE .. failures[i])
    end

    if failed == 0 then
        OB.Raw("  " .. GREEN .. passed .. " passed" .. WHITE .. ", 0 failed.")
    else
        OB.Raw("  " .. passed .. " passed, " .. RED .. failed .. " failed" .. WHITE .. ".")
    end

    OB.selfTestResult = { passed = passed, failed = failed, failures = failures }
    return passed, failed
end

OB.commands.selftest = {
    help = "check the addon against this client, not against the test stub",
    Run = function(args) OB.RunSelfTest() end,
}
