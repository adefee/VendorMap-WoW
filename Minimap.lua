local _, ns = ...

-- Minimap pins. Coordinate space matches HereBeDragons / UnitPosition:
--   x = east-west (UnitPosition 2nd return / worldPos.y)
--   y = north-south (UnitPosition 1st return / worldPos.x)
--
-- Two-phase updates (same idea as HBD-Pins):
--   Rebuild  — which vendors exist / their world coords (slow, ~1s)
--   Reposition — move existing pins from current player pos (every frame)
local MinimapPins = {}
ns.MinimapPins = MinimapPins

local pool = {}
local active = {} -- [vendorId] = { pin, wx, wy, instanceID, info, typeKey }
local updateFrame
local rotateMinimap = false
local mapSin, mapCos = 0, 1
local vecScratch = CreateVector2D(0, 0)
local lastPlayerMapID
local rebuildElapsed = 0
-- Dedicated result buffer reused across rebuilds (see Database:GetPinsForMap).
local resultBuffer = {}

local REBUILD_INTERVAL = 1.0

local function AcquirePin()
    local pin = table.remove(pool)
    if not pin then
        pin = CreateFrame("Button", nil, Minimap)
        local def = ns.PIN_BASE_SIZE and ns.PIN_BASE_SIZE.minimap or 12
        pin:SetSize(def, def)
        pin.icon = pin:CreateTexture(nil, "OVERLAY")
        pin.icon:SetAllPoints()
        pin:SetFrameStrata(Minimap:GetFrameStrata())
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        pin:SetScript("OnEnter", function(self)
            if not self.info then
                return
            end
            if ns.Overlap then
                ns.Overlap.OnPinEnter(self, {
                    anchor = "ANCHOR_LEFT",
                    hint = "|cff00ff00Left|r waypoint · |cffffd100Right|r edit",
                    index = ns._minimapOverlapIndex,
                })
            end
        end)
        pin:SetScript("OnLeave", function()
            if ns.Overlap then
                ns.Overlap.OnPinLeave()
            else
                GameTooltip:Hide()
            end
        end)
        pin:SetScript("OnClick", function(self, button)
            if not self.info then
                return
            end
            if ns.Overlap then
                ns.Overlap.HandlePinClick(self, button, {
                    index = ns._minimapOverlapIndex,
                    printWaypoint = false,
                })
            end
        end)
    end
    return pin
end

local function ReleasePin(pin)
    pin:Hide()
    pin.info = nil
    pin.vendorId = nil
    pool[#pool + 1] = pin
end

local function ReleaseAll()
    for id, data in pairs(active) do
        active[id] = nil
        ReleasePin(data.pin)
    end
end

--- World position in UnitPosition / HBD space.
local function GetWorldXY(mapID, x, y)
    if not mapID or not x or not y then
        return nil
    end
    vecScratch:SetXY(x, y)
    local instanceID, worldPos = C_Map.GetWorldPosFromMapPos(mapID, vecScratch)
    if not worldPos then
        return nil
    end
    -- GetWorldPosFromMapPos: .x = N/S, .y = E/W
    -- UnitPosition / HBD:     x = E/W,  y = N/S
    return instanceID, worldPos.y, worldPos.x
end

local function GetPlayerWorld()
    local y, x, _, instanceID = UnitPosition("player")
    if x and y and instanceID then
        return instanceID, x, y
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        return nil
    end
    local mx, my = pos:GetXY()
    return GetWorldXY(mapID, mx, my)
end

function MinimapPins:Refresh()
    if not updateFrame then
        return
    end
    updateFrame.forceRebuild = true
end

--- Slow path: refresh the set of tracked vendors and cache world coords.
local function Rebuild()
    if not ns.ShouldShowMinimap or not ns.ShouldShowMinimap() then
        ReleaseAll()
        return
    end
    if not ns.GetDB or not ns.GetDB().enabled then
        ReleaseAll()
        return
    end

    local instanceID = select(1, GetPlayerWorld())
    if not instanceID then
        ReleaseAll()
        return
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then
        ReleaseAll()
        return
    end
    lastPlayerMapID = playerMapID

    if ns.EnsureDataForMap then
        ns.EnsureDataForMap(playerMapID)
    end

    local baseSize = ns.GetPinBaseSize(nil, true)
    local pins = ns.Database:GetPinsForMap(playerMapID, resultBuffer)
    if ns.Names then
        ns.Names:Prefetch(pins)
    end
    local keep = {}

    for _, info in ipairs(pins) do
        local vInstance, vx, vy = GetWorldXY(info.mapID, info.originX or info.x, info.originY or info.y)
        if vInstance and vInstance == instanceID and vx and vy then
            local id = info.id
            keep[id] = true
            local data = active[id]
            if not data then
                data = { pin = AcquirePin() }
                active[id] = data
            end
            data.wx = vx
            data.wy = vy
            data.instanceID = vInstance
            data.info = info
            data.typeKey = ns.GetPinDisplayType and ns.GetPinDisplayType(info) or ns.PrimaryVendorType(info.types)

            local pin = data.pin
            pin.vendorId = id
            pin.info = info
            local size = baseSize * ns.GetTypeIconScale(data.typeKey)
            pin:SetSize(size, size)
            if ns.SetVendorPinIcon then
                ns.SetVendorPinIcon(pin.icon, info)
            else
                ns.SetTypeIcon(pin.icon, data.typeKey, info.faction)
            end
            if ns.LayoutPinIcon then
                ns.LayoutPinIcon(pin.icon)
            end
        end
    end

    for id, data in pairs(active) do
        if not keep[id] then
            active[id] = nil
            ReleasePin(data.pin)
        end
    end

    -- Rebuild the overlap index (hover-time neighbor lookup uses live rim positions).
    if ns.Overlap then
        ns._minimapOverlapIndex = ns.Overlap.BuildIndexFromActive(active)
        ns.Overlap.ClearHighlights()
    end
end

--- Fast path: move pins from cached world coords (called every frame).
local function Reposition()
    if not next(active) then
        return
    end
    if not ns.ShouldShowMinimap or not ns.ShouldShowMinimap() then
        return
    end

    local instanceID, playerX, playerY = GetPlayerWorld()
    if not instanceID then
        return
    end

    local radius
    if C_Minimap and C_Minimap.GetViewRadius then
        radius = C_Minimap.GetViewRadius()
    end
    if not radius or radius <= 0 then
        radius = 180
    end

    local minimapWidth = Minimap:GetWidth() / 2
    local minimapHeight = Minimap:GetHeight() / 2

    if rotateMinimap then
        local facing = GetPlayerFacing()
        if not facing then
            return
        end
        mapCos = math.cos(facing)
        mapSin = math.sin(facing)
    end

    for _, data in pairs(active) do
        local pin = data.pin
        if data.instanceID ~= instanceID then
            pin:Hide()
        else
            local xDist = playerX - data.wx
            local yDist = playerY - data.wy

            if rotateMinimap then
                local dx, dy = xDist, yDist
                xDist = dx * mapCos - dy * mapSin
                yDist = dx * mapSin + dy * mapCos
            end

            local diffX = xDist / radius
            local diffY = yDist / radius
            local distSq = diffX * diffX + diffY * diffY
            local dist = math.sqrt(distSq)

            if dist > 1.15 then
                pin:Hide()
            else
                if dist > 0.9 then
                    -- Slide along the rim instead of popping in/out
                    local scale = 0.9 / dist
                    diffX = diffX * scale
                    diffY = diffY * scale
                end
                -- SetPoint alone (no ClearAllPoints) — avoids layout thrash/jitter
                pin:SetPoint("CENTER", Minimap, "CENTER", diffX * minimapWidth, -diffY * minimapHeight)
                pin:Show()
            end
        end
    end
end

local function Init()
    if updateFrame then
        return
    end
    updateFrame = CreateFrame("Frame")
    rebuildElapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, e)
        if not ns.ShouldShowMinimap or not ns.ShouldShowMinimap() then
            if next(active) then
                ReleaseAll()
            end
            return
        end

        rotateMinimap = GetCVar("rotateMinimap") == "1"

        local mapID = C_Map.GetBestMapForUnit("player")
        local needRebuild = self.forceRebuild
            or (mapID and mapID ~= lastPlayerMapID)
            or rebuildElapsed >= REBUILD_INTERVAL

        rebuildElapsed = rebuildElapsed + e
        if needRebuild then
            rebuildElapsed = 0
            self.forceRebuild = nil
            Rebuild()
        end

        -- Smooth tracking: reposition every frame using cached world coords
        Reposition()
    end)
    updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    updateFrame:RegisterEvent("ZONE_CHANGED")
    updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    updateFrame:RegisterEvent("CVAR_UPDATE")
    updateFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    updateFrame:SetScript("OnEvent", function(self, event, cvar)
        if event == "CVAR_UPDATE" and cvar ~= "rotateMinimap" then
            return
        end
        self.forceRebuild = true
    end)
end

function ns.ShouldShowMinimap()
    if not VendorMapDB then
        return false
    end
    local display = ns.GetDB().mapDisplay
    return display == "minimap" or display == "both"
end

function ns.ShouldShowWorldMap()
    local db = ns.GetDB()
    if not db or not db.enabled then
        return false
    end
    local display = db.mapDisplay
    return display == "world" or display == "both"
end

ns.InitMinimapPins = Init
