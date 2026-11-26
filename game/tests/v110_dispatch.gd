extends SceneTree
## 1.10.1 crews beyond buildings (the November 20 brief, simulation/crews.gd):
## - a land road ordered now moves on only on a day a crew from one of its towns works at it; a day
##   without one puts its finish a day later; a sea link needs none; a road from an older save keeps
##   its date;
## - a crew at a road closed by rockfall clears it twice as fast; without one it keeps its days;
## - a field survey or a drilling takes a crew from the nearest town into the field for its days (its
##   project waits) and needs one at home to go;
## - each town's standing order puts road work and facilities in the order the player chose, after
##   the projects that fix a shortage, which still take a crew off a road;
## - every crew beyond the first two costs a quarter more to train or to hire;
## - the audit holds, and the same orders on the same seed give the same state.

const Watchdog = preload("res://tests/support/watchdog.gd")
const LegacyWorld = preload("res://tests/support/legacy_world.gd")
const Sim = preload("res://simulation/sim.gd")
const Crews = preload("res://simulation/crews.gd")
const Geology = preload("res://world/geo2/geology.gd")
const Features = preload("res://simulation/features.gd")
const WorldGen = preload("res://world/world_gen.gd")
const SEED: int = 20261029

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
	_road_waits_for_a_crew()
	_standing_orders()
	_repairs()
	_field_work()
	_costlier_crews()
	_older_roads()
	_same_seed_same_state()
	print(
		"V110_DISPATCH_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)]
	)
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


## The capital and a second town founded by expedition: [sim, the second town's region].
func _two_towns() -> Array:
	var sim: RefCounted = _colony()
	sim.state.contract.licences.append("expedition")
	var other: int = -1
	for region: int in range(1, sim.state.world.regions.size()):
		if other < 0 and sim.act("settle", {"site": region, "from": 0}) == "":
			other = region
	for _day: int in range(40):
		sim.tick()
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(0), good, 900.0, "TEST stock")
	return [sim, other]


## A land road between the towns, ordered now; empty when none can be laid.
func _land_road(sim: RefCounted, other: int) -> Dictionary:
	for variant: String in ["valley", "engineered"]:
		if sim.act("connect", {"a": 0, "b": other, "variant": variant}) == "":
			return sim.state.roads.back()
	return {}


## Keeps a town's crews on a building, so a road ordered later waits.
func _busy(sim: RefCounted, days: int, site: int = 0) -> Dictionary:
	sim.act("build", {"site": site, "kind": "habitat"})
	var housing: Dictionary = sim.settlement(site).buildings.back()
	housing.remaining = days
	housing.total_days = days
	return housing


func _road_waits_for_a_crew() -> void:
	var pair: Array = _two_towns()
	var sim: RefCounted = pair[0]
	var other: int = int(pair[1])
	check(other >= 0, "a second town is founded")
	if other < 0:
		return
	var away: int = Crews.teams_at(sim, other).size()
	for team: Dictionary in sim.state.crews.teams.duplicate():
		if int(team.region) == other:
			sim.state.crews.teams.erase(team)
			sim.settlement(other).crew = int(sim.settlement(other).crew) - 1
			sim.settlement(other).population = int(sim.settlement(other).population) - 1
	check(Crews.teams_at(sim, other).is_empty(), "the second town has no crew (%d sent off)" % away)
	var housing: Dictionary = _busy(sim, 12)
	var road: Dictionary = _land_road(sim, other)
	check(not road.is_empty() and bool(road.get("crew_built", false)), "a land road is ordered")
	if road.is_empty():
		return
	sim.tick()
	var finish: int = int(road.ready_day)
	for _day: int in range(5):
		sim.tick()
	check(
		int(road.ready_day) == finish + 5,
		(
			"with the crew on the housing the road waits: its finish moves %d days"
			% [int(road.ready_day) - finish]
		)
	)
	var waiting: Array = sim.Crews.view(sim).waiting.get(0, [])
	check(
		not waiting.is_empty() and str(waiting[0]).begins_with("修路"),
		"it is in the capital's queue: %s" % str(waiting)
	)
	housing.remaining = 1
	sim.tick()
	sim.tick()
	var team: Dictionary = Crews.teams_at(sim, 0)[0]
	check(
		str(team.task) == Crews.ROAD and int(team.target) == int(road.id),
		"the crew goes to the road once the housing is done"
	)
	finish = int(road.ready_day)
	for _day: int in range(3):
		sim.tick()
	check(int(road.ready_day) == finish, "with a crew on it the road keeps its date")
	var days: int = int(road.ready_day) - int(sim.state.day)
	for _day: int in range(days + 2):
		sim.tick()
	check(not WorldGen.road_blocked(road, int(sim.state.day)), "and opens on it")
	check(str(team.task) != Crews.ROAD, "the crew is free again")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
	# A sea link's docks are not crew work.
	var sea: Dictionary = {}
	for r: Dictionary in sim.state.roads:
		if str(r.get("variant", "")) == "sea":
			sea = r
	if sea.is_empty():
		print("NOTE no sea link between these towns; the sea rule is checked on a record")
		sea = road.duplicate()
		sea.variant = "sea"
		sea.ready_day = int(sim.state.day) + 9
	check(Crews.road_work(sim, sea).is_empty(), "a sea link's docks need no crew")


func _standing_orders() -> void:
	var pair: Array = _two_towns()
	var sim: RefCounted = pair[0]
	var other: int = int(pair[1])
	if other < 0:
		return
	_busy(sim, 40)
	sim.tick()
	sim.act("build", {"site": 0, "kind": "water"})
	var road: Dictionary = _land_road(sim, other)
	sim.tick()
	sim.act("build", {"site": 0, "kind": "farm"})
	var s: Dictionary = sim.settlement(0)
	var working: Dictionary = sim.state.crews.working
	var names: Dictionary = {}
	for order: String in Crews.ORDERS:
		check(sim.act("crew_order", {"site": 0, "order": order}) == "", "standing order %s" % order)
		var row: Array = []
		for item: Dictionary in Crews.queue(sim, s, working):
			row.append("road" if item.has("road") else str(item.kind))
		names[order] = row
	check(
		names.oldest == ["water", "road", "farm"],
		"in order given: the pump, the road, the farm %s" % str(names.oldest)
	)
	check(names.roads == ["road", "water", "farm"], "roads first %s" % str(names.roads))
	check(
		names.facilities == ["water", "farm", "road"], "facilities first %s" % str(names.facilities)
	)
	check(
		sim.act("crew_order", {"site": 0, "order": "nonsense"}) != "", "an unknown order is refused"
	)
	# A shortage takes the crew off the road.
	sim.act("crew_order", {"site": 0, "order": "roads"})
	var housing: Dictionary = {}
	for b: Dictionary in s.buildings:
		if str(b.kind) == "habitat" and int(b.remaining) > 0:
			housing = b
	housing.remaining = 1
	sim.tick()
	sim.tick()
	var team: Dictionary = Crews.teams_at(sim, 0)[0]
	check(str(team.task) == Crews.ROAD, "under roads first the crew takes the road")
	var pump: Dictionary = {}
	for b: Dictionary in s.buildings:
		if str(b.kind) == "water" and int(b.remaining) > 0:
			pump = b
	var pump_days: int = int(pump.remaining)
	sim._short(s, "water")
	sim.tick()
	check(
		str(team.task) == Crews.BUILD and int(team.target) == int(pump.uid),
		"a water shortage takes it off the road to the pump"
	)
	check(int(pump.remaining) == pump_days - 1, "which moves on that day")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _repairs() -> void:
	var pair: Array = _two_towns()
	var sim: RefCounted = pair[0]
	var other: int = int(pair[1])
	if other < 0:
		return
	var road: Dictionary = _land_road(sim, other)
	if road.is_empty():
		return
	road.ready_day = int(sim.state.day) - 1
	road.blocked_until = int(sim.state.day) - 1
	# The capital's only crew busy on housing: the closure keeps its days.
	var housing: Dictionary = _busy(sim, 60)
	sim.tick()
	road.blocked_until = int(sim.state.day) + 30
	var closed: int = int(road.blocked_until)
	for _day: int in range(4):
		sim.tick()
	check(int(road.blocked_until) == closed, "a closure with no crew keeps its date")
	check(
		str(Crews.road_work(sim, road).get("kind", "")) == Crews.REPAIR,
		"and asks for a repair crew"
	)
	housing.remaining = 1
	sim.tick()
	sim.tick()
	var team: Dictionary = {}
	for each: Dictionary in sim.state.crews.teams:
		if str(each.task) == Crews.REPAIR:
			team = each
	check(not team.is_empty(), "a free crew goes to clear it first (the default order)")
	var left: int = int(road.blocked_until) - int(sim.state.day)
	for _day: int in range(3):
		sim.tick()
	check(
		int(road.blocked_until) - int(sim.state.day) == left - 6,
		(
			"each day a crew works it clears two: %d days left → %d"
			% [left, int(road.blocked_until) - int(sim.state.day)]
		)
	)
	for _day: int in range(left):
		sim.tick()
	check(not WorldGen.road_blocked(road, int(sim.state.day)), "the road reopens early")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _field_work() -> void:
	var sim: RefCounted = Sim.new()
	LegacyWorld.new_game(sim, SEED, "capital", 1)
	var rules: Dictionary = sim.Prospecting.rules(sim)
	var reach: float = float(rules.field.reach_km) / (deg_to_rad(1.0) * float(sim.geo.radius_km))
	var spot: Dictionary = {}
	var region: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if not spot.is_empty():
			break
		for hit: Dictionary in Geology.reaching(sim.geo, reg.lat, reg.lon, reach * 0.8):
			if (
				spot.is_empty()
				and not bool(hit.deposit.hidden)
				and not Features.resource_frozen(str(hit.deposit.resource))
			):
				spot = hit.deposit
				region = int(reg.id)
	check(not spot.is_empty(), "a visible deposit in a field team's reach of a site")
	if spot.is_empty():
		return
	sim.act("settle", {"region": region})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(region), good, 900.0, "TEST stock")
	var town: Dictionary = sim.settlement(region)
	sim.act(
		"prospect_observe",
		{"resource": str(spot.resource), "lat": float(spot.lat), "lon": float(spot.lon)}
	)
	for _day: int in range(int(rules.orbital.days) + 1):
		sim.tick()
	var target: Dictionary = {}
	for anomaly: Dictionary in sim.state.prospecting.anomalies:
		if str(anomaly.deposit) == str(spot.id):
			target = anomaly
	check(not target.is_empty(), "orbit shows it")
	if target.is_empty():
		return
	var housing: Dictionary = _busy(sim, 50, region)
	sim.tick()
	var team: Dictionary = Crews.teams_at(sim, region)[0]
	var saved: Dictionary = team.duplicate()
	team.task = Crews.TRAIN
	team.until = int(sim.state.day) + 30
	check(
		sim.act("prospect_send", {"step": "field", "id": int(target.id)}).contains("工程队"),
		"with its only crew in training the town cannot send a field team"
	)
	team.task = saved.task
	team.target = saved.target
	team.until = saved.until
	var left: int = int(housing.remaining)
	check(
		sim.act("prospect_send", {"step": "field", "id": int(target.id)}) == "",
		"with its crew at home it can"
	)
	check(str(team.task) == Crews.FIELD, "the crew goes into the field, off the housing")
	for _day: int in range(int(rules.field.days) - 1):
		sim.tick()
	check(int(housing.remaining) == left, "the housing waits while it is away")
	check(
		sim.act("crew_send", {"crew": int(team.id), "to": region}).contains("野外"),
		"a crew in the field cannot be sent elsewhere"
	)
	for _day: int in range(3):
		sim.tick()
	check(str(target.stage) == "field", "the field survey reports")
	check(
		str(team.task) == Crews.BUILD and int(housing.remaining) < left,
		"and the crew is back on the housing"
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
	check(int(town.crew) == 1, "the town still counts its crew")


func _costlier_crews() -> void:
	var sim: RefCounted = _colony()
	var rule: Dictionary = sim.pop_rules.crews
	var base: float = float(rule.train_cost)
	var step: float = float(rule.growth_per_crew)
	var free: int = int(rule.free_crews)
	var prices: Array = []
	var paid: Array = []
	var s: Dictionary = sim.settlement(0)
	for _crew: int in range(4):
		s.workers = int(s.workers) + 2
		s.population = int(s.population) + 2
		var price: float = Crews.train_price(sim)
		var cash: float = float(sim.state.cash)
		check(sim.act("crew_train", {"region": 0}) == "", "a crew is trained at ¥ %.0f" % price)
		prices.append(price)
		paid.append(cash - float(sim.state.cash))
	var expected: Array = []
	for index: int in range(4):
		var count: int = 1 + index
		expected.append(base * (1.0 + step * maxi(0, count - free)))
	var ok: bool = true
	for index: int in range(4):
		ok = ok and is_equal_approx(float(prices[index]), float(expected[index]))
		ok = ok and is_equal_approx(float(paid[index]), float(prices[index]))
	check(
		ok,
		"each crew beyond the first %d costs %.0f%% more: %s" % [free, step * 100.0, str(prices)]
	)
	var one: float = sim.Population.campaign_price(sim, "crew")
	var two: float = sim.Population.campaign_cost(sim, "crew", 2)
	var teams: int = sim.state.crews.teams.size()
	check(
		is_equal_approx(
			two, one * (2.0 + step * (maxi(0, teams - free) + maxi(0, teams + 1 - free)))
		),
		"hiring from outside rises the same way: two cost ¥ %.0f" % two
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


## A road from a save made before crews built roads keeps its date without a crew.
func _older_roads() -> void:
	var pair: Array = _two_towns()
	var sim: RefCounted = pair[0]
	var other: int = int(pair[1])
	if other < 0:
		return
	_busy(sim, 30)
	var road: Dictionary = _land_road(sim, other)
	if road.is_empty():
		return
	road.erase("crew_built")
	var finish: int = int(road.ready_day)
	for _day: int in range(4):
		sim.tick()
	check(int(road.ready_day) == finish, "an older road keeps its date without a crew")


func _same_seed_same_state() -> void:
	var states: Array = []
	for _run: int in range(2):
		var pair: Array = _two_towns()
		var sim: RefCounted = pair[0]
		var other: int = int(pair[1])
		_busy(sim, 8)
		_land_road(sim, other)
		sim.act("crew_order", {"site": 0, "order": "roads"})
		for _day: int in range(30):
			sim.tick()
		states.append(var_to_str(sim.state))
	check(states[0] == states[1], "the same orders on the same seed give the same state")
