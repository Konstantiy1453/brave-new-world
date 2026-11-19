extends RefCounted
## The colony's lights after dark, made from the game's own state (1.10, plan B). Every building
## shines from its own plot, so the globe, the flat map and the district describe the same town:
## housing windows warm, filled in the order the homes were built as people arrive; work lamps
## cool where a facility is running; a lamp over a building site; a few lights where a road
## leaves town and where roads meet. Roads otherwise stay dark. The district maps to the planet at
## UNITS_PER_DEGREE (site_gen, region_ground), so a plot's lights land where the plot lies.
##
## A light is {lat, lon, warm, cold}: degrees on the planet and two brightnesses (warm and cold
## white), each 0-1. Nothing here is random: offsets come from the building's uid.

const WorldGen = preload("res://world/world_gen.gd")

const UNITS_PER_DEGREE: float = 4.0
## How far a building's lights spread round its plot centre, in district units.
const SPREAD: float = 0.9
## Beds behind one lit window.
const BEDS_PER_WINDOW: float = 15.0
## A building site's lamp.
const SITE_LAMP: float = 0.35
## Lights a running facility shows, by role: [warm count, cold count, brightness].
const WORK_LIGHTS: Dictionary = {
	"port": [0, 3, 0.8],
	"depot": [0, 2, 0.6],
	"mine": [0, 2, 0.55],
	"harvest": [0, 2, 0.5],
	"factory": [1, 2, 0.6],
	"power": [0, 2, 0.5],
	"water": [0, 1, 0.45],
	"scrubber": [0, 1, 0.4],
	"farm": [1, 0, 0.25],
	"indoor_farm": [2, 0, 0.45],
	"foodworks": [0, 2, 0.5],
	"income": [0, 2, 0.55],
	"lab": [1, 1, 0.55],
	"commerce": [3, 0, 0.6],
	"service": [2, 0, 0.5],
	"great": [2, 2, 0.75],
}
## Where a road leaves town: degrees out along it, and how bright.
const ENTRANCE_DEGREES: Array[float] = [0.55, 0.9]
const ENTRANCE_LAMP: float = 0.45
## A town where three links meet lights its junction.
const JUNCTION_LINKS: int = 3
const GOLDEN_ANGLE: float = 2.399963
## The landing camp's key among the homes' shares (no building has uid 0).
const CAMP: int = 0


## Every light in the colony tonight. `buildings` is the economy's building table (role, housing);
## `camps` holds each town's landing camp in district units (region_ground `landing_spot`).
static func lights(
	state: Dictionary, world: Dictionary, buildings: Dictionary, camps: Dictionary = {}
) -> Array:
	var found: Array = []
	for s: Dictionary in state.get("settlements", []):
		var region: int = int(s.get("region", -1))
		if region < 0 or region >= world.get("regions", []).size():
			continue
		found.append_array(
			settlement_lights(s, world, buildings, camps.get(region, Vector2(-6.0, 0.0)))
		)
	found.append_array(road_lights(state, world))
	return found


## The lights of one town, from its landing camp and its buildings at their plots.
static func settlement_lights(
	s: Dictionary, world: Dictionary, buildings: Dictionary, camp: Vector2 = Vector2(-6.0, 0.0)
) -> Array:
	var reg: Dictionary = world.regions[int(s.region)]
	var shares: Dictionary = housing_shares(s, buildings)
	var found: Array = []
	# The landing camp: its pods are the first homes, lit as they are lived in.
	var pods: int = int(s.get("base_housing", 0))
	if pods > 0:
		var windows: int = maxi(1, ceili(float(pods) / BEDS_PER_WINDOW))
		var lit: int = roundi(windows * float(shares.get(CAMP, 0.0)))
		for index: int in range(lit):
			var glow: float = 0.5 + 0.25 * _hash01(int(s.region) * 31 + 7, index)
			found.append(
				_light(
					world, reg, camp + _offset(int(s.region) * 31 + 7, index, windows), glow, 0.0
				)
			)
	for b: Dictionary in s.get("buildings", []):
		var spot: Vector2 = plot_point(reg, b)
		var uid: int = int(b.get("uid", 0))
		if int(b.get("remaining", 0)) > 0:
			found.append(_light(world, reg, spot, 0.0, SITE_LAMP))
			continue
		var spec: Dictionary = buildings.get(str(b.kind), {})
		var role: String = str(spec.get("role", "service" if b.kind == "service" else ""))
		if role == "housing":
			var windows: int = maxi(1, ceili(float(spec.get("housing", 15)) / BEDS_PER_WINDOW))
			var lit: int = roundi(windows * float(shares.get(uid, 0.0)))
			for index: int in range(lit):
				var glow: float = 0.45 + 0.3 * _hash01(uid, index)
				found.append(_light(world, reg, spot + _offset(uid, index, windows), glow, 0.0))
			continue
		if not bool(b.get("active", false)) or not WORK_LIGHTS.has(role):
			continue
		var recipe: Array = WORK_LIGHTS[role]
		var total: int = int(recipe[0]) + int(recipe[1])
		for index: int in range(total):
			var warm: bool = index < int(recipe[0])
			var glow: float = float(recipe[2]) * (0.75 + 0.25 * _hash01(uid, index))
			found.append(
				_light(
					world,
					reg,
					spot + _offset(uid, index, total),
					glow if warm else 0.0,
					0.0 if warm else glow
				)
			)
	return found


## Each home's share of its beds that is lived in, by uid (the landing camp under CAMP). The camp
## fills first and homes in the order they were built, so the first lights stay lit and a new
## block lights up as people arrive.
static func housing_shares(s: Dictionary, buildings: Dictionary) -> Dictionary:
	var homes: Array = []
	for b: Dictionary in s.get("buildings", []):
		if int(b.get("remaining", 0)) > 0:
			continue
		if str(buildings.get(str(b.kind), {}).get("role", "")) == "housing":
			homes.append(b)
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.uid) < int(b.uid))
	var people: float = float(s.get("population", 0))
	var shares: Dictionary = {}
	var camp_beds: float = float(s.get("base_housing", 0))
	if camp_beds > 0.0:
		shares[CAMP] = clampf(people / camp_beds, 0.0, 1.0)
		people = maxf(0.0, people - camp_beds)
	for b: Dictionary in homes:
		var beds: float = maxf(1.0, float(buildings[str(b.kind)].get("housing", 1)))
		var share: float = clampf(people / beds, 0.0, 1.0)
		shares[int(b.uid)] = share
		people = maxf(0.0, people - beds)
	return shares


## A building's plot centre in district units; a building without a plot stands in the centre.
static func plot_point(reg: Dictionary, b: Dictionary) -> Vector2:
	var plots: Array = reg.get("plots", [])
	var plot: int = int(b.get("plot", -1))
	if plot < 0 or plot >= plots.size():
		return Vector2.ZERO
	return Vector2(float(plots[plot].x), float(plots[plot].z))


## A few lamps where each finished road leaves a town, and a junction where three links meet. The
## rest of a road is dark: vehicles on it are drawn as they move.
static func road_lights(state: Dictionary, world: Dictionary) -> Array:
	var found: Array = []
	var links: Dictionary = {}
	var day: int = int(state.get("day", 0))
	for road: Dictionary in state.get("roads", []):
		if str(road.get("variant", "")) in ["sea", "shuttle"]:
			continue
		if int(road.get("ready_day", 0)) >= day or int(road.get("blocked_until", -1)) >= day:
			continue
		var points: Array = road.get("coordinates", [])
		if points.size() < 2:
			continue
		for end: int in [0, 1]:
			var town: int = int(road.a if end == 0 else road.b)
			links[town] = int(links.get(town, 0)) + 1
			var path: Array = points if end == 0 else _reversed(points)
			for at: float in ENTRANCE_DEGREES:
				var spot: Vector2 = _along(path, at)
				found.append({"lat": spot.x, "lon": spot.y, "warm": ENTRANCE_LAMP, "cold": 0.0})
	for town: int in links:
		if int(links[town]) < JUNCTION_LINKS or town < 0 or town >= world.regions.size():
			continue
		var reg: Dictionary = world.regions[town]
		for index: int in range(3):
			var spot: Vector2 = _offset(town * 977 + 11, index, 3) * 2.0 + Vector2(0.0, 2.5)
			found.append(_light(world, reg, spot, 0.5, 0.2))
	return found


## What the lights depend on, to repaint only when it changes: each building's state and lit
## windows, and each road's state.
static func signature(state: Dictionary, buildings: Dictionary) -> String:
	var parts: PackedStringArray = []
	for s: Dictionary in state.get("settlements", []):
		var shares: Dictionary = housing_shares(s, buildings)
		var pods: int = int(s.get("base_housing", 0))
		if pods > 0:
			var windows: int = maxi(1, ceili(float(pods) / BEDS_PER_WINDOW))
			parts.append("c%d:%d" % [int(s.region), roundi(windows * float(shares.get(CAMP, 0.0)))])
		for b: Dictionary in s.get("buildings", []):
			var spec: Dictionary = buildings.get(str(b.kind), {})
			var windows: int = maxi(1, ceili(float(spec.get("housing", 15)) / BEDS_PER_WINDOW))
			parts.append(
				(
					"%d:%d:%d:%d:%d"
					% [
						int(b.get("uid", 0)),
						int(b.get("plot", -1)),
						1 if int(b.get("remaining", 0)) > 0 else 0,
						1 if bool(b.get("active", false)) else 0,
						roundi(windows * float(shares.get(int(b.get("uid", 0)), 0.0)))
					]
				)
			)
	var day: int = int(state.get("day", 0))
	for road: Dictionary in state.get("roads", []):
		var open: bool = (
			int(road.get("ready_day", 0)) < day and int(road.get("blocked_until", -1)) < day
		)
		parts.append("r%d:%d" % [int(road.get("id", 0)), 1 if open else 0])
	return ",".join(parts)


## The mean position of a set of lights, weighted by brightness: [lat, lon].
static func centroid(found: Array) -> Vector2:
	var total: float = 0.0
	var sum := Vector2.ZERO
	for light: Dictionary in found:
		var weight: float = float(light.warm) + float(light.cold)
		sum += Vector2(float(light.lat), float(light.lon)) * weight
		total += weight
	return sum / total if total > 0.0 else Vector2.ZERO


static func _light(
	world: Dictionary, reg: Dictionary, local: Vector2, warm: float, cold: float
) -> Dictionary:
	var lat: float = float(reg.get("canonical_lat", reg.lat)) - local.y / UNITS_PER_DEGREE
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + local.x / UNITS_PER_DEGREE
	var shown: Vector2 = WorldGen.project_coordinate(lat, lon, world)
	return {"lat": shown.x, "lon": shown.y, "warm": warm, "cold": cold}


## Lights spread on a sunflower spiral round the plot centre, turned by the building's uid.
static func _offset(uid: int, index: int, count: int) -> Vector2:
	var radius: float = SPREAD * sqrt((float(index) + 0.5) / maxf(1.0, float(count)))
	var angle: float = float(index) * GOLDEN_ANGLE + _hash01(uid, 97) * TAU
	return Vector2(cos(angle), sin(angle)) * radius


static func _hash01(uid: int, index: int) -> float:
	var h: int = posmod(uid * 73856093 ^ (index + 1) * 19349663, 1000003)
	return float(h) / 1000003.0


## The point `degrees` out along a polyline of [lat, lon] pairs from its start: [lat, lon].
static func _along(points: Array, degrees: float) -> Vector2:
	var left: float = degrees
	for index: int in range(points.size() - 1):
		var a := Vector2(float(points[index][0]), float(points[index][1]))
		var b := Vector2(float(points[index + 1][0]), float(points[index + 1][1]))
		b.y = a.y + wrapf(b.y - a.y, -180.0, 180.0)
		var length: float = a.distance_to(b)
		if length >= left:
			var t: float = left / maxf(length, 0.0001)
			var at: Vector2 = a.lerp(b, t)
			return Vector2(at.x, wrapf(at.y, -180.0, 180.0))
		left -= length
	var last: Array = points.back()
	return Vector2(float(last[0]), float(last[1]))


static func _reversed(points: Array) -> Array:
	var copy: Array = points.duplicate()
	copy.reverse()
	return copy
