extends SceneTree
## The research curve, the technology pool and its cards, laboratories, paid contracts, building
## upgrades, new buildings, road paving and megaprojects, and old research progress on load.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Research = preload("res://simulation/research.gd")
const Production = preload("res://simulation/production.gd")
const Population = preload("res://simulation/population.gd")
const Market = preload("res://simulation/market.gd")
const Contract = preload("res://simulation/contract.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const Rules = preload("res://simulation/rules.gd")
const SaveMigration = preload("res://simulation/save_migration.gd")

const LAB_LEVEL_TWO_SEATS: int = 20
const LAB_LEVEL_TWO_PROJECTS: int = 3
const MIN_POOL: int = 100
const MIN_NEW_BUILDINGS: int = 30
const MIN_CATEGORY_POOL: int = 20
const V171_BUILDINGS: Array[String] = [
	"climate_regulator", "clinic", "component_plant", "farm", "foodworks", "habitat", "hydroponic_farm", "lab", "lift_port", "mine_copper", "mine_crystal", "mine_ore", "port", "power", "processor", "university", "water"
]

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


func make(opening: String = "capital") -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, opening)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


func grant(sim: RefCounted, techs: Array) -> void:
	for tech: String in techs:
		sim.state.research.completed.append(tech)
		for hand: Array in sim.state.research.offers.values():
			hand.erase(tech)


## Money and goods go through the ledger, or the audit would rightly object.
func fund(sim: RefCounted, amount: float) -> void:
	sim._transfer("external", "public", amount, "capital.initial", false)


func supply(sim: RefCounted, s: Dictionary, good: String, amount: float) -> void:
	sim._produce(s, good, amount, "test")


func add_finished(sim: RefCounted, kind: String) -> int:
	var s: Dictionary = sim.settlement(0)
	s.buildings.append(sim._building(kind, 0))
	return s.buildings.size() - 1


func run() -> void:
	_curve()
	_pool()
	_cards()
	_gates()
	_lab_levels()
	_contracts()
	_upgrades()
	_new_buildings()
	_road_paving()
	_megaprojects()
	_openings()
	_old_progress()
	await _card_page()
	print("V17_RESEARCH_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _curve() -> void:
	check(is_equal_approx(Research.rate(5) / Research.rate(10), 0.6), "R(5) / R(10) = 0.6")
	check(Research.rate(0) == 0.0, "no staff, no output")
	var last: float = 0.0
	var rising: bool = true
	for staff: int in range(1, 41):
		var now: float = Research.rate(staff)
		rising = rising and now > last
		last = now
	check(rising, "output rises with every added scientist")
	var reference: float = float(Rules.progression().research.reference_rate)
	check(reference > 0.0, "the reference output comes from the rules")
	check(Research.rate(10, reference) == reference, "ten scientists give the reference output")


func _pool() -> void:
	var rules: Dictionary = Rules.read("techs")
	var techs: Dictionary = rules.techs
	check(techs.size() >= MIN_POOL, "the pool holds at least a hundred technologies")
	check(rules.categories.size() in [3, 4], "three or four research categories")
	var per_category: Dictionary = {}
	var sound: bool = true
	for key: String in techs:
		var t: Dictionary = techs[key]
		per_category[t.category] = int(per_category.get(t.category, 0)) + 1
		sound = sound and rules.categories.has(t.category)
		sound = sound and float(t.cost) > 0.0 and float(t.weight) > 0.0
		for req: String in t.requires:
			sound = sound and techs.has(req) and int(techs[req].tier) <= int(t.tier)
	check(sound, "every technology has a category, a cost and earlier prerequisites")
	for category: String in rules.categories:
		check(
			int(per_category.get(category, 0)) >= MIN_CATEGORY_POOL,
			category + " has plenty of technologies"
		)
	# Every card can come up one day: walk the prerequisites from nothing.
	var known: Dictionary = {}
	var grew: bool = true
	while grew:
		grew = false
		for key: String in techs:
			if known.has(key):
				continue
			var open: bool = true
			for req: String in techs[key].requires:
				open = open and known.has(req)
			if open:
				known[key] = true
				grew = true
	check(known.size() == techs.size(), "no technology is out of reach")
	var economy: Dictionary = Rules.economy()
	var fresh: int = 0
	var gated: bool = true
	for kind: String in economy.buildings:
		if not V171_BUILDINGS.has(kind):
			fresh += 1
		var needed: String = str(economy.buildings[kind].get("requires_tech", ""))
		gated = gated and (needed == "" or techs.has(needed))
	check(fresh >= MIN_NEW_BUILDINGS, "at least thirty new buildings: %d" % fresh)
	check(gated, "every building's technology exists")
	var sim: RefCounted = make()
	var row: Dictionary = {}
	for candidate: Dictionary in sim.research_tree():
		if candidate.id == "survey":
			row = candidate
	check(row.previews.size() == 3, "staffing previews are offered")
	check(
		int(row.previews[0].days) > int(row.previews[1].days),
		"more research teams finish sooner in the preview"
	)
	check(
		(
			int(row.previews[1].days)
			== ceili(float(row.cost) / float(sim.progression.research.reference_rate))
		),
		"the ten-team preview uses the real rate and cost"
	)


func _hands(sim: RefCounted) -> String:
	return JSON.stringify(sim.state.research.offers)


func _cards() -> void:
	var rules: Dictionary = Rules.read("techs")
	var sim: RefCounted = make()
	var r: Dictionary = sim.state.research
	var good: bool = true
	for category: String in rules.categories:
		var hand: Array = r.offers[category]
		good = good and hand.size() == int(rules.offers)
		for key: String in hand:
			good = good and str(rules.techs[key].category) == category
			good = good and rules.techs[key].requires.is_empty()
		for key: String in rules.first_offers.get(category, []):
			good = good and hand.has(key)
	check(good, "each category deals its starter card and only what is open")
	var other: RefCounted = Sim.new()
	other.new_game(42, "capital")
	check(_hands(other) != _hands(sim), "another seed deals other cards")
	var twin: RefCounted = make()
	check(_hands(twin) == _hands(sim), "the same seed deals the same cards")

	var lab: int = add_finished(sim, "lab")
	sim.settlement(0).buildings[lab].active = true
	var town: Dictionary = sim.settlement(0)
	town.workers = int(town.workers) + int(town.scientists) - 12
	town.scientists = 12
	var locked: String = ""
	for key: String in rules.techs:
		if str(rules.techs[key].category) == "industry" and not r.offers.industry.has(key):
			if rules.techs[key].requires.is_empty():
				locked = key
	if locked != "":
		check(sim.act("research_allocate", {"tech": locked, "staff": 4}) != "", "a card not dealt waits")
	var first: String = str(r.offers.industry[0])
	var second: String = str(r.offers.industry[1])
	check(sim.act("research_allocate", {"tech": first, "staff": 4}) == "", "a dealt card can be staffed")
	r.projects[first].work = 7.0
	check(sim.act("research_allocate", {"tech": second, "staff": 4}) == "", "and another taken up")
	check(int(r.projects[first].staff) == 0, "one project per category: the first stands down")
	check(float(r.projects[first].work) == 7.0, "and keeps its work")
	check(r.offers.industry.has(first), "started work stays on the table")

	fund(sim, 20000.0)
	var before: Array = r.offers.agriculture.duplicate()
	var cash: float = float(sim.state.cash)
	var cost: float = sim.Research.reshuffle_cost(sim)
	check(sim.act("research_reshuffle", {"category": "agriculture"}) == "", "cards can be redrawn")
	check(float(sim.state.cash) == cash - cost, "for a price")
	check(r.offers.agriculture != before, "the hand changes")
	check(sim.act("research_reshuffle", {"category": "nothing"}) != "", "only real categories")

	var count_before: int = sim.Research.bonus(sim, "mine_output") as int
	r.projects[second].work = float(rules.techs[second].cost) - 0.01
	var before_done: int = r.completed.size()
	sim.tick()
	check(r.completed.size() == before_done + 1, "the project finishes")
	check(not r.offers.industry.has(second), "a finished card leaves the hand")
	check(r.offers.industry.size() >= int(rules.offers), "and the category deals again")
	check(count_before == 0, "no effect before a technology is done")
	var effects: Dictionary = rules.techs[second].get("effects", {})
	for effect: String in effects:
		check(
			is_equal_approx(sim.Research.bonus(sim, effect), float(effects[effect])),
			"finished technologies add their effects: " + effect
		)
	check(sim.audit().is_empty(), "the research ledger stays clean")

	var lead: String = ""
	for key: String in rules.techs:
		var t: Dictionary = rules.techs[key]
		if t.requires.is_empty() and not r.offers[t.category].has(key) and not r.completed.has(key):
			lead = key
			break
	if lead != "":
		check(sim.Research.add_lead(sim, lead), "an event can put a lead on the table")
		check(r.offers[rules.techs[lead].category].has(lead), "and the lead is dealt")
	var path: String = "user://cards.save"
	check(sim.save_game(path) == "", "cards are saved")
	var loaded: RefCounted = Sim.new()
	check(loaded.load_game(path) == "", "and loaded")
	check(_hands(loaded) == _hands(sim), "with the same hands")
	check(
		int(loaded.state.research.rng_state) == int(r.rng_state),
		"and the same draw still to come"
	)


func _gates() -> void:
	var sim: RefCounted = make()
	check(sim.act("build", {"region": 0, "kind": "clinic"}) != "", "clinic waits for medicine")
	check(
		Population.recruit_refusal(sim, 0, "scientist", 1) != "",
		"scientist campaigns wait for education"
	)
	grant(sim, ["education"])
	add_finished(sim, "habitat")
	sim._refresh(sim.settlement(0))
	check(
		Population.recruit_refusal(sim, 0, "scientist", 1) == "",
		"education opens scientist campaigns"
	)
	check(
		sim.act("research_allocate", {"tech": "deep_mining", "staff": 3}) != "",
		"a tier 2 technology waits for its prerequisite"
	)


func _lab_levels() -> void:
	var sim: RefCounted = make()
	var index: int = add_finished(sim, "lab")
	sim.state.settlements[0].buildings[index].active = true
	var view: Dictionary = sim.research_view()
	check(int(view.capacity) == 10, "a first-level lab has ten seats")
	check(int(view.benches) == 2, "a first-level lab has two benches")
	check(sim.upgrade_preview(0, index).disabled_reason != "", "lab upgrade needs the network")
	grant(sim, ["research_network"])
	fund(sim, 5000.0)
	var s: Dictionary = sim.settlement(0)
	supply(sim, s, "materials", 100.0)
	supply(sim, s, "parts", 50.0)
	check(sim.act("upgrade", {"region": 0, "index": index}) == "", "lab upgrade is accepted")
	check(sim.research_view().capacity == 10, "the old level serves until the work is done")
	for _day: int in range(int(sim.config.upgrades.lab[0].days)):
		sim.tick()
	view = sim.research_view()
	check(int(view.capacity) == LAB_LEVEL_TWO_SEATS, "a second-level lab has twenty seats")
	check(int(view.benches) == LAB_LEVEL_TWO_PROJECTS, "a second-level lab has three benches")


func _contracts() -> void:
	var sim: RefCounted = make()
	var index: int = add_finished(sim, "lab")
	var s: Dictionary = sim.settlement(0)
	s.scientists = 12
	s.workers = int(s.workers) - 8
	check(sim.act("research_contract", {"staff": 5}) != "", "contracts wait for the network")
	grant(sim, ["research_network"])
	check(sim.act("research_contract", {"staff": 50}) != "", "contracts cannot invent scientists")
	check(sim.act("research_contract", {"staff": 10}) == "", "contract staff is accepted")
	check(
		sim.act("research_allocate", {"tech": "survey", "staff": 4}) != "",
		"a contract competes with projects for staff"
	)
	var cash_before: float = float(sim.state.external_in)
	sim.tick()
	var earned: float = float(sim.state.research.contract.earned)
	var expected: float = (
		Research.rate(10, float(sim.progression.research.reference_rate))
		* float(sim.progression.research.contract_point_price)
	)
	check(s.buildings[index].active, "the contract lab is staffed")
	check(is_equal_approx(earned, expected), "a contract pays for the points it produces")
	check(
		float(sim.state.external_in) - cash_before >= earned, "contract money enters from outside"
	)
	var found: bool = false
	for entry: Dictionary in sim.state.ledger:
		if entry.key == "research.contract":
			found = entry.operating
	check(found, "contract income is operating income")
	check(sim.audit().is_empty(), "contract income passes the audit")
	sim.state.contract.income_window = []
	for _day: int in range(int(sim.contract_rules.windows.non_mining)):
		sim.tick()
	check(Contract.non_mining_share(sim) > 0.0, "contract income counts as non-mining income")


func _upgrades() -> void:
	var sim: RefCounted = make()
	var index: int = add_finished(sim, "mine_ore")
	var s: Dictionary = sim.settlement(0)
	s.buildings[index].plot = sim.Sites.find_plot(sim, 0, "mine_ore")
	var base_jobs: int = Production.jobs_for(sim, s.buildings[index])
	grant(sim, ["deep_mining"])
	fund(sim, 9000.0)
	supply(sim, s, "materials", 200.0)
	supply(sim, s, "parts", 100.0)
	check(sim.act("upgrade", {"region": 0, "index": index}) == "", "mine upgrade is accepted")
	check(sim.act("upgrade", {"region": 0, "index": index}) != "", "one upgrade at a time")
	check(s.buildings[index].level == 1, "level holds during the work")
	for _day: int in range(int(sim.config.upgrades.mine_ore[0].days)):
		sim.tick()
	check(s.buildings[index].level == 2, "level rises when the work is done")
	check(
		Production.jobs_for(sim, s.buildings[index]) == base_jobs + 4,
		"a level 2 mine needs +4 jobs"
	)
	check(is_equal_approx(Production.output_factor(sim, s.buildings[index]), 1.6), "+60% output")
	var before: float = float(sim.state.resource_sources.ore)
	sim.tick()
	var dug: float = float(sim.state.resource_sources.ore) - before
	var seam: Dictionary = sim.state.world.regions[0].plots[int(s.buildings[index].plot)]
	var plain: float = float(sim.config.buildings.mine_ore.rate) * float(seam.grade)
	check(dug > plain * 1.2, "the level 2 mine really digs more")
	grant(sim, ["automation"])
	check(
		Production.jobs_for(sim, s.buildings[index]) == ceili((base_jobs + 4) * 0.7),
		"automation takes 30% of mine jobs"
	)
	var habitat: int = add_finished(sim, "habitat")
	grant(sim, ["medicine"])
	fund(sim, 9000.0)
	var beds: int = Population.habitat_beds(sim, s.buildings[habitat])
	check(sim.act("upgrade", {"region": 0, "index": habitat}) == "", "habitat upgrade is accepted")
	for _day: int in range(int(sim.config.upgrades.habitat[0].days)):
		sim.tick()
	check(
		Population.habitat_beds(sim, s.buildings[habitat]) > beds, "a level 2 habitat has more beds"
	)
	check(sim.audit().is_empty(), "upgrades pass the audit")


func _new_buildings() -> void:
	var sim: RefCounted = make()
	var s: Dictionary = sim.settlement(0)
	var appeal_before: float = Population.attractiveness(sim, s).value
	add_finished(sim, "clinic")
	check(
		is_equal_approx(
			Population.attractiveness(sim, s).value,
			minf(2.0, appeal_before + float(sim.config.buildings.clinic.service.appeal))
		),
		"a clinic adds to attractiveness"
	)
	# Hydroponics grow the same anywhere: the forecast does not look at the soil.
	grant(sim, ["hydroponics", "electronics"])
	var forecast: Dictionary = sim.build_forecast(0, "hydroponic_farm")
	check(
		is_equal_approx(
			float(forecast.outputs.food), float(sim.config.buildings.hydroponic_farm.rate)
		),
		"hydroponic yield ignores the land"
	)
	var plant: int = add_finished(sim, "component_plant")
	add_finished(sim, "power")
	add_finished(sim, "power")
	add_finished(sim, "water")
	s.workers = int(s.workers) + 30
	s.population = int(s.population) + 30
	supply(sim, s, "parts", 50.0)
	supply(sim, s, "crystal", 50.0)
	var before: float = float(s.stock.components)
	var parts_before: float = float(s.stock.parts)
	var exports_before: float = float(sim.state.exports_total)
	sim.tick()
	check(s.buildings[plant].active, "the component plant runs with staff and inputs")
	check(float(s.stock.parts) < parts_before, "components use up parts")
	check(
		float(sim.state.exports_total) > exports_before or float(s.stock.components) > before,
		"components are made"
	)
	check(sim.state.market.saturation.has("components"), "components sell on the market")
	check(sim.audit().is_empty(), "components pass the material audit")


func _road_paving() -> void:
	var sim: RefCounted = make()
	fund(sim, 20000.0)
	sim.state.contract.licences.append("expedition")
	check(sim.act("settle", {"region": 1}) == "", "the outpost is founded")
	for _day: int in range(30):
		sim.tick()
	var a: Dictionary = sim.settlement(0)
	supply(sim, a, "materials", 200.0)
	check(sim.act("connect", {"a": 0, "b": 1, "mountain": true}) == "", "the road is ordered")
	var route: Dictionary = sim.state.roads[0]
	grant(sim, ["paved_roads"])
	check(sim.act("upgrade_road") != "", "a road still being built cannot be paved")
	sim.state.research.completed.erase("paved_roads")
	check(int(route.build_days) >= int(sim.config.roads.engineered.build_days), "roads take time")
	route.ready_day = int(sim.state.day) - 1
	route.blocked_until = int(sim.state.day) - 1
	var capacity: int = int(route.capacity)
	var days: int = int(route.days)
	check(sim.act("upgrade_road") != "", "paving waits for the technology")
	grant(sim, ["paved_roads"])
	check(sim.act("upgrade_road") == "", "paving is accepted")
	for _day: int in range(int(sim.config.road_upgrade.build_days) + 1):
		sim.tick()
	check(int(route.capacity) == int(round(capacity * 1.5)), "paving adds 50% capacity")
	check(int(route.days) == maxi(1, days - 1), "paving takes a day off the trip")
	check(sim.act("upgrade_road") != "", "a paved road cannot be paved again")
	check(sim.audit().is_empty(), "paving passes the audit")


func _megaprojects() -> void:
	var sim: RefCounted = make()
	var s: Dictionary = sim.settlement(0)
	check(
		sim.act("build", {"region": 0, "kind": "university"}) != "", "the university needs research"
	)
	grant(sim, ["university", "lift_port", "climate"])
	fund(sim, 100000.0)
	check(
		sim.act("build", {"region": 0, "kind": "university"}) == "", "the university can be ordered"
	)
	check(sim.act("build", {"region": 0, "kind": "university"}) != "", "one university per planet")
	check(sim.audit().is_empty(), "the supply train passes the audit")
	check(Megaprojects.research_factor(sim) == 1.0, "no effect before it is finished")
	for b: Dictionary in s.buildings:
		if b.kind == "university":
			b.remaining = 0
	check(Megaprojects.research_factor(sim) == 1.25, "the university speeds research by 25%")
	check(Megaprojects.scientist_share_bonus(sim) > 0.0, "the university attracts scientists")
	var price_before: float = Market.price(sim, "ore")
	add_finished(sim, "lift_port")
	check(
		is_equal_approx(Market.price(sim, "ore"), price_before * 1.1),
		"the lift port adds 10% to prices"
	)
	check(Megaprojects.port_factor(sim, s) == 3.0, "the lift port triples local port capacity")
	var yield_before: float = Production.farm_climate(sim, 0)
	var temperature: float = float(sim.state.world.regions[0].temperature)
	add_finished(sim, "climate_regulator")
	var shift: Dictionary = Megaprojects.climate(sim, 0)
	check(float(shift.temperature) == 3.0, "the regulator warms its region by 3 °C")
	check(is_equal_approx(float(shift.rainfall), 1.1), "the regulator adds 10% rainfall")
	check(
		Production.farm_climate(sim, 0) != yield_before or temperature > 40.0,
		"the regulator changes farm yields"
	)
	add_finished(sim, "capital_hall")
	check(Megaprojects.count(sim) == 4, "all four are counted")
	sim.state.status = "success"
	sim.state.contract.stage = Contract.STAGE_COUNT + 1
	var balance: float = float(sim.state.career.balance)
	Contract._check_milestones(sim)
	check(
		"four_megaprojects" in sim.state.contract.milestones,
		"four megaprojects meet their milestone"
	)
	check(float(sim.state.career.balance) > balance, "the milestone pays out")
	check(sim.save_game("user://milestone.save") == "", "a save after a milestone is written")
	var reloaded: RefCounted = sim.get_script().new()
	check(reloaded.load_game("user://milestone.save") == "", "and loads again")


func _openings() -> void:
	var science: RefCounted = make("science")
	var has_lab: bool = false
	for b: Dictionary in science.settlement(0).buildings:
		has_lab = has_lab or b.kind == "lab"
	check(has_lab, "the science opening lands with a laboratory")
	check(
		float(science.state.research.projects.survey.work) > 0.0,
		"the science opening starts with survey work done"
	)
	var other: int = int(science.state.settlements[0].region) + 1
	var plain: RefCounted = make("capital")
	check(
		float(science.site_view(other).band) < float(plain.site_view(other).band),
		"the science opening's survey estimates are narrower"
	)
	var fare: float = float(plain.config.outpost.cash)
	check(
		plain.Sites.expedition_cash(plain) < fare,
		"the capital opening's first expedition is cheaper"
	)
	check(
		is_equal_approx(science.Sites.expedition_cash(science), fare),
		"the other openings pay the full fare"
	)
	var hard: RefCounted = Sim.new()
	hard.new_game(260129, "capital", 1, "hard")
	var easy: RefCounted = Sim.new()
	easy.new_game(260129, "capital", 1, "easy")
	for sim: RefCounted in [hard, easy]:
		sim.state.market.saturation = {"ore": 100.0}
	check(
		hard.Market.factor(hard, "ore") < easy.Market.factor(easy, "ore"), "hard prices fall faster"
	)
	check(
		hard.EventsV2._draw_interval(hard) < easy.EventsV2._draw_interval(easy),
		"hard draws events more often"
	)


func _old_progress() -> void:
	var state: Dictionary = {
		"research":
		{
			"completed": [],
			"projects":
			{
				"survey": {"staff": 4, "work": 50.0, "effective": 4, "rate": 1.0, "reason": ""},
				"processing": {"staff": 0, "work": 30.0, "effective": 0, "rate": 0.0, "reason": ""},
			}
		}
	}
	state.research.projects.survey.work = 5000.0
	SaveMigration._settle_research(state)
	check(state.research.completed.has("survey"), "old work past the new cost finishes the project")
	check(
		is_equal_approx(
			float(state.research.projects.survey.work), float(Rules.read("techs").techs.survey.cost)
		),
		"finished work is clamped to the cost"
	)
	check(int(state.research.projects.survey.staff) == 0, "its scientists are released")
	check(not state.research.completed.has("processing"), "work below the cost stays in progress")


func _card_page() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.close_modal()
	scene.sim.act("settle", {"region": 0})
	scene.open_page("research")
	await process_frame
	check(scene.ui.find_children("Tech_*", "Button", true, false).is_empty(), "no tree is shown")
	var cards: Array[Node] = scene.ui.find_children("Card_*", "Button", true, false)
	var dealt: int = 0
	for hand: Array in scene.sim.state.research.offers.values():
		dealt += hand.size()
	check(cards.size() == dealt, "the research page shows every dealt card")
	for category: String in Rules.read("techs").categories:
		check(scene.ui.find_child("Staff_" + category, true, false) != null, category + " has a team")
		check(
			scene.ui.find_child("Reshuffle_" + category, true, false) != null,
			category + " can redraw"
		)
	var survey: Button = scene.ui.find_child("Card_survey", true, false)
	check(survey != null, "the starter card is there")
	var team: SpinBox = scene.ui.find_child("Staff_industry", true, false)
	team.value = 4
	survey.pressed.emit()
	await process_frame
	check(
		int(scene.sim.state.research.projects.survey.staff) == 4,
		"pressing a card sends the chosen team"
	)
	check(scene.ui.find_child("Card_survey", true, false) == null, "and it no longer asks to be picked")
	scene.close_modal()
	root.remove_child(scene)
	scene.free()
