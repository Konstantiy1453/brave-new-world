# Colony Charter 1.7 — Progress

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `PLAN.md`.

| Phase | State |
|---|---|
| 0 Infrastructure and baseline | Done (`v17-phase0`) |
| 1 Bugs, QA export, formatting | Done (`v17-phase1`) |
| 2 Foundations | Done (`v17-phase2`) |
| 3 Contract, population, economy | Done (`v17-phase3`), day-720 rows await Phase 5 |
| 4 Research | Done (`v17-phase4`) |
| 5 CC-GEO-2.0, sites, roads, plots | Done (`v17-phase5`) |
| 6 Events | Next |
| 7–8 | Not started |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

- Phase 2: simulation split into modules; English keys; `Sim.geo` split from `state`; save schema 3 with migration; autosave on a worker; reconciler UI with cached pages; map split into layers with signature-gated updates. Harness identical to Phase 1.

- Phase 3: three-stage contract with licences and soft deadlines; attractiveness, immigration, wage policy, recruitment, births; market saturation; running costs; road upkeep and closure; costlier aid; needs-first imports; depleted mines idle; `build_forecast`; contract and population pages; bots rewritten on a shared `colony_bot.gd`.

- Phase 4: Appendix D's 20 technologies with tiers and prerequisites; R10 = 2.0; lab L2; paid research contracts; building upgrades that keep the building working; clinic, hydroponic farm, component plant and the `components` good; road paving; three megaprojects with their effects and milestones; prefab lab and head start for the science opening; tech-tree page with staffing previews; `v17_research` suite.

- Phase 5: CC-GEO-2.0 in `game/world/geo2/` (plate-driven continents, sea-level quantile, climate with rain shadow, per-cell attributes, D8 rivers); Poisson-disk sites with archetypes, quotas, Appendix G names and a playability validator; disk geo cache; `routes.gd` A* with valley, engineered and sea routes; plots instead of the building cap; surveys with uncertainty bands; hidden and deep deposits; road network with per-road dispatch, chains and no backflow; sea expeditions; workers follow jobs along roads; 1.6 saves migrate to sites, plots and roads; region view on a height field with instanced nature, baked building models, one-plane sea and ribbon rivers; map filters, automatic labels, colony footprints, climate ring; site panel with estimates.

## In progress

Nothing.

## Next step

Phase 6: repeatable event pool with cooldowns, decisions versus notices, notification feed and setting, magnitudes scaled to income, feasibility checks on every option, at least 25 short events and 5 chains (Appendix E), chain tests. Then re-tune: research-first award day, easy award band, worst-seed export mix, and the runs where a balanced colony is still taken over after the award. Tuning aids: `game/tests/balance/trace_run.gd` prints one bot's timeline.

## Blockers

None.

## Latest harness metrics

Phase 5, `--full`, 950 runs, 0 audit errors: floor day 109; balanced award easy 153, standard 175, hard 210; openings 174 / 162 / 186; passive review 59, failure 149; sloppy fails on hard; population 374 / 839; research 5 techs, 13%, 17%; money 83%, ×3.46; labour lever +27%; geography and road trade-off (57%) pass over 200 seeds. Misses: easy award 153 (band 90–150), research-first day 195, worst-seed export mix 82%, event rows. See `BALANCE.md`.
