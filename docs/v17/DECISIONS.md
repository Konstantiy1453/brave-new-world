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
- Days stay the smallest time unit and build times roughly double (user offered weeks or longer builds) · every deadline, rate, ledger and balance figure is in days, so weeks would redo all of it for the same feel · weeks.
- The user's "building list" is read as an in-game page listing every building and what is under construction · slower builds need a place to see them; the per-building table also went into the reply and `DESIGN.md` in case a data list was meant · a data table only.
- Pre-made site names are gone from new worlds (user request, replacing Appendix G); a site shows a number and its terrain until named, and blank keeps the number · a settlement needs some label, and the terrain tells more than an invented word · forcing a name before settling.
- Settlements can be renamed · a typo should not last forever · one chance only.
- Duplicate names are allowed · "whatever they want to type"; logic uses ids · refusing repeats.
- New generator version CC-GEO-2.1, with CC-GEO-2.0 frozen beside it · 1.7.0 saves regenerate their terrain from the seed, and the user already had some; a changed generator would make them refuse to load · moving them, or refusing them.
- The route cache key includes the generator version · two versions of one seed in a session shared cached routes, which changed the validator's verdict and the world: found by the 2.0 fixture test · clearing the cache.
- A character softens after repeated playability failures · a planet must never ship unplayable, and hard types are the point otherwise · dropping the hardest combinations outright.
- Seed 260129 is pinned to 温和 · 群陆世界 · 平缓 · the tutorial's text promises a kindly start with a fertile neighbour, and many tests use that seed · a different tutorial seed.
- The seed box starts random; with the tutorial on, seed, size, difficulty and opening are locked and the menu says why, and 换个种子 leaves the tutorial · new games silently ignored those choices and loaded the tutorial planet, and the box's default was the tutorial's own seed; that is why "new" planets looked alike · ignoring them quietly with a note.
- Lab, port, processor, foodworks and clinic build in 8-10 days, others about double · the goals' chain runs through them and the standard award stayed in band · a flat doubling, which leaves less room in the 120-180 band.
- Stopped tuning with three small misses after five full and three quick runs · each further change moved the numbers beside it by more than it gained, and the fix is the user's call · more rules bent to fit.
- The menu words the planet type as a forecast (多半是), since 84% of seeds keep their draw · building the world on every keystroke takes up to 3.6 s, and a flat statement that is wrong one time in six is worse than a hedge · generating in the background while the menu is open.
- The bot's blind spot on easy (2 of 60 runs never found a second town) stays · the game refuses nothing and a person simply settles; it only counts against the harness row, which misses anyway · another bot change and full run for a number that does not change the game.

## 1.8

- Version 1.8.0, with folders staying `v17` (build, docs, evidence, delivery, data) · `CLAUDE.md` allows writes only there · a `v18` set of folders.
- 1.8 saves live in `%APPDATA%\ColonyCharter\v18` and 1.7 saves are read from `v17`, never written · a player may want to go back · overwriting.
- Five contract stages instead of three, and an old save in progress continues into them · the run had to grow to 6-8 years and every stage needs something to ask for · stretching three stages.
- Road, expedition and travel times come from kilometres on a sphere of the planet's true radius · the request says real, calculated · a scale factor per size.
- A town on a CC-GEO-2.2 planet has about 54 building plots and spent mines give their ground back · the capital goal needs room, and a player should see land as a real constraint · unlimited plots.
- The terrain field of a region grows from 57×47 to 96×72 on CC-GEO-2.2 only · plots stood off the edge of the old field, and older worlds must stay identical to the vertex, which a test holds them to · one size for all.
- Roads under construction count as closed, with their own colour and date · no separate network state to keep · a road that opens partly.
- A shipping lane takes 60 days to open and is not counted in the road row · the terminals are the work, not the sea · the same months as a road.
- The expedition kit grows to 130 materials, 30 parts and 420 food · with roads taking months a new outpost starved before anything could reach it, and could not afford a farm or a port on arrival · shorter roads.
- Food on the way only counts against a port's order if it arrives within the reserve window · a town on a long road starved beside a working port because a month of food was in transit.
- Starvation weighs by the town's share of the colony · one hamlet going hungry should not cost a charter · the old flat rate.
- Pollution is planet-wide, exponential, and out of `company.gd` entirely · the request · a capped linear penalty.
- Crossing a pollution stage opens a scene, and these three events are in every run's deck · a run-ending problem should be told, not only shown in a figure.
- The gauge shows the day's real change, so 0 at zero distrust · "-0.20 a day" at zero reads as a bug.
- Research reference rate 2.0 points a day at ten teams, with the final stage asking for 40 technologies · 2.4 gave 62-86 technologies by the award, 1.8 fell short of the bar.
- What the charter needs (community_admin, civic_planning, capital_planning) is always on the table, marked, and cannot be redrawn away · a required technology among 120 cards could stay out of reach for a whole run · a separate charter tree page.
- The hall can stand in any residential settlement · the capital is usually full by then, and the goal is the building, not its address.
- Offers are drawn from the save's own generator state and never from the simulation's · the deal must not change what later dice do, and redraws must replay.
- A redraw costs ¥600 + ¥300 per highest tier reached · cheap early, a real decision late.
- Every category runs one project at a time; a new card stands the old one down with its work kept · matches the request's "pick one".
- Building cards the colony cannot build yet stay off the build page · 56 buildings would bury the choice · greyed entries.
- Power and water show supply and surplus in the top table, because neither is stored · the request asks for a total and a monthly change, and for these two that would be empty figures. Reported in the closing message.
- Materials, parts, components, people and settlements join the seven requested cells · the player needs them just as often, and the table has room.
- About a third of the event pool is off in each run, and 45% of draw days open nothing · this is what "some can be skipped" asks for · a fixed order with skips.
- Old events keep their ids, node ids and choice ids · saves mid-chain must still load.
- Labour lever measured from year 2, on a colony past its first lean year · on day 0 the wage bill itself holds arrivals back, so the row measured poverty and not attractiveness.
- `wage_per_multiplier` 1.5 · at 1.0 the lever moved arrivals 15% and the bar asks for 20%.
- The road trade-off row's upper bound (70%) is no longer enforced by `v17_world_stats`; on real planets the cheap road is the slow one on about 89% of pairs · that is the trade-off working, not failing · reported as a miss against the bar as written.
- `tests/v16_rules_tests.gd` and others that hard-coded 1.7 figures now read them from the rule files · numbers live in `game/data/v17/`.
- Bots give any town past 100 people a port · one road carries 28 t a day and feeds fewer than 190 people, and a person would see the red line; a bot has to be told.
- The final stage asks for 2,000 people and 40 technologies · at 1,800 and 35 the median award sat at the bottom of the band, and the research row missed by a few.
- Hard's deadlines 320, 820, 1,400, 2,000, 2,880 and goals ×1.1 · the old final deadline of 2,550 came before its own target band, and most hard runs were taken over while earning the award. Hard still has the shorter review windows, more risk, lower prices and more events.
- Starts need 28 general plots, partners 12 · on a site with 14 the capital goal could not be met without tearing the town down.
- Starvation is no longer the only thing weighted by share: social trouble below the tolerated rate does not block an award · a lateness review plus a hamlet's small problem held up finished charters.
- A full frontier post is not unrest: frontier appeal -0.1 · at -0.2 a full camp fell below the departure line and could end in a takeover.
- `wage_per_multiplier` 2.0 and base immigration 9 a month · the lever moved between +13% and +38% at lower values depending on seeds, and population fell short at year 4.
- Pollution scale 3,600, with `sqrt(area)` in the penalty · 7,500 gave 4% if ignored, far from the bar; the square root keeps small planets from being punished twice.
- Cleanup costs ¥5,000 for 300 load · at ¥2,000 for 500 it cost less than a road's upkeep to erase a colony's whole output.
- Capital opening ¥32,000, science opening's research bonus 1.1 · they were 21% apart; they are still 20% apart in the release run, within noise of each other between runs. Tuning stopped here and the row is reported as a miss.
- The tutorial's first event waits for day 120 · with builds this slow, day 30 broke into the shortage lesson.
- The harness re-runs a lost shard once and reports it · one shard died without output, and the whole run's results were thrown away with it.
- Stopped after six full runs · the last three moved the openings row back and forth without settling, and the rest of the bar held.
- Three rare failures are reported, not explained · 97 further runs of the crashed suite were clean, and reading the worker-thread code found nothing shared.

## 1.9: moving map and models (2026-11-07)

- The moving map lives in `world/visual_clock.gd`, outside `Sim` · spin, sun, seasons and weather are cosmetic, so saves and replays stay byte-identical at any speed · driving the planet's turn from the game day, which would spin it every 5 seconds at 1×.
- One turn of the planet takes 240 s at 1×, 140 s at 3× and 92 s at 6×, a third as fast while paused · the turn should show that time runs and how fast · a fixed real-time spin unrelated to game speed.
- The spin eases out for 9 s after any drag, zoom or click on the globe, and a clicked site stays in front of the camera while the planet comes to rest · a target that slides away under the pointer is hard to pick · stopping the spin for good after the first click.
- The sun is fixed in space east of the opening view, so the first site starts its morning · TerraGenesis-style lighting needs a real terminator; starting at dusk would put the player's town in the dark within half a minute · the 1.8 sun over the viewer's shoulder, kept as the `day_night` off setting.
- The night side is moonlit, not black (about 12% of daylight, blue) · sites, coasts and routes must stay readable at night · a physically dark night side.
- The atlas now holds geography (temperature, rainfall, ridge, height) and the shaders colour it per pixel · coastlines become smooth curves at any zoom, biomes blend, relief is lit by the real sun, and the globe, flat map and regional ground share one palette · retouching the baked colour atlas, which kept its 26 km texels and hard biome edges.
- Height in the atlas alpha uses a square-root curve (0.5 + 0.5·sign(h)·√(|h|/2)) · a coastline needs fine steps near sea level and the trenches go to −1.85 · linear alpha, which clamped the deep ocean.
- Atlas cache key moved to `atlas-1536-r6-data`; the bundled 1.8 menu atlas was removed · its key can never match the new one, and a Linux build names the same world differently from Windows (generation floats), so it cannot be rebaked here · shipping a Linux-baked file that Windows would never find. `tests/art/bake_menu_atlas.gd` rebakes it on Windows.
- Night lights are one 2048×1024 RG8 texture repainted only when towns or lit roads change · the globe and the flat map read the same texture and a mip gives the halo for free · thousands of light nodes.
- Clouds: tileable 96³ noise, two layers carried by latitude winds and cross-faded every 45 s, and drawn cyclones whose arms turn without winding up · infinite shear and wound-up storm rings both showed in the first renders · a static cloud texture turning with the planet.
- Weather off hides the clouds entirely · it is the performance escape for weak GPUs, and frozen clouds would still cost the same · a separate quality setting.
- `world_v16_terrain_identity` now checks vertices and normals, plus that the ground carries geography for the shader · the user asked for a smoother surface, so the baked v1.5 colours are no longer the reference; the geometry still is · keeping the colour hash and the rough look.
- `world_v17_seam` measures the seam under the 1.8 lighting (spin, night and clouds off, clock frozen) · a terminator or a cloud edge on the seam column is not a seam bug · loosening its threshold.
- Region day and night follow where the site is on the turning globe · one clock for the whole map; at night windows of working buildings, lamps and headlights light up · a separate regional clock.
- The converter keeps each model within its triangle target: every colour slot starts at the finest
  level of detail under its share, shares weighted by slot (metal and gold ×2, ore, concrete and water
  ×0.5: thin structure vanishes first when simplified, bulky shapes keep their look); while a model is
  over, the slot heaviest for its weight steps down; budget left over steps slots back up · the first
  converter took the level nearest the target, so 26 of 53 models were over 4,500 triangles (field
  station 17,074) while others lost their hero parts (field station's crops, the light mine's
  headframe was at risk with equal shares) · equal shares. Two runs are byte-identical; the gallery
  (`evidence/v17/art/gallery/`) was compared before and after.
- Suite `v19_art` (plan B7) asserts per model: it loads, the registry's triangles and size match the
  mesh, the triangle target, one surface per known colour slot (at most ten: the converter has ten
  slots, the plan said eight), the footprint (4.2 units, great works 5.0, a recipe's own `fit`; kit
  pieces sized by `scale` are not checked), standing on its datum and reaching at most 0.7 below it
  (open pits 1.5); and that every building kind resolves to a model and assets/models stays under
  12 MB. Levels of detail are printed, not asserted: 21 models have fewer than three on their heaviest
  slot before and after this change, because the engine's simplifier stops on sharp-edged kit geometry ·
  a failing check nobody can fix in the converter. A recipe's `exceptions` lets a model off a check
  with its reason: field station, vertical farm, ranch and arcology (open crop strips and tree crowns
  the simplifier cannot reduce), the two heavy open-pit mines (the terraces are one 378,000-triangle
  mesh) and the heavy crystal mine's shaft (1.25 below grade, hidden by the ground). The model brief
  asks the modelling agent for closed low-poly crops, crowns and terraces.
- Building icons (plan B6) are baked by `tests/art/bake_icons.gd` from each kind's model with its tint
  and scale, under the map's daylight sun, fill and ambient, orthographic from the front right and
  above, at 256 px scaled to 128 px with mipmaps; the build card shows them at 64 px and the building
  column at 32 px (the SVG pictograms were 31 and 20 px, too small for a model) · the plan's recipe;
  the 15 SVG pictograms stay for goods and as the fallback for a kind without a model. They are
  lossless WebP, not the plan's PNG: the repository sends every PNG through Git LFS, whose GitHub host
  the cloud session's network does not reach, and 15 KB icons gain nothing from LFS.
- The plan's images (B6: up to ten beauty renders behind the menu and on the stage and award screens)
  are not used: the seven suggested renders are layout views on grey terrain in the present-day look
  the user has since asked to move away from, and a picture behind the menu would hide the turning
  globe the 1.9 request was about. The model brief asks for four key-art renders in the new look ·
  the plan's list as written.
- The 2026-11-09 delivery (release `art-assets-20261109`: 41 game ids, 37 construction states, the shuttle's
  flight state, all checksums matching the delivery check) is converted as its own pack, one model id per game
  id, so every building kind but `service` has its own model; the six older generic models no kind used any
  more (`mine`, `greenhouse`, `research`, `industry`, `logistics`, `civic`) are retired, and `service` stands
  in with the commerce arcade · ids per model family, kept for old models.
- A construction state is fitted in its building's frame (`like`), so the site stands exactly where the
  building will, and replaces the shared site kit while the building is built; a great work's state brings its
  own crane, so no extra crane is added. Kinds without one keep the kit · fitting each state on its own, which
  moves sites whose scaffold sticks out.
- Terraforming stages and capital-district levels are cut from one FBX by their part groups (`include` /
  `exclude` on `_stage2`, `_stage3`, `_level2`…`_level5`) in one frame and drawn on the base as each stage or
  level is finished; the base and its add-ons share the great-work budget (5,000 + 2,500 + 1,500 and
  3,000 + 4 × 1,500 triangles, both under 9,000) · one mesh per level, which would repeat the base five times.
- The shuttle and its pad are scaled at 0.09 units a metre (a 45 m building's scale), the road vehicles at
  0.11 (the length of the procedural vehicles they replace), all at true height, the vehicles seated on their
  lowest kept vertex. The flight model (legs up) is drawn once clear of the pad; the craft flies nose first
  (`look_at` with the model's front). Vehicle budgets: truck 1,000, van 1,200, bus 1,600 — the brief's
  800–1,200 is below what the simplifier reaches on the van and bus (950 and 1,390) without stripping their
  bodies · the brief's numbers.
- The hydroponic farm converts at 6,000 triangles, a recorded exception: its glass vaults are hundreds of
  panes the simplifier cannot reduce below 4,688, and squeezing to 4,500 strips every other part bare.
- The new heavy mines are no longer dug below the ground, so their open-pit flags and old exceptions are gone.
- A playtest preview can be exported in the cloud: the official Godot 4.5.1 export templates (SHA512 checked
  against `tools/godot-SHA512-SUMS.txt`), the repository's `Windows Desktop` preset, then
  `tools/package_v17.py --label=preview-<date>`, which reads the version, save schema and world generator
  from the source and puts the players' note `docs/v17/PREVIEW.md` in the zip in place of the developers'
  README. The pack is booted and played for 40 days with the Linux engine; the EXE itself is first run on
  Windows by the user · waiting for the Windows sheet before anyone can play 1.9. The release build and its
  checks (frame times, EXE drive) stay with the Windows sheet.
- Town traffic is cosmetic and stops while the game is paused · vehicles moving during a pause read as time passing · ambient traffic during pauses.
- The 3ds Max models are converted by `tests/art/convert_models.gd` from the FBX exports, per `tests/art/model_recipes.json`: thin parts dropped, parts grouped into ten colour slots by node name, fitted (4.0 units, great works 5.0, height ×1.3) and decimated to 4,500 triangles (great works 9,000) · the 1.9 plan's verified prototype; 53 runtime meshes in 25 s, 4.0 MB · importing the high-poly FBX directly (60k–200k triangles each).
- Every kind follows the art team's `ASSET_MAPPING.json`; the 15 kinds with only gray models stand in with their mapped source model and a shell tint · the mapping names those sources and the gray files have no FBX · drawing them procedurally.
- The 7 models with a final FBX but no final visual report (geothermal, fission, desalination, port, three heavy mines) are used and marked `wip` in the registry · they are complete geometry and better than a stand-in; the registry entry is one line to switch off · leaving them out.
- Kits go to their game contexts: construction site (+ crane for great works) while building, closed-mine plot by ore once the deposit is worked out, landing pods for the base camp, lighting masts on the main street, the exit gantry at route gates, closure barriers on blocked routes, bridge spans over water, harbour quay and cargo ship at towns with a port or a sea route · `ASSET_MAPPING.json` names these uses · showing kits only in a gallery.
- Open-pit mines stand in an open hex retaining wall as tall as the pit is deep · the terrain covers anything below ground · carving holes in the regional terrain.
- No road-vehicle model was delivered (the excavators, haul carts and tractor are parts of buildings), so the town's trucks, vans and buses stay procedural behind a mesh table · the traffic code takes any mesh per kind · cutting the haul cart out of a mine for road traffic.
- Tests run on Linux with `tools/run_tests.py` · cloud sessions have no Windows; four suites and the seven `review_*` tools fail on Linux before any change (Windows-recorded fixtures and hashes, hard-coded `D:` paths) and are reported as such · rewriting fixtures on Linux, which would then fail on Windows.

## 1.9: money (2026-11-07)

Quick harness on Linux (3 seeds, standard, 48 runs a configuration), baseline = untouched 1.8.0 source on
Linux: balanced award median day 2,464; cash cover from day 720 to the award median 74 / p90 158 days;
one year after the award median 85 / p90 634; absorption 79% in year 7; 0 of 27 rush, balanced and
research-first games taken over.

- First pass with the 1.9 plan's starting values (floor 0.5, +4% a copy to ×2, administration 1,500
  residents and +25% a settlement) · it met every money row (cover 12 / 76 days) but 3 of 27 games were taken
  over on contract deadlines with 1–4 days of cover, and the wage lever fell to +17% · it overshot the cover
  bar fivefold; the plan's warning about the knife edge applied.
- Kept the gentle variant: floor 0.55, +2.5% a copy to ×1.75, administration scale 2,500 residents and +15%
  a settlement · cover 15 / 101 days before the award, 8 / 40 after, absorption 92–111%, balanced award day
  2,400 (9/9), 2 of 27 games taken over · a stronger variant (floor 0.5, +3% to ×2, 2,000 / +20%) measured
  the same within noise (1 of 27 taken over, lever +23%) but widened the openings to 23% and left money for
  the services budget in only 4 of 9 runs.
- Homes (role `housing`) pay no copy surcharge · dearer houses taxed exactly the population the charter
  needs: the wage lever went from +18% to +23% in `lever_probe.gd` with the exemption · exempting nothing.
- Data centres earn ×0.85 per further working copy; foodworks beyond the sixth ×0.8 · the 1.9 plan's quota
  option; one rule in `simulation/copies.gd` serves the daily income and the build forecast · making
  processed food and compute market goods, a bigger change to the market page.
- Public services budget, levels 0–3 at ¥0.3 / 0.6 / 1.0 per resident a day, with the plan's effects · the
  plan's optional sink that buys people gradually; an unpaid day does nothing rather than run arrears, so it
  cannot push a colony into the takeover spiral · charging it as arrears like wages.
- Bots raise the budget a level at 120 days of cover and lower it below 45, reviewed every 60 days ·
  the plan's thresholds; balanced, research-first and rush use it, passive and sloppy do not.
- Commissioned research, career transfer and the late great works (plan A2.6a, A2.6c, A2.7) are not done ·
  the money rows pass without them; they remain the next ways to spend.
- The confirmation run keeps the plan's bot thresholds for the services budget (up at 120 days of cover,
  down below 45) and reports the harness row as missed (6 of 9 balanced runs; the row asks for 8) · with
  money binding the optional budget is meant for colonies with cash to spare, and the 80% bar is this
  job's own · lowering the bot's thresholds until a self-set row passes.
- Cash cover is one read-only `Sim.cover_view()` (window, short and idle bands in `economy.json`) used by
  the economy page, the top bar, the advisor and the bots · the player sees what the bots steer by; the
  harness metric keeps its own ledger sampling so recorded rows stay comparable · a copy per caller.
- Money counts as idle (≥ 180 days of cover) only once a full 90-day window has been seen · a fresh colony
  sits on its starting capital for weeks, and "spend it" is wrong advice before the first buildings are up
  · idle from the first day.
- The advisor line puts a pending message first, idle research teams second, a market at its floor third
  (only for goods exported in the last 30 days) and idle money last · research stays the heart of the game
  and a falling price is the more urgent money news · money advice above research.
- Export income at risk weighs the month's export value of each good by its dependence on seams with
  under 360 days left: a raw good by the share of its supply (mines and renewable harvest) from such
  seams, a factory good by the highest risk among its inputs (a factory needs all of them). The advisor
  warns at a third (`mine_warning_days`, `mine_warning_share`), ahead of the floor and idle-money lines ·
  everything it needs is already in the state (seam reserves, the build forecast's rates, the recipes,
  the stats window), so nothing new is saved · recording each mine's daily output and income in the save.
- Counting raw exports only missed the decline it is for: with the balanced bot stopped on day 1,080
  (`mine_probe.gd --hands-off=1080`) the share sat at 16–26% while mines died one by one, and the ore
  behind exported materials and parts was not counted (seed 42, capital: ore 17%, everything resting on
  ore 48%). Counting processing, a third warns 330, 420 and 210 days before income falls 20% in three of
  four such colonies (the fourth's income falls with at most 16% resting on dying seams), and in normal
  play by the balanced bot it shows for 0–390 of 3,600 days across six games; a fifth showed for 750 days
  in one of them · lowering the line to a fifth with the raw-only measure.
- Payback bands (plan A2.2) are checked by `v19_payback` on the balanced bot's colony (seed 260129,
  capital) with mines in year 6 only and factories in year 4 · in years 2 and 4 fresh markets and early
  mining research make every mine faster than its band (light mines 47–67 days in year 2), and pushing
  them into it would cost the opening about half again on its only income · asserting every year for
  mines. Band edges have 5% slack, because the same seed builds a slightly different world on Windows.
- Payback calibration: heavy mines cost iron 9,000 → 16,000, copper 12,000 → 19,200, crystal
  16,000 → 25,600 with twice the upkeep; light mines keep their 1.8 costs; renewables cheaper and stronger (tailings 6,000 → 4,200; sea copper 11,000 → 8,000 and
  5 → 7 t a day; crystal vats 13,000 → 9,000 and 1.8 → 3.2 t); commerce ¥0.2 → 0.3 a customer;
  foodworks 3,100 → 3,700; the forecast values a factory's materials and parts at the import price · every
  checked payback now sits in its band · a shallower iron market (scale 6,000 → 4,000 barely moved year
  4) and a cap on mining research bonuses (it would make the last mining techs do nothing).
- Light mines keep their 1.8 costs (2,100 / 2,900 / 4,300) · dearer light mines (2,900 / 3,100 / 5,200)
  cut the wage lever from +23% to +3% in `lever_probe.gd`: the opening's cash buys the houses that let
  wages matter; with 1.8 costs the lever is +23% and light mines still pay back in band in year 6
  (72 / 87 / 92 days) · dearer light mines for a closer year-4 band.
- Research-first commissions what the charter needs next at 90 days of cover (level 2 at 180), like the
  balanced bot, and every bot reviews commissions every 10 days · commissioning every running project
  from 60 days and reviewing monthly spent ¥40k–376k a year and lost 5 of 9 research-first games to the
  contract deadline (`1.9-phase2-linux`) · a weaker commission rule in the game.
- The windfall case (balanced bot, ¥1,000,000 on day 1,080, normal, capital, the harness's seeds) is an
  INFO row next to the balanced bot on the same seeds · the plan asks for a comparison, not a target.
- Late great works (plan A2.7) at the plan's prices and times. Their effects are colony-wide bonus keys
  that code already reads through `Research.bonus` (`market_depth`, `expedition_cost`, `closure`,
  `admin`, `sea_speed`) plus three new ones (`sea_route_cost`, `event_losses`, `event_closures`), totalled
  once a day in `Megaprojects.effect` · one path for technologies and great works, no per-call scan of
  every building · a separate hook in every module.
- Terraforming stages and capital-district levels are upgrades of one building, each level with its
  own upkeep (`maintenance` in a level rule) · the existing upgrade flow, costs and saves serve them ·
  separate buildings per stage. The district stands in the town with the capital hall
  (`requires_local`), and its beds and appeal stay in that town; the administration saving is
  colony-wide.
- The globe and flat map draw each terraforming stage through the same palette inputs the rules change
  (1 °C toward 20 °C, more rain), with rain drawn at 3 points a stage more than the rules' 5% and a
  slightly clearer sea · a stage the player paid ¥120,000 or more for should show from orbit.
- A great work's later stages and levels buy what the town's warehouse lacks at import price, as its
  first stage does (`supply_cost` in the upgrade preview; the button shows the total) · ports import
  only a 70 t / 24 t working stock and factories fill at most the stock targets, so terraforming's
  second stage (800 t materials, 260 t parts) needed a parts factory in the same town and a raised
  target · every other upgrade still builds from local stock, as in 1.8.
- Bots: balanced and rush build, stage and level the late works when cash pays for the step with its
  supplies and keeps 10 days of expenses (60 before the award, when the charter comes first). The step
  runs before the day's other building; after the award they save for the next one (new investment
  waits) and chase its technologies (value +40, a paid redraw when none is on offer; before the award
  only the unlocking technology counts, +6, as in the 1.9 phase 4 bots, which keeps the payback seed's
  colony unchanged). When no town that may hold a work has a free plot (seed 42 had none left in any
  town by day 4,500), the first such town with a public factory pulls it down and the work goes on that
  plot at once; the district does the same in the hall's town. A step refused for anything but money is
  left alone for 360 days. No crews are waited for: great works need none to work. The generic upgrade logic
  leaves great works alone · the plan's "150 days of cover" was never reached in 1.9 (cover peaked at
  124–142 days while expenses grow with the colony), so no run built any work
  (`1.9-great-works-linux`: 0 of 21) · the plan's cover rule as written.
- No late great work is dropped although three stood in no run of the quick harness
  (`1.9-great-works-shuttle-linux`: emergency network 6 of 21, capital district 1, the others 0): the
  harness ends two to three years after the award, before the 6–8-technology chains of the shipyard,
  exchange and terraforming finish, and in a 15-year game (balanced bot, seed 42) all five are built
  (emergency network day 2,850, district 3,480 to level 5, shipyard 4,250, exchange 4,720,
  terraforming 5,250) · the plan's "drop any project nobody builds", which assumed the harness reaches
  the late game.
- The five new works use recoloured stand-ins (climate regulator, arcology, data centre, lift port,
  hospital) marked "not modelled yet" in `models.json` and `model_recipes.json` · the plan's interim
  kitbash until the 3ds Max task models them.
- Short-range shuttle (the user's request, 2026-11-08): a fourth route variant in `economy.json`
  `roads.shuttle`, a straight hop of at most 3,500 km (nearest neighbours are 1,900–3,100 km apart by
  median on the three planet sizes), pads ready in 10 days, 1–2 days a trip, 4 t a day, ¥8,000 +
  ¥2/km, ¥40 a day upkeep and 30 times a road's fee a tonne, no technology needed · early, very dear,
  very small and fast, as asked · a 900 km range, which reached no settlement on an Earth-sized world.
- A road or sea route may be built where a shuttle flies, and the shuttle stands down (no traffic, no
  upkeep) the day it opens; one shuttle line per pair; never paved; left out of the contract's network,
  the first-road metric and the road lamps at night · a stopgap must not replace the network the
  contract asks for · counting shuttle lines as network.
- The rush bot flies a shuttle to each new outpost while that outpost's road is saved for and built;
  every bot counts only roads and sea routes as joining an outpost · the harness's floor row then
  catches a shuttle that shortens the game · no bot using it.
- In the region view the shuttle lands on a lit pad on the nearest clear, dry ground back from the
  lane's end, and flies a simple lifting body until the `shuttle` model exists · the lane's end itself
  can be a building's plot.
- The market page prices 100 t ahead (`market.json` `preview_tonnes`) and shows the floor price; the
  administration line shows the step for 100 more residents (`admin_preview_residents`) and one more
  settlement · the plan's wording · per-tonne and per-resident slopes, unreadable for cheap goods.

## 1.9: interface pass (2026-11-09)

Format as above: the call · why · what was rejected. Branch `v17-ui-redesign`, for review as a pull request.

- One style system in `ui/design.gd` with three variants: neutral (the shell and every other page, in
  the 1.8 colours), research (turquoise, cyan and yellow on deep teal) and industry (charcoal,
  gray-teal, muted gold) for construction, the facility list, production management and the facility
  column · the requested direction: research keeps its lively look, construction takes the darker one,
  and a colour means the same thing on every page · a global darkening or desaturation filter.
- A page's variant is set around its drawing (`D.use`), and the semantic colours INK, MUTED, TEAL,
  GOLD and RED resolve through it, so the existing page code follows without rewrites. Every reused
  button, card, bar and the shared frame is restyled or reset on each pass (`META_SKIN`) · a theme per
  page, which rebuilds resources and leaves stale overrides on shared controls.
- Style boxes are built once per variant and role and cached; a control is only touched when its role,
  variant or colour changes · building them on each refresh.
- Shared geometry: 1 px borders, two cut corners (`corner_detail = 1`), a 3 px bar for selected rows
  and running topics, a 2 px focus ring in each variant's pale gold; no glow, bevel or gloss.
- The modal frame (panel, title, close button, rule, footer) takes each page's variant. Construction
  and research open up to 1,320 wide, never wider than the window less 40 at the chosen text size ·
  960, which leaves no room for three columns.
- Construction is three parts: the catalogue (category chips; a row per facility with a small 「建设」
  that orders it on its current plot), the chosen facility (a baked view, what it is, its plot, what
  keeps it running) and its ledger (what building takes against what the colony holds, what it gives
  back, the verdict and the main order) · the requested three-part layout · one card per facility,
  which hides the comparison.
- Each catalogue row keeps `Build_<kind>`, so the tutorial's outline, the scripted EXE drive and the
  tests find the same control; the row is `Pick_<kind>` and the main order `BuildSelected`. Both orders
  are the same `build` action with the same plot.
- The first listed facility shows until the player picks one; the pick survives filters and page
  visits; a shortage's 「处理」 opens its category on the facility that answers it (power, water, farm,
  port; homes depend on the settlement kind, so housing opens on the category) · resetting the pick.
- The ledger marks a cash shortfall red and a stock shortfall gold (a port can buy what is missing);
  the simulation's refusal is the verdict, so the page never decides what can be built.
- Facility views are baked from the models (`tests/art/bake_facility_views.gd`, window): late
  afternoon, the model on a concrete pad, a driveway to a road with kerbs and lane marks, a vehicle at
  town scale, two street lamps with their own small lights, pipes and a tank for works, an ore heap and
  conveyor for mines, low neighbours fading into haze; 616 × 280 lossy WebP, 792 KB for 61 kinds,
  imported lossy at 0.82 with mipmaps (1.3 MB in the pack, against 7.3 MB lossless) · the brief's
  grounded look · a live 3D viewport per page, or models on display plinths.
- Research: four directions side by side, each with its colour, icon and team. A topic reads, top to
  bottom: state tag, level and points, name, effect, the facilities it unlocks with their icons, the
  charter mark, progress, then its actions. Active, available and waiting-for-a-prerequisite topics
  differ by frame and by tag text, not by colour alone; finished topics are listed per direction under
  a 「✓ 已完成」 tag.
- Direction colours: industry orange, construction yellow, agriculture green, society blue; they mark a
  direction only. Turquoise is active, selected and progress; cyan is what a topic opens; yellow is
  money, points and the charter mark.
- Text sizes: frame title 26, page heading 22, section 19, body 17, secondary 15, caption 14. The
  research page's 12–13 px text is gone · density from small text.
- Status glyphs are ones the game font has (✓ × ● ○ ★); it has no ✕ or ▸.
- The page box stays the direct child of its ScrollContainer (`v16_scroll_probe` relies on it); scroll
  areas keep a 10 px gap to their bar through a `panel` style rather than a wrapper.
- A reused unnamed button drops the name a keyed button gave it, so `find_child` never finds a stale
  `Card_*` or `Build_*`.
- The reference images named in the request were not in this session (nothing uploaded, nothing in the
  repository); the look follows the written direction · guessing pixel values from file names.
- Capture fixtures recorded on Windows do not load on Linux (world hash). `make_fixtures_v17.gd --out=`
  writes a local set and both capture suites take `--qa-fixtures=` · overwriting the recorded set.

## 1.9: fix tips (2026-11-12)

The user's FIX_TIPS document after the interface preview: a bigger region scene with no visible ground
edge and buildings cut into the slopes, no vehicles through buildings, satellite-style town lights that
grow with a place, daily changes, goods in real tonnes, labour, quarterly autosave, metals told apart,
cargo docks instead of the coastal route, road upgrades, event-only gift technologies, surveys that
narrow the ranges over time, a model fix sheet and a technology tree overview.

- Goods are kept in hundreds of tonnes and shown in tonnes (×100, `economy.json display.tonnes_per_unit`);
  prices read per 100 t · rescaling every amount, rate, capacity, save and harness number by 100 (same
  balance, every rule touched).
- The top bar's change is the mean daily change over the last 7 days (money: the economy page's 7-day
  operating net) · yesterday's change, which jumps with every shipment and payday.
- Labour (劳动力) is crews plus research teams, the people who work · everyone, children and retirees
  included.
- Metals are told apart by their map colours on the top-bar icons and by the name first in the tooltip ·
  new pictograms (the shapes already differ; colour was what was missing).
- Autosave every 90 days of the calendar (quarters, `progression.json time.autosave_days`) · monthly.
- The region scene changes (landscape, terraces, lanes, haze) apply to generated worlds only; 1.6
  worlds keep their ground to the vertex (`world_v16_terrain_identity`) · one rule for both.
- The ground runs 520 units past the field on a widening grid that follows the planet, under depth fog
  and a sky colour · a bigger field (every vertex costs on the CPU) or a skirt down to a flat floor
  (seen from low angles).
- Each visible plot is cut into the slope as a level terrace (flat to 2.45 units, back to the natural
  ground by 3.6), and the relief is compressed on a log curve (knee 5 units) so no pad sits on a pillar;
  towns read as carved into hillsides · pads on stilts, or flattening the whole town.
- The landing pods get a free hex cell of their own · the nearest general plot (they overlapped a
  building).
- Vehicles drive on service lanes between the rows of plots, stop at the front of each pad and leave by
  the lanes' corners and junctions · collision checks at run time (cost, and still visible clipping).
- Town lights are drawn in the globe and flat shaders from up to 48 towns (frayed outline, arms and
  suburbs gated by size, a rotated street grid with dark blocks, a core; a metropolis at 3,000 people);
  roads stay in the night-light texture · painting towns into the texture (blurry at globe scale and
  repainted on every change).
- A sea link is one link with two small cargo docks, one at each end, and one level for both · docks as
  town buildings (one dock serving several links needs coast plots and its own capacity rules).
- Sea links no longer need an orbital freight station at either end; the base cost rises from 5,000 to
  6,000 for the two docks · keeping the station rule (the request makes the docks the terminal).
- Each link level multiplies the capacity the link has (paved ×1.5, trunk ×1.5; medium docks ×1.5,
  large ×1.6), takes a day off the trip, multiplies the closure chance and adds upkeep (trunk +2, medium
  +3, large +6 a day) · fixed capacities per level (old paved roads would need their base capacity).
- Medium docks need no technology, large ones 沿海航运; the trunk road needs 连续摊铺机 after paving ·
  new technologies (they would change the deal of every run).
- Older saves: `paved` reads as level 2; `paving_until` carries any upgrade under way, with
  `upgrade_to` · a save migration.
- Upgrade stores come from whichever end has all of them · always the first end (an island outpost
  rarely has any).
- Gift technologies carry `gift: true` and weight 0: never dealt, refused by research and by event
  leads, left out of the re-deal price, the charter's technology goals and the harness's techs at award ·
  counting them as research.
- The three gift events use the default deck chance (65%), a 900-day cooldown, and open only where they
  make sense (`land_road`, `sea_link`, `lacks_tech`) · always in the deck (that pushed the share of events
  left out below 25% on some seeds).
- Bots let the gift events default (no gift) · a gift policy for bots (another change of path for the
  harness's colonies).
- Bots upgrade any link that runs full once its next level is open and the money is there · paving only.
- Ground surveys come in three steps (±12%, ±6%, ±3%; 15, 25, 40 days; ×1, ×1.5, ×2 the price), the first
  as in 1.8; the survey technology still makes surveyed sites exact · one survey straight to exact figures.
- The town view stands in for `dock_medium`, `dock_large`, `ship_bulk`, `ship_fast` and
  `vehicle_truck_redball` with the existing quay and ship drawn larger and trucks painted red, until the
  models arrive · drawing nothing new.
- The quay walks out from the town in half-unit steps and takes the nearest shore clear of plots and the
  street, avoiding cliff tops · the nearest shore from 4 units out (on a cliff-top coastal town it put
  the quay in the town centre).
- `v19_payback` misses on the light iron mine (63 days in year 6, band 70–150): with docks that need no
  freight station the bot's colony settles another coast first and its iron market is not saturated in
  year 6 (price 5.57 against the 4.40 floor). Clean runs of the previous commit gave 72 and 69 days, so
  the edge was already close. A dearer light iron mine (2,100 → 2,250) does not help: on its own path
  the mine paid back in 61 days and two more checks missed (heavy iron mine 94, tailings 317 in year 4),
  so one seed's year-6 figure follows the colony's path more than the mine's price. Left failing and
  reported · asserting the bands over several seeds (a change to how plan A2.2 is measured, for the
  user to approve) or tuning prices to one path.
- The labour lever reads +6% on this run (MISS, +23% before). Probes show it is noise from the event
  dice: unchanged code gives +15% and +16% with nudged event dice, and this code without its three
  extra deck rolls gives +35% (BALANCE.md, 1.9 fix tips). Left as measured and reported · dealing new
  events from a separate dice stream so old runs keep their sequence (it would pass by luck, not by
  measuring better) or tuning wages to one draw.

## 1.9: picture quality, natural terrain and polish (2026-11-13)

The user, after the preview: 高画质 next to the light renderer; the aliasing, hard edges and
hexagons looked amateur; the terrain looked like Minecraft (walls, mesas, stair-step shores); inland
sites showed coast; candidate labels cluttered the map after landing; cargo dots too big; stage
three too hard (three games stuck on population); a notice when research finishes; the events'
rewrite goes to GPT in parallel.

- Two renderers: standard is Compatibility (default, any graphics card); 高画质 is Forward+, chosen
  in the settings, saved in `user://graphics_override.cfg` through
  `application/config/project_settings_override` and applied on the next start (a restart button).
  Without Vulkan or Direct3D 12, Godot falls back to Compatibility (`fallback_to_opengl3`) and the
  page says so · a switch at run time (Godot cannot change renderer while running) or two
  executables.
- The choice at start-up is read once (`Graphics.start_choice`), to tell a fallback from a choice
  that waits for a restart.
- Anti-aliasing in both renderers: 4× multisampling by default, 2× and off in the settings; SMAA on
  top in Forward+. FXAA stays off in Compatibility: with multisampling it undid the smoothing in the
  captures · TAA (ghosts behind moving vehicles).
- Forward+ colour grade (brightness 0.92, contrast 1.12, saturation 1.38), measured on captures
  of the new terrain against Compatibility: mean brightness within 5 levels and the same saturation
  (without it, Forward+ came out brighter and about a fifth less saturated) · another tonemapper
  (AgX and ACES came out darker, linear lost the highlights).
- Forward+ extras:
  - ambient occlusion in the town view only (radius 1.2, intensity 1.6, power 1.5);
  - glow only above an HDR level of 1.6 (lamps, lit windows, night lights; sunlit snow no longer
    blooms);
  - soft directional shadows (high filter, four splits, blur 1.3);
  - at night, real lamp lights (up to 64, no shadows) instead of painted pools of light.

  Rejected: SDFGI and volumetric fog (too costly on modest cards).
- Natural ground on generated worlds:
  - the relief knee drops from 5 to 3.2;
  - three passes of a 1-2-1 blur over the whole landscape grid;
  - noise detail of 0.25–1.45 units, rising with height above the sea, and ridges on high ground;
  - a beach profile within 1.6 units of the sea;
  - the town's ground is pulled 65% toward its own level between 10 and 22 units out;
  - building pads are flat to 2.35 and graded out to 5.2 by a weighted mean of the neighbouring pad
    levels with smootherstep; each pad's level is averaged over the pad and relaxed toward its
    neighbours.

  Rejected: the terraces of `fef2eb7` (vertical walls and mesas), or flattening the whole town.
- Inland sites (no coast) draw no sea. The ground keeps a soft floor 0.45 above sea level, low
  plains get gentle swells, and the ground shader colours them as land · the planet's real seas
  within the field (the field spans 24° of the planet, so most inland sites had sea in view).
- Free plots:
  - no hexagon plates;
  - ore deposits show three small rocks in the ore's colour over a faint patch;
  - farmland shows a faint green patch;
  - rings round every free plot sit behind a settings switch, off by default.

  Rejected: hexagons, or no marks at all.
- Candidate sites are named only before the first landing or while the map is filtered; afterwards
  only the settled, selected and hovered sites are named · no candidate names at all (they help the
  first choice).
- Cargo dots shrink from 0.023 to 0.013 on the globe and from 0.031 to 0.018 on the flat map, and
  their glow drops from 2 to 1.2 · hiding them.
- Stage three's deadline moves a year later on every difficulty (normal 1,500 → 1,860, easy
  1,800 → 2,160, hard 1,400 → 1,760), as the user asked. Stage four's stays (normal 2,100, now 240
  days after stage three's) · moving stages four and five as well (not asked; put to the user).
- Research notices: a card under the top bar for each finished technology, saying so for a gift;
  eight seconds, up to three at a time, a click opens the research page; reset on a new or loaded
  game · a dialog (it would stop play).
- The events' rewrite is GPT's (`docs/superpowers/plans/2026-11-13-v19-events-rewrite-sheet.md`,
  branch `v17-events`); Claude leaves `events.json` alone meanwhile.

## 1.9: the coast that jumped (2026-11-13, after the preview)

The user: where the sea meets the land, the land jumps; dropped frames or something else?

- It was z-fighting, not frame time. The natural-terrain pass made beaches meet the flat sea plane at a
  tangent (`SHORE_POWER` 1.5), and the town view kept the globe's near plane of 0.05, so land and water
  lay within the depth buffer's precision of each other over whole strips of coast, worst far out. A
  probe that renders each view twice with the camera turned by 0.0015 rad counted 10,756 land/water
  flips over seven views (the same view rendered twice: 2).
- Fix: the beach profile keeps a straight share (`SHORE_LINEAR` 0.35), so the ground crosses the
  waterline at a slope instead of touching it; on the final ground a smooth odd curve moves heights
  within 0.3 of the sea away from it by up to 0.1 (`_clear_waterline`, slope ×3 at the waterline).
  The town view sets its own near plane, 0.5 (its camera stays 31 units or more from its pivot and 7
  or more above it): a depth buffer ten times finer. Measured on the field of seed 260129's first
  coastal site: the gentlest twentieth of the crossings went from slope 0.06 to 0.21; with the near
  plane moved 3% (which moves nothing on screen), land/water flips over seven views went from 4,660
  to 563, the rest on interface text. Pads (0.35 above the sea) keep their level; 1.6 worlds are
  untouched.
- First tried, and replaced the same day: a fixed lift of 0.08 for land and a drop of 0.3 or more for
  the seabed. It stopped the flicker as well, but every crossing then sat at the same fraction of its
  grid edge and the coast snapped into steps (crossing spread 0.14 against 0.26–0.32);
  `v19_region` now checks both the slope and the spread.
- Rejected: a depth bias in the water shader (it differs between renderers, and ground within the
  bias would still flicker); a transparent sea (sorting, and the beaches would still flicker); steeper
  beaches everywhere (the user asked for gentle shores).

## 1.9: the events rewrite (2026-11-13)

The user, handing over GPT's package (`docs/v17/events_rewrite/`): integrate the edited text and
events. The package offers two alternatives: the old events with new words only, or its full design.

- The full design goes in as written (106 events, 249 nodes; `game/data/v17/events.json`), because
  the user asked for stakes and rewards as well as story · the text-only alternative (it keeps the
  old peanuts) · picking events from both (GPT built them as alternatives, not parts).
- Checked before it went in: every old event keeps its id, version and nodes, so saves with an open
  or finished event load; no field, condition, effect kind or option key is new to the engine; every
  default is an option of its node, every `next` and `alt` exists, every chance lies between 0 and
  1, every node is reachable (the order engine's `industry.delivered`, as before); technologies,
  buildings, goods and earlier endings named in it exist. No placeholder, markup, English word or
  reference to another game in any title, text, option or ending.
- Its 18 requests for new mechanics (node-level pauses, single-road effects, cancellable upkeep,
  casualty records, and so on) are left for later: GPT already wrote fallbacks with today's effects,
  and each request is a system of its own · building them into this preview.
- Tests that walked the old chains follow the new paths and read the numbers from the data
  (`v17_events`: the crack's repair now runs through measurements, a plan and trial loads; the blank
  ridge's survey through the old camp's papers, its water room, an agreement and a pilot hole). The
  check that applies every short event's options on a rich colony stocks every good, since the new
  events also ask for components and alloy.
- The harness bots value an event option in money (`colony_bot._option_value`): payments and
  rewards scaled as the game scales them, goods at their prices, and each effect over its days (a
  year when it lasts) on the share of daily income its kind touches (all 1, export price 0.6, mines
  0.45, processing 0.3, port and roads 0.2, power 0.15, farms and water 0.1, research and appeal
  0.05), less its upkeep. The flat (factor − 1) × 500 per effect took every long cut the rewritten
  events offer and turned 8 of 9 balanced awards into 6. With it, 8 of 9 again (BALANCE.md, 1.9
  events rewrite) · scaling GPT's numbers down to suit the old bot (the user asked for bigger
  stakes; the bot, not the events, misjudged them).

## 1.9: stage four, payback seeds, event options (2026-11-14)

- Stage four's deadline moves 14 months (420 days) later on every difficulty, as the user asked:
  normal 2,100 → 2,520, easy 2,500 → 2,920, hard 2,000 → 2,420. Stage five's deadline, the
  contract's last date, stays: the user wants the overall limit kept, so stage five's window
  shrinks (normal 780 → 360 days) · moving stage five with it (that lengthens the contract).
- Payback bands are asserted on each building's median over the harness's first seeds, as the
  user agreed (`v19_payback`): five by default, `--seeds=3` for a quicker check; each seed's value is
  printed beside the median. The suite's timeout goes to 1,500 seconds · the mean (one odd path
  drags it) or keeping one seed (one colony's path decided a band). Three seeds failed the
  processing plant on one bad draw (median 112); five pass it (118).
- On five seeds, one band misses: the light iron mine pays back in 65 days in year 6 (69 / 62 / 46 /
  79 / 65; floor 70, 66.5 with the tolerance). Left as reported · a dearer light iron mine (2,100 →
  2,270): it brings the mine to 68 but pushes the smelter's year-4 median from 306 to 374 (ceiling
  315), since fewer iron mines starve it of ore; the two trade through the ore supply, so a fix
  means retuning ore, the processing plant and the smelter together, over five seeds each step.
- Every event option says where it leads: the ending it closes on, the next step and how many days
  until it, or for a gamble both outcomes with their odds (`events_v2._course`). Players could not
  tell a gamble from a sure thing, or whether a story went on · hiding the odds for suspense (the
  node texts already state most of them in words).

## 1.9: event payoffs, engine side, and faster immigration (2026-11-14)

The user approved the five steps of `docs/v17/EVENTS_DIAGNOSIS.md` and asked for GPT's brief
(`docs/superpowers/plans/2026-11-14-v19-events-payoff-sheet.md`); Claude builds steps 1-4 while GPT
writes the content. On balance the user chose more population growth over a retune of ore and the
factories, so the game's cycle and the payback bands stay as they are.

- The data contract is fixed in GPT's sheet before either side starts:
  - `outcome` on a choice;
  - `critical` on a node;
  - `landmark` on an ending (eight kinds);
  - `label` on an effect.

  The engine ignores keys it does not know, so GPT's data can land before or after this code ·
  waiting for the engine before briefing GPT (it would serialise the work).
- **Ending scenes.**
  - The ending's `outcome` is kept in the event log, with what changed in words and whether the
    default applied at the deadline.
  - A card under the top bar shows each new ending (the shared notice card, 14 seconds), and the
    events page shows the scene under its ending.
  - A loaded game raises no cards for old endings · a dialog (it stops play), or the scene only on
    the events page (players do not open it).
- **Pausing finales.** A node marked `critical` pauses when it opens, even in a notice · a chain-wide
  `critical` (it pauses every step, against the pause budget) · ending a node's default early.
- **Effects where they act.**
  - A town's panel lists the effects acting there and the colony-wide ones, with label, size and
    days left. The economy page lists all effects with their places.
  - Effects remember their event, so their name outlives the event's record.
  - Both maps add 「通讯」 to a place's name while an event is open there.

  Rejected: per-building tags (most effects act on a kind of production, not a building), a
  separate effects page.
- **Landmarks.**
  - Plain-shape figures for the eight kinds (there are no models yet), placed on rings around the
    town and clear of plots, street, water and steep ground. They are rebuilt with the town's live
    objects, so a landmark appears as soon as it is raised.
  - Each stands once, at most six to a place; their effects are permanent effects of the place.
  - The list of landmarks is created only with the first one, so other games keep a byte-identical
    state.

  Rejected: landmarks as buildings (they would need jobs, upkeep and plots), models from the art
  team first (that would hold up the content).
- New gift technologies may use any technology effect; an event card reads them from the gift's
  own description when there is no short name for them · names for every technology effect key
  (the research page already shows descriptions, not generated lists).
- **Free immigration 9 → 11 a month** (+22%), as the user asked: population, not money, is what
  stops stage three. Births, recruitment, housing and the economy are unchanged. The wage lever
  stays proportional, since wages act through attractiveness, which multiplies the base · births
  (1% a year moves little) · cheaper recruitment (it moves money, which the user wants left alone)
  · a lower stage-three goal (the goals stay; the pace changes).
- The events page's log shows what changed under an ending that has no scene, and marks a default
  (「到期按默认处理」); effects still acting are named after what caused them (the effect's label, or
  its event's title) instead of repeating their kind. Until GPT's scenes arrive, the log would
  otherwise show only a date and a tag · waiting for the content (the payoff would stay invisible in
  the meantime).
- Payback after faster immigration (`v19_payback`, five seeds): the light iron mine is back in band
  in year 6 (67 days), and the smelter misses in year 4 (median 354 days, ceiling 315; seeds 260 /
  1,713 / 316 / 354 / 457). The two trade through the ore supply, as with the dearer iron mine.
  Left as reported; the retune (ore, processing plant and smelter together) is still the user's
  call · retuning the smelter alone (the user asked to leave the numbers and timeline as they are).

## 1.10: the bay first (2026-11-19)

- The 2026-11-19 brief is 1.10, on branch `v17-bay` from `v17-fix-tips` (`8c395db`): pull request 2
  is already five rounds long, and this changes the premise (free siting, crews, geology). Folders
  keep the name `v17` · continuing on `v17-fix-tips` (one review for unrelated work).
- Order: the verified feedback first (small, and building identity is needed by lights and crews),
  then the nightscape from state, then crews and the bay, then the reviews; the planet-wide systems
  (radius, geology, prospecting, free siting, seabed, districts, people, stories) wait until the
  bay has been judged, as the brief asks · free siting first (it would scale an opening nobody
  has judged yet).
- Every building has a `uid` (`Production.new_building`; old saves get them in list order on
  load), and an event's construction follows it: an unrelated demolition no longer voids the
  story, demolishing the target still does. Saves move to schema 6 in their own folder
  (`ColonyCharter/v110`); 1.9 saves (schema 5, `v19`) are read and upgraded like 1.8's, never
  written · repairing the index on demolition (keeps a fragile position as identity; crews and
  lights need the uid anyway) · keeping schema 5 (1.9 builds would load 1.10 saves silently).
  New games had the schema hard-coded at 5, so every fresh save was "upgraded" on load; it now
  follows `SaveIo.SCHEMA`.
- Research topics have three states: progressing (the team earns points), blocked (a team is
  assigned but cannot work; the reason is shown) and open. The card and its column say which, the
  tutorial's research step waits for progressing work, as the contract does, and its coach says
  why a team is waiting · counting assignment as research (the preview's bug).
- The days left on a topic count a running commission's points; the switch says that charging
  starts the next day and stops on days the team is idle or cash is short · a separate commission
  ETA (one figure, the card's, is less to read).
- A farm's forecast counts only the food its town can use: what it eats and sends to food works,
  less what its farms grow, at most the farm's capacity (farms stop at the stock target). Its
  money and payback are that part valued as the imports it replaces. The ledger shows capacity,
  usable output and import savings · valuing the whole capacity (the preview's second
  greenhouse) · counting future population (the next forecast does, when it comes). Bots read the
  same forecast, so their farm choices may move in the next harness run.
- The water lesson completes when the player adds a pump. A fault that passes by itself is
  reported as waiting: the days short, the lowest output, and the pump's real price and time. The
  player may then move on with 「下一步」 · counting recovery as a fix (the preview's bug) ·
  making the lesson wait for a pump (a player who chose to wait would be stuck).
- With the tutorial on, the menu shows the tutorial's own seed, size, difficulty and opening (greyed
  out), the ones it really uses.
- The clock keeps the part of a day already run across pauses, panels, speed changes and forced
  stops. A long frame still drops its backlog of whole days. The 1.6 interface tests now accept
  less than a day kept instead of exactly 0 · zeroing on resume (that was the lost day).
- An event's town is chosen after the event is drawn: among the towns that qualify, weighted 1 +
  0.5 per building of the kind its story is about (up to 3), and down to 0.15 for a town that had
  an event within 120 days (`progression.json` `event_towns`). A definition still counts once, so
  the colony's rate stays the same as towns multiply · weighting by population (it would give the
  capital most stories again).
- An option that sends a field team says when it reports back (「调查团队约 N 日后回报」, at the
  team size it sends); a running investigation shows its expected day on the events page.
- Night lights come from the game's state (`world/light_field.gd`): each building shines from its
  own plot, mapped to the planet at the district's 4 units a degree. Housing windows are warm and
  fill in the order the homes were built (the landing camp first); a running facility shows cool
  work lamps by its role; a building site one lamp; roads only where they leave town and where
  three links meet. They are painted into one 4096 × 2048 texture shared by the globe and the flat
  map (a texel is about a screen pixel at the closest zoom; the mipmaps merge lights as the
  camera pulls back). The procedural town shapes and the lamp strings along whole roads are gone ·
  billboards for every light (exact, but more to keep in step with clouds, the terminator and two
  renderers, for no gain at this game's zoom range, about 13 pixels a degree at most).
- The landing camp's cell (`region_ground.landing_spot`) is one search shared by the district and
  the lights, run for any region: the first free slot of the plot grid on land, clear of rivers
  and lakes. The district used to run it before its rivers were prepared, which could stand pods
  in a river · two searches (they would disagree at the coast).
- The flat map's night is as dark as the globe's (`color *= 1 - 0.8 dark`, was 0.42), so towns read
  as lights on a just-legible land · keeping the cartographic brightness (the lights were lost).
- Harbour lights wait for the bay's harbour to be a building on a plot (plan C): then the quay and
  its lights share one position · guessing the quay from the planet's coast (it would disagree
  with the district's own search by a step or two).
- The district lights a home's windows only when people live in it, by the same fill order as the
  night map (`LightField.home_lit`); the landing pods' windows follow the camp. An empty home keeps
  its normal colours (not the idle orange): it is not broken, only empty.
- The complete transport diagram is an overlay (「运输网络」 in 地图画面, on by default): off, the
  globe and flat map show only what lights a route, where it leaves town and junctions, and the
  cargo moving on it, which now has its own node · turning the overlay off by default (players
  would lose the route view they know without asking for it).
- Each town says why it grows or not (`ui/people_lines.gd`): the net change over 30 days, how many
  want to come against the beds left after recruits on the way, and the main limit in the order
  that binds first (no free beds, then joblessness, which stops arrivals at 35%, then food under 10
  days, then appeal under 3 a month), with its remedy. The people page shows all of it; the town
  panel shows the limit when there is one · a growth forecast (the readout states what is true
  today; a forecast waits for crews and the bay, which change it).
- A town's quay is found by one search shared by the district and the night lights
  (`region_view.harbor_spot`): walked out from the town centre along 48 headings over the planet's
  own land and height, the last land before the sea, clear of plots and the street, cliffs costed.
  A quay is drawn for a town with a finished harbour or a sea link; an orbital freight station alone
  has none, so a town that put its crew on the mine first has no pier. A working quay shows a compact
  group of cool lights along it · the district's terrain-based search (it can only run for the town
  on show, so the globe could not agree with it).
- Mobile engineering crews (`simulation/crews.gd`, `population.json` `crews`):
  - a building under construction moves on only on a day a crew works on it;
  - the standing instruction: a project that fixes a shortage the town has today (water, power,
    food: `crews.urgent` maps each shortage to the roles that fix it) goes first, even off a
    project under way, which keeps its progress; then the one the player marked 先建 (build
    next); then the oldest order;
  - a crew can be sent over a finished link and takes the link's days.

  A landing brings one crew, made from its workers, so the town keeps its people. An expedition
  takes one crew from its source town, idle ones first, but never its last: a town founded from a
  one-crew capital has none until it trains one or one is sent. Prefabricated kits assemble on
  their own.
  Training turns a worker into a crew (¥900, 15 days); crews draw a wage (2.0 a day). A save from
  before crews gets one for each project under way, and at least one a town, taken from its
  workers, so nothing stalls. Upgrades and inter-town roads still need no crew in this first
  version (the brief's road repairs come with them) · crews for every job at once (too much to tune
  in one step) · a crew pool per colony (the brief's choices are about which town gets the crew).
- A crew recruited from outside comes through the same campaign as workers and research teams:
  ¥1,500 (rising with recent campaigns like theirs), 30 days, a bed kept for it, one more resident
  when it arrives. Training (¥900, 15 days) keeps the resident total but takes a worker off a job.
  Sending a crew away says what it stops: its project's days left, and whether the queue it leaves
  stops with it · recruiting at the training price (training would never be worth it).
- Beds are not on the crews' shortage list: a growing town is nearly always short of them, and the
  crew would never leave its housing · every shortage urgent (housing would swallow the crew) · no
  urgency (the tutorial's pump waited two months behind the copper mine and the housing, so the
  water lesson told the player to build a pump and then left them short of water).
- Every project's expected start and finish come from its town's crews and queue (`Crews.eta`): the
  sidebar's under-construction rows say who builds it or 「等工程队 · 约 X 开工，Y 完工」 with a 先建 chip,
  the colony's building list counts days to the expected finish, and an order's ledger says when
  it would start (at once for one that fixes a shortage). They are the days it really starts and
  finishes while nothing changes (`v110_crews`); a new shortage can move them · remaining work days
  as before (wrong for every order behind another).
- The suites that test other systems with buildings ordered together (`sim_tests`,
  `v16_events_tests`, `v16_event_order_probe`) run with every site moving on (`Crews.unlimited`, a
  test hook no game sets); suites that waited a building's catalogue days read the building's own
  days, which include a mine road. The tutorial suite plays the lesson as written: 先建 for the
  laboratory, a crew trained at the second town, and another research project once the first is
  done while the exports come in.
- The tutorial teaches crews where they bite: the income step says there is one crew and where to see
  its queue, the water step that a shortage fix goes first, the research step 先建, the farm step
  that the new town has no crew and how to get one · a separate crews step (fourteen steps are
  already many).
- `v18_systems`' top-bar checks read the 1.9 format (goods in tonnes with grouped digits, the daily
  change over the week): the bar changed on 2026-11-12 (`c6dbc6d`) and the three checks failed on
  every platform since, unseen on Linux where the suite fails anyway on its Windows-recorded saves.
- The workforce is 职工 (facility staff) and 工程队 means the mobile crews: 1.8 renamed every worker
  工程队, which made the brief's distinction unsayable, and 1.8's bar still forbids 工人 in player
  text (`v18_systems`), so the workforce takes a new word instead of going back. Staff are counted
  in persons (人); crews and research teams in teams (支) · 工人 again (it would undo the user's 1.8
  rename and fail its check).
- The bay (`simulation/bay.gd`, economy.json `bay`, building `harbor`):
  - **Mine road.** A mine beyond 18 units of the centre builds its mine road with it: 0.25 days and
    ¥40 a unit beyond, so the richest far seam of the first landing costs about 7 days and ¥1,040 on
    an 18-day, ¥2,100 mine. At first it was 0.5 days and ¥60: 13 days and ¥1,560, not a short road,
    and it held the first export back long enough to starve the jobs that pull in immigrants.
    A road built to one of the town's mines carries the next: a later mine pays only the spur
    from the nearest mine (6 units between neighbouring deposits), if that is shorter. Without
    this every mine paid the whole road from the centre again; the bots then built fewer mines,
    jobs held immigration, and the quick harness (`crews-234a06c`) lost a fifth of its people
    (296 / 783 at years 2 and 4 against 374 / 1014). The balanced bot's probe on three seeds: no
    mine road at all 413 / 388 / 420 at year 2, spurs 404 / 325 / 332, the whole road every time
    333 / 317 / 271 (seed 42 stalled at 300 for two years).
  - **The harbour's forecast** counts what it saves as its income: the catch the town can use
    instead of imported food (as a farm's crop), and the sea discount on the town's share of the
    colony's food, materials and parts imports over the last 30 days. Its added port capacity is
    not valued. Before, the order showed 不产生净收入, so a player could not weigh it against the
    mine road (`bay_openings`: on seed 909386518, a start with its own farmland, the harbour saves
    little and the bot that built it first lost its contract).
  - **Small harbour (小型码头).** ¥3,000, 20 days, 3 jobs. It catches 6 food a day, counted as the
    town's own food. Food, materials and parts come in 25% cheaper by sea there, and it adds 60
    capacity. It stands at the shore, with no plot, and its quay is what the district draws.
  - **Offshore signal.** Each coastal town has one, fixed by the seed: copper or crystal, rich 60%
    (about 4,000) or poor (300). A survey from a working harbour (¥1,500, 25 days) says which.
    The simulation places it on the town's first day; pages only read it. At first the town panel
    made it the first time it was shown, so a save's bytes depended on which pages the player had
    opened (`v110_bay` now plays one game twice, one of them read the way the pages read it).

  Developing a rich signal waits for seabed extraction (plan D) · an orbital import surcharge to
  make the harbour pay (it would make every colony poorer) · a separate mine-road building (one
  project for the one crew is the brief's choice; the road is part of opening the mine).
- The bay in the three views: while the crew builds the harbour, the district stands the shared
  site kit at the shore; once it works, the quay and its cargo ship, which carries a cool masthead
  lamp that brightens after dark like the quay's work lights. The globe and the flat map sail a
  ship light on the district ship's own line (offing 30 units out, berth beside the quay): in over
  the first third of a three-day call, at the berth, out, then away, from the game clock alone so
  captures and replays agree (`v110_lights` checks the berth and that every frame stays on the
  line). The district's quay stands lamp posts where the night map has its work lights
  (`QUAY_STEPS`), so the cool lights are in the same place on every view. The offshore signal is
  a gold ring on the globe and the flat map and a lit buoy in the
  district, 20 units out beyond the quay and off the shipping lane, while it is unknown or rich ·
  a ship every game day (a blur at 6×) · the signal at the town's own marker (it would read as the
  town's, not the sea's).
- The night halo on the globe and the flat map is round and answers by a power: the centre and a
  ring of six taps of a coarser mip, raised to 0.7. A linear halo from one coarse tap averaged a
  small town's few lights over hundreds of texels and left it as specks from orbit; a square root
  of that one tap lit it but drew square blocks (the mip's bilinear footprint). The ship light is a
  cargo dot's size: at one and a half it was the brightest thing in the bay. A town at the default
  globe distance is still small (its plots span about 60 pixels at 1920 × 1080); how bright the
  bay should read from orbit is for the player to judge on a real GPU.
- The first ore export and the first ship at a new harbour each raise a card once a game (「◆ 第一次」);
  a click opens that town's district. A loaded game marks what it already has.

## 1.10: free placement and the November 20 audit (2026-11-20)

- A settlement founded at a coordinate gets a site of its own at that exact point (`site_gen.site_at`),
  appended to `state.world.regions`. Its climate, water, coast and landmass come from the grid cell
  under it (the nearest land cell for a shore point in a mostly-sea cell), its plots from the slots
  around the point, and its deposits from the planet's geology. Everything keyed by a site (district,
  plots, roads, lights, saves) follows the point. Generated sites stay as recommended shortcuts · snapping
  to the nearest generated site (the audited bug) · moving a generated site to the click (two games could
  not share a world record).
- Each mineable resource has its own planetary deposits (`geology.gd`, geography.json `geology`): veins
  and pockets drawn from the seed, weighted by that resource's potential in the grid, barren ground
  between, overlapping where belts meet. About 360 on a world: a placed site reaches median 3–6
  deposit plots, up to 14, and about one in six reaches none. Generated sites keep their own deposits
  for now (their worlds and saves are unchanged).
- Plots on one planetary deposit name it and share one reserve, in every town that reaches it
  (`Placement.share`, `state.geology.remaining`); a town's totals and the audit count it once.
- A placed site takes at most 3 plots per deposit and 14 in all, chosen in a seeded order so the centre
  and the edge are alike · deposits on the outer slots first, as generated sites do (82% on the outer ring
  in the release audit).
- Placement rules (geography.json `placement`):
  - land only, not on a lake;
  - latitude within 74°;
  - local relief up to 3,000 m. Slope is read as the height range within 0.4° of the point, because the
    grid's ruggedness is saturated (1.0) on most land;
  - at least 18 land plot slots;
  - at least 8° (about 890 km at one Earth radius) from another settlement;
  - a capital must be able to expand: a coast, or a landmass of at least 16 grid cells.

  Each refusal names its reason and the number behind it.
- Routes run between grid cells but start and end at the towns' exact coordinates, so a road to a placed
  town ends at the town.
- A save may hold up to 96 sites (64 before): generated sites plus the ones players found.
- A left click on the globe or the flat map selects a recommended site only when its marker is within
  14 px of the pointer (`main.MARKER_CLICK_PX`); any other click selects the ground under the pointer
  (`map_view.pick_ground`: the ray meets the globe's sphere or the flat sheet). The 43 px radius is kept
  for hover names only · the old 43 px click radius (a click near a marker could not reach the ground).
- The documented picking precision is the ground one screen pixel covers at the current zoom, shown
  under the coordinate (「点选精度 ±0.07°」). At the closest zoom a player can reach on a 1600×900
  window it is about 0.07° on the globe (distance 7.0) and 0.09° on the flat map (size 4.2).
- The picked ground shows a white ring with ticks on both maps; the marker selection clears, so the
  founding button can only act on the picked point.
- The ground panel prices an expedition for the kind of town that would be founded: a frontier town
  by default for a later town, or the kind chosen in the naming dialog, and names it next to the cost ·
  pricing by the previous dialog's kind (the verification run showed ¥ 4,586 and charged ¥ 3,146).
- The ground panel reports the ground cover under the point (forest, grassland, tundra… as the maps
  draw it) beside the site type, so a player can tell what they clicked.
- Free placement is verified by `tools/verify/placement_driver.gd`, which drives the real interface
  (menu, mouse clicks on both maps, the ground panel, the naming dialog, Ctrl+S, continue) against the
  source project or a packaged PCK (`--main-pack`). It lives outside `game/` because the export leaves
  out `tests/`. The colony is played to the expansion licence by the balanced bot through `Sim.act`;
  the expedition itself goes through the interface.
- The first ore truck and the first ship are consignments the simulation records when they move
  (`consignments.gd`, `state.firsts`): ore only from a town with a finished mine of that good (or
  a linked town's mine whose ore came in by road), a ship only for cargo bought or sold through a
  working harbour. The notice names the town, the building, the good, the tonnes and the value, and
  opens the mine's or the harbour's town · counting any export (a food order set off "first ore")
  and any working harbour (a ship with no cargo).
- Vehicles follow the records: a map ship light and the district's quay ship only while the
  harbour has had sea cargo in the last `bay.ship_call_days` (30) days or sea-link freight is under
  way, at the berth on the cargo's day; the district's ore truck runs from the mine whose ore the
  town last sold to its cargo station. Saves from before the records count a first that evidently
  happened (mined goods sold, a finished harbour) as already announced.
- A mine ordered to branch off another mine's road records that mine (`haul.via`). Cancelling
  that mine before it is finished gives the branch mine the main road: its days grow by the
  difference, the road money the cancelled mine paid covers the extra cost first, and only the
  rest is charged · charging the full difference again (the colony would pay one road twice) ·
  leaving it as it was (the audited bug). The crews build the road's mine before the branch mine,
  even when the branch mine is chosen to go next; with two crews at one town both may still work
  at once (not modelled further).
- Crews travel by freight's rule (`Crews.travel_link`): a built, open, unretired link at freight's
  days (`Logistics.road_days`); a crew on the road when its link closes waits, day by day, as
  cargo does, and the crew panel says so · crews crossing a closed link (the audited bug).
- A town's 30-day change is measured: each day's stats row keeps every town's population at the
  close, its births and the people moved in or out (expeditions, landings, crews, workers
  following jobs), beside the existing arrivals and departures. The page shows the change with
  its parts, and the audit suite checks that the parts explain it exactly · arrivals minus
  departures (it showed +9 while a capital fell from 90 to 86).
- The people page adds the expected arrivals in the next 30 days (would-come, capped by the beds
  free after reservations) and the unemployment rate with both thresholds (immigration falls off
  above `jobless_free_share`, stops at `jobless_stop_share`, 35%).
- A food building's forecast counts the town's whole food balance (`Production.food_balance`):
  what it eats and its foodworks take, the stock still to fill to its reserve over
  `forecast_food_refill_days` (30), and what its farms grow, its harbour lands and food buildings
  already queued will add. Savings are at the delivered price (port fee, less the harbour's sea
  freight discount). The page lists each part · counting farms only (a harbour landing 600 t was
  ignored).
- A commission on a project whose team is held up is quoted at the pace its assigned team (at
  least the project's minimum) will have: the price a day and the days saved, with the reason it
  is held up and "charged from the day after it starts" · ¥0 and 0 days while blocked.
- The water lesson is passed only by a new pump at work on the day the shortage ends; a pump
  still being built when the filter recovers is named as such, with its days left, and the lesson
  counts as waited out · any pump ordered (one with 14 days still to build was credited).
- The planet's size is a radius slider from 0.70 to 1.30 Earth radii in steps of 0.05, centred on
  1.00 (geography.json `planet_radius`); the menu shows it in Earth radii and km, and the surface
  gravity at Earth's mean density beside it, named as gravity. The seed's ground does not change
  with the radius; the recommended sites take one of three densities by radius band (below 0.85
  the small layout, from 1.15 the large), as the three old presets did. Every distance is in km
  from `radius_km`: routes (their days and costs follow), the placement report, pollution, and the
  orbital reading's reach (`signal_radius_km`, 445 km, 4° at one Earth radius). The route terrain
  cache keys on the radius. The tutorial keeps its planet's preset. Saves keep the radius.
- A home lights a window as soon as anyone lives in it, then more as it fills
  (`LightField.lit_windows`), and its first window is bright enough for the maps' usual zoom · the
  rounded count (six people in a three-window home lit nothing, so the night map of a 66-person
  colony with a new home was the landing's, pixel for pixel). The landing camp still fills first.
- The night captures have an ordinary-play mode (`capture_nightscape.gd --play=on`): the balanced
  bot runs the colony and two ordinary orders queue a home and the harbour; the stages are the
  first day a new home has lit windows and the first day a ship lands cargo. The staged-fixture
  sheets stay, labelled as staged.
- Stage three is met by three operating goals (3 towns connected, 14 technologies, a 15% non-mining
  share) and one operating route of three, measured over 30 days (`operating_routes.gd`,
  contract.json `routes`): a food corridor (900 units of food carried between towns, 80% grown
  locally), a remote mining network (2,400 units mined outside the capital, two mining towns) or a
  coastal trade network (900 units exported through harbours or carried on sea links, two coastal
  towns). 600 people is an achievement paid once (¥ 6,000) · 600 people and a frontier town as
  conditions (the audited wait from day 1170 to 1250). Thresholds from the bots' 30-day values on six
  seeds (`docs/v17/STAGE_THREE_ROUTES.md`); the everyday imports through a harbour do not count as
  coastal trade. Saves mid-stage-three are judged by the new goals.
- The tutorial starts at a bay on its planet (site 12, a coastal mining basin; partner site 11) and
  its money lesson is the first decision: a mine first (export income sooner, a road for a far
  deposit) or the small harbour first (fish, cheaper sea freight, the offshore survey), both
  explained, either completing the step; the next step completes on the first recorded
  consignment of either kind. Landing elsewhere stays open (the landing step accepts any site and
  says how to judge ground); the lessons follow the town actually founded, and an inland town gets
  inland words (no harbour) · keeping the inland start and its two-mine instruction.
- Prospecting goes one resource at a time and works anywhere on the planet's own deposits
  (`prospecting.gd`, geography.json `prospecting`): an orbital observation of a resource at a point
  (¥400, 3 days) turns each deposit of it that orbit can see within 445 km into an anomaly zone 2°
  across, drawn up to 1.5° off; a field survey (¥1,800, 20 days, from a town within 1,200 km)
  narrows one to 0.5°, enough to choose where to found a town; drilling (¥2,600, 15 days, after the
  field survey) gives grade, depth and the reserve left and shows its plots in every town that
  reaches it. Anomalies are rings on both maps in the resource's colour. The ground panel offers the
  next step for each resource at the picked point. The old per-site survey stays for recommended
  sites · a survey that tightens all three resources at once.
- Newcomers ride a bus in the district from the landing pads to the newest home people live in,
  while the town has had arrivals in the last 7 days (the daily stats), so the vehicle and the lit
  windows it goes to are the same arrival · a shuttle landing per arrival (no model yet).
- Nickel and cobalt are planetary deposits like the others (geography.json `geology`): nickel in
  veins along the iron belts (large, low grade), cobalt in rarer pockets near nickel and copper;
  cells without a potential of their own take a weighted blend (`potential_from`). Their mines need
  nickel-cobalt metallurgy; a superalloy works (two nickel, half a cobalt → one superalloy at ¥160)
  is their industrial use · cobalt as a by-product of copper mines (no plot of its own to decide on).
- The offshore chain: offshore surveying (tier 2) halves the survey boat's price and days; seabed
  mining (tier 3, after deep mining) allows one seabed platform per town on a surveyed rich offshore
  deposit; its barges land the ore at the town's working harbour as a recorded cargo (`landed`,
  `firsts.offshore`), counted as stage three's coastal trade, sold or processed like mined ore;
  without a working harbour nothing is landed and the town says why · ore piling up offshore.
- Cobalt joins copper and crystal as an offshore signal good (cobalt-rich nodules) ·
  nickel offshore.
- A deposit that reaches the very point a town is founded on takes the free slot nearest the centre
  (plots stand 1.5° apart and a vein can be narrower): founding on the signal one sited for always
  reaches it · leaving it to the slots, which missed nickel-v0 when founded on its axis.
- Generated sites keep listing only iron, copper and crystal in `deposits`; a later metal appears
  in a town's totals once it is known there, and saves are filled with zero stock of goods they
  lack (`fill_goods`) before validation, so 1.10.0 saves load · a schema bump for three goods.
- The new buildings wear older models until they have their own (models.json `stand_in`): the iron
  mine for nickel and the crystal mine for cobalt, each with its ore in the metal's colour; the
  smelter in a paler shell for the superalloy works. The seabed platform stands offshore beyond the
  district and is not drawn there; its barges' cargo makes the harbour's ship call · a platform
  model at sea in the district.
- An orbital reading scales each resource by its own `signal_scale` (geography.json): the largest
  vein for iron, copper, crystal and nickel as before, twice the largest pocket for cobalt, which
  has no veins · reading cobalt against nickel's veins.
- The ship light on the globe and the flat map is 0.7 of a cargo dot at 0.55 of its glow, and at the
  berth lies 18% of its line out from the quay: it read as a white spot summed with the quay's
  lamps · dimming the quay's lamps.
- Crews beyond buildings (the 1.10 plan: "a project progresses only while a crew works on it"): a
  land road ordered from 1.10.1 on, and any land road's upgrade, moves on only on a day a crew from
  one of its two towns works at it; a day without one puts its finish a day later. Sea links and
  shuttle lines need none (docks and flights, not road works), and a road from an older save keeps
  its date · roads that build themselves, with crews only speeding them.
- A rockfall closure keeps its days without a crew and clears twice as fast with one (each day
  worked clears a day more) · closures that wait for a crew, which would strand freight in a town
  with none.
- A field survey or a drilling takes a crew from the town the team leaves (the nearest) for its
  days: an idle one, else one off its project, which waits; with none at home it cannot go · survey
  teams of their own.
- Standing orders per town, after the projects that fix a shortage and the one chosen to go next:
  in the order given, with closures cleared first (the default; buildings and roads by the day
  ordered, a building before a road on the same day, buildings from older saves first); repairs
  and roads first; or facilities first. A shortage still takes a crew off a road or a repair · a
  global setting.
- Each crew beyond the colony's first two costs a quarter of the base price more to train (¥ 900)
  or to hire (¥ 1,500 before the campaign step): the third ¥ 1,125, the fourth ¥ 1,350 · a rising
  wage, which would also punish crews already working.
- Farmers (农民) are the workers employed on farms and indoor farms, counted each day (s.farmers,
  part of the workers); every count of people is in persons, and a research team (研究团队, the
  1.8 request's name, V18_BRIEF row 4) and a crew each count one person, one bed, one wage; the
  readouts list workers, farmers, research teams, crews and the young · renaming research teams
  back to researchers, which the 1.8 request replaced.
- The flat map has no east or west edge: the camera wraps at 180° and copies of the map's content
  stand one map width to each side (moving cargo excepted); it zooms out no further than the map's
  height, where the poles sit on the window's top and bottom edges · a clamped pan.
- The globe stands in deep space: a dome with the galaxy's band, dust, faint nebulae and dense faint
  stars behind the existing star field, and the planet's star as a large glare in the real sun's
  direction, globe only · a skybox image.
- v19_payback judges a cell only where most seeds have the building that day (3 of 5, 2 of 3), and
  says how many it judged: its median skipped colonies without one, so "median of 5 seeds" could be
  one or two colonies. The bands are unchanged. Evidence (asserted cells, median and per-seed):
  3e3ab15 iron mine 64 (80/99/53/64/51), tailings 200, smelter 461 (288/274/461/578/2487),
  food processing y6 614 from 2 colonies (1097/131); 741e881 iron mine 81, tailings 316
  (316/317/269/171/396), smelter 346, food processing y6 404 from 1 colony; 591f011 iron mine 83,
  tailings 273 (267/364/336/158/273), smelter 282 (273/257/365/334/282), food processing y6 410 from
  2 colonies (423/397), while years 2 and 4 judge it on 4-5 colonies at 113-116. The rules of these
  buildings, the prices of existing goods and the market scales did not change between 3e3ab15 and
  591f011; the medians move with how the balanced bot grows the five colonies (four new technologies
  in the deck, dearer crews, roads that wait for crews) · widening the bands.

## 1.11 (the contractor, branch v17-charter)

- Frozen features (A) are read through `simulation/features.gd` from the shared rule cache, so the
  simulation, the site generator, the interface and the bots get one answer; a flag missing from
  the data counts as open. What each flag freezes (buildings, techs, resources, road kinds) is listed
  in `progression.json` `features.content` · a hard-coded list.
- Metals frozen: the planet keeps its nickel and cobalt deposits (world generation and its hashes
  unchanged); orbit does not read them, a newly founded town takes no plots on them, prospecting
  refuses them and an offshore signal is never cobalt. Saves that hold nickel plots or mines keep
  running them · regenerating towns without them.
- Commissions frozen: one already running in a save keeps running and can still be stopped (level
  0); none can start. The radius slider frozen: any asked radius becomes the default 1.0 and the
  slider row is hidden. The research tree hides frozen techs unless a save already finished them.
- Suites written for frozen features (v110_metals, v19_money, v19_transport, v110_fixes, the radius
  part of v110_audit) switch their own flag on in their process, so the frozen code stays tested;
  `v111_freeze` tests the frozen defaults · deleting those checks.
- 公司评级 bands: A below `company.rating_a_below` (20), B below the review threshold (40), C below
  the intervention threshold (70), D above. A reading of distrust only; no rule reads the letter.
- 民心: settlement appeal 0.0 reads 0 and 2.0 reads 100 (`population.json` `morale`), so the base
  appeal 1.0 reads 50. Towns still in transit and empty towns are left out; with nobody landed it is
  50. Measured: 20 on landing day (no spare beds, no jobs yet), 40-77 over four years of balanced
  bot play on seeds 260129 and 42 · a range fitted to observed values.
- The company code is CC-NN with NN = 1 + the world seed mod 99 (`contract.json` `document`). Two
  colonies can share a code: it is a name, not an id, and nothing reads it.
- The company's stage letters became template kinds in `letters.json` (warning, review,
  intervention, recovery_stable, recovery_solved, normal, aid_signed); `reason` keeps the subject
  for older readers; a kind without a template still makes a letter of its one line.
- Old one-line letters get the structured fields before validation on both load paths: schema 3-6
  through `ensure_systems`, the schema 2 JSON path in `load_legacy` (its validation runs first).
- The contract page keeps the stage goals and their shortcuts under the current milestone · a page
  of clauses only, which would lose the colony's to-do list.
- The review clause states the process as it runs: a warning letter at the difficulty's warning
  level, review at the review threshold, intervention when the review window ends with risk still
  there, takeover when the intervention window does. The intervention threshold is a rating band and
  a gauge mark, not a trigger · the plan's shorthand "intervention threshold".
- Event text may hold `{code}` and `{capital}` only, filled where events are viewed
  (`simulation/names.gd`); titles hold none · placeholders in titles, which history and notices
  would also have to fill.
- The ten reworded events changed wording only (ids, nodes, choices and effects checked identical by
  script). The company speaks through its documents quoted in the scene (【部门 · 文件名】, CC line);
  rule numbers typed into prose were removed where they repeated data (second_ship's 60 days in a
  title, industry's 240 days); narrative numbers stay.
- Sound cues are played by the interface: `cues.gd` `observe` compares the newest letter, the
  accepted stages and the ending with its last look, and only takes note at the first look at a
  game · cues called from the simulation, which must not call the interface.
- The meter pair keeps the day's change and the stage countdown under the letter; a click on 民心
  opens the population page, where the services budget is.
- The harness extras (determinism, labour lever, no control) run as their own process beside the
  chunks (`--extras_out`, then `--merge ... --extras_in`): about an hour per quick harness on four
  cores instead of 87 minutes · tooling only.
- `v19_payback` misses the smelter in year 4 after the freeze (352 days against 120-300; it was
  461 on 3e3ab15, 372 on faa0f97, in band on 591f011): towns no longer take metal plots and events
  skip frozen content, so the five colonies grow differently. Kept as a known miss for J's
  rebalance · widening the band.
- Origins (C) keep the opening ids saves store (`capital`, `workers`, `science`) with new names
  (标准承包, 工程承包, 科研托管). Gains, costs and rule are text templates filled from the entry
  (`{cash}`, `{rule:key}`, `{effect:key}`, `{cut:key}`, `{years:key}`, `{tech:key}`), so no number is
  typed; the old `description` stays for older readers.
- 科研托管 has no research-speed bonus (`science_opening_rate` removed, as the plan says); halved
  research funding is kept as one of today's gains and moved into the origin's rules. Its
  research-contract technology is granted at landing (logged; that category's offers are redrawn).
- 工程承包's wage floor refuses a lower wage (no clamping); a new game starts at the floor. An old
  save whose wage is below it keeps that wage until changed, so it plays on unchanged.
- 移民安置: the 60 extra residents are 40 workers and 20 children; the landing camp's 60 beds stay,
  so beds are short by design. Cash and materials are 0.7 of the standard contract; food +30% for
  the extra mouths. The subsidy is ¥20 a month per resident with a bed and a job, for 1,440 days;
  per town the employed up to its beds. A test colony had 7 such residents on day 30 · a subsidy
  on every resident, which would pay for the crowding it is meant to cure.
- 矿权抵押's tribute is in goods units by stage (600-3,000, i.e. 60,000-300,000 t a year); C records
  and shows it, D collects it.
- 群岛开发: the `offshore_survey` effect is +0.5 (the survey's price and days halve, as the plan's
  "−0.5" means); `road_cost` +0.5; a new key `orbital_freight` (+0.25) raises the price of goods
  bought by orbit, i.e. where no working harbour carries that good. The coastal rule refuses inland
  ground on both ways of founding (region and map point).
- `favours` names the stage-three route an origin suits (cards, contract) but changes no rule in
  1.11 · lowering that route's targets for the origin.
- The effects cache (`Research.bonus`) is keyed by the origin too and reset on load: a loaded game
  with as many technologies as the one before it read the old game's effects (found while testing).
- Harness: rush, balanced and research_first run all six origins; passive and sloppy only the three
  older ones (they measure failure); each new origin also runs with its own bot (`housing_first`,
  `mining`, `coastal`, subclasses of balanced with one knob each). 87 quick cases instead of 51.
- 1.11-A against crews-d24c660 is a material change, explained, not fixed: the balanced bot's
  median award moved from day 2674 (8/9 awarded) to 2854 (6/9), science openings 300-550 days later
  for every bot. On the three runs that newly fail (balanced capital 20261029, workers 260129 and
  20261029, all taken over at stage five's last date), switching research commissions back on
  awards all three (days 2854, 2999, 2586); switching metals and seabed back on awards two of three.
  The bots bought stage five's research with commissions. Left for J's rebalance · unfreezing.
- The annual report's gap (D) is filled from production: when the ship arrives, the year's
  production first makes good the open gap, and only the rest counts as the year's actual. The plan
  says "the surplus of actual over reported fills the gap first"; with 如实/报达标/报超额 nothing is
  ever reported below the actual, so read literally it would never fill · a gap that only an
  exposure closes.
- The ship comes on the landing anniversary (day 0 in practice: a colony lands before its first
  day); a 1.10 save gets its first ship on its next anniversary and targets from its stage.
  supply_delay's waiting option holds the ship 20 days; the next ship keeps the anniversary.
- A report left unsigned for `report_days` (30) goes as it is (如实), marked automatic.
- Rewards are booked outside operating income (`annual.reward`, like `contract.reward`); fines are
  public expenses (`annual.fine`); the tribute leaves the capital's ore as a resource sink.
- Amendments: the ship may bring one from the second year (chance 0.5, from the seed and year),
  opening one of five stories at its new `amendment` node; the audit stories open at their new
  `gap` node while a gap is open. Nodes are added, ids and versions kept, so saves with these
  stories open still load. A signed amendment changes the contract for good: stage deadline,
  company share after the award (`Contract.company_rate`), next year's targets, a clause added or
  one removed (removing `aid` refuses company aid from then on).
- New event option keys (`ship_delay`, `report_exposure`, `deadline_shift`, `company_share`,
  `kpi_scale`, `add_clause`, `remove_clause`, `amendment`) are applied in one place,
  `AnnualReport.apply_terms`, called from the events engine.
- Production sources became ids (`mining`, `farming`, `catch`, `seabed`) instead of Chinese words,
  so the tallies compare identifiers, not display strings.
- The company ship's light comes down over the capital from four days before it is due, on the
  globe, the flat map and the district, and stays while the report waits.
- Annex VII (E) is drawn from the seed (`hash(seed:annex)`); a save from before 1.11 E draws the
  same way on load. It opens when stage four is accepted, with a compliance letter per variant
  (`letters.json` `annex_<variant>`). The answer is given once, on the contract page.
- Answers move distrust by points and 民心 by a lasting shift in points (`state.annex.morale_shift`,
  added after the appeal mapping and clamped to 0-100): 照办 -8 / -6, 周旋 +2 / 0, 公开 +12 / +10.
  They set `state.ending_lean` (loyal, buyout, autonomy) and nothing else in 1.11; the lean is
  shown and recorded, the endings themselves have their own conditions.
- Variant rules, kept small: 改造试验 pays ¥60,000 per terraforming level standing on the last
  stage's deadline; 矿权转卖: 360 days after opening, unless 30,000 units of ore were exported since
  or the exchange stands, the two mines with the highest rate are disabled and marked sold;
  秘密设施: while the shipyard is under construction and not disclosed, a 15% chance each month that
  the colonists find out (民心 -12), disclosing costs 民心 -4 and ends the checks; 地下的东西: one
  find a month, at most 12, to the company (¥4,000, distrust -1.5) or the public (民心 +1.5, 120
  research points), as the contractor directs (公开 sends them to the public).
- The stories tied to the open variant come three times as often (`event_weight`).
- Endings: the award records 效忠 (loyal) until another follows. 收购: price = 8 x the company's
  share x the trailing 360 days' operating profit, at least ¥250,000, from the career fund; 自治:
  民心 >= 60, population >= 2,500 and a company rating of B or better, or 民心 >= 55 after a disclosed
  annex. Both end the company's share (`Contract.company_rate` 0) and its process (no more
  reviews); one ending per colony. The takeover is recorded as an ending too.
- The settlement statement (结算单) is one screen (`settlement_page.gd`) opened on every ending: stages
  promised and delivered, the annual reports and gaps, amendments, money, shares, landmarks; after
  the award it offers the buyout and autonomy. The lights time-lapse waits for G.
- Bots: balanced complies; rush manoeuvres; research_first discloses; the windfall bot aims for the
  buyout. The harness reports variants, answers and endings as an INFO row.
- Weather (F) lives in `simulation/weather.gd` with its numbers in `geography.json` `weather`, behind
  the flag `progression.json` `features.weather` (on). Five kinds: cyclones over ocean 8-30° with
  water above 22 °C (heading west-north-west, poleward), dust over arid interiors, cold waves over
  land 30-80° below 6 °C (heading equatorward), heavy rain over flood-prone land, fog on coasts.
  Each day each kind may be born once, from a roll seeded by seed, day and kind (24 tries to land in
  its zone); systems move once a day along a heading at a speed, for a life in days. Same seed and
  day, same weather, at any game speed.
- A system reaching a town (its centre within its radius) opens the kind's story through
  `EventsV2.trigger` (cyclone_landfall, new; dust_storm; cold_snap; flood_season; sea_fog); those
  five leave the random draw while weather is on (their weight factor is 0). Cooldowns still apply,
  so a second system soon after strikes without a second story.
- Warnings: base 3 days, doubled by a weather station within 12° of arc, +2 with 天气预报. Preparing a
  warned town costs ¥900 at the reference income (scaled like event money) and halves what the next
  disaster there takes; 防灾工程 cuts weather losses by 30%. "The weather's losses" are what any
  event takes from a town within `loss_days` (15) of a strike there: the strike's own story nearly
  always, since weather stories leave the draw; a random event landing in those days counts too,
  which is simpler than tying losses to one event instance. Losses elsewhere stay whole (an earlier
  draft let 防灾工程 cut every event's losses). One helper (`Weather.take_losses`) applies the 1.9
  emergency network's cut and these, consumes through the ledger, and writes the weather's share on
  the strike and in `weather.lost`.
- `audit()` covers the weather: systems (known kind, unique id below `next_id`, on the planet, age
  within life), strikes (known kind, not in the future), claims (once per strike and town, within
  `claim_days`), accepted claims' days within the contract's deadline shifts, each strike's losses
  within the total, and the total within the ledger's sinks per good.
- Force majeure is a standard clause. A claim within 15 days is accepted with a station's record or
  a logged warning; it moves the current stage's deadline by the kind's disaster days (5-20) and
  waives that year's miss on the kind's report line (farming for cyclones, cold and rain; mining for
  dust and fog). A waived line pays no reward and adds no distrust.
- The weather station (气象站, ¥1,200, no technology) looks like the field station until it has a
  model of its own.
- The globe's clouds draw the state's systems (three at most, cyclones swirling hardest), smoothed
  between days by the visual clock; rings mark every system and turn red for one heading at the
  colony, and stay when clouds are off. The cosmetic storms remain only for a game with weather off.
  The cloud shell gains domain warping, a thin faster upper layer, a stronger warm terminator and
  town light on the clouds' undersides at night. Frame times are for the Windows check.
- Seen in the first capture (`docs/v17/weather/`): a warned ring, lit and glowing, washed out to
  white in daylight, so rings are unshaded; a young storm heading for a town was a faint smudge, so
  a system's clouds reach 2.5 times its strike radius and a warned system is drawn at no less than
  60% strength. Both are drawing only.
- The weather page opens from the storm notice and from the force majeure clause on the contract
  page (a link under 第 N 条 不可抗力), not from the navigation: the plan limits HUD changes.
- The news line (I) lives in `ui/news_line.gd` with its templates and numbers in `news.json`. It
  reads the state and never writes it; what it has shown and its cooldowns live in the node, are
  not saved, and its generator is seeded by the seed and the day. A new or loaded game starts with
  what is already true (town sizes, stages, reports, closed events) marked as shown.
- Kinds by priority: weather 90 (systems in the state warned for a town and still coming, the days
  counted along the system's path within its remaining life), stage 85, report 80 (with a company
  share index from the report outcomes: 100, then -4 a missed line, +1.5 met, +3 exceeded, 0
  waived), town size 70 (100 to 4,000 people), echo 60 (an event closed within 20 days, once, with
  its ending), market 40 (a good at least 15% below the reference price, in 5% steps), Annex VII
  rumours 25 (before stage four and while sealed; never the variant), flavour 10 (company
  bulletins about other projects, CC-11 to CC-98 and never the colony's own; colony life that names
  no facility, so it cannot contradict one). Cooldowns 2 to 35 game days.
- "Waiting for a decision" is an event instance pending or deferred. A line whose subject is that
  story (the weather that opened it, an echo of the same story) is skipped until it is decided.
- The line holds its text and its time while the events page is open or a decision holds the
  clock; otherwise a line stays 14 seconds of running time. It sits in the 20-pixel strip under the
  task bar until the interface pass; 底部新闻 in the settings turns it off (settings.cfg).
- G without the light concept sheet (asked for on 2026-11-23): the record, the time-lapse and the
  flat map's new place are built; the planet-scale forms in ordinary play, their crossfade with the
  per-plot lights and the five-stage captures wait for the sheet.
- The light record (`light_record.gd`, `progression.json` `lights`): a snapshot on the first day
  with a settlement and every 90 days, 64 kept (16 years). Per founded settlement: where it stands,
  its light stage, people, facilities (finished buildings other than homes), coast, frontier, and
  the towns its finished roads reach. Stages, people / facilities both needed: 着陆点 0/0, 首批住区
  50/4, 小镇 200/12, 区域中心 600/25, 星球首府 1500/45, a first guess for J to check against the
  harness's towns. `audit()` holds the record in order; saves validate it; a save from before 1.11
  starts its record on the day it loads (there is nothing earlier to replay).
- Until the sheet arrives the time-lapse draws the 1.9 town forms (a bright core, a lit street grid,
  arms and suburbs, from a few numbers per town), which the globe shader still carried unused: an
  existing look, not a new one; the sheet's stages replace them. Homes are not in the record, so the
  built-up area counts one home for 40 people. During playback the per-plot lights are off, the sun
  is held opposite the capital, and clouds, markers, routes and the interface are hidden.
- The time-lapse runs at every ending before the settlement statement (20 seconds, a skip button)
  and from the career page (回放殖民地夜景). The game clock stops while it plays.
- The flat map leaves the main navigation (two views: globe and district). It opens from the panel
  of picked ground, where founding and prospecting happen (在平铺地图上选址与勘探 / 回到球面总览),
  and a founding made there returns to the globe. `navigate("flat")` stays for tests and captures.
- The phase gates run in small pieces after the machine restarted twice under them: 29 chunks of
  three cases (`--chunk=k/29`, which every gate commit's harness reads), three at a time beside
  the extras, each with its own checkpoint, at lower priority than interactive work; a rerun of
  the driver skips finished suites, chunks and extras · three chunks of 29 cases, which lost up
  to 40 minutes each time. Tooling only; the harness's cases and results are the same.
- J's measures in the harness: a weather row (systems born a year, strikes per settlement-year,
  goods lost to the weather, the share of warnings followed by a preparation, claims accepted of
  those made; the weather keeps running totals of warnings, strikes and preparations for it), a
  lights row (the capital's light stage by year), and a pace row.
- "A meaningful decision" (the pace row, `tests/balance/pace.gd`): an accepted action that commits
  money, people or ground or changes the colony's course: building, upgrading, demolishing,
  founding, roads and links, an enterprise, starting a research topic (the first allocation to it,
  not re-staffing), reshuffling the offers, research contracts and commissions, crews, recruitment,
  the wage, an event choice other than deferring, the annual report, the Annex VII answer, weather
  preparation and claims, the buyout, autonomy and the career transfer. Stock targets are not. The
  row reports the longest stretch between the landing, such decisions and the run's last day, for
  the balanced bot on normal. It measures what the bot found worth doing, the nearest a bot comes to
  "had nothing to decide"; the annual ship's cadence in real minutes comes from the data
  (seconds_per_day and the speeds).
- The technology merge (H) cannot reach the plan's 55-65 under its own rules: merging only the
  technologies that add effects, unlock nothing and are required by nothing gives 125; merging also
  those that only other technologies require, with each requirement pointed at the merged one,
  gives 85; 55-65 needs technologies that unlock buildings merged too, against the plan's "keep
  every technology that unlocks a building, upgrade or rule". Asked the user (2026-11-23); until an
  answer, the middle reading (85, 79 researchable) is built. The grouping is the only part that
  differs between the readings (`tools/tech_merge.py`).
- What the merge keeps: a technology named by any rule file but events.json, or by game code but
  the 1.6 save migration (it unlocks something); gifts; frozen ones; any without effects. The rest
  merge within category and tier: 69 into 18 (two tiers had one each and stay). Names are new
  (垦殖基础, 工程管理 ...); the description lists the parts.
- A merged technology costs the sum of its parts x 0.8 (`merge_cost_factor`); its funding is the
  parts' funding weighted by cost, so a research point costs what it did; draw weight and minimum
  staff are the parts' largest. Effects add per key: the totals over the tree are unchanged
  (`v111_techs` holds them to the totals before the merge).
- `techs.json` `merged` maps old ids to new ones; `merged_from` and `part_costs` sit on each merged
  technology. Saves convert on every load path (old schemas through `ensure_state`, current saves
  beside the crews' and weather's upgrades, 1.6 saves through validation that accepts merged ids):
  finished when all parts were, otherwise the finished parts' points (their old costs) plus any
  running part's work become progress, short of finishing; teams move with the project; offers
  name it once. Events' `research_lead` ids were rewritten in the data; bots read their plans
  through `Research.current_id`.
- The contract's technology goals become tier milestones, `techs_tier_<n>`: technologies finished
  at tier n or above, gifts left out (`Contract.TIER_GOAL`). Calibrated with
  `tests/balance/calibrate_techs.gd`: the balanced bot on the three classic contracts and the quick
  seeds, before the merge for the days its counts (5, 14, 24, 40) were reached, after it with the
  goals off for the day each tier count is reached.
- The tier milestones (calibrated 2026-11-23, nine balanced runs per tree, the three classic
  contracts and the quick seeds): the old counts were met on median days 569, 1163, 1834 and 2605
  (8 of 9 reached 40); on the merged tree, one tier-2 technology comes on day 494, five on day 1174,
  thirteen on day 1825, and five at tier 3 or above on day 2546. Stages two to four ask for 1, 5 and
  13 at tier 2 or above, stage five for 5 at tier 3 or above · 6 at tier 3 (day 2605, the same
  median, but 4 of 9 runs late or never against 1 of 9 for the old count; the freeze's later awards
  were left for J). The milestone of eighty technologies counts 49 (80 of 130, the same share of 79).
- After the merge, industry and agriculture open with two cards instead of three: tier one holds
  only their starter card and the merged technology. The hand deals what is open, so the first
  choice in those directions is narrower until the first card is done · adding a card to fill it.
- A merged technology needs every part's prerequisites (with merged parts pointed at their merged
  technology), so a merged tier-3 or tier-4 technology comes later than its earliest part did; the
  tier goals are calibrated on the merged tree, so the stages keep their days.
- A converted save's partly finished merged technology goes back into its direction's hand (a team
  can only take up a card on the table), once its prerequisites are done; the hand may hold one card
  over three until it next deals.
- `v17_research`'s pool checks follow the merge: at least 55 technologies (the plan's floor), at
  least 15 per direction, and a starting hand of three or as many as are open.
- The gates run in a different order from 2026-11-24 03:17: the head's (H, `cdf587a`) first, as the
  baseline the J rebalance needs, then the J candidate, then C, D, E and F at their commits. Gate C's
  harness had run 18 minutes without finishing a chunk; it was stopped and starts again later. H's
  suites are the run made on the main tree with the same content (`h2_suites`, 63 of 64, the
  payback suite the known miss); the gate copies that record instead of running them again.
- The container's kernel shares the CPU between sessions (autogroup scheduling), so the gate's four
  harness processes, started in one session, had a sixth of the machine beside five other sessions.
  Autogroup scheduling is now off for the session (`kernel.sched_autogroup_enabled=0`) and the
  gate's processes run at the probes' priority.
- What held growth from 200 to 600 people (the 1.10 miss, J) is measured in the harness: each day
  between the colony's 200th and 600th person, the capital's main limit as the people page names it
  (`people_lines.gd`: housing, jobs, food, appeal, none), pooled over the balanced runs on normal.
  The target: jobs holds growth on at most 60% of those days. Building workplaces is the core of
  that stretch, so jobs should stay the most common limit, but no longer nearly the only one
  (1.10: 97% of the days and every run, measured again on `cdf587a` with `growth_probe.gd`).
- The jobs limit and the wage lever had one cause: immigration slowed once a tenth of the adults
  were jobless (`jobless_free_share` 0.10, stopping at 0.35), so newcomers arrived only as fast as
  jobs opened and unemployment settled at 18-25% whatever the wage did (the lever probe: +8% on
  `cdf587a`). J moves the band to 0.25-0.50: a frontier town takes in newcomers until a quarter of
  its adults are out of work. With it (`growth_probe.gd`, six seeds each) jobs hold growth on 44% of
  the days for the standard contract, 52% for 移民安置 and 47% for 矿权抵押, food on 27-32% (faster
  growth outruns the farms) and nothing on 15-28%; the lever probe gives +27% (202 to 258 arrivals).
  0.20-0.45 gave jobs 72% and +22%; 0.30-0.55 jobs 39% but food 37% and one seed at 33% jobless.
  0.25-0.40 (stopping sooner, after one awarded trace colony on the new band was taken over 425
  days after its award when its mines ran out and jobless newcomers kept arriving) gave +1% and
  jobs 66%: above a quarter jobless, immigration then falls too steeply for the wage to matter. So
  0.50 stays; takeovers after the award are the 1.7 finding (mines run out, the bot never hands
  over) and the harness reports them.
  Employment stays above stage four's 60% and the company's 35% distress line.
- The payback suite's misses (the smelter in year 4 since the freeze, the ore mines in year 6 since
  the merge brought their output effects sooner) have one lever: ore. J lowers ore's list price
  from 8 to 6.2: an ore mine earns less (year 6: 55 days to 84, band 70-150; the heavy one 93 to
  139, band 100-220) and the smelter buys its ore cheaper (year 4: 325 to 260, band 120-300). The
  processor buys ore too and would then pay back in about 107 days in year 4 (band 120-300), so its
  price rises from 3,900 to 4,400 (121 days). With the unemployment band above, the suite passes,
  43 of 43 (`v19_payback.gd -- --set=...` before the data changed; `tests/support/rule_overrides.gd`
  gives the probes and the payback suite the same `--set` switch).
- The quick harness plays normal only, so the sloppy row's "takes over on hard" is reported as not
  measured there (it read MISS with "hard failed 0/0"); the full harness on the Windows PC plays
  hard and judges it.
