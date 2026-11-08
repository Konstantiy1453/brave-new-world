extends "res://world/building_models.gd"
## The regional terrain, water, nature and colony scene. Terrain is sampled once per load into a
## height field; everything placed on the ground afterwards reads that field. Trees, rocks and
## free plots are instanced; each building kind is one baked mesh.

const Rules = preload("res://simulation/rules.gd")
const Traffic = preload("res://world/traffic.gd")
const ModelArt = preload("res://world/model_art.gd")
## Deck height of the bridge model above its origin, in game units (5.03 m at 0.09 units a metre).
const BRIDGE_DECK: float = 0.45
const BRIDGE_LENGTH: float = 1.98
const SHIP_CYCLE_S: Vector4 = Vector4(26.0, 12.0, 26.0, 14.0)
## A shuttle's day in town seconds: on the pad, lifting, flying out, away, flying back, landing.
const SHUTTLE_CYCLE_S: Array[float] = [16.0, 3.0, 5.0, 14.0, 5.0, 3.0]
const SHUTTLE_HOVER: float = 2.4
const SHUTTLE_CRUISE: float = 9.0
const SHUTTLE_REACH: float = 30.0
## Building roles whose working plants send up steam or smoke.
const SMOKE_ROLES: Array[String] = ["factory", "harvest", "great"]
const SMOKE_KINDS: Array[String] = ["geothermal", "fission", "fusion", "smelter", "processor"]
## Older worlds keep the field they were drawn on, to the vertex; towns on newer ones need more room.
const OLD_FIELD: Dictionary = {
	"res": 86, "width": 57.0, "depth": 47.0, "trees": 160, "gate": 24.0, "rows": 2
}
const WIDE_FIELD: Dictionary = {
	"res": 112, "width": 96.0, "depth": 72.0, "trees": 360, "gate": 44.0, "rows": 3
}
## Rows of triangles between frames: one long block here is what a cold region's worst frame was.
const TRIANGLE_ROWS: int = 24
const EDGE_MARGIN: float = 1.5
const RIVER_STEP: float = 0.5
const PLOT_COLORS: Dictionary = {
	"general": Color("8c9a94"),
	"farm": Color("7f9a5c"),
	"ore": Color("ac7755"),
	"copper": Color("ba9c57"),
	"crystal": Color("7ba0bd"),
}
const LEGACY_SLOTS: Array[Vector2] = [
	Vector2(-3, -3),
	Vector2(3, -3),
	Vector2(-3, 3),
	Vector2(3, 3),
	Vector2(-9, -3),
	Vector2(9, -3),
	Vector2(-9, 3),
	Vector2(9, 3),
	Vector2(-3, -9),
	Vector2(3, -9),
	Vector2(-3, 9),
	Vector2(3, 9),
	Vector2(-9, -9),
	Vector2(9, -9),
	Vector2(-9, 9),
	Vector2(9, 9),
]

var field_res: int = int(OLD_FIELD.res)
var field_width: float = float(OLD_FIELD.width)
var field_depth: float = float(OLD_FIELD.depth)
var half_width: float = field_width / 2.0
var half_depth: float = field_depth / 2.0
var river_steps: int = int(field_depth / RIVER_STEP)
var tree_count: int = int(OLD_FIELD.trees)
var gate_reach: float = float(OLD_FIELD.gate)
var rows_per_frame: int = int(OLD_FIELD.rows)
var height_field := PackedFloat32Array()
var forest_field := PackedFloat32Array()
var field_has_sea: bool = false
var baked_models: Dictionary = {}
var road_tool: SurfaceTool
var road_sections: int = 0
## The living town of the region on show: vehicles, light pools, smoke.
var traffic: Traffic
var region_gates: Array = []
var smoke_emitters: Array = []
var glow_material: ShaderMaterial
## Road sections over water in the town being built, joined into runs: one bridge each.
var bridge_runs: Array = []
## The cargo ship of a coastal town: where it sails from and to, and how far it is in its cycle.
var ship: Node3D
var ship_route: Array = []
## [{"craft": Node3D, "pad": Vector3, "away": Vector3, "clock": float}]
var shuttle_flights: Array = []
var ship_clock: float = 0.0
var _wet_run: Dictionary = {}


## The town grew beside the fixed river in old worlds; in generated worlds plots avoid the rivers.
func _town_offset() -> float:
	if Geo.is_generated(str(world.version)):
		return 0.0
	return 12.0 if world.regions[selected_region].river else 0.0


func _sample_ground(x: float, z: float) -> float:
	var ll := _local_coordinate(x, z)
	var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	return _ground_from_geo(x, z, g, ll)


func _ground(x: float, z: float) -> float:
	if height_field.size() != (field_res + 1) * (field_res + 1):
		return _sample_ground(x, z)
	var fx: float = clampf((x / field_width + 0.5) * field_res, 0.0, field_res - 0.001)
	var fz: float = clampf((z / field_depth + 0.5) * field_res, 0.0, field_res - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - ix
	var tz: float = fz - iz
	var row: int = iz * (field_res + 1) + ix
	var next: int = row + field_res + 1
	return lerpf(
		lerpf(height_field[row], height_field[row + 1], tx),
		lerpf(height_field[next], height_field[next + 1], tx),
		tz
	)


func _ground_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	var reg: Dictionary = world.regions[selected_region]
	if not bool(g.land):
		return (
			-1.0 + float(g.height) * 30.0
			if str(world.version) == "CC-GEO-1.4"
			else (float(g.height) - region_ground) * 30.0
		)
	var detail: float = noise.get_noise_2d(x * .65, z * .65) * .33
	var raw: float = (float(g.height) - region_ground) * 30.0 + detail
	# Planned development terraces blend smoothly into the actual regional relief.
	var town_center := Vector2(_town_offset(), 0)
	var d: float = Vector2(x, z).distance_to(town_center)
	var blend: float = smoothstep(9.0, 18.0, d)
	var height: float = lerpf(.25, raw, blend)
	if reg.river and str(world.version) == "CC-GEO-1.4":
		var river_x: float = (Geo.river_lon(ll.x) - float(reg.lon)) * 4.0
		var river_dist: float = absf(x - river_x)
		if river_dist < 2.8:
			height = lerpf(-.55, height, smoothstep(.9, 2.8, river_dist))
	elif str(world.version) != "CC-GEO-1.4":
		var p := Vector2(x, z)
		for segment in local_river_segments:
			var a: Vector2 = segment.a
			var b: Vector2 = segment.b
			var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
			var distance: float = p.distance_to(a.lerp(b, t))
			var width: float = segment.width
			if distance < width * 2:
				var water: float = lerpf(segment.ya, segment.yb, t)
				height = lerpf(water - .28, height, smoothstep(width * .72, width * 2, distance))
		for lake in local_lakes:
			var distance: float = p.distance_to(lake.center)
			if distance < lake.radius * 1.25:
				height = lerpf(
					lake.height - .4,
					height,
					smoothstep(lake.radius * .8, lake.radius * 1.25, distance)
				)
	return height


func _water_height_at(x: float, z: float, margin: float = 1.0) -> float:
	var point := Vector2(x, z)
	var result: float = -INF
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var t: float = clampf((point - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
		if point.distance_to(a.lerp(b, t)) < float(segment.width) * margin:
			result = maxf(result, lerpf(segment.ya, segment.yb, t))
	for lake in local_lakes:
		if point.distance_to(lake.center) < float(lake.radius) * margin:
			result = maxf(result, lake.height)
	return result


func _local_coordinate(x: float, z: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var lat: float = float(reg.get("canonical_lat", reg.lat)) - z / 4.0
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + x / 4.0
	return Geo.project_coordinate(lat, lon, world)


## Worlds whose generator spreads plots further out get the larger field.
func _fit_field() -> void:
	var overrides: Dictionary = Rules.read("geography").get("overrides", {})
	var rules: Dictionary = overrides.get(str(world.get("version", "")), {})
	var field: Dictionary = WIDE_FIELD if rules.get("plots", {}).has("slot_x") else OLD_FIELD
	field_res = int(field.res)
	field_width = float(field.width)
	field_depth = float(field.depth)
	half_width = field_width / 2.0
	half_depth = field_depth / 2.0
	river_steps = int(field_depth / RIVER_STEP)
	tree_count = int(field.trees)
	gate_reach = float(field.gate)
	rows_per_frame = int(field.rows)


func _point_to_local(lat: float, lon: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var ll: Vector2 = Geo.unproject_coordinate(lat, lon, world)
	return Vector2(
		wrapf(ll.y - float(reg.get("canonical_lon", reg.lon)), -180, 180) * 4.0,
		(float(reg.get("canonical_lat", reg.lat)) - ll.x) * 4.0
	)


func _clip_segment(a: Vector2, b: Vector2) -> Vector2:
	# Liang-Barsky against the exact local ground bounds; returns segment t's.
	var d := b - a
	var low: float = 0
	var high: float = 1
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x + half_width, half_width - a.x, a.y + half_depth, half_depth - a.y]
	for i in range(4):
		if absf(float(p[i])) < .000001:
			if float(q[i]) < 0:
				return Vector2(-1, -1)
		else:
			var t: float = float(q[i]) / float(p[i])
			if float(p[i]) < 0:
				low = maxf(low, t)
			else:
				high = minf(high, t)
			if low > high:
				return Vector2(-1, -1)
	return Vector2(low, high)


func _prepare_local_rivers() -> void:
	local_river_segments.clear()
	local_lakes.clear()
	height_field = PackedFloat32Array()
	var reg: Dictionary = world.regions[selected_region]
	region_ground = float(Geo.sample_geo(reg.lat, reg.lon, noise, str(world.version)).height)
	if str(world.version) == "CC-GEO-1.4":
		return
	var rivers: Array = render_rivers
	for river_index in range(rivers.size()):
		var river = rivers[river_index]
		var coordinates: Array = river.coordinates
		var heights: Array = river.heights
		# Water only runs downhill: each point may not stand above the one upstream of it.
		var water_level: float = INF
		for i in range(coordinates.size() - 1):
			var ca = coordinates[i]
			var cb = coordinates[i + 1]
			var a := _point_to_local(float(ca[0]), float(ca[1]))
			var b := _point_to_local(float(cb[0]), float(cb[1]))
			var ha: float = minf(water_level, _river_height(heights, i, ca))
			var hb: float = minf(ha, _river_height(heights, i + 1, cb))
			water_level = hb
			if a.distance_to(b) > 60:
				continue
			var clip := _clip_segment(a, b)
			if clip.x < 0:
				continue
			var wa: float = (
				.45 + .18 * float(i) / maxi(1, coordinates.size() - 1) + .035 * sin(float(i) * .51)
			)
			var wb: float = (
				.45
				+ .18 * float(i + 1) / maxi(1, coordinates.size() - 1)
				+ .035 * sin(float(i + 1) * .51)
			)
			local_river_segments.append(
				{
					"a": a.lerp(b, clip.x),
					"b": a.lerp(b, clip.y),
					"ya": (lerpf(ha, hb, clip.x) - region_ground) * 30.0 + .04,
					"yb": (lerpf(ha, hb, clip.y) - region_ground) * 30.0 + .04,
					"width": maxf(wa, wb),
					"width_a": wa,
					"width_b": wb,
					"river_index": river_index
				}
			)
	for lake in world.get("lakes", []):
		var center := _point_to_local(float(lake.lat), float(lake.lon))
		var radius: float = float(lake.get("radius_degrees", .45)) * 4.0
		if absf(center.x) > half_width - radius or absf(center.y) > half_depth - radius:
			continue
		var h: float = float(lake.get("height", float(lake.get("elevation", 0)) / 4300.0))
		local_lakes.append(
			{"center": center, "radius": radius, "height": (h - region_ground) * 30.0 + .04}
		)


func _river_height(heights: Array, index: int, ll: Array) -> float:
	if index < heights.size():
		return float(heights[index])
	return float(Geo.sample_geo(float(ll[0]), float(ll[1]), noise, str(world.version)).height)


func _forest_chance(g: Dictionary) -> float:
	if not bool(g.land) or str(g.get("biome", "")) in ["alpine", "desert", "tundra"]:
		return 0.0
	return (
		clampf((float(g.rainfall) - .23) * 1.45, 0, .86) * smoothstep(-2, 10, float(g.temperature))
	)


func _build_terrain(token: int) -> bool:
	var reg: Dictionary = world.regions[selected_region]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = field_res
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	vertices.resize((resolution + 1) * (resolution + 1))
	colors.resize(vertices.size())
	var heights := PackedFloat32Array()
	heights.resize(vertices.size())
	var forests := PackedFloat32Array()
	forests.resize(vertices.size())
	terrain_unique_samples = 0
	field_has_sea = false
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x: float = (float(ix) / resolution - .5) * field_width
			var z: float = (float(iz) / resolution - .5) * field_depth
			var ll := _local_coordinate(x, z)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			terrain_unique_samples += 1
			field_has_sea = field_has_sea or not bool(g.land)
			# The ground shader colours from data, as the globe does: temperature, rainfall,
			# wet banks and height. See world/shaders.gd.
			var data: Color = Shaders.encode(
				float(g.height), float(g.temperature), float(g.rainfall), 0.0
			)
			data.b = 1.0 if is_finite(_water_height_at(x, z, 1.9)) else 0.0
			var index: int = iz * (resolution + 1) + ix
			colors[index] = data
			var height: float = _ground_from_geo(x, z, g, ll)
			heights[index] = height
			forests[index] = _forest_chance(g)
			vertices[index] = Vector3(x, height, z)
		if iz % rows_per_frame == 0:
			region_progress.emit(true, float(iz) / resolution * .9)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	height_field = heights
	forest_field = forests
	# Preserve the original triangles and flat normals; only sampling is shared.
	for iz in range(resolution):
		for ix in range(resolution):
			for corner in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var index: int = (iz + corner.y) * (resolution + 1) + ix + corner.x
				st.set_color(colors[index])
				st.add_vertex(vertices[index])
		if iz % TRIANGLE_ROWS == TRIANGLE_ROWS - 1:
			await get_tree().process_frame
			if token != region_load_token:
				return false

	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = _terrain_material(bool(reg.river))
	surface.add_child(terrain)
	# Geological section of a floating regional cutaway, deliberately no debug grid.
	var border := SurfaceTool.new()
	border.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array = [
		Vector2(-half_width, -half_depth),
		Vector2(half_width, -half_depth),
		Vector2(half_width, half_depth),
		Vector2(-half_width, half_depth)
	]
	for e in range(4):
		for k in range(80):
			var a: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k) / 80)
			var b: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k + 1) / 80)
			var top_a := Vector3(a.x, _ground(a.x, a.y), a.y)
			var top_b := Vector3(b.x, _ground(b.x, b.y), b.y)
			var bottom: float = minf(-4.0, minf(top_a.y, top_b.y) - 3.0)
			for v in [
				top_a,
				Vector3(a.x, bottom, a.y),
				top_b,
				top_b,
				Vector3(a.x, bottom, a.y),
				Vector3(b.x, bottom, b.y)
			]:
				border.add_vertex(v)
	border.generate_normals()
	var skirt := MeshInstance3D.new()
	skirt.mesh = border.commit()
	skirt.material_override = _mat("strata", Color("283a3e"), .15, .95)
	surface.add_child(skirt)
	_build_river()
	_build_sea()
	_build_nature()
	# Thin survey corner lights frame the playable terrain without a grid.
	for x in [-27.5, 27.5]:
		for z in [-22.5, 22.5]:
			var h: float = _ground(x, z)
			_cylinder(
				surface,
				Vector3(x, h + .35, z),
				.065,
				.7,
				_mat("survey", Color("71ccbe"), .3, .6, .8),
				8
			)

	return true


## One ground material per river setting: the uniforms carry the clock, not the region.
func _terrain_material(river: bool) -> ShaderMaterial:
	var key: String = "terrain_ground_" + str(river)
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = Shaders.shader("terrain")
		material.set_shader_parameter("noise3d", Shaders.noise_texture())
		material.set_shader_parameter("river_tint", 1.0 if river else 0.0)
		mats[key] = material
	terrain_shader = mats[key]
	return mats[key]


## One ribbon per river, so a winding channel is one mesh rather than one node per bend.
func _build_river() -> void:
	if str(world.version) == "CC-GEO-1.4":
		if world.regions[selected_region].river:
			_build_legacy_river()
		return
	var ribbons: Dictionary = {}
	for segment in local_river_segments:
		var key: int = int(segment.river_index)
		if not ribbons.has(key):
			var fresh := SurfaceTool.new()
			fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
			ribbons[key] = fresh
		var st: SurfaceTool = ribbons[key]
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var side_a: Vector2 = normal * float(segment.width_a)
		var side_b: Vector2 = normal * float(segment.width_b)
		var aa := Vector3(a.x - side_a.x, segment.ya, a.y - side_a.y)
		var ab := Vector3(a.x + side_a.x, segment.ya, a.y + side_a.y)
		var ba := Vector3(b.x - side_b.x, segment.yb, b.y - side_b.y)
		var bb := Vector3(b.x + side_b.x, segment.yb, b.y + side_b.y)
		for vertex in [aa, ab, ba, ab, bb, ba]:
			st.add_vertex(vertex)
	var material: Material = _water_material("river", Color("224f59"))
	for key: int in ribbons:
		var st: SurfaceTool = ribbons[key]
		st.generate_normals()
		_mesh(surface, st.commit(), Vector3.ZERO, material)
	for lake in local_lakes:
		_cylinder(
			surface,
			Vector3(lake.center.x, lake.height, lake.center.y),
			lake.radius,
			.025,
			_water_material("lake", Color("2e798a")),
			40
		)


func _build_legacy_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reg: Dictionary = world.regions[selected_region]
	for i in range(river_steps):
		var z: float = -half_depth + i * RIVER_STEP
		var nz: float = z + RIVER_STEP
		var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0
		var nx: float = (Geo.river_lon(float(reg.lat) - nz / 4.0) - float(reg.lon)) * 4.0
		for v in [
			Vector3(x - 1.35, -.24, z),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx - 1.35, -.24, nz),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx + 1.35, -.24, nz),
			Vector3(nx - 1.35, -.24, nz)
		]:
			st.add_vertex(v)
	st.generate_normals()
	var river := MeshInstance3D.new()
	river.mesh = st.commit()
	river.material_override = _mat("river", Color("2a818b"), .42, .19)
	surface.add_child(river)
	for lane in [-.7, .25, .85]:
		var points: Array[Vector3] = []
		for i in range(river_steps):
			var z: float = -half_depth + i * RIVER_STEP
			var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0 + lane
			points.append(Vector3(x, -.225, z))
		_line(surface, points, Color(.4, .7, .72, .4), .2)


## One plane at sea level; the terrain itself draws the shoreline where it rises through it.
func _build_sea() -> void:
	if not field_has_sea:
		return
	var sea_height: float = (
		-.72 if str(world.version) == "CC-GEO-1.4" else -region_ground * 30.0 + .04
	)
	var plane := PlaneMesh.new()
	plane.size = Vector2(field_width, field_depth)
	var sea := _mesh(
		surface, plane, Vector3(0, sea_height, 0), _water_material("sea", Color("285e76"))
	)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Moving water: rippling normals over the same colours as before.
func _water_material(kind: String, tint: Color) -> ShaderMaterial:
	var key: String = "water_" + kind
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = Shaders.shader("water")
		material.set_shader_parameter("noise3d", Shaders.noise_texture())
		material.set_shader_parameter("tint", tint)
		mats[key] = material
	return mats[key]


func _instanced(mesh: Mesh, material: Material, placed: Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = placed.size()
	for index: int in range(placed.size()):
		multi.set_instance_transform(index, placed[index][0])
		multi.set_instance_color(index, placed[index][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	return node


func _tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = .055
	trunk.bottom_radius = .055
	trunk.height = .5
	trunk.radial_segments = 6
	var crown := CylinderMesh.new()
	crown.top_radius = 0
	crown.bottom_radius = .35
	crown.height = 1.0
	crown.radial_segments = 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, .25, 0)))
	st.append_from(crown, 0, Transform3D(Basis.IDENTITY, Vector3(0, .65, 0)))
	return st.commit()


func _natural_material(key: String, roughness: float) -> StandardMaterial3D:
	var material := _mat(key, Color.WHITE, 0.0, roughness)
	material.vertex_color_use_as_albedo = true
	return material


func _forest_at(x: float, z: float) -> float:
	var fx: int = clampi(roundi((x / field_width + 0.5) * field_res), 0, field_res)
	var fz: int = clampi(roundi((z / field_depth + 0.5) * field_res), 0, field_res)
	return forest_field[fz * (field_res + 1) + fx]


func _near_plot(x: float, z: float) -> bool:
	for plot: Dictionary in world.regions[selected_region].get("plots", []):
		if absf(float(plot.x) - x) < 2.8 and absf(float(plot.z) - z) < 2.8:
			return true
	return false


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.seed) + selected_region * 173
	var reg: Dictionary = world.regions[selected_region]
	var center := Vector2(_town_offset(), 0)
	var trees: Array = []
	var rocks: Array = []
	for i in range(tree_count):
		var x: float = rng.randf_range(-half_width + EDGE_MARGIN, half_width - EDGE_MARGIN)
		var z: float = rng.randf_range(-half_depth + EDGE_MARGIN, half_depth - EDGE_MARGIN)
		if (
			Vector2(x, z).distance_to(center) < 13.0
			or _ground(x, z) < -.4
			or is_finite(_water_height_at(x, z, 1.8))
			or _near_plot(x, z)
		):
			continue
		var height: float = rng.randf_range(.55, 1.8)
		var turn: float = rng.randf() * TAU
		var base := Vector3(x, _ground(x, z), z)
		if rng.randf() < _forest_at(x, z):
			var scaled := Basis(Vector3.UP, turn).scaled(Vector3(height, height, height))
			trees.append(
				[Transform3D(scaled, base), Color("304f45").lightened(float(i % 4) * .035)]
			)
		else:
			var flat := Basis(Vector3.UP, turn).scaled(Vector3(1.3, .6, 1.0) * height * .38)
			rocks.append([Transform3D(flat, base + Vector3(0, height * .17, 0)), Color("7c8174")])
	# A visible geological exposure marks actual mineral-bearing ground.
	if float(reg.deposits.ore) > 6000:
		for _i: int in range(16):
			var x: float = -16 + rng.randf_range(-3.4, 3.4)
			var z: float = -10 + rng.randf_range(-2.5, 2.5)
			var size: float = rng.randf_range(.4, 1.2)
			var seam := Basis.IDENTITY.scaled(Vector3(1.5, .55, 1.0) * size)
			rocks.append([Transform3D(seam, Vector3(x, _ground(x, z) + .3, z)), Color("9b735a")])
	if not trees.is_empty():
		surface.add_child(_instanced(_tree_mesh(), _natural_material("tree", .9), trees))
	if not rocks.is_empty():
		var pebble := SphereMesh.new()
		pebble.radius = 1.0
		pebble.height = 2.0
		pebble.radial_segments = 6
		pebble.rings = 3
		surface.add_child(_instanced(pebble, _natural_material("rock", .95), rocks))


func _building_signature() -> String:
	for settlement in state.get("settlements", []):
		if int(settlement.region) == selected_region:
			var visible_status: Array = []
			for building in settlement.get("buildings", []):
				(
					visible_status
					. append(
						[
							building.kind,
							building.get("enabled", true),
							building.get("active", false),
							int(building.get("remaining", 0)) > 0,
							int(building.get("plot", -1)),
						]
					)
				)
			var route_state: Array = []
			for road: Dictionary in state.get("roads", []):
				route_state.append(
					[
						int(road.get("a", -1)),
						int(road.get("b", -1)),
						Geo.road_blocked(road, int(state.get("day", 0)))
					]
				)
			return (
				JSON.stringify(visible_status)
				+ JSON.stringify(route_state)
				+ str(settlement.get("base_housing", 0))
			)
	return "unsettled"


## Where a building stands: on its plot, or for hand-built test states on the old town grid.
func _building_spot(index: int, building: Dictionary, offset: float) -> Vector2:
	var plots: Array = world.regions[selected_region].get("plots", [])
	var plot: int = int(building.get("plot", -1))
	if plot >= 0 and plot < plots.size():
		return Vector2(float(plots[plot].x), float(plots[plot].z))
	if index < LEGACY_SLOTS.size():
		return LEGACY_SLOTS[index] + Vector2(offset, 0)
	var extra: int = index - LEGACY_SLOTS.size()
	return Vector2(-9.0 + (extra % 4) * 6.0, -15.0 if extra < 4 else 15.0) + Vector2(offset, 0)


## A building kind as one mesh with one surface per material, built once and shared.
func _baked_model(kind: String, active: bool) -> ArrayMesh:
	var key: String = "%s|%s" % [kind, str(active)]
	if baked_models.has(key):
		return baked_models[key]
	var root := Node3D.new()
	add_child(root)
	# Newer buildings wear the model of the closest older one until they have their own.
	var spec: Dictionary = Rules.read("economy").buildings.get(kind, {})
	_build_facility(root, str(spec.get("model", kind)), active)
	var groups: Dictionary = {}
	_collect_parts(root, Transform3D.IDENTITY, groups)
	remove_child(root)
	root.free()
	var baked := ArrayMesh.new()
	for material: Material in groups:
		var st: SurfaceTool = groups[material]
		st.commit(baked)
		baked.surface_set_material(baked.get_surface_count() - 1, material)
	baked_models[key] = baked
	return baked


func _collect_parts(node: Node3D, parent: Transform3D, groups: Dictionary) -> void:
	var here: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh != null and node.material_override != null:
		var material: Material = node.material_override
		if not groups.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[material] = st
		var tool: SurfaceTool = groups[material]
		tool.append_from(node.mesh, 0, here)
	for child: Node in node.get_children():
		if child is Node3D:
			_collect_parts(child, here, groups)


## Free plots, faintly: what this site still has room for.
func _draw_free_plots(settlement: Dictionary) -> void:
	var taken: Dictionary = {}
	for building: Dictionary in settlement.get("buildings", []):
		taken[int(building.get("plot", -1))] = true
	var placed: Array = []
	var plots: Array = world.regions[selected_region].get("plots", [])
	for index: int in range(plots.size()):
		var plot: Dictionary = plots[index]
		if taken.has(index) or bool(plot.get("hidden", false)):
			continue
		if float(plot.get("reserves", 1.0)) <= 0.0:
			continue
		var color_key: String = str(plot.get("resource", plot.kind))
		var x: float = float(plot.x)
		var z: float = float(plot.z)
		placed.append(
			[
				Transform3D(Basis.IDENTITY, Vector3(x, _ground(x, z) + .06, z)),
				Color(PLOT_COLORS.get(color_key, Color.WHITE), .55)
			]
		)
	if placed.is_empty():
		return
	var disc := CylinderMesh.new()
	disc.top_radius = 1.9
	disc.bottom_radius = 1.9
	disc.height = .03
	disc.radial_segments = 6
	var material := _natural_material("freeplot", 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node: MultiMeshInstance3D = _instanced(disc, material, placed)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	buildings_root.add_child(node)


func _build_colony() -> void:
	if buildings_root != null and is_instance_valid(buildings_root):
		if buildings_root.get_parent() != null:
			buildings_root.get_parent().remove_child(buildings_root)
		buildings_root.queue_free()
	buildings_root = Node3D.new()
	buildings_root.name = "LiveSettlementBuildings"
	surface.add_child(buildings_root)
	var settlement: Dictionary = {}
	for s in state.get("settlements", []):
		if int(s.region) == selected_region:
			settlement = s
	var offset: float = _town_offset()
	if settlement.is_empty():
		# Survey lander is survey equipment, not an operating settlement.
		_lander(buildings_root, Vector3(offset, _ground(offset, 0) + .1, 0))
		_draw_free_plots({})
		return
	road_tool = SurfaceTool.new()
	road_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_sections = 0
	region_gates.clear()
	smoke_emitters.clear()
	var stops: Array = []
	var pools: Array = []
	if int(settlement.get("base_housing", 0)) > 0:
		_build_base_housing(offset, int(settlement.base_housing))
		stops.append({"end": Vector2(offset - 6.0, 0.0), "z": 0.0, "kind": "base", "active": true})
	var roles: Dictionary = Rules.read("economy").buildings
	var buildings: Array = settlement.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var slot: Vector2 = _building_spot(i, b, offset)
		var complete: bool = int(b.get("remaining", b.get("days_left", 0))) <= 0
		var active: bool = b.get("enabled", true) and b.get("active", true) and complete
		var model := MeshInstance3D.new()
		var art: Dictionary = ModelArt.kind_entry(str(b.kind))
		model.mesh = (
			_baked_model(str(b.kind), active)
			if art.is_empty()
			else _art_base(active, _pit_depth(art, complete))
		)
		model.position = Vector3(slot.x, _ground(slot.x, slot.y), slot.y)
		model.set_meta("building_kind", str(b.kind))
		buildings_root.add_child(model)
		if not art.is_empty():
			_dress_building(model, b, art, active, complete, _street_yaw(slot.x, offset))
		elif not complete:
			_construction_frame(model)
		_road(Vector3(offset, 0, slot.y), Vector3(slot.x, 0, slot.y))
		stops.append({"end": slot, "z": slot.y, "kind": str(b.kind), "active": active})
		if active:
			pools.append([model.position, 2.6])
			var role: String = str(roles.get(str(b.kind), {}).get("role", ""))
			if role in SMOKE_ROLES or str(b.kind) in SMOKE_KINDS:
				_add_smoke(model)
	_road(Vector3(offset, 0, -12), Vector3(offset, 0, 12))
	for z in [-10, -5, 0, 5, 10]:
		var p := Vector3(offset + 1.1, _ground(offset + 1.1, z), z)
		pools.append([p, 1.3])
		var lamp: MeshInstance3D = ModelArt.instance("street_lamp", _lamp_slot_material)
		if lamp != null:
			lamp.position = p
			lamp.rotation.y = PI * 0.5
			buildings_root.add_child(lamp)
			continue
		_cylinder(
			buildings_root,
			p + Vector3(0, .8, 0),
			.05,
			1.6,
			_mat("metal", Color("73818a"), .6, .4),
			8
		)
		_box(
			buildings_root,
			p + Vector3(0, 1.6, 0),
			Vector3(.35, .06, .16),
			_mat("lamps", Color("c4eee1"), .2, .4, 1.3)
		)
	_build_outbound_route(offset)
	_draw_free_plots(settlement)
	_finish_roads()
	_build_bridges()
	_build_harbor(settlement, offset)
	_build_light_pools(pools)
	_build_traffic(stops, offset, int(settlement.get("region", 0)))


func _build_base_housing(offset: float, capacity: int) -> void:
	var root := Node3D.new()
	root.name = "LandingLivingCapsules"
	root.set_meta("base_housing", capacity)
	root.position = Vector3(offset - 6.0, _ground(offset - 6.0, 0), 0)
	buildings_root.add_child(root)
	var pods: MeshInstance3D = ModelArt.instance(
		"landing_pods", func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if pods != null:
		_cylinder(root, Vector3(0, -.22, 0), 2.6, .6, _mat("pad", Color("43545a"), .3, .85), 8)
		pods.position.y = .08
		root.add_child(pods)
		_base_housing_label(root, capacity)
		_road(Vector3(offset, 0, 0), Vector3(offset - 6.0, 0, 0))
		return
	var shell := _mat("basehousing", Color("c4b69a"), .45, .55)
	var dark := _mat("darkmetal", Color("354954"), .65, .38)
	var light := _mat("baselight", Color("f1d896"), .3, .4, .45)
	var count: int = 2 if capacity >= 80 else 1
	_cylinder(root, Vector3(0, .1, 0), 1.65, .2, dark, 8)
	for i in range(count):
		var x: float = (float(i) - float(count - 1) * .5) * 1.05
		var capsule := CapsuleMesh.new()
		capsule.radius = .44
		capsule.height = 2.45
		capsule.radial_segments = 16
		capsule.rings = 5
		var pod := _mesh(root, capsule, Vector3(x, .78, 0), shell)
		pod.rotation_degrees.x = 90
		for z in [-.65, 0, .65]:
			_box(root, Vector3(x, 1.20, z), Vector3(.55, .03, .22), dark)
			_box(root, Vector3(x, 1.22, z + .12), Vector3(.57, .02, .025), light)
		for z in [-.85, .85]:
			_box(root, Vector3(x, .32, z), Vector3(.7, .34, .14), dark)
	_box(root, Vector3(0, .37, 1.28), Vector3(1.2, .13, .5), shell)
	_base_housing_label(root, capacity)
	_road(Vector3(offset, 0, 0), Vector3(offset - 6.0, 0, 0))


func _base_housing_label(root: Node3D, capacity: int) -> void:
	var label := Label3D.new()
	label.text = "登陆生活舱 · " + str(capacity) + " 人"
	label.font = label_font
	label.font_size = 36
	label.pixel_size = .009
	label.modulate = Color("e7d3a5")
	label.outline_modulate = Color("091621")
	label.position = Vector3(0, 1.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)


func _build_outbound_route(offset: float) -> void:
	shuttle_flights.clear()
	for route: Dictionary in state.get("roads", []):
		if not bool(route.get("retired", false)):
			_build_road_gate(route, offset)


func _build_road_gate(route: Dictionary, offset: float) -> void:
	var a: int = int(route.get("a", -1))
	var b: int = int(route.get("b", -1))
	if selected_region != a and selected_region != b:
		return
	var destination: int = b if selected_region == a else a
	var to: Dictionary = world.regions[destination]
	var direction := _point_to_local(float(to.lat), float(to.lon)).normalized()
	var coordinates: Array = route.get("coordinates", [])
	if coordinates.size() > 2:
		var adjacent: Array = (
			coordinates[2] if selected_region == a else coordinates[coordinates.size() - 3]
		)
		direction = _point_to_local(float(adjacent[0]), float(adjacent[1])).normalized()
	# The global route is a four-neighbour corridor. Its local gateway follows
	# the dominant outgoing direction and uses the clear central service lane.
	direction = (
		Vector2(signf(direction.x), 0)
		if absf(direction.x) > absf(direction.y)
		else Vector2(0, signf(direction.y))
	)
	var start := Vector2(offset, 0)
	var finish := start + direction * gate_reach
	finish.x = clampf(finish.x, -half_width + 2.0, half_width - 2.0)
	finish.y = clampf(finish.y, -half_depth + 2.0, half_depth - 2.0)
	if str(route.get("variant", "")) == "shuttle":
		_build_shuttle_pad(route, finish, direction, to)
		return
	_road(Vector3(start.x, 0, start.y), Vector3(finish.x, 0, finish.y))
	var day: int = int(state.get("day", 0))
	if not Geo.road_building(route, day) and not Geo.road_blocked(route, day):
		region_gates.append({"end": finish})
	var gate := Vector3(finish.x, _ground(finish.x, finish.y), finish.y)
	var blocked: bool = Geo.road_blocked(route, int(state.get("day", 0)))
	# The gantry spans the road: across it is x when the road runs along z.
	var across_yaw: float = 0.0 if absf(direction.y) > absf(direction.x) else PI * 0.5
	var gantry: MeshInstance3D = ModelArt.instance(
		"route_gate", func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if gantry != null:
		gantry.position = gate
		gantry.rotation.y = across_yaw
		buildings_root.add_child(gantry)
	else:
		var steel := _mat("routegate", Color("bcb28d"), .55, .5)
		for x in [-.85, .85]:
			_tube(buildings_root, gate + Vector3(x, 0, 0), gate + Vector3(x, 2, 0), .09, steel)
		_box(buildings_root, gate + Vector3(0, 2, 0), Vector3(2, .35, .24), steel)
	if blocked and not Geo.road_building(route, int(state.get("day", 0))):
		var closure: MeshInstance3D = ModelArt.instance(
			"road_closure", func(slot: String) -> Material: return _art_material(slot, {}, true)
		)
		if closure != null:
			var near: Vector2 = finish - direction * 2.2
			closure.position = Vector3(near.x, _ground(near.x, near.y) + .02, near.y)
			closure.rotation.y = across_yaw
			buildings_root.add_child(closure)
	var label := Label3D.new()
	var kind: String = "海运 · " if str(route.get("variant", "")) == "sea" else "陆运 · "
	if Geo.road_building(route, int(state.get("day", 0))):
		kind = "在建 · "
		blocked = false
	label.text = (
		("停运 · " if blocked else kind) + str(to.name) + " / " + str(route.get("days", 0)) + "天"
	)
	label.font = label_font
	label.font_size = 42
	label.pixel_size = .012
	label.modulate = Color("ead49d")
	label.outline_modulate = Color("091621")
	label.position = gate + Vector3(0, 2.9, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	buildings_root.add_child(label)


## Service roads follow the height field; the same path crosses channels as a raised bridge.
## All sections of a town go into one mesh.
func _road(a: Vector3, b: Vector3) -> void:
	var count: int = maxi(1, ceili(a.distance_to(b) / 1.6))
	for i in range(count):
		_road_section(a.lerp(b, float(i) / count), a.lerp(b, float(i + 1) / count))


func _road_section(a: Vector3, b: Vector3) -> void:
	_note_bridge(a, b)
	a.y = _ground(a.x, a.z) + .16
	b.y = _ground(b.x, b.z) + .16
	a.y = maxf(a.y, _water_height_at(a.x, a.z, 1.5) + .24)
	b.y = maxf(b.y, _water_height_at(b.x, b.z, 1.5) + .24)
	var along := Vector2(b.x - a.x, b.z - a.z)
	if along.length() < .001:
		return
	var side: Vector2 = along.normalized().orthogonal() * .36
	var aa := Vector3(a.x - side.x, a.y, a.z - side.y)
	var ab := Vector3(a.x + side.x, a.y, a.z + side.y)
	var ba := Vector3(b.x - side.x, b.y, b.z - side.y)
	var bb := Vector3(b.x + side.x, b.y, b.z + side.y)
	for vertex: Vector3 in [aa, ba, ab, ab, ba, bb]:
		road_tool.add_vertex(vertex)
	road_sections += 1


func _finish_roads() -> void:
	if road_sections == 0:
		return
	road_tool.generate_normals()
	var material := _mat("road", Color("3c4848"), .15, .9)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := MeshInstance3D.new()
	mesh.mesh = road_tool.commit()
	mesh.material_override = material
	mesh.name = "ServiceRoads"
	buildings_root.add_child(mesh)


## Joins consecutive road sections over water into one run; a dry section closes the run.
func _note_bridge(a: Vector3, b: Vector3) -> void:
	var middle: Vector3 = a.lerp(b, 0.5)
	var water: float = _water_height_at(middle.x, middle.z, 1.2)
	var continues: bool = not _wet_run.is_empty() and Vector3(_wet_run.end).distance_to(a) < 0.01
	if not is_finite(water):
		if not _wet_run.is_empty():
			bridge_runs.append(_wet_run)
			_wet_run = {}
		return
	if continues:
		_wet_run.end = b
		_wet_run.water = maxf(float(_wet_run.water), water)
	else:
		if not _wet_run.is_empty():
			bridge_runs.append(_wet_run)
		_wet_run = {"start": a, "end": b, "water": water}


## A modelled span over every run of road above a river or lake, stretched to its length.
func _build_bridges() -> void:
	if not _wet_run.is_empty():
		bridge_runs.append(_wet_run)
		_wet_run = {}
	for run: Dictionary in bridge_runs:
		var start: Vector3 = run.start
		var end: Vector3 = run.end
		var along := Vector2(end.x - start.x, end.z - start.z)
		var length: float = along.length() + 1.0
		var span: MeshInstance3D = ModelArt.instance(
			"bridge_span", func(slot: String) -> Material: return _art_material(slot, {}, true)
		)
		if span == null or length < 0.5:
			continue
		var middle: Vector3 = start.lerp(end, 0.5)
		span.position = Vector3(middle.x, float(run.water) + .22 - BRIDGE_DECK, middle.z)
		# The model's span runs along its x axis.
		span.rotation.y = -atan2(along.y, along.x)
		span.scale = Vector3(maxf(length / BRIDGE_LENGTH, 0.6), 1.0, 1.0)
		buildings_root.add_child(span)
	bridge_runs.clear()


## A coastal town with a port or a sea route gets a quay at its nearest shore and a cargo ship
## that sails in, berths and leaves.
func _build_harbor(settlement: Dictionary, offset: float) -> void:
	ship = null
	ship_route.clear()
	if not field_has_sea or not _harbor_wanted(settlement):
		return
	var sea_level: float = -region_ground * 30.0 + .04
	var town := Vector2(offset, 0.0)
	var best: Dictionary = {}
	for step: int in range(24):
		var heading := Vector2.RIGHT.rotated(TAU * float(step) / 24.0)
		var last_land: Vector2 = town
		for reach: int in range(4, int(maxf(half_width, half_depth)) - 2):
			var at: Vector2 = town + heading * float(reach)
			if absf(at.x) > half_width - 3.0 or absf(at.y) > half_depth - 3.0:
				break
			if _ground(at.x, at.y) < sea_level - .1:
				if best.is_empty() or reach < int(best.reach):
					best = {"reach": reach, "shore": last_land, "heading": heading}
				break
			last_land = at
	if best.is_empty():
		return
	var heading: Vector2 = best.heading
	var shore: Vector2 = best.shore
	var quay: MeshInstance3D = ModelArt.instance(
		"harbor", func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if quay == null:
		return
	quay.position = Vector3(shore.x, maxf(_ground(shore.x, shore.y), sea_level) - .05, shore.y)
	# The quay's sea side is the model's -z: turn it to face the open water.
	quay.rotation.y = atan2(-heading.x, -heading.y)
	buildings_root.add_child(quay)
	var vessel: MeshInstance3D = ModelArt.instance(
		"cargo_ship", func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if vessel == null:
		return
	var side := Vector2(-heading.y, heading.x)
	var berth: Vector2 = shore + heading * 2.4 + side * 0.6
	var offing: Vector2 = berth + heading * 30.0 + side * 6.0
	offing.x = clampf(offing.x, -half_width + 3.0, half_width - 3.0)
	offing.y = clampf(offing.y, -half_depth + 3.0, half_depth - 3.0)
	ship_route = [
		Vector3(offing.x, sea_level - .02, offing.y), Vector3(berth.x, sea_level - .02, berth.y)
	]
	ship = vessel
	buildings_root.add_child(vessel)
	_sail(0.0)


func _harbor_wanted(settlement: Dictionary) -> bool:
	for building: Dictionary in settlement.get("buildings", []):
		if str(building.kind) == "port" and int(building.get("remaining", 0)) <= 0:
			return true
	for route: Dictionary in state.get("roads", []):
		if str(route.get("variant", "")) != "sea":
			continue
		if int(route.get("a", -1)) == selected_region or int(route.get("b", -1)) == selected_region:
			return true
	return false


## A shuttle line lands on a lit pad at the edge of town, where the service lane ends. The craft
## is the `shuttle` model once one is delivered, a simple lifting body until then.
func _build_shuttle_pad(
	route: Dictionary, finish: Vector2, direction: Vector2, to: Dictionary
) -> void:
	var day: int = int(state.get("day", 0))
	var spot: Vector2 = _pad_spot(finish, direction)
	var pad := Vector3(spot.x, _ground(spot.x, spot.y), spot.y)
	_cylinder(
		buildings_root, pad + Vector3(0, .04, 0), 1.3, .08, _mat("shuttle_pad", Color("4a575e"))
	)
	_cylinder(
		buildings_root,
		pad + Vector3(0, .085, 0),
		1.0,
		.012,
		_mat("shuttle_mark", Color("e6b45a"), 0.0, .5, .4)
	)
	var light := _mat("shuttle_light", SHUTTLE_COLOR, 0.0, .4, 1.4)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_cylinder(buildings_root, pad + Vector3(corner.x, .16, corner.y), .05, .18, light, 6)
	var building: bool = Geo.road_building(route, day)
	if not building:
		region_gates.append({"end": spot})
		var craft: Node3D = _shuttle_craft()
		buildings_root.add_child(craft)
		var away: Vector2 = spot + direction * SHUTTLE_REACH
		(
			shuttle_flights
			. append(
				{
					"craft": craft,
					"pad": pad + Vector3(0, .12, 0),
					"away": Vector3(away.x, pad.y + SHUTTLE_CRUISE, away.y),
					"clock": float(shuttle_flights.size()) * 17.0,
				}
			)
		)
	var label := Label3D.new()
	label.text = (
		("在建 · " if building else "穿梭机 · ") + str(to.name) + " / " + str(route.get("days", 0)) + "天"
	)
	label.font = label_font
	label.font_size = 42
	label.pixel_size = .012
	label.modulate = Color("ead49d")
	label.outline_modulate = Color("091621")
	label.position = pad + Vector3(0, 2.9, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	buildings_root.add_child(label)
	_fly(0.0)


## Dry, level ground clear of every plot for the pad: from the lane's end back toward town, and
## to either side of it.
func _pad_spot(finish: Vector2, direction: Vector2) -> Vector2:
	var side := Vector2(-direction.y, direction.x)
	for back: int in range(0, 9):
		for across: float in [0.0, 3.5, -3.5, 7.0, -7.0]:
			var at: Vector2 = finish - direction * (1.5 * back) + side * across
			if absf(at.x) > half_width - 2.0 or absf(at.y) > half_depth - 2.0:
				continue
			if _near_plot(at.x, at.y) or _ground(at.x, at.y) < -.4:
				continue
			if is_finite(_water_height_at(at.x, at.y, 1.6)):
				continue
			return at
	return finish


func _shuttle_craft() -> Node3D:
	var modelled: MeshInstance3D = ModelArt.instance(
		"shuttle", func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if modelled != null:
		return modelled
	var craft := Node3D.new()
	var hull := _mat("shuttle_hull", Color("d9dee0"), .3, .45)
	var dark := _mat("shuttle_dark", Color("2f3d45"), .4, .4)
	var glow := _mat("shuttle_glow", SHUTTLE_COLOR, 0.0, .3, 2.0)
	_box(craft, Vector3(0, .22, 0), Vector3(.5, .3, 1.4), hull)
	_box(craft, Vector3(0, .3, -.62), Vector3(.36, .16, .3), dark)
	_box(craft, Vector3(0, .2, .1), Vector3(1.5, .06, .5), hull)
	_box(craft, Vector3(0, .45, .55), Vector3(.06, .3, .3), hull)
	for side: float in [-.62, .62]:
		_cylinder(craft, Vector3(side, .18, .3), .1, .12, glow, 8)
	return craft


## Lifts off, flies out of the field, waits, flies back and lands; `elapsed` is town seconds.
func _fly(elapsed: float) -> void:
	var cycle: float = 0.0
	for part: float in SHUTTLE_CYCLE_S:
		cycle += part
	for flight: Dictionary in shuttle_flights:
		var craft: Node3D = flight.craft
		if craft == null or not is_instance_valid(craft):
			continue
		flight.clock = fposmod(float(flight.clock) + elapsed, cycle)
		var pad: Vector3 = flight.pad
		var hover: Vector3 = pad + Vector3(0, SHUTTLE_HOVER, 0)
		var away: Vector3 = flight.away
		var t: float = float(flight.clock)
		var at: Vector3 = pad
		var facing: Vector3 = Vector3(away.x - pad.x, 0, away.z - pad.z)
		var phase: int = 0
		while phase < SHUTTLE_CYCLE_S.size() - 1 and t >= SHUTTLE_CYCLE_S[phase]:
			t -= SHUTTLE_CYCLE_S[phase]
			phase += 1
		var share: float = smoothstep(0.0, 1.0, t / SHUTTLE_CYCLE_S[phase])
		match phase:
			1:
				at = pad.lerp(hover, share)
			2:
				at = hover.lerp(away, share)
			3:
				at = away
			4:
				at = away.lerp(hover, share)
				facing = -facing
			5:
				at = hover.lerp(pad, share)
				facing = -facing
		craft.visible = phase != 3
		craft.position = at
		if facing.length() > 0.01:
			craft.look_at(at + facing.normalized(), Vector3.UP)


## Sails in, berths, sails out, waits beyond the horizon; `elapsed` is seconds of town time.
func _sail(elapsed: float) -> void:
	if ship == null or not is_instance_valid(ship) or ship_route.size() < 2:
		return
	var cycle: float = SHIP_CYCLE_S.x + SHIP_CYCLE_S.y + SHIP_CYCLE_S.z + SHIP_CYCLE_S.w
	ship_clock = fposmod(ship_clock + elapsed, cycle)
	var offing: Vector3 = ship_route[0]
	var berth: Vector3 = ship_route[1]
	var t: float = ship_clock
	var at: Vector3 = berth
	var facing: Vector3 = berth - offing
	if t < SHIP_CYCLE_S.x:
		at = offing.lerp(berth, smoothstep(0.0, 1.0, t / SHIP_CYCLE_S.x))
	elif t < SHIP_CYCLE_S.x + SHIP_CYCLE_S.y:
		at = berth
	elif t < SHIP_CYCLE_S.x + SHIP_CYCLE_S.y + SHIP_CYCLE_S.z:
		var out: float = (t - SHIP_CYCLE_S.x - SHIP_CYCLE_S.y) / SHIP_CYCLE_S.z
		at = berth.lerp(offing, smoothstep(0.0, 1.0, out))
		facing = offing - berth
	else:
		at = offing
	ship.visible = t < SHIP_CYCLE_S.x + SHIP_CYCLE_S.y + SHIP_CYCLE_S.z
	ship.position = at
	if facing.length() > 0.01:
		ship.look_at(at + facing.normalized(), Vector3.UP)


## Open pits are dug below the ground the terrain draws: they get raised by their depth.
static func _pit_depth(art: Dictionary, complete: bool) -> float:
	if not complete or not bool(art.get("pit", false)):
		return 0.0
	return -ModelArt.lowest(str(art.model))


## The hex pad and status beacon every modelled building stands on. A pit stands in an open hex
## retaining wall instead, as tall as it is deep, so its benches show from above.
func _art_base(active: bool, pit_depth: float = 0.0) -> ArrayMesh:
	var key: String = "artbase|%s|%.2f" % [str(active), pit_depth]
	if baked_models.has(key):
		return baked_models[key]
	var root := Node3D.new()
	add_child(root)
	var accent := _mat(
		"accent" + str(active),
		Color("75d6cc") if active else Color("d18061"),
		.3,
		.35,
		.7 if active else .12
	)
	var pad_material := _mat("pad", Color("43545a"), .3, .85)
	if pit_depth > 0.0:
		var wall := CylinderMesh.new()
		wall.top_radius = 2.3
		wall.bottom_radius = 2.3
		wall.height = pit_depth + .68
		wall.radial_segments = 6
		wall.cap_top = false
		var ring := _mesh(root, wall, Vector3(0, (pit_depth + .08 - .6) * .5, 0), pad_material)
		ring.material_override = _double_sided(pad_material)
	else:
		# Deep enough that the pad never shows a gap where the ground slopes.
		_cylinder(root, Vector3(0, -.22, 0), 2.30, .6, pad_material, 6)
	_cylinder(root, Vector3(1.8, .35, -1.7), .045, .5, _mat("metal", Color("73818a"), .6, .4), 6)
	_sphere(root, Vector3(1.8, .64, -1.7), .09, accent, 8, 4)
	var groups: Dictionary = {}
	_collect_parts(root, Transform3D.IDENTITY, groups)
	remove_child(root)
	root.free()
	var baked := ArrayMesh.new()
	for material: Material in groups:
		var st: SurfaceTool = groups[material]
		st.commit(baked)
		baked.surface_set_material(baked.get_surface_count() - 1, material)
	baked_models[key] = baked
	return baked


## Turns a building's front (+z) towards the main street.
static func _street_yaw(x: float, street_x: float) -> float:
	if x < street_x - 0.5:
		return PI * 0.5
	if x > street_x + 0.5:
		return -PI * 0.5
	return 0.0


## The building's model; a construction site while it is being built; a closed mine once the
## deposit under it is worked out.
func _dress_building(
	model: MeshInstance3D,
	building: Dictionary,
	art: Dictionary,
	active: bool,
	complete: bool,
	yaw: float
) -> void:
	var id: String = str(art.model)
	var scale: float = float(art.get("scale", 1.0))
	var great: bool = (
		Rules.read("economy").buildings.get(str(building.kind), {}).get("role", "") == "great"
	)
	if not complete:
		id = "construction"
		scale = 1.2 if great else 1.0
	elif art.has("ore") and _plot_depleted(building):
		id = "depleted_" + str(art.ore)
	var dressed: MeshInstance3D = ModelArt.instance(
		id, func(slot: String) -> Material: return _art_material(slot, art, active)
	)
	if dressed == null:
		return
	dressed.rotation.y = yaw
	dressed.scale = Vector3.ONE * scale
	# Seated on the pad top; a pit's floor on the ground.
	dressed.position.y = .08 + _pit_depth(art, complete)
	model.add_child(dressed)
	if not complete and great:
		var crane: MeshInstance3D = ModelArt.instance(
			"construction_crane",
			func(slot: String) -> Material: return _art_material(slot, {}, true)
		)
		if crane != null:
			crane.position = Vector3(-1.6, 0, 1.9).rotated(Vector3.UP, yaw)
			crane.rotation.y = yaw
			model.add_child(crane)


func _double_sided(material: StandardMaterial3D) -> StandardMaterial3D:
	var key: String = "double|" + str(material.get_instance_id())
	if not mats.has(key):
		var copy: StandardMaterial3D = material.duplicate()
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		mats[key] = copy
	return mats[key]


func _plot_depleted(building: Dictionary) -> bool:
	var plots: Array = world.regions[selected_region].get("plots", [])
	var plot: int = int(building.get("plot", -1))
	if plot < 0 or plot >= plots.size():
		return false
	return float(plots[plot].get("reserves", 1.0)) <= 0.0


## One material per slot and colour, shared by every model; window glass lights up at night.
func _art_material(slot: String, art: Dictionary, active: bool) -> Material:
	if slot == "glass":
		return _window_mat(active)
	var color: Color = ModelArt.slot_color(slot, art)
	var finish: Array = ModelArt.SLOT_FINISH.get(slot, [0.3, 0.6])
	return _mat("art_%s_%s" % [slot, color.to_html(false)], color, finish[0], finish[1])


## Street lamps: their glass is the lamp light the map turns up after dark.
func _lamp_slot_material(slot: String) -> Material:
	if slot == "glass":
		return _mat("lamps", Color("c4eee1"), .2, .4, 1.3)
	return _art_material(slot, {}, true)


## Where a vehicle's wheels are: on the road surface, which rides over water as a bridge.
func _road_height(x: float, z: float) -> float:
	return maxf(_ground(x, z) + .16, _water_height_at(x, z, 1.5) + .24)


func _build_traffic(stops: Array, offset: float, region: int) -> void:
	traffic = Traffic.new()
	traffic.name = "Traffic"
	buildings_root.add_child(traffic)
	if stops.is_empty():
		return
	var working: int = 0
	for stop: Dictionary in stops:
		if bool(stop.active):
			working += 1
	traffic.vehicle_meshes = {
		"truck": _vehicle_mesh("truck"), "van": _vehicle_mesh("van"), "bus": _vehicle_mesh("bus")
	}
	traffic.surface_height = _road_height
	traffic.street_x = offset
	traffic.stops = stops
	traffic.gates = region_gates.duplicate()
	traffic.setup(int(world.seed) * 31 + region, 2 + working / 2 + region_gates.size() * 2)


func _vehicle_mesh(kind: String) -> ArrayMesh:
	var key: String = "vehicle|" + kind
	if baked_models.has(key):
		return baked_models[key]
	var root := Node3D.new()
	add_child(root)
	_build_vehicle(root, kind)
	var groups: Dictionary = {}
	_collect_parts(root, Transform3D.IDENTITY, groups)
	remove_child(root)
	root.free()
	var baked := ArrayMesh.new()
	for material: Material in groups:
		var st: SurfaceTool = groups[material]
		st.commit(baked)
		baked.surface_set_material(baked.get_surface_count() - 1, material)
	baked_models[key] = baked
	return baked


## Pools of lamp light on the ground after dark: one instanced mesh for the whole town.
func _build_light_pools(pools: Array) -> void:
	if pools.is_empty():
		return
	if glow_material == null:
		glow_material = ShaderMaterial.new()
		glow_material.shader = Shaders.shader("glow")
	var placed: Array = []
	for pool: Array in pools:
		var at: Vector3 = pool[0]
		var size: float = float(pool[1])
		var lifted := Vector3(at.x, _ground(at.x, at.z) + .2, at.z)
		placed.append(
			[Transform3D(Basis.IDENTITY.scaled(Vector3(size, 1.0, size)), lifted), Color.WHITE]
		)
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var node: MultiMeshInstance3D = _instanced(quad, glow_material, placed)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.name = "LightPools"
	buildings_root.add_child(node)


## Steam and smoke over a working plant. Light, slow and few: a sign of life, not weather.
func _add_smoke(model: MeshInstance3D) -> void:
	var top: AABB = _model_bounds(model)
	var puff := CPUParticles3D.new()
	puff.name = "Smoke"
	puff.amount = 14
	puff.lifetime = 4.5
	puff.preprocess = 4.5
	puff.local_coords = false
	puff.position = Vector3(top.position.x * 0.35, top.end.y + .1, top.position.z * 0.3)
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = .18
	puff.direction = Vector3(0, 1, 0)
	puff.spread = 14.0
	puff.gravity = Vector3(.16, .05, .06)
	puff.initial_velocity_min = .35
	puff.initial_velocity_max = .6
	puff.scale_amount_min = .5
	puff.scale_amount_max = .8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.6))
	puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.93, 0.94, 0.42))
	fade.set_color(1, Color(0.85, 0.87, 0.89, 0.0))
	puff.color_ramp = fade
	var sprite := QuadMesh.new()
	sprite.size = Vector2(.9, .9)
	sprite.material = _smoke_material()
	puff.mesh = sprite
	model.add_child(puff)
	smoke_emitters.append(puff)


## The building's extent in its own frame, including a dressed model and its turn and scale.
static func _model_bounds(model: MeshInstance3D) -> AABB:
	var bounds: AABB = model.mesh.get_aabb()
	for child: Node in model.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var part: MeshInstance3D = child
			bounds = bounds.merge(part.transform * part.mesh.get_aabb())
	return bounds


func _smoke_material() -> StandardMaterial3D:
	if mats.has("smoke"):
		return mats["smoke"]
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	var material := StandardMaterial3D.new()
	material.albedo_texture = dot
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mats["smoke"] = material
	return material


func _lander(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var material := _mat("lander", Color("bdccce"), .6, .4)
	_cylinder(root, Vector3(0, 1, 0), .7, 1.35, material, 8)
	_cone(root, Vector3(0, 1.9, 0), .7, .5, material)
	for i in range(3):
		var t: float = i * TAU / 3
		_tube(
			root,
			Vector3(sin(t) * .5, .8, cos(t) * .5),
			Vector3(sin(t) * 1.3, .08, cos(t) * 1.3),
			.07,
			material
		)
		_cylinder(root, Vector3(sin(t) * 1.3, .09, cos(t) * 1.3), .25, .08, material, 8)
	_tube(root, Vector3(0, 1.8, 0), Vector3(0, 3.3, 0), .035, material)
	_sphere(root, Vector3(0, 3.3, 0), .08, _mat("beacon", Color("76dace"), 0, .4, 1), 8, 4)
	var ring: Array[Vector3] = []
	for i in range(65):
		var t := float(i) / 64 * TAU
		var x := cos(t) * 4.2
		var z := sin(t) * 4.2
		ring.append(Vector3(x, _ground(x, z) - pos.y + .04, z))
	_line(root, ring, Color("77c9be"), .5)
