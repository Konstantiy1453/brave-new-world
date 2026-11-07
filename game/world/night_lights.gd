extends RefCounted
## The night side of the map: settlements and lit roads painted into one equirectangular texture.
## Red is warm light (homes, streets, roads), green is cold white light (mines and industry).
## The globe and the flat map read the same texture and show it only where the sun has set.

const WIDTH: int = 2048
const HEIGHT: int = 1024
const GLOBE_RADIUS: float = 3.0
## Degrees between two lamps along a finished road.
const ROAD_STEP_DEGREES: float = 0.32
const MAX_LIGHTS_PER_TOWN: int = 900
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
	return {
		"lat": float(region.lat),
		"lon": float(region.lon),
		"radius": rad_to_deg(radius_units / GLOBE_RADIUS),
		"count": mini(int(count), MAX_LIGHTS_PER_TOWN),
		"industry": clampf(float(industry) / maxf(1.0, float(built)), 0.0, 1.0),
		"frontier": frontier,
		"seed": int(region.id) * 7717 + 3,
	}


static func paint(towns: Array, roads: Array) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RG8)
	for road: Array in roads:
		_paint_road(image, road)
	for town: Dictionary in towns:
		_paint_town(image, town)
	image.generate_mipmaps()
	return image


## A town is a bright core, a scatter of streets and a few arms reaching out along its roads.
static func _paint_town(image: Image, town: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(town.seed)
	var lat: float = float(town.lat)
	var lon: float = float(town.lon)
	var radius: float = maxf(float(town.radius), 0.3)
	var stretch: float = 1.0 / maxf(cos(deg_to_rad(lat)), 0.2)
	var industry: float = float(town.industry)
	var frontier: bool = bool(town.frontier)
	var count: int = int(town.count)
	var arms: int = 3 + rng.randi_range(0, 2)
	var arm_angles: Array[float] = []
	for _arm: int in range(arms):
		arm_angles.append(rng.randf() * TAU)
	for index: int in range(count):
		var along_arm: bool = index % 4 == 3
		var dy: float
		var dx: float
		if along_arm:
			var angle: float = arm_angles[index % arms]
			var reach: float = rng.randf_range(0.2, 1.6) * radius
			dy = sin(angle) * reach + rng.randfn(0.0, radius * 0.06)
			dx = cos(angle) * reach + rng.randfn(0.0, radius * 0.06)
		else:
			dy = rng.randfn(0.0, radius * (0.62 if frontier else 0.45))
			dx = rng.randfn(0.0, radius * (0.62 if frontier else 0.45))
		var brightness: float = rng.randf_range(0.35, 1.0)
		var cold: bool = rng.randf() < industry * (0.75 if frontier else 0.5)
		_add(
			image,
			lat + dy,
			lon + dx * stretch,
			0.0 if cold else brightness * 0.55,
			brightness * 0.6 if cold else 0.0
		)
	# The centre glows: the light every orbit photo picks out first.
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			var spread: float = 180.0 / float(HEIGHT)
			var weight: float = 0.5 if ox == 0 and oy == 0 else 0.22
			_add(image, lat + oy * spread, lon + ox * spread * stretch, weight, 0.0)


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


static func _add(image: Image, lat: float, lon: float, warm: float, cold: float) -> void:
	var x: int = posmod(int(floor((wrapf(lon, -180.0, 180.0) + 180.0) / 360.0 * WIDTH)), WIDTH)
	var y: int = clampi(int(floor((90.0 - lat) / 180.0 * HEIGHT)), 0, HEIGHT - 1)
	var old: Color = image.get_pixel(x, y)
	image.set_pixel(x, y, Color(minf(old.r + warm, 1.0), minf(old.g + cold, 1.0), 0.0, 1.0))
