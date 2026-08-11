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

-- likewise one scale range, shared by the slider and the load-time clamp
OB.SCALE_MIN, OB.SCALE_MAX = 0.5, 1.5

function OB.ClampCoord(v)
    if not v then return 0 end
    if v < OB.POS_MIN then return OB.POS_MIN end
    if v > OB.POS_MAX then return OB.POS_MAX end
    return v
end

-- ---------------------------------------------------------------------------
-- defaults
-- ---------------------------------------------------------------------------

--[[ Bar geometry: offsets from the container's TOPLEFT with positive Y upward,
     stacked in OB.barOrder with a 1px gap, health at the top.

       health 115..99     resource 98..74    mainhand 73..61
       offhand 60..48     ranged 47..35      distance 34..22
       secondary 21..9    extras 8..0

     The panel lists them in this same order, so the list and the screen agree
     and there is nothing to reconcile.

     Most classes cannot fill all eight, which leaves a gap where their unusable
     bars sit. That is deliberate: geometry is account-wide, so closing the gap
     automatically for a rogue would move a hunter's bars. Restack Occupied Bars
     does it on demand -- see constraint 15. ]]--
OB.defaults = {
    schema = 5,

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
        health    = { x = 0, y = 115, w = 200, h = 16, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.5 }, textSize = 11 },
        resource  = { x = 0, y = 98,  w = 200, h = 24, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.5 }, textSize = 12 },
        mainhand  = { x = 0, y = 73,  w = 200, h = 12, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.8 }, textSize = 10 },
        offhand   = { x = 0, y = 60,  w = 200, h = 12, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.8 }, textSize = 10 },
        ranged    = { x = 0, y = 47,  w = 200, h = 12, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.8 }, textSize = 10 },
        distance  = { x = 0, y = 34,  w = 200, h = 12, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.5 }, textSize = 10 },
        secondary = { x = 0, y = 21,  w = 200, h = 12, show = true,  flip = false,
                      bg = { 0, 0, 0, 0.5 }, textSize = 10 },
        extras    = { x = 0, y = 8,   w = 200, h = 8,  show = true,  flip = false,
                      bg = { 0, 0, 0, 0.5 }, textSize = 12 },
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
    --[[ aux went from a reserved spare to a slot that takes whatever module
         defaults there, so its sentinel changed meaning and a saved "none" has
         to be re-read as "auto".

         Overriding a saved value is normally the wrong thing to do. It is right
         here because in schema 1 no module named aux as its default slot at all,
         so "none" was the only value the slot could ever have held -- nobody
         chose it over an alternative, because there was none. An explicit choice
         made since is preserved: only the untouched default is rewritten. ]]--
    { 2, function(p)
        if p.assign and p.assign["*"] and p.assign["*"].aux == "none" then
            p.assign["*"].aux = "auto"
        end
    end },

    --[[ Slots became Bars.

         Six abstract slots you assigned modules to became eight named bars, each
         permanently paired with one module. The rename carries each bar's tuned
         width, height, X, text size, background and flip across; only Y is
         rewritten, by the restack below, because the order changed and the two
         new bars have to go somewhere.

         What is lost, and it is worth being straight about: a deliberate
         *assignment*. Someone who had put health where combo points went gets
         health back in the Health bar. There is no way to preserve that, because
         the thing that expressed it no longer exists -- and it is the feature the
         restructure was asked for in order to remove.

         Module settings move with their ids. `range` reads better as `distance`
         next to a `ranged` swing timer, and `swing_main` reads worse than
         `mainhand` beside a bar called Main Hand. ]]--
    { 3, function(p)
        local bars = {
            points = "extras", swingB = "offhand", swingA = "mainhand",
            aux = "distance",
            -- health and resource keep their names
        }

        local modules = {
            range = "distance", swing_main = "mainhand",
            swing_off = "offhand", swing_ranged = "ranged",
        }

        --[[ Merged over the new key, never assigned to it.

             By the time a migration runs, `p` already holds a full set of
             defaults with the saved values merged on top -- so p.slots.mainhand
             exists and is complete, while p.slots.swingA holds only whatever the
             save happened to carry. Assigning one to the other replaces a
             complete table with a partial one and quietly drops every key the
             old save never mentioned. Merging keeps the defaults underneath,
             which is the same rule that makes a new setting appear for existing
             users. ]]--
        local function rename(t, from, to)
            if not t or not t[from] then return end

            if type(t[to]) == "table" then
                OB.DeepMerge(t[to], t[from])
            else
                t[to] = t[from]
            end

            t[from] = nil
        end

        for from, to in pairs(bars) do rename(p.slots, from, to) end
        for from, to in pairs(modules) do rename(p.modules, from, to) end

        if p.modulesEnabled then
            for from, to in pairs(modules) do
                if p.modulesEnabled[from] ~= nil then
                    p.modulesEnabled[to] = p.modulesEnabled[from]
                    p.modulesEnabled[from] = nil
                end
            end
        end

        p.assign = nil

        --[[ Restack in the new order, keeping the cluster where it was.

             Done here rather than by calling OB.RestackBars because that lives in
             layout.lua, loads after this file, and works off which bars are
             *bound* -- which needs a profile that has finished loading. A
             migration cannot wait for any of that, and the job is a dozen lines
             of arithmetic anyway.

             The top of the existing stack is reused as the top of the new one, so
             the whole cluster stays where the user put it on screen rather than
             jumping to the shipped default. ]]--
        local top
        for id, bar in pairs(p.slots) do
            if not top or bar.y > top then top = bar.y end
        end
        if not top then top = 115 end

        local y = top
        for i = 1, table.getn(OB.barOrder) do
            local bar = p.slots[OB.barOrder[i]]
            if bar then
                bar.y = OB.ClampCoord(y)
                y = y - bar.h - 1
            end
        end

        OB.Print("slots are now bars, and yours have been re-stacked in the new "
                .. "order. Drag them, or use Restack on the Bars page, to change it.")
    end },

    --[[ `hide` became `show`, inverted.

         A negative checkbox is a small papercut every single time it is read --
         "Hide Bar: unchecked" takes a beat to turn into "the bar is visible" --
         and this one had the additional problem of defaulting to off for two
         bars, so the readout you wanted was the one that looked disabled. A
         rename *and* an inversion is precisely the case the migration list
         exists for; a defaults change alone would have silently flipped every
         saved value.

         The low-health recolour goes at the same time. It is superseded by the
         planned colour-by-remaining-health, and leaving three dead keys in every
         saved profile forever is how a config file becomes archaeology. ]]--
    { 4, function(p)
        if p.slots then
            for id, bar in pairs(p.slots) do
                if bar.hide ~= nil then
                    bar.show = not bar.hide
                    bar.hide = nil
                end
            end
        end

        if p.modules and p.modules.health then
            p.modules.health.lowEnable = nil
            p.modules.health.lowThreshold = nil
            p.modules.health.lowColor = nil
        end
    end },

    --[[ Reveal the Distance bar.

         Schema 4 inverted `hide` into `show` faithfully, and faithfully was the
         bug: `aux` -- the slot that became Distance -- *shipped* hidden, so
         every profile carried `hide = true` on it without anyone having chosen
         that. The flip turned a shipped default into what looks like a decision,
         and the result was a Distance bar that came out of the upgrade switched
         off for every existing user while defaulting to on for new ones.

         Only Distance is affected. `secondary` did not exist before schema 3 and
         arrives from the defaults; every other bar shipped visible.

         This overrides a saved value, which is normally wrong. It is right here
         for the same reason the schema 2 step was: in the version that wrote it,
         the readout in that slot was hidden out of the box and the handover notes
         told you to run a command to reveal it, so `hide = true` means "never
         touched it" rather than "turned it off". The window in which somebody
         could have deliberately switched Distance off *since* the flip is a
         single version, and one release of a HUD nobody else runs.

         The general lesson, which is worth more than this fix: **inverting a key
         inverts defaults that were never chosen along with the choices.** When a
         migration flips a boolean, ask what the old default was, not just what
         the saved value is. ]]--
    { 5, function(p)
        if p.slots and p.slots.distance then p.slots.distance.show = true end
    end },
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
    if el.Hide ~= nil then slot.show = not el.Hide end
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

    --[[ RogueBars' four elements onto the bars that succeeded them. Its Y values
         come across untouched, so an imported layout lands exactly where it was
         -- the other four bars are new and sit wherever the defaults put them,
         which is what Restack is for. ]]--
    importGeometry(p.slots.extras, e.Combo)
    importGeometry(p.slots.offhand, e.OffHand)
    importGeometry(p.slots.mainhand, e.MainHand)
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

    if p.modules.offhand then importSwing(p.modules.offhand, e.OffHand) end
    if p.modules.mainhand then importSwing(p.modules.mainhand, e.MainHand) end

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

    --[[ The slider's range and this clamp are one setting in two places and must
         not disagree, or a profile can hold a scale its own slider cannot reach.
         A saved value above the ceiling is brought down rather than refused. ]]--
    if p.scale < OB.SCALE_MIN then p.scale = OB.SCALE_MIN end
    if p.scale > OB.SCALE_MAX then p.scale = OB.SCALE_MAX end

    db.profiles[name] = p
    OB.profile = p
    OB.profileName = name

    return p
end

--[[ There was an assignment layer here -- ResolveOccupant, SlotOf, AssignSlot --
     letting any module be put in any slot, per class, with "auto" and "none"
     sentinels. It is gone. A module names its bar and that is the end of it, so
     "which module draws here" is a registry lookup (OB.Occupant) rather than a
     stored, migratable, user-editable answer.

     It went because it was not earning its complexity: every bar can be dragged
     anywhere, so the ordering it existed to express was already the user's, and
     the dropdown that exposed it was the single most confusing control in the
     panel. ]]--

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

--[[ Every profile switch goes the same way: rebuild config, rebind, redraw, and
     re-read the panel.

     That last step is not optional and its absence was a real bug. LoadConfig
     replaces OB.profile wholesale, so every control on the panel is now reading
     a table that no longer exists -- and the profile dropdown in particular kept
     naming the profile you had just switched away from, which made switching
     look broken while it had in fact worked. The slash path called RefreshPanel
     itself; the panel path did not, so the control that most needed refreshing
     was the one that never got it. ]]--
local function reload()
    OB.LoadConfig()
    OB.BindSlots()
    OB.Refresh(true)
    OB.RefreshPanel()
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
