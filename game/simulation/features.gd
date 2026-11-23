extends RefCounted
## Frozen features (1.11, the contractor plan): progression.json `features`, every flag false in
## 1.11.0. A frozen feature keeps its code, data and tests; its content (`features.content`) is
## hidden from the interface, never drawn by events, never chosen by bots, and nothing new of its
## kind can be started. A save that already holds some keeps running it. Read from the shared rule
## cache, so the simulation, the generators, the interface and the bots see one answer.

const Rules = preload("res://simulation/rules.gd")
const METALS: String = "metals"
const SEABED: String = "seabed"
const SHUTTLES: String = "shuttles"
const RADIUS_SLIDER: String = "radius_slider"
const RESEARCH_COMMISSIONS: String = "research_commissions"


## Whether a feature is open. A flag missing from the data counts as open (older rule files).
static func on(key: String) -> bool:
	return bool(Rules.read("progression").get("features", {}).get(key, true))


static func _frozen_in(list: String, item: String) -> bool:
	var content: Dictionary = Rules.read("progression").get("features", {}).get("content", {})
	for key: String in content:
		if item in content[key].get(list, []) and not on(key):
			return true
	return false


static func building_frozen(kind: String) -> bool:
	return _frozen_in("buildings", kind)


static func tech_frozen(tech: String) -> bool:
	return _frozen_in("techs", tech)


static func resource_frozen(good: String) -> bool:
	return _frozen_in("resources", good)


static func road_frozen(variant: String) -> bool:
	return _frozen_in("roads", variant)
