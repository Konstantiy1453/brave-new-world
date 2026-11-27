extends SceneTree
## The 1.9 region scene on a generated world: the landscape runs far past the playable field, every
## plot's pad is level, the landing pods stand on a cell of their own, and no vehicle route between
## stops or out to a gate passes through a building or stops inside one. A plot that comes to
## light later gets its terrace the next time the region is shown. Headless; older worlds keep
## their ground to the vertex (world_v16_terrain_identity). Since the terrain pass: no walls or mesas,
## no hexagon plates on free plots, no sea at inland sites, and no ground lying close to the sea's
## surface (it flickered against it).

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const Traffic = preload("res://world/traffic.gd")
const SEED: int = 260129
const KINDS: Array[String] = [
	"habitat", "power", "water", "farm", "mine_ore", "processor", "lab", "mine_copper", "habitat"
]
## Ground steps between neighbouring field vertices: anywhere, and near the town.
const MAX_STEP: float = 1.6
const MAX_TOWN_STEP: float = 0.8
## Where the ground crosses the sea's level between neighbouring field vertices: the gentlest
## twentieth of the crossings at least this steep, and where along the edge they cross spread at
## least this much (evenly spread is 0.29; a coast snapped to the grid measured 0.14).
const MIN_SHORE_SLOPE: float = 0.15
const MIN_SHORE_SPREAD: float = 0.2

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1, "normal")
	var pairs: Array = sim.geo.get("playability", {}).get("pairs", [[0, 1]])
	var site: int = int(pairs[0][0])
	check(sim.act("settle", {"site": site}) == "", "the colony lands")
	for kind: String in KINDS:
		sim.act("build", {"region": site, "kind": kind})
	var map: Node3D = Map.new()
	root.add_child(map)
	map.set_process(false)
	map.setup(sim.geo)
	map.sync_state(sim.state)
	map.show_region(site)
	while map.region_busy:
		await process_frame
	check(map.Geo.is_generated(str(sim.geo.version)), "the world is a generated one")
	_landscape(map)
	_pads(map, sim, site)
	_pods(map, sim, site)
	_routes(map, sim, site)
	_natural_ground(map)
	_plot_marks(map)
	await _revealed(map, sim, site)
	await _waterline(map, sim)
	await _inland(map, sim)
	root.remove_child(map)
	map.free()
	print("V19_REGION_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _landscape(map: Node3D) -> void:
	var ground: MeshInstance3D = map.surface.get_node_or_null("Landscape")
	check(ground != null, "the region is drawn as one landscape")
	if ground == null:
		return
	var box: AABB = ground.get_aabb()
	var reach: float = map.APRON_REACH * 0.95
	check(
		box.position.x < -map.half_width - reach and box.end.x > map.half_width + reach,
		"it runs far past the field east and west (%s)" % box
	)
	check(
		box.position.z < -map.half_depth - reach and box.end.z > map.half_depth + reach,
		"and north and south"
	)
	check(
		map.height_field.size() == (map.field_res + 1) * (map.field_res + 1),
		"the field keeps its grid"
	)


## No walls or mesas: between neighbouring vertices of the field the ground never jumps by more
## than a steep hillside would (vertices are about 0.86 units apart), and the town's ground is
## gentler still.
func _natural_ground(map: Node3D) -> void:
	var res: int = map.field_res
	var worst: float = 0.0
	var worst_town: float = 0.0
	for iz: int in range(res):
		for ix: int in range(res):
			var index: int = iz * (res + 1) + ix
			var step: float = maxf(
				absf(map.height_field[index + 1] - map.height_field[index]),
				absf(map.height_field[index + res + 1] - map.height_field[index])
			)
			worst = maxf(worst, step)
			var x: float = (float(ix) / res - .5) * map.field_width
			var z: float = (float(iz) / res - .5) * map.field_depth
			if Vector2(x, z).length() < map.TOWN_CALM.x:
				worst_town = maxf(worst_town, step)
	print("INFO steepest step %.2f, in town %.2f" % [worst, worst_town])
	check(worst < MAX_STEP, "no wall anywhere in the field (steepest step %.2f)" % worst)
	check(worst_town < MAX_TOWN_STEP, "the town stands on gentle ground (%.2f)" % worst_town)
	var hexagons: int = 0
	for node: Node in map.buildings_root.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh: Mesh = (node as MultiMeshInstance3D).multimesh.mesh
		if mesh is CylinderMesh and (mesh as CylinderMesh).radial_segments == 6:
			hexagons += 1
	check(hexagons == 0, "no hexagon plates on the free plots")


## Free-plot rings are for planning: hidden unless the player turns them on.
func _plot_marks(map: Node3D) -> void:
	var marks: Node3D = map.plot_marks_node
	check(marks != null and not marks.visible, "free-plot rings are hidden by default")
	map.set_plot_marks(true)
	check(marks != null and marks.visible, "and shown when plot marks are on")
	map.set_plot_marks(false)


## Ground and sea never lie close together, where they flickered against each other as the camera
## moved: at a coastal site the ground crosses the sea's level at a slope between neighbouring
## vertices (the tangent beaches of the first terrain pass crossed at 0.06 and flickered), the
## coast keeps its own shape between the grid lines (a fixed lift snapped it into steps, every
## crossing at the same fraction of the edge), and the town view keeps its own, finer near plane.
func _waterline(map: Node3D, sim: RefCounted) -> void:
	check(
		is_equal_approx(map.camera.near, map.REGION_NEAR),
		"the town view uses its own near plane (%.2f)" % map.camera.near
	)
	if not map.field_has_sea:
		var coastal: int = -1
		for reg: Dictionary in sim.state.world.regions:
			if bool(reg.coast):
				coastal = int(reg.id)
				break
		check(coastal >= 0, "the world has a coastal site")
		if coastal < 0:
			return
		map.show_planet()
		map.show_region(coastal)
		while map.region_busy:
			await process_frame
	check(map.field_has_sea, "a coastal site draws the sea")
	check(map.local_river_segments.is_empty(), "regional water omits river ribbons")
	var region: int = map.selected_region
	var plots: Array = sim.state.world.regions[region].plots
	var lowest: float = INF
	var wet: bool = false
	for index: int in range(plots.size()):
		# The school is the widest approved model. Its whole rotated footprint needs dry ground
		# even on an unoccupied parcel, before construction and terrain grading.
		var lot: Dictionary = map.plot_lot(region, index, "school")
		for row: int in range(-2, 3):
			for column: int in range(-2, 3):
				var local: Vector2 = Vector2(column, row) * Vector2(lot.size) / 4.0
				var at: Vector2 = lot.pos + local.rotated(-float(lot.yaw))
				lowest = minf(lowest, map._mesh_ground(at.x, at.y) - map.sea_level())
				wet = wet or is_finite(map._water_height_at(at.x, at.y))
	check(lowest > 0.02 and not wet, "all coastal parcels keep the largest footprint ashore")
	var harbor: Dictionary = map.harbor_spot(region)
	if not harbor.is_empty():
		var shore: Vector2 = harbor.shore
		var berth: Vector2 = map._ship_ends(harbor, 1.0)[0]
		check(map._mesh_ground(shore.x, shore.y) > map.sea_level(), "quay building stands ashore")
		check(map._mesh_ground(berth.x, berth.y) < map.sea_level(), "the berth is in open water")
	var res: int = map.field_res
	var field: PackedFloat32Array = map.height_field
	var sea: float = map.sea_level()
	var slopes: Array[float] = []
	var fractions: Array[float] = []
	for iz: int in range(res + 1):
		for ix: int in range(res + 1):
			var here: float = field[iz * (res + 1) + ix]
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if ix + step.x > res or iz + step.y > res:
					continue
				var there: float = field[(iz + step.y) * (res + 1) + ix + step.x]
				if (here - sea) * (there - sea) >= 0.0:
					continue
				var spacing: float = map.field_width / res if step.x == 1 else map.field_depth / res
				slopes.append(absf(here - there) / spacing)
				fractions.append((maxf(here, there) - sea) / absf(here - there))
	check(slopes.size() >= 20, "the field has a shore (%d crossings)" % slopes.size())
	if slopes.size() < 20:
		return
	slopes.sort()
	var gentle: float = slopes[int(slopes.size() * 0.05)]
	var mean: float = 0.0
	for value: float in fractions:
		mean += value
	mean /= fractions.size()
	var spread: float = 0.0
	for value: float in fractions:
		spread += (value - mean) * (value - mean)
	spread = sqrt(spread / fractions.size())
	print(
		(
			"INFO shore: %d crossings, slope p5 %.3f, crossing spread %.3f"
			% [slopes.size(), gentle, spread]
		)
	)
	check(
		gentle >= MIN_SHORE_SLOPE, "the ground crosses the waterline at a slope (p5 %.3f)" % gentle
	)
	check(
		spread >= MIN_SHORE_SPREAD, "the coast keeps its shape between grid lines (%.3f)" % spread
	)


## An inland site shows no sea: no sea plane, and its lowest ground stays above the sea's level.
func _inland(map: Node3D, sim: RefCounted) -> void:
	var inland: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if not bool(reg.coast) and sim.settlement(int(reg.id)).is_empty():
			inland = int(reg.id)
			break
	check(inland >= 0, "the world has an inland site")
	if inland < 0:
		return
	map.show_planet()
	map.show_region(inland)
	while map.region_busy:
		await process_frame
	check(not map.field_has_sea, "an inland site draws no sea")
	var lowest: float = INF
	for height: float in map.height_field:
		lowest = minf(lowest, height)
	check(
		lowest > map.sea_level(),
		"and its ground stays above the sea (lowest %.2f, sea %.2f)" % [lowest, map.sea_level()]
	)


## Each building's footprint as the town draws it (1.12, district_plan.gd via the map's
## `plot_lot`): bent centre, half size, yaw; and the same unbent, as the traffic's paths run.
func _footprints(map: Node3D, sim: RefCounted, site: int) -> Array:
	var out: Array = []
	for building: Dictionary in sim.settlement(site).buildings:
		var plot: int = int(building.get("plot", -1))
		if plot < 0:
			continue
		var lot: Dictionary = map.plot_lot(site, plot, str(building.kind))
		(
			out
			. append(
				{
					"centre": lot.pos,
					"yaw": float(lot.yaw),
					"plain": lot.plain,
					"plain_yaw": float(lot.plain_yaw),
					"half": Vector2(lot.size) * 0.5,
				}
			)
		)
	return out


func _pads(map: Node3D, sim: RefCounted, site: int) -> void:
	var feet: Array = _footprints(map, sim, site)
	check(feet.size() >= 6, "the town has buildings on plots (%d)" % feet.size())
	var worst: float = 0.0
	for foot: Dictionary in feet:
		var centre: Vector2 = foot.centre
		var level: float = map._ground(centre.x, centre.y)
		for sz: int in [-1, 0, 1]:
			for sx: int in [-1, 0, 1]:
				var local := Vector2(sx * foot.half.x, sz * foot.half.y)
				var at: Vector2 = centre + local.rotated(-float(foot.yaw))
				worst = maxf(worst, absf(map._ground(at.x, at.y) - level))
	check(worst < 0.05, "every footprint is level to its edge (worst %.3f)" % worst)


func _pods(map: Node3D, sim: RefCounted, site: int) -> void:
	var spot: Vector2 = map._pods_position(0.0)
	var nearest: float = INF
	for plot: Dictionary in sim.state.world.regions[site].plots:
		nearest = minf(nearest, spot.distance_to(Vector2(float(plot.x), float(plot.z))))
	check(nearest >= 5.9, "the landing pods stand on a cell no plot was given (%.1f)" % nearest)


func _routes(map: Node3D, sim: RefCounted, site: int) -> void:
	var traffic: Node = map.traffic
	check(traffic != null and not traffic.stops.is_empty(), "the town has traffic stops")
	if traffic == null:
		return
	var feet: Array = _footprints(map, sim, site)
	var paths: Array = []
	for from: Dictionary in traffic.stops:
		for to: Dictionary in traffic.stops:
			paths.append(Traffic.stop_path(from, to, traffic.street_x))
		for gate: Dictionary in traffic.gates:
			paths.append(Traffic.gate_path(from, gate, traffic.street_x))
	var crossings: PackedStringArray = []
	for points: PackedVector2Array in paths:
		for index: int in range(points.size() - 1):
			for foot: Dictionary in feet:
				if _enters(foot, points[index], points[index + 1]):
					crossings.append(
						"%s-%s through %s" % [points[index], points[index + 1], foot.plain]
					)
	check(
		crossings.is_empty(), "no route passes through a building %s" % str(crossings.slice(0, 4))
	)
	var inside: int = 0
	for stop: Dictionary in traffic.stops:
		for foot: Dictionary in feet:
			if _enters(foot, stop.end, stop.end):
				inside += 1
	check(inside == 0, "no vehicle waits inside a building (%d)" % inside)


## Whether a segment of an unbent path enters a footprint (shrunk by a tenth of a unit, so a spur
## may end at its front).
func _enters(foot: Dictionary, a: Vector2, b: Vector2) -> bool:
	var half: Vector2 = Vector2(foot.half) - Vector2.ONE * 0.1
	var steps: int = maxi(1, ceili(a.distance_to(b) / 0.05))
	for step: int in range(steps + 1):
		var at: Vector2 = a.lerp(b, float(step) / steps)
		var local: Vector2 = (at - Vector2(foot.plain)).rotated(float(foot.plain_yaw))
		if absf(local.x) < half.x and absf(local.y) < half.y:
			return true
	return false


func _revealed(map: Node3D, sim: RefCounted, site: int) -> void:
	var plots: Array = sim.state.world.regions[site].plots
	var hidden: int = -1
	for index: int in range(plots.size()):
		if bool(plots[index].get("hidden", false)):
			hidden = index
			break
	if hidden < 0:
		print("INFO no hidden plot at this site; the reveal check is skipped")
		return
	var builds: int = map.region_build_count
	map.show_planet()
	map.show_region(site)
	while map.region_busy:
		await process_frame
	check(map.region_build_count == builds, "an unchanged region comes from the cache")
	plots[hidden].hidden = false
	map.show_planet()
	map.show_region(site)
	while map.region_busy:
		await process_frame
	check(map.region_build_count == builds + 1, "a plot found since is cut into the ground")
	# A free plot's pad as the town draws it (1.12): bent, its default footprint level.
	var lot: Dictionary = map.plot_lot(site, hidden, "")
	var centre: Vector2 = lot.pos
	var edge: Vector2 = centre + (Vector2(lot.size) * 0.5).rotated(-float(lot.yaw))
	check(
		absf(map._ground(edge.x, edge.y) - map._ground(centre.x, centre.y)) < 0.05,
		"and its pad is level"
	)
