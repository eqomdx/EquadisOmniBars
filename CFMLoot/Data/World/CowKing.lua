---
--- CowKing.lua - Cow King special boss loot data
---
--- This module contains loot data for the Cow King, a special easter egg
--- boss encounter. It includes unique drops, humorous items, and
--- special rewards from this hidden encounter.
---
--- Features:
--- • Complete Cow King loot table
--- • Easter egg items
--- • Humorous equipment
--- • Special encounter rewards
--- • Hidden boss mechanics
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
AtlasCFM.InstanceData.CowKing = {
    Servers = { AtlasCFM.Server.TURTLE1 },
    Name = LB["Moo"],
    Location = LZ["Moomoo Grove"],
    Level = { 1, 60 },
    Acronym = "CowKing",
    MaxPlayers = 20,
    DamageType = L["Physical"],
    Bosses = {
        {
            id = "WBCowKing",
            prefix = "1)",
            name = LB["Moo"],
            defaults = { dropRate = 50 },
            loot = {
                { id = 60486, dropRate = 25 },                    -- Fishbringer
                {},
                { id = 60487, },                                  -- Cloak of the Moo Lord
                { id = 60488 },                                   -- Drape of the Herd
                { id = 60489 },                                   -- Cap of the Cow Savant
                { id = 60490 },                                   -- Cowskin Chapeau
                {},
                { id = 4144,  disc = L["Book"], dropRate = 100 }, -- Tome of Polymorph: Cow
                {},
                { id = 60485, disc = L["Misc"], dropRate = 100 }, -- Sealed Diablo II Lord of Destruction Collectors Edition
                { id = 60491, disc = L["Misc"], dropRate = 100 }, -- The Moo Stone
                {},
                { id = 51261, dropRate = 100 },                   -- Little Cow
            },
        }
    }
}

-- Item initialization for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.CowKing.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
