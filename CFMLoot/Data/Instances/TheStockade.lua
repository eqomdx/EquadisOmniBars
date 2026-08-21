---
--- TheStockade.lua - The Stockade dungeon instance loot data
---
--- This module contains comprehensive loot tables and boss data for The Stockade
--- 5-player dungeon instance. It includes all boss encounters, rare drops,
--- and dungeon-specific items with their respective drop rates.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Low-level dungeon item drops
--- • Dungeon entrance and layout data
--- • Level-appropriate loot organization
--- • Quest reward items
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

AtlasCFM.InstanceData.TheStockade = {
    Name = LZ["The Stockade"],
    Location = LZ["Stormwind City"],
    Level = { 15, 31 },
    Acronym = "Stocks",
    MaxPlayers = 5,
    DamageType = L["Physical"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] }
    },

    Bosses = {
        {
            id = "SWStTargorr",
            prefix = "1)",
            name = LB["Targorr the Dread"],
            postfix = L["Varies"],
            defaults = { dropRate = 50 },
            loot = {
                { id = 80721, servers = { AtlasCFM.Server.TURTLE1 } },     -- Heavy Prison Cuffs
                { id = 80722, servers = { AtlasCFM.Server.TURTLE1 } },     -- Dreadskull Pauldrons
                {},
                { id = 3630,  dropRate = 100,                       container = { 3400, 1317 } }, -- Head of Targorr
            }
        },
        {
            id = "SWStKamDeepfury",
            prefix = "2)",
            name = LB["Kam Deepfury"],
            loot = {
                { id = 2280,  dropRate = 1 },                                         -- Kam's Walking Stick
                {},
                { id = 3640,  dropRate = 100, container = { 3562, 1264 } },           -- Head of Deepfury
                {},
                { id = 80723, dropRate = 90,  servers = { AtlasCFM.Server.TURTLE1 } }, -- Nail on a Plank
            }
        },
        {
            id = "SWStHamhock",
            prefix = "3)",
            servers = { AtlasCFM.Server.TURTLE1 },
            name = LB["Hamhock"],
            defaults = { dropRate = 50 },
            loot = {
                { id = 80724 }, -- Cell Heater
                { id = 80725 }, -- Hamhock's Nose Ring
            }
        },
        {
            id = "SWStBazil",
            prefix = "4)",
            name = LB["Bazil Thredd"],
            loot = {
                { id = 2909,  dropRate = 80 },                                                                       -- Red Wool Bandana
                { id = 2926,  dropRate = 100,                 container = { 2933 } },                                -- Head of Bazil Thredd
                {},
                { id = 80729, dropRate = 35,                  servers = { AtlasCFM.Server.TURTLE1 } },               -- Standard Issue Tunic
                { id = 80730, dropRate = 35,                  servers = { AtlasCFM.Server.TURTLE1 } },               -- Convict Moccasins
                { id = 80731, dropRate = 30,                  servers = { AtlasCFM.Server.TURTLE1 } },               -- Runed Hookblade
                {},
                { id = 80796, dropRate = .05,                 servers = { AtlasCFM.Server.TURTLE1 } },               -- Tattered Cloak of the Insurgency
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 1,                         servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            id = "SWStDextren",
            prefix = "5)",
            name = LB["Dextren Ward"],
            loot = {
                { id = 2909,  dropRate = 40 },                                         -- Red Wool Bandana
                { id = 3628,  dropRate = 100, container = { 2033, 2906 } },            -- Hand of Dextren Warder
                {},
                { id = 80726, dropRate = 35,  servers = { AtlasCFM.Server.TURTLE1 } }, -- Gravedigger Boots
                { id = 80727, dropRate = 35,  servers = { AtlasCFM.Server.TURTLE1 } }, -- Broken Bottle
                { id = 80728, dropRate = 30,  servers = { AtlasCFM.Server.TURTLE1 } }, -- Stormwind Guard Spear
                {},
                { id = 80796, dropRate = .05, servers = { AtlasCFM.Server.TURTLE1 } }, -- Tattered Cloak of the Insurgency
            }
        },
        {
            id = "SWStBruegalIronknuckle",
            prefix = "6)",
            name = LB["Bruegal Ironknuckle"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 3228 },                -- Jimmied Handcuffs
                { id = 2941 },                -- Prison Shank
                { id = 2942 },                -- Iron Knuckles
                {},
                { id = 2909, dropRate = 80 }, -- Red Wool Bandana
            }
        },
        {
            id = "SWStTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["The Stockade"],
            loot = {
                { id = 80796, dropRate = .05, servers = { AtlasCFM.Server.TURTLE1 } }, -- Tattered Cloak of the Insurgency
                { id = 1076,  dropRate = .6 },                                         -- Defias Renegade Ring
                {},
                { id = 2909,  dropRate = 80 },                                         -- Red Wool Bandana
            }
        },
    },
}

for _, bossData in ipairs(AtlasCFM.InstanceData.TheStockade.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil
end
