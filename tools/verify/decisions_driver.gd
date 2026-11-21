extends SceneTree
## The 1.11 decisions through the game's real interface. Runs against the source project
## (`--path game`) or a packaged build (`--main-pack ColonyCharter.pck`); it loads the game's own
## scene by path and acts with real mouse and key events on the controls a player uses.
##
##   godot --main-pack <pck> --script <abs>/decisions_driver.gd -- --case=opening --coast=south
##     --out=<json> [--pck=<pck>]
##
## Cases:
## - opening: seed 3 from the menu. The site card at both seed-3 coasts, clicked on the globe (what
##   it says about the ground, plots, farmland, the coast, each mineral's estimate and range, what
##   the first town could sell first). The capital founded at --coast (north 39.9747 N 122.1984 E,
##   south 4.9780 S 163.5193 E) through the card. The order screen's four answers for the plan's
##   first facility, the order placed, withdrawn before a crew starts, placed again; the supply
##   order signed where the plan is one; a contract goal's action pressed while empty ground is
##   selected; a materials reserve set on the stock page; "advance to the next decision" run to the
##   first delivery; a save, a quit and the menu's continue.
## - tutorial: the tutorial from the menu, played to step 4 (look, two site cards, the capital),
##   saved, quit, continued from the menu: the step, its town and its check come back.
## - events: seed 3 south; time runs with panels left open (the setting off) until a communication
##   waits; its deadline passes with the events page open: the card turns into its outcome in place,
##   once, with the day its effects end.
## - research: the research page's count of teams to assign matches the mission line, and a paid
##   reshuffle says how many cards it can change and changes that many.

const COASTS: Dictionary = {
	"north": Vector2(39.9747, 122.1984),
	"south": Vector2(-4.9780, 163.5193),
}
const GLOBE_DISTANCE: float = 7.0
const SETTLE_FRAMES: int = 24

var options: Dictionary = {"case": "opening", "coast": "south", "out": "", "pck": ""}
var game: Node
var record: Dictionary = {"checks": [], "ok": true}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	root.size = Vector2i(1920, 1080)
	record.options = options.duplicate()
	record.engine = Engine.get_version_info().string
	record.game_version = str(ProjectSettings.get_setting("application/config/version"))
	record.res_has_tests = ResourceLoader.exists("res://tests/v111_decisions.gd")
	record.build = "source project" if record.res_has_tests else "packaged PCK"
	if str(options.get("pck", "")) != "":
		record.pck = str(options.pck)
		record.pck_sha256 = FileAccess.get_sha256(str(options.pck))
	var timer: SceneTreeTimer = create_timer(1500.0)
	timer.timeout.connect(
		func():
			_check(false, "watchdog: the run did not finish")
			_finish()
	)
	call_deferred("run")


func _check(ok: bool, label: String) -> void:
	record.checks.append({"ok": ok, "label": label})
	if not ok:
		record.ok = false
	printerr(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	match str(options.case):
		"opening":
			await _boot(false, "3")
			await _opening()
		"tutorial":
			await _boot(true, "")
			await _tutorial()
		"events":
			await _boot(false, "3")
			await _events()
		"research":
			await _boot(false, "3")
			await _research()
	_finish()


func _finish() -> void:
	var path: String = str(options.out)
	if path != "":
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	printerr("DECISIONS_DRIVER_RESULT ok=%s checks=%d" % [str(record.ok), record.checks.size()])
	quit(0 if record.ok else 1)


static func _main_scene() -> PackedScene:
	return load("res://" + "main.tscn")


## The game from its menu: the tutorial switch as asked, the seed typed, a new game started.
func _boot(tutorial: bool, seed_text: String) -> void:
	game = _main_scene().instantiate()
	root.add_child(game)
	await _frames(4)
	if bool(game.tutorial_on) != tutorial:
		await _press(game.find_child("TutorialToggle", true, false))
		await _frames(2)
	_check(
		bool(game.tutorial_on) == tutorial,
		"the menu's tutorial switch is %s" % ("on" if tutorial else "off")
	)
	if seed_text != "":
		var seed_edit: LineEdit = game.find_child("SeedEdit", true, false)
		seed_edit.text = seed_text
		seed_edit.text_changed.emit(seed_edit.text)
	await _press(game.find_child("NewGame", true, false))
	await _frames(6)
	if not tutorial:
		await _key(KEY_ESCAPE)
		await _frames(4)
		if is_instance_valid(game.overlay):
			game.close_modal()
			await _frames(2)
	while game.map.atlas_refining:
		await process_frame
	record.seed = int(game.sim.state.world.seed)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _click(position: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = position
		event.global_position = position
		root.push_input(event)
		await process_frame


## A real click in the middle of a named control, scrolled into view first.
func _press(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	var scroll: ScrollContainer = _scroll_of(control)
	if scroll != null:
		scroll.ensure_control_visible(control)
		await _frames(2)
	if not control.is_visible_in_tree():
		return false
	await _click(control.get_global_rect().get_center())
	await _frames(3)
	return true


func _press_named(name: String, label: String) -> bool:
	var control: Control = game.find_child(name, true, false)
	var pressed: bool = await _press(control)
	_check(pressed, "%s (%s)" % [label, name])
	return pressed


func _scroll_of(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null


func _key(keycode: Key, ctrl: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.ctrl_pressed = ctrl
		event.pressed = down
		root.push_input(event)
		await process_frame


## What a named control shows: its own text, or the texts of the labels inside it.
func _text(name: String) -> String:
	var node: Node = game.find_child(name, true, false)
	if node == null:
		return ""
	if node is Label or node is Button:
		return node.text
	var lines: Array = []
	_texts(node, lines)
	return " ".join(lines)


## Every visible label's text under a node, for the record.
func _texts(node: Node, out: Array) -> void:
	if node == null:
		return
	if node is Label and node.is_visible_in_tree() and node.text != "":
		out.append(node.text)
	if node is Button and node.is_visible_in_tree() and node.text != "":
		out.append("[" + node.text + (" ·off" if node.disabled else "") + "]")
	for child: Node in node.get_children():
		_texts(child, out)


## Turns the globe so a coordinate is under the camera, zoomed in, and clicks it.
func _pick(lat: float, lon: float) -> Dictionary:
	var map: Node = game.map
	if map.mode != "planet":
		game.navigate("planet")
		await _frames(2)
	map.sky.hold_spin()
	map.sky.spin_factor = 0.0
	map.focus_site = -1
	map.planet_distance = GLOBE_DISTANCE
	map.planet_pitch = clampf(deg_to_rad(lat), -1.2, 1.2)
	map.planet_yaw = deg_to_rad(lon) + map.sky.spin
	map.smooth_yaw = map.planet_yaw
	map.smooth_pitch = map.planet_pitch
	map.smooth_distance = map.planet_distance
	await _frames(SETTLE_FRAMES)
	var point: Vector3 = map.planet.to_global(map.Geo.unit_point(lat, lon) * 3.0)
	var screen: Vector2 = map.camera.unproject_position(point)
	await _click(screen)
	await _frames(4)
	return game.ground.duplicate()


func _card_lines() -> Array:
	var lines: Array = []
	_texts(game.sidebar, lines)
	_texts(game.sidebar_actions, lines)
	return lines


## Ctrl+S, the game freed, the game made again and continued from the menu.
func _save_quit_reload() -> void:
	await _key(KEY_S, true)
	await _frames(6)
	game.queue_free()
	await _frames(4)
	game = _main_scene().instantiate()
	root.add_child(game)
	await _frames(6)
	await _press(game.find_child("ContinueGame", true, false))
	await _frames(8)
	while game.map.atlas_refining:
		await process_frame


func _close_popups() -> void:
	for _i: int in range(6):
		if not is_instance_valid(game.overlay) or not game.overlay.visible:
			return
		await _key(KEY_ESCAPE)
		await _frames(2)


## Runs "advance to the next decision" to a milestone; returns the reason it stopped.
func _advance(milestone: String) -> String:
	var pick: OptionButton = game.find_child("AdvanceMilestone", true, false)
	var index: int = ["decision", "stage", "project", "delivery", "days30", "days90"].find(
		milestone
	)
	if pick != null and index >= 0:
		pick.select(index)
		pick.item_selected.emit(index)
	await _close_popups()
	var from: int = int(game.sim.state.day)
	await _press_named("AdvanceNext", "the top bar's advance control is pressed")
	var frames: int = 0
	while not game.advance_run.is_empty() and frames < 4000:
		await process_frame
		frames += 1
	var reason: String = _text("AdvanceReason")
	record["advance_%s" % milestone] = {
		"from": from,
		"to": int(game.sim.state.day),
		"reason": reason,
		"page": str(game.current_page)
	}
	return reason


# --- opening ---------------------------------------------------------------------------------


func _opening() -> void:
	var cards: Dictionary = {}
	for key: String in ["north", "south"]:
		var at: Vector2 = COASTS[key]
		var picked: Dictionary = await _pick(at.x, at.y)
		_check(not picked.is_empty(), "%s coast: the click on the globe selected the ground" % key)
		var lines: Array = _card_lines()
		cards[key] = {"picked": picked, "lines": lines}
		var text: String = "\n".join(lines)
		for word: Array in [
			["海拔", "elevation"],
			["建设", "construction modifiers"],
			["淡水", "water"],
			["农", "farmland and a farm's output"],
			["海", "coast and fishery"],
			["地块", "buildable plots"],
			["±", "mineral estimates with their range"],
			["先卖什么", "what the first town could sell first"],
		]:
			_check(text.contains(str(word[0])), "%s card shows %s" % [key, str(word[1])])
	record.cards = cards
	var coast: String = str(options.coast)
	var home: Vector2 = COASTS.get(coast, COASTS.south)
	var picked: Dictionary = await _pick(home.x, home.y)
	_check(not picked.is_empty(), "the capital's ground is selected again")
	await _press_named("SettleGroundButton", "the card's founding button")
	var edit: LineEdit = game.modal_box.find_child("SiteNameEdit", true, false)
	if edit != null:
		edit.text = "首府"
	await _press(game.modal_box.find_child("SiteNameConfirm", true, false))
	await _frames(6)
	var sim: RefCounted = game.sim
	_check(sim.state.settlements.size() == 1, "the capital is founded through the card")
	if sim.state.settlements.is_empty():
		return
	var capital: Dictionary = sim.state.settlements[0]
	var region: int = int(capital.region)
	var reg: Dictionary = sim.state.world.regions[region]
	record.capital = {"lat": reg.lat, "lon": reg.lon, "picked": picked}
	await _close_popups()
	var plan: Dictionary = _best_plan(cards[coast].lines)
	record.plan_line = plan
	var kind: String = "farm" if coast == "south" else "mine_ore"
	await _order_and_withdraw(region, kind)
	if coast == "south":
		await _sign_supply(region)
	await _goal_action_from_ground(region)
	await _materials_reserve(region)
	var reason: String = await _advance("delivery")
	_check(
		float(sim.state.exports_total) > 0.0,
		(
			"advance to the next delivery stopped on day %d (%s) with ¥%.0f of exports"
			% [int(sim.state.day), reason, float(sim.state.exports_total)]
		)
	)
	await _close_popups()
	var before: Dictionary = {
		"day": int(sim.state.day),
		"cash": float(sim.state.cash),
		"orders": sim.state.get("supply", {}).get("orders", []).size(),
		"rule": sim.Stocks.set_reserve(capital, "materials"),
		"lat": float(reg.lat),
		"lon": float(reg.lon),
	}
	await _save_quit_reload()
	sim = game.sim
	_check(int(sim.state.day) == int(before.day), "the save comes back on day %d" % int(before.day))
	var again: Dictionary = sim.state.settlements[0] if not sim.state.settlements.is_empty() else {}
	var back: Dictionary = sim.state.world.regions[int(again.get("region", 0))]
	_check(
		(
			absf(float(back.lat) - float(before.lat)) < 0.0001
			and absf(float(back.lon) - float(before.lon)) < 0.0001
		),
		(
			"the capital's coordinate survives the save (%.4f, %.4f)"
			% [float(back.lat), float(back.lon)]
		)
	)
	_check(
		sim.state.get("supply", {}).get("orders", []).size() == int(before.orders),
		"the supply orders survive the save"
	)
	_check(
		is_equal_approx(sim.Stocks.set_reserve(again, "materials"), float(before.rule)),
		"the materials reserve survives the save"
	)


## The card's best plan line ("在这里先卖什么"), as shown.
func _best_plan(lines: Array) -> Dictionary:
	var after: bool = false
	var found: Array = []
	for line: Variant in lines:
		var text: String = str(line)
		if text.contains("先卖什么"):
			after = true
			continue
		if after and found.size() < 4:
			found.append(text)
	return {"lines": found}


## The build page for a facility: the four answers, the order, its withdrawal, the order again.
func _order_and_withdraw(region: int, kind: String) -> void:
	var sim: RefCounted = game.sim
	game.select_region(region)
	await _frames(3)
	await _press_named("OpenBuild", "the town's build button")
	await _frames(4)
	await _press(game.modal_box.find_child("Pick_" + kind, true, false))
	await _frames(4)
	var answers: Dictionary = {}
	for name: String in [
		"CheckoutCash", "CheckoutCrew", "CheckoutService", "CheckoutNet", "CheckoutPayback"
	]:
		answers[name] = _text(name)
	record["checkout_" + kind] = answers
	for name: String in ["CheckoutCash", "CheckoutCrew", "CheckoutService", "CheckoutNet"]:
		_check(str(answers[name]) != "", "the order screen answers %s before payment" % name)
	var order: Dictionary = sim.checkout(region, kind, -1)
	var cash: float = float(sim.state.cash)
	var materials: float = float(sim.settlement(region).stock.materials)
	await _press_named("BuildSelected", "the main order button")
	await _frames(4)
	var paid: float = cash - float(sim.state.cash)
	_check(
		absf(paid - float(order.cash_now)) < 0.5,
		"the cash that left (¥%.0f) is what the screen said (¥%.0f)" % [paid, float(order.cash_now)]
	)
	var uid: int = -1
	for b: Dictionary in sim.settlement(region).buildings:
		if str(b.kind) == kind and int(b.get("remaining", 0)) > 0:
			uid = int(b.get("uid", -1))
	await _close_popups()
	game.select_region(region)
	await _frames(4)
	var withdraw: Control = game.find_child("Withdraw_%d" % uid, true, false)
	var pressed: bool = await _press(withdraw)
	_check(pressed, "the order's withdraw button is on screen (Withdraw_%d)" % uid)
	_check(
		(
			absf(float(sim.state.cash) - cash) < 0.01
			and absf(float(sim.settlement(region).stock.materials) - materials) < 0.0001
		),
		"withdrawn before a crew started: cash and materials are back exactly once"
	)
	_check(sim.audit().is_empty(), "the audit holds after the withdrawal")
	await _press_named("OpenBuild", "the build page again")
	await _frames(4)
	await _press(game.modal_box.find_child("Pick_" + kind, true, false))
	await _frames(4)
	await _press_named("BuildSelected", "the order placed again")
	await _close_popups()


func _sign_supply(region: int) -> void:
	var sim: RefCounted = game.sim
	game.select_region(region)
	await _frames(4)
	var pressed: bool = await _press(game.find_child("SupplySign_food", true, false))
	_check(pressed, "the town panel offers the food supply order once a farm is ordered")
	var open: bool = not sim.Supply.open_order(sim, region, "food").is_empty()
	_check(open, "the food supply order is signed from the town panel")


## Empty ground selected, the contract page's action for the export goal opens the capital's
## production options.
func _goal_action_from_ground(region: int) -> void:
	var home: Dictionary = game.sim.state.world.regions[region]
	await _pick(float(home.lat) + 3.0, float(home.lon) + 3.0)
	_check(not game.ground.is_empty(), "empty ground is selected before the contract action")
	game.open_page("contract")
	await _frames(4)
	var pressed: bool = await _press(game.find_child("GoalFix_exports_total", true, false))
	_check(pressed, "the export goal's action button is on the contract page")
	await _frames(4)
	_check(
		(
			str(game.current_page) == "build"
			and int(game.selected) == region
			and game.ground.is_empty()
		),
		(
			"the action opened the capital's build page (page %s, town %d, category %s)"
			% [str(game.current_page), int(game.selected), str(game.build_category)]
		)
	)
	record.goal_action = {
		"page": str(game.current_page),
		"town": int(game.selected),
		"category": str(game.build_category),
	}
	await _close_popups()


func _materials_reserve(region: int) -> void:
	var sim: RefCounted = game.sim
	game.select_region(region)
	await _frames(3)
	await _press_named("OpenManage", "the town's stock page button")
	await _frames(4)
	var spin: SpinBox = game.find_child("Reserve_materials", true, false)
	_check(spin != null, "the stock page has a materials reserve input")
	if spin == null:
		return
	spin.value = 2000.0
	await _press_named("Set_reserve_materials", "the reserve's set button")
	var rule: float = sim.Stocks.set_reserve(sim.settlement(region), "materials")
	_check(
		absf(sim.tonnes(rule) - 2000.0) < 0.01,
		"the town keeps 2,000 t of materials (%.0f t)" % sim.tonnes(rule)
	)
	var row: Dictionary = sim.Stocks.availability(sim, sim.settlement(region), "materials")
	var shown: String = _text("Stock_materials")
	record.stock_line = shown
	_check(shown.contains("可售"), "the stock line shows total, kept and sellable: " + shown)
	_check(
		float(row.sellable) <= maxf(0.0, float(row.total) - rule) + 0.0001,
		"sellable stops at the reserve"
	)
	await _close_popups()


# --- tutorial --------------------------------------------------------------------------------


func _tutorial() -> void:
	var coach: Node = game.coach
	_check(int(coach.index) == 0, "the tutorial starts at step 1")
	var rules: Dictionary = load("res://simulation/" + "tutorial.gd").data()
	var start: Dictionary = game.sim.state.world.regions[int(rules.start_site)]
	var partner: Dictionary = game.sim.state.world.regions[int(rules.partner_site)]
	for _guard: int in range(30):
		if int(coach.index) >= 3:
			break
		if is_instance_valid(game.overlay) and game.overlay.visible:
			await _key(KEY_ESCAPE)
			await _frames(4)
		if int(coach.index) == 0:
			# Step 1: the wheel turns the zoom, as a player looks around.
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			wheel.position = Vector2(960, 540)
			wheel.global_position = wheel.position
			root.push_input(wheel)
			await _frames(20)
		elif int(coach.index) == 1:
			# Step 2: two site cards read.
			await _pick(float(partner.lat), float(partner.lon))
			await _pick(float(start.lat), float(start.lon))
			await _frames(20)
		elif int(coach.index) == 2:
			# Step 3: the capital on the tutorial's bay, through the card.
			await _pick(float(start.lat), float(start.lon))
			await _press(game.find_child("SettleGroundButton", true, false))
			var edit: LineEdit = game.modal_box.find_child("SiteNameEdit", true, false)
			if edit != null:
				edit.text = "引导首府"
			await _press(game.modal_box.find_child("SiteNameConfirm", true, false))
			await _frames(20)
		await _frames(10)
	_check(
		int(coach.index) == 3,
		"the tutorial reached step 4 by play (step %d)" % (int(coach.index) + 1)
	)
	var home: int = int(coach.context.get("home", -1))
	record.tutorial_before = {"step": int(coach.index), "home": home}
	await _save_quit_reload()
	var row: Dictionary = game.sim.state.get("tutorial", {})
	_check(int(row.get("step", -1)) == 3, "the save carries step 4 (%s)" % str(row.get("step", -1)))
	game.open_page("save")
	await _frames(4)
	await _press_named("ResumeTutorial", "the settings page's resume button")
	await _frames(6)
	_check(
		int(game.coach.index) == 3,
		"continuing resumes step 4 in the same colony (step %d)" % (int(game.coach.index) + 1)
	)
	_check(
		int(game.coach.context.get("home", -2)) == home,
		"the lessons follow the same town (%d)" % int(game.coach.context.get("home", -2))
	)
	_check(game.sim.state.settlements.size() == 1, "no new game was started")
	record.tutorial_after = {
		"step": int(game.coach.index),
		"title": str(game.coach.title_label.text) if game.coach.title_label != null else ""
	}


# --- events ----------------------------------------------------------------------------------


func _events() -> void:
	var home: Vector2 = COASTS.south
	await _pick(home.x, home.y)
	await _press(game.find_child("SettleGroundButton", true, false))
	var edit: LineEdit = game.modal_box.find_child("SiteNameEdit", true, false)
	if edit != null:
		edit.text = "首府"
	await _press(game.modal_box.find_child("SiteNameConfirm", true, false))
	await _frames(6)
	var sim: RefCounted = game.sim
	_check(sim.state.settlements.size() == 1, "the capital is founded")
	if game.panel_pause:
		game.open_page("save")
		await _frames(4)
		game.toggle_panel_pause()
		await _frames(2)
	_check(not game.panel_pause, "panels no longer pause the game (the setting)")
	await _close_popups()
	var waiting: Dictionary = {}
	for _round: int in range(12):
		await _advance("decision")
		for inst: Dictionary in sim.state.get("events_v2", {}).get("instances", []):
			if str(inst.status) in ["pending", "deferred"]:
				waiting = inst
		if not waiting.is_empty():
			break
		await _close_popups()
	_check(not waiting.is_empty(), "a communication arrived by day %d" % int(sim.state.day))
	if waiting.is_empty():
		return
	var id: String = str(waiting.instance_id)
	record.event = {
		"id": id,
		"definition": str(waiting.definition_id),
		"deadline": int(waiting.deadline),
		"arrived": int(sim.state.day)
	}
	if bool(waiting.get("pause_required", false)):
		# A decision that stops the clock: answer it through the page, as a player would.
		game.open_page("events")
		await _frames(4)
		var choice: Control = null
		for node: Node in game.modal_box.find_children(
			("Choice_%s_*" % id).validate_node_name(), "", true, false
		):
			if node is Button and not node.disabled and choice == null:
				choice = node
		var answered: bool = await _press(choice)
		_check(answered, "the waiting decision is answered on the events page")
		await _close_popups()
		return
	game.open_page("events")
	await _frames(4)
	_check(
		game.find_child(("EventDue_" + id).validate_node_name(), true, false) != null,
		"the card shows its deadline"
	)
	game.set_speed(int(sim.progression.time.very_fast_multiplier))
	game.paused = false
	var frames: int = 0
	while frames < 20000:
		await process_frame
		frames += 1
		var still: bool = false
		for inst: Dictionary in sim.state.events_v2.instances:
			if str(inst.instance_id) == id and str(inst.status) in ["pending", "deferred"]:
				still = true
		if not still:
			break
		if game.paused:
			game.paused = false
	await _frames(6)
	var settled: Node = game.find_child(("Settled_" + id).validate_node_name(), true, false)
	_check(
		settled != null,
		"the expired card turned into its outcome in place (day %d)" % int(sim.state.day)
	)
	var ends: String = _text(("SettledEnds_" + id).validate_node_name())
	record.event.settled_text = _text(("Settled_" + id).validate_node_name())
	record.event.ends_text = ends
	var resolved: int = 0
	for row: Dictionary in sim.state.events_v2.get("history", []):
		if str(row.get("instance_id", "")) == id:
			resolved += 1
	record.event.history_rows = resolved
	_check(resolved <= 1, "the event was settled once (%d history rows)" % resolved)
	game.set_speed(0)


# --- research --------------------------------------------------------------------------------


func _research() -> void:
	var home: Vector2 = COASTS.north
	await _pick(home.x, home.y)
	await _press(game.find_child("SettleGroundButton", true, false))
	var edit: LineEdit = game.modal_box.find_child("SiteNameEdit", true, false)
	if edit != null:
		edit.text = "首府"
	await _press(game.modal_box.find_child("SiteNameConfirm", true, false))
	await _frames(6)
	var sim: RefCounted = game.sim
	await _close_popups()
	await _advance("days30")
	await _close_popups()
	game.open_page("research")
	await _frames(6)
	var lines: Array = []
	_texts(game.modal_box, lines)
	var joined: String = "\n".join(lines)
	var teams: int = int(sim.Research.assignable(sim).teams)
	record.research_lines = lines.slice(0, 30)
	_check(joined.contains("可派"), "the research page shows teams to assign")
	var shown: Array = []
	for index: int in range(lines.size()):
		if str(lines[index]) == "可派":
			for near: int in [index - 1, index + 1]:
				if near >= 0 and near < lines.size():
					shown.append(str(lines[near]))
	_check(
		shown.has(str(teams)),
		"the page's count is the assignable count (%d; next to 可派: %s)" % [teams, str(shown)]
	)
	var mission: String = str(game.mission.text)
	record.mission_line = mission
	if mission.contains("支研究团队可派"):
		_check(
			mission.contains("有 %d 支研究团队可派" % teams),
			"the mission line's count is the same (%s)" % mission
		)
	var button: Button = null
	var category: String = ""
	for node: Node in game.modal_box.find_children("Reshuffle_*", "Button", true, false):
		if button == null and node is Button and node.is_visible_in_tree():
			button = node
			category = str(node.name).trim_prefix("Reshuffle_")
	_check(button != null, "the research page has a paid reshuffle")
	if button == null:
		return
	var preview: Dictionary = sim.Research.reshuffle_preview(sim, category)
	record.reshuffle = {"button": button.text, "preview": preview, "category": category}
	_check(
		button.text.contains(str(int(preview.get("changes", -1)))) or button.disabled,
		"the reshuffle says how many cards it can change: " + button.text
	)
	if button.disabled:
		var why: String = _text("ReshuffleWhy_" + category)
		_check(why != "", "a reshuffle that cannot change anything says why: " + why)
		return
	var before: Array = _cards(sim, category)
	var cash: float = float(sim.state.cash)
	await _press(button)
	var after: Array = _cards(sim, category)
	var changed: int = 0
	for index: int in range(mini(before.size(), after.size())):
		if str(before[index]) != str(after[index]):
			changed += 1
	record.reshuffle.changed = changed
	record.reshuffle.paid = cash - float(sim.state.cash)
	_check(
		changed == int(preview.changes),
		"the reshuffle changed %d cards, as it said (%d)" % [changed, int(preview.changes)]
	)


func _cards(sim: RefCounted, category: String) -> Array:
	var offer: Variant = sim.state.get("research", {}).get("offers", {}).get(category, [])
	return (offer as Array).duplicate() if offer is Array else []
