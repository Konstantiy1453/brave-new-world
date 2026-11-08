extends SceneTree
## Needs a real window (1.9 plan B6). Renders every building kind with its model, as the region
## draws it (the kind's tint and scale, the game's sun and ambient light), from a three-quarter view
## on a transparent background, and writes assets/icons/buildings/<kind>.webp (lossless) at 128 px.
## Kinds drawn procedurally get no icon and keep their SVG. Run the import afterwards so the game can
## load them, with mipmaps on in each new .import file.
## Options: --out=res://assets/icons/buildings --size=128 --only=kind,kind

const Watchdog = preload("res://tests/support/watchdog.gd")
const Map = preload("res://world/map_view.gd")
const ModelArt = preload("res://world/model_art.gd")
const RULES: String = "res://data/v17/economy.json"
## Rendered this many times larger, then scaled down: smooth edges without multisampling.
const SUPERSAMPLE: int = 2
## From the front right and above, the side the game's sun lights.
const VIEW: Vector3 = Vector3(0.75, 0.82, 1.0)
const MARGIN: float = 1.06

var options: Dictionary = {"out": "res://assets/icons/buildings", "size": "128", "only": ""}


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: int = int(options.size)
	var folder: String = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	var map: Node3D = Map.new()
	root.add_child(map)
	map.set_process(false)
	map.visible = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size * SUPERSAMPLE, size * SUPERSAMPLE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_light(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	viewport.add_child(camera)
	var kinds: Array = JSON.parse_string(FileAccess.get_file_as_string(RULES)).buildings.keys()
	kinds.append("service")
	kinds.sort()
	var only: Array = Array(str(options.only).split(",", false))
	var written: int = 0
	var skipped: Array = []
	for kind: String in kinds:
		if not only.is_empty() and not only.has(kind):
			continue
		var entry: Dictionary = ModelArt.kind_entry(kind)
		if entry.is_empty():
			skipped.append(kind)
			continue
		var art: MeshInstance3D = ModelArt.instance(
			str(entry.model),
			func(slot: String) -> Material: return map._art_material(slot, entry, true)
		)
		art.scale = Vector3.ONE * float(entry.get("scale", 1.0))
		viewport.add_child(art)
		_frame(camera, art)
		for _frame_index: int in range(3):
			await process_frame
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var path: String = folder.path_join(kind + ".webp")
		if image.save_webp(path, false) == OK:
			written += 1
		art.queue_free()
		await process_frame
	print("ICONS skipped (procedural): %s" % str(skipped))
	print("BAKE_ICONS_RESULT written=%d skipped=%d" % [written, skipped.size()])
	quit(0)


## The game's daylight: the map's sun, fill and ambient, with a clear background.
func _light(viewport: SubViewport) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Map.DAY_AMBIENT
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("f6ecd1")
	sun.light_energy = Map.SUN_ENERGY
	sun.rotation_degrees = Map.SUN_ROTATION
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("5ba6ca")
	fill.light_energy = 0.18
	fill.rotation_degrees = Vector3(35, 140, 0)
	viewport.add_child(fill)


## Looks at the model from `VIEW` with an orthographic size that just holds its bounds.
func _frame(camera: Camera3D, art: MeshInstance3D) -> void:
	var box: AABB = art.get_aabb()
	box = AABB(box.position * art.scale, box.size * art.scale)
	var centre: Vector3 = box.get_center()
	var direction: Vector3 = VIEW.normalized()
	camera.look_at_from_position(centre + direction * 50.0, centre, Vector3.UP)
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y
	var half_width: float = 0.0
	var half_height: float = 0.0
	for corner: int in range(8):
		var offset: Vector3 = box.get_endpoint(corner) - centre
		half_width = maxf(half_width, absf(offset.dot(right)))
		half_height = maxf(half_height, absf(offset.dot(up)))
	camera.size = 2.0 * maxf(half_width, half_height) * MARGIN
	camera.near = 1.0
	camera.far = 100.0
