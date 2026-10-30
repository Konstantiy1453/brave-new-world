extends Node3D
## Native lightweight 3D renderer. Every geography query uses WorldGen.
signal region_selected(id: int)
signal atlas_refined
signal region_progress(busy: bool, progress: float)
signal region_ready(id: int)
const Geo = preload("res://world/world_gen.gd")
static var atlas_cache: Dictionary = {}
var world: Dictionary = {}
var state: Dictionary = {}
var mode: String = "planet"
var selected_region: int = 0
var camera: Camera3D
var planet: Node3D
var flat_world: Node3D
var flat_marker_root: Node3D
var flat_transport_root: Node3D
var geography_atlas: ImageTexture
var flat_size: float = 15.8
var flat_center: Vector2 = Vector2.ZERO
var flat_user_zoomed: bool = false
var surface: Node3D
var marker_root: Node3D
var transport_root: Node3D
var buildings_root: Node3D
var cloud_shell: MeshInstance3D
var globe_shader: ShaderMaterial
var flat_shader: ShaderMaterial
var noise: FastNoiseLite
var planet_yaw: float = -.38
var planet_pitch: float = .22
var planet_distance: float = 10.3
var local_yaw: float = .68
var local_pitch: float = .75
var local_distance: float = 67.0
var smooth_yaw: float = -.38
var smooth_pitch: float = .22
var smooth_distance: float = 10.3
var camera_pivot: Vector3 = Vector3.ZERO
var mats: Dictionary = {}
var signature: String = ""
var selection_ring: MeshInstance3D
var region_ground: float = 0.0
var label_font: Font
var local_river_segments: Array = []
var local_lakes: Array = []
var render_rivers: Array = []
var last_setup_ms: int = 0
var last_atlas_ms: int = 0
var last_atlas_cached: bool = false
var last_atlas_source: String = ""
var atlas_refining: bool = false
var last_refinement_ms: int = 0
var current_atlas_key: String = ""
var pending_atlas: Dictionary = {}
var atlas_job: Dictionary = {}
const REGION_CACHE_LIMIT: int = 3
var region_cache: Dictionary = {}
var region_busy: bool = false
var region_load_token: int = 0
var region_build_count: int = 0
var last_region_ms: int = 0
var last_region_cached: bool = false
var terrain_unique_samples: int = 0


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
	_update_markers()
	_update_transport()
	if mode == "region" and not region_busy:
		var new_signature := _building_signature()
		if new_signature != signature:
			signature = new_signature
			_build_colony()
			surface.set_meta("building_signature", signature)


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
			"lakes": local_lakes.duplicate(true)
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


func pick_region(screen_pos: Vector2) -> int:
	if mode not in ["planet", "flat"] or camera == null:
		return -1
	var nearest: int = -1
	var best: float = 43.0
	for reg in world.regions:
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
	sun.rotation_degrees = Vector3(-26, -46, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("5ba6ca")
	fill.light_energy = .18
	fill.rotation_degrees = Vector3(35, 140, 0)
	add_child(fill)
	_build_stars()


func _mat(
	key: String, color: Color, metallic: float = 0.0, roughness: float = .75, emission: float = 0.0
) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	mats[key] = m
	return m


func _clear_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		remove_child(node)
		node.queue_free()


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


func _geo_color(g: Dictionary, lat: float, lon: float, source_noise: FastNoiseLite = null) -> Color:
	var h: float = g.height
	var active_noise: FastNoiseLite = noise if source_noise == null else source_noise
	var value: float = active_noise.get_noise_3dv(Geo.unit_point(lat, lon) * 43.0) * .16
	if absf(lat) > 76.0 + value * 22.0:
		return Color("bfced2").lightened(maxf(value * .45, 0))
	if h <= 0:
		var sea := Color("123e5c").lerp(Color("12324c"), clampf(-h * 7.0, 0, 1))
		if h > -.026:
			sea = sea.lerp(Color("278d8d"), clampf(1.0 + h / .026, 0, 1) * .7)
		return sea.lightened(maxf(value * .25, 0.0))
	var c := Color("7b9474")
	if g.temperature < -8:
		c = Color("d8e7e6")
	elif h > .65:
		c = Color("c2c5b9").lerp(Color("eff4ec"), clampf((h - .65) * 4.4, 0, 1))
	elif h > .27:
		c = Color("777b6d").lerp(Color("b0aa94"), (h - .27) * 3.0)
	elif g.rainfall < .39:
		c = Color("b9ad7d")
	elif g.temperature > 19:
		c = Color("47765f")
	elif g.temperature > 3:
		c = Color("63846b")
	if h < .022:
		c = c.lerp(Color("b7b58b"), .6)
	if g.river:
		c = Color("308f94")
	return c.lightened(maxf(value, 0)).darkened(maxf(-value, 0))


func _build_planet() -> void:
	# Both global modes share this authoritative atlas: no second random map.
	var atlas_start: int = Time.get_ticks_msec()
	var cache_key: String = (
		"atlas-1536-r4-seed32:"
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
		if image != null and image.get_width() == 1536 and image.get_height() == 768:
			last_atlas_cached = true
		else:
			var context: Dictionary = (
				Geo.SeedGeo.context(int(world.seed)).duplicate(true)
				if str(world.version) != "CC-GEO-1.4"
				else {}
			)
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
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction=vec3(-.7,.48,.48);
varying vec3 object_normal;
void vertex(){object_normal=normalize(VERTEX);}
void fragment(){
 vec3 n=normalize(object_normal);
 vec2 uv=vec2(atan(n.x,n.z)/6.283185307+.5,.5-asin(clamp(n.y,-1.0,1.0))/3.14159265);
 // atan() jumps at the antimeridian. The half-turn copy of u is continuous there, so the
 // smaller of the two derivatives keeps the mip level correct on both sides of the seam.
 vec2 wrapped=vec2(fract(uv.x+.5),uv.y);
 vec2 ddx=vec2(abs(dFdx(uv.x))<abs(dFdx(wrapped.x))?dFdx(uv.x):dFdx(wrapped.x),dFdx(uv.y));
 vec2 ddy=vec2(abs(dFdy(uv.x))<abs(dFdy(wrapped.x))?dFdy(uv.x):dFdy(wrapped.x),dFdy(uv.y));
 vec4 tex=textureGrad(atlas,uv,ddx,ddy);
 vec2 step_uv=1.0/vec2(textureSize(atlas,0));
 float relief=clamp((textureGrad(atlas,uv-vec2(step_uv.x,0),ddx,ddy).a-textureGrad(atlas,uv+vec2(step_uv.x,0),ddx,ddy).a+textureGrad(atlas,uv-vec2(0,step_uv.y),ddx,ddy).a-textureGrad(atlas,uv+vec2(0,step_uv.y),ddx,ddy).a)*26.0,-.24,.24);
 relief*=smoothstep(.50,.57,tex.a);
 float daylight=max(dot(n,normalize(sun_direction)),0.0);
 float shade=.065+daylight*.83;
 ALBEDO=tex.rgb*shade*(1.0+relief);
}
"""
	globe_shader = ShaderMaterial.new()
	globe_shader.shader = shader
	globe_shader.set_shader_parameter("atlas", geography_atlas)
	if str(world.version) != "CC-GEO-1.4" and not world.regions.is_empty():
		globe_shader.set_shader_parameter(
			"sun_direction",
			Geo.unit_point(float(world.regions[0].lat) + 15, float(world.regions[0].lon) - 32)
		)
	var sphere := SphereMesh.new()
	sphere.radius = 3
	sphere.height = 6
	sphere.radial_segments = 160
	sphere.rings = 80
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = globe_shader
	planet.add_child(mesh)
	var atmosphere_shader := Shader.new()
	atmosphere_shader.code = """
shader_type spatial;
render_mode unshaded,blend_add,cull_back,depth_draw_never;
void fragment(){float f=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),4.0);ALBEDO=vec3(.12,.48,.7)*f;ALPHA=f*.40;}
"""
	var am := ShaderMaterial.new()
	am.shader = atmosphere_shader
	_sphere(planet, Vector3.ZERO, 3.08, am, 96, 48)
	_build_clouds()
	marker_root = Node3D.new()
	planet.add_child(marker_root)
	transport_root = Node3D.new()
	planet.add_child(transport_root)
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
			var ll := Geo.cell_coordinate(y * width + x)
			var cell: Dictionary = world.grid[y * width + x].duplicate()
			cell.river = false  # rivers already have a persisted geometry overlay
			var color := _geo_color(cell, ll.x, ll.y)
			color.a = clampf(.5 + float(cell.height) * .45, .01, .99)
			image.set_pixel(x, y, color)
	return image


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
			var g: Dictionary = (
				Geo.sample_geo(lat, lon, tile_noise, version)
				if version == "CC-GEO-1.4"
				else Geo.SeedGeo.sample_with_context(lat, lon, tile_noise, context)
			)
			var color := _geo_color(g, lat, lon, tile_noise)
			color.a = clampf(.5 + float(g.height) * .45, .01, .99)
			image.set_pixel(x, y - row_start, color)
	return {"image": image, "row": row_start}


func _poll_atlas_job() -> void:
	if not atlas_job.is_empty():
		for worker in atlas_job.workers:
			if worker.is_alive():
				return
		var image := Image.create(1536, 768, false, Image.FORMAT_RGBA8)
		for worker in atlas_job.workers:
			var result: Dictionary = worker.wait_to_finish()
			image.blit_rect(
				result.image, Rect2i(0, 0, 1536, result.image.get_height()), Vector2i(0, result.row)
			)
		image.save_png(atlas_job.path)
		_trim_disk_atlases(atlas_job.path)
		image.generate_mipmaps()
		var texture := ImageTexture.create_from_image(image)
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
				1536,
				768,
				atlas_job.context
			)
		)
		atlas_job.workers.append(worker)


func _exit_tree() -> void:
	cancel_region_load()
	# Thread workers must finish before their script owner is destroyed.
	for worker in atlas_job.get("workers", []):
		worker.wait_to_finish()


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


func _build_global_water(parent: Node3D, flat: bool) -> void:
	# This overlay reads the same persisted river paths as the regional view.
	for river in render_rivers:
		var coordinates: Array = river.coordinates
		var points: Array[Vector3] = []
		for ll in coordinates:
			var point: Vector3 = (
				_flat_point(float(ll[0]), float(ll[1]))
				if flat
				else Geo.unit_point(float(ll[0]), float(ll[1])) * 3.009
			)
			if flat and not points.is_empty() and absf(point.x - points.back().x) > 9:
				_line(parent, points, Color("397f91"), .05)
				points.clear()
			points.append(point)
		_line(parent, points, Color("397f91"), .05)
	for lake in world.get("lakes", []):
		var lat: float = float(lake.lat)
		var lon: float = float(lake.lon)
		var radius: float = float(lake.get("radius_degrees", .45))
		var center: Vector3 = _flat_point(lat, lon) if flat else Geo.unit_point(lat, lon) * 3.013
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(32):
			var angle_a: float = TAU * float(i) / 32
			var angle_b: float = TAU * float(i + 1) / 32
			var la: Vector2 = Vector2(
				clampf(lat + cos(angle_a) * radius, -89.95, 89.95),
				wrapf(lon + sin(angle_a) * radius / maxf(cos(deg_to_rad(lat)), .15), -180, 180)
			)
			var lb: Vector2 = Vector2(
				clampf(lat + cos(angle_b) * radius, -89.95, 89.95),
				wrapf(lon + sin(angle_b) * radius / maxf(cos(deg_to_rad(lat)), .15), -180, 180)
			)
			var a: Vector3 = _flat_point(la.x, la.y) if flat else Geo.unit_point(la.x, la.y) * 3.013
			var b: Vector3 = _flat_point(lb.x, lb.y) if flat else Geo.unit_point(lb.x, lb.y) * 3.013
			if flat and (absf(center.x - a.x) > 9 or absf(center.x - b.x) > 9):
				continue
			for point in [center, a, b]:
				st.add_vertex(point)
		st.generate_normals()
		var material := _mat("global_lake", Color("327c91"), .1, .4, .12)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(parent, st.commit(), Vector3.ZERO, material)


func _prepare_render_rivers() -> void:
	# Round only the corners of the persisted coarse-grid channels. The same
	# subcell centerline and monotone height interpolation feed all three views.
	render_rivers.clear()
	var metadata: Array = world.get("river_metadata", [])
	var rivers: Array = world.get("rivers", [])
	for river_index in range(rivers.size()):
		var raw = rivers[river_index]
		var coordinates: Array = raw.get("coordinates", []) if raw is Dictionary else raw
		var heights: Array = (
			metadata[river_index].get("heights", []) if river_index < metadata.size() else []
		)
		var samples: Array[Vector3] = []
		for i in range(coordinates.size()):
			var ll = coordinates[i]
			var h: float = (
				float(heights[i])
				if i < heights.size()
				else float(
					Geo.sample_geo(float(ll[0]), float(ll[1]), noise, str(world.version)).height
				)
			)
			var lon: float = float(ll[1])
			if not samples.is_empty():
				lon = samples.back().x + wrapf(lon - samples.back().x, -180, 180)
			samples.append(Vector3(lon, float(ll[0]), h))
		if samples.size() < 2:
			continue
		var rounded: Array[Vector3] = [samples[0]]
		for i in range(1, samples.size() - 1):
			var a: Vector3 = samples[i - 1].lerp(samples[i], .76)
			var b: Vector3 = samples[i].lerp(samples[i + 1], .24)
			rounded.append(a)
			for step in range(1, 7):
				var t: float = float(step) / 6
				rounded.append(a.lerp(samples[i], t).lerp(samples[i].lerp(b, t), t))
		rounded.append(samples.back())
		var output: Array = []
		var output_heights: Array = []
		for point in rounded:
			output.append([point.y, wrapf(point.x, -180, 180)])
			output_heights.append(point.z)
		render_rivers.append(
			{"coordinates": output, "heights": output_heights, "river_index": river_index}
		)


func _flat_point(lat: float, lon: float) -> Vector3:
	return Vector3(lon / 20.0, lat / 20.0, .035)


func _build_flat() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D atlas:source_color,filter_linear_mipmap,repeat_disable;
void fragment(){
 vec4 tex=texture(atlas,UV);
 vec2 step_uv=1.0/vec2(textureSize(atlas,0));
 float relief=clamp((texture(atlas,UV-vec2(step_uv.x,0)).a-texture(atlas,UV+vec2(step_uv.x,0)).a+texture(atlas,UV-vec2(0,step_uv.y)).a-texture(atlas,UV+vec2(0,step_uv.y)).a)*26.0,-.24,.24);
 relief*=smoothstep(.50,.57,tex.a);
 ALBEDO=tex.rgb*(.76+relief);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", geography_atlas)
	flat_shader = material
	var sheet := QuadMesh.new()
	sheet.size = Vector2(18, 9)
	_mesh(flat_world, sheet, Vector3.ZERO, material)
	# A restrained cartographic frame, not the regional construction grid.
	var frame: Array[Vector3] = [
		Vector3(-9, -4.5, .02),
		Vector3(9, -4.5, .02),
		Vector3(9, 4.5, .02),
		Vector3(-9, 4.5, .02),
		Vector3(-9, -4.5, .02)
	]
	_line(flat_world, frame, Color("5a8491"), .15)
	for lon in range(-180, 181, 60):
		var p := _flat_point(90, lon)
		_line(flat_world, [p, p + Vector3(0, .12, 0)], Color("718e9c"), .1)
		_flat_label(flat_world, Vector3(p.x, 4.78, .03), "%d°" % lon, Color("8da6b4"), .0065, 26)
	for lat in [-60, -30, 0, 30, 60]:
		_flat_label(
			flat_world, Vector3(-9.38, lat / 20.0, .03), "%d°" % lat, Color("8da6b4"), .0065, 26
		)
	_flat_label(flat_world, Vector3(0, -4.9, .03), "全球勘察图  /  等距经纬投影", Color("90aeb9"), .0068, 30)
	flat_marker_root = Node3D.new()
	flat_world.add_child(flat_marker_root)
	flat_transport_root = Node3D.new()
	flat_world.add_child(flat_transport_root)
	_build_global_water(flat_world, true)
	_update_flat_markers()
	_update_flat_transport()


func _flat_label(
	parent: Node3D,
	pos: Vector3,
	text: String,
	color: Color,
	pixel_size: float = .003,
	font_size: int = 36
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = label_font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.position = pos
	label.no_depth_test = true
	label.modulate = color
	label.outline_modulate = Color("071623")
	label.outline_size = 7
	parent.add_child(label)
	return label


func _update_flat_markers() -> void:
	if flat_marker_root == null or not is_instance_valid(flat_marker_root):
		return
	for child in flat_marker_root.get_children():
		flat_marker_root.remove_child(child)
		child.queue_free()
	for reg in world.regions:
		var settled: bool = false
		for settlement in state.get("settlements", []):
			if int(settlement.region) == int(reg.id):
				settled = true
		var color := Color("edc779") if settled else Color("7ae0d6")
		if int(reg.id) == selected_region:
			color = Color("fff2bd")
		var point := _flat_point(reg.lat, reg.lon)
		var ring: Array[Vector3] = []
		for i in range(41):
			var angle := float(i) / 40.0 * TAU
			ring.append(
				(
					point
					+ (
						Vector3(cos(angle), sin(angle), 0)
						* (.085 if int(reg.id) == selected_region else .055)
					)
				)
			)
		var holder := Node3D.new()
		flat_marker_root.add_child(holder)
		_line(holder, ring, color, .8)
		_sphere(
			holder,
			point,
			.025,
			_mat("flatdot" + str(reg.id) + str(selected_region) + str(settled), color, 0, 1, 1.3),
			8,
			4
		)
		# Fixed cartographic offsets keep the clustered starting candidates readable.
		var label_offset: Vector3 = Vector3(.65, .26, .03)
		if int(reg.id) == 0:
			label_offset = Vector3(-.80, .3, .03)
		if int(reg.id) == 3:
			label_offset = Vector3(-.90, -.20, .03)
		if int(reg.id) == 2:
			label_offset = Vector3(.65, .48, .03)
		if int(reg.id) == 1:
			label_offset = Vector3(.90, -.15, .03)
		if int(reg.id) == 5:
			label_offset = Vector3(.40, -.25, .03)
		var label_position: Vector3 = point + label_offset
		label_position.x = clampf(label_position.x, -8.0, 8.0)
		_flat_label(
			holder,
			label_position,
			("◆ " if settled else "%02d " % (int(reg.id) + 1)) + str(reg.name),
			color,
			.0068,
			40
		)


func _update_flat_transport() -> void:
	if flat_transport_root == null or not is_instance_valid(flat_transport_root):
		return
	for child in flat_transport_root.get_children():
		flat_transport_root.remove_child(child)
		child.queue_free()
	var route: Dictionary = state.get("route", {})
	if not route.get("reachable", false):
		return
	var route_color := (
		Color("d77963") if Geo.road_blocked(route, int(state.get("day", 0))) else Color("e7bb75")
	)
	var coordinates: Array = route.get("coordinates", []).duplicate()
	if coordinates.is_empty():
		for index in route.get("path", []):
			var ll: Vector2 = Geo.cell_coordinate(int(index))
			coordinates.append([ll.x, ll.y])
	var points: Array[Vector3] = []
	var segment: Array[Vector3] = []
	for ll in coordinates:
		var point := _flat_point(float(ll[0]), float(ll[1])) + Vector3(0, 0, .02)
		if not segment.is_empty() and absf(point.x - segment.back().x) > 9:
			_line(flat_transport_root, segment, route_color, 1.1)
			segment.clear()
		segment.append(point)
		points.append(point)
	_line(flat_transport_root, segment, route_color, 1.1)
	for shipment in state.get("shipments", []):
		if points.is_empty():
			continue
		var progress: float = clampf(
			(
				1.0
				- (
					float(shipment.get("remaining", 1))
					/ maxf(float(shipment.get("total_days", 1)), 1.0)
				)
			),
			0,
			1
		)
		if int(shipment.get("from", -1)) == int(route.get("b", -2)):
			progress = 1.0 - progress
		var index: int = clampi(int(progress * (points.size() - 1)), 0, points.size() - 1)
		_sphere(
			flat_transport_root,
			points[index] + Vector3(0, 0, .03),
			.031,
			_mat("flatshipment", Color("fff0bd"), 0, 1, 2),
			8,
			4
		)


func _build_clouds() -> void:
	var image := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	var cloud_noise := FastNoiseLite.new()
	cloud_noise.seed = int(world.seed) + 79
	cloud_noise.frequency = 1.8
	cloud_noise.fractal_octaves = 4
	for y in range(256):
		for x in range(512):
			var p: Vector3 = Geo.unit_point(90.0 - y * 180.0 / 256.0, x * 360.0 / 512.0 - 180.0)
			var n: float = cloud_noise.get_noise_3dv(p * 2.6)
			var a: float = clampf((n - .12) * 1.3, 0, .16)
			image.set_pixel(x, y, Color(.85, .94, .98, a))
	image.generate_mipmaps()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode blend_mix,depth_draw_never;
uniform sampler2D clouds:source_color,filter_linear_mipmap,repeat_enable;
varying vec3 point;
void vertex(){point=normalize(VERTEX);}
void fragment(){
 vec3 p=normalize(point);
 vec2 uv=vec2(atan(p.x,p.z)/6.2831853+.5,.5-asin(p.y)/3.14159265);
 vec2 wrapped=vec2(fract(uv.x+.5),uv.y);
 vec2 ddx=vec2(abs(dFdx(uv.x))<abs(dFdx(wrapped.x))?dFdx(uv.x):dFdx(wrapped.x),dFdx(uv.y));
 vec2 ddy=vec2(abs(dFdy(uv.x))<abs(dFdy(wrapped.x))?dFdy(uv.x):dFdy(wrapped.x),dFdy(uv.y));
 vec4 c=textureGrad(clouds,uv,ddx,ddy);
 ALBEDO=c.rgb;
 ROUGHNESS=1.0;
 ALPHA=c.a;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = s
	sm.set_shader_parameter("clouds", ImageTexture.create_from_image(image))
	cloud_shell = _sphere(planet, Vector3.ZERO, 3.026, sm, 96, 48)
	cloud_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_markers() -> void:
	_update_flat_markers()
	if marker_root == null or not is_instance_valid(marker_root):
		return
	for child in marker_root.get_children():
		marker_root.remove_child(child)
		child.queue_free()
	for reg in world.regions:
		var root := Node3D.new()
		var point: Vector3 = Geo.unit_point(reg.lat, reg.lon) * 3.052
		root.set_meta("point", point)
		marker_root.add_child(root)
		var settled: bool = false
		for settlement in state.get("settlements", []):
			if int(settlement.region) == int(reg.id):
				settled = true
		var c := Color("e8c77f") if settled else Color("76e5d6")
		if int(reg.id) == selected_region:
			c = Color("fff0b9")
		var dot := _sphere(
			root,
			point,
			.036 if settled else .025,
			_mat("marker" + str(reg.id) + str(settled) + str(selected_region), c, 0, 1, 1.6),
			12,
			6
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
						(
							normal * 3.058
							+ tangent * cos(angle) * .074
							+ bitangent * sin(angle) * .074
						)
						. normalized()
					)
					* 3.058
				)
			)
		_line(root, ring_points, c, .85)
		var label := Label3D.new()
		label.text = ("◆ " if settled else "%02d  " % (int(reg.id) + 1)) + str(reg.name)
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
		if settled:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + int(reg.id)
			for j in range(15):
				var light_point: Vector3 = (
					(
						(
							normal * 3.02
							+ tangent * rng.randf_range(-.055, .055)
							+ bitangent * rng.randf_range(-.055, .055)
						)
						. normalized()
					)
					* 3.012
				)
				_sphere(
					root, light_point, .005, _mat("citylight", Color("ffcf7a"), 0, 1, 2.8), 5, 3
				)


func _update_transport() -> void:
	_update_flat_transport()
	if transport_root == null or not is_instance_valid(transport_root):
		return
	for child in transport_root.get_children():
		transport_root.remove_child(child)
		child.queue_free()
	var r: Dictionary = state.get("route", {})
	if not r.get("reachable", false):
		return
	var coordinates: Array = r.get("coordinates", []).duplicate()
	if coordinates.is_empty():
		for index in r.get("path", []):
			var ll: Vector2 = Geo.cell_coordinate(int(index))
			coordinates.append([ll.x, ll.y])
	var points: Array[Vector3] = []
	for ll in coordinates:
		points.append(Geo.unit_point(float(ll[0]), float(ll[1])) * 3.048)
	_line(
		transport_root,
		points,
		Color("d77963") if Geo.road_blocked(r, int(state.get("day", 0))) else Color("e9bf71"),
		1.5
	)
	for shipment in state.get("shipments", []):
		if points.is_empty():
			continue
		var progress: float = clampf(
			(
				1.0
				- (
					float(shipment.get("remaining", 1))
					/ maxf(float(shipment.get("total_days", 1)), 1.0)
				)
			),
			0.0,
			1.0
		)
		if int(shipment.get("from", -1)) == int(r.get("b", -2)):
			progress = 1.0 - progress
		var index: int = clampi(int(progress * (points.size() - 1)), 0, points.size() - 1)
		_sphere(
			transport_root, points[index], .023, _mat("shipment", Color("ffedc2"), 0, 1, 2), 8, 4
		)


func _ground(x: float, z: float) -> float:
	var ll := _local_coordinate(x, z)
	var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	return _ground_from_geo(x, z, g, ll)


func _ground_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	var reg: Dictionary = world.regions[selected_region]
	if not bool(g.land):
		return (
			-1.0 + float(g.height) * 30.0
			if str(world.version) == "CC-GEO-1.4"
			else (float(g.height) - region_ground) * 30.0
		)
	var detail: float = noise.get_noise_2d(x * .65, z * .65) * .33
	var raw: float = (float(g.height) - region_ground) * 30.0 + detail
	# Planned development terraces blend smoothly into the actual regional relief.
	var town_center := Vector2(12.0 if reg.river else 0.0, 0)
	var d: float = Vector2(x, z).distance_to(town_center)
	var blend: float = smoothstep(9.0, 18.0, d)
	var height: float = lerpf(.25, raw, blend)
	if reg.river and str(world.version) == "CC-GEO-1.4":
		var river_x: float = (Geo.river_lon(ll.x) - float(reg.lon)) * 4.0
		var river_dist: float = absf(x - river_x)
		if river_dist < 2.8:
			height = lerpf(-.55, height, smoothstep(.9, 2.8, river_dist))
	elif str(world.version) != "CC-GEO-1.4":
		var p := Vector2(x, z)
		for segment in local_river_segments:
			var a: Vector2 = segment.a
			var b: Vector2 = segment.b
			var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
			var distance: float = p.distance_to(a.lerp(b, t))
			var width: float = segment.width
			if distance < width * 2:
				var water: float = lerpf(segment.ya, segment.yb, t)
				height = lerpf(water - .28, height, smoothstep(width * .72, width * 2, distance))
		for lake in local_lakes:
			var distance: float = p.distance_to(lake.center)
			if distance < lake.radius * 1.25:
				height = lerpf(
					lake.height - .4,
					height,
					smoothstep(lake.radius * .8, lake.radius * 1.25, distance)
				)
	return height


func _water_height_at(x: float, z: float, margin: float = 1.0) -> float:
	var point := Vector2(x, z)
	var result: float = -INF
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var t: float = clampf((point - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
		if point.distance_to(a.lerp(b, t)) < float(segment.width) * margin:
			result = maxf(result, lerpf(segment.ya, segment.yb, t))
	for lake in local_lakes:
		if point.distance_to(lake.center) < float(lake.radius) * margin:
			result = maxf(result, lake.height)
	return result


func _local_coordinate(x: float, z: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var lat: float = float(reg.get("canonical_lat", reg.lat)) - z / 4.0
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + x / 4.0
	return Geo.project_coordinate(lat, lon, world)


func _point_to_local(lat: float, lon: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var ll: Vector2 = Geo.unproject_coordinate(lat, lon, world)
	return Vector2(
		wrapf(ll.y - float(reg.get("canonical_lon", reg.lon)), -180, 180) * 4.0,
		(float(reg.get("canonical_lat", reg.lat)) - ll.x) * 4.0
	)


func _clip_segment(a: Vector2, b: Vector2) -> Vector2:
	# Liang-Barsky against the exact local ground bounds; returns segment t's.
	var d := b - a
	var low: float = 0
	var high: float = 1
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x + 28.5, 28.5 - a.x, a.y + 23.5, 23.5 - a.y]
	for i in range(4):
		if absf(float(p[i])) < .000001:
			if float(q[i]) < 0:
				return Vector2(-1, -1)
		else:
			var t: float = float(q[i]) / float(p[i])
			if float(p[i]) < 0:
				low = maxf(low, t)
			else:
				high = minf(high, t)
			if low > high:
				return Vector2(-1, -1)
	return Vector2(low, high)


func _prepare_local_rivers() -> void:
	local_river_segments.clear()
	local_lakes.clear()
	var reg: Dictionary = world.regions[selected_region]
	region_ground = float(Geo.sample_geo(reg.lat, reg.lon, noise, str(world.version)).height)
	if str(world.version) == "CC-GEO-1.4":
		return
	var rivers: Array = render_rivers
	for river_index in range(rivers.size()):
		var river = rivers[river_index]
		var coordinates: Array = river.coordinates
		var heights: Array = river.heights
		for i in range(coordinates.size() - 1):
			var ca = coordinates[i]
			var cb = coordinates[i + 1]
			var a := _point_to_local(float(ca[0]), float(ca[1]))
			var b := _point_to_local(float(cb[0]), float(cb[1]))
			if a.distance_to(b) > 60:
				continue
			var clip := _clip_segment(a, b)
			if clip.x < 0:
				continue
			var ha: float = (
				float(heights[i])
				if i < heights.size()
				else float(
					Geo.sample_geo(float(ca[0]), float(ca[1]), noise, str(world.version)).height
				)
			)
			var hb: float = (
				float(heights[i + 1])
				if i + 1 < heights.size()
				else float(
					Geo.sample_geo(float(cb[0]), float(cb[1]), noise, str(world.version)).height
				)
			)
			var wa: float = (
				.45 + .18 * float(i) / maxi(1, coordinates.size() - 1) + .035 * sin(float(i) * .51)
			)
			var wb: float = (
				.45
				+ .18 * float(i + 1) / maxi(1, coordinates.size() - 1)
				+ .035 * sin(float(i + 1) * .51)
			)
			local_river_segments.append(
				{
					"a": a.lerp(b, clip.x),
					"b": a.lerp(b, clip.y),
					"ya": (lerpf(ha, hb, clip.x) - region_ground) * 30.0 + .04,
					"yb": (lerpf(ha, hb, clip.y) - region_ground) * 30.0 + .04,
					"width": maxf(wa, wb),
					"width_a": wa,
					"width_b": wb,
					"river_index": river_index
				}
			)
	for lake in world.get("lakes", []):
		var center := _point_to_local(float(lake.lat), float(lake.lon))
		var radius: float = float(lake.get("radius_degrees", .45)) * 4.0
		if absf(center.x) > 28.5 - radius or absf(center.y) > 23.5 - radius:
			continue
		var h: float = float(lake.get("height", float(lake.get("elevation", 0)) / 4300.0))
		local_lakes.append(
			{"center": center, "radius": radius, "height": (h - region_ground) * 30.0 + .04}
		)


func _build_terrain(token: int) -> bool:
	var reg: Dictionary = world.regions[selected_region]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = 86
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	vertices.resize((resolution + 1) * (resolution + 1))
	colors.resize(vertices.size())
	terrain_unique_samples = 0
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x: float = (float(ix) / resolution - .5) * 57.0
			var z: float = (float(iz) / resolution - .5) * 47.0
			var ll := _local_coordinate(x, z)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			terrain_unique_samples += 1
			var color := _geo_color(g, ll.x, ll.y)
			if reg.river:
				color = color.lerp(Color("59704e"), .4)
			else:
				color = color.lerp(Color("777566"), .35)
			color = color.darkened(maxf(noise.get_noise_2d(x * 2.5, z * 2.5) * .25, 0))
			if is_finite(_water_height_at(x, z, 1.9)):
				color = color.lerp(Color("354e43"), .48)
			var index: int = iz * (resolution + 1) + ix
			colors[index] = color
			vertices[index] = Vector3(x, _ground_from_geo(x, z, g, ll), z)
		if iz % 2 == 0:
			region_progress.emit(true, float(iz) / resolution * .45)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	# Preserve the original triangles and flat normals; only sampling is shared.
	for iz in range(resolution):
		for ix in range(resolution):
			for corner in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var index: int = (iz + corner.y) * (resolution + 1) + ix + corner.x
				st.set_color(colors[index])
				st.add_vertex(vertices[index])

	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	var material := _mat("terrain", Color.WHITE, 0, 1)
	material.vertex_color_use_as_albedo = true
	terrain.material_override = material
	surface.add_child(terrain)
	# Geological section of a floating regional cutaway, deliberately no debug grid.
	var border := SurfaceTool.new()
	border.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array = [
		Vector2(-28.5, -23.5), Vector2(28.5, -23.5), Vector2(28.5, 23.5), Vector2(-28.5, 23.5)
	]
	for e in range(4):
		for k in range(80):
			var a: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k) / 80)
			var b: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k + 1) / 80)
			var top_a := Vector3(a.x, _ground(a.x, a.y), a.y)
			var top_b := Vector3(b.x, _ground(b.x, b.y), b.y)
			var bottom: float = minf(-4.0, minf(top_a.y, top_b.y) - 3.0)
			for v in [
				top_a,
				Vector3(a.x, bottom, a.y),
				top_b,
				top_b,
				Vector3(a.x, bottom, a.y),
				Vector3(b.x, bottom, b.y)
			]:
				border.add_vertex(v)
	border.generate_normals()
	var skirt := MeshInstance3D.new()
	skirt.mesh = border.commit()
	skirt.material_override = _mat("strata", Color("283a3e"), .15, .95)
	surface.add_child(skirt)
	_build_river()
	if not await _build_sea(token):
		return false
	_build_nature()
	# Thin survey corner lights frame the playable terrain without a grid.
	for x in [-27.5, 27.5]:
		for z in [-22.5, 22.5]:
			var h: float = _ground(x, z)
			_cylinder(
				surface,
				Vector3(x, h + .35, z),
				.065,
				.7,
				_mat("survey", Color("71ccbe"), .3, .6, .8),
				8
			)

	return true


func _build_river() -> void:
	if str(world.version) == "CC-GEO-1.4":
		if world.regions[selected_region].river:
			_build_legacy_river()
		return
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var side_a: Vector2 = normal * float(segment.width_a)
		var side_b: Vector2 = normal * float(segment.width_b)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var aa := Vector3(a.x - side_a.x, segment.ya, a.y - side_a.y)
		var ab := Vector3(a.x + side_a.x, segment.ya, a.y + side_a.y)
		var ba := Vector3(b.x - side_b.x, segment.yb, b.y - side_b.y)
		var bb := Vector3(b.x + side_b.x, segment.yb, b.y + side_b.y)
		for vertex in [aa, ab, ba, ab, bb, ba]:
			st.add_vertex(vertex)
		st.generate_normals()
		var material := _mat("river_authoritative", Color("224f59"), .08, .36)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(surface, st.commit(), Vector3.ZERO, material)
	for lake in local_lakes:
		_cylinder(
			surface,
			Vector3(lake.center.x, lake.height, lake.center.y),
			lake.radius,
			.025,
			_mat("lakewater", Color("2e798a"), .32, .2),
			40
		)


func _build_legacy_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reg: Dictionary = world.regions[selected_region]
	for i in range(94):
		var z: float = -23.5 + i * .5
		var nz: float = z + .5
		var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0
		var nx: float = (Geo.river_lon(float(reg.lat) - nz / 4.0) - float(reg.lon)) * 4.0
		for v in [
			Vector3(x - 1.35, -.24, z),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx - 1.35, -.24, nz),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx + 1.35, -.24, nz),
			Vector3(nx - 1.35, -.24, nz)
		]:
			st.add_vertex(v)
	st.generate_normals()
	var river := MeshInstance3D.new()
	river.mesh = st.commit()
	river.material_override = _mat("river", Color("2a818b"), .42, .19)
	surface.add_child(river)
	for lane in [-.7, .25, .85]:
		var points: Array[Vector3] = []
		for i in range(94):
			var z: float = -23.5 + i * .5
			var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0 + lane
			points.append(Vector3(x, -.225, z))
		_line(surface, points, Color(.4, .7, .72, .4), .2)


func _build_sea(token: int) -> bool:
	var reg: Dictionary = world.regions[selected_region]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	var sea_height: float = (
		-.72 if str(world.version) == "CC-GEO-1.4" else -region_ground * 30.0 + .04
	)
	for iz in range(94):
		for ix in range(114):
			var x: float = -28.5 + ix * .5
			var z: float = -23.5 + iz * .5
			var ll := _local_coordinate(x, z)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			if g.land:
				continue
			for v in [
				Vector3(x, sea_height, z),
				Vector3(x + .51, sea_height, z),
				Vector3(x, sea_height, z + .51),
				Vector3(x + .51, sea_height, z),
				Vector3(x + .51, sea_height, z + .51),
				Vector3(x, sea_height, z + .51)
			]:
				st.add_vertex(v)
			count += 1
		if iz % 2 == 0:
			region_progress.emit(true, .45 + float(iz) / 94.0 * .5)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	if count == 0:
		return true
	st.generate_normals()
	var sea := MeshInstance3D.new()
	sea.mesh = st.commit()
	sea.material_override = _mat("sea", Color("285e76"), .4, .2)
	surface.add_child(sea)

	return true


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.seed) + selected_region * 173
	var reg: Dictionary = world.regions[selected_region]
	for i in range(160):
		var x: float = rng.randf_range(-27, 27)
		var z: float = rng.randf_range(-22, 22)
		var center := Vector2(12 if reg.river else 0, 0)
		if (
			Vector2(x, z).distance_to(center) < 13.0
			or _ground(x, z) < -.4
			or is_finite(_water_height_at(x, z, 1.8))
		):
			continue
		var height: float = rng.randf_range(.55, 1.8)
		var location := Vector3(x, _ground(x, z), z)
		var local_geo: Dictionary = Geo.local_geo(world, selected_region, x, z, noise)
		if not bool(local_geo.land):
			continue
		var forest_chance: float = (
			clampf((float(local_geo.rainfall) - .23) * 1.45, 0, .86)
			* smoothstep(-2, 10, float(local_geo.temperature))
		)
		if str(local_geo.get("biome", "")) in ["alpine", "desert", "tundra"]:
			forest_chance = 0
		if rng.randf() < forest_chance:
			_cylinder(
				surface,
				location + Vector3(0, height * .25, 0),
				.055,
				height * .5,
				_mat("wood", Color("4d4b3a")),
				6
			)
			var tree := _cone(
				surface,
				location + Vector3(0, height * .65, 0),
				height * .35,
				height,
				_mat("foliage" + str(i % 4), Color("304f45").lightened(float(i % 4) * .035))
			)
			tree.rotation.y = rng.randf() * TAU
		else:
			var rock := _sphere(
				surface,
				location + Vector3(0, height * .17, 0),
				height * .38,
				_mat("rock", Color("7c8174"), .1, .95),
				6,
				3
			)
			rock.scale = Vector3(1.3, .6, 1)
			rock.rotation_degrees = Vector3(0, rng.randf() * 360, rng.randf() * 25)
	# A visible geological exposure marks actual mineral-bearing ground.
	if float(reg.deposits.ore) > 6000:
		for i in range(16):
			var x: float = -16 + rng.randf_range(-3.4, 3.4)
			var z: float = -10 + rng.randf_range(-2.5, 2.5)
			var rock := _sphere(
				surface,
				Vector3(x, _ground(x, z) + .3, z),
				rng.randf_range(.4, 1.2),
				_mat("oreseam", Color("9b735a"), .33, .7),
				6,
				4
			)
			rock.scale = Vector3(1.5, .55, 1)


func _building_signature() -> String:
	for settlement in state.get("settlements", []):
		if int(settlement.region) == selected_region:
			var visible_status: Array = []
			for building in settlement.get("buildings", []):
				visible_status.append(
					[
						building.kind,
						building.get("enabled", true),
						building.get("active", false),
						int(building.get("remaining", 0)) > 0
					]
				)
			var route: Dictionary = state.get("route", {})
			var route_state: Array = [
				route.get("reachable", false),
				route.get("a", -1),
				route.get("b", -1),
				hash(route.get("path", [])),
				Geo.road_blocked(route, int(state.get("day", 0)))
			]
			return (
				JSON.stringify(visible_status)
				+ JSON.stringify(route_state)
				+ str(settlement.get("base_housing", 0))
			)
	return "unsettled"


func _build_colony() -> void:
	if buildings_root != null and is_instance_valid(buildings_root):
		if buildings_root.get_parent() != null:
			buildings_root.get_parent().remove_child(buildings_root)
		buildings_root.queue_free()
	buildings_root = Node3D.new()
	buildings_root.name = "LiveSettlementBuildings"
	surface.add_child(buildings_root)
	var settlement: Dictionary = {}
	for s in state.get("settlements", []):
		if int(s.region) == selected_region:
			settlement = s
	if settlement.is_empty():
		# Survey lander is survey equipment, not an operating settlement.
		var landing_x: float = 12.0 if world.regions[selected_region].river else 0.0
		_lander(buildings_root, Vector3(landing_x, _ground(landing_x, 0) + .1, 0))
		return
	var offset: float = 12.0 if world.regions[selected_region].river else 0.0
	if int(settlement.get("base_housing", 0)) > 0:
		_build_base_housing(offset, int(settlement.base_housing))
	var slots: Array[Vector2] = [
		Vector2(-3, -3),
		Vector2(3, -3),
		Vector2(-3, 3),
		Vector2(3, 3),
		Vector2(-9, -3),
		Vector2(9, -3),
		Vector2(-9, 3),
		Vector2(9, 3),
		Vector2(-3, -9),
		Vector2(3, -9),
		Vector2(-3, 9),
		Vector2(3, 9),
		Vector2(-9, -9),
		Vector2(9, -9),
		Vector2(-9, 9),
		Vector2(9, 9)
	]
	var buildings: Array = settlement.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var slot: Vector2 = slots[i % slots.size()] + Vector2(offset, 0)
		if i >= slots.size():
			var extra: int = i - slots.size()
			slot = (
				Vector2(-9.0 + (extra % 4) * 6.0, -15.0 if extra < 4 else 15.0) + Vector2(offset, 0)
			)
		var root := Node3D.new()
		root.position = Vector3(slot.x, _ground(slot.x, slot.y), slot.y)
		buildings_root.add_child(root)
		var complete: bool = int(b.get("remaining", b.get("days_left", 0))) <= 0
		var active: bool = b.get("enabled", true) and b.get("active", true) and complete
		_build_facility(root, str(b.kind), active)
		if not complete:
			_construction_frame(root)
		_road(Vector3(offset, 0, slot.y), Vector3(slot.x, 0, slot.y))
	_road(Vector3(offset, 0, -12), Vector3(offset, 0, 12))
	for z in [-10, -5, 0, 5, 10]:
		var p := Vector3(offset + 1.1, _ground(offset + 1.1, z), z)
		_cylinder(
			buildings_root,
			p + Vector3(0, .8, 0),
			.05,
			1.6,
			_mat("metal", Color("73818a"), .6, .4),
			8
		)
		_box(
			buildings_root,
			p + Vector3(0, 1.6, 0),
			Vector3(.35, .06, .16),
			_mat("lamps", Color("c4eee1"), .2, .4, 1.3)
		)
	_build_outbound_route(offset)


func _build_base_housing(offset: float, capacity: int) -> void:
	var root := Node3D.new()
	root.name = "LandingLivingCapsules"
	root.set_meta("base_housing", capacity)
	root.position = Vector3(offset - 6.0, _ground(offset - 6.0, 0), 0)
	buildings_root.add_child(root)
	var shell := _mat("basehousing", Color("c4b69a"), .45, .55)
	var dark := _mat("darkmetal", Color("354954"), .65, .38)
	var light := _mat("baselight", Color("f1d896"), .3, .4, .45)
	var count: int = 2 if capacity >= 80 else 1
	_cylinder(root, Vector3(0, .1, 0), 1.65, .2, dark, 8)
	for i in range(count):
		var x: float = (float(i) - float(count - 1) * .5) * 1.05
		var capsule := CapsuleMesh.new()
		capsule.radius = .44
		capsule.height = 2.45
		capsule.radial_segments = 16
		capsule.rings = 5
		var pod := _mesh(root, capsule, Vector3(x, .78, 0), shell)
		pod.rotation_degrees.x = 90
		for z in [-.65, 0, .65]:
			_box(root, Vector3(x, 1.20, z), Vector3(.55, .03, .22), dark)
			_box(root, Vector3(x, 1.22, z + .12), Vector3(.57, .02, .025), light)
		for z in [-.85, .85]:
			_box(root, Vector3(x, .32, z), Vector3(.7, .34, .14), dark)
	_box(root, Vector3(0, .37, 1.28), Vector3(1.2, .13, .5), shell)
	var label := Label3D.new()
	label.text = "登陆生活舱 · " + str(capacity) + " 人"
	label.font = label_font
	label.font_size = 36
	label.pixel_size = .009
	label.modulate = Color("e7d3a5")
	label.outline_modulate = Color("091621")
	label.position = Vector3(0, 1.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	_road(Vector3(offset, 0, 0), Vector3(offset - 6.0, 0, 0))


func _build_outbound_route(offset: float) -> void:
	var route: Dictionary = state.get("route", {})
	if not route.get("reachable", false):
		return
	var a: int = int(route.get("a", -1))
	var b: int = int(route.get("b", -1))
	if selected_region != a and selected_region != b:
		return
	var destination: int = b if selected_region == a else a
	var reg: Dictionary = world.regions[selected_region]
	var to: Dictionary = world.regions[destination]
	var direction := _point_to_local(float(to.lat), float(to.lon)).normalized()
	var coordinates: Array = route.get("coordinates", [])
	if coordinates.size() > 2:
		var adjacent: Array = (
			coordinates[2] if selected_region == a else coordinates[coordinates.size() - 3]
		)
		direction = _point_to_local(float(adjacent[0]), float(adjacent[1])).normalized()
	# The global route is a four-neighbour corridor. Its local gateway follows
	# the dominant outgoing direction and uses the clear central service lane.
	direction = (
		Vector2(signf(direction.x), 0)
		if absf(direction.x) > absf(direction.y)
		else Vector2(0, signf(direction.y))
	)
	var start := Vector2(offset, 0)
	var finish := start + direction * 24.0
	finish.x = clampf(finish.x, -26.5, 26.5)
	finish.y = clampf(finish.y, -21.5, 21.5)
	for i in range(28):
		var p: Vector2 = start.lerp(finish, float(i) / 28.0)
		var q: Vector2 = start.lerp(finish, float(i + 1) / 28.0)
		_road(Vector3(p.x, 0, p.y), Vector3(q.x, 0, q.y))
	var gate := Vector3(finish.x, _ground(finish.x, finish.y), finish.y)
	var steel := _mat("routegate", Color("bcb28d"), .55, .5)
	for x in [-.85, .85]:
		_tube(buildings_root, gate + Vector3(x, 0, 0), gate + Vector3(x, 2, 0), .09, steel)
	_box(buildings_root, gate + Vector3(0, 2, 0), Vector3(2, .35, .24), steel)
	var label := Label3D.new()
	var blocked: bool = Geo.road_blocked(route, int(state.get("day", 0)))
	label.text = (
		("停运 · " if blocked else "陆运 · ") + str(to.name) + " / " + str(route.get("days", 0)) + "天"
	)
	label.font = label_font
	label.font_size = 42
	label.pixel_size = .012
	label.modulate = Color("ead49d")
	label.outline_modulate = Color("091621")
	label.position = gate + Vector3(0, 2.9, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	buildings_root.add_child(label)


func _road(a: Vector3, b: Vector3) -> void:
	# Short actual service-road sections follow the regional height field; the
	# same service path crosses channels as a raised bridge, without fake exits.
	var count: int = maxi(1, ceili(a.distance_to(b) / 1.6))
	for i in range(count):
		_road_section(a.lerp(b, float(i) / count), a.lerp(b, float(i + 1) / count))


func _road_section(a: Vector3, b: Vector3) -> void:
	a.y = _ground(a.x, a.z) + .16
	b.y = _ground(b.x, b.z) + .16
	a.y = maxf(a.y, _water_height_at(a.x, a.z, 1.5) + .24)
	b.y = maxf(b.y, _water_height_at(b.x, b.z, 1.5) + .24)
	var midpoint: Vector3 = (a + b) * .5
	var road := _box(
		buildings_root,
		midpoint,
		Vector3(.72, .045, a.distance_to(b) + .4),
		_mat("road", Color("3c4848"), .15, .9)
	)
	if a.distance_to(b) > .01:
		road.look_at(b, Vector3.UP)
	var points: Array[Vector3] = [a + Vector3(0, .03, 0), b + Vector3(0, .03, 0)]
	_line(buildings_root, points, Color("b8b28c"), .25)


func _build_facility(root: Node3D, kind: String, active: bool) -> void:
	var shell := _mat("shell", Color("bec9cb"), .48, .43)
	var dark := _mat("darkmetal", Color("354954"), .65, .38)
	var metal := _mat("metal", Color("73818a"), .6, .4)
	var accent := _mat(
		"accent" + str(active),
		Color("75d6cc") if active else Color("d18061"),
		.3,
		.35,
		.7 if active else .12
	)
	var glass := _mat("glass", Color("204e62"), .55, .16)
	var gold := _mat("industrial", Color("c7a36b"), .4, .5)
	_cylinder(root, Vector3(0, .08, 0), 2.30, .16, _mat("pad", Color("43545a"), .3, .85), 6)
	match kind:
		"habitat":
			# Two pressure barrels, elevated floor, connecting vestibule and roof vents.
			for x in [-.86, .86]:
				var capsule := CapsuleMesh.new()
				capsule.radius = .64
				capsule.height = 3.15
				capsule.radial_segments = 16
				capsule.rings = 5
				var pod := _mesh(root, capsule, Vector3(x, 1.0, 0), shell)
				pod.rotation_degrees.x = 90
				for z in [-.9, -.3, .3, .9]:
					_box(root, Vector3(x, 1.58, z), Vector3(.62, .035, .25), glass)
					_box(root, Vector3(x, 1.60, z + .13), Vector3(.64, .025, .035), accent)
				for z in [-1, 1]:
					_box(root, Vector3(x, .35, z), Vector3(.88, .6, .18), dark)
			_box(root, Vector3(0, .7, .1), Vector3(.7, .8, .95), dark)
			_box(root, Vector3(0, .4, 1.7), Vector3(.85, .18, .9), shell)
		"power":
			# Tilted photovoltaic banks and central capacitor tower.
			_cylinder(root, Vector3(0, .72, 0), .45, 1.3, shell, 16)
			_cylinder(root, Vector3(0, 1.42, 0), .49, .12, accent, 16)
			for x in [-1.15, 1.15]:
				for z in [-.88, .88]:
					_box(root, Vector3(x, .45, z), Vector3(.12, .8, .12), metal)
					var panel := Node3D.new()
					panel.position = Vector3(x, .95, z)
					panel.rotation_degrees.x = -22
					root.add_child(panel)
					_box(panel, Vector3.ZERO, Vector3(1.35, .08, 1.48), dark)
					for col in range(4):
						for row in range(5):
							_box(
								panel,
								Vector3(-.48 + col * .32, .052, -.56 + row * .28),
								Vector3(.29, .012, .25),
								_mat("solar", Color("285d83"), .75, .2)
							)
		"water":
			for x in [-.86, .86]:
				_cylinder(root, Vector3(x, .9, 0), .65, 1.65, shell, 24)
				_sphere(root, Vector3(x, 1.72, 0), .65, metal, 20, 8).scale.y = .35
				for y in [.25, 1.1, 1.55]:
					_torus(root, Vector3(x, y, 0), .65, .055, accent if y > 1 else dark)
			_tube(root, Vector3(-.86, .35, 1), Vector3(.86, .35, 1), .12, metal)
			_box(root, Vector3(0, .48, 1.1), Vector3(.6, .7, .5), glass)
		"mine_ore", "mine_copper", "mine_crystal":
			var ore_color: Color = (
				Color("ac7755")
				if kind == "mine_ore"
				else (Color("ba9c57") if kind == "mine_copper" else Color("7ba0bd"))
			)
			_cylinder(root, Vector3(0, .18, 0), 1.35, .18, dark, 20)
			for x in [-.85, .85]:
				for z in [-.65, .65]:
					_tube(root, Vector3(x, .3, z), Vector3(x * .7, 3.2, z * .7), .10, gold)
			for y in [1.0, 2.0, 3.0]:
				_tube(root, Vector3(-.85, y, -.65), Vector3(.85, y, .65), .055, metal)
				_tube(root, Vector3(.85, y, -.65), Vector3(-.85, y, .65), .055, metal)
			_box(root, Vector3(0, 3.25, 0), Vector3(1.8, .3, 1.35), shell)
			_cylinder(root, Vector3(0, 1.5, 0), .14, 2.7, accent, 10)
			_box(root, Vector3(1.45, .6, .6), Vector3(.65, .95, 1.6), dark)
			var conveyor := _box(root, Vector3(.35, .42, 1.45), Vector3(1.0, .17, 1.7), metal)
			conveyor.rotation_degrees.x = 13
			for i in range(6):
				_sphere(
					root,
					Vector3(-.3 + (i % 3) * .3, .65, 1.1 + (i / 3) * .4),
					.19,
					_mat(kind + "raw", ore_color, .45, .7),
					5,
					3
				)
		"farm":
			# Two glazed growing tunnels with individually visible planting beds.
			for x in [-.9, .9]:
				_box(root, Vector3(x, .26, 0), Vector3(1.48, .25, 3.3), shell)
				for row in range(7):
					_box(
						root,
						Vector3(x, .44, -1.3 + row * .42),
						Vector3(1.21, .18, .25),
						_mat("crops", Color("719650"), 0, .85)
					)
				for z in [-1.5, -.75, 0, .75, 1.5]:
					var arch: Array[Vector3] = []
					for k in range(13):
						var angle: float = float(k) / 12 * PI
						arch.append(Vector3(x + cos(angle) * .74, .5 + sin(angle) * .88, z))
					for k in range(arch.size() - 1):
						_tube(root, arch[k], arch[k + 1], .035, shell)
				_box(root, Vector3(x, 1.38, 0), Vector3(.09, .08, 3.1), accent)
				for side in [-1, 1]:
					_box(root, Vector3(x + side * .7, .68, 0), Vector3(.04, .3, 3.1), glass)
		"processor":
			_box(root, Vector3(-.5, .72, 0), Vector3(2.2, 1.2, 2.8), shell)
			var roof := _cylinder(root, Vector3(-.5, 1.31, 0), 1.1, 2.8, metal, 12)
			roof.rotation_degrees.x = 90
			roof.scale.y = 1
			roof.scale.z = .5
			for z in [-.8, .75]:
				_cylinder(root, Vector3(1.05, 1.05, z), .4, 1.9, dark, 16)
				_torus(root, Vector3(1.05, 1.7, z), .4, .055, gold)
			_cylinder(root, Vector3(-1, 2.2, -.6), .18, 2.1, metal, 12)
			_box(root, Vector3(-.5, .9, 1.42), Vector3(1.7, .25, .04), accent)
		"lab":
			_cylinder(root, Vector3(0, .55, 0), 1.5, .9, shell, 12)
			_cylinder(root, Vector3(0, 1.0, 0), 1.55, .12, accent, 12)
			var dome := _sphere(root, Vector3(0, 1, 0), 1.3, glass, 28, 12)
			dome.scale.y = .65
			for a in range(6):
				var t: float = a * TAU / 6
				_box(root, Vector3(sin(t) * 1.1, .5, cos(t) * 1.1), Vector3(.25, .6, .25), dark)
			_tube(root, Vector3(-1.7, .2, -.9), Vector3(-1.7, 2.7, -.9), .055, metal)
			var dish := _sphere(root, Vector3(-1.7, 2.6, -.9), .48, shell, 16, 8)
			dish.scale = Vector3(1, .18, 1)
			dish.rotation_degrees.z = -30
			_sphere(root, Vector3(-1.7, 2.95, -.9), .075, accent, 8, 4)
		"port":
			_cylinder(root, Vector3(0, .2, 0), 1.9, .2, dark, 8)
			_torus(root, Vector3(0, .32, 0), 1.65, .045, accent)
			_box(root, Vector3(0, .33, 0), Vector3(1.4, .025, .12), shell)
			_box(root, Vector3(0, .33, 0), Vector3(.12, .025, 1.4), shell)
			for z in [-1.5, 1.5]:
				_box(root, Vector3(-1.9, .6, z * .7), Vector3(.6, .9, .95), gold)
				_box(root, Vector3(-1.9, .7, z * .7 + .48), Vector3(.52, .08, .025), accent)
			_cylinder(root, Vector3(1.8, 1.2, -1), .16, 2.2, metal, 12)
			_box(root, Vector3(1.8, 2.3, -1), Vector3(.55, .35, .55), glass)
		"commerce", "service":
			_cylinder(root, Vector3(0, .65, 0), 1.6, 1.0, shell, 6)
			_cone(root, Vector3(0, 1.4, 0), 1.8, .65, gold)
			for x in [-.8, 0, .8]:
				_box(root, Vector3(x, .7, 1.2), Vector3(.6, .5, .08), glass)
			_box(root, Vector3(0, 1.16, 1.25), Vector3(2, .16, .12), accent)
		_:
			_cylinder(root, Vector3(0, .8, 0), 1.1, 1.4, shell, 8)
			_cone(root, Vector3(0, 1.6, 0), 1.15, .6, metal)
	# A physical status beacon is attached to every facility.
	_cylinder(root, Vector3(1.8, .35, -1.7), .045, .5, metal, 6)
	_sphere(root, Vector3(1.8, .64, -1.7), .09, accent, 8, 4)


func _construction_frame(root: Node3D) -> void:
	var material := _mat("construction", Color("dfb46b"), .4, .5, .3)
	for x in [-1.9, 1.9]:
		for z in [-1.9, 1.9]:
			_tube(root, Vector3(x, .2, z), Vector3(x, 2.9, z), .055, material)
	for z in [-1.9, 1.9]:
		_tube(root, Vector3(-1.9, 2.9, z), Vector3(1.9, 2.9, z), .055, material)


func _lander(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var material := _mat("lander", Color("bdccce"), .6, .4)
	_cylinder(root, Vector3(0, 1, 0), .7, 1.35, material, 8)
	_cone(root, Vector3(0, 1.9, 0), .7, .5, material)
	for i in range(3):
		var t: float = i * TAU / 3
		_tube(
			root,
			Vector3(sin(t) * .5, .8, cos(t) * .5),
			Vector3(sin(t) * 1.3, .08, cos(t) * 1.3),
			.07,
			material
		)
		_cylinder(root, Vector3(sin(t) * 1.3, .09, cos(t) * 1.3), .25, .08, material, 8)
	_tube(root, Vector3(0, 1.8, 0), Vector3(0, 3.3, 0), .035, material)
	_sphere(root, Vector3(0, 3.3, 0), .08, _mat("beacon", Color("76dace"), 0, .4, 1), 8, 4)
	var ring: Array[Vector3] = []
	for i in range(65):
		var t := float(i) / 64 * TAU
		var x := cos(t) * 4.2
		var z := sin(t) * 4.2
		ring.append(Vector3(x, _ground(x, z) - pos.y + .04, z))
	_line(root, ring, Color("77c9be"), .5)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, material)


func _sphere(
	parent: Node3D,
	pos: Vector3,
	radius: float,
	material: Material,
	segments: int = 16,
	rings: int = 8
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = segments
	mesh.rings = rings
	return _mesh(parent, mesh, pos, material)


func _cylinder(
	parent: Node3D,
	pos: Vector3,
	radius: float,
	height: float,
	material: Material,
	segments: int = 16
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, pos, material)


func _cone(
	parent: Node3D, pos: Vector3, radius: float, height: float, material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	return _mesh(parent, mesh, pos, material)


func _torus(
	parent: Node3D, pos: Vector3, radius: float, width: float, material: Material
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 24
	mesh.ring_segments = 8
	return _mesh(parent, mesh, pos, material)


func _tube(
	parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material
) -> MeshInstance3D:
	var tube := _cylinder(parent, (a + b) * .5, radius, a.distance_to(b), material, 7)
	var up: Vector3 = (b - a).normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() > .001:
		tube.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(up), -1, 1)))
	return tube


func _line(parent: Node3D, points: Array[Vector3], color: Color, energy: float = 1.0) -> void:
	if points.size() < 2:
		return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for p in points:
		mesh.surface_add_vertex(p)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
