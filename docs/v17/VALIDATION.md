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
