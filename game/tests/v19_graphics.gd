extends SceneTree
## 1.9 picture quality and map polish, headless: the 高画质 choice is saved in the user override
## file and removed again for 标准画质; anti-aliasing levels set multisampling; the settings page
## carries the quality, anti-aliasing and plot-mark rows and they work; a finished technology
## raises a notice once, and a loaded game raises none for its old work; candidate sites are
## named only while the player chooses where to land; cargo dots are small; stage three's
## deadline is a year later than in 1.9's first preview.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Graphics = preload("res://ui/graphics.gd")
const MapBase = preload("res://world/map_base.gd")
const FlatView = preload("res://world/flat_view.gd")
const STAGE_THREE_NORMAL: int = 1860

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_override_file()
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await _anti_aliasing(scene)
	await _settings_rows(scene)
	await _notices(scene)
	await _labels(scene)
	_cargo_and_deadline(scene)
	Graphics.choose(Graphics.STANDARD)
	root.remove_child(scene)
	scene.free()
	print("V19_GRAPHICS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _override_file() -> void:
	Graphics.choose(Graphics.STANDARD)
	check(Graphics.chosen() == Graphics.STANDARD, "standard quality without an override file")
	Graphics.choose(Graphics.HIGH)
	check(FileAccess.file_exists(Graphics.OVERRIDE), "high quality writes the override file")
	var file := ConfigFile.new()
	check(file.load(Graphics.OVERRIDE) == OK, "the override file reads back")
	check(
		str(file.get_value(Graphics.SECTION, Graphics.METHOD_KEY, "")) == Graphics.HIGH,
		"it sets the renderer to Forward+ for the next start"
	)
	check(Graphics.chosen() == Graphics.HIGH, "high quality is the choice")
	check(
		(
			ProjectSettings.get_setting("application/config/project_settings_override", "")
			== Graphics.OVERRIDE
		),
		"the project reads that file at start"
	)
	check(
		bool(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3", false)),
		"a computer without Vulkan or Direct3D 12 falls back to the standard renderer"
	)
	Graphics.choose(Graphics.STANDARD)
	check(not FileAccess.file_exists(Graphics.OVERRIDE), "standard quality removes the file")


func _anti_aliasing(scene: Node) -> void:
	var viewport: Viewport = scene.get_viewport()
	check(scene.visual_aa == Graphics.AA_HIGH, "anti-aliasing starts on high")
	check(viewport.msaa_3d == Viewport.MSAA_4X, "high is 4x multisampling")
	Graphics.apply_anti_aliasing(viewport, Graphics.AA_MEDIUM)
	check(viewport.msaa_3d == Viewport.MSAA_2X, "medium is 2x")
	Graphics.apply_anti_aliasing(viewport, Graphics.AA_OFF)
	check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "off is off")
	Graphics.apply_anti_aliasing(viewport, Graphics.AA_HIGH)
	await process_frame


func _press(scene: Node, name: String) -> bool:
	var button: Button = scene.modal_box.find_child(name, true, false)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


func _settings_rows(scene: Node) -> void:
	scene.open_page("save")
	await process_frame
	for name: String in [
		"Render_gl_compatibility",
		"Render_forward_plus",
		"AA_off",
		"AA_medium",
		"AA_high",
		"Visual_plots"
	]:
		check(
			scene.modal_box.find_child(name, true, false) != null, "the settings page has " + name
		)
	check(_press(scene, "AA_medium"), "anti-aliasing can be set to medium")
	await process_frame
	check(
		scene.visual_aa == Graphics.AA_MEDIUM and scene.get_viewport().msaa_3d == Viewport.MSAA_2X,
		"and it applies at once"
	)
	check(_press(scene, "AA_high"), "and back to high")
	await process_frame
	var before: bool = bool(scene.plot_marks)
	check(_press(scene, "Visual_plots"), "plot marks can be switched")
	await process_frame
	check(
		(
			bool(scene.plot_marks) != before
			and bool(scene.map.plot_marks_on) == bool(scene.plot_marks)
		),
		"and the map follows"
	)
	_press(scene, "Visual_plots")
	await process_frame
	check(_press(scene, "Render_forward_plus"), "high quality can be chosen")
	await process_frame
	check(Graphics.chosen() == Graphics.HIGH, "the choice is saved for the next start")
	check(
		Graphics.status_text().contains("重启") or Graphics.high_running(),
		"the page says it applies after a restart"
	)
	check(_press(scene, "Render_gl_compatibility"), "standard quality can be chosen again")
	await process_frame
	check(Graphics.chosen() == Graphics.STANDARD, "and the override is gone")
	scene.close_modal()


func _notices(scene: Node) -> void:
	scene._watch_research()
	var research: Dictionary = scene.sim.state.research
	var count: int = scene.notices.get_child_count()
	var tech: String = ""
	for key: String in scene.sim.config.techs:
		if not research.completed.has(key):
			tech = key
			break
	research.completed.append(tech)
	scene._watch_research()
	await process_frame
	check(scene.notices.get_child_count() == count + 1, "a finished technology raises a notice")
	var notice: Node = scene.notices.get_child(scene.notices.get_child_count() - 1)
	var text: String = ""
	for label: Label in notice.find_children("*", "Label", true, false):
		text += label.text
	check(text.contains("科研完成"), "it says research is complete")
	check(
		text.contains(str(scene.sim.config.techs[tech].name)), "and names the technology: " + text
	)
	scene._watch_research()
	check(scene.notices.get_child_count() == count + 1, "only once")
	var loaded: Dictionary = research.duplicate(true)
	for key: String in scene.sim.config.techs:
		if (
			not loaded.completed.has(key)
			and loaded.completed.size() < research.completed.size() + 5
		):
			loaded.completed.append(key)
	scene.sim.state.research = loaded
	scene._watch_research()
	await process_frame
	check(
		scene.notices.get_child_count() == count + 1,
		"a loaded game raises no notices for work already done"
	)
	scene.sim.state.research = research


func _labels(scene: Node) -> void:
	var map: Node3D = scene.map
	map.sync_state(scene.sim.state)
	map._update_markers()
	var before: int = _label_count(map)
	check(
		scene.sim.state.settlements.is_empty() and before >= FlatView.LABELLED_SITES,
		"while choosing where to land, the richest candidates are named (%d)" % before
	)
	var pairs: Array = scene.sim.geo.get("playability", {}).get("pairs", [[0, 1]])
	check(scene.sim.act("settle", {"site": int(pairs[0][0])}) == "", "the colony lands")
	map.selected_region = int(pairs[0][0])
	map.sync_state(scene.sim.state)
	map._update_markers()
	var after: int = _label_count(map)
	check(after <= 2, "after landing only the colony and the selected site are named (%d)" % after)
	map.marker_filter = "ore"
	map._update_markers()
	check(_label_count(map) > after, "filtering the map for a site names candidates again")
	map.marker_filter = "all"
	map._update_markers()


func _label_count(map: Node3D) -> int:
	if map.marker_root == null:
		return 0
	return map.marker_root.find_children("*", "Label3D", true, false).size()


func _cargo_and_deadline(scene: Node) -> void:
	check(
		MapBase.CARGO_DOT_GLOBE <= 0.015 and MapBase.CARGO_DOT_FLAT <= 0.02,
		"cargo dots are small on both maps"
	)
	check(
		int(scene.sim.contract_rules.deadlines.normal[2]) == STAGE_THREE_NORMAL,
		"stage three's deadline is in year six on normal"
	)
	for level: String in ["easy", "normal", "hard"]:
		var days: Array = scene.sim.contract_rules.deadlines[level]
		var rising: bool = true
		for index: int in range(1, days.size()):
			rising = rising and int(days[index]) > int(days[index - 1])
		check(rising, level + " deadlines still come one after another")
