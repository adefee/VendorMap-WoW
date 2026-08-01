local _, ns = ...

local Learn = {}
ns.Learn = Learn

local pendingGossipInnkeeper = false
local pendingProfessionTrainer = false

-- Tradegoods cooking subclass (profession mats, not generic reagents for dominance).
local TRADEGOODS_COOKING = 8

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
    if not ok or not name or not CanUse(name) then
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

--- NPC specialty/title under the name, or nil.
local function GetUnitSubtitle(unit)
    if not unit or not C_TooltipInfo or not C_TooltipInfo.GetUnit then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or not data then
        return nil
    end
    local name = SafeUnitName(unit, nil)
    local text = ns.SubtitleFromTooltipData and ns.SubtitleFromTooltipData(data, name)
    if text and CanUse(text) and text ~= "" then
        return text
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

local function TextLooksLikeProfession(text)
    local lower = SafeLower(text)
    if not lower then
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

local function DetectMerchantTypes(subtitle)
    local types = {}
    local foodCount, reagentCount, professionCount = 0, 0, 0

    if CanMerchantRepair and CanMerchantRepair() then
        types.repair = true
    end

    local foodDrinkSub = FoodDrinkSubclass()
    local num = GetMerchantNumItems and GetMerchantNumItems() or 0
    for i = 1, num do
        local itemID = GetMerchantItemID and GetMerchantItemID(i)
        if itemID and CanUse(itemID) then
            local classID, subClassID = ItemClassIDs(itemID)
            local isCraftingReagent = false
            local itemName, itemType, itemSubType

            local ok, n, _, _, _, _, iType, iSub, _, _, _, _, _, _, _, _, _, craftReagent = pcall(GetItemInfo, itemID)
            if ok then
                itemName, itemType, itemSubType = n, iType, iSub
                if craftReagent then
                    isCraftingReagent = true
                end
            end

            if classID == Enum.ItemClass.Consumable and subClassID == foodDrinkSub then
                foodCount = foodCount + 1
            elseif classID == Enum.ItemClass.Reagent then
                reagentCount = reagentCount + 1
            elseif classID == Enum.ItemClass.Tradegoods then
                if subClassID == TRADEGOODS_COOKING then
                    professionCount = professionCount + 1
                else
                    reagentCount = reagentCount + 1
                end
            elseif classID == Enum.ItemClass.Recipe then
                professionCount = professionCount + 1
            elseif classID == Enum.ItemClass.Projectile then
                types.ammo = true
            elseif classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon then
                types.transmog = true
            elseif classID == Enum.ItemClass.Miscellaneous then
                local mountSub = Enum.ItemMiscellaneousSubclass and Enum.ItemMiscellaneousSubclass.Mount
                if mountSub and subClassID == mountSub then
                    types.mounts = true
                end
            end

            if isCraftingReagent then
                reagentCount = reagentCount + 1
            end

            local sub = SafeLower(itemSubType)
            if sub then
                if sub:find("mount", 1, true) then
                    types.mounts = true
                elseif sub:find("poison", 1, true) then
                    types.poison = true
                elseif sub:find("reagent", 1, true) then
                    reagentCount = reagentCount + 1
                end
            end
            local nameLower = SafeLower(itemName)
            if nameLower and nameLower:find("poison", 1, true) then
                types.poison = true
            end
            local typeLower = SafeLower(itemType)
            if typeLower and typeLower:find("reagent", 1, true) then
                reagentCount = reagentCount + 1
            end
        end
    end

    local subLower = SafeLower(subtitle)
    if subLower and subLower:find("reagent", 1, true) then
        reagentCount = reagentCount + 3
    end
    if TextLooksLikeProfession(subtitle) then
        professionCount = professionCount + 3
    end

    if foodCount > 0 then
        types.food = true
    end
    if reagentCount > 0 then
        types.reagents = true
    end
    if professionCount > 0 then
        types.profession = true
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

--- SaveVendor(name, npcID, types, note, opts)
-- opts: { subtitle=, replaceTypes=bool }
local function SaveVendor(name, npcID, types, note, opts)
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

    ns.Database:UpsertLearned({
        name = name or "Unknown Vendor",
        npcID = npcID,
        mapID = mapID,
        x = x,
        y = y,
        faction = ResolveFaction(),
        types = types,
        note = note,
        subtitle = subtitle,
        replaceTypes = opts.replaceTypes and true or nil,
    })
    ns.Print(string.format("Learned: %s (map %d @ %.1f, %.1f)", tostring(name), mapID, x * 100, y * 100))
    return true
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
    end

    SaveVendor(name, npcID, types, nil, { subtitle = subtitle, replaceTypes = true })
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
    local looksProfession = TextLooksLikeProfession(subtitle) or TextLooksLikeProfession(name)
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
                    "Learned from gossip",
                    { subtitle = subtitle }
                )
                return
            end
            if text:find("barber") or text:find("style") then
                SaveVendor(
                    SafeUnitName(unit, "Barber Shop"),
                    GetNpcIDFromUnit(unit),
                    { barber = true },
                    "Learned from gossip",
                    { subtitle = subtitle }
                )
                return
            end
            if text:find("stable", 1, true) or (text:find("pet", 1, true) and text:find("care", 1, true)) then
                SaveVendor(
                    SafeUnitName(unit, "Stable Master"),
                    GetNpcIDFromUnit(unit),
                    { stable = true },
                    "Learned from gossip",
                    { subtitle = subtitle }
                )
                return
            end
        end
    end

    -- Only treat as profession from gossip when the NPC looks like a craft trainer
    -- (avoid class trainers that also offer a Train option).
    if looksProfession then
        if hasTrainOption then
            pendingProfessionTrainer = true
        end
        SaveVendor(
            name,
            GetNpcIDFromUnit(unit),
            { profession = true },
            "Learned from gossip",
            { subtitle = subtitle }
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
        SaveVendor(
            SafeUnitName(unit),
            GetNpcIDFromUnit(unit),
            { profession = true },
            "Learned from trainer",
            { subtitle = subtitle, replaceTypes = true }
        )
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
        "Learned from barber shop",
        { subtitle = GetUnitSubtitle(unit), replaceTypes = true }
    )
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
        "Learned from stable",
        { subtitle = GetUnitSubtitle(unit), replaceTypes = true }
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
    elseif PIT.Transmogrifier and interactionType == PIT.Transmogrifier then
        local unit = InteractionUnit()
        SaveVendor(
            SafeUnitName(unit, "Transmogrifier"),
            GetNpcIDFromUnit(unit),
            { transmog = true },
            "Learned from transmogrifier",
            { subtitle = GetUnitSubtitle(unit), replaceTypes = true }
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
pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

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
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            Learn:OnPlayerInteractionShow(arg1)
        end
    end)
    if not ok and ns and ns.Print and VendorMapDB and VendorMapDB.debugLearn then
        ns.Print("Learn skipped: " .. tostring(err))
    end
end)
