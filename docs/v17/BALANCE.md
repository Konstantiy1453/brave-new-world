# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **phase4** · 2026-10-31T06-27-17 · 102 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 105 | PASS |
| Balanced award, normal | 120-180 | median 162 (60/60 awarded) | PASS |
| Balanced award, easy | 90-150 | median 142 (60/60 awarded) | PASS |
| Balanced award, hard | 160-230 | median 198 (52/60 awarded) | PASS |
| Openings | medians within 15% | capital 163, workers 158, science 166 | PASS |
| Failure, passive | review ~60, failure ~150 | review 57, failure 147 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 60/60 | PASS |
| Population | >= 300 by 360; >= 600 by 720 | 378 / 506 | MISS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 5 techs; 14%; 23% | PASS |
| Research-first | >= 6 techs, award in standard band | 7 techs; day 178 | PASS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 71%; x0.98 | MISS |
| Export mix | no good > 60% after day 180 | median 37%, worst 46% | PASS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720 | 1 per 34 days; 13 distinct | MISS |
| Audits | 0 errors in every run | 0 errors in 950 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 180-day immigration by >= 20% | 80 to 98 arrivals (+23%) | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 20 | 100% | 160 | 100% | 498 | 970 | 212 / 384 / -1 | 5 |
| balanced | easy | science | 20 | 100% | 125 | 100% | 560 | 2292 | 197 / 388 / -1 | 5 |
| balanced | easy | workers | 20 | 100% | 157 | 95% | 506 | 945 | 226 / 379 / 512 | 5 |
| balanced | hard | capital | 20 | 100% | 196 | 100% | 447 | 1109 | 203 / 371 / -1 | 7 |
| balanced | hard | science | 20 | 60% | 231 | 90% | 426 | 2077 | 173 / 384 / 541 | 10 |
| balanced | hard | workers | 20 | 100% | 183 | 95% | 443 | 1654 | 215 / 392 / 516 | 6 |
| balanced | normal | capital | 20 | 100% | 163 | 95% | 474 | 729 | 211 / 383 / 510 | 5 |
| balanced | normal | science | 20 | 100% | 166 | 95% | 497 | 1967 | 189 / 376 / 502 | 7 |
| balanced | normal | workers | 20 | 100% | 158 | 100% | 465 | 969 | 214 / 363 / -1 | 5 |
| passive | easy | capital | 20 | 0% | -1 | 100% | 171 | 3799 | -1 / -1 / -1 | -1 |
| passive | easy | science | 20 | 0% | -1 | 100% | 171 | 1194 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 20 | 0% | -1 | 100% | 183 | 239 | 75 / -1 / -1 | -1 |
| passive | hard | capital | 20 | 0% | -1 | 100% | 121 | 2625 | -1 / -1 / -1 | -1 |
| passive | hard | science | 20 | 0% | -1 | 100% | 121 | 830 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 20 | 0% | -1 | 100% | 133 | 677 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 20 | 0% | -1 | 100% | 147 | 2879 | -1 / -1 / -1 | -1 |
| passive | normal | science | 20 | 0% | -1 | 100% | 147 | 744 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 20 | 0% | -1 | 100% | 159 | 175 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 17 | 0% | -1 | 100% | 241 | 0 | 87 / 110 / -1 | -1 |
| random_legal | hard | science | 16 | 0% | -1 | 100% | 120 | 0 | 59 / -1 / -1 | -1 |
| random_legal | normal | workers | 17 | 0% | -1 | 100% | 154 | 0 | 105 / -1 / -1 | -1 |
| research_first | easy | capital | 20 | 95% | 148 | 5% | 371 | 195 | 148 / 150 / -1 | 6 |
| research_first | easy | science | 20 | 100% | 178 | 0% | -1 | 673 | 193 / -1 / -1 | 8 |
| research_first | easy | workers | 20 | 100% | 158 | 0% | -1 | 319 | 235 / -1 / -1 | 6 |
| research_first | hard | capital | 20 | 100% | 204 | 0% | -1 | 339 | 200 / -1 / -1 | 8 |
| research_first | hard | science | 20 | 85% | 239 | 15% | 262 | 643 | 175 / -1 / -1 | 11 |
| research_first | hard | workers | 20 | 100% | 188 | 0% | -1 | 254 | 209 / -1 / -1 | 7 |
| research_first | normal | capital | 20 | 95% | 190 | 5% | 323 | 311 | 201 / -1 / -1 | 7 |
| research_first | normal | science | 20 | 95% | 187 | 5% | 312 | 905 | 175 / -1 / -1 | 10 |
| research_first | normal | workers | 20 | 100% | 164 | 0% | -1 | 290 | 232 / -1 / -1 | 6 |
| rush | easy | capital | 20 | 100% | 177 | 0% | -1 | 69 | 272 / -1 / -1 | 2 |
| rush | easy | science | 20 | 95% | 137 | 5% | 505 | 68 | 231 / 350 / -1 | 2 |
| rush | easy | workers | 20 | 100% | 164 | 0% | -1 | 142 | 302 / -1 / -1 | 2 |
| rush | hard | capital | 20 | 100% | 185 | 0% | -1 | 90 | 248 / -1 / -1 | 2 |
| rush | hard | science | 20 | 85% | 168 | 15% | 173 | 86 | 195 / -1 / -1 | 2 |
| rush | hard | workers | 20 | 95% | 178 | 5% | 358 | 106 | 272 / -1 / -1 | 2 |
| rush | normal | capital | 20 | 90% | 203 | 10% | 324 | 81 | 229 / -1 / -1 | 2 |
| rush | normal | science | 20 | 80% | 165 | 20% | 214 | 80 | 209 / -1 / -1 | 2 |
| rush | normal | workers | 20 | 100% | 173 | 0% | -1 | 106 | 274 / -1 / -1 | 2 |
| sloppy | easy | capital | 20 | 0% | -1 | 100% | 267 | 1510 | 60 / -1 / -1 | -1 |
| sloppy | easy | science | 20 | 0% | -1 | 100% | 267 | 18 | 60 / -1 / -1 | -1 |
| sloppy | easy | workers | 20 | 0% | -1 | 100% | 267 | 24 | 104 / -1 / -1 | -1 |
| sloppy | hard | capital | 20 | 0% | -1 | 100% | 173 | 306 | -1 / -1 / -1 | -1 |
| sloppy | hard | science | 20 | 0% | -1 | 100% | 173 | 229 | -1 / -1 / -1 | -1 |
| sloppy | hard | workers | 20 | 0% | -1 | 100% | 173 | 198 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 20 | 0% | -1 | 100% | 214 | 18 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 20 | 0% | -1 | 100% | 214 | 18 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 20 | 0% | -1 | 100% | 214 | 424 | 104 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-10-31T06-27-17 · phase4 (full): 13 targets met, 3 missed.
- 2026-10-31T06-03-16 · phase 3 (full): 10 targets met, 6 missed.
- 2026-10-31T03-00-14 · phase 2 (quick): 3 targets met, 10 missed.
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.
