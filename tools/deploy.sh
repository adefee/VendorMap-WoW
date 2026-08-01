#!/usr/bin/env bash
# Sync this repo into World of Warcraft's Interface/AddOns for local testing.
#
# Copies the core addon to AddOns/VendorMap/ (excluding tooling / VCS noise),
# then creates top-level VendorMap_Data_* symlinks so LoD packs load.
#
# Usage:
#   tools/deploy.sh                         # auto-detect AddOns path
#   tools/deploy.sh --addons /path/to/AddOns
#   WOW_ADDONS=/path/to/AddOns tools/deploy.sh
#   tools/deploy.sh --dry-run
#   tools/deploy.sh --list                  # print detected candidates and exit
#
# Resolution order: --addons, $WOW_ADDONS, then auto-detect common installs
# (native Windows/macOS Battle.net, Wine/Lutris, Steam Proton, WSL mounts).
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
ADDON_NAME="VendorMap"

ADDONS_ROOT=""
DRY_RUN=0
LIST_ONLY=0
candidates=()
pending_mkdir=()

usage() {
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

# Collect common WoW retail AddOns locations for the current OS / wine setups.
collect_candidates() {
    candidates=()
    local home="${HOME:-}"
    local roots=()
    local r drive steam pfx

    # --- Explicit / well-known install roots ---
    roots+=(
        "/Applications/World of Warcraft"
        "$home/Applications/World of Warcraft"
        "$home/Games/world-of-warcraft"
        "$home/Games/World of Warcraft"
        "$home/.wine/drive_c/Program Files (x86)/World of Warcraft"
        "$home/.wine/drive_c/Program Files/World of Warcraft"
        "$home/.local/share/wine-prefixes/wow/drive_c/Program Files (x86)/World of Warcraft"
    )

    # Windows native (Git Bash / MSYS) and WSL drive mounts
    for drive in c d e; do
        local upper="${drive^^}"
        roots+=(
            "/${drive}/Program Files (x86)/World of Warcraft"
            "/${upper}/Program Files (x86)/World of Warcraft"
            "/${drive}/Program Files/World of Warcraft"
            "/${upper}/Program Files/World of Warcraft"
            "/${drive}/World of Warcraft"
            "/${upper}/World of Warcraft"
            "/mnt/${drive}/Program Files (x86)/World of Warcraft"
            "/mnt/${drive}/Program Files/World of Warcraft"
            "/mnt/${drive}/World of Warcraft"
        )
    done

    # Lutris / Bottles game dirs often live under ~/Games or similar
    for r in "$home/Games" "$home/lutris" "$home/.local/share/lutris/games" "$home/.local/share/bottles/bottles"; do
        [[ -d "$r" ]] || continue
        while IFS= read -r -d '' pfx; do
            roots+=("$pfx")
            # Bottles / Wine prefixes: WoW may be under drive_c
            roots+=(
                "$pfx/drive_c/Program Files (x86)/World of Warcraft"
                "$pfx/drive_c/Program Files/World of Warcraft"
                "$pfx/drive_c/World of Warcraft"
            )
        done < <(find "$r" -maxdepth 4 \( -iname 'world of warcraft' -o -iname 'wow' \) -type d -print0 2>/dev/null || true)
    done

    # Steam Proton prefixes (WoW via Battle.net inside a Proton/Steam app)
    for steam in \
        "$home/.local/share/Steam" \
        "$home/.steam/steam" \
        "$home/.steam/root" \
        "$home/.var/app/com.valvesoftware.Steam/.local/share/Steam"
    do
        [[ -d "$steam/steamapps/compatdata" ]] || continue
        while IFS= read -r -d '' pfx; do
            roots+=(
                "$pfx/drive_c/Program Files (x86)/World of Warcraft"
                "$pfx/drive_c/Program Files/World of Warcraft"
                "$pfx/drive_c/World of Warcraft"
            )
        done < <(find "$steam/steamapps/compatdata" -mindepth 2 -maxdepth 2 -type d -name 'pfx' -print0 2>/dev/null || true)
    done

    # Resolve each root -> _retail_/Interface/AddOns (canonicalize to collapse Steam symlinks)
    local seen="|"
    for r in "${roots[@]}"; do
        [[ -d "$r" ]] || continue
        local addons="$r/_retail_/Interface/AddOns"
        local iface="$r/_retail_/Interface"
        # Interface exists but AddOns was never created — still a valid target.
        if [[ ! -d "$addons" && -d "$iface" ]]; then
            addons="$iface/AddOns"
        fi
        [[ -d "$addons" || -d "$iface" ]] || continue

        local key
        if [[ -d "$addons" ]]; then
            key="$(readlink -f "$addons" 2>/dev/null || printf '%s' "$addons")"
        else
            # Not created yet: canonicalize parent Interface/, then append AddOns
            local iface_real
            iface_real="$(readlink -f "$iface" 2>/dev/null || printf '%s' "$iface")"
            key="$iface_real/AddOns"
            addons="$key"
            pending_mkdir+=("$addons")
        fi

        case "$seen" in
            *"|$key|"*) continue ;;
        esac
        seen+="$key|"
        candidates+=("$key")
    done
}

# Pick the best AddOns directory from candidates.
# Preference: already has VendorMap > most recently modified > first found.
select_candidate() {
    local best="" best_score=-1 score mtime
    local c
    if [[ ${#candidates[@]} -eq 0 ]]; then
        return 1
    fi
    if [[ ${#candidates[@]} -eq 1 ]]; then
        ADDONS_ROOT="${candidates[0]}"
        return 0
    fi

    for c in "${candidates[@]}"; do
        score=0
        [[ -f "$c/$ADDON_NAME/VendorMap.toc" ]] && score=$((score + 100))
        # Prefer installs that already have other addons (active play install)
        if find "$c" -maxdepth 2 -name '*.toc' -print -quit 2>/dev/null | grep -q .; then
            score=$((score + 10))
        fi
        mtime=$(stat -c %Y "$c" 2>/dev/null || stat -f %m "$c" 2>/dev/null || echo 0)
        score=$((score + (mtime / 1000000))) # weak recency tie-break
        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best="$c"
        fi
    done

    ADDONS_ROOT="$best"
    echo "Multiple AddOns directories found; using:" >&2
    echo "  $ADDONS_ROOT" >&2
    echo "Others:" >&2
    for c in "${candidates[@]}"; do
        [[ "$c" == "$ADDONS_ROOT" ]] && continue
        echo "  $c" >&2
    done
    echo "Override with --addons or WOW_ADDONS." >&2
}

resolve_addons_root() {
    if [[ -n "$ADDONS_ROOT" ]]; then
        return 0
    fi
    if [[ -n "${WOW_ADDONS:-}" ]]; then
        ADDONS_ROOT="$WOW_ADDONS"
        return 0
    fi

    collect_candidates
    if [[ $LIST_ONLY -eq 1 ]]; then
        if [[ ${#candidates[@]} -eq 0 ]]; then
            echo "No WoW retail AddOns directories detected." >&2
            exit 1
        fi
        printf '%s\n' "${candidates[@]}"
        exit 0
    fi

    if ! select_candidate; then
        echo "Could not auto-detect a WoW retail AddOns directory." >&2
        echo "Pass --addons /path/to/Interface/AddOns or set WOW_ADDONS." >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --addons)
            [[ $# -ge 2 ]] || { echo "--addons requires a path" >&2; exit 1; }
            ADDONS_ROOT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --list)
            LIST_ONLY=1
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

if [[ ! -f "$REPO_DIR/VendorMap.toc" ]]; then
    echo "VendorMap.toc not found in $REPO_DIR" >&2
    exit 1
fi

resolve_addons_root

# Create AddOns/ when we detected Interface/ but the folder was missing.
if [[ ! -d "$ADDONS_ROOT" ]]; then
    local_should_create=0
    for pending in "${pending_mkdir[@]}"; do
        if [[ "$pending" == "$ADDONS_ROOT" ]]; then
            local_should_create=1
            break
        fi
    done
    if [[ $local_should_create -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "Would create $ADDONS_ROOT"
        else
            mkdir -p "$ADDONS_ROOT"
            echo "Created $ADDONS_ROOT"
        fi
    fi
fi

if [[ ! -d "$ADDONS_ROOT" ]]; then
    echo "AddOns directory does not exist: $ADDONS_ROOT" >&2
    echo "Pass --addons /path/to/Interface/AddOns or set WOW_ADDONS." >&2
    exit 1
fi

DEST="$ADDONS_ROOT/$ADDON_NAME"

RSYNC=(rsync -a --delete)
if [[ $DRY_RUN -eq 1 ]]; then
    RSYNC+=(--dry-run --itemize-changes)
fi

# Match .pkgmeta ignore list + keep packs/ (needed for LoD symlinks).
EXCLUDE=(
    --exclude '.git/'
    --exclude '.github/'
    --exclude '.gitignore'
    --exclude '.pkgmeta'
    --exclude 'README.md'
    --exclude 'LICENSE'
    --exclude 'tools/'
    --exclude '.release/'
    --exclude '*.zip'
    --exclude '__pycache__/'
    --exclude '*.pyc'
    --exclude '.DS_Store'
    --exclude '*.swp'
)

echo "Deploying $REPO_DIR -> $DEST"
"${RSYNC[@]}" "${EXCLUDE[@]}" "$REPO_DIR/" "$DEST/"

if [[ $DRY_RUN -eq 1 ]]; then
    echo "Dry run only; pack links not changed."
    exit 0
fi

# LoD packs must sit at AddOns/ top level. Prefer symlinks into VendorMap/packs/
# (same layout as tools/link_packs.sh when the addon lives under AddOns/).
PACKS_DIR="$DEST/packs"
if [[ ! -d "$PACKS_DIR" ]]; then
    echo "No packs/ directory at $PACKS_DIR after sync" >&2
    exit 1
fi

for pack in "$PACKS_DIR"/VendorMap_Data_*; do
    [[ -d "$pack" ]] || continue
    name="$(basename "$pack")"
    link="$ADDONS_ROOT/$name"

    if [[ -e "$link" && ! -L "$link" ]]; then
        echo "skip $name: $link exists and is not a symlink" >&2
        continue
    fi
    rm -f "$link"
    ln -s "$ADDON_NAME/packs/$name" "$link"
    echo "linked $name"
done

echo "Done. Reload UI in-game (/reload) to pick up changes."
