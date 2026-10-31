extends Node
const D = preload("res://ui/design.gd")
const Pages = preload("res://ui/pages.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const Career = preload("res://simulation/career.gd")
const ProgressionPages = preload("res://ui/progression_pages.gd")
const Events = preload("res://simulation/events_v2.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Contract = preload("res://simulation/contract.gd")
const TutorialCoach = preload("res://ui/tutorial_coach.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Labels = preload("res://ui/labels.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const MAX_DAYS_PER_FRAME: int = 3
const SAVE_MANUAL: String = "user://manual.save"
const SAVE_AUTO: String = "user://autosave.save"
const OLD_SAVE_MANUAL: String = "/ColonyCharter/v16/manual.json"
const OLD_SAVE_AUTO: String = "/ColonyCharter/v16/autosave.json"
const OLDER_SAVE_MANUAL: String = "/Godot/app_userdata/殖民契约 · COLONY CHARTER/manual.json"
const AUTOSAVE_DAYS: int = 10
const MODAL_HEIGHT: int = 690
const PAGE_HEIGHT: int = 535
var sim = Sim.new()
var map: Node3D
var ui: Control
var sidebar: VBoxContainer
var sidebar_actions: VBoxContainer
var top_stats: Label
var date_label: Label
var mission: Label
var toast_label: Label
var overlay: Control
var modal_box: VBoxContainer
var modal_feedback: Label
var selected: int = 0
var selected_tech: String = ""
var site_filter: int = 0
var announced_event: int = 0
var build_category: String = "all"
var build_plots: Dictionary = {}
var expanded_kinds: Dictionary = {}
var coach: PanelContainer
var tutorial_on: bool = true
var naming_site: int = 0
var naming_again: bool = false
var menu_seed: String = ""
var planet_preview: Label
var local_view: bool = false
var paused: bool = true
var speed: int = 1
var elapsed: float = 0
var menu_open: bool = true
var last_status: String = "planning"
var current_page: String = ""
var advantage: String = "capital"
var seed_edit: LineEdit
var size_option: OptionButton
var accumulator: float = 0
var toast_time: float = 0
var autosave_day: int = 0
var session_seconds: float = 0
var sample_frames: Array = []
var ui_scale: float = 1.0
var map_hint: Label
var difficulty_option: OptionButton
var difficulty: String = "normal"
var detailed_info: bool = true
var panel_pause: bool = true
var resume_on_close: bool = false
var dev_mode: bool = false
var modal_root: Control
var modal_panel: PanelContainer
var modal_title: Label
var modal_close: Button
var modal_pages: VBoxContainer
var modal_footer: Label
var page_boxes: Dictionary = {}
var autosave_task: int = -1
var autosave_snapshot: Dictionary = {}


func _ready():
	Engine.max_fps = 60
	dev_mode = OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")
	sim.new_game(260129, "capital", 1)
	map = Map.new()
	add_child(map)
	map.setup(sim.geo)
	map.region_selected.connect(select_region)
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = D.theme()
	layer.add_child(ui)
	build_shell()
	coach = TutorialCoach.new()
	coach.setup(self)
	ui.add_child(coach)
	tutorial_on = not TutorialCoach.completed()
	if map.has_signal("region_progress"):
		map.region_progress.connect(
			func(busy, progress):
				if busy:
					toast("正在准备地区地形 · %.0f%%；可切回球面取消" % (float(progress) * 100))
				else:
					toast("地区地形已就绪" if float(progress) >= 1.0 else "地区准备已取消")
		)
	var preferences = ConfigFile.new()
	if preferences.load("user://settings.cfg") == OK:
		get_window().content_scale_factor = float(preferences.get_value("display", "scale", 1.0))
		detailed_info = bool(preferences.get_value("display", "details", true))
		panel_pause = bool(preferences.get_value("gameplay", "panel_pause", true))
	show_menu()
	var args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--load="):
			load_path(a.trim_prefix("--load="))
		if a == "--region":
			local_view = true
			map.show_region(selected)
	refresh()
	if dev_mode:
		for a in args:
			# Measures and scripted checks live outside the export; only --dev reaches them.
			if a.begins_with("--dev-script="):
				load(a.trim_prefix("--dev-script=")).run(self)
			if a.begins_with("--qa-v17="):
				load("res://ui/capture_suite_v17.gd").run(self, a.trim_prefix("--qa-v17="))
			if a.begins_with("--qa-v16="):
				load("res://ui/capture_suite_v16.gd").run(self, a.trim_prefix("--qa-v16="))
			if a.begins_with("--qa-capture="):
				load("res://ui/capture_suite.gd").run(self, a.trim_prefix("--qa-capture="))


func build_shell():
	var top = PanelContainer.new()
	ui.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 91
	var h = D.row(top)
	var brand = D.col(h)
	brand.custom_minimum_size.x = 185
	D.label(brand, "殖 民 契 约", 25, D.INK, false)
	var file_actions = D.row(brand)
	for entry in [["存档", true], ["读档", false]]:
		var saving: bool = entry[1]
		var action = D.button(
			file_actions,
			entry[0],
			func():
				if saving:
					save_slot(SAVE_MANUAL)
				else:
					open_page("save"),
			"Ctrl+S 快速存档；读档页面可选择手动、自动和验收档"
		)
		action.custom_minimum_size = Vector2(72, 26)
		action.add_theme_font_size_override("font_size", 14)
		for style_name in ["normal", "hover", "pressed"]:
			action.add_theme_stylebox_override(style_name, D.box(Color("1a3042"), D.TEAL, 5))
	top_stats = D.label(h, "", 18, D.INK, false)
	top_stats.name = "TopStats"
	top_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clockbox = D.col(h)
	date_label = D.label(clockbox, "", 17, D.GOLD, false)
	var controls = D.row(clockbox)
	var time_rules: Dictionary = sim.progression.time
	for item in [
		["暂停", 0],
		["正常", 1],
		["快进", int(time_rules.fast_multiplier)],
		["极快", int(time_rules.very_fast_multiplier)],
	]:
		var val = int(item[1])
		var b = D.button(
			controls, item[0], func(): set_speed(val), "空格暂停 / 恢复；每天固定步进", "Speed_" + str(val)
		)
		b.custom_minimum_size = Vector2(54, 32)
		b.add_theme_font_size_override("font_size", 15)
	var nav = PanelContainer.new()
	ui.add_child(nav)
	nav.position = Vector2(20, 115)
	nav.custom_minimum_size.x = 143
	nav.anchor_bottom = 1
	nav.offset_bottom = -116
	var nav_scroll = ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav.add_child(nav_scroll)
	var v = D.col(nav_scroll)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	D.label(v, "指 挥 中 枢", 13, D.MUTED, false)
	for entry in [
		["球面总览", "planet"],
		["平铺地图", "flat"],
		["星球档案", "world"],
		["地区建设", "region"],
		["设施清单", "buildings"],
		["经营账本", "economy"],
		["科研教育", "research"],
		["交通运输", "transport"],
		["人口移民", "population"],
		["民营经济", "enterprise"],
		["公司关系", "company"],
		["殖民合同", "contract"],
		["通讯事件", "events"],
		["生涯代管", "career"],
		["保存与设置", "save"]
	]:
		var key = entry[1]
		var nav_button = D.button(v, entry[0], func(): navigate(key), "", "Nav_" + key)
		D.font_size(nav_button, 16)
		nav_button.custom_minimum_size.y = 34
	var right = PanelContainer.new()
	ui.add_child(right)
	right.anchor_left = 1
	right.anchor_right = 1
	right.anchor_top = 0
	right.anchor_bottom = 1
	right.offset_left = -365
	right.offset_right = -20
	right.offset_top = 115
	right.offset_bottom = -116
	var right_column = D.col(right)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(scroll)
	sidebar = D.col(scroll)
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_actions = D.col(right_column)
	var bottom = PanelContainer.new()
	ui.add_child(bottom)
	bottom.anchor_top = 1
	bottom.anchor_bottom = 1
	bottom.anchor_right = 1
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -94
	bottom.offset_bottom = -20
	bottom.add_theme_stylebox_override("panel", D.box(Color("132333"), Color("304756"), 10))
	var foot = D.row(bottom)
	var mission_title = D.label(foot, "任务\n链路", 14, D.TEAL, false)
	mission = D.label(foot, "", 17)
	mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var guide_button = D.button(foot, "行动指南", func(): open_page("guide"))
	guide_button.custom_minimum_size.y = 30
	guide_button.add_theme_stylebox_override("normal", D.box(Color("1a3042"), Color("304756"), 7))
	var collapse = Button.new()
	collapse.text = "收起"
	collapse.add_theme_stylebox_override("normal", D.box(Color("1a3042"), Color("304756"), 7))
	foot.add_child(collapse)
	collapse.pressed.connect(
		func():
			mission.visible = not mission.visible
			mission_title.visible = mission.visible
			collapse.text = "收起" if mission.visible else "展开任务"
			bottom.offset_top = -94 if mission.visible else -70
	)
	toast_label = D.label(ui, "", 18, D.GOLD)
	toast_label.anchor_top = 1
	toast_label.anchor_bottom = 1
	toast_label.offset_left = 195
	toast_label.offset_right = 1200
	toast_label.offset_top = -145
	toast_label.offset_bottom = -100
	map_hint = D.label(ui, "球面总览  ·  右键旋转  ·  滚轮缩放", 14, D.MUTED, false)
	map_hint.name = "MapHint"
	map_hint.position = Vector2(215, 112)
	refresh()


func _process(delta):
	session_seconds += delta
	_finish_autosave(true)
	if sample_frames.size() < 36000:
		sample_frames.append(delta)
	advance_time(delta)
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.text = ""


func advance_time(delta: float):
	if (
		paused
		or menu_open
		or panel_blocks_time()
		or sim.state.status in ["planning", "failed"]
		or bool(map.get("region_busy"))
	):
		return
	if event_pause_required():
		forced_pause(true)
		open_page("events")
		return
	accumulator += delta * speed
	var seconds_per_day: float = float(sim.progression.get("time", {}).get("seconds_per_day", 5.0))
	var days_this_frame: int = 0
	while accumulator >= seconds_per_day:
		# A long frame never turns into a burst of days: the rest of the backlog is dropped.
		days_this_frame += 1
		if days_this_frame > MAX_DAYS_PER_FRAME:
			accumulator = 0
			break
		accumulator -= seconds_per_day
		var prior_company: String = str(sim.state.get("company", {}).get("stage", "normal"))
		sim.tick()
		map.sync_state(sim.state)
		refresh()
		if sim.state.day - autosave_day >= AUTOSAVE_DAYS:
			_begin_autosave()
			autosave_day = sim.state.day
		if sim.state.status != last_status and sim.state.status in ["success", "failed"]:
			forced_pause(false)
			open_page("contract")
		last_status = sim.state.status
		var company_stage: String = str(sim.state.get("company", {}).get("stage", "normal"))
		if (
			company_stage != prior_company
			and company_stage in ["review", "intervention"]
			and not forced_page_open()
		):
			forced_pause(true)
			open_page("company")
		_announce_new_event()
		coach.on_day()
		if event_pause_required() and not forced_page_open():
			forced_pause(true)
			open_page("events")
		if paused or panel_blocks_time():
			accumulator = 0
			break


## Serialization happens here on the main thread; compression and disk work run on a worker.
func _begin_autosave():
	_finish_autosave(false)
	autosave_snapshot = SaveIo.snapshot(sim, SAVE_AUTO)
	autosave_task = WorkerThreadPool.add_task(_write_autosave.bind(autosave_snapshot))


static func _write_autosave(snap: Dictionary):
	snap.result = SaveIo.write_snapshot(snap)


func _finish_autosave(only_if_done: bool):
	if autosave_task < 0:
		return
	if only_if_done and not WorkerThreadPool.is_task_completed(autosave_task):
		return
	WorkerThreadPool.wait_for_task_completion(autosave_task)
	autosave_task = -1
	if str(autosave_snapshot.get("result", "")) != "":
		toast(str(autosave_snapshot.result))
	autosave_snapshot = {}


## Notices do not stop the game, so each one gets a line on screen when it arrives.
func _announce_new_event() -> void:
	var serial: int = int(sim.state.get("events_v2", {}).get("next_id", 0))
	if serial == announced_event:
		return
	announced_event = serial
	var pending: Variant = sim.state.get("event", {})
	if (
		pending is Dictionary
		and not pending.is_empty()
		and not bool(pending.get("pause_required", true))
	):
		toast("新通讯：" + str(pending.get("title", "")) + "（左侧通讯事件）")


func event_pause_required() -> bool:
	return Events.pause_required(sim)


## Whether an open panel holds the clock under the current setting.
func panel_blocks_time() -> bool:
	return is_instance_valid(overlay) and panel_pause


func forced_page_open() -> bool:
	return (
		is_instance_valid(overlay) and current_page in ["contract", "company", "events"] and paused
	)


## Stops the clock for something the player must see; `resume` restores the speed on close.
func forced_pause(resume: bool):
	resume_on_close = resume and not paused
	paused = true
	accumulator = 0


func set_speed(n: int):
	if n > 0 and (panel_blocks_time() or menu_open):
		return
	if n > 0 and event_pause_required():
		open_page("events")
		return
	paused = n == 0
	resume_on_close = false
	if paused:
		accumulator = 0
	if n > 0:
		speed = n
	refresh()


func _input(event):
	if (
		event is InputEventKey
		and event.pressed
		and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_F12, KEY_S]
	):
		if event.keycode == KEY_S and not event.ctrl_pressed:
			return
		if event.keycode == KEY_SPACE and get_viewport().gui_get_focus_owner() is LineEdit:
			return
		_unhandled_input(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S and event.ctrl_pressed:
			save_slot(SAVE_MANUAL)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if menu_open:
				return
			if is_instance_valid(overlay):
				close_modal()
			else:
				open_page("save")
		if event.keycode == KEY_SPACE and not menu_open:
			set_speed(speed if paused else 0)
		if event.keycode == KEY_F12:
			capture()
	if is_instance_valid(overlay):
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		map.orbit(event.relative.x, event.relative.y)
		coach.note_camera()
	elif event is InputEventMouseMotion and not local_view and map.has_method("hover_region"):
		map.hover_region(event.position)
	if (
		event is InputEventMouseMotion
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		and map.has_method("pan")
	):
		map.pan(event.relative.x, event.relative.y)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			map.zoom(-1)
			coach.note_camera()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			map.zoom(1)
			coach.note_camera()
		if event.button_index == MOUSE_BUTTON_LEFT and not local_view:
			map.pick_region(event.position)


func select_region(id: int):
	selected = id
	coach.note_site(id)
	refresh_sidebar()


## A settlement gets its name from the player: asked when settling, and whenever they rename it.
func ask_site_name(again: bool):
	if not again:
		var refusal: String = sim.settle_refusal(selected)
		if refusal != "":
			toast(refusal)
			return
	naming_site = selected
	naming_again = again
	open_page("name_site")
	var edit: LineEdit = modal_box.find_child("SiteNameEdit", true, false)
	edit.text = str(sim.state.world.regions[selected].name) if again else ""
	edit.grab_focus.call_deferred()


func confirm_site_name(_typed: String = ""):
	var edit: LineEdit = modal_box.find_child("SiteNameEdit", true, false)
	var error: String = ""
	if naming_again:
		error = act("rename", {"site": naming_site, "name": edit.text})
	else:
		error = act("settle", {"site": naming_site, "name": edit.text})
	if error == "":
		close_modal()
		refresh_sidebar()


## The shortcut from a shortage line: the right page, on the right part of it.
func open_fix(fix: Dictionary):
	if fix.has("category"):
		build_category = str(fix.category)
	open_page(str(fix.page))


func navigate(page: String):
	if page == "planet":
		local_view = false
		map.show_planet()
		map_hint.text = "球面总览  ·  右键旋转  ·  滚轮缩放"
		refresh_sidebar()
	elif page == "flat":
		local_view = false
		map.show_flat()
		map_hint.text = "平铺地图  ·  右键/中键平移  ·  滚轮缩放"
		refresh_sidebar()
	elif page == "region":
		local_view = true
		map.show_region(selected)
		map_hint.text = "地区建设  ·  右键旋转  ·  中键平移  ·  滚轮缩放"
		refresh_sidebar()
	else:
		open_page(page)


func settlement() -> Dictionary:
	for s in sim.state.settlements:
		if int(s.region) == selected:
			return s
	return {}


func refresh():
	if not is_instance_valid(top_stats):
		return
	var pop = 0
	for s in sim.state.settlements:
		pop += int(s.population)
	var net = float(sim.state.get("operating_net", 0))
	top_stats.text = (
		"公共资金  ¥ %s    经营结余  %+.0f /日\n人口  %d    据点  %d / %d    种子  %d"
		% [
			money(sim.state.cash),
			net,
			pop,
			sim.state.settlements.size(),
			Contract.settlement_cap(sim),
			int(sim.state.world.seed)
		]
	)
	date_label.text = (
		"生涯 %d 日 / 登陆 %d 日 · %s"
		% [sim.state.career.global_day, sim.state.day, "已暂停" if paused else str(speed) + " 倍速"]
	)
	var steps = ["立足：登陆、矿场、出口、科研 → 分工：第二据点、食品、加工 → 自立：人口、企业、非矿业收入 → 总督"]
	var hint = "在地图上选一个地点，右侧卡片告诉你它适合做什么。"
	if sim.state.status != "planning":
		var phase = {"active": "契约考核中", "success": "总督阶段", "failed": "经营终止"}
		hint = (
			"经营连盈 %d 期  ·  %s"
			% [sim.state.get("streak", 0), phase.get(sim.state.status, sim.state.status)]
		)
		if sim.state.settlements.size() < 2:
			hint += "  |  矿山负责出口，肥沃的土地负责粮食。"
		elif sim.state.roads.is_empty():
			hint += "  |  据点尚未相连，打开交通运输修路。"
		else:
			hint += "  |  贸易和运输按本地库存自动进行。"
	if not sim.state.get("event", {}).is_empty():
		hint = "! 待处理通讯：" + str(sim.state.event.get("title", "事件")) + "  ·  打开左侧通讯事件"
	mission.text = steps[0] + "\n" + hint
	refresh_sidebar()


func refresh_sidebar():
	if not is_instance_valid(sidebar):
		return
	D.begin(sidebar)
	Pages.region(self, sidebar)
	D.finish(sidebar)
	D.begin(sidebar_actions)
	Pages.region_actions(self, sidebar_actions)
	D.finish(sidebar_actions)


func act(action: String, args: Dictionary = {}):
	var err: String = sim.act(action, args)
	if err.is_empty():
		map.sync_state(sim.state)
	refresh()
	populate_current_page()
	toast(err if not err.is_empty() else "指令已执行。")
	return err


func toast(text: String):
	toast_label.text = text
	toast_time = 7
	if is_instance_valid(modal_feedback):
		modal_feedback.text = text


func _hide_overlay():
	if is_instance_valid(modal_root):
		modal_root.visible = false
	overlay = null
	modal_box = null
	modal_feedback = null
	current_page = ""
	menu_open = false


func close_modal():
	_hide_overlay()
	if (
		resume_on_close
		and not event_pause_required()
		and not sim.state.get("status", "") in ["planning", "failed"]
	):
		paused = false
	resume_on_close = false
	refresh()


## One panel host stays in the tree for the whole session; each page keeps its own controls,
## so opening a page again only updates what changed.
func _build_modal_host():
	modal_root = Control.new()
	modal_root.name = "ModalHost"
	ui.add_child(modal_root)
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.visible = false
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.06, .88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(center)
	modal_panel = PanelContainer.new()
	center.add_child(modal_panel)
	var outer = D.col(modal_panel)
	var head = D.row(outer)
	modal_title = D.label(head, "", 27, D.INK, false)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_close = D.button(head, "关闭  ×", close_modal, "", "ModalClose")
	modal_pages = VBoxContainer.new()
	modal_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(modal_pages)
	modal_footer = D.label(outer, "", 15, D.GOLD)
	modal_footer.name = "Footer"


func _page_box(key: String) -> VBoxContainer:
	if not page_boxes.has(key):
		var scroll = ScrollContainer.new()
		scroll.name = "Page_" + key
		scroll.custom_minimum_size = Vector2(0, PAGE_HEIGHT)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		modal_pages.add_child(scroll)
		var box = D.col(scroll)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_boxes[key] = box
	for other: String in page_boxes:
		page_boxes[other].get_parent().visible = other == key
	return page_boxes[key]


func modal(title: String, width: int = 960, closable: bool = true, key: String = "page"):
	_hide_overlay()
	if not is_instance_valid(modal_root):
		_build_modal_host()
	overlay = modal_root
	modal_root.visible = true
	modal_root.move_to_front()
	modal_panel.custom_minimum_size = Vector2(width, MODAL_HEIGHT)
	modal_title.text = title
	modal_close.visible = closable
	modal_footer.text = (
		"" if not closable else ("已暂停，可从容决策；关闭后恢复原速度。" if panel_pause else "面板打开时时间继续流逝。")
	)
	modal_feedback = modal_footer
	modal_box = _page_box(key)
	if is_instance_valid(coach) and coach.visible:
		coach.move_to_front()
	if panel_pause:
		if not paused:
			resume_on_close = true
		paused = true
		accumulator = 0
	refresh()
	return modal_box


func populate_current_page():
	if not is_instance_valid(overlay) or current_page.is_empty():
		return
	D.begin(modal_box)
	if current_page in ["research", "company", "events", "career", "manage"]:
		ProgressionPages.populate(self, modal_box, current_page)
	else:
		Pages.populate(self, modal_box, current_page)
	D.finish(modal_box)


func open_page(page: String):
	var titles = {
		"world": "星球档案 / 自然环境",
		"build": "地区工程 / 建设与生产",
		"buildings": "设施清单 / 在建与运营",
		"name_site": "给据点起名",
		"economy": "公共账本 / 经济与库存",
		"research": "知识就是生产力 / 科研教育",
		"transport": "交通运输 / 道路与航线",
		"enterprise": "混合经济 / 民营经营许可",
		"population": "人口 / 吸引力与招募",
		"contract": "殖民经营对赌协议",
		"events": "远端通讯 / 当前事件",
		"save": "档案与显示设置",
		"guide": "专员行动指南"
	}
	titles.merge({"company": "公司关系 / 审查与有条件介入", "career": "连续生涯 / 总督与代管", "manage": "生产管理 / 批量操作"})
	modal(titles.get(page, page), 960, true, page)
	current_page = page
	coach.note_page(page)
	populate_current_page()


func show_menu():
	var box = modal("殖 民 契 约     /     COLONY CHARTER", 1030, false, "menu")
	menu_open = true
	paused = true
	resume_on_close = false
	D.begin(box)
	var h = D.row(box)
	D.portrait(h, "liaison", 260, 430)
	var v = D.col(h)
	v.add_theme_constant_override("separation", 5)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(v, "一颗星球。一纸契约。\n从第一座矿场，到自己的明天。", 28, D.INK)
	D.label(v, "你是公司的殖民外包专员。选址、开矿、养活大家，把几处据点连成一个能自负盈亏的社会，赢得总督资格。", 18, D.MUTED)
	var r = D.row(v)
	D.label(r, "星球种子", 17, D.MUTED, false)
	if menu_seed == "":
		menu_seed = _new_seed()
	seed_edit = D.line_edit(r, "SeedEdit", menu_seed)
	seed_edit.custom_minimum_size.x = 180
	seed_edit.editable = not tutorial_on
	if not seed_edit.text_changed.is_connected(_on_seed_changed):
		seed_edit.text_changed.connect(_on_seed_changed)
	size_option = D.option(r, "SizeOption", ["小型 · 短途", "中型 · 标准", "大型 · 长途"], 1)
	size_option.disabled = tutorial_on
	difficulty_option = D.option(r, "DifficultyOption", ["简单", "标准", "困难"], 1)
	difficulty_option.disabled = tutorial_on
	var reroll = D.button(r, "换个种子", _reroll_seed, "只更换输入框中的种子；新建后生成对应星球")
	D.font_size(reroll, 15)
	planet_preview = D.label(v, "", 16, D.GOLD)
	_show_planet_preview()
	D.label(v, "开局合作方案", 15, D.TEAL)
	var group = ButtonGroup.new()
	for id: String in sim.config.openings:
		var opening: Dictionary = sim.config.openings[id]
		var b = D.button(
			v, str(opening.name) + "  /  " + str(opening.description), func(): advantage = id
		)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == advantage
		b.disabled = tutorial_on
		b.custom_minimum_size.y = 34
		D.font_size(b, 15)
		b.add_theme_stylebox_override("normal", D.box(Color("1a3042"), Color("304756"), 10))
		b.add_theme_stylebox_override("pressed", D.box(Color("31565e"), D.TEAL, 10))
		b.add_theme_stylebox_override("hover", D.box(Color("264553"), D.TEAL, 10))
	var teach = D.button(
		v,
		"新手引导：开（使用引导专用星球）" if tutorial_on else "新手引导：关",
		func():
			tutorial_on = not tutorial_on
			show_menu(),
		"第一次玩建议打开。引导不会拦住你，可以随时结束。",
		"TutorialToggle"
	)
	D.font_size(teach, 15)
	teach.custom_minimum_size.y = 34
	var launch = D.button(v, "新建殖民远征  →", start_game, "", "NewGame")
	launch.add_theme_stylebox_override("normal", D.box(Color("1a3042"), D.TEAL, 10))
	var resume = D.row(v)
	var latest: String = _latest_save()
	var summary: String = _save_summary(latest)
	var continue_button = D.button(
		resume,
		"继续 · " + summary if summary != "" else "继续上次存档",
		func(): load_path(latest),
		"",
		"ContinueGame"
	)
	continue_button.disabled = latest == ""
	if dev_mode:
		D.button(resume, "读取1.6事件中段", func(): load_path("res://data/v16/acceptance_event_mid.json"))
	D.finish(box)


func _new_seed() -> String:
	return str(randi_range(1, 2147483646))


## Asking for another planet means leaving the tutorial's own one.
func _reroll_seed():
	menu_seed = _new_seed()
	tutorial_on = false
	show_menu()


func _on_seed_changed(text: String):
	menu_seed = text
	_show_planet_preview()


## What the typed seed will give, before any world is built.
func _show_planet_preview():
	if tutorial_on:
		planet_preview.text = "新手引导使用专用星球。想自己选种子、大小、难度和开局，先把引导关掉，或点「换个种子」。"
		return
	var rules: Dictionary = sim.progression_geo()
	var character: Dictionary = WorldGen.Plates.character(
		WorldGen.SeedGeo.normalize_seed(seed_edit.text), rules
	)
	planet_preview.text = "这个种子：" + Labels.planet_type(rules.planet_types, character)


func old_save_path(relative: String) -> String:
	return OS.get_environment("APPDATA") + relative


## The newer of the manual and automatic saves; a 1.6 save if this version has none yet.
func _latest_save() -> String:
	var best: String = _newest_of([SAVE_MANUAL, SAVE_AUTO])
	if best == "":
		best = _newest_of([old_save_path(OLD_SAVE_MANUAL), old_save_path(OLD_SAVE_AUTO)])
	return best


func _newest_of(paths: Array) -> String:
	var best: String = ""
	var newest: int = -1
	for path: String in paths:
		if FileAccess.file_exists(path) and FileAccess.get_modified_time(path) > newest:
			newest = FileAccess.get_modified_time(path)
			best = path
	return best


## "planet, day, cash" read from a save's header, without touching the rest of the file.
func _save_summary(path: String) -> String:
	if path == "":
		return ""
	var header: Dictionary = SaveIo.read_header(path)
	if header.is_empty():
		return ""
	return (
		"星球 %s · 第 %d 日 · ¥ %s"
		% [str(header.get("planet", "?")), int(header.get("day", 0)), money(header.get("cash", 0))]
	)


func start_game():
	if tutorial_on:
		start_tutorial()
		return
	var text = seed_edit.text
	var seed_value: Variant = text
	var scale_id = size_option.selected
	difficulty = ["easy", "normal", "hard"][difficulty_option.selected]
	_begin_world(seed_value, advantage, scale_id, difficulty)
	menu_seed = ""
	coach.stop(false)
	open_page("contract")
	var kind_of_planet: String = Labels.planet_type(
		sim.progression_geo().planet_types, sim.geo.get("character", {})
	)
	if kind_of_planet != "":
		toast("星球类型：" + kind_of_planet)


## A new game on the tutorial's own planet, with the coach panel running.
func start_tutorial():
	var rules: Dictionary = Tutorial.data()
	advantage = str(rules.opening)
	difficulty = str(rules.difficulty)
	_begin_world(int(rules.seed), advantage, int(rules.size), difficulty)
	sim.act("tutorial_begin")
	_hide_overlay()
	coach.start()
	refresh()


func _begin_world(seed_value: Variant, opening: String, scale_id: int, level: String):
	sim.new_game(seed_value, opening, scale_id, level)
	Career.capture_checkpoint(sim)
	selected = 0
	local_view = false
	map.setup(sim.geo)
	map.focus_region(selected)
	map_hint.text = "球面总览  ·  右键旋转  ·  滚轮缩放"
	map.sync_state(sim.state)
	accumulator = 0
	autosave_day = 0
	last_status = "planning"
	resume_on_close = false
	build_category = "all"
	build_plots = {}
	expanded_kinds = {}
	announced_event = 0
	_hide_overlay()


func load_path(path: String):
	var err: String = sim.load_game(path)
	if not err.is_empty():
		toast(err)
		return
	coach.stop(false)
	selected = int(sim.state.settlements[0].region) if not sim.state.settlements.is_empty() else 0
	map.setup(sim.geo)
	map.focus_region(selected)
	map.sync_state(sim.state)
	local_view = false
	paused = true
	map_hint.text = "球面总览  ·  右键旋转  ·  滚轮缩放"
	accumulator = 0
	autosave_day = sim.state.day
	last_status = sim.state.status
	resume_on_close = false
	close_modal()
	refresh()
	toast("完整存档已恢复；按空格继续经营。")


func export_state_json():
	var path: String = "user://state_export.json"
	var error: String = SaveIo.export_json(sim, path)
	toast(error if error != "" else "已导出：" + ProjectSettings.globalize_path(path))


func save_slot(path: String):
	var err: String = sim.save_game(path)
	toast("已存档 · 第 %d 日。可通过左上角“读档”继续。" % sim.state.day if err.is_empty() else err)


func career_action(action: String, args: Dictionary = {}):
	var error: String = ""
	if action == "invest":
		error = Career.invest(sim, float(args.get("amount", 0)))
	elif action == "handover":
		error = Career.handover(
			sim,
			args.get("seed", 260130),
			str(args.get("opening", sim.state.advantage)),
			str(args.get("difficulty", sim.state.get("difficulty", "normal"))),
			SAVE_MANUAL,
			int(args.get("size", sim.state.world.size))
		)
	elif action == "restart":
		error = Career.restart(sim, str(args.get("difficulty", "normal")), SAVE_MANUAL)
	if error != "":
		toast(error)
		return
	if action in ["handover", "restart"]:
		selected = 0
		local_view = false
		paused = true
		accumulator = 0
		autosave_day = 0
		last_status = sim.state.status
		map.setup(sim.geo)
		map.focus_region(0)
		map.sync_state(sim.state)
		open_page("contract")
	else:
		open_page("career")
	refresh()
	toast("生涯操作已完成。")


func capture():
	var folder = OS.get_user_data_dir() + "/screenshots"
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	var path = folder + "/capture_" + str(Time.get_unix_time_from_system()) + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	toast("实机画面已保存：" + path)


func money(value) -> String:
	return String.num(float(value), 0)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finish_autosave(false)
		var sorted = sample_frames.duplicate()
		sorted.sort()
		var sum = 0.0
		for d in sorted:
			sum += d
		var report = {
			"session_seconds": session_seconds,
			"frames": sorted.size(),
			"average_fps": sorted.size() / maxf(sum, .001),
			"p95_frame_ms": sorted[int(sorted.size() * .95)] * 1000 if not sorted.is_empty() else 0,
			"resolution": str(DisplayServer.window_get_size()),
			"renderer": "gl_compatibility",
			"adapter": RenderingServer.get_video_adapter_name(),
			"processor": OS.get_processor_name(),
			"simulation_day": sim.state.get("day", 0),
			"scope": "entire interactive session; includes menus and scene transitions"
		}
		var f = FileAccess.open("user://last_session_metrics.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, "\t"))


func apply_scale(value: float):
	ui_scale = value
	get_window().content_scale_factor = value
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("display", "scale", value)
	settings.save("user://settings.cfg")


func toggle_panel_pause():
	panel_pause = not panel_pause
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("gameplay", "panel_pause", panel_pause)
	settings.save("user://settings.cfg")
	open_page("save")


func toggle_information():
	detailed_info = not detailed_info
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("display", "details", detailed_info)
	settings.save("user://settings.cfg")
	open_page("save")
