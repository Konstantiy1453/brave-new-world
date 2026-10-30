# Colony Charter 1.7 — Plan

Brief: `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md`. This file fixes modules, data
ownership, the save schema and the order of work. Formulas and final numbers go in `DESIGN.md`.

## Data ownership

| Owner | Holds | Rule |
|---|---|---|
| `Sim.state` | Everything mutable and saved: accounts, settlements, stock, buildings, roads, shipments, research, company, contract, events, career, per-site mutable data | Changes only through `Sim.act()` / `Sim.tick()`. Plain data only, so `var_to_bytes(state)` is the canonical form for saves and determinism checks |
| `Sim.geo` | Derived geography: grid, rivers, lakes, statistics, generation parameters | Never saved for regenerable worlds; regenerated from `state.world` on load and verified against the stored hash. Read-only after generation |
| `game/data/v17/*.json` | Every tunable, with `version` and units | Loaded and validated by `simulation/rules.gd`; rules, UI text and tests read the same values |
| Simulation modules | Static functions taking `sim`; no module-level mutable state | `research`, `company`, `events_v2`, `career`, and the new `production`, `logistics`, `population`, `enterprise`, `contract` |
| UI | Reads state, calls `Sim.act()`; may not write state or advance time | `ui/labels.gd` maps English keys to display strings. No logic compares display strings |
| Map views | Read `Sim.geo` and `Sim.state`; never write | Rebuild only on a change of signature |
| Career layer | Active world id, global day, stewardship summaries, dividend accounting | Archives and the landing checkpoint move to sibling files |

## Save schema 3

One file per slot, written atomically with a `.bak`:

```
"CCS3" | u32 header length | header JSON | zstd(var_to_bytes(state))
```

The header holds `version`, `sha256` and `raw_size` of the payload, plus `planet`, `seed`, `day`, `cash`,
`difficulty`, `opening` for the main menu. Reading the header does not touch the payload.

- `state.world` keeps seed, seed input and protocol, generator version, size, world hash, and mutable site data.
- `Sim.geo` is regenerated on load. A hash mismatch refuses the load with a clear message and changes nothing.
- Landing checkpoint and stewardship archives move to `<slot>.ckpt-<hash>` and `<slot>.arch<id>-<hash>`, written
  before the main file. `state.career` keeps only their hashes.
- A JSON export sits behind `--dev`.
- Autosave serializes on the main thread and compresses and writes on a `WorkerThreadPool` task.
- Migration from schema 2: load through the 1.6 validator, then convert (world split out, Chinese status strings to
  keys, regions to sites with synthesized plots, the route to a road, buildings to plots). Legacy grids are dropped
  only when the legacy generator reproduces them exactly; otherwise kept, compressed, in the state.

## Modules

### Simulation (`game/simulation/`)

| File | Responsibility | Phase |
|---|---|---|
| `sim.gd` | Façade: `new_game`, `act`, `tick`, `settlement`, `summary`, `audit`, ledger primitives, tick order | 2 |
| `rules.gd` | Loads and validates `data/v17/*.json`; fails loudly in debug | 2 |
| `keys.gd` | English enum keys for building, enterprise, road, company and ledger states | 2 |
| `save_io.gd`, `save_migration.gd` | Schema 3 read/write, validators, schema 2 conversion | 2 |
| `production.gd` | Facility staffing, utilities, output, upgrades, plots | 2, 4, 5 |
| `logistics.gd` | Trade, dispatch, shipments, reservations, roads | 2, 3, 5 |
| `population.gd` | Feeding, housing, attractiveness, immigration, wages, recruitment, births, departures | 2, 3 |
| `enterprise.gd` | Private enterprises, forecasts, recovery | 2, 3 |
| `contract.gd` | Stages, trackers, deadlines, rewards, milestones | 2, 3 |
| `market.gd` | Dynamic export prices and saturation | 3 |
| `research.gd` | Existing; tree, labs, contracts, previews | 4 |
| `megaprojects.gd` | University, lift port, climate regulator | 4 |
| `sites.gd` | Founding settlements, plot queries, survey and prospecting, migration of old regions to sites | 5 |
| `events_v2.gd` | Existing; cooldowns, decisions versus notices, scaled magnitudes | 6 |
| `company.gd`, `career.gd` | Existing; aid delivery target, handover options, archive files | 1, 2, 8 |
| `tutorial.gd` | Named completion predicates; no `eval` | 7 |

### World (`game/world/`)

| File | Responsibility | Phase |
|---|---|---|
| `world_gen.gd`, `seed_geography.gd`, `hydrology.gd` | Legacy generator paths 1.4–1.6, kept | — |
| `geo2/plates.gd` | CC-GEO-2.0 plate-like continents and continuous height sampling | 5 |
| `geo2/climate.gd` | Latitude, altitude, pressure, wind, rain shadow | 5 |
| `geo2/world_gen2.gd` | Sea-level quantile, per-cell attributes, D8 hydrology, retries, hash | 5 |
| `geo2/site_gen.gd` | Poisson-disk sites, archetypes, quotas, plots, names, playability validator | 5 |
| `routes.gd` | A* on packed cells: land variants and sea routes | 5 |
| `map_base.gd`, `building_models.gd`, `region_view.gd`, `flat_view.gd`, `planet_view.gd`, `map_view.gd` | Layers, each extending the previous; `map_view.gd` is the coordinator | 2, 5 |

### UI (`game/ui/`)

| File | Responsibility | Phase |
|---|---|---|
| `design.gd` | Widgets gain a position-based reconciler: `begin`, widgets, `finish`. Re-running a page reuses its controls, so updates happen in place and controls keep stable names | 2 |
| `labels.gd` | English key → display string | 2 |
| `main.gd` | Shell, clock, navigation, modal host with cached pages | 1, 2 |
| `pages.gd`, `progression_pages.gd` | Split by subject as content grows | 2, 7 |
| `tutorial_coach.gd` | Coach panel, target outline | 7 |
| `capture_suite_v17.gd` | Screenshots at 3 resolutions × 3 text sizes | 8 |

### Tests and tools

`tools/run_tests.ps1`, `tools/test_suites.json`, `game/tests/support/watchdog.gd`, `game/tests/balance/*`,
`tools/build_v17.ps1`, `tools/package_v17.py`.

## Interfaces that later phases depend on

- **Actions** keep the `Sim.act(name, args) -> String` form (empty string means success). After Phase 5 `site` is
  the location argument; `region` stays an accepted alias so older fixtures and tests keep working.
- **Previews** are the single source for the build dialog, tutorial and balanced bot: `sim.build_forecast(site, kind, plot)`
  returns cost, materials, days, jobs, power, water, output, revenue, net per day, payback days and a disabled reason.
- **Ledger entries** gain an English `key` (for example `export.ore`, `wages.public`). `category` becomes display
  text derived from it. Metrics, career and UI read `key`.
- **Daily tick order** stays in `Sim.tick()` and is documented in `DESIGN.md`.
- **Events** apply effects only through `_transfer`, `_produce`, `_consume` and validated module calls.

## Order of work

Each phase ends with suites green through the runner (or intentional rewrites listed in `VALIDATION.md`), a harness run
recorded in `BALANCE.md`, `PROGRESS.md` updated, and a commit tagged `v17-phaseN`.

| Phase | Work | Exit check |
|---|---|---|
| 0 | Git, `CLAUDE.md`, runner, watchdog, fixture isolation, harness and bots, 1.6 baseline | Harness reproduces day 19 |
| 1 | W1 bugs with regression tests, QA data out of export, formatting commit | Bug tests pass; formatting changes nothing |
| 2 | Modules, keys, `Sim.geo` split, schema 3, reconciler UI, map split | Harness metrics equal to Phase 1; saves smaller |
| 3 | Contract stages, attractiveness and immigration, wages, recruitment, market, running costs, road upkeep, aid terms | Floor, award bands, failure, population, money rows |
| 4 | R10 = 2.0, 20-technology tree, lab L2, research contracts, upgrades, megaprojects, tech-tree UI | Research rows |
| 5 | CC-GEO-2.0, sites, plots, road network, sea routes, region view rework, legacy migration | Geography and road rows; migrated 1.6 save plays |
| 6 | Repeatable event pool, notices, feasibility, 25+ short events, 5+ chains | Event rows |
| 7 | Tutorial, build dialog, site card, settlement, economy, population panels, copy, menu | Tutorial test; screenshots viewed |
| 8 | Difficulty, openings, career, performance, visuals, final balance, build and release checks | All of §5.2, misses reported |

## Tests over the life of the work

Invariants stay: conservation, save robustness, determinism, the F05/F06/F11/F12 timing edges. Tests that encode superseded
rules are rewritten and listed in `VALIDATION.md`. Each phase adds its own suite named `v17_<area>.gd`.
