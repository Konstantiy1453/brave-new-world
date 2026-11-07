extends SceneTree
## The advisor's warning for export income leaning on mines about to run out (1.9): plays the
## balanced bot and prints, every `--every` days, the share of the last 30 days' export value from
## mines with under `mine_warning_days` of reserves, the first day the warning would show and how
## many days it showed. With `--hands-off=N` the bot stops deciding on day N and the colony runs
## on what it has, the case the warning is for; the probe then also prints the first day the
## month's income fell 20% below its best since day N. Run:
##   godot --headless --path game --script res://tests/balance/mine_probe.gd --
##       [--seeds=260129,42] [--openings=capital,workers] [--difficulty=easy] [--every=180]
##       [--hands-off=1080]

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const DAYS: int = 3600
const SAMPLE_DAYS: int = 30
const INCOME_DROP: float = 0.8


func _initialize() -> void:
	var seeds: Array[int] = [260129, 42, 20261029]
	var openings: Array[String] = ["capital", "workers"]
	var difficulty: String = "normal"
	var every: int = 180
	var hands_off: int = 0
	for argument: String in OS.get_cmdline_user_args():
		var value: String = argument.get_slice("=", 1)
		if argument.begins_with("--seeds="):
			seeds.clear()
			for part: String in value.split(","):
				seeds.append(int(part))
		elif argument.begins_with("--openings="):
			openings.clear()
			for part: String in value.split(","):
				openings.append(part)
		elif argument.begins_with("--difficulty="):
			difficulty = value
		elif argument.begins_with("--every="):
			every = maxi(SAMPLE_DAYS, int(value))
		elif argument.begins_with("--hands-off="):
			hands_off = int(value)
	for opening: String in openings:
		for seed_value: int in seeds:
			print(_play(seed_value, opening, difficulty, every, hands_off))
	quit(0)


func _play(
	seed_value: int, opening: String, difficulty: String, every: int, hands_off: int
) -> String:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, opening, 1, difficulty)
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	var samples: PackedStringArray = []
	var first_warning: int = -1
	var warned_days: int = 0
	var share_line: float = float(sim.config.economy.mine_warning_share)
	var best_income: float = 0.0
	var income_down: int = -1
	for day: int in range(1, DAYS + 1):
		if hands_off <= 0 or day <= hands_off:
			bot.on_day()
		sim.tick()
		if str(sim.state.status) == "failed":
			samples.append("failed@%d" % day)
			break
		if day % SAMPLE_DAYS != 0:
			continue
		if hands_off > 0 and day >= hands_off:
			var income: float = _mean_income(sim)
			best_income = maxf(best_income, income)
			if income_down < 0 and income < best_income * INCOME_DROP:
				income_down = day
		var share: float = float(sim.mine_outlook(sim.stats_window(SAMPLE_DAYS)).share)
		if share >= share_line:
			warned_days += SAMPLE_DAYS
			if first_warning < 0:
				first_warning = day
		if day % every == 0:
			samples.append("%d:%.0f%%" % [day, share * 100.0])
	return (
		"MINE_PROBE %s %d %s first_warning=%d warned_days=%d income_down_20pct=%d award=%d | %s"
		% [
			opening,
			seed_value,
			difficulty,
			first_warning,
			warned_days,
			income_down,
			int(sim.state.get("success_day", -1)),
			" ".join(samples)
		]
	)


## Mean daily operating income over the last month.
func _mean_income(sim: RefCounted) -> float:
	var history: Array = sim.state.operating_history
	var count: int = mini(SAMPLE_DAYS, history.size())
	var total: float = 0.0
	for index: int in range(history.size() - count, history.size()):
		total += float(history[index].income)
	return total / maxi(1, count)
