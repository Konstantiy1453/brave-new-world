extends SceneTree
## 1.10, stage three by operating routes (November 20 brief). On each seed the balanced bot plays
## until stage three is complete. Recorded each day: when each of stage three's operating goals was
## first met (towns connected, technologies, the non-mining share), when each route first worked
## (food corridor, remote mining network, coastal trade network), when every operating goal held
## at once (the last meaningful operating objective), when the contract advanced, when the colony
## reached 600 people (now an achievement), and when the rule before this change (600 people and a
## frontier town as conditions) would have let it advance. Writes
## evidence/v17/balance/stage_three_routes_<label>.json and prints a table.
##
##   godot --headless --path game --script res://tests/balance/stage_three_routes.gd -- --label=x

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const OperatingRoutes = preload("res://simulation/operating_routes.gd")
const SEEDS: Array[int] = [260129, 20261029, 42, 1024873270, 909386518, 3]
const LIMIT: int = 2520
const OLD_RULE: Dictionary = {
	"connected": 3, "frontiers": 1, "population": 600, "technologies": 14, "non_mining_share": 0.15
}
const OUT_DIR: String = "res://../evidence/v17/balance"

var label: String = "note"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
	call_deferred("run")


func run() -> void:
	var rows: Array = []
	for seed_value: int in SEEDS:
		rows.append(_play(seed_value))
	print(
		"seed        operating  advanced  routes (first day)                       600 people  old rule"
	)
	for row: Dictionary in rows:
		print(
			(
				"%-11d %-10s %-9s %-40s %-11s %s"
				% [
					int(row.seed),
					_day(int(row.all_operating)),
					_day(int(row.advanced)),
					str(row.routes),
					_day(int(row.population_600)),
					_day(int(row.old_rule)),
				]
			)
		)
	var folder: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder + "/stage_three_routes_%s.json" % label
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"label": label, "rows": rows}, "  "))
	file.close()
	print("STAGE_THREE_ROUTES_RESULT seeds=%d written=%s" % [rows.size(), path])
	quit(0)


static func _day(value: int) -> String:
	return "-" if value < 0 else str(value)


func _play(seed_value: int) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1)
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	var first: Dictionary = {"connected": -1, "technologies": -1, "non_mining_share": -1}
	var routes: Dictionary = {}
	var row: Dictionary = {
		"seed": seed_value,
		"stage2": -1,
		"all_operating": -1,
		"advanced": -1,
		"population_600": -1,
		"old_rule": -1,
		"population_at_advance": 0,
		"route_at_advance": "",
	}
	var audit_failures: int = 0
	var samples: Dictionary = {}
	while int(sim.state.day) < LIMIT:
		bot.on_day()
		sim.tick()
		if not sim.audit().is_empty():
			audit_failures += 1
		var day: int = int(sim.state.day)
		var stage: int = int(sim.state.contract.stage)
		if day % 180 == 0:
			samples[str(day)] = {
				"food_moved": OperatingRoutes.total(sim, "food_moved"),
				"remote_mined": OperatingRoutes.total(sim, "remote_mined"),
				"sea_cargo": OperatingRoutes.total(sim, "sea_cargo"),
				"mining_towns": OperatingRoutes.mining_towns(sim),
				"coastal_towns": OperatingRoutes.coastal_towns(sim),
				"local_food_share": sim.Contract.local_food_share(sim),
				"towns": sim.state.settlements.size(),
			}
		if row.stage2 < 0 and sim.state.contract.completed.has("2"):
			row.stage2 = int(sim.state.contract.completed["2"])
		if row.population_600 < 0 and sim.Contract.population_total(sim) >= 600:
			row.population_600 = day
		if row.old_rule < 0 and stage >= 3 and _meets(sim, OLD_RULE):
			row.old_rule = day
		if stage < 3:
			continue
		var all: bool = true
		for key: String in first:
			var ok: bool = (
				sim.Contract.goal_value(sim, key) >= sim.Contract.goal_target(sim, 3, key)
			)
			if ok and int(first[key]) < 0:
				first[key] = day
			all = all and ok
		for route: Dictionary in OperatingRoutes.view(sim):
			if bool(route.ok) and not routes.has(str(route.id)):
				routes[str(route.id)] = day
		all = all and OperatingRoutes.operating(sim) > 0.0
		if all and row.all_operating < 0 and row.advanced < 0:
			row.all_operating = day
		if row.advanced < 0 and sim.state.contract.completed.has("3"):
			row.advanced = int(sim.state.contract.completed["3"])
			row.population_at_advance = sim.Contract.population_total(sim)
			for route: Dictionary in OperatingRoutes.view(sim):
				if bool(route.ok):
					row.route_at_advance += str(route.id) + " "
		if row.advanced >= 0 and row.old_rule >= 0 and row.population_600 >= 0:
			break
	row.samples = samples
	row.first = first
	row.routes = routes
	row.days_played = int(sim.state.day)
	row.audit_failures = audit_failures
	return row


static func _meets(sim: RefCounted, goals: Dictionary) -> bool:
	for key: String in goals:
		if sim.Contract.goal_value(sim, key) < float(goals[key]):
			return false
	return true
