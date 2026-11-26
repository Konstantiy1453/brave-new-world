# Integrate and release the approved world and settlement upgrade

Implement this upgrade in `Konstantiy1453/brave-new-world` and deliver a new playable Windows x64 version of **Colony Charter**.

## Start from the correct game

1. Fetch `codex/approved-terrain-and-region` and `v17-charter`. The handoff lives in `docs/handoff/approved-terrain-region/`. Its base is the verified 1.11.1 game at `96d26551623c6b7c84a9db4143ce38956c11f6a4`. Start a feature branch from the handoff, or bring its files onto a newer compatible development tip. Preserve subsequent game changes.
2. Install Git LFS and retrieve the assets. After checkout, run `git lfs pull --include="docs/handoff/approved-terrain-region/**,game/**"`, then `python docs/handoff/approved-terrain-region/verify_package.py`. Read the repository's current `CLAUDE.md`, the map notes in this handoff, and the regional project's README. Run the regional reference in Godot 4.5.1 before editing the production game.
3. Use the approved images in `reference/` to judge the result. They establish the targets for terrain, scale, materials and lighting. The implementation must work through the game's ordinary New Expedition, world map, settlement and construction screens.

## Integrate the world generator

Use the supplied CC-GEO-2.3 geography for new expeditions, including its seeded landforms, drainage, coastlines and basin handling. Apply the final snow treatment to both the satellite map and globe. Carry the same geography into landing-site queries and regional water decisions. Rivers should depend on real drainage and viewing scale. High mountains and sufficiently cold high plateaus should read as high ground, with climate and latitude determining snow cover. Keep the range of gentle, dry, lowland and rugged worlds shown in the reference seeds.

Preserve the generator identity and stored settlement locations when loading earlier saves. Version the relevant caches so old atlas pixels cannot mask new generation. Verify repeatability with the same seed and variety across different seeds, including the reviewed 260130 mountain/plateau case.

## Integrate regional layout and materials

Use revision 06 for building scale, spacing, terrain proportions and the road network. Use revision 07 for the paved-road appearance, compacted shoulders, gravel, sparse grass, weathered boulders and partly embedded stone fragments. Keep the original layered rock on distant slopes. Near-camera buildings and vehicles should use the detailed models. Keep road widths, including the 8.60 m main road, in metres.

The supplied inland district contains 19 buildings and five vehicles. Its buildable reference window is 1,076.40 by 1,020.24 m. The measured median clear space between neighbouring models is 59.62 m. These already include the approved spacing changes. Use the scene to calibrate the production renderer, and build live districts from the player's actual buildings, terrain, roads and construction state. Preserve building identity, economy, selection, movement and placement across save/load. Keep outskirts continuous with the town. Use the world's local coast, lake and river data for water. Show any placement aid only when relevant to construction, and keep ordinary building views free of hexagonal pads.

Port the standalone resources into `game/`, including shaders, meshes and import settings. Confirm the exported PCK resolves every runtime asset. Preserve the high-detail appearance at close range and share or simplify geometry at distance. In particular, measure the three shipped `boulder_01` reference meshes: they carry identical high-detail geometry. Supply real lower-cost field and chip meshes for the live game and compare close-range appearance afterwards. Carry the supplied art credits and terrain data acknowledgments into the distributed game or release package, including the terrain CREDITS.txt.

## Prove and deliver the release

- Run the repository's applicable geography, world, region, construction, save/migration and regression suites. Play through New Expedition, landing selection, opening a settlement, building placement, saving and reloading. Check an inland dry site and a genuine coastal or river site.
- Take in-game daylight and dusk/night captures, including satellite, globe, settlement, rock and road-verge views. Compare the approved dusk targets at equivalent camera settings. Verify materials, scale, water and placement in both the default Compatibility renderer and the supported high-quality mode. Record cold region entry and frame times for the same representative populated save, with hardware, renderer and resolution.
- Increment the version consistently across the game, changelog and packaging. Use **1.12.0** if still available and consistent with the repository's current version scheme. Build the actual Windows x64 distribution, launch the packaged game and check the production paths. If a Windows host is unavailable, state exactly which exported PCK/platform checks ran and which Windows checks still require a host.
- Push the implementation and deliver the new version through the project's normal release workflow. Return the implementation commit and PR if used, the version and download link, SHA-256 for the Windows package, representative screenshots, test and frame-time results, and any remaining platform-specific limitations. Preserve existing releases.
