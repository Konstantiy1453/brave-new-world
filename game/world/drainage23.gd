extends RefCounted
## CC-GEO-2.3 native catchments. Height is metres, area is spherical km².
## Priority-Flood (Barnes et al., 2014) fills the routing surface only; D8
## grades use distances at each latitude. Hydraulic geometry and sediment
## dispersal are an optical design model, not measured river discharge.

const Plates = preload("res://world/geo2/plates.gd")
const METHOD := "Priority-Flood / spherical D8 / wet catchments v2.3"
const STEPS := [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1)
]
const DETAIL_WIDTH := 432
const DETAIL_HEIGHT := 216


## The binary heap stores cell IDs only; reachable spill level is the key.
class FloodHeap:
	var ids := PackedInt32Array()
	var level: PackedFloat32Array
	var used := 0

	func _init(n: int, heights: PackedFloat32Array):
		ids.resize(n)
		level = heights

	func before(a: int, b: int) -> bool:
		return level[a] < level[b] or (level[a] == level[b] and a < b)

	func push(id: int) -> void:
		var j: int = used
		used += 1
		while j > 0:
			var p: int = (j - 1) >> 1
			if not before(id, ids[p]):
				break
			ids[j] = ids[p]
			j = p
		ids[j] = id

	func pop() -> int:
		var result: int = ids[0]
		used -= 1
		var last: int = ids[used]
		var j := 0
		while j * 2 + 1 < used:
			var child: int = j * 2 + 1
			if child + 1 < used and before(ids[child + 1], ids[child]):
				child += 1
			if not before(ids[child], last):
				break
			ids[j] = ids[child]
			j = child
		ids[j] = last
		return result


static func _cell(x: int, y: int, routing_width: int, routing_height: int) -> int:
	return -1 if y < 0 or y >= routing_height else y * routing_width + posmod(x, routing_width)


static func _coordinate(i: int, routing_width: int, routing_height: int) -> Vector2:
	return Vector2(
		90.0 - (float(i / routing_width) + 0.5) * 180.0 / routing_height,
		(float(i % routing_width) + 0.5) * 360.0 / routing_width - 180.0
	)


static func _coordinate_index(
	lat: float, lon: float, routing_width: int, routing_height: int
) -> int:
	return (
		clampi(floori((90.0 - lat) * routing_height / 180.0), 0, routing_height - 1) * routing_width
		+ posmod(floori((lon + 180.0) * routing_width / 360.0), routing_width)
	)


## Returns complete, connected downstream and accumulation fields, also on flats.
static func solve(
	elevation_m: PackedFloat32Array,
	wetness: PackedFloat32Array,
	routing_width: int,
	routing_height: int,
	radius_km: float
) -> Dictionary:
	var cell_count := elevation_m.size()
	var spill_elevation := elevation_m.duplicate()
	var seen := PackedByteArray()
	seen.resize(cell_count)
	var receiver := PackedInt32Array()
	receiver.resize(cell_count)
	receiver.fill(-1)
	var order := PackedInt32Array()
	order.resize(cell_count)
	var queue := PackedInt32Array()
	queue.resize(cell_count)
	var heap := FloodHeap.new(cell_count, spill_elevation)
	var water_count := 0
	var lowest := 0
	var area := PackedFloat64Array()
	area.resize(routing_height)
	var step_km := PackedFloat64Array()
	step_km.resize(routing_height * 8)
	var dx := PackedFloat64Array()
	dx.resize(routing_height)
	var dy := radius_km * PI / routing_height
	for y in routing_height:
		var lat := PI * 0.5 - (y + 0.5) * PI / routing_height
		area[y] = (
			radius_km
			* radius_km
			* TAU
			/ routing_width
			* (sin(lat + 0.5 * PI / routing_height) - sin(lat - 0.5 * PI / routing_height))
		)
		dx[y] = radius_km * TAU / routing_width * cos(lat)
		for direction in 8:
			var offset: Vector2i = STEPS[direction]
			var mid_lat := lat - offset.y * 0.5 * PI / routing_height
			var dx_km := offset.x * radius_km * TAU / routing_width * cos(mid_lat)
			step_km[y * 8 + direction] = Vector2(dx_km, offset.y * dy).length()
	for cell_index in cell_count:
		if elevation_m[cell_index] <= 0.0:
			seen[cell_index] = 1
			water_count += 1
			continue
		if elevation_m[cell_index] < elevation_m[lowest]:
			lowest = cell_index
		var x := cell_index % routing_width
		var y := cell_index / routing_width
		for offset: Vector2i in STEPS:
			var neighbor := _cell(x + offset.x, y + offset.y, routing_width, routing_height)
			if neighbor >= 0 and elevation_m[neighbor] <= 0.0:
				heap.push(cell_index)
				seen[cell_index] = 1
				break
	if water_count == 0 and cell_count > 0:
		heap.push(lowest)
		seen[lowest] = 1
	var read := 0
	var write := 0
	var sorted_count := 0
	while heap.used > 0 or read < write:
		var cell_index: int
		if read < write:
			cell_index = queue[read]
			read += 1
		else:
			cell_index = heap.pop()
		order[sorted_count] = cell_index
		sorted_count += 1
		var x := cell_index % routing_width
		var y := cell_index / routing_width
		var turn: int = (y * 17 + x * 29) % 8
		for direction in 8:
			var offset: Vector2i = STEPS[(direction + turn) % 8]
			var neighbor := _cell(x + offset.x, y + offset.y, routing_width, routing_height)
			if neighbor < 0 or seen[neighbor]:
				continue
			seen[neighbor] = 1
			receiver[neighbor] = cell_index
			if elevation_m[neighbor] <= spill_elevation[cell_index]:
				spill_elevation[neighbor] = spill_elevation[cell_index]
				queue[write] = neighbor
				write += 1
			else:
				heap.push(neighbor)
	var catchment_km2 := PackedFloat64Array()
	catchment_km2.resize(cell_count)
	var wet_catchment_km2 := PackedFloat64Array()
	wet_catchment_km2.resize(cell_count)
	var cells := PackedInt32Array()
	cells.resize(cell_count)
	var widths_km := PackedFloat32Array()
	widths_km.resize(cell_count)
	var lake_coverage := PackedByteArray()
	lake_coverage.resize(cell_count)
	var lake_candidates: Array[int] = []
	var mouths: Array[int] = []
	for rank in range(sorted_count - 1, -1, -1):
		var cell_index := order[rank]
		var x := cell_index % routing_width
		var y := cell_index / routing_width
		var steepest_grade := 0.0
		for direction in 8:
			var offset: Vector2i = STEPS[direction]
			var neighbor := _cell(x + offset.x, y + offset.y, routing_width, routing_height)
			if neighbor < 0:
				continue
			var slope: float = (
				(spill_elevation[cell_index] - maxf(0.0, spill_elevation[neighbor]))
				/ step_km[y * 8 + direction]
			)
			if slope > steepest_grade:
				steepest_grade = slope
				receiver[cell_index] = neighbor
		catchment_km2[cell_index] += area[y]
		wet_catchment_km2[cell_index] += (
			area[y] * (0.025 + 1.225 * pow(clampf(wetness[cell_index], 0.0, 1.0), 1.65))
		)
		cells[cell_index] += 1
		if (
			cells[cell_index] >= 4
			and wet_catchment_km2[cell_index] >= 1500.0
			and wet_catchment_km2[cell_index] / catchment_km2[cell_index] >= 0.085
		):
			widths_km[cell_index] = minf(8.0, 0.0041 * pow(wet_catchment_km2[cell_index], 0.53))
		# Retain sufficiently deep/wet, spill-filled lake pockets. At coarse
		# resolution depth gives fractional coverage rather than a whole cell.
		var depth: float = spill_elevation[cell_index] - elevation_m[cell_index]
		if (
			depth > 25.0
			and wetness[cell_index] > 0.38
			and catchment_km2[cell_index] > area[y] * 2.0
		):
			lake_coverage[cell_index] = roundi(
				(
					255.0
					* minf(0.8, depth / (depth + 140.0))
					* smoothstep(0.38, 0.75, wetness[cell_index])
				)
			)
			if lake_coverage[cell_index] > 22:
				lake_candidates.append(cell_index)
		var neighbor := receiver[cell_index]
		if neighbor >= 0:
			if elevation_m[neighbor] <= 0.0:
				mouths.append(cell_index)
			else:
				catchment_km2[neighbor] += catchment_km2[cell_index]
				wet_catchment_km2[neighbor] += wet_catchment_km2[cell_index]
				cells[neighbor] += cells[cell_index]
	return {
		"w": routing_width,
		"h": routing_height,
		"radius_km": radius_km,
		"dx": dx,
		"dy": dy,
		"area": area,
		"rec": receiver,
		"flow": catchment_km2,
		"runoff": wet_catchment_km2,
		"widths": widths_km,
		"lake": lake_coverage,
		"lake_candidates": lake_candidates,
		"mouths": mouths,
		"filled": spill_elevation
	}


static func build_grid(world: Dictionary) -> void:
	var routing_width: int = world.grid_width
	var routing_height: int = world.grid_height
	var cell_count := routing_width * routing_height
	var elevation_m := PackedFloat32Array()
	elevation_m.resize(cell_count)
	var wetness := PackedFloat32Array()
	wetness.resize(cell_count)
	for i in cell_count:
		var cell: Dictionary = world.grid[i]
		elevation_m[i] = float(cell.height) * 4300.0
		wetness[i] = cell.rainfall
	var drainage := solve(elevation_m, wetness, routing_width, routing_height, world.radius_km)
	# Gameplay moisture and site validation use the historic dimensionless
	# runoff scale; do not pass square kilometres into those economic rules.
	var equator_area: float = (
		world.radius_km * world.radius_km * TAU * PI / (routing_width * routing_height)
	)
	for i in cell_count:
		var cell: Dictionary = world.grid[i]
		cell.discharge = float(drainage.runoff[i]) / equator_area
		cell.river = drainage.widths[i] > 0.0
		cell.lake = drainage.lake[i] > 22
		cell.catchment_area_km2 = float(drainage.flow[i])
		cell.river_width_km = float(drainage.widths[i])
	_write_paths(world, drainage, elevation_m)


## Select mainstems and tributaries from the complete graph. Both the finest
## named waterways and the optical atlas use these same receivers.
static func _write_paths(
	world: Dictionary, drainage: Dictionary, elevation_m: PackedFloat32Array
) -> void:
	var routing_width: int = drainage.w
	var routing_height: int = drainage.h
	var grid_width: int = world.grid_width
	var grid_height: int = world.grid_height
	var flow: PackedFloat64Array = drainage.flow
	var receiver: PackedInt32Array = drainage.rec
	var widths: PackedFloat32Array = drainage.widths
	var fill: PackedFloat32Array = drainage.filled
	var upstream := PackedInt32Array()
	upstream.resize(elevation_m.size())
	upstream.fill(-1)
	for index in elevation_m.size():
		var downstream := receiver[index]
		if downstream < 0 or elevation_m[downstream] <= 0.0 or widths[index] <= 0.0:
			continue
		if upstream[downstream] < 0 or flow[index] > flow[upstream[downstream]]:
			upstream[downstream] = index
	var outlets: Array[int] = []
	for index: int in drainage.mouths:
		if upstream[index] >= 0:
			outlets.append(index)
	outlets.sort_custom(
		func(a: int, b: int) -> bool: return a < b if flow[a] == flow[b] else flow[a] > flow[b]
	)
	var chosen := PackedInt32Array()
	chosen.resize(elevation_m.size())
	chosen.fill(-1)
	var rivers: Array = []
	var metadata: Array = []
	var river_cells: Dictionary = {}
	var lakes: Array = []
	var tributaries: Array[int] = []
	var mouths := 0
	var land_count := 0
	for v: float in elevation_m:
		if v > 0.0:
			land_count += 1
	var budget := clampi(ceili(sqrt(land_count) * 0.19), 12, 40)
	for outlet in outlets:
		if mouths >= budget / 2:
			break
		if _add_branch(
			outlet,
			-1,
			upstream,
			chosen,
			drainage,
			elevation_m,
			grid_width,
			grid_height,
			rivers,
			metadata,
			river_cells,
			tributaries
		):
			mouths += 1
	while rivers.size() < budget and not tributaries.is_empty():
		tributaries.sort_custom(
			func(a: int, b: int) -> bool: return a > b if flow[a] == flow[b] else flow[a] < flow[b]
		)
		var tip: int = tributaries.pop_back()
		if chosen[tip] >= 0:
			continue
		_add_branch(
			tip,
			chosen[receiver[tip]],
			upstream,
			chosen,
			drainage,
			elevation_m,
			grid_width,
			grid_height,
			rivers,
			metadata,
			river_cells,
			tributaries
		)
	var lake_ids: Array = drainage.lake_candidates
	lake_ids.sort_custom(
		func(a: int, b: int) -> bool:
			return (
				a < b
				if drainage.lake[a] == drainage.lake[b]
				else drainage.lake[a] > drainage.lake[b]
			)
	)
	var lake_sites: Array[Vector2] = []
	for lake_index: int in lake_ids:
		if lakes.size() >= 20:
			break
		var coordinate := _coordinate(lake_index, routing_width, routing_height)
		var covered := false
		for previous: Vector2 in lake_sites:
			if (
				(
					Vector2(
						(
							(wrapf(previous.y - coordinate.y, -180, 180))
							* cos(deg_to_rad(coordinate.x))
						),
						previous.x - coordinate.x
					)
					. length()
				)
				< 720.0 / routing_width
			):
				covered = true
				break
		if covered:
			continue
		var grid_index := _coordinate_index(coordinate.x, coordinate.y, grid_width, grid_height)
		if not world.grid[grid_index].land:
			continue
		lake_sites.append(coordinate)
		lakes.append(
			{
				"name": "汇水湖 %02d" % (lakes.size() + 1),
				"lat": coordinate.x,
				"lon": coordinate.y,
				"radius_degrees":
				sqrt(float(drainage.lake[lake_index]) / 255.0 / PI) * 180.0 / routing_height,
				"height": fill[lake_index] / 4300.0,
				"elevation": fill[lake_index],
				"cell": grid_index,
				"catchment_discharge": world.grid[grid_index].discharge
			}
		)
	world.rivers = rivers
	world.river_metadata = metadata
	world.river_cells = river_cells.keys()
	world.lakes = lakes
	world.hydrology = {
		"method": METHOD,
		"river_count": rivers.size(),
		"lake_count": lakes.size(),
		"ocean_mouth_count": mouths,
		"land_cells": land_count,
		"candidate_streams": outlets.size(),
		"mainland_farming_cell": -1,
		"river_display_budget": budget,
		"routing_width": routing_width,
		"routing_height": routing_height
	}


static func _add_branch(
	tip: int,
	downstream: int,
	upstream: PackedInt32Array,
	chosen: PackedInt32Array,
	drainage: Dictionary,
	elevation_m: PackedFloat32Array,
	grid_width: int,
	grid_height: int,
	rivers: Array,
	metadata: Array,
	river_cells: Dictionary,
	branches: Array[int]
) -> bool:
	var chain: Array[int] = []
	var current := tip
	while current >= 0 and chosen[current] < 0:
		chain.append(current)
		current = upstream[current]
	if chain.size() < 2:
		return false
	chain.reverse()
	var next_cell: int = drainage.rec[tip]
	if next_cell >= 0:
		chain.append(next_cell)
	var coords: Array = []
	var levels: Array = []
	var widths: Array = []
	var coarse: Array = []
	var river_index := rivers.size()
	var routing_width: int = drainage.w
	var routing_height: int = drainage.h
	for index: int in chain:
		var coordinate := _coordinate(index, routing_width, routing_height)
		coords.append([coordinate.x, coordinate.y])
		levels.append(maxf(0.0, drainage.filled[index] / 4300.0))
		widths.append(
			(
				float(drainage.widths[index])
				if elevation_m[index] > 0.0
				else float(drainage.widths[tip])
			)
		)
		var grid_index := _coordinate_index(coordinate.x, coordinate.y, grid_width, grid_height)
		coarse.append(grid_index)
		if elevation_m[index] <= 0.0 or chosen[index] >= 0:
			continue
		chosen[index] = river_index
		river_cells[grid_index] = true
		var x := index % routing_width
		var y := index / routing_width
		for delta: Vector2i in STEPS:
			var neighbor := _cell(x + delta.x, y + delta.y, routing_width, routing_height)
			if (
				neighbor >= 0
				and neighbor != upstream[index]
				and drainage.rec[neighbor] == index
				and drainage.widths[neighbor] > 0.0
				and chosen[neighbor] < 0
			):
				branches.append(neighbor)
	rivers.append(coords)
	metadata.append(
		{
			"name": "河系 %02d" % (river_index + 1),
			"cell_path": coarse,
			"heights": levels,
			"widths_km": widths,
			"terminal": "confluence" if downstream >= 0 else "ocean",
			"downstream_index": downstream,
			"discharge":
			(
				float(drainage.runoff[tip])
				/ (drainage.radius_km * drainage.radius_km * TAU * PI / (grid_width * grid_height))
			),
			"catchment_km2": float(drainage.flow[tip]),
			"source_elevation_m": levels[0] * 4300.0,
			"mouth_or_lake_elevation_m": levels.back() * 4300.0
		}
	)
	return true


## Sample the accepted seed's plate field, including subcell relief. Persist
## plain arrays with its derived geo-cache; no Image/Texture/Node is saved.
static func prepare_optical(world: Dictionary, terrain_context: Dictionary) -> void:
	if world.has("optical_drainage"):
		return
	var routing_width := DETAIL_WIDTH
	var routing_height := DETAIL_HEIGHT
	var noise := FastNoiseLite.new()
	noise.seed = world.seed
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	var elevation_m := PackedFloat32Array()
	elevation_m.resize(routing_width * routing_height)
	var wetness := PackedFloat32Array()
	wetness.resize(routing_width * routing_height)
	var grid_width: int = world.grid_width
	var grid_height: int = world.grid_height
	for y in routing_height:
		var lat := 90.0 - (y + 0.5) * 180.0 / routing_height
		for x in routing_width:
			var i := y * routing_width + x
			# At 3x resolution every coarse centre is an exact fine centre.
			if (
				routing_width == grid_width * 3
				and routing_height == grid_height * 3
				and x % 3 == 1
				and y % 3 == 1
			):
				var grid_cell: Dictionary = world.grid[(y / 3) * grid_width + x / 3]
				elevation_m[i] = float(grid_cell.height) * 4300.0
				wetness[i] = grid_cell.rainfall
			else:
				var sample := Plates.sample_with_context(
					lat, (x + 0.5) * 360.0 / routing_width - 180.0, noise, terrain_context
				)
				elevation_m[i] = float(sample.height) * 4300.0
				wetness[i] = sample.rainfall
	var drainage := solve(elevation_m, wetness, routing_width, routing_height, world.radius_km)
	var plume := _estuary_plumes(drainage, elevation_m)
	var land := PackedByteArray()
	land.resize(routing_width * routing_height)
	for i in routing_width * routing_height:
		land[i] = 1 if elevation_m[i] > 0.0 else 0
	# The accepted geometry owns the river/lake flags used by plot and site lookups.
	var equator_area: float = (
		world.radius_km * world.radius_km * TAU * PI / (grid_width * grid_height)
	)
	for i in world.grid.size():
		var cell: Dictionary = world.grid[i]
		# Start with the local catchment's own contribution, just as on the
		# preliminary 144 x 72 grid. Scale imported fine inflows into those units.
		cell.discharge = 0.0
		if cell.land:
			var wet_factor := 0.025 + 1.225 * pow(clampf(cell.rainfall, 0.0, 1.0), 1.65)
			var latitude := PI * 0.5 - (float(i / grid_width) + 0.5) * PI / grid_height
			cell.discharge = wet_factor * cos(latitude)
		cell.river = false
		cell.lake = false
		cell.river_width_km = 0.0
		cell.catchment_area_km2 = 0.0
	for y in routing_height:
		for x in routing_width:
			var i := y * routing_width + x
			if not land[i]:
				continue
			var cell: Dictionary = world.grid[
				(y * grid_height / routing_height) * grid_width + (x * grid_width / routing_width)
			]
			if not cell.land:
				continue
			cell.discharge = maxf(cell.discharge, float(drainage.runoff[i]) / equator_area)
			cell.catchment_area_km2 = maxf(float(cell.catchment_area_km2), float(drainage.flow[i]))
			cell.river_width_km = maxf(float(cell.river_width_km), float(drainage.widths[i]))
			cell.river = bool(cell.river) or drainage.widths[i] > 0.0
			cell.lake = bool(cell.lake) or drainage.lake[i] > 22
	for region: Dictionary in world.get("regions", []):
		if region.has("grid_index"):
			region.river = bool(world.grid[int(region.grid_index)].river)
	_write_paths(world, drainage, elevation_m)
	world.optical_drainage = {
		"width": routing_width,
		"height": routing_height,
		"radius_km": world.radius_km,
		"route": drainage.rec,
		"flow_km2": drainage.flow,
		"widths_km": drainage.widths,
		"plume": plume,
		"lake": drainage.lake,
		"land": land
	}
	world.hydrology.plume_model = "wet catchment outlets / directional coastal fan"


static func _estuary_plumes(
	drainage: Dictionary, elevation_m: PackedFloat32Array
) -> PackedByteArray:
	var routing_width: int = drainage.w
	var routing_height: int = drainage.h
	var plumes := PackedByteArray()
	plumes.resize(routing_width * routing_height)
	var chosen: Array[Vector2] = []
	var mouths: Array = drainage.mouths
	var runoff: PackedFloat64Array = drainage.runoff
	mouths.sort_custom(
		func(a: int, b: int) -> bool:
			return a < b if runoff[a] == runoff[b] else runoff[a] > runoff[b]
	)
	for mouth: int in mouths:
		if chosen.size() >= 18:
			break
		if drainage.flow[mouth] < 85000.0 or drainage.widths[mouth] < 1.25:
			continue
		var x := mouth % routing_width
		var y := mouth / routing_width
		var coordinate := _coordinate(mouth, routing_width, routing_height)
		if absf(coordinate.x) > 76.0:
			continue
		var too_close := false
		for previous: Vector2 in chosen:
			var lon_offset := wrapf(previous.y - coordinate.y, -180.0, 180.0)
			var east := lon_offset * cos(deg_to_rad(coordinate.x))
			var angle_degrees := Vector2(east, previous.x - coordinate.x).length()
			if deg_to_rad(angle_degrees) * drainage.radius_km < 225.0:
				too_close = true
				break
		if too_close:
			continue
		var dx: float = drainage.dx[y]
		var dy: float = drainage.dy
		var outlet: int = drainage.rec[mouth]
		var x_step := wrapi(outlet % routing_width - x, -routing_width / 2, routing_width / 2)
		var y_step := outlet / routing_width - y
		var delta := Vector2(x_step * dx, y_step * dy).normalized()
		var reach := clampf(38.0 + 46.0 * log(1.0 + runoff[mouth] / 120000.0), 40.0, 160.0)
		var angle := delta.angle()
		var best_score := -INF
		for degrees: float in [
			0.0, 20.0, -20.0, 40.0, -40.0, 70.0, -70.0, 105.0, -105.0, 150.0, -150.0, 180.0
		]:
			var ray := delta.rotated(deg_to_rad(degrees))
			var water_score := 0.0
			for fraction: float in [0.35, 0.65, 0.95]:
				var grid_index := _cell(
					x + roundi(ray.x * fraction * reach / dx),
					y + roundi(ray.y * fraction * reach / dy),
					routing_width,
					routing_height
				)
				if grid_index >= 0 and elevation_m[grid_index] <= 0.0:
					water_score += 1.0
			var value := water_score + 0.2 * cos(deg_to_rad(degrees))
			if value > best_score:
				best_score = value
				angle = ray.angle()
		if best_score < 1.1:
			continue
		var ray := Vector2.from_angle(angle)
		var columns := mini(routing_width / 2 - 1, ceili(reach * 1.45 / dx) + 1)
		var rows := ceili(reach * 1.45 / dy) + 1
		var peak := clampf(0.46 + 0.2 * log(1.0 + runoff[mouth] / 140000.0), 0.45, 0.96)
		for oy in range(-rows, rows + 1):
			for ox in range(-columns, columns + 1):
				var id := _cell(x + ox, y + oy, routing_width, routing_height)
				if id < 0 or elevation_m[id] > 0.0:
					continue
				var offset_km := Vector2(ox * dx, oy * dy)
				var a := offset_km.dot(ray)
				if a < 0.0 or a > reach * 1.3:
					continue
				var spread := maxf(0.65 * minf(dx, dy), reach * 0.3 * (0.2 + 0.8 * a / reach))
				var across := offset_km.cross(ray) / spread
				var amount := peak * exp(-across * across - pow(a / (reach * 0.69), 1.4))
				if amount <= 0.004:
					continue
				var clear := true
				for fraction: float in [0.25, 0.5, 0.75]:
					if offset_km.length() * fraction <= maxf(dx, dy) * 1.2:
						continue
					var mid := _cell(
						x + roundi(ox * fraction),
						y + roundi(oy * fraction),
						routing_width,
						routing_height
					)
					if mid < 0 or elevation_m[mid] > 0.0:
						clear = false
						break
				if clear:
					plumes[id] = maxi(plumes[id], roundi(255.0 * amount))
		chosen.append(coordinate)
	return plumes


## Optical fractions follow the atlas bilinear footprint across the date line.
## Channel width and upstream area refer to the local routing-cell centreline.
static func _fraction(
	values: PackedByteArray, x: float, y: float, routing_width: int, routing_height: int
) -> float:
	var raw_x := floori(x)
	var raw_y := floori(y)
	var left := posmod(raw_x, routing_width)
	var right := (left + 1) % routing_width
	var top := clampi(raw_y, 0, routing_height - 1) * routing_width
	var bottom := clampi(raw_y + 1, 0, routing_height - 1) * routing_width
	var upper := lerpf(values[top + left], values[top + right], x - raw_x)
	var lower := lerpf(values[bottom + left], values[bottom + right], x - raw_x)
	return lerpf(upper, lower, y - raw_y) / 255.0


static func query(world: Dictionary, lat: float, lon: float) -> Dictionary:
	var field: Dictionary = world.get("optical_drainage", {})
	if field.is_empty():
		return {"width_km": 0.0, "flow_km2": 0.0, "plume": 0.0, "lake_fraction": 0.0}
	var i := _coordinate_index(lat, lon, field.width, field.height)
	var x: float = (lon + 180.0) * field.width / 360.0 - 0.5
	var y: float = (90.0 - lat) * field.height / 180.0 - 0.5
	return {
		"width_km": float(field.widths_km[i]),
		"flow_km2": float(field.flow_km2[i]),
		"plume":
		_fraction(field.plume, x, y, field.width, field.height) if not field.land[i] else 0.0,
		"lake_fraction": _fraction(field.lake, x, y, field.width, field.height),
	}


static func texture(world: Dictionary, width: int, height: int) -> Image:
	var field: Dictionary = world.get("optical_drainage", {})
	if field.is_empty():
		return Image.create(width, height, false, Image.FORMAT_RG8)
	var routing_width: int = field.width
	var routing_height: int = field.height
	var radius: float = field.radius_km
	var channel_coverage := PackedFloat32Array()
	channel_coverage.resize(width * height)
	var lake := Image.create_from_data(
		routing_width, routing_height, false, Image.FORMAT_L8, field.lake
	)
	var coast := Image.create_from_data(
		routing_width, routing_height, false, Image.FORMAT_L8, field.plume
	)
	lake.resize(width, height, Image.INTERPOLATE_BILINEAR)
	coast.resize(width, height, Image.INTERPOLATE_BILINEAR)
	var lake_bytes := lake.get_data()
	var plume_bytes := coast.get_data()
	# Image.resize clamps at the boundaries; globe water wraps in longitude.
	var edge_columns := ceili(0.5 * width / routing_width)
	for edge_x in edge_columns:
		for x: int in [edge_x, width - 1 - edge_x]:
			var source_x := (x + 0.5) * routing_width / width - 0.5
			for y in height:
				var source_y := (y + 0.5) * routing_height / height - 0.5
				lake_bytes[y * width + x] = roundi(
					255.0 * _fraction(field.lake, source_x, source_y, routing_width, routing_height)
				)
				plume_bytes[y * width + x] = roundi(
					(
						255.0
						* _fraction(field.plume, source_x, source_y, routing_width, routing_height)
					)
				)
	var px_area := PackedFloat32Array()
	px_area.resize(height)
	for y in height:
		px_area[y] = (
			radius
			* radius
			* TAU
			/ width
			* (sin(PI * 0.5 - y * PI / height) - sin(PI * 0.5 - (y + 1) * PI / height))
		)
	var widths: PackedFloat32Array = field.widths_km
	var receiver: PackedInt32Array = field.route
	var mask: PackedByteArray = field.land
	# Integrate channel area (km²) through subpixel samples. No minimum
	# pixel width; small tributaries fade when downsampled on either map.
	for i in routing_width * routing_height:
		var j := receiver[i]
		if widths[i] <= 0.0 or j < 0:
			continue
		var x := i % routing_width
		var y := i / routing_width
		var offset := Vector2(
			wrapi(j % routing_width - x, -routing_width / 2, routing_width / 2),
			j / routing_width - y
		)
		var mid_lat := PI * 0.5 - (y + 0.5 + offset.y * 0.5) * PI / routing_height
		var east_km := offset.x * radius * TAU / routing_width * cos(mid_lat)
		var north_km := offset.y * radius * PI / routing_height
		var length_km := Vector2(east_km, north_km).length()
		var step_px := Vector2(offset.x * width / routing_width, offset.y * height / routing_height)
		if not mask[j]:
			step_px *= 0.5
			length_km *= 0.5
		var samples := maxi(1, ceili(step_px.length() * 2.0))
		var area_chunk := widths[i] * length_km / samples
		var base := Vector2(
			(x + 0.5) * width / routing_width - 0.5, (y + 0.5) * height / routing_height - 0.5
		)
		for t in samples:
			var v := base + step_px * ((t + 0.5) / samples)
			var column_base := floori(v.x)
			var row_base := floori(v.y)
			var fx := v.x - column_base
			var fy := v.y - row_base
			for yy in 2:
				var row := row_base + yy
				if row < 0 or row >= height:
					continue
				var value: float = area_chunk * (fy if yy else 1.0 - fy) / px_area[row]
				channel_coverage[row * width + posmod(column_base, width)] += value * (1.0 - fx)
				channel_coverage[row * width + posmod(column_base + 1, width)] += value * fx
	var bytes := PackedByteArray()
	bytes.resize(width * height * 2)
	for i in width * height:
		bytes[i * 2] = maxi(lake_bytes[i], roundi(255.0 * clampf(channel_coverage[i], 0.0, 1.0)))
		bytes[i * 2 + 1] = plume_bytes[i]
	return Image.create_from_data(width, height, false, Image.FORMAT_RG8, bytes)
