---
--- MoltenCore.lua - Molten Core raid instance loot data
---
--- This module contains comprehensive loot tables and boss data for the Molten Core
--- 40-player raid instance. It includes all boss encounters, shared loot pools,
--- tier set items, legendary drops, and crafting patterns with their drop rates.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Shared loot pool definitions
--- • Tier 1 set items and tokens
--- • Legendary weapon drops
--- • Crafting patterns and recipes
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses
local LF = AtlasCFM.Localization.Factions
local LMD = AtlasCFM.Localization.MapData

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}
local mCShareloot = {
    {},
    { id = 18264, dropRate = 1, container = { 18262 } }, -- Plans: Elemental Sharpening Stone
    { id = 18292, dropRate = 1, container = { 18282 } }, -- Schematic: Core Marksman Rifle
    { id = 18291, dropRate = 1, container = { 18168 } }, -- Schematic: Force Reactive Disk
    { id = 18290, dropRate = 1, container = { 18283 } }, -- Schematic: Biznicks 247x128 Accurascope
    { id = 18252, dropRate = 1, container = { 18251 } }, -- Pattern: Core Armor Kit
    { id = 18265, dropRate = 1, container = { 18263 } }, -- Pattern: Flarecore Wraps
    { id = 21371, dropRate = 1, container = { 21342 } }, -- Pattern: Core Felcloth Bag
    { id = 18257, dropRate = 1, container = { 18253 } }, -- Recipe: Major Rejuvenation Potion
    { id = 18259, dropRate = 1 },                        -- Formula: Enchant Weapon - Spell Power
    { id = 18260, dropRate = 1 },                        -- Formula: Enchant Weapon - Healing Power
}

AtlasCFM.InstanceData.MoltenCore = {
    Name = LZ["Molten Core"],
    Location = LZ["Blackrock Depths"],
    Level = 60,
    Acronym = "MC",
    Attunement = true,
    MaxPlayers = 40,
    DamageType = L["Fire"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] }
    },
    Reputation = {
        { name = LF["Hydraxian Waterlords"], loot = "HydroxianWaterLords" },
    },
    Keys = {
        { name = LMD["Aqual Quintessence"],   loot = "VanillaKeys", info = L["Boss"] },
        { name = LMD["Eternal Quintessence"], loot = "VanillaKeys", info = L["Boss"] }
    },
    Bosses = {
        {
            id = "Gehennas",
            servers = { AtlasCFM.Server.NOT_TURTLE },
            prefix = "1)",
            name = LB["Gehennas"],
            defaults = { dropRate = 5 },
            loot = {
                { id = 16812, dropRate = 25,                       container = { { 47202, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gloves of Prophecy
                { id = 16839, dropRate = 25,                       container = { { 47124, servers = { AtlasCFM.Server.TURTLE1 } }, { 47132, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Gloves
                { id = 16860, dropRate = 25,                       container = { { 47004, servers = { AtlasCFM.Server.TURTLE1 } }, { 47012, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Gloves
                { id = 16826, dropRate = 25,                       servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                               -- Nightslayer Gloves
                { id = 16862, dropRate = 25,                       container = { { 47247, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Sabatons of Might
                { id = 16849, dropRate = 25,                       servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                               -- Giantstalker's Boots
                { id = 34350, disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Burnt Bindings
                { id = 34342, disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Charred Bindings
                { id = 34334, disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Melted Bindings
                {},
                { id = 17077 },                                                                                                                                                                                    -- Crimson Shocker
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 18870 },                                                                                                                                                                                    -- Helm of the Lifegiver
                { id = 18872 },                                                                                                                                                                                    -- Manastorm Leggings
                { id = 18875 },                                                                                                                                                                                    -- Salamander Scale Pants
                { id = 18878 },                                                                                                                                                                                    -- Sorcerous Dagger
                { id = 18879 },                                                                                                                                                                                    -- Heavy Dark Iron Ring
                { id = 19145 },                                                                                                                                                                                    -- Robe of Volatile Power
                { id = 19146 },                                                                                                                                                                                    -- Wristguards of Stability
                { id = 19147 },                                                                                                                                                                                    -- Ring of Spell Power
                { id = 26058, dropRate = 33,                       servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                   -- Mask of Whispered Secrets
                {},
                { id = 20951, dropRate = 1,                        container = { 18253 } },                                                                                                                        -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Incindis",
            servers = { AtlasCFM.Server.TURTLE },
            prefix = "1)",
            name = LB["Incindis"], --52145
            defaults = { dropRate = 5 },
            loot = {
                { id = 16812, dropRate = 25,  container = { { 47202, servers = { AtlasCFM.Server.TURTLE1 } } } },                                                  -- Gloves of Prophecy
                { id = 16839, dropRate = 25,  container = { { 47124, servers = { AtlasCFM.Server.TURTLE1 } }, { 47132, servers = { AtlasCFM.Server.TURTLE1 } } } }, -- Earthfury Gloves
                { id = 16860, dropRate = 25,  container = { { 47004, servers = { AtlasCFM.Server.TURTLE1 } }, { 47012, servers = { AtlasCFM.Server.TURTLE1 } } } }, -- Lawbringer Gloves
                { id = 16826, dropRate = 25 },                                                                                                                     -- Nightslayer Gloves
                { id = 16862, dropRate = 25,  container = { { 47247, servers = { AtlasCFM.Server.TURTLE1 } } } },                                                  -- Sabatons of Might
                { id = 16849, dropRate = 25 },                                                                                                                     -- Giantstalker's Boots
                {},
                { id = 58205, dropRate = 20,  servers = { AtlasCFM.Server.TURTLE } },                                                                              -- Primal Flameslinger
                { id = 58206, dropRate = 20,  servers = { AtlasCFM.Server.TURTLE } },                                                                              -- Idol of the Forgotten Wilds
                { id = 58207, dropRate = 20,  servers = { AtlasCFM.Server.TURTLE } },                                                                              -- Fist of the Flamewaker
                { id = 58208, dropRate = 20,  servers = { AtlasCFM.Server.TURTLE } },                                                                              -- Shroud of Flowing Magma
                { id = 58209, dropRate = 20,  servers = { AtlasCFM.Server.TURTLE } },                                                                              -- Sizzling Pyrestone Aureole
                {},
                { id = 17077 },                                                                                                                                    -- Crimson Shocker
                { id = 18861 },                                                                                                                                    -- Flamewaker Legplates
                { id = 18870 },                                                                                                                                    -- Helm of the Lifegiver
                { id = 18872 },                                                                                                                                    -- Manastorm Leggings
                { id = 18875 },                                                                                                                                    -- Salamander Scale Pants
                { id = 18878 },                                                                                                                                    -- Sorcerous Dagger
                { id = 18879 },                                                                                                                                    -- Heavy Dark Iron Ring
                { id = 19145 },                                                                                                                                    -- Robe of Volatile Power
                { id = 19146 },                                                                                                                                    -- Wristguards of Stability
                { id = 19147 },                                                                                                                                    -- Ring of Spell Power
                {},
                { id = 41988, dropRate = 100, container = { 41990 },                                                                                             servers = { AtlasCFM.Server.TURTLE } }, -- Molten Scale
                { id = 20951, dropRate = 1,   container = { 18253 } },                                                                                             -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Lucifron",
            prefix = "2)",
            name = LB["Lucifron"],
            defaults = { dropRate = 4 },
            loot = {
                { id = 16800, dropRate = 20,                       container = { { 47085, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Boots
                { id = 16829, dropRate = 20,                       container = { { 47337, servers = { AtlasCFM.Server.TURTLE1 } }, { 47345, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Boots
                { id = 16837, dropRate = 20,                       container = { { 47127, servers = { AtlasCFM.Server.TURTLE1 } }, { 47135, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Boots
                { id = 16859, dropRate = 20,                       container = { { 47007, servers = { AtlasCFM.Server.TURTLE1 } }, { 47015, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Boots
                { id = 16863, dropRate = 30,                       container = { { 47244, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Might
                { id = 16805, dropRate = 30,                       container = { { 47280, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Gloves
                { id = 34350, disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Burnt Bindings
                { id = 34342, disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Charred Bindings
                { id = 34334, disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Melted Bindings
                {},
                { id = 17109, dropRate = 20 },                                                                                                                                                                     -- Choker of Enlightenment
                { id = 18870 },                                                                                                                                                                                    -- Helm of the Lifegiver
                { id = 19145 },                                                                                                                                                                                    -- Robe of Volatile Power
                { id = 19146 },                                                                                                                                                                                    -- Wristguards of Stability
                { id = 18872 },                                                                                                                                                                                    -- Manastorm Leggings
                { id = 18875 },                                                                                                                                                                                    -- Salamander Scale Pants
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 18879 },                                                                                                                                                                                    -- Heavy Dark Iron Ring
                { id = 19147 },                                                                                                                                                                                    -- Ring of Spell Power
                { id = 17077 },                                                                                                                                                                                    -- Crimson Shocker
                { id = 18878 },                                                                                                                                                                                    -- Sorcerous Dagger
                {},
                { id = 16665, disc = L["Book"],                    dropRate = 100 },                                                                                                                               -- Tome of Tranquilizing Shot
                { id = 20951, dropRate = 1,                        container = { 18253 } },                                                                                                                        -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Magmadar",
            prefix = "3)",
            name = LB["Magmadar"],
            defaults = { dropRate = 5 },
            loot = {
                { id = 16814, dropRate = 20,                      container = { { 47204, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Trousers of Prophecy
                { id = 16796, dropRate = 20,                      container = { { 47084, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Leggings
                { id = 16810, dropRate = 20,                      container = { { 47282, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Pants
                { id = 16835, dropRate = 17,                      container = { { 47336, servers = { AtlasCFM.Server.TURTLE1 } }, { 47344, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Leggings
                { id = 16843, dropRate = 17,                      container = { { 47126, servers = { AtlasCFM.Server.TURTLE1 } }, { 47134, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Pants
                { id = 16855, dropRate = 17,                      container = { { 47006, servers = { AtlasCFM.Server.TURTLE1 } }, { 47014, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Legplates
                { id = 16867, dropRate = 17,                      container = { { 47246, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Legplates of Might
                { id = 16822, dropRate = 20,                      servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                -- Nightslayer Pants
                { id = 16847, dropRate = 17,                      servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                -- Giantstalker's Leggings
                { id = 34352, disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Hot Claws
                { id = 34344, disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Fiery Claws
                { id = 34336, disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Molten Grips
                {},
                { id = 19142 },                                                                                                                                                                                    -- Fire Runed Grimoire
                { id = 17069, dropRate = 20 },                                                                                                                                                                     -- Striker's Mark
                { id = 18203, dropRate = 20 },                                                                                                                                                                     -- Eskhandar's Right Claw
                { id = 17073, dropRate = 20 },                                                                                                                                                                     -- Earthshaker
                { id = 18822, dropRate = 5 },                                                                                                                                                                      -- Obsidian Edged Blade
                { id = 17065, dropRate = 17 },                                                                                                                                                                     -- Medallion of Steadfast Might
                { id = 18829 },                                                                                                                                                                                    -- Deep Earth Spaulders
                { id = 18823 },                                                                                                                                                                                    -- Aged Core Leather Gloves
                { id = 19143 },                                                                                                                                                                                    -- Flameguard Gauntlets
                { id = 19136 },                                                                                                                                                                                    -- Mana Igniting Cord
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 19144 },                                                                                                                                                                                    -- Sabatons of the Flamewalker
                { id = 18824 },                                                                                                                                                                                    -- Magma Tempered Boots
                { id = 18821 },                                                                                                                                                                                    -- Quick Strike Ring
                { id = 18820 },                                                                                                                                                                                    -- Talisman of Ephemeral Power
                {},
                { id = 20951, dropRate = 1,                       container = { 18253 } },                                                                                                                         -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Garr",
            prefix = "4)",
            name = LB["Garr"],
            defaults = { dropRate = 5 },
            loot = {
                { id = 16813, dropRate = 20,                                 container = { { 47198, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Circlet of Prophecy
                { id = 16795, dropRate = 20,                                 container = { { 47078, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Crown
                { id = 16808, dropRate = 20,                                 container = { { 47276, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Horns
                { id = 16821, dropRate = 20,                                 servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                     -- Nightslayer Cover
                { id = 16834, dropRate = 17,                                 container = { { 47330, servers = { AtlasCFM.Server.TURTLE1 } }, { 47338, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Helm
                { id = 16846, dropRate = 17,                                 servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                     -- Giantstalker's Helmet
                { id = 16842, dropRate = 17,                                 container = { { 47120, servers = { AtlasCFM.Server.TURTLE1 } }, { 47128, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Helmet
                { id = 16854, dropRate = 17,                                 container = { { 47000, servers = { AtlasCFM.Server.TURTLE1 } }, { 47008, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Helm
                { id = 16866, dropRate = 17,                                 container = { { 47240, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Helm of Might
                { id = 34349, dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                         -- Burnt Shoulderpads
                { id = 34341, dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                         -- Charred Spaulders
                { id = 34333, dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                         -- Melted Pauldrons
                {},
                { id = 17782, servers = { AtlasCFM.Server.TURTLE1 } },                                                                                                                                             -- Talisman of Binding Shard
                { id = 18564, disc = L["Quest Item"] .. ", " .. L["Right Half"], container = { 19019 } },                                                                                                          -- Bindings of the Windseeker
                { id = 18829 },                                                                                                                                                                                    -- Deep Earth Spaulders
                { id = 18823 },                                                                                                                                                                                    -- Aged Core Leather Gloves
                { id = 19143 },                                                                                                                                                                                    -- Flameguard Gauntlets
                { id = 19136 },                                                                                                                                                                                    -- Mana Igniting Cord
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 19144, dropRate = 11 },                                                                                                                                                                     -- Sabatons of the Flamewalker
                { id = 18824 },                                                                                                                                                                                    -- Magma Tempered Boots
                { id = 18821 },                                                                                                                                                                                    -- Quick Strike Ring
                { id = 18820 },                                                                                                                                                                                    -- Talisman of Ephemeral Power
                { id = 19142 },                                                                                                                                                                                    -- Fire Runed Grimoire
                { id = 17066, dropRate = 17 },                                                                                                                                                                     -- Drillborer Disk
                { id = 17071, dropRate = 20 },                                                                                                                                                                     -- Gutgore Ripper
                { id = 17105, dropRate = 20 },                                                                                                                                                                     -- Aurastone Hammer
                { id = 18832, dropRate = 20 },                                                                                                                                                                     -- Brutality Blade
                { id = 18822, dropRate = 5 },                                                                                                                                                                      -- Obsidian Edged Blade
                {},
                { id = 20951, dropRate = 1,                                  container = { 18253 } },                                                                                                              -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "BaronGeddon",
            prefix = "5)",
            name = LB["Baron Geddon"],
            defaults = { dropRate = 4 },
            loot = {
                { id = 16797, dropRate = 33,                             container = { { 47079, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Mantle
                { id = 16807, dropRate = 33,                             container = { { 47277, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Shoulder Pads
                { id = 16836, dropRate = 30,                             container = { { 47331, servers = { AtlasCFM.Server.TURTLE1 } }, { 47339, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Spaulders
                { id = 16844, dropRate = 30,                             container = { { 47121, servers = { AtlasCFM.Server.TURTLE1 } }, { 47358, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Spaulders
                { id = 16856, dropRate = 60,                             container = { { 47001, servers = { AtlasCFM.Server.TURTLE1 } }, { 47009, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Spaulders
                { id = 34349, dropRate = 33,                             servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                             -- Burnt Shoulderpads
                { id = 34341, dropRate = 33,                             servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                             -- Charred Spaulders
                { id = 34333, dropRate = 33,                             servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                             -- Melted Pauldrons
                {},
                { id = 18829 },                                                                                                                                                                                    -- Deep Earth Spaulders
                { id = 19143 },                                                                                                                                                                                    -- Flameguard Gauntlets
                { id = 19136 },                                                                                                                                                                                    -- Mana Igniting Cord
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 19144 },                                                                                                                                                                                    -- Sabatons of the Flamewalker
                { id = 18824 },                                                                                                                                                                                    -- Magma Tempered Boots
                { id = 18823, dropRate = 1 },                                                                                                                                                                      -- Aged Core Leather Gloves
                {},
                { id = 18821 },                                                                                                                                                                                    -- Quick Strike Ring
                { id = 17110 },                                                                                                                                                                                    -- Seal of the Archmagus
                { id = 18820 },                                                                                                                                                                                    -- Talisman of Ephemeral Power
                {},
                { id = 19142 },                                                                                                                                                                                    -- Fire Runed Grimoire
                { id = 18822, dropRate = 8 },                                                                                                                                                                      -- Obsidian Edged Blade
                { id = 26060, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                                        -- Everhot Choker
                { id = 26059, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                                        -- Ashes of Destruction
                { id = 18563, dropRate = 6,                              disc = L["Quest Item"] .. ", " .. L["Left Half"],                                                                   container = { 19019 } }, -- Bindings of the Windseeker
                {},
                { id = 20951, dropRate = 1,                              container = { 18253 } },                                                                                                                  -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Shazzrah",
            prefix = "6)",
            name = LB["Shazzrah"],
            defaults = { dropRate = 3 },
            loot = {
                { id = 16811, dropRate = 25,                             container = { { 47205, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Boots of Prophecy
                { id = 16803, dropRate = 25,                             container = { { 47283, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Slippers
                { id = 16824, dropRate = 25,                             servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                         -- Nightslayer Boots
                {},
                { id = 16831, dropRate = 33,                             container = { { 47334, servers = { AtlasCFM.Server.TURTLE1 } }, { 47342, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Gloves
                { id = 16801, dropRate = 33,                             container = { { 47082, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Gloves
                { id = 16852, dropRate = 33,                             servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                         -- Giantstalker's Gloves
                { id = 34352, disc = L["Hands"] .. "/ " .. L["Feet"],    dropRate = 33,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Hot Claws
                { id = 34344, disc = L["Hands"] .. "/ " .. L["Feet"],    dropRate = 33,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Fiery Claws
                { id = 34336, disc = L["Hands"] .. "/ " .. L["Feet"],    dropRate = 33,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Molten Grips
                {},
                { id = 18870 },                                                                                                                                                                                    -- Helm of the Lifegiver
                { id = 19145 },                                                                                                                                                                                    -- Robe of Volatile Power
                { id = 19146 },                                                                                                                                                                                    -- Wristguards of Stability
                { id = 18872 },                                                                                                                                                                                    -- Manastorm Leggings
                { id = 18875 },                                                                                                                                                                                    -- Salamander Scale Pants
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 18879 },                                                                                                                                                                                    -- Heavy Dark Iron Ring
                { id = 19147 },                                                                                                                                                                                    -- Ring of Spell Power
                { id = 26061, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                                        -- Signet of Unlimited Power
                { id = 17077 },                                                                                                                                                                                    -- Crimson Shocker
                { id = 18878 },                                                                                                                                                                                    -- Sorcerous Dagger
                {},
                { id = 20951, dropRate = 1,                              container = { 18253 } },                                                                                                                  -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Golemagg",
            prefix = "7)",
            name = LB["Golemagg the Incinerator"],
            defaults = { dropRate = 2 },
            loot = {
                { id = 16815, dropRate = 25, container = { { 47200, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Robes of Prophecy
                { id = 16798, dropRate = 25, container = { { 47080, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Robes
                { id = 16809, dropRate = 25, container = { { 47278, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Robes
                { id = 16820, dropRate = 25, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                     -- Nightslayer Chestpiece
                { id = 16833, dropRate = 20, container = { { 47332, servers = { AtlasCFM.Server.TURTLE1 } }, { 47340, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Vestments
                { id = 16845, dropRate = 20, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                     -- Giantstalker's Breastplate
                { id = 16841, dropRate = 20, container = { { 47122, servers = { AtlasCFM.Server.TURTLE1 } }, { 47130, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Chestpiece
                { id = 16853, dropRate = 20, container = { { 47002, servers = { AtlasCFM.Server.TURTLE1 } }, { 47010, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Breastplate
                { id = 16865, dropRate = 20, container = { { 47242, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Breastplate of Might
                { id = 34347, dropRate = 33, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                         -- Burnt Leggings
                { id = 34339, dropRate = 33, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                         -- Charred Legguards
                { id = 34331, dropRate = 33, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                         -- Melted Legplates
                {},
                { id = 18829 },                                                                                                                                                                                    -- Deep Earth Spaulders
                { id = 18823 },                                                                                                                                                                                    -- Aged Core Leather Gloves
                { id = 19143 },                                                                                                                                                                                    -- Flameguard Gauntlets
                { id = 19136 },                                                                                                                                                                                    -- Mana Igniting Cord
                { id = 18861 },                                                                                                                                                                                    -- Flamewaker Legplates
                { id = 19144 },                                                                                                                                                                                    -- Sabatons of the Flamewalker
                { id = 18824 },                                                                                                                                                                                    -- Magma Tempered Boots
                { id = 18821 },                                                                                                                                                                                    -- Quick Strike Ring
                { id = 18820 },                                                                                                                                                                                    -- Talisman of Ephemeral Power
                {},
                { id = 19142 },                                                                                                                                                                                    -- Fire Runed Grimoire
                { id = 17072, dropRate = 25 },                                                                                                                                                                     -- Blastershot Launcher
                { id = 17103, dropRate = 25 },                                                                                                                                                                     -- Azuresong Mageblade
                { id = 18822, dropRate = 2 },                                                                                                                                                                      -- Obsidian Edged Blade
                { id = 18842, dropRate = 25 },                                                                                                                                                                     -- Staff of Dominance
                {},
                { id = 17203, dropRate = 80, disc = L["Reagent"],                                                                                                container = { 17182 } },                          -- Sulfuron Ingot
                {},
                { id = 20951, dropRate = 1,  container = { 18253 } },                                                                                                                                              -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Sulfuron",
            prefix = "8)",
            name = LB["Sulfuron Harbinger"],
            defaults = { dropRate = 4 },
            loot = {
                { id = 16816,                                dropRate = 33,                       container = { { 47199, servers = { AtlasCFM.Server.TURTLE1 } } },                                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Mantle of Prophecy
                { id = 16823,                                dropRate = 30,                       servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },              -- Nightslayer Shoulder Pads
                { id = 16848,                                dropRate = 33,                       servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },              -- Giantstalker's Epaulets
                { id = 16868,                                dropRate = 30,                       container = { { 47241, servers = { AtlasCFM.Server.TURTLE1 } } },                                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Pauldrons of Might
                { id = 34352,                                disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33,                                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Hot Claws
                { id = 34344,                                disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33,                                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Fiery Claws
                { id = 34336,                                disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33,                                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Molten Grips
                { servers = { AtlasCFM.Server.VANILLA_PLUS } },
                { id = 34349,                                dropRate = 33,                       servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Burnt Shoulderpads
                { id = 34341,                                dropRate = 33,                       servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Charred Spaulders
                { id = 34333,                                dropRate = 33,                       servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Melted Pauldrons
                { servers = { AtlasCFM.Server.VANILLA_PLUS } },
                { id = 34350,                                disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Burnt Bindings
                { id = 34342,                                disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Charred Bindings
                { id = 34334,                                disc = L["Wrist"] .. "/ " .. L["Waist"], dropRate = 33,                                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Melted Bindings
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                { id = 18870 },                                                                                                                                                    -- Helm of the Lifegiver
                { id = 19145 },                                                                                                                                                    -- Robe of Volatile Power
                { id = 19146 },                                                                                                                                                    -- Wristguards of Stability
                { id = 18872 },                                                                                                                                                    -- Manastorm Leggings
                { id = 18875 },                                                                                                                                                    -- Salamander Scale Pants
                { id = 18861 },                                                                                                                                                    -- Flamewaker Legplates
                {},
                { id = 18879 },                                                                                                                                                    -- Heavy Dark Iron Ring
                { id = 19147 },                                                                                                                                                    -- Ring of Spell Power
                {},
                { id = 17077 },                                                                                                                                                    -- Crimson Shocker
                { id = 18878 },                                                                                                                                                    -- Sorcerous Dagger
                { id = 17074,                                dropRate = 3,                        container = { 17223, { 26099, servers = { AtlasCFM.Server.VANILLA_PLUS } }, { 26100, servers = { AtlasCFM.Server.VANILLA_PLUS } } } }, -- Shadowstrike, Thunderstrike, Magmastrike, Aquastrike
                {},
                { id = 20951,                                dropRate = 1,                        container = { 18253 } },                                                         -- Narain's Scrying Goggles
            }
        },
        {
            id = "Majordomo",
            prefix = "9)",
            name = LB["Majordomo Executus"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 19139 },                                                                                       -- Fireguard Shoulders
                { id = 18810 },                                                                                       -- Wild Growth Spaulders
                { id = 18811 },                                                                                       -- Fireproof Cloak
                { id = 18808 },                                                                                       -- Gloves of the Hypnotic Flame
                { id = 18809 },                                                                                       -- Sash of Whispered Secrets
                { id = 18812 },                                                                                       -- Wristguards of True Flight
                { id = 18806 },                                                                                       -- Core Forged Greaves
                {},
                { id = 19140 },                                                                                       -- Cauterizing Band
                {},
                { id = 18805 },                                                                                       -- Core Hound Tooth
                { id = 18803 },                                                                                       -- Finkle's Lava Dredger
                {},
                { id = 42178, dropRate = 30, disc = L["Used to summon boss"],    servers = { AtlasCFM.Server.TURTLE } }, -- Rite of Resurrection 1.18.1
                { id = 42180, dropRate = 30, disc = L["Used to summon boss"],    servers = { AtlasCFM.Server.TURTLE } }, -- Twisting Rift Crystal 1.18.1
                { id = 18703, dropRate = 50, container = { 18714, 18713, 18715 } },                                   -- Ancient Petrified Leaf
                {},
                { id = 18646, dropRate = 50, container = { 18608, 18609 } },                                          -- The Eye of Divinity
                {},
                { id = 20951, dropRate = 1,  container = { 18253 } },                                                 -- Narain's Scrying Goggles
            }
        },
        {
            id = "Basalthar",
            servers = { AtlasCFM.Server.TURTLE },
            prefix = "10)",
            name = LB["Basalthar"], --65020
            defaults = { dropRate = 11 },
            loot = {
                { id = 58210, dropRate = 17 },                       -- Grasps of Sundering Power
                { id = 58212, dropRate = 17 },                       -- Treads of Scalding Rage
                { id = 58215, dropRate = 17 },                       -- Ash-Forged Greaves
                { id = 58237, dropRate = 17 },                       -- Emberwoven Binding Garments
                { id = 58238, dropRate = 17 },                       -- Runed Wardstone
                { id = 58242, dropRate = 17 },                       -- Sulfuron Aegis
                {},
                { id = 18820 },                                      -- Talisman of Ephemeral Power
                { id = 18821 },                                      -- Quick Strike Ring
                { id = 18822 },                                      -- Obsidian Edged Blade
                { id = 18823 },                                      -- Aged Core Leather Gloves
                { id = 18824 },                                      -- Magma Tempered Boots
                { id = 18829 },                                      -- Deep Earth Spaulders
                { id = 18861 },                                      -- Flamewaker Legplates
                { id = 19136 },                                      -- Mana Igniting Cord
                { id = 19142 },                                      -- Fire Runed Grimoire
                { id = 19143 },                                      -- Flameguard Gauntlets
                { id = 19144 },                                      -- Sabatons of the Flamewalker
                {},
                { id = 20951, dropRate = 1, container = { 18253 } }, -- Narain's Scrying Goggles
            }
        },
        {
            id = "Smoldaris",
            servers = { AtlasCFM.Server.TURTLE },
            name = LB["Smoldaris"], --65021
            defaults = { dropRate = 25 },
            loot = {
                { id = 58211 },                                      -- Molten Emberstone
                { id = 58213 },                                      -- Smoldaris’ Fractured Eye
                { id = 58239 },                                      -- Overheated Skyrazors
                { id = 58241 },                                      -- Totem of Eruption
                {},
                { id = 58246, dropRate = 100 },                      -- Tablet of Molten Blast VI
                {},
                { id = 20951, dropRate = 1,  container = { 18253 } }, -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "SorcererThaneThaurissan",
            servers = { AtlasCFM.Server.TURTLE },
            prefix = "11)",
            name = LB["Sorcerer-Thane Thaurissan"], --57642
            defaults = { dropRate = 11 },
            loot = {
                { id = 58210, dropRate = 17 },                         -- Grasps of Sundering Power
                { id = 58212, dropRate = 17 },                         -- Treads of Scalding Rage
                { id = 58215, dropRate = 17 },                         -- Ash-Forged Greaves
                { id = 58237, dropRate = 17 },                         -- Emberwoven Binding Garments
                { id = 58238, dropRate = 17 },                         -- Runed Wardstone
                { id = 58242, dropRate = 17 },                         -- Sulfuron Aegis
                {},
                { id = 18820 },                                        -- Talisman of Ephemeral Power
                { id = 18821 },                                        -- Quick Strike Ring
                { id = 18822 },                                        -- Obsidian Edged Blade
                { id = 18823 },                                        -- Aged Core Leather Gloves
                { id = 18824 },                                        -- Magma Tempered Boots
                { id = 18829 },                                        -- Deep Earth Spaulders
                { id = 18861 },                                        -- Flamewaker Legplates
                { id = 19136 },                                        -- Mana Igniting Cord
                { id = 19142 },                                        -- Fire Runed Grimoire
                { id = 19143 },                                        -- Flameguard Gauntlets
                { id = 19144 },                                        -- Sabatons of the Flamewalker
                {},
                { id = 58214, dropRate = 25 },                         -- Modrag'zan, Heart of the Mountain
                { id = 58240, dropRate = 25 },                         -- Libram of Final Judgement
                { id = 58243, dropRate = 25 },                         -- Leggings of the Deep Delve
                { id = 58244, dropRate = 25 },                         -- Sigil of Ancient Accord
                {},
                { id = 41989, dropRate = 100, container = { 41990 } }, -- Signet of Thaurissan
                {},
                { id = 20951, dropRate = 1,   container = { 18253 } }, -- Narain's Scrying Goggles
                {},
                unpack(mCShareloot),
            }
        },
        {
            id = "Ragnaros",
            prefix = "12)",
            name = LB["Ragnaros"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16922, dropRate = 13,                                                   container = { { 47212, servers = { AtlasCFM.Server.TURTLE1 } }, { 33014, servers = { AtlasCFM.Server.TURTLE } } },  servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Leggings of Transcendence
                { id = 16915, dropRate = 13,                                                   container = { { 47092, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Pants
                { id = 16930, dropRate = 13,                                                   container = { { 47290, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Pants
                { id = 16909, dropRate = 13,                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                   -- Bloodfang Pants
                { id = 16901, dropRate = 13,                                                   container = { { 47352, servers = { AtlasCFM.Server.TURTLE1 } }, { 47360, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Legguards
                { id = 16938, dropRate = 13,                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                   -- Dragonstalker's Legguards
                { id = 16946, dropRate = 13,                                                   container = { { 47142, servers = { AtlasCFM.Server.TURTLE1 } }, { 47150, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Legplates of Ten Storms
                { id = 16954, dropRate = 13,                                                   container = { { 47022, servers = { AtlasCFM.Server.TURTLE1 } }, { 47030, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Legplates
                { id = 16962, dropRate = 13,                                                   container = { { 47254, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Legplates of Wrath
                { id = 34346, dropRate = 33,                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                       -- Burnt Robe
                { id = 34338, dropRate = 33,                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                       -- Charred Tunic
                { id = 34330, dropRate = 33,                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                       -- Melted Breastplate
                {},
                { id = 18817 },                                                                                                                                                                                    -- Crown of Destruction
                { id = 18814 },                                                                                                                                                                                    -- Choker of the Fire Lord
                { id = 17102 },                                                                                                                                                                                    -- Cloak of the Shrouded Mists
                { id = 17107 },                                                                                                                                                                                    -- Dragon's Blood Cape
                { id = 19137 },                                                                                                                                                                                    -- Onslaught Girdle
                { id = 17063 },                                                                                                                                                                                    -- Band of Accuria
                { id = 18815, dropRate = 8 },                                                                                                                                                                      -- Essence of the Pure Flame
                { id = 17082, dropRate = 8 },                                                                                                                                                                      -- Shard of the Flame
                { id = 17106 },                                                                                                                                                                                    -- Malistar's Defender
                { id = 18816 },                                                                                                                                                                                    -- Perdition's Blade
                { id = 17104, dropRate = 8 },                                                                                                                                                                      -- Spinal Reaper
                { id = 17076, dropRate = 8 },                                                                                                                                                                      -- Bonereaver's Edge
                {},
                { id = 19138, container = { { 58088, servers = { AtlasCFM.Server.TURTLE1 } } } },                                                                                                                  -- Band of Sulfuras
                { id = 17982, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                                        -- Ragnaros Core
                { id = 26105, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                                        -- Claw of Molten Fury
                { id = 26106, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                                                                                                        -- Fist of Molten Fury
                {},
                { id = 17204, dropRate = 6,                                                    disc = L["Reagent"],                                                                                                container = { 17182 } }, -- Eye of Sulfuras
                { id = 19017, dropRate = 100,                                                  container = { 19019 } },                                                                                            -- Essence of the Firelord
                {},
                { id = 70171, dropRate = 100,                                                  container = { 56060 },                                                                                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Crown of Molten Ascension
                { id = 92080, dropRate = 1,                                                    servers = { AtlasCFM.Server.TURTLE1 } },                                                                            -- Molten Corehound
                {},
                { id = 20951, dropRate = 1,                                                    container = { 18253 } },                                                                                            -- Narain's Scrying Goggles
                { id = 42241, dropRate = 100,                                                  container = { 55469 },                                                                                              servers = { AtlasCFM.Server.TURTLE } }, -- Purging Flame 1.18.1
            }
        },
        {
            id = "MCTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["Molten Core"],
            defaults = { dropRate = .3 },
            loot = {
                { id = 16817, container = { { 47203, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Girdle of Prophecy
                { id = 16802, container = { { 47083, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Belt
                { id = 16806, container = { { 47281, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Belt
                { id = 16827, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                     -- Nightslayer Belt
                { id = 16828, container = { { 47335, servers = { AtlasCFM.Server.TURTLE1 } }, { 47343, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Belt
                { id = 16851, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                     -- Giantstalker's Belt
                { id = 16838, container = { { 47125, servers = { AtlasCFM.Server.TURTLE1 } }, { 47133, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Belt
                { id = 16858, container = { { 47005, servers = { AtlasCFM.Server.TURTLE1 } }, { 47013, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Belt
                { id = 16864, container = { { 47245, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Belt of Might
                { id = 17011, disc = L["Reagent"],                                                                                                dropRate = 15 },                                  -- Lava Core
                { id = 17010, disc = L["Reagent"],                                                                                                dropRate = 35 },                                  -- Fiery Core
                { id = 11382, disc = L["Reagent"] .. ", " .. LMD["Molten Destroyer"],                                                             dropRate = 7 },                                   -- Blood of the Mountain
                { id = 17012, disc = L["Reagent"],                                                                                                dropRate = 100 },                                 -- Core Leather
                { id = 70101, dropRate = .56,                                                                                                     container = { 56032 },                         servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Ruby Ring of Ruin
                { id = 20951, dropRate = 1,                                                                                                       container = { 18253 } },                          -- Narain's Scrying Goggles
                { id = 16819, container = { { 47201, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Vambraces of Prophecy
                { id = 16799, container = { { 47081, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Arcanist Bindings
                { id = 16804, container = { { 47279, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Felheart Bracers
                { id = 16825, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                     -- Nightslayer Bracelets
                { id = 16830, container = { { 47333, servers = { AtlasCFM.Server.TURTLE1 } }, { 47341, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cenarion Bracers
                { id = 16850, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                     -- Giantstalker's Bracers
                { id = 16840, container = { { 47123, servers = { AtlasCFM.Server.TURTLE1 } }, { 47131, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Earthfury Bracers
                { id = 16857, container = { { 47003, servers = { AtlasCFM.Server.TURTLE1 } }, { 47011, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lawbringer Bracers
                { id = 16861, container = { { 47243, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Bracers of Might
                { id = 81260, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.TURTLE1 } },          -- Lavashard Axe
                { id = 81261, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.TURTLE1 } },          -- Boots of Blistering Flames
                { id = 81262, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.TURTLE1 } },          -- Core Forged Helmet
                { id = 81263, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.TURTLE1 } },          -- Lost Dark Iron Chain
                { id = 81264, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.TURTLE1 } },          -- Shoulderpads of True Flight
                { id = 81265, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.TURTLE1 } },          -- Ashskin Belt
                { id = 26057, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },     --Flamewaker Hauberk
                { id = 26062, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },     --Narain's Scrying Goggles
                { id = 26063, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },     --Surtr's Belt
                { id = 26064, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },     --Scabrite Axe
                { id = 26065, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },     --Dark Iron Nugget
                { id = 26066, dropRate = .2,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },     --Obsidian Shard

            }
        },
        { name = L["Tier 1 Sets" .. " (V+)"], items = "AtlasCFMLootT1VPSetMenu", servers = { AtlasCFM.Server.VANILLA_PLUS } },
        { name = L["Tier 1 Sets"],            items = "AtlasCFMLootT1SetMenu",   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
        { name = L["Tier 2 Sets"],            items = "AtlasCFMLootT2SetMenu",   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
    },
}

-- Initialize items for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.MoltenCore.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
