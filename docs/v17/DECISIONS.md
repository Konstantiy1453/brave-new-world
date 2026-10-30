# Decisions

One line each: decision · reason · alternative rejected.

## Phase 0

- Installed Git system-wide with winget, by the user's choice · no git on the machine and the brief requires it · portable MinGit in `tools/`.
- Git LFS for `*.png`, `*.ttf`, `acceptance_*.json` · Git for Windows ships LFS, and the brief asks for it when installed · plain commits.
- `art_reserve/` ignored for new files; its 7 baseline files stay tracked · a separate 3ds Max task is working there and its brief separates it from the game · tracking its output in this history.
- Stage explicit paths, never `git add -A` · the same concurrent task must not leak into commits · trusting `.gitignore` alone.
- Commit identity set for this repository only · no global config existed and this avoids changing machine state · global `git config`.
- 1.6 suites redirected to `evidence/v17/tests`, including `tools/review_*.gd` and `game/world/*` probes · they wrote into `evidence/v16`, `docs/evidence` and `docs/` · leaving them and running only in a copy.
- Baseline suites and harness run on unmodified 1.6 production code with test-only edits · the brief forbids overwriting old evidence and fixtures, so tests had to change first · running tests from the raw baseline commit.
- `project.godot` moved to `ColonyCharter/v17` at the start of branch `v17` · a forgotten APPDATA override must not reach player saves · changing it later.
- Passive and sloppy bots defer every event so its default applies at the deadline · in the real UI an ignored decision blocks time, so a headless idler needs an equivalent · leaving events pending forever, which also stops new draws.
- Harness parallelism through child processes (`--jobs`, `--shard`) · 900 runs need it to meet the 15-minute limit, and simulation state is not shared · threads inside one process.
- Runner suite list kept in `tools/test_suites.json` · suites, timeouts and markers are data · hard-coding them in the script.

## Phase 1

- Aid goes automatically to the settlement that lacks most of what the aid carries, and the terms show the destination · no extra decision for a player in crisis · a destination picker.
- `free_workers` counts jobs of facilities still under construction · two queued mines would otherwise both look staffable · using last tick's employed count.
- On closing a panel the previous speed returns unless a decision is still unanswered; award and failure pages stay paused · reopening an unanswered event at once would stop the player looking at the map · always resuming.
- `gdlintrc` relaxes line length to 120, public methods to 60, file length to 1800 · legacy files need room until later phases split them · disabling the rules.
- Removed the `research` action along with its dead page; `sim_tests.gd` now staffs through `research_allocate` · the brief lists it as dead code · keeping an alias.

## Phase 2

- Map split as a layered inheritance chain (`map_base` → `building_models` → `region_view` → `flat_view` → `planet_view` → `map_view`) · no function body changed and tests keep their access, so the split is provably neutral; Phase 5 reworks the contents · composition with a back-reference, which rewrites every member access.
- Reconciler in `design.gd` rather than hand-built update functions per page · pages stay plain top-to-bottom code, controls persist, and names become stable · a separate build and update function for each of 15 pages.
- Ledger entries hold an English `key` and optional `detail`; `category` is gone and `ui/labels.gd` makes the text · career, metrics and UI needed a reliable key · keeping both fields.
- `shortages` hold `{key, detail}` · Phase 7 needs a fix button per shortage · display strings.
- Legacy grids dropped when the generator reproduces them by hash; all shipped fixtures qualify · saves fall from about 8 MB to about 10 KB · always keeping a compressed copy.
- Old fixtures keep their JSON form and migrate on load · shipped fixtures must not change without `--fixtures` · regenerating them.
- `max-returns` raised to 24 · `Sim.act` is a dispatch table · splitting the dispatcher to satisfy a count.
