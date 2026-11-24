extends RefCounted
## The colony's towns at planet scale after dark (1.11 G), in the forms of the user's concept sheet
## 沿海与内陆的灯光形态 (docs/v17/lights/concept_light_forms.webp): a lit street grid round a warm,
## white-hot core, the size fixed by the town's light stage (着陆点, 首批住区, 小镇, 区域中心,
## 星球首府; progression.json `lights`) and growing with the town between stages. A coastal town
## is cut by the real coastline (the globe shader's land mask) and spreads inland; an inland one
## spreads outwards, with arms along the roads the player built. A facility far from its town is a
## point of its own and a finished road a faint string of light (`far_image`). The globe shows these
## at its default and far distances and the per-plot lights (light_field.gd) up close, crossfaded
## by camera distance (`weights`). Display only: nothing here is saved or changes the game.

const LightRecord = preload("res://simulation/light_record.gd")
const LightField = preload("res://world/light_field.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Keys = preload("res://simulation/keys.gd")

const MAX_TOWNS: int = 48
## A road slot with no road (the shader reads bearings above 9 radians as none).
const NO_ROAD: float = 10.0
const MAX_ROADS: int = 4
## The texture of faint road strings and remote points: equirectangular, a texel about 0.18°.
const FAR_WIDTH: int = 2048
const FAR_HEIGHT: int = 1024
## Directions sampled round a coastal town to find its sea, and the ring they are taken on.
const SEA_SAMPLES: int = 16
const SEA_RINGS: Array[float] = [0.5, 1.0]
## The smallest ring for a small town's sea search, in degrees.
const SEA_LEAST: float = 0.6


## The towns tonight, as the light record (light_record.gd) describes them, from the state alone.
static func towns_now(state: Dictionary, world: Dictionary, buildings: Dictionary) -> Array:
	var towns: Array = []
	var regions: Array = world.get("regions", [])
	for s: Dictionary in state.get("settlements", []):
		var region: int = int(s.get("region", -1))
		if int(s.get("arrival", 0)) > 0 or region < 0 or region >= regions.size():
			continue
		var reg: Dictionary = regions[region]
		(
			towns
			. append(
				{
					"region": region,
					"lat": float(s.get("lat", reg.lat)),
					"lon": float(s.get("lon", reg.lon)),
					"population": float(s.get("population", 0)),
					"facilities": float(LightRecord.facility_count(buildings, s)),
					"coastal": bool(reg.get("coast", false)),
					"frontier": str(s.get("kind", "")) == Keys.SITE_FRONTIER,
					"roads": LightRecord.roads_reaching(state, region),
					"fade": 1.0,
				}
			)
		)
	return towns


## The globe shader's arrays for these towns:
## towns[i] = (lat, lon, radius in degrees, seed), town_style[i] = (shine, cold share, level 0-4,
## frontier), town_shape[i] = (the way to the sea as east and north, zero inland, 0, 0) and
## town_roads[i] = up to four road bearings (radians from east, NO_ROAD when none).
static func uniforms(towns: Array, world: Dictionary, rules: Dictionary) -> Dictionary:
	var stages: Array = rules.get("stages", [])
	var forms: Dictionary = rules.get("forms", {})
	var where: Dictionary = {}
	for town: Dictionary in towns:
		where[int(town.region)] = Vector2(float(town.lat), float(town.lon))
	var places: Array = []
	var styles: Array = []
	var shapes: Array = []
	var ways: Array = []
	for town: Dictionary in towns:
		if places.size() >= MAX_TOWNS:
			break
		var level: float = LightRecord.stage_level(
			stages, float(town.population), float(town.facilities)
		)
		var radius: float = form_radius(stages, level)
		var nearest: float = nearest_town(town, towns)
		if nearest < INF:
			radius = minf(radius, nearest * float(forms.get("neighbour_share", 0.45)))
		var shine: float = _between(stages, level, "shine", 1.0) * float(town.get("fade", 1.0))
		var sea: Vector2 = (
			sea_direction(world, float(town.lat), float(town.lon), radius)
			if bool(town.get("coastal", false))
			else Vector2.ZERO
		)
		places.append(Vector4(float(town.lat), float(town.lon), radius, town_seed(town)))
		styles.append(
			Vector4(
				shine,
				float(forms.get("cold_share", 0.35)),
				level,
				1.0 if bool(town.get("frontier", false)) else 0.0
			)
		)
		shapes.append(Vector4(sea.x, sea.y, 0.0, 0.0))
		ways.append(road_bearings(town, where))
	var count: int = places.size()
	while places.size() < MAX_TOWNS:
		places.append(Vector4.ZERO)
		styles.append(Vector4.ZERO)
		shapes.append(Vector4.ZERO)
		ways.append(Vector4(NO_ROAD, NO_ROAD, NO_ROAD, NO_ROAD))
	return {"towns": places, "styles": styles, "shapes": shapes, "roads": ways, "count": count}


## The form's radius at a level: each stage's radius from the data, and between stages the way
## from one to the next, so a town grows in steps no bigger than its people do.
static func form_radius(stages: Array, level: float) -> float:
	return _between(stages, level, "radius_degrees", 0.25)


static func _between(stages: Array, level: float, field: String, fallback: float) -> float:
	if stages.is_empty():
		return fallback
	var low: int = clampi(int(floor(level)), 0, stages.size() - 1)
	var high: int = mini(low + 1, stages.size() - 1)
	var share: float = clampf(level - float(low), 0.0, 1.0)
	return lerpf(
		float(stages[low].get(field, fallback)), float(stages[high].get(field, fallback)), share
	)


static func town_seed(town: Dictionary) -> float:
	return float(posmod(int(town.region) * 7717 + 3, 997)) + 0.37


## Degrees of arc to the nearest other town, INF when it stands alone.
static func nearest_town(town: Dictionary, towns: Array) -> float:
	var here: Vector3 = _unit(float(town.lat), float(town.lon))
	var best: float = INF
	for other: Dictionary in towns:
		if int(other.region) == int(town.region):
			continue
		best = minf(best, rad_to_deg(here.angle_to(_unit(float(other.lat), float(other.lon)))))
	return best


## The way from a coastal town to its sea, (east, north) of unit length: the water among
## SEA_SAMPLES directions on two rings round it, on the world's land grid. Zero where the grid
## is missing (worlds from before 1.7.1) or no water is near: the shader's land mask still cuts the
## lights at the coast.
static func sea_direction(world: Dictionary, lat: float, lon: float, radius: float) -> Vector2:
	if not world.has("grid_width") or world.get("grid", []).is_empty():
		return Vector2.ZERO
	var reach: float = maxf(radius, SEA_LEAST)
	var toward: Vector2 = Vector2.ZERO
	for ring: float in SEA_RINGS:
		for index: int in range(SEA_SAMPLES):
			var angle: float = TAU * float(index) / float(SEA_SAMPLES)
			var way := Vector2(cos(angle), sin(angle))
			var at_lat: float = clampf(lat + way.y * reach * ring, -89.0, 89.0)
			var at_lon: float = wrapf(
				lon + way.x * reach * ring / maxf(cos(deg_to_rad(lat)), 0.2), -180.0, 180.0
			)
			var cell: Dictionary = world.grid[SiteGen.cell_at(world, at_lat, at_lon)]
			if not bool(cell.get("land", true)):
				toward += way
	return toward.normalized() if toward.length() > 0.01 else Vector2.ZERO


## The bearings of the roads the player built from this town to others (radians from east,
## counter-clockwise, as the shader measures them), up to MAX_ROADS.
static func road_bearings(town: Dictionary, where: Dictionary) -> Vector4:
	var bearings: Array = []
	for other: Variant in town.get("roads", []):
		if bearings.size() >= MAX_ROADS or not where.has(int(other)):
			continue
		var to: Vector2 = where[int(other)]
		var east: float = (
			wrapf(to.y - float(town.lon), -180.0, 180.0) * cos(deg_to_rad(float(town.lat)))
		)
		var north: float = to.x - float(town.lat)
		bearings.append(atan2(north, east))
	while bearings.size() < MAX_ROADS:
		bearings.append(NO_ROAD)
	return Vector4(bearings[0], bearings[1], bearings[2], bearings[3])


## How much of the night the per-plot lights and the town forms each give at a camera distance:
## the plots up close, the forms from far_distance out, crossfaded between; they add up to one,
## so a town is never drawn twice as bright.
static func weights(distance: float, rules: Dictionary) -> Vector2:
	var forms: Dictionary = rules.get("forms", {})
	var share: float = smoothstep(
		float(forms.get("near_distance", 7.6)), float(forms.get("far_distance", 9.4)), distance
	)
	return Vector2(1.0 - share, share)


## The faint strings of light along finished roads and the points of the facilities that stand
## apart (`remote_roles`: mines, harbours, ...) far from their town, painted for the globe's far
## view (red warm, green cold, as night_lights.gd). The town's other buildings are its form.
static func far_image(
	state: Dictionary, world: Dictionary, buildings: Dictionary, towns: Array, rules: Dictionary
) -> Image:
	var forms: Dictionary = rules.get("forms", {})
	var image := Image.create(FAR_WIDTH, FAR_HEIGHT, false, Image.FORMAT_RG8)
	var sizes: Dictionary = {}
	var shown: Dictionary = uniforms(towns, world, rules)
	for index: int in range(int(shown.count)):
		var place: Vector4 = shown.towns[index]
		sizes[int(towns[index].region)] = Vector3(place.x, place.y, place.z)
	var share: float = float(forms.get("remote_share", 0.8))
	var remote: Array = forms.get("remote_roles", [])
	var regions: Array = world.get("regions", [])
	for s: Dictionary in state.get("settlements", []):
		var region: int = int(s.get("region", -1))
		if not sizes.has(region) or region >= regions.size():
			continue
		var centre: Vector3 = sizes[region]
		for b: Dictionary in s.get("buildings", []):
			var spec: Dictionary = buildings.get(str(b.kind), {})
			if int(b.get("remaining", 0)) > 0 or not remote.has(str(spec.get("role", ""))):
				continue
			var at: Vector2 = LightField.plot_coordinate(world, regions[region], b)
			if _arc(at, Vector2(centre.x, centre.y)) > centre.z * share:
				_add(image, at.x, at.y, 0.0, float(forms.get("facility_point", 0.45)))
	var step: float = float(forms.get("road_step_degrees", 0.25))
	var glow: float = float(forms.get("road_light", 0.16))
	var day: int = int(state.get("day", 0))
	for road: Dictionary in state.get("roads", []):
		if str(road.get("variant", "")) in ["sea", "shuttle"]:
			continue
		if int(road.get("ready_day", 0)) > day or int(road.get("blocked_until", -1)) >= day:
			continue
		for at: Vector2 in _along(road.get("coordinates", []), step):
			var inside: bool = false
			for region: int in [int(road.a), int(road.b)]:
				if sizes.has(region):
					var centre: Vector3 = sizes[region]
					inside = inside or _arc(at, Vector2(centre.x, centre.y)) < centre.z * share
			if not inside:
				_add(image, at.x, at.y, glow, 0.0)
	image.generate_mipmaps()
	return image


## What the forms depend on, to repaint only when it changes: each town's level to a twentieth
## of a stage, its roads and its coast.
static func signature(towns: Array, rules: Dictionary) -> String:
	var parts: Array = []
	for town: Dictionary in towns:
		var level: float = LightRecord.stage_level(
			rules.get("stages", []), float(town.population), float(town.facilities)
		)
		parts.append([int(town.region), snappedf(level, 0.05), town.get("roads", [])])
	return str(parts)


## Points every `step` degrees along a polyline of [lat, lon] pairs.
static func _along(points: Array, step: float) -> Array:
	var out: Array = []
	if points.size() < 2:
		return out
	var carry: float = step * 0.5
	for index: int in range(points.size() - 1):
		var a := Vector2(float(points[index][0]), float(points[index][1]))
		var b := Vector2(float(points[index + 1][0]), float(points[index + 1][1]))
		b.y = a.y + wrapf(b.y - a.y, -180.0, 180.0)
		var length: float = a.distance_to(b)
		var at: float = carry
		while at < length:
			var spot: Vector2 = a.lerp(b, at / maxf(length, 0.0001))
			out.append(Vector2(spot.x, wrapf(spot.y, -180.0, 180.0)))
			at += step
		carry = at - length
	return out


static func _arc(a: Vector2, b: Vector2) -> float:
	return rad_to_deg(_unit(a.x, a.y).angle_to(_unit(b.x, b.y)))


static func _unit(lat: float, lon: float) -> Vector3:
	var la: float = deg_to_rad(lat)
	var lo: float = deg_to_rad(lon)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))


## A light spread over the four texels round its position (as night_lights.gd `_add`).
static func _add(image: Image, lat: float, lon: float, warm: float, cold: float) -> void:
	var at := Vector2(
		(wrapf(lon, -180.0, 180.0) + 180.0) / 360.0 * FAR_WIDTH - 0.5,
		(90.0 - lat) / 180.0 * FAR_HEIGHT - 0.5
	)
	var x0: int = int(floor(at.x))
	var y0: int = int(floor(at.y))
	var fx: float = at.x - x0
	var fy: float = at.y - y0
	for dy: int in [0, 1]:
		for dx: int in [0, 1]:
			var part: float = (fx if dx == 1 else 1.0 - fx) * (fy if dy == 1 else 1.0 - fy)
			var px: int = posmod(x0 + dx, FAR_WIDTH)
			var py: int = clampi(y0 + dy, 0, FAR_HEIGHT - 1)
			var old: Color = image.get_pixel(px, py)
			image.set_pixel(
				px,
				py,
				Color(minf(old.r + warm * part, 1.0), minf(old.g + cold * part, 1.0), 0.0, 1.0)
			)
