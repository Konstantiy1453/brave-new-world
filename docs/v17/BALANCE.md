# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **phase 1** · 2026-10-31T02-23-14 · 94 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 19 | MISS |
| Balanced award, normal | 120-180 | median 19 (60/60 awarded) | MISS |
| Balanced award, easy | 90-150 | median 19 (60/60 awarded) | MISS |
| Balanced award, hard | 160-230 | median 42 (56/60 awarded) | MISS |
| Openings | medians within 15% | capital 19, workers 25, science 19 | MISS |
| Failure, passive | review ~60, failure ~150 | review 87, failure 137 | MISS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 60/60 | PASS |
| Population | >= 300 by 360; >= 600 by 720 | 76 / 78 | MISS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 0 techs; 8%; 11% | MISS |
| Research-first | >= 6 techs, award in standard band | 0 techs; day 30 | MISS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 0%; x1.14 | MISS |
| Export mix | no good > 60% after day 180 | median 52%, worst 57% | PASS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720 | 1 per 55 days; 11 distinct | MISS |
| Audits | 0 errors in every run | 0 errors in 950 runs | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 20 | 100% | 19 | 0% | -1 | 3902 | 72 / 76 / 78 | 0 |
| balanced | easy | science | 20 | 100% | 19 | 0% | -1 | 2169 | 74 / 78 / 80 | 0 |
| balanced | easy | workers | 20 | 100% | 19 | 10% | 448 | 1927 | 74 / 78 / 80 | 0 |
| balanced | hard | capital | 20 | 100% | 19 | 0% | -1 | 1422 | 72 / 76 / 78 | 0 |
| balanced | hard | science | 20 | 80% | 67 | 75% | 92 | 973 | 68 / 72 / 74 | 0 |
| balanced | hard | workers | 20 | 100% | 43 | 0% | -1 | 1039 | 70 / 74 / 76 | 0 |
| balanced | normal | capital | 20 | 100% | 19 | 0% | -1 | 2352 | 72 / 76 / 78 | 0 |
| balanced | normal | science | 20 | 100% | 19 | 15% | 106 | 1209 | 74 / 78 / 80 | 0 |
| balanced | normal | workers | 20 | 100% | 25 | 0% | -1 | 1058 | 74 / 78 / 80 | 0 |
| passive | easy | capital | 20 | 0% | -1 | 100% | 166 | 4834 | -1 / -1 / -1 | -1 |
| passive | easy | science | 20 | 0% | -1 | 100% | 166 | 3084 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 20 | 0% | -1 | 100% | 166 | 1892 | -1 / -1 / -1 | -1 |
| passive | hard | capital | 20 | 0% | -1 | 100% | 118 | 3391 | -1 / -1 / -1 | -1 |
| passive | hard | science | 20 | 0% | -1 | 100% | 118 | 2201 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 20 | 0% | -1 | 100% | 118 | 1734 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 20 | 0% | -1 | 100% | 137 | 3943 | -1 / -1 / -1 | -1 |
| passive | normal | science | 20 | 0% | -1 | 100% | 137 | 2543 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 20 | 0% | -1 | 100% | 137 | 1735 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 17 | 0% | -1 | 100% | 123 | 0 | 60 / -1 / -1 | -1 |
| random_legal | hard | science | 16 | 0% | -1 | 100% | 88 | 0 | -1 / -1 / -1 | -1 |
| random_legal | normal | workers | 17 | 6% | 91 | 100% | 100 | 0 | -1 / -1 / -1 | 0 |
| research_first | easy | capital | 20 | 100% | 29 | 0% | -1 | 4423 | 72 / 78 / 80 | 0 |
| research_first | easy | science | 20 | 100% | 85 | 0% | -1 | 625 | 72 / 80 / 82 | 1 |
| research_first | easy | workers | 20 | 100% | 30 | 0% | -1 | 2616 | 74 / 78 / 80 | 0 |
| research_first | hard | capital | 20 | 100% | 29 | 0% | -1 | 1943 | 72 / 78 / 80 | 0 |
| research_first | hard | science | 20 | 40% | 85 | 60% | 88 | 24 | 74 / 80 / 82 | 1 |
| research_first | hard | workers | 20 | 100% | 30 | 0% | -1 | 776 | 74 / 78 / 80 | 0 |
| research_first | normal | capital | 20 | 100% | 29 | 0% | -1 | 2873 | 72 / 78 / 80 | 0 |
| research_first | normal | science | 20 | 85% | 99 | 15% | 111 | 34 | 72 / 80 / 82 | 1 |
| research_first | normal | workers | 20 | 100% | 30 | 0% | -1 | 1466 | 74 / 78 / 80 | 0 |
| rush | easy | capital | 20 | 100% | 19 | 0% | -1 | 3935 | -1 / -1 / -1 | 0 |
| rush | easy | science | 20 | 100% | 19 | 0% | -1 | 2202 | -1 / -1 / -1 | 0 |
| rush | easy | workers | 20 | 100% | 19 | 0% | -1 | 1965 | -1 / -1 / -1 | 0 |
| rush | hard | capital | 20 | 100% | 19 | 0% | -1 | 1455 | -1 / -1 / -1 | 0 |
| rush | hard | science | 20 | 100% | 19 | 0% | -1 | 282 | -1 / -1 / -1 | 0 |
| rush | hard | workers | 20 | 100% | 19 | 0% | -1 | 196 | -1 / -1 / -1 | 0 |
| rush | normal | capital | 20 | 100% | 19 | 0% | -1 | 2385 | -1 / -1 / -1 | 0 |
| rush | normal | science | 20 | 100% | 19 | 0% | -1 | 1002 | -1 / -1 / -1 | 0 |
| rush | normal | workers | 20 | 100% | 19 | 0% | -1 | 815 | -1 / -1 / -1 | 0 |
| sloppy | easy | capital | 20 | 0% | -1 | 100% | 360 | 1526 | 61 / 70 / -1 | -1 |
| sloppy | easy | science | 20 | 0% | -1 | 100% | 348 | 24 | 72 / 69 / -1 | -1 |
| sloppy | easy | workers | 20 | 0% | -1 | 100% | 130 | 30 | -1 / -1 / -1 | -1 |
| sloppy | hard | capital | 20 | 0% | -1 | 100% | 254 | 63 | 61 / -1 / -1 | -1 |
| sloppy | hard | science | 20 | 0% | -1 | 100% | 256 | 24 | 72 / -1 / -1 | -1 |
| sloppy | hard | workers | 20 | 0% | -1 | 100% | 98 | 218 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 20 | 0% | -1 | 100% | 296 | 24 | 61 / -1 / -1 | -1 |
| sloppy | normal | science | 20 | 0% | -1 | 100% | 298 | 24 | 72 / -1 / -1 | -1 |
| sloppy | normal | workers | 20 | 0% | -1 | 100% | 110 | 367 | -1 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.
