extends SceneTree
## The nightscape sheet (1.10 plan, reviews): one coastal town at its stages (landing, housing
## built on one side, an operating harbour), each seen from three distances: the globe at its
## default distance, the flat map at its closest, and the district. Local midnight at the town,
## clouds off, and the camera held the same within each row, so only the town changes.
## STAGED FIXTURES: the stages after the landing are written straight into a copy of the state
## (buildings finished, people moved in, the harbour working), not reached through play; the
## landing is real. The harbour stage puts its ship three quarters of the way in to the berth on
## every view. `--clip=on` also writes two frame sequences: the ship sailing in to the berth in the
## district, and the globe zooming in on the town, each lit by the same state.
##
## godot --path game --script res://tests/art/capture_nightscape.gd -- --seed=260129
##   --out=<folder> [--size=1920x1080] [--labels=on|off] [--side=inland|west|east]
##   [--stages=landing,housing,harbour] [--site=<id>] [--clip=on]

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const LightField = preload("res://world/light_field.gd")
const Rules = preload("res://simulation/rules.gd")
## Homes the housing stage adds, and how many people move into them.
const HOMES: int = 3
const FLAT_CLOSEST: float = 4.2
## Where the harbour stage shows its ship: this share of the way in from the offing.
const SHIP_IN: float = 0.75
const CLIP_FRAMES: int = 36
const GLOBE_DEFAULT: float = 10.3
const GLOBE_CLOSE: float = 4.4
## The district camera: turned a little off the line to the sea, far enough for town and quay.
const DISTRICT_TURN: float = 0.35
const DISTRICT_DISTANCE: float = 74.0
const DISTRICT_PITCH: float = 0.62

var options: Dictionary = {
	"seed": "260129",
	"out": "user://nightscape",
	"size": "1920x1080",
	"labels": "on",
	"side": "inland",
	"stages": "landing,housing,harbour",
	"site": "",
	"clip": "off"
}
var map: Node3D
var folder: String = ""
var report: Dictionary = {"shots": [], "stages": {}, "failures": []}


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
	var site: int = _coastal_site(sim)
	var landed: String = sim.act("settle", {"site": site})
	if landed != "":
		report.failures.append("landing refused: " + landed)
	for _day: int in range(2):
		sim.tick()
	map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.set_visual_options(false, true, false)
	while map.atlas_refining:
		await process_frame
	var home: Dictionary = sim.geo.regions[site]
	var stages: Dictionary = {"landing": sim.state.duplicate(true)}
	stages.housing = _with_housing(sim, stages.landing, site)
	stages.harbour = _with_harbour(sim, stages.housing, site)
	for stage: String in str(options.stages).split(","):
		if not stages.has(stage):
			continue
		var shown: Dictionary = stages[stage]
		if stage == "harbour":
			shown.day = _ship_day(int(shown.day), site)
		map.sync_state(shown)
		var lights: Array = LightField.lights(
			shown, sim.geo, Rules.read("economy").buildings, map.landing_camps()
		)
		report.stages[stage] = {
			"lights": lights.size(),
			"centroid": var_to_str(LightField.centroid(lights)),
			"population": int(shown.settlements[0].population),
			"buildings": shown.settlements[0].buildings.size()
		}
		report.stages[stage].ships = map.globe_ships.size()
		await _globe(home, stage)
		await _flat(home, stage)
		await _district(home, stage)
		if stage == "harbour" and str(options.clip) == "on":
			await _clips(home)
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"CAPTURE_NIGHTSCAPE_RESULT site=%d shots=%d failures=%d %s"
			% [site, report.shots.size(), report.failures.size(), str(report.failures)]
		)
	)
	quit(0 if report.failures.is_empty() else 1)


## The first coastal start the world suggests, or the one asked for.
func _coastal_site(sim: RefCounted) -> int:
	if str(options.site) != "":
		return int(options.site)
	for pair: Array in sim.geo.get("playability", {}).get("pairs", []):
		if bool(sim.geo.regions[int(pair[0])].get("coast", false)):
			return int(pair[0])
	for reg: Dictionary in sim.geo.regions:
		if bool(reg.get("coast", false)):
			return int(reg.id)
	return int(sim.geo.playability.pairs[0][0])


## STAGED: HOMES homes finished on the chosen side of town, full of people.
func _with_housing(sim: RefCounted, base: Dictionary, site: int) -> Dictionary:
	var shown: Dictionary = base.duplicate(true)
	var s: Dictionary = shown.settlements[0]
	var plots: Array = sim.geo.regions[site].get("plots", [])
	var taken: Dictionary = {}
	for b: Dictionary in s.buildings:
		taken[int(b.plot)] = true
	var free: Array = []
	for index: int in range(plots.size()):
		if not taken.has(index) and str(plots[index].kind) == "general":
			free.append(index)
	var side: float = _side_sign(sim, site, free)
	free.sort_custom(
		func(a: int, b: int) -> bool: return side * float(plots[a].x) > side * float(plots[b].x)
	)
	var beds: int = 0
	for index: int in free.slice(0, HOMES):
		var home: Dictionary = sim.Production.new_building(sim, "habitat", 0)
		home.plot = index
		home.active = true
		s.buildings.append(home)
		beds += int(sim.config.buildings.habitat.housing)
	shown.next_building_uid = sim.state.next_building_uid
	s.population = int(s.population) + beds
	s.workers = int(s.workers) + beds
	return shown


## STAGED: the housing stage with its small harbour finished and working at the shore.
func _with_harbour(sim: RefCounted, base: Dictionary, site: int) -> Dictionary:
	var shown: Dictionary = base.duplicate(true)
	var s: Dictionary = shown.settlements[0]
	var harbor: Dictionary = sim.Production.new_building(sim, "harbor", 0)
	harbor.plot = -1
	harbor.active = true
	s.buildings.append(harbor)
	shown.next_building_uid = sim.state.next_building_uid
	if not bool(sim.geo.regions[site].get("coast", false)):
		report.failures.append("the harbour stage needs a coastal site")
	return shown


## A day of the next three on which the ship light is on its way in (flat_view `place_ships`),
## nearest SHIP_IN of the way, at the sky's fraction of the day.
func _ship_day(day: int, site: int) -> int:
	var best: int = day
	var gap: float = INF
	for offset: int in range(int(map.SHIP_DAYS)):
		var phase: float = (
			fposmod(float(day + offset) + map.sky.day_fraction + float(site) * 0.37, map.SHIP_DAYS)
			/ map.SHIP_DAYS
		)
		var target: float = SHIP_IN * 0.34
		if absf(phase - target) < gap:
			gap = absf(phase - target)
			best = day + offset
	return best


## +1 builds east, -1 west; "inland" takes the side with more free ground.
func _side_sign(sim: RefCounted, site: int, free: Array) -> float:
	match str(options.side):
		"east":
			return 1.0
		"west":
			return -1.0
	var plots: Array = sim.geo.regions[site].get("plots", [])
	var east: int = 0
	for index: int in free:
		if float(plots[index].x) > 0.0:
			east += 1
	return 1.0 if east * 2 >= free.size() else -1.0


## Hour angle PI is local midnight at the site.
func _midnight(site: Dictionary) -> void:
	map.sky.spin = wrapf(map.sky.sun_yaw - deg_to_rad(float(site.lon)) + PI, 0.0, TAU)
	map.planet.rotation.y = map.sky.spin


func _globe(site: Dictionary, stage: String) -> void:
	map.show_planet()
	_midnight(site)
	map.planet_yaw = deg_to_rad(float(site.lon)) + map.sky.spin
	map.planet_pitch = deg_to_rad(float(site.lat)) * 0.75
	map.planet_distance = GLOBE_DEFAULT
	map.smooth_yaw = map.planet_yaw
	map.smooth_pitch = map.planet_pitch
	map.smooth_distance = map.planet_distance
	await _shot(stage + "_globe")


func _flat(site: Dictionary, stage: String) -> void:
	map.show_flat()
	_midnight(site)
	map.flat_user_zoomed = true
	map.flat_size = FLAT_CLOSEST
	map.flat_center = Vector2(float(site.lon) / 20.0, float(site.lat) / 20.0)
	map.camera.size = FLAT_CLOSEST
	await _shot(stage + "_flat")


func _district(site: Dictionary, stage: String) -> void:
	map.show_region(int(site.id))
	while map.region_busy:
		await process_frame
	_midnight(site)
	# One camera for every stage: from the land side, over the town towards its quay and the
	# water the ships come in over (region_view `harbor_spot`, which depends on the ground only).
	map.local_distance = 67.0
	map.local_yaw = 0.68
	map.local_pitch = 0.75
	var spot: Dictionary = map.harbor_spot(int(site.id))
	if not spot.is_empty():
		var shore: Vector2 = spot.shore
		var heading: Vector2 = spot.heading
		var centre: Vector2 = shore * 0.5 + heading * 6.0
		map.camera_pivot = Vector3(centre.x, 0.0, centre.y)
		map.local_yaw = atan2(-heading.x, -heading.y) + DISTRICT_TURN
		map.local_distance = DISTRICT_DISTANCE
		map.local_pitch = DISTRICT_PITCH
	map.smooth_distance = map.local_distance
	map.smooth_yaw = map.local_yaw
	map.smooth_pitch = map.local_pitch
	# The ship three quarters of the way in from its offing, as on the globe and the flat map.
	map.ship_clock = map.SHIP_CYCLE_S.x * SHIP_IN
	map._sail(0.0)
	await _shot(stage + "_district")


## Two frame sequences in `clip_ship` and `clip_zoom`: the district's ship sailing in from its
## offing to the berth, then the globe from its default distance down to the town. Same state,
## same night: the lights stay where they are while the ship and the camera move.
func _clips(site: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(folder + "/clip_ship")
	DirAccess.make_dir_recursive_absolute(folder + "/clip_zoom")
	for frame: int in range(CLIP_FRAMES):
		map.ship_clock = map.SHIP_CYCLE_S.x * float(frame) / float(CLIP_FRAMES - 1)
		map._sail(0.0)
		await _shot("clip_ship/%03d" % frame, false)
	map.show_planet()
	_midnight(site)
	map.planet_yaw = deg_to_rad(float(site.lon)) + map.sky.spin
	map.planet_pitch = deg_to_rad(float(site.lat)) * 0.75
	map.smooth_yaw = map.planet_yaw
	map.smooth_pitch = map.planet_pitch
	for frame: int in range(CLIP_FRAMES):
		var t: float = smoothstep(0.0, 1.0, float(frame) / float(CLIP_FRAMES - 1))
		map.planet_distance = lerpf(GLOBE_DEFAULT, GLOBE_CLOSE, t)
		map.smooth_distance = map.planet_distance
		await _shot("clip_zoom/%03d" % frame, false)


func _shot(name: String, listed: bool = true) -> void:
	_show_labels(str(options.labels) != "off")
	for _frame: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = folder + "/" + name + ".png"
	image.save_png(path)
	if listed:
		report.shots.append({"name": name, "path": path, "mode": map.mode, "spin": map.sky.spin})
		print("CAPTURE ", path)


## Place names, building labels, site markers and the transport diagram: on for the normal view,
## off for the clean one.
func _show_labels(on: bool) -> void:
	for label: Node in map.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = on
	for overlay: Variant in [
		map.get("transport_root"),
		map.get("flat_transport_root"),
		map.get("marker_root"),
		map.get("flat_marker_root")
	]:
		if overlay is Node3D and is_instance_valid(overlay):
			(overlay as Node3D).visible = on
