local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = "0.6.2"

-- Vendor type keys (also used as filter + SavedVariables keys)
-- Prefer Minimap\Tracking icons (same art as Blizzard townsfolk tracking / NPC hover).
ns.VENDOR_TYPES = {
    { key = "repair",     label = "Repair",           icon = "Interface\\Minimap\\Tracking\\Repair" },
    { key = "reagents",   label = "Reagents",         icon = "Interface\\Minimap\\Tracking\\Reagents" },
    { key = "food",       label = "Food & Drink",     icon = "Interface\\Minimap\\Tracking\\Food" },
    { key = "poison",     label = "Poisons",          icon = "Interface\\Minimap\\Tracking\\Poisons" },
    { key = "ammo",       label = "Ammunition",       icon = "Interface\\Minimap\\Tracking\\Ammunition" },
    { key = "mounts",     label = "Mounts",           icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { key = "stable",     label = "Stable Master",    icon = "Interface\\Minimap\\Tracking\\StableMaster" },
    { key = "transmog",   label = "Transmog",         icon = "Interface\\Minimap\\Tracking\\Transmogrifier", atlas = "poi-transmogrifier" },
    { key = "decor",      label = "Decor / Housing",  icon = "Interface\\Icons\\Garrison_Building_Storehouse" },
    { key = "profession", label = "Profession",       icon = "Interface\\Minimap\\Tracking\\Profession" },
    -- Default / Neutral tabard; Alliance & Horde swap via SetTypeIcon(..., faction)
    { key = "faction",    label = "Faction / Rep",    icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
    { key = "innkeeper",  label = "Innkeeper",        icon = "Interface\\Minimap\\Tracking\\Innkeeper" },
    { key = "barber",     label = "Barber Shop",      icon = "Interface\\Minimap\\Tracking\\Barber" },
    -- Gossip vendor bag (non-square); Auction House pins use Auctioneer via display key.
    -- Users can change per-type icons under Vendors & Icons.
    { key = "general",    label = "General Goods",    icon = "Interface\\GossipFrame\\VendorGossipIcon" },
}

-- Display subtype keys (not seed data types). These share the "general" tag for
-- seed/learned data, but get their own art/size and an independent visibility toggle.
-- Minimap Auctioneer art is the classic gavel.
ns.AUCTION_HOUSE_DISPLAY_KEY = "auctionhouse"
ns.AUCTION_HOUSE_ICON = "Interface\\Minimap\\Tracking\\Auctioneer"
ns.AUCTION_HOUSE_ATLASES = {
    "poi-town-auctionhouse",
    "Auctioneer",
}

ns.PET_SUPPLIES_DISPLAY_KEY = "petsupplies"
ns.PET_SUPPLIES_ICON = "Interface\\Icons\\INV_Box_PetCarrier_01"

-- Display subtypes of General Goods: keyed by exact pin name, own visibility flag.
ns.GENERAL_SUBTYPES = {
    { key = ns.AUCTION_HOUSE_DISPLAY_KEY, label = "Auction House", fallbackIcon = ns.AUCTION_HOUSE_ICON },
    { key = ns.PET_SUPPLIES_DISPLAY_KEY,  label = "Pet Supplies",  fallbackIcon = ns.PET_SUPPLIES_ICON },
}

-- Display specialties: keyword match on NPC subtitle (then name). Nested under parent
-- type in settings; independent visibility + icon. Not seed inventory type keys.
-- Profession specialties apply to Supplies vendors only — "<Profession> Trainer"
-- keeps the parent Profession (skillbook) icon via GetSpecialtySubtype.
ns.SPECIALTY_SUBTYPES = {
    {
        key = "specialty_pastry",
        label = "Pastries / Cakes",
        parent = "food",
        match = { "cake", "cakes", "pastry", "pastries", "pie", "pies" },
        -- FileID 651575: cake / pastry (INV_Misc_Food_25 is a pumpkin).
        fallbackIcon = 651575,
    },
    {
        key = "specialty_inscription",
        label = "Inscription Supplies",
        parent = "profession",
        match = { "inscription", "scribe" },
        fallbackIcon = "Interface\\Icons\\INV_Inscription_Tradeskill01",
    },
    {
        key = "specialty_alchemy",
        label = "Alchemy Supplies",
        parent = "profession",
        match = { "alchemy", "alchemist" },
        fallbackIcon = "Interface\\Icons\\Trade_Alchemy",
    },
    {
        key = "specialty_engineering",
        label = "Engineering Supplies",
        parent = "profession",
        match = { "engineering", "engineer" },
        fallbackIcon = "Interface\\Icons\\Trade_Engineering",
    },
    {
        key = "specialty_blacksmithing",
        label = "Blacksmithing Supplies",
        parent = "profession",
        match = { "blacksmith", "blacksmithing" },
        fallbackIcon = "Interface\\Icons\\Trade_BlackSmithing",
    },
    {
        key = "specialty_enchanting",
        label = "Enchanting Supplies",
        parent = "profession",
        match = { "enchanting", "enchanter" },
        fallbackIcon = "Interface\\Icons\\Trade_Engraving",
    },
    {
        key = "specialty_leatherworking",
        label = "Leatherworking Supplies",
        parent = "profession",
        match = { "leatherworking", "leatherworker" },
        fallbackIcon = "Interface\\Icons\\Trade_LeatherWorking",
    },
    {
        key = "specialty_tailoring",
        label = "Tailoring Supplies",
        parent = "profession",
        match = { "tailoring", "tailor" },
        fallbackIcon = "Interface\\Icons\\Trade_Tailoring",
    },
    {
        key = "specialty_jewelcrafting",
        label = "Jewelcrafting Supplies",
        parent = "profession",
        match = { "jewelcrafting", "jewelcrafter", "jeweler" },
        fallbackIcon = "Interface\\Icons\\INV_Misc_Gem_01",
    },
    {
        key = "specialty_cooking",
        label = "Cooking Supplies",
        parent = "profession",
        match = { "cooking", "cook", "chef" },
        fallbackIcon = "Interface\\Icons\\INV_Misc_Food_15",
    },
    {
        key = "specialty_fishing",
        label = "Fishing Supplies",
        parent = "profession",
        match = { "fishing", "fisherman", "angler" },
        fallbackIcon = "Interface\\Icons\\Trade_Fishing",
    },
    {
        key = "specialty_herbalism",
        label = "Herbalism Supplies",
        parent = "profession",
        match = { "herbalism", "herbalist" },
        fallbackIcon = "Interface\\Icons\\Trade_Herbalism",
    },
    {
        key = "specialty_mining",
        label = "Mining Supplies",
        parent = "profession",
        match = { "mining", "miner" },
        fallbackIcon = "Interface\\Icons\\Trade_Mining",
    },
    {
        key = "specialty_skinning",
        label = "Skinning Supplies",
        parent = "profession",
        match = { "skinning", "skinner" },
        fallbackIcon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    },
}

ns.TYPE_BY_KEY = {}
for _, t in ipairs(ns.VENDOR_TYPES) do
    ns.TYPE_BY_KEY[t.key] = t
end

ns.SPECIALTY_BY_KEY = {}
for _, sub in ipairs(ns.SPECIALTY_SUBTYPES) do
    ns.SPECIALTY_BY_KEY[sub.key] = sub
end

ns.FACTIONS = {
    { key = "Alliance", label = "Alliance" },
    { key = "Horde",    label = "Horde" },
    { key = "Neutral",  label = "Neutral" },
}

-- Faction / Rep pin art by player-faction (Alliance / Horde / Neutral).
ns.FACTION_TYPE_ICONS = {
    Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance",
    Horde = "Interface\\FriendsFrame\\PlusManz-Horde",
    Neutral = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
}


-- mapDisplay: "world" | "minimap" | "both"
-- waypointMode: "auto" | "waypointui" | "tomtom" | "blizzard"
-- learnedOverrideMode: "preferOverride" | "preferLearned"
--   Display pipeline is always seed → learned → override; this chooses which side wins
--   when learned data and an existing user override both set the same field.
-- protectOverrideNotes: when true, learned data never replaces a note you set via override
--   (even if learnedOverrideMode is preferLearned). Name/types/faction may still update.
-- typeIconScale[key]: relative size multiplier (1.0 = 100% of addon default for that pin)
-- typeIconPreset[key]: curated preset id from IconPresets ("default", "custom", …)
-- typeIconCustom[key]: texture path / fileID when preset is "custom"
ns.DEFAULTS = {
    enabled = true,
    mapDisplay = "world",
    waypointMode = "auto",
    iconScale = 1.0,
    learnVendors = true,
    learnedOverrideMode = "preferOverride",
    protectOverrideNotes = true,
    showFilterButton = true,
    showMinimapFilterButton = true,
    showOverlapNeighbors = true,
    factions = {
        Alliance = true,
        Horde = true,
        Neutral = true,
    },
    types = {},
    typeIconScale = {},
    typeIconPreset = {},
    typeIconCustom = {},
}

for _, t in ipairs(ns.VENDOR_TYPES) do
    ns.DEFAULTS.types[t.key] = true
    ns.DEFAULTS.typeIconScale[t.key] = 1.0
    ns.DEFAULTS.typeIconPreset[t.key] = "default"
end
for _, sub in ipairs(ns.GENERAL_SUBTYPES) do
    ns.DEFAULTS.types[sub.key] = true
    ns.DEFAULTS.typeIconScale[sub.key] = 1.0
    ns.DEFAULTS.typeIconPreset[sub.key] = "default"
end
for _, sub in ipairs(ns.SPECIALTY_SUBTYPES) do
    ns.DEFAULTS.types[sub.key] = true
    ns.DEFAULTS.typeIconScale[sub.key] = 1.0
    ns.DEFAULTS.typeIconPreset[sub.key] = "default"
end

ns.PRINT_PREFIX = "|cff69ccf0VendorMap|r:"

-- Pixel size at 100% overall / per-type scale (midpoint between older 22px pool
-- defaults and the tighter 15/10 post-scale sizes).
ns.PIN_BASE_SIZE = {
    world = 18,
    continent = 12,
    cosmic = 9,
    minimap = 12,
}

--- Base pin size in pixels for a map context, before user scale multipliers.
-- mapType: Enum.UIMapType (1=Cosmic/World, 2=Continent, 3+=Zone…)
function ns.GetPinBaseSize(mapType, isMinimap)
    if isMinimap then
        return ns.PIN_BASE_SIZE.minimap
    end
    if mapType == 2 then
        return ns.PIN_BASE_SIZE.continent
    end
    if mapType and mapType <= 1 then
        return ns.PIN_BASE_SIZE.cosmic
    end
    return ns.PIN_BASE_SIZE.world
end

local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end
    return strlower(name:match("^%s*(.-)%s*$") or name)
end

--- True when the pin title is exactly "Auction House" or "Auctioneer" (case-insensitive).
function ns.IsAuctionHouseName(name)
    local trimmed = NormalizeName(name)
    return trimmed == "auction house" or trimmed == "auctioneer"
end

--- True when the pin title is exactly "Pet Supplies" (case-insensitive).
function ns.IsPetSuppliesName(name)
    return NormalizeName(name) == "pet supplies"
end

local function TextHasTrainer(text)
    local hay = NormalizeName(text)
    return hay and hay:find("trainer", 1, true) and true or false
end

--- First specialty subtype whose match keyword appears in text (lowercase).
-- Longer needles win (e.g. "blacksmithing" / "cooking" before shorter stems).
function ns.MatchSpecialtySubtype(text)
    local hay = NormalizeName(text)
    if not hay then
        return nil
    end
    local best, bestLen
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES) do
        for _, needle in ipairs(sub.match or {}) do
            if hay:find(needle, 1, true) then
                local nlen = #needle
                if not bestLen or nlen > bestLen then
                    best = sub
                    bestLen = nlen
                end
            end
        end
    end
    return best
end

--- Pull NPC title/subtitle from tooltip data (skip name + level lines).
function ns.SubtitleFromTooltipData(tooltipData, unitName)
    if not tooltipData or not tooltipData.lines then
        return nil
    end
    local levelToken = LEVEL or "Level"
    local nameLower = NormalizeName(unitName)
    for i, line in ipairs(tooltipData.lines) do
        local text = line and line.leftText
        if type(text) == "string" and text ~= "" then
            local lower = NormalizeName(text)
            if i == 1 and nameLower and lower == nameLower then
                -- unit name line
            elseif text:sub(1, #levelToken) == levelToken then
                -- level line
            elseif lower and (lower:find("^%(", 1) or lower:find("^<%d", 1)) then
                -- junk
            else
                return text
            end
        end
    end
    return nil
end

--- Specialty for a vendor info row (subtitle → name → short seed note).
-- Profession specialties are for Supplies vendors: "<Profession> Trainer" keeps the
-- parent Profession skillbook icon instead of the craft-specific art.
-- Override specialtyKey: "trainer" forces skillbook; "specialty_*" forces that craft.
function ns.GetSpecialtySubtype(info)
    if not info then
        return nil
    end
    local key = info.specialtyKey
    if key == "trainer" then
        return nil
    end
    if key and key ~= "auto" and key ~= "" and ns.SPECIALTY_BY_KEY[key] then
        return ns.SPECIALTY_BY_KEY[key]
    end

    local taggedProfession = info.types and info.types.profession

    --- @param text string|nil
    --- @param isLooseNote boolean  note field: apply extra trust checks
    local function fromText(text, isLooseNote)
        if type(text) ~= "string" or text == "" then
            return nil
        end
        local sub = ns.MatchSpecialtySubtype(text)
        if not sub then
            return nil
        end
        -- Trainers keep the parent Profession skillbook.
        if sub.parent == "profession" and TextHasTrainer(text) then
            return nil
        end
        if isLooseNote and sub.parent == "profession" then
            local hay = NormalizeName(text)
            if not hay or #hay > 64 then
                return nil
            end
            local hasSupply = hay:find("supplies", 1, true) or hay:find("supply", 1, true)
            local singleToken = not hay:find(" ", 1, true)
            -- "Alchemy supplies", bare "Enchanting", or craft keyword on a
            -- profession-tagged vendor (seed notes are inconsistent).
            if not (hasSupply or singleToken or taggedProfession) then
                return nil
            end
        end
        return sub
    end

    -- Notes that already say "… Supplies" are as trustworthy as subtitles.
    -- Ignore placeholder pack notes like "ATT".
    local note = info.note
    local noteHay = NormalizeName(note)
    if noteHay == "att" then
        note = nil
        noteHay = nil
    end
    local noteIsSupplies = noteHay
        and (noteHay:find("supplies", 1, true) or noteHay:find("supply", 1, true))

    return fromText(info.subtitle, false)
        or fromText(info.name, false)
        or fromText(note, not noteIsSupplies)
end

--- Type key used for pin art/size. General Goods name subtypes, then specialty, then primary.
function ns.GetPinDisplayType(info)
    if info then
        if ns.IsAuctionHouseName(info.name) then
            return ns.AUCTION_HOUSE_DISPLAY_KEY
        end
        if ns.IsPetSuppliesName(info.name) then
            return ns.PET_SUPPLIES_DISPLAY_KEY
        end
        if info.specialtyKey == "trainer" then
            -- Force parent Profession skillbook (or whatever primary type is).
        else
            local specialty = ns.GetSpecialtySubtype(info)
            if specialty then
                return specialty.key
            end
        end
    end
    if ns.PrimaryVendorType then
        return ns.PrimaryVendorType(info and info.types)
    end
    return "general"
end

--- Nested filter/settings rows under a top-level vendor type (specialties + general subtypes).
function ns.NestedTypesForParent(parentKey)
    local list = {}
    if parentKey == "general" then
        for _, sub in ipairs(ns.GENERAL_SUBTYPES or {}) do
            list[#list + 1] = sub
        end
    end
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES or {}) do
        if sub.parent == parentKey then
            list[#list + 1] = sub
        end
    end
    return list
end

function ns.TypeFilterIsShown(key)
    local db = ns.GetDB and ns.GetDB()
    if not db or not db.types then
        return true
    end
    return db.types[key] ~= false
end

--- Set a type filter. When key is a top-level vendor type, cascade to nested children.
function ns.SetTypeFilterEnabled(key, enabled, cascadeChildren)
    local db = ns.GetDB and ns.GetDB()
    if not db then
        return
    end
    db.types = db.types or {}
    db.types[key] = enabled and true or false
    local cascade = cascadeChildren
    if cascade == nil then
        cascade = ns.TYPE_BY_KEY and ns.TYPE_BY_KEY[key] ~= nil
    end
    if cascade then
        for _, nested in ipairs(ns.NestedTypesForParent(key)) do
            db.types[nested.key] = enabled and true or false
        end
    end
end

function ns.ToggleTypeFilter(key)
    local enabled = not ns.TypeFilterIsShown(key)
    ns.SetTypeFilterEnabled(key, enabled)
    if ns.RefreshAll then
        ns.RefreshAll()
    end
    if ns.RefreshSettingsWidgets then
        ns.RefreshSettingsWidgets()
    end
end

--- Global icon scale × per-type relative scale (1.0 = 100%).
-- Pin art is applied by IconPresets.lua (ns.SetTypeIcon).
function ns.GetTypeIconScale(typeKey)
    local db = ns.GetDB and ns.GetDB()
    if not db then
        return 1
    end
    local global = db.iconScale or 1
    local per = 1
    if db.typeIconScale and typeKey then
        if db.typeIconScale[typeKey] ~= nil then
            per = db.typeIconScale[typeKey]
        else
            local specialty = ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[typeKey]
            if specialty and specialty.parent and db.typeIconScale[specialty.parent] then
                per = db.typeIconScale[specialty.parent]
            elseif (typeKey == ns.AUCTION_HOUSE_DISPLAY_KEY or typeKey == ns.PET_SUPPLIES_DISPLAY_KEY)
                and db.typeIconScale.general then
                per = db.typeIconScale.general
            end
        end
    end
    return global * per
end
