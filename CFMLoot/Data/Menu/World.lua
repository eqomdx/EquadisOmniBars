---
--- World.lua - World boss loot system
---
--- This module handles world boss loot tables and menu systems for Atlas-CFM.
--- It provides access to outdoor raid bosses, world dragons, and other rare
--- spawns with their unique loot tables and spawn information.
---
--- Features:
--- • World boss loot catalogs
--- • Spawn location information
--- • Rare drop tracking
--- • Cross-zone boss organization
--- • Integration with Babble localization
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()

AtlasCFM = _G.AtlasCFM
AtlasCFM.MenuData = AtlasCFM.MenuData or {}

local L = AtlasCFM.Localization.UI
local LB = AtlasCFM.Localization.Bosses

AtlasCFM.MenuData.WorldBosses = {
    { name = LB["Azuregos"],                extra = "Azshara",                       icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Blue",     lootpage = "Azuregos" },
    { name = LB["Emeriss"],                 Extra = L["Various Locations"],          icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Green",    lootpage = "FourDragons" },
    { name = LB["Lethon"],                  Extra = L["Various Locations"],          icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Green",    lootpage = "FourDragons" },
    { name = LB["Taerar"],                  Extra = L["Various Locations"],          icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Green",    lootpage = "FourDragons" },
    { name = LB["Ysondre"],                 Extra = L["Various Locations"],          icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Green",    lootpage = "FourDragons" },
    {},
    { name = LB["Lord Kazzak"],             extra = "Blasted Lands",                 icon = "Interface\\Icons\\warlock_summon_doomguard",      lootpage = "LordKazzak" },
    { name = LB["Lady Hederine"],           extra = "Winterspring",                  icon = "Interface\\Icons\\spell_shadow_summonsuccubus",   lootpage = "LadyHederine",       servers = { AtlasCFM.Server.VANILLA_PLUS } },
    { name = LB["Kurinnaxx"],               extra = "Silithus",                      icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath",  lootpage = "Kurinnaxx",          servers = { AtlasCFM.Server.VANILLA_PLUS } },
    { name = LB["King Mosh"],               extra = "Un'goro Crater",                icon = "Interface\\Icons\\Ability_Druid_FerociousBite",   lootpage = "KingMosh",           servers = { AtlasCFM.Server.VANILLA_PLUS } },
    { name = LB["Teremus the Devourer"],    extra = "Blasted Lands",                 icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",    lootpage = "TeremustheDevourer", servers = { AtlasCFM.Server.VANILLA_PLUS } },
    { name = LB["Nerubian Overseer"],       extra = "Eastern Plaguelands",           icon = "Interface\\Icons\\Spell_Nature_Web",              lootpage = "Nerubian",           servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LB["Dark Reaver of Karazhan"], extra = "Deadwind Pass",                 icon = "Interface\\Icons\\Ability_Mount_Dreadsteed",      lootpage = "Reaver",             servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LB["Ostarius"],                extra = "Tanaris",                       icon = "Interface\\Icons\\INV_Misc_Platnumdisks",         lootpage = "Ostarius",           servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LB["Concavius"],               extra = "Desolace",                      icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", lootpage = "Concavius",          servers = { AtlasCFM.Server.TURTLE1 } },
    {},
    { name = LB["Moo"],                     extra = "Moomoo Grove",                  icon = "Interface\\Icons\\Spell_Nature_Polymorph_Cow",    lootpage = "CowKing",            servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LB["Cla'ckora"],               extra = "Azshara",                       icon = "Interface\\Icons\\INV_Misc_Birdbeck_02",          lootpage = "Clackora",           servers = { AtlasCFM.Server.TURTLE } },
    { name = L["Rare Mobs"],                Extra = L["Various Locations"],          icon = "Interface\\Icons\\INV_Misc_Head_Undead_01",       lootpage = "RareMobs",           servers = { AtlasCFM.Server.TURTLE1 } },
    { name = L["Weapon Skills"],            icon = "Interface\\Icons\\INV_Sword_04", lootpage = "AtlasCFMLootWeaponSkillsMenu" },
}

---
-- Display the World Bosses menu in AtlasCFMLoot
-- @function AtlasCFMLoot_WorldMenu
-- @usage AtlasCFMLoot_WorldMenu()
---
function AtlasCFMLoot_WorldMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(L["World"], AtlasCFM.MenuData.WorldBosses)
end
