extends RefCounted
## Dynamic export prices. Each good has a saturation stock that rises with exports and decays
## daily: price = base * clamp(1 - depth * saturation / scale, floor, 1).

const Megaprojects = preload("res://simulation/megaprojects.gd")


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
	return float(sim.config.prices[good]) * factor(sim, good) * Megaprojects.export_factor(sim)


static func record_export(sim: RefCounted, good: String, amount: float) -> void:
	var saturation: Dictionary = sim.state.market.saturation
	saturation[good] = float(saturation.get(good, 0.0)) + amount


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
				}
			)
		)
	return rows
