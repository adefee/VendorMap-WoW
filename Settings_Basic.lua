local _, ns = ...

local UI = ns.SettingsUI

local MAP_DISPLAY_OPTIONS = {
    { value = "world",   label = "World map only" },
    { value = "minimap", label = "Minimap only" },
    { value = "both",    label = "World map and minimap" },
}

local WAYPOINT_OPTIONS = {
    { value = "auto",       label = "Auto (Waypoint UI → TomTom → Blizzard)" },
    { value = "waypointui", label = "Waypoint UI" },
    { value = "tomtom",     label = "TomTom" },
    { value = "blizzard",   label = "Blizzard waypoint" },
}

local LEARNED_OVERRIDE_OPTIONS = {
    { value = "preferOverride", label = "Prefer my overrides" },
    { value = "preferLearned",  label = "Prefer learned (visited) data" },
}

function ns.BuildBasicSettingsPage(frame)
    local content = frame.content
    local y = -8

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("Basic Settings")

    local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(580)
    sub:SetJustifyH("LEFT")
    sub:SetText("Enable VendorMap, learning rules, map display, waypoints, and overall pin size.")

    y = -56
    UI.CreateCheckbox(content, "Enable VendorMap", 16, y, function()
        return ns.GetDB().enabled
    end, function(v)
        ns.GetDB().enabled = v
    end)

    y = y - 32
    UI.CreateCheckbox(content, "Learn vendors as you visit them", 16, y, function()
        return ns.GetDB().learnVendors
    end, function(v)
        ns.GetDB().learnVendors = v
    end)

    y = y - 36
    UI.CreateCycleButton(content, "Learned vs overrides:", LEARNED_OVERRIDE_OPTIONS, y, function()
        return ns.GetDB().learnedOverrideMode or "preferOverride"
    end, function(v)
        ns.GetDB().learnedOverrideMode = v
        UI.RebuildAndRefresh()
    end)

    local conflictHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    conflictHint:SetPoint("TOPLEFT", 16, y - 28)
    conflictHint:SetWidth(580)
    conflictHint:SetJustifyH("LEFT")
    conflictHint:SetText("Display order is always seed → learned → override. This chooses which side wins when both set the same field.")

    y = y - 56
    UI.CreateCheckbox(content, "Always prevent override notes from being changed", 16, y, function()
        return ns.GetDB().protectOverrideNotes ~= false
    end, function(v)
        ns.GetDB().protectOverrideNotes = v
        UI.RebuildAndRefresh()
    end)

    local noteHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    noteHint:SetPoint("TOPLEFT", 40, y - 26)
    noteHint:SetWidth(560)
    noteHint:SetJustifyH("LEFT")
    noteHint:SetText("When on, learning may still update name/types/faction (per setting above), but never replaces a note you set.")

    y = y - 52
    UI.CreateCheckbox(content, "Show world-map filter icon (top-right)", 16, y, function()
        return ns.GetDB().showFilterButton ~= false
    end, function(v)
        ns.GetDB().showFilterButton = v
        if ns.FilterButton then
            ns.FilterButton:UpdateVisibility()
        end
        local krowi = LibStub and LibStub("Krowi_WorldMapButtons-1.4", true)
        if krowi and krowi.SetPoints then
            krowi.SetPoints()
        end
    end)

    y = y - 32
    UI.CreateCheckbox(content, "Also show filter button on minimap", 16, y, function()
        return ns.GetDB().showMinimapFilterButton ~= false
    end, function(v)
        ns.GetDB().showMinimapFilterButton = v
        if ns.FilterButton then
            ns.FilterButton:UpdateVisibility()
        end
    end)

    y = y - 32
    UI.CreateCheckbox(content, "Show nearby vendors when pins overlap", 16, y, function()
        return ns.GetDB().showOverlapNeighbors ~= false
    end, function(v)
        ns.GetDB().showOverlapNeighbors = v
    end)

    local overlapHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    overlapHint:SetPoint("TOPLEFT", 40, y - 22)
    overlapHint:SetWidth(560)
    overlapHint:SetJustifyH("LEFT")
    overlapHint:SetText("Hovering a pin that overlaps others lists them in the tooltip; left-click then lets you pick which vendor to route to.")

    y = y - 44
    UI.CreateCycleButton(content, "Map display:", MAP_DISPLAY_OPTIONS, y, function()
        return ns.GetDB().mapDisplay
    end, function(v)
        ns.GetDB().mapDisplay = v
    end)

    y = y - 36
    UI.CreateCycleButton(content, "Waypoints:", WAYPOINT_OPTIONS, y, function()
        return ns.GetDB().waypointMode
    end, function(v)
        ns.GetDB().waypointMode = v
    end)

    y = y - 44
    UI.CreateIconSizeControl(content, "Overall Icon Size", y, 220, function()
        return ns.GetDB().iconScale or 1
    end, function(v)
        ns.GetDB().iconScale = v
    end, false)

    local overallHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    overallHint:SetPoint("TOPLEFT", 16, y - 36)
    overallHint:SetWidth(580)
    overallHint:SetJustifyH("LEFT")
    overallHint:SetText(string.format(
        "Applies to all pins. Drag the slider or type a custom %% (%d–%d). 100%% is default. Per-type sizes on Vendors & Icons multiply with this.",
        UI.SIZE_MIN_PCT, UI.SIZE_MAX_PCT
    ))

    y = y - 72
    local cmd = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    cmd:SetPoint("TOPLEFT", 16, y)
    cmd:SetWidth(580)
    cmd:SetJustifyH("LEFT")
    cmd:SetText("Commands: /vendormap · /vm toggle · /vm status · /vm refresh · /vm export")

    UI.FinishContentHeight(content, y - 24)
end
