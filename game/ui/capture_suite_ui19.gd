extends RefCounted
## Developer capture for the 1.9 interface pass, from the source project in a real window: the
## construction and research pages at each window size and text size, then the interactions
## around them at the reference size: a facility that can be ordered, a category filter, keyboard
## focus on a catalogue row, a refusal tooltip, the research page scrolled to a running topic,
## research -> construction -> research, the neutral economy page, the facility column and the
## main menu. Every action button on the two pages is scrolled into view and checked to be inside
## its scroll area. Loads the midgame fixture (--qa-fixtures, default res://data/v17: the recorded
## ones carry the world hash of the machine that made them). Writes PNGs and ui19_report.json.
##   godot --path game -- --dev --dev-script=res://ui/capture_suite_ui19.gd --qa-out=<folder>
##         [--qa-fixtures=<folder>] [--qa-sizes=1280x720,1600x900] [--qa-fonts=16,18,20]

const D = preload("res://ui/design.gd")
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)
]
const FONTS: Array[int] = [16, 18, 20]
const REFERENCE: Vector2i = Vector2i(1600, 900)
const FIXTURE: String = "midgame"


static func run(g) -> void:
	var folder: String = _option("--qa-out=")
	if folder == "":
		folder = ProjectSettings.globalize_path("res://../evidence/v17/ui19")
	DirAccess.make_dir_recursive_absolute(folder)
	var report: Dictionary = {
		"kind": "source-project window; automated UI rendering and scripted interaction",
		"adapter": RenderingServer.get_video_adapter_name(),
		"captures": [],
		"checks": 0,
		"failures": [],
	}
	g.map.freeze_motion()
	if not _load(g, report):
		_finish(g, folder, report)
		return
	for size: Vector2i in _sizes():
		DisplayServer.window_set_size(size)
		await g.get_tree().process_frame
		for font_px: int in _fonts():
			g.get_window().content_scale_factor = font_px / 18.0
			var tag: String = "%dx%d_%dpx" % [size.x, size.y, font_px]
			for page: String in ["build", "research"]:
				g.open_page(page)
				await _save(g, folder, "%s_%s" % [page, tag], report)
				await _reachable(g, page, tag, report)
	DisplayServer.window_set_size(REFERENCE)
	g.get_window().content_scale_factor = 1.0
	await g.get_tree().process_frame
	await _interactions(g, folder, report)
	_finish(g, folder, report)


static func _load(g, report: Dictionary) -> bool:
	var fixtures: String = _option("--qa-fixtures=")
	if fixtures == "":
		fixtures = "res://data/v17"
	var path: String = "%s/acceptance_%s.save" % [fixtures.trim_suffix("/"), FIXTURE]
	var error: String = g.sim.load_game(path)
	if error != "":
		report.failures.append(path + ": " + error)
		return false
	g.load_path(path)
	g.coach.stop(false)
	g.menu_open = false
	g.paused = true
	g.selected = int(g.sim.state.settlements[0].region)
	g.navigate("planet")
	return true


static func _interactions(g, folder: String, report: Dictionary) -> void:
	# A facility the rules allow here, chosen in the catalogue.
	g.open_page("build")
	await _frame(g)
	var ready: String = ""
	for row: Node in g.modal_box.find_children("Build_*", "Button", true, false):
		if not (row as Button).disabled:
			ready = str(row.name).trim_prefix("Build_")
			break
	_check(report, ready != "", "some facility can be ordered in the fixture")
	if ready != "":
		g.modal_box.find_child("Pick_" + ready, true, false).pressed.emit()
		await _save(g, folder, "build_ready", report)
	g.modal_box.find_child("Cat_industry", true, false).pressed.emit()
	await _save(g, folder, "build_filter_industry", report)
	g.modal_box.find_child("Cat_all", true, false).pressed.emit()
	await _frame(g)
	var row_button: Button = g.modal_box.find_child("Pick_mine_copper", true, false)
	if row_button != null:
		row_button.grab_focus()
		await _save(g, folder, "build_keyboard_focus", report)
		_check(report, row_button.has_focus(), "a catalogue row takes keyboard focus")
	var refused: Button = null
	for row: Node in g.modal_box.find_children("Build_*", "Button", true, false):
		if (row as Button).disabled and (row as Button).tooltip_text != "":
			refused = row
			break
	if refused != null:
		var centre: Vector2 = refused.get_global_rect().get_center()
		var scale: float = g.get_window().content_scale_factor
		g.get_viewport().warp_mouse(centre * scale)
		var motion := InputEventMouseMotion.new()
		motion.position = centre
		motion.global_position = centre
		g.get_viewport().push_input(motion)
		await g.get_tree().create_timer(1.4).timeout
		await _save(g, folder, "build_refusal_tooltip", report)
	g.get_viewport().warp_mouse(Vector2(5, 5))
	# Research: the top, then a running topic's commission switch.
	g.open_page("research")
	await _save(g, folder, "research_top", report)
	var scroll: ScrollContainer = g.modal_box.get_parent()
	for node: Node in g.modal_box.find_children("Commission_*", "Button", true, false):
		var holder: Control = g.modal_box
		scroll.scroll_vertical = int(node.global_position.y - holder.global_position.y - 300.0)
		break
	await _save(g, folder, "research_scrolled", report)
	# Switching modules: the frame and every control follow the page.
	g.open_page("build")
	await _frame(g)
	g.open_page("research")
	await _save(g, folder, "research_after_switch", report)
	_check(
		report,
		g.modal_close.get_meta(D.META_SKIN, "") == "research|plain",
		"the frame follows research after construction"
	)
	g.open_page("economy")
	await _save(g, folder, "economy_neutral", report)
	_check(
		report,
		g.modal_close.get_meta(D.META_SKIN, "") == "neutral|plain",
		"the frame is neutral on the economy page"
	)
	g.close_modal()
	g.column_open = true
	g.navigate("region")
	await _frame(g)
	await _map_ready(g)
	await _save(g, folder, "region_column", report)
	g.show_menu()
	await _save(g, folder, "menu", report)


## Every action on a page can be scrolled into view inside its own scroll area.
static func _reachable(g, page: String, tag: String, report: Dictionary) -> void:
	var missed: Array[String] = []
	for node: Node in g.modal_box.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.is_visible_in_tree():
			continue
		var area: ScrollContainer = _scroll_of(button)
		if area == null:
			continue
		area.ensure_control_visible(button)
		await g.get_tree().process_frame
		var inside: Rect2 = area.get_global_rect().grow(2.0)
		if not inside.encloses(button.get_global_rect()):
			missed.append(str(button.name))
	var window: Rect2 = g.ui.get_viewport_rect()
	var frame: Rect2 = g.modal_panel.get_global_rect()
	_check(
		report, window.grow(1.0).encloses(frame), "%s %s: the panel fits the window" % [page, tag]
	)
	_check(
		report,
		missed.is_empty(),
		"%s %s: every action can be scrolled into view %s" % [page, tag, str(missed)]
	)
	for node: Node in g.modal_box.find_children("*", "ScrollContainer", true, false):
		(node as ScrollContainer).scroll_vertical = 0
	g.modal_box.get_parent().scroll_vertical = 0


static func _scroll_of(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null


static func _check(report: Dictionary, ok: bool, label: String) -> void:
	report.checks += 1
	if not ok:
		report.failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


static func _frame(g) -> void:
	for _index: int in range(3):
		await g.get_tree().process_frame


static func _map_ready(g) -> void:
	var deadline: int = Time.get_ticks_msec() + 45000
	while (g.map.atlas_refining or g.map.region_busy) and Time.get_ticks_msec() < deadline:
		await g.get_tree().process_frame


static func _save(g, folder: String, name: String, report: Dictionary) -> void:
	await _frame(g)
	await g.get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var file: String = name + ".png"
	g.get_viewport().get_texture().get_image().save_png(folder.path_join(file))
	report.captures.append(file)
	print("UI19_CAPTURE ", file)


static func _finish(g, folder: String, report: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(folder.path_join("ui19_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		(
			"UI19_CAPTURE_RESULT captures=%d checks=%d failures=%d"
			% [report.captures.size(), int(report.checks), report.failures.size()]
		)
	)
	g.get_tree().quit(0 if report.failures.is_empty() else 1)


static func _option(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


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
