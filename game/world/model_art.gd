extends RefCounted
## The converted 3ds Max models: the registry in data/v17/models.json, the meshes it names and the
## palette their surfaces are drawn with. Each surface of a model is one colour slot; the map gives
## every slot a material, so one mesh serves several building kinds with their own tints.
## tests/art/convert_models.gd writes the registry and the meshes.

const REGISTRY: String = "res://data/v17/models.json"
const SLOT_COLORS: Dictionary = {
	"shell": "bec9cb",
	"dark": "354954",
	"metal": "73818a",
	"gold": "c7a36b",
	"roof": "7f909b",
	"concrete": "8d918c",
	"glass": "204e62",
	"green": "719650",
	"ore": "ac7755",
	"water": "2e6c7d",
}
const SLOT_FINISH: Dictionary = {
	"shell": [0.35, 0.55],
	"dark": [0.55, 0.42],
	"metal": [0.6, 0.4],
	"gold": [0.4, 0.5],
	"roof": [0.3, 0.6],
	"concrete": [0.05, 0.92],
	"glass": [0.55, 0.16],
	"green": [0.0, 0.88],
	"ore": [0.15, 0.85],
	"water": [0.2, 0.12],
}
const ORE_COLORS: Dictionary = {"ore": "ac7755", "copper": "ba9c57", "crystal": "7ba0bd"}

static var _registry: Dictionary = {}
static var _meshes: Dictionary = {}
static var _missing: Dictionary = {}


static func registry() -> Dictionary:
	if _registry.is_empty():
		_registry = {"models": {}, "kinds": {}}
		if FileAccess.file_exists(REGISTRY):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
			if parsed is Dictionary:
				_registry = parsed
	return _registry


## How a building kind is drawn: {"model", optional "shell", "ore", "scale"}. Empty: procedural.
static func kind_entry(kind: String) -> Dictionary:
	var entry: Dictionary = registry().get("kinds", {}).get(kind, {})
	if entry.is_empty() or mesh(str(entry.get("model", ""))) == null:
		return {}
	return entry


## A model by id, loaded once. Null, with one warning per id, when it is missing.
static func mesh(id: String) -> ArrayMesh:
	if id == "":
		return null
	if _meshes.has(id):
		return _meshes[id]
	var info: Dictionary = registry().get("models", {}).get(id, {})
	var path: String = str(info.get("file", ""))
	var loaded: ArrayMesh = null
	if path != "" and ResourceLoader.exists(path):
		loaded = load(path) as ArrayMesh
	if loaded == null and not _missing.has(id):
		_missing[id] = true
		push_warning("model art missing, drawing procedural: " + id)
	_meshes[id] = loaded
	return loaded


static func model_size(id: String) -> Vector3:
	var size: Array = registry().get("models", {}).get(id, {}).get("size", [4.0, 2.0, 4.0])
	return Vector3(float(size[0]), float(size[1]), float(size[2]))


## A node drawing one model, every surface with its slot's material from `material_for`.
static func instance(id: String, material_for: Callable) -> MeshInstance3D:
	var model: ArrayMesh = mesh(id)
	if model == null:
		return null
	var node := MeshInstance3D.new()
	node.mesh = model
	for index: int in range(model.get_surface_count()):
		var material: Material = material_for.call(model.surface_get_name(index))
		if material != null:
			node.set_surface_override_material(index, material)
	return node


## How far below its ground datum a model reaches, in game units (zero or negative).
static func lowest(id: String) -> float:
	return float(registry().get("models", {}).get(id, {}).get("lowest", 0.0))


static func slot_color(slot: String, entry: Dictionary) -> Color:
	if slot == "shell" and entry.has("shell"):
		return Color(str(entry.shell))
	if slot == "ore" and entry.has("ore"):
		return Color(str(ORE_COLORS.get(str(entry.ore), SLOT_COLORS.ore)))
	return Color(str(SLOT_COLORS.get(slot, SLOT_COLORS.shell)))
