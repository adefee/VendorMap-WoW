#!/usr/bin/env python3
"""Merge a VendorMap /vm export into LoD seed packs (or core Seed_*.lua).

Usage:
  python3 tools/merge_export_to_seeds.py path/to/export.lua
  # or paste via stdin:
  python3 tools/merge_export_to_seeds.py -

Reads A{ ... } lines, upserts by (npcID, mapID) into VendorMap_Data_* packs
using the same continent packing as extract_att_vendors.py.

Preserves the current seed/export data model:
  name, npcID, mapID, x, y, faction, types, repFactionID, minStanding,
  subtitle, specialtyKey, note

Runtime-only fields (learnedFrom, icon overrides, hidden) are not written to seeds.
Legacy notes like "Learned from merchant" are stripped (provenance lives in learnedFrom).
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
    ensure_uimap_csv,
    format_seed_line,
    load_uimap,
    pack_for_map,
    write_data_pack,
)

# Field extractors (order-independent; works with nested types={...}).
_STR_FIELD = r'{key}\s*=\s*"((?:\\.|[^"\\])*)"'
_NUM_FIELD = r"{key}\s*=\s*([0-9.]+)"
_INT_FIELD = r"{key}\s*=\s*(\d+)"
_IDENT_FIELD = r"{key}\s*=\s*([A-Za-z_][\w]*)"


def _str_field(blob: str, key: str) -> str | None:
    m = re.search(_STR_FIELD.format(key=re.escape(key)), blob)
    return m.group(1) if m else None


def _num_field(blob: str, key: str) -> float | None:
    m = re.search(_NUM_FIELD.format(key=re.escape(key)), blob)
    return float(m.group(1)) if m else None


def _int_field(blob: str, key: str) -> int | None:
    m = re.search(_INT_FIELD.format(key=re.escape(key)), blob)
    return int(m.group(1)) if m else None


def _ident_field(blob: str, key: str) -> str | None:
    m = re.search(_IDENT_FIELD.format(key=re.escape(key)), blob)
    return m.group(1) if m else None


def iter_a_blocks(text: str) -> list[str]:
    """Yield full A{ ... } bodies (including nested braces in types=)."""
    blocks: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        # Match "A{" with optional whitespace; avoid matching names that end in A.
        m = re.search(r"(?<![A-Za-z0-9_])A\s*\{", text[i:])
        if not m:
            break
        start = i + m.end() - 1  # index of '{'
        depth = 0
        j = start
        in_str = False
        escape = False
        while j < n:
            ch = text[j]
            if in_str:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        # Include from 'A' through closing '}'
                        block_start = i + m.start()
                        blocks.append(text[block_start : j + 1])
                        i = j + 1
                        break
            j += 1
        else:
            break
    return blocks


def parse_types(blob: str) -> dict[str, bool]:
    types_m = re.search(r"types\s*=\s*(\{(?:[^{}]|\{[^{}]*\})*\})", blob)
    if not types_m:
        return {"general": True}
    out: dict[str, bool] = {}
    for m in re.finditer(r"(\w+)\s*=\s*true", types_m.group(1)):
        out[m.group(1)] = True
    return out or {"general": True}


_LEGACY_LEARN_NOTE = re.compile(r"^[Ll]earned from\s+.+$")


def sanitize_note(note: str | None) -> str | None:
    """Drop runtime provenance strings that used to be stuffed into note."""
    if note is None:
        return None
    note = note.strip()
    if not note or _LEGACY_LEARN_NOTE.match(note):
        return None
    return note


def sanitize_specialty_key(key: str | None) -> str | None:
    if not key or key in ("auto", "nil"):
        return None
    return key


def parse_vendor_block(block: str) -> dict | None:
    name = _str_field(block, "name")
    map_id = _int_field(block, "mapID")
    x = _num_field(block, "x")
    y = _num_field(block, "y")
    if name is None or map_id is None or x is None or y is None:
        # Decor/core rows may use mapID=nil + zoneName; skip those quietly.
        if map_id is None and re.search(r"\bmapID\s*=\s*nil\b", block):
            return None
        print("skip unparsed:", block[:120].replace("\n", " "), file=sys.stderr)
        return None

    v: dict = {
        "name": name,
        "mapID": map_id,
        "x": x,
        "y": y,
        "faction": _str_field(block, "faction") or "Neutral",
        "types": parse_types(block),
    }
    npc = _int_field(block, "npcID")
    if npc is not None:
        v["npcID"] = npc
    rep = _int_field(block, "repFactionID")
    if rep is not None:
        v["repFactionID"] = rep
    standing = _int_field(block, "minStanding")
    if standing is not None:
        v["minStanding"] = standing
    subtitle = _str_field(block, "subtitle")
    if subtitle:
        v["subtitle"] = subtitle
    specialty = sanitize_specialty_key(_ident_field(block, "specialtyKey") or _str_field(block, "specialtyKey"))
    if specialty:
        v["specialtyKey"] = specialty
    note = sanitize_note(_str_field(block, "note"))
    if note:
        v["note"] = note
    return v


def parse_export(text: str) -> list[dict]:
    vendors: list[dict] = []
    for block in iter_a_blocks(text):
        v = parse_vendor_block(block)
        if v:
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


def merge_vendors(incoming: list[dict]) -> int:
    """Upsert vendor dicts into packs/VendorMap_Data_*. Returns 0 on success."""
    if not incoming:
        print("No vendors to merge.", file=sys.stderr)
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

    names = {v["npcID"]: v["name"] for v in incoming if v.get("npcID") and v.get("name")}

    for pack_key, rows in sorted(by_pack.items()):
        addon = PACKS_DIR / f"VendorMap_Data_{pack_key}"
        existing: list[dict] = []
        if addon.is_dir():
            existing = load_pack_vendors(addon)
        merged = upsert(existing, rows)
        for v in merged:
            if v.get("npcID") and v.get("name"):
                names[v["npcID"]] = v["name"]
        write_data_pack(pack_key, merged, names)
        print(f"{pack_key}: +{len(rows)} incoming → {len(merged)} total")

    print("Done. Reload UI / ship updated VendorMap_Data_* folders.")
    return 0


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

    return merge_vendors(incoming)


if __name__ == "__main__":
    raise SystemExit(main())
