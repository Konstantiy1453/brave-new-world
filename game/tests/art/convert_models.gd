extends SceneTree
## Converts the 3ds Max exchange FBX files into the game's runtime meshes.
##   godot --headless --path game --script res://tests/art/convert_models.gd -- --source=<dir>
## <dir> holds `art_reserve/` as unpacked from the art release. Options: --only=id,id
## Reads tests/art/model_recipes.json; writes assets/models/<id>.res (one surface per colour slot,
## with levels of detail), data/v17/models.json (the registry the map reads) and a report in
## evidence/v17/art. The sources are only read.

const Watchdog = preload("res://tests/support/watchdog.gd")
const RECIPES: String = "res://tests/art/model_recipes.json"
const OUT_DIR: String = "res://assets/models"
const REGISTRY: String = "res://data/v17/models.json"
const REPORT_DIR: String = "res://../evidence/v17/art"

var recipes: Dictionary = {}
var params: Dictionary = {}
var slot_rules: Array = []
var drop_words: Array = []
var report: Dictionary = {"models": {}, "failures": []}


func _initialize() -> void:
	Watchdog.arm(self, 3600.0)
	call_deferred("run")


func run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	if not options.has("source"):
		push_error("convert_models: --source=<folder holding art_reserve> is required")
		quit(2)
		return
	recipes = JSON.parse_string(FileAccess.get_file_as_string(RECIPES))
	params = recipes.parameters
	slot_rules = recipes.slots
	drop_words = recipes.drop
	var only: Array = []
	if options.has("only"):
		only = Array(str(options.only).split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var registry: Dictionary = _read_registry()
	var ids: Array = recipes.models.keys()
	ids.sort()
	for id: String in ids:
		if not only.is_empty() and not only.has(id):
			continue
		var started: int = Time.get_ticks_msec()
		var entry: Dictionary = _convert(id, recipes.models[id], str(options.source))
		if entry.is_empty():
			continue
		entry.seconds = (Time.get_ticks_msec() - started) / 1000.0
		registry.models[id] = entry
		print(
			(
				"CONVERTED %s tris=%d size=%s parts=%d dropped=%d %.1fs"
				% [
					id,
					int(entry.triangles),
					str(entry.size),
					int(entry.parts_kept),
					int(entry.parts_dropped),
					float(entry.seconds)
				]
			)
		)
	registry.kinds = recipes.kinds
	var file := FileAccess.open(REGISTRY, FileAccess.WRITE)
	file.store_string(JSON.stringify(registry, "  ", true))
	file.close()
	_write_report()
	print(
		(
			"CONVERT_MODELS_RESULT models=%d failures=%d"
			% [report.models.size(), report.failures.size()]
		)
	)
	quit(0 if report.failures.is_empty() else 1)


func _read_registry() -> Dictionary:
	var registry: Dictionary = {
		"version": 1,
		"units":
		{
			"size": "game units, x across, y up, z front (+z faces the street)",
			"triangles": "finest level of detail"
		},
		"models": {},
		"kinds": {},
	}
	if FileAccess.file_exists(REGISTRY):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
		if old is Dictionary:
			registry.models = old.get("models", {})
	return registry


func _convert(id: String, recipe: Dictionary, source_root: String) -> Dictionary:
	var path: String = source_root.path_join(str(recipes.packs[recipe.pack])).path_join(
		str(recipe.source) + ".fbx"
	)
	if not FileAccess.file_exists(path):
		report.failures.append("%s: missing %s" % [id, path])
		return {}
	var document := FBXDocument.new()
	var state := FBXState.new()
	if document.append_from_file(path, state) != OK:
		report.failures.append("%s: cannot read %s" % [id, path])
		return {}
	var scene: Node = document.generate_scene(state)
	var parts: Array = []
	_collect(scene, Transform3D.IDENTITY, parts)
	scene.free()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.key) < str(b.key))
	var kept: Array = []
	var dropped: int = 0
	var min_part: float = float(recipe.get("min_part_m", params.min_part_m))
	for part: Dictionary in parts:
		if recipe.has("box") and not _inside(part.aabb, recipe.box):
			continue
		if _dropped(str(part.name).to_lower(), part.aabb, min_part):
			dropped += 1
			continue
		kept.append(part)
	if kept.is_empty():
		report.failures.append("%s: nothing kept" % id)
		return {}
	var whole: AABB = kept[0].aabb
	for part: Dictionary in kept:
		whole = whole.merge(part.aabb)
	var great: bool = bool(recipe.get("great", false))
	var scale: float
	if recipe.has("scale"):
		scale = float(recipe.scale)
	else:
		var fit: float = float(recipe.get("fit", params.great_fit if great else params.fit))
		scale = fit / maxf(whole.size.x, whole.size.z)
	var lift: float = float(recipe.get("vertical", params.vertical))
	var scaling := Vector3(scale, scale * lift, scale)
	# Centred on the footprint; the ground stays at the source's ground datum, so footings and
	# shafts may reach below it.
	var centre := Vector3(whole.get_center().x, 0.0, whole.get_center().z)
	var place := Transform3D(Basis.from_scale(scaling), -centre * scaling)
	var groups: Dictionary = {}
	var slot_parts: Dictionary = {}
	for part: Dictionary in kept:
		var slot: String = _slot(str(part.name).to_lower())
		if not groups.has(slot):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[slot] = tool
			slot_parts[slot] = 0
		(groups[slot] as SurfaceTool).append_from(part.mesh, int(part.surface), place * part.xform)
		slot_parts[slot] = int(slot_parts[slot]) + 1
	var target: int = int(recipe.get("target", params.great_target if great else params.target))
	var mesh: ArrayMesh = _reduce(groups, target)
	var out: String = OUT_DIR + "/" + id + ".res"
	var error: int = ResourceSaver.save(mesh, out, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		report.failures.append("%s: cannot save (%d)" % [id, error])
		return {}
	var triangles: int = 0
	var surfaces: Array = []
	for index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(index)
		triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		surfaces.append(mesh.surface_get_name(index))
	var box: AABB = mesh.get_aabb()
	var entry: Dictionary = {
		"file": out,
		"source": str(recipe.source),
		"source_sha256": FileAccess.get_sha256(path),
		"state": str(recipe.get("state", "")),
		"triangles": triangles,
		"size":
		[snappedf(box.size.x, 0.01), snappedf(box.size.y, 0.01), snappedf(box.size.z, 0.01)],
		"lowest": snappedf(box.position.y, 0.01),
		"units_per_metre": snappedf(scale, 0.0001),
		"surfaces": surfaces,
		"recipe_hash": JSON.stringify(recipe, "", true).sha256_text().substr(0, 16),
		"parts_kept": kept.size(),
		"parts_dropped": dropped,
	}
	report.models[id] = entry.duplicate()
	report.models[id].slot_parts = slot_parts
	return entry


## Merges each slot, then decimates every surface towards its share of the triangle target.
func _reduce(groups: Dictionary, target: int) -> ArrayMesh:
	var slots: Array = groups.keys()
	slots.sort()
	var full := ImporterMesh.new()
	var total: int = 0
	for slot: String in slots:
		var tool: SurfaceTool = groups[slot]
		tool.index()
		var arrays: Array = tool.commit_to_arrays()
		total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		full.add_surface(Mesh.PRIMITIVE_TRIANGLES, _positions_normals(arrays), [], {}, null, slot)
	full.generate_lods(25.0, 60.0, [])
	var share: float = minf(1.0, float(target) / maxf(1.0, float(total)))
	var reduced := ImporterMesh.new()
	for surface: int in range(full.get_surface_count()):
		var arrays: Array = full.get_surface_arrays(surface)
		var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var want: int = maxi(12, int(best.size() / 3 * share))
		for lod: int in range(full.get_surface_lod_count(surface)):
			var candidate: PackedInt32Array = full.get_surface_lod_indices(surface, lod)
			if absi(candidate.size() / 3 - want) < absi(best.size() / 3 - want):
				best = candidate
		reduced.add_surface(
			Mesh.PRIMITIVE_TRIANGLES,
			_compact(arrays, best),
			[],
			{},
			null,
			full.get_surface_name(surface)
		)
	reduced.generate_lods(25.0, 60.0, [])
	return reduced.get_mesh()


func _positions_normals(arrays: Array) -> Array:
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX]
	out[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
	out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	return out


## Keeps only the vertices an index list uses (positions and normals; the palette needs no UVs).
func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var remap: Dictionary = {}
	var order := PackedInt32Array()
	var new_indices := PackedInt32Array()
	for index: int in indices:
		if not remap.has(index):
			remap[index] = order.size()
			order.append(index)
		new_indices.append(int(remap[index]))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var kept_vertices := PackedVector3Array()
	var kept_normals := PackedVector3Array()
	for index: int in order:
		kept_vertices.append(vertices[index])
		kept_normals.append(normals[index])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = kept_vertices
	out[Mesh.ARRAY_NORMAL] = kept_normals
	out[Mesh.ARRAY_INDEX] = new_indices
	return out


func _collect(node: Node, parent: Transform3D, parts: Array) -> void:
	var here: Transform3D = parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in range(mesh.get_surface_count()):
			(
				parts
				. append(
					{
						"name": str(node.name),
						"key": "%s#%d" % [str(node.name), surface],
						"mesh": mesh,
						"surface": surface,
						"xform": here,
						"aabb": here * mesh.get_aabb(),
					}
				)
			)
	for child: Node in node.get_children():
		_collect(child, here, parts)


## Recipe boxes are in Max metres (Z up, front -Y); parts arrive Y up with the front at +Z.
static func _inside(box: AABB, limits: Array) -> bool:
	var centre: Vector3 = box.get_center()
	var source := Vector3(centre.x, -centre.z, centre.y)
	for axis: int in range(3):
		if source[axis] < float(limits[0][axis]) or source[axis] > float(limits[1][axis]):
			return false
	return true


func _dropped(name: String, box: AABB, min_part: float) -> bool:
	for word: String in drop_words:
		if name.contains(word):
			return true
	return box.get_longest_axis_size() < min_part


func _slot(name: String) -> String:
	for rule: Array in slot_rules:
		for word: String in rule[1]:
			if name.contains(word):
				return str(rule[0])
	return "shell"


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var file := FileAccess.open(REPORT_DIR + "/conversion_" + stamp + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
