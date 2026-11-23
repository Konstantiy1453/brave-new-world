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
