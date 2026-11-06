# Colony Charter 1.9 — late-game money and the 3ds Max models

Instructions for Claude Code. Written 2026-11-01 against the 1.8.0 source (commit `af752d2`) and
`art_reserve/max_highpoly_20261031`. `CLAUDE.md` still applies except where §0.3 changes it, and every row
of the 1.8 bar in `docs/v17/V18_BRIEF.md` stays. §4 adds new rows.

Two jobs:

- **Part A — money.** The colony has far too much money from about year 3. Make money matter through year 6,
  and give the late game things worth spending on.
- **Part B — models.** Convert the Codex 3ds Max masters into game meshes, put one on every building kind,
  and list what is still missing (Part C).

The two parts touch different files. They can be worked on in parallel, but don't run the model converter
during a full harness run.

---

## 0. Setup

### 0.1 The request, verbatim (copy into `docs/v17/V19_BRIEF.md`)

> This game is actually 11 GB now. Take a look at the code and gameplay. There is a problem right now: it feels
> like there is too much money (especially in the mid-to-late game). Also, I had Codex create a lot of models
> using 3ds Max. Take a look at where they can be placed, whether they are enough, and if anything else is
> needed. As for exactly where to put them, give me an instruction, and I'll paste it to Claude Code later.

### 0.2 First commit

1. `docs/v17/V19_BRIEF.md`: the request above, the bar in §4 and a pointer to this file.
2. `docs/v17/V19_PLAN.md`: your order of work, starting from §6.
3. `CLAUDE.md`:
   - Set the current job to 1.9.
   - Reading list: V19_BRIEF, PROGRESS, V19_PLAN, DECISIONS.
   - Saves: 1.9 writes to `%APPDATA%\ColonyCharter\v19` (`project.godot`
     `config/custom_user_dir_name="ColonyCharter/v19"`). It reads 1.8 saves from `v18` and 1.7 saves from
     `v17`, read-only.
   - Replace the art_reserve paragraph with §0.3.
4. Version 1.9.0 in `config/version` and `config/name`. Stay on branch `v17` and tag phases `v19-phaseN`.
   Folders keep their `v17` names.

### 0.3 art_reserve in this job (this replaces the paragraph in CLAUDE.md)

`art_reserve/` belongs to the 3ds Max task. This job may **read** it and must never change it.

- **What to read.** Only these:
  - `00_brief/DELIVERY_TARGET_IDS.json`: which IDs are current.
  - `10_validation/<ID>.json`: per-asset metadata (size, bounds, door positions, axis, node list with
    bounds).
  - `08_exports/highpoly_fbx/<ID>.fbx`.
  - At most 10 images from `09_previews/beauty/` (§B6).
- **What not to do.** Never write, rename, re-save or move anything there. Never open `.max` files. Never
  `git add` it: it is in `.gitignore`, and it stays there.
- **Skip the big manifest.** Don't parse `ASSET_MANIFEST.json` (92 MB). The per-asset JSON has everything
  the converter needs.
- **The modelling task may still be running.**
  - Convert only the IDs listed in `DELIVERY_TARGET_IDS.json`.
  - Record each source FBX's size and SHA-256 in the conversion report.
  - If a source changes during a run, stop and run again.
- **What reaches `game/`.** Only the converter's runtime meshes and the downscaled images of §B6.

### 0.4 About "11 GB"

The shipped 1.8.0 is small: `ColonyCharter.exe` is 96.7 MB and `ColonyCharter.pck` is 14.2 MB, 47.9 MB
zipped.

The 11 GB is the working folder:

- `art_reserve`: 6.0 GB of high-poly FBX and MAX files, 4K textures, 551 MB of renders and 629 MB of
  validation data.
- `delivery\`, `build\`, `versions\`, `evidence\` and `.git` make up the rest.

`art_reserve` sits outside `game/`, so it is never exported. Keep it that way: no FBX, MAX, TIF or 4K PNG
goes under `game/`. Don't delete or move anything to save space. If you list candidates for archiving in
`PROGRESS.md`, the user decides what happens to them.

---

## 1. What was measured on 1.8.0

Source of every figure below:

- The balanced bot on standard difficulty, unless a row says otherwise.
- Run headless on the 1.8.0 source with the Linux build of Godot 4.5.1. Seeds replay identically on that
  build; see §1.3 for Windows.
- The probe scripts are in Appendix A; add them to `game/tests/balance/`.

Label these figures "balance harness probe, single seeds". Screenshots were taken with
`ui/capture_suite_v17.gd` in the same sandbox and viewed.

### 1.1 Money

Seed 260129, capital opening. One row per 360-day year.

- **Spent** means investment: construction, upgrades, recruitment, stock imports, roads and outposts.
- **Surplus** is operating income minus operating expense.

| Year | Operating income | Operating expense | Surplus | Spent | Spent ÷ surplus | Cash at year end |
|---|---:|---:|---:|---:|---:|---:|
| 1 | ¥175k | ¥110k | +¥66k | ¥104k | 158% | ¥4k |
| 2 | ¥531k | ¥261k | +¥271k | ¥277k | 102% | ¥13k |
| 3 | ¥1,076k | ¥532k | +¥545k | ¥576k | 106% | ¥21k (peak ¥109k) |
| 4 | ¥1,774k | ¥910k | +¥863k | ¥503k | 58% | ¥386k |
| 5 | ¥2,406k | ¥1,240k | +¥1,166k | ¥813k | 70% | ¥786k |
| 6 | ¥2,704k | ¥1,656k | +¥1,048k | ¥1,265k | 121% | ¥570k (award on day 2,265) |
| 7 | ¥3,338k | ¥2,236k | +¥1,102k | ¥962k | 87% | ¥721k |
| 8 | ¥3,872k | ¥2,406k | +¥1,465k | ¥460k | 31% | ¥1,740k |
| 9 | ¥3,727k | ¥2,367k | +¥1,360k | ¥346k | 25% | ¥2,754k |
| 10 | ¥3,423k | ¥2,319k | +¥1,104k | ¥104k | 9% | ¥3,762k |

Other runs, all to day 3,240 on the same source (a variant of `money_probe.gd` that samples every 180
days). **Cover** is public cash ÷ the mean daily operating expense of the previous 180 days: 100 days of
cover means the colony could pay every running cost for 100 days without earning anything.

| Bot, seed, opening, difficulty | Award | Highest cash | Cover, day 720 to the award (median / p90) | Cash on day 3,240 (cover) |
|---|---:|---:|---:|---:|
| Balanced, 260129, capital, standard (table above) | 2,265 | ¥3.76M, day 3,600 | 103 / 209 days | ¥2.75M (421 days) |
| Balanced, 20261029, workers, standard | 3,083 | ¥2.90M, day 3,240 | 108 / 392 days | ¥2.90M (526 days) |
| Balanced, 42, science, standard | 2,464 | ¥1.04M, day 3,240 | 11 / 52 days | ¥1.04M (132 days) |
| Balanced, 1234, capital, hard | 2,788 | ¥126k, day 2,700 | 31 / 55 days | ¥59k (8 days) |
| Balanced, 99991, workers, easy | **none: taken over on day 3,184** | ¥621k, day 1,800 | 85 / 223 days (to day 3,184) | ¥3k on day 3,184 |
| Research-first, 260129, capital, standard | 2,204 | ¥2.93M, day 3,240 | 7 / 13 days | ¥2.93M (252 days) |
| Rush, 314159, capital, standard | 2,314 | ¥494k, day 2,520 | 14 / 77 days | ¥11k (1 day) |

Every run passed `audit()` with no script errors. What the runs say:

- **Before the award, the pile depends on whether the bot finds things to buy.** Research-first pours money
  into teams and recruitment and never holds more than a month. Balanced runs that stall in stage 5 bank a
  year of costs. 20261029 held ¥137k on day 1,170, ¥374k on day 1,350 and ¥2.07M on day 2,880. It earned
  the award only on day 3,083, after sitting at distrust 89 under company review with millions in the bank.
  An earlier run on seed 1024 (science) stayed under ¥122k until day 2,520 and passed ¥1M on day 3,240.
- **After the award, the balanced and research-first runs on standard all pile up, and keep piling.** On
  seed 260129, cover went 180 → 260 → 339 → 421 → 517 → 588 days, every 180 days from day 2,700 to 3,600.
- **The other three end with almost nothing.** Rush spends everything on expansion. The hard run stays
  tight all game, under two months of cover. The easy run banked ¥621k by day 1,800, then spent it on 200
  more buildings. Income fell under expenses as its deposits ran out: ¥6,302 a day against ¥5,129 in the
  half-year to day 2,520, then ¥4,400 against ¥5,510 in its last four months. It was taken over during a
  food shortage it could not pay for. Point 6 below is the same knife edge seen from the other side.

What drives it:

1. **Raw exports are the engine, and they never stop paying.**
   - Exports were 80% of income in year 5. Ore, copper and crystal were 76% of exported tonnes.
   - By day 1,080 on seed 260129 (day 1,800 on seed 1024), ore, copper, crystal and parts all sit at the
     market floor (`market.json` `floor` 0.6).
   - At the floor, every extra tonne still earns 60% of the base price. So income grows in a straight line
     with the number of mines.

2. **Mines pay back in weeks and last for years.** These are the game's own `build_forecast` figures, best
   site, days 1,080–1,800:

   | Building | Payback | Deposit life |
   |---|---|---|
   | Light mines | 31–78 days | 1,600–2,700 days |
   | Heavy mines | 42–90 days | 540–900 days |
   | Automated mines | 80–162 days | 670–1,180 days |

   `V18_PLAN.md` aimed at 80–150 days. Processing is the opposite:

   | Building | Payback |
   |---|---|
   | Processor | 290–490 days |
   | Smelter | 330–590 days |
   | Pharma plant | about 300 days |
   | Commerce | 500–640 days |
   | Crystal vat | 340–1,120 days |

   The best move all game is "another mine".

3. **Two fixed incomes ignore the market.** Foodworks (`daily_payment` ¥78) and data centres
   (`daily_income` ¥280) pay as much for the 30th copy as for the first. When raw prices fell in the
   experiments below, the bot moved into foodworks: 35% of income by year 8 on seed 1024.

4. **Costs don't grow with the colony.**
   - Administration is ¥8 + ¥0.04 per resident + ¥8 per settlement a day. That is about ¥120 a day at 2,800
     people, or 2% of expenses.
   - Research funding is ¥8–46 a day per ten teams.
   - Upkeep is flat per building.
   - Only wages (60%) and upkeep (21%) are real costs.

5. **The late goals are not for sale.** Stage 5 waits on three things:
   - 40 technologies. Tier 4–5 technologies cost 1,000–1,600 points, at about 2 points a day per ten teams.
   - Population: 2,000, with 600 in the capital.
   - Fixed durations: the 240-day hall and the 180-day streak.

   Money buys none of these except people, through recruitment. Recruitment is already the second-largest
   spend: a quarter to a half of investment in years 3–6. After the award there are four unique great works and nothing
   else to buy.

6. **It is a knife edge, not just "too much".** Two quick experiments on seeds 260129 and 1024 with the same
   bot:

   | Change | Seed 260129 | Seed 1024 |
   |---|---|---|
   | Floor 0.3; administration scale 600 residents, +50% per extra settlement | Year-6 income halved (¥1.38M). Cash near zero from year 4, ¥118k in arrears. **Taken over on day 2,533** (food and arrears) | No award by day 2,880: stage 5 from day 1,888, 61 technologies, but only 1,901 people |
   | Floor 0.45; administration scale 1,500, +25% per extra settlement | Cash peaked at ¥147k all game. **Award on day 2,473** (in band; baseline 2,265). Year-6 income ¥1.74M | **No award by day 2,880.** 54 technologies, but 1,882 people while spending ¥360–400k a year on recruitment |

   The lesson:
   - Cut the free income gently.
   - Make population growth depend less on money.
   - Prefer **optional** ways to spend money to costs that every colony must pay. A mandatory cost that bites
     a stage-5 colony pushes it into the takeover spiral.

### 1.2 Models

What Codex delivered: 21 masters, all real 3ds Max 2024 geometry in metres, Z-up, fronts facing −Y. Each
has an FBX in `08_exports/highpoly_fbx`.

| Asset | Triangles | What it is | Game use |
|---|---:|---|---|
| CC_COMMAND_HP_v001 | 107k | Two-storey admin centre, glazed control drum, dish, braced mast, podium (25×26×17 m) | Yes |
| CC_HOUSING_HP_v002 | 66k | Habitat with a one-storey wing and a two-storey wing, glazed link, veranda, court (30×27×10 m) | Yes |
| CC_POWER_HP_v002 | 58k | Power hall, generator and heat exchanger, 16 PV tables, battery bank, transformers (35×28×13 m) | Yes |
| CC_WATER_HP_v003 | 99k | Clarifier with scraper bridge, filter vessels, pumps, pipework, hall (36×29×8 m) | Yes |
| CC_MINING_HP_v002 | 43k | Headframe, winding house, crusher, conveyor, ore bay (37×33×22 m) | Yes |
| CC_GREENHOUSE_HP_v003 | 191k | Three glass bays, hydroponic beds, nutrient tanks (31×33×8 m) | Yes |
| CC_RESEARCH_HP_v002 | 113k | Two-storey lab, glazed link, observatory dome, telescope, dish (35×21×11 m) | Yes |
| CC_INDUSTRY_HP_v005 | 90k | Gabled process hall, press annex, twin tanks, filters, stack, pipe rack (41×35×14 m) | Yes |
| CC_LOGISTICS_HP_v002 | 64k | Warehouse, 19 m gantry crane on rails, containers (44×38×14 m) | Yes |
| CC_CIVIC_HP_v001 | 61k | Community hall, butterfly canopy, kiosks, plaza furniture, trees (34×34×6 m) | Yes |
| CC_INFRASTRUCTURE_HP_v002 | 325k | 8 m road pieces, bend, crossing, landing pad, retaining wall, steps, pipe joint, 6 m lamp | Partly (§B5) |
| CC_ENVIRONMENT_HP_v002 | 200k | 3 trees, 1 shrub, 3 rocks, 1 grass clump | Partly (§B5) |
| CC_PLANET_260129_HP_v002 | 2.5M | The retired CC-GEO-1.6 world, seed 260129, at 1,000 km radius | Images only |
| R00/R01/R05 LOCAL and OVERVIEW | 0.26–2.7M | Terrain of that same retired world | Images only |
| CC_SETTLEMENT_R00/R01_HP_v004 | 6.5M / 7.1M | Two towns on that world, "initial" and "developed" layers | Images and reference |

Not every asset can be used in the game:

- **Planet, terrains and settlements: geometry is unusable.** They are locked to a world that 1.8 no longer
  generates. 1.8 worlds come from CC-GEO-2.2 at 0.6–1.3 Earth radii. The settlements are also far too heavy.
- **Buildings, infrastructure and environment are not seed-locked.**
- **None of it is game-ready.** There are no LODs (their brief forbade low poly), and the materials are Max
  Physical materials.

How the game draws buildings now:

- From primitives in `world/building_models.gd`: 15 shapes and a default. 40 of the 56 kinds borrow another
  kind's shape through `economy.json` `model`.
- The region view is a diorama:
  - `world/geo2/site_gen.gd` uses 4 local units per degree (`LOCAL_UNITS_PER_DEGREE`), so one unit is
    roughly 17–36 km depending on planet size.
  - Plots sit on a 6-unit grid.
  - Each building stands on a hex pad of radius 2.3.
  - The camera has a 43° field of view at 31–140 units (67 by default).
- So a 40 m building has to fill about 4 units. Real scale doesn't apply.

The prototype (Appendix B, screenshots viewed). The screenshots are next to this file, in
`docs/superpowers/plans/2026-11-01-v19-images/`: `region_models_before_after.jpg` (a 1.8 region with its
procedural buildings, then the same view with converted masters in place of the habitats and processors)
and `converted_models_closeup.jpg` (mining, industry and housing on their hex pads).

- **Loading works.** `FBXDocument.append_from_file()` + `generate_scene()` loads the Max FBX directly in
  Godot 4.5.1 at tool time.
  - The mining master arrives as 225 named nodes and 42,500 triangles.
  - It is already Y-up, with the Max front (−Y) at Godot +Z.
  - The FBX points at textures by relative path. That only logs warnings, and the textures aren't needed.
- **Decimation works.** `ImporterMesh.generate_lods(25, 60, [])` → take the LOD nearest a triangle target on
  each surface → drop unused vertices → generate LODs again. Results:

  | Master | Triangles | File (compressed, LODs included) |
  |---|---:|---:|
  | Mining | 3,874 | 53–68 KB |
  | Industry | 4,308 | 53–68 KB |
  | Housing | 4,264 | 53–68 KB |

- **Real scale reads badly.** At 0.1 units per metre the buildings were too small and flat beside the
  procedural ones. What read well:
  - Fit the longer side to 4.0 units.
  - Stretch the height ×1.3.
  - Keep the game's hex pad.
  - Use a lighter roof colour.
  - Drop thin parts: guardrails, stairs, mullions, rails, ropes, fans, cables.
- **Trees don't decimate.** The leaf crowns are separate cards and stop at 7,800 triangles. Branches go down
  to 532 and rocks to 516.

### 1.3 Other notes

- **The residents' account is a different pile.** The top bar shows public cash only. The ledger page's
  「居民账户」 also climbs, to ¥2–3M by day 3,000 in every run of §1.1. Residents earn wages and spend only
  on food (`population.gd feed`) and private services (`enterprise.gd`, at most ¥0.35 per person a day).
  That money is not the governor's and doesn't drive the public surplus, so leave the flow alone in 1.9.
  Do label it on the ledger page as savings the governor cannot spend, for example
  「居民储蓄（总督无法动用）」, so nobody reads it as spare money.
- **Fixtures across builds.** The 1.8 fixtures written on Windows fail to load in the Linux build with the
  message "世界与当前生成器的结果不一致". World generation is not bit-identical across engine builds. The game
  ships for Windows only, so this is low priority. In the next playtest, check that a save loads on a
  second Windows PC (Intel vs AMD).

---

## 2. Part A — money

### A1 Intent

Money binds through year 6 and keeps a use after the award. Do it in two halves:

1. Take the free money out gently: the market, the paybacks, the uncapped fixed incomes and a mild cost for
   size.
2. Add **optional** ways to spend money that buy what binds late. Prices rise as you buy more, and there is a
   ceiling on how much time money can buy. Money should matter, but it must not buy the charter.

### A2 Changes, in this order

Run a quick harness after each change and a full run at the end of each phase. Numbers are starting points;
calibrate with the harness and record every value you settle on in `DECISIONS.md`.

**A2.1 Market floor** (`market.json`, `market.gd`, market page)

- Lower `floor` from 0.6. Start at 0.45 and don't go lower until the bots adapt (see §1.1, point 6).
- A second lever if needed: `decay_per_day` 0.02 → 0.015, so saturation lingers.
- On the market page, show:
  - the price and the floor;
  - the price the next 100 t would sell at;
  - the trend.
- When a good sits at the floor, the advisor says so, for example
  「市场已饱和：再多卖只能按底价结算」.

**A2.2 Paybacks as a test** (new suite `v19_payback`)

- **Fixtures.** Have `tests/make_fixtures_v17.gd` also write `acceptance_y2.save`, `acceptance_y4.save` and
  `acceptance_y6.save`: balanced bot, seed 260129, capital opening, days 720, 1,440 and 2,160.
- **The check.** For every income building (roles mine, harvest, factory, foodworks, income, commerce), take
  the best `build_forecast` over all settlements. Assert these bands:

  | Building | Band |
  |---|---|
  | Light mines | 70–150 days |
  | Heavy and automated mines | 100–220 days |
  | Harvest buildings | 120–300 days |
  | Factories (at y4) | 120–300 days |
  | Foodworks | 100–220 days |
  | Data centre and commerce | 150–320 days |

  Write the table into `BALANCE.md`.
- **Knobs** (data first, formulas only if a band can't be met otherwise):
  - In `economy.json`: mine `maintenance`, `cost` and `rate`.
  - In `techs.json`, late output bonuses. `mine_output` adds up to +0.75 and `farm_output` to +1.40. Consider
    a cap on the summed bonus of any one key.
  - Processors, toward their band. Most of their output replaces imports, so `build_forecast` should value
    locally used materials and parts at the import price (`Production._import_price`), not at the saturated
    export price. Check how the bots read it.

**A2.3 Fixed incomes saturate** (`economy.json`, `logistics.gd` foodworks, `production.gd` role `income`)

- **Foodworks.** The orbital supply bureau should buy a limited amount. Prefer making "processed food" a
  market good with its own `scale`: one rule for everything, and it shows on the market page. The other
  option is a colony-wide quota, where each foodworks beyond the sixth earns ×0.8 of the one before.
- **Data centres.** Each additional one earns ×0.85 of the one before. Say so in its description and the
  build preview. A market good "compute" would also work.
- Commerce is already limited by its customers. Leave it.

**A2.4 A gentle cost for size** (`sim.gd _admin_cost()`, `economy.json`)

- The per-resident term becomes × (1 + residents / `admin_resident_scale`).
- The per-settlement term becomes × (1 + `admin_settlement_growth` × (settlements − 1)).
- Start at the gentle values: 1,500 and 0.25, **not** 600 and 0.5 (§1.1, point 6). Civic centres and
  administration technologies still reduce it.
- On the economy page, show the administration line with how it grows:
  「每多 100 人 +¥x/天，每多一处据点 +¥y/天」.

**A2.5 Surcharge for more copies** (`production.gd`: build preview, refusal, build, upgrade preview and
`build_forecast`)

- Cash cost × (1 + `copy_surcharge` × the number of copies of this kind standing or under way in the colony),
  up to `copy_surcharge_cap`.
- Start at 0.04 with a cap of ×2.0.
- Exempt great works, roads and outposts. Materials and parts are unchanged.
- The build preview shows 「第 n 座 +x%」. `build_forecast` and payback include the surcharge.

**A2.6 Optional ways to spend money** (Phase 2)

a. **委托研究 (commissioned research).** In `research.gd`, the research page and `techs.json`.

- **Only on a project that already has its own team working.** The player picks level 1 or 2:

  | Level | Extra points a day | Speed-up |
  |---|---|---|
  | 1 | in-house rate × 0.5 | ×1.5 |
  | 2 | in-house rate × 1.0 | ×2 |

  No team, no commission. Teams stay at the heart of research.
- **Price per point, by tier:** ¥100 / 150 / 220 / 320 / 450 (starting values). Multiply by
  (1 + 0.25 × the number of other active commissions).
  - Example: a tier-4 project running at 2 points a day, at level 2, gets +2 points a day for ¥640 a day.
- **How it is paid.**
  - Daily, from public cash, as investment: ledger key `research.commission`, not operating, like
    construction.
  - Only when cash covers the day; otherwise it pauses and gives the reason.
  - It never creates debt.
- **The research contract that sells points for ¥50 is unchanged.** Selling stays cheaper than buying, so
  there is nothing to arbitrage.
- **On the page.** Each project gets a two-step switch, its cost a day and 「预计提前 N 天」.

b. **公共服务预算 (public services budget).** A policy next to the wage policy.

- Levels 0–3 cost ¥0.3 / 0.6 / 1.0 per resident a day, booked as operating expense `services.budget`.
- Starting effects:

  | Level | Attractiveness | Departures | Births | Pollution health bill |
  |---|---|---|---|---|
  | 1 | +0.05 | × 0.85 | × 1.1 | × 0.85 |
  | 2 | +0.10 | × 0.70 | × 1.2 | × 0.70 |
  | 3 | +0.15 | × 0.55 | × 1.3 | × 0.55 |

  The attractiveness bonus shows as its own line in the attractiveness breakdown.
- Level 0 behaves exactly like 1.8.
- This is also the answer to §1.1, point 6: people can be bought gradually and kept, not only recruited.

c. **生涯资金转存 (career transfer).** After the award only.

- Public cash moves to the career balance at 2 : 1, up to ¥200,000 of career funds per 360 days.
- Ledger key `career.transfer`, not operating. The career page shows it.
- This is the release valve for a colony that has built everything. It is not the main way to spend money.

Not recommended unless the above miss the money rows after calibration: a company royalty on exports by
stage. It removes money without giving the player a choice.

**A2.7 Late great works** (Phase 4: `economy.json`, `megaprojects.gd`, `techs.json`, models in §B)

Five long, expensive projects with real effects. They also give the time after the award something to do.

| Project | Cost | Build time | Effect |
|---|---|---|---|
| **行星改造计划 (terraforming programme)** | ¥120k / ¥200k / ¥320k | 240 / 300 / 360 days | Three stages, see below |
| **首府新区 (capital district)** | ¥60k × 1.4^(level − 1) | 120 days | Each level: +120 beds, +0.05 attractiveness, −2% administration |
| **星际交易所 (off-world exchange)** | ¥150k | 200 days | Every market `scale` +50%: buys income back, at a price |
| **轨道船坞 (orbital shipyard)** | ¥90k | 180 days | Expeditions and sea routes −30% cost; sea speed +25% |
| **行星应急网 (planetary emergency network)** | ¥100k | 200 days | Event losses −30%; road closures −50% |

- **Terraforming programme.** Three stages (大气调和, 水循环, 土壤培育), built one after another in any residential
  settlement, with upkeep of ¥60 / 90 / 120 a day. Each stage, planet-wide:
  - temperature moves 1 °C toward the comfortable band;
  - rainfall × 1.05;
  - farm fertility +0.04.

  The planet view shows it in water and vegetation tint.
- **Capital district.** Up to five levels, in the capital.
- New tier 4–5 technologies unlock them. Keep the pool rows: at least 100 technologies in 4 categories.
- The `four_megaprojects` milestone counts kinds, not levels.
- Calibrate after A2.1–A2.6. Drop any project the harness shows nobody builds.

**A2.8 Bots** (`colony_bot.gd` and the rest)

- Add `cash_cover()`: public cash ÷ mean daily operating expense over the last 90 days. Replace absolute
  thresholds such as `RICH_CASH` (120,000) with cover thresholds.
- What each bot does:

  | Bot | Behaviour |
  |---|---|
  | Balanced | At cover ≥ 90 days, commission the project that leads to the next charter goal. Raise services one level at cover ≥ 120 and lower it below 45. Build great works at cover ≥ 150 once they are unlocked. After the award, transfer at cover ≥ 240 |
  | Research-first | Commissions first |
  | Rush | Everything |
  | Passive and sloppy | None of it |

- **Windfall scenario** (a harness case, not a bot): the balanced bot gets ¥1,000,000 on day 1,080 (ledger
  `test.windfall`, funding) on 10 seeds. Compare with the same seeds without it.

**A2.9 Harness and `BALANCE.md`**

- **Cash cover** (`cash_cover()` above), sampled every 30 days. Per run, report the median and p90 between
  day 720 and the award, and the value on the last day (3,600) for runs awarded by day 2,880. The §1.1 table
  is the 1.8 baseline; it used 180-day means, so re-measure the baseline with the new metric before
  changing anything.
- **Takeovers**, before and after the award, by difficulty and cause, next to the 1.8 counts.
- **Absorption per 360-day year**: spent ÷ operating surplus, for years 3–7.
- **Spending per sink per year**: commissions, services, great works, transfer, recruitment, upgrades.
- The payback table (A2.2) and the windfall row.
- Keep `money_probe.gd` and `payback_probe.gd` (Appendix A) for single runs.

**A2.10 Interface**

- **Economy page.**
  - 「现金可支撑 N 天」, coloured by band: under 30 days red, 30–120 normal, over 180 「钱闲着」.
  - 「钱花在哪」, by sink and year.
- **Advisor.**
  - When cover is over 180 days, it suggests something to spend on: a commission, services or a great work.
  - When more than a third of export income comes from mines with under 360 days of reserves left, it
    warns before the money dries up, for example 「三成以上出口收入来自一年内将采空的矿，收入会下滑」. The
    easy run in §1.1 went from a ¥621k pile to a takeover without any such warning.
- **Top bar.** The tooltip shows the cover days.
- **README.** Replace the known limitation 「后期钱会花不完」 with the new ways to spend, but only if the money
  rows pass. If they don't, say what still misses.

**A2.11 Saves**

- Schema 5. New fields get defaults when a 1.8 save loads:
  - `policy.services` 0;
  - commission level 0 on every project;
  - the `career.transfer` counters;
  - great-work levels.
- 1.8 saves continue under 1.9 rules, with one line in the log. The original files are never changed.
- Extend `v17_saves` and `v18_systems`.

---

## 3. Part B — the models

### B1 Verdict: what can go where

| Asset | In the game? | Where |
|---|---|---|
| 10 building masters | **Yes**, converted | Region-view buildings (B2), icons (B6) |
| Infrastructure kit | Partly | Main-street lamps; landing pad under the port and hospital; road colours. The road ribbons stay, because they follow terrain for hundreds of km |
| Environment library | Partly | Rocks (≤ 500 triangles each). Trees only with a rebuilt crown, otherwise keep the procedural trees (B5). Park decoration |
| Planet 260129 | No (as geometry) | Menu or loading illustration. Ideas for `planet_view`: cloud shell, atmosphere rim, settlement lights at night |
| Terrains R0/R1/R5 | No | Loading or tutorial illustration at most |
| Settlements R00/R01 | No | "Initial → developed" renders for the stage-complete and award screens. A layout reference for a later town-planning pass |

### B2 Placement: every building kind

**What the recipes mean:**

- `kit.part` is a sub-assembly cut from one master (definitions under the table).
- `A + B` is a kitbash: sub-assemblies placed together on one plot.
- **Interim** means it works and looks distinct, but Part C lists a better model.
- **P0–P2** is the priority of that better model.
- Great works fit 5.0 units; everything else fits 4.0.

| # | Kind | 中文 | Recipe | Status |
|---|---|---|---|---|
| 1 | habitat | 模块住区 | `housing.full` | exact |
| 2 | apartment | 公寓楼 | 2 × `housing.two_storey` in an L | interim · P2 mid-rise block |
| 3 | arcology | 生态穹顶城 | `greenhouse.one_bay` + 2 × `housing.two_storey` | interim · P1 dome city |
| 4 | crew_quarters | 工棚营地 | `housing.compact` | exact |
| 5 | frontier_lodge | 边疆宿舍楼 | `housing.two_storey` | exact |
| 6 | clinic | 社区诊所 | `civic.hall` + the existing procedural cross | interim · P2 |
| 7 | park | 生态公园 | `civic.plaza` + `nature.tree_*` + `nature.shrub` | good |
| 8 | school | 中等学校 | `research.office` + `civic.plaza` | interim · P2 |
| 9 | culture_center | 文化中心 | `civic.full` | exact |
| 10 | hospital | 综合医院 | `command.office` + `infra.pad` (helipad) + cross | interim · P1 |
| 11 | civic_center | 市政中心 | `command.full` | exact |
| 12 | commerce | 商业街区 | `civic.market` | exact |
| 13 | service (private enterprise) | 远岸生活服务社 | `civic.kiosk` | good |
| 14 | power | 光伏储能站 | `power.solar_yard` | exact |
| 15 | wind_farm | 风电场 | **procedural** (new simple turbines: 3 masts with rotors) | P1 |
| 16 | geothermal | 地热电站 | `power.plant` + `industry.stack` | interim · P2 wellheads |
| 17 | fission | 裂变电站 | `power.plant` + `water.clarifier` (as cooling pond) | interim · P1 |
| 18 | fusion | 聚变电站 | `power.plant` + `research.observatory` dome | interim · P1 |
| 19 | water | 净水泵站 | `water.full` | exact |
| 20 | deep_well | 深层水井 | `water.wellhouse` | good |
| 21 | desalination | 海水淡化厂 | `water.full` + `industry.tanks` | interim · P2 intake |
| 22 | atmospheric_water | 大气集水站 | `water.vessels` + `power.cooling` | interim · P2 |
| 23 | port | 轨道货运站 | `logistics.full` + `infra.pad` | good |
| 24 | depot | 区域物流中心 | `logistics.yard` | good |
| 25 | scrubber | 污染净化塔 | 2 × `industry.stack` + `industry.filters` | interim · P2 |
| 26–28 | mine_ore / mine_copper / mine_crystal | 轻型矿场 | `mining.full`, ore pile tinted per good | exact |
| 29–31 | mine_*_heavy | 重型矿场 | `mining.pit` + a stepped pit ring drawn in code | interim · P1 open pit |
| 32–34 | mine_*_auto | 自动钻场 | `mining.shaft` + `power.batteries` | interim · P2 drill rigs |
| 35 | tailings_plant | 尾矿回收站 | `mining.ore_bay` (grey) + `industry.tanks` | good |
| 36 | sea_copper | 海水提铜站 | `water.clarifier` + `industry.tanks` | interim · P2 platform |
| 37 | crystal_vat | 晶体培育槽 | `greenhouse.one_bay` (beds tinted crystal) + `water.vessels` | good |
| 38 | farm | 温室农场 | `greenhouse.two_bays` | exact |
| 39 | field_station | 大田农业站 | `logistics.yard` (barn) + `water.vessels` (silos) + crop strips | interim · P1 |
| 40 | ranch | 牧场 | `housing.compact` (barn) + pasture strips | interim · P2 |
| 41 | hydroponic_farm | 水培温室 | `greenhouse.full` | exact |
| 42 | aquafarm | 近海养殖场 | 2 × `water.clarifier` (as pens) | interim · P2 |
| 43 | vertical_farm | 垂直农场 | **procedural** (the current stacked racks) | P1 tower |
| 44 | protein_plant | 合成蛋白厂 | `industry.hall` + `industry.tanks` + `water.vessels` | good |
| 45 | foodworks | 食品出口加工坊 | `industry.hall` + `logistics.containers` | good |
| 46 | processor | 复合加工厂 | `industry.full` | exact |
| 47 | smelter | 合金冶炼厂 | `industry.full` + `industry.stack`, warm glow when active | interim · P2 |
| 48 | component_plant | 电子元件厂 | `research.office` + `industry.filters` | good |
| 49 | machine_works | 精密机械厂 | `industry.hall` + `logistics.crane` | good |
| 50 | pharma_plant | 生物制药厂 | `research.office` + `industry.tanks` | good |
| 51 | data_center | 数据中心 | `power.plant` + `power.batteries` + `command.dish` | interim · P2 |
| 52 | lab | 教学研究所 | `research.lab` | exact |
| 53 | institute | 研究院 | `research.full` | exact |
| 54 | university | 行星大学 | `research.full` + `research.observatory` + `civic.plaza` | interim · P1 |
| 55 | lift_port | 轨道升降港 | **procedural** (the current tower) | **P0** |
| 56 | climate_regulator | 气候调节站 | 3 × `industry.stack` + `power.cooling` | interim · P1 |
| 57 | capital_hall | 行星议会大厦 | `command.full` + the `civic.market` canopy + plaza | interim · **P0** |
| — | A2.7 great works | | Kitbash from the above until modelled | P1 |
| — | main-street lamps, rocks, trees | | `infra.lamp`, `nature.rock_*`, B5 | |
| — | landing lander, landing capsules | | procedural, unchanged | P2 lander |

**Sub-assemblies.** Filters are case-insensitive substrings of node names such as
`CC_INDUSTRY_slab_foundation_0001`. Where names can't separate two parts of a master, use position boxes in
source metres, taken from the node bounds in `10_validation/<ID>.json`. Record every box in the recipe, and
check each split in the gallery capture (B7).

- **housing**
  - `full`: everything.
  - `two_storey` and `compact`: the two wings, separated by position box. The one-storey wing tops out
    below about 5 m.
- **power**
  - `solar_yard`: `solar_`, `photovoltaic`, `battery_`, `transformer_`, `energy_compound_pad`.
  - `plant`: the hall (slab, walls, `flat_roof`, `parapet`) plus `tank_`, `pressure_vessel`, `generator_`,
    `cooling_`.
  - `batteries`: `battery_`.
  - `cooling`: `cooling_loop_fin`, `generator_heat_exchanger`.
- **water**
  - `full`: everything.
  - `wellhouse`: the hall plus `tank_`, `pressure_vessel`, `pump_`, `filter_`, without the clarifier.
  - `clarifier`: `clarifier_`, `scraper`, `rotating_bridge`.
  - `vessels`: `tank_plinth`, `pressure_vessel`, `vessel_domed_cap`.
- **mining**
  - `full`: everything.
  - `pit`: `crusher_`, `hopper_`, `conveyor_`, `ore_bay_`, `ore_stockpile`.
  - `shaft`: `headframe_`, `sheave`, `shaft_` and the winding house.
  - `ore_bay`: `ore_bay_`, `ore_stockpile`.
- **greenhouse**
  - `full`: everything.
  - `two_bays` and `one_bay`: by bay box. The doors in the metadata are at x = −10, 0 and +10 m.
- **research**
  - `full`: everything.
  - `lab`: the office plus `parabolic_dish`, `reflector`, `receiver`, `instrument_mount`.
  - `office`: the office alone.
  - `observatory`: `observatory_`, `dome`, `telescope_`.
- **industry**
  - `full`: everything.
  - `hall`: the hall, canopy, apron and ramp. Nothing with `tank`, `vessel`, `separator`, `filter`, `stack`,
    `process_feed` or `pipe_rack`.
  - `tanks`: `tank_plinth`, `pressure_vessel`, `vessel_`, `separator_`, `process_feed`, `pipe_rack`.
  - `stack`: `stack`, `filter_bank`, `filter_drum`, `filter_top`.
  - `filters`: `filter_`.
- **logistics**
  - `full`: everything.
  - `yard`: the warehouse, `freight_apron` and `container_`.
  - `crane`: `crane_rail`, `gantry_`, `girder_`, `trolley`, `hoist_drum`, `spreader`, `operator_cabin`.
  - `containers`: `container_`.
- **civic**
  - `full`: everything.
  - `hall`: the hall and clerestory, without kiosks, plaza or canopy.
  - `market`: `butterfly_canopy`, `plaza_canopy_column`, `canopy_fork`, `kiosk`, `public_table`,
    `public_bench`, `public_plaza`.
  - `plaza`: `public_plaza`, `planter`, `tree`, `public_bench`, `public_table`.
  - `kiosk`: one kiosk plus a patch of plaza, by box.
- **command**
  - `full`: everything.
  - `office`: everything except `communications_pedestal`, `parabolic_dish`, `reflector`, `receiver`,
    `tower_`, `antenna`.
  - `dish`: those parts.
- **infra**
  - `pad`: `PAD`.
  - `lamp`: `LAMP_`.
- **nature**
  - `rock_00` to `rock_02`: `CC_ROCK_SOURCE_0x`.
  - `tree_00` to `tree_02`: `CC_TREE_SOURCE_0x_BRANCH_NETWORK` plus a crown proxy (B5).
  - `shrub`: `CC_SHRUB_SOURCE_`.

### B3 Converter

**Files:**

- `game/tests/art/convert_models.gd`: a SceneTree script. `tests/*` is already excluded from export.
- `game/tests/art/model_recipes.json`: parameters, drop list, slot rules and one entry per model id.
- `tools/convert_models.ps1`: finds the engine and the `art_reserve` root, runs the converter headless, and
  exits non-zero on any failure.

**Outputs:**

- `game/assets/models/<group>/<id>.res`: a compressed binary `ArrayMesh` with an LOD chain, and surfaces
  named after material slots.
- `game/data/v17/models.json`: the runtime registry. For each model:
  - `file`, `source` ID and source SHA-256;
  - triangles per LOD;
  - footprint and height in units;
  - surfaces, and the recipe hash.
- `evidence/v17/art/conversion_<timestamp>.json`: the report.
  - Inputs and outputs with hashes.
  - Parts kept, and parts dropped with the reason.
  - Unmatched part names.
  - Slot counts and timings.

**Steps.** Appendix B has the verified core.

1. **Load** with `FBXDocument`. Ignore the texture warnings. Sort parts by name so output is deterministic.
2. **Check orientation.** Parts arrive Y-up with the Max front (−Y) at +Z. For every model, check it: the
   `doors` in the metadata are (Max x, y, z), which is Godot (x, −y). The front door must come out on the +Z
   side of the centre.
3. **Filter** with the recipe's includes, excludes and boxes.
4. **Drop.** Remove parts matching the drop list, and parts whose longest side is under `min_part_m`
   (starting value 1.2 m).
5. **Classify** each part into a slot: first matching rule wins, and anything unmatched goes to `shell`.
6. **Transform.**
   - Centre on the XZ bounds.
   - The ground stays at source Z 0. Don't lift the model to its lowest point: shafts and footings go below
     grade.
   - Uniform fit: `fit_units` (4.0, or 5.0 for great works) ÷ the longer horizontal side. Then height
     × `vertical` (1.3).
   - For a kitbash, place the sub-assemblies at their `offset` (plot units) and `yaw`, then fit the assembled
     bounds.
7. **Merge** by slot, generate LODs, take the LOD nearest each surface's share of the target, drop unused
   vertices, generate LODs again, and save with `ResourceSaver.FLAG_COMPRESS`. Targets: 4,500 triangles, or
   9,000 for great works.
8. **Variants.**
   - `<id>.foundation`: only the concrete-slot parts whose top is under 2 m at source. Used for
     construction.
   - `<id>.depleted`: the mines without the ore slot.
9. **Determinism.** The same inputs and recipe produce byte-identical outputs. Run the converter twice in a
   test and compare hashes.

**Slots and colours.** All are drawn with the existing `_mat()` palette:

| Slot | Colour | Notes |
|---|---|---|
| `shell` | `bec9cb` | |
| `dark` | `354954` | |
| `metal` | `73818a` | |
| `gold` | `c7a36b` | |
| `roof` | `7f909b` | **new**, lighter than `dark`; this matters at the default zoom |
| `concrete` | `8d918c` | new |
| `glass` | `204e62` idle; `8fd8e8` with emission 0.6 when active | |
| `green` | `719650` | |
| `ore` | ore `ac7755` / copper `ba9c57` / crystal `7ba0bd` | |
| `water` | `2e6c7d` | new |

### B4 Runtime

- **Data.**
  - `economy.json`: every building gets `art`, either a model id or `"procedural"`.
  - `model` stays as the name of the procedural fallback.
  - The private service building gets its id in `models.json`.
- **`world/building_models.gd`.**
  - `art_mesh(id, state)` loads the registry entry once.
  - It assigns slot materials. Glass is lit when the building runs and dark when it is idle or disabled.
  - Keep the status beacon.
  - Keep the hex pad under every model. Make it 0.6 deep, top at +0.08, so slopes don't show a gap.
- **`world/region_view.gd` `_baked_model`.**
  - Use art first. Fall back to procedural, with one warning in the log per missing id.
  - Turn each building so its front faces the main street: yaw +90° for plots with x less than the street's
    x, −90° for plots with greater x.
  - Under construction: `<id>.foundation` plus `_construction_frame()`.
  - Depleted mines: `.depleted`.
  - Cache per id and state, as now.
- **LODs in the Compatibility renderer.** Check that mesh LODs actually switch. If they don't, pick the LOD
  in code from the camera distance, or use two instances with visibility ranges.
- The planet view and the flat map are unchanged.

### B5 Environment and infrastructure

- **Rocks.** `nature.rock_00..02` replace the procedural rock mesh in `_build_nature()`. Use a MultiMesh and
  keep the per-instance colour.
- **Trees.**
  - The converter keeps the branch network (about 500 triangles). It replaces the leaf crown with 3–5
    low-poly lobes fitted to the crown's bounds, for at most 400 triangles per tree.
  - Capture both versions next to the procedural cones at three zooms and keep whichever reads better.
    Write the decision in `DECISIONS.md`.
- **Park.** `civic.plaza` with library trees and the shrub.
- **Lamps.** `infra.lamp` replaces the cylinder-and-box lamps on the main street.
- **Landing pad.** `infra.pad` is part of the port and hospital recipes.
- **Roads.** Keep the ribbons, but use the kit's asphalt and shoulder colours.

### B6 Icons and images

- **Icons.**
  - `game/tests/art/bake_icons.gd` (needs a window) renders every kind with its model in a SubViewport:
    transparent background, the game's sun, three-quarter view.
  - Output: `game/assets/icons/buildings/<kind>.png` at 128 px.
  - `ui/design.gd` looks there before falling back to the SVG. The build list, the building column and the
    details all use it.
  - This closes 1.8 open issue #5 for icons.
- **Images.** Copy at most 10 renders from `09_previews/beauty`. Suggested:
  - `CC_SETTLEMENT_R00_HP_v004_initial_bird`, `CC_SETTLEMENT_R00_HP_v004_developed_bird`;
  - `CC_SETTLEMENT_R01_HP_v004_developed_game`, `CC_SETTLEMENT_R01_HP_v004_evening`;
  - `CC_PLANET_260129_HP_v002_front`;
  - `CC_INDUSTRY_HP_v005_hero`;
  - `CC_GREENHOUSE_HP_v003_interior`.

  Scale each down to 1600×900 JPG, at most 400 KB, into `game/assets/art/`. Use them behind the main menu
  and on the stage-complete and award screens. They show a different world: never caption one as the
  player's planet.

### B7 Budgets and checks

- **Suite `v19_art`** (headless). Checks:
  - every kind resolves to an art id or `"procedural"`;
  - every file loads;
  - LOD0 has at most 4,500 triangles (great works 9,000), at most 8 surfaces, and at least 3 LODs;
  - footprint is at most 4.2 units (great works 5.0); the base sits at 0 and the lowest point is ≥ −0.7;
  - surface names are known slots;
  - `assets/models` totals at most 12 MB;
  - two converter runs are byte-identical.
- **Captures** (window).
  - The region at zoom 31, 67 and 140, from a midgame fixture and a late fixture.
  - `game/tests/art/model_gallery.gd`: a labelled contact sheet of all 57 visuals, active and idle.
  - Save to `evidence/v17/art/`. Label them "screenshot viewed" only after you have viewed them.
- **Performance** (exported EXE, on the user's machine). The `perf_probe_v17` rows hold. New row: a late
  region with at least 60 buildings has no frame over 50 ms.
- **Size.** The PCK is at most 30 MB.
- **Source safety.** List the art_reserve files used, with their hashes, before and after the job. They must
  be identical.

---

## 4. The 1.9 bar

These rows are added to `V18_BRIEF.md`. Every 1.8 row stays: award bands, the floor, openings, failure,
population, labour, research, research-first, money (reinvest ≥ 60%, income ×2.5 from year 2 to year 6),
export mix, pollution, distrust, events, geography, roads, determinism, audits, saves, responsiveness, old
saves, tutorial.

| Area | Target (balanced bot, standard, harness medians unless stated) |
|---|---|
| Cash cover before the award | Per run, from day 720 to the award: p90 ≤ 120 days of operating expense and median ≤ 60 (1.8 balanced standard in §1.1: p90 52–392, median 11–108) |
| Cash cover after the award | On day 3,600, runs awarded by day 2,880: median ≤ 180 days, p90 ≤ 365 (seed 260129 had 588) |
| Takeovers | Balanced runs taken over, before or after the award, no more often than in 1.8 on any difficulty |
| Absorption | Spending ≥ 80% of operating surplus in each of years 3–7 |
| Paybacks | Every income building inside its band at the y2, y4 and y6 fixtures (`v19_payback`) |
| Windfall | +¥1,000,000 on day 1,080 moves the median award at most 10% earlier, and never before day 1,800 |
| Ways to spend | The balanced bot uses commissions, services and at least one late great work in at least 80% of runs |
| Art coverage | At least 52 of the 57 visuals use converted art; the rest are listed as procedural with a reason |
| Art budgets | §B7 suite green; PCK ≤ 30 MB |
| Art in the game | Region captures and the gallery viewed; fronts face the street; nothing floats on slopes; new frame row holds in the EXE |
| Source safety | art_reserve hashes identical before and after; no FBX, MAX or TIF under `game/` or in the PCK |
| Icons | Every kind has its own baked icon, viewed in the build list |

Report misses plainly. The human playtest stays NOT_RUN until the user reports one.

---

## 5. Part C — what is still missing

### C1 Priority list

With the interim kitbashes from B2, every kind in 1.9 is already visibly distinct. These models replace the
weakest stand-ins.

| Priority | Model | Why |
|---|---|---|
| **P0** | 行星议会大厦 capital hall | The charter's goal building; a monumental civic complex |
| **P0** | 轨道升降港 lift port | A space-elevator base with a tether going out of frame |
| **P0** | Harbour and quay for sea routes | Islands are ordinary starts in 1.8. The port at a coastal site should show a quay and a ship |
| P1 | 行星大学 university campus | Great work |
| P1 | 气候调节站 climate regulator | Atmospheric processor towers |
| P1 | 裂变电站 fission | Containment dome and cooling tower |
| P1 | 聚变电站 fusion | Torus hall |
| P1 | 风电场 wind turbines | Three per plot |
| P1 | Open-pit kit | Benched pit, excavator, haul truck |
| P1 | 生态穹顶城 arcology | Dome city |
| P1 | 垂直农场 vertical farm | Glass tower |
| P1 | 大田农业站 field station | Barn, silos, machinery shed |
| P1 | 综合医院 hospital | |
| P1 | Construction kit | Tower crane, scaffold, foundation stages |
| P1 | Models for the A2.7 great works that are kept | |
| P2 | Geothermal wellheads; desalination intake; atmospheric condensers; scrubber tower; data centre; school; clinic; smelter furnace hall; autonomous drill rigs; sea-copper platform; aquafarm pens; ranch; mid-rise apartment block; landing craft; power pylons | |
| P2 | Upgrade add-ons for levels 2–3 | Mines, habitat, lab, port, farm, processor |
| P3 | Vehicles and people | |

### C2 Brief for the 3ds Max task (the user pastes this to Codex)

> **Colony Charter — game-ready additions to the 3ds Max library.** Deliver into a new folder,
> `art_reserve/max_models_<date>/`, with the same layout as `max_highpoly_20261031`: MAX, FBX in
> `08_exports/highpoly_fbx`, per-asset metadata JSON in `10_validation/` with the same fields
> (`measured_size`, `bounds`, `axis`, `doors`, `geometry.nodes` with names and bounds), hero renders, and
> `DELIVERY_TARGET_IDS.json`. Don't touch the game folders or the existing library.
>
> **How the models are used.** The game shows each building as a diorama piece about 4 units wide, seen from
> 40–60° above. A converter in the game repository reads your FBX and node names, drops thin parts, decimates
> to about 4,500 triangles (great works 9,000) and recolours by part name. So:
>
> - **Silhouette first.** Big, readable volumes that still read at 60 px wide. Thin rails, ropes and lattices
>   vanish or flicker. Use them as accents, never as the main shape.
> - **Name every part** `CC_<KIT>_<part>_<nnnn>` with these words where they apply: `glass`/`glazing`,
>   `roof`, `wall`/`spandrel`/`facade`, `column`/`beam`/`rail`/`frame`, `vessel`/`tank`,
>   `slab`/`foundation`/`pad`/`plinth`, `_run`/`_elbow` for pipes, `guardrail`, `stair`, `crop`/`leaf`/`tree`,
>   `ore`/`boulder`, `water`. Status lights are `status_light`.
> - **Coordinates.** Metres, Z-up, front facing −Y. The pivot is the footprint centre at grade. Footprint at
>   most 45 × 45 m; great works at most 60 × 60 m. Keep a 1.80 m human figure in the renders, not in the
>   export.
> - **Style.** Match the existing kits: dark blue-grey steel, cool grey panels, ochre safety elements,
>   concrete pads. Textures are optional; the game recolours by slot.
> - **Construction state.** Also export `<ID>_CONSTRUCTION.fbx`: the foundation, part-built frame, scaffold
>   and a tower crane.
> - **Not tied to any world.** No terrain, no planet, nothing that depends on a seed. The game generates its
>   worlds.
>
> **Order.** Capital hall; lift port; harbour and quay with a cargo ship. Then university; climate regulator;
> fission; fusion; wind turbines; open-pit kit (benched pit, excavator, haul truck); arcology; vertical farm;
> field station; hospital; construction kit. Then the P2 list.

---

## 6. Order of work and report

1. **Phase 1 — measure and tune.**
   - Add the probes and the harness metrics (A2.9) first, and record the 1.8 baseline with them.
   - Then A2.1–A2.5.
   - Exit when: a quick harness run is recorded, the award bands hold, `v19_payback` is green, and cash cover
     and absorption are measured.
2. **Phase 2 — ways to spend money.**
   - A2.6, the bots (A2.8), the interface (A2.10) and saves (A2.11).
   - Exit when: a full harness run is recorded and the money rows pass, or each miss is explained.
3. **Phase 3 — models.**
   - The converter, recipes, runtime, environment, icons, images and checks (B3–B7).
   - This can run alongside Phases 1–2.
   - Exit when: the art rows pass and the captures have been viewed.
4. **Phase 4 — late great works.** A2.7 with interim kitbash models, then calibrate.
5. **Phase 5 — release.**
   - Final calibration and a full harness run.
   - EXE build and the performance rows.
   - Docs: `BALANCE.md`, `PROGRESS.md`, `DECISIONS.md`, `VALIDATION.md`, README, CHANGELOG.
   - Package 1.9.0 to `delivery\v17`.

**The final report contains:**

- what changed;
- the bar table, 1.8.0 → 1.9.0;
- misses, stated plainly;
- the size of the PCK and of `assets/models`;
- the list of models that are still interim.

---

## Appendix A — probes

`game/tests/balance/money_probe.gd`. It prints public money by ledger key for each period. Run it with
`--bot=balanced --seed=260129 --opening=capital --difficulty=normal --days=3240 --period=360`.

```gdscript
extends SceneTree
## Money audit: runs one bot and prints public money by ledger key per period.

const Sim = preload("res://simulation/sim.gd")
const BOTS: Dictionary = {
	"rush": preload("res://tests/balance/bots/rush_bot.gd"),
	"balanced": preload("res://tests/balance/bots/balanced_bot.gd"),
	"research_first": preload("res://tests/balance/bots/research_first_bot.gd"),
	"passive": preload("res://tests/balance/bots/passive_bot.gd"),
}

var options: Dictionary = {
	"bot": "balanced", "seed": "260129", "opening": "capital", "difficulty": "normal",
	"days": "3240", "period": "180",
}


func _initialize() -> void:
	call_deferred("run")


func _add(into: Dictionary, row: Dictionary) -> void:
	for key: String in row:
		into[key] = float(into.get(key, 0.0)) + float(row[key])


func _fmt(values: Dictionary, limit: int = 12) -> String:
	var keys: Array = values.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return values[a] > values[b])
	var total: float = 0.0
	for key: String in keys:
		total += float(values[key])
	var parts: PackedStringArray = []
	for i: int in range(mini(limit, keys.size())):
		parts.append("%s %.0f" % [keys[i], float(values[keys[i]])])
	return "total %.0f | %s" % [total, ", ".join(parts)]


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var sim: RefCounted = Sim.new()
	sim.new_game(int(options.seed), options.opening, 1, options.difficulty)
	var bot: RefCounted = BOTS[options.bot].new()
	bot.begin(sim, int(options.seed))
	var period: int = int(options.period)
	var acc: Dictionary = {"income": {}, "expense": {}, "invest": {}, "funding": {}}
	var exported: Dictionary = {}
	var cash_max: float = 0.0
	for _day: int in range(int(options.days)):
		bot.on_day()
		sim.tick()
		var row: Dictionary = sim.state.stats.days.back()
		for column: String in acc:
			_add(acc[column], row[column])
		var goods: Dictionary = sim.state.stats.goods_days.back()
		for good: String in goods:
			exported[good] = float(exported.get(good, 0.0)) + float(goods[good][2])
		cash_max = maxf(cash_max, float(sim.state.cash))
		if sim.state.status == "success" and int(sim.state.success_day) == int(sim.state.day):
			print("== AWARD on day %d" % int(sim.state.day))
		if int(sim.state.day) % period == 0:
			var population: int = 0
			var buildings: int = 0
			for s: Dictionary in sim.state.settlements:
				population += int(s.population)
				buildings += s.buildings.size()
			print(
				(
					"D%d stage %d cash %.0f (max %.0f) pop %d towns %d buildings %d techs %d"
					% [
						int(sim.state.day), int(sim.state.contract.stage), float(sim.state.cash),
						cash_max, population, sim.state.settlements.size(), buildings,
						sim.state.research.completed.size(),
					]
				)
			)
			for column: String in acc:
				print("  %-8s %s" % [column, _fmt(acc[column])])
			print("  exported t ", _fmt(exported))
			acc = {"income": {}, "expense": {}, "invest": {}, "funding": {}}
			exported = {}
		if sim.state.status == "failed":
			print("FAILED day %d: %s" % [int(sim.state.day), sim.state.failure_reason])
			break
	print("PROBE_DONE day=%d audit=%s" % [int(sim.state.day), str(sim.audit())])
	quit(0)
```

`game/tests/balance/payback_probe.gd`. It plays the balanced bot to the given days and prints the game's own
forecast for every income building: the best site per kind, ignoring refusals. Run it with
`--seed=260129 --opening=capital --at=720,1440,2160`.

```gdscript
extends SceneTree

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Market = preload("res://simulation/market.gd")
const ROLES: Array[String] = ["mine", "harvest", "factory", "income", "commerce", "foodworks"]

var options: Dictionary = {"seed": "260129", "opening": "capital", "at": "720,1440,2160"}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var checkpoints: Array[int] = []
	for text: String in str(options.at).split(","):
		checkpoints.append(int(text))
	var sim: RefCounted = Sim.new()
	sim.new_game(int(options.seed), options.opening, 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(options.seed))
	for _day: int in range(checkpoints.max()):
		bot.on_day()
		sim.tick()
		if checkpoints.has(int(sim.state.day)):
			_report(sim)
		if sim.state.status == "failed":
			break
	quit(0)


func _report(sim: RefCounted) -> void:
	print("== day %d, %d technologies" % [int(sim.state.day), sim.state.research.completed.size()])
	var prices: PackedStringArray = []
	for row: Dictionary in Market.view(sim):
		prices.append("%s %.1f (%.0f%%)" % [row.good, float(row.price), float(row.factor) * 100.0])
	print("  prices ", ", ".join(prices))
	for kind: String in sim.config.buildings:
		if not str(sim.config.buildings[kind].role) in ROLES:
			continue
		var best: Dictionary = {}
		for s: Dictionary in sim.state.settlements:
			var forecast: Dictionary = sim.build_forecast(int(s.region), kind)
			if not forecast.is_empty() and (
				best.is_empty() or float(forecast.net_per_day) > float(best.net_per_day)
			):
				best = forecast
		if best.is_empty():
			continue
		print(
			(
				"  %-20s cost %6.0f net %6.1f/day payback %5.0f d deposit %6.0f d"
				% [
					kind, float(best.cost), float(best.net_per_day), float(best.payback_days),
					float(best.reserve_days),
				]
			)
		)
```

---

## Appendix B — converter core (ran in Godot 4.5.1 on mining, industry and housing)

This is the core of `convert_models.gd`. Recipes, sub-assembly filters, kitbash, variants and the report go
around it.

The rules below are exactly what produced the screenshots, with arguments `1.2 4500 4.0 1.3`. The full slot
word lists were:

- **glass:** `glass`, `glazing`, `transparent`, `aperture`, `lantern`.
- **ore:** `ore_stockpile`, `boulder`.
- **water:** `clarifier_water`.
- **green:** `crop`, `leaf`, `shrub`, `tree_canopy`, `public_tree`, `planter_soil`, `soil`.
- **gold:** `guardrail`, `stair_stringer`, `ridge_cap`, `_run`, `_elbow`, `bollard`, `gantry`, `crane`,
  `canopy_front_column`, `canopy_knee`, `hoist`, `lifting_rope`, `spreader`, `trolley`.
- **concrete:** `foundation`, `slab`, `_pad`, `plinth`, `apron`, `landing`, `paving`, `plaza`, `curb`,
  `floor`, `retaining_wall`, `stair_tread`, `ramp`, `ore_bay`, `threshold`, `pavement`, `shoulder`.
- **roof:** `roof`.
- **dark:** `door_leaf`, `roller_door`, `seam`, `louver`, `vessel`, `battery`, `transformer`,
  `photovoltaic`, `panel`, `container`, `cabinet`, `dish`, `conveyor_belt`, `crusher_machine`, `hopper`,
  `generator`.
- **metal:** `column`, `rafter`, `mullion`, `beam`, `frame`, `post`, `leg`, `support`, `rail`, `tower`,
  `receiver`, `headframe`, `sheave`, `trestle`, `girder`, `bogie`, `axle`, `mast`, `stack`, `pipe`, `fan`,
  `flange`, `lamp`, `drum`, `roller`, `spoke`, `rope`, `cross`, `transom`, `crown`, `brace`, `pier`,
  `telescope`, `track`.

```gdscript
## Drop list: thin or tiny parts that only sparkle at diorama scale.
const DROP_PATTERNS: Array[String] = [
	"guardrail", "stair", "handrail", "rope", "louver", "fan_", "landing_column", "cable",
	"conduit", "mullion", "door_pull", "busbar", "seam_band", "insulator_disc", "bench_leg",
	"bench_support", "door_lock", "corner_post", "corrugation", "drip_", "access_lid",
	"access_neck"
]


func convert_master(
	path: String, out: String, min_part: float, target: int, fit_units: float, lift: float
) -> void:
	var document := FBXDocument.new()
	var state := FBXState.new()
	if document.append_from_file(path, state) != OK:
		push_error("cannot read " + path)
		return
	var parts: Array = []
	_collect(document.generate_scene(state), Transform3D.IDENTITY, parts)
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	var whole: AABB = parts[0].aabb
	for part: Dictionary in parts:
		whole = whole.merge(part.aabb)
	# Already Y-up, Max front (-Y) at +Z. The ground stays at source Z 0.
	var center := Vector3(whole.get_center().x, 0.0, whole.get_center().z)
	var fit: float = fit_units / maxf(whole.size.x, whole.size.z)
	var scale := Vector3(fit, fit * lift, fit)
	var place := Transform3D(Basis.from_scale(scale), -center * scale)
	var groups: Dictionary = {}
	for part: Dictionary in parts:
		var name: String = str(part.name).to_lower()
		if _dropped(name, part.aabb, min_part):
			continue
		var slot: String = _slot(name)
		if not groups.has(slot):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[slot] = tool
		(groups[slot] as SurfaceTool).append_from(part.mesh, int(part.surface), place * part.xform)
	var slots: Array = groups.keys()
	slots.sort()
	var full := ImporterMesh.new()
	var kept: int = 0
	for slot: String in slots:
		var tool: SurfaceTool = groups[slot]
		tool.index()
		var arrays: Array = tool.commit_to_arrays()
		kept += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		full.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, slot)
	full.generate_lods(25.0, 60.0, [])
	var share: float = float(target) / maxf(1.0, float(kept))
	var reduced := ImporterMesh.new()
	for i: int in range(full.get_surface_count()):
		var arrays: Array = full.get_surface_arrays(i)
		var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var want: int = maxi(12, int(best.size() / 3 * share))
		for lod: int in range(full.get_surface_lod_count(i)):
			var candidate: PackedInt32Array = full.get_surface_lod_indices(i, lod)
			if absi(candidate.size() / 3 - want) < absi(best.size() / 3 - want):
				best = candidate
		reduced.add_surface(
			Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, best), [], {}, null, full.get_surface_name(i)
		)
	reduced.generate_lods(25.0, 60.0, [])
	ResourceSaver.save(reduced.get_mesh(), out, ResourceSaver.FLAG_COMPRESS)


func _collect(node: Node, parent: Transform3D, parts: Array) -> void:
	var here: Transform3D = parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in range(mesh.get_surface_count()):
			parts.append(
				{
					"name": str(node.name), "mesh": mesh, "surface": surface,
					"xform": here, "aabb": here * mesh.get_aabb()
				}
			)
	for child: Node in node.get_children():
		_collect(child, here, parts)


func _dropped(name: String, box: AABB, min_part: float) -> bool:
	for pattern: String in DROP_PATTERNS:
		if name.contains(pattern):
			return true
	return box.get_longest_axis_size() < min_part


## SLOT_RULES: [[slot, [words...]], ...] in the order listed above this block.
func _slot(name: String) -> String:
	for rule: Array in SLOT_RULES:
		for word: String in rule[1]:
			if name.contains(word):
				return str(rule[0])
	return "shell"


## Keeps only the vertices the chosen index list uses (positions and normals; the palette needs no UVs).
func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var remap: Dictionary = {}
	var order: PackedInt32Array = []
	var new_indices: PackedInt32Array = []
	for index: int in indices:
		if not remap.has(index):
			remap[index] = order.size()
			order.append(index)
		new_indices.append(int(remap[index]))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var kept_vertices := PackedVector3Array()
	var kept_normals := PackedVector3Array()
	for index: int in order:
		kept_vertices.append(vertices[index])
		kept_normals.append(normals[index])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = kept_vertices
	out[Mesh.ARRAY_NORMAL] = kept_normals
	out[Mesh.ARRAY_INDEX] = new_indices
	return out
```

Results with arguments `1.2 4500 4.0 1.3`:

| Master | Parts | Dropped | Fit | Triangles | Size (units) | File |
|---|---:|---|---:|---:|---|---:|
| Mining | 225 | 38 | 0.109 units/m | 3,874 | 3.99 × 3.18 × 3.56 | 61 KB |
| Industry | 284 | 137 | 0.098 units/m | 4,308 | 3.99 × 1.81 × 3.45 | 68 KB |
| Housing | 351 | 234 | 0.134 units/m | 4,264 | 4.00 × 1.63 × 3.24 | 53 KB |

The output surfaces are named after their slots: `concrete`, `dark`, `glass`, `gold`, `green`, `metal`,
`ore`, `roof`, `shell`.
