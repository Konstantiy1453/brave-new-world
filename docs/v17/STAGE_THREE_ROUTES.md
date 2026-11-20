# Stage three by operating routes (2026-11-20)

**Label: balance harness tool (automated), source project.** Run with `game/tests/balance/stage_three_routes.gd`; the
record is `evidence/v17/balance/stage_three_routes_routes-v3.json`. Human playtest: NOT_RUN.

**What changed.** Stage three ("network") is met when these all hold together:
- 3 towns connected;
- 14 technologies;
- a 15% non-mining share;
- **one operating route** (contract.json `routes`), measured over the last 30 days.

The routes:
- **Food corridor:** 900 units (about 3,000 t a day) of food carried between towns, with 80% of the
  colony's food grown locally.
- **Remote mining network:** 2,400 units mined in towns other than the capital, with two mining towns.
- **Coastal trade network:** 900 units sold abroad through harbours or carried on sea links (not the
  everyday imports), with two coastal towns.

600 people is no longer a condition. It is an achievement paid once (¥ 6,000), whenever it is
reached. The audited run had every other condition by day 1170 at 533 people and still waited until
day 1250.

**Measured on six seeds.** The balanced bot played each until stage three was complete; days are
game days:

| Seed | Routes working (first day) | Last operating goal met | Contract advanced | People then | 600 people | Old rule would advance |
|---|---|---|---|---|---|---|
| 260129 | coastal 576, food 588, mining 615 | 1018 (technologies) | 1018 | 629 | 947 | 1018 |
| 20261029 | food 607, mining 770 | 1224 (technologies) | 1224 | 709 | 1114 | 1224 |
| 42 | coastal 604, food 614 | 1284 (technologies) | 1284 | 531 | 1423 | 1423 |
| 1024873270 | coastal 606, mining 658 | 1147 (technologies) | 1147 | 513 | 1269 | 1269 |
| 909386518 | mining 699, coastal 856 | 1118 (technologies) | 1118 | 674 | 1009 | 1118 |
| 3 | food 443, coastal 443, mining 828 | 844 (technologies) | 844 | 556 | 895 | 895 |

- On every seed the contract advanced the day its last operating goal was met. There was no wait for
  the population.
- On three seeds that was 51 to 139 days sooner than the old rule. On the other three, 600 people came
  before the last technology anyway.
- Each seed met two or three routes, the earliest 30 to 330 days into stage three. Seed 20261029 never
  built a coastal network, 42 no mining network, and 1024873270 no food corridor, so the routes are real
  choices.
- What held stage three on every seed was the fourteenth technology, not the routes.
- The audit held every simulated day on every seed.

The first thresholds (v1: 90 / 450 / 300) were met on the first day of stage three on every seed and
measured nothing; the levels above come from the 30-day values the bots reached between days 720
and 1080 (`routes-v2`).
