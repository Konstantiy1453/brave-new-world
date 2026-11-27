extends SceneTree

const Sim = preload("res://simulation/sim.gd")
const LightRecord = preload("res://simulation/light_record.gd")
const Timelapse = preload("res://world/timelapse.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var sim := Sim.new()
	var error: String = sim.new_game(260129, "capital", 1, "normal")
	if error.is_empty():
		error = sim.act("settle", {"site": 0})
	if error.is_empty():
		_stages(sim)
		_legacy_record(sim)
	else:
		failures.append(error)
	for reason: String in failures:
		push_error(reason)
	print("EXTRACTION_LIGHT_STAGE ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)


func _stages(sim: RefCounted) -> void:
	var stages: Array = sim.progression.lights.stages
	var town := {"kind": "residential", "population": 0, "buildings": []}
	for index: int in range(stages.size()):
		var rule: Dictionary = stages[index]
		town.population = rule.population
		town.buildings = [{"kind": "habitat", "remaining": 0}, {"kind": "mine_ore", "remaining": 1}]
		for _n: int in range(int(rule.facilities)):
			town.buildings.append({"kind": "mine_ore", "remaining": 0})
		town.kind = "residential"
		check(LightRecord.facilities(sim, town) == int(rule.facilities), "completed non-housing facilities")
		check(LightRecord.stage_of(sim, town) == index, "residential town with mines reaches stage %d" % index)
		town.kind = "frontier"
		check(LightRecord.stage_of(sim, town) == 0, "frontier stays a work camp at city stage %d" % index)
	var current := {"population": 125, "facilities": 8, "frontier": false}
	check(is_equal_approx(LightRecord.town_level(stages, current), 1.5), "city grows between stages")
	current.frontier = true
	check(LightRecord.town_level(stages, current) == 0.0, "frontier does not interpolate upward")


func _legacy_record(sim: RefCounted) -> void:
	var home: Dictionary = sim.state.settlements[0]
	sim.state.contract.licences.append("expedition")
	sim._transfer("external", "public", 200000.0, "TEST expedition", false)
	sim.Population._admit(sim, home, 60, 0)
	for key: String in ["materials", "food", "parts"]:
		sim._produce(home, key, 1000.0, "TEST supplies")
	var dest: int = -1
	for site: Dictionary in sim.state.world.regions:
		if sim.Sites.settle_refusal(sim, int(site.id), int(home.region), "frontier").is_empty():
			dest = int(site.id)
			break
	if dest < 0:
		failures.append("no reachable frontier region")
		return
	var error: String = sim.act("settle", {"region": dest, "from": int(home.region), "kind": "frontier"})
	if not error.is_empty():
		failures.append(error)
		return
	var outpost: Dictionary = sim.settlement(dest)
	outpost.arrival = 0
	# Snapshot the mature work camp, then restore the simulation's real population and buildings.
	var population: int = int(outpost.population)
	var buildings: Array = outpost.buildings
	outpost.population = 2500
	outpost.buildings = []
	for n: int in range(70):
		outpost.buildings.append({"kind": "mine_ore", "remaining": 0})
	var frame: Dictionary = LightRecord.snapshot(sim)
	outpost.population = population
	outpost.buildings = buildings
	var mine: Dictionary = frame.towns[1]
	check(mine.frontier and mine.stage == 0 and mine.facilities == 70 and mine.population == 2500,
		"new snapshots keep mining history and the first-stage appearance")
	var city: Dictionary = frame.towns[0]
	city.population = 2000
	city.facilities = 60
	city.stage = 4
	mine.stage = 4
	# Exercise both generations of archived records through the normal save and load entry points.
	for missing_kind: bool in [false, true]:
		if missing_kind:
			mine.erase("frontier")
			city.erase("frontier")
		sim.state.lights.snapshots = [frame]
		sim.state.lights.next_day = int(frame.day) + 90
		var path := "user://extraction_light_stage_%d.save" % int(missing_kind)
		error = sim.save_game(path)
		if not error.is_empty():
			failures.append(error)
			return
		var hash_before := FileAccess.get_sha256(path)
		var loaded := Sim.new()
		error = loaded.load_game(path)
		if not error.is_empty():
			failures.append(error)
			return
		check(FileAccess.get_sha256(path) == hash_before, "loading leaves the original save intact")
		var restored: Dictionary = loaded.state.lights.snapshots[0]
		var old_mine: Dictionary = restored.towns[1]
		check(old_mine.frontier and old_mine.stage == 0 and old_mine.facilities == 70 and old_mine.population == 2500,
			"legacy outpost stage restored with actual population and facilities")
		check(not restored.towns[0].frontier and restored.towns[0].stage == 4, "legacy residential stage preserved")
		var later: Dictionary = restored.duplicate(true)
		later.day += 90
		later.towns[1].population += 1200
		later.towns[1].facilities += 35
		for offset: float in [0.0, 45.0, 90.0]:
			var shown: Array = Timelapse.towns_on([restored, later], float(restored.day) + offset)
			check(shown[1].frontier and shown[1].stage == 0 and shown[0].stage == 4, "replay preserves both kinds")
		var corrected: PackedByteArray = var_to_bytes(loaded.state.lights)
		LightRecord.restore_frontier_stages(loaded.state)
		check(var_to_bytes(loaded.state.lights) == corrected, "restoring a corrected archive is idempotent")
