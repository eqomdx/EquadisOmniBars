--[[ Equadis' Classic Overhaul :: auras

  **What is on a unit that is not your target.**

  The same hole as casts and the same shape of answer. 1.12's `UnitDebuff` needs
  a unit token, a nameplate has none, and so an addon that wants to show "does
  this mob still have my Rend on it" has to keep the book itself.

  ShaguPlates' `libdebuff` is the one this follows, and the technique is the same
  as the cast library's: **keyed by unit name**, fed from two sources of very
  different quality.

  **The target is exact.** `UnitDebuff("target", i)` gives the texture and the
  stack count directly, and a target change or an aura change re-reads all of
  them. Nothing is inferred.

  **Everything else comes out of the combat log**, which announces "X is
  afflicted by Y" and stops. No icon, no duration, no stack count -- a name and
  nothing else.

  So the icon is *learned*: the first time a spell is seen on your target, its
  texture is recorded against its name, and from then on any unit afflicted by
  that spell can be drawn with it. Which means the icons fill in as you fight,
  and a spell nobody has ever had on a target is known by name and not by
  picture.

  **Durations are not tracked at all, and that is deliberate.** 1.12's
  `UnitDebuff` does not return one -- it gives a texture and a count and stops --
  so a duration can only come from a shipped table of every spell in the game.
  ShaguPlates ships one. The useful question on a nameplate is *whether* your
  debuff is on the thing, not how many seconds are left, and answering the first
  honestly beats answering the second from a table that has to be maintained.
]]--

local OB = EquadisClassicOverhaul

-- ---------------------------------------------------------------------------
-- what is on whom
-- ---------------------------------------------------------------------------

--[[ Unit name -> spell name -> when it was last seen. Not saved: an aura lasts
     under a minute and nothing about it survives a reload worth keeping. ]]--
OB.auras = {}

--[[ **How long to believe a debuff is still there.**

     Nothing tells us when one falls off a unit we cannot see. The combat log
     announces the fade sometimes and not always -- a mob that dies takes its
     debuffs with it and says nothing -- so an entry that has not been renewed is
     dropped after this long.

     Thirty seconds is longer than most things worth showing on a nameplate and
     short enough that a stale icon is not still there when you come back. It is
     a guess, and it is the only guess in this file. ]]--
local STALE = 30

function OB.AddAura(unit, spell, texture)
    if not unit or not spell then return false end

    OB.auras[unit] = OB.auras[unit] or {}
    OB.auras[unit][spell] = GetTime()

    --[[ The icon, learned once and kept for every unit afterwards. This is what
         turns a combat log line -- which carries no picture -- into something
         that can be drawn. ]]--
    if texture and OB.auraIcons then OB.auraIcons[spell] = texture end

    return true
end

function OB.RemoveAura(unit, spell)
    if not unit or not spell then return end
    if not OB.auras[unit] then return end

    OB.auras[unit][spell] = nil
end

function OB.ForgetAuras(unit)
    if unit then OB.auras[unit] = nil end
end

--[[ What is on a unit, newest first, with icons where they are known.

     **Expiry happens here** rather than on a timer, exactly as the cast library
     does it: asking is the only moment it matters, and there is no sweep to
     schedule and nothing to leak. ]]--
function OB.AuraList(unit, limit)
    if not unit or not OB.auras[unit] then return {} end

    local now = GetTime()
    local out = {}

    for spell, seen in pairs(OB.auras[unit]) do
        if now - seen > STALE then
            OB.auras[unit][spell] = nil
        else
            table.insert(out, {
                spell = spell,
                seen = seen,
                icon = OB.auraIcons and OB.auraIcons[spell],
            })
        end
    end

    --[[ Newest first, which is the order somebody applied them in and therefore
         the order they think of them in. A stable order matters more than which
         one it is: icons that reshuffle every frame are unreadable. ]]--
    table.sort(out, function(a, b) return a.seen > b.seen end)

    if limit and table.getn(out) > limit then
        for i = table.getn(out), limit + 1, -1 do
            table.remove(out, i)
        end
    end

    return out
end

-- ---------------------------------------------------------------------------
-- watching for them
-- ---------------------------------------------------------------------------

--[[ Not a module and not a tab, for the reason `modules/casts.lua` gives: no
     settings, nothing to draw, and a source of answers rather than a subsystem. ]]--
local M = { }
OB.auraWatch = M

--[[ **Reading the target's debuffs, which is the only exact source there is.**

     `UnitDebuff` in 1.12 answers a texture and a stack count and nothing else --
     no name. The name has to come from a tooltip scan, which the addon already
     does for the action bar search, and which is affordable here because this
     runs on a target change rather than on a draw. ]]--
function M:ScanTarget()
    if not UnitExists("target") then return 0 end

    local unit = UnitName("target")
    if not unit then return 0 end

    local found = 0
    local tip = OB.ScanTooltip()

    for i = 1, 16 do
        local texture = UnitDebuff("target", i)
        if not texture then break end

        --[[ The name, out of the tooltip the client fills in for that slot. A
             debuff with no readable name is still recorded by its texture, which
             is enough to draw it even when it cannot be named. ]]--
        local spell

        if type(tip.SetUnitDebuff) == "function"
                and pcall(tip.SetUnitDebuff, tip, "target", i) then
            spell = OB.ScanLine(1)
        end

        if spell and spell ~= "" then
            OB.AddAura(unit, spell, texture)
            found = found + 1
        end
    end

    return found
end

--[[ A debuff landing on somebody who is not your target, which the combat log
     announces and describes in three words.

     Through the client's own sentence rather than by matching English, the same
     rule every parsed line in this addon follows. ]]--
function M:ReadAuraLine(text)
    if not text then return nil end
    if not AURAADDEDOTHERHARMFUL then return nil end

    local unit, spell = OB.ParseLine(text, AURAADDEDOTHERHARMFUL)
    if unit and spell then return unit, spell end

    return nil
end

--[[ And one falling off, which is announced the other way round: the spell is
     named first and the unit second. Getting that backwards files every fade
     under a unit called "Rend". ]]--
function M:ReadFadeLine(text)
    if not text then return nil end
    if not AURAREMOVEDOTHER then return nil end

    local spell, unit = OB.ParseLine(text, AURAREMOVEDOTHER)
    if unit and spell then return unit, spell end

    return nil
end

local EVENTS = {
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_AURA_GONE_OTHER",
    "PLAYER_TARGET_CHANGED",
    "UNIT_AURA",
}

M.frame = CreateFrame("Frame", "EquadisOverhaulAuras", UIParent)

for i = 1, table.getn(EVENTS) do
    M.frame:RegisterEvent(EVENTS[i])
end

M.frame:RegisterEvent("PLAYER_ENTERING_WORLD")

M.frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        OB.auras = {}
        return
    end

    --[[ The exact source: a target change or an aura change on the target
         re-reads all of them, which is both correct and how the icons get
         learned. ]]--
    if event == "PLAYER_TARGET_CHANGED"
            or (event == "UNIT_AURA" and arg1 == "target") then
        M:ScanTarget()
        return
    end

    if event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then
        local unit, spell = M:ReadFadeLine(arg1)
        if unit then OB.RemoveAura(unit, spell) end
        return
    end

    local unit, spell = M:ReadAuraLine(arg1)
    if unit then OB.AddAura(unit, spell) end
end)
