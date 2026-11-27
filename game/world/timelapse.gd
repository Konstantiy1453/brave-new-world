extends RefCounted
## Interpolates the simulation's recorded towns for the same terrain-grown light renderer as live play.

const TownForms = preload("res://world/town_forms.gd")
const Rules = preload("res://simulation/rules.gd")
const LightRecord = preload("res://simulation/light_record.gd")
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
	var stages: Array = Rules.read("progression").lights.stages
	for town: Dictionary in after.towns if t > 0.0 else before.towns:
		var was: Dictionary = earlier.get(int(town.region), {})
		var current := {
			"region": int(town.region),
			"lat": float(town.lat),
			"lon": float(town.lon),
			"population": lerpf(float(was.get("population", 0)), float(town.population), t),
			"facilities": lerpf(float(was.get("facilities", 0)), float(town.facilities), t),
			"frontier": bool(town.get("frontier", was.get("frontier", false))),
			"coastal": bool(town.get("coastal", false)),
			"roads": town.get("roads", []),
			"fade": 1.0 if not was.is_empty() else t,
		}
		current.stage = int(LightRecord.town_level(stages, current))
		out.append(current)
	return out


## Historical uniform representation retained for older capture and comparison tools.
static func uniforms(towns: Array, world: Dictionary = {}) -> Dictionary:
	return TownForms.uniforms(towns, world, Rules.read("progression").get("lights", {}))
