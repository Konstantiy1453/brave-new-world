extends SceneTree
## Needs a real window. Plays a colony with the balanced bot, then captures the moving map at
## chosen moments: the globe by day and by night, the flat map, and a region at noon and at night.
## Options: --seed=260129 --days=900 --out=res://../evidence/v17/art/dynamics --size=1600x900
## --terraform=3 draws the map as if that many terraforming stages were finished (render-only);
## --district=5 adds a finished capital district at that level to the home town (render-only);
## --shots=works frames the terraforming programme and the district in the home region.
## --shuttle adds a render-only shuttle line from the home town to the second settlement;
## --shots=shuttle then frames its pad with the craft parked, and the craft in flight.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Map = preload("res://world/map_view.gd")
const Geo = preload("res://world/world_gen.gd")

var options: Dictionary = {
	"seed": "260129",
	"days": "900",
	"out": "res://../evidence/v17/art/dynamics",
	"size": "1600x900",
	"weather": "140",
	"shots": "all",
}
var map: Node3D
var folder: String = ""
var report: Dictionary = {"shots": [], "failures": []}


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	folder = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	var sim: RefCounted = Sim.new()
	sim.new_game(int(options.seed), "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(options.seed))
	for _day: int in range(int(options.days)):
		bot.on_day()
		sim.tick()
		if sim.state.status == "failed":
			break
	print("CAPTURE_DYNAMICS day=%d settlements=%d" % [sim.state.day, sim.state.settlements.size()])
	map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.sync_state(sim.state)
	var stages: int = int(str(options.get("terraform", "0")))
	var shown: Dictionary = sim.state.duplicate(true)
	if str(options.get("shuttle", "")) == "true":
		var line: Dictionary = _shuttle_line(sim)
		if not line.is_empty():
			line.id = shown.roads.size()
			line.ready_day = 0
			line.blocked_until = 0
			line.sent_today = 0.0
			shown.roads.append(line)
			map.sync_state(shown)
		print("CAPTURE_DYNAMICS shuttle line=%s" % str(not line.is_empty()))
	var levels: int = int(str(options.get("district", "0")))
	for work: Array in [["terraforming", stages], ["capital_district", levels]]:
		if int(work[1]) <= 0:
			continue
		shown.settlements[0].buildings.append(
			{
				"kind": str(work[0]),
				"remaining": 0,
				"level": int(work[1]),
				"enabled": true,
				"active": true,
				"plot": -1
			}
		)
		map.sync_state(shown)
	map.set_visual_options(false, true, true)
	map.sky.weather_time = float(options.weather)
	while map.atlas_refining:
		await process_frame
	var home: Dictionary = sim.geo.regions[int(sim.state.settlements[0].region)]
	var wanted: String = str(options.shots)
	if wanted == "all" or wanted.contains("day"):
		await _globe(home, 0.55, 10.3, "globe_day")
	if wanted == "all" or wanted.contains("dusk"):
		await _globe(home, 1.45, 10.3, "globe_dusk")
	if wanted == "all" or wanted.contains("night"):
		await _globe(home, PI, 8.6, "globe_night")
	if wanted == "all" or wanted.contains("close"):
		await _globe(home, 0.25, 7.0, "globe_close")
	if wanted == "all" or wanted.contains("flat"):
		_set_local_time(home, 1.2)
		map.show_flat()
		await _shot("flat")
	if wanted == "all" or wanted.contains("region"):
		map.show_region(int(home.id))
		while map.region_busy:
			await process_frame
		_set_local_time(home, 0.35)
		await _shot("region_day")
		_set_local_time(home, 1.42)
		await _shot("region_dusk")
		_set_local_time(home, PI)
		await _shot("region_night")
	if wanted.contains("pad"):
		map.show_region(int(home.id))
		while map.region_busy:
			await process_frame
		_set_local_time(home, 0.4)
		map.local_distance = 52.0
		map.smooth_distance = 52.0
		for view: int in range(4):
			map.local_yaw = 0.68 + view * PI * 0.5
			map.smooth_yaw = map.local_yaw
			await _shot("region_side_%d" % view)
	if wanted.contains("shuttle"):
		await _shuttle_shots(home)
	if wanted.contains("works"):
		await _works_shots(home)
	if wanted == "all" or wanted.contains("showcase"):
		await _showcase(sim, home)
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"CAPTURE_DYNAMICS_RESULT shots=%d failures=%d"
			% [report.shots.size(), report.failures.size()]
		)
	)
	quit(0 if report.failures.is_empty() else 1)


## The first pair of settlements a shuttle can join, home first; empty when none can.
func _shuttle_line(sim: RefCounted) -> Dictionary:
	var places: Array = sim.state.settlements
	for first: int in range(places.size()):
		for second: int in range(first + 1, places.size()):
			var line: Dictionary = sim.road_quote(
				int(places[first].region), int(places[second].region), "shuttle"
			)
			if bool(line.reachable):
				return line
	return {}


## Close views of the first shuttle line's pad in the home region: parked, then in flight.
func _shuttle_shots(home: Dictionary) -> void:
	map.show_region(int(home.id))
	while map.region_busy:
		await process_frame
	_set_local_time(home, 0.4)
	if map.shuttle_flights.is_empty():
		report.failures.append("no shuttle line in the home region")
		return
	var flight: Dictionary = map.shuttle_flights[0]
	map.local_pitch = 0.62
	map.smooth_pitch = 0.62
	for shot: Array in [["shuttle_parked", 2.0, 6.5], ["shuttle_flying", 21.5, 11.0]]:
		flight.clock = float(shot[1])
		map._fly(0.0)
		# The region camera stands 4 units to the right of its pivot (room for the side panels).
		var right := Vector3(cos(map.local_yaw), 0.0, -sin(map.local_yaw))
		map.camera_pivot = (flight.craft as Node3D).position - right * 4.0
		map.local_distance = float(shot[2])
		map.smooth_distance = float(shot[2])
		await _shot(str(shot[0]))


## Close views of the late great works standing in the home region, with their stages or levels.
func _works_shots(home: Dictionary) -> void:
	map.show_region(int(home.id))
	while map.region_busy:
		await process_frame
	_set_local_time(home, 0.4)
	map.local_pitch = 0.7
	map.smooth_pitch = 0.7
	var right := Vector3(cos(map.local_yaw), 0.0, -sin(map.local_yaw))
	for node: Node in map.buildings_root.get_children():
		var kind: String = str(node.get_meta("building_kind", ""))
		if not kind in ["terraforming", "capital_district"]:
			continue
		map.camera_pivot = (node as Node3D).position - right * 4.0
		map.local_distance = 15.0
		map.smooth_distance = 15.0
		await _shot("work_" + kind)


## Hour angle 0 is local noon at the site, PI local midnight.
func _set_local_time(site: Dictionary, hour_angle: float) -> void:
	map.sky.spin = wrapf(map.sky.sun_yaw - deg_to_rad(float(site.lon)) + hour_angle, 0.0, TAU)
	map.planet.rotation.y = map.sky.spin


func _globe(site: Dictionary, hour_angle: float, distance: float, name: String) -> void:
	map.show_planet()
	_set_local_time(site, hour_angle)
	map.planet_yaw = deg_to_rad(float(site.lon)) + map.sky.spin
	map.planet_pitch = deg_to_rad(float(site.lat)) * 0.75
	map.planet_distance = distance
	map.smooth_yaw = map.planet_yaw
	map.smooth_pitch = map.planet_pitch
	map.smooth_distance = distance
	await _shot(name)


func _shot(name: String) -> void:
	for _frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = folder + "/" + name + ".png"
	image.save_png(path)
	report.shots.append({"name": name, "path": path, "mode": map.mode, "spin": map.sky.spin})
	print("CAPTURE ", path)


## Every plot of the home site gets a building, cycling through the kinds, some still being built and
## one worked-out mine: a render-only copy of the state, then close views from three sides.
func _showcase(sim: RefCounted, home: Dictionary) -> void:
	var shown: Dictionary = sim.state.duplicate(true)
	var kinds: Array = sim.config.buildings.keys()
	kinds.sort()
	var plots: Array = sim.geo.regions[int(home.id)].get("plots", [])
	var place: Dictionary = {}
	for settlement: Dictionary in shown.settlements:
		if int(settlement.region) == int(home.id):
			place = settlement
	var buildings: Array = []
	var start: int = int(str(options.get("first", "0")))
	for index: int in range(plots.size()):
		var kind: String = kinds[(start + index) % kinds.size()]
		(
			buildings
			. append(
				{
					"kind": kind,
					"plot": index,
					"active": true,
					"enabled": true,
					"remaining": 30 if index % 9 == 4 else 0,
				}
			)
		)
	place.buildings = buildings
	map.sync_state(shown)
	map.show_planet()
	map.show_region(int(home.id))
	while map.region_busy:
		await process_frame
	_set_local_time(home, 0.5)
	map.local_distance = 38.0
	map.smooth_distance = 38.0
	for view: int in range(3):
		map.local_yaw = 0.68 + view * 2.0
		map.smooth_yaw = map.local_yaw
		await _shot("showcase_%d_%d" % [start, view])
