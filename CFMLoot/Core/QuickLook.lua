--- @file QuickLook.lua
--- @brief Manages the Quick Look functionality for AtlasCFMLoot.
--- This file provides functions to save, clear, and refresh quick access slots for frequently viewed loot tables.
--- It integrates with the Hewdrop-2.0 library for UI interactions and stores user-defined quick look data in AtlasCFMCharDB.

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}
AtlasCFM.QuickLook = {}

-- Local references for performance
local L = AtlasCFM.Localization.UI

local BLUE = AtlasCFM.Colors.BLUE
local WHITE = AtlasCFM.Colors.WHITE
---
--- Clears a specific QuickLook button assignment
--- Removes stored data and refreshes button states
--- @param button number QuickLook button number to clear (1-6)
--- @return nil
--- @usage AtlasCFM.QuickLook.ClearButton(3)
---
function AtlasCFM.QuickLook.ClearButton(button)
	if not button or button == nil then return end
	AtlasCFMCharDB["QuickLooks"][button] = nil
	AtlasCFM.QuickLook.RefreshButtons()
	PrintA(L["QuickLook"] .. " " .. button .. " " .. L["has been reset!"])
end

---
--- Opens Hewdrop menu to assign current loot table to QuickLook slots
--- @param button table Button frame that triggered the menu
--- @return void
--- @usage AtlasCFM.QuickLook.ShowMenu(button)
---
function AtlasCFM.QuickLook.ShowMenu(button)
	local Hewdrop = _G.ATWHewdrop
	if Hewdrop:IsOpen(button) then
		Hewdrop:Close(1)
	else
		local setOptions = function()
			for i = 1, 6 do
				local index = i
				Hewdrop:AddLine(
					"text", L["QuickLook"] .. " " .. i,
					"tooltipTitle", L["QuickLook"] .. " " .. i,
					"tooltipText", L["Assign this loot table to QuickLook"] .. " " .. i,
					"func", function()
						local dataID = AtlasCFMLootItemsFrame and AtlasCFMLootItemsFrame.StoredElement or nil
						local storedMenu = AtlasCFMLootItemsFrame and AtlasCFMLootItemsFrame.StoredMenu or nil
						if not AtlasCFMCharDB["QuickLooks"] then AtlasCFMCharDB["QuickLooks"] = {} end
						local titleText = nil
						if AtlasCFMLoot_LootPageName and AtlasCFMLoot_LootPageName:GetText() and AtlasCFMLoot_LootPageName:GetText() ~= "" then
							titleText = AtlasCFMLoot_LootPageName:GetText()
						elseif type(dataID) == "table" then
							if dataID.menuName then
								titleText = dataID.menuName
							elseif dataID.title then
								titleText = dataID.title
							end
						end
						if not titleText and dataID then
							titleText = tostring(dataID)
						end
						AtlasCFMCharDB["QuickLooks"][index] = { dataID, storedMenu, titleText }
						AtlasCFM.QuickLook.RefreshButtons()
						Hewdrop:Close(1)
					end
				)
			end
		end
		Hewdrop:Open(button,
			'point', function(parent)
				return "BOTTOMLEFT", "BOTTOMRIGHT"
			end,
			"children", setOptions
		)
	end
end

---
--- Refreshes QuickLook buttons availability based on saved assignments
--- @return void
--- @usage AtlasCFM.QuickLook.RefreshButtons()
---
function AtlasCFM.QuickLook.RefreshButtons()
	local i = 1
	while i < 7 do
		local entry = AtlasCFMCharDB["QuickLooks"][i]
		local btnPanel = _G["AtlasCFMLootPanel_Preset" .. i]
		local btnItems = _G["AtlasCFMLootItemsFrame_Preset" .. i]
		local enable = false
		if entry then
			if type(entry) == "table" then
				if entry[1] ~= nil then enable = true end
			else
				if entry ~= "" then enable = true end
			end
		end
		if btnPanel then if enable then btnPanel:Enable() else btnPanel:Disable() end end
		if btnItems then if enable then btnItems:Enable() else btnItems:Disable() end end
		i = i + 1
	end
end
