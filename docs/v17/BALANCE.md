# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **phase 2** · 2026-10-31T03-00-14 · 24 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 19 | MISS |
| Balanced award, normal | 120-180 | median 19 (15/15 awarded) | MISS |
| Balanced award, easy | 90-150 | median -1 (0/0 awarded) | NOT_MEASURED |
| Balanced award, hard | 160-230 | median -1 (0/0 awarded) | NOT_MEASURED |
| Openings | medians within 15% | capital 19, workers 35, science 37 | MISS |
| Failure, passive | review ~60, failure ~150 | review 87, failure 137 | MISS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 0/0 | MISS |
| Population | >= 300 by 360; >= 600 by 720 | 76 / 78 | MISS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 0 techs; 8%; 11% | MISS |
| Research-first | >= 6 techs, award in standard band | 0 techs; day 32 | MISS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 0%; x1.13 | MISS |
| Export mix | no good > 60% after day 180 | median 55%, worst 57% | PASS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720 | 1 per 55 days; 11 distinct | MISS |
| Audits | 0 errors in every run | 0 errors in 80 runs | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | normal | capital | 5 | 100% | 19 | 0% | -1 | 2205 | 72 / 76 / 78 | 0 |
| balanced | normal | science | 5 | 100% | 37 | 20% | 110 | 1232 | 74 / 78 / 80 | 0 |
| balanced | normal | workers | 5 | 100% | 35 | 0% | -1 | 1085 | 72 / 76 / 78 | 0 |
| passive | normal | capital | 5 | 0% | -1 | 100% | 137 | 3943 | -1 / -1 / -1 | -1 |
| passive | normal | science | 5 | 0% | -1 | 100% | 137 | 2543 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 5 | 0% | -1 | 100% | 137 | 1735 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 2 | 0% | -1 | 100% | 131 | 0 | -1 / -1 / -1 | -1 |
| random_legal | hard | science | 1 | 0% | -1 | 100% | 173 | 0 | -1 / -1 / -1 | -1 |
| random_legal | normal | workers | 2 | 0% | -1 | 100% | 112 | 0 | -1 / -1 / -1 | -1 |
| research_first | normal | capital | 5 | 100% | 30 | 0% | -1 | 2908 | 72 / 78 / 80 | 0 |
| research_first | normal | science | 5 | 60% | 109 | 40% | 108 | 33 | 72 / 80 / 82 | 1 |
| research_first | normal | workers | 5 | 100% | 33 | 0% | -1 | 1619 | 74 / 78 / 80 | 0 |
| rush | normal | capital | 5 | 100% | 19 | 0% | -1 | 2317 | -1 / -1 / -1 | 0 |
| rush | normal | science | 5 | 100% | 19 | 0% | -1 | 884 | -1 / -1 / -1 | 0 |
| rush | normal | workers | 5 | 100% | 19 | 0% | -1 | 751 | -1 / -1 / -1 | 0 |
| sloppy | normal | capital | 5 | 0% | -1 | 100% | 310 | 24 | 63 / -1 / -1 | -1 |
| sloppy | normal | science | 5 | 0% | -1 | 100% | 300 | 24 | 74 / -1 / -1 | -1 |
| sloppy | normal | workers | 5 | 0% | -1 | 100% | 111 | 331 | -1 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-10-31T03-00-14 · phase 2 (quick): 3 targets met, 10 missed.
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.
