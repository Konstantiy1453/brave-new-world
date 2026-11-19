extends SceneTree
## 1.10 mobile engineering crews (plan C1, simulation/crews.gd). A landing has one crew, made from
## its workers, so the town keeps its people; a building waits until a crew works on it and the
## crew takes the oldest project first; a prefabricated kit assembles on its own; training turns a
## worker into a crew; a crew sent to another town travels the link's days and is counted there on
## arrival; a save from before crews gets one for each project under way; the audit checks the
## counts, and crews survive a save. The standing instruction: a project that fixes a shortage the
## town has goes first, even off a project under way (which keeps its progress), then the one the
## player chose to build next (先建), then the oldest; the expected start and finish of every project
## (`Crews.eta`) are the days it really starts and finishes.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Crews = preload("res://simulation/crews.gd")
const SAVE_PATH: String = "user://v110_crews.save"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_landing()
	_one_at_a_time()
	_shortages_first()
	_build_next()
	_training()
	_recruiting()
	_sending()
	_old_save()
	print("V110_CREWS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(20261029, "capital", 1)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(0), good, 600.0, "TEST stock")
	return sim


func _landing() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	var opening: Dictionary = sim.config.openings.capital
	var crews: int = int(sim.pop_rules.crews.opening)
	check(Crews.teams_at(sim, 0).size() == crews, "the landing brings %d crew" % crews)
	check(int(home.crew) == crews, "counted as the town's crew")
	check(
		int(home.workers) == int(opening.workers) - crews,
		"made from its workers (%d workers left)" % int(home.workers)
	)
	check(
		(
			int(home.population)
			== int(home.children) + int(home.workers) + int(home.scientists) + int(home.crew)
		),
		"and the town keeps its people"
	)
	check(sim.audit().is_empty(), "the audit accepts the crew: " + str(sim.audit()))


## Two buildings ordered with one crew: the first is built, the second waits, then follows.
func _one_at_a_time() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	check(sim.act("build", {"site": 0, "kind": "habitat"}) == "", "a first home is ordered")
	check(sim.act("build", {"site": 0, "kind": "water"}) == "", "and a pump after it")
	var first: Dictionary = home.buildings[home.buildings.size() - 2]
	var second: Dictionary = home.buildings.back()
	var first_days: int = int(first.remaining)
	var second_days: int = int(second.remaining)
	sim.tick()
	check(int(first.remaining) == first_days - 1, "the crew works on the older order")
	check(int(second.remaining) == second_days, "the other waits for a crew")
	for _day: int in range(first_days + 1):
		sim.tick()
	check(int(first.remaining) == 0, "the first is finished")
	check(int(second.remaining) < second_days, "and the crew moves on to the next")
	var view: Dictionary = Crews.view(sim)
	check(view.teams.size() == 1 and str(view.teams[0].task) == Crews.BUILD, "the view says so")


## A town short of water: the pump ordered after the housing takes the crew at once, and the
## housing keeps its progress and follows.
func _shortages_first() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	sim.act("build", {"site": 0, "kind": "habitat"})
	var housing: Dictionary = home.buildings.back()
	sim.tick()
	sim.tick()
	var housing_left: int = int(housing.remaining)
	sim.act("build", {"site": 0, "kind": "water"})
	var pump: Dictionary = home.buildings.back()
	var pump_days: int = int(pump.remaining)
	sim._short(home, "water")
	check(Crews.fixes_shortage(sim, home, pump), "a pump fixes a water shortage")
	check(not Crews.fixes_shortage(sim, home, housing), "housing does not")
	sim.tick()
	check(int(pump.remaining) == pump_days - 1, "the pump takes the crew at once")
	check(int(housing.remaining) == housing_left, "the housing it left keeps its progress")
	for _day: int in range(pump_days):
		sim.tick()
	check(int(pump.remaining) == 0, "the pump is finished")
	check(int(housing.remaining) < housing_left, "and the crew goes back to the housing")
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))


## Three orders with one crew: the third, chosen to go next, is built before the second, and
## every project starts and finishes on the days the queue said.
func _build_next() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	sim.act("build", {"site": 0, "kind": "habitat"})
	sim.act("build", {"site": 0, "kind": "water"})
	sim.act("build", {"site": 0, "kind": "lab"})
	var order: Array = home.buildings.slice(home.buildings.size() - 3)
	sim.tick()
	var third: Dictionary = order[2]
	check(
		sim.act("crew_next", {"site": 0, "uid": int(third.uid)}) == "",
		"the laboratory is told to go next"
	)
	check(Crews.chosen_next(sim, 0) == int(third.uid), "and is remembered")
	var view: Dictionary = Crews.view(sim)
	var names: Array = view.waiting.get(0, [])
	check(
		names.size() == 2 and str(names[0]) == str(sim.config.buildings.lab.name),
		"the queue shows it first: " + str(names)
	)
	var plans: Dictionary = Crews.eta(sim, home)
	var started: Dictionary = {}
	var finished: Dictionary = {}
	for _day: int in range(150):
		var before: Array = order.map(func(b: Dictionary) -> int: return int(b.remaining))
		sim.tick()
		for index: int in range(order.size()):
			var b: Dictionary = order[index]
			var uid: int = int(b.uid)
			if int(b.remaining) < int(before[index]) and not started.has(uid):
				started[uid] = int(sim.state.day)
			if int(b.remaining) == 0 and not finished.has(uid):
				finished[uid] = int(sim.state.day)
	check(finished.size() == 3, "all three are finished")
	check(
		int(finished.get(int(third.uid), 0)) < int(finished.get(int(order[1].uid), 0)),
		"the chosen one before the older order"
	)
	for b: Dictionary in order:
		var uid: int = int(b.uid)
		var plan: Dictionary = plans.get(uid, {})
		check(
			(
				int(plan.get("finish", -2)) == int(finished.get(uid, -1))
				and (
					not started.has(uid) or int(plan.get("start", -2)) == int(started.get(uid, -1))
				)
			),
			(
				"%s: expected days %s, built %s to %s"
				% [b.kind, str(plan), str(started.get(uid)), str(finished.get(uid))]
			)
		)
	check(Crews.chosen_next(sim, 0) == 0, "a finished choice is forgotten")
	check(
		sim.act("crew_next", {"site": 0, "uid": int(third.uid)}) != "",
		"and a finished project cannot be chosen"
	)


## A crew recruited from outside reserves a bed, arrives after the campaign's days as one more
## resident, and works as a crew; training (below) keeps the total instead.
func _recruiting() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	sim.act("build", {"site": 0, "kind": "habitat"})
	var housing: Dictionary = home.buildings.back()
	for _day: int in range(int(housing.remaining) + 1):
		sim.tick()
	var teams: int = Crews.teams_at(sim, 0).size()
	var price: float = sim.Population.campaign_price(sim, "crew")
	var cash: float = float(sim.state.cash)
	var beds: int = sim.Population.free_beds(sim, home)
	check(
		sim.act("recruit", {"region": 0, "kind": "crew", "count": 1}) == "",
		"a crew is recruited from outside"
	)
	check(is_equal_approx(cash - float(sim.state.cash), price), "for the campaign's price")
	check(sim.Population.free_beds(sim, home) == beds - 1, "and a bed is kept for it")
	for _day: int in range(int(sim.pop_rules.recruitment.travel_days) - 1):
		sim.tick()
	var people: int = int(home.population)
	var arrived: int = int(sim.state.immigrants_total)
	check(Crews.teams_at(sim, 0).size() == teams, "it is still on its way")
	sim.tick()
	check(Crews.teams_at(sim, 0).size() == teams + 1, "then it arrives as a crew")
	check(int(home.crew) == teams + 1, "counted as the town's crew")
	check(
		(
			int(sim.state.immigrants_total) > arrived
			and int(home.population) - people == int(sim.state.immigrants_total) - arrived
		),
		"as one more resident"
	)
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))


## Training keeps the town's people and gives a crew that works once trained.
func _training() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	var people: int = int(home.population)
	var cash: float = float(sim.state.cash)
	check(sim.act("crew_train", {"region": 0}) == "", "a worker is sent for training")
	check(int(home.population) == people, "the town keeps its people")
	check(int(home.crew) == int(sim.pop_rules.crews.opening) + 1, "and has one more crew")
	check(
		is_equal_approx(cash - float(sim.state.cash), float(sim.pop_rules.crews.train_cost)),
		"for the training fee"
	)
	sim.act("build", {"site": 0, "kind": "habitat"})
	sim.act("build", {"site": 0, "kind": "water"})
	var waiting: Dictionary = sim.settlement(0).buildings.back()
	var before: int = int(waiting.remaining)
	sim.tick()
	check(int(waiting.remaining) == before, "a crew in training does not build yet")
	for _day: int in range(int(sim.pop_rules.crews.train_days) + 1):
		sim.tick()
	check(int(waiting.remaining) < before, "once trained it does")
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))


## A crew sent to a second town over a finished link arrives after the link's days. An
## expedition takes a crew only when its town keeps one.
func _sending() -> void:
	var sim: RefCounted = _colony()
	sim.act("crew_train", {"region": 0})
	sim.state.contract.licences.append("expedition")
	var other: int = -1
	for region: int in range(1, sim.state.world.regions.size()):
		if sim.act("settle", {"site": region, "from": 0}) == "":
			other = region
			break
	check(other >= 0, "a second town is founded")
	if other < 0:
		return
	# A finished link between the towns, laid at once as the simulation suite lays its routes.
	for variant: String in ["valley", "engineered", "sea"]:
		if sim.act("connect", {"a": 0, "b": other, "variant": variant}) == "":
			break
	var link: Dictionary = {}
	for road: Dictionary in sim.state.roads:
		if [int(road.a), int(road.b)].has(other):
			link = road
			road.ready_day = int(sim.state.day) - 1
			road.blocked_until = int(sim.state.day) - 1
	check(not link.is_empty(), "the towns are linked")
	check(
		Crews.teams_at(sim, 0).size() == 1 and int(sim.settlement(0).crew) == 1,
		"the expedition took one crew and left one at home"
	)
	for _day: int in range(
		maxi(int(link.get("days", 30)), int(sim.pop_rules.crews.train_days)) + 2
	):
		sim.tick()
	check(int(sim.settlement(other).crew) == 1, "the expedition's crew arrived with it")
	var team: Dictionary = Crews.teams_at(sim, 0).back()
	var days: int = Crews.travel_days(sim, 0, other)
	check(days > 0, "the towns are linked (%d days)" % days)
	var people: int = int(sim.settlement(0).population)
	check(sim.act("crew_send", {"crew": int(team.id), "to": other}) == "", "a crew is sent")
	check(int(sim.settlement(0).population) == people - 1, "it leaves its town")
	for _day: int in range(days + 1):
		sim.tick()
	check(int(team.region) == other and str(team.task) != Crews.TRAVEL, "and arrives")
	check(int(sim.settlement(other).crew) == 2, "counted in its new town")
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))
	check(sim.save_game(SAVE_PATH) == "", "a game with crews saves")
	var copy: RefCounted = Sim.new()
	check(copy.load_game(SAVE_PATH) == "", "and loads")
	check(
		JSON.stringify(copy.state.crews) == JSON.stringify(sim.state.crews), "with the same crews"
	)


## A save from before crews: one crew for each project under way, taken from its workers.
func _old_save() -> void:
	var sim: RefCounted = _colony()
	sim.act("build", {"site": 0, "kind": "habitat"})
	sim.act("build", {"site": 0, "kind": "water"})
	var old: Dictionary = sim.state.duplicate(true)
	old.erase("crews")
	var home: Dictionary = old.settlements[0]
	home.workers = int(home.workers) + int(home.crew)
	home.erase("crew")
	var people: int = int(home.population)
	Sim.ensure_systems(old)
	check(old.crews.teams.size() == 2, "an old save gets a crew for each project under way")
	check(int(home.population) == people, "made from its workers")
	var assigned: int = 0
	for team: Dictionary in old.crews.teams:
		if str(team.task) == Crews.BUILD:
			assigned += 1
	check(assigned == 2, "each on its project")
