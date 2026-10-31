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

## Phase 6

**Balance harness.** `--quick`, 80 runs, 0 audit errors, 3/3 replays identical. Event row passes: one pausing decision per 38 days, 29 distinct definitions by day 720, no repeat inside a cooldown, 28 short definitions, 6 chains.

**Misses reported against §5.2 at this phase, all small and left for the final balance in Phase 8:** balanced award 184 against 120-180; research-first day 201; income growth ×2.42 against ×2.5; labour lever +19% against +20%.

**Automated test.** All suites green, including the new `v17_events`: content counts, soundness of every definition, cooldowns, notices and the pause setting, scaled money, feasibility with reasons, effects reaching their systems, the rockfall trigger, and each new chain's endings, deferral, timeout and save/load continuation.

**Source-project window, screenshot viewed, exported EXE, human playtest:** NOT_RUN at this phase.

### Tests rewritten

| Test | Change | Why |
|---|---|---|
| `v16_events_tests.gd` | Short-event loop covers the ten 1.6 events; pause checks set "all decisions pause" | New events need beds, roads or projects and have their own suite; `pump_seal` is now a minor decision |
| `v16_ui_tests.gd`, `v17_bugs.gd` | Use the `water` chain for "an event blocks time" | Short notices no longer pause |

## Phase 7

| Check | Evidence | Result |
|---|---|---|
| Tutorial start to finish, skip, back, replay, tips once, pinned sites, scripted shortage | automated test `v17_tutorial` (headless, drives the real UI scene) | PASS, 131+ checks |
| Rollups match the daily income, save and reload byte-identical | automated test `v17_tutorial` | PASS |
| New build dialog, site card, settlement panel, economy, population pages | automated test `v17_tutorial`; screenshot viewed | PASS |
| Every main page at 1920×1080 (18 px) and 1280×720 (20 px) | source-project window, `--qa-v17`; screenshot viewed | Problems below fixed |
| All headless suites | automated test, runner | 44 of 44 PASS |
| Window suites | automated test, runner `-Window` | 4 of 4 PASS |
| Balance, `--quick` | balance harness | 80 runs, 0 audit errors; misses in `BALANCE.md` |
| Manual tutorial run in the exported EXE | NOT_RUN | Phase 8 |
| Human first-time run | NOT_RUN | Needs the user |

Problems the screenshots found and fixed: the settle button was below the fold even at 1080p; navigation needed a scrollbar at
1080p; the home site was on the globe's night side unless it was site 0; the coach panel had empty space and could cover its
target; the site card hid the build-cost multiplier when it was small. The capture suite also found a bug no test had: a milestone
reward made every later save unloadable (`v17_research` now reloads a save after a milestone).

No test was rewritten in this phase.

## Phase 8 and release

Hardware: Intel Core i9-14900HX, NVIDIA GeForce RTX 4070 Laptop GPU, Windows 11, 32 threads.

| Check | Evidence | Result |
|---|---|---|
| All headless suites | automated test, runner | 45 of 45 PASS |
| Window suites | source-project window, runner `-Window` | 4 of 4 PASS |
| Balance `--full`, 950 runs with 50 random-legal fuzz runs of 720 days | balance harness | 17 of 18 rows PASS, 0 audit errors; best-bot part of Openings is a miss |
| 200-seed world test | automated test `v17_world_stats`; balance harness | PASS |
| Determinism: 3 replays, and 1×, 4×, 10× through the real clock against no interface | balance harness; automated test `v17_speed` | byte-identical |
| Capture suite: 22 views × 3 resolutions × 3 text sizes = 198 images | source-project window | all written at their true size |
| Images viewed | screenshot viewed | about 60: all 22 at 1920×1080 18 px; 1280×720 at 20 px and 16 px and 2560×1440 at 20 px for the hardest pages. Not every image |
| Tutorial through stage 1, save, quit, relaunch, continue, reach stage 2 | exported EXE, scripted through real buttons and the real clock (`tests/exe_drive_v17.gd`, `evidence/v17/exe_drive`) | PASS, log has no errors, audit clean |
| 1.6 save: found by settings page and menu, migrated, original file unchanged | exported EXE, scripted, in an isolated APPDATA | PASS |
| The delivered ZIP unpacked to another folder, tutorial part of the same run | exported EXE, scripted | PASS |
| PCK directory: 131 files, no tests, fixtures or capture suite | `tools/package_v17.py` reads the PCK's directory | PASS |
| Performance | exported EXE (`tests/perf_probe_v17.gd`, `evidence/v17/perf`) | table below |
| Manual tutorial run in the EXE | NOT_RUN | No person has done it. The scripted run above is not a substitute for reading the text |
| Human first-time run and all human playtests | NOT_RUN | Checklist in `PLAYTEST.md` |

| Measure, day-720 save | First run, empty caches | Second run | Target |
|---|---|---|---|
| Save size | 47,142 bytes | same | 1.5 MB |
| Save, median of 20 (worst) | 9.7 ms (11.4) | 9.8 ms (11.5) | 100 ms |
| Load, median of 20 (worst) | 20.2 ms (21.7) | 18.6 ms (25.2) | 300 ms |
| Worst frame during autosave, 12 × 45 frames | 33.8 ms | 23.1 ms | 50 ms |
| Page open, warm, 8 pages × 8 (worst) | 23.8 ms | 17.4 ms | 100 ms |
| Page open, first time (worst, transport) | 162 ms | 171 ms | not a target |
| Region, cold, 8 sites: median (worst) | 768 ms (822) | 766 ms (799) | 1.0 s |
| Worst frame during a cold region load | 42.8 ms | 42.1 ms | 50 ms |

Load assumes the world is already cached on disk, which the game does on first play. With no cache, a load also regenerates the world: about 0.5 s, 1.5 s at worst (Phase 5).

Problems these checks found and fixed: a settlement's action row pushed the sidebar past the window edge at every size; reused buttons kept another panel's narrow settings; finishing the world atlas stopped the frame for 340 ms on each new world; a milestone reward made later saves unloadable (Phase 7); the settings page looked for 1.6 saves in the 1.5 folder; the balanced bot's first partner could be a barren site reached cheaply.

### Known issues

- `v17_speed` crashed once at 37 s under the runner (signal 11, main thread, top frame `EventsV2.pause_required`, where a dictionary is allocated each call, so probably earlier heap damage). No C++ symbols. 38 repeats, 32 of them under heavy load, did not reproduce it. Cause unknown. The test then ran days with no engine frames, unlike a real game; it now gives the engine a frame per simulated day.
- `v16_scroll_probe` timed out once (540 s) while the machine was in use by someone else, and passed in 48 s alone. A window suite needs its window to keep drawing.
- `tools/build_v17.ps1` found no export templates in `%APPDATA%\Godot`, so it now unpacks the two it needs into `build\godot_home`. The first attempt, before that fallback existed, created `%APPDATA%\Godot` and `%APPDATA%\ColonyCharter\v17` on the real machine. Both were new and held only engine defaults and an empty lock file; both were removed. `%APPDATA%\ColonyCharter\v16` has no file newer than the baseline.

### Tests rewritten

| Test | Change | Why |
|---|---|---|
| `v16_rules_tests.gd` | Departure check compares with the town's own starting population | Opening crews changed |

## 1.7.1

Hardware as above. Evidence labels as above.

| Check | Evidence | Result |
|---|---|---|
| All headless suites | automated test, runner | 45 of 45 PASS |
| Window suites | source-project window, runner `-Window` | 4 of 4 PASS |
| Balance `--full`, 950 runs with 50 fuzz runs | balance harness, `2026-10-31T17-13-30` | 15 of 18 rows PASS, 0 audit errors; 3 misses in `BALANCE.md` |
| 200 seeds: site counts, 3 start pairs, land 25-45%, 2-6 continents, every planet type present, spreads of land, temperature and rainfall | automated test `v17_world_stats` | PASS: 0 carved worlds, land spread 0.19, temperature spread 26 °C, rainfall spread 0.38, the menu's type holds on 168 of 200 seeds |
| 12 seeds rendered before and after | source-project window; screenshot viewed | Layouts and ice clearly differ now; the green and tan palette is shared on purpose |
| A 1.7.0 save (CC-GEO-2.0) loads, keeps its names, plays and saves again, even after 2.1 worlds of the same seed | automated test `v17_saves` | PASS |
| Naming: dialog, cancel, Enter, odd text, limit, blank, rename, save and load, map and lists | automated test `v17_tutorial` | PASS |
| Building list, seed box, tutorial lock, menu's planet preview matches the planet | automated test `v17_tutorial` | PASS |
| Every page at 3 resolutions × 2 text sizes, 144 images | source-project window; screenshot viewed (32: every page at 1280×720 with 20 px text, 8 at larger sizes; plus the menu with the tutorial off) | Problems below fixed |
| Tutorial through stage 1, save, relaunch, continue, stage 2, 1.6 save | exported EXE, scripted through real buttons | PASS, 17 and 10 steps, logs have no errors |
| Performance | exported EXE (`evidence/v17/perf`) | as in the table below |
| The delivered game ZIP, unpacked, then the same scripted run from there | exported EXE from `delivery\v17`, scripted (`evidence/v17/exe_drive_zip`) | PASS, 17 and 10 steps, logs have no errors |
| Source ZIP holds no `art_reserve`, `.godot`, engine, evidence, builds or earlier deliveries | archive listing | PASS, 318 entries |
| Protected folders | file dates | `build\v16`, `docs\v16`, `versions`, `tools\godot-4.5.1`, `delivery` outside `v17` and `evidence` outside `v17`: nothing changed today. `%APPDATA%\ColonyCharter\v16`: newest file 00:26 today, before this work began at 01:40. `%APPDATA%\ColonyCharter\v17` is the user's own play, and its listing did not change across the build. `%APPDATA%\Godot` does not exist |
| Human playtests, manual EXE tutorial | NOT_RUN | The user tried 1.7.0 and reported what led to this version; 1.7.1 has not been played by a person |

| Measure, day-720 save | First run, empty caches | Second run | Target |
|---|---|---|---|
| Save size | 47,219 bytes | same | 1.5 MB |
| Save, median of 20 (worst) | 10.0 ms (14.2) | 9.9 ms (10.9) | 100 ms |
| Load, median of 20 (worst) | 19.6 ms (20.8) | 19.4 ms (20.4) | 300 ms |
| Worst frame during autosave | 20.1 ms | 17.6 ms | 50 ms |
| Page open, warm, worst | 17.8 ms | 17.4 ms | 100 ms |
| Region, cold, 8 sites: median (worst) | 766 ms (826) | 767 ms (802) | 1.0 s |
| Worst frame during a cold region load | 42.9 ms | 44.9 ms | 50 ms |

Problems found and fixed on the way: new games ignored the seed with the tutorial on, and the seed box defaulted to the tutorial's seed; the route cache mixed the two generators; site numbers did not match ids after the validator reordered sites; the balanced bot's new mines undid the non-mining goal; the menu overflowed at the largest text; the site chooser cut off the terrain; an island's card showed a heading with no routes under it.

World generation is slower on hard seeds: mean 0.7 s, worst 3.6 s over 200 seeds (was 0.5 s and 1.5 s).

### Tests changed

| Test | Change | Why |
|---|---|---|
| `sim_tests`, `v16_events_tests`, `v16_event_order_probe`, `v16_research_company_review`, `v17_contract_population`, `v17_tutorial` | Waits read build days from the rules; the scenario retries its farm and allows a processor until day 150 | Builds take longer |
| `v17_world_stats` | Adds variety checks | Planets must differ |

## 1.8.0

Hardware as above. Evidence labels as above.

| Check | Evidence | Result |
|---|---|---|
| All headless suites | automated test, runner | 46 of 46 PASS at the final run. `v17_speed` crashed once in the engine in an earlier full pass with the same code and passed 97 of 97 on re-runs; reported as an open issue |
| Window suites | source-project window, runner `-Window` | 4 of 4 PASS. `v16_interaction_probe` failed once on a garbled decode under full load and passed on re-runs; reported as an open issue |
| Balance `--full`, 480 runs with 30 fuzz runs | balance harness, `2026-11-01T03-10-20` | 20 of 22 rows PASS, 0 audit errors; 2 misses recorded in `BALANCE.md`. Five full runs before it, each for a reason in `DECISIONS.md` |
| Every page at 3 resolutions × 2 text sizes | source-project window; screenshot viewed (1280×720 at 20 px, every page, plus 1920×1080 of the map and research pages) | No clipped controls found. Labels are fitted with wrapping |
| Tutorial through stage 1, save, relaunch, continue, stage 2, 1.6 save | exported EXE, scripted through real buttons (`evidence/v17/exe_drive`) | PASS. It found the tutorial's first event breaking into the shortage lesson; fixed |
| Performance | exported EXE (`evidence/v17/perf`) | as in the table below |
| Old saves: 1.7.1, 1.7.0, 1.6 | automated test `v18_systems`, `v17_saves`, EXE drive | Load on their own worlds, keep playing with clean audits; files unchanged |
| Protected folders | file dates | `%APPDATA%\ColonyCharter\v16` and `v17`, `build\v16`, `docs\v16`, `versions`, `tools\godot-4.5.1`, `delivery` outside `v17`, and existing evidence untouched; `%APPDATA%\Godot` not created |
| Human playtests, manual EXE tutorial | NOT_RUN | The user tried 1.7.1 and reported what led to this version; 1.8.0 has not been played by a person |

| Measure, day-2,200 save | First run, empty caches | Second run | Target |
|---|---|---|---|
| Save size | 58,965 bytes | same | 1.5 MB |
| Save, median of 20 (worst) | 11.7 ms (16.8) | 11.5 ms (13.1) | 100 ms |
| Load, median of 20 (worst) | 25.0 ms (32.0) | 24.3 ms (25.3) | 300 ms |
| Worst frame during autosave | 33.5 ms | 18.3 ms | 50 ms |
| Page open, warm, worst | 17.5 ms | 17.6 ms | 100 ms |
| Region, cold, 8 sites: median (worst) | 739 ms (760) | 736 ms (761) | 1.0 s |
| Worst frame during a cold region load | 46.7 ms | 47.9 ms | 50 ms |

Problems found and fixed on the way, each by a harness run or a scripted check rather than by looking:

- A port stopped importing while a month of food was on the road, so towns starved beside a working port.
- A new outpost could not afford a farm or a port, and starved before its road was finished.
- A technology the final stage requires could stay out of the cards for a whole run.
- Lateness alone could block the award: small social trouble during a lateness review held up a finished charter.
- A full frontier post counted as unrest and could end in a takeover.
- Hard's final deadline fell before its own target band.
- Plots stood off the edge of the region's terrain on the new planets.
- A page whose layout changed could lose a named control, which is why `D._take_name` exists.
- A cold region's triangle stage was one long frame; it is now spread out.
- The site card crashed reading a route's building time on some worlds.

### Tests changed for 1.8

| Test | Change | Why |
|---|---|---|
| `v18_systems` | New: pollution curve, pollution is not distrust, outbreaks, distrust rates, old job names gone from every rule and UI file, 1.7 saves, resource table, gauge, column, settlement kind on the naming page, 1.7 save fallback in the menu | The request's new systems |
| `v17_research` | The tree checks become pool checks (at least 100 technologies, 4 categories, all reachable, at least 30 new buildings); new checks for hands, redraws, leads, always-dealt cards and cards in saves; the page test presses a card | The tree is gone |
| `v17_sites` | New real-distance, settlement-kind, road-construction and island tests. Existing network tests finish their roads by hand first; the sea test no longer expects a technology, and now finds a coast only the sea can reach instead of skipping when the first seed has none | Roads take months; water transport needs no research. The old sea test had been skipping silently |
| `v17_contract_population` | Reads figures from the rule files; adds five-stage checks | Numbers live in `game/data/v17/` |
| `v17_events` | Reads cooldowns and prices from the rule file, waits for a node instead of a fixed number of days; new deck and writing checks | Delays tripled; events can now be off |
| `v17_tutorial` | The catalogue shows only what can be built here; the settlement's buildings are looked for in the column; 6× replaces 10× | Requested changes |
| `v17_world_stats` | Road trade-off fails only below 30%, no longer above 70% | On real planets the cheap road is nearly always the slow one (89%), which is the trade-off working. Reported as a miss against the bar as written |
| `v17_bugs`, `v17_saves` | Say 工程队; compare with the current schema; wait for an expedition to arrive instead of 12 days | Names, schema 4, real distances |
| `sim_tests` | Waits for mines and expeditions by their real times; the "no materials" check turns the port off first, since a working port now buys what a site lacks; the first-island refusal becomes "a landing needs a real site"; the scripted scenario gets ¥30,000 so that it reaches its later steps | Rules changed. The script is not a plan a governor would follow, and it says so |
| `v16_rules_tests` | Pollution checks read the planet's load, not a town's; research path uses two starter cards; the post-mining town gets 40 crews so that it can staff a farm and a food works; company paths read the rule file and run longer | Planet-wide pollution, cards, slower distrust |
| `v16_events_tests` | Waits for nodes; the order test ships after the review, and a reduction ships before it; the first draw is no longer expected to be the water chain on day 6 | Delays and the deck |
| `v16_event_acceptance` | A bot plays until the first chain comes up by itself, instead of waiting for one named chain by day 150 | The named chain may be off in this run's deck |
| `v16_ui_tests`, `v16_career_boundaries`, `v16_economy_tests`, `v16_f12_transport`, `v16_research_company_review` | Last stage is 5; first draw day from the rule file; roads finished by hand where the test is about something else; a laboratory needs a residential town | Rule changes; none of the checks was weakened |
| `exe_drive_v17` | Presses `Speed_6`, a research card; checks the column and gauge; allows 8 minutes to stage 2 | Longer stage 1 |
| `make_fixtures_v17` | Moments moved to the new pace: midgame day 900, late day 2,200, days up to 3,300 | Pace |
