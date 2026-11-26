extends SceneTree
## 1.10.1 people (the November 20 brief; the 1.10 plan F "occupations kept apart in units and on
## screen"):
## - farmers (农民) are the town's workers employed on its farms, counted every day;
## - every count of people is in persons: workers, farmers, research teams and crews (each counted
##   as one person) and the young each count one, take one bed and draw one wage, and together
##   they are the town's population; the readouts say so;
## - recruiting a researcher or a crew adds one person who takes one bed, priced per person;
## - the audit catches farmers counted beyond the workers.

const Watchdog = preload("res://tests/support/watchdog.gd")
const LegacyWorld = preload("res://tests/support/legacy_world.gd")
const Sim = preload("res://simulation/sim.gd")
const Population = preload("res://simulation/population.gd")
const Labels = preload("res://ui/labels.gd")
const SEED: int = 20261029

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
	_farmers()
	_one_unit()
	_recruits()
	print("V110_PEOPLE_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony() -> RefCounted:
	var sim: RefCounted = Sim.new()
	LegacyWorld.new_game(sim, SEED, "capital", 1)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(0), good, 900.0, "TEST stock")
	return sim


func _farmers() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.settlement(0)
	sim.Crews.unlimited(sim)
	check(sim.act("build", {"site": 0, "kind": "farm"}) == "", "a farm is ordered")
	for _day: int in range(int(sim.config.buildings.farm.days) + 2):
		sim.tick()
	var on_farms: int = 0
	for b: Dictionary in s.buildings:
		var role: String = str(sim.config.buildings.get(str(b.kind), {}).get("role", ""))
		if role in sim.Production.FARMING_ROLES:
			on_farms += int(b.employed)
	check(on_farms > 0, "the farm employs %d people" % on_farms)
	check(int(s.get("farmers", -1)) == on_farms, "they are the town's farmers (%d)" % on_farms)
	var jobs: Dictionary = Population.occupations(s)
	check(
		(
			(
				int(jobs.workers)
				+ int(jobs.farmers)
				+ int(jobs.researchers)
				+ int(jobs.crews)
				+ int(jobs.children)
			)
			== int(s.population)
		),
		(
			"workers, farmers, researchers, crews and the young add up to the population: %s"
			% str(jobs)
		)
	)
	check(int(jobs.workers) == int(s.workers) - on_farms, "workers are the others in work or not")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
	s.farmers = int(s.workers) + 1
	check(
		sim.audit().has("farmers outside the workers"),
		"the audit catches farmers beyond the workers"
	)
	s.farmers = on_farms


func _one_unit() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.settlement(0)
	sim.tick()
	var text: String = Labels.occupations_text(Population.occupations(s))
	var named: bool = true
	for word: String in ["职工", "农民", "研究团队", "工程队", "未成年", "每人一张床", "每支计 1 人"]:
		named = named and text.contains(word)
	check(named, "the readout names every occupation and the unit: %s" % text)
	var units: String = str(sim.pop_rules.units.people)
	check(
		units.contains("persons") and units.contains("crew") and units.contains("one bed"),
		"the rules state one person, one bed, one wage"
	)
	var view: Dictionary = sim.population_view(0)
	check(view.has("occupations"), "the population view carries the occupations")


func _recruits() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.settlement(0)
	var tech: String = str(sim.pop_rules.recruitment.scientist_tech)
	sim.state.research.completed.append(tech)
	for hand: Array in sim.state.research.offers.values():
		hand.erase(tech)
	# Room for the newcomers: a finished block of housing.
	var housing: Dictionary = sim.Production.new_building(sim, "habitat", 0)
	housing.active = true
	s.buildings.append(housing)
	sim.tick()
	var people: int = int(s.population)
	var researchers: int = int(s.scientists)
	var crews: int = int(s.get("crew", 0))
	var beds: int = Population.free_beds(sim, s)
	var cash: float = float(sim.state.cash)
	var price: float = Population.campaign_cost(sim, "scientist", 1)
	check(
		sim.act("recruit", {"region": 0, "kind": "scientist", "count": 1}) == "",
		"a researcher is recruited at ¥ %.0f a person" % price
	)
	check(is_equal_approx(cash - float(sim.state.cash), price), "and paid for as one person")
	check(Population.free_beds(sim, s) == beds - 1, "a bed is kept for one person")
	var crew_price: float = Population.campaign_cost(sim, "crew", 1)
	check(
		sim.act("recruit", {"region": 0, "kind": "crew", "count": 1}) == "",
		"a crew is hired at ¥ %.0f" % crew_price
	)
	check(Population.free_beds(sim, s) == beds - 2, "and keeps one bed more")
	for _day: int in range(int(sim.pop_rules.recruitment.travel_days) + 2):
		sim.tick()
	check(int(s.scientists) == researchers + 1, "the researcher arrives as one person")
	check(int(s.get("crew", 0)) == crews + 1, "the crew arrives as one person")
	var arrived: int = int(sim.population_view(0).arrived_30)
	check(
		arrived >= 2,
		(
			"the town's arrivals count them as two people (%d arrived; population %d → %d)"
			% [arrived, people, int(s.population)]
		)
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
