extends RefCounted
## Trade, road dispatch, shipments and reservations.

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Market = preload("res://simulation/market.gd")
## Port capacity goes to the most valuable tonne first.
const EXPORT_ORDER: Array[String] = ["parts", "crystal", "copper", "materials", "ore"]
const EventsV2 = preload("res://simulation/events_v2.gd")


static func connect_road(sim: RefCounted, a: int, b: int, mountain: bool) -> String:
	if a == b or sim.settlement(a).is_empty() or sim.settlement(b).is_empty():
		return "请选择两个已建立的不同据点"
	if not sim.state.route.is_empty():
		return "两地已有运输连接"
	var r: Dictionary = WorldGen.new().route(sim.geo, a, b, mountain)
	if not r.reachable:
		return r.get("reason", "陆路不可达")
	var s: Dictionary = sim.settlement(a)
	if sim.state.cash < r.cost:
		return "路线投资需要 %.0f 资金" % r.cost
	if s.stock.materials < 12:
		return "起点仓库需要 12 建材修建装卸设施"
	sim._transfer("public", "external", float(r.cost), "invest.road", false)
	sim._consume(s, "materials", 12.0)
	r.blocked_until = 0
	r.sent_today = 0.0
	var road_rules: Dictionary = road_variant(sim, mountain)
	r.capacity = int(road_rules.capacity)
	r.upkeep = float(road_rules.upkeep)
	sim.state.route = r
	sim._log("陆路已连接，单程 %d 天，每天双向合计 %.0f 吨。" % [r.days, r.capacity])
	return ""


static func trade(sim: RefCounted, s: Dictionary) -> void:
	var cap: float = float(s.port_capacity)
	var target_food: float = (
		float(s.population)
		* float(sim.config.economy.food_per_person)
		* (float(sim.state.policy.food_reserve) + 1.0)
	)
	# Needs before sales: food and the construction stock get first call on the port.
	cap = _import(sim, s, "food", target_food, cap)
	for key in ["materials", "parts"]:
		cap = _import(sim, s, key, _construction_stock(sim, key), cap)
	# Recurring external buyer receives real farm input through actual local port.
	for b in s.buildings:
		if b.kind != "foodworks" or not b.active:
			continue
		var d: Dictionary = sim.config.buildings.foodworks
		var keep: float = (
			float(s.population)
			* float(sim.config.economy.food_per_person)
			* (float(sim.state.policy.food_reserve) + 1)
		)
		var scale: float = minf(
			float(b.efficiency),
			minf(
				cap / float(d.food_input), maxf(0, float(s.stock.food) - keep) / float(d.food_input)
			)
		)
		if scale <= 0:
			continue
		sim._consume(s, "food", float(d.food_input) * scale)
		sim._transfer(
			"external", "public", float(d.daily_payment) * scale, "food_order.income", true
		)
		sim._public_expense(
			float(d.daily_payment) * scale * float(sim.config.economy.port_fee),
			"food_order.port_fee",
			"external"
		)
		sim.state.exports_total += float(d.daily_payment) * scale
		cap -= float(d.food_input) * scale
	# Sell only surplus after promised cross-region stock.
	for key in EXPORT_ORDER:
		var reserve: float = (
			float(sim.config.economy.export_reserve.get(key, 0.0))
			+ float(reserved(sim, s).get(key, 0.0))
		)
		var amount: float = minf(cap, maxf(0.0, float(s.stock[key]) - reserve))
		if key in ["materials", "parts"]:
			amount = minf(
				amount,
				maxf(
					0.0,
					(
						float(s.get("exportable", {}).get(key, 0.0))
						- EventsV2.reserved(sim, int(s.region), key)
					)
				)
			)
		if amount <= 0:
			continue
		var price: float = Market.price(sim, key)
		if (
			key == "copper"
			and int(sim.state.day) >= int(sim.state.effects.get("market_start", 0))
			and int(sim.state.effects.get("market_until", 0)) > int(sim.state.day)
		):
			price *= 1.35
		var revenue: float = amount * price
		Market.record_export(sim, key, amount)
		sim._consume(s, key, amount)
		sim._transfer("external", "public", revenue, "export", true, key)
		sim._public_expense(revenue * sim.config.economy.port_fee, "export.port_fee", "external")
		sim.state.exports_total += revenue
		cap -= amount
		if sim.state.exports_total == revenue:
			sim._log("第一笔出口到账：%.0f。所有进出口共用本地港口吞吐。" % revenue)
	s.port_used = float(s.port_capacity) - cap
	if float(s.port_capacity) <= 0 and s.stock.food < target_food:
		sim._short(s, Keys.SH_NO_PORT)
	if (
		float(s.port_capacity) > 0
		and cap <= 0.01
		and (
			float(s.stock.food) + incoming(sim, int(s.region), "food") < target_food
			or float(s.stock.materials) < 35
			or float(s.stock.parts) < 12
		)
	):
		sim._short(s, Keys.SH_PORT_FULL)


static func advance_shipments(sim: RefCounted) -> void:
	var keep: Array = []
	for cargo in sim.state.shipments:
		if (
			not cargo.get("expedition", false)
			and not sim.state.route.is_empty()
			and WorldGen.road_blocked(sim.state.route, int(sim.state.day))
		):
			keep.append(cargo)
			continue
		cargo.remaining -= 1
		if cargo.remaining <= 0:
			var s: Dictionary = sim.settlement(int(cargo.to))
			s.stock[cargo.resource] += float(cargo.amount)
			sim.state.transported_total += float(cargo.amount)
		else:
			keep.append(cargo)
	sim.state.shipments = keep


static func incoming(sim: RefCounted, region: int, resource: String) -> float:
	var amount: float = 0.0
	for cargo in sim.state.shipments:
		if int(cargo.to) == region and str(cargo.resource) == resource:
			amount += float(cargo.amount)
	return amount


static func dispatch(sim: RefCounted) -> void:
	if sim.state.route.is_empty():
		return
	var r: Dictionary = sim.state.route
	r.sent_today = 0.0
	if WorldGen.road_blocked(r, int(sim.state.day)):
		return
	var cap: float = float(r.capacity) * (1.4 if sim._has("logistics") else 1.0)
	for resource in ["food", "materials", "parts", "ore", "copper", "crystal"]:
		for pair in [[int(r.a), int(r.b)], [int(r.b), int(r.a)]]:
			var src: Dictionary = sim.settlement(pair[0])
			var dst: Dictionary = sim.settlement(pair[1])
			if src.arrival > 0 or dst.arrival > 0:
				continue
			var reserve: float = float(sim.config.economy.export_reserve.get(resource, 0.0))
			var target: float = reserve
			if resource == "food":
				reserve = (
					float(src.population)
					* sim.config.economy.food_per_person
					* (sim.state.policy.food_reserve + 1.0)
				)
				target = (
					float(dst.population)
					* sim.config.economy.food_per_person
					* (sim.state.policy.food_reserve + float(r.days) + 2.0)
				)
			elif resource in ["materials", "parts"]:
				reserve = _construction_stock(sim, resource)
				target = reserve
			elif dst.port_capacity > 0:
				target = 80.0
			var surplus: float = maxf(0.0, float(src.stock[resource]) - reserve)
			var deficit: float = maxf(
				0.0, target - float(dst.stock[resource]) - incoming(sim, int(dst.region), resource)
			)
			var amount: float = minf(cap, minf(surplus, deficit))
			var fee: float = (
				float(sim.config.economy.transport_unit_cost)
				* (0.8 if sim._has("logistics") else 1.0)
			)
			amount = minf(amount, float(sim.state.cash) / fee)
			if amount <= 0.001:
				continue
			src.stock[resource] -= amount
			sim._public_expense(amount * fee, "transport.fee", "external")
			sim.state.shipments.append(
				{
					"from": src.region,
					"to": dst.region,
					"resource": resource,
					"amount": amount,
					"remaining": int(r.days),
					"total_days": int(r.days),
					"expedition": false
				}
			)
			cap -= amount
			r.sent_today += amount


static func reserved(sim: RefCounted, s: Dictionary) -> Dictionary:
	var reserved: Dictionary = sim._stock()
	for key in Keys.RESOURCES:
		reserved[key] = EventsV2.reserved(sim, int(s.region), key)
	if sim.state.route.is_empty():
		return reserved
	var r: Dictionary = sim.state.route
	if WorldGen.road_blocked(r, int(sim.state.day)):
		return reserved
	var dest: int = int(r.b) if int(s.region) == int(r.a) else int(r.a)
	var dst: Dictionary = sim.settlement(dest)
	if dst.is_empty() or dst.arrival > 0:
		return reserved
	var cap: float = float(r.capacity) * (1.4 if sim._has("logistics") else 1.0)
	for key in Keys.RESOURCES:
		var target: float = float(sim.config.economy.export_reserve.get(key, 0))
		if key == "food":
			target = (
				float(dst.population)
				* float(sim.config.economy.food_per_person)
				* (float(sim.state.policy.food_reserve) + float(r.days) + 2)
			)
		elif key == "materials":
			target = 35.0
		elif key == "parts":
			target = 12.0
		elif dst.port_capacity > 0:
			target = 80.0
		reserved[key] += minf(
			cap, maxf(0, target - float(dst.stock[key]) - incoming(sim, dest, key))
		)
	return reserved


static func view(sim: RefCounted, region: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return {}
	var incoming: Dictionary = sim._stock()
	for key in Keys.RESOURCES:
		incoming[key] = incoming(sim, region, key)
	return {
		"reserved": reserved(sim, s),
		"incoming": incoming,
		"stock": s.stock,
		"targets": s.get("targets", {})
	}


static func road_variant(sim: RefCounted, mountain: bool) -> Dictionary:
	return sim.config.roads["engineered" if mountain else "valley"]


## Upkeep and closure risk. Rockfall closes an engineered road; cargo waits, it does not vanish.
static func road_daily(sim: RefCounted) -> void:
	var r: Dictionary = sim.state.route
	if r.is_empty():
		return
	sim._public_expense(float(r.get("upkeep", 0.0)), "road.upkeep", "external")
	var rules: Dictionary = road_variant(sim, bool(r.get("mountain", false)))
	var chance: float = float(rules.closure_chance_per_day)
	if chance <= 0.0 or WorldGen.road_blocked(r, int(sim.state.day)):
		return
	if _roll(sim) < chance:
		var low: int = int(rules.closure_days[0])
		var high: int = int(rules.closure_days[1])
		var days: int = low + int(_roll(sim) * float(high - low + 1))
		r.blocked_until = int(sim.state.day) + days
		sim._log("工程公路落石封路，预计 %d 天后恢复；在途货物原地等待。" % days)


static func _roll(sim: RefCounted) -> float:
	sim.state.rng_state = (int(sim.state.rng_state) * 48271) % 2147483647
	return float(sim.state.rng_state) / 2147483647.0


static func _construction_stock(sim: RefCounted, resource: String) -> float:
	return float(sim.config.economy.construction_stock[resource])


## What a settlement without its own port still needs over the road. A port town imports for it,
## so an outpost can expand and eat without having to wait for a local surplus.
static func _road_demand(sim: RefCounted, s: Dictionary, resource: String) -> float:
	var r: Dictionary = sim.state.route
	if r.is_empty() or WorldGen.road_blocked(r, int(sim.state.day)):
		return 0.0
	var region: int = int(s.region)
	if region != int(r.a) and region != int(r.b):
		return 0.0
	var other_id: int = int(r.b) if region == int(r.a) else int(r.a)
	var other: Dictionary = sim.settlement(other_id)
	if other.is_empty() or int(other.arrival) > 0 or float(other.port_capacity) > 0.0:
		return 0.0
	var wanted: float = 0.0
	if resource == "food":
		wanted = (
			float(other.population)
			* float(sim.config.economy.food_per_person)
			* (float(sim.state.policy.food_reserve) + float(r.days) + 2.0)
		)
	else:
		wanted = _construction_stock(sim, resource)
	return maxf(0.0, wanted - float(other.stock[resource]) - incoming(sim, other_id, resource))


## Buys up to the target through the port and returns the capacity left.
static func _import(
	sim: RefCounted, s: Dictionary, key: String, target: float, capacity: float
) -> float:
	# Incoming consignments count against the target but cannot be consumed early.
	var need: float = maxf(
		0.0,
		target + _road_demand(sim, s, key) - float(s.stock[key]) - incoming(sim, int(s.region), key)
	)
	var price: float = float(sim.config.prices[key]) * (1.0 + float(sim.config.economy.port_fee))
	var amount: float = minf(minf(capacity, need), maxf(0.0, float(sim.state.cash)) / price)
	if amount <= 0:
		return capacity
	if key == "food":
		sim._public_expense(amount * price, "import.food", "external")
	else:
		sim._transfer("public", "external", amount * price, "import.stock", false, key)
	sim._produce(s, key, amount, "外部进口")
	sim.state.imports_total += amount * price
	return capacity - amount
