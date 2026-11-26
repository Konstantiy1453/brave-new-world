extends "res://world/region_view.gd"
## A generated world's town in metres (1.12): the approved district's revision 06 and 07 on the
## live settlement (district_plan.gd, district_art.gd, district_streets.gd). The buildings, their
## plots, kinds and states come from the save; the town grid is bent into curving streets, every
## building is drawn at its metric size, the reviewed kinds from their high-detail models near the
## camera, and the paving at metric widths. Older worlds keep region_view.gd's town.


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
	# Each lane runs from the main street out to its furthest building on either side.
	var lane_reach: Dictionary = {}
	if int(settlement.get("base_housing", 0)) > 0:
		var camp: float = float(
			LightField.housing_shares(settlement, Rules.read("economy").buildings).get(
				LightField.CAMP, 0.0
			)
		)
		_build_base_housing(offset, int(settlement.base_housing), camp > 0.0)
		var pods: Vector2 = _pods_position(offset)
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
		_note_lane(lane_reach, float(reach.lane), pods.x, "lane")
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
			else slot_lot(_building_spot(i, b, offset), str(b.kind), 1000 + i)
		)
		var complete: bool = int(b.get("remaining", b.get("days_left", 0))) <= 0
		var active: bool = b.get("enabled", true) and b.get("active", true) and complete
		var lit: bool = LightField.home_lit(b, roles, shares)
		var art: Dictionary = ModelArt.kind_entry(str(b.kind))
		var at: Vector2 = lot.pos
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
		_note_lane(lane_reach, reach_lane, slot.x, lane_kind)
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
	for lane: float in lane_reach:
		var reach: Dictionary = lane_reach[lane]
		for side: String in ["west", "east"]:
			if not reach.has(side):
				continue
			var end: float = float(reach[side])
			var beyond: float = end + (-0.9 if side == "west" else 0.9)
			town_roads.append(
				[PackedVector2Array([Vector2(offset, lane), Vector2(beyond, lane)]), reach.kind]
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
	_finish_roads()
	_build_bridges()
	_build_harbor(settlement)
	_build_company_ship(settlement, offset)
	_build_light_pools(pools)
	_build_traffic(stops, offset, int(settlement.get("region", 0)))


func _note_lane(reach: Dictionary, lane: float, x: float, kind: String) -> void:
	if not reach.has(lane):
		reach[lane] = {"kind": kind}
	var entry: Dictionary = reach[lane]
	var offset: float = _town_offset()
	var side: String = "west" if x < offset else "east"
	entry[side] = (
		minf(float(entry.get(side, x)), x) if side == "west" else maxf(float(entry.get(side, x)), x)
	)
	if kind == "works":
		entry.kind = "works"


## The town's streets, bent and paved (district_streets.gd).
func _finish_town_streets() -> void:
	var key: int = district_key()
	for entry: Array in town_roads:
		town_streets.street(DistrictPlan.bent_path(entry[0], 0.5, key), str(entry[1]))
	var paving := Node3D.new()
	paving.name = "TownPaving"
	buildings_root.add_child(paving)
	town_streets.commit(paving)


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
