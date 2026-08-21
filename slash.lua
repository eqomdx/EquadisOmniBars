--[[ Equadis' Classic Overhaul :: slash commands

  /eqob, generated from the same option index the panel is generated from.

  Nothing here contains behaviour that is not reachable from the panel, and
  nothing in the panel is unreachable from here. That is the point of generating
  both from one table: Equadis' Threat Meter's predecessor had roughly a hundred
  lines of near-identical `elseif strlower(cmd) ==` blocks that had to be kept in
  step by hand, and were not.

  Grammar:

    /eqob                          open the panel
    /eqob help                     every option in every scope
    /eqob <global option> [value]  e.g. scale 120, locked
    /eqob bar <id> <key> [value]   e.g. bar resource h 20
    /eqob <module> <key> [value]   e.g. power ticker nofull
    /eqob profile use|new|copy|delete <name>
    /eqob restack | test | reset [all]
]]--

local OB = EquadisClassicOverhaul

--[[ **Every line this file writes says which part of the addon it came from.**

     One prefix, one colour, and the name after it -- so a message about the
     chat scan says so, rather than leaving the reader to work out which of
     eleven things is talking. See OB.Print. ]]--
local function Say(msg) OB.Print(msg, "Commands") end

local function p(msg) OB.Raw(msg) end

--[[ Sub-commands a later file adds, keyed by the word that invokes them:

       OB.commands.selftest = { help = "...", Run = function(args) ... end }

     The dispatcher below is an if-chain fixed at load time, and TOC order means
     anything that wants a command of its own loads after it. Rather than reach
     back and edit the chain -- which is exactly the hand-maintained drift this
     file exists to avoid -- a later file registers here and both the dispatch
     and the generated help pick it up. Phase 4's meters join the same way.

     The reserved words are matched first, so nothing appended later can shadow
     `help` or `reset`. ]]--
OB.commands = {}

local BLUE = "|cff69ccf0"
local WHITE = "|cffffffff"
local GREY = "|cffcccccc"
local GREEN = "|cffabd473"

-- ---------------------------------------------------------------------------
-- reporting
-- ---------------------------------------------------------------------------

--[[ Report a value, or flip it when no value was given.

     Flipping only makes sense for a boolean; for anything else "no value" is a
     query, which is what makes `/eqob scale` a safe thing to type. ]]--
local function handleOption(w, label, args)
    if args == "" then
        if w.kind == "boolean" then
            OB.ApplyOption(w, not OB.ReadOption(w))
        end
        Say(label .. ": |cffffddcc" .. OB.DescribeOption(w))
        return
    end

    local err = OB.ParseOption(w, args)
    if err then
        Say("|cffff5511" .. err)
    else
        Say(label .. ": |cffffddcc" .. OB.DescribeOption(w))
    end
end

--[[ Option keys are camelCase (hideOOC, fontSize, textMode) but nobody types
     shift at a slash prompt, so a lookup falls back to a case-insensitive scan.
     Reserved words are matched lower-cased; option keys never are. ]]--
local function findOption(index, name)
    if not index or not name or name == "" then return nil end
    if index[name] then return index[name] end

    local wanted = string.lower(name)
    for key, w in pairs(index) do
        if string.lower(key) == wanted then return w end
    end

    return nil
end

local function listOptions(index, prefix)
    local keys = {}
    for key in pairs(index) do table.insert(keys, key) end
    table.sort(keys)

    for i = 1, table.getn(keys) do
        local w = index[keys[i]]
        p("  " .. BLUE .. prefix .. keys[i] .. WHITE .. " "
                .. OB.DescribeOption(w) .. " " .. GREY .. "- " .. w.caption)
    end
end

local function showHelp()
    --[[ **The version, first line, every time.**

         It was only ever printed by the self test, which meant the one question
         that has to be answerable before any other -- "which build am I looking
         at" -- could not be answered from inside the game. Two sessions were
         spent on a tab that was present in the code and absent on screen, and
         neither could settle it. ]]--
    p(GREEN .. OB.addonName .. WHITE .. " " .. (OB.version or "?")
            .. " commands:")
    p("  " .. BLUE .. "/eqob" .. WHITE .. " / " .. BLUE .. "/ob" .. WHITE
            .. " - open the settings panel")
    p("  " .. BLUE .. "/eqob test" .. WHITE .. " - start or stop the preview")
    p("  " .. BLUE .. "/eqob restack" .. WHITE
            .. " - re-stack the occupied bars top to bottom")
    p("  " .. BLUE .. "/eqob windows" .. WHITE
            .. " - where each meter window is stored and drawn")
    p("  " .. BLUE .. "/eqob profile use|new|copy|delete <name>" .. WHITE)
    p("  " .. BLUE .. "/eqob reset" .. WHITE .. " / " .. BLUE .. "reset all" .. WHITE
            .. " - this profile, or every profile")
    p("  " .. BLUE .. "/eqob doctor" .. WHITE
            .. " - version, and which modules actually loaded")
    p("  " .. BLUE .. "/eqob cmd" .. WHITE
            .. " - chat commands you can bind to anything in Key Bindings")

    -- listed from the registry, so a command added by a later file appears here
    -- without this function being touched
    local extra = {}
    for name in pairs(OB.commands) do table.insert(extra, name) end
    table.sort(extra)

    for i = 1, table.getn(extra) do
        local command = OB.commands[extra[i]]
        p("  " .. BLUE .. "/eqob " .. extra[i] .. WHITE .. " - " .. (command.help or ""))
    end

    p(GREEN .. "Bars:" .. WHITE .. " " .. BLUE .. "/eqob bar <id> <key> <value>")

    -- only the bars this class has: offering geometry for a rectangle that will
    -- never be drawn is just a way to waste somebody's afternoon
    local bars = OB.BarsForClass()
    local ids = {}
    for i = 1, table.getn(bars) do
        local id = bars[i]
        if OB.bound[id] then
            table.insert(ids, id)
        else
            table.insert(ids, id .. "=empty")
        end
    end
    p("  " .. GREY .. table.concat(ids, "  "))
    listOptions(OB.optionIndex.slot, "bar <id> ")

    p(GREEN .. "General:" .. WHITE .. " " .. BLUE .. "/eqob <option> <value>")
    listOptions(OB.optionIndex.global, "")

    for i = 1, table.getn(OB.moduleOrder) do
        local id = OB.moduleOrder[i]
        local index = OB.optionIndex.modules[id]
        if index and OB.ClassAllows(OB.modules[id]) then
            p(GREEN .. OB.modules[id].name .. ":" .. WHITE .. " "
                    .. BLUE .. "/eqob " .. id .. " <option> <value>")
            listOptions(index, id .. " ")
        end
    end
end

-- ---------------------------------------------------------------------------
-- sub-commands
-- ---------------------------------------------------------------------------

local function cmdBar(args)
    local _, _, barId, key, value = string.find(args, "^(%S+)%s+(%S+)%s*(.*)$")

    if not barId then
        Say("usage: /eqob bar <id> <key> [value]")
        return
    end

    if not OB.profile.slots[barId] then
        Say("no bar named '" .. barId .. "'. Try: "
                .. table.concat(OB.barOrder, ", "))
        return
    end

    local w = findOption(OB.optionIndex.slot, key)
    if not w then
        Say("no bar setting named '" .. key .. "'.")
        return
    end

    --[[ Bar rows read through OB.panel.bar, which is also what the panel's
         selector drives. Pointing it at the named bar is what lets one set of
         row descriptors serve both. ]]--
    local previous = OB.panel.bar
    OB.panel.bar = barId
    handleOption(w, barId .. " " .. key, value or "")
    OB.panel.bar = previous
    OB.RefreshPanel()
end

--[[ `/eqob assign <slot> <module>` lived here. It set which module drew in which
     slot, and it went with the rest of the assignment layer -- a bar and its
     module are one thing now, so there is nothing left to assign. ]]--

local function cmdProfile(args)
    local _, _, action, name = string.find(args, "^(%S*)%s*(.*)$")
    action = string.lower(action or "")

    if action == "" or action == "list" then
        local names = OB.ProfileNames()
        Say("profiles: " .. table.concat(names, ", "))
        Say("this character uses '" .. OB.profileName .. "'.")
        return
    end

    if name == "" then
        Say("usage: /eqob profile " .. action .. " <name>")
        return
    end

    if action == "use" then OB.SetProfile(name)
    elseif action == "new" then OB.NewProfile(name)
    elseif action == "copy" then OB.CopyProfile(name)
    elseif action == "delete" then OB.DeleteProfile(name)
    else Say("usage: /eqob profile use|new|copy|delete <name>") end

    OB.RefreshPanel()
end

-- ---------------------------------------------------------------------------
-- dispatch
-- ---------------------------------------------------------------------------

--[[ **Every name somebody might reach for.**

     The addon was Equadis' OmniBars and is Equadis' Classic Overhaul, and both
     sets are kept: `/eqob` and `/ob` are what a year of muscle memory types, and
     nobody should have to relearn a slash command because the title changed.

     Short before long, because the short ones are what get used. `/eq` and `/co`
     are two characters and will collide with something eventually -- the client
     resolves a collision by taking whichever addon registered last, so if either
     stops working that is why, and the longer names are the ones that will not. ]]--
SLASH_EQUADISOMNIBARS1 = "/eqob"
SLASH_EQUADISOMNIBARS2 = "/ob"
SLASH_EQUADISOMNIBARS3 = "/omnibars"
SLASH_EQUADISOMNIBARS4 = "/eq"
SLASH_EQUADISOMNIBARS5 = "/co"
SLASH_EQUADISOMNIBARS6 = "/eqco"
SLASH_EQUADISOMNIBARS7 = "/equadis"
SLASH_EQUADISOMNIBARS8 = "/classicoverhaul"

--[[ **`/tt` as a command of its own**, because that is the name everybody knows
     it by. Prat shipped it and a decade of muscle memory types `/tt name` --
     `/eqob tt` works too and nobody will ever use it.

     Registered separately rather than as another alias for the panel, since it
     takes an argument that has nothing to do with settings. ]]--
SLASH_EQUADISOVERHAULTELL1 = "/tt"
SLASH_EQUADISOVERHAULTELL2 = "/tellt"

SLASH_EQUADISOVERHAULCHATSCAN1 = "/chatscan"

-- Item Database shortcuts. /atlas intentionally opens ECO's unified database
-- rather than a second standalone Atlas window: Atlas-CFM and AtlasLoot are
-- bundled data/providers inside Classic Overhaul now.
SLASH_EQUADISOVERHAULDATABASE1 = "/db"
SLASH_EQUADISOVERHAULDATABASE2 = "/database"
SLASH_EQUADISOVERHAULDATABASE3 = "/eqdb"
SLASH_EQUADISOVERHAULDATABASE4 = "/atlas"

SlashCmdList["EQUADISOVERHAULDATABASE"] = function(msg)
    if not OB.profile then
        Say("still loading -- try again in a moment.")
        return
    end

    local database = OB.modules and OB.modules.itemdatabase
    if not database then
        Say("Item Database is not loaded.")
        return
    end

    database:OpenBrowser()
end

SlashCmdList["EQUADISOVERHAULTELL"] = function(msg)
    if not OB.profile then return end
    OB.modules.chat:TellTarget(msg)
end

SlashCmdList["EQUADISOVERHAULCHATSCAN"] = function(msg)
    if not OB.profile then
        Say("still loading -- try again in a moment.")
        return
    end

    local roster = OB.modules and OB.modules.roster
    if not roster then
        Say("ChatScan is not loaded.")
        return
    end

    if roster:Sweeping() then
        OB.Print("Scan already running.", "ChatScan")
        return
    end

    local level
    local arg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")

    if arg ~= "" then
        level = tonumber(arg)

        if not level or level < 1 or level > 60 or level ~= math.floor(level) then
            OB.Print("usage: /chatscan [1-60]", "ChatScan")
            return
        end
    end

    roster:SetScanning(true, level)
end

SlashCmdList["EQUADISOMNIBARS"] = function(msg)
    if not OB.profile then
        Say("still loading -- try again in a moment.")
        return
    end

    local _, _, raw, args = string.find(msg or "", "^%s*(%S*)%s*(.*)$")
    raw = raw or ""
    args = args or ""

    -- reserved words match case-insensitively; option keys keep their case and
    -- go through findOption, which does its own fallback
    local cmd = string.lower(raw)

    if cmd == "" or cmd == "config" or cmd == "options" then
        OB.TogglePanel()
        return
    end

    if cmd == "help" then showHelp() return end

    if cmd == "test" then
        OB.ToggleTestMode()
        if OB.testMode then
            Say("preview running.")
        else
            Say("preview stopped.")
        end
        return
    end

    if cmd == "windows" then OB.PrintWindowReport() return end

    if cmd == "restack" then
        OB.RestackBars()
        OB.Refresh(true)
        OB.RefreshPanel()
        Say("slots restacked -- this moves them for every character on the '"
                .. OB.profileName .. "' profile.")
        return
    end

    if cmd == "reset" then
        if string.lower(args) == "all" then
            StaticPopup_Show("EQOB_RESET_ALL")
        else
            StaticPopup_Show("EQOB_RESET_PROFILE")
        end
        return
    end

    --[[ What the addon knows about other players, which is not a setting and so
         is not reached by either reset. `report` because a store that grows
         quietly should be countable, and `forget` because it is the only way
         back. ]]--
    if cmd == "roster" then
        if string.lower(args) == "forget" then
            OB.ForgetRoster()
        else
            OB.PrintRosterReport()
        end
        return
    end

    --[[ **Marking something to sell this once**, which is a different act from
         deciding you never want it again -- that one is a setting and lives on
         the panel.

         A command rather than a control because the panel is not what is in
         front of you at a vendor, and because this is an action rather than a
         preference. It stops being true when the merchant window closes. ]]--
    if cmd == "sell" then
        local m = OB.modules.qol

        if args == "" then
            local sold = m:SellJunk()
            Say(sold > 0 and ("sold " .. sold .. ".")
                    or "nothing to sell -- open a vendor first.")
        elseif m:MarkForSale(args) then
            Say("'" .. args .. "' will be sold at this vendor. "
                    .. "Type '/eqob sell' to do it now.")
        end
        return
    end

    --[[ The never-keep list, from the keyboard. The panel holds the same string
         in a field; this is for adding the thing you are looking at without
         opening anything. ]]--
    if cmd == "trash" then
        local list = OB.TrashList()

        if args == "" then
            Say(list == "" and "nothing is on your never-keep list."
                    or ("never keeping: " .. list))
            return
        end

        --[[ Appended rather than replacing, because somebody typing
             `/eqob trash Broken Fang` means "and this one too". Replacing a list
             of things to destroy on the strength of one word would be a poor
             way to find out otherwise. ]]--
        if list == "" then
            EquadisClassicOverhaulDB.trash = args
        else
            EquadisClassicOverhaulDB.trash = list .. ", " .. args
        end

        OB.RefreshPanel()
        Say("'" .. args .. "' added. Anything on this list is destroyed "
                .. "when it arrives -- '/eqob trash' shows the whole list.")
        return
    end

    --[[ Trash mode. A command rather than a panel control because it is a mode
         you turn on for ten seconds with your bags open, and the panel would be
         covering the bags. ]]--
    if cmd == "select" then
        local m = OB.modules.qol
        local what = string.lower(args)

        if what == "none" then
            m:ClearSelection()
            Say("selection cleared.")
            return
        end

        if what == "trash" then
            local items = m:SelectedItems()
            local count = table.getn(items)

            if count == 0 then
                Say("nothing selected. '/eqob select' then click items.")
                return
            end

            --[[ Said before the dialog, because the dialog cannot hold a list
                 and the list is the part worth reading twice. ]]--
            local valuable = m:ValuableInSelection()

            if table.getn(valuable) > 0 then
                Say("about to destroy " .. count .. " items, including: "
                        .. table.concat(valuable, ", ") .. ".")
            end

            StaticPopup_Show("EQOB_TRASH_SELECTED")
            return
        end

        if what == "sell" then
            local sold = m:SellSelected()
            Say(sold > 0 and ("sold " .. sold .. ".")
                    or "nothing sold -- open a vendor first.")
            return
        end

        m:SetSelectMode(not m:SelectMode())

        if m:SelectMode() then
            Say("trash mode on -- click items in your bags to choose them, "
                    .. "then '/eqob select trash' or '/eqob select sell'.")
        else
            Say("trash mode off.")
        end
        return
    end

    --[[ Bind mode, which is a mode rather than a setting: you turn it on, do a
         thing with the mouse and keyboard, and turn it off. The panel could not
         host it if it wanted to -- the first thing it does is close the panel. ]]--
    if cmd == "bind" then
        local m = OB.modules.actionbars
        m:SetBindMode(not m:BindMode())
        return
    end

    --[[ Moving the bars, which like bind mode is a mode rather than a setting:
         on, drag, off. ]]--
    if cmd == "bars" then
        local m = OB.modules.actionbars

        if string.lower(args) == "reset" then
            m:ResetPositions()
        else
            m:SetDragMode(not m:DragMode())
        end
        return
    end

    --[[ **One command that says what actually loaded.**

         A tab going missing has one cause -- the module file threw while
         loading, so the client carried on with the next file and the
         registration never ran -- and no way to see it from inside the game
         except a line at login that is easy to miss.

         This reports the version, every declared tab and whether its module is
         there, so a bug report is one paste instead of a conversation. It reads
         nothing but the registry, so it works when the thing being diagnosed is
         a module that is not there. ]]--
    if cmd == "doctor" then
        Say(OB.addonName .. " " .. (OB.version or "?"))

        --[[ How far chat.lua got before it died, which the client will not say.
             nil means it never compiled -- a syntax error, which on 1.12 means
             something Lua 5.0 rejects and 5.1 accepts. ]]--
        --[[ How far the chat files got, which the client will not say. Only
             when something is wrong with them: a marker on a healthy boot is a
             number nobody needs. ]]--
        if not OB.modules.chat or table.getn((OB.modules.chat.options) or {}) == 0 then
            Say("  chat load marker: |cffff5511"
                    .. tostring(OB.chatLoad or "nothing -- chat.lua did not compile")
                    .. "|r")
        end

        local missing = 0

        for i = 1, table.getn(OB.featureTabs or {}) do
            local entry = OB.featureTabs[i]
            local ids = entry

            if type(entry) ~= "table" then ids = { entry } end

            for k = 1, table.getn(ids) do
                local id = ids[k]

                if OB.modules[id] then
                    local rows = table.getn(OB.modules[id].options or {})

                    --[[ **A finished module with no rows is not healthy**, and
                         it reads as healthy: the tab appears, the module is
                         registered, and the page is empty. It happens when the
                         rows live in a second file that did not load -- which
                         on this client is what a new TOC entry does until the
                         game is fully restarted, because /reload does not pick
                         up a file the client did not see at launch. ]]--
                    if rows == 0 and not OB.modules[id].development then
                        missing = missing + 1
                        Say("  |cffff5511" .. id .. ": loaded but has NO "
                                .. "ROWS|r -- restart the game rather than "
                                .. "reloading")
                    else
                        Say("  " .. id .. ": loaded, " .. rows .. " rows")
                    end
                else
                    missing = missing + 1
                    Say("  |cffff5511" .. id .. ": DID NOT LOAD|r")
                end
            end
        end

        if missing > 0 then
            Say("|cffff5511" .. missing .. " module"
                    .. (missing == 1 and "" or "s") .. " missing|r -- look for a "
                    .. "Lua error at login. Turn Blizzard's error display on "
                    .. "with '/console scriptErrors 1' and reload.")
        else
            Say("every declared tab has its module.")
        end

        for i = 1, table.getn(OB.panelFaults or {}) do
            Say("  |cffff5511panel|r " .. OB.panelFaults[i].label .. ": "
                    .. OB.panelFaults[i].err)
        end

        return
    end

    --[[ What the chat commands are. A fixed list now rather than one somebody
         edits, so this reports rather than manages. ]]--
    if cmd == "cmd" or cmd == "commands" then
        OB.PrintCommands()
        return
    end

    --[[ The same, for the player and target frames. A separate command from
         `bars` because they are separate frames with separate saved positions,
         and one command that moved both would be a mode nobody could aim. ]]--
    if cmd == "frames" then
        local m = OB.modules.unitframes

        if string.lower(args) == "reset" then
            m:ResetPositions()
        else
            m:SetDragMode(not m:DragMode())
        end
        return
    end

    --[[ What each chat window is actually holding, and the way back if the
         removal memory has learned something wrong. Both exist because chat
         settings coming back changed after a reload is not something reading the
         code has been able to settle. ]]--
    if cmd == "chat" then
        --[[ Finding a line that has scrolled away. Results print into chat,
             which reads better than scrolling a window to a hit -- and is the
             reason the search box Prat anchors to every frame is not here. ]]--
        local _, _, verb, rest = string.find(args, "^(%S*)%s*(.*)$")

        if string.lower(verb or "") == "find" then
            OB.modules.chat:Find(rest)
            return
        end

        if string.lower(args) == "forget" then
            local db = EquadisClassicOverhaulDB.chatRemovals or {}
            db[OB.CharacterKey()] = {}
            OB.chatRemovals = db[OB.CharacterKey()]

            Say("forgot which channels you had taken out of which window.")
        else
            OB.modules.chat:PrintReport()
        end
        return
    end

    --[[ Whisper whoever you are looking at. Prat's `/tt`, and one of the
         most-used things it ships -- which is a fair summary of how much of a
         chat addon is small. ]]--
    if cmd == "tt" then
        OB.modules.chat:TellTarget(args)
        return
    end

    if cmd == "bar" then cmdBar(args) return end
    if cmd == "profile" then cmdProfile(args) return end

    -- a registered command beats a module id, because a command word is the more
    -- specific claim on the line
    local command = OB.commands[cmd]
    if command then command.Run(args) return end

    -- a module id claims the rest of the line
    if OB.optionIndex.modules[cmd] then
        local _, _, key, value = string.find(args, "^(%S*)%s*(.*)$")
        local w = findOption(OB.optionIndex.modules[cmd], key)

        if not w then
            Say("no '" .. cmd .. "' setting named '" .. tostring(key)
                    .. "'. Type " .. BLUE .. "/eqob help" .. WHITE .. " for a list.")
            return
        end

        handleOption(w, cmd .. " " .. key, value or "")
        return
    end

    local w = findOption(OB.optionIndex.global, raw)
    if not w then
        Say("unknown option |cffff5511" .. raw .. WHITE .. ". Type "
                .. BLUE .. "/eqob help" .. WHITE .. " for a list.")
        return
    end

    handleOption(w, w.caption, args)
end
