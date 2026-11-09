# Colony Charter (殖民契约)

Single-player colony management game. Godot 4.5.1, GDScript, GL Compatibility, Windows x64.
Deterministic fixed-step simulation, audited ledgers, Chinese UI, offline and free.

The current job is version 1.9: the moving map (spin, day and night, lights, clouds), the 3ds Max models placed
in the game, and the money balance. Read these before doing anything:

1. `docs/v17/PROGRESS.md` — the 1.9 section first: what is done, in progress and next. **Update it before stopping.**
2. `docs/superpowers/plans/2026-11-01-v19-money-and-models-instructions.md` — the 1.9 plan (money, models, bar).
3. `docs/v17/V18_BRIEF.md` — the 1.8 request and acceptance bar; every row still holds.
4. `docs/v17/DECISIONS.md` — judgment calls already made. Add one line per new call.
5. On the user's Windows PC: `docs/superpowers/plans/2026-11-08-v19-windows-verification-instructions.md` — the
   Windows-only checks (fixtures, menu atlas, all suites, EXE, frame times, full harness) and which way to fix misses.

Background: `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md` is the 1.7 brief. Folders keep the name `v17`.

## Paths

| | |
|---|---|
| Project | `game/` (`game/project.godot`) |
| Engine | `tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe` |
| Rules data | `game/data/v17/*.json` (every tunable, with `version` and units) |
| Simulation | `game/simulation/` — `Sim.act()` and `Sim.tick()` are the only ways to change state |
| UI | `game/ui/`; map rendering in `game/world/` |
| Tests | `game/tests/`, suites listed in `tools/test_suites.json` |
| Balance harness | `game/tests/balance/run_balance.gd`, bots in `game/tests/balance/bots/` |
| Outputs | `build/v17`, `docs/v17`, `evidence/v17`, `delivery/v17` |

## Never modify

`%APPDATA%\ColonyCharter\v16` (player saves), `build\v16`, `delivery\` (except `delivery\v17`), `versions\`,
`docs\v16\`, existing files under `evidence\` (write only to `evidence\v17`), `tools\godot-4.5.1\`,
and the `1.6.0 baseline` commit / `v1.6.0` tag. 1.9 keeps its own saves (schema 5) in `%APPDATA%\ColonyCharter\v19`
and only reads the user's 1.8 and 1.7 saves in `%APPDATA%\ColonyCharter\v18` and `\v17`; never write there either.

`art_reserve/` belongs to a separate 3ds Max modelling task. Do not touch it and do not stage it. The models reach
the game only through `game/tests/art/convert_models.gd` (recipes in `game/tests/art/model_recipes.json`), which
reads unpacked copies of the `art-assets-20261107` and `art-assets-20261109` releases outside the repository
(`--source=<dir>[,<dir>]`, each holding `art_reserve/`; on the user's PC the project root holds all of it) and writes
`game/assets/models/*.res` and `game/data/v17/models.json`. No FBX, MAX or texture goes under `game/`.
**Stage explicit paths; never `git add -A`.**

## Commands (PowerShell, from the project root)

```powershell
# All test suites, each in its own isolated process; non-zero exit if any fails
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Only sim_tests,v16_flow -Jobs 2
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Window      # adds suites that need a real window

# Isolate user data for anything run by hand. The runner does this itself.
$env:APPDATA = 'D:\勇敢新世界\evidence\v17\userdata_tests'
$engine = 'D:\勇敢新世界\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'

# Re-import after adding or renaming resources
& $engine --headless --path game --editor --import --quit

# Balance harness (writes evidence\v17\balance\<timestamp>.json and refreshes docs\v17\BALANCE.md)
& $engine --headless --path game --script res://tests/balance/run_balance.gd -- --quick --label=note
& $engine --headless --path game --script res://tests/balance/run_balance.gd -- --full --jobs=12 --label=note
```

On Linux (cloud sessions) use the Linux build of Godot 4.5.1 and `tools/run_tests.py` (same suites, same rules;
`--only`, `--jobs`, `--window` under `xvfb-run`). Four suites fail on Linux before any change because their
fixtures and world hashes were recorded on Windows (`v17_saves`, `v17_tutorial`, `v18_systems`, `world_v16_seed`);
the `review_*` tools need their original `D:` paths. Model conversion and captures:

```bash
godot --headless --path game --script res://tests/art/convert_models.gd -- --source=<release 20261107>,<release 20261109>
xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/art/bake_icons.gd
xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/art/model_gallery.gd
xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/art/capture_dynamics.gd -- --days=900
xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/art/bake_facility_views.gd
# Interface captures (construction and research, every size and text size); on Linux make the fixtures first
godot --headless --path game --script res://tests/make_fixtures_v17.gd -- --out=<folder> --only=midgame
xvfb-run -a godot --path game --rendering-driver opengl3 -- --dev --dev-script=res://ui/capture_suite_ui19.gd --qa-out=<folder> --qa-fixtures=<folder>
```

`gdformat` and `gdlint` are in the Python 3.12 Scripts folder and may not be on PATH. Git is at
`C:\Program Files\Git\cmd` and may need adding to PATH in a fresh shell.

Do not set `$env:APPDATA` in the shell that runs an export: Godot looks for export templates under the real
`%APPDATA%\Godot`. `tools\build_v17.ps1` must run with the real value.

## Working rules (from the brief, §2)

- Commit in small steps on branch `v17`: `v17: <area>: <what>`. Each phase ends with suites green, a harness
  run recorded in `BALANCE.md`, `PROGRESS.md` updated, and a tag `v17-phaseN`.
- A process that exits 0 while its log has `SCRIPT ERROR` or failed checks is a failure.
- Label evidence: automated test · balance harness · source-project window · exported EXE · screenshot viewed ·
  human playtest. Human playtests are NOT_RUN unless the user reports one. Report misses against the bar plainly.
- Numbers live in `game/data/v17/`. Rules, UI text and tests read the same values.
- `audit()` must pass every simulated day in every harness run; extend it to every new system.
- Same seed + same action log ⇒ byte-identical state, at any game speed.
- English identifiers; Chinese only in player-facing strings. No logic compares display strings.
- Static types in new and touched code; one statement per line; `gdformat`, then `gdlint` clean.
- Ask the user only for a change of premise, dropping a requirement, deleting or rewriting user data, or acting
  outside the repository. Everything else goes in `DECISIONS.md`.
