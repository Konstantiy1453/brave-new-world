extends "res://world/building_models.gd"
## The regional terrain, water, nature and colony scene. Terrain is sampled once per load into a
## height field; everything placed on the ground afterwards reads that field. Trees, rocks and
## free plots are instanced; each building kind is one baked mesh.

const Rules = preload("res://simulation/rules.gd")
## Older worlds keep the field they were drawn on, to the vertex; towns on newer ones need more room.
const OLD_FIELD: Dictionary = {"res": 86, "width": 57.0, "depth": 47.0, "trees": 160, "gate": 24.0}
const WIDE_FIELD: Dictionary = {
	"res": 112, "width": 96.0, "depth": 72.0, "trees": 360, "gate": 44.0
}
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
var height_field := PackedFloat32Array()
var forest_field := PackedFloat32Array()
var field_has_sea: bool = false
var baked_models: Dictionary = {}
var road_tool: SurfaceTool
var road_sections: int = 0


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
			var color := _geo_color(g, ll.x, ll.y)
			if reg.river:
				color = color.lerp(Color("59704e"), .4)
			else:
				color = color.lerp(Color("777566"), .35)
			color = color.darkened(maxf(noise.get_noise_2d(x * 2.5, z * 2.5) * .25, 0))
			if is_finite(_water_height_at(x, z, 1.9)):
				color = color.lerp(Color("354e43"), .48)
			var index: int = iz * (resolution + 1) + ix
			colors[index] = color
			var height: float = _ground_from_geo(x, z, g, ll)
			heights[index] = height
			forests[index] = _forest_chance(g)
			vertices[index] = Vector3(x, height, z)
		if iz % 2 == 0:
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

	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	var material := _mat("terrain", Color.WHITE, 0, 1)
	material.vertex_color_use_as_albedo = true
	terrain.material_override = material
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
	var material := _mat("river_authoritative", Color("224f59"), .08, .36)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
			_mat("lakewater", Color("2e798a"), .32, .2),
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
		surface, plane, Vector3(0, sea_height, 0), _mat("sea", Color("285e76"), .4, .2)
	)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	if int(settlement.get("base_housing", 0)) > 0:
		_build_base_housing(offset, int(settlement.base_housing))
	var buildings: Array = settlement.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var slot: Vector2 = _building_spot(i, b, offset)
		var complete: bool = int(b.get("remaining", b.get("days_left", 0))) <= 0
		var active: bool = b.get("enabled", true) and b.get("active", true) and complete
		var model := MeshInstance3D.new()
		model.mesh = _baked_model(str(b.kind), active)
		model.position = Vector3(slot.x, _ground(slot.x, slot.y), slot.y)
		model.set_meta("building_kind", str(b.kind))
		buildings_root.add_child(model)
		if not complete:
			_construction_frame(model)
		_road(Vector3(offset, 0, slot.y), Vector3(slot.x, 0, slot.y))
	_road(Vector3(offset, 0, -12), Vector3(offset, 0, 12))
	for z in [-10, -5, 0, 5, 10]:
		var p := Vector3(offset + 1.1, _ground(offset + 1.1, z), z)
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


func _build_base_housing(offset: float, capacity: int) -> void:
	var root := Node3D.new()
	root.name = "LandingLivingCapsules"
	root.set_meta("base_housing", capacity)
	root.position = Vector3(offset - 6.0, _ground(offset - 6.0, 0), 0)
	buildings_root.add_child(root)
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
	_road(Vector3(offset, 0, 0), Vector3(offset - 6.0, 0, 0))


func _build_outbound_route(offset: float) -> void:
	for route: Dictionary in state.get("roads", []):
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
	_road(Vector3(start.x, 0, start.y), Vector3(finish.x, 0, finish.y))
	var gate := Vector3(finish.x, _ground(finish.x, finish.y), finish.y)
	var steel := _mat("routegate", Color("bcb28d"), .55, .5)
	for x in [-.85, .85]:
		_tube(buildings_root, gate + Vector3(x, 0, 0), gate + Vector3(x, 2, 0), .09, steel)
	_box(buildings_root, gate + Vector3(0, 2, 0), Vector3(2, .35, .24), steel)
	var label := Label3D.new()
	var blocked: bool = Geo.road_blocked(route, int(state.get("day", 0)))
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
