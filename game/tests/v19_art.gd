extends SceneTree
## 1.9 plan B7: the converted models keep to their budgets. Headless; reads the registry
## (data/v17/models.json), the meshes it names and the recipes (tests/art/model_recipes.json). A
## recipe's `exceptions` lets a model off one check, with the reason (DECISIONS.md). The converter's
## repeatability (two runs byte-identical) needs the art release and is checked when converting.

const Watchdog = preload("res://tests/support/watchdog.gd")
const ModelArt = preload("res://world/model_art.gd")
const RULES: String = "res://data/v17/economy.json"
const RECIPES: String = "res://tests/art/model_recipes.json"
const MODELS_DIR: String = "res://assets/models"
const FOLDER_LIMIT_BYTES: int = 12 * 1024 * 1024
const FOOTPRINT: float = 4.2
const GREAT_FOOTPRINT: float = 5.0
## How far a model may reach below its ground datum; an open pit is raised by its depth and stands
## in a retaining wall as tall (region_view.gd), so it may go deeper.
const LOWEST: float = -0.7
const PIT_LOWEST: float = -1.5
## Levels of detail in all, the finest included, the plan asks for on a model's heaviest surface.
const WANTED_LEVELS: int = 3
## Registry sizes are rounded to the centimetre.
const SIZE_SLACK: float = 0.02

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


## A check the recipe lets the model off is reported, not failed.
func check_unless(excused: Dictionary, key: String, ok: bool, label: String) -> void:
	if not ok and excused.has(key):
		print("EXCUSED %s (%s)" % [label, str(excused[key])])
		return
	check(ok, label)


func run() -> void:
	var registry: Dictionary = ModelArt.registry()
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECIPES))
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES)).buildings
	_kinds(registry, buildings)
	check(
		_sorted(registry.models.keys()) == _sorted(recipes.models.keys()),
		"every recipe has a converted model and every model a recipe"
	)
	var pits: Dictionary = {}
	for kind: String in registry.kinds:
		if bool(registry.kinds[kind].get("pit", false)):
			pits[str(registry.kinds[kind].model)] = true
	for id: String in _sorted(registry.models.keys()):
		_model(id, registry.models[id], recipes.models.get(id, {}), recipes.parameters, pits)
	_folder()
	print("V19_ART_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


## Every building kind is drawn by a converted model, or procedurally on purpose.
func _kinds(registry: Dictionary, buildings: Dictionary) -> void:
	var kinds: Array = buildings.keys()
	kinds.append("service")
	for kind: String in _sorted(kinds):
		var entry: Dictionary = registry.kinds.get(kind, {})
		var model: String = str(entry.get("model", ""))
		check(
			model == "procedural" or registry.models.has(model),
			"%s resolves to a model (%s)" % [kind, model]
		)
		# Its own construction state and a great work's stages or levels, when it has them.
		var extra: Array = entry.get("addons", []).duplicate()
		if entry.has("construction"):
			extra.append(str(entry.construction))
		for other: String in extra:
			check(registry.models.has(other), "%s: %s is converted" % [kind, other])


func _model(
	id: String, info: Dictionary, recipe: Dictionary, params: Dictionary, pits: Dictionary
) -> void:
	var excused: Dictionary = recipe.get("exceptions", {})
	var mesh: ArrayMesh = load(str(info.file)) as ArrayMesh
	check(mesh != null, "%s loads from %s" % [id, str(info.file)])
	if mesh == null:
		return
	var great: bool = bool(recipe.get("great", false))
	# The recipe's own target, never above the plan's 4,500 (great works 9,000).
	var plan_limit: int = int(params.great_target if great else params.target)
	var budget: int = mini(int(recipe.get("target", plan_limit)), plan_limit)
	var triangles: int = 0
	var heaviest: int = 0
	var names: Array = []
	for surface: int in range(mesh.get_surface_count()):
		var count: int = mesh.surface_get_array_index_len(surface) / 3
		if count > mesh.surface_get_array_index_len(heaviest) / 3:
			heaviest = surface
		triangles += count
		names.append(mesh.surface_get_name(surface))
	check(triangles == int(info.triangles), "%s: the registry counts its triangles" % id)
	check_unless(
		excused,
		"triangles",
		triangles <= budget,
		"%s keeps to %d triangles (%d)" % [id, budget, triangles]
	)
	var slots: Array = ModelArt.SLOT_COLORS.keys()
	var known: bool = true
	for name: String in names:
		known = known and name in slots and names.count(name) == 1
	check(known, "%s: one surface per colour slot, all known (%s)" % [id, str(names)])
	# Levels of detail are reported, not asserted: the engine's simplifier stops on sharp-edged kit
	# geometry, so many models have few coarser levels (DECISIONS.md).
	var levels: int = (
		1
		+ (
			(RenderingServer.mesh_get_surface(mesh.get_rid(), heaviest).get("lods", []) as Array)
			. size()
		)
	)
	if levels < WANTED_LEVELS:
		print("INFO %s: %d levels of detail on its heaviest surface" % [id, levels])
	var box: AABB = mesh.get_aabb()
	var size: Array = info.size
	check(
		(
			absf(box.size.x - float(size[0])) <= SIZE_SLACK
			and absf(box.size.y - float(size[1])) <= SIZE_SLACK
			and absf(box.size.z - float(size[2])) <= SIZE_SLACK
		),
		"%s: the registry has its size" % id
	)
	# A recipe that sets its own fit is sized on purpose; one that sets a scale is a kit piece.
	if not recipe.has("scale"):
		var limit: float = float(recipe.get("fit", GREAT_FOOTPRINT if great else FOOTPRINT))
		check_unless(
			excused,
			"footprint",
			maxf(box.size.x, box.size.z) <= limit + SIZE_SLACK,
			"%s: footprint within %.1f (%.2f)" % [id, limit, maxf(box.size.x, box.size.z)]
		)
	var floor_limit: float = PIT_LOWEST if pits.has(id) else LOWEST
	# A stage or level (a recipe with `include`) stands on its base model, not on the ground.
	if not recipe.has("include"):
		check_unless(
			excused,
			"datum",
			box.position.y <= SIZE_SLACK,
			"%s stands on its ground datum (%.2f)" % [id, box.position.y]
		)
	check_unless(
		excused,
		"lowest",
		box.position.y >= floor_limit - SIZE_SLACK,
		"%s reaches at most %.1f below ground (%.2f)" % [id, -floor_limit, box.position.y]
	)


func _folder() -> void:
	var total: int = 0
	var directory := DirAccess.open(MODELS_DIR)
	for file: String in directory.get_files():
		if file.ends_with(".res"):
			total += FileAccess.get_file_as_bytes(MODELS_DIR + "/" + file).size()
	check(
		total <= FOLDER_LIMIT_BYTES,
		(
			"assets/models holds %.1f MB (at most %.0f)"
			% [total / 1048576.0, FOLDER_LIMIT_BYTES / 1048576.0]
		)
	)


static func _sorted(values: Array) -> Array:
	var copy: Array = values.duplicate()
	copy.sort()
	return copy
