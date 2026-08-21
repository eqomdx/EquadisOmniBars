--[[ Equadis' Classic Overhaul :: unit frames

  Ported from Equadis' UnitFrames, which is UnitFramesImproved_Vanilla by Ko0zi
  (Richard Bertilsson), which is UnitFramesImproved for Legion by Althalla (Kim
  Forsberg). MIT -- see NOTICE.

  **These are Blizzard's frames, restyled.** Not replacements. That is the whole
  design of the addon this comes from and it is the right one for 1.12: the
  player, target, target-of-target and pet frames already exist, already know
  which unit they are showing, already update on the right events, and already
  handle every case a replacement would have to rediscover -- ghosts, tapped
  mobs, the pet happiness meter, the rested indicator.

  What they do badly is *look* like 2004 and refuse to say how much health
  anybody has. Both of those are texture and font work on frames that are
  already correct.

  **The settings are reworked rather than transcribed**, which is the part that
  needed doing. The original had five pages of its own -- General, Colors, Text,
  Position, Bars -- built with its own panel code, plus four settings hidden in
  CVars because that was the only way to make them per-character. Here they are
  sections of one tab in the same generator that builds every other page, and
  the four CVars become ordinary profile keys like everything else.

  Everything the original does is here, including the four pieces it bundles
  from elsewhere: the mob health estimate, the feigning-hunter health, the
  retarget helper and the compact target frame. Two of the five it also bundled --
  the energy ticker and the druid mana estimate -- were already modules of this
  addon, ported from their own sources.

  **UFI is the behavioural baseline.** This module deliberately keeps ECO's profile,
  media and options shell, but the frame geometry, Feign Death handling, retarget
  state machine and MobHealth estimator follow UnitFramesImproved_Vanilla again.

  UFI's custom frame artwork is used automatically when the original addon folder
  is still installed (it may remain disabled). If those binary assets are not
  present, the module falls back to Blizzard's own targeting-frame art while
  keeping the same geometry and behaviour. This makes the repair usable before
  the artwork is physically copied into ECO and, importantly, never leaves a
  missing-texture rectangle on screen.

  **What took the longest to get right was not a setting but who owns the
  strings.** See "taking over the client's own text and colour" below: Blizzard
  writes into these font strings on its own schedule and hides them by default,
  so a port that sets them from an event handler has every text and colour
  setting on the page silently doing nothing. Both client functions are replaced,
  which is what the original does and the only thing 1.12 allows.
]]--

local OB = EquadisClassicOverhaul

--[[ **Every line this file writes says which part of the addon it came from.**

     One prefix, one colour, and the name after it -- so a message about the
     chat scan says so, rather than leaving the reader to work out which of
     eleven things is talking. See OB.Print. ]]--
local function Say(msg) OB.Print(msg, "Unit Frames") end

-- ---------------------------------------------------------------------------
-- the frames, and what each of them is made of
-- ---------------------------------------------------------------------------

--[[ **Blizzard's own names for the pieces**, which are not consistent and cannot
     be derived.

     `PlayerFrameHealthBar` and `TargetFrameHealthBar` follow a pattern;
     `PetFrameHealthBar` follows it too but the pet's *text* is
     `PetFrameHealthBarText` while the player's is `PlayerFrameHealthBarText` --
     which looks the same until you notice target-of-target has no text at all
     and no mana bar worth the name.

     Written out rather than built from a prefix, because the exceptions are the
     whole difficulty and a loop that generated the regular cases would leave
     them to be discovered one bug report at a time. ]]--
local FRAMES = {
    {
        id = "player",
        setting = "replacePlayer",
        frame = "PlayerFrame",
        health = "PlayerFrameHealthBar",
        power = "PlayerFrameManaBar",
        name = "PlayerName",
        portrait = "PlayerPortrait",
        unit = "player",
    },
    {
        id = "target",
        setting = "replaceTarget",
        frame = "TargetFrame",
        health = "TargetFrameHealthBar",
        power = "TargetFrameManaBar",
        name = "TargetFrameTextureFrameName",
        portrait = "TargetPortrait",
        unit = "target",
    },
    {
        id = "targettarget",
        setting = "replaceTargetTarget",
        frame = "TargetofTargetFrame",
        health = "TargetofTargetHealthBar",
        power = "TargetofTargetManaBar",
        name = "TargetofTargetName",
        portrait = "TargetofTargetPortrait",
        unit = "targettarget",
    },
    {
        id = "pet",
        setting = "replacePet",
        frame = "PetFrame",
        health = "PetFrameHealthBar",
        power = "PetFrameManaBar",
        name = "PetName",
        portrait = "PetPortrait",
        unit = "pet",
    },
}

--[[ The party frames, which are four of the same thing and *can* be built from
     a prefix -- so they are. The exception above is an exception, not a rule. ]]--
local PARTY = 4

--[[ **Class portraits, from the client's own art.**

     The addon this comes from ships a copy of `UI-CLASSES-CIRCLES`, which is
     Blizzard's file. It is already installed -- it is in the client -- so the
     copy is not ported and the client's path is used instead. Nothing to
     relicense, nothing to keep in step with a patch.

     The coordinates are the TBC atlas layout, four across and three down, which
     is what the original carries and what the file contains. ]]--
local UFI_ROOT = "Interface\\AddOns\\UnitFramesImproved_Vanilla\\"
local FEIGN_TEXTURE = "Interface\\Icons\\Ability_Rogue_FeignDeath"
local PVP_TIMER_FONT = "Fonts\\FRIZQT__.TTF"
local PVP_TIMER_SIZE = 6
local PVP_TIMER_R, PVP_TIMER_G, PVP_TIMER_B = 1, 0.82, 0
local CLIENT_PORTRAIT_ART = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local LEGACY_PORTRAIT_ART = UFI_ROOT .. "UI-CLASSES-CIRCLES"

-- Exact coordinates carried by UFI's copy of the TBC class-circle atlas. The
-- 0.496/0.742 values avoid sampling the neighbouring icon's edge.
local LEGACY_PORTRAITS = {
    HUNTER  = { 0,          0.25,       0.25, 0.5  },
    WARRIOR = { 0,          0.25,       0,    0.25 },
    ROGUE   = { 0.49609375, 0.7421875,  0,    0.25 },
    MAGE    = { 0.25,       0.49609375, 0,    0.25 },
    PRIEST  = { 0.49609375, 0.7421875,  0.25, 0.5  },
    WARLOCK = { 0.7421875,  0.98828125, 0.25, 0.5  },
    DRUID   = { 0.7421875,  0.98828125, 0,    0.25 },
    SHAMAN  = { 0.25,       0.49609375, 0.25, 0.5  },
    PALADIN = { 0,          0.25,       0.5,  0.75 },
}

-- Fallback atlas in the stock client. It has clean quarter boundaries rather
-- than UFI's copied texture's padded edges.
local CLIENT_PORTRAITS = {
    WARRIOR = { 0,    0.25, 0,    0.25 },
    MAGE    = { 0.25, 0.5,  0,    0.25 },
    ROGUE   = { 0.5,  0.75, 0,    0.25 },
    DRUID   = { 0.75, 1.0,  0,    0.25 },
    HUNTER  = { 0,    0.25, 0.25, 0.5  },
    SHAMAN  = { 0.25, 0.5,  0.25, 0.5  },
    PRIEST  = { 0.5,  0.75, 0.25, 0.5  },
    WARLOCK = { 0.75, 1.0,  0.25, 0.5  },
    PALADIN = { 0,    0.25, 0.5,  0.75 },
}

local function legacyAssetsInstalled()
    if type(GetAddOnInfo) ~= "function" then return false end
    local name = GetAddOnInfo("UnitFramesImproved_Vanilla")
    return name and true or false
end

local function classPortraitCoords(class)
    -- 1.12 already exposes the coordinates for the CharacterCreate class atlas.
    -- Prefer those exact client coordinates; the previous ECO port guessed the
    -- quarter boundaries and also passed a second argument to SetTexture, which
    -- leaves a black portrait on some Vanilla clients.
    if type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[class] then
        return CLASS_ICON_TCOORDS[class]
    end
    return CLIENT_PORTRAITS[class]
end

-- ---------------------------------------------------------------------------
-- module
-- ---------------------------------------------------------------------------

--[[ **The original's five formats plus one.**

     It offers value/max, value, percent, value (percent) and none. The sixth --
     value/max (percent) -- is this addon's, and is here because the HUD and the
     meters already offer it and a unit frame that could not would be the odd one
     out. Everything the original has is present and means the same thing. ]]--
OB.unitTextModes = { "None", "Current", "Percent", "Current / Max",
                     "Current (Percent)", "Current / Max (Percent)" }

local TEXT_KEYS = { "none", "value", "percent", "max", "valuepct", "maxpct" }

local M = OB.RegisterModule({
    id = "unitframes",
    name = "Unit Frames",

    feature = true,
    tickly = true,

    --[[ It draws into frames the client owns rather than into a bar of this
         addon's -- the same declaration as chat, action bars and nameplates,
         and for the same reason. ]]--

    --[[ **Draws with the shared look**, so its page carries the texture, font,
         size, outline and border rows.

         Declared rather than inferred, because nothing about a module implies
         it: `renders` says "none" for nameplates and unit frames, which draw
         into the client's frames and use every one of the five.

         Chat, the roster and quality of life do not have this, and action bars
         gave it up -- they use a font and nothing else, so three of the five
         rows were controls that did nothing. ]]--
    styled = true,
    renders = "none",

    --[[ Off. It restyles the four frames somebody is looking at all the time,
         and next to another unit frame addon it is a fight. ]]--
    defaultEnabled = false,

    defaults = {
        --[[ Which frames to take over comes first because everything else
             depends on it -- and because taking over a frame somebody wanted
             left alone is the one thing a unit frame addon must not do by
             surprise. ]]--
        replacePlayer = true,
        replaceTarget = true,
        replaceTargetTarget = true,
        replaceParty = true,
        replacePet = true,

        --[[ **Text on the bars, which is the reason people install one of
             these.** 1.12 shows a percentage on mouseover and nothing the rest
             of the time. ]]--
        healthText = "maxpct",
        powerText = "value",

        --[[ Short numbers -- 1.11k rather than 1110. The original called this
             "true format" and had it off; on is right, because the whole point
             of the text is being read at a glance and five digits are not. ]]--
        shortNumbers = true,
        decimals = 1,

        healthSize = 10,
        powerSize = 10,
        nameSize = 11,
        nameOutline = true,

        --[[ Nudges, because Blizzard's art leaves the text sitting where the
             art wants it rather than where the bar is. Kept as offsets from the
             client's own anchor so zero means "where it was". ]]--
        healthX = 0, healthY = 0,
        powerX = 0, powerY = 0,
        nameX = 0, nameY = 5,

        --[[ **Colour.** Class colour on players is what everybody wants; on NPCs
             it is nonsense, because an NPC's "class" is whatever the server
             happened to give it. Off for them, and reaction colour instead. ]]--
        classColorHealth = true,
        npcClassColor = false,
        colorText = true,

        --[[ **The player's own bar, for when it is not class coloured.**

             "Not class coloured" still has to be *some* colour, and the
             client's is green -- which is Blizzard's answer, not a choice. The
             original carries this swatch for exactly that reason and the port
             had dropped it, which left switching class colour off looking like
             it did nothing. ]]--
        playerColor = { 0.29, 0.67, 0.30, 1 },

        tappedColor = { 0.55, 0.55, 0.55, 1 },
        hostileColor = { 0.78, 0.25, 0.25, 1 },
        neutralColor = { 0.85, 0.77, 0.36, 1 },
        friendlyColor = { 0.29, 0.67, 0.30, 1 },

        --[[ Portraits as class icons rather than as the 3D model, which is the
             original's most-recognised feature. The art is the client's own --
             see PORTRAIT_ART. ]]--
        classPortrait = true,

        --[[ Dark mode: the frame art tinted down so it stops being the
             brightest thing on screen. A tint rather than a replacement, so it
             works whatever the client's art actually is. ]]--
        -- Dark Mode is one continuous 0-90 slider. It is stored as 0.0-0.9 so
        -- existing profiles keep their old "How Dark" value without migration.
        darkMode = true, -- legacy migration key; no longer exposed
        darkness = 0.4,

        --[[ **The combat glow behind the player portrait, and the pet's attack
             flash.** The client draws both and they are the only indication
             that you are actually in combat rather than merely near it. On,
             because that is what the client does. ]]--
        statusGlow = false,

        --[[ **The pet frame drawn as a target-of-target frame**, which is
             smaller and better proportioned than the client's pet art, with
             happiness read as a colour: fed, content, unhappy. The original's
             Improved Pet. ]]--
        improvedPet = true,

        --[[ The pet's numbers hidden. A pet bar is small and its exact health
             is rarely the thing you are reading. The original ships this on;
             so does this. ]]--
        hidePetText = true,

        --[[ **The target frame without a mana bar.** Most things you fight do
             not have one worth watching, and the space it takes is the space the
             health bar wants. The original's Compact Mode. ]]--
        compact = true,

        --[[ **How much health a mob actually has**, worked out rather than
             asked for.

             1.12 answers `UnitHealthMax` for a mob with 100, because what it
             gives is a percentage. MobHealth3's insight is that the percentage
             and the damage you deal are two views of the same number: hit
             something for 340 and watch it drop four percent, and it has 8500.

             On. It costs one subtraction per damage event and it is the
             difference between "62%" and "5.3k", which is the difference between
             guessing whether you can finish something and knowing. ]]--
        mobHealth = true,
        mobHealthPrecision = 10,
        mobHealthStableMax = false,

        --[[ **A hunter's real health while feigning.** The client reports a
             feigned hunter as dead at zero, which in a raid is a healer watching
             somebody they think is a corpse. The last real value is remembered
             and shown instead. ]]--
        feignHealth = true,

        --[[ **Re-target somebody who vanished.** Feign Death, Vanish and Invis
             all clear your target, and the target you had is almost always the
             target you still want. Off, because it is the one thing here that
             acts on its own. ]]--
        retarget = false,

        --[[ Where the player and target frames were dragged to, as offsets from
             the centre of the screen. Empty means the client's own anchors,
             which is where they have always been. ]]--
        positions = {},
    },

    options = {
        { "Which Frames", "__s_which", "section", "which" },

        { "Player", "replacePlayer", "boolean" },
        { "Target", "replaceTarget", "boolean" },
        { "Target Of Target", "replaceTargetTarget", "boolean" },
        { "Party", "replaceParty", "boolean" },
        { "Pet", "replacePet", "boolean" },

        { "Text", "__s_text", "section", "text" },

        { "Health Text", "healthText", OB.Enum(TEXT_KEYS, OB.unitTextModes) },
        { "Power Text", "powerText", OB.Enum(TEXT_KEYS, OB.unitTextModes) },
        { "Hide The Pet's Numbers", "hidePetText", "boolean",
          nil, nil, nil, nil, nil, "!replacePet" },

        { "Shorten Numbers Under 10k", "shortNumbers", "boolean" },
        { "Decimal Places", "decimals", "slider", 0, 3, 1,
          nil, nil, "!shortNumbers" },

        { "Health Text Size", "healthSize", "slider", 6, 20, 1 },
        { "Power Text Size", "powerSize", "slider", 6, 20, 1 },
        { "Name Size", "nameSize", "slider", 6, 20, 1 },
        { "Outline The Name", "nameOutline", "boolean" },

        { "Nudges", "__s_pos", "section", "pos" },

        --[[ Offsets from where the client put them, so zero is "unchanged" and
             somebody who has not touched these sees Blizzard's own layout. ]]--
        { "Health Text Across", "healthX", "slider", -60, 60, 1 },
        { "Health Text Up", "healthY", "slider", -30, 30, 1 },
        { "Power Text Across", "powerX", "slider", -60, 60, 1 },
        { "Power Text Up", "powerY", "slider", -30, 30, 1 },
        { "Name Across", "nameX", "slider", -60, 60, 1 },
        { "Name Up", "nameY", "slider", -30, 30, 1 },

        { "Colors", "__s_colors", "section", "colors" },

        { "Color Players By Class", "classColorHealth", "boolean" },
        { "Color NPCs By Class Too", "npcClassColor", "boolean" },
        --[[ Health ramps red-to-green by what is left; resource takes its power
             type's own colour. Not "match the bar" -- purple text on a purple
             bar is the one arrangement that cannot be read. ]]--
        { "Color The Numbers Too", "colorText", "boolean" },

        { "Player", "playerColor", "color", true, nil, nil, nil, nil, "classColorHealth" },
        { "Hostile", "hostileColor", "color", true },
        { "Neutral", "neutralColor", "color", true },
        { "Friendly", "friendlyColor", "color", true },
        { "Tapped By Somebody Else", "tappedColor", "color", true },

        { "Appearance", "__s_look", "section", "look" },

        { "Class Icon Instead Of Portrait", "classPortrait", "boolean" },
        { "Combat Glow", "statusGlow", "boolean" },
        { "Slimmer Pet Frame", "improvedPet", "boolean",
          nil, nil, nil, nil, nil, "!replacePet" },
        { "Dark Mode", "darkness", "slider", 0, 90, 5, 0.01 },
        { "Compact Player & Target Frames", "compact", "boolean" },

        --[[ A mode rather than a lock, the same shape the action bars use: a
             permanently draggable player frame is one you move by accident. ]]--
        { "Move The Frames", "__a_ufdrag", "action",
          function() OB.modules.unitframes:SetDragMode(
                  not OB.modules.unitframes:DragMode()) end,
          function()
              if OB.modules.unitframes:DragMode() then return "Done Moving" end
              return "Move The Frames"
          end },

        { "Put Them Back", "__a_ufdragreset", "action",
          function() OB.modules.unitframes:ResetPositions() end },

        { "Knowing More", "__s_know", "section", "know" },

        { "|cffff5555Mob Flee Icon|r", "plannedMobFleeIcon", "boolean",
          nil, nil, nil, nil, nil, "!__notImplemented" },
        { "Work Out How Much Health Mobs Have", "mobHealth", "boolean" },
        { "Mob Health Precision", "mobHealthPrecision", "slider", 1, 99, 1,
          nil, nil, "!mobHealth" },
        { "Keep Mob Max Stable During Fight", "mobHealthStableMax", "boolean",
          nil, nil, nil, nil, nil, "!mobHealth" },
        { "Show A Feigning Hunter's Real Health", "feignHealth", "boolean" },
        { "Re-Target Somebody Who Vanished", "retarget", "boolean" },

        { "Forget Every Measured Mob", "__a_forgetmobs", "action",
          function()
              EquadisClassicOverhaulDB.mobHealth = {}
              OB.mobHealth = EquadisClassicOverhaulDB.mobHealth
              local m = OB.modules.unitframes
              m.mobAccHP, m.mobAccPerc, m.mobNoCalc = {}, {}, {}
              m.mobCurrent = nil
              m:MobTargetChanged()
              Say("forgot every measured mob health.")
          end,
          function()
              local n = 0
              for _ in pairs(OB.mobHealth or {}) do n = n + 1 end
              if n == 0 then return "No Mobs Measured Yet" end
              return "Forget " .. n .. " Measured Mob" .. (n == 1 and "" or "s")
          end },
    },

    --[[ Every event that changes what a frame is showing. The unit frames are
         Blizzard's and update themselves; what these are for is re-applying the
         *style* afterwards, because the client repaints a bar's colour and its
         text whenever the unit changes. ]]--
    events = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_TARGET_CHANGED",
        "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_COMBAT", "UNIT_AURA",
        "UNIT_MANA", "UNIT_MAXMANA",
        "UNIT_ENERGY", "UNIT_RAGE", "UNIT_FOCUS",
        "UNIT_PET", "UNIT_FACTION", "UNIT_DISPLAYPOWER",
        "PLAYER_FLAGS_CHANGED",
        "PARTY_MEMBERS_CHANGED",
    },
})

function M:Config()
    return OB.profile.modules.unitframes
end

-- ---------------------------------------------------------------------------
-- player PvP unflag countdown
-- ---------------------------------------------------------------------------

--[[ When /pvp is turned off, Vanilla leaves the faction PvP icon visible while
     a five-minute grace timer runs. `GetPVPTimer()` is the client-owned source
     of truth for that timer: a permanent flag reports 301000ms, while the
     actual unflag countdown is 300000ms down to zero.

     The readout deliberately has no option yet. The first pass is the requested
     fixed look: yellow Friz Quadrata at 6pt, minutes and seconds, directly beside
     the player's PvP icon. Once the size/position has been seen in-game we can
     make those adjustable if useful. ]]--
function M:PVPTimerText()
    if self.pvpTimerText then return self.pvpTimerText end

    local parent = getglobal("PlayerFrame") or UIParent
    if not parent or not parent.CreateFontString then return nil end

    local text = parent:CreateFontString("EquadisClassicOverhaulPVPTimer", "OVERLAY")
    if not text then return nil end

    text:SetFont(PVP_TIMER_FONT, PVP_TIMER_SIZE)
    text:SetTextColor(PVP_TIMER_R, PVP_TIMER_G, PVP_TIMER_B)
    text:SetJustifyH("LEFT")
    text:SetWidth(42)
    text:SetHeight(8)
    text:Hide()

    self.pvpTimerText = text
    self:PlacePVPTimer()
    return text
end

function M:PlacePVPTimer()
    local text = self.pvpTimerText
    if not text then return false end

    text:ClearAllPoints()

    -- The faction icon is the natural anchor: the countdown explains why that
    -- icon is still present after PvP has been switched off. Some 1.12-derived
    -- clients rename or omit the icon region, so the player name is the safe
    -- fallback rather than leaving the text unattached.
    local icon = getglobal("PlayerPVPIcon")
    local name = getglobal("PlayerName")

    if icon then
        text:SetPoint("LEFT", icon, "RIGHT", 2, 0)
    elseif name then
        text:SetPoint("LEFT", name, "RIGHT", 4, 0)
    else
        text:SetPoint("TOPLEFT", getglobal("PlayerFrame") or UIParent, "TOPLEFT", 112, -10)
    end

    return true
end

function M:HidePVPTimer()
    if self.pvpTimerText then self.pvpTimerText:Hide() end
    self.lastPVPTimerSecond = nil
end

function M:UpdatePVPTimer(force)
    if not OB.ModuleEnabled("unitframes") or not self:Config().replacePlayer then
        self:HidePVPTimer()
        return false
    end

    if type(GetPVPTimer) ~= "function" or type(UnitIsPVP) ~= "function"
            or not UnitIsPVP("player") then
        self:HidePVPTimer()
        return false
    end

    local ms = tonumber(GetPVPTimer())

    -- 301000 is Vanilla's sentinel for a permanent PvP flag. Values above the
    -- five-minute grace period are therefore not a countdown and should not be
    -- displayed.
    if not ms or ms <= 0 or ms > 300000 then
        self:HidePVPTimer()
        return false
    end

    -- Ceil rather than floor keeps the first visible value at 5M 00S instead
    -- of dropping to 4M 59S a fraction of a second after the toggle.
    local seconds = math.ceil(ms / 1000)
    if seconds < 0 then seconds = 0 end
    if seconds > 300 then seconds = 300 end

    local text = self:PVPTimerText()
    if not text then return false end

    if force or self.lastPVPTimerSecond ~= seconds then
        local minutes = math.floor(seconds / 60)
        local remainder = math.mod(seconds, 60)
        text:SetText(string.format("%dM %02dS", minutes, remainder))
        self.lastPVPTimerSecond = seconds
    end

    self:PlacePVPTimer()
    text:Show()
    return true
end

-- Appearance > Font Size is the subsystem-wide master size. Unit Frames also
-- has separate health/power/name sliders, so the shared control scales those
-- three values instead of replacing them. At the shared default of 12 this is
-- exactly 1.0 and preserves the element-specific defaults.
function M:FontScale()
    local look = OB.Look("unitframes")
    local size = tonumber(look.fontSize) or 12
    if size < 1 then size = 12 end
    return size / 12
end

function M:TextSize(base, drop)
    local size = (tonumber(base) or 10) - (drop or 0)
    size = size * self:FontScale()
    if size < 4 then size = 4 end
    return math.floor(size + 0.5)
end

-- One Dark Mode slider. Existing builds already stored darkness as 0.1-0.9,
-- so the option uses a 0.01 display factor: the panel shows 0-90 while the
-- saved value remains compatible. A profile that had the old boolean disabled
-- is converted to slider zero the first time it is styled.
function M:DarkAmount()
    local cfg = self:Config()
    local raw = tonumber(cfg.darkness)
    if raw == nil then raw = 0.4 end

    if cfg.darkMode == false then
        raw = 0
        cfg.darkMode = true
        cfg.darkness = 0
    elseif raw > 1 then
        -- Defensive compatibility with the short-lived 0-100 repair format.
        raw = raw / 100
        cfg.darkness = raw
    end

    if raw < 0 then raw = 0 end
    if raw > 1 then raw = 1 end
    return raw
end

function M:DarkShade()
    return 1 - self:DarkAmount()
end

-- ---------------------------------------------------------------------------
-- what colour a unit is
-- ---------------------------------------------------------------------------

--[[ **Whose colour, and why an NPC's class is not one.**

     A player gets their class colour, which is what everybody means by "class
     coloured frames".

     An NPC has a class too -- the server gives every creature one -- and it is
     meaningless: a wolf is a warrior. So NPCs get their *reaction* instead,
     which is the thing you actually want to know, and the class option for them
     is off and stays a separate switch rather than being folded in.

     A tapped mob is grey before anything else is considered. It does not matter
     what colour it would otherwise be; you cannot loot it, and that is the fact
     worth showing. ]]--
function M:UnitColor(unit)
    local cfg = self:Config()
    if not UnitExists(unit) then return nil end

    -- UFI's target update gives tap ownership first priority: a mob somebody
    -- else tagged is grey regardless of reaction or NPC class.
    if not UnitIsPlayer(unit) and type(UnitIsTapped) == "function"
            and UnitIsTapped(unit)
            and type(UnitIsTappedByPlayer) == "function"
            and not UnitIsTappedByPlayer(unit) then
        return cfg.tappedColor
    end

    if not UnitIsPlayer(unit) then
        if type(UnitIsConnected) == "function" and not UnitIsConnected(unit) then
            return cfg.tappedColor
        end
        if type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost(unit) then
            return cfg.tappedColor
        end
    end

    local _, class = UnitClass(unit)

    if UnitIsPlayer(unit) then
        if cfg.classColorHealth and class then
            local r, g, b = OB.ClassColor(class)
            if r then return { r, g, b, 1 } end
        end
        return self:ReactionColor(unit)
    end

    if cfg.npcClassColor and class then
        local r, g, b = OB.ClassColor(class)
        if r then return { r, g, b, 1 } end
    end

    return self:ReactionColor(unit)
end

function M:ReactionColor(unit)
    local cfg = self:Config()

    if type(UnitReaction) ~= "function" then return cfg.hostileColor end

    local reaction = UnitReaction(unit, "player")
    if not reaction then return cfg.hostileColor end

    if reaction > 4 then return cfg.friendlyColor end
    if reaction == 4 then return cfg.neutralColor end

    return cfg.hostileColor
end

-- ---------------------------------------------------------------------------
-- how much health a mob actually has
-- ---------------------------------------------------------------------------

--[[ **1.12 will not tell you, and MobHealth3 worked out that it does not have
     to.**

     `UnitHealthMax` on a mob answers 100, because what the client gives is a
     percentage. But the percentage and the damage you deal are two views of the
     same number: hit something for 340, watch it drop four percent, and it has
     eight and a half thousand.

     `max = damage / percentLost * 100`, accumulated over a fight so one unlucky
     rounding does not decide it.

     **Keyed by name and level together**, which is not fussiness: a level 22
     Defias Thug and a level 24 one are different creatures with the same name,
     and averaging them gives a number that is wrong for both.

     Account-wide beside the vendor prices and the cast times, on the same
     argument -- how much health a Defias Thug has is a fact about the game. ]]--
function OB.MobKey(name, level)
    if not name or name == "" then return nil end
    return name .. ":" .. tostring(level or 0)
end

-- Accept both the old ECO sample table and the repaired MobHealth3-shaped table.
function OB.MobHealthMax(name, level)
    local key = OB.MobKey(name, level)
    local known = key and OB.mobHealth and OB.mobHealth[key]
    if type(known) == "number" then return known end
    if type(known) ~= "table" then return nil end
    return known.max
end

-- Compatibility for the first ECO port and any neighbour that used its tiny
-- helper. The live estimator below uses UNIT_COMBAT like MobHealth3; this helper
-- simply feeds an already-known damage/percentage observation into the same
-- cache shape.
function OB.LearnMobHealth(name, level, damage, percentLost)
    local key = OB.MobKey(name, level)
    damage, percentLost = tonumber(damage), tonumber(percentLost)
    if not key or not damage or damage <= 0 or not percentLost or percentLost <= 0 then
        return false
    end

    OB.mobHealth = OB.mobHealth or {}
    local known = OB.mobHealth[key]
    local accHP, accPerc = 0, 0
    if type(known) == "table" then
        accHP = tonumber(known.damage) or tonumber(known.max) or 0
        accPerc = tonumber(known.percent) or (known.max and 100 or 0)
    elseif type(known) == "number" then
        accHP, accPerc = known, 100
    end

    accHP, accPerc = accHP + damage, accPerc + percentLost
    local max = math.floor(accHP / accPerc * 100 + 0.5)
    OB.mobHealth[key] = { max = max, damage = accHP, percent = accPerc }

    local frames = OB.modules and OB.modules.unitframes
    if frames then
        frames.mobAccHP = frames.mobAccHP or {}
        frames.mobAccPerc = frames.mobAccPerc or {}
        frames.mobAccHP[key], frames.mobAccPerc[key] = accHP, accPerc
    end
    return max
end

-- ---------------------------------------------------------------------------
-- MobHealth3 behaviour, without Ace2
-- ---------------------------------------------------------------------------

M.mobAccHP = M.mobAccHP or {}
M.mobAccPerc = M.mobAccPerc or {}
M.mobNoCalc = M.mobNoCalc or {}

function M:MobTargetChanged()
    local cfg = self:Config()

    -- Stable-max mode commits the previous fight's accumulated estimate when
    -- the target changes, exactly where MobHealth3 does it.
    local old = self.mobCurrent
    if cfg.mobHealthStableMax and old and old.accHP and old.accHP > 0
            and old.accPerc and old.accPerc > 0 and old.key then
        local max = math.floor(old.accHP / old.accPerc * 100 + 0.5)
        OB.mobHealth[old.key] = {
            max = max, damage = old.accHP, percent = old.accPerc,
        }
        self.mobAccHP[old.key], self.mobAccPerc[old.key] = old.accHP, old.accPerc
    end

    self.mobCurrent = nil
    if not cfg.mobHealth or not UnitExists("target") then return false end
    -- ECO exposes this as *mob* health. Player max HP is volatile with gear and
    -- buffs and is not useful in this account-wide creature cache.
    if UnitIsPlayer("target") then return false end
    if type(UnitCanAttack) == "function" and not UnitCanAttack("player", "target") then return false end
    if type(UnitIsDead) == "function" and UnitIsDead("target") then return false end
    if type(UnitIsFriend) == "function" and UnitIsFriend("player", "target") then return false end

    -- MobHealth3 excludes player-controlled beasts/demons so hunter/warlock pets
    -- sharing names with real creatures do not poison the cache.
    local creature = type(UnitCreatureType) == "function" and UnitCreatureType("target") or nil
    if (creature == "Beast" or creature == "Demon")
            and type(UnitPlayerControlled) == "function"
            and UnitPlayerControlled("target") then
        return false
    end

    local name, level = UnitName("target"), UnitLevel("target")
    local key = OB.MobKey(name, level)
    if not key then return false end

    local start = UnitHealth("target")
    local known = OB.mobHealth and OB.mobHealth[key]
    local accHP, accPerc = self.mobAccHP[key], self.mobAccPerc[key]

    -- Session accumulators are separate from the persistent display cache in
    -- MobHealth3. That distinction matters: a mob changed before reaching the
    -- precision threshold must keep the samples it already taught us.
    if accHP == nil or accPerc == nil then
        if type(known) == "table" and known.damage and known.percent then
            accHP, accPerc = known.damage, known.percent
        elseif type(known) == "table" and known.max then
            accHP, accPerc = known.max, 100
        elseif type(known) == "number" then
            accHP, accPerc = known, 100
        else
            accHP, accPerc = 0, 0
        end
    end

    -- MobHealth3 limits the memory of a mob to roughly two kills so variants
    -- with the same name/level can eventually correct an old estimate.
    if accPerc > 200 then
        accHP = accHP / accPerc * 100
        accPerc = 100
    end
    self.mobAccHP[key], self.mobAccPerc[key] = accHP, accPerc

    self.mobCurrent = {
        key = key, name = name, level = level,
        start = start, last = start,
        recent = 0, total = 0,
        accHP = accHP, accPerc = accPerc,
        stableHadValue = OB.MobHealthMax(name, level) and true or false,
    }
    return true
end

function M:MobCombat(amount)
    local m = self.mobCurrent
    amount = tonumber(amount)
    if not m or not amount or amount <= 0 then return false end
    m.recent = m.recent + amount
    m.total = m.total + amount
    return true
end

function M:MobHealthUpdate()
    local m = self.mobCurrent
    if not m or not UnitExists("target") then return false end
    if OB.MobKey(UnitName("target"), UnitLevel("target")) ~= m.key then
        return self:MobTargetChanged()
    end

    local current, max = UnitHealth("target"), UnitHealthMax("target")
    if self.mobNoCalc[m.key] then return false end
    if current == m.start or current == 0 then return false end

    -- Beast Lore (and some private-server APIs) can reveal real HP. Trust it and
    -- stop estimating; this is strictly better information.
    if max and max > 100 then
        OB.mobHealth[m.key] = { max = max, damage = max, percent = 100 }
        self.mobAccHP[m.key], self.mobAccPerc[m.key] = max, 100
        self.mobNoCalc[m.key] = true
        return true
    end

    -- A heal invalidates the pending damage-to-percent relationship.
    if current > m.last or m.start > 100 then
        m.last = current
        m.start = current
        m.recent = 0
        m.total = 0
        return false
    end

    if m.recent <= 0 or current == m.last then return false end

    m.accHP = m.accHP + m.recent
    m.accPerc = m.accPerc + (m.last - current)
    self.mobAccHP[m.key], self.mobAccPerc[m.key] = m.accHP, m.accPerc
    m.recent = 0
    m.last = current

    local cfg = self:Config()
    local precision = tonumber(cfg.mobHealthPrecision) or 10
    if m.accPerc < precision then return false end

    if cfg.mobHealthStableMax and m.stableHadValue then return false end

    local estimate = math.floor(m.accHP / m.accPerc * 100 + 0.5)
    OB.mobHealth[m.key] = {
        max = estimate, damage = m.accHP, percent = m.accPerc,
    }
    m.stableHadValue = true
    return true
end

-- ---------------------------------------------------------------------------
-- SimpleFeignHealth behaviour, scoped to ECO's own unit-frame text
-- ---------------------------------------------------------------------------

OB.feignedHealth = OB.feignedHealth or {}

function M:IsFeigning(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    local _, class = UnitClass(unit)
    if class ~= "HUNTER" then return false end
    if type(UnitBuff) ~= "function" then return false end

    local i = 1
    while i <= 32 do
        local texture = UnitBuff(unit, i)
        if not texture then break end
        if texture == FEIGN_TEXTURE then return true end
        i = i + 1
    end
    return false
end

local function unitDead(unit)
    if type(UnitIsDeadOrGhost) == "function" then return UnitIsDeadOrGhost(unit) and true or false end
    if type(UnitIsDead) == "function" then return UnitIsDead(unit) and true or false end
    return false
end

function M:NoteFeign(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if not name or class ~= "HUNTER" then return false end

    -- Never replace the cache with the zero the client reports once FD begins.
    if unitDead(unit) then return false end

    local health = UnitHealth(unit)
    if not health or health <= 0 then return false end

    OB.feignedHealth[name] = {
        health = health,
        max = UnitHealthMax(unit),
        mana = UnitMana(unit),
        manaMax = UnitManaMax(unit),
        at = type(GetTime) == "function" and GetTime() or 0,
    }
    return true
end

-- SimpleFeignHealth asks a hidden unit tooltip for a feigning hunter's real
-- current HP. Keep that useful part, but scope it to ECO rather than replacing
-- the global UnitHealth function for every addon in the UI.
function M:FeignActualHealth(unit)
    if type(CreateFrame) ~= "function" or not UIParent then return nil end

    if not self.feignScanner then
        local tip = CreateFrame("GameTooltip", "EquadisUnitFrameFeignScanner",
                UIParent, "GameTooltipTemplate")
        if not tip then return nil end
        if tip.SetOwner then tip:SetOwner(tip, "ANCHOR_NONE") end
        self.feignScanner = tip
        if tip.GetChildren then self.feignScannerBar = tip:GetChildren() end
    end

    local tip, bar = self.feignScanner, self.feignScannerBar
    if not tip or not tip.SetUnit then return nil end
    if tip.ClearLines then tip:ClearLines() end
    tip:SetUnit(unit)

    local value = bar and bar.GetValue and bar:GetValue()
    if value and value > 0 then return value end
    return nil
end

function M:HealthOf(unit)
    local live, max = UnitHealth(unit), UnitHealthMax(unit)
    if not self:Config().feignHealth or not unitDead(unit) or not self:IsFeigning(unit) then
        return live, max
    end
    local remembered = OB.feignedHealth[UnitName(unit) or ""]
    if not remembered then return live, max end
    return self:FeignActualHealth(unit) or remembered.health, remembered.max
end

function M:PowerOf(unit)
    local live, max = UnitMana(unit), UnitManaMax(unit)
    if not self:Config().feignHealth or not unitDead(unit) or not self:IsFeigning(unit) then
        return live, max
    end
    local remembered = OB.feignedHealth[UnitName(unit) or ""]
    if not remembered then return live, max end
    return remembered.mana or live, remembered.manaMax or max
end

function M:Number(value)
    local cfg = self:Config()
    value = value or 0

    if value > 1000000 then
        return string.format("%." .. cfg.decimals .. "fm", value / 1000000)
    end

    --[[ **Above ten thousand always shortens.** Five digits do not fit and
         nobody reads them; that is not a preference and the original does not
         offer it as one. ]]--
    if value > 10000 then
        return string.format("%." .. cfg.decimals .. "fk", value / 1000)
    end

    --[[ **The switch is only about the thousand-to-ten-thousand band**, which is
         exactly what the original's "Format HP<10k" means. "4.4k" or "4382" is a
         real preference: one is quicker to read and the other is the number.

         The port had this as "shorten everything above a thousand", which made
         the switch mean something the label did not say and made the band above
         ten thousand look like it obeyed a setting it never did. ]]--
    if value > 1000 and cfg.shortNumbers then
        return string.format("%." .. cfg.decimals .. "fk", value / 1000)
    end

    return tostring(OB.Round(value))
end

--[[ The text for one bar, in whichever of the six shapes was asked for.

     `OB.FormatValue` is the shared one -- the same function the resource bar and
     the health bar in the HUD use -- so "Current / Max (Percent)" means exactly
     the same thing in three places. What is different here is only that the
     numbers may be shortened first. ]]--
function M:BarText(value, max, mode)
    if mode == "none" then return "" end

    value = value or 0
    max = max or 0

    local function percent()
        if max == 0 then return "0%" end
        return math.floor((value / max) * 100 + 0.5) .. "%"
    end

    if mode == "percent" then return percent() end
    if mode == "value" then return self:Number(value) end
    if mode == "max" then return self:Number(value) .. "/" .. self:Number(max) end

    if mode == "valuepct" then
        return self:Number(value) .. " (" .. percent() .. ")"
    end

    if mode == "maxpct" then
        return self:Number(value) .. "/" .. self:Number(max)
                .. " (" .. percent() .. ")"
    end

    return self:Number(value)
end

-- ---------------------------------------------------------------------------
-- taking over the client's own text and colour
-- ---------------------------------------------------------------------------

--[[ **The client owns these strings, and it keeps writing to them.**

     `TextStatusBar_UpdateTextString` runs from every status bar's own
     `OnValueChanged`, which means it fires *after* any handler that took a
     damage event as its cue. The port wrote its text on the module's events and
     stopped there, so Blizzard overwrote it a frame later -- and every text
     setting on the page read as a setting that does nothing.

     Worse, the client *hides* the string unless the `statusBarText` CVar is on,
     which it is not by default. So even the frames where the timing happened to
     work showed nothing at all.

     `HealthBar_OnValueChanged` is the same problem in colour: it paints every
     health bar green on every value change.

     **So both are replaced, which is what the original does and the only thing
     that works.** 1.12 has no `hooksecurefunc` and no ordering guarantee that
     would let an event handler win a race against the client's own callback.

     **Installed once and never removed**, on the same rule as the chat hook: a
     method slot is one deep, so restoring our saved original silently deletes
     whatever a neighbour installed after us. The switches are read *inside*, and
     a module that is off delegates to the original -- which is the same
     behaviour as not being installed, without the hazard of uninstalling. ]]--
local BAR_ROLE = {}

for i = 1, table.getn(FRAMES) do
    BAR_ROLE[FRAMES[i].health] = { entry = FRAMES[i], role = "health" }
    BAR_ROLE[FRAMES[i].power] = { entry = FRAMES[i], role = "power" }
end

for i = 1, PARTY do
    BAR_ROLE["PartyMemberFrame" .. i .. "HealthBar"] = { party = i, role = "health" }
    BAR_ROLE["PartyMemberFrame" .. i .. "ManaBar"] = { party = i, role = "power" }
end

--[[ Which frame a bar belongs to and which of its two it is, or nil for a bar
     that is none of ours -- the focus frame, a raid frame, another addon's. ]]--
function M:BarRole(bar)
    if not bar or not bar.GetName then return nil end

    local found = BAR_ROLE[bar:GetName() or ""]
    if not found then return nil end

    local entry = found.entry
    if found.party then entry = self:PartyEntry(found.party) end

    if not entry or not self:Owns(entry) then return nil end

    return entry, found.role
end

--[[ **What colour the numbers are, which is not the colour of the bar.**

     The port had the text matching its bar, which sounds right and is not what
     the original does -- and on a class-coloured bar it makes a warlock's health
     purple text on a purple bar, which is the one arrangement that cannot be
     read.

     The original colours the two by what each one *means*:

     - health ramps red to green by how much is left, so the number and its
       colour say the same thing twice and either one is enough at a glance;
     - resource takes its power type's own colour -- energy pale, rage red, mana
       blue -- which is the same code the client uses on the bar itself.

     The ramp is `OB.Ramp` and the anchors are the health module's, so the number
     on a unit frame and the bar in the HUD agree about what "half" looks like
     rather than being two opinions. ]]--
function M:TextColor(role, value, max, unit)
    local cfg = self:Config()

    if not cfg.colorText then return 1, 1, 1 end

    if role == "health" then
        local fraction = 0
        if max and max > 0 then fraction = value / max end

        local health = OB.profile.modules.health
        local color = OB.Ramp(health.lowColor, health.halfColor,
                health.fullColor, fraction)

        return color[1], color[2], color[3]
    end

    --[[ Blizzard's own power colours, by type rather than by class: a druid in
         cat form is on energy and a druid in bear form is on rage, and reading
         the class would give both of them mana blue. ]]--
    local power = 0
    if type(UnitPowerType) == "function" then power = UnitPowerType(unit or "player") or 0 end

    if power == 3 then return 250 / 255, 240 / 255, 200 / 255 end
    if power == 1 then return 250 / 255, 108 / 255, 108 / 255 end

    return 0.6, 0.65, 1
end

--[[ **The text on one bar, written the way the panel asked for.**

     Everything the client's own version does is kept -- the zero text a dead
     unit shows, hiding a bar with no maximum -- because those are not styling,
     they are the frame working. What changes is the format, and that the string
     is *shown*: the CVar deciding whether Blizzard displays these at all is not
     a setting this addon should make somebody go and find. ]]--
function M:StatusText(bar)
    local entry, role = self:BarRole(bar)

    --[[ Not ours. The client's own version, unchanged -- which is what a module
         that is switched off has to look like. ]]--
    if not entry then return EquadisOverhaulBlizzStatusText(bar) end

    local text = bar.TextString or getglobal((bar:GetName() or "") .. "Text")
    if not text then return false end

    local cfg = self:Config()

    -- Blizzard rewrites these strings from TextStatusBar_UpdateTextString after
    -- frame styling. Re-apply the chosen font here, at the same point ECO writes
    -- the value, so Font/Font Size cannot be silently reset a frame later.
    local drop = (entry.id == "pet") and 2 or 0
    local baseSize = (role == "health") and cfg.healthSize or cfg.powerSize
    OB.ApplyFont(text, self:TextSize(baseSize, drop), "unitframes")

    local value, max = self:BarValues(entry, role, bar)

    if not max or max <= 0 then
        bar:Hide()
        return false
    end

    bar:Show()

    local mode = (role == "health") and cfg.healthText or cfg.powerText

    --[[ The pet's numbers, hidden as a whole rather than by setting its format
         to none -- which would be a second place the same decision is made. ]]--
    if cfg.hidePetText and entry.id == "pet" then mode = "none" end

    if mode == "none" then
        text:SetText("")
        text:Hide()
        return true
    end

    --[[ "Dead" rather than "0/8.0k", which is the client's own behaviour and is
         better than anything a format could say. ]]--
    if value == 0 and bar.zeroText then
        text:SetText(bar.zeroText)
        bar.isZero = 1
        text:Show()
        return true
    end

    bar.isZero = nil
    text:SetText(self:BarText(value, max, mode))
    text:SetTextColor(self:TextColor(role, value, max, entry.unit))
    text:Show()

    return true
end

--[[ What a bar should read, which is not always what the bar says.

     Two cases where the client is wrong and this addon knows better: a feigning
     hunter reports as dead at zero, and a mob reports a percentage as though it
     were health. Both are corrections to the *value*, so they belong here rather
     than in the formatter -- which then only has to turn numbers into text.

     The bar's own value is the fallback, and for anything without a unit it is
     the only answer there is. ]]--
function M:BarValues(entry, role, bar)
    local cfg = self:Config()

    if not UnitExists(entry.unit) then
        local _, max = bar:GetMinMaxValues()
        return bar:GetValue(), max
    end

    if role ~= "health" then
        return self:PowerOf(entry.unit)
    end

    local value, max = self:HealthOf(entry.unit)

    --[[ **A mob's real health, where it has been worked out.** The client
         answers 100 for max because what it gives is a percentage; if this addon
         knows the real number, the percentage is turned back into it. Falls back
         to the client's answer, so a mob nobody has hit reads exactly as it does
         without any of this. ]]--
    if cfg.mobHealth and not UnitIsPlayer(entry.unit) and max == 100 then
        local real = OB.MobHealthMax(UnitName(entry.unit), UnitLevel(entry.unit))

        if real then
            value = math.floor((value / 100) * real + 0.5)
            max = real
        end
    end

    return value, max
end

--[[ **The player's health bar colour, which the client repaints constantly.**

     Only the player's. The target, pet and party bars are coloured by the
     styling pass and marked `lockColor`, which is how the original keeps the
     client off them; the player's bar has no such flag in 1.12, so it is handled
     here instead. Every other bar falls through to Blizzard's own green. ]]--
function M:ColorUpdate(bar, value, smooth)
    if bar ~= getglobal("PlayerFrameHealthBar") or not self:Owns(FRAMES[1]) then
        return EquadisOverhaulBlizzHealthColor(value, smooth)
    end

    local cfg = self:Config()
    local color = cfg.playerColor

    if cfg.classColorHealth then
        local r, g, b = OB.ClassColor(OB.class)
        if r then color = { r, g, b, 1 } end
    end

    bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)

    return true
end

--[[ Both replacements, installed once.

     **Guarded on a global, and the guard is the saved original itself.**

     The replaced function lives in `_G` and outlives the addon namespace, which
     is rebuilt from scratch every load. A flag on `self` resets while the
     wrapper does not, so the second install wraps the first -- and a flag on
     `OB` is worse still: the wrapper survives and the original it delegates to
     does not, so every bar that is *not* ours calls nil.

     Guard and payload are therefore one object, in the one place that lasts as
     long as the thing being guarded. Third time this rule has been learned --
     the Escape menu button and the map label were the first two. ]]--
function M:InstallTextHooks()
    if EquadisOverhaulBlizzStatusText then return false end

    EquadisOverhaulBlizzStatusText = TextStatusBar_UpdateTextString
    EquadisOverhaulBlizzHealthColor = HealthBar_OnValueChanged

    --[[ **Both wrappers reach the module through the global name, never through
         the `OB` upvalue.**

         `core.lua` assigns `EquadisClassicOverhaul = {}` on every load, so the
         upvalue every module file captured points at whichever namespace existed
         when that file ran. The wrapper outlives that -- it is in `_G` -- so a
         wrapper holding the upvalue keeps calling a dead namespace: a module
         reading a profile nobody is editing any more, which looks exactly like
         settings that do nothing. ]]--
    TextStatusBar_UpdateTextString = function(bar)
        --[[ Blizzard calls this both ways: with the bar as an argument from
             elsewhere, and bare from the bar's own script with `this` set. ]]--
        local target = bar or this
        if not target then return end

        return EquadisClassicOverhaul.modules.unitframes:StatusText(target)
    end

    HealthBar_OnValueChanged = function(value, smooth)
        if not this then return end

        return EquadisClassicOverhaul.modules.unitframes
                :ColorUpdate(this, value, smooth)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- styling one frame
-- ---------------------------------------------------------------------------

--[[ Whether this frame is ours to touch. Asked per frame rather than once,
     because the switches are per frame and somebody who has turned the pet
     frame off should keep Blizzard's pet frame exactly as it was. ]]--
function M:Owns(entry)
    if not OB.ModuleEnabled("unitframes") then return false end
    return self:Config()[entry.setting] and true or false
end

-- A real frame around each Blizzard StatusBar. The Unit Frames page has always
-- exposed ECO's shared Border selector, but the old port never consumed it, so
-- changing None/Thin/Standard literally changed no pixels.
function M:BarBorder(bar)
    if not bar then return nil end
    self.barBorders = self.barBorders or {}
    if self.barBorders[bar] then return self.barBorders[bar] end

    local border = CreateFrame("Frame", nil, bar)
    if border.EnableMouse then border:EnableMouse(false) end
    if border.SetFrameLevel and bar.GetFrameLevel then
        border:SetFrameLevel((bar:GetFrameLevel() or 0) + 1)
    end
    self.barBorders[bar] = border
    return border
end

function M:StyleBarBorder(bar)
    local frame = self:BarBorder(bar)
    if not frame then return false end

    local look = OB.Look("unitframes")
    local index = tonumber(look.border) or 1
    local edge = OB.borderEdges[index]
    local pad = OB.borderPads[index] or 0

    if not edge or pad <= 0 then
        frame:SetBackdrop(nil)
        frame:Hide()
        return false
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", bar, "TOPLEFT", -pad, pad)
    frame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pad, -pad)
    frame:SetBackdrop(edge)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    frame:Show()
    return true
end

function M:HideBarBorder(bar)
    if self.barBorders and self.barBorders[bar] then
        self.barBorders[bar]:SetBackdrop(nil)
        self.barBorders[bar]:Hide()
    end
end

function M:HideBarBorders()
    if not self.barBorders then return end
    for _, frame in pairs(self.barBorders) do
        frame:SetBackdrop(nil)
        frame:Hide()
    end
end

--[[ **The bar textures, from the shared media list.**

     This is what makes a unit frame look like it belongs beside the HUD and the
     meters rather than beside the client's own art: one texture setting, read
     through `OB.Look`, the same as everything else this addon draws. ]]--
function M:StyleBar(bar, size, x, y, color)
    if not bar then return end

    local look = OB.Look("unitframes")

    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(OB.textures[look.texture] or OB.textures[1])
    end

    if color and bar.SetStatusBarColor then
        bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)

        --[[ **`lockColor` is how the client is told to keep off a bar.** Without
             it `UnitFrame_Update` repaints this the moment the unit changes, and
             the colour set here lasts until the next target. The player's bar
             has no such flag in 1.12, which is why that one is handled by
             replacing `HealthBar_OnValueChanged` instead. ]]--
        bar.lockColor = true
    end

    local text = bar.GetName and getglobal(bar:GetName() .. "Text")

    if text then
        OB.ApplyFont(text, self:TextSize(size), "unitframes")

        --[[ **Anchored every pass, not only when the offset is non-zero.**

             Setting it conditionally leaves the text wherever it was last put
             once somebody returns the slider to zero: a nudge that works going
             out and not coming back, which is worse than one that never worked.

             To its own bar rather than to the frame, which is the original's
             anchor and keeps the player and target texts level automatically --
             their bars are the same size at the same height, and a bar that
             grows carries its text with it. ]]--
        if text.SetPoint then
            text:ClearAllPoints()
            text:SetPoint("CENTER", bar, "CENTER", x, y)
        end

    end

    self:StyleBarBorder(bar)
end

--[[ **A class icon where the portrait was.**

     The art is the client's own -- see PORTRAIT_ART -- so nothing is copied and
     nothing has to be kept in step with a patch.

     Only for players. An NPC has no class worth drawing, and a wolf with a
     warrior's crest on it is worse than the model. ]]--
function M:RememberObject(name)
    self.original = self.original or {}
    if self.original[name] ~= nil then return end

    local obj = getglobal(name)
    if not obj then
        self.original[name] = false
        return
    end

    local snap = { object = obj }
    if obj.GetWidth then snap.width = obj:GetWidth() end
    if obj.GetHeight then snap.height = obj:GetHeight() end
    if obj.GetPoint then snap.point = { obj:GetPoint(1) } end
    if obj.IsShown then snap.shown = obj:IsShown() and true or false end
    if obj.GetTexture then
        snap.hasTexture = true
        snap.texture = obj:GetTexture()
    end
    if obj.GetTexCoord then snap.texcoord = { obj:GetTexCoord() } end
    if obj.GetVertexColor then snap.vertex = { obj:GetVertexColor() } end
    if obj.GetFont then snap.font = { obj:GetFont() } end
    if obj.GetTextColor then snap.textColor = { obj:GetTextColor() } end
    if obj.GetStatusBarColor then snap.barColor = { obj:GetStatusBarColor() } end
    if obj.GetStatusBarTexture then
        local tex = obj:GetStatusBarTexture()
        if type(tex) == "string" then
            snap.barTexture = tex
        elseif tex and tex.GetTexture then
            snap.barTexture = tex:GetTexture()
        end
    end
    snap.lockColor = obj.lockColor
    snap.capNumericDisplay = obj.capNumericDisplay
    self.original[name] = snap
end

function M:RememberOriginals()
    if self.originalCaptured then return end
    self.originalCaptured = true

    local names = {
        "PlayerFrame", "PlayerFrameTexture", "PlayerFrameBackground",
        "PlayerFrameHealthBar", "PlayerFrameManaBar", "PlayerFrameHealthBarText",
        "PlayerFrameManaBarText", "PlayerName", "PlayerPortrait", "PlayerStatusTexture",
        "TargetFrame", "TargetFrameTexture", "TargetFrameBackground",
        "TargetFrameHealthBar", "TargetFrameManaBar", "TargetFrameNameBackground",
        "TargetDeadText", "TargetFrameTextureFrameName", "TargetPortrait",
        "TargetofTargetFrame", "TargetofTargetTexture", "TargetofTargetPortrait",
        "TargetofTargetHealthBar", "TargetofTargetManaBar", "TargetofTargetName",
        "PetFrame", "PetFrameTexture", "PetPortrait", "PetAttackModeTexture",
        "PetFrameHealthBar", "PetFrameManaBar", "PetFrameHealthBarText",
        "PetFrameManaBarText", "PetName", "PetFrameHappiness",
    }

    for i = 1, PARTY do
        table.insert(names, "PartyMemberFrame" .. i)
        table.insert(names, "PartyMemberFrame" .. i .. "Texture")
        table.insert(names, "PartyMemberFrame" .. i .. "Portrait")
        table.insert(names, "PartyMemberFrame" .. i .. "HealthBar")
        table.insert(names, "PartyMemberFrame" .. i .. "ManaBar")
        table.insert(names, "PartyMemberFrame" .. i .. "HealthBarText")
        table.insert(names, "PartyMemberFrame" .. i .. "ManaBarText")
        table.insert(names, "PartyMemberFrame" .. i .. "Name")
    end

    for i = 1, table.getn(names) do self:RememberObject(names[i]) end
end

function M:RestoreObject(name, geometryOnly)
    if not self.original then return false end
    local snap = self.original[name]
    if not snap or snap == false then return false end
    local obj = snap.object or getglobal(name)
    if not obj then return false end

    if snap.width and obj.SetWidth then obj:SetWidth(snap.width) end
    if snap.height and obj.SetHeight then obj:SetHeight(snap.height) end
    if snap.point and obj.SetPoint then
        obj:ClearAllPoints()
        obj:SetPoint(unpack(snap.point))
    end

    if not geometryOnly then
        -- Restore nil too. PlayerStatusTexture is deliberately cleared by the
        -- glow option, and a snapshot whose original texture was nil must be able
        -- to clear a texture ECO added later.
        if obj.SetTexture and snap.hasTexture then obj:SetTexture(snap.texture) end
        if obj.SetTexCoord and snap.texcoord and table.getn(snap.texcoord) > 0 then
            obj:SetTexCoord(unpack(snap.texcoord))
        end
        if obj.SetVertexColor and snap.vertex and table.getn(snap.vertex) >= 3 then
            obj:SetVertexColor(unpack(snap.vertex))
        end
        if obj.SetFont and snap.font and snap.font[1] then obj:SetFont(unpack(snap.font)) end
        if obj.SetTextColor and snap.textColor then obj:SetTextColor(unpack(snap.textColor)) end
        if obj.SetStatusBarTexture and snap.barTexture then obj:SetStatusBarTexture(snap.barTexture) end
        if obj.SetStatusBarColor and snap.barColor then obj:SetStatusBarColor(unpack(snap.barColor)) end
        if snap.shown ~= nil then
            if snap.shown and obj.Show then obj:Show() elseif obj.Hide then obj:Hide() end
        end
        obj.lockColor = snap.lockColor
        obj.capNumericDisplay = snap.capNumericDisplay
    end
    return true
end

function M:RestorePortrait(entry)
    local portrait = getglobal(entry.portrait)
    if portrait and portrait.SetTexCoord then portrait:SetTexCoord(0, 1, 0, 1) end
    if portrait and type(SetPortraitTexture) == "function" and UnitExists(entry.unit) then
        SetPortraitTexture(portrait, entry.unit)
    end
end

function M:RestoreOriginals()
    self:HideBarBorders()
    if not self.original then return false end
    for name, snap in pairs(self.original) do
        if snap and snap ~= false then self:RestoreObject(name, false) end
    end

    for i = 1, table.getn(FRAMES) do self:RestorePortrait(FRAMES[i]) end
    for i = 1, PARTY do self:RestorePortrait(self:PartyEntry(i)) end
    return true
end

-- Restore one takeover switch immediately. The first port only stopped future
-- styling, so turning Pet/Target/etc. off left whatever ECO had already changed
-- sitting on Blizzard's frame until a reload.
function M:RestoreEntry(entry)
    if not entry then return false end
    local names = { entry.frame, entry.health, entry.power, entry.name, entry.portrait }

    if entry.id == "player" then
        names = { "PlayerFrame", "PlayerFrameTexture", "PlayerFrameBackground",
            "PlayerFrameHealthBar", "PlayerFrameManaBar", "PlayerFrameHealthBarText",
            "PlayerFrameManaBarText", "PlayerName", "PlayerPortrait", "PlayerStatusTexture" }
    elseif entry.id == "target" then
        names = { "TargetFrame", "TargetFrameTexture", "TargetFrameBackground",
            "TargetFrameHealthBar", "TargetFrameManaBar", "TargetFrameNameBackground",
            "TargetDeadText", "TargetFrameTextureFrameName", "TargetPortrait" }
    elseif entry.id == "targettarget" then
        names = { "TargetofTargetFrame", "TargetofTargetTexture",
            "TargetofTargetPortrait", "TargetofTargetHealthBar",
            "TargetofTargetManaBar", "TargetofTargetName" }
    elseif entry.id == "pet" then
        names = { "PetFrame", "PetFrameTexture", "PetPortrait",
            "PetAttackModeTexture", "PetFrameHealthBar", "PetFrameManaBar",
            "PetFrameHealthBarText", "PetFrameManaBarText", "PetName",
            "PetFrameHappiness" }
    elseif string.find(entry.id or "", "^party") then
        local n = string.gsub(entry.id, "party", "")
        names = { "PartyMemberFrame" .. n, "PartyMemberFrame" .. n .. "Texture",
            "PartyMemberFrame" .. n .. "Portrait", "PartyMemberFrame" .. n .. "HealthBar",
            "PartyMemberFrame" .. n .. "ManaBar", "PartyMemberFrame" .. n .. "HealthBarText",
            "PartyMemberFrame" .. n .. "ManaBarText", "PartyMemberFrame" .. n .. "Name" }
    end

    for i = 1, table.getn(names) do self:RestoreObject(names[i], false) end
    self:HideBarBorder(getglobal(entry.health))
    self:HideBarBorder(getglobal(entry.power))
    self:RestorePortrait(entry)
    return true
end

function M:StylePortrait(entry)
    local portrait = getglobal(entry.portrait)
    if not portrait or not portrait.SetTexture then return false end
    local cfg = self:Config()

    if not cfg.classPortrait or not UnitExists(entry.unit) or not UnitIsPlayer(entry.unit) then
        self:RestorePortrait(entry)
        return false
    end

    local _, class = UnitClass(entry.unit)
    local coords = class and classPortraitCoords(class)
    if not coords then return false end

    portrait:SetTexture(CLIENT_PORTRAIT_ART)
    portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

local function targetSuffix(classification)
    if classification == "worldboss" or classification == "elite" then return "-Elite" end
    if classification == "rareelite" then return "-Rare-Elite" end
    if classification == "rare" then return "-Rare" end
    return ""
end

function M:UFIFramePrefix()
    if self:Config().compact then return "compactUI" end
    return "UI"
end

function M:StyleFrameArt(entry)
    local cfg = self:Config()
    local shade = self:DarkShade()
    local art

    if entry.id == "player" then
        art = getglobal("PlayerFrameTexture")
        if art and art.SetTexture then
            if legacyAssetsInstalled() then
                art:SetTexture(UFI_ROOT .. "Textures\\" .. self:UFIFramePrefix() .. "-TargetingFrame")
            elseif cfg.compact then
                -- A genuine compact stock-client fallback. The old repair kept
                -- UI-TargetingFrame here, so only the bars moved under a full-size
                -- frame texture and Compact looked unchanged/broken.
                art:SetTexture("Interface\\TargetingFrame\\UI-SmallTargetingFrame")
            else
                art:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
            end
            art:SetVertexColor(shade, shade, shade)
        end
        return true
    end

    if entry.id == "target" then
        art = getglobal("TargetFrameTexture")
        if art and art.SetTexture then
            local classification = type(UnitClassification) == "function"
                    and UnitClassification("target") or nil
            local suffix = targetSuffix(classification)
            if legacyAssetsInstalled() then
                art:SetTexture(UFI_ROOT .. "Textures\\" .. self:UFIFramePrefix()
                        .. "-TargetingFrame" .. suffix)
            elseif cfg.compact then
                art:SetTexture("Interface\\TargetingFrame\\UI-SmallTargetingFrame")
            else
                art:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame" .. suffix)
            end
            art:SetVertexColor(shade, shade, shade)
        end
        return true
    end

    -- UFI tints the smaller Blizzard frames rather than replacing their art.
    for _, suffix in ipairs({ "Texture", "TextureFrameTexture" }) do
        art = getglobal(entry.frame .. suffix)
        if art and art.SetVertexColor then art:SetVertexColor(shade, shade, shade) end
    end
    return true
end

function M:StylePlayerGeometry()
    if not self:Owns(FRAMES[1]) then return false end
    local cfg = self:Config()
    local frame = getglobal("PlayerFrame")
    local background = getglobal("PlayerFrameBackground")
    local health = getglobal("PlayerFrameHealthBar")
    local power = getglobal("PlayerFrameManaBar")
    if not frame or not health or not power then return false end

    health.lockColor = true
    health.capNumericDisplay = true
    health:SetWidth(119)
    health:ClearAllPoints()
    power:ClearAllPoints()

    if cfg.compact then
        if background then
            background:ClearAllPoints()
            background:SetPoint("TOPLEFT", frame, "TOPLEFT", 106, -24)
            background:SetHeight(30)
        end
        health:SetHeight(20)
        health:SetPoint("TOPLEFT", frame, "TOPLEFT", 106, -22)
        power:SetPoint("TOPLEFT", frame, "TOPLEFT", 106, -42)
    else
        if background then
            background:ClearAllPoints()
            background:SetPoint("TOPLEFT", frame, "TOPLEFT", 106, -24)
            background:SetHeight(41)
        end
        health:SetHeight(29)
        health:SetPoint("TOPLEFT", frame, "TOPLEFT", 106, -22)
        power:SetPoint("TOPLEFT", frame, "TOPLEFT", 106, -51)
    end
    return true
end

function M:StyleTargetGeometry()
    if not self:Owns(FRAMES[2]) then return false end
    local cfg = self:Config()
    local frame = getglobal("TargetFrame")
    local background = getglobal("TargetFrameBackground")
    local health = getglobal("TargetFrameHealthBar")
    local power = getglobal("TargetFrameManaBar")
    local plate = getglobal("TargetFrameNameBackground")
    local dead = getglobal("TargetDeadText")
    if not frame or not health or not power then return false end

    if plate and plate.Hide then plate:Hide() end
    health:SetWidth(119)
    health.lockColor = true
    health:ClearAllPoints()
    power:ClearAllPoints()

    if cfg.compact then
        if background then background:SetHeight(30) end
        health:SetHeight(20)
        health:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -22)
        power:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -106, -42)
        if dead then
            dead:ClearAllPoints()
            dead:SetPoint("CENTER", frame, "CENTER", -50, 6)
        end
    else
        if background then background:SetHeight(41) end
        local classification = type(UnitClassification) == "function"
                and UnitClassification("target") or nil
        if classification == "minus" then
            health:SetHeight(12)
            health:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -41)
            if dead then
                dead:ClearAllPoints()
                dead:SetPoint("CENTER", frame, "CENTER", -50, 4)
            end
        else
            health:SetHeight(29)
            health:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -22)
            if dead then
                dead:ClearAllPoints()
                dead:SetPoint("CENTER", frame, "CENTER", -50, 6)
            end
        end
        power:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -51)
    end
    return true
end

-- Compatibility name from the first ECO port. Compact mode is a player *and*
-- target layout in UFI, so the wrapper now applies both halves.
function M:StyleCompact()
    local a = self:StylePlayerGeometry()
    local b = self:StyleTargetGeometry()
    return a or b
end

function M:StyleTargetTargetGeometry()
    if not self:Owns(FRAMES[3]) then return false end
    local portrait = getglobal("TargetofTargetPortrait")
    local frame = getglobal("TargetofTargetFrame")
    if portrait and frame then
        portrait:ClearAllPoints()
        portrait:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -53, 5)
    end
    return true
end

-- Original UFI mirrored/slim pet geometry, including the pieces the first ECO
-- port omitted (portrait, attack indicator, bar widths and name position).
function M:StylePetGeometry()
    if not self:Owns(FRAMES[4]) then return false end
    local cfg = self:Config()
    local names = {
        "PetFrameTexture", "PetPortrait", "PetAttackModeTexture",
        "PetFrameHealthBar", "PetFrameHealthBarText", "PetFrameManaBar",
        "PetFrameManaBarText", "PetName", "PetFrameHappiness",
    }

    if not cfg.improvedPet then
        -- The first repair pass restored geometry only, which left the mirrored
        -- target-of-target texture and flipped texcoords behind when this toggle
        -- was switched off. Restore the pet art/happiness completely; restore
        -- geometry for bars/text/name so StyleFrame can immediately re-apply
        -- ECO's selected media afterwards.
        self:RestoreObject("PetFrameTexture", false)
        self:RestoreObject("PetFrameHappiness", false)
        for i = 2, table.getn(names) - 1 do self:RestoreObject(names[i], true) end
        local happy = getglobal("PetFrameHappiness")
        if happy and happy.Show then happy:Show() end
        return false
    end

    local art = getglobal("PetFrameTexture")
    local frame = getglobal("PetFrame")
    local player = getglobal("PlayerFrame")
    local portrait = getglobal("PetPortrait")
    local attack = getglobal("PetAttackModeTexture")
    local health = getglobal("PetFrameHealthBar")
    local healthText = getglobal("PetFrameHealthBarText")
    local power = getglobal("PetFrameManaBar")
    local powerText = getglobal("PetFrameManaBarText")
    local name = getglobal("PetName")
    local happy = getglobal("PetFrameHappiness")

    if art then
        art:SetTexture("Interface\\TargetingFrame\\UI-TargetofTargetFrame")
        art:SetTexCoord(1, 0, 0, 1)
        art:ClearAllPoints()
        art:SetPoint("BOTTOMRIGHT", player or frame, "BOTTOMRIGHT", -104, -28)
    end
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -86, 8)
    end
    if attack then
        attack:ClearAllPoints()
        attack:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -46, -22)
    end
    if health then
        health:ClearAllPoints(); health:SetWidth(45)
        health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -125, 27)
    end
    if healthText then
        healthText:ClearAllPoints()
        healthText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -125, 27)
    end
    if power then
        power:ClearAllPoints(); power:SetWidth(45)
        power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -125, 18)
    end
    if powerText then
        powerText:ClearAllPoints()
        powerText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -125, 17)
    end
    if name then
        name:ClearAllPoints()
        name:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -125, 6)
    end
    if happy and happy.Hide then happy:Hide() end
    return true
end

function M:StyleGlow()
    if not self:Owns(FRAMES[1]) then
        self:RestoreObject("PlayerStatusTexture", false)
        return false
    end
    local player = getglobal("PlayerStatusTexture")
    if not player or not player.SetTexture then return false end
    if self:Config().statusGlow then
        if legacyAssetsInstalled() then
            player:SetTexture(UFI_ROOT .. "Textures\\UI-Player-Status")
        else
            player:SetTexture("Interface\\CharacterFrame\\UI-Player-Status")
        end
    else
        player:SetTexture(nil)
    end
    -- UFI never disables PetAttackModeTexture with the player glow option; the
    -- first ECO port did, which removed the pet's attack-state feedback.
    return true
end

local AURA_SECTIONS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
                        "TOP", "BOTTOM", "LEFT", "RIGHT" }

function M:SkinAura(frame, offset, r, g, b)
    if not legacyAssetsInstalled() or not frame or not frame.CreateTexture then return false end
    if not frame.ecoUfiBorder then
        local t = {}
        offset = offset or 0
        for i = 1, table.getn(AURA_SECTIONS) do
            local section = AURA_SECTIONS[i]
            local tex = frame:CreateTexture(nil, "OVERLAY")
            tex:SetTexture(UFI_ROOT .. "skin\\texture\\border-" .. section .. ".tga")
            t[section] = tex
        end
        t.TOPLEFT:SetWidth(8); t.TOPLEFT:SetHeight(8)
        t.TOPLEFT:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 4 + offset, -4 - offset)
        t.TOPRIGHT:SetWidth(8); t.TOPRIGHT:SetHeight(8)
        t.TOPRIGHT:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", -4 - offset, -4 - offset)
        t.BOTTOMLEFT:SetWidth(8); t.BOTTOMLEFT:SetHeight(8)
        t.BOTTOMLEFT:SetPoint("TOPRIGHT", frame, "BOTTOMLEFT", 4 + offset, 4 + offset)
        t.BOTTOMRIGHT:SetWidth(8); t.BOTTOMRIGHT:SetHeight(8)
        t.BOTTOMRIGHT:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT", -4 - offset, 4 + offset)
        t.TOP:SetHeight(8); t.TOP:SetPoint("TOPLEFT", t.TOPLEFT, "TOPRIGHT", 0, 0)
        t.TOP:SetPoint("TOPRIGHT", t.TOPRIGHT, "TOPLEFT", 0, 0)
        t.BOTTOM:SetHeight(8); t.BOTTOM:SetPoint("BOTTOMLEFT", t.BOTTOMLEFT, "BOTTOMRIGHT", 0, 0)
        t.BOTTOM:SetPoint("BOTTOMRIGHT", t.BOTTOMRIGHT, "BOTTOMLEFT", 0, 0)
        t.LEFT:SetWidth(8); t.LEFT:SetPoint("TOPLEFT", t.TOPLEFT, "BOTTOMLEFT", 0, 0)
        t.LEFT:SetPoint("BOTTOMLEFT", t.BOTTOMLEFT, "TOPLEFT", 0, 0)
        t.RIGHT:SetWidth(8); t.RIGHT:SetPoint("TOPRIGHT", t.TOPRIGHT, "BOTTOMRIGHT", 0, 0)
        t.RIGHT:SetPoint("BOTTOMRIGHT", t.BOTTOMRIGHT, "TOPRIGHT", 0, 0)
        frame.ecoUfiBorder = t
    end
    for _, tex in pairs(frame.ecoUfiBorder) do
        tex:SetVertexColor(r or 1, g or 1, b or 1, 1)
        if tex.Show then tex:Show() end
    end
    return true
end

function M:HideAuraSkins()
    for i = 1, 5 do
        local frame = getglobal("TargetFrameBuff" .. i)
        if frame and frame.ecoUfiBorder then
            for _, tex in pairs(frame.ecoUfiBorder) do if tex.Hide then tex:Hide() end end
        end
    end
    for i = 1, 4 do
        local frame = getglobal("TargetofTargetFrameDebuff" .. i)
        if frame and frame.ecoUfiBorder then
            for _, tex in pairs(frame.ecoUfiBorder) do if tex.Hide then tex:Hide() end end
        end
    end
end

function M:StyleTargetAuras()
    if not self:Owns(FRAMES[2]) or not legacyAssetsInstalled() then
        self:HideAuraSkins()
        return false
    end
    local shade = self:DarkShade()
    for i = 1, 5 do self:SkinAura(getglobal("TargetFrameBuff" .. i), 1, shade, shade, shade) end
    for i = 1, 4 do self:SkinAura(getglobal("TargetofTargetFrameDebuff" .. i), -1, 1, 0, 0) end
    return true
end

function M:StyleFrame(entry)
    if not self:Owns(entry) then return false end
    if not getglobal(entry.frame) then return false end

    local cfg = self:Config()
    local color = self:UnitColor(entry.unit)

    --[[ The pet's numbers two points smaller, which is the original's
         proportion: the pet bar is a third the height of the player's and text
         set at the same size overhangs it. ]]--
    local drop = 0
    if entry.id == "pet" then drop = 2 end

    self:StyleBar(getglobal(entry.health), cfg.healthSize - drop,
            cfg.healthX, cfg.healthY, color)

    --[[ The power bar keeps the client's colour. Mana is blue, rage is red and
         energy is yellow, and those are not preferences -- they are what the
         numbers mean. Only its font and position are ours. ]]--
    self:StyleBar(getglobal(entry.power), cfg.powerSize - drop,
            cfg.powerX, cfg.powerY, nil)

    local name = getglobal(entry.name)

    if name then
        local outline
        local look = OB.Look("unitframes")
        if cfg.nameOutline or look.fontOutline then outline = "OUTLINE" end

        --[[ The pet and target-of-target names a point smaller, which is the
             original's proportion: those frames are smaller and a name set at
             the player's size overhangs them. ]]--
        local size = cfg.nameSize
        if entry.id == "pet" or entry.id == "targettarget" then
            size = size - 1
        end

        name:SetFont(OB.FontPath("unitframes"), self:TextSize(size), outline)

        --[[ **Hung off the top edge of the health bar, not centred on the
             frame.**

             The original's anchor, and it is not a detail: a name centred on
             the frame lands in the middle of the portrait. Anchoring to the bar
             also keeps the player and target names level with each other for
             free, because their bars are the same size at the same height.

             Set every pass rather than only when the sliders are off zero, for
             the same reason the text offsets are -- otherwise the name never
             comes back when the slider does. ]]--
        if name.SetPoint then
            local bar = getglobal(entry.health)

            name:ClearAllPoints()

            if entry.id == "pet" and cfg.improvedPet then
                -- UFI gives the slim pet its own fixed baseline rather than the
                -- player/target name anchor. Keep ECO's nudge sliders additive
                -- so the port remains configurable without losing that geometry.
                name:SetPoint("BOTTOMRIGHT", getglobal(entry.frame), "BOTTOMRIGHT",
                        -125 + cfg.nameX, 6 + cfg.nameY)
            elseif bar then
                --[[ **The target's X is mirrored**, because the target frame's
                     art is. Without it, nudging both names right moves them
                     apart rather than together. ]]--
                local x = cfg.nameX
                if entry.id == "target" then x = -x end

                name:SetPoint("CENTER", bar, "TOP", x, cfg.nameY + 5)
            else
                name:SetPoint("CENTER", getglobal(entry.frame), "CENTER",
                        cfg.nameX, cfg.nameY)
            end
        end
    end

    self:StylePortrait(entry)
    self:StyleFrameArt(entry)

    return true
end

--[[ **Writing the numbers on.**

     Separate from the styling because it happens on a different clock: a frame
     is styled when a setting changes and re-lettered every time somebody takes
     damage. Doing both together would re-apply a font sixty times a second for
     no reason.

     **One writer, which is the whole point.** This goes through the client's own
     entry point rather than setting the strings itself, so the event path and
     the client's own `OnValueChanged` path end up in the same code. The port had
     two writers and they fought; the one that ran last won, and which that was
     depended on the order the events happened to arrive. ]]--
function M:UpdateText(entry)
    if not self:Owns(entry) then return false end

    for _, name in ipairs({ entry.health, entry.power }) do
        local bar = getglobal(name)
        if bar then TextStatusBar_UpdateTextString(bar) end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- moving the frames
-- ---------------------------------------------------------------------------

--[[ **The original's Unlock button, as a mode rather than a lock.**

     On, drag, off -- the same shape the action bars use, and for the same
     reason: a permanently draggable player frame is one you move by accident
     every time you right-click your own buffs.

     **Only the player and target frames**, which is what the original offers.
     The pet and target-of-target frames are anchored to those two by the client
     and follow them; the party frames are Blizzard's own managed layout and
     moving one individually is a different feature. ]]--
local MOVABLE = { "PlayerFrame", "TargetFrame" }

function M:DragMode()
    return self.dragging and true or false
end

function M:SetDragMode(on)
    if on and not OB.ModuleEnabled("unitframes") then
        Say("switch the Unit Frames module on first.")
        return false
    end

    self.dragging = on and true or nil

    for i = 1, table.getn(MOVABLE) do
        self:MakeMovable(getglobal(MOVABLE[i]))
    end

    if self.dragging then
        Say("drag mode on. Move the player and target frames, "
                .. "then switch it off. '/eqob frames reset' puts them back.")
    else
        Say("drag mode off.")
    end

    return true
end

--[[ One frame, made movable or not.

     **The border art is tinted green while the mode is on**, which is the
     original's own signal and is worth keeping: these frames are always on
     screen, so "can I drag this right now" is not otherwise answerable without
     trying it.

     `SetUserPlaced` is what stops the client putting the frame back where its
     XML says on the next load. Without it the drag works and is forgotten, which
     is the same as not working. ]]--
function M:MakeMovable(frame)
    if not frame or not frame.SetMovable then return false end

    local art = getglobal((frame:GetName() or "") .. "Texture")
            or getglobal((frame:GetName() or "") .. "TextureFrameTexture")

    if not self.dragging then
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:SetMovable(false)

        --[[ Back to whatever dark mode says, not to white -- restoring white
             here would undo the tint every time the mode was switched off. ]]--
        self:StyleFrameArt({ frame = frame:GetName() })
        return true
    end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")

    if art and art.SetVertexColor then art:SetVertexColor(0, 1, 0) end

    frame:SetScript("OnDragStart", function() this:StartMoving() end)

    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()

        if this.SetUserPlaced then this:SetUserPlaced(true) end
        EquadisClassicOverhaul.modules.unitframes:StorePosition(this)
    end)

    return true
end

--[[ Where a frame ended up, as an offset from the centre of the screen.

     **From the centre, not from a corner**, which is the rule the meters and the
     action bars already follow: a position measured from an edge is a different
     place on a different resolution, and this addon has been bitten by that
     before. The centre is the one point every screen shares. ]]--
function M:StorePosition(frame)
    if not frame or not frame.GetLeft or not frame:GetLeft() then return false end

    local cfg = self:Config()
    cfg.positions = cfg.positions or {}

    local scale = frame:GetScale() or 1
    if scale <= 0 then scale = 1 end

    cfg.positions[frame:GetName() or "?"] = {
        x = OB.Round((frame:GetLeft() + (frame:GetWidth() / 2))
                - ((GetScreenWidth() / 2) / scale)),
        y = OB.Round((frame:GetBottom() + (frame:GetHeight() / 2))
                - ((GetScreenHeight() / 2) / scale)),
    }

    return true
end

--[[ A stored position put back on, or nothing at all if there is none -- in
     which case the client's own anchor stands, which is where the frame has
     always been. ]]--
function M:PlaceFrames()
    local cfg = self:Config()
    if not cfg.positions then return false end

    for i = 1, table.getn(MOVABLE) do
        local frame = getglobal(MOVABLE[i])
        local saved = cfg.positions[MOVABLE[i]]

        if frame and saved and frame.SetPoint then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
            if frame.SetUserPlaced then frame:SetUserPlaced(true) end
        end
    end

    return true
end

--[[ Forgotten rather than moved back, so the client's own anchor takes over
     again -- which is a place that exists on every resolution, unlike any
     coordinate this addon could pick. ]]--
function M:ResetPositions()
    self:Config().positions = {}

    if type(OB.RequireReload) == "function" then
        OB.RequireReload("unit frame positions were reset")
    else
        Say("frame positions forgotten. Reload to put them back.")
    end

    return true
end

-- ---------------------------------------------------------------------------
-- the party, which is four of the same thing
-- ---------------------------------------------------------------------------

function M:PartyEntry(i)
    return {
        id = "party" .. i,
        setting = "replaceParty",
        frame = "PartyMemberFrame" .. i,
        health = "PartyMemberFrame" .. i .. "HealthBar",
        power = "PartyMemberFrame" .. i .. "ManaBar",
        name = "PartyMemberFrame" .. i .. "Name",
        portrait = "PartyMemberFrame" .. i .. "Portrait",
        unit = "party" .. i,
    }
end

-- ---------------------------------------------------------------------------
-- binding
-- ---------------------------------------------------------------------------

--[[ **Re-target somebody who vanished.**

     Feign Death, Vanish and Invisibility all clear your target, and the target
     you had is almost always the target you still want.

     `TargetByName` is noisy about failing -- it plays a sound and writes an
     error -- so both are silenced across the call and put straight back. That is
     the original's trick, from SHIRSIG's Retarget, and it is the only way: there
     is no quiet form of the call.

     **Only players.** A mob that vanished is a mob that died, and re-targeting a
     corpse is not a service. ]]--
function M:RetargetFeignOrHostile()
    if self:IsFeigning("target") then return true end
    return type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") and true or false
end

function M:RetargetStep()
    if not self:Config().retarget then
        self.retargetUnit, self.retargetDead, self.retargetLost = nil, nil, nil
        return false
    end

    local target = UnitName("target")
    if target and UnitIsPlayer("target") then
        self.retargetUnit = target
        self.retargetDead = type(UnitIsDead) == "function" and UnitIsDead("target") and true or false
        self.retargetLost = false
        return false
    end

    if not self.retargetUnit or type(TargetByName) ~= "function" then return false end

    local oldSound, oldErrors = PlaySound, UIErrorsFrame_OnEvent
    local quiet = function() end
    PlaySound, UIErrorsFrame_OnEvent = quiet, quiet
    TargetByName(self.retargetUnit, true)
    PlaySound, UIErrorsFrame_OnEvent = oldSound, oldErrors

    if UnitExists("target") then
        local nowDead = type(UnitIsDead) == "function" and UnitIsDead("target") and true or false
        if not (self.retargetLost or (not self.retargetDead and nowDead
                and self:RetargetFeignOrHostile())) then
            if type(ClearTarget) == "function" then ClearTarget() end
            self.retargetUnit, self.retargetLost = nil, false
            return false
        end
        return true
    end

    -- Failed once means the unit genuinely disappeared (Vanish/Feign/out of
    -- visibility). From now on, the first successful reacquisition is kept.
    self.retargetLost = true
    return false
end

-- Compatibility entry points from the first ECO port. They feed the repaired
-- SHIRSIG state machine rather than maintaining a second retarget implementation.
function M:NoteTarget()
    if UnitExists("target") and UnitIsPlayer("target") then
        self.lastTarget = UnitName("target")
        self.retargetUnit = self.lastTarget
        self.retargetDead = type(UnitIsDead) == "function" and UnitIsDead("target") and true or false
        self.retargetLost = false
        return true
    end
    return false
end

function M:Retarget()
    local result = self:RetargetStep()
    self.lastTarget = self.retargetUnit
    return result
end

function M:Apply()
    if not OB.ModuleEnabled("unitframes") then return end
    self:RememberOriginals()

    -- A per-frame switch means "give this frame back", not merely "stop touching
    -- it from now on". Undo a previous takeover before styling the frames still
    -- owned by ECO.
    for i = 1, table.getn(FRAMES) do
        if not self:Owns(FRAMES[i]) then self:RestoreEntry(FRAMES[i]) end
    end
    for i = 1, PARTY do
        local entry = self:PartyEntry(i)
        if not self:Owns(entry) then self:RestoreEntry(entry) end
    end

    -- Geometry first, styling second. This makes toggles reversible without the
    -- pet/compact restore pass wiping ECO's selected bar texture afterwards.
    self:StylePlayerGeometry()
    self:StyleTargetGeometry()
    self:StyleTargetTargetGeometry()
    self:StylePetGeometry()

    for i = 1, table.getn(FRAMES) do
        self:StyleFrame(FRAMES[i])
        self:UpdateText(FRAMES[i])
    end
    for i = 1, PARTY do
        local entry = self:PartyEntry(i)
        self:StyleFrame(entry)
        self:UpdateText(entry)
    end

    self:StyleGlow()
    self:StyleTargetAuras()

    local player = getglobal("PlayerFrameHealthBar")
    if player then self:ColorUpdate(player) end
end

function M:OnEvent()
    if event == "PLAYER_FLAGS_CHANGED" and (not arg1 or arg1 == "player") then
        self.nextPVPTimerRefresh = nil
        self:UpdatePVPTimer(true)
    elseif event == "UNIT_FACTION" and arg1 == "player" then
        self.nextPVPTimerRefresh = nil
        self:UpdatePVPTimer(true)
    end

    -- Record real hunter values only while alive. UNIT_AURA is included so the
    -- first frame drawn after Feign can immediately read the saved value.
    if (event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_AURA") and arg1 then
        self:NoteFeign(arg1)
    end

    if event == "PLAYER_TARGET_CHANGED" then
        self:MobTargetChanged()
    elseif event == "UNIT_COMBAT" and arg1 == "target" then
        -- Damage accumulation changes no pixels by itself; UNIT_HEALTH follows
        -- with the percentage delta. Avoid restyling every frame for every hit.
        self:MobCombat(arg4)
        return
    elseif event == "UNIT_HEALTH" and arg1 == "target" then
        self:MobHealthUpdate()
    end

    self:Apply()
end

-- UFI used per-frame OnUpdate for class portraits and SHIRSIG retarget. ECO has
-- one shared ticker, so both live here instead of installing competing globals.
function M:OnUpdate(now)
    self:RetargetStep()

    -- The PvP grace timer only changes once per second, but checking the client
    -- value four times a second makes the first/last displayed second feel
    -- immediate without doing string work every frame.
    if not self.nextPVPTimerRefresh or now >= self.nextPVPTimerRefresh then
        self.nextPVPTimerRefresh = now + 0.25
        self:UpdatePVPTimer(false)
    end

    if self:Config().classPortrait then
        -- Target-of-target changes have no useful event in 1.12. A light 10 Hz
        -- refresh is enough to beat Blizzard repainting the portrait without
        -- paying UFI's seven portrait writes every rendered frame.
        if not self.nextPortraitRefresh or now >= self.nextPortraitRefresh then
            self.nextPortraitRefresh = now + 0.10
            -- UFI applies class portraits to player, target and target-target,
            -- not the pet. (Pets are not players and restoring their portrait
            -- every tick would fight the pet frame's own portrait updates.)
            for i = 1, 3 do
                if self:Owns(FRAMES[i]) then self:StylePortrait(FRAMES[i]) end
            end
            for i = 1, PARTY do
                local entry = self:PartyEntry(i)
                if self:Owns(entry) then self:StylePortrait(entry) end
            end
        end
    end
end

function M:OnBind()
    self:RememberOriginals()
    self:InstallTextHooks()
    self:PlaceFrames()
    self:MobTargetChanged()
    self:Apply()
    self:UpdatePVPTimer(true)
end

function M:OnUnbind()
    self.retargetUnit, self.retargetDead, self.retargetLost = nil, nil, nil
    self.lastTarget = nil
    self.mobCurrent = nil
    self.nextPortraitRefresh = nil
    self.nextPVPTimerRefresh = nil
    self:HidePVPTimer()
    self:HideAuraSkins()
    self:HideBarBorders()
    self:RestoreOriginals()
end

function M:OnStyle()
    self:Apply()
end

function M:OnDraw() end
