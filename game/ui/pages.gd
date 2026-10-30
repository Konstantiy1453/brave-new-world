extends RefCounted
const D = preload("res://ui/design.gd")
const WG = preload("res://world/world_gen.gd")
const Labels = preload("res://ui/labels.gd")
const RES = {
	"ore": "铁矿", "copper": "铜矿", "crystal": "工业晶体", "food": "食品", "materials": "建材", "parts": "部件"
}


static func region(g, b):
	var r: Dictionary = g.sim.state.world.regions[g.selected]
	D.label(b, "REGION  /  %02d" % (g.selected + 1), 13, D.TEAL)
	D.label(b, r.name, 27)
	D.label(b, "%s  ·  %.1f°C" % [r.terrain, r.temperature], 16, D.MUTED)
	var site_names: Array = []
	for reg in g.sim.state.world.regions:
		site_names.append(reg.name)
	D.option(
		b,
		"RegionChooser",
		site_names,
		g.selected,
		func(id):
			g.selected = id
			if g.local_view:
				g.map.show_region(id)
			else:
				g.map.focus_region(id)
			g.refresh_sidebar()
	)
	D.label(
		b,
		"耕作潜力  %d%%    水源  %d%%\n海拔  %d m" % [r.fertility * 100, r.water * 100, r.elevation],
		16,
		D.MUTED
	)
	for key in ["ore", "copper", "crystal"]:
		var row = D.row(b)
		D.icon(row, key, 24)
		D.label(row, "%s储量  %s t" % [RES[key], g.money(r.deposits[key])], 16, D.INK, false)
	var s: Dictionary = g.settlement()
	if s.is_empty():
		D.label(b, "尚未开发", 18, D.GOLD)
		D.label(b, "选择矿区作为首府更易建立出口现金流。河谷适合作为粮食据点。海岛无陆路连接。", 16, D.MUTED)
		var btn = D.button(
			b,
			"在此建立" + ("第二据点" if g.sim.state.settlements.size() > 0 else "首府"),
			func(): g.act("settle", {"region": g.selected})
		)
		btn.disabled = g.sim.state.settlements.size() >= 2
		if btn.disabled:
			btn.tooltip_text = "Demo 每局最多两处据点。"
		D.button(b, "查看地区地表", func(): g.navigate("region"))
		return
	D.label(
		b,
		(
			"人口 %d  ·  住房 %d\n就业 %d  /  劳动人口 %d\n研究员 %d  ·  未成年 %d"
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
	D.label(b, "本地食品储备  %.1f 天" % s.get("food_days", 0), 18, D.GOLD)
	D.label(
		b,
		(
			"电力 %.0f / %.0f  ·  供水 %.0f / %.0f\n（可用供给 / 需求）"
			% [
				s.get("power_supply", 0),
				s.get("power_demand", 0),
				s.get("water_supply", 0),
				s.get("water_demand", 0)
			]
		),
		16,
		D.MUTED
	)
	for shortage in s.get("shortages", []):
		D.label(b, "!  " + Labels.shortage(g.sim.config, shortage), 15, D.RED)
	D.button(b, "建设设施  +", func(): g.open_page("build"))
	D.button(b, "批量生产 / 库存目标", func(): g.open_page("manage"))
	D.button(b, "进入地区 / 查看设施", func(): g.navigate("region"))
	D.label(b, "设施状态", 14, D.TEAL)
	for index in range(s.buildings.size()):
		var item = s.buildings[index]
		var active = bool(item.get("active", false))
		D.label(
			b,
			(
				"%s · %s"
				% [
					Labels.building_name(g.sim.config, item.kind),
					"运营" if active else Labels.building_status(item)
				]
			),
			15,
			D.INK if active else D.MUTED
		)
		if item.get("owner", "public") == "public":
			var idx = index
			var bt = D.button(
				b,
				"暂停此设施" if item.get("enabled", true) else "恢复此设施",
				func(): g.act("toggle", {"region": g.selected, "index": idx})
			)
			D.font_size(bt, 14)
			bt.custom_minimum_size.y = 30
			var preview: Dictionary = g.sim.toggle_preview(int(s.region), idx)
			bt.tooltip_text = (
				"停用规则：不提供产能或住房。切换后住房 %s，住房缺口 %s"
				% [
					str(preview.get("housing_after", "—")),
					str(preview.get("housing_shortfall", "—"))
				]
			)


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
	D.label(b, "工程消耗当前据点的实物库存。竣工后按劳力、电力、水源和原料限产；鼠标停留可查看配方。", 17, D.MUTED)
	for key in g.sim.config.buildings:
		var spec: Dictionary = g.sim.build_preview(g.selected, key)
		var card = D.card(b)
		var r = D.row(card)
		D.icon(r, str(key).trim_prefix("mine_"), 31)
		var text = D.col(r)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.label(text, spec.name, 20)
		D.label(
			text,
			(
				"¥ %d  |  建材 %d  部件 %d  |  %d 天  |  岗位 %d  电 %.0f  水 %.0f"
				% [
					spec.cost,
					spec.materials,
					spec.parts,
					spec.days,
					spec.jobs,
					spec.power,
					spec.water
				]
			),
			16,
			D.GOLD
		)
		var kind = key
		D.button(
			r,
			"下达建设",
			func(): g.act("build", {"region": g.selected, "kind": kind}),
			str(spec.description)
		)
		D.label(card, spec.description + "  日维护 ¥ %.1f。" % spec.maintenance, 16, D.MUTED)


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
	var net = float(state.get("operating_net", 0))
	var runway: float = float(g.sim.summary().runway)
	D.label(
		b,
		(
			"本期公共经营净额：%+.2f / 日   ·   预计现金可维持：%s"
			% [net, ("%.1f 天" % runway) if runway >= 0 else "经营净流入"]
		),
		19,
		D.TEAL
	)
	D.label(
		b,
		(
			"本日经营支出 ¥ %.2f · 到期欠款 ¥ %.2f · 连续欠款 %d 日"
			% [state.get("expense_daily", 0), state.get("debt", 0), state.get("grace_days", 0)]
		),
		17,
		D.GOLD
	)
	var finance: float = 0.0
	for entry in state.ledger:
		if (
			int(entry.day) > int(state.day) - 7
			and not bool(entry.operating)
			and entry.from == "external"
			and entry.to == "public"
		):
			finance += float(entry.amount)
	D.label(b, "最近7日非经营外部流入 ¥ %.2f · 援助、事件拨款与生涯注资单列，不计连盈。" % finance, 17, D.TEAL)
	D.button(b, "查看公司审查原因、整改期限与救助义务", func(): g.open_page("company"))
	D.label(
		b,
		(
			"口径：建设投资、融资不计入持续经营；工资和消费为内部转账。公司在总督阶段按正经营结余收取 %.0f%%；援助追加分成另列。"
			% (float(g.sim.config.contract.company_tax_rate) * 100)
		),
		16,
		D.MUTED
	)
	for s in state.settlements:
		var c = D.card(b)
		D.label(c, s.name + " / 实际本地库存", 20)
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
	D.label(b, "出口价格（出口越多，价格越低；每日缓慢恢复）", 20, D.TEAL)
	for row_data: Dictionary in g.sim.market_view():
		D.label(
			b,
			(
				"%s  ¥ %.1f / t（基准 %.1f，%.0f%%）"
				% [
					RES.get(row_data.good, row_data.good),
					row_data.price,
					row_data.base,
					row_data.factor * 100.0
				]
			),
			16,
			D.INK if float(row_data.factor) > 0.8 else D.GOLD
		)
	D.label(b, "最近资金流水（来源 → 去向 / 金额）", 20, D.TEAL)
	var ledger: Array = state.ledger
	for i in range(ledger.size() - 1, maxi(-1, ledger.size() - (31 if g.detailed_info else 7)), -1):
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


static func transport(g, b):
	D.label(b, "矿物向港口汇集，食品向居民流动。", 25, D.TEAL)
	D.label(b, "货物在装车时离开起点仓库，在运输天数结束后才进入终点；运力有限，陆路不会穿海。第二据点的材料由拓展物资提供，后续需要加工、进口或实际运输。", 18, D.MUTED)
	var state: Dictionary = g.sim.state
	if state.settlements.size() < 2:
		D.label(b, "尚需建立第二据点。请在行星总览选择青溪河谷等可达地区。", 21, D.GOLD)
		return
	var a: int = state.settlements[0].region
	var z: int = state.settlements[1].region
	for mode in [false, true]:
		var route: Dictionary = WG.new().route(g.sim.geo, a, z, mode)
		var c = D.card(b)
		D.label(c, "工程公路（跨山）" if mode else "河谷公路（绕山）", 21)
		var road_rules: Dictionary = g.sim.config.roads["engineered" if mode else "valley"]
		(
			D
			. label(
				c,
				(
					"距离 %.0f km  ·  单程 %d 天  ·  建设 ¥ %.0f\n运力 %d t/日  ·  养护 ¥ %.1f/日  ·  封路风险 %s"
					% [
						route.distance,
						route.days,
						route.cost,
						int(road_rules.capacity),
						float(road_rules.upkeep),
						(
							"约每 %.0f 日一次" % (1.0 / float(road_rules.closure_chance_per_day))
							if float(road_rules.closure_chance_per_day) > 0.0
							else "无"
						),
					]
				),
				18,
				D.GOLD
			)
		)
		var mt = mode
		var bt = D.button(
			c,
			"线路已建成" if not state.route.is_empty() else "建设此线路",
			func(): g.act("connect", {"a": a, "b": z, "mountain": mt})
		)
		bt.disabled = not route.reachable or not state.route.is_empty()
		bt.tooltip_text = route.get("reason", "")
	if not state.route.is_empty():
		D.label(
			b,
			(
				"当前线路："
				+ str(state.route.get("distance", 0))
				+ " km  ·  "
				+ str(state.route.get("days", 0))
				+ " 天\n累计运输："
				+ str(state.get("transported_total", 0))
				+ " t"
			),
			18,
			D.TEAL
		)
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
	D.button(
		b,
		"读取上一版手动档（原文件保留）",
		func():
			g.load_path(
				(
					OS.get_environment("APPDATA")
					+ "/Godot/app_userdata/殖民契约 · COLONY CHARTER/manual.json"
				)
			)
	)
	D.label(b, "说明详细度与难度独立；所有核心规则和重要原因始终可见。", 16, D.MUTED)
	D.button(
		b,
		"当前详细记录（30条流水 / 20条事件）" if g.detailed_info else "当前精简记录（6条流水 / 6条事件）",
		g.toggle_information
	)
	D.button(
		b, "打开面板时暂停：开（关闭后恢复原速度）" if g.panel_pause else "打开面板时暂停：关（面板打开时时间继续）", g.toggle_panel_pause
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


static func guide(g, b):
	D.label(b, "推荐种子 260129 · 中型 · 资本支持", 25, D.GOLD)
	var steps = [
		"01  勘察铁岬盆地并建立首府。登陆物资包含基础住房、水电与货运能力；检查建设面板和本地库存。",
		"02  建设铁矿与铜矿（或晶体）建立出口现金流。空格继续，顶部选择正常或快进。预留劳动力与公用能力。",
		"03  加工厂把铁矿与铜矿变成建材、部件。研究所雇用研究员，优先勘探或灌溉。",
		"04  选择青溪河谷建立第二据点，建设农场。交通运输面板比较绕山和跨山，建成线路后观察在途食品。",
		"05  在就业和供应允许时批准生活服务企业。它使用自己的投资自动经营，你决定税率和供应底线。",
		"06  保有至少 7 天食品、足够住房与就业；公共经营连盈 12 天，完成合同后继续沙盒。",
		"观察  成本过高时不要盲目扩张。关闭窗口不会自动恢复时间，请用空格或顶部速度按钮。食品短缺先查本地水、电、岗位和运输。"
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
