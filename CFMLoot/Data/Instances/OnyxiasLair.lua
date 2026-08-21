---
--- OnyxiasLair.lua - Onyxia's Lair raid instance loot data
---
--- This module contains comprehensive loot tables and boss data for Onyxia's Lair
--- 40-player raid instance. It includes the single boss encounter with
--- tier set items, rare drops, and the legendary Onyxia Scale Cloak.
---
--- Features:
--- • Complete Onyxia boss encounter
--- • Tier set head pieces
--- • Rare and epic weapon drops
--- • Legendary cloak materials
--- • Attunement quest items
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

AtlasCFM.InstanceData.OnyxiasLair = {
    Name = LZ["Onyxia's Lair"],
    Location = LZ["Dustwallow Marsh"],
    Level = 60,
    Acronym = "Ony",
    Attunement = true,
    MaxPlayers = 40,
    DamageType = L["Fire"],
    Entrances = {
        { letter = "A) " .. L["Entrance"] }
    },
    Bosses = {
        {
            id = "Onyxia",
            prefix = "1)",
            name = LB["Onyxia"],
            defaults = { dropRate = 13 },
            loot = {
                { id = 16921, container = { { 47206, servers = { AtlasCFM.Server.TURTLE1 } }, { 33008, servers = { AtlasCFM.Server.TURTLE } } },  servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Halo of Transcendence
                { id = 16914, container = { { 47086, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Netherwind Crown
                { id = 16929, container = { { 47284, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Nemesis Skullcap
                { id = 16908, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                                                       -- Bloodfang Hood
                { id = 16900, container = { { 47346, servers = { AtlasCFM.Server.TURTLE1 } }, { 47354, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Stormrage Cover
                { id = 16939, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                                                                                                                                       -- Dragonstalker's Helm
                { id = 16947, container = { { 47136, servers = { AtlasCFM.Server.TURTLE1 } }, { 47144, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Visor of Ten Storms
                { id = 16955, container = { { 47016, servers = { AtlasCFM.Server.TURTLE1 } }, { 47024, servers = { AtlasCFM.Server.TURTLE1 } } }, servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Judgement Helm
                { id = 16963, container = { { 47248, servers = { AtlasCFM.Server.TURTLE1 } } },                                                   servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },                                   -- Helm of Wrath
                { id = 34348, dropRate = 33,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },                                       -- Burnt Hood
                { id = 34340, dropRate = 33,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },                                       -- Charred Headpiece
                { id = 34332, dropRate = 33,                                                                                                      servers = { AtlasCFM.Server.VANILLA_PLUS } },                                       -- Melted Helmet
                {},
                { id = 18205, dropRate = 25 },                                                                                                                                                                                        -- Eskhandar's Collar
                { id = 17078, dropRate = 25 },                                                                                                                                                                                        -- Sapphiron Drape
                { id = 17067, dropRate = 25 },                                                                                                                                                                                        -- Ancient Cornerstone Grimoire
                {},
                { id = 18705, dropRate = 40,                                                                                                      container = { 18714, 18713, 18715 } },                                              -- Mature Black Dragon Sinew
                { id = 18423, dropRate = 100,                                                                                                     container = { 18403, 18404, 18406, 15138 } },                                       -- Head of Onyxia (Alliance)
                { id = 18422, dropRate = 100,                                                                                                     container = { 18403, 18404, 18406, 15138 } },                                       -- Head of Onyxia (Horde)
                {},
                { id = 18813, dropRate = 25 },                                                                                                                                                                                        -- Ring of Binding
                { id = 17064, dropRate = 8 },                                                                                                                                                                                         -- Shard of the Scale
                {},
                { id = 17068, dropRate = 8 },                                                                                                                                                                                         -- Deathbringer
                { id = 17075, dropRate = 8 },                                                                                                                                                                                         -- Vis'kag the Bloodletter
                {},
                { id = 17966, dropRate = 100 },                                                                                                                                                                                       -- Onyxia Hide Backpack
                { id = 15410, disc = L["Reagent"],                                                                                                dropRate = 100,                                container = { 17967, 15138, 15141 } }, -- Scale of Onyxia
                {},
                { id = 26243, dropRate = 1,                                                                                                       servers = { AtlasCFM.Server.VANILLA_PLUS } },                                       -- Stave of Errant Vision
                { id = 30017, dropRate = 1.5,                                                                                                     servers = { AtlasCFM.Server.TURTLE1 } },                                            --Onyxian Drake
                {},
                { id = 21108, disc = L["Quest Item"],                                                                                             dropRate = 100,                                container = { 21111 } },             -- Draconic for Dummies
                { id = 17962, disc = L["Container"],                                                                                              dropRate = 20,                                 container = { 13926, 7971, 3864, 55251, 55250, 7910, 7909, 1529, 12361 },                                                                                      servers = { AtlasCFM.Server.TURTLE1 } }, -- Blue Sack of Gems
                { id = 17963, disc = L["Container"],                                                                                              dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12364 } }, -- Green Sack of Gems
                { id = 17964, disc = L["Container"],                                                                                              dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12800 } }, -- Gray Sack of Gems
                { id = 17965, disc = L["Container"],                                                                                              dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12363 } }, -- Yellow Sack of Gems
                { id = 17969, disc = L["Container"],                                                                                              dropRate = 20,                                 container = { 13926, 7971, { 55250, servers = { AtlasCFM.Server.TURTLE1 } }, 7909, 3864, { 55251, servers = { AtlasCFM.Server.TURTLE1 } }, 7910, 1529, 12799 } }, -- Red Sack of Gems
            }
        },
        {
            id = "BroodcommanderAxelus",
            servers = { AtlasCFM.Server.TURTLE },
            prefix = "2)",
            name = LB["Broodcommander Axelus"],
            defaults = { dropRate = 16 },
            loot = {
                { id = 33087 },               -- Libram of Ardour
                { id = 33089 },               -- Totem of Thundercall
                { id = 33098, dropRate = 8 }, -- Idol of Equilibrium
                { id = 33149 },               -- Battle Standard of the Broodcommander
                { id = 33150 },               -- Yoxtez, Black Breath of the Dragonflight
                { id = 33151 },               -- Onyxian Brood Egg
                { id = 33152 },               -- Prestor's Rod of Command
                { id = 33153 },               -- Ignited Obsidian Scale
                { id = 33154 },               -- Ring of Burning Talons
                { id = 33155 },               -- Scaleshield of Obsidian Flight
                { id = 33156 },               -- Dragonhunter Javelin
                { id = 33157 },               -- Broodwarden's Bulwarkblade
            }
        }
    }
}

for _, bossData in ipairs(AtlasCFM.InstanceData.OnyxiasLair.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil
end
