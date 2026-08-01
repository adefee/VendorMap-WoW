local _, ns = ...

-- Core + loaded LoD pack rows. Packs append here via VendorMap.AddSeed when loaded.
ns.SeedVendors = ns.SeedVendors or {}

--- Helper used by region seed files (core TOC and LoadOnDemand data packs).
-- Requires x/y and either mapID or zoneName.
function ns.AddSeed(entry)
    if not entry or not entry.x or not entry.y then
        return
    end
    if not entry.mapID and not entry.zoneName then
        return
    end
    ns.SeedVendors[#ns.SeedVendors + 1] = entry
end
