# Colony Charter 1.7 — Progress

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `PLAN.md`.

| Phase | State |
|---|---|
| 0 Infrastructure and baseline | Done (`v17-phase0`) |
| 1 Bugs, QA export, formatting | Done (`v17-phase1`) |
| 2 Foundations | Done (`v17-phase2`) |
| 3 Contract, population, economy | Done (`v17-phase3`), day-720 rows await Phase 5 |
| 4 Research | Done (`v17-phase4`), climate visual on the globe and deep deposits await Phase 5 |
| 5 CC-GEO-2.0, sites, roads, plots | Next |
| 6–8 | Not started |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

- Phase 2: simulation split into modules; English keys; `Sim.geo` split from `state`; save schema 3 with migration; autosave on a worker; reconciler UI with cached pages; map split into layers with signature-gated updates. Harness identical to Phase 1.

- Phase 3: three-stage contract with licences and soft deadlines; attractiveness, immigration, wage policy, recruitment, births; market saturation; running costs; road upkeep and closure; costlier aid; needs-first imports; depleted mines idle; `build_forecast`; contract and population pages; bots rewritten on a shared `colony_bot.gd`.

- Phase 4: Appendix D's 20 technologies with tiers and prerequisites; R10 = 2.0; lab L2; paid research contracts; building upgrades that keep the building working; clinic, hydroponic farm, component plant and the `components` good; road paving; three megaprojects with their effects and milestones; prefab lab and head start for the science opening; tech-tree page with staffing previews; `v17_research` suite.

## In progress

Nothing.

## Next step

Phase 5: CC-GEO-2.0 in `game/world/geo2/`, sites with archetypes and quotas, survey and prospecting, `routes.gd`, road network, sea routes, plots instead of `SITE_BUILDING_CAP`, region view rework, 1.6 save migration. The bots must then found settlements by forecast; their colonies currently run out of deposits around day 360. Tuning aids: `game/tests/balance/trace_run.gd` prints one bot's timeline.

## Blockers

None.

## Latest harness metrics

Phase 4, `--full`: floor day 105; balanced award easy 142, standard 162, hard 198; openings 163 / 158 / 166; passive review 57, failure 147; sloppy fails on hard; balanced research 5 techs, 14% scientists, 23% spend; research-first 7 techs at day 178; 0 audit errors in 950 runs. Misses: day-720 population 506 and income ×0.98 (deposit exhaustion until Phase 5), event rows (Phase 6). See `BALANCE.md`.
