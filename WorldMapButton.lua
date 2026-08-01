local _, ns = ...

-- Circular world-map filter button (Krowi stack / ATT·RareScanner style).
-- Uses DropdownButton + WowStyle2IconButtonMixin so the menu matches Blizzard chrome.

VendorMapWorldMapButtonMixin = CreateFromMixins(WowStyle2IconButtonMixin)

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

function VendorMapWorldMapButtonMixin:OnLoad()
    self:SetFrameStrata("HIGH")
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if self.Letter then
        self.Letter:SetText("V")
        self.Letter:SetTextColor(0.95, 0.98, 1)
    end
end

function VendorMapWorldMapButtonMixin:OnShow()
    self:SetupMenu()
end

function VendorMapWorldMapButtonMixin:OnMenuResponse(_, description)
    self:NotifyUpdate(description)
end

function VendorMapWorldMapButtonMixin:NotifyUpdate()
    ns.RefreshAll()
end

function VendorMapWorldMapButtonMixin:OnMouseDown()
    if self.Icon then
        self.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", 7, -6)
    end
    if self.Letter then
        self.Letter:SetPoint("CENTER", self, "CENTER", 2.5, -2)
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function VendorMapWorldMapButtonMixin:OnMouseUp(button)
    if self.Icon then
        self.Icon:SetPoint("TOPLEFT", 7.2, -6)
    end
    if self.Letter then
        self.Letter:SetPoint("CENTER", self, "CENTER", 1.5, -1)
    end
    if button == "RightButton" then
        ns.OpenSettings()
    end
end

function VendorMapWorldMapButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, "VendorMap")
    GameTooltip:AddLine("Left-click: filter vendor categories", 1, 1, 1, true)
    GameTooltip:AddLine("Right-click: open settings", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

function VendorMapWorldMapButtonMixin:OnLeave()
    GameTooltip:Hide()
end

function VendorMapWorldMapButtonMixin:Refresh()
    self:SetupMenu()
end

function VendorMapWorldMapButtonMixin:SetupMenu()
    DropdownButtonMixin.SetupMenu(self, function(_, rootDescription)
        rootDescription:SetTag("MENU_WORLD_MAP_VENDORMAP")

        rootDescription:CreateTitle("VendorMap")
        rootDescription:CreateButton("Show all", function()
            SetAllTypes(true)
        end)
        rootDescription:CreateButton("Hide all", function()
            SetAllTypes(false)
        end)
        rootDescription:CreateDivider()

        for _, t in ipairs(ns.VENDOR_TYPES) do
            local key = t.key
            rootDescription:CreateCheckbox(t.label, function()
                return ns.TypeFilterIsShown(key)
            end, function()
                ns.ToggleTypeFilter(key)
            end)
            for _, nested in ipairs(NestedForParent(key)) do
                local subKey = nested.key
                rootDescription:CreateCheckbox("    " .. nested.label, function()
                    return ns.TypeFilterIsShown(subKey)
                end, function()
                    ns.ToggleTypeFilter(subKey)
                end)
            end
        end

        rootDescription:CreateDivider()
        rootDescription:CreateButton("Open settings…", function()
            ns.OpenSettings()
        end)
    end)
end

local worldBtn

local function CreateViaKrowi()
    local lib = LibStub and LibStub("Krowi_WorldMapButtons-1.4", true)
    if not lib then
        return nil
    end
    local btn = lib:Add("VendorMapWorldMapButtonTemplate", "DropdownButton")
    btn.Refresh = btn.Refresh or function(self) VendorMapWorldMapButtonMixin.Refresh(self) end
    return btn
end

local function CreateFallback()
    if not WorldMapFrame then
        return nil
    end
    local parent = WorldMapFrame
    local btn = CreateFrame("DropdownButton", "VendorMapWorldFilterButton", parent, "VendorMapWorldMapButtonTemplate")
    local container = WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer() or WorldMapFrame
    -- Rough ATT-style offset when Krowi isn't managing the stack
    btn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -66)
    btn.relativeFrame = container
    btn.Refresh = function(self)
        VendorMapWorldMapButtonMixin.Refresh(self)
    end
    return btn
end

function ns.CreateWorldMapFilterButton()
    if worldBtn then
        return worldBtn
    end
    if not WorldMapFrame then
        return nil
    end
    worldBtn = CreateViaKrowi() or CreateFallback()
    if worldBtn and worldBtn.OnLoad then
        worldBtn:OnLoad()
    end
    return worldBtn
end

function ns.GetWorldMapFilterButton()
    return worldBtn
end
