extends PanelContainer
## The tutorial's coach panel and the outline around its target control. Never modal: the player
## can do anything else while it is showing. Also shows the one-time tips afterwards.
## Progress lives in user://settings.cfg, not in the save.

const D = preload("res://ui/design.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const SETTINGS: String = "user://settings.cfg"
const CHECK_SECONDS: float = 0.2
const PANEL_WIDTH: float = 430.0
const OUTLINE_MARGIN: float = 4.0
const BOTTOM_MARGIN: float = 104.0
const LEFT_EDGE: float = 195.0
const RIGHT_EDGE: float = 385.0

var game: Node
var index: int = -1
var reviewing: bool = false
var context: Dictionary = Tutorial.new_context()
var tip: Dictionary = {}
var tips_enabled: bool = true
var title_label: Label
var text_label: Label
var progress_label: Label
var back_button: Button
var next_button: Button
var end_button: Button
var outline: Panel
var since_check: float = 0.0
var pulse: float = 0.0
var scrolled_for: Control = null


func setup(owner_game: Node) -> void:
	game = owner_game
	name = "TutorialCoach"
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -BOTTOM_MARGIN
	offset_bottom = -BOTTOM_MARGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(false)
	add_theme_stylebox_override("panel", D.box(Color("143042"), D.GOLD, 14))
	var column := VBoxContainer.new()
	add_child(column)
	progress_label = D.label(column, "", 14, D.TEAL, false)
	title_label = D.label(column, "", 21, D.GOLD)
	text_label = D.label(column, "", 17)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	back_button = D.button(buttons, "上一步", back, "", "CoachBack")
	next_button = D.button(buttons, "下一步", forward, "", "CoachNext")
	end_button = D.button(buttons, "结束引导", skip, "可以在保存与设置里重新开始", "CoachEnd")
	for button: Button in [back_button, next_button, end_button]:
		D.font_size(button, 15)
		button.custom_minimum_size.y = 32
	outline = Panel.new()
	outline.name = "TutorialOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.border_color = D.GOLD
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(6)
	outline.add_theme_stylebox_override("panel", frame)
	outline.visible = false
	visible = false
	var preferences := ConfigFile.new()
	if preferences.load(SETTINGS) == OK:
		tips_enabled = bool(preferences.get_value("tutorial", "tips", true))


func _ready() -> void:
	get_parent().add_child.call_deferred(outline)


func active() -> bool:
	return index >= 0


func steps() -> Array:
	return Tutorial.data().steps


static func completed() -> bool:
	var preferences := ConfigFile.new()
	if preferences.load(SETTINGS) != OK:
		return false
	return bool(preferences.get_value("tutorial", "done", false))


func start() -> void:
	context = Tutorial.new_context()
	context.home = int(Tutorial.data().start_site)
	index = 0
	reviewing = false
	tip = {}
	_enter()


func stop(finished: bool) -> void:
	index = -1
	reviewing = false
	visible = false
	outline.visible = false
	if finished:
		_remember("tutorial", "done")
		game.tutorial_on = false


func skip() -> void:
	stop(true)


func back() -> void:
	if index > 0:
		index -= 1
		reviewing = true
		_show_step()


func forward() -> void:
	if tip.size() > 0:
		tip = {}
		visible = false
		return
	if not reviewing and not _done():
		return
	_advance()


func _advance() -> void:
	reviewing = false
	index += 1
	if index >= steps().size():
		stop(true)
		game.toast("新手引导完成。接下来的提示会在需要时出现。")
		return
	_enter()


func _enter() -> void:
	var step: Dictionary = steps()[index]
	if step.has("site"):
		var rules: Dictionary = Tutorial.data()
		var site: int = int(rules.start_site if step.site == "start" else rules.partner_site)
		game.selected = site
		game.map.focus_region(site)
		game.refresh_sidebar()
	if str(step.get("enter", "")) == "shortage" and int(context.shortage_day) < 0:
		context.shortage_day = int(game.sim.state.day)
		game.act("tutorial_shortage", {"site": int(context.home)})
		game.selected = int(context.home)
		game.refresh_sidebar()
	_show_step()


func _show_step() -> void:
	var step: Dictionary = steps()[index]
	progress_label.text = "新手引导 · %d / %d" % [index + 1, steps().size()]
	title_label.text = str(step.title)
	text_label.text = str(step.text)
	back_button.visible = index > 0
	end_button.visible = true
	_update_next_button()
	visible = not game.menu_open
	move_to_front()
	if is_instance_valid(outline) and outline.get_parent() != null:
		outline.get_parent().move_child(outline, -1)


## Keeps the panel and its outline above a dialog that has just opened over them.
func keep_on_top() -> void:
	move_to_front()
	if is_instance_valid(outline) and outline.get_parent() != null:
		outline.get_parent().move_child(outline, -1)


func _update_next_button() -> void:
	next_button.text = "下一步"
	next_button.visible = reviewing or _done()


func _done() -> bool:
	if index < 0 or index >= steps().size():
		return false
	return Tutorial.check(game.sim, steps()[index].done, context)


func _process(delta: float) -> void:
	if game == null:
		return
	if active():
		pulse += delta
		_draw_outline()
	since_check += delta
	if since_check < CHECK_SECONDS:
		return
	since_check = 0.0
	if not active():
		return
	visible = not game.menu_open
	if not reviewing and _done():
		_advance()
	elif active():
		_update_next_button()


## The first listed target that is on screen gets the outline.
func _target() -> Control:
	for target_name: Variant in steps()[index].get("target", []):
		var found: Node = game.ui.find_child(str(target_name), true, false)
		if found is Control and found.is_visible_in_tree():
			return found
	return null


func _draw_outline() -> void:
	if not is_instance_valid(outline) or outline.get_parent() == null:
		return
	var target: Control = _target() if not game.menu_open else null
	outline.visible = target != null and _in_view(target)
	if target == null:
		return
	_avoid(target)
	var box: Rect2 = target.get_global_rect().grow(OUTLINE_MARGIN)
	outline.global_position = box.position
	outline.size = box.size
	outline.modulate.a = 0.55 + 0.45 * sin(pulse * 4.0)


## Brings a new target into its scroll area once; after that the player scrolls as they like.
func _in_view(target: Control) -> bool:
	var scroll: ScrollContainer = _scroll_of(target)
	if scroll == null:
		return true
	if scrolled_for != target:
		scrolled_for = target
		scroll.ensure_control_visible(target)
	return scroll.get_global_rect().encloses(target.get_global_rect())


func _scroll_of(target: Control) -> ScrollContainer:
	var node: Node = target.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null


## The panel moves to the other side of the screen when it would cover what it points at.
func _avoid(target: Control) -> void:
	var box: Rect2 = target.get_global_rect()
	if not get_global_rect().intersects(box):
		return
	_place(box.position.x < get_viewport_rect().size.x * 0.5)


func _place(on_right: bool) -> void:
	if on_right:
		anchor_left = 1.0
		anchor_right = 1.0
		offset_left = -RIGHT_EDGE - PANEL_WIDTH
		offset_right = -RIGHT_EDGE
	else:
		anchor_left = 0.0
		anchor_right = 0.0
		offset_left = LEFT_EDGE
		offset_right = LEFT_EDGE + PANEL_WIDTH


func note_camera() -> void:
	context.camera_moved = true


func note_site(site: int) -> void:
	context.sites_viewed[site] = true


func note_page(page: String) -> void:
	context.pages_opened[page] = true


## Called once per simulated day: shows the first tip whose moment has come.
func on_day() -> void:
	if active() or not tips_enabled or not tip.is_empty():
		return
	for row: Dictionary in Tutorial.data().tips:
		if _seen("tips", str(row.id)):
			continue
		if Tutorial.check(game.sim, row.when, context):
			_remember("tips", str(row.id))
			_show_tip(row)
			return


func _show_tip(row: Dictionary) -> void:
	tip = row
	progress_label.text = "提示"
	title_label.text = str(row.title)
	text_label.text = str(row.text)
	back_button.visible = false
	end_button.visible = false
	next_button.visible = true
	next_button.text = "知道了"
	visible = true
	move_to_front()


func set_tips(enabled: bool) -> void:
	tips_enabled = enabled
	var preferences := ConfigFile.new()
	preferences.load(SETTINGS)
	preferences.set_value("tutorial", "tips", enabled)
	preferences.save(SETTINGS)


func _seen(section: String, key: String) -> bool:
	var preferences := ConfigFile.new()
	if preferences.load(SETTINGS) != OK:
		return false
	return bool(preferences.get_value(section, key, false))


func _remember(section: String, key: String) -> void:
	var preferences := ConfigFile.new()
	preferences.load(SETTINGS)
	preferences.set_value(section, key, true)
	preferences.save(SETTINGS)
