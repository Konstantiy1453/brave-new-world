extends SceneTree
## Probe (1.10.1): the globe against deep space, with the planet's star in view when the camera
## faces the sun, and the flat map at its widest zoom across the 180° meridian.
## godot --path game --script res://tests/art/probe_space_flat.gd -- --out=<folder>

const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")
const Map = preload("res://world/map_view.gd")

var out: String = "res://../evidence/v17/art/space_flat"
var failures: Array = []


func _initialize() -> void:
	Watchdog.arm(self, 300.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func shot(name: String) -> void:
	for _i: int in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT " + out.path_join(name + ".png"))


func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	var map = Map.new()
	root.add_child(map)
	var gen = Geo.new()
	var world = gen.generate(260129)
	map.setup(world)
	while map.atlas_refining:
		await process_frame
	map.sync_state({"settlements": [], "roads": [], "shipments": [], "day": 120})
	map.show_planet()
	map.freeze_motion()
	# Turn the globe until the star stands just beside the planet's limb, in the window.
	map.focus_site = -1
	var best_yaw: float = 0.0
	var best_score: float = INF
	for step: int in range(72):
		map.planet_yaw = TAU * step / 72.0
		map.planet_pitch = 0.0
		map.smooth_yaw = map.planet_yaw
		map.smooth_pitch = map.planet_pitch
		map._update_camera(1.0)
		var star: Vector3 = map.star_glare.global_position
		if map.camera.is_position_behind(star):
			continue
		var at: Vector2 = map.camera.unproject_position(star)
		var middle: Vector2 = map.camera.unproject_position(Vector3.ZERO)
		var edge: Vector2 = map.camera.unproject_position(map.camera.global_basis.y * 3.0)
		var radius: float = edge.distance_to(middle)
		var inside: bool = Rect2(Vector2(80, 80), Vector2(1440, 740)).has_point(at)
		var gap: float = at.distance_to(middle) - radius
		if inside and gap > 30.0 and absf(gap - 120.0) < best_score:
			best_score = absf(gap - 120.0)
			best_yaw = map.planet_yaw
	check(best_score < INF, "an angle shows the star beside the planet")
	map.planet_yaw = best_yaw
	map.smooth_yaw = best_yaw
	await shot("globe_towards_star")
	map.planet_yaw = best_yaw + PI
	map.smooth_yaw = map.planet_yaw
	await shot("globe_default_side")
	check(map.space_dome.visible and map.star_glare.visible, "space and the star show on the globe")
	map.show_flat()
	map.flat_user_zoomed = true
	map.zoom(100.0)
	check(
		is_equal_approx(map.flat_size, map.FLAT_HEIGHT),
		"the widest zoom fits the poles (%.2f)" % map.flat_size
	)
	map.flat_center = Vector2(8.6, 0.0)
	map.pan(0.0, 400.0)
	check(absf(map.flat_center.y) < 0.0001, "at the widest zoom the view cannot move past a pole")
	await shot("flat_widest_at_seam")
	for _step: int in range(30):
		map.pan(-60.0, 0.0)
	check(
		absf(map.flat_center.x) <= 9.0, "panning east keeps going round (%.2f)" % map.flat_center.x
	)
	await shot("flat_after_going_round")
	check(not map.space_dome.visible, "space hides on the flat map")
	print("SPACE_FLAT_PROBE failures=%d %s" % [failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)
