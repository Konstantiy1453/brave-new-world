extends SceneTree
## The harness's labour-lever case on its own: year-2 immigration with the wage held at 1.0 and at
## 1.3, recruitment stopped, on the harness's first six seeds. Prints the median of each and the
## change. Run: godot --headless --path game --script res://tests/balance/lever_probe.gd

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Summary = preload("res://tests/balance/summary.gd")
const SEEDS: Array[int] = [260129, 20261029, 42, 1024873270, 909386518, 7]
const DAYS: int = 360


func _initialize() -> void:
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
