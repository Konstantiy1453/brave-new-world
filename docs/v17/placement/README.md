# Free placement records (2026-11-20)

**Label: automated test on the packaged build.** These ran against the shipped PCK of the 1.10.1 preview,
on the Linux build of the same engine (`--main-pack`), by `tools/verify/placement_driver.gd`. The Windows
EXE itself was not run. Human playtest: NOT_RUN.

**How the driver plays.** It drives the real interface:

1. It starts the game from its menu, with the tutorial switched off through the menu's own toggle and
   the seed typed in.
2. It turns the map to the target and clicks the ground with real mouse events, at the closest zoom a
   player can reach (globe distance 7.0, flat map size 4.2).
3. It reads what the ground panel and the naming dialog show.
4. It founds through the panel's button and the naming dialog.
5. It saves with Ctrl+S, frees the game, starts it again and continues from the menu.
6. It switches both maps and opens the district.

**Picking precision.** This is the ground one screen pixel covers at the current zoom. The panel shows it
under the coordinate. Coordinates count as agreeing within it.

**Later towns.** The colony was played to the expansion licence by the balance harness's balanced bot,
through `Sim.act` (the simulation actions the buttons call). The expedition itself went through the
interface.

**Repeat on Windows** with the packaged build:

```
ColonyCharter.exe --main-pack ColonyCharter.pck --script <abs>\placement_driver.gd -- --case=capital --view=planet --seed=3 --target=0 --out=<file>
```

- Cases: `capital` (with `--view=planet|flat` and `--target=0|1`), `regression`, `refusal`, and
  `outpost` (with `--view` and `--coast=0|1`).
- `outpost` needs `--bots=<folder>`: a copy of `game/tests/balance/bots/{bot,colony_bot,balanced_bot}.gd`
  with their `extends` lines pointing at that folder.

The JSON next to this file is each case's full record.

- Build: packaged PCK, game version 1.10.1, engine 4.5.1-stable (official)
- PCK SHA-256: `78181ecca53e41633adbdb37598b0a21403c6100db868994b3f9f46b55af786f`
- Window 1600×900, seed 3, 29 recommended sites

## Capitals (two fresh games, seed 3)

| Game | Map | Old site area | Clicked | Precision | Naming dialog | Stored | After save, quit, reload | Marker clearance | Checks |
|---|---|---|---|---|---|---|---|---|---|
| 1 | globe | 地点 01 at 21.2500, -118.7500, 6.5° away | 23.7374, -112.3067 | ±0.067° | 自选地点 · 北纬 23.74° · 西经 112.31° | 23.7374, -112.3067 | 23.7374, -112.3067 | 101 px | 14/14 |
| 2 | flat map | 地点 01 at 21.2500, -118.7500, 6.5° away | 25.8462, -123.6815 | ±0.093° | 自选地点 · 北纬 25.85° · 西经 123.68° | 25.8462, -123.6815 | 25.8462, -123.6815 | 72 px | 14/14 |

Both maps and the district opened on the stored place in each game (selected marker and district region recorded in the JSON).

## The seed 3 regression

| Click | Map | Ground | Panel showed | Marker clearance |
|---|---|---|---|---|
| 1 | globe | forest | 北纬 59.00° · 东经 106.50° · 地表：森林 · 地点类型：海岛 | 353 px |
| 2 | flat map | forest | 北纬 54.00° · 东经 114.00° · 地表：森林 · 地点类型：海岛 | 224 px |
| 3 | globe | grassland | 北纬 44.00° · 东经 91.50° · 地表：草地 · 地点类型：滨海平原 | 251 px |
| 4 | flat map | grassland | 北纬 41.50° · 东经 106.50° · 地表：草地 · 地点类型：滨海平原 | 86 px |
| 5 | globe | tundra | 北纬 59.00° · 东经 114.00° · 地表：苔原 · 地点类型：海岛 | 352 px |
| 6 | flat map | tundra | 北纬 56.50° · 西经 103.50° · 地表：苔原 · 地点类型：寒地 | 297 px |

Founded at 56.5000, -103.5000 (the last click), region 29, not Site 01. Checks 16/16.

## Refusals

| Ground | Panel said | Button | Founded |
|---|---|---|---|
| 海面 | ✗ 这里是海面，不能建立据点 | disabled | no |
| 极地 | ✗ 太靠近极地：纬度 78.8°，据点最远建在纬度 74° 以内 | disabled | no |
| 地势太陡 | ✗ 地势太陡：周围高差 4343 m，超过 3000 m 就平整不出城区和工地 | disabled | no |

Checks 7/7.

## Later towns (expeditions)

| Run | Map | Destination | Unlock day | Clicked | Route shown | Days, cost shown → taken | Stored | Route end | Built | After reload | Capital kept | Checks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| out_inland_globe | globe | inland (寒地) | 234 | 30.1014, -105.9427 | 从「远征首都」出发：工程公路（跨山） · 1553 km · 单程 5 天 · 远征费用 ¥ 3146（边疆据点） | 5 d, ¥3146 → 5 d, ¥3146 | 30.1014, -105.9427 | 30.1014, -105.9427 | water | 30.1014, -105.9427 | 远征首都 at 23.7374, -112.3067 | 22/22 |
| out_coast_flat | flat map | coastal (滨海平原) | 234 | 23.7374, -103.3067 | 从「远征首都」出发：工程公路（跨山） · 1558 km · 单程 5 天 · 远征费用 ¥ 3146（边疆据点） | 5 d, ¥3146 → 5 d, ¥3146 | 23.7374, -103.3067 | 23.7374, -103.3067 | farm | 23.7374, -103.3067 | 远征首都 at 23.7374, -112.3067 | 22/22 |

## Saves through the version change

- `save_files/before-1.10.0.save` was written by the 1.10.0 preview's own PCK (SHA-256 `7e2ec510…`)
  with the balanced bot on seed 20261029, day 201. It has two towns, three projects under way and
  three crews (one on the road).
- `save_files/after-1.10.1.save` is the same game loaded by this build, played ten days and saved again.
- `tools/verify/save_carry_driver.gd` checked on the shipped 1.10.1 PCK (13 of 13): every town with its
  name, place and people; every project under way with its days left; the crews and their tasks;
  research and money; the audit, before and after ten days; and that the new save loads.
- Records: `save_make_1.10.0.json` and `save_carry_pck.json`.
