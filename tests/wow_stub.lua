--[[ A fake Vanilla 1.12 client, enough of one to load and drive the addon.

  Run under LuaJIT (5.1 semantics -- the closest widely available match to the
  1.12 client's Lua 5.0). Nothing here is shipped: the TOC does not list this
  directory, and WoW only loads files a TOC names.

  Two deliberate choices:

  Widgets return real values, not nil. GetWidth after SetWidth gives the width
  back, GetChecked reflects SetChecked, and so on -- otherwise every arithmetic
  path in the addon (SetBarFill in particular, which multiplies by GetWidth)
  would silently short-circuit and the tests would pass by not executing.

  Unknown methods are answered by a recorded fallback rather than an error. A
  hard error would mean chasing every cosmetic call the addon makes; instead
  Stub.UnknownMethods() lists what got faked, so a typo'd API name shows up as
  an unexpected entry rather than hiding.
]]--

Stub = {}

--[[ **The client is Lua 5.0, so the string iterator is `gfind` and `gmatch` does
     not exist.** LuaJIT has it exactly the other way round.

     Both halves matter. Adding `gfind` lets the addon use the name the client
     actually has; removing `gmatch` is what stops a 5.1-ism compiling here and
     then erroring in the game, which is the whole reason the harness runs at
     all. The same applies to `table.getn` over `#`, which is why nothing in the
     addon uses the length operator either. ]]--
if not string.gfind then string.gfind = string.gmatch end
string.gmatch = nil

local unknown = {}
local frames = {}
local clock = 10000

-- ---------------------------------------------------------------------------
-- widget objects
-- ---------------------------------------------------------------------------

local function noop() end

--[[ Fabricate a no-op for any method the stub does not implement, and record it.

     Only PascalCase keys are treated as methods. Every WoW widget method starts
     with a capital; every field the stub keeps state in is lowercase. Without
     that discriminator, reading an unset state field (self.checked, self.value)
     would hand back a function, which is truthy -- so `self.tex or create()`
     would never create, and GetChecked() would return a function. ]]--
local widgetMT = {}
widgetMT.__index = function(t, key)
    if type(key) ~= "string" then return nil end
    if not string.find(key, "^%u") then return nil end

    unknown[(rawget(t, "__objtype") or "?") .. ":" .. key] = true
    local fn = function() end
    rawset(t, key, fn)
    return fn
end

local function newObject(objtype)
    local o = setmetatable({}, widgetMT)
    o.__objtype = objtype

    --[[ **Regions answer what they are, the same way frames do.**

         Left to the auto-faking metatable this returned nil, which is not an
         error and is worse than one: a nameplate is identified by its first
         region being a `Texture`, so a stub that would not say what a region
         *was* silently answered "not a nameplate" to every plate in the world
         and the module found nothing at all. Nothing errored. ]]--
    o.GetObjectType = function(self) return self.__objtype end

    return o
end

-- ---------------------------------------------------------------------------
-- regions: Texture and FontString
-- ---------------------------------------------------------------------------

local function definePoints(o)
    o.points = {}
    o.ClearAllPoints = function(self) self.points = {} end
    o.SetPoint = function(self, point, rel, relPoint, x, y)
        table.insert(self.points, { point, rel, relPoint, x, y })
    end
    o.GetNumPoints = function(self) return table.getn(self.points) end

    --[[ One anchor, read back. `GetPoint` is the only way to ask a frame what it
         is attached to, and the Escape menu button has to ask -- which button
         sits under Options differs between clients, so it is found rather than
         named. Answered in the client's order: point, relativeTo, relativePoint,
         x, y. ]]--
    o.GetPoint = function(self, index)
        local p = self.points[index or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    o.SetAllPoints = function(self) end

    --[[ **Screen edges, modelled rather than left to the auto-faking
         metatable.**

         Absent, these answered nil, and nil is the one value that makes the
         centre-from-edges arithmetic every draggable window does throw rather
         than misbehave. Both meters compute their dropped position from
         GetLeft/GetBottom, so *neither drop path had ever been executed* by the
         suite -- it could only ever check that a drag handler existed.

         Only CENTER-on-CENTER is modelled, because that is the anchor every
         window this addon owns actually uses. Anything else answers nil, which
         is honest: the stub does not know, and pretending would hide the next
         bug rather than the last one. ]]--
    local function centreOffset(self)
        local p = self.points[1]
        if not p then return nil end
        if p[1] ~= "CENTER" or p[3] ~= "CENTER" then return nil end
        return p[4] or 0, p[5] or 0
    end

    o.GetLeft = function(self)
        local x = centreOffset(self)
        if not x then return nil end
        return (GetScreenWidth() / 2) + x - ((self.width or 0) / 2)
    end

    o.GetBottom = function(self)
        local _, y = centreOffset(self)
        if not y then return nil end
        return (GetScreenHeight() / 2) + y - ((self.height or 0) / 2)
    end

    o.GetRight = function(self)
        local left = self:GetLeft()
        if not left then return nil end
        return left + (self.width or 0)
    end

    o.GetTop = function(self)
        local bottom = self:GetBottom()
        if not bottom then return nil end
        return bottom + (self.height or 0)
    end
end

local function defineShow(o)
    o.shown = true
    o.Show = function(self) self.shown = true end
    o.Hide = function(self) self.shown = false end
    o.IsShown = function(self) return self.shown end
    o.IsVisible = function(self)
        if not self.shown then return false end
        local p = self.parent
        while p do
            if not p.shown then return false end
            p = p.parent
        end
        return true
    end
end

local function defineSize(o)
    o.width, o.height = 0, 0
    o.SetWidth = function(self, v) self.width = v end
    o.SetHeight = function(self, v) self.height = v end
    o.GetWidth = function(self) return self.width end
    o.GetHeight = function(self) return self.height end
end

local function newTexture(parent, layer)
    local t = newObject("Texture")
    t.parent = parent
    t.layer = layer
    definePoints(t)
    defineShow(t)
    defineSize(t)

    t.SetTexture = function(self, a, b, c, d)
        if type(a) == "string" then
            self.texture, self.rgba = a, nil
        else
            self.texture, self.rgba = nil, { a, b, c, d }
        end
    end
    t.GetTexture = function(self) return self.texture end
    t.SetVertexColor = function(self, r, g, b, a)
        self.vertex = { r, g, b, a }
    end

    --[[ Readable, because the tint is a thing that gets *restored*: dark mode
         sets it, drag mode overrides it green, and switching drag mode off has
         to put dark mode's back rather than white. Only the read side can tell
         those two apart. ]]--
    t.GetVertexColor = function(self)
        if not self.vertex then return 1, 1, 1, 1 end
        return self.vertex[1], self.vertex[2], self.vertex[3], self.vertex[4]
    end
    t.SetTexCoord = function(self, ...)
        self.texcoord = { ... }
    end
    t.SetAlpha = function(self, v) self.alpha = v end
    t.GetAlpha = function(self) return self.alpha or 1 end
    return t
end

--[[ A FontString has no font object unless it inherited one from a template or
     was given one with SetFont, and in 1.12 touching the text or its colour
     before then is an error rather than a no-op.

     This is modelled rather than ignored because ignoring it shipped a dead
     settings panel with a green test suite: one `CreateFontString(nil, "OVERLAY")`
     followed by SetTextColor threw in the real client, aborted the panel build
     midway through a page, and the stub recorded the colour and said nothing.
     A stub that agrees with a wrong assumption still passes -- so where the rule
     is known, it belongs here. ]]--
local function newFontString(parent, layer, inherits)
    local f = newObject("FontString")
    f.parent = parent
    definePoints(f)
    defineShow(f)
    defineSize(f)

    if inherits then f.font = "inherited:" .. inherits end

    local function requireFont(self, what)
        if not self.font then
            error("FontString:" .. what .. " on a font string with no font: "
                    .. "create it with an inherited template, or call SetFont first", 3)
        end
    end

    f.text = ""
    f.SetText = function(self, v)
        requireFont(self, "SetText")
        self.text = v or ""
    end
    f.GetText = function(self) return self.text end
    f.SetFont = function(self, path, size, flags)
        self.font, self.fontSize, self.fontFlags = path, size, flags
    end
    f.GetFont = function(self) return self.font, self.fontSize, self.fontFlags end
    f.SetTextColor = function(self, r, g, b)
        requireFont(self, "SetTextColor")
        self.color = { r, g, b }
    end
    f.SetJustifyH = function(self, v) self.justify = v end
    f.SetAlpha = function(self, v) self.alpha = v end

    --[[ A rendered width, modelled rather than left to the auto-faking
         metatable -- which would answer nil, and nil is the one value that makes
         a clamp against the bar's edges silently do nothing.

         Half the point size per character is a rough average for a proportional
         face and wrong for any particular string. It does not need to be right:
         what depends on it is "does this label still fit", and the shape of that
         answer -- grows with the text, grows with the font size -- is what the
         stub has to get right. ]]--
    f.GetStringWidth = function(self)
        return string.len(self.text or "") * ((self.fontSize or 12) * 0.5)
    end

    --[[ Wrapped height, which is what the options layout has to know before it
         can place the row underneath.

         Modelled rather than left to the metatable for the same reason as the
         width: nil is the one answer that makes a layout silently do nothing,
         and "everything below the paragraph is drawn on top of it" was exactly
         the bug that reached the game. Lines are derived from the width the
         caller set, so a paragraph that wraps here wraps there. ]]--
    f.GetStringHeight = function(self)
        --[[ A font string with no font cannot be measured, exactly as it cannot
             be given text or a colour. This one threw inside the options page
             builder, which abandoned the rest of the page -- and since the
             description is built first, the whole tab came up empty. ]]--
        requireFont(self, "GetStringHeight")

        local size = self.fontSize or 12
        local width = self.width or 0
        local text = self.text or ""

        if width <= 0 then return size end

        local lines = math.ceil(self:GetStringWidth() / width)

        -- explicit breaks add lines the wrap calculation cannot see
        local _, breaks = string.gsub(text, "\n", "")
        lines = lines + breaks

        if lines < 1 then lines = 1 end
        return lines * size * 1.2
    end

    return f
end

-- ---------------------------------------------------------------------------
-- frames
-- ---------------------------------------------------------------------------

local templates = {}

templates.UICheckButtonTemplate = function(frame)
    if frame.name then
        _G[frame.name .. "Text"] = newFontString(frame, "OVERLAY", "GameFontNormal")
    end
end

templates.OptionsSliderTemplate = function(frame)
    if frame.name then
        _G[frame.name .. "Low"] = newFontString(frame, "OVERLAY", "GameFontNormal")
        _G[frame.name .. "High"] = newFontString(frame, "OVERLAY", "GameFontNormal")
        _G[frame.name .. "Text"] = newFontString(frame, "OVERLAY", "GameFontNormal")
    end
end

--[[ A scanning tooltip. Loading an item or a spell copies a block out of
     Stub.tooltips into the line font strings, which is the only part of a real
     tooltip the addon ever reads.

     These methods have to be real rather than left to the auto-faking metatable:
     NumLines answering nil would turn `for i = 1, tip:NumLines()` into an error
     rather than an empty loop, and the whole scrape would silently never run. ]]--
templates.GameTooltipTemplate = function(frame)
    frame.lines = {}
    frame.lineCount = 0

    frame.Line = function(self, i)
        if not self.lines[i] then
            self.lines[i] = newFontString(self, "OVERLAY", "GameTooltipText")
            if self.name then _G[self.name .. "TextLeft" .. i] = self.lines[i] end
        end
        return self.lines[i]
    end

    frame.ClearLines = function(self)
        self.lineCount = 0
        for i = 1, table.getn(self.lines) do self.lines[i]:SetText("") end
    end

    frame.NumLines = function(self) return self.lineCount end
    frame.SetOwner = function() end

    --[[ Writing to a tooltip, as opposed to scraping one. The addon only ever
         read tooltips until the meters grew a hover breakdown; without these the
         breakdown could be built and never once executed by the suite, which is
         constraint 49's shape all over again.

         Both halves of a double line are kept, because the whole point of the
         breakdown is a name on the left and a number on the right, and a stub
         that dropped one of them could not tell a correct row from an empty
         one. ]]--
    frame.AddLine = function(self, text)
        self.lineCount = self.lineCount + 1
        self:Line(self.lineCount):SetText(text or "")
        self.rightLines = self.rightLines or {}
        self.rightLines[self.lineCount] = nil
    end

    frame.AddDoubleLine = function(self, left, right)
        self.lineCount = self.lineCount + 1
        self:Line(self.lineCount):SetText(left or "")
        self.rightLines = self.rightLines or {}
        self.rightLines[self.lineCount] = right or ""
    end

    frame.RightLine = function(self, i)
        return self.rightLines and self.rightLines[i]
    end

    --[[ **A tooltip the client filled in, rather than one an addon built.**

         This is the case 1.12 gives no unit token for: hovering a mob populates
         the tooltip from the C client, so there is nothing to ask "which unit is
         this". Anything reading the tooltip has to read the *text*, and this
         writes the text the way the client writes it -- "Level 60 Elite
         Humanoid", one string, elite and type included.

         Then it fires OnShow, because that is the only signal an addon gets. ]]--
    --[[ **An item tooltip, with the sell price where the client puts it.**

         1.12 prints a vendor price into a *money frame* rather than into text,
         and only while a merchant window is open. Modelled that way -- a
         separate frame with gold, silver and copper of its own -- because a stub
         that wrote "Sell Price: 3s" as a line would agree with a scraper that
         only ever read lines, and the client does not write one.

         The addon reads text too, for the sell-value addons that add a line.
         Both paths exist here so both can be exercised. ]]--
    frame.SetBagItem = function(self, bag, slot)
        local b = Stub.bags[bag]
        local item = b and b[slot]

        self:ClearLines()
        if not item then return end

        self:AddLine(item.name)

        --[[ The client only prints it at a vendor. That is the constraint the
             whole learned-price store exists to work around, so it is real
             here. ]]--
        local price = nil
        if MerchantFrame and MerchantFrame:IsVisible() then
            price = item.price
        end

        --[[ For the stack, not for one, which is how the client writes it. ]]--
        if price then price = price * (item.count or 1) end

        if item.priceAsText and price then
            self:AddLine("Sell Price: " .. EquadisClassicOverhaul.Money(price))
            price = nil
        end

        self:SetMoney(price)
    end

    --[[ The money frame, named the way the client names it: `<tip>MoneyFrame1`
         with a Gold, Silver and Copper button under it, each carrying its own
         text. Anything reading it has to walk that naming. ]]--
    frame.SetMoney = function(self, copper)
        if not self.name then return end

        local units = { GoldButton = 10000, SilverButton = 100, CopperButton = 1 }
        local moneyName = self.name .. "MoneyFrame1"

        if not _G[moneyName] then
            _G[moneyName] = CreateFrame("Frame", moneyName, self)

            for suffix in pairs(units) do
                local button = CreateFrame("Frame", moneyName .. suffix, nil)
                _G[moneyName .. suffix .. "Text"] =
                        newFontString(button, "OVERLAY", "GameFontNormal")
            end
        end

        local left = copper

        for _, suffix in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
            local text = _G[moneyName .. suffix .. "Text"]

            if not left then
                text:SetText("")
            else
                local worth = units[suffix]
                text:SetText(tostring(math.floor(left / worth)))
                left = mod(left, worth)
            end
        end
    end

    frame.SetMob = function(self, name, level, kind, elite)
        self:ClearLines()
        self:AddLine(name)

        local second = "Level " .. tostring(level)
        if elite then second = second .. " Elite" end
        if kind then second = second .. " " .. kind end

        self:AddLine(second)

        local onShow = self:GetScript("OnShow")
        if onShow then onShow() end
    end

    local function load(self, key)
        self:ClearLines()

        local block = Stub.tooltips[key]
        if not block then return end

        for i = 1, table.getn(block) do
            self:Line(i):SetText(block[i])
        end
        self.lineCount = table.getn(block)
    end

    frame.SetInventoryItem = function(self, unit, slot) load(self, "item" .. slot) end
    frame.SetSpell = function(self, index, bookType) load(self, "spell" .. index) end

    --[[ 1.12 has no GetActionSpell, so the only way to learn what an action
         button holds is to point a tooltip at it and read line one. The stub
         answers from Stub.actionBar, which maps slot -> name. ]]--
    frame.SetAction = function(self, slot)
        self:ClearLines()

        local name = Stub.actionBar and Stub.actionBar[slot]
        if not name then return end

        self:Line(1):SetText(name)
        self.lineCount = 1
    end
end

function CreateFrame(ftype, name, parent, template)
    local f = newObject(ftype or "Frame")
    f.frameType = ftype
    f.name = name
    f.parent = parent
    f.children = {}
    f.scripts = {}
    f.events = {}
    f.level = parent and ((parent.level or 0) + 1) or 0
    f.scale = 1

    definePoints(f)
    defineShow(f)
    defineSize(f)

    f.GetName = function(self) return self.name end
    f.GetParent = function(self) return self.parent end

    --[[ **Re-parenting, which is a real operation and not a rename.** A child
         inherits its parent's visibility, alpha and scale, so moving a button
         off Blizzard's bar frame onto one of ours is what stops the client
         hiding it along with its own art. The list on both sides is kept
         straight because `IsVisible` walks it. ]]--
    f.SetParent = function(self, p)
        if self.parent and self.parent.children then
            for i = table.getn(self.parent.children), 1, -1 do
                if self.parent.children[i] == self then
                    table.remove(self.parent.children, i)
                end
            end
        end

        self.parent = p
        if p and p.children then table.insert(p.children, self) end
    end
    f.GetObjectType = function(self) return self.frameType end

    f.SetFrameLevel = function(self, v) self.level = v end
    f.GetFrameLevel = function(self) return self.level end

    --[[ The client refusing to let a moving frame leave the screen. Recorded
         rather than simulated: the stub does not run a drag, so what is worth
         asserting is that the window *asked* for it -- which is the thing that
         was missing and let both meters be pulled off the edge. ]]--
    --[[ **Backdrops, recorded rather than faked.** The edit box's colour is set
         on a frame behind it because 1.12's EditBox does not reliably take one
         itself, and a stub that swallowed the call could not tell the two
         apart. ]]--
    f.SetBackdrop = function(self, b) self.backdrop = b end
    f.GetBackdrop = function(self) return self.backdrop end
    f.SetBackdropColor = function(self, r, g, b, a)
        self.backdropColor = { r, g, b, a }
    end
    f.SetBackdropBorderColor = function(self, r, g, b, a)
        self.backdropBorder = { r, g, b, a }
    end

    f.SetClampedToScreen = function(self, v) self.clamped = v and true or false end
    f.IsClampedToScreen = function(self) return self.clamped or false end

    --[[ Movable, and *placed* -- two different things the client tracks
         separately. `SetUserPlaced` is what stops it putting the frame back
         where the XML says on the next load, so a drag without it works and is
         forgotten, which is indistinguishable from not working. ]]--
    f.SetMovable = function(self, v) self.movable = v and true or false end
    f.IsMovable = function(self) return self.movable or false end
    f.SetUserPlaced = function(self, v) self.userPlaced = v and true or false end
    f.IsUserPlaced = function(self) return self.userPlaced or false end

    f.SetScale = function(self, v) self.scale = v end
    f.GetScale = function(self) return self.scale end
    f.GetEffectiveScale = function(self)
        local s, p = self.scale, self.parent
        while p do s = s * (p.scale or 1); p = p.parent end
        return s
    end

    f.SetAlpha = function(self, v) self.alpha = v end
    f.GetAlpha = function(self) return self.alpha or 1 end

    f.EnableMouse = function(self, v) self.mouse = v and true or false end
    f.IsMouseEnabled = function(self) return self.mouse end

    --[[ **OnClick belongs to Button, not Frame**, and neither does
         RegisterForClicks. The auto-faking metatable answers any PascalCase
         call, so a Frame given an OnClick script looked fine here and would have
         errored the first time anyone clicked it in game -- which is how a
         click handler reached the damage meter's header bar.

         Frames get OnMouseUp and OnMouseDown; a click script on one is a
         mistake worth failing loudly for. ]]--
    local BUTTON_ONLY = { OnClick = true, OnDoubleClick = true }

    f.SetScript = function(self, which, fn)
        if BUTTON_ONLY[which] and self.frameType ~= "Button"
                and self.frameType ~= "CheckButton" then
            error(self.frameType .. " has no " .. which
                    .. " script -- that belongs to Button. Use OnMouseUp.", 2)
        end

        self.scripts[which] = fn
    end

    f.GetScript = function(self, which) return self.scripts[which] end
    f.HasScript = function() return true end

    f.RegisterForClicks = function(self)
        if self.frameType ~= "Button" and self.frameType ~= "CheckButton" then
            error(self.frameType .. " has no RegisterForClicks", 2)
        end
    end

    f.RegisterEvent = function(self, e) self.events[e] = true end
    f.UnregisterEvent = function(self, e) self.events[e] = nil end
    f.UnregisterAllEvents = function(self) self.events = {} end
    f.IsEventRegistered = function(self, e) return self.events[e] and true or false end

    --[[ **Children and regions, tracked in creation order.**

         Nothing needed these until nameplates, and nameplates need nothing else:
         a 1.12 plate has no name and no unit, so it is found by walking
         `WorldFrame:GetChildren()` and identified by what its first region is.
         Order is the whole of the identification -- `GetRegions()` answering the
         right objects in the wrong order would let a port read the level as the
         name and pass.

         Appended, never inserted, which is what the client does and what lets
         the scan look only at the new tail. ]]--
    f.children = {}
    f.regions = {}

    f.GetNumChildren = function(self) return table.getn(self.children) end
    f.GetChildren = function(self) return unpack(self.children) end
    f.GetNumRegions = function(self) return table.getn(self.regions) end
    f.GetRegions = function(self) return unpack(self.regions) end


    f.CreateTexture = function(self, tname, layer)
        local t = newTexture(self, layer)
        if tname then _G[tname] = t end
        table.insert(self.regions, t)
        return t
    end
    f.CreateFontString = function(self, fname, layer, inherits)
        local s = newFontString(self, layer, inherits)
        if fname then _G[fname] = s end
        table.insert(self.regions, s)
        return s
    end

    --[[ A status bar's own colour, which for a nameplate is not decoration: the
         client encodes hostility in it, and reading it back is the only way to
         know whether the thing on screen wants to kill you. ]]--
    f.SetStatusBarColor = function(self, r, g, b, a)
        self.barColor = { r, g, b, a }
    end

    f.GetStatusBarColor = function(self)
        if not self.barColor then return 1, 1, 1, 1 end
        return self.barColor[1], self.barColor[2], self.barColor[3], self.barColor[4]
    end

    f.SetStatusBarTexture = function(self, t) self.barTexture = t end
    f.GetStatusBarTexture = function(self) return self.barTexture end

    -- statusbar / slider value state
    f.SetMinMaxValues = function(self, lo, hi) self.min, self.max = lo, hi end
    f.GetMinMaxValues = function(self) return self.min, self.max end
    f.SetValue = function(self, v)
        self.value = v
        local fn = self.scripts.OnValueChanged
        if fn then
            local saved = this
            this = self
            fn(v)
            this = saved
        end
    end
    f.GetValue = function(self) return self.value or 0 end
    f.SetValueStep = function(self, v) self.step = v end

    -- checkbutton
    f.SetChecked = function(self, v) self.checked = v and true or false end
    f.GetChecked = function(self) return self.checked end
    f.Disable = function(self) self.enabled = false end
    f.Enable = function(self) self.enabled = true end
    f.IsEnabled = function(self) return self.enabled ~= false end

    -- editbox
    f.SetText = function(self, v) self.text = v or "" end
    f.GetText = function(self) return self.text or "" end
    f.SetAutoFocus = noop
    f.SetMaxLetters = noop
    f.ClearFocus = noop
    f.SetFocus = noop
    f.SetFont = noop
    f.SetJustifyH = noop

    -- button textures
    f.SetNormalTexture = function(self, path)
        self.normalTex = self.normalTex or newTexture(self, "ARTWORK")
        self.normalTex.texture = path
    end
    f.SetPushedTexture = function(self, path)
        self.pushedTex = self.pushedTex or newTexture(self, "ARTWORK")
        self.pushedTex.texture = path
    end
    f.SetHighlightTexture = function(self, path)
        self.highlightTex = self.highlightTex or newTexture(self, "HIGHLIGHT")
        self.highlightTex.texture = path
    end
    f.GetNormalTexture = function(self) return self.normalTex end
    f.GetPushedTexture = function(self) return self.pushedTex end
    f.GetHighlightTexture = function(self) return self.highlightTex end

    f.SetBackdrop = function(self, bd) self.backdrop = bd end
    f.GetBackdrop = function(self) return self.backdrop end

    if name then _G[name] = f end
    if parent and parent.children then table.insert(parent.children, f) end
    table.insert(frames, f)

    if template and templates[template] then templates[template](f) end
    f.template = template

    return f
end

-- ---------------------------------------------------------------------------
-- driving the fake client
-- ---------------------------------------------------------------------------

function Stub.FireEvent(name, a1, a2, a3)
    local saved, savedA1 = event, arg1
    event, arg1, arg2, arg3 = name, a1, a2, a3

    for i = 1, table.getn(frames) do
        local f = frames[i]
        if f.events[name] and f.scripts.OnEvent then
            local savedThis = this
            this = f
            f.scripts.OnEvent()
            this = savedThis
        end
    end

    event, arg1 = saved, savedA1
end

function Stub.Tick(dt, count)
    count = count or 1
    for n = 1, count do
        clock = clock + (dt or 0.05)
        for i = 1, table.getn(frames) do
            local f = frames[i]
            if f.scripts.OnUpdate and f:IsVisible() ~= false then
                local savedThis = this
                this = f
                f.scripts.OnUpdate(dt or 0.05)
                this = savedThis
            end
        end
    end
end

function Stub.Click(frame, button)
    if not frame or not frame.scripts.OnClick then return false end
    local savedThis, savedArg = this, arg1
    this, arg1 = frame, button or "LeftButton"
    frame.scripts.OnClick()
    this, arg1 = savedThis, savedArg
    return true
end

--[[ Hovering, which the client does by setting `this` and calling OnEnter --
     exactly as it does for a click. Calling the handler directly from a test
     leaves `this` at whatever it was, so the handler reads the wrong frame or
     nil: a bug in the test that looks like a bug in the addon. ]]--
function Stub.Hover(frame)
    if not frame or not frame.scripts.OnEnter then return false end
    local savedThis = this
    this = frame
    frame.scripts.OnEnter()
    this = savedThis
    return true
end

function Stub.Unhover(frame)
    if not frame or not frame.scripts.OnLeave then return false end
    local savedThis = this
    this = frame
    frame.scripts.OnLeave()
    this = savedThis
    return true
end

function Stub.MouseDown(frame, button)
    if not frame or not frame.scripts.OnMouseDown then return false end
    local savedThis, savedArg = this, arg1
    this, arg1 = frame, button or "LeftButton"
    frame.scripts.OnMouseDown()
    this, arg1 = savedThis, savedArg
    return true
end

function Stub.MouseUp(frame)
    if not frame or not frame.scripts.OnMouseUp then return false end
    local savedThis = this
    this = frame
    frame.scripts.OnMouseUp()
    this = savedThis
    return true
end

--[[ Open a dropdown and return the buttons it offered. The initialiser calls
     UIDropDownMenu_AddButton once per entry, so collecting them is how a test
     sees the menu without a real UI. ]]--
local menuButtons
function Stub.OpenMenu(drop)
    menuButtons = {}
    if drop and drop.initialize then
        local savedThis = this
        this = drop
        drop.initialize()
        this = savedThis
    end
    return menuButtons
end

-- pick an entry from the menu the way a click would
function Stub.ChooseMenu(drop, value)
    local buttons = Stub.OpenMenu(drop)
    for i = 1, table.getn(buttons) do
        if buttons[i].value == value then
            local savedThis = this
            this = buttons[i]
            buttons[i].func()
            this = savedThis
            return true
        end
    end
    return false
end

function Stub.Frames() return frames end
function Stub.SetClock(t) clock = t end
function Stub.Clock() return clock end

function Stub.UnknownMethods()
    local list = {}
    for k in pairs(unknown) do table.insert(list, k) end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------------
-- the simulated character
-- ---------------------------------------------------------------------------

Stub.player = {
    class = "ROGUE",
    localizedClass = "Rogue",
    name = "Testchar",
    level = 60,
    realm = "Turtle WoW",
    powerType = 3,
    power = 100,
    powerMax = 100,
    health = 2400,
    healthMax = 3000,
    combo = 0,
    mainSpeed = 2.6,
    offSpeed = 1.7,
    inCombat = false,
    dead = false,
    buffs = {},

    rangedSpeed = 2.9,

    -- what the target is, and how far away. hasTarget nil means none at all.
    hasTarget = false,
    targetDistance = 0,

    -- UnitStat indices: 4 intellect, 5 spirit
    stats = { [1] = 20, [2] = 20, [3] = 20, [4] = 100, [5] = 80 },

    -- GetSpellTexture by book index
    spellbook = {},

    -- spell names by book index, for the distance readout's auto-attack lookup
    spellNames = {},
    spellCount = 0,

    -- GetTalentInfo rank, keyed "tab:index"
    talents = {},
}

-- blocks of tooltip text, keyed "item<slot>" and "spell<bookIndex>"
Stub.tooltips = {}

--[[ Group units answer from Stub.group; every other token is the player.

     Modelled rather than left as "always the player", because a threat meter
     that looked up every name and got its own back would colour the whole raid
     one class and pass a test that proved nothing. ]]--
local function groupMember(unit)
    if type(unit) ~= "string" then return nil end

    local _, _, index = string.find(unit, "^%a+(%d+)$")
    if not index then return nil end

    return Stub.group and Stub.group[tonumber(index)]
end

function UnitClass(unit)
    local member = groupMember(unit)
    if member then return member.class, member.class end
    if unit == "target" and Stub.target then
        return Stub.target.class, Stub.target.class
    end
    return Stub.player.localizedClass, Stub.player.class
end

--[[ The target is answered from `Stub.target` rather than falling through to the
     player. It used to fall through, which was harmless while nothing read a
     target's name -- and the moment something did, it would have cached the
     player's own name against the target's class and looked like it worked. ]]--
function UnitName(unit)
    local member = groupMember(unit)
    if member then return member.name end
    if unit == "target" then return Stub.target and Stub.target.name end
    return Stub.player.name
end
function GetRealmName() return Stub.player.realm end
function UnitPowerType(unit) return Stub.player.powerType end
function UnitMana(unit) return Stub.player.power end
function UnitManaMax(unit) return Stub.player.powerMax end
function UnitHealth(unit) return Stub.player.health end
function UnitHealthMax(unit) return Stub.player.healthMax end
function UnitAttackSpeed(unit) return Stub.player.mainSpeed, Stub.player.offSpeed end
function UnitAffectingCombat(unit) return Stub.player.inCombat end
function UnitIsDeadOrGhost(unit) return Stub.player.dead end
function GetComboPoints() return Stub.player.combo end
function GetPlayerBuffTexture(i) return Stub.player.buffs[i + 1] end

function UnitExists(unit)
    if unit == "player" then return 1, "0xPLAYER" end

    --[[ Your target's target, which exists only when something is attacking it.
         It is the one relationship a nameplate can ask about at all -- see the
         nameplate module -- so it is modelled separately rather than folded into
         "has a target". ]]--
    if unit == "targettarget" then
        return Stub.player.targetsTarget and 1 or nil
    end

    if Stub.player.hasTarget then return 1, "0xTARGET" end
    return nil
end

--[[ Is your target attacking *you*? `UnitIsUnit("targettarget", "player")` is
     the whole of nameplate threat in vanilla, and it works for exactly one
     plate. ]]--
function UnitIsUnit(a, b)
    if a == "targettarget" and b == "player" then
        return Stub.player.targetsTarget == "player" and 1 or nil
    end

    return a == b and 1 or nil
end

--[[ Whether you could help this unit, which is how a friendly target is told
     from a hostile one without a reaction call. ]]--
function UnitCanAssist(a, b)
    if b == "target" then return Stub.player.targetFriendly and 1 or nil end
    return 1
end

function GetUnitGUID(unit)
    if unit == "player" then return "0xPLAYER" end
    if Stub.player.hasTarget then return "0xTARGET" end
    return nil
end

function UnitRangedDamage(unit)
    return Stub.player.rangedSpeed, 40, 60, 0, 0, 100
end

function UnitStat(unit, index)
    local value = Stub.player.stats[index] or 0
    return value, value, 0, 0
end

function GetTalentInfo(tab, index)
    local rank = Stub.player.talents[tab .. ":" .. index] or 0
    return "Talent", "", 1, 1, rank, 5
end

function GetSpellTabInfo(tab)
    return "Class", "", 0, Stub.player.spellCount or 0
end

function GetSpellTexture(index, bookType)
    return Stub.player.spellbook[index]
end

--[[ Spell names by book index. Separate from `spellbook`, which holds textures:
     the druid mana scrape finds Bear Form by icon because the name is localised,
     while the distance readout has to match a name because Auto Shot and Shoot
     Gun share no icon distinction it can use.

     This is how a plain client tells a hunter's Auto Shot from a warrior's Shoot
     Gun -- the two fire the same gun to different distances, and getting it wrong
     told a warrior a forty-yard target was in range. ]]--
function GetSpellName(index, bookType)
    local name = Stub.player.spellNames and Stub.player.spellNames[index]
    if not name then return nil end
    return name, ""
end

function GetLocale() return Stub.locale or "enUS" end

--[[ Whether the target can be attacked. Hostile by default, because that is what
     a HUD is looking at almost all of the time -- and because
     CheckInteractDistance answers nothing about such a unit, which is the whole
     reason this matters. ]]--
function UnitCanAttack(attacker, unit)
    if not Stub.player.hasTarget then return nil end
    if Stub.player.friendlyTarget then return nil end
    return 1
end

--[[ UnitXP SP3's line-of-sight check, which is a *third* client mod -- separate
     from SuperWoW and from Nampower, and not installed on the development
     machine. Off unless a test asks, like every other injected API. ]]--
function Stub.SetLineOfSight(present)
    Stub.losAvailable = present and true or false
end

--[[ A Nampower build extended with a line of sight query, the way this
     installation's GetUnitDistance was. Shaped to match it: one unit token, and
     a plain boolean so "cannot tell" and "blocked" stay distinguishable. ]]--
function Stub.SetNampowerSight(present)
    if not present then
        IsUnitInSight = nil
        return
    end

    IsUnitInSight = function(unit)
        if not unit or not UnitExists(unit) then return nil end
        return Stub.player.inSight ~= false
    end
end

--[[ CheckInteractDistance's real thresholds: 1 inspect ~28yd, 2 trade ~11.1yd,
     3 duel ~9.9yd, 4 follow ~28yd.

     It answers nil, never false, and answers nil for a unit that cannot be
     interacted with at all -- which a hostile mob cannot. Stub.interactRefuses
     models exactly that case, because treating it as an error rather than as
     "too far" is the mistake the range module is written to avoid. ]]--
local INTERACT_YARDS = { 28, 11.11, 9.9, 28 }

function CheckInteractDistance(unit, index)
    if not Stub.player.hasTarget then return nil end
    if Stub.interactRefuses then return nil end

    --[[ **Hostile units answer nil at every index**, because duelling, trading
         and inspecting are all things you do to a player who is not trying to
         kill you. Modelled rather than glossed over: without it the stub happily
         measured range to a mob, which is the one target a HUD spends its whole
         life pointed at -- and the addon shipped a distance readout that only
         worked on friendly targets while the suite stayed green. ]]--
    if UnitCanAttack("player", unit) then return nil end

    local limit = INTERACT_YARDS[index]
    if limit and (Stub.player.targetDistance or 0) <= limit then return 1 end
    return nil
end

-- 1 in range, 0 out of range, nil when the slot is not range checked
function IsActionInRange(slot)
    if Stub.actionRange == nil then return nil end
    return Stub.actionRange
end

--[[ What is on the bars: slot -> the name its tooltip shows. Empty by default,
     because most players do not keep their auto-attack on a bar and the addon
     has to cope with not finding it. ]]--
Stub.actionBar = {}

function HasAction(slot)
    return Stub.actionBar[slot] and 1 or nil
end

function UseAction(slot, checkCursor, onSelf)
    Stub.lastAction = slot
end

--[[ **Getting off a mount, which 1.12 does by cancelling a buff.**

     There is no `Dismount()` -- that is a 2.0 call -- and no id or reliable name
     on a 1.12 buff either, so a mount is identified by its icon and removed by
     its index. Both halves are modelled: `CancelPlayerBuff` really removes the
     texture from the list, so a test can watch somebody actually get off rather
     than only watch the call happen.

     `IsMounted` is deliberately **absent**. It exists on some private-server
     clients and not on a plain 1.12 one, and the addon has to work either way --
     a stub that always provided it would leave the texture path, which is what
     most people will actually run, never once executed. A test that wants the
     other branch defines it. ]]--
function CancelPlayerBuff(index)
    table.remove(Stub.player.buffs, index + 1)
    Stub.cancelledBuff = index
end

--[[ What an action slot's icon is, which is the only way to tell "this press is
     the mount itself" from "this press is a spell". They are the same art. ]]--
function GetActionTexture(slot)
    local action = Stub.actionBar[slot]
    if type(action) == "table" then return action.texture end
    return nil
end

Stub.castCalls = {}

function CastSpellByName(name, onSelf)
    table.insert(Stub.castCalls, name)
end

--[[ **Auto-attack, which toggles.** `AttackTarget` starts a swing if you are not
     swinging and stops one if you are -- there is no separate stop call in 1.12,
     which is why cancelling an unwanted attack means calling the same function
     again. Modelled as a toggle for that reason: a stub with separate start and
     stop would let the cancel be written the way it cannot be. ]]--
Stub.attacking = false
Stub.attackCalls = 0

function AttackTarget()
    Stub.attacking = not Stub.attacking
    Stub.attackCalls = Stub.attackCalls + 1
end

--[[ Client-mod APIs.

     None of these come from an addon: they are injected into the Lua state by a
     DLL, so on a plain install they are simply absent and there is no version or
     flag to read. Tests put them in and take them out again to drive the
     distance module down each of its backends.

     Modelling them as *togglable* rather than always-present is the point. The
     addon spent three versions believing UnitXP was on the development machine
     because another addon referenced it, and every reading came from the
     coarsest backend as a result. A stub where the good path is always available
     would reproduce that mistake rather than catch it. ]]--

-- UnitXP_SP3's command dispatcher.
function Stub.SetUnitXP(present)
    if not present then
        --[[ The stock experience API already owns this global. Handed a command
             name it reads it as a unit token, finds no such unit, and **raises a
             Lua error** -- verified in game, and this is its exact wording:

               UnitXP('inSight','player','player'):
                   ERROR Unknown unit name: inSight
               UnitXP('player'): 112473 (number)

             Both halves matter. The error is why a bare `pcall` probe cannot be
             fooled into a false positive here; the number is why a probe that
             concludes "stock" from a *successful* call is the one that can. ]]--
        UnitXP = function(unit)
            if unit ~= "player" then error("Unknown unit name: " .. tostring(unit)) end
            return Stub.player.xp or 0
        end
        return
    end

    UnitXP = function(command, a, b)
        if command == "nop" then return true end
        if command == "distanceBetween" then
            if b == "player" then return 0 end
            return Stub.player.targetDistance or 0
        end

        --[[ SP3's line-of-sight check. A separate opt-in from UnitXP itself,
             because a client can have the distance query without it -- and
             returning a number rather than a boolean is how the addon tells
             "cannot tell" from "blocked". ]]--
        if command == "inSight" then
            if not Stub.losAvailable then return 0 end
            return Stub.player.inSight ~= false
        end

        --[[ What an unrecognised command does, and the answer is "it depends on
             the build" -- which is the whole reason the addon must not probe
             here.

             SP3 is a *compatible replacement* for a global vanilla already owns,
             so a build that passes unit tokens through to the function it
             displaced is entirely reasonable. `Stub.unitXPPassthrough` models
             that build. A probe that concluded "this is the stock API" from a
             number came back saw one on this client and switched a working
             extension off. ]]--
        if Stub.unitXPPassthrough and command == "player" then
            return Stub.player.xp or 0
        end

        return nil
    end
end

--[[ World coordinates. The player sits at the origin and the target is placed
     along one axis, so the module's own three-dimensional maths has to run to
     get the distance back out -- a stub that returned the answer directly would
     not exercise it. ]]--
function Stub.SetUnitPosition(present)
    if not present then
        UnitPosition = nil
        return
    end

    --[[ Hostile targets answer nil here. This was a conservative assumption for
         several versions and is now a **verified fact**, from `/eqob rangedebug`
         against a hostile NPC on a SuperWoW client:

           UnitPosition player: -4623.379, 501.620, 36.766
           UnitPosition target: nil (nil, nil, nil)
           UnitPosition GUID:   nil (nil, nil, nil)

         Note the third line. Passing the unit's GUID rather than its token does
         **not** get round it, which was the obvious workaround and is now ruled
         out rather than untried. ]]--
    UnitPosition = function(unit)
        if unit == "player" or unit == "0xPLAYER" then return 0, 0, 0 end
        if not Stub.player.hasTarget then return nil end
        if unit == "target" and not Stub.player.friendlyTarget then return nil end
        if unit == "0xTARGET" then return nil end
        return Stub.player.targetDistance or 0, 0, 0
    end
end

--[[ Nampower: the engine's own range answers.

     Stub.spellRanges maps a spell name to { min, max }, so a test can give a
     hunter a dead zone and a wand none. IsSpellInRange returns the engine's
     boolean, computed from those same numbers, so the two can never disagree in
     a way the real client would not. ]]--
Stub.spellRanges = {}

--[[ Spells addressed by **id**, which is a different capability from addressing
     them by name and the whole basis of the range ladder.

     Verified in game. Asking by name for a spell outside your own book fails:

       Unable to determine spell id from spell name, possibly because it isn't
       in your spell book.  Try IsSpellInRange(SPELL_ID) instead

     Asking by id does not. A rogue got clean 0/1 answers for Fireball, Holy
     Light, Hammer of Justice and Hunter's Mark -- so the spellbook limit is on
     the name lookup, not on the range check.

     Two further rules come from the same run, and the ladder depends on both:

       * targeting restrictions are **not** applied. Holy Light, a heal,
         answered about a hostile mob. Any spell is therefore usable as a plain
         distance threshold regardless of who it could really be cast on.
       * the ranges are the classic vanilla numbers. Turtle has retuned none of
         the nine that were checked.

     These are the ids and ranges as the client reported them.

     Modelled the way the client stores it, in **two** tables: a short list of
     distinct min/max pairs, and spells that point at a row of it by index. That
     indirection is the whole basis of `/eqob rangescan` -- reading the rows
     answers "which bands could this client measure" without walking a single
     spell -- so a stub that collapsed the two into one could not test it. ]]--
--[[ **The real table**, as `/eqob rangescan` read it out of the client. Keyed by
     index and full of gaps, exactly as found -- index 1 is absent, and the rows
     jump from 15 to 34 and from 38 to 54. An array would have hidden that, and
     the gaps are the reason the scan walks a fixed span rather than counting.

     Two things here are worth more than the rest of the table. There **is** a
     zero-minimum 25 row, which was the open question and which closes the worst
     gap in the ladder. And there is a 0-50000 row, which is why a ladder without
     an upper cap ends up with a top band reading "100-50000y". ]]--
Stub.rangeRows = {
    [2]  = { 0, 5 },     [3]  = { 0, 20 },    [4]  = { 0, 30 },
    [5]  = { 0, 40 },    [6]  = { 0, 100 },   [7]  = { 0, 10 },
    [8]  = { 10, 20 },   [9]  = { 10, 30 },   [10] = { 10, 40 },
    [11] = { 0, 15 },    [12] = { 0, 5 },     [13] = { 0, 50000 },
    [14] = { 0, 60 },    [15] = { 0, 36 },    [34] = { 0, 25 },
    [35] = { 0, 35 },    [36] = { 0, 45 },    [37] = { 0, 50 },
    [38] = { 10, 25 },   [54] = { 5, 30 },
}

--[[ Spell ids, and every range here is the client's own. The first eight were
     guessed and confirmed; the rest the scan found by name.

     Several are not player spells. That is the point rather than a compromise:
     nothing is ever cast, the range check is arithmetic on a DBC row, and a
     spell nobody can cast measures a distance exactly as well as one anybody
     can. ]]--
Stub.spellById = {
    [2974]  = { 2,  "Wing Clip" },
    [853]   = { 7,  "Hammer of Justice" },
    [19503] = { 11, "Scatter Shot" },
    [5782]  = { 3,  "Fear" },
    [1906]  = { 34, "Debilitating Charge" },
    [116]   = { 4,  "Frostbolt" },
    [133]   = { 35, "Fireball" },
    [635]   = { 5,  "Holy Light" },
    [785]   = { 36, "True Fulfillment" },
    [15746] = { 37, "Disturb Rookery Egg" },
    [530]   = { 14, "Charm (Possess)" },
    [1130]  = { 6,  "Hunter's Mark" },

    -- absurdly long, and the reason the ladder caps itself
    [126]   = { 13, "Eye of Kilrogg" },

    --[[ A dead zone, kept so the ladder and the scan both have to prove they
         exclude it. Charge reported 8-25 when read directly, and no 8-25 row
         appeared in the scan -- so rows exist above the span it walked, which is
         why that span was widened. Modelled on the 10-25 row it did find. ]]--
    [100]   = { 38, "Charge" },
}

-- min and max for a spell id, or nil
function Stub.SpellIdRange(id)
    local spell = Stub.spellById[id]
    if not spell then return nil end

    local row = Stub.rangeRows[spell[1]]
    return row[1], row[2]
end

function Stub.SetNampower(present)
    if not present then
        GetSpellIdForName = nil
        GetSpellRecField = nil
        GetSpellRangeData = nil
        IsSpellInRange = nil
        return
    end

    --[[ Name-resolved spells get range-row indices well clear of the real rows
         above, because both live in the same index space on the client and a
         collision here would make the stub answer one lookup with the other. ]]--
    local ids, names = {}, {}
    local next = 101

    GetSpellIdForName = function(name)
        if not Stub.spellRanges[name] then return nil end
        if not ids[name] then
            ids[name] = next
            names[next] = name
            next = next + 1
        end
        return ids[name]
    end

    -- the range index is the spell id here; the indirection exists on the real
    -- client and is modelled only so the addon has to make both calls
    GetSpellRecField = function(id, field)
        local fixed = Stub.spellById[id]
        if fixed then
            if field == "name" then return fixed[2] end
            if field == "rangeIndex" then return fixed[1] end
            return nil
        end

        if field ~= "rangeIndex" then return nil end

        --[[ An id nobody has heard of resolves to nothing. Answering with the id
             itself made every number in the game look like a valid spell, which
             is the one thing a scan over thirty thousand ids must not see. ]]--
        if not names[id] then return nil end
        return id
    end

    GetSpellRangeData = function(index)
        local row = Stub.rangeRows[index]
        if row then return row[1], row[2], 0 end

        local name = names[index]
        if not name then return nil end
        local r = Stub.spellRanges[name]
        return r[1], r[2], 0, name
    end

    --[[ Takes a spell **name or id**, as Nampower's does. That matters: the
         addon has only a name unless the range-data APIs are also present, and a
         stub that insisted on an id made the whole spell backend look broken
         while the real one would have worked. ]]--
    IsSpellInRange = function(spell, unit)
        --[[ A fixed id first. No spellbook check and no targeting check: both
             were verified absent in game, and the ladder is built on their
             absence. ]]--
        local fixedMin, fixedMax = Stub.SpellIdRange(spell)
        if fixedMin then
            if not Stub.player.hasTarget then return -1 end

            local d = Stub.player.targetDistance or 0
            if d < fixedMin or d > fixedMax then return 0 end
            return 1
        end

        local name = names[spell]
        if not name and Stub.spellRanges[spell] then name = spell end
        if not name then return nil end
        if not Stub.player.hasTarget then return -1 end

        local r = Stub.spellRanges[name]
        local d = Stub.player.targetDistance or 0
        if d < r[1] then return 0 end
        if d > r[2] then return 0 end
        return 1
    end
end

-- Optional native extension proposed for Nampower. Stock 4.6.2 does not expose
-- this function even though its object manager already has both unit positions.
function Stub.SetNampowerDistance(present)
    if not present then
        GetUnitDistance = nil
        return
    end

    GetUnitDistance = function(unit)
        if unit == "player" or unit == "0xPLAYER" then return 0 end
        if not Stub.player.hasTarget then return nil end
        return Stub.player.targetDistance or 0
    end
end

-- ---------------------------------------------------------------------------
-- inventory
-- ---------------------------------------------------------------------------

--[[ What is worn, by slot number. Only the ranged slot (18) is populated, and
     only as { itemId, subtype } -- the distance module reads nothing else, and a
     fuller inventory model would be scenery. ]]--
Stub.equipped = {}

function GetInventoryItemLink(unit, slot)
    local item = Stub.equipped[slot]
    if not item then return nil end
    return "|cffffffff|Hitem:" .. item[1] .. ":0:0:0|h[Test Item]|h|r"
end

function GetInventorySlotInfo(name)
    if name == "RangedSlot" then return 18 end
    return 0
end

--[[ **Item quality colours, which the client owns and a server may extend.**

     Returned as r, g, b and the `|cff……` prefix, in that order, because the
     fourth is the one an addon building a link actually wants and the first
     three are what a texture wants. Real here because the item-link encoding
     recovers an item's rarity from its colour when the item is not in the local
     cache -- there is nothing else left to recover it from. ]]--
local QUALITY = {
    [0] = { 0.62, 0.62, 0.62, "|cff9d9d9d" },
    [1] = { 1.00, 1.00, 1.00, "|cffffffff" },
    [2] = { 0.12, 1.00, 0.00, "|cff1eff00" },
    [3] = { 0.00, 0.44, 0.87, "|cff0070dd" },
    [4] = { 0.64, 0.21, 0.93, "|cffa335ee" },
    [5] = { 1.00, 0.50, 0.00, "|cffff8000" },
    [6] = { 0.90, 0.80, 0.50, "|cffe6cc80" },
}

function GetItemQualityColor(rarity)
    local q = QUALITY[rarity] or QUALITY[1]
    return q[1], q[2], q[3], q[4]
end

--[[ **The item cache**, which is what `GetItemInfo` is really asking. An item
     the client has never seen answers nil, and that path matters as much as the
     hit: a link to something you have not encountered still has to arrive
     readable. Empty by default so the miss is what a test gets without asking
     for it. ]]--
Stub.items = {}

--[[ GetItemInfo's sixth return is the subtype, which is how the distance module
     tells a bow from a wand from a relic. The other returns are plausible
     filler; nothing reads them. ]]--
function GetItemInfo(item)
    local id = tonumber(item)
    if not id then
        local _, _, found = string.find(tostring(item), "item:(%d+)")
        id = tonumber(found)
    end
    if not id then return nil end

    for slot, entry in pairs(Stub.equipped) do
        if entry[1] == id then
            return "Test Item", "|Hitem:" .. id .. "|h", 2, 60, "Weapon", entry[2],
                    1, "Ranged", nil
        end
    end

    --[[ Anything the cache has been told about. Separate from the equipped list
         because an item you have seen in a link is not an item you are
         wearing, and the link code only ever asks the first question. ]]--
    local known = Stub.items[id]

    if known then
        return known.name, "item:" .. id .. ":0:0:0", known.rarity or 1, 60,
                "Miscellaneous", "Junk", 1, nil, nil
    end

    return nil
end

-- put a weapon of the given subtype in the ranged slot; nil empties it
function Stub.SetRanged(subtype)
    if not subtype then
        Stub.equipped[18] = nil
        return
    end
    Stub.equipped[18] = { 12345, subtype }
end

--[[ The group, as the threat meter reads it to colour a row by class. Raid
     first, party second and neither by default -- solo is the common case and
     the one where a class lookup has to come back empty rather than guessing. ]]--
Stub.group = {}

function GetNumRaidMembers() return Stub.raid and table.getn(Stub.group) or 0 end
function GetNumPartyMembers() return Stub.raid and 0 or table.getn(Stub.group) end

function Stub.SetGroup(members, raid)
    Stub.group = members or {}
    Stub.raid = raid and true or false
end

--[[ **The six rosters a name cache is built from**, each with its own argument
     order and none of them the same.

     This is the whole difficulty of PlayerNames and the reason it is four
     hundred lines upstream: `GetFriendInfo` answers name, level, class;
     `GetGuildRosterInfo` answers name, rank, rankIndex, level, class;
     `GetRaidRosterInfo` puts the subgroup third. Getting one of them wrong
     stores a rank where a class belongs and colours a name by a string no
     lookup will ever match -- silently, because an unknown class just means an
     uncoloured name, which is also what an empty roster looks like.

     So the orders are modelled exactly rather than made uniform. A stub that
     tidied them up would agree with a port that got them wrong.

     **And every one of them answers a localized class name, not a token.**
     `UnitClass` is the only call in the client that gives both; these give
     "Warrior" where the colour tables are keyed "WARRIOR". Modelled, because a
     stub that answered tokens agrees with a port that never converts -- and the
     symptom in game is an uncoloured name, which is exactly what a player
     nobody has heard of looks like. ]]--

--[[ Localized the way the client localizes it: first letter up, rest down. ]]--
local function localizedClass(token)
    if not token then return nil end
    return string.upper(string.sub(token, 1, 1)) .. string.lower(string.sub(token, 2))
end

Stub.friends = {}
Stub.guild = {}
Stub.whoResults = {}
Stub.raidRoster = {}

function GetNumFriends() return table.getn(Stub.friends) end

function GetFriendInfo(i)
    local f = Stub.friends[i]
    if not f then return nil end
    return f.name, f.level, localizedClass(f.class)
end

function GetNumGuildMembers() return table.getn(Stub.guild) end

function GetGuildRosterInfo(i)
    local g = Stub.guild[i]
    if not g then return nil end
    return g.name, g.rank or "Member", 0, g.level, localizedClass(g.class)
end

--[[ **`/who`, which is a request and an answer separated by the server.**

     `SendWho` does not return anything; the answer arrives later as
     WHO_LIST_UPDATE, and until then `GetWhoInfo` still holds the *previous*
     query's results. Modelled that way -- the sent query is recorded and the
     results are not touched -- because a stub that filled them in immediately
     would let a scanner pass while assuming an answer it cannot have yet.

     `SetWhoToUI` is a global switch, not a per-query flag. Left at 1, the next
     `/who` a player types answers into a frame they are not looking at, so what
     the stub records is the *current* state rather than a list of calls. ]]--
Stub.whoSent = {}
Stub.whoToUI = 0

function SendWho(query) table.insert(Stub.whoSent, query) end
function SetWhoToUI(value) Stub.whoToUI = value end

--[[ The answer coming back: set the results, then fire the event the way the
     client fires it. One call, because the two always happen together and a test
     that did them separately would be testing the stub. ]]--
function Stub.WhoAnswer(results)
    Stub.whoResults = results or {}

    local previous = event
    event = "WHO_LIST_UPDATE"

    local addon = EquadisClassicOverhaul
    if addon and addon.modules and addon.modules.roster then
        addon.modules.roster:OnEvent()
    end

    event = previous
end

--[[ The Who list itself, because a scan must not run while somebody is reading
     it: the query redirects results away from the interface, so scanning under
     an open Friends frame empties the list being read. ]]--
FriendsFrame = CreateFrame("Frame", "FriendsFrame", nil)
FriendsFrame:Hide()

--[[ **Channels, and specifically being put in one you did not ask for.**

     `CHAT_MSG_CHANNEL_NOTICE` is how the client announces a join, and it hands
     the name over twice: `arg9` plain, `arg4` decorated with its list position
     and the zone -- "1. General - Stormwind". Modelled with both, because the
     decorated form is the one a naive comparison fails on, and a stub that only
     supplied the plain name would agree with code that never stripped it. ]]--
Stub.channelsLeft = {}

function LeaveChannelByName(name) table.insert(Stub.channelsLeft, name) end

--[[ **A chat window's channel list, and the two calls that change it.**

     The client keeps one per window and re-adds a channel to it on every join --
     which on a server that force-joins World is every login, forever, with
     nowhere that remembers you took it out again. That is the bug the chat
     module's removal memory exists for, so both halves are modelled: a real list
     per frame, and adds and removes that really change it. ]]--
--[[ **Which chat types reopen the edit box where you left it.**

     `sticky` is a *number* in 1.12, not a boolean. Assigning `true` works by
     accident and stops the moment anything compares it to 1, so the stub holds
     what the client holds. ]]--
ChatTypeInfo = {}

for _, kind in ipairs({ "SAY", "WHISPER", "YELL", "PARTY", "GUILD", "OFFICER",
                        "RAID", "RAID_WARNING", "BATTLEGROUND", "CHANNEL",
                        "EMOTE" }) do
    ChatTypeInfo[kind] = { r = 1, g = 1, b = 1, sticky = 0 }
end

--[[ Channels by number, which is the whole difficulty: the numbers move when
     you leave one, and a colour stored against a number moves with them. ]]--
Stub.channels = {}
Stub.chatColors = {}

function GetChannelName(which)
    if type(which) == "number" then
        local name = Stub.channels[which]
        if not name then return 0 end
        return which, name
    end

    for i = 1, table.getn(Stub.channels) do
        if Stub.channels[i] == which then return i, Stub.channels[i] end
    end

    return 0
end

function ChangeChatColor(kind, r, g, b)
    Stub.chatColors[kind] = { r, g, b }
end

--[[ Every message sent, not just the last one. The link encoder is asserted by
     sending several in a row -- to a custom channel, to General, and out
     loud -- and comparing what went out each time, which one slot cannot
     hold. `chatSent` stays because older sections read it. ]]--
Stub.sent = {}

function SendChatMessage(message, kind, language, target)
    Stub.chatSent = { message = message, kind = kind, target = target }
    table.insert(Stub.sent,
            { message = message, kind = kind, target = target })
end

ChatFrameMenuButton = CreateFrame("Button", "ChatFrameMenuButton", nil)

--[[ The three buttons in a chat window's corner, which do nothing the mouse
     wheel and a right-click do not already do. ]]--
for i = 1, 7 do
    for _, which in ipairs({ "UpButton", "DownButton", "BottomButton" }) do
        CreateFrame("Button", "ChatFrame" .. i .. which, nil)
    end
end

function ChatFrame_AddChannel(frame, channel)
    if not frame or not channel then return end

    frame.channelList = frame.channelList or {}

    for i = 1, table.getn(frame.channelList) do
        if frame.channelList[i] == channel then return end
    end

    table.insert(frame.channelList, channel)
end

function ChatFrame_RemoveChannel(frame, channel)
    if not frame or not channel or not frame.channelList then return end

    for i = table.getn(frame.channelList), 1, -1 do
        if frame.channelList[i] == channel then
            table.remove(frame.channelList, i)
        end
    end
end

function Stub.JoinedChannel(number, name, zone)
    local decorated = number .. ". " .. name
    if zone then decorated = decorated .. " - " .. zone end

    local previous = { event, arg1, arg4, arg9 }
    event, arg1, arg4, arg9 = "CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", decorated, name

    local addon = EquadisClassicOverhaul
    if addon and addon.modules and addon.modules.chat then
        addon.modules.chat:OnEvent()
    end

    event, arg1, arg4, arg9 = previous[1], previous[2], previous[3], previous[4]
end

function GetNumWhoResults() return table.getn(Stub.whoResults) end

function GetWhoInfo(i)
    local w = Stub.whoResults[i]
    if not w then return nil end
    return w.name, w.guild or "", w.level, w.race or "Human", localizedClass(w.class)
end

--[[ The raid roster, which is `Stub.group` plus the subgroup number the party
     version has no room for. Kept separate so a test can put somebody in group
     three without inventing a whole raid. ]]--
function GetRaidRosterInfo(i)
    local r = Stub.raidRoster[i] or Stub.group[i]
    if not r then return nil end
    return r.name, r.rank or 0, r.subgroup or 1, r.level, localizedClass(r.class)
end

--[[ How far below you a level stops being worth colouring. The client widens
     this as you level -- nine at sixty, five at ten -- so it is asked for rather
     than assumed. ]]--
function GetQuestGreenRange() return Stub.greenRange or 5 end

function UnitLevel(unit)
    local member = groupMember(unit)
    if member then return member.level or 60 end
    if unit == "target" then return Stub.target and Stub.target.level or 60 end
    return Stub.player.level or 60
end

--[[ Target defaults to nothing, which is the state a test forgets to set up.
     Answering "yes, a friendly player" for a nil target would let the cache
     fill itself from a unit that is not there. ]]--
Stub.target = nil

function UnitIsPlayer(unit)
    if unit == "target" then return Stub.target and Stub.target.isPlayer ~= false end
    return true
end

function UnitIsFriend(a, b)
    if b == "target" then return Stub.target and Stub.target.friendly ~= false end
    return true
end

--[[ The one the client owns and every addon borrows. Real, because the meters'
     hover breakdown writes to it and a nil global would make that path throw the
     first time anybody moved a mouse -- in game, never here. ]]--
--[[ The seven chat windows, each with the AddMessage the client gives them and
     this addon hooks. Messages are kept rather than discarded: what a hook does
     to a line is the whole of what a chat module is, and a stub that swallowed
     the text could only ever check that the hook existed. ]]--
--[[ The client exposes these as globals; LuaJIT keeps them under `os` and
     `math`. Aliased rather than wrapped, because the addon calls exactly what
     1.12 calls and the behaviour is the same function either way.

     `mod` is Lua 5.0's, which the client kept as a global long after 5.1 moved
     it to the `%` operator -- so the addon uses the name the client has. ]]--
date = os.date
time = os.time
mod = math.fmod

Stub.chatFrames = {}

for i = 1, 7 do
    local f = CreateFrame("Frame", "ChatFrame" .. i, nil)
    f.lines = {}
    f.AddMessage = function(self, text) table.insert(self.lines, text or "") end

    --[[ The properties a chat module reaches in and sets. Modelled rather than
         auto-faked because GetFont answering nil makes the restore path a
         no-op, and a no-op restore looks exactly like a working one. ]]--
    f.font, f.fontSize, f.fontFlags = "Fonts/FRIZQT__.TTF", 12, nil
    f.SetFont = function(self, path, size, flags)
        self.font, self.fontSize, self.fontFlags = path, size, flags
    end
    f.GetFont = function(self) return self.font, self.fontSize, self.fontFlags end

    f.SetJustifyH = function(self, v) self.justify = v end
    f.SetFading = function(self, v) self.fading = v end
    f.SetFadeDuration = function(self, v) self.fadeDuration = v end

    --[[ **Scrollback, modelled as a position rather than a flag.**

         A ScrollingMessageFrame remembers how far up it is, and every one of
         the four scroll calls moves that number -- so a test can ask "did three
         notches of the wheel move three lines" rather than only "was ScrollUp
         called". Speed settings are the whole point of the module and a boolean
         cannot tell a fast scroll from a slow one.

         The floor is zero because that is the bottom, which is where a chat
         frame starts and where it refuses to go past. The client has no ceiling
         short of the line count, and neither does this. ]]--
    f.scrollOffset = 0
    f.maxLines = 128

    --[[ **Resizing the buffer empties it.**

         That is the client's behaviour rather than a bug in it: a new buffer
         does not carry the old one's contents. Modelled, because it is the whole
         reason ApplyScrollback has to ask before it writes -- a stub that kept
         the lines would let an unguarded call pass here and wipe somebody's chat
         on every settings change in the game. It did. ]]--
    f.SetMaxLines = function(self, n)
        self.maxLines = n
        self.lines = {}
    end

    f.GetMaxLines = function(self) return self.maxLines end

    f.ScrollUp = function(self) self.scrollOffset = self.scrollOffset + 1 end
    f.ScrollDown = function(self)
        if self.scrollOffset > 0 then
            self.scrollOffset = self.scrollOffset - 1
        end
    end

    --[[ Named for what they do rather than where they land: "top" is the oldest
         message and the largest offset, which reads backwards until you
         remember the frame counts upward from the bottom. ]]--
    f.ScrollToTop = function(self) self.scrollOffset = 999 end
    f.ScrollToBottom = function(self) self.scrollOffset = 0 end

    f.EnableMouseWheel = function(self, v) self.mouseWheel = v and true or false end
    f.IsMouseWheelEnabled = function(self) return self.mouseWheel and true or false end

    --[[ Its own number, which is how the removal memory keys what was taken out
         of which window. A chat frame with no id would file every window's
         removals under nil and undo them all together. ]]--
    f.id = i
    f.GetID = function(self) return self.id end
    f.channelList = {}

    --[[ **The tab above the window**, which is a separate frame with a separate
         name and its own visibility. Real, because the tab pass shows, hides and
         fades them -- and a nil global would make that pass do nothing while
         looking exactly like it had worked.

         `isDocked` is what decides whether a tab is a tab at all: an undocked,
         hidden window has one in the client's naming and nowhere on screen, so
         showing it would conjure a tab nobody asked for. ]]--
    local tab = CreateFrame("Button", "ChatFrame" .. i .. "Tab", f)
    f.isDocked = true

    Stub.chatFrames[i] = f
end

--[[ Which window is at the front. The client keeps this as a global pointing at
     the frame itself rather than at its number, which is why the tab pass asks
     it for its ID rather than comparing frames. ]]--
SELECTED_CHAT_FRAME = Stub.chatFrames[1]

--[[ The modifier keys, which the client answers as functions rather than
     exposing as state. Held in `Stub` so a test can set them without reaching
     into the global the addon reads. ]]--
Stub.shiftDown, Stub.ctrlDown, Stub.altDown = false, false, false

function IsShiftKeyDown() return Stub.shiftDown end
function IsControlKeyDown() return Stub.ctrlDown end
function IsAltKeyDown() return Stub.altDown end

--[[ **Blizzard's unit frames**, which the unit frame module restyles rather than
     replaces.

     Modelled with the client's own naming inconsistency intact: the player's
     border art is `PlayerFrameTexture` and the target's is
     `TargetFrameTextureFrameTexture`, and its name string is
     `TargetFrameTextureFrameName` where the player's is `PlayerName`. A stub
     that regularised those would agree with a port that assumed a pattern, and
     the failure in game is one frame silently left alone. ]]--
--[[ **The Escape menu, which is a fixed stack of buttons with no layout.**

     Every button is anchored to the one above it and the frame's height is a
     number in the XML, so inserting one means placing it, re-anchoring whatever
     was under it, and growing the frame. Modelled with the anchors real, because
     "which button is under Options" is a question the addon *asks* rather than
     knows -- a server may have added its own -- and a stub with no anchors would
     let that lookup return nothing while looking like it worked. ]]--
templates.GameMenuButtonTemplate = function(frame)
    frame:SetWidth(144)
    frame:SetHeight(21)
end

GameMenuFrame = CreateFrame("Frame", "GameMenuFrame", nil)
GameMenuFrame:SetHeight(200)

for i, name in ipairs({ "GameMenuButtonOptions", "GameMenuButtonKeybindings",
                        "GameMenuButtonMacros", "GameMenuButtonLogout",
                        "GameMenuButtonQuit" }) do
    local button = CreateFrame("Button", name, GameMenuFrame,
            "GameMenuButtonTemplate")

    if i > 1 then
        button:SetPoint("TOP", _G["GameMenuButtonOptions"], "BOTTOM", 0, -1)
    end
end

--[[ Only the button directly under Options is anchored to it; the rest chain
     from each other. Corrected here so the lookup has one answer rather than
     four -- which is what the client actually does. ]]--
_G["GameMenuButtonMacros"]:ClearAllPoints()
_G["GameMenuButtonMacros"]:SetPoint("TOP", _G["GameMenuButtonKeybindings"],
        "BOTTOM", 0, -1)
_G["GameMenuButtonLogout"]:ClearAllPoints()
_G["GameMenuButtonLogout"]:SetPoint("TOP", _G["GameMenuButtonMacros"],
        "BOTTOM", 0, -1)
_G["GameMenuButtonQuit"]:ClearAllPoints()
_G["GameMenuButtonQuit"]:SetPoint("TOP", _G["GameMenuButtonLogout"],
        "BOTTOM", 0, -1)

function HideUIPanel(frame) if frame and frame.Hide then frame:Hide() end end

Stub.reaction = 4

function UnitReaction(unit, other) return Stub.reaction end

--[[ **Targeting by name, which succeeds or quietly does not.**

     `TargetByName` is how an addon re-acquires somebody who vanished, and the
     client is noisy about failing -- it plays a sound and writes to the error
     frame. Both are real here, because the retarget helper silences them across
     the call and puts them straight back, and a stub without them would let that
     save-and-restore be written wrong.

     Nothing is targetable by default, so the failure path -- the one that has to
     forget rather than keep reaching -- is the one a test gets without asking. ]]--
Stub.targetable = {}

function TargetByName(name, exact)
    if Stub.targetable[name] then
        Stub.player.hasTarget = true
        Stub.target = Stub.targetable[name]
        return
    end

    --[[ Failed. The client says so out loud, which is exactly what the caller
         is silencing. ]]--
    if PlaySound then PlaySound("igQuestFailed") end
    if UIErrorsFrame_OnEvent then UIErrorsFrame_OnEvent() end
end

function UIErrorsFrame_OnEvent() Stub.lastUIError = true end
function SetPortraitTexture(texture, unit) texture.portraitOf = unit end

for _, frame in ipairs({
    { "PlayerFrame", "PlayerFrameHealthBar", "PlayerFrameManaBar",
      "PlayerName", "PlayerPortrait", "PlayerFrameTexture" },
    { "TargetFrame", "TargetFrameHealthBar", "TargetFrameManaBar",
      "TargetFrameTextureFrameName", "TargetPortrait",
      "TargetFrameTextureFrameTexture" },
    { "TargetofTargetFrame", "TargetofTargetHealthBar", "TargetofTargetManaBar",
      "TargetofTargetName", "TargetofTargetPortrait", "TargetofTargetFrameTexture" },
    { "PetFrame", "PetFrameHealthBar", "PetFrameManaBar",
      "PetName", "PetPortrait", "PetFrameTexture" },
}) do
    local parent = CreateFrame("Frame", frame[1], nil)

    for i, bar in ipairs({ frame[2], frame[3] }) do
        local b = CreateFrame("StatusBar", bar, parent)
        b.frameType = "StatusBar"
        _G[bar .. "Text"] = newFontString(b, "OVERLAY", "GameFontNormalSmall")

        --[[ The client reaches its own text through `bar.TextString` and its
             own bars through `frame.healthbar` / `frame.manabar`, not through
             the global names. Both spellings are real, and a stub with only the
             globals lets a replacement of `TextStatusBar_UpdateTextString` be
             written against a field that is never there. ]]--
        b.TextString = _G[bar .. "Text"]
        b.textLockable = 1
        b.lockShow = 0
        b:SetMinMaxValues(0, 100)
        b:SetValue(100)

        if i == 1 then parent.healthbar = b else parent.manabar = b end
    end

    _G[frame[4]] = newFontString(parent, "OVERLAY", "GameFontNormal")
    _G[frame[5]] = parent:CreateTexture(frame[5], "ARTWORK")
    _G[frame[6]] = parent:CreateTexture(frame[6], "OVERLAY")
end

--[[ The target frame's backing plate, which compact mode shortens. Real,
     because the compact layout is sizes rather than a replacement texture and a
     missing frame would make that pass do nothing while looking like it
     worked. ]]--
CreateFrame("Frame", "TargetFrameBackground", _G["TargetFrame"])

--[[ **The client's own status text machinery, which is the thing a unit frame
     addon is actually fighting.**

     `TextStatusBar_UpdateTextString` is Blizzard's, it owns every one of these
     strings, and it runs on the bar's own `OnValueChanged` -- so it fires after
     any event handler that took damage as its cue. An addon that writes the text
     on an event and stops there has its text overwritten a frame later, which
     looks exactly like a setting that does nothing.

     Worse, the client *hides* the string unless the `statusBarText` CVar is on
     or the bar is `lockShow`n. Off by default, as it is in the client, because
     that is the case where the port's own text never appears at all.

     Modelled here rather than left out, because a stub without it agrees with
     the assumption that writing the text once is enough. The CVar itself is set
     with the others, further down -- the table does not exist yet here. ]]--

function TextStatusBar_UpdateTextString(bar)
    bar = bar or this
    if not bar then return end

    local string = bar.TextString
    if not string then return end

    local value = bar:GetValue()
    local _, valueMax = bar:GetMinMaxValues()

    if valueMax and valueMax > 0 then
        bar:Show()

        if value == 0 and bar.zeroText then
            string:SetText(bar.zeroText)
            bar.isZero = 1
            string:Show()
        else
            bar.isZero = nil
            string:SetText(value .. "/" .. valueMax)

            if GetCVar("statusBarText") == "1" and bar.textLockable then
                string:Show()
            elseif (bar.lockShow or 0) > 0 then
                string:Show()
            else
                string:Hide()
            end
        end
    else
        bar:Hide()
    end
end

--[[ **And the colour, which the client rewrites just as often.**

     `HealthBar_OnValueChanged` paints every health bar green -- or red-to-green
     if the bar asked for smoothing -- on every value change. A module that sets
     a bar's colour on an event and stops there gets one frame of its own colour
     and then Blizzard's.

     This is why the addon this is ported from replaces the function outright
     rather than calling `SetStatusBarColor` from the outside. ]]--
function HealthBar_OnValueChanged(value, smooth)
    local bar = this
    if not bar then return end
    if not value then return end

    local min, max = bar:GetMinMaxValues()
    if not min or not max then return end
    if value < min or value > max then return end

    if max - min > 0 then value = (value - min) / (max - min) else value = 0 end

    local r, g = 0, 1

    if smooth then
        if value > 0.5 then r, g = (1 - value) * 2, 1 else r, g = 1, value * 2 end
    end

    bar:SetStatusBarColor(r, g, 0)
end

--[[ The pet's per-frame update, which is where the original does its pet work.
     Real because the module replaces it, and a replacement of something that
     does not exist is a silent no-op. ]]--
function CombatFeedback_OnUpdate(elapsed) Stub.combatFeedbackRan = true end
function PetFrame_OnUpdate(elapsed) CombatFeedback_OnUpdate(elapsed) end

--[[ The target frame's border, redrawn whenever the target's classification
     changes -- elite, rare, world boss. Replaced by the module for dark
     mode. ]]--
function TargetFrame_CheckClassification() Stub.classificationChecked = true end

Stub.classification = "normal"
function UnitClassification(unit) return Stub.classification end

Stub.petHappiness = 3
function GetPetHappiness() return Stub.petHappiness, 100, 0 end

--[[ The pieces the original touches by name: the combat glow behind the player
     portrait, the pet's attack flash, its happiness meter, and the plate behind
     the target's name that compact mode hides. ]]--
PlayerStatusTexture = _G["PlayerFrame"]:CreateTexture("PlayerStatusTexture", "OVERLAY")
PetAttackModeTexture = _G["PetFrame"]:CreateTexture("PetAttackModeTexture", "OVERLAY")
PetFrameHappiness = _G["PetFrame"]:CreateTexture("PetFrameHappiness", "OVERLAY")
TargetFrameNameBackground = _G["TargetFrame"]:CreateTexture("TargetFrameNameBackground", "ARTWORK")
TargetDeadText = newFontString(_G["TargetFrame"], "OVERLAY", "GameFontNormal")
_G["TargetDeadText"] = TargetDeadText

for i = 1, 4 do
    local name = "PartyMemberFrame" .. i
    local parent = CreateFrame("Frame", name, nil)

    for j, suffix in ipairs({ "HealthBar", "ManaBar" }) do
        local b = CreateFrame("StatusBar", name .. suffix, parent)
        b.frameType = "StatusBar"
        _G[name .. suffix .. "Text"] =
                newFontString(b, "OVERLAY", "GameFontNormalSmall")

        b.TextString = _G[name .. suffix .. "Text"]
        b.textLockable = 1
        b.lockShow = 0
        b:SetMinMaxValues(0, 100)
        b:SetValue(100)

        if j == 1 then parent.healthbar = b else parent.manabar = b end
    end

    _G[name .. "Name"] = newFontString(parent, "OVERLAY", "GameFontNormal")
    _G[name .. "Portrait"] = parent:CreateTexture(name .. "Portrait", "ARTWORK")
end

--[[ **Blizzard's action bars**, which are the frames the action bar module moves
     rather than anything it makes.

     Every button is real, with the two font strings the client puts on it --
     `<name>HotKey` and `<name>Name` -- because restyling those is half the
     module, and a stub without them would let the whole text pass run against
     nothing and report success.

     The families and their counts are the client's: twelve for every action bar,
     ten for the pet and stance bars. Getting that wrong here would hide a module
     that laid out ten stance buttons as if there were twelve. ]]--
--[[ **Bindings, modelled in both directions.**

     `GetBindingKey(command)` answers the key and `GetBindingAction(key)` answers
     the command, and bind mode needs both -- the second is how it can say what a
     key was taken *from*, which is the thing the client never tells you.

     Kept as two tables that are maintained together, because that is what the
     client does and because a stub with one of them would let the "taken from"
     line be written and never checked. ]]--
Stub.bindings = {}
Stub.boundTo = {}
Stub.bindingsSaved = 0

function GetBindingKey(command) return Stub.bindings[command] end
function GetBindingAction(key) return Stub.boundTo[key] end

function SetBinding(key, command)
    --[[ A key already held by something else changes hands, which is exactly the
         case bind mode warns about. Modelled, or the warning could not be
         tested. ]]--
    local previous = Stub.boundTo[key]
    if previous then Stub.bindings[previous] = nil end

    if command then
        Stub.boundTo[key] = command
        Stub.bindings[command] = key
    else
        Stub.boundTo[key] = nil
    end

    return 1
end

function SaveBindings(which) Stub.bindingsSaved = Stub.bindingsSaved + 1 end
function GetCurrentBindingSet() return 1 end
function CloseAllWindows() Stub.windowsClosed = true end

--[[ Which frame the mouse is over, by geometry rather than by focus -- which is
     how the addon has to ask it, because its own capture frame owns the mouse
     while bind mode is on. ]]--
Stub.mouseOver = nil

function MouseIsOver(frame) return Stub.mouseOver == frame end


--[[ The bar frames and their art. Real, because the module hides the art and
     switches the mouse off -- and a nil global would make that pass do nothing
     while looking exactly like it had worked. ]]--
for _, name in ipairs({ "MainMenuBar", "MainMenuBarArtFrame", "PetActionBarFrame",
                        "BonusActionBarFrame", "ShapeshiftBarFrame",
                        "MultiBarBottomLeft", "MultiBarBottomRight",
                        "MultiBarLeft", "MultiBarRight" }) do
    CreateFrame("Frame", name, nil)
end

--[[ **Every action button is a child of Blizzard's own bar frame**, which is the
     fact the whole layout pass turns on and which this stub used to leave out.

     A child inherits its parent's visibility. So hiding `PetActionBarFrame` to
     get rid of its art hides all ten pet buttons with it, and moving a button by
     `SetPoint` alone leaves it inheriting the alpha, scale and *position
     management* of a frame the client is still moving around. Parented to
     nothing, as they were here, none of that could happen and a port that only
     ever called `SetPoint` looked correct. ]]--
local BUTTON_PARENT = {
    ActionButton = "MainMenuBarArtFrame",
    BonusActionButton = "BonusActionBarFrame",
    MultiBarBottomLeftButton = "MultiBarBottomLeft",
    MultiBarBottomRightButton = "MultiBarBottomRight",
    MultiBarRightButton = "MultiBarRight",
    MultiBarLeftButton = "MultiBarLeft",
    ShapeshiftButton = "ShapeshiftBarFrame",
    PetActionButton = "PetActionBarFrame",
}

for _, family in ipairs({ { "ActionButton", 12 }, { "BonusActionButton", 12 },
                          { "MultiBarBottomLeftButton", 12 },
                          { "MultiBarBottomRightButton", 12 },
                          { "MultiBarRightButton", 12 },
                          { "MultiBarLeftButton", 12 },
                          { "ShapeshiftButton", 10 },
                          { "PetActionButton", 10 } }) do
    for i = 1, family[2] do
        local button = CreateFrame("Button", family[1] .. i,
                _G[BUTTON_PARENT[family[1]]])

        button:SetWidth(36)
        button:SetHeight(36)

        _G[family[1] .. i .. "HotKey"] =
                newFontString(button, "OVERLAY", "GameFontNormalSmall")
        _G[family[1] .. i .. "Name"] =
                newFontString(button, "OVERLAY", "GameFontNormalSmall")
    end
end

--[[ **The client rewrites its own keybind text, and often.**

     `ActionButton_UpdateHotkeys` runs from `ActionButton_Update` -- every time a
     spell is dragged onto a bar, every time a binding changes, and on entering
     the world -- and it writes the binding out in full. An addon that shortens
     that text once has it lengthened again on the next spell drag.

     Same shape as the unit frame text problem, and modelled for the same reason:
     without it the stub agrees that shortening once is enough. ]]--
function GetBindingText(key, prefix, returnAbbr)
    if not key or key == "" then return "" end
    return key
end

function ActionButton_UpdateHotkeys(button, buttonType)
    button = button or this
    if not button or not button.GetName then return end

    local hotkey = _G[(button:GetName() or "") .. "HotKey"]
    if not hotkey then return end

    local command = Stub.buttonCommand and Stub.buttonCommand[button:GetName()]
    local key = command and GetBindingKey(command)

    hotkey:SetText(key and GetBindingText(key) or "")
end

for _, name in ipairs({ "MainMenuBarTexture0", "MainMenuBarTexture1",
                        "MainMenuBarTexture2", "MainMenuBarTexture3",
                        "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
                        "SlidingActionBarTexture0", "SlidingActionBarTexture1",
                        "BonusActionBarTexture0", "BonusActionBarTexture1",
                        "ShapeshiftBarLeft", "ShapeshiftBarMiddle",
                        "ShapeshiftBarRight" }) do
    _G[name] = CreateFrame("Frame", nil, nil):CreateTexture(name, "ARTWORK")

    --[[ **With a texture already on it**, because the client's art has one and
         that is the whole reason hiding it must not be done by clearing it: the
         path is the client's and an addon that nils it cannot put it back. A
         stub whose art started blank could not tell the two apart. ]]--
    _G[name]:SetTexture("BlizzardArtFor-" .. name)
end

--[[ **The quest frames**, which in 1.12 are three windows and one conversation.

     Accept, then "have you brought it", then the reward -- each its own event
     with its own button, and the title text is the only thing that identifies
     the quest across all three. There is no quest id in this API.

     `Stub.quest` is what the window is showing. The calls that push it forward
     record themselves rather than advancing it, because what is worth asserting
     is which button was pressed, not a state machine written here. ]]--
Stub.quest = { title = "", completable = true, choices = 0 }
Stub.questCalls = {}

function GetTitleText() return Stub.quest.title end
function IsQuestCompletable() return Stub.quest.completable end
function GetNumQuestChoices() return Stub.quest.choices or 0 end

function AcceptQuest() table.insert(Stub.questCalls, "accept") end
function CompleteQuest() table.insert(Stub.questCalls, "complete") end
function GetQuestReward() table.insert(Stub.questCalls, "reward") end

--[[ An NPC's quest list, which 1.12 answers as one flat run of title, level,
     title, level. Modelled flat rather than as a list of records, because
     pulling the titles back out of that run is the part that can be got wrong. ]]--
Stub.gossipAvailable = {}
Stub.gossipActive = {}
Stub.gossipPicked = nil

local function flatten(quests)
    local out = {}

    for i = 1, table.getn(quests) do
        table.insert(out, quests[i])
        table.insert(out, 60)
    end

    return unpack(out)
end

function GetGossipAvailableQuests() return flatten(Stub.gossipAvailable) end
function GetGossipActiveQuests() return flatten(Stub.gossipActive) end

function SelectGossipAvailableQuest(i)
    Stub.gossipPicked = { kind = "available", index = i }
end

function SelectGossipActiveQuest(i)
    Stub.gossipPicked = { kind = "active", index = i }
end

--[[ The other kind of NPC menu: no gossip text, just a list, and four different
     calls to read the same two lists with. ]]--
function GetNumAvailableQuests() return table.getn(Stub.gossipAvailable) end
function GetAvailableTitle(i) return Stub.gossipAvailable[i] end
function GetNumActiveQuests() return table.getn(Stub.gossipActive) end
function GetActiveTitle(i) return Stub.gossipActive[i] end

function SelectAvailableQuest(i)
    Stub.gossipPicked = { kind = "available", index = i }
end

function SelectActiveQuest(i)
    Stub.gossipPicked = { kind = "active", index = i }
end

--[[ **Turning the wheel**, which is three pieces of client state at once: the
     frame's handler, the modifier keys, and `arg1` carrying the direction.

     `arg1` is a global in 1.12 -- the client sets it before calling the handler
     and the handler reads it off the environment -- so the stub sets it the same
     way rather than passing it in. A handler written to take it as a parameter
     would pass here and read nil in the game. ]]--
function Stub.Wheel(index, direction, modifier)
    local frame = Stub.chatFrames[index]
    local handler = frame:GetScript("OnMouseWheel")

    if not frame:IsMouseWheelEnabled() then return end
    if not handler then return end

    Stub.shiftDown = (modifier == "SHIFT")
    Stub.ctrlDown = (modifier == "CTRL")

    local previousThis, previousArg = this, arg1
    this, arg1 = frame, direction

    handler()

    this, arg1 = previousThis, previousArg
    Stub.shiftDown, Stub.ctrlDown = false, false
end

--[[ Server time, which 1.12 gives as hours and minutes and no seconds at all --
     the reason the chat module has to recover a second hand by watching the
     minute roll over. ]]--
--[[ The client's channel-group tables, which ChannelSeparator rewrites. Real
     tables because the module saves and restores them, and a restore that put
     back a fabricated table would pass while losing the client's own. ]]--
--[[ The format strings the client builds every chat line from. Real values,
     because the chat module saves them before overwriting and a saved nil
     restores as nil -- which blanks a channel's label rather than restoring it.
     `%s` is the speaker, substituted by the client. ]]--
CHAT_GUILD_GET = "|Hchannel:Guild|h[Guild]|h %s: "
CHAT_OFFICER_GET = "|Hchannel:o|h[Officer]|h %s: "
CHAT_PARTY_GET = "|Hchannel:party|h[Party]|h %s: "
CHAT_RAID_GET = "|Hchannel:raid|h[Raid]|h %s: "
CHAT_RAID_LEADER_GET = "|Hchannel:raid|h[Raid Leader]|h %s: "
CHAT_RAID_WARNING_GET = "[Raid Warning] %s: "
CHAT_SAY_GET = "%s says: "
CHAT_YELL_GET = "%s yells: "
CHAT_WHISPER_GET = "%s whispers: "
CHAT_WHISPER_INFORM_GET = "To %s: "

ChatTypeGroup = { GUILD = { "CHAT_MSG_GUILD" }, RAID = { "CHAT_MSG_RAID" } }
--[[ **Which message groups the chat settings offer**, and the client's list is
     longer than the obvious ones.

     Modelled with entries outside the five the separator touches -- loot, system
     messages, creature emotes -- because that is where the bug lived: replacing
     this table with a hardcoded list of the obvious groups makes every other one
     unselectable and drops it from what the client saves.

     A stub carrying only the five would have agreed with the code that replaced
     them, and the loss would have been invisible. ]]--
ChannelMenuChatTypeGroups = {
    "SAY", "YELL", "GUILD", "OFFICER", "WHISPER", "PARTY", "RAID",
    "BATTLEGROUND", "LOOT", "SYSTEM", "MONSTER_SAY", "SKILL",
}

Stub.gameTime = { hour = 12, minute = 30 }

function GetGameTime() return Stub.gameTime.hour, Stub.gameTime.minute end

GameTooltip = CreateFrame("GameTooltip", "GameTooltip", nil,
        "GameTooltipTemplate")

--[[ Addon messages the addon sends. Recorded rather than delivered: what is
     worth asserting is that the request went out, on the right channel, with
     the right payload -- the reply is the server's business. ]]--
Stub.addonSent = {}

function SendAddonMessage(prefix, message, channel)
    table.insert(Stub.addonSent, { prefix = prefix, message = message,
                                   channel = channel })
end

--[[ **Console variables**, which are the client's own settings and are global,
     persistent and shared with every other addon.

     Seeded with the defaults that matter rather than left empty, so a module
     that reads one before writing it gets a number instead of nil -- which is
     what happens in game, and is the difference between a slider that starts
     where the client is and one that starts at zero. ]]--
Stub.cvars = {
    cameraYawMoveSpeed = "180",

    --[[ **Off, as it is in the client.** This is the switch that decides whether
         Blizzard shows the numbers on a unit frame bar at all, and with it off
         `TextStatusBar_UpdateTextString` hides every string it writes. A stub
         that shipped it on would hide the case where a port's text is written
         correctly and then never seen. ]]--
    statusBarText = "0",
}

function SetCVar(name, value) Stub.cvars[name] = tostring(value) end
function GetCVar(name) return Stub.cvars[name] end

--[[ **Bags, and the one call that means two completely different things.**

     `UseContainerItem` sells an item while a merchant window is open and *uses*
     it everywhere else -- eats the food, opens the lockbox, equips the weapon.
     Modelled with that split intact rather than as a "sell" function, because a
     stub that only ever sold would agree with code that forgot to check the
     window was open, and the failure in game is a bag of used items.

     Bags 0 to 4: the backpack and four bags, which is every bag 1.12 has. ]]--
Stub.bags = {}
Stub.used = {}
Stub.sold = {}

--[[ Quality colours as the client defines them. Only poor matters here, and it
     matters exactly: the junk sweep recognises an item by the colour its link
     starts with. ]]--
ITEM_QUALITY_COLORS = {
    [0] = { r = 0.55, g = 0.55, b = 0.55, hex = "|cff9d9d9d" },
    [1] = { r = 1.00, g = 1.00, b = 1.00, hex = "|cffffffff" },
    [2] = { r = 0.12, g = 1.00, b = 0.00, hex = "|cff1eff00" },
    [3] = { r = 0.00, g = 0.44, b = 0.87, hex = "|cff0070dd" },
    [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee" },
}

--[[ A link, spelled the way the client spells one: quality colour, item id,
     bracketed name, terminator. The sweep reads the colour off the front and the
     name out of the brackets, so both have to be in the right places. ]]--
function Stub.ItemLink(name, quality)
    local hex = ITEM_QUALITY_COLORS[quality or 0].hex
    return hex .. "|Hitem:1234:0:0:0|h[" .. name .. "]|h|r"
end

function Stub.SetBag(bag, items)
    Stub.bags[bag] = items
end

function GetContainerNumSlots(bag)
    local b = Stub.bags[bag]
    if not b then return 0 end
    return b.slots or table.getn(b)
end

function GetContainerItemLink(bag, slot)
    local b = Stub.bags[bag]
    local item = b and b[slot]
    if not item then return nil end

    return Stub.ItemLink(item.name, item.quality)
end

--[[ Texture, count, locked -- and no price, which is the whole difficulty of
     "destroy cheap junk". 1.12 has no call that answers what an item sells for. ]]--
function GetContainerItemInfo(bag, slot)
    local b = Stub.bags[bag]
    local item = b and b[slot]
    if not item then return nil end

    return "Interface\\Icons\\INV_Misc_Bone_01", item.count or 1, nil
end

function UseContainerItem(bag, slot)
    local b = Stub.bags[bag]
    local item = b and b[slot]
    if not item then return end

    if MerchantFrame and MerchantFrame:IsVisible() then
        table.insert(Stub.sold, item.name)
    else
        table.insert(Stub.used, item.name)
    end
end

--[[ **Destroying an item, which in 1.12 is two calls and a cursor.**

     There is no `DeleteItem(bag, slot)`. You pick the item up and then delete
     what you are holding, which means the cursor is a real piece of state
     between the two -- and `PickupContainerItem` onto an occupied cursor
     *swaps*, putting what you held into the bag and picking up the item.

     Modelled with that swap intact. A stub whose pickup simply overwrote the
     cursor would agree with code that deleted the wrong thing, and the wrong
     thing here is whatever the player happened to be dragging. ]]--
Stub.cursor = nil
Stub.destroyed = {}

function CursorHasItem() return Stub.cursor ~= nil end
function ClearCursor() Stub.cursor = nil end

function PickupContainerItem(bag, slot)
    local b = Stub.bags[bag]
    local item = b and b[slot]

    local held = Stub.cursor
    Stub.cursor = item

    -- the swap: what was on the cursor lands in the slot it came from
    if b then b[slot] = held end
end

function DeleteCursorItem()
    if not Stub.cursor then return end

    table.insert(Stub.destroyed, Stub.cursor.name)
    Stub.cursor = nil
end

--[[ The merchant, and repairing at one. `GetRepairAllCost` answers copper and
     whether there is anything to repair; `RepairAllItems` takes the money. The
     money is really taken, so a test can assert that a repair somebody could not
     afford did not happen to their purse. ]]--
MerchantFrame = CreateFrame("Frame", "MerchantFrame", nil)
MerchantFrame:Hide()

Stub.money = 1000000
Stub.repairCost = 0
Stub.canRepair = true
Stub.repaired = 0

function GetMoney() return Stub.money end
function CanMerchantRepair() return Stub.canRepair end
function GetRepairAllCost() return Stub.repairCost, Stub.repairCost > 0 end

function RepairAllItems()
    Stub.money = Stub.money - Stub.repairCost
    Stub.repaired = Stub.repaired + 1
    Stub.repairCost = 0
end

function GetScreenWidth() return 1024 end
function GetScreenHeight() return 768 end

function GetTime() return clock end
function GetCursorPosition() return Stub.cursorX or 0, Stub.cursorY or 0 end
function PlaySound(name) Stub.lastSound = name end
function IsAddOnLoaded(name) return Stub.loadedAddons and Stub.loadedAddons[name] end

-- ---------------------------------------------------------------------------
-- globals the client provides
-- ---------------------------------------------------------------------------

_G = _G or getfenv(0)

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

--[[ The refusal strings, exactly as 1.12's GlobalStrings.lua spells them.
     `SPELL_FAILED_LINE_OF_SIGHT` is the one the client puts on screen and passes
     as UI_ERROR_MESSAGE's arg1; the other two do not exist in 1.12 and are left
     undefined on purpose, so anything that reads them has to cope with nil the
     way it must in game. ]]--
SPELL_FAILED_LINE_OF_SIGHT = "Target not in line of sight"

--[[ **The sentences a cast is announced with**, exactly as 1.12's
     GlobalStrings.lua spells them.

     These are the only notice a vanilla client gives that anything other than
     the player has begun casting -- there is no UnitCastingInfo until 2.0 -- so
     they are the entire input to the cast library, and they have to be right
     here rather than approximated for the reason every other global string in
     this file is: a stub with a subtly different sentence exercises a pattern the
     real client never produces. ]]--
SPELLCASTOTHERSTART = "%s begins to cast %s."
SPELLPERFORMOTHERSTART = "%s begins to perform %s."

--[[ The combat log sentences, exactly as 1.12's GlobalStrings.lua spells them.

     These are the parser's entire input. It never matches English -- it turns
     *these* into patterns, so whatever the client says is what it reads -- and
     that is precisely why they have to be right here rather than approximated:
     a stub with a subtly different sentence would exercise a pattern the real
     client never produces.

     `%2$s` in RESIST_TRAILER is not a typo. Reordering indices are the thing
     `captures` exists to handle, so at least one string carrying them earns its
     place. ]]--
COMBATHITSELFOTHER = "You hit %s for %d."
COMBATHITCRITSELFOTHER = "You crit %s for %d."
COMBATHITSCHOOLSELFOTHER = "You hit %s for %d %s damage."
COMBATHITCRITSCHOOLSELFOTHER = "You crit %s for %d %s damage."

COMBATHITOTHERSELF = "%s hits you for %d."
COMBATHITCRITOTHERSELF = "%s crits you for %d."
COMBATHITSCHOOLOTHERSELF = "%s hits you for %d %s damage."
COMBATHITCRITSCHOOLOTHERSELF = "%s crits you for %d %s damage."

COMBATHITOTHEROTHER = "%s hits %s for %d."
COMBATHITCRITOTHEROTHER = "%s crits %s for %d."
COMBATHITSCHOOLOTHEROTHER = "%s hits %s for %d %s damage."
COMBATHITCRITSCHOOLOTHEROTHER = "%s crits %s for %d %s damage."

SPELLLOGSELFOTHER = "Your %s hits %s for %d."
SPELLLOGCRITSELFOTHER = "Your %s crits %s for %d."
SPELLLOGSCHOOLSELFOTHER = "Your %s hits %s for %d %s damage."
SPELLLOGCRITSCHOOLSELFOTHER = "Your %s crits %s for %d %s damage."

SPELLLOGSELFSELF = "Your %s hits you for %d."
SPELLLOGCRITSELFSELF = "Your %s crits you for %d."
SPELLLOGSCHOOLSELFSELF = "Your %s hits you for %d %s damage."
SPELLLOGCRITSCHOOLSELFSELF = "Your %s crits you for %d %s damage."

SPELLLOGOTHERSELF = "%s's %s hits you for %d."
SPELLLOGCRITOTHERSELF = "%s's %s crits you for %d."
SPELLLOGSCHOOLOTHERSELF = "%s's %s hits you for %d %s damage."
SPELLLOGCRITSCHOOLOTHERSELF = "%s's %s crits you for %d %s damage."

SPELLLOGOTHEROTHER = "%s's %s hits %s for %d."
SPELLLOGCRITOTHEROTHER = "%s's %s crits %s for %d."
SPELLLOGSCHOOLOTHEROTHER = "%s's %s hits %s for %d %s damage."
SPELLLOGCRITSCHOOLOTHEROTHER = "%s's %s crits %s for %d %s damage."

PERIODICAURADAMAGESELFOTHER = "%s suffers %d %s damage from your %s."
PERIODICAURADAMAGESELFSELF = "You suffer %d %s damage from your %s."
PERIODICAURADAMAGEOTHERSELF = "You suffer %d %s damage from %s's %s."
PERIODICAURADAMAGEOTHEROTHER = "%s suffers %d %s damage from %s's %s."

DAMAGESHIELDSELFOTHER = "You reflect %d %s damage to %s."
DAMAGESHIELDOTHERSELF = "%s reflects %d %s damage to you."
DAMAGESHIELDOTHEROTHER = "%s reflects %d %s damage to %s."

HEALEDSELFSELF = "Your %s heals you for %d."
HEALEDCRITSELFSELF = "Your %s critically heals you for %d."
HEALEDSELFOTHER = "Your %s heals %s for %d."
HEALEDCRITSELFOTHER = "Your %s critically heals %s for %d."

HEALEDOTHERSELF = "%s's %s heals you for %d."
HEALEDCRITOTHERSELF = "%s's %s critically heals you for %d."
HEALEDOTHEROTHER = "%s's %s heals %s for %d."
HEALEDCRITOTHEROTHER = "%s's %s critically heals %s for %d."

PERIODICAURAHEALSELFSELF = "You gain %d health from %s."
PERIODICAURAHEALSELFOTHER = "%s gains %d health from your %s."
PERIODICAURAHEALOTHERSELF = "You gain %d health from %s's %s."
PERIODICAURAHEALOTHEROTHER = "%s gains %d health from %s's %s."

ABSORB_TRAILER = " (%d absorbed)"
RESIST_TRAILER = " (%d resisted)"

-- `UnitXP` is set up by Stub.SetUnitXP, which models both the stock experience
-- API and UnitXP_SP3's dispatcher. See the note there.

RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

Stub.chat = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(self, msg) table.insert(Stub.chat, msg) end,
}

function getglobal(name) return _G[name] end
function setglobal(name, v) _G[name] = v end
tinsert = table.insert
tremove = table.remove

UISpecialFrames = {}
SlashCmdList = {}

--[[ **What the Key Bindings panel can actually do**, which is what a chat
     command bound to a binding ends up calling.

     Recorded rather than simulated: there is no character to sit down, and what
     is worth asserting is that the right call was made. Each one records itself
     so a command can be traced end to end -- typed word, stored action, client
     API.

     **`RunBinding` is deliberately absent.** Vanilla has no way to invoke a
     binding by name; later clients grew one and some private servers back-port
     it. A stub that shipped it would let the fallback table -- the path almost
     every 1.12 player is actually on -- go untested. `Stub.runBinding` turns it
     on for the test that checks the other branch. ]]--
Stub.ran = {}

local function records(name)
    return function(arg)
        table.insert(Stub.ran, name)
        Stub.lastRan = name
        Stub.lastRanArg = arg
    end
end

ToggleRun = records("ToggleRun")
ToggleAutoRun = records("ToggleAutoRun")
ToggleSheath = records("ToggleSheath")
JumpOrAscendStart = records("JumpOrAscendStart")
Dismount = records("Dismount")
Screenshot = records("Screenshot")
Sound_ToggleMusic = records("Sound_ToggleMusic")
Sound_ToggleSound = records("Sound_ToggleSound")
--[[ **The framerate readout, which toggles rather than sets.** The client
     exposes no way to ask for it *on* -- only to flip it -- so an addon that
     wants it shown has to read the frame first and flip only if it is not.
     Modelled with a real frame for exactly that: a stub that only recorded the
     call could not tell "turned it on" from "turned it off". ]]--
FramerateFrame = CreateFrame("Frame", "FramerateFrame", UIParent)
FramerateFrame:Hide()

function ToggleFramerate()
    table.insert(Stub.ran, "ToggleFramerate")
    Stub.lastRan = "ToggleFramerate"

    if FramerateFrame:IsShown() then
        FramerateFrame:Hide()
    else
        FramerateFrame:Show()
    end
end
ToggleBackpack = records("ToggleBackpack")
OpenAllBags = records("OpenAllBags")
ToggleWorldMap = records("ToggleWorldMap")
ToggleQuestLog = records("ToggleQuestLog")
ToggleTalentFrame = records("ToggleTalentFrame")
ToggleFriendsFrame = records("ToggleFriendsFrame")
ToggleGameMenu = records("ToggleGameMenu")
ToggleCharacter = records("ToggleCharacter")
ToggleSpellBook = records("ToggleSpellBook")
DoEmote = records("DoEmote")

--[[ **Vanilla does not have `SitStandOrDescendStart`**, which is why the sit
     action tries it and falls back to the emote. Left undefined so the fallback
     is what a test gets without asking for it. ]]--

BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"

--[[ The client's own labels for its bindings, which is the string somebody read
     in the Key Bindings panel before coming to name a command after it. Only a
     few, because the point is that the label is looked up rather than written
     out -- a binding with no label falls back to its command name, and that
     path matters as much. ]]--
BINDING_NAME_TOGGLERUN = "Toggle Run/Walk"
BINDING_NAME_SITORSTAND = "Sit/Stand"
BINDING_NAME_TOGGLESHEATH = "Sheath/Unsheath Weapon"
BINDING_NAME_TOGGLEAUTORUN = "Toggle Autorun"

Stub.framerate = 60
Stub.latency = 42

function GetFramerate() return Stub.framerate end
function GetNetStats() return 0, 0, Stub.latency end

--[[ Combat logging, which the client exposes as one call that both reads and
     writes: no argument queries, an argument sets and answers with what it
     ended up as. Modelled that way because the toggle is written against
     it. ]]--
Stub.combatLogging = false

function LoggingCombat(on)
    if on == nil then return Stub.combatLogging end

    Stub.combatLogging = on and true or false
    return Stub.combatLogging
end

--[[ The chat edit box, which `/hud` moves onto WorldFrame while the interface is
     hidden -- otherwise the command that brings the interface back cannot be
     typed. Real, because that reparenting is the whole of the feature and a
     missing edit box would make it a no-op that looked like it worked. ]]--
ChatFrameEditBox = CreateFrame("EditBox", "ChatFrameEditBox", UIParent)
ChatFrameEditBox:Hide()

--[[ **The three textures that make the gold frame around it.** Not a backdrop --
     1.12's edit box has none -- which is why removing the border is hiding
     these and adding one of our own rather than recolouring anything. Real,
     because a nil global would make that pass do nothing while looking like it
     had worked. ]]--
for _, piece in ipairs({ "Left", "Mid", "Right",
                         "FocusLeft", "FocusMid", "FocusRight" }) do
    _G["ChatFrameEditBox" .. piece] =
            ChatFrameEditBox:CreateTexture("ChatFrameEditBox" .. piece, "BORDER")

    --[[ With a texture on it, because the client's art has one -- and taking
         it off is only acceptable because the path is remembered first. A stub
         whose art started blank could not tell "remembered and cleared" from
         "there was nothing there". ]]--
    _G["ChatFrameEditBox" .. piece]:SetTexture("BlizzardEditBoxArt-" .. piece)
end

DEFAULT_CHAT_FRAME.editBox = ChatFrameEditBox
DEFAULT_CHAT_FRAME.GetParent = function(self) return self.parent or UIParent end
DEFAULT_CHAT_FRAME.SetParent = function(self, p) self.parent = p end
DEFAULT_CHAT_FRAME.GetFrameStrata = function(self) return self.strata or "LOW" end
DEFAULT_CHAT_FRAME.SetFrameStrata = function(self, s) self.strata = s end
StaticPopupDialogs = {}

Stub.popups = {}
function StaticPopup_Show(name)
    table.insert(Stub.popups, name)
    return StaticPopupDialogs[name]
end

--[[ Accept a popup the way clicking its first button would.

     The dialog frame is modelled rather than skipped, because 1.12 hands the
     handlers no arguments at all: everything arrives through the `this` global,
     and a dialog with `hasEditBox` grows a child named `<dialog>EditBox` that
     the accept handler is expected to find by name. A stub that called
     `OnAccept()` bare would pass any handler that ignored its input and fail
     every handler that read it -- which is backwards. ]]--
Stub.popupFrame = nil

local function popupFrame()
    if Stub.popupFrame then return Stub.popupFrame end

    local dialog = CreateFrame("Frame", "StaticPopup1", UIParent)
    dialog.box = CreateFrame("EditBox", "StaticPopup1EditBox", dialog)
    dialog.box.parent = dialog

    --[[ The accept **button**, because that is what `this` is when 1.12 calls
         OnAccept -- which is why every vanilla addon reaches the dialog as
         `this:GetParent()`. Setting `this` to the dialog itself would make that
         idiom resolve to UIParent and quietly find no edit box. ]]--
    dialog.button = CreateFrame("Button", "StaticPopup1Button1", dialog)
    dialog.button.parent = dialog

    Stub.popupFrame = dialog
    return dialog
end

function Stub.AcceptPopup(name, text)
    local dialog = StaticPopupDialogs[name]
    if not dialog then return end

    local frame = popupFrame()
    local previous = this

    if dialog.hasEditBox then
        this = frame
        if dialog.OnShow then dialog.OnShow() end
        frame.box:SetText(text or "")
    end

    this = frame.button
    if dialog.OnAccept then dialog.OnAccept() end

    this = previous
end

-- press Enter in a popup's edit box, which is a separate handler from OnAccept
function Stub.PopupEnter(name, text)
    local dialog = StaticPopupDialogs[name]
    if not dialog or not dialog.EditBoxOnEnterPressed then return end

    local frame = popupFrame()
    frame.box:SetText(text or "")

    local previous = this
    this = frame.box
    dialog.EditBoxOnEnterPressed()
    this = previous
end

function ShowUIPanel(frame) if frame and frame.Show then frame:Show() end end
function HideUIPanel(frame) if frame and frame.Hide then frame:Hide() end end

BOOKTYPE_SPELL = "spell"

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetWidth(1024)
UIParent:SetHeight(768)

WorldFrame = CreateFrame("Frame", "WorldFrame")

--[[ **A nameplate as the client makes one**, which is the only way to test a
     module whose entire job is recognising them.

     Vanilla builds a Button parented to WorldFrame with six regions in a fixed
     order -- border, glow, name, level, level icon, raid icon -- and two
     children, the health bar and the cast bar. It has no name, no unit token and
     no event announcing it, so every one of those details is load bearing:
     something with the regions in a different order is not a nameplate, and
     something with the border texture is.

     Built here rather than faked, so a port that read the level as the name
     would fail rather than pass on a stub that answered plausible things in a
     convenient order. ]]--
function Stub.NewNamePlate(name, level, r, g, b, health)
    local plate = CreateFrame("Button", nil, WorldFrame)
    plate.frameType = "Button"

    --[[ The border first, because being first is the signature. ]]--
    local border = plate:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Tooltips\\Nameplate-Border")

    plate:CreateTexture(nil, "ARTWORK")               -- glow

    local nameText = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetText(name or "Target Dummy")

    local levelText = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelText:SetText(tostring(level or 60))

    plate:CreateTexture(nil, "ARTWORK")               -- level icon
    plate:CreateTexture(nil, "OVERLAY")               -- raid icon

    --[[ Health first, cast second, which is the order GetChildren answers and
         the order the takeover relies on. ]]--
    local healthBar = CreateFrame("StatusBar", nil, plate)
    healthBar.frameType = "StatusBar"
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(health or 100)
    healthBar:SetStatusBarColor(r or 1, g or 0, b or 0, 1)

    local castBar = CreateFrame("StatusBar", nil, plate)
    castBar.frameType = "StatusBar"

    plate:Show()

    return plate
end

ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame", UIParent)
ColorPickerFrame.rgb = { 1, 1, 1 }
ColorPickerFrame.SetColorRGB = function(self, r, g, b) self.rgb = { r, g, b } end
ColorPickerFrame.GetColorRGB = function(self)
    return self.rgb[1], self.rgb[2], self.rgb[3]
end
ColorPickerFrame:Hide()

OpacitySliderFrame = CreateFrame("Slider", "OpacitySliderFrame", UIParent)
OpacitySliderFrame:SetValue(0)

-- ---------------------------------------------------------------------------
-- dropdown API
-- ---------------------------------------------------------------------------

function UIDropDownMenu_Initialize(frame, fn) frame.initialize = fn end
function UIDropDownMenu_SetWidth(width, frame)
    if frame then frame.dropWidth = width end
end

--[[ SetSelectedValue calls UIDropDownMenu_Refresh on the real client, and Refresh
     both moves the check mark AND sets the label from the matching button. The
     addon therefore does not call SetText at all -- doing so alongside
     info.checked is what put several ticks in one menu (constraint 25).

     Modelled here rather than left as a bare assignment because a stub that only
     records the value cannot tell a working dropdown from one whose label never
     updates -- which is exactly the profile-switching bug that shipped: the
     profile changed, and the dropdown went on naming the old one. ]]--
function UIDropDownMenu_SetSelectedValue(frame, value)
    if not frame then return end

    frame.selectedValue = value
    frame.selectedText = nil

    if not frame.initialize then return end

    local buttons = Stub.OpenMenu(frame)
    for i = 1, table.getn(buttons) do
        if buttons[i].value == value then frame.selectedText = buttons[i].text end
    end
end

function UIDropDownMenu_SetText(text, frame)
    if frame then frame.selectedText = text end
end
function UIDropDownMenu_AddButton(info)
    if menuButtons then table.insert(menuButtons, info) end
end


--[[ **The world map's zone label**, which is one font string the client rewrites
     every frame from its own hit test as the cursor moves.

     Real, because that rewriting is the whole reason the level range is appended
     *after* the original handler rather than before -- and a stub without the
     handler would let the wrong order pass. ]]--
WorldMapFrameAreaLabel = newFontString(nil, "OVERLAY", "GameFontNormal")
_G["WorldMapFrameAreaLabel"] = WorldMapFrameAreaLabel

Stub.hoveredZone = nil

function WorldMapButton_OnUpdate(elapsed)
    --[[ What the client does: writes whatever the cursor is over, blanking it
         when the cursor is over nothing. ]]--
    WorldMapFrameAreaLabel:SetText(Stub.hoveredZone or "")
end

return Stub
