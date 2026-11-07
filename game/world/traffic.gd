extends Node3D
## Vehicles on a settlement's service roads. Cosmetic: they read where the roads and buildings are
## and never touch the simulation. Every trip runs building -> main street -> building, or out to
## a route gate, keeping to the right, then waits a moment and picks the next errand.
## Meshes come from the map (`vehicle_meshes`), so modelled vehicles can replace the procedural
## ones without touching this file.

const SPEED: float = 2.2
const KEEP_RIGHT: float = 0.17
const RIDE_HEIGHT: float = 0.03
const WAIT_SECONDS: Vector2 = Vector2(1.2, 4.0)
const MAX_VEHICLES: int = 14

## Mesh per vehicle kind: "truck", "van", "bus".
var vehicle_meshes: Dictionary = {}
## Road height at a ground point, bridges included.
var surface_height: Callable
var street_x: float = 0.0
## [{"end": Vector2, "z": float, "kind": String, "active": bool}]
var stops: Array = []
## [{"end": Vector2}] route gates at the edge of the region.
var gates: Array = []
var running: bool = true
var rate: float = 1.0
var _vehicles: Array = []
var _rng := RandomNumberGenerator.new()


func setup(seed_value: int, count: int) -> void:
	_rng.seed = seed_value
	for child: Node in get_children():
		child.queue_free()
	_vehicles.clear()
	if stops.is_empty() or vehicle_meshes.is_empty():
		return
	for index: int in range(mini(count, MAX_VEHICLES)):
		var kind: String = _pick_kind(index)
		var body := MeshInstance3D.new()
		body.mesh = vehicle_meshes.get(kind, vehicle_meshes.values()[0])
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		var vehicle: Dictionary = {
			"node": body,
			"kind": kind,
			"path": PackedVector2Array(),
			"lengths": PackedFloat32Array(),
			"at": 0.0,
			"wait": _rng.randf_range(0.0, WAIT_SECONDS.y),
			"stop": _rng.randi_range(0, stops.size() - 1),
		}
		_vehicles.append(vehicle)
		_next_trip(vehicle)
		# Spread them out along their first trip.
		vehicle.at = _rng.randf() * float(vehicle.lengths[vehicle.lengths.size() - 1])
		_place(vehicle)


func vehicle_count() -> int:
	return _vehicles.size()


func advance(delta: float) -> void:
	if not running:
		return
	var step: float = delta * rate
	for vehicle: Dictionary in _vehicles:
		if float(vehicle.wait) > 0.0:
			vehicle.wait = float(vehicle.wait) - step
			continue
		var total: float = float(vehicle.lengths[vehicle.lengths.size() - 1])
		vehicle.at = float(vehicle.at) + step * SPEED
		if float(vehicle.at) >= total:
			vehicle.at = total
			_place(vehicle)
			vehicle.wait = _rng.randf_range(WAIT_SECONDS.x, WAIT_SECONDS.y)
			_next_trip(vehicle)
			continue
		_place(vehicle)


func _pick_kind(index: int) -> String:
	if index == 0:
		return "bus"
	return "truck" if index % 3 != 2 else "van"


## Trucks serve working buildings and the gates; vans and buses go anywhere.
func _next_trip(vehicle: Dictionary) -> void:
	var from: Dictionary = stops[int(vehicle.stop)]
	var points := PackedVector2Array()
	points.append(from.end)
	points.append(Vector2(street_x, float(from.z)))
	if not gates.is_empty() and str(vehicle.kind) == "truck" and _rng.randf() < 0.3:
		var gate: Dictionary = gates[_rng.randi_range(0, gates.size() - 1)]
		points.append(Vector2(street_x, 0.0))
		points.append(gate.end)
		points.append(Vector2(street_x, 0.0))
		points.append(Vector2(street_x, float(from.z)))
		points.append(from.end)
	else:
		var choice: int = _choose_stop(vehicle)
		var to: Dictionary = stops[choice]
		points.append(Vector2(street_x, float(to.z)))
		points.append(to.end)
		vehicle.stop = choice
	vehicle.path = points
	var lengths := PackedFloat32Array([0.0])
	for index: int in range(1, points.size()):
		lengths.append(lengths[index - 1] + points[index - 1].distance_to(points[index]))
	if lengths[lengths.size() - 1] < 0.01:
		lengths[lengths.size() - 1] = 0.01
	vehicle.lengths = lengths
	vehicle.at = 0.0


func _choose_stop(vehicle: Dictionary) -> int:
	for _attempt: int in range(6):
		var index: int = _rng.randi_range(0, stops.size() - 1)
		if index == int(vehicle.stop) and stops.size() > 1:
			continue
		if str(vehicle.kind) == "truck" and not bool(stops[index].active) and _rng.randf() < 0.7:
			continue
		return index
	return _rng.randi_range(0, stops.size() - 1)


func _place(vehicle: Dictionary) -> void:
	var path: PackedVector2Array = vehicle.path
	var lengths: PackedFloat32Array = vehicle.lengths
	var at: float = float(vehicle.at)
	var segment: int = 0
	while segment < lengths.size() - 2 and at > lengths[segment + 1]:
		segment += 1
	var a: Vector2 = path[segment]
	var b: Vector2 = path[mini(segment + 1, path.size() - 1)]
	var span: float = maxf(
		lengths[mini(segment + 1, lengths.size() - 1)] - lengths[segment], 0.0001
	)
	var t: float = clampf((at - lengths[segment]) / span, 0.0, 1.0)
	var flat: Vector2 = a.lerp(b, t)
	var heading: Vector2 = (b - a).normalized() if a.distance_to(b) > 0.001 else Vector2.RIGHT
	# Keep right: the right of a heading (x, z) on this ground is (-z, x).
	flat += Vector2(-heading.y, heading.x) * KEEP_RIGHT
	var ahead: Vector2 = flat + heading * 0.4
	var here := Vector3(flat.x, _height(flat) + RIDE_HEIGHT, flat.y)
	var there := Vector3(ahead.x, _height(ahead) + RIDE_HEIGHT, ahead.y)
	var node: MeshInstance3D = vehicle.node
	node.position = here
	if here.distance_to(there) > 0.001:
		node.look_at(there, Vector3.UP, true)


func _height(point: Vector2) -> float:
	if surface_height.is_valid():
		return float(surface_height.call(point.x, point.y))
	return 0.0
