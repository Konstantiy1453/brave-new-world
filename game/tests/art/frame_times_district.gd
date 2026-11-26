extends SceneTree
## 1.12: cold entry and frame times in a populated district. Loads a save (--save), shows its
## capital's region from cold (no region cached), then holds each view (--views: the district's
## default view, the approved settlement camera, a street-level verge view) for --frames frames
## and records each frame's wall time, the frame's draw calls and primitives, and the machine:
## processor, graphics adapter, renderer and window size. Writes frame_times.json to --out.
##   xvfb-run -a godot --path game --rendering-driver opengl3 --script
##     res://tests/art/frame_times_district.gd -- --save=<file> --out=<folder> [--size=1920x1080]
##     [--frames=240] [--views=default,settlement,verge]

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")

var options: Dictionary = {
	"save": "",
	"out": "user://frame_times",
	"size": "1920x1080",
	"frames": "240",
	"views": "default,settlement,verge",
	"region": "",
}
var map: Node3D
var report: Dictionary = {"views": {}, "failures": []}


func _initialize() -> void:
	Watchdog.arm(self, 2400.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	var folder: String = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	var sim: RefCounted = Sim.new()
	var refused: String = sim.load_game(str(options.save))
	if refused != "" or sim.state.settlements.is_empty():
		report.failures.append("load: " + refused)
		_finish(folder)
		return
	var region: int = (
		int(options.region) if str(options.region) != "" else int(sim.state.settlements[0].region)
	)
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
	var town: Dictionary = sim.settlement(region)
	report.machine = {
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window": "%dx%d" % [root.size.x, root.size.y],
		"os": OS.get_name(),
	}
	report.colony = {
		"version": str(sim.geo.version),
		"day": int(sim.state.day),
		"region": region,
		"buildings": town.get("buildings", []).size(),
		"people": int(town.get("population", 0)),
		"cold_entry_ms": Time.get_ticks_msec() - started,
		"fringe_ms": int(map.get("fringe_ms")),
		"nature": map.get("nature_counts"),
	}
	for view: String in str(options.views).split(","):
		await _hold(view)
	_finish(folder)


func _hold(view: String) -> void:
	var centre: Vector3 = map.camera_pivot
	match view:
		"settlement":
			map.local_distance = 155.5 * DistrictPlan.UNIT
			map.local_pitch = deg_to_rad(15.7)
		"verge":
			map.local_distance = 16.2 * DistrictPlan.UNIT
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
	var calls := PackedFloat32Array()
	var primitives := PackedFloat32Array()
	var last: int = Time.get_ticks_usec()
	for _frame: int in range(int(options.frames)):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		calls.append(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
		primitives.append(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			)
		)
	var sorted: PackedFloat32Array = times.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in times:
		total += value
	report.views[view] = {
		"frames": times.size(),
		"mean_ms": total / maxi(times.size(), 1),
		"median_ms": sorted[sorted.size() / 2],
		"p95_ms": sorted[int(sorted.size() * 0.95)],
		"max_ms": sorted[sorted.size() - 1],
		"fps_mean": 1000.0 / maxf(total / maxi(times.size(), 1), 0.001),
		"draw_calls": calls[calls.size() - 1],
		"primitives": primitives[primitives.size() - 1],
		"distance_m": map.local_distance * DistrictPlan.METRES_PER_UNIT,
	}
	print("FRAME_TIMES ", view, " ", JSON.stringify(report.views[view]))


func _finish(folder: String) -> void:
	var file := FileAccess.open(folder + "/frame_times.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("FRAME_TIMES_RESULT failures=%d %s" % [report.failures.size(), str(report.failures)])
	quit(0 if report.failures.is_empty() else 1)
