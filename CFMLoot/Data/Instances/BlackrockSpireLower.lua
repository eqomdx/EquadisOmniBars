---
--- BlackrockSpireLower.lua - Lower Blackrock Spire dungeon instance loot data
---
--- This module contains comprehensive loot tables and boss data for the Lower Blackrock Spire
--- 5-player dungeon instance. It includes all boss encounters, rare drops,
--- and dungeon-specific items with their respective drop rates.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Rare and epic item drops
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
local LS = AtlasCFM.Localization.Spells
local LIS = AtlasCFM.Localization.ItemSets
local LMD = AtlasCFM.Localization.MapData

local GREY = AtlasCFM.Colors.GREY
local GREEN = AtlasCFM.Colors.GREEN

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

AtlasCFM.InstanceData.BlackrockSpireLower = {
    Name = LZ["Lower Blackrock Spire"],
    Location = LZ["Blackrock Mountain"],
    Level = { 55, 60 },
    Acronym = "LBRS",
    MaxPlayers = 10,
    DamageType = L["Physical"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] },
        { letter = "B)",                 info = LZ["Upper Blackrock Spire"] },
        { letter = "C-F)",               info = L["Connections"] }
    },
    Keys = {
        { name = LMD["Brazier of Invocation"], loot = "VanillaKeys", info = LMD["Tier 0.5 Summon"] }
    },
    Bosses = {
        {
            prefix = "1)",
            name = LMD["Vaelan"],
            postfix = L["Upper"],
            color = GREY,
        },
        {
            prefix = "2)",
            name = LMD["Warosh"],
            postfix = L["Wanders"],
            color = GREY,
        },
        {
            name = LMD["Elder Stonefort"],
            postfix = L["Lunar Festival"],
            items = "LunarFestival",
        },
        {
            id = "LBRSPike",
            prefix = "3)",
            name = LMD["Roughshod Pike"],
            loot = {
                { id = 12533, disc = L["Used to summon boss"], dropRate = 100 }, -- Roughshod Pike
            }
        },
        {
            id = "LBRSSpirestoneButcher",
            prefix = "4)",
            name = LMD["Spirestone Butcher"],
            postfix = L["Rare"],
            defaults = { dropRate = 50 },
            loot = {
                { id = 12608 }, -- Butcher's Apron
                {},
                { id = 13286 }, -- Rivenspike
            }
        },
        {
            id = "LBRSOmokk",
            prefix = "5)",
            name = LB["Highlord Omokk"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 16670, disc = L["Shaman"] .. ", T0",              container = { 22096 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Boots of Elements
                {},
                { id = 13166 },                                                                                           -- Slamshot Shoulders
                { id = 13168 },                                                                                           -- Plate of the Shaman King
                { id = 13170 },                                                                                           -- Skyshroud Leggings
                { id = 13169 },                                                                                           -- Tressermane Leggings
                { id = 26045, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Talisman of Bloodlust
                {},
                { id = 13167 },                                                                                           -- Fist of Omokk
                {},
                { id = 12534, disc = L["Used to summon boss"],           dropRate = 100 },                                -- Omokk's Head
                {},
                { id = 41985, dropRate = 100,                            container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 12336, disc = L["Quest Item"],                    dropRate = 25,         container = { 12344 } },  -- Gemstone of Spirestone
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 21982, quantity = { 2, 3 },                       dropRate = 50,         container = { 22149, 22150 } }, -- Ogre Warbeads
                { id = 51217, disc = L["Transmogrification"],            dropRate = 5,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 16671, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Bindings of Elements
                { id = 16710, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Shadowcraft Bracers
                { id = 16735, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Bracers of Valor
                { id = 16681, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Beaststalker's Bindings
                { id = 16714, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Wildheart Bracers
                { id = 16683, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Magister's Bindings
                { id = 16722, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Lightforge Bracers
                { id = 16697, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Devout Bracers
                { id = 16703, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                               -- Dreadmist Bracers
            }
        },
        {
            id = "LBRSSpirestoneBattleLord",
            prefix = "6)",
            name = LMD["Spirestone Battle Lord"],
            postfix = L["Rare"],
            loot = {
                { id = 13284, dropRate = 40 },                               -- Swiftdart Battleboots
                {},
                { id = 13285, dropRate = 60 },                               -- The Blackrock Slicer
                {},
                { id = 21982, dropRate = 14, container = { 22149, 22150 } }, -- Ogre Warbeads
            }
        },
        {
            id = "LBRSSpirestoneLordMagus",
            name = LMD["Spirestone Lord Magus"],
            postfix = L["Rare"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 13282 },                                              -- Ogreseer Tower Boots
                { id = 13283 },                                              -- Magus Ring
                { id = 13261 },                                              -- Globe of D'sak
                { id = 21982, dropRate = 50, container = { 22149, 22150 } }, -- Ogre Warbeads
            }
        },
        {
            id = "LBRSVosh",
            prefix = "7)",
            name = LB["Shadow Hunter Vosh'gajin"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 16712,                                    disc = L["Rogue"] .. ", T0",    container = { 22002 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Shadowcraft Gloves
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 13257 },                                                                                                                   -- Demonic Runed Spaulders
                { id = 12626 },                                                                                                                   -- Funeral Cuffs
                { id = 13255 },                                                                                                                   -- Trueaim Gauntlets
                { id = 12653 },                                                                                                                   -- Riphook
                { id = 12651 },                                                                                                                   -- Blackcrow
                { id = 12654,                                    quantity = 50,                  dropRate = 25 },                                 -- Doomshot
                {},
                { id = 13352,                                    dropRate = 100,                 container = { 12821 } },                         -- Vosh'gajin's Snakestone
                { id = 70226,                                    disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 41985,                                    dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 51217,                                    disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 19258,                                    disc = L["Misc"],               dropRate = 7,                              container = { 19287 },                         servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Ace of Warlords
                { id = 16665,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Tome of Tranquilizing Shot
                { id = 16670,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Boots of the Elements
                { id = 16672,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Gauntlets of Elements
                { id = 16675,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Beaststalker's Boots
                { id = 16676,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Beaststalker's Gloves
                { id = 16682,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Magister's Boots
                { id = 16684,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Magister's Gloves
                { id = 16691,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Devout Sandals
                { id = 26035,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Smolderthorn Scalper
                { id = 16692,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Devout Gloves
                { id = 16704,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Dreadmist Sandals
                { id = 16705,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Dreadmist Wraps
                { id = 16711,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Shadowcraft Boots
                { id = 16715,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Wildheart Boots
                { id = 16717,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Wildheart Gloves
                { id = 16724,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Lightforge Gauntlets
                { id = 16725,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Lightforge Boots
                { id = 16734,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Boots of Valor
                { id = 16737,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },    -- Gauntlets of Valor
            }
        },
        {
            name = LMD["Fifth Mosh'aru Tablet"],
            color = GREY,
        },
        {
            prefix = "8)",
            name = LMD["Bijou"],
            color = GREY,
        },
        {
            id = "LBRSVoone",
            prefix = "9)",
            name = LB["War Master Voone"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 16676,                                    disc = L["Hunter"] .. ", T0",   container = { 22015 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Gloves
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 13177 },                                                                                                    -- Talisman of Evasion
                { id = 13179 },                                                                                                    -- Brazecore Armguards
                { id = 22231 },                                                                                                    -- Kayser's Boots of Precision
                {},
                { id = 13173,                                    dropRate = 100 },                                                 -- Flightblade Throwing Axe
                { id = 12582 },                                                                                                    -- Keris of Zul'Serak
                {},
                { id = 12335,                                    disc = L["Quest Item"],         dropRate = 20,                             container = { 12344 } }, -- Gemstone of Smolderthorn
                { id = 70226,                                    disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 41454,                                    disc = L["Quest Item"],         dropRate = 100,                            servers = { AtlasCFM.Server.TURTLE1 } }, -- Throwing Axes of the Amani
                { id = 60714,                                    disc = L["Quest Item"],         dropRate = 100,                            servers = { AtlasCFM.Server.TURTLE1 } }, -- War Master Voone's Tusks
                { id = 41985,                                    dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 51217,                                    disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 50022,                                    disc = L["Reagent"],            servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Chromatic Topaz
                { id = 19258,                                    disc = L["Misc"],               container = { 19287 },                     servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Ace of Warlords
                { id = 26041,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Wild Shoulderguards
                { id = 16670,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Boots of the Elements
                { id = 16672,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Gauntlets of Elements
                { id = 16675,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Beaststalker's Boots
                { id = 16682,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Magister's Boots
                { id = 16684,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Magister's Gloves
                { id = 16691,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Devout Sandals
                { id = 16692,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Devout Gloves
                { id = 16704,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dreadmist Sandals
                { id = 16705,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dreadmist Wraps
                { id = 16711,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Shadowcraft Boots
                { id = 16712,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Shadowcraft Gloves
                { id = 16715,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Wildheart Boots
                { id = 16717,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Wildheart Gloves
                { id = 16724,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Lightforge Gauntlets
                { id = 16725,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Lightforge Boots
                { id = 16734,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Boots of Valor
                { id = 16737,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Gauntlets of Valor
            }
        },
        {
            id = "LBRSGemology",
            servers = { AtlasCFM.Server.TURTLE1 },
            name = L["Gemology Plans"],
            loot = {
                { id = 56105, disc = LS["Gemology"], dropRate = 100, container = { 56109, 70160, 56015 } }, -- Top Half of Advanced Gemology I
            },
        },
        {
            id = "LBRSGREYhoof",
            name = LB["Mor Grayhoof"],
            postfix = L["Summon"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 22306 }, -- Ironweave Belt
                { id = 22325 }, -- Belt of the Trickster
                { id = 22319 }, -- Tome of Divine Right
                { id = 22398 }, -- Idol of Rejuvenation
                {},
                { id = 22322 }, -- The Jaw Breaker
            }
        },
        {
            name = LMD["Sixth Mosh'aru Tablet"],
            color = GREY,
        },
        {
            prefix = "10)",
            name = LMD["Bijou's Belongings"],
            color = GREY,
        },
        {
            prefix = "11)",
            name = LMD["Human Remains"],
            postfix = L["Lower"],
            loot = {
                { id = 12812, disc = L["Quest Item"], dropRate = 100 }, -- Unfired Plate Gauntlets
            }
        },
        {
            name = LMD["Unfired Plate Gauntlets"],
            postfix = L["Lower"],
            color = GREY,
        },
        {
            id = "LBRSGrimaxe",
            prefix = "12)",
            name = LB["Bannok Grimaxe"],
            postfix = L["Rare"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 12637 },                                      -- Backusarian Gauntlets
                { id = 12634 },                                      -- Chiselbrand Girdle
                {},
                { id = 12621 },                                      -- Demonfork
                {},
                { id = 12838, dropRate = 7, container = { 12784 } }, -- Plans: Arcanite Reaper
            }
        },
        {
            id = "LBRSSmolderweb",
            prefix = "13)",
            name = LB["Mother Smolderweb"],
            defaults = { dropRate = 25 },
            loot = {
                { id = 16715, disc = L["Druid"] .. ", T0",    container = { 22107 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Wildheart Boots
                {},
                { id = 13244 },                                                                                                   -- Gilded Gauntlets
                { id = 13213 },                                                                                                   -- Smolderweb's Eye
                {},
                { id = 13183 },                                                                                                   -- Venomspitter
                {},
                { id = 80758, dropRate = 40,                  servers = { AtlasCFM.Server.TURTLE1 } },                            -- Carapace of the Spider Queen
                {},
                { id = 41985, dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 26039, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                       -- Bite of the Spider
                { id = 26052, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                       -- Crown of the Brood Mother
                { id = 26053, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                       -- Blood of the Brood Mother
            }
        },
        {
            id = "LBRSCrystalFang",
            prefix = "14)",
            name = LB["Crystal Fang"],
            postfix = L["Rare"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 13185 }, -- Sunderseer Mantle
                { id = 13184 }, -- Fallbrush Handgrips
                {},
                { id = 13218 }, -- Fang of the Crystal Spider
            }
        },
        {
            prefix = "15)",
            name = LMD["Urok's Tribute Pile"],
            color = GREY,
        },
        {
            id = "LBRSDoomhowl",
            name = LB["Urok Doomhowl"],
            postfix = L["Summon"],
            defaults = { dropRate = 25 },
            loot = {
                { id = 13258 },                                                                                      -- Slaghide Gauntlets
                { id = 22232 },                                                                                      -- Marksman's Girdle
                { id = 13259 },                                                                                      -- Ribsteel Footguards
                { id = 13178 },                                                                                      -- Rosewine Circle
                {},
                { id = 18784, dropRate = 16,                  container = { 18771, 12725, 12620 } },                 -- Top Half of Advanced Armorsmithing: Volume III
                {},
                { id = 12712, disc = L["Quest Item"],         dropRate = 100,                     container = { 15867 } }, -- Warosh's Mojo
                { id = 41985, dropRate = 100,                 container = { 41986 },              servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 21982, quantity = { 2, 3 },            dropRate = 50,                      container = { 22149, 22150 } }, -- Ogre Warbeads
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                       servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                       servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            id = "LBRSZigris",
            prefix = "16)",
            name = LB["Quartermaster Zigris"],
            defaults = { dropRate = 10 },
            loot = {
                { id = 13253 },                                                                                                                       -- Hands of Power
                { id = 13252 },                                                                                                                       -- Cloudrunner Girdle
                {},
                { id = 12835, container = { 12798 } },                                                                                                -- Plans: Annihilator
                {},
                { id = 80759, servers = { AtlasCFM.Server.TURTLE1 } },                                                                                -- Cloak of the Protector
                {},
                { id = 13446, quantity = 5,                         dropRate = 100,                            servers = { AtlasCFM.Server.TURTLE1 } }, -- Major Healing Potion
                { id = 13444, quantity = 5,                         dropRate = 100,                            servers = { AtlasCFM.Server.TURTLE1 } }, -- Major Mana Potion
                {},
                { id = 56101, disc = LS["Goldsmithing"],            dropRate = 30,                             container = { 56110, 70211, 56094 },  servers = { AtlasCFM.Server.TURTLE1 } }, -- Bottom Half of Advanced Goldsmithing I
                { id = 22138, dropRate = 80,                        servers = { AtlasCFM.Server.TURTLE1 } },                                          -- Blackrock Bracer
                { id = 41478, dropRate = 100,                       container = { 41465 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Lower Half of the Thunderbrew Golden Lager Plans
                { id = 41985, dropRate = 100,                       container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                {},
                { id = 51217, disc = L["Transmogrification"],       dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                { id = 50022, disc = L["Reagent"],                  servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Chromatic Topaz
                {},
                { id = 26025, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Old Foundry Boots
                { id = 16670, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Boots of the Elements
                { id = 16672, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Gauntlets of Elements
                { id = 16675, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Beaststalker's Boots
                { id = 16676, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Beaststalker's Gloves
                { id = 16682, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Magister's Boots
                { id = 18987, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Blackhand's Command
                { id = 16684, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Magister's Gloves
                { id = 16691, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Devout Sandals
                { id = 16692, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Devout Gloves
                { id = 16704, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Dreadmist Sandals
                { id = 16705, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Dreadmist Wraps
                { id = 16711, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Shadowcraft Boots
                { id = 16712, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Shadowcraft Gloves
                { id = 16715, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Wildheart Boots
                { id = 16717, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Wildheart Gloves
                { id = 16724, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Lightforge Gauntlets
                { id = 16725, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Lightforge Boots
                { id = 16734, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Boots of Valor
                { id = 16737, dropRate = 1,                         servers = { AtlasCFM.Server.VANILLA_PLUS } },                                     -- Gauntlets of Valor
            }
        },
        {
            id = "LBRSHalycon",
            prefix = "17)",
            name = LB["Halycon"],
            defaults = { dropRate = 25 },
            loot = {
                { id = 13212 },                                                                                      -- Halycon's Spiked Collar
                { id = 22313 },                                                                                      -- Ironweave Bracers
                { id = 13211 },                                                                                      -- Slashclaw Bracers
                { id = 13210 },                                                                                      -- Pads of the Dread Wolf
                {},
                { id = 41985, dropRate = 100,                 container = { 41986 },                     servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226, disc = L["Quest Item"],         dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217, disc = L["Transmogrification"], dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 16670, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Boots of the Elements
                { id = 16672, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Gauntlets of Elements
                { id = 16675, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Beaststalker's Boots
                { id = 16676, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Beaststalker's Gloves
                { id = 16682, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Magister's Boots
                { id = 16684, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Magister's Gloves
                { id = 16691, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Devout Sandals
                { id = 16692, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Devout Gloves
                { id = 16704, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Dreadmist Sandals
                { id = 16705, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Dreadmist Wraps
                { id = 16711, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Shadowcraft Boots
                { id = 16712, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Shadowcraft Gloves
                { id = 16715, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Wildheart Boots
                { id = 16717, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Wildheart Gloves
                { id = 16724, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Lightforge Gauntlets
                { id = 16725, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Lightforge Boots
                { id = 16734, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Boots of Valor
                { id = 16737, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },          -- Gauntlets of Valor
            }
        },
        {
            id = "LBRSSlavener",
            name = LB["Gizrul the Slavener"],
            defaults = { dropRate = 25 },
            loot = {
                { id = 16718,                                    disc = L["Druid"] .. ", T0",               container = { 22112 }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Wildheart Spaulders
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 13208 },                                                                                                   -- Bleak Howler Armguards
                { id = 13206 },                                                                                                   -- Wolfshear Leggings
                {},
                { id = 13205 },                                                                                                   -- Rhombeard Protector
                {},
                { id = 83573,                                    disc = L["Book"],                          dropRate = 15,         servers = { AtlasCFM.Server.TURTLE1 } }, -- Book of Shred VI
                { id = 26037,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Mask of the Predator
                {},
                { id = 70226,                                    disc = L["Quest Item"],                    dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 41985,                                    dropRate = 100,                            container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                {},
                { id = 51217,                                    disc = L["Transmogrification"],            dropRate = 5,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 16704,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Dreadmist Sandals
                { id = 16734,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Boots of Valor
                { id = 16675,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Beaststalker's Boots
                { id = 16711,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Shadowcraft Boots
                { id = 16682,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Magister's Boots
                { id = 16715,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Wildheart Boots
                { id = 16691,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Devout Sandals
                { id = 16725,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Lightforge Boots
                { id = 19227,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Ace of Beasts
                { id = 16670,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                    -- Boots of the Elements
            }
        },
        {
            id = "LBRSBashguud",
            prefix = "18)",
            name = LB["Ghok Bashguud"],
            postfix = L["Rare"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 13203 },                                       -- Armswake Cloak
                {},
                { id = 13198 },                                       -- Hurd Smasher
                { id = 13204 },                                       -- Bashguuder
                {},
                { id = 22138, dropRate = 80, container = { 22057 } }, -- Blackrock Bracer
            }
        },
        {
            id = "LBRSWyrmthalak",
            prefix = "19)",
            name = LB["Overlord Wyrmthalak"],
            defaults = { dropRate = 13 },
            loot = {
                { id = 16679,                                    disc = L["Hunter"] .. ", T0",              container = { 22016 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Mantle
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 13162 },                                                                                                                                  -- Reiver Claws
                { id = 13164 },                                                                                                                                  -- Heart of the Scale
                { id = 22321 },                                                                                                                                  -- Heart of Wyrmthalak
                { id = 80760,                                    servers = { AtlasCFM.Server.TURTLE1 } },                                                        -- Spireblade Band
                { id = 26040,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Blackrock Warhelm
                {},
                { id = 13163 },                                                                                                                                  -- Relentless Scythe
                { id = 13148 },                                                                                                                                  -- Chillpike
                { id = 13161 },                                                                                                                                  -- Trindlehaven Staff
                {},
                { id = 12780,                                    dropRate = 100,                            container = { 13966, 13968, 13965 } },               -- General Drakkisath's Command
                {},
                { id = 13143,                                    dropRate = 2 },                                                                                 -- Mark of the Dragon Lord
                {},
                { id = 47413,                                    dropRate = 10,                             container = { 47412 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Recipe: Concoction of the Arcane Giant
                { id = 47415,                                    dropRate = 10,                             container = { 47414 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Recipe: Concoction of the Dreamwater
                { id = 56097,                                    disc = L["Quest Item"],                    dropRate = .5,                             container = { 56099, 70175, 56064, 70223, 56096 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Top Half of Advanced Jewelcrafting XI: Hard as Diamonds
                { id = 12337,                                    disc = L["Quest Item"],                    dropRate = 30,                             container = { 12344 } }, -- Gemstone of Bloodaxe
                { id = 16786,                                    dropRate = 80,                             quantity = 2,                              container = { 16309 } }, -- Black Dragonspawn Eye
                { id = 13519,                                    dropRate = 1,                              servers = { AtlasCFM.Server.VANILLA_PLUS } },        -- Recipe: Flask of the Titans
                { id = 41985,                                    quantity = 3,                              dropRate = 100,                            container = { 41986 },                             servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 41700,                                    dropRate = 100,                            container = { 41704 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Lunar Token
                { id = 61459,                                    dropRate = 100,                            container = { 61465 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Eye of Wyrmthalak
                {},
                { id = 51217,                                    disc = L["Transmogrification"],            dropRate = 100,                            quantity = 2,                                      servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                { id = 50022,                                    disc = L["Reagent"],                       servers = { AtlasCFM.Server.VANILLA_PLUS } },        -- Chromatic Topaz
                {},
                { id = 16667,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Coif of Elements
                { id = 16677,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Beaststalker's Cap
                { id = 16686,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Magister's Crown
                { id = 16693,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Devout Crown
                { id = 16698,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Dreadmist Mask
                { id = 16707,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Shadowcraft Cap
                { id = 16720,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Wildheart Cowl
                { id = 16727,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Lightforge Helm
                { id = 16731,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                   -- Helm of Valor
            }
        },
        {
            id = "LBRSFelguard",
            prefix = "1')",
            name = LMD["Burning Felguard"],
            postfix = L["Rare"] .. ", " .. L["Summon"],
            color = GREEN,
            defaults = { dropRate = 50 },
            loot = {
                { id = 13181 }, -- Demonskin Gloves
                {},
                { id = 13182 }, -- Phase Blade
            }
        },
        {
            id = "LBRSTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["Lower Blackrock Spire"],
            defaults = { dropRate = 2 },
            loot = {
                { id = 14513, dropRate = 10,               container = { 14152 } },                                                                              -- Pattern: Robe of the Archmage
                {},
                { id = 16696, disc = L["Priest"] .. ", T0", container = { 22078 },     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Devout Belt
                { id = 16685, disc = L["Mage"] .. ", T0",  container = { 22062 },      servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Magister's Belt
                { id = 16683, dropRate = 1,                disc = L["Mage"] .. ", T0", container = { 22063 },                             servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Magister's Bindings
                { id = 16703, disc = L["Warlock"] .. ", T0", container = { 22071 },    servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Dreadmist Bracers
                { id = 16713, disc = L["Rogue"] .. ", T0", container = { 22002 },      servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Shadowcraft Belt
                { id = 16716, dropRate = 1,                disc = L["Druid"] .. ", T0", container = { 22106 },                            servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Wildheart Belt
                { id = 16680, dropRate = 1,                disc = L["Hunter"] .. ", T0", container = { 22010 },                           servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Belt
                { id = 16673, disc = L["Shaman"] .. ", T0", container = { 22098 },     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Cord of Elements
                { id = 16736, disc = L["Warrior"] .. ", T0", container = { 21994 },    servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Belt of Valor
                { id = 16735, disc = L["Warrior"] .. ", T0", container = { 21996 },    servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                         -- Bracers of Valor
                {},
                { id = 9214,  disc = L["Book"],            dropRate = 5 },                                                                                       -- Grimoire of Inferno
                {},
                { id = 70163, dropRate = 3,                container = { 56016 },      servers = { AtlasCFM.Server.TURTLE1 } },                                  -- Plans: Arcane Emerald Gemstone
                { id = 56097, disc = L["Quest Item"],      dropRate = .5,              container = { 56099, 70175, 56064, 70223, 56096 }, servers = { AtlasCFM.Server.TURTLE1 } }, -- Top Half of Advanced Jewelcrafting XI: Hard as Diamonds
                { id = 15749, dropRate = 5,                container = { 15053 } },                                                                              -- Pattern: Volcanic Breastplate
                { id = 15775, dropRate = 23,               container = { 15055 } },                                                                              -- Pattern: Volcanic Shoulders
                { id = 13494, container = { 13457 } },                                                                                                           -- Recipe: Greater Fire Protection Potion
                { id = 16250, dropRate = 3 },                                                                                                                    -- Formula: Enchant Weapon - Superior Striking
                { id = 16244, dropRate = 10 },                                                                                                                   -- Formula: Enchant Gloves - Greater Strength
                {},
                { id = 12219, disc = L["Quest Item"],      dropRate = 8,               container = { 12344 } },                                                  -- Unadorned Seal of Ascension
                { id = 12586, disc = L["Consumable"],      dropRate = 80 },                                                                                      -- Immature Venom Sac
            }
        },
        { name = LIS["Ironweave Battlesuit"], items = "Ironweave" },
        { name = LIS["Spider's Kiss"],        items = "SpiderKiss" },
        { name = L["Tier 0/0.5 Sets"],        items = "AtlasCFMLootT0SetMenu" },
    }
}

-- Initialize items for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.BlackrockSpireLower.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
