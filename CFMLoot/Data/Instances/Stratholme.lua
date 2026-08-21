---
--- Stratholme.lua - Stratholme dungeon instance loot data
---
--- This module contains comprehensive loot tables and boss data for the Stratholme
--- 5-player dungeon instance. It includes both Living and Undead sides with
--- all boss encounters, rare drops, and dungeon set items.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Dungeon set items (Tier 0.5)
--- • Rare and epic weapon drops
--- • Side-specific loot organization
--- • Key and attunement items
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses
local LF = AtlasCFM.Localization.Factions
local LS = AtlasCFM.Localization.Spells
local LIS = AtlasCFM.Localization.ItemSets
local LMD = AtlasCFM.Localization.MapData

local Colors = AtlasCFM.Colors

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

AtlasCFM.InstanceData.Stratholme = {
    Name = LZ["Stratholme"],
    Location = LZ["Eastern Plaguelands"],
    Level = { 45, 60 },
    Acronym = "Strat",
    MaxPlayers = 10,
    DamageType = L["Physical"],
    Entrances = {
        { letter = "A) " .. LMD["Front"] },
        { letter = "B) " .. L["Side"] }
    },
    Reputation = {
        { name = LF["Argent Dawn"], loot = "ArgentDawn" }
    },
    Keys = {
        { name = LMD["The Scarlet Key"],       loot = "VanillaKeys", info = LMD["Living Side"] },
        { name = LMD["Key to the City"],       loot = "VanillaKeys", info = LMD["Undead Side"] },
        { name = LMD["Brazier of Invocation"], loot = "VanillaKeys", info = LMD["Tier 0.5 Summon"] },
    },
    Bosses = {
        {
            id = "STRATSkull",
            prefix = "1)",
            name = LB["Skul"],
            postfix = L["Rare"] .. ", " .. L["Varies"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 13394 },                                                                              -- Skul's Cold Embrace
                { id = 13395 },                                                                              -- Skul's Fingerbone Claws
                {},
                { id = 13396 },                                                                              -- Skul's Ghastly Touch
                {},
                { id = 41985, dropRate = 100,         container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"], dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
            }
        },
        {
            id = "STRATStratholmeCourier",
            name = LB["Stratholme Courier"],
            defaults = { dropRate = 50 },
            loot = {
                { id = 13302 }, -- Market Row Postbox Key
                { id = 13303 }, -- Crusaders' Square Postbox Key
                { id = 13304 }, -- Festival Lane Postbox Key
                { id = 13305 }, -- Elders' Square Postbox Key
                { id = 13306 }, -- King's Square Postbox Key
                { id = 13307 }, -- Fras Siabi's Postbox Key
            }
        },
        {
            id = "STRATFrasSiabi",
            name = LMD["Fras Siabi"],
            loot = {
                { id = 13171, dropRate = 100 },                                                                  -- Smokey's Lighter
                {},
                { id = 50021, disc = L["Reagent"], dropRate = 100, servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dragonbreath
            }
        },
        {
            id = "STRATAtiesh",
            prefix = "2)",
            name = LB["Rethilgore"],
            postfix = L["Summon"],
            loot = {
                { id = 22736, dropRate = 100 }, -- Andonisus, Reaper of Souls
            }
        },
        {
            id = "STRATBalzaphon",
            name = LB["Balzaphon"],
            postfix = L["Scourge Invasion"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 23125 }, -- Chains of the Lich
                { id = 23126 }, -- Waistband of Balzaphon
                {},
                { id = 23124 }, -- Staff of Balzaphon
            }
        },
        {
            id = "STRATHearthsingerForresten",
            prefix = "3)",
            name = LB["Hearthsinger Forresten"],
            postfix = L["Rare"] .. ", " .. L["Varies"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16682, disc = L["Mage"] .. ", T0",                container = { 22064 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Magister's Boots
                {},
                { id = 13378 },                                                                                                  -- Songbird Blouse
                { id = 13384 },                                                                                                  -- Rainbow Girdle
                { id = 13383 },                                                                                                  -- Woollies of the Prancing Minstrel
                { id = 13379 },                                                                                                  -- Piccolo of the Flaming Fire
                {},
                { id = 41985, dropRate = 100,                            container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 13174, quantity = { 1, 3 },                       dropRate = 80,         container = { 13209, 19812 } },  -- Plagued Flesh Sample
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 26031, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                      -- Lucky Irontree Leaf
            }
        },
        {
            id = "STRATTheUnforgiven",
            prefix = "4)",
            name = LB["The Unforgiven"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16717, disc = L["Druid"] .. ", T0",               container = { 22110 },       servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Wildheart Gloves
                {},
                { id = 13404 },                                                                                                   -- Mask of the Unforgiven
                { id = 13405 },                                                                                                   -- Wailing Nightbane Pauldrons
                { id = 13409 },                                                                                                   -- Tearfall Bracers
                {},
                { id = 13408 },                                                                                                   -- Soul Breaker
                {},
                { id = 41985, dropRate = 100,                            container = { 41986 },       servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 13174, dropRate = 80,                             container = { 13209, 19812 } },                          -- Plagued Flesh Sample
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,                servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"],            dropRate = 5,                servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26038, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                       -- Elusive Drape
            }
        },
        {
            prefix = "5)",
            name = LMD["Elder Farwhisper"],
            postfix = L["Lunar Festival"],
            items = "LunarFestival",
        },
        {
            id = "STRATTimmytheCruel",
            prefix = "6)",
            name = LB["Timmy the Cruel"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16724, disc = L["Paladin"] .. ", T0",             container = { 22090 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lightforge Gauntlets
                {},
                { id = 13400 },                                                                                                     -- Vambraces of the Sadist
                { id = 13403 },                                                                                                     -- Grimgore Noose
                { id = 13402 },                                                                                                     -- Timmy's Galoshes
                { id = 13401 },                                                                                                     -- The Cruel Hand of Timmy
                {},
                { id = 61791, dropRate = .25,                            container = { 61784 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                {},
                { id = 41985, dropRate = 100,                            container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 13174, quantity = { 2, 4 },                       dropRate = 80,         container = { 13209, 19812 } },     -- Plagued Flesh Sample
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"],            dropRate = 5,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26047, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                         -- Hangman's Noose
            }
        },
        {
            id = "STRATMalor",
            prefix = "7)",
            servers = { AtlasCFM.Server.TURTLE1 },
            name = LB["Malor the Zealous"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 81016 },                                                                              -- Bleeding Heart Talisman
                { id = 81017 },                                                                              -- Girdle of Fading Hope
                { id = 81019 },                                                                              -- Gauntlets of Myrmidon
                { id = 81122 },                                                                              -- Bloodfallen Cloak
                { id = 81123 },                                                                              -- Crimson Defender's Leggings
                { id = 81124 },                                                                              -- Helmet of the Scarlet Avenger
                { id = 81131 },                                                                              -- Helmet of the Scarlet Avenger
                {},
                { id = 81018 },                                                                              -- Crimson Spellblade
                { id = 81125 },                                                                              -- Inquisitor's Orb
                {},
                { id = 83575, disc = L["Book"],               dropRate = 10 },                               -- Codex of Smite IX
                {},
                { id = 61791, dropRate = .25,                 container = { 61784 } },                       -- Plans: Arcanite Belt Buckle
                {},
                { id = 41985, dropRate = 100,                 container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],         dropRate = 1 },                                -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5 },                                -- Fashion Coin
            }
        },
        {
            id = "STRATMalorsStrongbox",
            name = LMD["Malor's Strongbox"],
            loot = {
                { id = 12845, disc = L["Quest Item"], dropRate = 100, container = { 17044, 17045 } }, -- Medallion of Faith
            }
        },
        {
            id = "STRATCrimsonHammersmith",
            prefix = "8)",
            name = LMD["Crimson Hammersmith"],
            postfix = L["Summon"],
            loot = {
                { id = 18781, dropRate = 40,  container = { 18770, 12726, 12619 } },                   -- Bottom Half of Advanced Armorsmithing: Volume II
                {},
                { id = 13351, dropRate = 100, container = { 12824, 12776 } },                          -- Crimson Hammersmith's Apron
                {},
                { id = 124,   dropRate = 6,   container = { 87 },                 servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Enchanted Thorium Belt Buckle
            }
        },
        {
            id = "STRATBSPlansSerenity",
            name = LMD["Blacksmithing Plans"] .. "  ",
            loot = {
                { id = 12827, dropRate = 32, container = { 12781 } }, -- Plans: Serenity
            }
        },
        {
            id = "STRATCannonMasterWilley",
            prefix = "9)",
            name = LB["Cannon Master Willey"],
            defaults = { dropRate = 10 },
            loot = {
                { id = 16708, disc = L["Rogue"] .. ", T0",               container = { 22008 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Shadowcraft Spaulders
                {},
                { id = 22407 },                                                                                                   -- Helm of the New Moon
                { id = 22403 },                                                                                                   -- Diana's Pearl Necklace
                { id = 22405 },                                                                                                   -- Mantle of the Scarlet Crusade
                { id = 18721 },                                                                                                   -- Barrage Girdle
                { id = 13381 },                                                                                                   -- Master Cannoneer Boots
                { id = 13382 },                                                                                                   -- Cannonball Runner
                {},
                { id = 13380 },                                                                                                   -- Willey's Portable Howitzer
                { id = 22404 },                                                                                                   -- Willey's Back Scratcher
                { id = 22406 },                                                                                                   -- Redemption
                {},
                { id = 13377, dropRate = 100 },                                                                                   -- Miniature Cannon Balls
                {},
                { id = 12839, dropRate = 6,                              container = { 12783 } },                                 -- Plans: Heartseeker
                { id = 26034, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                       -- Barrage Ring
                { id = 61791, dropRate = .25,                            container = { 61784 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                {},
                { id = 41985, quantity = 2,                              dropRate = 100,        container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"],            dropRate = 5,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 50021, disc = L["Reagent"],                       dropRate = 100,        servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dragonbreath
            }
        },
        {
            id = "STRATArchivistGalford",
            prefix = "10)",
            name = LB["Archivist Galford"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16692, disc = L["Priest"] .. ", T0",              container = { 22081 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Devout Gloves
                {},
                { id = 13386 },                                                                                                    -- Archivist Cape
                { id = 13387 },                                                                                                    -- Foresight Girdle
                { id = 18716 },                                                                                                    -- Ash Covered Boots
                { id = 13385 },                                                                                                    -- Tome of Knowledge
                {},
                { id = 12811, disc = L["Trade Goods"],                   dropRate = 18 },                                          -- Righteous Orb
                {},
                { id = 22897, disc = L["Book"],                          dropRate = 14 },                                          -- Tome of Conjure Food VII
                { id = 61791, dropRate = .25,                            container = { 61784 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                {},
                { id = 41985, dropRate = 100,                            container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"],            dropRate = 5,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26027, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                        -- Ladybird of Luck
            }
        },
        {
            id = "STRATDathrohan",
            prefix = "11)",
            name = LMD["Grand Crusader Dathrohan"],
            color = Colors.GREY,
        },
        {
            id = "STRATBalnazzar",
            name = LB["Balnazzar"],
            defaults = { dropRate = 10 },
            loot = {
                { id = 16725,                                    disc = L["Paladin"] .. ", T0",  container = { 22087 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lightforge Boots
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 13359 },                                                                                                     -- Crown of Tyranny
                { id = 18718 },                                                                                                     -- Grand Crusader's Helm
                { id = 12103 },                                                                                                     -- Star of Mystaria
                { id = 18720 },                                                                                                     -- Shroud of the Nathrezim
                { id = 13358 },                                                                                                     -- Wyrmtongue Shoulders
                { id = 13369 },                                                                                                     -- Fire Striders
                {},
                { id = 13348 },                                                                                                     -- Demonshear
                { id = 18717 },                                                                                                     -- Hammer of the Grand Crusader
                { id = 13360 },                                                                                                     -- Gift of the Elven Magi
                {},
                {},
                { id = 13353,                                    dropRate = 1.37 },                                                                                                                       -- Book of the Dead
                { id = 83501,                                    dropRate = 17,                  container = { 60288 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Rune-Etched Greaves
                { id = 83502,                                    dropRate = 17,                  container = { 60289 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Rune-Etched Legplates
                { id = 83503,                                    dropRate = 17,                  container = { 60290 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Rune-Etched Breastplate
                { id = 83504,                                    dropRate = 17,                  container = { 60291 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Rune-Etched Crown
                { id = 83505,                                    dropRate = 17,                  container = { 60292 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Rune-Etched Mantle
                { id = 83506,                                    dropRate = 17,                  container = { 60287 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Rune-Etched Grips
                { id = 83500,                                    dropRate = 5,                   container = { 60293 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Untempered Runeblade
                { id = 14512,                                    dropRate = 6,                   container = { 14154 } },                                                                                 -- Pattern: Truefaith Vestments
                { id = 13520,                                    dropRate = 3,                   container = { 13511 } },                                                                                 -- Recipe: Flask of Distilled Wisdom
                { id = 61791,                                    dropRate = .25,                 container = { 61784 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Plans: Arcanite Belt Buckle
                { id = 13250 },                                                                                                                                                                           -- Head of Balnazzar
                {},
                { id = 26048,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                            -- Wings of Malevolence
                { id = 47413,                                    dropRate = 10,                  container = { 47412 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Recipe: Concoction of the Arcane Giant
                { id = 47415,                                    dropRate = 10,                  container = { 47414 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Recipe: Concoction of the Dreamwater
                { id = 70226,                                    disc = L["Quest Item"],         dropRate = 3,                              container = { 70227, 70228, 70229, 70230, 70231, 70232, 70233, 70234, 70235, 70236, 70238 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 41985,                                    quantity = 3,                   dropRate = 100,                            container = { 41986 },                                                                       servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 41700,                                    dropRate = 100,                 container = { 41704 },                     servers = { AtlasCFM.Server.TURTLE1 } },                      -- Lunar Token
                { id = 51217,                                    disc = L["Transmogrification"], dropRate = 100,                            servers = { AtlasCFM.Server.TURTLE1 } },                      -- Fashion Coin
                {},
                { id = 50021,                                    disc = L["Reagent"],            dropRate = 100,                            servers = { AtlasCFM.Server.VANILLA_PLUS } },                 -- Dragonbreath
            }
        },
        {
            id = "STRATSothosJarien",
            name = LB["Sothos"] .. " & " .. LB["Jarien"],
            postfix = L["Summon"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 22327 }, -- Amulet of the Redeemed
                { id = 22301 }, -- Ironweave Robe
                { id = 22328 }, -- Legplates of Vigilance
                {},
                { id = 22334 }, -- Band of Mending
                {},
                { id = 22329 }, -- Scepter of Interminable Focus
            }
        },
        {
            id = "STRATMagistrateBarthilas",
            prefix = "12)",
            name = LB["Magistrate Barthilas"],
            postfix = L["Varies"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 18727 },                                                                                      -- Crimson Felt Hat
                { id = 13376 },                                                                                      -- Royal Tribunal Cloak
                { id = 18726 },                                                                                      -- Magistrate's Cuffs
                { id = 18722 },                                                                                      -- Death Grips
                {},
                { id = 23198 },                                                                                      -- Idol of Brutality
                {},
                { id = 18725 },                                                                                      -- Peacemaker
                {},
                { id = 12382, disc = L["Key"],                dropRate = 100 },                                      -- Key to the City
                {},
                { id = 41985, dropRate = 100,                 container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 13174, quantity = { 2, 4 },            dropRate = 80,         container = { 13209, 19812 } }, -- Plagued Flesh Sample
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            prefix = "13)",
            name = LMD["Aurius"],
            color = Colors.GREY,
        },
        {
            id = "STRATStonespine",
            prefix = "14)",
            name = LB["Stonespine"],
            postfix = L["Rare"] .. ", " .. L["Wanders"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 13397 },                                                                              -- Stoneskin Gargoyle Cape
                { id = 13954 },                                                                              -- Verdant Footpads
                {},
                { id = 13399 },                                                                              -- Gargoyle Shredder Talons
                {},
                { id = 41985, dropRate = 100,         container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"], dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
            }
        },
        {
            id = "STRATBaronessAnastari",
            prefix = "15)",
            name = LB["Baroness Anastari"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16704, disc = L["Warlock"] .. ", T0",  container = { 22076 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Dreadmist Sandals
                {},
                { id = 18728 },                                                                                                     -- Anastari Heirloom
                { id = 18730 },                                                                                                     -- Shadowy Laced Handwraps
                { id = 18729 },                                                                                                     -- Screeching Bow
                { id = 13534 },                                                                                                     -- Banshee Finger
                {},
                { id = 13538 },                                                                                                     -- Windshrieker Pauldrons
                { id = 13535 },                                                                                                     -- Coldtouch Phantom Wraps
                { id = 13537 },                                                                                                     -- Chillhide Bracers
                { id = 13539 },                                                                                                     -- Banshee's Touch
                { id = 13514 },                                                                                                     -- Wail of the Banshee
                {},
                { id = 61791, dropRate = .25,                 container = { 61784 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                {},
                { id = 41985, dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 13174, quantity = { 1, 3 },            dropRate = 80,                             container = { 13209, 19812 } }, -- Plagued Flesh Sample
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26033, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                         -- Horror Ring
            }
        },
        {
            id = "STRATBlackGuardSwordsmith",
            name = LMD["Black Guard Swordsmith"],
            postfix = L["Summon"],
            loot = {
                { id = 18783, disc = L["Quest Item"], dropRate = 40,               container = { 18771, 12725, 12620 } }, -- Bottom Half of Advanced Armorsmithing: Volume III
                {},
                { id = 13350, dropRate = 100,         container = { 12825, 12777 } },                       -- Insignia of the Black Guard
            }
        },
        {
            id = "STRATBSPlansCorruption",
            name = LMD["Blacksmithing Plans"],
            loot = {
                { id = 12830, dropRate = .02, container = { 12782 } }, -- Plans: Corruption
            }
        },
        {
            id = "STRATNerubenkan",
            prefix = "16)",
            name = LB["Nerub'enkan"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16675, disc = L["Hunter"] .. ", T0",   container = { 22061 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Boots
                {},
                { id = 18740 },                                                                                                    -- Thuzadin Sash
                { id = 18739 },                                                                                                    -- Chitinous Plate Legguards
                {},
                { id = 18738 },                                                                                                    -- Carapace Spine Crossbow
                { id = 13529 },                                                                                                    -- Husk of Nerub'enkan
                {},
                { id = 13533 },                                                                                                    -- Acid-etched Pauldrons
                { id = 13532 },                                                                                                    -- Darkspinner Claws
                { id = 13531 },                                                                                                    -- Crypt Stalker Leggings
                { id = 13530 },                                                                                                    -- Fangdrip Runners
                { id = 13508 },                                                                                                    -- Eye of Arachnida
                {},
                { id = 61791, dropRate = .25,                 container = { 61784 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                { id = 41985, dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 13174, quantity = { 2, 4 },            dropRate = 80,                             container = { 13209, 19812 } }, -- Plagued Flesh Sample
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text

                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26042, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Chitinous Husk Coif
            }
        },
        {
            id = "STRATMalekithePallid",
            prefix = "17)",
            name = LB["Maleki the Pallid"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16691, disc = L["Priest"] .. ", T0",   container = { 22084 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Devout Sandals
                {},
                { id = 18734 },                                                                                                    -- Pale Moon Cloak
                { id = 18735 },                                                                                                    -- Maleki's Footwraps
                { id = 13524 },                                                                                                    -- Skull of Burning Shadows
                {},
                { id = 18737 },                                                                                                    -- Bone Slicing Hatchet
                {},
                { id = 13528 },                                                                                                    -- Twilight Void Bracers
                { id = 13525 },                                                                                                    -- Darkbind Fingers
                { id = 13526 },                                                                                                    -- Flamescarred Girdle
                { id = 13527 },                                                                                                    -- Lavawalker Greaves
                { id = 13509 },                                                                                                    -- Clutch of Foresight
                {},
                { id = 12833, dropRate = 6,                   container = { 12796 } },                                             -- Plans: Hammer of the Titans
                { id = 61791, dropRate = .25,                 container = { 61784 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                {},
                { id = 41985, dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26029, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                        -- Amulet of the Undertaker
            }
        },
        {
            id = "STRATRamsteintheGorger",
            prefix = "18)",
            name = LB["Ramstein the Gorger"],
            defaults = { dropRate = 14 },
            loot = {
                { id = 16737, disc = L["Warrior"] .. ", T0",  container = { 21998 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Valor
                {},
                { id = 18723 },                                                                                                     -- Animated Chain Necklace
                { id = 13374 },                                                                                                     -- Soulstealer Mantle
                { id = 13373 },                                                                                                     -- Band of Flesh
                { id = 13515 },                                                                                                     -- Ramstein's Lightning Bolts
                {},
                { id = 13375 },                                                                                                     -- Crest of Retribution
                { id = 13372 },                                                                                                     -- Slavedriver's Cane
                {},
                { id = 61791, dropRate = .25,                 container = { 61784 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Arcanite Belt Buckle
                {},
                { id = 15880, dropRate = 100,                 container = { 18022, 17001 } },                                       -- Head of Ramstein the Gorger
                { id = 13174, quantity = { 1, 4 },            dropRate = 80,                             container = { 13209, 19812 } }, -- Plagued Flesh Sample
                { id = 41985, quantity = 2,                   dropRate = 100,                            container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26050, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                         -- Ramstein's Splintered Rib
            }
        },
        {
            id = "STRATBaronRivendare",
            prefix = "19)",
            name = LB["Baron Rivendare"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 13335, dropRate = 0.02 },                                                                                    -- Rivendare's Deathcharger
                { id = 13505, dropRate = 1 },                                                                                       -- Runeblade of Baron Rivendare
                {},
                { id = 22411, dropRate = 20 },                                                                                      -- Helm of the Executioner
                { id = 22412, dropRate = 20 },                                                                                      -- Thuzadin Mantle
                { id = 13340, dropRate = 14 },                                                                                      -- Cape of the Black Baron
                { id = 13346, dropRate = 14 },                                                                                      -- Robes of the Exalted
                { id = 22409, dropRate = 20 },                                                                                      -- Tunic of the Crescent Moon
                { id = 13344, dropRate = 14 },                                                                                      -- Dracorian Gauntlets
                { id = 22410, dropRate = 20 },                                                                                      -- Gauntlets of Deftness
                { id = 13345, dropRate = 14 },                                                                                      -- Seal of Rivendare
                { id = 22408, dropRate = 20 },                                                                                      -- Ritssyn's Wand of Bad Mojo
                { id = 13349, dropRate = 14 },                                                                                      -- Scepter of the Unholy
                { id = 13368, dropRate = 14 },                                                                                      -- Bonescraper
                { id = 13361, dropRate = 14 },                                                                                      -- Skullforge Reaver
                { id = 16697, disc = L["Priest"] .. ", T0", container = { 22079 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Devout Bracers
                { id = 16683, disc = L["Mage"] .. ", T0",  container = { 22063 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Magister's Bindings
                { id = 16703, disc = L["Warlock"] .. ", T0", container = { 22071 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },   -- Dreadmist Bracers
                { id = 16710, disc = L["Rogue"] .. ", T0", container = { 22004 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Shadowcraft Bracers
                { id = 16714, disc = L["Druid"] .. ", T0", container = { 22108 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Wildheart Bracers
                { id = 16681, disc = L["Hunter"] .. ", T0", container = { 22011 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Beaststalker's Bindings
                { id = 16671, disc = L["Shaman"] .. ", T0", container = { 22095 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Bindings of Elements
                { id = 16722, disc = L["Paladin"] .. ", T0", container = { 22088 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },   -- Lightforge Bracers
                { id = 16735, disc = L["Warrior"] .. ", T0", container = { 21996 }, servers = { AtlasCFM.Server.VANILLA_PLUS } },   -- Bracers of Valor
                { id = 16694, disc = L["Priest"] .. ", T0", container = { 22085 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Devout Skirt
                { id = 16687, disc = L["Mage"] .. ", T0",  container = { 22067 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Magister's Leggings
                { id = 16699, disc = L["Warlock"] .. ", T0", container = { 22072 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Dreadmist Leggings
                { id = 16709, disc = L["Rogue"] .. ", T0", container = { 22007 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Shadowcraft Pants
                { id = 16719, disc = L["Druid"] .. ", T0", container = { 22111 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Wildheart Kilt
                { id = 16678, disc = L["Hunter"] .. ", T0", container = { 22017 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Pants
                { id = 16668, disc = L["Shaman"] .. ", T0", container = { 22100 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Kilt of Elements
                { id = 16728, disc = L["Paladin"] .. ", T0", container = { 22092 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lightforge Legplates
                { id = 16732, disc = L["Warrior"] .. ", T0", container = { 22000 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Legplates of Valor
                {},
                { id = 61791, dropRate = .25,              container = { 61784 }, servers = { AtlasCFM.Server.TURTLE1 } },          -- Plans: Arcanite Belt Buckle
                {},
                { id = 47413, dropRate = 10,               container = { 47412 }, servers = { AtlasCFM.Server.TURTLE1 } },          -- Recipe: Concoction of the Arcane Giant
                { id = 47415, dropRate = 10,               container = { 47414 }, servers = { AtlasCFM.Server.TURTLE1 } },          -- Recipe: Concoction of the Dreamwater
                {
                    id = 70226,
                    disc = L["Quest Item"],
                    dropRate = 3,
                    container = { 70227, 70228, 70229, 70230, 70231, 70232, 70233,                                                  -- Ancient Warfare Text
                        70234, 70235, 70236, 70238 },
                    servers = { AtlasCFM.Server.TURTLE1 }
                },
                { id = 13251, dropRate = 100,                 container = { 13246, 13243, 13249 } },                                -- Head of Baron Rivendare
                { id = 13174, quantity = { 4, 6 },            dropRate = 80,                      container = { 13209, 19812 } },   -- Plagued Flesh Sample
                { id = 41985, quantity = 3,                   dropRate = 100,                     container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 41700, dropRate = 100,                 container = { 41704 },              servers = { AtlasCFM.Server.TURTLE1 } }, -- Lunar Token
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 100,                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 50021, disc = L["Reagent"],            dropRate = 100,                     servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dragonbreath
            }
        },
        { name = LMD["Ysida Harmon"], color = Colors.GREY },
        { prefix = "1')",             name = LMD["Crusaders' Square Postbox"], color = Colors.GREEN },
        { prefix = "2')",             name = LMD["Market Row Postbox"],        color = Colors.GREEN },
        { prefix = "3')",             name = LMD["Festival Lane Postbox"],     color = Colors.GREEN },
        { prefix = "4')",             name = LMD["Elders' Square Postbox"],    color = Colors.GREEN },
        { prefix = "5')",             name = LMD["King's Square Postbox"],     color = Colors.GREEN },
        { prefix = "6')",             name = LMD["Fras Siabi's Postbox"],      color = Colors.GREEN },
        {
            id = "STRATPostmaster",
            name = LMD["Third Postbox Opened"] .. ": " .. LB["Postmaster Malown"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 13390 }, -- The Postmaster's Band
                { id = 13388 }, -- The Postmaster's Tunic
                { id = 13389 }, -- The Postmaster's Trousers
                { id = 13391 }, -- The Postmaster's Treads
                { id = 13392 }, -- The Postmaster's Seal
                {},
                { id = 13393 }, -- Malown's Slam
            },
        },
        {
            id = "STRATGoldsmithing",
            servers = { AtlasCFM.Server.TURTLE1 },
            name = L["Goldsmithing Plans"],                                                                     --TODO CHECK PLACE
            loot = {
                { id = 56103, disc = LS["Goldsmithing"], dropRate = 100, container = { 56111, 70177, 56066 } }, -- Bottom Half of Advanced Goldsmithing II
            },
        },
        {
            id = "STRATTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["Stratholme"],
            defaults = { dropRate = 2 },
            loot = {
                { id = 16697, disc = L["Priest"] .. ", T0", container = { 22079 }, servers = { AtlasCFM.Server.TURTLE1 } },                            -- Devout Bracers
                { id = 16685, disc = L["Mage"] .. ", T0",  container = { 22062 }, servers = { AtlasCFM.Server.TURTLE1 } },                             -- Magister's Belt
                { id = 16702, disc = L["Warlock"] .. ", T0", dropRate = 1,        container = { 22070 },                servers = { AtlasCFM.Server.TURTLE1 } }, -- Dreadmist Belt
                { id = 16710, disc = L["Rogue"] .. ", T0", container = { 22004 }, servers = { AtlasCFM.Server.TURTLE1 } },                             -- Shadowcraft Bracers
                { id = 16714, disc = L["Druid"] .. ", T0", dropRate = 1.7,        container = { 22108 },                servers = { AtlasCFM.Server.TURTLE1 } }, -- Wildheart Bracers
                { id = 16681, disc = L["Hunter"] .. ", T0", dropRate = 1.7,       container = { 22011 },                servers = { AtlasCFM.Server.TURTLE1 } }, -- Beaststalker's Bindings
                { id = 16671, disc = L["Shaman"] .. ", T0", container = { 22095 }, servers = { AtlasCFM.Server.TURTLE1 } },                            -- Bindings of Elements
                { id = 16723, disc = L["Paladin"] .. ", T0", dropRate = 1,        container = { 22086 },                servers = { AtlasCFM.Server.TURTLE1 } }, -- Lightforge Belt
                { id = 16736, disc = L["Warrior"] .. ", T0", container = { 21994 }, servers = { AtlasCFM.Server.TURTLE1 } },                           -- Belt of Valor
                {},
                { id = 12811, disc = L["Reagent"],         dropRate = 5 },                                                                             -- Righteous Orb
                { id = 12735, dropRate = 15 },                                                                                                         -- Frayed Abomination Stitching
                { id = 12843 },                                                                                                                        -- Corruptor's Scourgestone
                { id = 12841 },                                                                                                                        -- Invader's Scourgestone
                { id = 12840 },                                                                                                                        -- Minion's Scourgestone
                { id = 56102, disc = LS["Goldsmithing"],   dropRate = .03,        container = { 56111, 70177, 56066 },  servers = { AtlasCFM.Server.TURTLE1 } }, -- Top Half of Advanced Goldsmithing II
                { id = 70163, dropRate = 3,                container = { 56016 }, servers = { AtlasCFM.Server.TURTLE1 } },                             -- Plans: Arcane Emerald Gemstone
                { id = 70164, LS["Gemology"],              dropRate = .14,        container = { 56017 },                servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Tempered Azerothian Gemstone
                { id = 70169, LS["Gemology"],              dropRate = .14,        container = { 56010 },                servers = { AtlasCFM.Server.TURTLE1 } }, -- Plans: Beautiful Diamond Gemstone
                { id = 18742, dropRate = .02 },                                                                                                        -- Stratholme Militia Shoulderguard
                { id = 18743, dropRate = .1 },                                                                                                         -- Gracious Cape
                { id = 17061, dropRate = .02 },                                                                                                        -- Juno's Shadow
                { id = 18741, dropRate = .02 },                                                                                                        -- Morlune's Bracer
                { id = 18744, dropRate = .02 },                                                                                                        -- Plaguebat Fur Gloves
                { id = 18745, dropRate = .02 },                                                                                                        -- Sacred Cloth Leggings
                { id = 18736, dropRate = .02 },                                                                                                        -- Plaguehound Leggings
                { id = 12827, dropRate = .1,               container = { 12781 }, servers = { AtlasCFM.Server.TURTLE1 } },                             -- Plans: Serenity
                { id = 16249 },                                                                                                                        -- Formula: Enchant 2H Weapon - Major Intellect
                { id = 16248, dropRate = .88 },                                                                                                        -- Formula: Enchant Weapon - Unholy
                { id = 14495, container = { 14144 } },                                                                                                 -- Pattern: Ghostweave Pants
                { id = 15777, container = { 15096 },       dropRate = .99 },                                                                           -- Pattern: Runic Leather Shoulders
                { id = 15768, container = { 15088 } },                                                                                                 -- Pattern: Wicked Leather Belt
                { id = 18658, container = { 18639 },       dropRate = 4 },                                                                             -- Schematic: Ultra-Flash Shadow Reflector
                { id = 16052, container = { 16009 },       dropRate = 5 },                                                                             -- Schematic: Voice Amplification Modulator
                { id = 56026, container = { 55259 },       dropRate = .08,        servers = { AtlasCFM.Server.TURTLE1 } },                             -- Plans: Sapphire Luminescence
            }
        },
        { name = LIS["Ironweave Battlesuit"], items = "Ironweave" },
        { name = LIS["The Postmaster"],       items = "Strat" },
        { name = L["Tier 0/0.5 Sets"],        items = "AtlasCFMLootT0SetMenu" },
    },
}

for _, bossData in ipairs(AtlasCFM.InstanceData.Stratholme.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil
end
