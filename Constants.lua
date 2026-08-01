local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = "0.6.4"

-- Vendor type keys (also used as filter + SavedVariables keys)
-- Prefer Minimap\Tracking icons (same art as Blizzard townsfolk tracking / NPC hover).
ns.VENDOR_TYPES = {
    { key = "repair",     label = "Repair",           icon = "Interface\\Minimap\\Tracking\\Repair" },
    { key = "reagents",   label = "Reagents",         icon = "Interface\\Minimap\\Tracking\\Reagents" },
    { key = "food",       label = "Food & Drink",     icon = "Interface\\Minimap\\Tracking\\Food" },
    { key = "poison",     label = "Poisons",          icon = "Interface\\Minimap\\Tracking\\Poisons" },
    { key = "ammo",       label = "Ammunition",       icon = "Interface\\Minimap\\Tracking\\Ammunition" },
    { key = "mounts",     label = "Mounts",           icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { key = "pets",       label = "Pets",             icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { key = "stable",     label = "Stable Master",    icon = "Interface\\Minimap\\Tracking\\StableMaster" },
    { key = "transmog",   label = "Transmog",         icon = "Interface\\Minimap\\Tracking\\Transmogrifier", atlas = "poi-transmogrifier" },
    { key = "decor",      label = "Decor / Housing",  icon = "Interface\\Icons\\Garrison_Building_Storehouse" },
    { key = "profession", label = "Profession",       icon = "Interface\\Minimap\\Tracking\\Profession" },
    -- Class supply vendors (e.g. Druid / Mage supplies). Class trainers are out of scope.
    { key = "class",      label = "Class",            icon = "Interface\\GossipFrame\\TrainerGossipIcon" },
    -- Default / Neutral tabard; Alliance & Horde swap via SetTypeIcon(..., faction)
    { key = "faction",    label = "Faction / Rep",    icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
    { key = "innkeeper",  label = "Innkeeper",        icon = "Interface\\Minimap\\Tracking\\Innkeeper" },
    { key = "barber",     label = "Barber Shop",      icon = "Interface\\Minimap\\Tracking\\Barber" },
    { key = "banker",     label = "Banker",           icon = "Interface\\Minimap\\Tracking\\Banker" },
    -- Combat training dummies (learned on target). Hidden by default — opt in under Vendors & Icons.
    { key = "trainingdummy", label = "Training Dummy", icon = "Interface\\Minimap\\Tracking\\BattleMaster" },
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

-- Legacy General Goods subtype key (pre-pets category). Kept for SavedVariables migration.
ns.PET_SUPPLIES_DISPLAY_KEY = "petsupplies"
ns.PETS_ICON = "Interface\\Icons\\INV_Box_PetCarrier_01"
ns.PET_SUPPLIES_ICON = ns.PETS_ICON

-- Display subtypes of General Goods: keyed by exact pin name, own visibility flag.
-- (Pet Supplies used to live here; it is now the top-level "pets" vendor type.)
ns.GENERAL_SUBTYPES = {
    { key = ns.AUCTION_HOUSE_DISPLAY_KEY, label = "Auction House", fallbackIcon = ns.AUCTION_HOUSE_ICON },
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
    -- Class specialties (parent = "class"). word = true → whole-word match so short
    -- stems like "mage" / "hunter" don't hit "damage" / "Dawnhunter".
    {
        key = "specialty_warrior",
        label = "Warrior Supplies",
        parent = "class",
        word = true,
        match = { "warrior" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Warrior",
    },
    {
        key = "specialty_paladin",
        label = "Paladin Supplies",
        parent = "class",
        word = true,
        match = { "paladin" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Paladin",
    },
    {
        key = "specialty_hunter",
        label = "Hunter Supplies",
        parent = "class",
        word = true,
        match = { "hunter" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Hunter",
    },
    {
        key = "specialty_rogue",
        label = "Rogue Supplies",
        parent = "class",
        word = true,
        match = { "rogue" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Rogue",
    },
    {
        key = "specialty_priest",
        label = "Priest Supplies",
        parent = "class",
        word = true,
        match = { "priest" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Priest",
    },
    {
        key = "specialty_deathknight",
        label = "Death Knight Supplies",
        parent = "class",
        word = true,
        match = { "death knight", "deathknight" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_DeathKnight",
    },
    {
        key = "specialty_shaman",
        label = "Shaman Supplies",
        parent = "class",
        word = true,
        match = { "shaman" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Shaman",
    },
    {
        key = "specialty_mage",
        label = "Mage Supplies",
        parent = "class",
        word = true,
        match = { "mage" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Mage",
    },
    {
        key = "specialty_warlock",
        label = "Warlock Supplies",
        parent = "class",
        word = true,
        match = { "warlock" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Warlock",
    },
    {
        key = "specialty_monk",
        label = "Monk Supplies",
        parent = "class",
        word = true,
        match = { "monk" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Monk",
    },
    {
        key = "specialty_druid",
        label = "Druid Supplies",
        parent = "class",
        word = true,
        match = { "druid" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Druid",
    },
    {
        key = "specialty_demonhunter",
        label = "Demon Hunter Supplies",
        parent = "class",
        word = true,
        match = { "demon hunter", "demonhunter" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_DemonHunter",
    },
    {
        key = "specialty_evoker",
        label = "Evoker Supplies",
        parent = "class",
        word = true,
        match = { "evoker" },
        fallbackIcon = "Interface\\Icons\\ClassIcon_Evoker",
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
    -- Seed vicinity markers without a creature ID (AH/Bank/etc.). Off: learn real NPCs instead.
    showApproximatePins = false,
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
-- Opt-in: cities have many dummies; keep maps clean until the user enables them.
ns.DEFAULTS.types.trainingdummy = false

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

--- True for Auction House pins: exact seed labels, "Auctioneer <Name>", or subtitle "Auctioneer".
function ns.IsAuctionHouseName(name)
    local trimmed = NormalizeName(name)
    if not trimmed then
        return false
    end
    if trimmed == "auction house" or trimmed == "auctioneer" then
        return true
    end
    -- Live NPCs are often "Auctioneer Chilton"; seeds use the bare label.
    if trimmed:find("^auctioneer%s") or trimmed:find("^auction house%s") then
        return true
    end
    return false
end

--- True when text looks like a pet vendor/trainer/breeder/kennel.
-- Whole-word "pet"/"pets" (not substrings like "trumpet"); also breeder/kennel.
function ns.TextLooksLikePets(text)
    local hay = NormalizeName(text)
    if not hay then
        return false
    end
    if hay:find("%f[%a]pets?%f[%A]") then
        return true
    end
    if hay:find("%f[%a]breeders?%f[%A]") then
        return true
    end
    if hay:find("%f[%a]kennels?%f[%A]") then
        return true
    end
    return false
end

--- Back-compat: former exact "Pet Supplies" name check now uses the pets matcher.
function ns.IsPetSuppliesName(name)
    return ns.TextLooksLikePets(name)
end

--- True when text has whole-word "mount"/"mounts", or is a riding trainer.
-- Whole-word avoids false hits on "mountain" / "mountaineer".
function ns.TextLooksLikeMounts(text)
    local hay = NormalizeName(text)
    if not hay then
        return false
    end
    if hay:find("%f[%a]mounts?%f[%A]") then
        return true
    end
    if hay:find("riding trainer", 1, true) then
        return true
    end
    return false
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
            local found
            if sub.word then
                -- Whole-word match: needle bounded by non-letters (or string ends).
                found = hay:find("%f[%a]" .. needle .. "%f[%A]") ~= nil
            else
                found = hay:find(needle, 1, true) ~= nil
            end
            if found then
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

--- Populate leftText/type/guid on C_TooltipInfo payloads (required since 10.0.2).
function ns.SurfaceTooltipData(tooltipData)
    if not tooltipData then
        return nil
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, tooltipData)
        if tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                if line then
                    pcall(TooltipUtil.SurfaceArgs, line)
                end
            end
        end
    end
    return tooltipData
end

--- Legacy notes like "Learned from gossip" → channel string, or nil.
function ns.ParseLegacyLearnNote(note)
    if type(note) ~= "string" or note == "" then
        return nil
    end
    local from = note:match("^[Ll]earned from%s+(.+)$")
    if not from then
        return nil
    end
    from = from:match("^%s*(.-)%s*$") or from
    return from ~= "" and from or nil
end

--- Move legacy "Learned from …" note text onto learnedFrom and clear note.
function ns.MigrateLegacyLearnNote(vendor)
    if type(vendor) ~= "table" then
        return vendor
    end
    local from = ns.ParseLegacyLearnNote(vendor.note)
    if from then
        if type(vendor.learnedFrom) ~= "string" or vendor.learnedFrom == "" then
            vendor.learnedFrom = from
        end
        vendor.note = nil
    end
    return vendor
end

--- Tooltip/status line for data provenance (never stored in note).
-- source pipeline: "seed" | "learned" | "override"
-- learnedFrom: interaction channel ("merchant", "gossip", "trainer", …)
function ns.FormatVendorProvenance(info)
    if not info then
        return "Seed"
    end
    if info.source == "override" then
        return "Override"
    end
    local from = info.learnedFrom
    if type(from) == "string" and from ~= "" then
        return "Learned from " .. from
    end
    if info.source == "learned" then
        return "Learned"
    end
    return "Seed"
end

local CREATURE_TYPE_SKIP = {
    humanoid = true,
    beast = true,
    dragonkin = true,
    elemental = true,
    giant = true,
    undead = true,
    demon = true,
    mechanical = true,
    aberration = true,
    critter = true,
    totem = true,
    noncombatpet = true,
    gascloud = true,
    wildpet = true,
    notspecified = true,
    alliance = true,
    horde = true,
}

local function IsSkippableTooltipLine(text, unitName, index)
    if type(text) ~= "string" or text == "" then
        return true
    end
    local levelToken = LEVEL or "Level"
    local lower = NormalizeName(text)
    if not lower then
        return true
    end
    local nameLower = NormalizeName(unitName)
    if index == 1 and nameLower and lower == nameLower then
        return true
    end
    if text:sub(1, #levelToken) == levelToken then
        return true
    end
    if lower:find("^%(", 1) or lower:find("^<%d", 1) then
        return true
    end
    -- "Humanoid", "Beast", etc. (strip spaces for Non-combat Pet)
    local compact = lower:gsub("[%s%-]", "")
    if CREATURE_TYPE_SKIP[compact] then
        return true
    end
    return false
end

--- Pull NPC title/subtitle from tooltip data (skip name + level + creature-type lines).
-- Prefers lines that look like "Alchemy Supplies" / "Enchanting Trainer".
function ns.SubtitleFromTooltipData(tooltipData, unitName)
    if not tooltipData or not tooltipData.lines then
        return nil
    end
    ns.SurfaceTooltipData(tooltipData)
    local candidates = {}
    for i, line in ipairs(tooltipData.lines) do
        local text = line and line.leftText
        if type(text) == "string" and text ~= "" and not IsSkippableTooltipLine(text, unitName, i) then
            candidates[#candidates + 1] = text
        end
    end
    if #candidates == 0 then
        return nil
    end
    for _, text in ipairs(candidates) do
        local lower = NormalizeName(text)
        if lower
            and (
                ns.MatchSpecialtySubtype(text)
                or lower:find("trainer", 1, true)
                or lower:find("supplies", 1, true)
                or lower:find("supply", 1, true)
                or lower:find("vendor", 1, true)
                or lower:find("banker", 1, true)
            )
        then
            return text
        end
    end
    return candidates[1]
end

--- Normalize seed/pack notes for specialty matching ("ATT — Alchemy…" → "alchemy…").
function ns.NoteTextForSpecialtyMatch(note)
    if type(note) ~= "string" or note == "" then
        return nil
    end
    local hay = NormalizeName(note)
    if not hay or hay == "att" then
        return nil
    end
    -- Strip common pack prefixes.
    hay = hay:gsub("^att%s*[—%-%:]*%s*", "")
    hay = hay:match("^%s*(.-)%s*$") or hay
    if hay == "" or hay == "att" then
        return nil
    end
    return hay
end

--- Auto specialty key from subtitle/name/note: "trainer" | "specialty_*" | nil.
-- Used when learning so craft icons survive even if later subtitle reads fail.
function ns.DetectSpecialtyKey(info)
    if not info then
        return nil
    end
    -- Mount / riding trainers are mounts category, not profession trainers.
    if ns.TextLooksLikeMounts(info.subtitle) or ns.TextLooksLikeMounts(info.name) then
        return nil
    end
    -- Pet / battle-pet trainers and breeders are pets category, not profession.
    if ns.TextLooksLikePets(info.subtitle) or ns.TextLooksLikePets(info.name) then
        return nil
    end
    local existing = info.specialtyKey
    if existing == "trainer" then
        return "trainer"
    end
    if existing and existing ~= "" and existing ~= "auto" and ns.SPECIALTY_BY_KEY[existing] then
        return existing
    end

    local note = ns.NoteTextForSpecialtyMatch(info.note)
    local texts = { info.subtitle, info.name, note }
    for _, text in ipairs(texts) do
        if type(text) == "string" and text ~= "" then
            local sub = ns.MatchSpecialtySubtype(text)
            if sub and sub.parent == "profession" then
                if TextHasTrainer(text) then
                    return "trainer"
                end
                return sub.key
            elseif sub and sub.parent == "class" then
                -- Class trainers are out of scope; don't learn them as class-supply pins.
                if TextHasTrainer(text) then
                    return nil
                end
                return sub.key
            elseif TextHasTrainer(text) then
                return "trainer"
            end
        end
    end
    return nil
end

--- Specialty for a vendor info row (subtitle → name → short seed note).
-- Profession specialties are for Supplies vendors: "<Profession> Trainer" keeps the
-- parent Profession skillbook icon instead of the craft-specific art.
-- Override/learned specialtyKey: "trainer" forces skillbook; "specialty_*" forces that craft.
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
    local taggedClass = info.types and info.types.class

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
        local specialtyParent = sub.parent == "profession" or sub.parent == "class"
        -- Trainers keep the parent skillbook / class icon, not a supplies specialty.
        if specialtyParent and TextHasTrainer(text) then
            return nil
        end
        if isLooseNote and specialtyParent then
            local hay = NormalizeName(text)
            if not hay or #hay > 64 then
                return nil
            end
            local hasSupply = hay:find("supplies", 1, true) or hay:find("supply", 1, true)
            local singleToken = not hay:find(" ", 1, true)
            local tagged = (sub.parent == "profession" and taggedProfession)
                or (sub.parent == "class" and taggedClass)
            -- "Druid supplies", a bare "Druid" token, or a class keyword on a
            -- class-tagged vendor (seed notes are inconsistent).
            if not (hasSupply or singleToken or tagged) then
                return nil
            end
        end
        return sub
    end

    local note = ns.NoteTextForSpecialtyMatch(info.note)
    local noteHay = note
    local noteIsSupplies = noteHay
        and (noteHay:find("supplies", 1, true) or noteHay:find("supply", 1, true))

    return fromText(info.subtitle, false)
        or fromText(info.name, false)
        or fromText(note, not noteIsSupplies)
end

local function CraftBaseLabel(specialty)
    if not specialty or type(specialty.label) ~= "string" then
        return nil
    end
    return (specialty.label:gsub("%s+Supplies%s*$", ""))
end

--- Human-readable role for a vendor: "Alchemy Supplies", "Alchemy Trainer", or nil.
-- Uses specialtyKey / subtitle / note — not only live tooltip text.
function ns.GetVendorRoleLabel(info)
    if not info then
        return nil
    end
    local key = info.specialtyKey
    local craft = (key and key ~= "auto" and key ~= "trainer" and ns.SPECIALTY_BY_KEY[key]) or nil
    local isTrainer = key == "trainer"

    local texts = {
        info.subtitle,
        info.name,
        ns.NoteTextForSpecialtyMatch and ns.NoteTextForSpecialtyMatch(info.note) or info.note,
    }
    for _, text in ipairs(texts) do
        if type(text) == "string" and text ~= "" then
            -- Mount / pet trainers keep their own category labels, not "Profession Trainer".
            if ns.TextLooksLikeMounts(text) or ns.TextLooksLikePets(text) then
                -- skip trainer/craft role from this text
            else
                local sub = ns.MatchSpecialtySubtype(text)
                if sub then
                    if not craft then
                        craft = sub
                    end
                    if (sub.parent == "profession" or sub.parent == "class") and TextHasTrainer(text) then
                        isTrainer = true
                    end
                elseif TextHasTrainer(text) then
                    isTrainer = true
                end
            end
        end
    end

    if not craft and not isTrainer then
        craft = ns.GetSpecialtySubtype(info)
    end

    if isTrainer then
        local base = CraftBaseLabel(craft)
        if base and craft and (craft.parent == "profession" or craft.parent == "class") then
            return base .. " Trainer"
        end
        return "Profession Trainer"
    end
    if craft then
        return craft.label
    end
    return nil
end

--- Type labels for tooltips/pickers: specialty role replaces parent Profession/Food when known.
function ns.VendorTypeLabelList(info)
    if not info then
        return ""
    end
    local role = ns.GetVendorRoleLabel(info)
    local roleParent
    if role then
        if info.specialtyKey == "trainer" then
            roleParent = "profession"
        else
            local sub = ns.GetSpecialtySubtype(info)
                or (info.specialtyKey and ns.SPECIALTY_BY_KEY[info.specialtyKey])
            roleParent = sub and sub.parent or "profession"
        end
    end

    local isAuction = ns.IsAuctionHouseName(info.name) or ns.IsAuctionHouseName(info.subtitle)
    local labels = {}
    local replaced = false
    for _, def in ipairs(ns.VENDOR_TYPES) do
        if info.types and info.types[def.key] then
            if role and roleParent == def.key then
                labels[#labels + 1] = role
                replaced = true
            elseif def.key == "general" and isAuction then
                labels[#labels + 1] = "Auction House"
            else
                labels[#labels + 1] = def.label
            end
        end
    end
    if role and not replaced then
        table.insert(labels, 1, role)
    end
    if #labels == 0 then
        return role or ""
    end
    return table.concat(labels, ", ")
end

--- Type key used for pin art/size. General Goods name subtypes, then specialty, then primary.
function ns.GetPinDisplayType(info)
    if info then
        if ns.IsAuctionHouseName(info.name) or ns.IsAuctionHouseName(info.subtitle) then
            return ns.AUCTION_HOUSE_DISPLAY_KEY
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
            elseif typeKey == ns.AUCTION_HOUSE_DISPLAY_KEY and db.typeIconScale.general then
                per = db.typeIconScale.general
            end
        end
    end
    return global * per
end
