extends RefCounted


## Drive an exported game through the NewGame button in an isolated APPDATA directory.
## TERRAIN_QA_OUT selects the output folder. TERRAIN_OLD_SAVE optionally supplies a 2.2 save.
static func frames(game, count: int) -> void:
	for frame in count:
		await game.get_tree().process_frame


static func fail(game, label: String) -> void:
	push_error("TERRAIN_EXPORT_FAIL " + label)
	game.get_tree().quit(1)


static func visible_landing_sites(game) -> int:
	var atlas: Image = game.map.geography_atlas.get_image()
	var width := atlas.get_width()
	var height := atlas.get_height()
	var count := 0
	for site: Dictionary in game.sim.geo.regions:
		var x: float = (float(site.lon) / 360.0 + 0.5) * width - 0.5
		var y: float = (0.5 - float(site.lat) / 180.0) * height - 0.5
		var left := posmod(floori(x), width)
		var right := posmod(left + 1, width)
		var top := clampi(floori(y), 0, height - 2)
		var dx := fposmod(x, 1.0)
		var north := lerpf(atlas.get_pixel(left, top).a, atlas.get_pixel(right, top).a, dx)
		var south := lerpf(atlas.get_pixel(left, top + 1).a, atlas.get_pixel(right, top + 1).a, dx)
		if lerpf(north, south, fposmod(y, 1.0)) > 0.5:
			count += 1
	return count


static func run(game) -> void:
	var output := OS.get_environment("TERRAIN_QA_OUT")
	if output.is_empty():
		output = ProjectSettings.globalize_path("user://terrain23_checks")
	DirAccess.make_dir_recursive_absolute(output)
	var checks := {"exported": OS.has_feature("template"), "sandbox": OS.get_user_data_dir()}
	await frames(game, 3)
	if not checks.exported or not game.menu_open:
		fail(game, "menu or template missing")
		return
	if game.tutorial_on:
		game.ui.find_child("TutorialToggle", true, false).pressed.emit()
		await frames(game, 3)
	var requested := OS.get_environment("TERRAIN_QA_SEED")
	game.seed_edit.text = requested if not requested.is_empty() else "260129"
	game.ui.find_child("NewGame", true, false).pressed.emit()
	await frames(game, 3)
	if game.menu_open or game.sim.geo.version != "CC-GEO-2.3":
		fail(game, "new expedition did not select 2.3")
		return
	game.close_modal()
	game.paused = true
	game.navigate("planet")
	var start := Time.get_ticks_msec()
	while game.map.atlas_refining and Time.get_ticks_msec() - start < 180000:
		await game.get_tree().create_timer(0.1).timeout
	checks.initial_atlas_source = game.map.last_atlas_source
	checks.background_refine_ms = game.map.last_refinement_ms
	checks.atlas_finished = not game.map.atlas_refining
	checks.atlas_wait_ms = Time.get_ticks_msec() - start
	checks.atlas_dimensions = str(game.map.geography_atlas.get_size())
	checks.height_same_texture = (
		game.map.globe_shader.get_shader_parameter("atlas")
		== game.map.flat_shader.get_shader_parameter("atlas")
	)
	checks.water_same_texture = (
		game.map.globe_shader.get_shader_parameter("optical_water")
		== game.map.flat_shader.get_shader_parameter("optical_water")
	)
	checks.shader_loaded = (
		game.map.globe_shader.get_shader_parameter("optical_v3") == true
		and game.map.flat_shader.get_shader_parameter("optical_v3") == true
	)
	checks.visible_landing_sites = visible_landing_sites(game)
	checks.region_count = game.sim.geo.regions.size()
	checks.seed = game.sim.geo.seed
	checks.world_hash = game.sim.geo.hash
	checks.version = game.sim.geo.version
	checks.gpu = RenderingServer.get_video_adapter_name()
	checks.pairs = game.sim.geo.playability.pairs.size()
	await frames(game, 10)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output + "/globe.png")
	var landing: Dictionary = game.sim.geo.regions[0]
	game.select_ground({"lat": landing.lat, "lon": landing.lon, "view": "planet"})
	await frames(game, 3)
	var flat_button: Button = game.ui.find_child("GroundFlatMap", true, false)
	if flat_button == null or flat_button.disabled:
		fail(game, "siting map button missing")
		return
	flat_button.pressed.emit()
	await frames(game, 3)
	checks.switched_via_siting_panel = game.map.mode == "flat"
	game.clear_ground()
	await frames(game, 12)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output + "/satellite.png")
	var old_path := OS.get_environment("TERRAIN_OLD_SAVE")
	var legacy_ok := true
	if not old_path.is_empty():
		game.load_path(old_path)
		await frames(game, 4)
		legacy_ok = (
			game.sim.geo.version == "CC-GEO-2.2"
			and game.sim.state.settlements.size() == 1
			and game.map.globe_shader.get_shader_parameter("optical_v3") == false
		)
		checks.legacy_save_loaded = legacy_ok
		checks.legacy_hash = str(game.sim.geo.hash)
	checks.passed = (
		checks.atlas_finished
		and legacy_ok
		and checks.height_same_texture
		and checks.water_same_texture
		and checks.shader_loaded
		and checks.region_count == checks.visible_landing_sites
		and checks.switched_via_siting_panel
		and checks.pairs > 0
	)
	FileAccess.open(output + "/export.json", FileAccess.WRITE).store_string(
		JSON.stringify(checks, "  ")
	)
	print("TERRAIN_EXPORT ", JSON.stringify(checks))
	if not old_path.is_empty():
		var deadline := Time.get_ticks_msec() + 90000
		while game.map.atlas_refining and Time.get_ticks_msec() < deadline:
			await game.get_tree().create_timer(0.1).timeout
	game.get_tree().quit(0 if checks.passed else 1)
