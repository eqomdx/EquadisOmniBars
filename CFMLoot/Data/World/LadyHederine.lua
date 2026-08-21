---
--- LadyHederine.lua - Lady Hederine world boss loot data
---
--- This module contains comprehensive loot data for Lady Hederine, the demon
--- world boss located in the Winterspring. It includes rare drops,
--- epic equipment, and unique demonic items.
---
--- Features:
--- • Complete Lady Hederine loot table
--- • Rare and epic drops
--- • Demonic-themed equipment
--- • Unique world boss rewards
--- • Respawn timer information
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses
local LS = AtlasCFM.Localization.Spells

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

-- World boss Lady Hederine data
AtlasCFM.InstanceData.LadyHederine = {
    servers = { AtlasCFM.Server.VANILLA_PLUS },
    Name = LB["Lady Hederine"],
    Location = LZ["Winterspring"],
    Level = { 1, 60 },
    Acronym = "LadyHederine",
    MaxPlayers = 40,
    DamageType = L["Nature"],
    Bosses = {
        {
            id = "WBLadyHederine",
            prefix = "1)",
            name = LB["Lady Hederine"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 26127 }, -- Soul Shard Pendant
                { id = 26128 }, -- Hederine Whipping Belt
                { id = 26129 }, -- Helm of the Fallen Hero
                { id = 26130 }, -- Hederine Shackles
                { id = 26131 }, -- Gyves of Perdition
                { id = 26132 }, -- Sayaad Wings
                { id = 26133 }, -- Ring of Suffering
                { id = 26134 }, -- Demonic Claw
            }
        }
    },
}

-- Item initialization for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.LadyHederine.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
