extends SceneTree
## 1.11 G: the planet-scale light forms (world/town_forms.gd) beside the user's concept sheet
## 沿海与内陆的灯光形态 (docs/v17/lights/concept_light_forms.webp).
## STAGES: one town alone at each of the five light stages (progression.json `lights.stages`, at
## the people and facilities of the stage's threshold), coastal and inland, on the world of --seed:
## the globe at its default distance, straight down on the town at local midnight, clouds off. The
## coastal town stands SHORE_GAP degrees from its shore, as the towns on the sheet do. These are
## STAGED: the town is written into the globe's uniforms, not reached through play.
## CROSSFADE (ordinary play): the balanced bot plays the colony for --days days; its capital at
## local midnight from the planet distances across the crossfade (progression.json `lights.forms`),
## each frame also taken with the lights off, so the light over the town can be measured: the
## per-plot lights and the forms share it and never add up.
## Writes PNG frames and report.json to --out; tools/light_forms_sheet.py lays them out.
##   xvfb-run -a -s "-screen 0 3840x2160x24" godot --path game --rendering-driver opengl3
##     --script res://tests/art/capture_light_forms.gd -- --out=<folder> [--seed=260129]
##     [--size=3840x2160] [--days=1500] [--parts=stages,crossfade]

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const TownForms = preload("res://world/town_forms.gd")
const Rules = preload("res://simulation/rules.gd")
const Geo = preload("res://world/world_gen.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")

const GLOBE_DEFAULT: float = 10.3
const GLOBE_RADIUS: float = 3.0
## The coastal town's distance from its shore, in degrees: about a third of the capital's form,
## where the sheet's coastal towns stand.
const SHORE_GAP: float = 0.8
## The ring on which a coastal site's shore is judged straight, in degrees.
const SHORE_RING: float = 2.5
## The inland town's nearest water at least this far, in degrees, so the capital is not cut.
const INLAND_CLEAR: float = 4.5
## Towns away from the poles, where a degree east is still most of a degree north.
const LATITUDE_LIMIT: float = 40.0
## The ground measured round a town, in degrees: past the capital's ragged edge.
const MEASURE_RADIUS: float = 3.4
const CROSSFADE_DISTANCES: Array[float] = [7.0, 7.6, 8.2, 8.8, 9.4, 10.3, 12.5]

var options: Dictionary = {
	"seed": "260129",
	"out": "user://light_forms",
	"size": "3840x2160",
	"days": "1500",
	"parts": "stages,crossfade",
}
var map: Node3D
var atlas: Image
var folder: String = ""
var report: Dictionary = {"stages": [], "crossfade": [], "failures": []}


func _initialize() -> void:
	Watchdog.arm(self, 2400.0)
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
	map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.set_visual_options(false, true, false)
	while map.atlas_refining:
		await process_frame
	map.show_planet()
	atlas = map.geography_atlas.get_image()
	if atlas.is_compressed():
		atlas.decompress()
	_show_overlays(false)
	report.seed = int(options.seed)
	report.size = [root.size.x, root.size.y]
	report.forms = Rules.read("progression").get("lights", {}).get("forms", {})
	var wanted: PackedStringArray = str(options.parts).split(",")
	if wanted.has("stages"):
		await _stages(sim)
	if wanted.has("crossfade"):
		await _crossfade(sim)
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"CAPTURE_LIGHT_FORMS_RESULT stages=%d crossfade=%d failures=%d %s"
			% [
				report.stages.size(),
				report.crossfade.size(),
				report.failures.size(),
				str(report.failures)
			]
		)
	)
	quit(0 if report.failures.is_empty() else 1)


## STAGED: each stage's threshold town, alone, coastal and inland.
func _stages(sim: RefCounted) -> void:
	var rules: Dictionary = Rules.read("progression").get("lights", {})
	var places: Dictionary = {"coastal": _coastal_spot(sim.geo), "inland": _inland_spot(sim.geo)}
	report.places = places.duplicate(true)
	for kind: String in ["coastal", "inland"]:
		var place: Dictionary = places[kind]
		if place.is_empty():
			report.failures.append("no %s place on seed %s" % [kind, str(options.seed)])
			continue
		for stage: Dictionary in rules.get("stages", []):
			var town: Dictionary = {
				"region": int(place.region),
				"lat": float(place.lat),
				"lon": float(place.lon),
				"population": float(stage.population),
				"facilities": float(stage.facilities),
				"coastal": kind == "coastal",
				"frontier": false,
				"roads": [],
				"fade": 1.0,
			}
			var shown: Dictionary = TownForms.uniforms([town], sim.geo, rules)
			_show_forms(shown)
			_look_down(float(place.lat), float(place.lon), GLOBE_DEFAULT)
			var name: String = "stage_%s_%s" % [kind, str(stage.id)]
			var image: Image = await _shot(name)
			var row: Dictionary = _framing(name, float(place.lat), float(place.lon))
			row.kind = kind
			row.stage = str(stage.id)
			row.stage_name = str(stage.name)
			row.radius_degrees = float(shown.towns[0].z)
			row.sea = [float(shown.shapes[0].x), float(shown.shapes[0].y)]
			row.light = _light(image, row)
			report.stages.append(row)
			print("CAPTURE ", name, " light=", row.light)


## ORDINARY PLAY: the balanced bot's colony, its capital from each crossfade distance.
func _crossfade(sim: RefCounted) -> void:
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(options.seed))
	for _day: int in range(int(options.days)):
		bot.on_day()
		sim.tick()
		if str(sim.state.status) == "failed":
			report.failures.append("the colony failed on day %d" % int(sim.state.day))
			return
	var capital: Dictionary = sim.state.settlements[0]
	var region: Dictionary = sim.geo.regions[int(capital.region)]
	var lat: float = float(capital.get("lat", region.lat))
	var lon: float = float(capital.get("lon", region.lon))
	map.sync_state(sim.state)
	_show_overlays(false)
	report.colony = {
		"day": int(sim.state.day),
		"towns": sim.state.settlements.size(),
		"capital_people": int(capital.population),
		"roads": sim.state.get("roads", []).size(),
		"lat": lat,
		"lon": lon,
	}
	var rules: Dictionary = Rules.read("progression").get("lights", {})
	for distance: float in CROSSFADE_DISTANCES:
		_look_down(lat, lon, distance)
		map.form_weights = Vector2(-1.0, -1.0)
		var name: String = "crossfade_%s" % str(distance).replace(".", "_")
		var lit: Image = await _shot(name)
		var row: Dictionary = _framing(name, lat, lon)
		row.distance = distance
		var shares: Vector2 = TownForms.weights(distance, rules)
		row.plot_share = shares.x
		row.form_share = shares.y
		row.light = _light(lit, row)
		map.globe_shader.set_shader_parameter("plot_lights", 0.0)
		map.globe_shader.set_shader_parameter("form_lights", 0.0)
		var dark: Image = await _shot(name + "_dark")
		row.dark = _light(dark, row)
		row.town_light = float(row.light.mean) - float(row.dark.mean)
		map.form_weights = Vector2(-1.0, -1.0)
		report.crossfade.append(row)
		print("CAPTURE ", name, " town_light=", row.town_light, " shares=", shares)


## The forms of these towns on the globe, and nothing else lit.
func _show_forms(shown: Dictionary) -> void:
	var globe: ShaderMaterial = map.globe_shader
	globe.set_shader_parameter("towns", shown.towns)
	globe.set_shader_parameter("town_style", shown.styles)
	globe.set_shader_parameter("town_shape", shown.shapes)
	globe.set_shader_parameter("town_roads", shown.roads)
	globe.set_shader_parameter("town_count", int(shown.count))
	var empty := Image.create(TownForms.FAR_WIDTH, TownForms.FAR_HEIGHT, true, Image.FORMAT_RG8)
	globe.set_shader_parameter("far_lights", ImageTexture.create_from_image(empty))
	globe.set_shader_parameter("plot_lights", 0.0)
	globe.set_shader_parameter("form_lights", 1.0)


## The camera straight above a point at local midnight.
func _look_down(lat: float, lon: float, distance: float) -> void:
	map.sky.spin = wrapf(map.sky.sun_yaw - deg_to_rad(lon) + PI, 0.0, TAU)
	map.planet.rotation.y = map.sky.spin
	map.planet_yaw = deg_to_rad(lon) + map.sky.spin
	map.planet_pitch = deg_to_rad(lat)
	map.planet_distance = distance
	map.smooth_yaw = map.planet_yaw
	map.smooth_pitch = map.planet_pitch
	map.smooth_distance = distance


func _shot(name: String) -> Image:
	for _frame: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(folder + "/" + name + ".png")
	return image


## Where the town is on screen and how many pixels a degree of ground takes there.
func _framing(name: String, lat: float, lon: float) -> Dictionary:
	var centre: Vector2 = _on_screen(lat, lon)
	var north: Vector2 = _on_screen(lat + 1.0, lon)
	return {
		"name": name,
		"file": name + ".png",
		"x": centre.x,
		"y": centre.y,
		"pixels_per_degree": centre.distance_to(north),
		"lat": lat,
		"lon": lon,
	}


## In the frame's pixels: the camera projects into the 1600 x 900 canvas the window stretches.
func _on_screen(lat: float, lon: float) -> Vector2:
	var point: Vector3 = map.planet.to_global(Geo.unit_point(lat, lon) * GLOBE_RADIUS)
	var scale: float = float(root.size.x) / root.get_visible_rect().size.x
	return map.camera.unproject_position(point) * scale


## The mean and brightest luminance (0-1) within MEASURE_RADIUS degrees of the town.
func _light(image: Image, row: Dictionary) -> Dictionary:
	var reach: int = int(ceil(float(row.pixels_per_degree) * MEASURE_RADIUS))
	var cx: int = int(round(float(row.x)))
	var cy: int = int(round(float(row.y)))
	var total: float = 0.0
	var brightest: float = 0.0
	var count: int = 0
	for y: int in range(maxi(0, cy - reach), mini(image.get_height(), cy + reach + 1)):
		for x: int in range(maxi(0, cx - reach), mini(image.get_width(), cx + reach + 1)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) > reach * reach:
				continue
			var color: Color = image.get_pixel(x, y)
			var value: float = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
			total += value
			brightest = maxf(brightest, value)
			count += 1
	return {"mean": total / maxf(1.0, float(count)), "max": brightest, "pixels": count}


## A coastal town: from a coastal region's centre out to its shore, then SHORE_GAP back inland,
## with land behind it for the capital to spread over. Of the regions that fit, the one with the
## straightest shore, as on the sheet.
func _coastal_spot(world: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -1.0
	for region: int in _by_latitude(world, true):
		var reg: Dictionary = world.regions[region]
		var sea: Vector2 = TownForms.sea_direction(world, float(reg.lat), float(reg.lon), 2.0)
		if sea == Vector2.ZERO:
			continue
		var shore: Vector2 = Vector2.ZERO
		var found: bool = false
		for step: int in range(1, 121):
			var at: Vector2 = _offset(float(reg.lat), float(reg.lon), sea, step * 0.05)
			if not _land(world, at.x, at.y):
				shore = _offset(float(reg.lat), float(reg.lon), sea, (step - 1) * 0.05)
				found = true
				break
		if not found:
			continue
		var town: Vector2 = _offset(shore.x, shore.y, sea, -SHORE_GAP)
		var behind: bool = _land(world, town.x, town.y)
		for step: int in range(1, 8):
			var back: Vector2 = _offset(town.x, town.y, sea, -0.5 * step)
			behind = behind and _land(world, back.x, back.y)
		if not behind:
			continue
		var score: float = _straight_shore(world, town, sea)
		if score > best_score:
			best_score = score
			best = {
				"region": region,
				"lat": town.x,
				"lon": town.y,
				"sea": [sea.x, sea.y],
				"straight": score,
			}
	return best


## The share of the points on a ring SHORE_RING degrees round the town that are water just where a
## straight shore SHORE_GAP away towards the sea would put it.
func _straight_shore(world: Dictionary, town: Vector2, sea: Vector2) -> float:
	var matched: int = 0
	for index: int in range(32):
		var angle: float = TAU * index / 32.0
		var way := Vector2(cos(angle), sin(angle))
		var at: Vector2 = _offset(town.x, town.y, way, SHORE_RING)
		var wet: bool = way.dot(sea) * SHORE_RING > SHORE_GAP
		if wet != _land(world, at.x, at.y):
			matched += 1
	return matched / 32.0


## An inland town: the inland region nearest the equator whose nearest water is INLAND_CLEAR
## degrees away or more, else the one farthest from water.
func _inland_spot(world: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_clear: float = -1.0
	for region: int in _by_latitude(world, false):
		var reg: Dictionary = world.regions[region]
		var clear: float = _water_distance(world, float(reg.lat), float(reg.lon))
		if clear >= INLAND_CLEAR:
			return {"region": region, "lat": float(reg.lat), "lon": float(reg.lon), "clear": clear}
		if clear > best_clear:
			best_clear = clear
			best = {"region": region, "lat": float(reg.lat), "lon": float(reg.lon), "clear": clear}
	return best


## Regions within LATITUDE_LIMIT, coastal or inland, nearest the equator first.
func _by_latitude(world: Dictionary, coastal: bool) -> Array:
	var picked: Array = []
	for region: int in range(world.regions.size()):
		var reg: Dictionary = world.regions[region]
		if bool(reg.get("coast", false)) != coastal or absf(float(reg.lat)) > LATITUDE_LIMIT:
			continue
		picked.append(region)
	picked.sort_custom(
		func(a: int, b: int) -> bool:
			return absf(float(world.regions[a].lat)) < absf(float(world.regions[b].lat))
	)
	return picked


## Degrees to the nearest water on rings every half degree, up to eight.
func _water_distance(world: Dictionary, lat: float, lon: float) -> float:
	for ring: int in range(1, 17):
		var reach: float = ring * 0.5
		for index: int in range(24):
			var angle: float = TAU * index / 24.0
			var at: Vector2 = _offset(lat, lon, Vector2(cos(angle), sin(angle)), reach)
			if not _land(world, at.x, at.y):
				return reach
	return 8.0


## A point `reach` degrees from (lat, lon) along `way` (east, north).
func _offset(lat: float, lon: float, way: Vector2, reach: float) -> Vector2:
	var at_lat: float = clampf(lat + way.y * reach, -89.0, 89.0)
	var at_lon: float = wrapf(lon + way.x * reach / maxf(cos(deg_to_rad(lat)), 0.2), -180.0, 180.0)
	return Vector2(at_lat, at_lon)


## Land as the globe draws it: the geography atlas's height above sea level (shaders.gd
## `geo_height`), finer than the world's 2.5-degree grid.
func _land(_world: Dictionary, lat: float, lon: float) -> bool:
	var x: int = posmod(int(floor((lon + 180.0) / 360.0 * atlas.get_width())), atlas.get_width())
	var y: int = clampi(int((90.0 - lat) / 180.0 * atlas.get_height()), 0, atlas.get_height() - 1)
	return atlas.get_pixel(x, y).a > 0.5


## Place names, markers, the route overlay, the transport diagram, weather marks, cargo and ships:
## off, for clean frames.
func _show_overlays(on: bool) -> void:
	map.set_route_overlay(on)
	for label: Node in map.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = on
	for overlay: Variant in [
		map.get("transport_root"),
		map.get("marker_root"),
		map.get("weather_root"),
		map.get("mover_root"),
	]:
		if overlay is Node3D and is_instance_valid(overlay):
			(overlay as Node3D).visible = on
