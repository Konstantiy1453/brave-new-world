extends SceneTree
## The 1.9 region scene on a generated world: the landscape runs far past the playable field, every
## plot's pad is level, the landing pods stand on a cell of their own, and no vehicle route between
## stops or out to a gate passes through a building or stops inside one. A plot that comes to
## light later gets its terrace the next time the region is shown. Headless; older worlds keep
## their ground to the vertex (world_v16_terrain_identity).

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const Traffic = preload("res://world/traffic.gd")
const SEED: int = 260129
const KINDS: Array[String] = [
	"habitat", "power", "water", "farm", "mine_ore", "processor", "lab", "mine_copper", "habitat"
]
## A pad's radius, and how close a vehicle's path may come to a building it is not serving: the
## lane is half a slot out, less the keep-right offset and a margin.
const PAD: float = 2.3
const CLEAR_OTHER: float = 2.7
const CLEAR_OWN: float = 2.5

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
	await _revealed(map, sim, site)
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


func _plot_points(sim: RefCounted, site: int) -> Array:
	var plots: Array = sim.state.world.regions[site].plots
	var points: Array = []
	for building: Dictionary in sim.settlement(site).buildings:
		var plot: int = int(building.get("plot", -1))
		if plot >= 0:
			points.append(Vector2(float(plots[plot].x), float(plots[plot].z)))
	return points


func _pads(map: Node3D, sim: RefCounted, site: int) -> void:
	var points: Array = _plot_points(sim, site)
	check(points.size() >= 6, "the town has buildings on plots (%d)" % points.size())
	var worst: float = 0.0
	for centre: Vector2 in points:
		var level: float = map._ground(centre.x, centre.y)
		for step: int in range(8):
			var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * step / 8.0) * PAD
			worst = maxf(worst, absf(map._ground(at.x, at.y) - level))
	check(worst < 0.05, "every pad is level to its edge (worst %.3f)" % worst)


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
	var buildings: Array = _plot_points(sim, site)
	buildings.append(map._pods_position(0.0))
	var paths: Array = []
	for from: Dictionary in traffic.stops:
		for to: Dictionary in traffic.stops:
			paths.append([from, to, Traffic.stop_path(from, to, traffic.street_x)])
		for gate: Dictionary in traffic.gates:
			paths.append([from, from, Traffic.gate_path(from, gate, traffic.street_x)])
	var crossings: PackedStringArray = []
	for entry: Array in paths:
		var points: PackedVector2Array = entry[2]
		var served: Array = [_served(entry[0], buildings), _served(entry[1], buildings)]
		for index: int in range(points.size() - 1):
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			for centre: Vector2 in buildings:
				var limit: float = CLEAR_OWN if served.has(centre) else CLEAR_OTHER
				if _distance(centre, a, b) < limit - 0.001:
					crossings.append("%s-%s near %s" % [a, b, centre])
	check(
		crossings.is_empty(), "no route passes through a building %s" % str(crossings.slice(0, 4))
	)
	var inside: int = 0
	for stop: Dictionary in traffic.stops:
		for centre: Vector2 in buildings:
			if Vector2(stop.end).distance_to(centre) < PAD:
				inside += 1
	check(inside == 0, "no vehicle waits inside a building (%d)" % inside)


## The building a stop serves: the one whose pad its spur ends at.
func _served(stop: Dictionary, buildings: Array) -> Vector2:
	var best: Vector2 = Vector2.INF
	for centre: Vector2 in buildings:
		if Vector2(stop.end).distance_to(centre) < Vector2(stop.end).distance_to(best):
			best = centre
	return best


static func _distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var t: float = clampf(
		(point - a).dot(b - a) / maxf(a.distance_squared_to(b), 0.000001), 0.0, 1.0
	)
	return point.distance_to(a.lerp(b, t))


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
	var centre := Vector2(float(plots[hidden].x), float(plots[hidden].z))
	var edge: Vector2 = centre + Vector2(PAD, 0.0)
	check(
		absf(map._ground(edge.x, edge.y) - map._ground(centre.x, centre.y)) < 0.05,
		"and its pad is level"
	)
