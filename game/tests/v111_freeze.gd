extends SceneTree
## 1.11 phase A: frozen features (progression.json `features`, simulation/features.gd).
## - every flag is false in 1.11.0;
## - frozen buildings cannot be ordered, frozen technologies are never dealt, put on the table by an
##   event or listed in the tree, the shuttle line cannot be built, a new game is on the default
##   radius, and no outside lab can be commissioned;
## - the planet still holds its nickel and cobalt deposits (the world is unchanged), but orbit does
##   not read them, a town takes no plots on them, prospecting refuses them and the offshore signal
##   is never cobalt;
## - a save that already holds frozen content keeps running it;
## - saves are schema 7 and a 1.10 save (schema 6) loads, with the log saying so.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Features = preload("res://simulation/features.gd")
const Sim = preload("res://simulation/sim.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Research = preload("res://simulation/research.gd")
const Bay = preload("res://simulation/bay.gd")
const Geology = preload("res://world/geo2/geology.gd")
const SEED: int = 20261029
const FLAGS: Array[String] = [
	"metals", "seabed", "shuttles", "radius_slider", "research_commissions"
]
const OLD_SAVE: String = "res://../docs/v17/placement/save_files/after-1.10.1.save"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_flags()
	_buildings_and_techs()
	_roads_radius_commissions()
	_metals_in_the_world()
	_old_save_keeps_running()
	_schema()
	print("V111_FREEZE_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(0), good, 900.0, "TEST stock")
	return sim


func _flags() -> void:
	var block: Dictionary = Rules.read("progression").get("features", {})
	var all_off: bool = true
	for flag: String in FLAGS:
		all_off = all_off and block.has(flag) and not bool(block[flag]) and not Features.on(flag)
	check(all_off, "every 1.11 feature flag is off: %s" % str(FLAGS))


func _buildings_and_techs() -> void:
	var sim: RefCounted = _colony()
	for kind: String in ["mine_nickel", "mine_cobalt", "superalloy_works", "seabed_mine"]:
		check(
			sim.Production.build_refusal(sim, 0, kind).contains("暂停开放"),
			"%s cannot be ordered" % kind
		)
	# With every other technology done, the frozen ones are still never eligible to be dealt.
	var frozen: Array[String] = ["nickel_metallurgy", "superalloys", "seabed_mining"]
	for key: String in sim.config.techs:
		if not key in frozen:
			sim.state.research.completed.append(key)
	var dealt: bool = false
	for category: String in Rules.read("techs").categories:
		for key: String in Research._eligible(sim.state.research, category, []):
			dealt = dealt or key in frozen
	check(not dealt, "no frozen technology can be dealt")
	var lead: bool = false
	for key: String in frozen:
		lead = lead or Research.add_lead(sim, key)
	check(not lead, "and no event puts one on the table")
	var listed: bool = false
	for row: Dictionary in Research.tree(sim):
		listed = listed or str(row.get("id", row.get("key", ""))) in frozen
	check(not listed, "and the tree does not list them")


func _roads_radius_commissions() -> void:
	var sim: RefCounted = _colony()
	check(
		str(sim.Logistics.quote(sim, 0, 1, "shuttle").refusal).contains("暂停开放"),
		"a shuttle line cannot be built"
	)
	var planet: RefCounted = Sim.new()
	planet.new_game(SEED, "capital", 1, "normal", 1.25)
	var default_km: float = (
		float(planet.progression_geo().planet_radius.default)
		* float(planet.progression_geo().planet_radius.earth_km)
	)
	check(
		is_equal_approx(float(planet.geo.radius_km), default_km),
		(
			"a new game is on the default radius whatever is asked: %.0f km"
			% float(planet.geo.radius_km)
		)
	)
	check(
		Research.commission(sim, "survey", 1).contains("暂停开放"), "no outside lab can be commissioned"
	)


## A capital founded right on a nickel vein, as v110_metals does with the flag on.
func _metals_in_the_world() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var counts: Dictionary = {}
	var vein: Dictionary = {}
	for deposit: Dictionary in Geology.deposits(sim.geo):
		counts[str(deposit.resource)] = int(counts.get(str(deposit.resource), 0)) + 1
		if str(deposit.resource) == "nickel" and not bool(deposit.hidden) and vein.is_empty():
			for point: Array in deposit.points:
				var lat: float = float(point[0])
				var lon: float = float(point[1])
				if vein.is_empty() and str(sim.Placement.view(sim, lat, lon).refusal) == "":
					vein = {"lat": lat, "lon": lon, "id": str(deposit.id)}
	check(
		int(counts.get("nickel", 0)) > 0 and int(counts.get("cobalt", 0)) > 0,
		"the world still holds nickel and cobalt deposits: %s" % str(counts)
	)
	if vein.is_empty():
		check(false, "a nickel vein a capital can be founded on")
		return
	var signals: Dictionary = Geology.orbital_signals(sim.geo, vein.lat, vein.lon, 4.0)
	check(
		float(signals.get("nickel", 0.0)) == 0.0 and float(signals.get("cobalt", 0.0)) == 0.0,
		"orbit reads no nickel or cobalt"
	)
	check(
		sim.act("settle_at", {"lat": vein.lat, "lon": vein.lon, "name": "镍城"}) == "",
		"a capital is founded on the vein"
	)
	var reg: Dictionary = sim.state.world.regions[int(sim.state.settlements[0].region)]
	var metal_plots: int = 0
	for plot: Dictionary in reg.plots:
		if str(plot.get("resource", "")) in ["nickel", "cobalt"]:
			metal_plots += 1
	check(metal_plots == 0, "and takes no plot on it (%d metal plots)" % metal_plots)
	check(
		sim.act("prospect_observe", {"resource": "nickel", "lat": vein.lat, "lon": vein.lon}) != "",
		"prospecting refuses nickel"
	)
	check(
		not "cobalt" in Bay._signal_goods(sim.config.get("bay", {})),
		"an offshore signal is never cobalt"
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


## A save that already runs a nickel mine keeps running it with the flag off.
func _old_save_keeps_running() -> void:
	Rules.read("progression").features.metals = true
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var spot: Dictionary = {}
	for deposit: Dictionary in Geology.deposits(sim.geo):
		if str(deposit.resource) != "nickel" or bool(deposit.hidden) or not spot.is_empty():
			continue
		for point: Array in deposit.points:
			var lat: float = float(point[0])
			var lon: float = float(point[1])
			if spot.is_empty() and str(sim.Placement.view(sim, lat, lon).refusal) == "":
				spot = {"lat": lat, "lon": lon}
	sim.act("settle_at", {"lat": spot.lat, "lon": spot.lon, "name": "镍城"})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	var s: Dictionary = sim.state.settlements[0]
	var reg: Dictionary = sim.state.world.regions[int(s.region)]
	var plot: int = -1
	for index: int in range(reg.plots.size()):
		if str(reg.plots[index].get("resource", "")) == "nickel" and plot < 0:
			plot = index
	sim.state.research.completed.append("nickel_metallurgy")
	sim.act("build", {"site": int(s.region), "kind": "mine_nickel", "plot": plot})
	s.buildings.back().remaining = 0
	sim.tick()
	var path: String = "user://v111_frozen_mine.save"
	check(sim.save_game(path) == "", "a game with a nickel mine saves (metals open)")
	Rules.read("progression").features.metals = false
	var again: RefCounted = Sim.new()
	check(again.load_game(path) == "", "and loads with metals frozen")
	var town: Dictionary = again.state.settlements[0]
	var before: float = float(town.stock.get("nickel", 0.0))
	var sold_before: float = float(again.state.market.saturation.get("nickel", 0.0))
	for _day: int in range(5):
		again.tick()
	var mined: bool = (
		float(town.stock.get("nickel", 0.0)) > before
		or float(again.state.market.saturation.get("nickel", 0.0)) > sold_before
	)
	check(mined, "the mine it already has keeps mining")
	check(
		again.Production.build_refusal(again, int(town.region), "mine_nickel", plot).contains(
			"暂停开放"
		),
		"but no new one can be ordered"
	)
	check(again.audit().is_empty(), "the audit holds: %s" % str(again.audit()))


func _schema() -> void:
	check(SaveIo.SCHEMA == 7 and SaveIo.OLD_SCHEMAS.get(6, "") == "1.10", "saves are schema 7")
	var path: String = ProjectSettings.globalize_path(OLD_SAVE)
	if not FileAccess.file_exists(path):
		check(false, "the 1.10 save fixture exists: " + path)
		return
	var sim: RefCounted = Sim.new()
	var error: String = sim.load_game(path)
	check(error == "", "a 1.10 save loads: " + error)
	check(int(sim.state.schema) == 7, "and is brought up to schema 7")
	var told: bool = false
	for line: Variant in sim.state.get("log", []):
		told = told or str(line).contains("1.10 存档按 1.11 规则继续经营")
	check(told, "the log says it plays on under the 1.11 rules")
	for _day: int in range(5):
		sim.tick()
	check(sim.audit().is_empty(), "and it plays on with a clean audit: %s" % str(sim.audit()))
	check(sim.save_game("user://v111_from_110.save") == "", "it saves as a 1.11 game")
	var reread: RefCounted = Sim.new()
	check(
		reread.load_game("user://v111_from_110.save") == "" and int(reread.state.schema) == 7,
		"and that save loads as schema 7"
	)
