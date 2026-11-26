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
##     [--save=<file>: play once and keep the colony there, or load it when it exists]
##     [--landing=inland_dry: land the capital on the driest temperate inland playable site]
## The approved views are lit from behind the camera; each view here turns the same way to the
## site's own sun. --approved_closeups=false draws Boulder 01's play mesh instead of its approved
## scan. Diagnostics: --hide_sea, --no_fringe, --no_terrain_shadow, --probe_pixel=x:y.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")
const Geo = preload("res://world/world_gen.gd")
const DistrictNature = preload("res://world/district/district_nature.gd")

## The inland dry landing's floor: a temperate dry site, not a polar one (degrees C).
const DRY_SITE_MIN_C: float = 8.0
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
	"dusk_height": "0.3",
	"night_height": "-0.3",
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
	var saved: String = str(options.get("save", ""))
	if saved != "" and FileAccess.file_exists(saved):
		var refused: String = sim.load_game(saved)
		if refused != "":
			report.failures.append("load: " + refused)
	else:
		sim.new_game(int(options.seed), "capital", 1, "normal")
		var bot: RefCounted = Bot.new()
		bot.begin(sim, int(options.seed))
		if str(options.get("landing", "")) == "inland_dry":
			_land_inland_dry(sim, bot)
		for _day: int in range(int(options.days)):
			bot.on_day()
			sim.tick()
			if str(sim.state.status) == "failed" or sim.state.settlements.is_empty():
				break
		if saved != "":
			var refused: String = sim.save_game(saved)
			if refused != "":
				report.failures.append("save: " + refused)
	if sim.state.settlements.is_empty():
		report.failures.append("no settlement")
		_finish()
		return
	var capital: Dictionary = sim.state.settlements[0]
	var region: int = int(options.region) if str(options.region) != "" else int(capital.region)
	# Comparison captures draw Boulder 01's approved scan near the camera, as the approved frames did.
	DistrictNature.approved_closeups = str(options.get("approved_closeups", "true")) == "true"
	report.approved_closeups = DistrictNature.approved_closeups
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
		"fringe_ms": int(map.get("fringe_ms")),
		"nature": map.get("nature_counts"),
		"hollows_filled": int(map.get("hollows_filled")),
	}
	if str(options.get("no_terrain_shadow", "")) == "true":
		var land: Node = map.surface.get_node_or_null("Landscape")
		if land is GeometryInstance3D:
			(land as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if str(options.get("no_fringe", "")) == "true":
		map.ground_material.set_shader_parameter("fringe_rect", Vector4.ZERO)
	if str(options.get("hide_sea", "")) == "true":
		for node: Node in map.surface.find_children("*", "MeshInstance3D", false, false):
			if (node as MeshInstance3D).mesh is PlaneMesh:
				(node as MeshInstance3D).visible = false
	if str(options.get("ground_debug", "")) != "":
		_debug_ground(str(options.ground_debug))
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
	# The verge: beside the road paving nearest the middle of town, looking along it.
	var verge: Vector2 = town
	var along := Vector2(0.0, 1.0)
	var nearest: float = INF
	for entry: Array in map.town_streets.edges:
		if int(entry[2]) != 0:
			continue
		var path: PackedVector2Array = entry[0]
		for index: int in range(path.size() - 1):
			var d: float = path[index].distance_to(town)
			if d < nearest:
				nearest = d
				along = (path[index + 1] - path[index]).normalized()
				var side := Vector2(-along.y, along.x)
				verge = path[index] + side * (float(entry[1]) + 5.0 * DistrictPlan.UNIT)
	var rock: Vector2 = Vector2(town.x + 14.0, town.y - 9.0)
	# The rocks: the largest weathered boulder within 40 units of the middle of town with no tree
	# or shrub within 35 m, so nothing stands between it and the camera.
	var nature: Node = map.surface.get_node_or_null("DistrictNature")
	var largest: float = 0.0
	var plants: Array[Vector2] = []
	var boulders: Array = []
	if nature != null:
		for batch: Node in nature.get_children():
			var label: String = str(batch.name)
			if not batch is MultiMeshInstance3D or label.ends_with("_crown"):
				continue
			var kind: int = int(label.get_slice("_", 1))
			var group: MultiMesh = (batch as MultiMeshInstance3D).multimesh
			for index: int in range(group.instance_count):
				var placed: Transform3D = group.get_instance_transform(index)
				var spot := Vector2(placed.origin.x, placed.origin.z)
				if kind <= 3:
					plants.append(spot)
				elif kind >= 8 and kind <= 11 and label.ends_with("_near"):
					boulders.append([spot, placed.basis.x.length()])
	for entry: Array in boulders:
		var spot: Vector2 = entry[0]
		if spot.distance_to(town) > 40.0 or float(entry[1]) <= largest:
			continue
		var clear: bool = true
		for plant: Vector2 in plants:
			if plant.distance_to(spot) < 35.0 * DistrictPlan.UNIT:
				clear = false
				break
		if clear:
			largest = float(entry[1])
			rock = spot
	return {
		"overview": town,
		"settlement": town,
		"verge": verge,
		"verge_heading": along,
		"rocks": rock,
	}


## The approved views are lit from behind the camera (views.json and preview.gd's sun: about 165
## degrees between the view and the sun); each view here turns the same way to the site's own sun,
## the verge along the stretch of road nearest the middle of town that best runs away from it.
func _view(view: String, targets: Dictionary, hour: String) -> void:
	var target: Vector2 = targets.get(view, targets.overview)
	var to_sun: Vector3 = map.sun_light.global_basis.z
	var sun_yaw: float = atan2(to_sun.x, to_sun.z)
	if view == "overview":
		map.local_distance = 67.0
		map.local_pitch = 0.75
		map.local_yaw = 0.68
	else:
		var spec: Array = VIEWS[view]
		map.local_distance = float(spec[0]) * DistrictPlan.UNIT
		map.local_pitch = deg_to_rad(float(spec[1]))
		map.local_yaw = sun_yaw + deg_to_rad(15.0)
		if view == "settlement":
			map.local_yaw = _town_facing(target, sun_yaw, map.local_distance)
		if view == "verge":
			var road: Array = _verge_along(targets.overview, Vector2(to_sun.x, to_sun.z))
			target = road[0]
			var away: Vector2 = road[1]
			map.local_yaw = atan2(-away.x, -away.y)
	map.camera_pivot = Vector3(target.x, map._ground(target.x, target.y), target.y)
	map.smooth_yaw = map.local_yaw
	map.smooth_pitch = map.local_pitch
	map.smooth_distance = map.local_distance
	for _frame: int in range(8):
		await process_frame
	map.camera.fov = 43.0 if view == "overview" else float(VIEWS[view][2])
	for _frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if str(options.get("probe_pixel", "")) != "":
		_probe_pixel(str(options.probe_pixel))
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


## Of the turns within 60 degrees of the sun's, the one whose view takes in most of the town's
## buildings (from the camera's foot to twice its distance beyond the target), so the settlement
## view looks over the town rather than over open ground or water.
func _town_facing(target: Vector2, sun_yaw: float, distance: float) -> float:
	var best: float = sun_yaw
	var best_count: int = -1
	for step: int in range(-6, 7):
		var yaw: float = sun_yaw + deg_to_rad(10.0 * step)
		var back := Vector2(sin(yaw), cos(yaw))
		var camera: Vector2 = target + back * distance
		var count: int = 0
		for spot: Vector2 in map.town_spots:
			var ahead: Vector2 = spot - camera
			var along: float = ahead.dot(-back)
			if along < distance * 0.2 or along > distance * 3.0:
				continue
			if absf(ahead.dot(Vector2(-back.y, back.x))) < along * 0.45:
				count += 1
		if count > best_count:
			best_count = count
			best = yaw
	return best


## The capital on inland, dry, temperate ground with no river or lake (the bot builds it up from
## there): the comparison's inland dry site, where no water may show. The driest such site of the
## world's playable pairs, else the driest such point a player could found at (free placement).
func _land_inland_dry(sim: RefCounted, bot: RefCounted) -> void:
	var best: int = -1
	var driest: float = INF
	for pair: Array in sim.geo.get("playability", {}).get("pairs", []):
		for site: int in [int(pair[0]), int(pair[1])]:
			var reg: Dictionary = sim.geo.regions[site]
			if bool(reg.get("coast", false)) or bool(reg.get("river", false)):
				continue
			if (
				float(reg.get("temperature", 0.0)) < DRY_SITE_MIN_C
				or sim.settle_refusal(site) != ""
			):
				continue
			if float(reg.get("rainfall", 1.0)) < driest:
				driest = float(reg.get("rainfall", 1.0))
				best = site
	if best >= 0:
		var landed: Dictionary = sim.geo.regions[best]
		report.landing = {
			"site": best,
			"rainfall": driest,
			"temperature": float(landed.get("temperature", 0.0)),
			"lat": float(landed.lat),
			"lon": float(landed.lon),
		}
		bot.home = best
		bot.act("settle", {"site": best})
		bot.act("build", {"site": best, "kind": "mine_ore"})
		bot.act("build", {"site": best, "kind": "mine_copper"})
		return
	var ground: Dictionary = _dry_ground(sim)
	if ground.is_empty():
		report.failures.append("no inland dry ground to land on")
		return
	var refusal: String = bot.act("settle_at", {"lat": float(ground.lat), "lon": float(ground.lon)})
	if refusal != "" or sim.state.settlements.is_empty():
		report.failures.append("landing refused: " + refusal)
		return
	bot.home = int(sim.state.settlements[0].region)
	report.landing = {
		"site": bot.home,
		"placed": true,
		"lat": float(ground.lat),
		"lon": float(ground.lon),
		"temperature": float(ground.temperature),
		"water": float(ground.water),
		"biome": str(ground.biome),
		"terrain": str(ground.terrain),
	}


## The driest ground a capital could be founded on at a grid cell's centre: inland, no river or
## lake, DRY_SITE_MIN_C or warmer.
func _dry_ground(sim: RefCounted) -> Dictionary:
	var found: Dictionary = {}
	var width: int = int(sim.geo.grid_width)
	for index: int in range(sim.geo.grid.size()):
		var lat: float = 90.0 - (float(index / width) + 0.5) * 2.5
		var lon: float = (float(index % width) + 0.5) * 2.5 - 180.0
		var view: Dictionary = sim.Placement.view(sim, lat, lon)
		if str(view.refusal) != "" or bool(view.coast) or bool(view.river) or bool(view.lake):
			continue
		if bool(view.get("lake_here", false)) or float(view.temperature) < DRY_SITE_MIN_C:
			continue
		if found.is_empty() or float(view.water) < float(found.water):
			found = view
	return found


## A point five metres off a road near the middle of town, on a stretch running away from the sun,
## and that stretch's heading away from it.
func _verge_along(town: Vector2, to_sun: Vector2) -> Array:
	var best: float = -INF
	var spot: Vector2 = town
	var heading := Vector2(0.0, 1.0)
	var sun: Vector2 = to_sun.normalized()
	for entry: Array in map.town_streets.edges:
		if int(entry[2]) != 0:
			continue
		var path: PackedVector2Array = entry[0]
		for index: int in range(path.size() - 1):
			var along: Vector2 = (path[index + 1] - path[index]).normalized()
			var away: Vector2 = along if along.dot(sun) < 0.0 else -along
			var score: float = -away.dot(sun) * 3.0 - path[index].distance_to(town) / 20.0
			if score > best:
				best = score
				heading = away
				var side := Vector2(-along.y, along.x)
				spot = path[index] + side * (float(entry[1]) + 5.0 * DistrictPlan.UNIT)
	return [spot, heading]


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


## Diagnostics: what stands under a pixel ("x:y" in the window's pixels).
## Diagnostic: the landscape drawn unshaded with its albedo (`albedo`), its world normal (`normal`),
## its vertex data (`data`: temperature, rain, wetness) or any shader value (`expr:<glsl>`), to tell
## its material from its light.
func _debug_ground(what: String) -> void:
	var land := map.surface.get_node_or_null("Landscape") as GeometryInstance3D
	if land == null:
		return
	var probe := (map.ground_material as ShaderMaterial).duplicate() as ShaderMaterial
	var code: String = probe.shader.code.replace(
		"render_mode cull_back,", "render_mode unshaded, cull_back,"
	)
	var shown: Dictionary = {
		"normal": "ALBEDO = world_normal * 0.5 + 0.5;",
		"data": "ALBEDO = data.rgb;",
	}
	if what.begins_with("expr:"):
		shown[what] = "ALBEDO = vec3(%s);" % what.substr(5)
	if shown.has(what):
		code = code.replace(
			"\tROUGHNESS = clamp(", "\t" + str(shown[what]) + "\n\tROUGHNESS = clamp("
		)
	var shader := Shader.new()
	shader.code = code
	probe.shader = shader
	land.material_override = probe


func _probe_pixel(pixel: String) -> void:
	var at := Vector2(float(pixel.get_slice(":", 0)), float(pixel.get_slice(":", 1)))
	var origin: Vector3 = map.camera.project_ray_origin(at)
	var direction: Vector3 = map.camera.project_ray_normal(at)
	var hit := Vector3.ZERO
	for step: int in range(4000):
		var p: Vector3 = origin + direction * step * 0.02
		if p.y <= map._ground(p.x, p.z):
			hit = p
			break
	print(
		"PROBE pixel ",
		at,
		" hit ",
		hit,
		" ground ",
		map._ground(hit.x, hit.z),
		" sea ",
		map.sea_level()
	)
	print("PROBE camera ", map.camera.global_position, " sun ", map.sun_light.global_basis.z)
	for node: Node in map.find_children("*", "GeometryInstance3D", true, false):
		var shape := node as GeometryInstance3D
		if not shape.is_visible_in_tree():
			continue
		var box: AABB = shape.get_aabb()
		box = shape.global_transform * box
		if box.grow(0.05).has_point(hit) and box.size.length() < 400.0:
			print("PROBE covers ", shape.get_path(), " ", shape.get_class(), " size ", box.size)
