extends RefCounted
## Dynamic export prices. Each good has a saturation stock that rises with exports and decays
## daily: price = base * clamp(1 - depth * saturation / scale, floor, 1).

const Megaprojects = preload("res://simulation/megaprojects.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Stats = preload("res://simulation/stats.gd")
const Research = preload("res://simulation/research.gd")


static func ensure_state(state: Dictionary) -> void:
	if not state.has("market"):
		state.market = {"saturation": {}}


static func factor(sim: RefCounted, good: String) -> float:
	return factor_at(sim, good, float(sim.state.market.saturation.get(good, 0.0)))


## The price factor a good would have at this saturation: today's, or a preview of later.
static func factor_at(sim: RefCounted, good: String, saturation: float) -> float:
	var rules: Dictionary = sim.market_rules
	if not rules.scale.has(good):
		return 1.0
	var level: Dictionary = sim.progression.difficulty[sim.state.get("difficulty", "normal")]
	var depth: float = float(rules.depth) * float(level.market_depth_factor)
	var market_size: float = float(rules.scale[good]) * (1.0 + Research.bonus(sim, "market_depth"))
	return clampf(1.0 - depth * saturation / market_size, float(rules.floor), 1.0)


static func price(sim: RefCounted, good: String) -> float:
	return price_at(sim, good, factor(sim, good))


## The export price at a given market factor, with today's colony-wide bonuses.
static func price_at(sim: RefCounted, good: String, market_factor: float) -> float:
	return (
		float(sim.config.prices[good])
		* market_factor
		* Megaprojects.export_factor(sim)
		* EventsV2.colony_modifier(sim, "export_price")
		* (1.0 + Research.bonus(sim, "export_price"))
	)


static func record_export(sim: RefCounted, good: String, amount: float) -> void:
	var saturation: Dictionary = sim.state.market.saturation
	saturation[good] = float(saturation.get(good, 0.0)) + amount
	Stats.goods(sim.state, good, Stats.EXPORTED, amount)


static func daily(sim: RefCounted) -> void:
	var saturation: Dictionary = sim.state.market.saturation
	var keep: float = 1.0 - float(sim.market_rules.decay_per_day)
	for good: String in saturation:
		saturation[good] = float(saturation[good]) * keep


## Prices for display: current price, the direction the saturation is moving, the floor and
## what the price would be once another `preview_tonnes` had been sold.
static func view(sim: RefCounted) -> Array:
	var rows: Array = []
	var floor_factor: float = float(sim.market_rules.floor)
	var ahead: float = float(sim.market_rules.get("preview_tonnes", 100.0))
	for good: String in sim.market_rules.scale:
		var saturation: float = float(sim.state.market.saturation.get(good, 0.0))
		var today: float = factor_at(sim, good, saturation)
		(
			rows
			. append(
				{
					"good": good,
					"price": price_at(sim, good, today),
					"base": float(sim.config.prices[good]),
					"factor": today,
					"saturation": saturation,
					"trend": _trend(sim, good),
					"floor": floor_factor,
					"floor_price": price_at(sim, good, floor_factor),
					"at_floor": today <= floor_factor,
					"ahead_tonnes": ahead,
					"ahead_price": price_at(sim, good, factor_at(sim, good, saturation + ahead)),
				}
			)
		)
	return rows


## -1 while exports push the price down faster than the market recovers, +1 while it recovers.
static func _trend(sim: RefCounted, good: String) -> int:
	var saturation: float = float(sim.state.market.saturation.get(good, 0.0))
	if saturation < 1.0:
		return 0
	var goods_days: Array = sim.state.get("stats", {}).get("goods_days", [])
	var sold: float = 0.0
	if not goods_days.is_empty():
		sold = float(goods_days.back().get(good, [0.0, 0.0, 0.0])[Stats.EXPORTED])
	return -1 if sold > saturation * float(sim.market_rules.decay_per_day) else 1
