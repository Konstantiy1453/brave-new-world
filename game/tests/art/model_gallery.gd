extends SceneTree
## Needs a real window. A labelled contact sheet of every converted model on its pad, seen from the
## front (+z) at the regional camera's angle, so orientation, scale and colours can be checked.
## Options: --out=res://../evidence/v17/art/gallery --size=1920x1080 --page=0

const Watchdog = preload("res://tests/support/watchdog.gd")
const Map = preload("res://world/map_view.gd")
const ModelArt = preload("res://world/model_art.gd")
const COLUMNS: int = 8
const ROWS: int = 4
const SPACING: float = 6.5

var options: Dictionary = {"out": "res://../evidence/v17/art/gallery", "size": "1920x1080"}


func _initialize() -> void:
	Watchdog.arm(self, 300.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	var folder: String = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	var map: Node3D = Map.new()
	root.add_child(map)
	map.set_process(false)
	var ids: Array = ModelArt.registry().models.keys()
	ids.sort()
	var per_page: int = COLUMNS * ROWS
	var pages: int = ceili(float(ids.size()) / per_page)
	for page: int in range(pages):
		var stage := Node3D.new()
		root.add_child(stage)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(COLUMNS * SPACING + 4, ROWS * SPACING + 4)
		ground.mesh = plane
		ground.material_override = map._mat("gallery_ground", Color("5d6b5a"), 0.0, 1.0)
		stage.add_child(ground)
		for index: int in range(per_page):
			var at: int = page * per_page + index
			if at >= ids.size():
				break
			var id: String = ids[at]
			var spot := Vector3(
				(index % COLUMNS - (COLUMNS - 1) * 0.5) * SPACING,
				0.0,
				(index / COLUMNS - (ROWS - 1) * 0.5) * SPACING
			)
			var pad := MeshInstance3D.new()
			pad.mesh = map._art_base(true)
			pad.position = spot
			stage.add_child(pad)
			var art: MeshInstance3D = ModelArt.instance(
				id, func(slot: String) -> Material: return map._art_material(slot, {}, true)
			)
			if art != null:
				art.position = spot + Vector3(0, 0.08, 0)
				stage.add_child(art)
			var label := Label3D.new()
			label.text = id
			label.font_size = 40
			label.pixel_size = 0.012
			label.position = spot + Vector3(0, 0.05, 2.9)
			label.rotation_degrees.x = -90
			label.modulate = Color("f3e6c4")
			label.outline_size = 8
			stage.add_child(label)
		map.camera.position = Vector3(0, 30, 34)
		map.camera.look_at(Vector3(0, 0, 1.5), Vector3.UP)
		map.camera.fov = 43
		map.camera.h_offset = 0
		map.sun_light.rotation_degrees = Vector3(-50, -30, 0)
		for _frame: int in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s/gallery_%d.png" % [folder, page]
		root.get_texture().get_image().save_png(path)
		print("GALLERY ", path)
		stage.queue_free()
		await process_frame
	print("MODEL_GALLERY_RESULT models=%d pages=%d" % [ids.size(), pages])
	quit(0)
