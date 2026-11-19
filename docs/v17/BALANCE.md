# Colony Charter 1.8 — Balance

Targets are in `docs/v17/V18_BRIEF.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **immigration-11** · 2026-11-14T06-17-50 · 2787 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 1440 | earliest day 2376 | PASS |
| Balanced award, normal | 2160-2880 | median 2254 (8/9 awarded) | PASS |
| Balanced award, easy | 1800-2520 | median -1 (0/0 awarded) | NOT_MEASURED |
| Balanced award, hard | 2520-3240 | median -1 (0/0 awarded) | NOT_MEASURED |
| Openings | medians within 15%; best bot differs by opening | capital 2784, workers 2374, science 2235; best { "capital": "research_first", "workers": "research_first", "science": "balanced" }; without rush { "capital": "research_first", "workers": "research_first", "science": "balanced" } | MISS |
| Failure, passive | review 150-400, failure 400-900 | review 168, failure 438 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 0/0 | MISS |
| Population | >= 300 by year 2; >= 800 by year 4 | 376 / 1038 | PASS |
| Research, balanced | >= 40 techs; every category; research teams 10-20% | 40 techs; 4 categories; 12% | PASS |
| Research-first | more techs than balanced, award in standard band | 76 techs; day 2124 | MISS |
| Money | reinvest >= 60%; income x2.5 from year 2 to year 6 | 107%; x3.69 | PASS |
| Export mix | no good > 60% after year 2 | median 27%, worst 35% | PASS |
| Cash cover before the award | day 720 to award: median <= 60 days, p90 <= 120 | median 13 days, p90 92 days | PASS |
| Cash cover after the award | last day, runs awarded by 2880: median <= 180 days, p90 <= 365 | median 16 days, p90 171 days | PASS |
| Services budget | used by the balanced bot (1.9 optional spending) | 5 of 9 runs, median 540 days paid | MISS |
| Absorption | spending >= 80% of operating surplus in years 3-7 | y3 98%, y4 106%, y5 124%, y6 106%, y7 105% | PASS |
| Spending by sink | balanced, normal: median a year in years 3-7 (no target) | buildings 341k, recruitment 98k, upgrades 65k, great_works 33k, services 11k, roads 9k, commissions 8k | INFO |
| Windfall | ¥1,000,000 on day 1,080, balanced, normal, capital (no target) | without: award 2784, cover on day 1440 84 days, 0 of 3 taken over; with: award 2480, cover on day 1440 227 days, 1 of 3 taken over; extra spending a run in years 4-6: services +506k, commissions +143k, recruitment +112k, buildings +110k | INFO |
| Late great works | standing at the end, balanced, rush and windfall runs (no target) | terraforming 0/21 (level 0), capital_district 5/21 (level 5), exchange 0/21 (level 0), shipyard 0/21 (level 0), emergency_net 10/21 (level 1) | INFO |
| Shuttle lines | rush runs that opened a short-range shuttle line (no target) | 8/9 runs, 18 lines, 18 stood down for a road or sea route | INFO |
| Events | <= 1 pause per 40 days; >= 25 distinct; 60 short, 10 chains; >= 25% off each run | 1 per 204 days; 63 distinct; 0 repeats; 79 short, 27 chains; 33% off; seeds share 48% | PASS |
| Distrust | largest daily rise <= 0.8 | worst 0.63 | PASS |
| Pollution | output penalty < 2% through year 3 | year 3 worst 0.2%; year 8 median 3.8% | PASS |
| Roads | first road takes 90-300 days | median 166 days | PASS |
| Pollution, no control | output penalty >= 15% by year 8 | 47.1% | PASS |
| Audits | 0 errors in every run | 0 errors in 51 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 360-day immigration by >= 20% | 174 to 234 arrivals (+34%) | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop y2 / y4 / y8 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | normal | capital | 3 | 100% | 2784 | 0% | -1 | 319 | 364 / 855 / 2218 | 41 |
| balanced | normal | science | 3 | 100% | 2235 | 0% | -1 | 250 | 376 / 1147 / -1 | 40 |
| balanced | normal | workers | 3 | 67% | 2374 | 33% | 3263 | 296 | 377 / 1038 / 2469 | 40 |
| passive | normal | capital | 3 | 0% | -1 | 100% | 438 | 15777 | -1 / -1 / -1 | -1 |
| passive | normal | science | 3 | 0% | -1 | 100% | 426 | 3519 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 3 | 0% | -1 | 100% | 446 | 426 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 1 | 0% | -1 | 100% | 459 | 0 | -1 / -1 / -1 | -1 |
| random_legal | hard | science | 1 | 0% | -1 | 100% | 323 | 0 | -1 / -1 / -1 | -1 |
| random_legal | normal | workers | 1 | 0% | -1 | 100% | 380 | 0 | -1 / -1 / -1 | -1 |
| research_first | normal | capital | 3 | 100% | 2139 | 0% | -1 | 283 | 351 / 933 / -1 | 76 |
| research_first | normal | science | 3 | 67% | 2284 | 33% | 2264 | 255 | 311 / 800 / -1 | 86 |
| research_first | normal | workers | 3 | 100% | 2014 | 0% | -1 | 306 | 344 / 901 / -1 | 67 |
| rush | normal | capital | 3 | 67% | 2717 | 33% | 3284 | 48 | 410 / 1023 / 2404 | 41 |
| rush | normal | science | 3 | 100% | 2573 | 0% | -1 | 267 | 324 / 895 / -1 | 41 |
| rush | normal | workers | 3 | 100% | 3072 | 0% | -1 | 305 | 390 / 909 / 2114 | 42 |
| sloppy | normal | capital | 3 | 0% | -1 | 100% | 764 | 375 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 3 | 0% | -1 | 100% | 764 | 246 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 3 | 0% | -1 | 100% | 717 | 15 | 105 / -1 / -1 | -1 |
| windfall | normal | capital | 3 | 67% | 2480 | 33% | 3270 | 319 | 364 / 968 / 2027 | 40 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-11-14T06-17-50 · immigration-11 (quick): 18 targets met, 4 missed.
- 2026-11-14T03-29-20 · stage4-5f596ee (quick): 18 targets met, 4 missed.
- 2026-11-13T09-53-32 · events-bot-days (quick): 18 targets met, 4 missed.
- 2026-11-13T09-05-58 · events-d36d01a (quick): 18 targets met, 4 missed.
- 2026-11-12T14-06-04 · fix-tips-5c50b0f (quick): 19 targets met, 3 missed.
- 2026-11-08T21-57-33 · 1.9-final-linux (quick): 19 targets met, 3 missed.
- 2026-11-07T14-03-08 · 1.9-money-linux (quick): 20 targets met, 2 missed.
- 2026-11-01T03-10-20 · v1.8.0 (full): 20 targets met, 2 missed.
- 2026-11-01T02-21-34 · 1.8 fifth full (full): 20 targets met, 2 missed.
- 2026-11-01T01-32-25 · 1.8 fourth full (full): 20 targets met, 2 missed.
- 2026-11-01T00-45-39 · 1.8 third full (full): 19 targets met, 3 missed.
- 2026-10-31T17-13-30 · v1.7.1 (full): 15 targets met, 3 missed.
- 2026-10-31T13-06-47 · release (full): 17 targets met, 1 missed.
- 2026-10-31T12-43-51 · release (full): 17 targets met, 1 missed.
- 2026-10-31T11-09-53 · phase7 (quick): 9 targets met, 5 missed.
- 2026-10-31T07-43-55 · phase5 (full): 14 targets met, 4 missed.
- 2026-10-31T06-27-17 · phase4 (full): 13 targets met, 3 missed.
- 2026-10-31T06-03-16 · phase 3 (full): 10 targets met, 6 missed.
- 2026-10-31T03-00-14 · phase 2 (quick): 3 targets met, 10 missed.
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.

## 1.9 money

The current results are a quick run (3 seeds, normal difficulty) on the Linux build: the easy and hard
rows are not measured there, and the sloppy row cannot pass without hard games. The 1.9 money settings
were compared over five such runs (1.8.0, the plan's starting values, gentle, stronger, and the kept
gentle settings with homes exempt from the copy surcharge); the comparison table is in `PROGRESS.md`
under "Money: quick harness on Linux". A full run (10 seeds, 3 difficulties) on Windows is still to do.

## 1.9 fix tips

Quick run `fix-tips-5c50b0f` (2026-11-12, Linux, 51 runs, 0 audit errors) after the cargo docks, link
levels, gift technologies and surveys, against `1.9-final-linux` (2026-11-08). The medians hold: the
balanced award 2694 → 2708, income ×4.08 → ×4.22, export worst 35% → 33%. Services budget MISS →
PASS (8 of 9 runs). Openings stay MISS (research-first is the best bot for every opening, as before).
Two rows moved the wrong way, and both turn out to be noise around their bar:

- **Labour lever, +23% → +6% (MISS).** `lever_probe.gd` (six seeds, year-2 immigration at wage 1.0
  and 1.3, medians):

  | Code | Change | Lever |
  |---|---|---:|
  | `608d645` (before) | as recorded | +23% |
  | `608d645` | event dice nudged (+1) | +15% |
  | `608d645` | event dice nudged (+2) | +16% |
  | `5c50b0f` (this) | as is | +6% |
  | `5c50b0f` | the three new events removed | +35% |
  | `5c50b0f` | the new events in the deck but never dealt | +6% |
  | `5c50b0f` | the new events only after year 2 | +6% |
  | `5c50b0f` | sea links need freight stations again | +3% |

  The new events never come up in the lever's window; what changes the result is the three extra
  rolls when a run deals its event deck, which reshuffle every later event. On unchanged code the
  event dice alone move the lever between +15% and +23%; over all eight probes it runs from +3% to
  +35%, around +15%. The recorded +23% was a lucky draw, and the bar needs more seeds to be measured,
  and may be a real miss at about +15%.
- **Payback, light iron mine in year 6** (`v19_payback`, seed 260129, band 70–150): 72 and 69 days
  before (as recorded and with nudged event dice), 63, 59 and 64 with this change and two variants,
  61 with a dearer iron mine (which also moved two other checks out of band). The colony's path
  decides whether its iron market is saturated by year 6.
- Per run, outcomes churn both ways: four runs that failed before now win, six that won now fail
  (two of them after their award). The balanced capital run on seed 20261029, awarded on day 3,033
  before (already past the band), now misses its main contract and is taken over on day 3,284.

Proposed for the user: measure the lever and the payback bands over more seeds (the lever over the
ten full-run seeds at least) before tuning anything; tuning to one path would chase noise.

## 1.9 events rewrite

Quick run `events-d36d01a` (2026-11-13, Linux, 51 runs, 0 audit errors). It covers everything since
`fix-tips-5c50b0f`: stage three a year later, the coast fix (no effect on the simulation) and GPT's
rewritten events. A run measuring stage three alone was started and then stopped: a shard died, and
its retry would have read the new events. Nothing from it is recorded.

| Row | fix-tips-5c50b0f | events-d36d01a |
|---|---|---|
| Balanced award, normal | median 2708, 8 of 9 awarded | median 2782, 6 of 9 awarded (PASS) |
| Income ×, year 2 to year 6 | ×4.22 | ×3.30 (PASS, bar ×2.5) |
| Labour lever | +6% (MISS) | +27% (PASS) |
| Research, balanced | 41 techs, research teams 11% (PASS) | 48 techs, 10% (MISS, just under the band) |
| Services budget | 8 of 9 runs (PASS) | 5 of 9 runs (MISS) |
| Events | 56 distinct, 72 short, 14 chains | 65 distinct, 79 short, 27 chains; a pause every 205 days |
| Largest daily distrust rise | 0.33 | 0.65 (bar 0.8) |
| Targets | 19 met, 3 missed | 18 met, 4 missed |

Two balanced runs finished stage three on days 1,751 and 1,698. Under the old day-1,500 deadline
they would have failed there, so the extension does what the user asked. Overall, though, the
balanced bot does worse: three of nine runs miss the main contract and are taken over around day
3,280 (one before), and in the run inspected the mid-game operating surplus falls by about half.

Much of that is the bot, not the events. `colony_bot._option_value` scores an event option as
reward − pay ± goods, plus a flat (factor − 1) × 500 for each effect, whatever its length. So it
always takes a free 90-day production cut (−125) over paying to avoid it (−2,700 at reference
income, more as the colony grows). The rewritten events make those free options long and heavy on
purpose, so the bot collects every penalty a sensible player would pay to avoid.

Quick run `events-bot-days` (same code, 51 runs, 0 audit errors): the bots value an event option in
money, with payments scaled as the game scales them, goods at their prices, and each effect over its
days on the share of daily income its kind touches, less its upkeep.

| Row | fix-tips-5c50b0f | events-d36d01a | events-bot-days |
|---|---|---|---|
| Balanced award, normal | 2708, 8 of 9 | 2782, 6 of 9 | 2686, 8 of 9 (PASS) |
| Income ×, year 2 to year 6 | ×4.22 | ×3.30 | ×3.40 (PASS) |
| Labour lever | +6% (MISS) | +27% | +38% (PASS) |
| Research, balanced | 41 techs, 11% | 48, 10% (MISS) | 40, 10% (PASS) |
| Research-first | 76 techs, day 2235 | 78, day 2206 | 74, day 2129 (MISS: 31 days before the band) |
| Services budget | 8 of 9 | 5 of 9 (MISS) | 7 of 9 (MISS) |
| Windfall runs awarded | 3 of 3 | 2 of 3 | 3 of 3 |
| Targets | 19 met, 3 missed | 18 met, 4 missed | 18 met, 4 missed |

A bot that weighs event costs is awarded as often as before the rewrite, and at the same median.
The events take a larger share of the economy than before, as designed: income grows ×3.4 from year
2 to year 6 against ×4.2. The two new misses (research-first a month early, services in 7 of 9 runs)
are of the size quick runs swing by. The current results block is this run.

## 1.9 stage four 14 months later

Quick run `stage4-5f596ee` (2026-11-14, Linux, 51 runs, 0 audit errors). Changes since
`events-bot-days`: stage four's deadline is 420 days later (normal 2,520) with stage five's kept at
2,880; the payback suite and the event option texts do not touch the simulation.

| Row | events-bot-days | stage4-5f596ee |
|---|---|---|
| Balanced award, normal | 2686, 8 of 9 | 2546, 7 of 9 (PASS) |
| Income ×, year 2 to year 6 | ×3.40 | ×3.22 (PASS) |
| Cash cover before the award | median 11 days | median 28 days (PASS) |
| Cash cover after the award | median 59 days | median 89 days (PASS) |
| Windfall runs taken over (without / with) | 1 / 0 of 3 | 0 / 0 of 3 |
| Largest daily distrust rise | 0.67 | 0.55 |
| Targets | 18 met, 4 missed | 18 met, 4 missed (the same four) |

Every run is identical through stage three. Runs part only after day ~1,700, where lateness on
stage four used to add distrust from day 2,100. One balanced run won that lost before (capital,
seed 42, day 3,211), and two lost that won before: workers on seed 20261029, and workers on seed
42, which had won only on day 3,239, nearly a year late. That is quick-run churn around marginal
runs; nine balanced runs cannot show a deadline effect this size.

## 1.9 faster immigration

Quick run `immigration-11` (2026-11-14, Linux, 51 runs, 0 audit errors). Free immigration 9 → 11 a
month in every town (+22%), the user's choice for stage three; nothing else in the simulation
changed since `stage4-5f596ee` (the event payoff engine only acts on data that uses its new keys).

| Row | stage4-5f596ee | immigration-11 |
|---|---|---|
| Population, year 2 / year 4 | 331 / 865 | 376 / 1038 (PASS) |
| Balanced bot, stage three done (median, latest) | day 1,238, 1,515 | day 1,134, 1,474 |
| Balanced bot, stage four done (median) | day 1,787 | day 1,679 |
| Balanced award, normal | 2546, 7 of 9 | 2254, 8 of 9 (PASS) |
| Floor (earliest rush award) | day 2,559 | day 2,376 (PASS, bar 1,440) |
| Income ×, year 2 to year 6 | ×3.22 | ×3.69 (PASS) |
| Labour lever | +38% | +34% (PASS) |
| Targets | 18 met, 4 missed | 18 met, 4 missed (the same four) |

Stage three comes about a hundred days sooner for the balanced bot, and stage four with it. The
money rows hold, and the wage lever keeps its strength. Openings still miss, but science's best bot
is now balanced rather than research-first.

## Before and after

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

### Reading the misses

All three appeared with the slower builds of 1.7.1. 1.7.0 passed them and missed only the best-bot row, which now passes.

- **Easy, day 156.** Time goals, not sizes, decide it: non-mining income and the weekly streak take as long as ever. Scaling the streak and processing goals by difficulty and adding starting cash moved it only from 157 to 156.
- **Research-first, day 181.** A day over the band; capital 181, workers 177, science 184.5.
- **Export mix, 65%.** One standard run of 60 (seed 20261029, workers) sold mostly crystal. Median 30%.
- **Takeovers are not a §5.2 row but matter.** 18 of 180 balanced runs are taken over. The bot never hands over, so this is an upper bound, not a player forecast.
  - 16 earned the award first and fail between days 450 and 713: 11 for overdue bills with under ¥370 left, 3 for food shortages (two of them with ¥5,900 and ¥15,700 in the bank), and 2 with ¥7,100 and ¥11,500 in the bank and no cause left on the record. In the one traced (standard, capital, seed 20261029), exports had stopped by day 658 and food sales were the only real income.
  - 2 never earn it (easy, workers, seeds 2048 and 1024873270). The bot never founds a second town, because it keeps waiting for road money above its reserve, and the missed contract ends the run on day 397. The game refused nothing and the same seed settles on day 77 on standard, so that is the bot's blind spot.

### What moved the numbers in Phase 8

| Change | Effect |
|---|---|
| Base immigration 6 → 7 a month | award median 184 → about 162 |
| Weekly streak | research-first 201 → 182; less luck in the award day |
| Food reaches chain ends (3 fixes) | on the quick run, money ×2.42 → ×3.24, export worst 53% → 44% |
| Company tolerates tiny risk | no takeover for one small town |
| Land kept for the town, starts need 12 plots | no more starts like seed 1000003, with no ground for a laboratory |
| Deposits ×1.25, deep mining first, diversifying | income ×2.59 → ×3.37; export worst 63% → 51% |
| Greenhouses, no barren partner | research-first's stuck seeds gone |

### What moved the numbers in 1.7.1

The changes: build times about doubled, with the buildings the goals run through (lab, port, processor, foodworks, clinic) at 8-10 days; base immigration 7 → 7.5 a month (in by pace2); science opening ¥4,800 → ¥5,300; easy starts with 1.4× cash, not 1.25×, and streak and processing goals scale with difficulty (in by pace6); paid research ¥40 → ¥50 a point (pace7); the bots keep a margin over the non-mining goal and build processors at any mining town. A market trial went in at pace5 and pace7 and came out again, because it made the export worst case worse.

| Run | Mode | Standard | Easy | Hard | Research-first | Worst export share |
|---|---|---|---|---|---|---|
| 1.7.0 | full | 167 | 143 | 194 | 172 | 51% |
| pace1 | quick | 174 | - | - | 194 | 62% |
| pace2 | quick | 179 | - | - | 186 | 44% |
| pace3 | quick | 184 | - | - | 187 | 56% |
| pace4 | full | 174 | 157 | 205 | 182 | 64% |
| pace5 | full | 171 | 157 | 207 | 182 | 79% |
| pace6 | full | 173 | 157 | 211 | 184 | 65% |
| pace7 | full | 173 | 155 | 211 | 182 | 75% |
| v1.7.1 | full | 173 | 156 | 211 | 181 | 65% |

Quick runs play standard only, 15 runs, so they do not compare directly with full ones. Each run changed several things, so no single number here belongs to a single change.
