extends SceneTree
## Reproduces the quantitative findings in §4 of the 1.7 brief on the 1.6 rule set.
## Run once at the baseline commit (`git switch --detach v17-phase0`); later phases change these rules.
## Output: evidence/v17/tests/findings_16.json.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Events = preload("res://simulation/events_v2.gd")
const ROAD_SEEDS: int = 40

var report: Dictionary = {}


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func run() -> void:
	report.roads_and_regions = _roads_and_regions()
	report.mines = _mines()
	report.processor = _processor()
	report.enterprise = _enterprise_preview()
	report.sandbox = _sandbox()
	report.mining_only = _mining_only()
	report.aid = _aid_terms()
	report.save_size = _save_size()
	report.definitions = _definitions()
	var path: String = "res://../evidence/v17/tests/findings_16.json"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://../evidence/v17/tests")
	)
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("FINDINGS_16 ", JSON.stringify(report))
	quit(0)


func _roads_and_regions() -> Dictionary:
	var generator: RefCounted = WorldGen.new()
	var result: Dictionary = {
		"seeds": ROAD_SEEDS,
		"mountain_always_faster": true,
		"mountain_days": [99, 0],
		"valley_days": [99, 0],
		"cost_delta_percent": [999.0, -999.0],
		"capacities": {},
		"valley_fertility": [9.0, 0.0],
		"basin_iron": [1e12, 0.0],
		"islands_reachable": 0,
	}
	for index: int in range(ROAD_SEEDS):
		var world: Dictionary = generator.generate(1000 + index * 7919)
		var valley: Dictionary = generator.route(world, 0, 1, false)
		var mountain: Dictionary = generator.route(world, 0, 1, true)
		if int(mountain.days) >= int(valley.days):
			result.mountain_always_faster = false
		result.mountain_days = _extend(result.mountain_days, int(mountain.days))
		result.valley_days = _extend(result.valley_days, int(valley.days))
		var delta: float = (float(mountain.cost) / float(valley.cost) - 1.0) * 100.0
		result.cost_delta_percent = _extend(result.cost_delta_percent, delta)
		result.capacities[str(valley.capacity) + "/" + str(mountain.capacity)] = true
		result.valley_fertility = _extend(
			result.valley_fertility, float(world.regions[1].fertility)
		)
		result.basin_iron = _extend(result.basin_iron, float(world.regions[0].deposits.ore))
		if generator.route(world, 0, 4, true).reachable:
			result.islands_reachable += 1
	return result


func _extend(pair: Array, value: float) -> Array:
	return [minf(float(pair[0]), value), maxf(float(pair[1]), value)]


func _input_value(sim: RefCounted, spec: Dictionary) -> float:
	var prices: Dictionary = sim.config.prices
	return (
		float(spec.cost)
		+ float(spec.materials) * float(prices.materials)
		+ float(spec.parts) * float(prices.parts)
	)


func _mines() -> Dictionary:
	var sim: RefCounted = Sim.new()
	var result: Dictionary = {}
	for kind: String in ["mine_ore", "mine_copper", "mine_crystal"]:
		var spec: Dictionary = sim.config.buildings[kind]
		var price: float = float(sim.config.prices[spec.output])
		var gross: float = float(spec.rate) * price * (1.0 - float(sim.config.economy.port_fee))
		result[kind] = {
			"gross_per_day_at_grade_1": gross,
			"jobs": int(spec.jobs),
			"input_value": _input_value(sim, spec),
		}
	return result


func _processor() -> Dictionary:
	var sim: RefCounted = Sim.new()
	var spec: Dictionary = sim.config.buildings.processor
	var prices: Dictionary = sim.config.prices
	var fee: float = float(sim.config.economy.port_fee)
	var income: float = 0.0
	for key: String in spec.outputs:
		income += float(spec.outputs[key]) * float(prices[key]) * (1.0 - fee)
	var inputs: float = 0.0
	for key: String in spec.inputs:
		inputs += float(spec.inputs[key]) * float(prices[key]) * (1.0 - fee)
	var wages: float = float(spec.jobs) * float(sim.config.economy.wage)
	return {
		"net_per_day_after_wages_and_upkeep": income - inputs - wages - float(spec.maintenance),
		"income": income,
		"foregone_inputs": inputs,
		"wages": wages,
		"maintenance": float(spec.maintenance),
	}


func _enterprise_preview() -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	sim.act("settle", {"region": 0})
	var capital: Dictionary = sim.enterprise_preview(0)
	var outpost_population: int = 18
	var outpost_sales: float = minf(float(outpost_population) * 0.35, 25.2)
	return {
		"capital_profit_per_day": capital.estimated_profit,
		"outpost_18_profit_per_day": outpost_sales - 6.0 * float(sim.config.economy.wage) - 5.0,
	}


func _rush_to_award(sim: RefCounted) -> void:
	for _i: int in range(240):
		var day: int = int(sim.state.day) + 1
		if day == 1:
			sim.act("settle", {"region": 0})
			sim.act("build", {"region": 0, "kind": "mine_ore"})
			sim.act("build", {"region": 0, "kind": "mine_copper"})
		if day >= 2 and sim.settlement(1).is_empty():
			sim.act("settle", {"region": 1})
		if not sim.settlement(1).is_empty() and sim.state.route.is_empty():
			sim.act("connect", {"a": 0, "b": 1, "mountain": true})
		var outpost: Dictionary = sim.settlement(1)
		if not outpost.is_empty() and int(outpost.arrival) <= 0:
			var farmed: bool = false
			for building: Dictionary in outpost.buildings:
				if building.kind == "farm":
					farmed = true
			if not farmed:
				sim.act("build", {"region": 1, "kind": "farm"})
		if day >= 15 and sim.state.enterprise.is_empty():
			sim.act("enterprise", {"region": 0})
		_first_choice(sim)
		sim.tick()
		if sim.state.status == "success":
			return


func _first_choice(sim: RefCounted) -> void:
	for node: Dictionary in Events.view(sim).pending:
		for choice: Dictionary in node.choices:
			if choice.id != "defer" and choice.enabled:
				sim.act("event_v2", {"instance_id": node.instance_id, "choice": choice.id})
				break


func _sandbox() -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	_rush_to_award(sim)
	var award_day: int = int(sim.state.day)
	var last_event_day: int = 0
	var known: int = sim.state.events_v2.seen.size()
	for _i: int in range(1500):
		_first_choice(sim)
		sim.tick()
		if sim.state.events_v2.seen.size() > known:
			known = sim.state.events_v2.seen.size()
			last_event_day = int(sim.state.day)
	var population: int = 0
	for place: Dictionary in sim.state.settlements:
		population += int(place.population)
	return {
		"award_day": award_day,
		"days_after_award": 1500,
		"cash": sim.state.cash,
		"population": population,
		"last_new_event_day": last_event_day,
		"events_seen": known,
		"company_stage": sim.state.company.stage,
	}


func _mining_only() -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	sim.act("settle", {"region": 0})
	sim.act("build", {"region": 0, "kind": "mine_ore"})
	sim.act("build", {"region": 0, "kind": "mine_copper"})
	for _i: int in range(720):
		_first_choice(sim)
		sim.tick()
		if sim.state.status == "failed":
			break
	return {"status": sim.state.status, "day": sim.state.day, "cash": sim.state.cash}


func _aid_terms() -> Dictionary:
	var sim: RefCounted = Sim.new()
	var result: Dictionary = {}
	var prices: Dictionary = sim.config.prices
	for key: String in sim.progression.company.offers:
		var offer: Dictionary = sim.progression.company.offers[key]
		var goods: float = (
			float(offer.food) * float(prices.food)
			+ float(offer.materials) * float(prices.materials)
			+ float(offer.parts) * float(prices.parts)
		)
		result[key] = {
			"value_delivered": float(offer.cash) + goods,
			"repayment": float(offer.repayment),
			"gives_more_than_it_costs": float(offer.cash) + goods > float(offer.repayment),
		}
	return result


func _save_size() -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	sim.act("settle", {"region": 0})
	var started: int = Time.get_ticks_msec()
	var error: String = sim.save_game("user://findings_size.json")
	var save_ms: int = Time.get_ticks_msec() - started
	var bytes: int = FileAccess.get_file_as_bytes("user://findings_size.json").size()
	started = Time.get_ticks_msec()
	var load_error: String = sim.load_game("user://findings_size.json")
	return {
		"bytes": bytes,
		"save_ms": save_ms,
		"load_ms": Time.get_ticks_msec() - started,
		"errors": [error, load_error],
		"grid_cells": sim.state.world.grid.size(),
	}


func _definitions() -> Dictionary:
	var definitions: Dictionary = Events.definitions().definitions
	var chains: int = 0
	var shorts: int = 0
	for key: String in definitions:
		if definitions[key].type == "short":
			shorts += 1
		else:
			chains += 1
	return {"total": definitions.size(), "short": shorts, "chain": chains}
