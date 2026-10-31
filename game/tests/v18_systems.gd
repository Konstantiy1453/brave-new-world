extends SceneTree
## 1.8's systems as a player meets them: pollution that stays out of the company's way, the resource
## table, the distrust gauge, the building column, settlement kinds on the naming page, the new job
## names everywhere, and the saves of the versions before it.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Keys = preload("res://simulation/keys.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Rules = preload("res://simulation/rules.gd")
const Labels = preload("res://ui/labels.gd")
const Stats = preload("res://simulation/stats.gd")

const SEED: int = 260129
const OLD_SAVES: Array[String] = [
	"res://data/v17/acceptance_geo20.save",
	"res://data/v17/acceptance_geo21.save",
]
const OLD_NAMES: Array[String] = ["工人", "研究员"]
## This file holds the old names on purpose: it is what turns them into keys in old saves.
const NAME_SCAN_SKIP: Array[String] = ["save_migration.gd"]
const NAME_SCAN_ROOTS: Array[String] = [
	"res://simulation",
	"res://ui",
	"res://world",
	"res://data/v17",
]
const TABLE_KEYS: Array[String] = ["ore", "copper", "crystal", "food", "power", "money", "water"]
const EARLY_LOAD: float = 2000.0
const LATE_LOAD: float = 60000.0
const MAX_DISTRUST_RISE: float = 0.8

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


func make(size: int = 1) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", size, "normal")
	sim.act("settle", {"site": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


func run() -> void:
	_pollution_curve()
	_pollution_is_not_distrust()
	_pollution_outbreaks()
	_distrust_rates()
	_names_are_gone()
	_old_saves()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial_on = false
	game.seed_edit.text = str(SEED)
	game.start_game()
	game.close_modal()
	await process_frame
	game.select_region(0)
	game.act("settle", {"site": 0})
	await process_frame
	_resource_table()
	await _gauge()
	_column()
	await _kind_choice()
	await _old_save_fallback()
	print("V18_SYSTEMS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


## Tiny for years, then all at once: a(e^x - 1), and a big planet takes more before it shows.
func _pollution_curve() -> void:
	var sim: RefCounted = make()
	var state: Dictionary = sim.state.pollution
	check(sim.Pollution.penalty(sim) == 0.0, "a clean planet costs nothing")
	state.load = EARLY_LOAD
	var early: float = sim.Pollution.penalty(sim)
	check(early > 0.0 and early < 0.02, "the first years' pollution barely shows: %.4f" % early)
	state.load = LATE_LOAD / 2.0
	var middle: float = sim.Pollution.penalty(sim)
	state.load = LATE_LOAD
	var late: float = sim.Pollution.penalty(sim)
	check(late > 0.2, "a late run's pollution hurts badly: %.3f" % late)
	check(late - middle > 2.0 * (middle - early), "the curve bends upwards")
	state.load = LATE_LOAD * 100.0
	check(
		is_equal_approx(sim.Pollution.penalty(sim), float(sim.progression.pollution.cap)),
		"and stops at its cap"
	)
	var small: RefCounted = make(0)
	var large: RefCounted = make(2)
	small.state.pollution.load = LATE_LOAD / 2.0
	large.state.pollution.load = LATE_LOAD / 2.0
	check(
		large.Pollution.penalty(large) < small.Pollution.penalty(small),
		"the same pile does less on a larger planet"
	)
	check(
		large.Pollution.absorption(large) > small.Pollution.absorption(small),
		"which also absorbs more each day"
	)
	sim.state.pollution.load = 3000.0
	sim._transfer("external", "public", 20000.0, "capital.initial", false)
	var cash: float = float(sim.state.cash)
	check(sim.act("company", {"operation": "cleanup"}) == "", "cleanup is an action")
	check(float(sim.state.pollution.load) < 3000.0, "it takes the load down")
	check(float(sim.state.cash) < cash, "and costs money")
	check(sim.audit().is_empty(), "pollution passes the audit")


## The company's distrust does not move because the air is dirty.
func _pollution_is_not_distrust() -> void:
	var clean: RefCounted = make()
	var dirty: RefCounted = make()
	dirty.state.pollution.load = LATE_LOAD
	for _day: int in range(30):
		clean.tick()
		dirty.tick()
	check(
		(
			not dirty.state.company.sources.has("pollution")
			and not dirty.state.company.sources.has("environment")
		),
		"pollution is no source of distrust"
	)
	for source: Variant in dirty.state.company.sources.values():
		check(not str(source.get("reason", "")).contains("污染"), "no distrust reason mentions it")
	var view: Dictionary = dirty.pollution_view()
	check(int(view.stage) >= 2, "the planet shows the damage all the same")
	check(float(dirty.Pollution.factor(dirty)) < 1.0, "and output falls")


## Crossing a stage opens a scene, in every run: the deck never leaves these out.
func _pollution_outbreaks() -> void:
	var defs: Dictionary = Rules.read("events").definitions
	for id: String in ["smog_season", "acid_rain", "dead_bay"]:
		check(defs.has(id), id + " is defined")
		check(float(defs[id].get("chance", 0.0)) >= 1.0, id + " is in every run's deck")
		check(bool(defs[id].conditions.get("trigger_only", false)), id + " never comes by chance")
	var sim: RefCounted = make()
	sim.state.pollution.load = 15000.0
	sim.Pollution.daily(sim)
	var opened: Array = []
	for inst: Dictionary in sim.state.events_v2.instances:
		opened.append(str(inst.definition_id))
	check(opened.has("smog_season"), "the first stage brings the smog: " + str(opened))
	check(int(sim.state.pollution.stage) >= 1, "and the stage is remembered")


## Distrust climbs slowly enough to read, and the gauge shows the true change of the day.
func _distrust_rates() -> void:
	var sim: RefCounted = make()
	var rules: Dictionary = sim.progression.company
	check(float(rules.starving_cap) <= MAX_DISTRUST_RISE, "starving alone stays under the limit")
	check(float(rules.debt_cap) <= MAX_DISTRUST_RISE, "debt alone stays under the limit")
	check(
		float(sim.contract_rules.overdue_distrust_per_day) <= MAX_DISTRUST_RISE,
		"a missed deadline alone stays under the limit"
	)
	sim.tick()
	check(
		float(sim.state.company.delta) == 0.0, "at zero distrust the change is zero, not negative"
	)
	sim.state.company.distrust = 30.0
	var before: float = 30.0
	sim.tick()
	check(
		is_equal_approx(float(sim.state.company.delta), float(sim.state.company.distrust) - before),
		"the day's change is what really changed"
	)
	check(float(sim.state.company.delta) < 0.0, "and with no trouble it falls")


func _scan(folder: String, found: Array) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	for name: String in dir.get_files():
		if not (name.ends_with(".gd") or name.ends_with(".json")) or name in NAME_SCAN_SKIP:
			continue
		var text: String = FileAccess.get_file_as_string(folder.path_join(name))
		for old: String in OLD_NAMES:
			if text.contains(old):
				found.append("%s: %s" % [name, old])
	for sub: String in dir.get_directories():
		_scan(folder.path_join(sub), found)


## Purely a naming change, but an everywhere one.
func _names_are_gone() -> void:
	var found: Array = []
	for folder: String in NAME_SCAN_ROOTS:
		_scan(folder, found)
	check(found.is_empty(), "no player text still says the old job names: " + str(found))


func _old_saves() -> void:
	for path: String in OLD_SAVES:
		var sim: RefCounted = Sim.new()
		var error: String = sim.load_game(path)
		check(error == "", path.get_file() + " loads: " + error)
		if error != "":
			continue
		check(int(sim.state.schema) == SaveIo.SCHEMA, "and is brought up to date")
		check(str(sim.geo.version) != sim.WorldGen.VERSION, "on the world it was started on")
		check(not sim.state.research.offers.is_empty(), "with research cards dealt")
		check(sim.state.events_v2.has("off"), "and an event deck")
		check(sim.state.has("pollution"), "and a planet that can be polluted")
		check(sim.audit().is_empty(), "with clean books")
		var clean: bool = true
		for _day: int in range(30):
			sim.tick()
			clean = clean and sim.audit().is_empty()
		check(clean, "and it plays on")


func _digits(text: String) -> float:
	return float(text.replace("+", "").replace("万", ""))


func _resource_table() -> void:
	for key: String in TABLE_KEYS:
		check(game.top_cells.has(key), "the table has " + key)
	game.refresh()
	var cells: Dictionary = game.top_cells
	var s: Dictionary = game.sim.settlement(0)
	check(
		cells.ore.value.text == Labels.compact(float(s.stock.ore)), "iron shows the colony's total"
	)
	check(
		cells.food.value.text == Labels.compact(float(s.stock.food)),
		"food shows the colony's total"
	)
	check(
		cells.money.value.text == Labels.compact(float(game.sim.state.cash)),
		"money shows what is in the account"
	)
	check(
		cells.power.value.text == Labels.compact(float(s.power_supply)),
		"power, which cannot be stored, shows the supply"
	)
	check(
		cells.power.delta.text.ends_with(Labels.compact(float(s.power_supply - s.power_demand))),
		"and the surplus"
	)
	for _day: int in range(40):
		game.sim.tick()
	game.refresh()
	s = game.sim.settlement(0)
	var window: Dictionary = game.sim.stats_window(30)
	var flows: Array = window.goods.get("food", [0.0, 0.0, 0.0, 0.0, 0.0])
	var change: float = (
		float(flows[Stats.PRODUCED])
		+ float(flows[Stats.IMPORTED])
		- float(flows[Stats.CONSUMED])
		- float(flows[Stats.EXPORTED])
	)
	check(
		is_equal_approx(_digits(cells.food.delta.text), float(roundi(change))),
		"food's monthly change comes from the month's flows"
	)
	for key: String in TABLE_KEYS:
		check(cells[key].cell.tooltip_text != "", key + " explains itself")


func _gauge() -> void:
	var gauge: Control = game.gauge
	check(gauge != null and gauge.visible, "the distrust gauge stands beside the map")
	game.sim.state.company.distrust = 35.0
	game.sim.state.company.delta = 0.42
	game.refresh()
	check(gauge.value_label.text == "35", "it shows the level")
	check(gauge.delta_label.text == "+0.42 /日", "and the change of the day")
	check(gauge.tooltip_text.contains("点击"), "and says what a click does")
	game.sim.state.company.distrust = 0.0
	game.sim.state.company.delta = 0.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	gauge._gui_input(press)
	await process_frame
	check(game.current_page == "company", "a click opens the company page")
	game.close_modal()


func _column() -> void:
	var sim: RefCounted = game.sim
	sim._transfer("external", "public", 8000.0, "capital.initial", false)
	sim._produce(sim.settlement(0), "materials", 60.0, "test")
	sim._produce(sim.settlement(0), "parts", 30.0, "test")
	check(sim.act("build", {"site": 0, "kind": "habitat"}) == "", "something under way")
	game.refresh_sidebar()
	var panel: Control = game.column_panel
	check(panel.visible, "the settlement's buildings have a column of their own")
	var texts: PackedStringArray = []
	for label: Label in game.column_box.find_children("*", "Label", true, false):
		texts.append(label.text)
	var joined: String = "\n".join(texts)
	check(joined.contains("在建"), "it starts with what is being built")
	check(joined.contains("模块住区"), "by name")
	check(joined.contains("完工") and joined.contains("年"), "with the date it will be done")
	check(
		not game.column_box.find_children("*", "ProgressBar", true, false).is_empty(),
		"and a progress bar"
	)
	game.set_column_open(false)
	check(not panel.visible and game.column_tab.visible, "it folds away")
	game.set_column_open(true)
	check(panel.visible and not game.column_tab.visible, "and comes back")


func _kind_choice() -> void:
	var sim: RefCounted = game.sim
	sim.state.contract.licences.append("expedition")
	sim._transfer("external", "public", 20000.0, "capital.initial", false)
	game.select_region(1)
	game.ask_site_name(false)
	await process_frame
	var town: Button = game.modal_box.find_child("SiteKind_residential", true, false)
	var camp: Button = game.modal_box.find_child("SiteKind_frontier", true, false)
	check(town != null and camp != null, "an expedition chooses between a town and a frontier post")
	check(game.naming_kind == Keys.SITE_FRONTIER, "a frontier post unless told otherwise")
	town.pressed.emit()
	await process_frame
	check(game.naming_kind == Keys.SITE_RESIDENTIAL, "the choice can be changed")
	camp = game.modal_box.find_child("SiteKind_frontier", true, false)
	camp.pressed.emit()
	await process_frame
	game.confirm_site_name()
	await process_frame
	check(str(sim.settlement(1).kind) == Keys.SITE_FRONTIER, "and the post is what was chosen")


## A player coming from 1.7 finds their game. Only inside an isolated APPDATA.
func _old_save_fallback() -> void:
	var appdata: String = OS.get_environment("APPDATA")
	if not appdata.contains("evidence"):
		print("SKIP fallback check: APPDATA is not isolated")
		return
	for path: String in [game.SAVE_MANUAL, game.SAVE_AUTO]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old_path: String = game.old_save_path(game.V17_SAVE_MANUAL)
	DirAccess.make_dir_recursive_absolute(old_path.get_base_dir())
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(OLD_SAVES[1])
	var copy: FileAccess = FileAccess.open(old_path, FileAccess.WRITE)
	copy.store_buffer(bytes)
	copy.close()
	check(game._latest_save() == old_path, "a 1.7 save is offered when there is nothing newer")
	game.show_menu()
	await process_frame
	var button: Button = game.modal_box.find_child("ContinueGame", true, false)
	check(button != null and not button.disabled, "the menu can continue it")
	button.pressed.emit()
	await process_frame
	check(not game.menu_open, "and continuing leaves the menu")
	check(int(game.sim.state.schema) == SaveIo.SCHEMA, "the old save is brought up to date")
	game.close_modal()
	var after: PackedByteArray = FileAccess.get_file_as_bytes(old_path)
	check(after == bytes, "and its file stays as it was")
	DirAccess.remove_absolute(old_path)
