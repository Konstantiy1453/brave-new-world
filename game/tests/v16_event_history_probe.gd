extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")


func _init() -> void:
	Watchdog.arm(self)
	var sim = load("res://simulation/sim.gd").new()
	var e = load("res://simulation/events_v2.gd")
	var error: String = sim.load_game("res://data/v16/acceptance_event_mid.json")
	if error != "":
		print(error)
		quit(2)
		return
	sim.state.events_v2.history[0].erase("definition_id")
	var result: String = e.validate(sim.state)
	print("HISTORY_MISSING_DEFINITION_REJECTED=", result != "")
	quit(0 if result != "" else 1)
