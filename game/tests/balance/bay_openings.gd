extends SceneTree
## 1.10 the bay's first decision (plan, "What is measured: Openings" and "Stage three"). On each seed
## the balanced bot plays the same coastal start twice from a landing where its one crew goes
## first either to the mine road (the inland iron mine and its road, then copper) or to the small
## harbour (then the two mines). Recorded per game: the day of the first export and of the first
## ship, cash and import spending in the first year, the days stages two and three were met, the
## population each year, the days population took from 200 to 600 (stage three's goal) and what held
## growth meanwhile (the people page's own limit, `people_lines.gd`), and how often orders waited for
## a crew. Prints a table and writes evidence/v17/balance/bay_openings_<label>.json.
##
##   godot --headless --path game --script res://tests/balance/bay_openings.gd -- --label=x [--days=N]

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Bay = preload("res://simulation/bay.gd")
const PeopleLines = preload("res://ui/people_lines.gd")
const SEEDS: Array[int] = [260129, 20261029, 42, 1024873270, 909386518]
const OPENINGS: Array[String] = ["mine_road", "harbour"]
const DEFAULT_DAYS: int = 2160
const SIZE_MEDIUM: int = 1
const MONEY_WINDOW: int = 90
const YEAR: int = 360
const OUT_DIR: String = "res://../evidence/v17/balance"

var label: String = "note"
var days: int = DEFAULT_DAYS


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
		elif argument.begins_with("--days="):
			days = int(argument.trim_prefix("--days="))
	call_deferred("run")


func run() -> void:
	var rows: Array = []
	for seed_value: int in SEEDS:
		for opening: String in OPENINGS:
			var row: Dictionary = _play(seed_value, opening)
			if not row.is_empty():
				rows.append(row)
				print("BAY_OPENING " + JSON.stringify(row))
	_table(rows)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path: String = "%s/bay_openings_%s.json" % [OUT_DIR, label]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"label": label, "days": days, "rows": rows}, "  "))
	file.close()
	print("BAY_OPENINGS_DONE rows=%d %s" % [rows.size(), ProjectSettings.globalize_path(path)])
	quit(0)


## The best-looking coastal start: among the starts with a farming partner, else any coastal site
## with iron ore.
func _bay_site(sim: RefCounted) -> int:
	var best: int = -1
	var best_score: float = -INF
	for pair: Array in sim.geo.get("playability", {}).get("pairs", []):
		var region: int = int(pair[0])
		if not bool(sim.state.world.regions[region].get("coast", false)):
			continue
		var score: float = float(sim.Sites.start_score(sim, region))
		if score > best_score:
			best_score = score
			best = region
	if best >= 0:
		return best
	for reg: Dictionary in sim.state.world.regions:
		if not bool(reg.get("coast", false)) or float(reg.get("deposits", {}).get("ore", 0)) <= 0:
			continue
		var score: float = float(sim.Sites.start_score(sim, int(reg.id)))
		if score > best_score:
			best_score = score
			best = int(reg.id)
	return best


func _play(seed_value: int, opening: String) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", SIZE_MEDIUM, "normal")
	var site: int = _bay_site(sim)
	if site < 0:
		return {}
	sim.act("settle", {"site": site})
	if opening == "harbour":
		sim.act("build", {"site": site, "kind": "harbor"})
	sim.act("build", {"site": site, "kind": "mine_ore"})
	sim.act("build", {"site": site, "kind": "mine_copper"})
	var bot: RefCounted = Bot.new()
	bot.begin(sim, seed_value)
	var row: Dictionary = {
		"seed": seed_value,
		"opening": opening,
		"site": site,
		"mine_road_days": int(sim.Production.build_preview(sim, site, "mine_ore").haul.days),
		"first_export": -1,
		"first_ship": -1,
		"stages": {},
		"cash": {},
		"imports_year1": 0.0,
		"food_imports_year1": 0.0,
		"population": {},
		"pop200": -1,
		"pop600": -1,
		"limits": {},
		"crew_wait_days": 0,
		"crew_wait_orders": 0,
		"crews_end": 0,
		"status": "",
	}
	var stage: int = int(sim.state.contract.stage)
	for _day: int in range(days):
		bot.on_day()
		sim.tick()
		_sample(sim, site, row)
		if int(sim.state.contract.stage) != stage:
			stage = int(sim.state.contract.stage)
			row.stages[str(stage)] = int(sim.state.day)
		if sim.state.status == "failed":
			break
	row.status = str(sim.state.status)
	row.crews_end = sim.state.crews.teams.size()
	row.final_day = int(sim.state.day)
	return row


func _sample(sim: RefCounted, site: int, row: Dictionary) -> void:
	var day: int = int(sim.state.day)
	var home: Dictionary = sim.settlement(site)
	if int(row.first_export) < 0 and float(sim.state.exports_total) > 0.0:
		row.first_export = day
	if int(row.first_ship) < 0 and Bay.harbor_working(sim, home):
		row.first_ship = day
	if day in [90, 180, YEAR, 2 * YEAR]:
		row.cash[str(day)] = roundf(float(sim.state.cash))
	if day <= YEAR and day % MONEY_WINDOW == 0:
		var window: Dictionary = sim.stats_window(MONEY_WINDOW)
		for key: String in window.get("expense", {}):
			if str(key).begins_with("import"):
				row.imports_year1 = float(row.imports_year1) + float(window.expense[key])
			if str(key) == "import.food":
				row.food_imports_year1 = float(row.food_imports_year1) + float(window.expense[key])
	var people: int = int(sim.Contract.population_total(sim))
	if day % YEAR == 0:
		row.population[str(day)] = people
	if int(row.pop200) < 0 and people >= 200:
		row.pop200 = day
	if int(row.pop600) < 0 and people >= 600:
		row.pop600 = day
	var waiting: int = 0
	for names: Array in sim.Crews.view(sim).waiting.values():
		waiting += names.size()
	if waiting > 0:
		row.crew_wait_days = int(row.crew_wait_days) + 1
		row.crew_wait_orders = int(row.crew_wait_orders) + waiting
	# What held growth while the colony grew from 200 towards 600: the capital's own limit.
	if int(row.pop200) >= 0 and int(row.pop600) < 0:
		var key: String = str(PeopleLines.limit(sim, home, sim.population_view(site)).key)
		row.limits[key] = int(row.limits.get(key, 0)) + 1


func _table(rows: Array) -> void:
	print(
		(
			"| Seed | Opening | Site | Road days | First export | First ship | Cash d180 "
			+ "| Imports yr1 | Stage 2 | Stage 3 | 200→600 | Main limit | Crew waits | Crews | Status |"
		)
	)
	print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---|")
	for row: Dictionary in rows:
		var main: String = "—"
		var most: int = 0
		var total: int = 0
		for key: String in row.limits:
			total += int(row.limits[key])
			if int(row.limits[key]) > most:
				most = int(row.limits[key])
				main = key
		if total > 0:
			main = "%s %d%%" % [main, roundi(100.0 * most / total)]
		var span: String = "—"
		if int(row.pop600) >= 0 and int(row.pop200) >= 0:
			span = str(int(row.pop600) - int(row.pop200))
		print(
			(
				"| %d | %s | %d | %d | %s | %s | %s | %.0f | %s | %s | %s | %s | %d%% | %d | %s |"
				% [
					int(row.seed),
					str(row.opening),
					int(row.site),
					int(row.mine_road_days),
					_day(int(row.first_export)),
					_day(int(row.first_ship)),
					str(row.cash.get("180", "—")),
					float(row.imports_year1),
					_day(int(row.stages.get("2", -1))),
					_day(int(row.stages.get("4", -1))),
					span,
					main,
					roundi(100.0 * float(row.crew_wait_days) / maxf(1.0, float(row.final_day))),
					int(row.crews_end),
					str(row.status),
				]
			)
		)


func _day(value: int) -> String:
	return "—" if value < 0 else str(value)
