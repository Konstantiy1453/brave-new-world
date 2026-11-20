extends RefCounted
## Planetary geology (1.10): each mineable resource has deposits of its own on the planet, fixed by the
## world seed. Veins run along the belts where the grid says the resource is likely (its potential),
## pockets lie isolated, and the ground between is barren. Resources are drawn independently, so their
## belts cross where the terrain suits both. A deposit has a world position and a finite reserve; every
## district that reaches it draws on that one reserve (sites.gd keeps the plots that reach it in step).
## Numbers are in data/v17/geography.json `geology`.

const Rules = preload("res://simulation/rules.gd")

## Worlds kept in memory, by seed, generator version and size.
const CACHE_LIMIT: int = 4

static var _cache: Dictionary = {}


## Every deposit of the world, in a fixed order: {id, resource, kind ("vein" or "pocket"), points
## ([lat, lon] pairs; one for a pocket), lat, lon (its middle), width or radius in degrees, reserve,
## grade, depth (0 near the surface, 1 deep), hidden (a pocket seen from no orbit)}.
static func deposits(world: Dictionary) -> Array:
	return _entry(world).deposits


## The deposits whose ground reaches within `reach` degrees of a point, nearest first:
## [{deposit, distance}] where distance is in degrees from the deposit's edge (0 inside it).
static func reaching(world: Dictionary, lat: float, lon: float, reach: float) -> Array:
	var entry: Dictionary = _entry(world)
	var found: Array = []
	var seen: Dictionary = {}
	var width: int = int(world.get("grid_width", 144))
	var height: int = int(world.get("grid_height", 72))
	var row: int = clampi(int((90.0 - lat) / 180.0 * height), 0, height - 1)
	var column: int = posmod(int((lon + 180.0) / 360.0 * width), width)
	var span: int = 1 + int(ceil(reach / (180.0 / height)))
	for dy: int in range(-span, span + 1):
		var y: int = row + dy
		if y < 0 or y >= height:
			continue
		for dx: int in range(-span, span + 1):
			var cell: int = y * width + posmod(column + dx, width)
			for at: Variant in entry.index.get(cell, []):
				if seen.has(at):
					continue
				seen[at] = true
				var deposit: Dictionary = entry.deposits[int(at)]
				var edge: float = _edge_distance(deposit, lat, lon)
				if edge <= reach:
					found.append({"deposit": deposit, "distance": edge})
	found.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a.distance), float(b.distance)):
				return float(a.distance) < float(b.distance)
			return str(a.deposit.id) < str(b.deposit.id)
	)
	return found


## What an orbital reading shows around a point for each resource: 0 for nothing, up to 1 for a
## strong anomaly. Broad: it sums the visible deposits within `radius` degrees, weighted by reserve
## and nearness, and says nothing about where exactly they lie.
static func orbital_signals(world: Dictionary, lat: float, lon: float, radius: float) -> Dictionary:
	var rules: Dictionary = _rules()
	var strength: Dictionary = {}
	for resource: String in rules.resources:
		strength[resource] = 0.0
	for hit: Dictionary in reaching(world, lat, lon, radius):
		var deposit: Dictionary = hit.deposit
		if bool(deposit.hidden) or int(deposit.depth) > 0:
			continue
		var scale: float = float(rules.vein_reserve[deposit.resource][1])
		var near: float = 1.0 - clampf(float(hit.distance) / maxf(radius, 0.01), 0.0, 1.0)
		strength[deposit.resource] = (
			float(strength[deposit.resource]) + float(deposit.reserve) / scale * (0.4 + 0.6 * near)
		)
	for resource: String in strength:
		strength[resource] = clampf(float(strength[resource]), 0.0, 1.0)
	return strength


## Distance in degrees from a point to a deposit's ground (0 inside it), longitude scaled by latitude.
static func _edge_distance(deposit: Dictionary, lat: float, lon: float) -> float:
	var points: Array = deposit.points
	var scale: float = cos(deg_to_rad(lat))
	var here := Vector2(0.0, 0.0)
	var best: float = INF
	if points.size() == 1:
		best = _local(points[0], lat, lon, scale).distance_to(here)
		return maxf(0.0, best - float(deposit.radius))
	for at: int in range(points.size() - 1):
		var a: Vector2 = _local(points[at], lat, lon, scale)
		var b: Vector2 = _local(points[at + 1], lat, lon, scale)
		var t: float = clampf(
			(here - a).dot(b - a) / maxf(a.distance_squared_to(b), 0.000001), 0.0, 1.0
		)
		best = minf(best, a.lerp(b, t).distance_to(here))
	return maxf(0.0, best - float(deposit.width) * 0.5)


static func _local(point: Array, lat: float, lon: float, scale: float) -> Vector2:
	return Vector2(wrapf(float(point[1]) - lon, -180.0, 180.0) * scale, float(point[0]) - lat)


static func _rules() -> Dictionary:
	return Rules.read("geography").geology


static func _entry(world: Dictionary) -> Dictionary:
	var key: String = (
		"%s|%s|%s"
		% [str(world.get("seed", 0)), str(world.get("version", "")), str(world.get("size", 1))]
	)
	if not _cache.has(key):
		if _cache.size() >= CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		var made: Array = _generate(world)
		_cache[key] = {"deposits": made, "index": _index(world, made)}
	return _cache[key]


## Cells each deposit's ground touches, for `reaching`.
static func _index(world: Dictionary, made: Array) -> Dictionary:
	var index: Dictionary = {}
	var width: int = int(world.get("grid_width", 144))
	var height: int = int(world.get("grid_height", 72))
	var cell_deg: float = 180.0 / height
	for at: int in range(made.size()):
		var deposit: Dictionary = made[at]
		var pad: float = float(deposit.get("width", 0.0)) * 0.5 + float(deposit.get("radius", 0.0))
		var low_lat: float = INF
		var high_lat: float = -INF
		var lons: Array = []
		for point: Array in deposit.points:
			low_lat = minf(low_lat, float(point[0]))
			high_lat = maxf(high_lat, float(point[0]))
			lons.append(float(point[1]))
		var top: int = clampi(int((90.0 - (high_lat + pad)) / cell_deg), 0, height - 1)
		var bottom: int = clampi(int((90.0 - (low_lat - pad)) / cell_deg), 0, height - 1)
		var middle: float = float(lons[0])
		var west: float = 0.0
		var east: float = 0.0
		for lon: float in lons:
			var offset: float = wrapf(lon - middle, -180.0, 180.0)
			west = minf(west, offset)
			east = maxf(east, offset)
		var lat_scale: float = maxf(
			0.15, cos(deg_to_rad(clampf((low_lat + high_lat) * 0.5, -80.0, 80.0)))
		)
		var lon_pad: float = pad / lat_scale
		var first: int = int(floor((middle + west - lon_pad + 180.0) / 360.0 * width))
		var last: int = int(floor((middle + east + lon_pad + 180.0) / 360.0 * width))
		for y: int in range(top, bottom + 1):
			for x: int in range(first, last + 1):
				var cell: int = y * width + posmod(x, width)
				if not index.has(cell):
					index[cell] = []
				index[cell].append(at)
	return index


static func _generate(world: Dictionary) -> Array:
	var rules: Dictionary = _rules()
	var made: Array = []
	var grid: Array = world.get("grid", [])
	if grid.is_empty():
		return made
	for resource: String in rules.resources:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|geology|%s" % [int(world.seed), resource])
		var picks: Dictionary = _weighted_cells(world, resource, rules)
		if picks.cells.is_empty():
			continue
		for number: int in range(int(rules.veins.get(resource, 0))):
			made.append(_vein(world, rules, resource, number, picks, rng))
		for number: int in range(int(rules.pockets.get(resource, 0))):
			made.append(_pocket(world, rules, resource, number, picks, rng))
	return made


## Land cells away from the poles, weighted by how likely the resource is there.
static func _weighted_cells(world: Dictionary, resource: String, rules: Dictionary) -> Dictionary:
	var cells := PackedInt32Array()
	var running := PackedFloat64Array()
	var total: float = 0.0
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	var power: float = float(rules.potential_power)
	for index: int in range(world.grid.size()):
		var cell: Dictionary = world.grid[index]
		if not bool(cell.get("land", false)):
			continue
		var lat: float = 90.0 - (float(index / width) + 0.5) * 180.0 / height
		if absf(lat) > float(rules.max_latitude):
			continue
		var weight: float = pow(float(cell.get(resource + "_potential", 0.0)), power)
		if weight <= 0.0:
			continue
		total += weight
		cells.append(index)
		running.append(total)
	return {"cells": cells, "running": running, "total": total}


static func _pick(world: Dictionary, picks: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var target: float = rng.randf() * float(picks.total)
	var running: PackedFloat64Array = picks.running
	var low: int = 0
	var high: int = running.size() - 1
	while low < high:
		var middle: int = (low + high) / 2
		if running[middle] < target:
			low = middle + 1
		else:
			high = middle
	var index: int = picks.cells[low]
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	var cell_deg: float = 180.0 / height
	var lat: float = 90.0 - (float(index / width) + rng.randf()) * cell_deg
	var lon: float = (float(index % width) + rng.randf()) * 360.0 / width - 180.0
	return Vector2(lat, lon)


static func _vein(
	world: Dictionary,
	rules: Dictionary,
	resource: String,
	number: int,
	picks: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var middle: Vector2 = _pick(world, picks, rng)
	var heading: float = rng.randf() * TAU
	var segments: int = rng.randi_range(int(rules.vein_segments[0]), int(rules.vein_segments[1]))
	var ahead: Array = []
	var behind: Array = []
	for side: int in [1, -1]:
		var at: Vector2 = middle
		var turn: float = heading if side > 0 else heading + PI
		for _step: int in range((segments + (1 if side > 0 else 0)) / 2):
			turn += deg_to_rad(rng.randf_range(-1.0, 1.0) * float(rules.turn_degrees))
			var length: float = rng.randf_range(
				float(rules.segment_degrees[0]), float(rules.segment_degrees[1])
			)
			var scale: float = maxf(0.2, cos(deg_to_rad(at.x)))
			at = Vector2(
				clampf(at.x + sin(turn) * length, -80.0, 80.0),
				wrapf(at.y + cos(turn) * length / scale, -180.0, 180.0)
			)
			if side > 0:
				ahead.append([at.x, at.y])
			else:
				behind.push_front([at.x, at.y])
	var points: Array = behind + [[middle.x, middle.y]] + ahead
	var spread: Array = rules.vein_reserve[resource]
	var potential: float = _potential(world, resource, middle)
	return _record(
		rules,
		"%s-v%d" % [resource, number],
		resource,
		"vein",
		points,
		middle,
		{"width": rng.randf_range(float(rules.vein_width[0]), float(rules.vein_width[1]))},
		rng.randf_range(float(spread[0]), float(spread[1])) * (0.7 + 0.6 * potential),
		rng,
		false
	)


static func _pocket(
	world: Dictionary,
	rules: Dictionary,
	resource: String,
	number: int,
	picks: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var middle: Vector2 = _pick(world, picks, rng)
	var spread: Array = rules.pocket_reserve[resource]
	var potential: float = _potential(world, resource, middle)
	return _record(
		rules,
		"%s-p%d" % [resource, number],
		resource,
		"pocket",
		[[middle.x, middle.y]],
		middle,
		{"radius": rng.randf_range(float(rules.pocket_radius[0]), float(rules.pocket_radius[1]))},
		rng.randf_range(float(spread[0]), float(spread[1])) * (0.7 + 0.6 * potential),
		rng,
		rng.randf() < float(rules.hidden_share)
	)


static func _record(
	rules: Dictionary,
	id: String,
	resource: String,
	kind: String,
	points: Array,
	middle: Vector2,
	shape: Dictionary,
	reserve: float,
	rng: RandomNumberGenerator,
	hidden: bool
) -> Dictionary:
	var deep: bool = rng.randf() < float(rules.deep_share)
	var grade: float = rng.randf_range(float(rules.grade[0]), float(rules.grade[1]))
	var record: Dictionary = {
		"id": id,
		"resource": resource,
		"kind": kind,
		"points": points,
		"lat": middle.x,
		"lon": middle.y,
		"width": float(shape.get("width", 0.0)),
		"radius": float(shape.get("radius", 0.0)),
		"reserve": roundf(reserve),
		"grade": grade * (float(rules.deep_grade) if deep else 1.0),
		"depth": 1 if deep else 0,
		"hidden": hidden,
	}
	return record


static func _potential(world: Dictionary, resource: String, at: Vector2) -> float:
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	var row: int = clampi(int((90.0 - at.x) / 180.0 * height), 0, height - 1)
	var column: int = posmod(int((at.y + 180.0) / 360.0 * width), width)
	return float(world.grid[row * width + column].get(resource + "_potential", 0.0))
