---
--- ArathiBasin.lua - Arathi Basin battleground PvP data
---
--- This module contains comprehensive PvP data for the Arathi Basin
--- battleground. It includes resource control objectives, strategic nodes,
--- capture points, and battleground-specific rewards.
---
--- Features:
--- • Battleground objectives
--- • PvP rewards and marks
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
AtlasCFM = _G.AtlasCFM or {}

local LZ = AtlasCFM.Localization.Zones
local LF = AtlasCFM.Localization.Factions
local LMD = AtlasCFM.Localization.MapData

AtlasCFM.InstanceData = AtlasCFM.InstanceData or {}

-- Arathi Basin data
AtlasCFM.InstanceData.BGArathiBasin = {
    Name = LZ["Arathi Basin"],
    Location = LZ["Arathi Highlands"],
    Level = { 20, 60 },
    Acronym = "AB",
    MaxPlayers = 15,
    Reputation = {
        { name = LF["The League of Arathor"] .. " \\ " .. LF["The Defilers"], loot = "ArathorDefilers" },
    },
    Entrances = {
        { letter = "A)", info = LMD["Trollbane Hall"] .. " (A)" },
        { letter = "B)", info = LMD["Defiler's Den"] .. " (H)" }
    },
    Bosses = {}
}
