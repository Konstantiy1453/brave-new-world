extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
var failures: int = 0
var checks: int = 0
var E: Script
var Sim: Script


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func _init() -> void:
	Watchdog.arm(self)
	check(
		FileAccess.file_exists("res://simulation/events_v2.gd"),
		"versioned conditional event module exists"
	)
	if failures:
		print("EVENTS_V16_RESULT checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	E = load("res://simulation/events_v2.gd")
	Sim = load("res://simulation/sim.gd")
	if E == null or Sim == null or not E.can_instantiate() or not Sim.can_instantiate():
		check(false, "event and simulation scripts parse")
		quit(1)
		return
	run_tests()
	print("EVENTS_V16_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func make():
	var s = Sim.new()
	s.new_game(20261029, "science", 1)
	s.act("settle", {"region": 0})
	E.ensure(s)
	s.state.events_v2.next_draw = 9999
	return s


func opened(s, id: String) -> Dictionary:
	return E._open(s, id, 0)


func choose(s, i: Dictionary, id: String) -> String:
	return E.act(s, {"instance_id": i.instance_id, "choice": id})


func days(s, n: int) -> void:
	for k in range(n):
		s.state.day += 1
		if s.state.has("career"):
			s.state.career.global_day += 1
			s.state.career.last_local_day = s.state.day
		E.tick(s)


func supplies(s) -> void:
	s._transfer("external", "public", 5000, "TEST initial funds", false)
	for resource in ["ore", "copper", "materials", "parts", "food"]:
		s._produce(s.settlement(0), resource, 200, "TEST inventory")


func facilities(s) -> void:
	supplies(s)
	for kind in ["processor", "lab", "mine_ore"]:
		s.act("build", {"region": 0, "kind": kind})
	for b in s.settlement(0).buildings:
		b.remaining = 0
		b.active = true
	s.settlement(0).port_capacity = 38.0
	s.settlement(0).port_used = 0.0


func assert_end(s, i: Dictionary, want: String) -> void:
	check(i.ending == want, "ending: " + want)
	check(i.status == "resolved" and not i.pause_required, "resolved ending releases modal pause")
	var before: String = JSON.stringify(s.state)
	check(
		choose(s, i, "decline") != "" and before == JSON.stringify(s.state),
		"duplicate conclusion has no effects"
	)
	if E.definitions().definitions[i.definition_id].type == "chain":
		check(s.save_game("user://v16_event_ending.json") == "", "ending saved: " + want)
		var restored = Sim.new()
		var error: String = restored.load_game("user://v16_event_ending.json")
		if error != "":
			print("ENDING_LOAD_ERROR ", want, " ", error)
		check(error == "", "ending restored: " + want)
		if error == "":
			var loaded: Dictionary = E._instance(restored, i.instance_id)
			var snapshot: String = JSON.stringify(restored.state)
			check(
				(
					choose(restored, loaded, "decline") != ""
					and snapshot == JSON.stringify(restored.state)
				),
				"loaded ending cannot repay: " + want
			)


func run_tests() -> void:
	var s = make()
	check(E.definitions().definitions.size() >= 13, "ten short events and three full chains")
	var before: String = JSON.stringify(s.state)
	check(E.act(s, {"instance_id": "bogus", "choice": "take"}) != "", "unknown target rejected")
	check(JSON.stringify(s.state) == before, "invalid event leaves whole state unchanged")
	var rng: int = s.state.events_v2.rng_state
	E.view(s)
	E.view(s)
	check(s.state.events_v2.rng_state == rng, "view never consumes random state")
	shorts()
	water_chain()
	archaeology_chain()
	industry_chain()
	persistence()
	deferred_nodes()
	integrated_production()
	malformed_saves()


func shorts() -> void:
	for id in E.definitions().definitions:
		var d: Dictionary = E.definitions().definitions[id]
		if d.type != "short":
			continue
		for option in d.nodes.start.choices:
			var s = make()
			facilities(s)
			var i: Dictionary = opened(s, id)
			check(choose(s, i, option.id) == "", "short option " + id + "/" + option.id)
			assert_end(s, i, option.ending)
			check(s.audit().is_empty(), "short money/material conservation " + id)
	var active = make()
	var timed = make()
	var ia: Dictionary = opened(active, "pump_seal")
	var it: Dictionary = opened(timed, "pump_seal")
	check(E.view(active).pause_required, "new decision requires explicit pause")
	check(
		choose(timed, it, "defer") == "" and not E.view(timed).pause_required,
		"explicit defer releases pause"
	)
	var deadline: int = int(it.deadline)
	var before: String = JSON.stringify(timed.state)
	check(
		choose(timed, it, "defer") != "" and before == JSON.stringify(timed.state),
		"repeated defer cannot extend deadline"
	)
	active.state.day = deadline
	choose(active, ia, "decline")
	days(timed, deadline)
	check(
		(
			JSON.stringify(active.state.events_v2.effects)
			== JSON.stringify(timed.state.events_v2.effects)
		),
		"manual/default same day yield identical effect boundaries"
	)
	var a_days: int = 0
	var t_days: int = 0
	for k in range(9):
		active.state.day = deadline + k
		timed.state.day = deadline + k
		if E.modifier(active, 0, "water") < 1:
			a_days += 1
		if E.modifier(timed, 0, "water") < 1:
			t_days += 1
	check(
		a_days == 6 and t_days == 6, "F10/F11 both choices affect exactly six full production days"
	)
	var missing = make()
	var im: Dictionary = opened(missing, "pump_seal")
	missing.state.cash = 0.0
	before = JSON.stringify(missing.state)
	check(
		choose(missing, im, "repair") != "" and before == JSON.stringify(missing.state),
		"missing cash atomic rejection"
	)
	check(
		choose(missing, im, "invented") != "" and before == JSON.stringify(missing.state),
		"unknown choice atomic rejection"
	)
	missing.state.settlements = []
	before = JSON.stringify(missing.state)
	check(
		choose(missing, im, "decline") != "" and before == JSON.stringify(missing.state),
		"missing target atomic rejection"
	)
	days(missing, 1)
	check(im.status == "cancelled", "daily cleanup records disappeared target")


func water_chain() -> void:
	for choice in ["decline", "conserve"]:
		var s = make()
		var i: Dictionary = opened(s, "water")
		choose(s, i, choice)
		assert_end(s, i, "水线封存" if choice == "decline" else "配水协议")
	for final_choice in ["flush", "decline", "careful"]:
		var s = make()
		supplies(s)
		var i: Dictionary = opened(s, "water")
		if final_choice == "careful":
			check(choose(s, i, "survey") == "", "water survey reserves real scientists")
			days(s, 5)
			check(
				i.node == "plan" and i.pause_required,
				"water investigation produces mandatory planning node"
			)
		check(choose(s, i, "build") == "", "water improvement uses real building action")
		days(s, 5)
		check(i.status == "waiting", "calendar alone cannot finish construction")
		var build: Dictionary = s.settlement(0).buildings[int(i.variables.building_index)]
		check(build.remaining > 0, "actual pump is still under construction without simulation")
		for k in range(3):
			s.tick()
		check(i.node == "inspection", "actual completed and operating pump triggers inspection")
		check(choose(s, i, final_choice) == "", "water inspection outcome " + final_choice)
		assert_end(s, i, {"flush": "调蓄验收", "decline": "含盐扩张", "careful": "精测验收"}[final_choice])
		check(s.audit().is_empty(), "water construction and outcome conservation")
	var timeout = make()
	var ti: Dictionary = opened(timeout, "water")
	choose(timeout, ti, "build")
	days(timeout, 30)
	assert_end(timeout, ti, "工程未能投入运行")
	var bad = make()
	var bi: Dictionary = opened(bad, "water")
	choose(bad, bi, "build")
	bad.settlement(0).buildings.remove_at(int(bi.variables.building_index))
	days(bad, 1)
	assert_end(bad, bi, "工程目标失效")


func archaeology_chain() -> void:
	var decline = make()
	var di: Dictionary = opened(decline, "archaeology")
	choose(decline, di, "decline")
	assert_end(decline, di, "遗址封存")
	for at_records in [false, true]:
		var s = make()
		var i: Dictionary = opened(s, "archaeology")
		if at_records:
			choose(s, i, "survey")
			days(s, 7)
		var cash: float = float(s.state.cash)
		check(choose(s, i, "sell") == "", "sell investigation rights")
		check(
			float(s.state.cash) > cash and not s.state.ledger[-1].operating,
			"rights sale is one-time nonoperating income"
		)
		var before: String = JSON.stringify(s.state)
		check(
			choose(s, i, "sell") != "" and before == JSON.stringify(s.state),
			"rights cannot be sold twice"
		)
		days(s, 8)
		check(
			i.node == "sale_report" and i.variables.rights_sold,
			"delayed buyer report retains transferred rights"
		)
		check(choose(s, i, "apply") != "", "sold rights cannot receive original scientific reward")
		choose(s, i, "close")
		assert_end(s, i, "调查权转让")
	for final_choice in ["protect", "decline", "apply", "sample_decline"]:
		var s = make()
		var i: Dictionary = opened(s, "archaeology")
		choose(s, i, "survey")
		check(
			int(s.state.research.investigations[i.instance_id].staff) == 3,
			"archaeology reserves three actual people"
		)
		days(s, 7)
		check(
			i.node == "records" and not s.state.research.investigations.has(i.instance_id),
			"research completion releases staff and opens actual records"
		)
		if final_choice in ["apply", "sample_decline"]:
			choose(s, i, "sample")
			days(s, 5)
			choose(s, i, "apply" if final_choice == "apply" else "decline")
		else:
			choose(s, i, final_choice)
		assert_end(
			s,
			i,
			{"protect": "值班簿归档", "decline": "勘探队去向查明", "apply": "样本完成", "sample_decline": "样本保管"}[final_choice]
		)
		check(s.audit().is_empty(), "archaeological outcome money conservation")
	var cancel = make()
	var ci: Dictionary = opened(cancel, "archaeology")
	choose(cancel, ci, "survey")
	check(
		choose(cancel, ci, "cancel") == "" and cancel.state.research.investigations.is_empty(),
		"withdrawal releases investigators"
	)
	assert_end(cancel, ci, "主动撤回调查，现场封存")
	var shortage = make()
	var si: Dictionary = opened(shortage, "archaeology")
	choose(shortage, si, "survey")
	shortage.state.research.investigations[si.instance_id].staff = 0
	days(shortage, 45)
	assert_end(shortage, si, "调查人员不足，现场封存")


func industry_chain() -> void:
	var decline = make()
	var di: Dictionary = opened(decline, "industry")
	choose(decline, di, "decline")
	assert_end(decline, di, "谢绝旺季")
	for final_choice in ["standard", "decline", "reduce", "extend"]:
		var s = make()
		facilities(s)
		var i: Dictionary = opened(s, "industry")
		check(choose(s, i, "accept") == "", "real order signed")
		var cash: float = float(s.state.cash)
		days(s, 1)
		check(
			i.order.dispatched == 0 and i.order.paid == 0,
			"imported inventories cannot satisfy local production order"
		)
		var amount: float = 2.0 if final_choice == "reduce" else 4.0
		s._produce(s.settlement(0), "parts", amount, "加工配方")
		days(s, 1)
		check(
			i.order.dispatched == amount and i.order.delivered == 0 and float(s.state.cash) < cash,
			"dispatch consumes genuine production and fees before reward"
		)
		days(s, 1)
		check(i.node == "review", "order has actual delayed negotiation node")
		check(
			(
				choose(s, i, final_choice if final_choice in ["reduce", "extend"] else "continue")
				== ""
			),
			"order negotiation " + final_choice
		)
		var deadline: int = int(i.order.deadline)
		if final_choice == "extend":
			check(deadline == 34, "single renegotiation extends deadline exactly ten days")
		if final_choice == "reduce":
			check(
				float(i.order.required) == 2,
				"negotiated reduction lowers four-part promise to two actually shipped"
			)
		days(s, 1)
		check(i.order.delivered == 0, "goods cannot arrive one day before voyage completes")
		days(s, 1)
		check(
			i.order.delivered == amount and i.order.paid == amount * 62.0,
			"arrival pays exact delivered quantity at contracted unit price"
		)
		if final_choice == "reduce":
			assert_end(s, i, "协商减量")
		else:
			choose(s, i, "standard" if final_choice == "extend" else final_choice)
			assert_end(s, i, "单次交付" if final_choice == "decline" else "准时交付")
		check(s.audit().is_empty(), "delivered order has full money/material conservation")
	var late = make()
	facilities(late)
	var li: Dictionary = opened(late, "industry")
	choose(late, li, "small")
	days(late, 3)
	choose(late, li, "defer")
	days(late, 6)
	check(li.order.reviewed, "deferred order review executes default without extra grant")
	days(late, 16)
	assert_end(late, li, "逾期按实结清")
	check(li.order.paid == 0, "unproduced undelivered order pays nothing")


func persistence() -> void:
	var s = make()
	facilities(s)
	var i: Dictionary = opened(s, "archaeology")
	choose(s, i, "survey")
	for n in range(3):
		s.tick()
	check(E.validate(s.state) == "", "complete event save validates")
	check(s.save_game("user://v16_event_mid.json") == "", "event mid-investigation atomic save")
	var restored = make()
	var load_error: String = restored.load_game("user://v16_event_mid.json")
	if load_error != "":
		print("LOAD_ERROR ", load_error)
	check(load_error == "", "event mid-investigation loads")
	check(
		JSON.stringify(s.state) == JSON.stringify(restored.state), "event save exact state restored"
	)
	for n in range(4):
		s.tick()
	for n in range(4):
		restored.tick()
	check(
		JSON.stringify(s.state) == JSON.stringify(restored.state),
		"research followup deterministic after save"
	)
	var candidate: Dictionary = s.state.duplicate(true)
	candidate.events_v2.instances[0].definition_id = "unknown"
	check(E.validate(candidate) != "", "unknown persisted definition rejected")
	candidate = s.state.duplicate(true)
	candidate.events_v2.instances[0].scheduled = {
		"kind": "research", "next": "invented", "deadline": 20
	}
	check(E.validate(candidate) != "", "unknown persisted followup rejected")
	var a = make()
	var b = make()
	a.state.events_v2.next_draw = 6
	b.state.events_v2.next_draw = 6
	days(a, 6)
	days(b, 6)
	check(
		a.state.events_v2.instances[0].definition_id == "water",
		"first contract naturally reaches water chain on day six"
	)
	check(
		JSON.stringify(a.state.events_v2) == JSON.stringify(b.state.events_v2),
		"independent random state replays identical draw"
	)


func deferred_nodes() -> void:
	for id in ["water", "archaeology", "industry"]:
		var s = make()
		var i: Dictionary = opened(s, id)
		check(choose(s, i, "defer") == "", "chain explicit defer " + id)
		days(s, 6)
		assert_end(s, i, {"water": "水线封存", "archaeology": "遗址封存", "industry": "谢绝旺季"}[id])
	for target in ["plan", "inspection", "records", "findings", "sale_report"]:
		var s = make()
		supplies(s)
		var i: Dictionary = opened(
			s, "water" if target in ["plan", "inspection"] else "archaeology"
		)
		if target == "sale_report":
			choose(s, i, "sell")
			days(s, 8)
		else:
			choose(s, i, "survey")
			days(s, 5 if target in ["plan", "inspection"] else 7)
			if target == "inspection":
				choose(s, i, "build")
				for n in range(3):
					s.tick()
			if target == "findings":
				choose(s, i, "sample")
				days(s, 5)
		check(i.node == target, "reach deferred chain node " + target)
		check(choose(s, i, "defer") == "", "defer node " + target)
		days(s, 6)
		assert_end(
			s,
			i,
			{
				"plan": "水线封存",
				"inspection": "含盐扩张",
				"records": "勘探队去向查明",
				"findings": "样本保管",
				"sale_report": "调查权转让"
			}[target]
		)


func integrated_production() -> void:
	var s = make()
	for kind in ["mine_ore", "mine_copper", "processor", "power"]:
		check(
			s.act("build", {"region": 0, "kind": kind}) == "",
			"real industrial fixture builds " + kind
		)
	for n in range(10):
		s.tick()
	var i: Dictionary = opened(s, "industry")
	check(choose(s, i, "small") == "", "actual operating industry can accept order")
	var paid_before: float = float(s.state.external_in)
	var replay = null
	for n in range(40):
		if i.status == "pending" and i.node == "review":
			choose(s, i, "continue")
			if replay != null:
				choose(replay, E._instance(replay, i.instance_id), "continue")
		if i.status == "pending" and i.node == "delivered":
			choose(s, i, "standard")
			if replay != null:
				choose(replay, E._instance(replay, i.instance_id), "standard")
		if i.status == "resolved":
			break
		s.tick()
		if replay != null:
			replay.tick()
		elif not i.order.cargo.is_empty():
			check(
				s.save_game("user://v16_event_order_transit.json") == "",
				"actual dispatched order saves in transit"
			)
			replay = Sim.new()
			check(
				replay.load_game("user://v16_event_order_transit.json") == "",
				"actual dispatched order restores in transit"
			)
	check(
		i.ending == "准时交付" and float(i.order.delivered) == 2,
		"normal simulation production and real port deliver contracted parts"
	)
	check(
		float(i.order.paid) == 110 and float(s.state.external_in) > paid_before,
		"normal simulation order has external payer"
	)
	check(s.audit().is_empty(), "actual industrial route conservation")
	check(
		replay != null and JSON.stringify(s.state) == JSON.stringify(replay.state),
		"actual in-transit save replay preserves receipts and all future state"
	)
	print(
		"INTEGRATED_ORDER day=",
		s.state.day,
		" ending=",
		i.ending,
		" order=",
		JSON.stringify(i.order)
	)
	var r = make()
	r.act("build", {"region": 0, "kind": "lab"})
	for n in range(5):
		r.tick()
	check(
		r.act("research_allocate", {"tech": "survey", "staff": 10}) == "",
		"calibration project receives ten actual scientists"
	)
	var ai: Dictionary = opened(r, "archaeology")
	choose(r, ai, "survey")
	r.tick()
	check(
		int(r.state.research.projects.survey.effective) <= 9,
		"three investigators reduce real project allocation from ten"
	)
	choose(r, ai, "cancel")
	check(
		r.act("research_allocate", {"tech": "survey", "staff": 10}) == "",
		"released investigators can be reallocated to ten-person project"
	)
	r.tick()
	check(
		int(r.state.research.projects.survey.effective) == 10,
		"withdrawal and explicit reallocation restore actual project capacity"
	)


func malformed_saves() -> void:
	var s = make()
	var i: Dictionary = opened(s, "archaeology")
	choose(s, i, "survey")
	var cases: Array = [
		[["events_v2"], []],
		[["events_v2", "rng_state"], "oops"],
		[["events_v2", "rng_state"], 0],
		[["events_v2", "next_id"], 0],
		[["events_v2", "instances"], [null]],
		[["events_v2", "seen"], [123]],
		[["events_v2", "instances", 0, "definition_id"], "invented"],
		[["events_v2", "instances", 0, "definition_version"], 99],
		[["events_v2", "instances", 0, "node"], "unknown"],
		[["events_v2", "instances", 0, "target_region"], 99],
		[["events_v2", "instances", 0, "history"], [null]],
		[["events_v2", "instances", 0, "scheduled"], []],
		[["events_v2", "instances", 0, "scheduled", "next"], null],
		[["events_v2", "instances", 0, "scheduled", "deadline"], "tomorrow"],
		[["events_v2", "instances", 0, "variables", "investigation"], []],
		[["events_v2", "instances", 0, "variables", "investigation", "progress"], -1],
		[["events_v2", "instances", 0, "pause_required"], true],
		[["events_v2", "instances", 0, "order"], []],
		[["events_v2", "history"], [null]],
		[["events_v2", "effects"], [null]]
	]
	for mutation in cases:
		var copy: Dictionary = s.state.duplicate(true)
		var cursor: Variant = copy
		for index in range(mutation[0].size() - 1):
			cursor = cursor[mutation[0][index]]
		cursor[mutation[0][-1]] = mutation[1]
		check(E.validate(copy) != "", "reject malformed event save " + str(mutation[0]))
	choose(s, i, "cancel")
	var missing_definition: Dictionary = s.state.duplicate(true)
	missing_definition.events_v2.history[0].erase("definition_id")
	check(
		E.validate(missing_definition) != "",
		"reject ending history without definition needed by view"
	)
