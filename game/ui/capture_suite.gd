extends RefCounted


## Explicit developer-only capture harness. Never invoked by normal menus.
static func run(g, folder: String):
	DirAccess.make_dir_recursive_absolute(folder)
	g.load_path("res://data/acceptance_midgame.json")
	g.paused = true
	var report = {
		"kind": "exported native render harness; automated, not manual play",
		"captures": [],
		"adapter": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"resolutions": []
	}
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		g.load_path("res://data/acceptance_midgame.json")
		var refinement_deadline = Time.get_ticks_msec() + 30000
		while g.map.get("atlas_refining") == true and Time.get_ticks_msec() < refinement_deadline:
			await g.get_tree().process_frame
		DisplayServer.window_set_size(size)
		g.get_window().content_scale_factor = 1.0
		await g.get_tree().create_timer(.6).timeout
		for page in [
			"planet",
			"flat",
			"world",
			"region",
			"economy",
			"research",
			"contract",
			"enterprise",
			"events"
		]:
			g.close_modal()
			if page == "events":
				while g.sim.state.day < 35:
					g.sim.tick()
				g.map.sync_state(g.sim.state)
				g.refresh()
			if page == "planet":
				g.navigate("planet")
			elif page == "flat":
				g.navigate("flat")
			elif page == "region":
				g.selected = 1
				g.navigate("region")
			else:
				g.open_page(page)
			await g.get_tree().create_timer(.6).timeout
			await RenderingServer.frame_post_draw
			var filename = "%s_%dx%d.png" % [page, size.x, size.y]
			g.get_viewport().get_texture().get_image().save_png(folder + "/" + filename)
			report.captures.append(filename)
		g.close_modal()
		g.navigate("planet")
		var frames = []
		for i in range(120):
			await g.get_tree().process_frame
			frames.append(g.get_process_delta_time())
		frames.sort()
		var sum = 0.0
		for t in frames:
			sum += t
		report.resolutions.append(
			{
				"size": str(size),
				"sample_frames": 120,
				"fps": 120.0 / sum,
				"p95_ms": frames[114] * 1000,
				"scope": "paused native planet view, 60 fps cap, 120 frames after warmup"
			}
		)
		for text_size in [16, 20]:
			g.get_window().content_scale_factor = text_size / 18.0
			g.open_page("save")
			await g.get_tree().create_timer(.4).timeout
			await RenderingServer.frame_post_draw
			var scaled = "settings_%dx%d_%dpx.png" % [size.x, size.y, text_size]
			g.get_viewport().get_texture().get_image().save_png(folder + "/" + scaled)
			report.captures.append(scaled)
			g.close_modal()
			await g.get_tree().create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			var shell = "shell_%dx%d_%dpx.png" % [size.x, size.y, text_size]
			g.get_viewport().get_texture().get_image().save_png(folder + "/" + shell)
			report.captures.append(shell)
		g.get_window().content_scale_factor = 1.0
	FileAccess.open(folder + "/capture_report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	g.get_tree().quit(0)
