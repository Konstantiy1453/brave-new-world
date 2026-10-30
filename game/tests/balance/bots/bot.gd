extends RefCounted
## Base harness bot. Bots act only through Sim.act(); the harness alone calls Sim.tick().
## State is read for decisions and never written.

const EventsV2 = preload("res://simulation/events_v2.gd")

var sim: RefCounted
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var actions: Array[Dictionary] = []


func begin(sim_ref: RefCounted, run_seed: int) -> void:
	sim = sim_ref
	seed_value = run_seed
	rng.seed = run_seed


## Called once before each simulated day.
func on_day() -> void:
	pass


## A bot that has shown what it exists to show may end its run early.
func finished() -> bool:
	return false


func act(action: String, args: Dictionary = {}) -> String:
	var error: String = sim.act(action, args)
	actions.append({"day": int(sim.state.day), "action": action, "args": args, "error": error})
	return error


func today() -> int:
	return int(sim.state.day) + 1


## Takes the first enabled non-deferring option of every pending event.
func answer_events_first_option() -> void:
	for node: Dictionary in EventsV2.view(sim).pending:
		for choice: Dictionary in node.choices:
			if choice.id != "defer" and choice.enabled:
				act("event_v2", {"instance_id": node.instance_id, "choice": choice.id})
				break


## Defers every pending event, so its default applies at the deadline: this is what a
## player who ignores the event panel gets.
func defer_events() -> void:
	for node: Dictionary in EventsV2.view(sim).pending:
		if node.status == "pending":
			act("event_v2", {"instance_id": node.instance_id, "choice": "defer"})


func has_building(region: int, kind: String) -> bool:
	for building: Dictionary in sim.settlement(region).get("buildings", []):
		if building.kind == kind:
			return true
	return false


func building_count(region: int, kind: String) -> int:
	var count: int = 0
	for building: Dictionary in sim.settlement(region).get("buildings", []):
		if building.kind == kind:
			count += 1
	return count


func free_workers(region: int) -> int:
	var place: Dictionary = sim.settlement(region)
	if place.is_empty():
		return 0
	return int(place.workers) - int(place.employed_workers)


func free_beds(region: int) -> int:
	var place: Dictionary = sim.settlement(region)
	if place.is_empty():
		return 0
	return int(place.housing) - int(place.population)


## Average public operating expense over the last days, used for cash-reserve decisions.
func daily_expense() -> float:
	var history: Array = sim.state.operating_history
	var count: int = mini(10, history.size())
	if count == 0:
		return 0.0
	var total: float = 0.0
	for index: int in range(history.size() - count, history.size()):
		total += float(history[index].expense)
	return total / count
