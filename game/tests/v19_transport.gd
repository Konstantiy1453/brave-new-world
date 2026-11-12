extends SceneTree
## 1.9 transport: a sea link is two small cargo docks that need no orbital freight station and
## grow to medium docks (no technology) and large ones (沿海航运); a road is paved (铺装道路) and
## then widened into a four-lane trunk road (连续摊铺机); every step costs money and stores, takes
## its build days, then raises capacity, takes a day off the trip and adds upkeep. Older saves keep
## their paving. Gift technologies are never dealt or researched, only handed over by events, and
## do not count towards the charter's technology goals.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Research = preload("res://simulation/research.gd")
const Contract = preload("res://simulation/contract.gd")
const Events = preload("res://simulation/events_v2.gd")
const Rules = preload("res://simulation/rules.gd")

const SEED: int = 260129
const ISLAND_SEEDS: int = 40
const GIFTS: Array[String] = ["red_ball_express", "fast_freighters", "bulk_freighters"]
const DRAWS: int = 60
const SAVE_PATH: String = "user://transport_test.save"

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


func fund(sim: RefCounted, amount: float) -> void:
	sim._transfer("external", "public", amount, "capital.initial", false)


func supply(sim: RefCounted, s: Dictionary, good: String, amount: float) -> void:
	sim._produce(s, good, amount, "test")


func grant(sim: RefCounted, tech: String) -> void:
	sim.state.research.completed.append(tech)
	for hand: Array in sim.state.research.offers.values():
		hand.erase(tech)


func finish_roads(sim: RefCounted) -> void:
	for road: Dictionary in sim.state.roads:
		road.ready_day = int(sim.state.day) - 1
		road.blocked_until = int(sim.state.day) - 1


func step(sim: RefCounted, days: int) -> void:
	for _i: int in range(days):
		sim.tick()


func run() -> void:
	_docks()
	_roads()
	_older_saves()
	_gifts()
	_gift_events()
	print(
		"V19_TRANSPORT_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)]
	)
	quit(0 if failures.is_empty() else 1)


## Two coastal sites the sea joins and the land does not, on the first seed that has them.
func _island_case() -> Dictionary:
	for seed_value: int in range(1, ISLAND_SEEDS + 1):
		var sim: RefCounted = Sim.new()
		sim.new_game(seed_value, "capital")
		for home: Dictionary in sim.state.world.regions:
			if not bool(home.coast):
				continue
			for other: Dictionary in sim.state.world.regions:
				if int(other.id) <= int(home.id) or not bool(other.coast):
					continue
				var a: int = int(home.id)
				var b: int = int(other.id)
				if bool(Logistics.route_between(sim, a, b, "engineered").reachable):
					continue
				if bool(Logistics.route_between(sim, a, b, "sea").reachable):
					return {"seed": seed_value, "a": a, "b": b}
	return {}


func _docks() -> void:
	var case: Dictionary = _island_case()
	check(not case.is_empty(), "some coast is reached only by sea")
	if case.is_empty():
		return
	var sim: RefCounted = Sim.new()
	sim.new_game(int(case.seed), "capital")
	sim.state.events_v2.next_draw = 99999
	var home: int = int(case.a)
	var island: int = int(case.b)
	check(sim.act("settle", {"site": home}) == "", "the first landing")
	sim.state.contract.licences.append("expedition")
	fund(sim, 90000.0)
	var s: Dictionary = sim.settlement(home)
	supply(sim, s, "materials", 600.0)
	supply(sim, s, "parts", 120.0)
	supply(sim, s, "food", 800.0)
	check(sim.act("settle", {"site": island}) == "", "a party sails to the island")
	while int(sim.settlement(island).arrival) > 0:
		sim.tick()
	# The island's orbital freight station is taken away: the docks do not need one.
	var town: Dictionary = sim.settlement(island)
	var kept: Array = []
	for b: Dictionary in town.buildings:
		if str(b.kind) != "port":
			kept.append(b)
	town.buildings = kept
	sim._refresh(town)
	var quote: Dictionary = sim.road_quote(home, island, "sea")
	check(
		str(quote.refusal) == "",
		"two small cargo docks need no freight station: " + str(quote.refusal)
	)
	check(
		str(sim.config.roads.sea.name) == "小型货运码头 ×2", "the sea link is offered as two small docks"
	)
	check(
		sim.act("connect", {"a": home, "b": island, "variant": "sea"}) == "",
		"the docks are ordered"
	)
	var lane: Dictionary = sim.state.roads.back()
	check(Logistics.link_level(lane) == 1, "a new link starts at level 1")
	check(Logistics.level_name(sim, lane) == "小型货运码头 ×2", "named as its two small docks")
	check(
		sim.act("upgrade_road", {"road": int(lane.id)}) == "线路尚未建成",
		"docks are not enlarged before the link opens"
	)
	finish_roads(sim)
	var capacity: int = int(lane.capacity)
	var days: int = int(lane.days)
	var upkeep: float = float(lane.upkeep)
	var medium: Dictionary = Logistics.next_level(sim, lane)
	check(str(medium.get("name", "")) == "中型货运码头 ×2", "the next level is two medium docks")
	check(str(medium.get("tech", "?")) == "", "medium docks need no technology")
	check(str(medium.get("refusal", "?")) == "", "and can be ordered now: " + str(medium.refusal))
	var cash: float = float(sim.state.cash)
	check(sim.act("upgrade_road", {"road": int(lane.id)}) == "", "the docks are enlarged")
	check(
		is_equal_approx(float(sim.state.cash), cash - float(medium.cost)),
		"the work is paid when it is ordered"
	)
	check(sim.act("upgrade_road", {"road": int(lane.id)}) == "这条线路正在升级", "one upgrade at a time")
	step(sim, int(medium.build_days) + 1)
	check(Logistics.link_level(lane) == 2, "medium docks after their build days")
	check(int(lane.capacity) == int(round(capacity * float(medium.capacity))), "they carry more")
	check(int(lane.days) == maxi(1, days + int(medium.days)), "and turn ships round faster")
	check(
		is_equal_approx(float(lane.upkeep), upkeep + float(medium.upkeep)), "and cost more to keep"
	)
	check(not bool(lane.get("paved", false)), "a sea link is never paved")
	var large: Dictionary = Logistics.next_level(sim, lane)
	check(
		str(large.get("refusal", "")).begins_with("需要技术"),
		"large docks wait for a technology: " + str(large.get("refusal", ""))
	)
	grant(sim, str(large.tech))
	check(sim.act("upgrade_road", {"road": int(lane.id)}) == "", "large docks with it")
	check(sim.save_game(SAVE_PATH) == "", "a save mid-upgrade")
	var other: RefCounted = Sim.new()
	check(other.load_game(SAVE_PATH) == "", "loads")
	var copy: Dictionary = other.state.roads[int(lane.id)]
	check(int(copy.get("upgrade_to", 0)) == 3, "the work in progress survives the save")
	step(other, int(large.build_days) + 1)
	check(Logistics.link_level(copy) == 3, "and finishes after loading")
	check(Logistics.next_level(other, copy).is_empty(), "large docks are the top level")
	check(
		other.act("upgrade_road", {"road": int(copy.id)}).begins_with("已是最高等级"),
		"nothing above them"
	)
	check(other.audit().is_empty(), "docks pass the audit")


func _roads() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital")
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	sim.state.contract.licences.append("expedition")
	fund(sim, 90000.0)
	check(sim.act("settle", {"region": 1}) == "", "the outpost is founded")
	step(sim, 30)
	var a: Dictionary = sim.settlement(0)
	supply(sim, a, "materials", 600.0)
	supply(sim, a, "parts", 80.0)
	check(sim.act("connect", {"a": 0, "b": 1, "mountain": true}) == "", "a mountain road")
	var road: Dictionary = sim.state.roads.back()
	finish_roads(sim)
	check(Logistics.level_name(sim, road) == "砂石路面", "a new road is gravel")
	var base_closure: float = Logistics.closure_chance(sim, road)
	var capacity: int = int(road.capacity)
	var days: int = int(road.days)
	var upkeep: float = float(road.upkeep)
	var paving: Dictionary = Logistics.next_level(sim, road)
	check(str(paving.name) == "铺装路面", "the next level is a paved surface")
	check(str(paving.refusal) == "需要技术：铺装道路", "which waits for 铺装道路")
	grant(sim, "paved_roads")
	check(sim.act("upgrade_road", {"road": int(road.id)}) == "", "paving is ordered")
	step(sim, int(paving.build_days) + 1)
	check(Logistics.link_level(road) == 2 and bool(road.paved), "the road is paved")
	check(
		is_equal_approx(Logistics.closure_chance(sim, road), base_closure * float(paving.closure)),
		"paving cuts the closure risk"
	)
	var trunk: Dictionary = Logistics.next_level(sim, road)
	check(str(trunk.name) == "四车道干线", "then it can be widened")
	check(str(trunk.refusal) == "需要技术：连续摊铺机", "with 连续摊铺机")
	grant(sim, "road_machines")
	supply(sim, a, "materials", 200.0)
	check(sim.act("upgrade_road", {"road": int(road.id)}) == "", "widening is ordered")
	step(sim, int(trunk.build_days) + 1)
	check(Logistics.link_level(road) == 3, "a four-lane trunk road")
	var both: float = float(paving.capacity) * float(trunk.capacity)
	check(
		absi(int(road.capacity) - int(round(capacity * both))) <= 1,
		"capacity grows at each step (%d from %d)" % [int(road.capacity), capacity]
	)
	check(int(road.days) == maxi(1, days + int(paving.days) + int(trunk.days)), "trips get shorter")
	check(
		is_equal_approx(float(road.upkeep), upkeep + float(paving.upkeep) + float(trunk.upkeep)),
		"a wider road costs more to keep"
	)
	check(
		is_equal_approx(
			Logistics.closure_chance(sim, road),
			base_closure * float(paving.closure) * float(trunk.closure)
		),
		"and closes less often"
	)
	check(Logistics.next_level(sim, road).is_empty(), "the trunk road is the top level")
	check(
		Logistics.level_steps(sim, {"variant": "shuttle"}).is_empty(),
		"a shuttle line has no levels"
	)
	check(sim.audit().is_empty(), "road levels pass the audit")


## Saves from before levels know only `paved`.
func _older_saves() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital")
	check(Logistics.link_level({"variant": "valley", "paved": true}) == 2, "an old paved road")
	check(Logistics.link_level({"variant": "valley"}) == 1, "an old unpaved road")
	check(Logistics.link_level({"variant": "sea"}) == 1, "an old sea route has small docks")
	var old: Dictionary = {"variant": "valley", "paved": true, "cost": 4000.0, "a": 0, "b": 1}
	check(str(Logistics.next_level(sim, old).name) == "四车道干线", "an old paved road can be widened")


func _gifts() -> void:
	var techs: Dictionary = Rules.read("techs").techs
	var found: Array = []
	for key: String in techs:
		if bool(techs[key].get("gift", false)):
			found.append(key)
			check(float(techs[key].weight) == 0.0, key + " is never weighed for a draw")
			check(not techs[key].effects.is_empty(), key + " does something")
	found.sort()
	var expected: Array = GIFTS.duplicate()
	expected.sort()
	check(found == expected, "three gift technologies: " + str(found))
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital")
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	var r: Dictionary = sim.state.research
	var dealt: bool = false
	for category: String in Rules.read("techs").categories:
		for _i: int in range(DRAWS):
			Research._draw(r, category, r.offers.get(category, []))
			for key: String in r.offers.get(category, []):
				dealt = dealt or GIFTS.has(key)
	check(not dealt, "no gift is ever dealt as a card")
	check(
		sim.act("research_allocate", {"tech": "red_ball_express", "staff": 3}) != "",
		"a team cannot research a gift"
	)
	check(not Research.add_lead(sim, "red_ball_express"), "nor can an event put it on the table")
	var researched: int = Research.researched(sim.state)
	var before: int = Logistics.road_days(sim, {"variant": "valley", "days": 10})
	check(Research.grant(sim, "red_ball_express"), "an event hands it over")
	check(not Research.grant(sim, "red_ball_express"), "once")
	check(not Research.grant(sim, "paved_roads"), "only gifts are handed over")
	check(
		Logistics.road_days(sim, {"variant": "valley", "days": 10}) < before,
		"red-ball trucks take time off every road trip"
	)
	check(Research.researched(sim.state) == researched, "a gift is not research done")
	check(
		int(Contract.goal_value(sim, "technologies")) == researched,
		"nor does it count towards the charter's technology goals"
	)
	var column: Dictionary = {}
	for each: Dictionary in Research.cards(sim):
		if str(each.id) == "construction":
			column = each
	check(column.get("gifts", []).has("红球快运车队"), "the research page lists it as a gift")
	check(sim.audit().is_empty(), "gifts pass the audit")


## Every gift comes from an event, and that event only fires where it makes sense.
func _gift_events() -> void:
	var defs: Dictionary = Events.definitions().definitions
	var handed: Dictionary = {}
	var sound: bool = true
	for id: String in defs:
		for node: Dictionary in defs[id].nodes.values():
			for option: Dictionary in node.choices:
				if option.has("tech_gift"):
					handed[str(option.tech_gift)] = id
					sound = sound and GIFTS.has(str(option.tech_gift))
	check(sound, "events hand over only gift technologies")
	for key: String in GIFTS:
		check(handed.has(key), "an event hands over " + key)
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital")
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	sim.state.contract.licences.append("expedition")
	fund(sim, 90000.0)
	check(sim.act("settle", {"region": 1}) == "", "a second town")
	step(sim, 30)
	supply(sim, sim.settlement(0), "materials", 300.0)
	var conditions: Dictionary = defs.red_ball_loop.conditions
	sim.state.day = maxi(int(sim.state.day), int(conditions.min_day))
	check(
		not Events._matches(sim, sim.settlement(0), conditions), "no red-ball offer without a road"
	)
	check(sim.act("connect", {"a": 0, "b": 1, "mountain": true}) == "", "a road")
	finish_roads(sim)
	check(Events._matches(sim, sim.settlement(0), conditions), "the offer can come with a road")
	check(
		not Events._matches(sim, sim.settlement(0), defs.retired_freighters.conditions),
		"ships are offered only to towns with docks"
	)
	var inst: Dictionary = Events._open(sim, "red_ball_loop", 0)
	check(not inst.is_empty(), "the offer opens")
	var view: Dictionary = Events.view(sim)
	var text: String = JSON.stringify(view)
	check(text.contains("车头上的红球"), "the card shows")
	check(
		sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "trial"}) == "",
		"the trial is funded"
	)
	for _i: int in range(60):
		if str(inst.node) == "adopted":
			break
		sim.tick()
	check(str(inst.node) == "adopted", "the trial ends with a decision")
	check(
		JSON.stringify(Events.view(sim)).contains("获得技术「红球快运车队」"),
		"the option says which technology it hands over"
	)
	check(
		sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "adopt"}) == "",
		"the red-ball loop is adopted"
	)
	check(sim.state.research.completed.has("red_ball_express"), "the colony has the gift")
	check(not Events._matches(sim, sim.settlement(0), conditions), "and is not offered it again")
	check(sim.audit().is_empty(), "the gift event passes the audit")
