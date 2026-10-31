extends SceneTree
## Phase 6 rules: repeatable events with cooldowns, notices against decisions and the pause setting,
## scaled money, feasibility of every option, and each new chain's endings, deferral, timeout and
## save/load continuation.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Events = preload("res://simulation/events_v2.gd")
const Rules = preload("res://simulation/rules.gd")

const SAVE_PATH: String = "user://events_test.save"
const NEW_CHAINS: Array[String] = ["liner", "crack", "blank_ridge"]

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


func make() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital")
	sim.act("settle", {"site": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


func fund(sim: RefCounted, amount: float) -> void:
	sim._transfer("external", "public", amount, "capital.initial", false)


func supply(sim: RefCounted, good: String, amount: float) -> void:
	sim._produce(sim.settlement(0), good, amount, "test")


func beds(sim: RefCounted, count: int) -> void:
	var s: Dictionary = sim.settlement(0)
	for _i: int in range(count):
		s.buildings.append(sim._building("habitat", 0))
	sim._refresh(s)


func open(sim: RefCounted, id: String) -> Dictionary:
	return Events._open(sim, id, 0)


func choose(sim: RefCounted, inst: Dictionary, choice: String) -> String:
	return sim.act("event_v2", {"instance_id": inst.instance_id, "choice": choice})


func step(sim: RefCounted, days: int) -> void:
	for _i: int in range(days):
		sim.tick()


func run() -> void:
	_content()
	_definitions_are_sound()
	_cooldowns()
	_notices_and_pause()
	_scaling()
	_feasibility()
	_effects_reach_the_systems()
	_rockfall_trigger()
	_liner()
	_crack()
	_blank_ridge()
	_chains_defer_and_time_out()
	_chains_survive_saving()
	_every_short_event_runs()
	print("V17_EVENTS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _content() -> void:
	var defs: Dictionary = Events.definitions().definitions
	var shorts: int = 0
	var chains: int = 0
	for id: String in defs:
		if str(defs[id].type) == "chain":
			chains += 1
		else:
			shorts += 1
	check(shorts >= 25, "at least 25 short definitions: %d" % shorts)
	check(chains >= 5, "at least 5 chains: %d" % chains)


## Every next node exists, every default is an option, every effect kind is known.
func _definitions_are_sound() -> void:
	var defs: Dictionary = Events.definitions().definitions
	var sound: bool = true
	for id: String in defs:
		var d: Dictionary = defs[id]
		for key: String in d.nodes:
			var node: Dictionary = d.nodes[key]
			var ids: Array = []
			for option: Dictionary in node.choices:
				ids.append(option.id)
				for field: String in ["next", "alt"]:
					if option.has(field) and not d.nodes.has(option[field]):
						sound = false
						print("bad %s in %s/%s" % [field, id, key])
				for effect: Dictionary in option.get("effects", []):
					if not effect.kind in Events.EFFECT_KINDS:
						sound = false
						print("bad effect in %s/%s" % [id, key])
			if not node.default in ids:
				sound = false
				print("bad default in %s/%s" % [id, key])
		var cooldown: int = int(d.get("cooldown_days", 0))
		if cooldown < 120 or cooldown > 360:
			sound = false
			print("cooldown out of range: " + id)
	check(sound, "definitions are sound")


func _cooldowns() -> void:
	var sim: RefCounted = make()
	var first: Dictionary = open(sim, "seed_crate")
	check(choose(sim, first, "take") == "", "a short event resolves")
	check(not Events._cooled(sim, "seed_crate"), "it cools down")
	var today: int = int(sim.state.day)
	sim.state.events_v2.last_opened.seed_crate = today - 179
	check(not Events._cooled(sim, "seed_crate"), "still cooling a day before the cooldown ends")
	sim.state.events_v2.last_opened.seed_crate = today - 180
	check(Events._cooled(sim, "seed_crate"), "ready again when the cooldown ends")
	var second: Dictionary = open(sim, "seed_crate")
	check(second.instance_id != first.instance_id, "the same definition opens a new instance")
	check(sim.state.events_v2.seen.count("seed_crate") == 1, "seen lists it once")
	check(choose(sim, second, "take") == "", "and resolves again")
	check(sim.save_game(SAVE_PATH) == "", "two instances of one definition save")
	var other: RefCounted = Sim.new()
	var load_error: String = other.load_game(SAVE_PATH)
	check(load_error == "", "and load: " + load_error)
	check(var_to_bytes(other.state) == var_to_bytes(sim.state), "byte-identical")
	var many: RefCounted = make()
	for _i: int in range(40):
		var inst: Dictionary = open(many, "seed_crate")
		choose(many, inst, "take")
	check(
		many.state.events_v2.instances.size() <= 17,
		"old instances are forgotten: %d kept" % many.state.events_v2.instances.size()
	)
	check(str(many.state.events_v2.endings.seed_crate) != "", "their endings are remembered")


func _notices_and_pause() -> void:
	var sim: RefCounted = make()
	var notice: Dictionary = open(sim, "seed_crate")
	check(not bool(notice.pause_required), "a notice does not pause")
	check(not Events.pause_required(sim), "the game keeps running")
	check(int(notice.deadline) > int(sim.state.day), "it has a deadline")
	var due: int = int(notice.deadline) - int(sim.state.day)
	step(sim, due)
	check(notice.status == "resolved", "an unanswered notice takes its default at the deadline")
	var critical: Dictionary = open(sim, "water")
	check(bool(critical.pause_required), "a critical decision pauses")
	check(Events.pause_required(sim), "and stops the game")
	choose(sim, critical, "decline")
	var quiet: RefCounted = make()
	var plain: Dictionary = open(quiet, "market_day")
	check(not bool(plain.pause_required), "by default a minor decision does not pause")
	choose(quiet, plain, "defer")
	var strict: RefCounted = make()
	check(strict.act("policy", {"event_pause": "all"}) == "", "the setting can be changed")
	var asked: Dictionary = open(strict, "market_day")
	check(bool(asked.pause_required), "with the setting every decision pauses")
	var told: Dictionary = open(strict, "seed_crate")
	check(not bool(told.pause_required), "notices still do not")
	check(strict.save_game(SAVE_PATH) == "", "a waiting notice saves")
	var again: RefCounted = Sim.new()
	check(again.load_game(SAVE_PATH) == "", "and loads")


func _scaling() -> void:
	var sim: RefCounted = make()
	check(Events.money_scale(sim) == 1.0, "no scaling for a small colony")
	for i: int in range(30):
		sim.state.operating_history.append({"day": i, "net": 0.0, "income": 1500.0, "expense": 0.0})
	check(is_equal_approx(Events.money_scale(sim), 5.0), "money scales with recent income")
	var inst: Dictionary = open(sim, "equipment_failure")
	fund(sim, 5000.0)
	var cash: float = float(sim.state.cash)
	check(choose(sim, inst, "cash") == "", "a scaled option can be paid")
	check(is_equal_approx(cash - float(sim.state.cash), 110.0 * 5.0), "it costs the scaled amount")
	var view_cost: float = 0.0
	var next: Dictionary = open(sim, "supply_delay")
	for row: Dictionary in Events.view(sim).pending:
		if row.instance_id == next.instance_id:
			view_cost = float(row.choices[0].cost)
	check(is_equal_approx(view_cost, 70.0 * 5.0), "the card shows the scaled amount")


func _feasibility() -> void:
	var sim: RefCounted = make()
	sim._transfer("public", "external", float(sim.state.cash), "test", false)
	var broke: Dictionary = open(sim, "supply_delay")
	var reason: String = choose(sim, broke, "rush")
	check(reason.contains("资金"), "no money, no option: " + reason)
	choose(sim, broke, "wait")
	var crowded: RefCounted = make()
	var migrants: Dictionary = open(crowded, "migrant_group")
	check(choose(crowded, migrants, "accept").contains("床位"), "no beds, no migrants")
	beds(crowded, 1)
	check(choose(crowded, migrants, "accept") == "", "with beds they settle")
	var labs: RefCounted = make()
	var idea: Dictionary = open(labs, "breakthrough")
	check(choose(labs, idea, "apply").contains("科研"), "no project, nothing to apply it to")
	choose(labs, idea, "publish")
	var enabled_reason: bool = true
	var poor: RefCounted = make()
	var card: Dictionary = open(poor, "equipment_failure")
	poor.settlement(0).stock.parts = 0.0
	poor.state.resource_sinks.parts = float(poor.state.resource_sources.parts)
	for row: Dictionary in Events.view(poor).pending:
		if row.instance_id == card.instance_id:
			for choice: Dictionary in row.choices:
				if choice.id == "parts":
					enabled_reason = not bool(choice.enabled) and str(choice.reason) != ""
	check(enabled_reason, "a disabled option says why")


func _effects_reach_the_systems() -> void:
	var sim: RefCounted = make()
	beds(sim, 1)
	var before: float = float(sim.Market.price(sim, "ore"))
	fund(sim, 1000.0)
	var window: Dictionary = open(sim, "price_window")
	check(choose(sim, window, "sign") == "", "the forward contract can be signed")
	sim.tick()
	check(
		(
			is_equal_approx(sim.Market.price(sim, "ore") / before, 1.1)
			or sim.Market.price(sim, "ore") > before
		),
		"it lifts export prices"
	)
	var s: Dictionary = sim.settlement(0)
	var show: Dictionary = open(sim, "meteor_shower")
	check(choose(sim, show, "festival") == "", "the festival runs")
	sim.tick()
	check(
		float(sim.Population.attractiveness(sim, s).parts.get("events", 0.0)) > 0.0,
		"and lifts appeal"
	)
	var flu: Dictionary = open(sim, "flu_season")
	check(choose(sim, flu, "carry_on") == "", "flu is left to run")
	sim.tick()
	check(
		is_equal_approx(Events.modifier(sim, 0, "mine"), 0.9),
		"everyone works at 90% during the flu"
	)
	var checked: RefCounted = make()
	checked.settlement(0).buildings.append(checked._building("clinic", 0))
	var flu_two: Dictionary = open(checked, "flu_season")
	choose(checked, flu_two, "carry_on")
	checked.tick()
	check(is_equal_approx(Events.modifier(checked, 0, "mine"), 0.95), "a clinic halves the flu")
	var audit_sim: RefCounted = make()
	var audit: Dictionary = open(audit_sim, "company_audit")
	var trust: float = float(audit_sim.state.company.distrust)
	choose(audit_sim, audit, "ignore")
	check(float(audit_sim.state.company.distrust) > trust, "skipping an audit costs trust")
	check(sim.audit().is_empty(), "effects pass the audit")


func _rockfall_trigger() -> void:
	var sim: RefCounted = make()
	fund(sim, 20000.0)
	supply(sim, "materials", 100.0)
	sim.state.contract.licences.append("expedition")
	sim.act("settle", {"site": 1})
	step(sim, 12)
	check(sim.act("connect", {"a": 0, "b": 1, "variant": "engineered"}) == "", "an engineered road")
	sim.state.day = 100
	var road: Dictionary = sim.state.roads[0]
	var opened: bool = false
	for _i: int in range(2000):
		sim.state.day = int(sim.state.day) + 1
		sim.Logistics.road_daily(sim)
		if sim.state.events_v2.last_opened.has("rockfall"):
			opened = true
			break
	check(opened, "a rockfall on the road opens its event")
	check(int(road.blocked_until) >= int(sim.state.day), "and the road really is closed")
	var inst: Dictionary = {}
	for row: Dictionary in sim.state.events_v2.instances:
		if row.definition_id == "rockfall":
			inst = row
	check(choose(sim, inst, "repair") == "", "a crew can be paid")
	check(int(road.blocked_until) < int(sim.state.day), "and the road opens the same day")


func _liner() -> void:
	var sim: RefCounted = make()
	fund(sim, 5000.0)
	supply(sim, "food", 400.0)
	beds(sim, 2)
	var inst: Dictionary = open(sim, "liner")
	var people: int = int(sim.settlement(0).population)
	check(choose(sim, inst, "all") == "", "everyone comes ashore")
	check(int(sim.settlement(0).population) == people + 20, "the population really grows")
	step(sim, 12)
	check(inst.node == "crowded", "the dormitories fill up")
	supply(sim, "materials", 60.0)
	supply(sim, "parts", 20.0)
	check(choose(sim, inst, "squeeze") == "", "they can squeeze in")
	check(str(inst.ending) == "拥挤度日", "ending: crowded")
	check(sim.audit().is_empty(), "the liner passes the audit")
	var staged: RefCounted = make()
	fund(staged, 5000.0)
	supply(staged, "food", 400.0)
	beds(staged, 2)
	var second: Dictionary = open(staged, "liner")
	check(choose(staged, second, "staged") == "", "half come ashore")
	step(staged, 15)
	check(second.node == "second_batch", "the other half wait")
	check(choose(staged, second, "rest") == "", "and are taken in")
	check(str(second.ending) == "分批安置完成", "ending: staged")
	var sent: RefCounted = make()
	var third: Dictionary = open(sent, "liner")
	supply(sent, "food", 100.0)
	check(choose(sent, third, "send_on") == "", "the ship can be sent on")
	check(str(third.ending) == "补给返航", "ending: sent on")
	var full: RefCounted = make()
	var fourth: Dictionary = open(full, "liner")
	check(choose(full, fourth, "all").contains("床位"), "accepting everyone needs beds")


func _crack() -> void:
	var sim: RefCounted = _with_road()
	var inst: Dictionary = open(sim, "crack")
	check(choose(sim, inst, "limit") == "", "loads can be limited")
	sim.tick()
	check(
		is_equal_approx(Events.colony_modifier(sim, "road_capacity"), 0.5),
		"limited loads halve road capacity"
	)
	step(sim, 20)
	check(inst.node == "repaired", "the repair finishes")
	choose(sim, inst, "reopen")
	check(str(inst.ending) == "修复通行", "ending: repaired")
	var bypass: RefCounted = _with_road()
	var built: Dictionary = open(bypass, "crack")
	check(choose(bypass, built, "bypass") == "", "a bypass can be built")
	check(str(built.ending) == "便桥通车", "ending: bypass")
	var held: int = 0
	var failed: int = 0
	for seed_offset: int in range(24):
		var gamble: RefCounted = _with_road()
		gamble.state.events_v2.rng_state = 1000 + seed_offset * 7919
		var bet: Dictionary = open(gamble, "crack")
		choose(gamble, bet, "risk")
		step(gamble, 25)
		if bet.node == "risk_failed":
			failed += 1
			fund(gamble, 5000.0)
			supply(gamble, "materials", 20.0)
			check(choose(gamble, bet, "emergency") == "", "the broken span is repaired")
			check(
				int(gamble.state.roads[0].blocked_until) > int(gamble.state.day),
				"the road stays closed meanwhile"
			)
		elif bet.node == "risk_held":
			held += 1
			choose(gamble, bet, "note")
	check(
		held > 0 and failed > 0, "the gamble can go either way: %d held, %d failed" % [held, failed]
	)


func _with_road() -> RefCounted:
	var sim: RefCounted = make()
	fund(sim, 20000.0)
	supply(sim, "materials", 100.0)
	supply(sim, "food", 300.0)
	sim.state.contract.licences.append("expedition")
	sim.act("settle", {"site": 1})
	step(sim, 12)
	sim.act("connect", {"a": 0, "b": 1, "variant": "valley"})
	return sim


func _blank_ridge() -> void:
	var sim: RefCounted = make()
	var site: Dictionary = sim.state.world.regions[0]
	(
		site
		. plots
		. append(
			{
				"kind": "deposit",
				"resource": "crystal",
				"grade": 1.0,
				"reserves": 900.0,
				"depth": 0,
				"hidden": true,
				"x": 24.0,
				"z": 18.0,
			}
		)
	)
	fund(sim, 2000.0)
	var s: Dictionary = sim.settlement(0)
	s.buildings.append(sim._building("lab", 0))
	var before: float = float(site.deposits.crystal)
	var inst: Dictionary = open(sim, "blank_ridge")
	check(choose(sim, inst, "survey") == "", "a full survey can be sent")
	check(inst.status == "waiting", "and takes time")
	for _i: int in range(40):
		sim.tick()
		if inst.node == "charted":
			break
	check(inst.node == "charted", "the survey finishes")
	check(choose(sim, inst, "open") == "", "the vein is published")
	check(float(site.deposits.crystal) > before, "the hidden deposit is now known")
	check(str(inst.ending) == "矿脉探明", "ending: charted")
	check(sim.audit().is_empty(), "the ridge passes the audit")
	var quick: RefCounted = make()
	var other: Dictionary = quick.state.world.regions[0]
	for plot: Dictionary in other.plots:
		if plot.kind == "deposit":
			plot.hidden = false
	quick.Sites.SiteGen.refresh_deposits(other)
	var sold: Dictionary = open(quick, "blank_ridge")
	var cash: float = float(quick.state.cash)
	check(choose(quick, sold, "sell") == "", "the rights can be sold")
	check(float(quick.state.cash) > cash, "for money")
	check(str(sold.ending) == "让渡开发权", "ending: sold")


func _chains_defer_and_time_out() -> void:
	for id: String in NEW_CHAINS:
		var sim: RefCounted = make()
		var inst: Dictionary = open(sim, id)
		var deadline: int = int(inst.deadline)
		check(choose(sim, inst, "defer") == "", id + " can be deferred")
		check(not Events.pause_required(sim), id + " stops pausing once deferred")
		check(choose(sim, inst, "defer") != "", id + " can be deferred only once")
		check(int(inst.deadline) == deadline, id + " keeps its deadline")
		step(sim, deadline - int(sim.state.day))
		check(
			inst.status != "deferred" and inst.status != "pending",
			id + " takes its default on time"
		)
		check(sim.audit().is_empty(), id + " passes the audit after timing out")


func _chains_survive_saving() -> void:
	for id: String in NEW_CHAINS:
		var sim: RefCounted = _with_road() if id == "crack" else make()
		fund(sim, 3000.0)
		supply(sim, "food", 300.0)
		beds(sim, 2)
		var inst: Dictionary = open(sim, id)
		check(sim.save_game(SAVE_PATH) == "", id + " saves while open")
		var other: RefCounted = Sim.new()
		check(other.load_game(SAVE_PATH) == "", id + " loads while open")
		check(var_to_bytes(other.state) == var_to_bytes(sim.state), id + " is byte-identical")
		for _i: int in range(int(inst.deadline) - int(sim.state.day) + 30):
			sim.tick()
			other.tick()
		check(var_to_bytes(other.state) == var_to_bytes(sim.state), id + " continues identically")


## Every short event opens on a colony that can afford it, and every option applies cleanly.
func _every_short_event_runs() -> void:
	var defs: Dictionary = Events.definitions().definitions
	var clean: bool = true
	for id: String in defs:
		if str(defs[id].type) != "short":
			continue
		for option: Dictionary in defs[id].nodes.start.choices:
			var sim: RefCounted = _rich_colony()
			var inst: Dictionary = open(sim, id)
			var refused: String = choose(sim, inst, option.id)
			if refused != "" and not _acceptable(refused):
				clean = false
				print("event %s/%s refused: %s" % [id, option.id, refused])
			step(sim, 3)
			var issues: Array = sim.audit()
			if not issues.is_empty():
				clean = false
				print("event %s/%s audit: %s" % [id, option.id, str(issues)])
	check(clean, "every short event option applies cleanly")


func _acceptable(refusal: String) -> bool:
	return refusal.contains("封闭中的道路") or refusal.contains("项目") or refusal.contains("企业")


func _rich_colony() -> RefCounted:
	var sim: RefCounted = make()
	fund(sim, 20000.0)
	supply(sim, "food", 400.0)
	supply(sim, "materials", 200.0)
	supply(sim, "parts", 60.0)
	beds(sim, 2)
	var s: Dictionary = sim.settlement(0)
	s.buildings.append(sim._building("mine_ore", 0))
	s.buildings.append(sim._building("farm", 0))
	s.buildings.append(sim._building("lab", 0))
	return sim
