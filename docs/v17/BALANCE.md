# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **phase5** · 2026-10-31T07-43-55 · 386 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 109 | PASS |
| Balanced award, normal | 120-180 | median 175 (51/60 awarded) | PASS |
| Balanced award, easy | 90-150 | median 153 (53/60 awarded) | MISS |
| Balanced award, hard | 160-230 | median 210 (49/60 awarded) | PASS |
| Openings | medians within 15% | capital 174, workers 162, science 186 | PASS |
| Failure, passive | review ~60, failure ~150 | review 59, failure 149 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 60/60 | PASS |
| Population | >= 300 by 360; >= 600 by 720 | 374 / 839 | PASS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 5 techs; 13%; 17% | PASS |
| Research-first | >= 6 techs, award in standard band | 8 techs; day 195 | MISS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 83%; x3.46 | PASS |
| Export mix | no good > 60% after day 180 | median 34%, worst 82% | MISS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720 | 1 per 51 days; 13 distinct | MISS |
| Audits | 0 errors in every run | 0 errors in 950 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 180-day immigration by >= 20% | 56 to 71 arrivals (+27%) | PASS |
| Geography | sites 14-20 / 20-30 / 28-40; 3+ start pairs; 3+ start archetypes; land 25-45%; continents 2-6 | sites 14-20 / 20-30 / 28-40; pairs min 3; 3 archetypes; land 28-42%; continents 2,3,4,5,6 | PASS |
| Road trade-off | cheaper road is the slower one for 30-70% of pairs | 57% of 2740 pairs | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 20 | 90% | 151 | 45% | 397 | 510 | 186 / 382 / 852 | 4 |
| balanced | easy | science | 20 | 90% | 157 | 30% | 410 | 1223 | 183 / 364 / 921 | 7 |
| balanced | easy | workers | 20 | 85% | 153 | 35% | 318 | 411 | 212 / 407 / 808 | 4 |
| balanced | hard | capital | 20 | 85% | 207 | 30% | 292 | 691 | 185 / 372 / 913 | 7 |
| balanced | hard | science | 20 | 80% | 220 | 40% | 342 | 1433 | 172 / 377 / 967 | 9 |
| balanced | hard | workers | 20 | 80% | 189 | 35% | 310 | 463 | 207 / 398 / 935 | 6 |
| balanced | normal | capital | 20 | 80% | 174 | 40% | 310 | 314 | 195 / 372 / 784 | 5 |
| balanced | normal | science | 20 | 90% | 186 | 45% | 384 | 1428 | 169 / 370 / 890 | 8 |
| balanced | normal | workers | 20 | 85% | 162 | 40% | 426 | 854 | 202 / 374 / 845 | 4 |
| passive | easy | capital | 20 | 0% | -1 | 100% | 173 | 3931 | -1 / -1 / -1 | -1 |
| passive | easy | science | 20 | 0% | -1 | 100% | 173 | 1329 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 20 | 0% | -1 | 100% | 183 | 200 | 47 / -1 / -1 | -1 |
| passive | hard | capital | 20 | 0% | -1 | 100% | 123 | 2674 | -1 / -1 / -1 | -1 |
| passive | hard | science | 20 | 0% | -1 | 100% | 123 | 869 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 20 | 0% | -1 | 100% | 133 | 332 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 20 | 0% | -1 | 100% | 149 | 2974 | -1 / -1 / -1 | -1 |
| passive | normal | science | 20 | 0% | -1 | 100% | 149 | 829 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 20 | 0% | -1 | 100% | 159 | 0 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 17 | 0% | -1 | 100% | 229 | 0 | 60 / -1 / -1 | -1 |
| random_legal | hard | science | 16 | 0% | -1 | 100% | 124 | 0 | 55 / -1 / -1 | -1 |
| random_legal | normal | workers | 17 | 0% | -1 | 100% | 145 | 0 | 61 / -1 / -1 | -1 |
| research_first | easy | capital | 20 | 90% | 194 | 10% | 332 | 223 | 187 / 195 / -1 | 8 |
| research_first | easy | science | 20 | 80% | 194 | 20% | 397 | 253 | 169 / 269 / -1 | 10 |
| research_first | easy | workers | 20 | 90% | 170 | 10% | 319 | 472 | 186 / 202 / -1 | 7 |
| research_first | hard | capital | 20 | 85% | 208 | 15% | 268 | 264 | 189 / -1 / -1 | 8 |
| research_first | hard | science | 20 | 85% | 223 | 15% | 268 | 475 | 162 / -1 / -1 | 11 |
| research_first | hard | workers | 20 | 90% | 221 | 10% | 220 | 324 | 186 / -1 / -1 | 8 |
| research_first | normal | capital | 20 | 85% | 192 | 15% | 324 | 239 | 181 / -1 / -1 | 8 |
| research_first | normal | science | 20 | 90% | 204 | 10% | 325 | 273 | 166 / -1 / -1 | 10 |
| research_first | normal | workers | 20 | 85% | 188 | 15% | 324 | 442 | 189 / -1 / -1 | 8 |
| rush | easy | capital | 20 | 75% | 148 | 25% | 394 | 141 | 169 / 215 / -1 | 2 |
| rush | easy | science | 20 | 25% | 211 | 75% | 397 | 107 | 152 / 285 / -1 | 2 |
| rush | easy | workers | 20 | 85% | 136 | 15% | 393 | 139 | 222 / 198 / -1 | 2 |
| rush | hard | capital | 20 | 60% | 173 | 40% | 268 | 125 | 212 / -1 / -1 | 2 |
| rush | hard | science | 20 | 45% | 200 | 55% | 268 | 170 | 170 / -1 / -1 | 2 |
| rush | hard | workers | 20 | 75% | 159 | 25% | 268 | 86 | 183 / -1 / -1 | 2 |
| rush | normal | capital | 20 | 60% | 141 | 40% | 324 | 72 | 150 / -1 / -1 | 2 |
| rush | normal | science | 20 | 35% | 167 | 65% | 323 | 163 | 144 / 312 / -1 | 2 |
| rush | normal | workers | 20 | 70% | 159 | 30% | 323 | 114 | 193 / -1 / -1 | 2 |
| sloppy | easy | capital | 20 | 0% | -1 | 100% | 267 | 2303 | 60 / -1 / -1 | -1 |
| sloppy | easy | science | 20 | 0% | -1 | 100% | 267 | 538 | 60 / -1 / -1 | -1 |
| sloppy | easy | workers | 20 | 0% | -1 | 100% | 267 | 502 | 104 / -1 / -1 | -1 |
| sloppy | hard | capital | 20 | 0% | -1 | 100% | 173 | 230 | -1 / -1 / -1 | -1 |
| sloppy | hard | science | 20 | 0% | -1 | 100% | 173 | 152 | -1 / -1 / -1 | -1 |
| sloppy | hard | workers | 20 | 0% | -1 | 100% | 173 | 195 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 20 | 0% | -1 | 100% | 214 | 753 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 20 | 0% | -1 | 100% | 214 | 257 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 20 | 0% | -1 | 100% | 214 | 252 | 105 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-10-31T07-43-55 · phase5 (full): 14 targets met, 4 missed.
- 2026-10-31T06-27-17 · phase4 (full): 13 targets met, 3 missed.
- 2026-10-31T06-03-16 · phase 3 (full): 10 targets met, 6 missed.
- 2026-10-31T03-00-14 · phase 2 (quick): 3 targets met, 10 missed.
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.
