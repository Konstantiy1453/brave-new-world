# Colony Charter — Progress

## 1.12.0 — approved terrain and settlement (branch `v17-terrain`, 2026-11-26)

The request: integrate the approved terrain and settlement handoff (`codex/approved-terrain-and-region`
`6046c90`, instructions `docs/handoff/approved-terrain-region/CLAUDE_INSTRUCTIONS.md`) into 1.11.1 and
release 1.12.0 for Windows x64. Evidence labels as in `CLAUDE.md`; everything ran in the Linux cloud
container (llvmpipe software rendering). Human playtests NOT_RUN; the Windows EXE NOT_RUN.

| Part | What | State |
|---|---|---|
| Setup | branch from the handoff, LFS assets, `verify_package.py`, the regional reference reproduced (llvmpipe Forward+ within ~1.7/255 of the approved frames) | **done** |
| Map | CC-GEO-2.3 and mountain and plateau snow (patches 01, 02) in New Expedition, the satellite map and the globe; old saves keep their generator and settlement places; Linux hashes and a Linux 1.11.1 fixture beside the Windows ones; world-dependent suites pinned to 2.2 worlds | **done** (`8a41277`) |
| District layout (rev 06) | 16.6 m per unit (59.62 m median clear space), reviewed footprints x1.3 (cap 91 m), metric streets (8.6 m through road, 6.2 m lanes, 7.0 m works roads, gutters, footways, gravel shoulders), the grid bent into curving streets, oriented footprint pads, high-detail reviewed models near the camera, metric vehicles; lanes from the player's own buildings, outlying buildings joined along open grid lines | **done** (`c876309`, `acad7f9`) |
| Ground (rev 07) | soil07 loam and turf, packed earth and gravel along the live paving (shoulders' mask rebuilt from the drawn streets), layered rock on far and steep slopes, the site's climate; settled town ground; no inland sea ponds | **done** (`384a6b1`, `9c90dbd`) |
| Nature (rev 07) | trees, shrubs, fine grass, weathered boulders with toe stones, far outcrops, from forest and climate, clear of paving and footprints; Boulder 01 field and chip meshes (2,000 and 220 triangles) and a 12,000-triangle play mesh (the 56,540 scan kept for comparison captures) | **done** (`acad7f9`, `6bfc011`) |
| Light | graded sky, ACES 1.12, warm ambient, evening sun; calibrated against the approved frames from equivalent cameras | **done** (`9c90dbd`) |
| Frame budget | draw limits for play, sectors, shadow reach with the camera: settlement camera 10.2 M to 3.7 M primitives, 1,497 to 561 draws | **done** (`6bfc011`) |
| Release | version 1.12.0, CHANGELOG, players' note, credits in the zip and the PCK, packaging checks every raw file is in the PCK | in progress |

## 1.11.0 — the contractor (branch `v17-charter`, started 2026-11-23)

The plan is `docs/superpowers/plans/2026-11-23-v111-contractor-instructions.md`: the player is an
outsourced contractor bound by a bet-on contract with the colonisation company. Branch `v17-charter`
from `v17-bay` `0697fe2`. Evidence labels as in `CLAUDE.md`; everything runs in the Linux cloud
container. Human playtests NOT_RUN.

| Phase | What | State |
|---|---|---|
| A. Freezes | version 1.11.0, schema 7 reading 1.10 saves from `v110`, user dir `v111`; `progression.json` `features` (metals, seabed, shuttles, radius_slider, research_commissions), all off, read through `simulation/features.gd` by rules, world generation, interface and bots | **done** (`ec86efc`, `40ecc44`, tag `v111-A` on `3429c06`); suite `v111_freeze`; suites 53/56 on `ec86efc` (the two test fixes in `40ecc44` then pass; `v19_payback` is the known miss below); harness `1.11-A` |
| B. The contract and the company's voice | the contract as a document (`contract_page.gd`: 第 N 条 from `contract.json` `document`, stage stamps, amendments, sealed Annex VII); structured letters (`letters.json`, `letters_view.gd`); 公司评级 + 民心 in the gauge's slot; CC-NN code; `cues.gd`; the company's register in ten events and the writing guide | **done** (`031e52e`, `4546737`, local tag `v111-B` on `4546737`); suite `v111_contract` (65 checks); gate: 57 of 65 suites, the misses `v19_payback` (known, below) and seven `review_*` tools that need the original `D:` paths; harness `1.11-B` identical to `1.11-A` (B changes no rule) |
| C. Six origins | `economy.json` `openings` as contract types with story, gains, costs, unique rule, effects (third `Research.bonus` source) and favoured route; `origins.gd`; origin cards on the new-game screen; the origin's clause in the contract; bots `housing_first`, `mining`, `coastal`; the harness runs all six | **done** (code `d9067b6`); suite `v111_origins` (55 checks); its suites at `d9067b6` 56 of 58 (`v17_world_stats` timed out under load, `v19_payback` the known miss); all six origins in the harness runs of H (`cdf587a`) and J2 (`741b872`); its own quick harness was stopped to run H first and has not run (no tag yet) |
| D. Annual ship and ratchet report | the company ship on each landing anniversary (delayed by supply_delay), its light coming down over the capital on globe, flat map and district, the days to it in the HUD; the report (矿业, 农业) with 如实 / 报达标 / 报超额, rewards and misses, the ratchet, the gap filled by later production, audit stories weighted and opening at their exposure scene; 矿权抵押's ore tribute; amendments on the ship (five stories, deadline shift, company share, next year's targets, clauses); `annual_report.gd`, `annual_report_page.gd`; targets calibrated with `tests/balance/calibrate_annual.gd`; bots report honestly, the new `inflating` bot claims every line | **done** (code `c49eba5`); suite `v111_annual` (76 checks); measured in H and J2 (the annual report row); its suites at `c49eba5` 58 of 59 (2026-11-25; `v19_payback`: the light ore mine 66 days, band 70-150, the smelter 361, band 120-300); its quick harness has not run (no tag yet) |
| E. Annex VII and three endings | Annex VII drawn from the seed, sealed on the contract page, opened by a letter when stage four is accepted; one answer (照办 / 周旋 / 公开) sets the lean and moves distrust and 民心; four variants with their great work, linked stories and rule (`annex.gd`); endings after the award: 收购 from the career fund and 自治 by 民心, people and rating (or a disclosed annex) end the company's share and process; the loyal ending at the award; the takeover recorded; the settlement statement on every ending (`endings.gd`, `settlement_page.gd`) | **done** (code `bdb5f5f`); suite `v111_endings` (56 checks); the time-lapse at every ending (G); measured in H and J2 (the Annex VII and endings row); its suites at `bdb5f5f` 59 of 60 (2026-11-25; `v19_payback` as at D: 65 and 361 days); its quick harness has not run (no tag yet) |
| F. Weather that matters | weather systems from seed and day (`weather.gd`, `geography.json` `weather`), strikes opening their stories, warnings and paid preparation, the weather station, 天气预报 and 防灾工程 (on the weather's losses only), force majeure (clause, claim, deadline and report waiver), the weather's losses on each strike and in `audit()`, the weather page (from the storm notice and the force majeure clause), storms on the globe drawn from state with rings that stay when clouds are off, a richer cloud shell; worlds from before the climate grid (1.6, 1.7 saves) keep cosmetic weather | **done** (code `496f5c0`, visuals `eeaac07`); suite `v111_weather` (45 checks); measured in H and J2 (the weather row); frame times wait for the Windows check; its suites at `496f5c0` 61 of 61 (2026-11-25; `v19_payback` passes there: the light ore mine 77 days, the smelter 290); its quick harness has not run (no tag yet) |
| G. Lights at two scales | the quarterly light record in the state (`light_record.gd`: place, stage, people, facilities, coast, roads); the night time-lapse at every ending and from the career page (`timelapse.gd`, `timelapse_view.gd`); the flat map only from the ground panel (founding, prospecting), back to the globe after a founding; with the user's sheet 沿海与内陆的灯光形态 (2026-11-24): the planet-scale forms in ordinary play and in the time-lapse (`town_forms.gd`, the globe shader: a lit street web, a white-hot core, coast cuts, growth along the player's roads, sizes in the sheet's proportions), remote mines and harbours as points, roads as faint strings, the crossfade with the per-plot lights by camera distance | **done** (the record, time-lapse and flat map: local tag `v111-G` on `03a03dd`, gate at `cdf587a` with H; the forms: `23f1b59`, local tag `v111-G2` on `0f7790d`): suite `v111_lights` (34 checks); screenshots viewed: `docs/v17/lights/forms_vs_sheet.webp` (five stages, coastal and inland, default distance, 4K; `_1080` the same at 1920 x 1080), `forms_crossfade.webp` and `forms_globe.webp` (a played colony; the light over the capital 0.0185 with plots, 0.0115 with forms, never more between), `timelapse_year*.webp`; ships as the 1.11.1 preview |
| H. Technologies merged | technologies that only add effects merged within category and tier (`tools/tech_merge.py`): 136 to 85, 79 researchable, every effect total kept; merged costs x0.8; saves converted on every load path; events and bots read old ids through `merged`; the contract's technology counts become tier milestones (`techs_tier_<n>`), calibrated (`calibrate_techs.gd`, nine balanced runs a tree): stages two to four ask for 1, 5 and 13 technologies at tier 2 or above, stage five for 5 at tier 3 or above | **done** (local tag `v111-H` on `cdf587a`; the user chose 85 on 2026-11-25, the tree in the game): gate H, suites 63 of 64 (`v19_payback` the known miss, met in J) and quick harness `1.11-H` (90 runs, 0 audit errors; research-first now awarded on day 2,068, under the band: DECISIONS.md); research days per direction kept (DECISIONS.md); the other readings, 124 and 56, are kept as comparisons in `docs/v17/tech_trees/`; suite `v111_techs` (20 checks) |
| I. The news line | one line at the bottom edge from `news.json` (weather, stages, reports and the company share index, town sizes, echoes, prices, Annex VII rumours, flavour), interface only, quiet on a waiting decision, holds while an event panel is open, a settings toggle (`news_line.gd`) | **done** (local tag `v111-I` on `3fd7f05`; gate run at `cdf587a` with H): suite `v111_news` (23 checks); `v17_speed` passes with it in the game; captures `docs/v17/weather/` |
| J. Rebalance and release | one rebalance, data only: the smelter 8,500 to 6,500 (`8ecc070`); tried and taken back with their evidence (DECISIONS.md): ore's price, dearer ore mines, the later mine bonuses and the 0.25-0.50 unemployment band; the harness rows for what holds growth from 200 to 600 people and for pace, `--set` for probes, the payback suite and the harness; the Windows build and package (`ColonyCharter-1.11.0-Windows-x64.zip`, SHA-256 `CEA06CCF…8DAC5A`); the run kit for 1.11.0 and its cases pre-checked on the shipped PCK (`docs/v17/kit_1.11`, 108 of 108 checks in seven cases); CHANGELOG, PLAYTEST, BALANCE | **done** (local tags `v111-J` and `v1.11.0` on `708ff33`, the commit packaged; code and data as `8ecc070`): suites 63 of 64 (`v19_payback`: the ore mines in year 6); harness `1.11-J4`, 17 targets met, 6 missed (below); the Windows checks and the full harness wait for the user's PC |

**Harness `1.11-A`** (quick, 51 runs, 47 minutes with the extras beside the chunks): 0 audit
errors, determinism 3/3; 18 targets met, 4 missed (openings, sloppy on hard, services budget, labour
lever). Against `crews-d24c660` the freezes are a material change: the balanced bot's median award
moved from day 2674 (8/9 awarded) to 2854 (6/9), and science openings award 300-550 days later.
Replaying the three runs that newly fail: research commissions back on awards all three, metals
and seabed back on two of three. The bots bought stage five's research. Left for J.

**Gates.** Each phase's suites and quick harness run in a worktree at the phase's commit
(`run_gates.sh`, then `run_gates2.sh`, which leaves out the `review_*` tools). The chain **died** at
04:49 when the session stopped at the usage limit (gate B's harness had two of three chunks); it
was resumed from the checkpoints at 08:22 (chunk 2 and the extras again). It **died** again at
10:08 when the machine restarted (gate C's suites done, 56 of 58: `v19_payback` known and
`v17_world_stats` timed out under the load; its harness lost a 29-case chunk at 28 cases and the
extras at 37 minutes). From 2026-11-24 02:56 the chain runs with `gate3.sh`: 29 chunks of three
cases, three at a time beside the extras, each with its own checkpoint, so a restart costs minutes,
and a rerun resumes. At 03:17 the order changed (DECISIONS.md): H first, the J baseline, then the J
candidate, then C, D, E and F; H's suites are the main-tree run on the same content, 63 of 64
(`v19_payback` the known miss). Autogroup scheduling had given the gate a sixth of the CPU; it is off. The run of C, D, E and F
from 11:31 on 2026-11-24 **died** at 11:36 when the container was reclaimed (`gates3.log`, no chunk
finished); the machine came back with 4 cores. The rerun from 16:01 **died** at about 16:14 the
same way (gate C's harness had 5 of 29 chunks, kept): the container is reclaimed a few minutes
after a working turn ends, so a run of hours cannot finish between the user's messages. On
2026-11-25 the suites of D, E and F ran at their commits in the foreground (above); the four quick
harnesses of C to F (about an hour and a half each on 4 cores) have not run.
Tags stay local: the session's proxy refuses tag pushes; the tag-to-commit map is in this table.

**Preview 1.11.1 (2026-11-24): the light forms.** `ColonyCharter-1.11.1-preview-20261124-lights-Windows-x64.zip`
(55,941,641 bytes, SHA-256 `C5CC31A879D121D0155F04B1B38C1AC4524E696625113570DF3CD7FEE63C1227`) and
its source ZIP in `delivery/v17`, from `0f7790d` (`RELEASE_IDENTITY.json`; 1.11.0's is kept as
`RELEASE_IDENTITY-1.11.0.json`): PCK `020ED9D8…EA7D8`, the EXE unchanged. Rules as 1.11.0 (display
data only, so no harness run). Evidence: automated tests (64 headless suites on `85af082`, 63 pass,
`v19_payback` the known miss; window suites 3 of 4, `v16_interaction_probe` failing on its 1.6
fixture on Linux as since 1.8, and on the 1.11.0 code); exported PCK on the Linux runtime (five of
the run kit's cases, 64 of 64 checks, no script or shader error: both capital placements, the
regression, the refusals and the save carried over; the two outpost cases, an hour each, not run);
screenshots viewed (`docs/v17/lights/`). Not run: the Windows EXE, frame times on a real GPU, every
human playtest (NOT_RUN).

**Release 1.11.0 (2026-11-24).** `ColonyCharter-1.11.0-Windows-x64.zip` (55,929,583 bytes, SHA-256
`CEA06CCF7F4DD9D122951E560E46FD2850406241FD18B514F9744FB94D8DAC5A`) and the source ZIP in
`delivery/v17`, from `708ff33` (`delivery/v17/RELEASE_IDENTITY.json`): PCK `A5CA2638…E990`, the EXE
the same Godot 4.5.1 runtime as 1.10. Evidence: automated tests (64 headless suites, 63 pass);
balance harness (`1.11-J4`, quick, Linux); exported PCK on the Linux runtime (the kit's seven
cases, 108 of 108 checks; `boot` needs a GPU). Not run: the Windows EXE, the full harness, frame
times and every human playtest (NOT_RUN); `docs/v17/WINDOWS_RUN_KIT.md` and `PLAYTEST.md` are ready.

**Misses at release** (`BALANCE.md`, "1.11 the contractor"):
- research-first is the best bot with all six origins and is awarded on day 2,065, under the band:
  the merge bundles research speed with the whole society tier (H); the merge's price did not move it;
- the openings row: balanced medians 2,516-2,964 (18% apart, target 15%) and the one best bot;
- the labour lever (+8%) and jobs as the limit from 200 to 600 people (94% of the days): the
  0.25-0.50 band fixes both (+27%, 46%) and costs the balanced bot half its games (`1.11-J2`);
- research teams 9% of the balanced bot's adults (10% at gate H); cash cover before the award, p90
  141 days (target 120);
- `v19_payback`: the ore mines' year-6 payback, 54 and 91 days against 70-150 and 100-220, since
  the merge;
- G was partial at release (the light concept sheet came after it; the forms are done since, in
  the 1.11.1 preview); H was provisional (the user chose 85 on 2026-11-25, the tree that shipped);
  C, D, E and F have no per-phase gate of their own (their code is measured at H and J4).

---

# 1.10 — Progress (the bay first, started 2026-11-19)

The user's brief of 2026-11-19 covers free siting, geology per resource and prospecting, mobile engineering crews,
a nightscape built from the game's own state, people and growth, and stories. The plan, in phases, is
`docs/superpowers/plans/2026-11-19-v110-bay-first-instructions.md`. The check of the branch against
the November 13 preview is `docs/v17/REVIEW_20261119.md`: most findings are still open, and immigration has
changed since (11 a month). Branch `v17-bay`, from `v17-fix-tips` at `8c395db`. Evidence labels as in
`CLAUDE.md`; everything runs in the Linux cloud container unless stated.

| Phase | What | State |
|---|---|---|
| A. Verified feedback | building uids (schema 6, own folder), research states, commission ETA, farm forecast by usable food, tutorial planet and water lesson, the clock's fraction, event towns after the draw, report-back days | **done** (`f1bf55f`, `0a30df2`); suite `v110_fixes`; harness `fixes-0a30df2` |
| B. Nightscape from state | lights from real plots on globe, flat map and district (`light_field.gd`), windows by occupancy, landing camp and quay positions shared with the district, transport diagram as an overlay | **done** (`185a4b2`, `9c2816c`, `c7bda43`); suite `v110_lights` with the decisive test |
| People readouts | each town's net change, demand against room, main growth limit and remedy | **done** (`112867b`) |
| C. The playable bay | mobile crews apart from the workforce (`crews.gd`): one at the landing, trained from the town's 职工 or recruited from outside, sent over finished links, a standing instruction (shortages first, then 先建, then the oldest order), each project's start and finish from the queue; the workforce renamed 职工; the small harbour with its forecast, mine roads for far deposits that carry the next mine, the offshore signal and its survey (`bay.gd`); first-shipment cards; the tutorial teaches crews; the bay in the three views (harbour site, quay lamps, masthead lamp, ship light, signal ring and buoy, round halos) | **done** (`aab8519`, `3e89426`, `234a06c`, `c39e828`, `5491ef0`, `acef816`, `21fef0f`); suites `v110_crews`, `v110_bay`, `v110_lights`; harness `crews-234a06c`, `spur-21fef0f` |
| Reviews | 3 × 3 night sheet with labels and clean (`docs/v17/bay`), ship and zoom clips, gameplay review of the opening on five seeds and of stage three (`REVIEW_BAY_20261119.md`, tool `bay_openings.gd`) | **done** (`f67a608`); human playtest NOT_RUN |
| Free placement (Nov 20 brief, release requirement) | a settlement at any coordinate, capital and later towns: the ground under a click on either map, its report and a specific refusal, the founding button acting on that point only, the point carried through naming, construction, expeditions, saves; planetary deposits per resource with shared reserves (`placement.gd`, `geology.gd`, `ground_panel.gd`) | **done** (`1c783d4`, `df24484`); suite `v110_placement`; interface driver `tools/verify/placement_driver.gd`, 95 checks passed on the source project and on the shipped PCK |
| November 20 audit | first ore truck and first ship from recorded consignments (`consignments.gd`), mine roads after a cancelled mine, crews by freight's road rule, measured 30-day population change with its parts, farm forecast from the whole food balance at the delivered price, commissions quoted while blocked, the water lesson's three outcomes, the first lived-in home lit | **done** (`0d8ed9d`, `08e1320`); suite `v110_audit`, `v110_lights`; night captures through ordinary play `docs/v17/bay/play` |
| Radius, stage three, tutorial, prospecting | radius slider 0.70–1.30 with km and gravity; stage three by one operating route of three, 600 people an achievement (measured on six seeds, `STAGE_THREE_ROUTES.md`); the tutorial opens on a bay with the mine-or-harbour decision; prospecting one resource at a time (orbit, field survey, drilling) | **done** (`0d8ed9d`, `4604991`, `3a35730`, `c5dda12`); suite `v110_audit` (102 checks) |
| Not done from the Nov 20 brief | offshore surveying tech, seabed extraction and its cargo; nickel and cobalt; larger districts, natural slopes, landform clues and close-range surfaces; the farmer occupation and one population unit everywhere; crews for roads, repairs and surveys with standing orders and costlier crews; local consequences by kind of town; the immigrant transport tied to the homes it fills | open |

**This round (2026-11-22).** Metals, crews beyond buildings, people, the endless flat map and the
space background (`741e881`, `93f8a30`, `591f011`), then the release gate (`a635393`-`09457a5`).
- **Suites.** On `591f011` 48 of 55 headless suites passed. On `a635393` 54 of 55, and on `9c45be7`
  the payback suite passes too (42 checks), so every headless suite now passes on Linux. The four
  "Linux-only" suites: `v17_saves` and `v18_systems` check the Windows-made fixtures on Windows only
  (SKIP with the reason elsewhere); `world_v16_seed` had a stale atlas assertion (failed on every
  platform since `319dc44`); `v17_tutorial`'s script errors were a real bug (a 1.6 save's globe
  preview), fixed.
- **Payback.** The suite judged medians of one or two colonies as "5 seeds"; it now needs 3 of 5.
  Bands unchanged; evidence over three commits in DECISIONS.md.
- **Harness `crews-d24c660`** (chunked, 51 runs): 0 audit errors, determinism 3/3, balanced award
  median 2,674. 16 met, 6 missed: research balanced (40 techs, 10%, at the floor), services budget
  (5 of 9 runs), absorption year 3 (80%), and the standing openings, sloppy-on-hard and labour lever.
- **Windows.** Run kit `tools/windows_run_kit.ps1`, `docs/v17/WINDOWS_RUN_KIT.md`; 5 of its 8 cases
  pre-checked on Linux with the shipped PCK (64 checks). Waiting for the user's Windows run.
- **Open.** The star glare (renders nowhere on Linux); the three new harness misses; the brief's
  crew-built roads balance, local event consequences, larger region and natural terrain.

**This round (2026-11-20).** The November 20 brief: free placement first, then the audit.
- **Build.** `ColonyCharter-1.10.1-preview-20261120-placement`, commit `1853590`, PCK SHA-256
  `78181ECC…786F`. Handoff with the plain status of every requirement: `docs/v17/HANDOFF_20261120.md`.
- **Free placement on the shipped PCK.** The Linux runtime with `--main-pack`, driven through the real
  interface by `tools/verify/placement_driver.gd`: 95 of 95 checks over six cases (two capitals, the
  seed 3 regression, refusals, inland and coastal expeditions). Records are in `docs/v17/placement/`.
  The Windows EXE was not run.
- **Saves.** A save made by the 1.10.0 PCK carries over on the 1.10.1 PCK, 13 of 13 checks
  (`save_carry_driver.gd`). The before and after files are in `docs/v17/placement/save_files/`.
- **Night in ordinary play.** `docs/v17/bay/play/`: the first lived-in home now changes the globe and
  flat-map night images (1,397 and 2,458 pixels).
- **Suites (final run on `1853590`).** 47 of 52 headless suites pass. The four Linux-known ones fail as
  their baselines. `v19_payback` misses three bands: iron mine 64 days against 70–150, smelter 461,
  food processing 614.
- **Harness `placement-c5dda12`.**
  - Audits 0 errors; determinism 3 of 3 identical.
  - Population 333 at year 2 and 940 at year 4; the balanced bot is awarded at a median of day 2646.
  - Misses: the labour lever and the sloppy bot on hard (both standing), and openings (research-first
    is best with every opening; new).
- **Open.** See the "Not done" row above and the handoff's failing list.

**This round (2026-11-19/20).** Phase C and the reviews.
- **What changed.**
  - A player now lands with one crew. Every building waits for a crew, and the town says who builds
    what and when.
  - The crew's first job is a choice: the mine road to the inland iron, or the small harbour.
  - The first export and the first ship each get a card. Every coastal town has an offshore signal a
    harbour can survey.
  - The nightscape shows the quay's lamps and a ship sailing in, on all three views.
- **Fixes found on the way.**
  - The town panel wrote the offshore signal into the save when first shown (the read is now pure,
    tested).
  - The tutorial's pump waited two months behind the copper mine (shortages first).
  - The harbour's order showed no income.
  - Every mine paid its whole road again, which cost the bots a fifth of their people.
- **Suites (final run on `faa0f97`).** 45 of 50 headless suites pass. The four Linux-known ones fail
  exactly as their Linux baselines. `v19_payback` misses twice:
  - the smelter, 372 days in year 4 against 120–300, as on the branch base;
  - food processing in year 6, 357 days against 100–220, where only one of five colonies has one to
    measure.

  `v18_systems`' top-bar checks had failed on every platform since 2026-11-12 and now read the 1.9
  format.
- **Openings (bot play, five seeds).** Both openings met stage three on every seed. Harbour first
  was sooner on four seeds, and later on a start with its own farmland.
- **Harness `spur-21fef0f`.**
  - 19 targets met. The 3 misses are standing: sloppy failure, the labour lever, the services
    budget.
  - Population at years 2 and 4 is 332 / 982.
  - The well-played bots fail 5 of 27 runs against 1 before crews, mostly the rush and
    research-first bots at stage five's last date.
- **Open for the player.**
  - How scarce crews should be: at ¥900 the bots train 12–24.
  - What the bay should look like from orbit, on a real GPU.
  - Jobs, which held growth from 200 to 600 people in every game.


---

# Colony Charter 1.9 — Progress (in development)

Started 2026-11-07 from the user's request after a friend compared the 1.8 demo with TerraGenesis:
the planet should turn, show day and night with lit towns and roads at night, the surface looked
too rough, and the map needs moving elements such as clouds (Plague Inc. / Rebel Inc. style). The
3ds Max models uploaded the same day (release `art-assets-20261107`) and the near-future set delivered on
2026-11-09 (release `art-assets-20261109`) are placed in the game. Balance
work follows `docs/superpowers/plans/2026-11-01-v19-money-and-models-instructions.md` Part A.

Evidence labels as in `CLAUDE.md`. Everything below ran in a Linux cloud container (Godot 4.5.1
Linux build, software OpenGL under Xvfb); the Windows EXE, real-GPU frame times and a human playtest
are **NOT_RUN**. Branch `v17` is on GitHub (`origin/v17`).

## Done

| Area | What | Evidence |
|---|---|---|
| Moving globe | Planet spins (240 s a turn at 1×, faster with game speed, eases out on drag, zoom and click; a clicked site stays in view); fixed sun with a real terminator; seasons over the 360-day year move the terminator and the ice edges; moonlit night side | source-project window, screenshots viewed (`evidence/v17/art/dynamics/globe_*.png`) |
| Night lights | Warm town lights, cold industrial lights and dotted road lamps after sunset on the globe and the flat map; town patches fade at night | screenshots viewed |
| Surface | Atlas stores geography; per-pixel palette shared by globe, flat map and regional ground: smooth coastlines, blended biomes, sun-lit relief, ocean depth, glint, organic ice caps | screenshots viewed |
| Clouds | Animated clouds on latitude winds, cross-faded layers, drifting cyclones with eyes and arms, day/night cloud lighting, twilight tint, atmosphere rim lit by the sun | screenshots viewed |
| Region dynamics | Day and night from the site's place on the globe; lit windows, lamp pools, headlights; trucks, vans and buses on the service roads; smoke from working plants; drifting cloud shadows; rippling water; smooth cargo motion on globe and flat map | screenshots viewed |
| Settings | 「地图画面」: spin, day/night with lights, clouds/weather (off hides clouds) | automated tests (ui_contract) |
| Models | `tests/art/convert_models.gd` turns the FBX exports of releases `art-assets-20261107` and `art-assets-20261109` into 122 runtime meshes (49 s, 6.9 MB, two runs byte-identical); each model within its triangle target, shares weighted by colour slot (five with open crop strips, tree crowns or glass panes are recorded exceptions); all 61 building kinds drawn with their own models but `service`; 36 kinds with their own construction state, the rest with the shared site kit; terraforming stages and district levels drawn as they are finished; shuttle (parked and in flight), its pad, trucks, vans and buses modelled; closed-mine plots by ore, landing pods, street lamps, route gantry, road closures, bridges, harbour quay and cargo ship placed in their game contexts; suite `v19_art` checks budgets, slots, footprints, depth, construction states and stages (plan B7) | automated tests (`v19_art` 1,063 checks), contact sheets viewed (`evidence/v17/art/gallery/`), region, shuttle and great-work captures viewed (`evidence/v17/art/models_1109*/`) |
| Tests | Linux runner `tools/run_tests.py`; seam test measures under 1.8 lighting; terrain identity checks geometry | automated tests |
| Money | Market floor 0.55; +2.5% cash per further copy (to ×1.75; homes, great works, roads and outposts exempt); data centres ×0.85 and foodworks beyond the sixth ×0.8 per copy; administration grows with residents (scale 2,500) and settlements (+15% each); optional public services budget (levels 0–3); bots use it by cash cover; harness rows for cash cover, absorption and budget use; new suite `v19_money` | balance harness (quick, Linux), automated tests, screenshots viewed (`evidence/v17/art/pages/`) |
| Money readouts | Economy page: 「现金可支撑 N 天」 by band (red under 30 days; at 180+ once 90 days are seen, a hint where idle money could go), the administration line with the step for 100 more residents and one more settlement, market rows with the price after another 100 t and the floor price (「市场已饱和」 at the floor); cover days in the top-bar money tooltip; advisor line, in this order, for export income leaning on mines with under 360 days of reserves, counting goods made from their ore (a third or more of the month's export value; the share also shows on the economy page), for a good exported at its floor and for idle money. One `Sim.cover_view()` serves the page, the advisor and the bots | automated tests (`v19_money` 56 checks, `ui_contract`), developer probe (`tests/balance/mine_probe.gd`, normal play and `--hands-off=1080`), screenshots viewed (`evidence/v17/art/pages/economy*.png`, `economy_day1440.png`) |

| Spending by sink | Every payment from public cash is summed by sink and colony year (`state.stats.sinks`); economy page 「钱花在哪」 for the last four years; harness INFO row | automated tests (`v19_money`), screenshots viewed |
| Career transfer | After the award, public cash buys career funds at 2 : 1, up to ¥200,000 a colony year; career page control; bots move cash above 240 days of cover | automated tests (`v19_money`) |
| Commissioned research | Levels 1/2 on a project its own team works on, ¥100–450 a point by tier, ×1.25 per other commission; research-page switch with cost and days saved; optional spending (this and services) only from cash beyond two days of bills | automated tests (`v19_money`), screenshot viewed (`research_commission.png`) |
| Saves | Schema 5 in `ColonyCharter/v19`; 1.8 and 1.7 saves are read from their own folders, upgraded on load with a log line, and never written | automated tests (`v19_money`; the Windows-recorded save suites are for the Windows run) |
| Paybacks | New suite `v19_payback` (plan bands; mines in year 6, factories in year 4); heavy mines dearer with twice the upkeep, renewables cheaper and stronger, commerce ¥0.3, foodworks dearer, processors valued at the import price | automated tests (`v19_payback` 39 checks) |
| Windfall case | Harness case: the balanced bot with ¥1,000,000 on day 1,080, compared on the same seeds | balance harness |
| Late great works | Terraforming (three stages, planet tint), capital district (five levels), exchange, shipyard, emergency network; five tier 4–5 techs (127 in all); later stages and levels buy missing materials and parts at import price, as the first stage does; bots build each step when cash pays for it with its supplies and keeps 10 days of expenses (60 before the award), save for the next one after the award and chase its technologies; harness INFO row; stand-in models | automated tests (`v19_money` 155 checks, `v19_payback` unchanged), developer probe (balanced bot, 10 years: emergency network on seeds 260129 and 42, capital district on 42), screenshot viewed (`terraform_compare.png`) |
| Shuttle | Short-range shuttle line from the start: straight hop ≤ 3,500 km, pads in 10 days, 1–2 days a trip, 4 t a day, ¥8,000 + ¥2/km, ¥40 a day, 30× a road's fee; stands down when a road or sea route opens; not part of the contract network; cyan arcs on the maps, a pad and a flying craft in the region | automated tests (`v19_money` 149 checks), screenshots viewed (`evidence/v17/art/shuttle/`) |
| Building icons | `tests/art/bake_icons.gd` renders every kind's model (tint, scale, the map's daylight) to `assets/icons/buildings/<kind>.webp` (lossless), 128 px with mipmaps; build card 64 px, building column 32 px; goods keep their SVG pictograms | screenshots viewed (`evidence/v17/art/pages/settlement.png`, `build.png`), automated tests (`ui_contract`, `v16_ui_tests`) |
| Playtest preview | `ColonyCharter-1.9.0-preview-20261109-Windows-x64.zip` (54 MB: EXE, pack, licences, 预览版说明.md, CHANGELOG, PLAYTEST) exported in the cloud from commit `f7311cb` with the official 4.5.1 templates; no test material in the pack; the pack boots, lands, builds and runs 40 days with a clean audit on the Linux engine. The EXE has not been run on Windows. Second preview with the interface pass: `ColonyCharter-1.9.0-preview-20261109-ui-Windows-x64.zip` (55 MB) from branch `v17-ui-redesign` at `7141d6a` (pull request #1, not yet merged into `v17`); its pack boots, lands, builds, runs 40 days with a clean audit, and orders a building and shows the research topics through the new pages on the Linux engine. Not run on Windows either | exported EXE (pack smoke-tested on Linux, not on Windows), screenshots viewed |
| Windows sheet | `docs/superpowers/plans/2026-11-08-v19-windows-verification-instructions.md` and `tests/art/frame_time_probe.gd` for the run only the user's PC can do | — |
| Interface pass (branch `v17-ui-redesign`, for review) | One style system in `ui/design.gd`: a neutral foundation in the 1.8 colours, a research variant (turquoise, cyan, yellow) and an industrial one (charcoal, gray-teal, muted gold); cached style boxes; skins reset on every reuse; fine borders with cut corners, focus ring, type scale (no text under 14 px on the two pages). Construction page in three parts (`ui/build_page.gd`: catalogue with quick orders, the chosen facility with a baked view of it at work, ledger with verdict and main order); 61 facility views (`tests/art/bake_facility_views.gd`). Research page (`ui/research_page.gd`): direction colours and icons, topic state tags, effects, unlock icons, progress, actions. The modal frame, navigation, facility list, production management and facility column follow their variant; the tutorial outline stays above dialogs. Decisions in `DECISIONS.md` (1.9: interface pass) | automated tests (new `v19_ui` 64 checks; `ui_contract`, `v16_ui_tests` 20, `v17_research` 144, `v17_bugs` 43, `v17_tutorial` 237 checks as before), source-project window: 34 captures and 52 checks (`ui/capture_suite_ui19.gd`: 4 window sizes × 3 text sizes, every action scrolled into view, keyboard focus, tooltip, page switching), screenshots viewed (`evidence/v17/ui19/`, a selection in `docs/v17/ui19/`). The two reference images were not available in the session; human playtest NOT_RUN |
| Fix tips: top bar and units (branch `v17-fix-tips`) | Goods kept in hundreds of tonnes and shown in tonnes (×100; prices per 100 t; money, balance and saves unchanged); each top-bar figure with its change a day (7-day mean); labour (劳动力, crews and research teams) in place of population; iron, copper and crystal icons in their map colours, names first in the tooltip; autosave every 90 days | automated tests (`ui_contract`, `v16_ui_tests`, `v16_manage_target_review`, `v19_money`, `v19_ui`), screenshot viewed (`docs/v17/fix_tips/top_bar.webp`) |
| Fix tips: region scene | Generated worlds only: the ground runs 520 units past the field under haze and a sky colour (no edge or underside in view); every visible plot cut into the slope as a level terrace, relief compressed on a log curve; the landing pods on a free cell; vehicles on service lanes between plot rows, stopping at the front of each pad and leaving by corners and junctions; the quay on a real shore clear of plots. 1.6 worlds unchanged to the vertex | automated tests (new `v19_region` 15 checks; `world_v16_terrain_identity`), screenshots viewed (`docs/v17/fix_tips/region_*.webp`, `quay_shore.webp`) |
| Fix tips: town lights | Satellite-style town lights drawn in the globe and flat shaders: frayed outline, arms and suburbs that come with size, a street grid with dark blocks; a landing is a small patch, a town of 3,000 a sea of light; roads stay lit as before | screenshots viewed (`docs/v17/fix_tips/lights_*.webp`) |
| Fix tips: transport | A sea link is two small cargo docks (no orbital freight station needed, ¥6,000 + ¥0.5/km); medium docks (no technology) and large ones (沿海航运); roads paved (铺装道路), then four-lane trunk roads (连续摊铺机); each level raises capacity, takes a day off and adds upkeep; the transport page shows each link's level and next step; three event-only gift technologies (红球快运车队, 高速货轮, 大型散货船) from three new events, not counted for the charter; red trucks and larger quays and ships as stand-ins | automated tests (new `v19_transport` 88 checks; `v17_sites`, `v17_research`, `v17_events`), source-project window, screenshots viewed (`docs/v17/fix_tips/transport_levels.webp`, `research_gifts.webp`, `town_redball.webp`) |
| Fix tips: surveys | Three ground surveys (±12%, ±6%, ±3%; 15, 25, 40 days; ×1, ×1.5, ×2 the price), settled sites included; the button shows price, days and the range it leaves | automated tests (`v17_sites`), screenshots viewed (`docs/v17/fix_tips/*_survey.webp`) |
| Fix tips: documents | Technology tree overview `docs/v17/TECH_TREE.md` (generated by `tools/tech_tree.py`); model fix sheet for GPT `docs/superpowers/plans/2026-11-12-v19-model-fix-sheet.md` (corners past the terrace in 35 of 67 building models, foundation skirts, scale outliers, docks, gift ships, red-ball truck, terrace pieces) | — |
| Picture quality and terrain (2026-11-13) | 高画质 (Forward+) chosen in the settings, saved in a user override file, applied on restart, automatic fallback to the standard renderer; 4× anti-aliasing in both renderers (2× and off selectable), SMAA in Forward+; Forward+ colour grade, town ambient occlusion, glow on lights only, soft shadows, real lamp lights at night; natural ground on generated worlds (smoothed relief, layered detail, beach profiles, calm town ground, graded pads, no walls or mesas); no sea at inland sites; no hexagon plates (ore rocks, farmland patches, optional rings); candidate names only while choosing; smaller cargo dots; stage three's deadline a year later; research-complete notices | automated tests (new `v19_graphics`; `v19_region` with terrain checks: steepest step 0.71, town 0.12), source-project window in both renderers (software Vulkan for Forward+), screenshots viewed (`docs/v17/quality/`) |
| Coast flicker (2026-11-13) | The land jumped where it met the sea: z-fighting. Beaches now cross the waterline at a slope (a straight share in the beach profile, and a smooth curve away from the sea's level), and the town view has its own near plane (0.5, ten times finer depth). A first fix with a fixed lift snapped the coast into steps and was replaced the same day | automated tests (`v19_region`: crossing slope p5 0.21, crossing spread 0.26), source-project window, screenshots viewed (flip masks: 4,660 land/water flips over seven views before, 563 after, with only the near plane moved) |
| Events rewrite (2026-11-13) | GPT's full design: 86 events rewritten, 20 new, 249 nodes, 14 long chains; stakes in days of income (mostly 2–20, up to 80); same ids, versions and nodes for every old event, nothing new to the engine; `v17_events` follows the new chain paths | automated tests (`v17_events` 161 checks; data checks against the engine and the old file), balance harness (see BALANCE.md) |
| Deadlines, payback, event options (2026-11-14) | Stage four's deadline 14 months later on every difficulty (normal 2,100 → 2,520), stage five's (the contract's last date) unchanged; `v19_payback` asserts each band on the median over five seeds (`--seeds=3` for a quicker check); every event option names its ending, or its next step and when, or a gamble's outcomes with their odds; a measured diagnosis of why the events still feel thin (`docs/v17/EVENTS_DIAGNOSIS.md`) | automated tests (`v19_graphics`, `v19_payback` 43 checks, event suites), screenshots viewed (event page with the new option lines) |
| Event payoffs, engine side (2026-11-14) | Steps 1-4 of `EVENTS_DIAGNOSIS.md`, approved: ending scenes (`outcome`, a card per ending, kept on the events page, or else what changed; a default marked), nodes that pause (`critical` on a node), effects listed on the town panel and economy page with days left and named after their cause on the events page, 「通讯」 on the maps while an event is open, landmarks (eight kinds drawn around the town, permanent effects, listed on the panel), new gifts' effects in words. GPT writes the content: `docs/superpowers/plans/2026-11-14-v19-events-payoff-sheet.md` | automated tests (new `v19_event_payoff`, 45 checks; event suites), exported pack (two years with events), source-project window, screenshots viewed (`docs/v17/events_payoff/`: landmarks around a town, the town panel, an ending card) |
| Faster immigration (2026-11-14) | Free arrivals 9 → 11 a month in every town (+22%), the user's choice for stage three's population goal instead of an economy retune | automated tests (population and economy suites), balance harness (BALANCE.md) |

## Money: quick harness on Linux (3 seeds, standard)

| | 1.8.0 on Linux | first pass (plan values) | gentle | stronger variant | **kept: gentle, homes exempt** |
|---|---|---|---|---|---|
| Balanced award, median | day 2,464 (9/9) | day 2,548 (8/9) | day 2,400 (9/9) | day 2,398 (9/9) | day 2,599 (9/9) |
| Research-first award, median | day 2,204 | day 2,554 (8/9) | day 2,274 (8/9) | day 2,416 (8/9) | day 2,479 (9/9) |
| Cover day 720 to award, median / p90 | 74 / 158 | 12 / 76 | 15 / 101 | 11 / 69 | 16 / 85 |
| Cover one year after award, median / p90 | 85 / 634 | 24 / 60 | 8 / 40 | 3 / 82 | 12 / 81 |
| Absorption, years 3–7 | 79–111% | 95–107% | 92–111% | 96–110% | 93–108% |
| Taken over (rush, balanced, research-first) | 0 / 27 | 3 / 27 | 2 / 27 | 1 / 27 | 2 / 27 |
| Wage lever | +26% | +17% | +18% | +23% | +23% |
| Services budget used (balanced) | - | - | 7 / 9 runs | 4 / 9 runs | 6 / 9 runs |
| Openings: spread of medians | 24% (miss) | 8% | 17% (miss) | 23% (miss) | 4% |

The last column is the kept configuration, confirmed by the run in `BALANCE.md` (label `1.9-money-linux`,
2026-11-07T14-03-08). It meets every row a quick run measures except two: the services budget is used in 6
of 9 balanced runs (the row asks for 8), and the sloppy row needs hard difficulty, which only full runs play.
The openings row passes (medians 4% apart; the workers opening favours rush). Award medians are about 200
days later than the gentle run without the exemption, but single runs moved both ways (balanced, science,
seed 260129: day 2,304 → 2,174; capital, seed 20261029: 2,706 → 3,042). Both takeovers are rush runs that
missed the main contract deadline (days 3,091 and 3,248). With 3 seeds a cell all of this may be noise: a
full run (10 seeds, 3 difficulties) on Windows is still to do.

## Late great works and the shuttle: quick harness and probes (Linux)

Quick harness `1.9-great-works-shuttle-linux` (commit `c5cb6d0`, 2026-11-08T20-29-06, 51 runs, 0 audit
errors): balanced award median day 2,694 (9/9), research-first 77 techs by day 2,403, cover from day 720
to the award 12 / 102 days (median / p90) — the same as the run before the great-works bots, because the
bots before the award are unchanged. After the award the cover is 56 / 150 days (was 18 / 148): the bots
now save for the next great work. Absorption 95–109% in years 3–7, wage lever +23%, determinism 3/3.
Late great works standing at the end: emergency network 6 of 21 runs, capital district 1 (level 3),
terraforming, exchange and shipyard none. Takeovers 4 of 27 (two research-first, two rush; the rush runs
spent nothing on late works, so this is run-to-run spread, not the change). Misses, the same three as
before: openings (research-first is best with every opening), sloppy (needs hard difficulty, which only
full runs play), services budget (6 of 9 runs; the row asks for 8).

Developer probes (`tests/balance/bots/balanced_bot.gd` and `rush_bot.gd`, scripts in the session's scratch
area, figures here):

- 15 years, balanced bot, seed 42, after the bots learned to clear ground in any full town (`3c19e77`):
  all five works are built — emergency network from day 2,850, capital district 3,480 (level 5),
  shipyard 4,250, exchange 4,720, terraforming started 5,250. Seed 20261029 (award day 3,033): district
  level 5 and the emergency network started by day 5,400; its shipyard was unlocked on day 5,337. The
  tier 4–5 technology chains (6–8 techs) set the pace; the harness ends 2–3 years after the award.
- Shuttle, rush bot, the quick seeds and openings, 4 years: 8 of 9 games open shuttle lines, 13 lines
  carrying 146–510 t each; 12 stood down when the road to the same outpost opened. The harness has a
  "Shuttle lines" INFO row from `3c19e77` on.
- Final quick harness `1.9-final-linux` (commit `3c19e77`, 2026-11-08T21-57-33, 51 runs, 0 audit errors,
  in `BALANCE.md`): the same as the run above except the emergency network stands in 7 of 21 runs and the
  cover a year after the award is 56 / 127 days. Shuttle lines: 8 of 9 rush runs, 20 lines, all 20 stood
  down when a road or sea route to the same settlement opened.

## Test results (Linux)

Interface pass (branch `v17-ui-redesign`, code at `6c69c6c`): the 42 headless suites other than the
`review_*` tools, 38 pass and 4 fail. The 4 are the same as on untouched `origin/v17` (`d9ef9dc`), run the
same day in a scratch worktree, with the same failing checks and counts (`v17_saves` 97 checks / 1 failure,
`v17_tutorial` 237 / 0 plus its 1.6-save script error, `v18_systems` 78 / 3, `world_v16_seed`). New
`v19_ui`: 64 checks pass. Of the `review_*` tools, `review_save_nested` passes and the rest fail on their
`D:` paths, as before. Window suites were not re-run.

Headless suites at commit `3c19e77`: 37 pass, 4 fail — the same 4, with the same failing checks, as the
untouched 1.8.0 source on Linux (`v17_saves`, `v17_tutorial`, `v18_systems`, `world_v16_seed`:
Windows-recorded fixtures and world hashes do not reproduce on the Linux build). `v19_money` (155 checks),
`v19_payback` (39 checks) and the new `v19_art` (479 checks) pass; `ui_contract` checks the economy page's
cover, administration and floor lines; `v17_contract_population` follows the 1.9 administration rule. Of
the `review_*` tools, `review_save_nested` passes; the others fail on both versions on their hard-coded
`D:` output paths (they then wait for the runner's 540 s timeout, so they were not run this time). Window
suites under Xvfb: `world_v16_visual` and `world_v17_seam` pass; `v16_interaction_probe` and
`v16_scroll_probe` fail with the same script errors as 1.8.0 on Linux (22 and 8, counted on both): the
1.6 acceptance fixture they load does not rebuild its world on the Linux build.

Fix tips (branch `v17-fix-tips`, code at `5c50b0f`): of the 44 headless suites other than the `review_*`
tools, 39 pass and 5 fail: the same 4 Windows-recorded ones as before (`v17_saves`, `v17_tutorial` with its 1.6-save
script error, `v18_systems`, `world_v16_seed`) and `v19_payback` (light iron mine, item 9 below). New
`v19_transport` (88 checks) and `v19_region` (15 checks) pass. Window suites under Xvfb:
`world_v16_visual` and `world_v17_seam` pass; `v16_interaction_probe` (24 script errors) and
`v16_scroll_probe` (8) fail on their 1.6 fixture as before. Quick harness `fix-tips-5c50b0f`: 51 runs, 0
audit errors (BALANCE.md). Exported pack `ColonyCharter-1.9.0-preview-20261112-Windows-x64.zip` from
`fef2eb7`: on the Linux engine it boots, lands, builds, runs 40 days with a clean audit and opens the
transport, construction, research and economy pages and the region with no script error; not run on
Windows.

Event payoffs and faster immigration (code at `8c3506e`): on `82a85f3`, of the 46 headless suites
other than the `review_*` tools, 41 pass and 5 fail: the same 4 Windows-recorded ones and
`v19_payback`, whose miss moved from the light iron mine to the smelter (item 16). After the events
page fix, the 14 event and interface suites ran again and pass (`v19_event_payoff` 45 checks).
Quick harness `immigration-11`: 51 runs, 0 audit errors (BALANCE.md). Exported pack
`ColonyCharter-1.9.0-preview-20261114-payoff-Windows-x64.zip` from `8c3506e`, on the Linux engine:
the standard smoke is clean (deadlines 360 / 900 / 1,860 / 2,520 / 2,880, immigration 11 a month);
two years with every event answered, on seeds 20261029 and 260129, give 15 and 9 endings, 9 and 5 of
them saying what changed, a card for the newest ending, the effect lines on the town panel and the
economy page while effects act, and no audit problem, refusal or script error. The colonies, played
passively, fail on days 493 and 422, as before. Not run on Windows.

## Not done / open

1. Windows: re-record the capture fixtures (rules and save schema changed), rebake the menu atlas,
   run every suite, export the EXE and measure frame times on a real GPU
   (`tests/art/frame_time_probe.gd`; the cloud and flat-map shaders are the heaviest). Step by step,
   with which way to fix each miss: `docs/superpowers/plans/2026-11-08-v19-windows-verification-instructions.md`.
2. Models: the 2026-11-09 delivery is in the game (every kind's own model and most construction states,
   the great works' stages and levels, the shuttle, its pad and the vehicles). Still to model, per the
   brief: `service` (the private enterprise's site; the commerce arcade stands in), the level 2–3
   upgrade add-ons, colonists, and four key-art renders for the menu and award screens. The 25 kinds
   modelled before 1.9's brief (apartment, arcology, clinic, …) keep their present-day look and have
   no construction state of their own.
3. The converted models and icons are committed. Converting again is only needed after a new delivery; on the
   user's PC `--source=D:\勇敢新世界` finds every `art_reserve/` pack, then re-bake the icons (window) and
   run the import.
4. Building icons are baked from the models; re-run `tests/art/bake_icons.gd` (window) and the import
   whenever converted models change.
   The plan's menu and award images wait for key art in the new look (requested in the model brief).
5. Money: every plan A2 item is in; what is left is measurement. The full harness run (10 seeds, 3
   difficulties) is for the Windows run. No late great work is dropped: the harness ends before the
   late chains finish, and a 15-year game builds all five (DECISIONS.md).
6. The README still describes the 1.8.0 release; its 「后期钱会花不完」 limitation (in
   `docs/HISTORICAL_README_1.8.md`) is answered in the 1.9 release notes once the full run confirms the
   money rows.
7. **Found, not fixed: a won colony can still be taken over.** Balanced bot, seed 260129, capital
   opening: awarded on day 2,527, then taken over by the company on day 3,787 while holding ¥498,000,
   for "持续住房或就业不足" — its capital (1,090 people) has 486 idle workers for 357 jobs and no free
   ground, because new homes took the ground as it grew. The bot from before this session's changes is
   taken over the same way (day 4,043), so the cause is older than the great-works work. The 10-year
   harness never sees it. Ways out, for the user to choose: a bot that keeps ground for jobs and clears
   it for workplaces when idle workers pile up (what a careful player does); or a softer company rule
   after the award (premise change); or both.
8. Interface pass: compare both pages with the two reference images (`S2-kasako-inspired-research.png`,
   `S1c-kasako-construction-dark-muted.png`, not available in the cloud session) and tune `PALETTES` in
   `ui/design.gd`, the only place the colours live; look at both pages on Windows with a real GPU at 100%
   and 125% display scaling; merge the pull request after review.

9. **Fix tips: `v19_payback` misses on the light iron mine** (63 days in year 6 on seed 260129, band
   70–150 with 5% slack). Since sea links need no freight station the balanced bot's colony settles
   another coast first and its iron market is not saturated in year 6 (5.57 against the 4.40 floor);
   clean runs of the commit before gave 72 and 69 days, three variants of this change 59–64. A dearer
   light iron mine (2,250) does not fix it (61 days on its own path, and two more checks missed), so the
   single-seed year-6 figure follows the colony's path. Recommended, for the user to approve: assert
   the payback bands over several seeds (median per kind) instead of one seed.
10. **Fix tips: labour lever +6% (MISS) on the quick run** (+23% before). It is noise from the event
    dice (probes in BALANCE.md, 1.9 fix tips: +15% and +16% on unchanged code with nudged dice, +35%
    on this code without its extra deck rolls); its central value looks like about +15%, under the
    20% bar. For the user: measure it over more seeds, then decide whether wages need a stronger pull.
11. Fix tips, models: `dock_medium`, `dock_large`, `ship_fast`, `ship_bulk` and `vehicle_truck_redball`
    are drawn by stand-ins until delivered; the fix sheet lists them and the model fixes. The terrace
    pieces (`terrace_wall`, `terrace_stair`, `cliff_habitat`) need placement code once they arrive.
12. Fix tips on Windows: look at the region scene's far landscape and haze and the town lights at
    100% and 125% scaling, and measure frame times with them (`tests/art/frame_time_probe.gd`).

13. Picture quality on Windows: choose 高画质 in the settings, restart, compare with the standard
    renderer at 100% and 125% scaling, and measure frame times in both
    (`tests/art/frame_time_probe.gd`, once with `--rendering-method forward_plus`). Both Vulkan and
    Direct3D 12 should run; a card without either falls back to the standard renderer and the
    settings page says so. Steps: the Windows sheet, section "Picture quality".
14. Stage three's deadline moved a year later as asked. Answered on 2026-11-14: stage four moved 14
    months later (normal: day 2,520), stage five unchanged as the contract's last date (2,880).
15. Events: GPT's rewrite is in (`docs/v17/events_rewrite/`, 106 events). Its 18 requests for new
    mechanics (node-level pauses, single-road effects, cancellable upkeep, casualty records, and so
    on: `04_奖惩与开发交接.md`) are not built; GPT wrote fallbacks with today's effects. Quick
    harness: bots that weigh event costs by their days keep 8 of 9 balanced awards (median day
    2,686), and income grows ×3.4 from year 2 to year 6 (×4.2 before the rewrite); with the old flat
    valuation the bots took every long penalty and 3 of 9 were taken over. Playtest the new stakes:
    GPT's own aim is a net 5–10% of income from events over ten years.
16. Payback over five seeds (as the user agreed): one band misses. Before faster immigration it was
    the light iron mine in year 6 (median 65 days, floor 66.5 with the tolerance); with it, the mine
    is in band (67) and the smelter misses in year 4 (median 354 days, ceiling 315). A dearer iron
    mine moves the miss the same way; the two trade through the ore supply (DECISIONS.md), so a fix
    means retuning ore, the processing plant and the smelter together. The user's call.
17. Events still feel thin (the user, 2026-11-14): diagnosis in `docs/v17/EVENTS_DIAGNOSIS.md`.
    The engine side (steps 1-4) is built; GPT writes the content on branch `v17-events-payoff` from
    `docs/superpowers/plans/2026-11-14-v19-events-payoff-sheet.md`. When it lands: check the data
    against the contract (outcomes on every ending, landmark kinds and limits, effect sizes, gift
    technologies), run the event suites and the harness, and capture a finale and a landmark.
18. Landmarks are drawn from plain shapes; real models for the eight kinds can go to the model team
    (a short sheet like `2026-11-12-v19-model-fix-sheet.md`).

**Resume here.** Read `CLAUDE.md`, this section, then the 1.9 instructions in
`docs/superpowers/plans/2026-11-01-v19-money-and-models-instructions.md`.

---

# Colony Charter 1.8 — Progress

## Final summary

**1.8.0 is built and packaged in `delivery\v17`. Of the 24 rows below, 20 pass, 3 miss and 1 is NOT_RUN.** The request is in `V18_BRIEF.md`, the design in `V18_PLAN.md` and `DESIGN.md`, judgment calls in `DECISIONS.md`. Figures are the balance harness at `evidence/v17/balance/2026-11-01T03-10-20.json` (480 runs) and the exported EXE (`evidence/v17/perf`, `evidence/v17/exe_drive`).

### What changed, point by point

| # | Request | Result |
|---|---|---|
| 1 | Governor in 6-8 years on standard | Median day 2,454, 6.8 years; at 6× about 35 minutes of play |
| 2 | Pollution no longer a distrust source; exponential | Planet-wide, out of `company.gd`; 0.5% at most in year 3, 33% by year 8 if ignored, 2.9% for a colony that deals with it |
| 3 | Speeds | 1×, 3×, 6× |
| 4 | 工人 → 工程队, 研究员 → 研究团队 | Every string; a test scans rule and UI files |
| 5 | Resource table | Total and monthly change; power and water show supply and surplus, since neither is stored |
| 6 | Distrust gauge, slower rise | Gauge beside the map with thresholds and the day's change; largest daily rise 0.52 |
| 7 | Research by cards | 4 categories, 3 random cards (4 with a technology), pick one, send a team; redraw for money. What the charter needs is always dealt |
| 8 | Roads take longer | Median first road 146 days; from distance |
| 9 | Islands | Ordinary starts; sea routes with no technology, ports at both ends |
| 10 | Building column | For the selected settlement: under way first, with date and bar |
| 11 | Longer builds | 12-35 days basic, 45-120 advanced, 200-300 great works |
| 12 | Events | About 30% of the pool off in each run, 45% of draw days empty, seeds share 47% of what fires; all text rewritten |
| 13 | More technology | 122 technologies, 39 new buildings (56 in all) |
| 14 | Two settlement types | Residential and frontier, chosen when the expedition leaves; buildings belong to one or both |
| 15 | Real planets | 0.6, 1.0, 1.3 Earth radii; every route measured on that sphere |

### The bar in `V18_BRIEF.md`

| Area | Target | 1.7.1 | 1.8.0 | |
|---|---|---|---|---|
| Balanced award, standard | 2,160-2,880 | day 173 | day 2,454, 27 of 30 awarded | PASS |
| Balanced award, easy | 1,800-2,520 | day 156 | day 2,343, 28 of 30 | PASS |
| Balanced award, hard | 2,520-3,240 | day 211 | day 2,709, 27 of 30 | PASS |
| Floor | rush never before day 1,440 | day 107 | day 2,086 | PASS |
| Openings: medians | within 15% | 11% | 2,752 / 2,623 / 2,294, 20% from first to last | **MISS** |
| Openings: best bot | differs by opening | yes | research-first on all three | **MISS**, same row |
| Passive bot | review by 150-400, takeover by 400-900 | 60 / 150 | 168 / 438 | PASS |
| Sloppy bot | review everywhere, takeover on hard | yes | yes, 30 of 30 on hard | PASS |
| Population | 300 by year 2; 800 by year 4 | - | 385 / 946 | PASS |
| Labour lever | wage 1.0→1.3 moves immigration 20% | +29% | +26%, from year 2 | PASS |
| Research, balanced | 40 technologies, all categories, teams 10-20% | 5 of 20 | 40, 4, 12% | PASS |
| Research-first | more technologies, award in band | 8, day 181 | 74, day 2,163 | PASS |
| Technology pool | 100, 4 categories, 30 new buildings, offers differ | 20 | 122, 4, 39 | PASS |
| Money | reinvest 60%; year 6 income 2.5× year 2 | 84%, ×3.76 | 92%, ×3.70 | PASS |
| Export mix | no good above 60% | worst 65% | median 30%, worst 41% | PASS |
| Pollution | under 2% through year 3; no-control 15% by year 8; no company source | - | 0.5%; 33%; test holds it | PASS |
| Distrust | largest daily rise 0.8 | - | 0.52 | PASS |
| Events | 60 short, 10 chains; 25% off; 1 pause per 40 days at most; 25 distinct | 28, 6 | 71, 12; 30%; 1 per 215; 53 | PASS |
| Geography, 200 seeds | radii, site counts, 3 start pairs, islands can start | - | all hold; worst world 3.0 s | PASS |
| Roads | first road 3-10 months | - | 146 days | PASS |
| Road trade-off | cheaper is slower on 30-70% of pairs | 54% | 90% of 2,568 pairs | **MISS** |
| Determinism and audits | identical at 2,880 days and any speed; 0 audit errors | yes | 3 of 3 replays; 1×, 3×, 6×; 0 errors in 480 runs | PASS |
| Saves and speed | 1.5 MB; 100 and 300 ms; no frame over 50 ms; warm page 100 ms; cold region 1 s | yes | 59 KB; 12 and 25 ms; 34 ms; 18 ms; 739 ms, worst frame 48 ms | PASS |
| Human playtest | - | - | NOT_RUN | NOT_RUN |

### Open issues

1. **Two rows miss.** The capital opening's median award is 20% later than the science opening's; research-first is the fastest on all three openings, so the best bot does not differ by opening. The road trade-off reads 90%: on real planets the cheap road is nearly always the slow one, so the row as written no longer fits, but it is reported, not redefined.
2. **Bots still lose some games.** 3 of 30 balanced runs on standard, 2 on easy and 3 on hard are taken over before an award, usually with money in the bank; one on standard and one on hard are taken over a little after one. A person may or may not hit the same walls. Rush loses 10-50% on standard and hard.
3. **Three rare failures that did not repeat.** Over the several hundred test and harness processes of this work: `v17_speed` crashed once in the engine (signal 11, main thread, in ordinary `refresh` code), a balance shard died once with no output, and `v16_interaction_probe` once read garbage while decoding a fixture. All three were under full load; 96 further `v17_speed` runs, the shard and the probe were clean. The same kind of crash was noted once in 1.7.0. The worker threads were reviewed and touch only their own data, so the cause is not found. The harness now re-runs a lost shard and says so.
4. **Money late in the game.** Balanced colonies hold about ¥500,000 a year after the award, and more in some runs. Great works and upgrades are not enough of a sink.
5. **New buildings use old models.** 39 new kinds borrow the closest existing 3D model and icon; the modelling task in `art_reserve` is separate.
6. Of the final capture images, the 1280×720 set at 20 px was viewed; see `VALIDATION.md`.

### Next three improvements

1. Play it: run `PLAYTEST.md`. Bots cannot say whether six years are fun.
2. Give frontier and residential towns more reason to differ, and late money something to buy.
3. Replace the borrowed models and icons with the new buildings' own.

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `V18_BRIEF.md`.

---

# Colony Charter 1.7 — Progress

## Final summary

**1.7.1 is built and packaged in `delivery\v17`. 22 of the 26 rows below pass; three are misses and one is NOT_RUN.** Nobody has played it through yet: these results come from tests, bots and scripts. The user's first impressions of 1.7.0 led to 1.7.1 (`CHANGELOG.md`).

### What changed

- A beginner tutorial on its own planet, with one-time tips afterwards.
- Generated planets with a character: six land layouts, five climates and three reliefs drawn from the seed; 14-40 candidate sites that the player names when settling; plots with uncertain estimates; two kinds of road and sea routes.
- Research that matters: 20 technologies that each unlock something, concentrated teams, paid research, megaprojects.
- A three-stage contract instead of a checklist; governor takes about 173 days at standard instead of 19, and building takes about twice as long as in 1.7.0.
- People who come and leave for visible reasons; wages and recruitment; prices that fall with exports; money with uses.
- 28 events and 6 chains that repeat with cooldowns and rarely stop the clock.
- Build dialog, site card, settlement panel, building list and economy page that answer what to do and why. Saves are 47 KB instead of 8-11 MB.
- Difficulty and openings that change the start and the pressure, not the rules.

### §5.2, 1.6 versus 1.7.1

| Area | Target | 1.6 | 1.7.1 | |
|---|---|---|---|---|
| Floor | rush bot not before day 90 | day 19 | day 107 | PASS |
| Balanced award, standard | 120-180 | day 19 | day 173 | PASS |
| Balanced award, easy | 90-150 | day 19 | day 156 | **MISS** |
| Balanced award, hard | 160-230 | day 42 | day 211 | PASS |
| Openings: medians | within 15% | 19 / 25 / 19 | 177 / 160 / 176 (11%) | PASS |
| Openings: best bot | differs by opening | - | rush, balanced, balanced | PASS |
| Passive bot | review ~60, fails ~150 | 87 / 137 | 60 / 150 | PASS |
| Sloppy bot | review everywhere, fails on hard | yes | yes, 60 of 60 on hard | PASS |
| Population | stage goal at award; 300 by 360; 600 by 720 | 78 / 80 | 425 / 973 | PASS |
| Labour lever | wage 1.0→1.3 moves immigration 20% | no wage policy | +29% | PASS |
| Research, balanced | 3 techs, 10-20% scientists, 15-30% spend | 0, 8%, 11% | 5, 13%, 17% | PASS |
| Research-first | 6 techs, award in band | 0, day 30 | 8, day 181 | **MISS** by a day |
| Money | reinvest 60%; income ×2.5 from 180 to 720 | 0%, ×1.16 | 84%, ×3.76 | PASS |
| Export mix | no good above 60% | worst 57% | median 30%, worst 65% | **MISS** on 1 of 60 runs |
| Events | 25 short, 5 chains; 1 pause per 20 days at most; 15 distinct; no early repeat | 10, 3; 1 per 60; 10; - | 28, 6; 1 per 38; 29; 0 repeats | PASS |
| Geography, 200 seeds | sites 14-20, 20-30, 28-40; 3 pairs; 3 archetypes; land 25-45%; 2-6 continents | not measured | 15-20, 20-30, 28-40; 3; 3; 25-45%; 2-6 | PASS |
| Road trade-off | cheaper is slower for 30-70% | - | 54% of 2,708 pairs | PASS |
| Determinism | byte-identical at 720 days and at any speed | replays identical | replays identical; 1×, 4×, 10× identical | PASS |
| Audits | 0 errors, with 50 fuzz runs | 0 in 950 | 0 in 950 | PASS |
| Save size | 1.5 MB at most | 8-11 MB | 47 KB at day 720 | PASS |
| Save, load | 100 ms, 300 ms at most | 209 ms, 242 ms | 10 ms, 20 ms | PASS |
| Autosave | no frame over 50 ms | not measured | worst frame 20 ms | PASS |
| Page open, warm | 100 ms at most | not measured | 18 ms at most | PASS |
| Region, cold | 1.0 s, no frame over 50 ms | not measured | median 766 ms, worst 826 ms; worst frame 45 ms | PASS |
| Tutorial | headless run, skip, replay | none | all pass | PASS |
| Tutorial, human first run | - | - | NOT_RUN | NOT_RUN |

1.7.1 figures are the balance harness at `evidence/v17/balance/2026-10-31T17-13-30.json` (950 runs) and the exported EXE on an i9-14900HX with an RTX 4070 Laptop GPU (`evidence/v17/perf`).

### Open issues

1. **Three misses, all small and all after slowing the builds.** Easy awards on day 156 (target at most 150). Research-first awards on day 181 (at most 180). One standard run of 60 sold 65% crystal after day 180 (at most 60%). Five full harness runs and three quick ones moved these by a few days without closing them, and the export worst case swung between 64% and 79%, so I stopped rather than keep bending other rules. They need the user's call: accept, or loosen build times a little.
2. **Late takeovers.** 18 of 180 balanced runs are taken over. 16 earned the award first and fail between days 450 and 713, most of them out of money (`BALANCE.md`). The bot never hands over, which is the game's answer to that moment, but the late economy may feel tight to a person too. The other 2 are easy runs with the workers opening where the bot never founds a second town. The game refused nothing and the same seed settles on standard, so that is the bot's blind spot.
3. **One unexplained crash in 1.7.0's tests.** `v17_speed` crashed once in the engine (signal 11, main thread, no C++ symbols) on about 40 runs and did not come back in 38 repeats. Cause unknown. Worth watching in playtests.
4. **Generating a world** takes about 0.7 s and up to 3.6 s on the hardest seeds, now that difficult planets may need more attempts. Every new game pays this once. A load pays it only if the cache folder was deleted, and then it is above the 300 ms target; the game keeps that folder.
5. **Planet types.** A draw that gives no playable world softens, so archipelagos and arid planets turn up less often than their weights say, and on 32 of 200 seeds the planet is milder than the menu's forecast. The menu therefore says 多半是, and the toast at the start and the world page show the real type. `v17_world_stats` keeps every type present and fails if fewer than 75% of seeds keep their draw.
6. **NOT_RUN:** human playtests, and a manual tutorial run in the EXE. The EXE run was scripted through its real buttons. `docs/v17/PLAYTEST.md` has a 30-45 minute checklist.
7. Of the final 144 capture images, 32 were viewed: every page at 1280×720 with 20 px text, the tightest case, and 8 at larger sizes. The rest were written without errors but not looked at.

### Next three improvements

1. Play it: run `PLAYTEST.md`, then fix the tutorial wording and pacing that a person trips on. Nothing else here can stand in for that.
2. Give the late game more to do when mines run out: lasting non-mining jobs, and a prompt towards handover before debt starts.
3. Measure the whole career in the harness: bots that hand over, so a second and third planet get balance numbers too.

**Resume here.** Branch `v17`. Read `CLAUDE.md`, then this file, then `PLAN.md`.

| Phase | State |
|---|---|
| 0 Infrastructure and baseline | Done (`v17-phase0`) |
| 1 Bugs, QA export, formatting | Done (`v17-phase1`) |
| 2 Foundations | Done (`v17-phase2`) |
| 3 Contract, population, economy | Done (`v17-phase3`), day-720 rows await Phase 5 |
| 4 Research | Done (`v17-phase4`) |
| 5 CC-GEO-2.0, sites, roads, plots | Done (`v17-phase5`) |
| 6 Events | Done (`v17-phase6`) |
| 7 Tutorial and UI content | Done (`v17-phase7`) |
| 8 Difficulty, openings, career, performance, release | Done (`v17-phase8`, `v1.7.0`) |
| After release: pace, names, building list, planet variety | Done (`v1.7.1`) |

## Done

- Phase 0: git with `1.6.0 baseline` and tag `v1.6.0`, `CLAUDE.md`, `tools/run_tests.ps1`, watchdog in every SceneTree test, fixture
  isolation, balance harness with six bots, 1.6 baseline recorded, §4 findings reproduced (`VALIDATION.md`).

- Phase 1: all 12 W1 bugs fixed with `v17_bugs` and `world_v17_seam`; QA data out of the export; `gdformat` commit proved behaviour-neutral.

- Phase 2: simulation split into modules; English keys; `Sim.geo` split from `state`; save schema 3 with migration; autosave on a worker; reconciler UI with cached pages; map split into layers with signature-gated updates. Harness identical to Phase 1.

- Phase 3: three-stage contract with licences and soft deadlines; attractiveness, immigration, wage policy, recruitment, births; market saturation; running costs; road upkeep and closure; costlier aid; needs-first imports; depleted mines idle; `build_forecast`; contract and population pages; bots rewritten on a shared `colony_bot.gd`.

- Phase 4: Appendix D's 20 technologies with tiers and prerequisites; R10 = 2.0; lab L2; paid research contracts; building upgrades that keep the building working; clinic, hydroponic farm, component plant and the `components` good; road paving; three megaprojects with their effects and milestones; prefab lab and head start for the science opening; tech-tree page with staffing previews; `v17_research` suite.

- Phase 5: CC-GEO-2.0 in `game/world/geo2/` (plate-driven continents, sea-level quantile, climate with rain shadow, per-cell attributes, D8 rivers); Poisson-disk sites with archetypes, quotas, Appendix G names and a playability validator; disk geo cache; `routes.gd` A* with valley, engineered and sea routes; plots instead of the building cap; surveys with uncertainty bands; hidden and deep deposits; road network with per-road dispatch, chains and no backflow; sea expeditions; workers follow jobs along roads; 1.6 saves migrate to sites, plots and roads; region view on a height field with instanced nature, baked building models, one-plane sea and ribbon rivers; map filters, automatic labels, colony footprints, climate ring; site panel with estimates.

- Phase 6: events repeat after a cooldown (120–360 days); notices never pause, decisions pause when critical or when the player asks for all to pause; money in events scales with recent income; every option checks money, goods, beds, hands, research and roads, and shows why it is disabled; 18 new short events and 3 new chains (没有目的地的客船, 零点八毫米的裂缝, 山脊里的空白图); rockfall opens its event when a road really closes; `v17_events` suite tests each new chain's endings, deferral, timeout and save/load.

- Phase 7: tutorial (Appendix F) with named conditions, non-modal coach panel with outline, skip, back, replay, contextual tips, quiet opening and a scripted first shortage; daily rollups (`stats.gd`); build dialog with categories, plot choice and forecast; site card with role hints, travel options and cost multiplier; settlement panel with fix buttons, grouped buildings and pinned actions; economy page with 30-day categories, 90-day chart, runway, goods table and price trends; arrivals and departures; in-transit goods on road cards; very fast speed; new guide copy; main menu with save summary and tutorial toggle; capture suite `ui/capture_suite_v17.gd` with bot-written fixtures.

- Phase 8: difficulty adds event and price pressure; openings differ as W12 lists; stewardship counts new income; food reaches the end of road chains; company tolerates tiny risk; sites keep ground for the town; deposits 1.25×; bots adapted; capture matrix; EXE build and scripted check; performance probe; atlas finishing off the main thread; README, CHANGELOG, PLAYTEST.

- After release (1.7.1): CC-GEO-2.1 with planet characters; build times about doubled, days kept; settlements named by the player, sites numbered until then; building list page; seed box no longer tied to the tutorial; rules retuned.

## In progress

Nothing.

## Next step

Nothing is planned. The user's playtest comes next (`docs/v17/PLAYTEST.md`).
