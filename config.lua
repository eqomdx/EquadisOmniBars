--[[ Equadis' OmniBars :: config

  Defaults, the profile store, and the merge that turns saved variables back into
  a live config table.

  The shape here is the whole point of the addon:

    slots   -- geometry and style. Never colour, never behaviour.
    assign  -- which module occupies which slot, per class.
    modules -- behaviour and colour. Never geometry.

  Because geometry lives on the slot and every character on a profile shares the
  slots table, a warrior's rage bar and a rogue's energy bar are literally the
  same rectangle. Only the occupant changes. Colour lives on the module
  deliberately: it is semantic, and it is the one thing that *should* differ when
  the occupant does.
]]--

local OB = EquadisOmniBars

--[[ One position range, shared by the X/Y sliders, dragging, the arrow buttons
     and the saved values. They must never disagree: three separate ranges is how
     a bar ends up at a coordinate its own slider cannot reach. ]]--
OB.POS_MIN, OB.POS_MAX = -2000, 2000
OB.HEIGHT_MAX = 40

function OB.ClampCoord(v)
    if not v then return 0 end
    if v < OB.POS_MIN then return OB.POS_MIN end
    if v > OB.POS_MAX then return OB.POS_MAX end
    return v
end

-- ---------------------------------------------------------------------------
-- defaults
-- ---------------------------------------------------------------------------

--[[ Slot geometry continues RogueBars' stack: offsets from the container's
     TOPLEFT with positive Y upward, at the sizes it shipped with. An imported
     RogueBars layout therefore lands exactly where it was, and the two new slots
     sit in free space below it.

       points 115..107   swingB 106..94   swingA 93..81
       resource 80..56   health 55..39    aux 38..26 ]]--
OB.defaults = {
    schema = 1,

    -- visibility
    show = true,
    hideOOC = false,
    hideStealth = false,
    hideDead = true,

    -- movement
    locked = false,
    join = true,
    allowOverlap = false,

    -- appearance
    scale = 1.0,
    texture = 8,           -- Interface\TargetingFrame\UI-StatusBar, RogueBars' default
    border = 1,            -- None
    font = OB.fontIndex["Roboto"] or 1,
    fontName = "Roboto",
    fontSize = 12,
    fontOutline = true,

    -- feedback
    audible = false,

    --[[ Per-module on/off. Absent means on: a module registered by a later
         version is enabled until the user says otherwise, which is the same
         principle as the defaults merge. ]]--
    modulesEnabled = {},

    slots = {
        points   = { x = 0, y = 115, w = 200, h = 8,  hide = false, flip = false,
                     bg = { 0, 0, 0, 0.5 }, textSize = 12 },
        swingB   = { x = 0, y = 106, w = 200, h = 12, hide = false, flip = false,
                     bg = { 0, 0, 0, 0.8 }, textSize = 10 },
        swingA   = { x = 0, y = 93,  w = 200, h = 12, hide = false, flip = false,
                     bg = { 0, 0, 0, 0.8 }, textSize = 10 },
        resource = { x = 0, y = 80,  w = 200, h = 24, hide = false, flip = false,
                     bg = { 0, 0, 0, 0.5 }, textSize = 12 },
        health   = { x = 0, y = 55,  w = 200, h = 16, hide = false, flip = false,
                     bg = { 0, 0, 0, 0.5 }, textSize = 11 },
        aux      = { x = 0, y = 38,  w = 200, h = 12, hide = true,  flip = false,
                     bg = { 0, 0, 0, 0.5 }, textSize = 10 },
    },

    --[[ "*" is every class; a class key overrides it slot by slot.

         The hunter rows are seeded data, not a branch in the code: a hunter has
         no off hand and wants the range readout where a rogue keeps combo
         points. Changing the dropdown writes exactly this shape, so the shipped
         default and a user edit are indistinguishable. ]]--
    assign = {
        ["*"] = {
            points = "auto", swingB = "auto", swingA = "auto",
            resource = "auto", health = "auto", aux = "none",
        },
        ["HUNTER"] = { points = "range", swingB = "none" },
    },

    -- filled in by OB.RegisterModule as each module loads
    modules = {},
}

-- ---------------------------------------------------------------------------
-- profile migrations
--
-- A list rather than a run of inline statements, so each step says which schema
-- it produces. Equadis' Threat Meter does this as a hundred unlabelled lines in
-- the middle of LoadConfig, which will not survive five merged addons.
--
-- A migration is only needed when a key is renamed, restructured or inverted.
-- A *new* setting needs nothing: adding it to OB.defaults (or a module's
-- defaults) is what makes it exist for current users, because the merge is
-- saved-over-default.
-- ---------------------------------------------------------------------------

OB.profileMigrations = {
    -- { 2, function(p) ... end },
}

function OB.RunProfileMigrations(p)
    p.schema = p.schema or 1

    for i = 1, table.getn(OB.profileMigrations) do
        local step = OB.profileMigrations[i]
        if p.schema < step[1] then
            step[2](p)
            p.schema = step[1]
        end
    end
end

-- ---------------------------------------------------------------------------
-- importing RogueBars
-- ---------------------------------------------------------------------------

local rbTextureNames = {
    ["ShaguPlates"] = 2, ["TukUI"] = 3, ["ElvUI"] = 4,
    ["Gradient"] = 5, ["Striped"] = 6,
    ["Wow Status"] = 8, ["Wow Skill"] = 10,
}

-- RogueBars 2.3 renamed its own texture keys; apply that first
local rbTextureRenames = {
    ["wow status"] = "Wow Status", ["wow skill"] = "Wow Skill",
    ["shaguplates"] = "ShaguPlates", ["tukui"] = "TukUI",
    ["elvui"] = "ElvUI", ["gradient"] = "Gradient", ["striped"] = "Striped",
}

local rbBorders = { ["none"] = 1, ["thin"] = 2, ["standard"] = 3 }

local function copyColor(src, fallback)
    if type(src) ~= "table" then return fallback end
    return { src[1] or 0, src[2] or 0, src[3] or 0, src[4] or 1 }
end

-- one RogueBars element's geometry onto one slot
local function importGeometry(slot, el)
    if type(el) ~= "table" then return end

    if el.Width then slot.w = el.Width end
    if el.Height then slot.h = el.Height end
    if el.X then slot.x = OB.ClampCoord(el.X) end
    if el.Y then slot.y = OB.ClampCoord(el.Y) end
    if el.TextSize then slot.textSize = el.TextSize end
    if el.Hide ~= nil then slot.hide = el.Hide and true or false end
    if el.Flip ~= nil then slot.flip = el.Flip and true or false end
    slot.bg = copyColor(el.BGColor, slot.bg)
end

local function importSwing(cfg, el)
    if type(el) ~= "table" then return end

    cfg.color = copyColor(el.Color, cfg.color)
    if el.Decimals then cfg.decimals = el.Decimals end
    if el.Swap ~= nil then cfg.swap = el.Swap and true or false end
    if el.ShowTimer ~= nil then cfg.showTimer = el.ShowTimer and true or false end
    if el.ShowSpeed ~= nil then cfg.showSpeed = el.ShowSpeed and true or false end
    if el.Deplete ~= nil then cfg.deplete = el.Deplete and true or false end
end

--[[ Seed a fresh profile from an installed RogueBars.

     RogueBarsConfig is account-wide, which is exactly the behaviour wanted here:
     one imported layout that every character then shares. Nothing is written
     back to RogueBarsConfig and nothing is deleted from it, so uninstalling
     OmniBars loses nothing.

     RogueBars' own pre-1.1 migration chain is deliberately not ported. A config
     five versions stale imports its post-merge shape; run RogueBars once to
     normalise it first if that matters. ]]--
function OB.ImportRogueBars(p)
    local rb = RogueBarsConfig
    if type(rb) ~= "table" or type(rb.Elements) ~= "table" then return false end

    if rb.Scale then p.scale = rb.Scale end
    if rb.Show ~= nil then p.show = rb.Show and true or false end
    if rb.HideStealth ~= nil then p.hideStealth = rb.HideStealth and true or false end
    if rb.HideOOC ~= nil then p.hideOOC = rb.HideOOC and true or false end
    if rb.Audible ~= nil then p.audible = rb.Audible and true or false end
    if rb.Locked ~= nil then p.locked = rb.Locked and true or false end
    if rb.Join ~= nil then p.join = rb.Join and true or false end
    if rb.AllowOverlap ~= nil then p.allowOverlap = rb.AllowOverlap and true or false end

    if type(rb.Texture) == "string" then
        local name = rbTextureRenames[rb.Texture] or rb.Texture
        p.texture = rbTextureNames[name] or p.texture
    end

    if type(rb.Border) == "string" then
        p.border = rbBorders[rb.Border] or p.border
    end

    local e = rb.Elements

    importGeometry(p.slots.points, e.Combo)
    importGeometry(p.slots.swingB, e.OffHand)
    importGeometry(p.slots.swingA, e.MainHand)
    importGeometry(p.slots.resource, e.Energy)

    if p.modules.combopoints and type(e.Combo) == "table"
            and type(e.Combo.Colors) == "table" then
        for i = 1, 5 do
            if e.Combo.Colors[i] then
                p.modules.combopoints.colors[i] =
                        copyColor(e.Combo.Colors[i], p.modules.combopoints.colors[i])
            end
        end
    end

    if p.modules.swing_off then importSwing(p.modules.swing_off, e.OffHand) end
    if p.modules.swing_main then importSwing(p.modules.swing_main, e.MainHand) end

    --[[ RogueBars only ever drew energy, so its bar colour and ticker mode are
         the energy variant's. The other power types keep their own defaults. ]]--
    if p.modules.power and type(e.Energy) == "table" then
        local energy = p.modules.power.byType[3]
        if energy then
            energy.color = copyColor(e.Energy.Color, energy.color)
            if e.Energy.Ticker then energy.ticker = e.Energy.Ticker end
        end
        p.modules.power.tickerColor =
                copyColor(e.Energy.TickerColor, p.modules.power.tickerColor)
        if e.Energy.TextMode then p.modules.power.textMode = e.Energy.TextMode end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- database migrations
--
-- Each import is guarded by db.migrated.<name>, so reinstalling an old addon
-- can never re-import over a layout that has since been tuned.
-- ---------------------------------------------------------------------------

function OB.RunDBMigrations(db)
    db.migrated = db.migrated or {}

    if not db.migrated.roguebars then
        db.migrated.roguebars = true
        db.pendingRogueBarsImport = true
    end

    -- reserved: v2 TWT_CONFIG -> modules.threat
    --           v3 ShaguDPS_Config -> modules.meter
    --           v4 UnitFramesConfig + the four uf* CVars -> modules.unitframes

    db.version = 1
end

-- ---------------------------------------------------------------------------
-- load
-- ---------------------------------------------------------------------------

function OB.CharacterKey()
    local realm = GetRealmName() or "Unknown"
    return realm .. " - " .. (UnitName("player") or "Unknown")
end

--[[ Build the live config for this character.

     The resulting table *is* db.profiles[name] -- not a copy of it. That is
     Equadis' Threat Meter's trick and it removes an entire class of bug: there
     is no save step to forget, because every write already lands in the saved
     variables. ]]--
function OB.LoadConfig()
    if type(EquadisOmniBarsDB) ~= "table" then
        EquadisOmniBarsDB = { version = 0, profiles = {}, chars = {}, migrated = {} }
    end

    local db = EquadisOmniBarsDB
    db.profiles = db.profiles or {}
    db.chars = db.chars or {}

    OB.RunDBMigrations(db)

    local key = OB.CharacterKey()
    local name = db.chars[key] or "Default"
    db.chars[key] = name

    -- a fresh copy every load, so a colour table is never aliased into defaults
    local p = OB.DeepCopy(OB.defaults)

    local existing = db.profiles[name]
    if existing then
        OB.DeepMerge(p, existing)
    elseif db.pendingRogueBarsImport then
        db.pendingRogueBarsImport = nil
        if OB.ImportRogueBars(p) then
            OB.Print("imported your RogueBars layout into the '" .. name .. "' profile.")
        end
    end
    db.pendingRogueBarsImport = nil

    OB.RunProfileMigrations(p)

    -- guard every media index against a list that changed between versions
    if not OB.textures[p.texture] then p.texture = 1 end
    if not OB.borders[p.border] then p.border = 1 end

    -- the font list can gain entries, which shifts every index after the
    -- insertion point, so the saved *name* is authoritative when present
    if p.fontName and OB.fontIndex[p.fontName] then p.font = OB.fontIndex[p.fontName] end
    if not OB.fonts[p.font] then p.font = OB.fontIndex["Roboto"] or 1 end
    p.fontName = OB.fonts[p.font]

    for id, slot in pairs(p.slots) do
        slot.x = OB.ClampCoord(slot.x)
        slot.y = OB.ClampCoord(slot.y)
        if slot.w < 0 then slot.w = 0 end
        if slot.h > OB.HEIGHT_MAX then slot.h = OB.HEIGHT_MAX end
        if slot.h < 1 then slot.h = 1 end
    end

    if p.scale < 0.5 then p.scale = 0.5 end
    if p.scale > 2.0 then p.scale = 2.0 end

    db.profiles[name] = p
    OB.profile = p
    OB.profileName = name

    return p
end

--[[ Resolve a slot's occupant: an explicit assignment for this class, else the
     "*" row, else "auto", which asks the registry. "none" is an explicit empty
     that overrides auto. ]]--
function OB.ResolveOccupant(slotId)
    local p = OB.profile
    if not p then return nil end

    local want
    if p.assign[OB.class] then want = p.assign[OB.class][slotId] end
    if want == nil and p.assign["*"] then want = p.assign["*"][slotId] end
    if want == nil then want = "auto" end

    if want == "none" then return nil end
    if want == "auto" then return OB.AutoOccupant(slotId) end

    if not OB.ModuleEnabled(want) then return nil end
    return want
end

-- which slot a module currently sits in, or nil
function OB.SlotOf(moduleId)
    for i = 1, table.getn(OB.slotOrder) do
        local slotId = OB.slotOrder[i]
        if OB.ResolveOccupant(slotId) == moduleId then return slotId end
    end
    return nil
end

--[[ Point a slot at a module.

     A module occupies at most one slot, so assigning one that already sits
     elsewhere vacates its old home. Without that the binder would need to
     resolve the conflict itself on every rebind. ]]--
function OB.AssignSlot(slotId, moduleId)
    local p = OB.profile
    if not p or not p.slots[slotId] then return end

    if moduleId ~= "auto" and moduleId ~= "none" then
        local previous = OB.SlotOf(moduleId)
        if previous and previous ~= slotId then
            p.assign[OB.class] = p.assign[OB.class] or {}
            p.assign[OB.class][previous] = "none"
            OB.Print(OB.slotLabels[previous] .. " emptied: "
                    .. moduleId .. " moved to " .. OB.slotLabels[slotId] .. ".")
        end
    end

    p.assign[OB.class] = p.assign[OB.class] or {}
    p.assign[OB.class][slotId] = moduleId
end

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

function OB.ProfileNames()
    local names = {}
    for name in pairs(EquadisOmniBarsDB.profiles) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- every profile switch goes the same way: rebuild config, rebind, redraw
local function reload()
    OB.LoadConfig()
    OB.BindSlots()
    OB.Refresh(true)
end

function OB.SetProfile(name)
    if not EquadisOmniBarsDB.profiles[name] then
        OB.Print("no profile named '" .. tostring(name) .. "'.")
        return
    end
    EquadisOmniBarsDB.chars[OB.CharacterKey()] = name
    reload()
    OB.Print("using profile '" .. name .. "'.")
end

-- a new profile is a copy of the current one: starting from bare defaults is
-- almost never what someone making a variant wants
function OB.NewProfile(name)
    if not name or name == "" then return end
    if EquadisOmniBarsDB.profiles[name] then
        OB.Print("profile '" .. name .. "' already exists.")
        return
    end
    EquadisOmniBarsDB.profiles[name] = OB.DeepCopy(OB.profile)
    EquadisOmniBarsDB.chars[OB.CharacterKey()] = name
    reload()
    OB.Print("created profile '" .. name .. "' from '" .. OB.profileName .. "'.")
end

function OB.CopyProfile(from)
    local source = EquadisOmniBarsDB.profiles[from]
    if not source then
        OB.Print("no profile named '" .. tostring(from) .. "'.")
        return
    end
    if from == OB.profileName then return end

    EquadisOmniBarsDB.profiles[OB.profileName] = OB.DeepCopy(source)
    reload()
    OB.Print("copied '" .. from .. "' over '" .. OB.profileName .. "'.")
end

function OB.DeleteProfile(name)
    if name == "Default" then
        OB.Print("the Default profile cannot be deleted.")
        return
    end
    if not EquadisOmniBarsDB.profiles[name] then return end

    EquadisOmniBarsDB.profiles[name] = nil

    -- anyone left pointing at it falls back to Default
    for char, used in pairs(EquadisOmniBarsDB.chars) do
        if used == name then EquadisOmniBarsDB.chars[char] = "Default" end
    end

    reload()
    OB.Print("deleted profile '" .. name .. "'.")
end

--[[ Reset the *current* profile only, including its assignments. Other profiles
     and every character's binding are left alone -- see OB.ResetAll for the
     bigger hammer. ]]--
function OB.ResetProfile()
    EquadisOmniBarsDB.profiles[OB.profileName] = nil
    reload()
    OB.Print("profile '" .. OB.profileName .. "' restored to defaults.")
end

function OB.ResetAll()
    EquadisOmniBarsDB = nil
    reload()
    OB.Print("every profile restored to defaults.")
end
