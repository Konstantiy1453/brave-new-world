extends SceneTree
## Writes the capture suite's saves to data/v17/acceptance_*.save by playing them with the harness
## bots, so they always follow the current rules. Run by hand after a rule or save schema change:
## godot --headless --path game --script res://tests/make_fixtures_v17.gd
## Options: --out=<folder> writes them elsewhere (the recorded ones stay as they are; on Linux the
## world hash differs, so captures there need their own), --only=midgame,governor writes some.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const BalancedBot = preload("res://tests/balance/bots/balanced_bot.gd")
const SloppyBot = preload("res://tests/balance/bots/sloppy_bot.gd")
const FOLDER: String = "res://data/v17/"
const SEED_VALUE: int = 260129
const MAX_DAYS: int = 3300

var folder: String = FOLDER
var only: Array = []


func _initialize() -> void:
	Watchdog.arm(self)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			folder = argument.trim_prefix("--out=").trim_suffix("/") + "/"
		if argument.begins_with("--only="):
			only = Array(argument.trim_prefix("--only=").split(",", false))
	var errors: int = 0
	errors += _write("early", BalancedBot, _reached_day.bind(40))
	errors += _write("midgame", BalancedBot, _reached_day.bind(900))
	errors += _write("event", BalancedBot, _pending_decision)
	errors += _write("crisis", SloppyBot, _under_review)
	errors += _write("governor", BalancedBot, _governor_for.bind(120))
	errors += _write("late", BalancedBot, _reached_day.bind(2200))
	print("V17_FIXTURES_RESULT errors=%d" % errors)
	quit(0 if errors == 0 else 1)


func _write(id: String, script: GDScript, done: Callable) -> int:
	if not only.is_empty() and not only.has(id):
		return 0
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED_VALUE, "capital", 1, "normal")
	var bot: RefCounted = script.new()
	bot.begin(sim, SEED_VALUE)
	while int(sim.state.day) < MAX_DAYS and not bool(done.call(sim)):
		bot.on_day()
		sim.tick()
	var path: String = folder + "acceptance_" + id + ".save"
	var error: String = sim.save_game(ProjectSettings.globalize_path(path))
	print("%s day %d stage %d: %s" % [id, sim.state.day, sim.state.contract.stage, error])
	if not bool(done.call(sim)):
		print("FAIL %s never reached its moment" % id)
		return 1
	return 0 if error == "" else 1


func _reached_day(sim: RefCounted, day: int) -> bool:
	return int(sim.state.day) >= day


func _pending_decision(sim: RefCounted) -> bool:
	return int(sim.state.day) >= 120 and not EventsV2.view(sim).pending.is_empty()


func _under_review(sim: RefCounted) -> bool:
	return str(sim.state.company.stage) in ["review", "intervention"]


func _governor_for(sim: RefCounted, days: int) -> bool:
	return (
		str(sim.state.status) == "success"
		and int(sim.state.day) >= int(sim.state.success_day) + days
	)
