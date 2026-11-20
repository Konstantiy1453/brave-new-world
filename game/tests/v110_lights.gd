extends SceneTree
## 1.10 nightscape from the game's state (plan B, light_field.gd). The brief's decisive test: two
## colonies with the same people and the same number of buildings, the new homes on opposite sides
## of the camp; the lit neighbourhood moves with them in the light list, in the painted night map
## and in the district. Also: homes light up in the order they were built as people arrive, a site
## under construction shows one lamp, a road shows lights only where it leaves town, and the same
## state always gives the same lights. A coastal town's harbour: the district stands its building
## site, then its quay; a ship light sails on the globe and the flat map on the district ship's own
## line, berthing where it berths; the offshore signal is drawn where the district floats its buoy.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const LightField = preload("res://world/light_field.gd")
const NightLights = preload("res://world/night_lights.gd")
const Rules = preload("res://simulation/rules.gd")
const Geo = preload("res://world/world_gen.gd")
const SEED: int = 260129
const HOMES: int = 3

var checks: int = 0
var failures: Array[String] = []
var buildings: Dictionary = {}


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	buildings = Rules.read("economy").buildings
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1, "normal")
	var site: int = int(sim.geo.playability.pairs[0][0])
	check(sim.act("settle", {"site": site}) == "", "the colony lands")
	for _day: int in range(2):
		sim.tick()
	var map: Node3D = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.sync_state(sim.state)
	var camps: Dictionary = map.landing_camps()
	var west: Dictionary = _with_homes(sim, site, -1.0)
	var east: Dictionary = _with_homes(sim, site, 1.0)
	_same_size(west, east)
	var west_lights: Array = LightField.lights(west, sim.geo, buildings, camps)
	var east_lights: Array = LightField.lights(east, sim.geo, buildings, camps)
	var west_homes: Vector2 = LightField.centroid(_warm(west_lights))
	var east_homes: Vector2 = LightField.centroid(_warm(east_lights))
	check(
		east_homes.y - west_homes.y > 1.0,
		(
			"the lit homes move with the housing: west %.2f, east %.2f degrees of longitude"
			% [west_homes.y, east_homes.y]
		)
	)
	var west_map: Vector2 = _painted_centroid(west_lights, sim.geo.regions[site])
	var east_map: Vector2 = _painted_centroid(east_lights, sim.geo.regions[site])
	check(
		east_map.x - west_map.x > 8.0,
		"and in the painted night map: texel x %.1f against %.1f" % [west_map.x, east_map.x]
	)
	await _district(map, site, west, east)
	_camp(sim, site, camps)
	_filling(sim, site, camps)
	_building_site(sim, site, camps)
	_roads(sim, site)
	_anchored(sim, camps)
	_overlay(map)
	root.remove_child(map)
	map.free()
	_harbour()
	print("V110_LIGHTS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


## A copy of the colony with HOMES homes finished on the general plots furthest to one side, and
## people enough to fill them.
func _with_homes(sim: RefCounted, site: int, side: float) -> Dictionary:
	var shown: Dictionary = sim.state.duplicate(true)
	var s: Dictionary = shown.settlements[0]
	var plots: Array = sim.geo.regions[site].plots
	var taken: Dictionary = {}
	for b: Dictionary in s.buildings:
		taken[int(b.plot)] = true
	var free: Array = []
	for index: int in range(plots.size()):
		if not taken.has(index) and str(plots[index].kind) == "general":
			free.append(index)
	free.sort_custom(
		func(a: int, b: int) -> bool: return side * float(plots[a].x) > side * float(plots[b].x)
	)
	var uid: int = int(shown.next_building_uid)
	for index: int in free.slice(0, HOMES):
		var home: Dictionary = sim.Production.building_record("habitat", 0)
		home.uid = uid
		uid += 1
		home.plot = index
		home.active = true
		s.buildings.append(home)
	shown.next_building_uid = uid
	s.population = int(s.population) + HOMES * int(buildings.habitat.housing)
	return shown


func _same_size(west: Dictionary, east: Dictionary) -> void:
	check(
		(
			west.settlements[0].buildings.size() == east.settlements[0].buildings.size()
			and int(west.settlements[0].population) == int(east.settlements[0].population)
		),
		"both colonies have the same buildings and people"
	)


func _warm(found: Array) -> Array:
	return found.filter(func(light: Dictionary) -> bool: return float(light.warm) > 0.0)


## The warm light's mean texel in the painted map, in a window round the town.
func _painted_centroid(found: Array, reg: Dictionary) -> Vector2:
	var image: Image = NightLights.paint(found)
	var centre: Vector2 = NightLights.texel(float(reg.lat), float(reg.lon))
	var reach: int = 160
	var total: float = 0.0
	var sum := Vector2.ZERO
	for y: int in range(int(centre.y) - reach, int(centre.y) + reach):
		for x: int in range(int(centre.x) - reach, int(centre.x) + reach):
			var px: int = posmod(x, NightLights.WIDTH)
			var py: int = clampi(y, 0, NightLights.HEIGHT - 1)
			var warm: float = image.get_pixel(px, py).r
			if warm > 0.0:
				sum += Vector2(x, y) * warm
				total += warm
	return sum / total if total > 0.0 else Vector2.ZERO


## In the district the same homes stand on the same side, and are drawn lit.
func _district(map: Node3D, site: int, west: Dictionary, east: Dictionary) -> void:
	var sides: Array[float] = []
	for shown: Dictionary in [west, east]:
		map.sync_state(shown)
		map.show_region(site)
		while map.region_busy:
			await process_frame
		map.sync_state(shown)
		var xs: float = 0.0
		var count: int = 0
		for model: Node in map.buildings_root.get_children():
			if str(model.get_meta("building_kind", "")) == "habitat":
				xs += (model as Node3D).position.x
				count += 1
		sides.append(xs / maxf(1.0, float(count)))
		check(count == HOMES, "the district draws the %d homes (%d)" % [HOMES, count])
		_newcomers_bus(map, site, shown)
		map.show_planet()
	check(
		sides[1] - sides[0] > 4.0,
		"on the same sides of town: x %.1f against %.1f" % [sides[0], sides[1]]
	)


## After people arrive, a bus runs from the landing pads to the newest home people live in; with
## no arrivals that week there is none.
func _newcomers_bus(map: Node3D, site: int, shown: Dictionary) -> void:
	var run: Dictionary = map._arrival_run(map.traffic.stops, site)
	if not shown.get("stats", {}).get("today", {}).get("arrivals", {}).has(str(site)):
		var quiet: bool = run.is_empty() or int(run.get("people", 0)) > 0
		check(quiet, "no newcomers' bus without arrivals (or arrivals this week: %s)" % str(run))
	var arrived: Dictionary = shown.duplicate(true)
	if not arrived.has("stats"):
		arrived.stats = {"today": {"arrivals": {}}, "days": []}
	arrived.stats.today.arrivals[str(site)] = 6
	map.state = arrived
	var bus: Dictionary = map._arrival_run(map.traffic.stops, site)
	var newest: int = -1
	var shares: Dictionary = LightField.housing_shares(arrived.settlements[0], buildings)
	for b: Dictionary in arrived.settlements[0].buildings:
		if float(shares.get(int(b.get("uid", 0)), 0.0)) > 0.0:
			newest = maxi(newest, int(b.uid))
	check(
		(
			not bus.is_empty()
			and int(bus.home) == newest
			and str(map.traffic.stops[int(bus.from)].kind) == "base"
		),
		"six newcomers: the bus runs from the pads to the newest lived-in home (uid %d)" % newest
	)
	map.state = shown


## The landing camp's first lights stand where the district stands its pods.
func _camp(sim: RefCounted, site: int, camps: Dictionary) -> void:
	var s: Dictionary = sim.state.settlements[0]
	check(int(s.base_housing) > 0, "the landing brings its pods (%d beds)" % int(s.base_housing))
	var found: Array = LightField.settlement_lights(s, sim.geo, buildings, camps[site])
	var reg: Dictionary = sim.geo.regions[site]
	var pods: Vector2 = camps[site]
	var near: int = 0
	for light: Dictionary in _warm(found):
		var local := Vector2(
			(float(light.lon) - float(reg.get("canonical_lon", reg.lon))) * 4.0,
			(float(reg.get("canonical_lat", reg.lat)) - float(light.lat)) * 4.0
		)
		if local.distance_to(pods) <= LightField.SPREAD + 0.01:
			near += 1
	check(
		near > 0 and near == _warm(found).size(), "the camp's windows are at the pods (%d)" % near
	)


## Homes light up in the order they were built: half the people, the newest home stays dark.
func _filling(sim: RefCounted, site: int, camps: Dictionary) -> void:
	var shown: Dictionary = _with_homes(sim, site, -1.0)
	var s: Dictionary = shown.settlements[0]
	var full: Dictionary = LightField.housing_shares(s, buildings)
	s.population = int(s.base_housing) + int(buildings.habitat.housing)
	var part: Dictionary = LightField.housing_shares(s, buildings)
	var uids: Array = []
	for b: Dictionary in s.buildings:
		if str(b.kind) == "habitat":
			uids.append(int(b.uid))
	check(
		float(full[uids.back()]) == 1.0 and float(part[uids.front()]) == 1.0,
		"with fewer people the oldest home is still full"
	)
	check(float(part[uids.back()]) == 0.0, "and the newest home is dark")
	var lit: int = _warm(LightField.settlement_lights(s, sim.geo, buildings, camps[site])).size()
	s.population = int(s.base_housing) + HOMES * int(buildings.habitat.housing)
	var more: int = _warm(LightField.settlement_lights(s, sim.geo, buildings, camps[site])).size()
	check(more > lit, "people moving in light more windows (%d -> %d)" % [lit, more])
	# The audited run: 60 beds in the landing camp, 66 people, the first home just finished. The
	# six in it light a window at the home's own plot, and the night map changes.
	s.population = int(s.base_housing) + 6
	var first_home: Dictionary = {}
	for b: Dictionary in s.buildings:
		if str(b.kind) == "habitat" and first_home.is_empty():
			first_home = b
	var shares: Dictionary = LightField.housing_shares(s, buildings)
	check(
		LightField.home_lit(first_home, buildings, shares),
		"six people in the first home light it (share %.2f)" % float(shares[int(first_home.uid)])
	)
	var camp_only: Dictionary = shown.duplicate(true)
	camp_only.settlements[0].population = int(s.base_housing)
	check(
		LightField.signature(shown, buildings) != LightField.signature(camp_only, buildings),
		"so the night map is repainted when they move in"
	)


## A building site shows one lamp; finished and running, its work lights.
func _building_site(sim: RefCounted, site: int, camps: Dictionary) -> void:
	var shown: Dictionary = sim.state.duplicate(true)
	var s: Dictionary = shown.settlements[0]
	var mine: Dictionary = sim.Production.building_record("mine_ore", 10)
	mine.uid = int(shown.next_building_uid)
	mine.plot = -1
	s.buildings.append(mine)
	var before: int = LightField.settlement_lights(s, sim.geo, buildings, camps[site]).size()
	mine.remaining = 0
	mine.active = true
	var after: int = LightField.settlement_lights(s, sim.geo, buildings, camps[site]).size()
	check(
		after - before == int(LightField.WORK_LIGHTS.mine[1]) - 1,
		"a site lamp, then the mine's work lights (%d -> %d)" % [before, after]
	)


## A finished road lights only where it leaves each town: no lamp string along it.
func _roads(sim: RefCounted, site: int) -> void:
	var shown: Dictionary = sim.state.duplicate(true)
	var long_road: Array = []
	for step: int in range(40):
		long_road.append([10.0 + step * 0.5, 20.0])
	shown.roads = [
		{
			"id": 1,
			"a": site,
			"b": (site + 1) % sim.geo.regions.size(),
			"variant": "valley",
			"ready_day": 0,
			"blocked_until": -1,
			"coordinates": long_road
		}
	]
	shown.day = 10
	var found: Array = LightField.road_lights(shown, sim.geo)
	check(
		found.size() == 2 * LightField.ENTRANCE_DEGREES.size(),
		"a 20-degree road shows %d lights, at its two ends" % found.size()
	)


## The same state gives the same lights, and a day that changes nothing changes none.
func _anchored(sim: RefCounted, camps: Dictionary) -> void:
	var first: Array = LightField.lights(sim.state, sim.geo, buildings, camps)
	var again: Array = LightField.lights(sim.state.duplicate(true), sim.geo, buildings, camps)
	check(JSON.stringify(first) == JSON.stringify(again), "the same state, the same lights")
	var copy: Dictionary = sim.state.duplicate(true)
	copy.day = int(copy.day) + 1
	check(
		JSON.stringify(LightField.lights(copy, sim.geo, buildings, camps)) == JSON.stringify(first),
		"lights stay where they are from one day to the next"
	)


## The route diagram is an overlay: off, the lines go and the moving cargo stays.
func _overlay(map: Node3D) -> void:
	map.set_route_overlay(false)
	check(
		not map.transport_root.visible and not map.flat_transport_root.visible,
		"the transport diagram can be switched off"
	)
	check(
		map.mover_root.visible and map.flat_mover_root.visible,
		"while the cargo on the routes still moves"
	)
	map.set_route_overlay(true)
	check(map.transport_root.visible, "and back on")


## A colony on the first coastal site with a quay spot builds its harbour; the views follow.
func _harbour() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1, "normal")
	var map: Node3D = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	var coast: int = -1
	for reg: Dictionary in sim.geo.regions:
		if bool(reg.get("coast", false)):
			map._fit_field()
			if not map.harbor_spot(int(reg.id)).is_empty():
				coast = int(reg.id)
				break
	check(coast >= 0, "a coastal site with a quay spot: %d" % coast)
	if coast >= 0:
		_harbour_views(sim, map, coast)
	root.remove_child(map)
	map.free()


func _harbour_views(sim: RefCounted, map: Node3D, coast: int) -> void:
	sim.act("settle", {"site": coast})
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	for good: String in ["materials", "parts"]:
		sim._produce(sim.settlement(coast), good, 200.0, "TEST stock")
	check(sim.act("build", {"site": coast, "kind": "harbor"}) == "", "a harbour is ordered")
	sim.tick()
	map.sync_state(sim.state)
	var town: Dictionary = sim.settlement(coast)
	check(map._harbor_state(town) == "site", "the district stands its building site")
	check(map.globe_ships.is_empty(), "no ship before the quay works")
	var harbor: Dictionary = town.buildings.back()
	for _day: int in range(int(harbor.remaining) + 2):
		sim.tick()
	map.sync_state(sim.state)
	check(map._harbor_state(town) == "quay", "then its quay")
	if town.get("sea_cargo", {}).is_empty():
		check(map.globe_ships.is_empty(), "no ship while the harbour has carried nothing")
	# The town runs short of food: the first cargo comes by sea, and with it the ship.
	sim._consume(town, "food", float(town.stock.food))
	sim.tick()
	map.sync_state(sim.state)
	check(
		map.globe_ships.size() == 1 and map.flat_ships.size() == 1,
		(
			"a ship light on the globe and on the flat map, with the cargo: %s"
			% str(town.get("sea_cargo", {}))
		)
	)
	if map.globe_ships.is_empty():
		return
	var line: Array = map.ship_line(coast)
	var berth: Vector3 = Geo.unit_point(line[1].x, line[1].y) * 3.05
	var ship: Dictionary = map.globe_ships[0]
	check(Vector3(ship.to).distance_to(berth) < 0.0001, "berthing where the district's ship berths")
	var worst: float = 0.0
	var at_berth: bool = false
	var away: bool = false
	for step: int in range(int(map.SHIP_DAYS) * 24):
		map.state.day = int(sim.state.day) + int(step / 24.0)
		map.place_ships(map.globe_ships, float(step % 24) / 24.0)
		var node: Node3D = ship.node
		if not node.visible:
			away = true
			continue
		var from: Vector3 = ship.from
		var to: Vector3 = ship.to
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(node.position, from, to)
		worst = maxf(worst, closest.distance_to(node.position))
		at_berth = at_berth or node.position.distance_to(to) < 0.0001
	map.state.day = int(sim.state.day)
	check(worst < 0.0001, "on its line in every frame (%.6f off at most)" % worst)
	check(at_berth and away, "it berths, and it sails away beyond the horizon")
	var reading: Dictionary = map.signal_reading(coast)
	check(not reading.is_empty(), "the town has an offshore signal still to read")
	var at: Vector2 = map.signal_point(coast)
	var mark: Vector3 = Geo.unit_point(at.x, at.y) * 3.05
	var drawn: bool = false
	for child: Node in map.marker_root.get_children():
		if child.has_meta("point") and Vector3(child.get_meta("point")).distance_to(mark) < 0.0001:
			drawn = true
	check(drawn, "and it is drawn on the globe where the district floats its buoy")
