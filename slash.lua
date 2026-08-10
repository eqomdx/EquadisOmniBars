--[[ Equadis' OmniBars :: slash commands

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
    /eqob slot <id> <key> [value]  e.g. slot resource h 20
    /eqob <module> <key> [value]   e.g. power ticker nofull
    /eqob assign <slot> <module>
    /eqob profile use|new|copy|delete <name>
    /eqob restack | test | reset [all]
]]--

local OB = EquadisOmniBars

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
        OB.Print(label .. ": |cffffddcc" .. OB.DescribeOption(w))
        return
    end

    local err = OB.ParseOption(w, args)
    if err then
        OB.Print("|cffff5511" .. err)
    else
        OB.Print(label .. ": |cffffddcc" .. OB.DescribeOption(w))
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
    p(GREEN .. OB.addonName .. WHITE .. " commands:")
    p("  " .. BLUE .. "/eqob" .. WHITE .. " / " .. BLUE .. "/ob" .. WHITE
            .. " - open the settings panel")
    p("  " .. BLUE .. "/eqob test" .. WHITE .. " - start or stop the preview")
    p("  " .. BLUE .. "/eqob restack" .. WHITE
            .. " - re-stack the occupied slots top to bottom")
    p("  " .. BLUE .. "/eqob assign <slot> <module>" .. WHITE
            .. " - put a module in a slot")
    p("  " .. BLUE .. "/eqob profile use|new|copy|delete <name>" .. WHITE)
    p("  " .. BLUE .. "/eqob reset" .. WHITE .. " / " .. BLUE .. "reset all" .. WHITE
            .. " - this profile, or every profile")

    -- listed from the registry, so a command added by a later file appears here
    -- without this function being touched
    local extra = {}
    for name in pairs(OB.commands) do table.insert(extra, name) end
    table.sort(extra)

    for i = 1, table.getn(extra) do
        local command = OB.commands[extra[i]]
        p("  " .. BLUE .. "/eqob " .. extra[i] .. WHITE .. " - " .. (command.help or ""))
    end

    p(GREEN .. "Slots:" .. WHITE .. " " .. BLUE .. "/eqob slot <id> <key> <value>")
    local ids = {}
    for i = 1, table.getn(OB.slotOrder) do
        local id = OB.slotOrder[i]
        local occupant = OB.bound[id]
        if occupant then
            table.insert(ids, id .. "=" .. occupant.id)
        else
            table.insert(ids, id .. "=empty")
        end
    end
    p("  " .. GREY .. table.concat(ids, "  "))
    listOptions(OB.optionIndex.slot, "slot <id> ")

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

local function cmdSlot(args)
    local _, _, slotId, key, value = string.find(args, "^(%S+)%s+(%S+)%s*(.*)$")

    if not slotId then
        OB.Print("usage: /eqob slot <id> <key> [value]")
        return
    end

    if not OB.profile.slots[slotId] then
        OB.Print("no slot named '" .. slotId .. "'. Try: "
                .. table.concat(OB.slotOrder, ", "))
        return
    end

    local w = findOption(OB.optionIndex.slot, key)
    if not w then
        OB.Print("no slot setting named '" .. key .. "'.")
        return
    end

    --[[ Slot rows read through OB.panel.slot, which is also what the panel's
         selector drives. Pointing it at the named slot is what lets one set of
         row descriptors serve both. ]]--
    local previous = OB.panel.slot
    OB.panel.slot = slotId
    handleOption(w, slotId .. " " .. key, value or "")
    OB.panel.slot = previous
    OB.RefreshPanel()
end

local function cmdAssign(args)
    local _, _, slotId, moduleId = string.find(args, "^(%S+)%s+(%S+)$")

    if not slotId then
        OB.Print("usage: /eqob assign <slot> <module|auto|none>")
        return
    end

    if not OB.profile.slots[slotId] then
        OB.Print("no slot named '" .. slotId .. "'. Try: "
                .. table.concat(OB.slotOrder, ", "))
        return
    end

    if moduleId ~= "auto" and moduleId ~= "none" and not OB.modules[moduleId] then
        OB.Print("no module named '" .. moduleId .. "'. Try: "
                .. table.concat(OB.ModulesForSlot(slotId), ", "))
        return
    end

    if OB.modules[moduleId] and not OB.ClassAllows(OB.modules[moduleId]) then
        OB.Print("'" .. moduleId .. "' is not available to a " .. OB.class .. ".")
        return
    end

    OB.AssignSlot(slotId, moduleId)
    OB.BindSlots()
    OB.Refresh(true)
    OB.RefreshPanel()

    local occupant = OB.bound[slotId]
    if occupant then
        OB.Print(slotId .. ": " .. occupant.name)
    else
        OB.Print(slotId .. ": empty")
    end
end

local function cmdProfile(args)
    local _, _, action, name = string.find(args, "^(%S*)%s*(.*)$")
    action = string.lower(action or "")

    if action == "" or action == "list" then
        local names = OB.ProfileNames()
        OB.Print("profiles: " .. table.concat(names, ", "))
        OB.Print("this character uses '" .. OB.profileName .. "'.")
        return
    end

    if name == "" then
        OB.Print("usage: /eqob profile " .. action .. " <name>")
        return
    end

    if action == "use" then OB.SetProfile(name)
    elseif action == "new" then OB.NewProfile(name)
    elseif action == "copy" then OB.CopyProfile(name)
    elseif action == "delete" then OB.DeleteProfile(name)
    else OB.Print("usage: /eqob profile use|new|copy|delete <name>") end

    OB.RefreshPanel()
end

-- ---------------------------------------------------------------------------
-- dispatch
-- ---------------------------------------------------------------------------

SLASH_EQUADISOMNIBARS1 = "/eqob"
SLASH_EQUADISOMNIBARS2 = "/ob"
SLASH_EQUADISOMNIBARS3 = "/omnibars"

SlashCmdList["EQUADISOMNIBARS"] = function(msg)
    if not OB.profile then
        OB.Print("still loading -- try again in a moment.")
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
            OB.Print("preview running.")
        else
            OB.Print("preview stopped.")
        end
        return
    end

    if cmd == "restack" then
        OB.RestackSlots()
        OB.Refresh(true)
        OB.RefreshPanel()
        OB.Print("slots restacked -- this moves them for every character on the '"
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

    if cmd == "slot" then cmdSlot(args) return end
    if cmd == "assign" then cmdAssign(args) return end
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
            OB.Print("no '" .. cmd .. "' setting named '" .. tostring(key)
                    .. "'. Type " .. BLUE .. "/eqob help" .. WHITE .. " for a list.")
            return
        end

        handleOption(w, cmd .. " " .. key, value or "")
        return
    end

    local w = findOption(OB.optionIndex.global, raw)
    if not w then
        OB.Print("unknown option |cffff5511" .. raw .. WHITE .. ". Type "
                .. BLUE .. "/eqob help" .. WHITE .. " for a list.")
        return
    end

    handleOption(w, w.caption, args)
end
