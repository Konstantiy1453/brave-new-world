extends RefCounted
## CC-GEO-2.0 terrain: seeded plate-like landmasses and a climate you can sample at any point.
## Continents are soft blobs warped by noise. Plates meet along warped Voronoi edges: where they
## converge a mountain belt rises, over open ocean it makes island arcs. The sea level is the
## height quantile that gives the seeded land fraction, measured once on the world grid.
## CC-GEO-2.1 first draws a character from the seed (land layout, climate, relief) and builds to
## that recipe. Without a character the numbers are those of CC-GEO-2.0, so its worlds stay as saved.

const SeedGeo = preload("res://world/seed_geography.gd")

const OCEAN_PLATES: Array[int] = [4, 8]
const BELT_WIDTH: float = 0.075
const RIFT_DEPTH: float = 0.05
const RAW_RIDGE: float = 0.5
const OCEANIC_RIDGE_FACTOR: float = 0.72
const HEIGHT_PER_COAST: float = 0.3
const HEIGHT_PER_RIDGE: float = 0.72
const HEIGHT_PER_DETAIL: float = 0.1
const METRES_PER_HEIGHT: float = 4300.0
const UPWIND_DEGREES: float = 11.0
const ICE_LATITUDE: float = 76.0
const ICE_DEGREES_PER_C: float = 1.8
const ICE_REFERENCE_C: float = 29.0
const CHARACTER_SALT: int = 0x7E57
const CC_GEO_2_0_RECIPE: Dictionary = {
	"temperature": [25.0, 32.0],
	"rainfall": [0.42, 0.56],
	"elevation": [0.9, 1.25],
	"spread": [0.82, 1.2],
	"stretch": [1.0, 1.55],
	"lobes": [1, 3],
	"chains": [2, 5],
	"max_latitude": 62.0,
	"spacing": 1.85,
	"lead": 1.0,
	"cap_degrees": 0.0,
	"warp": 0.34,
	"broad": 0.2,
}

static var _active: Dictionary = {}


## The context bound to a seed by the last world built from it. Read-only, shared with threads.
static func context(seed_value: int) -> Dictionary:
	return _active[seed_value]


static func activate(seed_value: int, ctx: Dictionary) -> void:
	_active[seed_value] = ctx


static func is_active(seed_value: int) -> bool:
	return _active.has(seed_value)


## What kind of planet a seed makes. Drawn from the seed alone, so retries keep the same character.
static func character(seed_value: int, rules: Dictionary) -> Dictionary:
	var types: Dictionary = rules.planet_types
	# The tutorial teaches on a mild planet whatever the draw would have been.
	if types.pinned.has(str(seed_value)):
		return types.pinned[str(seed_value)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 65537 + CHARACTER_SALT
	return {
		"layout": _weighted(rng, types.layouts),
		"climate": _weighted(rng, types.climates),
		"relief": _weighted(rng, types.reliefs),
	}


static func _weighted(rng: RandomNumberGenerator, table: Dictionary) -> String:
	var total: float = 0.0
	for key: String in table:
		total += float(table[key].weight)
	var roll: float = rng.randf_range(0.0, total)
	for key: String in table:
		roll -= float(table[key].weight)
		if roll <= 0.0:
			return key
	return table.keys().back()


## The numbers a world is built to.
static func _recipe(rules: Dictionary, planet: Dictionary) -> Dictionary:
	var recipe: Dictionary = CC_GEO_2_0_RECIPE.duplicate()
	recipe.land = rules.land_fraction
	recipe.continents = rules.continents
	if planet.is_empty():
		return recipe
	var types: Dictionary = rules.planet_types
	recipe.merge(types.layouts[planet.layout], true)
	recipe.merge(types.climates[planet.climate], true)
	recipe.merge(types.reliefs[planet.relief], true)
	return recipe


## Everything drawn from the seed, before the sea level is known.
static func build_context(
	seed_value: int, attempt: int, rules: Dictionary, planet: Dictionary = {}
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value * 131 + attempt) * 1000003 + 0x2C2
	var recipe: Dictionary = _recipe(rules, planet)
	var land_range: Array = recipe.land
	var continent_range: Array = recipe.continents
	var ctx: Dictionary = {
		"seed": seed_value,
		"attempt": attempt,
		"target_land": rng.randf_range(float(land_range[0]), float(land_range[1])),
		"temperature_base_c":
		rng.randf_range(float(recipe.temperature[0]), float(recipe.temperature[1])),
		"rainfall_base": rng.randf_range(float(recipe.rainfall[0]), float(recipe.rainfall[1])),
		"pressure_atm": rng.randf_range(0.88, 1.16),
		"oxygen_fraction": rng.randf_range(0.20, 0.23),
		"ocean_depth_m": rng.randf_range(3200, 6200),
		"elevation_scale": rng.randf_range(float(recipe.elevation[0]), float(recipe.elevation[1])),
		"sea_level": 0.0,
		"warp": float(recipe.warp),
		"broad": float(recipe.broad),
	}
	if not planet.is_empty():
		ctx.character = planet
		# Warmer planets have smaller ice caps; the hottest have none.
		ctx.ice_latitude = (
			ICE_LATITUDE + (float(ctx.temperature_base_c) - ICE_REFERENCE_C) * ICE_DEGREES_PER_C
		)
	var continent_count: int = rng.randi_range(int(continent_range[0]), int(continent_range[1]))
	var centers: Array[Vector3] = _continent_centers(rng, continent_count, ctx.target_land, recipe)
	var blobs: Dictionary = {
		"center": PackedVector3Array(),
		"u": PackedVector3Array(),
		"v": PackedVector3Array(),
		"su": PackedFloat64Array(),
		"sv": PackedFloat64Array(),
		"weight": PackedFloat64Array(),
	}
	var radius: float = _continent_radius(continent_count, ctx.target_land)
	var first: bool = true
	for center: Vector3 in centers:
		var size: float = radius * rng.randf_range(float(recipe.spread[0]), float(recipe.spread[1]))
		if first:
			size *= float(recipe.lead)
			first = false
		_add_continent(rng, blobs, center, size, recipe)
	for _arc: int in range(rng.randi_range(int(recipe.chains[0]), int(recipe.chains[1]))):
		_add_island_chain(rng, blobs)
	ctx.blob_center = blobs.center
	ctx.blob_u = blobs.u
	ctx.blob_v = blobs.v
	ctx.blob_su = blobs.su
	ctx.blob_sv = blobs.sv
	ctx.blob_weight = blobs.weight
	ctx.continent_count = continent_count
	_add_plates(rng, ctx, centers)
	return ctx


## Plain description of a context, for the saved generation record and the world page.
static func describe(ctx: Dictionary) -> Dictionary:
	var description: Dictionary = {
		"schema": "plates-2",
		"attempt": int(ctx.attempt),
		"sea_level": float(ctx.sea_level),
		"target_land": float(ctx.target_land),
		"continents_planned": int(ctx.continent_count),
		"plates": ctx.plate_center.size(),
		"temperature_base_c": float(ctx.temperature_base_c),
		"rainfall_base": float(ctx.rainfall_base),
		"pressure_atm": float(ctx.pressure_atm),
		"oxygen_fraction": float(ctx.oxygen_fraction),
		"ocean_depth_m": float(ctx.ocean_depth_m),
		"elevation_scale": float(ctx.elevation_scale),
		"mountain_ranges": [],
	}
	if ctx.has("character"):
		description.character = ctx.character
	return description


static func _continent_radius(count: int, target_land: float) -> float:
	# Blob radius in radians whose coasts roughly enclose the wanted land area.
	return sqrt(4.0 * target_land / float(count)) * 0.92


static func _continent_centers(
	rng: RandomNumberGenerator, count: int, target_land: float, recipe: Dictionary
) -> Array[Vector3]:
	var centers: Array[Vector3] = []
	var spacing: float = _continent_radius(count, target_land) * float(recipe.spacing)
	var cap: float = deg_to_rad(float(recipe.cap_degrees))
	var axis: Vector3 = _random_point(rng, 45.0) if cap > 0.0 else Vector3.UP
	for _index: int in range(count):
		var best: Vector3 = Vector3.UP
		var best_gap: float = -1.0
		for _try: int in range(40):
			var candidate: Vector3 = (
				_point_in_cap(rng, axis, cap)
				if cap > 0.0
				else _random_point(rng, float(recipe.max_latitude))
			)
			var gap: float = PI
			for other: Vector3 in centers:
				gap = minf(gap, candidate.angle_to(other))
			if gap > best_gap:
				best_gap = gap
				best = candidate
			if gap >= spacing:
				break
		centers.append(best)
	return centers


static func _random_point(rng: RandomNumberGenerator, max_latitude: float) -> Vector3:
	# Uniform on the sphere's area inside the latitude limit.
	var limit: float = sin(deg_to_rad(max_latitude))
	var lat: float = asin(rng.randf_range(-limit, limit))
	return SeedGeo.unit(rad_to_deg(lat), rng.randf_range(-180.0, 180.0))


## Uniform on the sphere's area within an angle of the axis: land gathered on one side.
static func _point_in_cap(rng: RandomNumberGenerator, axis: Vector3, cap: float) -> Vector3:
	var frame: Array[Vector3] = _tangent_frame(rng, axis)
	var along: float = rng.randf_range(cos(cap), 1.0)
	var around: Vector3 = frame[0] * sqrt(maxf(0.0, 1.0 - along * along))
	return (axis * along + around).normalized()


static func _tangent_frame(rng: RandomNumberGenerator, center: Vector3) -> Array[Vector3]:
	var seedling: Vector3 = Vector3.UP if absf(center.y) < 0.9 else Vector3.RIGHT
	var u: Vector3 = center.cross(seedling).normalized()
	var v: Vector3 = center.cross(u).normalized()
	var turn: float = rng.randf_range(0.0, TAU)
	return [u * cos(turn) + v * sin(turn), v * cos(turn) - u * sin(turn)]


static func _add_blob(
	blobs: Dictionary, center: Vector3, frame: Array[Vector3], su: float, sv: float, weight: float
) -> void:
	blobs.center.append(center)
	blobs.u.append(frame[0])
	blobs.v.append(frame[1])
	blobs.su.append(su)
	blobs.sv.append(sv)
	blobs.weight.append(weight)


static func _add_continent(
	rng: RandomNumberGenerator,
	blobs: Dictionary,
	center: Vector3,
	radius: float,
	recipe: Dictionary
) -> void:
	var frame: Array[Vector3] = _tangent_frame(rng, center)
	var stretch: float = rng.randf_range(float(recipe.stretch[0]), float(recipe.stretch[1]))
	_add_blob(blobs, center, frame, radius * stretch, radius / stretch, 1.0)
	# Arms and peninsulas: smaller lobes pushed out from the core.
	for _lobe: int in range(rng.randi_range(int(recipe.lobes[0]), int(recipe.lobes[1]))):
		var angle: float = rng.randf_range(0.0, TAU)
		var reach: float = radius * rng.randf_range(0.7, 1.15)
		var offset: Vector3 = (frame[0] * cos(angle) + frame[1] * sin(angle)) * reach
		var lobe: Vector3 = (center + offset).normalized()
		var size: float = radius * rng.randf_range(0.42, 0.72)
		_add_blob(blobs, lobe, _tangent_frame(rng, lobe), size * 1.25, size / 1.25, 0.86)


static func _add_island_chain(rng: RandomNumberGenerator, blobs: Dictionary) -> void:
	var at: Vector3 = _random_point(rng, 58.0)
	var frame: Array[Vector3] = _tangent_frame(rng, at)
	var heading: Vector3 = frame[0]
	var steps: int = rng.randi_range(3, 7)
	for _step: int in range(steps):
		var size: float = rng.randf_range(0.05, 0.1)
		_add_blob(blobs, at, _tangent_frame(rng, at), size, size, rng.randf_range(0.72, 0.92))
		heading = (heading + frame[1] * rng.randf_range(-0.35, 0.35)).normalized()
		at = (at + heading * rng.randf_range(0.09, 0.17)).normalized()
		frame = _tangent_frame(rng, at)
		heading = (heading - at * heading.dot(at)).normalized()


static func _add_plates(
	rng: RandomNumberGenerator, ctx: Dictionary, continents: Array[Vector3]
) -> void:
	var centers := PackedVector3Array()
	var drifts := PackedVector3Array()
	var continental := PackedByteArray()
	for core: Vector3 in continents:
		# Plate centres sit off the continent core, so belts cross land instead of ringing it.
		var frame: Array[Vector3] = _tangent_frame(rng, core)
		var center: Vector3 = (core + frame[0] * rng.randf_range(0.1, 0.45)).normalized()
		centers.append(center)
		continental.append(1)
	for _ocean: int in range(rng.randi_range(OCEAN_PLATES[0], OCEAN_PLATES[1])):
		var best: Vector3 = _random_point(rng, 80.0)
		var best_gap: float = -1.0
		for _try: int in range(16):
			var candidate: Vector3 = _random_point(rng, 80.0)
			var gap: float = PI
			for other: Vector3 in centers:
				gap = minf(gap, candidate.angle_to(other))
			if gap > best_gap:
				best_gap = gap
				best = candidate
		centers.append(best)
		continental.append(0)
	for center: Vector3 in centers:
		var frame: Array[Vector3] = _tangent_frame(rng, center)
		drifts.append(frame[0] * rng.randf_range(0.4, 1.0))
	var count: int = centers.size()
	var convergence := PackedFloat64Array()
	convergence.resize(count * count)
	for a: int in range(count):
		for b: int in range(count):
			if a == b:
				continue
			var normal: Vector3 = (centers[b] - centers[a]).normalized()
			var closing: float = (drifts[a] - drifts[b]).dot(normal) * 0.7
			if continental[a] == 0 and continental[b] == 0:
				closing *= OCEANIC_RIDGE_FACTOR
			convergence[a * count + b] = clampf(closing, -1.0, 1.0)
	ctx.plate_center = centers
	ctx.plate_convergence = convergence


## Warped point on the sphere used for every large-scale lookup.
static func _warp(p: Vector3, noise: FastNoiseLite, amount: float) -> Vector3:
	var warp := Vector3(
		noise.get_noise_3dv(p * 1.9 + Vector3(13, 7, -4)),
		noise.get_noise_3dv(p * 1.9 + Vector3(-9, 3, 17)),
		noise.get_noise_3dv(p * 1.9 + Vector3(5, -15, 8))
	)
	return (p + warp * amount).normalized()


static func _landmass(q: Vector3, ctx: Dictionary) -> float:
	var centers: PackedVector3Array = ctx.blob_center
	var us: PackedVector3Array = ctx.blob_u
	var vs: PackedVector3Array = ctx.blob_v
	var sus: PackedFloat64Array = ctx.blob_su
	var svs: PackedFloat64Array = ctx.blob_sv
	var weights: PackedFloat64Array = ctx.blob_weight
	var best: float = 0.0
	for i: int in range(centers.size()):
		var center: Vector3 = centers[i]
		if q.dot(center) <= 0.0:
			continue
		var x: float = q.dot(us[i]) / sus[i]
		var y: float = q.dot(vs[i]) / svs[i]
		var value: float = weights[i] * exp(-1.6 * (x * x + y * y))
		if value > best:
			best = value
	return best


## Positive along converging plate edges, slightly negative along spreading ones.
static func _ridge(q: Vector3, ctx: Dictionary) -> float:
	var centers: PackedVector3Array = ctx.plate_center
	var count: int = centers.size()
	var first: float = -2.0
	var second: float = -2.0
	var a: int = 0
	var b: int = 0
	for i: int in range(count):
		var d: float = q.dot(centers[i])
		if d > first:
			second = first
			b = a
			first = d
			a = i
		elif d > second:
			second = d
			b = i
	var closing: float = ctx.plate_convergence[a * count + b]
	var gap: float = (first - second) / BELT_WIDTH
	if gap > 3.0:
		return 0.0
	var belt: float = exp(-gap * gap)
	return belt * closing if closing > 0.0 else belt * closing * RIFT_DEPTH


## The value compared with the sea level, and its parts. The grid pass uses it to find the level.
static func raw_height(p: Vector3, noise: FastNoiseLite, ctx: Dictionary) -> Dictionary:
	var q: Vector3 = _warp(p, noise, float(ctx.warp))
	var ridge: float = _ridge(q, ctx)
	if ridge > 0.0:
		ridge *= (
			0.55 + 0.75 * clampf(noise.get_noise_3dv(q * 4.6 + Vector3(2, 9, -7)) + 0.5, 0.0, 1.0)
		)
	var land: float = _landmass(q, ctx)
	var broad: float = noise.get_noise_3dv(p * 3.6 + Vector3(4, 1, 8))
	var medium: float = noise.get_noise_3dv(p * 11.0 + Vector3(-4, 12, 2))
	var fine: float = noise.get_noise_3dv(p * 37.0 + Vector3(7, -2, 9))
	return {
		"raw": land + broad * float(ctx.broad) + medium * 0.075 + fine * 0.024 + ridge * RAW_RIDGE,
		"ridge": ridge,
		"q": q,
	}


## Same result as raw_height(), turned into a full geography sample.
static func sample(lat: float, lon: float, noise: FastNoiseLite) -> Dictionary:
	return sample_with_context(lat, lon, noise, context(noise.seed))


static func sample_with_context(
	lat: float, lon: float, noise: FastNoiseLite, ctx: Dictionary
) -> Dictionary:
	var p: Vector3 = SeedGeo.unit(lat, lon)
	return finish_sample(lat, lon, p, raw_height(p, noise, ctx), noise, ctx)


static func finish_sample(
	lat: float, lon: float, p: Vector3, parts: Dictionary, noise: FastNoiseLite, ctx: Dictionary
) -> Dictionary:
	var coast: float = float(parts.raw) - float(ctx.sea_level)
	var ridge: float = maxf(float(parts.ridge), 0.0)
	var height: float
	if coast > 0.0:
		var detail: float = noise.get_noise_3dv(p * 9.0)
		height = (
			(
				coast * HEIGHT_PER_COAST
				+ ridge * HEIGHT_PER_RIDGE
				+ maxf(detail, 0.0) * HEIGHT_PER_DETAIL
			)
			* float(ctx.elevation_scale)
		)
	else:
		var offshore: float = clampf(-coast / 0.26, 0.0, 1.0)
		var abyss: float = 0.86 + noise.get_noise_3dv(p * 5.0 + Vector3(19, -6, 4)) * 0.42
		height = (
			-maxf(8.0, float(ctx.ocean_depth_m) * pow(offshore, 1.7) * abyss) / METRES_PER_HEIGHT
		)
	var temperature: float = temperature_at(lat, height, p, noise, ctx)
	var rainfall: float = rainfall_at(lat, lon, ridge, p, noise, ctx)
	return {
		"height": height,
		"temperature": temperature,
		"rainfall": rainfall,
		"land": coast > 0.0,
		"river": false,
		"lake": false,
		"biome": biome_at(coast > 0.0, height, temperature, rainfall),
		"ocean_depth_m": maxf(0.0, -height * METRES_PER_HEIGHT),
		"ridge": ridge,
	}


static func temperature_at(
	lat: float, height: float, p: Vector3, noise: FastNoiseLite, ctx: Dictionary
) -> float:
	var greenhouse: float = (float(ctx.pressure_atm) - 1.0) * 8.0
	return (
		float(ctx.temperature_base_c)
		- absf(lat) * 0.48
		- maxf(height, 0.0) * 28.0
		+ noise.get_noise_3dv(p * 2.2) * 4.0
		+ greenhouse
	)


## Latitude bands (wet tropics, dry subtropics, wet mid-latitudes, dry poles), minus the rain the
## mountains here and upwind have already taken.
static func rainfall_at(
	lat: float, lon: float, ridge: float, p: Vector3, noise: FastNoiseLite, ctx: Dictionary
) -> float:
	var band: float = 0.17 * cos(deg_to_rad(absf(lat) * 6.0))
	band -= maxf(0.0, absf(lat) - 62.0) * 0.006
	# Trade winds below 30°, westerlies to 60°, polar easterlies beyond.
	var from_east: bool = absf(lat) < 30.0 or absf(lat) > 60.0
	var upwind_lon: float = lon + (UPWIND_DEGREES if from_east else -UPWIND_DEGREES)
	var upwind: float = maxf(_ridge(SeedGeo.unit(lat, upwind_lon), ctx), 0.0)
	return clampf(
		(
			float(ctx.rainfall_base)
			+ band
			+ noise.get_noise_3dv(p * 3.0 + Vector3(-11, 6, 3)) * 0.34
			- ridge * 0.3
			- upwind * 0.5
		),
		0.04,
		0.98
	)


static func biome_at(is_land: bool, height: float, temperature: float, rainfall: float) -> String:
	if not is_land:
		return "ocean"
	if temperature < -3.0:
		return "tundra"
	if height > 0.48:
		return "alpine"
	if rainfall < 0.27:
		return "desert"
	if rainfall > 0.59:
		return "forest"
	return "grassland" if rainfall > 0.40 else "steppe"
