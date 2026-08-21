---
--- Crafting.lua - Crafting professions menu and data management
---
--- This module provides comprehensive crafting profession support for Atlas-CFM,
--- organizing all tradeskill-related loot tables and profession menus.
--- It handles the display and navigation of crafting recipes, materials,
--- and profession-specific items across all available tradeskills.
---
--- Features:
--- • Complete profession menu structure
--- • Tradeskill categorization and organization
--- • Recipe and material data management
--- • Integration with Babble localization libraries
--- • Support for all classic WoW professions
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()

AtlasCFM = _G.AtlasCFM
AtlasCFM.MenuData = AtlasCFM.MenuData or {}

local L = AtlasCFM.Localization.UI
local LC = AtlasCFM.Localization.Classes
local LS = AtlasCFM.Localization.Spells
local LIS = AtlasCFM.Localization.ItemSets

local RED = AtlasCFM.Colors.RED

AtlasCFM.MenuData.Crafting = {
    { name = LS["Alchemy"],                             icon = "Interface\\Icons\\Trade_Alchemy",              lootpage = "AtlasCFMLoot_AlchemyMenu" },
    { name = LS["Blacksmithing"],                       icon = "Interface\\Icons\\Trade_BlackSmithing",        lootpage = "AtlasCFMLoot_SmithingMenu" },
    { name = LS["Enchanting"],                          icon = "Interface\\Icons\\Trade_Engraving",            lootpage = "AtlasCFMLoot_EnchantingMenu" },
    { name = LS["Engineering"],                         icon = "Interface\\Icons\\Trade_Engineering",          lootpage = "AtlasCFMLoot_EngineeringMenu" },
    { name = LS["Leatherworking"],                      icon = "Interface\\Icons\\INV_Misc_ArmorKit_17",       lootpage = "AtlasCFMLoot_LeatherworkingMenu" },
    { name = LS["Tailoring"],                           icon = "Interface\\Icons\\Trade_Tailoring",            lootpage = "AtlasCFMLoot_TailoringMenu" },
    { name = LS["Jewelcrafting"],                       icon = "Interface\\Icons\\INV_Jewelry_Necklace_11",    lootpage = "AtlasCFMLoot_JewelcraftingMenu", servers = { AtlasCFM.Server.TURTLE1 } },
    {},
    { name = LS["Mining"] .. ", " .. LS["Smelting"],    icon = "Interface\\Icons\\Trade_Mining",               lootpage = "AtlasCFMLoot_MiningMenu" },
    { name = LS["Cooking"],                             icon = "Interface\\Icons\\INV_Misc_Food_15",           lootpage = "AtlasCFMLoot_CookingMenu" },
    { name = LS["First Aid"],                           icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", lootpage = "AtlasCFMLoot_FirstAidMenu" },
    { name = LS["Herbalism"],                           icon = "Interface\\Icons\\Trade_Herbalism",            lootpage = "AtlasCFMLoot_HerbalismMenu" },
    { name = LS["Survival"] .. ", " .. LS["Gardening"], icon = "Interface\\Icons\\Trade_Survival",             lootpage = "AtlasCFMLoot_SurvivalMenu",      servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LS["Fishing"],                             icon = "Interface\\Icons\\Trade_Fishing",              lootpage = "AtlasCFMLoot_FishingMenu" },
    { name = LS["Skinning"],                            icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",      lootpage = "AtlasCFMLoot_SkinningMenu" },
    { name = LC["Rogue"] .. " " .. L["Special"],        icon = "Interface\\Icons\\Trade_BrewPoison",           lootpage = "AtlasCFMLoot_PoisonsMenu" },
    {},
    { name = L["Crafted Sets"],                         icon = "Interface\\Icons\\INV_Box_01",                 lootpage = "AtlasCFMLootCraftedSetMenu" },
    {},
    { name = L["Crafted Epic Weapons"],                 icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras", lootpage = "CraftedWeapons" },
}

---
--- Displays the crafting professions menu in AtlasCFMLoot
--- Shows all available crafting professions and their loot tables
--- @return nil
--- @usage AtlasCFMLoot_CraftingMenu() -- Show crafting menu

function AtlasCFMLoot_CraftingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(L["Crafting"], AtlasCFM.MenuData.Crafting)
end

AtlasCFM.MenuData.CraftedSet = {
    { name = RED .. LS["Tailoring"] .. " - " .. LS["Cloth"],        icon = "Interface\\Icons\\INV_Chest_Cloth_21",       isheader = true }, -- use cloth in name coz resolve navigation problem same name with parrent Tailoring page
    { name = LIS["Augerer's Attire"],                               icon = "Interface\\Icons\\INV_Helmet_11",            lootpage = "AugerersAttire",                   servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Diviner's Garments"],                             icon = "Interface\\Icons\\INV_Helmet_33",            lootpage = "DivinersGarments",                 servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Pillager's Garb"],                                icon = "Interface\\Icons\\INV_Helmet_28",            lootpage = "PillagersGarb",                    servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Mooncloth Regalia"],                              icon = "Interface\\Icons\\inv_misc_bandana_01",      lootpage = "MoonclothRegalia" },
    { name = LIS["Bloodvine Garb"],                                 icon = "Interface\\Icons\\INV_Pants_Cloth_14",       lootpage = "BloodvineG" },
    { name = LIS["Flarecore Regalia"],                              icon = "Interface\\Icons\\inv_chest_cloth_18",       lootpage = "FlarecoreRegalia" },
    { name = LIS["Dreamthread Regalia"],                            icon = "Interface\\Icons\\INV_Gauntlets_23",         lootpage = "DreamthreadRegalia",               servers = { AtlasCFM.Server.TURTLE1 } },
    {},
    { name = RED .. LS["Leatherworking"] .. " - " .. LS["Mail"],    icon = "Interface\\Icons\\INV_Chest_Chain_12",       isheader = true },
    { name = LIS["Red Dragon Mail"],                                Extra = L["Fire Resistance Gear"],                   icon = "Interface\\Icons\\inv_chest_chain_06", lootpage = "RedDragonM",                                            servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Green Dragon Mail"],                              Extra = L["Nature Resistance Gear"],                 icon = "Interface\\Icons\\INV_Pants_05",       lootpage = "GreenDragonM" },
    { name = LIS["Blue Dragon Mail"],                               Extra = L["Arcane Resistance Gear"],                 icon = "Interface\\Icons\\INV_Chest_Chain_04", lootpage = "BlueDragonM",                                           servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Black Dragon Mail"],                              Extra = L["Fire Resistance Gear"],                   icon = "Interface\\Icons\\INV_Pants_03",       lootpage = "BlackDragonM" },
    {},
    { name = RED .. LS["Leatherworking"] .. " - " .. LS["Leather"], icon = "Interface\\Icons\\INV_Chest_Leather_04",     isheader = true },
    { name = LIS["Grifter's Armor"],                                icon = "Interface\\Icons\\INV_Helmet_33",            lootpage = "GriftersArmor",                    servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Primalist's Trappings"],                          icon = "Interface\\Icons\\Inv_Chest_Plate06",        lootpage = "PrimalistsTrappings",              servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Volcanic Armor"],                                 Extra = L["Fire Resistance Gear"],                   icon = "Interface\\Icons\\INV_Pants_06",       lootpage = "VolcanicArmor" },
    { name = LIS["Ironfeather Armor"],                              icon = "Interface\\Icons\\INV_Chest_Leather_06",     lootpage = "IronfeatherArmor" },
    { name = LIS["Stormshroud Armor"],                              icon = "Interface\\Icons\\INV_Chest_Leather_08",     lootpage = "StormshroudArmor" },
    { name = LIS["Devilsaur Armor"],                                icon = "Interface\\Icons\\INV_Pants_Wolf",           lootpage = "DevilsaurArmor" },
    { name = LIS["Blood Tiger Harness"],                            icon = "Interface\\Icons\\INV_Shoulder_23",          lootpage = "BloodTigerH" },
    { name = LIS["Primal Batskin"],                                 icon = "Interface\\Icons\\INV_Chest_Leather_03",     lootpage = "PrimalBatskin" },
    { name = LIS["Convergence of the Elements"],                    icon = "Interface\\Icons\\INV_Helmet_13",            lootpage = "ConvergenceoftheElements",         servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Dreamhide Battlegarb"],                           icon = "Interface\\Icons\\inv_shoulder_18",          lootpage = "DreamhideBattlegarb",              servers = { AtlasCFM.Server.TURTLE1 } },
    {},
    { name = RED .. LS["Blacksmithing"] .. " - " .. LS["Plate"],    icon = "Interface\\Icons\\INV_Chest_Chain_04",       isheader = true },
    { name = LIS["Steel Plate Armor"],                              icon = "Interface\\Icons\\INV_Helmet_25",            lootpage = "SteelPlate",                       servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Imperial Plate"],                                 icon = "Interface\\Icons\\INV_Belt_01",              lootpage = "ImperialPlate" },
    { name = LIS["The Darksoul"],                                   icon = "Interface\\Icons\\INV_Shoulder_01",          lootpage = "TheDarksoul",                      servers = { AtlasCFM.Server.CLASSIC, AtlasCFM.Server.VANILLA_PLUS } },
    { name = RED .. LS["Blacksmithing"] .. " - " .. LS["Mail"],     icon = "Interface\\Icons\\INV_Chest_Chain_04",       isheader = true },
    { name = LIS["Bloodsoul Embrace"],                              icon = "Interface\\Icons\\INV_Shoulder_15",          lootpage = "BloodsoulEmbrace" },
    { name = LIS["Hateforge Armor"],                                icon = "Interface\\Icons\\INV_Helmet_10",            lootpage = "HateforgeArmor",                   servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Towerforge Battlegear"],                          icon = "Interface\\Icons\\INV_Helmet_37",            lootpage = "TowerforgeBattlegear",             servers = { AtlasCFM.Server.TURTLE1 } },
    {},
    { name = RED .. LS["Jewelcrafting"],                            icon = "Interface\\Icons\\INV_Chest_Chain_04",       isheader = true,                               servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Midnight Regalia"],                               icon = "Interface\\Icons\\BTNBlackPendant",          lootpage = "MidnightRegalia",                  servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Goldmaster's Jewelry"],                           icon = "Interface\\Icons\\INV_Jewelry_Ring_Emerald", lootpage = "GoldmastersJewelry",               servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Aquamarine Jewelry"],                             icon = "Interface\\Icons\\INV_Jewelry_Necklace_03",  lootpage = "AquamarineJewelry",                servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Ornate Mithril Jewelry"],                         icon = "Interface\\Icons\\INV_Bracer_14",            lootpage = "OrnateMithrilJewelry",             servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Spellweaver's Accessories"],                      icon = "Interface\\Icons\\INV_Staff_13",             lootpage = "SpellweaversAccessories",          servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Stormcloud Jewelry"],                             icon = "Interface\\Icons\\INV_Jewelry_Ring_Saphire", lootpage = "StormcloudJewelry",                servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Mastercrafted Diamond Jewelry"],                  icon = "Interface\\Icons\\INV_Crown_02",             lootpage = "MastercraftedDiamondJewelry",      servers = { AtlasCFM.Server.TURTLE1 } },
    {},
    {},
    { name = LIS["Rune-Etched Armor"],                              icon = "Interface\\Icons\\inv_helmet_06",            lootpage = "RuneEtchedArmor",                  servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["The Darksoul"],                                   icon = "Interface\\Icons\\INV_Shoulder_01",          lootpage = "TheDarksoul",                      servers = { AtlasCFM.Server.TURTLE1 } },
    { name = LIS["Dreamsteel Armor"],                               icon = "Interface\\Icons\\INV_Bracer_03",            lootpage = "DreamsteelArmor",                  servers = { AtlasCFM.Server.TURTLE1 } },
}

---
--- Opens the Crafted Sets menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLootCraftedSetMenu()

function AtlasCFMLootCraftedSetMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(L["Crafted Sets"], AtlasCFM.MenuData.CraftedSet, L["Crafting"])
end

AtlasCFM.MenuData.Alchemy = {
    { name = LS["Alchemy"] .. ": " .. L["Apprentice"],                    lootpage = "AlchemyApprentice" },
    { name = LS["Alchemy"] .. ": " .. L["Journeyman"],                    lootpage = "AlchemyJourneyman" },
    { name = LS["Alchemy"] .. ": " .. L["Expert"],                        lootpage = "AlchemyExpert" },
    { name = LS["Alchemy"] .. ": " .. L["Artisan"],                       lootpage = "AlchemyArtisan" },
    {},
    { name = LS["Alchemy"] .. ": " .. L["Flasks"],                        lootpage = "AlchemyFlasks" },
    { name = LS["Alchemy"] .. ": " .. L["Protection Potions"],            lootpage = "AlchemyProtectionPots" },
    { name = LS["Alchemy"] .. ": " .. L["Healing and Mana Potions"],      lootpage = "AlchemyHealingAndMana" },
    { name = LS["Alchemy"] .. ": " .. L["Transmutes"],                    lootpage = "AlchemyTransmutes" },
    { name = LS["Alchemy"] .. ": " .. L["Defensive Potions and Elixirs"], lootpage = "AlchemyDefensive" },
    { name = LS["Alchemy"] .. ": " .. L["Offensive Potions and Elixirs"], lootpage = "AlchemyOffensive" },
    { name = LS["Alchemy"] .. ": " .. L["Miscellaneous"],                 lootpage = "AlchemyMisc" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Alchemy"],                      icon = "Interface\\Icons\\INV_Misc_Book_09", lootpage = "AlchemyTrainers" },
}

---
--- Opens the Alchemy crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_AlchemyMenu()
---
function AtlasCFMLoot_AlchemyMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Alchemy"], AtlasCFM.MenuData.Alchemy, L["Crafting"],
        "Interface\\Icons\\Trade_Alchemy")
end

AtlasCFM.MenuData.Smithing = {
    { name = LS["Blacksmithing"] .. ": " .. L["Apprentice"],         lootpage = "SmithingApprentice" },
    { name = LS["Blacksmithing"] .. ": " .. L["Journeyman"],         lootpage = "SmithingJourneyman" },
    { name = LS["Blacksmithing"] .. ": " .. L["Expert"],             lootpage = "SmithingExpert" },
    { name = LS["Blacksmithing"] .. ": " .. L["Artisan"],            lootpage = "SmithingArtisan" },
    {},
    { name = LS["Blacksmithing"] .. ": " .. LS["Armorsmith"],        icon = "Interface\\Icons\\INV_Chest_Plate04", lootpage = "Armorsmith" },
    { name = LS["Blacksmithing"] .. ": " .. LS["Weaponsmith"],       icon = "Interface\\Icons\\INV_Sword_25",      lootpage = "Weaponsmith" },
    { name = LS["Blacksmithing"] .. ": " .. L["Master Axesmith"],    icon = "Interface\\Icons\\INV_Axe_05",        lootpage = "Axesmith" },
    { name = LS["Blacksmithing"] .. ": " .. L["Master Hammersmith"], icon = "Interface\\Icons\\INV_Hammer_23",     lootpage = "Hammersmith" },
    { name = LS["Blacksmithing"] .. ": " .. L["Master Swordsmith"],  icon = "Interface\\Icons\\INV_Sword_41",      lootpage = "Swordsmith" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Blacksmithing"],           icon = "Interface\\Icons\\INV_Misc_Book_09",  lootpage = "BlacksmithingTrainers" },
    {},
    {},
    {},
    { name = LS["Blacksmithing"] .. ": " .. L["Helm"],               lootpage = "SmithingHelm" },
    { name = LS["Blacksmithing"] .. ": " .. L["Shoulders"],          lootpage = "SmithingShoulders" },
    { name = LS["Blacksmithing"] .. ": " .. L["Chest"],              lootpage = "SmithingChest" },
    { name = LS["Blacksmithing"] .. ": " .. L["Bracers"],            lootpage = "SmithingBracers" },
    { name = LS["Blacksmithing"] .. ": " .. L["Gloves"],             lootpage = "SmithingGloves" },
    { name = LS["Blacksmithing"] .. ": " .. L["Belt"],               lootpage = "SmithingBelt" },
    { name = LS["Blacksmithing"] .. ": " .. L["Pants"],              lootpage = "SmithingPants" },
    { name = LS["Blacksmithing"] .. ": " .. L["Boots"],              lootpage = "SmithingBoots" },
    { name = LS["Blacksmithing"] .. ": " .. L["Belt Buckles"],       lootpage = "SmithingBuckles" },
    { name = LS["Blacksmithing"] .. ": " .. L["Axes"],               lootpage = "SmithingAxes" },
    { name = LS["Blacksmithing"] .. ": " .. L["Swords"],             lootpage = "SmithingSwords" },
    { name = LS["Blacksmithing"] .. ": " .. L["Maces"],              lootpage = "SmithingMaces" },
    { name = LS["Blacksmithing"] .. ": " .. L["Fist"],               lootpage = "SmithingFist" },
    { name = LS["Blacksmithing"] .. ": " .. L["Daggers"],            lootpage = "SmithingDaggers" },
    { name = LS["Blacksmithing"] .. ": " .. L["Misc"],               lootpage = "SmithingMisc" },
}

---
--- Opens the Blacksmithing crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_SmithingMenu()
---
function AtlasCFMLoot_SmithingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Blacksmithing"], AtlasCFM.MenuData.Smithing, L["Crafting"],
        "Interface\\Icons\\Trade_BlackSmithing")
end

AtlasCFM.MenuData.Enchanting = {
    { name = LS["Enchanting"] .. ": " .. L["Apprentice"], lootpage = "EnchantingApprentice" },
    { name = LS["Enchanting"] .. ": " .. L["Journeyman"], lootpage = "EnchantingJourneyman" },
    { name = LS["Enchanting"] .. ": " .. L["Expert"],     lootpage = "EnchantingExpert" },
    { name = LS["Enchanting"] .. ": " .. L["Artisan"],    lootpage = "EnchantingArtisan" },
    {},
    { name = LS["Enchanting"] .. ": " .. L["Cloak"],      lootpage = "EnchantingCloak" },
    { name = LS["Enchanting"] .. ": " .. L["Chest"],      lootpage = "EnchantingChest" },
    { name = LS["Enchanting"] .. ": " .. L["Bracers"],    lootpage = "EnchantingBracer" },
    { name = LS["Enchanting"] .. ": " .. L["Gloves"],     lootpage = "EnchantingGlove" },
    { name = LS["Enchanting"] .. ": " .. L["Boots"],      lootpage = "EnchantingBoots" },
    { name = LS["Enchanting"] .. ": " .. L["2H Weapon"],  lootpage = "Enchanting2HWeapon" },
    { name = LS["Enchanting"] .. ": " .. L["Weapon"],     lootpage = "EnchantingWeapon" },
    { name = LS["Enchanting"] .. ": " .. L["Shield"],     lootpage = "EnchantingShield" },
    { name = LS["Enchanting"] .. ": " .. L["Misc"],       lootpage = "EnchantingMisc" },
    {},
    { name = L["Disenchanting"],                          icon = "Interface\\Icons\\Spell_Holy_RemoveCurse", lootpage = "EnchantingDisenchant" },
    { name = L["Trainers"] .. ": " .. LS["Enchanting"],   icon = "Interface\\Icons\\INV_Misc_Book_09",       lootpage = "EnchantingTrainers" },
}

---
--- Opens the Enchanting crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_EnchantingMenu()

function AtlasCFMLoot_EnchantingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Enchanting"], AtlasCFM.MenuData.Enchanting, L["Crafting"],
        "Interface\\Icons\\Trade_Engraving")
end

AtlasCFM.MenuData.Engineering = {
    { name = LS["Engineering"] .. ": " .. L["Apprentice"], lootpage = "EngineeringApprentice" },
    { name = LS["Engineering"] .. ": " .. L["Journeyman"], lootpage = "EngineeringJourneyman" },
    { name = LS["Engineering"] .. ": " .. L["Expert"],     lootpage = "EngineeringExpert" },
    { name = LS["Engineering"] .. ": " .. L["Artisan"],    lootpage = "EngineeringArtisan" },
    {},
    { name = L["Gnomish Engineering"],                     icon = "Interface\\Icons\\INV_Gizmo_02",            lootpage = "Gnomish" },
    { name = L["Goblin Engineering"],                      icon = "Interface\\Icons\\Spell_Fire_Selfdestruct", lootpage = "Goblin" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Engineering"],   icon = "Interface\\Icons\\INV_Misc_Book_09",        lootpage = "EngineeringTrainers" },
    {},
    {},
    {},
    {},
    {},
    {},
    { name = LS["Engineering"] .. ": " .. L["Equipment"],  lootpage = "EngineeringEquipment" },
    { name = LS["Engineering"] .. ": " .. L["Trinkets"],   lootpage = "EngineeringTrinkets" },
    { name = LS["Engineering"] .. ": " .. L["Explosives"], lootpage = "EngineeringExplosives" },
    { name = LS["Engineering"] .. ": " .. L["Weapons"],    lootpage = "EngineeringWeapons" },
    { name = LS["Engineering"] .. ": " .. L["Parts"],      lootpage = "EngineeringParts" },
    { name = LS["Engineering"] .. ": " .. L["Misc"],       lootpage = "EngineeringMisc" },
}

---
--- Opens the Engineering crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_EngineeringMenu()

function AtlasCFMLoot_EngineeringMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Engineering"], AtlasCFM.MenuData.Engineering, L["Crafting"],
        "Interface\\Icons\\Trade_Engineering")
end

AtlasCFM.MenuData.Leatherworking = {
    { name = LS["Leatherworking"] .. ": " .. L["Apprentice"], lootpage = "LeatherApprentice" },
    { name = LS["Leatherworking"] .. ": " .. L["Journeyman"], lootpage = "LeatherJourneyman" },
    { name = LS["Leatherworking"] .. ": " .. L["Expert"],     lootpage = "LeatherExpert" },
    { name = LS["Leatherworking"] .. ": " .. L["Artisan"],    lootpage = "LeatherArtisan" },
    {},
    { name = LS["Dragonscale Leatherworking"],                icon = "Interface\\Icons\\INV_Misc_MonsterScales_03", lootpage = "Dragonscale" },
    { name = LS["Tribal Leatherworking"],                     icon = "Interface\\Icons\\Spell_Nature_NullWard",     lootpage = "Tribal" },
    { name = LS["Elemental Leatherworking"],                  icon = "Interface\\Icons\\Spell_Fire_Volcano",        lootpage = "Elemental" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Leatherworking"],   icon = "Interface\\Icons\\INV_Misc_Book_09",          lootpage = "LeatherworkingTrainers" },
    {},
    {},
    {},
    {},
    {},
    { name = LS["Leatherworking"] .. ": " .. L["Helm"],       lootpage = "LeatherHelm" },
    { name = LS["Leatherworking"] .. ": " .. L["Shoulders"],  lootpage = "LeatherShoulders" },
    { name = LS["Leatherworking"] .. ": " .. L["Cloak"],      lootpage = "LeatherCloak" },
    { name = LS["Leatherworking"] .. ": " .. L["Chest"],      lootpage = "LeatherChest" },
    { name = LS["Leatherworking"] .. ": " .. L["Bracers"],    lootpage = "LeatherBracers" },
    { name = LS["Leatherworking"] .. ": " .. L["Gloves"],     lootpage = "LeatherGloves" },
    { name = LS["Leatherworking"] .. ": " .. L["Belt"],       lootpage = "LeatherBelt" },
    { name = LS["Leatherworking"] .. ": " .. L["Pants"],      lootpage = "LeatherPants" },
    { name = LS["Leatherworking"] .. ": " .. L["Boots"],      lootpage = "LeatherBoots" },
    {},
    { name = LS["Leatherworking"] .. ": " .. L["Bags"],       lootpage = "LeatherBags" },
    { name = LS["Leatherworking"] .. ": " .. L["Misc"],       lootpage = "LeatherMisc" },
}

---
--- Opens the Leatherworking crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_LeatherworkingMenu()

function AtlasCFMLoot_LeatherworkingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Leatherworking"], AtlasCFM.MenuData.Leatherworking, L["Crafting"],
        "Interface\\Icons\\INV_Misc_ArmorKit_17")
end

AtlasCFM.MenuData.Mining = {
    { name = LS["Mining"],                          icon = "Interface\\Icons\\Trade_Mining",           lootpage = "MiningTable" },
    { name = LS["Smelting"],                        icon = "Interface\\Icons\\Spell_Fire_FlameBlades", lootpage = "Smelting" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Mining"], icon = "Interface\\Icons\\INV_Misc_Book_09",       lootpage = "MiningTrainers" },
}

---
--- Opens the Mining profession menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_MiningMenu()

function AtlasCFMLoot_MiningMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Mining"], AtlasCFM.MenuData.Mining, L["Crafting"],
        "Interface\\Icons\\Trade_Mining")
end

AtlasCFM.MenuData.Tailoring = {
    { name = LS["Tailoring"] .. ": " .. L["Apprentice"], lootpage = "TailoringApprentice" },
    { name = LS["Tailoring"] .. ": " .. L["Journeyman"], lootpage = "TailoringJourneyman" },
    { name = LS["Tailoring"] .. ": " .. L["Expert"],     lootpage = "TailoringExpert" },
    { name = LS["Tailoring"] .. ": " .. L["Artisan"],    lootpage = "TailoringArtisan" },
    {},
    { name = LS["Tailoring"] .. ": " .. L["Helm"],       lootpage = "TailoringHelm" },
    { name = LS["Tailoring"] .. ": " .. L["Shoulders"],  lootpage = "TailoringShoulders" },
    { name = LS["Tailoring"] .. ": " .. L["Cloak"],      lootpage = "TailoringCloak" },
    { name = LS["Tailoring"] .. ": " .. L["Chest"],      lootpage = "TailoringChest" },
    { name = LS["Tailoring"] .. ": " .. L["Bracers"],    lootpage = "TailoringBracers" },
    { name = LS["Tailoring"] .. ": " .. L["Gloves"],     lootpage = "TailoringGloves" },
    { name = LS["Tailoring"] .. ": " .. L["Belt"],       lootpage = "TailoringBelt" },
    { name = LS["Tailoring"] .. ": " .. L["Pants"],      lootpage = "TailoringPants" },
    { name = LS["Tailoring"] .. ": " .. L["Boots"],      lootpage = "TailoringBoots" },
    {},
    { name = LS["Tailoring"] .. ": " .. L["Shirt"],      lootpage = "TailoringShirt" },
    { name = LS["Tailoring"] .. ": " .. L["Bags"],       lootpage = "TailoringBags" },
    { name = LS["Tailoring"] .. ": " .. L["Misc"],       lootpage = "TailoringMisc" },
    {},
    { name = LS["Tailoring"] .. ": " .. LS["Cloth"],     icon = "Interface\\Icons\\INV_Fabric_Linen_01", lootpage = "ClothTable" },
    { name = L["Trainers"] .. ": " .. LS["Tailoring"],   icon = "Interface\\Icons\\INV_Misc_Book_09",    lootpage = "TailoringTrainers" },
}

---
--- Opens the Tailoring crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_TailoringMenu()

function AtlasCFMLoot_TailoringMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Tailoring"], AtlasCFM.MenuData.Tailoring, L["Crafting"],
        "Interface\\Icons\\Trade_Tailoring")
end

AtlasCFM.MenuData.Jewelcrafting = {
    { name = LS["Jewelcrafting"] .. ": " .. L["Apprentice"],    icon = "Interface\\Icons\\INV_Jewelry_Necklace_11", lootpage = "JewelcraftingApprentice" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Journeyman"],    icon = "Interface\\Icons\\INV_Jewelry_Necklace_11", lootpage = "JewelcraftingJourneyman" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Expert"],        icon = "Interface\\Icons\\INV_Jewelry_Necklace_11", lootpage = "JewelcraftingExpert" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Artisan"],       icon = "Interface\\Icons\\INV_Jewelry_Necklace_11", lootpage = "JewelcraftingArtisan" },
    {},
    { name = LS["Jewelcrafting"] .. ": " .. LS["Gemology"],     icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01", lootpage = "JewelcraftingGemology" },
    { name = LS["Jewelcrafting"] .. ": " .. LS["Goldsmithing"], icon = "Interface\\Icons\\INV_Jewelry_Ring_03",     lootpage = "JewelcraftingGoldsmithing" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Jewelcrafting"],      icon = "Interface\\Icons\\INV_Misc_Book_09",        lootpage = "JewelcraftingTrainers" },
    {},
    {},
    {},
    {},
    {},
    {},
    { name = LS["Jewelcrafting"] .. ": " .. L["Gemstones"],     lootpage = "JewelcraftingGemstones" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Rings"],         lootpage = "JewelcraftingRings" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Amulets"],       lootpage = "JewelcraftingAmulets" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Head"],          lootpage = "JewelcraftingHelm" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Bracers"],       lootpage = "JewelcraftingBracers" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Off Hand"],      lootpage = "JewelcraftingOffHands" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Staff"],         lootpage = "JewelcraftingStaves" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Trinkets"],      lootpage = "JewelcraftingTrinkets" },
    { name = LS["Jewelcrafting"] .. ": " .. L["Misc"],          lootpage = "JewelcraftingMisc" },
}

---
--- Opens the Jewelcrafting crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_JewelcraftingMenu()

function AtlasCFMLoot_JewelcraftingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Jewelcrafting"], AtlasCFM.MenuData.Jewelcrafting, L["Crafting"],
        "Interface\\Icons\\INV_Jewelry_Necklace_01")
end

AtlasCFM.MenuData.Cooking = {
    { name = LS["Cooking"] .. ": " .. L["Apprentice"], lootpage = "CookingApprentice" },
    { name = LS["Cooking"] .. ": " .. L["Journeyman"], lootpage = "CookingJourneyman" },
    { name = LS["Cooking"] .. ": " .. L["Expert"],     lootpage = "CookingExpert" },
    { name = LS["Cooking"] .. ": " .. L["Artisan"],    lootpage = "CookingArtisan" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Cooking"],   icon = "Interface\\Icons\\INV_Misc_Book_09", lootpage = "CookingTrainers" },
}

---
--- Opens the Cooking crafting menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_CookingMenu()

function AtlasCFMLoot_CookingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Cooking"], AtlasCFM.MenuData.Cooking, L["Crafting"],
        "Interface\\Icons\\INV_Misc_Food_15")
end

AtlasCFM.MenuData.FirstAid = {
    { name = LS["First Aid"],                          icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", lootpage = "FirstAidTable" },
    { name = LS["First Aid"] .. ": " .. LS["Cloth"],   icon = "Interface\\Icons\\INV_Fabric_Linen_01",        lootpage = "ClothTable" },
    {},
    { name = L["Trainers"] .. ": " .. LS["First Aid"], icon = "Interface\\Icons\\INV_Misc_Book_09",           lootpage = "FirstAidTrainers" },
}

---
--- Opens the First Aid menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_FirstAidMenu()

function AtlasCFMLoot_FirstAidMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["First Aid"], AtlasCFM.MenuData.FirstAid, L["Crafting"],
        "Interface\\Icons\\Spell_Holy_SealOfSacrifice")
end

AtlasCFM.MenuData.Skinning = {
    { name = LS["Skinning"],                          icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", lootpage = "SkinningTable" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Skinning"], icon = "Interface\\Icons\\INV_Misc_Book_09",      lootpage = "SkinningTrainers" },
}

---
--- Opens the Skinning menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_SkinningMenu()

function AtlasCFMLoot_SkinningMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Skinning"], AtlasCFM.MenuData.Skinning, L["Crafting"],
        "Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
end

AtlasCFM.MenuData.Fishing = {
    { name = LS["Fishing"],                          icon = "Interface\\Icons\\Trade_Fishing",    lootpage = "FishingTable" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Fishing"], icon = "Interface\\Icons\\INV_Misc_Book_09", lootpage = "FishingTrainers" },
}

---
--- Opens the Fishing menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_FishingMenu()

function AtlasCFMLoot_FishingMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Fishing"], AtlasCFM.MenuData.Fishing, L["Crafting"],
        "Interface\\Icons\\Trade_Fishing")
end

AtlasCFM.MenuData.Herbalism = {
    { name = LS["Herbalism"],                          icon = "Interface\\Icons\\Trade_Herbalism",  lootpage = "HerbalismTable" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Herbalism"], icon = "Interface\\Icons\\INV_Misc_Book_09", lootpage = "HerbalismTrainers" },
}

---
--- Opens the Herbalism menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_HerbalismMenu()

function AtlasCFMLoot_HerbalismMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Herbalism"], AtlasCFM.MenuData.Herbalism, L["Crafting"],
        "Interface\\Icons\\Trade_Herbalism")
end

AtlasCFM.MenuData.Survival = {
    { name = LS["Survival"] .. ", " .. LS["Gardening"],  lootpage = "SurvivalTable",                  servers = { AtlasCFM.Server.STRICT_TURTLE1 } },
    { name = LS["Survival"] .. ": " .. L["Apprentice"],  lootpage = "SurvivalApprentice",             servers = { AtlasCFM.Server.TURTLE } },
    { name = LS["Survival"] .. ": " .. L["Journeyman"],  lootpage = "SurvivalJourneyman",             servers = { AtlasCFM.Server.TURTLE } },
    { name = LS["Survival"] .. ": " .. L["Expert"],      lootpage = "SurvivalExpert",                 servers = { AtlasCFM.Server.TURTLE } },
    { name = LS["Survival"] .. ": " .. L["Artisan"],     lootpage = "SurvivalArtisan",                servers = { AtlasCFM.Server.TURTLE } },
    {},
    { name = LS["Survival"] .. ": " .. L["Woodcutting"], lootpage = "SurvivalWoodcutting",            servers = { AtlasCFM.Server.TURTLE } },
    {},
    { name = LS["Gardening"],                            lootpage = "GardeningTable" },
    {},
    { name = L["Trainers"] .. ": " .. LS["Survival"],    icon = "Interface\\Icons\\INV_Misc_Book_09", lootpage = "SurvivalTrainers" },
}

---
--- Opens the Survival menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_SurvivalMenu()

function AtlasCFMLoot_SurvivalMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LS["Survival"], AtlasCFM.MenuData.Survival, L["Crafting"],
        "Interface\\Icons\\Trade_Survival")
end

AtlasCFM.MenuData.Poisons = {
    { name = LS["Poisons"],                          icon = "Interface\\Icons\\Trade_BrewPoison",       lootpage = "PoisonsTable" },
    { name = L["Lockpicking"],                       icon = "Interface\\Icons\\Spell_Nature_MoonKey",   lootpage = "LockpickingTable" },
    { name = LS["Disguise"],                         icon = "Interface\\Icons\\Ability_Rogue_Disguise", lootpage = "DisguiseTable",   servers = { AtlasCFM.Server.NOT_CLASSIC } },
    {},
    { name = L["Trainers"] .. ": " .. LS["Poisons"], icon = "Interface\\Icons\\INV_Misc_Book_09",       lootpage = "PoisonsTrainers" },
}

---
--- Opens the Poisons menu in AtlasCFMLoot
--- @return nil
--- @usage AtlasCFMLoot_PoisonsMenu()

function AtlasCFMLoot_PoisonsMenu()
    AtlasCFM.LootBrowserUI.PrepMenu(LC["Rogue"] .. " " .. L["Special"], AtlasCFM.MenuData.Poisons, L["Crafting"],
        "Interface\\Icons\\Trade_BrewPoison")
end
