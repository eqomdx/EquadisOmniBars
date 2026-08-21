--[[ Equadis' Classic Overhaul :: item database browser

  One window, two entry paths:

    * Open Item Database -> search any item by partial name or exact item ID.
    * Ctrl+Alt over a unit -> open that unit's complete, unfiltered drop pool.

  Selecting an item shows every known source from bundled Atlas-CFM, bundled
  AtlasLoot and pfQuest. Tooltip-only world-drop/rarity filters are deliberately
  never applied here.
]]--

local OB = EquadisClassicOverhaul
local M = OB.modules.itemdatabase
if not M then return end

local ROW_H = 22
local ROWS = 16
local WIDTH = 790
local HEIGHT = 500
local LEFT_X = 12
local LEFT_W = 372
local RIGHT_X = 407
local RIGHT_W = 355
local LIST_TOP = -96

local function qualityName(quality)
    if quality == 0 then return "Poor" end
    if quality == 1 then return "Common" end
    if quality == 2 then return "Uncommon" end
    if quality == 3 then return "Rare" end
    if quality == 4 then return "Epic" end
    if quality == 5 then return "Legendary" end
    return "Unknown"
end

local function qualityColor(quality)
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

local function chanceText(chance)
    chance = tonumber(chance) or 0
    if chance <= 0 then return "?" end
    return string.format("%.2f%%", chance)
end

local function providerText(providers)
    if type(providers) ~= "table" then return "" end
    local names = {}
    for name in pairs(providers) do
        if name ~= "ID" then table.insert(names, name) end
    end
    table.sort(names)
    return table.concat(names, ", ")
end

local function itemEnter()
    local row = this
    local data = row.data
    if not data or not data.id then return end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 8, 0)
    GameTooltip:SetHyperlink("item:" .. tostring(data.id) .. ":0:0:0")
    GameTooltip:Show()
end

local function itemLeave()
    GameTooltip:Hide()
end

local function itemClick()
    local row = this
    local data = row.data
    if not data or not data.id then return end

    if arg1 == "RightButton" then
        local name, link = M:ItemInfo(data.id)
        local text = link or (name and ("[" .. name .. "]")) or tostring(data.id)
        SetItemRef("item:" .. tostring(data.id) .. ":0:0:0", text, arg1)
        return
    end

    M:SelectBrowserItem(data)
end

local function sourceEnter()
    local row = this
    local data = row.data
    local selected = M.browserSelected
    if not data or not selected or not selected.id then return end

    GameTooltip:SetOwner(row, "ANCHOR_LEFT", -8, 0)
    GameTooltip:SetHyperlink("item:" .. tostring(selected.id) .. ":0:0:0")
    GameTooltip:AddLine("Source: " .. tostring(data.name or "Unknown"), 0.55, 0.75, 1)
    if data.instance then GameTooltip:AddLine("Location: " .. tostring(data.instance), 0.7, 0.7, 0.7) end
    if data.provider then GameTooltip:AddLine("Database: " .. tostring(data.provider), 0.7, 0.7, 0.7) end
    local chance = tonumber(data.chance) or 0
    if chance > 0 then GameTooltip:AddLine("Drop rate: " .. chanceText(chance), 0.85, 0.85, 0.85) end
    GameTooltip:Show()
end

local function sourceLeave()
    GameTooltip:Hide()
end

function M:CreateBrowserItemRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(LEFT_W - 26)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT_X + 2, LIST_TOP - ((i - 1) * ROW_H))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnEnter", itemEnter)
    row:SetScript("OnLeave", itemLeave)
    row:SetScript("OnClick", itemClick)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(1, 1, 1, (math.floor(i / 2) * 2 == i) and 0.035 or 0.015)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:Hide()

    row.name = OB.NewText(row, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.name:SetWidth(229)
    row.name:SetJustifyH("LEFT")

    row.meta = OB.NewText(row, "OVERLAY", "GameFontNormalSmall")
    row.meta:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.meta:SetWidth(88)
    row.meta:SetJustifyH("RIGHT")

    return row
end

function M:CreateBrowserSourceRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(RIGHT_W - 26)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", RIGHT_X + 2, LIST_TOP - ((i - 1) * ROW_H))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnEnter", sourceEnter)
    row:SetScript("OnLeave", sourceLeave)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(1, 1, 1, (math.floor(i / 2) * 2 == i) and 0.035 or 0.015)

    row.name = OB.NewText(row, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.name:SetWidth(220)
    row.name:SetJustifyH("LEFT")

    row.rate = OB.NewText(row, "OVERLAY", "GameFontNormalSmall")
    row.rate:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.rate:SetWidth(92)
    row.rate:SetJustifyH("RIGHT")

    return row
end

function M:CreateBrowser()
    if self.browser then return self.browser end

    local f = CreateFrame("Frame", "EquadisClassicOverhaulItemDatabase", UIParent)
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetBackdrop(OB.backdrop)
    f:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
    f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
    f:Hide()

    if UISpecialFrames then table.insert(UISpecialFrames, "EquadisClassicOverhaulItemDatabase") end

    f:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then this:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    f:SetScript("OnHide", function() GameTooltip:Hide() end)

    f.close = OB.IconButton(f, "close")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -5)
    f.close:SetScript("OnClick", function() f:Hide() end)

    f.title = OB.NewText(f, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
    f.title:SetText("Item Database")

    f.search = CreateFrame("EditBox", "EquadisClassicOverhaulItemDatabaseSearch", f,
            "InputBoxTemplate")
    f.search:SetWidth(440)
    f.search:SetHeight(22)
    f.search:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.search:SetAutoFocus(false)
    f.search:SetMaxLetters(80)
    f.search:SetScript("OnEnterPressed", function()
        M:RunBrowserSearch(this:GetText())
        this:ClearFocus()
    end)
    f.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    f.searchButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.searchButton:SetWidth(76)
    f.searchButton:SetHeight(22)
    f.searchButton:SetPoint("LEFT", f.search, "RIGHT", 8, 0)
    f.searchButton:SetText("Search")
    f.searchButton:SetScript("OnClick", function() M:RunBrowserSearch(f.search:GetText()) end)

    f.clearButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.clearButton:SetWidth(64)
    f.clearButton:SetHeight(22)
    f.clearButton:SetPoint("LEFT", f.searchButton, "RIGHT", 6, 0)
    f.clearButton:SetText("Clear")
    f.clearButton:SetScript("OnClick", function()
        f.search:SetText("")
        M:ShowSearchHome()
        f.search:SetFocus()
    end)

    f.subtitle = OB.NewText(f, "OVERLAY", "GameFontNormalSmall")
    f.subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -68)
    f.subtitle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -68)
    f.subtitle:SetJustifyH("LEFT")

    f.leftHead = OB.NewText(f, "OVERLAY", "GameFontNormalSmall")
    f.leftHead:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT_X + 2, -82)
    f.leftHead:SetText("Items")

    f.rightHead = OB.NewText(f, "OVERLAY", "GameFontNormalSmall")
    f.rightHead:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X + 2, -82)
    f.rightHead:SetText("Sources")

    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetTexture(1, 1, 1, 0.12)
    f.divider:SetWidth(1)
    f.divider:SetHeight(ROWS * ROW_H + 8)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 394, LIST_TOP + 4)

    f.itemScroll = CreateFrame("ScrollFrame", "EquadisClassicOverhaulItemDatabaseItemScroll",
            f, "FauxScrollFrameTemplate")
    f.itemScroll:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT_X, LIST_TOP)
    f.itemScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", LEFT_X + LEFT_W, 42)
    f.itemScroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_H, function() M:RefreshBrowserItemRows() end)
    end)

    f.sourceScroll = CreateFrame("ScrollFrame", "EquadisClassicOverhaulItemDatabaseSourceScroll",
            f, "FauxScrollFrameTemplate")
    f.sourceScroll:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X, LIST_TOP)
    f.sourceScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", RIGHT_X + RIGHT_W, 42)
    f.sourceScroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_H, function() M:RefreshBrowserSourceRows() end)
    end)

    f.itemRows = {}
    f.sourceRows = {}
    for i = 1, ROWS do
        f.itemRows[i] = self:CreateBrowserItemRow(f, i)
        f.sourceRows[i] = self:CreateBrowserSourceRow(f, i)
    end

    f.footer = OB.NewText(f, "OVERLAY", "GameFontNormalSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    f.footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    f.footer:SetJustifyH("LEFT")
    f.footer:SetTextColor(0.6, 0.6, 0.6)

    f:SetScript("OnShow", function()
        M:StyleBrowser()
        M:RefreshBrowser()
    end)

    self.browser = f
    return f
end

function M:StyleBrowser()
    local f = self:CreateBrowser()
    OB.ApplyFont(f.title, 15)
    OB.ApplyFont(f.subtitle, 11)
    OB.ApplyFont(f.leftHead, 10)
    OB.ApplyFont(f.rightHead, 10)
    OB.ApplyFont(f.footer, 9)
    for i = 1, ROWS do
        OB.ApplyFont(f.itemRows[i].name, 11)
        OB.ApplyFont(f.itemRows[i].meta, 10)
        OB.ApplyFont(f.sourceRows[i].name, 11)
        OB.ApplyFont(f.sourceRows[i].rate, 10)
    end
end

function M:BrowserItemMeta(row)
    if self.browserMode == "unit" then return chanceText(row.chance) end
    if self:Config().showItemIds then return tostring(row.id) end
    return qualityName(row.quality)
end

function M:RefreshBrowserItemRows()
    local f = self.browser
    if not f then return end
    local rows = self.browserItems or {}
    local total = table.getn(rows)
    FauxScrollFrame_Update(f.itemScroll, total, ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(f.itemScroll) or 0

    for i = 1, ROWS do
        local widget = f.itemRows[i]
        local data = rows[offset + i]
        if data then
            widget.data = data
            local name, link, quality, texture = self:ItemInfo(data.id)
            data.name = name or data.name
            data.link = link or data.link
            data.texture = texture or data.texture
            if type(quality) == "number" then data.quality = quality end
            if type(data.quality) ~= "number" and self.atlasLootItems
                    and self.atlasLootItems[data.id] then
                data.quality = self.atlasLootItems[data.id].quality
            end

            local text = data.name or ("Item " .. tostring(data.id))
            widget.name:SetText(text)
            if data.texture then
                widget.icon:SetTexture(data.texture)
                widget.icon:Show()
            else
                widget.icon:Hide()
                if self.QueueItemRefresh then self:QueueItemRefresh(data.id) end
            end
            local r, g, b = qualityColor(data.quality)
            widget.name:SetTextColor(r, g, b)
            widget.meta:SetText(self:BrowserItemMeta(data))
            widget.meta:SetTextColor(r, g, b)
            widget:Show()
        else
            widget.data = nil
            if widget.icon then widget.icon:Hide() end
            widget:Hide()
        end
    end
end

function M:RefreshBrowserSourceRows()
    local f = self.browser
    if not f then return end
    local rows = self.browserSources or {}
    local total = table.getn(rows)
    FauxScrollFrame_Update(f.sourceScroll, total, ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(f.sourceScroll) or 0

    for i = 1, ROWS do
        local widget = f.sourceRows[i]
        local data = rows[offset + i]
        if data then
            widget.data = data
            local text = tostring(data.name or "Unknown")
            if data.instance and tostring(data.instance) ~= "" then
                text = text .. " |cff777777- " .. tostring(data.instance) .. "|r"
            end
            widget.name:SetText(text)
            local provider = data.provider and (" |cff666666" .. tostring(data.provider) .. "|r") or ""
            widget.rate:SetText(chanceText(data.chance) .. provider)
            widget:Show()
        else
            widget.data = nil
            widget:Hide()
        end
    end
end

function M:SelectBrowserItem(item)
    if not item or not item.id then return end
    self.browserSelected = item
    self.browserSources = self:GetItemSources(item.id)

    local f = self:CreateBrowser()
    local name = item.name
    if not name then name = self:ItemInfo(item.id) end
    f.rightHead:SetText("Sources for " .. tostring(name or ("Item " .. item.id)))
    self:RefreshBrowserSourceRows()
end

function M:SortSearchResults(rows)
    local sortBy = self:Config().sortBy or "chance"
    for i = 1, table.getn(rows) do
        if sortBy == "chance" then
            local sources = self:GetItemSources(rows[i].id)
            rows[i].bestChance = sources[1] and tonumber(sources[1].chance) or 0
        end
    end

    table.sort(rows, function(a, b)
        if sortBy == "rarity" then
            local aq = tonumber(a.quality) or -1
            local bq = tonumber(b.quality) or -1
            if aq ~= bq then return aq > bq end
        else
            local ac = tonumber(a.bestChance) or 0
            local bc = tonumber(b.bestChance) or 0
            if ac ~= bc then return ac > bc end
        end
        local an = string.lower(a.name or "")
        local bn = string.lower(b.name or "")
        if an ~= bn then return an < bn end
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)
end

function M:RunBrowserSearch(text)
    local f = self:CreateBrowser()
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then return self:ShowSearchHome() end

    local results = self:SearchItems(text)
    self:SortSearchResults(results)
    self.browserMode = "search"
    self.browserItems = results
    self.browserSources = {}
    self.browserSelected = nil
    self.browserSource = nil

    f.leftHead:SetText("Search results")
    f.rightHead:SetText("Sources")
    f.subtitle:SetText("Search: " .. text .. "  -  " .. table.getn(results) .. " matching item"
            .. (table.getn(results) == 1 and "" or "s"))
    f.footer:SetText("Full database search: bundled Atlas-CFM + AtlasLoot"
            .. ((pfDB and pfDB.items) and " + pfQuest" or "")
            .. ". Right-click an item to open its item link.")

    self:RefreshBrowserItemRows()
    self:RefreshBrowserSourceRows()
    if results[1] then self:SelectBrowserItem(results[1]) end
end

function M:ShowSearchHome()
    local f = self:CreateBrowser()
    self.browserMode = "search"
    self.browserItems = {}
    self.browserSources = {}
    self.browserSelected = nil
    self.browserSource = nil

    f.leftHead:SetText("Items")
    f.rightHead:SetText("Sources")
    f.subtitle:SetText("Search by partial item name or exact item ID.")
    f.footer:SetText("The full database is never affected by tooltip filtering.")
    self:RefreshBrowserItemRows()
    self:RefreshBrowserSourceRows()
end

function M:SetBrowserSource(source)
    self.browserSource = source
    if source then self.lastBrowserSource = source end
end

function M:ShowBrowser(source, requestedName)
    local f = self:CreateBrowser()
    f:Show()

    if source then
        self.browserMode = "unit"
        self:SetBrowserSource(source)
        self.browserSelected = nil
        self.browserSources = {}
        self.browserItems = self:SortedItems(source) -- full list; no tooltip filters
        f.leftHead:SetText("Drops from " .. tostring(source.name or requestedName or "unit"))
        f.rightHead:SetText("Sources")

        local bits = { source.name or requestedName or "Unknown" }
        if source.instance then table.insert(bits, tostring(source.instance)) end
        if source.provider then table.insert(bits, tostring(source.provider)) end
        table.insert(bits, tostring(table.getn(self.browserItems)) .. " drops")
        f.subtitle:SetText(table.concat(bits, "  -  "))
        f.footer:SetText("Ctrl+Alt view: complete drop pool. Tooltip filters are not applied.")
        self:RefreshBrowserItemRows()
        self:RefreshBrowserSourceRows()
        if self.browserItems[1] then self:SelectBrowserItem(self.browserItems[1]) end
        return true
    end

    if requestedName then
        self.browserMode = "unit"
        self.browserItems = {}
        self.browserSources = {}
        self.browserSelected = nil
        f.leftHead:SetText("Drops from " .. tostring(requestedName))
        f.rightHead:SetText("Sources")

        if self.building or self.browserWaitingName == requestedName then
            f.subtitle:SetText("Building pfQuest loot index for " .. tostring(requestedName) .. "...")
            f.footer:SetText("The window will update automatically when the world-mob index is ready.")
        else
            f.subtitle:SetText("No loot pool found for " .. tostring(requestedName)
                    .. ". You can still search the full database above.")
            f.footer:SetText("Full item search remains available even when a unit has no known loot table.")
        end

        self:RefreshBrowserItemRows()
        self:RefreshBrowserSourceRows()
        return true
    end

    self:ShowSearchHome()
    f.search:SetFocus()
    return true
end

function M:RefreshBrowser()
    local f = self.browser
    if not f or not f.IsShown or not f:IsShown() then return end

    if self.browserMode == "unit" and self.browserSource then
        self.browserItems = self:SortedItems(self.browserSource)
        self:RefreshBrowserItemRows()
        if self.browserSelected then self:SelectBrowserItem(self.browserSelected) end
    elseif self.browserMode == "search" and f.search and f.search:GetText() ~= "" then
        -- Do not rerun an expensive search for a pure style refresh. Existing
        -- results remain valid; only the rendered item info needs refreshing.
        self:RefreshBrowserItemRows()
        self:RefreshBrowserSourceRows()
    else
        self:ShowSearchHome()
    end
end
