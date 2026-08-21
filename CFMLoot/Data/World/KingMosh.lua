---
--- KingMosh.lua - King Mosh world boss loot data
---
--- This module contains comprehensive loot data for King Mosh, the demon
--- world boss located in the Un'goro Crater. It includes rare drops,
--- epic equipment, and unique demonic items.
---
--- Features:
--- • Complete King Mosh loot table
--- • Rare and epic drops
--- • Demonic-themed equipment
--- • Unique world boss rewards
--- • Respawn timer information
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses
local LS = AtlasCFM.Localization.Spells

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

-- World boss King Mosh data
AtlasCFM.InstanceData.KingMosh = {
    servers = { AtlasCFM.Server.VANILLA_PLUS },
    Name = LB["King Mosh"],
    Location = LZ["Un'goro Crater"],
    Level = { 1, 60 },
    Acronym = "KingMosh",
    MaxPlayers = 40,
    DamageType = L["Physical"],
    Bosses = {
        {
            id = "WBKingMosh",
            prefix = "1)",
            name = LB["King Mosh"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 20003 },                                                  -- Devilsaur Claws
                { id = 20005 },                                                  -- Devilsaur Claws
                { id = 26013, disc = L["Consumable"] },                          -- King's Heart
                { id = 81041 },                                                  -- Everlasting Liver
                { id = 83061 },                                                  -- Royal Incisor
                {},
                { id = 83167, disc = L["Quest Reward"], container = { 83123 } }, -- Pattern: Vital Devilsaur Hide
            }
        }
    },
}

-- Item initialization for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.KingMosh.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
