---
--- BlackwingLair.lua - Blackwing Lair raid instance loot data
---
--- This module contains comprehensive loot tables and boss data for the Blackwing Lair
--- 40-player raid instance. It includes all boss encounters, tier set items,
--- legendary drops, and unique weapons with their respective drop rates.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Tier 2 set items and tokens
--- • Legendary weapon drops
--- • Unique trinkets and accessories
--- • Attunement requirement tracking
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

AtlasCFM.InstanceData.BlackwingLair = {
    Name = LZ["Blackwing Lair"],
    Location = LZ["Blackrock Spire"],
    Level = 60,
    Acronym = "BWL",
    Attunement = true,
    MaxPlayers = 40,
    DamageType = L["Fire"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] },
    },
    Bosses = {
        {
            id = "Razorgore",
            prefix = "1)",
            name = LB["Razorgore the Untamed"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 34350, disc = L["Wrist"] .. "/ " .. L["Waist"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Burnt Bindings
                { id = 34342, disc = L["Wrist"] .. "/ " .. L["Waist"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Charred Bindings
                { id = 34334, disc = L["Wrist"] .. "/ " .. L["Waist"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Melted Bindings
                { id = 16926, container = { { 47209, servers = { AtlasCFM.Server.TURTLE1 } }, { 33011, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Bindings of Transcendence
                { id = 16918, container = { { 47089, servers = { AtlasCFM.Server.TURTLE1 } } },                                                servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Bindings
                { id = 16934, container = { { 47287, servers = { AtlasCFM.Server.TURTLE1 } } },                                                servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Bracers
                { id = 16911, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                  -- Bloodfang Bracers
                { id = 16904, container = { { 47349, servers = { AtlasCFM.Server.TURTLE1 } }, { 47357, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Bracers
                { id = 16935, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                  -- Dragonstalker's Bracers
                { id = 16943, container = { { 47139, servers = { AtlasCFM.Server.TURTLE1 } }, { 47147, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Bindings of Ten Storms
                { id = 16951, container = { { 47019, servers = { AtlasCFM.Server.TURTLE1 } }, { 47027, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Bracers
                { id = 16959, container = { { 47251, servers = { AtlasCFM.Server.TURTLE1 } } },                                                servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Bracelets of Wrath
                {},
                {},
                {},
                {},
                { id = 19336, dropRate = 20 }, -- Arcane Infused Gem
                { id = 19337, dropRate = 20 }, -- The Black Book
                { id = 19370, dropRate = 20 }, -- Mantle of the Blackwing Cabal
                { id = 19369, dropRate = 20 }, -- Gloves of Rapid Evolution
                {},
                { id = 19335, dropRate = 10 }, -- Spineshatter
                { id = 19334, dropRate = 10 }, -- The Untamed Blade
            }
        },
        {
            id = "ElementiumDecapitatorMKIII",
            prefix = "2)",
            name = LB["Elementium Decapitator MK III"],
            servers = { AtlasCFM.Server.VANILLA_PLUS },
            defaults = { dropRate = 11 },
            loot = {
                { id = 34352, disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33 }, -- Hot Claws
                { id = 34344, disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33 }, -- Fiery Claws
                { id = 34336, disc = L["Hands"] .. "/ " .. L["Feet"], dropRate = 33 }, -- Molten Grips
                {},
                { id = 26212 },                                                    -- Sawtooth Talisman
                { id = 26213 },                                                    -- Hypergear
                { id = 26214 },                                                    -- Technician's X-Ray Spectacles
                { id = 26215 },                                                    -- Gobunix Equilibrium Core
                { id = 26216 },                                                    -- Oilrag Cape
            }
        },
        {
            id = "Vaelastrasz",
            prefix = "2)",
            name = LB["Vaelastrasz the Corrupt"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 34350, disc = L["Wrist"] .. "/ " .. L["Waist"],                                                                        dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Burnt Bindings
                { id = 34342, disc = L["Wrist"] .. "/ " .. L["Waist"],                                                                        dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Charred Bindings
                { id = 34334, disc = L["Wrist"] .. "/ " .. L["Waist"],                                                                        dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Melted Bindings
                { id = 16925, container = { { 47211, servers = { AtlasCFM.Server.TURTLE1 } }, { 33013, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Belt of Transcendence
                { id = 16818, container = { { 47091, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Belt
                { id = 16933, container = { { 47289, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Belt
                { id = 16910, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Bloodfang Belt
                { id = 16903, container = { { 47351, servers = { AtlasCFM.Server.TURTLE1 } }, { 47359, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Belt
                { id = 16936, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Dragonstalker's Belt
                { id = 16944, container = { { 47141, servers = { AtlasCFM.Server.TURTLE1 } }, { 47149, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Sash of Ten Storms
                { id = 16952, container = { { 47021, servers = { AtlasCFM.Server.TURTLE1 } }, { 47029, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Belt
                { id = 16960, container = { { 47253, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Waistband of Wrath
                {},
                {},
                {},
                {},
                { id = 19339, dropRate = 20 }, -- Mind Quickening Gem
                { id = 19340, dropRate = 20 }, -- Rune of Metamorphosis
                { id = 19372, dropRate = 20 }, -- Helm of Endless Rage
                { id = 19371, dropRate = 20 }, -- Pendant of the Fallen Dragon
                {},
                { id = 19348, dropRate = 10 }, -- Red Dragonscale Protector
                { id = 19346, dropRate = 10 }, -- Dragonfang Blade
            }
        },
        {
            id = "Lashlayer",
            prefix = "3)",
            name = LB["Broodlord Lashlayer"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 34352, disc = L["Hands"] .. "/ " .. L["Feet"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Hot Claws
                { id = 34344, disc = L["Hands"] .. "/ " .. L["Feet"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Fiery Claws
                { id = 34336, disc = L["Hands"] .. "/ " .. L["Feet"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Molten Grips
                { id = 16919, container = { { 47213, servers = { AtlasCFM.Server.TURTLE1 } }, { 33015, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Boots of Transcendence
                { id = 16912, container = { { 47093, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Boots
                { id = 16927, container = { { 47291, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Slippers
                { id = 16906, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Bloodfang Boots
                { id = 16898, container = { { 47353, servers = { AtlasCFM.Server.TURTLE1 } }, { 47361, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Boots
                { id = 16941, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Dragonstalker's Greaves
                { id = 16949, container = { { 47143, servers = { AtlasCFM.Server.TURTLE1 } }, { 47151, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Greaves of Ten Storms
                { id = 16957, container = { { 47023, servers = { AtlasCFM.Server.TURTLE1 } }, { 47031, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Boots
                { id = 16965, container = { { 47255, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Sabatons of Wrath
                {},
                { id = 33083, container = { 33093, 33094 },                                                                                   dropRate = 25,                                 servers = { AtlasCFM.Server.TURTLE } }, -- Elementium Sharpening Stone 1.18.1
                {},
                { id = 26108 },                                                                                                                                                                 -- Amir Andilar, Glaive of the Brood Guard
                { id = 26217 },                                                                                                                                                                 -- Lashlayer's Signet
                {},
                { id = 19341, dropRate = 20 },                                                                                                                                                  -- Lifegiving Gem
                { id = 19342, dropRate = 20 },                                                                                                                                                  -- Venomous Totem
                { id = 19373, dropRate = 20 },                                                                                                                                                  -- Black Brood Pauldrons
                { id = 19374, dropRate = 20 },                                                                                                                                                  -- Bracers of Arcane Accuracy
                {},
                { id = 19350, dropRate = 10 },                                                                                                                                                  -- Heartstriker
                { id = 19351, dropRate = 10 },                                                                                                                                                  -- Maladath, Runed Blade of the Black Flight
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                {},
                { id = 20383, dropRate = 100 }, -- Head of the Broodlord Lashlayer
            }
        },
        {
            id = "Firemaw",
            prefix = "4)",
            name = LB["Firemaw"],
            defaults = { dropRate = 7 },
            loot = {
                { id = 34352, disc = L["Hands"] .. "/ " .. L["Feet"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Hot Claws
                { id = 34344, disc = L["Hands"] .. "/ " .. L["Feet"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Fiery Claws
                { id = 34336, disc = L["Hands"] .. "/ " .. L["Feet"],                                                                         dropRate = 33,                                 servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Molten Grips
                { id = 16920, container = { { 47210, servers = { AtlasCFM.Server.TURTLE1 } }, { 33012, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gloves of Transcendence
                { id = 16913, container = { { 47090, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Gloves
                { id = 16928, container = { { 47288, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Gloves
                { id = 16907, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Bloodfang Gloves
                { id = 16899, container = { { 47350, servers = { AtlasCFM.Server.TURTLE1 } }, { 47358, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Gloves
                { id = 16940, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Dragonstalker's Gauntlets
                { id = 16948, container = { { 47140, servers = { AtlasCFM.Server.TURTLE1 } }, { 47148, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Ten Storms
                { id = 16956, container = { { 47020, servers = { AtlasCFM.Server.TURTLE1 } }, { 47028, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Gloves
                { id = 16964, container = { { 47252, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Wrath
                {},
                {},
                {},
                {},
                { id = 19344, dropRate = 13 }, -- Natural Alignment Crystal
                { id = 19343, dropRate = 13 }, -- Scrolls of Blinding Light
                { id = 19394 },                -- Drake Talon Pauldrons
                { id = 19398, dropRate = 13 }, -- Cloak of Firemaw
                { id = 19399, dropRate = 13 }, -- Black Ash Robe
                { id = 19400, dropRate = 13 }, -- Firemaw's Clutch
                { id = 19396, dropRate = 13 }, -- Taut Dragonhide Belt
                { id = 19401, dropRate = 13 }, -- Primalist's Linked Legguards
                { id = 19402, dropRate = 13 }, -- Legguards of the Fallen Crusader
                {},
                { id = 19365, dropRate = 13 }, -- Claw of the Black Drake
                { id = 19353 },                -- Drake Talon Cleaver
                { id = 19355 },                -- Shadow Wing Focus Staff
                {},
                {},
                { id = 19397 }, -- Ring of Blackrock
                { id = 19395 }, -- Rejuvenating Gem
            }
        },
        {
            id = "MasterElementalShaperKrixix",
            prefix = "5)",
            servers = { AtlasCFM.Server.VANILLA_PLUS },
            name = LMD["Master Elemental Shaper Krixix"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 34349, dropRate = 33 }, -- Burnt Shoulderpads
                { id = 34341, dropRate = 33 }, -- Charred Spaulders
                { id = 34333, dropRate = 33 }, -- Melted Pauldrons
                {},
                { id = 26221 },                -- Guide: Elementium Smelting
                { id = 26222 },                -- Elementium Echo Modulator
                { id = 26223 },                -- Reactive Auto-Recaster
                { id = 26224 },                -- Personal Harm Prevention Field Emitter
                { id = 26227 },                -- Auto-Aim Goggles SMark 2
                { id = 26228 },                -- Combat Parser Interface V150r
                { id = 26229 },                -- Orb of Chaotic Elements
                { id = 26230 },                -- Ebony Flame Boots
                { id = 26238 },                -- Idol of Health
                { id = 26240 },                -- Idol of Wilderness
                { id = 26241 },                -- Ring of Master
            }
        },
        {
            id = "EzzelDarkbrewer", -- 1.18.1
            prefix = "5)",
            servers = { AtlasCFM.Server.TURTLE },
            name = LB["Ezzel Darkbrewer"],
            postfix = L["Optional"],
            defaults = { dropRate = 8 },
            loot = {
                { id = 33073 },                                               -- Philosopher's Barrier
                { id = 33074 },                                               -- Taut Dragonhide Boots
                { id = 33075 },                                               -- Staff of Cleansing Vapors
                { id = 33076 },                                               -- Ichorus
                { id = 33077 },                                               -- Apron of Fuming Protection
                { id = 33078 },                                               -- Vials of Volatile Acid
                { id = 33079 },                                               -- Philosopher's Stone Replica
                { id = 33080 },                                               -- Wingbone Vambraces
                { id = 33081 },                                               -- Flask of Petrified Gold
                {},
                { id = 33086 },                                               -- Libram of Hallowed Ground
                { id = 33090 },                                               -- Totem of Distant Tremors
                { id = 33097 },                                               -- Idol of Acidity
                {},
                { id = 33085, container = { 33095 }, dropRate = 25 },         -- Over-Tinkered Lens
                {},
                { id = 42311, dropRate = 100,        container = { 33330, 33331 } }, -- Transmutation Alloy
            }
        },
        {
            id = "Ebonroc",
            prefix = "6)",
            name = LB["Ebonroc"],
            defaults = { dropRate = 7 },
            loot = {
                { id = 34348, dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Burnt Hood
                { id = 34340, dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Charred Headpiece
                { id = 34332, dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Melted Helmet
                { id = 16920, container = { { 47210, servers = { AtlasCFM.Server.TURTLE1 } }, { 33012, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gloves of Transcendence
                { id = 16913, container = { { 47090, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Gloves
                { id = 16928, container = { { 47288, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Gloves
                { id = 16907, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Bloodfang Gloves
                { id = 16899, container = { { 47350, servers = { AtlasCFM.Server.TURTLE1 } }, { 47358, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Gloves
                { id = 16940, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Dragonstalker's Gauntlets
                { id = 16948, container = { { 47140, servers = { AtlasCFM.Server.TURTLE1 } }, { 47148, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Ten Storms
                { id = 16956, container = { { 47020, servers = { AtlasCFM.Server.TURTLE1 } }, { 47028, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Gloves
                { id = 16964, container = { { 47252, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Wrath
                {},
                {},
                {},
                {},
                {},
                { id = 19367, dropRate = 17,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dragon's Touch
                { id = 19345, dropRate = 17 },                                             -- Aegis of Preservation
                { id = 19394 },                                                            -- Drake Talon Pauldrons
                { id = 19407, dropRate = 17 },                                             -- Ebony Flame Gloves
                { id = 19396 },                                                            -- Taut Dragonhide Belt
                { id = 19405, dropRate = 17 },                                             -- Malfurion's Blessed Bulwark
                {},
                { id = 19368, dropRate = 17 },                                             -- Dragonbreath Hand Cannon
                { id = 19353 },                                                            -- Drake Talon Cleaver
                { id = 19355 },                                                            -- Shadow Wing Focus Staff
                {},
                {},
                {},
                { id = 19403, dropRate = 17 }, -- Band of Forced Concentration
                { id = 19397 },                -- Ring of Blackrock
                { id = 19406, dropRate = 17 }, -- Drake Fang Talisman
                { id = 19395 },                -- Rejuvenating Gem
            }
        },
        {
            id = "Flamegor",
            prefix = "7)",
            name = LB["Flamegor"],
            defaults = { dropRate = 7 },
            loot = {
                { id = 34348, dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Burnt Hood
                { id = 34340, dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Charred Headpiece
                { id = 34332, dropRate = 33,                                                                                                  servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Melted Helmet
                { id = 16920, container = { { 47210, servers = { AtlasCFM.Server.TURTLE1 } }, { 33012, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gloves of Transcendence
                { id = 16913, container = { { 47090, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Gloves
                { id = 16928, container = { { 47288, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Gloves
                { id = 16907, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Bloodfang Gloves
                { id = 16899, container = { { 47350, servers = { AtlasCFM.Server.TURTLE1 } }, { 47358, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Gloves
                { id = 16940, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                 -- Dragonstalker's Gauntlets
                { id = 16948, container = { { 47140, servers = { AtlasCFM.Server.TURTLE1 } }, { 47148, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Ten Storms
                { id = 16956, container = { { 47020, servers = { AtlasCFM.Server.TURTLE1 } }, { 47028, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Gloves
                { id = 16964, container = { { 47252, servers = { AtlasCFM.Server.TURTLE1 } } },                                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Wrath
                {},
                {},
                {},
                {},
                {},
                {},
                { id = 19394 },                -- Drake Talon Pauldrons
                { id = 19430, dropRate = 17 }, -- Shroud of Pure Thought
                { id = 19396 },                -- Taut Dragonhide Belt
                { id = 19433, dropRate = 17 }, -- Emberweave Leggings
                {},
                { id = 19367, dropRate = 17 }, -- Dragon's Touch
                { id = 19353 },                -- Drake Talon Cleaver
                { id = 19357, dropRate = 17 }, -- Herald of Woe
                { id = 19355 },                -- Shadow Wing Focus Staff
                {},
                {},
                { id = 19432, dropRate = 17 }, -- Circle of Applied Force
                { id = 19397 },                -- Ring of Blackrock
                { id = 19395 },                -- Rejuvenating Gem
                { id = 19431, dropRate = 17 }, -- Styleen's Impeding Scarab
            }
        },
        {
            id = "Chromaggus",
            prefix = "8)",
            name = LB["Chromaggus"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 34347, dropRate = 33,                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Burnt Leggings
                { id = 34339, dropRate = 33,                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Charred Legguards
                { id = 34331, dropRate = 33,                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Melted Legplates
                { id = 16924, container = { { 47207, servers = { AtlasCFM.Server.TURTLE1 } }, { 33009, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Pauldrons of Transcendence
                { id = 16917, container = { { 47087, servers = { AtlasCFM.Server.TURTLE1 } } },                                                servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Netherwind Mantle
                { id = 16932, container = { { 47285, servers = { AtlasCFM.Server.TURTLE1 } } },                                                servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Nemesis Spaulders
                { id = 16832, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                  -- Bloodfang Spaulders
                { id = 16902, container = { { 47347, servers = { AtlasCFM.Server.TURTLE1 } }, { 47355, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Stormrage Pauldrons
                { id = 16937, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                  -- Dragonstalker's Spaulders
                { id = 16945, container = { { 47137, servers = { AtlasCFM.Server.TURTLE1 } }, { 47145, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Epaulets of Ten Storms
                { id = 16953, container = { { 47017, servers = { AtlasCFM.Server.TURTLE1 } }, { 47025, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Judgement Spaulders
                { id = 16961, container = { { 47249, servers = { AtlasCFM.Server.TURTLE1 } } },                                                servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Pauldrons of Wrath
                {},
                { id = 26218, dropRate = 10,                                                                                                   servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Chronomirage
                { id = 33084, container = { 33096 },                                                                                           dropRate = 25,                                 servers = { AtlasCFM.Server.TURTLE } }, -- Pristine Chromatic Scale
                {},
                {},
                {},
                {},
                { id = 19389, dropRate = 16 }, -- Taut Dragonhide Shoulderpads
                { id = 19386, dropRate = 16 }, -- Elementium Threaded Cloak
                { id = 19390, dropRate = 16 }, -- Taut Dragonhide Gloves
                { id = 19388, dropRate = 20 }, -- Angelista's Grasp
                { id = 19393, dropRate = 16 }, -- Primalist's Linked Waistguard
                { id = 19392, dropRate = 16 }, -- Girdle of the Fallen Crusader
                { id = 19385, dropRate = 20 }, -- Empowered Leggings
                { id = 19391, dropRate = 16 }, -- Shimmering Geta
                { id = 19387, dropRate = 20 }, -- Chromatic Boots
                {},
                {},
                { id = 19361, dropRate = 10 }, -- Ashjre'thul, Crossbow of Smiting
                { id = 19349, dropRate = 10 }, -- Elementium Reinforced Bulwark
                { id = 19347, dropRate = 10 }, -- Claw of Chromaggus
                { id = 19352, dropRate = 10 }, -- Chromatically Tempered Sword
            }
        },
        {
            id = "Nefarian",
            prefix = "9)",
            name = LB["Nefarian"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 34346, dropRate = 33,                                                                                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                         -- Burnt Robe
                { id = 34338, dropRate = 33,                                                                                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                         -- Charred Tunic
                { id = 34330, dropRate = 33,                                                                                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                         -- Melted Breastplate
                { id = 16923, container = { { 47208, servers = { AtlasCFM.Server.TURTLE1 } }, { 33010, servers = { AtlasCFM.Server.TURTLE } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                    -- Robes of Transcendence
                { id = 16916, container = { { 47088, servers = { AtlasCFM.Server.TURTLE1 } } },                                                 servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                     -- Netherwind Robes
                { id = 16931, container = { { 47286, servers = { AtlasCFM.Server.TURTLE1 } } },                                                 servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                     -- Nemesis Robes
                { id = 16905, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                                                       -- Bloodfang Chestpiece
                { id = 16897, container = { { 47348, servers = { AtlasCFM.Server.TURTLE1 } }, { 47356, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Stormrage Chestguard
                { id = 16942, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                                                       -- Dragonstalker's Breastplate
                { id = 16950, container = { { 47138, servers = { AtlasCFM.Server.TURTLE1 } }, { 47146, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Raiments of Ten Storms
                { id = 16958, container = { { 47018, servers = { AtlasCFM.Server.TURTLE1 } }, { 47026, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Judgement Breastplate
                { id = 16966, container = { { 47250, servers = { AtlasCFM.Server.TURTLE1 } } },                                                 servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                     -- Breastplate of Wrath
                {},
                { id = 19003, dropRate = 100,                                                                                                   container = { 19383, 19384, 19366 } },                                                -- Head of Nefarian (Alliance)
                { id = 19002, dropRate = 100,                                                                                                   container = { 19383, 19384, 19366 } },                                                -- Head of Nefarian (Horde)
                {},
                { id = 36551, dropRate = 1,                                                                                                     servers = { AtlasCFM.Server.TURTLE1 } },                                              -- Black Drake
                { id = 19360, dropRate = 10 },                                                                                                                                                                                        -- Lok'amir il Romathis
                { id = 19363, dropRate = 10 },                                                                                                                                                                                        -- Crul'shorukh, Edge of Chaos
                { id = 19364, dropRate = 10 },                                                                                                                                                                                        -- Ashkandi, Greatsword of the Brotherhood
                { id = 19356, dropRate = 10 },                                                                                                                                                                                        -- Staff of the Shadow Flame
                {},
                { id = 19375, dropRate = 20 },                                                                                                                                                                                        -- Mish'undare, Circlet of the Mind Flayer
                { id = 19377, dropRate = 20 },                                                                                                                                                                                        -- Prestor's Talisman of Connivery
                { id = 19378, dropRate = 20 },                                                                                                                                                                                        -- Cloak of the Brood Lord
                { id = 19380, dropRate = 20 },                                                                                                                                                                                        -- Therazane's Link
                { id = 19381, dropRate = 20 },                                                                                                                                                                                        -- Boots of the Shadow Flame
                {},
                { id = 19376, dropRate = 20 },                                                                                                                                                                                        -- Archimtiros' Ring of Reckoning
                { id = 19382, dropRate = 20 },                                                                                                                                                                                        -- Pure Elementium Band
                { id = 19379, dropRate = 20 },                                                                                                                                                                                        -- Neltharion's Tear
                {},
                { id = 61760, dropRate = 100,                                                                                                   container = { 55505 },                         servers = { AtlasCFM.Server.TURTLE1 } }, -- Burnt Copy of "Vorgendor"
                {},
                { id = 17962, disc = L["Container"],                                                                                            dropRate = 20,                                 container = { 13926, 7971, 3864, 55251, 55250, 7910, 7909, 1529, 12361 },                                                                                      servers = { AtlasCFM.Server.TURTLE1 } }, -- Blue Sack of Gems
                { id = 17963, disc = L["Container"],                                                                                            dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12364 } }, -- Green Sack of Gems
                { id = 17964, disc = L["Container"],                                                                                            dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12800 } }, -- Gray Sack of Gems
                { id = 17965, disc = L["Container"],                                                                                            dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12363 } }, -- Yellow Sack of Gems
                { id = 17969, disc = L["Container"],                                                                                            dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12799 } }, -- Red Sack of Gems
            }
        },
        { prefix = "1)", name = LMD["Alchemy Lab"],                    color = Colors.GREEN },
        { prefix = "2)", name = LMD["Draconic for Dummies"],           color = Colors.GREEN },
        { prefix = "3'", name = LMD["Master Elemental Shaper Krixix"], color = Colors.GREEN, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
        {
            id = "BWLTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["Blackwing Lair"],
            defaults = { dropRate = 4 },
            loot = {
                { id = 19436 },                                                                             -- Cloak of Draconic Might
                { id = 19439, dropRate = 5 },                                                               -- Interlaced Shadow Jerkin
                { id = 19437 },                                                                             -- Boots of Pure Thought
                { id = 19438, dropRate = 5 },                                                               -- Ringo's Blizzard Boots
                {},
                { id = 19434, dropRate = 2 },                                                               -- Band of Dark Dominion
                {},
                { id = 19435, dropRate = 2 },                                                               -- Essence Gatherer
                { id = 19362, dropRate = 2 },                                                               -- Doom's Edge
                { id = 19354, dropRate = 5 },                                                               -- Draconic Avenger
                { id = 19358 },                                                                             -- Draconic Maul
                {},
                { id = 18562, disc = L["Trade Goods"], dropRate = 8 },                                      -- Elementium Ore
                { id = 19183, quantity = { 1, 2 },     disc = L["Consumable"], dropRate = 47 },             -- Hourglass Sand
                { id = 70173, dropRate = 2,            container = { 56062 },  servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Blackwing Signet of Command
            }
        },
        { name = L["Tier 2 Sets"],            items = "AtlasCFMLootT2SetMenu",   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
        { name = L["Tier 1 Sets" .. " (V+)"], items = "AtlasCFMLootT1VPSetMenu", servers = { AtlasCFM.Server.VANILLA_PLUS } },
    }
}

AtlasCFM.InstanceData.BlackrockMountainEnt = {
    Name = LZ["Blackrock Mountain"] .. " (" .. L["Entrance"] .. ")",
    Location = LZ["Blackrock Mountain"],
    Entrances = {
        { letter = "A) " .. LZ["Searing Gorge"] },
        { letter = "B) " .. LZ["Burning Steppes"] },
        { letter = "C) " .. LZ["Blackrock Depths"] .. " (BRD)" },
        { letter = "D) " .. LZ["Lower Blackrock Spire"] .. " (LBRS)" }
    },
    Bosses = {
        {
            name = LZ["Molten Core"] .. " (MC) (" .. L["through "] .. "BRD)",
            color = Colors.BLUE
        },
        {
            name = LZ["Upper Blackrock Spire"] .. " (UBRS)",
            color = Colors.BLUE
        },
        {
            name = LZ["Blackwing Lair"] .. " (BWL) (" .. L["through "] .. "UBRS)",
            color = Colors.BLUE
        },
        {
            name = LMD["Bodley"] .. " (" .. L["Ghost"] .. ")",
            color = Colors.BLUE
        },
        {
            id = "BRDPyron",
            prefix = "1)",
            name = LB["Overmaster Pyron"],
            postfix = L["Wanders"],
            loot = {
                { id = 14486, dropRate = 18, container = { 14134 } },               -- Pattern: Cloak of Fire
                {},
                { id = 11446, dropRate = 25, container = { 12061, 12062, 12065 } }, -- A Crumpled Up Note
            }
        },
        {
            prefix = "2)",
            name = LB["Lothos Riftwaker"],
            postfix = "MC " .. L["Teleport"],
            color = Colors.GREY,
        },
        {
            prefix = "3)",
            name = LB["Franclorn Forgewright"],
            postfix = L["Ghost"],
            color = Colors.GREY,
        },
        {
            prefix = "4)",
            name = L["Meeting Stone"] .. " (BRD)",
            color = Colors.GREY,
        },
        {
            prefix = "5)",
            name = LMD["Orb of Command"] .. " (BWL " .. L["Teleport"] .. ")",
            color = Colors.GREY,
        },
        {
            prefix = "6)",
            name = L["Meeting Stone"] .. " (LBRS, UBRS)",
            color = Colors.GREY,
        },
        {
            id = "BRMScarshieldQuartermaster",
            prefix = "7)",
            name = LB["Scarshield Quartermaster"],
            postfix = L["Rare"],
            loot = {
                { id = 13254, dropRate = 3 },                                          -- Astral Guard
                { id = 13248, dropRate = 3 },                                          -- Burstshot Harquebus
                {},
                { id = 18987, dropRate = 100, servers = { AtlasCFM.Server.TURTLE1 } }, -- Blackhand's Command
            }
        },
        {
            id = "BRMBehemoth",
            prefix = "8)",
            name = LB["The Behemoth"],
            postfix = L["Rare"],
            loot = {
                { id = 11603, dropRate = 99 },                                      -- Vilerend Slicer
                {},
                { id = 11446, dropRate = 25, container = { 12061, 12062, 12065 } }, -- A Crumpled Up Note
            }
        }
    }
}

for _, bossData in ipairs(AtlasCFM.InstanceData.BlackwingLair.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil
end

for _, bossData in ipairs(AtlasCFM.InstanceData.BlackrockMountainEnt.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil
end
