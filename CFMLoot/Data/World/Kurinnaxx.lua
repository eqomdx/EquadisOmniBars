---
--- Kurinnaxx.lua - Kurinnaxx world boss loot data
---
--- This module contains comprehensive loot data for Kurinnaxx, the demon
--- world boss located in the Silithus. It includes rare drops,
--- epic equipment, and unique demonic items.
---
--- Features:
--- • Complete Kurinnaxx loot table
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

-- World boss Lord Kazzak data
AtlasCFM.InstanceData.Kurinnaxx = {
    servers = { AtlasCFM.Server.VANILLA_PLUS },
    Name = LB["Kurinnaxx"],
    Location = LZ["Silithus"],
    Level = { 1, 60 },
    Acronym = "Kurinnaxx",
    MaxPlayers = 40,
    DamageType = L["Nature"],
    Bosses = {
        {
            id = "WBKurinnaxx",
            prefix = "1)",
            name = LB["Kurinnaxx"],
            defaults = { dropRate = 17 },
            loot = {
                { id = 21651 }, -- Scaled Sand Reaver Leggings
                { id = 26022 }, -- Spiked Carapace Fragment
                { id = 21685 }, -- Petrified Scarab
                { id = 21635 }, -- Barb of the Sand Reaver
                { id = 21647 }, -- Fetish of the Sand Reaver
                { id = 21488 }, -- Fetish of Chitinous Spikes
                { id = 21467 }, -- Thick Silithid Chestguard
                { id = 21664 }, -- Barbed Choker
                { id = 21673 }, -- Silithid Claw
                { id = 21688 }, -- Boots of the Fallen Hero
                { id = 21501 }, -- Toughened Silithid Hide Gloves
                { id = 21479 }, -- Gauntlets of the Immovable
                {},
                { id = 26023 }, -- Sharp Bone of the Sand Reaver
            }
        }
    },
}

-- Item initialization for all bosses
for _, bossData in ipairs(AtlasCFM.InstanceData.Kurinnaxx.Bosses) do
    bossData.items = bossData.items or AtlasCFM.CreateItemsFromLootTable(bossData)
    bossData.loot = nil -- Clear temporary data
end
