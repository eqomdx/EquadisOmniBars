---
--- BlackrockSpireUpper.lua - Upper Blackrock Spire raid instance loot data
---
--- This module contains comprehensive loot tables and boss data for the Upper Blackrock Spire
--- 10-player raid instance. It includes all boss encounters, rare drops,
--- and raid-specific items with their respective drop rates.
---
--- Features:
--- • Complete boss encounter loot tables
--- • Rare and epic item drops
--- • Raid entrance and layout data
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
local LIS = AtlasCFM.Localization.ItemSets
local LMD = AtlasCFM.Localization.MapData

local GREY = AtlasCFM.Colors.GREY

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

AtlasCFM.InstanceData.BlackrockSpireUpper = {
    Name = LZ["Upper Blackrock Spire"],
    Location = LZ["Blackrock Mountain"],
    Level = { 55, 60 },
    Acronym = "UBRS",
    MaxPlayers = 10,
    DamageType = L["Fire"],
    L["Physical"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] },
        { letter = "B)",                 info = LZ["Lower Blackrock Spire"] },
        { letter = "C-E)",               info = L["Connections"] }
    },
    Keys = {
        { name = LMD["Seal of Ascension"],     loot = "VanillaKeys" },
        { name = LMD["Brazier of Invocation"], loot = "VanillaKeys", info = LMD["Tier 0.5 Summon"] }
    },
    Bosses = {
        {
            id = "UBRSEmberseer",
            prefix = "1)",
            name = LB["Pyroguard Emberseer"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16672,                                    disc = L["Shaman"] .. ", " .. "T0", servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Gauntlets of Elements
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 12929 },                                                                                      -- Emberfury Talisman
                { id = 12927 },                                                                                      -- Truestrike Shoulders
                { id = 12905 },                                                                                      -- Wildfire Cape
                { id = 12926 },                                                                                      -- Flaming Band
                {},
                { id = 26044,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Burning Amulet
                { id = 41985,                                    dropRate = 100,                 container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 23320,                                    disc = L["Book"],               dropRate = 8 },     -- Tablet of Flame Shock VI
                { id = 17322,                                    dropRate = 100,                 container = { 18398, 18399 } }, -- Eye of the Emberseer
                { id = 21988,                                    dropRate = 100,                 container = { 22057 } }, -- Ember of the Emberseer
                {},
                { id = 51217,                                    disc = L["Transmogrification"], dropRate = 5,                                  servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            id = "UBRSSolakar",
            prefix = "2)",
            name = LB["Solakar Flamewreath"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16695,                                    disc = L["Priest"] .. ", " .. "T0",        servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Devout Mantle
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 12609 },                                                                                      -- Polychromatic Visionwrap
                { id = 12603 },                                                                                      -- Nightbrace Tunic
                { id = 12589 },                                                                                      -- Dustfeather Sash
                { id = 12606 },                                                                                      -- Crystallized Girdle
                { id = 26026,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },       -- Flame Wreath
                {},
                { id = 41985,                                    dropRate = 100,                            container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 18657,                                    dropRate = 6,                              container = { 18638 } }, -- Schematic: Hyper-Radiant Flame Reflector
                {},
                { id = 51217,                                    disc = L["Transmogrification"],            dropRate = 5,                                  servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                {},
                { id = 50021,                                    disc = L["Reagent"],                       dropRate = 100,                                servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dragonbreath
            }
        },
        {
            id = "UBRSFlame",
            name = LMD["Father Flame"],
            loot = {
                { id = 13371, dropRate = .08 }, -- Father Flame
            }
        },
        {
            prefix = "3)",
            name = LMD["Darkstone Tablet"],
            color = GREY,
        },
        {
            name = LMD["Doomrigger's Coffer"],
            color = GREY,
        },
        {
            id = "UBRSRunewatcher",
            prefix = "4)",
            name = LB["Jed Runewatcher"],
            postfix = L["Rare"],
            defaults = { dropRate = 33 },
            loot = {
                { id = 12604 },                                                                              -- Starfire Tiara
                {},
                { id = 12930 },                                                                              -- Briarwood Reed
                { id = 41985, dropRate = 100,         container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 22138, dropRate = 80,          container = { 22057 } },                               -- Blackrock Bracer
                { id = 70226, disc = L["Quest Item"], dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 12605 },                                                                              -- Serpentine Skuller
            }
        },
        {
            id = "UBRSAnvilcrack",
            prefix = "5)",
            name = LB["Goraluk Anvilcrack"],
            postfix = L["Rare"],
            defaults = { dropRate = 14 },
            loot = {
                { id = 13502 },                                                                                                         -- Handcrafted Mastersmith Girdle
                { id = 13498 },                                                                                                         -- Handcrafted Mastersmith Leggings
                { id = 18047 },                                                                                                         -- Flame Walkers
                { id = 18048 },                                                                                                         -- Mastersmith's Hammer
                {},
                { id = 12834, container = { 12790 } },                                                                                  -- Plans: Arcanite Champion
                { id = 12837, container = { 12794 } },                                                                                  -- Plans: Masterwork Stormhammer
                { id = 12728, container = { 12641 } },                                                                                  -- Plans: Invulnerable Mail
                {},
                { id = 18779, disc = L["Misc"],       dropRate = 15,         container = { 18769, 12727, 12618 } },                     -- Bottom Half of Advanced Armorsmithing: Volume I
                { id = 12806, disc = L["Quest Item"], dropRate = 100,        container = { 12696, 12628, { 9224, 5 }, 12849, 10377, 10383 } }, -- Unforged Rune Covered Breastplate
                { id = 41985, dropRate = 100,         container = { 41986 }, servers = { AtlasCFM.Server.TURTLE } },                    -- Crest of Valor
                { id = 70226, disc = L["Quest Item"], dropRate = 1,          servers = { AtlasCFM.Server.TURTLE1 } },                   -- Ancient Warfare Text
            }
        },
        {
            id = "UBRSRend",
            prefix = "6)",
            name = LB["Warchief Rend Blackhand"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 12587, dropRate = 23 },                                                                             -- Eye of Rend
                { id = 12588 },                                                                                            -- Bonespike Shoulder
                { id = 12936 },                                                                                            -- Battleborn Armbraces
                { id = 18104 },                                                                                            -- Feralsurge Girdle
                { id = 12935, dropRate = 23 },                                                                             -- Warmaster Legguards
                { id = 18102, dropRate = 23 },                                                                             -- Dragonrider Boots
                { id = 22247 },                                                                                            -- Faith Healer's Boots
                { id = 26049, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Horde Grips
                {},
                { id = 18103, dropRate = 23 },                                                                             -- Band of Rumination
                {},
                { id = 12583, dropRate = 8 },                                                                              -- Blackhand Doomsaw
                { id = 12940, dropRate = 8 },                                                                              -- Dal'Rend's Sacred Charge
                { id = 12939, dropRate = 8 },                                                                              -- Dal'Rend's Tribal Guardian
                { id = 12590, dropRate = 1 },                                                                              -- Felstriker
                {},
                { id = 16669, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Pauldrons of Elements
                { id = 16679, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Beaststalker's Mantle
                { id = 16689, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Magister's Mantle
                { id = 16695, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Devout Mantle
                { id = 16701, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Dreadmist Mantle
                { id = 16708, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Shadowcraft Spaulders
                { id = 16718, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Wildheart Spaulders
                { id = 16729, servers = { AtlasCFM.Server.VANILLA_PLUS } },                                                -- Lightforge Spaulders
                { id = 16733, disc = L["Warrior"] .. ", " .. "T0" },                                                       -- Spaulders of Valor
                {},
                { id = 41985, quantity = 3,                              dropRate = 100,                            container = { 41986 },                servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 12630, dropRate = 100,                            container = { 13966, 13965, 13968 } },            -- Head of Rend Blackhand
                { id = 22138, dropRate = 80,                             container = { 22057 } },                          -- Blackrock Bracer
                { id = 70226, disc = L["Quest Item"],                    dropRate = 1,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 50022, disc = L["Reagent"],                       servers = { AtlasCFM.Server.VANILLA_PLUS } },     -- Chromatic Topaz
                { id = 51217, disc = L["Transmogrification"],            dropRate = 5,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            id = "UBRSGyth",
            name = LB["Gyth"],
            defaults = { dropRate = 20 },
            loot = {
                { id = 16669,                                    disc = L["Shaman"] .. ", " .. "T0", servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Pauldrons of Elements
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 22225 },                                                                                      -- Dragonskin Cowl
                { id = 12960 },                                                                                      -- Tribal War Feathers
                { id = 12953 },                                                                                      -- Dragoneye Coif
                { id = 12952 },                                                                                      -- Gyth's Skull
                { id = 26043,                                    dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } }, -- Dragon Wing Tabard
                {},
                { id = 13522,                                    dropRate = 3,                   container = { 13513 } }, -- Recipe: Flask of Chromatic Resistance
                {},
                { id = 41985,                                    dropRate = 100,                 container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 12871,                                    disc = L["Quest Item"],         dropRate = 4 },     -- Chromatic Carapace
                { id = 70226,                                    disc = L["Quest Item"],         dropRate = 1,                                  servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217,                                    disc = L["Transmogrification"], dropRate = 5,                                  servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            prefix = "7)",
            name = LMD["Awbee"],
            color = GREY,
        },
        {
            id = "UBRSBeast",
            prefix = "8)",
            name = LB["The Beast"],
            defaults = { dropRate = 10 },
            loot = {
                { id = 16729,                                    disc = L["Paladin"] .. ", " .. "T0",       dropRate = 10,  servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Lightforge Spaulders
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 12967 },                                                                                                 -- Bloodmoon Cloak
                { id = 12968 },                                                                                                 -- Frostweaver Cape
                { id = 12966 },                                                                                                 -- Blackmist Armguards
                { id = 12965 },                                                                                                 -- Spiritshroud Leggings
                { id = 12963 },                                                                                                 -- Blademaster Leggings
                { id = 12964 },                                                                                                 -- Tristam Legguards
                { id = 22311 },                                                                                                 -- Ironweave Boots
                { id = 26046,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Tristam Boots
                {},
                { id = 12709 },                                                                                                 -- Finkle's Skinner
                { id = 12969 },                                                                                                 -- Seeping Willow
                {},
                { id = 24101,                                    disc = L["Book"],                          dropRate = 13 },    -- Book of Ferocious Bite VI
                { id = 19227,                                    disc = L["Darkmoon Faire Card"],           dropRate = 5,   container = { 19288 } }, -- Ace of Beasts
                { id = 12731,                                    disc = L["Misc"],                          dropRate = 2 },     -- Pristine Hide of the Beast
                { id = 41985,                                    quantity = 2,                              dropRate = 100, container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 70226,                                    disc = L["Quest Item"],                    dropRate = 1,   servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                {},
                { id = 51217,                                    disc = L["Transmogrification"],            dropRate = 5,   servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                { id = 16668,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Kilt of Elements
                { id = 16678,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Beaststalker's Pants
                { id = 16687,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Magister's Leggings
                { id = 16694,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Devout Skirt
                { id = 16699,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Dreadmist Leggings
                { id = 16709,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Shadowcraft Pants
                { id = 16719,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Wildheart Kilt
                { id = 16728,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Lightforge Legplates
                { id = 16732,                                    servers = { AtlasCFM.Server.VANILLA_PLUS } },                  -- Legplates of Valor
            }
        },
        {
            id = "UBRSValthalak",
            name = LB["Lord Valthalak"],
            postfix = L["Summon"],
            defaults = { dropRate = 25 },
            loot = {
                { name = L["Tier 0.5 Summonable"], icon = "INV_Misc_Bag_09" },
                { id = 22302 },                                                                                      -- Ironweave Cowl
                { id = 22340 },                                                                                      -- Pendant of Celerity
                { id = 22337 },                                                                                      -- Shroud of Domination
                { id = 22343 },                                                                                      -- Handguards of Savagery
                { id = 22342 },                                                                                      -- Leggings of Torment
                {},
                { id = 22339 },                                                                                      -- Rune Band of Wizardry
                {},
                { id = 22336 },                                                                                      -- Draconian Aegis of the Legion
                { id = 22335 },                                                                                      -- Lord Valthalak's Staff of Command
                {},
                { id = 51217,                      disc = L["Transmogrification"], dropRate = 5, servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
            }
        },
        {
            name = LMD["Finkle Einhorn"],
            color = GREY,
        },
        {
            id = "UBRSDrakkisath",
            prefix = "9)",
            name = LB["General Drakkisath"],
            defaults = { dropRate = 11 },
            loot = {
                { id = 22267, dropRate = 25 },                                                                                       -- Spellweaver's Turban
                { id = 13141, dropRate = 25 },                                                                                       -- Tooth of Gnarr
                { id = 22269, dropRate = 25 },                                                                                       -- Shadow Prowler's Cloak
                { id = 13142, dropRate = 25 },                                                                                       -- Brigam Girdle
                { id = 13098, dropRate = 25 },                                                                                       -- Painweaver Band
                { id = 22268, dropRate = 25 },                                                                                       -- Draconic Infused Emblem
                { id = 22253, dropRate = 25 },                                                                                       -- Tome of the Lost
                { id = 13090, dropRate = 10,                  servers = { AtlasCFM.Server.TURTLE1 } },                               -- Breastplate of the Chosen
                {},
                { id = 12602, dropRate = 25 },                                                                                       -- Draconian Deflector
                { id = 12592, dropRate = 1 },                                                                                        -- Blackblade of Shahram
                {},
                { id = 47413, dropRate = 10,                  container = { 47412 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Recipe: Concoction of the Arcane Giant
                { id = 47415, dropRate = 10,                  container = { 47414 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Recipe: Concoction of the Dreamwater
                { id = 15730, dropRate = 4,                   container = { 15047 } },                                               -- Pattern: Red Dragonscale Breastplate
                { id = 13519, dropRate = 3,                   container = { 13510 },                     servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Recipe: Flask of the Titans
                { id = 13516, dropRate = 1,                   servers = { AtlasCFM.Server.VANILLA_PLUS } },                          -- Recipe: Flask of Indomitable Might
                {},
                { id = 16690, disc = L["Priest"] .. ", " .. "T0" },                                                                  -- Devout Robe
                { id = 16688, disc = L["Mage"] .. ", " .. "T0" },                                                                    -- Magister's Robes
                { id = 16700, disc = L["Warlock"] .. ", " .. "T0" },                                                                 -- Dreadmist Robe
                { id = 16721, disc = L["Rogue"] .. ", " .. "T0" },                                                                   -- Shadowcraft Tunic
                { id = 16706, disc = L["Druid"] .. ", " .. "T0" },                                                                   -- Wildheart Vest
                { id = 16674, disc = L["Hunter"] .. ", " .. "T0" },                                                                  -- Beaststalker's Tunic
                { id = 16666, disc = L["Shaman"] .. ", " .. "T0" },                                                                  -- Vest of Elements
                { id = 16726, disc = L["Paladin"] .. ", " .. "T0" },                                                                 -- Lightforge Breastplate
                { id = 16730, disc = L["Warrior"] .. ", " .. "T0" },                                                                 -- Breastplate of Valor
                {},
                { id = 70226, disc = L["Quest Item"],         dropRate = 3,                              servers = { AtlasCFM.Server.TURTLE1 } }, -- Ancient Warfare Text
                { id = 41985, quantity = 3,                   dropRate = 100,                            container = { 41986 },                         servers = { AtlasCFM.Server.TURTLE } }, -- Crest of Valor
                { id = 16663, dropRate = 100,                 container = { 16309 } },                                               -- Blood of the Black Dragon Champion
                { id = 41700, dropRate = 100,                 container = { 41704 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Lunar Token
                { id = 61464, dropRate = 100,                 container = { 61465 },                     servers = { AtlasCFM.Server.TURTLE1 } }, -- Dragonblood Heart
                { id = 51217, disc = L["Transmogrification"], quantity = 3,                              dropRate = 100,                                servers = { AtlasCFM.Server.TURTLE1 } }, -- Fashion Coin
                { id = 50022, disc = L["Reagent"],            servers = { AtlasCFM.Server.VANILLA_PLUS } },                          -- Chromatic Topaz
            }
        },
        {
            name = LMD["Drakkisath's Brand"],
            color = GREY,
        },
        {
            prefix = "10)",
            name = LZ["Blackwing Lair"],
            postfix = "BWL",
            color = GREY,
        },
        {
            id = "UBRSTrash",
            name = L["Trash Mobs"] .. "-" .. LZ["Upper Blackrock Spire"],
            defaults = { dropRate = 2 },
            loot = {
                { id = 13260,                                    dropRate = .05 },                                               -- Wind Dancer Boots
                {},
                { id = 16696,                                    disc = L["Priest"] .. ", " .. "T0", dropRate = 2.25,                            servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Devout Belt
                { id = 16683,                                    disc = L["Mage"] .. ", " .. "T0", dropRate = 1.5,                               servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Magister's Bindings
                { id = 16703,                                    disc = L["Warlock"] .. ", " .. "T0", dropRate = 2.5,                            servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Dreadmist Bracers
                { id = 16713,                                    disc = L["Rogue"] .. ", " .. "T0", servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Shadowcraft Belt
                { id = 16681,                                    disc = L["Hunter"] .. ", " .. "T0", dropRate = 1.75,                            servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Bindings
                { id = 16680,                                    disc = L["Hunter"] .. ", " .. "T0", dropRate = 1.5,                             servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Beaststalker's Belt
                { id = 16673,                                    disc = L["Shaman"] .. ", " .. "T0", servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Cord of Elements
                { id = 16735,                                    disc = L["Warrior"] .. ", " .. "T0", servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } }, -- Bracers of Valor
                { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
                { id = 24102,                                    disc = L["Book"],                dropRate = 10 },               -- Manual of Eviscerate IX
                {},
                { id = 16247,                                    dropRate = 3 },                                                 -- Formula: Enchant 2H Weapon - Superior Impact
            }
        },
        { name = LIS["Ironweave Battlesuit"], items = "Ironweave" },
        { name = LIS["Dal'Rend's Arms"],      items = "DalRend" },
        { name = L["Tier 0/0.5 Sets"],        items = "AtlasCFMLootT0SetMenu" },
    }
}

-- Initialize items for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.BlackrockSpireUpper.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
