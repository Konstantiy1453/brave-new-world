# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **phase7** · 2026-10-31T11-09-53 · 107 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 135 | PASS |
| Balanced award, normal | 120-180 | median 184 (15/15 awarded) | MISS |
| Balanced award, easy | 90-150 | median -1 (0/0 awarded) | NOT_MEASURED |
| Balanced award, hard | 160-230 | median -1 (0/0 awarded) | NOT_MEASURED |
| Openings | medians within 15% | capital 181, workers 173, science 189 | PASS |
| Failure, passive | review ~60, failure ~150 | review 59, failure 149 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 0/0 | MISS |
| Population | >= 300 by 360; >= 600 by 720 | 401 / 795 | PASS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 7 techs; 13%; 18% | PASS |
| Research-first | >= 6 techs, award in standard band | 8 techs; day 201 | MISS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 83%; x2.42 | MISS |
| Export mix | no good > 60% after day 180 | median 26%, worst 53% | PASS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720; no repeat inside cooldown; 25 short, 5 chains | 1 per 38 days; 29 distinct; 0 repeats; 28 short, 6 chains | PASS |
| Audits | 0 errors in every run | 0 errors in 80 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 180-day immigration by >= 20% | 68 to 81 arrivals (+19%) | MISS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | normal | capital | 5 | 100% | 181 | 20% | 295 | 728 | 201 / 410 / 818 | 5 |
| balanced | normal | science | 5 | 100% | 189 | 20% | 424 | 1728 | 188 / 368 / 779 | 8 |
| balanced | normal | workers | 5 | 100% | 173 | 0% | -1 | 824 | 208 / 404 / 868 | 6 |
| passive | normal | capital | 5 | 0% | -1 | 100% | 149 | 3447 | -1 / -1 / -1 | -1 |
| passive | normal | science | 5 | 0% | -1 | 100% | 149 | 1302 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 5 | 0% | -1 | 100% | 159 | 443 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 2 | 0% | -1 | 100% | 175 | 0 | 38 / -1 / -1 | -1 |
| random_legal | hard | science | 1 | 0% | -1 | 100% | 112 | 0 | -1 / -1 / -1 | -1 |
| random_legal | normal | workers | 2 | 0% | -1 | 100% | 157 | 0 | -1 / -1 / -1 | -1 |
| research_first | normal | capital | 5 | 80% | 221 | 20% | 324 | 194 | 184 / -1 / -1 | 8 |
| research_first | normal | science | 5 | 100% | 202 | 0% | -1 | 185 | 184 / -1 / -1 | 10 |
| research_first | normal | workers | 5 | 100% | 189 | 0% | -1 | 479 | 202 / -1 / -1 | 7 |
| rush | normal | capital | 5 | 20% | 211 | 80% | 324 | 65 | 207 / -1 / -1 | 2 |
| rush | normal | science | 5 | 60% | 179 | 40% | 214 | 87 | 132 / -1 / -1 | 2 |
| rush | normal | workers | 5 | 60% | 188 | 40% | 321 | 63 | 191 / -1 / -1 | 2 |
| sloppy | normal | capital | 5 | 0% | -1 | 100% | 214 | 1060 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 5 | 0% | -1 | 100% | 214 | 273 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 5 | 0% | -1 | 100% | 214 | 266 | 102 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-10-31T11-09-53 · phase7 (quick): 9 targets met, 5 missed.
- 2026-10-31T07-43-55 · phase5 (full): 14 targets met, 4 missed.
- 2026-10-31T06-27-17 · phase4 (full): 13 targets met, 3 missed.
- 2026-10-31T06-03-16 · phase 3 (full): 10 targets met, 6 missed.
- 2026-10-31T03-00-14 · phase 2 (quick): 3 targets met, 10 missed.
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.
