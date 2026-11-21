extends RefCounted
## The order screen's four answers before anything is paid (1.11):
## 1. cash that leaves the treasury now: the construction price (with any mine road) plus what the
##    warehouse lacks of materials and parts, bought at import price on the spot;
## 2. when a crew can begin: from the town's crews and their queue as they stand (Crews.projection),
##    a crew on its way or in training included, with the order's place in that crew's line;
## 3. when the facility enters service: the day its crew should finish it;
## 4. what it is likely to add in this town: for a facility that earns, the additional cash flow a day
##    as a range, from the staff the town can give it, the inputs it can get, the port room for what
##    it sells, the recent selling price after its own extra volume, wages and upkeep, with what
##    replaces imports kept apart from what earns export receipts; payback both from the order date
##    and from the start of production. For a utility, a home or a laboratory, what it changes.

const Keys = preload("res://simulation/keys.gd")
const Stats = preload("res://simulation/stats.gd")
const Market = preload("res://simulation/market.gd")
const Research = preload("res://simulation/research.gd")
const Population = preload("res://simulation/population.gd")
const Supply = preload("res://simulation/supply.gd")

const EARNING_ROLES: Array[String] = [
	"mine", "harvest", "factory", "farm", "indoor_farm", "harbor", "foodworks", "commerce", "income"
]
const HISTORY_FULL_DAYS: int = 30
const BAND_FULL_HISTORY: float = 0.15
const BAND_SHORT_HISTORY: float = 0.35


static func view(sim: RefCounted, region: int, kind: String, plot: int = -1) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or not sim.config.buildings.has(kind):
		return {}
	var forecast: Dictionary = sim.build_forecast(region, kind, plot)
	if forecast.is_empty():
		return {}
	var spec: Dictionary = sim.Production.build_preview(sim, region, kind, int(forecast.plot))
	var short: Dictionary = {}
	var bought: float = 0.0
	for good: String in ["materials", "parts"]:
		var missing: float = maxf(0.0, float(spec[good]) - float(s.stock[good]))
		short[good] = missing
		bought += (
			missing * float(sim.config.prices[good]) * (1.0 + float(sim.config.economy.port_fee))
		)
	var day: int = int(sim.state.day)
	var crew: Dictionary = sim.Crews.projection(sim, s, kind, int(spec.days))
	var service: int = int(crew.finish)
	var result: Dictionary = {
		"kind": kind,
		"name": str(spec.name),
		"today": day,
		"construction": float(spec.cost),
		"road": float(spec.get("haul", {}).get("cost", 0.0)),
		"bought": bought,
		"short": short,
		"cash_now": float(spec.cost) + bought,
		"local_materials": minf(float(spec.materials), float(s.stock.materials)),
		"local_parts": minf(float(spec.parts), float(s.stock.parts)),
		"days": int(spec.days),
		"crew": crew,
		"in_service": service,
		"refusal": str(forecast.disabled_reason),
	}
	result.benefit = benefit(sim, s, kind, forecast, result)
	return result


## What the facility would add to the colony's cash a day once it works, as a range, with every
## figure it rests on.
static func benefit(
	sim: RefCounted, s: Dictionary, kind: String, forecast: Dictionary, order: Dictionary
) -> Dictionary:
	var spec: Dictionary = sim.config.buildings[kind]
	var role: String = str(spec.get("role", ""))
	if not role in EARNING_ROLES:
		return _utility(sim, s, kind, role)
	var fee: float = float(sim.config.economy.port_fee)
	var jobs: int = int(forecast.jobs) + int(forecast.specialists)
	var free: int = int(sim.free_workers(s))
	var staffed: float = 1.0 if jobs <= 0 else clampf(float(free) / jobs, 0.0, 1.0)
	var history: int = _history_days(sim)
	var band: float = BAND_FULL_HISTORY if history >= HISTORY_FULL_DAYS else BAND_SHORT_HISTORY
	var room: float = maxf(0.0, float(s.get("port_capacity", 0.0)) - float(s.get("port_used", 0.0)))
	var imports: Dictionary = _imports_a_day(sim)
	var inputs: Array = []
	var input_share: float = 1.0
	var input_cost: float = 0.0
	for good: String in spec.get("inputs", {}):
		var need: float = float(spec.inputs[good])
		var spare: float = _spare_supply(sim, s, good)
		var exported: float = _exported_a_day(sim, s, good)
		var share: float = clampf(spare / maxf(need, 0.0001), 0.0, 1.0)
		input_share = minf(input_share, share)
		# What the input would have fetched sold: what the town exports of it now is forgone.
		var forgone: float = minf(need, exported)
		var price: float = Market.price(sim, good) * (1.0 - fee)
		input_cost += forgone * price
		(
			inputs
			. append(
				{
					"good": good,
					"need": need,
					"spare": spare,
					"exported": exported,
					"share": share,
					"forgone_price": price,
				}
			)
		)
	var outputs: Array = []
	var revenue: float = 0.0
	var replaced: float = 0.0
	var receipts: float = 0.0
	for good: String in forecast.get("outputs", {}):
		var amount: float = float(forecast.outputs[good]) * input_share
		var row: Dictionary = {"good": good, "amount": amount}
		if role in ["farm", "indoor_farm", "harbor"]:
			var supply_kind: String = "catch" if role == "harbor" else "food"
			var order_row: Dictionary = Supply.open_order(sim, int(s.region), supply_kind)
			if not order_row.is_empty():
				row.export_value = amount * float(order_row.price) * (1.0 - fee)
				row.exported = amount
				row.replaces = 0.0
				row.basis = "supply"
			else:
				var usable: float = float(forecast.get("usable", {}).get(good, amount))
				row.replaces = usable
				row.exported = 0.0
				row.import_value = usable * float(sim.Production.delivered_price(sim, s, good))
				row.idle = amount - usable
				row.basis = "imports"
		else:
			# A town that already sells this good has none short: more of it is sold, not saved.
			var already: float = _exported_a_day(sim, s, good)
			var replace: float = (
				0.0 if already > 0.01 else minf(amount, float(imports.get(good, 0.0)))
			)
			var rest: float = amount - replace
			var port_limited: float = maxf(0.0, rest - room)
			var sold: float = rest - port_limited
			var now: float = Market.price(sim, good)
			var after: float = _price_after(sim, good, sold)
			row.replaces = replace
			row.import_value = replace * float(sim.config.prices[good]) * (1.0 + fee)
			row.exported = sold
			row.port_limited = port_limited
			row.price_now = now
			row.price_after = after
			row.export_value = sold * after * (1.0 - fee)
			row.basis = "market"
		replaced += float(row.get("import_value", 0.0))
		receipts += float(row.get("export_value", 0.0))
		revenue += float(row.get("import_value", 0.0)) + float(row.get("export_value", 0.0))
		outputs.append(row)
	if role in ["foodworks", "commerce", "income"]:
		revenue = float(forecast.revenue_per_day)
		receipts = revenue if role != "commerce" else 0.0
	var wages: float = float(forecast.wages_per_day)
	var upkeep: float = float(forecast.maintenance)
	# High: the town finds the staff (hired or moved in). Low: only today's free workers, and prices
	# and volumes `band` worse.
	var high: float = revenue - input_cost - wages - upkeep
	var low: float = (revenue * staffed - input_cost * staffed) * (1.0 - band) - wages - upkeep
	low = minf(low, high)
	var outlay: float = (
		float(order.cash_now)
		+ float(order.local_materials) * Market.price(sim, "materials") * (1.0 - fee)
		+ float(order.local_parts) * Market.price(sim, "parts") * (1.0 - fee)
	)
	var wait: int = maxi(0, int(order.in_service) - int(order.today))
	return {
		"kind": "earning",
		"role": role,
		"jobs": jobs,
		"free_workers": free,
		"staffed": staffed,
		"inputs": inputs,
		"input_share": input_share,
		"input_cost": input_cost,
		"outputs": outputs,
		"replaces_imports": replaced,
		"export_receipts": receipts,
		"port_room": room,
		"wages": wages,
		"upkeep": upkeep,
		"net_high": high,
		"net_low": low,
		"history_days": history,
		"band": band,
		"outlay": outlay,
		"wait_days": wait if int(order.in_service) >= 0 else -1,
		"payback_start": _payback(outlay, low, high),
		"payback_order": _payback(outlay, low, high, wait if int(order.in_service) >= 0 else -1),
		"old_forecast": float(forecast.payback_days),
	}


## Days to earn back `outlay`: {low, high} (the high figure from the low net); -1 when it never pays.
static func _payback(outlay: float, low: float, high: float, wait: int = 0) -> Dictionary:
	if wait < 0:
		return {"low": -1, "high": -1}
	var soonest: int = ceili(outlay / high) + wait if high > 0.0 else -1
	var latest: int = ceili(outlay / low) + wait if low > 0.0 else -1
	return {"low": soonest, "high": latest}


## A facility that earns nothing itself: what it changes in this town.
static func _utility(sim: RefCounted, s: Dictionary, kind: String, role: String) -> Dictionary:
	var spec: Dictionary = sim.config.buildings[kind]
	var row: Dictionary = {"kind": "utility", "role": role}
	match role:
		"power":
			row.supply = float(s.get("power_supply", 0.0))
			row.demand = float(s.get("power_demand", 0.0))
			row.adds = (
				float(spec.get("capacity", 0.0)) * (1.0 + Research.bonus(sim, "power_output"))
			)
		"water":
			var reg: Dictionary = sim.state.world.regions[int(s.region)]
			row.supply = float(s.get("water_supply", 0.0))
			row.demand = float(s.get("water_demand", 0.0))
			row.adds = (
				float(spec.capacity)
				* (
					float(spec.get("site_floor", 1.0))
					+ float(reg.water) * float(spec.get("site_gain", 0.0))
				)
			)
		"port":
			row.supply = float(s.get("port_capacity", 0.0))
			row.demand = float(s.get("port_used", 0.0))
			row.adds = (
				float(spec.get("capacity", 0.0)) * (1.0 + Research.bonus(sim, "port_capacity"))
			)
			row.crowded = _crowded_out(sim, s)
		"housing":
			row.supply = float(s.get("housing", 0))
			row.demand = float(s.get("population", 0))
			row.adds = float(Population.habitat_beds(sim, {"kind": kind, "level": 1}))
		"lab":
			row.adds = float(spec.get("seats", 0))
	return row


## A day's value of exports the town's port turned away lately, judged from goods piling up beyond
## what it sells: what a second freight port could carry out.
static func _crowded_out(sim: RefCounted, s: Dictionary) -> float:
	if float(s.get("port_used", 0.0)) < float(s.get("port_capacity", 0.0)) - 0.5:
		return 0.0
	var value: float = 0.0
	for good: String in sim.Logistics.EXPORT_ORDER:
		var row: Dictionary = sim.Stocks.availability(sim, s, good)
		value += maxf(0.0, float(row.sellable)) * Market.price(sim, good) * 0.05
	return value


## Days of colony history the estimate can look back on (up to the window).
static func _history_days(sim: RefCounted) -> int:
	return mini(int(sim.state.day), HISTORY_FULL_DAYS)


## What the colony imported of each good a day over the last month. A new plant's output replaces
## imports only as far as the colony buys that good in; the rest is sold at the market price.
static func _imports_a_day(sim: RefCounted) -> Dictionary:
	var window: Dictionary = sim.stats_window(HISTORY_FULL_DAYS)
	var days: float = maxf(1.0, float(window.get("days", 1)))
	var result: Dictionary = {}
	for good: String in window.get("goods", {}):
		result[good] = float(window.goods[good][Stats.IMPORTED]) / days
	return result


## What this town exported of a good a day over the last month: its own sales record, or before the
## town has one (a save from before 1.11), the colony's exports of it in proportion to what this town
## mines of it.
static func _exported_a_day(sim: RefCounted, s: Dictionary, good: String) -> float:
	if not s.get("sales", []).is_empty():
		var month: Dictionary = Supply.sales(s, int(sim.state.day), HISTORY_FULL_DAYS)
		var span: float = float(
			mini(int(sim.state.day) - int(s.sales[0].day) + 1, HISTORY_FULL_DAYS)
		)
		return float(month.goods.get(good, 0.0)) / maxf(1.0, span)
	var window: Dictionary = sim.stats_window(HISTORY_FULL_DAYS)
	var flows: Array = window.get("goods", {}).get(good, [])
	if flows.is_empty():
		return 0.0
	var colony: float = float(flows[Stats.EXPORTED]) / maxf(1.0, float(window.get("days", 1)))
	var here: float = _mined(sim, s, good) + _processed(sim, s, good)
	var everywhere: float = 0.0
	for place: Dictionary in sim.state.settlements:
		everywhere += _mined(sim, place, good) + _processed(sim, place, good)
	return colony * (here / everywhere if everywhere > 0.0 else 0.0)


## What a town's factories make of a good a day at their working efficiency.
static func _processed(sim: RefCounted, s: Dictionary, good: String) -> float:
	var made: float = 0.0
	for b: Dictionary in s.get("buildings", []):
		if int(b.get("remaining", 0)) > 0 or not bool(b.get("enabled", true)):
			continue
		var d: Dictionary = sim.config.buildings.get(str(b.kind), {})
		if str(d.get("role", "")) == "factory" and d.get("outputs", {}).has(good):
			made += float(d.outputs[good]) * float(b.get("efficiency", 1.0))
	return made


## What a town's mines and harvesters make of a good a day: yesterday's output where it is
## recorded, else their rate at their working efficiency.
static func _mined(sim: RefCounted, s: Dictionary, good: String) -> float:
	var made: float = 0.0
	for b: Dictionary in s.get("buildings", []):
		if int(b.get("remaining", 0)) > 0 or not bool(b.get("enabled", true)):
			continue
		var d: Dictionary = sim.config.buildings.get(str(b.kind), {})
		var role: String = str(d.get("role", ""))
		if role == "mine" and str(d.output) == good:
			if b.has("output"):
				made += float(b.output)
			else:
				var plot: Dictionary = (
					sim.Sites.plot_of(sim, s, b) if int(b.get("plot", -1)) >= 0 else {}
				)
				made += (
					float(d.rate) * float(plot.get("grade", 1.0)) * float(b.get("efficiency", 1.0))
				)
		elif role == "harvest" and d.outputs.has(good):
			made += float(d.outputs[good]) * float(b.get("efficiency", 1.0))
	return made


## What the town gets of a good a day that its own factories do not already take: its mines and
## harvesters, plus what comes in by road (cargo on its way, spread over its trip), less the inputs
## of the factories that stand.
static func _spare_supply(sim: RefCounted, s: Dictionary, good: String) -> float:
	var made: float = _mined(sim, s, good)
	var taken: float = 0.0
	for b: Dictionary in s.get("buildings", []):
		if int(b.get("remaining", 0)) > 0 or not bool(b.get("enabled", true)):
			continue
		var d: Dictionary = sim.config.buildings.get(str(b.kind), {})
		if str(d.get("role", "")) == "factory" and d.get("inputs", {}).has(good):
			taken += float(d.inputs[good]) * minf(1.0, float(b.get("efficiency", 1.0)))
	for cargo: Dictionary in sim.state.shipments:
		if int(cargo.to) == int(s.region) and str(cargo.resource) == good:
			made += float(cargo.amount) / maxf(1.0, float(cargo.get("total_days", 1)))
	return maxf(0.0, made - taken)


## The export price after a month of selling `extra` more a day: saturation builds by the volume
## and decays daily (market.gd).
static func _price_after(sim: RefCounted, good: String, extra: float) -> float:
	var saturation: float = float(sim.state.market.saturation.get(good, 0.0))
	var decay: float = maxf(0.001, float(sim.market_rules.decay_per_day))
	var gained: float = extra * (1.0 - pow(1.0 - decay, HISTORY_FULL_DAYS)) / decay
	return Market.price_at(sim, good, Market.factor_at(sim, good, saturation + gained))
