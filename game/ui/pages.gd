extends RefCounted
const D = preload("res://ui/design.gd")
const WG = preload("res://world/world_gen.gd")
const Labels = preload("res://ui/labels.gd")
const Keys = preload("res://simulation/keys.gd")
const PROBLEM_STATUSES: Array[String] = [Keys.B_IDLE, Keys.B_DEPLETED, Keys.B_NO_INPUT]
const MONEY_ROWS: int = 8
const RES = {
	"ore": "铁矿",
	"copper": "铜矿",
	"crystal": "工业晶体",
	"food": "食品",
	"materials": "建材",
	"parts": "部件",
	"components": "电子元件"
}


static func region(g, b):
	var r: Dictionary = g.sim.state.world.regions[g.selected]
	D.label(b, "REGION  /  %02d" % (g.selected + 1), 13, D.TEAL)
	D.label(b, r.name, 27)
	D.label(b, "%s  ·  %.1f°C" % [r.terrain, r.temperature], 16, D.MUTED)
	var site_names: Array = []
	for reg in g.sim.state.world.regions:
		site_names.append(reg.name)
	var pickers = D.row(b)
	var chooser = D.option(
		pickers,
		"RegionChooser",
		site_names,
		g.selected,
		func(id):
			g.select_region(id)
			if g.local_view:
				g.map.show_region(id)
			else:
				g.map.focus_region(id)
	)
	var filter = _site_filter(g, pickers)
	for picker: OptionButton in [chooser, filter]:
		D.font_size(picker, 15)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.clip_text = true
		picker.custom_minimum_size = Vector2(60, 34)
	var known: Dictionary = g.sim.site_view(g.selected)
	var s: Dictionary = g.settlement()
	if s.is_empty():
		_site_card(g, b, known)
	else:
		_settlement_panel(g, b, s, known)


## The buttons under the sidebar's scrolling part, so the next action is always on screen.
static func region_actions(g, b):
	var known: Dictionary = g.sim.site_view(g.selected)
	if g.settlement().is_empty():
		_site_actions(g, b, known)
		return
	var line = D.row(b)
	for entry: Array in [
		["建设设施", func(): g.open_fix({"page": "build", "category": "all"}), "OpenBuild"],
		["批量库存", func(): g.open_page("manage"), "OpenManage"],
		["进入地区", func(): g.navigate("region"), "ViewRegion"],
	]:
		var action = D.button(line, str(entry[0]), entry[1], "", str(entry[2]))
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.clip_text = true
		D.font_size(action, 14)
		action.custom_minimum_size = Vector2(60, 38)


## An unsettled site: what it offers, what reaching it costs, and what it is good for.
static func _site_card(g, b, known: Dictionary):
	_site_facts(g, b, known)
	var hint: String = str(Labels.ROLE_HINTS.get(known.archetype, ""))
	if hint != "":
		D.label(b, hint, 16, D.INK)
	var links: Dictionary = g.sim.site_links(g.selected)
	if not links.is_empty():
		D.label(b, "从 %s 出发：" % links.name, 15, D.TEAL)
		for variant: String in ["valley", "engineered", "sea"]:
			var road: Dictionary = links.variants[variant]
			if bool(road.reachable):
				D.label(
					b,
					(
						"%s  %d 天 · ¥ %.0f"
						% [g.sim.config.roads[variant].name, int(road.days), float(road.cost)]
					),
					15,
					D.MUTED
				)


static func _site_actions(g, b, known: Dictionary):
	var line = D.row(b)
	var look = D.button(line, "查看地表", func(): g.navigate("region"), "", "ViewRegion")
	look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look.size_flags_stretch_ratio = 0.7
	D.font_size(look, 14)
	look.custom_minimum_size = Vector2(60, 38)
	_survey_button(g, line, known)
	var first: bool = g.sim.state.settlements.is_empty()
	D.button(
		b,
		"在此建立首府" if first else "派遣远征队建立据点",
		func(): g.act("settle", {"site": g.selected}),
		"首府需要这块陆地上还有其他地点；远征需要出发据点备齐人员和物资。",
		"SettleButton"
	)


## A settlement: key figures, then problems with a way to fix each, then its buildings.
static func _settlement_panel(g, b, s: Dictionary, known: Dictionary):
	D.label(
		b,
		(
			"人口 %d  ·  床位 %d\n就业 %d / 劳动力 %d  ·  研究员 %d  ·  未成年 %d"
			% [
				s.population,
				s.get("housing", 0),
				s.get("employed", 0),
				int(s.workers) + int(s.scientists),
				s.scientists,
				s.children
			]
		),
		16
	)
	D.label(b, "食品可吃 %.1f 天" % s.get("food_days", 0), 18, D.GOLD)
	D.label(
		b,
		(
			"电力 %.0f / %.0f  ·  供水 %.0f / %.0f（供给 / 需求）"
			% [
				s.get("power_supply", 0),
				s.get("power_demand", 0),
				s.get("water_supply", 0),
				s.get("water_demand", 0)
			]
		),
		15,
		D.MUTED
	)
	for shortage: Dictionary in s.get("shortages", []):
		var line = D.row(b)
		var text = D.label(line, "!  " + Labels.shortage(g.sim.config, shortage), 15, D.RED)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fix: Dictionary = Labels.fix(shortage)
		if not fix.is_empty():
			var action = D.button(
				line, str(fix.text), func(): g.open_fix(fix), "", "Fix_" + str(shortage.key)
			)
			D.font_size(action, 14)
			action.custom_minimum_size.y = 28
	_building_groups(g, b, s)
	D.label(b, "地块与矿藏", 14, D.TEAL)
	_site_facts(g, b, known)
	if g.sim.state.research.completed.has("prospecting"):
		_survey_button(g, b, known)


## One line per kind of building, those with problems first; individual controls on demand.
static func _building_groups(g, b, s: Dictionary):
	D.label(b, "设施", 14, D.TEAL)
	var groups: Dictionary = {}
	for index: int in range(s.buildings.size()):
		var item: Dictionary = s.buildings[index]
		var kind: String = str(item.kind)
		if not groups.has(kind):
			groups[kind] = {"kind": kind, "rows": [], "running": 0, "problems": 0, "first": index}
		groups[kind].rows.append(index)
		if bool(item.get("active", false)):
			groups[kind].running += 1
		elif str(item.get("status", "")) in PROBLEM_STATUSES:
			groups[kind].problems += 1
	var ordered: Array = groups.values()
	ordered.sort_custom(
		func(a: Dictionary, x: Dictionary) -> bool:
			if (int(a.problems) > 0) != (int(x.problems) > 0):
				return int(a.problems) > 0
			return int(a.first) < int(x.first)
	)
	for group: Dictionary in ordered:
		var kind: String = group.kind
		var open: bool = bool(g.expanded_kinds.get(kind, false))
		var line = D.row(b)
		var words: String = (
			"%s ×%d · 运营 %d"
			% [Labels.building_name(g.sim.config, kind), group.rows.size(), group.running]
		)
		if int(group.problems) > 0:
			words += " · 问题 %d" % int(group.problems)
		var caption = D.label(line, words, 15, D.RED if int(group.problems) > 0 else D.INK)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle = D.button(
			line,
			"收起" if open else "详情",
			func():
				g.expanded_kinds[kind] = not open
				g.refresh_sidebar(),
			"",
			"Group_" + kind
		)
		D.font_size(toggle, 14)
		toggle.custom_minimum_size.y = 28
		if open:
			for index: int in group.rows:
				_building_row(g, b, s, index)


static func _building_row(g, b, s: Dictionary, index: int):
	var item: Dictionary = s.buildings[index]
	var active: bool = bool(item.get("active", false))
	D.label(
		b,
		(
			"%s%s · %s"
			% [
				Labels.building_name(g.sim.config, item.kind),
				" %d 级" % int(item.level) if int(item.level) > 1 else "",
				"运营" if active else Labels.building_status(item)
			]
		),
		15,
		D.INK if active else D.MUTED
	)
	if item.get("owner", "public") != "public":
		return
	var bt = D.button(
		b,
		"暂停此设施" if item.get("enabled", true) else "恢复此设施",
		func(): g.act("toggle", {"region": g.selected, "index": index})
	)
	D.font_size(bt, 14)
	bt.custom_minimum_size.y = 30
	var preview: Dictionary = g.sim.toggle_preview(int(s.region), index)
	bt.tooltip_text = (
		"停用规则：不提供产能或住房。切换后住房 %s，住房缺口 %s"
		% [str(preview.get("housing_after", "—")), str(preview.get("housing_shortfall", "—"))]
	)
	var upgrade: Dictionary = g.sim.upgrade_preview(int(s.region), index)
	if not upgrade.is_empty() and g.sim.state.research.completed.has(upgrade.tech):
		var raise_level = D.button(
			b,
			"升级到 %d 级 · ¥ %.0f" % [int(upgrade.level), float(upgrade.cost)],
			func(): g.act("upgrade", {"region": g.selected, "index": index}),
			str(upgrade.disabled_reason)
		)
		D.font_size(raise_level, 14)
		raise_level.custom_minimum_size.y = 30
		raise_level.disabled = str(upgrade.disabled_reason) != ""


static func _site_filter(g, b) -> OptionButton:
	var names: Array = []
	for row: Array in Labels.SITE_FILTERS:
		names.append(row[1])
	return D.option(
		b,
		"SiteFilter",
		names,
		g.site_filter,
		func(id):
			g.site_filter = id
			g.map.set_marker_filter(Labels.SITE_FILTERS[id][0])
	)


## Figures with their uncertainty: a range until the site has been surveyed well enough.
static func _estimate_text(g, row: Dictionary, band: float) -> String:
	if band <= 0.0:
		return g.money(row.mid)
	return "%s–%s" % [g.money(row.low), g.money(row.high)]


static func _share_text(row: Dictionary, band: float) -> String:
	if band <= 0.0:
		return "%d%%" % (float(row.mid) * 100.0)
	return "%d–%d%%" % [float(row.low) * 100.0, float(row.high) * 100.0]


static func _site_facts(g, b, known: Dictionary):
	var band: float = float(known.band)
	var quality: String = "精确数据" if band <= 0.0 else ("地面勘察 ±%d%%" % (band * 100.0))
	if int(known.survey) == 0 and g.settlement().is_empty():
		quality = "轨道估算 ±%d%%" % (band * 100.0)
	D.label(b, quality, 15, D.TEAL)
	D.label(
		b,
		(
			"耕作潜力  %s    水源  %s\n一座农场约产 %.0f t/日\n海拔  %d m    建设费 ×%.2f"
			% [
				_share_text(known.fertility, band * 0.5),
				_share_text(known.water, band * 0.5),
				float(known.farm_yield),
				known.elevation,
				float(known.development)
			]
		),
		16,
		D.MUTED
	)
	for key in ["ore", "copper", "crystal"]:
		var row = D.row(b)
		D.icon(row, key, 24)
		D.label(
			row,
			"%s储量  %s t" % [RES[key], _estimate_text(g, known.deposits[key], band)],
			16,
			D.INK,
			false
		)
	var plots: Dictionary = known.plots
	D.label(
		b,
		(
			"空闲地块：建设 %d · 农田 %d · 铁 %d · 铜 %d · 晶体 %d"
			% [plots.general, plots.farm, plots.ore, plots.copper, plots.crystal]
		),
		15,
		D.MUTED
	)
	var notes: PackedStringArray = []
	if bool(known.coast):
		notes.append("沿海")
	if bool(known.river):
		notes.append("有河流")
	if float(known.risks.cold) > 0.3:
		notes.append("寒冷")
	if float(known.risks.arid) > 0.3:
		notes.append("干旱")
	if float(known.risks.flood) > 0.3:
		notes.append("易涝")
	if known.neighbors.is_empty():
		notes.append("孤立陆地：需要海运")
	if not notes.is_empty():
		D.label(b, " · ".join(notes), 15, D.GOLD)


static func _survey_button(g, b, known: Dictionary):
	if int(known.surveying) > 0:
		D.label(b, "勘察队在途，余 %d 天" % int(known.surveying), 15, D.TEAL)
		return
	var deep: bool = g.sim.state.research.completed.has("prospecting")
	if int(known.survey) >= 1 and not deep:
		return
	var at: int = int(known.id)
	var button = D.button(
		b,
		"%s ¥ %.0f" % ["远程勘测" if deep else "地面勘察", float(g.sim.Sites.survey_cost(g.sim))],
		func(): g.act("survey", {"site": at}),
		"缩小储量和品位的估算范围；有远程勘测技术时还能发现隐藏矿床。",
		"SurveyButton"
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.font_size(button, 14)
	button.custom_minimum_size = Vector2(60, 38)


static func populate(g, b, page):
	match page:
		"contract":
			contract(g, b)
		"build":
			build(g, b)
		"economy":
			economy(g, b)
		"transport":
			transport(g, b)
		"enterprise":
			enterprise(g, b)
		"population":
			population(g, b)
		"save":
			settings(g, b)
		"guide":
			guide(g, b)
		"world":
			world_info(g, b)
	var feedback = D.label(b, "", 16, D.GOLD)
	feedback.name = "Feedback"


static func world_info(g, b):
	var world: Dictionary = g.sim.geo
	D.label(b, "种子 %d  ·  %s" % [world.seed, world.version], 24, D.GOLD)
	D.label(b, "球面与平铺使用同一世界。地区的气温、水源、土地和矿藏影响建设、农业与运输。", 18, D.MUTED)
	var generation: Dictionary = world.get("generation", {})
	var stats: Dictionary = world.get("statistics", {})
	if generation.is_empty():
		D.label(D.card(b), "这是旧版经营测试地图。读档保留原有大陆、矿区与道路；新建游戏可体验种子驱动的大陆、气候和水系。", 18, D.GOLD)
	else:
		var terrain = D.card(b)
		D.label(terrain, "海陆与地形", 22, D.TEAL)
		D.label(
			terrain,
			(
				"星球半径 %.0f km  ·  陆地 %.1f%%  /  水域 %.1f%%"
				% [
					world.radius_km,
					float(stats.get("land_fraction", 0)) * 100,
					(1 - float(stats.get("land_fraction", 0))) * 100
				]
			),
			18
		)
		D.label(
			terrain,
			(
				"大块陆地 %d  ·  岛屿 %d  ·  山脉带 %d"
				% [
					stats.get("continent_count", 0),
					stats.get("island_count", 0),
					generation.get("mountain_ranges", []).size()
				]
			),
			18
		)
		D.label(
			terrain,
			(
				"陆地最高点 %.0f m  ·  平均海深 %.0f m"
				% [stats.get("max_elevation_m", 0), stats.get("mean_ocean_depth_m", 0)]
			),
			18
		)
		D.label(terrain, "海陆数量按当前世界网格的连通块统计；近岸小礁与局部细节会在更高显示精度下出现。", 16, D.MUTED)
		var climate = D.card(b)
		D.label(climate, "大气与气候", 22, D.TEAL)
		D.label(
			climate,
			(
				"气压 %.2f atm  ·  氧气比例 %.1f%%"
				% [
					generation.get("pressure_atm", 1),
					float(generation.get("oxygen_fraction", .21)) * 100
				]
			),
			18
		)
		D.label(
			climate,
			(
				"平均气温 %.1f°C  ·  平均湿润度 %.0f%%"
				% [stats.get("mean_temperature_c", 0), float(stats.get("mean_rainfall", 0)) * 100]
			),
			18
		)
		D.label(climate, "首版均为可呼吸的宜居环境。气压、纬度与海拔参与温度估计，湿润度结合海陆和山地；氧比例是环境设定，不模拟人体生理。", 16, D.MUTED)
		var hydro = D.card(b)
		D.label(hydro, "水系与生态", 22, D.TEAL)
		D.label(
			hydro,
			(
				"已生成河道 %d 条  ·  湖泊 %d 处"
				% [world.get("rivers", []).size(), world.get("lakes", []).size()]
			),
			18
		)
		var names = {
			"ocean": "海洋",
			"lake": "湖泊",
			"forest": "森林",
			"rainforest": "雨林",
			"grassland": "草地",
			"savanna": "稀树草原",
			"desert": "沙漠",
			"tundra": "苔原",
			"alpine": "高山",
			"ice": "冰雪",
			"wetland": "湿地"
		}
		var biomes: Dictionary = stats.get("biome_counts", {})
		for key in biomes:
			D.label(hydro, "%s  ·  %d 个环境网格" % [names.get(key, key), biomes[key]], 16, D.MUTED)
	var views = D.row(b)
	D.button(
		views,
		"球面总览",
		func():
			g.close_modal()
			g.navigate("planet")
	)
	D.button(
		views,
		"平铺地图",
		func():
			g.close_modal()
			g.navigate("flat")
	)


static func contract(g, b):
	var state: Dictionary = g.sim.state
	var view: Dictionary = g.sim.contract_view()
	var row = D.row(b)
	D.portrait(row, "liaison", 210, 320)
	var v = D.col(row)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: String = "殖民外包协议"
	if state.status == "success":
		title = "契约履行完毕  /  总督资格已授予"
	if state.status == "failed":
		title = "合同终止  /  经营失败"
	D.label(v, title, 24, D.GOLD)
	D.label(v, "分三个阶段建立一个能自立的殖民地。完成阶段可获得发展资金和新据点许可；错过期限不会立刻判负，但会进入公司审查。", 18)
	var op: Dictionary = g.sim.config.openings[state.advantage]
	var capital: float = float(
		g.sim.progression.difficulty[state.get("difficulty", "normal")].capital
	)
	D.label(
		v,
		(
			"开局支持：¥ %.0f；食品 %.0f t、建材 %.0f t、部件 %.0f t。工人 %d、研究员 %d、未成年 %d。"
			% [
				float(op.cash) * capital,
				op.food,
				op.materials,
				op.parts,
				op.workers,
				op.scientists,
				op.children
			]
		),
		17,
		D.TEAL
	)
	if state.status == "planning":
		D.button(v, "接受协议，开始勘察  →", g.close_modal)
	elif state.status == "success":
		D.button(v, "继续担任总督 / 沙盒经营", g.close_modal)
		D.button(v, "查看 B 代管与下一颗星球", func(): g.open_page("career"))
	elif state.status == "failed":
		D.label(v, str(state.get("failure_reason", "经营条件未达标。")), 18, D.RED)
		D.button(v, "失败报告 / 恢复登陆检查点", func(): g.open_page("career"))
		D.button(v, "查看公司审查经过", func(): g.open_page("company"))
	else:
		D.button(v, "返回经营", g.close_modal)
	for stage: Dictionary in view.stages:
		_contract_stage(g, b, stage, int(view.current))
	if state.status == "success":
		D.label(b, "行星里程碑（可选）：已达成 %d 项" % view.milestones.size(), 18, D.TEAL)


static func _contract_stage(g, b, stage: Dictionary, current: int):
	var card = D.card(b)
	var done: bool = int(stage.completed_day) >= 0
	var head: String = str(Labels.STAGE_NAMES.get(stage.id, stage.id))
	if done:
		head += "  ·  第 %d 日完成" % int(stage.completed_day)
	elif int(stage.stage) == current:
		head += "  ·  期限第 %d 日" % int(stage.deadline)
	D.label(card, head, 21, D.GOLD if int(stage.stage) == current else D.TEAL)
	var rewards: PackedStringArray = []
	if float(stage.reward_cash) > 0.0:
		rewards.append("发展资金 ¥ %.0f" % float(stage.reward_cash))
	if str(stage.licence) != "":
		rewards.append(str(Labels.LICENCE_NAMES.get(stage.licence, stage.licence)))
	if int(stage.stage) == 3:
		rewards.append("总督资格")
	D.label(card, "奖励：" + "、".join(rewards), 16, D.MUTED)
	if done or int(stage.stage) > current:
		return
	for goal_row: Dictionary in stage.goals:
		var text: Dictionary = Labels.goal(goal_row)
		var line = D.row(card)
		var caption = D.label(
			line,
			"%s  %s" % ["✓" if goal_row.ok else "○", text.text],
			17,
			D.TEAL if goal_row.ok else D.INK
		)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not goal_row.ok and str(text.page) != "":
			var page: String = text.page
			var fix = D.button(line, "去处理", func(): g.open_page(page), str(text.hint))
			D.font_size(fix, 14)
			fix.custom_minimum_size.y = 30
		elif not goal_row.ok:
			D.label(line, str(text.hint), 15, D.MUTED, false)


static func build(g, b):
	D.label(b, g.sim.state.world.regions[g.selected].name + " / 建设目录", 23, D.TEAL)
	var s: Dictionary = g.settlement()
	if s.is_empty():
		D.label(b, "请先在这里建立据点。", 18, D.GOLD)
		return
	D.label(
		b,
		(
			"工程消耗本地仓库的建材和部件。空闲工人 %d · 公共资金 ¥ %s · 建材 %.0f t · 部件 %.0f t"
			% [g.sim.free_workers(s), g.money(g.sim.state.cash), s.stock.materials, s.stock.parts]
		),
		17,
		D.MUTED
	)
	var filters = D.row(b)
	_category_button(g, filters, "all", "全部")
	for key: String in Labels.BUILD_CATEGORIES:
		_category_button(g, filters, key, str(Labels.BUILD_CATEGORIES[key]))
	for category: String in Labels.BUILD_CATEGORIES:
		if g.build_category != "all" and g.build_category != category:
			continue
		D.label(b, str(Labels.BUILD_CATEGORIES[category]), 19, D.TEAL)
		for key: String in g.sim.config.buildings:
			if str(g.sim.config.buildings[key].get("category", "")) == category:
				_build_card(g, b, key)


static func _category_button(g, parent, key: String, text: String):
	var button = D.button(
		parent,
		text,
		func():
			g.build_category = key
			g.populate_current_page(),
		"",
		"Cat_" + key
	)
	D.font_size(button, 15)
	button.custom_minimum_size.y = 32
	button.add_theme_color_override("font_color", D.GOLD if g.build_category == key else D.INK)


static func _build_card(g, b, key: String):
	var spec: Dictionary = g.sim.build_preview(g.selected, key)
	var choices: Array = g.sim.plot_choices(g.selected, key)
	var plot: int = _chosen_plot(g, key, choices)
	var forecast: Dictionary = g.sim.build_forecast(g.selected, key, plot)
	var needed: String = str(spec.get("requires_tech", ""))
	var locked: bool = needed != "" and not g.sim.state.research.completed.has(needed)
	var refusal: String = str(forecast.disabled_reason)
	var card = D.card(b)
	var r = D.row(card)
	D.icon(r, str(key).trim_prefix("mine_"), 31)
	var text = D.col(r)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(text, spec.name, 20)
	D.label(
		text,
		"¥ %d · 建材 %d · 部件 %d · %d 天" % [spec.cost, spec.materials, spec.parts, spec.days],
		16,
		D.GOLD
	)
	D.label(
		text,
		(
			"岗位 %d（空闲工人 %d） · 电 %.0f · 水 %.0f · 维护 ¥ %.1f/日"
			% [
				int(forecast.jobs),
				int(forecast.free_workers),
				spec.power,
				spec.water,
				spec.maintenance
			]
		),
		15,
		D.MUTED
	)
	var outcome: String = _forecast_text(forecast)
	if outcome != "":
		D.label(text, outcome, 15, D.TEAL)
	var order = D.button(
		r,
		"需要：" + str(g.sim.config.techs[needed].name) if locked else "下达建设",
		func(): g.act("build", {"site": g.selected, "kind": key, "plot": plot}),
		refusal,
		"Build_" + key
	)
	order.disabled = locked or refusal != ""
	if choices.size() > 1 and str(choices[0].kind) != "general":
		var names: Array = []
		var picked: int = 0
		for index: int in range(choices.size()):
			names.append(Labels.plot(choices[index]))
			if int(choices[index].index) == plot:
				picked = index
		D.option(
			card,
			"Plot_" + key,
			names,
			picked,
			func(id):
				g.build_plots[key] = int(choices[id].index)
				g.populate_current_page()
		)
	D.label(card, str(spec.description), 15, D.MUTED)
	if bool(spec.get("megaproject", false)):
		D.label(card, "巨型工程：每颗星球一座；本地缺少的工程物资按进口价随工程采购。", 15, D.TEAL)
	if refusal != "" and not locked:
		D.label(card, refusal, 15, D.GOLD)


## The plot the player picked for this kind if it is still free, otherwise the best one.
static func _chosen_plot(g, key: String, choices: Array) -> int:
	if choices.is_empty():
		return -1
	var wanted: int = int(g.build_plots.get(key, -1))
	for row: Dictionary in choices:
		if int(row.index) == wanted:
			return wanted
	return int(choices[0].index)


static func _forecast_text(forecast: Dictionary) -> String:
	var parts: PackedStringArray = []
	for good: String in forecast.outputs:
		parts.append("%s %.1f t/日" % [RES.get(good, good), float(forecast.outputs[good])])
	if float(forecast.revenue_per_day) != 0.0:
		parts.append("收入 ¥ %.0f/日" % float(forecast.revenue_per_day))
	parts.append("净 ¥ %+.0f/日" % float(forecast.net_per_day))
	if float(forecast.payback_days) > 0.0:
		parts.append("约 %.0f 日回本" % float(forecast.payback_days))
	if float(forecast.reserve_days) >= 0.0:
		parts.append("储量够挖 %.0f 日" % float(forecast.reserve_days))
	return " · ".join(parts)


static func economy(g, b):
	var state: Dictionary = g.sim.state
	var row = D.row(b)
	for pair in [
		["公共账户", state.cash], ["居民账户", state.resident_cash], ["企业账户", state.enterprise_cash]
	]:
		var c = D.card(row)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.label(c, pair[0], 15, D.MUTED)
		D.label(c, "¥ " + g.money(pair[1]), 29, D.GOLD)
	var summary: Dictionary = g.sim.summary()
	var lasting: String = "经营净流入"
	if float(summary.runway) >= 0.0:
		lasting = "预计现金可维持 %.1f 天" % float(summary.runway)
	D.label(b, "近 7 日平均净额 ¥ %+.0f/日 · %s" % [float(summary.operating_average), lasting], 19, D.TEAL)
	if float(state.get("debt", 0)) > 0.0:
		D.label(
			b,
			"到期欠款 ¥ %.0f · 已连续 %d 日" % [float(state.debt), int(state.get("grace_days", 0))],
			17,
			D.RED
		)
	var series: Dictionary = g.sim.stats_series()
	var chart = D.card(b)
	D.label(
		chart,
		(
			"近 90 日  金色：现金 ¥ %s 至 ¥ %s    青色：每日净额 ¥ %+.0f 至 ¥ %+.0f"
			% [
				g.money(_lowest(series.cash)),
				g.money(_highest(series.cash)),
				_lowest(series.net),
				_highest(series.net)
			]
		),
		15,
		D.MUTED
	)
	D.line_chart(
		chart,
		"CashChart",
		[{"values": series.cash, "color": D.GOLD}, {"values": series.net, "color": D.TEAL}]
	)
	var totals: Dictionary = g.sim.stats_window(30)
	var columns = D.row(b)
	_money_column(g, columns, "近 30 日收入", totals.income, D.TEAL)
	_money_column(g, columns, "近 30 日支出", totals.expense, D.GOLD)
	if not totals.invest.is_empty() or not totals.funding.is_empty():
		var capital = D.row(b)
		_money_column(g, capital, "近 30 日投资（不计经营）", totals.invest, D.MUTED)
		_money_column(g, capital, "近 30 日外来资金（不计经营）", totals.funding, D.MUTED)
	_goods_table(b, totals.goods)
	D.label(b, "出口价格：出口越多价格越低，停售后缓慢恢复", 20, D.TEAL)
	for row_data: Dictionary in g.sim.market_view():
		var arrow: String = {-1: "↓", 0: "→", 1: "↑"}[int(row_data.trend)]
		D.label(
			b,
			(
				"%s  ¥ %.1f / t  %s（基准 %.1f，%.0f%%）"
				% [
					RES.get(row_data.good, row_data.good),
					row_data.price,
					arrow,
					row_data.base,
					row_data.factor * 100.0
				]
			),
			16,
			D.INK if float(row_data.factor) > 0.8 else D.GOLD
		)
	for s in state.settlements:
		var c = D.card(b)
		D.label(c, s.name + " / 本地库存", 20)
		var r = D.row(c)
		for key in RES:
			var v = D.col(r)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			D.icon(v, key)
			D.label(
				v,
				RES[key] + "\n%.1f t\n%+.1f /日" % [s.stock.get(key, 0), s.stock_delta.get(key, 0)],
				16
			)
		var lines: PackedStringArray = []
		for shortage in s.get("shortages", []):
			lines.append(Labels.shortage(g.sim.config, shortage))
		D.label(c, "\n".join(lines), 16, D.RED)
	D.button(b, "查看公司审查原因、整改期限与救助义务", func(): g.open_page("company"))
	var detail: bool = bool(g.detailed_info)
	D.label(b, "详情：最近资金流水（来源 → 去向 / 金额）", 20, D.TEAL)
	D.label(
		b,
		(
			"建设投资和融资不计入持续经营；工资和消费是账户间转账。总督阶段公司按正经营结余收取 %.0f%%；援助追加分成另列。"
			% (float(g.sim.config.contract.company_tax_rate) * 100)
		),
		15,
		D.MUTED
	)
	var ledger: Array = state.ledger
	for i in range(ledger.size() - 1, maxi(-1, ledger.size() - (31 if detail else 7)), -1):
		var e: Dictionary = ledger[i]
		var accounts = {"external": "外部", "public": "公共", "residents": "居民", "enterprise": "企业"}
		D.label(
			b,
			(
				"D%d  %s  |  %s → %s  ¥ %.2f"
				% [
					e.get("day", 0),
					Labels.ledger(g.sim.config, e),
					accounts.get(e.get("from", ""), e.get("from", "")),
					accounts.get(e.get("to", ""), e.get("to", "")),
					e.get("amount", 0)
				]
			),
			16,
			D.MUTED
		)


static func _lowest(values: PackedFloat32Array) -> float:
	var result: float = INF
	for value: float in values:
		result = minf(result, value)
	return 0.0 if values.is_empty() else result


static func _highest(values: PackedFloat32Array) -> float:
	var result: float = -INF
	for value: float in values:
		result = maxf(result, value)
	return 0.0 if values.is_empty() else result


## Largest first; keeps the page short by folding the small ones into a total.
static func _money_column(g, parent, title: String, amounts: Dictionary, color: Color):
	var c = D.card(parent)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys: Array = amounts.keys()
	keys.sort_custom(
		func(a: String, x: String) -> bool:
			if float(amounts[a]) == float(amounts[x]):
				return a < x
			return float(amounts[a]) > float(amounts[x])
	)
	var total: float = 0.0
	for key: String in keys:
		total += float(amounts[key])
	D.label(c, "%s  ¥ %s" % [title, g.money(total)], 17, color)
	var shown: int = 0
	var rest: float = 0.0
	for key: String in keys:
		if shown >= MONEY_ROWS:
			rest += float(amounts[key])
			continue
		shown += 1
		D.label(
			c, "%s  ¥ %s" % [str(Labels.LEDGER.get(key, key)), g.money(amounts[key])], 15, D.INK
		)
	if rest > 0.0:
		D.label(c, "其他  ¥ %s" % g.money(rest), 15, D.MUTED)


static func _goods_table(b, goods: Dictionary):
	var c = D.card(b)
	D.label(c, "近 30 日物资流向（吨）：产出 / 消耗 / 出口 / 进口 / 陆海运输", 17, D.TEAL)
	var table = D.grid(c, 6)
	for heading: String in ["物资", "产出", "消耗", "出口", "进口", "运输"]:
		D.label(table, heading, 15, D.MUTED, false)
	for good: String in RES:
		var row: Array = goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
		var name = D.label(table, str(RES[good]), 15, D.INK, false)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for amount: Variant in row:
			var cell = D.label(table, "%.0f" % float(amount), 15, D.INK, false)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func transport(g, b):
	D.label(b, "矿物向港口汇集，食品向居民流动。", 25, D.TEAL)
	D.label(b, "货物在装车时离开起点仓库，在运输天数结束后才进入终点；运力有限，陆路不会穿海。第二据点的材料由拓展物资提供，后续需要加工、进口或实际运输。", 18, D.MUTED)
	var state: Dictionary = g.sim.state
	if state.settlements.size() < 2:
		D.label(b, "尚需建立第二据点。请在行星总览选择可达地点，并派出远征队。", 21, D.GOLD)
		return
	var a: int = (
		int(g.selected) if not g.settlement().is_empty() else int(state.settlements[0].region)
	)
	D.label(b, "从 %s 出发的线路" % state.world.regions[a].name, 20, D.GOLD)
	for other: Dictionary in state.settlements:
		var z: int = int(other.region)
		if z != a:
			_road_options(g, b, a, z)
	var paving: Dictionary = g.sim.config.road_upgrade
	for road: Dictionary in state.roads:
		_road_card(g, b, road, paving)
	D.label(b, "累计运输 %.0f t" % float(state.get("transported_total", 0)), 18, D.TEAL)
	D.label(b, "在途批次  /  " + str(state.shipments.size()), 20)
	for sh in state.shipments:
		D.label(
			b,
			(
				"%s → %s   %s %.1f t  /  还有 %d 天抵达"
				% [
					state.world.regions[int(sh.from)].name,
					state.world.regions[int(sh.to)].name,
					RES.get(sh.resource, sh.resource),
					sh.amount,
					sh.remaining
				]
			),
			16,
			D.MUTED
		)


static func _road_options(g, b, a: int, z: int):
	var state: Dictionary = g.sim.state
	var c = D.card(b)
	D.label(c, "%s → %s" % [state.world.regions[a].name, state.world.regions[z].name], 21)
	for variant: String in ["valley", "engineered", "sea"]:
		var quote: Dictionary = g.sim.road_quote(a, z, variant)
		var spec: Dictionary = g.sim.config.roads[variant]
		if not bool(quote.reachable):
			if variant != "sea":
				D.label(c, "%s：%s" % [spec.name, str(quote.reason)], 16, D.MUTED)
			continue
		var risk: String = "无"
		if float(quote.closure_chance) > 0.0:
			risk = "约每 %.0f 日一次" % (1.0 / float(quote.closure_chance))
		(
			D
			. label(
				c,
				(
					"%s：%.0f km · 单程 %d 天 · 建设 ¥ %.0f · 运力 %d t/日 · 养护 ¥ %.1f/日 · 封路 %s"
					% [
						spec.name,
						float(quote.distance),
						int(quote.days),
						float(quote.cost),
						int(quote.capacity),
						float(quote.upkeep),
						risk,
					]
				),
				17,
				D.GOLD
			)
		)
		var chosen: String = variant
		var order = D.button(
			c,
			"建设" + str(spec.name),
			func(): g.act("connect", {"a": a, "b": z, "variant": chosen}),
			str(quote.refusal)
		)
		order.disabled = str(quote.refusal) != ""


static func _closure_text(chance: float) -> String:
	if chance <= 0.0:
		return "不会封路"
	return "封路 约每 %d 日一次" % roundi(1.0 / chance)


static func _road_card(g, b, road: Dictionary, paving: Dictionary):
	var state: Dictionary = g.sim.state
	var c = D.card(b)
	var spec: Dictionary = g.sim.config.roads[str(road.get("variant", "valley"))]
	var blocked: bool = WG.road_blocked(road, int(state.day))
	D.label(
		c,
		(
			"%s%s：%s ↔ %s"
			% [
				spec.name,
				"（已铺装）" if bool(road.get("paved", false)) else "",
				state.world.regions[int(road.a)].name,
				state.world.regions[int(road.b)].name
			]
		),
		19,
		D.RED if blocked else D.TEAL
	)
	D.label(
		c,
		(
			"单程 %d 天 · 运力 %d t/日 · 今日已发 %.1f t · 养护 ¥ %.1f/日 · %s%s"
			% [
				int(road.days),
				int(road.capacity),
				float(road.sent_today),
				float(road.get("upkeep", 0.0)),
				_closure_text(g.sim.Logistics.closure_chance(g.sim, road)),
				" · 封路至第 %d 日" % int(road.blocked_until) if blocked else ""
			]
		),
		17
	)
	var moving: Dictionary = {}
	for cargo: Dictionary in state.shipments:
		if int(cargo.get("road", -1)) == int(road.id):
			moving[cargo.resource] = float(moving.get(cargo.resource, 0.0)) + float(cargo.amount)
	if not moving.is_empty():
		var words: PackedStringArray = []
		for good: String in moving:
			words.append("%s %.0f t" % [RES.get(good, good), float(moving[good])])
		D.label(c, "在途：" + "、".join(words), 15, D.MUTED)
	if (
		state.research.completed.has(paving.tech)
		and not bool(road.get("paved", false))
		and str(road.get("variant", "valley")) != "sea"
	):
		var id: int = int(road.id)
		D.button(
			c,
			(
				"铺装道路 · ¥ %.0f + 建材 %.0f t"
				% [float(road.cost) * float(paving.cost_factor), float(paving.materials)]
			),
			func(): g.act("upgrade_road", {"road": id}),
			"运力 +50%，单程 -1 天，封路风险 -70%"
		)


static func enterprise(g, b):
	D.label(b, "从统一经营，走向混合经济", 25, D.GOLD)
	D.label(
		b, "开放本地生活服务业。外部投资者以自己的资金入场，自主租用经营点、雇工、支付设备维护，向居民提供维修、洗衣和通讯服务，按利润缴本地税；公共矿山与关键设施继续由你管理。", 18
	)
	var e: Dictionary = g.sim.state.get("enterprise", {})
	var forecast: Dictionary = g.sim.enterprise_preview(g.selected)
	D.label(
		b,
		(
			"所选地区潜在日收入 %.2f / 日成本 %.2f / 预计利润 %+.2f"
			% [
				forecast.get("daily_demand", 0),
				forecast.get("daily_cost", 0),
				forecast.get("estimated_profit", 0)
			]
		),
		18,
		D.GOLD
	)
	D.label(b, str(forecast.get("reason", "")), 16, D.MUTED)
	if e.is_empty():
		D.label(b, "选址：" + g.sim.state.world.regions[g.selected].name, 21, D.TEAL)
		D.button(b, "批准本地区生活服务经营许可", func(): g.act("enterprise", {"region": g.selected}))
	else:
		var c = D.card(b)
		D.label(c, str(e.get("name", "青溪餐食合作社")), 23)
		D.label(
			c,
			(
				"%s  ·  %s  ·  雇员 %d"
				% [
					g.sim.state.world.regions[int(e.region)].name,
					Labels.enterprise_status(e.status),
					e.get("employees", 0)
				]
			),
			20,
			D.TEAL
		)
		D.label(
			c,
			(
				"本日利润 ¥ %.2f  |  累计销售 ¥ %.2f\n累计工资 ¥ %.2f  |  已缴本地税 ¥ %.2f\n企业独立账户 ¥ %.2f"
				% [
					e.get("profit", 0),
					e.get("sales_total", 0),
					e.get("wages_total", 0),
					e.get("tax_total", 0),
					g.sim.state.enterprise_cash
				]
			),
			19,
			D.GOLD
		)
		D.label(c, Labels.enterprise_reason(str(e.get("reason", ""))), 17, D.MUTED)
		D.button(
			c,
			"付费重组 / 迁入所选地区 · ¥ %.0f" % forecast.get("recovery_cost", 0),
			func(): g.act("enterprise_recover", {"region": g.selected})
		)
	D.label(b, "本地企业利润税率（0—50%）", 18, D.TEAL)
	var row = D.row(b)
	var tax_box = D.spin(row, "PolicyTax", 0, 50, 1, float(g.sim.state.policy.tax) * 100.0, "%")
	D.button(row, "应用税率", func(): g.act("policy", {"tax": tax_box.value / 100.0}))
	D.label(b, "基本供应政策：食品保留天数（3—25 天，各地最低自动贸易储备）", 17, D.MUTED)
	var rr = D.row(b)
	var reserve_box = D.spin(
		rr, "PolicyFoodReserve", 3, 25, 1, float(g.sim.state.policy.food_reserve), "天"
	)
	D.button(rr, "应用食品底线", func(): g.act("policy", {"food_reserve": reserve_box.value}))
	D.label(
		b,
		(
			"当前税率 %.0f%% · 食品底线 %.0f 天"
			% [g.sim.state.policy.tax * 100, g.sim.state.policy.food_reserve]
		),
		17,
		D.GOLD
	)
	var allowed = bool(g.sim.state.policy.private_allowed)
	D.button(
		b,
		"暂停批准新经营许可" if allowed else "允许商业服务业",
		func(): g.act("policy", {"private_allowed": not allowed})
	)


static func settings(g, b):
	D.label(b, "安全存档 / 独立保存世界与经营状态", 23, D.TEAL)
	D.label(
		b,
		(
			"手动存档已存在 · 可读取继续"
			if FileAccess.file_exists(g.SAVE_MANUAL)
			else "尚无手动存档 · 点击下方保存，或使用左上角存档 / Ctrl+S"
		),
		18,
		D.GOLD
	)
	D.label(b, "自动存档每 10 个模拟日写入。手动档与自动档分开，临时文件写完后替换。退出前建议手动保存。", 18, D.MUTED)
	var r = D.row(b)
	D.button(r, "保存手动档", func(): g.save_slot(g.SAVE_MANUAL))
	D.button(r, "读取手动档", func(): g.load_path(g.SAVE_MANUAL))
	D.button(r, "读取自动档", func(): g.load_path(g.SAVE_AUTO))
	if g.dev_mode:
		for item in [
			["危机整改", "acceptance_crisis"],
			["事件中段", "acceptance_event_mid"],
			["总督移交前", "acceptance_governor"],
			["第二星球分红后", "acceptance_second_dividend"]
		]:
			var path: String = "res://data/v16/" + item[1] + ".json"
			var button = D.button(b, "读取1.6验收：" + item[0], func(): g.load_path(path))
			button.disabled = not FileAccess.file_exists(path)
		D.button(b, "读取1.5兼容性示例（中期）", func(): g.load_path("res://data/acceptance_midgame.json"))
		D.button(b, "导出可读 JSON（开发用）", func(): g.export_state_json())
	for item: Array in [
		["读取 1.6 手动档（原文件保留）", g.old_save_path(g.OLD_SAVE_MANUAL)],
		["读取 1.6 自动档（原文件保留）", g.old_save_path(g.OLD_SAVE_AUTO)],
		["读取 1.5 手动档（原文件保留）", g.old_save_path(g.OLDER_SAVE_MANUAL)],
	]:
		var old_path: String = str(item[1])
		var old_button = D.button(b, str(item[0]), func(): g.load_path(old_path))
		old_button.disabled = not FileAccess.file_exists(old_path)
	D.label(b, "说明详细度与难度独立；所有核心规则和重要原因始终可见。", 16, D.MUTED)
	D.button(
		b,
		"当前详细记录（30条流水 / 20条事件）" if g.detailed_info else "当前精简记录（6条流水 / 6条事件）",
		g.toggle_information
	)
	D.button(
		b, "打开面板时暂停：开（关闭后恢复原速度）" if g.panel_pause else "打开面板时暂停：关（面板打开时时间继续）", g.toggle_panel_pause
	)
	D.label(b, "新手引导", 20)
	var teaching = D.row(b)
	D.button(teaching, "重新开始新手引导（开始一局引导专用的新游戏）", g.start_tutorial, "当前未保存的进度会丢失", "ReplayTutorial")
	var tips_on: bool = bool(g.coach.tips_enabled)
	D.button(
		teaching,
		"情境提示：开" if tips_on else "情境提示：关",
		func():
			g.coach.set_tips(not tips_on)
			g.populate_current_page(),
		"",
		"ToggleTips"
	)
	D.label(b, "窗口分辨率", 20)
	var resolutions = D.row(b)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var sz = size
		D.button(
			resolutions, "%d × %d" % [size.x, size.y], func(): DisplayServer.window_set_size(sz)
		)
	D.label(b, "UI 文字大小", 20)
	var scale_row = D.row(b)
	for scale_val in [16, 18, 20]:
		var sv = scale_val
		D.button(scale_row, str(sv) + " px", func(): g.apply_scale(sv / 18.0))
	D.label(b, "存档目录：" + OS.get_user_data_dir(), 16, D.MUTED)
	D.button(b, "截取实际游戏画面  /  F12", g.capture)
	D.button(
		b,
		"返回主菜单（当前未保存进度会丢失）",
		func():
			var dialog = ConfirmationDialog.new()
			dialog.dialog_text = "确定返回主菜单？请先保存当前经营进度。"
			g.add_child(dialog)
			dialog.confirmed.connect(g.show_menu)
			dialog.popup_centered()
	)


static func guide(_g, b):
	D.label(b, "怎样经营一块殖民地", 25, D.GOLD)
	var steps = [
		"01  选址。卡片上的储量是估算，派勘察队可以缩小范围。先找矿多、水够、附近有肥沃土地的地点。",
		"02  开矿出口。在矿床地块上建矿场，矿石到货运站自动卖出。出口越多价格越低，别只卖一种。",
		"03  住房和工作。床位满了没人来，没工作的人多了新移民也不来。工资影响吸引力，招募来得最快。",
		"04  研究。建研究所，把研究员集中到关键项目：5 人的速度只有 10 人的 60%。",
		"05  第二据点。完成第一阶段后派远征队去肥沃的地方，修路相连。河谷公路便宜但绕远，工程公路直接但有落石风险。",
		"06  自立。合同的第三阶段要人口、就业、民营企业和非矿业收入。加工厂、食品订单和科研委托都算。",
		"07  长远。矿总会挖完。深层采掘、新地点、海运和巨型工程让殖民地继续发展。",
		"遇到问题先看右侧红字，旁边的「处理」会带你去解决。公司关系页解释一切风险的原因。",
	]
	for text in steps:
		D.label(D.card(b), text, 18)


static func population(g, b):
	var s: Dictionary = g.settlement()
	if s.is_empty():
		D.label(b, "请选择已建立的据点。", 20)
		return
	var v: Dictionary = g.sim.population_view(int(s.region))
	D.label(b, s.name + " / 人口与移民", 24, D.TEAL)
	D.label(b, "吸引力 %.2f  ·  约每月 %.1f 人迁入" % [v.attractiveness, v.arrivals_per_month], 20, D.GOLD)
	D.label(b, "近 30 日迁入 %d 人 · 离开 %d 人" % [int(v.arrived_30), int(v.departed_30)], 17)
	if float(v.prospects) < 1.0:
		D.label(b, "失业的人多，新移民正在减少（就业前景 %.0f%%）。" % (float(v.prospects) * 100.0), 16, D.GOLD)
	var parts = D.card(b)
	D.label(parts, "吸引力构成（基础 1.00）", 17, D.TEAL)
	for key: String in v.parts:
		var amount: float = float(v.parts[key])
		D.label(
			parts,
			"%s  %+.2f" % [Labels.ATTRACTIVENESS_PARTS.get(key, key), amount],
			16,
			D.INK if amount >= 0.0 else D.RED
		)
	D.label(
		b,
		(
			"人口 %d  ·  住房 %d  ·  空床位 %d  ·  招募在途 %d"
			% [int(s.population), int(s.housing), int(v.free_beds), int(v.in_transit)]
		),
		18
	)
	D.label(b, "工资政策（基准工资的倍数）：提高工资增加吸引力、减少离开，但所有工资支出同比增加。", 17, D.MUTED)
	var wage_row = D.row(b)
	var wage = D.spin(
		wage_row,
		"PolicyWage",
		g.sim.pop_rules.wage.min,
		g.sim.pop_rules.wage.max,
		0.05,
		float(v.wage),
		"×"
	)
	D.button(wage_row, "应用工资", func(): g.act("policy", {"wage": wage.value}), "", "ApplyWage")
	D.label(b, "招募：立即付费，%d 日后抵达，需要预留床位；90 日内每多一次招募，单价上涨 10%%。" % int(v.travel_days), 17, D.MUTED)
	var recruit_row = D.row(b)
	var count = D.spin(
		recruit_row, "RecruitCount", 1, g.sim.pop_rules.recruitment.max_per_campaign, 1, 10, "人"
	)
	var region: int = int(s.region)
	D.button(
		recruit_row,
		"招募工人 · ¥ %.0f/人" % float(v.worker_price),
		func(): g.act("recruit", {"region": region, "kind": "worker", "count": int(count.value)}),
		"",
		"RecruitWorkers"
	)
	D.button(
		recruit_row,
		"招募研究员 · ¥ %.0f/人" % float(v.scientist_price),
		func():
			g.act("recruit", {"region": region, "kind": "scientist", "count": int(count.value)}),
		"",
		"RecruitScientists"
	)
