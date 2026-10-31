extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
var failures: int = 0
var checks: int = 0
var Sim: Script


func _init() -> void:
	Watchdog.arm(self)
	if not FileAccess.file_exists("res://simulation/sim.gd"):
		check(false, "simulation API exists")
		quit(1)
		return
	Sim = load("res://simulation/sim.gd")
	if Sim == null:
		check(false, "simulation parses")
		quit(1)
		return
	run_tests()
	_boundary_tests()
	print("SIM_TEST_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)


func close(a: float, b: float) -> bool:
	return absf(a - b) < 0.00001


func equivalent(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true, true) == JSON.stringify(b, "", true, true)


## Sites have no fixed roles now: the first one alone on its landmass stands for the island.
func island_site(sim) -> int:
	for reg in sim.state.world.regions:
		if reg.neighbors.is_empty():
			return int(reg.id)
	return -1


func make(advantage: String = "capital"):
	var s = Sim.new()
	s.new_game(20261029, advantage, 1)
	s.state.contract.licences.append("expedition")
	return s


func run_tests() -> void:
	var a = make()
	check(a.state.status == "planning", "new game waits for landing")
	var before: String = JSON.stringify(a.state)
	a.tick()
	check(JSON.stringify(a.state) == before, "planning cannot advance time")
	check(a.act("settle", {"region": 0}) == "", "land mining basin")
	check(
		a.act("build", {"region": 0, "kind": "mine_ore"}) == "", "initial ore extraction available"
	)
	for i in range(12):
		a.tick()
	check(a.state.exports_total > 0, "first export is real external income")
	check(
		(
			(
				a.state.external_in
				- a.state.external_out
				+ a.state.initial_money
				- a.state.cash
				- a.state.resident_cash
				- a.state.enterprise_cash
			)
			< 0.00001
		),
		"cash identity has no unexplained creation"
	)
	check(a.audit().is_empty(), "accounting and population audit")
	var s = a.state.settlements[0]
	var saved_cash: float = a.state.cash
	var saved_stock: Dictionary = s.stock.duplicate(true)
	s.stock.materials = 0.0
	check(
		a.act("build", {"region": 0, "kind": "processor"}) != "",
		"construction cannot conjure materials"
	)
	check(close(saved_cash, a.state.cash), "rejected construction takes no cash")
	s.stock = saved_stock
	check(
		a.act("settle", {"region": island_site(a)}) != "",
		"cannot establish disconnected ocean outpost"
	)
	check(a.act("settle", {"region": 1}) == "", "second land outpost possible")
	check(a.act("connect", {"a": 0, "b": 1, "mountain": false}) == "", "build actual land route")
	for wait_day in range(10):
		a.tick()
	check(a.act("build", {"region": 1, "kind": "farm"}) == "", "fertile valley farm")
	check(a.act("build", {"region": 0, "kind": "mine_copper"}) == "", "copper opening available")
	for i in range(18):
		a.tick()
	check(a.state.transported_total > 0, "goods arrive through physical route")
	check(a.act("enterprise", {"region": 0}) == "", "private investor arrives")
	for i in range(20):
		if not a.state.event.is_empty():
			a.act("event", {"choice": a.state.event.choices[0].id})
		a.tick()
	check(a.state.enterprise.sales_total > 0, "enterprise operates automatically")
	check(a.state.enterprise.wages_total > 0, "enterprise pays real wages")
	check(a.state.enterprise.tax_total > 0, "enterprise pays local profit tax")
	check(a.audit().is_empty(), "full loop accounting and population conservation")
	check(a.save_game("res://../evidence/v17/tests/sim_test_save.json") == "", "atomic save")
	var b = make()
	check(
		b.load_game("res://../evidence/v17/tests/sim_test_save.json") == "", "load whole simulation"
	)
	check(equivalent(a.state, b.state), "save restore exact JSON state")
	FileAccess.open("res://../evidence/v17/tests/before_debug.json", FileAccess.WRITE).store_string(
		JSON.stringify(a.state, "  ", true, true)
	)
	FileAccess.open("res://../evidence/v17/tests/after_debug.json", FileAccess.WRITE).store_string(
		JSON.stringify(b.state, "  ", true, true)
	)
	for i in range(15):
		if not a.state.event.is_empty():
			var choice: String = a.state.event.choices[0].id
			a.act("event", {"choice": choice})
			b.act("event", {"choice": choice})
		a.tick()
		b.tick()
	check(equivalent(a.state, b.state), "continuation preserves all future outcomes")
	for advantage in ["capital", "workers", "science"]:
		var opening = make(advantage)
		opening.act("settle", {"region": 0})
		opening.act("build", {"region": 0, "kind": "mine_ore"})
		opening.act("build", {"region": 0, "kind": "mine_copper"})
		if advantage == "science":
			check(
				opening.act("build", {"region": 0, "kind": "lab"}) == "",
				"science opening builds academy"
			)
			check(
				(
					opening.act(
						"research_allocate",
						{
							"tech": "survey",
							"staff": mini(10, int(opening.research_view().available))
						}
					)
					== ""
				),
				"science opening starts research"
			)
		for d in range(90):
			if not opening.state.event.is_empty():
				opening.act("event", {"choice": opening.state.event.choices[0].id})
			opening.tick()
		check(
			opening.state.status != "failed" and opening.state.cash > 300,
			"survival opening " + advantage
		)
		if advantage == "science":
			check(
				opening.state.research.completed.has("survey"),
				"scientists deliver early useful technology"
			)
		check(opening.audit().is_empty(), "opening audit " + advantage)
	var dry = make()
	dry.act("settle", {"region": 0})
	dry.state.cash = 0.0
	dry.state.resident_cash = 0.0
	for building in dry.state.settlements[0].buildings:
		building.enabled = false
	dry.state.settlements[0].stock.food = 0.0
	for i in range(3):
		dry.tick()
	check(dry.state.status != "failed", "temporary payment failure has grace")
	for i in range(20):
		dry.tick()
	check(
		dry.state.status != "failed" and dry.state.company.stage in ["warning", "review"],
		"sustained supply collapse enters company process before takeover"
	)
	for i in range(120):
		dry.tick()
	check(dry.state.status == "failed", "unresolved collapse eventually reaches takeover")
	var bad = FileAccess.open("res://../evidence/v17/tests/invalid_save.json", FileAccess.WRITE)
	bad.store_string('{"version":1,"state":{}}')
	bad.close()
	var keep: String = JSON.stringify(b.state)
	check(
		b.load_game("res://../evidence/v17/tests/invalid_save.json") != "", "reject malformed save"
	)
	check(JSON.stringify(b.state) == keep, "failed load never replaces active state")
	for advantage in ["capital", "workers", "science"]:
		_scenario(advantage)


func _scenario(advantage: String) -> void:
	var s = Sim.new()
	s.new_game(260129, advantage, 1)
	s.state.contract.licences.append("expedition")
	check(s.act("settle", {"region": 0}) == "", "scenario land " + advantage)
	check(s.act("build", {"region": 0, "kind": "mine_ore"}) == "", "scenario iron " + advantage)
	check(
		s.act("build", {"region": 0, "kind": "mine_copper"}) == "", "scenario copper " + advantage
	)
	if advantage == "science":
		check(s.act("build", {"region": 0, "kind": "lab"}) == "", "scenario science academy")
		s.act(
			"research_allocate",
			{"tech": "survey", "staff": mini(10, int(s.research_view().available))}
		)
	var first_success: int = -1
	var violations: int = 0
	var processing_built: bool = false
	var farm_built: bool = false
	for day in range(1, 181):
		if day == 16:
			check(
				s.act("enterprise", {"region": 0}) == "", "scenario private investment " + advantage
			)
		if day == 24:
			check(s.act("settle", {"region": 1}) == "", "scenario expedition " + advantage)
			check(
				s.act("connect", {"a": 0, "b": 1, "mountain": false}) == "",
				"scenario road " + advantage
			)
		if day >= 28 and not farm_built:
			farm_built = s.act("build", {"region": 1, "kind": "farm"}) == ""
		if day == 70:
			check(farm_built, "scenario valley farm " + advantage)
		if day >= 45 and day <= 150 and not processing_built:
			var quote: Dictionary = s.build_preview(0, "processor")
			if float(s.state.cash) >= float(quote.cost) + 300:
				processing_built = s.act("build", {"region": 0, "kind": "processor"}) == ""
		if day == 60 and advantage != "science":
			check(
				s.act("build", {"region": 0, "kind": "lab"}) == "", "scenario academy " + advantage
			)
			s.act(
				"research_allocate",
				{"tech": "survey", "staff": mini(10, int(s.research_view().available))}
			)
		if not s.state.event.is_empty():
			var choice: String = s.state.event.choices[0].id
			if s.act("event", {"choice": choice}) != "":
				s.act("event", {"choice": s.state.event.choices[1].id})
		s.tick()
		if not s.audit().is_empty():
			violations += 1
			if violations < 3:
				print("AUDIT ", advantage, " ", day, " ", s.audit())
		if day == 29 and advantage == "capital":
			check(
				s.save_game("res://../evidence/v17/tests/acceptance_midgame.json") == "",
				"write real action midgame save"
			)
		if s.state.status == "success" and first_success < 0:
			first_success = day
			if advantage == "capital":
				check(
					s.save_game("res://../evidence/v17/tests/acceptance_success.json") == "",
					"write real action success save"
				)
		if s.state.status == "failed":
			break
	print(
		"SCENARIO ",
		advantage,
		" day=",
		s.state.day,
		" status=",
		s.state.status,
		" success_day=",
		first_success,
		" cash=",
		snappedf(s.state.cash, 0.01),
		" total_tax=",
		snappedf(s.state.company_tax_total, 0.01),
		" progress=",
		s.contract_progress()
	)
	check(
		processing_built,
		"scenario processing built by day150 with 300 liquidity reserve " + advantage
	)
	check(violations == 0, "daily full-loop invariants " + advantage)


func _boundary_tests() -> void:
	var s = make()
	var planned: String = JSON.stringify(s.state, "", true, true)
	check(
		s.act("settle", {"region": island_site(s)}) != "",
		"isolated island cannot trap initial contract"
	)
	check(JSON.stringify(s.state, "", true, true) == planned, "rejected island landing atomic")
	s.act("settle", {"region": 0})
	s.act("build", {"region": 0, "kind": "mine_ore"})
	for i in range(5):
		s.tick()
	var home: Dictionary = s.settlement(0)
	for building in home.buildings:
		if building.kind == "power":
			building.enabled = false
	var mined: float = s.state.resource_sources.ore
	s.tick()
	check(close(mined, s.state.resource_sources.ore), "zero electricity stops extraction")
	for building in home.buildings:
		if building.kind == "power":
			building.enabled = true
		if building.kind == "water":
			building.enabled = false
	s.tick()
	check(close(mined, s.state.resource_sources.ore), "zero water stops extraction")
	for building in home.buildings:
		building.enabled = true
	home.workers = 0
	home.population = int(home.children) + int(home.scientists)
	s.tick()
	check(close(mined, s.state.resource_sources.ore), "zero workers stops extraction")
	var workforce = make()
	workforce.act("settle", {"region": 0})
	workforce.state.settlements[0].workers = 20
	workforce.state.settlements[0].population = 36
	var before: String = JSON.stringify(workforce.state, "", true, true)
	check(
		workforce.act("settle", {"region": 1}) != "", "insufficient expedition workforce rejected"
	)
	check(
		JSON.stringify(workforce.state, "", true, true) == before,
		"failed expedition neither debits funds nor consumes inventory"
	)
	var finite = make()
	finite.act("settle", {"region": 0})
	finite.act("build", {"region": 0, "kind": "mine_crystal"})
	var seam: Dictionary = finite.state.world.regions[0].plots[int(
		finite.settlement(0).buildings.back().plot
	)]
	finite.state.world.regions[0].deposits.crystal -= float(seam.reserves) - 0.25
	seam.reserves = 0.25
	for i in range(int(finite.config.buildings.mine_crystal.days) + 3):
		finite.tick()
	check(
		close(finite.state.resource_sources.crystal, 0.25),
		"finite mineral exhaustion never overproduces"
	)
	check(close(float(seam.reserves), 0.0), "finite deposit reaches zero")
	var process = make()
	process.act("settle", {"region": 0})
	process.act("build", {"region": 0, "kind": "processor"})
	var material: float = process.state.resource_sources.materials
	for i in range(8):
		process.tick()
	check(
		close(material, process.state.resource_sources.materials),
		"processor cannot make goods without recipe inputs"
	)
	var travel = make()
	travel.act("settle", {"region": 0})
	check(travel.act("settle", {"region": 1}) == "", "logistics fixture starts expedition")
	check(close(travel.settlement(1).stock.food, 0.0), "destination cannot consume in-flight food")
	check(travel.state.shipments.size() == 3, "expedition stores three physical batches")
	var span: int = int(travel.state.shipments[0].remaining)
	for i in range(span - 1):
		travel.tick()
	check(
		close(travel.settlement(1).stock.food, 0.0), "food does not arrive before travel duration"
	)
	travel.tick()
	check(travel.settlement(1).stock.food > 90, "food arrives on scheduled date then consumes once")
	check(travel.audit().is_empty(), "expedition transfer conserves funds goods and population")
	var future = make()
	future.act("settle", {"region": 0})
	future.state.status = "success"
	future.state.success_day = 0
	future.state.resident_cash = 0.0
	future.state.day = 100
	future.tick()
	check(
		future.state.operating_net < 0 and close(future.state.company_tax_total, 0.0),
		"no governor profit tax on loss day fixture"
	)
	var pay = make()
	pay.act("settle", {"region": 0})
	pay.state.cash = 0.0
	pay.state.resident_cash = 0.0
	for b in pay.settlement(0).buildings:
		b.enabled = false
	# Stored food sustains life; only unpaid administrative invoices trigger this case.
	for i in range(int(pay.config.contract.grace_days) - 1):
		pay.tick()
	check(pay.state.status != "failed", "invoice grace remains open through penultimate day")
	pay.tick()
	check(
		pay.state.status != "failed" and pay.state.company.distrust > 0,
		"legacy invoice boundary now enters visible company scrutiny"
	)
	var expire = make()
	expire.act("settle", {"region": 0})
	expire.state.day = (
		int(expire.config.contract.deadline) + int(expire.config.contract.deadline_grace) - 1
	)
	expire.tick()
	check(
		expire.state.status != "failed" and expire.state.company.distrust > 0,
		"contract old boundary cannot bypass new review window"
	)
