extends RefCounted
## The construction page (地区工程 / 建设与生产), drawn in the industrial variant.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const CrewPanel = preload("res://ui/crew_panel.gd")
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
	CrewPanel.strip(g, b, s)
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
	D.stat(strip, "空闲职工", str(g.sim.free_workers(s)), D.INK, "还没有岗位的职工：每座设施运转时雇用职工")
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


## The order screen (1.11): four answers before payment — cash that leaves now, when a crew can begin,
## when the facility enters service, what it is likely to add here — then the orders.
static func _build_ledger(
	g, parent, s: Dictionary, key: String, spec: Dictionary, forecast: Dictionary, plot: int
) -> void:
	var column: VBoxContainer = D.col(parent)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	var rows: VBoxContainer = D.scroll(column, "BuildLedger")
	rows.add_theme_constant_override("separation", 4)
	var order: Dictionary = g.sim.checkout(int(s.region), key, plot)
	if order.is_empty():
		return
	_cash_answer(g, rows, s, order)
	_crew_answer(g, rows, order)
	_service_answer(g, rows, order, forecast)
	_benefit_answer(g, rows, order, forecast)
	if float(forecast.reserve_days) >= 0.0:
		D.pair(rows, "储量", "够挖 %.0f 日" % float(forecast.reserve_days), D.INK)
	var food: Dictionary = forecast.get("food", {})
	if not food.is_empty():
		_food_lines(rows, food, float(forecast.get("usable", {}).get("food", 0.0)))
	var refusal: String = str(forecast.disabled_reason)
	var verdict: Label = D.label(
		column,
		"×  " + refusal if refusal != "" else "✓  可以下达：现在付 ¥ %s" % g.money(float(order.cash_now)),
		D.SMALL,
		D.RED if refusal != "" else D.TEAL
	)
	verdict.name = "BuildVerdict"
	var actions: HBoxContainer = D.row(column)
	var region: int = int(s.region)
	var held: bool = false
	for entry: Dictionary in s.get("reservations", []):
		held = held or str(entry.kind) == key
	var hold: Button = D.button(
		actions,
		"已为它预留物资" if held else "为它预留建材和部件",
		func(): g.act("reserve_for", {"region": region, "kind": key}),
		"一步把这项工程要用的建材和部件留在仓库：不再出口、不外调，直到下令建设或在库存页取消",
		"ReserveFor_" + key
	)
	hold.disabled = held
	D.font_size(hold, D.SMALL)
	var place: Button = D.button(
		actions,
		"建设%s · ¥ %s" % [str(spec.get("name", key)), g.money(float(order.cash_now))],
		func(): g.act("build", {"site": g.selected, "kind": key, "plot": plot}),
		refusal,
		"BuildSelected",
		"primary"
	)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place.custom_minimum_size.y = 48
	place.disabled = refusal != ""
	place.clip_text = true


## 1. Cash that leaves now: the price, a mine road with it, and what is bought in for the warehouse.
static func _cash_answer(g, rows: Control, s: Dictionary, order: Dictionary) -> void:
	var cash: float = float(g.sim.state.cash)
	D.heading(rows, "① 现在付出")
	var total: HBoxContainer = D.pair(
		rows,
		"合计",
		"¥ " + g.money(float(order.cash_now)),
		D.GOLD,
		"持有 ¥ " + g.money(cash),
		D.MUTED if cash >= float(order.cash_now) else D.RED,
		"money"
	)
	D.named(total, "CheckoutCash")
	var parts: PackedStringArray = ["建设款 ¥ %s" % g.money(float(order.construction))]
	if float(order.road) > 0.0:
		parts[0] += "（含矿区道路 ¥ %s）" % g.money(float(order.road))
	if float(order.bought) > 0.0:
		parts.append(
			(
				"现买缺料 ¥ %s：建材 %s、部件 %s，按进口价"
				% [
					g.money(float(order.bought)),
					Labels.t(float(order.short.materials)),
					Labels.t(float(order.short.parts))
				]
			)
		)
	D.label(rows, " + ".join(parts), D.CAPTION, D.MUTED)
	D.label(
		rows,
		(
			"另用本地库存：建材 %s · 部件 %s（库存 %s / %s）"
			% [
				Labels.t(float(order.local_materials)),
				Labels.t(float(order.local_parts)),
				Labels.t(float(s.stock.materials)),
				Labels.t(float(s.stock.parts))
			]
		),
		D.CAPTION,
		D.MUTED
	)


## 2. When a crew can begin: which crew, its place in that crew's line, and the day.
static func _crew_answer(g, rows: Control, order: Dictionary) -> void:
	var crew: Dictionary = order.crew
	D.heading(rows, "② 工程队开工")
	var words: String = ""
	if int(crew.start) < 0:
		words = "本地没有工程队，也没有在路上的"
		var send: Dictionary = crew.get("send", {})
		if not send.is_empty():
			words += (
				"：可从「%s」派 #%d（路上 %d 天%s）"
				% [
					str(send.from),
					int(send.crew),
					int(send.days),
					"，手头工程还要 %d 天" % int(send.busy) if int(send.busy) > 0 else ""
				]
			)
		var rule: Dictionary = g.sim.pop_rules.get("crews", {})
		words += (
			"；或在本地培训一支（¥ %.0f · %d 天）"
			% [float(rule.get("train_cost", 0)), int(rule.get("train_days", 0))]
		)
		var none: Label = D.label(rows, words, D.SMALL, D.RED)
		D.named(none, "CheckoutCrew")
		return
	var state: String = {"": "现在空闲", "build": "正在施工", "train": "培训中", "travel": "正在赶来"}.get(
		str(crew.crew_state), ""
	)
	if str(crew.crew_state) in ["train", "travel"] and crew.has("crew_until"):
		state += "，%s 可开工" % Labels.short_date(int(crew.crew_until))
	words = (
		"工程队 #%d（%s）· 排第 %d 位 · 约 %s 开工"
		% [int(crew.crew), state, int(crew.place), Labels.short_date(int(crew.start))]
	)
	if bool(crew.get("urgent", false)):
		words += " · 能解决本地短缺，排在其他工程之前"
	var line: Label = D.label(rows, words, D.SMALL, D.INK)
	D.named(line, "CheckoutCrew")
	for item: Dictionary in crew.get("ahead", []):
		D.label(
			rows,
			(
				"　先做：%s · %s → %s 完工"
				% [
					str(item.name),
					"在建" if bool(item.started) else Labels.short_date(int(item.start)) + " 开工",
					Labels.short_date(int(item.finish))
				]
			),
			D.CAPTION,
			D.MUTED
		)


## 3. When it enters service, and what may hold it back once built.
static func _service_answer(_g, rows: Control, order: Dictionary, forecast: Dictionary) -> void:
	D.heading(rows, "③ 投入使用")
	var service: int = int(order.in_service)
	var words: String = (
		(
			"约 %s（工期 %d 天，下单后第 %d 天）"
			% [Labels.short_date(service), int(order.days), service - int(order.today)]
		)
		if service >= 0
		else "要等工程队：见上"
	)
	var line: Label = D.label(rows, words, D.SMALL, D.INK)
	D.named(line, "CheckoutService")
	var jobs: int = int(forecast.jobs) + int(forecast.specialists)
	if jobs > 0:
		var free: int = int(forecast.free_workers)
		D.label(
			rows,
			"岗位 %d · 本地找工作的职工 %d%s" % [jobs, free, "" if free >= jobs else "：人手不够时按比例开工"],
			D.CAPTION,
			D.MUTED if free >= jobs else D.GOLD
		)
	if float(forecast.power) > 0.0 or float(forecast.water) > 0.0:
		D.label(
			rows,
			"用电 %.0f · 用水 %.0f" % [float(forecast.power), float(forecast.water)],
			D.CAPTION,
			D.MUTED
		)


## 4. What it is likely to add in this town.
static func _benefit_answer(g, rows: Control, order: Dictionary, _forecast: Dictionary) -> void:
	var benefit: Dictionary = order.benefit
	D.heading(rows, "④ 本地增益")
	if str(benefit.get("kind", "")) != "earning":
		_utility_lines(g, rows, benefit)
		return
	var low: float = float(benefit.net_low)
	var high: float = float(benefit.net_high)
	var net: HBoxContainer = D.pair(
		rows,
		"现金流",
		"¥ %+.0f – %+.0f/日" % [low, high],
		D.TEAL if low >= 0.0 else (D.GOLD if high > 0.0 else D.RED),
		"近 %d 天数据 · 误差 ±%.0f%%" % [int(benefit.history_days), float(benefit.band) * 100.0],
		D.MUTED,
		"money"
	)
	D.named(net, "CheckoutNet")
	if float(benefit.replaces_imports) > 0.0:
		D.label(
			rows, "　替代进口：¥ %.0f/日（少买的进口货）" % float(benefit.replaces_imports), D.CAPTION, D.MUTED
		)
	if float(benefit.export_receipts) > 0.0:
		D.label(
			rows, "　出口收入：¥ %.0f/日（计入合同出口目标）" % float(benefit.export_receipts), D.CAPTION, D.MUTED
		)
	for row: Dictionary in benefit.outputs:
		if str(row.get("basis", "")) == "market" and float(row.get("exported", 0.0)) > 0.0:
			(
				D
				. label(
					rows,
					(
						"　%s 出口 %s/天：现价 ¥ %.1f/百吨，多卖一个月后约 ¥ %.1f%s"
						% [
							str(RES.get(row.good, row.good)),
							Labels.t(float(row.exported)),
							float(row.price_now),
							float(row.price_after),
							(
								"；货运站没有余量，%s/天卖不出去" % Labels.t(float(row.port_limited))
								if float(row.get("port_limited", 0.0)) > 0.01
								else ""
							),
						]
					),
					D.CAPTION,
					D.MUTED
				)
			)
	for row: Dictionary in benefit.inputs:
		(
			D
			. label(
				rows,
				(
					"　原料 %s %s/天：本地还有余 %s/天%s"
					% [
						str(RES.get(row.good, row.good)),
						Labels.t(float(row.need)),
						Labels.t(float(row.spare)),
						(
							"，其中本来出口的部分少卖 ¥ %.1f/百吨" % float(row.forgone_price)
							if float(row.exported) > 0.0
							else ""
						),
					]
				),
				D.CAPTION,
				D.GOLD if float(row.share) < 1.0 else D.MUTED
			)
		)
	D.label(
		rows,
		"　工资 ¥ %.0f/日 · 维护 ¥ %.0f/日" % [float(benefit.wages), float(benefit.upkeep)],
		D.CAPTION,
		D.MUTED
	)
	var from_order: Dictionary = benefit.payback_order
	var from_start: Dictionary = benefit.payback_start
	var payback: Label = D.label(
		rows,
		(
			"回本：从下单日算约 %s（含等工和工期 %d 天）；从投产日算约 %s。投入 ¥ %s（含用掉的库存按售价计）"
			% [
				_days(from_order),
				int(benefit.wait_days),
				_days(from_start),
				g.money(float(benefit.outlay))
			]
		),
		D.SMALL,
		D.INK
	)
	D.named(payback, "CheckoutPayback")


static func _days(row: Dictionary) -> String:
	if int(row.low) < 0 and int(row.high) < 0:
		return "回不了本"
	if int(row.high) < 0:
		return "%d 天以上" % int(row.low)
	if int(row.low) == int(row.high):
		return "%d 天" % int(row.low)
	return "%d–%d 天" % [int(row.low), int(row.high)]


## A utility, a home or a laboratory: what it changes here.
static func _utility_lines(_g, rows: Control, benefit: Dictionary) -> void:
	var words: String = ""
	match str(benefit.get("role", "")):
		"power":
			words = (
				"本地电力 供给 %.0f / 需求 %.0f；建成后供给 +%.0f%s"
				% [
					float(benefit.supply),
					float(benefit.demand),
					float(benefit.adds),
					"，缺电的设施恢复满效" if float(benefit.supply) < float(benefit.demand) else "，留作增长余量"
				]
			)
		"water":
			words = (
				"本地供水 %.0f / 需求 %.0f；建成后 +%.0f%s"
				% [
					float(benefit.supply),
					float(benefit.demand),
					float(benefit.adds),
					"，缺水的设施恢复满效" if float(benefit.supply) < float(benefit.demand) else "，留作增长余量"
				]
			)
		"port":
			words = (
				"货运站运力 %.0f t/天，已用 %.0f t；建成后 +%.0f t/天%s"
				% [
					float(benefit.supply) * 100.0,
					float(benefit.demand) * 100.0,
					float(benefit.adds) * 100.0,
					(
						"：现在满载，多出的运力用来卖仓库里卖不出去的货"
						if float(benefit.supply) - float(benefit.demand) < 1.0
						else "：现在还有余量"
					)
				]
			)
		"housing":
			words = (
				"床位 %d / 居民 %d；建成后 +%d 张床：住房是移民的上限"
				% [int(benefit.supply), int(benefit.demand), int(benefit.adds)]
			)
		"lab":
			words = "研究座位 +%d" % int(benefit.get("adds", 0))
		_:
			words = "不直接产生现金"
	var line: Label = D.label(rows, words, D.SMALL, D.INK)
	D.named(line, "CheckoutBenefit")


## The plot the player picked for this kind if it is still free, otherwise the best one.
static func _chosen_plot(g, key: String, choices: Array) -> int:
	if choices.is_empty():
		return -1
	var wanted: int = int(g.build_plots.get(key, -1))
	for row: Dictionary in choices:
		if int(row.index) == wanted:
			return wanted
	return int(choices[0].index)


## Why a food building's crop is or is not all useful: what the town needs a day, what it already
## grows and lands, what is already being built, and what is left for the new one.
static func _food_lines(rows: Control, food: Dictionary, useful: float) -> void:
	var need: String = (
		"本地每日需要 %s（口粮 %s" % [Labels.per_day(float(food.need)), Labels.per_day(float(food.eaten))]
	)
	if float(food.foodworks) > 0.0:
		need += " · 食品厂 %s" % Labels.per_day(float(food.foodworks))
	if float(food.refill) > 0.0:
		need += " · 补足库存 %s" % Labels.per_day(float(food.refill))
	need += "）"
	var have: String = (
		"已有：农场 %s · 码头渔获 %s"
		% [Labels.per_day(float(food.grown)), Labels.per_day(float(food.caught))]
	)
	if float(food.queued) > 0.0:
		have += " · 在建 %s" % Labels.per_day(float(food.queued))
	var line: Label = D.label(rows, need, D.CAPTION, D.MUTED)
	D.named(line, "FoodNeed")
	D.label(rows, have, D.CAPTION, D.MUTED)
	var left: Label = D.label(
		rows,
		"还缺 %s，新设施能用上 %s" % [Labels.per_day(float(food.shortfall)), Labels.per_day(useful)],
		D.CAPTION,
		D.TEAL if useful > 0.0 else D.GOLD
	)
	D.named(left, "FoodUseful")
