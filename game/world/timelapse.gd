extends RefCounted
## The colony's night, played back (1.11 G): the quarterly light record (light_record.gd) drawn in
## the planet-scale forms of the user's light concept sheet (town_forms.gd, shaders.gd
## TOWN_LIGHTS_GLSL), each town at its stage and growing between them, coastal towns cut by the
## coast and spreading inland, arms along the roads each snapshot records. Display only.

const TownForms = preload("res://world/town_forms.gd")
const Rules = preload("res://simulation/rules.gd")
const MAX_TOWNS: int = TownForms.MAX_TOWNS


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
					"coastal": bool(town.get("coastal", false)),
					"roads": town.get("roads", []),
					"fade": 1.0 if not was.is_empty() else t,
				}
			)
		)
	return out


## The shader's arrays for these towns (town_forms.gd `uniforms`), on `world` for the coasts.
static func uniforms(towns: Array, world: Dictionary = {}) -> Dictionary:
	return TownForms.uniforms(towns, world, Rules.read("progression").get("lights", {}))
