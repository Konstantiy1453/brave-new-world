extends SceneTree
## 1.12: CC-GEO-2.3 worlds in the game's own globe and satellite map, beside the approved terrain
## frames (docs/handoff/approved-terrain-region/reference: world-eight-seeds, world-snow-detail).
## For each --seeds world (size 1, normal capital opening, as the handoff's review): the globe at
## its default distance and at its closest over each --sites point, lit by a high sun, and again
## with the sun low over the site (dusk); and the flat satellite map at its closest zoom over the
## same points. Clouds and spin off. Writes PNG frames and report.json to --out.
##   xvfb-run -a godot --path game --rendering-driver opengl3 --script
##     res://tests/art/capture_world_23.gd -- --out=<folder> [--seeds=260130]
##     [--sites=-11:-121,-52:-153] [--size=1600x900]

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")

var options: Dictionary = {
	"out": "user://world23",
	"seeds": "260130",
	"sites": "-11:-121,-52:-153",
	"size": "1600x900",
}
var map: Node3D
var folder: String = ""
var report: Dictionary = {"shots": [], "failures": []}


func _initialize() -> void:
	Watchdog.arm(self, 2400.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	folder = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	for seed_text: String in str(options.seeds).split(","):
		var sim: RefCounted = Sim.new()
		sim.new_game(int(seed_text), "capital", 1, "normal")
		report[seed_text] = {"version": str(sim.geo.version)}
		map = Map.new()
		root.add_child(map)
		map.setup(sim.geo)
		map.set_visual_options(false, true, false)
		while map.atlas_refining:
			await process_frame
		map.sync_state(sim.state)
		map.show_planet()
		for _frame: int in range(4):
			await process_frame
		for site: String in str(options.sites).split(","):
			var lat: float = float(site.get_slice(":", 0))
			var lon: float = float(site.get_slice(":", 1))
			var tag: String = (
				"%s_%s_%s" % [seed_text, site.get_slice(":", 0), site.get_slice(":", 1)]
			)
			for hour: String in ["day", "dusk"]:
				_aim(lat, lon, 10.3, 0.0 if hour == "day" else 1.35)
				await _shot("globe_%s_%s_far" % [tag, hour])
				_aim(lat, lon, 7.0, 0.0 if hour == "day" else 1.35)
				await _shot("globe_%s_%s_near" % [tag, hour])
		map.show_flat()
		for site: String in str(options.sites).split(","):
			var lat: float = float(site.get_slice(":", 0))
			var lon: float = float(site.get_slice(":", 1))
			map.flat_size = 4.2
			map.flat_center = Vector2(lon / 180.0 * 9.0, lat / 90.0 * 4.5)
			var tag: String = (
				"%s_%s_%s" % [seed_text, site.get_slice(":", 0), site.get_slice(":", 1)]
			)
			await _shot("flat_%s" % tag)
		map.queue_free()
		await process_frame
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"CAPTURE_WORLD23_RESULT shots=%d failures=%d"
			% [report.shots.size(), report.failures.size()]
		)
	)
	quit(0 if report.failures.is_empty() else 1)


## The globe turned so (lat, lon) faces the camera, the sun `from_noon` radians of the planet's
## turn past local noon there.
func _aim(lat: float, lon: float, distance: float, from_noon: float) -> void:
	map.sky.spin = wrapf(map.sky.sun_yaw - deg_to_rad(lon) + from_noon, 0.0, TAU)
	map.planet.rotation.y = map.sky.spin
	map.planet_yaw = deg_to_rad(lon) + map.sky.spin
	map.planet_pitch = deg_to_rad(lat)
	map.planet_distance = distance
	map.smooth_yaw = map.planet_yaw
	map.smooth_pitch = map.planet_pitch
	map.smooth_distance = distance


func _shot(name: String) -> void:
	for _frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(folder + "/" + name + ".png")
	report.shots.append(name)
	print("CAPTURE ", name)
