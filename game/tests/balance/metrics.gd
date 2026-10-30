extends RefCounted
## Per-run metrics, read from Sim state after every simulated day.

const EventsV2 = preload("res://simulation/events_v2.gd")
const POPULATION_CHECKPOINTS: Array[int] = [90, 180, 360, 720]
const RESEARCH_WINDOW_FIRST_DAY: int = 60
const RESEARCH_WINDOW_LAST_DAY: int = 180
const EXPORT_MIX_FROM_DAY: int = 180
const INCOME_SAMPLE_DAYS: int = 30

var record: Dictionary = {}
var _pending_seen: Dictionary = {}
var _income_window: Array[float] = []
var _research_spend: float = 0.0
var _window_expense: float = 0.0
var _operating_surplus: float = 0.0
var _reinvested: float = 0.0
var _last_entry: Dictionary = {}


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
				"notices": 0,
				"company_stages": [],
				"company_stage_days": {},
				"audit_errors": [],
				"audit_error_count": 0,
				"immigrants_180": -1,
				"operating_income_180": -1.0,
				"operating_income_720": -1.0,
				"reinvested_share_720": -1.0,
				"distinct_events": 0,
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
	if day == 180:
		record.immigrants_180 = int(state.immigrants_total)
	if state.status == "success" and int(record.award_day) < 0:
		record.award_day = day
		record.techs_by_award = state.research.completed.size()
		record.scientist_share_at_award = _scientist_share(state)
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
	if _window_expense > 0.0:
		record.research_share = _research_spend / _window_expense
	if _operating_surplus > 0.0:
		record.reinvested_share_720 = _reinvested / _operating_surplus
	return record


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
			if key.begins_with("research."):
				_research_spend += amount
	if not operating and entry.from == "public" and entry.to == "external":
		if key != "arrears" and not key.begins_with("aid."):
			_reinvested += amount


func _scan_events(sim: RefCounted) -> void:
	for node: Dictionary in EventsV2.view(sim).pending:
		var key: String = str(node.instance_id) + "/" + str(node.node)
		if _pending_seen.has(key):
			continue
		_pending_seen[key] = true
		if node.pause_required:
			record.pausing_decisions += 1
		else:
			record.notices += 1


func _scan_company(state: Dictionary) -> void:
	var stage: String = str(state.get("company", {}).get("stage", "normal"))
	if not record.company_stages.has(stage):
		record.company_stages.append(stage)
		record.company_stage_days[stage] = int(state.day)


func _scan_income(state: Dictionary, day: int) -> void:
	_income_window.append(float(state.income_daily))
	if _income_window.size() > INCOME_SAMPLE_DAYS:
		_income_window.pop_front()
	if day == 180:
		record.operating_income_180 = _mean(_income_window)
	if day == 720:
		record.operating_income_720 = _mean(_income_window)


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


func _distinct_events(state: Dictionary) -> int:
	return state.get("events_v2", {}).get("seen", []).size()
