extends SceneTree
## Phase 3 rules: contract stages, attractiveness, immigration, wages, recruitment, births, market
## prices, running costs, road upkeep and closure, aid terms, needs-first imports, depleted mines.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Contract = preload("res://simulation/contract.gd")
const Population = preload("res://simulation/population.gd")
const Market = preload("res://simulation/market.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Company = preload("res://simulation/company.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Rules = preload("res://simulation/rules.gd")

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


func make(difficulty: String = "normal") -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, difficulty)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


func run() -> void:
	_stages()
	_licence_gate()
	_deadlines_feed_company()
	_difficulty_scales_goals()
	_enterprise_gate()
	_attractiveness()
	_immigration()
	_wages()
	_recruitment()
	_births()
	_market()
	_running_costs()
	_roads()
	_aid_terms()
	_needs_first()
	_depleted_mines()
	_forecast()
	print("V17_CONTRACT_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _stages() -> void:
	var sim: RefCounted = make()
	check(int(sim.state.contract.stage) == 1, "contract starts at stage one")
	var goals: Array = Contract.stage_goals(sim, 1)
	check(goals.size() == 5, "stage one lists its goals")
	sim.state.exports_total = 3000.0
	sim.settlement(0).food_days = 12.0
	sim.state.research.projects.survey = {
		"staff": 3, "work": 0.0, "effective": 3, "rate": 1.0, "reason": ""
	}
	sim.state.contract.stage_streak = 10
	sim.state.day = 5
	var cash: float = float(sim.state.cash)
	var net: float = float(sim.state.operating_net)
	Contract.daily(sim)
	check(int(sim.state.contract.stage) == 2, "meeting every goal completes the stage")
	check(is_equal_approx(float(sim.state.cash), cash + 1500.0), "stage reward paid")
	check(
		is_equal_approx(float(sim.state.operating_net), net), "stage reward is not operating income"
	)
	check(sim.state.contract.licences.has("expedition"), "stage one grants the expedition licence")
	check(int(sim.state.contract.stage_streak) == 0, "the streak restarts with each stage")
	check(int(sim.state.contract.completed["1"]) == 5, "stage day recorded")
	check(sim.audit().is_empty(), "reward keeps the audit clean")
	var last: RefCounted = make()
	last.state.contract.stage = 3
	check(last.state.status == "active", "still active before the last stage")
	var rules: Dictionary = last.contract_rules.duplicate(true)
	rules.stages[2].goals = {"settlements": 1}
	last.contract_rules = rules
	Contract.daily(last)
	check(last.state.status == "success", "stage three grants governor qualification")
	check(int(last.state.success_day) == int(last.state.day), "award day recorded")
	check(Contract.settlement_cap(last) >= 2, "award opens further settlements")
	var taxed: float = float(last.state.company_tax_total)
	last.act("build", {"region": 0, "kind": "mine_ore"})
	for _i: int in range(8):
		last.tick()
	check(float(last.state.company_tax_total) > taxed, "the company share starts after the award")
	check(float(make().state.company_tax_total) == 0.0, "no company share before the award")


func _licence_gate() -> void:
	var sim: RefCounted = make()
	var error: String = sim.act("settle", {"region": 1})
	check(error.contains("许可"), "second settlement needs the licence: " + error)
	sim.state.contract.licences.append("expedition")
	check(sim.act("settle", {"region": 1}) == "", "the licence opens the second settlement")
	check(int(sim.settlement(1).housing) == 24, "outpost landing housing")
	check(int(sim.settlement(0).housing) == 60, "capital landing housing")


func _deadlines_feed_company() -> void:
	var sim: RefCounted = make()
	check(not Contract.overdue(sim), "not overdue before the deadline")
	sim.state.day = 91
	check(Contract.overdue(sim), "overdue after the stage one deadline")
	Company.tick(sim)
	check(
		float(sim.state.company.sources.economic.rate) > 0.0,
		"a missed deadline is an economic risk"
	)
	check(sim.state.status != "failed", "a missed deadline never fails the game by itself")
	var quick: RefCounted = make("hard")
	quick.state.day = 76
	check(Contract.overdue(quick), "hard has an earlier deadline")
	var slow: RefCounted = make("easy")
	slow.state.day = 100
	check(not Contract.overdue(slow), "easy has a later deadline")


func _difficulty_scales_goals() -> void:
	check(int(Contract.goal_target(make("easy"), 3, "population")) == 144, "easy population goal")
	check(
		int(Contract.goal_target(make("normal"), 3, "population")) == 180,
		"standard population goal"
	)
	check(int(Contract.goal_target(make("hard"), 3, "population")) == 216, "hard population goal")
	check(
		is_equal_approx(Contract.goal_target(make("hard"), 3, "employment"), 0.6),
		"ratios do not scale"
	)


func _enterprise_gate() -> void:
	var sim: RefCounted = make()
	check(float(sim.enterprise_preview(0).estimated_profit) >= 0.0, "capital has enough demand")
	check(sim.act("enterprise", {"region": 0}) == "", "no waiting gate for the enterprise")
	var small: RefCounted = make()
	var place: Dictionary = small.settlement(0)
	place.workers = 20
	place.children = 0
	place.scientists = 0
	place.population = 20
	var error: String = small.act("enterprise", {"region": 0})
	check(error.contains("需求"), "too small a town refuses the licence: " + error)


func _attractiveness() -> void:
	var sim: RefCounted = make()
	var place: Dictionary = sim.settlement(0)
	place.food_days = 20.0
	place.jobs = 40
	place.employed = 40
	var crowded: Dictionary = Population.attractiveness(sim, place)
	check(
		crowded.parts.has("beds") and float(crowded.parts.beds) < 0.0, "no free beds lowers appeal"
	)
	place.housing = 200
	var roomy: Dictionary = Population.attractiveness(sim, place)
	check(float(roomy.value) > float(crowded.value), "free beds raise appeal")
	place.food_days = 1.0
	var hungry: Dictionary = Population.attractiveness(sim, place)
	check(float(hungry.value) < float(roomy.value), "food shortage lowers appeal")
	check(float(hungry.value) >= 0.0 and float(hungry.value) <= 2.0, "appeal stays in range")


func _immigration() -> void:
	var sim: RefCounted = make()
	var place: Dictionary = sim.settlement(0)
	var before: int = int(place.population)
	for _i: int in range(10):
		sim.tick()
	check(int(place.population) <= int(place.housing), "arrivals never exceed free beds")
	check(int(sim.state.immigrants_total) == 0, "a full town gets no arrivals")
	check(int(place.population) == before, "population holds while the town is full")
	var open: RefCounted = make()
	var home: Dictionary = open.settlement(0)
	home.buildings.append(open._building("habitat", 0))
	open._refresh(home)
	var savings: float = float(open.state.resident_cash)
	for _i: int in range(60):
		open.tick()
	check(int(open.state.immigrants_total) > 5, "free beds bring people")
	check(
		float(open.state.resident_cash) != savings,
		"arrivals bring savings into the resident account"
	)
	check(open.audit().is_empty(), "immigration keeps the audit clean")


func _arrivals_with_wage(wage: float) -> int:
	var sim: RefCounted = make()
	var home: Dictionary = sim.settlement(0)
	for _i: int in range(6):
		home.buildings.append(sim._building("habitat", 0))
	sim._refresh(home)
	sim.state.cash = 500000.0
	sim.state.initial_money = float(sim.state.initial_money) + 500000.0 - 0.0
	sim.act("policy", {"wage": wage})
	for _i: int in range(180):
		sim.tick()
	return int(sim.state.immigrants_total)


func _wages() -> void:
	var low: int = _arrivals_with_wage(1.0)
	var high: int = _arrivals_with_wage(1.3)
	check(
		float(high) >= float(low) * 1.2,
		"1.3x wages bring at least 20%% more arrivals: %d vs %d" % [high, low]
	)
	var sim: RefCounted = make()
	sim.act("policy", {"wage": 9.0})
	check(is_equal_approx(float(sim.state.policy.wage), 1.6), "wage policy is capped")
	sim.act("policy", {"wage": 0.1})
	check(is_equal_approx(float(sim.state.policy.wage), 0.8), "wage policy has a floor")
	sim.act("policy", {"wage": 1.0})
	sim.act("build", {"region": 0, "kind": "mine_ore"})
	for _i: int in range(5):
		sim.tick()
	var paid: float = 0.0
	for entry: Dictionary in sim.state.ledger:
		if entry.key == "wages.public" and int(entry.day) == int(sim.state.day):
			paid += float(entry.amount)
	var doubled: RefCounted = make()
	doubled.act("policy", {"wage": 1.5})
	doubled.act("build", {"region": 0, "kind": "mine_ore"})
	for _i: int in range(5):
		doubled.tick()
	var paid_more: float = 0.0
	for entry: Dictionary in doubled.state.ledger:
		if entry.key == "wages.public" and int(entry.day) == int(doubled.state.day):
			paid_more += float(entry.amount)
	check(is_equal_approx(paid_more, paid * 1.5), "wage policy scales what is paid")


func _recruitment() -> void:
	var sim: RefCounted = make()
	var home: Dictionary = sim.settlement(0)
	check(
		sim.act("recruit", {"region": 0, "kind": "worker", "count": 5}).contains("床位"),
		"recruits need beds"
	)
	home.buildings.append(sim._building("habitat", 0))
	sim._refresh(home)
	var cash: float = float(sim.state.cash)
	var price: float = Population.campaign_price(sim, "worker")
	check(is_equal_approx(price, 120.0), "first campaign at the listed price")
	check(
		sim.act("recruit", {"region": 0, "kind": "worker", "count": 5}) == "", "campaign accepted"
	)
	check(is_equal_approx(float(sim.state.cash), cash - 600.0), "campaign paid at once")
	check(
		is_equal_approx(Population.campaign_price(sim, "worker"), 132.0),
		"the next campaign costs 10% more"
	)
	check(
		Population.free_beds(sim, home) == int(home.housing) - int(home.population) - 5,
		"beds reserved"
	)
	var workers: int = int(home.workers)
	for _i: int in range(9):
		sim.tick()
	check(
		int(home.workers) >= workers and sim.state.recruits.size() == 1,
		"still travelling on day nine"
	)
	sim.tick()
	check(
		sim.state.recruits.is_empty() and int(home.workers) >= workers + 5,
		"recruits arrive after ten days"
	)
	check(
		sim.act("recruit", {"region": 0, "kind": "scientist", "count": 99}) != "",
		"campaign size is limited"
	)
	check(sim.audit().is_empty(), "recruitment keeps the audit clean")
	sim.state.day = 200
	check(
		is_equal_approx(Population.campaign_price(sim, "worker"), 120.0),
		"the price recovers after 90 days"
	)


func _births() -> void:
	var sim: RefCounted = make()
	var home: Dictionary = sim.settlement(0)
	home.buildings.append(sim._building("habitat", 0))
	sim._refresh(home)
	var children: int = int(home.children)
	home.workers = 400
	home.population = int(home.workers) + int(home.scientists) + children
	home.housing = 1000
	home.base_housing = 1000
	for _i: int in range(100):
		Population._births(sim, home)
	check(
		int(home.children) == children + 1,
		"about 1% of adults a year: one birth in 100 days at 400 adults"
	)
	check(
		int(home.population) == int(home.children) + int(home.workers) + int(home.scientists),
		"partition holds"
	)


func _market() -> void:
	var sim: RefCounted = make()
	check(is_equal_approx(Market.price(sim, "ore"), 8.0), "no exports, full price")
	Market.record_export(sim, "ore", 1500.0)
	check(is_equal_approx(Market.price(sim, "ore"), 8.0 * 0.8), "saturation lowers the price")
	Market.record_export(sim, "ore", 900000.0)
	check(is_equal_approx(Market.factor(sim, "ore"), 0.6), "the price has a floor")
	var before: float = float(sim.state.market.saturation.ore)
	Market.daily(sim)
	check(float(sim.state.market.saturation.ore) < before, "saturation decays")
	check(is_equal_approx(Market.price(sim, "food"), 3.0), "food has no export market")


func _running_costs() -> void:
	var sim: RefCounted = make()
	var residents: int = int(sim.settlement(0).population)
	check(
		is_equal_approx(sim._admin_cost(), 5.0 + 0.04 * residents + 3.0),
		"administration grows with the colony"
	)


func _roads() -> void:
	var sim: RefCounted = make()
	sim.state.contract.licences.append("expedition")
	sim.state.settlements[0].stock.materials = 200.0
	check(sim.act("settle", {"region": 1}) == "", "outpost for the road test")
	check(sim.act("connect", {"a": 0, "b": 1, "mountain": true}) == "", "engineered road built")
	check(
		int(sim.state.route.capacity) == 42 and is_equal_approx(float(sim.state.route.upkeep), 5.0),
		"engineered figures"
	)
	var closed: int = 0
	for _i: int in range(1200):
		sim.state.day = int(sim.state.day) + 1
		if int(sim.state.route.get("blocked_until", 0)) < int(sim.state.day):
			var before: int = int(sim.state.route.get("blocked_until", 0))
			Logistics.road_daily(sim)
			if int(sim.state.route.blocked_until) != before:
				closed += 1
	check(closed >= 3 and closed <= 25, "rockfall about once per 120 days: %d in 1200" % closed)
	var calm: RefCounted = make()
	calm.state.contract.licences.append("expedition")
	calm.act("settle", {"region": 1})
	calm.act("connect", {"a": 0, "b": 1, "mountain": false})
	check(
		(
			int(calm.state.route.capacity) == 28
			and is_equal_approx(float(calm.state.route.upkeep), 1.5)
		),
		"valley figures"
	)
	var net: float = float(calm.state.operating_net)
	for _i: int in range(300):
		calm.state.day = int(calm.state.day) + 1
		Logistics.road_daily(calm)
	check(int(calm.state.route.get("blocked_until", 0)) == 0, "a valley road does not close")
	check(float(calm.state.operating_net) < net, "road upkeep is an operating cost")


func _aid_terms() -> void:
	var sim: RefCounted = make()
	var prices: Dictionary = sim.config.prices
	for key: String in sim.progression.company.offers:
		var offer: Dictionary = sim.progression.company.offers[key]
		var value: float = (
			float(offer.cash)
			+ float(offer.food) * float(prices.food)
			+ float(offer.materials) * float(prices.materials)
			+ float(offer.parts) * float(prices.parts)
		)
		check(float(offer.repayment) >= value * 0.9, "aid buys time, not money: " + key)


func _needs_first() -> void:
	var sim: RefCounted = make()
	var home: Dictionary = sim.settlement(0)
	sim.state.day = 1
	home.port_capacity = 10.0
	sim._consume(home, "food", float(home.stock.food))
	sim._produce(home, "ore", 500.0, "test stock")
	home.food_days = 0.0
	Logistics.trade(sim, home)
	check(float(home.stock.food) >= 9.9, "food takes the port before ore does")
	check(float(home.stock.ore) >= 499.9, "ore waits when the port is full")
	check(sim.audit().is_empty(), "needs-first trade keeps the audit clean")


func _depleted_mines() -> void:
	var sim: RefCounted = make()
	sim.act("build", {"region": 0, "kind": "mine_ore"})
	for _i: int in range(5):
		sim.tick()
	var region: Dictionary = sim.state.world.regions[0]
	region.deposits.ore = 0.0
	sim.tick()
	var mine: Dictionary = {}
	for building: Dictionary in sim.settlement(0).buildings:
		if building.kind == "mine_ore":
			mine = building
	check(mine.status == "depleted" and int(mine.employed) == 0, "a depleted mine lets its crew go")
	check(
		int(mine.employed) == 0 and sim.free_workers(sim.settlement(0)) > 0,
		"its jobs stop counting"
	)


func _forecast() -> void:
	var sim: RefCounted = make()
	var mine: Dictionary = sim.build_forecast(0, "mine_ore")
	check(
		float(mine.net_per_day) > 0.0 and float(mine.payback_days) > 0.0,
		"a mine forecast shows net and payback"
	)
	check(float(mine.reserve_days) > 0.0, "a mine forecast shows how long reserves last")
	check(mine.disabled_reason == "", "an affordable mine is enabled")
	var habitat: Dictionary = sim.build_forecast(0, "habitat")
	check(float(habitat.payback_days) < 0.0, "housing has no payback of its own")
	var processor: Dictionary = sim.build_forecast(0, "processor")
	check(
		float(processor.net_per_day) >= 15.0 and float(processor.net_per_day) <= 40.0,
		"the processor earns about 20-35 a day: %.1f" % float(processor.net_per_day)
	)
	check(float(processor.payback_days) <= 90.0, "the processor pays back within about 60 days")
	sim.state.cash = 0.0
	check(sim.build_forecast(0, "mine_ore").disabled_reason != "", "unaffordable options say why")
	check(Rules.read("market").has("version"), "rule files carry a version")
