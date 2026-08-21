local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local LS = AtlasCFM.Localization.Spells

AtlasCFM.ReagentData = {}
local ReagentData = AtlasCFM.ReagentData

local ReagentIndex = nil
local RecipeInfo = nil

-- Helper to extract profession name from table key
local function GetProfessionName(tableKey)
    if not tableKey then return nil, nil end
    if string.find(tableKey, "^Alchemy") then return LS["Alchemy"], "Alchemy" end
    if string.find(tableKey, "^Blacksmithing") then return LS["Blacksmithing"], "Blacksmithing" end
    if string.find(tableKey, "^Enchanting") then return LS["Enchanting"], "Enchanting" end
    if string.find(tableKey, "^Engineering") then return LS["Engineering"], "Engineering" end
    if string.find(tableKey, "^Leatherworking") then return LS["Leatherworking"], "Leatherworking" end
    if string.find(tableKey, "^Leather") then return LS["Leatherworking"], "Leatherworking" end
    if string.find(tableKey, "^Tailoring") then return LS["Tailoring"], "Tailoring" end
    if string.find(tableKey, "^Cooking") then return LS["Cooking"], "Cooking" end
    if string.find(tableKey, "^FirstAid") then return LS["First Aid"], "First Aid" end
    if string.find(tableKey, "^Jewelcrafting") then return LS["Jewelcrafting"], "Jewelcrafting" end
    if string.find(tableKey, "^Poisons") then return LS["Poisons"], "Poisons" end
    if string.find(tableKey, "^Smelting") then return LS["Mining"], "Mining" end
    if string.find(tableKey, "^Survival") then return LS["Survival"], "Survival" end
    return nil, nil
end

ReagentData.ProfessionServers = {
    ["Survival"] = { AtlasCFM.Server.TURTLE1 },
    ["Jewelcrafting"] = { AtlasCFM.Server.TURTLE1 }
}

function ReagentData.IsProfessionVisible(professionKey)
    if not professionKey then return true end
    local servers = ReagentData.ProfessionServers[professionKey]
    if servers then
        return AtlasCFM.Server.IsVisible({ servers = servers }, false)
    end
    return true
end

-- Helper to get player's skill in a profession
function ReagentData.GetPlayerProfessionSkill(professionName)
    if not professionName then return 0 end
    for i = 1, GetNumSkillLines() do
        local skillName, _, _, skillRank, _, _, _, _, _, _, _, _, _ = GetSkillLineInfo(i)
        if skillName == professionName then
            return skillRank
        end
    end
    return 0
end

function ReagentData.BuildIndex()
    if ReagentIndex then return end
    ReagentIndex = {}
    RecipeInfo = {}

    -- 1. Build RecipeInfo from Crafting Data
    if AtlasCFMLoot_Data then
        for key, data in pairs(AtlasCFMLoot_Data) do
            local profession, professionKey = GetProfessionName(key)
            if profession and ReagentData.IsProfessionVisible(professionKey) and type(data) == "table" then
                for _, entry in ipairs(data) do
                    if entry.id and AtlasCFM.Server.IsVisible(entry, false) then
                        local el_skill = AtlasCFM.Server.GetDataField(entry, "skill")
                        local skill = 0
                        if el_skill and type(el_skill) == "table" then
                            skill = el_skill[1] or 0
                        end
                        RecipeInfo[entry.id] = {
                            profession = profession,
                            professionKey = professionKey,
                            skill = skill
                        }
                    end
                end
            end
        end
    end

    -- 2. Build ReagentIndex from SpellDB
    if AtlasCFM.SpellDB then
        for _, spells in pairs(AtlasCFM.SpellDB) do
            if type(spells) == "table" then
                for spellID, spellData in pairs(spells) do
                    -- Only index if we have RecipeInfo (i.e. we know the profession)
                    local info = RecipeInfo[spellID]
                    local reagents = (type(spellData) == "table") and AtlasCFM.Server.GetDataField(spellData, "reagents")
                    if info and reagents and AtlasCFM.Server.IsVisible(spellData, false) then
                        for _, reagent in ipairs(reagents) do
                            local reagentID = reagent[1]
                            if reagentID then
                                if not ReagentIndex[reagentID] then
                                    ReagentIndex[reagentID] = {}
                                end

                                local profession = info.profession
                                local professionKey = info.professionKey
                                local skill = info.skill

                                local name = AtlasCFM.Server.GetDataField(spellData, "name")
                                local itemID = AtlasCFM.Server.GetDataField(spellData, "item")

                                table.insert(ReagentIndex[reagentID], {
                                    spellID = spellID,
                                    itemID = itemID,
                                    name = name,
                                    profession = profession,
                                    professionKey = professionKey,
                                    skill = skill
                                })
                            end
                        end
                    end
                end
            end
        end

        -- Sort all lists
        for _, list in pairs(ReagentIndex) do
            table.sort(list, function(a, b)
                if a.profession ~= b.profession then
                    return a.profession < b.profession
                end
                if a.skill ~= b.skill then
                    return a.skill < b.skill
                end
                return (a.name or "") < (b.name or "")
            end)
        end
    end
end

function ReagentData.ClearIndex()
    ReagentIndex = nil
    RecipeInfo = nil
end

function ReagentData.GetRecipes(itemID)
    if not ReagentIndex then ReagentData.BuildIndex() end
    return ReagentIndex[itemID]
end
