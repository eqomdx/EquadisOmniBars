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
    t:ok(m.backend.Available(m) and true or false,
            "the " .. m.backend.id .. " backend is no longer available")

    if cfg.backend ~= "auto" then
        t:ok(m.backend.id == cfg.backend,
                "backend forced to " .. cfg.backend
                .. " but running " .. m.backend.id)
    end

    local note = m.backend.name
    if type(GetUnitDistance) == "function" then
        note = note .. " (Nampower exact hostile distance present)"
    elseif OB.HasUnitXP and OB.HasUnitXP() then
        note = note .. " (UnitXP exact hostile distance present)"
    elseif type(UnitPosition) == "function" then
        note = note .. " (SuperWoW exact friendly distance only)"
    else
        note = note .. " (no exact-distance API)"
    end
    if not OB.bound.distance then note = note .. ", bar not drawn" end

    t:note(note)

    --[[ The action slot is found rather than configured, so the only way to know
         whether the scan worked is to say what it found. "not on a bar" is a
         normal answer, not a fault: most players never put their auto-attack on
         one, and the backend simply goes unused. ]]--
    if m.spell then
        if m.actionSlot then
            t:note(m.spell .. " found on action slot " .. tostring(m.actionSlot))
        else
            t:note(m.spell .. " is not on an action bar")
        end
    end

    --[[ Which of the two line of sight routes this client is on, and it matters
         because they behave differently enough to be different features. The
         reactive one needs nothing installed but only knows after a shot has
         been refused; the continuous one can be asked. Reported rather than
         asserted -- neither is a failure. ]]--
    if cfg.losCheck then
        t:ok(OB.IsLineOfSightError(SPELL_FAILED_LINE_OF_SIGHT),
                "the client's line of sight message is not recognised")

        if type(IsUnitInSight) == "function" then
            t:note("line of sight: continuous, via a native IsUnitInSight")
        elseif OB.HasUnitXP and OB.HasUnitXP() then
            t:note("line of sight: continuous, via UnitXP_SP3")
        else
            t:note("line of sight: reactive -- known only after a refused shot,"
                    .. " and cleared a couple of seconds later")
        end
    end
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

--[[ A deliberately narrow runtime trace for the distance readout.

     The offline suite can prove that fallback order and drawing are internally
     consistent, but it cannot tell us what an injected API returns on this
     particular client build. Keep this as a command instead of permanent chat
     spam: target the unit that fails, run it once, and every value involved in
     choosing the yard count is visible. ]]--
local function positionResult(token)
    if type(UnitPosition) ~= "function" then return "API missing" end
    if not token then return "no token" end

    local ok, x, y, z = pcall(UnitPosition, token)
    if not ok then return "ERROR " .. tostring(x) end
    if type(x) ~= "number" or type(y) ~= "number" then
        return "nil (" .. tostring(x) .. ", " .. tostring(y) .. ", "
                .. tostring(z) .. ")"
    end

    return tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z)
end

--[[ Which of the five kinds of target this is, in the same words the report was
     asked for. The classification is printed rather than used: the point is that
     a run can be filed against the target type it came from, so five runs make a
     table instead of five opinions. ]]--
local function targetKind()
    if not UnitExists("target") then return "none" end

    local who = UnitIsPlayer("target") and "player" or "NPC"

    if UnitCanAttack("player", "target") then
        --[[ Attackable is not the same as hostile. A neutral mob can be attacked
             and will not attack back, which is exactly the case that has to be
             told apart from an enemy here. ]]--
        if UnitCanAttack("target", "player") then return "enemy " .. who end
        return "neutral " .. who
    end

    if UnitIsFriend("player", "target") then return "friendly " .. who end
    return "other " .. who
end

--[[ Every raw probe, one per line, named after the call that produced it. A
     value here is evidence; anything derived from it is not. ]]--
local function probe(label, fn, a, b, c)
    if type(fn) ~= "function" then
        OB.Raw("    " .. label .. ": API missing")
        return
    end

    local ok, value = pcall(fn, a, b, c)
    if not ok then
        OB.Raw("    " .. label .. ": " .. RED .. "ERROR " .. WHITE .. tostring(value))
        return
    end

    OB.Raw("    " .. label .. ": " .. tostring(value)
            .. " " .. GREY .. "(" .. type(value) .. ")" .. WHITE)
end

--[[ Can a **range ladder** be built here, and how fine would it be?

     The idea: `IsSpellInRange` is a boolean, but a boolean against a *known
     threshold* is one bit of a distance. Ask it about several spells with
     different maximum ranges and the answers bracket the target -- 0 for the
     35-yard spell and 1 for the 30 puts it between the two. That is the only
     route to a hostile yard figure that does not need native code, since
     IsSpellInRange is the one call on this client that answers about a mob.

     The first pass asked by **name** and every rung failed the same way, which
     turned out to be Nampower telling us how to do it properly:

       Unable to determine spell id from spell name, possibly because it isn't
       in your spell book.  Try IsSpellInRange(SPELL_ID) instead

     So the spellbook limit is on the name lookup, not on the range check. Asking
     by id should answer for any spell in the game, which is what the dense
     ladder needs. This pass asks by id.

     The ids are hardcoded and **not trusted**: each one is printed back with the
     name and range the client itself holds for it, so a wrong id shows up as a
     wrong name rather than quietly calibrating the ladder to the wrong distance.
     Reading the range from the client also means Turtle can have retuned any of
     them and the ladder still lands where the engine says it does.

     Candidates want a **zero minimum range**. Charge reads 0 both past 25 yards
     and inside 8, so a spell with a dead zone is not one threshold but two, and
     it breaks the ordering the method depends on. Charge is included anyway,
     precisely so the dead zone shows up in the output rather than being assumed
     away. ]]--
local LADDER = {
    { 2974, "Wing Clip" },          { 853, "Hammer of Justice" },
    { 19503, "Scatter Shot" },      { 5782, "Fear" },
    { 116, "Frostbolt" },           { 133, "Fireball" },
    { 635, "Holy Light" },          { 1130, "Hunter's Mark" },
    { 100, "Charge (has a dead zone)" },
}

local function rangeLadderProbe()
    OB.Raw("  " .. GREY .. "-- range ladder, asked by spell id --" .. WHITE)

    if type(IsSpellInRange) ~= "function" then
        OB.Raw("    IsSpellInRange missing -- no ladder is possible here")
        return
    end

    for i = 1, table.getn(LADDER) do
        local id, expected = LADDER[i][1], LADDER[i][2]

        --[[ What the client says this id actually is. The hardcoded label is
             only a note to the reader; this is the value that decides whether
             the id is right. ]]--
        local realName = "?"
        if type(GetSpellRecField) == "function" then
            local okName, value = pcall(GetSpellRecField, id, "name")
            if okName and type(value) == "string" then realName = value end
        end

        local dbc = "no data"
        if type(GetSpellRecField) == "function"
                and type(GetSpellRangeData) == "function" then
            local okIndex, index = pcall(GetSpellRecField, id, "rangeIndex")
            if okIndex and index then
                local okRange, minRange, maxRange = pcall(GetSpellRangeData, index)
                if okRange and type(maxRange) == "number" then
                    dbc = tostring(minRange) .. "-" .. tostring(maxRange)
                end
            end
        end

        local ok, result = pcall(IsSpellInRange, id, "target")
        local answer = ok and tostring(result) or ("ERROR " .. tostring(result))

        OB.Raw("    " .. id .. " " .. expected .. ": client=" .. realName
                .. " dbc=" .. dbc .. " inRange=" .. answer)
    end
end

function OB.RunRangeDebug()
    local m = OB.modules.distance
    if not m then
        OB.Raw(RED .. "Range debug: distance module is not registered")
        return
    end

    local exists, superGuid = UnitExists("target")
    local nampowerGuid
    if type(GetUnitGUID) == "function" then
        local ok, value = pcall(GetUnitGUID, "target")
        if ok then nampowerGuid = value end
    end
    local guid = superGuid or nampowerGuid

    OB.Raw(GREY .. "OmniBars range debug " .. WHITE .. OB.version
            .. GREY .. "  target type: " .. WHITE .. targetKind())
    OB.Raw("  target: exists=" .. tostring(exists)
            .. " name=" .. tostring(UnitName("target"))
            .. " attackable=" .. tostring(UnitCanAttack("player", "target"))
            .. " attacksYou=" .. tostring(UnitCanAttack("target", "player")))
    OB.Raw("  GUID: UnitExists=" .. tostring(superGuid)
            .. " GetUnitGUID=" .. tostring(nampowerGuid))

    --[[ The extension probes, before anything that depends on them. Getting
         these wrong is what disables a working install, so they are reported as
         what was asked and what came back rather than as a verdict. ]]--
    OB.Raw("  " .. GREY .. "-- client extensions --" .. WHITE)
    OB.Raw("    UnitXP global: " .. type(UnitXP)
            .. "  OB.HasUnitXP()=" .. tostring(OB.HasUnitXP()))
    probe("UnitXP('player')", UnitXP, "player")
    probe("UnitXP('inSight','player','player')", UnitXP, "inSight", "player", "player")
    probe("UnitXP('inSight','player','target')", UnitXP, "inSight", "player", "target")
    probe("UnitXP('distanceBetween','player','player')",
            UnitXP, "distanceBetween", "player", "player")
    probe("UnitXP('distanceBetween','player','target')",
            UnitXP, "distanceBetween", "player", "target")
    OB.Raw("  UnitPosition player: " .. positionResult("player"))
    OB.Raw("  UnitPosition target: " .. positionResult("target"))
    OB.Raw("  UnitPosition GUID: " .. positionResult(guid))

    local nativeDistance = "API missing"
    if type(GetUnitDistance) == "function" then
        local ok, value = pcall(GetUnitDistance, "target")
        nativeDistance = ok and tostring(value) or ("ERROR " .. tostring(value))
    end
    OB.Raw("  GetUnitDistance target: " .. nativeDistance)

    local exact = OB.UnitDistance("target")
    OB.Raw("  exact distance: " .. tostring(exact))

    local rangeResult = "API/spell unavailable"
    if type(IsSpellInRange) == "function" and (m.spellId or m.spell) then
        local ok, value = pcall(IsSpellInRange, m.spellId or m.spell, "target")
        rangeResult = ok and tostring(value) or ("ERROR " .. tostring(value))
    end
    OB.Raw("  weapon spell: " .. tostring(m.spell) .. " id="
            .. tostring(m.spellId) .. " good=" .. tostring(m.minRange)
            .. "-" .. tostring(m.maxRange) .. " IsSpellInRange=" .. rangeResult)

    --[[ The coarse fallback, spelled out. CheckInteractDistance answers nil for
         anything attackable, which is the single fact behind "it only works on
         friendly targets" -- so it is worth seeing rather than inferring. ]]--
    OB.Raw("  " .. GREY .. "-- CheckInteractDistance --" .. WHITE)
    probe("index 1 (inspect ~28y)", CheckInteractDistance, "target", 1)
    probe("index 3 (duel ~9.9y)", CheckInteractDistance, "target", 3)

    OB.Raw("  action slot: " .. tostring(m.actionSlot))
    if m.actionSlot then
        probe("IsActionInRange(slot)", IsActionInRange, m.actionSlot)
    end

    rangeLadderProbe()

    --[[ Every backend asked both questions in turn, against the target actually
         selected. "available but declines" and "never considered" look identical
         from the outside and have completely different fixes. ]]--
    OB.Raw("  " .. GREY .. "-- backends, against this target --" .. WHITE)

    --[[ Reading every backend walks paths the live readout would have skipped,
         and `bands` arms a warning when it meets an attackable unit. Left alone,
         the diagnostic prints a complaint it caused itself -- which is exactly
         the sort of thing a diagnostic must never do. ]]--
    local blindBefore, warnedBefore = m.blindToHostiles, m.warnedHostile

    for i = 1, table.getn(OB.rangeOrder) do
        local backend = OB.rangeBackends[OB.rangeOrder[i]]

        local okA, available = pcall(backend.Available, m)
        local line = "    " .. backend.id .. ": available="
                .. (okA and tostring(available) or (RED .. "ERROR" .. WHITE))

        local okR, state, yards = pcall(backend.Read, m)
        if okR then
            line = line .. " state=" .. tostring(state) .. " yards=" .. tostring(yards)
        else
            line = line .. " read=" .. RED .. "ERROR " .. WHITE .. tostring(state)
        end

        if backend == m.backend then line = line .. GREY .. "  <- selected" .. WHITE end
        OB.Raw(line)
    end

    m.blindToHostiles, m.warnedHostile = blindBefore, warnedBefore

    local state, yards = m:Read()
    OB.Raw("  " .. GREY .. "-- result --" .. WHITE)
    OB.Raw("  selected=" .. tostring(m.backend and m.backend.id)
            .. " answered=" .. tostring(m.answered and m.answered.id)
            .. " state=" .. tostring(state) .. " yards=" .. tostring(yards)
            .. " shown=" .. tostring(m.frame and m.frame:IsShown()))
end

OB.commands.rangedebug = {
    help = "report every client value used by the distance readout",
    Run = function(args) OB.RunRangeDebug() end,
}
