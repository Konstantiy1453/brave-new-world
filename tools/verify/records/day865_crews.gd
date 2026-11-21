extends SceneTree
## Day-865 analog: place a power station, then a freight port, in the capital while paused; print what
## the checkout says about the crew, its queue and the dates, then run and record what happened.
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
var options: Dictionary = {"save": "", "out": "", "mode": "handsoff"}


func _initialize() -> void:
	create_timer(500.0).timeout.connect(
		func():
			printerr("WATCHDOG")
			quit(2)
	)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var sim: RefCounted = Sim.new()
	printerr("LOAD ", sim.load_game(str(options.save)), " day ", sim.state.day)
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	var record: Dictionary = {"day": int(sim.state.day), "town": str(s.name), "steps": []}
	for team: Dictionary in sim.state.crews.teams:
		if int(team.region) == region:
			printerr("CREW ", JSON.stringify(team))
	printerr("PRE-CHECKOUT")
	var uids: Array = []
	for kind: String in ["power", "port"]:
		var order: Dictionary = sim.checkout(region, kind)
		var crew: Dictionary = order.crew
		var ahead: Array = []
		for item: Dictionary in crew.ahead:
			ahead.append("%s %d->%d" % [item.name, item.start, item.finish])
		printerr(
			(
				"CHECKOUT %s cash_now=%.0f (build %.0f + bought %.0f) crew=#%d state=%s place=%d start=%d finish=%d ahead=%s"
				% [
					kind,
					order.cash_now,
					order.construction,
					order.bought,
					crew.crew,
					crew.crew_state,
					crew.place,
					crew.start,
					crew.finish,
					str(ahead)
				]
			)
		)
		record.steps.append(
			{
				"kind": kind,
				"cash_now": order.cash_now,
				"crew": crew.crew,
				"place": crew.place,
				"start": crew.start,
				"finish": crew.finish,
				"ahead": ahead
			}
		)
		var before: float = float(sim.state.cash)
		printerr(
			"BUILD ",
			kind,
			" -> '",
			sim.act("build", {"site": region, "kind": kind}),
			"' cash change ",
			before - float(sim.state.cash)
		)
		uids.append(int(s.buildings.back().uid))
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(sim.state.world.seed))
	var started: Dictionary = {}
	var finished: Dictionary = {}
	for _d: int in range(120):
		if str(options.mode) == "bot":
			bot.on_day()
		else:
			bot.answer_events()
		sim.tick()
		for uid: int in uids:
			var index: int = sim.Production.index_of(s, uid)
			var b: Dictionary = s.buildings[index]
			if not started.has(uid) and int(b.remaining) < int(b.total_days):
				started[uid] = int(sim.state.day)
			if not finished.has(uid) and int(b.remaining) <= 0:
				finished[uid] = int(sim.state.day)
	for index: int in range(uids.size()):
		printerr(
			(
				"ACTUAL %s started=%s finished=%s"
				% [
					["power", "port"][index],
					str(started.get(uids[index], -1)),
					str(finished.get(uids[index], -1))
				]
			)
		)
		record.steps[index].actual_start = started.get(uids[index], -1)
		record.steps[index].actual_finish = finished.get(uids[index], -1)
	if str(options.out) != "":
		var file: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	quit(0)
