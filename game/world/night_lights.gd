extends RefCounted
## The night side of the map. Lit roads are painted into one equirectangular texture (red warm
## light, green cold white light); settlements are drawn by the globe and flat-map shaders from a
## few numbers each (shaders.gd TOWN_LIGHTS_GLSL), as orbit photos show towns at night: a bright
## core, an irregular built-up outline, lit blocks on a street grid and ribbons along the
## arterial roads, growing from a few lights round a landing site to a metropolis with suburbs.

const WIDTH: int = 2048
const HEIGHT: int = 1024
const GLOBE_RADIUS: float = 3.0
## Degrees between two lamps along a finished road.
const ROAD_STEP_DEGREES: float = 0.32
const MAX_LIGHTS_PER_TOWN: int = 900
## The shaders' arrays hold this many settlements (shaders.gd MAX_TOWNS).
const MAX_TOWNS: int = 48
## A settlement this populous counts as a metropolis: its lights stop growing brighter.
const METROPOLIS: float = 3000.0
const INDUSTRY_ROLES: Array[String] = ["mine", "harvest", "factory", "power", "port", "depot"]


## What a settlement contributes: centre, spread and how many lights, from its buildings.
static func town_source(
	settlement: Dictionary, region: Dictionary, roles: Dictionary
) -> Dictionary:
	var built: int = 0
	var industry: int = 0
	for building: Dictionary in settlement.get("buildings", []):
		if int(building.get("remaining", 0)) > 0:
			continue
		built += 1
		if str(roles.get(str(building.kind), "")) in INDUSTRY_ROLES:
			industry += 1
	var frontier: bool = str(settlement.get("kind", "residential")) == "frontier"
	var population: float = float(settlement.get("population", 0))
	# The same radius as the town footprint drawn on the map.
	var radius_units: float = 0.05 + sqrt(float(built)) * 0.022
	var count: float = (
		(14.0 + built * 5.0 + population / 10.0)
		if frontier
		else (30.0 + built * 7.0 + population / 6.0)
	)
	# 0 for a landing site, 1 for a metropolis: brightness, street density and suburbs follow it.
	var size: float = clampf(log(1.0 + population / 40.0) / log(1.0 + METROPOLIS / 40.0), 0.0, 1.0)
	return {
		"lat": float(region.lat),
		"lon": float(region.lon),
		"radius": rad_to_deg(radius_units / GLOBE_RADIUS),
		"count": mini(int(count), MAX_LIGHTS_PER_TOWN),
		"industry": clampf(float(industry) / maxf(1.0, float(built)), 0.0, 1.0),
		"frontier": frontier,
		"seed": int(region.id) * 7717 + 3,
		"size": size,
	}


## The shaders' town arrays: Vector4(lat, lon, radius in degrees, seed) and Vector4(brightness,
## cold-light share, size, frontier), padded to MAX_TOWNS.
static func town_uniforms(towns: Array) -> Dictionary:
	var places: Array = []
	var styles: Array = []
	for town: Dictionary in towns:
		if places.size() >= MAX_TOWNS:
			break
		var size: float = float(town.get("size", 0.0))
		var frontier: bool = bool(town.frontier)
		var cold: float = clampf(
			float(town.industry) * (0.75 if frontier else 0.5) + size * 0.2, 0.0, 1.0
		)
		var shine: float = (0.45 if frontier else 0.6) + 0.5 * size
		# Seeds kept small: the shader hashes them as floats.
		var seed_value: float = float(posmod(int(town.seed), 997)) + 0.37
		places.append(
			Vector4(float(town.lat), float(town.lon), maxf(float(town.radius), 0.25), seed_value)
		)
		styles.append(Vector4(shine, cold, size, 1.0 if frontier else 0.0))
	var count: int = places.size()
	while places.size() < MAX_TOWNS:
		places.append(Vector4.ZERO)
		styles.append(Vector4.ZERO)
	return {"towns": places, "styles": styles, "count": count}


## The lit roads; towns are the shaders' (town_uniforms).
static func paint(roads: Array) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RG8)
	for road: Array in roads:
		_paint_road(image, road)
	image.generate_mipmaps()
	return image


## Lamps every few tenths of a degree along a finished, open road.
static func _paint_road(image: Image, coordinates: Array) -> void:
	if coordinates.size() < 2:
		return
	var carried: float = 0.0
	var count: int = 0
	for index: int in range(coordinates.size() - 1):
		var a: Array = coordinates[index]
		var b: Array = coordinates[index + 1]
		var lat_a: float = float(a[0])
		var lon_a: float = float(a[1])
		var lat_b: float = float(b[0])
		var lon_b: float = lon_a + wrapf(float(b[1]) - lon_a, -180.0, 180.0)
		var scale: float = cos(deg_to_rad((lat_a + lat_b) * 0.5))
		var length: float = Vector2((lon_b - lon_a) * scale, lat_b - lat_a).length()
		var at: float = ROAD_STEP_DEGREES - carried
		while at <= length:
			var t: float = at / maxf(length, 0.0001)
			count += 1
			var strong: bool = count % 5 == 0
			_add(
				image,
				lerpf(lat_a, lat_b, t),
				lerpf(lon_a, lon_b, t),
				0.62 if strong else 0.4,
				0.12 if strong else 0.0
			)
			at += ROAD_STEP_DEGREES
		carried = length - (at - ROAD_STEP_DEGREES)


## A lamp: a bright texel and a faint ring round it, so a road seen close is a string of glows.
static func _add(image: Image, lat: float, lon: float, warm: float, cold: float) -> void:
	var x: int = posmod(int(floor((wrapf(lon, -180.0, 180.0) + 180.0) / 360.0 * WIDTH)), WIDTH)
	var y: int = clampi(int(floor((90.0 - lat) / 180.0 * HEIGHT)), 0, HEIGHT - 1)
	_lighten(image, x, y, warm, cold)
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_lighten(
			image,
			posmod(x + step.x, WIDTH),
			clampi(y + step.y, 0, HEIGHT - 1),
			warm * 0.3,
			cold * 0.3
		)


static func _lighten(image: Image, x: int, y: int, warm: float, cold: float) -> void:
	var old: Color = image.get_pixel(x, y)
	image.set_pixel(x, y, Color(minf(old.r + warm, 1.0), minf(old.g + cold, 1.0), 0.0, 1.0))
