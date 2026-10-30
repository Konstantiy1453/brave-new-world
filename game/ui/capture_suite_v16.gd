extends RefCounted


## Explicit developer capture; exported EXE traverses production pages and real saves.
static func run(g, folder: String):
	DirAccess.make_dir_recursive_absolute(folder)
	g.paused = true
	var report: Dictionary = {
		"kind": "v1.6 exported native render harness; automated UI rendering, not manual full play",
		"adapter": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"captures": [],
		"failures": [],
		"frames": [],
		"user_data": OS.get_user_data_dir()
	}
	var fixtures: Dictionary = {
		"company": "acceptance_crisis",
		"events": "acceptance_event_mid",
		"career": "acceptance_second_dividend",
		"contract": "acceptance_governor",
		"research": "acceptance_research",
		"economy": "acceptance_second_dividend",
		"enterprise": "acceptance_governor",
		"transport": "acceptance_governor",
		"manage": "acceptance_governor",
		"save": "acceptance_governor",
		"planet": "acceptance_governor",
		"flat": "acceptance_governor",
		"region": "acceptance_governor"
	}
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		DisplayServer.window_set_size(size)
		for font_px in [18, 16, 20]:
			g.get_window().content_scale_factor = font_px / 18.0
			var pages: Array = (
				[
					"planet",
					"flat",
					"region",
					"economy",
					"research",
					"company",
					"events",
					"career",
					"contract",
					"enterprise",
					"transport",
					"manage",
					"save"
				]
				if font_px == 18
				else ["research", "company", "events", "career", "save"]
			)
			if (
				g.get_tree().get_root().get_tree() != null
				and OS.get_cmdline_user_args().has("--qa-manage-only")
			):
				pages = ["manage"]
			for page in pages:
				var path: String = "res://data/v16/" + fixtures[page] + ".json"
				var err: String = g.sim.load_game(path)
				if err != "":
					report.failures.append(path + ": " + err)
					continue
				g.load_path(path)
				var expected_pause: bool = bool(
					preload("res://simulation/events_v2.gd").view(g.sim).pause_required
				)
				if g.event_pause_required() != expected_pause:
					report.failures.append(
						"exported event pause gate differs from actual event state"
					)
				var deadline: int = Time.get_ticks_msec() + 45000
				while g.map.atlas_refining and Time.get_ticks_msec() < deadline:
					await g.get_tree().process_frame
				if g.map.atlas_refining:
					report.failures.append("atlas timed out " + page)
				g.close_modal()
				if page in ["planet", "flat", "region"]:
					g.navigate(page)
				else:
					g.open_page(page)
				if page == "manage":
					var fields: Array = g.modal_box.find_children("*", "SpinBox", true, false)
					for index in range(fields.size()):
						var expected: float = g.sim._target(
							g.settlement(), ["food", "materials", "parts"][index]
						)
						if absf(fields[index].value - expected) > 0.001:
							report.failures.append("inventory target UI differs from actual target")
				deadline = Time.get_ticks_msec() + 20000
				while g.map.region_busy and Time.get_ticks_msec() < deadline:
					await g.get_tree().process_frame
				if g.map.region_busy:
					report.failures.append("region timed out")
				await g.get_tree().create_timer(0.2).timeout
				await RenderingServer.frame_post_draw
				var name: String = "%s_%dx%d_%dpx.png" % [page, size.x, size.y, font_px]
				g.get_viewport().get_texture().get_image().save_png(folder + "/" + name)
				report.captures.append(
					{
						"file": name,
						"fixture": path,
						"local_day": g.sim.state.day,
						"global_day": g.sim.state.career.global_day
					}
				)
				print("V16_CAPTURE ", name)
		g.get_window().content_scale_factor = 1.0
		g.close_modal()
		g.navigate("planet")
		var times: Array = []
		for i in range(120):
			await g.get_tree().process_frame
			times.append(g.get_process_delta_time() * 1000.0)
		times.sort()
		report.frames.append(
			{
				"resolution": str(size),
				"n": 120,
				"p95_ms": times[114],
				"scope": "paused globe, warm, 60fps cap; not interaction latency"
			}
		)
	FileAccess.open(folder + "/capture_report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	g.get_tree().quit(0 if report.failures.is_empty() else 1)
