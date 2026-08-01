local _, ns = ...

local Database = {}
ns.Database = Database

local indexByMap = {} -- [mapID] = { vendor, ... }
local byNpcID = {}   -- [npcID] = vendor
local zoneNameToID = {} -- [zoneName] = mapID
local zoneCacheBuilt = false

-- Reused scratch to avoid per-call allocation in hot paths (map/minimap refresh).
local translateScratch = CreateVector2D(0, 0)
local resultSeen = {}

local function CopyTypes(types)
    local out = {}
    if type(types) == "table" then
        for k, v in pairs(types) do
            if v then
                out[k] = true
            end
        end
    end
    return out
end

local function EnsureZoneCache()
    if zoneCacheBuilt then
        return
    end
    zoneCacheBuilt = true
    -- Scan a generous range of uiMapIDs (housing / Midnight maps included)
    for i = 1, 6000 do
        local info = C_Map.GetMapInfo(i)
        if info and info.name and not zoneNameToID[info.name] then
            zoneNameToID[info.name] = i
        end
    end
end

local function ResolveMapID(v)
    if v.mapID then
        return v.mapID
    end
    if v.zoneName then
        EnsureZoneCache()
        return zoneNameToID[v.zoneName]
    end
    return nil
end

local function NormalizeVendor(v, source)
    if not v or not v.x or not v.y then
        return nil
    end
    if ns.MigrateLegacyLearnNote then
        ns.MigrateLegacyLearnNote(v)
    end
    local mapID = ResolveMapID(v)
    if not mapID then
        return nil
    end
    local types = CopyTypes(v.types)
    if not next(types) then
        types.general = true
    end
    local name = v.name
    if type(name) ~= "string" or name == "" then
        name = "Unknown Vendor"
    end
    if v.npcID and ns.Names then
        local resolved = ns.Names:Lookup(v.npcID)
        if resolved then
            name = resolved
        end
    end
    local learnedFrom = v.learnedFrom
    if type(learnedFrom) ~= "string" or learnedFrom == "" then
        learnedFrom = nil
    end
    local specialtyKey = v.specialtyKey
    if specialtyKey == "" or specialtyKey == "auto" then
        specialtyKey = nil
    end
    -- Backfill craft/trainer specialty from subtitle/note for older learned rows.
    if not specialtyKey and ns.DetectSpecialtyKey then
        specialtyKey = ns.DetectSpecialtyKey({
            subtitle = v.subtitle,
            name = name,
            note = v.note,
            types = types,
            specialtyKey = v.specialtyKey,
        })
    end
    -- Name/subtitle with whole-word "mount" (or riding trainer) → mounts.
    if ns.TextLooksLikeMounts and (ns.TextLooksLikeMounts(v.subtitle) or ns.TextLooksLikeMounts(name)) then
        types.mounts = true
        types.general = nil
        if specialtyKey == "trainer" then
            specialtyKey = nil
        end
        local title = string.lower((v.subtitle or "") .. " " .. (name or ""))
        if title:find("trainer", 1, true) then
            types.profession = nil
        end
    end
    -- Name/subtitle with pet/breeder/kennel → pets.
    if ns.TextLooksLikePets and (ns.TextLooksLikePets(v.subtitle) or ns.TextLooksLikePets(name)) then
        types.pets = true
        types.general = nil
        if specialtyKey == "trainer" then
            specialtyKey = nil
        end
        local title = string.lower((v.subtitle or "") .. " " .. (name or ""))
        if title:find("trainer", 1, true) then
            types.profession = nil
        end
    end
    return {
        id = v.id or v.npcID or (source .. ":" .. tostring(mapID) .. ":" .. tostring(v.x) .. ":" .. tostring(v.y) .. ":" .. tostring(v.name)),
        npcID = v.npcID,
        name = name,
        mapID = mapID,
        x = v.x,
        y = v.y,
        faction = v.faction or "Neutral",
        types = types,
        note = v.note,
        subtitle = v.subtitle,
        specialtyKey = specialtyKey,
        learnedFrom = learnedFrom,
        repFactionID = v.repFactionID,
        minStanding = v.minStanding,
        source = source,
        replaceTypes = v.replaceTypes,
    }
end

local function ClearIndex()
    wipe(indexByMap)
    wipe(byNpcID)
end

-- Prefer capital/core rows with real supplies notes over LoD pack duplicates that
-- only carry note="ATT" (those otherwise win nothing useful and hide craft icons).
local function SeedSpecialtyQuality(vendor)
    if not vendor then
        return 0
    end
    local score = 0
    local note = type(vendor.note) == "string" and vendor.note:lower() or ""
    if note:find("supplies", 1, true) or note:find("supply", 1, true) then
        score = score + 50
    elseif note ~= "" and note ~= "att" then
        score = score + 8
    end
    if type(vendor.subtitle) == "string" and vendor.subtitle ~= "" then
        score = score + 40
    end
    if vendor.specialtyKey and vendor.specialtyKey ~= "" and vendor.specialtyKey ~= "auto" then
        score = score + 30
    end
    if vendor.types then
        if vendor.types.profession then
            score = score + 10
        end
        if vendor.types.general and not vendor.types.profession then
            score = score - 2
        end
    end
    return score
end

local function RemoveVendorFromMapIndex(vendor)
    if not vendor or not vendor.mapID then
        return
    end
    local list = indexByMap[vendor.mapID]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == vendor then
            table.remove(list, i)
            return
        end
    end
end

local function AddToIndex(vendor)
    if not vendor then
        return
    end
    if vendor.npcID then
        local existing = byNpcID[vendor.npcID]
        if existing and existing ~= vendor then
            if SeedSpecialtyQuality(vendor) <= SeedSpecialtyQuality(existing) then
                return
            end
            RemoveVendorFromMapIndex(existing)
        end
        byNpcID[vendor.npcID] = vendor
    end
    indexByMap[vendor.mapID] = indexByMap[vendor.mapID] or {}
    indexByMap[vendor.mapID][#indexByMap[vendor.mapID] + 1] = vendor
end

local function PreferOverride()
    local db = ns.GetDB and ns.GetDB()
    -- Default: user edits win over later learned visits.
    return not db or db.learnedOverrideMode ~= "preferLearned"
end

local function ProtectOverrideNotes()
    local db = ns.GetDB and ns.GetDB()
    return not db or db.protectOverrideNotes ~= false
end

local function GetOverrideForNpc(npcID)
    if ns.GetVendorOverride then
        return ns.GetVendorOverride(npcID)
    end
    return nil
end

local function GetOverrideForVendor(vendor)
    if not vendor or not ns.GetVendorOverride then
        return nil
    end
    if ns.VendorOverrideKey then
        return ns.GetVendorOverride(ns.VendorOverrideKey(vendor))
    end
    return ns.GetVendorOverride(vendor.npcID)
end

local function OverrideHasField(ov, field)
    if type(ov) ~= "table" then
        return false
    end
    if field == "note" then
        return ov.note ~= nil
    end
    if field == "subtitle" then
        return ov.subtitle ~= nil
    end
    if field == "types" then
        return ov.types ~= nil
    end
    if field == "faction" then
        return ov.faction ~= nil
    end
    if field == "name" then
        return ov.name ~= nil and ov.name ~= ""
    end
    return false
end

local function ForEachVendorWithNpcID(npcID, fn)
    if not npcID or not fn then
        return
    end
    for _, list in pairs(indexByMap) do
        for _, vendor in ipairs(list) do
            if vendor.npcID == npcID then
                fn(vendor)
            end
        end
    end
end

--- Apply an override key to every matching indexed row (npcID or synthetic seed id).
local function ForEachVendorMatchingOverrideKey(key, fn)
    if key == nil or key == "" or not fn then
        return
    end
    local seen = {}
    local function visit(vendor)
        if vendor and not seen[vendor] then
            seen[vendor] = true
            fn(vendor)
        end
    end
    local npcID = tonumber(key)
    if npcID then
        ForEachVendorWithNpcID(npcID, visit)
        visit(byNpcID[npcID])
        return
    end
    if type(key) == "string" then
        for _, list in pairs(indexByMap) do
            for _, vendor in ipairs(list) do
                if vendor.id == key then
                    visit(vendor)
                end
            end
        end
    end
end

--- Merge a learned visit onto an indexed vendor row.
-- Pipeline priority: seed < learned < override (override applied later).
-- When preferOverride, skip fields the user already set on their override so a
-- pre-visit edit is not clobbered by the first merchant open.
local function MergeLearnedOnto(existing, learned, ov)
    if not existing or not learned then
        return
    end
    local preferOv = PreferOverride()
    local lockFields = preferOv and type(ov) == "table"

    -- Visited position is always authoritative (override UI does not edit coords).
    existing.mapID = learned.mapID
    existing.x = learned.x
    existing.y = learned.y
    existing.repFactionID = learned.repFactionID or existing.repFactionID
    existing.minStanding = learned.minStanding or existing.minStanding

    if not (lockFields and OverrideHasField(ov, "name")) then
        existing.name = learned.name or existing.name
    end
    if not (lockFields and OverrideHasField(ov, "faction")) then
        existing.faction = learned.faction or existing.faction
    end
    if not (lockFields and OverrideHasField(ov, "types")) then
        if learned.replaceTypes and learned.types then
            -- Fresh merchant/trainer scan replaces inventory tags, but keep seed
            -- reputation/faction pin tags that scans never set.
            local keepFaction = existing.types and existing.types.faction
            local keepDecor = existing.types and existing.types.decor
            existing.types = CopyTypes(learned.types)
            if keepFaction then
                existing.types.faction = true
            end
            if keepDecor then
                existing.types.decor = true
            end
            if not next(existing.types) then
                existing.types.general = true
            end
        else
            for k, v in pairs(learned.types or {}) do
                if v then
                    existing.types[k] = true
                end
            end
        end
    end

    if learned.note then
        local noteLocked = OverrideHasField(ov, "note")
            and (preferOv or ProtectOverrideNotes())
        if not noteLocked then
            -- Ignore legacy provenance strings if any still arrive as note.
            if not (ns.ParseLegacyLearnNote and ns.ParseLegacyLearnNote(learned.note)) then
                existing.note = learned.note
            end
        end
    end

    -- Only apply a real subtitle; never clear a prior title with a failed capture.
    if learned.subtitle and learned.subtitle ~= ""
        and not (lockFields and OverrideHasField(ov, "subtitle"))
    then
        existing.subtitle = learned.subtitle
    end

    -- Persist auto-detected craft/trainer specialty from visits (unless user overrode it).
    if learned.specialtyKey and learned.specialtyKey ~= "" and learned.specialtyKey ~= "auto" then
        local ovLocksSpecialty = type(ov) == "table" and ov.specialtyKey ~= nil
        if not ovLocksSpecialty then
            existing.specialtyKey = learned.specialtyKey
        end
    end

    if learned.learnedFrom and learned.learnedFrom ~= "" then
        existing.learnedFrom = learned.learnedFrom
    end

    existing.source = "learned"
end

--- Apply one override onto a vendor according to conflict settings.
-- preferOverride: name/types/faction/note from override win.
-- preferLearned: learned already applied; only re-apply hidden, and notes when protected.
local function ApplyOverrideToVendor(existing, ov)
    if not existing or type(ov) ~= "table" then
        return
    end
    local preferOv = PreferOverride()
    local applied = false

    -- Hide is always a user intent; learning never sets it.
    if ov.hidden then
        existing.hidden = true
        applied = true
    else
        existing.hidden = nil
    end

    local applyNote = OverrideHasField(ov, "note") and (preferOv or ProtectOverrideNotes())
    if applyNote then
        -- Allow empty string to clear a seed/learned note
        existing.note = ov.note ~= "" and ov.note or nil
        applied = true
    end

    if OverrideHasField(ov, "subtitle") and preferOv then
        existing.subtitle = ov.subtitle ~= "" and ov.subtitle or nil
        applied = true
    end

    -- specialtyKey is always user intent when present on the override.
    if ov.specialtyKey ~= nil then
        if ov.specialtyKey == "" or ov.specialtyKey == "auto" then
            existing.specialtyKey = nil
        else
            existing.specialtyKey = ov.specialtyKey
        end
        applied = true
    end

    if preferOv then
        if ov.types ~= nil then
            existing.types = CopyTypes(ov.types)
            if not next(existing.types) then
                existing.types.general = true
            end
            applied = true
        end
        if ov.faction ~= nil then
            existing.faction = ov.faction
            applied = true
        end
        if ov.name ~= nil and ov.name ~= "" then
            existing.name = ov.name
            applied = true
        end
    end

    -- Per-pin icon is always user intent when present on the override.
    if ov.iconPreset ~= nil and ov.iconPreset ~= "" and ov.iconPreset ~= "default" then
        existing.iconPreset = ov.iconPreset
        applied = true
    else
        existing.iconPreset = nil
    end
    if ov.iconCustom ~= nil and ov.iconCustom ~= "" then
        existing.iconCustom = ov.iconCustom
        applied = true
    else
        existing.iconCustom = nil
    end

    if applied then
        existing.source = "override"
    end
end

local function ApplyOverrides()
    local overrides = VendorMapOverridesDB
    if type(overrides) ~= "table" then
        return
    end
    -- Match by npcID or synthetic seed id (hub Auctioneer/Bank markers have no npcID).
    for key, ov in pairs(overrides) do
        if type(ov) == "table" then
            ForEachVendorMatchingOverrideKey(key, function(vendor)
                ApplyOverrideToVendor(vendor, ov)
            end)
        end
    end
end

--- Normalize a seed row in place and reset its overlayable fields to the pristine
-- authored baseline. The same table is stored in ns.SeedVendors and the index, so we
-- avoid keeping a second normalized copy per vendor. Learned/override merges mutate the
-- returned row, but every rebuild resets it here first, keeping the pipeline idempotent.
local function PrepareSeedRow(raw)
    if not raw or not raw.x or not raw.y then
        return nil
    end
    if not raw._vmNormalized then
        local mapID = ResolveMapID(raw)
        if not mapID then
            return nil
        end
        raw._seedMapID = mapID
        raw._seedName = raw.name
        raw._seedFaction = raw.faction or "Neutral"
        raw._seedTypes = raw.types -- authored table; treated as read-only baseline
        raw._seedNote = raw.note
        raw._seedSubtitle = raw.subtitle
        raw._seedSpecialtyKey = raw.specialtyKey
        raw._seedRep = raw.repFactionID
        raw._seedStanding = raw.minStanding
        raw.id = raw.id or raw.npcID
            or ("seed:" .. tostring(mapID) .. ":" .. tostring(raw.x) .. ":" .. tostring(raw.y) .. ":" .. tostring(raw.name))
        raw._vmNormalized = true
    end

    raw.mapID = raw._seedMapID
    local name = raw._seedName
    if type(name) ~= "string" or name == "" then
        name = "Unknown Vendor"
    end
    if raw.npcID and ns.Names then
        local resolved = ns.Names:Lookup(raw.npcID)
        if resolved then
            name = resolved
        end
    end
    raw.name = name
    raw.faction = raw._seedFaction
    raw.types = CopyTypes(raw._seedTypes)
    if not next(raw.types) then
        raw.types.general = true
    end
    raw.note = raw._seedNote
    raw.subtitle = raw._seedSubtitle
    raw.specialtyKey = raw._seedSpecialtyKey
    -- Seed name/subtitle with whole-word "mount" (or riding trainer) → mounts.
    if ns.TextLooksLikeMounts and (ns.TextLooksLikeMounts(raw.subtitle) or ns.TextLooksLikeMounts(name)) then
        raw.types.mounts = true
        raw.types.general = nil
        if raw.specialtyKey == "trainer" then
            raw.specialtyKey = nil
        end
        local title = string.lower((raw.subtitle or "") .. " " .. (name or ""))
        if title:find("trainer", 1, true) then
            raw.types.profession = nil
        end
    end
    -- Seed name/subtitle with pet/breeder/kennel → pets.
    if ns.TextLooksLikePets and (ns.TextLooksLikePets(raw.subtitle) or ns.TextLooksLikePets(name)) then
        raw.types.pets = true
        raw.types.general = nil
        if raw.specialtyKey == "trainer" then
            raw.specialtyKey = nil
        end
        local title = string.lower((raw.subtitle or "") .. " " .. (name or ""))
        if title:find("trainer", 1, true) then
            raw.types.profession = nil
        end
    end
    raw.repFactionID = raw._seedRep
    raw.minStanding = raw._seedStanding
    raw.source = "seed"
    raw.hidden = nil
    raw.iconPreset = nil
    raw.iconCustom = nil
    return raw
end

function Database:Rebuild()
    ClearIndex()

    if ns.SeedVendors then
        for _, raw in ipairs(ns.SeedVendors) do
            AddToIndex(PrepareSeedRow(raw))
        end
    end

    local learned = VendorMapLearnedDB
    if type(learned) == "table" then
        for _, raw in ipairs(learned) do
            local vendor = NormalizeVendor(raw, "learned")
            if vendor then
                if vendor.npcID and byNpcID[vendor.npcID] then
                    local ov = GetOverrideForVendor(vendor) or GetOverrideForNpc(vendor.npcID)
                    -- All indexed rows with this npcID (hubs + packs can share one ID).
                    ForEachVendorWithNpcID(vendor.npcID, function(existing)
                        MergeLearnedOnto(existing, vendor, ov)
                    end)
                else
                    AddToIndex(vendor)
                end
            end
        end
    end

    ApplyOverrides()
end

local function FactionAllowed(faction)
    local db = ns.GetDB()
    local key = faction or "Neutral"
    if key ~= "Alliance" and key ~= "Horde" then
        key = "Neutral"
    end
    return db.factions[key]
end

local function TypesAllowed(types)
    local db = ns.GetDB()
    -- Missing filter keys default to shown (handles new types added after first install)
    for key in pairs(types) do
        if db.types[key] ~= false then
            return true
        end
    end
    return false
end

-- Display subtypes/specialties have their own visibility flag independent of parent.
local function SubtypeVisible(vendor)
    local db = ns.GetDB()
    local name = vendor and vendor.name
    if ns.IsAuctionHouseName(name) or ns.IsAuctionHouseName(vendor and vendor.subtitle) then
        return db.types[ns.AUCTION_HOUSE_DISPLAY_KEY] ~= false
    end
    local specialty = ns.GetSpecialtySubtype and ns.GetSpecialtySubtype(vendor)
    if specialty then
        return db.types[specialty.key] ~= false
    end
    return true
end

--- Vicinity markers (no creature ID) are hidden unless the user opts in.
local function ApproximateVisible(vendor)
    if vendor and vendor.npcID then
        return true
    end
    local db = ns.GetDB()
    return db and db.showApproximatePins == true
end

local function TranslateToMap(fromMapID, x, y, toMapID)
    if fromMapID == toMapID then
        return x, y
    end
    translateScratch:SetXY(x, y)
    local worldID, worldPos = C_Map.GetWorldPosFromMapPos(fromMapID, translateScratch)
    if not worldPos then
        return nil
    end
    local _, mapPos = C_Map.GetMapPosFromWorldPos(worldID, worldPos, toMapID)
    if not mapPos then
        return nil
    end
    return mapPos.x, mapPos.y
end

local function CollectChildMapIDs(mapID, into, seen)
    seen = seen or {}
    if seen[mapID] then
        return
    end
    seen[mapID] = true
    local children = C_Map.GetMapChildrenInfo(mapID, nil, true)
    if not children then
        return
    end
    for _, info in ipairs(children) do
        into[#into + 1] = info.mapID
        seen[info.mapID] = true
    end
end

--- Maps whose vendors should be considered for the viewed (zone-level) map: the map
-- itself, its child floors, and parent zones up to (but not including projection onto)
-- the continent. Continent/world views are handled earlier and never reach here.
local function CollectRelatedMapIDs(viewMapID)
    local maps = { viewMapID }
    local seen = { [viewMapID] = true }

    -- Always include child maps (city floors / micro dungeons). Learned NPCs often
    -- save on a different uiMapID than the parent city map you browse.
    CollectChildMapIDs(viewMapID, maps, seen)

    local continentType = (Enum.UIMapType and Enum.UIMapType.Continent) or 2
    local mapInfo = C_Map.GetMapInfo(viewMapID)
    local parentID = mapInfo and mapInfo.parentMapID
    local depth = 0
    while parentID and parentID > 0 and depth < 6 do
        local pInfo = C_Map.GetMapInfo(parentID)
        if not pInfo then
            break
        end
        -- Stop before reaching continent/world; VendorMap does not project that far.
        if pInfo.mapType and pInfo.mapType <= continentType then
            break
        end
        if not seen[parentID] then
            maps[#maps + 1] = parentID
            seen[parentID] = true
        end
        parentID = pInfo.parentMapID
        depth = depth + 1
    end

    return maps
end

--- Collect visible pins for a viewed map.
-- When outBuffer is supplied, its row tables are recycled in place (rows beyond the
-- result count are cleared) to avoid per-refresh allocation. The buffer is only valid
-- until the next GetPinsForMap call that reuses it, so each renderer passes its own.
function Database:GetPinsForMap(viewMapID, outBuffer)
    local results = outBuffer or {}
    local db = ns.GetDB()
    if not db.enabled then
        for i = #results, 1, -1 do
            results[i] = nil
        end
        return results
    end

    -- VendorMap shows zone-level pins only. Continent/world views render nothing
    -- (vendor pins are meaningless at that scale and would cluster into city blobs).
    local mapInfo = C_Map.GetMapInfo(viewMapID)
    local continentType = (Enum.UIMapType and Enum.UIMapType.Continent) or 2
    if mapInfo and mapInfo.mapType and mapInfo.mapType <= continentType then
        for i = #results, 1, -1 do
            results[i] = nil
        end
        return results
    end

    local maps = CollectRelatedMapIDs(viewMapID)
    local seen = resultSeen
    wipe(seen)

    local n = 0
    for _, mapID in ipairs(maps) do
        local list = indexByMap[mapID]
        if list then
            for _, vendor in ipairs(list) do
                if not vendor.hidden
                    and ApproximateVisible(vendor)
                    and FactionAllowed(vendor.faction)
                    and TypesAllowed(vendor.types)
                    and SubtypeVisible(vendor)
                then
                    local x, y = TranslateToMap(vendor.mapID, vendor.x, vendor.y, viewMapID)
                    -- Keep edge pins; only drop clearly invalid translations
                    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                        local key = vendor.id
                        if not seen[key] then
                            seen[key] = true
                            local displayName = vendor.name
                            if ns.Names then
                                displayName = ns.Names:DisplayName(vendor)
                            end
                            n = n + 1
                            local row = results[n]
                            if not row then
                                row = {}
                                results[n] = row
                            end
                            row.id = vendor.id
                            row.npcID = vendor.npcID
                            row.name = displayName
                            row.mapID = vendor.mapID
                            row.viewMapID = viewMapID
                            row.x = x
                            row.y = y
                            row.originX = vendor.x
                            row.originY = vendor.y
                            row.faction = vendor.faction
                            row.types = vendor.types
                            row.note = vendor.note
                            row.subtitle = vendor.subtitle
                            row.specialtyKey = vendor.specialtyKey
                            row.learnedFrom = vendor.learnedFrom
                            row.repFactionID = vendor.repFactionID
                            row.minStanding = vendor.minStanding
                            row.source = vendor.source
                            row.hidden = vendor.hidden
                            row.iconPreset = vendor.iconPreset
                            row.iconCustom = vendor.iconCustom
                        end
                    end
                end
            end
        end
    end

    -- Drop surplus rows from a previous, larger result so ipairs/# stop at n.
    for i = #results, n + 1, -1 do
        results[i] = nil
    end
    return results
end

function Database:FindByNpcID(npcID)
    return byNpcID[npcID]
end

--- Resolve a vendor for an override key (numeric npcID or synthetic seed id).
function Database:FindByOverrideKey(key)
    if key == nil or key == "" then
        return nil
    end
    local npcID = tonumber(key)
    if npcID and byNpcID[npcID] then
        return byNpcID[npcID]
    end
    if type(key) == "string" then
        for _, list in pairs(indexByMap) do
            for _, vendor in ipairs(list) do
                if vendor.id == key then
                    return vendor
                end
            end
        end
    end
    return nil
end

function Database:GetIndexByMap()
    return indexByMap
end

-- Learned rows differ meaningfully? Coordinate jitter within POSITION_EPSILON is
-- ignored so standing still (or map float noise) is not reported as a change.
local POSITION_EPSILON = 0.002

local function TypesEqual(a, b)
    a, b = a or {}, b or {}
    for k, v in pairs(a) do
        if v and not b[k] then
            return false
        end
    end
    for k, v in pairs(b) do
        if v and not a[k] then
            return false
        end
    end
    return true
end

local function LearnedVendorChanged(prev, vendor)
    if (prev.name or "") ~= (vendor.name or "") then return true end
    if prev.mapID ~= vendor.mapID then return true end
    if math.abs((prev.x or 0) - (vendor.x or 0)) > POSITION_EPSILON then return true end
    if math.abs((prev.y or 0) - (vendor.y or 0)) > POSITION_EPSILON then return true end
    if (prev.faction or "") ~= (vendor.faction or "") then return true end
    if (prev.subtitle or "") ~= (vendor.subtitle or "") then return true end
    if (prev.specialtyKey or "") ~= (vendor.specialtyKey or "") then return true end
    if (prev.note or "") ~= (vendor.note or "") then return true end
    if (prev.learnedFrom or "") ~= (vendor.learnedFrom or "") then return true end
    if not TypesEqual(prev.types, vendor.types) then return true end
    return false
end

--- Returns isNew, changed. isNew when a new learned row is appended; changed when an
--- existing row is replaced with meaningfully different data (see LearnedVendorChanged).
function Database:UpsertLearned(vendor)
    VendorMapLearnedDB = VendorMapLearnedDB or {}
    if ns.MigrateLegacyLearnNote then
        ns.MigrateLegacyLearnNote(vendor)
    end
    local npcID = vendor.npcID
    local replaced = false
    local changed = false
    if npcID then
        for i, existing in ipairs(VendorMapLearnedDB) do
            if existing.npcID == npcID then
                local prev = existing
                if ns.MigrateLegacyLearnNote then
                    ns.MigrateLegacyLearnNote(prev)
                end
                -- Keep a previously captured subtitle when this visit failed to read one.
                if (not vendor.subtitle or vendor.subtitle == "") and prev.subtitle and prev.subtitle ~= "" then
                    vendor.subtitle = prev.subtitle
                end
                -- Notes are user/seed text only — never drop a real note for nil.
                if (not vendor.note or vendor.note == "") and prev.note and prev.note ~= "" then
                    vendor.note = prev.note
                end
                if (not vendor.learnedFrom or vendor.learnedFrom == "")
                    and prev.learnedFrom and prev.learnedFrom ~= ""
                then
                    vendor.learnedFrom = prev.learnedFrom
                end
                -- Keep a previously detected specialty when this visit couldn't classify.
                if (not vendor.specialtyKey or vendor.specialtyKey == "" or vendor.specialtyKey == "auto")
                    and prev.specialtyKey and prev.specialtyKey ~= "" and prev.specialtyKey ~= "auto"
                then
                    vendor.specialtyKey = prev.specialtyKey
                end
                -- Re-detect from preserved subtitle/note if still unset.
                if (not vendor.specialtyKey or vendor.specialtyKey == "" or vendor.specialtyKey == "auto")
                    and ns.DetectSpecialtyKey
                then
                    vendor.specialtyKey = ns.DetectSpecialtyKey(vendor)
                end
                changed = LearnedVendorChanged(prev, vendor)
                VendorMapLearnedDB[i] = vendor
                replaced = true
                break
            end
        end
    end
    local isNew = not replaced
    if isNew then
        VendorMapLearnedDB[#VendorMapLearnedDB + 1] = vendor
    end

    -- Incremental index update: patch just this vendor instead of re-normalizing the
    -- whole database on every merchant visit. A full Rebuild (/vm refresh, pack load,
    -- settings changes) still reconciles everything from the pristine baseline.
    local normalized = NormalizeVendor(vendor, "learned")
    if normalized then
        local ov = npcID and GetOverrideForNpc(npcID) or nil
        if npcID and byNpcID[npcID] then
            ForEachVendorWithNpcID(npcID, function(existing)
                MergeLearnedOnto(existing, normalized, ov)
            end)
        else
            AddToIndex(normalized)
        end
        if ov and npcID then
            ForEachVendorWithNpcID(npcID, function(existing)
                ApplyOverrideToVendor(existing, ov)
            end)
            if byNpcID[npcID] then
                ApplyOverrideToVendor(byNpcID[npcID], ov)
            end
        end
    end

    ns.RefreshAll()

    return isNew, changed
end

function Database:Count()
    local n = 0
    for _, list in pairs(indexByMap) do
        n = n + #list
    end
    return n
end
