extends SceneTree
## Saves through a version change (1.10). Runs against any build: the source project, or a packaged
## PCK (`--main-pack`). With `--make`, it plays a colony with the balance harness's balanced bot
## (`--bots=<dir>` for a build that ships without tests) until a second town is founded and work
## is under way, and writes the game's own save to `--save`; with `--check`, it loads that save,
## reports what it holds (towns and their places, construction under way, crews, contract stage,
## research and money), plays on a few days, saves it again to `--after`, and checks that nothing
## the player had was lost.
##
##   godot --main-pack <old pck> --script <abs>/save_carry_driver.gd -- --make --seed=20261029
##     --save=<file> --out=<json> --bots=<dir>
##   godot --path game --script <abs>/save_carry_driver.gd -- --check --save=<file>
##     --after=<file> --out=<json> --before=<json from --make>

var options: Dictionary = {
	"seed": "20261029", "save": "", "after": "", "out": "", "bots": "", "before": "", "days": "700"
}
var record: Dictionary = {"checks": [], "ok": true}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	record.options = options.duplicate()
	record.game_version = str(ProjectSettings.get_setting("application/config/version"))
	record.build = (
		"source project"
		if ResourceLoader.exists("res://tests/v110_placement.gd")
		else "packaged PCK"
	)
	call_deferred("run")


func _check(ok: bool, label: String) -> void:
	record.checks.append({"ok": ok, "label": label})
	if not ok:
		record.ok = false
	printerr(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	if options.has("make"):
		_make()
	elif options.has("check"):
		_carry()
	var path: String = str(options.out)
	if path != "":
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	printerr("SAVE_CARRY_RESULT ok=%s checks=%d" % [str(record.ok), record.checks.size()])
	quit(0 if record.ok else 1)


func _sim() -> RefCounted:
	return load("res://simulation/" + "sim.gd").new()


func _bot() -> RefCounted:
	var path: String = "res://tests/balance/bots/balanced_bot.gd"
	if str(options.bots) != "":
		path = str(options.bots).path_join("balanced_bot.gd")
	return load(path).new()


## A colony played until a second town stands and something is being built, then saved.
func _make() -> void:
	var sim: RefCounted = _sim()
	sim.new_game(int(options.seed), "capital", 1)
	var bot: RefCounted = _bot()
	bot.begin(sim, int(options.seed))
	var limit: int = int(options.days)
	while int(sim.state.day) < limit:
		bot.on_day()
		sim.tick()
		if int(sim.state.day) > 200 and sim.state.settlements.size() >= 2 and _building(sim) > 0:
			break
	var error: String = sim.save_game(str(options.save))
	_check(error == "", "saved on day %d: %s" % [int(sim.state.day), error])
	record.snapshot = snapshot(sim)


## The save loaded in this build: what it holds, against what the old build wrote.
func _carry() -> void:
	var sim: RefCounted = _sim()
	var error: String = sim.load_game(str(options.save))
	_check(error == "", "the old save loads: " + error)
	if error != "":
		return
	# Compared as the old build wrote them: through JSON, where every number is a float.
	var now: Dictionary = JSON.parse_string(JSON.stringify(snapshot(sim)))
	record.loaded = now
	var before: Dictionary = {}
	if str(options.before) != "" and FileAccess.file_exists(str(options.before)):
		before = JSON.parse_string(FileAccess.get_file_as_string(str(options.before))).snapshot
	if not before.is_empty():
		_check(int(now.day) == int(before.day), "the same day: %d" % int(now.day))
		_check(
			is_equal_approx(float(now.cash), float(before.cash)),
			"the same money: ¥ %.0f" % float(now.cash)
		)
		_check(str(now.stage) == str(before.stage), "the same contract stage: %s" % str(now.stage))
		_check(
			now.towns == before.towns, "every town, its name, place and people: %s" % str(now.towns)
		)
		_check(now.under_way == before.under_way, "construction under way: %s" % str(now.under_way))
		_check(now.crews == before.crews, "the crews and what they do: %s" % str(now.crews))
		_check(
			now.research == before.research,
			"research done and in progress: %d done" % now.research.done.size()
		)
	_check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
	for _day: int in range(10):
		sim.tick()
	var later: Dictionary = snapshot(sim)
	_check(sim.audit().is_empty(), "ten days on, the audit holds")
	_check(later.towns.size() == now.towns.size(), "and every town is still there")
	if str(options.after) != "":
		error = sim.save_game(str(options.after))
		_check(error == "", "saved again by this build on day %d" % int(sim.state.day))
		var again: RefCounted = _sim()
		_check(again.load_game(str(options.after)) == "", "and that save loads")
	record.later = later


## What a player would check in a save: the day, money, stage, each town (name, place, people),
## what is being built (uid, kind, days left), the crews, research.
static func snapshot(sim: RefCounted) -> Dictionary:
	var towns: Array = []
	var under_way: Array = []
	for s: Dictionary in sim.state.settlements:
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		towns.append(
			[
				str(s.name),
				int(s.region),
				snappedf(float(reg.lat), 0.0001),
				snappedf(float(reg.lon), 0.0001),
				int(s.population)
			]
		)
		for b: Dictionary in s.buildings:
			if int(b.remaining) > 0:
				under_way.append(
					[int(s.region), int(b.get("uid", 0)), str(b.kind), int(b.remaining)]
				)
	var crews: Array = []
	for team: Dictionary in sim.state.get("crews", {}).get("teams", []):
		crews.append([int(team.id), int(team.region), str(team.task), int(team.get("target", 0))])
	var progress: Dictionary = {}
	for key: String in sim.state.research.projects:
		progress[key] = snappedf(float(sim.state.research.projects[key].work), 0.001)
	return {
		"day": int(sim.state.day),
		"cash": float(sim.state.cash),
		"stage": str(sim.state.contract.get("stage", "")),
		"towns": towns,
		"under_way": under_way,
		"crews": crews,
		"research": {"done": sim.state.research.completed.duplicate(), "work": progress},
	}


static func _building(sim: RefCounted) -> int:
	var count: int = 0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if int(b.remaining) > 0:
				count += 1
	return count
