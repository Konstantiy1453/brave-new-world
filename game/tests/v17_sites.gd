extends SceneTree
## The same seed makes the same world; sites, plots and what is known about them; real distances;
## settlement kinds; roads under construction; the road network; islands and sea routes; saves of
## generated worlds; a migrated 1.6 save that plays on.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const WorldGen = preload("res://world/world_gen.gd")
const WorldGen2 = preload("res://world/geo2/world_gen2.gd")
const Plates = preload("res://world/geo2/plates.gd")
const Routes = preload("res://world/routes.gd")
const Sites = preload("res://simulation/sites.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Contract = preload("res://simulation/contract.gd")
const Rules = preload("res://simulation/rules.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Keys = preload("res://simulation/keys.gd")
const BalancedBot = preload("res://tests/balance/bots/balanced_bot.gd")

const SEED: int = 260129
const OLD_SAVE: String = "res://data/acceptance_midgame.json"
const SAVE_PATH: String = "user://sites_test.save"
const EARTH_RADIUS_KM: float = 6371.0
const EARTH_SHARES: Array[float] = [0.6, 1.0, 1.3]
const ISLAND_SEEDS: int = 40

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func make(licence: bool = false) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital")
	sim.state.events_v2.next_draw = 99999
	check(sim.act("settle", {"site": 0}) == "", "landing on the first site")
	if licence:
		sim.state.contract.licences.append("expedition")
		sim.state.contract.licences.append("third_settlement")
	return sim


func fund(sim: RefCounted, amount: float) -> void:
	sim._transfer("external", "public", amount, "capital.initial", false)


func supply(sim: RefCounted, s: Dictionary, good: String, amount: float) -> void:
	sim._produce(s, good, amount, "test")


func grant(sim: RefCounted, tech: String) -> void:
	sim.state.research.completed.append(tech)
	for hand: Array in sim.state.research.offers.values():
		hand.erase(tech)


## Roads take months; most of these checks are about what happens once they stand.
func finish_roads(sim: RefCounted) -> void:
	for road: Dictionary in sim.state.roads:
		road.ready_day = int(sim.state.day) - 1
		road.blocked_until = int(sim.state.day) - 1


func wait_for_arrival(sim: RefCounted, region: int) -> void:
	while int(sim.settlement(region).arrival) > 0:
		sim.tick()


func run() -> void:
	_same_seed_same_world()
	_world_shape()
	_sample_matches_grid()
	_disk_cache()
	_plots()
	_knowledge()
	_deep_and_hidden()
	_settlement_cap()
	_real_distances()
	_settlement_kinds()
	_roads_take_time()
	_road_network()
	_supply_chain()
	_migration_of_workers()
	_islands()
	_routes_are_paths()
	_save_generated_world()
	_refuse_changed_world()
	_migrated_save_plays()
	print("V17_SITES_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _same_seed_same_world() -> void:
	var first: Dictionary = WorldGen2.generate(SEED, 1)
	var second: Dictionary = WorldGen2.generate(SEED, 1)
	check(
		WorldGen.geo_hash(first) == WorldGen.geo_hash(second),
		"the same seed makes the same terrain"
	)
	check(
		var_to_bytes(first.regions) == var_to_bytes(second.regions), "and the same sites and plots"
	)
	var other: Dictionary = WorldGen2.generate(SEED + 1, 1)
	check(WorldGen.geo_hash(first) != WorldGen.geo_hash(other), "another seed makes another world")


func _world_shape() -> void:
	var rules: Dictionary = Rules.read("geography")
	for size: int in [0, 1, 2]:
		var world: Dictionary = WorldGen2.generate(1000 + size, size)
		var low: int = int(rules.site_count[size][0])
		var high: int = int(rules.site_count[size][1])
		check(
			world.regions.size() >= low and world.regions.size() <= high,
			"size %d has %d sites" % [size, world.regions.size()]
		)
		var names: Dictionary = {}
		var totals_match: bool = true
		for site: Dictionary in world.regions:
			names[site.name] = true
			var known: Dictionary = {"ore": 0.0, "copper": 0.0, "crystal": 0.0}
			for plot: Dictionary in site.plots:
				if plot.kind == "deposit" and not plot.hidden and int(plot.depth) == 0:
					known[plot.resource] += float(plot.reserves)
			for good: String in known:
				totals_match = (
					totals_match and absf(known[good] - float(site.deposits[good])) < 0.01
				)
		check(names.size() == world.regions.size(), "site names are unique")
		check(totals_match, "each site's deposits are the sum of its known plots")
		check(int(world.generation.validation.pairs) >= 3, "at least three start pairs")
		var land: float = float(world.statistics.land_fraction)
		check(land >= 0.25 and land <= 0.45, "land fraction %.2f" % land)
	var world: Dictionary = WorldGen2.generate(SEED, 1)
	var roads: Dictionary = Rules.read("economy").roads
	var partner: Dictionary = Routes.find(world, 0, 1, "valley", roads)
	check(bool(partner.reachable), "the first start reaches its partner by valley road")
	check(float(world.regions[1].fertility) >= 0.6, "and its partner can farm")


## Terrain has to look the same in every view: the grid, the atlas and the region all sample it.
func _sample_matches_grid() -> void:
	var world: Dictionary = WorldGen.new().build(SEED, 1)
	var noise := FastNoiseLite.new()
	noise.seed = int(world.seed)
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	var same: bool = true
	for index: int in [100, 3333, 5000, 7777, 10000]:
		var ll: Vector2 = WorldGen.cell_coordinate(index)
		var sampled: Dictionary = WorldGen.sample_geo(ll.x, ll.y, noise, WorldGen.VERSION)
		var cell: Dictionary = world.grid[index]
		same = same and bool(sampled.land) == bool(cell.land)
		same = same and is_equal_approx(float(sampled.height), float(cell.height))
	check(same, "continuous sampling agrees with the world grid")


func _disk_cache() -> void:
	WorldGen.use_disk_cache = true
	var fresh_seed: int = SEED + 77
	var made: Dictionary = WorldGen.new().build(fresh_seed, 0)
	WorldGen._geo_cache.clear()
	var started: int = Time.get_ticks_usec()
	var loaded: Dictionary = WorldGen.new().build(fresh_seed, 0)
	var read_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	WorldGen.use_disk_cache = false
	check(str(made.hash) == str(loaded.hash), "a world read from disk has the same hash")
	check(
		var_to_bytes(made.regions) == var_to_bytes(loaded.regions), "and the same sites from disk"
	)
	check(Plates.is_active(fresh_seed), "the terrain sampler is ready after a disk read")
	print("GEO_CACHE_READ_MS %.1f" % read_ms)


func _plots() -> void:
	var sim: RefCounted = make()
	var s: Dictionary = sim.settlement(0)
	var reg: Dictionary = sim.state.world.regions[0]
	fund(sim, 50000.0)
	var counts: Dictionary = sim.Sites.free_counts(sim, 0)
	check(int(counts.general) > 0, "the site has free building ground")
	var built: int = 0
	var refusal: String = ""
	while refusal == "" and built < 80:
		supply(sim, s, "materials", 20.0)
		supply(sim, s, "parts", 5.0)
		refusal = sim.act("build", {"site": 0, "kind": "mine_ore"})
		if refusal == "":
			built += 1
	check(built == int(counts.ore), "one mine per ore plot: %d" % built)
	check(refusal.contains("矿床"), "no ore plot left: " + refusal)
	var used: Dictionary = {}
	var distinct: bool = true
	for b: Dictionary in s.buildings:
		distinct = distinct and not used.has(int(b.plot))
		used[int(b.plot)] = true
	check(distinct, "no two buildings share a plot")
	check(sim.audit().is_empty(), "plots pass the audit")
	var general: int = -1
	var farmland: int = -1
	for index: int in range(reg.plots.size()):
		if used.has(index):
			continue
		if reg.plots[index].kind == "general":
			general = index
		elif reg.plots[index].kind == "farm":
			farmland = index
	supply(sim, s, "materials", 40.0)
	supply(sim, s, "parts", 10.0)
	if farmland >= 0:
		check(
			sim.act("build", {"site": 0, "kind": "habitat", "plot": farmland}) != "",
			"a habitat cannot go on farmland"
		)
		var farm_refusal: String = sim.act("build", {"site": 0, "kind": "farm", "plot": farmland})
		check(farm_refusal == "", "a farm can: " + farm_refusal)
		check(int(s.buildings.back().plot) == farmland, "and stands on the plot asked for")
	if general >= 0:
		check(
			sim.act("build", {"site": 0, "kind": "farm", "plot": general}) != "",
			"a farm cannot go on building ground"
		)
		var forecast: Dictionary = sim.build_forecast(0, "habitat", general)
		check(int(forecast.plot) == general, "the forecast uses the plot asked for")


func _knowledge() -> void:
	var sim: RefCounted = make()
	var far: int = 2
	var reg: Dictionary = sim.state.world.regions[far]
	var view: Dictionary = sim.site_view(far)
	check(float(view.band) == 0.4, "from orbit the band is 40%")
	var holds: bool = true
	for good: String in view.deposits:
		var row: Dictionary = view.deposits[good]
		holds = holds and float(row.low) <= float(reg.deposits[good]) + 0.01
		holds = holds and float(row.high) >= float(reg.deposits[good]) - 0.01
	check(holds, "the band always holds the true tonnage")
	check(sim.act("survey", {"site": far}) == "", "a ground survey can be sent")
	check(sim.act("survey", {"site": far}) != "", "only one team at a time")
	check(int(sim.site_view(far).surveying) > 0, "the team shows as under way")
	for _day: int in range(int(sim.progression_geo().survey.days)):
		sim.tick()
	view = sim.site_view(far)
	check(float(view.band) == 0.12, "after the survey the band is 12%")
	fund(sim, 10000.0)
	var levels: Array = sim.Sites.survey_levels(sim)
	var last_band: float = float(view.band)
	var last_days: int = int(sim.progression_geo().survey.days)
	for level: int in range(2, levels.size() + 1):
		var next: Dictionary = sim.Sites.next_survey(sim, far)
		check(int(next.level) == level, "survey %d is offered" % level)
		check(
			float(next.band) < last_band and int(next.days) > last_days,
			"it narrows further and takes longer (%.2f, %d days)" % [float(next.band), next.days]
		)
		var cash: float = float(sim.state.cash)
		check(sim.act("survey", {"site": far}) == "", "a further survey can be sent")
		check(
			is_equal_approx(float(sim.state.cash), cash - float(next.cost)),
			"it costs what the button says"
		)
		for _day: int in range(int(next.days)):
			sim.tick()
		view = sim.site_view(far)
		check(float(view.band) == float(next.band), "and leaves the band it promised")
		holds = true
		for good: String in view.deposits:
			var row: Dictionary = view.deposits[good]
			holds = holds and float(row.low) <= float(reg.deposits[good]) + 0.01
			holds = holds and float(row.high) >= float(reg.deposits[good]) - 0.01
		check(holds, "the narrower band still holds the true tonnage")
		last_band = float(next.band)
		last_days = int(next.days)
	check(not bool(sim.Sites.next_survey(sim, far).narrows), "surveys stop at the last level")
	check(sim.act("survey", {"site": far}) != "", "a site surveyed to the last level needs no team")
	grant(sim, "survey")
	check(float(sim.site_view(far).band) == 0.0, "with survey technology the figures are exact")
	check(sim.audit().is_empty(), "surveys pass the audit")


func _deep_and_hidden() -> void:
	var sim: RefCounted = make()
	var regions: Array = sim.state.world.regions
	var with_deep: int = -1
	var with_hidden: int = -1
	for reg: Dictionary in regions:
		for plot: Dictionary in reg.plots:
			if plot.kind == "deposit":
				if int(plot.depth) > 0 and with_deep < 0:
					with_deep = int(reg.id)
				if bool(plot.hidden) and with_hidden < 0:
					with_hidden = int(reg.id)
	check(with_deep >= 0, "some site has a deep deposit")
	check(with_hidden >= 0, "some site has a hidden deposit")
	var before: float = float(regions[with_hidden].deposits.ore)
	before += (
		float(regions[with_hidden].deposits.copper) + float(regions[with_hidden].deposits.crystal)
	)
	fund(sim, 2000.0)
	grant(sim, "prospecting")
	var cost: float = sim.Sites.survey_cost(sim)
	check(cost == float(sim.progression_geo().survey.cost) * 0.5, "prospecting halves survey cost")
	var quoted: Dictionary = sim.Sites.next_survey(sim, with_hidden)
	check(sim.act("survey", {"site": with_hidden}) == "", "prospecting survey is accepted")
	for _day: int in range(int(quoted.days)):
		sim.tick()
	var after: float = float(regions[with_hidden].deposits.ore)
	after += (
		float(regions[with_hidden].deposits.copper) + float(regions[with_hidden].deposits.crystal)
	)
	check(after > before, "prospecting reveals hidden deposits")
	var deep_before: float = float(regions[with_deep].deposits.ore)
	deep_before += (
		float(regions[with_deep].deposits.copper) + float(regions[with_deep].deposits.crystal)
	)
	sim.Sites.on_technology(sim, "deep_mining")
	var deep_after: float = float(regions[with_deep].deposits.ore)
	deep_after += (
		float(regions[with_deep].deposits.copper) + float(regions[with_deep].deposits.crystal)
	)
	check(deep_after > deep_before, "deep mining adds deep deposits to what is known")
	check(sim.audit().is_empty(), "revealed deposits pass the audit")


func _settlement_cap() -> void:
	var sim: RefCounted = make()
	check(Contract.settlement_cap(sim) == 1, "one settlement to begin with")
	sim.state.contract.licences.append("expedition")
	check(Contract.settlement_cap(sim) == 2, "the first licence allows a second")
	sim.state.contract.licences.append("third_settlement")
	check(Contract.settlement_cap(sim) == 3, "the second licence allows a third")
	sim.state.status = "success"
	check(
		Contract.settlement_cap(sim) == int(sim.contract_rules.settlement_cap.after_award),
		"the award lifts the limit"
	)


## Planets are 0.6, 1.0 and 1.3 Earth radii, and every distance is measured on that sphere.
func _real_distances() -> void:
	var roads: Dictionary = Rules.read("economy").roads
	var first_lengths: Array = []
	for size: int in [0, 1, 2]:
		var world: Dictionary = WorldGen2.generate(SEED, size)
		var radius: float = float(world.radius_km)
		check(
			is_equal_approx(snappedf(radius / EARTH_RADIUS_KM, 0.01), EARTH_SHARES[size]),
			"size %d is %.1f Earth radii" % [size, EARTH_SHARES[size]]
		)
		var found: Dictionary = Routes.find(world, 0, 1, "valley", roads)
		if not bool(found.reachable):
			continue
		var from: Dictionary = world.regions[0]
		var to: Dictionary = world.regions[1]
		var straight: float = (
			WorldGen.unit_point(float(from.lat), float(from.lon)).angle_to(
				WorldGen.unit_point(float(to.lat), float(to.lon))
			)
			* radius
		)
		check(
			float(found.distance) >= straight * 0.97, "a road is no shorter than the great circle"
		)
		var spec: Dictionary = roads.valley
		check(
			(
				int(found.days)
				>= maxi(
					int(spec.min_days), ceili(float(found.distance) / float(spec.speed_km_per_day))
				)
			),
			"travel time comes from the distance, and hills only add to it"
		)
		check(
			(
				int(found.build_days)
				== maxi(
					int(spec.build_days),
					ceili(float(found.distance) / float(spec.build_km_per_day))
				)
			),
			"building time comes from the distance"
		)
		first_lengths.append(float(found.distance))
	check(not first_lengths.is_empty(), "roads were measured on real planets")
	var flat: Dictionary = WorldGen2.generate(SEED, 1)
	var near: Dictionary = Routes.find(flat, 0, 1, "valley", roads)
	if bool(near.reachable):
		check(
			float(near.distance) > 500.0, "sites on a real planet are hundreds of kilometres apart"
		)


func _settlement_kinds() -> void:
	var sim: RefCounted = make(true)
	var capital: Dictionary = sim.settlement(0)
	check(str(capital.kind) == Keys.SITE_RESIDENTIAL, "the first town is where people live")
	fund(sim, 60000.0)
	supply(sim, capital, "materials", 300.0)
	supply(sim, capital, "parts", 60.0)
	supply(sim, capital, "food", 800.0)
	var town_fare: float = sim.Sites.expedition_cash(sim, Keys.SITE_RESIDENTIAL)
	var camp_fare: float = sim.Sites.expedition_cash(sim, Keys.SITE_FRONTIER)
	check(camp_fare < town_fare, "a frontier post costs less to found")
	check(
		(
			sim.Sites.expedition_workers(sim, Keys.SITE_FRONTIER)
			< sim.Sites.expedition_workers(sim, Keys.SITE_RESIDENTIAL)
		),
		"and takes fewer crews"
	)
	check(sim.act("settle", {"site": 1, "kind": "nonsense"}) != "", "only the two kinds exist")
	check(
		sim.act("settle", {"site": 1, "kind": Keys.SITE_FRONTIER}) == "", "a frontier post is sent"
	)
	wait_for_arrival(sim, 1)
	var camp: Dictionary = sim.settlement(1)
	check(str(camp.kind) == Keys.SITE_FRONTIER, "and stays one")
	var buildings: Dictionary = sim.config.buildings
	for kind: String in buildings:
		var wants: Array = buildings[kind].get("site_kinds", [])
		if wants.size() != 1:
			continue
		var place: Dictionary = camp if wants[0] == Keys.SITE_RESIDENTIAL else capital
		var reg: Dictionary = sim.state.world.regions[int(place.region)]
		var refused: String = sim.Production._place_refusal(place, reg, buildings[kind])
		check(refused != "", "%s belongs to the other kind of settlement" % kind)
	var lab_refused: String = sim.act("build", {"region": 1, "kind": "lab"})
	check(lab_refused != "", "no laboratory in a frontier post: " + lab_refused)
	check(
		sim.act("build", {"region": 1, "kind": "crew_quarters"}) == "", "a frontier camp is allowed"
	)
	check(sim.act("build", {"region": 0, "kind": "crew_quarters"}) != "", "but not in the town")
	check(sim.act("build", {"region": 1, "kind": "habitat"}) != "", "town housing stays in towns")
	camp.workers = int(camp.workers) + 40
	camp.population = int(camp.population) + 40
	camp.housing = int(camp.population) + 40
	var born: int = int(camp.children)
	for _day: int in range(90):
		sim.Population._births(sim, camp)
	check(int(camp.children) == born, "nobody settles down to raise a family in a frontier post")
	camp.employed = int(camp.workers)
	var appeal: float = sim.Population.attractiveness(sim, camp).value
	var at_camp: float = sim.Population.arrivals_per_month(sim, camp, appeal)
	camp.kind = Keys.SITE_RESIDENTIAL
	var as_town: float = sim.Population.arrivals_per_month(sim, camp, appeal)
	camp.kind = Keys.SITE_FRONTIER
	check(at_camp < as_town, "and few come of their own accord")
	var mine: Dictionary = sim.build_forecast(1, "mine_ore")
	if not mine.is_empty() and mine.outputs.has("ore"):
		var field: float = sim.Production._field_bonus(sim, camp)
		check(field > 1.0, "frontier mines and farms work a richer field")
	check(sim.audit().is_empty(), "settlement kinds pass the audit")
	var path: String = "user://kinds.save"
	check(sim.save_game(path) == "", "a frontier post is saved")
	var loaded: RefCounted = Sim.new()
	check(loaded.load_game(path) == "", "and loaded")
	check(str(loaded.settlement(1).kind) == Keys.SITE_FRONTIER, "with its kind")


func _roads_take_time() -> void:
	var sim: RefCounted = make(true)
	var s: Dictionary = sim.settlement(0)
	fund(sim, 60000.0)
	supply(sim, s, "materials", 300.0)
	supply(sim, s, "parts", 60.0)
	supply(sim, s, "food", 800.0)
	check(sim.act("settle", {"site": 1}) == "", "a second town")
	wait_for_arrival(sim, 1)
	var cash: float = float(sim.state.cash)
	check(sim.act("connect", {"a": 0, "b": 1, "variant": "valley"}) == "", "a road is ordered")
	check(float(sim.state.cash) < cash, "and paid for at once")
	var road: Dictionary = sim.state.roads[0]
	var months: int = int(road.build_days)
	check(months >= int(sim.config.roads.valley.build_days), "it takes its time")
	check(WorldGen.road_building(road, int(sim.state.day)), "it counts as being built")
	check(Logistics.largest_connected(sim) == 1, "and connects nothing yet")
	sim._consume(sim.settlement(1), "food", float(sim.settlement(1).stock.food))
	sim.tick()
	check(float(road.sent_today) == 0.0, "nothing travels on it")
	var started: int = int(sim.state.day)
	while WorldGen.road_building(road, int(sim.state.day)):
		sim.tick()
	check(int(sim.state.day) - started >= months - 2, "the road is finished when the date says so")
	check(Logistics.largest_connected(sim) == 2, "then it connects the towns")
	sim._consume(sim.settlement(1), "food", float(sim.settlement(1).stock.food))
	supply(sim, s, "food", 800.0)
	sim.tick()
	check(float(road.sent_today) > 0.0, "and carries goods")
	check(sim.audit().is_empty(), "road building passes the audit")


func _land_neighbors(sim: RefCounted, count: int) -> Array:
	return sim.state.world.regions[0].neighbors.slice(0, count)


func _road_network() -> void:
	var sim: RefCounted = make(true)
	var s: Dictionary = sim.settlement(0)
	fund(sim, 40000.0)
	supply(sim, s, "materials", 300.0)
	supply(sim, s, "parts", 60.0)
	supply(sim, s, "food", 800.0)
	var others: Array = _land_neighbors(sim, 2)
	check(others.size() == 2, "two more sites on the first landmass")
	check(sim.act("settle", {"site": 1}) == "", "the second settlement")
	var third: int = int(others[1]) if int(others[0]) == 1 else int(others[0])
	check(sim.act("settle", {"site": third}) == "", "the third settlement")
	wait_for_arrival(sim, 1)
	wait_for_arrival(sim, third)
	check(Logistics.largest_connected(sim) == 1, "nothing connected without roads")
	var first_road: String = sim.act("connect", {"a": 0, "b": 1, "variant": "valley"})
	check(first_road == "", "a road to the second settlement: " + first_road)
	check(sim.act("connect", {"a": 1, "b": 0}) != "", "only one road between two settlements")
	finish_roads(sim)
	check(Logistics.largest_connected(sim) == 2, "two connected")
	var second_road: String = sim.act("connect", {"a": 0, "b": third, "variant": "engineered"})
	check(second_road == "", "a road to the third: " + second_road)
	finish_roads(sim)
	check(Logistics.largest_connected(sim) == 3, "three connected")
	check(sim.state.roads.size() == 2, "the network has two roads")
	sim.state.roads[0].blocked_until = int(sim.state.day) + 20
	check(Logistics.largest_connected(sim) == 2, "a closed road splits the network")
	var other_road: Dictionary = sim.state.roads[1]
	sim.settlement(third).stock.food = 0.0
	sim.state.resource_sinks.food += 0.0
	sim.tick()
	check(float(other_road.sent_today) > 0.0, "a closure on one road leaves the other running")
	var waiting: bool = true
	for cargo: Dictionary in sim.state.shipments:
		if int(cargo.road) == 0:
			waiting = waiting and int(cargo.remaining) > 0
	check(waiting, "cargo on the closed road waits")
	grant(sim, "paved_roads")
	check(sim.act("upgrade_road", {"road": 1}) == "", "a chosen road can be paved")
	for _day: int in range(int(sim.config.road_levels.land[1].build_days) + 1):
		sim.tick()
	check(bool(sim.state.roads[1].get("paved", false)), "and only that one")
	check(not bool(sim.state.roads[0].get("paved", false)), "the other is untouched")


## Supplies have to reach the far end of a chain of roads through towns without ports.
func _supply_chain() -> void:
	var sim: RefCounted = make(true)
	sim.state.status = "success"
	var s: Dictionary = sim.settlement(0)
	fund(sim, 60000.0)
	supply(sim, s, "materials", 400.0)
	supply(sim, s, "parts", 80.0)
	supply(sim, s, "food", 3000.0)
	var others: Array = _land_neighbors(sim, 2)
	var near: int = int(others[0])
	var far: int = int(others[1])
	check(sim.act("settle", {"site": near}) == "", "a town along the way")
	wait_for_arrival(sim, near)
	sim.act("connect", {"a": 0, "b": near, "variant": "engineered"})
	finish_roads(sim)
	for _day: int in range(12):
		sim.tick()
	check(
		sim.act("settle", {"site": far, "from": near}) != "", "the small town cannot send a party"
	)
	check(sim.act("settle", {"site": far, "from": 0}) == "", "the capital can")
	wait_for_arrival(sim, far)
	sim.act("connect", {"a": near, "b": far, "variant": "engineered"})
	finish_roads(sim)
	var town: Dictionary = sim.settlement(far)
	town.stock.food = 0.0
	sim.state.resource_sinks.food += 0.0
	var fed: bool = false
	for _day: int in range(40):
		sim.tick()
		fed = fed or float(town.stock.food) > 0.0
	check(fed, "food reaches the far end of the chain")
	var bounced: bool = false
	var by_road: Dictionary = {}
	for cargo: Dictionary in sim.state.shipments:
		if cargo.resource != "food":
			continue
		var key: String = "%d|%d" % [int(cargo.road), int(cargo.to)]
		by_road[key] = true
		var back: String = "%d|%d" % [int(cargo.road), int(cargo.from)]
		bounced = bounced or by_road.has(back)
	check(not bounced, "no road carries food both ways at once")


func _migration_of_workers() -> void:
	var sim: RefCounted = make(true)
	var s: Dictionary = sim.settlement(0)
	fund(sim, 40000.0)
	supply(sim, s, "materials", 200.0)
	supply(sim, s, "parts", 60.0)
	supply(sim, s, "food", 500.0)
	check(sim.act("settle", {"site": 1}) == "", "a second town for the migrants")
	wait_for_arrival(sim, 1)
	var crew: int = int(sim.settlement(1).workers)
	sim.act("connect", {"a": 0, "b": 1, "variant": "engineered"})
	finish_roads(sim)
	for _day: int in range(5):
		sim.tick()
	check(int(sim.settlement(1).workers) >= crew, "an outpost keeps its crew while it has no work")
	var mover: RefCounted = sim
	var town: Dictionary = mover.settlement(1)
	town.jobs = int(town.employed) + 5
	town.housing = int(town.population) + 20
	s.workers = int(s.workers) + 30
	s.population = int(s.population) + 30
	var before: int = int(town.workers)
	sim.Population._migrate(sim)
	check(int(town.workers) > before, "jobless workers move to open jobs along the road")
	check(sim.audit().is_empty(), "moving people keeps the books right")


## Two coastal sites the sea joins and the land does not, on the first seed that has them.
func _island_case() -> Dictionary:
	for seed_value: int in range(1, ISLAND_SEEDS + 1):
		var sim: RefCounted = Sim.new()
		sim.new_game(seed_value, "capital")
		for home: Dictionary in sim.state.world.regions:
			if not bool(home.coast):
				continue
			for other: Dictionary in sim.state.world.regions:
				if int(other.id) <= int(home.id) or not bool(other.coast):
					continue
				var a: int = int(home.id)
				var b: int = int(other.id)
				if bool(Logistics.route_between(sim, a, b, "valley").reachable):
					continue
				if bool(Logistics.route_between(sim, a, b, "engineered").reachable):
					continue
				if bool(Logistics.route_between(sim, a, b, "sea").reachable):
					return {"seed": seed_value, "a": a, "b": b}
	return {}


## An island is a fair place to start or to settle: what the land cannot reach, the sea can.
func _islands() -> void:
	var case: Dictionary = _island_case()
	check(not case.is_empty(), "some coast can only be reached by sea")
	if case.is_empty():
		return
	var sim: RefCounted = Sim.new()
	sim.new_game(int(case.seed), "capital")
	sim.state.events_v2.next_draw = 99999
	var home: int = int(case.a)
	var island: int = int(case.b)
	check(sim.settle_refusal(island) == "", "landing on an island is no restricted start")
	check(sim.act("settle", {"site": home}) == "", "the first landing")
	sim.state.contract.licences.append("expedition")
	sim.state.contract.licences.append("third_settlement")
	fund(sim, 60000.0)
	var s: Dictionary = sim.settlement(home)
	supply(sim, s, "materials", 400.0)
	supply(sim, s, "parts", 80.0)
	supply(sim, s, "food", 800.0)
	check(not sim._has("shipping"), "no shipping technology yet")
	var accepted: String = sim.act("settle", {"site": island})
	check(accepted == "", "a party can sail with no technology: " + accepted)
	wait_for_arrival(sim, island)
	var ported: bool = false
	for b: Dictionary in sim.settlement(island).buildings:
		ported = ported or b.kind == "port"
	check(ported, "a landing by sea brings its own freight station")
	var quote: Dictionary = sim.road_quote(home, island, "sea")
	check(str(quote.get("refusal", "")) == "", "two coastal towns can open a pair of cargo docks")
	var sailing: String = sim.act("connect", {"a": home, "b": island, "variant": "sea"})
	check(sailing == "", "a sea link between two coastal towns: " + sailing)
	var lane: Dictionary = sim.state.roads[0]
	check(str(lane.variant) == "sea", "it is a sea route")
	check(int(lane.build_days) > 0, "a shipping lane takes time to open as well")
	check(sim.act("upgrade_road", {"road": 0}) != "", "its docks are not enlarged before it opens")
	finish_roads(sim)
	check(Logistics.largest_connected(sim) == 2, "sea routes connect settlements")
	sim._consume(sim.settlement(island), "food", float(sim.settlement(island).stock.food))
	sim.tick()
	check(
		float(lane.sent_today) > 0.0 or sim.settlement(island).stock.food > 0.0,
		"goods cross the water"
	)
	check(sim.audit().is_empty(), "sea routes pass the audit")


func _routes_are_paths() -> void:
	var world: Dictionary = WorldGen.new().build(SEED, 1)
	var roads: Dictionary = Rules.read("economy").roads
	var there: Dictionary = Routes.find(world, 0, 1, "engineered", roads)
	var back: Dictionary = Routes.find(world, 1, 0, "engineered", roads)
	check(bool(there.reachable), "a route exists")
	check(int(there.path[0]) == int(world.regions[0].grid_index), "it starts at the first site")
	check(int(there.path.back()) == int(world.regions[1].grid_index), "it ends at the second")
	check(
		int(back.path[0]) == int(world.regions[1].grid_index), "the way back starts at the second"
	)
	var on_land: bool = true
	for cell: Variant in there.path:
		on_land = on_land and bool(world.grid[int(cell)].land)
	check(on_land, "a road stays on land")
	var valley: Dictionary = Routes.find(world, 0, 1, "valley", roads)
	check(float(valley.cost) <= float(there.cost), "the valley road costs no more than engineered")
	check(int(valley.capacity) < int(there.capacity), "and carries less")


func _save_generated_world() -> void:
	var sim: RefCounted = make(true)
	var s: Dictionary = sim.settlement(0)
	fund(sim, 30000.0)
	supply(sim, s, "materials", 200.0)
	supply(sim, s, "parts", 40.0)
	supply(sim, s, "food", 500.0)
	sim.act("settle", {"site": 1})
	for _day: int in range(12):
		sim.tick()
	sim.act("connect", {"a": 0, "b": 1, "variant": "valley"})
	sim.act("build", {"site": 0, "kind": "mine_ore"})
	for _day: int in range(10):
		sim.tick()
	check(sim.save_game(SAVE_PATH) == "", "a generated world saves")
	var header: Dictionary = SaveIo.read_header(SAVE_PATH)
	check(int(header.get("version", 0)) == SaveIo.SCHEMA, "the header reads without the payload")
	var other: RefCounted = Sim.new()
	var error: String = other.load_game(SAVE_PATH)
	check(error == "", "and loads: " + error)
	check(
		var_to_bytes(other.state) == var_to_bytes(sim.state), "byte-identical state after loading"
	)
	check(str(other.geo.version) == WorldGen.VERSION, "the world is the generated one")
	for _day: int in range(20):
		sim.tick()
		other.tick()
	check(var_to_bytes(other.state) == var_to_bytes(sim.state), "and it plays on identically")
	var size: int = FileAccess.get_file_as_bytes(SAVE_PATH).size()
	check(size < 1500000, "save size %d bytes" % size)


func _refuse_changed_world() -> void:
	var sim: RefCounted = make()
	sim.state.world.hash = "0".repeat(64)
	check(sim.save_game(SAVE_PATH) == "", "a save with a wrong world hash can be written")
	var other: RefCounted = Sim.new()
	other.new_game(SEED + 5, "capital")
	var before: PackedByteArray = var_to_bytes(other.state)
	var error: String = other.load_game(SAVE_PATH)
	check(error != "", "loading it is refused: " + error)
	check(var_to_bytes(other.state) == before, "the game in memory is left alone")


func _migrated_save_plays() -> void:
	var sim: RefCounted = Sim.new()
	var error: String = sim.load_game(OLD_SAVE)
	check(error == "", "a 1.6 save loads: " + error)
	check(str(sim.geo.version) != WorldGen.VERSION, "and keeps its old world")
	var has_plots: bool = true
	for reg: Dictionary in sim.state.world.regions:
		has_plots = has_plots and not reg.plots.is_empty()
	check(has_plots, "its regions became sites with plots")
	var placed: bool = true
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			placed = placed and int(b.plot) >= 0
	check(placed, "every old building stands on a plot")
	check(sim.state.roads.size() <= 1, "the old route became a road")
	check(not sim.state.has("route"), "and the old field is gone")
	check(sim.audit().is_empty(), "the migrated state passes the audit")
	var bot: RefCounted = BalancedBot.new()
	bot.begin(sim, 1)
	var clean: bool = true
	var start_day: int = int(sim.state.day)
	for _day: int in range(120):
		bot.on_day()
		sim.tick()
		clean = clean and sim.audit().is_empty()
		if sim.state.status == "failed":
			break
	check(clean, "a bot plays it on with clean audits")
	check(int(sim.state.day) > start_day, "days pass")
	check(sim.save_game(SAVE_PATH) == "", "it saves in the new format")
	var again: RefCounted = Sim.new()
	check(again.load_game(SAVE_PATH) == "", "and loads again")
	check(var_to_bytes(again.state) == var_to_bytes(sim.state), "byte-identical")
