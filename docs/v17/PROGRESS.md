# Colony Charter 1.9 — Progress (in development)

Started 2026-11-07 from the user's request after a friend compared the 1.8 demo with TerraGenesis:
the planet should turn, show day and night with lit towns and roads at night, the surface looked
too rough, and the map needs moving elements such as clouds (Plague Inc. / Rebel Inc. style). The
3ds Max models uploaded the same day (release `art-assets-20261107`) and the near-future set delivered on
2026-11-09 (release `art-assets-20261109`) are placed in the game. Balance
work follows `docs/superpowers/plans/2026-11-01-v19-money-and-models-instructions.md` Part A.

Evidence labels as in `CLAUDE.md`. Everything below ran in a Linux cloud container (Godot 4.5.1
Linux build, software OpenGL under Xvfb); the Windows EXE, real-GPU frame times and a human playtest
are **NOT_RUN**. Branch `v17` is on GitHub (`origin/v17`).

## Done

| Area | What | Evidence |
|---|---|---|
| Moving globe | Planet spins (240 s a turn at 1×, faster with game speed, eases out on drag, zoom and click; a clicked site stays in view); fixed sun with a real terminator; seasons over the 360-day year move the terminator and the ice edges; moonlit night side | source-project window, screenshots viewed (`evidence/v17/art/dynamics/globe_*.png`) |
| Night lights | Warm town lights, cold industrial lights and dotted road lamps after sunset on the globe and the flat map; town patches fade at night | screenshots viewed |
| Surface | Atlas stores geography; per-pixel palette shared by globe, flat map and regional ground: smooth coastlines, blended biomes, sun-lit relief, ocean depth, glint, organic ice caps | screenshots viewed |
| Clouds | Animated clouds on latitude winds, cross-faded layers, drifting cyclones with eyes and arms, day/night cloud lighting, twilight tint, atmosphere rim lit by the sun | screenshots viewed |
| Region dynamics | Day and night from the site's place on the globe; lit windows, lamp pools, headlights; trucks, vans and buses on the service roads; smoke from working plants; drifting cloud shadows; rippling water; smooth cargo motion on globe and flat map | screenshots viewed |
| Settings | 「地图画面」: spin, day/night with lights, clouds/weather (off hides clouds) | automated tests (ui_contract) |
| Models | `tests/art/convert_models.gd` turns the FBX exports of releases `art-assets-20261107` and `art-assets-20261109` into 122 runtime meshes (49 s, 6.9 MB, two runs byte-identical); each model within its triangle target, shares weighted by colour slot (five with open crop strips, tree crowns or glass panes are recorded exceptions); all 61 building kinds drawn with their own models but `service`; 36 kinds with their own construction state, the rest with the shared site kit; terraforming stages and district levels drawn as they are finished; shuttle (parked and in flight), its pad, trucks, vans and buses modelled; closed-mine plots by ore, landing pods, street lamps, route gantry, road closures, bridges, harbour quay and cargo ship placed in their game contexts; suite `v19_art` checks budgets, slots, footprints, depth, construction states and stages (plan B7) | automated tests (`v19_art` 1,063 checks), contact sheets viewed (`evidence/v17/art/gallery/`), region, shuttle and great-work captures viewed (`evidence/v17/art/models_1109*/`) |
| Tests | Linux runner `tools/run_tests.py`; seam test measures under 1.8 lighting; terrain identity checks geometry | automated tests |
| Money | Market floor 0.55; +2.5% cash per further copy (to ×1.75; homes, great works, roads and outposts exempt); data centres ×0.85 and foodworks beyond the sixth ×0.8 per copy; administration grows with residents (scale 2,500) and settlements (+15% each); optional public services budget (levels 0–3); bots use it by cash cover; harness rows for cash cover, absorption and budget use; new suite `v19_money` | balance harness (quick, Linux), automated tests, screenshots viewed (`evidence/v17/art/pages/`) |
| Money readouts | Economy page: 「现金可支撑 N 天」 by band (red under 30 days; at 180+ once 90 days are seen, a hint where idle money could go), the administration line with the step for 100 more residents and one more settlement, market rows with the price after another 100 t and the floor price (「市场已饱和」 at the floor); cover days in the top-bar money tooltip; advisor line, in this order, for export income leaning on mines with under 360 days of reserves, counting goods made from their ore (a third or more of the month's export value; the share also shows on the economy page), for a good exported at its floor and for idle money. One `Sim.cover_view()` serves the page, the advisor and the bots | automated tests (`v19_money` 56 checks, `ui_contract`), developer probe (`tests/balance/mine_probe.gd`, normal play and `--hands-off=1080`), screenshots viewed (`evidence/v17/art/pages/economy*.png`, `economy_day1440.png`) |

| Spending by sink | Every payment from public cash is summed by sink and colony year (`state.stats.sinks`); economy page 「钱花在哪」 for the last four years; harness INFO row | automated tests (`v19_money`), screenshots viewed |
| Career transfer | After the award, public cash buys career funds at 2 : 1, up to ¥200,000 a colony year; career page control; bots move cash above 240 days of cover | automated tests (`v19_money`) |
| Commissioned research | Levels 1/2 on a project its own team works on, ¥100–450 a point by tier, ×1.25 per other commission; research-page switch with cost and days saved; optional spending (this and services) only from cash beyond two days of bills | automated tests (`v19_money`), screenshot viewed (`research_commission.png`) |
| Saves | Schema 5 in `ColonyCharter/v19`; 1.8 and 1.7 saves are read from their own folders, upgraded on load with a log line, and never written | automated tests (`v19_money`; the Windows-recorded save suites are for the Windows run) |
| Paybacks | New suite `v19_payback` (plan bands; mines in year 6, factories in year 4); heavy mines dearer with twice the upkeep, renewables cheaper and stronger, commerce ¥0.3, foodworks dearer, processors valued at the import price | automated tests (`v19_payback` 39 checks) |
| Windfall case | Harness case: the balanced bot with ¥1,000,000 on day 1,080, compared on the same seeds | balance harness |
| Late great works | Terraforming (three stages, planet tint), capital district (five levels), exchange, shipyard, emergency network; five tier 4–5 techs (127 in all); later stages and levels buy missing materials and parts at import price, as the first stage does; bots build each step when cash pays for it with its supplies and keeps 10 days of expenses (60 before the award), save for the next one after the award and chase its technologies; harness INFO row; stand-in models | automated tests (`v19_money` 155 checks, `v19_payback` unchanged), developer probe (balanced bot, 10 years: emergency network on seeds 260129 and 42, capital district on 42), screenshot viewed (`terraform_compare.png`) |
| Shuttle | Short-range shuttle line from the start: straight hop ≤ 3,500 km, pads in 10 days, 1–2 days a trip, 4 t a day, ¥8,000 + ¥2/km, ¥40 a day, 30× a road's fee; stands down when a road or sea route opens; not part of the contract network; cyan arcs on the maps, a pad and a flying craft in the region | automated tests (`v19_money` 149 checks), screenshots viewed (`evidence/v17/art/shuttle/`) |
| Building icons | `tests/art/bake_icons.gd` renders every kind's model (tint, scale, the map's daylight) to `assets/icons/buildings/<kind>.webp` (lossless), 128 px with mipmaps; build card 64 px, building column 32 px; goods keep their SVG pictograms | screenshots viewed (`evidence/v17/art/pages/settlement.png`, `build.png`), automated tests (`ui_contract`, `v16_ui_tests`) |
| Windows sheet | `docs/superpowers/plans/2026-11-08-v19-windows-verification-instructions.md` and `tests/art/frame_time_probe.gd` for the run only the user's PC can do | — |

## Money: quick harness on Linux (3 seeds, standard)

| | 1.8.0 on Linux | first pass (plan values) | gentle | stronger variant | **kept: gentle, homes exempt** |
|---|---|---|---|---|---|
| Balanced award, median | day 2,464 (9/9) | day 2,548 (8/9) | day 2,400 (9/9) | day 2,398 (9/9) | day 2,599 (9/9) |
| Research-first award, median | day 2,204 | day 2,554 (8/9) | day 2,274 (8/9) | day 2,416 (8/9) | day 2,479 (9/9) |
| Cover day 720 to award, median / p90 | 74 / 158 | 12 / 76 | 15 / 101 | 11 / 69 | 16 / 85 |
| Cover one year after award, median / p90 | 85 / 634 | 24 / 60 | 8 / 40 | 3 / 82 | 12 / 81 |
| Absorption, years 3–7 | 79–111% | 95–107% | 92–111% | 96–110% | 93–108% |
| Taken over (rush, balanced, research-first) | 0 / 27 | 3 / 27 | 2 / 27 | 1 / 27 | 2 / 27 |
| Wage lever | +26% | +17% | +18% | +23% | +23% |
| Services budget used (balanced) | - | - | 7 / 9 runs | 4 / 9 runs | 6 / 9 runs |
| Openings: spread of medians | 24% (miss) | 8% | 17% (miss) | 23% (miss) | 4% |

The last column is the kept configuration, confirmed by the run in `BALANCE.md` (label `1.9-money-linux`,
2026-11-07T14-03-08). It meets every row a quick run measures except two: the services budget is used in 6
of 9 balanced runs (the row asks for 8), and the sloppy row needs hard difficulty, which only full runs play.
The openings row passes (medians 4% apart; the workers opening favours rush). Award medians are about 200
days later than the gentle run without the exemption, but single runs moved both ways (balanced, science,
seed 260129: day 2,304 → 2,174; capital, seed 20261029: 2,706 → 3,042). Both takeovers are rush runs that
missed the main contract deadline (days 3,091 and 3,248). With 3 seeds a cell all of this may be noise: a
full run (10 seeds, 3 difficulties) on Windows is still to do.

## Late great works and the shuttle: quick harness and probes (Linux)

Quick harness `1.9-great-works-shuttle-linux` (commit `c5cb6d0`, 2026-11-08T20-29-06, 51 runs, 0 audit
errors): balanced award median day 2,694 (9/9), research-first 77 techs by day 2,403, cover from day 720
to the award 12 / 102 days (median / p90) — the same as the run before the great-works bots, because the
bots before the award are unchanged. After the award the cover is 56 / 150 days (was 18 / 148): the bots
now save for the next great work. Absorption 95–109% in years 3–7, wage lever +23%, determinism 3/3.
Late great works standing at the end: emergency network 6 of 21 runs, capital district 1 (level 3),
terraforming, exchange and shipyard none. Takeovers 4 of 27 (two research-first, two rush; the rush runs
spent nothing on late works, so this is run-to-run spread, not the change). Misses, the same three as
before: openings (research-first is best with every opening), sloppy (needs hard difficulty, which only
full runs play), services budget (6 of 9 runs; the row asks for 8).

Developer probes (`tests/balance/bots/balanced_bot.gd` and `rush_bot.gd`, scripts in the session's scratch
area, figures here):

- 15 years, balanced bot, seed 42, after the bots learned to clear ground in any full town (`3c19e77`):
  all five works are built — emergency network from day 2,850, capital district 3,480 (level 5),
  shipyard 4,250, exchange 4,720, terraforming started 5,250. Seed 20261029 (award day 3,033): district
  level 5 and the emergency network started by day 5,400; its shipyard was unlocked on day 5,337. The
  tier 4–5 technology chains (6–8 techs) set the pace; the harness ends 2–3 years after the award.
- Shuttle, rush bot, the quick seeds and openings, 4 years: 8 of 9 games open shuttle lines, 13 lines
  carrying 146–510 t each; 12 stood down when the road to the same outpost opened. The harness has a
  "Shuttle lines" INFO row from `3c19e77` on.
- Final quick harness `1.9-final-linux` (commit `3c19e77`, 2026-11-08T21-57-33, 51 runs, 0 audit errors,
  in `BALANCE.md`): the same as the run above except the emergency network stands in 7 of 21 runs and the
  cover a year after the award is 56 / 127 days. Shuttle lines: 8 of 9 rush runs, 20 lines, all 20 stood
  down when a road or sea route to the same settlement opened.

## Test results (Linux)

Headless suites at commit `3c19e77`: 37 pass, 4 fail — the same 4, with the same failing checks, as the
untouched 1.8.0 source on Linux (`v17_saves`, `v17_tutorial`, `v18_systems`, `world_v16_seed`:
Windows-recorded fixtures and world hashes do not reproduce on the Linux build). `v19_money` (155 checks),
`v19_payback` (39 checks) and the new `v19_art` (479 checks) pass; `ui_contract` checks the economy page's
cover, administration and floor lines; `v17_contract_population` follows the 1.9 administration rule. Of
the `review_*` tools, `review_save_nested` passes; the others fail on both versions on their hard-coded
`D:` output paths (they then wait for the runner's 540 s timeout, so they were not run this time). Window
suites under Xvfb: `world_v16_visual` and `world_v17_seam` pass; `v16_interaction_probe` and
`v16_scroll_probe` fail with the same script errors as 1.8.0 on Linux (22 and 8, counted on both): the
1.6 acceptance fixture they load does not rebuild its world on the Linux build.

## Not done / open

1. Windows: re-record the capture fixtures (rules and save schema changed), rebake the menu atlas,
   run every suite, export the EXE and measure frame times on a real GPU
   (`tests/art/frame_time_probe.gd`; the cloud and flat-map shaders are the heaviest). Step by step,
   with which way to fix each miss: `docs/superpowers/plans/2026-11-08-v19-windows-verification-instructions.md`.
2. Models: the 2026-11-09 delivery is in the game (every kind's own model and most construction states,
   the great works' stages and levels, the shuttle, its pad and the vehicles). Still to model, per the
   brief: `service` (the private enterprise's site; the commerce arcade stands in), the level 2–3
   upgrade add-ons, colonists, and four key-art renders for the menu and award screens. The 25 kinds
   modelled before 1.9's brief (apartment, arcology, clinic, …) keep their present-day look and have
   no construction state of their own.
3. The converted models and icons are committed. Converting again is only needed after a new delivery; on the
   user's PC `--source=D:\勇敢新世界` finds every `art_reserve/` pack, then re-bake the icons (window) and
   run the import.
4. Building icons are baked from the models; re-run `tests/art/bake_icons.gd` (window) and the import
   whenever converted models change.
   The plan's menu and award images wait for key art in the new look (requested in the model brief).
5. Money: every plan A2 item is in; what is left is measurement. The full harness run (10 seeds, 3
   difficulties) is for the Windows run. No late great work is dropped: the harness ends before the
   late chains finish, and a 15-year game builds all five (DECISIONS.md).
6. The README still describes the 1.8.0 release; its 「后期钱会花不完」 limitation (in
   `docs/HISTORICAL_README_1.8.md`) is answered in the 1.9 release notes once the full run confirms the
   money rows.
7. **Found, not fixed: a won colony can still be taken over.** Balanced bot, seed 260129, capital
   opening: awarded on day 2,527, then taken over by the company on day 3,787 while holding ¥498,000,
   for "持续住房或就业不足" — its capital (1,090 people) has 486 idle workers for 357 jobs and no free
   ground, because new homes took the ground as it grew. The bot from before this session's changes is
   taken over the same way (day 4,043), so the cause is older than the great-works work. The 10-year
   harness never sees it. Ways out, for the user to choose: a bot that keeps ground for jobs and clears
   it for workplaces when idle workers pile up (what a careful player does); or a softer company rule
   after the award (premise change); or both.

**Resume here.** Read `CLAUDE.md`, this section, then the 1.9 instructions in
`docs/superpowers/plans/2026-11-01-v19-money-and-models-instructions.md`.

---

# Colony Charter 1.8 — Progress

## Final summary

**1.8.0 is built and packaged in `delivery\v17`. Of the 24 rows below, 20 pass, 3 miss and 1 is NOT_RUN.** The request is in `V18_BRIEF.md`, the design in `V18_PLAN.md` and `DESIGN.md`, judgment calls in `DECISIONS.md`. Figures are the balance harness at `evidence/v17/balance/2026-11-01T03-10-20.json` (480 runs) and the exported EXE (`evidence/v17/perf`, `evidence/v17/exe_drive`).

### What changed, point by point

| # | Request | Result |
|---|---|---|
| 1 | Governor in 6-8 years on standard | Median day 2,454, 6.8 years; at 6× about 35 minutes of play |
| 2 | Pollution no longer a distrust source; exponential | Planet-wide, out of `company.gd`; 0.5% at most in year 3, 33% by year 8 if ignored, 2.9% for a colony that deals with it |
| 3 | Speeds | 1×, 3×, 6× |
| 4 | 工人 → 工程队, 研究员 → 研究团队 | Every string; a test scans rule and UI files |
| 5 | Resource table | Total and monthly change; power and water show supply and surplus, since neither is stored |
| 6 | Distrust gauge, slower rise | Gauge beside the map with thresholds and the day's change; largest daily rise 0.52 |
| 7 | Research by cards | 4 categories, 3 random cards (4 with a technology), pick one, send a team; redraw for money. What the charter needs is always dealt |
| 8 | Roads take longer | Median first road 146 days; from distance |
| 9 | Islands | Ordinary starts; sea routes with no technology, ports at both ends |
| 10 | Building column | For the selected settlement: under way first, with date and bar |
| 11 | Longer builds | 12-35 days basic, 45-120 advanced, 200-300 great works |
| 12 | Events | About 30% of the pool off in each run, 45% of draw days empty, seeds share 47% of what fires; all text rewritten |
| 13 | More technology | 122 technologies, 39 new buildings (56 in all) |
| 14 | Two settlement types | Residential and frontier, chosen when the expedition leaves; buildings belong to one or both |
| 15 | Real planets | 0.6, 1.0, 1.3 Earth radii; every route measured on that sphere |

### The bar in `V18_BRIEF.md`

| Area | Target | 1.7.1 | 1.8.0 | |
|---|---|---|---|---|
| Balanced award, standard | 2,160-2,880 | day 173 | day 2,454, 27 of 30 awarded | PASS |
| Balanced award, easy | 1,800-2,520 | day 156 | day 2,343, 28 of 30 | PASS |
| Balanced award, hard | 2,520-3,240 | day 211 | day 2,709, 27 of 30 | PASS |
| Floor | rush never before day 1,440 | day 107 | day 2,086 | PASS |
| Openings: medians | within 15% | 11% | 2,752 / 2,623 / 2,294, 20% from first to last | **MISS** |
| Openings: best bot | differs by opening | yes | research-first on all three | **MISS**, same row |
| Passive bot | review by 150-400, takeover by 400-900 | 60 / 150 | 168 / 438 | PASS |
| Sloppy bot | review everywhere, takeover on hard | yes | yes, 30 of 30 on hard | PASS |
| Population | 300 by year 2; 800 by year 4 | - | 385 / 946 | PASS |
| Labour lever | wage 1.0→1.3 moves immigration 20% | +29% | +26%, from year 2 | PASS |
| Research, balanced | 40 technologies, all categories, teams 10-20% | 5 of 20 | 40, 4, 12% | PASS |
| Research-first | more technologies, award in band | 8, day 181 | 74, day 2,163 | PASS |
| Technology pool | 100, 4 categories, 30 new buildings, offers differ | 20 | 122, 4, 39 | PASS |
| Money | reinvest 60%; year 6 income 2.5× year 2 | 84%, ×3.76 | 92%, ×3.70 | PASS |
| Export mix | no good above 60% | worst 65% | median 30%, worst 41% | PASS |
| Pollution | under 2% through year 3; no-control 15% by year 8; no company source | - | 0.5%; 33%; test holds it | PASS |
| Distrust | largest daily rise 0.8 | - | 0.52 | PASS |
| Events | 60 short, 10 chains; 25% off; 1 pause per 40 days at most; 25 distinct | 28, 6 | 71, 12; 30%; 1 per 215; 53 | PASS |
| Geography, 200 seeds | radii, site counts, 3 start pairs, islands can start | - | all hold; worst world 3.0 s | PASS |
| Roads | first road 3-10 months | - | 146 days | PASS |
| Road trade-off | cheaper is slower on 30-70% of pairs | 54% | 90% of 2,568 pairs | **MISS** |
| Determinism and audits | identical at 2,880 days and any speed; 0 audit errors | yes | 3 of 3 replays; 1×, 3×, 6×; 0 errors in 480 runs | PASS |
| Saves and speed | 1.5 MB; 100 and 300 ms; no frame over 50 ms; warm page 100 ms; cold region 1 s | yes | 59 KB; 12 and 25 ms; 34 ms; 18 ms; 739 ms, worst frame 48 ms | PASS |
| Human playtest | - | - | NOT_RUN | NOT_RUN |

### Open issues

1. **Two rows miss.** The capital opening's median award is 20% later than the science opening's; research-first is the fastest on all three openings, so the best bot does not differ by opening. The road trade-off reads 90%: on real planets the cheap road is nearly always the slow one, so the row as written no longer fits, but it is reported, not redefined.
2. **Bots still lose some games.** 3 of 30 balanced runs on standard, 2 on easy and 3 on hard are taken over before an award, usually with money in the bank; one on standard and one on hard are taken over a little after one. A person may or may not hit the same walls. Rush loses 10-50% on standard and hard.
3. **Three rare failures that did not repeat.** Over the several hundred test and harness processes of this work: `v17_speed` crashed once in the engine (signal 11, main thread, in ordinary `refresh` code), a balance shard died once with no output, and `v16_interaction_probe` once read garbage while decoding a fixture. All three were under full load; 96 further `v17_speed` runs, the shard and the probe were clean. The same kind of crash was noted once in 1.7.0. The worker threads were reviewed and touch only their own data, so the cause is not found. The harness now re-runs a lost shard and says so.
4. **Money late in the game.** Balanced colonies hold about ¥500,000 a year after the award, and more in some runs. Great works and upgrades are not enough of a sink.
5. **New buildings use old models.** 39 new kinds borrow the closest existing 3D model and icon; the modelling task in `art_reserve` is separate.
6. Of the final capture images, the 1280×720 set at 20 px was viewed; see `VALIDATION.md`.

### Next three improvements

1. Play it: run `PLAYTEST.md`. Bots cannot say whether six years are fun.
2. Give frontier and residential towns more reason to differ, and late money something to buy.
3. Replace the borrowed models and icons with the new buildings' own.

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `V18_BRIEF.md`.

---

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
