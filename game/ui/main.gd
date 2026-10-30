extends Node
const D = preload("res://ui/design.gd")
const Pages = preload("res://ui/pages.gd")
const Sim = preload("res://simulation/sim.gd")
const Map = preload("res://world/map_view.gd")
const Career = preload("res://simulation/career.gd")
const ProgressionPages = preload("res://ui/progression_pages.gd")
var sim = Sim.new()
var map: Node3D
var ui: Control
var sidebar: VBoxContainer
var top_stats: Label
var date_label: Label
var mission: Label
var toast_label: Label
var overlay: Control
var modal_box: VBoxContainer
var modal_feedback: Label
var selected: int = 0
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


func _ready():
	Engine.max_fps = 60
	dev_mode = OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")
	sim.new_game(260129, "capital", 1)
	map = Map.new()
	add_child(map)
	map.setup(sim.state.world)
	map.region_selected.connect(select_region)
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = D.theme()
	layer.add_child(ui)
	build_shell()
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
					save_slot("user://manual.json")
				else:
					open_page("save"),
			"Ctrl+S 快速存档；读档页面可选择手动、自动和验收档"
		)
		action.custom_minimum_size = Vector2(72, 26)
		action.add_theme_font_size_override("font_size", 14)
		for style_name in ["normal", "hover", "pressed"]:
			action.add_theme_stylebox_override(style_name, D.box(Color("1a3042"), D.TEAL, 5))
	top_stats = D.label(h, "", 18, D.INK, false)
	top_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clockbox = D.col(h)
	date_label = D.label(clockbox, "", 17, D.GOLD, false)
	var controls = D.row(clockbox)
	for item in [
		["暂停", 0], ["正常", 1], ["快进", int(sim.progression.get("time", {}).get("fast_multiplier", 4))]
	]:
		var val = int(item[1])
		var b = D.button(controls, item[0], func(): set_speed(val), "空格暂停 / 恢复；每天固定步进")
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
	D.label(v, "指 挥 中 枢", 13, D.MUTED, false)
	for entry in [
		["球面总览", "planet"],
		["平铺地图", "flat"],
		["星球档案", "world"],
		["地区建设", "region"],
		["经营账本", "economy"],
		["科研教育", "research"],
		["交通运输", "transport"],
		["民营经济", "enterprise"],
		["公司关系", "company"],
		["殖民合同", "contract"],
		["通讯事件", "events"],
		["生涯代管", "career"],
		["保存与设置", "save"]
	]:
		var key = entry[1]
		D.button(v, entry[0], func(): navigate(key))
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
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	sidebar = D.col(scroll)
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	map_hint.position = Vector2(215, 112)
	refresh()


func _process(delta):
	session_seconds += delta
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
	while accumulator >= seconds_per_day:
		accumulator -= seconds_per_day
		var prior_company: String = str(sim.state.get("company", {}).get("stage", "normal"))
		sim.tick()
		map.sync_state(sim.state)
		refresh()
		if sim.state.day - autosave_day >= 10:
			sim.save_game("user://autosave.json")
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
		if event_pause_required() and not forced_page_open():
			forced_pause(true)
			open_page("events")
		if paused or panel_blocks_time():
			accumulator = 0
			break


func event_pause_required() -> bool:
	return bool(preload("res://simulation/events_v2.gd").view(sim).get("pause_required", false))


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
			save_slot("user://manual.json")
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
	if (
		event is InputEventMouseMotion
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		and map.has_method("pan")
	):
		map.pan(event.relative.x, event.relative.y)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			map.zoom(-1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			map.zoom(1)
		if event.button_index == MOUSE_BUTTON_LEFT and not local_view:
			map.pick_region(event.position)


func select_region(id: int):
	selected = id
	refresh_sidebar()


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
		"公共资金  ¥ %s    经营结余  %+.0f /日\n人口  %d    据点  %d / 2    种子  %d"
		% [money(sim.state.cash), net, pop, sim.state.settlements.size(), int(sim.state.world.seed)]
	)
	date_label.text = (
		"生涯 %d 日 / 登陆 %d 日 · %s"
		% [sim.state.career.global_day, sim.state.day, "已暂停" if paused else str(speed) + " 倍速"]
	)
	var steps = ["勘察登陆 → 生活与矿场 → 自动出口 → 河谷农业 → 两地物流 → 民营企业 → 总督"]
	var hint = "先签署合同，并在右侧选择登陆区域。"
	if sim.state.status != "planning":
		var phase = {"active": "契约考核中", "success": "总督阶段", "failed": "经营终止"}
		hint = (
			"经营连盈 %d 期  ·  %s"
			% [sim.state.get("streak", 0), phase.get(sim.state.status, sim.state.status)]
		)
		if sim.state.settlements.size() < 2:
			hint += "  |  建议：矿区负责出口，河谷负责食物。"
		elif sim.state.route.is_empty():
			hint += "  |  两据点尚未连接，打开交通运输。"
		else:
			hint += "  |  自动贸易与运输按本地库存运行。"
	if not sim.state.get("event", {}).is_empty():
		hint = "! 待处理通讯：" + str(sim.state.event.get("title", "事件")) + "  ·  打开左侧通讯事件"
	mission.text = steps[0] + "\n" + hint
	refresh_sidebar()


func refresh_sidebar():
	if not is_instance_valid(sidebar):
		return
	for n in sidebar.get_children():
		sidebar.remove_child(n)
		n.queue_free()
	Pages.region(self, sidebar)


func act(action: String, args: Dictionary = {}):
	var err: String = sim.act(action, args)
	if err.is_empty():
		map.sync_state(sim.state)
	refresh()
	if is_instance_valid(overlay) and not current_page.is_empty():
		var scroll: ScrollContainer = modal_box.get_parent()
		var position_y = scroll.scroll_vertical
		open_page(current_page)
		_restore_scroll.call_deferred(position_y)
	toast(err if not err.is_empty() else "指令已执行。")
	return err


func _restore_scroll(value: int):
	await get_tree().process_frame
	if is_instance_valid(modal_box):
		modal_box.get_parent().scroll_vertical = value


func toast(text: String):
	toast_label.text = text
	toast_time = 7
	if is_instance_valid(modal_feedback):
		modal_feedback.text = text


func _free_overlay():
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	modal_box = null
	modal_feedback = null
	current_page = ""
	menu_open = false


func close_modal():
	_free_overlay()
	if (
		resume_on_close
		and not event_pause_required()
		and not sim.state.get("status", "") in ["planning", "failed"]
	):
		paused = false
	resume_on_close = false
	refresh()


func modal(title: String, width: int = 960, closable: bool = true):
	_free_overlay()
	overlay = Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.06, .88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 690)
	center.add_child(panel)
	var outer = D.col(panel)
	var head = D.row(outer)
	var title_label = D.label(head, title, 27, D.INK, false)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if closable:
		D.button(head, "关闭  ×", close_modal)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 535)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	modal_box = D.col(scroll)
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f = D.label(
		outer,
		"" if not closable else ("已暂停，可从容决策；关闭后恢复原速度。" if panel_pause else "面板打开时时间继续流逝。"),
		15,
		D.GOLD
	)
	f.name = "Footer"
	modal_feedback = f
	if panel_pause:
		if not paused:
			resume_on_close = true
		paused = true
		accumulator = 0
	refresh()
	return modal_box


func open_page(page: String):
	var titles = {
		"world": "星球档案 / 自然环境",
		"build": "地区工程 / 建设与生产",
		"economy": "公共账本 / 经济与库存",
		"research": "知识就是生产力 / 科研教育",
		"transport": "跨区货运 / 两地分工",
		"enterprise": "混合经济 / 民营经营许可",
		"contract": "殖民经营对赌协议",
		"events": "远端通讯 / 当前事件",
		"save": "档案与显示设置",
		"guide": "专员行动指南"
	}
	titles.merge({"company": "公司关系 / 审查与有条件介入", "career": "连续生涯 / 总督与代管", "manage": "生产管理 / 批量操作"})
	var box = modal(titles.get(page, page))
	current_page = page
	if page in ["research", "company", "events", "career", "manage"]:
		ProgressionPages.populate(self, box, page)
	else:
		Pages.populate(self, box, page)


func show_menu():
	var box = modal("殖 民 契 约     /     COLONY CHARTER", 1030, false)
	menu_open = true
	paused = true
	resume_on_close = false
	var h = D.row(box)
	D.portrait(h, "liaison", 260, 430)
	var v = D.col(h)
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(v, "一颗星球。一纸契约。\n从第一座矿场，到自己的明天。", 28, D.INK)
	D.label(v, "你是公司的殖民外包专员。让两座据点各尽其能，建立可自负盈亏的社会，赢得总督资格。", 18, D.MUTED)
	var r = D.row(v)
	D.label(r, "星球种子", 17, D.MUTED, false)
	seed_edit = LineEdit.new()
	seed_edit.text = "260129"
	seed_edit.custom_minimum_size.x = 180
	r.add_child(seed_edit)
	size_option = OptionButton.new()
	for s in ["小型 · 短途", "中型 · 标准", "大型 · 长途"]:
		size_option.add_item(s)
	size_option.select(1)
	r.add_child(size_option)
	difficulty_option = OptionButton.new()
	for label in ["简单", "标准", "困难"]:
		difficulty_option.add_item(label)
	difficulty_option.select(1)
	r.add_child(difficulty_option)
	var reroll = D.button(
		r, "换个种子", func(): seed_edit.text = str(randi_range(1, 2147483646)), "只更换输入框中的种子；新建后生成对应星球"
	)
	reroll.add_theme_font_size_override("font_size", 15)
	D.label(v, "开局合作方案", 15, D.TEAL)
	var opts = [
		["capital", "资本支持", "更多初始公共资金，容错更高。"],
		["workers", "工人招募", "更多劳动人口，生产更快展开。"],
		["science", "研究合作", "科研人才与勘探优势，同时保有基础劳力。"]
	]
	var group = ButtonGroup.new()
	for o in opts:
		var id = o[0]
		var b = D.button(v, o[1] + "  /  " + o[2], func(): advantage = id)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == advantage
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", D.box(Color("1a3042"), Color("304756"), 10))
		b.add_theme_stylebox_override("pressed", D.box(Color("31565e"), D.TEAL, 10))
		b.add_theme_stylebox_override("hover", D.box(Color("264553"), D.TEAL, 10))
	var launch = D.button(v, "新建殖民远征  →", start_game)
	launch.add_theme_stylebox_override("normal", D.box(Color("1a3042"), D.TEAL, 10))
	var resume = D.row(v)
	D.button(resume, "继续上次存档", func(): load_path("user://manual.json"))
	if dev_mode:
		D.button(resume, "读取1.6事件中段", func(): load_path("res://data/v16/acceptance_event_mid.json"))


func start_game():
	var text = seed_edit.text
	var seed_value: Variant = text
	var scale_id = size_option.selected
	difficulty = ["easy", "normal", "hard"][difficulty_option.selected]
	sim.new_game(seed_value, advantage, scale_id, difficulty)
	Career.capture_checkpoint(sim)
	selected = 0
	local_view = false
	map.setup(sim.state.world)
	map.focus_region(selected)
	map_hint.text = "球面总览  ·  右键旋转  ·  滚轮缩放"
	map.sync_state(sim.state)
	accumulator = 0
	autosave_day = 0
	last_status = "planning"
	resume_on_close = false
	_free_overlay()
	open_page("contract")


func load_path(path: String):
	var err: String = sim.load_game(path)
	if not err.is_empty():
		toast(err)
		return
	selected = int(sim.state.settlements[0].region) if not sim.state.settlements.is_empty() else 0
	map.setup(sim.state.world)
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
			"user://manual.json",
			int(args.get("size", sim.state.world.size))
		)
	elif action == "restart":
		error = Career.restart(sim, str(args.get("difficulty", "normal")), "user://manual.json")
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
		map.setup(sim.state.world)
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
