extends SceneTree
## 1.9 plan A2.2: income buildings pay for themselves in a band of days, neither free money nor dead
## weight. The balanced bot plays seed 260129 (capital opening, normal); at days 720, 1,440 and
## 2,160 each income building's best build_forecast over all settlements must sit in its group's
## band. Mines are checked in year 6 only: in years 2 and 4 fresh markets and early research make
## them faster than their band, and the opening depends on that (DECISIONS.md). Factories are
## checked in year 4, as the plan says. Prints the whole table for BALANCE.md.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")

const SEED: int = 260129
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
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, SEED)
	var table: Dictionary = {}
	for day: int in range(1, CHECKPOINTS.back() + 1):
		bot.on_day()
		sim.tick()
		if day in CHECKPOINTS:
			table[day] = _paybacks(sim)
	check(sim.audit().is_empty(), "the colony's ledger balances")
	var lines: PackedStringArray = ["| Group | Building | Band | Year 2 | Year 4 | Year 6 |"]
	lines.append("|---|---|---|---:|---:|---:|")
	for group: Array in GROUPS:
		var band: Array = group[2]
		var low: float = float(band[0]) * (1.0 - TOLERANCE)
		var high: float = float(band[1]) * (1.0 + TOLERANCE)
		var measured: int = 0
		for kind: String in group[1]:
			var cells: PackedStringArray = []
			for day: int in CHECKPOINTS:
				var days: float = float(table[day].get(kind, -1.0))
				var asserted: bool = day in group[3]
				cells.append(_cell(days, asserted))
				if not asserted or days < 0.0:
					continue
				measured += 1
				check(
					days >= low and days <= high,
					(
						"%s pays back in %.0f days on day %d (band %d-%d)"
						% [kind, days, day, int(band[0]), int(band[1])]
					)
				)
			lines.append(
				"| %s | %s | %d-%d | %s |" % [group[0], kind, band[0], band[1], " | ".join(cells)]
			)
		check(measured > 0, "%s are measured at least once" % group[0])
	print("PAYBACK_TABLE\n" + "\n".join(lines))
	print("V19_PAYBACK_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


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


## A table cell: the days, in brackets where that year is reported but not asserted.
func _cell(days: float, asserted: bool) -> String:
	if days < 0.0:
		return "—"
	return ("%.0f" if asserted else "(%.0f)") % days
