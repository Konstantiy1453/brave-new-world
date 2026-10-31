extends RefCounted
## Per-run metrics, read from Sim state after every simulated day.

const EventsV2 = preload("res://simulation/events_v2.gd")
const POPULATION_CHECKPOINTS: Array[int] = [360, 720, 1080, 1440, 2160, 2880]
const RESEARCH_WINDOW_FIRST_DAY: int = 360
const RESEARCH_WINDOW_LAST_DAY: int = 1440
const EXPORT_MIX_FROM_DAY: int = 720
const INCOME_SAMPLE_DAYS: int = 30
const EARLY_INCOME_DAY: int = 720
const LATE_INCOME_DAY: int = 2160
const POLLUTION_CHECK_DAYS: Array[int] = [1080, 2880]

var record: Dictionary = {}
var _pending_seen: Dictionary = {}
var _income_window: Array[float] = []
var _research_spend: float = 0.0
var _window_expense: float = 0.0
var _operating_surplus: float = 0.0
var _reinvested: float = 0.0
var _last_entry: Dictionary = {}
var _opened_at: Dictionary = {}


func begin(case_info: Dictionary, sim: RefCounted) -> void:
	record = case_info.duplicate()
	(
		record
		. merge(
			{
				"award_day": -1,
				"stage_days": {},
				"failure_day": -1,
				"failure_reason": "",
				"min_cash": float(sim.state.cash),
				"population": {},
				"techs_by_award": -1,
				"scientist_share_at_award": -1.0,
				"research_share": -1.0,
				"export_revenue": {},
				"pausing_decisions": 0,
				"cooldown_breaks": 0,
				"notices": 0,
				"company_stages": [],
				"company_stage_days": {},
				"audit_errors": [],
				"audit_error_count": 0,
				"operating_income_early": -1.0,
				"operating_income_late": -1.0,
				"reinvested_share": -1.0,
				"distinct_events": 0,
				"events_off": 0,
				"largest_distrust_rise": 0.0,
				"pollution_penalty": {},
				"categories_at_award": 0,
				"first_road_days": -1,
				"final_day": 0,
				"final_status": "",
			}
		)
	)


func sample(sim: RefCounted) -> void:
	var state: Dictionary = sim.state
	var day: int = int(state.day)
	record.min_cash = minf(float(record.min_cash), float(state.cash))
	_scan_ledger(state, day)
	_scan_events(sim)
	_scan_company(state)
	_scan_income(state, day)
	var issues: Array = sim.audit()
	if not issues.is_empty():
		record.audit_error_count += issues.size()
		if record.audit_errors.size() < 5:
			record.audit_errors.append({"day": day, "issues": issues})
	record.stage_days = state.contract.completed.duplicate()
	if POPULATION_CHECKPOINTS.has(day):
		record.population[str(day)] = _population(state)
	if POLLUTION_CHECK_DAYS.has(day):
		record.pollution_penalty[str(day)] = sim.Pollution.penalty(sim)
	record.largest_distrust_rise = maxf(
		float(record.largest_distrust_rise), float(state.company.delta)
	)
	if int(record.first_road_days) < 0:
		for road: Dictionary in state.roads:
			if str(road.get("variant", "")) != "sea":
				record.first_road_days = int(road.get("build_days", 0))
				break
	if state.status == "success" and int(record.award_day) < 0:
		record.award_day = day
		record.techs_by_award = state.research.completed.size()
		record.scientist_share_at_award = _scientist_share(state)
		record.categories_at_award = _categories(sim)
	if state.status == "failed" and int(record.failure_day) < 0:
		record.failure_day = day
		record.failure_reason = str(state.failure_reason)


func finish(sim: RefCounted) -> Dictionary:
	var state: Dictionary = sim.state
	record.final_day = int(state.day)
	record.final_status = str(state.status)
	record.final_population = _population(state)
	record.final_cash = float(state.cash)
	record.distinct_events = _distinct_events(state)
	record.events_off = state.get("events_v2", {}).get("off", []).size()
	record.opened_events = state.get("events_v2", {}).get("seen", []).duplicate()
	if _window_expense > 0.0:
		record.research_share = _research_spend / _window_expense
	if _operating_surplus > 0.0:
		record.reinvested_share = _reinvested / _operating_surplus
	return record


func _categories(sim: RefCounted) -> int:
	var seen: Dictionary = {}
	for tech: String in sim.state.research.completed:
		seen[str(sim.config.techs[tech].category)] = true
	return seen.size()


func _population(state: Dictionary) -> int:
	var total: int = 0
	for place: Dictionary in state.settlements:
		total += int(place.population)
	return total


func _scientist_share(state: Dictionary) -> float:
	var adults: int = 0
	var scientists: int = 0
	for place: Dictionary in state.settlements:
		adults += int(place.workers) + int(place.scientists)
		scientists += int(place.scientists)
	return float(scientists) / maxi(1, adults)


## Counts every entry once, including those made by actions between two ticks.
func _scan_ledger(state: Dictionary, day: int) -> void:
	var entries: Array = state.ledger
	var index: int = entries.size() - 1
	while index >= 0:
		var entry: Dictionary = entries[index]
		if is_same(entry, _last_entry):
			break
		_count_entry(entry, day)
		index -= 1
	if not entries.is_empty():
		_last_entry = entries.back()


func _count_entry(entry: Dictionary, day: int) -> void:
	var key: String = str(entry.key)
	var amount: float = float(entry.amount)
	var operating: bool = bool(entry.operating)
	if key == "export" and day > EXPORT_MIX_FROM_DAY:
		var good: String = str(entry.detail)
		record.export_revenue[good] = float(record.export_revenue.get(good, 0.0)) + amount
	if operating and entry.to == "public":
		_operating_surplus += amount
	if operating and entry.from == "public":
		_operating_surplus -= amount
		if day >= RESEARCH_WINDOW_FIRST_DAY and day <= RESEARCH_WINDOW_LAST_DAY:
			_window_expense += amount
			if key.begins_with("research.") or _is_lab_cost(key, entry):
				_research_spend += amount
	if not operating and entry.from == "public" and entry.to == "external":
		if key != "arrears" and not key.begins_with("aid."):
			_reinvested += amount


func _is_lab_cost(key: String, entry: Dictionary) -> bool:
	return key in ["wages.public", "upkeep.facility"] and entry.detail == "lab"


func _scan_events(sim: RefCounted) -> void:
	_scan_cooldowns(sim)
	for node: Dictionary in EventsV2.view(sim).pending:
		var key: String = str(node.instance_id) + "/" + str(node.node)
		if _pending_seen.has(key):
			continue
		_pending_seen[key] = true
		if node.pause_required:
			record.pausing_decisions += 1
		else:
			record.notices += 1


## Compares each definition's last opening with the one before it.
func _scan_cooldowns(sim: RefCounted) -> void:
	var rules: Dictionary = EventsV2.definitions()
	var opened: Dictionary = sim.state.get("events_v2", {}).get("last_opened", {})
	for id: String in opened:
		var day: int = int(opened[id])
		if int(_opened_at.get(id, day)) == day:
			_opened_at[id] = day
			continue
		var cooldown: int = int(
			rules.definitions[id].get("cooldown_days", rules.sampling.default_cooldown_days)
		)
		if day - int(_opened_at[id]) < cooldown:
			record.cooldown_breaks += 1
		_opened_at[id] = day


func _scan_company(state: Dictionary) -> void:
	var stage: String = str(state.get("company", {}).get("stage", "normal"))
	if not record.company_stages.has(stage):
		record.company_stages.append(stage)
		record.company_stage_days[stage] = int(state.day)


func _scan_income(state: Dictionary, day: int) -> void:
	_income_window.append(float(state.income_daily))
	if _income_window.size() > INCOME_SAMPLE_DAYS:
		_income_window.pop_front()
	if day == EARLY_INCOME_DAY:
		record.operating_income_early = _mean(_income_window)
	if day == LATE_INCOME_DAY:
		record.operating_income_late = _mean(_income_window)


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


func _distinct_events(state: Dictionary) -> int:
	return state.get("events_v2", {}).get("seen", []).size()
