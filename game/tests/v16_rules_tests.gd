extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const R = preload("res://simulation/research.gd")
const C = preload("res://simulation/company.gd")
var failures: int = 0
var checks: int = 0
var results: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)


func make():
	var sim = Sim.new()
	sim.new_game(260129, "science", 1)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


func step(sim, n: int) -> void:
	for i in range(n):
		sim.tick()


func _init() -> void:
	Watchdog.arm(self)
	check(absf(R.rate(5) / R.rate(10) - 0.6) < 0.0000001, "R5/R10=0.6")
	check(
		R.rate(0) == 0 and R.rate(20) > R.rate(10) and R.rate(20) < 2 * R.rate(10),
		"zero and diminishing monotonic research"
	)
	var concentrated: Dictionary = research_path(false)
	var parallel: Dictionary = research_path(true)
	results.research = {"concentrated": concentrated, "parallel": parallel}
	check(concentrated.first < parallel.first, "concentration delivers first tech earlier")
	check(parallel.last < concentrated.last, "five plus five completes two equal projects earlier")
	var s = make()
	s.act("build", {"region": 0, "kind": "lab"})
	step(s, 5)
	s.act("research_allocate", {"tech": "survey", "staff": 5})
	step(s, 3)
	var work: float = s.state.research.projects.survey.work
	s.act("research_allocate", {"tech": "survey", "staff": 0})
	step(s, 2)
	check(s.state.research.projects.survey.work == work, "pause preserves work zero output")
	s.act("research_allocate", {"tech": "survey", "staff": 10})
	check(s.research_reserve("fixture", 6) == "", "field investigation reserves real scientists")
	check(
		s.state.research.projects.survey.staff == 6,
		"investigation shrinks project allocation without duplicates"
	)
	s.research_release("fixture")
	check(
		s.act("research_allocate", {"tech": "survey", "staff": 10}) == "",
		"staff released can return to project"
	)
	for b in s.settlement(0).buildings:
		if b.kind == "lab":
			b.enabled = false
	step(s, 1)
	check(s.state.research.projects.survey.work == work, "disabled lab blocks research")
	check(
		s.save_game("res://../evidence/v17/tests/research_resume.json") == "",
		"research save writes"
	)
	var loaded = Sim.new()
	check(
		loaded.load_game("res://../evidence/v17/tests/research_resume.json") == "",
		"research load validates"
	)
	check(var_to_bytes(s.state) == var_to_bytes(loaded.state), "research exact state persists")
	step(s, 1)
	step(loaded, 1)
	check(var_to_bytes(s.state) == var_to_bytes(loaded.state), "research exact continuation")
	company_paths()
	postmining()
	results.checks = checks
	results.failures = failures
	(
		FileAccess
		. open("res://../evidence/v17/tests/rules_results.json", FileAccess.WRITE)
		. store_string(JSON.stringify(results, "\t"))
	)
	print("V16_RULES ", JSON.stringify(results))
	quit(1 if failures else 0)


func research_path(split: bool) -> Dictionary:
	var s = make()
	s._transfer("external", "public", 20000.0, "test controlled research funding", false)
	s.config.techs.survey.cost = 12.0
	s.config.techs.irrigation.cost = 12.0
	s.act("build", {"region": 0, "kind": "lab"})
	step(s, 5)
	s.act("research_allocate", {"tech": "survey", "staff": 5 if split else 10})
	if split:
		s.act("research_allocate", {"tech": "irrigation", "staff": 5})
	var first: int = -1
	var last: int = -1
	for day in range(1, 40):
		s.tick()
		if first < 0 and s.state.research.completed.size() > 0:
			first = day
			if not split:
				s.act("research_allocate", {"tech": "irrigation", "staff": 10})
		if s.state.research.completed.size() == 2:
			last = day
			break
	return {"first": first, "last": last}


func company_paths() -> void:
	var s = make()
	s._transfer("public", "external", s.state.cash, "test fund exhaustion", false)
	s._public_expense(100.0, "test necessary unpaid invoices", "external")
	var stages: Array = []
	for day in range(1, 110):
		s.state.day = day
		s.state.grace_days = day
		C.tick(s)
		if not stages.has(s.state.company.stage):
			stages.append(s.state.company.stage)
		if s.state.status == "failed":
			break
	results.company_failure = {
		"day": s.state.day, "stages": stages, "letters": s.state.company.letters.size()
	}
	check(
		(
			stages.has("warning")
			and stages.has("review")
			and stages.has("intervention")
			and s.state.status == "failed"
		),
		"unresolved debt passes every window before takeover"
	)
	check(s.state.day > 50, "legacy debt boundary cannot skip review window")
	var rescue = make()
	rescue.state.company.stage = "review"
	rescue.state.company.deadline = 40
	rescue.state.company.distrust = 55.0
	rescue._transfer("public", "external", rescue.state.cash, "test low liquidity", false)
	rescue._public_expense(100, "test overdue invoices", "external")
	check(rescue.act("company", {"offer": "liquidity"}) == "", "conditional aid accepted")
	var deadline: int = rescue.state.company.deadline
	check(rescue.act("company", {"offer": "liquidity"}) != "", "aid cannot repeat")
	check(rescue.state.company.deadline == deadline, "repeat cannot extend deadline")
	check(rescue.state.cash == 0, "aid not instant before shipment arrival")
	rescue.state.day = 1
	C.tick(rescue)
	check(rescue.state.cash == 0, "aid still in transit day one")
	rescue.state.day = 2
	rescue.state.operating_net = 0
	C.tick(rescue)
	check(
		rescue.state.cash > 1700 and rescue.state.operating_net == 0,
		"aid delivered as financing not local profit"
	)
	rescue._repay()
	for day in range(3, 65):
		rescue.state.day = day
		C.tick(rescue)
	check(rescue.state.company.aid[0].status == "fulfilled", "aid principal and duration complete")
	check(rescue.state.company.aid[0].paid == 1200, "aid real repayment recorded")
	check(
		rescue.state.company.stage in ["normal", "recovery"],
		"solved risk stops escalation and recovers"
	)
	check(rescue.audit().is_empty(), "aid delivery repayment preserves cash and goods")
	var own = make()
	own.state.company.stage = "review"
	own.state.company.deadline = 20
	own.state.company.distrust = 60.0
	for day in range(1, 15):
		own.state.day = day
		C.tick(own)
	check(
		own.state.company.stage == "recovery" and own.state.company.aid.is_empty(),
		"unaided stable recovery possible"
	)
	var social = make()
	social.state.day = 30
	var home: Dictionary = social.settlement(0)
	home.housing = 1
	home.employed = 0
	for i in range(18):
		C.social_environment(social)
	check(
		social.state.departed_total > 0 and home.population < 60,
		"persistent housing work shortage causes actual offworld departure"
	)
	home.pollution = 80
	check(C.environmental_factor(home) < 1, "pollution lowers local production capacity")
	var before: float = home.pollution
	check(
		(
			social.act("company", {"operation": "cleanup", "region": 0}) == ""
			and home.pollution < before
		),
		"paid cleanup reduces actual pollution"
	)


func postmining() -> void:
	var s = make()
	s._transfer("external", "public", 30000.0, "post mining fixture controlled investment", false)
	var h: Dictionary = s.settlement(0)
	s.state.world.regions[0].fertility = 1.0
	s.state.world.regions[0].temperature = 20.0
	s.state.world.regions[0].deposits = {"ore": 0.0, "copper": 0.0, "crystal": 0.0}
	s.act("build", {"region": 0, "kind": "lab"})
	s.act("research_allocate", {"tech": "adaptation", "staff": 10})
	for day in range(45):
		s.tick()
	check(
		s.state.research.completed.has("adaptation"), "real research unlocks post mining industry"
	)
	check(s.act("build", {"region": 0, "kind": "farm"}) == "", "post mining builds renewable farm")
	check(
		s.act("build", {"region": 0, "kind": "foodworks"}) == "",
		"post mining builds unlocked food export works"
	)
	step(s, 50)
	var revenue: float = 0.0
	for item in s.state.ledger:
		if item.category == "轨道补给局可再生食品订单":
			revenue += float(item.amount)
	results.postmining = {
		"revenue": revenue,
		"food": h.stock.food,
		"mineral_export":
		(
			s.state.resource_sources.ore
			+ s.state.resource_sources.copper
			+ s.state.resource_sources.crystal
		)
	}
	check(revenue > 1500, "renewable processing earns real recurring external payment")
	check(
		s.state.resource_sources.ore == 0 and s.audit().is_empty(),
		"post mining works with exhausted deposits and conserves ledgers"
	)
	check(h.stock.food <= s._target(h, "food") + 1, "target stock halts renewable overproduction")
