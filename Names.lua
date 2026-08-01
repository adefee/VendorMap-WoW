local _, ns = ...

-- Fallback name resolution for seed rows still missing a real name, plus learned NPCs.
-- Preferred path: names are baked into Seed_*.lua at extract time (no ATT runtime needed).
-- Persists successful lookups in VendorMapDB.npcNames across sessions.

local Names = {}
ns.Names = Names

local memory = {} -- session cache [npcID] = name
local pending = {} -- [npcID] = true while awaiting a non-retrieving result
local retries = {} -- [npcID] = attempts
local MAX_RETRY = 40

local STANDING_BY_INDEX = {
    [1] = "Hated",
    [2] = "Hostile",
    [3] = "Unfriendly",
    [4] = "Neutral",
    [5] = "Friendly",
    [6] = "Honored",
    [7] = "Revered",
    [8] = "Exalted",
}

local STANDING_BY_AMOUNT = {
    [3000] = "Friendly",
    [9000] = "Honored",
    [21000] = "Revered",
    [42000] = "Exalted",
}

local function IsRetrieving(text)
    if not text or text == "" then
        return true
    end
    if RETRIEVING_ITEM_INFO and text == RETRIEVING_ITEM_INFO then
        return true
    end
    if type(text) == "string" and text:find("Retrieving", 1, true) then
        return true
    end
    return false
end

local function IsSecret(value)
    return issecretvalue and value ~= nil and issecretvalue(value)
end

local function PersistCache()
    if type(VendorMapDB) ~= "table" then
        return
    end
    VendorMapDB.npcNames = VendorMapDB.npcNames or {}
end

local function CachedName(npcID)
    if memory[npcID] then
        return memory[npcID]
    end
    PersistCache()
    local saved = VendorMapDB and VendorMapDB.npcNames and VendorMapDB.npcNames[npcID]
    if type(saved) == "string" and saved ~= "" and not IsRetrieving(saved) then
        memory[npcID] = saved
        return saved
    end
    return nil
end

local function StoreName(npcID, name)
    if not npcID or not name or IsRetrieving(name) or IsSecret(name) then
        return
    end
    -- Ignore placeholder fallbacks we may have written earlier
    if name:match("^Vendor %d+$") then
        return
    end
    memory[npcID] = name
    PersistCache()
    if type(VendorMapDB) == "table" then
        VendorMapDB.npcNames = VendorMapDB.npcNames or {}
        VendorMapDB.npcNames[npcID] = name
    end
    pending[npcID] = nil
    retries[npcID] = nil
end

--- Best-effort fetch; may return nil while client data is still loading.
function Names:Lookup(npcID)
    npcID = tonumber(npcID)
    if not npcID or npcID <= 0 then
        return nil
    end

    local cached = CachedName(npcID)
    if cached then
        return cached
    end

    if retries[npcID] and retries[npcID] > MAX_RETRY then
        return nil
    end

    pending[npcID] = true
    local title
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, tooltipData = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
        if ok and tooltipData then
            if ns.SurfaceTooltipData then
                ns.SurfaceTooltipData(tooltipData)
            end
            if tooltipData.lines and tooltipData.lines[1] then
                title = tooltipData.lines[1].leftText
            end
        end
    end

    if title and not IsSecret(title) and not IsRetrieving(title) then
        StoreName(npcID, title)
        return title
    end

    retries[npcID] = (retries[npcID] or 0) + 1
    return nil
end

--- Display name for a vendor/pin info table. Updates info.name when resolved.
function Names:DisplayName(info)
    if not info then
        return "Unknown Vendor"
    end
    local npcID = info.npcID
    if npcID then
        local resolved = self:Lookup(npcID)
        if resolved then
            info.name = resolved
            return resolved
        end
    end
    if type(info.name) == "string" and info.name ~= "" then
        return info.name
    end
    -- Location markers / failed lookups: recover a useful label from subtitle.
    if ns.IsAuctionHouseName and ns.IsAuctionHouseName(info.subtitle) then
        info.name = "Auctioneer"
        return info.name
    end
    if type(info.subtitle) == "string" and info.subtitle ~= "" then
        return info.subtitle
    end
    if npcID then
        return ("Vendor %d"):format(npcID)
    end
    return "Unknown Vendor"
end

--- Prefetch names for a list of pin infos (non-blocking; retries on later calls).
function Names:Prefetch(list)
    if type(list) ~= "table" then
        return
    end
    local changed = false
    for _, info in ipairs(list) do
        if info and info.npcID then
            local before = info.name
            local name = self:DisplayName(info)
            if name and name ~= before and not name:match("^Vendor %d+$") then
                changed = true
            end
        end
    end
    return changed
end

function Names:StandingLabel(minStanding)
    if not minStanding then
        return nil
    end
    return STANDING_BY_INDEX[minStanding]
        or STANDING_BY_AMOUNT[minStanding]
        or (minStanding <= 100 and ("Standing %d"):format(minStanding))
        or nil
end

function Names:RepFactionName(repFactionID)
    repFactionID = tonumber(repFactionID)
    if not repFactionID then
        return nil
    end
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, repFactionID)
        if ok and data and data.name then
            return data.name
        end
    end
    if GetFactionInfoByID then
        local name = GetFactionInfoByID(repFactionID)
        if name then
            return name
        end
    end
    return ("Faction %d"):format(repFactionID)
end

--- Tooltip line for reputation requirements, or nil.
function Names:RepRequirementText(info)
    if not info or not info.repFactionID then
        return nil
    end
    local factionName = self:RepFactionName(info.repFactionID)
    local standing = self:StandingLabel(info.minStanding)
    if standing then
        return ("%s — %s"):format(factionName, standing)
    end
    return factionName
end
