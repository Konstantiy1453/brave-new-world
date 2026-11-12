extends RefCounted
## The construction page (地区工程 / 建设与生产), drawn in the industrial variant.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
## Each facility at work in its setting, baked from its model (tests/art/bake_facility_views.gd).
const FACILITY_VIEWS: String = "res://assets/art/facilities/"
const RES: Dictionary = Labels.RESOURCE_NAMES


## The construction page in three parts: the catalogue (filters and one row per facility that can
## be built here, each with a quick order button Build_<kind>), the chosen facility (a view of it in
## place, what it is, where it goes) and its ledger (what building it takes, what it costs to run,
## what it gives back) ending in the main order button. Every figure comes from the simulation's
## preview and forecast; the orders are the same "build" action as before.
static func build(g, b):
	var region: Dictionary = g.sim.state.world.regions[g.selected]
	var s: Dictionary = g.settlement()
	if s.is_empty():
		D.label(b, str(region.name) + " / 建设目录", D.TITLE, D.TEAL)
		D.label(b, "请先在这里建立据点。", 18, D.GOLD)
		return
	# The three columns fill the panel; each scrolls on its own.
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_header(g, b, s, region)
	var shown: Array[String] = []
	for key: String in _open_kinds(g, s):
		var category: String = str(g.sim.config.buildings[key].get("category", ""))
		if g.build_category == "all" or g.build_category == category:
			shown.append(key)
	var chosen: String = g.build_selected if shown.has(g.build_selected) else ""
	if chosen == "" and not shown.is_empty():
		chosen = shown[0]
	var columns: HBoxContainer = D.row(b)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_build_catalogue(g, columns, shown, chosen)
	if chosen == "":
		var empty: VBoxContainer = D.col(columns)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.label(empty, "这个分类里暂时没有可以在这里建设的设施。", D.BODY, D.MUTED)
		return
	var choices: Array = g.sim.plot_choices(g.selected, chosen)
	var plot: int = _chosen_plot(g, chosen, choices)
	var spec: Dictionary = g.sim.build_preview(g.selected, chosen)
	var forecast: Dictionary = g.sim.build_forecast(g.selected, chosen, plot)
	_build_facility(g, columns, chosen, spec, forecast, choices, plot)
	_build_ledger(g, columns, s, chosen, spec, forecast, plot)


## Every kind of facility this settlement can build, in catalogue order: by category, then as the
## rules list them. What the colony has not discovered, or this kind of settlement cannot hold,
## stays off the list.
static func _open_kinds(g, s: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for category: String in Labels.BUILD_CATEGORIES:
		for key: String in g.sim.config.buildings:
			var spec: Dictionary = g.sim.config.buildings[key]
			if str(spec.get("category", "")) != category:
				continue
			if (
				spec.has("requires_tech")
				and not g.sim.state.research.completed.has(spec.requires_tech)
			):
				continue
			if spec.has("site_kinds") and not spec.site_kinds.has(str(s.kind)):
				continue
			kinds.append(key)
	return kinds


## The settlement and what every order draws on: crews, cash and the local building stock.
static func _build_header(g, b, s: Dictionary, region: Dictionary) -> void:
	var strip: HBoxContainer = D.row(b)
	strip.add_theme_constant_override("separation", 26)
	var place: VBoxContainer = D.col(strip)
	place.add_theme_constant_override("separation", 0)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(place, str(Labels.SITE_KIND_NAMES.get(s.kind, "")), D.CAPTION, D.MUTED, false)
	D.label(place, str(region.name) + " / 建设目录", 22, D.INK, false)
	var supplies: String = "工程消耗本地仓库的建材和部件，缺的部分有货运站时按进口价现买。"
	D.stat(strip, "空闲工程队", str(g.sim.free_workers(s)), D.INK, "每项在建工程占用工程队，完工后释放")
	D.stat(strip, "公共资金", "¥ " + g.money(g.sim.state.cash), D.GOLD)
	D.stat(strip, "建材库存", Labels.t(float(s.stock.materials)), D.INK, supplies)
	D.stat(strip, "部件库存", Labels.t(float(s.stock.parts)), D.INK, supplies)


static func _build_catalogue(g, parent, shown: Array[String], chosen: String) -> void:
	var column: VBoxContainer = D.col(parent)
	column.custom_minimum_size.x = 400
	column.add_theme_constant_override("separation", 8)
	D.heading(column, "设施目录 · %d 项" % shown.size())
	var filters: HFlowContainer = D.flow(column)
	_category_button(g, filters, "all", "全部")
	for key: String in Labels.BUILD_CATEGORIES:
		_category_button(g, filters, key, str(Labels.BUILD_CATEGORIES[key]))
	var list: VBoxContainer = D.scroll(column, "BuildCatalogue")
	list.add_theme_constant_override("separation", 6)
	var last_category: String = ""
	for key: String in shown:
		var category: String = str(g.sim.config.buildings[key].get("category", ""))
		if g.build_category == "all" and category != last_category:
			D.label(list, str(Labels.BUILD_CATEGORIES[category]), D.CAPTION, D.TEAL, false)
			last_category = category
		_catalogue_row(g, list, key, key == chosen)


static func _category_button(g, parent, key: String, text: String):
	var on: bool = g.build_category == key
	var button: Button = D.button(
		parent,
		text,
		func():
			g.build_category = key
			g.populate_current_page(),
		"",
		"Cat_" + key,
		"chip_on" if on else "chip"
	)
	D.font_size(button, D.SMALL)
	button.custom_minimum_size.y = 32


## One facility in the catalogue: the row picks it, the small button orders it on its best plot.
static func _catalogue_row(g, list, key: String, on: bool) -> void:
	var spec: Dictionary = g.sim.build_preview(g.selected, key)
	var choices: Array = g.sim.plot_choices(g.selected, key)
	var plot: int = _chosen_plot(g, key, choices)
	var refusal: String = str(g.sim.build_forecast(g.selected, key, plot).disabled_reason)
	var line: HBoxContainer = D.row(D.card(list, "item_on" if on else "item"))
	line.add_theme_constant_override("separation", 6)
	var pick: Button = D.button(
		line,
		"",
		func():
			g.build_selected = key
			g.populate_current_page(),
		str(spec.description),
		"Pick_" + key,
		"row_on" if on else "row"
	)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.custom_minimum_size.y = 54
	pick.toggle_mode = false
	D.begin(pick)
	var inside: HBoxContainer = D.row(pick)
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8
	inside.offset_right = -6
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_theme_constant_override("separation", 10)
	var picture: TextureRect = D.building_icon(inside, key, Labels.icon_key(g.sim.config, key), 42)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words: VBoxContainer = D.col(inside)
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = D.label(words, str(spec.name), D.BODY, D.INK, false)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	var facts: Label = D.label(
		words, "¥ %s · %d 天" % [g.money(spec.cost), int(spec.days)], D.CAPTION, D.MUTED, false
	)
	facts.clip_text = true
	if refusal != "":
		D.tag(inside, "× 受限", D.RED)
	var order: Button = D.button(
		line,
		"建设",
		func(): g.act("build", {"site": g.selected, "kind": key, "plot": plot}),
		refusal if refusal != "" else "按当前地块直接下达建设",
		"Build_" + key
	)
	D.font_size(order, D.SMALL)
	order.custom_minimum_size = Vector2(64, 38)
	order.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	order.disabled = refusal != ""


## The chosen facility: a view of it at work, its category, what it is, where it would stand and
## what keeps it running.
static func _build_facility(
	g, parent, key: String, spec: Dictionary, forecast: Dictionary, choices: Array, plot: int
) -> void:
	var column: VBoxContainer = D.scroll(parent, "BuildFacility")
	var holder: ScrollContainer = column.get_parent()
	holder.size_flags_stretch_ratio = 1.18
	column.add_theme_constant_override("separation", 7)
	var view: String = FACILITY_VIEWS + key + ".webp"
	if ResourceLoader.exists(view):
		D.picture(column, view, Vector2(0, 190))
	else:
		D.building_icon(column, key, Labels.icon_key(g.sim.config, key), 128)
	var tags: HBoxContainer = D.row(column)
	tags.add_theme_constant_override("separation", 6)
	D.tag(tags, str(Labels.BUILD_CATEGORIES.get(str(spec.get("category", "")), "")), D.TEAL)
	if bool(spec.get("megaproject", false)):
		D.tag(tags, "巨型工程", D.GOLD)
	elif int(spec.get("copy_number", 1)) > 1:
		D.tag(tags, "第 %d 座" % int(spec.copy_number), D.MUTED)
	D.label(column, str(spec.name), 22, D.INK)
	D.label(column, str(spec.description), D.BODY - 1, D.MUTED)
	D.heading(column, "建设地块")
	if choices.size() > 1 and str(choices[0].kind) != "general":
		var names: Array = []
		var picked: int = 0
		for index: int in range(choices.size()):
			names.append(Labels.plot(choices[index]))
			if int(choices[index].index) == plot:
				picked = index
		D.option(
			column,
			"Plot_" + key,
			names,
			picked,
			func(id):
				g.build_plots[key] = int(choices[id].index)
				g.populate_current_page()
		)
		D.label(column, "可选 %d 块地，默认最好的一块。" % choices.size(), D.CAPTION, D.MUTED)
	elif choices.is_empty():
		D.label(column, "这里没有适合它的空地。", D.BODY, D.RED)
	else:
		D.label(column, Labels.plot(choices[0]), D.BODY, D.INK)
	D.heading(column, "运营需求")
	var running: GridContainer = D.grid(column, 2)
	running.add_theme_constant_override("h_separation", 18)
	running.add_theme_constant_override("v_separation", 4)
	D.pair(running, "电力", "%.0f" % float(forecast.power), D.INK, "", D.MUTED, "power")
	D.pair(running, "水", "%.0f" % float(forecast.water), D.INK, "", D.MUTED, "water")
	D.pair(running, "维护", "¥ %.1f/日" % float(forecast.maintenance), D.INK, "", D.MUTED, "upkeep")
	D.pair(running, "工资", "¥ %.0f/日" % float(forecast.wages_per_day), D.INK, "", D.MUTED, "crew")
	for good: String in spec.get("inputs", {}):
		D.pair(
			column,
			"消耗",
			"%s %s" % [RES.get(good, good), Labels.per_day(float(spec.inputs[good]))],
			D.INK
		)
	if float(spec.get("copy_surcharge", 0.0)) > 0.0:
		D.label(
			column,
			(
				"第 %d 座：资金 +%.0f%%（同类设施越多越贵）"
				% [int(spec.copy_number), float(spec.copy_surcharge) * 100.0]
			),
			D.SMALL,
			D.MUTED
		)
	if bool(spec.get("megaproject", false)):
		D.label(column, "巨型工程：每颗星球一座；本地缺少的工程物资按进口价随工程采购。", D.SMALL, D.TEAL)
	D.label(column, "工程消耗本地仓库的建材和部件，缺的部分有货运站时按进口价现买。", D.CAPTION, D.MUTED)


## What it takes to build and what it gives back, then the order itself.
static func _build_ledger(
	g, parent, s: Dictionary, key: String, spec: Dictionary, forecast: Dictionary, plot: int
) -> void:
	var column: VBoxContainer = D.col(parent)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	var rows: VBoxContainer = D.scroll(column, "BuildLedger")
	rows.add_theme_constant_override("separation", 4)
	var cash: float = float(g.sim.state.cash)
	D.heading(rows, "建设需求")
	D.pair(
		rows,
		"资金",
		"¥ " + g.money(forecast.cost),
		D.GOLD,
		"持有 ¥ " + g.money(cash),
		D.MUTED if cash >= float(forecast.cost) else D.RED,
		"money"
	)
	for good: String in ["materials", "parts"]:
		var need: float = float(forecast[good])
		var have: float = float(s.stock[good])
		D.pair(
			rows,
			str(RES[good]),
			Labels.t(need),
			D.INK,
			(
				"库存 " + Labels.t(have)
				if have >= need
				else "库存 %s · 缺 %s" % [Labels.t(have), Labels.t(need - have)]
			),
			D.MUTED if have >= need else D.GOLD,
			good
		)
	D.pair(rows, "工期", "%d 天" % int(forecast.days), D.INK, "", D.MUTED, "time")
	D.pair(
		rows,
		"岗位",
		"%d" % int(forecast.jobs),
		D.INK,
		"空闲工程队 %d" % int(forecast.free_workers),
		D.MUTED,
		"crew"
	)
	D.heading(rows, "预计产出")
	for good: String in forecast.outputs:
		D.pair(
			rows,
			"产出",
			"%s %s" % [RES.get(good, good), Labels.per_day(float(forecast.outputs[good]))],
			D.TEAL,
			"",
			D.MUTED,
			good
		)
	if float(forecast.revenue_per_day) != 0.0:
		D.pair(rows, "收入", "¥ %.0f/日" % float(forecast.revenue_per_day), D.INK)
	var net: float = float(forecast.net_per_day)
	D.pair(rows, "净额", "¥ %+.0f/日" % net, D.TEAL if net >= 0.0 else D.RED)
	var payback: float = float(forecast.payback_days)
	D.pair(
		rows,
		"回本",
		"约 %.0f 日" % payback if payback > 0.0 else "不产生净收入",
		D.INK if payback > 0.0 else D.MUTED
	)
	if float(forecast.reserve_days) >= 0.0:
		D.pair(rows, "储量", "够挖 %.0f 日" % float(forecast.reserve_days), D.INK)
	var refusal: String = str(forecast.disabled_reason)
	var verdict: Label = D.label(
		column,
		"×  " + refusal if refusal != "" else "✓  可以下达",
		D.SMALL,
		D.RED if refusal != "" else D.TEAL
	)
	verdict.name = "BuildVerdict"
	var order: Button = D.button(
		column,
		"下达建设 · %s" % str(spec.name),
		func(): g.act("build", {"site": g.selected, "kind": key, "plot": plot}),
		refusal,
		"BuildSelected",
		"primary"
	)
	order.custom_minimum_size.y = 48
	order.disabled = refusal != ""
	order.clip_text = true


## The plot the player picked for this kind if it is still free, otherwise the best one.
static func _chosen_plot(g, key: String, choices: Array) -> int:
	if choices.is_empty():
		return -1
	var wanted: int = int(g.build_plots.get(key, -1))
	for row: Dictionary in choices:
		if int(row.index) == wanted:
			return wanted
	return int(choices[0].index)
