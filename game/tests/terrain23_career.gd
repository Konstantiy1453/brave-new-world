extends SceneTree
## New career, landing, day tick, save/load from seed, and pre-2.3 regression.
## Supply -- --old-save=<1.11.1 save> to exercise a save produced by the original executable.
## The same seed builds a slightly different world on Windows and on Linux (DECISIONS.md, 1.9), so
## the old generators' hashes are kept per platform and a save is checked on the platform that made
## it: the handoff's fixture on Windows, `tests/fixtures/legacy-260129-linux.save` on Linux.
const Sim = preload("res://simulation/sim.gd")
const Gen = preload("res://world/world_gen.gd")
const Plates = preload("res://world/geo2/plates.gd")
const Hydro = preload("res://world/hydrology.gd")
const HISTORICAL := {
	"Windows":
	{
		"CC-GEO-2.0": "2bff58027e5b36dda4be24f1fd942c9b302fd19d0f3bef78552f5b903be3da7b",
		"CC-GEO-2.1": "ac70a6c6ef23c1e0cad36104889c6eaf130ac6daa0e3be4229c918cbfb03ef9e",
		"CC-GEO-2.2": "ac70a6c6ef23c1e0cad36104889c6eaf130ac6daa0e3be4229c918cbfb03ef9e",
	},
	"Linux":
	{
		"CC-GEO-2.0": "c19b38e82883dfce96006e91f02a80c7a1757c55afd361a9b4d61a1e768f3a19",
		"CC-GEO-2.1": "6ba6436130dc694351bd8a56b8588ce2349bfcd1e7fab223bf41479db1dd286d",
		"CC-GEO-2.2": "6ba6436130dc694351bd8a56b8588ce2349bfcd1e7fab223bf41479db1dd286d",
	},
}
## The save each platform checks when no --old-save is given.
const FIXTURES := {
	"Windows": "res://../docs/handoff/approved-terrain-region/map/fixtures/legacy-260129.save",
	"Linux": "res://tests/fixtures/legacy-260129-linux.save",
}
var failures: Array[String] = []
var cases: Array = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)


func digest(bytes: PackedByteArray) -> String:
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(bytes)
	return hash_ctx.finish().hex_encode()


func probe_surface(world: Dictionary) -> String:
	var noise := FastNoiseLite.new()
	noise.seed = int(world.seed)
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	var samples := PackedFloat32Array()
	for y in range(4, Gen.GH - 3, 7):
		for x in range(3, Gen.GW, 9):
			var cell_id: int = y * Gen.GW + x
			var ll := Gen.cell_coordinate(cell_id)
			var cell: Dictionary = world.grid[cell_id]
			var field: Dictionary = Plates.sample_with_context(ll.x, ll.y, noise, world.plates)
			check(
				absf(field.height - cell.height) < 0.00002 and field.land == cell.land,
				"grid and continuous surface match at " + str(cell_id)
			)
			samples.append(field.height)
			samples.append(field.rainfall)
			samples.append(field.temperature)
	return digest(samples.to_byte_array())


func career(seed_value: int, size_id: int) -> void:
	var sim := Sim.new()
	var start := Time.get_ticks_msec()
	sim.new_game(seed_value, "capital", size_id)
	var world: Dictionary = sim.geo
	var hit := str(world.hash)
	var surface := probe_surface(world)
	var water := digest(Hydro.optical_atlas(world, 256, 128).get_data())
	check(
		world.version == "CC-GEO-2.3" and world.plates.version == world.version, "new game uses 2.3"
	)
	check(
		world.generation.validation.ok and world.playability.pairs.size() > 0,
		"playable landing pair " + str(seed_value)
	)
	var landing := sim.act("settle", {"site": 0})
	check(landing.is_empty() and sim.state.settlements.size() == 1, "land " + str(seed_value))
	sim.tick()
	var day: int = sim.state.day
	var save_path := "user://terrain23_regression_" + str(seed_value) + ".save"
	check(sim.save_game(save_path).is_empty(), "save " + str(seed_value))
	Gen._geo_cache.clear()
	var restored := Sim.new()
	var error := restored.load_game(save_path)
	check(error.is_empty(), "reload " + str(seed_value) + " " + error)
	if error.is_empty():
		check(
			restored.geo.hash == hit and restored.geo.version == world.version,
			"cold save regeneration"
		)
		check(probe_surface(restored.geo) == surface, "cold continuous surface")
		check(
			digest(Hydro.optical_atlas(restored.geo, 256, 128).get_data()) == water,
			"cold water coverage"
		)
		check(
			day == 1 and restored.state.day == day and restored.state.settlements.size() == 1,
			"landed colony and time survive save"
		)
	DirAccess.remove_absolute(save_path)
	cases.append(
		{
			"seed": seed_value,
			"size": size_id,
			"world_sha256": hit,
			"surface_sha256": surface,
			"water_sha256": water,
			"regions": world.regions.size(),
			"viable_pairs": world.playability.pairs.size(),
			"day": day,
			"round_trip_ms": Time.get_ticks_msec() - start
		}
	)


func run() -> void:
	Gen.use_disk_cache = false
	for spec in [[260129, 1], [42, 0], [17, 2], [42, 1]]:
		career(spec[0], spec[1])
	check(
		(
			cases[0].surface_sha256 != cases[3].surface_sha256
			and cases[0].water_sha256 != cases[3].water_sha256
		),
		"different seeds produce different terrain and water at the same planet size"
	)
	var historical: Dictionary = HISTORICAL.get(OS.get_name(), {})
	if historical.is_empty():
		print("SKIP historic geography hashes (%s): recorded on Windows and Linux" % OS.get_name())
	for version in historical:
		var world: Dictionary = Gen.new().build(260129, 1, version)
		check(world.hash == historical[version], "unchanged historic geography " + version)
	var old_save_loaded := false
	var old_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--old-save="):
			old_path = arg.trim_prefix("--old-save=")
	if old_path == "" and FIXTURES.has(OS.get_name()):
		old_path = ProjectSettings.globalize_path(FIXTURES[OS.get_name()])
	if old_path != "":
		var old := Sim.new()
		var err: String = old.load_game(old_path)
		old_save_loaded = (
			err.is_empty()
			and old.geo.version == "CC-GEO-2.2"
			and old.geo.hash == historical.get("CC-GEO-2.2", "")
			and old.state.settlements.size() == 1
		)
		check(old_save_loaded, "original 1.11.1 save " + err)
	else:
		print("SKIP the 1.11.1 save (%s): no fixture for this platform" % OS.get_name())
	print(
		"TERRAIN_CAREER ",
		JSON.stringify({"cases": cases, "old_save_loaded": old_save_loaded, "failures": failures})
	)
	quit(0 if failures.is_empty() else 1)
