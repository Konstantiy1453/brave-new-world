extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const E = preload("res://simulation/events_v2.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const LONGEST_WAIT: int = 2400
var actions: Array = []


func apply(s, action: String, args: Dictionary) -> String:
	var error: String = s.act(action, args)
	actions.append(
		{"day": s.state.day, "action": action, "args": args.duplicate(true), "error": error}
	)
	return error


func _init() -> void:
	Watchdog.arm(self)
	var s = Sim.new()
	s.new_game(20261029, "science", 1, "normal")
	actions.append(
		{"action": "new_game", "seed": 20261029, "advantage": "science", "difficulty": "normal"}
	)
	# A governor plays on; the first chain that comes up by itself is answered and saved mid-story.
	var bot: RefCounted = Bot.new()
	bot.begin(s, 20261029)
	var rules: Dictionary = E.definitions().definitions
	var captured: bool = false
	for index in range(LONGEST_WAIT):
		var v: Dictionary = E.view(s)
		for p in v.pending:
			if str(rules[p.id].type) != "chain" or p.node != "start":
				continue
			for option: Dictionary in rules[p.id].nodes.start.choices:
				var open: bool = false
				for row in p.choices:
					open = open or (row.id == option.id and row.enabled)
				if open and option.has("next") and not captured:
					var picked: Dictionary = {"instance_id": p.instance_id, "choice": option.id}
					captured = apply(s, "event_v2", picked) == ""
		if captured:
			break
		bot.on_day()
		s.tick()
		actions.append(
			{"action": "tick", "day": s.state.day, "status": s.state.status, "audit": s.audit()}
		)
		if captured or s.state.status == "failed":
			break
	# Shipped fixtures change only under an explicit --fixtures flag.
	var fixture_path: String = (
		"res://data/v16/acceptance_event_mid.json"
		if OS.get_cmdline_user_args().has("--fixtures")
		else "user://acceptance_event_mid.json"
	)
	var result: String = "没有事件链自然出现"
	if captured:
		result = s.save_game(fixture_path)
	var saved_day: int = int(s.state.day)
	var record: Dictionary = {
		"kind": "automated formal-action scenario; no event or result injection",
		"captured": captured,
		"day": saved_day,
		"save_error": result,
		"events": E.view(s),
		"actions": actions
	}
	var restored = Sim.new()
	var load_error: String = restored.load_game(fixture_path) if result == "" else "未保存"
	var continued: bool = false
	if load_error == "":
		s.tick()
		restored.tick()
		continued = JSON.stringify(s.state) == JSON.stringify(restored.state)
	record.load_error = load_error
	record.next_day_identical = continued
	(
		FileAccess
		. open("res://../evidence/v17/tests/event_acceptance_actions.json", FileAccess.WRITE)
		. store_string(JSON.stringify(record, "  "))
	)
	print(
		"EVENT_ACCEPTANCE captured=",
		captured,
		" saved_day=",
		saved_day,
		" save_error=",
		result,
		" load_error=",
		load_error,
		" next_day_identical=",
		continued,
		" audit=",
		s.audit()
	)
	quit(
		(
			0
			if captured and result == "" and load_error == "" and continued and s.audit().is_empty()
			else 1
		)
	)
