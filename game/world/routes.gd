extends RefCounted
## A* over the world grid. Land roads come in two variants: the valley road keeps to low ground
## and may go a long way round; the engineered road takes the direct line through the mountains.
## Sea routes run over ocean cells between coastal sites. Results are the same plain record for
## every variant and are cached per world.

const HIGH_GROUND: float = 0.38
const SEA_SPEED_KM_PER_DAY: float = 340.0
## The shuttle flies: a straight hop drawn with this many points, no terrain in the way.
const AIR: String = "shuttle"
const AIR_POINTS: int = 12
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

const SEA_NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

static var _terrain: Dictionary = {}
static var _results: Dictionary = {}


static func unit(lat: float, lon: float) -> Vector3:
	var a: float = deg_to_rad(lat)
	var b: float = deg_to_rad(lon)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))


## Packed copies of what the search reads. One per world, shared.
static func _prepared(world: Dictionary) -> Dictionary:
	var key: String = str(world.get("terrain_key", world.get("hash", "")))
	if _terrain.has(key):
		return _terrain[key]
	var grid: Array = world.grid
	var heights := PackedFloat32Array()
	heights.resize(grid.size())
	var land := PackedByteArray()
	land.resize(grid.size())
	for index: int in range(grid.size()):
		heights[index] = float(grid[index].height)
		land[index] = 1 if bool(grid[index].land) else 0
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	# East-west cell size shrinks towards the poles; north-south does not.
	var step_x := PackedFloat32Array()
	step_x.resize(height)
	var degree_km: float = deg_to_rad(1.0) * float(world.radius_km)
	var step_y: float = 180.0 / height * degree_km
	for y: int in range(height):
		var lat: float = 90.0 - (y + 0.5) * 180.0 / height
		step_x[y] = maxf(0.08, cos(deg_to_rad(lat))) * 360.0 / width * degree_km
	var prepared: Dictionary = {
		"key": key,
		"heights": heights,
		"land": land,
		"width": width,
		"height": height,
		"step_x": step_x,
		"step_y": step_y,
	}
	if _terrain.size() >= 4:
		_terrain.erase(_terrain.keys()[0])
		_results.clear()
	_terrain[key] = prepared
	return prepared


## Route between two site indices. `variant` is "valley", "engineered" or "sea".
static func find(
	world: Dictionary, a: int, b: int, variant: String, rules: Dictionary
) -> Dictionary:
	var regions: Array = world.regions
	if a < 0 or b < 0 or a >= regions.size() or b >= regions.size() or a == b:
		return _unreachable(variant, "请选择两个不同的地点")
	if variant == AIR:
		return _air(world, a, b, rules)
	var terrain: Dictionary = _prepared(world)
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	# Cells, not site numbers: the validator renumbers sites after its first routes.
	var cache_key: String = (
		"%s|%d|%d|%s"
		% [terrain.key, int(regions[low].grid_index), int(regions[high].grid_index), variant]
	)
	if not _results.has(cache_key):
		_results[cache_key] = _search(world, terrain, low, high, variant, rules)
	var found: Dictionary = _results[cache_key].duplicate(true)
	if found.reachable and a != low:
		found.path.reverse()
		found.coordinates.reverse()
	found.a = a
	found.b = b
	return found


## A short hop by air: a great-circle line, nothing in the way, but only up to `max_km`.
static func _air(world: Dictionary, a: int, b: int, rules: Dictionary) -> Dictionary:
	var spec: Dictionary = rules[AIR]
	var from: Vector3 = unit(float(world.regions[a].lat), float(world.regions[a].lon))
	var to: Vector3 = unit(float(world.regions[b].lat), float(world.regions[b].lon))
	var distance: float = roundf(from.angle_to(to) * float(world.radius_km))
	if distance > float(spec.max_km):
		return _unreachable(AIR, "超出穿梭机航程：%.0f km，最远 %.0f km" % [distance, float(spec.max_km)])
	var coordinates: Array = []
	for index: int in range(AIR_POINTS + 1):
		var point: Vector3 = from.slerp(to, float(index) / AIR_POINTS).normalized()
		coordinates.append(
			[rad_to_deg(asin(clampf(point.y, -1.0, 1.0))), rad_to_deg(atan2(point.x, point.z))]
		)
	return {
		"reachable": true,
		"distance": distance,
		"days": maxi(int(spec.min_days), ceili(distance / float(spec.speed_km_per_day))),
		"cost": roundf(float(spec.base_cost) + distance * float(spec.cost_per_km)),
		"path": [],
		"coordinates": coordinates,
		"mountain": false,
		"variant": AIR,
		"a": a,
		"b": b,
		"capacity": int(spec.capacity),
		"reason": str(spec.reason),
		"build_days": int(spec.build_days),
	}


static func _unreachable(variant: String, reason: String) -> Dictionary:
	return {
		"reachable": false,
		"distance": 0.0,
		"days": 0,
		"cost": 0.0,
		"path": [],
		"coordinates": [],
		"mountain": variant == "engineered",
		"variant": variant,
		"reason": reason,
	}


static func _unreachable_reason(variant: String) -> String:
	if variant == "sea":
		return "两地之间没有可通行的海路"
	if variant == "valley":
		return "高山或海洋阻断河谷公路"
	return "海洋阻断陆路；两地靠海时可以建小型货运码头开辟航线"


static func _passable(terrain: Dictionary, cell: int, variant: String, ends: Array[int]) -> bool:
	if cell in ends:
		return true
	if variant == "sea":
		return terrain.land[cell] == 0
	if terrain.land[cell] == 0:
		return false
	return variant != "valley" or terrain.heights[cell] <= HIGH_GROUND


## Cost of entering a cell, in effective kilometres per kilometre.
static func _penalty(terrain: Dictionary, from: int, to: int, variant: String) -> float:
	if variant == "sea":
		return 1.0
	var height: float = maxf(terrain.heights[to], 0.0)
	var slope: float = absf(terrain.heights[to] - terrain.heights[from])
	if variant == "valley":
		return 1.0 + height * 2.5 + slope * 4.0
	return 1.0 + height * 0.25 + slope * 0.4


static func _search(
	world: Dictionary, terrain: Dictionary, a: int, b: int, variant: String, rules: Dictionary
) -> Dictionary:
	var start: int = int(world.regions[a].grid_index)
	var finish: int = int(world.regions[b].grid_index)
	var ends: Array[int] = [start, finish]
	if variant == "sea":
		ends = _sea_ends(terrain, start, finish)
		if ends.is_empty():
			return _unreachable(variant, "两地并非都靠海")
	var moves: Array[Vector2i] = SEA_NEIGHBORS if variant == "sea" else NEIGHBORS
	var width: int = terrain.width
	var height: int = terrain.height
	var count: int = width * height
	var best := PackedFloat64Array()
	best.resize(count)
	best.fill(INF)
	var previous := PackedInt32Array()
	previous.resize(count)
	previous.fill(-1)
	var heap_keys := PackedFloat64Array()
	var heap_cells := PackedInt32Array()
	var finish_x: int = finish % width
	var finish_y: int = finish / width
	var step_y: float = terrain.step_y
	var min_step_x: float = 0.08 * 360.0 / width * deg_to_rad(1.0) * float(world.radius_km)
	best[start] = 0.0
	_push(heap_keys, heap_cells, 0.0, start)
	while heap_cells.size() > 0:
		var current: int = _pop(heap_keys, heap_cells)
		if current == finish:
			break
		var cx: int = current % width
		var cy: int = current / width
		var known: float = best[current]
		for offset: Vector2i in moves:
			var ny: int = cy + offset.y
			if ny < 1 or ny >= height - 1:
				continue
			var next: int = ny * width + posmod(cx + offset.x, width)
			if not _passable(terrain, next, variant, ends):
				continue
			var km_x: float = float(terrain.step_x[cy]) * absi(offset.x)
			var km_y: float = step_y * absi(offset.y)
			var km: float = sqrt(km_x * km_x + km_y * km_y)
			var total: float = known + km * _penalty(terrain, current, next, variant)
			if total < best[next]:
				best[next] = total
				previous[next] = current
				var wrap_dx: int = absi(next % width - finish_x)
				wrap_dx = mini(wrap_dx, width - wrap_dx)
				var guess: float = (
					maxf(wrap_dx * min_step_x, absi(ny - finish_y) * step_y)
					if variant == "sea"
					else wrap_dx * min_step_x + absi(ny - finish_y) * step_y
				)
				_push(heap_keys, heap_cells, total + guess, next)
	if previous[finish] < 0:
		return _unreachable(variant, _unreachable_reason(variant))
	return _record(terrain, previous, start, finish, best[finish], variant, a, b, rules)


## A sea voyage starts and ends on the coast: the land cell itself must touch the ocean.
static func _sea_ends(terrain: Dictionary, start: int, finish: int) -> Array[int]:
	for cell: int in [start, finish]:
		var touches: bool = false
		var x: int = cell % int(terrain.width)
		var y: int = cell / int(terrain.width)
		for offset: Vector2i in SEA_NEIGHBORS:
			var ny: int = y + offset.y
			if ny < 0 or ny >= int(terrain.height):
				continue
			if (
				terrain.land[ny * int(terrain.width) + posmod(x + offset.x, int(terrain.width))]
				== 0
			):
				touches = true
		if not touches:
			return []
	return [start, finish]


static func _record(
	terrain: Dictionary,
	previous: PackedInt32Array,
	start: int,
	finish: int,
	effective: float,
	variant: String,
	a: int,
	b: int,
	rules: Dictionary
) -> Dictionary:
	var path: Array[int] = [finish]
	var cursor: int = finish
	var width: int = terrain.width
	var distance: float = 0.0
	while cursor != start:
		var next: int = previous[cursor]
		var km_x: float = (
			float(terrain.step_x[cursor / width]) if next % width != cursor % width else 0.0
		)
		var km_y: float = float(terrain.step_y) if next / width != cursor / width else 0.0
		distance += sqrt(km_x * km_x + km_y * km_y)
		path.push_front(next)
		cursor = next
	var coordinates: Array = []
	var height: int = terrain.height
	for cell: int in path:
		(
			coordinates
			. append(
				[
					90.0 - (float(cell / width) + 0.5) * 180.0 / height,
					(float(cell % width) + 0.5) * 360.0 / width - 180.0,
				]
			)
		)
	var spec: Dictionary = rules[variant]
	var speed: float = float(spec.speed_km_per_day)
	return {
		"reachable": true,
		"distance": roundf(distance),
		"days": maxi(int(spec.min_days), ceili(effective / speed)),
		"cost": roundf(float(spec.base_cost) + distance * float(spec.cost_per_km)),
		"path": path,
		"coordinates": coordinates,
		"mountain": variant == "engineered",
		"variant": variant,
		"a": a,
		"b": b,
		"capacity": int(spec.capacity),
		"reason": str(spec.reason),
		"build_days": _build_days(spec, distance),
	}


## Laying a road takes time in proportion to its length; a sea route only needs its terminals.
static func _build_days(spec: Dictionary, distance: float) -> int:
	if not spec.has("build_km_per_day"):
		return int(spec.get("build_days", 0))
	return maxi(int(spec.get("build_days", 0)), ceili(distance / float(spec.build_km_per_day)))


static func _push(keys: PackedFloat64Array, cells: PackedInt32Array, key: float, cell: int) -> void:
	keys.append(key)
	cells.append(cell)
	var at: int = keys.size() - 1
	while at > 0:
		var parent: int = (at - 1) / 2
		if keys[parent] <= keys[at]:
			break
		var swap_key: float = keys[parent]
		var swap_cell: int = cells[parent]
		keys[parent] = keys[at]
		cells[parent] = cells[at]
		keys[at] = swap_key
		cells[at] = swap_cell
		at = parent


static func _pop(keys: PackedFloat64Array, cells: PackedInt32Array) -> int:
	var top: int = cells[0]
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	cells[0] = cells[last]
	keys.resize(last)
	cells.resize(last)
	var at: int = 0
	while true:
		var left: int = at * 2 + 1
		var right: int = left + 1
		var low: int = at
		if left < last and keys[left] < keys[low]:
			low = left
		if right < last and keys[right] < keys[low]:
			low = right
		if low == at:
			break
		var swap_key: float = keys[low]
		var swap_cell: int = cells[low]
		keys[low] = keys[at]
		cells[low] = cells[at]
		keys[at] = swap_key
		cells[at] = swap_cell
		at = low
	return top
