---
--- Server.lua - Server detection and management
---
--- This module handles identifying the current server and managing server-specific profiles.
--- It provides functions for auto-detection and data filtering based on the active server.
---

local _G = getfenv()

AtlasCFM = _G.AtlasCFM or {}

AtlasCFM.Server = {}

-- Server constants
AtlasCFM.Server.AUTO = "Auto"
AtlasCFM.Server.TURTLE = "Turtle WoW"
AtlasCFM.Server.TURTLE1 = "Turtle WoW 1.17.2"
AtlasCFM.Server.VANILLA_PLUS = "Vanilla Plus"
AtlasCFM.Server.CLASSIC = "Classic"

-- Strict matching constants (no inheritance)
AtlasCFM.Server.STRICT_TURTLE = "=" .. AtlasCFM.Server.TURTLE
AtlasCFM.Server.STRICT_TURTLE1 = "=" .. AtlasCFM.Server.TURTLE1

local currentDetectedServer = nil

--- Detects the current server based on realm name and unique items
--- @return string The name of the detected server
function AtlasCFM.Server.Detect()
    if currentDetectedServer then return currentDetectedServer end

    local realm = GetRealmName()
    local build = GetBuildInfo()

    -- Check build version for Turtle WoW
    if build == "1.18.1" then
        currentDetectedServer = AtlasCFM.Server.TURTLE
        return currentDetectedServer
    elseif build == "1.17.2" then
        currentDetectedServer = AtlasCFM.Server.TURTLE1
        return currentDetectedServer
    end

    -- Check realm name for Vanilla Plus (Hogger)
    if realm and string.find(realm, "Hogger") then
        currentDetectedServer = AtlasCFM.Server.VANILLA_PLUS
        return currentDetectedServer
    end

    currentDetectedServer = AtlasCFM.Server.CLASSIC
    return currentDetectedServer
end

--- Gets the currently active server (manual choice or detected)
--- @return string The active server profile name
function AtlasCFM.Server.GetActive()
    local choice = AtlasCFMOptions and AtlasCFMOptions.AtlasServer or AtlasCFM.Server.AUTO
    if choice == AtlasCFM.Server.AUTO then
        return AtlasCFM.Server.Detect()
    end
    return choice
end

--- Checks if the current server matches the given server name
--- @param serverName string The server name to check against
--- @return boolean True if matches
function AtlasCFM.Server.Is(serverName)
    if type(serverName) == "string" and string.sub(serverName, 1, 1) == "=" then
        serverName = string.sub(serverName, 2)
    end
    return AtlasCFM.Server.GetActive() == serverName
end

--- Validates if a data entry is visible on the current server
--- @param entry table Data entry containing 'servers' or 'Servers' requirement list
--- @param strictMode boolean Optional. If true, disables server inheritance (e.g. Turtle WoW 1.18.1 won't see 1.17.2 content)
--- @return boolean True if entry is visible, false otherwise
function AtlasCFM.Server.IsVisible(entry, strictMode)
    if not entry or type(entry) ~= "table" then return true end

    -- Поддерживаем и поле servers, и старый формат маркеров (8-й элемент)
    local servers = entry.servers or entry.Servers
    if not servers and entry[8] and type(entry[8]) == "table" then
        servers = entry[8]
    end

    -- Если ограничений нет — показываем везде
    if not servers or type(servers) ~= "table" then
        return true
    end

    local active = AtlasCFM.Server.GetActive()
    local hasWhitelist = false
    local isAllowed = false

    -- Используем pairs для поддержки как списков { "S1", "S2" }, так и словарей { ["S1"] = false }
    for k, s in pairs(servers) do
        local serverTarget = nil
        local isDeny = false

        if type(k) == "number" then
            -- Элемент списка: { "Turtle WoW", "!Vanilla Plus" }
            if type(s) == "string" then
                if string.sub(s, 1, 1) == "!" then
                    serverTarget = string.sub(s, 2)
                    isDeny = true
                else
                    serverTarget = s
                    hasWhitelist = true
                end
            end
        elseif type(k) == "string" then
            -- Ключ словаря: { ["Vanilla Plus"] = false, ["Turtle WoW"] = true }
            serverTarget = k
            if s == false then
                isDeny = true
            else
                hasWhitelist = true
            end
        end

        if serverTarget then
            local isStrict = false
            if type(serverTarget) == "string" and string.sub(serverTarget, 1, 1) == "=" then
                serverTarget = string.sub(serverTarget, 2)
                isStrict = true
            end

            -- Проверяем совпадение
            local match = (active == serverTarget)

            -- Наследование Turtle WoW (1.18.1 видит контент 1.17.2)
            -- Отключается, если включен строгий режим (параметр strictMode или префикс "=")
            if not match and not strictMode and not isStrict and active == AtlasCFM.Server.TURTLE and serverTarget == AtlasCFM.Server.TURTLE1 then
                match = true
            end

            if match then
                if isDeny then
                    return false     -- Если сервер в черном списке — сразу скрываем
                else
                    isAllowed = true -- Если в белом списке — помечаем как разрешенный
                end
            end
        end
    end

    -- Если были правила "белого списка", и ни одно не подошло — скрываем
    if hasWhitelist then
        return isAllowed
    end

    -- Если были только правила "черного списка" (или их вообще не было),
    -- и мы дошли до сюда — значит сервер не запрещен.
    return true
end

--- Retrieves a data field from an entry, prioritizing server-specific overrides
--- @param entry table The data entry table
--- @param fieldName string The base field name (e.g. "reagents", "skill")
--- @return any The field value
function AtlasCFM.Server.GetDataField(entry, fieldName)
    if not entry or type(entry) ~= "table" then return nil end
    if not fieldName then return nil end

    local active = AtlasCFM.Server.GetActive()

    -- Check for current server specific field
    local suffix = nil
    if active == AtlasCFM.Server.TURTLE then
        suffix = "_TURTLE"
    elseif active == AtlasCFM.Server.TURTLE1 then
        suffix = "_TURTLE1"
    elseif active == AtlasCFM.Server.VANILLA_PLUS then
        suffix = "_VANILLA_PLUS"
    end

    if suffix then
        local serverField = fieldName .. suffix
        if entry[serverField] ~= nil then
            return entry[serverField]
        end
    end

    -- Inheritance: TURTLE (1.18.1) inherits from TURTLE1 (1.17.2)
    if active == AtlasCFM.Server.TURTLE then
        local fallbackField = fieldName .. "_TURTLE1"
        if entry[fallbackField] ~= nil then
            return entry[fallbackField]
        end
    end

    return entry[fieldName]
end

--- Helper to create a blacklist entry for a server
--- @param serverName string The server name to exclude
--- @return string The exclusion string (e.g., "!Vanilla Plus")
function AtlasCFM.Server.Exclude(serverName)
    return "!" .. (serverName or "")
end

-- Добавляем метатаблицу для поддержки синтаксиса NOT_SERVER_NAME
-- Это позволяет писать AtlasCFM.Server.NOT_VANILLA_PLUS вместо "!Vanilla Plus"
setmetatable(AtlasCFM.Server, {
    __index = function(t, k)
        if type(k) == "string" and string.sub(k, 1, 4) == "NOT_" then
            local baseKey = string.sub(k, 5)
            local serverName = rawget(t, baseKey)
            if serverName then
                return "!" .. serverName
            end
        end
        return nil
    end
})
