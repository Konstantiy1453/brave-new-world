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
const DistrustGauge = preload("res://ui/distrust_gauge.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Labels = preload("res://ui/labels.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const Stats = preload("res://simulation/stats.gd")
const Keys = preload("res://simulation/keys.gd")
const Graphics = preload("res://ui/graphics.gd")
const MAX_DAYS_PER_FRAME: int = 3
const SAVE_MANUAL: String = "user://manual.save"
const SAVE_AUTO: String = "user://autosave.save"
const V18_SAVE_MANUAL: String = "/ColonyCharter/v18/manual.save"
const V18_SAVE_AUTO: String = "/ColonyCharter/v18/autosave.save"
const V17_SAVE_MANUAL: String = "/ColonyCharter/v17/manual.save"
const V17_SAVE_AUTO: String = "/ColonyCharter/v17/autosave.save"
const OLD_SAVE_MANUAL: String = "/ColonyCharter/v16/manual.json"
const OLD_SAVE_AUTO: String = "/ColonyCharter/v16/autosave.json"
const OLDER_SAVE_MANUAL: String = "/Godot/app_userdata/殖民契约 · COLONY CHARTER/manual.json"
## Autosaves land on every quarter of the calendar (progression.json time.autosave_days).
const AUTOSAVE_FALLBACK_DAYS: int = 90
## Days whose mean is the change shown after each amount in the top bar.
const DAILY_WINDOW: int = 7
const MODAL_HEIGHT: int = 690
const PAGE_HEIGHT: int = 535
const TOP_CELLS: Array = [
	["money", "¥", "公共资金"],
	["labour", "crew", "劳动力"],
	["places", "据", "据点"],
	["food", "food", "食品"],
	["power", "power", "电力"],
	["water", "water", "水"],
	["ore", "ore", "铁矿"],
	["copper", "copper", "铜矿"],
	["crystal", "crystal", "工业晶体"],
	["materials", "materials", "建材"],
	["parts", "parts", "部件"],
	["components", "components", "电子元件"],
]
const TOP_GOODS: Array[String] = [
	"food", "ore", "copper", "crystal", "materials", "parts", "components"
]
const MONTH_DAYS: float = 30.0
const COLUMN_LEFT: int = 170
const COLUMN_WIDTH: int = 300
## Research notices: width, distance from the top, how many at once, seconds on screen.
const NOTICE_WIDTH: int = 460
const NOTICE_TOP: int = 98
const NOTICE_LIMIT: int = 3
const NOTICE_SECONDS: float = 8.0
## Ending scenes are longer to read than a technology's name.
const EVENT_NOTICE_SECONDS: float = 14.0
const PAGE_TOOLTIPS: Dictionary = {"research": "打开科研教育", "events": "打开通讯事件"}
## Pages drawn in a module's variant (design.gd); every other page stays neutral.
const PAGE_VARIANTS: Dictionary = {
	"research": D.RESEARCH,
	"build": D.INDUSTRY,
	"buildings": D.INDUSTRY,
	"manage": D.INDUSTRY,
}
## The pages that lay out side by side get a wider panel, up to this, inside the window.
const WIDE_PAGES: Array[String] = ["build", "research"]
const WIDE_MODAL: int = 1320
var sim = Sim.new()
var map: Node3D
var ui: Control
var sidebar: VBoxContainer
var sidebar_actions: VBoxContainer
var top_stats: GridContainer
var top_cells: Dictionary = {}
var gauge: PanelContainer
var column_panel: PanelContainer
var column_box: VBoxContainer
var column_tab: Button
var column_open: bool = true
var date_label: Label
var mission: Label
var toast_label: Label
var overlay: Control
var modal_box: VBoxContainer
var modal_feedback: Label
var selected: int = 0
var research_team: Dictionary = {}
var site_filter: int = 0
var announced_event: int = 0
var build_category: String = "all"
var build_plots: Dictionary = {}
## The facility the construction page shows in detail; the first listed one when it is not listed.
var build_selected: String = ""
var expanded_kinds: Dictionary = {}
var coach: PanelContainer
var tutorial_on: bool = true
var naming_site: int = 0
var naming_again: bool = false
var naming_kind: String = "residential"
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
## Research notices: one card per finished technology under the top bar, for a few seconds.
var notices: VBoxContainer
var research_watch: Dictionary = {}
var research_seen: int = 0
## Event endings already shown: the events state being watched and the newest ending's instance.
var event_watch: Dictionary = {}
var event_seen: String = ""
var autosave_day: int = 0
var session_seconds: float = 0
var sample_frames: Array = []
var ui_scale: float = 1.0
var map_hint: Label
var difficulty_option: OptionButton
var difficulty: String = "normal"
var detailed_info: bool = true
var panel_pause: bool = true
## The moving map: a turning planet, day and night with lights, weather. Saved in settings.cfg.
var visual_spin: bool = true
var visual_day_night: bool = true
var visual_weather: bool = true
## Anti-aliasing level (Graphics.AA_LEVELS) and the free-plot rings in the region view.
var visual_aa: String = Graphics.AA_DEFAULT
var plot_marks: bool = false
var resume_on_close: bool = false
var dev_mode: bool = false
var modal_root: Control
var modal_panel: PanelContainer
var modal_title: Label
var modal_close: Button
var modal_pages: VBoxContainer
var modal_footer: Label
var modal_rule_accent: ColorRect
var modal_rule_line: ColorRect
var page_boxes: Dictionary = {}
var nav_buttons: Dictionary = {}
## The map view the left navigation marks while no page is open: "planet" or "flat".
var map_mode: String = "planet"
var autosave_task: int = -1
var autosave_snapshot: Dictionary = {}


func _ready():
	Graphics.start_choice()
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
		visual_spin = bool(preferences.get_value("visual", "spin", true))
		visual_day_night = bool(preferences.get_value("visual", "day_night", true))
		visual_weather = bool(preferences.get_value("visual", "weather", true))
		visual_aa = str(preferences.get_value("visual", "aa", Graphics.AA_DEFAULT))
		plot_marks = bool(preferences.get_value("visual", "plot_marks", false))
	map.set_visual_options(visual_spin, visual_day_night, visual_weather)
	Graphics.apply_anti_aliasing(get_viewport(), visual_aa)
	map.set_plot_marks(plot_marks)
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
	brand.custom_minimum_size.x = 150
	D.label(brand, "殖民契约", 23, D.INK, false)
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
		action.custom_minimum_size = Vector2(62, 26)
		action.add_theme_font_size_override("font_size", 14)
		D.skin(action, "chip")
	_build_resource_table(h)
	var clockbox = D.col(h)
	date_label = D.label(clockbox, "", 17, D.GOLD, false)
	var controls = D.row(clockbox)
	var time_rules: Dictionary = sim.progression.time
	for item in [
		["暂停", 0],
		["1×", 1],
		["%d×" % int(time_rules.fast_multiplier), int(time_rules.fast_multiplier)],
		["%d×" % int(time_rules.very_fast_multiplier), int(time_rules.very_fast_multiplier)],
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
	D.label(v, "指 挥 中 枢", D.CAPTION, D.MUTED, false)
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
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_buttons[key] = nav_button
	_mark_nav()
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
	var foot = D.row(bottom)
	var mission_title = D.label(foot, "任务\n链路", 14, D.TEAL, false)
	mission = D.label(foot, "", 17)
	mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var guide_button = D.button(foot, "行动指南", func(): open_page("guide"))
	guide_button.custom_minimum_size.y = 30
	D.skin(guide_button, "chip")
	var collapse = Button.new()
	collapse.text = "收起"
	D.skin(collapse, "chip")
	foot.add_child(collapse)
	collapse.pressed.connect(
		func():
			mission.visible = not mission.visible
			mission_title.visible = mission.visible
			collapse.text = "收起" if mission.visible else "展开任务"
			bottom.offset_top = -94 if mission.visible else -70
	)
	notices = VBoxContainer.new()
	notices.name = "Notices"
	notices.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notices.offset_left = -NOTICE_WIDTH / 2.0
	notices.offset_right = NOTICE_WIDTH / 2.0
	notices.offset_top = NOTICE_TOP
	notices.offset_bottom = NOTICE_TOP + NOTICE_LIMIT * 140
	notices.add_theme_constant_override("separation", 6)
	notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(notices)
	toast_label = D.label(ui, "", 18, D.GOLD)
	toast_label.anchor_top = 1
	toast_label.anchor_bottom = 1
	toast_label.offset_left = COLUMN_LEFT + COLUMN_WIDTH + 10
	toast_label.offset_right = 1200
	toast_label.offset_top = -145
	toast_label.offset_bottom = -100
	map_hint = D.label(ui, "球面总览  ·  右键旋转  ·  滚轮缩放", 14, D.MUTED, false)
	map_hint.name = "MapHint"
	map_hint.position = Vector2(COLUMN_LEFT + COLUMN_WIDTH + 10, 96)
	_build_gauge()
	_build_column()
	refresh()


## Colony totals with their change over a month, one small cell each: icons where there are icons.
func _build_resource_table(parent: Control) -> void:
	top_stats = GridContainer.new()
	top_stats.name = "TopStats"
	top_stats.columns = 6
	top_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_stats.add_theme_constant_override("h_separation", 10)
	top_stats.add_theme_constant_override("v_separation", 6)
	parent.add_child(top_stats)
	for row: Array in TOP_CELLS:
		var cell := HBoxContainer.new()
		cell.name = "Top_" + str(row[0])
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_stats.add_child(cell)
		if ResourceLoader.exists("res://assets/icons/%s.svg" % str(row[1])):
			var mark: TextureRect = D.icon(cell, str(row[1]), 20)
			# Iron, copper and crystal in their map colours, so the three read apart.
			mark.self_modulate = Labels.GOOD_COLORS.get(str(row[0]), Color.WHITE)
		else:
			D.label(cell, str(row[1]), 15, D.GOLD, false)
		var value: Label = D.label(cell, "", 16, D.INK, false)
		var delta: Label = D.label(cell, "", 13, D.TEAL, false)
		top_cells[str(row[0])] = {"cell": cell, "value": value, "delta": delta}


func _build_gauge() -> void:
	gauge = DistrustGauge.new()
	gauge.setup(self)
	ui.add_child(gauge)
	gauge.anchor_left = 1
	gauge.anchor_right = 1
	gauge.offset_left = -440
	gauge.offset_right = -372
	gauge.offset_top = 115


## The selected settlement's buildings in a column of their own, beside the navigation.
func _build_column() -> void:
	column_panel = PanelContainer.new()
	column_panel.name = "BuildingColumn"
	ui.add_child(column_panel)
	column_panel.anchor_bottom = 1
	column_panel.offset_left = COLUMN_LEFT
	column_panel.offset_right = COLUMN_LEFT + COLUMN_WIDTH
	column_panel.offset_top = 115
	column_panel.offset_bottom = -116
	# The settlement's facilities belong to construction and production: the industrial variant.
	D.panel_style(column_panel, "panel", D.INDUSTRY)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column_panel.add_child(scroll)
	column_box = D.col(scroll)
	column_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column_box.add_theme_constant_override("separation", 6)
	column_tab = D.button(ui, "设施 ▸", set_column_open.bind(true), "展开设施栏", "ColumnTab")
	column_tab.position = Vector2(COLUMN_LEFT, 115)
	column_tab.custom_minimum_size = Vector2(70, 32)
	D.font_size(column_tab, 14)


func set_column_open(open: bool) -> void:
	column_open = open
	refresh_sidebar()


func _process(delta):
	session_seconds += delta
	_finish_autosave(true)
	if sample_frames.size() < 36000:
		sample_frames.append(delta)
	advance_time(delta)
	_feed_map_clock()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.text = ""
	_watch_research()
	_watch_events()


## A technology finished since the last frame gets a notice; a new or loaded game only sets the
## mark, so old work never floods the screen.
func _watch_research() -> void:
	var research: Dictionary = sim.state.get("research", {})
	var done: Array = research.get("completed", [])
	if not is_same(research, research_watch) or done.size() < research_seen:
		research_watch = research
		research_seen = done.size()
		return
	while research_seen < done.size():
		notice_research(str(done[research_seen]))
		research_seen += 1


## 「科研完成：某某」 under the top bar, with what it does; a click opens the research page.
func notice_research(tech: String) -> void:
	var spec: Dictionary = sim.config.techs.get(tech, {})
	if spec.is_empty() or notices == null:
		return
	var gift: bool = bool(spec.get("gift", false))
	_post_notice(
		"Notice_" + tech,
		D.RESEARCH,
		"◆ 获得赠予科技" if gift else "◆ 科研完成",
		str(spec.name),
		[str(spec.get("description", ""))],
		"research",
		NOTICE_SECONDS
	)


## An event that ended since the last frame gets its ending scene; a new or loaded game only sets
## the mark, so old endings never flood the screen.
func _watch_events() -> void:
	var e: Dictionary = sim.state.get("events_v2", {})
	var rows: Array = e.get("history", [])
	var newest: String = str(rows.back().get("instance_id", "")) if not rows.is_empty() else ""
	if not is_same(e, event_watch):
		event_watch = e
		event_seen = newest
		return
	if newest == event_seen:
		return
	var start: int = rows.size() - 1
	for index: int in range(rows.size() - 1, -1, -1):
		if str(rows[index].get("instance_id", "")) == event_seen:
			start = index + 1
			break
	for index: int in range(start, rows.size()):
		notice_event(rows[index])
	event_seen = newest


## The ending scene of an event: its title, the ending, and what happened (the event's own words,
## or else what changed); a click opens the events page.
func notice_event(row: Dictionary) -> void:
	var definition: Dictionary = Events.definitions().definitions.get(
		str(row.get("definition_id", "")), {}
	)
	if definition.is_empty() or notices == null:
		return
	var scene: String = str(row.get("outcome", ""))
	var lines: Array[String] = ["结局「%s」" % str(row.get("ending", ""))]
	if scene != "":
		lines.append(scene)
	elif str(row.get("changes", "")) != "":
		lines.append(str(row.changes))
	_post_notice(
		"EventEnding_" + str(row.get("instance_id", "")),
		D.NEUTRAL,
		"◆ 到期按默认处理" if bool(row.get("automatic", false)) else "◆ 事件结局",
		str(definition.nodes.start.title),
		lines,
		"events",
		EVENT_NOTICE_SECONDS
	)


## A card under the top bar: a small heading, a title and lines of text; a click opens `page`.
## Up to NOTICE_LIMIT at once, each gone after `seconds`.
func _post_notice(
	card_name: String,
	variant: String,
	heading: String,
	title_text: String,
	lines: Array[String],
	page: String,
	seconds: float
) -> void:
	var panel := PanelContainer.new()
	panel.name = card_name
	panel.add_theme_stylebox_override("panel", D.style("card_on", variant))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = PAGE_TOOLTIPS.get(page, "")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := Label.new()
	head.text = heading
	head.add_theme_color_override("font_color", D.GOLD)
	head.add_theme_font_size_override("font_size", 15)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	var labels: Array[Label] = [head, title]
	for line: String in lines:
		var body := Label.new()
		body.text = line
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override("font_color", D.MUTED)
		body.add_theme_font_size_override("font_size", 15)
		labels.append(body)
	for label: Label in labels:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	panel.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				open_page(page)
				panel.queue_free()
	)
	notices.add_child(panel)
	# Above whatever page or dialog is open.
	notices.get_parent().move_child(notices, -1)
	while notices.get_child_count() > NOTICE_LIMIT:
		var oldest: Node = notices.get_child(0)
		notices.remove_child(oldest)
		oldest.queue_free()
	get_tree().create_timer(seconds, true).timeout.connect(
		func():
			if is_instance_valid(panel):
				panel.queue_free()
	)


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
		var every: int = int(sim.progression.time.get("autosave_days", AUTOSAVE_FALLBACK_DAYS))
		if int(sim.state.day) % maxi(1, every) == 0 and int(sim.state.day) != autosave_day:
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


## The map's visual clock follows the game clock: faster at higher speeds, slow while paused.
func _feed_map_clock() -> void:
	var running: bool = not (
		paused or menu_open or panel_blocks_time() or sim.state.status in ["planning", "failed"]
	)
	var seconds_per_day: float = float(sim.progression.get("time", {}).get("seconds_per_day", 5.0))
	map.set_clock(running, speed, int(sim.state.day), accumulator / maxf(seconds_per_day, 0.01))


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
		naming_kind = "residential" if sim.state.settlements.is_empty() else "frontier"
		var refusal: String = sim.settle_refusal(selected, naming_kind)
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
		error = act("settle", {"site": naming_site, "name": edit.text, "kind": naming_kind})
	if error == "":
		close_modal()
		refresh_sidebar()


## The shortcut from a shortage line: the right page, on the right part of it.
func open_fix(fix: Dictionary):
	if fix.has("category"):
		build_category = str(fix.category)
	if fix.has("kind"):
		build_selected = str(fix.kind)
	open_page(str(fix.page))


func navigate(page: String):
	if page == "planet":
		local_view = false
		map_mode = "planet"
		map.show_planet()
		map_hint.text = "球面总览  ·  右键旋转  ·  滚轮缩放"
		refresh_sidebar()
	elif page == "flat":
		local_view = false
		map_mode = "flat"
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
		return
	_mark_nav()


func settlement() -> Dictionary:
	for s in sim.state.settlements:
		if int(s.region) == selected:
			return s
	return {}


func refresh():
	if not is_instance_valid(top_stats):
		return
	var window: Dictionary = _refresh_top()
	var state: Dictionary = sim.state
	date_label.text = (
		"%s · %s" % [Labels.date(int(state.day)), "已暂停" if paused else str(speed) + " 倍速"]
	)
	date_label.tooltip_text = "登陆第 %d 日 · 生涯第 %d 日" % [state.day, state.career.global_day]
	var company: Dictionary = state.get("company", {})
	var level: Dictionary = sim.progression.difficulty[state.get("difficulty", "normal")]
	gauge.show_state(
		company,
		float(level.warning),
		float(sim.progression.company.review_threshold),
		float(sim.progression.company.intervention_threshold)
	)
	var steps = ["立足 → 分工 → 网络 → 自立 → 首府：一步步把据点变成能自立的殖民地，赢得总督资格"]
	var hint = "在地图上选一个地点，右侧卡片告诉你它适合做什么。"
	if state.status != "planning":
		var phase = {"active": "契约考核中", "success": "总督阶段", "failed": "经营终止"}
		hint = phase.get(state.status, state.status)
		if state.settlements.size() < 2:
			hint += "  |  矿山负责出口，肥沃的土地负责粮食。"
		elif state.roads.is_empty():
			hint += "  |  据点尚未相连，打开交通运输修路或开航线。"
		else:
			hint += "  |  贸易和运输按本地库存自动进行。"
		var advice: String = _money_advice(window)
		if advice != "":
			hint = advice
		if not sim.Research.idle_categories(sim).is_empty():
			hint = "! 有研究团队闲着：打开科研教育，给他们挑一个课题"
	if not state.get("event", {}).is_empty():
		hint = "! 待处理通讯：" + str(state.event.get("title", "事件")) + "  ·  打开左侧通讯事件"
	mission.text = steps[0] + "\n" + hint
	_mark_nav()
	refresh_sidebar()


## The advisor on money: export income from mines about to run out first, then a market sold
## down to its floor, then cash with nothing to do.
func _money_advice(window: Dictionary) -> String:
	var outlook: Dictionary = sim.mine_outlook(window)
	if float(outlook.share) >= float(sim.config.economy.mine_warning_share):
		return "! " + Labels.mine_warning(outlook, true)
	for row: Dictionary in sim.market_view():
		var flows: Array = window.goods.get(str(row.good), [])
		if bool(row.at_floor) and not flows.is_empty() and float(flows[Stats.EXPORTED]) > 0.0:
			return (
				"! %s市场已饱和：再多卖只能按底价结算，打开经营账本看行情"
				% str(Labels.RESOURCE_NAMES.get(str(row.good), row.good))
			)
	var cover: Dictionary = sim.cover_view()
	if str(cover.band) == Keys.COVER_IDLE and float(cover.expense) >= 1.0:
		return "现金可支撑 %.0f 天，%s" % [float(cover.cover), Labels.idle_money(sim)]
	return ""


## Colony totals and what the last month did to them, scaled up while the colony is younger than that.
## Returns the month's window for the advisor.
func _refresh_top() -> Dictionary:
	var state: Dictionary = sim.state
	var window: Dictionary = sim.stats_window(int(MONTH_DAYS))
	# The figure after each amount is its change a day: the mean of the last week's days.
	var week: Dictionary = sim.stats_window(DAILY_WINDOW)
	var per_day: float = 1.0 / maxi(1, int(week.days))
	var income: float = 0.0
	var expense: float = 0.0
	for key: String in window.income:
		income += float(window.income[key])
	for key: String in window.expense:
		expense += float(window.expense[key])
	var cover_line: String = Labels.cover_text(sim.cover_view())
	var net_per_day: float = float(sim.summary().operating_average)
	_set_cell(
		"money",
		float(state.cash),
		net_per_day,
		(
			(
				"公共资金 ¥ %.0f\n后面的数字是每日经营结余（近 7 日平均）¥ %+.0f/日。\n近 30 日经营收入 ¥ %.0f，支出 ¥ %.0f；建设和融资不计入。"
				% [float(state.cash), net_per_day, income, expense]
			)
			+ ("" if cover_line == "" else "\n" + cover_line)
		)
	)
	var people: int = 0
	var employed: int = 0
	var children: int = 0
	var power: float = 0.0
	var power_used: float = 0.0
	var water: float = 0.0
	var water_used: float = 0.0
	var stock: Dictionary = {}
	var places: PackedStringArray = []
	for s: Dictionary in state.settlements:
		people += int(s.population)
		employed += int(s.get("employed", 0))
		children += int(s.get("children", 0))
		power += float(s.power_supply)
		power_used += float(s.power_demand)
		water += float(s.water_supply)
		water_used += float(s.water_demand)
		places.append(
			(
				"%s：电 %.0f/%.0f · 水 %.0f/%.0f"
				% [s.name, s.power_supply, s.power_demand, s.water_supply, s.water_demand]
			)
		)
		for good: String in TOP_GOODS:
			stock[good] = float(stock.get(good, 0.0)) + float(s.stock.get(good, 0.0))
	var labour: int = Stats.labour(state)
	_set_cell(
		"labour",
		labour,
		Stats.labour_change(state, DAILY_WINDOW),
		(
			"劳动力 %d：工程队和研究团队\n人口 %d · 就业 %d · 未成年 %d\n后面的数字是每日变化（近 7 日平均）。"
			% [labour, people, employed, children]
		)
	)
	_set_cell_text(
		"places",
		"%d / %d" % [state.settlements.size(), Contract.settlement_cap(sim)],
		"",
		0.0,
		"已建立的据点 / 合同许可的上限"
	)
	var utility_note: String = "\n电和水不能储存：第一个数是全部据点的供给，后面是供给减需求。\n"
	_set_cell_flow("power", power, power - power_used, "电力" + utility_note + "\n".join(places))
	_set_cell_flow("water", water, water - water_used, "水" + utility_note + "\n".join(places))
	for good: String in TOP_GOODS:
		var flows: Array = week.goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
		var change: float = (
			float(flows[Stats.PRODUCED])
			+ float(flows[Stats.IMPORTED])
			- float(flows[Stats.CONSUMED])
			- float(flows[Stats.EXPORTED])
		)
		var month: Array = window.goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
		_set_cell(
			good,
			Labels.tonnes(float(stock.get(good, 0.0))),
			Labels.tonnes(change * per_day),
			(
				Labels.flow_text(
					str(Labels.RESOURCE_NAMES[good]), float(stock.get(good, 0.0)), month
				)
				+ "\n后面的数字是每日变化（近 7 日平均，吨）。"
			)
		)
	return window


func _set_cell(key: String, value: float, change: float, hint: String) -> void:
	var sign_text: String = "+" if change >= 0.0 else ""
	_set_cell_text(
		key, Labels.amount_text(value), sign_text + Labels.amount_text(change), change, hint
	)


## Power and water: a rate, not a stock, so the sign is the surplus and red means somebody is short.
func _set_cell_flow(key: String, supply: float, surplus: float, hint: String) -> void:
	var sign_text: String = "+" if surplus >= 0.0 else ""
	_set_cell_text(key, Labels.compact(supply), sign_text + Labels.compact(surplus), surplus, hint)


func _set_cell_text(
	key: String, value: String, change: String, amount: float, hint: String
) -> void:
	var cell: Dictionary = top_cells[key]
	if cell.value.text != value:
		cell.value.text = value
	if cell.delta.text != change:
		cell.delta.text = change
		cell.delta.add_theme_color_override("font_color", D.TEAL if amount >= 0.0 else D.RED)
	cell.cell.tooltip_text = hint


func refresh_sidebar():
	if not is_instance_valid(sidebar):
		return
	D.begin(sidebar)
	Pages.region(self, sidebar)
	D.finish(sidebar)
	D.begin(sidebar_actions)
	Pages.region_actions(self, sidebar_actions)
	D.finish(sidebar_actions)
	var settled: bool = not settlement().is_empty()
	column_panel.visible = settled and column_open
	column_tab.visible = settled and not column_open
	if column_panel.visible:
		var previous: String = D.variant()
		D.use(D.INDUSTRY)
		D.begin(column_box)
		Pages.building_column(self, column_box)
		D.finish(column_box)
		D.use(previous)


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
	outer.add_theme_constant_override("separation", 10)
	var head = D.row(outer)
	modal_title = D.label(head, "", 26, D.INK, false)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	modal_close = D.button(head, "关闭  ×", close_modal, "关闭面板（Esc）", "ModalClose")
	# Under the title: a short accent stroke on a fine line, the frame's one geometric detail.
	var rule = D.row(outer)
	rule.add_theme_constant_override("separation", 0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_rule_accent = D.rule(rule, D.TEAL, 2)
	modal_rule_accent.custom_minimum_size.x = 72
	modal_rule_accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	modal_rule_line = D.rule(rule)
	modal_rule_line.size_flags_vertical = Control.SIZE_SHRINK_END
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
		scroll.add_theme_stylebox_override("panel", D.style("scroll_area", D.NEUTRAL))
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
	if WIDE_PAGES.has(key):
		width = maxi(width, WIDE_MODAL)
	# Never wider than the window at the chosen text size.
	width = mini(width, int(ui.get_viewport_rect().size.x) - 40)
	modal_panel.custom_minimum_size = Vector2(width, MODAL_HEIGHT)
	_style_modal(page_variant(key))
	modal_title.text = title
	modal_close.visible = closable
	modal_footer.text = (
		"" if not closable else ("已暂停，可从容决策；关闭后恢复原速度。" if panel_pause else "面板打开时时间继续流逝。")
	)
	modal_feedback = modal_footer
	modal_box = _page_box(key)
	if is_instance_valid(coach) and coach.visible:
		coach.keep_on_top()
	if panel_pause:
		if not paused:
			resume_on_close = true
		paused = true
		accumulator = 0
	refresh()
	return modal_box


## The modal frame in a page's variant: panel, title, close button, rule and footer.
func _style_modal(variant: String) -> void:
	D.panel_style(modal_panel, "modal", variant)
	modal_title.add_theme_color_override("font_color", D.tone("text", variant))
	D.skin(modal_close, "plain", variant)
	modal_rule_accent.color = D.tone("primary", variant)
	modal_rule_line.color = D.tone("line", variant)
	modal_footer.add_theme_color_override("font_color", D.tone("gold", variant))


func page_variant(page: String) -> String:
	return str(PAGE_VARIANTS.get(page, D.NEUTRAL))


## The left navigation marks the open page, or the map view when no page is open.
func _mark_nav() -> void:
	var active: String = map_mode
	if local_view:
		active = "region"
	if is_instance_valid(overlay) and nav_buttons.has(current_page):
		active = current_page
	for key: String in nav_buttons:
		D.skin(nav_buttons[key], "row_on" if key == active else "row", D.NEUTRAL)


func populate_current_page():
	if not is_instance_valid(overlay) or current_page.is_empty():
		return
	var previous: String = D.variant()
	D.use(page_variant(current_page))
	D.begin(modal_box)
	if current_page in ["research", "company", "events", "career", "manage"]:
		ProgressionPages.populate(self, modal_box, current_page)
	else:
		Pages.populate(self, modal_box, current_page)
	D.finish(modal_box)
	D.use(previous)


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
	_mark_nav()
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
	size_option = D.option(r, "SizeOption", ["小型 · 0.6 地球半径", "中型 · 1.0 地球半径", "大型 · 1.3 地球半径"], 1)
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
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# A choice among several: the selected one shows the chosen style and keeps its text.
		D.skin(b, "chip")
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
	D.button(v, "新建殖民远征  →", start_game, "", "NewGame", "primary")
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
## A forecast: a draw that gives no playable world softens, which only building the world can tell.
func _show_planet_preview():
	if tutorial_on:
		planet_preview.text = "新手引导使用专用星球。想自己选种子、大小、难度和开局，先把引导关掉，或点「换个种子」。"
		return
	var rules: Dictionary = sim.progression_geo()
	var character: Dictionary = WorldGen.Plates.character(
		WorldGen.SeedGeo.normalize_seed(seed_edit.text), rules
	)
	planet_preview.text = "这个种子多半是：" + Labels.planet_type(rules.planet_types, character)


func old_save_path(relative: String) -> String:
	return OS.get_environment("APPDATA") + relative


## The newer of the manual and automatic saves; a 1.8, 1.7 or 1.6 save if this version has none
## yet. Older versions' files are only read: saving writes to this version's own folder.
func _latest_save() -> String:
	var best: String = _newest_of([SAVE_MANUAL, SAVE_AUTO])
	if best == "":
		best = _newest_of([old_save_path(V18_SAVE_MANUAL), old_save_path(V18_SAVE_AUTO)])
	if best == "":
		best = _newest_of([old_save_path(V17_SAVE_MANUAL), old_save_path(V17_SAVE_AUTO)])
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
	build_selected = ""
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


## key is "spin", "day_night" or "weather".
func toggle_visual(key: String) -> void:
	match key:
		"spin":
			visual_spin = not visual_spin
		"day_night":
			visual_day_night = not visual_day_night
		"weather":
			visual_weather = not visual_weather
	map.set_visual_options(visual_spin, visual_day_night, visual_weather)
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("visual", "spin", visual_spin)
	settings.set_value("visual", "day_night", visual_day_night)
	settings.set_value("visual", "weather", visual_weather)
	settings.save("user://settings.cfg")
	open_page("save")


## level is one of Graphics.AA_LEVELS; it applies at once.
func set_anti_aliasing(level: String) -> void:
	visual_aa = level
	Graphics.apply_anti_aliasing(get_viewport(), level)
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("visual", "aa", level)
	settings.save("user://settings.cfg")
	open_page("save")


func toggle_plot_marks() -> void:
	plot_marks = not plot_marks
	map.set_plot_marks(plot_marks)
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("visual", "plot_marks", plot_marks)
	settings.save("user://settings.cfg")
	open_page("save")


## Picture quality for the next start (Graphics.STANDARD or Graphics.HIGH).
func choose_renderer(method: String) -> void:
	Graphics.choose(method)
	open_page("save")


## Starts the game again with the same arguments, so a new picture quality takes effect.
func restart_game() -> void:
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


func toggle_information():
	detailed_info = not detailed_info
	var settings = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("display", "details", detailed_info)
	settings.save("user://settings.cfg")
	open_page("save")
