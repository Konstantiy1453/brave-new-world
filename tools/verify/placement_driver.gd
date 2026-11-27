extends SceneTree
## Free placement through the game's real interface (1.10). Runs against the source project
## (`--path game`) or a packaged build (`--main-pack ColonyCharter.pck`), so it lives outside the
## project and loads the game's own scenes and scripts by path. It starts the game from the menu with
## the tutorial off, turns the globe or the flat map to a target, clicks with real mouse events,
## reads what the interface shows, founds through the ground panel and the naming dialog, saves with
## Ctrl+S, quits, starts the game again and continues from the menu, then reads the place back.
##
##   godot --main-pack <pck> --script <abs>/placement_driver.gd -- --case=capital --view=planet
##     --seed=3 --target=0 --out=<json> [--coast=1]
##
## Cases:
## - capital: founds the capital at the target-th of two eligible unmarked points in one generated
##   site's old area (the points lie on either side of its centre).
## - regression: seed 3, six clicks on unmarked land across both views, each selecting the ground
##   under the pointer; then founding the capital at the last one.
## - refusal: sea, polar and steep ground: the reason is shown, the button is off, nothing is founded.
## - outpost: a capital on picked ground, the colony played to the expansion licence (the balanced bot
##   through the simulation's own actions), then the expedition to picked inland (--coast=0) or
##   coastal (--coast=1) ground through the interface: departure town, route, cost, days, naming,
##   arrival, a building, a road, a save, a quit and a reload. With --save=<file> the colony comes
##   from a save on its licence day instead, loaded through the game's load path.

const MARKER_CLEARANCE_PX: float = 60.0
const OLD_PICK_RADIUS_PX: float = 43.0
## Each target is this far from its old site's centre and nearer to it than to any other site, so it
## lies in that site's old area; snapping to the centre would move it this far.
const AREA_DEGREES: Array[float] = [6.5, 6.0, 5.5]
const OTHER_SITE_MARGIN: float = 1.0
## The closest zoom a player can reach (`map_view.zoom` clamps the globe to 7.0-15.8, the flat map to
## 4.2-23.0): ground is inspected there.
const GLOBE_DISTANCE: float = 7.0
const FLAT_SIZE: float = 4.2
const SETTLE_FRAMES: int = 24

var options: Dictionary = {
	"case": "capital",
	"view": "planet",
	"seed": "3",
	"target": "0",
	"out": "",
	"coast": "0",
	"bots": "",
	"pck": "",
}
var game: Node
var record: Dictionary = {"checks": [], "ok": true}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	root.size = Vector2i(1920, 1080)
	record.options = options.duplicate()
	record.engine = Engine.get_version_info().string
	record.game_version = str(ProjectSettings.get_setting("application/config/version"))
	record.viewport = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	# Which build answered: the export leaves out `tests/`, so a packaged PCK has none of it. The
	# engine takes `--main-pack` for itself, so the run names its PCK again with `--pck=` for the record.
	record.res_has_tests = ResourceLoader.exists("res://tests/v110_placement.gd")
	record.build = "source project" if record.res_has_tests else "packaged PCK"
	if str(options.get("pck", "")) != "":
		record.pck = str(options.pck)
		record.pck_sha256 = FileAccess.get_sha256(str(options.pck))
	_watchdog(1500.0)
	call_deferred("run")


func _watchdog(seconds: float) -> void:
	var timer: SceneTreeTimer = create_timer(seconds)
	timer.timeout.connect(
		func():
			_check(false, "watchdog: the run did not finish in %.0f s" % seconds)
			_finish()
	)


## Loaded by path when needed: the driver runs against whichever build is mounted.
static func _main_scene() -> PackedScene:
	return load("res://" + "main.tscn")


static func _logistics() -> GDScript:
	return load("res://simulation/" + "logistics.gd")


func _check(ok: bool, label: String) -> void:
	record.checks.append({"ok": ok, "label": label})
	if not ok:
		record.ok = false
	printerr(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	await _boot()
	match str(options.case):
		"capital":
			await _capital()
		"regression":
			await _regression()
		"refusal":
			await _refusal()
		"outpost":
			await _outpost()
	_finish()


func _finish() -> void:
	var path: String = str(options.out)
	if path != "":
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	printerr("PLACEMENT_DRIVER_RESULT ok=%s checks=%d" % [str(record.ok), record.checks.size()])
	quit(0 if record.ok else 1)


## The game from its menu: the tutorial off, the seed typed, a new expedition started.
func _boot() -> void:
	game = _main_scene().instantiate()
	root.add_child(game)
	await _frames(4)
	if game.tutorial_on:
		await _press(game.find_child("TutorialToggle", true, false))
		await _frames(2)
	_check(not game.tutorial_on, "the menu's tutorial switch is off")
	var seed_edit: LineEdit = game.find_child("SeedEdit", true, false)
	seed_edit.text = str(options.seed)
	seed_edit.text_changed.emit(seed_edit.text)
	await _press(game.find_child("NewGame", true, false))
	await _frames(4)
	# The contract opens first; Esc closes it, as a player would.
	await _key(KEY_ESCAPE)
	await _frames(4)
	if is_instance_valid(game.overlay):
		game.close_modal()
		await _frames(2)
	while game.map.atlas_refining:
		await process_frame
	record.candidates = game.sim.state.world.candidates.size()
	record.seed = int(game.sim.state.world.seed)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _click(position: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = position
		event.global_position = position
		root.push_input(event)
		await process_frame


func _press(control: Control) -> void:
	if control == null:
		_check(false, "a control the step needs is on screen")
		return
	# A page taller than the window scrolls, as a person would scroll it (1.11: the menu's six
	# contract cards push its last buttons below a 720-pixel window).
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
			await _frames(2)
			break
		parent = parent.get_parent()
	await _click(control.get_global_rect().get_center())
	await _frames(2)


func _key(keycode: Key, ctrl: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.ctrl_pressed = ctrl
		event.pressed = down
		root.push_input(event)
		await process_frame


## Turns the map in `view` so that a coordinate is under the camera, zoomed in as a player would to
## inspect ground, and returns where it is on screen.
func _look_at(view: String, lat: float, lon: float) -> Vector2:
	var map: Node = game.map
	if game.map.mode != view:
		game.navigate(view)
		await _frames(2)
	# The player holds the globe still while inspecting it: the spin waits, as it does after a drag.
	map.sky.hold_spin()
	map.sky.spin_factor = 0.0
	if view == "flat":
		map.flat_user_zoomed = true
		map.flat_size = FLAT_SIZE
		map.flat_center = Vector2(lon / 20.0, lat / 20.0)
		map.camera.size = FLAT_SIZE
	else:
		map.focus_site = -1
		map.planet_distance = GLOBE_DISTANCE
		map.planet_pitch = clampf(deg_to_rad(lat), -1.2, 1.2)
		map.planet_yaw = deg_to_rad(lon) + map.sky.spin
		# Where a drag would have brought the camera to rest.
		map.smooth_yaw = map.planet_yaw
		map.smooth_pitch = map.planet_pitch
		map.smooth_distance = map.planet_distance
	await _frames(SETTLE_FRAMES)
	return _screen_of(view, lat, lon)


func _screen_of(view: String, lat: float, lon: float) -> Vector2:
	var map: Node = game.map
	var point: Vector3 = (
		map.flat_world.to_global(map._flat_point(lat, lon))
		if view == "flat"
		else map.planet.to_global(map.Geo.unit_point(lat, lon) * 3.0)
	)
	return map.camera.unproject_position(point)


## Pixels from a screen position to the nearest site marker the map shows.
func _nearest_marker_px(view: String, at: Vector2) -> float:
	var best: float = INF
	for reg: Dictionary in game.sim.state.world.regions:
		if not game.map._marker_shown(reg):
			continue
		var point: Vector3 = (
			game.map._flat_point(float(reg.lat), float(reg.lon))
			if view == "flat"
			else game.map.planet.to_global(game.map.Geo.unit_point(reg.lat, reg.lon) * 3.055)
		)
		if view == "planet":
			# As `map_view._region_at`: markers round the back of the globe cannot be clicked.
			if point.normalized().dot(game.map.camera.position.normalized()) < 0.18:
				continue
		if game.map.camera.is_position_behind(point):
			continue
		best = minf(best, game.map.camera.unproject_position(point).distance_to(at))
	return best


static func _parse_coordinates(text: String) -> Vector2:
	var regex := RegEx.new()
	regex.compile("(北纬|南纬)\\s*([0-9.]+)°\\s*·\\s*(东经|西经)\\s*([0-9.]+)°")
	var found: RegExMatch = regex.search(text)
	if found == null:
		return Vector2(INF, INF)
	var lat: float = float(found.get_string(2)) * (1.0 if found.get_string(1) == "北纬" else -1.0)
	var lon: float = float(found.get_string(4)) * (1.0 if found.get_string(3) == "东经" else -1.0)
	return Vector2(lat, lon)


## The days and the cost in the ground panel's route line.
static func _route_figures(text: String) -> Vector2:
	var regex := RegEx.new()
	regex.compile("单程\\s*([0-9]+)\\s*天.*远征费用\\s*¥\\s*([0-9]+)")
	var found: RegExMatch = regex.search(text)
	if found == null:
		return Vector2(-1.0, -1.0)
	return Vector2(float(found.get_string(1)), float(found.get_string(2)))


static func _degrees(a: Vector2, b: Vector2) -> float:
	var p: Vector3 = _unit(a.x, a.y)
	return rad_to_deg(p.angle_to(_unit(b.x, b.y)))


static func _unit(lat: float, lon: float) -> Vector3:
	var a: float = deg_to_rad(lat)
	var b: float = deg_to_rad(lon)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))


## Two eligible points on either side of one generated site, in its old area: `away` degrees from
## its centre, at least OTHER_SITE_MARGIN degrees nearer to it than to any other recommended site.
func _area_pair() -> Dictionary:
	for away: float in AREA_DEGREES:
		var pair: Dictionary = _area_pair_at(away)
		if not pair.is_empty():
			return pair
	return {}


func _area_pair_at(away: float) -> Dictionary:
	var sim: RefCounted = game.sim
	for reg: Dictionary in sim.state.world.regions:
		var points: Array = []
		for step: int in range(16):
			var angle: float = TAU * float(step) / 16.0
			var lat: float = float(reg.lat) + sin(angle) * away
			var lon: float = (
				float(reg.lon) + cos(angle) * away / maxf(0.3, cos(deg_to_rad(float(reg.lat))))
			)
			var view: Dictionary = sim.Placement.view(sim, lat, lon)
			if str(view.refusal) != "":
				continue
			var here := Vector2(float(view.lat), float(view.lon))
			var own: float = _degrees(here, Vector2(reg.lat, reg.lon))
			var clear: float = INF
			for other: Dictionary in sim.state.world.regions:
				if int(other.id) != int(reg.id):
					clear = minf(clear, _degrees(here, Vector2(other.lat, other.lon)))
			if clear < own + OTHER_SITE_MARGIN:
				continue
			(
				points
				. append(
					{
						"lat": here.x,
						"lon": here.y,
						"terrain": str(view.terrain),
						"coast": bool(view.coast),
						"own_site_degrees": own,
						"other_site_degrees": clear,
					}
				)
			)
		for i: int in range(points.size()):
			for j: int in range(i + 1, points.size()):
				var a := Vector2(points[i].lat, points[i].lon)
				var b := Vector2(points[j].lat, points[j].lon)
				if _degrees(a, b) >= away * 1.5:
					return {
						"site": int(reg.id),
						"site_name": str(reg.name),
						"centre": [float(reg.lat), float(reg.lon)],
						"away_degrees": away,
						"points": [points[i], points[j]],
					}
	return {}


## Clicks a target on a map; returns what the game took from the click.
func _pick(view: String, lat: float, lon: float) -> Dictionary:
	var screen: Vector2 = await _look_at(view, lat, lon)
	var clearance: float = _nearest_marker_px(view, screen)
	await _click(screen)
	await _frames(3)
	var picked: Dictionary = game.ground.duplicate()
	var shown: Label = game.find_child("GroundCoordinates", true, false)
	var verdict: Label = game.find_child("GroundVerdict", true, false)
	var terrain: Label = game.find_child("GroundTerrain", true, false)
	return {
		"target": [lat, lon],
		"screen": [screen.x, screen.y],
		"nearest_marker_px": clearance,
		"picked": picked,
		"panel_text": shown.text if shown != null else "",
		"verdict": verdict.text if verdict != null else "",
		"terrain_text": terrain.text if terrain != null else "",
		"selected_site_after_click": int(game.selected),
		"map_selected_marker": int(game.map.selected_region),
	}


## Founds on the picked ground through the button and the naming dialog; returns what it showed.
func _found(name: String) -> Dictionary:
	await _press(game.find_child("SettleGroundButton", true, false))
	await _frames(2)
	var naming: Label = game.find_child("GroundNamingCoordinates", true, false)
	var shown: String = naming.text if naming != null else ""
	var edit: LineEdit = game.modal_box.find_child("SiteNameEdit", true, false)
	if edit != null:
		edit.text = name
	await _press(game.modal_box.find_child("SiteNameConfirm", true, false))
	await _frames(4)
	return {"confirmation_text": shown, "confirmation": _parse_coordinates(shown)}


func _stored(region: int) -> Dictionary:
	var reg: Dictionary = game.sim.state.world.regions[region]
	return {"region": region, "lat": float(reg.lat), "lon": float(reg.lon), "name": str(reg.name)}


## Ctrl+S, the game freed, a new game process state from the menu's continue button.
func _save_quit_reload() -> void:
	await _key(KEY_S, true)
	await _frames(4)
	game.queue_free()
	await _frames(4)
	game = _main_scene().instantiate()
	root.add_child(game)
	await _frames(6)
	await _press(game.find_child("ContinueGame", true, false))
	await _frames(6)
	while game.map.atlas_refining:
		await process_frame


## Both maps and the district: the selection follows the town, the district is centred on it.
func _views_agree(region: int) -> Dictionary:
	var reg: Dictionary = game.sim.state.world.regions[region]
	var result: Dictionary = {}
	for view: String in ["planet", "flat"]:
		game.select_region(region)
		game.map.focus_region(region)
		await _look_at(view, float(reg.lat), float(reg.lon))
		var marker: Vector2 = _screen_of(view, float(reg.lat), float(reg.lon))
		result[view] = {
			"selected_marker": int(game.map.selected_region),
			"marker_screen": [marker.x, marker.y],
		}
	game.navigate("region")
	await _frames(4)
	while game.map.region_busy:
		await process_frame
	var shown: Dictionary = game.map.world.regions[int(game.map.selected_region)]
	result.district = {
		"region": int(game.map.selected_region),
		"lat": float(shown.get("canonical_lat", shown.lat)),
		"lon": float(shown.get("canonical_lon", shown.lon)),
	}
	game.navigate("planet")
	await _frames(2)
	return result


func _agrees(a: Vector2, b: Vector2, within: float) -> bool:
	return _degrees(a, b) <= within


func _capital() -> void:
	var pair: Dictionary = _area_pair()
	_check(not pair.is_empty(), "two eligible points in one generated site's old area")
	if pair.is_empty():
		return
	var target: Dictionary = pair.points[int(options.target)]
	record.area = pair
	var view: String = str(options.view)
	var pick: Dictionary = await _pick(view, float(target.lat), float(target.lon))
	record.pick = pick
	_check(
		float(pick.nearest_marker_px) >= MARKER_CLEARANCE_PX,
		(
			"the target is %.0f px from the nearest marker (old pick radius %.0f px)"
			% [pick.nearest_marker_px, OLD_PICK_RADIUS_PX]
		)
	)
	var picked: Dictionary = pick.picked
	_check(not picked.is_empty(), "the click selected the ground under the pointer")
	if picked.is_empty():
		return
	var clicked := Vector2(float(picked.lat), float(picked.lon))
	var precision: float = maxf(float(picked.precision), 0.0001)
	_check(
		_agrees(clicked, Vector2(target.lat, target.lon), precision * 2.0),
		"at the target: %.4f, %.4f (precision ±%.3f°)" % [clicked.x, clicked.y, precision]
	)
	_check(int(pick.map_selected_marker) == -1, "and no site marker stays selected")
	var founded: Dictionary = await _found("自选首都")
	record.found = founded
	var capital: Dictionary = (
		game.sim.state.settlements[0] if not game.sim.state.settlements.is_empty() else {}
	)
	_check(not capital.is_empty(), "the capital is founded")
	if capital.is_empty():
		return
	var stored: Dictionary = _stored(int(capital.region))
	record.stored = stored
	_check(
		int(capital.region) >= int(record.candidates),
		"on a site of its own, not Site %02d" % (int(pair.site) + 1)
	)
	_check(
		_agrees(founded.confirmation, Vector2(stored.lat, stored.lon), 0.006),
		"the naming dialog showed the stored place: %s" % founded.confirmation_text
	)
	_check(
		_agrees(clicked, Vector2(stored.lat, stored.lon), precision),
		"stored where clicked: %.4f, %.4f" % [stored.lat, stored.lon]
	)
	_check(
		(
			_degrees(Vector2(stored.lat, stored.lon), Vector2(pair.centre[0], pair.centre[1]))
			> float(pair.away_degrees) * 0.5
		),
		(
			"not snapped to the old site's centre (%.1f° away)"
			% _degrees(Vector2(stored.lat, stored.lon), Vector2(pair.centre[0], pair.centre[1]))
		)
	)
	record.views = await _views_agree(int(capital.region))
	_check(
		(
			int(record.views.district.region) == int(capital.region)
			and _agrees(
				Vector2(record.views.district.lat, record.views.district.lon),
				Vector2(stored.lat, stored.lon),
				0.0001
			)
		),
		"the district opens on the same place"
	)
	await _save_quit_reload()
	var again: Dictionary = (
		game.sim.state.settlements[0] if not game.sim.state.settlements.is_empty() else {}
	)
	_check(not again.is_empty(), "the save continues from the menu")
	if again.is_empty():
		return
	var reloaded: Dictionary = _stored(int(again.region))
	record.reloaded = reloaded
	_check(
		(
			int(reloaded.region) == int(stored.region)
			and _agrees(
				Vector2(reloaded.lat, reloaded.lon), Vector2(stored.lat, stored.lon), 0.0001
			)
			and str(again.name) == "自选首都"
		),
		(
			"after save, quit and reload the capital is where it was: %.4f, %.4f"
			% [reloaded.lat, reloaded.lon]
		)
	)


## Seed 3: six clicks on unmarked forest, grassland and tundra, alternating the globe and the flat
## map, each selecting its own ground; founding then uses the last click, not Site 01.
func _regression() -> void:
	var sim: RefCounted = game.sim
	var wanted: Dictionary = {"forest": 2, "grassland": 2, "tundra": 2}
	var targets: Array = []
	var width: int = int(sim.geo.grid_width)
	for index: int in range(0, sim.geo.grid.size(), 3):
		if targets.size() >= 6:
			break
		var lat: float = 90.0 - (float(index / width) + 0.4) * 2.5
		var lon: float = (float(index % width) + 0.6) * 2.5 - 180.0
		var view: Dictionary = sim.Placement.view(sim, lat, lon)
		var cover: String = str(view.biome)
		if cover == "steppe":
			cover = "grassland"
		if str(view.refusal) != "" or int(wanted.get(cover, 0)) <= 0:
			continue
		var clear: float = INF
		for reg: Dictionary in sim.state.world.regions:
			clear = minf(clear, _degrees(Vector2(lat, lon), Vector2(reg.lat, reg.lon)))
		for other: Dictionary in targets:
			clear = minf(clear, _degrees(Vector2(lat, lon), Vector2(other.lat, other.lon)) * 2.0)
		if clear < 6.5:
			continue
		wanted[cover] = int(wanted[cover]) - 1
		(
			targets
			. append(
				{
					"lat": float(view.lat),
					"lon": float(view.lon),
					"biome": str(view.biome),
					"terrain": str(view.terrain),
					"site_degrees": clear,
				}
			)
		)
	# Alternate the kinds so each view sees each kind of land.
	targets.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a.biome) < str(b.biome)
	)
	record.targets = targets
	_check(
		targets.size() == 6,
		"six unmarked targets: %s" % ", ".join(targets.map(func(t): return t.biome))
	)
	var picks: Array = []
	for at: int in range(targets.size()):
		var view: String = "planet" if at % 2 == 0 else "flat"
		var pick: Dictionary = await _pick(view, float(targets[at].lat), float(targets[at].lon))
		pick.view = view
		picks.append(pick)
		var picked: Dictionary = pick.picked
		var precision: float = maxf(float(picked.get("precision", 0.0)), 0.0001)
		_check(
			float(pick.nearest_marker_px) >= MARKER_CLEARANCE_PX,
			"click %d is %.0f px from the nearest marker" % [at + 1, pick.nearest_marker_px]
		)
		_check(
			(
				not picked.is_empty()
				and _agrees(
					Vector2(picked.lat, picked.lon),
					Vector2(targets[at].lat, targets[at].lon),
					precision * 2.0
				)
				and int(pick.map_selected_marker) == -1
			),
			(
				"click %d on the %s (%s) selects that ground: %s · %s"
				% [at + 1, view, targets[at].biome, pick.panel_text, pick.terrain_text]
			)
		)
	record.picks = picks
	var founded: Dictionary = await _found("回归首都")
	record.found = founded
	var capital: Dictionary = (
		game.sim.state.settlements[0] if not game.sim.state.settlements.is_empty() else {}
	)
	_check(not capital.is_empty(), "the capital is founded")
	if capital.is_empty():
		return
	var stored: Dictionary = _stored(int(capital.region))
	record.stored = stored
	var last: Dictionary = picks.back().picked
	_check(
		(
			int(capital.region) >= int(record.candidates)
			and _agrees(
				Vector2(stored.lat, stored.lon),
				Vector2(last.lat, last.lon),
				maxf(float(last.precision), 0.0001)
			)
		),
		(
			"founded at the last click (%.4f, %.4f), not Site 01 (%.2f, %.2f)"
			% [
				stored.lat,
				stored.lon,
				game.sim.state.world.regions[0].lat,
				game.sim.state.world.regions[0].lon
			]
		)
	)


## Sea, polar and steep ground: the reason shows, the button is off, nothing is founded.
func _refusal() -> void:
	var sim: RefCounted = game.sim
	var cases: Array = [
		["海面", func(v: Dictionary) -> bool: return not bool(v.land)],
		["极地", func(v: Dictionary) -> bool: return bool(v.land) and absf(float(v.lat)) > 76.0],
		["地势太陡", func(v: Dictionary) -> bool: return str(v.refusal).begins_with("地势太陡")],
	]
	var width: int = int(sim.geo.grid_width)
	record.refusals = []
	for case: Array in cases:
		var point: Array = []
		for index: int in range(sim.geo.grid.size()):
			var lat: float = 90.0 - (float(index / width) + 0.5) * 2.5
			if absf(lat) > 80.0:
				continue
			var lon: float = (float(index % width) + 0.5) * 2.5 - 180.0
			var view: Dictionary = sim.Placement.view(sim, lat, lon)
			if case[1].call(view):
				point = [lat, lon]
				break
		_check(not point.is_empty(), "ground for the %s case" % case[0])
		if point.is_empty():
			continue
		var pick: Dictionary = await _pick("planet", point[0], point[1])
		var button: Button = game.find_child("SettleGroundButton", true, false)
		var disabled: bool = button != null and button.disabled
		await _press(button)
		await _frames(2)
		var founded: bool = not game.sim.state.settlements.is_empty()
		record.refusals.append(
			{"case": case[0], "pick": pick, "button_disabled": disabled, "founded": founded}
		)
		_check(
			str(pick.verdict).contains(case[0]) and disabled and not founded,
			"%s: the panel says %s, the button is off, nothing is founded" % [case[0], pick.verdict]
		)


## A capital on picked ground, the colony played to the expansion licence, then an expedition to
## picked ground through the interface.
func _outpost() -> void:
	var sim: RefCounted = game.sim
	if str(options.get("save", "")) != "":
		# From a save that holds the licence (`--save`), loaded through the game's own load path
		# (1.12: CC-GEO-2.3 seed 3's picked capital has no deposit the bot can export from, so it
		# never earns the licence; the save is a bot-played colony on its first licence day).
		game.load_path(str(options.save))
		await _frames(6)
		while game.map.atlas_refining:
			await process_frame
		sim = game.sim
		record.played_by = "save %s (balanced bot through Sim.act)" % str(options.save).get_file()
	else:
		var pair: Dictionary = _area_pair()
		var start: Dictionary = pair.points[0]
		await _pick("planet", float(start.lat), float(start.lon))
		await _found("远征首都")
		sim = game.sim
	var capital: Dictionary = (
		sim.state.settlements[0] if not sim.state.settlements.is_empty() else {}
	)
	_check(
		not capital.is_empty(),
		(
			"the capital is founded on picked ground"
			if str(options.get("save", "")) == ""
			else "the saved colony's capital is loaded: %s" % str(capital.get("name", ""))
		)
	)
	if capital.is_empty():
		return
	var capital_region: int = int(capital.region)
	record.capital = _stored(capital_region)
	record.capital_name = str(capital.name)
	if str(options.get("save", "")) == "":
		# The colony is played to the expansion licence by the balance harness's balanced bot,
		# through the simulation's own actions (`Sim.act`), the ones the interface's buttons call.
		var bot: RefCounted = _bot()
		_check(
			bot != null, "the balanced bot is loaded to play the colony to the expansion licence"
		)
		if bot == null:
			return
		bot.begin(sim, int(options.seed))
		while not sim.state.contract.licences.has("expedition") and int(sim.state.day) < 900:
			bot.on_day()
			sim.tick()
		record.played_by = (
			"balanced bot (tests/balance/bots) through Sim.act, days 1-%d" % int(sim.state.day)
		)
	record.unlock_day = int(sim.state.day)
	record.towns_at_unlock = sim.state.settlements.size()
	_check(
		sim.state.contract.licences.has("expedition") and sim.state.settlements.size() == 1,
		"the expansion licence came on day %d, with the capital the only town" % int(sim.state.day)
	)
	if not sim.state.contract.licences.has("expedition"):
		return
	game.map.sync_state(sim.state)
	game.refresh()
	await _close_popups()
	var coastal: bool = str(options.coast) == "1"
	var target: Dictionary = _expedition_target(capital_region, coastal)
	record.target = target
	_check(
		not target.is_empty(),
		"eligible %s ground an expedition can reach" % ("coastal" if coastal else "inland")
	)
	if target.is_empty():
		return
	var view: String = str(options.view)
	var pick: Dictionary = await _pick(view, float(target.lat), float(target.lon))
	record.pick = pick
	_check(
		not pick.picked.is_empty(),
		(
			"the click on the %s selected the ground (%s · %s)"
			% [view, pick.panel_text, pick.terrain_text]
		)
	)
	if pick.picked.is_empty():
		return
	_check(
		float(pick.nearest_marker_px) >= MARKER_CLEARANCE_PX,
		"the target is %.0f px from the nearest marker" % pick.nearest_marker_px
	)
	var picker: OptionButton = game.find_child("GroundDeparture", true, false)
	_check(picker != null, "the departure town can be chosen")
	if picker != null:
		for index: int in range(picker.item_count):
			if picker.get_item_text(index) == str(capital.name):
				picker.select(index)
				picker.item_selected.emit(index)
		await _frames(3)
	var route_label: Label = game.find_child("GroundRoute", true, false)
	record.route_text = route_label.text if route_label != null else ""
	var verdict: Label = game.find_child("GroundVerdict", true, false)
	record.verdict = verdict.text if verdict != null else ""
	var quote: Dictionary = sim.Placement.view(
		sim, float(pick.picked.lat), float(pick.picked.lon), capital_region, "frontier"
	)
	record.quote = {
		"from": int(quote.from),
		"variant": str(quote.route.get("variant", "")),
		"km": float(quote.route.get("distance", 0.0)),
		"days": int(quote.route.get("days", 0)),
		"cost": float(quote.cost),
		"route_end": quote.route.get("coordinates", [[0, 0]]).back(),
	}
	_check(
		str(record.route_text).contains(str(capital.name)) and str(record.route_text).contains("天"),
		"the route, its days and the cost are shown: " + str(record.route_text)
	)
	var regions: int = sim.state.world.regions.size()
	var cash_before: float = float(sim.state.cash)
	var founded: Dictionary = await _found("自选远征镇")
	record.found = founded
	_check(
		sim.state.world.regions.size() == regions + 1, "the expedition left for a site of its own"
	)
	if sim.state.world.regions.size() != regions + 1:
		return
	var town: Dictionary = sim.state.settlements.back()
	var stored: Dictionary = _stored(int(town.region))
	record.stored = stored
	record.cash_spent = cash_before - float(sim.state.cash)
	record.arrival_days = int(town.arrival)
	var clicked := Vector2(float(pick.picked.lat), float(pick.picked.lon))
	_check(
		_agrees(
			clicked, Vector2(stored.lat, stored.lon), maxf(float(pick.picked.precision), 0.0001)
		),
		"stored where clicked: %.4f, %.4f" % [stored.lat, stored.lon]
	)
	_check(
		_agrees(founded.confirmation, Vector2(stored.lat, stored.lon), 0.006),
		"the naming dialog showed the stored place: " + str(founded.confirmation_text)
	)
	_check(
		(
			int(town.arrival) == int(record.quote.days)
			and absf(float(record.cash_spent) - float(record.quote.cost)) < 0.5
		),
		(
			"it takes the quoted %d days (arrival in %d) and costs the quoted ¥ %.0f (spent ¥ %.0f)"
			% [record.quote.days, int(town.arrival), record.quote.cost, record.cash_spent]
		)
	)
	var shown: Vector2 = _route_figures(str(record.route_text))
	record.shown_days = shown.x
	record.shown_cost = shown.y
	_check(
		int(shown.x) == int(town.arrival) and absf(shown.y - float(record.cash_spent)) < 1.0,
		(
			"the panel's own figures (%d days, ¥ %.0f) are what the expedition took"
			% [shown.x, shown.y]
		)
	)
	var convoy: Dictionary = _logistics().route_between(
		sim, capital_region, int(town.region), str(record.quote.variant)
	)
	record.convoy_route_end = convoy.get("coordinates", [[0, 0]]).back()
	var quoted_end := Vector2(record.quote.route_end[0], record.quote.route_end[1])
	var convoy_end := Vector2(record.convoy_route_end[0], record.convoy_route_end[1])
	_check(
		(
			_agrees(quoted_end, Vector2(stored.lat, stored.lon), 0.0001)
			and _agrees(convoy_end, Vector2(stored.lat, stored.lon), 0.0001)
		),
		"the quoted route and the convoy's route end at the town"
	)
	for _day: int in range(int(town.arrival) + 2):
		sim.tick()
	game.map.sync_state(sim.state)
	game.refresh()
	await _close_popups()
	_check(int(town.arrival) <= 0, "the expedition arrived as 「%s」" % town.name)
	var kind: String = await _build_something(int(town.region))
	record.built = kind
	_check(kind != "", "a building is ordered there through the build page: %s" % kind)
	record.views = await _views_agree(int(town.region))
	var district := Vector2(record.views.district.lat, record.views.district.lon)
	_check(
		(
			int(record.views.district.region) == int(town.region)
			and _agrees(district, Vector2(stored.lat, stored.lon), 0.0001)
		),
		"both maps select the town and the district opens on the same place"
	)
	await _save_quit_reload()
	sim = game.sim
	var after: Dictionary = {}
	var kept_capital: Dictionary = {}
	for s: Dictionary in sim.state.settlements:
		if int(s.region) == int(town.region):
			after = s
		if int(s.region) == capital_region:
			kept_capital = s
	_check(
		not after.is_empty() and not kept_capital.is_empty(), "both towns continue from the menu"
	)
	if after.is_empty() or kept_capital.is_empty():
		return
	var reloaded: Dictionary = _stored(int(after.region))
	record.reloaded = reloaded
	var still_built: bool = false
	for b: Dictionary in after.buildings:
		still_built = still_built or str(b.kind) == kind
	_check(
		(
			_agrees(Vector2(reloaded.lat, reloaded.lon), Vector2(stored.lat, stored.lon), 0.0001)
			and str(after.name) == "自选远征镇"
			and still_built
		),
		(
			"after save, quit and reload: 「%s」 at %.4f, %.4f with its %s"
			% [after.name, reloaded.lat, reloaded.lon, kind]
		)
	)
	var convoy_after: Dictionary = _logistics().route_between(
		sim, capital_region, int(after.region), str(record.quote.variant)
	)
	var end_after: Array = convoy_after.get("coordinates", [[0, 0]]).back()
	_check(
		_agrees(Vector2(end_after[0], end_after[1]), Vector2(stored.lat, stored.lon), 0.0001),
		"the route still ends at the town after the reload"
	)
	record.capital_after = _stored(capital_region)
	var capital_was := Vector2(record.capital.lat, record.capital.lon)
	var capital_now := Vector2(record.capital_after.lat, record.capital_after.lon)
	_check(
		(
			str(kept_capital.name) == str(record.capital_name)
			and int(sim.state.settlements[0].region) == capital_region
			and _agrees(capital_now, capital_was, 0.0001)
		),
		"the original capital is still the capital, where it was"
	)


## The balanced bot from the source project, or from `--bots=<dir>` (a copy whose `extends` lines
## point at absolute paths) when the packaged build, which ships without tests, is driven.
func _bot() -> RefCounted:
	var path: String = "res://tests/balance/bots/balanced_bot.gd"
	if str(options.get("bots", "")) != "":
		path = str(options.bots).path_join("balanced_bot.gd")
	elif not ResourceLoader.exists(path):
		return null
	var script: GDScript = load(path)
	return script.new() if script != null else null


## Closes whatever window the game opened (events, notices) with Esc, as a player would.
func _close_popups() -> void:
	for _i: int in range(6):
		if not is_instance_valid(game.overlay) or not game.overlay.visible:
			return
		await _key(KEY_ESCAPE)
		await _frames(2)


## Orders the first building the town's build page offers, by its 「建设」 button.
func _build_something(region: int) -> String:
	game.select_region(region)
	game.open_page("build")
	await _frames(4)
	for kind: String in [
		"habitat", "frontier_lodge", "farm", "water", "power", "mine_ore", "depot"
	]:
		var button: Button = game.find_child("Build_" + kind, true, false)
		if button == null or button.disabled or not button.is_visible_in_tree():
			continue
		var scroll: ScrollContainer = _scroll_of(button)
		if scroll != null:
			scroll.ensure_control_visible(button)
			await _frames(3)
		var before: int = game.sim.settlement(region).buildings.size()
		await _press(button)
		await _frames(2)
		if game.sim.settlement(region).buildings.size() > before:
			await _close_popups()
			return kind
	await _close_popups()
	return ""


func _scroll_of(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null


## Eligible ground 9-18 degrees from the capital, inland or coastal, an expedition from it can reach.
func _expedition_target(capital_region: int, coastal: bool) -> Dictionary:
	var sim: RefCounted = game.sim
	var home: Dictionary = sim.state.world.regions[capital_region]
	for ring: float in [9.0, 11.0, 13.0, 15.0, 18.0]:
		for step: int in range(24):
			var angle: float = TAU * float(step) / 24.0
			var lat: float = float(home.lat) + sin(angle) * ring
			var lon: float = float(home.lon) + cos(angle) * ring
			var view: Dictionary = sim.Placement.view(sim, lat, lon, capital_region, "frontier")
			if str(view.refusal) != "" or bool(view.coast) != coastal:
				continue
			var far: bool = true
			for reg: Dictionary in sim.state.world.regions:
				far = far and _degrees(Vector2(lat, lon), Vector2(reg.lat, reg.lon)) > 4.0
			if far:
				return {
					"lat": float(view.lat),
					"lon": float(view.lon),
					"terrain": str(view.terrain),
					"coast": coastal
				}
	return {}
