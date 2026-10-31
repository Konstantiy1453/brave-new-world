extends SceneTree
## Game speed must not change the game: the same bot through the real clock at 1×, 4× and the
## fastest speed, and with no interface at all, ends in byte-identical state.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")

const SEED_VALUE: int = 260129
const DAYS: int = 720
const FRAME: float = 1.0 / 60.0

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	var plain: PackedByteArray = _without_interface()
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var rules: Dictionary = game.sim.progression.time
	for speed: int in [1, int(rules.fast_multiplier), int(rules.very_fast_multiplier)]:
		var bytes: PackedByteArray = await _through_the_clock(game, speed)
		check(bytes == plain, "%d× ends in the same state as no interface at all" % speed)
	game.queue_free()
	print("V17_SPEED_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _without_interface() -> PackedByteArray:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED_VALUE, "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, SEED_VALUE)
	while int(sim.state.day) < DAYS and str(sim.state.status) != "failed":
		bot.on_day()
		sim.tick()
	check(int(sim.state.day) == DAYS, "the plain run lasts %d days" % DAYS)
	return var_to_bytes(sim.state)


## The bot acts once at the start of each day, exactly where the plain run does; the clock then
## decides when the next day comes.
func _through_the_clock(game: Node, speed: int) -> PackedByteArray:
	game.sim.new_game(SEED_VALUE, "capital", 1, "normal")
	game.selected = 0
	game.menu_open = false
	game.close_modal()
	game.last_status = str(game.sim.state.status)
	game.autosave_day = 0
	var bot: RefCounted = Bot.new()
	bot.begin(game.sim, SEED_VALUE)
	game.paused = false
	game.panel_pause = false
	game.set_speed(speed)
	var day: int = -1
	var frames: int = 0
	var limit: int = DAYS * 400
	while (
		int(game.sim.state.day) < DAYS and str(game.sim.state.status) != "failed" and frames < limit
	):
		frames += 1
		if int(game.sim.state.day) != day:
			day = int(game.sim.state.day)
			bot.on_day()
			game.paused = false
			game.speed = speed
			game.accumulator = 0.0
			game.close_modal()
			# The engine gets a frame each day, as in a real game, however the clock is set.
			await process_frame
		game.advance_time(FRAME)
		# Days that stop for a decision or a letter resume through the same panel a player uses.
		if game.paused:
			game.paused = false
			game.close_modal()
	await process_frame
	game._finish_autosave(false)
	check(int(game.sim.state.day) == DAYS, "%d× reaches day %d" % [speed, DAYS])
	return var_to_bytes(game.sim.state)
