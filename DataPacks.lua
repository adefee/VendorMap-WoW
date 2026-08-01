local _, ns = ...

-- LoadOnDemand continent data packs (sibling addons VendorMap_Data_*).
-- Core ships Capitals/Hubs/Decor always; ATT-scale dumps live in these packs.

ns.DATA_PACKS = {
    EasternKingdoms = {
        addon = "VendorMap_Data_EasternKingdoms",
        label = "Eastern Kingdoms",
        continents = { 13, 2537 }, -- Quel'Thalas / Midnight folds into EK
    },
    Kalimdor = {
        addon = "VendorMap_Data_Kalimdor",
        label = "Kalimdor",
        continents = { 12 },
    },
    Outland = {
        addon = "VendorMap_Data_Outland",
        label = "Outland",
        continents = { 101 },
    },
    Northrend = {
        addon = "VendorMap_Data_Northrend",
        label = "Northrend",
        continents = { 113 },
    },
    Pandaria = {
        addon = "VendorMap_Data_Pandaria",
        label = "Pandaria",
        continents = { 424 },
    },
    Draenor = {
        addon = "VendorMap_Data_Draenor",
        label = "Draenor",
        continents = { 572 },
    },
    BrokenIsles = {
        addon = "VendorMap_Data_BrokenIsles",
        label = "Broken Isles",
        continents = { 619, 905 }, -- Argus
    },
    Zandalar = {
        addon = "VendorMap_Data_Zandalar",
        label = "Zandalar",
        continents = { 875 },
    },
    KulTiras = {
        addon = "VendorMap_Data_KulTiras",
        label = "Kul Tiras",
        continents = { 876 },
    },
    Maelstrom = {
        addon = "VendorMap_Data_Maelstrom",
        label = "The Maelstrom",
        continents = { 948 },
    },
    Shadowlands = {
        addon = "VendorMap_Data_Shadowlands",
        label = "Shadowlands",
        continents = { 1550 },
    },
    DragonIsles = {
        addon = "VendorMap_Data_DragonIsles",
        label = "Dragon Isles",
        continents = { 1978 },
    },
    KhazAlgar = {
        addon = "VendorMap_Data_KhazAlgar",
        label = "Khaz Algar",
        continents = { 2274 },
    },
    Other = {
        addon = "VendorMap_Data_Other",
        label = "Other",
        continents = {}, -- Nazjatar, Darkmoon, orphans, etc.
    },
}

ns.CONTINENT_TO_PACK = {}
for packKey, meta in pairs(ns.DATA_PACKS) do
    for _, continentID in ipairs(meta.continents) do
        ns.CONTINENT_TO_PACK[continentID] = packKey
    end
end

ns._loadedDataPacks = ns._loadedDataPacks or {}

local function IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    if _G.IsAddOnLoaded then
        return _G.IsAddOnLoaded(name)
    end
    return false
end

local function LoadAddOnByName(name)
    if C_AddOns and C_AddOns.LoadAddOn then
        return C_AddOns.LoadAddOn(name)
    end
    if LoadAddOn then
        return LoadAddOn(name)
    end
    return false, "NO_LOADER"
end

local function GetAddOnInfoByName(name)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        return C_AddOns.GetAddOnInfo(name)
    end
    if GetAddOnInfo then
        return GetAddOnInfo(name)
    end
    return nil
end

--- Walk parents to the primary continent (skip nested continents like Argus → Broken Isles).
function ns.GetPrimaryContinentMapID(mapID)
    if not mapID then
        return nil
    end
    local id = mapID
    local seen = {}
    local continentType = (Enum.UIMapType and Enum.UIMapType.Continent) or 2
    local continents = {}
    while id and id > 0 and not seen[id] do
        seen[id] = true
        local info = C_Map.GetMapInfo(id)
        if not info then
            break
        end
        if info.mapType == continentType then
            continents[#continents + 1] = id
        end
        id = info.parentMapID
    end
    if #continents == 0 then
        return nil
    end
    -- Prefer outermost continent whose parent is not itself a continent.
    for _, contID in ipairs(continents) do
        local info = C_Map.GetMapInfo(contID)
        local parentID = info and info.parentMapID
        local parentInfo = parentID and C_Map.GetMapInfo(parentID)
        if not parentInfo or parentInfo.mapType ~= continentType then
            return contID
        end
    end
    return continents[#continents]
end

function ns.GetPackKeyForMap(mapID)
    local continentID = ns.GetPrimaryContinentMapID(mapID)
    if continentID and ns.CONTINENT_TO_PACK[continentID] then
        return ns.CONTINENT_TO_PACK[continentID]
    end
    return "Other"
end

function ns.GetPackKeysForMap(mapID)
    if not mapID then
        return {}
    end
    local info = C_Map.GetMapInfo(mapID)
    local mapType = info and info.mapType
    local worldType = (Enum.UIMapType and Enum.UIMapType.World) or 1
    -- Cosmic / Azeroth: skip bulk LoD loads. Zoom to a continent/zone to pull that pack.
    -- (Core Capitals/Hubs/Decor still show if they translate onto the world map.)
    if mapType and mapType <= worldType then
        return {}
    end
    return { ns.GetPackKeyForMap(mapID) }
end

--- Load one data pack. Returns true if newly loaded (seeds were registered).
function ns.LoadDataPack(packKey)
    if not packKey or ns._loadedDataPacks[packKey] then
        return false
    end
    local meta = ns.DATA_PACKS[packKey]
    if not meta then
        ns._loadedDataPacks[packKey] = true
        return false
    end
    local addon = meta.addon
    if IsAddOnLoaded(addon) then
        ns._loadedDataPacks[packKey] = true
        return false
    end

    local name = GetAddOnInfoByName(addon)
    if not name or name == "" then
        -- Pack not installed; don't spam retries.
        ns._loadedDataPacks[packKey] = true
        if ns.debugPins then
            ns.Print("Data pack missing: " .. addon)
        end
        return false
    end

    local ok, reason = LoadAddOnByName(addon)
    -- NotifySeedPackLoaded marks the pack; if load failed, mark anyway to avoid retries.
    if not ns._loadedDataPacks[packKey] then
        ns._loadedDataPacks[packKey] = true
    end
    if not ok then
        if ns.debugPins then
            ns.Print(string.format("Failed to load %s (%s)", addon, tostring(reason)))
        end
        return false
    end
    return true
end

--- Ensure pack(s) for a viewed/player map are loaded. Returns true if any new pack loaded.
function ns.EnsureDataForMap(mapID)
    local loadedNew = false
    ns._deferPackRebuild = true
    for _, packKey in ipairs(ns.GetPackKeysForMap(mapID)) do
        if ns.LoadDataPack(packKey) then
            loadedNew = true
        end
    end
    ns._deferPackRebuild = false
    if loadedNew and ns.Database and ns.Database.Rebuild then
        ns.Database:Rebuild()
    end
    return loadedNew
end

--- Called at the end of each data pack's seed file (after all AddSeed calls).
function ns.NotifySeedPackLoaded(packKey)
    ns._loadedDataPacks[packKey] = true
    if ns._deferPackRebuild then
        return
    end
    if ns.Database and ns.Database.Rebuild then
        ns.Database:Rebuild()
    end
end
