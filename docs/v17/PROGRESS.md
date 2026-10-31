# Colony Charter 1.7 — Progress

## Final summary

**1.7.1 is built and packaged in `delivery\v17`. 22 of the 26 rows below pass; three are misses and one is NOT_RUN.** Nobody has played it through yet: these results come from tests, bots and scripts. The user's first impressions of 1.7.0 led to 1.7.1 (`CHANGELOG.md`).

### What changed

- A beginner tutorial on its own planet, with one-time tips afterwards.
- Generated planets with a character: six land layouts, five climates and three reliefs drawn from the seed; 14-40 candidate sites that the player names when settling; plots with uncertain estimates; two kinds of road and sea routes.
- Research that matters: 20 technologies that each unlock something, concentrated teams, paid research, megaprojects.
- A three-stage contract instead of a checklist; governor takes about 173 days at standard instead of 19, and building takes about twice as long as in 1.7.0.
- People who come and leave for visible reasons; wages and recruitment; prices that fall with exports; money with uses.
- 28 events and 6 chains that repeat with cooldowns and rarely stop the clock.
- Build dialog, site card, settlement panel, building list and economy page that answer what to do and why. Saves are 47 KB instead of 8-11 MB.
- Difficulty and openings that change the start and the pressure, not the rules.

### §5.2, 1.6 versus 1.7.1

| Area | Target | 1.6 | 1.7.1 | |
|---|---|---|---|---|
| Floor | rush bot not before day 90 | day 19 | day 107 | PASS |
| Balanced award, standard | 120-180 | day 19 | day 173 | PASS |
| Balanced award, easy | 90-150 | day 19 | day 156 | **MISS** |
| Balanced award, hard | 160-230 | day 42 | day 211 | PASS |
| Openings: medians | within 15% | 19 / 25 / 19 | 177 / 160 / 176 (11%) | PASS |
| Openings: best bot | differs by opening | - | rush, balanced, balanced | PASS |
| Passive bot | review ~60, fails ~150 | 87 / 137 | 60 / 150 | PASS |
| Sloppy bot | review everywhere, fails on hard | yes | yes, 60 of 60 on hard | PASS |
| Population | stage goal at award; 300 by 360; 600 by 720 | 78 / 80 | 425 / 973 | PASS |
| Labour lever | wage 1.0→1.3 moves immigration 20% | no wage policy | +29% | PASS |
| Research, balanced | 3 techs, 10-20% scientists, 15-30% spend | 0, 8%, 11% | 5, 13%, 17% | PASS |
| Research-first | 6 techs, award in band | 0, day 30 | 8, day 181 | **MISS** by a day |
| Money | reinvest 60%; income ×2.5 from 180 to 720 | 0%, ×1.16 | 84%, ×3.76 | PASS |
| Export mix | no good above 60% | worst 57% | median 30%, worst 65% | **MISS** on 1 of 60 runs |
| Events | 25 short, 5 chains; 1 pause per 20 days at most; 15 distinct; no early repeat | 10, 3; 1 per 60; 10; - | 28, 6; 1 per 38; 29; 0 repeats | PASS |
| Geography, 200 seeds | sites 14-20, 20-30, 28-40; 3 pairs; 3 archetypes; land 25-45%; 2-6 continents | not measured | 15-20, 20-30, 28-40; 3; 3; 25-45%; 2-6 | PASS |
| Road trade-off | cheaper is slower for 30-70% | - | 54% of 2,708 pairs | PASS |
| Determinism | byte-identical at 720 days and at any speed | replays identical | replays identical; 1×, 4×, 10× identical | PASS |
| Audits | 0 errors, with 50 fuzz runs | 0 in 950 | 0 in 950 | PASS |
| Save size | 1.5 MB at most | 8-11 MB | 47 KB at day 720 | PASS |
| Save, load | 100 ms, 300 ms at most | 209 ms, 242 ms | 10 ms, 20 ms | PASS |
| Autosave | no frame over 50 ms | not measured | worst frame 20 ms | PASS |
| Page open, warm | 100 ms at most | not measured | 18 ms at most | PASS |
| Region, cold | 1.0 s, no frame over 50 ms | not measured | median 766 ms, worst 826 ms; worst frame 45 ms | PASS |
| Tutorial | headless run, skip, replay | none | all pass | PASS |
| Tutorial, human first run | - | - | NOT_RUN | NOT_RUN |

1.7.1 figures are the balance harness at `evidence/v17/balance/2026-10-31T17-13-30.json` (950 runs) and the exported EXE on an i9-14900HX with an RTX 4070 Laptop GPU (`evidence/v17/perf`).

### Open issues

1. **Three misses, all small and all after slowing the builds.** Easy awards on day 156 (target at most 150). Research-first awards on day 181 (at most 180). One standard run of 60 sold 65% crystal after day 180 (at most 60%). Five full harness runs and three quick ones moved these by a few days without closing them, and the export worst case swung between 64% and 79%, so I stopped rather than keep bending other rules. They need the user's call: accept, or loosen build times a little.
2. **Late takeovers.** 18 of 180 balanced runs are taken over. 16 earned the award first and fail between days 450 and 713, most of them out of money (`BALANCE.md`). The bot never hands over, which is the game's answer to that moment, but the late economy may feel tight to a person too. The other 2 are easy runs with the workers opening where the bot never founds a second town. The game refused nothing and the same seed settles on standard, so that is the bot's blind spot.
3. **One unexplained crash in 1.7.0's tests.** `v17_speed` crashed once in the engine (signal 11, main thread, no C++ symbols) on about 40 runs and did not come back in 38 repeats. Cause unknown. Worth watching in playtests.
4. **Generating a world** takes about 0.7 s and up to 3.6 s on the hardest seeds, now that difficult planets may need more attempts. Every new game pays this once. A load pays it only if the cache folder was deleted, and then it is above the 300 ms target; the game keeps that folder.
5. **Planet types.** A draw that gives no playable world softens, so archipelagos and arid planets turn up less often than their weights say, and on 32 of 200 seeds the planet is milder than the menu's forecast. The menu therefore says 多半是, and the toast at the start and the world page show the real type. `v17_world_stats` keeps every type present and fails if fewer than 75% of seeds keep their draw.
6. **NOT_RUN:** human playtests, and a manual tutorial run in the EXE. The EXE run was scripted through its real buttons. `docs/v17/PLAYTEST.md` has a 30-45 minute checklist.
7. Of the final 144 capture images, 32 were viewed: every page at 1280×720 with 20 px text, the tightest case, and 8 at larger sizes. The rest were written without errors but not looked at.

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
| After release: pace, names, building list, planet variety | Done (`v1.7.1`) |

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

- After release (1.7.1): CC-GEO-2.1 with planet characters; build times about doubled, days kept; settlements named by the player, sites numbered until then; building list page; seed box no longer tied to the tutorial; rules retuned.

## In progress

Nothing.

## Next step

Nothing is planned. The user's playtest comes next (`docs/v17/PLAYTEST.md`).
