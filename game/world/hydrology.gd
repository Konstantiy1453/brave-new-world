extends RefCounted
## Deterministic drainage on the authoritative spherical height grid.
## Rivers follow strict natural descent. Closed terrain depressions are small
## endorheic lakes; no pre-drawn channel is forced through a mountain.
const METHOD := "D8 natural descent / precipitation-weighted accumulation v1"


static func apply(world: Dictionary) -> Dictionary:
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	var count: int = world.grid.size()
	var receiver: PackedInt32Array = []
	var discharge: PackedFloat64Array = []
	var upstream: PackedInt32Array = []
	var lengths: PackedInt32Array = []
	receiver.resize(count)
	receiver.fill(-1)
	discharge.resize(count)
	upstream.resize(count)
	upstream.fill(-1)
	lengths.resize(count)
	lengths.fill(1)
	var land: Array[int] = []
	var rainfall_sum: float = 0.0
	for i in range(count):
		var cell: Dictionary = world.grid[i]
		cell.river = false
		cell.lake = false
		cell.discharge = 0.0
		if not bool(cell.land):
			continue
		land.append(i)
		rainfall_sum += float(cell.get("rainfall", .5))
		var coordinate: Vector2 = _coordinate(i, width, height)
		discharge[i] = (
			maxf(.08, float(cell.get("rainfall", .5))) * maxf(.05, cos(deg_to_rad(coordinate.x)))
		)
		var best_slope: float = 0.0
		for next in _neighbors(i, width, height):
			var next_cell: Dictionary = world.grid[next]
			var descent: float = float(cell.height) - float(next_cell.height)
			if descent <= .00000001:
				continue
			var nc: Vector2 = _coordinate(next, width, height)
			var metric: float = maxf(.01, _unit(coordinate).angle_to(_unit(nc)))
			var slope: float = descent / metric
			if slope > best_slope:
				best_slope = slope
				receiver[i] = next
	land.sort_custom(
		func(a: int, b: int):
			var ha: float = float(world.grid[a].height)
			var hb: float = float(world.grid[b].height)
			return a < b if ha == hb else ha > hb
	)
	for i in land:
		var next: int = receiver[i]
		if next < 0:
			continue
		discharge[next] += discharge[i]
		if lengths[i] + 1 > lengths[next]:
			lengths[next] = lengths[i] + 1
			upstream[next] = i
	for i in land:
		world.grid[i].discharge = discharge[i]
	var component: Dictionary = {}
	if world.get("regions", []).size() > 1:
		component = _component(int(world.regions[0].grid_index), world, width, height)
	var valley: int = _choose_valley(world, component, discharge, receiver, width, height)
	var candidates: Array = []
	for i in land:
		if discharge[i] < .65 or float(world.grid[i].height) < .018:
			continue
		var path: Array[int] = _trace(i, receiver, world)
		if path.size() < 3:
			continue
		var end: int = path[path.size() - 1]
		var score: float = discharge[end] * sqrt(float(path.size()))
		candidates.append({"start": i, "score": score, "path": path})
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary):
			return (
				int(a.start) < int(b.start)
				if float(a.score) == float(b.score)
				else float(a.score) > float(b.score)
			)
	)
	# Keep the farming candidate on a real catchment even if another continent
	# has the largest river. Walk upstream to include its mountain-fed reaches.
	if valley >= 0:
		var source: int = valley
		var guard: int = 0
		while upstream[source] >= 0 and guard < count:
			source = upstream[source]
			guard += 1
		var path: Array[int] = _trace(source, receiver, world)
		if path.size() >= 3:
			candidates.push_front({"start": source, "score": INF, "path": path})
	world.rivers = []
	world.river_metadata = []
	world.lakes = []
	var owned: Dictionary = {}
	var lake_cells: Dictionary = {}
	var mouth_cells: Dictionary = {}
	# Cartographic selection varies with actual land area and precipitation.
	# The full D8 accumulation remains in the grid, even for unlabelled streams.
	var river_budget: int = clampi(
		ceili(sqrt(float(land.size())) * .22 + rainfall_sum / maxf(1.0, float(land.size())) * 18.0),
		10,
		36
	)
	for candidate in candidates:
		if world.rivers.size() >= river_budget:
			break
		var original: Array = candidate.path
		var path: Array[int] = []
		var downstream: int = -1
		for cell_id in original:
			path.append(int(cell_id))
			if owned.has(cell_id):
				downstream = int(owned[cell_id])
				break
		var minimum: int = 3 if downstream >= 0 else 4
		if path.size() < minimum and not world.rivers.is_empty():
			continue
		var fresh: int = 0
		for cell_id in path:
			if not owned.has(cell_id):
				fresh += 1
		if fresh < (2 if downstream >= 0 else 4) and not world.rivers.is_empty():
			continue
		var coordinates: Array = []
		var water_heights: Array = []
		var river_index: int = world.rivers.size()
		for cell_id in path:
			var ll: Vector2 = _coordinate(cell_id, width, height)
			coordinates.append([ll.x, ll.y])
			water_heights.append(maxf(0.0, float(world.grid[cell_id].height)))
			world.grid[cell_id].river = bool(world.grid[cell_id].land)
			if not owned.has(cell_id):
				owned[cell_id] = river_index
		var terminal: int = path[path.size() - 1]
		var terminal_type: String = (
			"confluence"
			if downstream >= 0
			else ("ocean" if not bool(world.grid[terminal].land) else "lake")
		)
		if terminal_type == "ocean":
			mouth_cells[terminal] = true
		if terminal_type == "lake" and not lake_cells.has(terminal):
			lake_cells[terminal] = true
			var ll: Vector2 = _coordinate(terminal, width, height)
			world.grid[terminal].lake = true
			world.lakes.append(
				{
					"name": "汇水湖 %02d" % (world.lakes.size() + 1),
					"lat": ll.x,
					"lon": ll.y,
					"radius_degrees": clampf(.22 + sqrt(discharge[terminal]) * .045, .25, .75),
					"height": float(world.grid[terminal].height),
					"elevation": float(world.grid[terminal].height) * 4300.0,
					"cell": terminal,
					"catchment_discharge": discharge[terminal]
				}
			)
		world.rivers.append(coordinates)
		world.river_metadata.append(
			{
				"name": "河系 %02d" % (river_index + 1),
				"cell_path": path,
				"heights": water_heights,
				"terminal": terminal_type,
				"downstream_index": downstream,
				"discharge": discharge[terminal],
				"source_elevation_m": water_heights[0] * 4300.0,
				"mouth_or_lake_elevation_m": water_heights.back() * 4300.0
			}
		)
	world.river_cells = owned.keys()
	world.hydrology = {
		"method": METHOD,
		"river_count": world.rivers.size(),
		"lake_count": world.lakes.size(),
		"ocean_mouth_count": mouth_cells.size(),
		"mainland_farming_cell": valley,
		"land_cells": land.size(),
		"river_display_budget": river_budget,
		"candidate_streams": candidates.size(),
		"scope":
		"coarse-grid catchments; precipitation/area-limited major river display; subcell lakes; not a fluid simulation"
	}
	for region in world.get("regions", []):
		region.river = owned.has(int(region.grid_index))
	return world


static func _choose_valley(
	world: Dictionary,
	component: Dictionary,
	discharge: PackedFloat64Array,
	receiver: PackedInt32Array,
	width: int,
	height: int
) -> int:
	if world.get("regions", []).size() < 2:
		return -1
	var valley: Dictionary = world.regions[1]
	var original: int = int(valley.grid_index)
	var ox: int = original % width
	var oy: int = original / width
	var best: int = -1
	var score: float = -INF
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			if dx * dx + dy * dy > 36:
				continue
			var y: int = oy + dy
			if y < 1 or y >= height - 1:
				continue
			var cell: int = y * width + posmod(ox + dx, width)
			if not component.has(cell) or receiver[cell] < 0:
				continue
			if not bool(world.grid[receiver[cell]].land):
				continue
			if float(world.grid[cell].height) > .34:
				continue
			var candidate: float = (
				log(1.0 + discharge[cell]) * 2.0
				- sqrt(float(dx * dx + dy * dy)) * .23
				- float(world.grid[cell].height) * 2.0
			)
			if candidate > score:
				score = candidate
				best = cell
	if best < 0:
		return -1
	var ll: Vector2 = _coordinate(best, width, height)
	var g: Dictionary = world.grid[best]
	valley.lat = ll.x
	valley.lon = ll.y
	valley.grid_index = best
	valley.elevation = maxf(20.0, float(g.height) * 4300.0)
	valley.temperature = float(g.get("temperature", valley.get("temperature", 15.0)))
	valley.rainfall = float(g.get("rainfall", .5))
	var climate_fertility: float = float(g.get("fertility", valley.get("fertility", .55)))
	valley.fertility = clampf(climate_fertility + .12 + log(1.0 + discharge[best]) * .025, .65, .95)
	valley.water = clampf(
		float(g.get("rainfall", .5)) * .7 + .25 + log(1.0 + discharge[best]) * .04, .60, .98
	)
	valley.catchment_discharge = discharge[best]
	valley.river = true
	return best


static func _trace(start: int, receiver: PackedInt32Array, world: Dictionary) -> Array[int]:
	var result: Array[int] = [start]
	var current: int = start
	while receiver[current] >= 0 and result.size() < world.grid.size():
		current = receiver[current]
		result.append(current)
		if not bool(world.grid[current].land):
			break
	return result


static func _component(start: int, world: Dictionary, width: int, height: int) -> Dictionary:
	var reached: Dictionary = {start: true}
	var queue: Array[int] = [start]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		var x: int = current % width
		var y: int = current / width
		for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var ny: int = y + off.y
			if ny < 0 or ny >= height:
				continue
			var next: int = ny * width + posmod(x + off.x, width)
			if reached.has(next) or not bool(world.grid[next].land):
				continue
			reached[next] = true
			queue.append(next)
	return reached


static func _neighbors(index: int, width: int, height: int) -> Array[int]:
	var result: Array[int] = []
	var x: int = index % width
	var y: int = index / width
	for dy in [-1, 0, 1]:
		var ny: int = y + dy
		if ny < 0 or ny >= height:
			continue
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			result.append(ny * width + posmod(x + dx, width))
	return result


static func _coordinate(index: int, width: int, height: int) -> Vector2:
	return Vector2(
		90.0 - (float(index / width) + .5) * 180.0 / height,
		(float(index % width) + .5) * 360.0 / width - 180.0
	)


static func _unit(ll: Vector2) -> Vector3:
	var a: float = deg_to_rad(ll.x)
	var b: float = deg_to_rad(ll.y)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))
