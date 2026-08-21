---
--- AtlasOptions.lua - Atlas configuration and options management
---
--- This file contains the options and configuration system for Atlas-CFM.
--- It handles user preferences, settings persistence, UI customization,
--- and provides the interface for configuring Atlas behavior and appearance.
---
--- Features:
--- - Options frame and UI management
--- - Settings persistence and loading
--- - User preference handling
--- - Configuration validation
--- - Default settings management
---
--- @compatible World of Warcraft 1.12
---

-- Local references to global functions for performance
local _G                            = getfenv()
local AtlasCFM                      = _G.AtlasCFM

local L                             = AtlasCFM.Localization.UI

local uIDropDownMenu_SetSelectedID  = UIDropDownMenu_SetSelectedID

---------------
--- COLOURS ---
---------------
local red                           = AtlasCFM.Colors.RED
local blue                          = AtlasCFM.Colors.BLUE

-- Local variables for frequently used UI elements
local atlasOptionsFrame, atlasFrame = AtlasCFMOptionsFrame, AtlasCFMFrame

--- Rounds a number to specified decimal places
--- @param num number The number to round
--- @param idp number|nil Number of decimal places (default: 0)
--- @return number The rounded number
--- @usage local rounded = round(3.14159, 2) -- returns 3.14
local function round(num, idp)
    local mult = 10 ^ (idp or 0)
    return math.floor(num * mult + 0.5) / mult
end



--- Toggles the bottom loot panel visibility
--- Updates AtlasCFMOptions.LootShowPanel and shows/hides AtlasCFMLootPanel
--- @return nil
--- @usage AtlasCFM.OptionShowPanelOnClick()
---
function AtlasCFM.OptionShowPanelOnClick()
    local showPanelStatus = AtlasCFMOptions.LootShowPanel
    AtlasCFMOptions.LootShowPanel = not showPanelStatus
    if showPanelStatus then
        AtlasCFMLootPanel:Hide()
    else
        AtlasCFMLootPanel:Show()
    end
    AtlasCFMOptionShowPanel:SetChecked(AtlasCFMOptions.LootShowPanel)
    AtlasCFM.OptionsInit()
end

--- Toggles loot filtering mode
--- Cycles through 0: All, 1: My Class, 2: Available
--- @return nil
function AtlasCFM.OptionFilterModeOnClick()
    if not AtlasCFMOptions.LootFilterMode then
        AtlasCFMOptions.LootFilterMode = 0
    end
    AtlasCFMOptions.LootFilterMode = math.mod(AtlasCFMOptions.LootFilterMode + 1, 3)

    -- Update UI if button exists
    if AtlasCFMLootFilterButton then
        local filterText = ""
        if AtlasCFMOptions.LootFilterMode == 0 then
            filterText = L["Filter: No Filter"]
        elseif AtlasCFMOptions.LootFilterMode == 1 then
            filterText = L["Filter: My Class"]
        elseif AtlasCFMOptions.LootFilterMode == 2 then
            filterText = L["Filter: Available"]
        end
        AtlasCFMLootFilterButton:SetText(filterText)
    end

    -- Refresh loot display
    if AtlasCFM.LootBrowserUI and AtlasCFM.LootBrowserUI.ScrollBarLootUpdate then
        AtlasCFM.LootBrowserUI.ScrollBarLootUpdate()
        AtlasCFM.Quest.UI.InsideAtlasFrame:Hide()
    end
end

---
--- Toggles the visibility of the Atlas options frame
--- Shows or hides the options panel and refreshes tooltip settings
--- @return nil
--- @usage AtlasCFM.OptionsOnClick() -- Called by options button click
---
function AtlasCFM.OptionsOnClick()
    if atlasOptionsFrame:IsVisible() then
        atlasOptionsFrame:Hide()
    else
        atlasOptionsFrame:Show()
    end
end

---
--- Toggles the auto-select feature for Atlas maps
--- Enables or disables automatic map selection based on player location
--- @return nil
--- @usage AtlasCFM.OptionsAutoSelectOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionsAutoSelectOnClick()
    AtlasCFMOptions.AtlasAutoSelect = not AtlasCFMOptions.AtlasAutoSelect
    AtlasCFM.OptionsInit()
end

---
--- Toggles the world map right-click integration feature
--- Enables or disables Atlas opening on world map right-click
--- @return nil
--- @usage AtlasCFM.OptionsWorldMapOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionsWorldMapOnClick()
    AtlasCFMOptions.AtlasRightClick = not AtlasCFMOptions.AtlasRightClick
    AtlasCFM.OptionsInit()
end

---
--- Toggles the display of instance acronyms in Atlas
--- Shows or hides abbreviated instance names and refreshes display
--- @return nil
--- @usage AtlasCFM.OptionsAcronymsOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionsAcronymsOnClick()
    AtlasCFMOptions.AtlasAcronyms = not AtlasCFMOptions.AtlasAcronyms
    AtlasCFM.OptionsInit()
    AtlasCFM.Refresh()
end

--- Toggles clamping Atlas frame to the screen
--- Updates AtlasCFMOptions.AtlasClamped and refreshes the UI
--- @return nil
--- @usage AtlasCFM.OptionsClampedOnClick()
---
function AtlasCFM.OptionsClampedOnClick()
    AtlasCFMOptions.AtlasClamped = not AtlasCFMOptions.AtlasClamped
    atlasFrame:SetClampedToScreen(AtlasCFMOptions.AtlasClamped)
    AtlasCFM.OptionsInit()
    AtlasCFM.Refresh()
end

---
--- Toggles showing cursor coordinates on the Atlas map
--- Updates AtlasCFMOptions.AtlasCursorCoords and shows/hides the overlay
--- @return nil
--- @usage AtlasCFM.OptionsCursorCoordsOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionsCursorCoordsOnClick()
    AtlasCFMOptions.AtlasCursorCoords = not AtlasCFMOptions.AtlasCursorCoords
    if AtlasMapOverlay then
        if AtlasCFMOptions.AtlasCursorCoords then
            AtlasMapOverlay:Show()
            PrintA("Cursor coordinates on map enabled")
        else
            AtlasMapOverlay:Hide()
            PrintA("Cursor coordinates on map disabled")
        end
    end
    if AtlasCFMOptionCursorCoords then
        AtlasCFMOptionCursorCoords:SetChecked(AtlasCFMOptions.AtlasCursorCoords)
    end
end

---
--- Handles toggle of pfUI styling option
--- Enables or disables pfUI integration styling
--- @return nil
--- @usage Called when user clicks pfUI styling checkbox
---
function AtlasCFM.OptionsPfUIOnClick()
    AtlasCFMOptions.pfUIEnabled = not AtlasCFMOptions.pfUIEnabled
    if AtlasCFMOptionPfUI then
        AtlasCFMOptionPfUI:SetChecked(AtlasCFMOptions.pfUIEnabled)
    end

    -- Inform user that UI reload is required
    if AtlasCFMOptions.pfUIEnabled then
        PrintA(L["pfUI styling enabled. Type /reload to apply changes."])
    else
        PrintA(L["pfUI styling disabled. Type /reload to apply changes."])
    end
end

---
--- Toggles map markers display
--- Enables or disables icons on the World Map
--- @return nil
--- @usage AtlasCFM.OptionMapMarkersOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionMapMarkersOnClick()
    AtlasCFMOptions.ShowMapMarkers = not AtlasCFMOptions.ShowMapMarkers
    if AtlasCFMOptionMapMarkers then
        AtlasCFMOptionMapMarkers:SetChecked(AtlasCFMOptions.ShowMapMarkers)
    end

    if AtlasCFM.MapMarkers and AtlasCFM.MapMarkers.UpdateMarkers then
        AtlasCFM.MapMarkers.UpdateMarkers()
    end
end

---
--- Initializes all Atlas-CFM option settings and UI elements
--- Sets checkbox states, slider values, and frame visibility based on saved options
--- @return nil
--- @usage AtlasCFM.OptionsInit() -- Called after option changes
---
function AtlasCFM.OptionsInit()
    if not AtlasCFMOptions then
        PrintA("Failed to initialize local references.")
        return
    end

    -- Ensure Reagent options exist for old configs
    if AtlasCFMOptions.ReagentRows == nil then AtlasCFMOptions.ReagentRows = 20 end
    if AtlasCFMOptions.ReagentProfessions == nil then
        AtlasCFMOptions.ReagentProfessions = {
            ["Alchemy"] = true,
            ["Blacksmithing"] = true,
            ["Enchanting"] = true,
            ["Engineering"] = true,
            ["Leatherworking"] = true,
            ["Tailoring"] = true,
            ["Cooking"] = true,
            ["First Aid"] = true,
            ["Jewelcrafting"] = true,
            ["Poisons"] = true,
            ["Mining"] = true,
            ["Survival"] = true,
        }
    end
    if AtlasCFMOptions.ProfessionInfo == nil then AtlasCFMOptions.ProfessionInfo = false end

    if AtlasCFMOptions.QuestWithAtlas then
        AtlasCFM.Quest.UI_Main.Frame:Show()
    else
        AtlasCFM.Quest.UI_Main.Frame:Hide()
    end
    -- Consult the saved variable table to see whether to show the bottom panel
    if AtlasCFMOptions.LootShowPanel then
        AtlasCFMLootPanel:Show()
    else
        AtlasCFMLootPanel:Hide()
    end
    -- Set values on load
    if AtlasCFMOptionToggleButton then AtlasCFMOptionToggleButton:SetChecked(AtlasCFMOptions.AtlasButtonShown) end
    if AtlasCFMOptionAutoSelect then AtlasCFMOptionAutoSelect:SetChecked(AtlasCFMOptions.AtlasAutoSelect) end
    if AtlasCFMOptionRightClick then AtlasCFMOptionRightClick:SetChecked(AtlasCFMOptions.AtlasRightClick) end
    if AtlasCFMOptionAcronyms then AtlasCFMOptionAcronyms:SetChecked(AtlasCFMOptions.AtlasAcronyms) end
    if AtlasCFMOptionClamped then AtlasCFMOptionClamped:SetChecked(AtlasCFMOptions.AtlasClamped) end
    if AtlasCFMOptionCursorCoords then AtlasCFMOptionCursorCoords:SetChecked(AtlasCFMOptions.AtlasCursorCoords) end

    -- pfUI option (only show if pfUI is loaded)
    if IsAddOnLoaded("pfUI") and AtlasCFMOptionPfUI then
        AtlasCFMOptionPfUI:SetChecked(AtlasCFMOptions.pfUIEnabled)
    elseif AtlasCFMOptionPfUI then
        -- Hide the checkbox if pfUI is not loaded
        AtlasCFMOptionPfUI:Hide()
        _G[AtlasCFMOptionPfUI:GetName() .. "Text"]:Hide()
    end

    if AtlasCFMOptionSliderButtonPos then AtlasCFMOptionSliderButtonPos:SetValue(AtlasCFMOptions.AtlasButtonPosition) end
    if AtlasCFMOptionSliderButtonRad then AtlasCFMOptionSliderButtonRad:SetValue(AtlasCFMOptions.AtlasButtonRadius) end
    if AtlasCFMOptionSliderAlpha then AtlasCFMOptionSliderAlpha:SetValue(AtlasCFMOptions.AtlasAlpha) end
    if AtlasCFMOptionSliderScale then AtlasCFMOptionSliderScale:SetValue(AtlasCFMOptions.AtlasScale) end

    if AtlasCFMOptionMapMarkers then AtlasCFMOptionMapMarkers:SetChecked(AtlasCFMOptions.ShowMapMarkers) end

    -- Quest Options
    if AtlasCFMOptionAutoshow then AtlasCFMOptionAutoshow:SetChecked(AtlasCFMOptions.QuestWithAtlas) end
    if AtlasCFMOptionLeftSide then AtlasCFMOptionLeftSide:SetChecked(AtlasCFMOptions.QuestCurrentSide) end

    local function IsPfUIStylingEnabled()
        return IsAddOnLoaded("pfUI") and pfUI and (not AtlasCFMOptions or AtlasCFMOptions.pfUIEnabled ~= false)
    end

    if IsPfUIStylingEnabled() then
        AtlasCFM.Quest.UI_Main.Frame:ClearAllPoints()
        if AtlasCFMOptionLeftSide and AtlasCFMOptionLeftSide:GetChecked() then
            AtlasCFM.Quest.UI_Main.Frame:SetPoint("TOPRIGHT", "AtlasCFMFrame", "TOPLEFT", -1, 0)
        else
            AtlasCFM.Quest.UI_Main.Frame:SetPoint("TOPLEFT", "AtlasCFMFrame", "TOPRIGHT", 1, 0)
        end
    else
        if AtlasCFMOptionLeftSide and AtlasCFMOptionLeftSide:GetChecked() then
            AtlasCFM.Quest.UI_Main.Frame:SetPoint("TOP", "AtlasCFMFrame", -556, -36)
        else
            AtlasCFM.Quest.UI_Main.Frame:SetPoint("TOP", "AtlasCFMFrame", 567, -36)
        end
    end
    if AtlasCFMOptionColor then AtlasCFMOptionColor:SetChecked(AtlasCFMOptions.QuestColourCheck) end
    if AtlasCFMOptionQuestlog then AtlasCFMOptionQuestlog:SetChecked(AtlasCFMOptions.QuestCheckQuestlog) end
    if AtlasCFMOptionAutoQuery then AtlasCFMOptionAutoQuery:SetChecked(AtlasCFMOptions.QuestAutoQuery) end

    -- Loot Options
    if AtlasCFMOptionShowSource then AtlasCFMOptionShowSource:SetChecked(AtlasCFMOptions.LootShowSource) end
    if AtlasCFMOptionEquipCompare then AtlasCFMOptionEquipCompare:SetChecked(AtlasCFMOptions.LootEquipCompare) end
    if AtlasCFMOptionOpaque then AtlasCFMOptionOpaque:SetChecked(AtlasCFMOptions.LootOpaque) end
    if AtlasCFMOptionShowPanel then AtlasCFMOptionShowPanel:SetChecked(AtlasCFMOptions.LootShowPanel) end
    if AtlasCFMOptionTooltipID then AtlasCFMOptionTooltipID:SetChecked(AtlasCFMOptions.TooltipShowID) end
    if AtlasCFMOptionTooltipIcon then AtlasCFMOptionTooltipIcon:SetChecked(AtlasCFMOptions.TooltipShowIcon) end

    -- Update Loot Filter button text
    if AtlasCFMLootFilterButton then
        local filterText = ""
        local mode = AtlasCFMOptions.LootFilterMode or 0
        if mode == 0 then
            filterText = L["Filter: No Filter"]
        elseif mode == 1 then
            filterText = L["Filter: My Class"]
        elseif mode == 2 then
            filterText = L["Filter: Available"]
        end
        AtlasCFMLootFilterButton:SetText(filterText)
    end

    -- Update Server label
    if AtlasCFM.HewdropMenus and AtlasCFM.HewdropMenus.UpdateServerLabel then
        AtlasCFM.HewdropMenus.UpdateServerLabel()
    end
end

---
--- Resets Atlas frame position and related settings to defaults
--- Clears frame anchors and restores default button position, radius, alpha, and scale
--- @return nil
--- @usage AtlasCFM.OptionResetPosition() -- Called by reset button
---
function AtlasCFM.OptionResetPosition()
    atlasFrame:ClearAllPoints()
    atlasFrame:SetPoint("TOP", 0, -104)

    -- Reset settings to default values
    AtlasCFMOptions.AtlasButtonPosition = 305
    AtlasCFMOptions.AtlasButtonRadius = 76
    AtlasCFMOptions.AtlasAlpha = 1.0
    AtlasCFMOptions.AtlasScale = 1.0

    AtlasCFM.OptionsInit()
end

---
--- Updates slider display text with current value
--- Shows the slider label with current rounded value in parentheses
--- @param text string The base text label for the slider
--- @param frame table Optional frame to update, defaults to 'this'
--- @return nil
--- @usage AtlasOptions_UpdateSlider("Scale") -- Called by slider OnValueChanged
---
function AtlasOptions_UpdateSlider(text, frame)
    local slider = frame or this
    if not slider or type(slider.GetValue) ~= "function" then
        return
    end
    local sliderName = slider:GetName()
    local textElement = _G[sliderName .. "Text"]
    if textElement then
        textElement:SetText(text .. " (" .. round(slider:GetValue(), 2) .. ")")
    end
end

--- Sets default configuration options for Atlas-CFM
--- Initializes all addon settings to their default values
--- @return nil
--- @usage AtlasCFM.OptionDefaultSettings() -- Reset to defaults
function AtlasCFM.OptionDefaultSettings()
    AtlasCFMOptions = {
        AtlasButtonPosition = 305,
        AtlasButtonRadius = 76,
        AtlasButtonShown = true,
        AtlasRightClick = false,
        AtlasType = 1,
        AtlasScale = 1,
        AtlasVersion = AtlasCFM.Version,
        AtlasZone = 1,
        AtlasSortBy = 1,
        AtlasServer = "Auto",
        AtlasAutoSelect = false,
        AtlasLocked = false,
        AtlasAlpha = 1.0,
        AtlasAcronyms = true,
        AtlasClamped = true,
        AtlasCursorCoords = true,
        QuestCurrentSide = "Left",
        QuestWithAtlas = true,
        QuestColourCheck = true,
        QuestCheckQuestlog = true,
        QuestAutoQuery = true,
        LootShowSource = true,
        LootEquipCompare = false,
        LootOpaque = true,
        LootShowPanel = true,
        LootFilterMode = 0,
        ReagentRows = 20,
        ReagentProfessions = {
            ["Alchemy"] = true,
            ["Blacksmithing"] = true,
            ["Enchanting"] = true,
            ["Engineering"] = true,
            ["Leatherworking"] = true,
            ["Tailoring"] = true,
            ["Cooking"] = true,
            ["First Aid"] = true,
            ["Jewelcrafting"] = true,
            ["Poisons"] = true,
            ["Mining"] = true,
            ["Survival"] = true,
        },
        TooltipShowID = true,
        TooltipShowIcon = true,
        pfUIEnabled = true
    }
    AtlasCFMCharDB.PartialMatching = true
    AtlasCFMCharDB["QuickLooks"] = {}
    AtlasCFMCharDB["WishList"] = {}
    AtlasCFM.QuickLook.RefreshButtons()
    AtlasCFM.OptionsInit()
    PrintA(red .. L["Default settings applied!"])
end

--- Shows and initializes the categories dropdown menu
--- Sets up the dropdown with available sort categories and selects current option
--- @return nil
--- @usage AtlasCFM.OptionFrameDropDownCatsOnShow() -- Called by dropdown OnShow event
---
function AtlasCFM.OptionFrameDropDownCatsOnShow()
    if AtlasCFM.HewdropMenus and AtlasCFM.HewdropMenus.UpdateSortByLabel then
        AtlasCFM.HewdropMenus.UpdateSortByLabel()
    end
end

-----------------------------------------------------------------------------
-- Option handlers
-----------------------------------------------------------------------------
---
--- Toggles automatic quest panel display feature
--- Shows or hides quest panel when Atlas is opened and updates UI state
--- @return nil
--- @usage AtlasCFM.OptionAutoshowOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionAutoshowOnClick()
    AtlasCFMOptions.QuestWithAtlas = not AtlasCFMOptions.QuestWithAtlas
    AtlasCFMOptionAutoshow:SetChecked(AtlasCFMOptions.QuestWithAtlas)
    AtlasCFM.OptionsInit()
end

---
--- Toggles quest panel position between left and right side
--- Moves the quest UI frame and updates settings
--- @return nil
--- @usage AtlasCFM.OptionLeftSideOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionLeftSideOnClick()
    AtlasCFMOptions.QuestCurrentSide = not AtlasCFMOptions.QuestCurrentSide
    if not AtlasCFMOptions.QuestCurrentSide then
        AtlasCFM.Quest.UI_Main.Frame:ClearAllPoints()
        AtlasCFM.Quest.UI_Main.Frame:SetPoint("TOP", "AtlasCFMFrame", -556, -36)
    end
    AtlasCFM.OptionsInit()
end

---
--- Toggles quest color coding feature
--- Enables or disables color-coded quest display and updates quest buttons
--- @return nil
--- @usage AtlasCFM.OptionColorOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionColorOnClick()
    AtlasCFMOptions.QuestColourCheck = not AtlasCFMOptions.QuestColourCheck
    AtlasCFMOptionColor:SetChecked(AtlasCFMOptions.QuestColourCheck)
    AtlasCFM.OptionsInit()
    AtlasCFM.Quest.SetQuestButtons()
end

---
--- Toggles questlog integration feature
--- Enables or disables checking against player's questlog and updates quest buttons
--- @return nil
--- @usage AtlasCFM.OptionQuestlogOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionQuestlogOnClick()
    AtlasCFMOptions.QuestCheckQuestlog = not AtlasCFMOptions.QuestCheckQuestlog
    AtlasCFMOptionQuestlog:SetChecked(AtlasCFMOptions.QuestCheckQuestlog)
    AtlasCFM.OptionsInit()
    AtlasCFM.Quest.SetQuestButtons()
end

---
--- Toggles automatic quest query feature
--- Enables or disables automatic querying of quest information
--- @return nil
--- @usage AtlasCFM.OptionAutoQueryOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionAutoQueryOnClick()
    AtlasCFMOptions.QuestAutoQuery = not AtlasCFMOptions.QuestAutoQuery
    AtlasCFMOptionAutoQuery:SetChecked(AtlasCFMOptions.QuestAutoQuery)
    AtlasCFM.OptionsInit()
end

---
--- Toggles loot source display feature
--- Shows or hides the source information for loot items
--- @return nil
--- @usage AtlasCFM.OptionShowSourceOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionShowSourceOnClick()
    AtlasCFMOptions.LootShowSource = not AtlasCFMOptions.LootShowSource
    AtlasCFM.OptionsInit()
end

---
--- Toggles EquipCompare addon integration
--- Registers or unregisters Atlas tooltips with EquipCompare/EQCompare addons
--- @return nil
--- @usage AtlasCFM.OptionEquipCompareOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionEquipCompareOnClick()
    if AtlasCFM.Integrations and AtlasCFM.Integrations.ToggleEquipCompare then
        AtlasCFM.Integrations.ToggleEquipCompare()
    else
        AtlasCFMOptions.LootEquipCompare = not AtlasCFMOptions.LootEquipCompare
    end
    AtlasCFM.OptionsInit()
end

---
--- Toggles loot frame opacity setting
--- Changes the background transparency of the loot items frame
--- @return nil
--- @usage AtlasCFM.OptionOpaqueOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionOpaqueOnClick()
    AtlasCFMOptions.LootOpaque = AtlasCFMOptionOpaque:GetChecked()
    if AtlasCFMOptions.LootOpaque then
        AtlasCFMLootItemsFrame_Back:SetTexture(0, 0, 0, 1)
    else
        AtlasCFMLootItemsFrame_Back:SetTexture(0, 0, 0, 0.65)
    end
    AtlasCFM.OptionsInit()
end

---
--- Toggles universal tooltip item ID display
--- @return nil
---
function AtlasCFM.OptionTooltipIDOnClick()
    AtlasCFMOptions.TooltipShowID = not AtlasCFMOptions.TooltipShowID
    AtlasCFM.OptionsInit()
end

---
--- Toggles universal tooltip item icon display
--- @return nil
---
function AtlasCFM.OptionTooltipIconOnClick()
    AtlasCFMOptions.TooltipShowIcon = not AtlasCFMOptions.TooltipShowIcon
    AtlasCFM.OptionsInit()
end

---
--- Toggles the Profession Info feature
--- Enables or disables displaying skill levels in profession frames
--- @return nil
--- @usage AtlasCFM.OptionProfessionInfoOnClick() -- Called by checkbox click
---
function AtlasCFM.OptionProfessionInfoOnClick()
    AtlasCFMOptions.ProfessionInfo = not AtlasCFMOptions.ProfessionInfo

    -- Trigger cache build if enabled
    if AtlasCFMOptions.ProfessionInfo and AtlasCFM.ProfessionHooks and AtlasCFM.ProfessionHooks.BuildCache then
        AtlasCFM.ProfessionHooks.BuildCache()
    end

    -- Update visibility of buttons immediately
    if AtlasCFM.ProfessionHooks and AtlasCFM.ProfessionHooks.CreateAtlasButton then
        if AtlasCFMOptions.ProfessionInfo then
            -- Re-create/Update buttons if frames exist
            if TradeSkillFrame then AtlasCFM.ProfessionHooks.CreateAtlasButton(TradeSkillFrame) end
            if CraftFrame then AtlasCFM.ProfessionHooks.CreateAtlasButton(CraftFrame) end
        else
            -- Hide buttons if they exist
            if _G["TradeSkillFrameAtlasButton"] then _G["TradeSkillFrameAtlasButton"]:Hide() end
            if _G["CraftFrameAtlasButton"] then _G["CraftFrameAtlasButton"]:Hide() end
        end
    end

    -- Refresh UI
    if AtlasCFM.ProfessionHooks then
        if TradeSkillFrame and TradeSkillFrame:IsVisible() and AtlasCFM.ProfessionHooks.OnTradeSkillUpdate then
            AtlasCFM.ProfessionHooks.OnTradeSkillUpdate()
        end
        if CraftFrame and CraftFrame:IsVisible() then
            CraftFrame_Update()
        end
    end

    AtlasCFM.OptionsInit()
end

-- Popup Box for first time users
StaticPopupDialogs["AtlasCFMLoot_SETUP"] = {
    text = L["Welcome to Atlas-CFM Edition. Please take a moment to set your preferences."],
    button1 = L["Setup"],
    OnAccept = function()
        AtlasCFM.OptionsOnClick()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}
