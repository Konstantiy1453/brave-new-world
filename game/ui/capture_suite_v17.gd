extends RefCounted
## Developer capture: every main page at each resolution and text size, from the source project.
## Fixtures are data/v17/acceptance_*.save (tests/make_fixtures_v17.gd writes them).
## Options: --qa-sizes=1920x1080,1280x720  --qa-fonts=18,16  --qa-pages=economy,build

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FONTS: Array[int] = [18, 16, 20]
const PAGES: Dictionary = {
	"planet": "midgame",
	"flat": "midgame",
	"region": "midgame",
	"site": "early",
	"settlement": "midgame",
	"build": "midgame",
	"economy": "governor",
	"population": "midgame",
	"research": "midgame",
	"company": "crisis",
	"events": "event",
	"career": "governor",
	"contract": "midgame",
	"enterprise": "governor",
	"transport": "governor",
	"manage": "midgame",
	"world": "midgame",
	"save": "governor",
	"guide": "early",
	"buildings": "governor",
	"naming": "early",
}
const MAP_PAGES: Array[String] = ["planet", "flat", "region"]
const SIDEBAR_PAGES: Array[String] = ["site", "settlement"]


static func run(g, folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	g.paused = true
	# The same picture every time: the moving map holds still, with its look intact.
	g.map.freeze_motion()
	var report: Dictionary = {
		"kind": "v1.8 source-project window; automated UI rendering, not manual play",
		"adapter": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"captures": [],
		"failures": [],
	}
	var sizes: Array = _sizes()
	var fonts: Array = _fonts()
	var pages: Array = _pages()
	for size: Vector2i in sizes:
		DisplayServer.window_set_size(size)
		await g.get_tree().process_frame
		for font_px: int in fonts:
			g.get_window().content_scale_factor = font_px / 18.0
			for page: String in pages:
				await _capture_page(g, folder, page, size, font_px, report)
			if _pages_option() == "" or _pages_option().contains("menu"):
				await _capture_menu(g, folder, size, font_px, report)
				await _capture_tutorial(g, folder, size, font_px, report)
	g.get_window().content_scale_factor = 1.0
	var file: FileAccess = FileAccess.open(folder + "/capture_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"V17_CAPTURE_RESULT captures=%d failures=%d"
			% [report.captures.size(), report.failures.size()]
		)
	)
	g.get_tree().quit(0 if report.failures.is_empty() else 1)


static func _capture_page(
	g, folder: String, page: String, size: Vector2i, font_px: int, report: Dictionary
) -> void:
	var path: String = "res://data/v17/acceptance_%s.save" % str(PAGES[page])
	var error: String = g.sim.load_game(path)
	if error != "":
		report.failures.append(path + ": " + error)
		return
	g.load_path(path)
	g.paused = true
	await _map_ready(g, report, page)
	g.close_modal()
	if page in MAP_PAGES:
		g.selected = _settled_site(g)
		g.navigate(page)
		await _map_ready(g, report, page)
	elif page == "site":
		g.navigate("planet")
		g.select_region(_free_site(g))
	elif page == "naming":
		g.navigate("planet")
		g.select_region(_free_site(g))
		g.naming_site = g.selected
		g.naming_again = false
		g.open_page("name_site")
	elif page == "settlement":
		g.navigate("planet")
		g.select_region(_settled_site(g))
		for group: String in ["mine_ore"]:
			g.expanded_kinds[group] = true
		g.refresh_sidebar()
	else:
		g.selected = _settled_site(g)
		g.navigate("planet")
		g.open_page(page)
	await _save(g, folder, page, size, font_px, report)


static func _capture_menu(
	g, folder: String, size: Vector2i, font_px: int, report: Dictionary
) -> void:
	g.close_modal()
	g.show_menu()
	await _save(g, folder, "menu", size, font_px, report)


## A new tutorial game: the coach panel over the map, then over the build dialog.
static func _capture_tutorial(
	g, folder: String, size: Vector2i, font_px: int, report: Dictionary
) -> void:
	g.close_modal()
	g.start_tutorial()
	g.paused = true
	await _map_ready(g, report, "tutorial")
	await _save(g, folder, "tutorial_start", size, font_px, report)
	g.act("settle", {"site": 0})
	g.select_region(0)
	g.coach.index = 3
	g.coach._show_step()
	g.open_fix({"page": "build", "category": "all"})
	await _save(g, folder, "tutorial_build", size, font_px, report)
	g.close_modal()
	g.coach.stop(false)


static func _save(
	g, folder: String, page: String, size: Vector2i, font_px: int, report: Dictionary
) -> void:
	await g.get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var file: String = "%s_%dx%d_%dpx.png" % [page, size.x, size.y, font_px]
	g.get_viewport().get_texture().get_image().save_png(folder + "/" + file)
	report.captures.append({"file": file, "day": int(g.sim.state.day)})
	print("V17_CAPTURE ", file)


static func _map_ready(g, report: Dictionary, page: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 45000
	while (g.map.atlas_refining or g.map.region_busy) and Time.get_ticks_msec() < deadline:
		await g.get_tree().process_frame
	if g.map.atlas_refining or g.map.region_busy:
		report.failures.append("map timed out on " + page)


static func _settled_site(g) -> int:
	if g.sim.state.settlements.is_empty():
		return 0
	return int(g.sim.state.settlements[0].region)


static func _free_site(g) -> int:
	for region: Dictionary in g.sim.state.world.regions:
		if g.sim.settlement(int(region.id)).is_empty():
			return int(region.id)
	return 0


static func _option(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


static func _pages_option() -> String:
	return _option("--qa-pages=")


static func _pages() -> Array:
	var chosen: String = _pages_option()
	if chosen == "":
		return PAGES.keys()
	var names: Array = []
	for name: String in chosen.split(","):
		if PAGES.has(name):
			names.append(name)
	return names


static func _sizes() -> Array:
	var chosen: String = _option("--qa-sizes=")
	if chosen == "":
		return SIZES
	var sizes: Array = []
	for text: String in chosen.split(","):
		var parts: PackedStringArray = text.split("x")
		sizes.append(Vector2i(int(parts[0]), int(parts[1])))
	return sizes


static func _fonts() -> Array:
	var chosen: String = _option("--qa-fonts=")
	if chosen == "":
		return FONTS
	var fonts: Array = []
	for text: String in chosen.split(","):
		fonts.append(int(text))
	return fonts
