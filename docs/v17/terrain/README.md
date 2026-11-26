# 1.12.0 — the live game beside the approved terrain and settlement frames

Every game frame here was taken from the running game (source project, Linux, GL Compatibility on
llvmpipe software rendering, 1920 x 1080) by `game/tests/art/capture_district.gd`,
`capture_world_23.gd` and `capture_boulder_lods.gd`. Evidence label: screenshot viewed. The approved
frames are the handoff's (`docs/handoff/approved-terrain-region/reference`). Forward+ frames of the
same views are in the release evidence (see `PROGRESS.md`).

Two played colonies, both CC-GEO-2.3, both built by the balanced bot from a new expedition:

- **coast**: seed 260129, 900 days, a coastal highland site with a river (3.8°S, 3,140 m, 4.7 °C):
  37 buildings, 277 people, 16 vehicles.
- **inland**: seed 260133, an arid placed site with no coast, river or lake under it (28.75°N,
  296 m, 14.9 °C, rainfall 0.12), founded where the ground panel allowed (no recommended site on
  this seed is temperate, inland and river-free). The colony stalled: 5 buildings and 25 people
  when its game ended on day 626. Two rivers of the planet's drainage cross its district.

Cameras are the approved views' distances, pitches and fields of view (views.json), turned to the
site's own sun as the approved views are lit (sun about 17 degrees up, behind the camera).

| File | Left | Right |
|---|---|---|
| `cmp_<site>_settlement_dusk.webp` | approved 07 settlement (155.5 m, 15.7°, 43°) | the game, same camera, evening |
| `cmp_<site>_verge_dusk.webp` | approved 07 road verge (16.2 m, 11.3°, 46°) | the game, same camera, on a lane's verge |
| `cmp_<site>_rocks_dusk.webp` | approved 07 rocks (21.6 m, 17.2°, 39°) | the game, its largest boulder near town (approved Boulder 01 scan) |
| `cmp_<site>_overview_day.webp` | approved 06 region layout | the game's district view, day |
| `hours_<site>_*.webp` | | the game's day, evening and night, left to right |
| `cmp_world_eight_seeds.webp` | approved eight-world contact sheet | the game's satellite map of the same eight seeds (review driver, full daylight) |
| `globe_snow_260130.webp` | | seed 260130 on the globe (top) and the satellite map (bottom), the two reviewed snow sites |
| `boulder_01_details.webp` | | Boulder 01: approved 56,540-triangle scan, the 12,000 play mesh, 2,000 field and 220 chip, left to right |

Whole-frame mean RGB (0-255), approved / coast / inland: settlement 95,95,87 / 120,118,97 /
159,134,103; verge 102,97,85 / 107,108,88 / 152,126,94; rocks 77,73,51 / 94,93,62 / 148,120,73.
By band, the coast's near ground is within about 10% of the approved frames' (verge bottom fifth
70,65,43 approved, 68,70,39 game; rocks 67,66,40 and 72,75,41); its far field is paler (settlement
second fifth 97,96,88 approved, 138,137,120 game), where the approved views have wooded hills
and the game's haze. The inland site is a desert, not the approved temperate meadow.

Known differences: the paved road reads warmer than the approved grey asphalt under the game's
warm ambient light; Boulder 01 reads paler under the frontal evening sun; the live district has
fewer boulders in the rocks view; and the game's horizon is haze where the approved views show
distant ranges.

The live district's median clear space between neighbouring buildings is 53.2 m (approved
59.62 m), its built window 1,453.5 x 1,049.9 m with 37 buildings (approved 1,076.40 x 1,020.24 m
with 19).
