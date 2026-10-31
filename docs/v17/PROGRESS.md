# Colony Charter 1.7 — Progress

## Final summary

**1.7.0 is built and packaged in `delivery\v17`. 24 of the 26 rows below pass; one is a miss and one is NOT_RUN.** Nobody has played it yet: every result is a test, a bot or a script, not a person.

### What changed

- A beginner tutorial on its own planet, with one-time tips afterwards.
- Generated planets: plate continents, oceans, climate, rivers, 14-40 candidate sites, plots with uncertain estimates, two kinds of road and sea routes.
- Research that matters: 20 technologies that each unlock something, concentrated teams, paid research, megaprojects.
- A three-stage contract instead of a checklist; governor takes about 167 days at standard instead of 19.
- People who come and leave for visible reasons; wages and recruitment; prices that fall with exports; money with uses.
- 28 events and 6 chains that repeat with cooldowns and rarely stop the clock.
- Build dialog, site card, settlement panel and economy page rewritten to answer what to do and why. Saves are 47 KB instead of 8-11 MB.
- Difficulty and openings that change the start and the pressure, not the rules.

### §5.2, 1.6 versus 1.7

| Area | Target | 1.6 | 1.7 | |
|---|---|---|---|---|
| Floor | rush bot not before day 90 | day 19 | day 116 | PASS |
| Balanced award, standard | 120-180 | day 19 | day 167 | PASS |
| Balanced award, easy | 90-150 | day 19 | day 143 | PASS |
| Balanced award, hard | 160-230 | day 42 | day 194 | PASS |
| Openings: medians | within 15% | 19 / 25 / 19 | 166 / 160 / 179 (12%) | PASS |
| Openings: best bot | differs by opening | - | rush for all three at standard | **MISS** |
| Passive bot | review ~60, fails ~150 | 87 / 137 | 60 / 150 | PASS |
| Sloppy bot | review everywhere, fails on hard | yes | yes, 60 of 60 on hard | PASS |
| Population | stage goal at award; 300 by 360; 600 by 720 | 78 / 80 | 431 / 980 | PASS |
| Labour lever | wage 1.0→1.3 moves immigration 20% | no wage policy | +39% | PASS |
| Research, balanced | 3 techs, 10-20% scientists, 15-30% spend | 0, 8%, 11% | 5, 13%, 17% | PASS |
| Research-first | 6 techs, award in band | 0, day 30 | 8, day 172 | PASS |
| Money | reinvest 60%; income ×2.5 from 180 to 720 | 0%, ×1.16 | 79%, ×3.37 | PASS |
| Export mix | no good above 60% | worst 57% | worst 51% | PASS |
| Events | 25 short, 5 chains; 1 pause per 20 days at most; 15 distinct; no early repeat | 10, 3; 1 per 60; 10; - | 28, 6; 1 per 38; 28; 0 repeats | PASS |
| Geography, 200 seeds | sites 14-20, 20-30, 28-40; 3 pairs; 3 archetypes; land 25-45%; 2-6 continents | not measured | 15-20, 20-30, 28-40; 3; 3; 28-42%; 2-6 | PASS |
| Road trade-off | cheaper is slower for 30-70% | - | 58% of 2,798 pairs | PASS |
| Determinism | byte-identical at 720 days and at any speed | replays identical | replays identical; 1×, 4×, 10× identical | PASS |
| Audits | 0 errors, with 50 fuzz runs | 0 in 950 | 0 in 950 | PASS |
| Save size | 1.5 MB at most | 8-11 MB | 47 KB at day 720 | PASS |
| Save, load | 100 ms, 300 ms at most | 209 ms, 242 ms | 10 ms, 19 ms | PASS |
| Autosave | no frame over 50 ms | not measured | worst frame 34 ms | PASS |
| Page open, warm | 100 ms at most | not measured | 24 ms at most | PASS |
| Region, cold | 1.0 s, no frame over 50 ms | not measured | median 767 ms, worst 822 ms; worst frame 43 ms | PASS |
| Tutorial | headless run, skip, replay | none | all pass | PASS |
| Tutorial, human first run | - | - | NOT_RUN | NOT_RUN |

1.7 figures are the balance harness at `evidence/v17/balance/2026-10-31T13-06-47.json` (950 runs) and the exported EXE on an i9-14900HX with an RTX 4070 Laptop GPU (`evidence/v17/perf`).

### Open issues

1. **Miss: best bot by opening.** At standard, rush is fastest with all three openings, by only 1.5 days over research-first with science. Without rush the best bot does differ (balanced, balanced, research-first), and it differs at easy and hard. I did not redefine the target.
2. **Late takeovers.** 18 of 180 balanced runs are taken over, 17 of them after the award, around day 430-720, once mines run out. The bot never hands over, which is the game's answer to that moment, but the late economy may feel tight to a person too. One hard run missed the award.
3. **One unexplained crash.** `v17_speed` crashed once in the engine (signal 11, main thread, no C++ symbols) on about 40 runs and did not come back in 38 repeats. Cause unknown. It happened with the test driving the clock without frames; the test now gives the engine a frame per day. Worth watching in playtests.
4. **A world with no cache** must be regenerated when its save loads: about 0.5 s, 1.5 s at worst, above the 300 ms target. This needs the cache folder to have been deleted; the game keeps it.
5. **NOT_RUN:** human playtests, and a manual tutorial run in the EXE. The EXE run was scripted through its real buttons. `docs/v17/PLAYTEST.md` has a 30-45 minute checklist.
6. Of 198 capture images, about 60 were viewed; the rest were only checked to exist at the right size.

### Next three improvements

1. Play it: run `PLAYTEST.md`, then fix the tutorial wording and pacing that a person trips on. Nothing else here can stand in for that.
2. Give the late game more to do when mines run out: lasting non-mining jobs, and a prompt towards handover before debt starts.
3. Measure the whole career in the harness: bots that hand over, so a second and third planet get balance numbers too.

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
| 8 Difficulty, openings, career, performance, release | Done (`v17-phase8`, `v1.7.0`) |

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

- Phase 8: difficulty adds event and price pressure; openings differ as W12 lists; stewardship counts new income; food reaches the end of road chains; company tolerates tiny risk; sites keep ground for the town; deposits 1.25×; bots adapted; capture matrix; EXE build and scripted check; performance probe; atlas finishing off the main thread; README, CHANGELOG, PLAYTEST.

## In progress

Nothing.

## Next step

Nothing is planned. The user's playtest comes next (`docs/v17/PLAYTEST.md`).
