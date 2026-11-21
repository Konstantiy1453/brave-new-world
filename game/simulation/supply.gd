extends RefCounted
## Supply orders (1.11): an off-world buyer's standing order for what a town grows or lands.
## - `food` (粮食供应合同): food grown by the town's farms, sent through its cargo station;
## - `catch` (渔获交付合同): fish landed by its small harbour, sent from the harbour.
## Only what the town itself grew or landed is delivered (its supply pools, `s.supply_pool`, fill as
## the farms and the harbour produce and never exceed the food in the warehouse), never below the
## residents' food reserve (stocks.gd `food_keep` or the player's food reserve), and only as far as
## the port has room. Each delivery is paid at the order's price less the port fee, the day it
## leaves: an export receipt that counts towards the charter's export goal. An order filled before
## its days run out renews larger (`growth`, up to `max_size`); one that runs out of days renews
## smaller (`lapse_factor`, never below its first size). Numbers in economy.json `supply`.

const Keys = preload("res://simulation/keys.gd")
const Stats = preload("res://simulation/stats.gd")
const Stocks = preload("res://simulation/stocks.gd")
const Consignments = preload("res://simulation/consignments.gd")

const KINDS: Array[String] = ["food", "catch"]
const POOLS: Dictionary = {"food": "farm", "catch": "catch"}
## What a source of food fills: farms and indoor farms the farm pool, the harbour the catch pool.
const SOURCES: Dictionary = {"农业生产": "farm", "近海捕捞": "catch"}
const OPEN: String = "open"
const FILLED: String = "filled"
const LAPSED: String = "lapsed"
const ENDED: String = "ended"


static func rules(sim: RefCounted) -> Dictionary:
	return sim.config.get("supply", {})


static func ensure_state(state: Dictionary) -> void:
	if not state.has("supply"):
		state.supply = {"orders": [], "next_id": 1}
	for s: Dictionary in state.get("settlements", []):
		if not s.has("supply_pool"):
			s.supply_pool = {"farm": 0.0, "catch": 0.0}


## Food grown or landed in the town goes into its pool.
static func on_produce(s: Dictionary, resource: String, amount: float, source: String) -> void:
	if resource != "food" or not SOURCES.has(source) or amount <= 0.0:
		return
	if not s.has("supply_pool"):
		s.supply_pool = {"farm": 0.0, "catch": 0.0}
	var pool: String = str(SOURCES[source])
	s.supply_pool[pool] = float(s.supply_pool.get(pool, 0.0)) + amount


## The pools never hold more than the warehouse: what was eaten or sent away leaves them in step.
static func clamp_pools(s: Dictionary) -> void:
	var pools: Dictionary = s.get("supply_pool", {})
	var total: float = float(pools.get("farm", 0.0)) + float(pools.get("catch", 0.0))
	var food: float = float(s.stock.food)
	if total <= food or total <= 0.0:
		return
	var share: float = food / total
	for key: String in ["farm", "catch"]:
		pools[key] = float(pools.get(key, 0.0)) * share


## How much the town can grow (food) or land (catch) a day at full staffing, from what stands and
## what is being built, and what one more facility of the kind would add: for offers and plans.
static func capacity(sim: RefCounted, s: Dictionary, kind: String) -> Dictionary:
	var standing: float = 0.0
	var building: float = 0.0
	for b: Dictionary in s.get("buildings", []):
		if not bool(b.get("enabled", true)):
			continue
		var role: String = str(sim.config.buildings.get(str(b.kind), {}).get("role", ""))
		var made: float = 0.0
		if kind == "food" and role in ["farm", "indoor_farm"]:
			made = float(sim.Production.farm_rate(sim, s, b))
		elif kind == "catch" and role == "harbor":
			made = sim.Production.catch_rate(sim, s, b)
		if made <= 0.0:
			continue
		if int(b.get("remaining", 0)) > 0:
			building += made
		else:
			standing += made
	return {"standing": standing, "building": building}


## What the buyer offers this town now, per kind: the order's terms, whether the town qualifies
## (`refusal`, "" when it can sign), what the town grows or lands a day, what its people eat, and
## the facilities the deliveries need.
static func offers(sim: RefCounted, s: Dictionary) -> Array:
	var rows: Array = []
	for kind: String in KINDS:
		rows.append(offer(sim, s, kind))
	return rows


static func offer(sim: RefCounted, s: Dictionary, kind: String) -> Dictionary:
	var rule: Dictionary = rules(sim).get(kind, {})
	var row: Dictionary = {
		"kind": kind,
		"name": str(rule.get("name", kind)),
		"price": float(rule.get("price", 0.0)),
		"size": float(rule.get("first_size", 0.0)),
		"days": int(rule.get("days", 0)),
		"needs": str(rule.get("needs", "")),
		"refusal": "",
		"open": {},
	}
	if s.is_empty() or rule.is_empty():
		row.refusal = "请先建立据点"
		return row
	var current: Dictionary = open_order(sim, int(s.region), kind)
	row.open = current
	var reg: Dictionary = sim.state.world.regions[int(s.region)]
	var made: Dictionary = capacity(sim, s, kind)
	row.standing = float(made.standing)
	row.building = float(made.building)
	row.eaten = float(s.population) * float(sim.config.economy.food_per_person)
	if kind == "food":
		var farms: int = 0
		for plot: Dictionary in reg.get("plots", []):
			if str(plot.get("kind", "")) == "farm":
				farms += 1
		row.plots = farms
		row.per_facility = float(sim.Production.farm_plot_rate(sim, s))
		if farms == 0:
			row.refusal = "这里没有农田地块：只能靠温室以外的方式产粮"
		elif row.per_facility * farms < float(rule.get("min_daily", 0.0)):
			row.refusal = (
				"这里的农田太贫瘠：全部种上每天也只产 %.0f t，买方不签"
				% sim.tonnes(float(row.per_facility) * farms)
			)
	else:
		row.per_facility = sim.Production.catch_rate(sim, s, {"kind": "harbor"})
		row.fishery = sim.Bay.fishery_of(sim, int(s.region))
		if not bool(reg.get("coast", false)):
			row.refusal = "内陆据点没有渔获"
		elif float(row.per_facility) < float(rule.get("min_daily", 0.0)):
			row.refusal = "这片海太贫瘠：一座小型码头每天只能捕到 %.0f t" % sim.tonnes(float(row.per_facility))
	if row.refusal == "" and not current.is_empty():
		row.refusal = "已经签了这份合同"
	return row


## The town's order of a kind that is still being filled, or an empty dictionary.
static func open_order(sim: RefCounted, region: int, kind: String) -> Dictionary:
	for order: Dictionary in sim.state.get("supply", {}).get("orders", []):
		if int(order.region) == region and str(order.kind) == kind and str(order.status) == OPEN:
			return order
	return {}


static func orders_at(sim: RefCounted, region: int) -> Array:
	var rows: Array = []
	for order: Dictionary in sim.state.get("supply", {}).get("orders", []):
		if int(order.region) == region:
			rows.append(order)
	return rows


## Signs the buyer's order at a town.
static func sign(sim: RefCounted, region: int, kind: String) -> String:
	ensure_state(sim.state)
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return "请选择已建立的据点"
	if not kind in KINDS:
		return "没有这种供货合同"
	var row: Dictionary = offer(sim, s, kind)
	if str(row.refusal) != "":
		return str(row.refusal)
	_new_order(sim, s, kind, float(row.size), 1)
	return ""


## Ends an order at once: what was delivered stays paid; nothing renews.
static func cancel(sim: RefCounted, region: int, kind: String) -> String:
	var order: Dictionary = open_order(sim, region, kind)
	if order.is_empty():
		return "这里没有在执行的这种合同"
	order.status = ENDED
	order.closed_day = int(sim.state.day)
	sim._log("%s · %s已终止，已交付的部分照常结算。" % [sim.settlement(region).name, str(order.name)])
	return ""


static func _new_order(sim: RefCounted, s: Dictionary, kind: String, size: float, round: int) -> void:
	var rule: Dictionary = rules(sim)[kind]
	var order: Dictionary = {
		"id": int(sim.state.supply.next_id),
		"kind": kind,
		"name": str(rule.name),
		"region": int(s.region),
		"round": round,
		"size": size,
		"price": float(rule.price),
		"signed_day": int(sim.state.day),
		"due_day": int(sim.state.day) + int(rule.days),
		"delivered": 0.0,
		"paid": 0.0,
		"first_day": -1,
		"status": OPEN,
	}
	sim.state.supply.next_id = int(sim.state.supply.next_id) + 1
	sim.state.supply.orders.append(order)
	sim._log(
		(
			"%s · %s第 %d 期：%d 天内交付 %.0f t，每百吨 ¥%.1f；只收本地产出，不动居民口粮。"
			% [s.name, str(rule.name), round, int(rule.days), sim.tonnes(size), float(rule.price)]
		)
	)


## What production should leave room for: food still owed on the town's open orders, so farms keep
## growing while it sells (Production.target).
static func room(sim: RefCounted, s: Dictionary, good: String) -> float:
	if good != "food":
		return 0.0
	var owed: float = 0.0
	for order: Dictionary in sim.state.get("supply", {}).get("orders", []):
		if int(order.region) == int(s.region) and str(order.status) == OPEN:
			owed += maxf(0.0, float(order.size) - float(order.delivered))
	return owed


## What the town's open orders would take of its own produce today if the warehouse allowed: the
## port imports that much more food first, so the residents' reserve stays whole while the local
## produce goes out (Logistics.trade).
static func selling_today(sim: RefCounted, s: Dictionary) -> float:
	if not sim.state.has("supply"):
		return 0.0
	clamp_pools(s)
	var total: float = 0.0
	for kind: String in KINDS:
		var order: Dictionary = open_order(sim, int(s.region), kind)
		if order.is_empty() or not _outlet_ready(sim, s, kind):
			continue
		var ready: float = float(s.get("supply_pool", {}).get(str(POOLS[kind]), 0.0))
		total += minf(ready, maxf(0.0, float(order.size) - float(order.delivered)))
	return total


## Today's deliveries from a town, after its imports and before its ordinary exports: catch first
## (fish keeps worst), then farm produce. Returns the port room left.
static func deliver(sim: RefCounted, s: Dictionary, room_left: float) -> float:
	if not sim.state.has("supply"):
		return room_left
	clamp_pools(s)
	for kind: String in ["catch", "food"]:
		var order: Dictionary = open_order(sim, int(s.region), kind)
		if order.is_empty() or room_left <= 0.0:
			continue
		if not _outlet_ready(sim, s, kind):
			continue
		var pool: String = str(POOLS[kind])
		var ready: float = float(s.supply_pool.get(pool, 0.0))
		var above: float = maxf(0.0, float(s.stock.food) - Stocks.keep(sim, s, "food"))
		var owed: float = maxf(0.0, float(order.size) - float(order.delivered))
		var amount: float = minf(minf(ready, above), minf(owed, room_left))
		if amount <= 0.0001:
			continue
		sim._consume(s, "food", amount)
		s.supply_pool[pool] = maxf(0.0, ready - amount)
		var value: float = amount * float(order.price)
		sim._transfer("external", "public", value, "supply.income", true, kind)
		sim._public_expense(
			value * float(sim.config.economy.port_fee), "supply.port_fee", "external", kind
		)
		Stats.goods(sim.state, "food", Stats.EXPORTED, amount)
		sim.state.exports_total = float(sim.state.exports_total) + value
		order.delivered = float(order.delivered) + amount
		order.paid = float(order.paid) + value
		if int(order.first_day) < 0:
			order.first_day = int(sim.state.day)
			sim._log(
				(
					"%s · %s首批交付：%.0f t，入账 ¥%.0f，计入合同出口目标。"
					% [s.name, str(order.name), sim.tonnes(amount), value]
				)
			)
		Consignments.exported(sim, s, "food", amount, value)
		record_sale(sim, s, "food", amount, value, "supply")
		room_left -= amount
	return room_left


## A catch order leaves from a working harbour; a food order from a working cargo station or harbour.
static func _outlet_ready(sim: RefCounted, s: Dictionary, kind: String) -> bool:
	for b: Dictionary in s.get("buildings", []):
		if int(b.get("remaining", 0)) > 0 or not bool(b.get("active", false)):
			continue
		var role: String = str(sim.config.buildings.get(str(b.kind), {}).get("role", ""))
		if role == "harbor" or (kind == "food" and role == "port"):
			return true
	return false


## A town's sales by day (the last 30): export receipts and supply deliveries, value and tonnage,
## so its page can show what it sold and the tests can measure one town's exports.
static func record_sale(
	sim: RefCounted, s: Dictionary, good: String, amount: float, value: float, kind: String
) -> void:
	if not s.has("sales"):
		s.sales = []
	var day: int = int(sim.state.day)
	if s.sales.is_empty() or int(s.sales.back().day) != day:
		s.sales.append({"day": day, "export": 0.0, "supply": 0.0, "local": 0.0, "goods": {}})
	var row: Dictionary = s.sales.back()
	row[kind] = float(row.get(kind, 0.0)) + value
	if good != "" and amount > 0.0:
		row.goods[good] = float(row.goods.get(good, 0.0)) + amount
	while not s.sales.is_empty() and int(s.sales[0].day) <= day - 30:
		s.sales.pop_front()


## A town's sales over the last `days` days: {export, supply, local, goods: {good: units}}. Export
## and supply receipts count towards the charter's export goal; local sales (food and shops sold to
## the residents) do not.
static func sales(s: Dictionary, today: int, days: int = 30) -> Dictionary:
	var total: Dictionary = {"export": 0.0, "supply": 0.0, "local": 0.0, "goods": {}}
	for row: Dictionary in s.get("sales", []):
		if int(row.day) <= today - days:
			continue
		total.export = float(total.export) + float(row.get("export", 0.0))
		total.supply = float(total.supply) + float(row.get("supply", 0.0))
		total.local = float(total.local) + float(row.get("local", 0.0))
		for good: String in row.get("goods", {}):
			total.goods[good] = float(total.goods.get(good, 0.0)) + float(row.goods[good])
	return total


## Once a day: an order filled renews larger, one out of days renews smaller.
static func daily(sim: RefCounted) -> void:
	if not sim.state.has("supply"):
		return
	var day: int = int(sim.state.day)
	var renew: Array = []
	for order: Dictionary in sim.state.supply.orders:
		if str(order.status) != OPEN:
			continue
		var s: Dictionary = sim.settlement(int(order.region))
		if s.is_empty():
			order.status = ENDED
			continue
		var rule: Dictionary = rules(sim).get(str(order.kind), {})
		if float(order.delivered) >= float(order.size) - 0.0001:
			order.status = FILLED
			order.closed_day = day
			var bigger: float = minf(
				float(order.size) * float(rule.growth), float(rule.get("max_size", INF))
			)
			renew.append([s, str(order.kind), bigger, int(order.round) + 1])
			sim._log(
				(
					"%s · %s第 %d 期提前交齐（%d 天），共 ¥%.0f；买方续签下一期 %.0f t。"
					% [
						s.name,
						str(order.name),
						int(order.round),
						day - int(order.signed_day),
						float(order.paid),
						sim.tonnes(bigger)
					]
				)
			)
		elif day >= int(order.due_day):
			order.status = LAPSED
			order.closed_day = day
			var smaller: float = maxf(
				float(order.size) * float(rule.get("lapse_factor", 1.0)),
				float(rule.get("first_size", 0.0))
			)
			renew.append([s, str(order.kind), smaller, int(order.round) + 1])
			sim._log(
				(
					"%s · %s第 %d 期到期：交付 %.0f / %.0f t，按实结算 ¥%.0f；下一期 %.0f t。"
					% [
						s.name,
						str(order.name),
						int(order.round),
						sim.tonnes(float(order.delivered)),
						sim.tonnes(float(order.size)),
						float(order.paid),
						sim.tonnes(smaller)
					]
				)
			)
	for entry: Array in renew:
		_new_order(sim, entry[0], str(entry[1]), float(entry[2]), int(entry[3]))
	_prune(sim)


static func _prune(sim: RefCounted) -> void:
	var keep: int = int(rules(sim).get("history", 12))
	var closed: int = 0
	var orders: Array = sim.state.supply.orders
	for index: int in range(orders.size() - 1, -1, -1):
		if str(orders[index].status) != OPEN:
			closed += 1
			if closed > keep:
				orders.remove_at(index)


## Checks for the audit: orders well formed; pools within the warehouse.
static func audit(state: Dictionary) -> Array:
	var errors: Array = []
	for order: Dictionary in state.get("supply", {}).get("orders", []):
		if float(order.get("delivered", 0.0)) < -0.0001 or float(order.get("size", 0.0)) <= 0.0:
			errors.append("supply order invalid")
		if not str(order.get("kind", "")) in KINDS:
			errors.append("supply order of an unknown kind")
	for s: Dictionary in state.get("settlements", []):
		var pools: Dictionary = s.get("supply_pool", {})
		var total: float = float(pools.get("farm", 0.0)) + float(pools.get("catch", 0.0))
		if total < -0.0001:
			errors.append("supply pool negative")
	return errors
