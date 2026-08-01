local _, ns = ...

-- Organic overlap discovery. Pins stay at their exact map positions; when the cursor
-- hovers a pin whose on-screen hitbox intersects nearby pins, we surface those vendors
-- in the tooltip and (on left-click) offer a small picker so waypoint/edit still target
-- a specific NPC. No forced regrouping — visual fidelity of individual pins is preserved.

local Overlap = {}
ns.Overlap = Overlap

-- Partial overlap counts; clear separation does not. Distance between pin centers is
-- compared against the mean pin radius scaled by this factor.
local OVERLAP_THRESHOLD = 0.85
-- Cap listed neighbors so a dense capital hub tooltip stays readable.
local MAX_LIST = 8

--- Feature toggle (VendorMapDB.showOverlapNeighbors, default on).
function Overlap.Enabled()
    local db = ns.GetDB and ns.GetDB()
    if not db then
        return true
    end
    return db.showOverlapNeighbors ~= false
end

--- Build an overlap index from a pin pool. Only pins with a live `.info` are indexed.
-- pool: array of pin frames; count: optional active count (defaults to #pool).
function Overlap.BuildIndex(pool, count)
    local index = {}
    if type(pool) ~= "table" then
        return index
    end
    count = count or #pool
    for i = 1, count do
        local pin = pool[i]
        if pin and pin.info then
            index[#index + 1] = pin
        end
    end
    return index
end

--- Build an overlap index from the minimap's active map ([id] = { pin = ... }).
function Overlap.BuildIndexFromActive(active)
    local index = {}
    if type(active) ~= "table" then
        return index
    end
    for _, data in pairs(active) do
        if data and data.pin and data.pin.info then
            index[#index + 1] = data.pin
        end
    end
    return index
end

--- Pins (excluding `pin`) whose on-screen hitbox intersects the hovered pin.
-- Uses live GetCenter/GetWidth so the test is zoom-invariant (both scale together).
-- Returns a distance-sorted array of { pin, info, dist }.
function Overlap.Neighbors(index, pin, threshold)
    threshold = threshold or OVERLAP_THRESHOLD
    local out = {}
    if type(index) ~= "table" or not pin then
        return out
    end
    local px, py = pin:GetCenter()
    if not px then
        return out
    end
    local pRadius = (pin:GetWidth() or 0) / 2
    for _, other in ipairs(index) do
        if other ~= pin and other.info and other:IsShown() then
            local ox, oy = other:GetCenter()
            if ox then
                local dx = px - ox
                local dy = py - oy
                local dist = math.sqrt(dx * dx + dy * dy)
                local limit = (pRadius + (other:GetWidth() or 0) / 2) * threshold
                if dist <= limit then
                    out[#out + 1] = { pin = other, info = other.info, dist = dist }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        return a.dist < b.dist
    end)
    return out
end

-- Soft highlight applied to overlapping neighbors while a stacked pin is hovered.
local highlighted = {}

local function EnsureNeighborHighlight(pin)
    if pin._vmNeighborHL then
        return pin._vmNeighborHL
    end
    local t = pin:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(pin)
    t:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    t:SetBlendMode("ADD")
    t:SetVertexColor(1, 0.9, 0.35, 0.9)
    t:Hide()
    pin._vmNeighborHL = t
    return t
end

function Overlap.ClearHighlights()
    for i = #highlighted, 1, -1 do
        local t = highlighted[i]
        if t then
            t:Hide()
        end
        highlighted[i] = nil
    end
end

local function HighlightNeighbors(neighbors)
    Overlap.ClearHighlights()
    for _, entry in ipairs(neighbors) do
        local t = EnsureNeighborHighlight(entry.pin)
        t:Show()
        highlighted[#highlighted + 1] = t
    end
end

--- Inline icon markup (atlas or texture/fileID) for a vendor, for menu entries.
local function VendorIconMarkup(info)
    local art
    if ns.ResolveVendorOverrideIconArt then
        art = ns.ResolveVendorOverrideIconArt(info)
    end
    if not art then
        local key = (ns.GetPinDisplayType and ns.GetPinDisplayType(info))
            or (ns.PrimaryVendorType and ns.PrimaryVendorType(info.types))
            or "general"
        if ns.ResolveTypeIconArt then
            art = ns.ResolveTypeIconArt(key)
        end
    end
    if art then
        if art.atlas and CreateAtlasMarkup and C_Texture and C_Texture.GetAtlasInfo
            and C_Texture.GetAtlasInfo(art.atlas) then
            return CreateAtlasMarkup(art.atlas, 16, 16)
        end
        if art.icon then
            return ("|T%s:16:16|t "):format(tostring(art.icon))
        end
    end
    return ""
end

--- Render a single vendor's primary tooltip block (title + details) into `tooltip`.
-- Shared by pin hover and pick-menu entry tooltips so both look identical.
local function VendorTypesText(info)
    if ns.VendorTypeLabelList then
        return ns.VendorTypeLabelList(info)
    end
    if ns.TypeLabelList then
        return ns.TypeLabelList(info.types)
    end
    return ""
end

--- Secondary label beside the name in stack lists: subtitle when present, else categories.
local function VendorListSecondary(info)
    local subtitle = info and info.subtitle
    if type(subtitle) == "string" and subtitle ~= "" then
        return subtitle
    end
    return VendorTypesText(info)
end

local function RenderVendorPrimary(tooltip, info, opts)
    if not tooltip or not info then
        return
    end
    opts = opts or {}
    local name = ns.Names and ns.Names:DisplayName(info) or info.name
    tooltip:SetText(name, 1, 1, 1)
    local role = ns.GetVendorRoleLabel and ns.GetVendorRoleLabel(info)
    local subtitle = info.subtitle
    if type(subtitle) == "string" and subtitle ~= "" then
        tooltip:AddLine(subtitle, 0.75, 0.75, 0.75, true)
    elseif role then
        tooltip:AddLine(role, 0.75, 0.75, 0.75, true)
    end
    local typesText = VendorTypesText(info)
    if typesText ~= "" then
        tooltip:AddLine(typesText, 0.8, 0.8, 0.8, true)
    end
    tooltip:AddLine(info.faction or "Neutral", 0.6, 0.8, 1)
    local repText = ns.Names and ns.Names:RepRequirementText(info)
    if repText then
        tooltip:AddLine(repText, 0.4, 0.9, 0.5, true)
    end
    if info.note then
        tooltip:AddLine(info.note, 1, 0.82, 0, true)
    end
    if opts.showSource then
        local provenance = ns.FormatVendorProvenance and ns.FormatVendorProvenance(info)
            or (info.source == "learned" and "Learned" or "Seed")
        tooltip:AddLine(provenance, 0.5, 0.5, 0.5)
    end
end
ns.Overlap.RenderVendorPrimary = RenderVendorPrimary

--- Set a waypoint for a vendor via its own map + origin coords (Waypoints resolves parents).
function Overlap.WaypointVendor(info, printMsg)
    if not info or not ns.Waypoints then
        return
    end
    local mapID = info.mapID
    local wx = info.originX or info.x
    local wy = info.originY or info.y
    local name = ns.Names and ns.Names:DisplayName(info) or info.name
    local used, ok = ns.Waypoints:Set(mapID, wx, wy, name)
    if ok and printMsg then
        ns.Print(string.format("Waypoint set for %s (%s).", name, used))
    end
end

--- Copy pin info so picker/edit still have a stable row after result buffers recycle.
local function SnapshotVendorInfo(info)
    if not info then
        return nil
    end
    local types = {}
    if type(info.types) == "table" then
        for k, v in pairs(info.types) do
            if v then
                types[k] = true
            end
        end
    end
    return {
        id = info.id,
        npcID = info.npcID,
        name = info.name,
        mapID = info.mapID,
        x = info.x,
        y = info.y,
        originX = info.originX,
        originY = info.originY,
        faction = info.faction,
        types = types,
        note = info.note,
        subtitle = info.subtitle,
        specialtyKey = info.specialtyKey,
        learnedFrom = info.learnedFrom,
        repFactionID = info.repFactionID,
        minStanding = info.minStanding,
        source = info.source,
        hidden = info.hidden,
        iconPreset = info.iconPreset,
        iconCustom = info.iconCustom,
    }
end

-- Forward-declared: OpenVendorEditSoon must dismiss the catcher before the editor opens.
local ClosePicker

local function OpenVendorEditSoon(info)
    local snap = SnapshotVendorInfo(info)
    if not snap or not ns.OpenVendorEdit then
        return
    end
    -- Must kill the fullscreen click-catcher before the editor appears; otherwise it
    -- stays above the dialog and eats every click (including Cancel).
    ClosePicker()
    -- Defer so the opening mouse-up settles on the map/catcher stack.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            ns.OpenVendorEdit(snap)
        end)
    else
        ns.OpenVendorEdit(snap)
    end
end

-- Custom picker: MenuUtil context menus use a dark/low-contrast style that is hard
-- to read on the world map. This panel matches filter-dropdown readability (solid
-- backdrop, white labels) and shows per-row vendor tooltips on hover.
local picker
local pickerRows = {}
local pickerOnPick
local pickerEditMode = false -- true when opened via right-click (both clicks edit)
local pickerTip
local pickerTipLines = {}
local pickerTipOwner
local ROW_H = 24
local PAD = 10
local TIP_PAD = 10
local TIP_MAX_LINES = 12

local function HidePickerTip()
    pickerTipOwner = nil
    if pickerTip then
        pickerTip:Hide()
    end
end

local function EnsurePickerTip()
    if pickerTip then
        return pickerTip
    end
    -- Plain frame tip (not GameTooltip): the world map and tooltip pipeline fight
    -- owned GameTooltips while the cursor isn't on a pin.
    pickerTip = CreateFrame("Frame", "VendorMapOverlapTip", UIParent, "BackdropTemplate")
    pickerTip:SetFrameStrata("TOOLTIP")
    pickerTip:SetFrameLevel(50000)
    pickerTip:SetClampedToScreen(true)
    pickerTip:EnableMouse(false)
    pickerTip:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pickerTip:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
    pickerTip:SetBackdropBorderColor(0.6, 0.6, 0.7, 1)
    pickerTip:Hide()
    return pickerTip
end

local function AcquireTipLine(i, font)
    local fs = pickerTipLines[i]
    if fs then
        return fs
    end
    fs = EnsurePickerTip():CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(260)
    fs:SetWordWrap(true)
    pickerTipLines[i] = fs
    return fs
end

local function ShowPickerRowTooltip(row)
    local info = row and row.info
    if not info then
        return
    end
    local tip = EnsurePickerTip()
    pickerTipOwner = row

    local lines = {}
    local function add(text, r, g, b, font)
        if type(text) ~= "string" or text == "" then
            return
        end
        lines[#lines + 1] = {
            text = text,
            r = r or 1,
            g = g or 1,
            b = b or 1,
            font = font,
        }
    end

    local name = ns.Names and ns.Names:DisplayName(info) or info.name or "Unknown Vendor"
    add(name, 1, 1, 1, "GameFontNormal")
    local role = ns.GetVendorRoleLabel and ns.GetVendorRoleLabel(info)
    if info.subtitle and info.subtitle ~= "" then
        add(info.subtitle, 0.75, 0.75, 0.75)
    elseif role then
        add(role, 0.75, 0.75, 0.75)
    end
    add(VendorTypesText(info), 0.8, 0.8, 0.8)
    add(info.faction or "Neutral", 0.6, 0.8, 1)
    local repText = ns.Names and ns.Names:RepRequirementText(info)
    if repText then
        add(repText, 0.4, 0.9, 0.5)
    end
    if info.note and info.note ~= "" then
        add(info.note, 1, 0.82, 0)
    end
    add(
        (ns.FormatVendorProvenance and ns.FormatVendorProvenance(info))
            or (info.source == "learned" and "Learned" or "Seed"),
        0.5,
        0.5,
        0.5
    )
    if pickerEditMode then
        add("Click: edit vendor", 0.55, 0.55, 0.55)
    else
        add("Left-click: waypoint  ·  Right-click: edit", 0.55, 0.55, 0.55)
    end

    local y = -TIP_PAD
    local width = 160
    local shown = 0
    for i = 1, math.min(#lines, TIP_MAX_LINES) do
        local line = lines[i]
        local fs = AcquireTipLine(i, line.font or "GameFontHighlightSmall")
        if line.font then
            fs:SetFontObject(line.font)
        else
            fs:SetFontObject("GameFontHighlightSmall")
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", TIP_PAD, y)
        fs:SetText(line.text)
        fs:SetTextColor(line.r, line.g, line.b)
        fs:Show()
        local tw = (fs.GetStringWidth and fs:GetStringWidth()) or 120
        local th = (fs.GetStringHeight and fs:GetStringHeight()) or 14
        width = math.max(width, tw)
        y = y - th - 2
        shown = i
    end
    for i = shown + 1, #pickerTipLines do
        pickerTipLines[i]:Hide()
    end

    tip:SetSize(width + TIP_PAD * 2, (-y) + TIP_PAD)
    tip:ClearAllPoints()
    tip:SetPoint("LEFT", row, "RIGHT", 10, 0)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetFrameLevel(50000)
    tip:Show()
    tip:Raise()
end

local function UpdatePickerHoverTip()
    if not picker or not picker:IsShown() then
        return
    end
    local over
    for i = 1, #pickerRows do
        local row = pickerRows[i]
        if row and row:IsShown() and row.info and row:IsMouseOver() then
            over = row
            break
        end
    end
    if over then
        if pickerTipOwner ~= over then
            ShowPickerRowTooltip(over)
        end
        if over.hoverBg then
            over.hoverBg:Show()
        end
        for i = 1, #pickerRows do
            local row = pickerRows[i]
            if row and row.hoverBg and row ~= over then
                row.hoverBg:Hide()
            end
        end
    else
        HidePickerTip()
        for i = 1, #pickerRows do
            local row = pickerRows[i]
            if row and row.hoverBg then
                row.hoverBg:Hide()
            end
        end
    end
end

local pickerOpen = false
local closingPicker = false

--- Reset picker + catcher to fully inert state.
ClosePicker = function()
    if closingPicker then
        return
    end
    closingPicker = true
    pickerOpen = false
    if picker then
        picker:SetScript("OnUpdate", nil)
        if picker.EnableKeyboard then
            picker:EnableKeyboard(false)
        end
        if picker.catcher then
            picker.catcher:EnableMouse(false)
            picker.catcher:Hide()
        end
        picker:Hide()
    end
    pickerOnPick = nil
    pickerEditMode = false
    HidePickerTip()
    closingPicker = false
end

--- Public: dismiss stack picker + click-catcher (edit/override must call this).
function Overlap.ClosePickMenu()
    ClosePicker()
end

local function EnsurePicker()
    if picker then
        return picker
    end
    picker = CreateFrame("Frame", "VendorMapOverlapPicker", UIParent, "BackdropTemplate")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(20000)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(false)
    picker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    picker:SetBackdropColor(0.08, 0.08, 0.12, 0.96)
    picker:SetBackdropBorderColor(0.55, 0.55, 0.65, 1)

    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    picker.title:SetPoint("TOPLEFT", PAD, -PAD)
    picker.title:SetTextColor(1, 0.82, 0)
    picker.title:SetText("Vendors here")

    -- OnHide: inline cleanup only — never call ClosePicker() from here (re-entrant
    -- picker:Hide() inside OnHide corrupts the frame on some WoW builds).
    picker:SetScript("OnHide", function(self)
        pickerOpen = false
        self:SetScript("OnUpdate", nil)
        if self.EnableKeyboard then
            self:EnableKeyboard(false)
        end
        if self.catcher then
            self.catcher:EnableMouse(false)
            self.catcher:Hide()
        end
        pickerOnPick = nil
        pickerEditMode = false
        HidePickerTip()
    end)
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            ClosePicker()
        end
    end)
    if picker.SetPropagateKeyboardInput then
        picker:SetPropagateKeyboardInput(false)
    end

    -- Click-away catcher: lives behind picker rows but above everything else.
    -- Always anchored full-screen; visibility + EnableMouse toggles activation.
    picker.catcher = CreateFrame("Button", nil, UIParent)
    picker.catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    picker.catcher:SetFrameLevel(19999)
    picker.catcher:SetAllPoints(UIParent)
    picker.catcher:EnableMouse(false)
    picker.catcher:Hide()
    picker.catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    picker.catcher:SetScript("OnClick", ClosePicker)
    picker.catcher:SetScript("OnMouseWheel", ClosePicker)

    return picker
end

local function AcquirePickerRow(i)
    local row = pickerRows[i]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, picker)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hoverBg = row:CreateTexture(nil, "BACKGROUND")
    row.hoverBg:SetAllPoints()
    row.hoverBg:SetColorTexture(1, 1, 1, 0.14)
    row.hoverBg:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        ShowPickerRowTooltip(self)
        if self.hoverBg then
            self.hoverBg:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.hoverBg then
            self.hoverBg:Hide()
        end
        if pickerTipOwner == self then
            HidePickerTip()
        end
    end)
    row:SetScript("OnClick", function(self, button)
        local info = self.info
        if not info then
            return
        end
        local snap = SnapshotVendorInfo(info)
        local editMode = pickerEditMode
        local onPick = pickerOnPick

        -- Right-click always edits. Edit-mode list: either click edits.
        -- OpenVendorEditSoon closes the picker/catcher itself.
        if button == "RightButton" or editMode then
            OpenVendorEditSoon(snap)
            return
        end

        ClosePicker()

        -- Waypoint-mode list: left-click runs the open-time callback (set waypoint).
        if onPick then
            onPick(snap)
        else
            Overlap.WaypointVendor(snap, true)
        end
    end)
    pickerRows[i] = row
    return row
end

--- Picker listing every vendor in a stack; choosing one runs onPick(info).
-- opts: { editMode = bool } — when true, left-click also edits (opened via right-click).
function Overlap.OpenPickMenu(owner, vendors, onPick, opts)
    if type(vendors) ~= "table" or #vendors == 0 then
        return
    end
    if #vendors == 1 then
        if onPick then
            onPick(vendors[1])
        end
        return
    end

    -- Tear down any previous picker so we start clean.
    ClosePicker()

    local f = EnsurePicker()
    pickerOnPick = onPick
    pickerEditMode = opts and opts.editMode and true or false

    local width = 260
    local y = -(PAD + 18)
    for i, info in ipairs(vendors) do
        local row = AcquirePickerRow(i)
        row.info = info
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, y)
        row:SetPoint("TOPRIGHT", -PAD, y)
        row:SetFrameLevel(f:GetFrameLevel() + 2)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:Show()

        local name = ns.Names and ns.Names:DisplayName(info) or info.name or "Unknown Vendor"
        local secondary = VendorListSecondary(info)
        if secondary ~= "" then
            row.text:SetText(name .. "  |cff999999" .. secondary .. "|r")
        else
            row.text:SetText(name)
        end
        row.text:SetTextColor(1, 1, 1)

        if ns.SetVendorPinIcon then
            ns.SetVendorPinIcon(row.icon, info)
        elseif ns.SetTypeIcon then
            local key = ns.GetPinDisplayType and ns.GetPinDisplayType(info) or "general"
            ns.SetTypeIcon(row.icon, key, info.faction)
        end
        -- Keep the 18×18 slot (LayoutPinIcon would re-anchor to the wide row).
        row.icon:ClearAllPoints()
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)

        local textWidth = (row.text.GetUnboundedStringWidth and row.text:GetUnboundedStringWidth())
            or (name and #name * 8) or 120
        width = math.max(width, 4 + 18 + 6 + textWidth + PAD * 2 + 8)
        y = y - ROW_H
    end
    for i = #vendors + 1, #pickerRows do
        pickerRows[i].info = nil
        pickerRows[i]:Hide()
    end

    width = math.min(420, math.max(220, width))
    local height = PAD + 18 + (#vendors * ROW_H) + PAD
    f:SetSize(width, height)

    local x, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, cy / scale + 8)

    pickerOpen = true
    f:Show()

    -- Arm click-away catcher one frame later so the opening mouse-up doesn't dismiss.
    local catcher = f.catcher
    catcher:EnableMouse(false)
    catcher:Show()
    C_Timer.After(0, function()
        if not pickerOpen or not picker or not picker:IsShown() then
            return
        end
        if picker.catcher then
            picker.catcher:EnableMouse(true)
        end
    end)

    -- Poll hover: OnEnter is unreliable over the world map / click-catcher stack.
    f:SetScript("OnUpdate", UpdatePickerHoverTip)
    if f.EnableKeyboard then
        f:EnableKeyboard(true)
    end
end

-- Kept for callers that still expect icon markup helpers.
local function VendorMenuLabel(info)
    local name = ns.Names and ns.Names:DisplayName(info) or info.name or "Unknown Vendor"
    local secondary = VendorListSecondary(info)
    local label = VendorIconMarkup(info) .. name
    if secondary and secondary ~= "" then
        label = label .. (" (%s)"):format(secondary)
    end
    return label
end
ns.Overlap.VendorMenuLabel = VendorMenuLabel

local function AppendNearby(tooltip, neighbors)
    tooltip:AddLine(" ")
    tooltip:AddLine(("Nearby (%d):"):format(#neighbors), 0.6, 0.85, 1)
    local shown = 0
    for _, entry in ipairs(neighbors) do
        if shown >= MAX_LIST then
            break
        end
        local ninfo = entry.info
        local nname = ns.Names and ns.Names:DisplayName(ninfo) or ninfo.name
        local secondary = VendorListSecondary(ninfo)
        if secondary and secondary ~= "" then
            tooltip:AddLine(("  %s |cff888888— %s|r"):format(nname, secondary), 0.9, 0.9, 0.9, true)
        else
            tooltip:AddLine(("  %s"):format(nname), 0.9, 0.9, 0.9, true)
        end
        shown = shown + 1
    end
    local remaining = #neighbors - shown
    if remaining > 0 then
        tooltip:AddLine(("  …and %d more"):format(remaining), 0.6, 0.6, 0.6)
    end
end

--- Full hover behavior: tooltip (primary vendor block + Nearby list) and neighbor highlight.
-- opts: { anchor, showSource (bool), hint (string), index }
function Overlap.OnPinEnter(pin, opts)
    local info = pin and pin.info
    if not info then
        return
    end
    opts = opts or {}

    local neighbors
    if opts.index and Overlap.Enabled() then
        neighbors = Overlap.Neighbors(opts.index, pin)
        if #neighbors == 0 then
            neighbors = nil
        end
    end

    GameTooltip:SetOwner(pin, opts.anchor or "ANCHOR_RIGHT")
    RenderVendorPrimary(GameTooltip, info, { showSource = opts.showSource })

    if neighbors then
        AppendNearby(GameTooltip, neighbors)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Left-click|r list (waypoint) · |cffffd100Right-click|r list (edit)", 1, 1, 1)
        HighlightNeighbors(neighbors)
    else
        GameTooltip:AddLine(" ")
        if opts.hint then
            GameTooltip:AddLine(opts.hint, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

function Overlap.OnPinLeave()
    GameTooltip:Hide()
    Overlap.ClearHighlights()
end

--- Full click behavior. Right-click edits the hovered pin. Left-click waypoints the
-- hovered vendor, or opens a picker when the pin overlaps others.
-- opts: { index, printWaypoint (bool) }
function Overlap.HandlePinClick(pin, button, opts)
    local info = pin and pin.info
    if not info then
        return
    end
    opts = opts or {}

    local neighbors
    if opts.index and Overlap.Enabled() then
        neighbors = Overlap.Neighbors(opts.index, pin)
    end

    if button == "RightButton" then
        -- Stacked pins: open the list so edit can target a specific neighbor.
        if neighbors and #neighbors > 0 then
            local vendors = { SnapshotVendorInfo(info) }
            for _, entry in ipairs(neighbors) do
                vendors[#vendors + 1] = SnapshotVendorInfo(entry.info)
            end
            -- editMode: row clicks edit (onPick unused; kept nil on purpose).
            Overlap.OpenPickMenu(pin, vendors, nil, { editMode = true })
            return
        end
        OpenVendorEditSoon(SnapshotVendorInfo(info) or info)
        return
    end

    if neighbors and #neighbors > 0 then
        local vendors = { SnapshotVendorInfo(info) }
        for _, entry in ipairs(neighbors) do
            vendors[#vendors + 1] = SnapshotVendorInfo(entry.info)
        end
        local printWaypoint = opts.printWaypoint
        Overlap.OpenPickMenu(pin, vendors, function(chosen)
            Overlap.WaypointVendor(chosen, printWaypoint)
        end, { editMode = false })
        return
    end

    Overlap.WaypointVendor(info, opts.printWaypoint)
end
