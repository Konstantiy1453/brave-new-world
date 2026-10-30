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

## Phase 3

- Stage 3's 30-day streak counts only from the start of stage 3 · this makes the floor hold by construction instead of by a calendar gate · a fixed earliest award day, which the brief rules out.
- Stage windows (local food, non-mining share, enterprise profit) run continuously rather than per stage · a player who already has 30 good days should not wait another 30 · resetting each stage.
- Second settlement gated by the expedition licence from stage 1; cap held at 2 until the road network exists in Phase 5 · a third settlement would have no road · connecting only two of three.
- R10 raised to 2.0 in Phase 3, a phase early · stage 2 needs two technologies and four scientists at 1.0/day would take over 100 days · moving the goal to Phase 4.
- Food and construction imports get first call on the port, then exports by value · a port full of ore starved the colony and blocked every expedition · exports first, as in 1.6.
- A port town also imports what a connected portless settlement lacks, and ships construction stock above 35/12 t instead of 90/20 t · outposts could otherwise never expand or eat · requiring a local surplus, which is the 1.6 bug F01 in another form.
- Depleted mines release their crew and stop costing money · paying miners to dig nothing makes depletion a silent drain · charging wages until the player notices.
- Social risk is weighted by the share of people affected, floor 0.2 · idle workers in a small outpost put the whole charter at full risk · the unweighted maximum.
- Departures are 1% of the settlement every period, at least one · scaling with size keeps the pressure meaningful in large towns · one person at a time.
- Balanced bot's 30-day reserve applies to investment; fixing a shortage (first farm, utilities) ignores it · §5.3 orders shortages first · reserving before fixing.
- Rush bot keeps a 5-day reserve and stops recruiting at 240 people · spending every coin made it slower than a careful player, which would not guard the floor · an all-in rush.
- Company review 50 days and intervention 40 days on standard (easy 60/45, hard 40/30) · gives passive review about day 60 and failure about day 150 as §5.2 asks · the 30/20 windows of 1.6.
- `build_forecast` lives in `production.gd` and is the one source for bots and the Phase 7 build dialog · bot and player must see the same numbers · a bot-only estimate.
- `SITE_BUILDING_CAP` raised to 40 as a stopgap · the 24 cap would block the population targets before plots arrive in Phase 5 · removing it now.
- Removed `tools/review_population_boundaries.gd` and sim_tests' full-contract checks; `v17_contract_population` and the harness cover them · they encoded the 1.6 clock births and contract · keeping them with rewritten numbers.
- Five branches, as Appendix D draws them, not the "four" of W5's text · the table is the detailed source · merging Logistics or Society into another branch.
- Upgrades keep the building working at its old level until the work is done · a habitat under upgrade would otherwise evict its residents · stopping the building for the build days.
- Extra upgrades beyond Appendix D: habitat L2 (medicine), processor L2 (electronics), farm L2 (hydroponics), port L2 (logistics), mine L3 (automation) · a mature colony needs places to spend money, and the money row asks for 60% reinvestment · only the two levels named in the brief.
- Megaprojects buy what the local store lacks at import price when ordered · 220 t of materials cannot be stocked through a 35 t import target, and a stockpiling chore adds nothing · making imports follow stock targets, which would make a target set for a processor spend money.
- Funding about 8 / 14 / 22 per day at ten staff by tier · research spend has to reach 15-30% of opex; at 1.6's 1.0-1.5 a day it stayed near 11% · raising scientist wages, which would also hit idle-looking staffing on the labour side.
- Science opening: rate factor 1.2 instead of 1.35, funding halved as before, prefab L1 lab, 15 points on survey · with a free lab and a head start the 1.35 factor would break the openings row · keeping 1.35.
- Workers opening starts with a prefab habitat · the second half of the openings spread, and the extra hands need beds · more cash.
- Scientist recruitment needs education, per Appendix D; until then immigration and training supply scientists · the appendix asks for it · open from day 0.
- Research-contract income ¥40 per point · a ten-person contract nets about ¥55 a day after wages: a real income, not better than a mine at first · ¥45, which beat early mines for the same people.
- Wage and upkeep ledger entries carry the building kind in `detail` · lab costs count as research spending in the harness, and the economy page will use it · a separate lab ledger key.
- 1.6 saves keep their research: work at or past a new cost finishes the project, staff released; the old validator judges against 1.6 costs and six goods · §1 forbids losing player progress · refusing or clamping without completing.
- `.gd` files are LF in git through `.gitattributes` · `gdformat` on Windows writes CRLF, which made every touched file a full diff · normalising by hand.
- Bots stop other spending once the contract's road is the only thing missing · a rush that spends everything never afforded the road and failed at day 320 · a separate rush-only rule.
- Rush bot researches only what the contract asks for · research spending made it slower than the balanced bot, weakening the floor check · keep the full tree.
- After the award bots recruit only for open jobs · recruiting to an unlimited goal gave 400 people and 130 jobs, then a takeover with ¥14,000 in the bank · the population goal stays.
