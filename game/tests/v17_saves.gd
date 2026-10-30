extends SceneTree
## Save schema 3: size, speed, exact round trip, siblings, migration of every shipped 1.6 fixture.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Career = preload("res://simulation/career.gd")
const WorldGen = preload("res://world/world_gen.gd")
const MAX_TYPICAL_BYTES: int = 1500000
const OLD_FIXTURES: Array[String] = [
	"res://data/v16/acceptance_pre_award.json",
	"res://data/v16/acceptance_crisis.json",
	"res://data/v16/acceptance_event_mid.json",
	"res://data/v16/acceptance_research.json",
	"res://data/v16/acceptance_governor.json",
	"res://data/v16/acceptance_second_dividend.json",
	"res://data/acceptance_midgame.json",
	"res://data/acceptance_success.json",
]

var checks: int = 0
var failures: Array[String] = []
var report: Dictionary = {"fixtures": {}}


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_fresh_game_round_trip()
	_migrate_old_fixtures()
	_second_world_siblings()
	_mismatched_world_refused()
	_async_autosave_path()
	_header_only()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://../evidence/v17/tests")
	)
	FileAccess.open("res://../evidence/v17/tests/v17_saves.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("V17_SAVES_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _played(days: int) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	sim.act("settle", {"region": 0})
	sim.act("build", {"region": 0, "kind": "mine_ore"})
	Career.capture_checkpoint(sim)
	for _i: int in range(days):
		sim.tick()
	return sim


func _fresh_game_round_trip() -> void:
	var sim: RefCounted = _played(60)
	var path: String = "user://v17_round_trip.save"
	var started: int = Time.get_ticks_usec()
	check(sim.save_game(path) == "", "save writes")
	report.save_ms = (Time.get_ticks_usec() - started) / 1000.0
	var bytes: int = FileAccess.get_file_as_bytes(path).size()
	report.typical_bytes = bytes
	check(bytes <= MAX_TYPICAL_BYTES, "typical save at most 1.5 MB, was %d" % bytes)
	started = Time.get_ticks_usec()
	var restored: RefCounted = Sim.new()
	check(restored.load_game(path) == "", "load reads")
	report.load_ms_warm_world = (Time.get_ticks_usec() - started) / 1000.0
	check(var_to_bytes(restored.state) == var_to_bytes(sim.state), "state round trip is exact")
	check(not sim.state.world.has("grid"), "the grid is not in the saved state")
	check(restored.geo.grid.size() == WorldGen.GW * WorldGen.GH, "geography is regenerated on load")
	for _i: int in range(30):
		sim.tick()
		restored.tick()
	check(var_to_bytes(restored.state) == var_to_bytes(sim.state), "continuation stays identical")
	var sibling: String = path + ".ckpt-" + str(sim.state.career.checkpoint).left(16)
	check(FileAccess.file_exists(sibling), "landing checkpoint is a sibling file")
	check(sim.state.career.checkpoint.length() == 64, "the state keeps only the checkpoint hash")
	check(
		sim.save_game(path) == "" and FileAccess.file_exists(path + ".bak"),
		"second save keeps a backup"
	)


func _migrate_old_fixtures() -> void:
	for fixture: String in OLD_FIXTURES:
		var sim: RefCounted = Sim.new()
		var error: String = sim.load_game(fixture)
		check(error == "", "old fixture migrates: %s %s" % [fixture.get_file(), error])
		if error != "":
			continue
		check(int(sim.state.schema) == 3, "migrated state is schema 3: " + fixture.get_file())
		check(sim.audit().is_empty(), "migrated state passes audit: " + fixture.get_file())
		var path: String = "user://v17_migrated.save"
		check(sim.save_game(path) == "", "migrated state saves: " + fixture.get_file())
		var restored: RefCounted = Sim.new()
		check(restored.load_game(path) == "", "migrated save reloads: " + fixture.get_file())
		check(
			var_to_bytes(restored.state) == var_to_bytes(sim.state),
			"reload exact: " + fixture.get_file()
		)
		var before: int = FileAccess.get_file_as_bytes(fixture).size()
		var after: int = FileAccess.get_file_as_bytes(path).size()
		report.fixtures[fixture.get_file()] = {
			"old_bytes": before,
			"new_bytes": after,
			"regenerated": not sim.state.world.has("stored_geo"),
		}
		sim.tick()
		restored.tick()
		check(
			var_to_bytes(restored.state) == var_to_bytes(sim.state),
			"reload continues: " + fixture.get_file()
		)
		check(sim.audit().is_empty(), "first tick after migration audits: " + fixture.get_file())


func _second_world_siblings() -> void:
	var sim: RefCounted = Sim.new()
	check(sim.load_game("res://data/v16/acceptance_governor.json") == "", "governor fixture loads")
	Career.capture_checkpoint(sim)
	var path: String = "user://v17_second.save"
	check(
		Career.handover(sim, 42, "capital", "normal", path) == "",
		"handover writes through schema 3"
	)
	check(sim.state.career.archives.size() == 1, "one archive recorded")
	var archive: Dictionary = sim.state.career.archives[0]
	check(not archive.has("snapshot") and archive.hash.length() == 64, "archive stored by hash")
	check(
		FileAccess.file_exists(
			"%s.arch%d-%s" % [path, int(archive.id), str(archive.hash).left(16)]
		),
		"archive is a sibling file"
	)
	var restored: RefCounted = Sim.new()
	check(restored.load_game(path) == "", "second-world save reloads")
	check(not restored.blobs.checkpoint.is_empty(), "checkpoint found on reload")
	check(restored.blobs.archives.has(archive.id), "archive found on reload")
	var frozen: Variant = Career.decode_blob(restored.blobs.archives[archive.id])
	check(
		frozen is Dictionary and int(frozen.world.seed) == int(archive.seed),
		"archive decodes to its world"
	)
	sim.act("settle", {"region": 0})
	for _i: int in range(3):
		sim.tick()
	check(Career.restart(sim, "normal", path) == "", "restart from a sibling checkpoint")
	check(int(sim.state.day) == 0, "restart returns to landing")
	check(sim.state.career.managed.size() == 1, "restart keeps earlier stewardship")


func _mismatched_world_refused() -> void:
	var sim: RefCounted = _played(5)
	var before: PackedByteArray = var_to_bytes(sim.state)
	var other: RefCounted = Sim.new()
	other.new_game(42, "capital", 1, "normal")
	var bad: Dictionary = sim.state.duplicate(true)
	bad.world.hash = other.state.world.hash
	var path: String = "user://v17_bad_world.save"
	preload("res://tests/support/save_fixture.gd").write_state(path, bad)
	var error: String = sim.load_game(path)
	check(error.contains("世界"), "a world hash mismatch is refused with a message: " + error)
	check(var_to_bytes(sim.state) == before, "refused load leaves the game unchanged")


func _async_autosave_path() -> void:
	var sim: RefCounted = _played(10)
	var path: String = "user://v17_async.save"
	var snap: Dictionary = SaveIo.snapshot(sim, path)
	var worker: int = WorkerThreadPool.add_task(
		func() -> void: snap.result = SaveIo.write_snapshot(snap)
	)
	WorkerThreadPool.wait_for_task_completion(worker)
	check(str(snap.get("result", "x")) == "", "snapshot writes on a worker thread")
	var restored: RefCounted = Sim.new()
	check(restored.load_game(path) == "", "worker-written save loads")
	check(var_to_bytes(restored.state) == var_to_bytes(sim.state), "worker-written save is exact")


func _header_only() -> void:
	var sim: RefCounted = _played(7)
	var path: String = "user://v17_header.save"
	sim.save_game(path)
	var header: Dictionary = SaveIo.read_header(path)
	check(int(header.get("day", -1)) == 7, "header gives the day without the payload")
	check(int(header.get("seed", -1)) == 260129, "header gives the seed")
	check(header.get("sha256", "") != "", "header carries the checksum")
