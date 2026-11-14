extends SceneTree
## 1.9 plan A2.2: income buildings pay for themselves in a band of days, neither free money nor dead
## weight. The balanced bot plays several seeds (capital opening, normal); at days 720, 1,440 and
## 2,160 each income building's best build_forecast over all settlements is taken, and its median
## over the seeds must sit in its group's band, so one colony's path (a fresh market, an event's
## cut on the measuring day) does not decide a band. Five seeds by default, `--seeds=3` for a quicker check.
## Mines are checked in year 6 only: in years 2 and 4 fresh markets and early research make them
## faster than their band, and the opening depends on that (DECISIONS.md). Factories are checked in
## year 4, as the plan says. Prints the whole table, medians with each seed's value, for BALANCE.md.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")

## The harness's first seeds; the first DEFAULT_SEEDS of them unless `--seeds=` asks for more.
const SEEDS: Array[int] = [260129, 20261029, 42, 1024873270, 909386518]
const DEFAULT_SEEDS: int = 5
const SEEDS_ARGUMENT: String = "--seeds="
## Five six-year colonies take about five minutes.
const WATCHDOG_SECONDS: float = 1500.0
const CHECKPOINTS: Array[int] = [720, 1440, 2160]
## Band edges may be missed by this share: the same seed builds a slightly different world on
## another platform.
const TOLERANCE: float = 0.05
## [name, kinds, band in days, checkpoints that are asserted]
const GROUPS: Array = [
	["Light mines", ["mine_ore", "mine_copper", "mine_crystal"], [70, 150], [2160]],
	[
		"Heavy and automated mines",
		[
			"mine_ore_heavy",
			"mine_copper_heavy",
			"mine_crystal_heavy",
			"mine_ore_auto",
			"mine_copper_auto",
			"mine_crystal_auto"
		],
		[100, 220],
		[2160]
	],
	["Harvest buildings", ["tailings_plant", "sea_copper", "crystal_vat"], [120, 300], CHECKPOINTS],
	[
		"Factories",
		["processor", "smelter", "component_plant", "machine_works", "pharma_plant"],
		[120, 300],
		[1440]
	],
	["Foodworks", ["foodworks"], [100, 220], CHECKPOINTS],
	["Data centre and commerce", ["data_center", "commerce"], [150, 320], CHECKPOINTS],
]

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, WATCHDOG_SECONDS)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	var seeds: Array[int] = []
	for index: int in range(_seed_count()):
		seeds.append(SEEDS[index])
	var tables: Array[Dictionary] = []
	for seed_value: int in seeds:
		tables.append(_play(seed_value))
	var heading: String = "| Group | Building | Band | Year 2 | Year 4 | Year 6 |"
	var lines: PackedStringArray = [heading, "|---|---|---|---:|---:|---:|"]
	for group: Array in GROUPS:
		var band: Array = group[2]
		var low: float = float(band[0]) * (1.0 - TOLERANCE)
		var high: float = float(band[1]) * (1.0 + TOLERANCE)
		var measured: int = 0
		for kind: String in group[1]:
			var cells: PackedStringArray = []
			for day: int in CHECKPOINTS:
				var values: Array[float] = []
				for table: Dictionary in tables:
					values.append(float(table[day].get(kind, -1.0)))
				var days: float = _median(values)
				var asserted: bool = day in group[3]
				cells.append(_cell(days, values, asserted))
				if not asserted or days < 0.0:
					continue
				measured += 1
				check(
					days >= low and days <= high,
					(
						"%s pays back in %.0f days on day %d, median of %d seeds (band %d-%d)"
						% [kind, days, day, seeds.size(), int(band[0]), int(band[1])]
					)
				)
			lines.append(
				"| %s | %s | %d-%d | %s |" % [group[0], kind, band[0], band[1], " | ".join(cells)]
			)
		check(measured > 0, "%s are measured at least once" % group[0])
	print("PAYBACK_SEEDS %s" % str(seeds))
	print("PAYBACK_TABLE\n" + "\n".join(lines))
	print("V19_PAYBACK_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


## Plays one seed to the last checkpoint and returns each checkpoint's paybacks.
func _play(seed_value: int) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	var table: Dictionary = {}
	for day: int in range(1, CHECKPOINTS.back() + 1):
		bot.on_day()
		sim.tick()
		if day in CHECKPOINTS:
			table[day] = _paybacks(sim)
	check(sim.audit().is_empty(), "seed %d: the colony's ledger balances" % seed_value)
	return table


func _seed_count() -> int:
	var count: int = DEFAULT_SEEDS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEEDS_ARGUMENT):
			count = int(argument.trim_prefix(SEEDS_ARGUMENT))
	return clampi(count, 1, SEEDS.size())


## The middle of the seeds that could build the kind (-1 where none could); the mean of the two
## middle ones for an even count.
static func _median(values: Array[float]) -> float:
	var found: Array[float] = []
	for value: float in values:
		if value > 0.0:
			found.append(value)
	if found.is_empty():
		return -1.0
	found.sort()
	var middle: int = int(found.size() / 2.0)
	if found.size() % 2 == 1:
		return found[middle]
	return (found[middle - 1] + found[middle]) * 0.5


## The best payback of every income building over all settlements, or -1 where none pays.
func _paybacks(sim: RefCounted) -> Dictionary:
	var best: Dictionary = {}
	for group: Array in GROUPS:
		for kind: String in group[1]:
			var lowest: float = INF
			for s: Dictionary in sim.state.settlements:
				var forecast: Dictionary = sim.build_forecast(int(s.region), kind)
				if forecast.is_empty():
					continue
				var days: float = float(forecast.payback_days)
				if days > 0.0:
					lowest = minf(lowest, days)
			best[kind] = lowest if lowest < INF else -1.0
	return best


## A table cell: the median days, in brackets where that year is reported but not asserted, and
## each seed's value after it.
func _cell(days: float, values: Array[float], asserted: bool) -> String:
	if days < 0.0:
		return "—"
	var each: PackedStringArray = []
	for value: float in values:
		each.append("%.0f" % value if value > 0.0 else "—")
	return ("%.0f" if asserted else "(%.0f)") % days + " <sub>" + " / ".join(each) + "</sub>"
