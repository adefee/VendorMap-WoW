local _, ns = ...

-- Reliable world-map pins via frames on the map canvas. This is the sole world-map
-- renderer (the old MapCanvas DataProvider path has been retired).
--
-- Memory notes: WoW never frees a CreateFrame'd frame, so we do NOT destroy and
-- recreate pins (that would leak on every dense continent view). Instead we keep a
-- reuse pool whose growth is bounded by the continent pin cap in Database, hide any
-- surplus pins, and clear their `.info` so they never retain vendor result rows.
local CanvasPins = {}
ns.CanvasPins = CanvasPins

local pins = {}
local activeCount = 0
-- Dedicated result buffer reused across updates (see Database:GetPinsForMap).
local resultBuffer = {}
-- Safety ceiling; the continent cap in Database:GetPinsForMap keeps us well under this.
local MAX_POOL = 400
-- Last trusted canvas scale (zoom/map changes). Reject spikes from open menus/dialogs.
local lastGoodScale
-- Cached map-type base size for the active pin set (used by the zoom-only rescale path).
local activeBaseSize = 18

-- Extra screen-space shrink once zoomed past 1×. 0 = constant on-screen size;
-- 0.12 ≈ 11% smaller at 2× zoom so the point reads a bit more precisely.
local ZOOM_SHRINK = 0.12

local function HideFrom(startIndex)
    for i = startIndex, #pins do
        local pin = pins[i]
        if pin then
            -- Drop the result-row reference so buffer reuse in Database can recycle it.
            pin.info = nil
            pin:Hide()
        end
    end
end

local function HideAll()
    HideFrom(1)
    activeCount = 0
end

function CanvasPins:ActiveCount()
    return activeCount
end

function CanvasPins:PoolSize()
    return #pins
end

local function GetCanvas()
    if not WorldMapFrame then
        return nil
    end
    local canvas = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    if canvas and canvas.GetWidth and canvas:GetWidth() > 0 then
        return canvas
    end
    return WorldMapFrame:GetCanvas()
end

local function Acquire(i)
    local pin = pins[i]
    if pin then
        return pin
    end
    local parent = GetCanvas() or UIParent
    pin = CreateFrame("Button", nil, parent)
    pin:SetSize(ns.PIN_BASE_SIZE and ns.PIN_BASE_SIZE.world or 18, ns.PIN_BASE_SIZE and ns.PIN_BASE_SIZE.world or 18)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin.icon = pin:CreateTexture(nil, "OVERLAY")
    pin.icon:SetAllPoints()
    local hl = pin:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

    pin:SetScript("OnEnter", function(self)
        if not self.info then
            return
        end
        if ns.Overlap then
            ns.Overlap.OnPinEnter(self, {
                anchor = "ANCHOR_RIGHT",
                showSource = true,
                hint = "|cff00ff00Left-click|r waypoint · |cffffd100Right-click|r edit",
                index = ns._canvasOverlapIndex,
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
        -- Waypoints uses the vendor's own map + origin coords; it resolves parents
        -- (city floor → zone → continent) for Blizzard's CanSetUserWaypointOnMap rules.
        if ns.Overlap then
            ns.Overlap.HandlePinClick(self, button, {
                index = ns._canvasOverlapIndex,
                printWaypoint = true,
            })
        end
    end)

    pins[i] = pin
    return pin
end

--- Read ScrollContainer canvas scale, optionally rejecting dialog-induced spikes.
local function ReadCanvasScale(trustScale)
    local scale = 1
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    if sc and sc.GetCanvasScale then
        local ok, canvasScale = pcall(sc.GetCanvasScale, sc)
        if ok and type(canvasScale) == "number" and canvasScale > 0 then
            scale = canvasScale
        end
    else
        local canvas = GetCanvas()
        if canvas and canvas.GetScale then
            local s = canvas:GetScale()
            if type(s) == "number" and s > 0 then
                scale = s
            end
        end
    end
    -- Wide band: maps zoom well past 2.5×; clamping there made deep-zoom pins bloat.
    if scale < 0.25 then
        scale = 0.25
    elseif scale > 8 then
        scale = 8
    end

    if trustScale or not lastGoodScale then
        lastGoodScale = scale
        return scale
    end
    local lo = lastGoodScale / 1.25
    local hi = lastGoodScale * 1.25
    if scale < lo or scale > hi then
        return lastGoodScale
    end
    lastGoodScale = scale
    return scale
end

--- Canvas-local pixel size: undo parenting scale, then shrink a bit as zoom rises.
local function ComputePinSize(base, typeKey, canvasScale)
    local scale = canvasScale > 0 and canvasScale or 1
    local shrink = 1 + ZOOM_SHRINK * math.max(0, scale - 1)
    return (base * ns.GetTypeIconScale(typeKey)) / (scale * shrink)
end

local function DisplayKeyForInfo(info)
    return ns.GetPinDisplayType and ns.GetPinDisplayType(info) or ns.PrimaryVendorType(info.types)
end

--- Cheap zoom path: resize existing pins without rebuilding the vendor list.
function CanvasPins:RescaleActive()
    if activeCount <= 0 then
        return
    end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end
    local scale = ReadCanvasScale(true)
    local base = activeBaseSize
    for i = 1, activeCount do
        local pin = pins[i]
        local info = pin and pin.info
        if info then
            local key = pin._displayKey or DisplayKeyForInfo(info)
            local size = ComputePinSize(base, key, scale)
            pin:SetSize(size, size)
            -- Non-square atlases (e.g. transmog poi-transmogrifier) use absolute
            -- SetSize in LayoutPinIcon; must re-run after the pin frame resizes.
            if pin.icon and ns.LayoutPinIcon then
                ns.LayoutPinIcon(pin.icon)
            end
        end
    end
end

--- opts.trustScale: accept the current GetCanvasScale reading (zoom / map change).
-- Without it, sudden spikes (filter menu, dialogs) keep lastGoodScale instead.
function CanvasPins:Update(opts)
    opts = opts or {}
    if not ns.ShouldShowWorldMap or not ns.ShouldShowWorldMap() then
        HideAll()
        return
    end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        HideAll()
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then
        HideAll()
        return
    end

    local canvas = GetCanvas()
    if not canvas or not canvas:GetWidth() or canvas:GetWidth() == 0 then
        -- Canvas not sized yet (just shown); one deferred retry, no busy loop.
        if not ns._canvasRetryScheduled then
            ns._canvasRetryScheduled = true
            C_Timer.After(0.15, function()
                ns._canvasRetryScheduled = false
                if WorldMapFrame and WorldMapFrame:IsShown() then
                    CanvasPins:Update({ trustScale = true })
                end
            end)
        end
        return
    end

    -- Prefer ScrollContainer canvas scale — Child:GetScale() can spike while other
    -- dialogs (vendor edit) are open, which made pins shrink until the next reload.
    local scale = ReadCanvasScale(opts.trustScale)

    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if ns.EnsureDataForMap then
        ns.EnsureDataForMap(mapID)
    end
    local list = ns.Database:GetPinsForMap(mapID, resultBuffer)
    if ns.Names then
        ns.Names:Prefetch(list)
    end
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapType = mapInfo and mapInfo.mapType or 3
    local base = ns.GetPinBaseSize(mapType, false)
    activeBaseSize = base

    local count = 0
    for i, info in ipairs(list) do
        if i > MAX_POOL then
            break
        end
        local pin = Acquire(i)
        pin:SetParent(canvas)
        pin:SetFrameStrata("DIALOG")
        pin:SetFrameLevel(10000)
        pin.info = info

        local key = DisplayKeyForInfo(info)
        pin._displayKey = key
        local size = ComputePinSize(base, key, scale)
        pin:SetSize(size, size)

        if ns.SetVendorPinIcon then
            ns.SetVendorPinIcon(pin.icon, info)
        else
            ns.SetTypeIcon(pin.icon, key, info.faction)
        end
        if ns.LayoutPinIcon then
            ns.LayoutPinIcon(pin.icon)
        end

        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", info.x * width, -info.y * height)
        pin:Show()
        count = i
    end

    -- Hide + clear any surplus pins left from a previous, denser view.
    HideFrom(count + 1)
    activeCount = count

    -- Rebuild the overlap index (hover-time neighbor lookup uses live positions).
    if ns.Overlap then
        ns._canvasOverlapIndex = ns.Overlap.BuildIndex(pins, count)
        ns.Overlap.ClearHighlights()
    end

    if ns.debugPins then
        ns.Print(string.format("CanvasPins: drew %d icons on map %d (pool %d)", count, mapID, #pins))
    end

    -- Names often resolve a tick later; a few follow-up redraws pick up real titles.
    ns._nameRefreshTries = ns._nameRefreshTries or 0
    if ns.Names and not ns._nameRefreshScheduled and ns._nameRefreshTries < 8 then
        local needRetry = false
        for _, info in ipairs(list) do
            if info.npcID and type(info.name) == "string" and info.name:match("^Vendor %d+$") then
                needRetry = true
                break
            end
        end
        if needRetry then
            ns._nameRefreshScheduled = true
            ns._nameRefreshTries = ns._nameRefreshTries + 1
            C_Timer.After(0.75, function()
                ns._nameRefreshScheduled = false
                if WorldMapFrame and WorldMapFrame:IsShown() then
                    CanvasPins:Update()
                end
            end)
        else
            ns._nameRefreshTries = 0
        end
    end
end

local function ScheduleUpdate(trustScale)
    ns._nameRefreshTries = 0
    local trust = trustScale ~= false
    C_Timer.After(0, function()
        CanvasPins:Update({ trustScale = trust })
    end)
end

-- Filter/settings refresh: defer and do not trust a possibly spiked canvas scale.
function CanvasPins:ScheduleRefresh()
    if ns._canvasPinsRefreshScheduled then
        return
    end
    ns._canvasPinsRefreshScheduled = true
    C_Timer.After(0, function()
        ns._canvasPinsRefreshScheduled = false
        CanvasPins:Update({ trustScale = false })
    end)
end

local function HookWorldMap()
    if not WorldMapFrame or ns._canvasPinsHooked then
        return
    end
    ns._canvasPinsHooked = true
    WorldMapFrame:HookScript("OnShow", function()
        ScheduleUpdate(true)
    end)
    -- Fires throughout a zoom animation — resize only (no DB rebuild), same as
    -- Blizzard MapCanvasPinMixin:OnCanvasScaleChanged → ApplyCurrentScale.
    if WorldMapFrame.OnCanvasScaleChanged then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
            CanvasPins:RescaleActive()
        end)
    elseif WorldMapFrame.ScrollContainer then
        hooksecurefunc(WorldMapFrame.ScrollContainer, "SetZoomTarget", function()
            C_Timer.After(0, function()
                CanvasPins:RescaleActive()
            end)
        end)
    end
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            ScheduleUpdate(true)
        end)
    end
    if WorldMapFrame.RegisterCallback then
        pcall(function()
            WorldMapFrame:RegisterCallback("OnMapIDChanged", function()
                ScheduleUpdate(true)
            end)
        end)
    end
end

function ns.InitCanvasPins()
    if ns._canvasPinsInit then
        HookWorldMap()
        return
    end
    ns._canvasPinsInit = true
    HookWorldMap()

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "Blizzard_WorldMap" then
            return
        end
        HookWorldMap()
        ScheduleUpdate()
    end)
end
