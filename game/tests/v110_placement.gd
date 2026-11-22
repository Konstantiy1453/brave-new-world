extends SceneTree
## 1.10 free placement (placement.gd, site_gen `site_at`/`ground`, geology.gd), the simulation side.
## Seed 3 (29 generated sites, the audited regression): a capital founded at an unmarked coordinate is
## a new site at exactly that point, not Site 01; two games with the same seed found at two different
## points of one old site's area and keep them through a save. Unsuitable ground is refused with its
## reason and creates nothing. A later town is founded by an expedition to a coordinate, inland and on
## the coast, with its departure town, route, cost and days known first; it arrives, is named, builds,
## and keeps its place, its route's endpoint and the capital's identity through a save. One planetary
## deposit reached by two towns has one reserve.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const WorldGen = preload("res://world/world_gen.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Geology = preload("res://world/geo2/geology.gd")
const SEED: int = 3
const SAVE_PATH: String = "user://v110_placement.save"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_regression_and_two_capitals()
	_refusals()
	_expeditions()
	_shared_deposit()
	print(
		"V110_PLACEMENT_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)]
	)
	quit(0 if failures.is_empty() else 1)


func _game(seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1, "normal")
	return sim


func _degrees(a_lat: float, a_lon: float, b_lat: float, b_lon: float) -> float:
	return rad_to_deg(WorldGen.unit_point(a_lat, a_lon).angle_to(WorldGen.unit_point(b_lat, b_lon)))


## Eligible points around a generated site, in rings from 1.5 to 3.5 degrees out.
func _eligible_near(sim: RefCounted, centre: Dictionary, wanted: int) -> Array:
	var found: Array = []
	for ring: float in [1.5, 2.5, 3.5]:
		for step: int in range(12):
			var angle: float = TAU * float(step) / 12.0
			var lat: float = float(centre.lat) + sin(angle) * ring
			var lon: float = float(centre.lon) + cos(angle) * ring
			var view: Dictionary = sim.Placement.view(sim, lat, lon)
			if str(view.refusal) != "":
				continue
			var apart: bool = true
			for other: Array in found:
				apart = apart and _degrees(lat, lon, other[0], other[1]) > 1.0
			if apart:
				found.append([float(view.lat), float(view.lon)])
			if found.size() >= wanted:
				return found
	return found


func _regression_and_two_capitals() -> void:
	var first: RefCounted = _game()
	check(first.state.world.candidates.size() == 29, "seed 3 has 29 generated sites, as audited")
	var points: Array = []
	var centre: Dictionary = {}
	for reg: Dictionary in first.state.world.regions:
		points = _eligible_near(first, reg, 2)
		if points.size() == 2:
			centre = reg
			break
	check(points.size() == 2, "two eligible points in one generated site's area")
	if points.size() < 2:
		return
	var stored: Array = []
	for at: int in range(2):
		var sim: RefCounted = first if at == 0 else _game()
		var point: Array = points[at]
		var sites: int = sim.state.world.regions.size()
		var view: Dictionary = sim.Placement.view(sim, point[0], point[1])
		check(
			str(view.terrain) != "" and view.has("slope_word") and view.has("signals"),
			(
				"the ground report says terrain, slope and signals: %s, %s"
				% [view.terrain, view.slope_word]
			)
		)
		check(
			sim.act("settle_at", {"lat": point[0], "lon": point[1], "name": "首都%d" % at}) == "",
			"a capital is founded at %.4f, %.4f" % point
		)
		var capital: Dictionary = sim.state.settlements[0]
		var site: Dictionary = sim.state.world.regions[int(capital.region)]
		check(int(capital.region) == sites, "on a site of its own, not a generated one")
		check(sim.settlement(0).is_empty(), "Site 01 is not founded (the audited regression)")
		check(
			(
				is_equal_approx(float(site.lat), float(point[0]))
				and is_equal_approx(float(site.lon), float(point[1]))
			),
			"stored at the chosen point: %.4f, %.4f" % [float(site.lat), float(site.lon)]
		)
		check(
			_degrees(float(site.lat), float(site.lon), float(centre.lat), float(centre.lon)) > 1.0,
			"not snapped to the generated site's centre"
		)
		check(bool(site.placed) and site.plots.size() >= 10, "with a district of its own")
		check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))
		check(sim.save_game(SAVE_PATH) == "", "the game saves")
		var copy: RefCounted = Sim.new()
		check(copy.load_game(SAVE_PATH) == "", "and loads")
		var kept: Dictionary = copy.state.world.regions[int(copy.state.settlements[0].region)]
		check(
			(
				is_equal_approx(float(kept.lat), float(point[0]))
				and is_equal_approx(float(kept.lon), float(point[1]))
				and str(copy.state.settlements[0].name) == "首都%d" % at
			),
			"keeping the capital's place and name"
		)
		stored.append([float(kept.lat), float(kept.lon)])
	check(
		_degrees(stored[0][0], stored[0][1], stored[1][0], stored[1][1]) > 1.0,
		"the two games keep two different capitals in the same area"
	)


func _refusals() -> void:
	var sim: RefCounted = _game()
	var sea: Array = _find(sim, func(v: Dictionary) -> bool: return not bool(v.land))
	var polar: Array = _find(
		sim, func(v: Dictionary) -> bool: return bool(v.land) and absf(float(v.lat)) > 76.0
	)
	var steep: Array = _find(
		sim, func(v: Dictionary) -> bool: return str(v.refusal).begins_with("地势太陡")
	)
	for case: Array in [[sea, "海面"], [polar, "极地"], [steep, "地势太陡"]]:
		var point: Array = case[0]
		check(not point.is_empty(), "found ground for the %s case" % case[1])
		if point.is_empty():
			continue
		var regions: int = sim.state.world.regions.size()
		var refusal: String = sim.act("settle_at", {"lat": point[0], "lon": point[1]})
		check(refusal.contains(case[1]), "refused with the reason: " + refusal)
		check(
			sim.state.settlements.is_empty() and sim.state.world.regions.size() == regions,
			"and nothing is founded anywhere"
		)


## The first grid cell centre whose ground report meets `test`.
func _find(sim: RefCounted, test: Callable) -> Array:
	var width: int = int(sim.geo.grid_width)
	for index: int in range(sim.geo.grid.size()):
		var lat: float = 90.0 - (float(index / width) + 0.5) * 2.5
		var lon: float = (float(index % width) + 0.5) * 2.5 - 180.0
		var view: Dictionary = sim.Placement.view(sim, lat, lon)
		if test.call(view):
			return [lat, lon]
	return []


## A town at a capital founded at a free point, then expeditions to an inland and a coastal point.
func _expeditions() -> void:
	var sim: RefCounted = _game()
	var capital_point: Array = []
	for reg: Dictionary in sim.state.world.regions:
		var near: Array = _eligible_near(sim, reg, 1)
		if not near.is_empty():
			capital_point = near[0]
			break
	sim.act("settle_at", {"lat": capital_point[0], "lon": capital_point[1], "name": "原首都"})
	var capital: Dictionary = sim.state.settlements[0]
	var capital_region: int = int(capital.region)
	sim.state.events_v2.next_draw = 99999
	sim.Crews.unlimited(sim)
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(capital, good, 400.0, "TEST stock")
	sim.state.contract.licences.append("expedition")
	sim.state.contract.licences.append("network")
	var inland: Array = _destination(sim, capital_point, false)
	var coastal: Array = _destination(sim, capital_point, true)
	if not inland.is_empty():
		var licences: Array = sim.state.contract.licences.duplicate()
		sim.state.contract.licences.clear()
		var before: Dictionary = sim.Placement.view(sim, inland[0], inland[1])
		check(
			str(before.refusal).contains("远征许可"),
			"before the expansion licence a second town is refused: " + str(before.refusal)
		)
		sim.state.contract.licences = licences
	check(not inland.is_empty(), "an inland point an expedition can reach")
	check(not coastal.is_empty(), "and a coastal one")
	for target: Array in [inland, coastal]:
		if target.is_empty():
			continue
		var view: Dictionary = sim.Placement.view(sim, target[0], target[1], capital_region)
		check(
			(
				int(view.from) == capital_region
				and bool(view.route.reachable)
				and int(view.route.days) > 0
				and float(view.cost) > 0.0
			),
			(
				"the expedition from %s: %s route, %d days, ¥ %.0f"
				% [view.get("from_name", ""), view.route.variant, int(view.route.days), view.cost]
			)
		)
		var end: Array = view.route.coordinates.back()
		check(
			(
				is_equal_approx(float(end[0]), float(view.lat))
				and is_equal_approx(float(end[1]), float(view.lon))
			),
			"its route ends at the chosen point"
		)
		var name: String = "内陆镇" if target == inland else "海湾镇"
		check(
			(
				sim.act(
					"settle_at",
					{"lat": target[0], "lon": target[1], "from": capital_region, "name": name}
				)
				== ""
			),
			"the expedition is dispatched to %.4f, %.4f" % target
		)
		var town: Dictionary = sim.state.settlements.back()
		var site: Dictionary = sim.state.world.regions[int(town.region)]
		check(
			(
				is_equal_approx(float(site.lat), float(view.lat))
				and is_equal_approx(float(site.lon), float(view.lon))
				and bool(site.coast) == (target == coastal)
			),
			"%s stands at the chosen point (coast %s)" % [name, str(site.coast)]
		)
		for _day: int in range(int(town.arrival) + 2):
			sim.tick()
		check(int(town.arrival) <= 0 and str(town.name) == name, "it arrives under its name")
		sim._produce(town, "materials", 200.0, "TEST stock")
		sim._produce(town, "parts", 60.0, "TEST stock")
		check(
			sim.act("build", {"site": int(town.region), "kind": "habitat"}) == "",
			"and builds there"
		)
		var link: String = ""
		for variant: String in ["valley", "engineered", "sea"]:
			link = sim.act(
				"connect", {"a": capital_region, "b": int(town.region), "variant": variant}
			)
			if link == "":
				break
		var road: Dictionary = sim.state.roads.back() if not sim.state.roads.is_empty() else {}
		check(
			(
				link == ""
				and not road.is_empty()
				and is_equal_approx(float(road.coordinates.back()[0]), float(site.lat))
				and is_equal_approx(float(road.coordinates.back()[1]), float(site.lon))
			),
			"a link to it ends at the town itself: " + link
		)
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))
	check(sim.save_game(SAVE_PATH) == "", "the colony saves")
	var copy: RefCounted = Sim.new()
	check(copy.load_game(SAVE_PATH) == "", "and loads")
	check(
		(
			int(copy.state.settlements[0].region) == capital_region
			and str(copy.state.settlements[0].name) == "原首都"
		),
		"with the original capital where it was"
	)
	for town: Dictionary in copy.state.settlements.slice(1):
		var site: Dictionary = copy.state.world.regions[int(town.region)]
		var built: bool = false
		for b: Dictionary in town.buildings:
			built = built or str(b.kind) == "habitat"
		check(
			bool(site.placed) and built,
			"%s keeps its place (%.4f, %.4f) and its building" % [town.name, site.lat, site.lon]
		)


## A point 9-16 degrees from the capital an expedition can reach, inland or on the coast.
func _destination(sim: RefCounted, from: Array, coastal: bool) -> Array:
	for ring: float in [9.0, 11.0, 13.0, 16.0]:
		for step: int in range(24):
			var angle: float = TAU * float(step) / 24.0
			var lat: float = float(from[0]) + sin(angle) * ring
			var lon: float = float(from[1]) + cos(angle) * ring
			var view: Dictionary = sim.Placement.view(sim, lat, lon)
			if str(view.refusal) != "" or bool(view.coast) != coastal:
				continue
			return [float(view.lat), float(view.lon)]
	return []


## Two towns whose districts reach one vein: mining at one leaves the other with what is left.
func _shared_deposit() -> void:
	for seed_value: int in [SEED, 20261029, 42]:
		var sim: RefCounted = _game(seed_value)
		var pair: Array = _vein_pair(sim)
		if pair.is_empty():
			continue
		sim.Crews.unlimited(sim)
		sim.state.events_v2.next_draw = 99999
		sim.act("settle_at", {"lat": pair[0][0], "lon": pair[0][1]})
		var capital: Dictionary = sim.state.settlements[0]
		sim._transfer("external", "public", 200000.0, "TEST funds", false)
		for good: String in ["materials", "parts", "food"]:
			sim._produce(capital, good, 400.0, "TEST stock")
		sim.state.contract.licences.append("expedition")
		var second: String = sim.act(
			"settle_at", {"lat": pair[1][0], "lon": pair[1][1], "from": int(capital.region)}
		)
		if second != "":
			continue
		var town: Dictionary = sim.state.settlements.back()
		var id: String = str(pair[2])
		var mine_plot: int = _plot_on(sim, int(capital.region), id)
		var far_plot: int = _plot_on(sim, int(town.region), id)
		var mine_kind: String = (
			"mine_" + str(sim.state.world.regions[int(capital.region)].plots[mine_plot].resource)
		)
		check(
			(
				sim.act(
					"build", {"site": int(capital.region), "kind": mine_kind, "plot": mine_plot}
				)
				== ""
			),
			"seed %d: a mine on the vein %s at the capital" % [seed_value, id]
		)
		var far: Dictionary = sim.state.world.regions[int(town.region)].plots[far_plot]
		var start: float = float(far.reserves)
		for _day: int in range(60):
			sim.tick()
		var here: Dictionary = sim.state.world.regions[int(capital.region)].plots[mine_plot]
		check(
			(
				float(far.reserves) < start
				and is_equal_approx(float(far.reserves), float(here.reserves))
			),
			(
				"the other town's plot on the vein shows the same reserve left: %.1f of %.1f"
				% [float(far.reserves), start]
			)
		)
		check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))
		return
	check(false, "found two towns on one vein on any of the seeds")


func _plot_on(sim: RefCounted, region: int, id: String) -> int:
	var plots: Array = sim.state.world.regions[region].plots
	for at: int in range(plots.size()):
		if (
			str(plots[at].get("deposit", "")) == id
			and not bool(plots[at].hidden)
			and int(plots[at].depth) == 0
		):
			return at
	return -1


## Two eligible points at least the minimum separation apart whose districts both have a visible,
## shallow plot on the same vein, the second reachable from the first by road: [[lat, lon], [lat,
## lon], vein id], or [] when there is none.
func _vein_pair(sim: RefCounted) -> Array:
	var rules: Dictionary = sim.progression_geo()
	var separation: float = float(rules.placement.min_separation_degrees)
	for deposit: Dictionary in Geology.deposits(sim.geo):
		if str(deposit.kind) != "vein" or bool(deposit.hidden) or int(deposit.depth) > 0:
			continue
		var points: Array = deposit.points
		var first: Array = points[0]
		var last: Array = points.back()
		if _degrees(first[0], first[1], last[0], last[1]) < separation + 0.5:
			continue
		var ends: Array = []
		for end: Array in [first, last]:
			var view: Dictionary = sim.Placement.view(sim, end[0], end[1])
			if str(view.refusal) != "":
				break
			var site: Dictionary = SiteGen.site_at(
				sim.geo, rules, float(view.lat), float(view.lon), 0
			)
			var on: bool = false
			for plot: Dictionary in site.plots:
				on = (
					on
					or (str(plot.get("deposit", "")) == str(deposit.id) and not bool(plot.hidden))
				)
			if not on:
				break
			ends.append([float(view.lat), float(view.lon)])
		if ends.size() == 2:
			return [ends[0], ends[1], str(deposit.id)]
	return []
