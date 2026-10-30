extends RefCounted
## Seeded spherical provinces. Cache is derived only from the seed; saved
## generation parameters describe the exact same bounded generator protocol.
static var _cache: Dictionary = {}
const SEED_PROTOCOL := "signed32-mod-v1"


static func normalize_seed(input: Variant) -> int:
	# Accumulate decimal text modulo 2^32 without parsing through float/int64.
	# Numeric and textual spellings of the same integer always name one world.
	var bits: int = 0
	if input is int:
		bits = int(input) & 0xffffffff
	else:
		var value: String = str(input).strip_edges()
		var digits: String = value.trim_prefix("-").trim_prefix("+")
		var decimal: bool = not digits.is_empty()
		for i in range(digits.length()):
			var code: int = digits.unicode_at(i)
			if code < 48 or code > 57:
				decimal = false
				break
		if decimal:
			for i in range(digits.length()):
				bits = (bits * 10 + digits.unicode_at(i) - 48) & 0xffffffff
			if value.begins_with("-"):
				bits = (-bits) & 0xffffffff
		else:
			bits = value.hash() & 0xffffffff
	return bits - 4294967296 if bits >= 2147483648 else bits


static func context(seed_value: int) -> Dictionary:
	seed_value = normalize_seed(seed_value)
	if _cache.has(seed_value):
		return _cache[seed_value]
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4A731BC
	var d: Dictionary = {
		"schema": "seeded-provinces-1",
		"rotation_degrees":
		[rng.randf_range(-28, 28), rng.randf_range(-180, 180), rng.randf_range(-25, 25)],
		"mainland_scale": [rng.randf_range(.90, 1.16), rng.randf_range(.90, 1.12)],
		"temperature_base_c": rng.randf_range(25, 32),
		"rainfall_base": rng.randf_range(.49, .76),
		"pressure_atm": rng.randf_range(.88, 1.16),
		"oxygen_fraction": rng.randf_range(.20, .23),
		"ocean_depth_m": rng.randf_range(3200, 6200),
		"elevation_scale": rng.randf_range(.82, 1.32),
		"continents": [],
		"island_groups": [],
		"mountain_ranges": [],
		"sea_level": rng.randf_range(.25, .34),
		"bay_shift": [rng.randf_range(-6, 6), rng.randf_range(-6, 6)],
		"wind_direction_degrees": rng.randf_range(-180, 180)
	}
	# Main economic province is varied in aspect and coastal morphology, then
	# every location is rotated on the sphere. Other landmasses are independent.
	for i in range(rng.randi_range(2, 4)):
		var lat: float = 0
		var lon: float = 0
		for attempt in range(100):
			lat = rng.randf_range(-63, 63)
			lon = rng.randf_range(-180, 180)
			var p: Vector3 = unit(lat, lon)
			if p.angle_to(unit(8, -27)) < deg_to_rad(68):
				continue
			if p.angle_to(unit(-22, 105)) < deg_to_rad(39):
				continue
			var separated: bool = true
			for c in d.continents:
				if p.angle_to(unit(c.lat, c.lon)) < deg_to_rad(39):
					separated = false
			if separated:
				break
		var c: Dictionary = {
			"lat": lat,
			"lon": lon,
			"sx": rng.randf_range(17, 34),
			"sy": rng.randf_range(16, 36),
			"angle": rng.randf_range(-65, 65),
			"arm_angle": rng.randf_range(-75, 75),
			"gulf_shift": rng.randf_range(-7, 7)
		}
		d.continents.append(c)
		d.mountain_ranges.append(
			{
				"lat": lat + rng.randf_range(-7, 7),
				"lon": lon + rng.randf_range(-7, 7),
				"sx": rng.randf_range(3, 8),
				"sy": rng.randf_range(10, 24),
				"angle": rng.randf_range(-75, 75),
				"height": rng.randf_range(.35, .78)
			}
		)
	d.mountain_ranges.append(
		{
			"lat": rng.randf_range(19, 24),
			"lon": rng.randf_range(-21, -17),
			"sx": rng.randf_range(4.5, 7),
			"sy": rng.randf_range(18, 24),
			"angle": rng.randf_range(-12, 12),
			"height": rng.randf_range(.59, .75)
		}
	)
	for i in range(rng.randi_range(3, 7)):
		d.island_groups.append(
			{
				"lat": rng.randf_range(-62, 59),
				"lon": rng.randf_range(-180, 180),
				"sx": rng.randf_range(3, 7),
				"sy": rng.randf_range(4, 10),
				"angle": rng.randf_range(-80, 80)
			}
		)
	var r: Array = d.rotation_degrees
	var basis: Basis = (
		Basis(Vector3.UP, deg_to_rad(r[1]))
		* Basis(Vector3.RIGHT, deg_to_rad(r[0]))
		* Basis(Vector3.FORWARD, deg_to_rad(r[2]))
	)
	var result: Dictionary = {"data": d, "basis": basis, "inverse": basis.transposed()}
	if _cache.size() >= 32:
		_cache.erase(_cache.keys()[0])
	_cache[seed_value] = result
	return result


static func unit(lat: float, lon: float) -> Vector3:
	var a: float = deg_to_rad(lat)
	var b: float = deg_to_rad(lon)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))


static func coordinate(p: Vector3) -> Vector2:
	return Vector2(rad_to_deg(asin(clampf(p.y, -1, 1))), rad_to_deg(atan2(p.x, p.z)))


static func project(lat: float, lon: float, seed_value: int) -> Vector2:
	return coordinate(context(seed_value).basis * unit(lat, lon))


static func unproject(lat: float, lon: float, seed_value: int) -> Vector2:
	return coordinate(context(seed_value).inverse * unit(lat, lon))


static func main_coordinate(lat: float, lon: float, seed_value: int) -> Vector2:
	var scale: Array = context(seed_value).data.mainland_scale
	return Vector2(8 + (lat - 8) * float(scale[1]), -27 + (lon + 27) * float(scale[0]))


static func blob(
	lat: float, lon: float, clat: float, clon: float, sx: float, sy: float, angle: float = 0
) -> float:
	var dx: float = wrapf(lon - clon, -180, 180)
	var dy: float = lat - clat
	var t: float = deg_to_rad(angle)
	var x: float = (dx * cos(t) - dy * sin(t)) / sx
	var y: float = (dx * sin(t) + dy * cos(t)) / sy
	return exp(-1.6 * (x * x + y * y))


static func sample(lat: float, lon: float, noise: FastNoiseLite) -> Dictionary:
	return sample_with_context(lat, lon, noise, context(noise.seed))


static func sample_with_context(
	lat: float, lon: float, noise: FastNoiseLite, ctx: Dictionary
) -> Dictionary:
	var d: Dictionary = ctx.data
	var global_point: Vector3 = unit(lat, lon)
	var local_point: Vector3 = ctx.inverse * global_point
	var ll: Vector2 = coordinate(local_point)
	var p: Vector3 = local_point
	var warp_lat: float = noise.get_noise_3dv(p * 2.7 + Vector3(13, 7, -4)) * 17
	var warp_lon: float = noise.get_noise_3dv(p * 2.7 + Vector3(-9, 3, 17)) * 22
	var a: float = ll.x + warp_lat * cos(deg_to_rad(ll.x))
	var b: float = ll.y + warp_lon
	var ca: float = 8 + (a - 8) / float(d.mainland_scale[1])
	var cb: float = -27 + wrapf(b + 27, -180, 180) / float(d.mainland_scale[0])
	var primary: float = maxf(
		blob(ca, cb, 15, -31, 32, 52, -23), blob(ca, cb, 40, 4, 37, 18, 24) * .86
	)
	primary = maxf(primary, blob(ca, cb, -26, -25, 16, 25, -36) * .83)
	primary = maxf(primary, blob(ca, cb, -3, -56, 24, 13, 18) * .8)
	primary = maxf(primary, blob(ca, cb, 54, -37, 20, 13, -15) * .86)
	primary -= blob(ca, cb, 23 + d.bay_shift[0], -65, 18, 11) * .78
	primary -= blob(ca, cb, 43, -19 + d.bay_shift[1], 10, 13) * .65
	primary -= blob(ca, cb, -22, 0, 13, 16) * .70
	primary -= blob(ca, cb, -14, -52, 11, 9) * .68
	var land: float = primary
	for c in d.continents:
		var mass: float = maxf(
			blob(a, b, c.lat, c.lon, c.sx, c.sy, c.angle),
			(
				blob(
					a, b, c.lat - c.sy * .55, c.lon + c.sx * .35, c.sx * .7, c.sy * .7, c.arm_angle
				)
				* .78
			)
		)
		mass -= blob(a, b, c.lat + c.gulf_shift, c.lon + c.sx * .65, c.sx * .55, c.sy * .35) * .8
		land = maxf(land, mass)
	for c in d.island_groups:
		land = maxf(land, blob(a, b, c.lat, c.lon, c.sx, c.sy, c.angle) * .72)
	land = maxf(land, blob(a, b, -24, 105, 11, 21, -31) * .78)
	land = maxf(land, blob(a, b, -3, 121, 9, 13, 28) * .65)
	land = maxf(land, blob(a, b, -42, 121, 14, 7, -12) * .68)
	var broad: float = noise.get_noise_3dv(p * 4 + Vector3(4, 1, 8))
	var medium: float = noise.get_noise_3dv(p * 13 + Vector3(-4, 12, 2))
	var fine: float = noise.get_noise_3dv(p * 43 + Vector3(7, -2, 9))
	var coast: float = land - float(d.sea_level) + broad * .22 + medium * .09 + fine * .028
	var plain_lat: float = 8 + (ll.x - 8) / float(d.mainland_scale[1])
	var plain_lon: float = -27 + wrapf(ll.y + 27, -180, 180) / float(d.mainland_scale[0])
	var heart: float = maxf(
		blob(plain_lat, plain_lon, 8, -27, 30, 46), blob(plain_lat, plain_lon, 24, -16, 17, 13)
	)
	if heart > .45:
		coast = maxf(coast, (heart - .50) * .8 + broad * .055 + medium * .025)
	coast -= blob(ca, cb, -18, -49, 16, 8) * .34
	var grass_anchor: float = blob(plain_lat, plain_lon, -9, -41, 6, 6)
	var south_anchor: float = blob(plain_lat, plain_lon, -29, -18, 6, 6)
	if grass_anchor > .32:
		coast = maxf(coast, (grass_anchor - .32) * .25)
	if south_anchor > .32:
		coast = maxf(coast, (south_anchor - .32) * .25)
	# Keep the prospective farming basin as a natural broad lowland. Actual
	# rivers are derived later by the drainage helper, not painted into this.
	var basin_anchor: float = blob(plain_lat, plain_lon, 5, -7, 9, 14)
	if basin_anchor > .32:
		coast = maxf(coast, (basin_anchor - .32) * .35)
	var island_distance: float = rad_to_deg(p.angle_to(unit(-22, 105)))
	if island_distance > 10 and island_distance < 19:
		coast = minf(coast, -.025)
	var island_anchor: float = blob(ll.x, ll.y, -22, 105, 7, 7)
	if island_anchor > .38:
		coast = maxf(coast, (island_anchor - .38) * .35)
	var ridges: float = 0
	for c in d.mountain_ranges:
		var m: float = blob(ll.x, ll.y, c.lat, c.lon, c.sx, c.sy, c.angle) * float(c.height)
		ridges = maxf(ridges, m)
	var detail: float = noise.get_noise_3dv(p * 9)
	var height: float = (
		(maxf(coast, 0) * .33 + ridges + maxf(detail, 0) * .17) * float(d.elevation_scale)
	)
	if coast <= 0:
		var offshore: float = clampf(-coast / .26, 0, 1)
		var abyss: float = .86 + noise.get_noise_3dv(p * 5 + Vector3(19, -6, 4)) * .42
		var depth: float = maxf(8.0, float(d.ocean_depth_m) * pow(offshore, 1.7) * abyss)
		height = -depth / 4300.0
	var greenhouse: float = (float(d.pressure_atm) - 1.0) * 8.0
	var temperature: float = (
		float(d.temperature_base_c)
		- absf(lat) * .48
		- maxf(height, 0) * 28
		+ noise.get_noise_3dv(global_point * 2.2) * 4
		+ greenhouse
	)
	var wind: Vector3 = Vector3(
		cos(deg_to_rad(d.wind_direction_degrees)), 0, sin(deg_to_rad(d.wind_direction_degrees))
	)
	var rainfall: float = clampf(
		(
			float(d.rainfall_base)
			- absf(lat) * .003
			+ noise.get_noise_3dv(global_point * 3 + wind * 5) * .40
			- ridges * .40
		),
		.04,
		.98
	)
	var biome: String = "ocean"
	if coast > 0:
		if temperature < -3:
			biome = "tundra"
		elif height > .48:
			biome = "alpine"
		elif rainfall < .27:
			biome = "desert"
		elif rainfall > .59:
			biome = "forest"
		elif rainfall > .40:
			biome = "grassland"
		else:
			biome = "steppe"
	return {
		"height": height,
		"temperature": temperature,
		"rainfall": rainfall,
		"land": coast > 0,
		"river": false,
		"lake": false,
		"biome": biome,
		"ocean_depth_m": maxf(0, -height * 4300),
		"ridge": ridges
	}
