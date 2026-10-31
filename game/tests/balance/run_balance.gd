extends SceneTree
## Balance harness. --quick: 3 seeds, standard, 3 openings. --full: 10 seeds, 3 openings,
## 3 difficulties, 9 years. Writes evidence/v17/balance/<timestamp>.json and refreshes the
## results table in docs/v17/BALANCE.md (skip with --no-doc).

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Metrics = preload("res://tests/balance/metrics.gd")
const Summary = preload("res://tests/balance/summary.gd")
const BOTS: Dictionary = {
	"rush": preload("res://tests/balance/bots/rush_bot.gd"),
	"balanced": preload("res://tests/balance/bots/balanced_bot.gd"),
	"research_first": preload("res://tests/balance/bots/research_first_bot.gd"),
	"passive": preload("res://tests/balance/bots/passive_bot.gd"),
	"sloppy": preload("res://tests/balance/bots/sloppy_bot.gd"),
	"random_legal": preload("res://tests/balance/bots/random_legal_bot.gd"),
}
const SEEDS: Array[int] = [
	260129,
	20261029,
	42,
	1024873270,
	909386518,
	7,
	1234,
	99991,
	314159,
	271828,
	161803,
	577215,
	8675309,
	5550123,
	1999,
	2048,
	65537,
	424242,
	1000003,
	73939133,
]
const OPENINGS: Array[String] = ["capital", "workers", "science"]
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const SIZE_MEDIUM: int = 1
const DEFAULT_DAYS: int = 3600
const FUZZ_DAYS: int = 720
const QUICK_SEEDS: int = 3
const FULL_SEEDS: int = 10
const QUICK_FUZZ_RUNS: int = 3
const FULL_FUZZ_RUNS: int = 30
const LEVER_SEEDS: int = 3
const OUT_DIR: String = "res://../evidence/v17/balance"
const DOC_PATH: String = "res://../docs/v17/BALANCE.md"
const RESULTS_BEGIN: String = "<!-- results:begin -->"
const RESULTS_END: String = "<!-- results:end -->"
const HISTORY_BEGIN: String = "<!-- history:begin -->"
const POLL_SECONDS: float = 0.5
const LEVER_DAYS: int = 360
const DETERMINISM_DAYS: int = 2880
const GEOGRAPHY_SEEDS: int = 200

var options: Dictionary = {}
var shards_lost: int = 0


func _initialize() -> void:
	Watchdog.arm(self, 14400.0)
	call_deferred("run")


func run() -> void:
	options = _parse_options()
	var cases: Array = _build_cases()
	if options.has("shard"):
		_run_shard(cases)
		return
	var started: int = Time.get_ticks_msec()
	var runs: Array = []
	if int(options.get("jobs", 1)) > 1:
		runs = await _run_parallel()
	else:
		for index: int in range(cases.size()):
			runs.append(_run_case(cases[index], false))
	var extras: Dictionary = {
		"determinism": _determinism_check(),
		"labour_lever": _labour_lever(),
		"no_control": _no_pollution_control(),
	}
	if options.mode == "full":
		extras.geography = _geography()
	_publish(runs, extras, (Time.get_ticks_msec() - started) / 1000.0)


func _parse_options() -> Dictionary:
	var parsed: Dictionary = {"mode": "quick", "jobs": 8, "doc": true, "label": "unlabelled"}
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--quick":
			parsed.mode = "quick"
		elif argument == "--full":
			parsed.mode = "full"
		elif argument == "--no-doc":
			parsed.doc = false
		elif argument.begins_with("--"):
			var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
			parsed[parts[0]] = parts[1] if parts.size() > 1 else "true"
	parsed.jobs = int(parsed.jobs)
	return parsed


func _list_option(key: String, fallback: Array) -> Array:
	if not options.has(key):
		return fallback
	return Array(str(options[key]).split(","))


func _build_cases() -> Array:
	var quick: bool = options.mode == "quick"
	var seed_pool: Array = SEEDS.slice(0, QUICK_SEEDS if quick else FULL_SEEDS)
	if options.has("seeds"):
		seed_pool = []
		for text: String in str(options.seeds).split(","):
			seed_pool.append(int(text))
	var difficulties: Array = _list_option("difficulties", ["normal"] if quick else DIFFICULTIES)
	var openings: Array = _list_option("openings", OPENINGS)
	var bots: Array = _list_option(
		"bots", ["rush", "balanced", "research_first", "passive", "sloppy"]
	)
	var days: int = int(options.get("days", DEFAULT_DAYS))
	var cases: Array = []
	for bot: String in bots:
		for difficulty: String in difficulties:
			for opening: String in openings:
				for seed_value: int in seed_pool:
					(
						cases
						. append(
							{
								"bot": bot,
								"seed": seed_value,
								"opening": opening,
								"difficulty": difficulty,
								"days": days,
							}
						)
					)
	if not options.has("bots"):
		var fuzz_runs: int = QUICK_FUZZ_RUNS if quick else FULL_FUZZ_RUNS
		for index: int in range(fuzz_runs):
			(
				cases
				. append(
					{
						"bot": "random_legal",
						"seed": SEEDS[index % SEEDS.size()] + index,
						"opening": OPENINGS[index % OPENINGS.size()],
						"difficulty": DIFFICULTIES[index % DIFFICULTIES.size()],
						"days": mini(days, FUZZ_DAYS),
					}
				)
			)
	return cases


func _run_case(case_info: Dictionary, keep_bot: bool) -> Dictionary:
	var sim: RefCounted = Sim.new()
	sim.new_game(case_info.seed, case_info.opening, SIZE_MEDIUM, case_info.difficulty)
	var bot: RefCounted = BOTS[case_info.bot].new()
	bot.begin(sim, int(case_info.seed))
	var metrics: RefCounted = Metrics.new()
	metrics.begin(case_info, sim)
	for _day: int in range(int(case_info.days)):
		bot.on_day()
		sim.tick()
		metrics.sample(sim)
		if sim.state.status == "failed" or bot.finished():
			break
	var record: Dictionary = metrics.finish(sim)
	if keep_bot:
		record["_actions"] = bot.actions
		record["_state_bytes"] = var_to_bytes(sim.state)
	return record


func _run_shard(cases: Array) -> void:
	var parts: PackedStringArray = str(options.shard).split("/")
	var shard: int = int(parts[0])
	var count: int = int(parts[1])
	var runs: Array = []
	for index: int in range(cases.size()):
		if index % count == shard:
			runs.append(_run_case(cases[index], false))
	var file: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
	file.store_string(JSON.stringify(runs))
	file.close()
	quit(0)


func _run_parallel() -> Array:
	var jobs: int = int(options.jobs)
	_ensure_dir(OUT_DIR + "/tmp")
	var children: Array = []
	var base: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tests/balance/run_balance.gd",
		"--",
	]
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--jobs"):
			base.append(argument)
	for shard: int in range(jobs):
		var out: String = ProjectSettings.globalize_path("%s/tmp/shard_%d.json" % [OUT_DIR, shard])
		var arguments: PackedStringArray = base.duplicate()
		arguments.append("--shard=%d/%d" % [shard, jobs])
		arguments.append("--out=" + out)
		var pid: int = OS.create_process(OS.get_executable_path(), arguments)
		children.append({"pid": pid, "out": out, "shard": shard})
	while true:
		var alive: bool = false
		for child: Dictionary in children:
			if OS.is_process_running(int(child.pid)):
				alive = true
		if not alive:
			break
		await create_timer(POLL_SECONDS).timeout
	var runs: Array = []
	for child: Dictionary in children:
		var parsed: Variant = null
		if FileAccess.file_exists(child.out):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(child.out))
			DirAccess.remove_absolute(child.out)
		if parsed is Array:
			runs.append_array(parsed)
		else:
			# What the other shards measured is still worth having; the exit code says it is partial.
			print("BALANCE_ERROR shard %d produced no results" % int(child.shard))
			shards_lost += 1
	return runs


## Geography over 200 seeds, from its own process: worlds there are built without any cache.
func _geography() -> Dictionary:
	var out: String = ProjectSettings.globalize_path(OUT_DIR + "/tmp/world_stats.json")
	var arguments: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tests/v17_world_stats.gd",
		"--",
		"--seeds=%d" % GEOGRAPHY_SEEDS,
		"--json=" + out,
	]
	OS.execute(OS.get_executable_path(), arguments)
	if not FileAccess.file_exists(out):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out))
	DirAccess.remove_absolute(out)
	return parsed if parsed is Dictionary else {}


## A/B of the wage policy on colonies past their first lean year: the same colony from day 360 at
## 1.0x and 1.3x wages, with recruiting switched off so that only attractiveness moves arrivals.
func _labour_lever() -> Dictionary:
	var arrivals: Dictionary = {"1.0": [], "1.3": []}
	for seed_value: int in SEEDS.slice(0, LEVER_SEEDS):
		for wage: String in arrivals:
			var sim: RefCounted = Sim.new()
			sim.new_game(seed_value, "capital", SIZE_MEDIUM, "normal")
			var bot: RefCounted = BOTS.balanced.new()
			bot.fixed_wage = 1.0
			bot.begin(sim, seed_value)
			var before: int = 0
			for day: int in range(LEVER_DAYS * 2):
				if day == LEVER_DAYS:
					before = int(sim.state.immigrants_total)
					bot.recruit_batch = 0
					bot.fixed_wage = float(wage)
				bot.on_day()
				sim.tick()
				if sim.state.status == "failed":
					break
			arrivals[wage].append(int(sim.state.immigrants_total) - before)
	return {
		"days": LEVER_DAYS,
		"base": Summary.median(arrivals["1.0"]),
		"raised": Summary.median(arrivals["1.3"]),
	}


## What the air does to a colony that never builds a scrubber or pays for a cleanup.
func _no_pollution_control() -> Dictionary:
	var losses: Array = []
	for seed_value: int in SEEDS.slice(0, LEVER_SEEDS):
		var sim: RefCounted = Sim.new()
		sim.new_game(seed_value, "capital", SIZE_MEDIUM, "normal")
		var bot: RefCounted = BOTS.balanced.new()
		bot.clean_air = false
		bot.begin(sim, seed_value)
		for _day: int in range(DETERMINISM_DAYS):
			bot.on_day()
			sim.tick()
			if sim.state.status == "failed":
				break
		losses.append(float(sim.Pollution.penalty(sim)))
	return {"days": DETERMINISM_DAYS, "penalty": Summary.median(losses)}


## Replays a recorded action log on a fresh simulation and compares final states byte for byte.
func _determinism_check() -> Dictionary:
	var result: Dictionary = {"cases": 0, "identical": 0}
	for opening: String in OPENINGS:
		var case_info: Dictionary = {
			"bot": "balanced",
			"seed": SEEDS[0],
			"opening": opening,
			"difficulty": "normal",
			"days": mini(int(options.get("days", DEFAULT_DAYS)), DETERMINISM_DAYS),
		}
		var original: Dictionary = _run_case(case_info, true)
		var replayed: PackedByteArray = _replay(
			case_info, original._actions, int(original.final_day)
		)
		result.cases += 1
		if replayed == original._state_bytes:
			result.identical += 1
	return result


func _replay(case_info: Dictionary, actions: Array, final_day: int) -> PackedByteArray:
	var sim: RefCounted = Sim.new()
	sim.new_game(case_info.seed, case_info.opening, SIZE_MEDIUM, case_info.difficulty)
	var cursor: int = 0
	for _day: int in range(int(case_info.days) + 1):
		while cursor < actions.size() and int(actions[cursor].day) == int(sim.state.day):
			sim.act(actions[cursor].action, actions[cursor].args)
			cursor += 1
		if int(sim.state.day) >= final_day:
			break
		sim.tick()
	return var_to_bytes(sim.state)


func _publish(runs: Array, extras: Dictionary, seconds: float) -> void:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var rows: Array = Summary.targets(runs, extras)
	var groups: Array = Summary.group_table(runs)
	var report: Dictionary = {
		"label": options.label,
		"mode": options.mode,
		"stamp": stamp,
		"seconds": seconds,
		"engine": Engine.get_version_info(),
		"targets": rows,
		"groups": groups,
		"extras": extras,
		"runs": runs,
	}
	_ensure_dir(OUT_DIR)
	var path: String = "%s/%s.json" % [OUT_DIR, stamp]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	var table: String = Summary.markdown(str(options.label), stamp, rows, groups, seconds)
	if bool(options.doc):
		_update_doc(table, stamp, rows)
	print(table)
	print(
		(
			"BALANCE_RESULT runs=%d audit_errors=%d shards_lost=%d report=%s"
			% [runs.size(), _audit_total(runs), shards_lost, path]
		)
	)
	quit(0 if _audit_total(runs) == 0 and shards_lost == 0 else 1)


func _audit_total(runs: Array) -> int:
	var total: int = 0
	for run: Dictionary in runs:
		total += int(run.audit_error_count)
	return total


func _update_doc(table: String, stamp: String, rows: Array) -> void:
	var text: String = (
		"# Balance\n\n%s\n%s\n\n## History\n\n%s\n"
		% [
			RESULTS_BEGIN,
			RESULTS_END,
			HISTORY_BEGIN,
		]
	)
	if FileAccess.file_exists(DOC_PATH):
		text = FileAccess.get_file_as_string(DOC_PATH)
	var head: int = text.find(RESULTS_BEGIN)
	var tail: int = text.find(RESULTS_END)
	if head < 0 or tail < 0:
		print("BALANCE_ERROR results markers missing from BALANCE.md")
		return
	text = text.substr(0, head + RESULTS_BEGIN.length()) + "\n" + table + "\n" + text.substr(tail)
	var met: int = 0
	var missed: int = 0
	for row: Dictionary in rows:
		if row.status == Summary.STATUS_PASS:
			met += 1
		elif row.status == Summary.STATUS_MISS:
			missed += 1
	var line: String = (
		"- %s · %s (%s): %d targets met, %d missed."
		% [
			stamp,
			options.label,
			options.mode,
			met,
			missed,
		]
	)
	var marker: int = text.find(HISTORY_BEGIN)
	if marker >= 0:
		var insert_at: int = marker + HISTORY_BEGIN.length()
		text = text.substr(0, insert_at) + "\n" + line + text.substr(insert_at)
	var file: FileAccess = FileAccess.open(DOC_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
