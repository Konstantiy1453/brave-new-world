# Colony Charter — model fix sheet for GPT (2026-11-12)

**For:** the 3ds Max modelling agent (the user pastes this to GPT/Codex). Everything in
`2026-11-08-v19-model-brief-scifi.md` still holds: art direction (§1), technical rules (§2), slot words (§3),
delivery layout and handoff (§5). This sheet adds what the 1.9 region scene and the new transport rules found
or need. Deliver as before into `art_reserve/max_models_<date>/` and publish `art-assets-<yyyymmdd>`; never
touch the game folders.

## Why this sheet

In 1.9 the region view changed on generated worlds:

- Every building plot is cut into the hillside as a **level terrace** (the "dwellings carved into the
  mountainside" look). The pad is level out to **2.45 game units** from the plot centre (2.3 is guaranteed),
  then the ground runs back to the natural slope by **3.6 units**. Uphill the slope rises above the pad;
  downhill it falls away.
- Vehicles now drive on **service lanes** between the rows of plots and stop at the front of each pad
  (2.55 units out). Nothing drives through a building any more, so a building that reaches past its pad
  is what still looks wrong.
- Sea links are now **pairs of cargo docks** that grow from small to medium to large, roads are paved and
  then widened, and three **gift technologies** (event-only) bring a red-ball truck fleet, fast freighters and
  a bulk carrier. Each wants its own model.

The game fits every building to **4.0 units on its long side** (great works 5.0), whatever its size in metres,
and draws vehicles at **0.11 units per metre**. Both facts drive the fixes below.

## 1. Fixes to delivered models

### F1 · Corners that overhang the terrace (35 of 67 building models)

A square footprint fitted to 4.0 units has its corners 2.83 units from the centre: 0.4 units past the level
pad. Uphill the corner disappears into the slope; downhill it hangs over the drop. These models reach past
2.6 units (game id · building · reach in units):

| Reach | Models |
|---|---|
| 2.80–2.83 | `deep_well` 深层水井 · `hydroponic_farm` 水培温室 · `park` 生态公园 · `arcology` 生态穹顶城 · `institute` 研究院 |
| 2.70–2.79 | `port` 轨道货运站 · `desalination` 海水淡化厂 · `fission` 裂变电站 · `mine_ore_heavy` / `mine_copper_heavy` / `mine_crystal_heavy` 重型矿场 · `tailings_plant` 尾矿回收站 · `atmospheric_water` 大气集水站 · `farm` 温室农场 · `mine_crystal` 晶体采掘站 · `pharma_plant` 生物制药厂 · `smelter` 合金冶炼厂 · `crystal_vat` 晶体培育槽 · `protein_plant` 合成蛋白厂 · `sea_copper` 海水提铜站 |
| 2.60–2.69 | `mine_copper` 轻型铜矿场 · `geothermal` 地热电站 · `machine_works` 精密机械厂 · `mine_ore` 轻型铁矿场 · `foodworks` 食品出口加工坊 · `mine_*_auto` 自动钻场 (3) · `school` 中等学校 · `vertical_farm` 垂直农场 · `depot` 区域物流中心 · `processor` 复合加工厂 · `aquafarm` 近海养殖场 · `clinic` 社区诊所 · `fusion` 聚变电站 |

**Fix.** Keep every part taller than 0.3 m inside a circle of radius **0.58 × the long side** around the
pivot (for a 40 m building: 23 m). Round or chamfer the footprint (octagon, rounded rectangle, cluster of
modules); put only flat paving (`apron`, `paving`, at grade) in the corners. Do not shrink the main mass:
the building should still fill its pad. Great works (fitted to 5.0 units) follow the same rule against a
pad of 3.0 units: radius 0.6 × long side.

### F2 · A foundation skirt under every building

Each pad is level, but its edge meets a slope. Give every building and construction state a closed
`CC_<KIT>_foundation_skirt_0001` (slot: concrete) that follows the footprint outline and runs **1.5 m below
grade**, so no gap or floating edge shows at the terrace rim. The game already reads how far a model reaches
below its datum (`lowest`) and keeps the pivot at grade.

### F3 · Scale outliers next to vehicles

Fitted to 4.0 units, a model's metres shrink or grow. Vehicles are 0.11 units per metre, so a truck looks
right beside a 35–45 m building and like a toy or a giant beside anything else. Models far from that band
(units per metre):

| Too big in reality (truck looks huge) | Too small in reality (truck looks tiny) |
|---|---|
| `wind_farm` 0.015 · `fusion` 0.030 · `arcology` 0.031 · `mine_*_auto` 0.034 · `aquafarm` 0.049 · `school` 0.051 · `apartment` 0.074 | `habitat` 0.135 · `deep_well` 0.133 · `crystal_vat` 0.133 · `protein_plant` 0.133 |

**Fix.** Remodel the left column at a diorama footprint of **35–45 m** on the long side (compress spacing,
fewer repeated modules, keep the hero feature at full size). For the right column, widen the footprint to
at least 32 m with yard, tanks or annexes. Wind farm: three or four turbines on one pad, not a field.

## 2. New models for the 1.9 transport rules

Axes as in the brief (metres, Z-up, front −Y = land or street side, pivot at the footprint centre at grade).
For quays the **sea side is +Y** (the back), like the delivered `harbor`.

| Game id | What | Size | Triangles | Notes |
|---|---|---|---|---|
| `dock_medium` | 中型货运码头: a longer quay with **two berths**, two rail-mounted cranes (`crane`), a transit shed, a small yard of containers (`container`), bollards and fenders | ~110 × 40 m | ~5,000 | Replaces the enlarged stand-in the game draws today (the small `harbor` at 1.25×) |
| `dock_large` | 大型货运码头: **three berths**, two ship-to-shore gantry cranes (`gantry`), container stacks, a bulk hopper and conveyor, a harbour office tower with `glass` | ~150 × 50 m | ~7,000 | Stand-in today: `harbor` at 1.5× |
| `ship_fast` | 高速货轮 (gift): a slim, fast container ship, raked bow, bridge aft, a few container rows | ~90 m long | ~3,000 | Same axes and pivot as `cargo_ship` (length along Y). Shown when the colony has the gift |
| `ship_bulk` | 大型散货船 (gift): a broad bulk carrier, five or six hatch covers (`panel`), deck cranes (`crane`), bridge aft | ~120 m long | ~3,500 | As `ship_fast` |
| `vehicle_truck_redball` | 红球快运 truck (gift): `vehicle_truck` with a red cab and a **white disc with a red ball** on both doors and the front (geometry, not texture: a flat disc part named `warning_disc`) | as `vehicle_truck` (~10 m) | 800–1,200 | Same pivot and axes as `vehicle_truck`. Until it arrives the game paints the standard truck red |

Optional, same family: `dock_small` to replace `harbor` (one berth, one crane, ~80 × 30 m) so all three
docks match.

## 3. Optional: pieces for the carved-terrace look

The game side places these once they arrive (no game support yet; say in the delivery notes which you made).

| Game id | What | Size |
|---|---|---|
| `terrace_wall` | Retaining-wall module for the uphill side of a cut pad: rough stone or shotcrete face (`foundation`), a coping rail (`rail`), drainage holes, 4 m tall at one end and 1 m at the other | 20 m long module, tiles end to end |
| `terrace_stair` | Stair and ramp between two terraces 3 m apart, with a handrail | 12 × 6 m |
| `cliff_habitat` | Housing set **into** a rock face: a row of pressurised modules whose fronts (windows `glass`, airlocks) stand out of a cut cliff, with a ledge walkway | 40 m wide, 12 m deep, 15 m tall; the back is a rough rock mass meant to sit inside the slope |

## 4. Check before delivery

- Render each fixed building from 50° above on a **level disc of radius 0.58 × long side**, with a slope
  rising behind it and falling in front: nothing taller than 0.3 m may cross the disc edge, and the skirt
  must hide the rim.
- Render a `vehicle_truck` beside each building in F3 at the true metre scale: the truck should look like a
  truck, not a toy or a building.
- Fill the usual metadata (`measured_size`, `bounds`, `geometry.nodes`) and map every new id in
  `DELIVERY_TARGET_IDS.json`. Keep the existing ids for fixed models so the game picks them up with no change.

## 5. Handoff

Tell the user the release tag. The game side converts with `tests/art/convert_models.gd`, checks budgets with
the `v19_art` suite, and re-bakes icons and facility views. `dock_medium`, `dock_large`, `ship_fast`,
`ship_bulk` and `vehicle_truck_redball` replace their stand-ins with no other change; the terrace pieces need
placement code first.
