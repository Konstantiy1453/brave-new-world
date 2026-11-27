extends "res://world/region_town.gd"
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
## How far along the steps on either side a river's corners are rounded: on the maps, and in a
## CC-GEO-2.3 district (half a step: one smooth bend per cell).
const MAP_RIVER_ROUNDING: float = 0.24
const DISTRICT_RIVER_ROUNDING: float = 0.5
## Points of a rounded river closer than this (degrees) are one point.
const RIVER_POINT_EPSILON: float = 0.0001
## The flat map's width and height in scene units (360° and 180° at 20° a unit).
const FLAT_WIDTH: float = 18.0
const FLAT_HEIGHT: float = 9.0
## A ship's call at a working quay (1.10): in, at the berth, out and away, over these game days.
const SHIP_DAYS: float = 3.0
## The ship light against a cargo dot: its size and its glow. At the berth it lies this share of its
## line out from the quay, so it reads beside the quay's lamps instead of summing with them into
## one white spot (the 1.10.1 night captures).
const SHIP_LIGHT_SIZE: float = 0.7
const SHIP_LIGHT_GLOW: float = 0.55
## The company's annual ship (1.11 D): it comes down over the capital in the days before it is due
## and stays on the ground while the year's report waits for a signature.
const COMPANY_SHIP_DESCENT_DAYS: float = 4.0
const COMPANY_SHIP_LIGHT: Color = Color("fff1c2")
const COMPANY_SHIP_SIZE: float = 1.6
## The picked ground's cursor on both maps (1.10 free placement): its ring's radius in degrees.
const GROUND_CURSOR_DEGREES: float = 1.2
const GROUND_CURSOR_COLOR: Color = Color("f4fbff")
## Prospecting anomalies by resource: iron rust, copper green, crystal violet, nickel pale sage,
## cobalt deep blue.
const ANOMALY_COLORS: Dictionary = {
	"ore": Color("d9895a"),
	"copper": Color("4fc3a1"),
	"crystal": Color("b493e8"),
	"nickel": Color("c2d6b0"),
	"cobalt": Color("6f86e8"),
}

const SeaLane = preload("res://world/sea_lane.gd")
var sea_lane := SeaLane.new()
## Only the annual report ship has a moving marker on these two maps.
var globe_ships: Array = []
var flat_ships: Array = []


func _flat_point(lat: float, lon: float) -> Vector3:
	return Vector3(lon / 20.0, lat / 20.0, .035)


func _build_flat() -> void:
	var material := ShaderMaterial.new()
	material.shader = Shaders.shader("flat")
	_bind_optical(material, true, true)
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
	# No frame and no east or west edge: the map repeats round the planet (`_refresh_flat_ghosts`).
	# Longitude ticks along the top edge; 180° once, where the copies meet.
	for lon in range(-120, 181, 60):
		var p := _flat_point(90, lon)
		_line(flat_world, [p, p + Vector3(0, .12, 0)], Color("718e9c"), .1)
		_flat_label(flat_world, Vector3(p.x, 4.78, .03), "%d°" % lon, Color("8da6b4"), .0065, 26)
	flat_marker_root = Node3D.new()
	flat_world.add_child(flat_marker_root)
	flat_transport_root = Node3D.new()
	flat_world.add_child(flat_transport_root)
	flat_transport_root.visible = routes_shown
	flat_mover_root = Node3D.new()
	flat_mover_root.name = "FlatMovers"
	flat_world.add_child(flat_mover_root)
	_build_global_water(flat_world, true)
	_update_flat_markers()
	_update_flat_transport()
	flat_ghosts_dirty = true


## Copies of the flat map's content one map width west and east (its moving cargo excepted), so a
## view across the 180° meridian shows the planet going on. Rebuilt only when the map has changed.
func _refresh_flat_ghosts() -> void:
	for ghost: Node3D in flat_ghosts:
		if is_instance_valid(ghost):
			ghost.get_parent().remove_child(ghost)
			ghost.queue_free()
	flat_ghosts.clear()
	flat_ghosts_dirty = false
	if flat_world == null or not is_instance_valid(flat_world):
		return
	var originals: Array = []
	for child: Node in flat_world.get_children():
		if child == flat_mover_root or child.has_meta("flat_ghost"):
			continue
		originals.append(child)
	for side: float in [-FLAT_WIDTH, FLAT_WIDTH]:
		var ghost := Node3D.new()
		ghost.set_meta("flat_ghost", true)
		ghost.position = Vector3(side, 0, 0)
		flat_world.add_child(ghost)
		for child: Node in originals:
			ghost.add_child(child.duplicate())
		flat_ghosts.append(ghost)


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
	return _is_settled(int(reg.id))


func _is_settled(id: int) -> bool:
	for settlement in state.get("settlements", []):
		if int(settlement.region) == id:
			return true
	return false


## Named towns are the only persistent site markers on both projections.
func _labelled_sites() -> Array:
	var regions: Array = []
	for reg: Dictionary in world.regions:
		if _marker_shown(reg):
			regions.append(reg)
	return regions


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
	flat_ghosts_dirty = true
	for child in flat_marker_root.get_children():
		flat_marker_root.remove_child(child)
		child.queue_free()
	_draw_flat_climate()
	var labelled: Dictionary = {}
	for reg: Dictionary in _labelled_sites():
		labelled[int(reg.id)] = true
	var placed: Array = []
	for reg in _labelled_sites():
		_flat_marker(reg, true, placed)
	for reg in world.regions:
		if _marker_shown(reg) and not labelled.has(int(reg.id)):
			_flat_marker(reg, false, placed)
	_flat_signals()
	_flat_anomalies()
	_flat_ground_cursor()


## The picked ground (1.10 free placement): a white ring and cross at the exact point.
func _flat_ground_cursor() -> void:
	if ground_point.is_empty():
		return
	var point := _flat_point(float(ground_point.lat), float(ground_point.lon)) + Vector3(0, 0, .03)
	var holder := Node3D.new()
	flat_marker_root.add_child(holder)
	var size: float = GROUND_CURSOR_DEGREES / 20.0
	var ring: Array[Vector3] = []
	for i in range(41):
		var angle := float(i) / 40.0 * TAU
		ring.append(point + Vector3(cos(angle), sin(angle), 0) * size)
	_line(holder, ring, GROUND_CURSOR_COLOR, 1.4)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
		for side: float in [-1.0, 1.0]:
			var tick: Array[Vector3] = [
				point + axis * size * 0.5 * side, point + axis * size * 1.6 * side
			]
			_line(holder, tick, GROUND_CURSOR_COLOR, 1.4)
	_sphere(holder, point, .01, _marker_material(GROUND_CURSOR_COLOR), 8, 4)


## The prospecting anomalies (prospecting.gd): a ring per anomaly, its zone's size, in its
## resource's colour; a drilled deposit gets a dot in the middle.
func _flat_anomalies() -> void:
	for anomaly: Dictionary in state.get("prospecting", {}).get("anomalies", []):
		var colour: Color = ANOMALY_COLORS.get(str(anomaly.resource), Color.WHITE)
		var point := _flat_point(float(anomaly.lat), float(anomaly.lon)) + Vector3(0, 0, .025)
		var size: float = float(anomaly.zone) / 20.0
		var ring: Array[Vector3] = []
		for i in range(49):
			var angle := float(i) / 48.0 * TAU
			ring.append(point + Vector3(cos(angle), sin(angle), 0) * size)
		var holder := Node3D.new()
		flat_marker_root.add_child(holder)
		_line(holder, ring, colour, 1.2)
		if str(anomaly.stage) == "drilled":
			_sphere(holder, point, .014, _marker_material(colour), 8, 4)


## Each settled coastal town's offshore signal while it is unknown or rich: a gold ring out over
## the water, where the district floats its buoy.
func _flat_signals() -> void:
	for s: Dictionary in state.get("settlements", []):
		var region: int = int(s.get("region", -1))
		if signal_reading(region).is_empty():
			continue
		_fit_field()
		var at: Vector2 = signal_point(region)
		if not at.is_finite():
			continue
		var point := _flat_point(at.x, at.y) + Vector3(0, 0, .02)
		var ring: Array[Vector3] = []
		for i in range(33):
			var angle := float(i) / 32.0 * TAU
			ring.append(point + Vector3(cos(angle), sin(angle), 0) * .04)
		var holder := Node3D.new()
		flat_marker_root.add_child(holder)
		_line(holder, ring, SIGNAL_COLOR, 1.1)
		_sphere(holder, point, .012, _marker_material(SIGNAL_COLOR), 8, 4)


func _flat_marker(reg: Dictionary, with_label: bool, placed: Array) -> void:
	var settled: bool = _is_settled(int(reg.id))
	var color := Color("edc779") if settled else Color("7ae0d6")
	if int(reg.id) == selected_region:
		color = Color("fff2bd")
	var point := _flat_point(reg.lat, reg.lon)
	var holder := Node3D.new()
	flat_marker_root.add_child(holder)
	if not with_label:
		return
	var text: String = _site_name(reg, settled)
	_flat_label(holder, _place_flat_label(point, text, placed), text, color, .0068, 40)


func _marker_material(color: Color) -> StandardMaterial3D:
	return _mat("marker" + color.to_html(), color, 0, 1, 1.3)


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
	flat_ghosts_dirty = true
	for root: Node3D in [flat_transport_root, flat_mover_root]:
		if root == null or not is_instance_valid(root):
			continue
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	for route: Dictionary in state.get("roads", []):
		if not bool(route.get("retired", false)):
			_draw_road_on_flat(route)
	flat_ships = _ship_movers(true)
	place_ships(flat_ships, sky.day_fraction)


## Convert old cell paths and current coordinates into the same display geometry on both maps.
func _route_coordinates(route: Dictionary) -> Array[Vector2]:
	if str(route.get("variant", "")) == "sea":
		var regions: Array = state.get("world", {}).get("regions", world.get("regions", []))
		var a: int = int(route.get("a", -1))
		var b: int = int(route.get("b", -1))
		if a < 0 or b < 0 or a >= regions.size() or b >= regions.size():
			return []
		sea_lane.setup(geography_atlas)
		return sea_lane.coordinates(
			Vector2(regions[a].lat, regions[a].lon), Vector2(regions[b].lat, regions[b].lon)
		)
	var points: Array[Vector2] = []
	for ll: Variant in route.get("coordinates", []):
		points.append(Vector2(float(ll[0]), float(ll[1])))
	if points.is_empty():
		for cell: int in route.get("path", []):
			points.append(Geo.cell_coordinate(cell))
	return points


func _route_color(route: Dictionary) -> Color:
	var day: int = int(state.get("day", 0))
	if Geo.road_blocked(route, day):
		return Color("b47561")
	if Geo.road_building(route, day):
		return Color("86959c")
	match str(route.get("variant", "")):
		"sea":
			return Color("96c7d8")
		"shuttle":
			return SHUTTLE_COLOR
	return Color("aa8053")


func _draw_road_on_flat(route: Dictionary) -> void:
	var segment: Array[Vector3] = []
	var color: Color = _route_color(route)
	var sea: bool = str(route.get("variant", "")) == "sea"
	for ll: Vector2 in _route_coordinates(route):
		var point := _flat_point(ll.x, ll.y) + Vector3(0, 0, 0.02)
		if not segment.is_empty() and absf(point.x - segment.back().x) > FLAT_WRAP_JUMP:
			var previous: Vector3 = segment.back()
			var edge: float = FLAT_WIDTH * (0.5 if previous.x > 0.0 else -0.5)
			var unwrapped := point + Vector3(signf(edge) * FLAT_WIDTH, 0, 0)
			var span: float = unwrapped.x - previous.x
			var fraction: float = 0.0 if is_zero_approx(span) else (edge - previous.x) / span
			var cut := previous.lerp(unwrapped, fraction)
			segment.append(cut)
			_draw_route_segment(flat_transport_root, segment, color, sea, true)
			segment = [Vector3(-edge, cut.y, cut.z)]
		segment.append(point)
	_draw_route_segment(flat_transport_root, segment, color, sea, true)


## Sea fragments use the same atlas as the planet surface, including the antimeridian.
func _draw_route_segment(holder: Node3D, points: Array[Vector3], color: Color, sea: bool, flat_map: bool) -> void:
	if points.size() < 2:
		return
	var key := "route_%s_%s_%s" % [color.to_html(), sea, flat_map]
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = preload("res://world/transport_route.gdshader")
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("sea", sea)
		material.set_shader_parameter("flat_map", flat_map)
		material.set_shader_parameter("road_lamps", not sea and color == Color("aa8053"))
		mats[key] = material
	var material: ShaderMaterial = mats[key]
	if sea:
		material.set_shader_parameter("atlas", geography_atlas)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point: Vector3 in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.name = "SeaRoute" if sea else "LandRoute"
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(line)


func _ship_movers(flat: bool) -> Array:
	var holder: Node3D = flat_mover_root if flat else mover_root
	if not is_instance_valid(holder):
		return []
	var company: Dictionary = _company_ship(flat, holder)
	return [] if company.is_empty() else [company]


## The company ship's light over the capital, while it is coming down or waiting on the ground;
## empty at any other time. Its descent is placed from the game clock by `place_ships`.
func _company_ship(flat: bool, holder: Node3D) -> Dictionary:
	var annual: Dictionary = state.get("annual", {})
	var towns: Array = state.get("settlements", [])
	if annual.is_empty() or towns.is_empty() or int(annual.get("next_ship", -1)) < 0:
		return {}
	var pending: Dictionary = annual.get("pending", {})
	var due: float = float(pending.get("day", annual.next_ship))
	if pending.is_empty() and due - float(state.get("day", 0)) > COMPANY_SHIP_DESCENT_DAYS:
		return {}
	var region: int = int(towns[0].get("region", -1))
	if region < 0 or region >= world.get("regions", []).size():
		return {}
	var ll: Vector2 = _coordinate_in(world.regions[region], 0.0, 0.0)
	var ground: Vector3 = Geo.unit_point(ll.x, ll.y) * 3.06
	var high: Vector3 = Geo.unit_point(ll.x, ll.y) * 4.4
	if flat:
		ground = _flat_point(ll.x, ll.y) + Vector3(0, 0, .06)
		high = ground + Vector3(0, 0, 2.4)
	var light := _sphere(
		holder,
		high,
		(CARGO_DOT_FLAT if flat else CARGO_DOT_GLOBE) * SHIP_LIGHT_SIZE * COMPANY_SHIP_SIZE,
		_mat("company_ship", COMPANY_SHIP_LIGHT, 0, 1, CARGO_GLOW * SHIP_LIGHT_GLOW * 1.6),
		8,
		4
	)
	light.name = "CompanyShip"
	return {
		"node": light,
		"from": high,
		"to": ground,
		"descent": [due - COMPANY_SHIP_DESCENT_DAYS, due],
	}


## The annual ship descends only around its report date.
func place_ships(ships: Array, fraction: float) -> void:
	var day: float = float(state.get("day", 0)) + fraction
	for entry: Dictionary in ships:
		if not is_instance_valid(entry.node):
			continue
		var span: Array = entry.descent
		var down: float = inverse_lerp(float(span[0]), float(span[1]), day)
		entry.node.position = entry.from.lerp(entry.to, smoothstep(0.0, 1.0, down))


func _build_global_water(parent: Node3D, flat: bool) -> void:
	if _uses_optical_geography():
		# The shared optical atlas already includes river and lake areas at observation scale.
		return
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
	district_rivers.clear()
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
		var drawn: Dictionary = _rounded_river(samples, MAP_RIVER_ROUNDING, river_index)
		render_rivers.append(drawn)
		# In a district four units span a degree: a coarse step is several units long, and corners
		# rounded over a quarter of it still read as a staircase (1.12).
		district_rivers.append(
			(
				_rounded_river(samples, DISTRICT_RIVER_ROUNDING, river_index)
				if _uses_optical_geography()
				else drawn
			)
		)


## A channel's cell centres (lon, lat, height) with each corner rounded by a quadratic curve over
## `reach` of the steps on either side, as [lat, lon] coordinates and heights. Heights stay
## monotone: each curve runs between points of the falling channel.
func _rounded_river(samples: Array[Vector3], reach: float, river_index: int) -> Dictionary:
	# Half-step curves meet end to end; their shared points are kept once.
	var merge: bool = reach >= DISTRICT_RIVER_ROUNDING
	var rounded: Array[Vector3] = [samples[0]]
	for i in range(1, samples.size() - 1):
		var a: Vector3 = samples[i - 1].lerp(samples[i], 1.0 - reach)
		var b: Vector3 = samples[i].lerp(samples[i + 1], reach)
		if not merge or a.distance_to(rounded.back()) > RIVER_POINT_EPSILON:
			rounded.append(a)
		for step in range(1, 7):
			var t: float = float(step) / 6
			rounded.append(a.lerp(samples[i], t).lerp(samples[i].lerp(b, t), t))
	if not merge or samples.back().distance_to(rounded.back()) > RIVER_POINT_EPSILON:
		rounded.append(samples.back())
	var output: Array = []
	var output_heights: Array = []
	for point in rounded:
		output.append([point.y, wrapf(point.x, -180, 180)])
		output_heights.append(point.z)
	return {"coordinates": output, "heights": output_heights, "river_index": river_index}
