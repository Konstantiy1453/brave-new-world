extends "res://world/planet_view.gd"
## Native lightweight 3D renderer: owns the camera, the view mode and input.

const SUN_ROTATION: Vector3 = Vector3(-26, -46, 0)


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
	selected_region = 0
	signature = ""
	marker_signature = ""
	transport_signature = ""
	height_field = PackedFloat32Array()
	forest_field = PackedFloat32Array()
	marker_filter = "all"
	hovered_region = -1
	world = data
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
	var markers_now: String = _marker_signature()
	if markers_now != marker_signature:
		marker_signature = markers_now
		_update_markers()
	var transport_now: String = _transport_signature()
	if transport_now != transport_signature:
		transport_signature = transport_now
		_update_transport()
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
		settled.append([int(place.region), place.get("buildings", []).size(), farms])
	return "%d|%s|%s" % [selected_region, str(settled), marker_filter]


func _transport_signature() -> String:
	var roads: Array = []
	for road: Dictionary in state.get("roads", []):
		roads.append([int(road.get("id", 0)), Geo.road_blocked(road, int(state.get("day", 0)))])
	var moving: Array = []
	for cargo: Dictionary in state.get("shipments", []):
		moving.append([int(cargo.from), int(cargo.remaining), int(cargo.total_days)])
	return "%s|%s" % [str(roads), str(moving)]


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
	var started: int = Time.get_ticks_msec()
	var token: int = region_load_token
	selected_region = id
	mode = "region"
	planet.visible = false
	flat_world.visible = false
	surface.visible = false
	var old_cached: bool = false
	for entry in region_cache.values():
		if entry.surface == surface:
			old_cached = true
	if not old_cached:
		_clear_node(surface)
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
		planet_yaw -= dx * .005
		planet_pitch = clampf(planet_pitch + dy * .004, -1.25, 1.25)
	else:
		local_yaw -= dx * .005
		local_pitch = clampf(local_pitch + dy * .004, .25, 1.35)


func zoom(amount: float) -> void:
	if mode == "flat":
		flat_user_zoomed = true
		flat_size = clampf(flat_size + amount * .85, 4.2, 23.0)
	elif mode == "planet":
		planet_distance = clampf(planet_distance + amount * .65, 7.0, 15.8)
	else:
		local_distance = clampf(local_distance + amount * 3.5, 31.0, 94.0)


func pan(dx: float, dy: float) -> void:
	if mode == "flat":
		flat_center += Vector2(-dx, dy) * flat_size * .0012
		flat_center.x = clampf(flat_center.x, -9.0, 9.0)
		flat_center.y = clampf(flat_center.y, -4.5, 4.5)
		return
	if mode != "region" or camera == null:
		return
	var right: Vector3 = camera.global_basis.x
	var up: Vector3 = camera.global_basis.y
	right.y = 0
	up.y = 0
	camera_pivot += (-right.normalized() * dx + up.normalized() * dy) * local_distance * .0012
	camera_pivot.x = clampf(camera_pivot.x, -18.0, 18.0)
	camera_pivot.z = clampf(camera_pivot.z, -15.0, 15.0)


## The site marker under a screen position, among those the filter shows.
func _region_at(screen_pos: Vector2) -> int:
	if mode not in ["planet", "flat"] or camera == null:
		return -1
	var nearest: int = -1
	var best: float = 43.0
	for reg in world.regions:
		if not _marker_shown(reg):
			continue
		var point: Vector3 = (
			_flat_point(reg.lat, reg.lon)
			if mode == "flat"
			else Geo.unit_point(reg.lat, reg.lon) * 3.055
		)
		if mode == "planet" and point.normalized().dot(camera.position.normalized()) < .18:
			continue
		if camera.is_position_behind(point):
			continue
		var distance: float = camera.unproject_position(point).distance_to(screen_pos)
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


func pick_region(screen_pos: Vector2) -> int:
	var nearest: int = _region_at(screen_pos)
	if nearest >= 0:
		selected_region = nearest
		_update_markers()
		region_selected.emit(nearest)
	return nearest


func focus_region(id: int) -> void:
	if id < 0 or id >= world.regions.size():
		return
	selected_region = id
	planet_yaw = deg_to_rad(float(world.regions[id].lon))
	planet_pitch = deg_to_rad(float(world.regions[id].lat)) * .75
	_update_markers()


func _process(delta: float) -> void:
	_poll_atlas_job()
	if camera == null:
		return
	_update_camera(1.0 - exp(-delta * 9.0))
	if cloud_shell != null and is_instance_valid(cloud_shell):
		cloud_shell.rotation.y += delta * .0015
	if marker_root != null and is_instance_valid(marker_root) and planet.visible:
		for child in marker_root.get_children():
			if child is Node3D and child.has_meta("point"):
				child.visible = (
					Vector3(child.get_meta("point")).normalized().dot(camera.position.normalized())
					> .12
				)


func _update_camera(weight: float) -> void:
	if mode == "flat":
		var ui_scale: float = get_window().content_scale_factor
		if not flat_user_zoomed:
			flat_size = 16.6 * maxf(1.0, ui_scale)
		camera.size = lerpf(camera.size, flat_size, weight)
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
	camera.h_offset = .68 if mode == "planet" else 4.0
	_aim_sun()


## On the globe the sun stays over the viewer's shoulder, so the part being looked at is never in
## the dark. The regional scene keeps its fixed sun and its long shadows.
func _aim_sun() -> void:
	if sun_light == null:
		return
	if mode != "planet":
		sun_light.rotation_degrees = SUN_ROTATION
		return
	var basis: Basis = camera.global_transform.basis
	var toward_sun: Vector3 = (basis.z + basis.x * -0.55 + basis.y * 0.5).normalized()
	sun_light.look_at_from_position(toward_sun * 10.0, Vector3.ZERO, Vector3.UP)
	if globe_shader != null:
		globe_shader.set_shader_parameter("sun_direction", toward_sun)


func _build_environment() -> void:
	if camera != null:
		return
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	var environment := Environment.new()
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
	_build_stars()


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


func _exit_tree() -> void:
	cancel_region_load()
	# Thread workers must finish before their script owner is destroyed.
	for worker in atlas_job.get("workers", []):
		worker.wait_to_finish()
