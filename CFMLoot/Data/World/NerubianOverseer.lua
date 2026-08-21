---
--- NerubianOverseer.lua - Nerubian Overseer world boss loot data
---
--- This module contains comprehensive loot data for the Nerubian Overseer,
--- a special world boss encounter. It includes unique drops, nerubian-themed
--- equipment, and boss-specific rewards from this elite encounter.
---
--- Features:
--- • Complete Nerubian Overseer loot table
--- • Nerubian-themed equipment
--- • Rare and epic drops
--- • Unique world boss rewards
--- • Encounter mechanics data
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

-- World boss Nerubian Overseer data
AtlasCFM.InstanceData.Nerubian = {
    Servers = { AtlasCFM.Server.TURTLE1 },
    Name = LB["Nerubian Overseer"],
    Location = LZ["Eastern Plaguelands"],
    Level = { 1, 60 },
    Acronym = "Spooder",
    MaxPlayers = 40,
    DamageType = L["Nature"] .. ", " .. L["Shadow"],
    Bosses = {
        {
            id = "WBNerubian",
            prefix = "1)",
            name = LB["Nerubian Overseer"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 51738 },                                      -- Tunnel Fiend Carapace
                { id = 51737 },                                      -- Vestments of Eternal Autumn
                { id = 51736 },                                      -- Plague-Infected Robe
                { id = 51735 },                                      -- Scourgelord's Fang
                { id = 51740 },                                      -- Crown of Skittering Shadows
                {},
                { id = 51734 },                                      -- Shawl of Haunted Memories
                { id = 51733 },                                      -- Shadow-Weaver's Cape
                { id = 51732 },                                      -- Silken Mantle of Dying Hope
                { id = 51731 },                                      -- Venom Covered Cloak
                { id = 51730 },                                      -- Shawl of Nerubian Silk
                {},
                { id = 12717, dropRate = 5,  container = { 12640 } }, -- Plans: Lionheart Helm
                { id = 22388, dropRate = 5,  container = { 22385 } }, -- Plans: Titanic Leggings
                { id = 83547, dropRate = 5,  container = { 65014 } }, -- Plans: Pauldron of Deflection
                { id = 51739, dropRate = 100 },                      -- Little Ball of Spider Web
            }
        }
    }
}

-- Item initialization for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.Nerubian.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
