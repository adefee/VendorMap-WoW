#!/usr/bin/env python3
"""Merge a VendorMap /vm export into LoD seed packs (or core Seed_*.lua).

Usage:
  python3 tools/merge_export_to_seeds.py path/to/export.lua
  # or paste via stdin:
  python3 tools/merge_export_to_seeds.py -

Reads A{ ... } lines, upserts by (npcID, mapID) into VendorMap_Data_* packs
using the same continent packing as extract_att_vendors.py.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Reuse pack assignment helpers from the ATT extractor.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_att_vendors import (  # type: ignore
    PACKS_DIR,
    CACHE_DIR,
    CONTINENT_ALIASES,
    CONTINENT_PACKS,
    PACK_LABELS,
    ensure_uimap_csv,
    format_seed_line,
    load_uimap,
    pack_for_map,
    write_data_pack,
)

LINE_RE = re.compile(
    r'A\{\s*name="(?P<name>(?:\\.|[^"\\])*)"'
    r"(?:,\s*npcID=(?P<npcID>\d+))?"
    r",\s*mapID=(?P<mapID>\d+)"
    r",\s*x=(?P<x>[0-9.]+)"
    r",\s*y=(?P<y>[0-9.]+)"
    r',\s*faction="(?P<faction>[^"]+)"'
    r",\s*types=(?P<types>\{[^}]*\})"
    r"(?P<extras>[^,]*(?:,\s*repFactionID=\d+)?(?:,\s*minStanding=\d+)?)*"
    r'(?:,\s*note="(?P<note>(?:\\.|[^"\\])*)")?\s*\}'
)


def parse_types(blob: str) -> dict[str, bool]:
    out: dict[str, bool] = {}
    for m in re.finditer(r"(\w+)\s*=\s*true", blob):
        out[m.group(1)] = True
    return out or {"general": True}


def parse_export(text: str) -> list[dict]:
    vendors: list[dict] = []
    for m in re.finditer(r"A\{[^}]+\}", text, re.S):
        line = m.group(0).replace("\n", " ")
        pm = LINE_RE.search(line)
        if not pm:
            # looser fallback
            npc = re.search(r"npcID=(\d+)", line)
            mid = re.search(r"mapID=(\d+)", line)
            xy = re.search(r"x=([0-9.]+),\s*y=([0-9.]+)", line)
            fac = re.search(r'faction="([^"]+)"', line)
            name = re.search(r'name="((?:\\.|[^"\\])*)"', line)
            types_m = re.search(r"types=(\{[^}]*\})", line)
            note = re.search(r'note="((?:\\.|[^"\\])*)"', line)
            if not (mid and xy and name):
                print("skip unparsed:", line[:120], file=sys.stderr)
                continue
            v = {
                "name": name.group(1),
                "npcID": int(npc.group(1)) if npc else None,
                "mapID": int(mid.group(1)),
                "x": float(xy.group(1)),
                "y": float(xy.group(2)),
                "faction": fac.group(1) if fac else "Neutral",
                "types": parse_types(types_m.group(1) if types_m else ""),
                "note": note.group(1) if note else "export",
            }
        else:
            extras = pm.group("extras") or ""
            rep = re.search(r"repFactionID=(\d+)", extras + line)
            standing = re.search(r"minStanding=(\d+)", extras + line)
            v = {
                "name": pm.group("name"),
                "npcID": int(pm.group("npcID")) if pm.group("npcID") else None,
                "mapID": int(pm.group("mapID")),
                "x": float(pm.group("x")),
                "y": float(pm.group("y")),
                "faction": pm.group("faction"),
                "types": parse_types(pm.group("types")),
                "note": pm.group("note") or "export",
                "repFactionID": int(rep.group(1)) if rep else None,
                "minStanding": int(standing.group(1)) if standing else None,
            }
        vendors.append(v)
    return vendors


def load_pack_vendors(pack_dir: Path) -> list[dict]:
    text = ""
    for p in sorted(pack_dir.glob("Seeds*.lua")):
        text += p.read_text(encoding="utf-8")
    return parse_export(text)


def upsert(existing: list[dict], incoming: list[dict]) -> list[dict]:
    by_key: dict[tuple, dict] = {}
    for v in existing:
        key = (v.get("npcID"), v["mapID"], round(v["x"], 4), round(v["y"], 4))
        by_key[key] = v
    for v in incoming:
        key = (v.get("npcID"), v["mapID"], round(v["x"], 4), round(v["y"], 4))
        # Prefer npcID+mapID match for location updates
        if v.get("npcID"):
            for k in list(by_key):
                if k[0] == v["npcID"] and k[1] == v["mapID"]:
                    del by_key[k]
            by_key[(v["npcID"], v["mapID"], round(v["x"], 4), round(v["y"], 4))] = v
        else:
            by_key[key] = v
    out = list(by_key.values())
    out.sort(key=lambda v: (v["mapID"], v.get("npcID") or 0, v["x"], v["y"]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("export_file", help="Path to export.lua, or - for stdin")
    args = ap.parse_args()

    if args.export_file == "-":
        text = sys.stdin.read()
    else:
        text = Path(args.export_file).read_text(encoding="utf-8")

    incoming = parse_export(text)
    if not incoming:
        print("No A{...} vendors found in export.", file=sys.stderr)
        return 1

    uimap_path = ensure_uimap_csv()
    if not uimap_path:
        print("UiMap CSV required.", file=sys.stderr)
        return 1
    uimap = load_uimap(uimap_path)

    by_pack: dict[str, list[dict]] = {}
    for v in incoming:
        pack = pack_for_map(v["mapID"], uimap)
        by_pack.setdefault(pack, []).append(v)

    # Identity names map for format_seed_line
    names = {v["npcID"]: v["name"] for v in incoming if v.get("npcID") and v.get("name")}

    for pack_key, rows in sorted(by_pack.items()):
        addon = PACKS_DIR / f"VendorMap_Data_{pack_key}"
        existing: list[dict] = []
        if addon.is_dir():
            existing = load_pack_vendors(addon)
        merged = upsert(existing, rows)
        # format_seed_line wants names dict by npcID; pass through name field via names
        for v in merged:
            if v.get("npcID") and v.get("name"):
                names[v["npcID"]] = v["name"]
        write_data_pack(pack_key, merged, names)
        print(f"{pack_key}: +{len(rows)} incoming → {len(merged)} total")

    print("Done. Reload UI / ship updated VendorMap_Data_* folders.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
