extends RefCounted
## The colony's lights over time (1.11 G). Every quarter (`progression.json` `lights`
## `snapshot_days`) a snapshot of each founded settlement as the planet-scale lights draw it: where
## it stands, its light stage (着陆点, 首批住区, 小镇, 区域中心, 星球首府: the highest whose people and
## facilities it both has), its people and facilities, whether it is on the coast, and the towns
## its finished roads reach. The night time-lapse at an ending plays them back from the landing.
## State only: the views draw it. A save from before 1.11 starts its record on the day it loads.

const Keys = preload("res://simulation/keys.gd")


static func rules(sim: RefCounted) -> Dictionary:
	return sim.progression.get("lights", {})


static func ensure_state(state: Dictionary) -> void:
	if not state.has("lights"):
		state.lights = {"snapshots": [], "next_day": 0}


## A snapshot on the first day with a settlement, then every `snapshot_days`.
static func daily(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var record: Dictionary = sim.state.lights
	if sim.state.settlements.is_empty() or int(sim.state.day) < int(record.next_day):
		return
	record.snapshots.append(snapshot(sim))
	while record.snapshots.size() > int(rules(sim).get("snapshots_kept", 64)):
		record.snapshots.pop_front()
	record.next_day = int(sim.state.day) + maxi(1, int(rules(sim).get("snapshot_days", 90)))


static func snapshot(sim: RefCounted) -> Dictionary:
	var towns: Array = []
	for s: Dictionary in sim.state.settlements:
		if int(s.get("arrival", 0)) > 0:
			continue
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		(
			towns
			. append(
				{
					"region": int(s.region),
					"lat": float(s.get("lat", reg.lat)),
					"lon": float(s.get("lon", reg.lon)),
					"stage": stage_of(sim, s),
					"population": int(s.population),
					"facilities": facilities(sim, s),
					"coastal": bool(reg.get("coast", false)),
					"frontier": str(s.get("kind", "")) == Keys.SITE_FRONTIER,
					"roads": roads_of(sim, int(s.region)),
				}
			)
		)
	return {"day": int(sim.state.day), "towns": towns}


## Finished buildings other than homes.
static func facilities(sim: RefCounted, s: Dictionary) -> int:
	return facility_count(sim.config.buildings, s)


## The same count from the building table alone, for the views (town_forms.gd).
static func facility_count(buildings: Dictionary, s: Dictionary) -> int:
	var count: int = 0
	for b: Dictionary in s.get("buildings", []):
		var spec: Dictionary = buildings.get(str(b.kind), {})
		if int(b.get("remaining", 0)) <= 0 and str(spec.get("role", "")) != "housing":
			count += 1
	return count


## The index of the highest light stage whose people and facilities the town both has.
static func stage_of(sim: RefCounted, s: Dictionary) -> int:
	return stage_index(rules(sim).get("stages", []), float(s.population), facilities(sim, s))


static func stage_index(stages: Array, people: float, count: float) -> int:
	var stage: int = 0
	for index: int in range(stages.size()):
		var rule: Dictionary = stages[index]
		if people >= float(rule.population) and count >= float(rule.facilities):
			stage = index
	return stage


## The stage and how far the town has come towards the next one, as one number (2.5: half way
## from 小镇 to 区域中心), so a town's lights grow with it instead of jumping at each threshold.
static func stage_level(stages: Array, people: float, count: float) -> float:
	var stage: int = stage_index(stages, people, count)
	if stage + 1 >= stages.size():
		return float(stage)
	var here: Dictionary = stages[stage]
	var next: Dictionary = stages[stage + 1]
	var by_people: float = (
		(people - float(here.population))
		/ maxf(1.0, float(next.population) - float(here.population))
	)
	var by_count: float = (
		(count - float(here.facilities))
		/ maxf(1.0, float(next.facilities) - float(here.facilities))
	)
	return float(stage) + clampf(minf(by_people, by_count), 0.0, 0.999)


## The towns a finished road or sea link reaches from this one.
static func roads_of(sim: RefCounted, region: int) -> Array:
	return roads_reaching(sim.state, region)


## The same from the state alone, for the views (town_forms.gd).
static func roads_reaching(state: Dictionary, region: int) -> Array:
	var out: Array = []
	for road: Dictionary in state.get("roads", []):
		if int(road.get("ready_day", 0)) > int(state.get("day", 0)):
			continue
		if int(road.a) == region and not int(road.b) in out:
			out.append(int(road.b))
		elif int(road.b) == region and not int(road.a) in out:
			out.append(int(road.a))
	return out


static func audit(sim: RefCounted) -> Array:
	var errors: Array = []
	var record: Dictionary = sim.state.get("lights", {})
	if record.is_empty():
		return errors
	var last: int = -1
	var stages: int = rules(sim).get("stages", []).size()
	for snap: Dictionary in record.snapshots:
		if int(snap.day) <= last or int(snap.day) > int(sim.state.day):
			errors.append("light snapshots out of order")
		last = int(snap.day)
		for town: Dictionary in snap.towns:
			if int(town.stage) < 0 or int(town.stage) >= maxi(1, stages):
				errors.append("light stage out of range")
	if last >= 0 and int(record.next_day) <= last:
		errors.append("next light snapshot before the last")
	return errors


static func validate(_sim: RefCounted, candidate: Dictionary) -> String:
	var record: Variant = candidate.get("lights")
	if not record is Dictionary:
		return "存档缺少灯光记录"
	if not record.get("snapshots") is Array or not record.has("next_day"):
		return "灯光记录无效"
	return ""
