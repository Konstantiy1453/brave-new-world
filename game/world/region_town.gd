extends "res://world/region_view.gd"
## A generated world's town in metres (1.12): the approved district's revision 06 and 07 on the
## live settlement (district_plan.gd, district_art.gd, district_streets.gd). The buildings, their
## plots, kinds and states come from the save; the town grid is bent into curving streets, every
## building is drawn at its metric size, the reviewed kinds from their high-detail models near the
## camera, and the paving at metric widths. Older worlds keep region_view.gd's town.

## The ground round the town reads as the approved close ground this far past its buildings, in
## units (district_ground.gd).
const TOWN_GROUND_MARGIN: float = 8.0
## The close ground reaches at least this far from a town's middle (units, about 600 m): a new
## town of a few buildings otherwise stood on a small disc of it, ringed by the far ground.
const TOWN_GROUND_MIN_REACH: float = 36.0
## A lane stops where the next building along its row stands further than this from the last, in
## units: two plots apart and a little.
const LANE_GAP: float = 12.5
const DistrictNature = preload("res://world/district/district_nature.gd")

## Where the town's buildings stand (bent, units), for the ground's close soil; and how long the
## last town's shoulders took to draw, in milliseconds.
var town_spots := PackedVector2Array()
var fringe_ms: int = 0
## The town's drawn buildings as {pos, yaw, size, kind}, the shoulders' mask of its paving, and
## what the last nature held (counts and milliseconds; district_nature.gd).
var town_lots: Array = []
var town_fringe: Dictionary = {}
var nature_counts: Dictionary = {}


## A generated world's town in metres (1.12): every building on its plot's lot (district_plan.gd)
## at its metric size, the reviewed kinds in their high-detail models near the camera, the plot
## grid's main street, lanes and spurs paved at their metric widths and bent with the town, and
## no hexagonal pads: a building stands on its graded footprint with its status beacon.
func _build_town(settlement: Dictionary, offset: float) -> void:
	_build_landmarks()
	road_tool = SurfaceTool.new()
	road_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_sections = 0
	town_streets = DistrictStreets.new(_paving_height)
	town_roads.clear()
	region_gates.clear()
	smoke_emitters.clear()
	var stops: Array = []
	var pools: Array = []
	var street_ends := Vector2(-12.0, 12.0)
	town_spots.clear()
	town_lots.clear()
	# Where each building meets its lane, for the lanes laid after (`_lay_lanes`).
	var reaches: Array = []
	if int(settlement.get("base_housing", 0)) > 0:
		var camp: float = float(
			LightField.housing_shares(settlement, Rules.read("economy").buildings).get(
				LightField.CAMP, 0.0
			)
		)
		_build_base_housing(offset, int(settlement.base_housing), camp > 0.0)
		var pods: Vector2 = _pods_position(offset)
		town_spots.append(pods)
		var reach: Dictionary = _access(pods)
		stops.append(
			{
				"end": reach.front,
				"via": Vector2(pods.x, float(reach.lane)),
				"z": float(reach.lane),
				"kind": "base",
				"active": true
			}
		)
		reaches.append({"x": pods.x, "lane": float(reach.lane), "kind": "lane", "stop": stops[-1]})
	var roles: Dictionary = Rules.read("economy").buildings
	var shares: Dictionary = LightField.housing_shares(settlement, roles)
	var buildings: Array = settlement.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var role: String = str(roles.get(str(b.kind), {}).get("role", ""))
		if role in ["harbor", "seabed"]:
			continue
		var plot: int = int(b.get("plot", -1))
		var lot: Dictionary = (
			plot_lot(selected_region, plot, str(b.kind))
			if plot >= 0
			else unplotted_lot(selected_region, i, str(b.kind))
		)
		var complete: bool = int(b.get("remaining", b.get("days_left", 0))) <= 0
		var active: bool = b.get("enabled", true) and b.get("active", true) and complete
		var lit: bool = LightField.home_lit(b, roles, shares)
		var art: Dictionary = ModelArt.kind_entry(str(b.kind))
		var at: Vector2 = lot.pos
		town_spots.append(at)
		town_lots.append({"pos": at, "yaw": lot.yaw, "size": lot.size, "kind": str(b.kind)})
		var yaw: float = float(lot.yaw)
		var size: Vector2 = lot.size
		var model := MeshInstance3D.new()
		model.mesh = (
			_baked_model(str(b.kind), active)
			if art.is_empty()
			else _town_base(active, _pit_depth(art, complete), size)
		)
		model.position = Vector3(at.x, _ground(at.x, at.y), at.y)
		model.set_meta("building_kind", str(b.kind))
		model.set_meta("building_uid", int(b.get("uid", 0)))
		buildings_root.add_child(model)
		if art.is_empty():
			model.rotation.y = yaw
			if not complete:
				_construction_frame(model)
		else:
			_dress_building(model, b, art, active, complete, yaw, lit, maxf(size.x, size.y))
			if complete and DistrictArt.has_model(str(b.kind)) and not _plot_depleted(b):
				_near_detail(model, str(b.kind), yaw, lit and active)
		var reach_lane: float = float(lot.lane)
		var slot: Vector2 = lot.slot
		var lane_kind: String = DistrictPlan.lane_kind(role)
		var spur_kind: String = "yard" if lane_kind == "works" else "walk"
		town_roads.append(
			[PackedVector2Array([Vector2(slot.x, reach_lane), lot.plain_front]), spur_kind]
		)
		street_ends = Vector2(minf(street_ends.x, reach_lane), maxf(street_ends.y, reach_lane))
		(
			stops
			. append(
				{
					"end": lot.plain_front,
					"via": Vector2(slot.x, reach_lane),
					"z": reach_lane,
					"kind": str(b.kind),
					"active": active,
					"uid": int(b.get("uid", 0)),
				}
			)
		)
		reaches.append({"x": slot.x, "lane": reach_lane, "kind": lane_kind, "stop": stops[-1]})
		if active and lit:
			pools.append([model.position, 2.6])
			if role in SMOKE_ROLES or str(b.kind) in SMOKE_KINDS:
				_add_smoke(model)
	town_roads.append(
		[
			PackedVector2Array(
				[Vector2(offset, street_ends.x - 1.5), Vector2(offset, street_ends.y + 1.5)]
			),
			"through"
		]
	)
	_lay_lanes(
		reaches, offset, Vector2(offset, street_ends.x - 1.5), Vector2(offset, street_ends.y + 1.5)
	)
	for z: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		var spot: Vector2 = DistrictPlan.warp(
			Vector2(offset + 9.0 * DistrictPlan.UNIT, z), district_key()
		)
		var p := Vector3(spot.x, _ground(spot.x, spot.y), spot.y)
		pools.append([p, 1.3])
		var lamp: MeshInstance3D = ModelArt.instance("street_lamp", _lamp_slot_material)
		if lamp != null:
			lamp.position = p
			lamp.rotation.y = PI * 0.5
			lamp.scale = (
				Vector3.ONE
				* DistrictPlan.UNIT
				* 8.0
				/ maxf(ModelArt.model_size("street_lamp").y, 0.01)
			)
			buildings_root.add_child(lamp)
	_build_outbound_route(offset)
	_draw_free_plots(settlement)
	_finish_town_streets()
	_build_district_nature()
	_finish_roads()
	_build_bridges()
	_build_harbor(settlement)
	_build_company_ship(settlement, offset)
	_build_light_pools(pools)
	_build_traffic(stops, offset, int(settlement.get("region", 0)))


## The town's lanes from the player's own buildings (1.12): a lane runs out from the main street
## along its row only as far as the row's buildings stand within LANE_GAP of each other; a building
## further out gets its own road to the nearest road already laid, the nearest such building
## first, so outlying sites share one road out instead of each drawing a lane across empty land.
## Each stop learns its way in to the main street (`approach`, traffic.gd).
func _lay_lanes(reaches: Array, offset: float, street_low: Vector2, street_high: Vector2) -> void:
	var network: Array = [{"a": street_low, "b": street_high, "parent": -1, "lane": NAN}]
	var rows: Dictionary = {}
	for index: int in range(reaches.size()):
		var reach: Dictionary = reaches[index]
		var key := Vector2(float(reach.lane), -1.0 if float(reach.x) < offset else 1.0)
		if not rows.has(key):
			rows[key] = []
		rows[key].append(index)
	var outlying: Array[int] = []
	for key: Vector2 in rows:
		var members: Array = rows[key]
		members.sort_custom(
			func(a: int, b: int) -> bool:
				return absf(float(reaches[a].x) - offset) < absf(float(reaches[b].x) - offset)
		)
		var end: float = offset
		var kind: String = "lane"
		var open: bool = true
		for index: int in members:
			var x: float = float(reaches[index].x)
			open = open and absf(x - end) <= LANE_GAP
			if not open:
				outlying.append(index)
				continue
			end = x
			if str(reaches[index].kind) == "works":
				kind = "works"
		if end == offset:
			continue
		var tip := Vector2(end + key.y * 0.9, key.x)
		network.append({"a": Vector2(offset, key.x), "b": tip, "parent": 0, "lane": key.x})
		town_roads.append([PackedVector2Array([Vector2(offset, key.x), tip]), kind])
	while not outlying.is_empty():
		var best: int = -1
		var best_way: Dictionary = {}
		for slot: int in range(outlying.size()):
			var reach: Dictionary = reaches[outlying[slot]]
			var way: Dictionary = _way_in(Vector2(float(reach.x), float(reach.lane)), network)
			if not way.is_empty() and (best_way.is_empty() or way.length < best_way.length):
				best = slot
				best_way = way
		if best < 0:
			break
		var chosen: Dictionary = reaches[outlying[best]]
		outlying.remove_at(best)
		var points: PackedVector2Array = best_way.points
		var host: int = int(best_way.host)
		for index: int in range(points.size() - 2, -1, -1):
			network.append(
				{"a": points[index], "b": points[index + 1], "parent": host, "lane": NAN}
			)
			host = network.size() - 1
		town_roads.append([points, str(chosen.kind)])
		_route_stop(chosen.stop, network, host)


## The shortest way from an outlying building's corner of its lane to a road already laid, on the
## grid's open lines only: along its own lane line to a crossing road, or one step to the gap
## between plot columns and along it to a lane, so it never crosses a plot. {points, length, host}.
static func _way_in(via: Vector2, network: Array) -> Dictionary:
	var best: Dictionary = {}
	for index: int in range(network.size()):
		var a: Vector2 = network[index].a
		var b: Vector2 = network[index].b
		var low: Vector2 = a.min(b)
		var high: Vector2 = a.max(b)
		var options: Array = []
		if absf(a.x - b.x) < 0.001 and via.y >= low.y - 0.001 and via.y <= high.y + 0.001:
			options.append([via, Vector2(a.x, via.y)])
		if absf(a.y - b.y) < 0.001:
			if absf(a.y - via.y) < 0.001:
				options.append([via, Vector2(clampf(via.x, low.x, high.x), via.y)])
			for side: float in [-1.0, 1.0]:
				var gap: float = via.x + side * DistrictPlan.SLOT_SPACING * 0.5
				if gap >= low.x - 0.001 and gap <= high.x + 0.001:
					options.append([via, Vector2(gap, via.y), Vector2(gap, a.y)])
		for option: Array in options:
			var length: float = 0.0
			for step: int in range(option.size() - 1):
				length += Vector2(option[step]).distance_to(option[step + 1])
			if best.is_empty() or length < float(best.length):
				best = {"points": PackedVector2Array(option), "length": length, "host": index}
	return best


## A stop on an outlying road: the corners of its way in, from its own road to the main street,
## and the main street's point it reaches it by.
func _route_stop(stop: Variant, network: Array, segment: int) -> void:
	if not stop is Dictionary:
		return
	var approach := PackedVector2Array()
	var piece: Dictionary = network[segment]
	for _guard: int in range(network.size()):
		var host_index: int = int(piece.parent)
		var join: Vector2 = piece.b
		if host_index <= 0:
			stop.z = join.y
			break
		var host: Dictionary = network[host_index]
		approach.append(join)
		if not is_nan(float(host.lane)):
			stop.z = float(host.lane)
			break
		piece = host
	stop.approach = approach


## The town's streets, bent and paved (district_streets.gd).
func _finish_town_streets() -> void:
	var key: int = district_key()
	for entry: Array in town_roads:
		town_streets.street(DistrictPlan.bent_path(entry[0], 0.5, key), str(entry[1]))
	var paving := Node3D.new()
	paving.name = "TownPaving"
	buildings_root.add_child(paving)
	town_streets.commit(paving)
	_dress_ground()


## The ground's shoulders along the paving just drawn, and its close soil over the town's extent.
func _dress_ground() -> void:
	if ground_material == null:
		return
	var started: int = Time.get_ticks_msec()
	town_fringe = DistrictGround.fringe(town_streets.edges)
	DistrictGround.set_fringe(ground_material, town_fringe)
	fringe_ms = Time.get_ticks_msec() - started
	var centre := Vector2(_town_offset(), 0.0)
	var reach := Vector2.ONE * TOWN_GROUND_MARGIN * 1.5
	var level: float = _ground(centre.x, centre.y)
	if not town_spots.is_empty():
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var total: float = 0.0
		for spot: Vector2 in town_spots:
			low = low.min(spot)
			high = high.max(spot)
			total += _ground(spot.x, spot.y)
		centre = (low + high) * 0.5
		reach = (high - low) * 0.5 + Vector2.ONE * TOWN_GROUND_MARGIN
		level = total / town_spots.size()
	DistrictGround.set_town(
		ground_material, centre, reach.max(Vector2.ONE * TOWN_GROUND_MIN_REACH), level
	)


## A reviewed kind's high-detail model over the game's own, the one shown near the camera and the
## other beyond it.
func _near_detail(model: MeshInstance3D, kind: String, yaw: float, lit: bool) -> void:
	var near: Node3D = DistrictArt.building(kind, lit)
	if near == null:
		return
	var reach: float = NEAR_DETAIL_M * DistrictPlan.UNIT
	for child: Node in model.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visibility_range_begin = reach
	near.rotation.y = yaw
	near.position.y = 0.0
	model.add_child(near)
	for part: Node in near.find_children("*", "GeometryInstance3D", true, false):
		(part as GeometryInstance3D).visibility_range_end = reach


## The status beacon at a footprint's corner, and a pit's retaining wall round its footprint: no
## pad, the ground is graded flat under the building (region_ground.gd).
func _town_base(active: bool, pit_depth: float, size: Vector2) -> ArrayMesh:
	var key: String = "townbase|%s|%.2f|%.2f|%.2f" % [str(active), pit_depth, size.x, size.y]
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
	var unit: float = DistrictPlan.UNIT
	if pit_depth > 0.0:
		var wall := BoxMesh.new()
		wall.size = Vector3(size.x, pit_depth + .68, size.y)
		var ring := _mesh(
			root,
			wall,
			Vector3(0, (pit_depth + .08 - .6) * .5, 0),
			_mat("pad", Color("43545a"), .3, .85)
		)
		ring.material_override = _double_sided(_mat("pad", Color("43545a"), .3, .85))
	var corner := Vector3(size.x * .5 + 2.0 * unit, 0, -size.y * .5 - 2.0 * unit)
	_cylinder(
		root,
		corner + Vector3(0, 3.0 * unit, 0),
		.35 * unit,
		6.0 * unit,
		_mat("metal", Color("73818a"), .6, .4),
		6
	)
	_sphere(root, corner + Vector3(0, 6.4 * unit, 0), .7 * unit, accent, 8, 4)
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


## The ground under paving: the ground's own triangles, or over water a deck.
func _paving_height(x: float, z: float) -> float:
	var level: float = _mesh_ground(x, z)
	var water: float = _water_height_at(x, z, 1.5)
	return maxf(level, water + .24) if is_finite(water) else level


func _dress_traffic(dressed: Traffic) -> void:
	if town_streets == null:
		return
	# A generated town (1.12): the reviewed vehicles at their metric size, on the bent streets,
	# keeping to the right of a lane's centre.
	var key: int = district_key()
	dressed.warp = func(at: Vector2) -> Vector2: return DistrictPlan.warp(at, key)
	dressed.vehicle_factory = func(kind: String) -> Node3D: return DistrictArt.vehicle(kind)
	dressed.surface_height = _paving_height
	dressed.keep_right = 1.6 * DistrictPlan.UNIT
	dressed.speed = 0.85


func _town_road(a: Vector3, b: Vector3) -> void:
	# A generated town paves its roads once built (`_finish_town_streets`); bridges follow the
	# bent road.
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	town_roads.append([PackedVector2Array([from, to]), "lane"])
	var key: int = district_key()
	var pieces: int = maxi(1, ceili(from.distance_to(to) / 1.6))
	for index: int in range(pieces):
		var p0: Vector2 = DistrictPlan.warp(from.lerp(to, float(index) / pieces), key)
		var p1: Vector2 = DistrictPlan.warp(from.lerp(to, float(index + 1) / pieces), key)
		_note_bridge(Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p1.y))


## The field's trees, shrubs, grass and boulders, clear of the town just drawn (district_nature.gd).
## They stand on the region's ground, not with its buildings, and are scattered again only when
## the paving or the buildings' footprints have changed, not when a building's lights or state do.
func _build_district_nature() -> void:
	var signature: String = _nature_signature()
	var kept: Node = surface.get_node_or_null("DistrictNature")
	if kept != null and str(surface.get_meta("nature_signature", "")) == signature:
		return
	if kept != null:
		surface.remove_child(kept)
		kept.queue_free()
	var nature := Node3D.new()
	nature.name = "DistrictNature"
	surface.add_child(nature)
	surface.set_meta("nature_signature", signature)
	var reg: Dictionary = world.regions[selected_region]
	var seed_value: int = int(world.get("seed", 0)) * 977 + selected_region * 173
	var ore: bool = float(reg.get("deposits", {}).get("ore", 0.0)) > 6000.0
	nature_counts = DistrictNature.build(nature, self, seed_value, town_fringe, town_lots, ore)


## What the nature stands clear of: the paving's extent and edges, and every building's footprint.
func _nature_signature() -> String:
	var parts: PackedStringArray = [str(selected_region), str(town_fringe.get("rect", ""))]
	if town_streets != null:
		parts.append(str(town_streets.edges.size()))
		for entry: Array in town_streets.edges:
			var path: PackedVector2Array = entry[0]
			parts.append("%d:%.3f:%.3f" % [path.size(), path[0].x + path[-1].y, float(entry[1])])
	for lot: Dictionary in town_lots:
		parts.append("%.3f,%.3f,%s" % [Vector2(lot.pos).x, Vector2(lot.pos).y, str(lot.kind)])
	return ",".join(parts).md5_text()


## A generated region with no town yet: its own ground and nature round the survey lander.
func _build_wild_district() -> void:
	town_spots.clear()
	town_lots.clear()
	town_fringe = {}
	if ground_material != null:
		DistrictGround.set_fringe(ground_material, town_fringe)
		var centre := Vector2(_town_offset(), 0.0)
		(
			DistrictGround
			. set_town(
				ground_material,
				centre,
				Vector2.ONE * TOWN_GROUND_MARGIN * 1.5,
				_ground(centre.x, centre.y),
			)
		)
	_build_district_nature()
