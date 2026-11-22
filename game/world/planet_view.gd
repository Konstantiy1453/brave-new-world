extends "res://world/flat_view.gd"
## The globe: geography atlas, clouds, water overlay, markers, routes. The planet node turns with
## the visual clock (`sky`); everything on it lives in the planet's own frame.

const ATLAS_WIDTH: int = 1536
const ATLAS_HEIGHT: int = 768


func _build_planet() -> void:
	# Both global modes share this authoritative atlas: no second random map.
	var atlas_start: int = Time.get_ticks_msec()
	var cache_key: String = (
		"atlas-1536-r6-data:"
		+ str(world.version)
		+ ":"
		+ str(world.seed)
		+ ":"
		+ str(world.get("size", 1))
		+ ":"
		+ JSON.stringify(world.get("generation", {})).sha256_text()
	)
	current_atlas_key = cache_key
	atlas_refining = false
	pending_atlas.clear()
	var disk_path: String = "user://world_atlas_" + cache_key.sha256_text() + ".png"
	var bundled_path: String = (
		"res://assets/generated/world_atlas_" + cache_key.sha256_text() + ".png"
	)
	last_atlas_cached = atlas_cache.has(cache_key)
	if last_atlas_cached:
		geography_atlas = atlas_cache[cache_key]
		last_atlas_source = "memory"
	else:
		var image: Image = (
			Image.load_from_file(disk_path) if FileAccess.file_exists(disk_path) else null
		)
		last_atlas_source = "disk" if image != null else "preview"
		if ResourceLoader.exists(bundled_path):
			var bundled: Texture2D = load(bundled_path)
			image = bundled.get_image()
			last_atlas_source = "bundled"
		if (
			image != null
			and image.get_width() == ATLAS_WIDTH
			and image.get_height() == ATLAS_HEIGHT
		):
			last_atlas_cached = true
		else:
			var context: Dictionary = {}
			if Geo.is_generated(str(world.version)):
				context = Geo.Plates.context(int(world.seed))
			elif str(world.version) != "CC-GEO-1.4":
				context = Geo.SeedGeo.context(int(world.seed)).duplicate(true)
			# A small authoritative preview is visible immediately. Only the high
			# detail atlas runs in background; camera and economy remain responsive.
			image = _grid_preview()
			atlas_refining = true
			pending_atlas = {
				"key": cache_key,
				"path": disk_path,
				"seed": int(world.seed),
				"version": str(world.version),
				"context": context
			}
		image.generate_mipmaps()
		geography_atlas = ImageTexture.create_from_image(image)
		if last_atlas_cached:
			if atlas_cache.size() >= 2:
				atlas_cache.erase(atlas_cache.keys()[0])
			atlas_cache[cache_key] = geography_atlas
	last_atlas_ms = Time.get_ticks_msec() - atlas_start
	globe_shader = ShaderMaterial.new()
	globe_shader.shader = Shaders.shader("globe")
	globe_shader.set_shader_parameter("atlas", geography_atlas)
	globe_shader.set_shader_parameter("noise3d", Shaders.noise_texture())
	globe_shader.set_shader_parameter("lights", _night_lights_texture())
	_apply_town_lights(globe_shader)
	globe_shader.set_shader_parameter("ice_latitude", _ice_latitude())
	var sphere := SphereMesh.new()
	sphere.radius = 3
	sphere.height = 6
	sphere.radial_segments = 160
	sphere.rings = 80
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = globe_shader
	planet.add_child(mesh)
	atmosphere_shader = ShaderMaterial.new()
	atmosphere_shader.shader = Shaders.shader("atmosphere")
	_sphere(planet, Vector3.ZERO, 3.08, atmosphere_shader, 96, 48)
	_build_clouds()
	marker_root = Node3D.new()
	planet.add_child(marker_root)
	transport_root = Node3D.new()
	planet.add_child(transport_root)
	transport_root.visible = routes_shown
	mover_root = Node3D.new()
	mover_root.name = "Movers"
	planet.add_child(mover_root)
	_build_global_water(planet, false)
	_update_markers()


func _grid_preview() -> Image:
	# Reuse persisted geography for first feedback; background refinement keeps
	# the existing 1536 x 768 final quality without a blocking second generation.
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var cell: Dictionary = world.grid[y * width + x]
			image.set_pixel(x, y, _geo_data(cell))
	return image


## The four numbers every map shader colours from; see `world/shaders.gd`.
static func _geo_data(g: Dictionary) -> Color:
	return Shaders.encode(
		float(g.height), float(g.temperature), float(g.rainfall), float(g.get("ridge", 0.0))
	)


func _render_atlas_tile(
	tile: int,
	count: int,
	seed_value: int,
	version: String,
	width: int,
	height: int,
	context: Dictionary
) -> Dictionary:
	var row_start: int = height * tile / count
	var row_end: int = height * (tile + 1) / count
	var image := Image.create(width, row_end - row_start, false, Image.FORMAT_RGBA8)
	var tile_noise := FastNoiseLite.new()
	tile_noise.seed = seed_value
	tile_noise.frequency = 1.8
	tile_noise.fractal_octaves = 4
	for y in range(row_start, row_end):
		var lat: float = 90.0 - (float(y) + .5) * 180.0 / height
		for x in range(width):
			var lon: float = (float(x) + .5) * 360.0 / width - 180.0
			var g: Dictionary = _atlas_sample(lat, lon, tile_noise, version, context)
			image.set_pixel(x, y - row_start, _geo_data(g))
	return {"image": image, "row": row_start}


func _atlas_sample(
	lat: float, lon: float, tile_noise: FastNoiseLite, version: String, context: Dictionary
) -> Dictionary:
	if Geo.is_generated(version):
		return Geo.Plates.sample_with_context(lat, lon, tile_noise, context)
	if version == "CC-GEO-1.4":
		return Geo.sample_geo(lat, lon, tile_noise, version)
	return Geo.SeedGeo.sample_with_context(lat, lon, tile_noise, context)


## Joins the tiles, writes the file and builds the mipmaps away from the frame: only uploading the
## finished texture happens on the main thread.
static func _finish_atlas_image(job: Dictionary, tiles: Array) -> void:
	var image := Image.create(ATLAS_WIDTH, ATLAS_HEIGHT, false, Image.FORMAT_RGBA8)
	for result: Dictionary in tiles:
		image.blit_rect(
			result.image,
			Rect2i(0, 0, ATLAS_WIDTH, result.image.get_height()),
			Vector2i(0, result.row)
		)
	image.save_png(job.path)
	image.generate_mipmaps()
	job.image = image


func _poll_atlas_job() -> void:
	if not atlas_job.is_empty():
		if not atlas_job.has("finish_task"):
			for worker in atlas_job.workers:
				if worker.is_alive():
					return
			var tiles: Array = []
			for worker in atlas_job.workers:
				tiles.append(worker.wait_to_finish())
			atlas_job.finish_task = WorkerThreadPool.add_task(
				_finish_atlas_image.bind(atlas_job, tiles)
			)
			return
		if not WorkerThreadPool.is_task_completed(int(atlas_job.finish_task)):
			return
		WorkerThreadPool.wait_for_task_completion(int(atlas_job.finish_task))
		_trim_disk_atlases(atlas_job.path)
		var texture := ImageTexture.create_from_image(atlas_job.image)
		if atlas_cache.size() >= 2:
			atlas_cache.erase(atlas_cache.keys()[0])
		atlas_cache[atlas_job.key] = texture
		last_refinement_ms = Time.get_ticks_msec() - int(atlas_job.started)
		if str(atlas_job.key) == current_atlas_key:
			geography_atlas = texture
			if globe_shader != null:
				globe_shader.set_shader_parameter("atlas", texture)
			if flat_shader != null:
				flat_shader.set_shader_parameter("atlas", texture)
			atlas_refining = false
			if pending_atlas.get("key", "") == atlas_job.key:
				pending_atlas.clear()
			atlas_refined.emit()
		print(
			"MAP_ATLAS_REFINED ms=", last_refinement_ms, " key=", str(atlas_job.key).sha256_text()
		)
		atlas_job.clear()
	if pending_atlas.is_empty():
		return
	atlas_job = pending_atlas.duplicate()
	pending_atlas.clear()
	atlas_job.started = Time.get_ticks_msec()
	atlas_job.workers = []
	var count: int = clampi(OS.get_processor_count() / 2, 2, 6)
	for tile in range(count):
		var worker := Thread.new()
		worker.start(
			_render_atlas_tile.bind(
				tile,
				count,
				int(atlas_job.seed),
				str(atlas_job.version),
				ATLAS_WIDTH,
				ATLAS_HEIGHT,
				atlas_job.context
			)
		)
		atlas_job.workers.append(worker)


func _trim_disk_atlases(current: String) -> void:
	var files: Array = []
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("world_atlas_") and file.ends_with(".png"):
			var path: String = "user://" + file
			if path != current:
				files.append({"path": path, "time": FileAccess.get_modified_time(path)})
	files.sort_custom(func(a, b): return a.time > b.time)
	for i in range(1, files.size()):
		DirAccess.remove_absolute(files[i].path)


func _build_clouds() -> void:
	cloud_shader = ShaderMaterial.new()
	cloud_shader.shader = Shaders.shader("clouds")
	cloud_shader.set_shader_parameter("noise3d", Shaders.noise_texture())
	cloud_shader.set_shader_parameter("coverage", _cloud_coverage())
	cloud_shell = _sphere(planet, Vector3.ZERO, 3.026, cloud_shader, 128, 64)
	cloud_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The colony's lights for the night side (light_field.gd): every building at its plot, lit as it
## is used, and the few lamps where roads leave town. Repainted only when what it shows has changed.
func _update_night_lights() -> void:
	var buildings: Dictionary = Rules.read("economy").buildings
	var image: Image = NightLights.paint(
		LightField.lights(state, world, buildings, landing_camps(), harbor_spots())
	)
	if night_lights == null:
		night_lights = ImageTexture.create_from_image(image)
	else:
		night_lights.update(image)
	town_lights = NightLights.town_uniforms()
	for material: ShaderMaterial in [globe_shader, flat_shader]:
		_apply_town_lights(material)


## Each settled town's landing camp in district units, as the district stands its pods: found once
## per town (region_ground `landing_spot`), since plots and water do not move.
func landing_camps() -> Dictionary:
	var camps: Dictionary = {}
	for settlement: Dictionary in state.get("settlements", []):
		var region: int = int(settlement.get("region", -1))
		if region < 0 or region >= world.get("regions", []).size():
			continue
		if not camp_cache.has(region):
			# The district's field size clips its rivers; it depends only on the world.
			_fit_field()
			camp_cache[region] = (
				landing_spot(region) if Geo.is_generated(str(world.version)) else Vector2(-6.0, 0.0)
			)
		camps[region] = camp_cache[region]
	return camps


## Each settled coastal town's quay (region_view `harbor_spot`), for its night lights.
func harbor_spots() -> Dictionary:
	var spots: Dictionary = {}
	if not Geo.is_generated(str(world.version)):
		return spots
	for settlement: Dictionary in state.get("settlements", []):
		var region: int = int(settlement.get("region", -1))
		if region < 0 or region >= world.get("regions", []).size():
			continue
		if bool(world.regions[region].get("coast", false)):
			_fit_field()
			spots[region] = harbor_spot(region)
	return spots


func _update_markers() -> void:
	_update_flat_markers()
	if marker_root == null or not is_instance_valid(marker_root):
		return
	for child in marker_root.get_children():
		marker_root.remove_child(child)
		child.queue_free()
	var labelled: Dictionary = {}
	for reg: Dictionary in _labelled_sites():
		labelled[int(reg.id)] = true
	for reg in world.regions:
		if _marker_shown(reg):
			_globe_marker(reg, labelled.has(int(reg.id)))
	_globe_signals()
	_globe_anomalies()
	_globe_ground_cursor()
	_draw_globe_climate()


## The picked ground (1.10 free placement): a white ring and cross at the exact point.
## The prospecting anomalies on the globe, as on the flat map (`_flat_anomalies`).
func _globe_anomalies() -> void:
	for anomaly: Dictionary in state.get("prospecting", {}).get("anomalies", []):
		var colour: Color = ANOMALY_COLORS.get(str(anomaly.resource), Color.WHITE)
		var center: Vector3 = Geo.unit_point(float(anomaly.lat), float(anomaly.lon))
		var root := Node3D.new()
		root.set_meta("point", center * 3.05)
		marker_root.add_child(root)
		var u: Vector3 = center.cross(Vector3.UP)
		if u.length() < 0.01:
			u = center.cross(Vector3.RIGHT)
		u = u.normalized()
		var v: Vector3 = center.cross(u).normalized()
		var reach: float = deg_to_rad(float(anomaly.zone))
		var ring: Array[Vector3] = []
		for i in range(49):
			var angle: float = float(i) / 48.0 * TAU
			var direction: Vector3 = u * cos(angle) + v * sin(angle)
			ring.append((center * cos(reach) + direction * sin(reach)).normalized() * 3.05)
		_line(root, ring, colour, 1.4)
		if str(anomaly.stage) == "drilled":
			var dot: Material = _mat("anomaly_" + str(anomaly.resource), colour, 0, 1, 1.4)
			_sphere(root, center * 3.05, .014, dot, 8, 4)


func _globe_ground_cursor() -> void:
	if ground_point.is_empty():
		return
	var center: Vector3 = Geo.unit_point(float(ground_point.lat), float(ground_point.lon))
	var root := Node3D.new()
	root.set_meta("point", center * 3.05)
	marker_root.add_child(root)
	var u: Vector3 = center.cross(Vector3.UP)
	if u.length() < 0.01:
		u = center.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = center.cross(u).normalized()
	var ring: Array[Vector3] = []
	for i in range(41):
		var angle: float = float(i) / 40.0 * TAU
		var reach: float = deg_to_rad(GROUND_CURSOR_DEGREES)
		var direction: Vector3 = u * cos(angle) + v * sin(angle)
		ring.append((center * cos(reach) + direction * sin(reach)).normalized() * 3.052)
	_line(root, ring, GROUND_CURSOR_COLOR, 1.6)
	for axis: Vector3 in [u, v]:
		var cross: Array[Vector3] = []
		for t: float in [-1.6, -0.5]:
			var reach: float = deg_to_rad(GROUND_CURSOR_DEGREES * t)
			cross.append((center * cos(reach) + axis * sin(reach)).normalized() * 3.052)
		_line(root, cross, GROUND_CURSOR_COLOR, 1.6)
		cross = []
		for t: float in [0.5, 1.6]:
			var reach: float = deg_to_rad(GROUND_CURSOR_DEGREES * t)
			cross.append((center * cos(reach) + axis * sin(reach)).normalized() * 3.052)
		_line(root, cross, GROUND_CURSOR_COLOR, 1.6)
	_sphere(root, center * 3.052, .012, _mat("ground_dot", GROUND_CURSOR_COLOR, 0, 1, 1.6), 8, 4)


## Each settled coastal town's offshore signal while it is unknown or rich: a gold ring out over
## the water, the reason to come back once a harbour can send a survey boat.
func _globe_signals() -> void:
	for s: Dictionary in state.get("settlements", []):
		var region: int = int(s.get("region", -1))
		if signal_reading(region).is_empty():
			continue
		_fit_field()
		var at: Vector2 = signal_point(region)
		if not at.is_finite():
			continue
		var center: Vector3 = Geo.unit_point(at.x, at.y)
		var root := Node3D.new()
		root.set_meta("point", center * 3.05)
		marker_root.add_child(root)
		var u: Vector3 = center.cross(Vector3.UP)
		if u.length() < 0.01:
			u = center.cross(Vector3.RIGHT)
		u = u.normalized()
		var v: Vector3 = center.cross(u).normalized()
		var reach: float = deg_to_rad(0.55)
		var ring: Array[Vector3] = []
		for i in range(33):
			var angle: float = float(i) / 32.0 * TAU
			var direction: Vector3 = u * cos(angle) + v * sin(angle)
			ring.append((center * cos(reach) + direction * sin(reach)).normalized() * 3.05)
		_line(root, ring, SIGNAL_COLOR, 1.1)
		_sphere(root, center * 3.05, .01, _mat("signal_dot", SIGNAL_COLOR, 0, 1, 1.4), 8, 4)


func _globe_marker(reg: Dictionary, with_label: bool) -> void:
	var root := Node3D.new()
	var point: Vector3 = Geo.unit_point(reg.lat, reg.lon) * 3.052
	root.set_meta("point", point)
	marker_root.add_child(root)
	var settled: bool = _is_settled(int(reg.id))
	var c := Color("e8c77f") if settled else Color("76e5d6")
	if int(reg.id) == selected_region:
		c = Color("fff0b9")
	var dot := _sphere(
		root, point, .036 if settled else .025, _mat("marker" + c.to_html(), c, 0, 1, 1.6), 12, 6
	)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_points: Array[Vector3] = []
	var normal := point.normalized()
	var tangent := normal.cross(Vector3.UP).normalized()
	var bitangent := normal.cross(tangent).normalized()
	for k in range(41):
		var angle := float(k) / 40.0 * TAU
		ring_points.append(
			(
				(
					(normal * 3.058 + tangent * cos(angle) * .074 + bitangent * sin(angle) * .074)
					. normalized()
				)
				* 3.058
			)
		)
	_line(root, ring_points, c, .85)
	if with_label:
		var label := Label3D.new()
		label.text = _site_name(reg, settled)
		label.font = label_font
		label.font_size = 48
		label.pixel_size = .0028
		label.position = point + Vector3(0, .15, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = c
		label.outline_modulate = Color("091621")
		label.outline_size = 8
		root.add_child(label)
	if not settled:
		return
	var sizes: Dictionary = _footprint_sizes(_settlement_at(int(reg.id)))
	if float(sizes.farmland) > 0.0:
		_disc(root, normal * 3.0205, normal, float(sizes.farmland), _globe_footprint_mat("farm"))
	_disc(root, normal * 3.021, normal, float(sizes.town), _globe_footprint_mat("town"))


## The flat map's footprint colours, fading on the night side of the globe.
func _globe_footprint_mat(kind: String) -> ShaderMaterial:
	var key: String = "globe_footprint_" + kind
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = Shaders.shader("footprint")
		material.set_shader_parameter("tint", _footprint_mat(kind).albedo_color)
		mats[key] = material
	return mats[key]


func _settlement_at(id: int) -> Dictionary:
	for settlement in state.get("settlements", []):
		if int(settlement.region) == id:
			return settlement
	return {}


func _draw_globe_climate() -> void:
	var at: Dictionary = _climate_site()
	if at.is_empty():
		return
	var center: Vector3 = Geo.unit_point(float(at.lat), float(at.lon))
	var seedling: Vector3 = Vector3.UP if absf(center.y) < 0.9 else Vector3.RIGHT
	var u: Vector3 = center.cross(seedling).normalized()
	var v: Vector3 = center.cross(u).normalized()
	var reach: float = deg_to_rad(float(at.radius))
	var points: Array[Vector3] = []
	for i in range(97):
		var angle: float = float(i) / 96.0 * TAU
		var direction: Vector3 = u * cos(angle) + v * sin(angle)
		points.append((center * cos(reach) + direction * sin(reach)).normalized() * 3.03)
	_line(marker_root, points, Color("6fd8c0"), .9)


func _update_transport() -> void:
	_update_flat_transport()
	if transport_root == null or not is_instance_valid(transport_root):
		return
	for root: Node3D in [transport_root, mover_root]:
		if root == null or not is_instance_valid(root):
			continue
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	globe_movers.clear()
	for r: Dictionary in state.get("roads", []):
		if not bool(r.get("retired", false)):
			_draw_road_on_globe(r)
	_place_movers(globe_movers, sky.day_fraction)
	globe_ships = _ship_movers(false)
	place_ships(globe_ships, sky.day_fraction)


func _road_color(r: Dictionary) -> Color:
	var day: int = int(state.get("day", 0))
	if Geo.road_building(r, day):
		return Color("8fa1a8")
	if Geo.road_blocked(r, day):
		return Color("d77963")
	return SHUTTLE_COLOR if str(r.get("variant", "")) == "shuttle" else Color("e9bf71")


func _draw_road_on_globe(r: Dictionary) -> void:
	var coordinates: Array = r.get("coordinates", []).duplicate()
	if coordinates.is_empty():
		for index in r.get("path", []):
			var ll: Vector2 = Geo.cell_coordinate(int(index))
			coordinates.append([ll.x, ll.y])
	var points: Array[Vector3] = []
	# A shuttle line flies: it arcs up from both pads instead of lying on the ground.
	var lift: float = SHUTTLE_ARC if str(r.get("variant", "")) == "shuttle" else 0.0
	for index: int in range(coordinates.size()):
		var ll: Array = coordinates[index]
		var along: float = float(index) / maxf(1.0, float(coordinates.size() - 1))
		points.append(Geo.unit_point(float(ll[0]), float(ll[1])) * (3.048 + lift * sin(PI * along)))
	_line(transport_root, points, _road_color(r), 1.5)
	for shipment in state.get("shipments", []):
		if points.is_empty() or int(shipment.get("road", 0)) != int(r.get("id", 0)):
			continue
		var marker := _sphere(
			mover_root if mover_root != null else transport_root,
			points[0],
			CARGO_DOT_GLOBE,
			_mat("shipment", Color("ffedc2"), 0, 1, CARGO_GLOW),
			8,
			4
		)
		globe_movers.append(_mover(marker, points, shipment, r, INF))
