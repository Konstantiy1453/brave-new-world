# Colony Charter 1.7 — Progress

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `PLAN.md`.

| Phase | State |
|---|---|
| 0 Infrastructure and baseline | Done (`v17-phase0`) |
| 1 Bugs, QA export, formatting | Done (`v17-phase1`) |
| 2 Foundations | Done (`v17-phase2`) |
| 3 Contract, population, economy | Done (`v17-phase3`), day-720 rows await Phase 5 |
| 4 Research | Next |
| 5–8 | Not started |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

- Phase 2: simulation split into modules; English keys; `Sim.geo` split from `state`; save schema 3 with migration; autosave on a worker; reconciler UI with cached pages; map split into layers with signature-gated updates. Harness identical to Phase 1.

- Phase 3: three-stage contract with licences and soft deadlines; attractiveness, immigration, wage policy, recruitment, births; market saturation; running costs; road upkeep and closure; costlier aid; needs-first imports; depleted mines idle; `build_forecast`; contract and population pages; bots rewritten on a shared `colony_bot.gd`.

## In progress

Nothing.

## Next step

Phase 4: tech tree from Appendix D in `economy.json`, tier costs, lab L2, research contracts, building upgrades, megaprojects, tech-tree UI, milestones for megaprojects and tier 2, research rows. Tuning aids: `game/tests/balance/trace_run.gd` prints one bot's timeline.

## Blockers

None.

## Latest harness metrics

Phase 3, `--full`: floor day 111; balanced award easy 137, standard 172, hard 201; passive review 57, failure 147; sloppy fails on hard; 0 audit errors. Misses: day-720 population and money (deposit exhaustion until Phase 5), research and event rows (Phases 4 and 6). See `BALANCE.md`.
