extends RefCounted
## Turns run records into per-group medians and the §5.2 target table.

const STATUS_PASS: String = "PASS"
const STATUS_MISS: String = "MISS"
const STATUS_NONE: String = "NOT_MEASURED"
const AWARD_BANDS: Dictionary = {
	"easy": [90, 150],
	"normal": [120, 180],
	"hard": [160, 230],
}
const FLOOR_DAY: int = 90
const OPENING_SPREAD: float = 0.15
const PASSIVE_REVIEW_DAY: Array[int] = [40, 80]
const PASSIVE_FAILURE_DAY: Array[int] = [120, 180]
const POPULATION_AT_360: int = 300
const POPULATION_AT_720: int = 600
const STAGE3_POPULATION: Dictionary = {"easy": 144, "normal": 180, "hard": 216}
const MIN_TECHS_BALANCED: int = 3
const MIN_TECHS_RESEARCH_FIRST: int = 6
const SCIENTIST_SHARE: Array[float] = [0.10, 0.20]
const RESEARCH_SHARE: Array[float] = [0.15, 0.30]
const REINVEST_SHARE: float = 0.60
const INCOME_GROWTH: float = 2.5
const EXPORT_CONCENTRATION: float = 0.60
const PAUSE_INTERVAL_DAYS: float = 20.0
const DISTINCT_EVENTS: int = 15


static func median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	var middle: int = sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return float(sorted_values[middle])
	return (float(sorted_values[middle - 1]) + float(sorted_values[middle])) / 2.0


static func select(
	runs: Array, bot: String, difficulty: String = "", opening: String = ""
) -> Array:
	var chosen: Array = []
	for run: Dictionary in runs:
		if run.bot != bot:
			continue
		if difficulty != "" and run.difficulty != difficulty:
			continue
		if opening != "" and run.opening != opening:
			continue
		chosen.append(run)
	return chosen


static func field(runs: Array, key: String, valid_from: float = 0.0) -> Array:
	var values: Array = []
	for run: Dictionary in runs:
		var value: float = float(run.get(key, -1))
		if value >= valid_from:
			values.append(value)
	return values


static func population_at(runs: Array, day: int) -> Array:
	var values: Array = []
	for run: Dictionary in runs:
		if run.population.has(str(day)):
			values.append(float(run.population[str(day)]))
	return values


static func group_table(runs: Array) -> Array:
	var keys: Dictionary = {}
	for run: Dictionary in runs:
		keys["%s|%s|%s" % [run.bot, run.difficulty, run.opening]] = true
	var names: Array = keys.keys()
	names.sort()
	var rows: Array = []
	for key: String in names:
		var parts: PackedStringArray = key.split("|")
		var group: Array = select(runs, parts[0], parts[1], parts[2])
		var awards: Array = field(group, "award_day")
		var failures: Array = field(group, "failure_day")
		rows.append(
			{
				"bot": parts[0],
				"difficulty": parts[1],
				"opening": parts[2],
				"runs": group.size(),
				"award_rate": float(awards.size()) / group.size(),
				"award_median": median(awards),
				"failure_rate": float(failures.size()) / group.size(),
				"failure_median": median(failures),
				"min_cash_median": median(field(group, "min_cash", -1e12)),
				"population_180": median(population_at(group, 180)),
				"population_360": median(population_at(group, 360)),
				"population_720": median(population_at(group, 720)),
				"techs_by_award": median(field(group, "techs_by_award")),
				"audit_errors": _sum_field(group, "audit_error_count"),
			}
		)
	return rows


static func targets(runs: Array, extras: Dictionary = {}) -> Array:
	var rows: Array = []
	_floor_row(rows, runs)
	_award_rows(rows, runs)
	_opening_row(rows, runs)
	_failure_rows(rows, runs)
	_population_rows(rows, runs)
	_research_rows(rows, runs)
	_money_rows(rows, runs)
	_event_rows(rows, runs)
	_audit_row(rows, runs, extras)
	return rows


static func _row(rows: Array, area: String, target: String, measured: String, status: String) -> void:
	rows.append({"area": area, "target": target, "measured": measured, "status": status})


static func _verdict(ok: bool, measured_any: bool = true) -> String:
	if not measured_any:
		return STATUS_NONE
	return STATUS_PASS if ok else STATUS_MISS


static func _floor_row(rows: Array, runs: Array) -> void:
	var awards: Array = field(select(runs, "rush"), "award_day")
	var earliest: float = -1.0 if awards.is_empty() else float(awards.min())
	var text: String = "no rush award" if awards.is_empty() else "earliest day %d" % earliest
	var ok: bool = awards.is_empty() or earliest >= FLOOR_DAY
	_row(rows, "Floor", "rush bot day >= %d" % FLOOR_DAY, text, _verdict(ok, not select(runs, "rush").is_empty()))


static func _award_rows(rows: Array, runs: Array) -> void:
	for difficulty: String in ["normal", "easy", "hard"]:
		var group: Array = select(runs, "balanced", difficulty)
		var awards: Array = field(group, "award_day")
		var band: Array = AWARD_BANDS[difficulty]
		var value: float = median(awards)
		var ok: bool = not awards.is_empty() and value >= band[0] and value <= band[1]
		var text: String = "median %.0f (%d/%d awarded)" % [value, awards.size(), group.size()]
		_row(rows, "Balanced award, " + difficulty, "%d-%d" % band, text, _verdict(ok, not group.is_empty()))


static func _opening_row(rows: Array, runs: Array) -> void:
	var medians: Array = []
	var labels: PackedStringArray = []
	for opening: String in ["capital", "workers", "science"]:
		var awards: Array = field(select(runs, "balanced", "normal", opening), "award_day")
		if not awards.is_empty():
			medians.append(median(awards))
			labels.append("%s %.0f" % [opening, median(awards)])
	if medians.size() < 3:
		_row(rows, "Openings", "medians within 15%", ", ".join(labels), STATUS_NONE)
		return
	var low: float = medians.min()
	var high: float = medians.max()
	var ok: bool = low > 0.0 and (high - low) / low <= OPENING_SPREAD
	_row(rows, "Openings", "medians within 15%", ", ".join(labels), _verdict(ok))


static func _failure_rows(rows: Array, runs: Array) -> void:
	var passive: Array = select(runs, "passive", "normal")
	var review: Array = []
	for run: Dictionary in passive:
		var day: int = int(run.get("company_stage_days", {}).get("review", -1))
		if day >= 0:
			review.append(day)
	var failure: float = median(field(passive, "failure_day"))
	var review_day: float = median(review)
	var ok_review: bool = (
		review_day >= PASSIVE_REVIEW_DAY[0] and review_day <= PASSIVE_REVIEW_DAY[1]
	)
	var ok_failure: bool = (
		failure >= PASSIVE_FAILURE_DAY[0] and failure <= PASSIVE_FAILURE_DAY[1]
	)
	var text: String = "review %.0f, failure %.0f" % [review_day, failure]
	_row(
		rows,
		"Failure, passive",
		"review ~60, failure ~150",
		text,
		_verdict(ok_review and ok_failure, not passive.is_empty())
	)
	var sloppy_review: bool = true
	var sloppy_any: bool = false
	for difficulty: String in ["easy", "normal", "hard"]:
		for run: Dictionary in select(runs, "sloppy", difficulty):
			sloppy_any = true
			if not run.company_stages.has("review"):
				sloppy_review = false
	var hard: Array = select(runs, "sloppy", "hard")
	var hard_failed: int = field(hard, "failure_day").size()
	_row(
		rows,
		"Failure, sloppy",
		"review on all difficulties; fails on hard",
		"all reach review: %s; hard failed %d/%d" % [str(sloppy_review), hard_failed, hard.size()],
		_verdict(sloppy_review and not hard.is_empty() and hard_failed == hard.size(), sloppy_any)
	)


static func _population_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var at_360: float = median(population_at(group, 360))
	var at_720: float = median(population_at(group, 720))
	_row(
		rows,
		"Population",
		">= %d by 360; >= %d by 720" % [POPULATION_AT_360, POPULATION_AT_720],
		"%.0f / %.0f" % [at_360, at_720],
		_verdict(at_360 >= POPULATION_AT_360 and at_720 >= POPULATION_AT_720, not group.is_empty())
	)


static func _research_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var techs: float = median(field(group, "techs_by_award"))
	var share: float = median(field(group, "scientist_share_at_award"))
	var spend: float = median(field(group, "research_share"))
	var ok: bool = (
		techs >= MIN_TECHS_BALANCED
		and share >= SCIENTIST_SHARE[0]
		and share <= SCIENTIST_SHARE[1]
		and spend >= RESEARCH_SHARE[0]
		and spend <= RESEARCH_SHARE[1]
	)
	_row(
		rows,
		"Research, balanced",
		">= 3 techs; scientists 10-20%; spend 15-30%",
		"%.0f techs; %.0f%%; %.0f%%" % [techs, share * 100.0, spend * 100.0],
		_verdict(ok, not group.is_empty())
	)
	var first: Array = select(runs, "research_first", "normal")
	var first_techs: float = median(field(first, "techs_by_award"))
	var first_award: float = median(field(first, "award_day"))
	var band: Array = AWARD_BANDS["normal"]
	var first_ok: bool = (
		first_techs >= MIN_TECHS_RESEARCH_FIRST
		and first_award >= band[0]
		and first_award <= band[1]
	)
	_row(
		rows,
		"Research-first",
		">= 6 techs, award in standard band",
		"%.0f techs; day %.0f" % [first_techs, first_award],
		_verdict(first_ok, not first.is_empty())
	)


static func _money_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var reinvest: float = median(field(group, "reinvested_share_720"))
	var income_180: float = median(field(group, "operating_income_180"))
	var income_720: float = median(field(group, "operating_income_720"))
	var growth: float = income_720 / income_180 if income_180 > 0.0 else 0.0
	_row(
		rows,
		"Money",
		"reinvest >= 60%; income x2.5 from 180 to 720",
		"%.0f%%; x%.2f" % [reinvest * 100.0, growth],
		_verdict(reinvest >= REINVEST_SHARE and growth >= INCOME_GROWTH, not group.is_empty())
	)
	var worst: float = 0.0
	var shares: Array = []
	for run: Dictionary in group:
		var share: float = _top_export_share(run)
		if share >= 0.0:
			shares.append(share)
			worst = maxf(worst, share)
	_row(
		rows,
		"Export mix",
		"no good > 60% after day 180",
		"median %.0f%%, worst %.0f%%" % [median(shares) * 100.0, worst * 100.0],
		_verdict(worst <= EXPORT_CONCENTRATION, not shares.is_empty())
	)


static func _top_export_share(run: Dictionary) -> float:
	var total: float = 0.0
	var top: float = 0.0
	for good: String in run.export_revenue:
		var amount: float = float(run.export_revenue[good])
		total += amount
		top = maxf(top, amount)
	return top / total if total > 0.0 else -1.0


static func _event_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var intervals: Array = []
	for run: Dictionary in group:
		var decisions: int = int(run.pausing_decisions)
		if decisions > 0:
			intervals.append(float(run.final_day) / decisions)
	var distinct: float = median(field(group, "distinct_events"))
	var interval: float = median(intervals)
	_row(
		rows,
		"Events",
		"<= 1 pause per 20 days; >= 15 distinct by 720",
		"1 per %.0f days; %.0f distinct" % [interval, distinct],
		_verdict(interval >= PAUSE_INTERVAL_DAYS and distinct >= DISTINCT_EVENTS, not intervals.is_empty())
	)


static func _audit_row(rows: Array, runs: Array, extras: Dictionary) -> void:
	var total: int = _sum_field(runs, "audit_error_count")
	_row(rows, "Audits", "0 errors in every run", "%d errors in %d runs" % [total, runs.size()], _verdict(total == 0, not runs.is_empty()))
	if extras.has("determinism"):
		var replay: Dictionary = extras.determinism
		_row(
			rows,
			"Determinism",
			"same seed + action log => identical state",
			"%d/%d replays identical" % [int(replay.identical), int(replay.cases)],
			_verdict(int(replay.identical) == int(replay.cases), int(replay.cases) > 0)
		)


static func _sum_field(runs: Array, key: String) -> int:
	var total: int = 0
	for run: Dictionary in runs:
		total += int(run.get(key, 0))
	return total


static func markdown(label: String, stamp: String, rows: Array, groups: Array, seconds: float) -> String:
	var lines: PackedStringArray = []
	lines.append("Run: **%s** · %s · %.0f s wall clock. Source: balance harness." % [label, stamp, seconds])
	lines.append("")
	lines.append("| Area | Target | Measured | Status |")
	lines.append("|---|---|---|---|")
	for row: Dictionary in rows:
		lines.append("| %s | %s | %s | %s |" % [row.area, row.target, row.measured, row.status])
	lines.append("")
	lines.append("| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day | Min cash | Pop 180 / 360 / 720 | Techs at award |")
	lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	for group: Dictionary in groups:
		lines.append(
			(
				"| %s | %s | %s | %d | %.0f%% | %.0f | %.0f%% | %.0f | %.0f | %.0f / %.0f / %.0f | %.0f |"
				% [
					group.bot,
					group.difficulty,
					group.opening,
					group.runs,
					group.award_rate * 100.0,
					group.award_median,
					group.failure_rate * 100.0,
					group.failure_median,
					group.min_cash_median,
					group.population_180,
					group.population_360,
					group.population_720,
					group.techs_by_award,
				]
			)
		)
	return "\n".join(lines)
