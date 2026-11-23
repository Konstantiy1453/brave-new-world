# Colony Charter 1.11.0: the contractor (plan, 2026-11-23)

The user's decisions of 2026-11-22 and 2026-11-23, after a review of 1.10.1 against six reference games:

- **The spine is the contractor.** The player is an outsourced contractor of a colonisation company, bound by a bet-on contract (对赌协议). The company is client and judge; the colonists are the people the player lives among. 1.11 turns that relationship into something the player feels and decides about, not only a distrust gauge.
- **Terraforming is the later career.** Early contracts are on habitable worlds; harsher worlds that need terraforming come later in a career. Not in 1.11.
- **The district view and the 3D models are the showcase.** They stay; they do not drive the design.
- **The game is already not simple.** Every addition here replaces or merges something. No new meters beyond the two in B; one screen per ritual. When in doubt, build the simpler version and record the call.

Work on a new branch `v17-charter` from `v17-bay` (0697fe2 or later; `main` is six commits behind `v17-bay`). Before starting, check the working copy for uncommitted work and ask the user about anything that looks like it belongs to this plan (the user made a light concept sheet outside the repository; see G).

## Rules that hold throughout

- **As before.** The working rules in `CLAUDE.md` hold: `Sim.act()` and `Sim.tick()` are the only ways to change state; same seed and action log give byte-identical state at any speed; `audit()` covers every new system; numbers live in `game/data/v17/`; English identifiers, Chinese only in player-facing strings, no logic compares display strings; static types, gdformat, gdlint; stage explicit paths; the never-modify list; evidence labels. Human playtests are NOT_RUN unless the user reports one.
- **Version and saves.** 1.11.0. In `game/project.godot`, `config/custom_user_dir_name` becomes `ColonyCharter/v111`. In `save_io.gd`, `SCHEMA` becomes 7 and `OLD_SCHEMAS` gains `6: "1.10"`. 1.11 reads the 1.10 saves in `%APPDATA%\ColonyCharter\v110` read-only (as `main.gd` already does for v19) and upgrades them on load; it never writes there. Every new state field gets a migration, a validator entry and a round-trip test. The opening ids `capital`, `workers` and `science` stay valid.
- **Freeze, don't delete.** Frozen features sit behind flags in a new `progression.json` `features` block, all false. Their code, data and tests stay. Frozen content is hidden from the interface, never drawn by events and never chosen by bots. A save that already contains frozen content loads and keeps running it; nothing new of that kind can be started.
- **Player text.** Simplified Chinese, following `docs/v17/events_rewrite/03_创作准则与奖惩标尺.md` (B adds a section on company letters). Numbers in text are filled from data, never typed.
- **Interface.** A separate UI brief follows this one. In 1.11 the new screens are functional, built with `game/ui/design.gd`, each in its own script, so the UI pass can restyle them without touching rules. No broad layout changes. HUD changes are limited to the meter pair (B), the days to the next ship (D) and the news line (I).
- **Sound.** None in 1.11. Add `game/ui/cues.gd` (new) with `play(id: String)` that does nothing yet, and call it on ship arrival, stamp, signature, letter arrival, storm warning and ending. A later audio pass fills it in.
- Each phase ends with suites green (apart from the four Windows-recorded suites on Linux), a harness run in `BALANCE.md` (quick is enough until J), `PROGRESS.md` and `DECISIONS.md` updated, and a tag `v111-<letter>`.
- Ask the user only for a change of premise, dropping a requirement, the light concept sheet, deleting or rewriting user data, or acting outside the repository. Everything else goes in `DECISIONS.md`.

## Order

A–E and J are required for 1.11.0. F–I are expected; if one cannot be finished, it ships behind its flag and is reported as partial.

### A. Baseline and freezes (first, small)

Branch, version, save schema and user directory as above. Update the "current job" paragraph and the save rules in `CLAUDE.md` for 1.11, `v17-charter` and this plan.

Feature flags, all false:

- `metals`: `mine_nickel`, `mine_cobalt`, `superalloy_works`, nickel and cobalt deposits and signals, and the techs and events that exist only for them. World generation is unchanged (world hashes stay); nothing shows or uses these deposits.
- `seabed`: `seabed_mine` and its offshore cargo chain. Offshore surveying stays.
- `shuttles`: the `shuttle` road kind in `economy.json` `roads`.
- `radius_slider`: new games use radius 1.0 (`geography.json` `radius_km`); the slider is hidden.
- `research_commissions`: paying outside labs to speed research (`progression.json` `research.commission`). Inbound research contracts (`research.contract_tech`) stay; C builds on them.

Kept on purpose, do not freeze: the public services budget (the player's lever on colonists' mood, see B), the career fund transfer (it pays for the buyout ending, E), every great work (Annex VII uses them, E), pollution, crews.

A quick harness labelled `1.11-A`, compared with `placement-c5dda12`, the last full run, which was made before the metals and seabed chain existed. Expect no material change; explain any.

### B. The contract as a document, the company's voice, two meters, two names

**Clauses.** `contract.json` gains `clauses`: standard clauses generated from rules that already exist (stage deadlines, the review and intervention thresholds, overdue distrust, the post-award share from `career.json` `management.player_share`, company aid terms, force majeure from F). Each clause has an id, a Chinese title and a text template filled from data. Origins (C), amendments (D) and Annex VII (E) add clauses.

The contract page shows a document: numbered clauses (第 N 条); the five stages as milestones that receive an acceptance stamp (已验收 and the date) when completed; signed amendments (补充协议 N); the sealed Annex VII. Functional, in its own script.

**Letters.** `Company.letter` becomes a structured letter: sender department (运营部, 财务部, 合规部, 公关部), subject, CC list, body, and an optional handwritten note from the liaison (`game/assets/portraits/liaison.png`) about what is really happening at headquarters. Templates live in `game/data/v17/letters.json` (new). Letters are listed on the company page.

**Voice.** Add a section 公司来信 to the writing guide: the company writes in a correct, dry, slightly absurd corporate register (memo header, CC line, deadline); the liaison's note is personal; the colony's voice stays as in the events. Rewrite only the wording, keeping ids, nodes, choices and effects, of `company_audit`, `vp_visit`, `new_tax_letter`, `ledger_hole`, `second_ship`, `industry`, `price_window`, `investor_offer`, `supply_delay` and `nw_d_empty_seat`.

**Two meters.** The HUD gauge in `game/ui/distrust_gauge.gd` becomes a pair in the same slot:

- 公司评级: a letter A, B, C or D from distrust, with bands in data (A below 20 to start, B below `review_threshold`, C below `intervention_threshold`, D above); the number on hover.
- 民心: the population-weighted mean of settlement appeal from `population.gd`, shown 0–100 through a mapping in data.

In 1.11, 民心 is displayed and read only by the autonomy ending (E). The services budget is its lever; the budget's tooltip says so.

**Two names.** A new game gives the colony a company code CC-NN (NN from the seed; old saves get one on load). Company letters, reports and the contract say "CC-NN 项目"; colony-voice text uses the capital's name. No rule reads either string.

### C. Origins (replacing the three openings)

Stellaris-style origins: each is a type of contract with a reason to exist, gains, costs and one unique rule that changes how the first years play.

**Data.** Keep `economy.json` `openings` and its ids (saves store `state.advantage`). Each entry gains `story` (one Chinese sentence), `effects` (permanent modifiers on the effect keys that techs and great works already use), `clauses` (ids shown in the contract), `rules` (parameters of its unique rule) and `favours` (one of the stage-three routes in `contract.json` `routes`, or none).

**Effects.** Add the origin as a third source in `Research.bonus` (techs, great works, origin), cached the same way.

**The six origins.** The numbers are starting points for J.

| id | name | gains | costs | unique rule | favours |
|---|---|---|---|---|---|
| `capital` | 标准承包 | today's extra cash and first-expedition discount | none | the slowest annual-report ratchet (D); marked 推荐首局 | none |
| `workers` | 工程承包 | today's extra workers and prefab habitat | today's lower cash; wages may not go below 1.1× | starts with 2 crews (`population.json` `crews.opening` is 1) | none |
| `science` | 科研托管 | today's lab, 12 teams, narrower survey band and head start | today's fewer miners | `research.contract_tech` granted at landing; research-contract income ×1.5. No research-speed bonus: research-first already wins with every opening (BALANCE.md) | none |
| `resettlement` (new) | 移民安置 | 60 extra residents at landing; immigration +0.15 | 30% less cash and materials | a monthly resettlement subsidy for each resident who has both a bed and a job, booked as operating income on a new ledger line 安置补贴 | `food_corridor` |
| `mining_pledge` (new) | 矿权抵押 | `mine_output` +0.2 | each annual ship takes an unpaid ore tribute from stock (tonnes by stage, in data) | the mining line of the annual report is this physical delivery and cannot be over-reported (D) | `mining_network` |
| `archipelago` (new) | 群岛开发 | a prefab harbor; `offshore_survey` −0.5 | `road_cost` +0.5; dearer orbital freight | the first settlement must be coastal; placement refuses inland ground with that reason | `coastal_trade` |

If an effect needs a key that does not exist (for example, cheaper orbital freight alone), add the key and record it.

**New game screen.** One card per origin: story, gains, costs, unique rule, favoured route. Functional.

**Bots and harness.** The openings matrix runs all six origins. Where the balanced bot cannot represent an origin's intended play, add `housing_first_bot`, `mining_bot` or `coastal_bot` as subclasses of the balanced bot. Targets: balanced award medians across origins within 15%; the best bot differs by origin (the row 1.10 misses).

**Tests.** Starting state per origin; effects reach `Research.bonus`; the wage floor, coastal founding, tribute and subsidy are enforced; old saves with the three old ids load and play on unchanged; the tutorial (standard contract) stays green.

### D. The annual ship and the ratchet report

The user's design: the report does not ask the player to type numbers. It asks whether mining and farming met their targets, and lets the player claim more than the truth for a bigger reward, at the price of a higher target next year.

- **The ship.** The company's annual ship arrives at the capital (or the first settlement until there is a capital) on each landing anniversary (`career.json` `calendar.year_days`). A ship light descends on the globe and in the district; a notice opens the report. The HUD shows the days to the next ship. `supply_delay` can delay the ship, and the report with it.
- **Lines.** Two lines in 1.11: 矿业 (ore mined in the year, tonnes; frozen metals excluded) and 农业 (food produced in the year, tonnes, harbour catch included). Targets by contract stage live in `progression.json` `annual_report.base_targets` (new). Calibrate them from the harness (balanced bot, normal: median production in that stage-year × 0.9) and record the calibration.
- **Choices.** Per line, three buttons: 如实 (report the actual), 报达标 (report max(actual, target)), 报超额 (report max(actual, target × `exceed_factor`), 1.2 to start). One screen, one signature to send.
- **Outcomes.** Per line, by the tier reported: missed adds `miss_distrust`; met pays `met_reward`; exceeded pays `exceed_reward` and removes `exceed_trust` distrust. Rewards scale with `EventsV2.money_scale`, like event money.
- **Ratchet.** Next year's target for a line = max(the base target of the stage current then, the reported value × `ratchet_growth[origin]`). `capital` has the lowest growth.
- **Gap.** Per line, gap += max(0, reported − actual). In later years the surplus of actual over reported fills the gap first. The report screen shows the gap as 账面差额.
- **Audits.** While any gap is open, the draw weight of `company_audit`, `ledger_hole` and `vp_visit` is multiplied by 1 + `audit_k` × gap / target (candidate weights in `events_v2.gd`). Each of the three gets a new node used when a gap is open: exposure charges a fine of gap × export price × `fine_factor`, adds `exposure_distrust`, closes the gap and leaves the targets where they are. Follow the save rules for event versions; events already open in old saves keep their nodes.
- **Mining pledge.** For `mining_pledge` the mining line is the tribute: loaded from stock on arrival; a shortfall is a miss; that line has no claim buttons.
- **Amendments.** The ship may carry one amendment, opened with `EventsV2.trigger` on arrival, from `industry`, `price_window`, `second_ship`, `new_tax_letter` and `investor_offer`. Add choice keys that change the contract for good: `deadline_shift` (days, current stage), `company_share` (points on the post-award share), `kpi_scale` (next year's targets), `add_clause` and `remove_clause`. Give each of the five events one amendment choice in a new node. Signed amendments appear in the contract.
- **State and audit.** Report choices go through `Sim.act("annual_report", ...)`; the arrival happens in `Sim.tick()`. `audit()` checks that gaps are never negative, that every reward, fine and tribute is booked, and that targets follow the ratchet.
- **Harness.** Bots get a reporting policy: honest (default) and inflating. Target: the inflating policy has more cash in years 1–2 and a worse median outcome by years 4–5 (later award, more reviews or failures). Record both.
- **Tests.** Schedule and delay; the three choices; the ratchet arithmetic; gap filling; audit weighting; exposure; the tribute; amendment effects; a save round-trip with an open gap.

### E. Annex VII and three endings

**Annex VII.** From the first day the contract shows a sealed annex: 附件七（密封）：第四阶段验收后启封. Its variant is drawn from the seed at a new game (old saves draw one on load). It opens with a letter at the acceptance of stage four (`self_reliance`). Each variant gives a late goal to an existing great work. Three of them had none standing at the end of any run in the last full harness (terraforming, exchange, shipyard: 0 of 21).

| variant | what the company wants | great work | linked events (weight raised after opening) | unique rule |
|---|---|---|---|---|
| `terraform_trial` 改造试验 | proof, for a larger client, that this world can be terraformed | `terraforming` | `archive_grant`, `nw_d_weather_lease` | a bonus per terraforming level completed by the final deadline |
| `rights_sale` 矿权转卖 | the company is selling the mining rights | `exchange` | `price_window` | 360 days after opening, the buyer takes the two most productive mines, unless the player has delivered the stated ore or completed the exchange first |
| `secret_station` 秘密设施 | an undisclosed orbital facility | `shipyard` | `silent_probe` | while it is being built, a monthly chance that the colonists find out (民心 falls); revealing it ends the checks |
| `beneath` 地下的东西 | the company knew what lies under the ground | `university` | `nw_e_buried_sky`, `archaeology` | an excavation site; finds go to the company (cash, trust) or to the public (民心, research) |

On opening, the player answers 照办, 周旋 or 公开. The answer sets `state.ending_lean` (`loyal`, `buyout` or `autonomy`), adds the variant's late goal to the contract, and moves distrust and 民心 by amounts in data.

**Endings.** Three, kept small:

- 效忠 (loyal): the governor award as today, then the handover.
- 收购 (buyout): after the award, `Sim.act("buyout")` succeeds when the career fund covers the price (`career.json`: a multiple × the company's share × trailing 360-day operating profit, with a floor). The existing career transfer (2:1, yearly cap) is how the player saves for it. It ends the company's share.
- 自治 (autonomy): after the award, `Sim.act("declare_autonomy")` succeeds when 民心, population and the company rating meet thresholds in data, or when the Annex VII answer was 公开 and 民心 meets its threshold. No embargo phase in 1.11.

Every ending, and the existing takeover, shows a settlement statement (结算单): per stage, what was promised and what was delivered; the annual reports and gaps; amendments; rewards and fines; the player's share; landmarks. Then the lights time-lapse (G). Afterwards the player can continue in sandbox or start the next contract, as today.

**Tests and harness.** Scripted runs reach each ending. INFO rows: Annex VII variants drawn, answers given, endings reached and on which day.

### F. Weather that matters

Today the clouds and storms are cosmetic (`game/world/visual_clock.gd` states that nothing reaches the simulation), and weather disasters are random draws. Join the two.

- **Weather in the simulation.** `game/simulation/weather.gd` (new) generates weather systems from the seed and the day and advances them once a day in `Sim.tick()`: cyclones over warm ocean, dust over dry interiors, cold waves in cold climates, heavy rain over river basins. Genesis zones, frequencies, sizes, speeds and lifetimes live in data, by climate and latitude from `geography.json`. State holds the active systems. The views draw them from state; `visual_clock.gd` only smooths their motion between days.
- **Disasters from weather.** When a system reaches a settlement, its event opens through `EventsV2.trigger`: heavy rain opens `flood_season`, a cold wave `cold_snap`, coastal fog `sea_fog`. Cyclones and dust use an existing incident if one fits; otherwise write one new incident for each, following the writing guide. These events leave the random draw while weather is on.
- **Warnings.** A system heading for a settlement within `warning_days` raises a notice and a map marker. The player can pay to prepare (secure, stockpile), which cuts the losses.
- **Weather station.** A new building `weather_station` (气象站): cheap and early; it covers settlements within a range, doubles their warning days, and its records make force majeure claims valid.
- **Techs.** Two new techs: 天气预报 (more warning days) and 防灾工程 (smaller weather losses). Weather control through `climate_regulator` is for later.
- **Force majeure.** A standard clause: within 15 days of a weather disaster at a settlement, `Sim.act("force_majeure", ...)` files a claim. It is accepted when a weather station covered the settlement or the warning was logged. Acceptance extends the current stage deadline by the disaster's length and waives that year's miss on the affected report line.
- **Clouds.** Cosmetic, in the cloud shell of `shaders.gd`: two layers moving at different speeds; finer detail with domain warping; a warm edge along the terminator; on the night side, clouds lit faintly from below by city lights. Storm markers stay visible when clouds are switched off in the settings. Frame times stay within the 1.10 figures on the user's PC (see the Windows verification plan).
- **Tests.** The same seed gives the same weather by day at any speed; a system reaching a town opens its event; warning days with and without a station and the tech; force majeure accepted and refused; saves; `audit()` covers weather losses.

### G. Lights at two scales; the flat map as a tool

- **Planet scale.** At the globe's default and far distances, each settlement shows a city-light form that follows the user's five-stage concept sheet 沿海与内陆的灯光形态 (stages 着陆点, 首批住区, 小镇, 区域中心, 星球首府): a lit street grid with a warm core; coastal towns cut by the coastline; inland towns spreading outwards; growth along the roads the player actually built. The stage comes from population and facility count, with thresholds in data. Each remote facility (mine, harbour, outpost) is a small point of its own; roads between settlements are faint strings of light. The forms are deliberately larger than the plots: at the default distance a capital must read as a city, not a point, and neighbouring towns must stay apart. The sheet is not in the repository. Ask the user for it, keep it at `docs/v17/lights/concept_light_forms.png`, and do not invent another look.
- **Close up.** The district and near zoom keep the 1.10 per-plot lights (`light_field.gd`). Crossfade by camera distance, with no double brightness.
- **Time-lapse.** Each quarter, record a light snapshot in state (per settlement: position, stage, population, facilities, roads). At every ending, play a night time-lapse of about 20 seconds on the globe, from the landing to now; it is also available on the career page.
- **Flat map.** It opens only from founding (site picking) and prospecting, and returns to the globe. No further parity work on it (clouds, day and night, lights, traffic). The main navigation has two views: globe and district.
- **Captures.** The five stages, coastal and inland, at the default globe distance, plus crossfade frames, next to the sheet in `docs/v17/lights/`.

### H. Merge the technologies

- Merge pure-bonus techs (techs that only add effects, unlock nothing and are required by nothing) within the same category and tier, adding their effect values per key. `Research.bonus` adds effects, so the totals with everything researched are unchanged. Keep every tech that unlocks a building, upgrade or rule, or that other techs require. Target 55–65 techs (134 today).
- A merged tech costs the sum of its parts × `merge_cost_factor` (0.8 to start, in data).
- **Saves.** Map old ids to new ones: a merged tech is complete if all its parts were; otherwise its progress is the research points of the parts already done. Research in progress converts. The event keys `tech_gift` and `research_lead` that name a removed id are remapped.
- **Contract goals.** Replace the technology counts in `contract.json` (5, 14, 24, 40) with tier milestones calibrated so that the balanced bot meets them at about the same day as the old counts. Update the rows of `docs/v17/V18_BRIEF.md` that count techs.
- **Tests.** Conservation (per key, before and after, frozen content excluded); every tech reachable; migration.

### I. The news line

- One line of news, for now at the bottom edge of the screen (its final place comes with the UI pass). Interface only: it reads state, never writes it, is not saved, and its randomness comes from a UI-side generator seeded by the day, so the simulation hash is the same with it on or off.
- Templates live in `game/data/v17/news.json` (new), keyed by conditions on state: the company and the market (a company share index that moves with the annual reports; price changes); weather warnings, only when the system exists in state; echoes of resolved events (their outcome); milestones; rumours about Annex VII before stage four; flavour lines about other colonies and the company, with no system behind them.
- Rules: it never asks for a decision; it says nothing about an event that is waiting for one; forecasts come only from state; cooldowns and priorities live in data; it pauses while an event panel is open; company lines use the company voice and colony lines the colony voice.
- **Tests:** scripted scenarios find no line that contradicts state; no line during a pending decision on the same subject; the simulation hash is unchanged by the news line.

### J. One rebalance, then the release

- After A–I, one full harness, and tuning of data only. Targets: every row of `docs/v17/V18_BRIEF.md` still in force (rows this plan changes are updated there with a note), plus the new rows in "What is measured". Where the new systems allow, address the 1.10 misses: research-first winning with every origin, the wage lever (at least a 20% effect on 360-day immigration), and jobs limiting growth from 200 to 600 people.
- A new INFO row: the longest stretch of days in which the balanced bot had no meaningful decision available (define "meaningful" in `DECISIONS.md`).
- **Release 1.11.0.** `CHANGELOG.md` (Chinese, player-facing, house style); a 1.11 section in `PROGRESS.md` with a plain status for each phase (done, partial, failing); `DECISIONS.md`; `BALANCE.md`; the Windows build (`tools\build_v17.ps1`) and the Windows checks (`docs/superpowers/plans/2026-11-08-v19-windows-verification-instructions.md`); a playtest script for the user's friends in `docs/v17/PLAYTEST.md` (the first 30 minutes: tasks to try, questions to ask).

## Not in 1.11.0

The UI restructure, brand and logo (separate brief); audio and music; new planet classes and terraforming careers; merging the 1.9 ground survey into the 1.10 prospecting flow; simplifying road and dock levels; company acquisition; multiple employers; the contractor dossier; the liaison's career; an on-site auditor character; the previous contractor; contractor rankings (flavour lines in the news are fine); an onboarding re-skin of the tutorial.

## What is measured

- **Origins:** award medians; the best bot per origin; the day of the first export or ship; the stage-three route each origin takes.
- **Annual report:** cash and distrust paths under the honest and inflating policies; audits per run; exposures.
- **Endings:** Annex VII variants and answers; endings reached and on which day.
- **Weather:** systems per year; hits per settlement-year; losses; warnings acted on; force majeure claims accepted.
- **Lights:** the capital's size in pixels at the default distance; the stage reached by year.
- **Techs:** the conservation check; research days per category before and after.
- **Pace:** the longest stretch without a meaningful decision; the ship and report cadence in real minutes at 1×, 3× and 6×.
