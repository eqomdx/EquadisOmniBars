--[[ Equadis' Classic Overhaul :: quality of life

  **The small things, which are small individually and are the reason people run
  eight addons.**

  Nothing here is a subsystem. There is no window, no bar and no data model --
  each of these is one behaviour the client does not have, and the only thing
  they share is that none of them is worth an addon of its own. That is exactly
  what makes them worth one tab of a bundle.

  Every one is off by default. A quality-of-life change nobody switched on is a
  surprise, and several of these touch things -- your camera, your tooltips --
  that somebody may already have set up the way they like.

  First slice: the ones that only read and decorate. Nothing here destroys an
  item, cancels a buff or reparents a Blizzard frame; those come later and each
  deserves its own set of tests.
]]--

local OB = EquadisClassicOverhaul

--[[ **Every line this file writes says which part of the addon it came from.**

     One prefix, one colour, and the name after it -- so a message about the
     chat scan says so, rather than leaving the reader to work out which of
     eleven things is talking. See OB.Print. ]]--
local function Say(msg) OB.Print(msg, "QoL") end

OB.predicates = OB.predicates or {}

--[[ Nothing happens at a vendor, so there is nothing to report. Both halves have
     to be off: either one on is a reason to want the line. ]]--
OB.predicates.qol_no_vendor = function()
    local cfg = OB.profile.modules.qol
    return not cfg.autoRepair and not cfg.autoSell
end

local M = OB.RegisterModule({
    id = "qol",
    name = "Quality Of Life",

    feature = true,
    renders = "none",

    --[[ On, because the module itself does nothing: every behaviour inside it
         has its own switch and every one of those is off. Leaving the module
         disabled as well would mean two switches to reach one setting. ]]--
    defaultEnabled = true,

    defaults = {
        --[[ **Camera speed**, which is a CVar the client ships with no interface
             for. 180 is the default; the slider covers half to triple.

             Stored as the number rather than a multiplier, so what the panel
             shows is what the CVar holds and a bug report can be read. ]]--
        --[[ **The framerate readout, on at every login.** The client has one and
             forgets it every time, so somebody who wants to see it wants to see
             it again after every reload. Off, because it is one more thing on
             screen and the people who want it know they do. ]]--
        showMetrics = false,

        cameraSpeed = false,
        cameraYaw = 180,

        --[[ **Vendors.**

             Two chores nobody has ever enjoyed: paying the repair bill and
             emptying a bag of grey items one right-click at a time. Both are
             entirely mechanical, both are safe -- a repair is money you owed
             anyway and a sale can be bought back -- and neither is something the
             client will ever do for you. ]]--
        autoRepair = false,

        --[[ A ceiling, in gold, above which it asks nothing and does nothing.

             Not a hedge: repair costs are what they are and you pay them
             eventually. It is for the case where you are nearly broke and a full
             set of epics wants forty gold -- being emptied without warning at
             the wrong moment is the one way an automatic repair can hurt.

             Zero means no ceiling, which is what most people want once they
             have any money at all. ]]--
        repairLimit = 0,

        --[[ Grey items only. Not a setting, because "sell my whites too" is how
             people vendor their alt's heirloom, and the ones worth selling that
             are not grey are exactly the ones worth thinking about. Anything
             else goes on the list below, by name, deliberately. ]]--
        autoSell = false,

        --[[ On, and worth having on: something that spends and earns money on
             your behalf should say what it did. The one line it prints is the
             difference between trusting it and checking your bags. ]]--
        vendorReport = true,

        --[[ **The never-keep list**, which is the only thing in this addon that
             destroys anything.

             Off, and off is not a formality here. Everything else in this file
             can be undone: a repair is money you owed, a sale has a buyback
             window, a camera setting is a number. A destroyed item is gone, and
             no amount of care in the code changes that.

             The list itself is account-wide and lives outside the profile -- see
             config.lua. What is here is only the switch. ]]--
        autoTrash = false,

        --[[ **Zone level ranges on the world map.**

             The map does not say what level anything is, which is the one thing
             you want from it while levelling -- and the reason everybody has at
             some point had a browser open beside the game.

             On. It adds a few characters to a label that is already there and
             answers a question the map raises and refuses to settle. ]]--
        zoneLevels = true,
        zoneFaction = true,

        --[[ **Right-clicking a mob should not start an auto-attack.**

             1.12 has no setting for this and it is the single most common way to
             pull something you were not ready for: you right-click to turn the
             camera, the cursor passes over a mob, and you are in combat with it.
             A rogue loses stealth, a hunter loses distance, and everybody loses
             the pull they were setting up.

             Off, because it *is* how a lot of people attack -- but it is one of
             the first things anybody who has been caught by it goes looking
             for. ]]--
        noRightClickAttack = false,

        --[[ **Dismount when you cast something.**

             1.12 will not do this and it is the single most common way to waste
             three seconds: you press a spell, the client says "You are mounted",
             you press the mount, you press the spell again.

             Off, because it hooks the casting calls and anything in that path is
             a decision -- particularly next to a bar addon. ]]--
        dismount = false,

        --[[ **Destroy grey items below a value.**

             The rule is as simple as it sounds -- grey, and worth less than this,
             so it goes. What is not simple is the *value*: see `OB.SellValue`.
             1.12 will only tell you what something sells for while you are
             standing at a vendor, which is exactly where you do not need to
             know.

             So this destroys nothing whose price it has not learned. Not a
             fallback, a refusal: guessing at the value of something before
             destroying it is the one thing this must never do. ]]--
        trashJunk = false,

        --[[ In silver. Most grey drops are worth a few, so the useful range is
             small and the slider says silver rather than copper to keep the
             number readable. ]]--
        junkValue = 5,

        --[[ **Handing quests in without reading them**, from QuestHaste by
             WobLight (MIT -- see NOTICE).

             The case it is built for is the repeatable: an Alterac Valley
             turn-in you have read forty times, four clicks each. The design that
             makes it safe is that it is **per quest** -- you tell it which ones
             you have finished reading, and it leaves everything else alone. ]]--
        questHaste = false,

        --[[ Every quest, not just remembered ones. Off, and it should stay off
             for anybody levelling: the first read of a quest is the only chance
             to notice it is the wrong one. On, it is a repeatables machine. ]]--
        questAll = false,
    },

    options = {
        --[[ The client has a framerate readout and forgets it every login, so
             somebody who wants it reaches for the same key every time. ]]--
        { "Metrics", "__s_metrics", "section", "metrics" },

        { "Show Metrics", "showMetrics", "boolean" },

        { "Camera", "__s_camera", "section", "camera" },

        { "Set Camera Turn Speed", "cameraSpeed", "boolean" },
        { "Turn Speed", "cameraYaw", "slider", 90, 540, 10,
          nil, nil, "!cameraSpeed" },

        { "Vendors", "__s_vendor", "section", "vendor" },

        { "|cffff5555AutoSell Junk|r", "plannedAutoSellJunk", "boolean",
          nil, nil, nil, nil, nil, "!__notImplemented" },
        { "|cffff5555AutoRepair Equipment|r", "plannedAutoRepairEquipment", "boolean",
          nil, nil, nil, nil, nil, "!__notImplemented" },

        { "Never Keep", "__s_trash", "section", "trash" },

        { "Destroy These When They Arrive", "autoTrash", "boolean" },

        --[[ Bound to the saved variables rather than the profile: this is not a
             statement about how your interface looks on this character. See the
             `account` scope. ]]--
        { "Item Names (Comma Separated)", "@account:trash", "text", 200, 250,
          nil, nil, nil, "!autoTrash" },

        { "Destroy Cheap Junk", "trashJunk", "boolean" },
        { "Worth Less Than (Silver)", "junkValue", "slider", 1, 100, 1,
          nil, nil, "!trashJunk" },

        --[[ Trash mode, which is a mode and so says which one it is in. The two
             actions under it are only useful while something is selected, and
             they say how much. ]]--
        { "Choose Items In Your Bags", "__a_select", "action",
          function() OB.modules.qol:SetSelectMode(not OB.modules.qol:SelectMode()) end,
          function()
              if OB.modules.qol:SelectMode() then return "Stop Choosing Items" end
              return "Choose Items In Your Bags"
          end },

        { "Destroy What Is Chosen", "__a_dtrash", "action",
          function() OB.modules.qol:ConfirmDestroySelected() end,
          function()
              local n = table.getn(OB.modules.qol:SelectedItems())
              if n == 0 then return "Destroy What Is Chosen" end
              return "Destroy " .. n .. " Chosen Item" .. (n == 1 and "" or "s")
          end },

        { "Sell What Is Chosen", "__a_dsell", "action",
          function()
              local sold = OB.modules.qol:SellSelected()
              Say(sold > 0 and ("sold " .. sold .. ".")
                      or "nothing sold -- open a vendor first.")
          end },

        { "The Map", "__s_map", "section", "map" },

        { "Show Zone Level Ranges", "zoneLevels", "boolean" },
        { "Color Them By Faction", "zoneFaction", "boolean",
          nil, nil, nil, nil, nil, "!zoneLevels" },

        { "Attacking", "__s_attack", "section", "attack" },

        { "Do Not Attack On Right Click", "noRightClickAttack", "boolean" },

        { "Mounts", "__s_mount", "section", "mount" },

        { "Dismount To Cast", "dismount", "boolean" },

        { "Quests", "__s_quest", "section", "quest" },

        { "Hand In Remembered Quests", "questHaste", "boolean" },
        { "Every Quest, Not Just Remembered Ones", "questAll", "boolean",
          nil, nil, nil, nil, nil, "!questHaste" },

        --[[ The list is built by Control-clicking quests rather than typed, so
             the panel's job is to say how long it is and to offer the way back.
             A remembered quest is an automatic hand-in, and a list nobody can
             see or empty is a list that eventually surprises somebody. ]]--
        { "List Remembered Quests", "__a_qlist", "action",
          function() OB.PrintQuestList() end,
          function()
              local n = 0
              for _ in pairs(OB.quests) do n = n + 1 end
              if n == 0 then return "No Quests Remembered" end
              return "List " .. n .. " Remembered Quest" .. (n == 1 and "" or "s")
          end },

        { "Forget Every Remembered Quest", "__a_qreset", "action",
          function() OB.ForgetQuests() end },
    },

    events = { "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE",
               "UI_ERROR_MESSAGE",
               "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
               "PLAYER_ENTER_COMBAT",
               "GOSSIP_SHOW", "QUEST_GREETING" },
})

function M:Config()
    return OB.profile.modules.qol
end

-- ---------------------------------------------------------------------------
-- camera
-- ---------------------------------------------------------------------------

--[[ **A CVar with no interface.**

     `cameraYawMoveSpeed` is how fast the camera swings when you turn it, and the
     client ships it at 180 with no way to change it short of typing
     `/console`. Tripling it is the single most-recommended thing in every
     "vanilla feels sluggish" thread, and it has been a one-line fix nobody could
     find for twenty years.

     Only written when the switch is on. **Never written back on the way off**,
     because there is no honest value to restore: whatever it was before might
     have been set by another addon, by a `/console` line in someone's notes, or
     by the client's default, and this module cannot tell those apart. Off means
     "stops changing it", not "puts it back to 180" -- guessing 180 would quietly
     undo a setting somebody made deliberately. ]]--
function M:ApplyCamera()
    local cfg = self:Config()

    if not cfg.cameraSpeed then return end
    if type(SetCVar) ~= "function" then return end

    SetCVar("cameraYawMoveSpeed", cfg.cameraYaw)
end

-- ---------------------------------------------------------------------------
-- vendors
-- ---------------------------------------------------------------------------

--[[ Money, as the client writes it. Copper is dropped once there is gold to
     say, because "12g 40s 3c" is three facts where two were wanted. ]]--
function OB.Money(copper)
    copper = copper or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor(mod(copper, 10000) / 100)
    local bronze = mod(copper, 100)

    if gold > 0 then return gold .. "g " .. silver .. "s" end
    if silver > 0 then return silver .. "s " .. bronze .. "c" end
    return bronze .. "c"
end

--[[ The colour the client paints a worthless item. Asked of the client where it
     answers, because a server may have restyled its qualities, and only fallen
     back to the literal that has been correct since 2004. ]]--
local function junkColor()
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[0]
            and ITEM_QUALITY_COLORS[0].hex then
        return ITEM_QUALITY_COLORS[0].hex
    end

    return "|cff9d9d9d"
end

--[[ An item's name, out of its link. `|cff9d9d9d|Hitem:1234:0:0:0|h[Broken
     Fang]|h|r` is one string carrying quality, item id and name, and the name is
     the only part with a stable shape. ]]--
local function linkName(link)
    if not link then return nil end

    local _, _, name = string.find(link, "%[(.-)%]")
    return name
end


local function linkItemId(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    return tonumber(id)
end

--[[ **Marked for this visit only.**

     The list the panel cannot hold: things you have decided to sell *now*,
     which is a different act from deciding you never want them again. Cleared
     when the merchant window closes, because "this once" is what it means.

     Keyed by lowercased name so typing is forgiving. When the bag selection
     lands it writes into this same table -- the storage is the interface's
     problem, not this list's. ]]--
function M:MarkForSale(name)
    if not name or name == "" then return false end

    self.marked = self.marked or {}
    self.marked[string.lower(name)] = true

    return true
end

function M:ClearMarks()
    self.marked = nil
end

function M:IsMarked(name)
    if not self.marked or not name then return false end
    return self.marked[string.lower(name)] and true or false
end

--[[ Everything in your bags worth handing over: grey by colour, or named on the
     list for this visit.

     Bags 0 to 4 -- the backpack and four bags -- which is every bag a 1.12
     character has. ]]--
function M:SellableItems()
    local cfg = self:Config()
    local grey = junkColor()
    local out = {}

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag) or 0

        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)

            if link then
                local name = linkName(link)
                local isJunk = cfg.autoSell
                        and string.find(link, grey, 1, true) == 1

                if isJunk or self:IsMarked(name) then
                    table.insert(out, { bag = bag, slot = slot, name = name })
                end
            end
        end
    end

    return out
end

--[[ **`UseContainerItem` sells only while a merchant window is open. Everywhere
     else it *uses* the item.**

     That is the whole hazard of this feature, and it is not a small one: the
     same call that sells a Broken Fang at a vendor eats your food, opens your
     lockbox and equips your weapon anywhere else. A merchant frame that has
     already closed -- a stray event, a server hiccup, a second addon closing it
     first -- turns "sell my junk" into "use every grey item I own".

     So the check is not "did we get MERCHANT_SHOW", it is "is the window open
     right now", asked immediately before each call rather than once at the top. ]]--
function M:MerchantOpen()
    if not MerchantFrame then return false end
    if not MerchantFrame.IsVisible then return false end

    return MerchantFrame:IsVisible() and true or false
end

function M:SellJunk()
    local cfg = self:Config()
    if not (cfg.autoSell or self.marked) then return 0 end
    if not self:MerchantOpen() then return 0 end

    local items = self:SellableItems()
    local sold = 0

    for i = 1, table.getn(items) do
        --[[ Re-asked every time round. See above: one sale outside a merchant
             window is one item used, and the window can close mid-loop. ]]--
        if not self:MerchantOpen() then break end

        UseContainerItem(items[i].bag, items[i].slot)
        sold = sold + 1
    end

    return sold
end

--[[ The repair bill, paid if it is payable and small enough to be worth not
     asking about.

     Three refusals, and each is a different thing being wrong: the merchant does
     not repair, the bill is over your ceiling, or you cannot afford it. Only the
     middle one is a decision -- the others are facts -- but all three are worth
     saying out loud, because a repair that silently did not happen is a repair
     you find out about when your weapon breaks. ]]--
function M:Repair()
    local cfg = self:Config()
    if not cfg.autoRepair then return nil end
    if not self:MerchantOpen() then return nil end

    if type(CanMerchantRepair) ~= "function" or not CanMerchantRepair() then
        return nil
    end

    local cost = GetRepairAllCost()
    if not cost or cost <= 0 then return nil end

    if cfg.repairLimit > 0 and cost > cfg.repairLimit * 10000 then
        return nil, "over your " .. cfg.repairLimit .. "g limit"
    end

    if (GetMoney() or 0) < cost then
        return nil, "you cannot afford it"
    end

    RepairAllItems()

    return cost
end

function M:AtMerchant()
    if not OB.ModuleEnabled("qol") then return end

    local cfg = self:Config()
    local cost, refused = self:Repair()
    local sold = self:SellJunk()

    if not cfg.vendorReport then return end

    if cost then
        Say("repaired for " .. OB.Money(cost) .. ".")
    elseif refused then
        Say("did not repair: " .. refused .. ".")
    end

    if sold > 0 then
        Say("sold " .. sold .. " item" .. (sold == 1 and "" or "s")
                .. ". Buy anything back from the vendor if that was a mistake.")
    end
end

-- ---------------------------------------------------------------------------
-- never keep
-- ---------------------------------------------------------------------------

--[[ An item's quality, back out of the colour its link starts with. There is no
     call that answers this for a bag slot in 1.12 -- `GetContainerItemInfo` gives
     you a texture, a count and whether it is locked, and stops. ]]--
local function linkQuality(link)
    if not link or not ITEM_QUALITY_COLORS then return nil end

    for quality = 0, 5 do
        local colors = ITEM_QUALITY_COLORS[quality]

        if colors and colors.hex
                and string.find(link, colors.hex, 1, true) == 1 then
            return quality
        end
    end

    return nil
end

--[[ **The highest quality this will ever destroy.**

     One, which is white. Not a setting, and this is the guardrail rather than a
     preference: the list is typed by hand, and a hand-typed list of names is one
     slip away from matching something that took a month to get. Greens and above
     sell for real money, so nobody wants them destroyed *and* the client already
     has a confirmation box for exactly that reason.

     A name on the list that turns out to be a green is simply skipped, and said
     out loud, because silence would look like the list not working. ]]--
local TRASH_MAX_QUALITY = 1

-- ---------------------------------------------------------------------------
-- what a thing is worth
-- ---------------------------------------------------------------------------

--[[ **Where a vendor value comes from.**

     A merchant tooltip is the authority because private servers can change the
     vanilla database. When a merchant is open, ECO reads that real value and
     stores it account-wide under both the legacy item name and the item ID.

     Away from a merchant, `OB.Market` supplies the shared provider stack used by
     Tooltip too: learned ECO values, Aux, the embedded SellValue baseline, then
     ShaguTweaks. `GetSellValue` remains as compatibility for addons that expose
     only that old community API.

     An unknown or zero answer remains nil. Cheap-junk deletion never guesses. ]]--
local function moneyFromTooltip(prefix)
    local frame = getglobal(prefix .. "MoneyFrame1")
    if not frame then return nil end

    local total = 0
    local found = false
    local units = { GoldButton = 10000, SilverButton = 100, CopperButton = 1 }

    for suffix, worth in pairs(units) do
        local text = getglobal(prefix .. "MoneyFrame1" .. suffix .. "Text")
        local value = text and text.GetText and tonumber(text:GetText())

        if value then
            total = total + (value * worth)
            found = true
        end
    end

    if not found then return nil end
    return total
end

--[[ Anything a sell-value addon wrote as plain text, for the ones that add a
     line rather than a money frame. Read as "<n>g <n>s <n>c" in any combination,
     which is how every one of them writes it. ]]--
local function moneyFromText(text)
    if not text then return nil end

    local total, found = 0, false

    local _, _, g = string.find(text, "(%d+)%s*[gG]")
    local _, _, s = string.find(text, "(%d+)%s*[sS]")
    local _, _, c = string.find(text, "(%d+)%s*[cC]")

    if g then total = total + tonumber(g) * 10000 found = true end
    if s then total = total + tonumber(s) * 100 found = true end
    if c then total = total + tonumber(c) found = true end

    if not found then return nil end
    return total
end

--[[ Per item, not per stack. A stack of twenty is twenty times the answer, and
     the threshold is about the thing rather than about how many of it you
     happen to be carrying. ]]--
function OB.SellValue(name, bag, slot)
    if not name then return nil end

    local link = GetContainerItemLink(bag, slot)
    local itemId = linkItemId(link)

    -- A merchant observation is the highest authority because private servers
    -- can change vanilla prices. While the merchant is open, inspect the native
    -- bag tooltip before trusting any static/addon answer, then remember it.
    if MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() then
        local tip = OB.ScanTooltip()
        local value

        if type(tip.SetBagItem) == "function"
                and pcall(tip.SetBagItem, tip, bag, slot) then
            value = moneyFromTooltip("EquadisClassicOverhaulScanTooltip")

            if not value then
                for i = 1, (tip:NumLines() or 0) do
                    local line = OB.ScanLine(i)

                    if line and string.find(string.lower(line), "sell", 1, true) then
                        value = moneyFromText(line)
                        if value then break end
                    end
                end
            end

            -- The merchant tooltip reports the whole stack; ECO stores one item.
            if value and type(GetContainerItemInfo) == "function" then
                local _, count = GetContainerItemInfo(bag, slot)
                if count and count > 1 then value = math.floor(value / count) end
            end
        end

        if value and value > 0 then
            if OB.Market and OB.Market.LearnVendor and itemId then
                OB.Market:LearnVendor(itemId, value, name)
            else
                OB.prices[name] = value
            end
            return value
        end
    end

    -- Account-wide values observed on an earlier merchant visit beat every
    -- addon/static source, including values saved by pre-item-ID ECO builds.
    if itemId and OB.prices["item:" .. tostring(itemId)] then
        return OB.prices["item:" .. tostring(itemId)]
    end
    if OB.prices[name] then return OB.prices[name] end

    -- The shared provider stack is Aux first, then ECO's embedded SellValue
    -- baseline, then ShaguTweaks. This is also the path Tooltip uses.
    if itemId and OB.Market and OB.Market.GetVendor then
        local values = OB.Market:GetVendor(itemId)
        local value = values and tonumber(values.vendor)
        if value and value > 0 then return value end
    end

    -- Keep the long-standing compatibility hook for Auctioneer/other vendor
    -- addons that expose only GetSellValue and are not registered with Market.
    if type(GetSellValue) == "function" then
        local value = tonumber(GetSellValue(link))
        if value and value > 0 then return value end
    end

    return nil
end

--[[ Is this item cheap enough to be beneath keeping?

     Three ways to answer no, and only one of them is "it is expensive". Not grey
     is a no, and **not knowing is a no** -- which is the whole design. ]]--
function M:IsCheapJunk(name, bag, slot)
    local cfg = self:Config()
    if not cfg.trashJunk then return false end

    local link = GetContainerItemLink(bag, slot)
    if linkQuality(link) ~= 0 then return false end

    local value = OB.SellValue(name, bag, slot)
    if not value then return false end

    return value < (cfg.junkValue * 100)
end

--[[ Is this name on the never-keep list?

     **Whole names only, compared in full.** Never a substring, and that is the
     single most important line in this file: "Cloth" as a substring eats
     Runecloth, Mageweave and the Silk Cloth somebody is levelling tailoring
     with. The list is short and typed deliberately; matching it loosely to be
     helpful would be helpful exactly once. ]]--
function M:OnTrashList(name)
    if not name or name == "" then return false end

    local wanted = string.lower(name)

    for entry in string.gfind(OB.TrashList(), "[^,]+") do
        local trimmed = string.gsub(entry, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" and string.lower(trimmed) == wanted then return true end
    end

    return false
end

--[[ **Destroying one item, which is the one thing here that cannot be undone.**

     Three guards, in order, and each is protecting against a different way the
     obvious version goes wrong.

     `ClearCursor` first, because `PickupContainerItem` onto an occupied cursor
     *swaps* -- it would put whatever you were carrying into the bag and pick up
     the item, and the delete that follows would destroy the wrong thing. There
     is no way to ask 1.12 what is on the cursor, so the only safe move is to
     make sure the answer is nothing.

     Then the slot is re-read rather than trusted from the sweep. Bags shift: a
     `BAG_UPDATE` between building the list and acting on it moves everything
     after a removed stack up one, and a stale slot number is a correct-looking
     delete of the wrong item.

     Then the quality gate, for the reason above. ]]--
function M:DestroySlot(bag, slot, expected)
    if type(PickupContainerItem) ~= "function" then return false end
    if type(DeleteCursorItem) ~= "function" then return false end

    local link = GetContainerItemLink(bag, slot)
    local name = linkName(link)

    --[[ Not what we came for any more. Silent, because this is the normal
         outcome of bags having moved, not a problem worth a line of chat. ]]--
    if not name or name ~= expected then return false end

    local quality = linkQuality(link)

    if quality and quality > TRASH_MAX_QUALITY then
        Say("'" .. name .. "' is on your never-keep list but is not junk. "
                .. "Left alone -- remove it from the list or destroy it yourself.")
        return false
    end

    if CursorHasItem and CursorHasItem() then return false end
    if ClearCursor then ClearCursor() end

    PickupContainerItem(bag, slot)
    DeleteCursorItem()

    --[[ Always said, never a setting. Something that destroys an item without
         mentioning it is indistinguishable from an item that never dropped. ]]--
    Say("destroyed " .. name .. ".")

    return true
end

--[[ One pass over the bags.

     **One item per pass**, and then it stops. Deleting causes a `BAG_UPDATE`,
     which brings us straight back here with the bags in their new shape -- so
     the loop is the event rather than a `for`, and every delete acts on a slot
     that was read a moment ago rather than on a list assembled before anything
     moved. Slower by a frame per item and correct by construction. ]]--
function M:TrashPass()
    if not OB.ModuleEnabled("qol") then return false end

    local cfg = self:Config()

    --[[ Two ways in and they are separate switches: a named list, and a value
         rule. Neither implies the other -- somebody may want their Broken Fangs
         gone and every other grey kept, or the reverse. ]]--
    local byName = cfg.autoTrash and OB.TrashList() ~= ""
    if not (byName or cfg.trashJunk) then return false end

    --[[ Not while something is being dragged. The cursor is the player's. ]]--
    if CursorHasItem and CursorHasItem() then return false end

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag) or 0

        for slot = 1, slots do
            local name = linkName(GetContainerItemLink(bag, slot))

            if name then
                local wanted = (byName and self:OnTrashList(name))
                        or self:IsCheapJunk(name, bag, slot)

                if wanted and self:DestroySlot(bag, slot, name) then
                    return true
                end
            end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- picking things out of your bags
-- ---------------------------------------------------------------------------

--[[ **Trash mode: choose several things, then deal with all of them at once.**

     The chore this replaces is a bag full of quest leftovers and vendor trash
     after a dungeon, cleared one right-click-delete-confirm at a time.

     Kept entirely separate from the never-keep list, which is automatic and
     therefore guarded to the point of paranoia. This is not automatic. Every
     item in the selection is there because somebody clicked it, and the friction
     that belongs on an automatic list is just noise on a deliberate one.

     What replaces it is the confirmation at the end, which is the same shape as
     the client's own: it asks once, it says how many, and it names anything good
     enough that you might not have meant it. ]]--
function M:SelectMode()
    return self.selecting and true or false
end

function M:SetSelectMode(on)
    self.selecting = on and true or nil

    if not self.selecting then self:ClearSelection() end
    self:RefreshOverlays()
end

local function slotKey(bag, slot)
    return bag .. ":" .. slot
end

--[[ **The name is stored with the slot, and it is the point.**

     Bags shift. A stack sold, a quest item handed in, anything at all between
     choosing and acting moves everything after it up one -- so a slot number
     remembered from a click is a correct-looking reference to whatever is there
     now. Storing the name means the act can be checked against the intent, and
     the check happens immediately before the delete. ]]--
function M:ToggleSlot(bag, slot)
    local name = linkName(GetContainerItemLink(bag, slot))
    if not name then return false end

    self.selection = self.selection or {}

    local key = slotKey(bag, slot)

    if self.selection[key] then
        self.selection[key] = nil
    else
        self.selection[key] = { bag = bag, slot = slot, name = name }
    end

    self:RefreshOverlays()

    return true
end

function M:SlotSelected(bag, slot)
    if not self.selection then return false end
    return self.selection[slotKey(bag, slot)] ~= nil
end

function M:ClearSelection()
    self.selection = nil
    self:RefreshOverlays()
end

--[[ What is chosen, as a list, in a fixed order.

     `pairs` over the selection would answer in whatever order the table felt
     like, and a confirmation that named things in a different order each time
     would be harder to read than one that named them in bag order. ]]--
function M:SelectedItems()
    local out = {}

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag) or 0

        for slot = 1, slots do
            local chosen = self.selection and self.selection[slotKey(bag, slot)]
            if chosen then table.insert(out, chosen) end
        end
    end

    return out
end

--[[ Anything in the selection good enough that somebody might not have meant it.

     Green and up, which is the same line the client draws when it asks you to
     type the item's name before deleting it. Naming them in the confirmation is
     the whole safety measure here -- not refusing, because a deliberate choice
     is allowed to be a deliberate choice, but making sure the choice is seen. ]]--
function M:ValuableInSelection()
    local out = {}
    local items = self:SelectedItems()

    for i = 1, table.getn(items) do
        local link = GetContainerItemLink(items[i].bag, items[i].slot)
        local quality = linkQuality(link)

        if quality and quality > TRASH_MAX_QUALITY then
            table.insert(out, items[i].name)
        end
    end

    return out
end

--[[ Destroy everything chosen.

     **Backwards through the list**, which is the whole of why this is written
     out rather than reusing the never-keep sweep. Removing an item shifts every
     slot after it up one; walking forwards would leave every remaining
     reference pointing one slot too far along. Walking backwards, the slots
     ahead of the one being removed are the ones already dealt with.

     The name is still re-checked before each delete, because backwards is a
     defence against our own removals and not against anything else that moves a
     bag while this runs. ]]--
function M:DestroySelected()
    local items = self:SelectedItems()
    local gone = 0

    for i = table.getn(items), 1, -1 do
        if self:DestroySlot(items[i].bag, items[i].slot, items[i].name) then
            gone = gone + 1
        end
    end

    self:ClearSelection()

    return gone
end

--[[ The panel's route to destroying a selection, which is the slash command's
     route with the same warning in front of it.

     Written here rather than in the option row so both entry points get the
     naming of valuable items -- an action that skipped it because it was reached
     from a button would be the more dangerous of the two paths having the less
     careful behaviour. ]]--
function M:ConfirmDestroySelected()
    local items = self:SelectedItems()

    if table.getn(items) == 0 then
        Say("nothing chosen. Turn choosing on and click items in your bags.")
        return
    end

    local valuable = self:ValuableInSelection()

    if table.getn(valuable) > 0 then
        Say("about to destroy " .. table.getn(items) .. " items, including: "
                .. table.concat(valuable, ", ") .. ".")
    end

    StaticPopup_Show("EQOB_TRASH_SELECTED")
end

--[[ Or hand them to a vendor instead, which is the better answer whenever the
     vendor will take them.

     Written into the same marks the panel-free `/eqob sell` uses, so there is
     one idea of "sell these now" rather than two. ]]--
function M:SellSelected()
    local items = self:SelectedItems()

    for i = 1, table.getn(items) do
        self:MarkForSale(items[i].name)
    end

    local sold = self:SellJunk()
    self:ClearSelection()

    return sold
end

-- ---------------------------------------------------------------------------
-- the highlight on the bag slot
-- ---------------------------------------------------------------------------

--[[ **Which button is showing which bag slot**, which is a question rather than
     a lookup: 1.12 reuses the five container frames for whichever bags happen to
     be open, so `ContainerFrame3` is not bag three -- it is the third bag you
     opened, and it will be a different one tomorrow.

     The frame carries its bag id and each button carries its slot, so the answer
     is asked of the frames every time rather than cached. Caching it is the bug
     that makes a highlight land on the wrong item after you close one bag. ]]--
function M:RefreshOverlays()
    if type(getglobal) ~= "function" then return end

    for frame = 1, 5 do
        local container = getglobal("ContainerFrame" .. frame)

        if container and container.GetID and container:IsVisible() then
            local bag = container:GetID()

            for button = 1, 20 do
                local item = getglobal("ContainerFrame" .. frame
                        .. "Item" .. button)

                if item and item.GetID then
                    self:MarkButton(item, bag, item:GetID())
                end
            end
        end
    end
end

--[[ One button's highlight, created the first time it is needed.

     Created on the button rather than pooled, because a container button lives
     as long as the client does -- there is nothing to reclaim, and a pool would
     be bookkeeping in exchange for nothing. ]]--
function M:MarkButton(button, bag, slot)
    if not button.eqobMark then
        if not button.CreateTexture then return end

        local mark = button:CreateTexture(nil, "OVERLAY")
        mark:SetAllPoints(button)
        mark:SetTexture(1, 0.2, 0.2, 0.35)
        mark:Hide()

        button.eqobMark = mark
    end

    if self:SelectMode() and self:SlotSelected(bag, slot) then
        button.eqobMark:Show()
    else
        button.eqobMark:Hide()
    end
end

--[[ **Clicking a bag slot while the mode is on chooses it instead of using it.**

     Hooked on the global the way the casting calls are, and with the same known
     hole: a bag replacement that took its own reference at load never reaches
     ours. The mode is read inside, so with it off every click goes straight
     through untouched -- which is what makes hooking this acceptable at all. ]]--
function M:InstallBagClicks()
    if self.bagClicksInstalled then return end
    if type(ContainerFrameItemButton_OnClick) ~= "function" then return end

    self.bagClicksInstalled = true

    local original = ContainerFrameItemButton_OnClick

    ContainerFrameItemButton_OnClick = function(button, ignoreShift)
        local m = OB.modules.qol

        if m:SelectMode() and this and this.GetID and this.GetParent then
            local parent = this:GetParent()

            if parent and parent.GetID then
                m:ToggleSlot(parent:GetID(), this:GetID())
                return
            end
        end

        return original(button, ignoreShift)
    end
end

-- ---------------------------------------------------------------------------
-- what level a zone is for
-- ---------------------------------------------------------------------------

--[[ **The world map does not say what level anything is.**

     Which is the one thing you want from it while levelling, and the reason
     everybody has at some point had a browser open beside the game to find out
     whether Desolace comes before or after Thousand Needles.

     From LevelRange by Bull3t and the several hands after him -- see NOTICE, and
     note that its licence is stated in its own source rather than in a file,
     which is why it is quoted there in full.

     The ranges are its table, including the zones Turtle added. That is the half
     that could not have been written from memory: most of them exist nowhere
     else.

     Faction rides with the range because one look answers both questions -- a
     horde zone is somewhere an alliance character can go and should think about
     first. ]]--
--[[ Named `zoneRanges` rather than `zoneLevels` because the *setting* is
     `zoneLevels`, and one word meaning both the switch and the data it reads is
     how somebody ends up reading the wrong one. ]]--
OB.zoneRanges = {
    ["Alterac Mountains"] = { 30, 40, "contested" },
    ["Arathi Highlands"] = { 30, 40, "contested" },
    ["Ashenvale"] = { 18, 30, "contested" },
    ["Azshara"] = { 45, 55, "contested" },
    ["Badlands"] = { 35, 45, "contested" },
    ["Balor"] = { 29, 34, "contested" },
    ["Blackstone Island"] = { 1, 10, "horde" },
    ["Blasted Lands"] = { 45, 55, "contested" },
    ["Burning Steppes"] = { 50, 58, "contested" },
    ["Darkshore"] = { 10, 20, "alliance" },
    ["Deadwind Pass"] = { 55, 60, "contested" },
    ["Desolace"] = { 30, 40, "contested" },
    ["Dun Morogh"] = { 1, 10, "alliance" },
    ["Durotar"] = { 1, 10, "horde" },
    ["Duskwood"] = { 18, 30, "contested" },
    ["Dustwallow Marsh"] = { 35, 45, "contested" },
    ["Eastern Plaguelands"] = { 53, 60, "contested" },
    ["Elwynn Forest"] = { 1, 10, "alliance" },
    ["Felwood"] = { 48, 55, "contested" },
    ["Feralas"] = { 40, 50, "contested" },
    ["Gillijim's Isle"] = { 48, 53, "contested" },
    ["Gilneas"] = { 39, 46, "contested" },
    ["Grim Reaches"] = { 33, 38, "contested" },
    ["Hillsbrad Foothills"] = { 20, 30, "contested" },
    ["Hyjal"] = { 58, 60, "contested" },
    ["Lapidis Isle"] = { 48, 53, "contested" },
    ["Loch Modan"] = { 10, 20, "alliance" },
    ["Moonglade"] = { 1, 60, "contested" },
    ["Mulgore"] = { 1, 10, "horde" },
    ["Northwind"] = { 28, 34, "contested" },
    ["Redridge Mountains"] = { 15, 25, "contested" },
    ["Scarlet Enclave"] = { 55, 60, "contested" },
    ["Searing Gorge"] = { 43, 50, "contested" },
    ["Silithus"] = { 55, 60, "contested" },
    ["Silverpine Forest"] = { 10, 20, "horde" },
    ["Stonetalon Mountains"] = { 15, 27, "contested" },
    ["Stranglethorn Vale"] = { 30, 45, "contested" },
    ["Swamp of Sorrows"] = { 35, 45, "contested" },
    ["Tanaris"] = { 40, 50, "contested" },
    ["Tel'Abim"] = { 54, 60, "contested" },
    ["Teldrassil"] = { 1, 10, "alliance" },
    ["Thalassian Highlands"] = { 1, 10, "alliance" },
    ["The Barrens"] = { 10, 25, "horde" },
    ["The Hinterlands"] = { 40, 50, "contested" },
    ["Thousand Needles"] = { 25, 35, "contested" },
    ["Tirisfal Glades"] = { 1, 10, "horde" },
    ["Un'Goro Crater"] = { 48, 55, "contested" },
    ["Western Plaguelands"] = { 51, 58, "contested" },
    ["Westfall"] = { 10, 20, "alliance" },
    ["Wetlands"] = { 20, 30, "contested" },
    ["Winterspring"] = { 55, 60, "contested" },
}

--[[ What to say about a zone, or nothing at all.

     nil for a city, a battleground, or anything not in the table -- and the
     label is then left exactly as the client drew it. That is the right answer
     rather than a fallback: a zone with no level range is not a zone with an
     unknown one, it is a zone the question does not apply to. ]]--
function OB.ZoneLevelText(zone)
    local entry = zone and OB.zoneRanges[zone]
    if not entry then return nil end

    local range = entry[1] .. "-" .. entry[2]

    --[[ One number where the range is one level wide: "60-60" spends two
         characters saying one thing. ]]--
    if entry[1] == entry[2] then range = tostring(entry[1]) end

    return range, entry[3]
end
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- attacking by accident

--[[ **Where the range is drawn: onto the label the client already writes.**

     LevelRange makes a tooltip of its own and manages showing and hiding it.
     This appends to `WorldMapFrameAreaLabel` instead, which is one font string
     the client is already updating as the cursor moves -- no frame to make, no
     tooltip to place, and nothing to hide when the cursor leaves, because the
     client blanks the label itself.

     **Hooked once, and the original runs first.** The client rewrites the label
     every frame from its own hit test, so anything written before it is thrown
     away. Appending after is the only order that survives. ]]--
local FACTION_COLOR = {
    alliance = "|cff6699ff",
    horde = "|cffff5555",
    contested = "|cffffcc44",
}

--[[ **Guarded on a global, not on the module.**

     Every other hook here guards on a field of `self`, and in the game that is
     the same thing: the addon loads once, so the module table and the wrapped
     global appear together and never again.

     It is not the same thing under a test harness, which boots the addon many
     times against one set of frames. The module table is new each time and the
     global still carries the previous wrapper, so the hook stacks -- and each
     layer closes over the namespace it was built with, reading a profile that
     was replaced two boots ago. A setting switched off in the current one is
     still on in theirs.

     That is not only a harness problem. It is exactly what the Escape menu
     button did, and there it duplicated a button on every reload. A guard
     belongs on the durable thing, and here the durable thing is the global. ]]--
function M:InstallMapLabel()
    if EquadisOverhaulMapHooked then return end
    if type(WorldMapButton_OnUpdate) ~= "function" then return end

    EquadisOverhaulMapHooked = true

    local original = WorldMapButton_OnUpdate

    WorldMapButton_OnUpdate = function(elapsed)
        original(elapsed)

        --[[ Reached through the *current* namespace rather than the one this
             closure was built with, so a reload cannot leave the hook talking to
             a profile that has been replaced. ]]--
        local m = EquadisClassicOverhaul.modules.qol
        if m then m:LabelZone() end
    end
end

--[[ The label, with the range on the end of it.

     Read back off the font string rather than tracked, because the client owns
     it and the only reliable statement about its contents is what it currently
     says. A remembered zone name would be a second source of truth that goes
     stale the moment anything else writes there. ]]--
function M:LabelZone()
    if not OB.ModuleEnabled("qol") then return false end
    if not self:Config().zoneLevels then return false end

    local label = getglobal("WorldMapFrameAreaLabel")
    if not label or not label.GetText then return false end

    local text = label:GetText()
    if not text or text == "" then return false end

    --[[ Turtle ships at least one zone whose name carries a trailing space --
         "Northwind " -- which matches nothing. Trimmed here rather than in the
         table, so the table stays the zone names as everybody writes them. ]]--
    local zone = string.gsub(text, "^%s*(.-)%s*$", "%1")

    --[[ Already labelled. The client rewrites this every frame, so without the
         check the range would be appended sixty times a second until the string
         was longer than the screen. ]]--
    if string.find(zone, "|cff", 1, true) then return false end

    local range, side = OB.ZoneLevelText(zone)
    if not range then return false end

    local color = ""
    if self:Config().zoneFaction then color = FACTION_COLOR[side] or "" end

    label:SetText(zone .. "  " .. color .. range .. (color ~= "" and "|r" or ""))
    return true
end
-- ---------------------------------------------------------------------------

--[[ **Right-clicking a mob starts an auto-attack, and 1.12 has no setting for
     it.**

     It is the commonest way to pull something you were not ready for: you
     right-click to turn the camera, the cursor crosses a mob, and you are in
     combat. A rogue loses stealth, a hunter loses their opener, and everybody
     loses the pull they were setting up.

     **The client does this in C and there is no hook on it.** What there *is* is
     a CVar -- `AutoInteract` -- which governs whether right-clicking a unit
     interacts with it at all. Setting it to zero stops the attack, and it stops
     right-click-to-loot and right-click-to-talk with it, which is the trade and
     is why this is a switch rather than a default.

     Written only when asked and **never written back on the way off**, for the
     reason the camera setting gives: whatever it was before might have been set
     by another addon or by a `/console` line in somebody's notes, and this
     cannot tell those apart. Off means "stops changing it". ]]--
function M:ApplyRightClick()
    local cfg = self:Config()

    if not cfg.noRightClickAttack then return false end
    if type(SetCVar) ~= "function" then return false end

    SetCVar("AutoInteract", "0")
    return true
end

--[[ **Telling an attack you asked for from one you did not.**

     This is the whole difficulty. Stopping every auto-attack would be useless --
     the point is to keep the ones you meant. So the two ways of meaning it are
     hooked and they set a flag: pressing an attack on a bar, and `/attack` or
     any macro that runs `AttackTarget`.

     A right-click reaches the client's C code and sets no flag, which is exactly
     what distinguishes it. The absence is the signal.

     Installed once and never removed, the same rule as every other hook here. ]]--
function M:InstallAttackWatch()
    if self.attackWatchInstalled then return end
    self.attackWatchInstalled = true

    if type(AttackTarget) == "function" then
        local original = AttackTarget

        AttackTarget = function()
            --[[ Set *before* the call, because the client can raise the combat
                 event synchronously inside it -- and a flag set afterwards would
                 arrive too late to protect the attack that set it. ]]--
            OB.modules.qol.attackWanted = true
            return original()
        end
    end

    --[[ An attack pressed on a bar. `UseAction` is already hooked for
         dismounting, so this rides along there rather than wrapping it twice --
         two wrappers on one global is how an order nobody chose gets built. ]]--
end

--[[ **And the half a CVar cannot cover: the attack that has already started.**

     `AutoInteract` stops the interaction, and on some builds a right-click still
     reaches the auto-attack through a different path. The client announces every
     swing start, so the belt-and-braces answer is to stop one that began while
     the setting was on and nothing else asked for it.

     Only when the player did not press anything. `self.attackWanted` is set by
     the casting hooks -- an attack somebody asked for is an attack they get. ]]--
function M:OnAttackStarted()
    if not OB.ModuleEnabled("qol") then return false end
    if not self:Config().noRightClickAttack then return false end

    --[[ Asked for, so left alone. The flag is cleared by whoever set it on the
         next event rather than here, because an attack command can produce more
         than one start. ]]--
    if self.attackWanted then return false end

    if type(AttackTarget) ~= "function" then return false end

    --[[ `AttackTarget` toggles, so calling it while attacking stops it. That is
         the only way 1.12 offers to cancel one. ]]--
    AttackTarget()
    return true
end

-- ---------------------------------------------------------------------------
-- mounts
-- ---------------------------------------------------------------------------

--[[ **1.12 has no `Dismount()`. A mount is a buff, and you get off it by
     cancelling the buff.**

     Which means finding it, and a 1.12 buff has no id and no reliable name --
     only an icon path. Every buff test in this addon is a texture comparison for
     that reason; see `OB.HasPlayerBuff`.

     Nearly every mount in the game uses `Ability_Mount_<something>`, which makes
     the prefix a good test rather than a guess. **It is still a prefix test**:
     a class mount or a server's own mount with an icon outside that family will
     not be recognised, and the failure is quiet -- the cast goes out and the
     client refuses it, which is exactly what happens today with this switched
     off. Nothing is made worse by not recognising a mount.

     `IsMounted` is asked for first where it exists. It is a 2.0 call and absent
     from a plain 1.12 client, but several private-server clients backport it,
     and a real answer beats a good heuristic every time. ]]--
local MOUNT_ICON = "ability_mount"

function M:MountBuff()
    if type(GetPlayerBuffTexture) ~= "function" then return nil end

    local i = 0
    local texture = GetPlayerBuffTexture(i)

    while texture do
        if string.find(string.lower(texture), MOUNT_ICON, 1, true) then
            return i, texture
        end

        i = i + 1
        texture = GetPlayerBuffTexture(i)
    end

    return nil
end

--[[ Mounted, by whatever means the client will tell us.

     The real call wins when there is one. When there is not, a mount buff is the
     answer, and when there is no mount buff either the answer is no -- which is
     right far more often than it is wrong, and wrong in the harmless direction. ]]--
function M:Mounted()
    if type(IsMounted) == "function" then
        return IsMounted() and true or false
    end

    return self:MountBuff() ~= nil
end

function M:Dismount()
    local index, texture = self:MountBuff()

    if not index then return false end
    if type(CancelPlayerBuff) ~= "function" then return false end

    CancelPlayerBuff(index)
    self.lastMount = texture

    return true
end

--[[ **Should this cast dismount you?**

     Everything except the mount itself. Pressing your mount button while mounted
     is already how you get off, and intercepting it would cancel the buff and
     then re-cast the mount -- leaving you exactly where you started, one global
     cooldown poorer.

     Told apart by icon, which is the only identity available: the action's
     texture against the buff's. They are the same art for every mount in the
     game, which is what makes this work at all. ]]--
function M:ShouldDismount(texture)
    if not OB.ModuleEnabled("qol") then return false end
    if not self:Config().dismount then return false end
    if not self:Mounted() then return false end

    if texture then
        local _, mount = self:MountBuff()

        if mount and string.lower(texture) == string.lower(mount) then
            return false
        end
    end

    return true
end

--[[ **Hooked once, on the globals, and the hole is known.**

     `range.lua` found this the hard way and wrote it down: replacing the global
     `UseAction` only catches a press if every bar addon in the chain still calls
     the global at press time. One that took its own reference at load never
     reaches ours, and there is nothing to be done about that from here.

     So the globals are hooked -- which covers the default bars, macros, the
     spellbook and most bar replacements -- and `UI_ERROR_MESSAGE` catches the
     rest after the fact. That fallback cannot save the first press, but it means
     the second one works rather than repeating the same refusal. ]]--
function M:InstallDismount()
    if self.dismountInstalled then return end
    self.dismountInstalled = true

    if type(UseAction) == "function" then
        local original = UseAction

        UseAction = function(slot, checkCursor, onSelf)
            local m = OB.modules.qol
            local texture

            if type(GetActionTexture) == "function" then
                texture = GetActionTexture(slot)
            end

            if m:ShouldDismount(texture) then m:Dismount() end

            --[[ A button press is a deliberate act, so whatever it starts is
                 wanted -- including an auto-attack. See InstallAttackWatch. ]]--
            m.attackWanted = true

            return original(slot, checkCursor, onSelf)
        end
    end

    --[[ Macros and everything typed. No texture to compare against here -- there
         is no name-to-icon call in 1.12 -- so `/cast <your mount>` while mounted
         will dismount and then mount again. Rare enough to accept, and the cost
         of getting it wrong is a wasted global cooldown rather than anything
         that matters. ]]--
    if type(CastSpellByName) == "function" then
        local original = CastSpellByName

        CastSpellByName = function(name, onSelf)
            local m = OB.modules.qol
            if m:ShouldDismount(nil) then m:Dismount() end

            return original(name, onSelf)
        end
    end
end

--[[ The client refusing a cast because you are mounted. Whatever the wording,
     the shape is the same, so this matches on the mounted-ness rather than on a
     string -- there is more than one refusal that says it, and the exact
     globals differ between 1.12 and the servers built on it. ]]--
function M:OnCastRefused(message)
    if not self:Config().dismount then return false end
    if not message then return false end

    if not string.find(string.lower(message), "mounted", 1, true) then
        return false
    end

    return self:Dismount()
end

-- ---------------------------------------------------------------------------
-- quests
-- ---------------------------------------------------------------------------

--[[ **Handing in a quest you have already read**, from QuestHaste by WobLight.

     Ported rather than copied -- the storage, the settings and the event
     dispatch all belong to this addon's shapes -- but the design is WobLight's
     and it is the good part. Two decisions in particular are worth keeping
     exactly as they are.

     **It is per quest.** The obvious version of this feature accepts and hands
     in everything, and it is the version that makes you miss the one quest you
     had not read. So the list is opt-in, a quest at a time, and the thing it is
     really for -- an Alterac Valley turn-in you have read forty times -- is on
     it after the first Ctrl-click.

     **The modifiers are a full grammar rather than a switch.** Ctrl remembers
     and proceeds, Alt forgets, Shift inverts, nothing does what the list says.
     Four behaviours on keys you are already holding, and no interface at all in
     the moment you need them. ]]--
function M:QuestRemembered(title, what)
    if not title then return false end

    if self:Config().questAll then return true end

    local saved = OB.quests[title]
    return (saved and saved[what]) and true or false
end

function M:RememberQuest(title, what)
    if not title then return end

    OB.quests[title] = OB.quests[title] or {}
    OB.quests[title][what] = true

    Say("remembering '" .. title .. "'.")
end

--[[ Forgetting one half leaves the other. A quest you auto-accept but want to
     read the reward text for is a real thing, and dropping the whole entry
     because one half was cleared would quietly undo the other. ]]--
function M:ForgetQuest(title, what)
    if not title then return end

    local saved = OB.quests[title]
    if not saved then return end

    saved[what] = nil

    if not saved.accept and not saved.complete then
        OB.quests[title] = nil
    end

    Say("forgot '" .. title .. "'.")
end

--[[ **What the modifiers say to do**, in one place because all three quest
     frames ask the same question.

     Returns "forget" for Alt, or a boolean: whether to go ahead.

     The `~=` is exclusive-or and is the whole of Shift. Remembered and no Shift
     goes ahead; not remembered and Shift goes ahead; the other two do not. That
     makes Shift "do the opposite of whatever the list says", which is both a way
     to push one unremembered quest through and a way to hold a remembered one
     while you read it. ]]--
function M:QuestIntent(title, what)
    if IsAltKeyDown() then return "forget" end

    if IsControlKeyDown() then
        self:RememberQuest(title, what)
        return true
    end

    local remembered = self:QuestRemembered(title, what)
    local shift = IsShiftKeyDown() and true or false

    return remembered ~= shift
end

function M:QuestActive()
    if not OB.ModuleEnabled("qol") then return false end
    return self:Config().questHaste and true or false
end

--[[ The quest text with an Accept button: the first window of a hand-out. ]]--
function M:OnQuestDetail()
    if not self:QuestActive() then return end

    local title = GetTitleText()
    local intent = self:QuestIntent(title, "accept")

    if intent == "forget" then
        self:ForgetQuest(title, "accept")
        return
    end

    if intent then
        --[[ Remembered across the window, so a quest pushed through by hand
             carries on being pushed through at the next step rather than
             stopping halfway. WobLight's, and it is what makes Shift usable. ]]--
        self.questInFlight = title
        AcceptQuest()
    else
        self.questInFlight = nil
    end
end

--[[ The "have you brought it" window, with a Continue button. ]]--
function M:OnQuestProgress()
    if not self:QuestActive() then return end

    local title = GetTitleText()
    local intent = self:QuestIntent(title, "complete")

    if intent == "forget" then
        self:ForgetQuest(title, "complete")
        return
    end

    --[[ Not completable means the items are not there. Pressing on would be
         asking the client to do something it will refuse. ]]--
    if (self.questInFlight == title or intent) and IsQuestCompletable() then
        self.questInFlight = title
        CompleteQuest()
    else
        self.questInFlight = nil
    end
end

--[[ The reward window, which is the one place this must be careful.

     **Never when there is a choice of reward.** `GetQuestReward(index)` takes
     one, and picking for somebody is picking wrong -- the whole point of a
     choice is that only they know which. So a quest with rewards to choose
     between stops here and waits, however firmly it is on the list.

     Not a setting. There is no version of "pick a reward for me" that is a good
     idea, and offering it would be offering somebody a way to lose an item they
     wanted. ]]--
function M:OnQuestComplete()
    if not self:QuestActive() then return end

    local title = GetTitleText()
    local intent = self:QuestIntent(title, "complete")

    if intent == "forget" then
        self:ForgetQuest(title, "complete")
        return
    end

    if (self.questInFlight == title or intent) and GetNumQuestChoices() == 0 then
        GetQuestReward()
    end

    self.questInFlight = nil
end

-- ---------------------------------------------------------------------------
-- the list of quests an NPC is offering
-- ---------------------------------------------------------------------------

--[[ 1.12 answers a gossip quest list as one flat run of title, level, title,
     level. The odd entries are the titles. ]]--
local function titlesFrom(list)
    local out = {}

    for i = 1, table.getn(list) do
        if mod(i, 2) == 1 then table.insert(out, list[i]) end
    end

    return out
end

--[[ **Which of an NPC's quests to pick**, in the order somebody would.

     A completed quest first, because that is a reward waiting. Then anything
     remembered, available before active -- taking a repeatable is what starts
     the loop. Then the rest, which only matters with "every quest" on.

     Returns the kind and the index, or nothing at all, so the caller does the
     selecting and this only decides. ]]--
function M:BestQuest(available, active)
    for i = 1, table.getn(available) do
        if self:QuestRemembered(available[i], "accept") then
            return "available", i
        end
    end

    for i = 1, table.getn(active) do
        if self:QuestRemembered(active[i], "complete") then
            return "active", i
        end
    end

    return nil
end

--[[ Shift on an NPC's menu takes the obvious quest.

     Shift rather than automatic, and this is deliberate: a gossip menu is also
     how you reach a flight master, a bank and a trainer, and an addon that
     jumped to a quest every time you opened one would be taking the menu away. ]]--
function M:OnGossip(available, active, pickAvailable, pickActive)
    if not self:QuestActive() then return false end
    if not IsShiftKeyDown() then return false end

    local kind, index = self:BestQuest(available, active)
    if not kind then return false end

    if kind == "available" then
        pickAvailable(index)
    else
        pickActive(index)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- binding
-- ---------------------------------------------------------------------------

function M:OnEvent()
    if event == "QUEST_DETAIL" then self:OnQuestDetail() return end
    if event == "QUEST_PROGRESS" then self:OnQuestProgress() return end
    if event == "QUEST_COMPLETE" then self:OnQuestComplete() return end

    if event == "GOSSIP_SHOW" then
        self:OnGossip(titlesFrom({ GetGossipAvailableQuests() }),
                titlesFrom({ GetGossipActiveQuests() }),
                SelectGossipAvailableQuest, SelectGossipActiveQuest)
        return
    end

    --[[ The other kind of NPC menu -- no gossip text, just a list. Same
         decision, different four calls to read it with. ]]--
    if event == "QUEST_GREETING" then
        local available, active = {}, {}

        for i = 1, GetNumAvailableQuests() do
            table.insert(available, GetAvailableTitle(i))
        end

        for i = 1, GetNumActiveQuests() do
            table.insert(active, GetActiveTitle(i))
        end

        self:OnGossip(available, active, SelectAvailableQuest, SelectActiveQuest)
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        self:OnCastRefused(arg1)
        return
    end

    --[[ The client announcing that a swing has begun, which is the only notice
         there is that something started attacking. ]]--
    if event == "PLAYER_ENTER_COMBAT" then
        self:OnAttackStarted()
        self.attackWanted = nil
        return
    end

    if event == "BAG_UPDATE" then
        self:TrashPass()
        return
    end

    if event == "MERCHANT_SHOW" then
        self:AtMerchant()
        return
    end

    if event == "MERCHANT_CLOSED" then
        self:ClearMarks()
        return
    end
end

--[[ **The framerate readout, on at every login.**

     The client has one and forgets it every time: `ToggleFramerate` flips it and
     nothing persists the answer, so somebody who wants to see their framerate
     wants to see it *again* after every reload, and reaches for the same key
     every time.

     **Turned on, never off.** The setting means "have it on when I arrive"
     rather than "have it on always" -- so switching the display off by hand
     mid-session stays off, which is what somebody pressing the key is asking
     for. Unticking the setting stops it coming back next time and leaves this
     session alone, for the same reason.

     Read by asking the frame rather than by remembering: another addon may have
     shown it already, and toggling a shown display would turn it off. ]]--
function M:ApplyMetrics()
    if not self:Config().showMetrics then return false end
    if self.metricsDone then return false end

    --[[ Once per session. `OnBind` runs again on every settings change, and a
         toggle called twice is a toggle that undid itself. ]]--
    self.metricsDone = true

    local frame = getglobal("FramerateFrame")
    if frame and frame:IsShown() then return false end

    if type(ToggleFramerate) ~= "function" then return false end

    ToggleFramerate()

    return true
end


function M:OnBind()
    self:InstallDismount()
    self:InstallBagClicks()
    self:InstallAttackWatch()
    self:InstallMapLabel()
    self:ApplyCamera()
    self:ApplyRightClick()
    self:ApplyMetrics()
end

function M:OnStyle()
    self:ApplyCamera()
    self:ApplyRightClick()
end

function M:OnDraw() end
