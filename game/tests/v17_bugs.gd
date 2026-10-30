extends SceneTree
## Regression tests for the W1 bug list in the 1.7 brief.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Events = preload("res://simulation/events_v2.gd")
const Career = preload("res://simulation/career.gd")
const Company = preload("res://simulation/company.gd")

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_bug1_event_build_checks_labour()
	_bug3_handover_size()
	_bug6_aid_goes_to_shortage()
	await _ui_bugs()
	_bug12_export_filters()
	print("V17_BUGS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _bug1_event_build_checks_labour() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	sim.act("settle", {"region": 0})
	var place: Dictionary = sim.settlement(0)
	sim.state.events_v2.next_draw = 99999
	Events._open(sim, "water", 0)
	var instance: Dictionary = sim.state.events_v2.instances[0]
	var build_option: Dictionary = {}
	for node_id: String in Events.definitions().definitions.water.nodes:
		for option: Dictionary in Events.definitions().definitions.water.nodes[node_id].choices:
			if option.has("build"):
				build_option = option
				instance.node = node_id
				break
	check(not build_option.is_empty(), "water chain has a build option to test")
	place.stock.materials = 500.0
	place.stock.parts = 100.0
	sim.state.cash = 50000.0
	check(
		Events._reason(sim, instance, build_option) == "",
		"build option open while workers are free"
	)
	var jobs: int = int(sim.build_preview(0, str(build_option.build)).jobs)
	var spare: int = sim.free_workers(place)
	place.workers = int(place.workers) - spare + jobs - 1
	place.population = int(place.children) + int(place.workers) + int(place.scientists)
	var reason: String = Events._reason(sim, instance, build_option)
	check(reason.contains("工人"), "build option refused when one worker short: " + reason)
	check(
		reason.contains(str(jobs)) and reason.contains(str(jobs - 1)),
		"refusal states needed and free workers"
	)
	var cash: float = float(sim.state.cash)
	var count: int = place.buildings.size()
	instance.status = "pending"
	var error: String = Events.act(
		sim, {"instance_id": instance.instance_id, "choice": build_option.id}
	)
	check(error != "" and float(sim.state.cash) == cash, "refused option spends nothing")
	check(place.buildings.size() == count, "refused option builds nothing")
	var text: String = Events._description(sim, instance, build_option)
	check(text.contains("空闲"), "option text shows free workers: " + text)


func _bug3_handover_size() -> void:
	var sim: RefCounted = Sim.new()
	var error: String = sim.load_game("res://data/acceptance_success.json")
	check(error == "", "success fixture loads: " + error)
	Career.ensure(sim)
	Career.capture_checkpoint(sim)
	var path: String = "user://bug3_career.json"
	check(
		Career.handover(sim, 42, "workers", "hard", path, 2) == "",
		"handover to a chosen planet commits"
	)
	check(int(sim.state.world.size) == 2, "next planet uses the chosen size")
	check(
		sim.state.advantage == "workers" and sim.state.difficulty == "hard",
		"next planet uses chosen opening and difficulty"
	)
	var kept: RefCounted = Sim.new()
	kept.new_game(260129, "capital", 0, "normal")
	var quick_world: Dictionary = kept.state.world
	check(int(quick_world.size) == 0, "small planet fixture")


func _bug6_aid_goes_to_shortage() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	sim.act("settle", {"region": 0})
	sim.act("settle", {"region": 1})
	sim.state.events_v2.next_draw = 99999
	for _i: int in range(12):
		sim.tick()
	var capital: Dictionary = sim.settlement(0)
	var outpost: Dictionary = sim.settlement(1)
	sim._produce(capital, "food", 400.0, "test surplus")
	sim._produce(capital, "materials", 200.0, "test surplus")
	sim._produce(capital, "parts", 60.0, "test surplus")
	sim._consume(outpost, "food", float(outpost.stock.food))
	sim._refresh(capital)
	sim._refresh(outpost)
	sim.state.company.stage = "warning"
	var before: float = float(outpost.stock.food)
	check(
		sim.act("company", {"operation": "accept", "offer": "supplies"}) == "",
		"supplies aid accepted"
	)
	var terms: Dictionary = sim.state.company.aid[0]
	check(int(terms.region) == 1, "aid is addressed to the settlement that lacks food")
	for _i: int in range(3):
		sim.tick()
	check(float(outpost.stock.food) > before, "aid food physically arrives at the outpost")
	check(sim.audit().is_empty(), "aid delivery keeps the audit clean")


func _ui_bugs() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	_bug4_menu_cannot_close(game)
	_start_colony(game)
	_bug7_policy_controls(game)
	_bug8_runway(game)
	_bug9_copy(game)
	_bug11_panel_pause(game)
	_bug12_qa_loaders(game)
	game.queue_free()
	await process_frame


func _start_colony(game: Node) -> void:
	game.sim.new_game(260129, "capital", 1, "normal")
	game.sim.act("settle", {"region": 0})
	game.sim.act("build", {"region": 0, "kind": "mine_ore"})
	game.sim.state.events_v2.next_draw = 99999
	game.last_status = game.sim.state.status
	game.map.setup(game.sim.geo if "geo" in game.sim else game.sim.state.world)
	game.close_modal()
	game.paused = true
	game.resume_on_close = false


func _buttons(game: Node) -> Array:
	return game.ui.find_children("*", "Button", true, false)


func _bug4_menu_cannot_close(game: Node) -> void:
	check(game.menu_open, "game starts on the main menu")
	var has_close: bool = false
	for button: Button in _buttons(game):
		if (
			button.text.contains("关闭")
			and is_instance_valid(game.overlay)
			and game.overlay.is_ancestor_of(button)
		):
			has_close = true
	check(not has_close, "main menu has no close button")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	game._unhandled_input(key)
	check(game.menu_open and is_instance_valid(game.overlay), "Esc does not dismiss the main menu")


func _bug7_policy_controls(game: Node) -> void:
	game.open_page("enterprise")
	var tax: SpinBox = game.modal_box.find_child("PolicyTax", true, false)
	var reserve: SpinBox = game.modal_box.find_child("PolicyFoodReserve", true, false)
	check(tax != null and reserve != null, "tax and food reserve have direct controls")
	check(tax.max_value == 50.0 and tax.min_value == 0.0, "tax control spans 0-50%")
	check(
		reserve.min_value == 3.0 and reserve.max_value == 25.0,
		"food reserve control spans 3-25 days"
	)
	check(is_equal_approx(tax.value, 18.0), "tax control shows the 18% default")
	check(is_equal_approx(reserve.value, 12.0), "reserve control shows the 12-day default")
	game.close_modal()


func _bug8_runway(game: Node) -> void:
	var sim: RefCounted = game.sim
	for _i: int in range(8):
		sim.tick()
	sim.state.operating_history = []
	for day: int in range(7):
		sim.state.operating_history.append(
			{"day": day, "net": -10.0, "income": 0.0, "expense": 10.0}
		)
	sim.state.operating_net = -500.0
	sim.state.cash = 1000.0
	game.open_page("economy")
	var found: bool = false
	for label: Label in game.modal_box.find_children("*", "Label", true, false):
		if label.text.contains("预计现金可维持") and label.text.contains("100.0 天"):
			found = true
	check(found, "economy page runway uses the 7-day average, not one bad day")
	game.close_modal()


func _bug9_copy(game: Node) -> void:
	game.refresh_sidebar()
	var claims: bool = false
	for label: Label in game.sidebar.find_children("*", "Label", true, false):
		if label.text.contains("地区面积随星球尺寸变化"):
			claims = true
	check(not claims, "sidebar no longer claims region area scales with planet size")


func _bug11_panel_pause(game: Node) -> void:
	var sim: RefCounted = game.sim
	game.panel_pause = true
	game.paused = false
	game.speed = 1
	var day: int = int(sim.state.day)
	game.open_page("economy")
	check(game.paused, "panel pauses by default")
	game.advance_time(30.0)
	check(int(sim.state.day) == day, "no time passes behind a pausing panel")
	game.close_modal()
	check(not game.paused, "closing restores the previous speed")
	game.paused = true
	game.open_page("economy")
	game.close_modal()
	check(game.paused, "closing leaves a game paused by the player paused")
	game.panel_pause = false
	game.paused = false
	game.open_page("economy")
	check(not game.paused, "with the setting off a panel does not pause")
	game.advance_time(10.0)
	check(int(sim.state.day) > day, "with the setting off time passes behind a panel")
	game.close_modal()
	game.panel_pause = true
	game.paused = false
	Events._open(sim, "seed_crate", 0)
	game.panel_pause = false
	game.advance_time(30.0)
	check(
		game.paused and game.current_page == "events",
		"event decisions still pause with the setting off"
	)
	game.close_modal()
	check(game.paused, "closing with the decision unanswered stays paused")
	game.panel_pause = true
	sim.state.events_v2.instances.clear()
	sim.state.events_v2.seen.clear()
	sim.state.event = {}


func _bug12_qa_loaders(game: Node) -> void:
	game.dev_mode = false
	game.open_page("save")
	var shows_fixture: bool = false
	for button: Button in game.modal_box.find_children("*", "Button", true, false):
		if button.text.contains("验收") or button.text.contains("兼容性示例"):
			shows_fixture = true
	check(not shows_fixture, "settings page hides QA loaders outside debug and --dev")
	game.close_modal()
	game.dev_mode = true
	game.open_page("save")
	var shows_when_dev: bool = false
	for button: Button in game.modal_box.find_children("*", "Button", true, false):
		if button.text.contains("验收"):
			shows_when_dev = true
	check(shows_when_dev, "settings page offers QA loaders under --dev")
	game.close_modal()


func _bug12_export_filters() -> void:
	var preset := ConfigFile.new()
	check(preset.load("res://export_presets.cfg") == OK, "export preset parses")
	var include: String = str(preset.get_value("preset.0", "include_filter", ""))
	var exclude: String = str(preset.get_value("preset.0", "exclude_filter", ""))
	check(not include.contains("data/v16"), "export no longer includes the 1.6 fixtures")
	for pattern: String in [
		"data/acceptance_*",
		"data/v16/*",
		"data/v17/acceptance_*",
		"ui/capture_suite*.gd",
		"tests/*"
	]:
		check(exclude.contains(pattern), "export excludes " + pattern)
