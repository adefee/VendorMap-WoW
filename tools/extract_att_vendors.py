#!/usr/bin/env python3
"""Extract ATT vendor (header -58) coords into LoadOnDemand VendorMap_Data_* packs.

ATT is an *extract-time* source only — shipped seeds are standalone (no ATT runtime dep).

Output: in-repo packs/VendorMap_Data_<Pack>/ (LoadOnDemand); shipped in the
same CurseForge zip via .pkgmeta move-folders, symlinked for local testing.
Core VendorMap keeps Capitals/Hubs/Decor only; continent dumps load when that map opens.

Richer fields:
  - Real NPC names baked from wago Creature CSV + Wowhead tooltip API
  - Alliance/Horde/Neutral from ATT r=1/2
  - repFactionID / minStanding, description notes, faction+transmog types

Name cache: tools/cache/npc_names.json
UiMap cache: tools/cache/UiMap.enUS.csv (for continent → pack assignment)
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ATT_CAT = Path(
    "/home/shamrock/.local/share/Steam/steamapps/compatdata/3801730699/"
    "pfx/drive_c/Program Files (x86)/World of Warcraft/_retail_/"
    "Interface/AddOns/AllTheThings/db/Standard/Categories"
)
TOOLS_DIR = Path(__file__).resolve().parent
ADDON_DIR = TOOLS_DIR.parent
ADDONS_ROOT = ADDON_DIR.parent
# LoD data packs now live inside the repo under packs/ (shipped in the same
# CurseForge zip via .pkgmeta move-folders). Use tools/link_packs.sh to symlink
# them back to top-level AddOns/ folders for local testing.
PACKS_DIR = ADDON_DIR / "packs"
CORE_DATA_DIR = ADDON_DIR / "Data"
CACHE_DIR = TOOLS_DIR / "cache"
NAME_CACHE = CACHE_DIR / "npc_names.json"
WAGO_CREATURE_CSV = CACHE_DIR / "Creature.enUS.csv"
WAGO_UIMAP_CSV = CACHE_DIR / "UiMap.enUS.csv"
CHUNK = 450
WAGO_CREATURE_URL = "https://wago.tools/db2/Creature/csv?locale=enUS"
WAGO_UIMAP_URL = "https://wago.tools/db2/UiMap/csv?locale=enUS"
WOWHEAD_NPC_URL = "https://nether.wowhead.com/tooltip/npc/{npc_id}"
UA = "VendorMap-extract/1.0 (local seed bake; +https://github.com/)"
INTERFACE_VERSION = "120007, 120100"
ADDON_VERSION = "0.6.4"

# Primary continent mapID → pack key (nested continents aliased in CONTINENT_ALIASES).
CONTINENT_PACKS: dict[int, str] = {
    12: "Kalimdor",
    13: "EasternKingdoms",
    101: "Outland",
    113: "Northrend",
    424: "Pandaria",
    572: "Draenor",
    619: "BrokenIsles",
    875: "Zandalar",
    876: "KulTiras",
    948: "Maelstrom",
    1550: "Shadowlands",
    1978: "DragonIsles",
    2274: "KhazAlgar",
}
# Nested Type=2 maps that should fold into a parent pack.
CONTINENT_ALIASES: dict[int, str] = {
    905: "BrokenIsles",  # Argus
    2537: "EasternKingdoms",  # Quel'Thalas / Midnight
}

PACK_LABELS: dict[str, str] = {
    "EasternKingdoms": "Eastern Kingdoms",
    "Kalimdor": "Kalimdor",
    "Outland": "Outland",
    "Northrend": "Northrend",
    "Pandaria": "Pandaria",
    "Draenor": "Draenor",
    "BrokenIsles": "Broken Isles",
    "Zandalar": "Zandalar",
    "KulTiras": "Kul Tiras",
    "Maelstrom": "The Maelstrom",
    "Shadowlands": "Shadowlands",
    "DragonIsles": "Dragon Isles",
    "KhazAlgar": "Khaz Algar",
    "Other": "Other",
}

def find_matching_brace(s: str, open_idx: int) -> int:
    """open_idx points at '{'. Returns index of matching '}'."""
    depth = 0
    i = open_idx
    in_str = False
    while i < len(s):
        ch = s[i]
        if in_str:
            if ch == "\\" and i + 1 < len(s):
                i += 2
                continue
            if ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def parse_shared_array(text: str) -> dict[int, object]:
    """Parse `local a={...}` 1-based shared table used by ATT category files."""
    m = re.search(r"local a=\{", text)
    if not m:
        return {}
    start = m.end() - 1
    end = find_matching_brace(text, start)
    if end < 0:
        return {}
    body = text[start + 1 : end]
    # Split top-level comma-separated entries (respect braces/strings)
    entries: list[str] = []
    buf: list[str] = []
    depth = 0
    in_str = False
    i = 0
    while i < len(body):
        ch = body[i]
        if in_str:
            buf.append(ch)
            if ch == "\\" and i + 1 < len(body):
                buf.append(body[i + 1])
                i += 2
                continue
            if ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            buf.append(ch)
        elif ch == "{":
            depth += 1
            buf.append(ch)
        elif ch == "}":
            depth -= 1
            buf.append(ch)
        elif ch == "," and depth == 0:
            entries.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
        i += 1
    if buf:
        entries.append("".join(buf).strip())

    out: dict[int, object] = {}
    for idx, ent in enumerate(entries, start=1):
        if not ent:
            continue
        # coordinate pair {x,y}
        cm = re.fullmatch(r"\{([0-9.]+),([0-9.]+)\}", ent)
        if cm:
            out[idx] = (float(cm.group(1)), float(cm.group(2)))
            continue
        # reputation pair {factionID, standing}
        rm = re.fullmatch(r"\{(\d+),(\d+)\}", ent)
        if rm:
            out[idx] = (int(rm.group(1)), int(rm.group(2)))
            continue
        out[idx] = ent
    return out


def resolve_a_ref(val: str, shared: dict[int, object]):
    m = re.fullmatch(r"a\[(\d+)\]", val.strip())
    if not m:
        return None
    return shared.get(int(m.group(1)))


def extract_coords_block(npc_body: str, shared: dict[int, object]) -> list[tuple[int, float, float]]:
    """Return list of (mapID, x01, y01)."""
    results: list[tuple[int, float, float]] = []
    # coords={[map]={{x,y},...}} or coords={[map]={a[n]}} or multi-map
    cm = re.search(r"coords=\{", npc_body)
    if not cm:
        return results
    start = cm.end() - 1
    end = find_matching_brace(npc_body, start)
    if end < 0:
        return results
    block = npc_body[start + 1 : end]

    # [mapID]=...
    for m in re.finditer(r"\[(\d+)\]=", block):
        map_id = int(m.group(1))
        rest = block[m.end() :]
        if rest.startswith("a["):
            am = re.match(r"a\[(\d+)\]", rest)
            if not am:
                continue
            resolved = shared.get(int(am.group(1)))
            if isinstance(resolved, tuple) and len(resolved) == 2:
                x, y = resolved
                results.append((map_id, float(x) / 100.0, float(y) / 100.0))
            continue
        if rest.startswith("{"):
            be = find_matching_brace(rest, 0)
            if be < 0:
                continue
            inner = rest[1:be]
            # one or more {x,y}
            for pm in re.finditer(r"\{([0-9.]+),([0-9.]+)\}", inner):
                results.append((map_id, float(pm.group(1)) / 100.0, float(pm.group(2)) / 100.0))
            # or a[n] alone inside
            if not results or results[-1][0] != map_id:
                am = re.match(r"a\[(\d+)\]", inner.strip())
                if am:
                    resolved = shared.get(int(am.group(1)))
                    if isinstance(resolved, tuple) and len(resolved) == 2:
                        x, y = resolved
                        results.append((map_id, float(x) / 100.0, float(y) / 100.0))
    return results


def top_level_field(body: str, key: str) -> str | None:
    """Get a simple top-level field value string (best-effort)."""
    # r=1 / awp=50004
    m = re.search(rf"(?<![\w]){key}=([0-9]+)", body)
    if m:
        return m.group(1)
    # description="..."
    m = re.search(rf'(?<![\w]){key}="((?:\\.|[^"\\])*)"', body)
    if m:
        return m.group(1)
    # minReputation=a[n] or minReputation={id,standing}
    m = re.search(rf"(?<![\w]){key}=(a\[\d+\]|\{{[^\}}]+\}})", body)
    if m:
        return m.group(1)
    return None


# ATT filter IDs (see AllTheThings General - Filters.lua)
TRANSMOG_FILTERS = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 32, 33, 34, 35, 36,
    50, 51, 52, 53, 54,
}
CONSUMABLE_FILTERS = {55}  # food/drink/potions — treat as food for map filters
PROFESSION_FILTERS = {57}  # profession equipment
BAG_FILTERS = {113}

TYPE_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("repair", ("repair", "blacksmith", "armorer", "weaponsmith", "gunsmith")),
    ("reagents", ("reagent", "components", "inscription supplies", "enchanting")),
    ("food", ("food", "drink", "meat", "fruit", "butcher", "bread", "cheese", "fish vendor", "cook")),
    ("poison", ("poison",)),
    ("ammo", ("ammo", "ammunition", "arrow", "bullet")),
    ("mounts", ("mount vendor", "mount trainer", "mounts", "riding trainer", "wind rider", "gryphon master")),
    ("pets", ("pet vendor", "pet supplies", "pet trainer", "battle pet", "breeder", "kennel", "pets")),
    ("stable", ("stable master", "stablemaster")),
    ("profession", ("profession", "trainer", "recipes", "plans", "schematic", "pattern", "design")),
    # Class supply vendors only — require an explicit "<Class> Supplies" phrase so we don't
    # mass-tag every ATT note that merely mentions a class name.
    ("class", (
        "warrior supplies", "paladin supplies", "hunter supplies", "rogue supplies",
        "priest supplies", "death knight supplies", "shaman supplies", "mage supplies",
        "warlock supplies", "monk supplies", "druid supplies", "demon hunter supplies",
        "evoker supplies", "class supplies",
    )),
    ("decor", ("decor", "housing", "furniture", "ornament")),
    ("innkeeper", ("innkeeper", "inn keeper")),
    ("barber", ("barber",)),
    ("transmog", ("transmogrif", "appearances", "ensemble")),
]


def count_att_filters(npc_body: str) -> dict[int, int]:
    counts: dict[int, int] = {}
    for m in re.finditer(r"\bf=(\d+)\b", npc_body):
        fid = int(m.group(1))
        counts[fid] = counts.get(fid, 0) + 1
    return counts


def infer_vendor_types(
    npc_body: str,
    description: str | None,
    rep_faction_id: int | None,
) -> dict[str, bool]:
    """Medium taxonomy: ATT filters + description keywords. No default faction/transmog."""
    types: dict[str, bool] = {}
    filters = count_att_filters(npc_body)
    text = (description or "").lower()

    transmog_hits = sum(filters.get(f, 0) for f in TRANSMOG_FILTERS)
    consumable_hits = sum(filters.get(f, 0) for f in CONSUMABLE_FILTERS)
    profession_hits = sum(filters.get(f, 0) for f in PROFESSION_FILTERS)
    total_filters = sum(filters.values()) or 1

    if rep_faction_id:
        types["faction"] = True

    if transmog_hits >= 3 or (transmog_hits >= 1 and transmog_hits / total_filters >= 0.35):
        types["transmog"] = True
    elif "sourceID" in npc_body or re.search(r"\bs\(\d+", npc_body):
        # Collectible appearances without heavy armor filters
        if transmog_hits >= 1 or "ensemble" in text:
            types["transmog"] = True

    if consumable_hits >= 2 or (consumable_hits >= 1 and consumable_hits >= transmog_hits):
        types["food"] = True

    if profession_hits >= 1:
        types["profession"] = True

    for type_key, words in TYPE_KEYWORDS:
        for w in words:
            if w in text:
                types[type_key] = True
                break

    # Whole-word "mount"/"mounts" in the description (not "mountain").
    if re.search(r"\bmounts?\b", text):
        types["mounts"] = True

    # Whole-word pet/breeder/kennel signals.
    if re.search(r"\b(?:pets?|breeders?|kennels?)\b", text):
        types["pets"] = True

    # Mount/riding trainers are mounts, not profession trainers.
    if types.get("mounts") and re.search(r"\b(?:mount|riding)\s+trainer\b", text):
        types.pop("profession", None)

    # Pet / battle-pet trainers are pets, not profession trainers.
    if types.get("pets") and re.search(r"\b(?:battle\s+)?pet\s+trainer\b", text):
        types.pop("profession", None)

    if not types:
        types["general"] = True
    return types


def faction_from_r(r: str | None) -> str:
    if r == "1":
        return "Horde"
    if r == "2":
        return "Alliance"
    return "Neutral"


def extract_file(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    shared = parse_shared_array(text)
    vendors: list[dict] = []

    for hm in re.finditer(r"h\(-58,\{", text):
        h_start = hm.end() - 1
        h_end = find_matching_brace(text, h_start)
        if h_end < 0:
            continue
        header_body = text[h_start + 1 : h_end]
        header_r = top_level_field(header_body, "r")

        # Find n(npcID,{...}) at various nest depths inside this header
        for nm in re.finditer(r"n\((-?\d+),\{", header_body):
            npc_id = int(nm.group(1))
            if npc_id <= 0:
                continue
            n_start = nm.end() - 1
            n_end = find_matching_brace(header_body, n_start)
            if n_end < 0:
                continue
            npc_body = header_body[n_start + 1 : n_end]
            coords = extract_coords_block(npc_body, shared)
            if not coords:
                continue

            npc_r = top_level_field(npc_body, "r") or header_r
            faction = faction_from_r(npc_r)
            desc = top_level_field(npc_body, "description")
            min_rep_raw = top_level_field(npc_body, "minReputation")
            rep_faction_id = None
            min_standing = None
            if min_rep_raw:
                resolved = resolve_a_ref(min_rep_raw, shared)
                if isinstance(resolved, tuple) and len(resolved) == 2:
                    rep_faction_id, min_standing = int(resolved[0]), int(resolved[1])
                else:
                    mm = re.fullmatch(r"\{(\d+),(\d+)\}", min_rep_raw.strip())
                    if mm:
                        rep_faction_id, min_standing = int(mm.group(1)), int(mm.group(2))

            desc_clean = None
            if desc:
                desc_clean = desc.replace("\\n", " ").replace('\\"', '"')[:120]
            types = infer_vendor_types(npc_body, desc_clean, rep_faction_id)

            note_parts = ["ATT"]
            if desc_clean:
                note_parts.append(desc_clean)

            for map_id, x, y in coords:
                vendors.append(
                    {
                        "npcID": npc_id,
                        "mapID": map_id,
                        "x": x,
                        "y": y,
                        "faction": faction,
                        "types": types,
                        "repFactionID": rep_faction_id,
                        "minStanding": min_standing,
                        "note": " — ".join(note_parts),
                    }
                )
    return vendors


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def http_get(url: str, timeout: float = 60.0) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def load_name_cache() -> dict[str, str]:
    if not NAME_CACHE.is_file():
        return {}
    try:
        data = json.loads(NAME_CACHE.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return {str(k): str(v) for k, v in data.items() if v}
    except (OSError, json.JSONDecodeError):
        pass
    return {}


def save_name_cache(cache: dict[str, str]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    NAME_CACHE.write_text(
        json.dumps(dict(sorted(cache.items(), key=lambda kv: int(kv[0]))), indent=0, ensure_ascii=False)
        + "\n",
        encoding="utf-8",
    )


def ensure_wago_creature_csv(force: bool = False) -> Path | None:
    """Download/cache wago Creature CSV (partial coverage; fast bulk fill)."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if WAGO_CREATURE_CSV.is_file() and not force and WAGO_CREATURE_CSV.stat().st_size > 1000:
        return WAGO_CREATURE_CSV
    print("Downloading wago Creature CSV…")
    try:
        raw = http_get(WAGO_CREATURE_URL, timeout=120)
        WAGO_CREATURE_CSV.write_bytes(raw)
        print(f"  cached {WAGO_CREATURE_CSV.name} ({len(raw)} bytes)")
        return WAGO_CREATURE_CSV
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        print(f"  wago download failed: {e}", file=sys.stderr)
        return WAGO_CREATURE_CSV if WAGO_CREATURE_CSV.is_file() else None


def names_from_wago_csv(path: Path) -> dict[int, str]:
    out: dict[int, str] = {}
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                nid = int(row["ID"])
            except (KeyError, TypeError, ValueError):
                continue
            name = (row.get("Name_lang") or "").strip().strip('"')
            if name:
                out[nid] = name
    return out


def wowhead_npc_name(npc_id: int) -> str | None:
    url = WOWHEAD_NPC_URL.format(npc_id=npc_id)
    try:
        raw = http_get(url, timeout=20)
    except (urllib.error.URLError, TimeoutError, OSError):
        return None
    try:
        data = json.loads(raw.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return None
    name = data.get("name") if isinstance(data, dict) else None
    if isinstance(name, str):
        name = name.strip()
        if name:
            return name
    return None


def resolve_names(npc_ids: set[int], refresh: bool = False, workers: int = 12) -> dict[int, str]:
    """Bake npcID → name via cache, wago CSV, then Wowhead for gaps."""
    cache = {} if refresh else load_name_cache()
    resolved: dict[int, str] = {}
    for nid in npc_ids:
        cached = cache.get(str(nid))
        if cached:
            resolved[nid] = cached

    missing = npc_ids - resolved.keys()
    print(f"Names: {len(resolved)} cached, {len(missing)} still needed")

    csv_path = ensure_wago_creature_csv(force=refresh)
    if csv_path and missing:
        wago = names_from_wago_csv(csv_path)
        filled = 0
        for nid in list(missing):
            if nid in wago:
                resolved[nid] = wago[nid]
                cache[str(nid)] = wago[nid]
                filled += 1
        missing = npc_ids - resolved.keys()
        print(f"  wago Creature CSV filled {filled}; {len(missing)} remain")

    if missing:
        print(f"  fetching {len(missing)} names from Wowhead (workers={workers})…")
        done = 0
        failed = 0
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(wowhead_npc_name, nid): nid for nid in sorted(missing)}
            for fut in as_completed(futures):
                nid = futures[fut]
                name = None
                try:
                    name = fut.result()
                except Exception:
                    name = None
                if name:
                    resolved[nid] = name
                    cache[str(nid)] = name
                else:
                    failed += 1
                done += 1
                if done % 100 == 0 or done == len(futures):
                    print(f"    Wowhead {done}/{len(futures)} (fail={failed})")
                    save_name_cache(cache)
                # light politeness — pool already limits concurrency
                if done % 50 == 0:
                    time.sleep(0.05)

    save_name_cache(cache)
    print(f"Names resolved: {len(resolved)}/{len(npc_ids)}")
    return resolved


def ensure_uimap_csv(force: bool = False) -> Path | None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if WAGO_UIMAP_CSV.is_file() and not force and WAGO_UIMAP_CSV.stat().st_size > 1000:
        return WAGO_UIMAP_CSV
    print("Downloading wago UiMap CSV…")
    try:
        raw = http_get(WAGO_UIMAP_URL, timeout=120)
        WAGO_UIMAP_CSV.write_bytes(raw)
        print(f"  cached {WAGO_UIMAP_CSV.name} ({len(raw)} bytes)")
        return WAGO_UIMAP_CSV
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        print(f"  UiMap download failed: {e}", file=sys.stderr)
        return WAGO_UIMAP_CSV if WAGO_UIMAP_CSV.is_file() else None


def load_uimap(path: Path) -> dict[int, dict[str, str]]:
    rows: dict[int, dict[str, str]] = {}
    with path.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                rows[int(row["ID"])] = row
            except (KeyError, ValueError):
                continue
    return rows


def primary_continent_id(map_id: int, uimap: dict[int, dict[str, str]]) -> int | None:
    continents: list[int] = []
    seen: set[int] = set()
    mid = map_id
    while mid and mid not in seen:
        seen.add(mid)
        row = uimap.get(mid)
        if not row:
            break
        if row.get("Type") == "2":
            continents.append(mid)
        try:
            mid = int(row.get("ParentUiMapID") or 0)
        except ValueError:
            break
    if not continents:
        return None
    for cont in continents:
        parent = int(uimap[cont].get("ParentUiMapID") or 0)
        prow = uimap.get(parent)
        if not prow or prow.get("Type") != "2":
            return cont
    return continents[-1]


def pack_for_map(map_id: int, uimap: dict[int, dict[str, str]]) -> str:
    if map_id in CONTINENT_ALIASES:
        return CONTINENT_ALIASES[map_id]
    cont = primary_continent_id(map_id, uimap)
    if cont is not None:
        if cont in CONTINENT_ALIASES:
            return CONTINENT_ALIASES[cont]
        if cont in CONTINENT_PACKS:
            return CONTINENT_PACKS[cont]
    return "Other"


TYPE_EMIT_ORDER = (
    "repair", "reagents", "food", "poison", "ammo", "mounts", "pets", "stable",
    "transmog", "decor", "profession", "faction", "innkeeper", "barber", "general",
)


def format_types_lua(types: dict) -> str:
    bits = [f"{k}=true" for k in TYPE_EMIT_ORDER if types.get(k)]
    if not bits:
        bits = ["general=true"]
    return "{" + ", ".join(bits) + "}"


def format_seed_line(v: dict, names: dict[int, str]) -> str:
    """Emit one AddSeed line matching Export.lua / runtime NormalizeVendor fields.

    Includes optional subtitle + specialtyKey (display model). Omits runtime-only
    fields (learnedFrom, icon overrides, hidden).
    """
    types_s = format_types_lua(v.get("types") or {})
    extras = ""
    if v.get("repFactionID"):
        extras += f", repFactionID={v['repFactionID']}"
    if v.get("minStanding"):
        extras += f", minStanding={v['minStanding']}"
    subtitle = v.get("subtitle")
    if isinstance(subtitle, str) and subtitle.strip():
        extras += f', subtitle="{lua_escape(subtitle.strip())}"'
    specialty = v.get("specialtyKey")
    if isinstance(specialty, str) and specialty not in ("", "auto"):
        extras += f", specialtyKey=\"{lua_escape(specialty)}\""
    # ATT extractor always sets note; merge/export may omit it.
    note = v.get("note")
    note_part = f', note="{lua_escape(note)}"' if note else ""
    npc_id = v.get("npcID")
    display = (
        v.get("name")
        or (names.get(npc_id) if npc_id is not None else None)
        or (f"Vendor {npc_id}" if npc_id is not None else "Unknown Vendor")
    )
    npc_part = f", npcID={npc_id}" if npc_id is not None else ""
    return (
        f'A{{ name="{lua_escape(display)}"{npc_part}, mapID={v["mapID"]}, '
        f'x={v["x"]:.4f}, y={v["y"]:.4f}, faction="{v.get("faction") or "Neutral"}", '
        f"types={types_s}{extras}{note_part} }}\n"
    )


def write_data_pack(pack_key: str, vendors: list[dict], names: dict[int, str]) -> Path:
    addon_name = f"VendorMap_Data_{pack_key}"
    PACKS_DIR.mkdir(parents=True, exist_ok=True)
    pack_dir = PACKS_DIR / addon_name
    if pack_dir.exists():
        shutil.rmtree(pack_dir)
    pack_dir.mkdir(parents=True)

    label = PACK_LABELS.get(pack_key, pack_key)
    chunks = [vendors[i : i + CHUNK] for i in range(0, len(vendors), CHUNK)] or [[]]
    seed_files: list[str] = []
    for ci, chunk in enumerate(chunks):
        fname = "Seeds.lua" if ci == 0 else f"Seeds_{ci + 1}.lua"
        seed_files.append(fname)
        lines = [
            "-- Auto-generated LoadOnDemand seed pack. ATT not required at runtime.\n",
            "local A = VendorMap.AddSeed\n\n",
        ]
        for v in chunk:
            lines.append(format_seed_line(v, names))
        if ci == len(chunks) - 1:
            lines.append(f'\nVendorMap.NotifySeedPackLoaded("{pack_key}")\n')
        (pack_dir / fname).write_text("".join(lines), encoding="utf-8")

    toc_lines = [
        f"## Interface: {INTERFACE_VERSION}\n",
        f"## Title: VendorMap Data: {label}\n",
        f"## Notes: LoadOnDemand vendor coordinates for {label}. Requires VendorMap.\n",
        "## Author: VendorMap\n",
        f"## Version: {ADDON_VERSION}\n",
        "## LoadOnDemand: 1\n",
        "## Dependencies: VendorMap\n",
        "## X-Category: Map\n",
        "\n",
    ]
    for fname in seed_files:
        toc_lines.append(f"{fname}\n")
    (pack_dir / f"{addon_name}.toc").write_text("".join(toc_lines), encoding="utf-8")
    return pack_dir


def emit_packs(vendors: list[dict], names: dict[int, str], uimap: dict[int, dict[str, str]]) -> None:
    seen = set()
    unique: list[dict] = []
    for v in vendors:
        key = (v["npcID"], v["mapID"], round(v["x"], 4), round(v["y"], 4))
        if key in seen:
            continue
        seen.add(key)
        unique.append(v)
    unique.sort(key=lambda v: (v["mapID"], v["npcID"], v["x"], v["y"]))

    by_pack: dict[str, list[dict]] = defaultdict(list)
    for v in unique:
        by_pack[pack_for_map(v["mapID"], uimap)].append(v)

    # Remove legacy in-core ATT dumps
    for old in CORE_DATA_DIR.glob("Seed_ATT*.lua"):
        old.unlink()
        print(f"Removed legacy {old.name}")

    # Remove stale data addons we manage
    if PACKS_DIR.exists():
        for path in PACKS_DIR.glob("VendorMap_Data_*"):
            if path.is_dir():
                shutil.rmtree(path)

    print(f"Seed rows with baked names: {sum(1 for v in unique if names.get(v['npcID']))}/{len(unique)}")
    for pack_key in sorted(by_pack.keys(), key=lambda k: (-len(by_pack[k]), k)):
        rows = by_pack[pack_key]
        dest = write_data_pack(pack_key, rows, names)
        print(f"  {pack_key:18s} {len(rows):4d} vendors → {dest.name}")

    # Ensure empty Other pack exists if somehow unused (always ship all known packs? optional)
    for pack_key in PACK_LABELS:
        if pack_key not in by_pack:
            write_data_pack(pack_key, [], names)
            print(f"  {pack_key:18s}    0 vendors → VendorMap_Data_{pack_key} (empty)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--refresh-names",
        action="store_true",
        help="Ignore cached names and re-download wago/Wowhead data",
    )
    parser.add_argument(
        "--refresh-uimap",
        action="store_true",
        help="Re-download wago UiMap CSV used for continent packing",
    )
    parser.add_argument("--workers", type=int, default=12, help="Wowhead fetch concurrency")
    args = parser.parse_args()

    if not ATT_CAT.is_dir():
        print("ATT Categories dir not found:", ATT_CAT, file=sys.stderr)
        return 1

    uimap_path = ensure_uimap_csv(force=args.refresh_uimap)
    if not uimap_path:
        print("UiMap CSV required for continent packs.", file=sys.stderr)
        return 1
    uimap = load_uimap(uimap_path)

    all_v: list[dict] = []
    for path in sorted(ATT_CAT.glob("*.lua")):
        got = extract_file(path)
        if got:
            print(f"  {path.name}: {len(got)}")
            all_v.extend(got)

    npc_ids = {v["npcID"] for v in all_v if v.get("npcID")}
    names = resolve_names(npc_ids, refresh=args.refresh_names, workers=args.workers)
    emit_packs(all_v, names, uimap)
    print("Done. Packs written to packs/. Run tools/link_packs.sh to test locally.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
