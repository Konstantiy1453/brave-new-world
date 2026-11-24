extends SceneTree
## 1.11 phase G (the parts that do not wait for the light concept sheet):
## - a light snapshot on the first day with a settlement and every quarter after, the same for the
##   same seed; each town's place, stage, people, facilities, coast and roads;
## - the stage is the highest whose people and facilities a town both has (thresholds in data);
## - an old save starts its record when it loads; saves keep the record; the audit holds it;
## - the time-lapse reads the record: towns between snapshots, new towns growing in, bigger towns
##   drawn bigger; the player runs, holds the last frame, can be skipped, and calls what follows.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const LightRecord = preload("res://simulation/light_record.gd")
const Timelapse = preload("res://world/timelapse.gd")
const TimelapseView = preload("res://ui/timelapse_view.gd")
const TownForms = preload("res://world/town_forms.gd")
const Shaders = preload("res://world/shaders.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Rules = preload("res://simulation/rules.gd")
const SEED: int = 20261124

var checks: int = 0
var failures: Array[String] = []


class FakeMap:
	extends Node
	var playing: bool = false
	var elapsed: float = 0.0
	var seconds: float = 1.0
	var stopped: int = 0

	func play_timelapse(_snapshots: Array, length: float) -> void:
		playing = true
		seconds = length
		elapsed = 0.0

	func stop_timelapse() -> void:
		playing = false
		stopped += 1

	func timelapse_progress() -> float:
		return clampf(elapsed / seconds, 0.0, 1.0) if playing else -1.0

	func timelapse_day() -> int:
		return int(elapsed)


class FakeGame:
	extends Node
	var sim: RefCounted
	var map: Node
	var ui: Control
	var paused: bool = false


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_record()
	_stages()
	_saved()
	_interpolation()
	_forms()
	await _player()
	print("V111_LIGHTS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1)
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) == "":
			sim.act("settle", {"region": int(reg.id)})
			break
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	return sim


func _tick(sim: RefCounted) -> void:
	for town: Dictionary in sim.state.settlements:
		sim._produce(town, "food", maxf(0.0, 400.0 - float(town.stock.food)), "TEST food")
	sim.state.company.distrust = 0.0
	sim.state.company.stage = "normal"
	sim.tick()


func _record() -> void:
	var one: RefCounted = _colony()
	var two: RefCounted = _colony()
	var every: int = int(one.progression.lights.snapshot_days)
	for _day: int in range(every * 2 + 5):
		_tick(one)
		_tick(two)
	var snaps: Array = one.state.lights.snapshots
	check(
		snaps.size() == 3,
		"a snapshot on the first day and every %d days: %d" % [every, snaps.size()]
	)
	var spaced: bool = snaps.size() == 3
	for index: int in range(1, snaps.size()):
		spaced = spaced and int(snaps[index].day) - int(snaps[index - 1].day) == every
	check(spaced, "a quarter apart")
	# A snapshot taken now, against the state now (the last recorded one is days old).
	var town: Dictionary = LightRecord.snapshot(one).towns[0]
	var capital: Dictionary = one.state.settlements[0]
	check(
		(
			not town.is_empty()
			and int(town.region) == int(capital.region)
			and int(town.population) == int(capital.population)
			and int(town.facilities) == LightRecord.facilities(one, capital)
			and town.has("lat")
			and town.has("coastal")
			and town.roads is Array
		),
		"each town's place, stage, people, facilities, coast and roads"
	)
	check(
		var_to_bytes(one.state.lights) == var_to_bytes(two.state.lights),
		"the same seed records the same lights"
	)
	check(one.audit().is_empty(), "the audit holds: %s" % str(one.audit()))
	one.state.lights.snapshots.reverse()
	check("light snapshots out of order" in one.audit(), "and catches a record out of order")


func _stages() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	var stages: Array = sim.progression.lights.stages
	var right: bool = true
	var facilities: int = LightRecord.facilities(sim, town)
	for index: int in range(stages.size()):
		var rule: Dictionary = stages[index]
		town.population = int(rule.population)
		var expect: int = 0
		for other: int in range(stages.size()):
			var needs: Dictionary = stages[other]
			if (
				int(town.population) >= int(needs.population)
				and facilities >= int(needs.facilities)
			):
				expect = other
		right = right and LightRecord.stage_of(sim, town) == expect
	check(right, "a town's stage is the highest whose people and facilities it has")
	town.population = 100000
	check(
		(
			LightRecord.stage_of(sim, town) < stages.size() - 1
			or facilities >= int(stages.back().facilities)
		),
		"people alone do not make a planetary capital (%d facilities)" % facilities
	)
	check(
		str(stages[0].name) == "着陆点" and str(stages.back().name) == "星球首府",
		"five stages, 着陆点 to 星球首府, as on the concept sheet"
	)


func _saved() -> void:
	var sim: RefCounted = _colony()
	for _day: int in range(100):
		_tick(sim)
	check(sim.save_game("user://v111_lights.save") == "", "a game with a light record saves")
	var again: RefCounted = Sim.new()
	check(again.load_game("user://v111_lights.save") == "", "and loads")
	check(
		var_to_bytes(again.state.lights) == var_to_bytes(sim.state.lights),
		"with its record (%d snapshots)" % sim.state.lights.snapshots.size()
	)
	var old: RefCounted = _colony()
	old.state.erase("lights")
	old.ensure_systems(old.state)
	check(
		old.state.lights.snapshots.is_empty() and old.state.has("lights"),
		"an old save gets an empty record"
	)
	_tick(old)
	check(old.state.lights.snapshots.size() == 1, "which starts on the day it loads")


func _interpolation() -> void:
	var record: Array = [
		{"day": 0, "towns": [_town(1, 40, 2)]},
		{"day": 100, "towns": [_town(1, 240, 10), _town(5, 80, 4)]},
	]
	var mid: Array = Timelapse.towns_on(record, 50.0)
	check(
		mid.size() == 2 and is_equal_approx(float(mid[0].population), 140.0),
		"halfway between snapshots a town is halfway grown"
	)
	check(
		(
			is_equal_approx(float(mid[1].fade), 0.5)
			and is_equal_approx(float(mid[1].population), 40.0)
		),
		"a new town grows in from nothing"
	)
	check(Timelapse.towns_on(record, 0.0).size() == 1, "before it is founded it is not drawn")
	check(
		Timelapse.towns_on(record, 500.0).size() == 2, "after the last snapshot the last is drawn"
	)
	var drawn: Dictionary = Timelapse.uniforms(Timelapse.towns_on(record, 100.0))
	check(
		(
			int(drawn.count) == 2
			and drawn.towns[0].z > drawn.towns[1].z
			and drawn.styles[0].z > drawn.styles[1].z
			and drawn.towns.size() == Timelapse.MAX_TOWNS
		),
		"bigger towns are drawn bigger and brighter"
	)


## The planet-scale forms of the light concept sheet (1.11 G, town_forms.gd).
func _forms() -> void:
	var rules: Dictionary = Rules.read("progression").lights
	var stages: Array = rules.stages
	var sizes: Array = []
	for index: int in range(stages.size()):
		sizes.append(TownForms.form_radius(stages, float(index)))
	var growing: bool = true
	for index: int in range(1, sizes.size()):
		growing = growing and float(sizes[index]) > float(sizes[index - 1])
	check(
		growing and float(sizes[4]) / float(sizes[0]) > 8.0,
		"the five stages grow in the sheet's proportions: %s" % str(sizes)
	)
	var level_at: Array = []
	for pair: Vector2 in [
		Vector2(0, 0),
		Vector2(50, 4),
		Vector2(125, 8),
		Vector2(200, 12),
		Vector2(1500, 45),
		Vector2(9000, 300)
	]:
		level_at.append(LightRecord.stage_level(stages, pair.x, pair.y))
	check(
		(
			is_equal_approx(float(level_at[1]), 1.0)
			and float(level_at[2]) > 1.0
			and float(level_at[2]) < 2.0
			and is_equal_approx(float(level_at[3]), 2.0)
			and is_equal_approx(float(level_at[5]), 4.0)
		),
		"a town grows between stages and stops at the capital: %s" % str(level_at)
	)
	var sim: RefCounted = _colony()
	# The views draw on the derived geography (main.gd `map.setup(sim.geo)`), which holds the grid.
	var world: Dictionary = sim.geo
	var coastal: Dictionary = {}
	var inland: Dictionary = {}
	for reg: Dictionary in world.regions:
		if coastal.is_empty() and bool(reg.get("coast", false)):
			coastal = reg
		if inland.is_empty() and not bool(reg.get("coast", false)) and bool(reg.get("land", true)):
			var way: Vector2 = TownForms.sea_direction(world, float(reg.lat), float(reg.lon), 1.0)
			if way == Vector2.ZERO:
				inland = reg
	var sea: Vector2 = TownForms.sea_direction(world, float(coastal.lat), float(coastal.lon), 1.0)
	var off_lat: float = float(coastal.lat) + sea.y * 1.0
	var off_lon: float = (
		float(coastal.lon) + sea.x * 1.0 / maxf(cos(deg_to_rad(float(coastal.lat))), 0.2)
	)
	var wet: bool = not bool(world.grid[SiteGen.cell_at(world, off_lat, off_lon)].get("land", true))
	check(
		sea.length() > 0.99 and wet and not inland.is_empty(),
		"a coastal town knows which way its sea lies, an inland one has none"
	)
	var east := {"region": 1, "lat": 0.0, "lon": 10.0, "population": 700.0, "facilities": 30.0}
	var west := {"region": 2, "lat": 0.0, "lon": 7.0, "population": 700.0, "facilities": 30.0}
	east.roads = [2]
	var bearing: Vector4 = TownForms.road_bearings(east, {1: Vector2(0, 10), 2: Vector2(0, 7)})
	check(
		absf(absf(bearing.x) - PI) < 0.01 and bearing.y == TownForms.NO_ROAD,
		"a town's arm follows the road the player built: %s" % str(bearing)
	)
	var drawn: Dictionary = TownForms.uniforms([east, west], world, rules)
	check(
		float(drawn.towns[0].z) <= 3.0 * float(rules.forms.neighbour_share) + 0.0001,
		"neighbouring towns stay apart: radius %.2f with 3° between them" % float(drawn.towns[0].z)
	)
	var sums: bool = true
	for distance: float in [7.0, 7.6, 8.0, 8.5, 9.0, 9.4, 10.3, 15.8]:
		var shares: Vector2 = TownForms.weights(distance, rules)
		sums = sums and is_equal_approx(shares.x + shares.y, 1.0)
	var near: Vector2 = TownForms.weights(7.0, rules)
	var usual: Vector2 = TownForms.weights(10.3, rules)
	check(
		sums and near == Vector2(1, 0) and usual == Vector2(0, 1),
		"up close the plots, from the default distance the forms, never both in full"
	)
	_far(sim, rules)
	var record: Array = [{"day": 0, "towns": [_town(1, 240, 10)]}]
	var shown: Dictionary = Timelapse.uniforms(Timelapse.towns_on(record, 0.0), world)
	var same: Dictionary = TownForms.uniforms(Timelapse.towns_on(record, 0.0), world, rules)
	check(
		shown.towns == same.towns and shown.styles == same.styles,
		"the time-lapse draws the same forms as the globe in play"
	)
	var code: String = Shaders.shader("globe").code
	check(
		(
			code.contains("town_roads")
			and code.contains("form_lights")
			and code.contains("forms *= coast")
		),
		"the globe's shader draws the forms, cut by the coast, beside the plots"
	)


## A finished road shows as a faint string between its towns; a facility far from its town is a
## point of its own; one in the town is part of its form.
func _far(sim: RefCounted, rules: Dictionary) -> void:
	var buildings: Dictionary = sim.config.buildings
	var state: Dictionary = sim.state
	var capital: Dictionary = state.settlements[0].duplicate()
	var home: Dictionary = sim.geo.regions[int(capital.region)]
	capital.lat = float(capital.get("lat", home.lat))
	capital.lon = float(capital.get("lon", home.lon))
	var other: Dictionary = {}
	var other_index: int = -1
	var closest: float = INF
	for index: int in range(sim.geo.regions.size()):
		var reg: Dictionary = sim.geo.regions[index]
		var apart: float = rad_to_deg(
			_unit(float(reg.lat), float(reg.lon)).angle_to(_unit(capital.lat, capital.lon))
		)
		if index != int(capital.region) and apart > 3.0 and apart < closest:
			closest = apart
			other = reg
			other_index = index
	check(other_index >= 0, "a second place to build a road to")
	var road := {
		"id": 900,
		"a": int(capital.region),
		"b": other_index,
		"ready_day": 0,
		"coordinates": [[capital.lat, capital.lon], [other.lat, other.lon]],
	}
	state.roads.append(road)
	var towns: Array = TownForms.towns_now(state, sim.geo, buildings)
	var image: Image = TownForms.far_image(state, sim.geo, buildings, towns, rules)
	var middle := Vector2(
		(float(capital.lat) + float(other.lat)) * 0.5,
		float(capital.lon) + wrapf(float(other.lon) - float(capital.lon), -180.0, 180.0) * 0.5
	)
	var lit: float = 0.0
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var x: int = posmod(
				int((wrapf(middle.y, -180.0, 180.0) + 180.0) / 360.0 * TownForms.FAR_WIDTH) + dx,
				TownForms.FAR_WIDTH
			)
			var y: int = int((90.0 - middle.x) / 180.0 * TownForms.FAR_HEIGHT) + dy
			lit = maxf(lit, image.get_pixel(x, clampi(y, 0, TownForms.FAR_HEIGHT - 1)).r)
	check(lit > 0.02, "a finished road is a faint string of light: %.3f midway" % lit)
	state.roads.erase(road)


func _unit(lat: float, lon: float) -> Vector3:
	var la: float = deg_to_rad(lat)
	var lo: float = deg_to_rad(lon)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))


func _town(region: int, people: int, facilities: int) -> Dictionary:
	return {
		"region": region,
		"lat": 10.0 + region,
		"lon": 20.0,
		"stage": 0,
		"population": people,
		"facilities": facilities,
		"coastal": false,
		"frontier": false,
		"roads": [],
	}


func _player() -> void:
	var fake := FakeGame.new()
	fake.sim = _colony()
	fake.map = FakeMap.new()
	fake.ui = Control.new()
	fake.add_child(fake.map)
	fake.add_child(fake.ui)
	root.add_child(fake)
	var called: Array = []
	TimelapseView.play(fake, func(): called.append("none"))
	check(called == ["none"], "without a record what follows comes at once")
	for _day: int in range(3):
		_tick(fake.sim)
	fake.sim.progression.lights.timelapse_seconds = 0.2
	TimelapseView.play(fake, func(): called.append("after"))
	check(fake.map.playing and fake.paused, "with a record the globe plays it and the clock stops")
	for _frame: int in range(4):
		fake.map.elapsed += 0.1
		await process_frame
	check(not called.has("after"), "the last frame holds a moment")
	for _frame: int in range(30):
		fake.map.elapsed += 0.1
		await create_timer(0.1).timeout
	check(
		called.has("after") and fake.map.stopped == 1,
		"then the time-lapse ends and the page follows"
	)
	TimelapseView.play(fake, func(): called.append("skipped"))
	var view: Node = fake.ui.get_node_or_null("Timelapse")
	if view != null:
		view.finish()
	check(called.has("skipped") and not fake.map.playing, "skipping ends it at once")
	fake.queue_free()
