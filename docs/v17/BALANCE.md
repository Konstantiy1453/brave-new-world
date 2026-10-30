# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **phase 3** · 2026-10-31T06-03-16 · 159 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 111 | PASS |
| Balanced award, normal | 120-180 | median 172 (60/60 awarded) | PASS |
| Balanced award, easy | 90-150 | median 137 (60/60 awarded) | PASS |
| Balanced award, hard | 160-230 | median 201 (51/60 awarded) | PASS |
| Openings | medians within 15% | capital 166, workers 147, science 177 | MISS |
| Failure, passive | review ~60, failure ~150 | review 57, failure 147 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 60/60 | PASS |
| Population | >= 300 by 360; >= 600 by 720 | 472 / -1 | MISS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 4 techs; 13%; 11% | MISS |
| Research-first | >= 6 techs, award in standard band | 5 techs; day 163 | MISS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 101%; x-0.00 | MISS |
| Export mix | no good > 60% after day 180 | median 34%, worst 40% | PASS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720 | 1 per 37 days; 13 distinct | MISS |
| Audits | 0 errors in every run | 0 errors in 950 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 180-day immigration by >= 20% | 80 to 99 arrivals (+24%) | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 20 | 100% | 130 | 100% | 534 | 1842 | 192 / 465 / -1 | 3 |
| balanced | easy | science | 20 | 100% | 129 | 100% | 541 | 1828 | 194 / 471 / -1 | 4 |
| balanced | easy | workers | 20 | 100% | 143 | 100% | 515 | 1714 | 216 / 494 / -1 | 3 |
| balanced | hard | capital | 20 | 90% | 199 | 100% | 482 | 1672 | 195 / 474 / -1 | 5 |
| balanced | hard | science | 20 | 65% | 227 | 100% | 463 | 1651 | 174 / 467 / -1 | 6 |
| balanced | hard | workers | 20 | 100% | 193 | 100% | 472 | 1846 | 216 / 487 / -1 | 5 |
| balanced | normal | capital | 20 | 100% | 166 | 100% | 523 | 1787 | 195 / 468 / -1 | 4 |
| balanced | normal | science | 20 | 100% | 177 | 100% | 530 | 1547 | 183 / 432 / -1 | 6 |
| balanced | normal | workers | 20 | 100% | 147 | 100% | 511 | 2060 | 211 / 496 / -1 | 3 |
| passive | easy | capital | 20 | 0% | -1 | 100% | 171 | 3799 | -1 / -1 / -1 | -1 |
| passive | easy | science | 20 | 0% | -1 | 100% | 171 | 2049 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 20 | 0% | -1 | 100% | 163 | 1634 | -1 / -1 / -1 | -1 |
| passive | hard | capital | 20 | 0% | -1 | 100% | 121 | 2625 | -1 / -1 / -1 | -1 |
| passive | hard | science | 20 | 0% | -1 | 100% | 121 | 1435 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 20 | 0% | -1 | 100% | 113 | 1531 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 20 | 0% | -1 | 100% | 147 | 2879 | -1 / -1 / -1 | -1 |
| passive | normal | science | 20 | 0% | -1 | 100% | 147 | 1479 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 20 | 0% | -1 | 100% | 139 | 1311 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 17 | 0% | -1 | 100% | 198 | 0 | 84 / -1 / -1 | -1 |
| random_legal | hard | science | 16 | 0% | -1 | 100% | 139 | 0 | 49 / -1 / -1 | -1 |
| random_legal | normal | workers | 17 | 0% | -1 | 100% | 139 | 0 | 102 / -1 / -1 | -1 |
| research_first | easy | capital | 20 | 100% | 152 | 0% | -1 | 528 | 148 / -1 / -1 | 3 |
| research_first | easy | science | 20 | 100% | 165 | 0% | -1 | 282 | 214 / -1 / -1 | 5 |
| research_first | easy | workers | 20 | 100% | 163 | 0% | -1 | 482 | -1 / -1 / -1 | 4 |
| research_first | hard | capital | 20 | 100% | 209 | 0% | -1 | 337 | 192 / -1 / -1 | 5 |
| research_first | hard | science | 20 | 85% | 198 | 15% | 286 | 391 | 188 / -1 / -1 | 6 |
| research_first | hard | workers | 20 | 100% | 183 | 0% | -1 | 396 | 216 / -1 / -1 | 5 |
| research_first | normal | capital | 20 | 100% | 164 | 0% | -1 | 603 | 213 / -1 / -1 | 5 |
| research_first | normal | science | 20 | 100% | 165 | 0% | -1 | 340 | 189 / -1 / -1 | 5 |
| research_first | normal | workers | 20 | 100% | 163 | 0% | -1 | 442 | 216 / -1 / -1 | 4 |
| rush | easy | capital | 20 | 60% | 192 | 40% | 396 | 68 | 203 / 173 / -1 | 4 |
| rush | easy | science | 20 | 50% | 208 | 50% | 397 | 78 | 155 / 190 / -1 | 5 |
| rush | easy | workers | 20 | 100% | 171 | 0% | -1 | 187 | 281 / -1 / -1 | 3 |
| rush | hard | capital | 20 | 45% | 175 | 55% | 267 | 106 | 147 / -1 / -1 | 4 |
| rush | hard | science | 20 | 50% | 188 | 50% | 266 | 95 | 153 / -1 / -1 | 5 |
| rush | hard | workers | 20 | 100% | 194 | 0% | -1 | 226 | 260 / -1 / -1 | 4 |
| rush | normal | capital | 20 | 15% | 204 | 85% | 322 | 74 | 150 / 291 / -1 | 4 |
| rush | normal | science | 20 | 25% | 194 | 75% | 322 | 73 | 150 / 310 / -1 | 5 |
| rush | normal | workers | 20 | 100% | 184 | 0% | -1 | 191 | 258 / -1 / -1 | 4 |
| sloppy | easy | capital | 20 | 0% | -1 | 100% | 267 | 1510 | 60 / -1 / -1 | -1 |
| sloppy | easy | science | 20 | 0% | -1 | 100% | 267 | 18 | 60 / -1 / -1 | -1 |
| sloppy | easy | workers | 20 | 0% | -1 | 100% | 162 | 24 | -1 / -1 / -1 | -1 |
| sloppy | hard | capital | 20 | 0% | -1 | 100% | 173 | 306 | -1 / -1 / -1 | -1 |
| sloppy | hard | science | 20 | 0% | -1 | 100% | 173 | 224 | -1 / -1 / -1 | -1 |
| sloppy | hard | workers | 20 | 0% | -1 | 100% | 112 | 201 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 20 | 0% | -1 | 100% | 214 | 18 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 20 | 0% | -1 | 100% | 214 | 18 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 20 | 0% | -1 | 100% | 138 | 412 | -1 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
- 2026-10-31T06-03-16 · phase 3 (full): 10 targets met, 6 missed.
- 2026-10-31T03-00-14 · phase 2 (quick): 3 targets met, 10 missed.
- 2026-10-31T02-23-14 · phase 1 (full): 4 targets met, 11 missed.
- 2026-10-31T02-00-23 · 1.6 baseline (full): 4 targets met, 11 missed.
