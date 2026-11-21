extends SceneTree
## Seed 260129 on the 1.11 code, from 1.10.1 saves.
## --mode=advance --save=day933: the contract outlook, then "advance to the next decision" with the
##   stage as its milestone, answering only communications at each stop, until the stage changes.
## --mode=branch --save=day611 [--commission]: the balanced bot plays on (and, with --commission,
##   commissions every running project at level 2 from the first day); the outlook at the start and
##   the day stage three begins.
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Advance = preload("res://simulation/advance.gd")
var options: Dictionary = {
	"save": "", "mode": "advance", "commission": "false", "limit": "1300", "out": ""
}
var record: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	create_timer(1700.0).timeout.connect(func(): _finish("watchdog"))
	_run.call_deferred()


func _outlook(sim: RefCounted) -> Dictionary:
	var view: Dictionary = sim.outlook_view()
	var goals: Array = []
	for row: Dictionary in view.goals:
		goals.append(
			{
				"key": row.key,
				"status": row.status,
				"eta": int(row.eta),
				"value": row.value,
				"target": row.target,
				"commission": row.get("commission", {}),
				"holding": row.get("holding", "")
			}
		)
	return {
		"day": int(sim.state.day),
		"stage": int(sim.state.contract.stage),
		"eta": int(view.eta),
		"bottleneck": view.bottleneck,
		"completes_by_waiting": view.completes_by_waiting,
		"deadline": int(view.deadline),
		"goals": goals
	}


func _run() -> void:
	var sim: RefCounted = Sim.new()
	record.load = sim.load_game(str(options.save))
	record.options = options
	record.outlook_start = _outlook(sim)
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(sim.state.world.seed))
	var stage0: int = int(sim.state.contract.stage)
	if str(options.mode) == "advance":
		var stops: Array = []
		var orders: int = 0
		while int(sim.state.contract.stage) == stage0 and int(sim.state.day) < int(options.limit):
			var run: Dictionary = Advance.begin(sim, "stage")
			var reason: String = ""
			while reason == "":
				sim.tick()
				reason = Advance.stop_reason(sim, run)
			stops.append({"day": int(sim.state.day), "reason": reason})
			# The player answers what stopped the clock and nothing else.
			var before: int = bot.actions.size()
			bot.answer_events()
			orders += bot.actions.size() - before
			if sim.state.status == "failed":
				break
		record.stops = stops
		record.answers = orders
	else:
		var commission: bool = str(options.commission) == "true"
		while int(sim.state.contract.stage) == stage0 and int(sim.state.day) < int(options.limit):
			bot.on_day()
			if commission:
				for key: String in sim.state.research.projects:
					var p: Dictionary = sim.state.research.projects[key]
					if (
						int(p.staff) > 0
						and not sim.state.research.completed.has(key)
						and int(p.get("commission", 0)) < 2
					):
						sim.act("research_commission", {"tech": key, "level": 2})
			sim.tick()
			if sim.state.status == "failed":
				break
	record.stage_day = int(sim.state.day) if int(sim.state.contract.stage) != stage0 else -1
	record.final_stage = int(sim.state.contract.stage)
	_finish("done")


func _finish(why: String) -> void:
	record.finish = why
	if str(options.out) != "":
		var f: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
		f.store_string(JSON.stringify(record, "  "))
		f.close()
	printerr(
		(
			"ADVANCE_CHECK %s mode=%s eta_start=%s stage_day=%s stops=%s"
			% [
				why,
				options.mode,
				str(record.get("outlook_start", {}).get("eta", "?")),
				str(record.get("stage_day", "?")),
				str(record.get("stops", []).size())
			]
		)
	)
	quit(0)
