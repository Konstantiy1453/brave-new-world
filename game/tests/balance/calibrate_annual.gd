extends SceneTree
## Calibrates the annual report's base targets (1.11 D), as the plan asks: the balanced bot on
## normal, the three classic origins on the quick seeds, eight years each, with the report made
## neutral (no rewards, no distrust) so it changes nothing the bot does. Each year's mined minerals
## and food are filed under the contract stage the year started in; a stage's base target is 0.9 x
## the median of its years. Prints CALIBRATION lines and a JSON block for progression.json.
## `--origins=a,b` and `--seeds=x,y` narrow the runs; `--part=k/K` runs every K-th of them.

const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const SEEDS: Array[int] = [260129, 20261029, 42]
const ORIGINS: Array[String] = ["capital", "workers", "science"]
const DAYS: int = 2880
const SHARE: float = 0.9
const STAGES: int = 5


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	var origins: Array = Array(str(options.get("origins", ",".join(ORIGINS))).split(","))
	var seeds: Array = []
	for text: String in str(options.get("seeds", ",".join(SEEDS.map(str)))).split(","):
		seeds.append(int(text))
	var rule: Dictionary = Rules.read("progression").annual_report
	for key: String in ["miss_distrust", "met_reward", "exceed_reward", "exceed_trust"]:
		rule[key] = 0.0
	rule.amendment_chance = 0.0
	var part: PackedStringArray = str(options.get("part", "0/1")).split("/")
	var index: int = 0
	for origin: String in origins:
		for seed_value: int in seeds:
			if index % int(part[1]) == int(part[0]):
				_one(origin, seed_value)
			index += 1
	quit(0)


func _one(origin: String, seed_value: int) -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, origin, 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	for _day: int in range(DAYS):
		bot.on_day()
		sim.tick()
		if sim.state.status == "failed":
			break
	var start_stage: int = 1
	for entry: Dictionary in sim.state.annual.history:
		print(
			(
				"CALIBRATION origin=%s seed=%d year=%d stage=%d mining=%.1f farming=%.1f"
				% [
					origin,
					seed_value,
					int(entry.year),
					start_stage,
					float(entry.actual.mining),
					float(entry.actual.farming)
				]
			)
		)
		start_stage = int(entry.stage_after)
