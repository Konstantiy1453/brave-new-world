extends RefCounted
## CC-GEO-2.x world: picks the sea level for the seeded land fraction, builds the 144 x 72 grid
## with per-cell attributes and D8 hydrology, places sites and checks that the world is playable.
## A world that fails is rebuilt from the next deterministic sub-seed.

const Plates = preload("res://world/geo2/plates.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Hydrology = preload("res://world/hydrology.gd")
const SeedGeo = preload("res://world/seed_geography.gd")
const Rules = preload("res://simulation/rules.gd")

const VERSION: String = "CC-GEO-2.2"
## 1.7.0 saves are bound to this one: same seed, same terrain, so it must never change.
const FROZEN_VERSION: String = "CC-GEO-2.0"
## Bump when the same seed would generate a different world: disk caches are keyed on it.
const REVISION: int = 5
const SOFTER_CLIMATE_ATTEMPT: int = 5
const SOFTER_LAYOUT_ATTEMPT: int = 8
const GW: int = 144
const GH: int = 72
const RADIUS_KM: Array[float] = [730.0, 1000.0, 1430.0]

static var _version_rules: Dictionary = {}


## The rule tables a generator version runs on. Older versions keep the base tables and the road
## table they were validated with, or their saves would stop matching what they regenerate.
static func rules_for(version: String) -> Dictionary:
	if _version_rules.has(version):
		return _version_rules[version]
	var base: Dictionary = Rules.read("geography")
	var merged: Dictionary = base
	if base.overrides.has(version):
		merged = base.duplicate(false)
		for key: String in base.overrides[version]:
			merged[key] = base.overrides[version][key]
		merged.erase("frozen_roads")
	_version_rules[version] = merged
	return merged


static func generate(seed_input: Variant, size_id: int, version: String = VERSION) -> Dictionary:
	var seed_value: int = SeedGeo.normalize_seed(seed_input)
	var size: int = clampi(size_id, 0, 2)
	var rules: Dictionary = rules_for(version)
	var planet: Dictionary = {}
	if version != FROZEN_VERSION:
		planet = Plates.character(seed_value, rules)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	var rejected: Array = []
	var fallback: Dictionary = {}
	var attempts: int = int(rules.attempts)
	if not planet.is_empty():
		attempts = int(rules.planet_types.attempts)
	for attempt: int in range(attempts):
		var ctx: Dictionary = Plates.build_context(
			seed_value, attempt, rules, _softened(planet, attempt)
		)
		var world: Dictionary = _terrain(seed_value, size, ctx, noise, seed_input, version)
		world.radius_km = _radius(rules, size)
		var count: int = int(world.statistics.continent_count)
		if count < int(rules.continents[0]) or count > int(rules.continents[1]):
			rejected.append({"attempt": attempt, "reason": "continents", "value": count})
			continue
		_finish_grid(world, noise)
		SiteGen.place(world, rules, ctx, attempt)
		var check: Dictionary = SiteGen.validate(world, rules)
		if bool(check.ok):
			return _accept(world, ctx, check, rejected, false)
		rejected.append({"attempt": attempt, "reason": "playability", "value": check.pairs.size()})
		if fallback.is_empty():
			fallback = {"world": world, "ctx": ctx}
	# Nothing passed. Carve a fertile basin near the best start of the first usable world.
	if fallback.is_empty():
		var ctx: Dictionary = Plates.build_context(
			seed_value, attempts, rules, _softened(planet, attempts)
		)
		var world: Dictionary = _terrain(seed_value, size, ctx, noise, seed_input, version)
		world.radius_km = _radius(rules, size)
		_finish_grid(world, noise)
		SiteGen.place(world, rules, ctx, attempts)
		fallback = {"world": world, "ctx": ctx}
	SiteGen.carve_basin(fallback.world, rules)
	var carved: Dictionary = SiteGen.validate(fallback.world, rules)
	return _accept(fallback.world, fallback.ctx, carved, rejected, true)


static func _radius(rules: Dictionary, size: int) -> float:
	return float(rules.get("radius_km", RADIUS_KM)[size])


## A character that keeps failing the playability check gives way: first the climate, then the
## layout and relief. Harsh planets stay common; unplayable ones do not ship.
static func _softened(planet: Dictionary, attempt: int) -> Dictionary:
	if planet.is_empty():
		return planet
	var softened: Dictionary = planet.duplicate()
	if attempt >= SOFTER_CLIMATE_ATTEMPT:
		softened.climate = "temperate"
	if attempt >= SOFTER_LAYOUT_ATTEMPT:
		softened.layout = "scattered"
		softened.relief = "ordinary"
	return softened


static func _accept(
	world: Dictionary, ctx: Dictionary, check: Dictionary, rejected: Array, carved: bool
) -> Dictionary:
	Plates.activate(int(world.seed), ctx)
	# The validator puts the best start first, so numbers are given out last.
	if world.has("character"):
		for site: Dictionary in world.regions:
			site.name = SiteGen.site_number(int(site.id))
	world.plates = ctx
	world.generation = Plates.describe(ctx)
	world.generation.mountain_ranges = _mountain_ranges(world)
	world.generation.validation = {
		"ok": bool(check.ok),
		"pairs": check.pairs.size(),
		"rejected": rejected,
		"carved": carved,
	}
	world.playability = {"checked": true, "pairs": check.pairs, "method": "cc-geo-2 validator"}
	return world


static func _terrain(
	seed_value: int,
	size: int,
	ctx: Dictionary,
	noise: FastNoiseLite,
	seed_input: Variant,
	version: String
) -> Dictionary:
	var parts: Array = []
	parts.resize(GW * GH)
	var raw_values := PackedFloat64Array()
	raw_values.resize(GW * GH)
	var weights := PackedFloat64Array()
	weights.resize(GW * GH)
	var points := PackedVector3Array()
	points.resize(GW * GH)
	for y: int in range(GH):
		var lat: float = 90.0 - (y + 0.5) * 180.0 / GH
		var area: float = cos(deg_to_rad(lat))
		for x: int in range(GW):
			var lon: float = (x + 0.5) * 360.0 / GW - 180.0
			var index: int = y * GW + x
			var p: Vector3 = SeedGeo.unit(lat, lon)
			var part: Dictionary = Plates.raw_height(p, noise, ctx)
			parts[index] = part
			points[index] = p
			raw_values[index] = float(part.raw)
			weights[index] = area
	ctx.sea_level = _sea_level(raw_values, weights, float(ctx.target_land))
	var grid: Array = []
	grid.resize(GW * GH)
	for y: int in range(GH):
		var lat: float = 90.0 - (y + 0.5) * 180.0 / GH
		for x: int in range(GW):
			var lon: float = (x + 0.5) * 360.0 / GW - 180.0
			var index: int = y * GW + x
			grid[index] = Plates.finish_sample(lat, lon, points[index], parts[index], noise, ctx)
	var world: Dictionary = {
		"seed": seed_value,
		"seed_input": str(seed_input),
		"seed_protocol": SeedGeo.SEED_PROTOCOL,
		"version": version,
		"size": size,
		"radius_km": RADIUS_KM[size],
		"grid_width": GW,
		"grid_height": GH,
		"grid": grid,
		"regions": [],
		"candidates": [],
		"rivers": [],
		"lakes": [],
		"terrain_key": "%s|%d|%d|%d" % [version, seed_value, size, int(ctx.attempt)],
	}
	world.statistics = _statistics(world)
	if ctx.has("character"):
		world.character = ctx.character
	return world


## The raw height above which land covers the wanted share of the sphere's area.
static func _sea_level(
	raw_values: PackedFloat64Array, weights: PackedFloat64Array, target: float
) -> float:
	var order: Array[int] = []
	order.resize(raw_values.size())
	for i: int in range(raw_values.size()):
		order[i] = i
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return a < b if raw_values[a] == raw_values[b] else raw_values[a] > raw_values[b]
	)
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var covered: float = 0.0
	for index: int in order:
		covered += weights[index]
		if covered >= total * target:
			return raw_values[index]
	return raw_values[order.back()]


static func _finish_grid(world: Dictionary, noise: FastNoiseLite) -> void:
	Hydrology.apply(world)
	_attributes(world, noise)
	world.statistics = _statistics(world)


static func _neighbor_indices(index: int) -> Array[int]:
	var result: Array[int] = []
	var x: int = index % GW
	var y: int = index / GW
	for dy: int in [-1, 0, 1]:
		var ny: int = y + dy
		if ny < 0 or ny >= GH:
			continue
		for dx: int in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				result.append(ny * GW + posmod(x + dx, GW))
	return result


## Fertility, water, ruggedness, coast access, climate risks and mineral potential of each cell.
static func _attributes(world: Dictionary, noise: FastNoiseLite) -> void:
	var grid: Array = world.grid
	for index: int in range(grid.size()):
		var cell: Dictionary = grid[index]
		if not bool(cell.land):
			continue
		var height: float = float(cell.height)
		var steepest: float = 0.0
		var coast: bool = false
		var lake_near: bool = bool(cell.lake)
		for near: int in _neighbor_indices(index):
			var other: Dictionary = grid[near]
			steepest = maxf(steepest, absf(height - maxf(float(other.height), 0.0)))
			coast = coast or not bool(other.land)
			lake_near = lake_near or bool(other.lake)
		cell.near_lake = 1.0 if lake_near else 0.0
		var rugged: float = clampf(steepest * 5.5, 0.0, 1.0)
		var discharge: float = float(cell.get("discharge", 0.0))
		var river_gain: float = minf(0.3, log(1.0 + discharge) * 0.13)
		var temperature: float = float(cell.temperature)
		var rainfall: float = float(cell.rainfall)
		var lowland: float = 1.0 - smoothstep(0.05, 0.3, height)
		var warmth: float = clampf(1.0 - absf(temperature - 19.0) / 24.0, 0.0, 1.0)
		var moisture: float = smoothstep(0.16, 0.56, rainfall + river_gain * 0.6)
		var soil: float = 0.6 + 0.4 * lowland + river_gain * 0.6
		cell.fertility = clampf(0.98 * warmth * moisture * soil * (1.0 - 0.55 * rugged), 0.03, 0.98)
		cell.water = clampf(
			rainfall * 0.72 + river_gain * 1.1 + (0.22 if lake_near else 0.0), 0.05, 0.98
		)
		cell.ruggedness = rugged
		cell.coast = coast
		cell.risk_cold = clampf((6.0 - temperature) / 14.0, 0.0, 1.0)
		cell.risk_arid = clampf((0.32 - rainfall) / 0.24, 0.0, 1.0)
		cell.risk_flood = clampf(river_gain * 2.2 * lowland, 0.0, 1.0)
		var p: Vector3 = SeedGeo.unit(
			90.0 - (index / GW + 0.5) * 180.0 / GH, (index % GW + 0.5) * 360.0 / GW - 180.0
		)
		var ridge: float = float(cell.ridge)
		var flank: float = smoothstep(0.02, 0.2, ridge) * (1.0 - smoothstep(0.45, 0.8, ridge))
		var basin: float = lowland * (1.0 - smoothstep(0.0, 0.5, rugged))
		var field_a: float = clampf(
			noise.get_noise_3dv(p * 5.5 + Vector3(31, 2, -14)) + 0.5, 0.0, 1.0
		)
		var field_b: float = clampf(
			noise.get_noise_3dv(p * 5.5 + Vector3(-23, 17, 6)) + 0.5, 0.0, 1.0
		)
		var field_c: float = clampf(
			noise.get_noise_3dv(p * 7.5 + Vector3(9, -28, 12)) + 0.5, 0.0, 1.0
		)
		cell.ore_potential = clampf(flank * 0.55 + basin * 0.2 + field_a * 0.5, 0.0, 1.0)
		cell.copper_potential = clampf(flank * 0.6 + basin * 0.1 + field_b * 0.5, 0.0, 1.0)
		cell.crystal_potential = clampf(
			smoothstep(0.25, 0.7, ridge) * 0.65 + field_c * 0.55, 0.0, 1.0
		)


## Mountain belts seen on the grid, for the world page: connected cells above the highland line.
static func _mountain_ranges(world: Dictionary) -> Array:
	var seen: Dictionary = {}
	var ranges: Array = []
	var grid: Array = world.grid
	for start: int in range(grid.size()):
		if seen.has(start) or not bool(grid[start].land) or float(grid[start].height) < 0.32:
			continue
		var queue: Array[int] = [start]
		seen[start] = true
		var head: int = 0
		while head < queue.size():
			var at: int = queue[head]
			head += 1
			for near: int in _neighbor_indices(at):
				if (
					not seen.has(near)
					and bool(grid[near].land)
					and float(grid[near].height) >= 0.32
				):
					seen[near] = true
					queue.append(near)
		if queue.size() >= 6:
			ranges.append({"cells": queue.size()})
	return ranges


## Land share by area, landmass counts and the figures on the world page.
static func _statistics(world: Dictionary) -> Dictionary:
	var grid: Array = world.grid
	var stats: Dictionary = {
		"land_fraction": 0.0,
		"mean_temperature_c": 0.0,
		"mean_rainfall": 0.0,
		"mean_ocean_depth_m": 0.0,
		"max_elevation_m": 0.0,
		"continent_count": 0,
		"island_count": 0,
		"biome_counts": {},
	}
	var land_area: float = 0.0
	var total_area: float = 0.0
	var ocean_cells: int = 0
	var landmass := PackedInt32Array()
	landmass.resize(grid.size())
	landmass.fill(-1)
	var sizes: Array[int] = []
	for index: int in range(grid.size()):
		var cell: Dictionary = grid[index]
		var area: float = cos(deg_to_rad(90.0 - (index / GW + 0.5) * 180.0 / GH))
		total_area += area
		stats.mean_temperature_c += float(cell.temperature)
		stats.mean_rainfall += float(cell.rainfall)
		var biome: String = str(cell.biome)
		stats.biome_counts[biome] = int(stats.biome_counts.get(biome, 0)) + 1
		if not bool(cell.land):
			ocean_cells += 1
			stats.mean_ocean_depth_m += float(cell.ocean_depth_m)
			continue
		land_area += area
		stats.max_elevation_m = maxf(stats.max_elevation_m, float(cell.height) * 4300.0)
		if landmass[index] >= 0:
			continue
		var id: int = sizes.size()
		var queue: Array[int] = [index]
		landmass[index] = id
		var head: int = 0
		while head < queue.size():
			var at: int = queue[head]
			head += 1
			var ax: int = at % GW
			var ay: int = at / GW
			for step: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]:
				var ny: int = ay + step.y
				if ny < 0 or ny >= GH:
					continue
				var next: int = ny * GW + posmod(ax + step.x, GW)
				if landmass[next] < 0 and bool(grid[next].land):
					landmass[next] = id
					queue.append(next)
		sizes.append(queue.size())
	var threshold: int = int(Rules.read("geography").continent_cells)
	for size: int in sizes:
		if size >= threshold:
			stats.continent_count += 1
		elif size >= 2:
			stats.island_count += 1
	stats.land_fraction = land_area / total_area
	stats.mean_temperature_c /= grid.size()
	stats.mean_rainfall /= grid.size()
	stats.mean_ocean_depth_m /= maxi(ocean_cells, 1)
	world.landmass = landmass
	world.landmass_sizes = sizes
	return stats
