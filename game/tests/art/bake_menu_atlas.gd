extends SceneTree
## Bakes the geography atlas of the world shown behind the main menu into res://assets/generated,
## so the first planet appears at full detail without waiting for the background refinement.
## Run it with the engine the game ships with (Windows): the atlas key includes floating-point
## generation values, and other builds name the same world differently.
##   & $engine --headless --path game --script res://tests/art/bake_menu_atlas.gd

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const MENU_SEED: int = 260129
const OUT_DIR: String = "res://assets/generated"


func _initialize() -> void:
	Watchdog.arm(self, 300.0)
	call_deferred("run")


func run() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(MENU_SEED, "capital", 1)
	var map: Node3D = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	while map.atlas_refining:
		await process_frame
	var name: String = "world_atlas_" + str(map.current_atlas_key).sha256_text() + ".png"
	var target: String = ProjectSettings.globalize_path(OUT_DIR + "/" + name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for file: String in DirAccess.get_files_at(OUT_DIR):
		if file.begins_with("world_atlas_") and not file.begins_with(name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + file))
	var error: int = DirAccess.copy_absolute(
		ProjectSettings.globalize_path("user://" + name), target
	)
	print("BAKE_MENU_ATLAS ", target, " error=", error)
	quit(0 if error == OK else 1)
