---
--- PvP.lua - PvP rewards and battleground loot system
---
--- This module handles PvP-related loot tables and menu systems for Atlas-CFM.
--- It provides access to battleground rewards, PvP armor sets, weapons, and accessories
--- organized by rank requirements and battleground locations.
---
--- Features:
--- • Battleground-specific reward catalogs
--- • PvP rank requirement tracking
--- • Honor system integration
--- • Cross-battleground item organization
--- • Faction-specific PvP rewards
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()

AtlasCFM = _G.AtlasCFM
AtlasCFM.MenuData = AtlasCFM.MenuData or {}

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LC = AtlasCFM.Localization.Classes

local Colors = AtlasCFM.Colors

AtlasCFM.MenuData.PVP = {
    {},
    {},
    { servers = { AtlasCFM.Server.NOT_VANILLA_PLUS } },
    { name = LZ["Azshara Crater"],                   icon = "Interface\\Icons\\INV_Misc_Gem_Crystal_02", lootpage = "AzsharaCrater",                           servers = { AtlasCFM.Server.VANILLA_PLUS } }, --Vanilla+
    { name = LZ["Alterac Valley"],                   icon = "Interface\\Icons\\INV_Jewelry_Necklace_21", lootpage = "StormpikeFrostwolf" },
    { name = LZ["Arathi Basin"],                     icon = "Interface\\Icons\\INV_Jewelry_Amulet_07",   lootpage = "ArathorDefilers" },
    { name = LZ["Warsong Gulch"],                    icon = "Interface\\Icons\\INV_Misc_Rune_07",        lootpage = "SentinelsOutriders" },
    { servers = { AtlasCFM.Server.CLASSIC } },
    { name = LZ["Blood Ring"],                       icon = "Interface\\Icons\\inv_jewelry_ring_04",     lootpage = "SteamwheedleBloodRing",                   servers = { AtlasCFM.Server.TURTLE1 } },      --1.17.2
    { name = L["Crimson Ring"],                      icon = "Interface\\Icons\\INV_Jewelry_Necklace_38", lootpage = "CrimsonRing",                             servers = { AtlasCFM.Server.VANILLA_PLUS } }, --Vanilla+
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
    { name = L["PvP Mounts"],                        Extra = L["Rank"] .. " 11",                         icon = "Interface\\Icons\\Ability_Mount_RidingHorse", lootpage = "PvPMountsPvP" },
    { name = L["PvP Accessories"],                   Extra = L["Rank"] .. " 2-9",                        icon = "Interface\\Icons\\INV_Jewelry_Talisman_09",   lootpage = "PvP60Accessories" },
    { name = L["PvP Armor Sets"],                    icon = "Interface\\Icons\\INV_Helmet_03",           lootpage = "AtlasCFMLootPVPSetMenu" },
    { name = L["PvP Weapons"],                       icon = "Interface\\Icons\\INV_Sword_11",            lootpage = "PVPWeapons1181",                          servers = { AtlasCFM.Server.TURTLE } },
    { name = L["PvP Weapons"],                       icon = "Interface\\Icons\\INV_Sword_11",            lootpage = "PVPWeapons",                              servers = { AtlasCFM.Server.NOT_TURTLE } },

}

---
--- Displays the main PvP rewards menu
--- Shows battleground locations, PvP mounts, accessories, armor sets, and weapons
--- @return nil
--- @usage AtlasCFMLootPvPMenu()
---
function AtlasCFMLootPvPMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(L["PvP Rewards"], AtlasCFM.MenuData.PVP)
end

AtlasCFM.MenuData.PVPSets = {
    {},
    {},
    { name = Colors.Priest .. LC["Priest"],   icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",   lootpage = "PVPPriest",      servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Mage .. LC["Mage"],       icon = "Interface\\Icons\\Spell_Frost_IceStorm",         lootpage = "PVPMage",        servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Warlock .. LC["Warlock"], icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",  lootpage = "PVPWarlock",     servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Rogue .. LC["Rogue"],     icon = "Interface\\Icons\\Ability_BackStab",             lootpage = "PVPRogue",       servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Druid .. LC["Druid"],     icon = "Interface\\Icons\\Spell_Nature_Regeneration",    lootpage = "PVPDruid",       servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Priest .. LC["Priest"],   icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",   lootpage = "PVPPriest1181",  servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Mage .. LC["Mage"],       icon = "Interface\\Icons\\Spell_Frost_IceStorm",         lootpage = "PVPMage1181",    servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Warlock .. LC["Warlock"], icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",  lootpage = "PVPWarlock1181", servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Rogue .. LC["Rogue"],     icon = "Interface\\Icons\\Ability_BackStab",             lootpage = "PVPRogue1181",   servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Druid .. LC["Druid"],     icon = "Interface\\Icons\\Spell_Nature_Regeneration",    lootpage = "PVPDruid1181",   servers = { AtlasCFM.Server.TURTLE } },
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
    { name = Colors.Hunter .. LC["Hunter"],   icon = "Interface\\Icons\\Ability_Hunter_RunningShot",   lootpage = "PVPHunter",      servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Shaman .. LC["Shaman"],   icon = "Interface\\Icons\\Spell_FireResistanceTotem_01", lootpage = "PVPShaman",      servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Paladin .. LC["Paladin"], icon = "Interface\\Icons\\Spell_Holy_SealOfMight",       lootpage = "PVPPaladin",     servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Warrior .. LC["Warrior"], icon = "Interface\\Icons\\INV_Shield_05",                lootpage = "PVPWarrior",     servers = { AtlasCFM.Server.NOT_TURTLE } },
    { name = Colors.Hunter .. LC["Hunter"],   icon = "Interface\\Icons\\Ability_Hunter_RunningShot",   lootpage = "PVPHunter1181",  servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Shaman .. LC["Shaman"],   icon = "Interface\\Icons\\Spell_FireResistanceTotem_01", lootpage = "PVPShaman1181",  servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Paladin .. LC["Paladin"], icon = "Interface\\Icons\\Spell_Holy_SealOfMight",       lootpage = "PVPPaladin1181", servers = { AtlasCFM.Server.TURTLE } },
    { name = Colors.Warrior .. LC["Warrior"], icon = "Interface\\Icons\\INV_Shield_05",                lootpage = "PVPWarrior1181", servers = { AtlasCFM.Server.TURTLE } },
}

---
--- Displays the PvP armor sets menu organized by class
--- @return nil
--- @usage AtlasCFMLootPVPSetMenu()
---
function AtlasCFMLootPVPSetMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(L["PvP Armor Sets"], AtlasCFM.MenuData.PVPSets, L["PvP Rewards"])
end
