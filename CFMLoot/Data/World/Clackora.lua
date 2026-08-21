---
--- Clackora.lua - Clackora world boss loot data
---
--- This module contains comprehensive loot data for Clackora, a special
--- world boss encounter. It includes unique drops, rare equipment,
--- and boss-specific rewards from this elite encounter.
---
--- Features:
--- • Complete Clackora loot table
--- • Rare and epic drops
--- • Boss-specific equipment
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

-- World bosses data
AtlasCFM.InstanceData.Clackora = {
    Servers = { AtlasCFM.Server.TURTLE },
    Name = LB["Cla'ckora"],
    Location = LZ["Azshara"],
    Level = { 1, 60 },
    Acronym = "Clackora",
    MaxPlayers = 40,
    DamageType = L["Frost"],
    Bosses = {
        {
            id = "WBClackora",
            prefix = "1)",
            name = LB["Cla'ckora"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 55501, dropRate = 20 }, -- Sphere of the Endless Gulch
                { id = 55494, dropRate = 20 }, -- The Abyssal Pincer
                { id = 55495, dropRate = 20 }, -- Zandalar Predator's Glaive
                { id = 55498, dropRate = 20 }, -- Clamshell of the Depths
                { id = 55504, dropRate = 20 }, -- Anchor of the Wavecutter
                {},
                { id = 55502 },                -- Iceplated Leggings
                { id = 55499 },                -- Primal Murloc Scale Belt
                { id = 55500 },                -- Barnacle Vambraces
                { id = 55496 },                -- Polychromatic Pearl Necklace
                { id = 55503 },                -- Loop of Unceasing Frost
                { id = 55497 },                -- Idol of Ebb and Flow
                {},
                { id = 92020, dropRate = 5 },  -- Spawn of Cla'ckora
            }
        }
    }
}

-- Initialize items for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.Clackora.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil
end
