extends SceneTree
## Calibrates the contract's technology goals for the 1.11 H merge: runs the balanced bot on the
## three classic contracts and the quick seeds for 3,000 days and records every technology it
## finished (day, tier, id), the stage days and the award. Run on the tree before the merge for
## the days its old counts were reached, and on the merged tree with `--no-tech-goals` (the
## contract's technology goals at 0, so they hold nothing back) for the tier milestones.
##   godot --headless --path game --script res://tests/balance/calibrate_techs.gd --
##         --out=<file.json> [--no-tech-goals] [--days=3000]

const Sim = preload("res://simulation/sim.gd")
const Balanced = preload("res://tests/balance/bots/balanced_bot.gd")
const OPENINGS: Array[String] = ["capital", "workers", "science"]
const SEEDS: Array[int] = [260129, 42, 20261029]
const GOALS: Array[String] = ["technologies", "techs_tier_1", "techs_tier_2", "techs_tier_3"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var days: int = int(options.get("days", 3000))
	var runs: Array = []
	for opening: String in OPENINGS:
		for seed_value: int in SEEDS:
			runs.append(_run(opening, seed_value, days, options.has("no-tech-goals")))
			print("CALIBRATE_TECHS %s %d done" % [opening, seed_value])
	var file: FileAccess = FileAccess.open(
		str(options.get("out", "user://techs.json")), FileAccess.WRITE
	)
	file.store_string(JSON.stringify({"runs": runs}))
	file.close()
	print("CALIBRATE_TECHS_RESULT runs=%d" % runs.size())
	quit(0)


func _run(opening: String, seed_value: int, days: int, no_goals: bool) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, opening, 1, "normal")
	if no_goals:
		for stage: Dictionary in sim.contract_rules.stages:
			for key: String in GOALS:
				if stage.goals.has(key):
					stage.goals[key] = 0
	var bot: RefCounted = Balanced.new()
	bot.begin(sim, seed_value)
	var seen: int = 0
	var techs: Array = []
	for _day: int in range(days):
		bot.on_day()
		sim.tick()
		var done: Array = sim.state.research.completed
		while seen < done.size():
			var key: String = str(done[seen])
			var spec: Dictionary = sim.config.techs.get(key, {})
			if not bool(spec.get("gift", false)):
				techs.append([int(sim.state.day), int(spec.get("tier", 0)), key])
			seen += 1
		if str(sim.state.status) == "failed":
			break
	return {
		"opening": opening,
		"seed": seed_value,
		"techs": techs,
		"stages": sim.state.contract.completed.duplicate(),
		"award":
		int(sim.state.get("success_day", -1)) if str(sim.state.status) == "success" else -1,
		"final_day": int(sim.state.day),
	}
