extends SceneTree
## 1.11 phase F: weather that matters.
## - the same seed gives the same weather by day; another seed other weather; systems are born in
##   their zones (warm ocean, dry interior, cold land, river basins, coasts);
## - a system reaching a town opens its story; a system on its way raises a warning; the weather's
##   stories leave the random draw while weather is on;
## - warning days: base, doubled under a weather station, more with the forecasting technology;
## - preparation is paid and cuts the town's losses; the disaster technology cuts them too, and
##   only the weather's; the losses are written on the strike and the audit holds them to the ledger;
## - force majeure: accepted with a warning or a station (deadline moved, the report's miss waived),
##   refused without evidence, late, or twice;
## - saves keep the weather; the audit holds; the clouds follow the state's systems; the page.

const Watchdog = preload("res://tests/support/watchdog.gd")
const LegacyWorld = preload("res://tests/support/legacy_world.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Weather = preload("res://simulation/weather.gd")
const Research = preload("res://simulation/research.gd")
const AnnualReport = preload("res://simulation/annual_report.gd")
const Contract = preload("res://simulation/contract.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Clock = preload("res://world/visual_clock.gd")
const WeatherPage = preload("res://ui/weather_page.gd")
const SEED: int = 20261029
## 天气预报 and 防灾工程, merged into their tier's technology in 1.11 H.
var forecasting: String = Research.current_id("weather_forecasting")
var engineering: String = Research.current_id("disaster_engineering")

var checks: int = 0
var failures: Array[String] = []


class FakeGame:
	extends Node
	var sim: RefCounted

	func act(action: String, args: Dictionary) -> String:
		return sim.act(action, args)


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_deterministic()
	_zones()
	_strike_and_warning()
	_warning_days()
	_prepare()
	_losses()
	_force_majeure()
	_draw()
	_saved()
	_clouds()
	_page()
	print("V111_WEATHER_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	LegacyWorld.new_game(sim, seed_value, "capital", 1)
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) == "":
			sim.act("settle", {"region": int(reg.id)})
			break
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	return sim


## A colony kept alive and quiet while days pass.
func _tick(sim: RefCounted) -> void:
	for town: Dictionary in sim.state.settlements:
		sim._produce(town, "food", maxf(0.0, 400.0 - float(town.stock.food)), "TEST food")
	sim.state.company.distrust = 0.0
	sim.state.company.stage = "normal"
	sim.tick()


func _systems_key(sim: RefCounted) -> String:
	var parts: PackedStringArray = []
	for system: Dictionary in sim.state.weather.systems:
		parts.append(
			"%d %s %.3f %.3f" % [int(system.id), system.kind, float(system.lat), float(system.lon)]
		)
	return ",".join(parts)


func _deterministic() -> void:
	var one: RefCounted = _colony()
	var two: RefCounted = _colony()
	var other: RefCounted = _colony(SEED + 7)
	for _day: int in range(160):
		_tick(one)
		_tick(two)
		_tick(other)
	check(
		not one.state.weather.systems.is_empty(),
		"weather systems form: %d now" % one.state.weather.systems.size()
	)
	check(_systems_key(one) == _systems_key(two), "the same seed gives the same weather by day")
	check(_systems_key(one) != _systems_key(other), "another seed other weather")


func _zones() -> void:
	var sim: RefCounted = _colony()
	var born: Dictionary = {}
	var wrong: Array = []
	var seen: Dictionary = {}
	for _day: int in range(300):
		_tick(sim)
		for system: Dictionary in sim.state.weather.systems:
			if seen.has(int(system.id)):
				continue
			seen[int(system.id)] = true
			born[str(system.kind)] = int(born.get(str(system.kind), 0)) + 1
			var zone: Dictionary = Weather.rules().kinds[system.kind].zone
			var origin: Array = system.born
			var cell: Dictionary = sim.geo.grid[SiteGen.cell_at(
				sim.geo, float(origin[0]), float(origin[1])
			)]
			if not Weather._fits(cell, zone):
				wrong.append("%s %d" % [system.kind, int(system.id)])
	check(born.size() >= 4, "most kinds form within a year: %s" % str(born))
	check(wrong.is_empty(), "each where its zone is: %s" % str(wrong))


## A system of `kind` sitting on the town, or `days` away heading straight for it.
func _aimed(sim: RefCounted, kind: String, days: float) -> Dictionary:
	var town: Dictionary = sim.state.settlements[0]
	var here: Vector2 = Weather.town_point(sim, town)
	var speed: float = 2.0
	var system: Dictionary = {
		"id": int(sim.state.weather.next_id),
		"kind": kind,
		"lat": here.x - speed * days,
		"lon": here.y,
		"heading": 0.0,
		"speed": speed,
		"radius": 1.0,
		"age": 0,
		"life": 30,
		"warned": {},
		"struck": {},
		"prepared": {},
	}
	sim.state.weather.next_id = int(sim.state.weather.next_id) + 1
	sim.state.weather.systems.append(system)
	return system


func _strike_and_warning() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	var system: Dictionary = _aimed(sim, "heavy_rain", 3.0)
	_tick(sim)
	check(system.warned.has(str(town.region)), "a system on its way raises a warning")
	var logged: bool = false
	for line: Variant in sim.state.log:
		logged = logged or str(line).contains("气象预警")
	check(logged, "logged")
	for _day: int in range(4):
		_tick(sim)
	check(system.struck.has(str(town.region)), "and when it arrives it strikes the town")
	var opened: bool = false
	for inst: Dictionary in sim.state.events_v2.instances:
		opened = opened or str(inst.definition_id) == "flood_season"
	check(opened, "opening its story (heavy rain, flood_season)")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _warning_days() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	var base: int = int(Weather.rules().warning_days)
	check(Weather.warning_days(sim, town) == base, "%d days of warning by default" % base)
	var station: Dictionary = sim._building("weather_station", 0)
	station.remaining = 0
	town.buildings.append(station)
	check(
		Weather.covered(sim, town) and Weather.warning_days(sim, town) == base * 2,
		"doubled under a weather station"
	)
	sim.state.research.completed.append(forecasting)
	var more: int = int(sim.config.techs[forecasting].effects.weather_warning)
	check(
		Weather.warning_days(sim, town) == base * 2 + more,
		"and %d more with weather forecasting" % more
	)
	var refusal: String = sim.Production.build_refusal(sim, int(town.region), "weather_station")
	check(refusal == "", "a weather station can be built from the start: " + refusal)


func _prepare() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	var system: Dictionary = _aimed(sim, "heavy_rain", 3.0)
	_tick(sim)
	var cost: float = Weather.prepare_cost(sim)
	var cash: float = float(sim.state.cash)
	check(
		sim.act("weather_prepare", {"system": int(system.id), "region": int(town.region)}) == "",
		"a warned town can be prepared"
	)
	check(is_equal_approx(cash - float(sim.state.cash), cost), "for ¥%.0f" % cost)
	check(
		sim.act("weather_prepare", {"system": int(system.id), "region": int(town.region)}) != "",
		"once"
	)
	for _day: int in range(4):
		_tick(sim)
	check(
		is_equal_approx(Weather.kept(sim, town), float(Weather.rules().prepared_losses)),
		(
			"a prepared town keeps %.0f%% of what the disaster takes"
			% (Weather.kept(sim, town) * 100.0)
		)
	)
	sim.state.research.completed.append(engineering)
	sim.tech_effects_count = -1
	check(
		Weather.kept(sim, town) < float(Weather.rules().prepared_losses),
		"and less with disaster engineering"
	)


func _losses() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	sim.state.research.completed.append(engineering)
	sim.tech_effects_count = -1
	check(is_equal_approx(Weather.kept(sim, town), 1.0), "away from the weather, losses stay whole")
	_aimed(sim, "heavy_rain", 1.0)
	_tick(sim)
	var strike: Dictionary = Weather.recent_strike(sim, town)
	check(not strike.is_empty(), "a strike is on the town's record")
	var share: float = 1.0 + float(sim.config.techs[engineering].effects.weather_losses)
	check(
		is_equal_approx(Weather.kept(sim, town), share),
		"after it disaster engineering cuts the losses to %.0f%%" % (share * 100.0)
	)
	sim._produce(town, "food", 500.0, "TEST food")
	var sunk: float = float(sim.state.resource_sinks.food)
	Weather.take_losses(sim, town, {"food": 100.0})
	var lost: float = float(sim.state.resource_sinks.food) - sunk
	check(
		(
			is_equal_approx(lost, 100.0 * Weather.kept_losses(sim, town))
			and is_equal_approx(float(strike.losses.food), lost)
			and is_equal_approx(float(sim.state.weather.lost.food), lost)
		),
		"the loss (%.1f food) goes through the ledger, on the strike and in the total" % lost
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
	sim.state.weather.lost.food = float(sim.state.resource_sinks.food) + 50.0
	check(
		"weather losses outside the ledger food" in sim.audit(),
		"the audit catches weather losses the ledger never took"
	)
	sim.state.weather.lost.food = lost
	var row: Dictionary = {
		"system": int(strike.system),
		"region": int(town.region),
		"day": int(sim.state.day),
		"accepted": false,
		"days": 0,
		"line": "",
	}
	sim.state.weather.claims.append(row)
	sim.state.weather.claims.append(row.duplicate())
	check("force majeure claimed twice" in sim.audit(), "and a disaster claimed twice")


func _force_majeure() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	_aimed(sim, "heavy_rain", 3.0)
	for _day: int in range(5):
		_tick(sim)
	var stage: int = int(sim.state.contract.stage)
	var deadline: int = Contract.deadline(sim, stage)
	check(
		sim.act("force_majeure", {"region": int(town.region)}) == "",
		"a warned disaster is force majeure"
	)
	var days: int = int(Weather.rules().kinds.heavy_rain.disaster_days)
	check(
		Contract.deadline(sim, stage) == deadline + days, "the stage deadline moves %d days" % days
	)
	check("farming" in sim.state.annual.waivers, "and this year's farming miss is waived")
	check(
		sim.act("force_majeure", {"region": int(town.region)}) != "", "a disaster is claimed once"
	)
	var a: Dictionary = sim.state.annual
	a.next_ship = int(sim.state.day) + 1
	while a.pending.is_empty():
		_tick(sim)
	a.pending.actual.farming = 0.0
	a.pending.targets.farming = 100.0
	# Mining met, so the distrust below can only come from the farming line.
	a.pending.actual.mining = float(a.pending.targets.mining)
	sim.state.company.distrust = 10.0
	sim.act("annual_report", {})
	check(
		(
			str(a.history.back().outcomes.farming) == "waived"
			and float(sim.state.company.distrust) <= 10.0
		),
		"the report's farming line is not held against the colony"
	)
	var blind: RefCounted = _colony()
	var unseen: Dictionary = _aimed(blind, "heavy_rain", 1.0)
	_tick(blind)
	var home: String = str(blind.state.settlements[0].region)
	check(
		(
			unseen.struck.has(home)
			and not unseen.warned.has(home)
			and blind.act("force_majeure", {"region": int(home)}).contains("驳回")
		),
		"a disaster nobody warned of and no station recorded is refused"
	)
	var late: RefCounted = _colony()
	_aimed(late, "heavy_rain", 3.0)
	for _day: int in range(5 + int(Weather.rules().claim_days) + 1):
		_tick(late)
	check(
		late.act("force_majeure", {"region": int(late.state.settlements[0].region)}).contains("日内"),
		"and so is a late claim"
	)


func _draw() -> void:
	var sim: RefCounted = _colony()
	check(
		is_zero_approx(AnnualReport.story_weight(sim, "flood_season")),
		"the weather's stories leave the draw"
	)
	check(is_equal_approx(AnnualReport.story_weight(sim, "price_window"), 1.0), "and no other")
	Rules.read("progression").features.weather = false
	check(
		is_equal_approx(AnnualReport.story_weight(sim, "flood_season"), 1.0),
		"with the weather off they are drawn again"
	)
	Rules.read("progression").features.weather = true
	var grid: Dictionary = sim.geo
	sim.geo = {"seed": grid.seed}
	check(
		(
			not Weather.active(sim)
			and is_equal_approx(AnnualReport.story_weight(sim, "flood_season"), 1.0)
		),
		"and in a world from before the climate grid (1.6, 1.7 saves)"
	)
	var count: int = sim.state.weather.systems.size()
	Weather.daily(sim)
	check(sim.state.weather.systems.size() == count, "where no system is born")
	sim.geo = grid


func _saved() -> void:
	var sim: RefCounted = _colony()
	_aimed(sim, "cyclone", 2.0)
	for _day: int in range(40):
		_tick(sim)
	var before: String = _systems_key(sim)
	check(sim.save_game("user://v111_weather.save") == "", "a game with weather saves")
	var again: RefCounted = Sim.new()
	check(again.load_game("user://v111_weather.save") == "", "and loads")
	check(
		(
			_systems_key(again) == before
			and again.state.weather.strikes.size() == sim.state.weather.strikes.size()
		),
		"with its systems and strikes"
	)
	check(again.audit().is_empty(), "the audit holds: %s" % str(again.audit()))


func _clouds() -> void:
	var sim: RefCounted = _colony()
	var system: Dictionary = _aimed(sim, "cyclone", 2.0)
	var clock: RefCounted = Clock.new()
	clock.follow([system], true)
	var drawn: Array[Vector4] = clock.storm_vectors()
	var lat: float = deg_to_rad(float(system.lat))
	var lon: float = deg_to_rad(float(system.lon))
	var centre := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	check(
		Vector3(drawn[0].x, drawn[0].y, drawn[0].z).distance_to(centre) < 0.02,
		"the clouds draw the state's systems"
	)
	clock.follow([], false)
	check(
		clock.storm_vectors().size() == Clock.STORM_COUNT, "and their own while the weather is off"
	)


func _page() -> void:
	var sim: RefCounted = _colony()
	var system: Dictionary = _aimed(sim, "heavy_rain", 3.0)
	_tick(sim)
	var fake := FakeGame.new()
	fake.sim = sim
	root.add_child(fake)
	var box := VBoxContainer.new()
	fake.add_child(box)
	WeatherPage.page(fake, box)
	var button: Node = box.find_child(
		"Prepare_%d_%d" % [int(system.id), int(sim.state.settlements[0].region)], true, false
	)
	check(button != null, "the weather page offers preparation for a warned town")
	fake.queue_free()
