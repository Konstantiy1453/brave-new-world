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
