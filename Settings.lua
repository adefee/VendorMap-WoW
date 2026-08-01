local ADDON_NAME, ns = ...

-- Settings hub: Blizzard AddOns expandable categories + standalone tabbed window.

local pages = {} -- { key, title, standaloneFrame, settingsFrame }
local standalone
local activeStandaloneKey
local built = false

local PAGE_DEFS = {
    { key = "basic",   title = "Basic Settings",   build = function(f) ns.BuildBasicSettingsPage(f) end },
    { key = "vendors", title = "Vendors & Icons",   build = function(f) ns.BuildVendorsSettingsPage(f) end },
    { key = "data",    title = "Data Management",   build = function(f) ns.BuildDataSettingsPage(f) end },
}

local function EnsurePages()
    if built then
        return
    end
    built = true
    ns.SettingsUI.ResetWidgets()

    for _, def in ipairs(PAGE_DEFS) do
        -- Distinct frames: standalone keeps parenting under our window; Blizzard
        -- Settings may reparent the registered canvas.
        local standaloneFrame = ns.SettingsUI.CreateCanvas("VendorMapOptions_" .. def.key)
        standaloneFrame.pageTitle = def.title
        def.build(standaloneFrame)

        local settingsFrame = ns.SettingsUI.CreateCanvas("VendorMapOptions_" .. def.key .. "_Settings")
        settingsFrame.pageTitle = def.title
        def.build(settingsFrame)

        pages[#pages + 1] = {
            key = def.key,
            title = def.title,
            standaloneFrame = standaloneFrame,
            settingsFrame = settingsFrame,
        }
    end
end

local function FindPage(key)
    for _, p in ipairs(pages) do
        if p.key == key then
            return p
        end
    end
    return pages[1]
end

local function ShowStandalonePage(key)
    local page = FindPage(key)
    if not page or not standalone then
        return
    end
    activeStandaloneKey = page.key
    for _, p in ipairs(pages) do
        local frame = p.standaloneFrame
        frame:SetParent(standalone.body)
        frame:ClearAllPoints()
        frame:SetAllPoints(standalone.body)
        if p.key == page.key then
            frame:Show()
        else
            frame:Hide()
        end
    end
    if standalone.title then
        standalone.title:SetText("VendorMap — " .. page.title)
    end
    for _, tab in ipairs(standalone.tabs or {}) do
        if tab.key == page.key then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
    if ns.RefreshSettingsWidgets then
        ns.RefreshSettingsWidgets()
    end
end

local function EnsureStandalone()
    if standalone then
        return standalone
    end
    EnsurePages()

    standalone = CreateFrame("Frame", "VendorMapOptionsPanel", UIParent, "BackdropTemplate")
    standalone:SetSize(700, 580)
    standalone:SetPoint("CENTER")
    standalone:SetFrameStrata("DIALOG")
    standalone:SetFrameLevel(100)
    standalone:SetMovable(true)
    standalone:EnableMouse(true)
    standalone:SetClampedToScreen(true)
    standalone:RegisterForDrag("LeftButton")
    standalone:SetScript("OnDragStart", standalone.StartMoving)
    standalone:SetScript("OnDragStop", standalone.StopMovingOrSizing)
    standalone:Hide()

    if standalone.SetBackdrop then
        standalone:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end

    tinsert(UISpecialFrames, "VendorMapOptionsPanel")

    local close = CreateFrame("Button", nil, standalone, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    standalone.title = standalone:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    standalone.title:SetPoint("TOPLEFT", 16, -14)
    standalone.title:SetText("VendorMap")

    standalone.tabs = {}
    local tabX = 16
    for i, p in ipairs(pages) do
        local tab = CreateFrame("Button", nil, standalone, "UIPanelButtonTemplate")
        tab:SetSize(140, 22)
        tab:SetPoint("TOPLEFT", tabX, -40)
        tab:SetText(p.title)
        tab.key = p.key
        tab:SetScript("OnClick", function()
            ShowStandalonePage(p.key)
        end)
        standalone.tabs[i] = tab
        tabX = tabX + 148
    end

    standalone.body = CreateFrame("Frame", nil, standalone)
    standalone.body:SetPoint("TOPLEFT", 12, -68)
    standalone.body:SetPoint("BOTTOMRIGHT", -12, 12)

    return standalone
end

function ns.RefreshSettingsWidgets()
    if ns.SettingsUI then
        ns.SettingsUI.EnsureTypeIconScale()
        for _, w in ipairs(ns.SettingsUI.widgets) do
            if w._get and w.SetChecked then
                w:SetChecked(not not w._get())
            elseif w._refresh then
                w._refresh()
            end
        end
    end
    if ns.RefreshVendorSettingsRows then
        ns.RefreshVendorSettingsRows()
    end
    if ns.RefreshOverrideList then
        -- Only rebuild override UI if that page exists / has been built
        ns.RefreshOverrideList()
    end
end

--- Show options without calling protected Settings.OpenSettingsPanel (blocked from slash cmds).
function ns.ShowOptionsPanel()
    EnsurePages()

    -- If Blizzard Settings is already open, jump to our category.
    if SettingsPanel and SettingsPanel:IsShown() and Settings and ns.SettingsCategory and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.SettingsCategory:GetID())
        return
    end

    EnsureStandalone()
    ShowStandalonePage(activeStandaloneKey or "basic")
    standalone:SetParent(UIParent)
    standalone:ClearAllPoints()
    standalone:SetPoint("CENTER")
    standalone:Show()
    standalone:Raise()
end

function ns.InitSettings()
    EnsurePages()
    ns.RefreshSettingsWidgets()

    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end
    if ns.SettingsCategory then
        return
    end

    -- Parent category (expandable in Settings > AddOns), with three sub-pages.
    local about = ns.SettingsUI.CreateCanvas("VendorMapOptions_About")
    local aboutContent = about.content
    local aboutTitle = aboutContent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    aboutTitle:SetPoint("TOPLEFT", 16, -8)
    aboutTitle:SetText("VendorMap")
    local aboutSub = aboutContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    aboutSub:SetPoint("TOPLEFT", aboutTitle, "BOTTOMLEFT", 0, -10)
    aboutSub:SetWidth(560)
    aboutSub:SetJustifyH("LEFT")
    aboutSub:SetText(string.format(
        "Version %s\n\nUse the expandable entries under VendorMap in the AddOns list:\n• Basic Settings\n• Vendors & Icons\n• Data Management\n\nSlash: /vendormap or /vm",
        ns.VERSION or "?"
    ))
    ns.SettingsUI.FinishContentHeight(aboutContent, -120)

    local category = Settings.RegisterCanvasLayoutCategory(about, "VendorMap")
    Settings.RegisterAddOnCategory(category)
    ns.SettingsCategory = category

    for _, p in ipairs(pages) do
        local sub = Settings.RegisterCanvasLayoutSubcategory(category, p.settingsFrame, p.title)
        p.settingsCategory = sub
    end
    ns.SettingsPages = pages
end
