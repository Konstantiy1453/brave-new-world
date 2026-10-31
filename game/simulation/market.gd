extends RefCounted
## Dynamic export prices. Each good has a saturation stock that rises with exports and decays
## daily: price = base * clamp(1 - depth * saturation / scale, floor, 1).

const Megaprojects = preload("res://simulation/megaprojects.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Stats = preload("res://simulation/stats.gd")


static func ensure_state(state: Dictionary) -> void:
	if not state.has("market"):
		state.market = {"saturation": {}}


static func factor(sim: RefCounted, good: String) -> float:
	var rules: Dictionary = sim.market_rules
	if not rules.scale.has(good):
		return 1.0
	var saturation: float = float(sim.state.market.saturation.get(good, 0.0))
	return clampf(
		1.0 - float(rules.depth) * saturation / float(rules.scale[good]), float(rules.floor), 1.0
	)


static func price(sim: RefCounted, good: String) -> float:
	return (
		float(sim.config.prices[good])
		* factor(sim, good)
		* Megaprojects.export_factor(sim)
		* EventsV2.colony_modifier(sim, "export_price")
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


## Prices for display: current price and the direction the saturation is moving.
static func view(sim: RefCounted) -> Array:
	var rows: Array = []
	for good: String in sim.market_rules.scale:
		(
			rows
			. append(
				{
					"good": good,
					"price": price(sim, good),
					"base": float(sim.config.prices[good]),
					"factor": factor(sim, good),
					"saturation": float(sim.state.market.saturation.get(good, 0.0)),
					"trend": _trend(sim, good),
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
