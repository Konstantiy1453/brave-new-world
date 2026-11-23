extends SceneTree
## 1.11 phase C: six origins, each a type of contract with a story, gains, costs and a unique rule.
## - every origin has its story, gains, costs, rule and favoured route in data, and its new game
##   starts with the people, money and goods of its entry;
## - an origin's effects reach Research.bonus as a third source, and the cache follows a load;
## - 工程承包: two crews at landing; wages start at the floor and cannot be set below it;
## - 科研托管: the research-contract technology from landing, contract income by its factor, and no
##   research-speed bonus;
## - 移民安置: sixty more residents, immigration +15%, and a monthly subsidy for each resident with a
##   bed and a job, booked as operating income, only while it lasts;
## - 矿权抵押: mines produce 20% more;
## - 群岛开发: inland ground refused for the first settlement (both ways of founding), a harbour at
##   landing, a cheaper offshore survey, dearer roads and dearer orbital freight;
## - saves of the three older ids load and play on unchanged (a 1.10 save, an old wage below the
##   new floor), and the new-game cards and the contract page show the origin.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Origins = preload("res://simulation/origins.gd")
const Research = preload("res://simulation/research.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Bay = preload("res://simulation/bay.gd")
const OriginCards = preload("res://ui/origin_cards.gd")
const ContractPage = preload("res://ui/contract_page.gd")
const SEED: int = 20261029
const IDS: Array[String] = [
	"capital", "workers", "science", "resettlement", "mining_pledge", "archipelago"
]
const OLD_SAVE: String = "res://../docs/v17/placement/save_files/after-1.10.1.save"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_data()
	_starting_states()
	_effects()
	_works()
	_research()
	_resettlement()
	_archipelago()
	_old_saves()
	_interface()
	print("V111_ORIGINS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


## A new game on `id`, landed on the best site the contract accepts.
func _landed(id: String, seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, id, 1)
	var best: int = -1
	var score: float = -1.0
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) != "":
			continue
		var value: float = sim.Sites.start_score(sim, int(reg.id))
		if value > score:
			score = value
			best = int(reg.id)
	sim.act("settle", {"region": best})
	sim.state.events_v2.next_draw = 99999
	return sim


func _data() -> void:
	var openings: Dictionary = Rules.read("economy").openings
	var complete: bool = openings.size() == IDS.size()
	var routes: Dictionary = Rules.read("contract").routes
	var clauses: Dictionary = Rules.read("contract").document.origin_clauses
	for id: String in IDS:
		var entry: Dictionary = openings.get(id, {})
		for field: String in ["name", "story", "gains", "costs", "rule", "effects", "rules"]:
			complete = complete and entry.has(field)
		var route: String = str(entry.get("favours", ""))
		complete = complete and (route == "" or routes.has(route))
		for clause: Variant in entry.get("clauses", []):
			complete = complete and clauses.has(str(clause))
	check(complete, "six origins, each with story, gains, costs, rule, effects and its clauses")
	check(
		bool(openings.capital.get("recommended", false)),
		"the standard contract is the one recommended for a first game"
	)


func _starting_states() -> void:
	for id: String in IDS:
		var sim: RefCounted = Sim.new()
		sim.new_game(SEED, id, 1)
		var entry: Dictionary = sim.config.openings[id]
		var capital: float = float(sim.progression.difficulty.normal.capital)
		var cash_ok: bool = is_equal_approx(float(sim.state.cash), float(entry.cash) * capital)
		sim = _landed(id)
		var town: Dictionary = sim.state.settlements[0]
		var people: int = int(entry.workers) + int(entry.scientists) + int(entry.children)
		check(
			cash_ok and int(town.population) == people,
			"%s starts with ¥%.0f and %d people" % [id, float(entry.cash) * capital, people]
		)
		check(sim.audit().is_empty(), "%s lands with a clean audit" % id)
	var settled: RefCounted = _landed("resettlement")
	var standard: RefCounted = _landed("capital")
	check(
		(
			(
				int(settled.state.settlements[0].population)
				- int(standard.state.settlements[0].population)
			)
			== 60
		),
		"移民安置 lands sixty more residents than the standard contract"
	)


func _effects() -> void:
	var mining: RefCounted = _landed("mining_pledge")
	check(
		is_equal_approx(Research.bonus(mining, "mine_output"), 0.2),
		"矿权抵押's mine output reaches Research.bonus: %.2f" % Research.bonus(mining, "mine_output")
	)
	check(
		is_equal_approx(mining.Production._good_bonus(mining, "ore"), 1.2),
		"and its mines produce 20% more"
	)
	var settled: RefCounted = _landed("resettlement")
	check(
		is_equal_approx(Research.bonus(settled, "immigration"), 0.15),
		"移民安置's immigration +15% reaches Research.bonus"
	)
	var standard: RefCounted = _landed("capital")
	check(
		is_zero_approx(Research.bonus(standard, "mine_output")), "the standard contract adds none"
	)
	check(mining.save_game("user://v111_origin_mining.save") == "", "a mining pledge saves")
	check(
		(
			standard.load_game("user://v111_origin_mining.save") == ""
			and is_equal_approx(Research.bonus(standard, "mine_output"), 0.2)
		),
		"and a game loaded over another reads the loaded origin's effects (the cache follows)"
	)


func _works() -> void:
	var sim: RefCounted = _landed("workers")
	check(sim.state.crews.teams.size() == 2, "工程承包 lands with two crews")
	var floor_value: float = float(sim.config.openings.workers.rules.wage_floor)
	check(
		is_equal_approx(float(sim.state.policy.wage), floor_value),
		"its wages start at the floor (%.2f)" % floor_value
	)
	var refusal: String = sim.act("policy", {"wage": 1.0})
	check(refusal.contains("工资不得低于"), "and cannot go below it: " + refusal)
	check(is_equal_approx(float(sim.state.policy.wage), floor_value), "the refusal changes nothing")
	check(sim.act("policy", {"wage": 1.3}) == "", "a higher wage is fine")
	var standard: RefCounted = _landed("capital")
	check(standard.state.crews.teams.size() == 1, "the standard contract lands with one crew")
	check(standard.act("policy", {"wage": 0.9}) == "", "and has no wage floor")


func _research() -> void:
	var sim: RefCounted = _landed("science")
	var tech: String = str(sim.progression.research.contract_tech)
	check(sim._has(tech), "科研托管 holds the research-contract technology from landing")
	check(
		is_equal_approx(Research._speed_factor(sim), Research._speed_factor(_landed("capital"))),
		"and has no research-speed bonus"
	)
	check(is_equal_approx(Research._funding_factor(sim), 0.5), "its research funding is halved")
	var earned: Array[float] = []
	var rule: Dictionary = Rules.read("economy").openings.science.rules
	var factor: float = float(rule.contract_income)
	for scale: float in [1.0, 2.0]:
		rule.contract_income = factor * scale
		var run: RefCounted = _landed("science")
		run.act("research_contract", {"staff": 6})
		for _day: int in range(10):
			run.tick()
		earned.append(float(run.state.research.contract.earned))
	rule.contract_income = factor
	check(
		earned[0] > 0.0 and is_equal_approx(earned[1], earned[0] * 2.0),
		"research-contract income follows its factor: %.0f, %.0f" % [earned[0], earned[1]]
	)


func _resettlement() -> void:
	var rule: Dictionary = Rules.read("economy").openings.resettlement.rules
	var lasting: float = float(rule.subsidy_days)
	rule.subsidy_days = 60.0
	var sim: RefCounted = _landed("resettlement")
	var paid: Dictionary = {}
	var expected: Dictionary = {}
	for _day: int in range(95):
		var people: int = Origins.housed_and_employed(sim)
		sim.tick()
		for row: Dictionary in sim.state.ledger:
			if str(row.key) == Origins.SUBSIDY and int(row.day) == int(sim.state.day):
				paid[int(row.day)] = float(row.amount)
				check(bool(row.operating), "the subsidy is booked as operating income")
		if int(sim.state.day) % 30 == 0:
			expected[int(sim.state.day)] = people
	rule.subsidy_days = lasting
	check(
		paid.keys() == [30, 60],
		"移民安置 is paid on the first day of each month while it lasts: days %s" % str(paid.keys())
	)
	check(
		paid.has(30) and float(paid[30]) > 0.0,
		"for residents with a bed and a job: ¥%.0f" % float(paid.get(30, 0.0))
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _archipelago() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "archipelago", 1)
	var inland: int = -1
	var coastal: int = -1
	for reg: Dictionary in sim.state.world.regions:
		var standard_refusal: String = sim.Sites.settle_refusal(sim, int(reg.id))
		if not bool(reg.coast) and inland < 0 and standard_refusal.contains("海岸"):
			inland = int(reg.id)
		if bool(reg.coast) and coastal < 0 and standard_refusal == "":
			coastal = int(reg.id)
	check(inland >= 0, "群岛开发 refuses inland ground for the first settlement")
	var reg: Dictionary = sim.state.world.regions[maxi(0, inland)]
	var ground: Dictionary = sim.Placement.view(
		sim, float(reg.get("lat", 0.0)), float(reg.get("lon", 0.0))
	)
	var picked: bool = (
		bool(ground.get("coast", true))
		or str(ground.refusal).contains("海岸")
		or not bool(ground.get("land", false))
	)
	check(picked, "and so does picking ground on the map: " + str(ground.refusal))
	check(sim.act("settle", {"region": coastal}) == "", "a coastal site is accepted")
	var town: Dictionary = sim.state.settlements[0]
	var harbour: bool = false
	for building: Dictionary in town.buildings:
		harbour = harbour or str(building.kind) == "harbor"
	check(harbour, "it lands with a harbour")
	var standard: RefCounted = _landed("capital")
	check(
		is_equal_approx(
			float(Bay.survey_terms(sim).cost), float(Bay.survey_terms(standard).cost) * 0.5
		),
		"its offshore survey costs half"
	)
	check(
		(
			is_equal_approx(Research.bonus(sim, "road_cost"), 0.5)
			and is_equal_approx(Research.bonus(sim, "orbital_freight"), 0.25)
		),
		"roads cost 50% more and orbital freight 25% more"
	)
	_orbital_price(sim)


## Food bought by orbit at a town without a working harbour costs `orbital_freight` more.
func _orbital_price(sim: RefCounted) -> void:
	var town: Dictionary = sim.state.settlements[0]
	town.buildings = town.buildings.filter(
		func(b: Dictionary) -> bool: return str(b.kind) != "harbor"
	)
	sim._transfer("external", "public", 50000.0, "TEST funds", false)
	var spent: Array[float] = []
	# The game's own copy of the rules: a game reads the rule files when it is made.
	var effects: Dictionary = sim.config.openings.archipelago.effects
	var surcharge: float = float(effects.orbital_freight)
	for value: float in [surcharge, 0.0]:
		effects.orbital_freight = value
		sim.tech_effects_count = -1
		var before: float = float(sim.state.cash)
		town.stock.food = 0.0
		Logistics._import(sim, town, "food", 5.0, 5.0)
		spent.append(before - float(sim.state.cash))
	effects.orbital_freight = surcharge
	sim.tech_effects_count = -1
	check(
		spent[1] > 0.0 and is_equal_approx(spent[0], spent[1] * (1.0 + surcharge)),
		"food by orbit costs %.1f instead of %.1f" % [spent[0], spent[1]]
	)


func _old_saves() -> void:
	var path: String = ProjectSettings.globalize_path(OLD_SAVE)
	if FileAccess.file_exists(path):
		var sim: RefCounted = Sim.new()
		check(sim.load_game(path) == "", "a 1.10 save loads")
		var id: String = str(sim.state.advantage)
		for _day: int in range(30):
			sim.tick()
		check(
			id in ["capital", "workers", "science"] and str(sim.state.advantage) == id,
			"and keeps its contract type (%s) as it plays on" % id
		)
		check(sim.audit().is_empty(), "with a clean audit")
	var works: RefCounted = _landed("workers")
	works.state.policy.wage = 1.0
	check(
		works.save_game("user://v111_old_works.save") == "",
		"a workers game below the new floor saves"
	)
	var again: RefCounted = Sim.new()
	check(
		(
			again.load_game("user://v111_old_works.save") == ""
			and is_equal_approx(float(again.state.policy.wage), 1.0)
		),
		"and loads with its wage unchanged"
	)
	for _day: int in range(10):
		again.tick()
	check(again.audit().is_empty(), "and plays on")


func _interface() -> void:
	var sim: RefCounted = _landed("mining_pledge")
	var box := VBoxContainer.new()
	root.add_child(box)
	var picked: Array[String] = []
	OriginCards.cards(box, sim, "capital", false, func(id: String) -> void: picked.append(id))
	var texts: PackedStringArray = []
	for label: Node in box.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	var shown: String = "\n".join(texts)
	var named: bool = true
	for id: String in IDS:
		named = named and shown.contains(str(sim.config.openings[id].name))
	check(named and shown.contains("推荐首局"), "the new-game screen has a card for each origin")
	check(not shown.contains("{"), "with every number filled")
	check(shown.contains("偏向第三阶段路线"), "and the route each new origin favours")
	var button: Button = box.find_child("Origin_archipelago", true, false)
	button.pressed.emit()
	check(picked == ["archipelago"], "choosing a card picks its contract")
	box.queue_free()
	var rows: Array = ContractPage.clauses(sim)
	var origin: String = ""
	for row: Dictionary in rows:
		if str(row.id).begins_with("origin_"):
			origin = str(row.text)
	check(
		origin.contains("矿权") and not origin.contains("{"),
		"the contract carries the origin's clause: " + origin
	)
