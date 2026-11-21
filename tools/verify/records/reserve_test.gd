extends SceneTree
## The day-865 stock test, run the same way on 1.10.1 and 1.11 from one 1.10.1 save: the capital
## keeps --reserve units (100 t each) of materials and parts — 1.10.1's production target, 1.11's
## local reserve — and the colony runs --days days hands-off (communications answered). Other towns'
## processing is switched off so every tonne of materials and parts comes from the capital, and the
## capital has no construction waiting (no competing commitments). Records per day the capital's
## stock, what it made, what was exported and what construction used.
##   godot --headless --path <project> --script reserve_test.gd -- --save=<file> --reserve=500 --days=30 --out=<json>

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Stats = preload("res://simulation/stats.gd")

const GOODS: Array[String] = ["materials", "parts"]

var options: Dictionary = {"save": "", "reserve": "500", "days": "30", "out": ""}
var record: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var timer: SceneTreeTimer = create_timer(900.0)
	timer.timeout.connect(func(): _finish("watchdog"))
	_run.call_deferred()


func _run() -> void:
	var sim: RefCounted = Sim.new()
	var error: String = sim.load_game(str(options.save))
	record.options = options
	record.load_error = error
	if error != "":
		_finish("load failed")
		return
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	var version: String = "1.11" if s.has("stock_rules") else "1.10.1"
	record.version = version
	record.day = int(sim.state.day)
	record.capital = str(s.name)
	# Other towns make no materials or parts for the month.
	var switched: Array = []
	for town: Dictionary in sim.state.settlements:
		if int(town.region) == region:
			continue
		for index: int in range(town.buildings.size()):
			var b: Dictionary = town.buildings[index]
			var role: String = str(sim.config.buildings.get(str(b.kind), {}).get("role", ""))
			if role in ["processor", "factory"] and bool(b.get("enabled", true)):
				var refused: String = sim.act(
					"toggle", {"region": int(town.region), "index": index}
				)
				switched.append("%s %s %s" % [str(town.name), str(b.kind), refused])
	record.switched_off = switched
	var waiting: Array = []
	for b: Dictionary in s.buildings:
		if int(b.get("remaining", 0)) > 0:
			waiting.append(str(b.kind))
	record.capital_construction_waiting = waiting
	var units: float = float(options.reserve)
	var set_words: Array = []
	for good: String in GOODS:
		if version == "1.11":
			set_words.append(
				sim.act("stock_rule", {"region": region, "resource": good, "reserve": units})
			)
		else:
			set_words.append(
				sim.act("stock_target", {"region": region, "resource": good, "target": units})
			)
	record.set_refusals = set_words
	if version == "1.11":
		var rows: Dictionary = {}
		for good: String in GOODS:
			var row: Dictionary = sim.Stocks.availability(sim, s, good)
			rows[good] = {
				"total_t": sim.tonnes(float(row.total)),
				"held_t": sim.tonnes(float(row.held_total)),
				"sellable_t": sim.tonnes(float(row.sellable))
			}
		record.availability_at_start = rows
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(sim.state.world.get("seed", 0)))
	var start: Dictionary = {}
	for good: String in GOODS:
		start[good] = float(s.stock.get(good, 0.0))
	record.stock_start_t = {"materials": start.materials * 100.0, "parts": start.parts * 100.0}
	var days: Array = []
	for _day: int in range(int(options.days)):
		bot.answer_events()
		sim.tick()
		var one: Dictionary = sim.stats_window(1)
		var row: Dictionary = {"day": int(sim.state.day)}
		for good: String in GOODS:
			var flows: Array = one.goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
			row[good] = {
				"stock_t": snappedf(float(s.stock.get(good, 0.0)) * 100.0, 1.0),
				"made_t": snappedf(float(flows[Stats.PRODUCED]) * 100.0, 1.0),
				"exported_t": snappedf(float(flows[Stats.EXPORTED]) * 100.0, 1.0),
				"used_t": snappedf(float(flows[Stats.CONSUMED]) * 100.0, 1.0),
			}
		days.append(row)
	record.days = days
	var window: Dictionary = sim.stats_window(int(options.days))
	var totals: Dictionary = {}
	for good: String in GOODS:
		var flows: Array = window.goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
		totals[good] = {
			"made_t": snappedf(float(flows[Stats.PRODUCED]) * 100.0, 1.0),
			"exported_t": snappedf(float(flows[Stats.EXPORTED]) * 100.0, 1.0),
			"used_t": snappedf(float(flows[Stats.CONSUMED]) * 100.0, 1.0),
			"imported_t": snappedf(float(flows[Stats.IMPORTED]) * 100.0, 1.0),
			"stock_start_t": snappedf(float(start[good]) * 100.0, 1.0),
			"stock_end_t": snappedf(float(s.stock.get(good, 0.0)) * 100.0, 1.0),
		}
	record.totals = totals
	record.audit = sim.audit()
	_finish("done")


func _finish(why: String) -> void:
	record.finish = why
	if str(options.out) != "":
		var file: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	printerr(
		(
			"RESERVE %s finish=%s totals=%s"
			% [str(record.get("version", "?")), why, JSON.stringify(record.get("totals", {}))]
		)
	)
	quit(0)
