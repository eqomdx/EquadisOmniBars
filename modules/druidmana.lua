--[[ Equadis' OmniBars :: druid secondary mana

  How much mana a druid still has while in bear or cat form.

  Vanilla stops reporting mana the moment you shift: UnitMana starts answering
  about rage or energy instead, and there is no second accessor. So the number
  cannot be read -- it has to be simulated from the moment of the shift onwards.

  The simulation is ported from DruidManaLib-1.0 (Aviana), which Equadis'
  UnitFrames uses through Ace2. It arrives here standalone, because Ace2 is
  ~170KB serving two libraries and this is one of them.

  Two things changed on the way across, both of which mattered:

  The eighteen-slot tooltip scrape ran from an unthrottled OnUpdate in the
  original -- eighteen items loaded and re-read every frame, forever, to answer a
  question that can only change when your gear does. It is driven by inventory
  and max-mana events here.

  Gear mana-per-5 never actually counted, because the accumulator read
  `extra = extra or 0 + n`, which Lua parses as `extra or (0 + n)` -- and `extra`
  starts at 0, which is truthy, so the old value won every time. See ScanGear.

  The estimate only ever runs low. Every mana source it cannot see -- a potion, a
  proc, anything the shifted client does not announce -- is one it under-counts,
  and never one it over-counts. That asymmetry is what makes the near-full snap
  in OnUpdate a correction rather than a guess.
]]--

local OB = EquadisOmniBars

local floor, ceil = math.floor, math.ceil

-- ---------------------------------------------------------------------------
-- text the client only exposes through tooltips
-- ---------------------------------------------------------------------------

--[[ Localised patterns, carried over from the source library. Phase 3 brings
     ShaguDPS's `sanitize`, which builds these from the client's own
     GLOBALSTRINGs and makes the table unnecessary; until then they are typed
     out. An unlisted locale falls back to English and simply reads no gear
     bonus, which costs accuracy rather than correctness. ]]--
local L = {
    equipMp5 = "Equip: Restores (%d+) mana per 5 sec%.",
    plainMp5 = "Mana Regen (%d+) per 5 sec%.",
    spellCost = "(%d+) Mana",
}

local locale = GetLocale()

if locale == "deDE" then
    L.equipMp5 = "Anlegen: Stellt alle 5 Sek%. (%d+) Punkt%(e%) Mana wieder her%."
    L.plainMp5 = "Manaregeneration (%d+) per 5 Sek%."
elseif locale == "zhCN" then
    L.equipMp5 = "装备：每5秒回复(%d+)点法力值。"
    L.plainMp5 = "每5秒恢复(%d+)点法力值。"
    L.spellCost = "(%d+)法力值"
end

local BEAR_ICON = "Interface\\Icons\\Ability_Racial_BearForm"

-- Innervate: regeneration at five times the normal rate, and the five second
-- rule does not hold it back
local INNERVATE = { ["Interface\\Icons\\Spell_Nature_Lightning"] = true }

-- the buff the source library treats as making a shift cost nothing
local FREE_SHIFT = { ["Interface\\Icons\\Inv_Misc_Rune_06"] = true }

-- every point of intellect is worth this much maximum mana
local MANA_PER_INT = 15

-- ---------------------------------------------------------------------------
-- module
-- ---------------------------------------------------------------------------

local M = OB.RegisterModule({
    id = "druidmana",
    name = "Druid Mana",
    slot = "aux",

    --[[ Outranks the range readout, so a druid's spare slot fills with the
         thing only a druid can use and everyone else's fills with the thing
         anyone can. One priority number instead of a class branch in the
         resolver. ]]--
    priority = 20,
    classes = { DRUID = true },

    renders = "bar",
    tickly = true,

    defaults = {
        color = { 0.20, 0.40, 0.90, 1 },
        textMode = "max",
        hideInCaster = true,
    },

    options = {
        { "Bar Colour", "color", "color", true },
        { "Text", "textMode", OB.Enum(
                { "none", "value", "percent", "max" },
                { "None", "Current Only", "Percentage", "Current / Max" }) },
        { "Hide In Caster Form", "hideInCaster", "boolean" },
    },

    --[[ The longest list in the addon, because the estimate is assembled from
         everything the client will still answer once it stops reporting mana. ]]--
    requires = {
        "UnitMana", "UnitManaMax", "UnitPowerType",
        "UnitStat", "GetTalentInfo", "GetSpellTabInfo", "GetSpellTexture",
    },

    events = {
        "PLAYER_ENTERING_WORLD",
        "UNIT_MANA", "UNIT_MAXMANA",
        "UNIT_INVENTORY_CHANGED",
        "UPDATE_SHAPESHIFT_FORMS",
        "PLAYER_AURAS_CHANGED",
        "SPELLCAST_STOP",
    },
})

-- a safe starting point, so a draw that beats the first scan divides by 1
M.cur, M.max = 0, 1
M.gearTick = 0
M.shiftCost = 0

function M:Config()
    return OB.profile.modules.druidmana
end

function M:Shifted()
    return UnitPowerType("player") ~= 0
end

-- ---------------------------------------------------------------------------
-- scanning
--
-- The expensive half, and the half the original ran every frame.
-- ---------------------------------------------------------------------------

--[[ What shifting costs, read off Bear Form's tooltip.

     Found by icon rather than by name because the name is localised and the icon
     is not. The spellbook walk covers tab 4, the class tab, exactly as the
     source library did. ]]--
function M:ScanShiftCost()
    local _, _, offset, count = GetSpellTabInfo(4)
    if not offset or not count then return end

    local tip = OB.ScanTooltip()

    for i = 1, offset + count do
        if GetSpellTexture(i, BOOKTYPE_SPELL) == BEAR_ICON then
            tip:ClearLines()
            -- the numeric book type is the source library's, verbatim
            tip:SetSpell(i, 1)

            local line = OB.ScanLine(2)
            if line then
                local _, _, cost = string.find(line, L.spellCost)
                cost = tonumber(cost)
                if cost and cost > 0 then
                    self.shiftCost = cost
                    return
                end
            end
        end
    end
end

--[[ Mana per five seconds from equipped gear, restated as mana per tick.

     Ticks are two seconds apart, hence the (x * 2) / 5. Rounding up matches the
     source library and keeps the estimate from drifting low over a long fight,
     which is the direction it already errs in. ]]--
function M:ScanGear()
    local tip = OB.ScanTooltip()
    local total = 0

    for slot = 1, 18 do
        tip:ClearLines()
        tip:SetInventoryItem("player", slot)

        for line = 1, tip:NumLines() do
            local text = OB.ScanLine(line)
            if text then
                local _, _, n = string.find(text, L.equipMp5)
                if not n then
                    _, _, n = string.find(text, L.plainMp5)
                end
                -- `total + (tonumber(n) or 0)`, and not the source library's
                -- `total or 0 + tonumber(n)`. See the note at the top of the file.
                if n then total = total + (tonumber(n) or 0) end
            end
        end
    end

    self.gearTick = ceil((total * 2) / 5)
end

function M:Rescan()
    self:ScanShiftCost()
    self:ScanGear()
end

-- ---------------------------------------------------------------------------
-- the estimate
-- ---------------------------------------------------------------------------

--[[ Re-seed from the real API in caster form, or carry the estimate forward in
     any other.

     Intellect can still move while shifted -- a buff falling off, a trinket --
     and each point is worth 15 maximum mana, so the ceiling tracks it rather
     than freezing at whatever it was when you shifted. ]]--
function M:Resync()
    local _, int = UnitStat("player", 4)

    if not self:Shifted() then
        local max = UnitManaMax("player")
        if max and max > 0 then
            self.max = max
            self.cur = UnitMana("player") or 0
            self.int = int
            self.seeded = true
        end
        return
    end

    if not self.int then
        self.int = int
    elseif int and int ~= self.int then
        self.max = self.max + ((int - self.int) * MANA_PER_INT)
        self.int = int
    end

    if self.cur > self.max then self.cur = self.max end
end

--[[ What one tick of regeneration is worth right now.

     Base spirit regeneration, five times that under Innervate, and inside the
     five second rule only whatever the Reflection talent pays out. The first
     tick after a cast returns nothing at all: the source library carried a
     one-shot flag for exactly that, and the mana curve is visibly wrong without
     it. ]]--
function M:RegenPerTick()
    local _, spirit = UnitStat("player", 5)
    local base = ceil((spirit or 0) / 5) + 15

    if OB.HasPlayerBuff(INNERVATE) then return base * 5 end

    if self.fsrUntil and GetTime() < self.fsrUntil then
        if not self.fsrWaited then
            self.fsrWaited = true
            return 0
        end

        local _, _, _, _, rank = GetTalentInfo(3, 6)
        if not rank or rank == 0 then return 0 end
        return ceil(base * (0.05 * rank))
    end

    return base
end

--[[ Accrue one tick.

     While shifted, UNIT_MANA still fires -- for rage or energy -- and in vanilla
     those tick on the same two second cadence mana regeneration does. That
     coincidence is the whole trick: the event nobody can use for mana is used as
     the clock for it. ]]--
function M:Tick()
    self.lastTick = GetTime()

    if not self:Shifted() then
        self.cur = UnitMana("player") or 0
        self.max = UnitManaMax("player") or self.max
        return
    end

    if self.cur >= self.max then return end

    self.cur = self.cur + self:RegenPerTick() + self.gearTick
    if self.cur > self.max then self.cur = self.max end
end

--[[ Shifting spends mana, and once you are in the form no event will say so.
     A buff can make it free. ]]--
function M:PayShiftCost()
    if OB.HasPlayerBuff(FREE_SHIFT) then return end

    self.cur = self.cur - self.shiftCost
    if self.cur < 0 then self.cur = 0 end
end

-- the cost is paid on the way in; the way out re-seeds from an API that is
-- telling the truth again
function M:FormChanged()
    local shifted = self:Shifted()
    if shifted == self.shifted then return end

    self.shifted = shifted

    if shifted then
        self:PayShiftCost()
    else
        self:Resync()
    end
end

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------

function M:OnBind(slot)
    self:Rescan()
    self.shifted = self:Shifted()
    self:Resync()
end

function M:OnEvent()
    if event == "SPELLCAST_STOP" then
        -- casting starts the five second rule, and only a caster can cast
        if not self:Shifted() then
            self.fsrUntil = GetTime() + 5
            self.fsrWaited = false
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        self:Rescan()
        self.shifted = self:Shifted()
        self:Resync()
        OB.SetDirty(self)
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_MAXMANA" then
        if arg1 and arg1 ~= "player" then return end
        self:Rescan()
        self:Resync()
        OB.SetDirty(self)
        return
    end

    if event == "PLAYER_AURAS_CHANGED" or event == "UPDATE_SHAPESHIFT_FORMS" then
        self:FormChanged()
        OB.SetDirty(self)
        return
    end

    if arg1 and arg1 ~= "player" then return end
    self:Tick()
    OB.SetDirty(self)
end

--[[ Nothing has ticked for a while and the estimate sits just short of full: call
     it full.

     This is the correction the estimate's one-sided error allows. It can only
     ever have missed mana, never invented it, so a bar parked at 97% through a
     long quiet stretch is certainly wrong in one specific direction -- and
     rounding it up is the only correction available without an API to ask. ]]--
function M:OnUpdate(now)
    if not self.shifted or self.max <= 0 then return end
    if self.cur >= self.max then return end
    if (now - (self.lastTick or now)) < 6 then return end

    self.lastTick = now

    if (self.cur / self.max) > 0.9 then
        self.cur = self.max
        OB.SetDirty(self)
    end
end

-- ---------------------------------------------------------------------------
-- drawing
-- ---------------------------------------------------------------------------

function M:GetValue()
    if OB.testMode then
        return OB.test.druidMana or 0, OB.test.druidManaMax or 100
    end
    return floor(self.cur), floor(self.max)
end

function M:OnStyle(slot)
    OB.SetBarColor(self.frame, self:Config().color)
end

function M:OnDraw()
    local cfg = self:Config()
    local slot = OB.profile.slots[self.slotId]

    --[[ No baseline. Logging in already shifted means the real mana pool has
         never been visible this session, so there is nothing to estimate from --
         and an estimate built on a made-up starting point is worse than an empty
         slot, because it looks authoritative. The source library shipped a
         maximum of 10 for this case and drew a full bar on it. ]]--
    if not OB.testMode and not self.seeded then
        self.frame:Hide()
        return
    end

    --[[ In caster form the resource bar already shows real mana, so this one is
         a duplicate of it and hides by default. ]]--
    if cfg.hideInCaster and not OB.testMode and not self:Shifted() then
        self.frame:Hide()
        return
    end
    if not slot.hide then self.frame:Show() end

    local value, max = self:GetValue()

    local fraction = 0
    if max > 0 then fraction = value / max end

    OB.SetBarColor(self.frame, cfg.color)
    OB.SetBarFill(self.frame, fraction, slot.flip)
    self.frame.center:SetText(OB.FormatValue(value, max, cfg.textMode))
end

-- ---------------------------------------------------------------------------
-- test mode
-- ---------------------------------------------------------------------------

function M:TestStart(now)
    local realMax = UnitManaMax("player")
    if not realMax or realMax < 1 then realMax = 100 end

    OB.test.druidManaMax = realMax
    OB.test.druidMana = realMax * 0.4
    OB.test.druidManaAt = now
end

function M:TestStep(now)
    if (now - (OB.test.druidManaAt or 0)) < 0.5 then return end
    OB.test.druidManaAt = now

    local max = OB.test.druidManaMax or 100

    -- a shifted druid only ever regains mana, so the preview only climbs
    OB.test.druidMana = OB.test.druidMana + (max * 0.04)
    if OB.test.druidMana > max then OB.test.druidMana = max * 0.4 end

    OB.SetDirty(self)
end
