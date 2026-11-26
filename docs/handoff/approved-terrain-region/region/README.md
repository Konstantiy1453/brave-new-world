# Approved inland district reference

Run this directory as an independent Godot 4.5.1 project. It contains the approved revision 06 street and building layout, revision 07 local terrain materials, rocks and roadside treatment, and the working inland reference scene. The scene uses the high-detail building and vehicle meshes from the project art reserve. The 19 buildings in this scene are an art and scale fixture. In the game, the settlement simulation and save determine which buildings exist.

## View and reproduce

Open `project.godot`, or run these commands from this directory. The executable on some systems is named `godot4`. Forward+ with a graphics device reproduces the approved lighting. The headless command constructs the scene, loads its resources, and checks the reference counts.

```sh
godot --path .
godot --headless --path . -- --validate
godot --path . --rendering-method forward_plus -- --capture settlement --output captures
godot --path . --rendering-method forward_plus -- --capture rocks --output captures
godot --path . --rendering-method forward_plus -- --capture verge --output captures
```

The viewer starts on the settlement view. Press **1** for the rock group, **2** for the settlement and **3** for the road shoulder. Each capture writes one 3840 × 2160 PNG. Use the three named captures for a camera-matched comparison. `REFERENCE_CHECK.json` records the tested engine, renderer and image hashes. For the checks recorded here, all three captures from a clean checkout and all three captures from the standalone PCK matched the approved PNGs byte for byte on the listed GPU. Output can vary across graphics devices.

## Bring the approved scene into gameplay

| Component | Working reference | Integration requirement |
|---|---|---|
| Metric layout | `assets/space06/positions06.json` and `assets/space06/streets06.gd` | Preserve world-space building centers, original extents, road widths and curved approaches for the reference town. Feed occupancy, building kind and persistent identity from actual game state. Keep existing plot IDs stable across save/load. |
| Surface and vegetation | `assets/surface07/terrain07.gd`, `soil/` and `lowgrass.gd` | Use one continuous terrain across the built-up area and its surroundings. Match soil, packed earth, gravel, sparse grass, foothills and far ridges. The terrain reference converts local horizontal coordinates to metres by **4.68** and vertical coordinates by **2.4**. Building placements and road widths are already in metres. |
| Rock geometry and materials | `assets/surface07/rock07.gd` and `rock_assets/` | Keep weathered boulders partly buried, with gravel at their feet, and retain layered outcrops on distant slopes. Carry the texture sampler, normal, roughness, orientation, burial and placement clearance into the game. |
| Road shoulder | `assets/surface07/fringe/road_fringe.png`, sampled by `soil/soil07.gdshader` | The supplied 0.25 m per pixel mask is aligned to this particular town. For a different road network, rebuild the packed-soil and gravel channels from that network’s actual paving. Preserve walkways and avoid a rectangular outline around the town. |
| High-detail models | `assets/artpreview/art/region_assets.gd` and `assets/scale02/assets_fix/` | Use the approved metre-calibrated building and high-detail vehicle meshes at near range. Apply the cropped foundations after measuring the original meshes. Preserve activity, construction states, selections, vehicle simulation and sensible distant LODs. |
| Camera and composition | `views.json`, `preview.gd` | Match the three reference compositions, exposure, road-relative vehicle positions and camera scale. Keep normal gameplay camera and HUD controls. |

At the v1.11.1 base, `game/world/region_view.gd` builds the colony, free plots, roads and harbor, and `game/world/region_ground.gd` builds terrain, river, sea and nature. Connect the reference to those live paths. Use the saved or generated site's actual hydrology to decide whether to show a coast, river, lake or harbor. Preserve access to buildable plots through selection and construction tools while suppressing the visible hexagonal pads in the close view.

The reference has **19** buildings and **5** vehicles on **4** roads. Selected nearest-neighbor exterior-to-exterior clearances on the approved layout include **12.70 m** for the processor and power facility and **29.98 m** for the neighboring pair of houses identified in the approved measurements. Road travel, building construction, hydrology and save migration are integration tests for the game.

Carry `reference_io.gd`, the 24 checked-in `.png.import` and `.jpg.import` files using `importer="keep"`, and the raw-file inclusion filters in `export_presets.cfg` into the live game. The shader and loader supply their own sampling and mipmaps. Textures, shaders and geometry are included locally. The packed reference supports `--validate` and the same capture CLI. Any new asset-root prefix in the live game must cover scripts, materials, textures, binary streams and JSON inputs together. The assignment of high, field and chip meshes deserves profiling on the lowest supported graphics profile. In particular the supplied `boulder_01` mesh currently contains 56,540 triangles in all three detail files. Preserve the close view and simplify the field and chip tiers as needed. Verify the exported game on a dry inland save, a water-bearing site and a newly generated world.

Runtime media provenance and third-party notices are supplied alongside this document.


### Rebuild the road shoulder cutout

To reproduce the fixture mask, run these commands from the reference project. The Python authoring step uses NumPy and OpenCV. It writes a PNG and diagnostic JSON in the output directory and checks the mask against points on each pavement surface.

```sh
godot --headless --path . --script tools/export_paving.gd -- /path/to/temporary-paving-output
python tools/bake_road_fringe.py /path/to/temporary-paving-output
```

For another district, replace the reference-plan construction in the extractor with the actual built road mesh nodes. Use the same physical X/Z extent and coordinate transform for both the mask generator and the consuming shader. The supplied inland fixture uses a 1280 by 640 metre area starting at (-640, -400).
