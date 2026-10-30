extends "res://tests/balance/bots/bot.gd"
## A reasonable human: fixes shortages first, keeps a cash cushion, then invests in the
## best affordable option. This version targets the 1.6 rule set and is rewritten as the
## rules change (see docs/v17/PLAN.md).

const CASH_RESERVE_DAYS: float = 30.0
const HOME: int = 0
const OUTPOST: int = 1


func on_day() -> void:
	if today() == 1:
		act("settle", {"region": HOME})
		act("build", {"region": HOME, "kind": "mine_ore"})
		act("build", {"region": HOME, "kind": "mine_copper"})
	answer_events_first_option()
	if sim.state.settlements.is_empty():
		return
	var reserve: float = daily_expense() * CASH_RESERVE_DAYS
	_fix_shortages(reserve)
	_invest(reserve)


func _can_spend(kind: String, region: int, reserve: float) -> bool:
	var preview: Dictionary = sim.build_preview(region, kind)
	return not preview.is_empty() and float(sim.state.cash) >= float(preview.cost) + reserve


func _fix_shortages(reserve: float) -> void:
	for place: Dictionary in sim.state.settlements:
		var region: int = int(place.region)
		if int(place.arrival) > 0:
			continue
		if float(place.power_demand) > float(place.power_supply) and _can_spend("power", region, 0.0):
			act("build", {"region": region, "kind": "power"})
		if float(place.water_demand) > float(place.water_supply) and _can_spend("water", region, 0.0):
			act("build", {"region": region, "kind": "water"})
		if free_beds(region) < maxi(2, int(place.population) / 20):
			if _can_spend("habitat", region, reserve):
				act("build", {"region": region, "kind": "habitat"})


func _invest(reserve: float) -> void:
	var cash: float = float(sim.state.cash)
	if sim.settlement(OUTPOST).is_empty():
		if cash >= 1100.0 + reserve:
			act("settle", {"region": OUTPOST})
		return
	if sim.state.route.is_empty():
		var quote: Dictionary = sim.WorldGen.new().route(sim.state.world, HOME, OUTPOST, true)
		if cash >= float(quote.get("cost", 0.0)) + reserve:
			act("connect", {"a": HOME, "b": OUTPOST, "mountain": true})
		return
	var outpost: Dictionary = sim.settlement(OUTPOST)
	if int(outpost.arrival) <= 0:
		if building_count(OUTPOST, "farm") < 1 and _can_spend("farm", OUTPOST, reserve):
			act("build", {"region": OUTPOST, "kind": "farm"})
			return
		if free_workers(OUTPOST) >= 8 and _can_spend("farm", OUTPOST, reserve):
			if float(outpost.food_days) < 30.0:
				act("build", {"region": OUTPOST, "kind": "farm"})
				return
	if sim.state.enterprise.is_empty() and sim.state.policy.private_allowed:
		act("enterprise", {"region": HOME})
		return
	if not has_building(HOME, "processor") and free_workers(HOME) >= 10:
		if _can_spend("processor", HOME, reserve):
			act("build", {"region": HOME, "kind": "processor"})
			return
	if not has_building(HOME, "lab") and today() >= 30 and free_workers(HOME) >= 2:
		if _can_spend("lab", HOME, reserve):
			act("build", {"region": HOME, "kind": "lab"})
			return
	_staff_research()
	if free_workers(HOME) >= 10 and building_count(HOME, "mine_crystal") < 1:
		if _can_spend("mine_crystal", HOME, reserve):
			act("build", {"region": HOME, "kind": "mine_crystal"})


func _staff_research() -> void:
	if not has_building(HOME, "lab"):
		return
	var view: Dictionary = sim.research_view()
	if int(view.available) < 3:
		return
	for tech: String in ["survey", "irrigation", "logistics", "processing", "efficiency"]:
		if sim.state.research.completed.has(tech):
			continue
		if act("research_allocate", {"tech": tech, "staff": mini(10, int(view.available))}) == "":
			return
