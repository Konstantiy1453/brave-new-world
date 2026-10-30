extends SceneTree
## Needs a real window. Points the globe at the antimeridian and measures whether the column
## of pixels on the seam stands out from its neighbours (W1 bug 2).

const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")
const Map = preload("res://world/map_view.gd")
const OUT_DIR: String = "res://../evidence/v17/tests"
const THRESHOLD: float = 0.045
const SETTLE_FRAMES: int = 90
const CONTROL_OFFSET_PX: int = 45

var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 120.0)
	call_deferred("run")


func _luminance(color: Color) -> float:
	return color.r * 0.3 + color.g * 0.59 + color.b * 0.11


## Rows whose pixel at column x differs from the mean of its neighbours by more than THRESHOLD.
func _outliers(image: Image, x: int, top: int, bottom: int) -> int:
	var count: int = 0
	for y: int in range(top, bottom):
		var centre: float = _luminance(image.get_pixel(x, y))
		var side: float = (
			(_luminance(image.get_pixel(x - 3, y)) + _luminance(image.get_pixel(x + 3, y))) / 2.0
		)
		if absf(centre - side) > THRESHOLD:
			count += 1
	return count


func run() -> void:
	root.size = Vector2i(1280, 720)
	var map: Node3D = Map.new()
	root.add_child(map)
	var world: Dictionary = Geo.new().generate(260129)
	map.setup(world)
	map.sync_state({"world": world, "day": 0, "settlements": [], "route": {}})
	map.planet_yaw = PI
	map.planet_pitch = 0.0
	map.planet_distance = 8.0
	if map.cloud_shell != null:
		map.cloud_shell.rotation.y = 0.0
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + "/world_v17_seam.png"))
	var seam_point: Vector3 = Geo.unit_point(0.0, 180.0) * 3.0
	var seam: Vector2 = map.camera.unproject_position(seam_point)
	var x: int = int(round(seam.x))
	var top: int = int(seam.y) - 160
	var bottom: int = int(seam.y) + 160
	var seam_rows: int = 0
	for column: int in [x - 1, x, x + 1]:
		seam_rows = maxi(seam_rows, _outliers(image, column, top, bottom))
	var control_rows: int = 0
	for column: int in [x - CONTROL_OFFSET_PX, x + CONTROL_OFFSET_PX]:
		control_rows = maxi(control_rows, _outliers(image, column, top, bottom))
	print(
		(
			"WORLD_V17_SEAM seam_x=%d seam_outliers=%d control_outliers=%d"
			% [x, seam_rows, control_rows]
		)
	)
	if seam_rows > control_rows + 8:
		failures.append("seam column stands out from control columns")
	map.queue_free()
	await process_frame
	print("WORLD_V17_SEAM_RESULT failures=%d %s" % [failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)
