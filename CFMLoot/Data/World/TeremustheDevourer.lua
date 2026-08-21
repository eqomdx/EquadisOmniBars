---
--- TeremustheDevourer.lua - Teremus the Devourer world boss loot data
---
--- This module contains comprehensive loot data for Teremus the Devourer,
--- the demon world boss located in the Blasted Lands. It includes rare drops,
--- epic equipment, and unique demonic items.
---
--- Features:
--- • Complete Teremus the Devourer loot table
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

-- World boss Teremus the Devourer data
AtlasCFM.InstanceData.TeremustheDevourer = {
    servers = { AtlasCFM.Server.VANILLA_PLUS },
    Name = LB["Teremus the Devourer"],
    Location = LZ["Blasted Lands"],
    Level = { 1, 60 },
    Acronym = "TeremustheDevourer",
    MaxPlayers = 40,
    DamageType = L["Shadow"],
    Bosses = {
        {
            id = "WBTeremustheDevourer",
            prefix = "1)",
            name = LB["Teremus the Devourer"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 83073 }, -- Blazing Scale
                { id = 83074 }, -- City Guard Gauntlets
                { id = 83075 }, -- Blood Scarred Scale
            }
        }
    },
}

-- Item initialization for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.TeremustheDevourer.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
