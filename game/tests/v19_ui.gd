extends SceneTree
## The 1.9 interface pass: one style system with a neutral foundation and two module variants.
## Checks that styles are cached, that each page and the modal frame take their page's variant and
## give it back, that switching pages leaves no stale skin, that pages reuse their controls, that
## the construction and research pages keep the names tests and the tutorial use and still order
## through the same simulation actions, and that the frame fits the window at every text size.

const Watchdog = preload("res://tests/support/watchdog.gd")
const D = preload("res://ui/design.gd")
const TEXT_SIZES: Array[int] = [16, 18, 20]

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
	_styles()
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.close_modal()
	scene.sim.act("settle", {"region": 0})
	scene.selected = 0
	scene.refresh_sidebar()
	await _build_page(scene)
	await _research_page(scene)
	await _switching(scene)
	await _pause(scene)
	await _fit(scene)
	await _coach(scene)
	_column(scene)
	scene.close_modal()
	root.remove_child(scene)
	scene.free()
	print("V19_UI_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _styles() -> void:
	var first: StyleBox = D.style("card", D.RESEARCH)
	var again: StyleBox = D.style("card", D.RESEARCH)
	check(first == again, "styles are built once")
	check(
		D.style("card", D.RESEARCH) != D.style("card", D.INDUSTRY), "each variant has its own card"
	)
	var research: StyleBoxFlat = D.style("card", D.RESEARCH) as StyleBoxFlat
	var industry: StyleBoxFlat = D.style("card", D.INDUSTRY) as StyleBoxFlat
	check(
		research.bg_color.s > industry.bg_color.s,
		"the research surfaces are more saturated than the industrial ones"
	)
	var accent_r: Color = D.tone("accent", D.RESEARCH)
	var accent_i: Color = D.tone("accent", D.INDUSTRY)
	check(accent_r.s > accent_i.s * 2.0, "research accents are vivid, industrial ones subdued")
	check(D.tone("text", D.NEUTRAL) == D.INK, "the neutral variant keeps the original ink")
	check(D.variant() == D.NEUTRAL, "nothing is drawn in a module variant by default")
	var theme: Theme = D.theme()
	var focus: StyleBoxFlat = theme.get_stylebox("focus", "Button") as StyleBoxFlat
	check(
		focus != null and not focus.draw_center and focus.border_width_top >= 2,
		"keyboard focus draws a visible ring"
	)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		check(theme.has_stylebox(state, "Button"), "the theme styles a button's %s state" % state)


func _skins_under(node: Node) -> Array[String]:
	var found: Array[String] = []
	for button: Node in node.find_children("*", "Button", true, false):
		if button.has_meta(D.META_SKIN):
			found.append(str(button.get_meta(D.META_SKIN)))
	return found


func _all_in(skins: Array[String], variant: String) -> bool:
	for skin: String in skins:
		if not skin.begins_with(variant + "|"):
			return false
	return true


func _build_page(scene: Node) -> void:
	scene.open_page("build")
	await process_frame
	var box: Control = scene.modal_box
	check(
		scene.modal_panel.get_theme_stylebox("panel") == D.style("modal", D.INDUSTRY),
		"the construction page's frame is industrial"
	)
	var skins: Array[String] = _skins_under(box)
	check(not skins.is_empty() and _all_in(skins, D.INDUSTRY), "its controls are industrial")
	check(D.variant() == D.NEUTRAL, "the variant is given back after the page is drawn")
	for name: String in ["Cat_all", "Cat_research", "BuildCatalogue", "BuildSelected"]:
		check(box.find_child(name, true, false) != null, "the construction page has " + name)
	check(box.find_child("Pick_mine_ore", true, false) != null, "a catalogue row picks a kind")
	check(box.find_child("Build_mine_ore", true, false) != null, "and orders it directly")
	var plots: OptionButton = box.find_child("Plot_mine_ore", true, false)
	check(plots != null and plots.item_count > 1, "the chosen mine offers its plots")
	var order: Button = box.find_child("BuildSelected", true, false)
	var forecast: Dictionary = scene.sim.build_forecast(0, "mine_ore", -1)
	check(
		order.disabled == (str(forecast.disabled_reason) != ""),
		"the main order is enabled exactly when the rules allow it"
	)
	var kept: int = box.find_child("Build_mine_ore", true, false).get_instance_id()
	scene.populate_current_page()
	await process_frame
	check(
		box.find_child("Build_mine_ore", true, false).get_instance_id() == kept,
		"a refresh reuses the page's controls"
	)
	var pick: Button = box.find_child("Pick_habitat", true, false)
	pick.pressed.emit()
	await process_frame
	check(scene.build_selected == "habitat", "a row selects its facility")
	order = box.find_child("BuildSelected", true, false)
	var name: String = str(scene.sim.config.buildings.habitat.name)
	check(order.text.contains(name), "the main order names the selected facility")
	var row: PanelContainer = pick.get_parent().get_parent().get_parent() as PanelContainer
	check(
		row != null and row.get_theme_stylebox("panel") == D.style("item_on", D.INDUSTRY),
		"the selected row is marked"
	)
	var before: int = scene.sim.settlement(0).buildings.size()
	var refusal: String = str(scene.sim.build_forecast(0, "habitat", -1).disabled_reason)
	check(refusal == "", "a home can be built in the new colony")
	order.pressed.emit()
	await process_frame
	var after: Array = scene.sim.settlement(0).buildings
	check(
		after.size() == before + 1 and str(after.back().kind) == "habitat",
		"the main order builds the selected facility through the build action"
	)
	box.find_child("Cat_research", true, false).pressed.emit()
	await process_frame
	check(box.find_child("Build_lab", true, false) != null, "a category filter shows its kinds")
	check(
		box.find_child("Cat_research", true, false).get_meta(D.META_SKIN) == "industry|chip_on",
		"and marks itself chosen"
	)
	check(scene.build_selected == "habitat", "the selection survives a filter it is not in")
	box.find_child("Cat_all", true, false).pressed.emit()
	await process_frame


func _research_page(scene: Node) -> void:
	scene.open_page("research")
	await process_frame
	var box: Control = scene.modal_box
	check(
		scene.modal_panel.get_theme_stylebox("panel") == D.style("modal", D.RESEARCH),
		"the research page's frame is the research variant"
	)
	var skins: Array[String] = _skins_under(box)
	check(not skins.is_empty() and _all_in(skins, D.RESEARCH), "its controls are research ones")
	var dealt: int = 0
	for hand: Array in scene.sim.state.research.offers.values():
		dealt += hand.size()
	check(
		box.find_children("Card_*", "Button", true, false).size() == dealt,
		"every dealt topic can be picked"
	)
	var nav: Button = scene.nav_buttons.research
	check(nav.get_meta(D.META_SKIN) == "neutral|row_on", "the navigation marks the open page")
	check(
		scene.nav_buttons.economy.get_meta(D.META_SKIN) == "neutral|row", "and only the open page"
	)
	var team: SpinBox = box.find_child("Staff_industry", true, false)
	team.value = 4
	box.find_child("Card_survey", true, false).pressed.emit()
	await process_frame
	check(
		int(scene.sim.state.research.projects.survey.staff) == 4,
		"picking a topic sends the chosen team through research_allocate"
	)
	check(box.find_child("Card_survey", true, false) == null, "a running topic is not offered")
	var running: int = 0
	for panel: Node in box.find_children("*", "PanelContainer", true, false):
		if panel.get_meta(D.META_SKIN, "") == "research|card_on":
			running += 1
	check(running == 1, "the running topic's card is marked active")


func _switching(scene: Node) -> void:
	scene.open_page("economy")
	await process_frame
	check(
		scene.modal_panel.get_theme_stylebox("panel") == D.style("modal", D.NEUTRAL),
		"another page's frame is neutral again"
	)
	check(
		scene.modal_close.get_meta(D.META_SKIN) == "neutral|plain",
		"the shared close button is reset"
	)
	var leaked: bool = false
	for skin: String in _skins_under(scene.modal_box):
		if skin.begins_with(D.RESEARCH) or skin.begins_with(D.INDUSTRY):
			leaked = true
	check(not leaked, "no module skin reaches a neutral page")
	scene.open_page("build")
	await process_frame
	check(
		scene.modal_close.get_meta(D.META_SKIN) == "industry|plain",
		"returning to construction restyles the shared frame"
	)
	scene.open_page("research")
	await process_frame
	check(
		scene.modal_close.get_meta(D.META_SKIN) == "research|plain",
		"and research restyles it again"
	)
	var research_box: Control = scene.modal_box
	scene.open_page("build")
	await process_frame
	check(not research_box.get_parent().visible, "only the open page is shown")


func _pause(scene: Node) -> void:
	scene.close_modal()
	scene.paused = false
	scene.open_page("build")
	await process_frame
	check(scene.paused, "opening the construction page pauses")
	scene.close_modal()
	check(not scene.paused, "closing it resumes")
	scene.paused = true


func _fit(scene: Node) -> void:
	for text_px: int in TEXT_SIZES:
		scene.get_window().content_scale_factor = text_px / 18.0
		for page: String in ["build", "research"]:
			scene.open_page(page)
			await process_frame
			await process_frame
			var room: Rect2 = scene.ui.get_viewport_rect()
			var panel: Rect2 = scene.modal_panel.get_global_rect()
			check(
				room.grow(1.0).encloses(panel),
				"%s fits the window at %d px text (%s in %s)" % [page, text_px, panel, room]
			)
			var close: Control = scene.modal_close
			check(
				room.encloses(close.get_global_rect()),
				"%s can be closed at %d px text" % [page, text_px]
			)
	scene.get_window().content_scale_factor = 1.0


## The tutorial's outline stays above a dialog opened while a step points into it.
func _coach(scene: Node) -> void:
	scene.close_modal()
	scene.coach.visible = true
	scene.open_page("build")
	await process_frame
	var outline: Control = scene.coach.outline
	check(
		outline.get_index() > scene.modal_root.get_index(),
		"the tutorial outline is drawn above the open dialog"
	)
	scene.coach.visible = false
	scene.close_modal()


func _column(scene: Node) -> void:
	scene.close_modal()
	scene.navigate("flat")
	check(
		scene.nav_buttons.flat.get_meta(D.META_SKIN) == "neutral|row_on", "the map view is marked"
	)
	scene.navigate("planet")
	check(scene.nav_buttons.planet.get_meta(D.META_SKIN) == "neutral|row_on", "and follows it")
	scene.column_open = true
	scene.refresh_sidebar()
	check(
		scene.column_panel.get_theme_stylebox("panel") == D.style("panel", D.INDUSTRY),
		"the facility column is industrial"
	)
	check(D.variant() == D.NEUTRAL, "and gives the variant back")
