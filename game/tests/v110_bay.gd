extends SceneTree
## 1.10 the bay (plan C2–C3, simulation/bay.gd). A mine on a far deposit builds its mine road with
## it: days and money for every unit beyond the reach, none for a near one. The small harbour stands
## only on the coast, once a town; working, it catches fish counted as the town's own food, adds
## port capacity and makes sea goods cheaper. Each coastal town has an offshore signal, placed by
## the simulation on the town's first day from the seed alone; reading it changes nothing, so the
## same game played while a player opens every page stays byte-identical. A survey from a working
## harbour says what the signal is on the day the boat returns.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bay = preload("res://simulation/bay.gd")
const Crews = preload("res://simulation/crews.gd")
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
	_mine_road()
	_harbour()
	_signal()
	_pages_change_nothing()
	print("V110_BAY_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


## A landing at the first coastal site, with money and stock enough for the checks.
func _colony(seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1)
	var coast: int = _coastal(sim)
	sim.act("settle", {"region": coast})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(coast), good, 600.0, "TEST stock")
	return sim


func _coastal(sim: RefCounted) -> int:
	for reg: Dictionary in sim.state.world.regions:
		if bool(reg.get("coast", false)):
			return int(reg.id)
	return -1


func _inland(sim: RefCounted) -> int:
	for reg: Dictionary in sim.state.world.regions:
		if not bool(reg.get("coast", false)):
			return int(reg.id)
	return -1


## The farthest and the nearest plot of a region from its centre.
func _far_and_near(sim: RefCounted, region: int) -> Array:
	var far: int = -1
	var near: int = -1
	var plots: Array = sim.state.world.regions[region].plots
	for index: int in range(plots.size()):
		var reach: float = Vector2(float(plots[index].x), float(plots[index].z)).length()
		if far < 0 or reach > Vector2(float(plots[far].x), float(plots[far].z)).length():
			far = index
		if near < 0 or reach < Vector2(float(plots[near].x), float(plots[near].z)).length():
			near = index
	return [far, near]


func _mine_road() -> void:
	var sim: RefCounted = _colony()
	var region: int = int(sim.state.settlements[0].region)
	var rule: Dictionary = Bay.rules(sim)
	var spec: Dictionary = sim.config.buildings.mine_ore
	var ends: Array = _far_and_near(sim, region)
	var plots: Array = sim.state.world.regions[region].plots
	var far_reach: float = Vector2(float(plots[ends[0]].x), float(plots[ends[0]].z)).length()
	var near_reach: float = Vector2(float(plots[ends[1]].x), float(plots[ends[1]].z)).length()
	check(far_reach > float(rule.haul_reach), "the farthest plot lies beyond the mine road's reach")
	check(near_reach <= float(rule.haul_reach), "the nearest within it")
	var far: Dictionary = sim.Production.build_preview(sim, region, "mine_ore", int(ends[0]))
	var near: Dictionary = sim.Production.build_preview(sim, region, "mine_ore", int(ends[1]))
	var beyond: float = far_reach - float(rule.haul_reach)
	var road_days: int = ceili(beyond * float(rule.haul_days_per_unit))
	check(int(far.haul.days) == road_days, "the road's days: %d" % road_days)
	check(
		is_equal_approx(float(far.haul.cost), beyond * float(rule.haul_cost_per_unit)),
		"and its money: ¥ %.0f" % float(far.haul.cost)
	)
	check(int(far.days) == int(near.days) + road_days, "added to the mine's days")
	check(
		is_equal_approx(float(far.cost), float(near.cost) + float(far.haul.cost)), "and to its cost"
	)
	check(int(near.haul.days) == 0 and float(near.haul.cost) == 0.0, "a near mine needs no road")
	check(int(near.days) == int(spec.days), "and takes the catalogue's days")
	var farm: Dictionary = sim.Production.build_preview(sim, region, "farm", int(ends[0]))
	check(int(farm.haul.days) == 0, "only mines build a road")


func _harbour() -> void:
	var inland_sim: RefCounted = Sim.new()
	inland_sim.new_game(SEED, "capital", 1)
	var inland: int = _inland(inland_sim)
	inland_sim.act("settle", {"region": inland})
	inland_sim._transfer("external", "public", 80000.0, "TEST funds", false)
	check(
		inland_sim.act("build", {"site": inland, "kind": "harbor"}) != "",
		"an inland town cannot build a harbour"
	)
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.settlement(int(sim.state.settlements[0].region))
	var region: int = int(s.region)
	var rule: Dictionary = Bay.rules(sim)
	check(Bay.sea_discount(sim, s, "food") == 0.0, "no sea discount before a harbour")
	check(sim.act("build", {"site": region, "kind": "harbor"}) == "", "a coastal town builds one")
	var harbor: Dictionary = s.buildings.back()
	check(int(harbor.get("plot", -1)) < 0, "at the shore, on no plot")
	check(sim.act("build", {"site": region, "kind": "harbor"}) != "", "and only one harbour a town")
	for _day: int in range(int(harbor.remaining) + 2):
		sim.tick()
	check(Bay.harbor_working(sim, s), "once built it works")
	check(
		is_equal_approx(Bay.sea_discount(sim, s, "food"), float(rule.sea_discount)),
		"food comes in cheaper by sea"
	)
	check(Bay.sea_discount(sim, s, "ore") == 0.0, "goods the sea does not carry do not")
	var fish: float = float(sim.config.buildings.harbor.fish)
	sim.tick()
	# The day's own food goes into the contract's window when the day closes.
	var local: float = float(sim.state.contract.food_window.back()[0])
	check(
		local >= fish * float(harbor.get("efficiency", 1.0)) - 0.001,
		"its catch counts as the town's own food (%.1f a day)" % local
	)
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))


func _signal() -> void:
	var sim: RefCounted = _colony()
	var region: int = int(sim.state.settlements[0].region)
	var s: Dictionary = sim.settlement(region)
	check(Bay.offshore_signal(sim, region).is_empty(), "no signal before the town's first day")
	check(
		not sim.state.world.regions[region].has("offshore"), "and reading for one does not make one"
	)
	sim.tick()
	var reading: Dictionary = Bay.offshore_signal(sim, region)
	check(not reading.is_empty(), "the first day places it")
	check(str(reading.good) in ["copper", "crystal"], "copper or crystal: " + str(reading.good))
	check(not bool(reading.surveyed), "not yet known")
	var twin: RefCounted = _colony()
	twin.tick()
	check(
		JSON.stringify(Bay.offshore_signal(twin, region)) == JSON.stringify(reading),
		"the same seed places the same signal"
	)
	var inland_sim: RefCounted = Sim.new()
	inland_sim.new_game(SEED, "capital", 1)
	var inland: int = _inland(inland_sim)
	inland_sim.act("settle", {"region": inland})
	inland_sim.tick()
	check(Bay.offshore_signal(inland_sim, inland).is_empty(), "an inland town has none")
	check(sim.act("survey_offshore", {"site": region}) != "", "a survey needs a working harbour")
	sim.act("build", {"site": region, "kind": "harbor"})
	var harbor: Dictionary = s.buildings.back()
	for _day: int in range(int(harbor.remaining) + 2):
		sim.tick()
	var rule: Dictionary = Bay.rules(sim)
	var cash: float = float(sim.state.cash)
	check(sim.act("survey_offshore", {"site": region}) == "", "then a boat goes out")
	check(
		is_equal_approx(cash - float(sim.state.cash), float(rule.survey_cost)),
		"for the survey's price"
	)
	check(sim.act("survey_offshore", {"site": region}) != "", "one boat at a time")
	for _day: int in range(int(rule.survey_days) - 1):
		sim.tick()
	check(not bool(reading.surveyed), "it is out for the survey's days")
	sim.tick()
	check(bool(reading.surveyed), "and says what the signal is when it returns")
	var tonnes: float = float(
		rule.signal_rich_tonnes if bool(reading.rich) else rule.signal_poor_tonnes
	)
	check(
		float(reading.tonnes) >= tonnes * 0.8 - 0.5 and float(reading.tonnes) <= tonnes * 1.2 + 0.5,
		"%s, about %.0f" % ["rich" if bool(reading.rich) else "poor", float(reading.tonnes)]
	)
	check(sim.audit().is_empty(), "the audit holds: " + str(sim.audit()))


## The same game twice, one of them read every day the way the pages read it: the same bytes.
func _pages_change_nothing() -> void:
	var plain: RefCounted = _colony()
	var looked: RefCounted = _colony()
	for sim: RefCounted in [plain, looked]:
		var region: int = int(sim.state.settlements[0].region)
		sim.act("build", {"site": region, "kind": "harbor"})
		sim.act("build", {"site": region, "kind": "habitat"})
	for _day: int in range(40):
		for index: int in range(looked.state.world.regions.size()):
			Bay.offshore_signal(looked, index)
		Crews.view(looked)
		for s: Dictionary in looked.state.settlements:
			Crews.eta(looked, s)
			Bay.harbor_working(looked, s)
		plain.tick()
		looked.tick()
	check(
		JSON.stringify(plain.state) == JSON.stringify(looked.state),
		"reading the bay and the crews as the pages do changes nothing"
	)
