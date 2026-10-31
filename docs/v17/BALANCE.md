# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **1.8 fourth full** · 2026-11-01T01-32-25 · 2726 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 1440 | earliest day 2011 | PASS |
| Balanced award, normal | 2160-2880 | median 2523 (26/30 awarded) | PASS |
| Balanced award, easy | 1800-2520 | median 2296 (30/30 awarded) | PASS |
| Balanced award, hard | 2520-3240 | median 2669 (22/30 awarded) | PASS |
| Openings | medians within 15%; best bot differs by opening | capital 2563, workers 2634, science 2409; best { "capital": "balanced", "workers": "research_first", "science": "research_first" }; without rush { "capital": "balanced", "workers": "research_first", "science": "research_first" } | PASS |
| Failure, passive | review 150-400, failure 400-900 | review 168, failure 438 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 30/30 | PASS |
| Population | >= 300 by year 2; >= 800 by year 4 | 370 / 957 | PASS |
| Research, balanced | >= 40 techs; every category; research teams 10-20% | 41 techs; 4 categories; 12% | PASS |
| Research-first | more techs than balanced, award in standard band | 81 techs; day 2333 | PASS |
| Money | reinvest >= 60%; income x2.5 from year 2 to year 6 | 99%; x3.72 | PASS |
| Export mix | no good > 60% after year 2 | median 28%, worst 44% | PASS |
| Events | <= 1 pause per 40 days; >= 25 distinct; 60 short, 10 chains; >= 25% off each run | 1 per 214 days; 52 distinct; 0 repeats; 71 short, 12 chains; 30% off; seeds share 45% | PASS |
| Distrust | largest daily rise <= 0.8 | worst 0.68 | PASS |
| Pollution | output penalty < 2% through year 3 | year 3 worst 0.6%; year 8 median 2.7% | PASS |
| Roads | first road takes 90-300 days | median 146 days | PASS |
| Pollution, no control | output penalty >= 15% by year 8 | 21.1% | PASS |
| Audits | 0 errors in every run | 0 errors in 480 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 360-day immigration by >= 20% | 152 to 172 arrivals (+13%) | MISS |
| Geography | sites 14-20 / 20-30 / 28-40; 3+ start pairs; 3+ start archetypes; land 25-45%; continents 2-6 | sites 15-20 / 20-30 / 28-40; pairs min 3; 4 archetypes; land 25-45%; continents 2,3,4,5,6 | PASS |
| Road trade-off | cheaper road is the slower one for 30-70% of pairs | 90% of 2568 pairs | MISS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop y2 / y4 / y8 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 10 | 100% | 2271 | 0% | -1 | 316 | 415 / 919 / 2138 | 40 |
| balanced | easy | science | 10 | 100% | 2265 | 0% | -1 | 361 | 305 / 926 / 1671 | 40 |
| balanced | easy | workers | 10 | 100% | 2389 | 0% | -1 | 396 | 421 / 899 / 2156 | 40 |
| balanced | hard | capital | 10 | 80% | 2678 | 20% | 2755 | 231 | 351 / 887 / 2206 | 40 |
| balanced | hard | science | 10 | 70% | 2449 | 30% | 3163 | 377 | 318 / 794 / 1961 | 50 |
| balanced | hard | workers | 10 | 70% | 2799 | 30% | 2383 | 284 | 378 / 872 / 2282 | 40 |
| balanced | normal | capital | 10 | 70% | 2563 | 30% | 1860 | 290 | 388 / 881 / 2194 | 40 |
| balanced | normal | science | 10 | 90% | 2409 | 10% | 3199 | 422 | 340 / 898 / 2168 | 46 |
| balanced | normal | workers | 10 | 100% | 2634 | 0% | -1 | 412 | 418 / 1034 / 2344 | 41 |
| passive | easy | capital | 10 | 0% | -1 | 100% | 536 | 25821 | -1 / -1 / -1 | -1 |
| passive | easy | science | 10 | 0% | -1 | 100% | 522 | 9025 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 10 | 0% | -1 | 100% | 542 | 5454 | -1 / -1 / -1 | -1 |
| passive | hard | capital | 10 | 0% | -1 | 100% | 353 | 13852 | -1 / -1 / -1 | -1 |
| passive | hard | science | 10 | 0% | -1 | 100% | 342 | 3592 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 10 | 0% | -1 | 100% | 362 | 523 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 10 | 0% | -1 | 100% | 438 | 15851 | -1 / -1 / -1 | -1 |
| passive | normal | science | 10 | 0% | -1 | 100% | 426 | 3684 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 10 | 0% | -1 | 100% | 446 | 656 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 10 | 0% | -1 | 90% | 471 | 8034 | 91 / -1 / -1 | -1 |
| random_legal | hard | science | 10 | 0% | -1 | 100% | 311 | 0 | -1 / -1 / -1 | -1 |
| random_legal | normal | workers | 10 | 0% | -1 | 100% | 393 | 0 | -1 / -1 / -1 | -1 |
| research_first | easy | capital | 10 | 90% | 2059 | 10% | 2997 | 345 | 398 / 786 / 795 | 70 |
| research_first | easy | science | 10 | 90% | 1887 | 10% | 2972 | 166 | 405 / 932 / 745 | 72 |
| research_first | easy | workers | 10 | 100% | 2128 | 0% | -1 | 344 | 431 / 767 / -1 | 72 |
| research_first | hard | capital | 10 | 70% | 2463 | 30% | 1722 | 254 | 343 / 608 / 1761 | 77 |
| research_first | hard | science | 10 | 90% | 2284 | 10% | 3199 | 281 | 373 / 920 / 1698 | 84 |
| research_first | hard | workers | 10 | 60% | 2937 | 40% | 1722 | 127 | 342 / 776 / 2026 | 100 |
| research_first | normal | capital | 10 | 90% | 2623 | 10% | 1904 | 287 | 366 / 755 / 1782 | 87 |
| research_first | normal | science | 10 | 90% | 2179 | 10% | 1304 | 190 | 391 / 940 / -1 | 82 |
| research_first | normal | workers | 10 | 90% | 2163 | 10% | 1904 | 339 | 371 / 843 / -1 | 76 |
| rush | easy | capital | 10 | 90% | 2546 | 10% | 2991 | 178 | 383 / 876 / 1444 | 40 |
| rush | easy | science | 10 | 100% | 2167 | 0% | -1 | 270 | 398 / 926 / -1 | 40 |
| rush | easy | workers | 10 | 90% | 2591 | 10% | 3365 | 203 | 397 / 883 / 1486 | 40 |
| rush | hard | capital | 10 | 70% | 2711 | 30% | 2592 | 226 | 318 / 824 / 2101 | 41 |
| rush | hard | science | 10 | 30% | 2819 | 70% | 3191 | 243 | 313 / 782 / 2052 | 52 |
| rush | hard | workers | 10 | 30% | 2435 | 70% | 2582 | 136 | 339 / 826 / 2182 | 40 |
| rush | normal | capital | 10 | 70% | 2819 | 30% | 2278 | 135 | 362 / 894 / 2071 | 41 |
| rush | normal | science | 10 | 70% | 2599 | 30% | 2718 | 245 | 323 / 860 / 1859 | 47 |
| rush | normal | workers | 10 | 80% | 2765 | 20% | 2898 | 309 | 396 / 864 / 1870 | 41 |
| sloppy | easy | capital | 10 | 0% | -1 | 100% | 947 | 16388 | 60 / -1 / -1 | -1 |
| sloppy | easy | science | 10 | 0% | -1 | 100% | 947 | 2258 | 60 / -1 / -1 | -1 |
| sloppy | easy | workers | 10 | 0% | -1 | 100% | 820 | 1000 | 105 / -1 / -1 | -1 |
| sloppy | hard | capital | 10 | 0% | -1 | 100% | 642 | 354 | -1 / -1 / -1 | -1 |
| sloppy | hard | science | 10 | 0% | -1 | 100% | 642 | 239 | -1 / -1 / -1 | -1 |
| sloppy | hard | workers | 10 | 0% | -1 | 100% | 566 | 312 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 10 | 0% | -1 | 100% | 764 | 3588 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 10 | 0% | -1 | 100% | 764 | 218 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 10 | 0% | -1 | 100% | 670 | 358 | 104 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
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
