extends SceneTree
## 1.12: Boulder 01's details side by side at close range, under the district's evening light: the
## approved 56,540-triangle scan, the 12,000-triangle play mesh, the 2,000-triangle field mesh and
## the 220-triangle chip mesh, left to right, each 1.8 m wide on a soil patch, seen from 8 m
## (`close.png`), with their triangle counts (`report.json`).
##   xvfb-run -a godot --path game --rendering-driver opengl3 --script
##     res://tests/art/capture_boulder_lods.gd -- --out=<folder> [--size=1600x900]

const DistrictNature = preload("res://world/district/district_nature.gd")
const DETAILS: Array[String] = ["near", "near_game", "field", "chip"]
const WIDTH_M: float = 1.8

var options: Dictionary = {"out": "user://boulder_lods", "size": "1600x900"}
var report: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	var folder: String = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	var scene := Node3D.new()
	root.add_child(scene)
	_light(scene)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("6b6146")
	soil.roughness = 0.95
	ground.material_override = soil
	scene.add_child(ground)
	var stone: ShaderMaterial = DistrictNature._stone("boulder_01")
	for index: int in range(DETAILS.size()):
		var mesh: ArrayMesh = DistrictNature._rock_mesh("boulder_01", DETAILS[index])
		var rock := MeshInstance3D.new()
		rock.mesh = mesh
		rock.material_override = stone
		rock.position = Vector3((index - 1.5) * 2.4, -0.12, 0.0)
		rock.rotation.y = -1.12
		rock.scale = Vector3.ONE * WIDTH_M
		scene.add_child(rock)
		report[DETAILS[index]] = {"triangles": _triangles(mesh)}
	var camera := Camera3D.new()
	camera.fov = 39.0
	scene.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(0.0, 2.2, 7.6), Vector3(0.0, 0.5, 0.0), Vector3.UP)
	await _shot(folder + "/close.png")
	print("BOULDER_LODS ", JSON.stringify(report))
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit(0)


func _light(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a9a5ad")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9c8c2")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.12
	environment.tonemap_white = 4.0
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffce9e")
	sun.light_energy = 0.96
	sun.shadow_enabled = true
	scene.add_child(sun)
	sun.look_at_from_position(Vector3(-3.0, 1.1, 9.0), Vector3.ZERO, Vector3.UP)


func _shot(path: String) -> void:
	for _frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


static func _triangles(mesh: ArrayMesh) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
