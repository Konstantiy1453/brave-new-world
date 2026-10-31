extends RefCounted
## The release check of §8.4, on the exported EXE, through its real buttons and real clock:
## --dev --dev-script=<this file> --drive-out=<folder> --drive-part=first, then again with
## --drive-part=second. Writes drive_<part>.json and screenshots to the folder.
## Run with APPDATA isolated: part two writes a sample 1.6 save into its ColonyCharter\v16 folder.

const WAIT_LIMIT_SECONDS: float = 120.0
const SECONDS_BETWEEN_CHECKS: float = 0.1

static var report: Dictionary = {}
static var folder: String = ""


static func run(g) -> void:
	var part: String = "first"
	var sample: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--drive-out="):
			folder = argument.trim_prefix("--drive-out=")
		if argument.begins_with("--drive-part="):
			part = argument.trim_prefix("--drive-part=")
		if argument.begins_with("--drive-sample="):
			sample = argument.trim_prefix("--drive-sample=")
	DirAccess.make_dir_recursive_absolute(folder)
	report = {
		"evidence": "exported EXE, scripted input through real buttons; not a human playtest",
		"exported": OS.has_feature("template"),
		"user_data": OS.get_user_data_dir(),
		"steps": [],
		"failures": [],
	}
	if part == "first":
		await _first_part(g)
	else:
		await _second_part(g, sample)
	report.passed = report.failures.is_empty()
	var file: FileAccess = FileAccess.open(folder + "/drive_" + part + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("V17_DRIVE_RESULT part=%s failures=%d" % [part, report.failures.size()])
	g.get_tree().quit(0 if report.failures.is_empty() else 1)


static func _note(text: String, ok: bool = true) -> void:
	report.steps.append(("OK   " if ok else "FAIL ") + text)
	print(("OK   " if ok else "FAIL ") + text)
	if not ok:
		report.failures.append(text)


static func _frame(g) -> void:
	await g.get_tree().process_frame
	await g.get_tree().process_frame


static func _press(g, control_name: String) -> bool:
	var found: Node = g.ui.find_child(control_name, true, false)
	if not (found is Button) or not found.is_visible_in_tree() or found.disabled:
		_note("button %s is there and enabled" % control_name, false)
		return false
	found.pressed.emit()
	await _frame(g)
	return true


static func _wait(g, what: String, condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_LIMIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			_note("%s (game day %d)" % [what, int(g.sim.state.day)])
			return true
		await g.get_tree().create_timer(SECONDS_BETWEEN_CHECKS).timeout
	_note(what + " within the time limit", false)
	return false


static func _shot(g, name: String) -> void:
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(folder + "/" + name + ".png")


static func _step(g) -> String:
	if not g.coach.active():
		return ""
	return str(g.coach.steps()[g.coach.index].id)


## Answers whatever stops the clock the way a player would: choose something, close the page.
static func _keep_running(g) -> void:
	var pending: Array = g.Events.view(g.sim).pending
	for node: Dictionary in pending:
		for choice: Dictionary in node.choices:
			if choice.id != "defer" and bool(choice.enabled):
				g.act("event_v2", {"instance_id": node.instance_id, "choice": choice.id})
				break
	if is_instance_valid(g.overlay) and not g.menu_open:
		g.close_modal()


static func _first_part(g) -> void:
	await _frame(g)
	_note("the main menu opens with the tutorial on", g.menu_open and g.tutorial_on)
	await _shot(g, "01_menu")
	if not await _press(g, "NewGame"):
		return
	_note("the tutorial starts", g.coach.active() and _step(g) == "look")
	await _shot(g, "02_tutorial_start")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	g._unhandled_input(wheel)
	await _wait(g, "the camera step passes", func() -> bool: return _step(g) == "cards")
	var chooser: OptionButton = g.ui.find_child("RegionChooser", true, false)
	chooser.select(3)
	chooser.item_selected.emit(3)
	await _frame(g)
	chooser.select(0)
	chooser.item_selected.emit(0)
	await _wait(g, "two site cards read", func() -> bool: return _step(g) == "land")
	await _shot(g, "03_land")
	await _press(g, "SettleButton")
	await _wait(g, "the capital is founded", func() -> bool: return _step(g) == "income")
	await _press(g, "OpenBuild")
	await _shot(g, "04_build")
	await _press(g, "Build_mine_ore")
	await _press(g, "Build_mine_copper")
	g.close_modal()
	await _wait(g, "two mines ordered", func() -> bool: return _step(g) == "clock")
	await _press(g, "Speed_10")
	await _wait(g, "the clock runs", func() -> bool: return _step(g) == "export")
	await _wait(g, "the first export arrives", func() -> bool: return _step(g) == "ledger")
	await _press(g, "Nav_economy")
	await _shot(g, "05_economy")
	g.close_modal()
	await _wait(g, "the ledger is read", func() -> bool: return _step(g) == "beds")
	await _press(g, "OpenBuild")
	await _press(g, "Build_habitat")
	g.close_modal()
	await _wait(g, "housing ordered", func() -> bool: return _step(g) == "problem")
	await _press(g, "Speed_10")
	var seen: bool = await _wait(
		g,
		"the red line appears",
		func() -> bool: return g.ui.find_child("Fix_water", true, false) != null
	)
	if seen:
		await _shot(g, "06_shortage")
		await _press(g, "Fix_water")
		await _shot(g, "07_fix_opens_build")
		await _press(g, "Build_water")
		g.close_modal()
	await _press(g, "Speed_10")
	await _wait(g, "the shortage clears", func() -> bool: return _step(g) == "research")
	await _press(g, "OpenBuild")
	await _press(g, "Build_lab")
	g.close_modal()
	g.act("research_allocate", {"tech": "survey", "staff": 4})
	await _wait(g, "scientists on a project", func() -> bool: return _step(g) == "stage")
	_note("still in stage 1 at the save", int(g.sim.state.contract.stage) == 1)
	await _frame(g)
	g.save_slot(g.SAVE_MANUAL)
	await _shot(g, "08_saved")
	report.saved_day = int(g.sim.state.day)
	report.saved_cash = float(g.sim.state.cash)
	_note("saved on day %d" % int(g.sim.state.day), FileAccess.file_exists(g.SAVE_MANUAL))


static func _second_part(g, sample: String) -> void:
	await _frame(g)
	var button: Node = g.ui.find_child("ContinueGame", true, false)
	_note("the menu offers to continue", button != null and not button.disabled)
	report.continue_text = str(button.text) if button != null else ""
	_note(
		"it names planet, day and cash: " + report.continue_text, report.continue_text.contains("第")
	)
	await _shot(g, "11_menu_continue")
	if not await _press(g, "ContinueGame"):
		return
	_note("the save loads", not g.menu_open and int(g.sim.state.day) > 0)
	await _shot(g, "12_continued")
	g.close_modal()
	g.paused = false
	g.set_speed(10)
	var deadline: int = Time.get_ticks_msec() + int(WAIT_LIMIT_SECONDS * 1000.0)
	while int(g.sim.state.contract.stage) < 2 and Time.get_ticks_msec() < deadline:
		_keep_running(g)
		if g.paused:
			g.paused = false
			g.set_speed(10)
		await g.get_tree().create_timer(SECONDS_BETWEEN_CHECKS).timeout
	_note("stage 2 reached on day %d" % int(g.sim.state.day), int(g.sim.state.contract.stage) >= 2)
	await _shot(g, "13_stage_two")
	report.audit = g.sim.audit()
	_note("the audit is clean", report.audit.is_empty())
	await _load_old_save(g, sample)


## A 1.6 save at the place 1.6 keeps them, offered through the settings page.
static func _load_old_save(g, sample: String) -> void:
	var appdata: String = OS.get_environment("APPDATA")
	if not appdata.contains("evidence"):
		_note("APPDATA is isolated for the 1.6 save check", false)
		return
	var old_path: String = g.old_save_path(g.OLD_SAVE_MANUAL)
	DirAccess.make_dir_recursive_absolute(old_path.get_base_dir())
	var source: PackedByteArray = FileAccess.get_file_as_bytes(sample)
	_note("the 1.6 sample is available", not source.is_empty())
	var copy: FileAccess = FileAccess.open(old_path, FileAccess.WRITE)
	copy.store_buffer(source)
	copy.close()
	g.paused = true
	g.open_page("save")
	await _frame(g)
	var found: Button = null
	for item: Button in g.modal_box.find_children("*", "Button", true, false):
		if item.text.contains("1.6 手动档"):
			found = item
	_note("the settings page offers the 1.6 save", found != null and not found.disabled)
	await _shot(g, "14_settings")
	if found == null:
		return
	found.pressed.emit()
	await _frame(g)
	_note(
		(
			"the 1.6 save migrates, schema %d, day %d"
			% [int(g.sim.state.schema), int(g.sim.state.day)]
		),
		int(g.sim.state.schema) == 3
	)
	_note("its world keeps its version: " + str(g.sim.geo.version), str(g.sim.geo.version) != "")
	await _shot(g, "15_migrated")
	var after: PackedByteArray = FileAccess.get_file_as_bytes(old_path)
	_note("the 1.6 file is unchanged", after == source)
