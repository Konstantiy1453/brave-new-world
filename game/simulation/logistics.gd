extends RefCounted
## Trade, the road network, shipments and reservations. A road joins two settlements and comes in
## three variants (valley, engineered, sea); each one dispatches surplus to deficit on its own.

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Routes = preload("res://world/routes.gd")
const Market = preload("res://simulation/market.gd")
## Port capacity goes to the most valuable tonne first.
const EXPORT_ORDER: Array[String] = ["components", "parts", "crystal", "copper", "materials", "ore"]
## Construction stock first: its need is small and stops, while food can fill a road for weeks.
const DISPATCH_ORDER: Array[String] = [
	"materials", "parts", "food", "components", "ore", "copper", "crystal"
]
const EventsV2 = preload("res://simulation/events_v2.gd")
const Stats = preload("res://simulation/stats.gd")
const HUB_FOOD_DAYS: float = 3.0
const HUNGRY_DAYS: float = 7.0
const TERMINAL_MATERIALS: float = 12.0
const MAX_SUPPLY_HOPS: int = 5


## Older saves have one `route`; it becomes the first road of the network.
static func ensure_state(state: Dictionary) -> void:
	if not state.has("roads"):
		state.roads = []
		var old: Dictionary = state.get("route", {})
		if bool(old.get("reachable", false)):
			var road: Dictionary = old.duplicate(true)
			road.id = 0
			road.variant = "engineered" if bool(old.get("mountain", false)) else "valley"
			state.roads.append(road)
	state.erase("route")
	for cargo: Dictionary in state.shipments:
		if not cargo.has("road"):
			cargo.road = -1 if bool(cargo.expedition) or state.roads.is_empty() else 0


## The route a road between two sites would take, in the number scheme of this world.
static func route_between(sim: RefCounted, a: int, b: int, variant: String) -> Dictionary:
	if str(sim.geo.version) == WorldGen.VERSION or variant == "sea":
		return Routes.find(sim.geo, a, b, variant, sim.config.roads)
	var found: Dictionary = WorldGen.new().route(sim.geo, a, b, variant == "engineered")
	found.variant = variant
	return found


## A road between these two settlements, or an empty dictionary.
static func road_between(sim: RefCounted, a: int, b: int) -> Dictionary:
	for road: Dictionary in sim.state.roads:
		if int(road.a) == a and int(road.b) == b or int(road.a) == b and int(road.b) == a:
			return road
	return {}


## What building this road would take, with the reason it cannot be built yet.
static func quote(sim: RefCounted, a: int, b: int, variant: String) -> Dictionary:
	var found: Dictionary = route_between(sim, a, b, variant)
	var refusal: String = ""
	if not found.reachable:
		refusal = str(found.get("reason", "不可达"))
	elif sim.settlement(a).is_empty() or sim.settlement(b).is_empty():
		refusal = "两端都要是已建立的据点"
	elif not road_between(sim, a, b).is_empty():
		refusal = "两地已有运输连接"
	elif variant == "sea":
		refusal = _sea_refusal(sim, a, b)
	if refusal == "" and float(sim.state.cash) < float(found.cost):
		refusal = "路线投资需要 %.0f 资金" % float(found.cost)
	if refusal == "" and _terminal_store(sim, a, b).is_empty():
		refusal = "两端仓库都没有 %.0f 建材修建装卸设施" % TERMINAL_MATERIALS
	found.refusal = refusal
	var spec: Dictionary = sim.config.roads[variant]
	found.upkeep = float(spec.upkeep)
	found.capacity = int(spec.capacity)
	found.closure_chance = float(spec.closure_chance_per_day)
	return found


## Whichever end has the materials builds the terminals: a new outpost may have none to spare.
static func _terminal_store(sim: RefCounted, a: int, b: int) -> Dictionary:
	for place: int in [a, b]:
		var s: Dictionary = sim.settlement(place)
		if float(s.stock.materials) >= TERMINAL_MATERIALS:
			return s
	return {}


static func _sea_refusal(sim: RefCounted, a: int, b: int) -> String:
	var tech: String = str(sim.config.roads.sea.tech)
	if not sim._has(tech):
		return "需要技术：" + str(sim.config.techs[tech].name)
	for place: int in [a, b]:
		if not _has_port(sim.settlement(place)):
			return "两端都需要运转的货运站"
	return ""


static func _has_port(s: Dictionary) -> bool:
	for building: Dictionary in s.buildings:
		if building.kind == "port" and int(building.remaining) <= 0:
			return true
	return false


static func connect_road(
	sim: RefCounted, a: int, b: int, mountain: bool, variant: String = ""
) -> String:
	if a == b or sim.settlement(a).is_empty() or sim.settlement(b).is_empty():
		return "请选择两个已建立的不同据点"
	var kind: String = variant if variant != "" else ("engineered" if mountain else "valley")
	if not sim.config.roads.has(kind):
		return "未知线路类型"
	var r: Dictionary = quote(sim, a, b, kind)
	if str(r.refusal) != "":
		return str(r.refusal)
	sim._transfer("public", "external", float(r.cost), "invest.road", false)
	sim._consume(_terminal_store(sim, a, b), "materials", TERMINAL_MATERIALS)
	r.erase("refusal")
	r.erase("closure_chance")
	r.id = sim.state.roads.size()
	r.blocked_until = 0
	r.sent_today = 0.0
	sim.state.roads.append(r)
	sim._log("线路已连接，单程 %d 天，每天双向合计 %.0f 吨。" % [r.days, r.capacity])
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
		if _waiting_on_closure(sim, cargo):
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


static func _waiting_on_closure(sim: RefCounted, cargo: Dictionary) -> bool:
	var road: int = int(cargo.get("road", 0))
	if bool(cargo.expedition) or road < 0 or road >= sim.state.roads.size():
		return false
	return WorldGen.road_blocked(sim.state.roads[road], int(sim.state.day))


static func incoming(sim: RefCounted, region: int, resource: String) -> float:
	var amount: float = 0.0
	for cargo in sim.state.shipments:
		if int(cargo.to) == region and str(cargo.resource) == resource:
			amount += float(cargo.amount)
	return amount


static func dispatch(sim: RefCounted) -> void:
	for r: Dictionary in sim.state.roads:
		_dispatch_road(sim, r)


static func _road_capacity(sim: RefCounted, r: Dictionary) -> float:
	var land: bool = str(r.get("variant", "valley")) != "sea"
	return (
		float(r.capacity)
		* (1.4 if land and sim._has("logistics") else 1.0)
		* EventsV2.colony_modifier(sim, "road_capacity")
	)


static func _dispatch_road(sim: RefCounted, r: Dictionary) -> void:
	r.sent_today = 0.0
	if WorldGen.road_blocked(r, int(sim.state.day)):
		return
	var cap: float = _road_capacity(sim, r)
	var spec: Dictionary = sim.config.roads[str(r.get("variant", "valley"))]
	var fee_factor: float = float(spec.get("fee_factor", 1.0))
	for resource in DISPATCH_ORDER:
		for pair in [[int(r.a), int(r.b)], [int(r.b), int(r.a)]]:
			var src: Dictionary = sim.settlement(pair[0])
			var dst: Dictionary = sim.settlement(pair[1])
			if src.arrival > 0 or dst.arrival > 0:
				continue
			# Never send back along a road what is on its way here along that same road.
			if _arriving_by(sim, int(r.id), int(src.region), resource):
				continue
			var reserve: float = float(sim.config.economy.export_reserve.get(resource, 0.0))
			var target: float = reserve
			if resource == "food":
				var eaten: float = float(src.population) * sim.config.economy.food_per_person
				reserve = eaten * (sim.state.policy.food_reserve + 1.0)
				# For a town going hungry, food on its way in counts towards the reserve, and a
				# hub keeps little more than its neighbour will have by the time this arrives:
				# that is how food passes along a chain of roads.
				if float(dst.food_days) < HUNGRY_DAYS:
					var fair_share: float = eaten * (float(dst.food_days) + float(r.days) + 1.0)
					reserve = maxf(
						eaten * HUB_FOOD_DAYS,
						minf(reserve - incoming(sim, int(src.region), "food"), fair_share)
					)
				target = (
					float(dst.population)
					* sim.config.economy.food_per_person
					* (sim.state.policy.food_reserve + float(r.days) + 2.0)
				)
				# A town with a port can buy its own: towns beyond this one that cannot come first.
				if float(dst.port_capacity) > 0.0:
					reserve += _road_demand(sim, src, resource, int(r.id))
			elif resource in ["materials", "parts"]:
				reserve = _construction_stock(sim, resource)
				target = reserve
			elif dst.port_capacity > 0:
				target = 80.0
			if resource in ["food", "materials", "parts"]:
				target += _road_demand(sim, dst, resource, int(r.id))
			var surplus: float = maxf(0.0, float(src.stock[resource]) - reserve)
			var deficit: float = maxf(
				0.0, target - float(dst.stock[resource]) - incoming(sim, int(dst.region), resource)
			)
			var amount: float = minf(cap, minf(surplus, deficit))
			var fee: float = (
				float(sim.config.economy.transport_unit_cost)
				* (0.8 if sim._has("logistics") else 1.0)
				* fee_factor
			)
			amount = minf(amount, float(sim.state.cash) / fee)
			if amount <= 0.001:
				continue
			src.stock[resource] -= amount
			Stats.goods(sim.state, resource, Stats.SHIPPED, amount)
			sim._public_expense(amount * fee, "transport.fee", "external")
			(
				sim
				. state
				. shipments
				. append(
					{
						"from": src.region,
						"to": dst.region,
						"resource": resource,
						"amount": amount,
						"remaining": int(r.days),
						"total_days": int(r.days),
						"expedition": false,
						"road": int(r.id),
					}
				)
			)
			cap -= amount
			r.sent_today += amount


static func _arriving_by(sim: RefCounted, road: int, region: int, resource: String) -> bool:
	for cargo: Dictionary in sim.state.shipments:
		if (
			int(cargo.get("road", -1)) == road
			and int(cargo.to) == region
			and str(cargo.resource) == resource
		):
			return true
	return false


static func reserved(sim: RefCounted, s: Dictionary) -> Dictionary:
	var result: Dictionary = sim._stock()
	for key in Keys.RESOURCES:
		result[key] = EventsV2.reserved(sim, int(s.region), key)
	var region: int = int(s.region)
	for r: Dictionary in sim.state.roads:
		if region != int(r.a) and region != int(r.b):
			continue
		if WorldGen.road_blocked(r, int(sim.state.day)):
			continue
		var dest: int = int(r.b) if region == int(r.a) else int(r.a)
		var dst: Dictionary = sim.settlement(dest)
		if dst.is_empty() or dst.arrival > 0:
			continue
		var cap: float = _road_capacity(sim, r)
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
			result[key] += minf(
				cap, maxf(0, target - float(dst.stock[key]) - incoming(sim, dest, key))
			)
	return result


static func view(sim: RefCounted, region: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return {}
	var coming: Dictionary = sim._stock()
	for key in Keys.RESOURCES:
		coming[key] = incoming(sim, region, key)
	return {
		"reserved": reserved(sim, s),
		"incoming": coming,
		"stock": s.stock,
		"targets": s.get("targets", {})
	}


static func road_variant(sim: RefCounted, mountain: bool) -> Dictionary:
	return sim.config.roads["engineered" if mountain else "valley"]


## Upkeep and closure risk. Rockfall closes an engineered road; cargo waits, it does not vanish.
static func road_daily(sim: RefCounted) -> void:
	for r: Dictionary in sim.state.roads:
		_road_day(sim, r)


static func closure_chance(sim: RefCounted, r: Dictionary) -> float:
	var chance: float = float(
		sim.config.roads[str(r.get("variant", "valley"))].closure_chance_per_day
	)
	if bool(r.get("paved", false)):
		chance *= float(sim.config.road_upgrade.closure)
	return chance


static func _road_day(sim: RefCounted, r: Dictionary) -> void:
	sim._public_expense(float(r.get("upkeep", 0.0)), "road.upkeep", "external")
	var rules: Dictionary = sim.config.roads[str(r.get("variant", "valley"))]
	var chance: float = closure_chance(sim, r)
	if chance <= 0.0 or WorldGen.road_blocked(r, int(sim.state.day)):
		return
	if _roll(sim) < chance:
		var low: int = int(rules.closure_days[0])
		var high: int = int(rules.closure_days[1])
		var days: int = low + int(_roll(sim) * float(high - low + 1))
		r.blocked_until = int(sim.state.day) + days
		sim._log("工程公路落石封路，预计 %d 天后恢复；在途货物原地等待。" % days)
		EventsV2.trigger(sim, "rockfall", int(r.a))


static func _roll(sim: RefCounted) -> float:
	sim.state.rng_state = (int(sim.state.rng_state) * 48271) % 2147483647
	return float(sim.state.rng_state) / 2147483647.0


static func _construction_stock(sim: RefCounted, resource: String) -> float:
	return float(sim.config.economy.construction_stock[resource])


## What the portless settlements beyond this one still need, over every road but `arrived_by`.
## A port town imports for them and a town on the way passes it along, so an outpost at the end
## of a chain can expand and eat without having to wait for a local surplus.
static func _road_demand(
	sim: RefCounted, s: Dictionary, resource: String, arrived_by: int = -1, hops: int = 0
) -> float:
	if hops >= MAX_SUPPLY_HOPS:
		return 0.0
	var region: int = int(s.region)
	var total: float = 0.0
	for r: Dictionary in sim.state.roads:
		if int(r.id) == arrived_by or (region != int(r.a) and region != int(r.b)):
			continue
		if WorldGen.road_blocked(r, int(sim.state.day)):
			continue
		var other_id: int = int(r.b) if region == int(r.a) else int(r.a)
		var other: Dictionary = sim.settlement(other_id)
		if other.is_empty() or int(other.arrival) > 0 or float(other.port_capacity) > 0.0:
			continue
		var wanted: float = 0.0
		if resource == "food":
			wanted = (
				float(other.population)
				* float(sim.config.economy.food_per_person)
				* (float(sim.state.policy.food_reserve) + float(r.days) + 2.0)
			)
		else:
			wanted = _construction_stock(sim, resource)
		wanted += _road_demand(sim, other, resource, int(r.id), hops + 1)
		total += maxf(
			0.0, wanted - float(other.stock[resource]) - incoming(sim, other_id, resource)
		)
	return total


## Buys up to the target through the port and returns the capacity left.
static func _import(
	sim: RefCounted, s: Dictionary, key: String, target: float, capacity: float
) -> float:
	# Incoming consignments count against the local target but cannot be consumed early, and
	# what is still on the road here feeds nobody further along it. Only the warehouse can.
	var stock: float = float(s.stock[key])
	var need: float = (
		maxf(0.0, target - stock - incoming(sim, int(s.region), key))
		+ maxf(0.0, _road_demand(sim, s, key) - maxf(0.0, stock - target))
	)
	var price: float = float(sim.config.prices[key]) * (1.0 + float(sim.config.economy.port_fee))
	var amount: float = minf(minf(capacity, need), maxf(0.0, float(sim.state.cash)) / price)
	if amount <= 0:
		return capacity
	if key == "food":
		sim._public_expense(amount * price, "import.food", "external")
	else:
		sim._transfer("public", "external", amount * price, "import.stock", false, key)
	sim._produce(s, key, amount, Keys.SOURCE_IMPORT)
	sim.state.imports_total += amount * price
	return capacity - amount


## Paved roads carry more, arrive sooner and close less often.
static func upgrade_road(sim: RefCounted, road: int = 0) -> String:
	if road < 0 or road >= sim.state.roads.size():
		return "还没有这条道路"
	var r: Dictionary = sim.state.roads[road]
	if str(r.get("variant", "valley")) == "sea":
		return "海运航线无需铺装"
	if bool(r.get("paved", false)):
		return "道路已经铺装"
	var rules: Dictionary = sim.config.road_upgrade
	if not sim._has(str(rules.tech)):
		return "需要技术：" + str(sim.config.techs[rules.tech].name)
	var cost: float = float(r.cost) * float(rules.cost_factor)
	if float(sim.state.cash) < cost:
		return "道路升级需要 %.0f 资金" % cost
	var s: Dictionary = sim.settlement(int(r.a))
	if float(s.stock.materials) < float(rules.materials):
		return "起点仓库需要 %.0f 建材" % float(rules.materials)
	sim._transfer("public", "external", cost, "invest.road", false, "paved")
	sim._consume(s, "materials", float(rules.materials))
	r.paved = true
	r.capacity = int(round(float(r.capacity) * float(rules.capacity)))
	r.days = maxi(1, int(r.days) + int(rules.days))
	sim._log("道路铺装完成：单程 %d 天，每天 %d 吨。" % [int(r.days), int(r.capacity)])
	return ""


## Settlements reachable from each other over open roads: the size of the largest group.
static func largest_connected(sim: RefCounted) -> int:
	var settled: Array[int] = []
	for s: Dictionary in sim.state.settlements:
		settled.append(int(s.region))
	if settled.is_empty():
		return 0
	var best: int = 1
	var seen: Dictionary = {}
	for start: int in settled:
		if seen.has(start):
			continue
		var group: Array[int] = [start]
		seen[start] = true
		var head: int = 0
		while head < group.size():
			var at: int = group[head]
			head += 1
			for r: Dictionary in sim.state.roads:
				if WorldGen.road_blocked(r, int(sim.state.day)):
					continue
				var next: int = -1
				if int(r.a) == at:
					next = int(r.b)
				elif int(r.b) == at:
					next = int(r.a)
				if next >= 0 and not seen.has(next):
					seen[next] = true
					group.append(next)
		best = maxi(best, group.size())
	return best
