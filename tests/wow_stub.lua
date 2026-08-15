--[[ A fake Vanilla 1.12 client, enough of one to load and drive the addon.

  Run under LuaJIT (5.1 semantics -- the closest widely available match to the
  1.12 client's Lua 5.0). Nothing here is shipped: the TOC does not list this
  directory, and WoW only loads files a TOC names.

  Two deliberate choices:

  Widgets return real values, not nil. GetWidth after SetWidth gives the width
  back, GetChecked reflects SetChecked, and so on -- otherwise every arithmetic
  path in the addon (SetBarFill in particular, which multiplies by GetWidth)
  would silently short-circuit and the tests would pass by not executing.

  Unknown methods are answered by a recorded fallback rather than an error. A
  hard error would mean chasing every cosmetic call the addon makes; instead
  Stub.UnknownMethods() lists what got faked, so a typo'd API name shows up as
  an unexpected entry rather than hiding.
]]--

Stub = {}

local unknown = {}
local frames = {}
local clock = 10000

-- ---------------------------------------------------------------------------
-- widget objects
-- ---------------------------------------------------------------------------

local function noop() end

--[[ Fabricate a no-op for any method the stub does not implement, and record it.

     Only PascalCase keys are treated as methods. Every WoW widget method starts
     with a capital; every field the stub keeps state in is lowercase. Without
     that discriminator, reading an unset state field (self.checked, self.value)
     would hand back a function, which is truthy -- so `self.tex or create()`
     would never create, and GetChecked() would return a function. ]]--
local widgetMT = {}
widgetMT.__index = function(t, key)
    if type(key) ~= "string" then return nil end
    if not string.find(key, "^%u") then return nil end

    unknown[(rawget(t, "__objtype") or "?") .. ":" .. key] = true
    local fn = function() end
    rawset(t, key, fn)
    return fn
end

local function newObject(objtype)
    local o = setmetatable({}, widgetMT)
    o.__objtype = objtype
    return o
end

-- ---------------------------------------------------------------------------
-- regions: Texture and FontString
-- ---------------------------------------------------------------------------

local function definePoints(o)
    o.points = {}
    o.ClearAllPoints = function(self) self.points = {} end
    o.SetPoint = function(self, point, rel, relPoint, x, y)
        table.insert(self.points, { point, rel, relPoint, x, y })
    end
    o.GetNumPoints = function(self) return table.getn(self.points) end
    o.SetAllPoints = function(self) end
end

local function defineShow(o)
    o.shown = true
    o.Show = function(self) self.shown = true end
    o.Hide = function(self) self.shown = false end
    o.IsShown = function(self) return self.shown end
    o.IsVisible = function(self)
        if not self.shown then return false end
        local p = self.parent
        while p do
            if not p.shown then return false end
            p = p.parent
        end
        return true
    end
end

local function defineSize(o)
    o.width, o.height = 0, 0
    o.SetWidth = function(self, v) self.width = v end
    o.SetHeight = function(self, v) self.height = v end
    o.GetWidth = function(self) return self.width end
    o.GetHeight = function(self) return self.height end
end

local function newTexture(parent, layer)
    local t = newObject("Texture")
    t.parent = parent
    t.layer = layer
    definePoints(t)
    defineShow(t)
    defineSize(t)

    t.SetTexture = function(self, a, b, c, d)
        if type(a) == "string" then
            self.texture, self.rgba = a, nil
        else
            self.texture, self.rgba = nil, { a, b, c, d }
        end
    end
    t.GetTexture = function(self) return self.texture end
    t.SetVertexColor = function(self, r, g, b, a)
        self.vertex = { r, g, b, a }
    end
    t.SetTexCoord = function(self, ...)
        self.texcoord = { ... }
    end
    t.SetAlpha = function(self, v) self.alpha = v end
    t.GetAlpha = function(self) return self.alpha or 1 end
    return t
end

--[[ A FontString has no font object unless it inherited one from a template or
     was given one with SetFont, and in 1.12 touching the text or its colour
     before then is an error rather than a no-op.

     This is modelled rather than ignored because ignoring it shipped a dead
     settings panel with a green test suite: one `CreateFontString(nil, "OVERLAY")`
     followed by SetTextColor threw in the real client, aborted the panel build
     midway through a page, and the stub recorded the colour and said nothing.
     A stub that agrees with a wrong assumption still passes -- so where the rule
     is known, it belongs here. ]]--
local function newFontString(parent, layer, inherits)
    local f = newObject("FontString")
    f.parent = parent
    definePoints(f)
    defineShow(f)
    defineSize(f)

    if inherits then f.font = "inherited:" .. inherits end

    local function requireFont(self, what)
        if not self.font then
            error("FontString:" .. what .. " on a font string with no font: "
                    .. "create it with an inherited template, or call SetFont first", 3)
        end
    end

    f.text = ""
    f.SetText = function(self, v)
        requireFont(self, "SetText")
        self.text = v or ""
    end
    f.GetText = function(self) return self.text end
    f.SetFont = function(self, path, size, flags)
        self.font, self.fontSize, self.fontFlags = path, size, flags
    end
    f.GetFont = function(self) return self.font, self.fontSize, self.fontFlags end
    f.SetTextColor = function(self, r, g, b)
        requireFont(self, "SetTextColor")
        self.color = { r, g, b }
    end
    f.SetJustifyH = function(self, v) self.justify = v end
    f.SetAlpha = function(self, v) self.alpha = v end
    return f
end

-- ---------------------------------------------------------------------------
-- frames
-- ---------------------------------------------------------------------------

local templates = {}

templates.UICheckButtonTemplate = function(frame)
    if frame.name then
        _G[frame.name .. "Text"] = newFontString(frame, "OVERLAY", "GameFontNormal")
    end
end

templates.OptionsSliderTemplate = function(frame)
    if frame.name then
        _G[frame.name .. "Low"] = newFontString(frame, "OVERLAY", "GameFontNormal")
        _G[frame.name .. "High"] = newFontString(frame, "OVERLAY", "GameFontNormal")
        _G[frame.name .. "Text"] = newFontString(frame, "OVERLAY", "GameFontNormal")
    end
end

--[[ A scanning tooltip. Loading an item or a spell copies a block out of
     Stub.tooltips into the line font strings, which is the only part of a real
     tooltip the addon ever reads.

     These methods have to be real rather than left to the auto-faking metatable:
     NumLines answering nil would turn `for i = 1, tip:NumLines()` into an error
     rather than an empty loop, and the whole scrape would silently never run. ]]--
templates.GameTooltipTemplate = function(frame)
    frame.lines = {}
    frame.lineCount = 0

    frame.Line = function(self, i)
        if not self.lines[i] then
            self.lines[i] = newFontString(self, "OVERLAY", "GameTooltipText")
            if self.name then _G[self.name .. "TextLeft" .. i] = self.lines[i] end
        end
        return self.lines[i]
    end

    frame.ClearLines = function(self)
        self.lineCount = 0
        for i = 1, table.getn(self.lines) do self.lines[i]:SetText("") end
    end

    frame.NumLines = function(self) return self.lineCount end
    frame.SetOwner = function() end

    local function load(self, key)
        self:ClearLines()

        local block = Stub.tooltips[key]
        if not block then return end

        for i = 1, table.getn(block) do
            self:Line(i):SetText(block[i])
        end
        self.lineCount = table.getn(block)
    end

    frame.SetInventoryItem = function(self, unit, slot) load(self, "item" .. slot) end
    frame.SetSpell = function(self, index, bookType) load(self, "spell" .. index) end

    --[[ 1.12 has no GetActionSpell, so the only way to learn what an action
         button holds is to point a tooltip at it and read line one. The stub
         answers from Stub.actionBar, which maps slot -> name. ]]--
    frame.SetAction = function(self, slot)
        self:ClearLines()

        local name = Stub.actionBar and Stub.actionBar[slot]
        if not name then return end

        self:Line(1):SetText(name)
        self.lineCount = 1
    end
end

function CreateFrame(ftype, name, parent, template)
    local f = newObject(ftype or "Frame")
    f.frameType = ftype
    f.name = name
    f.parent = parent
    f.children = {}
    f.scripts = {}
    f.events = {}
    f.level = parent and ((parent.level or 0) + 1) or 0
    f.scale = 1

    definePoints(f)
    defineShow(f)
    defineSize(f)

    f.GetName = function(self) return self.name end
    f.GetParent = function(self) return self.parent end
    f.GetObjectType = function(self) return self.frameType end

    f.SetFrameLevel = function(self, v) self.level = v end
    f.GetFrameLevel = function(self) return self.level end

    f.SetScale = function(self, v) self.scale = v end
    f.GetScale = function(self) return self.scale end
    f.GetEffectiveScale = function(self)
        local s, p = self.scale, self.parent
        while p do s = s * (p.scale or 1); p = p.parent end
        return s
    end

    f.SetAlpha = function(self, v) self.alpha = v end
    f.GetAlpha = function(self) return self.alpha or 1 end

    f.EnableMouse = function(self, v) self.mouse = v and true or false end
    f.IsMouseEnabled = function(self) return self.mouse end

    f.SetScript = function(self, which, fn) self.scripts[which] = fn end
    f.GetScript = function(self, which) return self.scripts[which] end
    f.HasScript = function() return true end

    f.RegisterEvent = function(self, e) self.events[e] = true end
    f.UnregisterEvent = function(self, e) self.events[e] = nil end
    f.UnregisterAllEvents = function(self) self.events = {} end
    f.IsEventRegistered = function(self, e) return self.events[e] and true or false end

    f.CreateTexture = function(self, tname, layer)
        local t = newTexture(self, layer)
        if tname then _G[tname] = t end
        return t
    end
    f.CreateFontString = function(self, fname, layer, inherits)
        local s = newFontString(self, layer, inherits)
        if fname then _G[fname] = s end
        return s
    end

    -- statusbar / slider value state
    f.SetMinMaxValues = function(self, lo, hi) self.min, self.max = lo, hi end
    f.GetMinMaxValues = function(self) return self.min, self.max end
    f.SetValue = function(self, v)
        self.value = v
        local fn = self.scripts.OnValueChanged
        if fn then
            local saved = this
            this = self
            fn(v)
            this = saved
        end
    end
    f.GetValue = function(self) return self.value or 0 end
    f.SetValueStep = function(self, v) self.step = v end

    -- checkbutton
    f.SetChecked = function(self, v) self.checked = v and true or false end
    f.GetChecked = function(self) return self.checked end
    f.Disable = function(self) self.enabled = false end
    f.Enable = function(self) self.enabled = true end
    f.IsEnabled = function(self) return self.enabled ~= false end

    -- editbox
    f.SetText = function(self, v) self.text = v or "" end
    f.GetText = function(self) return self.text or "" end
    f.SetAutoFocus = noop
    f.SetMaxLetters = noop
    f.ClearFocus = noop
    f.SetFont = noop
    f.SetJustifyH = noop

    -- button textures
    f.SetNormalTexture = function(self, path)
        self.normalTex = self.normalTex or newTexture(self, "ARTWORK")
        self.normalTex.texture = path
    end
    f.SetPushedTexture = function(self, path)
        self.pushedTex = self.pushedTex or newTexture(self, "ARTWORK")
        self.pushedTex.texture = path
    end
    f.SetHighlightTexture = function(self, path)
        self.highlightTex = self.highlightTex or newTexture(self, "HIGHLIGHT")
        self.highlightTex.texture = path
    end
    f.GetNormalTexture = function(self) return self.normalTex end
    f.GetPushedTexture = function(self) return self.pushedTex end
    f.GetHighlightTexture = function(self) return self.highlightTex end

    f.SetBackdrop = function(self, bd) self.backdrop = bd end
    f.GetBackdrop = function(self) return self.backdrop end

    if name then _G[name] = f end
    if parent and parent.children then table.insert(parent.children, f) end
    table.insert(frames, f)

    if template and templates[template] then templates[template](f) end
    f.template = template

    return f
end

-- ---------------------------------------------------------------------------
-- driving the fake client
-- ---------------------------------------------------------------------------

function Stub.FireEvent(name, a1, a2, a3)
    local saved, savedA1 = event, arg1
    event, arg1, arg2, arg3 = name, a1, a2, a3

    for i = 1, table.getn(frames) do
        local f = frames[i]
        if f.events[name] and f.scripts.OnEvent then
            local savedThis = this
            this = f
            f.scripts.OnEvent()
            this = savedThis
        end
    end

    event, arg1 = saved, savedA1
end

function Stub.Tick(dt, count)
    count = count or 1
    for n = 1, count do
        clock = clock + (dt or 0.05)
        for i = 1, table.getn(frames) do
            local f = frames[i]
            if f.scripts.OnUpdate and f:IsVisible() ~= false then
                local savedThis = this
                this = f
                f.scripts.OnUpdate(dt or 0.05)
                this = savedThis
            end
        end
    end
end

function Stub.Click(frame, button)
    if not frame or not frame.scripts.OnClick then return false end
    local savedThis, savedArg = this, arg1
    this, arg1 = frame, button or "LeftButton"
    frame.scripts.OnClick()
    this, arg1 = savedThis, savedArg
    return true
end

function Stub.MouseDown(frame, button)
    if not frame or not frame.scripts.OnMouseDown then return false end
    local savedThis, savedArg = this, arg1
    this, arg1 = frame, button or "LeftButton"
    frame.scripts.OnMouseDown()
    this, arg1 = savedThis, savedArg
    return true
end

function Stub.MouseUp(frame)
    if not frame or not frame.scripts.OnMouseUp then return false end
    local savedThis = this
    this = frame
    frame.scripts.OnMouseUp()
    this = savedThis
    return true
end

--[[ Open a dropdown and return the buttons it offered. The initialiser calls
     UIDropDownMenu_AddButton once per entry, so collecting them is how a test
     sees the menu without a real UI. ]]--
local menuButtons
function Stub.OpenMenu(drop)
    menuButtons = {}
    if drop and drop.initialize then
        local savedThis = this
        this = drop
        drop.initialize()
        this = savedThis
    end
    return menuButtons
end

-- pick an entry from the menu the way a click would
function Stub.ChooseMenu(drop, value)
    local buttons = Stub.OpenMenu(drop)
    for i = 1, table.getn(buttons) do
        if buttons[i].value == value then
            local savedThis = this
            this = buttons[i]
            buttons[i].func()
            this = savedThis
            return true
        end
    end
    return false
end

function Stub.Frames() return frames end
function Stub.SetClock(t) clock = t end
function Stub.Clock() return clock end

function Stub.UnknownMethods()
    local list = {}
    for k in pairs(unknown) do table.insert(list, k) end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------------
-- the simulated character
-- ---------------------------------------------------------------------------

Stub.player = {
    class = "ROGUE",
    localizedClass = "Rogue",
    name = "Testchar",
    realm = "Turtle WoW",
    powerType = 3,
    power = 100,
    powerMax = 100,
    health = 2400,
    healthMax = 3000,
    combo = 0,
    mainSpeed = 2.6,
    offSpeed = 1.7,
    inCombat = false,
    dead = false,
    buffs = {},

    rangedSpeed = 2.9,

    -- what the target is, and how far away. hasTarget nil means none at all.
    hasTarget = false,
    targetDistance = 0,

    -- UnitStat indices: 4 intellect, 5 spirit
    stats = { [1] = 20, [2] = 20, [3] = 20, [4] = 100, [5] = 80 },

    -- GetSpellTexture by book index
    spellbook = {},

    -- spell names by book index, for the distance readout's auto-attack lookup
    spellNames = {},
    spellCount = 0,

    -- GetTalentInfo rank, keyed "tab:index"
    talents = {},
}

-- blocks of tooltip text, keyed "item<slot>" and "spell<bookIndex>"
Stub.tooltips = {}

function UnitClass(unit) return Stub.player.localizedClass, Stub.player.class end
function UnitName(unit) return Stub.player.name end
function GetRealmName() return Stub.player.realm end
function UnitPowerType(unit) return Stub.player.powerType end
function UnitMana(unit) return Stub.player.power end
function UnitManaMax(unit) return Stub.player.powerMax end
function UnitHealth(unit) return Stub.player.health end
function UnitHealthMax(unit) return Stub.player.healthMax end
function UnitAttackSpeed(unit) return Stub.player.mainSpeed, Stub.player.offSpeed end
function UnitAffectingCombat(unit) return Stub.player.inCombat end
function UnitIsDeadOrGhost(unit) return Stub.player.dead end
function GetComboPoints() return Stub.player.combo end
function GetPlayerBuffTexture(i) return Stub.player.buffs[i + 1] end

function UnitExists(unit)
    if unit == "player" then return 1, "0xPLAYER" end
    if Stub.player.hasTarget then return 1, "0xTARGET" end
    return nil
end

function GetUnitGUID(unit)
    if unit == "player" then return "0xPLAYER" end
    if Stub.player.hasTarget then return "0xTARGET" end
    return nil
end

function UnitRangedDamage(unit)
    return Stub.player.rangedSpeed, 40, 60, 0, 0, 100
end

function UnitStat(unit, index)
    local value = Stub.player.stats[index] or 0
    return value, value, 0, 0
end

function GetTalentInfo(tab, index)
    local rank = Stub.player.talents[tab .. ":" .. index] or 0
    return "Talent", "", 1, 1, rank, 5
end

function GetSpellTabInfo(tab)
    return "Class", "", 0, Stub.player.spellCount or 0
end

function GetSpellTexture(index, bookType)
    return Stub.player.spellbook[index]
end

--[[ Spell names by book index. Separate from `spellbook`, which holds textures:
     the druid mana scrape finds Bear Form by icon because the name is localised,
     while the distance readout has to match a name because Auto Shot and Shoot
     Gun share no icon distinction it can use.

     This is how a plain client tells a hunter's Auto Shot from a warrior's Shoot
     Gun -- the two fire the same gun to different distances, and getting it wrong
     told a warrior a forty-yard target was in range. ]]--
function GetSpellName(index, bookType)
    local name = Stub.player.spellNames and Stub.player.spellNames[index]
    if not name then return nil end
    return name, ""
end

function GetLocale() return Stub.locale or "enUS" end

--[[ Whether the target can be attacked. Hostile by default, because that is what
     a HUD is looking at almost all of the time -- and because
     CheckInteractDistance answers nothing about such a unit, which is the whole
     reason this matters. ]]--
function UnitCanAttack(attacker, unit)
    if not Stub.player.hasTarget then return nil end
    if Stub.player.friendlyTarget then return nil end
    return 1
end

--[[ UnitXP SP3's line-of-sight check, which is a *third* client mod -- separate
     from SuperWoW and from Nampower, and not installed on the development
     machine. Off unless a test asks, like every other injected API. ]]--
function Stub.SetLineOfSight(present)
    Stub.losAvailable = present and true or false
end

--[[ A Nampower build extended with a line of sight query, the way this
     installation's GetUnitDistance was. Shaped to match it: one unit token, and
     a plain boolean so "cannot tell" and "blocked" stay distinguishable. ]]--
function Stub.SetNampowerSight(present)
    if not present then
        IsUnitInSight = nil
        return
    end

    IsUnitInSight = function(unit)
        if not unit or not UnitExists(unit) then return nil end
        return Stub.player.inSight ~= false
    end
end

--[[ CheckInteractDistance's real thresholds: 1 inspect ~28yd, 2 trade ~11.1yd,
     3 duel ~9.9yd, 4 follow ~28yd.

     It answers nil, never false, and answers nil for a unit that cannot be
     interacted with at all -- which a hostile mob cannot. Stub.interactRefuses
     models exactly that case, because treating it as an error rather than as
     "too far" is the mistake the range module is written to avoid. ]]--
local INTERACT_YARDS = { 28, 11.11, 9.9, 28 }

function CheckInteractDistance(unit, index)
    if not Stub.player.hasTarget then return nil end
    if Stub.interactRefuses then return nil end

    --[[ **Hostile units answer nil at every index**, because duelling, trading
         and inspecting are all things you do to a player who is not trying to
         kill you. Modelled rather than glossed over: without it the stub happily
         measured range to a mob, which is the one target a HUD spends its whole
         life pointed at -- and the addon shipped a distance readout that only
         worked on friendly targets while the suite stayed green. ]]--
    if UnitCanAttack("player", unit) then return nil end

    local limit = INTERACT_YARDS[index]
    if limit and (Stub.player.targetDistance or 0) <= limit then return 1 end
    return nil
end

-- 1 in range, 0 out of range, nil when the slot is not range checked
function IsActionInRange(slot)
    if Stub.actionRange == nil then return nil end
    return Stub.actionRange
end

--[[ What is on the bars: slot -> the name its tooltip shows. Empty by default,
     because most players do not keep their auto-attack on a bar and the addon
     has to cope with not finding it. ]]--
Stub.actionBar = {}

function HasAction(slot)
    return Stub.actionBar[slot] and 1 or nil
end

function UseAction(slot, checkCursor, onSelf)
    Stub.lastAction = slot
end

--[[ Client-mod APIs.

     None of these come from an addon: they are injected into the Lua state by a
     DLL, so on a plain install they are simply absent and there is no version or
     flag to read. Tests put them in and take them out again to drive the
     distance module down each of its backends.

     Modelling them as *togglable* rather than always-present is the point. The
     addon spent three versions believing UnitXP was on the development machine
     because another addon referenced it, and every reading came from the
     coarsest backend as a result. A stub where the good path is always available
     would reproduce that mistake rather than catch it. ]]--

-- UnitXP_SP3's command dispatcher.
function Stub.SetUnitXP(present)
    if not present then
        --[[ The stock experience API already owns this global, and it does not
             complain about being handed a command name -- it just reads it as a
             unit token and finds no such unit.

             It used to `error` here, which was a flattering guess: it made a
             `pcall`-shaped probe look like it could tell the two apart when it
             could not. Returning quietly, the way the real function does, is
             what forces the addon to discriminate on the *answer* instead. ]]--
        UnitXP = function(unit)
            if unit ~= "player" then return nil end
            return Stub.player.xp or 0
        end
        return
    end

    UnitXP = function(command, a, b)
        if command == "nop" then return true end
        if command == "distanceBetween" then
            if b == "player" then return 0 end
            return Stub.player.targetDistance or 0
        end

        --[[ SP3's line-of-sight check. A separate opt-in from UnitXP itself,
             because a client can have the distance query without it -- and
             returning a number rather than a boolean is how the addon tells
             "cannot tell" from "blocked". ]]--
        if command == "inSight" then
            if not Stub.losAvailable then return 0 end
            return Stub.player.inSight ~= false
        end

        --[[ What an unrecognised command does, and the answer is "it depends on
             the build" -- which is the whole reason the addon must not probe
             here.

             SP3 is a *compatible replacement* for a global vanilla already owns,
             so a build that passes unit tokens through to the function it
             displaced is entirely reasonable. `Stub.unitXPPassthrough` models
             that build. A probe that concluded "this is the stock API" from a
             number came back saw one on this client and switched a working
             extension off. ]]--
        if Stub.unitXPPassthrough and command == "player" then
            return Stub.player.xp or 0
        end

        return nil
    end
end

--[[ World coordinates. The player sits at the origin and the target is placed
     along one axis, so the module's own three-dimensional maths has to run to
     get the distance back out -- a stub that returned the answer directly would
     not exercise it. ]]--
function Stub.SetUnitPosition(present)
    if not present then
        UnitPosition = nil
        return
    end

    --[[ Hostile targets answer nil here, which is a **conservative assumption
         rather than a verified fact**. It is modelled that way because it is the
         harder case: if SuperWoW turns out to answer for mobs too, an addon
         written against this still works, whereas one written against the
         optimistic model would fail on the only target a HUD ever points at.

         The reported symptom -- "range check only works on friendly targets" --
         is consistent with it, which is the other reason to assume it until
         someone checks in game. ]]--
    UnitPosition = function(unit)
        if unit == "player" or unit == "0xPLAYER" then return 0, 0, 0 end
        if not Stub.player.hasTarget then return nil end
        if unit == "target" and not Stub.player.friendlyTarget then return nil end
        if unit == "0xTARGET" then return nil end
        return Stub.player.targetDistance or 0, 0, 0
    end
end

--[[ Nampower: the engine's own range answers.

     Stub.spellRanges maps a spell name to { min, max }, so a test can give a
     hunter a dead zone and a wand none. IsSpellInRange returns the engine's
     boolean, computed from those same numbers, so the two can never disagree in
     a way the real client would not. ]]--
Stub.spellRanges = {}

function Stub.SetNampower(present)
    if not present then
        GetSpellIdForName = nil
        GetSpellRecField = nil
        GetSpellRangeData = nil
        IsSpellInRange = nil
        return
    end

    local ids, names = {}, {}
    local next = 1

    GetSpellIdForName = function(name)
        if not Stub.spellRanges[name] then return nil end
        if not ids[name] then
            ids[name] = next
            names[next] = name
            next = next + 1
        end
        return ids[name]
    end

    -- the range index is the spell id here; the indirection exists on the real
    -- client and is modelled only so the addon has to make both calls
    GetSpellRecField = function(id, field)
        if field ~= "rangeIndex" then return nil end
        return id
    end

    GetSpellRangeData = function(index)
        local name = names[index]
        if not name then return nil end
        local r = Stub.spellRanges[name]
        return r[1], r[2], 0, name
    end

    --[[ Takes a spell **name or id**, as Nampower's does. That matters: the
         addon has only a name unless the range-data APIs are also present, and a
         stub that insisted on an id made the whole spell backend look broken
         while the real one would have worked. ]]--
    IsSpellInRange = function(spell, unit)
        local name = names[spell]
        if not name and Stub.spellRanges[spell] then name = spell end
        if not name then return nil end
        if not Stub.player.hasTarget then return -1 end

        local r = Stub.spellRanges[name]
        local d = Stub.player.targetDistance or 0
        if d < r[1] then return 0 end
        if d > r[2] then return 0 end
        return 1
    end
end

-- Optional native extension proposed for Nampower. Stock 4.6.2 does not expose
-- this function even though its object manager already has both unit positions.
function Stub.SetNampowerDistance(present)
    if not present then
        GetUnitDistance = nil
        return
    end

    GetUnitDistance = function(unit)
        if unit == "player" or unit == "0xPLAYER" then return 0 end
        if not Stub.player.hasTarget then return nil end
        return Stub.player.targetDistance or 0
    end
end

-- ---------------------------------------------------------------------------
-- inventory
-- ---------------------------------------------------------------------------

--[[ What is worn, by slot number. Only the ranged slot (18) is populated, and
     only as { itemId, subtype } -- the distance module reads nothing else, and a
     fuller inventory model would be scenery. ]]--
Stub.equipped = {}

function GetInventoryItemLink(unit, slot)
    local item = Stub.equipped[slot]
    if not item then return nil end
    return "|cffffffff|Hitem:" .. item[1] .. ":0:0:0|h[Test Item]|h|r"
end

function GetInventorySlotInfo(name)
    if name == "RangedSlot" then return 18 end
    return 0
end

--[[ GetItemInfo's sixth return is the subtype, which is how the distance module
     tells a bow from a wand from a relic. The other returns are plausible
     filler; nothing reads them. ]]--
function GetItemInfo(item)
    local id = tonumber(item)
    if not id then
        local _, _, found = string.find(tostring(item), "item:(%d+)")
        id = tonumber(found)
    end
    if not id then return nil end

    for slot, entry in pairs(Stub.equipped) do
        if entry[1] == id then
            return "Test Item", "|Hitem:" .. id .. "|h", 2, 60, "Weapon", entry[2],
                    1, "Ranged", nil
        end
    end

    return nil
end

-- put a weapon of the given subtype in the ranged slot; nil empties it
function Stub.SetRanged(subtype)
    if not subtype then
        Stub.equipped[18] = nil
        return
    end
    Stub.equipped[18] = { 12345, subtype }
end

function GetTime() return clock end
function GetCursorPosition() return Stub.cursorX or 0, Stub.cursorY or 0 end
function PlaySound(name) Stub.lastSound = name end
function IsAddOnLoaded(name) return Stub.loadedAddons and Stub.loadedAddons[name] end

-- ---------------------------------------------------------------------------
-- globals the client provides
-- ---------------------------------------------------------------------------

_G = _G or getfenv(0)

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

--[[ The refusal strings, exactly as 1.12's GlobalStrings.lua spells them.
     `SPELL_FAILED_LINE_OF_SIGHT` is the one the client puts on screen and passes
     as UI_ERROR_MESSAGE's arg1; the other two do not exist in 1.12 and are left
     undefined on purpose, so anything that reads them has to cope with nil the
     way it must in game. ]]--
SPELL_FAILED_LINE_OF_SIGHT = "Target not in line of sight"

-- `UnitXP` is set up by Stub.SetUnitXP, which models both the stock experience
-- API and UnitXP_SP3's dispatcher. See the note there.

RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

Stub.chat = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(self, msg) table.insert(Stub.chat, msg) end,
}

function getglobal(name) return _G[name] end
function setglobal(name, v) _G[name] = v end
tinsert = table.insert
tremove = table.remove

UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}

Stub.popups = {}
function StaticPopup_Show(name)
    table.insert(Stub.popups, name)
    return StaticPopupDialogs[name]
end

-- accept a popup the way clicking its first button would
function Stub.AcceptPopup(name)
    local dialog = StaticPopupDialogs[name]
    if dialog and dialog.OnAccept then dialog.OnAccept() end
end

function ShowUIPanel(frame) if frame and frame.Show then frame:Show() end end
function HideUIPanel(frame) if frame and frame.Hide then frame:Hide() end end

BOOKTYPE_SPELL = "spell"

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetWidth(1024)
UIParent:SetHeight(768)

WorldFrame = CreateFrame("Frame", "WorldFrame")

ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame", UIParent)
ColorPickerFrame.rgb = { 1, 1, 1 }
ColorPickerFrame.SetColorRGB = function(self, r, g, b) self.rgb = { r, g, b } end
ColorPickerFrame.GetColorRGB = function(self)
    return self.rgb[1], self.rgb[2], self.rgb[3]
end
ColorPickerFrame:Hide()

OpacitySliderFrame = CreateFrame("Slider", "OpacitySliderFrame", UIParent)
OpacitySliderFrame:SetValue(0)

-- ---------------------------------------------------------------------------
-- dropdown API
-- ---------------------------------------------------------------------------

function UIDropDownMenu_Initialize(frame, fn) frame.initialize = fn end
function UIDropDownMenu_SetWidth(width, frame)
    if frame then frame.dropWidth = width end
end

--[[ SetSelectedValue calls UIDropDownMenu_Refresh on the real client, and Refresh
     both moves the check mark AND sets the label from the matching button. The
     addon therefore does not call SetText at all -- doing so alongside
     info.checked is what put several ticks in one menu (constraint 25).

     Modelled here rather than left as a bare assignment because a stub that only
     records the value cannot tell a working dropdown from one whose label never
     updates -- which is exactly the profile-switching bug that shipped: the
     profile changed, and the dropdown went on naming the old one. ]]--
function UIDropDownMenu_SetSelectedValue(frame, value)
    if not frame then return end

    frame.selectedValue = value
    frame.selectedText = nil

    if not frame.initialize then return end

    local buttons = Stub.OpenMenu(frame)
    for i = 1, table.getn(buttons) do
        if buttons[i].value == value then frame.selectedText = buttons[i].text end
    end
end

function UIDropDownMenu_SetText(text, frame)
    if frame then frame.selectedText = text end
end
function UIDropDownMenu_AddButton(info)
    if menuButtons then table.insert(menuButtons, info) end
end

return Stub
