local _, ns = ...

local Waypoints = {}
ns.Waypoints = Waypoints

local vecScratch = CreateVector2D(0, 0)

local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function EnsureAddonLoaded(name)
    if IsAddonLoaded(name) then
        return true
    end
    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loader then
        pcall(loader, name)
    end
    return IsAddonLoaded(name)
end

local function TomTomAvailable()
    EnsureAddonLoaded("TomTom")
    return TomTom and TomTom.AddWaypoint and IsAddonLoaded("TomTom")
end

local function WaypointUIAvailable()
    EnsureAddonLoaded("WaypointUI")
    return WaypointUIAPI
        and WaypointUIAPI.Navigation
        and type(WaypointUIAPI.Navigation.NewUserNavigation) == "function"
end

--- Accept 0–1 or 0–100 inputs; clamp to the unit square.
local function NormalizeXY(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    if x > 1 or y > 1 then
        x, y = x / 100, y / 100
    end
    if x < 0 or x > 1 or y < 0 or y > 1 then
        x = math.min(1, math.max(0, x))
        y = math.min(1, math.max(0, y))
    end
    return x, y
end

local function CanSetOnMap(mapID)
    if not mapID then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap then
        return C_Map.CanSetUserWaypointOnMap(mapID)
    end
    return true
end

--- Translate a point from childMap → parentMap via world coordinates.
local function TranslateToMap(fromMapID, x, y, toMapID)
    if fromMapID == toMapID then
        return x, y
    end
    vecScratch:SetXY(x, y)
    local continentID, worldPos = C_Map.GetWorldPosFromMapPos(fromMapID, vecScratch)
    if not worldPos then
        return nil
    end
    local _, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, toMapID)
    if not mapPos then
        return nil
    end
    return NormalizeXY(mapPos.x, mapPos.y)
end

--- Build candidate (mapID, x, y) pairs: original map, then parents with translated coords.
local function CollectWaypointCandidates(mapID, x, y)
    local candidates = {}
    local seen = {}
    local nx, ny = NormalizeXY(x, y)
    if not nx then
        return candidates
    end

    local function add(id, cx, cy)
        if not id or seen[id] or not cx then
            return
        end
        seen[id] = true
        candidates[#candidates + 1] = { mapID = id, x = cx, y = cy }
    end

    add(mapID, nx, ny)

    local currentID, cx, cy = mapID, nx, ny
    for _ = 1, 10 do
        local info = C_Map.GetMapInfo(currentID)
        local parentID = info and info.parentMapID
        if not parentID or parentID == 0 then
            break
        end
        local px, py = TranslateToMap(currentID, cx, cy, parentID)
        if not px then
            -- Do not reuse child % on a parent map (wildly wrong for Dalaran → Crystalsong).
            break
        end
        add(parentID, px, py)
        currentID, cx, cy = parentID, px, py
    end
    return candidates
end

local function CreateMapPoint(mapID, x, y)
    if UiMapPoint and UiMapPoint.CreateFromVector2D then
        vecScratch:SetXY(x, y)
        local ok, point = pcall(UiMapPoint.CreateFromVector2D, mapID, vecScratch)
        if ok and point then
            return point
        end
    end
    if UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local ok, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
        if ok and point then
            return point
        end
    end
    return nil
end

local function ApplyBlizzardPoint(mapID, x, y)
    local point = CreateMapPoint(mapID, x, y)
    if not point then
        return false
    end

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
    end
    if C_Map.ClearUserWaypoint then
        pcall(C_Map.ClearUserWaypoint)
    end

    local ok = pcall(C_Map.SetUserWaypoint, point)
    if not ok then
        return false
    end

    -- Do not require HasUserWaypoint() immediately — it can lag a frame and caused
    -- false failures even when the native pin was set successfully.
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true
end

local function SetBlizzardWaypoint(mapID, x, y)
    if not C_Map or not C_Map.SetUserWaypoint then
        return false
    end

    local nx, ny = NormalizeXY(x, y)
    if not nx then
        return false
    end

    -- Prefer the vendor's own map first (city pins like Dalaran). Parent world-pos
    -- translation is often hundreds of meters off for floating city maps.
    if ApplyBlizzardPoint(mapID, nx, ny) then
        return true
    end

    local candidates = CollectWaypointCandidates(mapID, x, y)
    for _, c in ipairs(candidates) do
        if c.mapID ~= mapID and CanSetOnMap(c.mapID) and ApplyBlizzardPoint(c.mapID, c.x, c.y) then
            return true
        end
    end
    for _, c in ipairs(candidates) do
        if c.mapID ~= mapID and ApplyBlizzardPoint(c.mapID, c.x, c.y) then
            return true
        end
    end

    return false
end

local function SetTomTomWaypoint(mapID, x, y, title)
    if not TomTomAvailable() then
        return false
    end
    local nx, ny = NormalizeXY(x, y)
    if not nx then
        return false
    end
    local ok = pcall(function()
        TomTom:AddWaypoint(mapID, nx, ny, {
            title = title or "Vendor",
            persistent = false,
            minimap = true,
            world = true,
            from = "VendorMap",
        })
    end)
    return ok
end

--- WaypointUI's CreateResolvedMapPoint requires CanSetUserWaypointOnMap on the
--- mapID we pass (it only auto-parents when x/y are outside 0–100). So we must
--- feed it a candidate map that already allows user pins.
local function SetWaypointUIWaypoint(mapID, x, y, title)
    if not WaypointUIAvailable() then
        return false
    end

    local nav = WaypointUIAPI.Navigation
    local nx, ny = NormalizeXY(x, y)
    if not nx then
        return false
    end

    local function tryCandidate(c)
        local ok, result = pcall(function()
            return nav.NewUserNavigation({
                name = title or "Vendor",
                mapID = c.mapID,
                x = c.x * 100,
                y = c.y * 100,
                flags = "VendorMap",
                requestRecolor = true,
                syncNativeWaypoint = true,
            })
        end)
        if not ok then
            return false
        end
        if result ~= nil then
            return true
        end
        if nav.GetUserNavigation then
            local tracked = nav.GetUserNavigation()
            if tracked and tracked.mapID then
                return true
            end
        end
        if nav.IsUserNavigationTracked and nav.IsUserNavigationTracked() then
            return true
        end
        return false
    end

    -- Origin map first (same rationale as Blizzard path).
    if tryCandidate({ mapID = mapID, x = nx, y = ny }) then
        return true
    end

    local candidates = CollectWaypointCandidates(mapID, x, y)
    for _, c in ipairs(candidates) do
        if c.mapID ~= mapID and CanSetOnMap(c.mapID) and tryCandidate(c) then
            return true
        end
    end
    for _, c in ipairs(candidates) do
        if c.mapID ~= mapID and tryCandidate(c) then
            return true
        end
    end

    return false
end

--- Set a waypoint using the user's preferred mode.
-- @return usedMode string|nil, ok boolean
function Waypoints:Set(mapID, x, y, title)
    if not mapID or type(x) ~= "number" or type(y) ~= "number" then
        return nil, false
    end

    local mode = ns.GetDB().waypointMode or "auto"

    local function tryAutoChain(preferWaypointUI)
        if preferWaypointUI and SetWaypointUIWaypoint(mapID, x, y, title) then
            return "Waypoint UI", true
        end
        if SetTomTomWaypoint(mapID, x, y, title) then
            return "TomTom", true
        end
        if SetBlizzardWaypoint(mapID, x, y) then
            return "Blizzard", true
        end
        return nil, false
    end

    if mode == "waypointui" then
        if SetWaypointUIWaypoint(mapID, x, y, title) then
            return "Waypoint UI", true
        end
        -- Fall back so a WaypointUI map rejection still gets the player an arrow.
        if SetTomTomWaypoint(mapID, x, y, title) then
            return "TomTom", true
        end
        if SetBlizzardWaypoint(mapID, x, y) then
            return "Blizzard", true
        end
        ns.Print("Could not set a Waypoint UI / fallback waypoint here.")
        return nil, false
    end

    if mode == "tomtom" then
        if SetTomTomWaypoint(mapID, x, y, title) then
            return "TomTom", true
        end
        ns.Print("TomTom is not available. Falling back to Blizzard waypoint.")
        if SetBlizzardWaypoint(mapID, x, y) then
            return "Blizzard", true
        end
        ns.Print("Could not set a waypoint on this map.")
        return nil, false
    end

    if mode == "blizzard" then
        if SetBlizzardWaypoint(mapID, x, y) then
            return "Blizzard", true
        end
        ns.Print("Could not set a Blizzard waypoint on this map (try zooming to the zone, or use Auto/TomTom).")
        return nil, false
    end

    -- auto: Waypoint UI → TomTom → Blizzard
    local used, ok = tryAutoChain(true)
    if ok then
        return used, true
    end
    ns.Print("Could not set a waypoint here (map may not allow navigation).")
    return nil, false
end
