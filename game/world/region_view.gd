extends "res://world/region_ground.gd"
## The colony scene on the regional ground (region_ground.gd): buildings on their terraces, the
## service lanes and roads, route gates, harbour, shuttle pads, traffic, lamps and smoke. Free
## plots are instanced; each building kind is one baked mesh.

const Traffic = preload("res://world/traffic.gd")
const ModelArt = preload("res://world/model_art.gd")
const Landmarks = preload("res://world/landmarks.gd")
## Landmarks around the town (`_landmark_spots`): rings in units from the town's centre, spots per
## ring, how far from plots and from each other, how far above the sea, how steep the ground may
## be across three units, and where the name floats.
const LANDMARK_RINGS: Array[float] = [15.0, 19.0, 23.0, 27.0]
const LANDMARK_SPOKES: int = 16
const LANDMARK_PLOT_CLEARANCE: float = 4.5
const LANDMARK_SPACING: float = 5.0
const LANDMARK_ABOVE_SEA: float = 0.4
const LANDMARK_MAX_RISE: float = 1.0
const LANDMARK_LABEL_HEIGHT: float = 4.2
## Deck height of the bridge model above its origin, in game units (5.03 m at 0.09 units a metre).
const BRIDGE_DECK: float = 0.45
const BRIDGE_LENGTH: float = 1.98
const SHIP_CYCLE_S: Vector4 = Vector4(26.0, 12.0, 26.0, 14.0)
## A shuttle's day in town seconds: on the pad, lifting, flying out, away, flying back, landing.
const SHUTTLE_CYCLE_S: Array[float] = [16.0, 3.0, 5.0, 14.0, 5.0, 3.0]
const SHUTTLE_HOVER: float = 2.4
const SHUTTLE_CRUISE: float = 9.0
const SHUTTLE_REACH: float = 30.0
## Cargo docks by level (small, medium, large): the model each would use, and how much bigger
## the standard quay is drawn while that model has not been delivered.
const DOCK_MODELS: Array[String] = ["harbor", "dock_medium", "dock_large"]
const DOCK_GROWTH: Array[float] = [1.0, 1.25, 1.5]
## Gift technologies (1.9) the town shows: [technology, model, stand-in model, stand-in scale].
## The bulk carrier is drawn before the fast freighter when the colony has both.
const GIFT_SHIPS: Array = [
	["bulk_freighters", "ship_bulk", "cargo_ship", 1.25],
	["fast_freighters", "ship_fast", "cargo_ship", 0.9]
]
## The quay's search for a shore: headings tried, step length, how far it keeps from plot
## centres and from the main street, the height above the sea that counts as a cliff, and what
## a crowded or steep shore costs against a farther one (units of reach).
const HARBOR_HEADINGS: int = 48
const HARBOR_STEP: float = 0.5
const HARBOR_PLOT_CLEAR: float = 5.0
const HARBOR_STREET_CLEAR: float = 2.0
const HARBOR_CLIFF: float = 1.5
const HARBOR_CLIFF_COST: float = 6.0
const HARBOR_CROWDED: float = 1000.0
## Forward+ lamps: how many, how high, how far they reach (times the painted pool's size), their
## colour and their brightness at full night.
const MAX_LAMP_LIGHTS: int = 64
const LAMP_HEIGHT: float = 1.5
const LAMP_REACH: float = 2.2
const LAMP_COLOR: Color = Color(1.0, 0.78, 0.52)
const LAMP_ENERGY: float = 1.6
const RED_BALL_TECH: String = "red_ball_express"
const RED_BALL_SHELL: String = "b8322a"
## Building roles whose working plants send up steam or smoke.
const SMOKE_ROLES: Array[String] = ["factory", "harvest", "great"]
const SMOKE_KINDS: Array[String] = ["geothermal", "fission", "fusion", "smelter", "processor"]
## Service lanes run between the rows of plots, half a slot from each; a building's spur stops at
## the front of its pad, so nothing drives into it.
const LANE_OFFSET: float = 3.0
const PAD_FRONT: float = 2.55
## Free plots: the radius their marks cover, the width of a planning ring (share of the radius)
## and the rocks that show a deposit.
const PLOT_MARK_RADIUS: float = 1.9
const PLOT_RING_WIDTH: float = 0.07
const PLOT_ROCKS: int = 3
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

var baked_models: Dictionary = {}
var road_tool: SurfaceTool
var road_sections: int = 0
## The living town of the region on show: vehicles, light pools, smoke.
var traffic: Traffic
var region_gates: Array = []
var smoke_emitters: Array = []
var glow_material: ShaderMaterial
## Real lamp lights in Forward+ (高画质), one per street lamp and working building.
var lamp_lights: Array[OmniLight3D] = []
## The free-plot rings (shown only when the player turns plot marks on) and that setting.
var plot_marks_node: MultiMeshInstance3D
var plot_marks_on: bool = false
## Road sections over water in the town being built, joined into runs: one bridge each.
var bridge_runs: Array = []
## The cargo ship of a coastal town: where it sails from and to, and how far it is in its cycle.
var ship: Node3D
var ship_route: Array = []
## [{"craft": Node3D, "pad": Vector3, "away": Vector3, "clock": float}]
var shuttle_flights: Array = []
var ship_clock: float = 0.0
var _wet_run: Dictionary = {}


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
				(
					route_state
					. append(
						[
							int(road.get("a", -1)),
							int(road.get("b", -1)),
							Geo.road_blocked(road, int(state.get("day", 0))),
							int(road.get("level", 1)),
						]
					)
				)
			var gifts: Array = []
			for tech: String in [RED_BALL_TECH, "fast_freighters", "bulk_freighters"]:
				gifts.append(_has_tech(tech))
			var marks: Array = []
			for mark: Dictionary in state.get("events_v2", {}).get("landmarks", []):
				if int(mark.region) == selected_region:
					marks.append(str(mark.id))
			return (
				JSON.stringify(visible_status)
				+ JSON.stringify(route_state)
				+ str(settlement.get("base_housing", 0))
				+ str(gifts)
				+ str(marks)
			)
	return "unsettled"


## The landmarks events left here, each on its spot around the town with its name above it.
func _build_landmarks() -> void:
	var standing: Array[Dictionary] = []
	for mark: Dictionary in state.get("events_v2", {}).get("landmarks", []):
		if int(mark.region) == selected_region:
			standing.append(mark)
	if standing.is_empty():
		return
	var spots: Array[Vector3] = _landmark_spots(standing.size())
	for index: int in range(mini(standing.size(), spots.size())):
		var mark: Dictionary = standing[index]
		var root := Node3D.new()
		root.name = "Landmark_" + str(mark.id)
		root.position = spots[index]
		buildings_root.add_child(root)
		Landmarks.draw(self, root, str(mark.kind))
		var label := Label3D.new()
		label.text = str(mark.name)
		label.font = label_font
		label.font_size = 44
		label.pixel_size = .02
		label.position = Vector3(0, LANDMARK_LABEL_HEIGHT, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("e8c77f")
		label.outline_modulate = Color("091621")
		label.outline_size = 10
		root.add_child(label)


## Where landmarks stand: rings around the town, taken in a fixed order, each spot clear of the
## plots, the main street, the water, steep ground and the other landmarks, so a landmark keeps its
## place from one visit to the next.
func _landmark_spots(count: int) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var town := Vector2(_town_offset(), 0.0)
	var plots: Array = world.regions[selected_region].get("plots", [])
	var floor_height: float = sea_level() + LANDMARK_ABOVE_SEA
	for ring: int in range(LANDMARK_RINGS.size()):
		for step: int in range(LANDMARK_SPOKES):
			if spots.size() >= count:
				return spots
			var angle: float = TAU * (step + 0.5 * ring) / LANDMARK_SPOKES
			var at: Vector2 = town + Vector2(cos(angle), sin(angle)) * LANDMARK_RINGS[ring]
			if absf(at.x) > half_width - 4.0 or absf(at.y) > half_depth - 4.0:
				continue
			if absf(at.y) < 2.5:
				continue
			var clear: bool = true
			for plot: Dictionary in plots:
				if at.distance_to(Vector2(float(plot.x), float(plot.z))) < LANDMARK_PLOT_CLEARANCE:
					clear = false
					break
			for taken: Vector3 in spots:
				if at.distance_to(Vector2(taken.x, taken.z)) < LANDMARK_SPACING:
					clear = false
			if not clear:
				continue
			var height: float = _ground(at.x, at.y)
			if height < floor_height or is_finite(_water_height_at(at.x, at.y, 1.2)):
				continue
			var rise: float = 0.0
			for offset: Vector2 in [
				Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)
			]:
				rise = maxf(rise, absf(_ground(at.x + offset.x, at.y + offset.y) - height))
			if rise > LANDMARK_MAX_RISE:
				continue
			spots.append(Vector3(at.x, height, at.y))
	return spots


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
	var rings: Array = []
	var patches: Array = []
	var rocks: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.get("seed", 0)) * 7 + selected_region * 131
	var plots: Array = world.regions[selected_region].get("plots", [])
	for index: int in range(plots.size()):
		var plot: Dictionary = plots[index]
		if taken.has(index) or bool(plot.get("hidden", false)):
			continue
		if float(plot.get("reserves", 1.0)) <= 0.0:
			continue
		var color: Color = PLOT_COLORS.get(str(plot.get("resource", plot.kind)), Color.WHITE)
		var x: float = float(plot.x)
		var z: float = float(plot.z)
		var at := Vector3(x, _ground(x, z), z)
		var spread := Basis.IDENTITY.scaled(Vector3(PLOT_MARK_RADIUS, 1.0, PLOT_MARK_RADIUS))
		rings.append(
			[Transform3D(spread, at + Vector3(0, .06, 0)), Color(color.lightened(.25), .7)]
		)
		if str(plot.kind) == "farm":
			patches.append([Transform3D(spread, at + Vector3(0, .04, 0)), Color(color, .3)])
		elif str(plot.kind) == "deposit":
			patches.append([Transform3D(spread, at + Vector3(0, .04, 0)), Color(color, .22)])
			for _rock: int in range(PLOT_ROCKS):
				var offset := Vector2(rng.randf_range(.2, .95), 0.0).rotated(rng.randf() * TAU)
				var size: float = rng.randf_range(.16, .3)
				var turn := Basis(Vector3.UP, rng.randf() * TAU).scaled(
					Vector3(size, size * .7, size)
				)
				var rx: float = x + offset.x
				var rz: float = z + offset.y
				rocks.append(
					[
						Transform3D(turn, Vector3(rx, _ground(rx, rz) + size * .25, rz)),
						color.lerp(Color("6f6a63"), .35)
					]
				)
	if not patches.is_empty():
		var soft: MultiMeshInstance3D = _instanced(_plot_plane(), _plot_material(0.0), patches)
		soft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		buildings_root.add_child(soft)
	if not rocks.is_empty():
		var stone := SphereMesh.new()
		stone.radius = 1.0
		stone.height = 1.4
		stone.radial_segments = 7
		stone.rings = 3
		var outcrop: MultiMeshInstance3D = _instanced(
			stone, _natural_material("plotrock", .95), rocks
		)
		buildings_root.add_child(outcrop)
	plot_marks_node = null
	if not rings.is_empty():
		plot_marks_node = _instanced(_plot_plane(), _plot_material(PLOT_RING_WIDTH), rings)
		plot_marks_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plot_marks_node.visible = plot_marks_on
		buildings_root.add_child(plot_marks_node)


## Free-plot rings for planning, on or off; the setting holds across towns and rebuilds.
func set_plot_marks(on: bool) -> void:
	plot_marks_on = on
	if plot_marks_node != null and is_instance_valid(plot_marks_node):
		plot_marks_node.visible = on


func _plot_plane() -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	return plane


func _plot_material(ring: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Shaders.shader("plotmark")
	material.set_shader_parameter("ring", ring)
	return material


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
	_build_landmarks()
	road_tool = SurfaceTool.new()
	road_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_sections = 0
	region_gates.clear()
	smoke_emitters.clear()
	var stops: Array = []
	var pools: Array = []
	# Generated towns are laid out on the plot grid: lanes between the rows, spurs to each pad.
	var lanes: bool = Geo.is_generated(str(world.version))
	var street_ends := Vector2(-12.0, 12.0)
	if int(settlement.get("base_housing", 0)) > 0:
		_build_base_housing(offset, int(settlement.base_housing))
		var pods: Vector2 = _pods_position(offset)
		if lanes:
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
		else:
			stops.append({"end": pods, "z": 0.0, "kind": "base", "active": true})
	var roles: Dictionary = Rules.read("economy").buildings
	var buildings: Array = settlement.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var slot: Vector2 = _building_spot(i, b, offset)
		var reach: Dictionary = _access(slot) if lanes and int(b.get("plot", -1)) >= 0 else {}
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
		var yaw: float = _street_yaw(slot.x, offset) if reach.is_empty() else float(reach.yaw)
		if not art.is_empty():
			_dress_building(model, b, art, active, complete, yaw)
		elif not complete:
			_construction_frame(model)
		if reach.is_empty():
			_road(Vector3(offset, 0, slot.y), Vector3(slot.x, 0, slot.y))
			stops.append({"end": slot, "z": slot.y, "kind": str(b.kind), "active": active})
		else:
			var lane: float = float(reach.lane)
			var front: Vector2 = reach.front
			_road(Vector3(offset, 0, lane), Vector3(slot.x, 0, lane))
			_road(Vector3(slot.x, 0, lane), Vector3(front.x, 0, front.y))
			street_ends = Vector2(minf(street_ends.x, lane), maxf(street_ends.y, lane))
			stops.append(
				{
					"end": front,
					"via": Vector2(slot.x, lane),
					"z": lane,
					"kind": str(b.kind),
					"active": active
				}
			)
		if active:
			pools.append([model.position, 2.6])
			var role: String = str(roles.get(str(b.kind), {}).get("role", ""))
			if role in SMOKE_ROLES or str(b.kind) in SMOKE_KINDS:
				_add_smoke(model)
	_road(Vector3(offset, 0, street_ends.x), Vector3(offset, 0, street_ends.y))
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
	var spot: Vector2 = _pods_position(offset)
	root.position = Vector3(spot.x, _ground(spot.x, spot.y), spot.y)
	buildings_root.add_child(root)
	var pods: MeshInstance3D = ModelArt.instance(
		"landing_pods", func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if pods != null:
		_cylinder(root, Vector3(0, -.22, 0), 2.6, .6, _mat("pad", Color("43545a"), .3, .85), 8)
		pods.position.y = .08
		root.add_child(pods)
		_base_housing_label(root, capacity)
		_pods_road(offset)
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
	_pods_road(offset)


## Where the landing pods stand: beside the street on older worlds, on a cell of their own on
## generated ones (region_ground.gd `pods_spot`).
func _pods_position(offset: float) -> Vector2:
	if not Geo.is_generated(str(world.version)):
		return Vector2(offset - 6.0, 0.0)
	if terrace_region != selected_region:
		_prepare_terraces()
	return pods_spot


## The landing pods' road: straight in on older worlds, by the lane and a spur on generated ones.
func _pods_road(offset: float) -> void:
	if not Geo.is_generated(str(world.version)):
		_road(Vector3(offset, 0, 0), Vector3(offset - 6.0, 0, 0))
		return
	var spot: Vector2 = _pods_position(offset)
	var reach: Dictionary = _access(spot)
	var lane: float = float(reach.lane)
	var front: Vector2 = reach.front
	_road(Vector3(offset, 0, lane), Vector3(spot.x, 0, lane))
	_road(Vector3(spot.x, 0, lane), Vector3(front.x, 0, front.y))


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
	if Geo.is_generated(str(world.version)) and absf(direction.x) > 0.5:
		start.y = LANE_OFFSET
	var finish := start + direction * gate_reach
	finish.x = clampf(finish.x, -half_width + 2.0, half_width - 2.0)
	finish.y = clampf(finish.y, -half_depth + 2.0, half_depth - 2.0)
	if str(route.get("variant", "")) == "shuttle":
		_build_shuttle_pad(route, finish, direction, to, start)
		return
	_road(Vector3(start.x, 0, start.y), Vector3(finish.x, 0, finish.y))
	var day: int = int(state.get("day", 0))
	if not Geo.road_building(route, day) and not Geo.road_blocked(route, day):
		region_gates.append({"end": finish, "junction": start})
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
	var along := Vector2(b.x - a.x, b.z - a.z)
	if along.length() < .001:
		return
	var side: Vector2 = along.normalized().orthogonal() * .36
	a.y = _road_level(a, side)
	b.y = _road_level(b, side)
	var aa := Vector3(a.x - side.x, a.y, a.z - side.y)
	var ab := Vector3(a.x + side.x, a.y, a.z + side.y)
	var ba := Vector3(b.x - side.x, b.y, b.z - side.y)
	var bb := Vector3(b.x + side.x, b.y, b.z + side.y)
	for vertex: Vector3 in [aa, ba, ab, ab, ba, bb]:
		road_tool.add_vertex(vertex)
	road_sections += 1


## A road's deck at a point: on the ground, over water as a bridge. In generated towns it rides
## on the higher of its two edges, so a lane across a slope never sinks into the bank.
func _road_level(at: Vector3, side: Vector2) -> float:
	var level: float = _ground(at.x, at.z)
	if Geo.is_generated(str(world.version)):
		level = maxf(
			level,
			maxf(_ground(at.x + side.x, at.z + side.y), _ground(at.x - side.x, at.z - side.y))
		)
	return maxf(level + .16, _water_height_at(at.x, at.z, 1.5) + .24)


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
## that sails in, berths and leaves. Enlarged docks (1.9) use their own model once one is
## delivered (`dock_medium`, `dock_large`), and until then a bigger quay and ship.
func _build_harbor(settlement: Dictionary, offset: float) -> void:
	ship = null
	ship_route.clear()
	if not field_has_sea or not _harbor_wanted(settlement):
		return
	var best: Dictionary = _harbor_shore(Vector2(offset, 0.0), sea_level())
	if best.is_empty():
		return
	var sea_level: float = sea_level()
	var heading: Vector2 = best.heading
	var shore: Vector2 = best.shore
	var level: int = _dock_level()
	var model: String = DOCK_MODELS[level - 1]
	var grown: float = 1.0
	if not ModelArt.registry().get("models", {}).has(model):
		model = "harbor"
		grown = DOCK_GROWTH[level - 1]
	var quay: MeshInstance3D = ModelArt.instance(
		model, func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if quay == null:
		return
	quay.position = Vector3(shore.x, maxf(_ground(shore.x, shore.y), sea_level) - .05, shore.y)
	# The quay's sea side is the model's -z: turn it to face the open water.
	quay.rotation.y = atan2(-heading.x, -heading.y)
	quay.scale = Vector3.ONE * grown
	buildings_root.add_child(quay)
	var calling: Array = _gift_ship()
	var vessel: MeshInstance3D = ModelArt.instance(
		str(calling[0]), func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if vessel == null:
		return
	vessel.scale = Vector3.ONE * sqrt(grown) * float(calling[1])
	var side := Vector2(-heading.y, heading.x)
	var berth: Vector2 = shore + heading * 2.4 * grown + side * 0.6
	var offing: Vector2 = berth + heading * 30.0 + side * 6.0
	offing.x = clampf(offing.x, -half_width + 3.0, half_width - 3.0)
	offing.y = clampf(offing.y, -half_depth + 3.0, half_depth - 3.0)
	ship_route = [
		Vector3(offing.x, sea_level - .02, offing.y), Vector3(berth.x, sea_level - .02, berth.y)
	]
	ship = vessel
	buildings_root.add_child(vessel)
	_sail(0.0)


func _has_tech(tech: String) -> bool:
	return state.get("research", {}).get("completed", []).has(tech)


## The ship that calls here: a gift freighter's model once delivered (a resized cargo ship until
## then), or the standard cargo ship. [model, scale]
func _gift_ship() -> Array:
	for gift: Array in GIFT_SHIPS:
		if not _has_tech(str(gift[0])):
			continue
		if ModelArt.registry().get("models", {}).has(str(gift[1])):
			return [str(gift[1]), 1.0]
		return [str(gift[2]), float(gift[3])]
	return ["cargo_ship", 1.0]


## Where the quay goes: the nearest point of shore, walked out from the town in small steps, that
## leaves room for the plots and the street and is not a cliff top. A crowded or steep shore is
## taken only when there is no other. {shore, heading} or empty.
func _harbor_shore(town: Vector2, sea_level: float) -> Dictionary:
	var plots: Array = []
	for plot: Dictionary in world.regions[selected_region].get("plots", []):
		plots.append(Vector2(float(plot.x), float(plot.z)))
	var best: Dictionary = {}
	var reach_limit: float = maxf(half_width, half_depth) - 2.0
	for step: int in range(HARBOR_HEADINGS):
		var heading := Vector2.RIGHT.rotated(TAU * float(step) / HARBOR_HEADINGS)
		var last_land: Vector2 = town
		var reach: float = HARBOR_STEP
		while reach < reach_limit:
			var at: Vector2 = town + heading * reach
			if absf(at.x) > half_width - 3.0 or absf(at.y) > half_depth - 3.0:
				break
			if _ground(at.x, at.y) < sea_level - .1:
				var cost: float = reach
				var crowded: bool = absf(last_land.x - town.x) < HARBOR_STREET_CLEAR
				for centre: Vector2 in plots:
					crowded = crowded or centre.distance_to(last_land) < HARBOR_PLOT_CLEAR
				if crowded:
					cost += HARBOR_CROWDED
				var height: float = _ground(last_land.x, last_land.y) - sea_level
				cost += maxf(0.0, height - HARBOR_CLIFF) * HARBOR_CLIFF_COST
				if best.is_empty() or cost < float(best.cost):
					best = {"cost": cost, "shore": last_land, "heading": heading}
				break
			last_land = at
			reach += HARBOR_STEP
	return best


## The biggest docks a finished sea link gives this town: 1 small, 2 medium, 3 large.
func _dock_level() -> int:
	var level: int = 1
	var day: int = int(state.get("day", 0))
	for route: Dictionary in state.get("roads", []):
		if str(route.get("variant", "")) != "sea" or Geo.road_building(route, day):
			continue
		if int(route.get("a", -1)) == selected_region or int(route.get("b", -1)) == selected_region:
			level = maxi(level, int(route.get("level", 1)))
	return clampi(level, 1, DOCK_MODELS.size())


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
	route: Dictionary, finish: Vector2, direction: Vector2, to: Dictionary, junction: Vector2
) -> void:
	var day: int = int(state.get("day", 0))
	var spot: Vector2 = _pad_spot(finish, direction)
	var pad := Vector3(spot.x, _ground(spot.x, spot.y), spot.y)
	var building: bool = Geo.road_building(route, day)
	var deck: String = "shuttle_pad"
	if building and ModelArt.mesh("shuttle_pad_construction") != null:
		deck = "shuttle_pad_construction"
	var modelled: MeshInstance3D = ModelArt.instance(
		deck, func(slot: String) -> Material: return _art_material(slot, {}, true)
	)
	if modelled != null:
		modelled.position = pad
		buildings_root.add_child(modelled)
	else:
		_plain_pad(pad)
	if not building:
		region_gates.append({"end": spot, "junction": junction})
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


## The pad drawn until the `shuttle_pad` model exists: a deck, a touchdown ring, corner lights.
func _plain_pad(pad: Vector3) -> void:
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


## The `shuttle` model, legs down, and `shuttle_flight`, legs up, under one node that flies; the
## models face +z, so the craft is turned with `model_front`. A simple lifting body without them.
func _shuttle_craft() -> Node3D:
	var material_for: Callable = func(slot: String) -> Material:
		return _art_material(slot, {}, true)
	var parked: MeshInstance3D = ModelArt.instance("shuttle", material_for)
	if parked != null:
		var modelled := Node3D.new()
		modelled.set_meta("model_front", true)
		parked.name = "Parked"
		modelled.add_child(parked)
		var flying: MeshInstance3D = ModelArt.instance("shuttle_flight", material_for)
		if flying != null:
			flying.name = "Flying"
			flying.visible = false
			modelled.add_child(flying)
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
		# Legs come up once clear of the pad and go down just before touching it.
		var flying: Node3D = craft.get_node_or_null("Flying") as Node3D
		if flying != null:
			var low: bool = phase == 0 or (phase == 1 and share < .3) or (phase == 5 and share > .7)
			flying.visible = not low
			(craft.get_node("Parked") as Node3D).visible = low
		if facing.length() > 0.01:
			craft.look_at(
				at + facing.normalized(), Vector3.UP, bool(craft.get_meta("model_front", false))
			)


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
## A building on the plot grid is reached from the lane between its row and the next row towards
## the middle of town, by a short spur that stops at the front of its pad, and it faces that lane
## (the models' front is +z). Vehicles wait at the spur's end, never inside the building.
static func _access(slot: Vector2) -> Dictionary:
	var side: float = -1.0 if slot.y > 0.0 else 1.0
	return {
		"lane": slot.y + side * LANE_OFFSET,
		"front": Vector2(slot.x, slot.y + side * PAD_FRONT),
		"yaw": 0.0 if side > 0.0 else PI,
	}


static func _street_yaw(x: float, street_x: float) -> float:
	if x < street_x - 0.5:
		return PI * 0.5
	if x > street_x + 0.5:
		return -PI * 0.5
	return 0.0


## The building's model; its own construction state while it is being built (the shared site kit
## for kinds without one); a closed mine once the deposit under it is worked out. A great work's
## finished stages or levels (`addons` in the registry) stand on its frame.
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
	var own_site: bool = false
	if not complete:
		var site: String = str(art.get("construction", ""))
		own_site = site != "" and ModelArt.mesh(site) != null
		id = site if own_site else "construction"
		if not own_site:
			scale = 1.2 if great else 1.0
	elif art.has("ore") and _plot_depleted(building):
		id = "depleted_" + str(art.ore)
	var material_for: Callable = func(slot: String) -> Material:
		return _art_material(slot, art, active)
	var dressed: MeshInstance3D = ModelArt.instance(id, material_for)
	if dressed == null:
		return
	dressed.rotation.y = yaw
	dressed.scale = Vector3.ONE * scale
	# Seated on the pad top; a pit's floor on the ground.
	dressed.position.y = .08 + _pit_depth(art, complete)
	model.add_child(dressed)
	if complete and id == str(art.model):
		var addons: Array = art.get("addons", [])
		for index: int in range(mini(int(building.get("level", 1)) - 1, addons.size())):
			var stage: MeshInstance3D = ModelArt.instance(str(addons[index]), material_for)
			if stage == null:
				continue
			stage.rotation.y = yaw
			stage.scale = dressed.scale
			stage.position.y = dressed.position.y
			model.add_child(stage)
	# A construction state of its own brings its scaffold, and a great work's its crane.
	if not complete and great and not own_site:
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
		"truck": _red_ball_truck() if _has_tech(RED_BALL_TECH) else _vehicle_mesh("truck"),
		"van": _vehicle_mesh("van"),
		"bus": _vehicle_mesh("bus"),
	}
	traffic.surface_height = _road_height
	traffic.street_x = offset
	traffic.stops = stops
	traffic.gates = region_gates.duplicate()
	traffic.setup(int(world.seed) * 31 + region, 2 + working / 2 + region_gates.size() * 2)


## Trucks of the red-ball express (a gift technology): their own model once one is delivered, the
## standard truck painted red until then.
func _red_ball_truck() -> ArrayMesh:
	var key: String = "vehicle|truck_redball"
	if baked_models.has(key):
		return baked_models[key]
	var model_id: String = "vehicle_truck_redball"
	var art: Dictionary = {}
	if not ModelArt.registry().get("models", {}).has(model_id):
		model_id = "vehicle_truck"
		art = {"shell": RED_BALL_SHELL}
	if not ModelArt.registry().get("models", {}).has(model_id):
		return _vehicle_mesh("truck")
	var tinted: ArrayMesh = ModelArt.mesh(model_id).duplicate() as ArrayMesh
	for index: int in range(tinted.get_surface_count()):
		tinted.surface_set_material(index, _art_material(tinted.surface_get_name(index), art, true))
	baked_models[key] = tinted
	return tinted


## A traffic vehicle: the `vehicle_<kind>` model with its slot colours once one is delivered, a
## procedural one until then.
func _vehicle_mesh(kind: String) -> ArrayMesh:
	var key: String = "vehicle|" + kind
	if baked_models.has(key):
		return baked_models[key]
	var model: ArrayMesh = ModelArt.mesh("vehicle_" + kind)
	if model != null:
		var tinted: ArrayMesh = model.duplicate() as ArrayMesh
		for index: int in range(tinted.get_surface_count()):
			tinted.surface_set_material(
				index, _art_material(tinted.surface_get_name(index), {}, true)
			)
		baked_models[key] = tinted
		return tinted
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
	lamp_lights.clear()
	if pools.is_empty():
		return
	if high_quality:
		_build_lamp_lights(pools)
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


## Forward+ lights the town with real lamps (no shadows; Forward+ handles many small lights),
## where Compatibility paints pools of light on the ground. Their brightness follows the night.
func _build_lamp_lights(pools: Array) -> void:
	var lamps := Node3D.new()
	lamps.name = "LampLights"
	buildings_root.add_child(lamps)
	for pool: Array in pools.slice(0, MAX_LAMP_LIGHTS):
		var at: Vector3 = pool[0]
		var light := OmniLight3D.new()
		light.position = Vector3(at.x, _ground(at.x, at.z) + LAMP_HEIGHT, at.z)
		light.omni_range = float(pool[1]) * LAMP_REACH
		light.omni_attenuation = 1.6
		light.light_color = LAMP_COLOR
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.visible = false
		lamps.add_child(light)
		lamp_lights.append(light)


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
