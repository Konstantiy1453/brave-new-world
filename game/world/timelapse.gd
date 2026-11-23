extends RefCounted
## The colony's night, played back (1.11 G): the quarterly light record (light_record.gd) turned
## into the planet-scale town forms that the globe shader draws from a few numbers per town
## (shaders.gd TOWN_LIGHTS_GLSL: a bright core, a lit street grid, arms and suburbs as a town
## grows). These are the 1.9 forms with their 1.9 sizes; the five stages of the user's light
## concept sheet replace them when it arrives (DECISIONS.md). Display only.

const MAX_TOWNS: int = 48
const GLOBE_RADIUS: float = 3.0
## The population the brightest, densest form stands for.
const METROPOLIS: float = 3000.0
## Homes are not in the record: one for about this many people, for the size of the built area.
const PEOPLE_PER_HOME: float = 40.0
## The share of a town's light that is cold work light.
const WORK_SHARE: float = 0.4


## The towns on `day`, between the snapshots around it; a town missing from the earlier snapshot
## grows in from nothing.
static func towns_on(snapshots: Array, day: float) -> Array:
	if snapshots.is_empty():
		return []
	var index: int = 0
	while index + 1 < snapshots.size() and float(snapshots[index + 1].day) <= day:
		index += 1
	var before: Dictionary = snapshots[index]
	var after: Dictionary = snapshots[mini(index + 1, snapshots.size() - 1)]
	var span: float = maxf(1.0, float(after.day) - float(before.day))
	var t: float = clampf((day - float(before.day)) / span, 0.0, 1.0)
	if float(after.day) <= float(before.day):
		t = 0.0
	var earlier: Dictionary = {}
	for town: Dictionary in before.towns:
		earlier[int(town.region)] = town
	var out: Array = []
	for town: Dictionary in after.towns if t > 0.0 else before.towns:
		var was: Dictionary = earlier.get(int(town.region), {})
		(
			out
			. append(
				{
					"region": int(town.region),
					"lat": float(town.lat),
					"lon": float(town.lon),
					"population": lerpf(float(was.get("population", 0)), float(town.population), t),
					"facilities": lerpf(float(was.get("facilities", 0)), float(town.facilities), t),
					"frontier": bool(town.get("frontier", false)),
					"fade": 1.0 if not was.is_empty() else t,
				}
			)
		)
	return out


## The shader's arrays for these towns: towns[i] = (lat, lon, radius in degrees, seed) and
## town_style[i] = (brightness, cold share, size 0-1, frontier).
static func uniforms(towns: Array) -> Dictionary:
	var places: Array = []
	var styles: Array = []
	for town: Dictionary in towns:
		if places.size() >= MAX_TOWNS:
			break
		var people: float = float(town.population)
		var size: float = clampf(log(1.0 + people / 40.0) / log(1.0 + METROPOLIS / 40.0), 0.0, 1.0)
		var built: float = float(town.facilities) + people / PEOPLE_PER_HOME
		var radius: float = rad_to_deg((0.05 + sqrt(built) * 0.022) / GLOBE_RADIUS)
		var frontier: bool = bool(town.frontier)
		var shine: float = ((0.45 if frontier else 0.6) + 0.5 * size) * float(town.fade)
		var seed_value: float = float(posmod(int(town.region) * 7717 + 3, 997)) + 0.37
		places.append(Vector4(float(town.lat), float(town.lon), maxf(radius, 0.25), seed_value))
		styles.append(Vector4(shine, WORK_SHARE, size, 1.0 if frontier else 0.0))
	var count: int = places.size()
	while places.size() < MAX_TOWNS:
		places.append(Vector4.ZERO)
		styles.append(Vector4.ZERO)
	return {"towns": places, "styles": styles, "count": count}
