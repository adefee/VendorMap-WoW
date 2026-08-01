local _, ns = ...

local UI = ns.SettingsUI

local overrideRows = {}
local listContent
local listScroll
local expandedNpc
local statsLabel

local function CountLearned()
    if type(VendorMapLearnedDB) ~= "table" then
        return 0
    end
    return #VendorMapLearnedDB
end

local function CountOverrides()
    local n = 0
    if type(VendorMapOverridesDB) == "table" then
        for _, ov in pairs(VendorMapOverridesDB) do
            if type(ov) == "table" then
                n = n + 1
            end
        end
    end
    return n
end

local function CollectOverrideEntries()
    local entries = {}
    if type(VendorMapOverridesDB) ~= "table" then
        return entries
    end
    for key, ov in pairs(VendorMapOverridesDB) do
        if type(ov) == "table" then
            local id = tonumber(key) or key
            local vendor = ns.Database and (
                (ns.Database.FindByOverrideKey and ns.Database:FindByOverrideKey(id))
                or ns.Database:FindByNpcID(id)
            )
            local name = (ov.name and ov.name ~= "" and ov.name)
                or (vendor and ((ns.Names and ns.Names:DisplayName(vendor)) or vendor.name))
                or (type(id) == "number" and ("npc " .. tostring(id)))
                or tostring(id)
            entries[#entries + 1] = {
                npcID = id,
                ov = ov,
                name = name,
                vendor = vendor,
            }
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    return entries
end

local function TypesSummary(ov, vendor)
    local info = {
        types = ov.types or (vendor and vendor.types),
        specialtyKey = ov.specialtyKey or (vendor and vendor.specialtyKey),
        subtitle = ov.subtitle or (vendor and vendor.subtitle),
        name = ov.name or (vendor and vendor.name),
        note = ov.note or (vendor and vendor.note),
    }
    if ns.VendorTypeLabelList then
        local label = ns.VendorTypeLabelList(info)
        if label and label ~= "" then
            return label
        end
    end
    if ns.TypeLabelList and info.types then
        return ns.TypeLabelList(info.types)
    end
    return "—"
end

local function RefreshStats()
    if not statsLabel then
        return
    end
    statsLabel:SetText(string.format(
        "Learned visits: %d    Overrides: %d    Indexed vendors: %d",
        CountLearned(),
        CountOverrides(),
        (ns.Database and ns.Database:Count()) or 0
    ))
end

local function ClearOverrideList()
    for _, row in ipairs(overrideRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(overrideRows)
end

local function BuildOverrideRow(parent, entry, y)
    local collapsedH = 28
    local expandedH = 112
    local isExpanded = expandedNpc == entry.npcID
    local height = isExpanded and expandedH or collapsedH

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(560, height)
    row:SetPoint("TOPLEFT", 0, y)
    if row.SetBackdrop then
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(0.08, 0.08, 0.1, 0.85)
        row:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    end

    local header = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    header:SetPoint("TOPLEFT", 10, -6)
    header:SetWidth(420)
    header:SetJustifyH("LEFT")
    local hideMark = entry.ov.hidden and " |cffcc6666(hidden)|r" or ""
    header:SetText(string.format("%s  |cff888888(%s)|r%s", entry.name, tostring(entry.npcID), hideMark))

    local chevron = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chevron:SetPoint("TOPRIGHT", -10, -6)
    chevron:SetText(isExpanded and "▼" or "▶")

    row:SetScript("OnClick", function()
        if expandedNpc == entry.npcID then
            expandedNpc = nil
        else
            expandedNpc = entry.npcID
        end
        ns.RefreshOverrideList()
    end)

    if isExpanded then
        local detail = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        detail:SetPoint("TOPLEFT", 12, -28)
        detail:SetWidth(420)
        detail:SetJustifyH("LEFT")
        local note = entry.ov.note
        if note == "" then
            note = "(empty note)"
        end
        local iconDesc = "Type default"
        if entry.ov.iconPreset and entry.ov.iconPreset ~= "default" then
            if entry.ov.iconPreset == "custom" then
                iconDesc = "Custom: " .. tostring(entry.ov.iconCustom or "—")
            else
                iconDesc = tostring(entry.ov.iconPreset)
            end
        elseif entry.ov.iconCustom and entry.ov.iconCustom ~= "" then
            iconDesc = "Custom: " .. tostring(entry.ov.iconCustom)
        end
        detail:SetText(string.format(
            "Faction: %s\nTypes: %s\nIcon: %s\nNote: %s",
            tostring(entry.ov.faction or (entry.vendor and entry.vendor.faction) or "—"),
            TypesSummary(entry.ov, entry.vendor),
            iconDesc,
            note and tostring(note) or "—"
        ))

        local editBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        editBtn:SetSize(70, 22)
        editBtn:SetPoint("BOTTOMRIGHT", -90, 8)
        editBtn:SetText("Edit")
        editBtn:SetScript("OnClick", function()
            local info = entry.vendor
            if not info then
                local key = entry.npcID
                info = {
                    npcID = type(key) == "number" and key or nil,
                    id = key,
                    name = entry.name,
                    faction = entry.ov.faction or "Neutral",
                    types = entry.ov.types or { general = true },
                    note = entry.ov.note,
                    subtitle = entry.ov.subtitle,
                    specialtyKey = entry.ov.specialtyKey,
                    hidden = entry.ov.hidden,
                    iconPreset = entry.ov.iconPreset,
                    iconCustom = entry.ov.iconCustom,
                }
            end
            if ns.OpenVendorEdit then
                ns.OpenVendorEdit(info)
            end
        end)

        local clearBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        clearBtn:SetSize(70, 22)
        clearBtn:SetPoint("BOTTOMRIGHT", -12, 8)
        clearBtn:SetText("Clear")
        clearBtn:SetScript("OnClick", function()
            if ns.SetVendorOverride then
                ns.SetVendorOverride(entry.npcID, nil)
            end
            if expandedNpc == entry.npcID then
                expandedNpc = nil
            end
            ns.Print("Cleared override for " .. entry.name)
            ns.RefreshOverrideList()
            RefreshStats()
        end)
    end

    overrideRows[#overrideRows + 1] = row
    return height
end

function ns.RefreshOverrideList()
    if not listContent then
        return
    end
    ClearOverrideList()
    local entries = CollectOverrideEntries()
    local y = 0
    if #entries == 0 then
        local holder = CreateFrame("Frame", nil, listContent)
        holder:SetSize(560, 24)
        holder:SetPoint("TOPLEFT", 0, 0)
        local empty = holder:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -4)
        empty:SetText("No overrides yet. Right-click a map pin to edit.")
        overrideRows[1] = holder
        y = -24
    else
        for _, entry in ipairs(entries) do
            local h = BuildOverrideRow(listContent, entry, y)
            y = y - (h + 4)
        end
    end
    listContent:SetHeight(math.max(120, math.abs(y) + 16))
    RefreshStats()
end

function ns.BuildDataSettingsPage(frame)
    local content = frame.content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -8)
    title:SetText("Data Management")

    local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(580)
    sub:SetJustifyH("LEFT")
    sub:SetText("Export learned/override vendors into seed lines, and browse overrides saved in VendorMapOverridesDB.")

    statsLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statsLabel:SetPoint("TOPLEFT", 16, -56)
    statsLabel:SetWidth(580)
    statsLabel:SetJustifyH("LEFT")
    RefreshStats()

    local exportBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    exportBtn:SetSize(220, 26)
    exportBtn:SetPoint("TOPLEFT", 16, -84)
    exportBtn:SetText("Export learned + overrides")
    exportBtn:SetScript("OnClick", function()
        if ns.ExportLearnedSeeds then
            ns.ExportLearnedSeeds()
        else
            ns.Print("Export module not loaded.")
        end
        RefreshStats()
    end)

    local exportHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    exportHint:SetPoint("TOPLEFT", 16, -116)
    exportHint:SetWidth(580)
    exportHint:SetJustifyH("LEFT")
    exportHint:SetText("Opens a copyable window (and clipboard when available). Paste into tools/merge_export_to_seeds.py or a Seed_*.lua. Same as /vm export.")

    local refreshBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    refreshBtn:SetSize(140, 24)
    refreshBtn:SetPoint("TOPLEFT", 250, -84)
    refreshBtn:SetText("Refresh lists")
    refreshBtn:SetScript("OnClick", function()
        if ns.Database and ns.Database.Rebuild then
            ns.Database:Rebuild()
        end
        ns.RefreshOverrideList()
        RefreshStats()
    end)

    local ovTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ovTitle:SetPoint("TOPLEFT", 16, -150)
    ovTitle:SetText("Overrides")

    local ovHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ovHint:SetPoint("TOPLEFT", 16, -170)
    ovHint:SetWidth(580)
    ovHint:SetJustifyH("LEFT")
    ovHint:SetText("Click a row to expand. Edit opens the pin editor; Clear removes the override.")

    listScroll = CreateFrame("ScrollFrame", "VendorMapOverridesListScroll", content, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 16, -198)
    listScroll:SetSize(580, 320)

    listContent = CreateFrame("Frame", "VendorMapOverridesListContent", listScroll)
    listContent:SetWidth(560)
    listContent:SetHeight(320)
    listScroll:SetScrollChild(listContent)

    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 28
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, cur - delta * step)))
    end)

    ns.RefreshOverrideList()
    UI.FinishContentHeight(content, -540)

    -- Refresh list whenever this page is shown
    frame:HookScript("OnShow", function()
        ns.RefreshOverrideList()
    end)
end
