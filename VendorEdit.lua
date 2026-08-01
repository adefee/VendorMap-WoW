local _, ns = ...

-- Right-click pin editor. Saves full type replacements into VendorMapOverridesDB.

local VendorEdit = {}
ns.VendorEdit = VendorEdit

local frame
local scrollChild
local editing
local typeChecks = {}
local noteBox
local subtitleBox
local factionBtn
local hideCheck
local selectedFaction = "Neutral"
local selectedIconPreset = "default"
local selectedSpecialtyKey = "auto" -- auto | trainer | specialty_*
local iconPreview
local iconBtn
local iconBrowseBtn
local iconCustomLabel
local iconCustomBox
local iconHint
local profRoleBtn
local profCraftBtn
local profRoleLabel
local contentBottomY = 0

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
    if key and key ~= "auto" and ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[key] then
        return "supplies"
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

local function UpdateScrollChildHeight()
    if not scrollChild then
        return
    end
    -- contentBottomY is the note label; note + subtitle boxes sit below + padding.
    local height = math.abs(contentBottomY) + 100
    if selectedIconPreset == "custom" then
        height = height + 28
    end
    if typeChecks.profession and typeChecks.profession:GetChecked() then
        height = height + 50
        if ProfessionRoleFromKey(selectedSpecialtyKey) == "supplies" then
            height = height + 28
        end
    end
    scrollChild:SetHeight(math.max(280, height))
end

local function UpdateProfessionControls()
    local profOn = typeChecks.profession and typeChecks.profession:GetChecked()
    if not profRoleBtn then
        return
    end
    if profOn then
        profRoleLabel:Show()
        profRoleBtn:Show()
        local role = ProfessionRoleFromKey(selectedSpecialtyKey)
        if role == "trainer" then
            profRoleBtn:SetText("Role: Trainer")
            profCraftBtn:Hide()
        elseif role == "supplies" then
            profRoleBtn:SetText("Role: Supplies")
            profCraftBtn:Show()
            profCraftBtn:SetText(SpecialtyLabel(selectedSpecialtyKey))
        else
            profRoleBtn:SetText("Role: Auto")
            profCraftBtn:Hide()
        end
    else
        profRoleLabel:Hide()
        profRoleBtn:Hide()
        profCraftBtn:Hide()
    end
    UpdateScrollChildHeight()
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
        specialtyKey = selectedSpecialtyKey,
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
    SyncIconPreview()
    UpdateScrollChildHeight()
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

function ns.GetVendorOverride(npcID)
    if not npcID then
        return nil
    end
    local db = VendorMapOverridesDB
    if type(db) ~= "table" then
        return nil
    end
    return db[npcID] or db[tostring(npcID)]
end

function ns.SetVendorOverride(npcID, override)
    if not npcID then
        return
    end
    local id = tonumber(npcID) or npcID
    local db = EnsureOverrides()
    -- Keep a single numeric key so reload/apply always finds it.
    db[tostring(id)] = nil
    if override == nil then
        db[id] = nil
    else
        db[id] = override
    end
    if ns.Database then
        ns.Database:Rebuild()
    end
    -- Defer refresh a frame so pin sizing runs after the edit dialog finishes hiding
    -- (avoids a bad world-map canvas scale reading while the dialog is still up).
    C_Timer.After(0, function()
        ns.RefreshAll()
    end)
end

local function CollectTypesFromUI()
    local types = {}
    for key, cb in pairs(typeChecks) do
        if cb:GetChecked() then
            types[key] = true
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
    local ov = info.npcID and ns.GetVendorOverride(info.npcID) or nil
    if noteBox then
        noteBox:SetText(info.note or "")
    end
    if subtitleBox then
        subtitleBox:SetText((ov and ov.subtitle) or info.subtitle or "")
    end
    for key, cb in pairs(typeChecks) do
        cb:SetChecked(not not (info.types and info.types[key]))
        cb:SetScript("OnClick", function()
            UpdateProfessionControls()
            SyncIconPreview()
        end)
    end

    selectedSpecialtyKey = (ov and ov.specialtyKey) or info.specialtyKey or "auto"
    if selectedSpecialtyKey == "" or selectedSpecialtyKey == nil then
        selectedSpecialtyKey = "auto"
    end
    -- Infer a useful default from current auto-detection when unset.
    if selectedSpecialtyKey == "auto" and info.types and info.types.profession then
        local detected = ns.GetSpecialtySubtype and ns.GetSpecialtySubtype({
            subtitle = (ov and ov.subtitle) or info.subtitle,
            name = info.name,
            note = info.note,
            types = info.types,
        })
        if detected then
            -- Keep auto; preview still shows craft icon via note/subtitle match.
        elseif info.subtitle and tostring(info.subtitle):lower():find("trainer", 1, true) then
            -- still auto
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
        frame.title:SetText(info.name or "Vendor")
    end
end

local function BuildFrame()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "VendorMapVendorEditFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:Hide()
    tinsert(UISpecialFrames, "VendorMapVendorEditFrame")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 16, -16)
    frame.title:SetWidth(300)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetText("Edit Vendor")

    local sub = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(300)
    sub:SetJustifyH("LEFT")
    sub:SetText("Overrides seed/learned data for this character's SavedVariables.")

    -- Footer buttons stay fixed; form body scrolls above them.
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

    local scroll = CreateFrame("ScrollFrame", "VendorMapVendorEditScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetPoint("BOTTOMRIGHT", -34, 48)

    scrollChild = CreateFrame("Frame", "VendorMapVendorEditScrollChild", scroll)
    scrollChild:SetWidth(300)
    scrollChild:SetHeight(600)
    scroll:SetScrollChild(scrollChild)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 28
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, cur - delta * step)))
    end)

    local content = scrollChild
    local y = -4
    for _, def in ipairs(ns.VENDOR_TYPES) do
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 8, y)
        cb.Text:SetText(def.label)
        typeChecks[def.key] = cb
        y = y - 22
    end

    profRoleLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    profRoleLabel:SetPoint("TOPLEFT", 12, y - 2)
    profRoleLabel:SetText("Profession detail")
    profRoleLabel:Hide()
    y = y - 18

    profRoleBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    profRoleBtn:SetSize(200, 22)
    profRoleBtn:SetPoint("TOPLEFT", 8, y)
    profRoleBtn:SetText("Role: Auto")
    profRoleBtn:Hide()
    profRoleBtn:SetScript("OnClick", function()
        local role = ProfessionRoleFromKey(selectedSpecialtyKey)
        local crafts = ProfessionCraftOptions()
        if role == "auto" then
            selectedSpecialtyKey = "trainer"
        elseif role == "trainer" then
            selectedSpecialtyKey = (crafts[1] and crafts[1].value) or "auto"
        else
            selectedSpecialtyKey = "auto"
        end
        UpdateProfessionControls()
        SyncIconPreview()
    end)
    y = y - 26

    profCraftBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    profCraftBtn:SetSize(240, 22)
    profCraftBtn:SetPoint("TOPLEFT", 8, y)
    profCraftBtn:SetText("Alchemy Supplies")
    profCraftBtn:Hide()
    profCraftBtn:SetScript("OnClick", function()
        local crafts = ProfessionCraftOptions()
        if #crafts == 0 then
            return
        end
        local idx = 1
        for i, opt in ipairs(crafts) do
            if opt.value == selectedSpecialtyKey then
                idx = i
                break
            end
        end
        selectedSpecialtyKey = crafts[(idx % #crafts) + 1].value
        UpdateProfessionControls()
        SyncIconPreview()
    end)
    y = y - 28

    factionBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    factionBtn:SetSize(200, 24)
    factionBtn:SetPoint("TOPLEFT", 8, y - 4)
    factionBtn:SetText("Faction: Neutral")
    factionBtn:SetScript("OnClick", CycleFaction)
    y = y - 36

    hideCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    hideCheck:SetPoint("TOPLEFT", 8, y)
    hideCheck.Text:SetText("Hide this pin")
    y = y - 30

    local iconLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", 8, y)
    iconLabel:SetText("Pin icon")
    y = y - 20

    iconPreview = content:CreateTexture(nil, "ARTWORK")
    iconPreview:SetSize(22, 22)
    iconPreview:SetPoint("TOPLEFT", 10, y)

    iconBrowseBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
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

    iconBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
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
    y = y - 28

    iconCustomLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    iconCustomLabel:SetPoint("TOPLEFT", 8, y)
    iconCustomLabel:SetText("Path / fileID")
    iconCustomLabel:Hide()

    iconCustomBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    iconCustomBox:SetPoint("LEFT", iconCustomLabel, "RIGHT", 8, 0)
    iconCustomBox:SetSize(180, 20)
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
    y = y - 28

    iconHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    iconHint:SetPoint("TOPLEFT", 8, y)
    iconHint:SetWidth(280)
    iconHint:SetJustifyH("LEFT")
    iconHint:SetText("Browse any in-game icon, or opt into a Custom path (Interface\\… or fileID).")
    y = y - 36

    local subtitleLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    subtitleLabel:SetPoint("TOPLEFT", 8, y)
    subtitleLabel:SetText("Subtitle")
    y = y - 18

    subtitleBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    subtitleBox:SetPoint("TOPLEFT", 12, y)
    subtitleBox:SetSize(270, 24)
    subtitleBox:SetAutoFocus(false)
    subtitleBox:SetScript("OnTextChanged", function()
        SyncIconPreview()
    end)
    y = y - 30

    contentBottomY = y

    frame.noteLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.noteLabel:SetPoint("TOPLEFT", 8, y)
    frame.noteLabel:SetText("Note")
    y = y - 18

    noteBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    noteBox:SetPoint("TOPLEFT", 12, y)
    noteBox:SetSize(270, 24)
    noteBox:SetAutoFocus(false)

    UpdateScrollChildHeight()

    saveBtn:SetScript("OnClick", function()
        if not editing or not editing.npcID then
            ns.Print("Cannot override a vendor without npcID.")
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
        local override = {
            types = CollectTypesFromUI(),
            faction = selectedFaction,
            note = noteText,
            subtitle = subtitleText,
            hidden = hideCheck:GetChecked() and true or false,
            name = editing.name,
        }
        if override.types and override.types.profession then
            if selectedSpecialtyKey and selectedSpecialtyKey ~= "auto" then
                override.specialtyKey = selectedSpecialtyKey
            else
                override.specialtyKey = "auto"
            end
        else
            override.specialtyKey = "auto"
        end
        if iconPreset then
            override.iconPreset = iconPreset
        end
        if iconCustom then
            override.iconCustom = iconCustom
        end
        local npcID = editing.npcID
        local label = editing.name or ("npc " .. tostring(npcID))
        frame:Hide()
        ns.SetVendorOverride(npcID, override)
        ns.Print("Saved override for " .. label .. " (applies immediately).")
    end)

    resetBtn:SetScript("OnClick", function()
        if not editing or not editing.npcID then
            return
        end
        local npcID = editing.npcID
        local label = editing.name or ("npc " .. tostring(npcID))
        frame:Hide()
        ns.SetVendorOverride(npcID, nil)
        ns.Print("Cleared override for " .. label)
    end)

    return frame
end

function VendorEdit:Open(info)
    if not info then
        return
    end
    BuildFrame()
    LoadInfoIntoUI(info)
    frame:Show()
    frame:Raise()
end

function ns.OpenVendorEdit(info)
    VendorEdit:Open(info)
end
