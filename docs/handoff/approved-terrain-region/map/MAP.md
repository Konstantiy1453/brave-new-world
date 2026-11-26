# CC-GEO-2.3 world terrain

The approved eight worlds were rendered in Godot 4.5.1 from the playable game. Seeded geography, hydrology and shading are all present in these patches. New expeditions use CC-GEO-2.3. Save loading selects the recorded geography version. The agreed visual targets are the [eight-world contact sheet](../reference/world-eight-seeds.webp) and [seed 260130 mountain and plateau detail](../reference/world-snow-detail.webp).

## Integrate

The tested base is game version 1.11.1, commit `96d26551623c6b7c84a9db4143ce38956c11f6a4`. Use this sequence from the repository root in Bash or Git Bash. Install Git LFS and Godot 4.5.1 with its Windows export templates. For a newer development base, merge equivalent changes into its current files and retain subsequent game changes. The source hashes identify the exact 1.11.1 reference.

```bash
set -e
M="$PWD/docs/handoff/approved-terrain-region/map"
git lfs pull --include="game/**"
for patch in "$M/01-cc-geo-2.3.patch" "$M/02-alpine-snow.patch"; do
    git apply --binary --ignore-space-change --check "$patch"
    git apply --binary --ignore-space-change "$patch"
done
python "$M/verify_payload.py" --root .
```

1. **Seeded terrain**. Patch 01 adds irregular continental margins, local elevation samples and drainage derived from that elevation. Land/water at landing sites and both map projections use the same surface. The flat map initialization binds its optical material as soon as the shader is assigned. Keep that first binding as well as the globe binding and the export filter for `assets/terrain_v3/*.bin`. The two PNG textures respect the repository's LFS rules when staged. The whitespace option accommodates CRLF in the baseline export preset.
2. **Mountain and plateau snow**. Patch 02 changes `game/world/shaders.gd`. The shader measures local and wider elevation gradients. Snow retention varies with elevation, temperature, moisture, slope and aspect. Dry plateaus expose rock, cold wet uplands retain broader snow, and steep faces show exposed stone. Both globe and flat satellite use this shader treatment. The snow change does not consume the seed or alter geography hashes.
3. **Regional integration**. Ask `Hydrology.sample_water(world, lat, lon)` on 2.3 worlds and consult the actual nearby coastline or drainage for local visible water. Terrain shown here supplies the map and its data. Wire the regional camera, lots, streets and materials through the companion regional handoff.
4. **Attribution**. The patch adds `game/assets/terrain_v3/CREDITS.txt`. Include it as a readable third-party notice alongside the release or in the game's credits. The default Godot export preset explicitly includes the binary relief data and does not select text notices. [Source details and reuse terms](TERRAIN-DATA-NOTICE.md)

## Reproduce the terrain and save checks

Use a dedicated QA profile before launch. The commands below set a Windows AppData sandbox when run under Git Bash and XDG directories for Linux. The legacy fixture is a synthetic, day-zero capital settlement created in stock 1.11.1 with seed 260129.

```bash
GODOT_BUILD_APPDATA="$APPDATA"
Q="$(mktemp -d)"
if command -v cygpath >/dev/null; then
    M="$(cygpath -am "$M")"
    Q="$(cygpath -am "$Q")"
fi
export APPDATA="$Q/profile" LOCALAPPDATA="$Q/cache"
export XDG_DATA_HOME="$Q/data" XDG_CACHE_HOME="$Q/cache" XDG_CONFIG_HOME="$Q/config"
mkdir -p "$APPDATA" "$LOCALAPPDATA" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
godot --headless --editor --path game --import
godot --headless --path game --script res://tests/terrain23_career.gd -- "--old-save=$M/fixtures/legacy-260129.save"
godot --headless --path game --script res://tests/terrain_water23.gd
godot --headless --path game --script res://tests/terrain23_sites.gd
export TERRAIN_REVIEW_OUT="$Q/review"
godot --path game --rendering-method gl_compatibility -- --dev "--dev-script=$M/render_review.gd"
python "$M/verify_payload.py" --root . --renders "$TERRAIN_REVIEW_OUT"
```

Worlds are size 1 with the normal capital opening. The driver captures the flat game's bound orbital material at 2048 × 1024, with visual overlays disabled. At cold startup the game can display a temporary atlas. Wait for background refinement and the bound 1536 × 768 atlas before taking comparison images. All eight gameplay hashes must match. On the recorded reference system, adding `--exact-png` also confirmed the entire PNG files were byte-identical to the approved captures. Driver, renderer and color differences can affect pixel comparison on other systems.

## Exercise the exported Windows build

Use the normal Godot profile with installed export templates for the build. The second command starts the exported game in a fresh QA profile and drives the menu, globe, landing panel, flat map and old-save loader. In a Bash shell on Windows, retain `M` and `Q` from above. `GODOT_BUILD_APPDATA` was captured above and points to the normal Windows profile containing export templates.

```bash
mkdir -p "$Q/build" "$Q/export-profile"
APPDATA="$GODOT_BUILD_APPDATA" godot --headless --path game --export-release "Windows Desktop" "$Q/build/ColonyCharter.exe"
export APPDATA="$Q/export-profile" TERRAIN_QA_OUT="$Q/export-results"
export TERRAIN_QA_SEED=260130 TERRAIN_OLD_SAVE="$M/fixtures/legacy-260129.save"
check_script="$(cygpath -am "$PWD/game/tests/terrain23_export.gd")"
"$Q/build/ColonyCharter.exe" --rendering-method gl_compatibility -- --dev "--dev-script=$check_script"
```

Read `export-results/export.json` and inspect its globe and satellite frames. The reference run started with a cold preview, finished refinement in 4.96 seconds on one RTX 4070 Laptop GPU, displayed all 29 recommended sites on land, switched via the normal landing panel, and loaded the original 2.2 save. Release acceptance also needs the regional rendering and gameplay checks after integration. The [verification record](validation.json) covers this world-terrain component.
