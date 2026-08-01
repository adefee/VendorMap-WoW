#!/usr/bin/env bash
# Symlink the in-repo LoD data packs (packs/VendorMap_Data_*) back to top-level
# AddOns/ folders so WoW can load them locally. LoadOnDemand addons must live at
# the top level of Interface/AddOns/; in the repo they live under packs/ and are
# re-homed for release via .pkgmeta move-folders.
#
# Usage:
#   tools/link_packs.sh          # create/refresh symlinks
#   tools/link_packs.sh --clean  # remove the symlinks
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
ADDON_NAME="$(basename "$ADDON_DIR")"
ADDONS_ROOT="$(cd "$ADDON_DIR/.." && pwd)"
PACKS_DIR="$ADDON_DIR/packs"

if [[ ! -d "$PACKS_DIR" ]]; then
    echo "No packs/ directory found at $PACKS_DIR" >&2
    exit 1
fi

clean=0
[[ "${1:-}" == "--clean" ]] && clean=1

for pack in "$PACKS_DIR"/VendorMap_Data_*; do
    [[ -d "$pack" ]] || continue
    name="$(basename "$pack")"
    link="$ADDONS_ROOT/$name"

    if [[ $clean -eq 1 ]]; then
        if [[ -L "$link" ]]; then
            rm "$link"
            echo "unlinked $name"
        fi
        continue
    fi

    if [[ -e "$link" && ! -L "$link" ]]; then
        echo "skip $name: $link exists and is not a symlink" >&2
        continue
    fi
    rm -f "$link"
    ln -s "$ADDON_NAME/packs/$name" "$link"
    echo "linked $name"
done

echo "Done."
