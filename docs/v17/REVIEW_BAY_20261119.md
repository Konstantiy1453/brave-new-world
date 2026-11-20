# The bay: gameplay and visual review (1.10 phase C, 2026-11-19)

The brief asked for one playable bay before the planet-wide systems: the first settlement, an inland
resource, an offshore clue, one scarce crew and the first completed shipment. This review says what a
player can now decide there, what the numbers show, and what still needs a player's judgement.

Evidence labels as in `CLAUDE.md`. Everything ran in the Linux cloud container (Godot 4.5.1, software
OpenGL under Xvfb). **Human playtest: NOT_RUN.** Windows EXE, real-GPU frame times and the window-only
suites: NOT_RUN in this round (the Windows sheet `2026-11-08-v19-windows-verification-instructions.md`
covers them).

## What a player can do in the bay now

- **One crew.** The landing brings one engineering crew (工程队), made from its own workers, so the town
  keeps its people. Every building waits for a crew. The crew's standing instruction:
  1. a project that fixes today's water, power or food shortage, even off a project under way, which
     keeps its progress;
  2. then the order marked 先建 (build next);
  3. then the oldest order.

  The town's sidebar shows, for every project, which crew builds it or when one is expected to start
  and finish (「等工程队 · 约 X 开工，Y 完工」). The construction page shows:
  - each crew, what it builds and for how long;
  - the queue in the order crews will take it;
  - training a worker (¥900, 15 days, the town keeps its people);
  - recruiting from outside (¥1,500, 30 days, one more resident and a bed);
  - sending a crew over a finished link, with what that stops.

  *Automated test (`v110_crews`, 52 checks: the dates match the real start and finish), screenshot
  viewed.*
- **The first decision: what the crew builds first.**
  - **The mine road.** The inland iron deposit with its road: on the five bay starts below the road
    adds 5–7 days and ¥680–980 to a 23–25-day mine. A later mine builds only the spur from the nearest
    mine (DECISIONS).
  - **The small harbour (小型码头).** ¥3,000 and 20 days. It catches 6 food a day, counted as the
    town's own food. Food, materials and parts come in 25% cheaper by sea, and it adds port capacity.
    Its order now shows what it saves as its income: before, it read 不产生净收入.

  *Automated test (`v110_bay`, 41 checks).*
- **The first shipment worth watching.** A card the first time ore leaves camp and the first time a
  ship reaches the new harbour (「◆ 第一次」); a click opens the district.
- **The offshore clue.** Every coastal town has a signal from the seed: copper or crystal, rich (60%,
  about 4,000) or poor (300). A survey boat from a working harbour (¥1,500, 25 days) says which. Until
  then it is a gold ring on the globe and the flat map and a lit buoy in the district. Developing a
  rich one waits for seabed work (plan D).
- **The bay at night.**
  - The homes' windows light up as people move in.
  - The quay has cool lamps where the night map has its work lights.
  - The cargo ship carries a masthead lamp, and a ship light sails in to the berth on the globe and
    the flat map on the district ship's own line.
  - While the crew builds the harbour, the district shows its building site.

  *Automated test (`v110_lights`, 30 checks, including the ship on its line in every frame and the
  signal drawn where the district floats its buoy).*

## The opening decision, measured

Bot play, not a person. On each of five seeds the balanced bot lands on the same coastal start twice.
Its first order goes either to the mine road (then copper) or to the harbour (then both mines), and the
bot plays the rest for six years (`game/tests/balance/bay_openings.gd`, run `spur-acef816`).

| Seed | Opening | First export | First ship | Imports, year 1 | Cash, day 180 | Stage 2 met | Stage 3 met | 200→600 people | Crews at the end |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 260129 | mine road | 25 | — | ¥11,743 | ¥10,108 | 178 | 1018 | 490 days | 24 |
| 260129 | harbour | 38 | 20 | ¥6,309 | ¥10,390 | 180 | 993 | 544 days | 20 |
| 20261029 | mine road | 25 | — | ¥17,788 | ¥10,729 | 172 | 1224 | 614 days | 19 |
| 20261029 | harbour | 39 | 20 | ¥8,785 | ¥5,563 | 179 | 1105 | 541 days | 17 |
| 42 | mine road | 24 | — | ¥16,790 | ¥11,193 | 170 | 1330 | 839 days | 12 |
| 42 | harbour | 38 | 20 | ¥8,028 | ¥348 | 169 | 1302 | 685 days | 14 |
| 1024873270 | mine road | 23 | — | ¥5,558 | ¥2,811 | 172 | 1254 | 845 days | 15 |
| 1024873270 | harbour | 37 | 20 | ¥2,042 | ¥7,223 | 164 | 1163 | 573 days | 13 |
| 909386518 | mine road | 26 | — | ¥264 | ¥694 | 216 | 1118 | 544 days | 21 |
| 909386518 | harbour | 40 | 20 | ¥0 | ¥2,182 | 256 | 1469 | 595 days | 24 |

- **Both openings are viable.** All ten colonies met stage three, and none failed in six years.
- **They differ the way the brief wants.**
  - The mine road exports two weeks sooner (day 23–26 against 37–40).
  - The harbour lands its first ship on day 20 and halves the first year's imports (¥0–8,800 against
    ¥260–17,800).
  - Harbour first met stage three sooner on four seeds, by 25–120 days.
- **The exception is a start with its own farmland (909386518).** Its food was never imported, so the
  harbour saves little, and harbour first met stage three 351 days later.
- **The first run of this comparison** (`bay-c39e828`, before mine roads carried later mines) lost
  that colony to a company takeover on day 1,304. That was the reason the harbour's order now shows
  its savings.
- **The towns look different.**
  - The harbour town has a lit quay, a masthead lamp and the ship's light at sea.
  - The mine-road town has its mine and the first ore card.

## Stage three: how long, and what held growth

- **How long.** From 200 to 600 people (stage three's goal) took 490–845 days (median 573), and stage
  three was met on days 993–1,469.
- **What held growth: jobs.** The people page's own limit (`people_lines.gd`) at the capital said
  "jobs" on 90–100% of those days. Unemployment above the threshold stops immigration. This is the
  1.9 finding again (a full capital with too few jobs), not crews and not beds.
- **Crews were not the limit.** Orders waited for a crew on 34–58% of days, but the bot trained crews
  freely (12–24 by year six). Crews were scarce only in the first months.

## Two viable approaches, with real trade-offs

1. **Exports first: mine road, then copper.**
   - Ore income from about day 24, and the most cash in the first months on four of five seeds.
   - Food stays imported at full price, which on a farmless start costs ¥11,000–18,000 in the first
     year.
   - Best on a start with its own farmland, or when cash is short.
2. **Food and the sea first: harbour, then the mines.**
   - A ship and cheap food from day 20, and the offshore survey open early.
   - Exports two weeks later and the ¥3,000 outlay.
   - Paid back by stage three on four of five seeds, and leaves the signal ready for seabed work later.

A third axis runs through both: train crews early or wait. Two crews from day 15 shorten every queue;
training too many draws wages and takes workers off jobs.

## The visual sheet

`docs/v17/bay/sheet_labels.jpg` (with labels and markers) and `docs/v17/bay/sheet_clean.jpg` (labels,
markers and route overlays hidden).
- **Layout.** Stages across: landing, housing built, harbour working. Views down: the globe at its
  default distance, the flat map at its closest, the district.
- **Settings.** Captured at 1920 × 1080, local midnight at the town, clouds off, the same camera within
  each row. The district camera looks over the town to its quay.
- **Files.** The native captures are WebP files in `docs/v17/bay/labels/` and `docs/v17/bay/clean/`. The
  clips are delivered with the build, not kept in git:
  - `labels_ship.mp4`: the ship sails in to the berth in the district;
  - `labels_zoom.mp4`: the globe zooms in on the town, with the lights staying where they are.

*Screenshot viewed.*

What it shows:
- the lit neighbourhood moving to where the homes were built;
- the quay's cool lamps;
- the ship;
- the gold signal ring out at sea.

What it does not yet show: a bay recognizable from orbit at the default distance. The town's lights
are anchored and correct, but its plots span about 60 pixels there. The halos are now round and soft
(DECISIONS), yet the bay reads as a few warm and cool glows rather than the reference image's lit
coastline. This needs a judgement on a real GPU (see below).

## Staged and played

- **Played.** The openings table is the balanced bot's play from one scripted first order. The landing
  column of the sheet is a real landing after two days. The UI screenshots come from scripted orders.
- **Staged fixtures.** The sheet's housing and harbour columns are written into a copy of the state:
  three homes finished and full, then the harbour finished and working. They were not reached through
  play.

## Balance

Quick harness, recorded in `docs/v17/BALANCE.md` ("1.10 crews and the bay"):
- **`crews-234a06c`, crews and full roads for every mine.** It lost a fifth of the population (296 /
  783 at years 2 and 4, against 374 / 1014) and 6 of 27 well-played runs. A probe found the cause:
  every mine paid its whole road again.
- **`spur-acef816`, roads that carry the next mine.** Measured after it (see BALANCE.md).

## Needs player feedback

1. **How scarce crews should be.** At ¥900 and 15 days the bot ends with 12–24 crews, so scarcity lasts
   only the opening. A training slot per town, a higher price or equipment (parts) per crew would keep
   the choice of where a crew goes alive longer. The brief leaves the count and rate to playtests.
2. **Whether the harbour should be worth more on a farmland start**, where it saves little.
3. **How bright the bay should be from orbit and on the flat map**, on a real GPU.
4. **Jobs as the limit to growth.** It held growth on 90–100% of the days from 200 to 600 people in
   every game. Stage three's rebalance (600) and the logistics achievement are plan F.
5. **The mine road's price:** 0.25 days and ¥40 a unit beyond 18 units, and a spur after the first.
6. **The tutorial.** It now teaches the crew: one crew, shortages first, 先建, training at the second
   town. It finishes in 272 game days in the suite.

## Not in this round

- **Plan D:** the radius slider, per-resource geology, prospecting, free siting, the seabed path, nickel
  and cobalt.
- **Plan E:** districts.
- **Plan F:** the rest of people, including the immigrant ship and stage three.
- **Plan G:** stories and contracts.

These follow the plan's order: after the bay is judged.
