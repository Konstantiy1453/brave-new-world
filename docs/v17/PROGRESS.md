# Colony Charter 1.7 — Progress

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `PLAN.md`.

| Phase | State |
|---|---|
| 0 Infrastructure and baseline | Done (`v17-phase0`) |
| 1 Bugs, QA export, formatting | Done (`v17-phase1`) |
| 2 Foundations | Done (`v17-phase2`) |
| 3 Contract, population, economy | Next |
| 4–8 | Not started |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

- Phase 2: simulation split into modules; English keys; `Sim.geo` split from `state`; save schema 3 with migration; autosave on a worker; reconciler UI with cached pages; map split into layers with signature-gated updates. Harness identical to Phase 1.

## In progress

Nothing.

## Next step

Phase 3: `data/v17/contract.json`-style stage data, `contract.gd` stages, attractiveness and immigration, wages, recruitment, `market.gd`, running costs, road upkeep, aid terms; rewrite the balanced, rush and research-first bots. Exit: floor, award bands, failure, population, money rows.

## Blockers

None.

## Latest harness metrics

Phase 2, `--full` (same as Phase 1): rush day 19, balanced day 19–42, 0 audit errors, 4 targets met, 11 missed. See `BALANCE.md`.
