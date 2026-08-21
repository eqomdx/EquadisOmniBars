---
--- PVPRewards.lua - Player vs Player reward data tables
---
--- This module contains comprehensive PvP reward data for all battlegrounds
--- and honor systems in World of Warcraft. It includes honor rewards,
--- PvP sets, battleground marks, and ranking system items.
---
--- Features:
--- • Complete PvP reward tables
--- • Honor system items
--- • Battleground mark rewards
--- • Ranking system equipment
--- • PvP set collections
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM

local L = AtlasCFM.Localization.UI
local LF = AtlasCFM.Localization.Factions
local LIS = AtlasCFM.Localization.ItemSets

--Instance required libraries

AtlasCFMLoot_Data = AtlasCFMLoot_Data or {}

local pvpRewards = {
	AzsharaCrater = {
		{ id = 34000,           container = { { 1000000, 3 } }, }, -- Azsharite Powder (inv_azsharite_coin) need ItemId for Azsharite Encrusted Coin(34975 spellid)
		{ id = 34001,           container = { { 1000000, 5 } }, }, -- Azsharite Bomb
		{ id = 34002,           container = { { 1000000, 15 } }, }, -- Azsharite Land Mine
		{ id = 34003,           container = { { 1000000, 40 } }, }, -- Crater Survival Kit
		{ id = 34004,           container = { { 1000000, 50 } }, }, -- Auto-sniping Rifle
		{ id = 34005,           container = { { 1000000, 70 } }, }, -- Azsharite Heart
		{ id = 34006,           container = { { 1000000, 50 } }, }, -- Azsharite Boots of Travel
		{ id = 34010,           container = { { 1000000, 20 } }, }, -- Ultra-Safe Torpor Pills
		{ id = 34011,           container = { { 1000000, 40 } }, }, -- Advanced Adrenaline Injector
		{ id = 34012,           container = { { 1000000, 20 } }, }, -- Major Thick Blood Potion
		{ id = 34013,           container = { { 1000000, 30 } }, }, -- Major Vampiric Potion
		{ id = 34014,           container = { { 1000000, 70 } }, }, -- Major Elixir of Life
		{ id = 34015,           container = { { 1000000, 80 } }, }, -- Timberweb Blowgun
		{ id = 34016,           container = { { 1000000, 100 } }, }, -- Tablet of the Dark Blessing
		{ id = 34020,           container = { { 1000000, 45 } }, }, -- Best Shirt Ever
		{ id = 34021,           container = { { 1000000, 5 } }, }, -- Langrage Scraps
		{ id = 34023,           container = { { 1000000, 35 } }, }, -- Executioner's Greataxe
		{ id = 34024,           container = { { 1000000, 50 } }, }, -- Azsharite Storm Bolt
		{ id = 34025,           container = { { 1000000, 120 } }, }, -- Brotherhood's Great Protector
		{ id = 34026,           container = { { 1000000, 60 } }, }, -- Bloody Hook
		{ id = 34027,           container = { { 1000000, 80 } }, }, -- Sharpest Dimension Slicer
		{ id = 34040,           container = { { 1000000, 50 } }, }, -- Sentry Totem
		{ id = 34041,           container = { { 1000000, 50 } }, }, -- Serpent Totem
		{ id = 34042,           container = { { 1000000, 80 } }, }, -- Mana Detonation Totem
		{ id = 34043,           container = { { 1000000, 100 } }, }, -- Totem of Lightness
		{ id = 34044,           container = { { 1000000, 80 } }, }, -- Totem of Power
		{ id = 34045,           container = { { 1000000, 120 } }, }, -- Healing Totem
		{ id = 34046,           container = { { 1000000, 150 } }, }, -- Stasis Totem
		{},
		{ id = 34048,           disc = L["Misc"] },            -- Once Lost Ring of the Deadly Chaos
		{},
		{ name = LF["Honored"], icon = "INV_BannerPVP_02",        extra = L["Firebird Corps"] },
		{ id = 26139 }, -- Rough Tactical Cloak
		{ id = 26140 }, -- Soft Tactical Poncho
		{ id = 26143 }, -- Battle Healer's Token
		{ id = 26144 }, -- Infantry Good Luck Token
		{},
		{ name = LF["Revered"], icon = "INV_BannerPVP_02",        extra = L["Firebird Corps"] },
		{ id = 26147 }, -- Battle Healer's Hammer
		{ id = 26148 }, -- Battle Mage's Golden Wand
		{ id = 26149 }, -- Naturalist Staff
		{ id = 26150 }, -- Firebird's Kiss
		{},
		{},
		{},
		{},
		{ name = LF["Exalted"], icon = "INV_BannerPVP_02",        extra = L["Firebird Corps"] },
		{ id = 26155 }, -- Sawblade
		{ id = 26157 }, -- Hand of Pacifist
		{ id = 26159 }, -- Mark of the Veteran
		{ id = 26160 }, -- Mark of the Veteran
		{ id = 26162 }, -- Mark of the Veteran
		{ id = 26163 }, -- Mark of the Veteran
		{ id = 26164 }, -- Mark of the Veteran
		{ id = 26165 }, -- Mark of the Veteran
		{ id = 26166 }, -- Mark of the Veteran
		{ id = 26167 }, -- Mark of the Veteran
		{ id = 26137 }, -- Firebird Battle Tabard
		{},
		{},
		{},
		{ name = LF["Honored"], icon = "INV_BannerPVP_01",        extra = L["Operation Rattlesnake"] },
		{ id = 26141 }, -- Rough Tactical Cloak
		{ id = 26142 }, -- Soft Tactical Poncho
		{ id = 26145 }, -- Battle Healer's Token
		{ id = 26146 }, -- Infantry Good Luck Token
		{},
		{ name = LF["Revered"], icon = "INV_BannerPVP_01",        extra = L["Operation Rattlesnake"] },
		{ id = 26151 }, -- Battle Healer's Totem
		{ id = 26152 }, -- Battle Mage's Rod
		{ id = 26153 }, -- Stick of the Shapeshifter
		{ id = 26154 }, -- Rattlesnake Storm Bolter
		{},
		{},
		{},
		{},
		{ name = LF["Exalted"], icon = "INV_BannerPVP_01",        extra = L["Operation Rattlesnake"] },
		{ id = 26156 }, -- The Bite
		{ id = 26158 }, -- Hand of Pacifist
		{ id = 26168 }, -- Mark of the Veteran
		{ id = 26170 }, -- Mark of the Veteran
		{ id = 26171 }, -- Mark of the Veteran
		{ id = 26172 }, -- Mark of the Veteran
		{ id = 26173 }, -- Mark of the Veteran
		{ id = 26174 }, -- Mark of the Veteran
		{ id = 26175 }, -- Mark of the Veteran
		{ id = 26176 }, -- Mark of the Veteran
		{ id = 26138 }, -- Rattlesnake Battle Tabard
	},
	CrimsonRing = { --Vanilla+
		{ name = LF["Neutral"], icon = "inv_jewelry_ring_04" },
		{ id = 26249 },
		{ id = 26250 },
		{ id = 26254 },
		{ id = 26255 },
		{ id = 26256 },
		{ id = 26257 },
		{ id = 26258 },
		{ id = 26259 },
		{ id = 26260 },
		{ id = 26261 },
		{},
		{ name = LF["Honored"], icon = "inv_jewelry_ring_04" },
		{ id = 26246 },
		{ id = 26251 },
		{ id = 26252 },
		{ id = 26253 },
		{ id = 26262 },
		{ id = 26263 },
		{ id = 26264 },
		{ id = 26265 },
		{ id = 26266 },
		{ id = 26267 },
		{},
		{ name = LF["Revered"], icon = "inv_jewelry_ring_04" },
		{ id = 26247 },
		{ id = 26281 },
		{ id = 26268 },
		{ id = 26269 },
		{ id = 26270 },
		{ name = LF["Revered"], icon = "inv_jewelry_ring_04" },
		{ id = 26271 },
		{ id = 26272 },
		{ id = 26273 },
		{ id = 26274 },
		{ id = 26275 },
		{},
		{ name = LF["Exalted"], icon = "inv_jewelry_ring_04" },
		{ id = 26248 },
		{ id = 26245 },
		{ id = 26276 },
		{ id = 26277 },
		{ id = 26278 },
		{ id = 26279 },
		{ id = 26280 },
	},
	PVPWeapons1181 = {
		{ id = 33883, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 18000" },                 -- Strategist's Stave
		{ id = 33881, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 18000" },                 -- Strategist's Demolisher
		{ id = 33894, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Strategist's Mageblade
		{ id = 33895, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Strategist's Tome of Power
		{ id = 33904, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 18000" },                    -- Strategist's War Staff
		{ id = 33902, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 18000" },                    -- Strategist's Destroyer
		{ id = 33915, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Strategist's Spellblade
		{ id = 33916, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Strategist's Tome of Destruction
		{},
		{ id = 33891, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Physician's Warhammer
		{ id = 33896, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Physician's Tome of Restoration
		{ id = 33912, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Physician's Battle Mace
		{ id = 33917, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Physician's Tome of Mending
		{},
		{ id = 33879, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 18000" },                 -- Partisan's Claymore
		{ id = 33880, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 18000" },                 -- Partisan's Battle Hammer
		{ id = 33882, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 18000" },                 -- Partisan's Sunderer
		{ id = 33884, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 18000" },                 -- Partisan's Glaive
		{ id = 33885, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Aegis
		{ id = 33886, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Longsword
		{ id = 33887, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Punisher
		{ id = 33888, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Handaxe
		{ id = 33889, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Left Hand Blade
		{ id = 33890, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Right Hand Blade
		{ id = 33892, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Swiftblade
		{ id = 33893, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Dirk
		{ id = 33897, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Hand Cannon
		{ id = 33898, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Repeater
		{ id = 33899, disc = LF["Alliance"] .. ", " .. L["Honor: "] .. " 14000" },                 -- Partisan's Bullseye
		{ id = 33900, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 18000" },                    -- Partisan's Greatsword
		{ id = 33901, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 18000" },                    -- Partisan's Pulverizer
		{ id = 33903, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 18000" },                    -- Partisan's Battle Axe
		{ id = 33905, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 18000" },                    -- Partisan's Pig Sticker
		{ id = 33906, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Shield Wall
		{ id = 33907, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Blade
		{},
		{ id = 33908, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Bludgeon
		{ id = 33909, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Cleaver
		{ id = 33910, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Left Claw
		{ id = 33911, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Right Claw
		{ id = 33913, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Quickblade
		{ id = 33914, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Razor
		{ id = 33918, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Street Sweeper
		{ id = 33919, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Crossbow
		{ id = 33920, disc = LF["Horde"] .. ", " .. L["Honor: "] .. " 14000" },                    -- Partisan's Recurve
		{},
		{ id = 18873, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 48000", container = { 33883 } }, -- Executioner's Stave
		{ id = 23455, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 48000", container = { 33881 } }, -- Executioner's Demolisher
		{ id = 23451, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33894 } }, -- Executioner's Mageblade
		{ id = 23452, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33895 } }, -- Executioner's Tome of Power
		{ id = 18874, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 48000",    container = { 33904 } }, -- Executioner's War Staff
		{ id = 23465, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 48000",    container = { 33902 } }, -- Executioner's Destroyer
		{ id = 23466, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33915 } }, -- Executioner's Spellblade
		{ id = 23468, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33916 } }, -- Executioner's Tome of Destruction
		{},
		{ id = 23454, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33891 } }, -- Field Medic's Warhammer
		{ id = 23453, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33896 } }, -- Field Medic's Tome of Restoration
		{ id = 23464, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33912 } }, -- Field Medic's Battle Mace
		{ id = 23469, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33917 } }, -- Field Medic's Tome of Mending
		{},
		{ id = 18876, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 48000", container = { 33879 } }, -- Veteran's Claymore
		{ id = 18867, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 48000", container = { 33880 } }, -- Veteran's Battle Hammer
		{ id = 18830, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 48000", container = { 33882 } }, -- Veteran's Sunderer
		{ id = 18869, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 48000", container = { 33884 } }, -- Veteran's Glaive
		{ id = 18825, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33885 } }, -- Veteran's Aegis
		{},
		{ id = 12584, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33886 } }, -- Veteran's Longsword
		{ id = 18865, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33887 } }, -- Veteran's Punisher
		{ id = 18827, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33888 } }, -- Veteran's Handaxe
		{ id = 18847, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33889 } }, -- Veteran's Left Hand Blade
		{ id = 18843, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33890 } }, -- Veteran's Right Hand Blade
		{ id = 23456, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33892 } }, -- Veteran's Swiftblade
		{ id = 18838, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33893 } }, -- Veteran's Dirk
		{ id = 18855, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33897 } }, -- Veteran's Hand Cannon
		{ id = 18836, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33898 } }, -- Veteran's Repeater
		{ id = 18833, disc = L["Alliance"] .. ", " .. L["Honor: "] .. " 32000", container = { 33899 } }, -- Veteran's Bullseye
		{ id = 18877, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 48000",    container = { 33900 } }, -- Veteran's Greatsword
		{ id = 18868, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 48000",    container = { 33901 } }, -- Veteran's Pulverizer
		{ id = 18831, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 48000",    container = { 33903 } }, -- Veteran's Battle Axe
		{ id = 18871, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 48000",    container = { 33905 } }, -- Veteran's Pig Sticker
		{ id = 18826, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33906 } }, -- Veteran's Shield Wall
		{ id = 16345, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33907 } }, -- Veteran's Blade
		{ id = 18866, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33908 } }, -- Veteran's Bludgeon
		{ id = 18828, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33909 } }, -- Veteran's Cleaver
		{ id = 18848, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33910 } }, -- Veteran's Left Claw
		{ id = 18844, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33911 } }, -- Veteran's Right Claw
		{ id = 23467, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33913 } }, -- Veteran's Quickblade
		{ id = 18840, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33914 } }, -- Veteran's Razor
		{ id = 18860, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33918 } }, -- Veteran's Street Sweeper
		{ id = 18837, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33919 } }, -- Veteran's Crossbow
		{ id = 18835, disc = L["Horde"] .. ", " .. L["Honor: "] .. " 32000",    container = { 33920 } }, -- Veteran's Recurve
	},
	PVPWeapons = {
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02", extra = L["Rank"] .. " 14" },
		{ id = 18827 }, -- Grand Marshal's Handaxe
		{ id = 18830 }, -- Grand Marshal's Sunderer
		{ id = 18838 }, -- Grand Marshal's Dirk
		{ id = 23451 }, -- Grand Marshal's Mageblade
		{ id = 18843 }, -- Grand Marshal's Right Hand Blade
		{ id = 18847 }, -- Grand Marshal's Left Hand Blade
		{ id = 18865 }, -- Grand Marshal's Punisher
		{ id = 23454 }, -- Grand Marshal's Warhammer
		{ id = 23455 }, -- Grand Marshal's Demolisher
		{ id = 18867 }, -- Grand Marshal's Battle Hammer
		{ id = 12584 }, -- Grand Marshal's Longsword
		{ id = 23456 }, -- Grand Marshal's Swiftblade
		{ id = 18876 }, -- Grand Marshal's Claymore
		{ id = 18869 }, -- Grand Marshal's Glaive
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01", extra = L["Rank"] .. " 14" },
		{ id = 18828 }, -- High Warlord's Cleaver
		{ id = 18831 }, -- High Warlord's Battle Axe
		{ id = 18840 }, -- High Warlord's Razor
		{ id = 23466 }, -- High Warlord's Spellblade
		{ id = 18844 }, -- High Warlord's Right Claw
		{ id = 18848 }, -- High Warlord's Left Claw
		{ id = 18866 }, -- High Warlord's Bludgeon
		{ id = 23464 }, -- High Warlord's Battle Mace
		{ id = 23465 }, -- High Warlord's Destroyer
		{ id = 18868 }, -- High Warlord's Pulverizer
		{ id = 16345 }, -- High Warlord's Blade
		{ id = 23467 }, -- High Warlord's Quickblade
		{ id = 18877 }, -- High Warlord's Greatsword
		{ id = 18871 }, -- High Warlord's Pig Sticker
		{ id = 18873 }, -- Grand Marshal's Stave
		{ id = 18833 }, -- Grand Marshal's Bullseye
		{ id = 18836 }, -- Grand Marshal's Repeater
		{ id = 18855 }, -- Grand Marshal's Hand Cannon
		{ id = 18825 }, -- Grand Marshal's Aegis
		{ id = 23452 }, -- Grand Marshal's Tome of Power
		{ id = 23453 }, -- Grand Marshal's Tome of Restoration
		{},
		{},
		{},
		{},
		{},
		{},
		{},
		{},
		{ id = 18874 }, -- High Warlord's War Staff
		{ id = 18835 }, -- High Warlord's Recurve
		{ id = 18837 }, -- High Warlord's Crossbow
		{ id = 18860 }, -- High Warlord's Street Sweeper
		{ id = 18826 }, -- High Warlord's Shield Wall
		{ id = 23468 }, -- High Warlord's Tome of Destruction
		{ id = 23469 }, -- High Warlord's Tome of Mending
	},
	PvP60Accessories = {
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 1" }, --*1
		{ id = 15196 },                                                                      -- Private's Tabard
		{ id = 18839,            disc = L["Consumable"] },                                   -- Combat Healing Potion
		{ id = 18841,            disc = L["Consumable"] },                                   -- Combat Mana Potion
		{},
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 2" },
		{ id = 18862 },                                                                      -- Insignia of the Alliance
		{ id = 18859 },                                                                      -- Insignia of the Alliance
		{ id = 18858 },                                                                      -- Insignia of the Alliance
		{ id = 18857 },                                                                      -- Insignia of the Alliance
		{ id = 18863 },                                                                      -- Insignia of the Alliance
		{ id = 18856 },                                                                      -- Insignia of the Alliance
		{ id = 18864 },                                                                      -- Insignia of the Alliance
		{ id = 18854 },                                                                      -- Insignia of the Alliance
		{},
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 1" }, --*1
		{ id = 15197 },                                                                      -- Scout's Tabard
		{ id = 18839,            disc = L["Consumable"] },                                   -- Combat Healing Potion
		{ id = 18841,            disc = L["Consumable"] },                                   -- Combat Mana Potion
		{},
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 2" },
		{ id = 18851 },                                                                      -- Insignia of the Horde
		{ id = 18850 },                                                                      -- Insignia of the Horde
		{ id = 18852 },                                                                      -- Insignia of the Horde
		{ id = 18849 },                                                                      -- Insignia of the Horde
		{ id = 18853 },                                                                      -- Insignia of the Horde
		{ id = 18846 },                                                                      -- Insignia of the Horde
		{ id = 18845 },                                                                      -- Insignia of the Horde
		{ id = 18834 },                                                                      -- Insignia of the Horde
		{},
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 3" }, --*1
		{ id = 18440 },                                                                      -- Sergeant's Cape 3
		{ id = 18441 },                                                                      -- Sergeant's Cape 3
		{ id = 16342 },                                                                      -- Sergeant's Cape 3
		{},
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 4" },
		{ id = 18442 }, -- Master Sergeant's Insignia 4
		{ id = 18444 }, -- Master Sergeant's Insignia 4
		{ id = 18443 }, -- Master Sergeant's Insignia 4
		{},
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 5" },
		{ id = 18457 },                                                                      -- Sergeant Major's Silk Cuffs 5
		{ id = 18456 },                                                                      -- Sergeant Major's Silk Cuffs 5
		{},
		{ id = 18455 },                                                                      -- Sergeant Major's Dragonhide Armsplints 5 *15
		--Horde
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 3" }, --*1
		{ id = 18427 },                                                                      -- Sergeant's Cloak 3
		{ id = 16341 },                                                                      -- Sergeant's Cloak 3
		{ id = 18461 },                                                                      -- Sergeant's Cloak 3
		{},
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 4" },
		{ id = 15200 }, -- Senior Sergeant's Insignia 4
		{ id = 18428 }, -- Senior Sergeant's Insignia 4
		{ id = 16335 }, -- Senior Sergeant's Insignia 4
		{},
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 5" },
		{ id = 18437 }, -- First Sergeant's Silk Cuffs 5
		{ id = 16486 }, -- First Sergeant's Silk Cuffs 5
		{},
		{ id = 18436 }, -- First Sergeant's Dragonhide Armguards 5 *15
		{ id = 18454 }, -- Sergeant Major's Dragonhide Armsplints 5 *1 alliance
		{},
		{ id = 18453 }, -- Sergeant Major's Leather Armsplints 5
		{ id = 18452 }, -- Sergeant Major's Leather Armsplints 5
		{},
		{ id = 18449 }, -- Sergeant Major's Chain Armguards 5
		{ id = 18448 }, -- Sergeant Major's Chain Armguards 5
		{},
		{ id = 18447 }, -- Sergeant Major's Plate Wristguards 5
		{ id = 18445 }, -- Sergeant Major's Plate Wristguards 5
		{},
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 6" },
		{ id = 15198 },                        -- Knight's Colors 6
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02",           extra = L["Rank"] .. " 9" },
		{ id = 18606,            disc = L["Misc"] }, -- Alliance Battle Standard 9
		{ id = 18434 },                        -- First Sergeant's Dragonhide Armguards 5 *1 horde
		{},
		{ id = 18435 },                        -- First Sergeant's Leather Armguards 5
		{ id = 16497 },                        -- First Sergeant's Leather Armguards 5
		{},
		{ id = 18432 },                        -- First Sergeant's Mail Wristguards 5
		{ id = 16532 },                        -- First Sergeant's Mail Wristguards 5
		{},
		{ id = 18430 },                        -- First Sergeant's Plate Bracers 5
		{ id = 18429 },                        -- First Sergeant's Plate Bracers 5
		{},
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 6" },
		{ id = 15199 },                                            -- Stone Guard's Herald 6
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01",           extra = L["Rank"] .. " 9" },
		{ id = 18607,            disc = L["Misc"] },               -- Horde Battle Standard 9
		{},
		{ id = 98731,            servers = { AtlasCFM.Server.TURTLE } }, -- Gladiator's Tunic
	},
	PVPHunter1181 = {
		{ id = 33440, disc = L["Honor: "] .. " 5000" }, -- Combatant's Chain Helm
		{ id = 33441, disc = L["Honor: "] .. " 4000" }, -- Combatant's Chain Spaulders
		{ id = 33442, disc = L["Honor: "] .. " 5000" }, -- Combatant's Chain Breastplate
		{ id = 33443, disc = L["Honor: "] .. " 3000" }, -- Combatant's Chain Grips
		{ id = 33444, disc = L["Honor: "] .. " 4000" }, -- Combatant's Chain Legguards
		{ id = 33445, disc = L["Honor: "] .. " 3000" }, -- Combatant's Chain Boots
		{},
		{ id = 33716, disc = L["Honor: "] .. " 5000" }, -- Combatant's Chain Helm
		{ id = 33717, disc = L["Honor: "] .. " 4000" }, -- Combatant's Chain Spaulders
		{ id = 33718, disc = L["Honor: "] .. " 5000" }, -- Combatant's Chain Breastplate
		{ id = 33719, disc = L["Honor: "] .. " 3000" }, -- Combatant's Chain Grips
		{ id = 33720, disc = L["Honor: "] .. " 4000" }, -- Combatant's Chain Legguards
		{ id = 33721, disc = L["Honor: "] .. " 3000" }, -- Combatant's Chain Boots
		{},
		{},
		{ id = 33446, disc = L["Honor: "] .. " 19000",                                        container = { 33440 } }, -- Partisan's Chain Helm
		{ id = 33447, disc = L["Honor: "] .. " 19000",                                        container = { 33441 } }, -- Partisan's Chain Spaulders
		{ id = 33448, disc = L["Honor: "] .. " 22000",                                        container = { 33442 } }, -- Partisan's Chain Breastplate
		{ id = 33449, disc = L["Honor: "] .. " 20000",                                        container = { 33443 } }, -- Partisan's Chain Grips
		{ id = 33450, disc = L["Honor: "] .. " 22000",                                        container = { 33444 } }, -- Partisan's Chain Legguards
		{ id = 33451, disc = L["Honor: "] .. " 18000",                                        container = { 33445 } }, -- Partisan's Chain Boots
		{},
		{ id = 33722, disc = L["Honor: "] .. " 19000",                                        container = { 33716 } }, -- Partisan's Chain Helm
		{ id = 33723, disc = L["Honor: "] .. " 19000",                                        container = { 33717 } }, -- Partisan's Chain Spaulders
		{ id = 33724, disc = L["Honor: "] .. " 22000",                                        container = { 33718 } }, -- Partisan's Chain Breastplate
		{ id = 33725, disc = L["Honor: "] .. " 20000",                                        container = { 33719 } }, -- Partisan's Chain Grips
		{ id = 33726, disc = L["Honor: "] .. " 22000",                                        container = { 33720 } }, -- Partisan's Chain Legguards
		{ id = 33727, disc = L["Honor: "] .. " 18000",                                        container = { 33721 } }, -- Partisan's Chain Boots
		{},
		{},
		{ id = 33452, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33446 } }, -- Veteran's Chain Helm
		{ id = 33453, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33447 } }, -- Veteran's Chain Spaulders
		{ id = 33454, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33448 } }, -- Veteran's Chain Breastplate
		{ id = 33455, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33449 } }, -- Veteran's Chain Grips
		{ id = 33456, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33450 } }, -- Veteran's Chain Legguards
		{ id = 33457, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33451 } }, -- Veteran's Chain Boots
		{},
		{ id = 33728, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33722 } }, -- Veteran's Chain Helm
		{ id = 33729, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33723 } }, -- Veteran's Chain Spaulders
		{ id = 33730, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33724 } }, -- Veteran's Chain Breastplate
		{ id = 33731, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33725 } }, -- Veteran's Chain Grips
		{ id = 33732, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33726 } }, -- Veteran's Chain Legguards
		{ id = 33733, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33727 } }, -- Veteran's Chain Boots
	},
	PVPMage1181 = {
		{ id = 33422, disc = L["Honor: "] .. " 5000" }, -- Tactician's Coronet
		{ id = 33423, disc = L["Honor: "] .. " 4000" }, -- Tactician's Silk Spaulders
		{ id = 33424, disc = L["Honor: "] .. " 5000" }, -- Tactician's Silk Vestments
		{ id = 33425, disc = L["Honor: "] .. " 3000" }, -- Tactician's Silk Gloves
		{ id = 33426, disc = L["Honor: "] .. " 4000" }, -- Tactician's Silk Leggings
		{ id = 33427, disc = L["Honor: "] .. " 3000" }, -- Tactician's Silk Footwraps
		{},
		{ id = 33698, disc = L["Honor: "] .. " 5000" }, -- Tactician's Coronet
		{ id = 33699, disc = L["Honor: "] .. " 4000" }, -- Tactician's Silk Spaulders
		{ id = 33700, disc = L["Honor: "] .. " 5000" }, -- Tactician's Silk Vestments
		{ id = 33701, disc = L["Honor: "] .. " 3000" }, -- Tactician's Silk Gloves
		{ id = 33702, disc = L["Honor: "] .. " 4000" }, -- Tactician's Silk Leggings
		{ id = 33703, disc = L["Honor: "] .. " 3000" }, -- Tactician's Silk Footwraps
		{},
		{},
		{ id = 33428, disc = L["Honor: "] .. " 19000",                                        container = { 33422 } }, -- Strategist's Coronet
		{ id = 33429, disc = L["Honor: "] .. " 19000",                                        container = { 33423 } }, -- Strategist's Silk Spaulders
		{ id = 33430, disc = L["Honor: "] .. " 22000",                                        container = { 33424 } }, -- Strategist's Silk Vestments
		{ id = 33431, disc = L["Honor: "] .. " 20000",                                        container = { 33425 } }, -- Strategist's Silk Gloves
		{ id = 33432, disc = L["Honor: "] .. " 22000",                                        container = { 33426 } }, -- Strategist's Silk Leggings
		{ id = 33433, disc = L["Honor: "] .. " 18000",                                        container = { 33427 } }, -- Strategist's Silk Footwraps
		{},
		{ id = 33704, disc = L["Honor: "] .. " 19000",                                        container = { 33698 } }, -- Strategist's Coronet
		{ id = 33705, disc = L["Honor: "] .. " 19000",                                        container = { 33699 } }, -- Strategist's Silk Spaulders
		{ id = 33706, disc = L["Honor: "] .. " 22000",                                        container = { 33700 } }, -- Strategist's Silk Vestments
		{ id = 33707, disc = L["Honor: "] .. " 20000",                                        container = { 33701 } }, -- Strategist's Silk Gloves
		{ id = 33708, disc = L["Honor: "] .. " 22000",                                        container = { 33702 } }, -- Strategist's Silk Leggings
		{ id = 33709, disc = L["Honor: "] .. " 18000",                                        container = { 33703 } }, -- Strategist's Silk Footwraps
		{},
		{},
		{ id = 33434, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33428 } }, -- Executor's Coronet
		{ id = 33435, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33429 } }, -- Executor's Silk Spaulders
		{ id = 33436, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33430 } }, -- Executor's Silk Vestments
		{ id = 33437, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33431 } }, -- Executor's Silk Gloves
		{ id = 33438, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33432 } }, -- Executor's Silk Leggings
		{ id = 33439, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33433 } }, -- Executor's Silk Footwraps
		{},
		{ id = 33710, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33704 } }, -- Executor's Coronet
		{ id = 33711, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33705 } }, -- Executor's Silk Spaulders
		{ id = 33712, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33706 } }, -- Executor's Silk Vestments
		{ id = 33713, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33707 } }, -- Executor's Silk Gloves
		{ id = 33714, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33708 } }, -- Executor's Silk Leggings
		{ id = 33715, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33709 } }, -- Executor's Silk Footwraps
	},
	PVPPriest1181 = {
		{ id = 33620, disc = L["Honor: "] .. " 5000" }, -- Tactician's Headdress
		{ id = 33621, disc = L["Honor: "] .. " 4000" }, -- Tactician's Satin Mantle
		{ id = 33622, disc = L["Honor: "] .. " 5000" }, -- Tactician's Satin Vestments
		{ id = 33623, disc = L["Honor: "] .. " 3000" }, -- Tactician's Satin Gloves
		{ id = 33624, disc = L["Honor: "] .. " 4000" }, -- Tactician's Satin Pants
		{ id = 33625, disc = L["Honor: "] .. " 3000" }, -- Tactician's Satin Sandals
		{},
		{ id = 33806, disc = L["Honor: "] .. " 5000" }, -- Tactician's Headdress
		{ id = 33807, disc = L["Honor: "] .. " 4000" }, -- Tactician's Satin Mantle
		{ id = 33808, disc = L["Honor: "] .. " 5000" }, -- Tactician's Satin Vestments
		{ id = 33809, disc = L["Honor: "] .. " 3000" }, -- Tactician's Satin Gloves
		{ id = 33810, disc = L["Honor: "] .. " 4000" }, -- Tactician's Satin Pants
		{ id = 33811, disc = L["Honor: "] .. " 3000" }, -- Tactician's Satin Sandals
		{},
		{},
		{ id = 33626, disc = L["Honor: "] .. " 19000",                                        container = { 33620 } }, -- Strategist's Headdress
		{ id = 33627, disc = L["Honor: "] .. " 19000",                                        container = { 33621 } }, -- Strategist's Satin Mantle
		{ id = 33628, disc = L["Honor: "] .. " 22000",                                        container = { 33622 } }, -- Strategist's Satin Vestments
		{ id = 33629, disc = L["Honor: "] .. " 20000",                                        container = { 33623 } }, -- Strategist's Satin Gloves
		{ id = 33630, disc = L["Honor: "] .. " 22000",                                        container = { 33624 } }, -- Strategist's Satin Pants
		{ id = 33631, disc = L["Honor: "] .. " 18000",                                        container = { 33625 } }, -- Strategist's Satin Sandals
		{},
		{ id = 33812, disc = L["Honor: "] .. " 19000",                                        container = { 33806 } }, -- Strategist's Headdress
		{ id = 33813, disc = L["Honor: "] .. " 19000",                                        container = { 33807 } }, -- Strategist's Satin Mantle
		{ id = 33814, disc = L["Honor: "] .. " 22000",                                        container = { 33808 } }, -- Strategist's Satin Vestments
		{ id = 33815, disc = L["Honor: "] .. " 20000",                                        container = { 33809 } }, -- Strategist's Satin Gloves
		{ id = 33816, disc = L["Honor: "] .. " 22000",                                        container = { 33810 } }, -- Strategist's Satin Pants
		{ id = 33817, disc = L["Honor: "] .. " 18000",                                        container = { 33811 } }, -- Strategist's Satin Sandals
		{},
		{},
		{ id = 33632, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33626 } }, -- Executor's Headdress
		{ id = 33633, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33627 } }, -- Executor's Satin Mantle
		{ id = 33634, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33628 } }, -- Executor's Satin Vestments
		{ id = 33635, disc = L["Honor: "] .. " 67000, " .. L["Conquest Points: "] .. " 3000", container = { 33629 } }, -- Executor's Satin Gloves
		{ id = 33636, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33630 } }, -- Executor's Satin Pants
		{ id = 33637, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3000", container = { 33631 } }, -- Executor's Satin Sandals
		{},
		{ id = 33818, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33812 } }, -- Executor's Headdress
		{ id = 33819, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33813 } }, -- Executor's Satin Mantle
		{ id = 33820, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33814 } }, -- Executor's Satin Vestments
		{ id = 33821, disc = L["Honor: "] .. " 67000, " .. L["Conquest Points: "] .. " 3000", container = { 33815 } }, -- Executor's Satin Gloves
		{ id = 33822, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33816 } }, -- Executor's Satin Pants
		{ id = 33823, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3000", container = { 33817 } }, -- Executor's Satin Sandals
		{},
		{},
		{ id = 33638, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Headdress
		{ id = 33639, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Satin Mantle
		{ id = 33640, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Satin Vestments
		{ id = 33641, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Satin Gloves
		{ id = 33642, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Satin Pants
		{ id = 33643, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Satin Sandals
		{},
		{ id = 33824, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Headdress
		{ id = 33825, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Satin Mantle
		{ id = 33826, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Satin Vestments
		{ id = 33827, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Satin Gloves
		{ id = 33828, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Satin Pants
		{ id = 33829, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Satin Sandals
		{},
		{},
		{ id = 33644, disc = L["Honor: "] .. " 19000",                                        container = { 33638 } }, -- Physician's Headdress
		{ id = 33645, disc = L["Honor: "] .. " 19000",                                        container = { 33639 } }, -- Physician's Satin Mantle
		{ id = 33646, disc = L["Honor: "] .. " 22000",                                        container = { 33640 } }, -- Physician's Satin Vestments
		{ id = 33647, disc = L["Honor: "] .. " 20000",                                        container = { 33641 } }, -- Physician's Satin Gloves
		{ id = 33648, disc = L["Honor: "] .. " 22000",                                        container = { 33642 } }, -- Physician's Satin Pants
		{ id = 33649, disc = L["Honor: "] .. " 18000",                                        container = { 33643 } }, -- Physician's Satin Sandals
		{},
		{ id = 33830, disc = L["Honor: "] .. " 19000",                                        container = { 33824 } }, -- Physician's Headdress
		{ id = 33831, disc = L["Honor: "] .. " 19000",                                        container = { 33825 } }, -- Physician's Satin Mantle
		{ id = 33832, disc = L["Honor: "] .. " 22000",                                        container = { 33826 } }, -- Physician's Satin Vestments
		{ id = 33833, disc = L["Honor: "] .. " 20000",                                        container = { 33827 } }, -- Physician's Satin Gloves
		{ id = 33834, disc = L["Honor: "] .. " 22000",                                        container = { 33828 } }, -- Physician's Satin Pants
		{ id = 33835, disc = L["Honor: "] .. " 18000",                                        container = { 33829 } }, -- Physician's Satin Sandals
		{},
		{},
		{ id = 33650, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33644 } }, -- Field Medic's Headdress
		{ id = 33651, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33645 } }, -- Field Medic's Satin Mantle
		{ id = 33652, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33646 } }, -- Field Medic's Satin Vestments
		{ id = 33653, disc = L["Honor: "] .. " 67000, " .. L["Conquest Points: "] .. " 3000", container = { 33647 } }, -- Field Medic's Satin Gloves
		{ id = 33654, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33648 } }, -- Field Medic's Satin Pants
		{ id = 33655, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3000", container = { 33649 } }, -- Field Medic's Satin Sandals
		{},
		{ id = 33836, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33830 } }, -- Field Medic's Headdress
		{ id = 33837, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33831 } }, -- Field Medic's Satin Mantle
		{ id = 33838, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33832 } }, -- Field Medic's Satin Vestments
		{ id = 33839, disc = L["Honor: "] .. " 67000, " .. L["Conquest Points: "] .. " 3000", container = { 33833 } }, -- Field Medic's Satin Gloves
		{ id = 33840, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33834 } }, -- Field Medic's Satin Pants
		{ id = 33841, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3000", container = { 33835 } }, -- Field Medic's Satin Sandals
	},
	PVPWarlock1181 = {
		{ id = 33458, disc = L["Honor: "] .. " 5000" }, -- Tactician's Coronal
		{ id = 33459, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dreadweave Shoulders
		{ id = 33460, disc = L["Honor: "] .. " 5000" }, -- Tactician's Dreadweave Robe
		{ id = 33461, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dreadweave Gloves
		{ id = 33462, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dreadweave Leggings
		{ id = 33463, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dreadweave Boots
		{},
		{ id = 33734, disc = L["Honor: "] .. " 5000" }, -- Tactician's Coronal
		{ id = 33735, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dreadweave Shoulders
		{ id = 33736, disc = L["Honor: "] .. " 5000" }, -- Tactician's Dreadweave Robe
		{ id = 33737, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dreadweave Gloves
		{ id = 33738, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dreadweave Leggings
		{ id = 33739, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dreadweave Boots
		{},
		{},
		{ id = 33464, disc = L["Honor: "] .. " 19000",                                        container = { 33458 } }, -- Strategist's Coronal
		{ id = 33465, disc = L["Honor: "] .. " 19000",                                        container = { 33459 } }, -- Strategist's Dreadweave Shoulders
		{ id = 33466, disc = L["Honor: "] .. " 22000",                                        container = { 33460 } }, -- Strategist's Dreadweave Robe
		{ id = 33467, disc = L["Honor: "] .. " 20000",                                        container = { 33461 } }, -- Strategist's Dreadweave Gloves
		{ id = 33468, disc = L["Honor: "] .. " 22000",                                        container = { 33462 } }, -- Strategist's Dreadweave Leggings
		{ id = 33469, disc = L["Honor: "] .. " 18000",                                        container = { 33463 } }, -- Strategist's Dreadweave Boots
		{},
		{ id = 33740, disc = L["Honor: "] .. " 19000",                                        container = { 33734 } }, -- Strategist's Coronal
		{ id = 33741, disc = L["Honor: "] .. " 19000",                                        container = { 33735 } }, -- Strategist's Dreadweave Shoulders
		{ id = 33742, disc = L["Honor: "] .. " 22000",                                        container = { 33736 } }, -- Strategist's Dreadweave Robe
		{ id = 33743, disc = L["Honor: "] .. " 20000",                                        container = { 33737 } }, -- Strategist's Dreadweave Gloves
		{ id = 33744, disc = L["Honor: "] .. " 22000",                                        container = { 33738 } }, -- Strategist's Dreadweave Leggings
		{ id = 33745, disc = L["Honor: "] .. " 18000",                                        container = { 33739 } }, -- Strategist's Dreadweave Boots
		{},
		{},
		{ id = 33470, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33464 } }, -- Executor's Coronal
		{ id = 33471, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33465 } }, -- Executor's Dreadweave Shoulders
		{ id = 33472, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33466 } }, -- Executor's Dreadweave Robe
		{ id = 33473, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33467 } }, -- Executor's Dreadweave Gloves
		{ id = 33474, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33468 } }, -- Executor's Dreadweave Leggings
		{ id = 33475, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33469 } }, -- Executor's Dreadweave Boots
		{},
		{ id = 33746, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33740 } }, -- Executor's Coronal
		{ id = 33747, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33741 } }, -- Executor's Dreadweave Shoulders
		{ id = 33748, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33742 } }, -- Executor's Dreadweave Robe
		{ id = 33749, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33743 } }, -- Executor's Dreadweave Gloves
		{ id = 33750, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33744 } }, -- Executor's Dreadweave Leggings
		{ id = 33751, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33745 } }, -- Executor's Dreadweave Boots
	},
	PVPRogue1181 = {
		{ id = 33656, disc = L["Honor: "] .. " 5000" }, -- Combatant's Leather Mask
		{ id = 33657, disc = L["Honor: "] .. " 4000" }, -- Combatant's Leather Epaulets
		{ id = 33658, disc = L["Honor: "] .. " 5000" }, -- Combatant's Leather Chestpiece
		{ id = 33659, disc = L["Honor: "] .. " 3000" }, -- Combatant's Leather Handgrips
		{ id = 33660, disc = L["Honor: "] .. " 4000" }, -- Combatant's Leather Leggings
		{ id = 33661, disc = L["Honor: "] .. " 3000" }, -- Combatant's Leather Footguards
		{},
		{ id = 33842, disc = L["Honor: "] .. " 5000" }, -- Combatant's Leather Mask
		{ id = 33843, disc = L["Honor: "] .. " 4000" }, -- Combatant's Leather Epaulets
		{ id = 33844, disc = L["Honor: "] .. " 5000" }, -- Combatant's Leather Chestpiece
		{ id = 33845, disc = L["Honor: "] .. " 3000" }, -- Combatant's Leather Handgrips
		{ id = 33846, disc = L["Honor: "] .. " 4000" }, -- Combatant's Leather Leggings
		{ id = 33847, disc = L["Honor: "] .. " 3000" }, -- Combatant's Leather Footguards
		{},
		{},
		{ id = 33662, disc = L["Honor: "] .. " 19000",                                        container = { 33656 } }, -- Partisan's Leather Mask
		{ id = 33663, disc = L["Honor: "] .. " 19000",                                        container = { 33657 } }, -- Partisan's Leather Epaulets
		{ id = 33664, disc = L["Honor: "] .. " 22000",                                        container = { 33658 } }, -- Partisan's Leather Chestpiece
		{ id = 33665, disc = L["Honor: "] .. " 20000",                                        container = { 33659 } }, -- Partisan's Leather Handgrips
		{ id = 33666, disc = L["Honor: "] .. " 22000",                                        container = { 33660 } }, -- Partisan's Leather Leggings
		{ id = 33667, disc = L["Honor: "] .. " 18000",                                        container = { 33661 } }, -- Partisan's Leather Footguards
		{},
		{ id = 33848, disc = L["Honor: "] .. " 19000",                                        container = { 33842 } }, -- Partisan's Leather Mask
		{ id = 33849, disc = L["Honor: "] .. " 19000",                                        container = { 33843 } }, -- Partisan's Leather Epaulets
		{ id = 33850, disc = L["Honor: "] .. " 22000",                                        container = { 33844 } }, -- Partisan's Leather Chestpiece
		{ id = 33851, disc = L["Honor: "] .. " 20000",                                        container = { 33845 } }, -- Partisan's Leather Handgrips
		{ id = 33852, disc = L["Honor: "] .. " 22000",                                        container = { 33846 } }, -- Partisan's Leather Leggings
		{ id = 33853, disc = L["Honor: "] .. " 18000",                                        container = { 33847 } }, -- Partisan's Leather Footguards
		{},
		{},
		{ id = 33668, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33662 } }, -- Veteran's Leather Mask
		{ id = 33669, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33663 } }, -- Veteran's Leather Epaulets
		{ id = 33670, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33664 } }, -- Veteran's Leather Chestpiece
		{ id = 33671, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33665 } }, -- Veteran's Leather Handgrips
		{ id = 33672, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33666 } }, -- Veteran's Leather Leggings
		{ id = 33673, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33667 } }, -- Veteran's Leather Footguards
		{},
		{ id = 33854, disc = L["Honor: "] .. " 32000, " .. L["Conquest Points: "] .. " 1500", container = { 33848 } }, -- Veteran's Leather Mask
		{ id = 33855, disc = L["Honor: "] .. " 32000, " .. L["Conquest Points: "] .. " 1500", container = { 33849 } }, -- Veteran's Leather Epaulets
		{ id = 33856, disc = L["Honor: "] .. " 32000, " .. L["Conquest Points: "] .. " 1500", container = { 33850 } }, -- Veteran's Leather Chestpiece
		{ id = 33857, disc = L["Honor: "] .. " 32000, " .. L["Conquest Points: "] .. " 1500", container = { 33851 } }, -- Veteran's Leather Handgrips
		{ id = 33858, disc = L["Honor: "] .. " 32000, " .. L["Conquest Points: "] .. " 1500", container = { 33852 } }, -- Veteran's Leather Leggings
		{ id = 33859, disc = L["Honor: "] .. " 32000, " .. L["Conquest Points: "] .. " 1500", container = { 33853 } }, -- Veteran's Leather Footguards
	},
	PVPDruid1181 = {
		{ id = 33530, disc = L["Honor: "] .. " 5000" }, -- Combatant's Dragonhide Helmet
		{ id = 33531, disc = L["Honor: "] .. " 4000" }, -- Combatant's Dragonhide Epaulets
		{ id = 33532, disc = L["Honor: "] .. " 5000" }, -- Combatant's Dragonhide Hauberk
		{ id = 33533, disc = L["Honor: "] .. " 3000" }, -- Combatant's Dragonhide Gloves
		{ id = 33534, disc = L["Honor: "] .. " 4000" }, -- Combatant's Dragonhide Leggings
		{ id = 33535, disc = L["Honor: "] .. " 3000" }, -- Combatant's Dragonhide Boots
		{},
		{ id = 33752, disc = L["Honor: "] .. " 5000" }, -- Combatant's Dragonhide Helmet
		{ id = 33753, disc = L["Honor: "] .. " 4000" }, -- Combatant's Dragonhide Shoulders
		{ id = 33754, disc = L["Honor: "] .. " 5000" }, -- Combatant's Dragonhide Hauberk
		{ id = 33755, disc = L["Honor: "] .. " 3000" }, -- Combatant's Dragonhide Gloves
		{ id = 33756, disc = L["Honor: "] .. " 4000" }, -- Combatant's Dragonhide Leggings
		{ id = 33757, disc = L["Honor: "] .. " 3000" }, -- Combatant's Dragonhide Boots
		{},
		{},
		{ id = 33536, disc = L["Honor: "] .. " 19000",                                        container = { 33530 } }, -- Partisan's Dragonhide Helmet
		{ id = 33537, disc = L["Honor: "] .. " 19000",                                        container = { 33531 } }, -- Partisan's Dragonhide Epaulets
		{ id = 33538, disc = L["Honor: "] .. " 22000",                                        container = { 33532 } }, -- Partisan's Dragonhide Hauberk
		{ id = 33539, disc = L["Honor: "] .. " 20000",                                        container = { 33533 } }, -- Partisan's Dragonhide Gloves
		{ id = 33540, disc = L["Honor: "] .. " 22000",                                        container = { 33534 } }, -- Partisan's Dragonhide Leggings
		{ id = 33541, disc = L["Honor: "] .. " 18000",                                        container = { 33535 } }, -- Partisan's Dragonhide Boots
		{},
		{ id = 33758, disc = L["Honor: "] .. " 19000",                                        container = { 33752 } }, -- Partisan's Dragonhide Helmet
		{ id = 33759, disc = L["Honor: "] .. " 19000",                                        container = { 33753 } }, -- Partisan's Dragonhide Epaulets
		{ id = 33760, disc = L["Honor: "] .. " 22000",                                        container = { 33754 } }, -- Partisan's Dragonhide Hauberk
		{ id = 33761, disc = L["Honor: "] .. " 20000",                                        container = { 33755 } }, -- Partisan's Dragonhide Gloves
		{ id = 33762, disc = L["Honor: "] .. " 22000",                                        container = { 33756 } }, -- Partisan's Dragonhide Leggings
		{ id = 33763, disc = L["Honor: "] .. " 18000",                                        container = { 33757 } }, -- Partisan's Dragonhide Boots
		{},
		{},
		{ id = 33542, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33536 } }, -- Veteran's Dragonhide Helmet
		{ id = 33543, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33537 } }, -- Veteran's Dragonhide Epaulets
		{ id = 33544, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33538 } }, -- Veteran's Dragonhide Hauberk
		{ id = 33545, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33539 } }, -- Veteran's Dragonhide Gloves
		{ id = 33546, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33540 } }, -- Veteran's Dragonhide Leggings
		{ id = 33547, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33541 } }, -- Veteran's Dragonhide Boots
		{},
		{ id = 33764, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33758 } }, -- Veteran's Dragonhide Helmet
		{ id = 33765, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33759 } }, -- Veteran's Dragonhide Epaulets
		{ id = 33766, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33760 } }, -- Veteran's Dragonhide Hauberk
		{ id = 33767, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33761 } }, -- Veteran's Dragonhide Gloves
		{ id = 33768, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33762 } }, -- Veteran's Dragonhide Leggings
		{ id = 33769, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33763 } }, -- Veteran's Dragonhide Boots
		{},
		{},
		{ id = 33548, disc = L["Honor: "] .. " 5000" }, -- Tactician's Dragonhide Helmet
		{ id = 33549, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dragonhide Epaulets
		{ id = 33550, disc = L["Honor: "] .. " 5000" }, -- Tactician's Dragonhide Hauberk
		{ id = 33551, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dragonhide Gloves
		{ id = 33552, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dragonhide Leggings
		{ id = 33553, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dragonhide Boots
		{},
		{ id = 33770, disc = L["Honor: "] .. " 5000" }, -- Tactician's Dragonhide Helmet
		{ id = 33771, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dragonhide Epaulets
		{ id = 33772, disc = L["Honor: "] .. " 5000" }, -- Tactician's Dragonhide Hauberk
		{ id = 33773, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dragonhide Gloves
		{ id = 33774, disc = L["Honor: "] .. " 4000" }, -- Tactician's Dragonhide Leggings
		{ id = 33775, disc = L["Honor: "] .. " 3000" }, -- Tactician's Dragonhide Boots
		{},
		{},
		{ id = 33554, disc = L["Honor: "] .. " 19000",                                        container = { 33548 } }, -- Strategist's Dragonhide Helmet
		{ id = 33555, disc = L["Honor: "] .. " 19000",                                        container = { 33549 } }, -- Strategist's Dragonhide Epaulets
		{ id = 33556, disc = L["Honor: "] .. " 22000",                                        container = { 33550 } }, -- Strategist's Dragonhide Hauberk
		{ id = 33557, disc = L["Honor: "] .. " 20000",                                        container = { 33551 } }, -- Strategist's Dragonhide Gloves
		{ id = 33558, disc = L["Honor: "] .. " 22000",                                        container = { 33552 } }, -- Strategist's Dragonhide Leggings
		{ id = 33559, disc = L["Honor: "] .. " 18000",                                        container = { 33553 } }, -- Strategist's Dragonhide Boots
		{},
		{ id = 33776, disc = L["Honor: "] .. " 19000",                                        container = { 33770 } }, -- Strategist's Dragonhide Helmet
		{ id = 33777, disc = L["Honor: "] .. " 19000",                                        container = { 33771 } }, -- Strategist's Dragonhide Epaulets
		{ id = 33778, disc = L["Honor: "] .. " 22000",                                        container = { 33772 } }, -- Strategist's Dragonhide Hauberk
		{ id = 33779, disc = L["Honor: "] .. " 20000",                                        container = { 33773 } }, -- Strategist's Dragonhide Gloves
		{ id = 33780, disc = L["Honor: "] .. " 22000",                                        container = { 33774 } }, -- Strategist's Dragonhide Leggings
		{ id = 33781, disc = L["Honor: "] .. " 18000",                                        container = { 33775 } }, -- Strategist's Dragonhide Boots
		{},
		{},
		{ id = 33560, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33554 } }, -- Executor's Dragonhide Helmet
		{ id = 33561, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33555 } }, -- Executor's Dragonhide Epaulets
		{ id = 33562, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33556 } }, -- Executor's Dragonhide Hauberk
		{ id = 33563, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33557 } }, -- Executor's Dragonhide Gloves
		{ id = 33564, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33558 } }, -- Executor's Dragonhide Leggings
		{ id = 33565, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33559 } }, -- Executor's Dragonhide Boots
		{},
		{ id = 33782, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33776 } }, -- Executor's Dragonhide Helmet
		{ id = 33783, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33777 } }, -- Executor's Dragonhide Epaulets
		{ id = 33784, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33778 } }, -- Executor's Dragonhide Hauberk
		{ id = 33785, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33779 } }, -- Executor's Dragonhide Gloves
		{ id = 33786, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33780 } }, -- Executor's Dragonhide Leggings
		{ id = 33787, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33781 } }, -- Executor's Dragonhide Boots
		{},
		{},
		{ id = 33566, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Dragonhide Helmet
		{ id = 33567, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Dragonhide Epaulets
		{ id = 33568, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Dragonhide Hauberk
		{ id = 33569, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Dragonhide Gloves
		{ id = 33570, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Dragonhide Leggings
		{ id = 33571, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Dragonhide Boots
		{},
		{ id = 33788, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Dragonhide Helmet
		{ id = 33789, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Dragonhide Epaulets
		{ id = 33790, disc = L["Honor: "] .. " 5000" }, -- Corpsman's Dragonhide Hauberk
		{ id = 33791, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Dragonhide Gloves
		{ id = 33792, disc = L["Honor: "] .. " 4000" }, -- Corpsman's Dragonhide Leggings
		{ id = 33793, disc = L["Honor: "] .. " 3000" }, -- Corpsman's Dragonhide Boots
		{},
		{},
		{ id = 33572, disc = L["Honor: "] .. " 19000",                                        container = { 33566 } }, -- Physician's Dragonhide Helmet
		{ id = 33573, disc = L["Honor: "] .. " 19000",                                        container = { 33567 } }, -- Physician's Dragonhide Epaulets
		{ id = 33574, disc = L["Honor: "] .. " 22000",                                        container = { 33568 } }, -- Physician's Dragonhide Hauberk
		{ id = 33575, disc = L["Honor: "] .. " 20000",                                        container = { 33569 } }, -- Physician's Dragonhide Gloves
		{ id = 33576, disc = L["Honor: "] .. " 22000",                                        container = { 33570 } }, -- Physician's Dragonhide Leggings
		{ id = 33577, disc = L["Honor: "] .. " 18000",                                        container = { 33571 } }, -- Physician's Dragonhide Boots
		{},
		{ id = 33794, disc = L["Honor: "] .. " 19000",                                        container = { 33788 } }, -- Physician's Dragonhide Helmet
		{ id = 33795, disc = L["Honor: "] .. " 19000",                                        container = { 33789 } }, -- Physician's Dragonhide Epaulets
		{ id = 33796, disc = L["Honor: "] .. " 22000",                                        container = { 33790 } }, -- Physician's Dragonhide Hauberk
		{ id = 33797, disc = L["Honor: "] .. " 20000",                                        container = { 33791 } }, -- Physician's Dragonhide Gloves
		{ id = 33798, disc = L["Honor: "] .. " 22000",                                        container = { 33792 } }, -- Physician's Dragonhide Leggings
		{ id = 33799, disc = L["Honor: "] .. " 18000",                                        container = { 33793 } }, -- Physician's Dragonhide Boots
		{},
		{},
		{ id = 33578, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33572 } }, -- Field Medic's Dragonhide Helmet
		{ id = 33579, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33573 } }, -- Field Medic's Dragonhide Epaulets
		{ id = 33580, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33574 } }, -- Field Medic's Dragonhide Hauberk
		{ id = 33581, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33575 } }, -- Field Medic's Dragonhide Gloves
		{ id = 33582, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33576 } }, -- Field Medic's Dragonhide Leggings
		{ id = 33583, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33577 } }, -- Field Medic's Dragonhide Boots
		{},
		{ id = 33800, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33794 } }, -- Field Medic's Dragonhide Helmet
		{ id = 33801, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33795 } }, -- Field Medic's Dragonhide Epaulets
		{ id = 33802, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33796 } }, -- Field Medic's Dragonhide Hauberk
		{ id = 33803, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33797 } }, -- Field Medic's Dragonhide Gloves
		{ id = 33804, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33798 } }, -- Field Medic's Dragonhide Leggings
		{ id = 33805, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33799 } }, -- Field Medic's Dragonhide Boots
	},
	PVPShaman1181 = {
		{ id = 33476, disc = L["Honor: "] .. " 5000" },                                                          -- Combatant's Mail Helm
		{ id = 33477, disc = L["Honor: "] .. " 4000" },                                                          -- Combatant's Mail Shoulders
		{ id = 33478, disc = L["Honor: "] .. " 5000" },                                                          -- Combatant's Mail Armor
		{ id = 33479, disc = L["Honor: "] .. " 3000" },                                                          -- Combatant's Mail Gauntlets
		{ id = 33480, disc = L["Honor: "] .. " 4000" },                                                          -- Combatant's Mail Leggings
		{ id = 33481, disc = L["Honor: "] .. " 3000" },                                                          -- Combatant's Mail Boots
		{},
		{ id = 33482, disc = L["Honor: "] .. " 19000",                                        container = { 33476 } }, -- Partisan's Mail Helm
		{ id = 33483, disc = L["Honor: "] .. " 19000",                                        container = { 33477 } }, -- Partisan's Mail Shoulders
		{ id = 33484, disc = L["Honor: "] .. " 22000",                                        container = { 33478 } }, -- Partisan's Mail Armor
		{ id = 33485, disc = L["Honor: "] .. " 20000",                                        container = { 33479 } }, -- Partisan's Mail Gauntlets
		{ id = 33486, disc = L["Honor: "] .. " 22000",                                        container = { 33480 } }, -- Partisan's Mail Leggings
		{ id = 33487, disc = L["Honor: "] .. " 18000",                                        container = { 33481 } }, -- Partisan's Mail Boots
		{},
		{},
		{ id = 33488, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33482 } }, -- Veteran's Mail Helm
		{ id = 33489, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33483 } }, -- Veteran's Mail Shoulders
		{ id = 33490, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33484 } }, -- Veteran's Mail Armor
		{ id = 33491, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33485 } }, -- Veteran's Mail Gauntlets
		{ id = 33492, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33486 } }, -- Veteran's Mail Leggings
		{ id = 33493, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33487 } }, -- Veteran's Mail Sabatons
		{},
		{ id = 33494, disc = L["Honor: "] .. " 5000" },                                                          -- Tactician's Mail Helm
		{ id = 33495, disc = L["Honor: "] .. " 4000" },                                                          -- Tactician's Mail Spaulders
		{ id = 33496, disc = L["Honor: "] .. " 5000" },                                                          -- Tactician's Mail Armor
		{ id = 33497, disc = L["Honor: "] .. " 3000" },                                                          -- Tactician's Mail Gauntlets
		{ id = 33498, disc = L["Honor: "] .. " 4000" },                                                          -- Tactician's Mail Leggings
		{ id = 33499, disc = L["Honor: "] .. " 3000" },                                                          -- Tactician's Mail Boots
		{},
		{},
		{ id = 33500, disc = L["Honor: "] .. " 19000",                                        container = { 33494 } }, -- Strategist's Mail Helm
		{ id = 33501, disc = L["Honor: "] .. " 19000",                                        container = { 33495 } }, -- Strategist's Mail Shoulders
		{ id = 33502, disc = L["Honor: "] .. " 22000",                                        container = { 33496 } }, -- Strategist's Mail Armor
		{ id = 33503, disc = L["Honor: "] .. " 20000",                                        container = { 33497 } }, -- Strategist's Mail Gauntlets
		{ id = 33504, disc = L["Honor: "] .. " 22000",                                        container = { 33498 } }, -- Strategist's Mail Leggings
		{ id = 33505, disc = L["Honor: "] .. " 18000",                                        container = { 33499 } }, -- Strategist's Mail Boots
		{},
		{ id = 33506, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33500 } }, -- Executor's Mail Helm
		{ id = 33507, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33501 } }, -- Executor's Mail Shoulders
		{ id = 33508, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33502 } }, -- Executor's Mail Armor
		{ id = 33509, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33503 } }, -- Executor's Mail Gauntlets
		{ id = 33510, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33504 } }, -- Executor's Mail Leggings
		{ id = 33511, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33505 } }, -- Executor's Mail Sabatons
		{},
		{},
		{ id = 33512, disc = L["Honor: "] .. " 5000" },                                                          -- Corpsman's Mail Helm
		{ id = 33513, disc = L["Honor: "] .. " 4000" },                                                          -- Corpsman's Mail Spaulders
		{ id = 33514, disc = L["Honor: "] .. " 5000" },                                                          -- Corpsman's Mail Armor
		{ id = 33515, disc = L["Honor: "] .. " 3000" },                                                          -- Corpsman's Mail Gauntlets
		{ id = 33516, disc = L["Honor: "] .. " 4000" },                                                          -- Corpsman's Mail Leggings
		{ id = 33517, disc = L["Honor: "] .. " 3000" },                                                          -- Corpsman's Mail Boots
		{},
		{ id = 33518, disc = L["Honor: "] .. " 19000",                                        container = { 33512 } }, -- Physician's Mail Helm
		{ id = 33519, disc = L["Honor: "] .. " 19000",                                        container = { 33513 } }, -- Physician's Mail Spaulders
		{ id = 33520, disc = L["Honor: "] .. " 22000",                                        container = { 33514 } }, -- Physician's Mail Armor
		{ id = 33521, disc = L["Honor: "] .. " 20000",                                        container = { 33515 } }, -- Physician's Mail Gauntlets
		{ id = 33522, disc = L["Honor: "] .. " 22000",                                        container = { 33516 } }, -- Physician's Mail Leggings
		{ id = 33523, disc = L["Honor: "] .. " 18000",                                        container = { 33517 } }, -- Physician's Mail Boots
		{},
		{},
		{ id = 33524, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33518 } }, -- Field Medic's Mail Helmet
		{ id = 33525, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33519 } }, -- Field Medic's Mail Shoulders
		{ id = 33526, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33520 } }, -- Field Medic's Mail Armor
		{ id = 33527, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33521 } }, -- Field Medic's Mail Gauntlets
		{ id = 33528, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33522 } }, -- Field Medic's Mail Leggings
		{ id = 33529, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33523 } }, -- Field Medic's Mail Boots
	},
	PVPWarrior1181 = {
		{ id = 33404, disc = L["Honor: "] .. " 5000" }, -- Combatant's Plate Helm
		{ id = 33405, disc = L["Honor: "] .. " 4000" }, -- Combatant's Plate Shoulderguards
		{ id = 33406, disc = L["Honor: "] .. " 5000" }, -- Combatant's Plate Armor
		{ id = 33407, disc = L["Honor: "] .. " 3000" }, -- Combatant's Plate Gauntlets
		{ id = 33408, disc = L["Honor: "] .. " 4000" }, -- Combatant's Plate Leggings
		{ id = 33409, disc = L["Honor: "] .. " 3000" }, -- Combatant's Plate Boots
		{},
		{ id = 33680, disc = L["Honor: "] .. " 5000" }, -- Combatant's Plate Helm
		{ id = 33681, disc = L["Honor: "] .. " 4000" }, -- Combatant's Plate Shoulderguards
		{ id = 33682, disc = L["Honor: "] .. " 5000" }, -- Combatant's Plate Armor
		{ id = 33683, disc = L["Honor: "] .. " 3000" }, -- Combatant's Plate Gauntlets
		{ id = 33684, disc = L["Honor: "] .. " 4000" }, -- Combatant's Plate Leggings
		{ id = 33685, disc = L["Honor: "] .. " 3000" }, -- Combatant's Plate Boots
		{},
		{},
		{ id = 33410, disc = L["Honor: "] .. " 19000",                                        container = { 33404 } }, -- Partisan's Plate Helm
		{ id = 33411, disc = L["Honor: "] .. " 19000",                                        container = { 33405 } }, -- Partisan's Plate Shoulderguards
		{ id = 33412, disc = L["Honor: "] .. " 22000",                                        container = { 33406 } }, -- Partisan's Plate Armor
		{ id = 33413, disc = L["Honor: "] .. " 20000",                                        container = { 33407 } }, -- Partisan's Plate Gauntlets
		{ id = 33414, disc = L["Honor: "] .. " 22000",                                        container = { 33408 } }, -- Partisan's Plate Leggings
		{ id = 33415, disc = L["Honor: "] .. " 18000",                                        container = { 33409 } }, -- Partisan's Plate Boots
		{},
		{ id = 33686, disc = L["Honor: "] .. " 19000",                                        container = { 33680 } }, -- Partisan's Plate Helm
		{ id = 33687, disc = L["Honor: "] .. " 19000",                                        container = { 33681 } }, -- Partisan's Plate Shoulderguards
		{ id = 33688, disc = L["Honor: "] .. " 22000",                                        container = { 33682 } }, -- Partisan's Plate Armor
		{ id = 33689, disc = L["Honor: "] .. " 20000",                                        container = { 33683 } }, -- Partisan's Plate Gauntlets
		{ id = 33690, disc = L["Honor: "] .. " 22000",                                        container = { 33684 } }, -- Partisan's Plate Leggings
		{ id = 33691, disc = L["Honor: "] .. " 18000",                                        container = { 33685 } }, -- Partisan's Plate Boots
		{},
		{},
		{ id = 33416, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33410 } }, -- Veteran's Plate Helm
		{ id = 33417, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33411 } }, -- Veteran's Plate Shoulderguards
		{ id = 33418, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33412 } }, -- Veteran's Plate Armor
		{ id = 33419, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33413 } }, -- Veteran's Plate Gauntlets
		{ id = 33420, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33414 } }, -- Veteran's Plate Leggings
		{ id = 33421, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33415 } }, -- Veteran's Plate Boots
		{},
		{ id = 33692, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33686 } }, -- Veteran's Plate Helm
		{ id = 33693, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33687 } }, -- Veteran's Plate Shoulderguards
		{ id = 33694, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33688 } }, -- Veteran's Plate Armor
		{ id = 33695, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33689 } }, -- Veteran's Plate Gauntlets
		{ id = 33696, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33690 } }, -- Veteran's Plate Leggings
		{ id = 33697, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33691 } }, -- Veteran's Plate Boots
	},
	PVPPaladin1181 = {
		{ id = 33584, disc = L["Honor: "] .. " 5000" },                                                          -- Combatant's Lamellar Faceguard
		{ id = 33585, disc = L["Honor: "] .. " 4000" },                                                          -- Combatant's Lamellar Shoulders
		{ id = 33586, disc = L["Honor: "] .. " 5000" },                                                          -- Combatant's Lamellar Chestplate
		{ id = 33587, disc = L["Honor: "] .. " 3000" },                                                          -- Combatant's Lamellar Gauntlets
		{ id = 33588, disc = L["Honor: "] .. " 4000" },                                                          -- Combatant's Lamellar Legplates
		{ id = 33589, disc = L["Honor: "] .. " 3000" },                                                          -- Combatant's Lamellar Sabatons
		{},
		{ id = 33590, disc = L["Honor: "] .. " 19000",                                        container = { 33584 } }, -- Partisan's Lamellar Faceguard
		{ id = 33591, disc = L["Honor: "] .. " 19000",                                        container = { 33585 } }, -- Partisan's Lamellar Shoulders
		{ id = 33592, disc = L["Honor: "] .. " 22000",                                        container = { 33586 } }, -- Partisan's Lamellar Chestplate
		{ id = 33593, disc = L["Honor: "] .. " 20000",                                        container = { 33587 } }, -- Partisan's Lamellar Gauntlets
		{ id = 33594, disc = L["Honor: "] .. " 22000",                                        container = { 33588 } }, -- Partisan's Lamellar Legplates
		{ id = 33595, disc = L["Honor: "] .. " 18000",                                        container = { 33589 } }, -- Partisan's Lamellar Sabatons
		{},
		{},
		{ id = 33596, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33590 } }, -- Veteran's Lamellar Faceguard
		{ id = 33597, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33591 } }, -- Veteran's Lamellar Shoulders
		{ id = 33598, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33592 } }, -- Veteran's Lamellar Chestplate
		{ id = 33599, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33593 } }, -- Veteran's Lamellar Gauntlets
		{ id = 33600, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33594 } }, -- Veteran's Lamellar Legplates
		{ id = 33601, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33595 } }, -- Veteran's Lamellar Sabatons
		{},
		{ id = 33602, disc = L["Honor: "] .. " 5000" },                                                          -- Corpsman's Lamellar Faceguard
		{ id = 33603, disc = L["Honor: "] .. " 4000" },                                                          -- Corpsman's Lamellar Pauldrons
		{ id = 33604, disc = L["Honor: "] .. " 5000" },                                                          -- Corpsman's Lamellar Chestplate
		{ id = 33605, disc = L["Honor: "] .. " 3000" },                                                          -- Corpsman's Lamellar Gloves
		{ id = 33606, disc = L["Honor: "] .. " 4000" },                                                          -- Corpsman's Lamellar Legplates
		{ id = 33607, disc = L["Honor: "] .. " 3000" },                                                          -- Corpsman's Lamellar Sabatons
		{},
		{},
		{ id = 33608, disc = L["Honor: "] .. " 19000",                                        container = { 33602 } }, -- Physician's Lamellar Faceguard
		{ id = 33609, disc = L["Honor: "] .. " 19000",                                        container = { 33603 } }, -- Physician's Lamellar Pauldrons
		{ id = 33610, disc = L["Honor: "] .. " 22000",                                        container = { 33604 } }, -- Physician's Lamellar Chestplate
		{ id = 33611, disc = L["Honor: "] .. " 20000",                                        container = { 33605 } }, -- Physician's Lamellar Gloves
		{ id = 33612, disc = L["Honor: "] .. " 22000",                                        container = { 33606 } }, -- Physician's Lamellar Legplates
		{ id = 33613, disc = L["Honor: "] .. " 18000",                                        container = { 33607 } }, -- Physician's Lamellar Boots
		{},
		{ id = 33614, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33608 } }, -- Field Medic's Lamellar Faceguard
		{ id = 33615, disc = L["Honor: "] .. " 65000, " .. L["Conquest Points: "] .. " 3500", container = { 33609 } }, -- Field Medic's Lamellar Shoulders
		{ id = 33616, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33610 } }, -- Field Medic's Lamellar Chestplate
		{ id = 33617, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33611 } }, -- Field Medic's Lamellar Gloves
		{ id = 33618, disc = L["Honor: "] .. " 69000, " .. L["Conquest Points: "] .. " 4000", container = { 33612 } }, -- Field Medic's Lamellar Legplates
		{ id = 33619, disc = L["Honor: "] .. " 54000, " .. L["Conquest Points: "] .. " 3000", container = { 33613 } }, -- Field Medic's Lamellar Sabatons
	},
	PVPHunter = {
		{ name = LIS["Field Marshal's Pursuit"],          icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 16465,                                     disc = L["Rank"] .. " 13" }, -- Field Marshal's Chain Helm
		{ id = 16468,                                     disc = L["Rank"] .. " 13" }, -- Field Marshal's Chain Spaulders
		{ id = 16466,                                     disc = L["Rank"] .. " 13" }, -- Field Marshal's Chain Breastplate
		{ id = 16463,                                     disc = L["Rank"] .. " 12" }, -- Marshal's Chain Grips
		{ id = 16467,                                     disc = L["Rank"] .. " 12" }, -- Marshal's Chain Legguards
		{ id = 16462,                                     disc = L["Rank"] .. " 12" }, -- Marshal's Chain Boots
		{},
		{ name = LIS["Lieutenant Commander's Pursuance"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23306,                                     disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Chain Helm
		{ id = 23307,                                     disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Chain Shoulders
		{ id = 23292,                                     disc = L["Rank"] .. " 8" }, -- Knight-Captain's Chain Hauberk
		{ id = 23279,                                     disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Chain Vices
		{ id = 23293,                                     disc = L["Rank"] .. " 8" }, -- Knight-Captain's Chain Legguards
		{ id = 23278,                                     disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Chain Greaves
		{ name = LIS["Warlord's Pursuit"],                icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 16566,                                     disc = L["Rank"] .. " 13" }, -- Warlord's Chain Helmet
		{ id = 16568,                                     disc = L["Rank"] .. " 13" }, -- Warlord's Chain Shoulders
		{ id = 16565,                                     disc = L["Rank"] .. " 13" }, -- Warlord's Chain Chestpiece
		{ id = 16571,                                     disc = L["Rank"] .. " 12" }, -- General's Chain Gloves
		{ id = 16567,                                     disc = L["Rank"] .. " 12" }, -- General's Chain Legguards
		{ id = 16569,                                     disc = L["Rank"] .. " 12" }, -- General's Chain Boots
		{},
		{ name = LIS["Champion's Pursuance"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23251,                                     disc = L["Rank"] .. " 10" }, -- Champion's Chain Helm
		{ id = 23252,                                     disc = L["Rank"] .. " 10" }, -- Champion's Chain Shoulders
		{ id = 22874,                                     disc = L["Rank"] .. " 8" }, -- Legionnaire's Chain Hauberk
		{ id = 22862,                                     disc = L["Rank"] .. " 7" }, -- Blood Guard's Chain Vices
		{ id = 22875,                                     disc = L["Rank"] .. " 8" }, -- Legionnaire's Chain Legguards
		{ id = 22843,                                     disc = L["Rank"] .. " 7" }, -- Blood Guard's Chain Greaves
	},
	PVPMage = {
		{ name = LIS["Field Marshal's Regalia"],        icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 16441,                                   disc = L["Rank"] .. " 13" }, -- Field Marshal's Coronet
		{ id = 16444,                                   disc = L["Rank"] .. " 13" }, -- Field Marshal's Silk Spaulders
		{ id = 16443,                                   disc = L["Rank"] .. " 13" }, -- Field Marshal's Silk Vestments
		{ id = 16440,                                   disc = L["Rank"] .. " 12" }, -- Marshal's Silk Gloves
		{ id = 16442,                                   disc = L["Rank"] .. " 12" }, -- Marshal's Silk Leggings
		{ id = 16437,                                   disc = L["Rank"] .. " 12" }, -- Marshal's Silk Footwraps
		{},
		{ name = LIS["Lieutenant Commander's Arcanum"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23318,                                   disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Silk Cowl
		{ id = 23319,                                   disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Silk Mantle
		{ id = 23305,                                   disc = L["Rank"] .. " 8" }, -- Knight-Captain's Silk Tunic
		{ id = 23290,                                   disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Silk Handwraps
		{ id = 23304,                                   disc = L["Rank"] .. " 8" }, -- Knight-Captain's Silk Legguards
		{ id = 23291,                                   disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Silk Walkers
		{ name = LIS["Warlord's Regalia"],              icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 16533,                                   disc = L["Rank"] .. " 13" }, -- Warlord's Silk Cowl
		{ id = 16536,                                   disc = L["Rank"] .. " 13" }, -- Warlord's Silk Amice
		{ id = 16535,                                   disc = L["Rank"] .. " 13" }, -- Warlord's Silk Raiment
		{ id = 16540,                                   disc = L["Rank"] .. " 12" }, -- General's Silk Handguards
		{ id = 16534,                                   disc = L["Rank"] .. " 12" }, -- General's Silk Trousers
		{ id = 16539,                                   disc = L["Rank"] .. " 12" }, -- General's Silk Boots
		{},
		{ name = LIS["Champion's Arcanum"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23263,                                   disc = L["Rank"] .. " 10" }, -- Champion's Silk Cowl
		{ id = 23264,                                   disc = L["Rank"] .. " 10" }, -- Champion's Silk Mantle
		{ id = 22886,                                   disc = L["Rank"] .. " 8" }, -- Legionnaire's Silk Tunic
		{ id = 22870,                                   disc = L["Rank"] .. " 7" }, -- Blood Guard's Silk Handwraps
		{ id = 22883,                                   disc = L["Rank"] .. " 8" }, -- Legionnaire's Silk Legguards
		{ id = 22860,                                   disc = L["Rank"] .. " 7" }, -- Blood Guard's Silk Walkers
	},
	PVPPriest = {
		{ name = LIS["Field Marshal's Raiment"],            icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 17602,                                       disc = L["Rank"] .. " 13" }, -- Field Marshal's Headdress
		{ id = 17604,                                       disc = L["Rank"] .. " 13" }, -- Field Marshal's Satin Mantle
		{ id = 17605,                                       disc = L["Rank"] .. " 13" }, -- Field Marshal's Satin Vestments
		{ id = 17608,                                       disc = L["Rank"] .. " 12" }, -- Marshal's Satin Gloves
		{ id = 17603,                                       disc = L["Rank"] .. " 12" }, -- Marshal's Satin Pants
		{ id = 17607,                                       disc = L["Rank"] .. " 12" }, -- Marshal's Satin Sandals
		{},
		{ name = LIS["Lieutenant Commander's Investiture"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23316,                                       disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Satin Hood
		{ id = 23317,                                       disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Satin Mantle
		{ id = 23303,                                       disc = L["Rank"] .. " 8" }, -- Knight-Captain's Satin Tunic
		{ id = 23288,                                       disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Satin Handwraps
		{ id = 23302,                                       disc = L["Rank"] .. " 8" }, -- Knight-Captain's Satin Legguards
		{ id = 23289,                                       disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Satin Walkers
		{ name = LIS["Warlord's Raiment"],                  icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 17623,                                       disc = L["Rank"] .. " 13" }, -- Warlord's Satin Cowl
		{ id = 17622,                                       disc = L["Rank"] .. " 13" }, -- Warlord's Satin Mantle
		{ id = 17624,                                       disc = L["Rank"] .. " 13" }, -- Warlord's Satin Robes
		{ id = 17620,                                       disc = L["Rank"] .. " 12" }, -- General's Satin Gloves
		{ id = 17625,                                       disc = L["Rank"] .. " 12" }, -- General's Satin Leggings
		{ id = 17618,                                       disc = L["Rank"] .. " 12" }, -- General's Satin Boots
		{},
		{ name = LIS["Champion's Investiture"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23261,                                       disc = L["Rank"] .. " 10" }, -- Champion's Satin Hood
		{ id = 23262,                                       disc = L["Rank"] .. " 10" }, -- Champion's Satin Mantle
		{ id = 22885,                                       disc = L["Rank"] .. " 8" }, -- Legionnaire's Satin Tunic
		{ id = 22869,                                       disc = L["Rank"] .. " 7" }, -- Blood Guard's Satin Handwraps
		{ id = 22882,                                       disc = L["Rank"] .. " 8" }, -- Legionnaire's Satin Legguards
		{ id = 22859,                                       disc = L["Rank"] .. " 7" }, -- Blood Guard's Satin Walkers
	},
	PVPWarlock = {
		{ name = LIS["Field Marshal's Threads"],          icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 17578,                                     disc = L["Rank"] .. " 13" }, -- Field Marshal's Coronal
		{ id = 17580,                                     disc = L["Rank"] .. " 13" }, -- Field Marshal's Dreadweave Shoulders
		{ id = 17581,                                     disc = L["Rank"] .. " 13" }, -- Field Marshal's Dreadweave Robe
		{ id = 17584,                                     disc = L["Rank"] .. " 12" }, -- Marshal's Dreadweave Gloves
		{ id = 17579,                                     disc = L["Rank"] .. " 12" }, -- Marshal's Dreadweave Leggings
		{ id = 17583,                                     disc = L["Rank"] .. " 12" }, -- Marshal's Dreadweave Boots
		{},
		{ name = LIS["Lieutenant Commander's Dreadgear"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23310,                                     disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Dreadweave Cowl
		{ id = 23311,                                     disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Dreadweave Spaulders
		{ id = 23297,                                     disc = L["Rank"] .. " 8" }, -- Knight-Captain's Dreadweave Tunic
		{ id = 23282,                                     disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Dreadweave Handwraps
		{ id = 23296,                                     disc = L["Rank"] .. " 8" }, -- Knight-Captain's Dreadweave Legguards
		{ id = 23283,                                     disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Dreadweave Walkers
		{ name = LIS["Warlord's Threads"],                icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 17591,                                     disc = L["Rank"] .. " 13" }, -- Warlord's Dreadweave Hood
		{ id = 17590,                                     disc = L["Rank"] .. " 13" }, -- Warlord's Dreadweave Mantle
		{ id = 17592,                                     disc = L["Rank"] .. " 13" }, -- Warlord's Dreadweave Robe
		{ id = 17588,                                     disc = L["Rank"] .. " 12" }, -- General's Dreadweave Gloves
		{ id = 17593,                                     disc = L["Rank"] .. " 12" }, -- General's Dreadweave Pants
		{ id = 17586,                                     disc = L["Rank"] .. " 12" }, -- General's Dreadweave Boots
		{},
		{ name = LIS["Champion's Dreadgear"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23255,                                     disc = L["Rank"] .. " 10" }, -- Champion's Dreadweave Cowl
		{ id = 23256,                                     disc = L["Rank"] .. " 10" }, -- Champion's Dreadweave Spaulders
		{ id = 22884,                                     disc = L["Rank"] .. " 8" }, -- Legionnaire's Dreadweave Tunic
		{ id = 22865,                                     disc = L["Rank"] .. " 7" }, -- Blood Guard's Dreadweave Handwraps
		{ id = 22881,                                     disc = L["Rank"] .. " 8" }, -- Legionnaire's Dreadweave Legguards
		{ id = 22855,                                     disc = L["Rank"] .. " 7" }, -- Blood Guard's Dreadweave Walkers
	},
	PVPRogue = {
		{ name = LIS["Field Marshal's Vestments"],    icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 16455,                                 disc = L["Rank"] .. " 13" }, -- Field Marshal's Leather Mask
		{ id = 16457,                                 disc = L["Rank"] .. " 13" }, -- Field Marshal's Leather Epaulets
		{ id = 16453,                                 disc = L["Rank"] .. " 13" }, -- Field Marshal's Leather Chestpiece
		{ id = 16454,                                 disc = L["Rank"] .. " 12" }, -- Marshal's Leather Handgrips
		{ id = 16456,                                 disc = L["Rank"] .. " 12" }, -- Marshal's Leather Leggings
		{ id = 16446,                                 disc = L["Rank"] .. " 12" }, -- Marshal's Leather Footguards
		{},
		{ name = LIS["Lieutenant Commander's Guard"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23312,                                 disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Leather Helm
		{ id = 23313,                                 disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Leather Shoulders
		{ id = 23298,                                 disc = L["Rank"] .. " 8" }, -- Knight-Captain's Leather Chestpiece
		{ id = 23284,                                 disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Leather Grips
		{ id = 23299,                                 disc = L["Rank"] .. " 8" }, -- Knight-Captain's Leather Legguards
		{ id = 23285,                                 disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Leather Walkers
		{ name = LIS["Warlord's Vestments"],          icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 16561,                                 disc = L["Rank"] .. " 13" }, -- Warlord's Leather Helm
		{ id = 16562,                                 disc = L["Rank"] .. " 13" }, -- Warlord's Leather Spaulders
		{ id = 16563,                                 disc = L["Rank"] .. " 13" }, -- Warlord's Leather Breastplate
		{ id = 16560,                                 disc = L["Rank"] .. " 12" }, -- General's Leather Mitts
		{ id = 16564,                                 disc = L["Rank"] .. " 12" }, -- General's Leather Legguards
		{ id = 16558,                                 disc = L["Rank"] .. " 12" }, -- General's Leather Treads
		{},
		{ name = LIS["Champion's Guard"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23257,                                 disc = L["Rank"] .. " 10" }, -- Champion's Leather Helm
		{ id = 23258,                                 disc = L["Rank"] .. " 10" }, -- Champion's Leather Shoulders
		{ id = 22879,                                 disc = L["Rank"] .. " 8" }, -- Legionnaire's Leather Chestpiece
		{ id = 22864,                                 disc = L["Rank"] .. " 7" }, -- Blood Guard's Leather Grips
		{ id = 22880,                                 disc = L["Rank"] .. " 8" }, -- Legionnaire's Leather Legguards
		{ id = 22856,                                 disc = L["Rank"] .. " 7" }, -- Blood Guard's Leather Walkers
	},
	PVPDruid = {
		{ name = LIS["Field Marshal's Sanctuary"],     icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 16451,                                  disc = L["Rank"] .. " 13" }, -- Field Marshal's Dragonhide Helmet
		{ id = 16449,                                  disc = L["Rank"] .. " 13" }, -- Field Marshal's Dragonhide Spaulders
		{ id = 16452,                                  disc = L["Rank"] .. " 13" }, -- Field Marshal's Dragonhide Breastplate
		{ id = 16448,                                  disc = L["Rank"] .. " 12" }, -- Marshal's Dragonhide Gauntlets
		{ id = 16450,                                  disc = L["Rank"] .. " 12" }, -- Marshal's Dragonhide Legguards
		{ id = 16459,                                  disc = L["Rank"] .. " 12" }, -- Marshal's Dragonhide Boots
		{},
		{ name = LIS["Lieutenant Commander's Refuge"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23308,                                  disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Dragonhide Headguard
		{ id = 23309,                                  disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Dragonhide Shoulders
		{ id = 23294,                                  disc = L["Rank"] .. " 8" }, -- Knight-Captain's Dragonhide Chestpiece
		{ id = 23280,                                  disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Dragonhide Grips
		{ id = 23295,                                  disc = L["Rank"] .. " 8" }, -- Knight-Captain's Dragonhide Leggings
		{ id = 23281,                                  disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Dragonhide Treads
		{ name = LIS["Warlord's Sanctuary"],           icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 16550,                                  disc = L["Rank"] .. " 13" }, -- Warlord's Dragonhide Helmet
		{ id = 16551,                                  disc = L["Rank"] .. " 13" }, -- Warlord's Dragonhide Epaulets
		{ id = 16549,                                  disc = L["Rank"] .. " 13" }, -- Warlord's Dragonhide Hauberk
		{ id = 16555,                                  disc = L["Rank"] .. " 12" }, -- General's Dragonhide Gloves
		{ id = 16552,                                  disc = L["Rank"] .. " 12" }, -- General's Dragonhide Leggings
		{ id = 16554,                                  disc = L["Rank"] .. " 12" }, -- General's Dragonhide Boots
		{},
		{ name = LIS["Champion's Refuge"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23253,                                  disc = L["Rank"] .. " 10" }, -- Champion's Dragonhide Headguard
		{ id = 23254,                                  disc = L["Rank"] .. " 10" }, -- Champion's Dragonhide Shoulders
		{ id = 22877,                                  disc = L["Rank"] .. " 8" }, -- Legionnaire's Dragonhide Chestpiece
		{ id = 22863,                                  disc = L["Rank"] .. " 7" }, -- Blood Guard's Dragonhide Grips
		{ id = 22878,                                  disc = L["Rank"] .. " 8" }, -- Legionnaire's Dragonhide Leggings
		{ id = 22852,                                  disc = L["Rank"] .. " 7" }, -- Blood Guard's Dragonhide Treads
	},
	PVPShaman = {
		{ name = LIS["Warlord's Earthshaker"],  icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 16578,                           disc = L["Rank"] .. " 13" }, -- Warlord's Mail Helm
		{ id = 16580,                           disc = L["Rank"] .. " 13" }, -- Warlord's Mail Spaulders
		{ id = 16577,                           disc = L["Rank"] .. " 13" }, -- Warlord's Mail Armor
		{ id = 16574,                           disc = L["Rank"] .. " 12" }, -- General's Mail Gauntlets
		{ id = 16579,                           disc = L["Rank"] .. " 12" }, -- General's Mail Leggings
		{ id = 16573,                           disc = L["Rank"] .. " 12" }, -- General's Mail Boots
		{},
		{ name = LIS["Champion's Stormcaller"], icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23259,                           disc = L["Rank"] .. " 10" }, -- Champion's Mail Headguard
		{ id = 23260,                           disc = L["Rank"] .. " 10" }, -- Champion's Mail Pauldrons
		{ id = 22876,                           disc = L["Rank"] .. " 8" }, -- Legionnaire's Mail Hauberk
		{ id = 22867,                           disc = L["Rank"] .. " 7" }, -- Blood Guard's Mail Vices
		{ id = 22887,                           disc = L["Rank"] .. " 8" }, -- Legionnaire's Mail Legguards
		{ id = 22857,                           disc = L["Rank"] .. " 7" }, -- Blood Guard's Mail Greaves
	},
	PVPWarrior = {
		{ name = LIS["Field Marshal's Battlegear"],         icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 16478,                                       disc = L["Rank"] .. " 13" }, -- Field Marshal's Plate Helm
		{ id = 16480,                                       disc = L["Rank"] .. " 13" }, -- Field Marshal's Plate Shoulderguards
		{ id = 16477,                                       disc = L["Rank"] .. " 13" }, -- Field Marshal's Plate Armor
		{ id = 16484,                                       disc = L["Rank"] .. " 12" }, -- Marshal's Plate Gauntlets
		{ id = 16479,                                       disc = L["Rank"] .. " 12" }, -- Marshal's Plate Legguards
		{ id = 16483,                                       disc = L["Rank"] .. " 12" }, -- Marshal's Plate Boots
		{},
		{ name = LIS["Lieutenant Commander's Battlearmor"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23314,                                       disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Plate Helm
		{ id = 23315,                                       disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Plate Shoulders
		{ id = 23300,                                       disc = L["Rank"] .. " 8" }, -- Knight-Captain's Plate Hauberk
		{ id = 23286,                                       disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Plate Gauntlets
		{ id = 23301,                                       disc = L["Rank"] .. " 8" }, -- Knight-Captain's Plate Leggings
		{ id = 23287,                                       disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Plate Greaves
		{ name = LIS["Warlord's Battlegear"],               icon = "INV_BannerPVP_01", extra = L["Epic Set"] },
		{ id = 16542,                                       disc = L["Rank"] .. " 13" }, -- Warlord's Plate Headpiece
		{ id = 16544,                                       disc = L["Rank"] .. " 13" }, -- Warlord's Plate Shoulders
		{ id = 16541,                                       disc = L["Rank"] .. " 13" }, -- Warlord's Plate Armor
		{ id = 16548,                                       disc = L["Rank"] .. " 12" }, -- General's Plate Gauntlets
		{ id = 16543,                                       disc = L["Rank"] .. " 12" }, -- General's Plate Leggings
		{ id = 16545,                                       disc = L["Rank"] .. " 12" }, -- General's Plate Boots
		{},
		{ name = LIS["Champion's Battlearmor"],             icon = "INV_BannerPVP_01", extra = L["Rare Set"] },
		{ id = 23244,                                       disc = L["Rank"] .. " 10" }, -- Champion's Plate Helm
		{ id = 23243,                                       disc = L["Rank"] .. " 10" }, -- Champion's Plate Shoulders
		{ id = 22872,                                       disc = L["Rank"] .. " 8" }, -- Legionnaire's Plate Hauberk
		{ id = 22868,                                       disc = L["Rank"] .. " 7" }, -- Blood Guard's Plate Gauntlets
		{ id = 22873,                                       disc = L["Rank"] .. " 8" }, -- Legionnaire's Plate Leggings
		{ id = 22858,                                       disc = L["Rank"] .. " 7" }, -- Blood Guard's Plate Greaves
	},
	PVPPaladin = {
		{ name = LIS["Field Marshal's Aegis"],          icon = "INV_BannerPVP_02", extra = L["Epic Set"] },
		{ id = 16474,                                   disc = L["Rank"] .. " 13" }, -- Field Marshal's Lamellar Faceguard
		{ id = 16476,                                   disc = L["Rank"] .. " 13" }, -- Field Marshal's Lamellar Pauldrons
		{ id = 16473,                                   disc = L["Rank"] .. " 13" }, -- Field Marshal's Lamellar Chestplate
		{ id = 16471,                                   disc = L["Rank"] .. " 12" }, -- Marshal's Lamellar Gloves
		{ id = 16475,                                   disc = L["Rank"] .. " 12" }, -- Marshal's Lamellar Legplates
		{ id = 16472,                                   disc = L["Rank"] .. " 12" }, -- Marshal's Lamellar Boots
		{},
		{ name = LIS["Lieutenant Commander's Redoubt"], icon = "INV_BannerPVP_02", extra = L["Rare Set"] },
		{ id = 23276,                                   disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Lamellar Headguard
		{ id = 23277,                                   disc = L["Rank"] .. " 10" }, -- Lieutenant Commander's Lamellar Shoulders
		{ id = 23272,                                   disc = L["Rank"] .. " 8" }, -- Knight-Captain's Lamellar Breastplate
		{ id = 23274,                                   disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Lamellar Gauntlets
		{ id = 23273,                                   disc = L["Rank"] .. " 8" }, -- Knight-Captain's Lamellar Leggings
		{ id = 23275,                                   disc = L["Rank"] .. " 7" }, -- Knight-Lieutenant's Lamellar Sabatons
	},
	PvPMountsPvP = {
		{ name = LF["Alliance"], icon = "INV_BannerPVP_02", extra = L["Rank"] .. " 11" },
		{ id = 19030 }, -- Stormpike Battle Charger
		{},
		{ id = 18244 }, -- Black War Ram
		{ id = 18243 }, -- Black Battlestrider
		{ id = 18241 }, -- Black War Steed Bridle
		{ id = 18242 }, -- Reins of the Black War Tiger
		{},
		{},
		{},
		{},
		{},
		{},
		{},
		{},
		{ name = LF["Horde"],    icon = "INV_BannerPVP_01", extra = L["Rank"] .. " 11" },
		{ id = 19029 }, -- Horn of the Frostwolf Howler
		{},
		{ id = 18245 }, -- Horn of the Black War Wolf
		{ id = 18247 }, -- Black War Kodo
		{ id = 18246 }, -- Whistle of the Black War Raptor
		{ id = 18248 }, -- Red Skeletal Warhorse
	}
}

for k, v in pairs(pvpRewards) do
	AtlasCFMLoot_Data[k] = v
end
