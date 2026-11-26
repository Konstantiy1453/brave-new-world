# 1.12.0 — the live game beside the approved terrain and settlement frames

Every game frame here was taken from the running game (source project, Linux, GL Compatibility on
llvmpipe software rendering, 1920 x 1080) by `game/tests/art/capture_district.gd`,
`capture_world_23.gd` and `capture_boulder_lods.gd`. Evidence label: screenshot viewed. The approved
frames are the handoff's (`docs/handoff/approved-terrain-region/reference`).

The district is a played colony, not a staged one: seed 260129, the balanced bot for 900 days on
CC-GEO-2.3 (coastal site with a river; 37 buildings, 277 people, 16 vehicles). Its cameras are the
approved views' distances, pitches and fields of view (views.json), turned to the site's own sun as
the approved views are lit (sun about 17 degrees up, behind the camera).

| File | Left | Right |
|---|---|---|
| `cmp_settlement_dusk.webp` | approved 07 settlement (155.5 m, 15.7°, 43°) | the game, same camera, evening |
| `cmp_verge_dusk.webp` | approved 07 road verge (16.2 m, 11.3°, 46°) | the game, same camera, on a lane's verge |
| `cmp_rocks_dusk.webp` | approved 07 rocks (21.6 m, 17.2°, 39°) | the game, its largest boulder near town (approved Boulder 01 scan) |
| `cmp_overview_day.webp` | approved 06 region layout | the game's district view, day |
| `hours_*.webp` | | the game's day, evening and night, left to right |
| `cmp_world_eight_seeds.webp` | approved eight-world contact sheet | the game's satellite map of the same eight seeds (review driver, full daylight) |
| `globe_snow_260130.webp` | | seed 260130 on the globe (top) and the satellite map (bottom), the two reviewed snow sites |
| `boulder_01_details.webp` | | Boulder 01: approved 56,540-triangle scan, the 12,000 play mesh, 2,000 field and 220 chip, left to right |

Measured against the approved frames (whole-frame mean RGB, 0-255): settlement 95/95/87 approved,
100/98/77 game; verge 102/97/85 approved, 105/106/86 game (both before the final colour step).
The live district's median clear space between neighbouring buildings is 53.2 m (approved 59.62 m),
its built window 1,453.5 x 1,049.9 m with 37 buildings (approved 1,076.40 x 1,020.24 m with 19).
