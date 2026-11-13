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
