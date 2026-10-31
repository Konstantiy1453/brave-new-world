# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **release** · 2026-10-31T13-06-47 · 445 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 116 | PASS |
| Balanced award, normal | 120-180 | median 167 (60/60 awarded) | PASS |
| Balanced award, easy | 90-150 | median 143 (60/60 awarded) | PASS |
| Balanced award, hard | 160-230 | median 194 (59/60 awarded) | PASS |
| Openings | medians within 15%; best bot differs by opening | capital 166, workers 160, science 179; best { "capital": "rush", "workers": "rush", "science": "rush" }; without rush { "capital": "balanced", "workers": "balanced", "science": "research_first" } | MISS |
| Failure, passive | review ~60, failure ~150 | review 60, failure 150 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 60/60 | PASS |
| Population | >= 300 by 360; >= 600 by 720 | 431 / 980 | PASS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 5 techs; 13%; 17% | PASS |
| Research-first | >= 6 techs, award in standard band | 8 techs; day 172 | PASS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 79%; x3.37 | PASS |
| Export mix | no good > 60% after day 180 | median 29%, worst 51% | PASS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720; no repeat inside cooldown; 25 short, 5 chains | 1 per 38 days; 28 distinct; 0 repeats; 28 short, 6 chains | PASS |
| Audits | 0 errors in every run | 0 errors in 950 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 180-day immigration by >= 20% | 80 to 111 arrivals (+39%) | PASS |
| Geography | sites 14-20 / 20-30 / 28-40; 3+ start pairs; 3+ start archetypes; land 25-45%; continents 2-6 | sites 15-20 / 20-30 / 28-40; pairs min 3; 3 archetypes; land 28-42%; continents 2,3,4,5,6 | PASS |
| Road trade-off | cheaper road is the slower one for 30-70% of pairs | 58% of 2798 pairs | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 20 | 100% | 142 | 10% | 670 | 856 | 211 / 457 / 882 | 4 |
| balanced | easy | science | 20 | 100% | 139 | 10% | 572 | 1275 | 204 / 400 / 835 | 7 |
| balanced | easy | workers | 20 | 100% | 151 | 5% | 639 | 669 | 230 / 500 / 1030 | 4 |
| balanced | hard | capital | 20 | 100% | 199 | 10% | 532 | 629 | 203 / 404 / 1029 | 7 |
| balanced | hard | science | 20 | 100% | 206 | 0% | -1 | 1654 | 193 / 409 / 1032 | 8 |
| balanced | hard | workers | 20 | 95% | 175 | 15% | 432 | 650 | 224 / 424 / 919 | 5 |
| balanced | normal | capital | 20 | 100% | 166 | 10% | 667 | 694 | 214 / 421 / 878 | 4 |
| balanced | normal | science | 20 | 100% | 179 | 15% | 665 | 1591 | 204 / 438 / 1092 | 8 |
| balanced | normal | workers | 20 | 100% | 160 | 15% | 645 | 1023 | 216 / 433 / 979 | 4 |
| passive | easy | capital | 20 | 0% | -1 | 100% | 175 | 4343 | -1 / -1 / -1 | -1 |
| passive | easy | science | 20 | 0% | -1 | 100% | 163 | 2054 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 20 | 0% | -1 | 100% | 183 | 1091 | 43 / -1 / -1 | -1 |
| passive | hard | capital | 20 | 0% | -1 | 100% | 123 | 3147 | -1 / -1 / -1 | -1 |
| passive | hard | science | 20 | 0% | -1 | 100% | 113 | 1606 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 20 | 0% | -1 | 100% | 133 | 1116 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 20 | 0% | -1 | 100% | 150 | 3421 | -1 / -1 / -1 | -1 |
| passive | normal | science | 20 | 0% | -1 | 100% | 139 | 1560 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 20 | 0% | -1 | 100% | 159 | 810 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 17 | 0% | -1 | 100% | 265 | 0 | 77 / -1 / -1 | -1 |
| random_legal | hard | science | 16 | 0% | -1 | 100% | 113 | 0 | 56 / -1 / -1 | -1 |
| random_legal | normal | workers | 17 | 0% | -1 | 100% | 151 | 0 | 71 / -1 / -1 | -1 |
| research_first | easy | capital | 20 | 100% | 166 | 0% | -1 | 159 | 210 / -1 / -1 | 6 |
| research_first | easy | science | 20 | 100% | 157 | 0% | -1 | 260 | 172 / -1 / -1 | 9 |
| research_first | easy | workers | 20 | 100% | 170 | 0% | -1 | 566 | 200 / -1 / -1 | 6 |
| research_first | hard | capital | 20 | 95% | 185 | 5% | 264 | 209 | 206 / -1 / -1 | 8 |
| research_first | hard | science | 20 | 95% | 196 | 5% | 267 | 234 | 200 / -1 / -1 | 10 |
| research_first | hard | workers | 20 | 85% | 190 | 15% | 268 | 405 | 206 / -1 / -1 | 8 |
| research_first | normal | capital | 20 | 100% | 178 | 0% | -1 | 188 | 196 / -1 / -1 | 7 |
| research_first | normal | science | 20 | 100% | 170 | 0% | -1 | 209 | 174 / -1 / -1 | 8 |
| research_first | normal | workers | 20 | 100% | 172 | 0% | -1 | 230 | 204 / -1 / -1 | 7 |
| rush | easy | capital | 20 | 100% | 159 | 0% | -1 | 89 | 214 / -1 / -1 | 2 |
| rush | easy | science | 20 | 95% | 174 | 5% | 397 | 123 | 199 / 306 / -1 | 4 |
| rush | easy | workers | 20 | 100% | 142 | 0% | -1 | 109 | 212 / -1 / -1 | 2 |
| rush | hard | capital | 20 | 80% | 162 | 20% | 268 | 103 | 161 / -1 / -1 | 2 |
| rush | hard | science | 20 | 75% | 214 | 25% | 268 | 144 | 174 / -1 / -1 | 4 |
| rush | hard | workers | 20 | 95% | 160 | 5% | 358 | 126 | 231 / -1 / -1 | 2 |
| rush | normal | capital | 20 | 90% | 159 | 10% | 372 | 137 | 199 / 303 / -1 | 3 |
| rush | normal | science | 20 | 100% | 168 | 0% | -1 | 114 | 185 / -1 / -1 | 4 |
| rush | normal | workers | 20 | 85% | 144 | 15% | 324 | 108 | 159 / -1 / -1 | 2 |
| sloppy | easy | capital | 20 | 0% | -1 | 100% | 267 | 2207 | 60 / -1 / -1 | -1 |
| sloppy | easy | science | 20 | 0% | -1 | 100% | 267 | 447 | 60 / -1 / -1 | -1 |
| sloppy | easy | workers | 20 | 0% | -1 | 100% | 266 | 400 | 104 / -1 / -1 | -1 |
| sloppy | hard | capital | 20 | 0% | -1 | 100% | 173 | 184 | -1 / -1 / -1 | -1 |
| sloppy | hard | science | 20 | 0% | -1 | 100% | 150 | 199 | -1 / -1 / -1 | -1 |
| sloppy | hard | workers | 20 | 0% | -1 | 100% | 173 | 181 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 20 | 0% | -1 | 100% | 214 | 657 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 20 | 0% | -1 | 100% | 204 | 256 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 20 | 0% | -1 | 100% | 214 | 233 | 104 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
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

### Reading the misses

- **Best bot by opening** stays a miss at standard. Rush is the fastest with all three, because its job is the shortest path. Without it: balanced, balanced, research-first. At easy the best are balanced, rush, balanced; at hard rush, rush, research-first.
- **Takeovers are not a §5.2 row but matter.** 18 of 180 balanced runs fail: 17 after the award, between days 432 and 716, one on hard before the award. Reasons: unpaid bills as mines run out, or food shortages from the same collapse; five standard runs with ¥87,000 to ¥204,000 in the bank were taken over with no money problem at all, and the one traced (seed 73939133) had most of its people out of work. The bot never hands over, so this is an upper bound, not a player forecast.

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
