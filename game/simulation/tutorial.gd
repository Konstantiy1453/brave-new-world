extends RefCounted
## Tutorial and tip conditions. Each is a named check written here: data picks a name and its
## arguments, nothing is evaluated. `context` holds what only the interface knows.

const Rules = preload("res://simulation/rules.gd")
const Keys = preload("res://simulation/keys.gd")
## The scripted water fault leaves the pumps this share of what the town uses, at most.
const SHORTAGE_DEPTH: float = 0.6


static func data() -> Dictionary:
	return Rules.read("tutorial")


## The same tutorial bay has a different road network in the new geography.
static func partner_site(world: Dictionary) -> int:
	var rules := data()
	return int(rules.partner_site if world.get("version", "") == "CC-GEO-2.3" else rules.legacy_partner_site)


static func new_context() -> Dictionary:
	return {
		"camera_moved": false,
		"sites_viewed": {},
		"pages_opened": {},
		"shortage_day": -1,
		"home": 0,
		# The water lesson: pumps at home when the fault began, and what the fault cost.
		"water_built": -1,
		"water_working": -1,
		"short_days": 0,
		"lowest_water": 1.0,
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
		"first_choice":
			# The bay's first decision: a mine or the small harbour ordered at the home town.
			return _buildings(state, "mine_") >= 1 or _buildings(state, "harbor") >= 1
		"first_shipment":
			# A recorded first consignment (consignments.gd): the first ore truck or ship.
			for kind: String in ["ore", "ship"]:
				var entry: Dictionary = state.get("firsts", {}).get(kind, {})
				if not entry.is_empty() and not bool(entry.get("legacy", false)):
					return true
			return false
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


## Projects whose team is at work, as the contract counts them: a team assigned to a laboratory
## that is not running does not count (`note` says why the lesson is waiting).
static func _staffed_projects(state: Dictionary) -> int:
	var total: int = 0
	for project: Dictionary in state.research.get("projects", {}).values():
		if int(project.staff) >= 3 and int(project.effective) > 0:
			total += 1
	return total


## A line under the lesson while its condition is not met for a reason the player may not see:
## a research team that is assigned but blocked. Empty when there is nothing to add.
static func note(sim: RefCounted, condition: Dictionary, context: Dictionary) -> String:
	match str(condition.get("name", "")):
		"project_staffed":
			for project: Dictionary in sim.state.research.get("projects", {}).values():
				if int(project.staff) >= 3 and int(project.effective) <= 0:
					return "团队已经派出，但研究还没有进展：" + str(project.get("reason", ""))
		"shortage_cleared":
			return _water_note(sim, context)
	return ""


## True once the shortage has shown itself and is gone again because the player added supply.
## Waiting for the fault to pass is not counted as fixing it (`waited`).
static func _shortage_cleared(sim: RefCounted, context: Dictionary, key: String) -> bool:
	return _shortage_over(sim, context, key) and _ended_by_pump(sim, context)


## Whether a new pump ended the shortage: one was at work on the day it ended, while the fault was
## still on (`count_shortage` notes it then). A pump still being built when the filter recovered by
## itself, or a shortage that lasted until the fault passed, was ended by the filter.
static func _ended_by_pump(sim: RefCounted, context: Dictionary) -> bool:
	if context.has("ended_by_pump"):
		return bool(context.ended_by_pump)
	return _pump_working(sim, context) and int(sim.state.day) < _fault_end(context)


## The first day without the fault (the effect runs until then, as `start_shortage` sets it).
static func _fault_end(context: Dictionary) -> int:
	return int(context.shortage_day) + 1 + int(data().shortage.days)


static func _shortage_over(sim: RefCounted, context: Dictionary, key: String) -> bool:
	if int(context.shortage_day) < 0 or int(sim.state.day) <= int(context.shortage_day) + 1:
		return false
	return not _any_shortage(sim.state, key)


## The water lesson ended because the fault passed by itself, with no pump added, after the town
## had gone short for at least a day.
static func waited(sim: RefCounted, context: Dictionary) -> bool:
	return (
		int(context.get("short_days", 0)) > 0
		and _shortage_over(sim, context, "water")
		and not _ended_by_pump(sim, context)
	)


## Water buildings at the lesson's town, finished or not (or only finished ones).
static func water_count(sim: RefCounted, region: int, finished_only: bool = false) -> int:
	var count: int = 0
	for b: Dictionary in sim.settlement(region).get("buildings", []):
		if str(sim.config.buildings.get(b.kind, {}).get("role", "")) != "water":
			continue
		if finished_only and int(b.remaining) > 0:
			continue
		count += 1
	return count


## A new pump ordered since the fault began, built or not.
static func _invested(sim: RefCounted, context: Dictionary) -> bool:
	var before: int = int(context.get("water_built", -1))
	return before >= 0 and water_count(sim, int(context.home)) > before


## A new pump working since the fault began.
static func _pump_working(sim: RefCounted, context: Dictionary) -> bool:
	var before: int = int(context.get("water_working", -1))
	if before < 0:
		# A lesson begun before the count of working pumps was kept: the pumps then were built.
		before = int(context.get("water_built", -1))
	return before >= 0 and water_count(sim, int(context.home), true) > before


## Days until the soonest new pump still being built is finished; -1 when none is.
static func _pump_days_left(sim: RefCounted, context: Dictionary) -> int:
	var left: int = -1
	for b: Dictionary in sim.settlement(int(context.home)).get("buildings", []):
		if str(sim.config.buildings.get(b.kind, {}).get("role", "")) != "water":
			continue
		if int(b.remaining) > 0 and (left < 0 or int(b.remaining) < left):
			left = int(b.remaining)
	return left


## Once a day during the water lesson: how long the town has been short and how short.
static func count_shortage(sim: RefCounted, context: Dictionary) -> void:
	if int(context.get("shortage_day", -1)) < 0:
		return
	if _shortage_over(sim, context, "water"):
		if not context.has("ended_day"):
			context.ended_day = int(sim.state.day)
			context.ended_by_pump = (
				_pump_working(sim, context) and int(sim.state.day) < _fault_end(context)
			)
		return
	var s: Dictionary = sim.settlement(int(context.home))
	if s.is_empty() or not _settlement_short(s, "water"):
		return
	context.short_days = int(context.get("short_days", 0)) + 1
	var ratio: float = float(s.water_supply) / maxf(0.001, float(s.water_demand))
	context.lowest_water = minf(float(context.get("lowest_water", 1.0)), clampf(ratio, 0.0, 1.0))


static func _settlement_short(s: Dictionary, key: String) -> bool:
	for entry: Dictionary in s.get("shortages", []):
		if str(entry.key) == key:
			return true
	return false


## What waiting costs against what a pump costs, in the actual numbers of this game.
static func _water_note(sim: RefCounted, context: Dictionary) -> String:
	if int(context.get("shortage_day", -1)) < 0:
		return ""
	var home: int = int(context.home)
	var pump: Dictionary = sim.build_preview(home, "water")
	var price: String = "再建一座净水泵站要 ¥%.0f、%d 天" % [float(pump.cost), int(pump.days)]
	var lowest: int = roundi(100.0 * float(context.get("lowest_water", 1.0)))
	var building: int = _pump_days_left(sim, context)
	if waited(sim, context):
		if _invested(sim, context):
			return (
				"滤芯自己恢复了：缺水 %d 天，最低只剩 %d%% 的产量。你订的泵站%s，下次出故障时它能顶上。可以点「下一步」继续。"
				% [
					int(context.short_days),
					lowest,
					"这次没赶上，还要 %d 天建成" % building if building > 0 else "建成了，但故障太重，缺水是滤芯恢复后才结束的",
				]
			)
		return (
			"滤芯自己恢复了：缺水 %d 天，用水的设施最低只剩 %d%% 的产量。等待不花钱，但这些天少产了东西；%s，下次出故障时它能顶上。可以点「下一步」继续。"
			% [int(context.short_days), lowest, price]
		)
	if _pump_working(sim, context):
		return "新泵站已经投入运转，供水正在补回来。"
	if _invested(sim, context):
		var ends_on: int = int(context.shortage_day) + 1 + int(data().shortage.days)
		return (
			"新泵站已经下令，但还没建成：还要 %d 天（工程队排队中）。建成之前仍然缺水；滤芯约第 %d 天自己恢复，哪个先到就靠哪个。"
			% [maxi(building, 0), ends_on]
		)
	var ends: int = int(context.shortage_day) + 1 + int(data().shortage.days)
	return (
		"缺水第 %d 天：用水的设施只能按供水比例开工（最低约 %d%%）。等滤芯自己恢复要到第 %d 天；%s。"
		% [int(context.short_days), lowest, ends, price]
	)


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
	# Deep enough to show whatever the crew has built so far: the pumps fall below the town's use.
	var supply: float = float(s.get("water_supply", 0.0))
	var factor: float = float(rules.factor)
	if supply > 0.0:
		factor = clampf(
			minf(factor, SHORTAGE_DEPTH * float(s.get("water_demand", 0.0)) / supply), 0.02, 1.0
		)
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
				"factor": factor,
				"start": int(sim.state.day) + 1,
				"until": int(sim.state.day) + 1 + int(rules.days),
				"duration_days": int(rules.days),
				"maintenance": 0.0,
			}
		)
	)
	sim._log("净水泵站的滤芯堵塞，供水大幅下降。")
	return ""
