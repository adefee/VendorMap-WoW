local _, ns = ...

local UI = ns.SettingsUI

-- One typeRows table per vendors-settings canvas (standalone + Blizzard Settings).
local vendorPageStates = {}

local function NestedForParent(parentKey)
    if ns.NestedTypesForParent then
        return ns.NestedTypesForParent(parentKey)
    end
    return {}
end

local function SyncPreview(row, typeKey)
    if not row.preview then
        return
    end
    local faction = (typeKey == "faction") and "Neutral" or nil
    ns.SetTypeIcon(row.preview, typeKey, faction)
end

local function UpdateCustomVisibility(row, typeKey)
    local isCustom = ns.GetTypeIconPreset(typeKey) == "custom"
    if row.customBox then
        if isCustom then
            row.customBox:Show()
            row.customLabel:Show()
            row.customCheck:SetChecked(true)
            row.customBox:SetText(ns.GetTypeIconCustomPath(typeKey))
        else
            row.customBox:Hide()
            row.customLabel:Hide()
            row.customCheck:SetChecked(false)
        end
    end
    if row.modeBtn then
        local id = ns.GetTypeIconPreset(typeKey)
        if id == "custom" then
            local path = ns.GetTypeIconCustomPath(typeKey)
            if path ~= "" then
                row.modeBtn:SetText("Custom")
            else
                row.modeBtn:SetText("Browse…")
            end
        elseif id == "default" then
            row.modeBtn:SetText("Default")
        else
            row.modeBtn:SetText(id)
        end
    end
    SyncPreview(row, typeKey)
end

local function RelayoutTypeRows(typeRows)
    local y = typeRows._startY or -120
    local order = typeRows._order or {}
    for _, key in ipairs(order) do
        local row = typeRows[key]
        if row then
            local indent = row.indent or 0
            row.cb:ClearAllPoints()
            row.cb:SetPoint("TOPLEFT", 16 + indent, y)
            row.sizeRow.label:ClearAllPoints()
            row.sizeRow.label:SetPoint("LEFT", row.cb, "LEFT", 150, 0)
            row.iconLabel:ClearAllPoints()
            row.iconLabel:SetPoint("TOPLEFT", 40 + indent, y - 26)
            row.preview:ClearAllPoints()
            row.preview:SetPoint("LEFT", row.iconLabel, "RIGHT", 8, 0)
            row.browseBtn:ClearAllPoints()
            row.browseBtn:SetPoint("LEFT", row.preview, "RIGHT", 8, 0)
            row.modeBtn:ClearAllPoints()
            row.modeBtn:SetPoint("LEFT", row.browseBtn, "RIGHT", 6, 0)
            local nextY = y - 52
            if ns.GetTypeIconPreset(key) == "custom" then
                row.customCheck:ClearAllPoints()
                row.customCheck:SetPoint("TOPLEFT", 36 + indent, y - 48)
                row.customLabel:ClearAllPoints()
                row.customLabel:SetPoint("LEFT", row.customCheck, "RIGHT", 2, 0)
                row.customBox:ClearAllPoints()
                row.customBox:SetPoint("LEFT", row.customLabel, "RIGHT", 8, 0)
                nextY = y - 86
            end
            y = nextY
        end
    end
    if typeRows._content then
        UI.FinishContentHeight(typeRows._content, y - 12)
    end
end

local function RefreshTypeRowsEnabled(typeRows)
    local db = ns.GetDB()
    for key, row in pairs(typeRows) do
        if type(row) == "table" and row.cb then
            local controlsEnabled = true
            local checkboxEnabled = true
            if row.parentKey then
                local parentOn = db.types[row.parentKey] ~= false
                checkboxEnabled = parentOn
                controlsEnabled = parentOn and (db.types[key] ~= false)
            elseif ns.TYPE_BY_KEY[key] then
                controlsEnabled = db.types[key] ~= false
            end
            if checkboxEnabled then row.cb:Enable() else row.cb:Disable() end
            if row.cb.Text then
                row.cb.Text:SetAlpha(checkboxEnabled and 1 or 0.35)
            end
            UI.SetRowEnabled(row.sizeRow, controlsEnabled)
            UI.SetRowEnabled(row, controlsEnabled)
            UpdateCustomVisibility(row, key)
        end
    end
    RelayoutTypeRows(typeRows)
end

function ns.RefreshVendorSettingsRows()
    for _, typeRows in ipairs(vendorPageStates) do
        RefreshTypeRowsEnabled(typeRows)
    end
end

local function CreateTypeIconControls(content, typeRows, typeKey, labelText, y, parentKey)
    local cb = UI.CreateCheckbox(content, labelText, 16, y, function()
        return ns.GetDB().types[typeKey]
    end, function(v)
        -- Top-level types cascade to nested specialties / general subtypes.
        if ns.SetTypeFilterEnabled then
            ns.SetTypeFilterEnabled(typeKey, v, parentKey == nil)
        else
            ns.GetDB().types[typeKey] = v
        end
        -- Sync child checkbox visuals after a parent cascade.
        if parentKey == nil and ns.RefreshSettingsWidgets then
            ns.RefreshSettingsWidgets()
        else
            ns.RefreshVendorSettingsRows()
        end
    end)
    cb.Text:SetWidth(120)
    cb.Text:SetWordWrap(false)

    local sizeRow = UI.CreateIconSizeControl(content, "Size", y, 120, function()
        local scales = UI.EnsureTypeIconScale()
        if scales[typeKey] == nil then
            scales[typeKey] = 1
        end
        return scales[typeKey] or 1
    end, function(v)
        UI.EnsureTypeIconScale()[typeKey] = v
    end, true)
    sizeRow.label:ClearAllPoints()
    sizeRow.label:SetPoint("LEFT", cb, "LEFT", 150, 0)
    sizeRow.slider:ClearAllPoints()
    sizeRow.slider:SetPoint("LEFT", sizeRow.label, "RIGHT", 6, 0)
    sizeRow.editBox:ClearAllPoints()
    sizeRow.editBox:SetPoint("LEFT", sizeRow.slider, "RIGHT", 8, 0)
    sizeRow.pctLabel:ClearAllPoints()
    sizeRow.pctLabel:SetPoint("LEFT", sizeRow.editBox, "RIGHT", 2, 0)

    local iconLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    iconLabel:SetPoint("TOPLEFT", 40, y - 26)
    iconLabel:SetText("Icon")

    local preview = content:CreateTexture(nil, "ARTWORK")
    preview:SetSize(20, 20)
    preview:SetPoint("LEFT", iconLabel, "RIGHT", 8, 0)

    local browseBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    browseBtn:SetSize(80, 22)
    browseBtn:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    browseBtn:SetText("Browse…")
    browseBtn:SetScript("OnClick", function()
        local current = ns.GetTypeIconCustomPath(typeKey)
        ns.OpenIconPicker(function(icon)
            if icon == nil then
                ns.SetTypeIconPreset(typeKey, "default")
                ns.SetTypeIconCustomPath(typeKey, "")
            else
                ns.SetTypeIconPreset(typeKey, "custom")
                ns.SetTypeIconCustomPath(typeKey, tostring(icon))
            end
            UpdateCustomVisibility(typeRows[typeKey], typeKey)
            RelayoutTypeRows(typeRows)
            ns.RefreshAll()
        end, current ~= "" and current or nil)
    end)

    local modeBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    modeBtn:SetSize(80, 22)
    modeBtn:SetPoint("LEFT", browseBtn, "RIGHT", 6, 0)
    modeBtn:SetText("Default")
    modeBtn:SetScript("OnClick", function()
        -- Cycle: default → custom (show path) → default
        if ns.GetTypeIconPreset(typeKey) == "custom" then
            ns.SetTypeIconPreset(typeKey, "default")
        else
            ns.SetTypeIconPreset(typeKey, "custom")
        end
        UpdateCustomVisibility(typeRows[typeKey], typeKey)
        RelayoutTypeRows(typeRows)
        ns.RefreshAll()
    end)
    modeBtn._refresh = function()
        UpdateCustomVisibility(typeRows[typeKey], typeKey)
    end
    UI.RegisterWidget(modeBtn)

    local customCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    customCheck:SetSize(24, 24)
    customCheck:Hide()
    customCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ns.SetTypeIconPreset(typeKey, "custom")
        else
            ns.SetTypeIconPreset(typeKey, "default")
            ns.SetTypeIconCustomPath(typeKey, "")
        end
        UpdateCustomVisibility(typeRows[typeKey], typeKey)
        RelayoutTypeRows(typeRows)
        ns.RefreshAll()
    end)

    local customLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    customLabel:SetText("Path / fileID")
    customLabel:Hide()

    local customBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    customBox:SetSize(300, 20)
    customBox:SetAutoFocus(false)
    customBox:SetMaxLetters(256)
    customBox:Hide()
    customBox:SetScript("OnEnterPressed", function(self)
        ns.SetTypeIconPreset(typeKey, "custom")
        ns.SetTypeIconCustomPath(typeKey, self:GetText())
        self:ClearFocus()
        SyncPreview(typeRows[typeKey], typeKey)
        ns.RefreshAll()
    end)
    customBox:SetScript("OnEditFocusLost", function(self)
        if ns.GetTypeIconPreset(typeKey) == "custom" then
            ns.SetTypeIconCustomPath(typeKey, self:GetText())
            SyncPreview(typeRows[typeKey], typeKey)
            ns.RefreshAll()
        end
    end)

    local row = {
        cb = cb,
        sizeRow = sizeRow,
        iconLabel = iconLabel,
        preview = preview,
        browseBtn = browseBtn,
        modeBtn = modeBtn,
        iconBtn = modeBtn, -- SettingsUI.SetRowEnabled looks for iconBtn
        customCheck = customCheck,
        customLabel = customLabel,
        customBox = customBox,
        parentKey = parentKey,
        indent = parentKey and 24 or 0,
    }
    typeRows[typeKey] = row
    UpdateCustomVisibility(row, typeKey)
    return row
end

function ns.BuildVendorsSettingsPage(frame)
    local typeRows = {}
    vendorPageStates[#vendorPageStates + 1] = typeRows
    local content = frame.content
    UI.EnsureTypeIconScale()

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -8)
    title:SetText("Vendors & Icons")

    local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(580)
    sub:SetJustifyH("LEFT")
    sub:SetText("Faction filters, which vendor types appear, and per-type pin size / icon art.")

    local y = -56
    local factionTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    factionTitle:SetPoint("TOPLEFT", 16, y)
    factionTitle:SetText("Factions")

    y = y - 28
    local fx = 16
    for _, f in ipairs(ns.FACTIONS) do
        UI.CreateCheckbox(content, f.label, fx, y, function()
            return ns.GetDB().factions[f.key]
        end, function(v)
            ns.GetDB().factions[f.key] = v
        end)
        fx = fx + 140
    end

    y = y - 40
    local typeTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    typeTitle:SetPoint("TOPLEFT", 16, y)
    typeTitle:SetText("Vendor types")

    local typeHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    typeHint:SetPoint("TOPLEFT", 16, y - 18)
    typeHint:SetWidth(580)
    typeHint:SetJustifyH("LEFT")
    typeHint:SetText("Browse… picks any in-game icon. Opt into Custom path for an Interface\\… texture path or fileID.")

    y = y - 48
    typeRows._startY = y
    typeRows._content = content
    typeRows._order = {}

    for _, t in ipairs(ns.VENDOR_TYPES) do
        typeRows._order[#typeRows._order + 1] = t.key
        CreateTypeIconControls(content, typeRows, t.key, t.label, y)
        y = y - 52

        for _, nested in ipairs(NestedForParent(t.key)) do
            typeRows._order[#typeRows._order + 1] = nested.key
            CreateTypeIconControls(content, typeRows, nested.key, nested.label, y, t.key)
            y = y - 52
        end
    end

    RelayoutTypeRows(typeRows)
end
