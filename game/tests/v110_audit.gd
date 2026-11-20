extends SceneTree
## 1.10, the November 20 audit:
## - the first ore truck and the first ship are real consignments (consignments.gd): a food order
##   or ore with no mine behind it is no ore truck; a working harbour with no cargo has no ship;
##   ore sold in another town names the mine's town; the maps and the district read the same
##   records;
## - a mine queued to branch off another mine's road builds the main road itself when that mine is
##   cancelled before it was finished, and the crews build the road's mine first;
## - crews travel only where freight can: no crew sets out over a closed link, and one on the road
##   waits out a closure as cargo does;
## - a town's 30-day change is its measured population change, and every person in it is accounted
##   for by immigration, departures, births and people moved between towns.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bay = preload("res://simulation/bay.gd")
const Crews = preload("res://simulation/crews.gd")
const Consignments = preload("res://simulation/consignments.gd")
const Stats = preload("res://simulation/stats.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const SiteGenScript = preload("res://world/geo2/site_gen.gd")
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
	_first_ore()
	_first_ship()
	_ore_from_another_town()
	_mine_road_cancel()
	_crews_follow_freight()
	_growth_is_measured()
	_farm_forecast()
	_water_lesson()
	_radius()
	_stage_three()
	_tutorial_bay()
	print("V110_AUDIT_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(coastal: bool = true) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var region: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if bool(reg.get("coast", false)) == coastal and region < 0:
			region = int(reg.id)
	sim.act("settle", {"region": region})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(region), good, 600.0, "TEST stock")
	return sim


## A finished building put straight into a town, as a long-built one would be.
func _finished(sim: RefCounted, s: Dictionary, kind: String, plot: int = -1) -> Dictionary:
	var b: Dictionary = sim.Production.new_building(sim, kind, 0)
	b.plot = plot
	b.active = true
	s.buildings.append(b)
	return b


func _first_ore() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.state.settlements[0]
	# The audited case: a food order worth 78 from a colony with no mine.
	Consignments.exported(sim, s, "food", 4.0, 78.0)
	check(not sim.state.firsts.has("ore"), "a food order is not the first ore truck")
	Consignments.exported(sim, s, "ore", 2.0, 16.0)
	check(not sim.state.firsts.has("ore"), "nor is ore sold with no mine behind it")
	var mine: Dictionary = _finished(sim, s, "mine_ore")
	Consignments.exported(sim, s, "ore", 3.0, 24.0)
	var first: Dictionary = sim.state.firsts.get("ore", {})
	check(
		(
			int(first.get("region", -1)) == int(s.region)
			and int(first.get("building", 0)) == int(mine.uid)
			and str(first.get("resource", "")) == "ore"
			and is_equal_approx(float(first.get("amount", 0.0)), 3.0)
			and is_equal_approx(float(first.get("value", 0.0)), 24.0)
			and str(first.get("vehicle", "")) == "矿车"
		),
		"the first ore truck: the town, its mine, 300 t of iron ore, ¥ 24, by truck"
	)
	check(
		Consignments.ore_run(sim.state, s, 30) == int(mine.uid),
		"the district's ore truck runs from that mine"
	)
	Consignments.exported(sim, s, "ore", 5.0, 40.0)
	check(
		is_equal_approx(float(sim.state.firsts.ore.amount), 3.0),
		"a later load does not replace the first"
	)
	# Through a day of the game: trade records the export itself.
	var played: RefCounted = _colony()
	var town: Dictionary = played.state.settlements[0]
	_finished(played, town, "mine_ore")
	played._produce(town, "ore", 40.0, "TEST ore")
	for _day: int in range(3):
		played.tick()
	var traded: Dictionary = played.state.firsts.get("ore", {})
	check(
		int(traded.get("region", -1)) == int(town.region) and float(traded.get("value", 0.0)) > 0.0,
		(
			"the game's own trade records it: %.0f t for ¥ %.0f on day %d"
			% [
				played.tonnes(float(traded.get("amount", 0.0))),
				float(traded.get("value", 0.0)),
				int(traded.get("day", -1))
			]
		)
	)
	check(played.audit().is_empty(), "the audit holds: %s" % str(played.audit()))


func _first_ship() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.state.settlements[0]
	var harbour: Dictionary = _finished(sim, s, "harbor")
	check(Bay.harbor_working(sim, s), "a working harbour")
	check(not sim.state.firsts.has("ship"), "no first ship before any cargo")
	check(not Consignments.ship_calling(sim.state, s, 30), "and no ship at the berth")
	Consignments.imported(sim, s, "food", 6.0, 21.0)
	var first: Dictionary = sim.state.firsts.get("ship", {})
	check(
		(
			int(first.get("region", -1)) == int(s.region)
			and int(first.get("building", 0)) == int(harbour.uid)
			and str(first.get("direction", "")) == "import"
			and str(first.get("resource", "")) == "food"
			and str(first.get("vehicle", "")) == "货船"
		),
		"the first ship lands the first cargo at that harbour: 600 t of food"
	)
	check(Consignments.ship_calling(sim.state, s, 30), "a ship is at the berth while cargo moves")
	sim.state.day = int(sim.state.day) + 31
	check(not Consignments.ship_calling(sim.state, s, 30), "and gone a month after the last")
	# Through days of the game: the harbour is built; nothing moves while the stores are full, and
	# the first ship comes with the first cargo the town needs.
	var played: RefCounted = _colony()
	var town: Dictionary = played.state.settlements[0]
	check(
		played.act("build", {"site": int(town.region), "kind": "harbor"}) == "", "a harbour ordered"
	)
	var opened: int = -1
	for _day: int in range(90):
		played.tick()
		if Bay.harbor_working(played, town):
			opened = int(played.state.day)
			break
	check(opened >= 0, "it works from day %d" % opened)
	check(not played.state.firsts.has("ship"), "no ship yet: the stores are full, nothing to carry")
	played._consume(town, "food", float(town.stock.food))
	for _day: int in range(3):
		played.tick()
	var ship: Dictionary = played.state.firsts.get("ship", {})
	check(
		(
			int(ship.get("day", -1)) >= opened
			and str(ship.get("direction", "")) == "import"
			and str(ship.get("resource", "")) == "food"
			and float(ship.get("amount", 0.0)) > 0.0
		),
		(
			"the first ship lands the food the town ran short of: %.0f t on day %d"
			% [played.tonnes(float(ship.get("amount", 0.0))), int(ship.get("day", -1))]
		)
	)
	check(played.audit().is_empty(), "the audit holds")


func _ore_from_another_town() -> void:
	var sim: RefCounted = _colony()
	var capital: Dictionary = sim.state.settlements[0]
	var other: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if (
			other < 0
			and int(reg.id) != int(capital.region)
			and sim.settle_refusal(int(reg.id), "frontier") == ""
		):
			other = int(reg.id)
	if other < 0:
		sim.state.contract.licences.append("expedition")
		for reg: Dictionary in sim.state.world.regions:
			if (
				other < 0
				and int(reg.id) != int(capital.region)
				and sim.settle_refusal(int(reg.id), "frontier") == ""
			):
				other = int(reg.id)
	check(sim.act("settle", {"site": other, "kind": "frontier"}) == "", "a second town")
	var mining: Dictionary = sim.settlement(other)
	var mine: Dictionary = _finished(sim, mining, "mine_copper")
	# Its own cargo station sells its copper: the first truck is the second town's.
	Consignments.exported(sim, mining, "copper", 2.0, 28.0)
	check(
		(
			int(sim.state.firsts.get("ore", {}).get("region", -1)) == other
			and int(sim.state.firsts.ore.building) == int(mine.uid)
		),
		"the first ore truck is the second town's, from its mine"
	)
	# Copper carried by road and sold at the capital names the mine's town.
	var routed: RefCounted = _colony()
	var home: Dictionary = routed.state.settlements[0]
	routed.state.contract.licences.append("expedition")
	var far: int = -1
	for reg: Dictionary in routed.state.world.regions:
		if (
			far < 0
			and int(reg.id) != int(home.region)
			and routed.settle_refusal(int(reg.id), "frontier") == ""
		):
			far = int(reg.id)
	routed.act("settle", {"site": far, "kind": "frontier"})
	var source: Dictionary = routed.settlement(far)
	source.arrival = 0
	var dug: Dictionary = _finished(routed, source, "mine_copper")
	routed.state.roads.append(
		{
			"id": routed.state.roads.size(),
			"a": int(home.region),
			"b": far,
			"variant": "valley",
			"days": 3,
			"ready_day": 0,
			"blocked_until": 0
		}
	)
	Consignments.exported(routed, home, "copper", 2.0, 28.0)
	var first: Dictionary = routed.state.firsts.get("ore", {})
	check(
		(
			int(first.get("region", -1)) == far
			and int(first.get("building", 0)) == int(dug.uid)
			and int(first.get("sold_at", -1)) == int(home.region)
		),
		"copper sold at the capital after the road names the mine's town and the selling one"
	)


func _mine_road_cancel() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	var plots: Array = sim.state.world.regions[region].plots
	var reach: float = float(Bay.rules(sim).haul_reach)
	var far: Array = []
	for index: int in range(plots.size()):
		var point := Vector2(float(plots[index].x), float(plots[index].z))
		if point.length() <= reach:
			continue
		for kind: String in ["mine_ore", "mine_copper", "mine_crystal"]:
			if sim.Sites.plot_fits(sim, plots[index], kind):
				far.append([index, kind, point])
				break
	check(far.size() >= 2, "two deposits beyond the reach")
	if far.size() < 2:
		return
	# A: the first far mine; B: the one nearest to A, whose own road would be longer than its spur.
	var a: Array = far[0]
	var b: Array = []
	for entry: Array in far.slice(1):
		var own: float = Vector2(entry[2]).length() - reach
		if (
			Vector2(entry[2]).distance_to(a[2]) < own
			and (
				b.is_empty()
				or Vector2(entry[2]).distance_to(a[2]) < Vector2(b[2]).distance_to(a[2])
			)
		):
			b = entry
	check(not b.is_empty(), "a deposit nearer to A's mine than to the edge of the reach")
	if b.is_empty():
		return
	var alone: Dictionary = sim.Production.build_preview(sim, region, b[1], b[0])
	sim.act("build", {"site": region, "kind": a[1], "plot": a[0]})
	var mine_a: Dictionary = s.buildings.back()
	sim.act("build", {"site": region, "kind": b[1], "plot": b[0]})
	var mine_b: Dictionary = s.buildings.back()
	check(int(mine_b.haul.via) == int(mine_a.uid), "B branches off A's road")
	check(
		int(mine_b.remaining) < int(alone.days),
		"and is quicker than alone: %d < %d days" % [int(mine_b.remaining), int(alone.days)]
	)
	# The crews build A, whose road B needs, before B, even when B is chosen to go next.
	sim.act("crew_next", {"site": region, "uid": int(mine_b.uid)})
	var order: Array = Crews.queue(sim, s, {})
	check(order.find(mine_a) < order.find(mine_b), "the crews build A's road before B")
	var days_before: int = int(mine_b.remaining)
	var cash_before: float = float(sim.state.cash)
	sim.act("demolish", {"region": region, "index": s.buildings.find(mine_a)})
	check(
		int(mine_b.haul.days) == int(alone.haul.days) and int(mine_b.remaining) > days_before,
		"cancelling A gives B the main road: %d days, was %d" % [int(mine_b.remaining), days_before]
	)
	check(int(mine_b.remaining) == int(alone.days), "B takes as long as it would have alone")
	check(int(mine_b.haul.via) == 0, "and its road starts from the town")
	var charged: float = cash_before - float(sim.state.cash)
	check(
		charged >= 0.0 and charged <= float(alone.haul.cost),
		"the extra road money is charged once at most: ¥ %.0f" % charged
	)
	check(sim.audit().is_empty(), "the audit holds")


func _crews_follow_freight() -> void:
	var sim: RefCounted = _colony()
	var capital: Dictionary = sim.state.settlements[0]
	sim.state.contract.licences.append("expedition")
	var other: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if (
			other < 0
			and int(reg.id) != int(capital.region)
			and sim.settle_refusal(int(reg.id), "frontier") == ""
		):
			other = int(reg.id)
	sim.act("settle", {"site": other, "kind": "frontier"})
	for _day: int in range(int(sim.settlement(other).arrival) + 1):
		sim.tick()
	sim.state.roads.append(
		{
			"id": sim.state.roads.size(),
			"a": int(capital.region),
			"b": other,
			"variant": "valley",
			"days": 4,
			"ready_day": 0,
			"blocked_until": 0,
			"coordinates": [],
			"capacity": 10.0,
			"distance": 100.0,
			"level": 1
		}
	)
	var road: Dictionary = sim.state.roads.back()
	check(Crews.travel_days(sim, int(capital.region), other) > 0, "an open road: a crew can go")
	road.blocked_until = int(sim.state.day) + 6
	check(WorldGen.road_blocked(road, int(sim.state.day)), "the road closes; freight stops")
	var link: Dictionary = Crews.travel_link(sim, int(capital.region), other)
	check(
		int(link.days) < 0 and str(link.reason).contains("封闭"),
		"no crew sets out over it: %s" % str(link.reason)
	)
	var team: Dictionary = {}
	for t: Dictionary in sim.state.crews.teams:
		if int(t.region) == int(capital.region) and team.is_empty():
			team = t
	check(sim.act("crew_send", {"crew": int(team.id), "to": other}) != "", "the order is refused")
	# A crew already on the road when it closes waits, as the cargo does.
	road.blocked_until = 0
	team.task = ""
	check(
		sim.act("crew_send", {"crew": int(team.id), "to": other}) == "",
		"sent while the road is open"
	)
	var due: int = int(team.until)
	road.blocked_until = int(sim.state.day) + 5
	for _day: int in range(4):
		sim.tick()
	check(
		str(team.task) == "travel" and int(team.region) == int(capital.region),
		"it has not arrived across the closed road"
	)
	check(
		int(team.until) > due, "its arrival moves back day by day: %d → %d" % [due, int(team.until)]
	)
	for _day: int in range(12):
		sim.tick()
	check(int(team.region) == other, "it arrives once the road reopens")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _growth_is_measured() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var bot: RefCounted = Bot.new()
	bot.begin(sim, SEED)
	var worst: int = 0
	var measured: int = 0
	for _day: int in range(420):
		bot.on_day()
		sim.tick()
		if int(sim.state.day) % 30 != 0:
			continue
		for s: Dictionary in sim.state.settlements:
			var change: Dictionary = Stats.population_change(sim.state, int(s.region))
			if not bool(change.known):
				continue
			measured += 1
			worst = maxi(worst, absi(int(change.other)))
			if int(change.now) != int(s.population):
				check(
					false,
					(
						"day %d %s: the record %d is the town's %d"
						% [int(sim.state.day), s.name, int(change.now), int(s.population)]
					)
				)
	check(measured > 10, "%d monthly readings over 420 days" % measured)
	check(worst == 0, "every change is explained by its parts (largest unexplained: %d)" % worst)
	var s: Dictionary = sim.state.settlements[0]
	var view: Dictionary = sim.Population.view(sim, int(s.region))
	var change: Dictionary = view.change
	check(
		int(change.net) == int(change.now) - int(change.then),
		(
			"the page's net change is the population's: %d → %d (%+d: in %d, out %d, born %d, moved %+d)"
			% [
				int(change.then),
				int(change.now),
				int(change.net),
				int(change.arrivals),
				int(change.departures),
				int(change.births),
				int(change.moves)
			]
		)
	)
	check(sim.audit().is_empty(), "the audit holds")


## The audited forecast: a harbour town eating 944 t a day and landing 600 t of fish was told a farm
## could meet all 944 t. The catch, other farms, food buildings queued and the stock still to fill
## all count, and the savings are at the price food reaches this town.
func _farm_forecast() -> void:
	var sim: RefCounted = _colony()
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	var before: Dictionary = sim.Production.build_forecast(sim, region, "farm")
	var harbour: Dictionary = _finished(sim, s, "harbor")
	harbour.efficiency = 1.0
	var forecast: Dictionary = sim.Production.build_forecast(sim, region, "farm")
	var food: Dictionary = forecast.food
	var fish: float = float(sim.config.buildings.harbor.fish)
	check(
		is_equal_approx(float(food.caught), fish),
		"the harbour's catch counts: %.0f t a day" % sim.tonnes(fish)
	)
	check(
		float(forecast.usable.food) <= maxf(0.0, float(food.need) - fish) + 0.0001,
		(
			"a farm can use at most what the catch leaves: %.0f t of %.0f t needed"
			% [sim.tonnes(float(forecast.usable.food)), sim.tonnes(float(food.need))]
		)
	)
	check(
		(
			float(forecast.usable.food) < float(before.usable.food)
			or float(before.usable.food) <= fish
		),
		"less than before the harbour worked"
	)
	var base: float = float(sim.config.prices.food) * (1.0 + float(sim.config.economy.port_fee))
	var discount: float = float(Bay.rules(sim).sea_discount)
	check(
		is_equal_approx(float(food.import_price), base * (1.0 - discount)),
		"savings at the delivered price: ¥ %.2f, not ¥ %.2f" % [float(food.import_price), base]
	)
	check(
		is_equal_approx(
			float(forecast.import_savings_per_day),
			float(forecast.usable.food) * float(food.import_price)
		),
		"the farm's savings are its useful crop at that price"
	)
	# This bay's climate needs the greenhouse technology for a farm.
	if not sim._has("adaptation"):
		sim.state.research.completed.append("adaptation")
	check(sim.act("build", {"site": region, "kind": "farm"}) == "", "a farm is ordered")
	var again: Dictionary = sim.Production.build_forecast(sim, region, "farm")
	check(float(again.food.queued) > 0.0, "a farm already queued counts")
	check(
		float(again.usable.food) <= float(forecast.usable.food) + 0.0001,
		"and leaves the next one less to do"
	)


## The water lesson: ordering a pump is not fixing the shortage. The audited case: the filter came
## back by itself while the new pump still had 14 days to build, and the lesson credited the pump.
func _water_lesson() -> void:
	for pump_first: bool in [false, true]:
		var sim: RefCounted = Sim.new()
		sim.new_game(int(Tutorial.data().seed), "capital", 1)
		var home: int = int(Tutorial.data().start_site)
		sim.act("settle", {"region": home})
		sim.state.events_v2.next_draw = 99999
		sim._transfer("external", "public", 80000.0, "TEST funds", false)
		# The lesson begins once the opening's mines draw water.
		for kind: String in ["mine_ore", "mine_copper"]:
			_finished(sim, sim.settlement(home), kind)
		for _day: int in range(3):
			sim.tick()
		var context: Dictionary = Tutorial.new_context()
		context.home = home
		context.shortage_day = int(sim.state.day)
		context.water_built = Tutorial.water_count(sim, home)
		context.water_working = Tutorial.water_count(sim, home, true)
		sim.act("tutorial_shortage", {"site": home})
		var done: Dictionary = {"name": "shortage_cleared", "shortage": "water"}
		for _day: int in range(2):
			sim.tick()
			Tutorial.count_shortage(sim, context)
		check(sim.act("build", {"site": home, "kind": "water"}) == "", "a pump is ordered")
		var pump: Dictionary = sim.settlement(home).buildings.back()
		if pump_first:
			# Built before the fault passes: the new pump is what ends the shortage.
			pump.remaining = 1
		else:
			pump.remaining = maxi(int(pump.remaining), int(Tutorial.data().shortage.days) + 20)
		var credited_day: int = -1
		for _day: int in range(int(Tutorial.data().shortage.days) + 4):
			sim.tick()
			Tutorial.count_shortage(sim, context)
			if credited_day < 0 and Tutorial.check(sim, done, context):
				credited_day = int(sim.state.day)
		var note: String = Tutorial.note(sim, done, context)
		if pump_first:
			check(
				credited_day > 0 and bool(context.get("ended_by_pump", false)),
				"a pump at work when the shortage ends is credited (day %d)" % credited_day
			)
		else:
			check(credited_day < 0, "a pump still being built when the filter recovers is not")
			check(Tutorial.waited(sim, context), "the lesson says the filter recovered by itself")
			check(
				note.contains("还要") and note.contains("天建成"),
				"and that the pump ordered still has days to build: " + note
			)


## The radius slider: the seed's ground at any radius; every distance, travel day and route cost
## follows the radius; an orbital reading covers a fixed ground distance; saves keep the radius.
func _radius() -> void:
	var worlds: Dictionary = {}
	for radius: float in [1.0, 1.1, 0.7]:
		var sim: RefCounted = Sim.new()
		sim.new_game(3, "capital", 1, "normal", radius)
		worlds[radius] = sim
	var one: RefCounted = worlds[1.0]
	var more: RefCounted = worlds[1.1]
	check(is_equal_approx(float(one.geo.radius_km), 6371.0), "1.00 Earth radii is 6371 km")
	check(is_equal_approx(float(more.geo.radius_km), 7008.1), "1.10 is 7008 km")
	check(
		str(one.geo.hash) == str(more.geo.hash), "the same seed gives the same ground at any radius"
	)
	check(
		one.state.world.regions.size() == more.state.world.regions.size(),
		"and, within a band, the same recommended sites"
	)
	check(int(worlds[0.7].geo.size) == 0, "0.70 takes the small planet's site layout")
	# The same route on both: its km, days and cost scale with the radius.
	var a: int = int(one.geo.playability.pairs[0][0])
	var b: int = int(one.geo.playability.pairs[0][1])
	var near: Dictionary = one.Logistics.route_between(one, a, b, "engineered")
	var far: Dictionary = more.Logistics.route_between(more, a, b, "engineered")
	check(
		bool(near.reachable) and bool(far.reachable),
		"a route between the first pair on both planets"
	)
	if bool(near.reachable) and bool(far.reachable):
		var ratio: float = float(far.distance) / maxf(1.0, float(near.distance))
		check(
			absf(ratio - 1.1) < 0.02,
			"its length scales with the radius: %.0f km → %.0f km" % [near.distance, far.distance]
		)
		check(
			int(far.days) >= int(near.days),
			"it takes at least as long: %d → %d days" % [near.days, far.days]
		)
		check(
			float(far.cost) > float(near.cost),
			"and costs more: ¥ %.0f → ¥ %.0f" % [near.cost, far.cost]
		)
	var small: RefCounted = worlds[0.7]
	check(
		(
			SiteGenScript.signal_degrees(small.geo, small.progression_geo())
			> SiteGenScript.signal_degrees(one.geo, one.progression_geo())
		),
		"an orbital reading spans more of a smaller planet's arc (same km)"
	)
	var path: String = "user://radius_check.save"
	check(more.save_game(path) == "", "a 1.10 planet saves")
	var again: RefCounted = Sim.new()
	check(again.load_game(path) == "", "and loads")
	check(is_equal_approx(float(again.geo.radius_km), 7008.1), "with its radius")


## Stage three: any one operating route, not 600 people; 600 people is an achievement paid once.
func _stage_three() -> void:
	var sim: RefCounted = _colony()
	var goals: Dictionary = sim.contract_rules.stages[2].goals
	check(
		goals.has("operating_route") and not goals.has("population"),
		"stage three asks for a route, not 600 people"
	)
	var routes: Array = sim.Contract.OperatingRoutes.view(sim)
	check(routes.size() == 3, "three routes: %s" % ", ".join(routes.map(func(r): return r.name)))
	check(sim.Contract.OperatingRoutes.operating(sim) == 0.0, "none works in a new colony")
	# A month of food carried between towns, with the colony feeding itself, makes a food corridor.
	var rule: Dictionary = sim.contract_rules.routes.food_corridor
	for _day: int in range(30):
		sim.Contract.OperatingRoutes.add(sim, "food_moved", float(rule.food_moved) / 30.0 + 0.01)
		sim.Contract.OperatingRoutes.close_day(sim)
	sim.state.contract.food_window = []
	for _day: int in range(int(sim.contract_rules.windows.local_food)):
		sim.state.contract.food_window.append([10.0, 10.0])
	var corridor: Dictionary = {}
	for route: Dictionary in sim.Contract.OperatingRoutes.view(sim):
		if str(route.id) == "food_corridor":
			corridor = route
	check(bool(corridor.get("ok", false)), "a month's food corridor works")
	check(
		sim.Contract.goal_value(sim, "operating_route") == 1.0, "and meets the stage's route goal"
	)
	var before: float = float(sim.state.cash)
	sim.settlement(int(sim.state.settlements[0].region)).population = 600
	sim.Contract.OperatingRoutes.check_achievements(sim)
	var paid: float = float(sim.state.cash) - before
	sim.Contract.OperatingRoutes.check_achievements(sim)
	check(
		(
			sim.state.contract.achievements.has("population_600")
			and is_equal_approx(paid, float(sim.contract_rules.achievements[0].reward_cash))
			and is_equal_approx(float(sim.state.cash) - before, paid)
		),
		"600 people is an achievement, paid once: ¥ %.0f" % paid
	)


## The tutorial opens on a bay and its first decision: a mine or the small harbour completes the
## step, and the first recorded consignment of either kind the next one; inland words exist.
func _tutorial_bay() -> void:
	var rules: Dictionary = Tutorial.data()
	var sim: RefCounted = Sim.new()
	sim.new_game(int(rules.seed), str(rules.opening), int(rules.size), str(rules.difficulty))
	var home: int = int(rules.start_site)
	check(bool(sim.state.world.regions[home].get("coast", false)), "the tutorial's start is a bay")
	check(sim.act("settle", {"site": home}) == "", "landing there works")
	sim._transfer("external", "public", 20000.0, "TEST funds", false)
	var context: Dictionary = Tutorial.new_context()
	var choice: Dictionary = {"name": "first_choice"}
	var shipment: Dictionary = {"name": "first_shipment"}
	check(not Tutorial.check(sim, choice, context), "the decision waits for an order")
	check(sim.act("build", {"site": home, "kind": "harbor"}) == "", "the harbour first")
	check(Tutorial.check(sim, choice, context), "is a choice the lesson accepts")
	check(not Tutorial.check(sim, shipment, context), "no consignment yet")
	Consignments.imported(sim, sim.settlement(home), "food", 1.0, 3.0)
	check(not Tutorial.check(sim, shipment, context), "nor while the harbour is still being built")
	var steps: Dictionary = {}
	for step: Dictionary in rules.steps:
		steps[str(step.id)] = step
	check(
		steps.income.has("text_inland") and steps.export.has("text_inland"),
		"the opening has words for an inland landing"
	)
	check(
		str(steps.income.text).contains("码头") and str(steps.income.text).contains("矿"),
		"and explains both ways"
	)
