local _, ns = ...

-- Export learned + override vendors as AddSeed lines for offline merge into packs.

local TYPE_ORDER = {
    "repair", "reagents", "food", "poison", "ammo", "mounts", "pets", "stable",
    "transmog", "decor", "profession", "class", "faction", "innkeeper", "barber", "banker",
    "trainingdummy", "general",
}

local exportFrame
local exportBox

local function LuaEscape(s)
    if not s then
        return ""
    end
    return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function FormatTypes(types)
    local bits = {}
    for _, key in ipairs(TYPE_ORDER) do
        if types and types[key] then
            bits[#bits + 1] = key .. "=true"
        end
    end
    if #bits == 0 then
        bits[1] = "general=true"
    end
    return "{" .. table.concat(bits, ", ") .. "}"
end

local function FormatSeedLine(v)
    local name = LuaEscape(v.name or ("Vendor " .. tostring(v.npcID or "?")))
    local types = FormatTypes(v.types)
    local extras = ""
    if v.repFactionID then
        extras = extras .. ", repFactionID=" .. tostring(v.repFactionID)
    end
    if v.minStanding then
        extras = extras .. ", minStanding=" .. tostring(v.minStanding)
    end
    -- Seed/export fields for display model (not runtime provenance).
    local subtitle = LuaEscape(v.subtitle or "")
    if subtitle ~= "" then
        extras = extras .. ', subtitle="' .. subtitle .. '"'
    end
    local specialty = v.specialtyKey
    if type(specialty) == "string" and specialty ~= "" and specialty ~= "auto" then
        extras = extras .. ', specialtyKey="' .. LuaEscape(specialty) .. '"'
    end
    -- Never export legacy "Learned from …" notes; that belongs in learnedFrom.
    local note = v.note
    if ns.ParseLegacyLearnNote and ns.ParseLegacyLearnNote(note) then
        note = nil
    end
    local notePart = ""
    if type(note) == "string" and note ~= "" then
        notePart = ', note="' .. LuaEscape(note) .. '"'
    end
    local npc = v.npcID and (", npcID=" .. tostring(v.npcID)) or ""
    return string.format(
        'A{ name="%s"%s, mapID=%d, x=%.4f, y=%.4f, faction="%s", types=%s%s%s }',
        name,
        npc,
        v.mapID,
        v.x or 0,
        v.y or 0,
        v.faction or "Neutral",
        types,
        extras,
        notePart
    )
end

local function CollectExportRows()
    local byNpc = {}
    local index = ns.Database:GetIndexByMap()
    for _, list in pairs(index) do
        for _, v in ipairs(list) do
            if v.npcID and (v.source == "learned" or v.source == "override") then
                byNpc[v.npcID] = v
            end
        end
    end

    -- Also include overrides that only change types on seed rows.
    if type(VendorMapOverridesDB) == "table" then
        for npcID, _ in pairs(VendorMapOverridesDB) do
            local id = tonumber(npcID) or npcID
            local v = ns.Database:FindByNpcID(id)
            if v then
                byNpc[id] = v
            end
        end
    end

    if type(VendorMapLearnedDB) == "table" then
        for _, raw in ipairs(VendorMapLearnedDB) do
            if raw.npcID then
                local v = ns.Database:FindByNpcID(raw.npcID)
                if v then
                    byNpc[raw.npcID] = v
                end
            end
        end
    end

    local rows = {}
    for _, v in pairs(byNpc) do
        if v.mapID and v.x and v.y and not v.hidden then
            rows[#rows + 1] = v
        end
    end
    table.sort(rows, function(a, b)
        if a.mapID ~= b.mapID then
            return (a.mapID or 0) < (b.mapID or 0)
        end
        return (a.npcID or 0) < (b.npcID or 0)
    end)
    return rows
end

local function BuildExportText()
    local rows = CollectExportRows()
    local lines = {
        "-- VendorMap export (" .. date("%Y-%m-%d %H:%M") .. ")",
        "-- Paste into tools/merge_export_to_seeds.py or a Seed_*.lua file.",
        "-- You can also share or submit this data with the addon author to improve data for everyone!",
        "local _, ns = ...",
        "local A = ns.AddSeed",
        "",
    }
    for _, v in ipairs(rows) do
        lines[#lines + 1] = FormatSeedLine(v)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("-- %d vendors", #rows)
    return table.concat(lines, "\n"), #rows
end

local function ShowExportUI(text)
    if not exportFrame then
        exportFrame = CreateFrame("Frame", "VendorMapExportFrame", UIParent, "BackdropTemplate")
        exportFrame:SetSize(560, 420)
        exportFrame:SetPoint("CENTER")
        exportFrame:SetFrameStrata("DIALOG")
        exportFrame:SetMovable(true)
        exportFrame:EnableMouse(true)
        exportFrame:RegisterForDrag("LeftButton")
        exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
        exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
        exportFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        tinsert(UISpecialFrames, "VendorMapExportFrame")

        local close = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local title = exportFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("VendorMap Export")

        local scroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -40)
        scroll:SetPoint("BOTTOMRIGHT", -36, 48)

        exportBox = CreateFrame("EditBox", nil, scroll)
        exportBox:SetMultiLine(true)
        exportBox:SetFontObject(GameFontHighlightSmall)
        exportBox:SetWidth(500)
        exportBox:SetAutoFocus(false)
        scroll:SetScrollChild(exportBox)

        local copyBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
        copyBtn:SetSize(120, 24)
        copyBtn:SetPoint("BOTTOMLEFT", 16, 14)
        copyBtn:SetText("Select All")
        copyBtn:SetScript("OnClick", function()
            exportBox:SetFocus()
            exportBox:HighlightText()
        end)
    end
    exportBox:SetText(text)
    exportFrame:Show()
    exportFrame:Raise()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

function ns.ExportLearnedSeeds()
    local text, count = BuildExportText()
    if C_Clipboard and C_Clipboard.SetClipboardText then
        pcall(C_Clipboard.SetClipboardText, text)
        ns.Print(string.format("Exported %d vendors to clipboard (also shown in window).", count))
    else
        ns.Print(string.format("Exported %d vendors — copy from the window (Ctrl+C).", count))
    end
    ShowExportUI(text)
end
