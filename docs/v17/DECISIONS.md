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
