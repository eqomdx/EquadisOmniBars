---
--- Cache.lua - Item caching system for Atlas-CFM Loot
--- Provides efficient item caching utilities and memoization
--- Features:
--- • Asynchronous item caching with batched tooltip requests
--- • Memoization to avoid duplicate cache operations
--- • Fallback mechanisms for environments without timers
--- • Global cache management and cleanup
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}
AtlasCFM.LootCache = AtlasCFM.LootCache or {}

-- Global cache of checked item sets
if not AtlasCFMLOOT_CHECKED_SETS then
    AtlasCFMLOOT_CHECKED_SETS = {}
    AtlasCFMLOOT_CHECKED_SETS_COUNT = 0
end

---
--- Creates stable hash string for a list of item IDs
--- Sorts item list to ensure reproducible hash generation
--- @param itemList table List of numeric item IDs
--- @return string Hash string for the item set
---
local function CreateItemSetHash(itemList)
    table.sort(itemList) -- Stable order for reproducible hash
    return table.concat(itemList, ",")
end

---
--- Periodic memo cache cleanup to avoid unbounded growth
--- Resets cache when it exceeds maximum size threshold
--- @return nil
---
local function CleanupMemoCache()
    if AtlasCFMLOOT_CHECKED_SETS_COUNT > 100 then
        AtlasCFMLOOT_CHECKED_SETS = {}
        AtlasCFMLOOT_CHECKED_SETS_COUNT = 0
    end
end

---
-- Forces the client to cache an item by touching its hyperlink via a hidden tooltip
-- This uses a hidden GameTooltip to request item info from the client cache/server.
-- @param itemID number Item ID to cache
-- @param attempts number Optional attempts count for repeated tries (default 1)
-- @return void
---
function AtlasCFM.LootCache.ForceCacheItem(itemID, maxAttempts, callback)
    if not itemID or itemID == 0 then
        if callback then callback(false) end
        return false
    end

    if GetItemInfo(itemID) then
        if callback then callback(true) end
        return true
    end

    maxAttempts = maxAttempts or 3
    local attempts = 0

    local function tryCache()
        if GetItemInfo(itemID) then
            if callback then callback(true) end
            return
        end

        -- Use a hidden tooltip to request item data from server
        AtlasCFMLootTooltip:SetHyperlink("item:" .. itemID .. ":0:0:0")
        attempts = attempts + 1

        if attempts < maxAttempts then
            -- Wait for client to receive data before retrying (0.15s is safer for server latency)
            AtlasCFM.Timer.Start(0.15, tryCache)
        else
            if callback then callback(false) end
        end
    end

    tryCache()
end

---
-- Public wrapper that proxies to the internal CacheAllItems defined in AtlasCFMLoot.lua during migration.
-- This keeps existing modules working while CacheAllItems remains local in AtlasCFMLoot.lua.
-- @param dataSource table Loot data to cache
-- @param callback function Optional callback to invoke after caching completes
-- @return void
-- @usage AtlasCFM.LootCache.CacheAllItems(lootData, function() PrintA("Caching complete") end)
-- @note Prefer this wrapper over direct CacheAllItems to get fallback and diagnostics in non-Core callers.
---
function AtlasCFM.LootCache.CacheAllItems(dataSource, callback)
    -- Unify caching logic here to decouple external callers from internal implementation
    CleanupMemoCache()
    if not dataSource or type(dataSource) ~= "table" then
        if callback then callback() end
        return
    end

    -- Collect all item IDs for caching
    local itemsToCache = {}
    local n = table.getn(dataSource)
    for i = 1, n do
        local item = dataSource[i]
        local itemID = nil
        if item then
            if type(item) == "table" then
                if item.id then
                    itemID = item.id
                    -- Map spells/enchants to item ids when needed (item database format)
                    if item.skill and item.type ~= "item" then
                        if AtlasCFM and AtlasCFM.SpellDB and AtlasCFM.SpellDB.enchants and AtlasCFM.SpellDB.enchants[itemID] then
                            itemID = AtlasCFM.SpellDB.enchants[itemID].item
                        elseif AtlasCFM and AtlasCFM.SpellDB and AtlasCFM.SpellDB.craftspells and AtlasCFM.SpellDB.craftspells[itemID] then
                            itemID = AtlasCFM.SpellDB.craftspells[itemID].item
                        end
                    end
                elseif item[1] then
                    itemID = item[1]
                    -- Map spells/enchants to item ids when needed (search result format)
                    local itemType = item[4]
                    if itemType == "spell" or itemType == "enchant" then
                        if AtlasCFM and AtlasCFM.SpellDB then
                            if itemType == "enchant" and AtlasCFM.SpellDB.enchants and AtlasCFM.SpellDB.enchants[itemID] then
                                itemID = AtlasCFM.SpellDB.enchants[itemID].item
                            elseif itemType == "spell" and AtlasCFM.SpellDB.craftspells and AtlasCFM.SpellDB.craftspells[itemID] then
                                itemID = AtlasCFM.SpellDB.craftspells[itemID].item
                            end
                        end
                    end
                end
            elseif type(item) == "number" then
                itemID = item
            end
            if itemID and itemID ~= 0 then
                table.insert(itemsToCache, itemID)
            end
        end
    end

    local totalToCache = table.getn(itemsToCache)
    if totalToCache == 0 then
        if callback then callback() end
        return
    end

    -- Memoization: skip repeated sets
    local itemsCopy = {}
    local n = table.getn(itemsToCache)
    for i = 1, n do itemsCopy[i] = itemsToCache[i] end
    local setHash = CreateItemSetHash(itemsCopy)
    if AtlasCFMLOOT_CHECKED_SETS[setHash] then
        if callback then callback() end
        return
    end

    -- Quick pre-check
    local quickCheckCount = math.min(5, totalToCache)
    local quickCachedCount = 0
    for i = 1, quickCheckCount do
        local itemID = itemsToCache[i]
        if GetItemInfo(itemID) then
            quickCachedCount = quickCachedCount + 1
        end
    end

    -- Full check to collect uncached items
    local uncachedItems = {}
    for i = 1, totalToCache do
        local itemID = itemsToCache[i]
        if not GetItemInfo(itemID) then
            table.insert(uncachedItems, itemID)
        end
    end

    if table.getn(uncachedItems) == 0 then
        if not AtlasCFMLOOT_CHECKED_SETS[setHash] then
            AtlasCFMLOOT_CHECKED_SETS[setHash] = true
            AtlasCFMLOOT_CHECKED_SETS_COUNT = AtlasCFMLOOT_CHECKED_SETS_COUNT + 1
        end
        if callback then callback() end
        return
    end

    -- If timers are unavailable, fallback to force cache synchronously
    if not AtlasCFM.Timer or not AtlasCFM.Timer.Start then
        if not AtlasCFMLOOT_DEBUG_FALLBACK_CACHE_REPORTED then
            PrintA("AtlasCFM.Timer not found, using fallback force cache")
            AtlasCFMLOOT_DEBUG_FALLBACK_CACHE_REPORTED = true
        end
        local m = table.getn(uncachedItems)
        for i = 1, m do
            AtlasCFM.LootCache.ForceCacheItem(uncachedItems[i], 1)
        end
        if callback then callback() end
        return
    end

    -- Batched tooltip-driven cache priming
    local batchSize = 3
    local maxIterations = 2
    local iteration = 1

    local tooltipName = "AtlasCFMLootHiddenTooltip_Batch"
    local tooltip = _G[tooltipName]
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        _G[tooltipName] = tooltip
    end

    local function runIteration()
        local idx = 1
        local total = table.getn(uncachedItems)

        local function processBatch()
            local processed = 0
            while processed < batchSize and idx <= total do
                local itemID = uncachedItems[idx]
                tooltip:ClearLines()
                tooltip:SetHyperlink("item:" .. itemID .. ":0:0:0")
                idx = idx + 1
                processed = processed + 1
            end

            if idx <= total then
                local delay = (iteration == 1) and 0.07 or 0.09
                AtlasCFM.Timer.Start(delay, function()
                    processBatch()
                end)
            else
                local delay = (iteration == 1) and 0.07 or 0.09
                AtlasCFM.Timer.Start(delay, function()
                    local remaining = {}
                    for i = 1, total do
                        local id = uncachedItems[i]
                        if not GetItemInfo(id) then
                            table.insert(remaining, id)
                        end
                    end
                    uncachedItems = remaining

                    if table.getn(uncachedItems) == 0 or iteration >= maxIterations then
                        if not AtlasCFMLOOT_CHECKED_SETS[setHash] then
                            AtlasCFMLOOT_CHECKED_SETS[setHash] = true
                            AtlasCFMLOOT_CHECKED_SETS_COUNT = AtlasCFMLOOT_CHECKED_SETS_COUNT + 1
                        end
                        if callback then callback() end
                    else
                        iteration = iteration + 1
                        local nextDelay = (iteration == 1) and 0.07 or 0.09
                        AtlasCFM.Timer.Start(nextDelay, function()
                            runIteration()
                        end)
                    end
                end)
            end
        end

        processBatch()
    end

    runIteration()
end
