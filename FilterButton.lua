local _, ns = ...

-- World-map circular button (top-right icon stack) + optional minimap chip.
local FilterButton = {}
ns.FilterButton = FilterButton

local miniBtn

local function NestedForParent(parentKey)
    if ns.NestedTypesForParent then
        return ns.NestedTypesForParent(parentKey)
    end
    return {}
end

local function SetAllTypes(enabled)
    local db = ns.GetDB()
    for _, t in ipairs(ns.VENDOR_TYPES) do
        db.types[t.key] = enabled
    end
    for _, sub in ipairs(ns.GENERAL_SUBTYPES or {}) do
        db.types[sub.key] = enabled
    end
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES or {}) do
        db.types[sub.key] = enabled
    end
    ns.RefreshAll()
    if ns.RefreshSettingsWidgets then
        ns.RefreshSettingsWidgets()
    end
end

local function OpenMenuWithMenuUtil(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return false
    end
    -- Explicit colors so minimap fallback stays readable on any theme
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("|cffffffffVendorMap Filters|r")
        root:CreateDivider()
        root:CreateButton("|cffffffffShow all|r", function() SetAllTypes(true) end)
        root:CreateButton("|cffffffffHide all|r", function() SetAllTypes(false) end)
        root:CreateDivider()
        for _, t in ipairs(ns.VENDOR_TYPES) do
            local key = t.key
            root:CreateCheckbox("|cffffffff" .. t.label .. "|r", function()
                return ns.TypeFilterIsShown(key)
            end, function()
                ns.ToggleTypeFilter(key)
            end)
            for _, nested in ipairs(NestedForParent(key)) do
                local subKey = nested.key
                root:CreateCheckbox("|cffffffff    " .. nested.label .. "|r", function()
                    return ns.TypeFilterIsShown(subKey)
                end, function()
                    ns.ToggleTypeFilter(subKey)
                end)
            end
        end
        root:CreateDivider()
        root:CreateButton("|cffffffffOpen settings…|r", function()
            ns.OpenSettings()
        end)
    end)
    return true
end

local function StyleMiniVButton(btn, size)
    btn:SetSize(size, size)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.08, 0.14, 0.22, 0.95)

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.45, 0.72, 0.95, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("V")
    label:SetTextColor(0.9, 0.97, 1)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("VendorMap", 1, 1, 1)
        GameTooltip:AddLine("Left-click: filter vendor categories", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: open settings", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ns.OpenSettings()
            return
        end
        OpenMenuWithMenuUtil(self)
    end)
end

local function CreateMinimapButton()
    if miniBtn then
        return miniBtn
    end
    local parent = Minimap or MinimapCluster
    if not parent then
        return nil
    end
    miniBtn = CreateFrame("Button", "VendorMapMinimapFilterButton", parent)
    miniBtn:SetFrameStrata("MEDIUM")
    miniBtn:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 10)
    miniBtn:SetPoint("TOPRIGHT", Minimap or parent, "TOPRIGHT", -4, -4)
    StyleMiniVButton(miniBtn, 22)
    return miniBtn
end

local function HookWorldMapShow()
    if not WorldMapFrame or ns._filterWorldMapHooked then
        return
    end
    ns._filterWorldMapHooked = true
    WorldMapFrame:HookScript("OnShow", function()
        FilterButton:Create()
        FilterButton:UpdateVisibility()
    end)
end

function FilterButton:UpdateVisibility()
    local db = ns.GetDB()
    local show = db and db.showFilterButton ~= false and db.enabled ~= false
    local worldBtn = ns.GetWorldMapFilterButton and ns.GetWorldMapFilterButton()

    if worldBtn then
        if show then worldBtn:Show() else worldBtn:Hide() end
    end
    if miniBtn then
        if show and db.showMinimapFilterButton ~= false then
            miniBtn:Show()
        else
            miniBtn:Hide()
        end
    end
end

function FilterButton:Create()
    if ns.CreateWorldMapFilterButton then
        ns.CreateWorldMapFilterButton()
    end
    CreateMinimapButton()
    HookWorldMapShow()
    self:UpdateVisibility()
end

function ns.InitFilterButton()
    local function try()
        FilterButton:Create()
        FilterButton:UpdateVisibility()
    end

    try()

    if not (ns.GetWorldMapFilterButton and ns.GetWorldMapFilterButton()) then
        if EventUtil and EventUtil.ContinueOnAddOnLoaded then
            EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function()
                try()
            end)
        end
        if not ns._filterLoadWatcher then
            ns._filterLoadWatcher = CreateFrame("Frame")
            local f = ns._filterLoadWatcher
            f:RegisterEvent("ADDON_LOADED")
            f:RegisterEvent("PLAYER_ENTERING_WORLD")
            f:SetScript("OnEvent", function(self, event, name)
                if event == "ADDON_LOADED" and name ~= "Blizzard_WorldMap" then
                    return
                end
                try()
                if ns.GetWorldMapFilterButton and ns.GetWorldMapFilterButton() then
                    self:UnregisterAllEvents()
                end
            end)
        end
    end
end
