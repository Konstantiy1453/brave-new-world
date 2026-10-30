# 殖民契约 Colony Charter 1.7 — Improvement Instructions for Claude Code

| | |
|---|---|
| Project folder | `D:\勇敢新世界` (Godot project in `game\`) |
| Current version | 1.6.0 — world generator CC-GEO-1.6, save schema 2 |
| Target version | 1.7.0 — world generator CC-GEO-2.0, save schema 3 |
| Engine | Godot 4.5.1.stable.official.f62fdbde1, GDScript, GL Compatibility, Windows x64 |
| Engine binary | `D:\勇敢新世界\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe` |
| Written | 2026-10-31, from a code and gameplay review of 1.6. The findings in §4 were reproduced by running the 1.6 production code headless. |

> **Kickoff prompt** (for the user to paste into Claude Code, opened at `D:\勇敢新世界`):
> “Read `docs/superpowers/plans/2026-10-31-v17-improvement-instructions.md` completely and carry it out phase by phase, starting with Phase 0. Keep `docs/v17/PROGRESS.md` up to date so the work can resume in a new session.”

---

## 1. Mission

Version 1.6 is technically sound: a deterministic fixed-step simulation, audited ledgers, robust save validation, a coherent art direction. It is not yet a game with real decisions. A plain rush wins the first contract on day 19 at every difficulty. After that nothing asks anything of the player. Every seed gives the same six regions in the same roles. Research is optional, and events run out by day 60.

Turn it into a game where geography, people, research and money create real trade-offs, and keep what already works. The user asked for these explicitly:

1. **A beginner tutorial.** The first contract stage teaches the game.
2. **Re-tuned numbers and balance**, measured against the targets in §5 by an automated balance harness.
3. **Procedural continents, oceans and many candidate sites** instead of five or six fixed locations; every seed should call for a different plan.
4. **More weight on research**: more technologies that unlock capabilities, goals that need them, a viable research-led strategy, and a larger share of workforce and budget going to science.
5. **Everything else in this file**: the bugs, gameplay gaps, UI problems, save size, code health and performance issues found in the review.

**Keep:** Godot 4.5.1 and the Compatibility renderer; the fixed-step deterministic simulation; conservation audits; separate public / resident / enterprise accounts; the company process (warning → review → conditional aid → takeover); the career loop (governor → stewardship B → next planet); the R(5)/R(10) = 0.6 research calibration; the art direction and palette; Chinese UI; offline, free, no in-app purchases; aggregate population (no per-person simulation).

---

## 2. How to work

1. **Read first** (§3). Then write `docs/v17/PLAN.md`: files and modules you will add or change per phase, data ownership, save-schema changes and the order of work. Then start. Do not wait for approval on routine choices.
2. **Ask the user only** when a decision would change the game's premise, drop a requirement from this file, delete or rewrite user data, or act outside the repository. Record every other judgment call in `docs/v17/DECISIONS.md`, one line each: decision · reason · alternative rejected.
3. **Reproduce before fixing.** Confirm each finding in §4 with a test or the harness before changing code. If something is already fixed, note it and move on.
4. **Version control first.** There is no git history. Initialize git, add the `.gitignore` from W0, commit the untouched 1.6 tree as `1.6.0 baseline`, tag it `v1.6.0`, then work on branch `v17` with small commits (`v17: <area>: <what>`). Never rewrite the baseline.
5. **Never modify:** `%APPDATA%\ColonyCharter\v16` (player saves), `build\v16`, `delivery\`, `versions\`, `docs\v16\`, existing files under `evidence\`, `tools\godot-4.5.1\`. New outputs go to `build\v17`, `docs\v17`, `evidence\v17`, `game\data\v17`.
6. **Isolate every run.** Set `$env:APPDATA` to a folder under `evidence\v17\userdata_*` for tests, and change `config/custom_user_dir_name` in `project.godot` to `ColonyCharter/v17`.
7. **Be honest about evidence.** Label each result: automated test · balance harness · source-project window · exported EXE · screenshot viewed · human playtest. Human playtests are NOT_RUN unless the user reports one. A process that exits 0 while its log contains `SCRIPT ERROR` or failed checks is a failure. Report misses against §5 targets plainly; never relax a target silently.
8. **Keep documentation lean.** `docs/v17/` holds `PLAN.md`, `PROGRESS.md`, `DECISIONS.md`, `DESIGN.md`, `BALANCE.md`, `VALIDATION.md`; the root holds `CHANGELOG.md` and the Chinese `README.md`. Raw output goes to `evidence\v17` only. Do not create per-run evidence trees, red/green file pairs or hash manifests beyond one final release identity file.
9. **Data-driven numbers.** Every tunable lives in JSON under `game/data/v17/` with units and a `version` field. Rules, UI text and tests read the same values. Validate configs at load and fail loudly in debug builds.
10. **Determinism.** Same seed + same action log ⇒ identical state, at any game speed. `audit()` (money, goods, population partition) must pass every simulated day in every harness run; extend it to every new system.
11. **Code style.** English identifiers; Chinese only in player-facing strings. Static types in new and touched code. One statement per line. All scripts formatted with `gdformat`; new and touched code `gdlint` clean (gdtoolkit 4.x).
12. **Multi-session.** At the end of each phase and before you stop, update `docs/v17/PROGRESS.md`: done, in progress, next step, blockers, latest harness metrics. In Phase 0 create `CLAUDE.md` at the root with paths, commands and the never-modify list, so a fresh session starts correctly.
13. **Parallel work.** If you can run subagents (or have the superpowers skills), split independent workstreams only after `PLAN.md` fixes the interfaces between them.

---

## 3. Read first

- `README.md`, `DEMO_AGENT_PROMPT.txt` (original product direction)
- `docs/superpowers/plans/2026-10-30-next-demo-agent-instructions.md` — the 1.6 brief. It stays binding where this file is silent: research calibration, company process, stewardship B, honest validation, save safety.
- `docs/AUDIT_20261030.md` (B01–B10 are still relevant) and `evidence/audit_20261029/events_review.md` (original event-chain ideas)
- `docs/v16/VALIDATION.md`, `BALANCE.md`, `WORLD.md`, `ECONOMY.md`, `EVENTS.md`, `CAREER.md`
- All of `game/simulation/`, `game/ui/`, `game/world/`, `game/data/*.json`, `game/tests/`

Precedence: the user's later instructions > this file > the 1.6 brief > older documents.

---

## 4. Verified state of 1.6

Line numbers refer to the 1.6 source; they will move once you edit.

### 4.1 Pacing and goals
- On seed 260129 a rush qualifies for governor on **day 19** for the capital and workers openings at every difficulty, and for science on easy and standard; science on hard takes day 25. Capital-on-hard runs on seeds 42, 20261029, 1024873270 and 909386518 also give day 19, as do runs with the around-the-mountain road, with every event declined, and with the capital placed in the grassland, coast, plateau or valley. Script: Appendix B (re-run on 2026-10-31; it returns exactly these days).
- Day 19 = the investor gate (`sim.gd:185`: day ≥ 15 and exports ≥ 100) + 4 days of fit-out (`sim.gd:193`). The 1.6 flow test reports days 38–60 only because its bot waits until day 16 and day 24 (`tests/v16_flow.gd`).
- For competent play, difficulty only changes starting cash. No rush run left the company's normal stage.
- Failing takes neglect: idling after landing fails on day 137; mining without a second settlement fails on day 317 while holding ¥35,671.
- After the award (1,500-day sandbox run): cash climbs steadily to about ¥152k with nothing worth buying; population goes from 60 to 84; the last event fires by day 60.

### 4.2 Economy and decisions
- Labour is the binding constraint (the copper mine and a water pump stay short-staffed for months), but the player has almost no lever: immigration is a fixed +2 workers per 24 days when conditions hold (`sim.gd:526`), births are one per settlement per year, and landing housing (80 + 40 beds) makes habitats unnecessary.
- Roads: across 40 seeds the mountain road is always faster (2–4 vs 5–9 days) and larger (42 vs 28 t/day), with no upkeep or risk, for −4% to +55% one-off cost. The route card hides capacity (`pages.gd:227`).
- Mines: iron earns about ¥77/day gross for 9 workers and ¥678 of inputs; crystal about ¥75/day for 12 workers and ¥1,328. Crystal is dominated at typical grades.
- Processor: about +¥4/day after wages and upkeep; never needed.
- Company aid gives a struggling colony more than it costs (`progression.json` → `company.offers`).
- Research is never required by a goal or a crisis; the rush never builds a lab.
- The enterprise preview at the capital is about +¥0.7/day; at an 18-person outpost it is negative.

### 4.3 Events
- 13 definitions, each at most once per planet (`events_v2.gd:279`); the last one fires by day 60.
- Stakes are small (28 food, ¥90, ±8–20% output for 5–12 days), yet every decision node pauses: 10–13 pauses in the first 60 days.
- Trap: event options that build a facility check money and materials but not workers (`events_v2.gd:102–106`). In the rush run, “直接增建净水泵站” built a pump that was never staffed, and the chain closed as “工程未能投入运行” 30 days later.

### 4.4 Geography and region view
- The six regions are hard-coded (`world_gen.gd:38–44`: names, roles, base fertility and water, deposits ±15%). Seeds rotate and reshape the home continent but keep the cluster; the home continent's anchors are fixed in `seed_geography.gd:96–133`.
- Across 40 seeds: the valley's fertility is 0.95 every time (clamp in `hydrology.gd:158`); the basin always holds 15.6–20.8 kt of iron; the islands are unreachable by land in all 40.
- Terrain reaches the economy only through region fertility, water, temperature (farm yield), deposits and grade, route length and slope, and a fixed ×1.45 build cost on the plateau. Biome, coastline, lakes and most rivers change no number.
- Inside a region nothing is spatial: buildings take fixed slots (`map_view.gd:1172`), at most 24 (`sim.gd:138`); the 86 × 86 terrain around them is scenery.
- Rivers come from the 2.5° grid and are drawn as flat ribbons along that path, so they ride along slopes and run off the map edge. The sea is a sheet of 0.5-unit squares, so coasts are stepped. Flat-map label offsets are hard-coded per region id (`map_view.gd:722–727`).
- A dashed seam runs down the globe and the cloud layer: UVs computed with `atan()` per fragment jump at ±180° and select the smallest mip (`map_view.gd:454` and `:782`).

### 4.5 UI
- The build list shows cost, days, jobs, power and water, not output, profit or payback (`pages.gd:146`).
- The economy page shows net stock change; exports leave the same day, so mined goods read +0.0/day.
- Every page pauses the game, and it stays paused after closing (`main.gd:368`). With event pauses on top, play is stop-and-go.
- Much copy explains accounting rules (口径, 账户, 守恒) rather than what to do next and why.
- The globe shows no colony footprint beyond 15 city-light dots per settlement.
- Onboarding is the menu text, the contract page, a static seven-card guide (行动指南) and a one-line mission bar.

### 4.6 Code, saves, performance, tests
- Saves are 8.1 MB for a new game and 10.9 MB after one handover. They store the whole world grid (10,368 dictionaries), the state twice (JSON plus base64 binary) and a gzipped full copy of the state as the landing checkpoint. Save ≈ 0.4 s and load 0.5–0.7 s (reviewer's Linux container). Autosave runs every 10 game days on the main thread (`main.gd:198`), i.e. every 12.5 s at fast speed.
- The UI is rebuilt, not updated: `refresh()` recreates the sidebar every sim day (`main.gd:302–307`) and every action reopens the whole page (`main.gd:309–319`).
- State is untyped nested dictionaries, and logic compares Chinese display strings such as “营业中” and “停业” (`sim.gd:278`, `sim.gd:612`).
- Readability: multi-statement lines, single-letter names, `sim.gd:799` is a 1,580-character line, and `map_view.gd` (1,507 lines) mixes the globe, flat map, region terrain, building models and roads.
- Rendering redoes work: each building is dozens of primitive mesh nodes; 160 trees and rocks are separate nodes; `_ground()` re-samples the full geography function for every road piece and tree; markers and route lines are rebuilt every sim day (`map_view.gd:113–117`); `EventsV2.view()` runs every frame while time runs (`main.gd:185`, `main.gd:217`).
- Tests cover conservation and robustness, not balance. `tests/v16_research_priority.gd:12` and `tests/v16_event_acceptance.gd:35` overwrite shipped fixtures in `res://data/v16`. `tests/world_v16_seed.gd` needs `evidence/v16/world_seed_red.json`, which the source ZIP lacks; on that script error it hangs instead of exiting.
- The export ships QA data: `export_presets.cfg` includes `data/v16/*.json`, about 64 MB of the 77.5 MB PCK, and the settings page exposes QA loaders to players.

---

## 5. Goals and acceptance targets

### 5.1 Design pillars
1. **Growth, not waiting.** Goals require building a growing colony; no arbitrary timer sets the pace.
2. **Geography drives plans.** Each seed produces different continents, oceans and candidate sites; where you land and expand changes your strategy.
3. **Research is a pillar.** Technologies unlock capabilities the colony needs; a research-led strategy is viable and distinct.
4. **People are the engine.** Housing, wages, services and recruitment turn money into workers and scientists; labour is the main constraint and the player has levers on it.
5. **Every choice shows its numbers.** Cost, output, payback, labour, upkeep and risk are visible before committing.
6. **Something to work toward after the award.** Expansion, upgrades, megaprojects and a visible footprint on the planet.

### 5.2 Target metrics (the acceptance bar)

Measured by the balance harness (W0) on 20 fixed seeds; standard difficulty unless stated; medians unless stated.

| Area | Target |
|---|---|
| Floor | Rush bot (best opening, best seed) cannot qualify for governor before **day 90** |
| Balanced bot, award day | standard **120–180**; easy **90–150**; hard **160–230** |
| Openings | Balanced-bot medians of the three openings within ±15% of each other; the best bot differs by opening |
| Failure is possible | Passive bot (land, then idle) reaches company review by about day 60 and fails by about day 150 on standard (later on easy, sooner on hard). Sloppy bot (mines only, ignores food and housing) reaches review on every difficulty and fails on hard |
| Population (balanced) | Meets the stage-3 goal at award (180 on standard); ≥ 300 by day 360; ≥ 600 by day 720 |
| Labour lever | Raising the wage policy from 1.0× to 1.3× changes 180-day immigration by ≥ 20% (A/B in the harness) |
| Research (balanced) | ≥ 3 technologies by award; scientists 10–20% of adults at award; research spending (scientist wages, project funding, lab upkeep) 15–30% of operating expenses over days 60–180 |
| Research-first bot | ≥ 6 technologies by award, with an award day inside the standard band |
| Money has uses | Balanced bot reinvests ≥ 60% of its cumulative operating surplus by day 720; operating income on day 720 ≥ 2.5× day 180 |
| Export mix | After day 180, no single good exceeds 60% of export revenue in balanced runs |
| Events | ≥ 25 short definitions and ≥ 5 chains; on average ≤ 1 pausing decision per 20 days; ≥ 15 distinct events by day 720; no definition repeats inside its cooldown |
| Geography (200 seeds) | Candidate sites per world: small 14–20, medium 20–30, large 28–40. 100% of seeds have ≥ 3 viable start pairs (after the validator). The best start's archetype varies: ≥ 3 archetypes each ≥ 10% of seeds. Land fraction spans 25–45%; continents 2–6 |
| Road trade-off | Over 360 days, the cheaper road (build + upkeep + expected closures) is the slower one for 30–70% of evaluated settlement pairs |
| Determinism | Same seed + action log ⇒ byte-identical state after 720 days; the 1×, 4× and fastest speeds give identical results |
| Audits | 0 conservation or partition errors in every harness run, including 50 random-legal fuzz runs of 720 days |
| Saves | Typical save ≤ 1.5 MB; save ≤ 100 ms and load ≤ 300 ms on the user's machine; autosave adds no frame over 50 ms |
| Responsiveness | Warm page open shows feedback within 100 ms; cold region load ≤ 1.0 s with no frame over 50 ms (user's machine: i9-14900HX, RTX 4070 Laptop) |
| Tutorial | A headless tutorial run completes every step through its predicates; skip and replay work. Human first-time run: NOT_RUN until the user does it |

### 5.3 Harness bots
All bots act only through `Sim.act()` and `Sim.tick()`, never by editing state.

- **Rush** — the shortest path to the contract (Appendix B adapted to the new rules). Guards the floor.
- **Balanced** — a reasonable human. Each day: answer events with the option of best expected value that it can actually staff; fix shortages in the order food → water/power → labour → housing; keep cash ≥ 30 days of expenses; then invest greedily in the best affordable option with payback ≤ 120 days (mines respecting market saturation, farms while food self-sufficiency < 100%, processors while construction imports are high, habitats while free beds < 5%, labs and research while any project is unstaffed, expeditions and roads when goals or returns call for them, enterprises when the forecast is positive, upgrades and megaprojects after the award); set wages to keep attractiveness ≥ 1.0.
- **Research-first** — builds labs early, trains scientists, and picks technologies that unlock better deposits and products.
- **Passive** — lands, then does nothing.
- **Sloppy** — builds only mines; ignores food, housing and events.
- **Random-legal** — random affordable legal actions; used for crash and audit fuzzing.

---

## 6. Workstreams

Each workstream lists what to build and how it is accepted. Phase numbers refer to §7.

### W0 — Infrastructure and baseline (Phase 0)
- **git:** `.gitignore` covering `game/.godot/`, `build/`, `delivery/`, `versions/`, `evidence/`, `saves/`, `tools/*.zip`, `tools/*.tpz`, `tools/godot-4.5.1/`, `*.bak`, `*.tmp`, `__pycache__/`. Keep Godot's `*.uid` files tracked. Use Git LFS for `*.png`, `*.ttf` and acceptance-save JSON if LFS is installed; otherwise commit them normally.
- **`CLAUDE.md`** at the root: project summary, engine path, test and build commands, never-modify list, APPDATA isolation, pointers to this file and `PROGRESS.md`.
- **Test runner `tools/run_tests.ps1`:** runs each suite as its own process with a timeout (default 600 s; per-suite override), isolated APPDATA, logs to `evidence\v17\tests\<suite>.log`. A suite fails on non-zero exit, timeout, `SCRIPT ERROR`, or the suite's own failure marker. Print a summary table; exit non-zero if anything failed.
- **Watchdog in every SceneTree test:** a timer that quits with code 2 on timeout, so a script error can never hang a run.
- **Fixture isolation:** tests write only to `user://` or `evidence\v17`; regenerating shipped fixtures requires an explicit `--fixtures` flag (as `v16_flow.gd` already does). Fix `v16_research_priority.gd` and `v16_event_acceptance.gd`.
- **`world_v16_seed.gd`:** when the evidence baseline file is missing, skip that comparison with a clear message instead of erroring.
- **Balance harness** `game/tests/balance/run_balance.gd` with bots in `game/tests/balance/bots/`. Modes: `--quick` (5 seeds, standard, three openings, ≤ 3 min) and `--full` (20 seeds × 3 openings × 3 difficulties × 720 days, ≤ 15 min). Output: `evidence\v17\balance\<timestamp>.json`, plus the current results table at the top of `docs/v17/BALANCE.md` with a short history below it. Per run record: award day and stage days, failure day and reason, minimum cash, population at days 90/180/360/720, technologies by award, research share of expenses, scientists' share of adults, export mix, pausing decisions and notices, company stages reached, audit errors.
- **Baseline:** run every suite and the harness on unmodified 1.6. The rush bot must reproduce day 19. Record the result in `BALANCE.md` as “1.6 baseline”.

**Accept:** all 1.6 suites pass through the runner (or fail with a documented environment cause); the harness reproduces day 19; the baseline is committed and tagged.

### W1 — Bugs and safety rails (Phase 1)
Add a regression test for each item that can be tested headless.

| # | Bug | Where (1.6) | Fix |
|---|---|---|---|
| 1 | Event build options ignore labour | `events_v2.gd:102–106` | Check free workers (and specialists) in `_reason`; show “needs N workers, M free” on the option |
| 2 | Seam on the globe and clouds | `map_view.gd:454`, `:782` | Use `textureGrad` with seam-safe derivatives (compare `dFdx`/`dFdy` of `uv.x` and `fract(uv.x + 0.5)`, keep the smaller), for the main sample and the relief samples; or build the sphere with a UV seam |
| 3 | Handover ignores planet size | `career.gd:191` | Pass size through; let the player choose the next planet's seed, size, opening and difficulty |
| 4 | Main menu can be dismissed | `main.gd:357`, `main.gd:243` | No close button and no Esc on the main menu |
| 5 | Tests overwrite shipped fixtures | `tests/v16_research_priority.gd:12`, `tests/v16_event_acceptance.gd:35` | See W0 |
| 6 | Aid always goes to the capital | `company.gd:53` | Deliver to the settlement with the worst shortage, or let the player choose |
| 7 | Policy defaults can't be re-selected | `pages.gd:257–264` vs `sim.gd:19` | Slider or spin box for tax (0–50%) and food reserve (3–25 days) |
| 8 | Cash runway uses a single day | `pages.gd:160` | Use `summary().runway` (7-day average) |
| 9 | Copy claims region area scales with planet size | `pages.gd:20` | Correct the text; area becomes real through plots in W8 |
| 10 | Dead UI code | `pages.gd:185–212`, `pages.gd:269–289`, `sim.gd:167` | Delete |
| 11 | Panels stay paused after closing | `main.gd:368` | Setting “打开面板时暂停” (default on) that restores the previous speed on close; event decisions still pause |
| 12 | QA data ships to players | `export_presets.cfg`, settings page | Exclude test fixtures from export; QA loaders only when `OS.is_debug_build()` or `--dev` |

**Accept:** each fix has a test or a documented manual check; all suites green.

### W2 — Contract and progression (Phase 3)
Replace the single checklist with three stages. Starting values for standard (calibrate to §5.2):

| Stage | Soft deadline | Goals | Reward |
|---|---|---|---|
| 1 立足 Foothold | day 90 | First settlement; ¥3,000 cumulative exports; food ≥ 10 days; 10-day non-negative operating streak; one research project staffed | ¥1,500 development funds (non-operating); expedition licence |
| 2 分工 Division of labour | day 200 | Two settlements connected; local food covers ≥ 80% of consumption over 30 days; one processing chain active ≥ 20 days; population ≥ 120; ≥ 2 technologies | ¥2,500; third-settlement licence |
| 3 自立 Self-reliance → governor | day 300 | Population ≥ 180; employment ≥ 60%; everyone housed; an enterprise profitable for 30 days; non-mining operating income ≥ 25% over 30 days; 30-day non-negative streak; no active company review | Governor qualification |

- Missing a soft deadline adds an economic distrust source and enters the existing warning → review → intervention process; it never fails the game instantly.
- Remove the investor's 15-day and 100-export gates. An enterprise needs local demand: forecast profit ≥ 0 at current population and resident purchasing power, shown before approval.
- Difficulty scales goal sizes (about ×0.8 / ×1.0 / ×1.2) and deadlines, never the rules.
- After the award: optional planetary milestones (for example population 1,000, five settlements, three megaprojects, all tier-2 technologies) with modest rewards to career funds.
- The contract page shows each stage's progress, what is missing, and the action that fixes it.

**Accept:** §5.2 floor, award bands and failure rows met; stage rewards recorded as non-operating income.

### W3 — Population, labour and housing (Phase 3)
- **Attractiveness** per settlement, 0–2, from: free beds, food security, open jobs, wage policy, services (enterprise, clinic), pollution, recent shortages and company standing. The UI shows the breakdown.
- **Immigration:** monthly arrivals = base × attractiveness, accrued daily, capped by free beds; arrivals bring savings into the resident account; mostly workers, plus scientists in proportion to research facilities.
- **Wage policy** 0.8×–1.6× (default 1.0×): costs money, raises attractiveness and reduces departures.
- **Recruitment campaigns:** pay public cash to bring workers or scientists after a travel delay; the price rises with repeated campaigns inside 90 days; needs beds. This is the main explicit lever and a money sink.
- **Departures** generalize the 1.6 social-distress rule to low attractiveness.
- **Housing** matters: landing housing about 60 beds at the capital and 24 at an outpost (from 80 and 40); habitat L1 45 beds, L2 through technology.
- **Births** scale with adults and housing (about 1% of adults per year); maturation unchanged.

**Accept:** population rows and the labour-lever A/B row in §5.2.

### W4 — Economy and numbers (Phase 3)
Starting proposals are in Appendix C; the harness decides the final values. Record every change with its reason in `DESIGN.md`.
- **Dynamic export prices:** each good has a saturation stock that rises with exports and decays daily; price = base × clamp(1 − 0.4·S/M, 0.6, 1.0). Show the price and its trend.
- **Rebalance producers** so each has a niche: crystal is high-value per worker but scarce and often remote; the processor nets about ¥20–35/day and pays back within about 60 days; farms matter because food demand grows with population.
- **Roads** get upkeep, and engineered (mountain) roads get closure risk (rockfall events); the route card shows capacity, upkeep, travel days and risk.
- **Company aid** costs more than it gives (it buys time, not money).
- **Running costs** scale with population and settlement count, so growth is not free.
- **Money sinks:** building upgrades (L2/L3 via technology), more settlements, recruitment, wage policy, research funding, road upgrades and megaprojects (W5).
- Keep the 1.6 overproduction fix (production stops at the stock target).

**Accept:** §5.2 money and export-mix rows; no harness audit errors.

### W5 — Research (Phase 4)
- **Keep** R(n) = R10 × (n/10)^α with α = ln 0.6 / ln 0.5, zero output at zero staff, and the concentrated-versus-parallel trade-off.
- **Raise** the reference output (proposal: R10 = 2.0 points/day) and re-cost technologies by tier (proposal: tier 1 40–60, tier 2 100–140, tier 3 200–260).
- **Expand the tree** to about 20 technologies in four branches and three tiers (Appendix D). Every tier-2 and tier-3 technology unlocks something — a building, an upgrade, a deposit tier, a route type, a product, a policy or a megaproject — not only a percentage.
- **Labs:** L1 = 10 seats and 2 projects; L2 (学术网络) = 20 seats and 3 projects. The science opening starts with a prefab L1 lab.
- **Research contracts (科研委托)** after 学术网络: labs can take paid external contracts that use scientist-days and pay operating income — a post-mining income path that competes with internal research for staff.
- **Exploration links:** survey reveals true deposits and grades at sites; prospecting reveals hidden deposits (W7).
- **Megaprojects** (tier 3): Planetary University (research ×1.25, attracts scientists), Orbital Lift Port (port capacity ×3, export prices +10%), Climate Regulator (+3 °C and +10% rainfall within a radius, visible on the globe). Long builds, large costs, real effects.
- **UI:** a tech-tree view (branches, tiers, prerequisites) and staffing previews (“5 人 → 22 日，10 人 → 13 日”).

**Accept:** research rows in §5.2; a test asserts R(5)/R(10) = 0.6, zero at zero staff, and monotonic output.

### W6 — Events (Phase 6)
- **Repeatable pool:** each definition has a cooldown (about 120–240 days) instead of once per planet; conditions use the new systems (sites, roads, research, population, megaprojects).
- **Two kinds:** *decisions* (pause; real stakes) and *notices* (no pause; shown in a notification feed, auto-applied or answerable before a deadline). A setting chooses whether every decision pauses (default: only critical ones).
- **Scaled magnitudes:** rewards and costs scale with recent daily income or colony size.
- **Feasibility:** every option checks money, goods, workers, specialists and plots before it is offered; options that cannot run are shown disabled with the reason.
- **Content:** keep the existing 10 short events and 3 chains; reach ≥ 25 short definitions and ≥ 5 chains (Appendix E). New chains come from the originals in `docs/AUDIT_20261030.md` §5 (for example 没有目的地的客船 and 零点八毫米的裂缝).
- Keep the 1.6 framework guarantees: independent saved RNG, instances with history, one-time settlement, consistent effect timing for chosen and defaulted options, validation of unknown definitions.

**Accept:** event rows in §5.2; each chain's endings, deferral, timeout and save/load continuation tested.

### W7 — World generation and sites (Phase 5) — CC-GEO-2.0
**Goal:** continents, oceans and candidate sites are generated from the seed. No fixed names, coordinates or roles.

1. **Continents and oceans:** replace the fixed home-continent anchors (`seed_geography.gd:96–133`) and the six region specs (`world_gen.gd:38–44`) with seeded plate-like landmasses: 2–6 continents plus island arcs, with mountain ranges on collision edges. Choose the sea level as a height quantile so land fraction hits a seeded target of 25–45%. Keep the climate model (latitude, altitude, pressure, wind, rain shadow) and D8 hydrology.
2. **Per-cell attributes** on the 144 × 72 grid: fertility (temperature suitability × rainfall × lowland/river soil × slope), water (rainfall, river discharge, lakes), ruggedness, coast access, climate risks (cold, arid, flood), and mineral potential from geology (ore and copper on mountain flanks and basins, crystal in high ridges and hotspots) plus seeded deposit fields with grade distributions.
3. **Candidate sites:** Poisson-disk sampling over land cells, scored for archetypes — mining basin, fertile valley, highland mining, grassland, coastal plain, island, lake basin, arid, cold. Keep quotas so each world has a mix. Site count by size: small 14–20, medium 20–30, large 28–40.
4. **Playability validator:** at least three viable start pairs — a start with adequate water and ≥ a configured tonnage of minable ore + copper (or crystal), plus a land-reachable site within 10 travel days with fertility ≥ 0.6. If the check fails, retry with deterministic sub-seeds (bounded); as a last resort, carve a fertile basin near the best start and record that in `world.generation.validation`.
5. **Names:** deterministic, unique Chinese names from site attributes (Appendix G).
6. **Information:** at game start every site shows terrain, climate and resource estimates with uncertainty bands (orbital survey). Ground survey actions and the 精细勘探 technology narrow the bands; prospecting reveals hidden and deep deposits.
7. **Legacy:** keep the CC-GEO-1.4 / 1.5 / 1.6 generator code paths so 1.6 saves keep their exact worlds.
8. **Storage:** the save keeps seed, generator version, a world hash and mutable world data (remaining deposits, revealed information, climate changes) — not the grid. Regenerate on load and refuse with a clear message if the hash differs.

**Accept:** geography and determinism rows in §5.2; a 200-seed test reports site counts, validator results, archetype distribution and land fraction; the same seed always produces the same world.

### W8 — Settlements, roads and the region view (Phase 5)
- **Settlement cap** comes from contract stage and career (2 → 3 → up to 6 after the award, configurable). An expedition may start from any settlement with enough people and supplies.
- **Road network:** a road between any two settlements, in two variants (valley/around and engineered/direct) that differ in build cost, upkeep, travel days, capacity and closure risk. Dispatch generalizes per road (surplus → deficit), with reserved and in-transit amounts shown per road. Road upgrades (铺装道路) and sea routes between coastal sites with ports (沿海航运) come from technology, so islands become reachable.
- **Plots replace the 24-building cap:** each site gets deposit plots (resource, grade, reserves, depth tier), farm plots (fertility) and general plots, generated from local terrain. The build dialog picks a plot; mines need a matching deposit plot; plot fertility scales farm yield; site capacity differs by terrain.
- **Region view:** buildings stand at their plot positions; plots are drawn subtly. Cache the region heightfield and query it (no full geography sampling per road piece or tree). Use MultiMesh for trees and rocks. Smooth rivers (spline through cell centres, monotone water level, carve along it, clip to the map bounds). Draw the sea as one plane with a shoreline from the heightfield. Build one model per building kind and instance it.
- **Globe and flat map:** many sites need filtering (by archetype or resource), labels only for selected, hovered, settled or top-scored sites, and automatic label placement instead of the hard-coded offsets. Add a colony footprint overlay (built-up area, farmland tint, roads) updated when buildings change — the visible progress TerraGenesis players expect.
- **Contract checks** generalize from “two settlements and one route” to network connectivity.

**Accept:** a migrated 1.6 save and a new 2.0 world both play end-to-end in the harness; region cold-load and frame targets in §5.2.

### W9 — Beginner tutorial and onboarding (Phase 7)
- **Scope:** the tutorial is the first contract stage plus the start of stage 2 (Appendix F), on a pinned easy seed. A test proves its recommended sites exist and its scripted first shortage happens.
- **Data:** `game/data/v17/tutorial.json` — per step: id, text (what and why), target control name, optional camera target, completion predicate, optional prerequisite.
- **Predicates:** a small set of named, testable predicates implemented in code (no `eval`), such as `settlements>=1`, `buildings_queued(mine_*)>=2`, `exports_total>0`, `page_opened(economy)`, `shortage_cleared(first)`, `project_staffed>=1`, `route_count>=1`, `building_active(farm)`, `contract_stage>=2`.
- **Presentation:** a small coach panel and a pulsing outline on the target control, never modal; Skip, Back and Replay; completion stored in `settings.cfg`; a “新手引导” toggle on the new-game screen.
- **Teach through problems:** the tutorial lets the first shortage happen, then shows how to read its red line and fix it.
- **Afterwards:** one-time contextual tips when a system first matters (first event, first company warning, first depleted deposit, first road closure).
- **Prerequisite:** stable node names on target controls and in-place UI updates (W10) — a tutorial cannot point at controls that are recreated every day.

**Accept:** headless tutorial run passes; manual run in the exported EXE recorded; human first-time run NOT_RUN until the user does it.

### W10 — UI and information (Phase 2 foundations, Phase 7 content)
- **Foundations (Phase 2):** build each page once and update its labels in place; give key controls stable names; update the sidebar in place; update map markers and routes only when they change.
- **Build dialog:** categories; per option at the selected plot: cost, materials, days, jobs (with free workers), power, water, expected output, revenue and net per day at current prices, payback days, and the reason when disabled.
- **Site card:** terrain, climate, water, fertility, deposits (estimate or surveyed), build-cost multiplier, travel time and cost to the nearest settlement for both road variants, risks and a role hint.
- **Settlement panel:** key figures first; each shortage has a “fix” button that opens the relevant action; buildings grouped by kind with problems first.
- **Economy page:** 30-day income and expense by category, a 90-day cash and net chart, 7-day runway, per-good flows (produced, consumed, exported, imported, shipped in and out), prices and trends.
- **Population panel:** attractiveness breakdown, arrivals and departures, housing, wage policy, recruitment.
- **Research:** tech tree with staffing previews (W5). **Roads:** network list with capacity, use, upkeep, risk and in-transit goods.
- **Time controls:** pause, normal, fast, and a very fast speed (8–10×) for the late game, protected by the existing long-frame stop rules.
- **Copy:** short, player-facing Chinese that says what to do and why; accounting detail goes behind “详情” tooltips.
- **Main menu:** continue shows the save's planet, day and cash; new game offers seed, size, difficulty, opening and the tutorial toggle.
- Check layouts at 1280×720, 1920×1080 and 2560×1440 and at the three UI text sizes.

**Accept:** capture-suite screenshots of every main page at three resolutions, viewed; page-open targets in §5.2.

### W11 — Saves, code health, performance and visuals (Phase 2 and Phase 8)
- **Save schema 3 (Phase 2):** one envelope (version, metadata, checksum) plus one compressed binary state (`var_to_bytes` + `compress(FileAccess.COMPRESSION_ZSTD)`); an optional human-readable JSON export behind `--dev`. Landing checkpoint and stewardship archives move to sibling files. Keep atomic write, `.bak`, validation and rollback on failure. Autosave serializes on the main thread and writes on a `WorkerThreadPool` task.
- **Migration from schema 2:** preferred — load 1.6 saves through the existing validator, then convert (regions → sites with synthesized plots, the route → a road, buildings → plots, Chinese status strings → English keys). Acceptable fallback, recorded in `DECISIONS.md`: refuse 1.6 saves with a clear message that points to the preserved 1.6 build. Never regenerate a world silently. For legacy worlds, drop the stored grid only if the legacy generator reproduces it exactly; otherwise keep it, compressed.
- **Modules (Phase 2):** extract from `sim.gd` into `simulation/logistics.gd`, `population.gd`, `production.gd`, `enterprise.gd`, `contract.gd`, keeping `Sim.act()` / `Sim.tick()` as the façade and documenting the daily tick order in `DESIGN.md`. Split `map_view.gd` into `planet_view.gd`, `flat_view.gd`, `region_view.gd` and `building_models.gd`.
- **State access:** keep dictionaries as the serialized form, but use key constants, small typed accessor helpers and English enum keys with a separate display-name table. No logic may compare display strings.
- **Formatting:** a formatting-only commit with `gdformat` over all scripts in Phase 1 (tests green before and after), then `gdlint` clean for new and touched code. If `gdformat` cannot parse a file, split its multi-statement lines by hand first and note it in `DECISIONS.md`.
- **Performance (Phase 8):** cache the event pause flag instead of building `EventsV2.view()` every frame; region heightfield cache, MultiMesh and instanced building models (W8); measure page opens, region loads, save and autosave in the real window on the user's machine with sample counts.
- **Visual fixes:** globe seam (W1), rivers, sea and coast (W8), label overlap, colony footprint overlay.

**Accept:** save, determinism and responsiveness rows in §5.2; no behaviour change from the formatting commit.

### W12 — Difficulty, openings and career (Phase 8)
- **Difficulty** changes starting cash, goal sizes, deadlines, event pressure, price volatility and company tolerance — the same rules at every level.
- **Openings with distinct starts:** capital (more cash, cheaper first expedition); workers (more workers plus a prefab habitat); science (12 scientists, a prefab lab, a head start on 精细勘探, narrower survey uncertainty).
- **Career:** the next planet uses a new procedural world chosen by the player (seed, size, opening, difficulty). The stewardship model keeps its 1.6 rules but uses the new income categories.

**Accept:** opening and difficulty rows in §5.2.

---

## 7. Phases and checkpoints

Work in this order; it is also the priority order. Every phase ends with: all suites green through the runner (or intentional rewrites listed in `VALIDATION.md`), a harness run with its metrics in `BALANCE.md`, `PROGRESS.md` updated, and a commit tagged `v17-phaseN`. If you must stop early, stop at a phase boundary with everything green.

| Phase | Content | Exit check |
|---|---|---|
| 0 | W0: git, `CLAUDE.md`, runner, watchdog, fixture isolation, harness and bots, 1.6 baseline | Harness reproduces day 19 |
| 1 | W1 bugs, QA data out of the export, formatting commit | Bug tests pass; formatting changes nothing |
| 2 | Foundations: sim modules, state keys and enums, UI refresh in place, save schema 3 and migration hook | Behaviour unchanged (harness metrics equal to Phase 1); saves smaller |
| 3 | W2 contract stages, W3 population, W4 economy | Floor, award bands, failure, population and money rows |
| 4 | W5 research and megaprojects | Research rows |
| 5 | W7 world generation, W8 sites, roads, plots and region view, legacy migration | Geography and road rows; migrated 1.6 save plays |
| 6 | W6 events | Event rows |
| 7 | W9 tutorial, W10 UI content | Tutorial test; screenshots viewed |
| 8 | W12, W11 performance and visuals, final balance pass, build and release checks | All of §5.2, misses reported |

Old tests encode 1.6 rules. Keep the tests of invariants (conservation, save robustness, determinism, the F05/F06/F11/F12 timing edges). Rewrite tests that encode superseded rules, and list each rewrite in `VALIDATION.md`.

---

## 8. Release validation

1. `tools\run_tests.ps1`: all green.
2. Harness `--full` and a 200-seed world test: results table in `BALANCE.md`, with misses listed.
3. Capture suite: create `ui/capture_suite_v17.gd` from `capture_suite_v16.gd` (flag `--qa-v17=<folder>`, fixtures from `data/v17`). Capture every main page at 1280×720, 1920×1080 and 2560×1440 and three text sizes; view the images and note problems found and fixed.
4. Exported EXE from `build\v17`: new game with the tutorial through stage 1; save; quit; relaunch; continue; reach stage 2. Load a 1.6 save (migration or explicit refusal). Record what you did.
5. Performance probe numbers on the user's machine, with sample counts and hardware.
6. Write a playtest checklist for the user (`docs/v17/PLAYTEST.md`: what to try, what to note, 30–45 minutes) and mark human playtests NOT_RUN.

---

## 9. Deliverables

1. Source on branch `v17`, tagged `v1.7.0`, with the 1.6 baseline untouched.
2. `build\v17\` EXE and PCK with no QA fixtures inside; `tools\build_v17.ps1` and `tools\package_v17.py` producing `delivery\v17\` (game ZIP and source ZIP; the source ZIP includes everything the tests need).
3. Chinese `README.md` (start, controls, core rules, tutorial, known limits, engine version, save locations, rollback to 1.6) and `CHANGELOG.md`.
4. `docs/v17/`: `PLAN.md`, `PROGRESS.md`, `DECISIONS.md`, `DESIGN.md` (systems, formulas, tick order, data files), `BALANCE.md` (targets, before and after), `VALIDATION.md` (what ran, results, NOT_RUN, known issues), `PLAYTEST.md`.
5. A final summary at the top of `PROGRESS.md`: what changed, a table of §5.2 metrics for 1.6 versus 1.7, open issues, and the next three improvements.

---

## 10. Out of scope

Multiplayer; diplomacy or war; piloting ships; per-person simulation; a full physical climate model; real-time offline earnings; ads or purchases; switching engines; a wholesale art remake or detailed building modelling (keep the current style, improve templates only); A-type direct management of several planets at once; simulating millions of residents (keep the aggregate model and bounded histories).

---

## Appendix A — Commands (PowerShell)

```powershell
$root   = 'D:\勇敢新世界'
$engine = "$root\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe"
$env:APPDATA = "$root\evidence\v17\userdata_tests"   # isolates user:// from player saves

# Import (after adding or renaming resources)
& $engine --headless --path "$root\game" --editor --import --quit

# One suite (prefer tools\run_tests.ps1 for all of them)
& $engine --headless --path "$root\game" --script res://tests/v16_events_tests.gd

# Balance harness
& $engine --headless --path "$root\game" --script res://tests/balance/run_balance.gd -- --quick
& $engine --headless --path "$root\game" --script res://tests/balance/run_balance.gd -- --full

# Screenshots from the source project (window, Compatibility renderer)
& $engine --path "$root\game" --rendering-method gl_compatibility -- --qa-v17="$root\evidence\v17\screens"

# Formatting and lint
pip install "gdtoolkit==4.*"
gdformat "$root\game"
gdlint "$root\game"

# Build (create build_v17.ps1 from build_v16.ps1; output to build\v17)
powershell -ExecutionPolicy Bypass -File "$root\tools\build_v17.ps1"
```

Paths contain Chinese characters: quote them and use `-LiteralPath` where PowerShell accepts it.

## Appendix B — Rush bot that reproduces day 19 in 1.6

```gdscript
# Uses only the production API. In 1.6: seed 260129 returns 19 (science on hard: 25).
const Sim = preload("res://simulation/sim.gd")
const Events = preload("res://simulation/events_v2.gd")

func rush(seed_value, opening: String, difficulty: String) -> int:
	var sim = Sim.new()
	sim.new_game(seed_value, opening, 1, difficulty)
	for _i in range(240):
		var day: int = int(sim.state.day) + 1
		if day == 1:
			sim.act("settle", {"region": 0})
			sim.act("build", {"region": 0, "kind": "mine_ore"})
			sim.act("build", {"region": 0, "kind": "mine_copper"})
		if day >= 2 and sim.settlement(1).is_empty():
			sim.act("settle", {"region": 1})
		if not sim.settlement(1).is_empty() and sim.state.route.is_empty():
			sim.act("connect", {"a": 0, "b": 1, "mountain": true})
		var outpost: Dictionary = sim.settlement(1)
		if not outpost.is_empty() and outpost.arrival <= 0 \
				and not outpost.buildings.any(func(b): return b.kind == "farm"):
			sim.act("build", {"region": 1, "kind": "farm"})
		if day >= 15 and sim.state.enterprise.is_empty():
			sim.act("enterprise", {"region": 0})
		for node in Events.view(sim).pending:
			for choice in node.choices:
				if choice.id != "defer" and choice.enabled:
					sim.act("event_v2", {"instance_id": node.instance_id, "choice": choice.id})
					break
		sim.tick()
		if sim.state.status == "success":
			return int(sim.state.day)
	return -1
```

Adapt it to the 1.7 rules (sites, plots, stages) and keep it in the harness as the floor guard.

## Appendix C — Starting proposals for numbers

Calibrate all of these with the harness; record final values and reasons in `DESIGN.md`.

| Item | 1.6 | Proposal | Intent |
|---|---|---|---|
| Landing housing (capital / outpost) | 80 / 40 | 60 / 24 | Housing becomes an early decision |
| Immigration | +2 per 24 days | base ≈ 6 per settlement per month × attractiveness, capped by free beds | Growth responds to the player |
| Wage policy | fixed ¥1.5 | 0.8×–1.6× of ¥1.5 | Money → people lever |
| Recruitment campaign | — | ≈ ¥120 per worker and ¥200 per scientist, 10-day travel, price +10% per campaign inside 90 days | Explicit lever and money sink (worker payback ≈ 20–30 days) |
| Enterprise gate | day ≥ 15 and exports ≥ 100 | forecast profit ≥ 0 at current demand | No waiting gate |
| Research reference R10 | 1.0/day | 2.0/day | Research arrives inside the first contract |
| Tech costs (tiers 1/2/3) | 32–120 | 40–60 / 100–140 / 200–260 | ≥ 3 technologies by award |
| Processor | jobs 10; out 2.4 materials + 0.8 parts | jobs 8; out 2.4 materials + 1.2 parts | ≈ +¥20–35/day net, payback ≈ 60 days |
| Crystal mine | ¥26/t, 3 t/day, 12 jobs | ¥32/t, 3.5 t/day, 10 jobs; deposits scarcer and more remote | Best per worker, worst logistics |
| Dynamic price scale M (t) | — | ore 3,000 · copper 1,500 · crystal 500 · materials 1,200 · parts 400; saturation decays 2%/day | No single good carries the colony |
| Road upkeep (around / engineered) | 0 / 0 | ¥1.5 / ¥5 per day | Real road trade-off |
| Engineered-road closure | — | ≈ one rockfall per 120 days, 3–8 days closed; risk −70% with 铺装道路 | Risk against speed |
| Liquidity aid | ¥1,800 → repay ¥1,200 over 60 days + 10% | ¥1,800 → repay ¥2,100 over 90 days + 8% | Aid buys time, not money |
| Supplies aid | goods ≈ ¥1,500 → repay ¥700 | → repay ¥1,400 over 90 days | Same |
| Administration cost | ¥5/day | ¥5 + ¥0.04 per resident + ¥3 per settlement, per day | Growth has running costs |
| Event magnitudes | fixed amounts | about 2–5 days of recent average income | Events stay relevant as the colony grows |
| Stage deadlines, days (stage 1 / 2 / 3) | one deadline: easy 270, standard 240, hard 210 | easy 120 / 250 / 360 · standard 90 / 200 / 300 · hard 75 / 170 / 260 | See W2 |

## Appendix D — Technology tree draft

Costs assume R10 = 2.0. “Unlock” means a new capability, not only a percentage.

| id | 名称 | Branch | Tier | Requires | Cost | Effect |
|---|---|---|---|---|---|---|
| survey | 精细勘探 | Extraction | 1 | — | 45 | Mines +20%; reveals true deposits and grades at surveyed sites |
| deep_mining | 深层采掘 | Extraction | 2 | survey | 120 | Unlock mine L2 (+60% output, +4 jobs) and the deep deposit tier |
| prospecting | 远程勘测 | Extraction | 2 | survey | 100 | Survey actions −50% cost; reveals hidden deposits within a radius |
| adaptation | 作物适配与食品加工 | Agriculture | 1 | — | 40 | Farms on cold and arid sites; food export workshop |
| irrigation | 闭环灌溉 | Agriculture | 1 | — | 55 | Farm water −30%, output +20% |
| hydroponics | 水培温室 | Agriculture | 2 | irrigation | 120 | Unlock hydroponic farm (yield independent of soil, power-heavy) |
| processing | 精密加工 | Industry | 1 | survey | 60 | Processor output +30% |
| efficiency | 能效工程 | Industry | 2 | processing | 110 | Power −25%, maintenance −20% |
| electronics | 电子元件 | Industry | 2 | processing | 130 | Unlock component plant: parts + crystal → components (high-value export) |
| automation | 自动化产线 | Industry | 3 | deep_mining, electronics | 240 | Mines and processors −30% jobs |
| logistics | 货运调度 | Logistics | 1 | — | 55 | Road capacity +40%, transport cost −20% |
| paved_roads | 铺装道路 | Logistics | 2 | logistics | 100 | Unlock road upgrade (+50% capacity, −1 travel day, closure risk −70%) |
| shipping | 沿海航运 | Logistics | 2 | logistics | 120 | Unlock sea routes between coastal sites with ports |
| medicine | 社区医疗 | Society | 1 | — | 50 | Unlock clinic (attractiveness +0.3, departures −50%, births ×1.5) |
| education | 职业教育 | Society | 1 | — | 60 | Training ×2; scientist recruitment campaigns |
| research_network | 学术网络 | Society | 2 | education | 110 | Unlock lab L2 (20 seats, 3 projects) and research contracts (科研委托) |
| remediation | 环境治理 | Society | 2 | medicine | 100 | Pollution decay ×2, clean-up cost −50% |
| university | 行星大学 | Society | 3 | research_network | 220 | Unlock megaproject: Planetary University |
| lift_port | 轨道升降港 | Logistics | 3 | shipping, electronics | 260 | Unlock megaproject: Orbital Lift Port |
| climate | 气候调节 | Agriculture | 3 | hydroponics, efficiency | 260 | Unlock megaproject: Climate Regulator |

## Appendix E — Event content draft

Existing short events to keep (make repeatable where sensible, scale magnitudes): 一箱标错的种子, 泵房里的一滴盐, 食堂的旧菜单, 技工的定位夹具, 颜色不同的货签, 筛网上的细灰, 地学站的回信, 两地的第一个集市, 安静的水渠, 任命后的工具箱. Existing chains to keep: 第二条水位线, 送不到的旺季, 岩层下的值班簿.

New short events (ideas; write original text and check feasibility):

| id | Condition | Choices |
|---|---|---|
| rockfall 落石封路 | engineered road exists | pay repair crew now · wait out the closure · reroute through the valley road |
| price_window 报价窗口 | any export good | sign a forward contract at a fixed price · stay on the market |
| migrant_group 自发移民 | attractiveness ≥ 1.2 | accept now (needs beds) · accept in stages · decline |
| wage_talks 工资协商 | wage policy < 1.0, employment high | raise wages · one-off bonus · refuse (productivity −) |
| equipment_failure 设备故障 | random facility | repair with parts · repair with cash · run at reduced output |
| dust_storm 尘暴 | arid site | solar output −40% for some days · buy fuel · ration |
| flood_season 汛期 | river site | build a levee · move stock · accept losses |
| cold_snap 寒潮 | cold site | heating cost · farm output loss |
| flu_season 流感季 | population ≥ 150 | workforce −10% for days; a clinic halves it |
| breakthrough 意外突破 | scientists ≥ 8 | add progress to a project · publish (scientist immigration ↑) |
| visiting_scholars 访问学者 | lab exists | host them (cost; research boost and a chance to recruit) · decline |
| investor_offer 投资意向 | enterprise slot free | accept terms · negotiate tax · decline |
| deposit_revision 勘探修正 | surveyed deposit | reserves revised up or down; accept or fund a re-survey |
| meteor_shower 流星雨 | any (rare) | festival (small attractiveness boost) · collect fragments (small crystal) |
| supply_delay 补给船延误 | imports active | pay a rush fee · wait |
| company_audit 例行抽查 | stage ≥ 2 | prepare documents (cost) · do nothing (small distrust risk) |
| school_request 学校申请 | children ≥ 20 | build a school (attractiveness, future scientists) · postpone |
| local_species 本地物种 | farm near forest | protect habitat (cost) · expand anyway (pollution and reputation) |

New chains (from `docs/AUDIT_20261030.md` §5): 没有目的地的客船 (accept all · staged settlement · resupply and send on), 零点八毫米的裂缝 (limit loads · build a bypass · run the risk), and optionally 山脊里的空白图 (hidden deposit, ties to prospecting) or 玻璃下的第二季 (greenhouse soil).

## Appendix F — Tutorial steps (first contract)

| # | Step | Highlight | Done when |
|---|---|---|---|
| 1 | Look around | globe | camera rotated and zoomed |
| 2 | Read site cards | two site markers | two site cards opened |
| 3 | Land | recommended mining site, “建立首府” | `settlements>=1` |
| 4 | Start income | 建设设施 → iron and copper mines on deposit plots | two mines queued |
| 5 | Run time | 正常 / Space | day ≥ 3 |
| 6 | First export | top bar | `exports_total>0` |
| 7 | Read the ledger | 经营账本 | economy page opened |
| 8 | Make room for people | habitat; attractiveness panel | habitat queued |
| 9 | Fix a problem | the red shortage line and its fix button | scripted first shortage cleared |
| 10 | Start research | lab; assign ≥ 3 scientists to 精细勘探 | a project staffed |
| 11 | Stage 1 complete | contract page | `contract_stage>=2` |
| 12 | Expedition | a recommended fertile site | second settlement founded |
| 13 | Compare roads | road cards (capacity, upkeep, risk) | a road built |
| 14 | Feed the colony | farm on a farm plot | farm running; tutorial ends, contextual tips on |

## Appendix G — Site names

Deterministic from the world seed; unique within a world. Name = adjective + noun + feature (for example 苍脊高原, 青溪河谷, 寒汐海岸).

- Adjectives: 铁 赤 青 苍 白 寒 暖 雾 云 星 澄 碧 远 长 磐 金 银 霜 晨 暮
- Nouns: 岬 溪 脊 风 汐 栖 石 松 岩 川 林 湾 峰 泉 原 坪 岭 渊
- Features by archetype: basin 盆地 谷地 · valley 河谷 溪谷 河湾 · highland 高原 台地 山麓 · grassland 原野 草甸 · coast 海岸 湾 岬 · island 群岛 岛 · lake 湖畔 泽地 · arid 荒原 戈壁 · cold 冻原 雪原
