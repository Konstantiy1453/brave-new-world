extends "res://world/planet_view.gd"
## Native lightweight 3D renderer: owns the camera, the view mode and input.

const SUN_ROTATION: Vector3 = Vector3(-26, -46, 0)
const DAY_AMBIENT: Color = Color("8aacbe")
const NIGHT_AMBIENT: Color = Color("4a6a96")
const DAY_SKY: Color = Color("080f1c")
const NIGHT_SKY: Color = Color("03070f")
## Deep space on the globe: the dome's radius, and the star's distance and size (scene units).
const SPACE_RADIUS: float = 320.0
const STAR_DISTANCE: float = 200.0
const STAR_SIZE: float = 170.0
const SPACE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;
uniform bool optical_sky = false;
uniform vec3 band_normal = vec3(0.32, 0.86, 0.40);
varying vec3 dir;
void vertex() {
	dir = normalize(VERTEX);
}
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec3 d = normalize(dir);
	float h = dot(d, normalize(band_normal));
	float band = exp(-h * h / 0.03);
	float n = fbm(d * 3.0);
	float fine = fbm(d * 9.0 + 4.0);
	float dust = smoothstep(0.47, 0.75, fbm(d * 6.0 + 11.0)) * band;
	vec3 col = vec3(0.010, 0.018, 0.040);
	col += vec3(0.09, 0.13, 0.23) * band * (0.5 + 0.9 * n);
	col += vec3(0.20, 0.22, 0.29) * pow(band, 3.0) * fine;
	col *= 1.0 - dust * 0.7;
	col += vec3(0.03, 0.09, 0.15) * smoothstep(0.52, 0.86, fbm(d * 2.2 + 7.0));
	col += vec3(0.09, 0.03, 0.13) * smoothstep(0.56, 0.9, fbm(d * 2.6 - 3.0));
	vec3 cell = floor(d * 720.0);
	float s = hash(cell);
	float star = step(0.9972, s) * (0.3 + 0.7 * hash(cell + 3.1));
	star += step(0.990, s) * band * 0.35;
	col += vec3(0.72, 0.80, 1.0) * star * 0.55;
	if (optical_sky) {
		col = col * 0.64 + vec3(0.002, 0.005, 0.013);
		if (!OUTPUT_IS_SRGB) { col = pow(col, vec3(2.2)); }
	}
	ALBEDO = col;
}
"""
## The air over a generated region: the horizon colour by day, at dusk and at night, and the haze
## that hides the landscape's far edge: it begins and is complete this far from the eye.
## A generated region's daylight ambient (1.12): the approved district's sky fill.
const REGION_DAY_AMBIENT: Color = Color("b6c9de")
const REGION_AMBIENT_ENERGY: float = 0.58
const REGION_DAY_AIR: Color = Color("9cadbb")
## The evening haze and sky of the approved district (1.12, region/preview.gd `set_hour`), the
## day's and night's sky overhead, and the exposure a generated region is drawn at.
const REGION_EVENING_AIR: Color = Color("a9a5ad")
const REGION_SKY_DAY: Color = Color("4e6f98")
const REGION_SKY_EVENING: Color = Color("435b85")
const REGION_SKY_NIGHT: Color = Color("04070e")
const REGION_EXPOSURE: float = 1.02
const REGION_DUSK_AIR: Color = Color("8a6b5b")
const REGION_NIGHT_AIR: Color = Color("070b13")
const REGION_HAZE: Vector2 = Vector2(150.0, 430.0)
## The town view's near clip plane. Its camera orbits 31 units or more from its pivot and at least
## 7 units above it, so nothing comes this close; the depth buffer is ten times finer than with the
## globe's 0.05, and ground and water no longer flicker where they meet.
const REGION_NEAR: float = 0.5
## The district camera (1.12): it comes down to about 17 m from its target for the ground's
## close view, its near plane and side offset scaling with its distance; the default view keeps
## its 1.11 framing.
const REGION_CLOSEST: float = 1.0
const REGION_FARTHEST: float = 140.0
const REGION_ZOOM_STEP: float = 1.12
const REGION_LOWEST_PITCH: float = 0.08
const REGION_OFFSET_DISTANCE: float = 67.0
const SUN_ENERGY: float = 1.12
## Pixels around a marker that a hover shows its name for (and a click picked before 1.10).
const HOVER_RADIUS: float = 43.0
## The planet sphere's radius and the flat map's surface plane, as the maps draw them.
const GLOBE_RADIUS: float = 3.0
const FLAT_SURFACE_Z: float = 0.035
## Forward+ (高画质) tuning. Colour grade (brightness, contrast, saturation) that brings Forward+
## to the Compatibility palette; ambient occlusion in the town (radius in units, intensity,
## power); glow (intensity, bloom, HDR threshold); how far shadow edges soften.
const HQ_GRADE: Vector3 = Vector3(0.92, 1.12, 1.38)
const HQ_AO: Vector3 = Vector3(1.2, 1.6, 1.5)
const HQ_GLOW: Vector3 = Vector3(0.4, 0.0, 1.6)
const HQ_SHADOW_BLUR: float = 1.3

const Timelapse = preload("res://world/timelapse.gd")
## The globe's default distance, where the time-lapse watches the colony from.
const TIMELAPSE_DISTANCE: float = 10.3
## The night time-lapse (1.11 G): {snapshots, seconds, elapsed, day, capital}; empty when none plays.
var timelapse: Dictionary = {}
var environment: Environment
var fill_light: DirectionalLight3D
## A generated region's sky (`_region_air`).
var region_sky: ProceduralSkyMaterial
var star_field: MultiMeshInstance3D
## Deep space behind the globe (1.10.1): a dome far beyond the stars with the galaxy's band, dust
## lanes and faint nebulae, and the planet's own star, a large glare in the sun's real direction.
## The planet hides the star when it stands in front, so it shows as the globe is turned towards it.
var space_dome: MeshInstance3D
var star_glare: MeshInstance3D
## A site the camera keeps in view while the spin eases out after a click.
var focus_site: int = -1
## 0 by full day, 1 by full night, at the selected site: lamps and windows read this.
var region_night: float = 0.0


func _ready() -> void:
	set_process(true)
	label_font = load("res://assets/fonts/main_medium.ttf")
	_build_environment()


func setup(data: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	cancel_region_load()
	for entry in region_cache.values():
		if entry.surface != surface:
			_clear_node(entry.surface)
	region_cache.clear()
	camp_cache.clear()
	harbor_cache.clear()
	selected_region = 0
	signature = ""
	marker_signature = ""
	transport_signature = ""
	height_field = PackedFloat32Array()
	forest_field = PackedFloat32Array()
	marker_filter = "all"
	hovered_region = -1
	world = data
	if space_dome != null:
		(space_dome.material_override as ShaderMaterial).set_shader_parameter(
			"optical_sky", _uses_optical_geography()
		)
	flat_user_zoomed = false
	flat_center = Vector2.ZERO
	noise = FastNoiseLite.new()
	noise.seed = int(world.seed)
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	if camera == null:
		_build_environment()
	_clear_node(planet)
	_clear_node(surface)
	_clear_node(flat_world)
	flat_marker_root = null
	flat_transport_root = null
	flat_mover_root = null
	planet = Node3D.new()
	planet.name = "AuthoritativePlanet"
	add_child(planet)
	surface = Node3D.new()
	surface.name = "RegionalSurface"
	add_child(surface)
	flat_world = Node3D.new()
	flat_world.name = "AuthoritativeFlatWorld"
	add_child(flat_world)
	_prepare_render_rivers()
	# Seeded worlds rotate their continents; start over the actual main province.
	if str(world.version) != "CC-GEO-1.4" and not world.regions.is_empty():
		planet_yaw = deg_to_rad(float(world.regions[0].lon))
		planet_pitch = deg_to_rad(float(world.regions[0].lat))
	sky.reset(int(world.seed), planet_yaw)
	focus_site = -1
	lights_signature = ""
	globe_movers.clear()
	flat_movers.clear()
	globe_ships.clear()
	flat_ships.clear()
	_build_planet()
	_build_flat()
	show_planet()
	last_setup_ms = Time.get_ticks_msec() - started
	print(
		"MAP_SETUP ms=", last_setup_ms, " atlas_ms=", last_atlas_ms, " cached=", last_atlas_cached
	)


func sync_state(data: Dictionary) -> void:
	state = data
	if world.is_empty():
		return
	var stages: float = float(_terraforming_stages())
	for material: ShaderMaterial in [globe_shader, flat_shader]:
		if material != null:
			material.set_shader_parameter("terraform", stages)
	var markers_now: String = _marker_signature()
	if markers_now != marker_signature:
		marker_signature = markers_now
		_update_markers()
	var transport_now: String = _transport_signature()
	if transport_now != transport_signature:
		transport_signature = transport_now
		_update_transport()
	# New night lights repaint the town forms too (planet_view `_update_night_lights`).
	var lights_now: String = _lights_signature()
	var forms_now: String = _forms_signature()
	if lights_now != lights_signature:
		lights_signature = lights_now
		forms_signature = forms_now
		_update_night_lights()
	elif forms_now != forms_signature and timelapse.is_empty():
		forms_signature = forms_now
		_update_town_forms()
	_follow_weather()
	if mode == "region" and not region_busy:
		var new_signature := _building_signature()
		if new_signature != signature:
			signature = new_signature
			_build_colony()
			surface.set_meta("building_signature", signature)


func _marker_signature() -> String:
	var settled: Array = []
	for place: Dictionary in state.get("settlements", []):
		var farms: int = 0
		for building: Dictionary in place.get("buildings", []):
			if str(building.kind) == "farm":
				farms += 1
		settled.append(
			[
				int(place.region),
				place.get("buildings", []).size(),
				farms,
				str(place.get("name", ""))
			]
		)
	var signals: Array = []
	for place: Dictionary in state.get("settlements", []):
		signals.append(not signal_reading(int(place.region)).is_empty())
	# Prospecting anomalies are drawn as rings: their stages and zones change what is shown.
	for anomaly: Dictionary in state.get("prospecting", {}).get("anomalies", []):
		signals.append([int(anomaly.id), str(anomaly.stage), snappedf(float(anomaly.zone), 0.01)])
	return (
		"%d|%s|%s|%s|%s"
		% [selected_region, str(settled), marker_filter, str(_event_places()), str(signals)]
	)


## Towns and lit roads change the night side; a few dozen people more do not.
func _lights_signature() -> String:
	return LightField.signature(state, Rules.read("economy").buildings)


## The planet-scale forms grow with each town's people between its light stages (1.11 G).
func _forms_signature() -> String:
	var towns: Array = TownForms.towns_now(state, world, Rules.read("economy").buildings)
	return TownForms.signature(towns, Rules.read("progression").get("lights", {}))


func _transport_signature() -> String:
	var roads: Array = []
	for road: Dictionary in state.get("roads", []):
		roads.append([int(road.get("id", 0)), Geo.road_blocked(road, int(state.get("day", 0)))])
	var moving: Array = []
	for cargo: Dictionary in state.get("shipments", []):
		moving.append([int(cargo.from), int(cargo.remaining), int(cargo.total_days)])
	# A quay that starts work, and then its first cargo, bring its ship light.
	var quays: Array = []
	var economy: Dictionary = Rules.read("economy")
	var calls: int = int(economy.get("bay", {}).get("ship_call_days", 30))
	for place: Dictionary in state.get("settlements", []):
		quays.append(LightField.quay_working(state, place, economy.buildings))
		quays.append(Consignments.ship_calling(state, place, calls))
	# The company's annual ship: coming down, waiting for the report, gone (1.11 D).
	var annual: Dictionary = state.get("annual", {})
	var due: int = int(annual.get("next_ship", -1)) - int(state.get("day", 0))
	quays.append(
		[
			not annual.get("pending", {}).is_empty(),
			due >= 0 and due <= int(COMPANY_SHIP_DESCENT_DAYS),
			int(annual.get("next_ship", -1))
		]
	)
	return "%s|%s|%s" % [str(roads), str(moving), str(quays)]


func show_planet() -> void:
	cancel_region_load()
	mode = "planet"
	if planet == null:
		return
	_update_markers()
	_update_transport()
	planet.visible = true
	surface.visible = false
	flat_world.visible = false
	smooth_yaw = planet_yaw
	smooth_pitch = planet_pitch
	smooth_distance = planet_distance
	camera_pivot = Vector3.ZERO
	camera.fov = 43
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.near = .05
	camera.far = 700
	_update_camera(1.0)
	_apply_mode_quality()


func show_flat() -> void:
	cancel_region_load()
	if world.is_empty() or flat_world == null:
		return
	mode = "flat"
	planet.visible = false
	surface.visible = false
	flat_world.visible = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = .05
	camera.far = 700
	_update_camera(1.0)
	_update_flat_markers()
	_update_flat_transport()
	_apply_mode_quality()


func cancel_region_load() -> void:
	region_load_token += 1
	if region_busy:
		region_busy = false
		region_progress.emit(false, 0.0)


func show_region(id: int) -> void:
	if world.is_empty() or id < 0 or id >= world.regions.size():
		return
	if region_busy and selected_region == id:
		return
	cancel_region_load()
	_fit_field()
	var started: int = Time.get_ticks_msec()
	var token: int = region_load_token
	selected_region = id
	mode = "region"
	_apply_mode_quality()
	planet.visible = false
	flat_world.visible = false
	surface.visible = false
	var old_cached: bool = false
	for entry in region_cache.values():
		if entry.surface == surface:
			old_cached = true
	if not old_cached:
		_clear_node(surface)
	if region_cache.has(id) and str(region_cache[id].get("terraces", "")) != terrace_signature(id):
		# A plot has come to light since this ground was cut: cut it again with its terrace.
		_clear_node(region_cache[id].surface)
		region_cache.erase(id)
	last_region_cached = region_cache.has(id)
	if last_region_cached:
		var entry: Dictionary = region_cache[id]
		# Touch for bounded least-recently-used retention.
		region_cache.erase(id)
		region_cache[id] = entry
		surface = entry.surface
		region_ground = entry.ground
		local_river_segments = entry.rivers.duplicate(true)
		local_lakes = entry.lakes.duplicate(true)
		height_field = entry.heights
		forest_field = entry.forests
		climate_field = entry.get("climate", PackedVector2Array())
	else:
		surface = Node3D.new()
		surface.name = "RegionalSurface_" + str(id)
		add_child(surface)
		surface.visible = false
	buildings_root = surface.get_node_or_null("LiveSettlementBuildings")
	smooth_yaw = local_yaw
	smooth_pitch = local_pitch
	smooth_distance = local_distance
	camera_pivot = Vector3.ZERO
	camera.fov = 43
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.near = REGION_NEAR
	camera.far = 700
	_update_camera(1.0)
	if not last_region_cached:
		region_busy = true
		region_progress.emit(true, 0.0)
		# Yield before work: feedback can be drawn and navigation can cancel.
		await get_tree().process_frame
		if token != region_load_token:
			return
		_prepare_local_rivers()
		if not await _build_terrain(token):
			return
		region_build_count += 1
		if region_cache.size() >= REGION_CACHE_LIMIT:
			var oldest = region_cache.keys()[0]
			_clear_node(region_cache[oldest].surface)
			region_cache.erase(oldest)
		region_cache[id] = {
			"surface": surface,
			"ground": region_ground,
			"rivers": local_river_segments.duplicate(true),
			"lakes": local_lakes.duplicate(true),
			"heights": height_field,
			"forests": forest_field,
			"climate": climate_field,
			"terraces": terrace_signature(id),
		}
	signature = _building_signature()
	if buildings_root == null or str(surface.get_meta("building_signature", "")) != signature:
		_build_colony()
		surface.set_meta("building_signature", signature)
	surface.visible = true
	region_busy = false
	last_region_ms = Time.get_ticks_msec() - started
	region_progress.emit(false, 1.0)
	region_ready.emit(id)


func orbit(dx: float, dy: float) -> void:
	if mode == "flat":
		pan(dx, dy)
	elif mode == "planet":
		focus_site = -1
		sky.hold_spin()
		planet_yaw -= dx * .005
		planet_pitch = clampf(planet_pitch + dy * .004, -1.25, 1.25)
	else:
		local_yaw -= dx * .005
		local_pitch = clampf(local_pitch + dy * .004, REGION_LOWEST_PITCH, 1.35)


func zoom(amount: float) -> void:
	if mode == "flat":
		flat_user_zoomed = true
		# Zoomed out as far as it goes, the poles sit on the window's top and bottom edges.
		flat_size = clampf(flat_size + amount * .85, 4.2, FLAT_HEIGHT)
	elif mode == "planet":
		sky.hold_spin()
		planet_distance = clampf(planet_distance + amount * .65, 7.0, 15.8)
	else:
		local_distance = clampf(
			local_distance * pow(REGION_ZOOM_STEP, amount), REGION_CLOSEST, REGION_FARTHEST
		)


func pan(dx: float, dy: float) -> void:
	if mode == "flat":
		flat_center += Vector2(-dx, dy) * flat_size * .0012
		# East and west without end: past 180° the view comes round to -180°, where the copies of
		# the map stand (`_refresh_flat_ghosts`).
		flat_center.x = wrapf(flat_center.x, -FLAT_WIDTH * 0.5, FLAT_WIDTH * 0.5)
		var room: float = maxf(0.0, (FLAT_HEIGHT - flat_size) * 0.5)
		flat_center.y = clampf(flat_center.y, -room, room)
		return
	if mode != "region" or camera == null:
		return
	var right: Vector3 = camera.global_basis.x
	var up: Vector3 = camera.global_basis.y
	right.y = 0
	up.y = 0
	camera_pivot += (-right.normalized() * dx + up.normalized() * dy) * local_distance * .0012
	camera_pivot.x = clampf(camera_pivot.x, -36.0, 36.0)
	camera_pivot.z = clampf(camera_pivot.z, -26.0, 26.0)
	# Close to the ground the target follows it, so the camera never sinks into a hill.
	if local_distance < 12.0:
		camera_pivot.y = _ground(camera_pivot.x, camera_pivot.z)


## The site marker under a screen position, among those the filter shows, within `radius` pixels.
func _region_at(screen_pos: Vector2, radius: float = HOVER_RADIUS) -> int:
	if mode not in ["planet", "flat"] or camera == null:
		return -1
	var nearest: int = -1
	var best: float = radius
	for reg in world.regions:
		if not _marker_shown(reg):
			continue
		var point: Vector3 = (
			_flat_point(reg.lat, reg.lon)
			if mode == "flat"
			else planet.to_global(Geo.unit_point(reg.lat, reg.lon) * 3.055)
		)
		if mode == "planet" and point.normalized().dot(camera.position.normalized()) < .18:
			continue
		if camera.is_position_behind(point):
			continue
		var distance: float = camera.unproject_position(point).distance_to(screen_pos)
		if mode == "flat":
			for side: float in [-FLAT_WIDTH, FLAT_WIDTH]:
				var copy: Vector3 = point + Vector3(side, 0, 0)
				distance = minf(distance, camera.unproject_position(copy).distance_to(screen_pos))
		if distance < best:
			best = distance
			nearest = int(reg.id)
	return nearest


## Shows the name of the site under the pointer. Rebuilds markers only when that site changes.
func hover_region(screen_pos: Vector2) -> void:
	var under: int = _region_at(screen_pos)
	if under != hovered_region:
		hovered_region = under
		_update_markers()


func set_marker_filter(key: String) -> void:
	if key != marker_filter:
		marker_filter = key
		_update_markers()


func pick_region(screen_pos: Vector2, radius: float = HOVER_RADIUS) -> int:
	var nearest: int = _region_at(screen_pos, radius)
	if nearest >= 0:
		ground_point = {}
		selected_region = nearest
		if mode == "planet":
			sky.hold_spin()
		_update_markers()
		region_selected.emit(nearest)
	return nearest


## The ground under a screen position on the globe or the flat map (1.10 free placement):
## {lat, lon, precision (degrees one pixel spans there), view}, or empty off the planet.
func pick_ground(screen_pos: Vector2) -> Dictionary:
	if camera == null or mode not in ["planet", "flat"]:
		return {}
	var here: Variant = _ground_hit(screen_pos)
	if here == null:
		return {}
	var beside: Variant = _ground_hit(screen_pos + Vector2(1.0, 0.0))
	var below: Variant = _ground_hit(screen_pos + Vector2(0.0, 1.0))
	var at: Vector2 = here
	var precision: float = 0.0
	for other: Variant in [beside, below]:
		if other == null:
			continue
		var step: Vector2 = other
		var scale: float = cos(deg_to_rad(at.x))
		precision = maxf(
			precision, Vector2(wrapf(step.y - at.y, -180.0, 180.0) * scale, step.x - at.x).length()
		)
	return {"lat": at.x, "lon": at.y, "precision": precision, "view": mode}


## The coordinate (lat, lon) under a screen position, or null when the pointer is off the planet.
func _ground_hit(screen_pos: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	if mode == "planet":
		if planet == null:
			return null
		var local_origin: Vector3 = planet.to_local(origin)
		var local_direction: Vector3 = (planet.global_basis.inverse() * direction).normalized()
		var b: float = local_origin.dot(local_direction)
		var c: float = local_origin.length_squared() - GLOBE_RADIUS * GLOBE_RADIUS
		var disc: float = b * b - c
		if disc < 0.0:
			return null
		var t: float = -b - sqrt(disc)
		if t < 0.0:
			return null
		var p: Vector3 = (local_origin + local_direction * t).normalized()
		return Vector2(rad_to_deg(asin(clampf(p.y, -1.0, 1.0))), rad_to_deg(atan2(p.x, p.z)))
	if flat_world == null:
		return null
	var flat_origin: Vector3 = flat_world.to_local(origin)
	var flat_direction: Vector3 = flat_world.global_basis.inverse() * direction
	if absf(flat_direction.z) < 0.000001:
		return null
	var hit: Vector3 = (
		flat_origin + flat_direction * ((FLAT_SURFACE_Z - flat_origin.z) / flat_direction.z)
	)
	var lat: float = hit.y * 20.0
	if absf(lat) > 90.0:
		return null
	return Vector2(lat, wrapf(hit.x * 20.0, -180.0, 180.0))


## Shows the picked ground on both maps, or none with an empty point. The marker selection clears:
## the ground is what the founding button acts on now.
func set_ground(point: Dictionary) -> void:
	ground_point = point.duplicate() if not point.is_empty() else {}
	if not ground_point.is_empty():
		selected_region = -1
	_update_markers()


func focus_ground(lat: float) -> void:
	focus_site = -1
	sky.hold_spin()
	planet_pitch = deg_to_rad(lat) * .75


func focus_region(id: int) -> void:
	if id < 0 or id >= world.regions.size():
		return
	ground_point = {}
	selected_region = id
	focus_site = id
	sky.hold_spin()
	_track_focus()
	planet_pitch = deg_to_rad(float(world.regions[id].lat)) * .75
	_update_markers()


## Keeps a clicked site in front of the camera while the planet comes to rest under it.
func _track_focus() -> void:
	if focus_site < 0 or focus_site >= world.regions.size():
		return
	var target: float = deg_to_rad(float(world.regions[focus_site].lon)) + sky.spin
	planet_yaw = smooth_yaw + wrapf(target - smooth_yaw, -PI, PI)


func _process(delta: float) -> void:
	_poll_atlas_job()
	if camera == null:
		return
	sky.advance(delta)
	if planet != null and is_instance_valid(planet):
		planet.rotation.y = sky.spin
	if focus_site >= 0 and mode == "planet":
		_track_focus()
		if sky.hold <= 0.0:
			focus_site = -1
	if not timelapse.is_empty():
		_step_timelapse(delta)
	_update_camera(1.0 - exp(-delta * 9.0))
	if mode == "planet" and timelapse.is_empty():
		_crossfade_lights()
	_apply_sky()
	if mode == "region" and surface != null and surface.visible:
		_animate_region(delta)
	elif mode == "planet":
		_place_movers(globe_movers, sky.day_fraction)
		place_ships(globe_ships, sky.day_fraction)
		_place_weather_markers()
	elif mode == "flat":
		_place_movers(flat_movers, sky.day_fraction)
		place_ships(flat_ships, sky.day_fraction)
	if marker_root != null and is_instance_valid(marker_root) and planet.visible:
		var toward: Vector3 = planet.to_local(camera.global_position).normalized()
		for child in marker_root.get_children():
			if child is Node3D and child.has_meta("point"):
				child.visible = Vector3(child.get_meta("point")).normalized().dot(toward) > .12


## The town after dark: windows, street lamps, headlights and pools of lamp light follow the
## night at the site; vehicles run while the game clock runs.
func _animate_region(delta: float) -> void:
	if traffic != null and is_instance_valid(traffic):
		traffic.running = sky.running
		traffic.rate = sky.rate
		traffic.advance(delta)
	if sky.running:
		_sail(delta * sky.rate)
		_fly(delta * sky.rate)
	lower_company_ship(sky.day_fraction)
	var night: float = region_night if day_night_enabled else 0.0
	if mats.has("glass_on"):
		mats["glass_on"].emission_energy_multiplier = night * 0.85
	if mats.has("lamps"):
		mats["lamps"].emission_energy_multiplier = 1.3 + night * 3.0
	if mats.has("headlight"):
		mats["headlight"].emission_energy_multiplier = 0.4 + night * 3.5
	if glow_material != null:
		glow_material.set_shader_parameter("intensity", night * 0.8)
	for lamp: OmniLight3D in lamp_lights:
		lamp.light_energy = night * LAMP_ENERGY
		lamp.visible = night > 0.02
	if mats.has("smoke"):
		var shade: float = lerpf(1.0, 0.32, night)
		mats["smoke"].albedo_color = Color(shade, shade, shade * 1.04, 1.0)


## What the game clock is doing; main.gd calls this every frame.
func set_clock(running: bool, speed: int, day: int, fraction: float) -> void:
	sky.set_clock(running, speed, day, fraction)


## Player settings: a turning planet, day and night with lights, moving weather.
func set_visual_options(spin: bool, day_night: bool, weather: bool) -> void:
	sky.spin_enabled = spin
	sky.weather_enabled = weather
	day_night_enabled = day_night
	weather_enabled = weather
	for material: ShaderMaterial in [globe_shader, flat_shader]:
		if material != null:
			material.set_shader_parameter("low_haze", 1.0 if weather else 0.0)
	if not spin:
		sky.spin_factor = 0.0


## The complete transport diagram on the globe and the flat map. Off, the night shows only what
## lights a route: where it leaves town, junctions and the cargo moving on it.
func set_route_overlay(on: bool) -> void:
	routes_shown = on
	flat_ghosts_dirty = true
	for root: Variant in [transport_root, flat_transport_root]:
		if root is Node3D and is_instance_valid(root):
			(root as Node3D).visible = on


## Captures and window tests want the same picture every time: the clock stops where it is,
## with the planet unturned. Day, night and clouds stay as the settings have them.
func freeze_motion() -> void:
	sky.frozen = true
	sky.spin = 0.0
	if planet != null and is_instance_valid(planet):
		planet.rotation.y = 0.0


## Feeds the visual clock to every map shader. In planet frames: the shaders never turn anything.
## Terraforming stages finished, read from the state the map was given (0-3).
func _terraforming_stages() -> int:
	for s: Dictionary in state.get("settlements", []):
		for b: Dictionary in s.get("buildings", []):
			if str(b.kind) == "terraforming" and int(b.get("remaining", 0)) <= 0:
				return int(b.get("level", 1))
	return 0


func _apply_sky() -> void:
	var sun: Vector3 = sky.sun_local()
	if not day_night_enabled:
		sun = _shoulder_sun()
	if not timelapse.is_empty():
		# Night over the capital for the whole time-lapse.
		sun = -Geo.unit_point(float(timelapse.capital.lat), float(timelapse.capital.lon))
	var night_value: float = 1.0 if day_night_enabled or not timelapse.is_empty() else 0.0
	var storms: Array[Vector4] = sky.storm_vectors()
	var radii: PackedFloat32Array = sky.storm_radii()
	var season: float = sky.season() if day_night_enabled else 0.0
	if globe_shader != null and planet.visible:
		globe_shader.set_shader_parameter("sun_local", sun)
		globe_shader.set_shader_parameter("camera_local", planet.to_local(camera.global_position))
		globe_shader.set_shader_parameter("season", season)
		globe_shader.set_shader_parameter("day_night", night_value)
	if cloud_shell != null and is_instance_valid(cloud_shell):
		cloud_shell.visible = weather_enabled and timelapse.is_empty()
	if flat_shader != null:
		flat_shader.set_shader_parameter("cloud_opacity", 0.22 if weather_enabled else 0.0)
	for material: ShaderMaterial in [cloud_shader, flat_shader]:
		if material == null:
			continue
		material.set_shader_parameter("sun_local", sun)
		material.set_shader_parameter("weather_time", sky.weather_time)
		material.set_shader_parameter("storms", storms)
		material.set_shader_parameter("storm_radius", radii)
		material.set_shader_parameter("day_night", night_value)
	if flat_shader != null:
		flat_shader.set_shader_parameter("season", season)
	if atmosphere_shader != null:
		atmosphere_shader.set_shader_parameter("sun_local", sun)
		atmosphere_shader.set_shader_parameter("day_night", night_value)
	for key: String in ["terrain_ground_true", "terrain_ground_false", "district_ground"]:
		if mats.has(key):
			mats[key].set_shader_parameter("weather_time", sky.weather_time)
			mats[key].set_shader_parameter("cloud_shadow", 0.35 if weather_enabled else 0.0)
	for kind: String in ["globe_footprint_town", "globe_footprint_farm"]:
		if mats.has(kind):
			mats[kind].set_shader_parameter("sun_world", sky.sun_world())
			mats[kind].set_shader_parameter("day_night", night_value)


## Without day and night the globe is lit as in 1.8: from over the viewer's shoulder.
func _shoulder_sun() -> Vector3:
	if camera == null or planet == null:
		return Vector3(0.6, 0.3, 0.7)
	var basis: Basis = camera.global_transform.basis
	var toward_sun: Vector3 = (basis.z + basis.x * -0.55 + basis.y * 0.5).normalized()
	return planet.global_transform.basis.inverse() * toward_sun


func _update_camera(weight: float) -> void:
	_place_space()
	if mode == "flat":
		var ui_scale: float = get_window().content_scale_factor
		if not flat_user_zoomed:
			flat_size = FLAT_HEIGHT
		flat_size = minf(flat_size, FLAT_HEIGHT)
		camera.size = minf(lerpf(camera.size, flat_size, weight), FLAT_HEIGHT)
		# The view never goes past a pole: at the widest it shows them on its top and bottom edges.
		var room: float = maxf(0.0, (FLAT_HEIGHT - camera.size) * 0.5)
		flat_center.y = clampf(flat_center.y, -room, room)
		var half_width: float = camera.size * 0.5 * get_viewport().get_visible_rect().size.aspect()
		if flat_ghosts_dirty and absf(flat_center.x) + half_width + 1.0 > FLAT_WIDTH * 0.5:
			_refresh_flat_ghosts()
		camera.position = Vector3(flat_center.x, flat_center.y, 16)
		camera.look_at(Vector3(flat_center.x, flat_center.y, 0), Vector3.UP)
		camera.h_offset = flat_size * 87.5 * ui_scale / 900.0
		return
	var yaw: float = planet_yaw if mode == "planet" else local_yaw
	var pitch: float = planet_pitch if mode == "planet" else local_pitch
	var distance: float = planet_distance if mode == "planet" else local_distance
	smooth_yaw = lerp(smooth_yaw, yaw, weight)
	smooth_pitch = lerp(smooth_pitch, pitch, weight)
	smooth_distance = lerp(smooth_distance, distance, weight)
	var direction := Vector3(
		cos(smooth_pitch) * sin(smooth_yaw), sin(smooth_pitch), cos(smooth_pitch) * cos(smooth_yaw)
	)
	camera.position = camera_pivot + direction * smooth_distance
	camera.look_at(camera_pivot, Vector3.UP)
	camera.h_offset = (
		.68
		if mode == "planet"
		else 4.0 * clampf(smooth_distance / REGION_OFFSET_DISTANCE, 0.0, 1.0)
	)
	if mode == "region":
		camera.near = clampf(smooth_distance * 0.02, 0.01, REGION_NEAR)
	_aim_sun()


## On the globe the light comes from the real sun (or over the viewer's shoulder without day and
## night). In a region the sun stands where it stands over that site on the turning planet.
func _aim_sun() -> void:
	_place_space()
	if sun_light == null:
		return
	if mode == "region" and day_night_enabled and not world.is_empty():
		_aim_region_sun()
		return
	_light_day_scene()
	if mode != "planet":
		sun_light.rotation_degrees = SUN_ROTATION
		return
	var toward_sun: Vector3 = sky.sun_world()
	if not day_night_enabled and planet != null:
		toward_sun = planet.global_transform.basis * _shoulder_sun()
	sun_light.look_at_from_position(toward_sun * 10.0, Vector3.ZERO, _up_hint(toward_sun))


static func _up_hint(direction: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(direction.normalized().y) > 0.98 else Vector3.UP


func _light_day_scene() -> void:
	region_night = 0.0
	sun_light.light_energy = SUN_ENERGY
	sun_light.light_color = Color("f6ecd1")
	if environment != null:
		environment.ambient_light_color = DAY_AMBIENT
		environment.ambient_light_energy = .38
		environment.background_color = DAY_SKY
	if fill_light != null:
		fill_light.light_energy = .18
	_region_air(1.0, 0.0)


## The site's sky: east is +x, north is -z, as the regional ground is laid out.
func _aim_region_sun() -> void:
	var reg: Dictionary = world.regions[selected_region]
	var up: Vector3 = Geo.unit_point(float(reg.lat), float(reg.lon)).rotated(Vector3.UP, sky.spin)
	var east: Vector3 = Vector3(up.z, 0.0, -up.x).normalized()
	if east.length() < 0.5:
		east = Vector3.RIGHT
	var north: Vector3 = up.cross(east)
	var sun: Vector3 = sky.sun_world()
	var height: float = sun.dot(up)
	var local := Vector3(sun.dot(east), maxf(height, 0.06), -sun.dot(north)).normalized()
	var daylight: float = smoothstep(-0.1, 0.14, height)
	region_night = 1.0 - daylight
	sun_light.look_at_from_position(local * 10.0, Vector3.ZERO, _up_hint(local))
	sun_light.light_energy = SUN_ENERGY * smoothstep(-0.02, 0.12, height)
	sun_light.light_color = Color("ffad6b").lerp(Color("f6ecd1"), smoothstep(0.04, 0.35, height))
	if environment != null:
		environment.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, daylight)
		environment.ambient_light_energy = lerpf(.62, .38, daylight)
		environment.background_color = NIGHT_SKY.lerp(DAY_SKY, daylight)
	if fill_light != null:
		fill_light.light_energy = lerpf(.85, .18, daylight)
	var dusk: float = smoothstep(-0.12, 0.04, height) * (1.0 - smoothstep(0.04, 0.3, height))
	if not world.is_empty() and Geo.is_generated(str(world.version)):
		# The approved district's light (1.12, region/preview.gd): a warm low sun over a bright
		# sky-blue ambient, so shade on the ground keeps its colour.
		var low: float = 1.0 - smoothstep(0.25, 0.6, height)
		sun_light.light_color = Color("ffad6b").lerp(Color("ffce9e"), smoothstep(0.02, 0.2, height))
		sun_light.light_color = sun_light.light_color.lerp(Color("f6ecd1"), 1.0 - low)
		sun_light.light_energy *= lerpf(1.0, 0.76, low * smoothstep(0.04, 0.2, height))
		if environment != null:
			environment.ambient_light_color = NIGHT_AMBIENT.lerp(REGION_DAY_AMBIENT, daylight)
			environment.ambient_light_energy = lerpf(.62, REGION_AMBIENT_ENERGY, daylight)
	var evening: float = smoothstep(0.0, 0.1, height) * (1.0 - smoothstep(0.18, 0.5, height))
	_region_air(daylight, dusk * 0.55, evening)


## A generated region stands under its own sky: the horizon takes the time of day and the far
## landscape fades into it, so no edge of the ground shows. The globe, the flat map and older
## worlds keep the dark of space and the stars.
func _region_air(daylight: float, dusk: float, evening: float = 0.0) -> void:
	var landscape: bool = (
		mode == "region" and not world.is_empty() and Geo.is_generated(str(world.version))
	)
	if star_field != null:
		star_field.visible = not landscape
	if environment == null:
		return
	environment.fog_enabled = landscape
	if not landscape:
		environment.background_mode = Environment.BG_COLOR
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 1.0
		environment.tonemap_white = 1.0
		return
	var air: Color = (
		REGION_NIGHT_AIR
		. lerp(REGION_DAY_AIR, daylight)
		. lerp(REGION_EVENING_AIR, evening)
		. lerp(REGION_DUSK_AIR, dusk)
	)
	environment.background_color = air
	# The approved district's evening (region/preview.gd): a graded sky whose horizon is the haze
	# the far ground fades into, under ACES with its exposure and white point.
	if region_sky == null:
		region_sky = ProceduralSkyMaterial.new()
		region_sky.sky_curve = 0.12
		region_sky.sun_angle_max = 2.0
		region_sky.use_debanding = true
		environment.sky = Sky.new()
		environment.sky.sky_material = region_sky
	region_sky.sky_top_color = (REGION_SKY_NIGHT.lerp(REGION_SKY_DAY, daylight).lerp(
		REGION_SKY_EVENING, evening
	))
	region_sky.sky_horizon_color = air
	region_sky.ground_horizon_color = air
	region_sky.ground_bottom_color = air.darkened(0.35)
	environment.background_mode = Environment.BG_SKY
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = REGION_EXPOSURE
	environment.tonemap_white = 4.0
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = air
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.0
	environment.fog_density = 1.0
	environment.fog_depth_begin = REGION_HAZE.x
	environment.fog_depth_end = REGION_HAZE.y


func _build_environment() -> void:
	if camera != null:
		return
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080f1c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8aacbe")
	environment.ambient_light_energy = .38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "WarmDistantSun"
	sun.light_color = Color("f6ecd1")
	sun.light_energy = 1.12
	sun.rotation_degrees = SUN_ROTATION
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	sun_light = sun
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("5ba6ca")
	fill.light_energy = .18
	fill.rotation_degrees = Vector3(35, 140, 0)
	add_child(fill)
	fill_light = fill
	_apply_render_quality()
	_build_stars()


## Forward+ (高画质) draws what Compatibility cannot: ambient occlusion where buildings meet the
## ground, bloom on lit windows and town lights, finer and softer shadows. Forward+ renders in
## linear light and comes out about a fifth less saturated, so a colour grade keeps one palette
## across both renderers.
func _apply_render_quality() -> void:
	high_quality = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if not high_quality:
		return
	environment.adjustment_enabled = true
	environment.adjustment_brightness = HQ_GRADE.x
	environment.adjustment_contrast = HQ_GRADE.y
	environment.adjustment_saturation = HQ_GRADE.z
	environment.ssao_radius = HQ_AO.x
	environment.ssao_intensity = HQ_AO.y
	environment.ssao_power = HQ_AO.z
	environment.ssao_detail = 0.5
	environment.glow_enabled = true
	environment.glow_intensity = HQ_GLOW.x
	environment.glow_bloom = HQ_GLOW.y
	environment.glow_hdr_threshold = HQ_GLOW.z
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	sun_light.shadow_blur = HQ_SHADOW_BLUR
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	)
	_apply_mode_quality()


## Ambient occlusion belongs to the town at its scale; the globe and the flat map do without.
func _apply_mode_quality() -> void:
	if environment != null and high_quality:
		environment.ssao_enabled = mode == "region"
		# The optical palette is already display-referred in both graphics modes.
		environment.adjustment_enabled = mode == "region" or not _uses_optical_geography()


func _build_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var star := SphereMesh.new()
	star.radius = .04
	star.height = .08
	star.radial_segments = 5
	star.rings = 3
	var m := _mat("starlight", Color(.65, .82, .95), 0, 1, 1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	star.material = m
	mm.mesh = star
	mm.instance_count = 1050
	var rng := RandomNumberGenerator.new()
	rng.seed = 902410
	for i in range(mm.instance_count):
		var pos := (
			(
				Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
				. normalized()
			)
			* 210.0
		)
		var scale_value := rng.randf_range(.35, 2.6)
		mm.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), pos)
		)
		mm.set_instance_color(i, Color(.56, .73, .88) * rng.randf_range(.2, .95))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	add_child(stars)
	star_field = stars
	_build_space()


## The space dome and the star's glare (see `space_dome`).
func _build_space() -> void:
	var dome := SphereMesh.new()
	dome.radius = SPACE_RADIUS
	dome.height = SPACE_RADIUS * 2.0
	dome.radial_segments = 64
	dome.rings = 32
	var sky_shader := Shader.new()
	sky_shader.code = SPACE_SHADER
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	space_dome = MeshInstance3D.new()
	space_dome.name = "SpaceDome"
	space_dome.mesh = dome
	space_dome.material_override = sky_material
	space_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(space_dome)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * STAR_SIZE
	# The star's glare: a white core in a warm halo, always facing the camera, added to the sky.
	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.05, 0.14, 0.34, 0.62, 1.0])
	glow.colors = PackedColorArray(
		[
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 0.98, 0.9, 1.0),
			Color(1.0, 0.9, 0.68, 0.75),
			Color(1.0, 0.78, 0.48, 0.3),
			Color(1.0, 0.66, 0.36, 0.08),
			Color(1.0, 0.6, 0.3, 0.0)
		]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = glow
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var glare_material := StandardMaterial3D.new()
	glare_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glare_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glare_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glare_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glare_material.albedo_texture = texture
	glare_material.albedo_color = Color(1.6, 1.5, 1.35, 1.0)
	glare_material.disable_fog = true
	star_glare = MeshInstance3D.new()
	star_glare.name = "StarGlare"
	star_glare.mesh = quad
	star_glare.material_override = glare_material
	star_glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star_glare)
	_place_space()


## Space shows on the globe only; the star stands in the real sun's direction (also when day and
## night are off and the globe is lit over the viewer's shoulder).
func _place_space() -> void:
	var on_globe: bool = mode == "planet"
	if space_dome != null and is_instance_valid(space_dome):
		space_dome.visible = on_globe
	if star_glare != null and is_instance_valid(star_glare):
		star_glare.visible = on_globe
		if on_globe:
			star_glare.position = sky.sun_world().normalized() * STAR_DISTANCE


func _exit_tree() -> void:
	cancel_region_load()
	# Thread workers must finish before their script owner is destroyed.
	for worker in atlas_job.get("workers", []):
		worker.wait_to_finish()


## The simulation's weather (1.11 F): the clouds draw its systems (visual_clock.gd `follow`), and
## a ring marks each one on the globe, red when it is heading for one of the colony's towns. The
## rings stay with the clouds switched off.
func _follow_weather() -> void:
	var systems: Array = state.get("weather", {}).get("systems", [])
	# Worlds from before the climate grid keep the cosmetic storms (weather.gd `active`).
	sky.follow(systems, Weather.on() and world.has("grid_width"))
	var key: PackedStringArray = []
	for system: Dictionary in systems:
		key.append("%d:%d:%d" % [int(system.id), int(system.age), system.get("warned", {}).size()])
	var now: String = ",".join(key)
	if now == weather_signature:
		return
	weather_signature = now
	if weather_root == null or not is_instance_valid(weather_root):
		if planet == null or not is_instance_valid(planet):
			return
		weather_root = Node3D.new()
		weather_root.name = "WeatherMarkers"
		planet.add_child(weather_root)
	for child: Node in weather_root.get_children():
		weather_root.remove_child(child)
		child.queue_free()
	weather_markers.clear()
	for system: Dictionary in systems:
		var warned: bool = not system.get("warned", {}).is_empty()
		var color: Color = WEATHER_COLORS.get(str(system.kind), Color("c8c8c8"))
		if warned:
			color = Color("e46f68")
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		var size: float = deg_to_rad(float(system.radius)) * 3.0
		mesh.inner_radius = size * 0.92
		mesh.outer_radius = size
		mesh.rings = 32
		mesh.ring_segments = 4
		ring.mesh = mesh
		ring.material_override = _ring_material("weather_%s_%s" % [str(system.kind), warned], color)
		ring.name = "Weather_%d" % int(system.id)
		weather_root.add_child(ring)
		weather_markers.append({"node": ring, "system": system})
	_place_weather_markers()


## Plays the colony's light record (light_record.gd) on the globe at night over `seconds`, from
## the landing to the last snapshot, watched from the default distance over the capital.
func play_timelapse(snapshots: Array, seconds: float) -> void:
	if snapshots.is_empty() or snapshots.back().towns.is_empty() or planet == null:
		return
	var capital: Dictionary = snapshots.back().towns[0]
	timelapse = {
		"snapshots": snapshots,
		"seconds": maxf(1.0, seconds),
		"elapsed": 0.0,
		"day": float(snapshots[0].day),
		"capital": capital,
	}
	show_planet()
	focus_region(int(capital.region))
	planet_distance = TIMELAPSE_DISTANCE
	for root: Variant in [marker_root, weather_root, transport_root]:
		if root is Node3D and is_instance_valid(root):
			(root as Node3D).visible = false


func stop_timelapse() -> void:
	if timelapse.is_empty():
		return
	timelapse = {}
	_update_night_lights()
	if globe_shader != null:
		globe_shader.set_shader_parameter("far_lights", _far_lights_texture())
	form_weights = Vector2(-1.0, -1.0)
	_crossfade_lights()
	for root: Variant in [marker_root, weather_root]:
		if root is Node3D and is_instance_valid(root):
			(root as Node3D).visible = true
	set_route_overlay(routes_shown)


## The per-plot lights up close and the planet-scale town forms from the default distance out,
## crossfaded by camera distance so the two never add up (1.11 G, town_forms.gd `weights`).
func _crossfade_lights() -> void:
	if globe_shader == null:
		return
	var shares: Vector2 = TownForms.weights(
		smooth_distance, Rules.read("progression").get("lights", {})
	)
	if form_weights.distance_to(shares) < 0.005:
		return
	form_weights = shares
	globe_shader.set_shader_parameter("plot_lights", shares.x)
	globe_shader.set_shader_parameter("form_lights", shares.y)


func _empty_far_lights() -> ImageTexture:
	if not timelapse.has("far"):
		var empty := Image.create(TownForms.FAR_WIDTH, TownForms.FAR_HEIGHT, true, Image.FORMAT_RG8)
		timelapse.far = ImageTexture.create_from_image(empty)
	return timelapse.far


## 0 to 1 through the time-lapse; -1 when none plays.
func timelapse_progress() -> float:
	if timelapse.is_empty():
		return -1.0
	return clampf(float(timelapse.elapsed) / float(timelapse.seconds), 0.0, 1.0)


## The game day the time-lapse shows.
func timelapse_day() -> int:
	return int(timelapse.get("day", 0.0))


func _step_timelapse(delta: float) -> void:
	timelapse.elapsed = float(timelapse.elapsed) + delta
	var snapshots: Array = timelapse.snapshots
	var day: float = lerpf(
		float(snapshots[0].day), float(snapshots.back().day), timelapse_progress()
	)
	timelapse.day = day
	town_lights = Timelapse.uniforms(Timelapse.towns_on(snapshots, day), world)
	_apply_town_lights(globe_shader)
	if globe_shader != null:
		# Only the forms, and no strings of today's roads in the past.
		globe_shader.set_shader_parameter("plot_lights", 0.0)
		globe_shader.set_shader_parameter("form_lights", 1.0)
		globe_shader.set_shader_parameter("far_lights", _empty_far_lights())
	sky.hold_spin()


## Unshaded: a lit, glowing ring washes out to white in daylight and the red of a warning is lost.
func _ring_material(key: String, color: Color) -> StandardMaterial3D:
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		mats[key] = m
	return mats[key]


func _place_weather_markers() -> void:
	for entry: Dictionary in weather_markers:
		var node: Node3D = entry.node
		if not is_instance_valid(node):
			continue
		var at: Vector2 = Weather.ahead(entry.system, sky.day_fraction)
		var normal: Vector3 = Geo.unit_point(at.x, at.y)
		var side: Vector3 = normal.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		node.transform = Transform3D(
			Basis(side, normal, side.cross(normal).normalized()), normal * 3.07
		)
