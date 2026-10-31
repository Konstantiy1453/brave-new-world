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
- `state.world.regions` stays the list of sites; `site` is the action argument with `region` as an alias · renaming the field would touch every system and every old save for no player benefit · a new `sites` array.
- Site 0 is the best start and site 1 its partner in every generated world · tests, tutorial and first-time players all need a sensible default · a separate recommended-start field.
- Land fraction measured by area, not by cell count · cells near the poles are small · cell count, which overstates polar land.
- Worlds cached on disk only in exported builds, keyed on a generator revision and the rule data · regeneration takes about 0.45 s against a 300 ms load target; in development a stale cache would hide generator changes · always caching.
- Interior heights lower than the first draft (coast factor 0.30) · 0.42 turned every continent's interior into highland · a separate plateau mask.
- Deposit plots are placed before farms and town ground, keeping half the slots for the town · towns placed first left rich sites with no ore · fixed plot counts by archetype.
- A start is worth more with room to grow: value × (0.55 + 0.09 × neighbours, up to 5) · the richest start on a four-site landmass ran out of road by day 360 · excluding small landmasses outright.
- The first offered pair must be connectable by valley road · a beginner should not need the expensive road on the first try · any road within ten days.
- Valley road 300 km/day against engineered 260, with terrain penalties · at equal speed the cheaper road was the slower on 100% of pairs; this gives 57% over 200 seeds, inside the 30-70% target · cost alone.
- Road cost no longer scales with site development multipliers · a 1.65 multiplier put the first road at ¥3,600 · scaling only the terminals.
- Either end of a road can supply the 12 t of terminal materials · a new outpost connecting to another outpost had none, which froze the bot and would freeze a player · always the first-named end.
- Food and construction demand pass along chains of roads, up to 5 hops · a chain of portless towns starved past the first hop · requiring a port in every town.
- A town sends food on only when the receiving town is below 7 days and food is inbound; otherwise it keeps its full reserve · a flat reduction made outposts ship their expedition food back to the capital · a fixed three-day reserve everywhere.
- Nothing ships back along a road while the same good is arriving on it · hubs bounced food back and forth, paying fees and starving the next town · per-resource flow planning.
- Construction stock ships before food · its need is small and stops, while food can fill a road for weeks · a capacity share per good.
- Workers without jobs move along open roads to vacancies, at most 3 per road per day, and a town keeps 18 workers · aggregate people still need to reach the work; without it one town was jobless while another had vacancies · a manual relocation action.
- Immigration falls to zero as a town's jobless share goes from 10% to 35% · arrivals with no work piled up until the company took over; people do not move to a town with no jobs · a stronger attractiveness penalty alone, which still drew people.
- The "no review" goal does not block the award when lateness is the only cause of the review · lateness caused the review and the review blocked the goal that ended the lateness: a colony that met everything could never recover · dropping the goal.
- Sea landings bring a prefab port · nothing else could supply the materials for one · a bigger expedition kit.
- Social risk floor per settlement lowered to 0.1 · with six settlements one small unhappy town drove a takeover at ¥130,000 in the bank · removing the floor.
- Upgrades, megaprojects and the job-creation routine in bots use forecasts and can accept work that only breaks even · wages mostly return as food sales, and idle workers cost more · payback limit for everything.
- Events draw every 10 days, not 6 · with repeatable definitions a draw nearly always finds something, and 6 days buried the player · a longer draw for notices only.
- Money in events is the written amount up to ¥300 a day of recent income, then scales with income · keeps the 1.6 early amounts and tests while staying relevant later, about 2-5 days of income as Appendix C asks · percentages of income everywhere.
- Existing short events became notices, except 两地的第一个集市 and 泵房里的一滴盐, which are minor decisions; every chain is a critical decision · chains have real stakes and pausing for a box of seeds does not · pausing for everything.
- Rockfall opens only when a road actually closes, through `trigger` · a rockfall event with no closure, or a closure with no event, would each read as a bug · a random draw with its own closure.
- "Reroute through the valley" became a short temporary detour · only one road may join a pair of settlements, so the valley road cannot be built on the spot · a second road just for the event.
- A forward contract is modelled as +10% on all export prices for 25 days for a deposit · a fixed price per good would need its own contract system · dropping the event.
- The school is an event outcome (appeal for 180 days, two workers retrained), not a building · the brief adds no school building · a new building kind.
- 山脊里的空白图 was chosen as the sixth chain over 玻璃下的第二季 · it ties to hidden deposits and prospecting, which already exist · both.
- Finished event instances beyond 16 are dropped; `endings` and `last_opened` keep what later conditions need · save size stays bounded with repeatable events · keeping every instance.
- The tutorial game holds its first event until day 30 through an ordinary `tutorial_begin` action · the first lessons should not compete with a surprise decision, and a replay stays deterministic · switching events off for the whole tutorial.
- The scripted filter clog multiplies pump output by 0.15 · 0.2 left one pump exactly at demand, so nothing showed; at 0.15 one pump is short and two are enough · removing the existing pump.
- The tutorial's progress lives in `settings.cfg` and replay starts a new game on the pinned planet · a tutorial state inside saves would have to be migrated and validated · resuming a half-done tutorial from a save.
- Coach steps do not lock the interface; a step that is already satisfied moves on by itself and Back holds it until Next · the brief says never modal · blocking clicks outside the target.
- Tips show after the tutorial or instead of it, one at a time, once per installation · a first-time player should meet each only once · per-save tips.
- Sidebar actions moved to a pinned bar under the scrolling part · at 1080p the settle button was below the fold, and the tutorial pointed at something off screen · a shorter card.
- Navigation buttons shrunk to 34 px so all 14 fit at 1080p · the list had grown past the panel · a second column.
- A category filter opens at "all" from the build button and at the right category from a fix button · a filter left on from an earlier fix hid what the tutorial's next step asked for · remembering the last filter.
- The globe's sun follows the camera, over the viewer's left shoulder · a fixed sun put the home of any bot or player not on site 0 in the dark · a brighter night side.
- Very fast is 10×; a frame runs at most 3 days and drops the backlog · a long frame (region load, autosave) must not become a burst of days · no limit.
- Economy page runway keeps using `summary().runway` · one number from one place; its 7-day average is the fix for bug 8 · a second calculation from the new rollups.
- Daily rollups are `state.stats`, 90 days of money and 30 of goods, read only by pages and validated on load · rules must not depend on a display aid, and the pages add them up unchecked · a separate file next to the save.
- Milestone rewards count as paid income in `career.milestones_paid` · they were added to the career balance alone, so any save after a milestone was refused as "分红转账不守恒" (found by the capture suite) · removing the check.
- Capture fixtures are saves written by `tests/make_fixtures_v17.gd` with the harness bots into `data/v17/acceptance_*.save` · they follow rule changes with one command, stay under 50 KB each and the export filter already excludes them · hand-built JSON fixtures as in 1.6.
- Difficulty adds event and price pressure through `event_interval_factor` (1.3, 1.0, 0.8) and `market_depth_factor` (0.85, 1.0, 1.2) · W12 lists both and neither existed; the pool and the rules stay the same · a different event pool per level.
- Capital's first expedition costs 60% and science's survey bands are 60% as wide · W12 lists both as what makes the openings distinct · more cash instead.
- Opening crews moved to 52 workers (workers) and 40 (science) · the openings' award days spread 19% with 56 and 36, 10% now · changing their cash.
- Base immigration is 7 a month, not 6 · population was the last goal to finish in most runs and the 180 target comes from the brief · lowering the goal.
- The stage streak counts days whose last seven sum to no loss · one lumpy day (a shipment, a bill) reset a 30-day goal and decided the award day by chance · a shorter streak. The day-by-day count stays for the status line.
- Food for a town with a port waits until the portless towns beyond the sender are served · farm towns sent everything to the capital by road order, while the far end of the chain starved next to a full warehouse · sorting roads by need.
- A hub feeding a hungry neighbour keeps its neighbour's days plus travel plus one · a hub at eleven days watched the next town starve · sending everything.
- A port imports for the towns beyond it even when food is on its way to the port itself · food on the road feeds nobody further along it · counting only the local target. Stock above the local target does count, or the port buys the same demand again every day.
- Company risk at or below 0.15 a day neither raises distrust nor blocks recovery · one small town's joblessness ended colonies with ¥160,000 in the bank · removing the population floor.
- Farm plots no longer take the ground the town needs (10 plots or half), starts need 12 general plots and partners 6 · the best start of seed 1000003 had room for its prefabs and nothing else: no laboratory, no housing, and no way to finish stage 1 · refusing such landings. Generator revision 2.
- Deposits are 1.25× larger · mines ran out by day 350-500 and bots went bankrupt with a full colony; income at day 720 was the thinnest money row · cheaper mines. Generator revision 3.
- The site card shows what one farm would make, climate included · fertile land in a cold place grows nothing, and the fertility figure alone misled the bots and would mislead players · a separate climate warning.
- The local-food goal's hint names hydroponics · a colony with poor land in its first two settlements can only finish stage 2 with greenhouses · a third-settlement licence before the goal is met.
- Bots: greenhouses when land is poor, no barren partner while hungry, no more mines into a flooded market, belt-tightening on wages when losing money and low on cash, deep mining first when a mine runs out, and after the award spending some cushion to end dependence on one export · the brief's balanced bot is "a reasonable human", and each of these stuck runs was a choice no person would keep making.
- Component plants, greenhouses and paid research count as lasting income under a steward · the 1.6 model knew only processors, foodworks and farms · new stewardship rules.
- The road card names its closure risk and in-transit goods · W10 lists both · a separate page.
- The settings page and the menu's Continue read 1.6 saves from `%APPDATA%\ColonyCharter\v16`; the old button still pointed at the 1.5 folder · an upgrading player found nothing to continue · an import dialog. The files are only read.
- Measures and scripted checks (`tests/perf_probe_v17.gd`, `tests/exe_drive_v17.gd`) run through `--dev --dev-script=<path>` and stay out of the PCK · the export must stay free of test material, and the numbers must come from the real EXE · shipping them.
- A developer JSON export sits behind `--dev` on the settings page and is never read back · W11 asks for it and only as an aid · a second save path.
- Tuning stopped with the best bot at standard being rush for all three openings · the row is reported as a miss, not redefined; science is decided by 1.5 days, research-first wins it without rush, and easy and hard differ · weakening rush, whose job is to guard the floor, or adding opening-specific bot rules.
- 18 of 180 balanced runs are taken over later on, nearly all after the award around day 430-720, once mines run out and the bot, which never hands over, keeps paying a full colony · handover is the game's answer to that moment and a person can use it · adding handover to a bot that must measure day 720.
- Finishing the world atlas moved to a worker; only the texture upload stays on the main thread · it stopped the frame for 340 ms on each new world's first opening · leaving it, since no target names it.
- The build script unpacks export templates into `build\godot_home` when `%APPDATA%\Godot` has none · they were missing, and writing there is acting outside the repository · installing them, or asking.
- The EXE check is scripted through real buttons and marked as such; the manual run stays NOT_RUN · no way to play it here, and a script must not be reported as a person · skipping the check.
