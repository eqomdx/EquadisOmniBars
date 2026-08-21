---
--- RazorfenKraul.lua - Razorfen Kraul dungeon instance loot data
---
--- This module contains comprehensive loot tables and boss data for the Razorfen Kraul
--- 5-player dungeon instance. It includes all boss encounters, rare drops,
--- and dungeon-specific items with their respective drop rates.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Mid-level dungeon item drops
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
local LMD = AtlasCFM.Localization.MapData

local Colors = AtlasCFM.Colors

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

AtlasCFM.InstanceData.RazorfenKraul = {
    Name = LZ["Razorfen Kraul"],
    Location = LZ["The Barrens"],
    Level = { 19, 38 },
    Acronym = "RFK",
    MaxPlayers = 5,
    DamageType = L["Physical"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] }
    },
    Bosses = {
        {
            prefix = "1)",
            name = LB["Roogug"],
            color = Colors.GREY,
        },
        {
            id = "RFKAggem",
            prefix = "2)",
            name = LB["Aggem Thorncurse"],
            defaults = { dropRate = 35 },
            loot = {
                { id = 6681,  dropRate = 100 },                                                                  -- Thornspike
                {},
                { id = 80732, servers = { AtlasCFM.Server.TURTLE1 } },                                           -- Boar Tamer Gloves
                { id = 80733, servers = { AtlasCFM.Server.TURTLE1 } },                                           -- Cursed Thornblade
                {},
                { id = 80789, dropRate = .1,                        servers = { AtlasCFM.Server.TURTLE1 } },     -- Sharpsight Eyepatch
                {},
                { id = 5825,  dropRate = 10,                        container = { 6751, 6752 },           servers = { AtlasCFM.Server.TURTLE1 } }, -- Treshala's Pendant
            }
        },
        {
            id = "RFKDeathSpeakerJargba",
            prefix = "3)",
            name = LB["Death Speaker Jargba"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 6685 },                                            -- Death Speaker Mantle
                { id = 6682 },                                            -- Death Speaker Robes
                { id = 2816 },                                            -- Death Speaker Scepter
                {},
                { id = 5825, dropRate = 10, container = { 6751, 6752 } }, -- Treshala's Pendant
            }
        },
        {
            id = "RFKOverlordRamtusk",
            prefix = "4)",
            name = LB["Overlord Ramtusk"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 6687 },                                            -- Corpsemaker
                { id = 6686 },                                            -- Tusken Helm
                { id = 80734, servers = { AtlasCFM.Server.TURTLE1 } },    -- Quilguard Legguards
                {},
                { id = 5825,  dropRate = 10,                        container = { 6751, 6752 } }, -- Treshala's Pendant
            }
        },
        {
            id = "RFKRazorfenSpearhide",
            name = LMD["Razorfen Spearhide"],
            postfix = L["Rare"],
            loot = {
                { id = 6679, dropRate = 80 },                             -- Armor Piercer
                {},
                { id = 5825, dropRate = 10, container = { 6751, 6752 } }, -- Treshala's Pendant
            }
        },
        {
            id = "RFKRotthorn",
            servers = { AtlasCFM.Server.TURTLE1 },
            prefix = "5)",
            name = LB["Rotthorn"],
            defaults = { dropRate = 25 },
            loot = {
                { id = 50800 },                                               -- Bramblethorn Girdle
                { id = 58089 },                                               -- Thornlash Branch
                { id = 58090 },                                               -- Seed of Writhing Growth
                { id = 58091 },                                               -- Idol of the Thorned Grove
                {},
                { id = 41853, dropRate = 100, container = { 41854, 41855 } }, -- Tainted Brambleheart
            }
        },
        {
            id = "RFKAgathelos",
            prefix = "6)",
            name = LB["Agathelos the Raging"],
            defaults = { dropRate = 25 },
            loot = {
                { id = 6690 },                                                        -- Ferine Leggings
                { id = 6691 },                                                        -- Swinetusk Shank
                { id = 80735, servers = { AtlasCFM.Server.TURTLE1 } },                -- Warded Boarleather Belt
                { id = 80736, servers = { AtlasCFM.Server.TURTLE1 } },                -- Rageboar Harness
                {},
                { id = 69170, dropRate = .5,                        servers = { AtlasCFM.Server.TURTLE1 } }, -- Ivory Boar
            }
        },
        {
            id = "RFKBlindHunter",
            prefix = "7)",
            name = LB["Blind Hunter"],
            postfix = L["Rare"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 6695 }, -- Stygian Bone Amulet
                { id = 6697 }, -- Batwing Mantle
                { id = 6696 }, -- Nightstalker Bow
            }
        },
        {
            id = "RFKCharlgaRazorflank",
            prefix = "8)",
            name = LB["Charlga Razorflank"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 6693 },                                                                                       -- Agamaggan's Clutch
                { id = 6694 },                                                                                       -- Heart of Agamaggan
                { id = 6692 },                                                                                       -- Pronged Reaver
                {},
                { id = 17008, dropRate = 100,                 container = { 17042, 17043, 17039 } },                 -- Small Scroll
                {},
                { id = 5825,  dropRate = 10,                  container = { 6751, 6752 } },                          -- Treshala's Pendant
                { id = 5792,  dropRate = 100,                 container = { 4197, 6725, 6742 } },                    -- Razorflank's Medallion
                { id = 5793,  dropRate = 100,                 container = { 4197, 6725, 6742 } },                    -- Razorflank's Heart
                { id = 51217, disc = L["Transmogrification"], dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 17039, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Skullbreaker
                { id = 17042, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Nail Spitter
                { id = 17043, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Zealot's Robe
            }
        },
        {
            id = "RFKWillixtheImporter",
            prefix = "9)",
            name = LMD["Willix the Importer"],
            color = Colors.GREY,
        },
        {
            id = "RFKHeralathFallowbrook",
            name = LMD["Heralath Fallowbrook"],
            color = Colors.GREY,
        },
        {
            id = "RFKEarthcallerHalmgar",
            prefix = "10)",
            name = LB["Earthcaller Halmgar"],
            postfix = L["Rare"],
            defaults = { dropRate = 50 },
            loot = {
                { id = 6689 },                                            -- Wind Spirit Staff
                {},
                { id = 6688 },                                            -- Whisperwind Headdress
                {},
                { id = 5825, dropRate = 10, container = { 6751, 6752 } }, -- Treshala's Pendant
            }
        },
        {
            id = "RFKTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["Razorfen Kraul"],
            defaults = { dropRate = .1 },
            loot = {
                { id = 80789, servers = { AtlasCFM.Server.TURTLE1 } },    -- Sharpsight Eyepatch
                { id = 2264 },                                            -- Mantle of Thieves
                { id = 1488 },                                            -- Avenger's Armor
                { id = 4438 },                                            -- Pugilist Bracers
                { id = 1978 },                                            -- Wolfclaw Gloves
                { id = 2039 },                                            -- Plains Ring
                { id = 1727 },                                            -- Sword of Decay
                { id = 776 },                                             -- Vendetta
                { id = 1976 },                                            -- Slaghammer
                { id = 1975 },                                            -- Pysan's Old Greatsword
                { id = 2549 },                                            -- Staff of the Shade
                {},
                { id = 5825,  dropRate = 10,                        container = { 6751, 6752 } }, -- Treshala's Pendant
            }
        },
    },
}

-- Initialize items for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.RazorfenKraul.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
