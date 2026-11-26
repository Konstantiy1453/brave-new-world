extends SceneTree
## 1.12: the settlement district from a packaged build (`--main-pack ColonyCharter.pck`) or the
## source (`--path game`). Lives outside the project so a PCK, which has no `tests/`, can run it.
## Checks that every raw district and terrain file the game reads by path opens from `res://`
## (meshes, rocks, textures, shaders, JSON, credits), that a save's capital region builds from cold
## with its ground material and textures, its paving and shoulders, its buildings and its nature,
## and records the cold entry, the frame times of three views (the district's default, the approved
## settlement camera and a street-level verge) and a capture of each, with the machine they ran on.
##
##   godot --main-pack <pck> --rendering-driver opengl3 --script <abs>/district_check.gd --
##     --save=<file> --out=<json> [--frames=240] [--size=1920x1080] [--pck=<pck>] [--expect=59: the
##     raw files the source holds]

const METRES_PER_UNIT: float = 16.6
const RAW_FOLDERS: Array[String] = ["res://assets/district", "res://assets/terrain_v3"]
const RAW_SUFFIXES: Array[String] = [
	"meshbin", "rock", "json", "jpg", "png", "gdshader", "txt", "bin"
]

var options: Dictionary = {"save": "", "out": "", "frames": "240", "size": "1920x1080", "pck": ""}
var record: Dictionary = {"checks": [], "ok": true, "views": {}}
var map: Node3D


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	record.options = options.duplicate()
	record.engine = Engine.get_version_info().string
	record.game_version = str(ProjectSettings.get_setting("application/config/version"))
	record.res_has_tests = ResourceLoader.exists("res://tests/v19_region.gd")
	call_deferred("run")


func _check(ok: bool, label: String) -> void:
	record.checks.append({"ok": ok, "label": label})
	if not ok:
		record.ok = false
		print("FAIL ", label)
	else:
		print("PASS ", label)


func run() -> void:
	var started_all: int = Time.get_ticks_msec()
	_raw_files()
	var Sim: GDScript = load("res://simulation/sim.gd")
	var Map: GDScript = load("res://world/map_view.gd")
	var sim: RefCounted = Sim.new()
	var refused: String = sim.load_game(str(options.save))
	var loaded: bool = refused == "" and not sim.state.settlements.is_empty()
	_check(loaded, "the save loads: " + refused)
	if not loaded:
		_finish()
		return
	var region: int = int(sim.state.settlements[0].region)
	map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.set_visual_options(false, true, true)
	while map.atlas_refining:
		await process_frame
	map.sync_state(sim.state)
	var started: int = Time.get_ticks_msec()
	map.show_region(region)
	while map.region_busy:
		await process_frame
	await process_frame
	var cold_ms: int = Time.get_ticks_msec() - started
	var town: Dictionary = sim.settlement(region)
	record.colony = {
		"version": str(sim.geo.version),
		"day": int(sim.state.day),
		"region": region,
		"buildings": town.get("buildings", []).size(),
		"people": int(town.get("population", 0)),
		"cold_entry_ms": cold_ms,
		"fringe_ms": int(map.get("fringe_ms")),
		"nature": map.get("nature_counts"),
	}
	var ground: ShaderMaterial = map.get("ground_material")
	_check(ground != null, "the landscape wears the district ground material")
	if ground != null:
		for texture_name: String in ["soil_patch", "meadow_patch", "scrub", "old_soil", "old_rock"]:
			_check(
				ground.get_shader_parameter(texture_name) != null, "ground texture " + texture_name
			)
		var rect: Vector4 = ground.get_shader_parameter("fringe_rect")
		_check(rect.z > 0.0, "the shoulders' mask is drawn from the paving")
	var streets: Variant = map.get("town_streets")
	_check(streets != null and not streets.edges.is_empty(), "the town's streets are paved")
	var nature: Dictionary = map.get("nature_counts")
	_check(int(nature.get("boulders", 0)) > 0, "weathered boulders stand in the field")
	_check(int(nature.get("toe_stones", 0)) > 0, "toe stones lie round the boulders")
	_check(int(nature.get("fine_grass", 0)) > 0, "fine grass grows")
	var root_node: Node = map.get("buildings_root")
	var models: int = 0
	for child: Node in root_node.get_children():
		if child.has_meta("building_kind"):
			models += 1
	_check(models >= int(record.colony.buildings) - 2, "the buildings stand (%d drawn)" % models)
	var near: int = 0
	for node: Node in root_node.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).visibility_range_end > 0.0:
			near += 1
	_check(near > 0, "reviewed buildings carry their high-detail models near the camera")
	record.machine = {
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window": "%dx%d" % [root.size.x, root.size.y],
		"os": OS.get_name(),
	}
	for view: String in ["default", "settlement", "verge"]:
		await _hold(view)
	record.total_ms = Time.get_ticks_msec() - started_all
	_finish()


## Every raw file under the district's and terrain's folders opens and is not empty.
func _raw_files() -> void:
	var count: int = 0
	var bad: Array[String] = []
	for folder: String in RAW_FOLDERS:
		for path: String in _walk(folder):
			if path.get_extension() not in RAW_SUFFIXES:
				continue
			count += 1
			if FileAccess.get_file_as_bytes(path).is_empty():
				bad.append(path)
	record.raw_files = count
	var expected: int = int(options.get("expect", "59"))
	_check(
		count >= expected and bad.is_empty(),
		"%d raw files open from res:// (of %d) %s" % [count, expected, str(bad)]
	)


func _walk(folder: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	dir.include_hidden = false
	for file: String in dir.get_files():
		found.append(folder + "/" + file.trim_suffix(".remap"))
	for sub: String in dir.get_directories():
		found.append_array(_walk(folder + "/" + sub))
	return found


func _hold(view: String) -> void:
	var centre: Vector3 = map.camera_pivot
	match view:
		"settlement":
			map.local_distance = 155.5 / METRES_PER_UNIT
			map.local_pitch = deg_to_rad(15.7)
		"verge":
			map.local_distance = 16.2 / METRES_PER_UNIT
			map.local_pitch = deg_to_rad(11.3)
		_:
			map.local_distance = 67.0
			map.local_pitch = 0.75
	map.camera_pivot = centre
	map.local_yaw = 0.68
	map.smooth_yaw = map.local_yaw
	map.smooth_pitch = map.local_pitch
	map.smooth_distance = map.local_distance
	for _frame: int in range(20):
		await process_frame
	var times := PackedFloat32Array()
	var last: int = Time.get_ticks_usec()
	for _frame: int in range(int(options.frames)):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var sorted: PackedFloat32Array = times.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in times:
		total += value
	var mean: float = total / maxi(times.size(), 1)
	record.views[view] = {
		"frames": times.size(),
		"mean_ms": mean,
		"median_ms": sorted[sorted.size() / 2],
		"p95_ms": sorted[int(sorted.size() * 0.95)],
		"max_ms": sorted[sorted.size() - 1],
		"fps_mean": 1000.0 / maxf(mean, 0.001),
		"draw_calls":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
		"primitives":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		),
		"distance_m": map.local_distance * METRES_PER_UNIT,
	}
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if str(options.out) != "":
		image.save_png(str(options.out).get_basename() + "_" + view + ".png")
	print("VIEW ", view, " ", JSON.stringify(record.views[view]))


func _finish() -> void:
	if str(options.out) != "":
		var file := FileAccess.open(str(options.out), FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "\t"))
		file.close()
	print("DISTRICT_CHECK ok=%s checks=%d" % [str(record.ok), record.checks.size()])
	quit(0 if record.ok else 1)
