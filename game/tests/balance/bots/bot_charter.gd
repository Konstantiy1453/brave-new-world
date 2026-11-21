extends RefCounted
## The 1.11 charter rules a winning bot follows (split from colony_bot.gd): when stage one's second
## town is worth founding, which supply orders to sign, and whether a site is too near a town.

## Stage one's second town waits for this share of the stage's export goal.
const EARLY_EXPANSION_GOAL_SHARE: float = 0.25


## Stage one allows a second town, but a sound player founds it once the first one earns: a quarter
## of the stage's export goal in, and cash for the expedition twice over besides the reserve.
static func early_expansion_ok(sim: RefCounted, reserve: float) -> bool:
	if int(sim.state.contract.stage) != 1:
		return true
	var goal: float = sim.Contract.goal_target(sim, 1, "exports_total")
	if float(sim.state.exports_total) < goal * EARLY_EXPANSION_GOAL_SHARE:
		return false
	var fare: float = sim.Sites.expedition_cash(sim, "frontier")
	return float(sim.state.cash) >= 2.0 * fare + reserve


## Supply orders: every order a town qualifies for is signed; it costs nothing and buys only what
## the town grows or lands above its residents' reserve. Returns the actions as [name, args].
static func supply_orders(sim: RefCounted) -> Array:
	var orders: Array = []
	for place: Dictionary in sim.state.settlements:
		if int(place.arrival) > 0:
			continue
		for row: Dictionary in sim.Supply.offers(sim, place):
			if str(row.refusal) == "":
				orders.append(["supply_sign", {"site": int(place.region), "kind": str(row.kind)}])
	return orders


## A site within a town's separation distance: no town can be founded there.
static func crowded(sim: RefCounted, reg: Dictionary) -> bool:
	var limit: float = float(sim.progression_geo().placement.min_separation_degrees)
	for place: Dictionary in sim.state.settlements:
		var town: Dictionary = sim.state.world.regions[int(place.region)]
		var gap: float = rad_to_deg(
			sim.WorldGen.unit_point(float(reg.lat), float(reg.lon)).angle_to(
				sim.WorldGen.unit_point(float(town.lat), float(town.lon))
			)
		)
		if gap < limit:
			return true
	return false
