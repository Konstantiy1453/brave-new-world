extends SceneTree
## Needs a real window. Renders every building kind at work in its setting for the construction
## page: the kind's model on a concrete pad, a driveway to a road with kerbs and lane marks, a
## vehicle at the scale the town uses, street lamps with their own small pools of warm light, and
## for working kinds the pipes, tank, conveyor or stockpile that tie them to the ground. The light
## is late afternoon going to dusk, with lit windows; materials are the game's matte slot colours.
## Writes assets/art/facilities/<kind>.webp (lossy) at 616 x 280. Run the import afterwards, with
## mipmaps on and lossy compression (quality 0.82) in each new .import file.
## Options: --out=res://assets/art/facilities --only=kind,kind

const Watchdog = preload("res://tests/support/watchdog.gd")
const Map = preload("res://world/map_view.gd")
const ModelArt = preload("res://world/model_art.gd")
const RULES: String = "res://data/v17/economy.json"
const WIDTH: int = 616
const HEIGHT: int = 280
## Rendered this many times larger, then scaled down: smooth edges without multisampling.
const SUPERSAMPLE: int = 2
const QUALITY: float = 0.82
## From the front right and above; the street is in front (+z), the sun low from the front left.
const VIEW: Vector3 = Vector3(0.66, 0.5, 1.0)
const FOV: float = 26.0
const PIPE_ROLES: Array[String] = [
	"mine", "factory", "water", "power", "scrubber", "harvest", "foodworks", "port", "depot"
]
const TANK_ROLES: Array[String] = ["factory", "water", "foodworks", "scrubber"]
const VAN_CATEGORIES: Array[String] = ["people", "research"]

var options: Dictionary = {"out": "res://assets/art/facilities", "only": ""}
var map: Node3D
var scene_root: Node3D
var materials: Dictionary = {}


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var folder: String = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	map = Map.new()
	root.add_child(map)
	map.set_process(false)
	map.visible = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WIDTH * SUPERSAMPLE, HEIGHT * SUPERSAMPLE)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.positional_shadow_atlas_size = 2048
	root.add_child(viewport)
	_light(viewport)
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.current = true
	viewport.add_child(camera)
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES)).buildings
	var kinds: Array = buildings.keys()
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
		scene_root = Node3D.new()
		viewport.add_child(scene_root)
		var box: AABB = _stage(entry, buildings[kind])
		_frame(camera, box)
		_dusk()
		for _frame_index: int in range(4):
			await process_frame
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(WIDTH, HEIGHT, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		if image.save_webp(folder.path_join(kind + ".webp"), true, QUALITY) == OK:
			written += 1
		scene_root.queue_free()
		await process_frame
	print("FACILITY_VIEWS skipped: %s" % str(skipped))
	print("BAKE_FACILITY_VIEWS_RESULT written=%d skipped=%d" % [written, skipped.size()])
	quit(0)


## Late afternoon: a low warm sun with shadows, a cool sky fill, matte depth haze.
func _light(viewport: SubViewport) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1a2024")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("5d6d78")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("1f262b")
	environment.fog_density = 0.018
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("f1c995")
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-24, -48, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("7d97ad")
	fill.light_energy = 0.22
	fill.rotation_degrees = Vector3(-35, 140, 0)
	viewport.add_child(fill)


## Windows lit and street lamps on, as the map shows them going into the evening.
func _dusk() -> void:
	if map.mats.has("glass_on"):
		map.mats["glass_on"].emission_energy_multiplier = 0.55
	if map.mats.has("lamps"):
		map.mats["lamps"].emission_energy_multiplier = 3.2


## Builds one kind's setting around the origin and returns the box the camera frames.
func _stage(entry: Dictionary, spec: Dictionary) -> AABB:
	var art: MeshInstance3D = ModelArt.instance(
		str(entry.model),
		func(slot: String) -> Material: return map._art_material(slot, entry, true)
	)
	var scale_value: float = float(entry.get("scale", 1.0))
	art.scale = Vector3.ONE * scale_value
	for addon: String in entry.get("addons", []):
		var stage: MeshInstance3D = ModelArt.instance(
			addon, func(slot: String) -> Material: return map._art_material(slot, entry, true)
		)
		if stage != null:
			art.add_child(stage)
	var box: AABB = art.get_aabb()
	for child: Node in art.get_children():
		if child is MeshInstance3D:
			box = box.merge((child as MeshInstance3D).get_aabb())
	box = AABB(box.position * scale_value, box.size * scale_value)
	# The footprint's centre on the origin, the model on the ground.
	art.position = Vector3(-box.get_center().x, 0.0, -box.get_center().z)
	box.position += art.position
	scene_root.add_child(art)
	var half: Vector2 = Vector2(box.size.x, box.size.z) * 0.5
	var category: String = str(spec.get("category", ""))
	var role: String = str(spec.get("role", ""))
	_ground(category)
	var pad_half: Vector2 = half + Vector2(0.45, 0.45)
	_box(Vector3(0, 0.03, 0), Vector3(pad_half.x * 2.0, 0.06, pad_half.y * 2.0), "pad")
	var road_z: float = pad_half.y + 1.35
	_road(road_z, maxf(30.0, half.x * 8.0))
	_box(
		Vector3(half.x * 0.25, 0.035, (pad_half.y + road_z - 0.75) * 0.5),
		Vector3(1.0, 0.05, road_z - 0.75 - pad_half.y + 0.1),
		"pad"
	)
	_vehicle("van" if category in VAN_CATEGORIES else "truck", half.x * 0.55 + 0.4, road_z + 0.35)
	if category not in VAN_CATEGORIES:
		_vehicle("van", -half.x - 1.6, road_z - 0.35, true)
	for x: float in [-half.x - 0.9, half.x + 1.6]:
		_lamp(Vector3(x, 0.0, road_z - 0.95))
	_light_pool(Vector3(half.x * 0.25, 0.7, pad_half.y + 0.2), 0.8, 2.6)
	if role in PIPE_ROLES:
		_pipes(half, role in TANK_ROLES)
	if role == "mine":
		_stockpile(half, str(entry.get("ore", "ore")))
	_neighbours(half)
	return box


## Low sheds and blocks behind and beside it, fading into the haze: the rest of the settlement.
func _neighbours(half: Vector2) -> void:
	var blocks: Array = [
		[Vector3(-half.x - 4.6, 0.0, -half.y - 4.0), Vector3(2.6, 0.7, 2.0)],
		[Vector3(half.x + 4.6, 0.0, -half.y - 5.6), Vector3(2.2, 1.0, 1.8)],
		[Vector3(-1.0, 0.0, -half.y - 8.5), Vector3(3.4, 0.6, 2.0)],
		[Vector3(half.x + 8.5, 0.0, -1.5), Vector3(1.8, 0.6, 2.4)],
	]
	for block: Array in blocks:
		var at: Vector3 = block[0]
		var size: Vector3 = block[1]
		_box(at + Vector3(0, size.y * 0.5, 0), size, "shed")
		_box(at + Vector3(0, size.y + 0.04, 0), Vector3(size.x + 0.1, 0.08, size.z + 0.1), "kerb")


func _ground(category: String) -> void:
	var soils: Dictionary = {"extraction": "3d3730", "food": "343a2d", "great": "34373a"}
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = _material("soil_" + category, Color(soils.get(category, "35393a")))
	ground.position.y = -0.005
	scene_root.add_child(ground)


func _road(z: float, length: float) -> void:
	_box(Vector3(0, 0.025, z), Vector3(length, 0.05, 1.6), "asphalt")
	for side: float in [-0.84, 0.84]:
		_box(Vector3(0, 0.05, z + side), Vector3(length, 0.07, 0.08), "kerb")
	var x: float = -length * 0.5
	while x < length * 0.5:
		_box(Vector3(x, 0.052, z), Vector3(0.55, 0.01, 0.05), "paint")
		x += 1.3


func _vehicle(kind: String, x: float, z: float, back: bool = false) -> void:
	var vehicle: MeshInstance3D = ModelArt.instance(
		"vehicle_" + kind, func(slot: String) -> Material: return map._art_material(slot, {}, true)
	)
	if vehicle == null:
		return
	vehicle.position = Vector3(x, 0.05, z)
	vehicle.rotation.y = -PI * 0.5 if back else PI * 0.5
	scene_root.add_child(vehicle)


func _lamp(at: Vector3) -> void:
	var lamp: MeshInstance3D = ModelArt.instance("street_lamp", map._lamp_slot_material)
	if lamp != null:
		lamp.position = at
		lamp.rotation.y = -PI * 0.5
		scene_root.add_child(lamp)
	_light_pool(at + Vector3(0, 1.55, 0.35), 1.5, 3.4)


## A small warm light: a lamp head or a lit doorway, lighting only what is near it.
func _light_pool(at: Vector3, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffcf8f")
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.position = at
	scene_root.add_child(light)


## A pipe run on low supports from the facility's side, ending at a tank for works that hold fluids.
func _pipes(half: Vector2, tank: bool) -> void:
	var start: float = half.x + 0.3
	var length: float = 3.2
	for offset: float in [-0.35, 0.0]:
		var pipe := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.07
		tube.bottom_radius = 0.07
		tube.height = length
		tube.radial_segments = 10
		pipe.mesh = tube
		pipe.material_override = _material("pipe", Color("6c787e"), 0.5, 0.45)
		pipe.rotation.z = PI * 0.5
		pipe.position = Vector3(start + length * 0.5, 0.32, -half.y * 0.2 + offset)
		scene_root.add_child(pipe)
	var x: float = start + 0.3
	while x < start + length:
		_box(Vector3(x, 0.16, -half.y * 0.2 - 0.17), Vector3(0.1, 0.32, 0.6), "steel")
		x += 0.9
	if tank:
		var vessel := MeshInstance3D.new()
		var drum := CylinderMesh.new()
		drum.top_radius = 0.55
		drum.bottom_radius = 0.55
		drum.height = 1.1
		vessel.mesh = drum
		vessel.material_override = _material("tank", Color("8b9290"), 0.3, 0.6)
		vessel.position = Vector3(start + length + 0.5, 0.55, -half.y * 0.2 - 0.2)
		scene_root.add_child(vessel)


## A mine's ore heap beside it, fed by an inclined conveyor.
func _stockpile(half: Vector2, ore: String) -> void:
	var heap := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.0
	cone.height = 0.8
	cone.radial_segments = 14
	heap.mesh = cone
	heap.material_override = _material(
		"ore_" + ore, Color(str(ModelArt.ORE_COLORS.get(ore, "ac7755"))).darkened(0.25), 0.0, 0.95
	)
	heap.position = Vector3(-half.x - 1.5, 0.4, 0.5)
	scene_root.add_child(heap)
	var belt := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(1.9, 0.08, 0.32)
	belt.mesh = board
	belt.material_override = _material("belt", Color("4a5155"), 0.35, 0.6)
	belt.position = Vector3(-half.x - 0.55, 0.6, 0.5)
	belt.rotation.z = -0.42
	scene_root.add_child(belt)


func _box(at: Vector3, size: Vector3, key: String) -> void:
	var colors: Dictionary = {
		"pad": [Color("5b5f5c"), 0.0, 0.95],
		"asphalt": [Color("202325"), 0.0, 0.9],
		"kerb": [Color("575b58"), 0.0, 0.9],
		"paint": [Color("8f8b78"), 0.0, 0.8],
		"steel": [Color("596267"), 0.4, 0.55],
		"shed": [Color("30353a"), 0.1, 0.92],
	}
	var look: Array = colors[key]
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	block.mesh = mesh
	block.material_override = _material(key, look[0], look[1], look[2])
	block.position = at
	scene_root.add_child(block)


func _material(
	key: String, color: Color, metallic: float = 0.0, roughness: float = 0.95
) -> StandardMaterial3D:
	if not materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		made.metallic = metallic
		made.roughness = roughness
		materials[key] = made
	return materials[key]


## Looks at the facility from `VIEW`, close enough that it fills most of the frame's height, with
## the road in front and its neighbours at the sides.
func _frame(camera: Camera3D, box: AABB) -> void:
	var centre: Vector3 = box.get_center()
	var footprint: float = Vector2(box.size.x, box.size.z).length() * 0.5 + 0.8
	# A tower is looked at higher up and from further back, so most of it shows.
	var tall: bool = box.size.y > footprint * 1.4
	centre.y = box.size.y * (0.42 if tall else 0.3)
	centre.z += 0.7
	var radius: float = maxf(maxf(footprint, box.size.y * (0.72 if tall else 0.6)), 2.4)
	var distance: float = radius / tan(deg_to_rad(FOV * 0.5)) * 0.9
	var direction: Vector3 = VIEW.normalized()
	camera.look_at_from_position(centre + direction * distance, centre, Vector3.UP)
	camera.near = 0.3
	camera.far = distance * 4.0
