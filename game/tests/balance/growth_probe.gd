extends SceneTree
## 1.11 J: what holds a colony's growth from 200 to 600 people (the 1.10 miss: jobs, in every
## game). The balanced bot on the standard contract and the lever probe's six seeds; for each run,
## the days from 200 to 600 people and, each day meanwhile, the capital's main limit as the people
## page names it (`people_lines.gd`), with the capital's mean jobless share. `--set=<file>.<path>=
## <value>` changes a rule for this run (`tests/support/rule_overrides.gd`); `--origin=<id>` picks the
## origin (default capital).
##   godot --headless --path game --script res://tests/balance/growth_probe.gd -- [--set=...]

const RuleOverrides = preload("res://tests/support/rule_overrides.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const PeopleLines = preload("res://ui/people_lines.gd")
const SEEDS: Array[int] = [260129, 20261029, 42, 1024873270, 909386518, 7]
const LAST_DAY: int = 2160
const FROM_PEOPLE: int = 200
const TO_PEOPLE: int = 600


func _initialize() -> void:
	var origin: String = "capital"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--origin="):
			origin = argument.trim_prefix("--origin=")
	for line: String in RuleOverrides.apply(OS.get_cmdline_user_args()):
		print("GROWTH_PROBE set " + line)
	var totals: Dictionary = {}
	var spans: Array = []
	var jobs_main: int = 0
	for seed_value: int in SEEDS:
		var row: Dictionary = _run(seed_value, origin)
		for key: String in row.limits:
			totals[key] = int(totals.get(key, 0)) + int(row.limits[key])
		if int(row.span) >= 0:
			spans.append(int(row.span))
		if str(row.main) == "jobs":
			jobs_main += 1
		print(
			(
				"GROWTH_PROBE_RUN seed=%d from=%d to=%d main=%s limits=%s jobless=%.2f"
				% [
					seed_value,
					int(row.from),
					int(row.to),
					str(row.main),
					str(row.limits),
					float(row.jobless)
				]
			)
		)
	var all_days: int = 0
	for key: String in totals:
		all_days += int(totals[key])
	var shares: PackedStringArray = []
	for key: String in totals:
		shares.append("%s %d%%" % [key, roundi(100.0 * int(totals[key]) / maxi(1, all_days))])
	spans.sort()
	print(
		(
			"GROWTH_PROBE origin=%s span_median=%s jobs_main_runs=%d/%d shares=%s"
			% [
				origin,
				str(spans[spans.size() / 2]) if not spans.is_empty() else "-",
				jobs_main,
				SEEDS.size(),
				", ".join(shares)
			]
		)
	)
	quit(0)


func _run(seed_value: int, origin: String) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, origin, 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	var row: Dictionary = {"from": -1, "to": -1, "span": -1, "limits": {}, "main": "-"}
	var jobless_sum: float = 0.0
	var jobless_days: int = 0
	for _day: int in range(LAST_DAY):
		bot.on_day()
		sim.tick()
		if str(sim.state.status) == "failed" or sim.state.settlements.is_empty():
			break
		var day: int = int(sim.state.day)
		var people: int = int(sim.Contract.population_total(sim))
		if int(row.from) < 0 and people >= FROM_PEOPLE:
			row.from = day
		if int(row.to) < 0 and people >= TO_PEOPLE:
			row.to = day
			break
		if int(row.from) < 0:
			continue
		var home: Dictionary = sim.state.settlements[0]
		var view: Dictionary = sim.population_view(int(home.region))
		var key: String = str(PeopleLines.limit(sim, home, view).key)
		row.limits[key] = int(row.limits.get(key, 0)) + 1
		var adults: int = maxi(1, int(home.workers) + int(home.scientists))
		jobless_sum += float(maxi(0, adults - int(home.employed))) / adults
		jobless_days += 1
	if int(row.from) >= 0 and int(row.to) >= 0:
		row.span = int(row.to) - int(row.from)
	var most: int = 0
	for key: String in row.limits:
		if int(row.limits[key]) > most:
			most = int(row.limits[key])
			row.main = key
	row.jobless = jobless_sum / maxi(1, jobless_days)
	return row
