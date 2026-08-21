-- Place the three Dragonflight migration areas together in the feature sidebar.
local OB = EquadisClassicOverhaul
if not OB.featureTabs then return end

local rebuilt = { "actionbars", "buffframes", "partyframes" }
for i = 1, table.getn(OB.featureTabs) do
    local entry = OB.featureTabs[i]
    local id = entry
    if type(entry) == "table" then id = entry[1] end

    if id ~= "actionbars" and id ~= "buffframes" and id ~= "partyframes" then
        table.insert(rebuilt, entry)
    end
end
OB.featureTabs = rebuilt
