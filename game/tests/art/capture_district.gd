extends SceneTree
## 1.12: the live district beside the approved district's frames (docs/handoff/
## approved-terrain-region/reference). ORDINARY PLAY: the balanced bot runs a new expedition on
## --seed for --days days (CC-GEO-2.3); its capital's district (or --region) is then shown and
## captured from the approved views' camera distances, pitches and fields of view, converted to
## district units (district_plan.gd): settlement (155.5 m, 15.7 degrees, 43), rocks (21.6 m, 17.2,
## 39), verge (16.2 m, 11.3, 46), and the district's own default view, at day and at dusk (the
## sun --dusk_height and --day_height over the site's horizon). Writes PNG frames and report.json.
##   xvfb-run -a godot --path game --rendering-method gl_compatibility --script
##     res://tests/art/capture_district.gd -- --out=<folder> [--seed=260129] [--days=1200]
##     [--size=1920x1080] [--hours=day,dusk] [--views=overview,settlement,verge,rocks]

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")
const Geo = preload("res://world/world_gen.gd")

## [distance m, pitch degrees, fov] of the approved views (views.json, metres).
const VIEWS: Dictionary = {
	"settlement": [155.5, 15.7, 43.0],
	"rocks": [21.6, 17.2, 39.0],
	"verge": [16.2, 11.3, 46.0],
}

var options: Dictionary = {
	"seed": "260129",
	"out": "user://district",
	"size": "1920x1080",
	"days": "1200",
	"hours": "day,dusk",
	"views": "overview,settlement,verge,rocks",
	"region": "",
	"day_height": "0.6",
	"dusk_height": "0.07",
}
var map: Node3D
var folder: String = ""
var report: Dictionary = {"shots": [], "failures": []}


func _initialize() -> void:
	Watchdog.arm(self, 3000.0)
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
		if str(sim.state.status) == "failed" or sim.state.settlements.is_empty():
			break
	if sim.state.settlements.is_empty():
		report.failures.append("no settlement")
		_finish()
		return
	var capital: Dictionary = sim.state.settlements[0]
	var region: int = int(options.region) if str(options.region) != "" else int(capital.region)
	map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.set_visual_options(false, true, false)
	while map.atlas_refining:
		await process_frame
	map.sync_state(sim.state)
	var started: int = Time.get_ticks_msec()
	map.show_region(region)
	while map.region_busy:
		await process_frame
	var entry_ms: int = Time.get_ticks_msec() - started
	_show_overlays(false)
	var town: Dictionary = sim.settlement(region)
	report.colony = {
		"seed": int(options.seed),
		"version": str(sim.geo.version),
		"day": int(sim.state.day),
		"region": region,
		"coast": bool(sim.geo.regions[region].get("coast", false)),
		"river": bool(sim.geo.regions[region].get("river", false)),
		"people": int(town.get("population", 0)),
		"buildings": town.get("buildings", []).size(),
		"region_entry_ms": entry_ms,
	}
	var targets: Dictionary = _targets(sim, region)
	report.targets = {}
	for key: String in targets:
		report.targets[key] = var_to_str(targets[key])
	for hour: String in str(options.hours).split(","):
		_set_hour(sim, region, float(options.get(hour + "_height", 0.3)))
		for view: String in str(options.views).split(","):
			await _view(view, targets, hour)
	_finish()


func _finish() -> void:
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"CAPTURE_DISTRICT_RESULT shots=%d failures=%d %s"
			% [report.shots.size(), report.failures.size(), str(report.failures)]
		)
	)
	quit(0 if report.failures.is_empty() else 1)


## Where each view looks: the middle of the town's buildings; a road verge on the main street
## near the middle of town; a weathered rock if the district has one, else open ground.
func _targets(sim: RefCounted, region: int) -> Dictionary:
	var town := Vector2.ZERO
	var count: int = 0
	for b: Dictionary in sim.settlement(region).buildings:
		if int(b.get("plot", -1)) >= 0:
			town += Vector2(map.plot_lot(region, int(b.plot), str(b.kind)).pos)
			count += 1
	if count > 0:
		town /= count
	var key: int = map.district_key(region)
	var street: Vector2 = DistrictPlan.warp(Vector2(map._town_offset(), 1.5), key)
	var beyond: Vector2 = DistrictPlan.warp(Vector2(map._town_offset(), 2.5), key)
	var along: Vector2 = (beyond - street).normalized()
	var side := Vector2(-along.y, along.x)
	var verge: Vector2 = street + side * (4.3 + 2.0) * DistrictPlan.UNIT
	var rock: Vector2 = Vector2(town.x + 14.0, town.y - 9.0)
	if map.has_method("rock_spots"):
		var spots: Array = map.rock_spots()
		var best: float = INF
		for spot: Vector2 in spots:
			var d: float = spot.distance_to(town)
			if d > 6.0 and d < best:
				best = d
				rock = spot
	return {
		"overview": town,
		"settlement": town,
		"verge": verge,
		"verge_heading": along,
		"rocks": rock,
	}


func _view(view: String, targets: Dictionary, hour: String) -> void:
	var target: Vector2 = targets.get(view, targets.overview)
	map.camera_pivot = Vector3(target.x, map._ground(target.x, target.y), target.y)
	if view == "overview":
		map.local_distance = 67.0
		map.local_pitch = 0.75
		map.local_yaw = 0.68
	else:
		var spec: Array = VIEWS[view]
		map.local_distance = float(spec[0]) * DistrictPlan.UNIT
		map.local_pitch = deg_to_rad(float(spec[1]))
		map.local_yaw = 0.68
		if view == "verge":
			var heading: Vector2 = targets.verge_heading
			map.local_yaw = atan2(-heading.x, -heading.y) + 0.5
	map.smooth_yaw = map.local_yaw
	map.smooth_pitch = map.local_pitch
	map.smooth_distance = map.local_distance
	for _frame: int in range(8):
		await process_frame
	map.camera.fov = 43.0 if view == "overview" else float(VIEWS[view][2])
	for _frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var name: String = "%s_%s" % [view, hour]
	image.save_png(folder + "/" + name + ".png")
	(
		report
		. shots
		. append(
			{
				"name": name,
				"file": name + ".png",
				"distance_units": map.local_distance,
				"distance_m": map.local_distance * DistrictPlan.METRES_PER_UNIT,
				"pitch_deg": rad_to_deg(map.local_pitch),
				"fov": map.camera.fov,
				"near": map.camera.near,
			}
		)
	)
	print("CAPTURE ", name)


## The sky turned so the sun stands `height` (sine of its elevation) over the site's horizon, in
## the evening.
func _set_hour(sim: RefCounted, region: int, height: float) -> void:
	var reg: Dictionary = sim.geo.regions[region]
	var best_spin: float = 0.0
	var best_gap: float = INF
	for step: int in range(720):
		var spin: float = TAU * step / 720.0
		map.sky.spin = spin
		var up: Vector3 = Geo.unit_point(float(reg.lat), float(reg.lon)).rotated(Vector3.UP, spin)
		var sun: Vector3 = map.sky.sun_world()
		var now: float = sun.dot(up)
		map.sky.spin = spin + 0.01
		var later: Vector3 = Geo.unit_point(float(reg.lat), float(reg.lon)).rotated(
			Vector3.UP, spin + 0.01
		)
		var setting: bool = map.sky.sun_world().dot(later) < now
		if setting and absf(now - height) < best_gap:
			best_gap = absf(now - height)
			best_spin = spin
	map.sky.spin = best_spin
	report["spin_%.2f" % height] = best_spin


func _show_overlays(on: bool) -> void:
	map.set_route_overlay(on)
	for label: Node in map.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = on
	for overlay: Variant in [map.get("marker_root"), map.get("weather_root")]:
		if overlay is Node3D and is_instance_valid(overlay):
			(overlay as Node3D).visible = on
