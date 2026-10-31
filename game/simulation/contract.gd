extends RefCounted
## The staged contract, from a foothold to a capital city. Goals live in data/v17/contract.json.
## Missing a soft deadline feeds the company process, never instant failure.

const STREAK_WINDOW: int = 7
const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const Logistics = preload("res://simulation/logistics.gd")
const STAGE_COUNT: int = 5
const OLD_STAGE_COUNT: int = 3
const MINING_GOODS: Array[String] = ["ore", "copper", "crystal"]


static func ensure_state(state: Dictionary) -> void:
	if state.has("contract"):
		# A 1.7 colony that finished its three stages has earned the award for good.
		if state.status == "success" and int(state.contract.stage) == OLD_STAGE_COUNT + 1:
			state.contract.stage = STAGE_COUNT + 1
		return
	var finished: bool = state.get("status", "") == "success"
	state.contract = {
		"stage": STAGE_COUNT + 1 if finished else 1,
		"stage_started": int(state.get("day", 0)),
		"completed": {},
		"missed": [],
		"licences":
		["expedition", "third_settlement", "network", "self_reliance"] if finished else [],
		"stage_streak": 0,
		"food_window": [],
		"income_window": [],
		"processing_days": 0,
		"today_food": 0.0,
		"milestones": [],
	}


static func _difficulty_scale(sim: RefCounted) -> float:
	return float(
		sim.contract_rules.difficulty_scale.get(sim.state.get("difficulty", "normal"), 1.0)
	)


static func goal_target(sim: RefCounted, stage: int, key: String) -> float:
	var target: float = float(sim.contract_rules.stages[stage - 1].goals[key])
	if key in sim.contract_rules.scaled_goals:
		target = ceilf(target * _difficulty_scale(sim))
	return target


static func deadline(sim: RefCounted, stage: int) -> int:
	return int(sim.contract_rules.deadlines[sim.state.get("difficulty", "normal")][stage - 1])


## True while the current stage is past its soft deadline.
static func overdue(sim: RefCounted) -> bool:
	var contract: Dictionary = sim.state.contract
	if int(contract.stage) > STAGE_COUNT or sim.state.status == "success":
		return false
	return int(sim.state.day) > deadline(sim, int(contract.stage))


static func settlement_cap(sim: RefCounted) -> int:
	var rules: Dictionary = sim.contract_rules.settlement_cap
	var cap: int = int(rules.initial)
	if sim.state.status == "success":
		cap = int(rules.after_award)
	else:
		for licence: String in sim.state.contract.licences:
			cap = maxi(cap, int(rules.get(licence, 0)))
	return cap


static func population_total(sim: RefCounted) -> int:
	var total: int = 0
	for s: Dictionary in sim.state.settlements:
		total += int(s.population)
	return total


static func _window_sum(window: Array, column: int) -> float:
	var total: float = 0.0
	for row: Array in window:
		total += float(row[column])
	return total


static func local_food_share(sim: RefCounted) -> float:
	var window: Array = sim.state.contract.food_window
	var need: int = int(sim.contract_rules.windows.local_food)
	var consumed: float = _window_sum(window, 1)
	if window.size() < need or consumed <= 0.0:
		return 0.0
	return minf(1.0, _window_sum(window, 0) / consumed)


static func non_mining_share(sim: RefCounted) -> float:
	var window: Array = sim.state.contract.income_window
	var need: int = int(sim.contract_rules.windows.non_mining)
	var mining: float = _window_sum(window, 0)
	var other: float = _window_sum(window, 1)
	if window.size() < need or mining + other <= 0.0:
		return 0.0
	return other / (mining + other)


static func _connected(sim: RefCounted) -> int:
	return Logistics.largest_connected(sim)


static func _min_food_days(sim: RefCounted) -> float:
	var days: float = INF
	for s: Dictionary in sim.state.settlements:
		if int(s.arrival) > 0:
			continue
		days = minf(days, float(s.food_days))
	return 0.0 if days == INF else days


static func _employment(sim: RefCounted) -> float:
	var adults: int = 0
	var employed: int = 0
	for s: Dictionary in sim.state.settlements:
		adults += int(s.workers) + int(s.scientists)
		employed += int(s.employed)
	return float(employed) / maxi(1, adults)


static func _housed(sim: RefCounted) -> bool:
	for s: Dictionary in sim.state.settlements:
		if int(s.housing) < int(s.population):
			return false
	return not sim.state.settlements.is_empty()


static func _frontiers(sim: RefCounted) -> int:
	var count: int = 0
	for s: Dictionary in sim.state.settlements:
		if int(s.arrival) <= 0 and str(s.kind) == Keys.SITE_FRONTIER:
			count += 1
	return count


static func _research_staffed(sim: RefCounted) -> int:
	var count: int = 0
	for project: Dictionary in sim.state.research.get("projects", {}).values():
		if int(project.effective) > 0:
			count += 1
	return count


## A review only holds up the award while something other than the late contract is wrong.
## Otherwise a colony that met every goal late could never clear the review that its lateness caused.
static func _review_blocks_award(sim: RefCounted) -> bool:
	var company: Dictionary = sim.state.company
	if not company.stage in ["review", "intervention"]:
		return false
	if float(sim.state.debt) > 0.01:
		return true
	for s: Dictionary in sim.state.settlements:
		if int(s.starvation) > 0:
			return true
	for aid: Dictionary in company.aid:
		if aid.status == "breached":
			return true
	# A small town's troubles, or ones just over, do not hold up an award that is otherwise earned.
	var social: float = float(company.sources.get("social", {}).get("rate", 0.0))
	return social > float(sim.progression.company.tolerated_risk)


## Current value of one goal, in the units of its target.
static func goal_value(sim: RefCounted, key: String) -> float:
	match key:
		"settlements":
			return sim.state.settlements.size()
		"exports_total":
			return float(sim.state.exports_total)
		"food_days":
			return _min_food_days(sim)
		"stage_streak":
			return int(sim.state.contract.stage_streak)
		"research_staffed":
			return _research_staffed(sim)
		"connected":
			return _connected(sim)
		"local_food_share":
			return local_food_share(sim)
		"processing_days":
			return int(sim.state.contract.processing_days)
		"population":
			return population_total(sim)
		"technologies":
			return sim.state.research.completed.size()
		"employment":
			return _employment(sim)
		"housed":
			return 1.0 if _housed(sim) else 0.0
		"enterprise_profit_days":
			return int(sim.state.enterprise.get("profit_days", 0))
		"non_mining_share":
			return non_mining_share(sim)
		"no_review":
			return 0.0 if _review_blocks_award(sim) else 1.0
		"frontiers":
			return _frontiers(sim)
		"capital_population":
			if sim.state.settlements.is_empty():
				return 0.0
			return int(sim.state.settlements[0].population)
		"capital_hall":
			return 1.0 if Megaprojects.active(sim, "capital_hall") else 0.0
	return 0.0


## Every goal of a stage with its value, target and whether it is met.
static func stage_goals(sim: RefCounted, stage: int) -> Array:
	var rows: Array = []
	for key: String in sim.contract_rules.stages[stage - 1].goals:
		var target: float = goal_target(sim, stage, key)
		var value: float = goal_value(sim, key)
		rows.append({"key": key, "value": value, "target": target, "ok": value >= target})
	return rows


static func view(sim: RefCounted) -> Dictionary:
	var contract: Dictionary = sim.state.contract
	var stages: Array = []
	for stage: int in range(1, STAGE_COUNT + 1):
		var rules: Dictionary = sim.contract_rules.stages[stage - 1]
		(
			stages
			. append(
				{
					"stage": stage,
					"id": rules.id,
					"deadline": deadline(sim, stage),
					"reward_cash": float(rules.reward_cash),
					"licence": rules.licence,
					"completed_day": int(contract.completed.get(str(stage), -1)),
					"goals": stage_goals(sim, stage),
				}
			)
		)
	return {
		"current": int(contract.stage),
		"stages": stages,
		"overdue": overdue(sim),
		"cap": settlement_cap(sim),
		"milestones": contract.milestones,
	}


## Kept for summary() and the older callers: a flat picture of the colony against the contract.
static func progress(sim: RefCounted) -> Dictionary:
	return {
		"connected": _connected(sim) >= 2,
		"food": _min_food_days(sim) >= 7.0,
		"housing": _housed(sim),
		"employment": _employment(sim) >= 0.45,
		"enterprise":
		(
			not sim.state.enterprise.is_empty()
			and sim.state.enterprise.get("status", "") == Keys.E_OPEN
		),
		"solvent": sim.state.debt < 0.001,
		"streak": int(sim.state.streak),
		"stage": int(sim.state.contract.stage),
	}


static func _record_windows(sim: RefCounted) -> void:
	var contract: Dictionary = sim.state.contract
	var consumed: float = 0.0
	for s: Dictionary in sim.state.settlements:
		consumed += float(s.food_consumed)
	contract.food_window.append([float(contract.today_food), consumed])
	contract.today_food = 0.0
	while contract.food_window.size() > int(sim.contract_rules.windows.local_food):
		contract.food_window.pop_front()
	var mining: float = 0.0
	var other: float = 0.0
	var entries: Array = sim.state.ledger
	var index: int = entries.size() - 1
	while index >= 0 and int(entries[index].day) == int(sim.state.day):
		var entry: Dictionary = entries[index]
		index -= 1
		if not bool(entry.operating) or entry.to != "public":
			continue
		if entry.key == "export" and entry.detail in MINING_GOODS:
			mining += float(entry.amount)
		else:
			other += float(entry.amount)
	contract.income_window.append([mining, other])
	while contract.income_window.size() > int(sim.contract_rules.windows.non_mining):
		contract.income_window.pop_front()
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if (
				str(sim.config.buildings.get(b.kind, {}).get("role", "")) == "factory"
				and str(b.status) in [Keys.B_RUNNING, Keys.B_TARGET_FULL]
			):
				contract.processing_days = int(contract.processing_days) + 1
				return


static func _complete_stage(sim: RefCounted, stage: int) -> void:
	var contract: Dictionary = sim.state.contract
	var rules: Dictionary = sim.contract_rules.stages[stage - 1]
	contract.completed[str(stage)] = int(sim.state.day)
	if float(rules.reward_cash) > 0.0:
		sim._transfer(
			"external", "public", float(rules.reward_cash), "contract.reward", false, rules.id
		)
	if str(rules.licence) != "":
		contract.licences.append(rules.licence)
	contract.stage = stage + 1
	contract.stage_started = int(sim.state.day)
	contract.stage_streak = 0
	if stage == STAGE_COUNT:
		sim.state.status = "success"
		sim.state.success_day = sim.state.day
		sim._log("合同履约完成：总督资格生效。明日起按公共账户正经营结余的 15% 缴纳公司分成；可继续经营。")
	else:
		sim._log("合同阶段 %d 完成，公司拨付发展资金 %.0f。" % [stage, float(rules.reward_cash)])


static func _check_milestones(sim: RefCounted) -> void:
	var contract: Dictionary = sim.state.contract
	for milestone: Dictionary in sim.contract_rules.milestones:
		if milestone.id in contract.milestones:
			continue
		var reached: bool = false
		match str(milestone.goal):
			"population":
				reached = population_total(sim) >= int(milestone.target)
			"settlements":
				reached = sim.state.settlements.size() >= int(milestone.target)
			"megaprojects":
				reached = Megaprojects.count(sim) >= int(milestone.target)
			"technologies":
				reached = sim.state.research.completed.size() >= int(milestone.target)
		if reached:
			contract.milestones.append(milestone.id)
			sim.state.career.balance = float(sim.state.career.balance) + float(milestone.reward)
			var paid: float = float(sim.state.career.get("milestones_paid", 0.0))
			sim.state.career.milestones_paid = paid + float(milestone.reward)
			sim._log("行星里程碑达成，生涯资金增加 %.0f。" % float(milestone.reward))


## One lumpy day (a shipment, a one-off bill) does not undo weeks of sound running.
static func _solvent_week(sim: RefCounted) -> bool:
	if float(sim.state.debt) >= 0.001:
		return false
	var history: Array = sim.state.operating_history
	var total: float = float(sim.state.operating_net)
	for index: int in range(maxi(0, history.size() - STREAK_WINDOW + 1), history.size()):
		total += float(history[index].net)
	return total >= -0.000001


static func daily(sim: RefCounted) -> void:
	var contract: Dictionary = sim.state.contract
	var solvent_day: bool = sim.state.operating_net >= -0.000001 and sim.state.debt < 0.001
	sim.state.streak = int(sim.state.streak) + 1 if solvent_day else 0
	contract.stage_streak = int(contract.stage_streak) + 1 if _solvent_week(sim) else 0
	sim.state.grace_days = int(sim.state.grace_days) + 1 if sim.state.debt > 0.001 else 0
	_record_windows(sim)
	if sim.state.status == "success":
		_check_milestones(sim)
		return
	var stage: int = int(contract.stage)
	if overdue(sim) and not contract.missed.has(stage):
		contract.missed.append(stage)
		sim._log("合同阶段 %d 已超过期限；公司将此计入履约风险。" % stage)
	for goal: Dictionary in stage_goals(sim, stage):
		if not goal.ok:
			return
	_complete_stage(sim, stage)
