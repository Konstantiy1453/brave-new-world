# Colony Charter 1.7 — Progress

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `PLAN.md`.

| Phase | State |
|---|---|
| 0 Infrastructure and baseline | Done (`v17-phase0`) |
| 1 Bugs, QA export, formatting | Done (`v17-phase1`) |
| 2 Foundations | Next |
| 3–8 | Not started |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

## In progress

Nothing.

## Next step

Phase 2: `Sim.geo` split, modules, English keys, schema 3, reconciler UI, map split. Exit: harness equal to Phase 1 via `tools/compare_balance.py`.

## Blockers

None.

## Latest harness metrics

Phase 1, `--full`: rush day 19, balanced day 19–42, 0 audit errors, 4 targets met, 11 missed. See `BALANCE.md`.
