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
				"income": today.income,
				"expense": today.expense,
				"invest": today.invest,
				"funding": today.funding,
				"arrivals": today.arrivals,
				"departures": today.departures,
			}
		)
	)
	stats.goods_days.append(today.goods)
	while stats.days.size() > MONEY_DAYS:
		stats.days.pop_front()
	while stats.goods_days.size() > GOODS_DAYS:
		stats.goods_days.pop_front()
	stats.today = _blank()


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
