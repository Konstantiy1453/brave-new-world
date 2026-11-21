extends SceneTree
## Event pacing, measured the same way on 1.10.1 and 1.11: the balanced bot plays --days days on each
## seed; every day the new event instances (an event arriving) and every new step of an event that
## waits for the player are recorded. An arrival is "independent" when the random draw brought it,
## "set off" when something in the colony did (a rockfall on a road, a pollution outbreak). A step
## that stops the clock is a forced interruption; 1.11 can hold one back under its colony-wide cap
## (muted: it waits in the panel with more days to answer).
##   godot --headless --path <project> --script event_pacing.gd -- --seeds=1,2,3 --days=720 --out=<json>

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")

const SET_OFF: Array[String] = ["rockfall", "smog_season", "acid_rain", "dead_bay"]
const WINDOWS: Array[int] = [30, 90, 360, 720]

var options: Dictionary = {"seeds": "1,2,3,4,5,6", "days": "720", "out": ""}
var record: Dictionary = {"runs": []}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var timer: SceneTreeTimer = create_timer(3000.0)
	timer.timeout.connect(func(): _finish("watchdog"))
	_run.call_deferred()


func _run() -> void:
	record.options = options
	for text: String in str(options.seeds).split(","):
		record.runs.append(_one(int(text)))
	_finish("done")


func _one(seed_value: int) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	var seen: Dictionary = {}
	var steps: Dictionary = {}
	var arrivals: Array = []
	var stops: Array = []
	var stage_days: Dictionary = {"1": 0}
	for _day: int in range(int(options.days)):
		bot.on_day()
		sim.tick()
		var day: int = int(sim.state.day)
		var stage: int = int(sim.state.contract.stage)
		if not stage_days.has(str(stage)):
			stage_days[str(stage)] = day
		for inst: Dictionary in sim.state.get("events_v2", {}).get("instances", []):
			var id: String = str(inst.instance_id)
			if not seen.has(id):
				seen[id] = true
				(
					arrivals
					. append(
						{
							"day": int(inst.get("created_day", day)),
							"id": str(inst.definition_id),
							"stage": stage,
							"kind":
							"set_off" if str(inst.definition_id) in SET_OFF else "independent",
						}
					)
				)
			var step: String = "%s/%s" % [id, str(inst.node)]
			if str(inst.status) == "pending" and not steps.has(step):
				steps[step] = true
				var muted: bool = bool(inst.get("variables", {}).get("muted", false))
				if bool(inst.pause_required) or muted:
					(
						stops
						. append(
							{
								"day": day,
								"id": str(inst.definition_id),
								"node": str(inst.node),
								"stage": stage,
								"forced": bool(inst.pause_required),
								"muted": muted,
							}
						)
					)
		if sim.state.status == "failed":
			break
	var summary: Dictionary = {}
	for window: int in WINDOWS:
		var row: Dictionary = {"independent": 0, "set_off": 0, "forced": 0, "muted": 0}
		for a: Dictionary in arrivals:
			if int(a.day) <= window:
				row[str(a.kind)] = int(row[str(a.kind)]) + 1
		for s: Dictionary in stops:
			if int(s.day) <= window:
				row.forced = int(row.forced) + (1 if bool(s.forced) else 0)
				row.muted = int(row.muted) + (1 if bool(s.muted) else 0)
		summary[str(window)] = row
	var by_stage: Dictionary = {}
	for a: Dictionary in arrivals:
		var key: String = str(a.stage)
		if not by_stage.has(key):
			by_stage[key] = {"independent": 0, "set_off": 0, "forced": 0, "muted": 0}
		by_stage[key][str(a.kind)] = int(by_stage[key][str(a.kind)]) + 1
	for s: Dictionary in stops:
		var key: String = str(s.stage)
		if not by_stage.has(key):
			by_stage[key] = {"independent": 0, "set_off": 0, "forced": 0, "muted": 0}
		by_stage[key].forced = int(by_stage[key].forced) + (1 if bool(s.forced) else 0)
		by_stage[key].muted = int(by_stage[key].muted) + (1 if bool(s.muted) else 0)
	printerr("PACING seed=%d windows=%s" % [seed_value, JSON.stringify(summary)])
	return {
		"seed": seed_value,
		"final_day": int(sim.state.day),
		"status": str(sim.state.status),
		"stage_days": stage_days,
		"windows": summary,
		"by_stage": by_stage,
		"arrivals": arrivals,
		"stops": stops,
		"tally": sim.state.get("events_v2", {}).get("tally", {}),
	}


func _finish(why: String) -> void:
	record.finish = why
	if str(options.out) != "":
		var file: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	printerr("PACING_DONE %s" % why)
	quit(0)
