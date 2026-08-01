#!/usr/bin/env python3
"""Pull learned/override vendors from a local WoW install and merge into seed packs.

Finds retail AddOns via tools/deploy.sh --list, reads account SavedVariables
(VendorMap.lua), converts VendorMapLearnedDB (+ applicable overrides) into the
same seed shape as /vm export, then runs merge_export_to_seeds.

Usage:
  python3 tools/import_local_learned.py
  python3 tools/import_local_learned.py --dry-run          # print summary + sample lines
  python3 tools/import_local_learned.py --export-only out.lua
  python3 tools/import_local_learned.py --account '308434992#1'
  python3 tools/import_local_learned.py --saved-vars /path/to/VendorMap.lua

Note: WoW flushes SavedVariables on logout / clean exit. Quit the client (or
wait for a save) before importing if you just learned new vendors.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
REPO_DIR = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from extract_att_vendors import CORE_DATA_DIR, PACKS_DIR, format_seed_line  # type: ignore
from merge_export_to_seeds import (  # type: ignore
    load_pack_vendors,
    merge_vendors,
    parse_export,
    sanitize_note,
    sanitize_specialty_key,
)

DEPLOY_SH = TOOLS_DIR / "deploy.sh"

# Subtitles that are clearly reaction/standing lines, not NPC titles.
_BAD_SUBTITLES = {
    "friendly",
    "neutral",
    "hostile",
    "honored",
    "revered",
    "exalted",
    "unfriendly",
    "hated",
    "alliance",
    "horde",
}


# ---------------------------------------------------------------------------
# Minimal WoW SavedVariables Lua table parser (no external deps)
# ---------------------------------------------------------------------------

class _LuaSVError(ValueError):
    pass


class _LuaSVParser:
    def __init__(self, text: str):
        self.text = text
        self.n = len(text)
        self.i = 0

    def parse_assignment(self, name: str):
        """Return the value of `Name = <value>` or None if missing."""
        m = re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}\s*=\s*", self.text)
        if not m:
            return None
        self.i = m.end()
        return self._parse_value()

    def _skip_ws(self) -> None:
        while self.i < self.n:
            ch = self.text[self.i]
            if ch in " \t\r\n":
                self.i += 1
            elif self.text.startswith("--", self.i):
                while self.i < self.n and self.text[self.i] not in "\r\n":
                    self.i += 1
            else:
                break

    def _parse_value(self):
        self._skip_ws()
        if self.i >= self.n:
            raise _LuaSVError("unexpected EOF")
        ch = self.text[self.i]
        if ch == "{":
            return self._parse_table()
        if ch == '"':
            return self._parse_string()
        if self.text.startswith("true", self.i) and self._is_word_end(self.i + 4):
            self.i += 4
            return True
        if self.text.startswith("false", self.i) and self._is_word_end(self.i + 5):
            self.i += 5
            return False
        if self.text.startswith("nil", self.i) and self._is_word_end(self.i + 3):
            self.i += 3
            return None
        return self._parse_number()

    def _is_word_end(self, pos: int) -> bool:
        return pos >= self.n or not (self.text[pos].isalnum() or self.text[pos] == "_")

    def _parse_string(self) -> str:
        assert self.text[self.i] == '"'
        self.i += 1
        out: list[str] = []
        while self.i < self.n:
            ch = self.text[self.i]
            if ch == "\\":
                self.i += 1
                if self.i >= self.n:
                    break
                esc = self.text[self.i]
                out.append({"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}.get(esc, esc))
                self.i += 1
            elif ch == '"':
                self.i += 1
                return "".join(out)
            else:
                out.append(ch)
                self.i += 1
        raise _LuaSVError("unterminated string")

    def _parse_number(self) -> float | int:
        m = re.match(r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", self.text[self.i :])
        if not m:
            raise _LuaSVError(f"expected number at {self.i}: {self.text[self.i:self.i+20]!r}")
        raw = m.group(0)
        self.i += len(raw)
        return float(raw) if ("." in raw or "e" in raw.lower()) else int(raw)

    def _parse_table(self):
        assert self.text[self.i] == "{"
        self.i += 1
        # Distinguish array-like vs map-like; WoW mixes both.
        arr: list = []
        obj: dict = {}
        used_obj = False
        while True:
            self._skip_ws()
            if self.i >= self.n:
                raise _LuaSVError("unterminated table")
            if self.text[self.i] == "}":
                self.i += 1
                break
            # Bracket key: ["name"] = / [123] =
            if self.text[self.i] == "[":
                self.i += 1
                self._skip_ws()
                if self.text[self.i] == '"':
                    key = self._parse_string()
                else:
                    key = self._parse_number()
                    if isinstance(key, float) and key.is_integer():
                        key = int(key)
                self._skip_ws()
                if self.i >= self.n or self.text[self.i] != "]":
                    raise _LuaSVError("expected ] after key")
                self.i += 1
                self._skip_ws()
                if self.i >= self.n or self.text[self.i] != "=":
                    raise _LuaSVError("expected = after key")
                self.i += 1
                val = self._parse_value()
                obj[key] = val
                used_obj = True
            else:
                # Array element (learned rows are bare {...}, ...)
                val = self._parse_value()
                arr.append(val)
            self._skip_ws()
            if self.i < self.n and self.text[self.i] == ",":
                self.i += 1
                continue
            if self.i < self.n and self.text[self.i] == "}":
                self.i += 1
                break
            raise _LuaSVError(f"expected , or }} at {self.i}: {self.text[self.i:self.i+20]!r}")

        if used_obj and arr:
            # Mixed: put array items under integer keys starting at 1 (Lua style)
            for idx, val in enumerate(arr, start=1):
                obj.setdefault(idx, val)
            return obj
        if used_obj:
            return obj
        return arr


def load_saved_variables(path: Path) -> tuple[list[dict], dict]:
    text = path.read_text(encoding="utf-8", errors="replace")
    parser = _LuaSVParser(text)
    learned_raw = parser.parse_assignment("VendorMapLearnedDB") or []
    overrides_raw = parser.parse_assignment("VendorMapOverridesDB") or {}

    learned: list[dict] = []
    if isinstance(learned_raw, list):
        for row in learned_raw:
            if isinstance(row, dict):
                learned.append(row)
    elif isinstance(learned_raw, dict):
        for key in sorted(learned_raw, key=lambda k: (isinstance(k, int), k)):
            row = learned_raw[key]
            if isinstance(row, dict):
                learned.append(row)

    overrides: dict = {}
    if isinstance(overrides_raw, dict):
        for key, ov in overrides_raw.items():
            if not isinstance(ov, dict):
                continue
            try:
                npc_id = int(key)
            except (TypeError, ValueError):
                continue
            overrides[npc_id] = ov
    return learned, overrides


# ---------------------------------------------------------------------------
# Install / SavedVariables discovery
# ---------------------------------------------------------------------------

def detect_addons_roots() -> list[Path]:
    if not DEPLOY_SH.is_file():
        return []
    try:
        out = subprocess.check_output([str(DEPLOY_SH), "--list"], text=True)
    except subprocess.CalledProcessError:
        return []
    roots: list[Path] = []
    for line in out.splitlines():
        line = line.strip()
        if line:
            roots.append(Path(line))
    return roots


def retail_root_from_addons(addons: Path) -> Path:
    # .../_retail_/Interface/AddOns → .../_retail_
    return addons.resolve().parent.parent


def find_saved_variables(
    addons_roots: list[Path] | None = None,
    account: str | None = None,
    explicit: Path | None = None,
) -> Path:
    if explicit:
        path = explicit.expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"SavedVariables not found: {path}")
        return path

    roots = addons_roots if addons_roots is not None else detect_addons_roots()
    if not roots:
        raise FileNotFoundError(
            "No WoW AddOns path detected. Pass --saved-vars or --addons / set WOW_ADDONS."
        )

    candidates: list[Path] = []
    for addons in roots:
        retail = retail_root_from_addons(addons)
        wtf_accounts = retail / "WTF" / "Account"
        if not wtf_accounts.is_dir():
            continue
        for acct_dir in sorted(wtf_accounts.iterdir()):
            if not acct_dir.is_dir() or acct_dir.name == "SavedVariables":
                continue
            if account and acct_dir.name != account:
                continue
            sv = acct_dir / "SavedVariables" / "VendorMap.lua"
            if sv.is_file():
                candidates.append(sv)

    if not candidates:
        hint = f" (account={account})" if account else ""
        raise FileNotFoundError(
            f"No WTF/Account/*/SavedVariables/VendorMap.lua found under detected installs{hint}."
        )

    # Prefer the file with the most learned npc rows, then newest mtime.
    def score(p: Path) -> tuple[int, float]:
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
            learned_count = text.count('["npcID"]')
        except OSError:
            learned_count = 0
        return learned_count, p.stat().st_mtime

    candidates.sort(key=score, reverse=True)
    return candidates[0]


def load_repo_seed_index() -> dict[int, dict]:
    """npcID → seed vendor dict from core Data/ + packs/ (for override-only rows)."""
    by_npc: dict[int, dict] = {}
    core_parts: list[str] = []
    for p in sorted(CORE_DATA_DIR.glob("Seed_*.lua")):
        core_parts.append(p.read_text(encoding="utf-8"))
    if core_parts:
        for v in parse_export("\n".join(core_parts)):
            npc = v.get("npcID")
            if npc:
                by_npc[int(npc)] = v
    if PACKS_DIR.is_dir():
        for pack in sorted(PACKS_DIR.glob("VendorMap_Data_*")):
            for row in load_pack_vendors(pack):
                npc = row.get("npcID")
                if npc:
                    by_npc[int(npc)] = row
    return by_npc


def _clean_subtitle(subtitle) -> str | None:
    if not isinstance(subtitle, str):
        return None
    subtitle = subtitle.strip()
    if not subtitle or subtitle.lower() in _BAD_SUBTITLES:
        return None
    return subtitle


def _types_dict(raw) -> dict[str, bool]:
    if not isinstance(raw, dict):
        return {"general": True}
    out = {str(k): True for k, v in raw.items() if v is True}
    return out or {"general": True}


def vendor_from_learned(row: dict) -> dict | None:
    try:
        map_id = int(row["mapID"])
        x = float(row["x"])
        y = float(row["y"])
    except (KeyError, TypeError, ValueError):
        return None
    name = row.get("name") or "Unknown Vendor"
    v: dict = {
        "name": str(name),
        "mapID": map_id,
        "x": x,
        "y": y,
        "faction": str(row.get("faction") or "Neutral"),
        "types": _types_dict(row.get("types")),
    }
    npc = row.get("npcID")
    if npc is not None:
        try:
            v["npcID"] = int(npc)
        except (TypeError, ValueError):
            pass
    subtitle = _clean_subtitle(row.get("subtitle"))
    if subtitle:
        v["subtitle"] = subtitle
    specialty = sanitize_specialty_key(row.get("specialtyKey") if isinstance(row.get("specialtyKey"), str) else None)
    if specialty:
        v["specialtyKey"] = specialty
    note = sanitize_note(row.get("note") if isinstance(row.get("note"), str) else None)
    if note:
        v["note"] = note
    for key in ("repFactionID", "minStanding"):
        if row.get(key) is not None:
            try:
                v[key] = int(row[key])
            except (TypeError, ValueError):
                pass
    return v


def apply_override(vendor: dict, ov: dict) -> dict | None:
    """Apply override fields onto a vendor copy. Returns None if hidden."""
    if ov.get("hidden") is True:
        return None
    out = dict(vendor)
    if isinstance(ov.get("types"), dict) and ov["types"]:
        out["types"] = _types_dict(ov["types"])
    if isinstance(ov.get("faction"), str) and ov["faction"]:
        out["faction"] = ov["faction"]
    if isinstance(ov.get("name"), str) and ov["name"]:
        out["name"] = ov["name"]
    subtitle = _clean_subtitle(ov.get("subtitle"))
    if subtitle:
        out["subtitle"] = subtitle
    elif "subtitle" in ov and (ov.get("subtitle") == "" or ov.get("subtitle") is None):
        # Explicit clear — keep prior subtitle from learned/seed.
        pass
    specialty = sanitize_specialty_key(ov.get("specialtyKey") if isinstance(ov.get("specialtyKey"), str) else None)
    if specialty:
        out["specialtyKey"] = specialty
    elif ov.get("specialtyKey") == "auto":
        out.pop("specialtyKey", None)
    if "note" in ov:
        note = sanitize_note(ov.get("note") if isinstance(ov.get("note"), str) else None)
        if note:
            out["note"] = note
        elif ov.get("note") == "":
            out.pop("note", None)
    # iconPreset / iconCustom / learnedFrom stay out of seeds
    return out


def collect_import_vendors(learned: list[dict], overrides: dict, seed_index: dict[int, dict]) -> list[dict]:
    by_npc: dict[int, dict] = {}

    for row in learned:
        v = vendor_from_learned(row)
        if not v or not v.get("npcID"):
            continue
        npc = int(v["npcID"])
        ov = overrides.get(npc)
        if ov:
            merged = apply_override(v, ov)
            if merged is None:
                continue
            v = merged
        by_npc[npc] = v

    # Overrides that only retarget existing seed rows (no learned coords).
    for npc, ov in overrides.items():
        if npc in by_npc:
            continue
        seed = seed_index.get(npc)
        if not seed:
            continue
        merged = apply_override(seed, ov)
        if merged is None:
            continue
        by_npc[npc] = merged

    out = list(by_npc.values())
    out.sort(key=lambda v: (v["mapID"], v.get("npcID") or 0, v["x"], v["y"]))
    return out


def vendors_to_export_text(vendors: list[dict]) -> str:
    lines = [
        "-- VendorMap local learned import",
        "local _, ns = ...",
        "local A = ns.AddSeed",
        "",
    ]
    names: dict[int, str] = {}
    for v in vendors:
        if v.get("npcID") and v.get("name"):
            names[int(v["npcID"])] = v["name"]
        lines.append(format_seed_line(v, names).rstrip())
    lines.append("")
    lines.append(f"-- {len(vendors)} vendors")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--addons", help="Interface/AddOns path (otherwise deploy.sh --list)")
    ap.add_argument("--saved-vars", type=Path, help="Explicit path to WTF/.../VendorMap.lua")
    ap.add_argument("--account", help="WTF account folder name (e.g. 308434992#1)")
    ap.add_argument("--export-only", type=Path, metavar="FILE", help="Write A{...} export and exit")
    ap.add_argument("--dry-run", action="store_true", help="Parse and summarize without writing packs")
    args = ap.parse_args()

    addons_roots: list[Path] | None = None
    if args.addons:
        addons_roots = [Path(args.addons).expanduser().resolve()]
    elif not args.saved_vars:
        addons_roots = detect_addons_roots()

    try:
        sv_path = find_saved_variables(addons_roots, account=args.account, explicit=args.saved_vars)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 1

    print(f"SavedVariables: {sv_path}")
    learned, overrides = load_saved_variables(sv_path)
    print(f"Loaded {len(learned)} learned, {len(overrides)} overrides")

    seed_index = load_repo_seed_index()
    vendors = collect_import_vendors(learned, overrides, seed_index)
    if not vendors:
        print("Nothing to import (no usable learned/override vendors).", file=sys.stderr)
        return 1

    learned_ids: set[int] = set()
    for r in learned:
        if isinstance(r, dict) and r.get("npcID") is not None:
            try:
                learned_ids.add(int(r["npcID"]))
            except (TypeError, ValueError):
                pass
    override_only = sum(1 for v in vendors if v.get("npcID") not in learned_ids)
    print(f"Import candidates: {len(vendors)} ({override_only} override-on-seed only)")

    if args.export_only:
        text = vendors_to_export_text(vendors)
        args.export_only.write_text(text, encoding="utf-8")
        print(f"Wrote {args.export_only}")
        return 0

    if args.dry_run:
        print("Dry run — sample lines:")
        names: dict[int, str] = {}
        for v in vendors[:8]:
            if v.get("npcID") and v.get("name"):
                names[int(v["npcID"])] = v["name"]
            print(" ", format_seed_line(v, names).rstrip())
        if len(vendors) > 8:
            print(f"  ... ({len(vendors) - 8} more)")
        return 0

    return merge_vendors(vendors)


if __name__ == "__main__":
    raise SystemExit(main())
