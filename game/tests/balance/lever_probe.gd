extends SceneTree
## The harness's labour-lever case on its own: year-2 immigration with the wage held at 1.0 and at
## 1.3, recruitment stopped, on the harness's first six seeds. Prints the median of each and the
## change. Run: godot --headless --path game --script res://tests/balance/lever_probe.gd

const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Summary = preload("res://tests/balance/summary.gd")
const SEEDS: Array[int] = [260129, 20261029, 42, 1024873270, 909386518, 7]
const DAYS: int = 360


func _initialize() -> void:
	# Tuning (1.11 J): `--set=<file>.<path>=<value>` changes a rule in this process only, e.g.
	# --set=population.attractiveness.wage_per_multiplier=3.0 (repeatable).
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--set="):
			var pair: PackedStringArray = argument.trim_prefix("--set=").split("=", true, 1)
			var path: PackedStringArray = pair[0].split(".")
			var node: Dictionary = Rules.read(path[0])
			for index: int in range(1, path.size() - 1):
				node = node[path[index]]
			node[path[path.size() - 1]] = float(pair[1])
			print("LEVER_PROBE set %s = %s" % [pair[0], pair[1]])
	var arrivals: Dictionary = {"1.0": [], "1.3": []}
	for seed_value: int in SEEDS:
		for wage: String in arrivals:
			var sim: RefCounted = Sim.new()
			sim.new_game(seed_value, "capital", 1, "normal")
			var bot: RefCounted = Bot.new()
			bot.fixed_wage = 1.0
			bot.begin(sim, seed_value)
			var before: int = 0
			for day: int in range(DAYS * 2):
				if day == DAYS:
					before = int(sim.state.immigrants_total)
					bot.recruit_batch = 0
					bot.fixed_wage = float(wage)
				bot.on_day()
				sim.tick()
				if sim.state.status == "failed":
					break
			arrivals[wage].append(int(sim.state.immigrants_total) - before)
	var base: float = Summary.median(arrivals["1.0"])
	var raised: float = Summary.median(arrivals["1.3"])
	print(
		(
			"LEVER_PROBE base=%.0f raised=%.0f change=%+.0f%% runs=%s"
			% [base, raised, (raised / maxf(1.0, base) - 1.0) * 100.0, str(arrivals)]
		)
	)
	quit(0)
