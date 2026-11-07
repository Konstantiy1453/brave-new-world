extends RefCounted
## Turns run records into per-group medians and the §5.2 target table.

const STATUS_PASS: String = "PASS"
const STATUS_MISS: String = "MISS"
const EventsV2 = preload("res://simulation/events_v2.gd")
const SITE_BANDS: Array = [[14, 20], [20, 30], [28, 40]]
const STATUS_NONE: String = "NOT_MEASURED"
const AWARD_BANDS: Dictionary = {
	"easy": [1800, 2520],
	"normal": [2160, 2880],
	"hard": [2520, 3240],
}
const FLOOR_DAY: int = 1440
const OPENING_SPREAD: float = 0.15
const POLLUTION_LATE_LEAST: float = 0.15
const PASSIVE_REVIEW_DAY: Array[int] = [150, 400]
const PASSIVE_FAILURE_DAY: Array[int] = [400, 900]
const POPULATION_AT_720: int = 300
const POPULATION_AT_1440: int = 800
const MIN_TECHS_BALANCED: int = 40
const SCIENTIST_SHARE: Array[float] = [0.10, 0.20]
const REINVEST_SHARE: float = 0.60
const INCOME_GROWTH: float = 2.5
const EXPORT_CONCENTRATION: float = 0.60
const PAUSE_INTERVAL_DAYS: float = 40.0
const DISTINCT_EVENTS: int = 25
const LABOUR_LEVER: float = 0.20
const MIN_SHORT_EVENTS: int = 60
const MIN_CHAINS: int = 10
const MIN_OFF_SHARE: float = 0.25
const LARGEST_DISTRUST_RISE: float = 0.8
const POLLUTION_EARLY_LIMIT: float = 0.02
const ROAD_DAYS: Array[int] = [90, 300]
## 1.9 money rows: cash cover in days of operating expense, and the share of surplus spent.
const COVER_BEFORE_MEDIAN: float = 60.0
const COVER_BEFORE_P90: float = 120.0
const COVER_AFTER_MEDIAN: float = 180.0
const COVER_AFTER_P90: float = 365.0
const ABSORPTION_LEAST: float = 0.8
const ABSORPTION_YEARS: Array[int] = [2, 3, 4, 5, 6]


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
		(
			rows
			. append(
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
					"population_720": median(population_at(group, 720)),
					"population_1440": median(population_at(group, 1440)),
					"population_2880": median(population_at(group, 2880)),
					"techs_by_award": median(field(group, "techs_by_award")),
					"audit_errors": _sum_field(group, "audit_error_count"),
				}
			)
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
	_cash_rows(rows, runs)
	_event_rows(rows, runs)
	_no_control_row(rows, extras)
	_audit_row(rows, runs, extras)
	return rows


static func _row(
	rows: Array, area: String, target: String, measured: String, status: String
) -> void:
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
	_row(
		rows,
		"Floor",
		"rush bot day >= %d" % FLOOR_DAY,
		text,
		_verdict(ok, not select(runs, "rush").is_empty())
	)


static func _award_rows(rows: Array, runs: Array) -> void:
	for difficulty: String in ["normal", "easy", "hard"]:
		var group: Array = select(runs, "balanced", difficulty)
		var awards: Array = field(group, "award_day")
		var band: Array = AWARD_BANDS[difficulty]
		var value: float = median(awards)
		var ok: bool = not awards.is_empty() and value >= band[0] and value <= band[1]
		var text: String = "median %.0f (%d/%d awarded)" % [value, awards.size(), group.size()]
		_row(
			rows,
			"Balanced award, " + difficulty,
			"%d-%d" % band,
			text,
			_verdict(ok, not group.is_empty())
		)


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
	var best: Dictionary = {}
	var best_of_styles: Dictionary = {}
	for opening: String in ["capital", "workers", "science"]:
		best[opening] = _best_bot(runs, opening, ["balanced", "rush", "research_first"])
		best_of_styles[opening] = _best_bot(runs, opening, ["balanced", "research_first"])
	var varied: bool = _distinct(best.values()) >= 2
	_row(
		rows,
		"Openings",
		"medians within 15%; best bot differs by opening",
		"%s; best %s; without rush %s" % [", ".join(labels), str(best), str(best_of_styles)],
		_verdict(ok and varied)
	)


## The bot with the earliest median award among those that reach it in most runs.
static func _best_bot(runs: Array, opening: String, bots: Array) -> String:
	var best: String = "none"
	var earliest: float = INF
	for bot: String in bots:
		var chosen: Array = select(runs, bot, "normal", opening)
		var awards: Array = field(chosen, "award_day")
		if chosen.is_empty() or awards.size() * 2 <= chosen.size():
			continue
		if median(awards) < earliest:
			earliest = median(awards)
			best = bot
	return best


static func _distinct(values: Array) -> int:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


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
	var ok_failure: bool = failure >= PASSIVE_FAILURE_DAY[0] and failure <= PASSIVE_FAILURE_DAY[1]
	var text: String = "review %.0f, failure %.0f" % [review_day, failure]
	_row(
		rows,
		"Failure, passive",
		(
			"review %d-%d, failure %d-%d"
			% [
				PASSIVE_REVIEW_DAY[0],
				PASSIVE_REVIEW_DAY[1],
				PASSIVE_FAILURE_DAY[0],
				PASSIVE_FAILURE_DAY[1]
			]
		),
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
	var early: float = median(population_at(group, 720))
	var later: float = median(population_at(group, 1440))
	_row(
		rows,
		"Population",
		">= %d by year 2; >= %d by year 4" % [POPULATION_AT_720, POPULATION_AT_1440],
		"%.0f / %.0f" % [early, later],
		_verdict(early >= POPULATION_AT_720 and later >= POPULATION_AT_1440, not group.is_empty())
	)


static func _research_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var techs: float = median(field(group, "techs_by_award"))
	var share: float = median(field(group, "scientist_share_at_award"))
	var categories: float = median(field(group, "categories_at_award"))
	var ok: bool = (
		techs >= MIN_TECHS_BALANCED
		and categories >= 4.0
		and share >= SCIENTIST_SHARE[0]
		and share <= SCIENTIST_SHARE[1]
	)
	_row(
		rows,
		"Research, balanced",
		">= 40 techs; every category; research teams 10-20%",
		"%.0f techs; %.0f categories; %.0f%%" % [techs, categories, share * 100.0],
		_verdict(ok, not group.is_empty())
	)
	var first: Array = select(runs, "research_first", "normal")
	var first_techs: float = median(field(first, "techs_by_award"))
	var first_award: float = median(field(first, "award_day"))
	var band: Array = AWARD_BANDS["normal"]
	var first_ok: bool = first_techs > techs and first_award >= band[0] and first_award <= band[1]
	_row(
		rows,
		"Research-first",
		"more techs than balanced, award in standard band",
		"%.0f techs; day %.0f" % [first_techs, first_award],
		_verdict(first_ok, not first.is_empty())
	)


static func _money_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var reinvest: float = median(field(group, "reinvested_share"))
	var income_early: float = median(field(group, "operating_income_early"))
	var income_late: float = median(field(group, "operating_income_late"))
	var growth: float = income_late / income_early if income_early > 0.0 else 0.0
	_row(
		rows,
		"Money",
		"reinvest >= 60%; income x2.5 from year 2 to year 6",
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
		"no good > 60% after year 2",
		"median %.0f%%, worst %.0f%%" % [median(shares) * 100.0, worst * 100.0],
		_verdict(worst <= EXPORT_CONCENTRATION, not shares.is_empty())
	)


static func percentile(values: Array, share: float) -> float:
	if values.is_empty():
		return -1.0
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	return float(sorted_values[mini(sorted_values.size() - 1, int(share * sorted_values.size()))])


## Cover samples of one run between `first` and `last` day, inclusive.
static func cover_between(run: Dictionary, first: int, last: int) -> Array:
	var values: Array = []
	for sample: Array in run.get("cover_samples", []):
		if int(sample[0]) >= first and int(sample[0]) <= last:
			values.append(float(sample[1]))
	return values


static func _cash_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var medians: Array = []
	var highs: Array = []
	var after: Array = []
	for run: Dictionary in group:
		var award: int = int(run.award_day)
		var last: int = award if award > 0 else int(run.final_day)
		var before: Array = cover_between(run, 720, last)
		if not before.is_empty():
			medians.append(median(before))
			highs.append(percentile(before, 0.9))
		var samples: Array = run.get("cover_samples", [])
		if award > 0 and award <= 2880 and not samples.is_empty():
			after.append(float(samples.back()[1]))
	var before_median: float = median(medians)
	var before_high: float = median(highs)
	_row(
		rows,
		"Cash cover before the award",
		(
			"day 720 to award: median <= %.0f days, p90 <= %.0f"
			% [COVER_BEFORE_MEDIAN, COVER_BEFORE_P90]
		),
		"median %.0f days, p90 %.0f days" % [before_median, before_high],
		_verdict(
			before_median <= COVER_BEFORE_MEDIAN and before_high <= COVER_BEFORE_P90,
			not medians.is_empty()
		)
	)
	var after_median: float = median(after)
	var after_high: float = percentile(after, 0.9)
	_row(
		rows,
		"Cash cover after the award",
		(
			"last day, runs awarded by 2880: median <= %.0f days, p90 <= %.0f"
			% [COVER_AFTER_MEDIAN, COVER_AFTER_P90]
		),
		"median %.0f days, p90 %.0f days" % [after_median, after_high],
		_verdict(
			after_median <= COVER_AFTER_MEDIAN and after_high <= COVER_AFTER_P90,
			not after.is_empty()
		)
	)
	var yearly: Array = []
	for year: int in ABSORPTION_YEARS:
		var shares: Array = []
		for run: Dictionary in group:
			var surplus: Array = run.get("year_surplus", [])
			var invested: Array = run.get("year_invested", [])
			if year < surplus.size() and float(surplus[year]) > 0.0:
				shares.append(float(invested[year]) / float(surplus[year]))
		yearly.append(median(shares))
	var lowest: float = INF
	var parts: PackedStringArray = []
	for index: int in range(yearly.size()):
		parts.append("y%d %.0f%%" % [ABSORPTION_YEARS[index] + 1, float(yearly[index]) * 100.0])
		if float(yearly[index]) >= 0.0:
			lowest = minf(lowest, float(yearly[index]))
	var users: int = 0
	var used_days: Array = []
	for run: Dictionary in group:
		if int(run.get("services_days", 0)) > 0:
			users += 1
			used_days.append(int(run.services_days))
	_row(
		rows,
		"Services budget",
		"used by the balanced bot (1.9 optional spending)",
		(
			"%d of %d runs, median %.0f days paid"
			% [users, group.size(), median(used_days) if not used_days.is_empty() else 0.0]
		),
		_verdict(users * 10 >= group.size() * 8, not group.is_empty())
	)
	_row(
		rows,
		"Absorption",
		"spending >= 80% of operating surplus in years 3-7",
		", ".join(parts),
		_verdict(lowest >= ABSORPTION_LEAST, lowest < INF)
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
	var breaks: int = _sum_field(runs, "cooldown_breaks")
	var definitions: Dictionary = EventsV2.definitions().definitions
	var shorts: int = 0
	var chains: int = 0
	for id: String in definitions:
		if str(definitions[id].type) == "chain":
			chains += 1
		else:
			shorts += 1
	var off_share: float = median(field(group, "events_off")) / maxi(1, shorts + chains)
	var overlap: float = _opened_overlap(group)
	_row(
		rows,
		"Events",
		(
			"<= 1 pause per %d days; >= %d distinct; %d short, %d chains; >= %d%% off each run"
			% [
				PAUSE_INTERVAL_DAYS,
				DISTINCT_EVENTS,
				MIN_SHORT_EVENTS,
				MIN_CHAINS,
				MIN_OFF_SHARE * 100.0
			]
		),
		(
			"1 per %.0f days; %.0f distinct; %d repeats; %d short, %d chains; %.0f%% off; seeds share %.0f%%"
			% [interval, distinct, breaks, shorts, chains, off_share * 100.0, overlap * 100.0]
		),
		_verdict(
			(
				interval >= PAUSE_INTERVAL_DAYS
				and distinct >= DISTINCT_EVENTS
				and breaks == 0
				and shorts >= MIN_SHORT_EVENTS
				and chains >= MIN_CHAINS
				and off_share >= MIN_OFF_SHARE
				and overlap < 0.95
			),
			not intervals.is_empty()
		)
	)
	_pressure_rows(rows, runs)


## How alike two different seeds' runs were: events both saw, over events either saw.
static func _opened_overlap(group: Array) -> float:
	var shares: Array = []
	for at: int in range(group.size() - 1):
		var a: Array = group[at].get("opened_events", [])
		var b: Array = group[at + 1].get("opened_events", [])
		if int(group[at].seed) == int(group[at + 1].seed) or a.is_empty() or b.is_empty():
			continue
		var both: int = 0
		for id: Variant in a:
			if b.has(id):
				both += 1
		shares.append(float(both) / maxi(1, a.size() + b.size() - both))
	return median(shares)


## Distrust climbs slowly and pollution stays out of it until the late game.
static func _pressure_rows(rows: Array, runs: Array) -> void:
	var group: Array = select(runs, "balanced", "normal")
	var rises: Array = field(group, "largest_distrust_rise")
	var worst: float = 0.0 if rises.is_empty() else float(rises.max())
	_row(
		rows,
		"Distrust",
		"largest daily rise <= %.1f" % LARGEST_DISTRUST_RISE,
		"worst %.2f" % worst,
		_verdict(worst <= LARGEST_DISTRUST_RISE, not rises.is_empty())
	)
	var early: Array = []
	var late: Array = []
	for run: Dictionary in group:
		if run.pollution_penalty.has("1080"):
			early.append(float(run.pollution_penalty["1080"]))
		if run.pollution_penalty.has("2880"):
			late.append(float(run.pollution_penalty["2880"]))
	var early_worst: float = 0.0 if early.is_empty() else float(early.max())
	_row(
		rows,
		"Pollution",
		"output penalty < %.0f%% through year 3" % (POLLUTION_EARLY_LIMIT * 100.0),
		"year 3 worst %.1f%%; year 8 median %.1f%%" % [early_worst * 100.0, median(late) * 100.0],
		_verdict(early_worst < POLLUTION_EARLY_LIMIT, not early.is_empty())
	)
	var roads: Array = field(group, "first_road_days", 0.0)
	var road_median: float = median(roads)
	_row(
		rows,
		"Roads",
		"first road takes %d-%d days" % ROAD_DAYS,
		"median %.0f days" % road_median,
		_verdict(road_median >= ROAD_DAYS[0] and road_median <= ROAD_DAYS[1], not roads.is_empty())
	)


static func _no_control_row(rows: Array, extras: Dictionary) -> void:
	var measured: Dictionary = extras.get("no_control", {})
	var loss: float = float(measured.get("penalty", -1.0))
	_row(
		rows,
		"Pollution, no control",
		"output penalty >= %.0f%% by year 8" % (POLLUTION_LATE_LEAST * 100.0),
		"%.1f%%" % (loss * 100.0),
		_verdict(loss >= POLLUTION_LATE_LEAST, not measured.is_empty())
	)


static func _audit_row(rows: Array, runs: Array, extras: Dictionary) -> void:
	var total: int = _sum_field(runs, "audit_error_count")
	_row(
		rows,
		"Audits",
		"0 errors in every run",
		"%d errors in %d runs" % [total, runs.size()],
		_verdict(total == 0, not runs.is_empty())
	)
	if extras.has("labour_lever"):
		var lever: Dictionary = extras.labour_lever
		var base: float = float(lever.base)
		var gain: float = float(lever.raised) / base - 1.0 if base > 0.0 else 0.0
		_row(
			rows,
			"Labour lever",
			"wage 1.0x to 1.3x changes 360-day immigration by >= 20%",
			"%.0f to %.0f arrivals (%+.0f%%)" % [base, float(lever.raised), gain * 100.0],
			_verdict(absf(gain) >= LABOUR_LEVER, base > 0.0)
		)
	if extras.has("geography") and not extras.geography.is_empty():
		_geography_rows(rows, extras.geography)
	if extras.has("determinism"):
		var replay: Dictionary = extras.determinism
		_row(
			rows,
			"Determinism",
			"same seed + action log => identical state",
			"%d/%d replays identical" % [int(replay.identical), int(replay.cases)],
			_verdict(int(replay.identical) == int(replay.cases), int(replay.cases) > 0)
		)


static func _geography_rows(rows: Array, geo: Dictionary) -> void:
	var parts: PackedStringArray = []
	var sized: bool = true
	for key: String in ["0", "1", "2"]:
		var row: Dictionary = geo.sites.get(key, {"min": 0, "max": 0})
		var band: Array = SITE_BANDS[int(key)]
		parts.append("%d-%d" % [int(row.min), int(row.max)])
		sized = sized and int(row.min) >= int(band[0]) and int(row.max) <= int(band[1])
	var common: int = 0
	var seeds: int = int(geo.seeds)
	for key: String in geo.best:
		if float(geo.best[key]) / seeds >= 0.1:
			common += 1
	var land: Array = geo.land
	var continents: Array = geo.continents.keys()
	continents.sort()
	var land_ok: bool = float(land[0]) >= 0.25 and float(land[1]) <= 0.45
	_row(
		rows,
		"Geography",
		"sites 14-20 / 20-30 / 28-40; 3+ start pairs; 3+ start archetypes; land 25-45%; continents 2-6",
		(
			"sites %s; pairs min %d; %d archetypes; land %.0f-%.0f%%; continents %s"
			% [
				" / ".join(parts),
				int(geo.pairs_min),
				common,
				float(land[0]) * 100.0,
				float(land[1]) * 100.0,
				",".join(PackedStringArray(continents)),
			]
		),
		_verdict(sized and int(geo.pairs_min) >= 3 and common >= 3 and land_ok)
	)
	var trade: float = float(geo.road_trade)
	_row(
		rows,
		"Road trade-off",
		"cheaper road is the slower one for 30-70% of pairs",
		"%.0f%% of %d pairs" % [trade, int(geo.road_pairs)],
		_verdict(trade >= 30.0 and trade <= 70.0)
	)


static func _sum_field(runs: Array, key: String) -> int:
	var total: int = 0
	for run: Dictionary in runs:
		total += int(run.get(key, 0))
	return total


static func markdown(
	label: String, stamp: String, rows: Array, groups: Array, seconds: float
) -> String:
	var lines: PackedStringArray = []
	lines.append(
		"Run: **%s** · %s · %.0f s wall clock. Source: balance harness." % [label, stamp, seconds]
	)
	lines.append("")
	lines.append("| Area | Target | Measured | Status |")
	lines.append("|---|---|---|---|")
	for row: Dictionary in rows:
		lines.append("| %s | %s | %s | %s |" % [row.area, row.target, row.measured, row.status])
	lines.append("")
	lines.append(
		(
			"| Bot | Difficulty | Opening | Runs | Awarded | Award day | Failed | Failure day"
			+ " | Min cash | Pop y2 / y4 / y8 | Techs at award |"
		)
	)
	lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	for group: Dictionary in groups:
		(
			lines
			. append(
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
						group.population_720,
						group.population_1440,
						group.population_2880,
						group.techs_by_award,
					]
				)
			)
		)
	return "\n".join(lines)
