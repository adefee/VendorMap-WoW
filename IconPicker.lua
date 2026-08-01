local _, ns = ...

-- Searchable modal browser of in-game macro/item icons (fileDataIDs).
-- Virtualized grid: only COLS*(VISIBLE_ROWS+2) cell frames; textures update on scroll.
-- Icon ID list is built in chunks across frames so opening never freezes the client.

local COLS = 8
local CELL = 36
local PAD = 4
local VISIBLE_ROWS = 8
local POOL_ROWS = VISIBLE_ROWS + 2
local ROW_H = CELL + PAD
local BUILD_CHUNK = 2500
local SEARCH_DEBOUNCE = 0.12

local picker
local allIcons = {}
local listReady = false
local listBuilding = false
local filtered = {}
local filterActive = false
local onPick
local selectedID
local searchBox
local scrollFrame
local scrollChild
local cells = {}
local statusText
local searchTicker
local scrollOffset = 0
local refreshing = false

local FALLBACK_ICONS = {
    "Interface\\Minimap\\Tracking\\Repair",
    "Interface\\Minimap\\Tracking\\Food",
    "Interface\\Minimap\\Tracking\\Reagents",
    "Interface\\Minimap\\Tracking\\Profession",
    "Interface\\Minimap\\Tracking\\Innkeeper",
    "Interface\\Minimap\\Tracking\\StableMaster",
    "Interface\\Minimap\\Tracking\\Auctioneer",
    651575,
    "Interface\\Icons\\Trade_Alchemy",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\Trade_BlackSmithing",
    "Interface\\Icons\\Trade_Engraving",
    "Interface\\Icons\\Trade_LeatherWorking",
    "Interface\\Icons\\Trade_Tailoring",
    "Interface\\Icons\\INV_Inscription_Tradeskill01",
    "Interface\\Icons\\INV_Misc_Gem_01",
    "Interface\\Icons\\Trade_Fishing",
    "Interface\\Icons\\Trade_Herbalism",
    "Interface\\Icons\\Trade_Mining",
    "Interface\\Icons\\INV_Misc_Bag_10",
}

local function DataList()
    if filterActive then
        return filtered
    end
    return allIcons
end

local function DataCount()
    return #DataList()
end

local function UpdateStatus()
    if not statusText then
        return
    end
    if listBuilding and not listReady then
        statusText:SetText(string.format("Loading… %d", #allIcons))
    else
        statusText:SetText(string.format("%d icons", DataCount()))
    end
end

local function HighlightSelection()
    for _, cell in ipairs(cells) do
        if cell.hl then
            if cell.iconID ~= nil and cell.iconID == selectedID then
                cell.hl:Show()
            else
                cell.hl:Hide()
            end
        end
    end
end

local function RefreshVisibleCells()
    if not scrollFrame or not scrollChild then
        return
    end
    if refreshing then
        return
    end
    refreshing = true

    local list = DataList()
    local total = #list
    local totalRows = math.max(1, math.ceil(math.max(total, 1) / COLS))
    local contentH = totalRows * ROW_H + PAD
    local viewH = VISIBLE_ROWS * ROW_H
    scrollChild:SetHeight(math.max(contentH, viewH))

    local maxScroll = math.max(0, contentH - viewH)
    if scrollOffset > maxScroll then
        scrollOffset = maxScroll
    elseif scrollOffset < 0 then
        scrollOffset = 0
    end

    local current = scrollFrame:GetVerticalScroll() or 0
    if math.abs(current - scrollOffset) > 0.5 then
        scrollFrame:SetVerticalScroll(scrollOffset)
    end

    local firstRow = math.floor(scrollOffset / ROW_H)
    if firstRow < 0 then
        firstRow = 0
    end

    for i, cell in ipairs(cells) do
        local row = firstRow + math.floor((i - 1) / COLS)
        local col = (i - 1) % COLS
        local index = row * COLS + col + 1
        local id = list[index]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", PAD + col * (CELL + PAD), -(PAD + row * ROW_H))
        if id then
            if cell.iconID ~= id then
                cell.iconID = id
                cell.tex:SetTexture(id)
            end
            cell:Show()
            if id == selectedID then
                cell.hl:Show()
            else
                cell.hl:Hide()
            end
        else
            cell.iconID = nil
            cell:Hide()
        end
    end

    UpdateStatus()
    refreshing = false
end

local function EnsureCellPool()
    local need = COLS * POOL_ROWS
    for i = #cells + 1, need do
        local cell = CreateFrame("Button", nil, scrollChild)
        cell:SetSize(CELL, CELL)
        cell.tex = cell:CreateTexture(nil, "ARTWORK")
        cell.tex:SetAllPoints()
        cell.hl = cell:CreateTexture(nil, "OVERLAY")
        cell.hl:SetAllPoints()
        cell.hl:SetColorTexture(1, 1, 0, 0.35)
        cell.hl:Hide()
        cell:SetScript("OnClick", function(self)
            selectedID = self.iconID
            HighlightSelection()
        end)
        cell:SetScript("OnDoubleClick", function(self)
            if self.iconID ~= nil and onPick then
                onPick(self.iconID)
                picker:Hide()
            end
        end)
        cell:SetScript("OnEnter", function(self)
            if not self.iconID then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(self.iconID), 1, 1, 1)
            GameTooltip:AddLine("Click to select · Double-click to apply", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        cells[i] = cell
    end
end

local function SeedQuickIcons(into, seen)
    for _, path in ipairs(FALLBACK_ICONS) do
        if not seen[path] then
            seen[path] = true
            into[#into + 1] = path
        end
    end
end

local function FinishListBuild()
    listBuilding = false
    listReady = true
    if #allIcons == 0 then
        SeedQuickIcons(allIcons, {})
    end
    UpdateStatus()
    if not filterActive then
        RefreshVisibleCells()
    end
end

local function BuildIconListChunked()
    if listReady or listBuilding then
        return
    end
    listBuilding = true

    -- Defer macro icon APIs across frames — each can fill many thousands of IDs.
    C_Timer.After(0, function()
        if not picker or not picker:IsShown() then
            listBuilding = false
            return
        end

        local spellList, itemList = {}, {}
        if GetMacroIcons then
            pcall(GetMacroIcons, spellList)
        end
        UpdateStatus()

        C_Timer.After(0, function()
            if not picker or not picker:IsShown() then
                listBuilding = false
                return
            end
            if GetMacroItemIcons then
                pcall(GetMacroItemIcons, itemList)
            end

            local seen = {}
            for i = 1, #allIcons do
                seen[allIcons[i]] = true
            end

            local sources = { spellList, itemList }
            local srcIndex, srcPos = 1, 1

            local function step()
                if not picker or not picker:IsShown() then
                    listBuilding = false
                    return
                end

                local budget = BUILD_CHUNK
                while budget > 0 and srcIndex <= #sources do
                    local src = sources[srcIndex]
                    local id = src[srcPos]
                    if id == nil then
                        srcIndex = srcIndex + 1
                        srcPos = 1
                    else
                        srcPos = srcPos + 1
                        local n = tonumber(id) or id
                        if not seen[n] then
                            seen[n] = true
                            allIcons[#allIcons + 1] = n
                            budget = budget - 1
                        end
                    end
                end

                UpdateStatus()
                if not filterActive then
                    RefreshVisibleCells()
                end

                if srcIndex > #sources then
                    FinishListBuild()
                    return
                end
                C_Timer.After(0, step)
            end

            step()
        end)
    end)
end

local function ApplyFilter(query)
    query = (query or ""):match("^%s*(.-)%s*$") or ""
    local qLower = strlower(query)
    local asNumber = tonumber(query)

    if query == "" then
        filterActive = false
        wipe(filtered)
        scrollOffset = 0
        RefreshVisibleCells()
        return
    end

    filterActive = true
    wipe(filtered)

    for i = 1, #allIcons do
        local id = allIcons[i]
        if asNumber and id == asNumber then
            filtered[#filtered + 1] = id
        elseif type(id) == "string" and strlower(id):find(qLower, 1, true) then
            filtered[#filtered + 1] = id
        elseif type(id) == "number" and tostring(id):find(query, 1, true) then
            filtered[#filtered + 1] = id
        end
    end

    if asNumber and #filtered == 0 then
        filtered[1] = asNumber
    end

    scrollOffset = 0
    RefreshVisibleCells()
end

local function ScheduleFilter(query)
    if searchTicker then
        searchTicker:Cancel()
        searchTicker = nil
    end
    searchTicker = C_Timer.NewTimer(SEARCH_DEBOUNCE, function()
        searchTicker = nil
        ApplyFilter(query)
    end)
end

local function EnsurePicker()
    if picker then
        return picker
    end

    local width = COLS * (CELL + PAD) + 40
    local height = VISIBLE_ROWS * ROW_H + 110

    picker = CreateFrame("Frame", "VendorMapIconPicker", UIParent, "BackdropTemplate")
    picker:SetSize(width, height)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:SetToplevel(true)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    picker:Hide()
    tinsert(UISpecialFrames, "VendorMapIconPicker")

    local title = picker:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Choose icon")

    searchBox = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    searchBox:SetSize(220, 20)
    searchBox:SetPoint("TOPLEFT", 20, -42)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput == false then
            ApplyFilter(self:GetText())
            return
        end
        ScheduleFilter(self:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if searchTicker then
            searchTicker:Cancel()
            searchTicker = nil
        end
        ApplyFilter(self:GetText())
    end)

    statusText = picker:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusText:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)

    local hint = picker:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 20, -64)
    hint:SetWidth(width - 40)
    hint:SetJustifyH("LEFT")
    hint:SetText("Scroll to browse · search by fileID · Custom path accepts Interface\\… or fileID.")

    scrollFrame = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -82)
    scrollFrame:SetPoint("BOTTOMRIGHT", -36, 44)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        scrollOffset = scrollOffset - delta * ROW_H * 2
        RefreshVisibleCells()
    end)
    scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
        if refreshing then
            return
        end
        scrollOffset = offset or 0
        RefreshVisibleCells()
    end)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(COLS * (CELL + PAD) + PAD, VISIBLE_ROWS * ROW_H)
    scrollFrame:SetScrollChild(scrollChild)
    EnsureCellPool()

    local cancelBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 22)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        picker:Hide()
    end)

    local okBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    okBtn:SetSize(90, 22)
    okBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -8, 0)
    okBtn:SetText("Select")
    okBtn:SetScript("OnClick", function()
        if selectedID ~= nil and onPick then
            onPick(selectedID)
        end
        picker:Hide()
    end)

    local defaultBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    defaultBtn:SetSize(110, 22)
    defaultBtn:SetPoint("BOTTOMLEFT", 20, 16)
    defaultBtn:SetText("Use default")
    defaultBtn:SetScript("OnClick", function()
        if onPick then
            onPick(nil)
        end
        picker:Hide()
    end)

    picker:SetScript("OnHide", function()
        if searchTicker then
            searchTicker:Cancel()
            searchTicker = nil
        end
    end)

    return picker
end

--- Open the icon browser. callback(iconOrNil) — nil means reset to default.
function ns.OpenIconPicker(callback, current)
    EnsurePicker()
    onPick = callback
    selectedID = current and (tonumber(current) or current) or nil
    scrollOffset = 0
    filterActive = false
    wipe(filtered)
    searchBox:SetText("")
    picker:Show()
    EnsureCellPool()

    if listReady then
        RefreshVisibleCells()
    elseif listBuilding then
        RefreshVisibleCells()
    else
        -- Quick curated icons first, then stream the full macro/item set.
        wipe(allIcons)
        SeedQuickIcons(allIcons, {})
        RefreshVisibleCells()
        BuildIconListChunked()
    end
    searchBox:SetFocus()
end
