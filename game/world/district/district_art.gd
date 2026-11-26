extends RefCounted
## The approved high-detail building and vehicle models (1.12, the district handoff's
## artpreview/art and scale02/assets_fix), finished with their architectural surfaces and drawn at
## the district's metric scale (district_plan.gd). From the handoff's region_assets.gd, finishes.gd
## and crop_site.gd. The reviewed buildings face -z and the vehicles +z in their own meshes; the
## nodes made here face +z, as the game's models do. Widths follow revision 06 (1.3 times the
## models' own); heights keep the models' own metres, as the approved scene draws them.

const DistrictIO = preload("res://world/district/district_io.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")

const DIR: String = "res://assets/district/art/"
const VEHICLE_LENGTH_M: Dictionary = {"bus": 12.12, "truck": 10.105, "van": 6.155}
## Five kinds whose site platforms the approved revision cropped, pivots and sizes unchanged.
const CROPPED: Array[String] = ["crew_quarters", "habitat", "lab", "clinic", "apartment"]
const ROLE: Dictionary = {
	"paint": 0,
	"wall": 1,
	"roof": 2,
	"door": 3,
	"roof_metal": 4,
	"metal": 5,
	"glass": 6,
	"salon_glass": 7,
	"window_warm": 8,
	"window_cool": 8,
	"window_dim": 8,
	"rubber": 10,
	"accent": 11,
	"skirt": 12,
	"dark": 13,
	"rim": 14
}
const BASES: Dictionary = {
	"paint": ["859596", .51, .22],
	"wall": ["929b91", .63, .14],
	"door": ["647876", .56, .26],
	"roof": ["78857d", .66, .21],
	"roof_metal": ["747e80", .47, .48],
	"metal": ["657278", .43, .53],
	"glass": ["254351", .18, .34],
	"salon_glass": ["28505b", .20, .22],
	"window_warm": ["534f45", .23, .20],
	"window_dim": ["2e4249", .21, .27],
	"window_cool": ["355763", .19, .31],
	"rubber": ["262726", .84, .01],
	"accent": ["a07d51", .54, .24],
	"skirt": ["45504e", .61, .22],
	"dark": ["39474a", .58, .30],
	"rim": ["98a5a4", .38, .65]
}
const PAINT: Dictionary = {
	"vehicle_bus": "7a9d92",
	"vehicle_truck": "ac7a54",
	"vehicle_van": "adbaae",
	"habitat": "8d9d91",
	"commerce": "ada08a",
	"apartment": "a29a8e",
	"clinic": "9aaea6",
	"lab": "82969d",
	"school": "b0a188",
	"crew_quarters": "929f8e",
	"processor": "889698",
	"depot": "8b9589",
	"power": "8a9c99"
}
const ROOF: Dictionary = {
	"habitat": "798479",
	"commerce": "858781",
	"apartment": "7b827d",
	"clinic": "778a83",
	"lab": "6e858b",
	"school": "867d71",
	"crew_quarters": "788378"
}
## Window glow: colour and strength lit, as the approved dusk shows an occupied town.
const GLOW: Dictionary = {
	"window_warm": ["e8b17b", .30],
	"window_dim": ["b38968", .025],
	"window_cool": ["8bacbc", .15],
	"salon_glass": ["97b2a8", .047]
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _units: Dictionary = {}
static var _shader: Shader
static var _patina: Texture2D


static func has_model(kind: String) -> bool:
	return DistrictPlan.REVIEWED_M.has(kind) and _mesh(kind) != null


## A building of a reviewed kind at its metric size, front to +z, standing on its local origin.
## `lit` lights its windows (an occupied home after dark); `cropped` takes the approved cropped
## platform where there is one.
static func building(kind: String, lit: bool) -> Node3D:
	var mesh: ArrayMesh = _mesh(kind)
	if mesh == null:
		return null
	var holder := Node3D.new()
	holder.name = "Reviewed_" + kind
	var item := MeshInstance3D.new()
	item.mesh = mesh
	var bounds: AABB = mesh.get_aabb()
	var widest: float = maxf(bounds.size.x, bounds.size.z)
	var width: float = maxf(DistrictPlan.footprint(kind).x, DistrictPlan.footprint(kind).y)
	if kind in DistrictPlan.REVIEWED_LONGEST:
		width = float(DistrictPlan.REVIEWED_LONGEST[kind]) * DistrictPlan.DISTRICT_SCALE
		width *= DistrictPlan.UNIT
	var factor: float = width / maxf(widest, 0.0001)
	# Revision 06 widened the town, not the buildings' storeys.
	item.scale = Vector3(factor, factor / DistrictPlan.DISTRICT_SCALE, factor)
	item.rotation.y = PI
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	item.position = -(item.basis * pivot)
	_finish(item, kind, lit)
	if kind in CROPPED:
		_crop(item, kind)
	holder.add_child(item)
	return holder


## A vehicle of `kind` (bus, truck, van) at its metric length, front to +z, wheels on its origin.
static func vehicle(kind: String) -> Node3D:
	var id: String = "vehicle_" + kind
	var mesh: ArrayMesh = _mesh(id)
	if mesh == null:
		return null
	var holder := Node3D.new()
	holder.name = "Reviewed_" + id
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds: AABB = mesh.get_aabb()
	var length: float = float(VEHICLE_LENGTH_M.get(kind, 6.0)) * DistrictPlan.UNIT
	var factor: float = length / maxf(bounds.size.z, 0.0001)
	item.scale = Vector3.ONE * factor
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	item.position = -(item.basis * pivot)
	_finish(item, id, true)
	holder.add_child(item)
	return holder


static func _mesh(id: String) -> ArrayMesh:
	if not _meshes.has(id):
		var path: String = DIR + "meshes/" + id + ".res"
		_meshes[id] = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	return _meshes[id]


static func _crop(item: MeshInstance3D, kind: String) -> void:
	var key: String = "cropped/" + kind
	if not _meshes.has(key):
		var path: String = DIR + "cropped/" + kind + ".res"
		_meshes[key] = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	var replacement: ArrayMesh = _meshes[key]
	if replacement == null:
		return
	var slots: Dictionary = {}
	var previous: ArrayMesh = item.mesh
	for index: int in range(previous.get_surface_count()):
		slots[previous.surface_get_name(index)] = item.get_surface_override_material(index)
	for index: int in range(replacement.get_surface_count()):
		if not slots.has(replacement.surface_get_name(index)):
			return
	item.mesh = replacement
	for index: int in range(replacement.get_surface_count()):
		item.set_surface_override_material(index, slots[replacement.surface_get_name(index)])


static func _finish(item: MeshInstance3D, id: String, lit: bool) -> void:
	for index: int in range(item.mesh.get_surface_count()):
		var slot: String = item.mesh.surface_get_name(index)
		item.set_surface_override_material(index, _material(id, slot, lit))


static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = DistrictIO.texture(DIR + "textures/" + name + "_1k.png")
	return _textures[name]


static func _material(id: String, slot: String, lit: bool) -> Material:
	var cache_id: String = "%s/%s/%s" % [id, slot, "lit" if lit else "dark"]
	if _materials.has(cache_id):
		return _materials[cache_id]
	var made: Material = (
		_finish_material(id, slot, lit) if ROLE.has(slot) else _palette(id, slot, lit)
	)
	_materials[cache_id] = made
	return made


## The architectural surfaces (finishes.gd): a coat, triplanar patina, framed glazing.
static func _finish_material(id: String, slot: String, lit: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = DistrictIO.shader(DIR + "surfaces/architectural.gdshader")
		_patina = DistrictIO.texture(DIR + "surfaces/patina.png")
	if _units.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(DIR + "model_units.json")
		)
		_units = parsed if parsed is Dictionary else {}
	var m := ShaderMaterial.new()
	m.resource_name = id + "/" + slot
	m.shader = _shader
	var spec: Array = BASES[slot]
	var colour: String = spec[0]
	var vehicle: bool = id.begins_with("vehicle_")
	var rough: float = spec[1]
	var metal: float = spec[2]
	if slot in ["paint", "wall"]:
		colour = PAINT.get(id, colour)
	if slot == "door":
		if vehicle:
			colour = PAINT.get(id, colour)
		elif id == "commerce":
			colour = "6d7971"
	if slot == "roof":
		colour = ROOF.get(id, colour)
	if slot == "accent" and vehicle:
		colour = ({"vehicle_bus": "b3a168", "vehicle_truck": "af8347", "vehicle_van": "547b77"}.get(
			id, colour
		))
	if vehicle and slot == "paint":
		rough = .41
		metal = .30
	m.set_shader_parameter("patina", _patina)
	m.set_shader_parameter("coat", Color(colour))
	m.set_shader_parameter("metal_fraction", metal)
	m.set_shader_parameter("micro_roughness", rough)
	m.set_shader_parameter("treatment", ROLE[slot])
	m.set_shader_parameter("automobile", vehicle)
	m.set_shader_parameter("local_to_metres", 1.0 / maxf(float(_units.get(id, 0.1)), .001))
	if GLOW.has(slot):
		m.set_shader_parameter("glow", Color(GLOW[slot][0]))
		m.set_shader_parameter("warmth", float(GLOW[slot][1]) if lit else 0.0)
	return m


## The plain surfaces (region_assets.gd): a palette, concrete and soil textured.
static func _palette(id: String, slot: String, lit: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = id + "/" + slot
	var vehicle: bool = id.begins_with("vehicle_")
	var palette: Dictionary = {
		"paint": ["c0c5be", 0.15, 0.54],
		"dark": ["34444b", 0.26, 0.51],
		"accent": ["af8352", 0.24, 0.45],
		"glass": ["264653", 0.26, 0.19],
		"concrete": ["a6a69b", 0.0, 0.9],
		"wood": ["917559", 0.0, 0.67],
		"soil": ["998b69", 0.0, 0.97],
		"leaf": ["61755b", 0.0, 0.87],
		"metal": ["76858a", 0.63, 0.39],
		"rubber": ["232729", 0.0, 0.71],
		"greenhouse": ["81a7a4", 0.15, 0.20],
		"window_cool": ["415860", 0.30, 0.22],
		"window_warm": ["7c7260", 0.27, 0.23],
		"window_dim": ["304751", 0.28, 0.24],
		"salon_glass": ["42565a", 0.28, 0.20],
		"signal": ["d0bb8b", 0.14, 0.30],
		"taillight": ["b14028", 0.1, 0.26],
		"headlight": ["e5dac1", 0.16, 0.26]
	}
	if id == "vehicle_bus":
		palette.paint = ["9cb3ad", 0.31, 0.34]
		palette.accent = ["d8b76e", 0.25, 0.41]
	elif id == "vehicle_truck":
		palette.paint = ["b89373", 0.23, 0.45]
		palette.accent = ["c59950", 0.27, 0.40]
	elif id == "vehicle_van":
		palette.paint = ["d2d0bf", 0.29, 0.40]
		palette.accent = ["517c80", 0.32, 0.39]
	else:
		var shells: Dictionary = {
			"habitat": "bdc3b7",
			"commerce": "c7bda9",
			"apartment": "c0b7aa",
			"clinic": "c7cec5",
			"lab": "b8c4c8",
			"school": "c6bfab",
			"crew_quarters": "b4bdb7",
			"processor": "a8b1b2",
			"depot": "acb1a6",
			"power": "adb7b4"
		}
		palette.paint[0] = shells.get(id, "b3bcb7")
	var spec: Array = palette.get(slot, palette.paint)
	m.albedo_color = Color(spec[0])
	m.metallic = spec[1]
	m.roughness = spec[2]
	if slot in ["concrete", "soil"]:
		m.albedo_texture = _texture(slot + "_basecolor")
		m.roughness_texture = _texture(slot + "_roughness")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.albedo_color = Color("d4cfc2") if slot == "concrete" else Color.WHITE
	if slot == "greenhouse":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.33
	if vehicle and slot in ["paint", "glass", "salon_glass"]:
		m.clearcoat_enabled = true
		m.clearcoat = 0.34
		m.clearcoat_roughness = 0.31
	var emit: Dictionary = {
		"signal": ["f3c67d", 1.20],
		"headlight": ["ffecd0", 2.55],
		"taillight": ["ff5433", 1.50],
		"window_warm": ["f8ca8b", 0.80],
		"window_dim": ["c2966c", 0.085],
		"window_cool": ["afc8cb", 0.42],
		"salon_glass": ["dcc6a1", 0.32]
	}
	if emit.has(slot) and (lit or vehicle or not slot.begins_with("window")):
		m.emission_enabled = true
		m.emission = Color(emit[slot][0])
		m.emission_energy_multiplier = emit[slot][1]
	return m
