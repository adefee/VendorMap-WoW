local _, ns = ...

-- Shared pin helpers. World-map rendering lives in CanvasPins.lua (single renderer);
-- the minimap uses these same helpers for icon/label resolution.

local function PrimaryType(types)
    -- Icon priority for multi-tagged vendors:
    -- Profession wins over reagents/food/etc. (supplies vendors are often dual-tagged).
    -- Barber/innkeeper stay first (unique shop roles); mounts before stable;
    -- transmog then faction/rep last.
    -- e.g. profession+reagents → profession; food+transmog+faction → food.
    local priority = {
        "barber", "innkeeper", "banker", "profession", "class", "repair", "reagents", "mounts", "pets", "stable",
        "decor", "poison", "ammo", "food", "trainingdummy", "general",
        "transmog", "faction",
    }
    for _, key in ipairs(priority) do
        if types and types[key] then
            return key
        end
    end
    return "general"
end

local function TypeLabelList(types)
    local labels = {}
    for _, def in ipairs(ns.VENDOR_TYPES) do
        if types and types[def.key] then
            labels[#labels + 1] = def.label
        end
    end
    return table.concat(labels, ", ")
end

ns.PrimaryVendorType = PrimaryType
ns.TypeLabelList = TypeLabelList

-- Back-compat shims for the retired MapCanvas DataProvider path. CanvasPins is now
-- the sole world-map renderer, so these just ensure it is hooked / redrawn.
function ns.EnsureWorldMapRegistration()
    if ns.InitCanvasPins then
        ns.InitCanvasPins()
    end
    return true
end

function ns.RefreshWorldMap()
    if ns.CanvasPins then
        ns.CanvasPins:Update()
    end
end
