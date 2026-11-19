# Colony Charter 1.10: the bay first (plan, 2026-11-19)

The user's brief of 2026-11-19 asks for:
- a player who chooses where to settle;
- a player who finds out what lies under the ground;
- decisions that visibly change a place the player can recognise.

The reference is a three-panel night photo of one bay: a landing, the housing that follows, then a
working harbour. This plan turns the brief into phases. The check of the branch against the November 13
preview is in `docs/v17/REVIEW_20261119.md`.

The work is on branch `v17-bay`, from `v17-fix-tips` at `8c395db`.

## Rules that hold throughout

- **Baseline.** The 1.6.0 baseline stays: 1.6 worlds unchanged to the vertex, the `world_v16_*` suites, the `v1.6.0` tag.
- **Saves.** Saves keep loading:
  - 1.10 writes schema 6 to `%APPDATA%\ColonyCharter\v110`;
  - it reads schema 5 (1.9, `v19`), 1.8 and 1.7 saves read-only and upgrades them on load;
  - every new state field has a migration and a validator entry.
- **Determinism.** Same seed and action log give byte-identical state at any speed. `audit()` covers every new system.
- **Numbers** live in `game/data/v17/`. Interface text stays Chinese; identifiers and this plan are English.
- **Evidence.** Each phase ends with:
  - suites green, apart from the four Windows-recorded ones;
  - a harness run in `BALANCE.md`;
  - `PROGRESS.md` and `DECISIONS.md` updated.

  Staged fixtures (captures, probes) are always labelled apart from outcomes reached through normal play.

## Order

The brief says to build one playable bay first and judge the opening before scaling. So phases A–C
make the bay, and the reviews follow. D–G scale the design to the planet once the bay holds up.

### A. Verified feedback (small, independent; first)

1. **Stable building identity.** Every building gets a `uid`, migrated for old saves in list order. Event construction follows the uid. Tests: demolishing the target ends the story; demolishing an unrelated older building does not.
2. **Research status in three states.** A topic is assigned, blocked (with the reason) or progressing. The card, the column and the tutorial use the state; the tutorial waits for research that progresses.
3. **Commissioned research.**
   - The ETA counts the chosen level's extra points.
   - The card says when charging starts: from the next day while the team works, and paused while it is blocked or cash is short.
4. **The build ledger tells three numbers apart:**
   - nominal capacity;
   - output the town can use, after local demand and the stock target;
   - likely import savings.

   Farms and food first, then any good with a local demand.
5. **The tutorial.**
   - The menu shows the tutorial's real seed, size and difficulty.
   - In the water lesson, waiting out the fault is reported as waiting, with what it cost. An intervention completes the lesson.
6. **The clock** keeps its fraction of a day across pauses, panels and speed changes.
7. **Events pick the town after the event.**
   - A definition is drawn first, then a town among those that qualify, weighted by local conditions and away from towns with recent events.
   - The colony-wide rate stays the same as towns multiply.
   - Options that send a team say on which day it reports back.

### B. A nightscape made from the game (the reference image is the target)

1. **One light model** (`world/light_field.gd`), built from state. Settlement lights:
   - housing windows at the actual plots, warm, scaled by completion and occupancy;
   - work lamps at operating facilities, cooler;
   - quay lights at a working dock, cool and compact;
   - a few lights at route entrances and junctions.

   Moving lights: vehicles on roads in proportion to traffic, and a ship that sails to its real berth. Each light has a world position: the district's local units map to the planet at 4 per degree, which `region_ground` already uses.
2. **Globe and flat map draw those lights** as anchored points.
   - Each has a small bright core and a restrained halo, with varied intensity.
   - Nearby lights merge smoothly as the camera pulls back and separate as it comes close.
   - The sea stays darkest and the terrain barely legible.
   - Roads keep long dark stretches.
   - The complete transport diagram becomes a separate overlay the player switches on.
   - The procedural town shapes and the lamp strings along whole roads go.
3. **The district lights its windows and yards** from the same state:
   - completion, occupancy where the town has it, and operation;
   - a landing shows a work lamp and a few windows.
4. **The decisive test (automated).** Two colonies with the same population and building count, with the housing on opposite sides of the camp. The lit neighbourhood's centroid moves to the side where the housing stands, on the globe, the flat map and in the district.

### C. The playable bay (the opening)

1. **Mobile engineering crews (工程队) separate from the workforce.**
   - Residents work facilities as workers (工人) and farmers (农民).
   - Crews are few, dispatchable teams for construction, repairs, roads and field work; a project progresses only while a crew works on it.
   - Crews grow through training, equipment and logistics; the starting count and rate are for playtests.
   - A team recruited from outside adds one adult population unit when it arrives and takes a bed. Training or a change of job keeps the resident total.
   - The interface shows who is assigned, when they are free and what a reassignment would delay.
   - Old saves get one crew per project under way, so nothing in them stalls.
2. **The bay** is a coastal landing with:
   - a dependable iron deposit inland, worked through a short mine road the crew builds;
   - an uncertain mineral signal offshore.
3. **The first decision, for the one crew:**
   - **Mine road:** the inland mine ships ore and the first exports come early.
   - **Small harbour:** food arrives by sea, cheaper than orbital freight; later it bases an offshore survey.

   The harbour stays useful if the offshore deposit is poor: cheaper imports, then sea links. Both choices make economic sense and leave visibly different towns.
4. **The first shipment worth watching:** the first ore truck back at camp, or the first ship at the new pier after dark. A notice offers the view.
5. **Orbit.** Pulled back, the player sees the bay they built, and the offshore signal is a reason to come back.

### Reviews of the bay (deliverables)

- **Visual sheet, 3 × 3.**
  - Columns: landing, housing expansion, operating harbour. Rows: default globe distance, flat map near the city, district.
  - Within each row: the same place and camera, with local night time, weather and exposure set explicitly.
  - Captured at 1920 × 1080 before the sheet is assembled.
  - Two versions: the normal view with labels, and a clean one with labels and route overlays hidden.
  - A short ship-arrival or zoom clip shows that the lights stay anchored.
- **Gameplay review.**
  - What the player could decide in the opening and how the town changed.
  - How long stage three's population goal took, and which constraint held growth back.
  - At least two viable approaches with real trade-offs.
  - Staged fixtures marked apart from normal play.

### D. The planet (after the bay)

1. **Radius slider.** 0.70–1.30 Earth radii, 1.00 in the middle, shown in Earth radii and kilometres.
   - It is separate from surface gravity.
   - The same radius drives surface distances, travel times, route costs and survey coverage.
   - The setup screen shows an example journey.
2. **Geology per resource.** Each of iron, copper, industrial crystal and every later resource is its own persistent planetary field.
   - It forms veins, deposits, rich pockets and barren ground, and the layers overlap.
   - Terrain and geological features give clues.
   - Deposits are anchored to world coordinates with finite reserves. A vein under two towns is one reserve shared by their mines.
3. **Prospecting per resource:**
   - an orbital scan shows a broad anomaly;
   - a field survey shows which side of a ridge;
   - drilling shows grade and depth.

   Each answers a question that can change an investment.
4. **Free siting.**
   - Any surface coordinate can be inspected: terrain, slope, fresh water, harbour potential, approximate mineral signals, distance to infrastructure.
   - A settlement or facility goes wherever its physical needs are met.
   - Neighbouring sites trade off: a poor bay can be a good port, a rich mountain deposit is dear to supply, a fertile valley can feed several towns.
   - Suggested landing areas stay as shortcuts.
5. **Seabed path.** Offshore anomalies are marked early, investigated as survey technology improves, and developed through a port, offshore equipment and shipping.

   Later resources, nickel and cobalt among them, each bring a new decision: their uses, extraction or transport.

### E. Districts

- **Room to act.** The area a player can act on grows, so a riverbank, hillside or stretch of coast near town can be inspected for a road, farm, mine, harbour or expansion. Inland towns get inland ground.
- **Natural ground.** Slopes, ridges and shores stay natural until a project starts, which grades its own footprint. Today 98.9% of plot centres are already flatter than their surroundings.
- **Clues.** Veins, rock exposures and drainage replace the outer ring as the place to look. Today 82% of mineral plots sit on the outermost ring.
- **Close-range look.** Rock, gravel, dry soil, grass and wet banks differ in relief, roughness and transitions, not only colour. Facilities get working areas, entrances, loading points and road or water connections.

### F. People

- **Occupations.** Workers, farmers, mobile crews, researchers and dependants are kept apart in units and on screen.
- **Per-town readouts:**
  - net growth over 30 days;
  - free beds after reservations;
  - expected arrivals;
  - the main limit on growth;
  - migration demand against the arrivals the town can admit.

  Unemployment above 35% stops arrivals; the town says so and names the remedy.
- **Arrivals you can see.** An immigrant ship docks, and dark windows light up.
- **Stage three.** It is about a working network of settlements. Compare:
  - a logistics or regional achievement that advances the contract, with 600 people earning a bonus;
  - faster growth under today's target.

  Pick numbers from the harness and playtests.

### G. Stories and contracts

- Frontier towns, ports, farms and mining districts get stories of their own, and the colony keeps a sensible event rate as it grows.
- Follow-ups are easier to find, and a practical choice can still lead to a later local consequence.
- The middle contracts get identities, each with its own development history:
  - a dependable food corridor;
  - a remote mine in production;
  - a coastal trade network.

## What is measured

- **Openings.** Choice, cash, food, the day of first export or first ship. Mine road against harbour on several seeds: both viable and different.
- **Stage three.** How long it takes, and which limit held growth: beds, jobs, food, transport, crews.
- **Lights.** Centroid shift for the housing test, cluster separation at each zoom, anchoring in motion (positions in planet space unchanged over frames).
- **Events.** Share of the earliest town chosen, follow-up nodes reached, colony rate with 1–7 towns.
