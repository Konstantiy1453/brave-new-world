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
| 6 Events | Done (`v17-phase6`) |
| 7 Tutorial and UI content | Done (`v17-phase7`) |
| 8 Difficulty, openings, career, performance, release | Next |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

- Phase 2: simulation split into modules; English keys; `Sim.geo` split from `state`; save schema 3 with migration; autosave on a worker; reconciler UI with cached pages; map split into layers with signature-gated updates. Harness identical to Phase 1.

- Phase 3: three-stage contract with licences and soft deadlines; attractiveness, immigration, wage policy, recruitment, births; market saturation; running costs; road upkeep and closure; costlier aid; needs-first imports; depleted mines idle; `build_forecast`; contract and population pages; bots rewritten on a shared `colony_bot.gd`.

- Phase 4: Appendix D's 20 technologies with tiers and prerequisites; R10 = 2.0; lab L2; paid research contracts; building upgrades that keep the building working; clinic, hydroponic farm, component plant and the `components` good; road paving; three megaprojects with their effects and milestones; prefab lab and head start for the science opening; tech-tree page with staffing previews; `v17_research` suite.

- Phase 5: CC-GEO-2.0 in `game/world/geo2/` (plate-driven continents, sea-level quantile, climate with rain shadow, per-cell attributes, D8 rivers); Poisson-disk sites with archetypes, quotas, Appendix G names and a playability validator; disk geo cache; `routes.gd` A* with valley, engineered and sea routes; plots instead of the building cap; surveys with uncertainty bands; hidden and deep deposits; road network with per-road dispatch, chains and no backflow; sea expeditions; workers follow jobs along roads; 1.6 saves migrate to sites, plots and roads; region view on a height field with instanced nature, baked building models, one-plane sea and ribbon rivers; map filters, automatic labels, colony footprints, climate ring; site panel with estimates.

- Phase 6: events repeat after a cooldown (120–360 days); notices never pause, decisions pause when critical or when the player asks for all to pause; money in events scales with recent income; every option checks money, goods, beds, hands, research and roads, and shows why it is disabled; 18 new short events and 3 new chains (没有目的地的客船, 零点八毫米的裂缝, 山脊里的空白图); rockfall opens its event when a road really closes; `v17_events` suite tests each new chain's endings, deferral, timeout and save/load.

- Phase 7: tutorial (Appendix F) with named conditions, non-modal coach panel with outline, skip, back, replay, contextual tips, quiet opening and a scripted first shortage; daily rollups (`stats.gd`); build dialog with categories, plot choice and forecast; site card with role hints, travel options and cost multiplier; settlement panel with fix buttons, grouped buildings and pinned actions; economy page with 30-day categories, 90-day chart, runway, goods table and price trends; arrivals and departures; in-transit goods on road cards; very fast speed; new guide copy; main menu with save summary and tutorial toggle; capture suite `ui/capture_suite_v17.gd` with bot-written fixtures.

## In progress

Nothing.

## Next step

Phase 8: W12 difficulty and openings, career with new procedural worlds; close the §5.2 misses; performance measures (save, load, autosave frames, page open, region frames) in the real window; capture at all sizes; `tools/build_v17.ps1`, `tools/package_v17.py`, exported EXE checks; final `--full` and 200-seed runs; determinism at speeds; `PLAYTEST.md`, Chinese `README.md`, `CHANGELOG.md`, final summary here, release identity file, tag `v1.7.0`, `delivery\v17`.
