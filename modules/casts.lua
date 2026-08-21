--[[ Equadis' Classic Overhaul :: casts

  **Who is casting what, in a client that will not say.**

  1.12 has no `UnitCastingInfo` and no `UnitChannelInfo`. They arrive in 2.0. So
  every vanilla addon that draws a cast bar for anything other than the player
  has built this layer for itself, and ShaguPlates' `libcast` is the one this
  follows.

  Two halves, and they are not equally good.

  **The player's own casts are exact.** `SPELLCAST_START` hands over the spell
  name and the cast time in milliseconds, from the client, before anything is
  drawn. Nothing here is inferred.

  **Everything else is read out of the combat log**, which announces that a cast
  has begun and says nothing whatever about how long it will take. That number
  has to come from somewhere, and where it comes from is the one real design
  decision in this file.

  ShaguPlates ships a database: every spell in the game with its cast time,
  thousands of lines, one per locale. It works and it is a lot of data to carry
  and keep current.

  **This learns instead.** Every spell the player casts teaches the table its
  exact duration -- for free, from the client, with no guessing -- and mobs cast
  a great many of the same spells that players do. Fireball is Fireball. What is
  not known yet is drawn as a bar with no fill and the spell's name on it, which
  is still the useful half of a cast bar: *what* is being cast matters more than
  how far through it is.

  Keyed by unit **name**, not by unit token, which is what makes it work at all:
  a nameplate has a name and no token, so every plate can have a cast bar rather
  than only the target.
]]--

local OB = EquadisClassicOverhaul

-- ---------------------------------------------------------------------------
-- what is being cast
-- ---------------------------------------------------------------------------

--[[ In flight right now, keyed by caster name. Not saved: a cast lasts three
     seconds and nothing about it survives a reload worth keeping. ]]--
OB.casting = {}

--[[ **How long a spell takes**, learned rather than shipped. Saved, because a
     cast time is a fact about the world that does not change -- the same
     argument the roster and the price table are stored on. ]]--
function OB.CastTime(spell)
    if not spell then return nil end
    return OB.castTimes and OB.castTimes[spell]
end

function OB.LearnCastTime(spell, milliseconds)
    if not spell or not milliseconds or milliseconds <= 0 then return end
    if not OB.castTimes then return end

    --[[ **The longest seen wins**, which is the opposite of the levels rule and
         right for the opposite reason. A cast time shortens with haste and with
         talents and lengthens with nothing, so the largest number seen is the
         base -- and a bar drawn from a hasted duration finishes early on
         somebody who is not hasted, which reads as the spell being interrupted. ]]--
    local known = OB.castTimes[spell]
    if known and known >= milliseconds then return end

    OB.castTimes[spell] = milliseconds
end

--[[ Somebody has started casting.

     `duration` is given for the player, because the client provides it, and nil
     for everybody else, because the combat log does not. A nil duration is not a
     failure -- it is a bar that shows the spell's name and no progress, which is
     the honest drawing of "this is being cast and I do not know for how long". ]]--
function OB.StartCast(name, spell, duration, channel)
    if not name or not spell then return false end

    if duration then OB.LearnCastTime(spell, duration) end

    OB.casting[name] = {
        spell = spell,
        start = GetTime(),
        duration = duration or OB.CastTime(spell),
        channel = channel and true or nil,
    }

    return true
end

function OB.StopCast(name)
    if not name then return end
    OB.casting[name] = nil
end

--[[ **What to draw, or nothing.**

     Returns the spell, how far through it is as a fraction, and whether it is a
     channel. The fraction is nil when the duration is not known -- which the
     caller must handle rather than treat as zero, because a bar sitting at empty
     for three seconds looks like a bug and an unfilled bar with a name on it
     looks like what it is.

     **Expiry happens here rather than on a timer.** A cast that ran out is
     forgotten the next time anybody asks about it, which costs nothing and means
     there is no sweep to schedule and nothing to leak if a caster dies mid-cast
     and never sends another line. ]]--
function OB.CastInfo(name)
    if not name then return nil end

    local cast = OB.casting[name]
    if not cast then return nil end

    local elapsed = GetTime() - cast.start

    --[[ Unknown duration: kept for a few seconds and then dropped, because
         nothing will ever come along to end it. Five is longer than almost any
         vanilla cast and short enough not to linger. ]]--
    local limit = cast.duration and (cast.duration / 1000) or 5

    if elapsed >= limit then
        OB.casting[name] = nil
        return nil
    end

    if not cast.duration then
        return cast.spell, nil, cast.channel
    end

    local fraction = elapsed / (cast.duration / 1000)

    --[[ A channel empties rather than fills. It is the same number read the
         other way round, and getting it backwards is the sort of thing nobody
         notices until they watch a Drain Life. ]]--
    if cast.channel then fraction = 1 - fraction end

    if fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end

    return cast.spell, fraction, cast.channel
end

-- ---------------------------------------------------------------------------
-- watching for them
-- ---------------------------------------------------------------------------

--[[ **Not a module and not a tab.**

     This has no settings and nothing to draw. It is a source of answers that
     nameplates read from and unit frames will -- the same shape as
     `modules/parser.lua`, which is also not a module for the same reason.
     Registering it would put an empty page on the panel and a pointless line on
     the Modules list.

     So it carries its own event frame, which is three lines and owes nothing to
     the registry. ]]--
local M = { }
OB.casts = M

local EVENTS = {
    --[[ The player's own, which are exact. ]]--
    "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED",
    "SPELLCAST_INTERRUPTED", "SPELLCAST_DELAYED",
    "SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_STOP",

    --[[ Everybody else's, which arrive as sentences. The set is ShaguPlates' and
         it is long because 1.12 splits the combat log by who did what to whom,
         and a cast can be announced through any of them. ]]--
    "CHAT_MSG_SPELL_SELF_DAMAGE",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
}

--[[ **Read the caster and the spell out of one line.**

     `SPELLCASTOTHERSTART` is the client's own sentence -- "%s begins to cast
     %s." -- and going through the parser's pattern machinery rather than
     matching English is the same rule every other line in this addon follows:
     whatever the client says is what gets read, in whatever language it says it.

     `SPELLPERFORMOTHERSTART` is the same event for abilities rather than spells,
     and a client that lacks either simply never matches it. ]]--
local STARTS = { "SPELLCASTOTHERSTART", "SPELLPERFORMOTHERSTART" }

function M:ReadCastLine(text)
    if not text then return nil end

    for i = 1, table.getn(STARTS) do
        local sentence = getglobal(STARTS[i])

        if sentence then
            local who, spell = OB.ParseLine(text, sentence)
            if who and spell then return who, spell end
        end
    end

    return nil
end

function M:OnEvent()
    --[[ The player's own casts, where the client hands over the exact
         duration. ]]--
    if event == "SPELLCAST_START" then
        OB.StartCast(UnitName("player"), arg1, arg2)
        return
    end

    if event == "SPELLCAST_CHANNEL_START" then
        --[[ Channels reverse the arguments: the duration comes first. Not a
             mistake in the reading -- it is what the client sends. ]]--
        OB.StartCast(UnitName("player"), arg2, arg1, true)
        return
    end

    if event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED"
            or event == "SPELLCAST_INTERRUPTED"
            or event == "SPELLCAST_CHANNEL_STOP" then
        OB.StopCast(UnitName("player"))
        return
    end

    --[[ A delayed cast is pushed back rather than restarted, which is what
         being hit while casting does. Restarting it would show the bar jumping
         back to the beginning, which is not what happened. ]]--
    if event == "SPELLCAST_DELAYED" then
        local cast = OB.casting[UnitName("player")]
        if cast and arg1 then cast.start = cast.start + (arg1 / 1000) end
        return
    end

    --[[ Everybody else, out of the log. ]]--
    local who, spell = self:ReadCastLine(arg1)
    if who then OB.StartCast(who, spell) end
end

M.frame = CreateFrame("Frame", "EquadisOverhaulCasts", UIParent)

for i = 1, table.getn(EVENTS) do
    M.frame:RegisterEvent(EVENTS[i])
end

--[[ Cleared on entering the world. A cast in flight across a loading screen is
     a cast whose caster is no longer there. ]]--
M.frame:RegisterEvent("PLAYER_ENTERING_WORLD")

M.frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        OB.casting = {}
        return
    end

    M:OnEvent()
end)
