extends SceneTree
## Prints one bot's run as a timeline, for tuning by hand.
## Usage: --script res://tests/balance/trace_run.gd -- --bot=balanced --seed=260129
##        --opening=capital --difficulty=normal --days=360 --every=15

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Contract = preload("res://simulation/contract.gd")
const BOTS: Dictionary = {
	"rush": preload("res://tests/balance/bots/rush_bot.gd"),
	"balanced": preload("res://tests/balance/bots/balanced_bot.gd"),
	"research_first": preload("res://tests/balance/bots/research_first_bot.gd"),
	"passive": preload("res://tests/balance/bots/passive_bot.gd"),
	"sloppy": preload("res://tests/balance/bots/sloppy_bot.gd"),
}

var options: Dictionary = {
	"bot": "balanced",
	"seed": "260129",
	"opening": "capital",
	"difficulty": "normal",
	"days": "360",
	"every": "15",
	"errors": "false",
}


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var sim: RefCounted = Sim.new()
	sim.new_game(int(options.seed), options.opening, 1, options.difficulty)
	var bot: RefCounted = BOTS[options.bot].new()
	bot.begin(sim, int(options.seed))
	var seen_errors: Dictionary = {}
	var last_stage: int = 1
	for _day: int in range(int(options.days)):
		var before: int = bot.actions.size()
		bot.on_day()
		for index: int in range(before, bot.actions.size()):
			var action: Dictionary = bot.actions[index]
			if action.error == "":
				print("  D%d %s %s" % [int(action.day), action.action, _short_args(action.args)])
			elif options.errors == "true" and not seen_errors.has(action.error):
				seen_errors[action.error] = true
				print("  D%d REFUSED %s: %s" % [int(action.day), action.action, action.error])
		sim.tick()
		if int(sim.state.contract.stage) != last_stage:
			last_stage = int(sim.state.contract.stage)
			print("== stage %d reached on day %d" % [last_stage, int(sim.state.day)])
		if int(sim.state.day) % int(options.every) == 0:
			_line(sim)
		if sim.state.status == "failed":
			print("FAILED day %d: %s" % [int(sim.state.day), sim.state.failure_reason])
			break
	_goals(sim)
	_ledger(sim)
	print("  company sources ", sim.state.company.sources)
	print("TRACE_DONE audit=", sim.audit())
	quit(0)


func _short_args(args: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in args:
		if key != "instance_id":
			parts.append("%s=%s" % [key, str(args[key])])
	return " ".join(parts)


func _line(sim: RefCounted) -> void:
	var state: Dictionary = sim.state
	var causes: PackedStringArray = []
	for key: String in state.company.sources:
		if float(state.company.sources[key].rate) > 0.0:
			causes.append("%s %.1f" % [key, float(state.company.sources[key].rate)])
	if not causes.is_empty():
		print("  risk: ", ", ".join(causes))
	var row: PackedStringArray = []
	for s: Dictionary in state.settlements:
		(
			row
			. append(
				(
					"[%d%s pop%d w%d sci%d emp%d jobs%d beds%d food%.0f att%.2f b%d]"
					% [
						int(s.region),
						str(s.kind).left(1),
						int(s.population),
						int(s.workers),
						int(s.scientists),
						int(s.employed),
						int(s.jobs),
						int(s.housing),
						float(s.food_days),
						float(s.attractiveness),
						s.buildings.size(),
					]
				)
			)
		)
	print(
		(
			"D%d stage %d cash %.0f net %+.0f inc %.0f exp %.0f debt %.0f tech %d poll %.3f co %s/%.0f %s"
			% [
				int(state.day),
				int(state.contract.stage),
				float(state.cash),
				float(state.operating_net),
				float(state.income_daily),
				float(state.expense_daily),
				float(state.debt),
				state.research.completed.size(),
				sim.Pollution.penalty(sim),
				str(state.company.stage),
				float(state.company.distrust),
				" ".join(row),
			]
		)
	)


func _goals(sim: RefCounted) -> void:
	var stage: int = int(sim.state.contract.stage)
	if stage > Contract.STAGE_COUNT:
		print("All stages complete: ", sim.state.contract.completed)
		return
	for goal: Dictionary in Contract.stage_goals(sim, stage):
		print(
			(
				"  goal %-24s %.2f / %.2f %s"
				% [goal.key, goal.value, goal.target, "ok" if goal.ok else ""]
			)
		)


## Operating money by ledger key over the last 30 days, per day.
func _ledger(sim: RefCounted) -> void:
	var income: Dictionary = {}
	var expense: Dictionary = {}
	for entry: Dictionary in sim.state.ledger:
		if int(entry.day) <= int(sim.state.day) - 30 or not bool(entry.operating):
			continue
		var key: String = str(entry.key)
		if key == "export":
			key = "export." + str(entry.detail)
		if entry.to == "public":
			income[key] = float(income.get(key, 0.0)) + float(entry.amount) / 30.0
		if entry.from == "public":
			expense[key] = float(expense.get(key, 0.0)) + float(entry.amount) / 30.0
	print("  income/day ", _sorted(income))
	print("  expense/day ", _sorted(expense))


func _sorted(values: Dictionary) -> String:
	var keys: Array = values.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return values[a] > values[b])
	var parts: PackedStringArray = []
	for key: String in keys:
		parts.append("%s %.0f" % [key, float(values[key])])
	return ", ".join(parts)
