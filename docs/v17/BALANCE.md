# Colony Charter 1.7 — Balance

Targets are §5.2 of `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`.
The results block below is rewritten by `game/tests/balance/run_balance.gd`; raw per-run
records are in `evidence/v17/balance/<timestamp>.json`.

## Current results

<!-- results:begin -->
Run: **v1.7.1** · 2026-10-31T17-13-30 · 562 s wall clock. Source: balance harness.

| Area | Target | Measured | Status |
|---|---|---|---|
| Floor | rush bot day >= 90 | earliest day 107 | PASS |
| Balanced award, normal | 120-180 | median 173 (60/60 awarded) | PASS |
| Balanced award, easy | 90-150 | median 156 (58/60 awarded) | MISS |
| Balanced award, hard | 160-230 | median 211 (60/60 awarded) | PASS |
| Openings | medians within 15%; best bot differs by opening | capital 177, workers 160, science 176; best { "capital": "rush", "workers": "balanced", "science": "balanced" }; without rush { "capital": "balanced", "workers": "balanced", "science": "balanced" } | PASS |
| Failure, passive | review ~60, failure ~150 | review 60, failure 150 | PASS |
| Failure, sloppy | review on all difficulties; fails on hard | all reach review: true; hard failed 60/60 | PASS |
| Population | >= 300 by 360; >= 600 by 720 | 425 / 973 | PASS |
| Research, balanced | >= 3 techs; scientists 10-20%; spend 15-30% | 5 techs; 13%; 17% | PASS |
| Research-first | >= 6 techs, award in standard band | 8 techs; day 181 | MISS |
| Money | reinvest >= 60%; income x2.5 from 180 to 720 | 84%; x3.76 | PASS |
| Export mix | no good > 60% after day 180 | median 30%, worst 65% | MISS |
| Events | <= 1 pause per 20 days; >= 15 distinct by 720; no repeat inside cooldown; 25 short, 5 chains | 1 per 38 days; 29 distinct; 0 repeats; 28 short, 6 chains | PASS |
| Audits | 0 errors in every run | 0 errors in 950 runs | PASS |
| Labour lever | wage 1.0x to 1.3x changes 180-day immigration by >= 20% | 83 to 107 arrivals (+29%) | PASS |
| Geography | sites 14-20 / 20-30 / 28-40; 3+ start pairs; 3+ start archetypes; land 25-45%; continents 2-6 | sites 15-20 / 20-30 / 28-40; pairs min 3; 3 archetypes; land 25-45%; continents 2,3,4,5,6 | PASS |
| Road trade-off | cheaper road is the slower one for 30-70% of pairs | 54% of 2708 pairs | PASS |
| Determinism | same seed + action log => identical state | 3/3 replays identical | PASS |

| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| balanced | easy | capital | 20 | 100% | 157 | 10% | 643 | 295 | 218 / 447 / 1040 | 4 |
| balanced | easy | science | 20 | 100% | 152 | 10% | 562 | 642 | 199 / 406 / 933 | 7 |
| balanced | easy | workers | 20 | 90% | 161 | 15% | 397 | 246 | 225 / 466 / 980 | 4 |
| balanced | hard | capital | 20 | 100% | 211 | 15% | 588 | 815 | 195 / 395 / 1027 | 7 |
| balanced | hard | science | 20 | 100% | 221 | 0% | -1 | 1499 | 181 / 407 / 1061 | 9 |
| balanced | hard | workers | 20 | 100% | 200 | 20% | 613 | 573 | 202 / 427 / 1093 | 6 |
| balanced | normal | capital | 20 | 100% | 177 | 15% | 658 | 573 | 202 / 407 / 918 | 5 |
| balanced | normal | science | 20 | 100% | 176 | 0% | -1 | 1301 | 187 / 423 / 1018 | 8 |
| balanced | normal | workers | 20 | 100% | 160 | 5% | 687 | 409 | 213 / 426 / 857 | 4 |
| passive | easy | capital | 20 | 0% | -1 | 100% | 175 | 5273 | -1 / -1 / -1 | -1 |
| passive | easy | science | 20 | 0% | -1 | 100% | 163 | 3474 | -1 / -1 / -1 | -1 |
| passive | easy | workers | 20 | 0% | -1 | 100% | 183 | 1781 | 43 / -1 / -1 | -1 |
| passive | hard | capital | 20 | 0% | -1 | 100% | 123 | 3147 | -1 / -1 / -1 | -1 |
| passive | hard | science | 20 | 0% | -1 | 100% | 113 | 2031 | -1 / -1 / -1 | -1 |
| passive | hard | workers | 20 | 0% | -1 | 100% | 133 | 1116 | -1 / -1 / -1 | -1 |
| passive | normal | capital | 20 | 0% | -1 | 100% | 150 | 3421 | -1 / -1 / -1 | -1 |
| passive | normal | science | 20 | 0% | -1 | 100% | 139 | 2060 | -1 / -1 / -1 | -1 |
| passive | normal | workers | 20 | 0% | -1 | 100% | 159 | 810 | -1 / -1 / -1 | -1 |
| random_legal | easy | capital | 17 | 0% | -1 | 100% | 243 | 0 | 66 / 135 / -1 | -1 |
| random_legal | hard | science | 16 | 0% | -1 | 100% | 111 | 0 | 82 / -1 / -1 | -1 |
| random_legal | normal | workers | 17 | 0% | -1 | 100% | 150 | 0 | 65 / -1 / -1 | -1 |
| research_first | easy | capital | 20 | 100% | 174 | 0% | -1 | 116 | 228 / -1 / -1 | 7 |
| research_first | easy | science | 20 | 100% | 156 | 0% | -1 | 162 | 196 / -1 / -1 | 8 |
| research_first | easy | workers | 20 | 100% | 171 | 0% | -1 | 304 | 205 / -1 / -1 | 7 |
| research_first | hard | capital | 20 | 100% | 205 | 0% | -1 | 268 | 198 / -1 / -1 | 8 |
| research_first | hard | science | 20 | 95% | 200 | 5% | 268 | 169 | 187 / -1 / -1 | 9 |
| research_first | hard | workers | 20 | 95% | 200 | 5% | 268 | 385 | 198 / -1 / -1 | 8 |
| research_first | normal | capital | 20 | 100% | 181 | 0% | -1 | 218 | 198 / -1 / -1 | 7 |
| research_first | normal | science | 20 | 100% | 185 | 0% | -1 | 193 | 178 / -1 / -1 | 9 |
| research_first | normal | workers | 20 | 100% | 177 | 0% | -1 | 256 | 194 / -1 / -1 | 6 |
| rush | easy | capital | 20 | 90% | 154 | 10% | 397 | 110 | 165 / 180 / -1 | 2 |
| rush | easy | science | 20 | 95% | 181 | 5% | 397 | 108 | 198 / 144 / -1 | 4 |
| rush | easy | workers | 20 | 95% | 155 | 5% | 397 | 173 | 215 / 186 / -1 | 2 |
| rush | hard | capital | 20 | 90% | 168 | 10% | 268 | 91 | 198 / -1 / -1 | 2 |
| rush | hard | science | 20 | 60% | 217 | 40% | 173 | 182 | 204 / -1 / -1 | 4 |
| rush | hard | workers | 20 | 80% | 170 | 20% | 268 | 84 | 169 / -1 / -1 | 2 |
| rush | normal | capital | 20 | 90% | 159 | 10% | 323 | 154 | 211 / -1 / -1 | 3 |
| rush | normal | science | 20 | 95% | 191 | 5% | 324 | 149 | 198 / -1 / -1 | 4 |
| rush | normal | workers | 20 | 95% | 173 | 5% | 324 | 157 | 201 / -1 / -1 | 2 |
| sloppy | easy | capital | 20 | 0% | -1 | 100% | 267 | 3081 | 60 / -1 / -1 | -1 |
| sloppy | easy | science | 20 | 0% | -1 | 100% | 267 | 1798 | 60 / -1 / -1 | -1 |
| sloppy | easy | workers | 20 | 0% | -1 | 100% | 267 | 1019 | 105 / -1 / -1 | -1 |
| sloppy | hard | capital | 20 | 0% | -1 | 100% | 173 | 226 | -1 / -1 / -1 | -1 |
| sloppy | hard | science | 20 | 0% | -1 | 100% | 150 | 183 | -1 / -1 / -1 | -1 |
| sloppy | hard | workers | 20 | 0% | -1 | 100% | 173 | 160 | -1 / -1 / -1 | -1 |
| sloppy | normal | capital | 20 | 0% | -1 | 100% | 214 | 601 | 60 / -1 / -1 | -1 |
| sloppy | normal | science | 20 | 0% | -1 | 100% | 204 | 206 | 60 / -1 / -1 | -1 |
| sloppy | normal | workers | 20 | 0% | -1 | 100% | 214 | 209 | 104 / -1 / -1 | -1 |
<!-- results:end -->

## History

<!-- history:begin -->
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
| Save, load | 100 ms, 300 ms at most | 209 ms, 242 ms | 10 ms, 19 ms | PASS |
| Autosave | no frame over 50 ms | not measured | worst frame 34 ms | PASS |
| Page open, warm | 100 ms at most | not measured | 18 ms at most | PASS |
| Region, cold | 1.0 s, no frame over 50 ms | not measured | median 767 ms, worst 826 ms; worst frame 43 ms | PASS |
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

| Change | Effect |
|---|---|
| Build times about doubled | award on standard 167 → 174-184 in quick runs, before retuning |
| Base immigration 7 → 7.5 a month | a few days back |
| Goal-related buildings at 8-10 days, not 10-12 (lab, port, processor, foodworks, clinic) | a few days back |
| Science opening ¥4,800 → ¥5,300 | openings within 11% |
| Paid research ¥40 → ¥50 a point | research-first 184 → 181 |
| Easy starts with 1.4× cash; streak and processing goals scale with difficulty | easy 157 → 156 |
| Bots keep a margin over the non-mining goal, build processors at any mining town | no more new mines undoing the goal |
