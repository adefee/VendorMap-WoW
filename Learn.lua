local _, ns = ...

local Learn = {}
ns.Learn = Learn

local pendingGossipInnkeeper = false
local pendingProfessionTrainer = false

-- Tradegoods "Cooking" subclass (raw meat/fish). Treated as food, not reagents.
local TRADEGOODS_COOKING = 8

-- Basic vendor gear (white/gray axes, armor on repair/general vendors) is not a
-- transmog signal. Only Uncommon+ appearance gear tags a shop as transmog.
local TRANSMOG_MIN_QUALITY = (Enum and Enum.ItemQuality and Enum.ItemQuality.Uncommon) or 2

local function IsSecret(value)
    return issecretvalue and value ~= nil and issecretvalue(value)
end

local function CanUse(value)
    if value == nil then
        return false
    end
    if canaccessvalue then
        return canaccessvalue(value)
    end
    return not IsSecret(value)
end

--- Prefer npc, then target (stable UI sometimes clears npc).
local function InteractionUnit()
    if UnitExists("npc") then
        return "npc"
    end
    if UnitExists("target") then
        return "target"
    end
    return "npc"
end

--- Safe NPC id extraction. Midnight may return a secret UnitGUID in instances.
local function GetNpcIDFromUnit(unit)
    local guid = UnitGUID(unit)
    if not guid or not CanUse(guid) then
        return nil
    end

    if C_CreatureInfo and C_CreatureInfo.GetCreatureID then
        local ok, creatureID = pcall(C_CreatureInfo.GetCreatureID, guid)
        if ok and creatureID then
            return tonumber(creatureID)
        end
    end

    local ok, unitType, _, _, _, _, npcID = pcall(strsplit, "-", guid)
    if not ok or not CanUse(unitType) or not CanUse(npcID) then
        return nil
    end
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

local function SafeUnitName(unit, fallback)
    local ok, name = pcall(UnitName, unit)
    if not ok or type(name) ~= "string" or name == "" or not CanUse(name) then
        return fallback or "Unknown Vendor"
    end
    return name
end

local function SafeLower(text)
    if not text or not CanUse(text) then
        return nil
    end
    local ok, lower = pcall(string.lower, text)
    if ok then
        return lower
    end
    return nil
end

local function SubtitleFromTooltipData(data, name)
    if not data or not ns.SubtitleFromTooltipData then
        return nil
    end
    local text = ns.SubtitleFromTooltipData(data, name)
    if text and CanUse(text) and text ~= "" then
        return text
    end
    return nil
end

--- NPC specialty/title under the name, or nil.
local function GetUnitSubtitle(unit)
    if not unit or not C_TooltipInfo then
        return nil
    end
    local name = SafeUnitName(unit, nil)

    if C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and data then
            local text = SubtitleFromTooltipData(data, name)
            if text then
                return text
            end
        end
    end

    -- Fallback: creature hyperlink scan (same path Names uses).
    local npcID = GetNpcIDFromUnit(unit)
    if npcID and C_TooltipInfo.GetHyperlink then
        local link = ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and data then
            local text = SubtitleFromTooltipData(data, name)
            if text then
                return text
            end
        end
    end
    return nil
end

local function GetPlayerMapPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and y and CanUse(x) and CanUse(y) then
                return mapID, x, y
            end
        end
    end

    if not mapID then
        return nil
    end
    local ok, unitY, unitX, _, instanceID = pcall(UnitPosition, "player")
    if not ok or not unitX or not unitY or not instanceID then
        return nil
    end
    if not CanUse(unitX) or not CanUse(unitY) then
        return nil
    end
    local _, mapPos = C_Map.GetMapPosFromWorldPos(instanceID, CreateVector2D(unitX, unitY), mapID)
    if not mapPos then
        return nil
    end
    return mapID, mapPos.x, mapPos.y
end

local function ItemClassIDs(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
        return classID, subClassID
    end
    if GetItemInfoInstant then
        local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
        return classID, subClassID
    end
    return nil, nil
end

local function FoodDrinkSubclass()
    local ecs = Enum and Enum.ItemConsumableSubclass
    if ecs and ecs.Fooddrink ~= nil then
        return ecs.Fooddrink
    end
    return 5
end

local function TextLooksLikeMounts(text)
    return ns.TextLooksLikeMounts and ns.TextLooksLikeMounts(text)
end

local function TextLooksLikePets(text)
    return ns.TextLooksLikePets and ns.TextLooksLikePets(text)
end

local function TextLooksLikeProfession(text)
    local lower = SafeLower(text)
    if not lower then
        return false
    end
    -- Mount / riding / pet trainers belong in mounts or pets, not profession.
    if TextLooksLikeMounts(text) or TextLooksLikePets(text) then
        return false
    end
    if lower:find("trainer", 1, true) then
        return true
    end
    if lower:find("reagent", 1, true) then
        return false
    end
    local sub = ns.MatchSpecialtySubtype and ns.MatchSpecialtySubtype(text)
    return sub and sub.parent == "profession"
end

--- True when a subtitle/name looks like a class *supply* vendor (e.g. "Druid Supplies").
-- Class trainers are out of scope, so any "Trainer" title is rejected.
local function TextLooksLikeClass(text)
    local lower = SafeLower(text)
    if not lower then
        return false
    end
    if lower:find("trainer", 1, true) then
        return false
    end
    local sub = ns.MatchSpecialtySubtype and ns.MatchSpecialtySubtype(text)
    return sub and sub.parent == "class" and true or false
end

--- True for "Banker" / "Guild Banker" NPC titles (and similar).
local function TextLooksLikeBanker(text)
    local lower = SafeLower(text)
    return lower and lower:find("banker", 1, true) and true or false
end

--- True for city/hub combat dummies ("Training Dummy", "Raider's Training Dummy", …).
local function TextLooksLikeTrainingDummy(text)
    local lower = SafeLower(text)
    if not lower then
        return false
    end
    if lower:find("training dummy", 1, true) or lower:find("target dummy", 1, true) then
        return true
    end
    -- Legacy / role-specific labels without the full phrase.
    if lower:find("dummy", 1, true)
        and (lower:find("raid", 1, true) or lower:find("dungeon", 1, true) or lower:find("tank", 1, true) or lower:find("heal", 1, true))
    then
        return true
    end
    return false
end

--- Gossip option text that opens personal/guild/account bank access.
local function GossipLooksLikeBank(text)
    if not text then
        return false
    end
    if text:find("deposit box", 1, true) then
        return true
    end
    if text:find("bank", 1, true) then
        -- Avoid odd false positives; bank gossip usually mentions access/check/open/deposit.
        if text:find("access", 1, true)
            or text:find("check", 1, true)
            or text:find("open", 1, true)
            or text:find("deposit", 1, true)
            or text:find("account", 1, true)
            or text:find("guild", 1, true)
        then
            return true
        end
        -- Short options like "Bank" / "The bank".
        if text == "bank" or text:find("^the bank") then
            return true
        end
    end
    return false
end

-- Inventory profession share: stray recipes on general goods should not tag the shop.
-- Tiny shops (≤3 items) still accept a single craft item; larger shops need ≥20% and ≥2.
local PROFESSION_RATIO = 0.2

local function DetectMerchantTypes(subtitle)
    local types = {}
    local foodCount, reagentCount, professionCount, itemCount = 0, 0, 0, 0

    if CanMerchantRepair and CanMerchantRepair() then
        types.repair = true
    end

    local foodDrinkSub = FoodDrinkSubclass()
    local num = GetMerchantNumItems and GetMerchantNumItems() or 0
    for i = 1, num do
        local itemID = GetMerchantItemID and GetMerchantItemID(i)
        if itemID and CanUse(itemID) then
            itemCount = itemCount + 1
            local classID, subClassID = ItemClassIDs(itemID)
            local isCraftingReagent = false
            local itemName, itemType, itemSubType

            local ok, n, _, quality, _, _, iType, iSub, _, _, _, _, _, _, _, _, _, craftReagent = pcall(GetItemInfo, itemID)
            if ok then
                itemName, itemType, itemSubType = n, iType, iSub
                if craftReagent then
                    isCraftingReagent = true
                end
            end

            local isReagent = false
            if classID == Enum.ItemClass.Consumable and subClassID == foodDrinkSub then
                foodCount = foodCount + 1
            elseif classID == Enum.ItemClass.Reagent then
                isReagent = true
            elseif classID == Enum.ItemClass.Tradegoods then
                if subClassID == TRADEGOODS_COOKING then
                    -- Cooking tradegoods (raw meat/fish) are food ingredients, not a
                    -- profession-supplies signal on their own. Real cooking-supply /
                    -- trainer vendors are caught by subtitle/name and by Recipe items.
                    foodCount = foodCount + 1
                else
                    isReagent = true
                end
            elseif classID == Enum.ItemClass.Recipe then
                professionCount = professionCount + 1
            elseif classID == Enum.ItemClass.Projectile then
                types.ammo = true
            elseif classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon then
                -- Only Uncommon+ gear implies an appearance/transmog vendor; basic
                -- white/gray weapons and armor are just repair/general goods stock.
                if quality and quality >= TRANSMOG_MIN_QUALITY then
                    types.transmog = true
                end
            elseif classID == Enum.ItemClass.Miscellaneous then
                local mountSub = Enum.ItemMiscellaneousSubclass and Enum.ItemMiscellaneousSubclass.Mount
                if mountSub and subClassID == mountSub then
                    types.mounts = true
                end
            end

            if isCraftingReagent then
                isReagent = true
            end

            local sub = SafeLower(itemSubType)
            if sub then
                if sub:find("mount", 1, true) then
                    types.mounts = true
                elseif sub:find("poison", 1, true) then
                    types.poison = true
                elseif sub:find("reagent", 1, true) then
                    isReagent = true
                end
            end
            local nameLower = SafeLower(itemName)
            if nameLower and nameLower:find("poison", 1, true) then
                types.poison = true
            end
            local typeLower = SafeLower(itemType)
            if typeLower and typeLower:find("reagent", 1, true) then
                isReagent = true
            end
            if isReagent then
                reagentCount = reagentCount + 1
            end
        end
    end

    local subLower = SafeLower(subtitle)
    if subLower and subLower:find("reagent", 1, true) then
        reagentCount = reagentCount + 3
    end

    if foodCount > 0 then
        types.food = true
    end
    if reagentCount > 0 then
        types.reagents = true
    end

    -- Title still wins; inventory needs a meaningful craft share (not one recipe in twenty).
    if TextLooksLikeProfession(subtitle) then
        types.profession = true
    elseif professionCount > 0 then
        local minProfession = (itemCount <= 3) and 1 or math.max(2, math.ceil(itemCount * PROFESSION_RATIO))
        if professionCount >= minProfession then
            types.profession = true
        end
    end

    if TextLooksLikeMounts(subtitle) then
        types.mounts = true
    end
    if TextLooksLikePets(subtitle) then
        types.pets = true
    end

    -- Drop minority food tags on reagent-heavy shops (eggs on a reagents vendor).
    if types.food and types.reagents then
        local foodCap = math.max(2, math.floor(reagentCount / 4))
        if reagentCount >= 3 and foodCount <= foodCap then
            types.food = nil
        end
    end

    if not next(types) then
        types.general = true
    end
    return types
end

local function ResolveFaction()
    local unit = InteractionUnit()
    local ok, f = pcall(UnitFactionGroup, unit)
    if ok and f and CanUse(f) and (f == "Alliance" or f == "Horde") then
        return f
    end
    ok, f = pcall(UnitFactionGroup, "player")
    if ok and f and CanUse(f) and (f == "Alliance" or f == "Horde") then
        return f
    end
    return "Neutral"
end

local function MarkProfessionTrainer()
    local ok, isTrade = pcall(IsTradeskillTrainer)
    if ok and isTrade then
        pendingProfessionTrainer = true
        return true
    end
    return false
end

--- SaveVendor(name, npcID, types, opts)
-- opts: { subtitle=, replaceTypes=, learnedFrom=, note=, specialtyKey= }
-- Provenance goes in learnedFrom ("merchant", "gossip", …), never in note.
-- specialtyKey is auto-detected from subtitle when omitted (supplies vs trainer).
-- Per-NPC chat debounce: suppress a repeat "Learned:" line for the same NPC within
-- this window so overlapping save paths in one interaction print at most once.
local LEARN_ANNOUNCE_DEBOUNCE = 0.5
local lastLearnAnnounce = {}

local function ShouldAnnounceLearn(key)
    if not key then
        return true
    end
    local now = (GetTime and GetTime()) or 0
    local last = lastLearnAnnounce[key]
    if last and (now - last) < LEARN_ANNOUNCE_DEBOUNCE then
        return false
    end
    lastLearnAnnounce[key] = now
    return true
end

local function SaveVendor(name, npcID, types, opts)
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return false
    end
    local mapID, x, y = GetPlayerMapPosition()
    if not mapID then
        return false
    end

    if not CanUse(name) then
        name = "Unknown Vendor"
    end

    opts = opts or {}
    local subtitle = opts.subtitle
    if subtitle and (not CanUse(subtitle) or subtitle == "") then
        subtitle = nil
    end

    local learnedFrom = opts.learnedFrom
    if type(learnedFrom) ~= "string" or learnedFrom == "" then
        learnedFrom = nil
    end

    local note = opts.note
    if type(note) ~= "string" or note == "" or (ns.ParseLegacyLearnNote and ns.ParseLegacyLearnNote(note)) then
        note = nil
    end

    local specialtyKey = opts.specialtyKey
    if specialtyKey == "" or specialtyKey == "auto" then
        specialtyKey = nil
    end
    if not specialtyKey and ns.DetectSpecialtyKey then
        specialtyKey = ns.DetectSpecialtyKey({
            subtitle = subtitle,
            name = name,
            note = note,
            types = types,
        })
    end

    -- Name/subtitle with whole-word "mount" (or riding trainer) → mounts category.
    if TextLooksLikeMounts(subtitle) or TextLooksLikeMounts(name) then
        types = types or {}
        types.mounts = true
        types.general = nil
        -- Mount trainers must not keep a profession-trainer specialty/type.
        if specialtyKey == "trainer" then
            specialtyKey = nil
        end
        local title = SafeLower((subtitle or "") .. " " .. (name or ""))
        if title and title:find("trainer", 1, true) then
            types.profession = nil
        end
    end

    -- Name/subtitle with pet/breeder/kennel → pets category.
    if TextLooksLikePets(subtitle) or TextLooksLikePets(name) then
        types = types or {}
        types.pets = true
        types.general = nil
        if specialtyKey == "trainer" then
            specialtyKey = nil
        end
        local title = SafeLower((subtitle or "") .. " " .. (name or ""))
        if title and title:find("trainer", 1, true) then
            types.profession = nil
        end
    end

    -- A detected specialty implies its parent type (Profession or Class) even when the
    -- inventory looked like plain reagents. "trainer" is always a profession skillbook.
    if specialtyKey and specialtyKey ~= "" and specialtyKey ~= "auto" then
        types = types or {}
        local sub = ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[specialtyKey]
        local parent = (specialtyKey == "trainer") and "profession" or (sub and sub.parent) or "profession"
        types[parent] = true
        types.general = nil
    end

    local isNew, changed = ns.Database:UpsertLearned({
        name = name or "Unknown Vendor",
        npcID = npcID,
        mapID = mapID,
        x = x,
        y = y,
        faction = ResolveFaction(),
        types = types,
        note = note,
        subtitle = subtitle,
        specialtyKey = specialtyKey,
        learnedFrom = learnedFrom,
        replaceTypes = opts.replaceTypes and true or nil,
    })

    -- Only announce a first learn or a meaningful change, and debounce by NPC so a
    -- single interaction that saves twice (gossip→merchant, PIM + dedicated event,
    -- subtitle retry) produces at most one chat line.
    if (isNew or changed) and ShouldAnnounceLearn(npcID or name) then
        ns.Print(string.format("Learned: %s (map %d @ %.1f, %.1f)", tostring(name), mapID, x * 100, y * 100))
    end
    return true
end

--- Re-save with subtitle if the first MERCHANT/TRAINER tick missed tooltip text.
local function RetrySubtitleSoon(name, npcID, types, learnedFrom)
    if not C_Timer or not C_Timer.After or not npcID then
        return
    end
    C_Timer.After(0.15, function()
        if not VendorMapDB or not ns.GetDB().learnVendors then
            return
        end
        local unit = InteractionUnit()
        local subtitle = GetUnitSubtitle(unit)
        if not subtitle then
            return
        end
        local patchTypes = {}
        for k, v in pairs(types or {}) do
            if v then
                patchTypes[k] = true
            end
        end
        if TextLooksLikeMounts(subtitle) then
            patchTypes.mounts = true
            patchTypes.general = nil
        elseif TextLooksLikePets(subtitle) then
            patchTypes.pets = true
            patchTypes.general = nil
        elseif TextLooksLikeProfession(subtitle) then
            patchTypes.profession = true
            patchTypes.general = nil
        elseif TextLooksLikeClass(subtitle) then
            patchTypes.class = true
            patchTypes.general = nil
        end
        SaveVendor(name, npcID, patchTypes, {
            subtitle = subtitle,
            replaceTypes = true,
            learnedFrom = learnedFrom or "merchant",
        })
    end)
end

function Learn:OnMerchantShow()
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    local unit = InteractionUnit()
    local npcID = GetNpcIDFromUnit(unit)
    local name = SafeUnitName(unit, "Unknown Vendor")
    local subtitle = GetUnitSubtitle(unit)

    local types = DetectMerchantTypes(subtitle)
    if pendingGossipInnkeeper then
        types.innkeeper = true
        pendingGossipInnkeeper = false
    end

    if TextLooksLikeMounts(subtitle) or TextLooksLikeMounts(name) then
        types.mounts = true
        types.general = nil
    end
    if TextLooksLikePets(subtitle) or TextLooksLikePets(name) then
        types.pets = true
        types.general = nil
    end

    local isTradeTrainer = false
    do
        local ok, isTrade = pcall(IsTradeskillTrainer)
        isTradeTrainer = ok and isTrade
    end
    if pendingProfessionTrainer or isTradeTrainer or TextLooksLikeProfession(subtitle) or TextLooksLikeProfession(name) then
        types.profession = true
        types.general = nil
        -- Trainer supply shops: strip residual food unless also an innkeeper.
        if types.food and not types.innkeeper then
            types.food = nil
        end
        pendingProfessionTrainer = false
    elseif TextLooksLikeClass(subtitle) or TextLooksLikeClass(name) then
        types.class = true
        types.general = nil
    end

    SaveVendor(name, npcID, types, {
        subtitle = subtitle,
        replaceTypes = true,
        learnedFrom = "merchant",
    })
    if not subtitle then
        RetrySubtitleSoon(name, npcID, types, "merchant")
    end
end

function Learn:OnGossipShow()
    pendingGossipInnkeeper = false
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    if not C_GossipInfo or not C_GossipInfo.GetOptions then
        return
    end
    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or not options then
        return
    end
    local unit = InteractionUnit()
    local name = SafeUnitName(unit)
    local subtitle = GetUnitSubtitle(unit)
    local looksMounts = TextLooksLikeMounts(subtitle) or TextLooksLikeMounts(name)
    local looksPets = TextLooksLikePets(subtitle) or TextLooksLikePets(name)
    local looksProfession = TextLooksLikeProfession(subtitle) or TextLooksLikeProfession(name)
    local looksClass = TextLooksLikeClass(subtitle) or TextLooksLikeClass(name)

    -- Bankers often show gossip with a bank option, or simply carry a "Banker" title.
    if TextLooksLikeBanker(subtitle) then
        SaveVendor(
            name,
            GetNpcIDFromUnit(unit),
            { banker = true },
            { subtitle = subtitle, learnedFrom = "gossip" }
        )
        return
    end

    local hasTrainOption = false
    for _, opt in ipairs(options) do
        local text = SafeLower(opt.name or opt.text)
        if text then
            if text:find("train", 1, true) then
                hasTrainOption = true
            end
            if text:find("inn") and (text:find("home") or text:find("bind") or text:find("rest")) then
                pendingGossipInnkeeper = true
                SaveVendor(
                    name,
                    GetNpcIDFromUnit(unit),
                    { innkeeper = true, food = true },
                    { subtitle = subtitle, learnedFrom = "gossip" }
                )
                return
            end
            if text:find("barber") or text:find("style") then
                SaveVendor(
                    SafeUnitName(unit, "Barber Shop"),
                    GetNpcIDFromUnit(unit),
                    { barber = true },
                    { subtitle = subtitle, learnedFrom = "gossip" }
                )
                return
            end
            if text:find("stable", 1, true) or (text:find("pet", 1, true) and text:find("care", 1, true)) then
                SaveVendor(
                    SafeUnitName(unit, "Stable Master"),
                    GetNpcIDFromUnit(unit),
                    { stable = true },
                    { subtitle = subtitle, learnedFrom = "gossip" }
                )
                return
            end
            if GossipLooksLikeBank(text) then
                local bankSubtitle = subtitle
                if not bankSubtitle or bankSubtitle == "" then
                    bankSubtitle = "Banker"
                end
                SaveVendor(
                    name,
                    GetNpcIDFromUnit(unit),
                    { banker = true },
                    { subtitle = bankSubtitle, learnedFrom = "gossip" }
                )
                return
            end
            if text:find("auction", 1, true) then
                local ahName = SafeUnitName(unit, "Auctioneer")
                local ahSubtitle = subtitle
                if not (ns.IsAuctionHouseName and (ns.IsAuctionHouseName(ahName) or ns.IsAuctionHouseName(ahSubtitle))) then
                    if not ahSubtitle or ahSubtitle == "" then
                        ahSubtitle = "Auctioneer"
                    end
                end
                SaveVendor(
                    ahName,
                    GetNpcIDFromUnit(unit),
                    { general = true },
                    { subtitle = ahSubtitle, learnedFrom = "gossip" }
                )
                return
            end
        end
    end

    if looksMounts then
        SaveVendor(
            name,
            GetNpcIDFromUnit(unit),
            { mounts = true },
            { subtitle = subtitle, learnedFrom = "gossip" }
        )
    elseif looksPets then
        SaveVendor(
            name,
            GetNpcIDFromUnit(unit),
            { pets = true },
            { subtitle = subtitle, learnedFrom = "gossip" }
        )
    -- Only treat as profession from gossip when the NPC looks like a craft trainer
    -- (avoid class trainers that also offer a Train option).
    elseif looksProfession then
        if hasTrainOption then
            pendingProfessionTrainer = true
        end
        SaveVendor(
            name,
            GetNpcIDFromUnit(unit),
            { profession = true },
            { subtitle = subtitle, learnedFrom = "gossip" }
        )
    elseif looksClass and not hasTrainOption then
        -- Class *supplies* vendor (a class trainer would have a Train option / "Trainer" title).
        SaveVendor(
            name,
            GetNpcIDFromUnit(unit),
            { class = true },
            { subtitle = subtitle, learnedFrom = "gossip" }
        )
    elseif hasTrainOption then
        -- May be confirmed on TRAINER_SHOW via IsTradeskillTrainer.
    end
end

function Learn:OnTrainerShow()
    if MarkProfessionTrainer() then
        if not VendorMapDB or not ns.GetDB().learnVendors then
            return
        end
        local unit = InteractionUnit()
        local subtitle = GetUnitSubtitle(unit)
        local name = SafeUnitName(unit)
        local npcID = GetNpcIDFromUnit(unit)
        SaveVendor(
            name,
            npcID,
            { profession = true },
            { subtitle = subtitle, replaceTypes = true, learnedFrom = "trainer" }
        )
        if not subtitle then
            RetrySubtitleSoon(name, npcID, { profession = true }, "trainer")
        end
    end
end

function Learn:OnBarberOpen()
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    local unit = InteractionUnit()
    SaveVendor(
        SafeUnitName(unit, "Barber Shop"),
        GetNpcIDFromUnit(unit),
        { barber = true },
        { subtitle = GetUnitSubtitle(unit), replaceTypes = true, learnedFrom = "barber shop" }
    )
end

--- Auction house opens via AUCTION_HOUSE_SHOW / PlayerInteractionType.Auctioneer — not MERCHANT_SHOW.
function Learn:OnAuctionShow()
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    local unit = InteractionUnit()
    local name = SafeUnitName(unit, "Auctioneer")
    local subtitle = GetUnitSubtitle(unit)
    -- Seeds use the bare "Auctioneer" label; live NPCs are often "Auctioneer Foo".
    -- Ensure AH display art when neither name nor subtitle already identifies the AH.
    if not (ns.IsAuctionHouseName and (ns.IsAuctionHouseName(name) or ns.IsAuctionHouseName(subtitle))) then
        if not subtitle or subtitle == "" then
            subtitle = "Auctioneer"
        end
    end
    SaveVendor(name, GetNpcIDFromUnit(unit), { general = true }, {
        subtitle = subtitle,
        replaceTypes = true,
        learnedFrom = "auction house",
    })
end

--- Bank opens via BANKFRAME_OPENED / PlayerInteractionType.Banker (etc.) — not MERCHANT_SHOW.
function Learn:OnBankerShow()
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    local unit = InteractionUnit()
    local name = SafeUnitName(unit, "Banker")
    local subtitle = GetUnitSubtitle(unit)
    if not subtitle or subtitle == "" then
        subtitle = "Banker"
    end
    SaveVendor(name, GetNpcIDFromUnit(unit), { banker = true }, {
        subtitle = subtitle,
        replaceTypes = true,
        learnedFrom = "bank",
    })
end

--- Dummies have no merchant/gossip UI — learn when the player targets (or mouseovers) one.
function Learn:TryLearnTrainingDummy(unit)
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    unit = unit or "target"
    if not UnitExists(unit) then
        return
    end
    -- Players / pets are never dummies.
    if UnitIsPlayer and UnitIsPlayer(unit) then
        return
    end
    local name = SafeUnitName(unit, nil)
    local subtitle = GetUnitSubtitle(unit)
    if not (TextLooksLikeTrainingDummy(name) or TextLooksLikeTrainingDummy(subtitle)) then
        return
    end
    SaveVendor(name or "Training Dummy", GetNpcIDFromUnit(unit), { trainingdummy = true }, {
        subtitle = subtitle,
        replaceTypes = true,
        learnedFrom = "training dummy",
    })
end

function Learn:OnStableShow()
    if not VendorMapDB or not ns.GetDB().learnVendors then
        return
    end
    if C_StableInfo and C_StableInfo.IsAtStableMaster and not C_StableInfo.IsAtStableMaster() then
        -- Interaction manager may fire slightly before the flag flips; still try to learn.
    end
    local unit = InteractionUnit()
    SaveVendor(
        SafeUnitName(unit, "Stable Master"),
        GetNpcIDFromUnit(unit),
        { stable = true },
        { subtitle = GetUnitSubtitle(unit), replaceTypes = true, learnedFrom = "stable" }
    )
end

function Learn:OnPlayerInteractionShow(interactionType)
    if not interactionType or not Enum or not Enum.PlayerInteractionType then
        return
    end
    local PIT = Enum.PlayerInteractionType
    if interactionType == PIT.StableMaster then
        self:OnStableShow()
    elseif interactionType == PIT.Barber or interactionType == PIT.BarberShop then
        self:OnBarberOpen()
    elseif PIT.Auctioneer and interactionType == PIT.Auctioneer then
        self:OnAuctionShow()
    elseif (PIT.Banker and interactionType == PIT.Banker)
        or (PIT.GuildBanker and interactionType == PIT.GuildBanker)
        or (PIT.CharacterBanker and interactionType == PIT.CharacterBanker)
    then
        -- Skip AccountBanker: warband-inhibitor spawn, not a city NPC pin.
        self:OnBankerShow()
    elseif PIT.Transmogrifier and interactionType == PIT.Transmogrifier then
        local unit = InteractionUnit()
        SaveVendor(
            SafeUnitName(unit, "Transmogrifier"),
            GetNpcIDFromUnit(unit),
            { transmog = true },
            { subtitle = GetUnitSubtitle(unit), replaceTypes = true, learnedFrom = "transmogrifier" }
        )
    elseif PIT.Trainer and interactionType == PIT.Trainer then
        self:OnTrainerShow()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("GOSSIP_SHOW")
pcall(frame.RegisterEvent, frame, "TRAINER_SHOW")
pcall(frame.RegisterEvent, frame, "BARBER_SHOP_OPEN")
pcall(frame.RegisterEvent, frame, "PET_STABLE_SHOW")
pcall(frame.RegisterEvent, frame, "AUCTION_HOUSE_SHOW")
pcall(frame.RegisterEvent, frame, "BANKFRAME_OPENED")
pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_CHANGED")
pcall(frame.RegisterEvent, frame, "UPDATE_MOUSEOVER_UNIT")

frame:SetScript("OnEvent", function(_, event, arg1)
    local ok, err = pcall(function()
        if event == "MERCHANT_SHOW" then
            Learn:OnMerchantShow()
        elseif event == "GOSSIP_SHOW" then
            Learn:OnGossipShow()
        elseif event == "TRAINER_SHOW" then
            Learn:OnTrainerShow()
        elseif event == "BARBER_SHOP_OPEN" then
            Learn:OnBarberOpen()
        elseif event == "PET_STABLE_SHOW" then
            Learn:OnStableShow()
        elseif event == "AUCTION_HOUSE_SHOW" then
            Learn:OnAuctionShow()
        elseif event == "BANKFRAME_OPENED" then
            Learn:OnBankerShow()
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            Learn:OnPlayerInteractionShow(arg1)
        elseif event == "PLAYER_TARGET_CHANGED" then
            Learn:TryLearnTrainingDummy("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            Learn:TryLearnTrainingDummy("mouseover")
        end
    end)
    if not ok and ns and ns.Print and VendorMapDB and VendorMapDB.debugLearn then
        ns.Print("Learn skipped: " .. tostring(err))
    end
end)
