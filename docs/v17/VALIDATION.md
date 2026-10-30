# Colony Charter 1.7 — Validation

What ran, on what, with what result. Evidence labels: automated test · balance harness · source-project window ·
exported EXE · screenshot viewed · human playtest. Raw output stays in `evidence/v17`.

Human playtests: **NOT_RUN**.

## 1.6 baseline (Phase 0)

Hardware: Intel Core i9-14900HX, NVIDIA GeForce RTX 4070 Laptop GPU, Windows 11. A separate 3ds Max task was running on the
same machine, so timings are indicative.

**Automated test.** `tools/run_tests.ps1`: 37 of 37 headless suites pass on 1.6 production code. Only test scripts changed, for
output isolation and the watchdog. Shipped fixtures in `game/data` and existing files in `evidence/v16` were checked unchanged
after the run. Watchdog proved on a deliberately failing script: exit code 2 after 3 s.

**Source-project window.** `v16_interaction_probe`, `v16_scroll_probe`, `world_v16_visual` pass through the runner with `-Window`.
Both probes first failed on their own check for the old user-data folder name, which is now `userdata_`.

**Balance harness.** `--full`, 950 runs in 107 s: rush day 19, 0 audit errors, 3 of 3 replays byte-identical. Table in `BALANCE.md`.

### §4 findings reproduced

From `game/tests/v17_findings_16.gd` (`evidence/v17/tests/findings_16.json`) and the harness.

| Finding | Brief | Measured |
|---|---|---|
| Rush award | day 19; science on hard 25 | Identical on seed 260129; across 20 seeds all day 19 |
| Idle after landing | fails day 137 | Passive bot median 137 (easy 166, hard 118) |
| Mining without second settlement | fails day 317 holding ¥35,671 | Day 317, ¥35,671.26 |
| Sandbox after award, 1,500 days | cash about ¥152k, population 84, last event by day 60 | ¥141k, population 76, last new event day 60; differences come from which event options were taken |
| Mountain road | always faster, 2–4 vs 5–9 days, 42 vs 28 t/day, −4% to +55% cost | Always faster across 40 other seeds, 2–4 vs 4–10 days, 42 vs 28, −16% to +55% |
| Iron and crystal mines | ¥77 for 9 workers, ¥678 inputs; ¥75 for 12 workers, ¥1,328 | ¥76.8, 9, ¥678; ¥74.9, 12, ¥1,328 |
| Processor | about +¥4/day | +¥3.35/day |
| Aid | gives more than it costs | Liquidity 1,800 for 1,200; supplies 1,504 for 700 |
| Enterprise preview | capital about +¥0.7, 18-person outpost negative | +¥7.0 at the full 60 residents, +¥0.7 at 42 after an expedition, outpost −¥7.7 |
| Valley fertility | 0.95 every time | 0.83–0.95 across 40 other seeds |
| Basin iron | 15.6–20.8 kt | 15.5–20.7 kt |
| Islands | unreachable in all 40 | Unreachable in all 40 |
| Events | 13 definitions, last fires by day 60 | 10 short + 3 chains, last new event day 60 |
| Saves | 8.1 MB new game | 6.66 MB without a landing checkpoint; 209 ms save, 242 ms load headless |
| Pausing decisions | 10–13 in the first 60 days | Balanced bot totals about 12 over 720 days, all before day 60 |

Other §4 items are confirmed by reading the code at the cited lines and are re-tested by the regression test that fixes each one.

## Intentional test changes

| Test | Change | Why |
|---|---|---|
| All SceneTree scripts in `game/tests`, `game/world/*test*`, `tools/*.gd` | Watchdog; outputs moved to `evidence/v17/tests` | W0 isolation |
| `v16_research_priority.gd`, `v16_event_acceptance.gd` | Fixtures written only with `--fixtures` | W1 bug 5 |
| `world_v16_seed.gd` | Skips the frozen hash comparison when the evidence file is missing | W0; it used to hang |
| `v16_interaction_probe.gd`, `v16_scroll_probe.gd` | User-data check accepts any `userdata_` folder | Runner isolates per suite |

## Phase 1

**Automated test.** `v17_bugs` 43 checks, 0 failures. All 38 headless suites green.

Reproduced on pre-fix code (tag `v17-phase0`, temporary worktree) before the fixes landed: bug 1 chain ended `water:工程未能投入运行`;
bug 3 size 0 became 1 on handover; bug 4 Esc closed the menu; bug 6 aid addressed to the capital with the outpost starving; bug 11 still
paused after closing when previously running.

**Source-project window, screenshot viewed.** `world_v17_seam`: camera on the antimeridian, 6 outlier rows on the seam column against 8 on
control columns; `evidence/v17/tests/world_v17_seam.png` viewed, no dashed seam visible.

**Formatting.** `gdformat` over 76 scripts: 38 suites green before and after; 950 harness run records identical via
`tools/compare_balance.py`; 3 of 3 replays byte-identical.

Export filter exclusions are checked against `export_presets.cfg` here. PCK contents are verified at the release step (Phase 8).

## Phase 2

**Balance harness.** Behaviour unchanged: 950 of 950 run records identical to Phase 1 through `tools/compare_balance.py`, 3 of 3 replays byte-identical, 0 audit errors.

**Automated test.** All headless suites green, including `v17_saves` (93 checks): exact round trip and continuation, sibling checkpoint and archives, refusal of a mismatched world with no change to the running game, a worker-thread write, header read without the payload, and migration of all 8 shipped 1.6 and 1.5 fixtures.

| Measure | 1.6 | Schema 3 |
|---|---|---|
| Day 60 save | about 8 MB | 7.8 KB (headless, this machine) |
| Second-world fixture | 11.15 MB | 11.1 KB |
| Save | 209 ms | 23 ms |
| Load, world already in memory | 242 ms | 7 ms |

Cold load, which regenerates the world, is measured in Phase 5 against the new generator.

**Source-project window.** `v16_interaction_probe`, `v16_scroll_probe`, `world_v16_visual`, `world_v17_seam` pass.

### Tests rewritten

| Test | Change | Why |
|---|---|---|
| `tools/review_save_guards.gd`, `review_save_nested_regressions.gd`, `review_save_nested_type.gd` | Build malformed schema 3 saves through `tests/support/save_fixture.gd`; added bad magic, truncation and world-hash cases; the grid case became a hash case | Schema 3 replaces the JSON envelope and the grid left the state |
| `world_v16_legacy_load.gd` | Compares `geo.grid` and regions against the old save | World split |
| `v16_career_review.gd` | Archive corruption removes the hash; ledger fixture uses `key` | Archives are sibling files |
| `v16_events_tests.gd`, `v16_economy_tests.gd`, `v16_rules_tests.gd`, `v16_ui_tests.gd` | English keys, `sim.geo` | Display strings left the logic |

## Phase 3

**Balance harness.** `--full`: floor, three award bands, passive and sloppy failure, export mix, audits and determinism pass. See `BALANCE.md`.

**Misses reported against §5.2 at this phase:**

- Population and money at day 720, and openings spread. Colonies run out of deposits around day 470–530: two settlements and the six fixed regions cannot carry a 720-day economy. Phase 5 brings many sites and deep deposits; re-measure there.
- Research rows belong to Phase 4. Event rows belong to Phase 6.

**Automated test.** All headless suites green, including the new `v17_contract_population`.

### Tests rewritten

| Test | Change | Why |
|---|---|---|
| `tools/review_population_boundaries.gd` | Removed; births and arrivals covered by `v17_contract_population` | It tested the fixed 360-day birth clock |
| `sim_tests.gd` | Full-contract and tax checks moved to `v17_contract_population` and the harness; licence granted up front | One-step contract is gone |
| `v16_rules_tests.gd` | Longer company windows; ¥2,100 aid repayment | Appendix C aid terms and §5.2 failure timing |
| `v16_ui_tests.gd` | Long-frame award forced through a one-goal stage | The old contract could complete in one tick |
| `v16_economy_tests.gd`, `v16_f12_transport.gd`, `v16_flow.gd`, `v17_bugs.gd`, `tools/review_outpost_jobs.gd`, `tools/review_sim.gd` | Grant the expedition licence | Second settlement is now licensed |

## Phase 4

**Balance harness.** `--full`, 950 runs, 0 audit errors: all research rows pass (balanced 5 techs, 14% scientists, 23% spend; research-first 7 techs, award day 178). Floor, award bands, openings, failure, export mix and determinism also pass. See `BALANCE.md`.

**Misses reported against §5.2 at this phase:**

- Population at day 720 (506, target 600) and income growth (×0.98, target ×2.5): bots run out of deposits and jobs around day 360 on two settlements and six fixed regions. Re-measure in Phase 5.
- Event rows belong to Phase 6.
- The Climate Regulator's effect on farm yields is implemented and tested; its appearance on the globe is not. It belongs with the map overlays in Phase 5.
- Survey's "reveal true deposits", prospecting's reveal and survey discount, deep deposits and sea routes need sites: Phase 5. Those technologies can be researched now but do less than their text says until then.

**Automated test.** All 40 headless suites green, including the new `v17_research`, which also opens the tech-tree page in a headless UI.

**Source-project window, screenshot viewed, exported EXE, human playtest:** NOT_RUN at this phase.

### Tests rewritten

| Test | Change | Why |
|---|---|---|
| `v16_rules_tests.gd` | Clears the science opening's survey head start in the concentration test | The head start would finish its 12-point test project on day one |

## Phase 5

**Balance harness.** `--full`, 950 runs, 0 audit errors, 3/3 replays identical. Floor, standard and hard award bands, openings, failure rows, population (374 / 839), research, money (83%, ×3.46), labour lever (+27%), geography and road trade-off (57%) pass. See `BALANCE.md`.

**Misses reported against §5.2 at this phase:**

- Easy award median 153 against a band of 90-150.
- Research-first award median day 195 against the standard band of 120-180. It reaches 8 technologies, more than the 6 asked for, so it is spending too much on research.
- Export mix: median 34%, but one seed reaches 82% against the limit of 60%.
- Event rows belong to Phase 6.
- 9 of 60 balanced runs on standard miss the award or are taken over by the company later. No §5.2 row covers this, but a sensible player should not lose; Phase 8 looks at it.

**Automated test.** 42 headless suites green, including the new `v17_sites` and `v17_world_stats` (200 seeds: sites 14-20 / 20-30 / 28-40, land 28-42%, continents 2-6, 3+ start pairs on every seed, three archetypes as best start at 10% or more: mining basin 58%, cold 20%, highland 19%; no basin carved; every name unique; first pair connectable by valley road on all 200).

**Source-project window.** The four window suites pass. Cold region load measured once at 749 ms on this machine; frame spikes not yet measured (Phase 8). A cached world reads from disk in 32 ms.

**Screenshot viewed.** Globe, flat map, region view and research page from the source project at 1600 × 900: continents, mountain belts, islands, automatic labels, buildings on plots, faint free plots, shoreline, tech tree.

**Exported EXE, human playtest:** NOT_RUN at this phase.

### Tests rewritten

| Test | Change | Why |
|---|---|---|
| `sim_tests.gd` | The island is found by having no neighbours; finite deposit test sets a plot's reserves | Sites have no fixed roles or numbers; reserves live on plots |
| `v16_rules_tests.gd` | Post-mining fixture empties deposit plots and sets farm plots' fertility | Same |
| `v17_contract_population.gd` | Depleted-mine test empties plots; immigration test adds jobs; `state.roads` | Plots; arrivals need jobs; road network |
| `world_v16_legacy_load.gd` | Old site fields must be byte-identical; sites may gain fields | Migration adds plots to each region |
| `world_v16_region.gd`, `v16_f12_transport.gd`, `tools/review_save_nested_regressions.gd` | `state.roads[0]` | One route became a network |
| `world_v16_ui_sync.gd` | Looks for the inactive accent in the baked mesh's surfaces | Building models are baked |

