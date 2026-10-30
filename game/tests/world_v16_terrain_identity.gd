extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")
const Map = preload("res://world/map_view.gd")


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func run():
	var w: Dictionary = Geo.new().generate(260129)
	var old_script = load(
		"res://../versions/v1_5_before_v1_6_20261030_125059/game/world/map_view.gd"
	)
	var old = old_script.new()
	root.add_child(old)
	old.set_process(false)
	old.world = w
	old.noise = FastNoiseLite.new()
	old.noise.seed = int(w.seed)
	old.noise.frequency = 1.8
	old.noise.fractal_octaves = 4
	old.surface = Node3D.new()
	old.add_child(old.surface)
	old._prepare_render_rivers()
	old._prepare_local_rivers()
	var t: int = Time.get_ticks_usec()
	old._build_terrain()
	var old_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	var before: Array = old.surface.get_child(0).mesh.surface_get_arrays(0)
	var map = Map.new()
	root.add_child(map)
	map.set_process(false)
	map.setup(w)
	map.show_region(0)
	while map.region_busy:
		await process_frame
	var after: Array = map.surface.get_child(0).mesh.surface_get_arrays(0)
	var failed: Array = []
	var hashes: Dictionary = {}
	for index in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR]:
		var a: String = var_to_bytes(before[index]).hex_encode().sha256_text()
		var b: String = var_to_bytes(after[index]).hex_encode().sha256_text()
		hashes[str(index)] = {"before": a, "after": b}
		if a != b:
			failed.append("mesh array changed: " + str(index))
	var result: Dictionary = {
		"scope":
		"original frozen v1.5 map terrain routine compared with v1.6 at signed32 seed260129; actual packed vertex,normal,color arrays",
		"old_terrain_ms": old_ms,
		"new_region_ms": map.last_region_ms,
		"array_hashes": hashes,
		"failures": failed
	}
	(
		FileAccess
		. open("res://../evidence/v17/tests/world_terrain_identity.json", FileAccess.WRITE)
		. store_string(JSON.stringify(result, "\t"))
	)
	print("WORLD_TERRAIN_IDENTITY ", JSON.stringify(result))
	old.queue_free()
	map.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
