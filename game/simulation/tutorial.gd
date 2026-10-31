extends RefCounted
## Tutorial and tip conditions. Each is a named check written here: data picks a name and its
## arguments, nothing is evaluated. `context` holds what only the interface knows.

const Rules = preload("res://simulation/rules.gd")
const Keys = preload("res://simulation/keys.gd")


static func data() -> Dictionary:
	return Rules.read("tutorial")


static func new_context() -> Dictionary:
	return {
		"camera_moved": false,
		"sites_viewed": {},
		"pages_opened": {},
		"shortage_day": -1,
		"home": 0,
	}


static func check(sim: RefCounted, condition: Dictionary, context: Dictionary) -> bool:
	var state: Dictionary = sim.state
	var count: float = float(condition.get("count", 1))
	match str(condition.name):
		"camera_moved":
			return bool(context.camera_moved)
		"sites_viewed":
			return context.sites_viewed.size() >= count
		"page_opened":
			return context.pages_opened.has(str(condition.page))
		"settlements":
			return state.settlements.size() >= count
		"buildings_queued":
			return _buildings(state, str(condition.prefix)) >= count
		"building_active":
			return _running(state, str(condition.prefix))
		"day":
			return int(state.day) >= count
		"exports_total":
			return float(state.exports_total) > 0.0
		"shortage_cleared":
			return _shortage_cleared(sim, context, str(condition.shortage))
		"project_staffed":
			return _staffed_projects(state) >= count
		"contract_stage":
			return int(state.contract.stage) >= count
		"route_count":
			return state.roads.size() >= count
		"event_seen":
			return not state.get("events_v2", {}).get("seen", []).is_empty()
		"company_warning":
			return str(state.company.stage) != "normal"
		"deposit_depleted":
			return _any_shortage(state, Keys.SH_DEPLETED)
		"road_closed":
			return _road_closed(state)
	push_error("TUTORIAL: unknown condition " + str(condition.name))
	return false


static func _buildings(state: Dictionary, prefix: String) -> int:
	var total: int = 0
	for s: Dictionary in state.settlements:
		for b: Dictionary in s.buildings:
			if str(b.kind).begins_with(prefix):
				total += 1
	return total


static func _running(state: Dictionary, prefix: String) -> bool:
	for s: Dictionary in state.settlements:
		for b: Dictionary in s.buildings:
			if str(b.kind).begins_with(prefix) and bool(b.active):
				return true
	return false


static func _staffed_projects(state: Dictionary) -> int:
	var total: int = 0
	for project: Dictionary in state.research.get("projects", {}).values():
		if int(project.staff) >= 3:
			total += 1
	return total


## True once the shortage has shown itself and is gone again.
static func _shortage_cleared(sim: RefCounted, context: Dictionary, key: String) -> bool:
	if int(context.shortage_day) < 0 or int(sim.state.day) <= int(context.shortage_day) + 1:
		return false
	return not _any_shortage(sim.state, key)


static func _any_shortage(state: Dictionary, key: String) -> bool:
	for s: Dictionary in state.settlements:
		for entry: Dictionary in s.shortages:
			if str(entry.key) == key:
				return true
	return false


static func _road_closed(state: Dictionary) -> bool:
	for road: Dictionary in state.roads:
		if int(road.get("blocked_until", 0)) >= int(state.day):
			return true
	return false


## The tutorial game opens quietly: no event competes with the first lessons.
static func begin(sim: RefCounted) -> String:
	var first: int = int(data().first_event_day)
	sim.state.events_v2.next_draw = maxi(int(sim.state.events_v2.next_draw), first)
	return ""


## The tutorial's first problem: the pumps at this settlement lose most of their output for a while.
## An ordinary action, so a save or replay of the session behaves the same.
static func start_shortage(sim: RefCounted, site: int) -> String:
	var s: Dictionary = sim.settlement(site)
	if s.is_empty():
		return "请选择已建立的据点"
	var rules: Dictionary = data().shortage
	(
		sim
		. state
		. events_v2
		. effects
		. append(
			{
				"source": "tutorial",
				"region": site,
				"kind": str(rules.kind),
				"factor": float(rules.factor),
				"start": int(sim.state.day) + 1,
				"until": int(sim.state.day) + 1 + int(rules.days),
				"duration_days": int(rules.days),
				"maintenance": 0.0,
			}
		)
	)
	sim._log("净水泵站的滤芯堵塞，供水大幅下降。")
	return ""
