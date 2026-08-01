# VendorMap

VendorMap shows vendor, repair, barber, and other utility NPC locations directly on the world map and minimap, with per-type filters. It is fully standalone: **no HandyNotes or other addons are required**. VendorMap also *learns* from your discoveries: when you interact with a vendor, its category and details are updated to be current (and you can optionally override icons, notes, or other details as desired). Your Learned data can be easily exported to share with others or to submit here to make the addon data better for everyone.

## Features

- World-map and minimap pins for a wide range of NPC types: repair, reagents, food & drink, poisons, ammunition, mounts, stable masters, transmog, decor/housing, professions, faction/reputation, innkeepers, barbers, and general goods.
- Customize vendor icons by category, or add vendor-specific overrides for icons, notes, categories, and more.
- Filter button on the world map to toggle types and factions.
- **Learning**: vendors are recorded automatically on `MERCHANT_SHOW` / `GOSSIP_SHOW`
(safe under Midnight secret-value rules).
- **Overrides**: right-click any pin to edit or hide it.
- Waypoint routing via WaypointUI, TomTom, or the built-in Blizzard waypoint.
- Settings under three tabs in your Settings > Addons list: Basic, Vendors & Icons, and Data Management.
- Data is split into `packs` based on contintent for your memory optimization pleasaure.



> Current data set has been sourced from a variety of other addons (including ATT) and data my copy of the addon has learned while I've explored the world. I've made it easy to export data your VendorMap learns as you interact with vendors - submit your "learnings" here so we can update the seed data and improve everyone's maps!


## Why?
I've only actively played WoW a few months, but my single biggest pain point is the world map: I understand it's nostalgic, but I don't like spending my time having to Google where my nearest X type of vendor is, flying around an entire area, or always going to a major city. I want to be efficient with my time and spend more time doing what I want to do, not searching for the vendor I want.

I've seen some addons made for specific subsets of addons, and some addons that build on top of HandyNotes. I didn't want to always have to have HandyNotes, and while I use ATT and it has a lot of vendor data, it's focused around completions (achieves, etc), not map utility.

So, VendorMap tries to fill this gap: it's sole purpose is to add vendor locations on the map (and minimap, optionally). 

## Installation

### CurseForge (recommended)

Install "VendorMap" from CurseForge / the CurseForge app. The download includes the core
addon and all continent data packs.

### Manual

1. Download the latest release zip.
2. Extract it into `World of Warcraft/_retail_/Interface/AddOns/`.
  You should end up with `Interface/AddOns/VendorMap/` alongside the
   `Interface/AddOns/VendorMap_Data_*/` continent packs.
3. Restart the game or reload (`/reload`).



### Optional dependencies

- [TomTom](https://www.curseforge.com/wow/addons/tomtom) for arrow routing
(VendorMap falls back to the Blizzard waypoint if not presnet).
- [TomTom](https://www.curseforge.com/wow/addons/waypointui) for arrow routing
(VendorMap falls back to the Blizzard waypoint if not present).



## Usage

- Open the world map and use the **VendorMap filter button** to choose which vendor types
and factions are shown.
- Visit merchants and gossip NPCs normally — VendorMap learns their location automatically.
- **Right-click a pin** to edit its types, note, faction, or hide it.
- Configure everything from the settings panel (Esc → Options → AddOns → VendorMap, the
addon compartment icon, or `/vendormap`).



### Slash commands


| Command               | Action                                                     |
| --------------------- | ---------------------------------------------------------- |
| `/vendormap` or `/vm` | Open the settings panel                                    |
| `/vm toggle`          | Enable/disable VendorMap                                   |
| `/vm status`          | Print version, vendor/learned counts, and loaded packs     |
| `/vm refresh`         | Rebuild the database and refresh pins                      |
| `/vm export`          | Export your learned vendors + overrides (for contributing) |
| `/vm debug`           | Print diagnostic world-map registration info               |




## Data packs

Continent vendor data ships as **LoadOnDemand** sibling addons named
`VendorMap_Data_<Continent>` (Eastern Kingdoms, Kalimdor, Outland, Northrend, Pandaria,
Draenor, Broken Isles, Zandalar, Kul Tiras, The Maelstrom, Shadowlands, Dragon Isles,
Khaz Algar, and Other). Each pack loads only when you open a map on that continent, so
memory stays low. The core addon always ships the capital, hub, and decor seeds.

## Contributing vendor data

The database grows through player submissions. If VendorMap has learned vendors the shared
data is missing, please share them:

1. In game, run `/vm export` (or use **Settings → Data Management → Export**).
2. Your learned vendors and overrides are copied to the clipboard and shown in a window as
  `A{ ... }` seed lines.
3. Open a [vendor submission issue](../../issues/new?template=vendor-export.yml) and paste
  the exported block. That's it — a maintainer will merge it into the right pack.

Prefer to open a PR? See `[.github/PULL_REQUEST_TEMPLATE/vendor_data.md](.github/PULL_REQUEST_TEMPLATE/vendor_data.md)`.
Maintainers merge exports into packs with:

```bash
python3 tools/merge_export_to_seeds.py path/to/export.lua
# or paste via stdin:
python3 tools/merge_export_to_seeds.py -

# Or pull learned/overrides straight from your local WoW SavedVariables:
python3 tools/import_local_learned.py              # detect install → merge into packs/
python3 tools/import_local_learned.py --dry-run    # preview without writing
```

`import_local_learned.py` uses `tools/deploy.sh --list` to find your retail
AddOns path, then reads `WTF/Account/*/SavedVariables/VendorMap.lua`. Quit WoW
(or wait for a save) first so learned data is flushed to disk.



## Development

The repository is laid out as the core addon plus in-repo data packs:

```
VendorMap/
  VendorMap.toc          # core addon
  *.lua / *.xml          # core code
  Data/                  # always-loaded capital/hub/decor seeds
  packs/                 # LoD continent packs (VendorMap_Data_*)
  tools/                 # Python data tooling + helpers
  .pkgmeta               # BigWigs packager config (bundles core + packs)
```



### Local testing (deploy to WoW)

Copy the addon into your retail `Interface/AddOns` folder (and refresh LoD pack
symlinks):

```bash
tools/deploy.sh              # auto-detect AddOns path
tools/deploy.sh --list       # show detected candidates
tools/deploy.sh --addons "/path/to/_retail_/Interface/AddOns"
WOW_ADDONS="/path/to/_retail_/Interface/AddOns" tools/deploy.sh
```

Then `/reload` in-game. Auto-detect checks common Battle.net, Wine/Lutris,
Steam Proton, and WSL paths; override with `--addons` or `WOW_ADDONS` if needed.

If the repo itself already lives under `Interface/AddOns/VendorMap`, you only
need the pack symlinks:

```bash
tools/link_packs.sh          # create symlinks in Interface/AddOns/
tools/link_packs.sh --clean  # remove them
```



### Regenerating data from AllTheThings

`tools/extract_att_vendors.py` bakes vendor coordinates from a local AllTheThings install
into `packs/`. ATT is an extract-time source only — shipped seeds are standalone and do not
require ATT at runtime.

## Releases

Pushing to `main` triggers `.github/workflows/release.yml`, which:

1. Bumps the patch version across the core TOC, `Constants.lua`, every pack TOC, and the
  extractor.
2. Commits `chore: release vX.Y.Z [release]` and tags `vX.Y.Z`.
3. Runs the [BigWigs packager](https://github.com/BigWigsMods/packager) to build a single
  zip (core + all packs) and upload it to CurseForge.

To enable CurseForge uploads, set the repository secret `CF_API_KEY` and replace the
`## X-Curse-Project-ID:` value in `VendorMap.toc` with your CurseForge project id.