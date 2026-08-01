# Vendor data contribution

Thanks for contributing to the VendorMap database!

## What's in this PR

<!-- Briefly describe which continents/zones or vendors this adds or corrects. -->

## How the data was obtained

- [ ] Exported in game via `/vm export` or **Settings → Data Management → Export**
- [ ] Merged into packs with `python3 tools/merge_export_to_seeds.py <export>`
- [ ] Hand-edited pack seed lines (please explain below)

<!-- If hand-edited or sourced elsewhere, explain how you verified the coordinates. -->

## Checklist

- [ ] Changes are limited to `packs/VendorMap_Data_*/` (and/or `Data/Seed_*.lua`).
- [ ] I did **not** bump any `## Version:` fields — the release workflow owns versioning.
- [ ] Seed lines follow the `A{ name=..., npcID=..., mapID=..., x=..., y=..., faction=..., types={...} }` format.

<!--
Tip: if you'd rather not run the merge tool yourself, open a "Submit learned vendors"
issue instead and just paste your export block. A maintainer will merge it.
-->
