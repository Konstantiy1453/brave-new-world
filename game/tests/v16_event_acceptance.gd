extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const E = preload("res://simulation/events_v2.gd")
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
	apply(s, "settle", {"region": 0})
	for kind in ["mine_ore", "mine_copper", "lab"]:
		apply(s, "build", {"region": 0, "kind": kind})
	var captured: bool = false
	for index in range(150):
		var v: Dictionary = E.view(s)
		for p in v.pending:
			if p.id == "archaeology" and p.node == "start":
				if apply(s, "event_v2", {"instance_id": p.instance_id, "choice": "survey"}) == "":
					captured = true
			else:
				var choice: String = (
					"conserve" if p.id == "water" and p.node == "start" else "decline"
				)
				var valid: bool = false
				for o in p.choices:
					if o.id == choice and o.enabled:
						valid = true
				if not valid:
					for o in p.choices:
						if o.enabled and o.id != "defer":
							choice = o.id
							break
				apply(s, "event_v2", {"instance_id": p.instance_id, "choice": choice})
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
	var result: String = "未自然进入考古调查"
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
