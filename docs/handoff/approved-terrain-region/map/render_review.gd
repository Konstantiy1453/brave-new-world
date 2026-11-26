extends RefCounted

# Load with the game's --dev-script option from a fresh QA profile.
# Set TERRAIN_REVIEW_OUT to an absolute, writable directory before launching.
const EXPECTED := {
    "260129": "60dbcafeb9abb7c2662987c923dd67e21bc96f211bee1a22918adf2b4a3d67da",
    "260130": "287242ac363da2392e6d6e18c0cb2a340ca5d6c8804aaffe3e9404780ed1097a",
    "260133": "561181fd3609fa5db6e593e495f8b8762366086370a4e3eb75cfed323eaab677",
    "260137": "73c2c64f1e30411c31d291583214cea5a4481b22c3a4566b8eb6510b73a890c2",
    "260140": "9ac73aa5c6f35a773824cff9f03eb5c79dc3e507a9540247f575236ae5720a94",
    "260141": "7ddcdded5f9e67e92155b72f2fbfdbceaeb98f3ab953ec596dccb0457fdb0319",
    "260143": "80bcc4b33c927f834862fc46c329471456f6bcef27beb1305829560bb00e88a9",
    "260144": "9c8147858408a8c0af8304155bcc0e2760847b8ea4ed0e8f57b96e70ab7e87cf"
}

static func run(game) -> void:
	var output := OS.get_environment("TERRAIN_REVIEW_OUT")
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Set TERRAIN_REVIEW_OUT to a writable absolute directory.")
		game.get_tree().quit(1)
		return
	game.paused = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048, 1024)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.add_child(viewport)
	var style := WorldEnvironment.new()
	viewport.add_child(style)
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(18, 9)
	sheet.mesh = quad
	viewport.add_child(sheet)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 9.0
	camera.position = Vector3(0, 0, 5)
	viewport.add_child(camera)
	camera.current = true
	for key: String in EXPECTED:
		var seed_value := int(key)
		var name := "world_%s" % key
		var started := Time.get_ticks_msec()
		if not game._begin_world(seed_value, "capital", 1, "normal", 1.0):
			push_error("Failed to generate " + name)
			game.get_tree().quit(1)
			return
		game.paused = true
		game.navigate("flat")
		game.map.set_visual_options(false, false, false)
		game.map._apply_sky()
		while game.map.atlas_refining and Time.get_ticks_msec() - started < 240000:
			await game.get_tree().create_timer(0.08).timeout
		var world: Dictionary = game.sim.geo
		var atlas: Texture2D = game.map.flat_shader.get_shader_parameter("atlas")
		if str(world.hash) != str(EXPECTED[key]) or game.map.atlas_refining or str(world.version) != "CC-GEO-2.3" or atlas == null or int(atlas.get_width()) != 1536 or atlas != game.map.geography_atlas or not game.map.flat_shader.get_shader_parameter("optical_v3"):
			push_error("Map mismatch %s: hash=%s expected=%s schema=%s size=%s refining=%s physical=%s optical=%s" % [name, world.hash, EXPECTED[key], world.version, atlas.get_size() if atlas != null else Vector2i.ZERO, game.map.atlas_refining, atlas == game.map.geography_atlas, game.map.flat_shader.get_shader_parameter("optical_v3")])
			game.get_tree().quit(2)
			return
		style.environment = game.map.environment
		sheet.material_override = game.map.flat_shader
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for frame in 4:
			await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var in_progress := output + "/" + name + ".partial.png"
		if img.get_size() != viewport.size or img.save_png(in_progress) != OK or DirAccess.rename_absolute(in_progress,output + "/" + name + ".png") != OK:
			push_error("Capture failed " + name)
			game.get_tree().quit(3)
			return
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var details := {"seed":seed_value,"version":world.version,"hash":world.hash,"radius_km":world.radius_km,"regions":world.regions.size(),"rivers":world.rivers.size(),"generation":world.generation,"atlas":str(atlas.get_size()),"milliseconds":Time.get_ticks_msec()-started}
		FileAccess.open(output + "/" + name+".json",FileAccess.WRITE).store_string(JSON.stringify(details))
		print("TERRAIN_REVIEW_SAVED ",name," ",world.hash)
	game.get_tree().quit(0)
