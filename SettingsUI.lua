local _, ns = ...

-- Shared settings widgets / layout helpers used by each settings page.

local UI = {}
ns.SettingsUI = UI

UI.widgets = {}
UI.SIZE_MIN_PCT = 10
UI.SIZE_MAX_PCT = 300
UI.SIZE_SLIDER_STEP = 5

local sliderSerial = 0

function UI.ResetWidgets()
    wipe(UI.widgets)
end

function UI.RegisterWidget(w)
    UI.widgets[#UI.widgets + 1] = w
    return w
end

function UI.RebuildAndRefresh()
    if ns.Database and ns.Database.Rebuild then
        ns.Database:Rebuild()
    end
    ns.RefreshAll()
end

function UI.LabelForValue(options, value)
    for _, opt in ipairs(options) do
        if opt.value == value then
            return opt.label
        end
    end
    return tostring(value)
end

function UI.CycleOption(options, current)
    for i, opt in ipairs(options) do
        if opt.value == current then
            return (options[i + 1] or options[1]).value
        end
    end
    return options[1].value
end

function UI.ScaleToPercent(scale)
    return math.floor(((scale or 1) * 100) + 0.5)
end

function UI.PercentToScale(pct)
    return (pct or 100) / 100
end

function UI.ClampPercent(pct)
    pct = tonumber(pct) or 100
    pct = math.floor(pct + 0.5)
    return math.max(UI.SIZE_MIN_PCT, math.min(UI.SIZE_MAX_PCT, pct))
end

function UI.EnsureTypeIconScale()
    local db = ns.GetDB()
    db.typeIconScale = db.typeIconScale or {}
    for _, t in ipairs(ns.VENDOR_TYPES) do
        if db.typeIconScale[t.key] == nil then
            db.typeIconScale[t.key] = 1.0
        end
    end
    for _, sub in ipairs(ns.GENERAL_SUBTYPES or {}) do
        if db.typeIconScale[sub.key] == nil then
            db.typeIconScale[sub.key] = 1.0
        end
    end
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES or {}) do
        if db.typeIconScale[sub.key] == nil then
            db.typeIconScale[sub.key] = 1.0
        end
    end
    return db.typeIconScale
end

function UI.CreateCheckbox(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb.Text:SetFontObject(GameFontHighlight)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked())
        ns.RefreshAll()
    end)
    cb._get = get
    return UI.RegisterWidget(cb)
end

function UI.CreateCycleButton(parent, title, options, y, get, set, btnWidth)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetText(title)

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(btnWidth or 300, 24)
    btn:SetPoint("LEFT", label, "RIGHT", 12, 0)
    btn:SetScript("OnClick", function()
        local nextValue = UI.CycleOption(options, get())
        set(nextValue)
        btn:SetText(UI.LabelForValue(options, nextValue))
        ns.RefreshAll()
    end)
    btn._refresh = function()
        btn:SetText(UI.LabelForValue(options, get()))
    end
    UI.RegisterWidget(btn)
    return btn, label
end

function UI.CreateIconSizeControl(parent, title, y, sliderWidth, get, set, compact)
    sliderSerial = sliderSerial + 1
    local name = "VendorMapIconSizeSlider" .. sliderSerial

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetText(title)

    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", label, "RIGHT", 12, 0)
    slider:SetWidth(sliderWidth or 200)
    slider:SetHeight(17)
    slider:SetMinMaxValues(UI.SIZE_MIN_PCT, UI.SIZE_MAX_PCT)
    slider:SetValueStep(UI.SIZE_SLIDER_STEP)
    slider:SetObeyStepOnDrag(true)
    slider:SetStepsPerPage(UI.SIZE_SLIDER_STEP)

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]
    if text then
        text:SetText("")
    end
    if compact then
        if low then low:Hide() end
        if high then high:Hide() end
    else
        if low then low:SetText(UI.SIZE_MIN_PCT .. "%") end
        if high then high:SetText(UI.SIZE_MAX_PCT .. "%") end
    end

    local editBox = CreateFrame("EditBox", name .. "Edit", parent, "InputBoxTemplate")
    editBox:SetSize(44, 20)
    editBox:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(3)
    editBox:SetJustifyH("RIGHT")

    local pctLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pctLabel:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
    pctLabel:SetText("%")

    local function commitPercent(pct, fromSlider)
        pct = UI.ClampPercent(pct)
        set(UI.PercentToScale(pct))
        slider._silent = true
        local sliderPct = math.max(UI.SIZE_MIN_PCT, math.min(UI.SIZE_MAX_PCT, math.floor(pct / UI.SIZE_SLIDER_STEP + 0.5) * UI.SIZE_SLIDER_STEP))
        slider:SetValue(fromSlider and pct or sliderPct)
        if not slider._silentEdit then
            editBox:SetText(tostring(pct))
        end
        slider._silent = false
        ns.RefreshAll()
        return pct
    end

    local function syncFromDB()
        local pct = UI.ClampPercent(UI.ScaleToPercent(get()))
        slider._silent = true
        slider._silentEdit = true
        local sliderPct = math.max(UI.SIZE_MIN_PCT, math.min(UI.SIZE_MAX_PCT, math.floor(pct / UI.SIZE_SLIDER_STEP + 0.5) * UI.SIZE_SLIDER_STEP))
        slider:SetValue(sliderPct)
        editBox:SetText(tostring(pct))
        slider._silentEdit = false
        slider._silent = false
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self._silent then
            return
        end
        commitPercent(value, true)
    end)

    local function commitEdit()
        local pct = UI.ClampPercent(editBox:GetNumber())
        editBox:SetText(tostring(pct))
        editBox:ClearFocus()
        commitPercent(pct, false)
    end

    editBox:SetScript("OnEnterPressed", commitEdit)
    editBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" or not tonumber(self:GetText()) then
            syncFromDB()
            return
        end
        commitEdit()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        syncFromDB()
        self:ClearFocus()
    end)

    local row = {
        label = label,
        slider = slider,
        editBox = editBox,
        pctLabel = pctLabel,
        _refresh = syncFromDB,
    }
    UI.RegisterWidget(row)
    syncFromDB()
    return row
end

function UI.SetRowEnabled(row, enabled)
    local alpha = enabled and 1 or 0.35
    if row.slider then
        if enabled then row.slider:Enable() else row.slider:Disable() end
        row.slider:SetAlpha(alpha)
    end
    if row.editBox then
        if enabled then row.editBox:Enable() else row.editBox:Disable() end
        row.editBox:SetAlpha(alpha)
    end
    if row.label then row.label:SetAlpha(alpha) end
    if row.pctLabel then row.pctLabel:SetAlpha(alpha) end
    if row.iconBtn then
        if enabled then row.iconBtn:Enable() else row.iconBtn:Disable() end
        row.iconBtn:SetAlpha(alpha)
    end
    if row.browseBtn then
        if enabled then row.browseBtn:Enable() else row.browseBtn:Disable() end
        row.browseBtn:SetAlpha(alpha)
    end
    if row.modeBtn and row.modeBtn ~= row.iconBtn then
        if enabled then row.modeBtn:Enable() else row.modeBtn:Disable() end
        row.modeBtn:SetAlpha(alpha)
    end
    if row.preview then row.preview:SetAlpha(alpha) end
    if row.customBox then
        if enabled and row.customBox:IsShown() then row.customBox:Enable() else row.customBox:Disable() end
        row.customBox:SetAlpha(alpha)
    end
    if row.customCheck then
        if enabled then row.customCheck:Enable() else row.customCheck:Disable() end
        row.customCheck:SetAlpha(alpha)
    end
    if row.customLabel then row.customLabel:SetAlpha(alpha) end
end

--- Create a canvas frame suitable for Settings.RegisterCanvasLayout* + standalone hosting.
function UI.CreateCanvas(name)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:Hide()
    frame.name = name

    local scroll = CreateFrame("ScrollFrame", name .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 4)

    local content = CreateFrame("Frame", name .. "ScrollChild", scroll)
    content:SetWidth(620)
    content:SetHeight(800)
    scroll:SetScrollChild(content)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 36
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, cur - delta * step)))
    end)

    frame.scroll = scroll
    frame.content = content

    frame:SetScript("OnShow", function()
        if content._contentHeight then
            content:SetHeight(content._contentHeight)
        end
        if ns.RefreshSettingsWidgets then
            ns.RefreshSettingsWidgets()
        end
    end)

    return frame
end

function UI.FinishContentHeight(content, y)
    content._contentHeight = math.abs(y) + 60
    content:SetHeight(content._contentHeight)
end
