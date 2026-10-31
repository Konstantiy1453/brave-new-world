extends SceneTree
## Phase 7: the tutorial run from start to end in a headless game, skip and replay, tips that show
## once, and the new pages: build dialog with plots, site card, settlement panel, economy page.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const Stats = preload("res://simulation/stats.gd")
const WorldGen = preload("res://world/world_gen.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Coach = preload("res://ui/tutorial_coach.gd")
const Sim = preload("res://simulation/sim.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")

const SETTINGS: String = "user://settings.cfg"
const MAX_DAYS: int = 400

var checks: int = 0
var failures: Array[String] = []
var game: Node


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	_data_is_sound()
	_pinned_world()
	await _run_tutorial()
	await _skip_and_replay()
	await _tips_show_once()
	await _pages()
	await _menu()
	await _upgrade_from_old_version()
	_stats_rollups()
	print("V17_TUTORIAL_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


## Coach checks run on a timer, so tests give it a moment after each move.
func settle_coach() -> void:
	for _i: int in range(2):
		game.coach._process(1.0)
	await process_frame


func _data_is_sound() -> void:
	var rules: Dictionary = Tutorial.data()
	check(rules.steps.size() == 14, "fourteen tutorial steps")
	var ids: Dictionary = {}
	for step: Dictionary in rules.steps:
		ids[step.id] = true
		check(str(step.text) != "" and step.has("done"), "step %s has text and a goal" % step.id)
	check(ids.size() == rules.steps.size(), "step ids are unique")


## The planet the tutorial is pinned to has what its text promises.
func _pinned_world() -> void:
	var rules: Dictionary = Tutorial.data()
	var sim: RefCounted = Sim.new()
	sim.new_game(int(rules.seed), str(rules.opening), int(rules.size), str(rules.difficulty))
	var start: Dictionary = sim.state.world.regions[int(rules.start_site)]
	var partner: Dictionary = sim.state.world.regions[int(rules.partner_site)]
	check(float(start.deposits.ore) > 0.0, "the recommended start has ore")
	check(float(start.deposits.copper) > 0.0, "and copper")
	check(float(partner.fertility) >= 0.6, "the recommended partner is fertile")
	check(int(partner.id) in start.neighbors, "and shares a landmass with the start")
	check(sim.plot_choices(int(partner.id), "farm").size() > 0, "and has farm plots")
	# The scripted shortage really happens on this planet with the tutorial's buildings.
	check(sim.act("settle", {"site": 0}) == "", "landing works")
	for kind: String in ["mine_ore", "mine_copper", "habitat"]:
		check(sim.act("build", {"site": 0, "kind": kind}) == "", "building " + kind)
	for _i: int in range(6):
		sim.tick()
	check(sim.act("tutorial_shortage", {"site": 0}) == "", "the shortage can be started")
	sim.tick()
	var short: bool = false
	for entry: Dictionary in sim.settlement(0).shortages:
		short = short or entry.key == "water"
	check(short, "the scripted first shortage happens")
	check(sim.act("build", {"site": 0, "kind": "water"}) == "", "a second pump can be ordered")
	for _i: int in range(5):
		sim.tick()
	var cleared: bool = true
	for entry: Dictionary in sim.settlement(0).shortages:
		cleared = cleared and entry.key != "water"
	check(cleared, "a second pump clears it")
	check(sim.audit().is_empty(), "the shortage passes the audit")


func step_id() -> String:
	return str(game.coach.steps()[game.coach.index].id) if game.coach.active() else ""


func tick_until(goal: Callable, days: int = MAX_DAYS) -> void:
	for _i: int in range(days):
		if goal.call():
			return
		_answer_events()
		game.sim.tick()
		game.map.sync_state(game.sim.state)
	game.refresh()


func _answer_events() -> void:
	var definitions: Dictionary = EventsV2.definitions().definitions
	for node: Dictionary in EventsV2.view(game.sim).pending:
		var options: Array = definitions[node.id].nodes[node.node].choices
		for choice: Dictionary in node.choices:
			if (
				choice.id == "defer"
				or not bool(choice.enabled)
				or _takes_scientists(options, choice)
			):
				continue
			game.sim.act("event_v2", {"instance_id": node.instance_id, "choice": choice.id})
			break


func _takes_scientists(options: Array, choice: Dictionary) -> bool:
	for option: Dictionary in options:
		if option.id == choice.id:
			return option.has("investigate")
	return false


func _run_tutorial() -> void:
	game.start_tutorial()
	await process_frame
	check(game.coach.active(), "the tutorial starts")
	check(game.coach.visible, "the coach shows")
	check(not game.menu_open and not is_instance_valid(game.overlay), "and blocks nothing")
	check(step_id() == "look", "step: look around")
	game.coach.note_camera()
	await settle_coach()
	check(step_id() == "cards", "step: read site cards")
	game.select_region(3)
	game.coach._draw_outline()
	game.select_region(0)
	await settle_coach()
	check(step_id() == "land", "step: land")
	check(game.selected == 0, "the recommended site is selected")
	var settle_button: Control = game.ui.find_child("SettleButton", true, false)
	check(settle_button != null and settle_button.is_visible_in_tree(), "the target exists")
	check(game.coach._target() == settle_button, "and is outlined")
	check(game.sidebar_actions.is_ancestor_of(settle_button), "and stays on screen")
	game.act("settle", {"site": 0})
	await settle_coach()
	check(step_id() == "income", "step: start income")
	game.open_page("build")
	await process_frame
	check(
		game.coach._target() == game.ui.find_child("Build_mine_ore", true, false),
		"the build button is outlined"
	)
	game.act("build", {"site": 0, "kind": "mine_ore"})
	game.act("build", {"site": 0, "kind": "mine_copper"})
	game.close_modal()
	await settle_coach()
	check(step_id() == "clock", "step: run time")
	tick_until(func() -> bool: return int(game.sim.state.day) >= 3)
	await settle_coach()
	# On this planet the first sale can land the day the clock step ends.
	check(step_id() in ["export", "ledger"], "step: first export")
	tick_until(func() -> bool: return float(game.sim.state.exports_total) > 0.0)
	await settle_coach()
	check(step_id() == "ledger", "step: read the ledger")
	game.open_page("economy")
	game.close_modal()
	await settle_coach()
	check(step_id() == "beds", "step: make room for people")
	game.act("build", {"site": 0, "kind": "habitat"})
	await settle_coach()
	check(step_id() == "problem", "step: fix a problem")
	check(int(game.coach.context.shortage_day) >= 0, "the shortage has begun")
	tick_until(func() -> bool: return _has_shortage("water"), 3)
	check(_has_shortage("water"), "the red line is there")
	game.refresh_sidebar()
	await process_frame
	var fix: Control = game.sidebar.find_child("Fix_water", true, false)
	check(fix != null, "with a fix button")
	fix.pressed.emit()
	await process_frame
	check(
		game.current_page == "build" and game.build_category == "utilities",
		"which opens the right page"
	)
	game.sim._produce(game.sim.settlement(0), "parts", 10.0, "test")
	game.act("build", {"site": 0, "kind": "water"})
	game.close_modal()
	tick_until(func() -> bool: return not _has_shortage("water"), 12)
	await settle_coach()
	check(step_id() == "research", "step: start research")
	game.act("build", {"site": 0, "kind": "lab"})
	# An event investigation may hold the scientists for a while; the refusal says so.
	tick_until(func() -> bool: return _assign_scientists() == "", 40)
	check(_assign_scientists() == "", "scientists assigned")
	await settle_coach()
	check(step_id() == "stage", "step: finish stage one")
	tick_until(func() -> bool: return int(game.sim.state.contract.stage) >= 2)
	await settle_coach()
	check(step_id() == "expedition", "step: expedition")
	check(game.selected == 1, "the fertile site is selected")
	tick_until(func() -> bool: return game.act("settle", {"site": 1}) == "", 60)
	await settle_coach()
	check(step_id() == "road", "step: compare roads")
	check(not game.sim.settlement(1).is_empty(), "the expedition has left")
	tick_until(func() -> bool: return int(game.sim.settlement(1).get("arrival", 0)) <= 0, 30)
	var road: String = game.act("connect", {"a": 0, "b": 1, "variant": "valley"})
	check(road == "", "a road is built: " + road)
	await settle_coach()
	check(step_id() == "farm", "step: feed the colony")
	tick_until(func() -> bool: return game.act("build", {"site": 1, "kind": "farm"}) == "", 60)
	tick_until(func() -> bool: return Tutorial._running(game.sim.state, "farm"), 30)
	await settle_coach()
	check(not game.coach.active(), "the tutorial ends with a running farm")
	check(not game.coach.visible, "and the panel goes away")
	check(Coach.completed(), "completion is remembered")
	check(game.sim.audit().is_empty(), "the tutorial game passes the audit")
	check(int(game.sim.state.day) < MAX_DAYS, "in %d game days" % int(game.sim.state.day))


func _assign_scientists() -> String:
	return game.act("research_allocate", {"tech": "survey", "staff": 4})


func _has_shortage(key: String) -> bool:
	for s: Dictionary in game.sim.state.settlements:
		for entry: Dictionary in s.shortages:
			if str(entry.key) == key:
				return true
	return false


func _skip_and_replay() -> void:
	game.start_tutorial()
	await process_frame
	check(game.coach.active(), "the tutorial can be replayed")
	check(step_id() == "look", "from the first step")
	game.coach.note_camera()
	await settle_coach()
	game.coach.back()
	check(step_id() == "look", "back returns to the step before")
	check(game.coach.reviewing, "and stays there to be read")
	await settle_coach()
	check(step_id() == "look", "without jumping forward by itself")
	game.coach.forward()
	check(step_id() == "cards", "next moves on again")
	game.coach.skip()
	check(not game.coach.active() and not game.coach.visible, "the tutorial can be skipped")
	check(not game.menu_open, "skipping leaves the game running")
	game.sim.act("settle", {"site": 0})
	game.sim.tick()
	check(game.sim.audit().is_empty(), "a skipped tutorial's game plays on")


func _tips_show_once() -> void:
	game.tutorial_on = false
	game.seed_edit.text = "42"
	game.start_game()
	game.close_modal()
	await process_frame
	check(not game.coach.active(), "no tutorial when the toggle is off")
	var config := ConfigFile.new()
	config.load(SETTINGS)
	if config.has_section("tips"):
		config.erase_section("tips")
	config.save(SETTINGS)
	game.coach.set_tips(true)
	game.sim.act("settle", {"site": 0})
	game.sim.state.events_v2.seen.append("seed_crate")
	game.coach.on_day()
	check(game.coach.visible and not game.coach.tip.is_empty(), "the first event brings a tip")
	var shown: String = str(game.coach.tip.id)
	game.coach.forward()
	check(not game.coach.visible, "it can be dismissed")
	game.coach.on_day()
	check(game.coach.tip.is_empty() or str(game.coach.tip.id) != shown, "and does not come back")
	game.coach.tip = {}
	game.coach.visible = false
	game.coach.set_tips(false)
	game.sim.state.company.stage = "warning"
	game.coach.on_day()
	check(game.coach.tip.is_empty(), "tips can be switched off")
	game.sim.state.company.stage = "normal"
	game.coach.set_tips(true)


func _pages() -> void:
	game.tutorial_on = false
	game.seed_edit.text = "260129"
	game.start_game()
	game.close_modal()
	await process_frame
	game.selected = 1
	game.refresh_sidebar()
	var names: PackedStringArray = _labels(game.sidebar)
	check(_contains(names, "轨道估算"), "the site card says how good its figures are")
	check(_contains(names, "建设费 ×"), "and what building here costs")
	check(game.ui.find_child("SettleButton", true, false) != null, "and offers to settle")
	game.selected = 0
	game.act("settle", {"site": 0})
	game.refresh_sidebar()
	game.selected = 1
	game.refresh_sidebar()
	names = _labels(game.sidebar)
	check(
		_contains(names, "天 · ¥"), "the card shows road days and cost from the nearest settlement"
	)
	game.selected = 0
	game.refresh_sidebar()
	game.open_page("build")
	await process_frame
	for kind: String in game.sim.config.buildings:
		check(game.ui.find_child("Build_" + kind, true, false) != null, "the catalogue has " + kind)
	names = _labels(game.modal_box)
	check(_contains(names, "回本"), "the dialog shows payback")
	check(_contains(names, "空闲工人"), "and free workers")
	var plots: OptionButton = game.modal_box.find_child("Plot_mine_ore", true, false)
	check(plots != null and plots.item_count > 1, "a mine offers a choice of plots")
	var before: int = int(game.sim.plot_choices(0, "mine_ore")[1].index)
	plots.select(1)
	plots.item_selected.emit(1)
	await process_frame
	check(int(game.build_plots.mine_ore) == before, "the choice is kept")
	game.act("build", {"site": 0, "kind": "mine_ore", "plot": before})
	check(int(game.sim.settlement(0).buildings.back().plot) == before, "and the mine goes there")
	game.ui.find_child("Cat_research", true, false).pressed.emit()
	await process_frame
	check(game.build_category == "research", "a category can be chosen")
	check(game.ui.find_child("Build_lab", true, false) != null, "its buildings show")
	game.build_category = "all"
	game.close_modal()
	game.refresh_sidebar()
	check(
		game.sidebar.find_child("Group_power", true, false) != null, "buildings are grouped by kind"
	)
	for _i: int in range(40):
		game.sim.tick()
	game.refresh_sidebar()
	var toggle: Button = game.sidebar.find_child("Group_mine_ore", true, false)
	toggle.pressed.emit()
	await process_frame
	check(_contains(_labels(game.sidebar), "轻型铁矿场"), "a group opens to its buildings")
	game.open_page("economy")
	await process_frame
	names = _labels(game.modal_box)
	check(_contains(names, "近 30 日收入"), "the economy page lists income by category")
	check(_contains(names, "近 30 日支出"), "and expenses")
	check(_contains(names, "物资流向"), "and goods flows")
	check(_contains(names, "近 7 日平均净额"), "and the runway")
	var chart: Control = game.modal_box.find_child("CashChart", true, false)
	check(chart != null and chart.series.size() == 2, "and a chart")
	check(chart.series[0].values.size() >= 40, "with the days so far")
	game.close_modal()
	game.open_page("population")
	await process_frame
	check(
		_contains(_labels(game.modal_box), "近 30 日迁入"), "population shows arrivals and departures"
	)
	game.close_modal()
	game.open_page("guide")
	await process_frame
	check(not _contains(_labels(game.modal_box), "铁岬"), "the guide names no fixed places")
	game.close_modal()
	check(game.ui.find_child("Speed_10", true, false) != null, "a very fast speed button exists")


func _menu() -> void:
	check(game.sim.save_game(game.SAVE_MANUAL) == "", "a save for the menu to describe")
	game.show_menu()
	await process_frame
	var button: Button = game.modal_box.find_child("ContinueGame", true, false)
	check(button != null, "the menu offers to continue")
	check(
		button.text.contains("星球") and button.text.contains("第"),
		"with planet and day: " + button.text
	)
	check(game.modal_box.find_child("TutorialToggle", true, false) != null, "and a tutorial toggle")
	game.close_modal()


## A player coming from 1.6 finds their game. Only inside an isolated APPDATA: the real v16 folder
## is never written.
func _upgrade_from_old_version() -> void:
	var appdata: String = OS.get_environment("APPDATA")
	if not appdata.contains("evidence"):
		print("SKIP upgrade check: APPDATA is not isolated")
		return
	for path: String in [game.SAVE_MANUAL, game.SAVE_AUTO]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(game._latest_save() == "", "no save at all to continue")
	var old_path: String = game.old_save_path(game.OLD_SAVE_MANUAL)
	DirAccess.make_dir_recursive_absolute(old_path.get_base_dir())
	var fixture: FileAccess = FileAccess.open(
		"res://data/v16/acceptance_governor.json", FileAccess.READ
	)
	var text: String = fixture.get_as_text()
	fixture.close()
	var copy: FileAccess = FileAccess.open(old_path, FileAccess.WRITE)
	copy.store_string(text)
	copy.close()
	check(game._latest_save() == old_path, "a 1.6 save is offered when there is nothing newer")
	game.show_menu()
	await process_frame
	var button: Button = game.modal_box.find_child("ContinueGame", true, false)
	check(button != null and not button.disabled, "the menu can continue it")
	button.pressed.emit()
	await process_frame
	check(not game.menu_open, "and continuing leaves the menu")
	check(int(game.sim.state.schema) == 3, "the old save is migrated")
	var after: FileAccess = FileAccess.open(old_path, FileAccess.READ)
	check(after.get_as_text() == text, "and its file stays as it was")
	after.close()
	game.open_page("save")
	await process_frame
	var found: bool = false
	for item: Button in game.modal_box.find_children("*", "Button", true, false):
		found = found or (item.text.contains("1.6 手动档") and not item.disabled)
	check(found, "the settings page also offers it")
	game.close_modal()
	DirAccess.remove_absolute(old_path)


func _stats_rollups() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(260129, "capital")
	sim.state.events_v2.next_draw = 99999
	sim.act("settle", {"site": 0})
	sim.act("build", {"site": 0, "kind": "mine_ore"})
	for _i: int in range(120):
		sim.tick()
	var stats: Dictionary = sim.state.stats
	check(stats.days.size() == 90, "ninety days of money are kept")
	check(stats.goods_days.size() == 30, "thirty days of goods")
	var totals: Dictionary = sim.stats_window(30)
	check(int(totals.days) == 30, "the window covers thirty days")
	check(float(totals.expense.get("wages.public", 0.0)) > 0.0, "wages show as an expense")
	check(float(totals.goods.ore[Stats.PRODUCED]) > 0.0, "ore shows as produced")
	check(float(totals.goods.ore[Stats.EXPORTED]) > 0.0, "and exported")
	var income: float = 0.0
	for row: Dictionary in stats.days.slice(-30):
		for key: String in row.income:
			income += float(row.income[key])
	var history: float = 0.0
	for row: Dictionary in sim.state.operating_history.slice(-30):
		history += float(row.income)
	check(is_equal_approx(income, history), "rollups agree with the daily income")
	check(sim.save_game("user://stats_test.save") == "", "rollups save")
	var other: RefCounted = Sim.new()
	check(other.load_game("user://stats_test.save") == "", "and load")
	check(var_to_bytes(other.state) == var_to_bytes(sim.state), "byte-identical")
	var header: Dictionary = SaveIo.read_header("user://stats_test.save")
	check(int(header.get("day", 0)) == 120, "the header has the day")


func _labels(parent: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in parent.find_children("*", "Label", true, false):
		texts.append(label.text)
	return texts


func _contains(texts: PackedStringArray, part: String) -> bool:
	for text: String in texts:
		if text.contains(part):
			return true
	return false
