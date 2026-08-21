--[[ Equadis' Classic Overhaul :: damage meter

  Who is doing the damage, and the healing.

  A feature module: it owns a window rather than a bar in the cluster, and shares
  the event map, the dirty-flag redraw and the look with everything else.

  Reads OB.ReadCombatLine, which is the ShaguDPS-derived parser -- see
  modules/parser.lua and NOTICE. Nothing about locales or sentences reaches this
  file: it is handed a source, a spell, a target, an amount and a kind, and its
  only job is to keep the running totals and draw them.

  **Two segments, always both.** `overall` runs until you reset it; `current`
  starts fresh at each pull. Kept simultaneously rather than switching, because
  the moment anyone wants the other one the fight is over and recomputing it is
  impossible. Two counters is cheaper than a decision that cannot be undone.
]]--

local OB = EquadisClassicOverhaul

-- ---------------------------------------------------------------------------
-- the running totals
-- ---------------------------------------------------------------------------

--[[ Two segments, each holding damage and healing keyed by player name, plus
     when the segment started -- which is what turns a total into a rate. ]]--
--[[ Three buckets, and the third is not a variation on the first two.

     `damage` and `heal` are keyed by **who did it**. `taken` is keyed by **who
     it happened to**, which is the whole reason it is a separate bucket rather
     than a filter: a tank wants to know what they are absorbing, and the source
     of it is a boss they cannot influence. Same lines, opposite end. ]]--
--[[ `spells` is the same three buckets broken down one level further:

       spells[bucket][source][spellName] = amount

     Kept alongside the totals rather than derived from them, because a total is
     a sum and a sum cannot be taken apart afterwards. It is what the hover
     breakdown reads -- "where did those forty thousand come from" -- and that
     question is only ever asked after the fight, when recomputing is impossible.

     The cost is one table per player per fight, which is nothing next to being
     unable to answer. ]]--
local function newSegment(now)
    return {
        damage = {}, heal = {}, taken = {},
        spells = { damage = {}, heal = {}, taken = {} },
        started = now, last = now,
    }
end

function OB.NewDamageData(now)
    return { overall = newSegment(now), current = newSegment(now) }
end

--[[ One line's worth into the spell breakdown, building the two levels of table
     it needs on the way. Separate from AddCombatLine so the nesting is written
     once rather than twice -- damage and taken both go through it. ]]--
local function addSpell(segment, bucket, who, spell, amount)
    if not who then return end

    local byName = segment.spells[bucket]
    if not byName then return end

    if not byName[who] then byName[who] = {} end
    byName[who][spell] = (byName[who][spell] or 0) + amount
end

--[[ Add one parsed line to both segments.

     `last` moves with every line rather than with the clock, so a fight's
     duration is the span that actually had damage in it. Idle time between pulls
     would otherwise divide into the rate and make everyone look worse the longer
     they stood still. ]]--
function OB.AddCombatLine(data, line, now)
    if not data or not line then return end
    if not line.amount or line.amount <= 0 then return end

    local bucket = line.kind == "heal" and "heal" or "damage"

    --[[ A swing has no spell, and it is still the answer to "where did that come
         from" -- usually the biggest part of it. Named rather than skipped, or
         the breakdown would omit most of a warrior's damage. ]]--
    local spell = line.spell or "Melee"

    local segments = { data.overall, data.current }
    for i = 1, table.getn(segments) do
        local segment = segments[i]

        segment[bucket][line.source] =
                (segment[bucket][line.source] or 0) + line.amount

        addSpell(segment, bucket, line.source, spell, line.amount)

        --[[ The same line counted a second time, under whoever received it.
             Only damage: healing taken is healing done seen from the other side
             and putting it here would double every healer's row. ]]--
        if bucket == "damage" and line.target then
            segment.taken[line.target] =
                    (segment.taken[line.target] or 0) + line.amount

            addSpell(segment, "taken", line.target, spell, line.amount)
        end

        segment.last = now
    end
end

--[[ One player's damage broken down by spell, biggest first.

     Built on demand rather than kept sorted, because it is read on hover and
     written on every combat line: sorting once per hover is free, sorting once
     per hit is not. ]]--
function OB.DamageSpells(segment, bucket, name)
    local out = {}
    if not segment or not segment.spells then return out end

    local byName = segment.spells[bucket]
    if not byName or not byName[name] then return out end

    local sum = 0
    for spell, amount in pairs(byName[name]) do
        table.insert(out, { name = spell, total = amount })
        sum = sum + amount
    end

    for i = 1, table.getn(out) do
        out[i].share = sum > 0 and (out[i].total / sum) or 0
    end

    table.sort(out, function(a, b)
        if a.total == b.total then return a.name < b.name end
        return a.total > b.total
    end)

    return out
end

--[[ Seconds a segment has been running, floored at one.

     Floored because the first line of a fight arrives at zero elapsed, and
     dividing by that is either an error or an infinity depending on the platform
     -- neither of which belongs in a number somebody reads mid-pull. ]]--
function OB.SegmentDuration(segment)
    if not segment then return 1 end

    local span = (segment.last or 0) - (segment.started or 0)
    if span < 1 then return 1 end
    return span
end

--[[ A segment's grand total for one bucket, which is what the header reports.

     Summed rather than kept as a running counter, because a counter is a second
     source of truth for something already stored and the two only ever diverge
     one way: silently. ]]--
function OB.SegmentTotal(segment, bucket)
    if not segment then return 0 end

    local sum = 0
    for name, amount in pairs(segment[bucket] or {}) do sum = sum + amount end
    return sum
end

--[[ One segment's rows, highest first: { name, total, perSecond, share }.

     Sorted by total rather than by rate. A meter answers "who did the work",
     and rate is the same ordering divided by a constant -- except for somebody
     who joined late, where rate flatters them for having been there less. Name
     breaks a tie so the list does not shuffle between identical readings. ]]--
function OB.DamageRows(segment, bucket)
    local rows = {}
    if not segment then return rows end

    local totals = segment[bucket] or {}
    local sum = 0

    for name, amount in pairs(totals) do
        table.insert(rows, { name = name, total = amount })
        sum = sum + amount
    end

    local duration = OB.SegmentDuration(segment)

    for i = 1, table.getn(rows) do
        rows[i].perSecond = rows[i].total / duration
        rows[i].share = sum > 0 and (rows[i].total / sum) or 0
    end

    table.sort(rows, function(a, b)
        if a.total == b.total then return a.name < b.name end
        return a.total > b.total
    end)

    return rows
end

-- ---------------------------------------------------------------------------
-- module
-- ---------------------------------------------------------------------------

--[[ What one window shows. A meter is several windows over one set of totals --
     damage in one, healing beside it -- so everything that differs between them
     lives here and everything that is counted lives in the data above. ]]--
local function newWindow(x, y)
    return {
        mode = "damage",
        segment = "current",

        x = x or 0, y = y or 0,
        width = 220,
        height = 15,
        rows = 10,
        locked = false,

        bg = { 0, 0, 0, 0.5 },
        headerColor = { 0, 0, 0, 0.5 },

        --[[ Nothing between rows by default: the border pad is already the only
             spacing a bordered window needs, and a gap on top of it is a stripe
             of background rather than breathing room. Yours to add. ]]--
        gap = 0,

        showRank = true,
        showTotal = true,
        showPerSecond = true,
        showPercent = true,

        --[[ Two colours, in one order: bar, then class. The bar colour is what
             a row is unless something knows better, and class knows better
             because it is how you find a name in a list.

             The threat meter has a third above these -- your own pull ramp --
             and the rule there is the same rule: the fallback is the dullest of
             the options and never the loudest. ]]--
        barColor = { 0.35, 0.42, 0.55, 1 },
        classColor = true,
    }
end

local M = OB.RegisterModule({
    id = "damage",
    name = "Damage Meter",
    feature = true,
    defaultEnabled = false,
    renders = "window",
    tickly = true,


    --[[ **Draws with the shared look**, so its page carries the texture, font,
         size, outline and border rows.

         Declared rather than inferred, because nothing about a module implies
         it: `renders` says "none" for nameplates and unit frames, which draw
         into the client's frames and use every one of the five.

         Chat, the roster and quality of life do not have this, and action bars
         gave it up -- they use a font and nothing else, so three of the five
         rows were controls that did nothing. ]]--
    styled = true,
    description = "Damage and healing done, parsed from the combat log."
            .. " The parser is derived from ShaguDPS, which reads the 1.12 log"
            .. " without matching translated strings -- so it works on any"
            .. " locale, including this one.",

    defaults = {
        windows = { newWindow(0, 0) },

        mergePets = true,
        trackAll = false,
        resetOnPull = true,

        --[[ Redraws per second. Per-second figures keep moving between events --
             the totals only change on a hit, but the seconds they are divided
             by do not -- so this is a real speed rather than a throttle.

             Two by default. Ten reads as live and costs five times as much on a
             fight where the numbers barely move; one is calm and lags a burst.
             Which of those is right is a taste, so it is a setting. ]]--
        updateRate = 2,
    },

    --[[ The panel edits **window one**. Everything a second window differs in is
         reached from its own header, which is where you are standing when you
         want it -- putting a second copy of every row on the page would double
         its length to configure something you can click. ]]--
    --[[ Three sections, and the second column picks between them. A `section`
         marker is not a row: it stamps every row after it until the next one.

         Window is what the meter *is* -- where, how big, what it counts. Bar is
         one row's shape and colour. Text is what a row says. Split that way
         because those are three separate sittings: you place a window once, tune
         the bars when you dislike how they look, and change the columns when you
         want a different question answered. ]]--
    options = {
        { "Window", "__s_window", "section", "window" },
        { "Reset On Pull", "resetOnPull", "boolean" },
        --[[ Nearby *players*, told from mobs by the roster -- so an unswept
             realm sees fewer of them and the Chat Scan is what fills that in. ]]--
        { "Track Nearby Players", "trackAll", "boolean" },
        { "Updates Per Second", "updateRate", "slider", 1, 10, 1 },
        { "Width", "windows.1.width", "slider", 100, 500, 1 },
        { "Rows Shown", "windows.1.rows", "slider", 3, 40, 1 },
        { "X Position", "windows.1.x", "slider", -2000, 2000, 1 },
        { "Y Position", "windows.1.y", "slider", -2000, 2000, 1 },
        { "Lock All Windows", "windows.1.locked", "boolean" },
        { "Background Color", "windows.1.bg", "color", true },
        { "Header Color", "windows.1.headerColor", "color", true },

        { "Bar", "__s_bar", "section", "bar" },
        { "Height", "windows.1.height", "slider", 8, 32, 1 },
        { "Gap Between Bars", "windows.1.gap", "slider", 0, 12, 1 },

        --[[ The winner first, the fallback under it: class colour overrides the
             swatch on every row it can resolve, which is most of them. The
             swatch is dimmed while it does, so the page shows which one is in
             charge rather than leaving you to work it out. ]]--
        { "Color Rows By Class", "windows.1.classColor", "boolean" },
        { "Bar Color", "windows.1.barColor", "color", true,
          nil, nil, nil, nil, "windows.1.classColor" },

        { "Text", "__s_text", "section", "text" },
        { "Rank Number", "windows.1.showRank", "boolean" },
        { "Total", "windows.1.showTotal", "boolean" },
        { "Per Second", "windows.1.showPerSecond", "boolean" },
        { "Percentage", "windows.1.showPercent", "boolean" },
    },

    requires = { "UnitName" },
})

function M:Config()
    return OB.profile.modules.damage
end

function M:Window(index)
    return self:Config().windows[index]
end

--[[ Every combat log event the parser knows, plus the two that bracket a fight.

     Built from the parser rather than listed again, so a sentence added there is
     listened for without a second edit here. ]]--
local function damageEvents()
    --[[ Guarded, because this runs at file scope: if the parser is missing --
         a TOC line lost, a load order changed -- an unguarded call throws here
         and takes the rest of this file with it, so the module would vanish from
         the settings panel entirely rather than appear and do nothing. ]]--
    local events = {}
    if OB.CombatLogEvents then events = OB.CombatLogEvents() end

    table.insert(events, "PLAYER_REGEN_DISABLED")
    table.insert(events, "PLAYER_REGEN_ENABLED")
    return events
end

M.events = damageEvents()

--[[ Whether this line is worth counting.

     Off, the meter follows your group, because a raid boss's own damage in the
     list is noise -- you cannot improve it and it dwarfs everybody.

     **On, it follows nearby *players*, which is what the row says.** It used to
     return true for every line in the log, so the boss, its adds and every
     critter in earshot arrived in the list under their own names. That is not
     "track nearby players", it is "track everything", and the two differ by
     exactly the thing the setting is for.

     **The roster is what tells a player from a mob.** Every path into it --
     friends, guild, raid, party, a friendly target, a `/who` answer -- is
     player-only, so a name being in it is proof. A name that is not in it is
     not proof of anything, which is the honest limit: 1.12 hands the combat log
     over as text and there is nothing in a line that says what kind of thing
     said it.

     So an unswept realm sees fewer names than it might, and the Chat Scan on the
     Chat page is what fills that in. That is a real dependency and it is better
     than the alternative, which was a damage meter with Ragnaros at the top. ]]--
function M:Counts(line)
    if not line.source then return false end

    if line.source == UnitName("player") then return true end
    if OB.GroupClass(line.source) ~= nil then return true end

    if not self:Config().trackAll then return false end

    return (OB.roster and OB.roster[line.source]) ~= nil
end

function M:OnEvent()
    local now = GetTime()

    if event == "PLAYER_REGEN_DISABLED" then
        --[[ A pull starts the current segment over, if asked. The overall one is
             deliberately untouched: it is the thing you would have lost by
             switching, which is why both are kept. ]]--
        --[[ Built by the factory, **never by hand**. This wrote the segment's
             fields out literally, so when `spells` was added for the hover
             breakdown this one segment came into the world without it -- and
             every hit after the next pull threw on `segment.spells[bucket]`.

             The shape of a segment is one function's business. Anything that
             makes one and is not that function is a second definition waiting
             to fall behind the first. ]]--
        if self:Config().resetOnPull then
            self.data.current = newSegment(now)
        end

        OB.SetDirty(self)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        OB.SetDirty(self)
        return
    end

    local line = OB.ReadCombatLine(event, arg1)
    if not line then return end
    if not self:Counts(line) then return end

    OB.AddCombatLine(self.data, line, now)
    OB.SetDirty(self)
end

function M:Reset()
    self.data = OB.NewDamageData(GetTime())
    OB.SetDirty(self)
end

-- ---------------------------------------------------------------------------
-- the header
-- ---------------------------------------------------------------------------

local SEGMENTS = {
    { "current", "Current" },
    { "overall", "Overall" },
}

--[[ Damage and DPS are the same numbers with different columns showing, which
     is why ShaguDPS's four modes collapse to three here plus a column switch:
     picking "DPS" there is picking a column, and a column is already a
     setting. ]]--
local MODES = {
    { "damage", "Damage" },
    { "heal", "Healing" },
    { "taken", "Taken" },
}

local function labelFor(list, value)
    for i = 1, table.getn(list) do
        if list[i][1] == value then return list[i][2] end
    end
    return value
end

--[[ A small popup of buttons under a header button.

     One menu frame, reused: it is only ever open under one button at a time, and
     a pool per button would be six frames doing one frame's work. ]]--
local function ensureMenu(window)
    if window.menu then return window.menu end

    local menu = CreateFrame("Frame", nil, window)
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop(OB.backdrop)
    menu:SetBackdropColor(0.08, 0.08, 0.09, 0.95)
    menu:Hide()
    menu.items = {}

    window.menu = menu
    return menu
end

local function openMenu(window, anchor, list, current, onPick)
    local menu = ensureMenu(window)

    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(72)
    menu:SetHeight((table.getn(list) * 16) + 10)

    for i = 1, table.getn(list) do
        local item = menu.items[i]

        if not item then
            item = CreateFrame("Button", nil, menu)
            item:SetWidth(64)
            item:SetHeight(16)
            item:SetHighlightTexture(
                    "Interface\\QuestFrame\\UI-QuestTitleHighlight")

            item.text = OB.NewText(item, "OVERLAY", "GameFontNormalSmall")
            item.text:SetAllPoints(item)
            item.text:SetJustifyH("LEFT")

            menu.items[i] = item
        end

        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, -(5 + ((i - 1) * 16)))
        item.text:SetText(list[i][2])

        if list[i][1] == current then
            item.text:SetTextColor(1, 0.82, 0)
        else
            item.text:SetTextColor(0.8, 0.8, 0.8)
        end

        item.value = list[i][1]
        item:SetScript("OnClick", function()
            onPick(this.value)
            menu:Hide()
        end)

        item:Show()
    end

    for i = table.getn(list) + 1, table.getn(menu.items) do
        menu.items[i]:Hide()
    end

    if menu:IsShown() then menu:Hide() else menu:Show() end
end

--[[ One header button carrying a caption that changes: the segment and the
     mode, which are the two that have to say what they currently are. ]]--
local function headerButton(parent, width, caption)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(14)
    b:SetBackdrop(OB.backdrop)
    b:SetBackdropColor(0.2, 0.2, 0.22, 1)
    b:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    b.text = OB.NewText(b, "OVERLAY", "GameFontNormalSmall")
    b.text:SetAllPoints(b)
    b.text:SetJustifyH("CENTER")
    b.text:SetText(caption)

    --[[ White. GameFontNormalSmall is Blizzard's gold, which on a header means
         "selected" everywhere else in this interface -- so both buttons read as
         highlighted at once and neither one stood out when it was. ]]--
    b.text:SetTextColor(1, 1, 1)

    return b
end

-- ---------------------------------------------------------------------------
-- one window
-- ---------------------------------------------------------------------------

local HEADER_H = OB.HEADER_H
local GRIP = 14

function M:BuildWindow(index)
    local f = CreateFrame("Frame", "EqOBDamage" .. index, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)

    --[[ **Deliberately not SetClampedToScreen.**

         It was here, and it is what stacked two windows on an ultrawide monitor
         after every reload. 1.12 predates widescreen: UIParent is not the
         monitor, and the client's clamp pulls anything outside *its* idea of the
         screen back to that edge -- both windows, to the same edge, on the next
         show. Which is exactly the symptom, and why it survived two rounds of
         looking at our own arithmetic.

         M:RescueWindow does the job instead, and does less of it on purpose: it
         moves a window only when its centre is genuinely unreachable, so a
         window parked out on the wide part of an ultrawide is left alone. ]]--
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f.index = index
    f.rows = {}

    f:SetScript("OnDragStart", function()
        local cfg = OB.modules.damage:Window(this.index)
        if not cfg or cfg.locked then return end
        this:StartMoving()
    end)

    f:SetScript("OnDragStop", function()
        OB.modules.damage:StoreWindowPosition(this)
    end)

    --[[ The header strip, left to right:

           settings  open this subsystem's tab            (cog)
           lock      lock or unlock this window           (padlock, toggles)
           segment   Current or Overall                  (menu)
           mode      Damage, Healing or Taken             (menu)
           chat      report the current list
           close     close this window                    (X)
           reset     reset the meter                      (circular arrow)
           new       open another window                  (+)

         Reset is a dedicated icon immediately left of + on the master window.
         Extra windows keep their X instead; the data belongs to the meter, not
         to an individual view. ]]--
    --[[ The header drags the window, which is where everybody reaches for it.

         It has to say so itself: it is a child frame with the mouse enabled, so
         it swallows the press before the window under it ever sees one, and the
         window's own OnDragStart never fired from the only place a person aims
         at. The body was draggable the whole time and the strip people actually
         grab was dead. ]]--
    local head = CreateFrame("Frame", nil, f)
    head:SetHeight(HEADER_H)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    f.head = head

    head:SetScript("OnDragStart", function()
        local frame = this:GetParent()
        local cfg = OB.modules.damage:Window(frame.index)
        if not cfg or cfg.locked then return end
        frame:StartMoving()
    end)

    head:SetScript("OnDragStop", function()
        OB.modules.damage:StoreWindowPosition(this:GetParent())
    end)

    head.bg = head:CreateTexture(nil, "BACKGROUND")
    head.bg:SetAllPoints(head)

    --[[ One surface under every row, so a gap between two of them shows the
         window rather than whatever is behind it. See StyleWindow. ]]--
    f.body = f:CreateTexture(nil, "BACKGROUND")

    head.settings = OB.IconButton(head, "settings")
    head.lock     = OB.IconButton(head, "unlock")
    head.segment  = headerButton(head, 56, "Current")
    head.mode     = headerButton(head, 56, "Damage")
    head.close    = OB.IconButton(head, "close")
    head.reset    = OB.IconButton(head, "reset")
    head.new      = OB.IconButton(head, "new")

    --[[ **Every button carries its own window**, rather than walking up two
         parents to find it.

         `this:GetParent():GetParent()` is one refactor away from pointing at the
         wrong frame -- wrap a button in a container, or hang one off the window
         instead of the header, and it silently resolves to something with no
         `index`. Then `Window(nil)` is nil and the handler dies on the next
         line, which is the "attempt to index local 'cfg'" that was reported for
         the padlock. Storing the window removes the walk and the whole class of
         failure with it.

         The handlers below also refuse to run on a window that has gone rather
         than erroring: a click that arrives after RemoveWindow has renumbered
         things should do nothing, not break the frame it landed on. ]]--
    local buttons = { head.settings, head.lock, head.segment, head.mode,
                      head.close, head.reset, head.new }

    for i = 1, table.getn(buttons) do buttons[i].window = f end

    head.settings:SetScript("OnClick", function()
        OB.OpenPanelAt("Damage Meter")
    end)

    --[[ The lock is per window, so a window parked over the action bars can be
         nailed down while the one you are still placing stays draggable. ]]--
    head.lock:SetScript("OnClick", function()
        local frame = this.window
        local cfg = OB.modules.damage:Window(frame.index)
        if not cfg then return end

        cfg.locked = not cfg.locked

        OB.modules.damage:StyleWindow(frame)
        OB.RefreshPanel()
    end)

    head.segment:SetScript("OnClick", function()
        local frame = this.window
        local cfg = OB.modules.damage:Window(frame.index)
        if not cfg then return end

        openMenu(frame, this, SEGMENTS, cfg.segment, function(value)
            cfg.segment = value
            OB.modules.damage:StyleWindow(frame)
            OB.SetDirty(OB.modules.damage)
            OB.RefreshPanel()
        end)
    end)

    head.mode:SetScript("OnClick", function()
        local frame = this.window
        local cfg = OB.modules.damage:Window(frame.index)
        if not cfg then return end

        openMenu(frame, this, MODES, cfg.mode, function(value)
            cfg.mode = value
            OB.modules.damage:StyleWindow(frame)
            OB.SetDirty(OB.modules.damage)
            OB.RefreshPanel()
        end)
    end)

    head.close:SetScript("OnClick", function()
        OB.modules.damage:RemoveWindow(this.window.index)
    end)

    head.reset:SetScript("OnClick", function()
        OB.modules.damage:Reset()
    end)

    head.new:SetScript("OnClick", function()
        OB.modules.damage:AddWindow()
    end)

    --[[ The resize grip, bottom right. Hidden when the window is locked, because
         a lock that still lets the window be resized is not a lock. ]]--
    local grip = CreateFrame("Button", nil, f)
    grip:SetWidth(GRIP)
    grip:SetHeight(GRIP)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.grip = grip

    --[[ Resizing writes width and row count rather than a frame size, so the
         result is a whole number of rows and the window cannot end up half a row
         tall. Dragging the grip is the same edit the two sliders make. ]]--
    grip:SetScript("OnMouseDown", function()
        local frame = this:GetParent()
        if OB.modules.damage:Window(frame.index).locked then return end

        frame.sizing = true
        frame.sizeFrom = { GetCursorPosition() }
    end)

    grip:SetScript("OnMouseUp", function()
        this:GetParent().sizing = nil
        OB.RefreshPanel()
    end)

    return f
end

--[[ The drag, applied. Called from the meter's tick while the grip is held.

     Cursor coordinates come back in the client's own scale, so both deltas are
     divided by it before they mean pixels on this window. Right and *down*
     grows, which is the direction the grip sits in. ]]--
function M:StepResize(frame)
    if not frame.sizing then return end

    local cfg = self:Window(frame.index)
    if not cfg or cfg.locked then
        frame.sizing = nil
        return
    end

    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end

    local dx = (x - frame.sizeFrom[1]) / scale
    local dy = (frame.sizeFrom[2] - y) / scale

    local step = self:RowStep(cfg)

    --[[ Width tracks the cursor directly; the row count only changes once the
         cursor has crossed a whole row, so the window is always a whole number
         of rows tall and never ends up half a row short. ]]--
    local width = OB.Clamp(OB.Round(cfg.width + dx), 100, 500)
    local rows = OB.Clamp(cfg.rows + OB.Round(dy / step), 3, 40)

    if width == cfg.width and rows == cfg.rows then return end

    cfg.width = width
    cfg.rows = rows

    -- the cursor's reference moves with what has already been applied
    frame.sizeFrom = { x, y }

    OB.Refresh(true)
end

--[[ Where a dropped window landed, written back to the profile.

     The stored offset is the window's **centre**, because that is what it is
     anchored by. Writing the left edge's distance from the middle of the screen
     and re-anchoring by centre moves the window half its own width every drop,
     and a few drags walk it off the edge.

     Then bounded to the screen, on both axes, against the window's own size --
     so a window cannot be dragged somewhere it cannot be dragged back from. ]]--
function M:StoreWindowPosition(frame)
    frame:StopMovingOrSizing()

    local cfg = self:Window(frame.index)
    if not cfg then return end

    local scale = self:Scale()

    --[[ A frame the client cannot give edges for keeps the position it had. That
         happens to one that has never been laid out, and inventing a coordinate
         from a nil edge would move the window somewhere nobody asked for. ]]--
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return end

    local x = OB.Round((left + (frame:GetWidth() / 2))
            - ((GetScreenWidth() / 2) / scale))
    local y = OB.Round((bottom + (frame:GetHeight() / 2))
            - ((GetScreenHeight() / 2) / scale))

    x = self:ClampWindow(frame, "x", x)
    y = self:ClampWindow(frame, "y", y)

    --[[ Pushed clear of any window already down, then bounded again: avoiding
         one can walk it into the edge, and the screen wins. ]]--
    x, y = OB.AvoidWindows("damage" .. frame.index, x, y,
            frame:GetWidth(), frame:GetHeight(), self:Scale())

    cfg.x = self:ClampWindow(frame, "x", x)
    cfg.y = self:ClampWindow(frame, "y", y)

    self:StyleWindow(frame)
    OB.RefreshPanel()
end

--[[ The scale this meter's windows are drawn at, which is the addon's. ]]--
function M:Scale()
    local scale = OB.profile and OB.profile.scale or 1
    if scale <= 0 then return 1 end
    return scale
end

--[[ `RescueWindow` lived here: a softer bound for the draw pass that only moved
     a window once its centre had left the screen.

     It was the third mechanism to be caught moving windows somebody had placed,
     after SetClampedToScreen and a hard clamp in the same spot. All three shared
     one flaw -- each decided for itself where "the screen" ends, and on an
     ultrawide none of them agrees with the monitor. Softening the rule bought a
     round; it did not fix anything.

     Drawing does not move windows now. Nothing replaced this. ]]--
function M:ClampWindow(frame, axis, v)
    local size = (axis == "x") and frame:GetWidth() or frame:GetHeight()
    local limit = OB.ScreenLimit(axis, size, self:Scale())

    if v > limit then return limit end
    if v < -limit then return -limit end
    return OB.Round(v)
end

--[[ The addon's scale, applied to every window. Features are asked rather than
     reached into, because only this one knows it has more than one frame. ]]--
function M:OnScale(scale)
    if not self.frames then return end

    for i = 1, table.getn(self.frames) do
        self.frames[i]:SetScale(scale)
    end
end

--[[ **A new window is a copy of the first one, moved.**

     It used to be built from the factory defaults, so a window opened beside one
     you had spent ten minutes colouring arrived in the shipped grey and had to
     be matched by hand -- reported as new tabs not sharing the header colour,
     and it was true of every appearance setting, not only that one.

     Copied rather than sharing a table: two windows that cannot differ are one
     window drawn twice, and the whole point is damage in one and healing in the
     other. So the mode is the only thing deliberately *not* inherited -- opening
     a second window showing exactly what the first shows is never what anybody
     meant by opening a second window. ]]--
--[[ Settings that stay a property of *one* window, whatever the page does.

     Position, obviously: pushing window one's coordinates onto the rest would
     stack them all in the same place. And the two the header owns -- the segment
     and the statistic -- because a second window exists precisely to show
     something the first does not. Everything else is appearance, and appearance
     that differs between two windows of one meter is a mistake nobody made on
     purpose. ]]--
local PER_WINDOW = { x = true, y = true, mode = true, segment = true }

--[[ **The page edits every window, not just the first.**

     Its rows are written as `windows.1.*` because a page needs one concrete
     thing to bind to, and it used to mean exactly that: colour the meter and
     only the master window changed, with the others keeping whatever they had
     until you deleted and re-made them. There is no second column of settings
     for window two and no plan to add one, so a setting that reached only
     window one left the rest unreachable. ]]--
function M:AfterSet(key, value)
    local _, _, field = string.find(key or "", "^windows%.1%.(.+)$")
    if not field then return end

    local cfg = self:Config()

    --[[ **Position is bounded here, on the write.**

         It used to be bounded on the draw, which is why removing that left a
         typed coordinate free to put a window past the edge. The bound belongs
         on the deliberate act: somebody dragging a slider to its end means "as
         far as it goes", and stopping at the screen is the helpful reading. A
         draw means nothing at all and should have no opinion. ]]--
    if field == "x" or field == "y" then
        local frame = self.frames and self.frames[1]
        if frame then
            cfg.windows[1][field] = self:ClampWindow(frame, field, value)
        end
        return
    end

    if PER_WINDOW[field] then return end

    for i = 2, table.getn(cfg.windows) do
        --[[ Copied, never shared. A colour is a table, and handing every window
             the same one makes them impossible to tell apart later -- and means
             editing any of them edits all of them by accident rather than by
             this rule. ]]--
        if type(value) == "table" then
            cfg.windows[i][field] = OB.DeepCopy(value)
        else
            cfg.windows[i][field] = value
        end
    end
end

function M:AddWindow()
    local cfg = self:Config()
    if table.getn(cfg.windows) >= 4 then return end

    local first = cfg.windows[1]
    local made = OB.DeepCopy(first)

    -- offset from the first so the new one is not hidden underneath it
    made.x = first.x + first.width + 10
    made.y = first.y

    --[[ Damage, then healing, then taken: the next question along from whatever
         window one is answering, so the second window is useful before it is
         touched. ]]--
    if first.mode == "damage" then made.mode = "heal"
    elseif first.mode == "heal" then made.mode = "taken"
    else made.mode = "damage" end

    table.insert(cfg.windows, made)

    OB.Refresh(true)
    OB.RefreshPanel()
end

--[[ Window one is never removed: it is the one the settings page edits, and a
     meter with no windows is a subsystem you can only switch off. ]]--
function M:RemoveWindow(index)
    if index <= 1 then return end

    local cfg = self:Config()
    table.remove(cfg.windows, index)

    --[[ **The frame pool is not touched.**

         It used to `table.remove` the frame as well, which took it out of the
         list while leaving it on screen -- and once it is out of the list,
         nothing can ever hide it again, because the sweep at the end of OnStyle
         walks exactly that list. One orphaned window per close, each of them
         permanent. That is the second meter that would not go away.

         Frames are pooled by position and reused, the rule every other pool here
         follows: frame `i` always draws window `i`, whatever window that now is,
         and any frame past the end is hidden. Nothing to renumber and nothing
         that can escape. ]]--
    OB.Refresh(true)
    OB.RefreshPanel()
end

function M:OnBind()
    self.data = self.data or OB.NewDamageData(GetTime())
    self.frames = self.frames or {}

    self:OnStyle()
end

-- ---------------------------------------------------------------------------
-- drawing
-- ---------------------------------------------------------------------------

--[[ Rows are inset by the border's own width, so two of them cannot draw their
     borders over each other.

     This is the bug RogueBars had: a border is art *outside* the bar, so bars
     packed edge to edge overlap by twice the pad however carefully the heights
     line up. Spacing them by it is the fix, and it has to come from the same
     BorderPad the styling uses or the two disagree.

     And **exactly** the pad, with nothing added on top. A spare pixel per row is
     invisible against a border and is a stripe of window background between
     every pair of rows when the border is off, which is the gap that got
     reported. With no border the step is the height and the rows touch. ]]--
function M:RowStep(cfg)
    return cfg.height + (OB.BorderPad("damage") * 2) + (cfg.gap or 0)
end

--[[ **Where the number came from**, on hover -- ShaguDPS's most useful habit and
     the reason its rows are worth pointing at.

     A total answers "who", and the next question is always "off what": whether
     the rogue's forty thousand was backstabs or a lucky proc, whether a warrior
     is actually using their rotation. That cannot be recovered from a total
     afterwards, which is why the per-spell tables are kept as the lines arrive
     rather than derived on demand.

     Capped at ten lines. A shadow priest in a long fight has thirty entries and
     the last twenty are rounding; a tooltip taller than the screen answers
     nothing. ]]--
local TOOLTIP_ROWS = 10

function M:ShowRowTooltip(row)
    if not row.entryName then return end

    local cfg = self:Window(row.windowIndex)
    if not cfg then return end

    local segment = self.data[cfg.segment] or self.data.current
    local spells = OB.DamageSpells(segment, cfg.mode, row.entryName)

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    GameTooltip:AddDoubleLine(row.entryName,
            labelFor(MODES, cfg.mode) .. "  " .. labelFor(SEGMENTS, cfg.segment))

    if table.getn(spells) == 0 then
        --[[ Says so rather than showing a name and nothing under it, which reads
             as a tooltip that failed to load. ]]--
        GameTooltip:AddLine("no breakdown recorded")
        GameTooltip:Show()
        return
    end

    for i = 1, table.getn(spells) do
        if i > TOOLTIP_ROWS then break end

        GameTooltip:AddDoubleLine(spells[i].name,
                OB.ShortNumber(spells[i].total)
                        .. "  (" .. OB.Round(spells[i].share * 100) .. "%)")
    end

    GameTooltip:Show()
end

function M:EnsureRows(frame, count)
    for i = table.getn(frame.rows) + 1, count do
        local row = OB.CreateBar("EqOBDamage" .. frame.index .. "Row" .. i, frame)

        --[[ Rows take the mouse so they can be hovered. That is safe now only
             because the header carries the drag: when the window was dragged by
             its body, a row swallowing the press would have made most of the
             window undraggable. ]]--
        row:EnableMouse(true)
        row.windowIndex = frame.index

        row:SetScript("OnEnter", function()
            OB.modules.damage:ShowRowTooltip(this)
        end)

        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        frame.rows[i] = row
    end
end

function M:StyleWindow(frame)
    local cfg = self:Window(frame.index)
    if not cfg then return end

    local step = self:RowStep(cfg)
    local pad = OB.BorderPad("damage")

    self:EnsureRows(frame, cfg.rows)

    frame:SetWidth(cfg.width)
    frame:SetHeight(HEADER_H + (step * cfg.rows) + (pad * 2))
    frame:SetScale(self:Scale())
    frame:ClearAllPoints()

    --[[ **Drawing never moves a window. Ever.**

         Three separate mechanisms have now been caught doing it: the client's
         SetClampedToScreen, a hard clamp here, and a gentler rescue here that
         only fired when the centre left the screen. Each was defensible on its
         own and each moved windows the user had placed -- because every one of
         them decides where "the screen" ends, and on an ultrawide none of them
         agrees with the monitor.

         The stored position is the answer. It is written by exactly two things,
         both of them deliberate acts on one window: dropping a drag, and typing
         a coordinate. Neither happens while drawing, so drawing has no business
         having an opinion.

         A profile carried to a smaller monitor can leave a window off the edge.
         That is recoverable -- `/eqob windows` says where everything is, and the
         sliders reach it -- and it is a far smaller cost than rearranging a
         layout somebody built, every single load. ]]--

    frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)

    --[[ Published so other windows know to keep off. Written on every style
         pass, because a window that grew is a window that may now overlap. ]]--
    OB.RegisterWindowRect("damage" .. frame.index, cfg.x, cfg.y,
            frame:GetWidth(), frame:GetHeight())

    frame.head:ClearAllPoints()
    frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    local c = cfg.headerColor
    frame.head.bg:SetTexture(c[1], c[2], c[3], c[4] or 1)

    --[[ **Master controls: reset + new. Extra windows: close.**

         The master is the one the settings page edits and the one a meter cannot
         be without, so it carries the reset and add-window controls. Every extra
         window carries only its close control. ]]--
    local master = frame.index == 1

    if master then
        frame.head.close:Hide()
        frame.head.reset:Show()
        frame.head.new:Show()
    else
        frame.head.close:Show()
        frame.head.reset:Hide()
        frame.head.new:Hide()
    end

    --[[ **Three groups, not one row: window controls left, what-am-I-looking-at
         centred, add and close right.**

         They are three different kinds of thing and reading them as one strip of
         seven made you scan it every time. The two menus are the only ones whose
         answer changes, so they get the middle where the eye lands; the padlock
         is first because it is the one you reach for while arranging windows,
         and the settings cog sits beside it as the other rarely-used one. ]]--
    local left = { frame.head.lock, frame.head.settings }
    local x = 2

    for i = 1, table.getn(left) do
        left[i]:ClearAllPoints()
        left[i]:SetPoint("LEFT", frame.head, "LEFT", x, 0)
        x = x + left[i]:GetWidth() + 2
    end

    local corner = master and frame.head.new or frame.head.close
    corner:ClearAllPoints()
    corner:SetPoint("RIGHT", frame.head, "RIGHT", -2, 0)

    frame.head.reset:ClearAllPoints()
    if master then
        frame.head.reset:SetPoint("RIGHT", frame.head.new, "LEFT", -2, 0)
    end

    --[[ Centred as a pair, so the two together sit on the window's midline
         rather than one of them landing there and the other beside it. ]]--
    local pairWidth = frame.head.segment:GetWidth()
            + frame.head.mode:GetWidth() + 2

    frame.head.segment:ClearAllPoints()
    frame.head.segment:SetPoint("LEFT", frame.head, "CENTER",
            -(pairWidth / 2), 0)

    frame.head.mode:ClearAllPoints()
    frame.head.mode:SetPoint("LEFT", frame.head.segment, "RIGHT", 2, 0)

    --[[ The padlock shows the state it is in, not the state clicking would
         reach. A closed padlock on an unlocked window reads as a button that
         will lock it and as a window that is already locked, and half the
         people looking at it pick the wrong one. ]]--
    frame.head.lock:SetIcon(cfg.locked and "lock" or "unlock")

    frame.head.segment.text:SetText(labelFor(SEGMENTS, cfg.segment))
    frame.head.mode.text:SetText(labelFor(MODES, cfg.mode))

    if cfg.locked then frame.grip:Hide() else frame.grip:Show() end

    --[[ **The window's body carries the background, not each row.**

         Painting it per row leaves the gap between two rows showing whatever is
         behind the window, so raising Gap Between Bars cut stripes through it --
         reported as "the gap creates a gap in the background". A window is one
         surface; the rows sit on it.

         So the body is painted once across the whole area below the header, and
         the rows are given no background of their own. What was the row's trough
         is now the body showing through, which is the same pixels and cannot
         come apart. ]]--
    local body = cfg.bg
    frame.body:SetTexture(body[1], body[2], body[3], body[4] or 0.6)
    frame.body:ClearAllPoints()
    --[[ Anchored here, sized in FitBackground: how tall it should be depends on
         how many rows there are to sit on it, which the draw pass knows and the
         style pass does not. ]]--
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_H)
    frame.body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -HEADER_H)

    --[[ Rows are inset by the border pad on both sides, so the border art stays
         inside the window rather than hanging over its edge -- which is the
         other half of "bars must not go beyond the window region". ]]--
    local slot = {
        w = cfg.width - (pad * 2), h = cfg.height,
        bg = { 0, 0, 0, 0 },
    }

    for i = 1, table.getn(frame.rows) do
        local row = frame.rows[i]
        OB.StyleBar(row, slot, nil, "damage")

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT",
                pad, -(HEADER_H + pad + ((i - 1) * step)))
    end
end

function M:OnStyle()
    local cfg = self:Config()
    if not self.frames then return end

    -- one frame per configured window, built on demand and never destroyed
    for i = 1, table.getn(cfg.windows) do
        if not self.frames[i] then self.frames[i] = self:BuildWindow(i) end
        self:StyleWindow(self.frames[i])
    end

    for i = table.getn(cfg.windows) + 1, table.getn(self.frames) do
        self.frames[i]:Hide()
    end
end

--[[ The right-hand label: total, rate and share, in whichever combination is
     switched on. Assembled rather than fixed, because which of the three matter
     depends on what you are looking for and all three may be on at once. ]]--
function M:RowText(cfg, row)
    local parts = {}

    if cfg.showTotal then table.insert(parts, OB.ShortNumber(row.total)) end
    if cfg.showPerSecond then
        table.insert(parts, OB.ShortNumber(row.perSecond))
    end
    if cfg.showPercent then
        table.insert(parts, OB.Round(row.share * 100) .. "%")
    end

    return table.concat(parts, OB.COLUMN_GAP)
end

--[[ The left-hand label: a rank and a name, or just a name.

     The rank is worth a setting because it answers "am I third" without
     counting rows, and worth being optional because on a five row window
     counting is free. ]]--
function M:RowName(cfg, index, row)
    if cfg.showRank then return index .. ". " .. row.name end
    return row.name
end

--[[ **Bar colour, unless class knows better.**

     The fallback is the window's own bar colour rather than a hardcoded grey,
     which is the setting the panel now carries. A row whose class cannot be
     resolved -- a pet, a boss, anybody outside the group -- is not an error and
     should not look like one. ]]--
function M:RowColor(cfg, entry)
    if cfg.classColor then
        local class = OB.GroupClass(entry.name)
        if class then
            local r, g, b = OB.ClassColor(class)
            return { r, g, b, 1 }
        end
    end

    return cfg.barColor
end

function M:DrawWindow(frame)
    local cfg = self:Window(frame.index)
    if not cfg then return end

    self:EnsureRows(frame, cfg.rows)

    local segment = self.data[cfg.segment] or self.data.current
    local rows = OB.DamageRows(segment, cfg.mode)

    frame:Show()

    --[[ Scaled against the leader rather than a fixed total, which is what makes
         the bars a comparison. Against a total, a raid of ten would draw every
         row at a tenth of the width and say nothing. ]]--
    local top = rows[1] and rows[1].total or 0
    if top <= 0 then top = 1 end

    for i = 1, table.getn(frame.rows) do
        local row = frame.rows[i]
        local entry = rows[i]

        if not entry or i > cfg.rows then
            row.entryName = nil
            row:Hide()
        else
            row:Show()
            OB.SetBarFill(row, entry.total / top, false)

            OB.SetBarColor(row, self:RowColor(cfg, entry))

            --[[ Whose row this is, so the hover breakdown can ask about them.
                 Stored rather than re-derived from the position, because the
                 ordering changes under the cursor mid-fight and reading the
                 sorted list again on hover would answer about whoever is there
                 *now* rather than the row being pointed at. ]]--
            row.entryName = entry.name
            row.windowIndex = frame.index

            OB.SetBarText(row, row.left, self:RowName(cfg, i, entry), 0)
            OB.SetBarText(row, row.center, "", 50)

            --[[ Placed below, once the widest row is known: every row's numbers
                 have to begin at the same x or the digits run ragged down the
                 window and nothing lines up with anything. ]]--
            row.right:SetText(self:RowText(cfg, entry))
        end
    end

    self:AlignColumns(frame)

    local shown = table.getn(rows)
    if shown > cfg.rows then shown = cfg.rows end
    self:FitBackground(frame, shown)
end

--[[ **The background stops where the rows stop**, so there is never background
     with no bar in front of it.

     Rows Shown is a ceiling, not a promise: three people in a window sized for
     ten left seven rows of bare colour, which reads as a window that failed to
     draw rather than as a fight with three people in it.

     The frame keeps its full height. It is what the resize grip and the overlap
     rectangle are measured from, and a window whose bounds moved every time
     somebody joined the fight could not be placed. Only the paint follows. ]]--
function M:FitBackground(frame, shown)
    if not frame.body then return end

    if shown <= 0 then
        frame.body:Hide()
        return
    end

    local cfg = self:Window(frame.index)
    local pad = OB.BorderPad("damage")

    frame.body:Show()

    --[[ Exactly the last row's bottom edge, not a whole step past it: a step
         includes the gap *after* a row, so multiplying by the count leaves a
         strip below the last bar. ]]--
    frame.body:SetHeight(((shown - 1) * self:RowStep(cfg))
            + cfg.height + (pad * 2))
end

--[[ **One left edge for every row's numbers.**

     Measured across the visible rows and applied to all of them, so the column
     is flush left with itself while the block as a whole still ends on the
     window's right edge. Two passes rather than one, because the answer depends
     on every row and no row can know it alone. ]]--
function M:AlignColumns(frame)
    local widest, leftUsed = 0, 0

    for i = 1, table.getn(frame.rows) do
        local row = frame.rows[i]

        if row:IsShown() then
            local w = row.right:GetStringWidth() or 0
            if w > widest then widest = w end

            local l = row.left:GetStringWidth() or 0
            if l > leftUsed then leftUsed = l end
        end
    end

    for i = 1, table.getn(frame.rows) do
        local row = frame.rows[i]
        if row:IsShown() then
            OB.PlaceTextLeftAt(row, row.right,
                    OB.ColumnStart(row, widest, leftUsed))
        end
    end
end

function M:OnDraw()
    if not self.frames then return end

    local cfg = self:Config()
    for i = 1, table.getn(cfg.windows) do
        if self.frames[i] then self:DrawWindow(self.frames[i]) end
    end
end

-- ---------------------------------------------------------------------------
-- preview
-- ---------------------------------------------------------------------------

--[[ A plausible raid, so the colours and columns can be set without a fight.

     Class names rather than player names, because the row colour comes from the
     group roster and a preview that could not colour itself would be failing to
     show the one thing hardest to picture. ]]--
local PREVIEW = {
    { "Rogue", 48000, "ROGUE" }, { "Mage", 41500, "MAGE" },
    { "Warrior", 33000, "WARRIOR" }, { "Hunter", 29500, "HUNTER" },
    { "Warlock", 24000, "WARLOCK" }, { "Druid", 12000, "DRUID" },
    { "Priest", 4200, "PRIEST" },
}

function M:TestStart(now)
    self.liveData = self.data
    self.previewAt = nil
    self:SeedPreview(now)
end

--[[ Re-seeded every second with fresh numbers, so the bars actually move.

     A still preview shows the colours and hides everything about the motion --
     whether the ordering settles, whether a row that overtakes another is
     readable, whether the widths are jumpy. Those are the things worth looking
     at before a raid. ]]--
function M:SeedPreview(now)
    self.data = OB.NewDamageData(now - 30)

    for i = 1, table.getn(PREVIEW) do
        local name, base = PREVIEW[i][1], PREVIEW[i][2]

        --[[ The class is asserted, because a preview row is in no group and the
             roster can never answer for it. Without this every row came back
             classless and the preview showed the fallback seven times over --
             which is what "color rows by class isn't working" was. ]]--
        OB.classHint[name] = PREVIEW[i][3]

        -- +/- 30%, so the ranking genuinely reshuffles rather than jittering
        local amount = math.floor(base * (0.7 + (math.random() * 0.6)))

        OB.AddCombatLine(self.data,
                { source = name, target = "Training Dummy",
                  amount = amount, kind = "damage" }, now)
        OB.AddCombatLine(self.data,
                { source = name, target = name,
                  amount = math.floor(amount / 3), kind = "heal" }, now)
    end

    OB.SetDirty(self)
end

--[[ The real totals come back untouched. A preview that overwrote them would
     cost somebody the fight they were reading, which is a high price for
     looking at a colour. ]]--
function M:TestStop()
    -- unconditional, for the reason threat.lua gives at the same point
    self.data = self.liveData or OB.NewDamageData(GetTime())
    self.liveData = nil
    self.previewAt = nil

    --[[ Cleared, or a real player who happens to be called Mage keeps the
         preview's class for the rest of the session. ]]--
    OB.classHint = {}

    OB.SetDirty(self)
end

--[[ **The preview re-seeds at the meter's own update rate.**

     It was pinned at once a second, so dragging Updates Per Second to ten did
     nothing you could see -- the bars still moved once a second, and the setting
     read as broken. It was not: the *redraw* was ten a second over numbers that
     changed once. Nothing to look at.

     A preview exists to show what a setting does, so the setting has to reach
     it. In a real fight the two are genuinely separate -- the numbers change
     when somebody is hit -- but the only honest way to preview a redraw rate is
     to give it something changing at that rate. ]]--
function M:TestStep(now)
    if not self.previewAt then self.previewAt = now end
    if (now - self.previewAt) < self:RedrawStep() then return end

    self.previewAt = now
    self:SeedPreview(now)
end

--[[ Ticked so a rate keeps moving while a fight runs. The totals only change on
     an event, but the seconds they are divided by do not.

     The beat is `updateRate` redraws a second, clamped to the slider's own
     bounds so a saved value from a future build cannot stop the meter
     redrawing at all. ]]--
function M:RedrawStep()
    return 1 / OB.Clamp(self:Config().updateRate or 2, 1, 10)
end

function M:OnUpdate(now)
    --[[ A drag has to be followed every frame, not on the redraw beat: a grip
         that only catches up twice a second reads as a stuck window. ]]--
    if self.frames then
        for i = 1, table.getn(self.frames) do
            if self.frames[i].sizing then self:StepResize(self.frames[i]) end
        end
    end

    if self.nextDraw and now < self.nextDraw then return end
    self.nextDraw = now + self:RedrawStep()

    OB.SetDirty(self)
end
