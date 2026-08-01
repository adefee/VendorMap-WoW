local ADDON_NAME, ns = ...

VendorMap = ns

local function DeepCopyDefaults(src)
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = DeepCopyDefaults(v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function MergeDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(db[k]) ~= "table" then
                db[k] = DeepCopyDefaults(v)
            else
                MergeDefaults(db[k], v)
            end
        elseif db[k] == nil then
            db[k] = v
        end
    end
end

function ns.GetDB()
    return VendorMapDB
end

function ns.Print(msg)
    print(ns.PRINT_PREFIX, msg)
end

function ns.RefreshAll()
    -- Defer world-map redraw so filter menus / dialogs don't feed a spiked canvas scale
    -- into pin sizing (which previously crushed icons until reload).
    if ns.CanvasPins then
        if ns.CanvasPins.ScheduleRefresh then
            ns.CanvasPins:ScheduleRefresh()
        else
            ns.CanvasPins:Update()
        end
    end
    if ns.MinimapPins then
        ns.MinimapPins:Refresh()
    end
    if ns.FilterButton then
        ns.FilterButton:UpdateVisibility()
    end
end

function ns.OpenSettings()
    -- Midnight blocks Settings.OpenToCategory from slash/addon compartment
    -- (protected OpenSettingsPanel). Prefer our standalone panel.
    if ns.ShowOptionsPanel then
        ns.ShowOptionsPanel()
    else
        ns.Print("Settings are not ready yet.")
    end
end


function VendorMap_OnAddonCompartmentClick()
    ns.OpenSettings()
end

local function DebugStatus()
    ns.debugPins = true
    if ns.CanvasPins then
        ns.CanvasPins:Update()
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local viewID = WorldMapFrame and WorldMapFrame:GetMapID()
    local pinCount = 0
    if viewID then
        pinCount = #ns.Database:GetPinsForMap(viewID)
    end

    local activePins = ns.CanvasPins and ns.CanvasPins:ActiveCount() or 0

    ns.Print(string.format(
        "v%s | enabled=%s | display=%s | playerMap=%s | worldMap=%s | candidates=%d | activePins=%d | pool=%d | total=%d | learned=%d",
        ns.VERSION,
        tostring(VendorMapDB.enabled),
        VendorMapDB.mapDisplay,
        tostring(mapID),
        tostring(viewID),
        pinCount,
        activePins,
        ns.CanvasPins and ns.CanvasPins:PoolSize() or 0,
        ns.Database:Count(),
        #VendorMapLearnedDB
    ))

    if viewID and pinCount > 0 then
        local sample = ns.Database:GetPinsForMap(viewID)[1]
        ns.Print(string.format(
            "Sample: %s @ view(%.2f,%.2f) origin map %d (%.2f,%.2f) types=%s",
            sample.name,
            sample.x, sample.y,
            sample.mapID,
            sample.originX or 0, sample.originY or 0,
            ns.TypeLabelList(sample.types)
        ))
    elseif viewID and pinCount == 0 then
        ns.Print("No pin candidates for this map — zoom into the city/zone map where the vendor was learned.")
    end

    C_Timer.After(5, function()
        ns.debugPins = false
    end)
end

local function OnAddonLoaded(name)
    if name ~= ADDON_NAME then
        return
    end

    VendorMapDB = VendorMapDB or {}
    MergeDefaults(VendorMapDB, ns.DEFAULTS)
    VendorMapDB.npcNames = VendorMapDB.npcNames or {}
    VendorMapLearnedDB = VendorMapLearnedDB or {}
    VendorMapOverridesDB = VendorMapOverridesDB or {}

    ns.Database:Rebuild()
    ns.InitSettings()
    if ns.InitCanvasPins then
        ns.InitCanvasPins()
    end
    if ns.InitMinimapPins then
        ns.InitMinimapPins()
    end
    if ns.InitFilterButton then
        ns.InitFilterButton()
    end

    SLASH_VENDORMAP1 = "/vendormap"
    SLASH_VENDORMAP2 = "/vm"
    SlashCmdList["VENDORMAP"] = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "toggle" then
            VendorMapDB.enabled = not VendorMapDB.enabled
            ns.Print(VendorMapDB.enabled and "Enabled." or "Disabled.")
            ns.RefreshAll()
            if ns.RefreshSettingsWidgets then
                ns.RefreshSettingsWidgets()
            end
        elseif msg == "status" then
            local loaded, total = 0, 0
            if ns.DATA_PACKS then
                for packKey in pairs(ns.DATA_PACKS) do
                    total = total + 1
                    if ns._loadedDataPacks and ns._loadedDataPacks[packKey] then
                        loaded = loaded + 1
                    end
                end
            end
            ns.Print(string.format(
                "v%s | vendors: %d | learned: %d | packs: %d/%d | map: %s | waypoints: %s",
                ns.VERSION,
                ns.Database:Count(),
                #VendorMapLearnedDB,
                loaded,
                total,
                VendorMapDB.mapDisplay,
                VendorMapDB.waypointMode
            ))
        elseif msg == "debug" then
            DebugStatus()
        elseif msg == "refresh" then
            ns.Database:Rebuild()
            ns.RefreshAll()
            ns.Print("Refreshed.")
        elseif msg == "export" then
            if ns.ExportLearnedSeeds then
                ns.ExportLearnedSeeds()
            else
                ns.Print("Export module not loaded.")
            end
        else
            ns.OpenSettings()
        end
    end

    ns.Print(string.format(
        "Loaded v%s — %d core vendors (packs on demand). |cffffff00/vendormap|r · |cffffff00/vm export|r · right-click pins to edit.",
        ns.VERSION,
        ns.Database:Count()
    ))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(arg1)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if ns.InitCanvasPins then
            ns.InitCanvasPins()
        end
        if ns.InitFilterButton then
            ns.InitFilterButton()
        end
        ns.RefreshAll()
    end
end)
