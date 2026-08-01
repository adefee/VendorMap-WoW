local _, ns = ...

-- Curated pin icon presets. "default" uses each type's built-in art from Constants.
-- "custom" reads VendorMapDB.typeIconCustom[typeKey] (texture path or fileID string).

ns.ICON_PRESETS = {
    { id = "default",       label = "Default (built-in)" },
    { id = "repair",        label = "Repair",            icon = "Interface\\Minimap\\Tracking\\Repair" },
    { id = "reagents",      label = "Reagents",          icon = "Interface\\Minimap\\Tracking\\Reagents" },
    { id = "food",          label = "Food & Drink",      icon = "Interface\\Minimap\\Tracking\\Food" },
    { id = "poison",        label = "Poisons",           icon = "Interface\\Minimap\\Tracking\\Poisons" },
    { id = "ammo",          label = "Ammunition",        icon = "Interface\\Minimap\\Tracking\\Ammunition" },
    { id = "stable",        label = "Stable Master",     icon = "Interface\\Minimap\\Tracking\\StableMaster" },
    { id = "pets",          label = "Pets",              icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "profession",    label = "Profession",        icon = "Interface\\Minimap\\Tracking\\Profession" },
    { id = "innkeeper",     label = "Innkeeper",         icon = "Interface\\Minimap\\Tracking\\Innkeeper" },
    { id = "barber",        label = "Barber",            icon = "Interface\\Minimap\\Tracking\\Barber" },
    { id = "transmog",      label = "Transmog",          icon = "Interface\\Minimap\\Tracking\\Transmogrifier", atlas = "poi-transmogrifier" },
    { id = "auctioneer",    label = "Auctioneer",        icon = "Interface\\Minimap\\Tracking\\Auctioneer" },
    -- Legacy preset id kept so saved typeIconPreset.petsupplies still resolves.
    { id = "petsupplies",   label = "Pets (legacy)",     icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "banker",        label = "Banker",            icon = "Interface\\Minimap\\Tracking\\Banker" },
    { id = "trainingdummy", label = "Training Dummy",    icon = "Interface\\Minimap\\Tracking\\BattleMaster" },
    { id = "vendor_gossip", label = "Vendor (gossip)",   icon = "Interface\\GossipFrame\\VendorGossipIcon" },
    { id = "bag",           label = "Bag (item icon)",  icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { id = "mount",         label = "Mount",             icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { id = "decor",         label = "Decor / Housing",   icon = "Interface\\Icons\\Garrison_Building_Storehouse" },
    { id = "tabard",        label = "Tabard",            icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
    { id = "pastry",        label = "Cake / Pastry",     icon = 651575 },
    { id = "custom",        label = "Custom path…" },
}

ns.ICON_PRESET_BY_ID = {}
for _, p in ipairs(ns.ICON_PRESETS) do
    ns.ICON_PRESET_BY_ID[p.id] = p
end

-- Display subtype / specialty keys that can also pick an icon.
ns.ICON_EXTRA_TARGETS = {}
do
    for _, sub in ipairs(ns.GENERAL_SUBTYPES or {}) do
        ns.ICON_EXTRA_TARGETS[#ns.ICON_EXTRA_TARGETS + 1] = sub
    end
    for _, sub in ipairs(ns.SPECIALTY_SUBTYPES or {}) do
        ns.ICON_EXTRA_TARGETS[#ns.ICON_EXTRA_TARGETS + 1] = sub
    end
end

local function DisplaySubtypeByKey(typeKey)
    for _, sub in ipairs(ns.GENERAL_SUBTYPES or {}) do
        if sub.key == typeKey then
            return sub
        end
    end
    if ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[typeKey] then
        return ns.SPECIALTY_BY_KEY[typeKey]
    end
    return nil
end
ns.GeneralSubtypeByKey = DisplaySubtypeByKey
ns.DisplaySubtypeByKey = DisplaySubtypeByKey

local function EnsureIconDB()
    local db = ns.GetDB and ns.GetDB()
    if not db then
        return nil
    end
    db.typeIconPreset = db.typeIconPreset or {}
    db.typeIconCustom = db.typeIconCustom or {}
    return db
end

function ns.GetTypeIconPreset(typeKey)
    local db = EnsureIconDB()
    if not db or not typeKey then
        return "default"
    end
    local id = db.typeIconPreset[typeKey]
    if id and ns.ICON_PRESET_BY_ID[id] then
        return id
    end
    return "default"
end

function ns.SetTypeIconPreset(typeKey, presetId)
    local db = EnsureIconDB()
    if not db or not typeKey then
        return
    end
    if not ns.ICON_PRESET_BY_ID[presetId] then
        presetId = "default"
    end
    db.typeIconPreset[typeKey] = presetId
end

function ns.GetTypeIconCustomPath(typeKey)
    local db = EnsureIconDB()
    if not db or not typeKey then
        return ""
    end
    return db.typeIconCustom[typeKey] or ""
end

function ns.SetTypeIconCustomPath(typeKey, path)
    local db = EnsureIconDB()
    if not db or not typeKey then
        return
    end
    if type(path) ~= "string" then
        path = ""
    end
    path = path:match("^%s*(.-)%s*$") or ""
    if path == "" then
        db.typeIconCustom[typeKey] = nil
    else
        db.typeIconCustom[typeKey] = path
    end
end

--- Resolve texture/atlas for a type (or display) key.
-- Returns { icon=, atlas=, isDefault=bool }
function ns.ResolveTypeIconArt(typeKey)
    local def = ns.TYPE_BY_KEY[typeKey]
    local fallbackIcon = def and def.icon
    local fallbackAtlas = def and def.atlas
    local subtype = DisplaySubtypeByKey(typeKey)
    if subtype then
        fallbackIcon = subtype.fallbackIcon or fallbackIcon
        fallbackAtlas = nil
    end

    local presetId = ns.GetTypeIconPreset(typeKey)
    if presetId == "custom" then
        local path = ns.GetTypeIconCustomPath(typeKey)
        if path ~= "" then
            local asNumber = tonumber(path)
            return { icon = asNumber or path, atlas = nil, isDefault = false }
        end
    elseif presetId ~= "default" then
        local p = ns.ICON_PRESET_BY_ID[presetId]
        if p and (p.icon or p.atlas) then
            return { icon = p.icon, atlas = p.atlas, isDefault = false }
        end
    end

    return { icon = fallbackIcon, atlas = fallbackAtlas, isDefault = true }
end

-- Item icons (Interface\Icons / fileIDs) fill their square more than Minimap\Tracking
-- art, so they read larger at the same pin size. Inset them slightly for parity.
local ITEM_ICON_INSET = 0.12

local function IsItemIconSource(icon)
    if type(icon) == "number" then
        return true
    end
    if type(icon) ~= "string" then
        return false
    end
    local lower = icon:lower()
    return lower:find("interface\\icons\\", 1, true)
        or lower:find("interface/icons/", 1, true)
        or false
end

local function ReadTextureFileSize(texture)
    if not texture then
        return nil, nil
    end
    if texture.GetTextureFileWidth and texture.GetTextureFileHeight then
        local ok, w, h = pcall(function()
            return texture:GetTextureFileWidth(), texture:GetTextureFileHeight()
        end)
        if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
            return w, h
        end
    end
    return nil, nil
end

--- Lay out pin art inside its parent so square item icons and non-square gossip/atlas
-- art share a comparable visual weight. Call after the pin frame has its final size.
function ns.LayoutPinIcon(texture)
    if not texture then
        return
    end
    local parent = texture.GetParent and texture:GetParent()
    if not parent then
        return
    end
    local pw = parent.GetWidth and parent:GetWidth() or 0
    local ph = parent.GetHeight and parent:GetHeight() or 0
    if pw <= 0 or ph <= 0 then
        return
    end

    if texture.SetTexCoord then
        texture:SetTexCoord(0, 1, 0, 1)
    end

    local srcW = texture._vmIconW
    local srcH = texture._vmIconH
    local kind = texture._vmIconKind

    texture:ClearAllPoints()

    if kind == "item" then
        local insetX = pw * ITEM_ICON_INSET
        local insetY = ph * ITEM_ICON_INSET
        texture:SetPoint("TOPLEFT", parent, "TOPLEFT", insetX, -insetY)
        texture:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insetX, insetY)
        return
    end

    if srcW and srcH and srcW > 0 and srcH > 0 and math.abs(srcW - srcH) > 0.5 then
        local aspect = srcW / srcH
        local tw, th
        if aspect > 1 then
            tw = pw
            th = pw / aspect
        else
            th = ph
            tw = ph * aspect
        end
        texture:SetSize(tw, th)
        texture:SetPoint("CENTER", parent, "CENTER")
        return
    end

    texture:SetAllPoints(parent)
end

local function ApplyArt(texture, art)
    if not texture or not art then
        return
    end

    texture._vmIconW = nil
    texture._vmIconH = nil
    texture._vmIconKind = "other"

    if texture.SetTexCoord then
        texture:SetTexCoord(0, 1, 0, 1)
    end

    if art.atlas and C_Texture and C_Texture.GetAtlasInfo then
        local info = C_Texture.GetAtlasInfo(art.atlas)
        if info then
            -- useAtlasSize=false: fill our region; pin renderers call LayoutPinIcon.
            texture:SetAtlas(art.atlas, false)
            texture._vmIconW = info.width
            texture._vmIconH = info.height
            texture._vmIconKind = "atlas"
            return
        end
    end

    if art.icon then
        -- Clear atlas/prior art so pooled pins don't keep a previous skillbook, etc.
        pcall(texture.SetTexture, texture, 0)
        texture:SetTexture(art.icon)
        local w, h = ReadTextureFileSize(texture)
        texture._vmIconW = w
        texture._vmIconH = h
        texture._vmIconKind = IsItemIconSource(art.icon) and "item" or "other"
        return
    end

    texture:SetTexture("Interface\\Minimap\\Tracking\\None")
    texture._vmIconKind = "other"
end

ns.ApplyIconArt = ApplyArt

--- Per-vendor override icon (from VendorMapOverridesDB), if any.
-- Returns art table or nil to fall back to type / Auction House display rules.
function ns.ResolveVendorOverrideIconArt(info)
    if not info then
        return nil
    end
    local presetId = info.iconPreset
    if not presetId or presetId == "" or presetId == "default" then
        -- Path-only override without a preset id
        if info.iconCustom and info.iconCustom ~= "" then
            local asNumber = tonumber(info.iconCustom)
            return { icon = asNumber or info.iconCustom, isDefault = false }
        end
        return nil
    end
    if presetId == "custom" then
        local path = info.iconCustom
        if type(path) == "string" and path ~= "" then
            local asNumber = tonumber(path)
            return { icon = asNumber or path, isDefault = false }
        end
        return nil
    end
    local p = ns.ICON_PRESET_BY_ID[presetId]
    if p and (p.icon or p.atlas) then
        return { icon = p.icon, atlas = p.atlas, isDefault = false }
    end
    return nil
end

--- Draw a pin icon for a vendor: override icon → type (or Auction House) art.
function ns.SetVendorPinIcon(texture, info)
    if not texture or not info then
        return
    end
    if texture.SetVertexColor then
        texture:SetVertexColor(1, 1, 1)
    end
    local ovArt = ns.ResolveVendorOverrideIconArt(info)
    if ovArt then
        ApplyArt(texture, ovArt)
        return
    end
    local key = ns.GetPinDisplayType and ns.GetPinDisplayType(info)
        or (ns.PrimaryVendorType and ns.PrimaryVendorType(info.types))
        or "general"
    ns.SetTypeIcon(texture, key, info.faction)
end

-- Draw a General Goods display subtype icon (Auction House).
-- Honors user preset/custom first, then a preferred atlas list, then the fallback texture.
local function SetGeneralSubtypeIcon(texture, typeKey, atlases)
    local art = ns.ResolveTypeIconArt(typeKey)
    if not art.isDefault then
        ApplyArt(texture, art)
        return
    end
    if atlases and C_Texture and C_Texture.GetAtlasInfo then
        for _, atlas in ipairs(atlases) do
            if C_Texture.GetAtlasInfo(atlas) then
                ApplyArt(texture, { atlas = atlas, icon = art.icon })
                return
            end
        end
    end
    ApplyArt(texture, art)
end

--- Apply the texture/atlas for a vendor type onto a Texture region.
function ns.SetTypeIcon(texture, typeKey, faction)
    if not texture then
        return
    end
    if texture.SetVertexColor then
        texture:SetVertexColor(1, 1, 1)
    end

    -- Legacy petsupplies display key → pets type art.
    if typeKey == ns.PET_SUPPLIES_DISPLAY_KEY then
        typeKey = "pets"
    end

    if typeKey == ns.AUCTION_HOUSE_DISPLAY_KEY then
        SetGeneralSubtypeIcon(texture, typeKey, ns.AUCTION_HOUSE_ATLASES)
        return
    end
    if ns.SPECIALTY_BY_KEY and ns.SPECIALTY_BY_KEY[typeKey] then
        SetGeneralSubtypeIcon(texture, typeKey, nil)
        return
    end

    local art = ns.ResolveTypeIconArt(typeKey)

    -- Built-in faction art swaps Alliance/Horde; presets/custom replace that.
    if typeKey == "faction" and art.isDefault then
        local fac = faction
        if fac ~= "Alliance" and fac ~= "Horde" then
            fac = "Neutral"
        end
        ApplyArt(texture, {
            icon = ns.FACTION_TYPE_ICONS[fac] or ns.FACTION_TYPE_ICONS.Neutral,
        })
        return
    end

    ApplyArt(texture, art)
end
