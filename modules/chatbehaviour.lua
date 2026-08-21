--[[ Equadis' Classic Overhaul :: chat, the behaviour

  **Split off from `modules/chat.lua`, and not for tidiness.**

  That file would not compile on 1.12 while compiling cleanly under the Lua 5.1
  the tests run, and the client says nothing about where a file died -- it simply
  carries on with the next one, so the module never registered and its tab
  vanished without a word. At 112KB it was the largest file in the addon by
  half again, which is a lot of haystack.

  So it is two files. The first declares the module -- defaults, options, and
  nothing that can fail -- and this one holds every line of behaviour. The tab
  now exists whatever happens here, and `/eqob doctor` says which half stopped.

  It is also just a better shape. One file was carrying the decoration chain,
  the window styling, channel names, player names, item links, mentions, popups,
  search boxes and the chat scan's readers, which is eleven sections of settings
  and no reason for them to share a file.
]]--

local OB = EquadisClassicOverhaul

--[[ **Every line this file writes says which part of the addon it came from.**

     One prefix, one colour, and the name after it -- so a message about the
     chat scan says so, rather than leaving the reader to work out which of
     eleven things is talking. See OB.Print. ]]--
local function Say(msg) OB.Print(msg, "Chat") end
local M = OB.modules.chat

--[[ **Nothing here works without the declaration**, and saying so beats eighty
     "attempt to index nil" errors -- which is what happened when chat.lua did
     not compile: this file ran, M was nil, and the first method definition threw
     while the marker still said the declaration had finished. ]]--
if not M then
    OB.chatLoad = 99
    return
end

--[[ The same breadcrumbs as the first half, so `/eqob doctor` can say which of
     the two stopped and roughly where. See the note in `modules/chat.lua`. ]]--
OB.chatLoad = 100

--[[ Seven chat windows, fixed rather than discovered -- `NUM_CHAT_WINDOWS`
     exists but a stub or a future client could disagree with the frames that
     actually exist. ]]--
local WINDOWS = 7

--[[ **A channel's name, with everything the client decorates it with taken off.**

     `"1. General - Stormwind"` is one channel under two names depending on where
     you are standing, and a setting that had to be re-typed on entering a new
     zone would be no use. The number goes because it is a position in your list
     rather than part of the name, and the suffix goes because it is the zone.

     Up here rather than beside the first thing that used it, because three
     separate behaviours now ask the same question -- the never-join list, the
     removal memory and the colour store -- and a helper that has to be defined
     above all of them belongs above all of them. ]]--
local function channelBase(name)
    if not name or name == "" then return nil end

    name = string.gsub(name, "^%s*%d+%.%s*", "")
    name = string.gsub(name, "%s*%-%s*.*$", "")
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")

    if name == "" then return nil end
    return string.lower(name)
end

--[[ Whether a shape carries seconds, and whether it pads. Read off the
     notation rather than stored beside it, because the notation *is* the
     answer: a doubled letter is a padded field, and that is what `hh` means
     everywhere anybody has met it. ]]--
local SHAPE = {
    { seconds = false, padded = false },
    { seconds = true,  padded = false },
    { seconds = false, padded = true },
    { seconds = true,  padded = true },
}

function M:Config()
    return OB.profile.modules.chat
end

--[[ The strftime spec for the three answers together.

     `strip` and `stripAll` exist because 1.12's strftime has no unpadded
     specifier -- no `%-I`, no `%-M` -- so an unpadded clock is a padded one with
     the zeroes taken off afterwards. ]]--
function M:TimeSpec()
    local cfg = self:Config()
    local shape = SHAPE[cfg.timeShape] or SHAPE[3]

    local pattern = (cfg.hour12 and "%I" or "%H") .. ":%M"

    if shape.seconds then pattern = pattern .. ":%S" end

    --[[ Only where there is an hour it can disambiguate. "14:36 PM" is not a
         time, so the switch is read but the twenty-four-hour clock ignores
         it -- which is why the row is dimmed rather than dropped. ]]--
    if cfg.hour12 and cfg.meridiem then pattern = pattern .. " %p" end

    if shape.padded then return { pattern } end

    --[[ Unpadded means every field, not just the hour: `h:m` at five past nine
         is "9:5", which is what the notation says and what somebody choosing it
         asked for. ]]--
    return { pattern, strip = true, stripAll = true }
end

--[[ **The clock a timestamp is read from.**

     Local time is `date()` and needs nothing. Server time is the awkward one:
     `GetGameTime` gives hours and minutes and no seconds at all, so the seconds
     have to be recovered by noticing when the minute rolls over and measuring
     the offset from the local clock at that instant.

     That trick is Prat's, taken in turn from FuBar_ClockFu. It is carried across
     intact because it is the only way to get a second hand out of an API that
     does not have one, and because getting it subtly wrong shows up as a clock
     that jumps rather than one that is simply wrong -- which is worse. ]]--
function M:Now()
    local cfg = self:Config()
    local spec = self:TimeSpec()

    --[[ One means the local clock, which needs nothing. Two means the server's,
         which needs everything below. ]]--
    if cfg.timeSource == 1 then return OB.FormatTime(spec) end

    local parts = date("*t")
    local hour, minute = GetGameTime()

    parts.hour, parts.min = hour, minute

    --[[ The minute rolled over, so *now* is a known second-zero: the difference
         between the local clock and that instant is the offset to subtract from
         here until the next roll. ]]--
    if self.lastMinute ~= minute then
        self.lastMinute = minute
        self.drift = mod(time(), 60)
    end

    parts.sec = mod(time() - (self.drift or 0), 60)

    return OB.FormatTime(spec, time(parts))
end


--[[ **Square, angled or bare -- one question asked once.**

     Player names, links, channel labels and timestamps are four things that all
     get wrapped in something, and four different answers to "how is a thing
     wrapped" would be four things to learn. They share the list and they share
     this, so `[Guild]` and `[Bobby]` cannot drift apart.

     Index one is square, which is what the client does and therefore what every
     one of these looked like before it was a setting. ]]--
local function surround(text, choice)
    if choice == 2 then return "<" .. text .. ">" end
    if choice == 3 then return text end

    return "[" .. text .. "]"
end
--[[ The text a message is prefixed with, or "" when this window has no stamp.

     Separated from the hook so the whole of the decision is testable without a
     chat frame: what a message *becomes* is arithmetic on strings, and only the
     act of putting it on screen needs the client. ]]--
function M:Stamp(index)
    local cfg = self:Config()
    if not cfg.stamp[index] then return "" end

    --[[ Wrapped before it is coloured, so the brackets take the timestamp's
         colour rather than sitting in whatever the line was. ]]--
    local stamp = surround(self:Now(), cfg.stampBrackets)

    --[[ **Always a space.** It was a checkbox, and "01:23Bob: hi" is not a
         thing anybody wanted -- a setting whose off state nobody chooses is a
         row of noise above the ones they do. ]]--
    local trailing = " "

    if cfg.colorStamp then
        local c = cfg.stampColor
        stamp = string.format("|cff%02x%02x%02x%s|r",
                c[1] * 255, c[2] * 255, c[3] * 255, stamp)
    end

    return stamp .. trailing
end

--[[ **`[1. General]` becomes `[1]`, `[General]` or `[G]`.**

     A pattern rather than a lookup, and unavoidably so: numbered channels are
     built from the channel list at runtime, not from a format string, so there
     is nothing to rewrite in advance. The message has already been assembled by
     the time anything can see it.

     The pattern is deliberately narrow -- a digit, a dot, a space, then anything
     that is not a closing bracket. Prat matched much more loosely and reached
     for the player link to anchor itself, which breaks on any line that carries
     a link and no channel. A bracket containing "number dot text" is specific
     enough that a false positive would have to be somebody typing one. ]]--
function M:ShortenNumbered(text)
    local cfg = self:Config()
    if not cfg.shortenNumbered then return text end

    --[[ **The name, always.** This was a three-way choice between the number,
         the name and its first letter. The number is what the client already
         shows and the reason anybody wants this changed; a single letter is
         ambiguous the moment you are in two channels starting with the same
         one. The name is the answer, so it is the answer. ]]--
    return (string.gsub(text, "%[(%d+)%. ([^%]]+)%]", function(number, name)
        return "[" .. name .. "]"
    end))
end

--[[ Everything one message picks up on its way to a frame, in order.

     A chain rather than a hook per behaviour, which is what Prat had: four
     modules each hooking AddMessage means four wrappers deep on every line and
     an order nobody chose. Here the order is written down, and adding a
     behaviour is adding a line to it. ]]--
--[[ **Fail-safe, because the alternative is chat that has stopped working.**

     Everything below runs inside `AddMessage`, which the client calls for every
     line. A throw there does not lose one message -- it takes the chat frame
     with it, and the only way back is a reload. That has happened twice: once
     from a pattern built out of typed text, once from a callback that fell off
     its end.

     So the chain runs under `pcall` and hands back the line it was given if
     anything in it throws. Decoration is a nicety; chat is not. Said once per
     session rather than per line, because a broken pass breaks on every line and
     eighty identical errors is not eighty times the information. ]]--
function M:Decorate(index, text)
    if not text then return text end

    local ok, out = pcall(self.Decorated, self, index, text)
    if ok then return out end

    if not self.decorateFailed then
        self.decorateFailed = true
        Say("|cffff5511chat decoration threw and has been skipped for this "
                .. "session|r -- chat itself is fine. " .. tostring(out))
    end

    return text
end

function M:Decorated(index, text)
    --[[ **Encoded item links first, because until they are decoded the item is
         a run of punctuation** -- `{CLINK:ff1eff00:4583:0:0:0:Thick Furry Mane}`
         is a bracketed name to the name pass and a mess to everything else.
         Decoding first means every pass below sees the line as it will be
         read. ]]--
    text = self:DecodeLinks(text)

    --[[ Names before the channel, because both are looking at brackets and the
         name rewrite is the fussier match -- it wants the sender's link intact,
         which is easier to find before anything else has been at the line. ]]--
    text = self:DecorateNames(text)
    text = self:ShortenNumbered(text)

    --[[ URLs last of the three, because it is the only pass that *inserts*
         characters rather than replacing them -- running it first would give the
         other two a line with brackets in it that were not there when the client
         wrote it. ]]--
    text = self:DecorateUrls(text)

    --[[ **Highlighting after the rewrites and before the stamp.**

         After, because a watched word may be a player name and the name pass
         wants the line as the client wrote it. Before the stamp, because
         somebody watching for "4" should not have their clock light up. ]]--
    text = self:Highlight(text)

    --[[ **A mention, put on screen** -- the louder half of highlighting, for
         when the chat window is not where you are looking. After the
         highlighting so the popup shows the line coloured the same way. ]]--
    if self:ShouldPopup(index, text) then self:Popup(text) end

    --[[ **Recorded as it will be read**, colours and all, so a search result
         printed back looks like the line it matched rather than a stripped
         copy of it. Before the stamp for the same reason as above: the time is
         not part of what was said. ]]--
    self:Record(index, text)

    --[[ The timestamp last, so it is outside everything: a prefix, not something
         another pass could mistake for part of a name. ]]--
    --[[ **Not on a search result.** Those already carry the time the line was
         said, which is the time worth having -- stamping them again would put
         the moment you searched in front of the moment somebody spoke, and the
         one nearest the left margin is the one that reads as authoritative. ]]--
    if self.printing then return text end

    return self:Stamp(index) .. text
end

-- ---------------------------------------------------------------------------
-- the hook
-- ---------------------------------------------------------------------------

--[[ **One hook per frame, installed once and never removed.**

     1.12 has no `hooksecurefunc`, so hooking is replacing a method and calling
     the old one. That makes *unhooking* the dangerous part: another addon may
     have hooked the same method after us, and restoring our saved original
     silently deletes their hook. Prat unhooked whenever a window's toggle went
     off, which is exactly that hazard once a second chat addon is loaded.

     So the hook goes on once and stays, and the *setting* is read inside it. A
     window with timestamps off gets an empty prefix rather than no hook, which
     costs a table lookup per message and cannot break a neighbour. ]]--
function M:Install()
    self:InstallLinks()

    if self.hooked then return end
    self.hooked = {}

    for i = 1, WINDOWS do
        local frame = getglobal("ChatFrame" .. i)

        if frame and frame.AddMessage then
            local index = i
            local original = frame.AddMessage

            self.hooked[i] = original

            frame.AddMessage = function(self2, text, r, g, b, id)
                --[[ **Which event this line arrived on**, read off the global
                     the client is still standing in.

                     `AddMessage` is called synchronously from
                     `ChatFrame_OnEvent`, so `event` is whichever CHAT_MSG_ this
                     is -- and it is the only way to know, because the frame
                     index says which window somebody filed it in rather than
                     what was said. A window is where you put things; a channel
                     is what happened. ]]--
                OB.modules.chat.lastEvent = event

                --[[ **And which numbered channel**, which is `arg8` on a
                     CHAT_MSG_CHANNEL and nothing on anything else. Read here
                     for the same reason the event is: the client is still
                     standing in its own handler, and one step further on the
                     information is gone. ]]--
                OB.modules.chat.lastChannel = arg8

                --[[ Guarded, because a message can arrive while the module is
                     unbound -- the hook outlives the binding by design. ]]--
                if text and OB.ModuleEnabled("chat") then
                    text = OB.modules.chat:Decorate(index, text)
                end

                return original(self2, text, r, g, b, id)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- window appearance
-- ---------------------------------------------------------------------------
-- what you said last
-- ---------------------------------------------------------------------------

--[[ **Up and down through what you have already sent.**

     1.12 has none of this: the edit box opens empty every time, so correcting a
     typo in a long `/w` means typing the whole thing again. Every chat client
     written since has it and everybody's hands already know the keys.

     Kept in memory rather than saved. What you typed last session is not what
     you want back, and a chat log on disk is a different feature with different
     consent attached to it. ]]--
local HISTORY = 30

function M:Remember(message)
    if not message or message == "" then return false end

    self.history = self.history or {}

    --[[ The same line twice running is one line. Sending "bump" four times is
         not four things to page back through. ]]--
    local last = self.history[table.getn(self.history)]
    if last == message then return false end

    table.insert(self.history, message)

    while table.getn(self.history) > HISTORY do
        table.remove(self.history, 1)
    end

    --[[ Feed the client's own EditBox history as well. Vanilla 1.12 exposes
         AddHistoryLine/SetHistoryLines, and letting the EditBox own arrow-key
         navigation means Left/Right keep their native cursor behaviour while
         Up/Down page through sent messages. ]]--
    local box = self:EditBox()
    if box and box.AddHistoryLine then
        box:AddHistoryLine(message)
    end

    --[[ Kept for the small history helpers/tests below. The live EditBox now
         maintains its own current history position. ]]--
    self.historyAt = nil

    return true
end

--[[ One step through it. `up` is towards older.

     **Returns nil at the newest end rather than wrapping**, because wrapping
     from the newest to the oldest is a keypress that looks like a bug -- and
     because the empty box below the newest line is a real position: it is what
     you had before you started paging. ]]--
function M:HistoryStep(up)
    local lines = self.history or {}
    local count = table.getn(lines)

    if count == 0 then return nil end

    local at = self.historyAt or (count + 1)

    if up then
        at = at - 1
        if at < 1 then at = 1 end
    else
        at = at + 1
        if at > count + 1 then at = count + 1 end
    end

    self.historyAt = at

    if at > count then return "" end

    return lines[at]
end

--[[ **Paging starts from the newest again once the box has been closed.**

     Somebody who closed chat and came back is starting a new thought, not
     continuing to page through an old one -- and a box that opens three lines
     up from where you left off is a box that has remembered the wrong thing. ]]--
function M:ResetHistory()
    self.historyAt = nil
end

--[[ **Use the EditBox's native arrow-key/history machinery.**

     The previous implementation attached an `OnKeyDown` script just to catch
     Up/Down. On this 1.12 client that also prevents the EditBox's own arrow-key
     handling, which is why Left/Right stopped moving the text cursor.

     Vanilla already exposes history storage and arrow-mode methods on EditBox.
     With Alt-arrow mode disabled, Left/Right remain normal cursor movement and
     Up/Down page through the history populated by Remember(). No keyboard
     script is installed here at all. ]]--
function M:InstallHistory()
    if EquadisOverhaulEditKeys then return false end

    local box = self:EditBox()
    if not box then return false end

    if box.SetHistoryLines then
        box:SetHistoryLines(HISTORY)
    end

    if box.SetAltArrowKeyMode then
        box:SetAltArrowKeyMode(false)
    end

    EquadisOverhaulEditKeys = true
    return true
end

-- ---------------------------------------------------------------------------
-- the box you type into
-- ---------------------------------------------------------------------------

--[[ **The typing box is now only a text widget; ECO owns its geometry and art.**

     We cannot replace ChatFrameEditBox itself without reimplementing Blizzard's
     input/history/channel machinery, but we do not need any of its visual frame
     or sizing behaviour. A separate invisible ECO container owns position,
     width and height. ChatFrameEditBox is stretched to that container, and one
     WHITE8X8 texture supplies the background.

     Every stock UI-ChatInputBorder texture is suppressed. We also explicitly
     cover the three live 1.12 art slots (regions 6-8) and the named variants
     used by client forks, because relying on the texture path alone is exactly
     how the anonymous middle strip survived before.
]]--
local EDIT_FILL = "Interface\\BUTTONS\\WHITE8X8"
local EDIT_DEFAULT_W = 430
local EDIT_DEFAULT_H = 32
local EDIT_MIN_W, EDIT_MAX_W = 180, 600
local EDIT_MIN_H, EDIT_MAX_H = 20, 36

function M:EditBox()
    return (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or ChatFrameEditBox
end

local function editClamp(v, low, high, fallback)
    v = tonumber(v) or fallback
    if v < low then return low end
    if v > high then return high end
    return v
end

-- The container owns ALL geometry. It has no art and does not replace the
-- EditBox widget; it simply gives that widget a rectangle Blizzard cannot
-- derive from its old opposing ChatFrame anchors.
function M:EditContainer()
    local box = self:EditBox()
    if not box then return nil end

    if not EquadisOverhaulEditContainer then
        local holder = CreateFrame("Frame", "EquadisOverhaulEditContainer", UIParent)
        holder:SetWidth(EDIT_DEFAULT_W)
        holder:SetHeight(EDIT_DEFAULT_H)
        holder:SetMovable(false)
        if holder.SetResizable then holder:SetResizable(false) end
        if holder.SetMinResize then holder:SetMinResize(EDIT_MIN_W, EDIT_MIN_H) end
        if holder.SetMaxResize then holder:SetMaxResize(EDIT_MAX_W, EDIT_MAX_H) end
        if holder.SetClampedToScreen then holder:SetClampedToScreen(true) end
        EquadisOverhaulEditContainer = holder
    end

    return EquadisOverhaulEditContainer
end

-- One flat fill, attached to the real EditBox so it naturally hides whenever
-- the input widget hides. No Blizzard border region contributes to this fill.
function M:EditBackground()
    local box = self:EditBox()
    if not box or not box.CreateTexture then return nil end

    if not box.eqFlatBackground then
        local bg = box:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(EDIT_FILL)
        bg:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
        box.eqFlatBackground = bg
    end

    return box.eqFlatBackground
end

-- The "original" option is rendered by ECO too.  We recreate Blizzard's
-- three-piece ChatFrameEditBox artwork with our own textures instead of ever
-- handing geometry/art control back to the stock regions.  This is the safe
-- switch: flat mode and Blizzard mode share the same holder, position and size.
function M:EditBlizzardArt()
    local box = self:EditBox()
    if not box or not box.CreateTexture then return nil end
    if box.eqBlizzardArt then return box.eqBlizzardArt end

    local art = {}

    art.left = box:CreateTexture(nil, "BACKGROUND")
    art.left:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left")
    art.left:SetPoint("LEFT", box, "LEFT", 0, 0)

    art.right = box:CreateTexture(nil, "BACKGROUND")
    art.right:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Right")
    art.right:SetTexCoord(0.9375, 1.0, 0, 1.0)
    art.right:SetPoint("RIGHT", box, "RIGHT", 0, 0)

    art.mid = box:CreateTexture(nil, "BACKGROUND")
    art.mid:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Right")
    art.mid:SetTexCoord(0, 0.9375, 0, 1.0)

    box.eqBlizzardArt = art
    return art
end

function M:SizeBlizzardArt()
    local art = self:EditBlizzardArt()
    local holder = self:EditContainer()
    if not art or not holder then return false end

    local width = editClamp(holder:GetWidth(), EDIT_MIN_W, EDIT_MAX_W, EDIT_DEFAULT_W)
    local height = editClamp(holder:GetHeight(), EDIT_MIN_H, EDIT_MAX_H, EDIT_DEFAULT_H)
    local rightW = 16
    local leftW = 256

    if width < leftW + rightW then leftW = width - rightW end
    if leftW < 1 then leftW = 1 end

    art.left:SetWidth(leftW)
    art.left:SetHeight(height)
    -- Below the stock 272px composition, crop the left texture instead of
    -- squashing it horizontally.
    if leftW < 256 then
        art.left:SetTexCoord(0, leftW / 256, 0, 1)
    else
        art.left:SetTexCoord(0, 1, 0, 1)
    end

    art.right:SetWidth(rightW)
    art.right:SetHeight(height)

    art.mid:ClearAllPoints()
    art.mid:SetHeight(height)
    if width > leftW + rightW then
        art.mid:SetPoint("LEFT", art.left, "RIGHT", 0, 0)
        art.mid:SetPoint("RIGHT", art.right, "LEFT", 0, 0)
        art.mid:Show()
    else
        art.mid:Hide()
    end

    return true
end

-- Return every piece that might be stock input-box chrome. Path matching gets
-- normal clients; regions 6-8 are the exact live slots our diagnostic found on
-- this client; named globals cover forks that expose the focus variants.
function M:EditStockArt()
    local box = self:EditBox()
    if not box or not box.GetRegions then return {} end

    local regions = { box:GetRegions() }
    local found, seen = {}, {}

    local function add(art)
        if not art or art == box.eqFlatBackground or seen[art] then return end
        if box.eqBlizzardArt and (art == box.eqBlizzardArt.left
                or art == box.eqBlizzardArt.mid
                or art == box.eqBlizzardArt.right) then return end
        if not art.GetTexture then return end
        seen[art] = true
        table.insert(found, art)
    end

    for i = 1, table.getn(regions) do
        local art = regions[i]
        local path = art and art.GetTexture and art:GetTexture()
        if type(path) == "string"
                and string.find(string.lower(path), "chatinputborder") then
            add(art)
        end
    end

    -- Live Turtle/1.12 diagnostic: these are the three actual border pieces,
    -- including the otherwise-anonymous stretched middle region.
    add(regions[6])
    add(regions[7])
    add(regions[8])

    -- Some 1.12 forks expose the same pieces by name (and sometimes duplicate
    -- focus pieces). Blank all of them if present.
    add(getglobal("ChatFrameEditBoxLeft"))
    add(getglobal("ChatFrameEditBoxMid"))
    add(getglobal("ChatFrameEditBoxRight"))
    add(getglobal("ChatFrameEditBoxFocusLeft"))
    add(getglobal("ChatFrameEditBoxFocusMid"))
    add(getglobal("ChatFrameEditBoxFocusRight"))

    return found
end

function M:SuppressEditStockArt()
    local stock = self:EditStockArt()

    for i = 1, table.getn(stock) do
        local art = stock[i]
        -- Hide AND alpha-zero. Either is sufficient on its own; both mean a
        -- later Show() from Blizzard cannot resurrect an ornate strip.
        if art.SetAlpha then art:SetAlpha(0) end
        if art.Hide then art:Hide() end
    end

    return true
end

function M:ApplyEditArt()
    local cfg = self:Config()
    local bg = self:EditBackground()
    local blizz = self:EditBlizzardArt()

    -- The real Blizzard regions stay suppressed in BOTH modes.  "Original"
    -- below means our own visual recreation of the stock three-piece bar, not
    -- re-enabling the regions that previously fought the movable editbox.
    self:SuppressEditStockArt()
    self:SizeBlizzardArt()

    if cfg.editBorder then
        -- Remove Editbox Border = our flat WHITE8X8 style.
        if bg then
            local c = cfg.editColor or { 0, 0, 0, 0.5 }
            bg:SetTexture(EDIT_FILL)
            bg:SetVertexColor(c[1] or 0, c[2] or 0, c[3] or 0)
            bg:SetAlpha(c[4] or 0.5)
            bg:Show()
        end
        if blizz then
            blizz.left:Hide()
            blizz.mid:Hide()
            blizz.right:Hide()
        end
    else
        -- Border enabled = stock Blizzard LOOK, still rendered by ECO.
        if bg then bg:Hide() end
        if blizz then
            blizz.left:SetAlpha(1)
            blizz.mid:SetAlpha(1)
            blizz.right:SetAlpha(1)
            blizz.left:Show()
            blizz.right:Show()
            local holder = self:EditContainer()
            if holder and holder:GetWidth() > 272 then blizz.mid:Show() end
        end
    end

    return true
end

-- Width/height are applied to ECO's holder. The actual EditBox has two opposing
-- anchors TO THAT HOLDER, so it must exactly follow those dimensions. This is
-- deliberately the inverse of the old broken design, where Blizzard's anchors
-- owned the size and SetWidth/SetHeight fought them.
function M:PlaceEditBox()
    local cfg = self:Config()
    local box = self:EditBox()
    local holder = self:EditContainer()
    if not box or not holder then return false end

    local width = editClamp(cfg.editWidth, EDIT_MIN_W, EDIT_MAX_W, EDIT_DEFAULT_W)
    local height = editClamp(cfg.editHeight, EDIT_MIN_H, EDIT_MAX_H, EDIT_DEFAULT_H)
    cfg.editWidth = width
    cfg.editHeight = height

    holder:ClearAllPoints()
    holder:SetWidth(width)
    holder:SetHeight(height)

    if cfg.editPos and cfg.editPos.x then
        holder:SetPoint("CENTER", UIParent, "CENTER", cfg.editPos.x, cfg.editPos.y)
    else
        local frame = getglobal("ChatFrame1")
        if frame then
            holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
        else
            holder:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        end
    end

    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)

    return true
end

-- Blizzard can re-show its art/reapply anchors when the box opens. Run our pass
-- after Blizzard every time. OnHide needs no special handling because the
-- custom texture is a child region of the EditBox and hides with it.
function M:InstallEditBox()
    if EquadisOverhaulEditShow then return false end

    local box = self:EditBox()
    if not box or not box.GetScript then return false end

    EquadisOverhaulEditShow = box:GetScript("OnShow") or true
    EquadisOverhaulEditFocus = box:GetScript("OnEditFocusGained") or true

    local function restyle()
        local m = EquadisClassicOverhaul.modules.chat
        if not EquadisClassicOverhaul.ModuleEnabled("chat") then return end
        m:PlaceEditBox()
        m:ApplyEditArt()
    end

    box:SetScript("OnShow", function()
        if type(EquadisOverhaulEditShow) == "function" then
            EquadisOverhaulEditShow()
        end
        restyle()
        EquadisClassicOverhaul.modules.chat:ResetHistory()
    end)

    box:SetScript("OnEditFocusGained", function()
        if type(EquadisOverhaulEditFocus) == "function" then
            EquadisOverhaulEditFocus()
        end
        restyle()
    end)

    return true
end

function M:ApplyEditBox()
    local box = self:EditBox()
    if not box then return false end

    self:InstallEditBox()
    self:InstallHistory()
    self:PlaceEditBox()
    self:ApplyEditArt()
    self:LockEditBox()

    return true
end

-- Save the holder, because that is now the authoritative rectangle.
function M:StoreEditBox()
    local holder = self:EditContainer()
    if not holder or not holder.GetCenter then return false end

    local bx, by = holder:GetCenter()
    if not bx or not by then return false end

    local ux, uy
    if UIParent and UIParent.GetCenter then ux, uy = UIParent:GetCenter() end
    if not ux then ux = GetScreenWidth() / 2 end
    if not uy then uy = GetScreenHeight() / 2 end

    local cfg = self:Config()
    cfg.editPos = {
        x = OB.Round(bx - ux),
        y = OB.Round(by - uy),
    }

    cfg.editWidth = editClamp(holder:GetWidth(), EDIT_MIN_W, EDIT_MAX_W, EDIT_DEFAULT_W)
    cfg.editHeight = editClamp(holder:GetHeight(), EDIT_MIN_H, EDIT_MAX_H, EDIT_DEFAULT_H)

    holder:SetWidth(cfg.editWidth)
    holder:SetHeight(cfg.editHeight)
    self:PlaceEditBox()

    return true
end

-- Unlocked: left-drag moves the ECO holder; right-drag resizes it. The EditBox
-- merely receives the mouse gesture -- it never owns the geometry itself.
function M:LockEditBox()
    local box = self:EditBox()
    local holder = self:EditContainer()
    if not box or not holder then return false end

    local cfg = self:Config()

    if cfg.editLocked then
        box:SetScript("OnDragStart", nil)
        box:SetScript("OnDragStop", nil)
        holder:SetMovable(false)
        if holder.SetResizable then holder:SetResizable(false) end
        return true
    end

    holder:SetMovable(true)
    if holder.SetResizable then holder:SetResizable(true) end
    if holder.SetMinResize then holder:SetMinResize(EDIT_MIN_W, EDIT_MIN_H) end
    if holder.SetMaxResize then holder:SetMaxResize(EDIT_MAX_W, EDIT_MAX_H) end
    if holder.SetClampedToScreen then holder:SetClampedToScreen(true) end
    if box.RegisterForDrag then box:RegisterForDrag("LeftButton", "RightButton") end

    box:SetScript("OnDragStart", function()
        local h = EquadisOverhaulEditContainer
        if not h then return end
        if arg1 == "RightButton" and h.StartSizing then
            h:StartSizing("BOTTOMRIGHT")
        else
            h:StartMoving()
        end
    end)

    box:SetScript("OnDragStop", function()
        local h = EquadisOverhaulEditContainer
        if h and h.StopMovingOrSizing then h:StopMovingOrSizing() end
        local m = EquadisClassicOverhaul.modules.chat
        m:StoreEditBox()
        m:ApplyEditArt()
    end)

    return true
end

function M:ResetEditBox()
    local cfg = self:Config()
    cfg.editPos = {}
    cfg.editWidth = EDIT_DEFAULT_W
    cfg.editHeight = EDIT_DEFAULT_H

    self:PlaceEditBox()
    self:ApplyEditArt()
    Say("editbox reset.")

    return true
end

-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------

--[[ **Size, justification and fading, applied to every window.**

     Prat's Justify, Fading and FontSize, which were three modules doing one
     thing each to the same seven frames. One pass here, because they are read
     together and a settings page that made you visit three tabs to style one
     window was Ace's shape rather than a decision.

     **What it was before is remembered on the first pass**, so switching the
     section off puts each window back where it was found rather than at some
     invented default. Prat restored a hardcoded 12pt and LEFT on disable, which
     is not "off" -- it is "off, and also I have changed your font". ]]--
function M:ApplyWindows()
    local cfg = self:Config()

    for i = 1, WINDOWS do
        local frame = getglobal("ChatFrame" .. i)

        if frame and frame.SetFont then
            if not self.original then self.original = {} end

            if not self.original[i] then
                local font, size, flags = frame:GetFont()
                self.original[i] = { font = font, size = size, flags = flags }
            end

            local was = self.original[i]

            if cfg.restyle then
                --[[ **The chosen font, not the one that was there.** This kept
                     the client's face and changed only the size, which made
                     "restyle" mean "resize" -- and left the one window anybody
                     reads as prose in a headline face. `OB.FontPath` falls back
                     to the profile's font, so leaving the row alone leaves chat
                     agreeing with everything else. ]]--
                local flags
                if cfg.fontOutline then flags = "OUTLINE" end
                frame:SetFont(OB.FontPath("chat"), cfg.fontSize, flags)
                frame:SetJustifyH(OB.chatJustify[cfg.justify] or "LEFT")

                --[[ **The window, not its text.** Font size changes the letters
                     and leaves the frame the size it was; this changes both,
                     which is what somebody asking for a smaller chat window
                     means. Remembered on the first pass like the font, so
                     switching the section off puts it back. ]]--
                if frame.SetScale then
                    if not was.scale then was.scale = frame:GetScale() or 1 end
                    frame:SetScale(cfg.scale)
                end

                if cfg.fade then
                    frame:SetFading(1)
                    frame:SetFadeDuration(cfg.fadeAfter)
                else
                    frame:SetFading(nil)
                end
            elseif was.font then
                frame:SetFont(was.font, was.size, was.flags)

                if was.scale and frame.SetScale then frame:SetScale(was.scale) end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- player names
-- ---------------------------------------------------------------------------


local function hex(r, g, b)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

--[[ The name as it should read: level in front, group behind, the whole thing
     coloured. ]]--
function M:Decorate1Name(name)
    if not name or name == "" then return "" end

    local cfg = self:Config()
    local known = OB.roster[name] or {}
    local out = name

    --[[ **A name nobody recognises is worth asking about.**

         Said here rather than acted on: this is the middle of drawing a line, so
         it records the wish and returns. The roster module's queue does the
         asking on its own clock, and if it is switched off the wish is dropped,
         which is the right amount of ceremony for a colour.

         This is where a chat addon stops being able to help itself. Most of the
         names in General belong to people you have never grouped with, so the
         six client rosters never learn them and they stay uncoloured forever --
         which is precisely the channel where telling people apart is hardest. ]]--
    if not known.class then OB.WantPlayer(name) end

    --[[ The group number rides with the name: it is a fact about the person, so
         it takes the person's colour. ]]--
    if cfg.nameGroup and OB.subgroups[name] then
        out = out .. ":" .. OB.subgroups[name]
    end

    local color

    --[[ **Known and unknown are two swatches and one override.**

         Somebody whose class this addon has learned is "known"; somebody it has
         not is not. They get different colours because that difference is the
         useful one -- an uncoloured name in General is not a person you know
         nothing about, it is a person nobody has looked up yet.

         **Colour By Class overrides the known swatch rather than replacing it.**
         The swatch stays visible and dimmed on the page, because "your colour is
         still there, something else is winning" is what is actually true --
         hiding it read as the setting having been deleted, and was reported as
         exactly that. ]]--
    if known.class and cfg.nameClassColor then
        color = hex(OB.ClassColor(known.class))
    elseif known.class then
        color = hex(cfg.nameKnownColor[1], cfg.nameKnownColor[2],
                cfg.nameKnownColor[3])
    else
        color = hex(cfg.nameColor[1], cfg.nameColor[2], cfg.nameColor[3])
    end

    if color then out = "|cff" .. color .. out .. "|r" end

    --[[ **The level is coloured by level, not by class**, and so it goes on
         outside the name's colour block rather than inside it.

         The two colours say different things and the level's is the one that
         cannot be got any other way: class is legible from the name once you
         know the person, but "is this a 60" is the question you are actually
         asking, and red-through-grey answers it without arithmetic. Painting it
         in the class colour would spend the only place that answer could go on
         a fact already shown two characters to the right. ]]--
    if cfg.nameLevel and known.level then
        out = "|cff" .. hex(OB.LevelColor(known.level)) .. known.level .. "|r:" .. out
    end

    return out
end

--[[ **Only the first player link, which is the sender.**

     This is Equadis' fix over upstream Prat and it matters: a message can carry
     player links of its own -- somebody typing a clickable name into what they
     say -- and replacing every match rewrites the body of the message with the
     sender's level and colour. The `1` on the end of the gsub is the whole fix.

     The link itself is left alone. Only what is drawn between `|h` and `|h` is
     replaced, so clicking the name still whispers the right person, and the
     brackets move outside the link because that is where the client draws
     them. ]]--
function M:DecorateNames(text)
    local cfg = self:Config()
    if not cfg.names then return text end

    local brackets = cfg.nameBrackets

    return (string.gsub(text, "|Hplayer:(.-)|h%[.-%]|h", function(name)
        local shown = "|Hplayer:" .. name .. "|h" .. self:Decorate1Name(name) .. "|h"

        return surround(shown, brackets)
    end, 1))
end

-- ---------------------------------------------------------------------------
-- scrollback
-- ---------------------------------------------------------------------------

--[[ **The wheel handler, installed once and never taken off.**

     Same rule as the message hook, for the same reason: a script is one slot per
     frame, so clearing ours clears whatever a neighbour put there after us.
     Prat's Scroll did exactly that on disable -- `SetScript("OnMouseWheel", nil)`
     -- which is fine alone and deletes another addon's scrolling in company.

     So it goes on once, and the switch is read inside. When the switch is off
     the handler hands the event to whatever was there before us, which is the
     neighbourly reading of "off": out of the way rather than absent. When it is
     on we take the event and do not chain, because two handlers both scrolling
     is worse than either.

     `arg1` is the direction and `this` the frame, both globals the client sets
     before the call. Reading them off the environment is not a shortcut here --
     it is the only place they exist. ]]--
function M:InstallWheel()
    if self.wheelInstalled then return end
    self.wheelInstalled = true

    self.originalWheel = {}

    for i = 1, WINDOWS do
        local frame = getglobal("ChatFrame" .. i)

        if frame and frame.EnableMouseWheel then
            local index = i
            self.originalWheel[i] = frame:GetScript("OnMouseWheel")

            frame:SetScript("OnMouseWheel", function()
                OB.modules.chat:Wheel(index, arg1)
            end)

            frame:EnableMouseWheel(true)
        end
    end
end

--[[ One notch of the wheel.

     Shift jumps to the end rather than scrolling faster, which is Prat's and is
     right: the two things you want from a chat log are "back a little" and "back
     to now", and a modifier that only changed the speed would waste the more
     useful of the two. ]]--
function M:Wheel(index, direction)
    local cfg = self:Config()

    if not (cfg.wheel and OB.ModuleEnabled("chat")) then
        local original = self.originalWheel and self.originalWheel[index]
        if original then original() end
        return
    end

    local frame = getglobal("ChatFrame" .. index)
    if not frame or not direction or direction == 0 then return end

    if IsShiftKeyDown() then
        if direction > 0 then frame:ScrollToTop() else frame:ScrollToBottom() end
        return
    end

    local lines = cfg.wheelLines
    if IsControlKeyDown() then lines = cfg.wheelFast end

    for _ = 1, lines do
        if direction > 0 then frame:ScrollUp() else frame:ScrollDown() end
    end
end

--[[ **How much each window keeps, and why the guard came back.**

     `SetMaxLines` **empties the frame**. That is the client's behaviour, not a
     bug in it: resizing the buffer throws away what was in the old one, so every
     call wipes the chat history.

     The style pass runs on every settings change, so calling this
     unconditionally cleared somebody's chat every time they moved any slider on
     any page. Reported exactly that way.

     Prat's `SetHistory` had a guard against precisely this and I removed it,
     calling it a saved call that cost nothing. The guard was right; what was
     wrong was **what it compared against** -- its own stored copy of the number,
     which the login path handed back to it unchanged, so it never applied at
     all.

     Asking the *frame* fixes both halves. At login it holds the client's 128,
     the setting says something else, and the change goes through. On every pass
     after that it already holds the answer and nothing happens. One comparison,
     both bugs. ]]--
function M:ApplyScrollback()
    local cfg = self:Config()

    for i = 1, WINDOWS do
        local frame = getglobal("ChatFrame" .. i)

        if frame and frame.SetMaxLines then
            --[[ A client that will not say what it currently holds gets the
                 call, because an unset buffer is worse than a cleared one. ]]--
            local current = frame.GetMaxLines and frame:GetMaxLines()

            if current ~= cfg.scrollback then
                frame:SetMaxLines(cfg.scrollback)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- typing
-- ---------------------------------------------------------------------------

--[[ **Every channel the box can reopen into.** Split only because the loud ones
     read as a warning when you see them in a list, not because they behave
     differently -- both are set the same way now. ]]--
local STICKY_QUIET = {
    "SAY", "WHISPER", "PARTY", "GUILD", "OFFICER", "RAID",
    "BATTLEGROUND", "CHANNEL",
}

local STICKY_LOUD = { "YELL", "RAID_WARNING", "EMOTE" }

--[[ **Always on, and every channel, including the loud ones.**

     It was two switches: sticky, and "the dangerous ones too". Neither is a
     decision anybody makes twice -- reopening the box in the channel you last
     used is what every chat client does and what everybody expects, and leaving
     yell out of it means the one time you do use it the box quietly goes back to
     say without telling you.

     The client's own default is off, which is the behaviour this replaces. ]]--
function M:ApplySticky()
    if not ChatTypeInfo then return end

    for i = 1, table.getn(STICKY_QUIET) do
        local info = ChatTypeInfo[STICKY_QUIET[i]]
        if info then info.sticky = 1 end
    end

    for i = 1, table.getn(STICKY_LOUD) do
        local info = ChatTypeInfo[STICKY_LOUD[i]]
        if info then info.sticky = 1 end
    end
end

--[[ **`/tt` -- whisper whoever you are looking at**, from Prat's TellTarget.

     Eleven lines and one of the most-used things Prat ships, which is a fair
     summary of how much of a chat addon is small. ]]--
function M:TellTarget(message)
    if not UnitExists("target") then
        Say("no target.")
        return false
    end

    if not UnitIsPlayer("target") then
        Say("your target is not a player.")
        return false
    end

    local name = UnitName("target")
    if not name then return false end

    if message and message ~= "" then
        SendChatMessage(message, "WHISPER", nil, name)
        return true
    end

    --[[ No message: open the box addressed to them rather than sending nothing.
         `/tt` with nothing after it is somebody about to type. ]]--
    local box = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox

    if box then
        box.chatType = "WHISPER"
        box.tellTarget = name
        if box.Show then box:Show() end
        if box.SetFocus then box:SetFocus() end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- the chat frame's own furniture
-- ---------------------------------------------------------------------------

--[[ **The scroll arrows and the menu button**, from Prat's Buttons.

     They occupy the corner of every chat window and do nothing the mouse wheel
     and a right-click do not already do.

     Prat hid these from a hook on `ChatFrame_OnUpdate` -- every frame, forever,
     for a decision that changes when a setting does. Here it runs on the style
     pass with everything else. The client does re-show them when a window is
     resized, which is what Prat was really working around; the answer to that is
     to run again on the event, not sixty times a second. ]]--
local FRAME_BUTTONS = { "UpButton", "DownButton", "BottomButton" }

function M:ApplyButtons()
    local cfg = self:Config()

    for i = 1, WINDOWS do
        for b = 1, table.getn(FRAME_BUTTONS) do
            local button = getglobal("ChatFrame" .. i .. FRAME_BUTTONS[b])

            if button then
                if cfg.hideButtons then button:Hide() else button:Show() end
            end
        end
    end

    if ChatFrameMenuButton then
        if cfg.hideMenuButton then
            ChatFrameMenuButton:Hide()
        else
            ChatFrameMenuButton:Show()
        end
    end
end

-- ---------------------------------------------------------------------------
-- links
-- ---------------------------------------------------------------------------

--[[ **Anything that looks like a URL becomes something you can click**, from
     Prat's UrlCopy.

     1.12 cannot open a browser and never will, so "clickable" means a box with
     the text already selected. That is the whole feature, and the alternative is
     reading a URL off the screen and typing it by hand.

     The patterns are Prat's. They are deliberately not one clever expression:
     `www.` without a scheme, a scheme with `://`, and a bare host with a slash
     are three different shapes, and one pattern that caught all three caught a
     great deal else besides. ]]--
function M:LinkUrl(url)
    local cfg = self:Config()
    local shown = url

    --[[ Square, angled or bare -- the same three the player-name row offers,
         read from the same list. ]]--
    if cfg.urlBrackets == 2 then
        shown = "<" .. url .. ">"
    elseif cfg.urlBrackets ~= 3 then
        shown = "[" .. url .. "]"
    end

    local color = ""
    if cfg.urlColor then
        color = string.format("|cff%02x%02x%02x", cfg.urlColor[1] * 255,
                cfg.urlColor[2] * 255, cfg.urlColor[3] * 255)
    end

    return " " .. color .. "|Heqourl:" .. url .. "|h" .. shown .. "|h|r "
end

function M:DecorateUrls(text)
    if not self:Config().urlCopy then return text end
    if not text then return text end

    --[[ A leading space is added so a URL at the very start of a line is still
         preceded by one -- every pattern below expects a boundary in front, and
         the alternative is three more patterns for the same three shapes. ]]--
    local padded = " " .. text

    padded = string.gsub(padded, " (%a[%w+.-]+://%S+)", function(url)
        return self:LinkUrl(url)
    end)

    padded = string.gsub(padded, " (www%.[%w_-]+%.%S+)", function(url)
        return self:LinkUrl(url)
    end)

    --[[ Trimmed back to what came in, or every line grows a space per pass. ]]--
    return (string.gsub(padded, "^%s", ""))
end

--[[ Clicking one. The client routes every hyperlink through `SetItemRef`, so
     this is a hook on one global rather than a handler per frame -- and one that
     hands anything not ours straight on. ]]--
function M:InstallUrlClicks()
    if self.urlClicksInstalled then return end
    if type(SetItemRef) ~= "function" then return end

    self.urlClicksInstalled = true

    local original = SetItemRef

    SetItemRef = function(link, text, button)
        if link and string.sub(link, 1, 7) == "eqourl:" then
            OB.modules.chat:ShowUrl(string.sub(link, 8))
            return
        end

        return original(link, text, button)
    end
end

function M:ShowUrl(url)
    if type(StaticPopup_Show) ~= "function" then return false end

    self.pendingUrl = url
    StaticPopup_Show("EQOB_COPY_URL")

    return true
end

-- ---------------------------------------------------------------------------
-- channel colours
-- ---------------------------------------------------------------------------

--[[ **1.12 stores a channel's colour by its number, and the numbers move.**

     Leave one channel and every channel below it shifts up, taking your colours
     with it: the green you set on your guild's channel is now on Trade. Prat's
     ChannelColorMemory keys them by name instead, which is the fix and is
     invisible when it works.

     Account-wide, because a colour is a preference about a channel rather than
     about a character, and setting it again on every alt is exactly the chore
     this removes. ]]--
function M:RememberColor(channel, r, g, b)
    if not channel or not r then return end
    if not self:Config().rememberColors then return end

    local base = channelBase(channel)
    if not base then return end

    OB.channelColors[base] = { r, g, b }
end

function M:ApplyRememberedColor(channel)
    if not self:Config().rememberColors then return false end
    if type(ChangeChatColor) ~= "function" then return false end

    local base = channelBase(channel)
    local saved = base and OB.channelColors[base]

    if not saved then return false end

    --[[ By its *current* number, which is the whole point: the name is what was
         remembered and the number is whatever it happens to be today. ]]--
    local index = GetChannelName(channel)
    if not index or index == 0 then return false end

    ChangeChatColor("CHANNEL" .. index, saved[1], saved[2], saved[3])
    return true
end

-- ---------------------------------------------------------------------------
-- channel groups
-- ---------------------------------------------------------------------------

--[[ **Raid warnings, raid leader and officer as groups of their own.**

     The client lumps them in with plain raid and guild, so a window set to show
     raid also shows raid warnings and there is no way to separate them. Prat's
     ChannelSeparator splits the groups; this is the same table, kept whole
     because the client reads it by name and a partial copy is a channel that
     stops being deliverable.

     The originals are saved and restored, and unlike the AddMessage hook that is
     safe: these are plain tables the client re-reads rather than functions
     another addon may have wrapped. Restoring a table cannot delete somebody
     else's behaviour, only their edits -- and an addon editing the same table is
     already in a fight this one cannot referee. ]]--
function M:ApplyChannels()
    local cfg = self:Config()

    if not ChatTypeGroup then return end

    local groups = {
        GUILD = { "CHAT_MSG_GUILD", "GUILD_MOTD" },
        OFFICER = { "CHAT_MSG_OFFICER" },
        PARTY = { "CHAT_MSG_PARTY" },
        RAID = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                 "CHAT_MSG_RAID_WARNING" },
        BATTLEGROUND = { "CHAT_MSG_BATTLEGROUND",
                         "CHAT_MSG_BATTLEGROUND_LEADER" },
    }

    if cfg.separate then
        --[[ **Each replaced key is remembered, not the table it lives in.**

             Saving `ChatTypeGroup` itself saves a *reference*, and the next line
             mutates that same table -- so the "original" and the live copy are
             one object and restoring puts back the edits. Prat has this bug
             too; its OnDisable assigns the same aliased table back.

             The suite caught it by comparing the restored table with the one it
             started from, which is the only way this shows: nothing errors, the
             channels simply never go back. ]]--
        if not self.savedGroups then
            self.savedGroups = {}
            for name in pairs(groups) do
                self.savedGroups[name] = ChatTypeGroup[name]
            end
            self.menuGroups = ChannelMenuChatTypeGroups
        end

        for name, value in pairs(groups) do ChatTypeGroup[name] = value end

        --[[ **Extended, never replaced.** This line used to assign a hardcoded
             list of eight, and that is a bug with a very specific symptom: the
             client builds the chat settings checkboxes from this table *and*
             walks it when saving which groups a window shows. Any group missing
             from it is a checkbox that cannot be ticked and a saved selection
             that does not survive a reload.

             The list is not just the obvious ones. 1.12 carries creature emotes,
             system messages, loot, skill-ups and more, and every one of them
             dropped out of somebody's window the moment this ran.

             So the client's own list is copied and only what is genuinely new is
             appended. Nothing that was selectable stops being selectable.

             Reported as "leave World, join Raid and Officer, reload, undone" --
             and Raid and Officer are two of the five groups this touches. ]]--
        local menu = {}
        local seen = {}

        for i = 1, table.getn(self.menuGroups or {}) do
            local name = self.menuGroups[i]
            menu[i] = name
            seen[name] = true
        end

        for name in pairs(groups) do
            if not seen[name] then table.insert(menu, name) end
        end

        ChannelMenuChatTypeGroups = menu

    elseif self.savedGroups then
        for name in pairs(groups) do
            ChatTypeGroup[name] = self.savedGroups[name]
        end
        ChannelMenuChatTypeGroups = self.menuGroups

        self.savedGroups = nil
        self.menuGroups = nil
    end
end

-- ---------------------------------------------------------------------------
-- short channel names
-- ---------------------------------------------------------------------------

--[[ Which global carries each channel's label, and the setting that renames it.

     The client builds every chat line from one of these format strings, so
     renaming a channel is rewriting the string rather than rewriting the
     message. That is why this needs no hook at all -- and why it is the right
     way round: a hook would have to recognise a channel it had already
     formatted, which is what Prat's numbered-channel path does and why that one
     is a pattern match rather than a lookup. ]]--
local CHANNELS = {
    { "CHAT_GUILD_GET", "shortGuild" },
    { "CHAT_OFFICER_GET", "shortOfficer" },
    { "CHAT_PARTY_GET", "shortParty" },
    { "CHAT_RAID_GET", "shortRaid" },
    { "CHAT_RAID_LEADER_GET", "shortRaidLeader" },
    { "CHAT_RAID_WARNING_GET", "shortRaidWarning" },
    { "CHAT_SAY_GET", "shortSay" },
    { "CHAT_YELL_GET", "shortYell" },
    { "CHAT_WHISPER_INFORM_GET", "shortWhisper" },
    { "CHAT_WHISPER_GET", "shortWhisperFrom" },
}

--[[ **The client's own strings are saved once, before anything is written.**

     Saved per key rather than as a table, for the reason ApplyChannels gives:
     these are globals, and remembering "the value this had" is the only form of
     remembering that survives us overwriting it.

     `%s` is the speaker's name, which the client substitutes. It has to survive
     into the replacement or every line loses the name of whoever said it. ]]--
function M:ApplyNames()
    local cfg = self:Config()

    if not self.savedNames then
        self.savedNames = {}
        for i = 1, table.getn(CHANNELS) do
            local key = CHANNELS[i][1]
            self.savedNames[key] = getglobal(key)
        end
    end

    for i = 1, table.getn(CHANNELS) do
        local key, setting = CHANNELS[i][1], CHANNELS[i][2]

        if cfg.shorten then
            local short = cfg[setting] or ""
            local tail = cfg.colon and ":" or ""

            setglobal(key, surround(short, cfg.channelBrackets)
                    .. " %s" .. tail .. " ")
        else
            setglobal(key, self.savedNames[key])
        end
    end
end

-- ---------------------------------------------------------------------------
-- channels you did not ask to be in
-- ---------------------------------------------------------------------------

--[[ **A channel you took out of a window, put back by the client, every login.**

     Different from the never-join list above and reported separately. That one
     is about being *in* a channel at all; this is about which window it shows
     in. You want World -- you just want it in the window you put it in.

     The client's own join handler adds a channel to a chat window whenever you
     join it, and there is nowhere it remembers that you took it out again. So a
     server that force-joins World re-adds it to that window on every reload,
     forever, and removing it by hand is a chore with no end.

     **This is not a setting.** Nobody should have to type a list to undo
     something they already did with the interface: the removal *is* the
     statement. So it is remembered when it happens and re-applied afterwards --
     the same shape as the roster and the learned cast times, and for the same
     reason. Somebody said something true once and it should keep being true. ]]--
function M:RememberRemoval(index, channel)
    local base = channelBase(channel)
    if not base or not index then return end

    OB.chatRemovals[index] = OB.chatRemovals[index] or {}
    OB.chatRemovals[index][base] = true
end

--[[ And the other way. Adding it back is somebody changing their mind, which
     has to clear the record or the change of mind lasts until the next login. ]]--
function M:ForgetRemoval(index, channel)
    local base = channelBase(channel)
    if not base or not index then return end
    if not OB.chatRemovals[index] then return end

    OB.chatRemovals[index][base] = nil
end

function M:WasRemoved(index, channel)
    local base = channelBase(channel)
    if not base or not index then return false end
    if not OB.chatRemovals[index] then return false end

    return OB.chatRemovals[index][base] and true or false
end

--[[ **Hooked once, and only recording after the client has finished its own
     setup.**

     During login the client adds and removes channels itself while restoring
     each window, and recording those as decisions would file the client's own
     bookkeeping as the player's. The gate is `self.chatReady`, set once the
     world is in -- before that these hooks watch and say nothing. ]]--
function M:InstallChannelMemory()
    if self.channelMemoryInstalled then return end
    if type(ChatFrame_RemoveChannel) ~= "function" then return end
    if type(ChatFrame_AddChannel) ~= "function" then return end

    self.channelMemoryInstalled = true

    local removeOriginal = ChatFrame_RemoveChannel
    local addOriginal = ChatFrame_AddChannel

    ChatFrame_RemoveChannel = function(frame, channel)
        local m = OB.modules.chat

        if m.chatReady and frame and frame.GetID then
            m:RememberRemoval(frame:GetID(), channel)
        end

        return removeOriginal(frame, channel)
    end

    ChatFrame_AddChannel = function(frame, channel)
        local m = OB.modules.chat

        --[[ **The whole fix is here.** The client adds a channel to a window on
             every join; if the player has already taken it out of that window,
             the add is the client repeating itself rather than anybody asking
             for anything, and it is refused.

             Only after login. During setup an add is the client restoring what
             was saved, and refusing those would empty the windows. ]]--
        if m.chatReady and frame and frame.GetID
                and m:WasRemoved(frame:GetID(), channel) then
            return
        end

        if m.chatReady and frame and frame.GetID then
            m:ForgetRemoval(frame:GetID(), channel)
        end

        return addOriginal(frame, channel)
    end
end

--[[ The sweep, for the adds that happened before the gate opened.

     The hook cannot refuse what it was not yet allowed to judge, so once the
     world is in, every window is checked against what the player took out of it
     and anything that came back is taken out again. ]]--
function M:ApplyChannelMemory()
    if type(ChatFrame_RemoveChannel) ~= "function" then return 0 end

    local removed = 0

    for i = 1, WINDOWS do
        local frame = getglobal("ChatFrame" .. i)
        local list = OB.chatRemovals[i]

        if frame and list and frame.channelList then
            --[[ Backwards, because removing shortens the list under us -- the
                 same reason the bag sweep walks backwards. ]]--
            for j = table.getn(frame.channelList), 1, -1 do
                local channel = frame.channelList[j]

                if self:WasRemoved(i, channel) then
                    ChatFrame_RemoveChannel(frame, channel)
                    removed = removed + 1
                end
            end
        end
    end

    return removed
end

--[[ **What each chat window actually holds**, printed.

     Written for the same reason `/eqob windows` was: two rounds of reading the
     code did not find why chat settings come back changed after a reload, and a
     third would not either. What settles it is one line of output per window --
     the channels it is showing and the message groups it is registered for,
     beside whether this module has touched either.

     `messageTypeList` is the one that matters and the one nothing else prints.
     "Raid" and "Officer" are message *groups*, not channels, and the two are
     kept in different places by the client -- so a report that showed only
     channels would look fine while the actual problem sat one field away. ]]--
function M:PrintReport()
    local cfg = self:Config()

    Say("chat module: " .. (OB.ModuleEnabled("chat") and "on" or "off")
            .. ", separate groups: " .. tostring(cfg.separate)
            .. ", hooks: " .. tostring(self.channelMemoryInstalled and true or false))


    for i = 1, WINDOWS do
        local frame = getglobal("ChatFrame" .. i)

        if frame then
            local channels = {}
            local groups = {}

            for j = 1, table.getn(frame.channelList or {}) do
                table.insert(channels, tostring(frame.channelList[j]))
            end

            for j = 1, table.getn(frame.messageTypeList or {}) do
                table.insert(groups, tostring(frame.messageTypeList[j]))
            end

            --[[ Only windows with something in them. Seven lines of "nothing" is
                 seven lines somebody has to read past to reach the one that
                 matters. ]]--
            if table.getn(channels) > 0 or table.getn(groups) > 0 then
                OB.Raw("  [" .. i .. "] channels: "
                        .. (table.concat(channels, ", ") ~= ""
                                and table.concat(channels, ", ") or "none"))
                OB.Raw("      groups: "
                        .. (table.concat(groups, ", ") ~= ""
                                and table.concat(groups, ", ") or "none"))
            end
        end
    end

    local remembered = 0
    for _, list in pairs(OB.chatRemovals or {}) do
        for _ in pairs(list) do remembered = remembered + 1 end
    end

    Say(remembered .. " remembered removal(s). "
            .. "'/eqob chat forget' clears them.")
end


--[[ **Leaving again, every time.**

     The client announces a join whether you asked for it or not, which makes it
     the one reliable moment to act: a server that force-joins World and a chat
     frame re-joining its saved list both arrive here, and neither has to be
     identified for this to work.

     Said out loud once per channel, because an addon silently removing you from
     somewhere is worse than the problem it is fixing -- and because the first
     time it happens, "why am I not in World any more" is a question with an
     answer somebody has forgotten they configured. ]]--
function M:OnEvent()
    --[[ The world is in, so the client has finished restoring its windows. From
         here on an add or a remove is somebody deciding something. ]]--
    if event == "PLAYER_ENTERING_WORLD" then
        self.chatReady = true
        self:ApplyChannelMemory()
        return
    end

    --[[ A channel colour changed. Remembered by name, because the number it is
         stored under today is not the number it will have tomorrow. ]]--
    if event == "UPDATE_CHAT_COLOR" then
        if arg1 and string.find(arg1, "^CHANNEL%d") then
            local index = tonumber(string.sub(arg1, 8))
            local _, name = GetChannelName(index)
            if name then self:RememberColor(name, arg2, arg3, arg4) end
        end
        return
    end

    if event ~= "CHAT_MSG_CHANNEL_NOTICE" then return end
    if arg1 ~= "YOU_JOINED" then return end

    --[[ 1.12 gives the plain name in arg9 and the decorated one in arg4. Both
         are read, because a client mod that fills only one of them should not
         turn this into a no-op. ]]--
    local name = arg9
    if not name or name == "" then name = arg4 end

    --[[ A channel just joined gets back whatever colour it had last time,
         under whatever number it happens to have today. ]]--
    self:ApplyRememberedColor(name)

end

function M:OnBind()
    self.lastMinute = nil
    self.drift = nil

    self:Install()
    self:InstallWheel()
    self:InstallChannelMemory()
    self:InstallUrlClicks()
    self:ApplyWindows()
    self:ApplyScrollback()
    self:ApplyChannels()
    self:ApplyNames()
    self:ApplySearchBoxes()
    self:ApplyPopups()
    self:ApplyEditBox()
end

--[[ Re-applied whenever a setting changes, which is what makes the section's
     controls take effect without a reload. Cheap: seven frames, a handful of
     calls each, only when somebody is in the panel. ]]--
function M:OnStyle()
    self:ApplyWindows()
    self:ApplyEditBox()
    self:ApplyScrollback()
    self:ApplySticky()
    self:ApplyButtons()
    self:ApplyChannels()
    self:ApplyNames()
end
-- ---------------------------------------------------------------------------
-- item links that survive a custom channel
-- ---------------------------------------------------------------------------

--[[ **The server strips item links out of custom channels, and this puts them
     back.**

     Paste an item into General and it arrives as a link. Paste it into a channel
     somebody made -- a guild's trade channel, a server's world channel -- and it
     arrives as nothing at all, because the client only trusts `|Hitem:` escapes
     on the channels it knows about.

     Prat's answer, and it is the right one: encode the link as plain text on the
     way out and decode it on the way in. Anybody without the addon sees a
     readable `{CLINK:...}` rather than a blank; anybody with it sees the item.

     **Two formats exist because two addons invented one each**, and which you
     send matters -- it is what the people reading you can decode. Prat sends one
     or the other and reads only what it sends. This sends one and reads *both*,
     because decoding costs a substitution on a line that already has to be
     scanned, and refusing to read somebody's link to make a point is not a
     feature. ]]--

--[[ The item quality colours, both ways round.

     `GetItemQualityColor` is the client's own, so a server that has added a
     quality gets it for free. The reverse map exists because ChatManager encodes
     rarity as a *count of backspaces* -- the colour is the only thing left to
     recover it from when the item is not in the local cache. ]]--
local qualityColor, qualityByColor = {}, {}

for rarity = 0, 6 do
    local _, _, _, hex = GetItemQualityColor(rarity)

    if hex then
        qualityColor[rarity] = hex
        qualityByColor[string.sub(hex, 3)] = rarity
    end
end

local ITEM_LINK = "|c(%x+)|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[(.-)%]|h|r"
local CM_LINK = "%[([^%[^%]]-)%]{(%d+):(%d+):(%d+):(%d+)}(\b*)"

--[[ **ChatManager's format, decoded.** `[Thick Furry Mane]{4583:0:0:0}` plus one
     backspace per quality level -- invisible in a chat window, which is the
     trick: somebody without the addon reads the name and nothing else.

     The item is looked up locally first, because the cache knows its real name
     and colour. Failing that the backspaces are counted, which is what they are
     there for. Failing *that* the link is still built, uncoloured -- an item you
     cannot colour is better than an item you cannot click. ]]--
local function decodeCM(name, a, b, c, d, marks)
    local itemString = "item:" .. a .. ":" .. b .. ":" .. c .. ":" .. d
    local itemName, itemLink, rarity = GetItemInfo(itemString)

    if itemName and itemLink and rarity then
        return (qualityColor[tonumber(rarity)] or "")
                .. "|H" .. itemLink .. "|h[" .. itemName .. "]|h|r"
    end

    rarity = string.len(marks or "") - 1

    if rarity >= 0 then
        return (qualityColor[rarity] or "")
                .. "|H" .. itemString .. "|h[" .. name .. "]|h|r"
    end

    return "|H" .. itemString .. "|h[" .. name .. "]|h|r"
end

local function encodeCM(color, a, b, c, d, name)
    local itemString = "item:" .. a .. ":" .. b .. ":" .. c .. ":" .. d
    local _, _, rarity = GetItemInfo(itemString)

    --[[ Not in the cache, so the colour it arrived with is the only evidence of
         what quality it is. ]]--
    if not rarity then rarity = qualityByColor[color] end

    local encoded = "[" .. name .. "]{" .. a .. ":" .. b .. ":" .. c .. ":" .. d .. "}"

    if rarity then
        encoded = encoded .. string.rep("\b", tonumber(rarity) + 1)
    end

    return encoded
end

--[[ An incoming line with any encoded link turned back into a real one.

     Both formats, always, whichever this profile sends. ]]--
function M:DecodeLinks(text)
    if not self:Config().itemLinks or not text then return text end

    text = string.gsub(text, CM_LINK, decodeCM)

    text = string.gsub(text,
            "{CLINK:(%x+):(%d-):(%d-):(%d-):(%d-):([^}]-)}",
            "|c%1|Hitem:%2:%3:%4:%5|h[%6]|h|r")

    return text
end

--[[ An outgoing line with its links encoded, in whichever format was chosen. ]]--
function M:EncodeLinks(text)
    if not text then return text end

    if self:Config().linkFormat == "ChatManager" then
        return string.gsub(text, ITEM_LINK, encodeCM)
    end

    return string.gsub(text, ITEM_LINK, "{CLINK:%1:%2:%3:%4:%5:%6}")
end

--[[ **Which channels need it, which is the ones the client does not already
     handle.**

     General, Trade, LookingForGroup and the two defense channels carry links
     fine, and encoding into them would turn a working link into text for
     everybody -- including the people without this addon, who currently see the
     item. Prat's list, matched on the *base* name so it holds in every city:
     "Trade - Stormwind" and "Trade - Orgrimmar" are one channel under two
     names. ]]--
local BUILTIN = {
    ["general"] = true, ["trade"] = true, ["lookingforgroup"] = true,
    ["localdefense"] = true, ["localedefense"] = true, ["worlddefense"] = true,
}

function M:ChannelNeedsEncoding(channel)
    if not channel then return false end

    local _, name = GetChannelName(channel)
    if not name or name == "" then return false end

    --[[ `channelBase` is the same reduction the never-join list and the colour
         memory use: list position and zone stripped, lowercased. Three
         behaviours needed it, which is why it lives at the top of this file. ]]--
    return not BUILTIN[channelBase(name) or ""]
end

--[[ **Installed once, never removed**, on the rule the rest of this addon
     follows: a global function slot is one deep, so restoring our saved original
     would silently delete whatever a neighbour installed after us. The settings
     are read inside, and switched off means calling straight through. ]]--
function M:InstallLinks()
    if EquadisOverhaulBlizzSendChat then return false end

    EquadisOverhaulBlizzSendChat = SendChatMessage

    SendChatMessage = function(msg, chatType, language, channel)
        local m = EquadisClassicOverhaul.modules.chat

        --[[ Remembered before it is encoded, so paging back gives you the line
             you typed rather than the wire form of it. ]]--
        m:Remember(msg)

        if msg and chatType == "CHANNEL"
                and EquadisClassicOverhaul.ModuleEnabled("chat")
                and m:Config().itemLinks
                and m:ChannelNeedsEncoding(channel) then
            msg = m:EncodeLinks(msg)
        end

        return EquadisOverhaulBlizzSendChat(msg, chatType, language, channel)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- your name, lit up
-- ---------------------------------------------------------------------------


--[[ **Everything that counts as somebody talking to you.**

     One list, built once per line, feeding both halves -- the colour in chat and
     the popup on screen. They were two lists asking the same question, which
     meant a word you wanted lit was not a word you wanted shouted unless you
     said so twice. ]]--
function M:HighlightWords()
    local cfg = self:Config()
    local words = {}

    local me = UnitName("player")

    if cfg.highlightName and me and me ~= "" then
        table.insert(words, me)
    end

    --[[ `@name`, which is a player convention rather than a client one -- so it
         is its own switch. Added as a separate word so it lights even when the
         plain name is switched off, which is what somebody who wants only the
         deliberate form is asking for. ]]--
    if cfg.highlightAt and me and me ~= "" then
        table.insert(words, "@" .. me)
    end

    --[[ **No custom words.** A box of arbitrary text went straight into a Lua
         pattern, and a word holding a magic character -- a bracket, a dash, an
         unbalanced percent -- makes an invalid pattern. `gsub` throws, the throw
         happens inside `AddMessage`, and the chat frame stops rendering
         entirely. Escaping was attempted and clearly not sufficient.

         What is left are the three sources whose text this addon controls: your
         own name, the same with an `@`, and names out of the roster. None of
         them can arrive holding a pattern. ]]--
    return words
end


--[[ **A word turned into a pattern that matches it however it is written.**

     Two things, and both were bugs.

     **Magic characters are escaped**, or a word holding a bracket is not a word
     any more, it is a pattern -- and an invalid one throws inside `AddMessage`
     and takes the chat frame down.

     **And every letter becomes a class**, because 1.12's matcher has no
     case-insensitive flag and people do not capitalise names. `@equadis` is what
     somebody types; `@Equadis` is what the client calls you. Lowercasing the
     line instead would work for finding and be useless for replacing, because
     the replacement has to put back what was written rather than what was
     matched. ]]--
local function pattern(word)
    local out = string.gsub(word, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    return (string.gsub(out, "(%a)", function(c)
        return "[" .. string.upper(c) .. string.lower(c) .. "]"
    end))
end

--[[ One line, with every watched word wrapped in the highlight colour.

     **Links are taken out of the way first, and that is not a nicety.** A chat
     line already contains `|Hplayer:Ollie|h[Ollie]|h`, and colouring the word
     inside it splits the escape sequence -- the link stops working and the line
     renders as its own markup. The name pass and any item somebody linked are
     both in the blast radius.

     So every `|H...|h...|h` span is lifted out, replaced by a marker no chat
     line can contain, and put back afterwards. What is left to search is the
     part somebody actually typed, which is the only part worth lighting up.

     Matching is case-sensitive on purpose: `gsub` cannot fold case without
     rebuilding the string, and a name is written the way its owner writes
     it. ]]--
function M:Highlight(text)
    local cfg = self:Config()
    if not cfg.highlight or not text then return text end

    local words = self:HighlightWords()
    if table.getn(words) == 0 then return text end

    --[[ **Longest first, or `@Equadis` never matches.** The plain name is inside
         the @ form, so whichever is tried first wins -- and with the shorter one
         first the @ is left outside the colour, which is what "@username is not
         working" looked like. Sorting is one line and makes the order a
         property of the list rather than of how it was built. ]]--
    table.sort(words, function(a, b) return string.len(a) > string.len(b) end)

    --[[ The one colour, used for everything the roster cannot name a class for
         -- and for everything when colouring by class is off. ]]--
    local color = hex(cfg.highlightColor[1], cfg.highlightColor[2],
            cfg.highlightColor[3])

    --[[ `\1` and `\2` are control characters. The client will not put one in a
         chat line and a player cannot type one, which is what makes them safe as
         markers -- anything printable could be said by somebody. ]]--
    local links = {}

    text = string.gsub(text, "(|H.-|h.-|h)", function(link)
        table.insert(links, link)
        return "\1" .. table.getn(links) .. "\2"
    end)

    local me = UnitName("player")
    local meLower = me and string.lower(me) or nil

    for i = 1, table.getn(words) do
        local safe = pattern(words[i])
        local shade = color

        -- Your own name has a known class too. The old pass only used class
        -- colour for names learned by ChatScan, so a mention of *you* stayed in
        -- the generic highlight colour.
        if cfg.highlightClass and meLower and OB.class then
            local wordLower = string.lower(words[i])
            if wordLower == meLower or wordLower == "@" .. meLower then
                shade = hex(OB.ClassColor(OB.class))
            end
        end

        --[[ **Whole words only**, so "Ollie" does not match inside "Ollies".
             1.12's matcher has no word-boundary escape and no `%f`, so the
             character either side is matched and put back -- which is why the
             replacement carries `%1` and `%3`. ]]--
        text = string.gsub(text, "(%A)(" .. safe .. ")(%A)",
                "%1|cff" .. shade .. "%2|r%3")

        --[[ And again for the two positions a character class cannot reach: the
             very start of the line and the very end. ]]--
        text = string.gsub(text, "^(" .. safe .. ")(%A)", "|cff" .. shade .. "%1|r%2")
        text = string.gsub(text, "(%A)(" .. safe .. ")$", "%1|cff" .. shade .. "%2|r")

        --[[ **What this word coloured is lifted out before the next one looks.**

             The plain name is inside the @ form, so without this the second pass
             matches inside what the first wrote and the line ends up with a
             colour code inside a colour code. The hex is letters too, so a
             watched word like "cafe" could match inside the escape itself.

             Same placeholders as the links, and the same restore at the end. ]]--
        text = string.gsub(text, "(|cff%x%x%x%x%x%x.-|r)", function(span)
            table.insert(links, span)
            return "" .. table.getn(links) .. ""
        end)
    end
    --[[ **Everybody the roster knows, said inside a message.**

         The Chat Scan's database put to the one use that needs no lookup while
         reading: a name in the body of a line is a person, and colouring it is
         the difference between a wall of chat and a conversation with people in
         it.

         **Only inside the message.** The sender's own name is in the link the
         client puts in front of every line, and those were lifted out above --
         so what is left to scan is what somebody actually typed.

         **The callback returns the word it was given when there is no match, and
         that line is the whole bug this section shipped with.** 1.12 replaces
         the match with an empty string when a gsub callback returns nothing;
         5.1, which the test harness runs, keeps the original. So every run of
         letters in every line vanished in game and nothing failed here. Never
         let a gsub callback fall off its end. ]]--
    if cfg.highlightKnown and OB.roster then
        text = string.gsub(text, "(%a+)", function(word)
            local known = OB.roster[word]

            if known then
                --[[ **Class colour says who is talking as well as that they
                     were named**, which is the more useful of the two on
                     anybody but yourself. Falls back to the one colour for
                     somebody whose class nobody has looked up yet, because an
                     uncoloured name in a coloured line reads as a miss. ]]--
                local shade = color

                if cfg.highlightClass and known.class then
                    shade = hex(OB.ClassColor(known.class))
                end

                return "|cff" .. shade .. word .. "|r"
            end

            return word
        end)
    end


    --[[ **Restored until nothing is left, not once.**

         A lifted span can hold a marker of its own: a URL arrives already
         wrapped in a colour, its link is lifted first, and then the whole
         coloured span is lifted around the marker. One pass expands the outer
         one and leaves the inner text reading `\1 2 \2`, which is what a chat
         line full of stray digits looked like.

         Bounded, because an expansion that keeps producing markers is a bug
         rather than a deep nest, and a `while true` in AddMessage is a frozen
         client. ]]--
    for pass = 1, 4 do
        local found = nil

        text = string.gsub(text, "\1(%d+)\2", function(n)
            found = true
            return links[tonumber(n)] or ""
        end)

        if not found then break end
    end

    return text
end

-- ---------------------------------------------------------------------------
-- finding something that has scrolled away
-- ---------------------------------------------------------------------------

--[[ **Every line a window has shown, kept so it can be found again.**

     The timestamp is recorded beside the text rather than taken from the line,
     because the line has not been stamped yet at this point in the chain -- and
     because a window with timestamps switched off still wants its search results
     to say when.

     **Kept in memory, not saved.** A chat log on disk is a different feature
     with different consent attached to it, and nobody asked for one. ]]--
function M:Record(index, text)
    if not self:Config().showSearchBox or not text then return false end

    --[[ Not our own search results. `Find` prints into the frame it searched,
         which goes through AddMessage like anything else -- so without this a
         search records its own output and the next search finds that. ]]--
    if self.printing then return false end

    self.log = self.log or {}
    self.log[index] = self.log[index] or {}

    local kept = self.log[index]
    table.insert(kept, { text = text, when = date("%H:%M:%S") })

    --[[ Trimmed from the front, so what is dropped is always the oldest. The
         cap is what stops a long session turning into a memory leak with a
         search box on it. ]]--
    local limit = self:Config().searchLines or 500
    while table.getn(kept) > limit do table.remove(kept, 1) end

    return true
end

--[[ Every remembered line containing the text.

     **Printed into the window that was searched**, which is Prat's choice and
     the right one: the answer arrives where you were already looking, in the
     same column, and scrolls away with everything else. A window with no results
     still says so, because silence is indistinguishable from a search that did
     not run.

     `index` narrows it to one window -- which is what the box on a window
     does -- and its absence searches all of them, which is what the slash
     command does. ]]--
function M:Find(needle, index)
    if not needle or needle == "" then
        Say("usage: /eqob chat find <text>.")
        return 0
    end

    if not self:Config().showSearchBox then
        Say("remembering lines is switched off -- turn on Remember Lines "
                .. "For Searching on the Chat page first.")
        return 0
    end

    local wanted = string.lower(needle)
    local into = getglobal("ChatFrame" .. (index or 1))
    local found = 0

    --[[ Guarded across the whole printing run, so none of the results are
         recorded as chat. ]]--
    self.printing = true

    local first, last = index or 1, index or WINDOWS

    for i = first, last do
        local kept = (self.log and self.log[i]) or {}

        for k = 1, table.getn(kept) do
            if string.find(string.lower(kept[k].text), wanted, 1, true) then
                found = found + 1

                if into and into.AddMessage then
                    into:AddMessage("|cff888888[" .. kept[k].when .. "]|r "
                            .. kept[k].text, 1, 1, 1)
                end
            end
        end
    end

    local summary = "|cff33ff99" .. found .. "|r line"
            .. (found == 1 and "" or "s") .. " matching '" .. needle .. "'"

    if into and into.AddMessage then
        into:AddMessage(summary, 1, 1, 1)
    else
        Say(summary)
    end

    self.printing = nil

    return found
end

function M:Remembered()
    local n = 0

    for i = 1, WINDOWS do
        n = n + table.getn((self.log and self.log[i]) or {})
    end

    return n
end

--[[ **A box on the window itself**, which is what a search wants: the question
     is asked where the answer will appear.

     **Faint until something is near it, and it fades rather than snaps.** A
     permanently bright edit box sits on top of the one part of the screen
     already full of text; one that appears and vanishes instantly reads as a
     glitch. Ten percent at rest, ninety when the mouse is on the box *or
     anywhere on the window it belongs to* -- the window, because reaching for
     the box means moving across the window first, and a control that only
     brightens once you have already found it is not helping. ]]--
local FAINT, BRIGHT = 0.1, 0.9

--[[ **Alpha per second**, matched to the chat frame's own fade rather than
     picked. Four was a quarter of a second, which is a switch with a smear on
     it; the client takes about a second and a half to fade a chat window and the
     box sits on that window, so it moves with it. ]]--
local FADE = 1.6

function M:SearchBox(index)
    self.boxes = self.boxes or {}
    if self.boxes[index] then return self.boxes[index] end

    local frame = getglobal("ChatFrame" .. index)
    if not frame then return nil end

    local box = CreateFrame("EditBox", "EquadisOverhaulSearch" .. index,
            frame, "InputBoxTemplate")

    box:SetWidth(120)
    box:SetHeight(20)
    box:SetAutoFocus(false)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -4)
    box:SetAlpha(FAINT)

    box.window = index
    box.wanted = FAINT

    box:SetScript("OnEnterPressed", function()
        local m = EquadisClassicOverhaul.modules.chat

        m:Find(this:GetText(), this.window)

        --[[ Emptied after asking, because the next thing anybody does with a
             search box is ask something else -- and a box still holding the last
             question has to be cleared before it can be used again. ]]--
        this:SetText("")
        this:ClearFocus()
    end)

    box:SetScript("OnEscapePressed", function()
        this:SetText("")
        this:ClearFocus()
    end)

    --[[ Brightened by the mouse rather than by focus, so it is legible before
         you click it -- a box you have to find in order to see is not a box. ]]--
    box:SetScript("OnEnter", function() this.wanted = BRIGHT end)
    box:SetScript("OnLeave", function() this.wanted = FAINT end)

    --[[ Held bright while it has the keyboard, or it dims under the cursor the
         moment you start typing into it. ]]--
    box:SetScript("OnEditFocusGained", function() this.held = true end)
    box:SetScript("OnEditFocusLost", function() this.held = nil end)

    --[[ **The fade is a per-frame walk toward the wanted alpha**, which is what
         makes it a fade rather than a switch. Its own OnUpdate rather than the
         module's draw pass, because the draw pass runs when a setting changes
         and this has to run when a mouse moves. ]]--
    box:SetScript("OnUpdate", function()
        EquadisClassicOverhaul.modules.chat:FadeSearchBox(this, arg1)
    end)

    self.boxes[index] = box
    return box
end

--[[ One step of one box's fade, and the reason it also watches the window.

     `OnEnter` on a chat frame is not reliable in 1.12 -- the frame is not
     mouse-enabled unless something has enabled it, and enabling it to get a
     hover would swallow clicks meant for the text underneath. `MouseIsOver` asks
     the same question by geometry and costs a rectangle test on a frame that is
     already running an OnUpdate. ]]--
function M:FadeSearchBox(box, elapsed)
    local wanted = box.wanted or FAINT

    if box.held then
        wanted = BRIGHT
    elseif type(MouseIsOver) == "function" then
        local frame = getglobal("ChatFrame" .. box.window)
        if frame and MouseIsOver(frame) then wanted = BRIGHT end
    end

    local alpha = box:GetAlpha() or FAINT
    if alpha == wanted then return false end

    local step = (elapsed or 0) * FADE

    if alpha < wanted then
        alpha = alpha + step
        if alpha > wanted then alpha = wanted end
    else
        alpha = alpha - step
        if alpha < wanted then alpha = wanted end
    end

    box:SetAlpha(alpha)

    return true
end

--[[ One box per window that asked for one.

     **Made on demand and hidden when not wanted**, never destroyed: a frame
     cannot be unmade in 1.12, and creating one per settings change would leak a
     frame every time somebody ticked the box. ]]--
function M:ApplySearchBoxes()
    local cfg = self:Config()

    for i = 1, WINDOWS do
        local wanted = cfg.showSearchBox and cfg.searchWindow[i]

        --[[ Not built at all unless it is wanted, so somebody who never turns
             this on never pays for seven edit boxes. ]]--
        local box = self.boxes and self.boxes[i]
        if wanted and not box then box = self:SearchBox(i) end

        if box then
            if wanted then box:Show() else box:Hide() end
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- somebody said your name, loudly
-- ---------------------------------------------------------------------------

--[[ **A stack, not a frame.**

     One frame meant a second mention overwrote the first, which is worst in the
     case the feature exists for: two people speak to you while you are looking
     somewhere else, and you come back to one of them with no sign there was
     another. They stack now, newest at the bottom, each with its own clock --
     so one fading has no effect on the one above it.

     **Capped.** Beyond a few, a stack of popups is the screen, and the oldest
     is the one you have already had the longest chance to read -- so a new
     mention past the cap takes the oldest slot rather than growing the pile. ]]--
local POPUPS = 4

function M:PopupFrame(slot)
    self.popups = self.popups or {}
    if self.popups[slot] then return self.popups[slot] end

    local frame = CreateFrame("Frame", "EquadisOverhaulPopup" .. slot, UIParent)

    frame:SetWidth(420)
    frame:SetHeight(44)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    frame:SetBackdropColor(0, 0, 0, 0.8)

    local text = OB.NewText(frame, "OVERLAY", "GameFontNormal")
    local font, _, flags = text:GetFont()
    if font then text:SetFont(font, self:Config().popupTextSize or 12, flags) end
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")

    frame.text = text
    frame.slot = slot

    --[[ The fade is its own clock rather than the module's draw pass, because it
         has to keep running while nothing else is happening -- which is the
         whole case this exists for. ]]--
    frame:SetScript("OnUpdate", function()
        EquadisClassicOverhaul.modules.chat:PopupFade(this, arg1)
    end)

    self.popups[slot] = frame
    return frame
end

--[[ The first slot with nothing in it, or the one that has been up longest.

     Reusing the oldest rather than refusing the new one, because the newest
     mention is the one somebody has not read yet -- dropping it to protect a
     line that has been on screen for nine seconds is the wrong way round. ]]--
function M:PopupSlot()
    local oldest, oldestLeft = 1, nil

    for i = 1, POPUPS do
        local frame = self.popups and self.popups[i]

        if not frame or not frame:IsShown() then return i end

        if not oldestLeft or (frame.left or 0) < oldestLeft then
            oldest, oldestLeft = i, frame.left or 0
        end
    end

    return oldest
end

--[[ One tick of one popup's fade. Held at full while the mover is on, or placing
     it would mean chasing something that disappears. ]]--
function M:PopupFade(frame, elapsed)
    if not frame then return false end

    if self.popupMoving then
        frame:SetAlpha(1)
        return false
    end

    frame.left = (frame.left or 0) - (elapsed or 0)

    --[[ A second of fade after the time is up, then gone. Fading rather than
         vanishing, because something that disappears between glances reads as
         something you imagined. ]]--
    if frame.left < -1 then
        frame:Hide()
        self:StackPopups()
    elseif frame.left < 0 then
        frame:SetAlpha(1 + frame.left)
    else
        frame:SetAlpha(1)
    end

    return true
end

--[[ Every showing popup, restacked from the anchor downwards.

     Run whenever one appears or goes, so a gap left by the middle of three
     closes rather than staying as a hole -- which reads as a fourth popup that
     failed to draw. ]]--
function M:StackPopups()
    local cfg = self:Config()
    local y = cfg.popupPos.y or 120
    local shown = 0

    for i = 1, POPUPS do
        local frame = self.popups and self.popups[i]

        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", cfg.popupPos.x or 0, y)

            --[[ Its own height, so the gap is right at any scale -- and the
                 stack grows downwards, because the anchor is where the first one
                 goes and everybody knows where that is. ]]--
            y = y - (frame:GetHeight() + 4)
            shown = shown + 1
        end
    end

    return shown
end
--[[ Who sent a line, from the sender link the client puts in front of it.

     `string.find` with a capture, because 1.12 has no `string.match` -- which is
     the call the addon this comes from uses and the reason it cannot run here.

     An emote has no sender link and returns nothing, which is correct: `/me
     waves at Ollie` is not somebody addressing you. ]]--
function M:SenderOf(text)
    if not text then return nil end

    local _, _, name = string.find(text, "|Hplayer:([^|]+)|h")
    return name
end
--[[ **Which channel a popup is wanted from**, mapped from the event the line
     arrived on.

     By channel rather than by window, because a window is where you filed
     something and a channel is what happened -- "whisper me and I want to know"
     is a sentence about the whisper, and it stays true after somebody
     rearranges their windows.

     Raid, raid leader and raid warning are one answer: they are the same
     conversation and nobody wants two of the three. Say and Yell are not -- a
     yell carries across a zone and a say does not, which is the whole
     difference between them. ]]--
local POPUP_FOR = {
    CHAT_MSG_WHISPER = "popupWhisper",
    CHAT_MSG_PARTY = "popupParty",
    CHAT_MSG_PARTY_LEADER = "popupParty",
    CHAT_MSG_RAID = "popupRaid",
    CHAT_MSG_RAID_LEADER = "popupRaid",
    CHAT_MSG_RAID_WARNING = "popupRaid",
    CHAT_MSG_GUILD = "popupGuild",
    CHAT_MSG_OFFICER = "popupOfficer",
    CHAT_MSG_SAY = "popupSay",
    CHAT_MSG_YELL = "popupYell",
    CHAT_MSG_EMOTE = "popupSay",
}

--[[ Whether this line's channel is one somebody asked to be interrupted for.

     **A numbered channel is answered by its number**, not as a group. They are
     not one thing: General, Trade and whatever a guild has made for itself are
     three different rooms that happen to share a naming scheme, and wanting one
     of them is not wanting all three. The client hands the number over as
     `arg8`, which is why the hook keeps it. ]]--
function M:PopupChannelWanted()
    local cfg = self:Config()

    if self.lastEvent == "CHAT_MSG_CHANNEL" then
        local n = tonumber(self.lastChannel)
        if not n then return false end

        return cfg.popupChannel[n] and true or false
    end

    local key = POPUP_FOR[self.lastEvent or ""]

    --[[ An event nobody has an opinion about -- a system message, a loot line,
         the client talking to itself. Not a mention. ]]--
    if not key then return false end

    return cfg[key] and true or false
end

--[[ **What counts as being spoken to.**

     Two questions, and they were one: *where* it was said, and *whether it was
     about you*. The channel list answers the first. This answers the second, and
     it has its own switch rather than borrowing the Highlights column's --
     which was the bug: turning highlighting off, or turning your own name off
     over there, silently stopped popups working for your name.

     Your name is the answer almost everybody wants, so it is the first row and
     it is on. ]]--
function M:ShouldPopup(index, text)
    local cfg = self:Config()

    if not cfg.popup or not text then return false end

    local sender = self:SenderOf(text)

    -- Never notify for our own lines.
    if sender and sender == UnitName("player") then return false end

    -- Player-name matching may override a conversation channel's own popup
    -- toggle, but it must not turn non-conversation text into a mention.
    -- Need/Greed, loot and other system lines can contain the player's name;
    -- reject those events before the name check gets a chance to promote them.
    local eventName = self.lastEvent or ""
    if eventName ~= "CHAT_MSG_CHANNEL" and not POPUP_FOR[eventName] then
        return false
    end

    -- A configured channel/event can request every message. A player-name
    -- mention is different: it is allowed to request a popup regardless of the
    -- numbered-channel toggles. That is what "Player Name Mention" means.
    local wanted = self:PopupChannelWanted()

    if cfg.popupName then
        local me = UnitName("player")
        if me and me ~= "" then
            local safe = pattern(me)
            local mentioned = false

            if string.find(text, "(%A)(" .. safe .. ")(%A)")
                    or string.find(text, "^(" .. safe .. ")(%A)")
                    or string.find(text, "(%A)(" .. safe .. ")$") then
                mentioned = true
            end

            if mentioned then wanted = true end
        end
    end

    if not wanted then return false end

    -- The same event can be rendered into more than one chat window. Those
    -- AddMessage calls are milliseconds apart, not guaranteed to share exactly
    -- the same GetTime() value. Treat an identical rendered line inside a short
    -- window as one notification; a later repeat is a genuinely new message.
    local now = GetTime()
    if self.lastPopped == text and self.lastPoppedAt
            and (now - self.lastPoppedAt) < 0.25 then
        return false
    end

    self.lastPopped = text
    self.lastPoppedAt = now
    return true
end


function M:Popup(text)
    local cfg = self:Config()
    local frame = self:PopupFrame(self:PopupSlot())

    frame:SetScale(cfg.popupScale)
    frame.text:SetText(text)
    frame.left = cfg.popupSeconds
    frame:SetAlpha(1)
    frame:Show()

    self:StackPopups()

    if cfg.popupSound and type(PlaySound) == "function" then
        PlaySound("FriendJoinGame")
    end

    return true
end

--[[ **The scale, re-applied on every settings pass.**

     It used to be set only when a popup appeared and when the mover was switched
     on, which meant moving the slider did nothing you could see: the frame in
     front of you kept the size it was built at until you closed the mover and
     opened it again. A scale you cannot watch change is a scale you cannot
     set. ]]--
function M:ApplyPopups()
    local cfg = self:Config()

    for i = 1, POPUPS do
        local frame = self.popups and self.popups[i]
        if frame then
            frame:SetScale(cfg.popupScale)

            --[[ Text size is separate from frame scale. Keep the font face and
                 flags the popup was created with and change only its point
                 size, so this setting cannot silently restyle the popup. ]]--
            if frame.text and frame.text.GetFont and frame.text.SetFont then
                local font, _, flags = frame.text:GetFont()
                if font then frame.text:SetFont(font, cfg.popupTextSize or 12, flags) end
            end
        end
    end

    self:StackPopups()

    return true
end

--[[ A mode rather than a lock, the same shape the bars and the frames use: on,
     drag, off. Shows a sample so there is something to aim at -- placing a frame
     that only appears when somebody says your name is otherwise a matter of
     waiting to be spoken to.

     **The first slot is the handle.** The stack grows downwards from wherever it
     is dropped, so placing the top one places all of them and there is nothing
     to line up by hand. ]]--
function M:PopupMoving()
    return self.popupMoving and true or false
end

function M:SetPopupMoving(on)
    local frame = self:PopupFrame(1)

    self.popupMoving = on and true or nil

    if not self.popupMoving then
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:SetMovable(false)
        frame:EnableMouse(false)
        frame:Hide()

        Say("popup placed.")
        return true
    end

    frame:SetScale(self:Config().popupScale)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function() this:StartMoving() end)

    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        EquadisClassicOverhaul.modules.chat:StorePopup()
    end)

    frame.text:SetText("Somebody: this is where a mention will appear.")
    frame:SetAlpha(1)
    frame:Show()

    self:StackPopups()

    Say("drag the popup where you want it, then switch this off.")
    return true
end

function M:StorePopup()
    local frame = self.popups and self.popups[1]
    if not frame or not frame.GetLeft or not frame:GetLeft() then return false end

    local cfg = self:Config()
    local scale = frame:GetScale() or 1
    if scale <= 0 then scale = 1 end

    cfg.popupPos = {
        x = OB.Round((frame:GetLeft() + (frame:GetWidth() / 2))
                - ((GetScreenWidth() / 2) / scale)),
        y = OB.Round((frame:GetBottom() + (frame:GetHeight() / 2))
                - ((GetScreenHeight() / 2) / scale)),
    }

    self:StackPopups()

    return true
end



--[[ Nothing to draw and nothing to hide: this module decorates frames the
     client owns. Switching it off is read by the hook rather than acted on
     here, for the reason Install gives. ]]--
function M:OnDraw() end

--[[ The far end of the file. Reaching this means every definition in it ran. ]]--
OB.chatLoad = 40
