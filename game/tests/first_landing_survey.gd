extends SceneTree
## The first landing preview must match the site that the game actually builds.
const Sim = preload("res://simulation/sim.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Watchdog = preload("res://tests/support/watchdog.gd")
const SAVE := "user://first_landing_survey.save"
const GOODS := ["ore", "copper", "crystal"]

var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 120)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(3, "capital", 1, "normal")
	_check(_check_preplaced_site(sim), "pre-generated site checks completed")
	_check(_check_free_placement(sim), "free placement checks completed")
	print("FIRST_LANDING_SURVEY ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _check_preplaced_site(sim: RefCounted) -> bool:
	# Two mine plots on one vein share a reserve. Concealed, deep and dry
	# veins cannot support an opening mine. Older plots may have no vein ID.
	var site: Dictionary = sim.state.world.regions[0].duplicate(true)
	var shallow := {
		"kind": "deposit",
		"resource": "ore",
		"reserves": 120.0,
		"depth": 0,
		"hidden": false,
		"deposit": "shared"
	}
	site.plots = [
		{"kind": "general"},
		{"kind": "farm", "fertility": 0.67},
		shallow,
		shallow.duplicate(),
		shallow.merged({"hidden": true, "deposit": "hidden"}, true),
		shallow.merged({"depth": 1, "deposit": "deep"}, true),
		shallow.merged({"reserves": 0.0, "deposit": "spent"}, true),
		{"kind": "deposit", "resource": "copper", "reserves": 17.0, "hidden": false, "depth": 0},
	]
	SiteGen.refresh_deposits(site)
	var report: Dictionary = sim.Sites.landing_survey(sim, site)
	_check(not report.is_empty(), "pre-generated sites have opening survey data")
	if report.is_empty():
		return false
	_check(is_equal_approx(float(report.fertility), float(site.fertility)), "local soil fertility")
	_check(report.plots.general == 1 and report.plots.farm == 1, "construction and farmland counts")
	_check(report.plots.ore == 2 and report.plots.copper == 1, "usable mine plots")
	_check(
		report.deposits.ore == 120.0 and report.deposits.copper == 17.0,
		"accessible reserves counted once"
	)
	_check(
		report.deposits.has("crystal") and report.deposits.crystal == 0.0,
		"absent crystal is explicit"
	)
	site.plots = [{"kind": "general"}]
	SiteGen.refresh_deposits(site)
	report = sim.Sites.landing_survey(sim, site)
	for good: String in GOODS:
		_check(report.deposits.get(good, -1.0) == 0.0, "mineral-free site reports zero %s" % good)
	return true


func _check_water(sim: RefCounted) -> bool:
	var sea: Dictionary = {}
	var width: int = sim.geo.grid_width
	var height: int = sim.geo.grid_height
	for index: int in range(sim.geo.grid.size()):
		if not sim.geo.grid[index].land:
			var lat: float = 90.0 - (floori(float(index) / width) + 0.5) * 180.0 / height
			var lon: float = (index % width + 0.5) * 360.0 / width - 180.0
			sea = sim.Placement.view(sim, lat, lon)
			if not sea.land:
				break
	_check(not sea.is_empty() and not sea.land, "seed contains a sea selection")
	_check(sim.Placement.landing_survey(sim, sea).is_empty(), "ocean has no buildable district")
	var lake: Dictionary = {}
	for water: Dictionary in sim.geo.lakes:
		lake = sim.Placement.view(sim, water.lat, water.lon)
		if lake.land and lake.lake_here:
			break
	_check(
		not lake.is_empty() and lake.land and lake.lake_here,
		"seed contains an inland lake selection"
	)
	_check(
		sim.Placement.landing_survey(sim, lake).is_empty(), "lake surface has no buildable district"
	)
	return true


func _check_free_placement(sim: RefCounted) -> bool:
	var initial: Dictionary = sim.state.duplicate(true)
	var sites: Array[Dictionary] = []
	for region: Dictionary in sim.geo.regions:
		var point: Dictionary = sim.Placement.view(
			sim, float(region.lat) + 0.63, float(region.lon) - 0.47
		)
		if point.refusal != "":
			continue
		if (
			sites.is_empty()
			or not is_equal_approx(float(sites[0].fertility), float(point.fertility))
		):
			sites.append(point)
		if sites.size() == 2:
			break
	_check(sites.size() == 2, "seed has two legal free placements with different fertility")
	if sites.size() != 2:
		return false
	var first: Dictionary = sim.Placement.landing_survey(sim, sites[0])
	var other: Dictionary = sim.Placement.landing_survey(sim, sites[1])
	_check(
		not first.is_empty() and not other.is_empty(), "both points can be compared before founding"
	)
	if first.is_empty() or other.is_empty():
		return false
	_check(
		not is_equal_approx(float(first.fertility), float(other.fertility)),
		"moving updates soil data"
	)
	_check(
		sim.Placement.landing_survey(sim, sites[0]) == first,
		"returning to a point reproduces its survey"
	)
	_check(_check_water(sim), "map water checks completed")
	_check(sim.state == initial, "browsing preserves time, money, settlement and prospecting state")

	_check(sim.save_game(SAVE).is_empty(), "planning game saves")
	var loaded: RefCounted = Sim.new()
	_check(loaded.load_game(SAVE).is_empty(), "planning game reloads")
	var point: Dictionary = loaded.Placement.view(loaded, sites[0].lat, sites[0].lon)
	_check(
		loaded.Placement.landing_survey(loaded, point) == first,
		"unsettled save still offers first survey"
	)
	var result: String = loaded.act(
		"settle_at", {"lat": point.lat, "lon": point.lon, "name": "Survey"}
	)
	_check(result.is_empty(), "chosen coordinate can be founded: %s" % result)
	if not result.is_empty():
		return false
	var actual: Dictionary = loaded.state.world.regions[int(loaded.state.settlements[0].region)]
	_check(
		is_equal_approx(float(first.fertility), float(actual.fertility)),
		"soil matches founded site"
	)
	var plots := {"general": 0, "farm": 0, "ore": 0, "copper": 0, "crystal": 0}
	for plot: Dictionary in actual.plots:
		var key: String = plot.kind
		if key == "deposit":
			if plot.hidden or int(plot.depth) != 0 or float(plot.reserves) <= 0:
				continue
			key = plot.resource
		plots[key] = int(plots.get(key, 0)) + 1
	for kind: String in plots:
		_check(
			first.plots.get(kind, -1) == plots[kind], "founded site's %s plot count matches" % kind
		)
	for good: String in GOODS:
		_check(
			first.deposits[good] == actual.deposits[good],
			"founded site's %s reserve matches" % good
		)
	_check(
		loaded.Placement.landing_survey(loaded, point).is_empty(),
		"a stale pre-founding selection is hidden"
	)
	_check(
		loaded.Sites.landing_survey(loaded, loaded.state.world.regions[0]).is_empty(),
		"later preset sites are hidden"
	)
	_check(loaded.save_game(SAVE).is_empty(), "active game saves")
	_check(sim.load_game(SAVE).is_empty(), "active game reloads")
	point = sim.Placement.view(sim, sites[1].lat, sites[1].lon)
	_check(
		sim.Placement.landing_survey(sim, point).is_empty(),
		"later free placement stays hidden after load"
	)
	return true
