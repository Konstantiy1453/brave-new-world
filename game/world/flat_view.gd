extends "res://world/region_view.gd"
## The flat equirectangular world map.

const LABELLED_SITES: int = 8
const LABEL_CHAR_WIDTH: float = 0.26
const LABEL_HEIGHT: float = 0.28
const LABEL_SPOTS: Array[Vector2] = [
	Vector2(0, 0.26),
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, -0.26),
	Vector2(1, 0.3),
	Vector2(-1, 0.3),
	Vector2(1, -0.3),
	Vector2(-1, -0.3),
]
const MARKER_RICH_TONNES: Dictionary = {"ore": 6000.0, "copper": 4000.0, "crystal": 2500.0}
const MARKER_RICH_FERTILITY: float = 0.55
const GOOD_WEIGHT: Dictionary = {"ore": 8.0, "copper": 14.0, "crystal": 32.0}
const CLIMATE_RING_DEGREES: float = 35.0
## Straight-line jumps longer than this on the flat map cross the antimeridian: no gliding there.
const FLAT_WRAP_JUMP: float = 9.0

## Cargo markers placed every frame along their route, between the daily updates.
var globe_movers: Array = []
var flat_movers: Array = []


func _flat_point(lat: float, lon: float) -> Vector3:
	return Vector3(lon / 20.0, lat / 20.0, .035)


func _build_flat() -> void:
	var material := ShaderMaterial.new()
	material.shader = Shaders.shader("flat")
	material.set_shader_parameter("atlas", geography_atlas)
	material.set_shader_parameter("noise3d", Shaders.noise_texture())
	material.set_shader_parameter("lights", _night_lights_texture())
	_apply_town_lights(material)
	material.set_shader_parameter("ice_latitude", _ice_latitude())
	material.set_shader_parameter("coverage", _cloud_coverage())
	flat_shader = material
	var sheet := QuadMesh.new()
	sheet.size = Vector2(18, 9)
	_mesh(flat_world, sheet, Vector3.ZERO, material)
	# A restrained cartographic frame, not the regional construction grid.
	var frame: Array[Vector3] = [
		Vector3(-9, -4.5, .02),
		Vector3(9, -4.5, .02),
		Vector3(9, 4.5, .02),
		Vector3(-9, 4.5, .02),
		Vector3(-9, -4.5, .02)
	]
	_line(flat_world, frame, Color("5a8491"), .15)
	for lon in range(-180, 181, 60):
		var p := _flat_point(90, lon)
		_line(flat_world, [p, p + Vector3(0, .12, 0)], Color("718e9c"), .1)
		_flat_label(flat_world, Vector3(p.x, 4.78, .03), "%d°" % lon, Color("8da6b4"), .0065, 26)
	for lat in [-60, -30, 0, 30, 60]:
		_flat_label(
			flat_world, Vector3(-9.38, lat / 20.0, .03), "%d°" % lat, Color("8da6b4"), .0065, 26
		)
	_flat_label(flat_world, Vector3(0, -4.9, .03), "全球勘察图  /  等距经纬投影", Color("90aeb9"), .0068, 30)
	flat_marker_root = Node3D.new()
	flat_world.add_child(flat_marker_root)
	flat_transport_root = Node3D.new()
	flat_world.add_child(flat_transport_root)
	_build_global_water(flat_world, true)
	_update_flat_markers()
	_update_flat_transport()


func _flat_label(
	parent: Node3D,
	pos: Vector3,
	text: String,
	color: Color,
	pixel_size: float = .003,
	font_size: int = 36
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = label_font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.position = pos
	label.no_depth_test = true
	label.modulate = color
	label.outline_modulate = Color("071623")
	label.outline_size = 7
	parent.add_child(label)
	return label


## Whether a site passes the player's filter. Settled and selected sites always show.
func _marker_shown(reg: Dictionary) -> bool:
	if int(reg.id) == selected_region or _is_settled(int(reg.id)):
		return true
	match marker_filter:
		"all":
			return true
		"ore", "copper", "crystal":
			return float(reg.deposits.get(marker_filter, 0.0)) >= MARKER_RICH_TONNES[marker_filter]
		"farm":
			return float(reg.fertility) >= MARKER_RICH_FERTILITY
		"coast":
			return bool(reg.get("coast", false))
	return str(reg.get("archetype", "")) == marker_filter


func _is_settled(id: int) -> bool:
	for settlement in state.get("settlements", []):
		if int(settlement.region) == id:
			return true
	return false


## Names stay readable with forty sites: only the selected, hovered, settled and the richest.
func _labelled_sites() -> Array:
	var ranked: Array = []
	for reg in world.regions:
		if _marker_shown(reg):
			ranked.append(reg)
	ranked.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var sa: float = _site_rank(a)
			var sb: float = _site_rank(b)
			return int(a.id) < int(b.id) if sa == sb else sa > sb
	)
	# Candidates are named only while the player is choosing where to land, or filtering the map
	# for a site; after that, the settled, selected and hovered sites keep their names.
	var choosing: bool = state.get("settlements", []).is_empty() or marker_filter != "all"
	var labelled: Array = []
	for reg: Dictionary in ranked:
		var id: int = int(reg.id)
		if (
			id == selected_region
			or id == hovered_region
			or _is_settled(id)
			or (choosing and labelled.size() < LABELLED_SITES)
		):
			labelled.append(reg)
	return labelled


func _site_rank(reg: Dictionary) -> float:
	var id: int = int(reg.id)
	if id == selected_region or id == hovered_region:
		return INF
	if _is_settled(id):
		return 1.0e12
	var value: float = float(reg.fertility) * 40000.0
	for good: String in ["ore", "copper", "crystal"]:
		value += float(reg.deposits.get(good, 0.0)) * float(GOOD_WEIGHT[good])
	return value


## Tries the spots around a marker until a label fits without touching one already placed.
func _place_flat_label(point: Vector3, text: String, placed: Array) -> Vector3:
	var width: float = maxf(1.0, text.length() * LABEL_CHAR_WIDTH)
	var best: Vector3 = point + Vector3(0.0, 0.26, 0.03)
	for offset: Vector2 in LABEL_SPOTS:
		var at := Vector2(point.x, point.y) + Vector2(offset.x * (width * 0.5 + 0.12), offset.y)
		at.x = clampf(at.x, -8.6 + width * 0.5, 8.6 - width * 0.5)
		var box := Rect2(
			at - Vector2(width * 0.5, LABEL_HEIGHT * 0.5), Vector2(width, LABEL_HEIGHT)
		)
		var clear: bool = true
		for other: Rect2 in placed:
			clear = clear and not box.intersects(other)
		if clear:
			placed.append(box)
			return Vector3(at.x, at.y, 0.03)
	return best


func _update_flat_markers() -> void:
	if flat_marker_root == null or not is_instance_valid(flat_marker_root):
		return
	for child in flat_marker_root.get_children():
		flat_marker_root.remove_child(child)
		child.queue_free()
	_draw_flat_footprints()
	var labelled: Dictionary = {}
	for reg: Dictionary in _labelled_sites():
		labelled[int(reg.id)] = true
	var placed: Array = []
	for reg in _labelled_sites():
		_flat_marker(reg, true, placed)
	for reg in world.regions:
		if _marker_shown(reg) and not labelled.has(int(reg.id)):
			_flat_marker(reg, false, placed)


func _flat_marker(reg: Dictionary, with_label: bool, placed: Array) -> void:
	var settled: bool = _is_settled(int(reg.id))
	var color := Color("edc779") if settled else Color("7ae0d6")
	if int(reg.id) == selected_region:
		color = Color("fff2bd")
	var point := _flat_point(reg.lat, reg.lon)
	var ring: Array[Vector3] = []
	for i in range(41):
		var angle := float(i) / 40.0 * TAU
		ring.append(
			(
				point
				+ (
					Vector3(cos(angle), sin(angle), 0)
					* (.085 if int(reg.id) == selected_region else .055)
				)
			)
		)
	var holder := Node3D.new()
	flat_marker_root.add_child(holder)
	_line(holder, ring, color, .8)
	_sphere(holder, point, .025, _marker_material(color), 8, 4)
	if not with_label:
		return
	var text: String = _site_text(reg, settled)
	_flat_label(holder, _place_flat_label(point, text, placed), text, color, .0068, 40)


func _marker_material(color: Color) -> StandardMaterial3D:
	return _mat("marker" + color.to_html(), color, 0, 1, 1.3)


## Built-up area and farmland on the flat map: colonies visibly spread as they grow.
func _draw_flat_footprints() -> void:
	for settlement in state.get("settlements", []):
		var reg: Dictionary = world.regions[int(settlement.region)]
		var sizes: Dictionary = _footprint_sizes(settlement)
		var point := _flat_point(reg.lat, reg.lon) + Vector3(0, 0, -.004)
		if float(sizes.farmland) > 0.0:
			_disc(
				flat_marker_root,
				point,
				Vector3.BACK,
				float(sizes.farmland) * .3,
				_footprint_mat("farm")
			)
		_disc(
			flat_marker_root,
			point + Vector3(0, 0, .002),
			Vector3.BACK,
			float(sizes.town) * .3,
			_footprint_mat("town")
		)
	_draw_flat_climate()


func _draw_flat_climate() -> void:
	var at: Dictionary = _climate_site()
	if at.is_empty():
		return
	var radius: float = float(at.radius)
	var points: Array[Vector3] = []
	for i in range(73):
		var angle: float = float(i) / 72.0 * TAU
		points.append(
			_flat_point(
				clampf(float(at.lat) + cos(angle) * radius, -89.0, 89.0),
				float(at.lon) + sin(angle) * radius
			)
		)
	_line(flat_marker_root, points, Color("6fd8c0"), .8)


## The site of a finished climate regulator, with the radius it reaches.
func _climate_site() -> Dictionary:
	for settlement in state.get("settlements", []):
		for building: Dictionary in settlement.get("buildings", []):
			if str(building.kind) == "climate_regulator" and int(building.get("remaining", 0)) <= 0:
				var reg: Dictionary = world.regions[int(settlement.region)]
				return {
					"lat": float(reg.lat), "lon": float(reg.lon), "radius": CLIMATE_RING_DEGREES
				}
	return {}


## Radii in globe units for a settlement's built-up area and farmland.
func _footprint_sizes(settlement: Dictionary) -> Dictionary:
	var built: int = 0
	var farms: int = 0
	for building: Dictionary in settlement.get("buildings", []):
		if int(building.get("remaining", 0)) > 0:
			continue
		if str(building.kind) in ["farm", "hydroponic_farm"]:
			farms += 1
		else:
			built += 1
	return {
		"town": 0.05 + sqrt(float(built)) * 0.022,
		"farmland": 0.0 if farms == 0 else 0.07 + sqrt(float(built + farms * 3)) * 0.024,
	}


func _footprint_mat(kind: String) -> StandardMaterial3D:
	var color := Color(0.82, 0.66, 0.42, 0.72) if kind == "town" else Color(0.45, 0.62, 0.32, 0.5)
	var material := _mat("footprint" + kind, color, 0, 1)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _disc(
	parent: Node3D, center: Vector3, normal: Vector3, radius: float, material: Material
) -> void:
	var seedling: Vector3 = Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	var u: Vector3 = normal.cross(seedling).normalized()
	var v: Vector3 = normal.cross(u).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a: float = float(i) / 16.0 * TAU
		var b: float = float(i + 1) / 16.0 * TAU
		st.add_vertex(center)
		st.add_vertex(center + (u * cos(a) + v * sin(a)) * radius)
		st.add_vertex(center + (u * cos(b) + v * sin(b)) * radius)
	st.generate_normals()
	var node := _mesh(parent, st.commit(), Vector3.ZERO, material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_flat_transport() -> void:
	if flat_transport_root == null or not is_instance_valid(flat_transport_root):
		return
	for child in flat_transport_root.get_children():
		flat_transport_root.remove_child(child)
		child.queue_free()
	flat_movers.clear()
	for route: Dictionary in state.get("roads", []):
		if not bool(route.get("retired", false)):
			_draw_road_on_flat(route)
	_place_movers(flat_movers, sky.day_fraction)


func _draw_road_on_flat(route: Dictionary) -> void:
	var day: int = int(state.get("day", 0))
	var route_color := Color("e7bb75")
	if str(route.get("variant", "")) == "shuttle":
		route_color = SHUTTLE_COLOR
	if Geo.road_building(route, day):
		route_color = Color("8fa1a8")
	elif Geo.road_blocked(route, day):
		route_color = Color("d77963")
	var coordinates: Array = route.get("coordinates", []).duplicate()
	if coordinates.is_empty():
		for index in route.get("path", []):
			var ll: Vector2 = Geo.cell_coordinate(int(index))
			coordinates.append([ll.x, ll.y])
	var points: Array[Vector3] = []
	var segment: Array[Vector3] = []
	for ll in coordinates:
		var point := _flat_point(float(ll[0]), float(ll[1])) + Vector3(0, 0, .02)
		if not segment.is_empty() and absf(point.x - segment.back().x) > 9:
			_line(flat_transport_root, segment, route_color, 1.1)
			segment.clear()
		segment.append(point)
		points.append(point)
	_line(flat_transport_root, segment, route_color, 1.1)
	var lifted: Array[Vector3] = []
	for point: Vector3 in points:
		lifted.append(point + Vector3(0, 0, .03))
	for shipment in state.get("shipments", []):
		if points.is_empty() or int(shipment.get("road", 0)) != int(route.get("id", 0)):
			continue
		var marker := _sphere(
			flat_transport_root,
			lifted[0],
			CARGO_DOT_FLAT,
			_mat("flatshipment", Color("fff0bd"), 0, 1, CARGO_GLOW),
			8,
			4
		)
		flat_movers.append(_mover(marker, lifted, shipment, route, FLAT_WRAP_JUMP))


## A cargo marker and the path it follows. Lengths skip wrap jumps, so a marker leaps the
## antimeridian on the flat map instead of crossing the whole sheet.
func _mover(
	node: Node3D, points: Array[Vector3], shipment: Dictionary, route: Dictionary, jump: float
) -> Dictionary:
	var lengths := PackedFloat32Array([0.0])
	for index: int in range(1, points.size()):
		var step: float = points[index - 1].distance_to(points[index])
		lengths.append(lengths[index - 1] + (0.0 if step > jump else step))
	return {
		"node": node,
		"points": points,
		"lengths": lengths,
		"remaining": float(shipment.get("remaining", 1)),
		"total": maxf(float(shipment.get("total_days", 1)), 1.0),
		"reverse": int(shipment.get("from", -1)) == int(route.get("b", -2)),
	}


## Glides every cargo marker to where it is part-way through the day.
func _place_movers(movers: Array, fraction: float) -> void:
	for mover: Dictionary in movers:
		if not is_instance_valid(mover.node):
			continue
		var node: Node3D = mover.node
		var done: float = clampf(
			1.0 - (float(mover.remaining) - fraction) / float(mover.total), 0.0, 1.0
		)
		if bool(mover.reverse):
			done = 1.0 - done
		var points: Array[Vector3] = mover.points
		var lengths: PackedFloat32Array = mover.lengths
		var target: float = done * lengths[lengths.size() - 1]
		var index: int = 0
		while index < lengths.size() - 2 and lengths[index + 1] < target:
			index += 1
		var span: float = lengths[index + 1] - lengths[index] if lengths.size() > 1 else 0.0
		if span <= 0.0:
			node.position = points[mini(index + 1, points.size() - 1)]
			continue
		var t: float = (target - lengths[index]) / span
		node.position = points[index].lerp(points[index + 1], t)


func _build_global_water(parent: Node3D, flat: bool) -> void:
	# This overlay reads the same persisted river paths as the regional view.
	for river in render_rivers:
		var coordinates: Array = river.coordinates
		var points: Array[Vector3] = []
		for ll in coordinates:
			var point: Vector3 = (
				_flat_point(float(ll[0]), float(ll[1]))
				if flat
				else Geo.unit_point(float(ll[0]), float(ll[1])) * 3.009
			)
			if flat and not points.is_empty() and absf(point.x - points.back().x) > 9:
				_line(parent, points, Color("397f91"), .05)
				points.clear()
			points.append(point)
		_line(parent, points, Color("397f91"), .05)
	for lake in world.get("lakes", []):
		var lat: float = float(lake.lat)
		var lon: float = float(lake.lon)
		var radius: float = float(lake.get("radius_degrees", .45))
		var center: Vector3 = _flat_point(lat, lon) if flat else Geo.unit_point(lat, lon) * 3.013
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(32):
			var angle_a: float = TAU * float(i) / 32
			var angle_b: float = TAU * float(i + 1) / 32
			var la: Vector2 = Vector2(
				clampf(lat + cos(angle_a) * radius, -89.95, 89.95),
				wrapf(lon + sin(angle_a) * radius / maxf(cos(deg_to_rad(lat)), .15), -180, 180)
			)
			var lb: Vector2 = Vector2(
				clampf(lat + cos(angle_b) * radius, -89.95, 89.95),
				wrapf(lon + sin(angle_b) * radius / maxf(cos(deg_to_rad(lat)), .15), -180, 180)
			)
			var a: Vector3 = _flat_point(la.x, la.y) if flat else Geo.unit_point(la.x, la.y) * 3.013
			var b: Vector3 = _flat_point(lb.x, lb.y) if flat else Geo.unit_point(lb.x, lb.y) * 3.013
			if flat and (absf(center.x - a.x) > 9 or absf(center.x - b.x) > 9):
				continue
			for point in [center, a, b]:
				st.add_vertex(point)
		st.generate_normals()
		var material := _mat("global_lake", Color("327c91"), .1, .4, .12)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(parent, st.commit(), Vector3.ZERO, material)


func _prepare_render_rivers() -> void:
	# Round only the corners of the persisted coarse-grid channels. The same
	# subcell centerline and monotone height interpolation feed all three views.
	render_rivers.clear()
	var metadata: Array = world.get("river_metadata", [])
	var rivers: Array = world.get("rivers", [])
	for river_index in range(rivers.size()):
		var raw = rivers[river_index]
		var coordinates: Array = raw.get("coordinates", []) if raw is Dictionary else raw
		var heights: Array = (
			metadata[river_index].get("heights", []) if river_index < metadata.size() else []
		)
		var samples: Array[Vector3] = []
		for i in range(coordinates.size()):
			var ll = coordinates[i]
			var h: float = (
				float(heights[i])
				if i < heights.size()
				else float(
					Geo.sample_geo(float(ll[0]), float(ll[1]), noise, str(world.version)).height
				)
			)
			var lon: float = float(ll[1])
			if not samples.is_empty():
				lon = samples.back().x + wrapf(lon - samples.back().x, -180, 180)
			samples.append(Vector3(lon, float(ll[0]), h))
		if samples.size() < 2:
			continue
		var rounded: Array[Vector3] = [samples[0]]
		for i in range(1, samples.size() - 1):
			var a: Vector3 = samples[i - 1].lerp(samples[i], .76)
			var b: Vector3 = samples[i].lerp(samples[i + 1], .24)
			rounded.append(a)
			for step in range(1, 7):
				var t: float = float(step) / 6
				rounded.append(a.lerp(samples[i], t).lerp(samples[i].lerp(b, t), t))
		rounded.append(samples.back())
		var output: Array = []
		var output_heights: Array = []
		for point in rounded:
			output.append([point.y, wrapf(point.x, -180, 180)])
			output_heights.append(point.z)
		render_rivers.append(
			{"coordinates": output, "heights": output_heights, "river_index": river_index}
		)
