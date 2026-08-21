---
--- WarsongGulch.lua - Warsong Gulch battleground PvP data
---
--- This module contains comprehensive PvP data for the Warsong Gulch
--- battleground. It includes capture the flag objectives, faction bases,
--- strategic locations, and battleground-specific rewards.
---
--- Features:
--- • Faction base locations
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

-- Warsong Gulch data
AtlasCFM.InstanceData.BGWarsongGulch = {
    Name = LZ["Warsong Gulch"],
    Location = LZ["Ashenvale"] .. "/" .. LZ["The Barrens"],
    Level = { 1, 60 },
    Acronym = "WSG",
    MaxPlayers = 10,
    Reputation = {
        { name = LF["Silverwing Sentinels"] .. " \\ " .. LF["Warsong Outriders"], loot = "SentinelsOutriders" },
    },
    Entrances = {
        { letter = "A)", info = LMD["Silverwing Hold"] .. " (A)" },
        { letter = "B)", info = LMD["Warsong Lumber Mill"] .. " (H)" }
    },
    Bosses = {}
}
