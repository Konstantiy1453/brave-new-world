# Colony Charter 1.7 — Design

Systems, formulas, tick order and data files. Grows phase by phase; final numbers and the reason for each change from 1.6
are recorded here.

## Daily tick order (1.6, unchanged until a phase says otherwise)

1. `day += 1`; reset the day's operating figures.
2. Repay arrears.
3. Advance shipments; arrivals enter local stock.
4. Each settlement: expedition countdown, staffing, utilities, wages, maintenance, production.
5. Research: allocation, funding, progress.
6. Each settlement: trade (food orders, exports, imports).
7. Enterprise.
8. Each settlement: feeding.
9. Dispatch new shipments.
10. Administration cost.
11. Population: immigration, births, maturation, training.
12. Company social and environmental effects.
13. Events.
14. Governor share, if awarded.
15. Refresh housing and food days; record stock deltas.
16. Contract check.
17. Company tick, including aid.
18. Operating history; trim the ledger.
19. Career tick.

## Contract (data/v17/contract.json)

Three stages, each a set of goals checked daily; a stage completes on the first day all its goals hold.

| Stage | Soft deadline (easy / standard / hard) | Goals | Reward |
|---|---|---|---|
| 1 立足 | 120 / 90 / 75 | First settlement; ¥3,000 cumulative exports; food ≥ 10 days; 10-day streak; one project staffed | ¥1,500; expedition licence |
| 2 分工 | 250 / 200 / 170 | Two settlements connected; local food ≥ 80% over 30 days; processing active ≥ 20 days; population ≥ 120; ≥ 2 technologies | ¥2,500; third-settlement licence |
| 3 自立 | 360 / 300 / 260 | Population ≥ 180; employment ≥ 60%; everyone housed; enterprise profitable 30 days; non-mining income ≥ 25% over 30 days; 30-day streak from the start of this stage; no active review | Governor |

Goal sizes for exports and population scale ×0.8 / ×1.0 / ×1.2 by difficulty. An overdue stage adds an economic risk of 1.2 distrust a day to the company process; it never fails the game by itself. Rewards are non-operating.

## Population (data/v17/population.json)

Attractiveness per settlement, clamped 0–2: base 1.0; beds (over capacity −0.6, none free −0.4, ≥ 10% free +0.2); food (< 3 days −0.5, < 7 −0.2, ≥ 14 +0.1); jobs (≥ 30% unemployed −0.3, vacancies ≥ 5% +0.2); wage (multiplier − 1); open enterprise +0.1; pollution above 35, −0.01 a point; power or water short −0.2; company review −0.2.

Arrivals accrue at 6 a month × attractiveness, capped by free beds, with ¥60 savings each. Scientists are 12% of arrivals per lab, at most 30%. Recruitment: ¥120 a worker, ¥200 a scientist, +10% for each campaign in the last 90 days, at most 20 people, 10 days' travel, beds reserved at purchase. Births: 1% of adults a year when beds and food allow. Below attractiveness 0.5, or with too little housing, food or work, 1% leave each period after 12 days; a higher wage multiplier stretches the period.

## Economy

| Item | 1.6 | 1.7 | Why |
|---|---|---|---|
| Crystal | ¥26, 3 t, 12 jobs | ¥32, 3.5 t, 10 jobs | Best per worker; deposits scarcer from Phase 5 |
| Processor | 10 jobs, 0.8 parts | 8 jobs, 1.2 parts | About +¥21 a day, payback about 62 days |
| Road upkeep | none | ¥1.5 valley, ¥5 engineered | Real trade-off |
| Road closure | none | Engineered about every 120 days, 3–8 days | Risk against speed |
| Liquidity aid | ¥1,800 for ¥1,200 over 60 days, 10% | ¥1,800 for ¥2,100 over 90 days, 8% | Buys time, not money |
| Supplies aid | ≈ ¥1,500 for ¥700 | ≈ ¥1,500 for ¥1,400 over 90 days | Same |
| Administration | ¥5 | ¥5 + ¥0.04 a resident + ¥3 a settlement | Growth has running costs |
| Landing housing | 80 / 40 | 60 / 24 | Housing is an early decision |
| Immigration | +2 per 24 days | 6 a month × attractiveness | Responds to the player |
| Research R10 | 1.0 | 2.0 | Research arrives inside the first contract |

Export price = base × clamp(1 − 0.4 · S / M, 0.6, 1), where S rises with every tonne exported and decays 2% a day. M: ore 3,000, copper 1,500, crystal 500, materials 1,200, parts 400 t.

Trade order each day: foodworks orders, food imports, construction imports, then exports by value (parts, crystal, copper, materials, ore).

Tick additions: `road_daily` and `Market.daily` after dispatch; administration uses `_admin_cost()`.
