# Colony Charter 1.8 — plan

Design and order of work for `V18_BRIEF.md`. Starting numbers; the harness calibrates them. Record changes of direction in `DECISIONS.md`.

## Principles

- Old saves keep loading. New state arrives through `ensure_state`; new worlds through a new generator version. Old tech and building ids stay.
- Frozen generators stay frozen: CC-GEO-2.0 and 2.1 read their own road table, validator and radii, or their saves would stop binding.
- Effects live in data. `Research.bonus(sim, key)` sums the effects of completed technologies; code asks for a key, never for a technology, except where a technology unlocks a rule.
- User data: 1.8 uses `%APPDATA%\ColonyCharter\v18`, so it never writes over the user's 1.7 saves. It reads them read-only from `v17`.

## Pace (numbers in `economy.json`, `contract.json`, `progression.json`)

Money and labour should both bind. 1.7.1 mines paid back in about 10 days; 1.8 aims at 80-150 days.

| Item | 1.7.1 | 1.8 start |
|---|---|---|
| Prices | ore 8, copper 14, crystal 32, food 3, materials 12, parts 38, components 110 | × 0.6 |
| Building cash cost | ¥340-1,400 | × 5 |
| Materials and parts per building | | × 2 |
| Build days | 6-14, great works 80-120 | 12-35 for basics, 45-120 for advanced, 200-300 for great works |
| Opening cash | ¥4,600-6,200 | ¥20,000-26,000 |
| Deposits per plot | 300-450 days of a light mine | 1,200+ days |
| Speeds | 1×, 4×, 10× | 1×, 3×, 6× |

Contract, standard:

| Stage | Soft deadline | Goals (start) | Reward |
|---|---|---|---|
| 1 立足 | 360 | settlement; ¥15,000 exports; food 10 days; 30-day streak; project staffed | ¥8,000; second settlement |
| 2 分工 | 900 | 2 connected; local food 80%; processing 120 days; 200 people; 5 technologies | ¥15,000; third |
| 3 网络 | 1,500 | 4 connected; 1 frontier; 600 people; 14 technologies; non-mining 15% | ¥25,000; fifth |
| 4 自立 | 2,100 | 1,200 people; housed; enterprise 180 days; non-mining 30%; 28 technologies; 90-day streak | ¥40,000; seventh |
| 5 首府 | 2,880 | capital 800 people; 2,000 people; 40 technologies; 行星议会大厦; 180-day streak; no review | Governor |

## Planet scale (CC-GEO-2.2)

- Radii 3,823 / 6,371 / 8,282 km. Same terrain recipe as 2.1; deposits and plots in a 2.2 override block.
- Roads: speeds about 400-500 km/day, cost per km, build time from distance (`build_km_per_day`), sea routes a fixed setup time. A road under construction is `blocked_until` its finish day and carries `ready_day`.
- Islands: no landmass-size rule for starts; partners may be reached by sea; sea routes need no technology, only a port at each end. `shipping` improves them.
- Outposts carry more food, because the road takes months.

## Settlements

`s.kind` is `residential` or `frontier`. Building `site_kinds` limits where each may stand; absent means both.

- Residential: full immigration, births, housing, services, labs, advanced industry. Light mines and greenhouses allowed so a capital can start.
- Frontier: cheaper expedition, crew quarters, heavy and automated mines, field agriculture, output bonus, low immigration (workers arrive along roads), no births.
- First settlement is always residential. Migrated saves: first residential, others by what they hold.

## Buildings

About 55 kinds, data-driven by `role`: mine, harvest, farm, indoor_farm, factory, port, power, water, housing, lab, service, commerce, income, scrubber, depot, foodworks. New goods: alloy, machinery, pharma. `demolish` frees a plot. Models and icons map through `model` and `icon`.

## Research

`techs.json`: about 100 technologies, categories industry, agriculture, construction, society, tiers 1-5. `state.research.offers[category]` holds 3 cards (4 with a technology); partly done work stays on the table. One running project per category. Completing one redraws that category. Paid reshuffle. Benches and seats as before. `Research.add_lead()` lets events add a card.

## Pollution (`simulation/pollution.gd`)

`state.pollution.load` is planet-wide: emissions minus absorption, absorption scaled by planet area. Penalty = a(e^(load/L) − 1), capped; L scales with area. Applies to output, appeal and a health bill; never to distrust. Scrubbers, technologies and paid cleanup reduce it. Old per-settlement values are ignored.

## Company

Risk rates about a quarter of 1.7.1, recovery slower, review and intervention windows longer, environment source gone. Gauge on the main screen.

## Interface

- Top bar: table of colony totals with monthly change; power and water show supply and surplus because they are not stockpiled.
- Distrust gauge: vertical, thresholds marked, value, daily change, opens the company page.
- Building column beside the navigation for the selected settlement: construction first with finish date and progress bar, then buildings by kind.
- Calendar dates (`第 3 年 4 月 12 日`), speeds 1× 3× 6×.
- Research page: four columns of cards, team staffing, progress, finished list.
- Settling asks for a type as well as a name.

## Events

`e.deck`: at game start each definition rolls availability (`chance`, default 0.65), so each run has its own subset. Draws are less frequent and may fire nothing; long cooldowns. All text rewritten; pool grown to 60+ short events and 10+ chains; chains may stop early by chance.

## Order of work

| Step | Work | Done when |
|---|---|---|
| 1 | Docs, version, user folder, schema 4 reading schema 3, frozen 2.1 fixture | `v17_saves` green |
| 2 | CC-GEO-2.2, roads with build time, islands, speeds | world and sites suites green |
| 3 | Settlement kinds, role-driven production, new buildings and goods, demolish | sim suites green |
| 4 | Technology pool, cards, bonuses | research suite rewritten and green |
| 5 | Pollution, company rates, contract, economy scale | contract suite green |
| 6 | Bots and harness for the long game; calibrate | bar rows measured |
| 7 | Interface | capture viewed |
| 8 | Events: deck, rewrite, new content | events suite green |
| 9 | Tutorial, all suites, fixtures | all suites green |
| 10 | Final calibration, build, EXE checks, package, docs | delivered |
