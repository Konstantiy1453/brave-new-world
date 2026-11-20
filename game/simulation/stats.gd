extends RefCounted
## Daily rollups for the economy and population pages: public money by ledger key, goods flows and
## people moved. Nothing reads these to decide anything; they only describe what happened.

const MONEY_DAYS: int = 90
const GOODS_DAYS: int = 30
const PRODUCED: int = 0
const CONSUMED: int = 1
const EXPORTED: int = 2
const IMPORTED: int = 3
const SHIPPED: int = 4
const FLOW_COLUMNS: int = 5
const YEAR_DAYS: int = 360
const NUMBER_COLUMNS: Array[String] = [
	"income", "expense", "invest", "funding", "arrivals", "departures"
]
## Per town, newer than some saves' rows (1.10): births, people moved between towns (expeditions,
## crews, workers following jobs; a landing counts as moved in) and the population at the day's end.
const PEOPLE_COLUMNS: Array[String] = ["births", "moves"]


static func ensure_state(state: Dictionary) -> void:
	if not state.has("stats"):
		state.stats = {"today": _blank(), "days": [], "goods_days": [], "sinks": []}
	if not state.stats.has("sinks"):
		state.stats.sinks = []


## Spending by sink (1.9): one dictionary of sums per 360-day year of the colony, kept for the
## whole game so the economy page can say where the money went.
static func sink(state: Dictionary, name: String, amount: float) -> void:
	if name == "" or amount <= 0.0 or not state.has("stats"):
		return
	if not state.stats.has("sinks"):
		state.stats.sinks = []
	var years: Array = state.stats.sinks
	var year: int = maxi(0, floori(float(state.day) / YEAR_DAYS))
	while years.size() <= year:
		years.append({})
	var row: Dictionary = years[year]
	row[name] = float(row.get(name, 0.0)) + amount


static func _blank() -> Dictionary:
	return {
		"income": {},
		"expense": {},
		"invest": {},
		"funding": {},
		"goods": {},
		"arrivals": {},
		"departures": {},
		"births": {},
		"moves": {},
	}


## A save's rollups must be numbers in the expected places: the pages add them up unchecked.
static func validate(candidate: Dictionary) -> String:
	var stats: Dictionary = candidate.stats
	var rows: Array = stats.days.duplicate()
	rows.append(stats.today)
	for row: Variant in rows:
		if not row is Dictionary:
			return "统计数据无效"
		for column: String in NUMBER_COLUMNS:
			if not _numbers_only(row.get(column)):
				return "统计数据无效"
		for column: String in PEOPLE_COLUMNS + ["pop"]:
			if row.has(column) and not _numbers_only(row[column]):
				return "统计数据无效"
	for row: Variant in stats.days:
		if not (row.get("cash") is float or row.get("cash") is int):
			return "统计数据无效"
	if not stats.get("sinks", []) is Array:
		return "统计数据无效"
	for row: Variant in stats.get("sinks", []):
		if not row is Dictionary or not _numbers_only(row):
			return "统计数据无效"
	var goods_rows: Array = stats.goods_days.duplicate()
	goods_rows.append(stats.today.get("goods"))
	for row: Variant in goods_rows:
		if not row is Dictionary:
			return "统计数据无效"
		for flows: Variant in row.values():
			if not flows is Array or flows.size() != FLOW_COLUMNS or not _numbers_only(flows):
				return "统计数据无效"
	return ""


static func _numbers_only(values: Variant) -> bool:
	if not (values is Dictionary or values is Array):
		return false
	for value: Variant in values.values() if values is Dictionary else values:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return true


## Adds to one of income, expense, invest or funding under a ledger key.
static func money(state: Dictionary, column: String, key: String, amount: float) -> void:
	if not state.has("stats"):
		return
	var row: Dictionary = state.stats.today[column]
	row[key] = float(row.get(key, 0.0)) + amount


static func goods(state: Dictionary, good: String, column: int, amount: float) -> void:
	if not state.has("stats"):
		return
	var row: Dictionary = state.stats.today.goods
	if not row.has(good):
		row[good] = [0.0, 0.0, 0.0, 0.0, 0.0]
	row[good][column] = float(row[good][column]) + amount


## Adds to a per-town count of today: "births" or "moves" (signed: in is positive).
static func count(state: Dictionary, column: String, region: int, amount: int) -> void:
	if not state.has("stats") or amount == 0:
		return
	if not state.stats.today.has(column):
		state.stats.today[column] = {}
	var row: Dictionary = state.stats.today[column]
	row[str(region)] = int(row.get(str(region), 0)) + amount


static func people(state: Dictionary, region: int, arriving: bool, count: int) -> void:
	if not state.has("stats"):
		return
	var row: Dictionary = state.stats.today["arrivals" if arriving else "departures"]
	row[str(region)] = int(row.get(str(region), 0)) + count


static func close_day(state: Dictionary) -> void:
	var stats: Dictionary = state.stats
	var today: Dictionary = stats.today
	(
		stats
		. days
		. append(
			{
				"day": int(state.day),
				"cash": float(state.cash),
				"labour": labour(state),
				"income": today.income,
				"expense": today.expense,
				"invest": today.invest,
				"funding": today.funding,
				"arrivals": today.arrivals,
				"departures": today.departures,
				"births": today.get("births", {}),
				"moves": today.get("moves", {}),
				"pop": _populations(state),
			}
		)
	)
	stats.goods_days.append(today.goods)
	while stats.days.size() > MONEY_DAYS:
		stats.days.pop_front()
	while stats.goods_days.size() > GOODS_DAYS:
		stats.goods_days.pop_front()
	stats.today = _blank()


static func _populations(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for s: Dictionary in state.get("settlements", []):
		result[str(int(s.region))] = int(s.population)
	return result


## A town's population over the last `window_days` closed days: where it stood, where it stands, the
## net change and what made it (immigration, departures, births, people moved in or out with
## expeditions, crews and workers following jobs, and anything else). `known` is false while the
## history is too short or older than the records.
static func population_change(state: Dictionary, region: int, window_days: int = 30) -> Dictionary:
	var days: Array = state.get("stats", {}).get("days", [])
	var key: String = str(region)
	var result: Dictionary = {
		"known": false,
		"days": 0,
		"then": 0,
		"now": 0,
		"net": 0,
		"arrivals": 0,
		"departures": 0,
		"births": 0,
		"moves": 0,
		"other": 0,
	}
	if days.is_empty() or not days.back().has("pop"):
		return result
	var first: int = maxi(0, days.size() - window_days)
	var start: Dictionary = days[first - 1] if first > 0 else {}
	if first > 0 and not start.has("pop"):
		return result
	result.then = int(start.get("pop", {}).get(key, 0))
	result.now = int(days.back().pop.get(key, 0))
	for index: int in range(first, days.size()):
		var row: Dictionary = days[index]
		result.days = int(result.days) + 1
		result.arrivals = int(result.arrivals) + int(row.arrivals.get(key, 0))
		result.departures = int(result.departures) + int(row.departures.get(key, 0))
		result.births = int(result.births) + int(row.get("births", {}).get(key, 0))
		result.moves = int(result.moves) + int(row.get("moves", {}).get(key, 0))
	result.net = int(result.now) - int(result.then)
	result.other = (
		int(result.net)
		- int(result.arrivals)
		+ int(result.departures)
		- int(result.births)
		- int(result.moves)
	)
	result.known = true
	return result


## Engineering crews and research teams in every settlement: the colony's labour force.
static func labour(state: Dictionary) -> int:
	var total: int = 0
	for s: Dictionary in state.get("settlements", []):
		total += int(s.get("workers", 0)) + int(s.get("scientists", 0))
	return total


## The labour force's mean change a day over the last `span` closed days; 0 until two days with a
## count have been kept (saves from before 1.9's interface pass have none).
static func labour_change(state: Dictionary, span: int = 7) -> float:
	var counted: Array = []
	for row: Dictionary in state.get("stats", {}).get("days", []):
		if row.has("labour"):
			counted.append(row)
	if counted.size() < 2:
		return 0.0
	var first: Dictionary = counted[maxi(0, counted.size() - 1 - span)]
	var last: Dictionary = counted[counted.size() - 1]
	var days: int = maxi(1, int(last.day) - int(first.day))
	return (float(last.labour) - float(first.labour)) / days


static func _add_all(into: Dictionary, row: Dictionary) -> void:
	for key: String in row:
		into[key] = float(into.get(key, 0.0)) + float(row[key])


## Totals over the last `window` days, with goods as produced, consumed, exported, imported, shipped.
static func window(state: Dictionary, window_days: int = 30) -> Dictionary:
	var result: Dictionary = {
		"days": 0,
		"income": {},
		"expense": {},
		"invest": {},
		"funding": {},
		"goods": {},
		"arrivals": {},
		"departures": {},
	}
	var days: Array = state.get("stats", {}).get("days", [])
	var first: int = maxi(0, days.size() - window_days)
	for index: int in range(first, days.size()):
		var row: Dictionary = days[index]
		result.days += 1
		for column: String in NUMBER_COLUMNS:
			_add_all(result[column], row[column])
	var goods_days: Array = state.get("stats", {}).get("goods_days", [])
	for index: int in range(maxi(0, goods_days.size() - window_days), goods_days.size()):
		var row: Dictionary = goods_days[index]
		for good: String in row:
			if not result.goods.has(good):
				result.goods[good] = [0.0, 0.0, 0.0, 0.0, 0.0]
			for column: int in range(5):
				result.goods[good][column] += float(row[good][column])
	for good: String in result.goods:
		# A sale leaves the warehouse too; consumption here means use inside the colony.
		var row: Array = result.goods[good]
		row[CONSUMED] = maxf(0.0, float(row[CONSUMED]) - float(row[EXPORTED]))
	return result


## Cash and daily net over the kept days, oldest first, for the chart.
static func series(state: Dictionary) -> Dictionary:
	var cash := PackedFloat32Array()
	var net := PackedFloat32Array()
	for row: Dictionary in state.get("stats", {}).get("days", []):
		cash.append(float(row.cash))
		var income: float = 0.0
		var expense: float = 0.0
		for key: String in row.income:
			income += float(row.income[key])
		for key: String in row.expense:
			expense += float(row.expense[key])
		net.append(income - expense)
	return {"cash": cash, "net": net}
