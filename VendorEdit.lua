local _, ns = ...

-- Right-click pin editor. Saves full type replacements into VendorMapOverridesDB.

local VendorEdit = {}
ns.VendorEdit = VendorEdit

local frame
local typesScrollChild
local pageFrames = {}   -- key -> page frame
local tabButtons = {}   -- ordered list of tab buttons
local activeTabKey
local editing
local typeChecks = {}
local noteBox
local subtitleBox
local factionBtn
local hideCheck
local selectedFaction = "Neutral"
local selectedIconPreset = "default"
-- Profession and class specialties are independent UI state; save picks the active one.
local selectedProfessionSpecialty = "auto" -- auto | trainer | specialty_* (profession parent)
local selectedClassSpecialty = "auto" -- auto | specialty_* (class parent)
local iconPreview
local iconBtn
local iconBrowseBtn
local iconCustomLabel
local iconCustomBox
local iconHint
local profRoleBtn
local profCraftBtn
local profRoleLabel
local classRoleBtn
local classCraftBtn
local classRoleLabel
local typesGridBottom = 0  -- y offset just below the type checkbox grid

local TABS = {
    { key = "types", title = "Types" },
    { key = "pin",   title = "Pin" },
    { key = "notes", title = "Notes" },
}

local FACTIONS = { "Alliance", "Horde", "Neutral" }

local function ProfessionCraftOptions()
    local opts = {}
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES or {}) do
        if sub.parent == "profession" then
            opts[#opts + 1] = { value = sub.key, label = sub.label }
        end
    end
    return opts
end

local function SpecialtyLabel(key)
    if not key or key == "auto" then
        return "Auto (from subtitle)"
    end
    if key == "trainer" then
        return "Trainer (skillbook)"
    end
    local sub = ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[key]
    if sub then
        return sub.label
    end
    return tostring(key)
end

local function ProfessionRoleFromKey(key)
    if key == "trainer" then
        return "trainer"
    end
    local sub = key and ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[key]
    if sub and sub.parent == "profession" then
        return "supplies"
    end
    return "auto"
end

local function ClassSpecialtyOptions()
    local opts = {}
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES or {}) do
        if sub.parent == "class" then
            opts[#opts + 1] = { value = sub.key, label = sub.label }
        end
    end
    return opts
end

local function ClassRoleFromKey(key)
    local sub = key and ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[key]
    if sub and sub.parent == "class" then
        return "supplies"
    end
    return "auto"
end

local function ClassSpecialtyLabel(key)
    local sub = key and ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[key]
    if sub and sub.parent == "class" then
        return sub.label
    end
    return "Auto (from subtitle)"
end

--- Effective specialty for icon preview / save (one key on the override).
local function EffectiveSpecialtyKey()
    local profOn = typeChecks.profession and typeChecks.profession:GetChecked()
    local classOn = typeChecks.class and typeChecks.class:GetChecked()
    if profOn and selectedProfessionSpecialty and selectedProfessionSpecialty ~= "auto" then
        return selectedProfessionSpecialty
    end
    if classOn and selectedClassSpecialty and selectedClassSpecialty ~= "auto" then
        return selectedClassSpecialty
    end
    return "auto"
end

local function PresetOptions()
    local opts = {}
    for _, p in ipairs(ns.ICON_PRESETS or {}) do
        local label = p.label
        if p.id == "default" then
            label = "Type default"
        end
        opts[#opts + 1] = { value = p.id, label = label }
    end
    if #opts == 0 then
        opts[1] = { value = "default", label = "Type default" }
    end
    return opts
end

local function LabelForPreset(id)
    for _, opt in ipairs(PresetOptions()) do
        if opt.value == id then
            return opt.label
        end
    end
    return tostring(id)
end

local function CyclePreset(current)
    local opts = PresetOptions()
    for i, opt in ipairs(opts) do
        if opt.value == current then
            return (opts[i + 1] or opts[1]).value
        end
    end
    return opts[1].value
end

-- Position profession/class detail below the type grid and size the Types scroll child
-- from real content, so hiding the controls leaves no reserved gap.
local function RelayoutTypesPage()
    if not typesScrollChild or not profRoleBtn or not classRoleBtn then
        return
    end
    local profOn = typeChecks.profession and typeChecks.profession:GetChecked()
    local classOn = typeChecks.class and typeChecks.class:GetChecked()
    local bottom = typesGridBottom - 4  -- start just under the grid
    if profOn then
        profRoleLabel:ClearAllPoints()
        profRoleLabel:SetPoint("TOPLEFT", 12, bottom - 2)
        profRoleLabel:Show()
        bottom = bottom - 20

        profRoleBtn:ClearAllPoints()
        profRoleBtn:SetPoint("TOPLEFT", 8, bottom)
        profRoleBtn:Show()
        bottom = bottom - 26

        local role = ProfessionRoleFromKey(selectedProfessionSpecialty)
        if role == "trainer" then
            profRoleBtn:SetText("Role: Trainer")
            profCraftBtn:Hide()
        elseif role == "supplies" then
            profRoleBtn:SetText("Role: Supplies")
            profCraftBtn:ClearAllPoints()
            profCraftBtn:SetPoint("TOPLEFT", 8, bottom)
            profCraftBtn:Show()
            profCraftBtn:SetText(SpecialtyLabel(selectedProfessionSpecialty))
            bottom = bottom - 28
        else
            profRoleBtn:SetText("Role: Auto")
            profCraftBtn:Hide()
        end
    else
        profRoleLabel:Hide()
        profRoleBtn:Hide()
        profCraftBtn:Hide()
    end

    if classOn then
        classRoleLabel:ClearAllPoints()
        classRoleLabel:SetPoint("TOPLEFT", 12, bottom - 2)
        classRoleLabel:Show()
        bottom = bottom - 20

        classRoleBtn:ClearAllPoints()
        classRoleBtn:SetPoint("TOPLEFT", 8, bottom)
        classRoleBtn:Show()
        bottom = bottom - 26

        local role = ClassRoleFromKey(selectedClassSpecialty)
        if role == "supplies" then
            classRoleBtn:SetText("Role: Supplies")
            classCraftBtn:ClearAllPoints()
            classCraftBtn:SetPoint("TOPLEFT", 8, bottom)
            classCraftBtn:Show()
            classCraftBtn:SetText(ClassSpecialtyLabel(selectedClassSpecialty))
            bottom = bottom - 28
        else
            classRoleBtn:SetText("Role: Auto")
            classCraftBtn:Hide()
        end
    else
        classRoleLabel:Hide()
        classRoleBtn:Hide()
        classCraftBtn:Hide()
    end

    typesScrollChild:SetHeight(math.max(120, math.abs(bottom) + 12))
end

-- Kept as the single entry point callers use after toggling profession/class/craft.
local function UpdateProfessionControls()
    RelayoutTypesPage()
end

local function SyncIconPreview()
    if not iconPreview or not editing then
        return
    end
    local previewInfo = {
        name = editing.name,
        subtitle = subtitleBox and subtitleBox:GetText() or editing.subtitle,
        note = noteBox and noteBox:GetText() or editing.note,
        types = editing.types,
        faction = selectedFaction,
        iconPreset = selectedIconPreset,
        iconCustom = iconCustomBox and iconCustomBox:GetText() or nil,
        specialtyKey = EffectiveSpecialtyKey(),
    }
    -- Reflect current type checkboxes for accurate "Type default" preview.
    local types = {}
    for key, cb in pairs(typeChecks) do
        if cb:GetChecked() then
            types[key] = true
        end
    end
    if next(types) then
        previewInfo.types = types
    end
    if ns.SetVendorPinIcon then
        ns.SetVendorPinIcon(iconPreview, previewInfo)
    elseif ns.SetTypeIcon then
        local key = ns.GetPinDisplayType and ns.GetPinDisplayType(previewInfo) or "general"
        ns.SetTypeIcon(iconPreview, key, selectedFaction)
    end
end

-- Anchor the icon hint under the custom-path row only when Custom is active,
-- so Default mode leaves no empty gap on the Pin page.
local function RelayoutPinPage()
    if not iconHint or not iconCustomLabel then
        return
    end
    iconHint:ClearAllPoints()
    if selectedIconPreset == "custom" then
        iconHint:SetPoint("TOPLEFT", iconCustomLabel, "BOTTOMLEFT", -4, -12)
    else
        iconHint:SetPoint("TOPLEFT", iconCustomLabel, "TOPLEFT", -4, -6)
    end
end

local function UpdateCustomPathVisibility()
    local isCustom = selectedIconPreset == "custom"
    if iconCustomLabel and iconCustomBox then
        if isCustom then
            iconCustomLabel:Show()
            iconCustomBox:Show()
        else
            iconCustomLabel:Hide()
            iconCustomBox:Hide()
        end
    end
    if iconBtn then
        if selectedIconPreset == "default" then
            iconBtn:SetText("Default")
        elseif selectedIconPreset == "custom" then
            iconBtn:SetText("Custom path")
        else
            iconBtn:SetText(LabelForPreset(selectedIconPreset))
        end
    end
    RelayoutPinPage()
    SyncIconPreview()
end

local function CycleFaction()
    local idx = 1
    for i, fac in ipairs(FACTIONS) do
        if fac == selectedFaction then
            idx = i
            break
        end
    end
    selectedFaction = FACTIONS[(idx % #FACTIONS) + 1]
    if factionBtn then
        factionBtn:SetText("Faction: " .. selectedFaction)
    end
    SyncIconPreview()
end

local function EnsureOverrides()
    VendorMapOverridesDB = VendorMapOverridesDB or {}
    return VendorMapOverridesDB
end

--- Stable override key: prefer npcID; fall back to synthetic seed id (hub AH/bank markers).
function ns.VendorOverrideKey(info)
    if not info then
        return nil
    end
    if info.npcID ~= nil and info.npcID ~= "" then
        return tonumber(info.npcID) or info.npcID
    end
    if info.id ~= nil and info.id ~= "" then
        return info.id
    end
    return nil
end

function ns.GetVendorOverride(key)
    if key == nil or key == "" then
        return nil
    end
    local db = VendorMapOverridesDB
    if type(db) ~= "table" then
        return nil
    end
    local found = db[key] or db[tostring(key)]
    if found then
        return found
    end
    local asNum = tonumber(key)
    if asNum then
        return db[asNum]
    end
    return nil
end

function ns.SetVendorOverride(key, override)
    if key == nil or key == "" then
        return
    end
    local id = tonumber(key) or key
    local db = EnsureOverrides()
    -- Clear both numeric and string forms so old/new keys don't leave duplicates.
    db[tostring(id)] = nil
    if type(id) == "number" then
        db[id] = nil
    end
    if override == nil then
        db[id] = nil
    else
        db[id] = override
    end
    if ns.Database then
        ns.Database:Rebuild()
    end
    -- Defer refresh a frame so pin sizing runs after the edit dialog finishes hiding.
    C_Timer.After(0, function()
        ns.RefreshAll()
    end)
end

local function CollectTypesFromUI(existing)
    -- Start from current types so keys the dialog does not render (e.g. legacy
    -- subtype keys) are preserved; then apply checkbox state for top-level types.
    local types = {}
    if type(existing) == "table" then
        for key, val in pairs(existing) do
            if val then
                types[key] = true
            end
        end
    end
    for key, cb in pairs(typeChecks) do
        if cb:GetChecked() then
            types[key] = true
        else
            types[key] = nil
        end
    end
    return types
end

local function CollectIconFromUI()
    local preset = selectedIconPreset or "default"
    local custom = nil
    if iconCustomBox then
        local text = iconCustomBox:GetText() or ""
        text = text:match("^%s*(.-)%s*$") or ""
        if text ~= "" then
            custom = text
        end
    end
    if preset == "default" then
        return nil, nil
    end
    if preset == "custom" then
        -- Custom selected but empty path → treat as type default.
        if not custom then
            return nil, nil
        end
        return "custom", custom
    end
    return preset, nil
end

local function LoadInfoIntoUI(info)
    editing = info
    selectedFaction = info.faction or "Neutral"
    if factionBtn then
        factionBtn:SetText("Faction: " .. selectedFaction)
    end
    if hideCheck then
        hideCheck:SetChecked(not not info.hidden)
    end
    local ov = ns.GetVendorOverride(ns.VendorOverrideKey(info))
    if noteBox then
        noteBox:SetText(info.note or "")
    end
    if subtitleBox then
        subtitleBox:SetText((ov and ov.subtitle) or info.subtitle or "")
    end
    for key, cb in pairs(typeChecks) do
        cb:SetChecked(not not (info.types and info.types[key]))
    end

    local loadedSpecialty = (ov and ov.specialtyKey) or info.specialtyKey or "auto"
    if loadedSpecialty == "" or loadedSpecialty == nil then
        loadedSpecialty = "auto"
    end
    selectedProfessionSpecialty = "auto"
    selectedClassSpecialty = "auto"
    if loadedSpecialty == "trainer" then
        selectedProfessionSpecialty = "trainer"
    else
        local sub = ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[loadedSpecialty]
        if sub and sub.parent == "class" then
            selectedClassSpecialty = loadedSpecialty
        elseif sub and sub.parent == "profession" then
            selectedProfessionSpecialty = loadedSpecialty
        end
    end

    selectedIconPreset = (ov and ov.iconPreset) or info.iconPreset or "default"
    if selectedIconPreset == "" then
        selectedIconPreset = "default"
    end
    if iconCustomBox then
        iconCustomBox:SetText((ov and ov.iconCustom) or info.iconCustom or "")
    end
    UpdateCustomPathVisibility()
    UpdateProfessionControls()

    if frame.title then
        local title = (ns.Names and ns.Names:DisplayName(info)) or info.name
        if type(title) ~= "string" or title == "" then
            title = "Vendor"
        end
        frame.title:SetText(title)
    end
end

-- Switch the visible page and mark the active tab (disabled = current).
local function ShowTab(key)
    activeTabKey = key
    for _, tab in ipairs(tabButtons) do
        if tab.key == key then
            tab:Disable()
            tab:LockHighlight()
        else
            tab:Enable()
            tab:UnlockHighlight()
        end
    end
    for pageKey, pageFrame in pairs(pageFrames) do
        if pageKey == key then
            pageFrame:Show()
        else
            pageFrame:Hide()
        end
    end
end

local function BuildTypesPage(body)
    local page = CreateFrame("Frame", nil, body)
    page:SetAllPoints(body)
    pageFrames.types = page

    local scroll = CreateFrame("ScrollFrame", "VendorMapVendorEditTypesScroll", page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 28
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, cur - delta * step)))
    end)

    typesScrollChild = CreateFrame("Frame", "VendorMapVendorEditTypesChild", scroll)
    typesScrollChild:SetSize(360, 240)
    scroll:SetScrollChild(typesScrollChild)

    local content = typesScrollChild
    local COLS = 2
    local colW = 182
    local rowH = 24
    for i, def in ipairs(ns.VENDOR_TYPES) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 8 + col * colW, -4 - row * rowH)
        cb.Text:SetText(def.label)
        -- Default check-button text is near-black; force the readable settings style.
        cb.Text:SetFontObject(GameFontHighlight)
        cb.Text:SetTextColor(1, 1, 1)
        typeChecks[def.key] = cb
        cb:SetScript("OnClick", function()
            UpdateProfessionControls()
            SyncIconPreview()
        end)
    end
    local rows = math.ceil(#ns.VENDOR_TYPES / COLS)
    typesGridBottom = -4 - rows * rowH

    profRoleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profRoleLabel:SetText("Profession detail")
    profRoleLabel:SetTextColor(1, 0.82, 0)
    profRoleLabel:Hide()

    profRoleBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    profRoleBtn:SetSize(200, 22)
    profRoleBtn:SetText("Role: Auto")
    profRoleBtn:Hide()
    profRoleBtn:SetScript("OnClick", function()
        local role = ProfessionRoleFromKey(selectedProfessionSpecialty)
        local crafts = ProfessionCraftOptions()
        if role == "auto" then
            selectedProfessionSpecialty = "trainer"
        elseif role == "trainer" then
            selectedProfessionSpecialty = (crafts[1] and crafts[1].value) or "auto"
        else
            selectedProfessionSpecialty = "auto"
        end
        UpdateProfessionControls()
        SyncIconPreview()
    end)

    profCraftBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    profCraftBtn:SetSize(240, 22)
    profCraftBtn:SetText("Alchemy Supplies")
    profCraftBtn:Hide()
    profCraftBtn:SetScript("OnClick", function()
        local crafts = ProfessionCraftOptions()
        if #crafts == 0 then
            return
        end
        local idx = 1
        for i, opt in ipairs(crafts) do
            if opt.value == selectedProfessionSpecialty then
                idx = i
                break
            end
        end
        selectedProfessionSpecialty = crafts[(idx % #crafts) + 1].value
        UpdateProfessionControls()
        SyncIconPreview()
    end)

    classRoleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classRoleLabel:SetText("Class detail")
    classRoleLabel:SetTextColor(1, 0.82, 0)
    classRoleLabel:Hide()

    classRoleBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    classRoleBtn:SetSize(200, 22)
    classRoleBtn:SetText("Role: Auto")
    classRoleBtn:Hide()
    classRoleBtn:SetScript("OnClick", function()
        local role = ClassRoleFromKey(selectedClassSpecialty)
        local opts = ClassSpecialtyOptions()
        if role == "auto" then
            selectedClassSpecialty = (opts[1] and opts[1].value) or "auto"
        else
            selectedClassSpecialty = "auto"
        end
        UpdateProfessionControls()
        SyncIconPreview()
    end)

    classCraftBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    classCraftBtn:SetSize(240, 22)
    classCraftBtn:SetText("Mage Supplies")
    classCraftBtn:Hide()
    classCraftBtn:SetScript("OnClick", function()
        local opts = ClassSpecialtyOptions()
        if #opts == 0 then
            return
        end
        local idx = 1
        for i, opt in ipairs(opts) do
            if opt.value == selectedClassSpecialty then
                idx = i
                break
            end
        end
        selectedClassSpecialty = opts[(idx % #opts) + 1].value
        UpdateProfessionControls()
        SyncIconPreview()
    end)
end

local function BuildPinPage(body)
    local page = CreateFrame("Frame", nil, body)
    page:SetAllPoints(body)
    pageFrames.pin = page

    local y = -6
    factionBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    factionBtn:SetSize(200, 24)
    factionBtn:SetPoint("TOPLEFT", 8, y)
    factionBtn:SetText("Faction: Neutral")
    factionBtn:SetScript("OnClick", CycleFaction)
    y = y - 34

    hideCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    hideCheck:SetPoint("TOPLEFT", 8, y)
    hideCheck.Text:SetText("Hide this pin")
    hideCheck.Text:SetFontObject(GameFontHighlight)
    hideCheck.Text:SetTextColor(1, 1, 1)
    y = y - 34

    local iconLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", 8, y)
    iconLabel:SetText("Pin icon")
    iconLabel:SetTextColor(1, 0.82, 0)
    y = y - 22

    iconPreview = page:CreateTexture(nil, "ARTWORK")
    iconPreview:SetSize(22, 22)
    iconPreview:SetPoint("TOPLEFT", 10, y)

    iconBrowseBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    iconBrowseBtn:SetSize(90, 22)
    iconBrowseBtn:SetPoint("LEFT", iconPreview, "RIGHT", 8, 0)
    iconBrowseBtn:SetText("Browse…")
    iconBrowseBtn:SetScript("OnClick", function()
        local current = iconCustomBox and iconCustomBox:GetText() or ""
        ns.OpenIconPicker(function(icon)
            if icon == nil then
                selectedIconPreset = "default"
                if iconCustomBox then
                    iconCustomBox:SetText("")
                end
            else
                selectedIconPreset = "custom"
                if iconCustomBox then
                    iconCustomBox:SetText(tostring(icon))
                end
            end
            UpdateCustomPathVisibility()
        end, current ~= "" and current or nil)
    end)

    iconBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    iconBtn:SetSize(100, 22)
    iconBtn:SetPoint("LEFT", iconBrowseBtn, "RIGHT", 6, 0)
    iconBtn:SetText("Default")
    iconBtn:SetScript("OnClick", function()
        if selectedIconPreset == "custom" then
            selectedIconPreset = "default"
        else
            selectedIconPreset = "custom"
        end
        UpdateCustomPathVisibility()
    end)
    y = y - 32

    iconCustomLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconCustomLabel:SetPoint("TOPLEFT", 8, y)
    iconCustomLabel:SetText("Path / fileID")
    iconCustomLabel:SetTextColor(0.9, 0.9, 0.9)
    iconCustomLabel:Hide()

    iconCustomBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    iconCustomBox:SetPoint("LEFT", iconCustomLabel, "RIGHT", 8, 0)
    iconCustomBox:SetSize(240, 20)
    iconCustomBox:SetAutoFocus(false)
    iconCustomBox:SetMaxLetters(256)
    iconCustomBox:Hide()
    iconCustomBox:SetScript("OnTextChanged", function()
        if selectedIconPreset == "custom" then
            SyncIconPreview()
        end
    end)
    iconCustomBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        SyncIconPreview()
    end)

    iconHint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconHint:SetWidth(360)
    iconHint:SetJustifyH("LEFT")
    iconHint:SetTextColor(0.65, 0.65, 0.65)
    iconHint:SetText("Browse any in-game icon, or opt into a Custom path (Interface\\… or fileID).")
end

local function BuildNotesPage(body)
    local page = CreateFrame("Frame", nil, body)
    page:SetAllPoints(body)
    pageFrames.notes = page

    local subtitleLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitleLabel:SetPoint("TOPLEFT", 8, -6)
    subtitleLabel:SetText("Subtitle")
    subtitleLabel:SetTextColor(1, 0.82, 0)

    subtitleBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    subtitleBox:SetPoint("TOPLEFT", 12, -26)
    subtitleBox:SetSize(360, 24)
    subtitleBox:SetAutoFocus(false)
    subtitleBox:SetScript("OnTextChanged", function()
        SyncIconPreview()
    end)

    local noteLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", 8, -64)
    noteLabel:SetText("Note")
    noteLabel:SetTextColor(1, 0.82, 0)

    noteBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    noteBox:SetPoint("TOPLEFT", 12, -84)
    noteBox:SetSize(360, 24)
    noteBox:SetAutoFocus(false)
end

local function BuildFrame()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "VendorMapVendorEditFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 470)
    frame:SetPoint("CENTER")
    -- TOOLTIP strata sits above WorldMapFrame and the overlap click-catcher
    -- (FULLSCREEN_DIALOG). Without this, the invisible catcher eats all clicks.
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    -- BackdropTemplate defaults to an unreadable wash without an explicit color.
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.97)
    frame:SetBackdropBorderColor(0.55, 0.55, 0.65, 1)
    frame:Hide()
    tinsert(UISpecialFrames, "VendorMapVendorEditFrame")

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(false)
    end
    frame:SetScript("OnHide", function(self)
        if self.EnableKeyboard then
            self:EnableKeyboard(false)
        end
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 16, -16)
    frame.title:SetWidth(360)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetText("Edit Vendor")
    frame.title:SetTextColor(1, 0.82, 0)

    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(380)
    sub:SetJustifyH("LEFT")
    sub:SetText("Overrides seed/learned data for this character's SavedVariables.")
    sub:SetTextColor(0.85, 0.85, 0.85)

    -- Tab strip selects which page is visible below.
    local tabX = 16
    for _, def in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(100, 22)
        tab:SetPoint("TOPLEFT", tabX, -60)
        tab:SetText(def.title)
        tab.key = def.key
        tab:SetScript("OnClick", function()
            ShowTab(def.key)
        end)
        tabButtons[#tabButtons + 1] = tab
        tabX = tabX + 104
    end

    -- Footer buttons stay fixed below the page body.
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetSize(90, 24)
    saveBtn:SetPoint("BOTTOMLEFT", 16, 16)
    saveBtn:SetText("Save")
    saveBtn:SetFrameLevel(frame:GetFrameLevel() + 5)

    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(90, 24)
    resetBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    resetBtn:SetText("Reset")
    resetBtn:SetFrameLevel(frame:GetFrameLevel() + 5)

    local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", -16, 16)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetFrameLevel(frame:GetFrameLevel() + 5)
    cancelBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Shared body region hosts the three tab pages.
    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", 12, -90)
    frame.body:SetPoint("BOTTOMRIGHT", -12, 46)

    BuildTypesPage(frame.body)
    BuildPinPage(frame.body)
    BuildNotesPage(frame.body)

    RelayoutTypesPage()
    RelayoutPinPage()
    ShowTab("types")

    saveBtn:SetScript("OnClick", function()
        local ovKey = editing and ns.VendorOverrideKey(editing)
        if not ovKey then
            ns.Print("Cannot override a vendor without an id.")
            return
        end
        noteBox:ClearFocus()
        if subtitleBox then
            subtitleBox:ClearFocus()
        end
        if iconCustomBox then
            iconCustomBox:ClearFocus()
        end
        local noteText = noteBox:GetText() or ""
        noteText = noteText:match("^%s*(.-)%s*$") or ""
        local subtitleText = subtitleBox and subtitleBox:GetText() or ""
        subtitleText = subtitleText:match("^%s*(.-)%s*$") or ""
        local iconPreset, iconCustom = CollectIconFromUI()
        local displayName = (ns.Names and ns.Names:DisplayName(editing)) or editing.name
        if type(displayName) ~= "string" or displayName == "" then
            displayName = "Vendor"
        end
        local existingTypes = editing and editing.types
        local override = {
            types = CollectTypesFromUI(existingTypes),
            faction = selectedFaction,
            note = noteText,
            subtitle = subtitleText,
            hidden = hideCheck:GetChecked() and true or false,
            name = displayName,
        }
        -- Persist one specialty key: class supplies when Class is checked with a pick,
        -- otherwise profession trainer/craft when Profession is checked.
        do
            local key = EffectiveSpecialtyKey()
            local profOn = override.types and override.types.profession
            local classOn = override.types and override.types.class
            local valid = false
            if key and key ~= "auto" then
                if key == "trainer" then
                    valid = profOn and true or false
                else
                    local sub = ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[key]
                    if sub then
                        if sub.parent == "class" then
                            valid = classOn and true or false
                        else
                            valid = profOn and true or false
                        end
                    end
                end
            end
            override.specialtyKey = valid and key or "auto"
        end
        if iconPreset then
            override.iconPreset = iconPreset
        end
        if iconCustom then
            override.iconCustom = iconCustom
        end
        frame:Hide()
        ns.SetVendorOverride(ovKey, override)
        ns.Print("Saved override for " .. displayName .. " (applies immediately).")
    end)

    resetBtn:SetScript("OnClick", function()
        local ovKey = editing and ns.VendorOverrideKey(editing)
        if not ovKey then
            return
        end
        local label = (ns.Names and ns.Names:DisplayName(editing)) or editing.name or tostring(ovKey)
        frame:Hide()
        ns.SetVendorOverride(ovKey, nil)
        ns.Print("Cleared override for " .. label)
    end)

    return frame
end

function VendorEdit:Open(info)
    if not info then
        return
    end
    -- Drop the fullscreen click-catcher before we take mouse focus.
    if ns.Overlap and ns.Overlap.ClosePickMenu then
        ns.Overlap.ClosePickMenu()
    end
    BuildFrame()
    LoadInfoIntoUI(info)
    ShowTab("types")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:Show()
    frame:Raise()
    if frame.EnableKeyboard then
        frame:EnableKeyboard(true)
    end
end

function ns.OpenVendorEdit(info)
    VendorEdit:Open(info)
end
