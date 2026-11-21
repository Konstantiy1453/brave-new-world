extends RefCounted
const D = preload("res://ui/design.gd")
const Career = preload("res://simulation/career.gd")
const Labels = preload("res://ui/labels.gd")
const ResearchPage = preload("res://ui/research_page.gd")
const RadiusSlider = preload("res://ui/radius_slider.gd")


static func populate(g, b, page: String):
	match page:
		"research":
			ResearchPage.research(g, b)
		"company":
			company(g, b)
		"events":
			events(g, b)
		"career":
			career(g, b)
		"manage":
			manage(g, b)


static func company(g, b):
	var v: Dictionary = g.sim.company_view()
	D.label(b, "公司关系 / 整改与有条件支持", 25, D.TEAL)
	var stages = {
		"normal": "正常经营",
		"warning": "关注预警",
		"review": "正式审查",
		"intervention": "有条件介入",
		"recovery": "稳定恢复"
	}
	D.label(
		b,
		(
			"不信任 %.1f / 100 · %s"
			% [v.get("distrust", 0), stages.get(v.get("stage", "normal"), v.get("stage", ""))]
		),
		23,
		D.GOLD
	)
	D.label(b, str(v.get("summary", v.get("reason", "公司根据真实的逾期和社会问题评估；投资期亏损本身不等于违约。"))), 18)
	for source in v.get("sources", {}).values():
		if float(source.rate) > 0:
			D.label(
				b,
				"%s · 持续 %d 日 · 本日 +%.2f" % [source.reason, source.days, source.rate],
				17,
				D.MUTED
			)
	D.label(
		b,
		(
			"整改期限：%s · 本日变化 %+.2f"
			% [
				Labels.short_date(int(v.deadline)) if int(v.get("deadline", -1)) >= 0 else "暂无",
				float(v.get("delta", 0))
			]
		),
		18
	)
	D.label(b, str(v.get("remedy", "优先恢复食品和住房，清偿到期欠款；暂停非必要扩张，调拨库存，必要时接受有条件援助。")), 17, D.MUTED)
	for offer in v.get("offers", []):
		var description = (
			"援助现金 %.0f，食品 %s，建材 %s，部件 %s；%d日后抵达。\n期限%d日，偿还%.0f；期间正经营结余追加分成%.0f%%。仅从超过%.0f现金保底的部分分期偿还。每方案一生涯当前星球仅可领取一次。"
			% [
				offer.cash,
				Labels.t(float(offer.food)),
				Labels.t(float(offer.materials)),
				Labels.t(float(offer.parts)),
				offer.arrival_days,
				offer.duration,
				offer.repayment,
				offer.surcharge * 100,
				offer.cash_floor
			]
		)
		if int(offer.get("target_region", -1)) >= 0:
			description += (
				"\n送达：%s（当前最缺这批物资的据点）。" % g.sim.state.world.regions[int(offer.target_region)].name
			)
		var c = D.card(b)
		D.label(c, str(offer.get("title", offer.get("name", "公司援助"))), 22, D.TEAL)
		D.label(c, description, 17)
		var id = str(offer.get("id", ""))
		var bt = D.button(
			c,
			"查看并接受条款",
			func():
				var confirm = ConfirmationDialog.new()
				confirm.dialog_text = description + "\n确认接受上述义务？"
				g.add_child(confirm)
				confirm.confirmed.connect(
					func():
						g.act("company", {"operation": "accept", "offer": id})
						confirm.queue_free()
				)
				confirm.popup_centered(Vector2i(700, 340))
		)
		bt.disabled = bool(offer.get("claimed", false)) or v.get("stage", "normal") == "normal"
		bt.tooltip_text = str(offer.get("reason", ""))
	var dirt: Dictionary = g.sim.pollution_view()
	var air = D.card(b)
	D.label(air, "星球污染（不影响公司评价）", 20, D.TEAL)
	D.label(
		air,
		(
			"累积负荷 %.0f · 每日排放 %.1f / 星球吸收 %.1f · 产出损失 %.1f%%"
			% [
				float(dirt.load),
				float(dirt.emitted),
				float(dirt.absorbed),
				float(dirt.penalty) * 100.0
			]
		),
		17
	)
	D.label(air, "排放低于吸收时不会累积。负荷越高，后果越是成倍地放大：产出下降、吸引力下降、医疗开支上升。", 15, D.MUTED)
	D.button(
		air,
		"出资治理 · 支出 ¥ %.0f / 负荷 -%.0f" % [float(dirt.cleanup_cost), float(dirt.cleanup_amount)],
		func(): g.act("company", {"operation": "cleanup"}),
		"",
		"CleanupButton"
	)
	for a in v.get("aid", []):
		D.label(
			D.card(b),
			(
				"%s · %s · 偿还 %.2f / %.2f · 第%d日到期"
				% [
					a.name,
					(
						{
							"in_transit": "运输中",
							"active": "履行中",
							"fulfilled": "已履行",
							"breached": "待补缴",
							"cancelled": "已取消"
						}
						. get(a.status, a.status)
					),
					a.paid,
					a.repayment,
					a.end_day
				]
			),
			17,
			D.GOLD
		)
	for line in v.get("letters", []).slice(-12):
		D.label(b, "第%d日 · %s" % [line.day, line.reason], 15, D.MUTED)


static func events(g, b):
	var v: Dictionary = load("res://simulation/events_v2.gd").view(g.sim)
	D.label(b, "殖民通讯 / 选择与后续", 25, D.TEAL)
	var stop_all: bool = str(g.sim.state.policy.get("event_pause", "critical")) == "all"
	D.label(
		b, "通知不会暂停世界，到期按默认方案处理；关键决定会暂停。" if not stop_all else "所有决定都会暂停世界；通知到期按默认方案处理。", 17, D.MUTED
	)
	var pause_row = D.row(b)
	D.label(pause_row, "决定是否暂停：", 16, D.MUTED, false)
	D.option(
		pause_row,
		"EventPause",
		["仅关键决定", "全部决定"],
		1 if stop_all else 0,
		func(id): g.act("policy", {"event_pause": "all" if id == 1 else "critical"})
	)
	D.label(b, "决定节点暂停世界；选择“稍后处理”才会继续计时。调查占用科研人员，订单按真实交付结算。", 17, D.MUTED)
	for node in v.get("pending", []):
		var c = D.card(b)
		var notice: bool = str(node.get("kind", "decision")) == "notice"
		D.label(c, ("通知 · " if notice else "决定 · ") + str(node.get("title", "通讯")), 22, D.GOLD)
		D.label(c, str(node.get("text", "")), 18)
		D.label(
			c,
			(
				"%s 截止 · 还有 %s 天"
				% [
					Labels.short_date(int(node.get("deadline", 0))),
					str(node.get("remaining_days", "—"))
				]
			),
			16,
			D.TEAL
		)
		for choice in node.get("choices", []):
			var instance = str(node.instance_id)
			var id = str(choice.id)
			D.label(c, str(choice.label), 17)
			var bt = D.button(
				c, "选择此方案", func(): g.act("event_v2", {"instance_id": instance, "choice": id})
			)
			bt.disabled = not bool(choice.get("enabled", true))
			bt.tooltip_text = str(choice.get("reason", ""))
	if v.get("pending", []).is_empty():
		D.label(b, "目前没有需要答复的节点。", 20)
	for node in v.get("active", []):
		if node.status != "waiting":
			continue
		var c = D.card(b)
		D.label(c, str(node.title) + " / 进行中", 21, D.TEAL)
		var investigation: Dictionary = node.variables.get("investigation", {})
		if not investigation.is_empty():
			var report: int = int(node.get("report_day", -1))
			D.label(
				c,
				(
					"调查进度 %.1f / %.1f · 已保留科研团队 · %s"
					% [
						investigation.get("progress", 0),
						investigation.get("work", 0),
						"预计 %s 回报" % g.Events._date(report) if report >= 0 else "团队不在岗，调查暂停"
					]
				),
				17
			)
		if not node.order.is_empty():
			D.label(
				c,
				(
					"订单已发 %s / 已到 %s · 已付款 %.2f"
					% [
						Labels.t(float(node.order.get("dispatched", 0))),
						Labels.t(float(node.order.get("delivered", 0))),
						node.order.get("paid", 0)
					]
				),
				17
			)
		for choice in node.choices:
			var instance = str(node.instance_id)
			var id = str(choice.id)
			D.button(
				c,
				str(choice.label),
				func(): g.act("event_v2", {"instance_id": instance, "choice": id})
			)
	for section in ["effects", "history"]:
		D.label(
			b, {"active": "正在进行", "effects": "仍生效的影响", "history": "事件结局与选择记录"}[section], 20, D.TEAL
		)
		for row in v.get(section, []).slice(-20 if g.detailed_info else -6):
			if row is Dictionary:
				D.label(
					b,
					(
						str(row.get("title", row.get("definition_id", row.get("kind", ""))))
						+ " · "
						+ str(
							row.get(
								"text",
								row.get(
									"summary",
									row.get("ending", row.get("factor", row.get("node", "")))
								)
							)
						)
					),
					16,
					D.MUTED
				)
				# An ending keeps its scene (what happened, in the event's own words), or else
				# what changed.
				var scene: String = str(row.get("outcome", row.get("changes", "")))
				if section == "history" and scene != "":
					D.label(b, "　" + scene, 15, D.MUTED)
			else:
				D.label(b, str(row), 16, D.MUTED)


## Career transfer after the award: idle public cash into career funds, at a loss, capped a year.
static func _career_transfer(g, b) -> void:
	var view: Dictionary = Career.transfer_preview(g.sim)
	if not bool(view.open):
		return
	D.label(
		b,
		(
			"生涯资金转存：公共现金 ¥ %.0f 换 ¥ 1 生涯资金，每年最多 ¥ %.0f；今年还可转 ¥ %.0f，累计已转 ¥ %.0f。"
			% [float(view.rate), float(view.cap), float(view.room), float(view.transferred)]
		),
		17,
		D.MUTED
	)
	if float(view.most) < 1.0:
		return
	var row = D.row(b)
	var amount = D.spin(
		row, "TransferAmount", 1, float(view.most), 1, minf(float(view.most), 10000.0)
	)
	D.button(
		row,
		"转存为生涯资金",
		func(): g.act("career_transfer", {"amount": amount.value}),
		"",
		"CareerTransfer"
	)


static func career(g, b):
	Career.ensure(g.sim)
	var c: Dictionary = g.sim.state.career
	D.label(b, "连续生涯 / 旧星代管与新远征", 25, D.TEAL)
	D.label(
		b,
		(
			"生涯第 %d 日 · 当前第 %d 颗星球 · 登陆第 %d 日\n可用生涯资金 ¥ %.2f"
			% [c.global_day, c.active_id, g.sim.state.day, c.balance]
		),
		21,
		D.GOLD
	)
	D.label(b, "30日为一个月，360日为一年。暂停时旧星也暂停。分红先进入生涯资金；注资不计入新星球经营利润。", 17, D.MUTED)
	var row = D.row(b)
	var amount = D.spin(row, "InvestAmount", 0, float(c.balance), 1, minf(float(c.balance), 500))
	D.button(row, "注入当前星球", func(): g.career_action("invest", {"amount": amount.value}))
	_career_transfer(g, b)
	for old in c.managed:
		var card = D.card(b)
		D.label(card, "代管星球 %d · 种子 %s" % [old.id, str(old.seed)], 22, D.TEAL)
		(
			D
			. label(
				card,
				(
					"本地周转 ¥ %.2f / 目标 %.2f · 待付 %.2f\n上期玩家分红 %.2f · 累计 %.2f · 代管方累计 %.2f\n公司累计 %.2f · 有限矿业剩余可售价值 %.0f"
					% [
						old.reserve,
						old.reserve_target,
						old.debt,
						old.last_dividend,
						old.player_total,
						old.manager_total,
						old.company_total,
						old.mine_remaining
					]
				),
				17
			)
		)
	if g.sim.state.status == "success":
		var p: Dictionary = Career.preview(g.sim)
		D.label(b, "总督交接预览", 23, D.TEAL)
		D.label(
			b,
			(
				"参考最近 %d 日；日收入 %.2f / 日成本 %.2f\n周转留存 %.2f · 玩家分成 %.0f%% · 稳态月分红估计 %.2f"
				% [
					p.sample_days,
					p.daily_income,
					p.daily_cost,
					p.reserve_target,
					p.player_share * 100,
					p.monthly_estimate
				]
			),
			18,
			D.GOLD
		)
		D.label(b, p.warning + " 代管方取得剩余分成，不另收管理费。旧星的救助附加义务保留。", 17, D.MUTED)
		D.label(b, "下一颗星球", 20, D.TEAL)
		var next_row = D.row(b)
		var next_seed = D.line_edit(next_row, "NextSeed", str(int(g.sim.state.world.seed) + 1))
		next_seed.custom_minimum_size.x = 170
		var next_radius: HSlider = RadiusSlider.add(
			b, "NextRadius", float(g.sim.state.world.radius_km) / 6371.0, true
		)
		var opening_keys: Array = g.sim.config.openings.keys()
		var opening_names: Array = []
		for key: String in opening_keys:
			opening_names.append(str(g.sim.config.openings[key].name))
		var next_opening = D.option(
			next_row, "NextOpening", opening_names, opening_keys.find(g.sim.state.advantage)
		)
		var level_keys: Array = ["easy", "normal", "hard"]
		var next_level = D.option(
			next_row,
			"NextDifficulty",
			["简单", "标准", "困难"],
			level_keys.find(g.sim.state.get("difficulty", "normal"))
		)
		D.button(
			b,
			"确认交接并前往下一颗星球",
			func():
				var dialog = ConfirmationDialog.new()
				dialog.dialog_text = "保留旧星完整快照并交给代管，开始新星球合同。只有完整生涯存档写入成功才提交交接。"
				g.add_child(dialog)
				dialog.confirmed.connect(
					func():
						g.career_action(
							"handover",
							{
								"seed": next_seed.text,
								"radius": next_radius.value,
								"opening": opening_keys[next_opening.selected],
								"difficulty": level_keys[next_level.selected]
							}
						)
						dialog.queue_free()
				)
				dialog.popup_centered(Vector2i(700, 260))
		)
	else:
		D.label(b, "取得当前星球总督资格后可移交；现在仍可查看已取得的代管资产。", 18, D.MUTED)
	var level = D.option(
		b,
		"RestartDifficulty",
		["简单", "标准", "困难"],
		["easy", "normal", "hard"].find(g.sim.state.get("difficulty", "normal"))
	)
	D.button(
		b,
		"恢复本次登陆检查点 / 按选定难度重开",
		func():
			var dialog = ConfirmationDialog.new()
			dialog.dialog_text = "恢复本星登陆时的完整生涯，包括全局时间、余额、旧星结算账期和随机状态。本次尝试取得的分红与投资一并撤回。"
			g.add_child(dialog)
			dialog.confirmed.connect(
				func():
					g.career_action(
						"restart", {"difficulty": ["easy", "normal", "hard"][level.selected]}
					)
					dialog.queue_free()
			)
			dialog.popup_centered(Vector2i(700, 260))
	)


static func manage(g, b):
	var s: Dictionary = g.settlement()
	if s.is_empty():
		D.label(b, "请选择已建立的据点。", 20)
		return
	D.label(b, s.name + " / 库存与生产", 24, D.TEAL)
	D.label(
		b,
		"每种物资两个设定：「本地保留」是至少留在本据点的数量，自动出口、供货合同和外调都停在它上面；「减产线」是库存到多少就停止生产。保留高于减产线时，生产会一直补到保留量。默认（自动）就是 1.10 的规则，只在需要时调整。",
		16,
		D.MUTED
	)
	var shifts: HBoxContainer = D.row(b)
	var shift_words: Label = D.label(
		shifts,
		"自动减班：%s · 库存达到减产线、当天没有产出的设施，职工保留岗位、按 %.0f%% 工资减班；需求回升自动恢复"
		% [
			"开" if bool(s.get("auto_shifts", true)) else "关",
			float(g.sim.config.get("shifts", {}).get("reduced_wage", 1.0)) * 100.0
		],
		15,
		D.INK
	)
	shift_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var region: int = int(s.region)
	D.button(
		shifts,
		"关闭减班" if bool(s.get("auto_shifts", true)) else "开启减班",
		func(): g.act("shifts", {"region": region, "enabled": not bool(s.get("auto_shifts", true))}),
		"",
		"ToggleShifts"
	)
	for reservation: Dictionary in s.get("reservations", []):
		var held: HBoxContainer = D.row(b)
		var kind: String = str(reservation.kind)
		var note: Label = D.label(
			held,
			(
				"为计划工程「%s」预留：建材 %s · 部件 %s"
				% [
					Labels.building_name(g.sim.config, kind),
					Labels.t(float(reservation.materials)),
					Labels.t(float(reservation.parts))
				]
			),
			15,
			D.GOLD
		)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.button(
			held,
			"取消预留",
			func(): g.act("reserve_release", {"region": region, "kind": kind}),
			"",
			"Release_" + kind
		)
	for good: String in g.sim.KEYS:
		var row: Dictionary = g.sim.Stocks.availability(g.sim, s, good)
		var produced: bool = float(row.total) > 0.0 or bool(row.keep_set) or bool(row.slowdown_set)
		if not produced and not good in ["food", "materials", "parts"]:
			continue
		_stock_card(g, b, s, good, row)
	D.label(b, "批量启用 / 停用", 18, D.TEAL)
	for category in ["all", "production"]:
		var line = D.row(b)
		var cat = category
		var caption = D.label(line, "全部公共设施" if cat == "all" else "生产设施", 18)
		caption.custom_minimum_size.x = 150
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.button(
			line,
			"批量启用",
			func(): g.act("batch_toggle", {"region": g.selected, "category": cat, "enabled": true})
		)
		D.button(
			line,
			"批量停用",
			func(): g.act("batch_toggle", {"region": g.selected, "category": cat, "enabled": false})
		)


## One good: what the warehouse holds, what is held back and for whom, what can be sold (the same
## figure the trade sells), and the two controls.
static func _stock_card(g, b, s: Dictionary, good: String, row: Dictionary) -> void:
	var card: VBoxContainer = D.card(b)
	card.add_theme_constant_override("separation", 4)
	var name: String = str(Labels.RESOURCE_NAMES.get(good, good))
	var held: PackedStringArray = []
	for entry: Dictionary in row.held:
		if float(entry.amount) > 0.0:
			held.append("%s %s" % [str(entry.name), Labels.t(float(entry.amount))])
	var slowdown: float = g.sim.Production.target(g.sim, s, good)
	var words: Label = D.label(
		card,
		(
			"%s：库存 %s · 留用 %s（%s）· 可售 %s · 减产线 %s"
			% [
				name,
				Labels.t(float(row.total)),
				Labels.t(float(row.held_total)),
				"、".join(held) if not held.is_empty() else "无",
				Labels.t(float(row.sellable)),
				Labels.t(slowdown),
			]
		),
		16,
		D.INK
	)
	D.named(words, "Stock_" + good)
	var scale: float = Labels.tonnes_per_unit()
	var region: int = int(s.region)
	var limit: float = float(g.sim.config.get("stock_rules", {}).get("max_units", 10000.0)) * scale
	for control: Array in [["reserve", "本地保留"], ["slowdown", "减产线"]]:
		var key: String = str(control[0])
		var line: HBoxContainer = D.row(card)
		var chosen: float = (
			g.sim.Stocks.set_reserve(s, good)
			if key == "reserve"
			else g.sim.Stocks.set_slowdown(s, good)
		)
		var shown: float = chosen if chosen >= 0.0 else (
			float(row.keep) if key == "reserve" else slowdown
		)
		var caption: Label = D.label(
			line, "%s（%s）" % [str(control[1]), "已设定" if chosen >= 0.0 else "自动"], 15, D.MUTED, false
		)
		caption.custom_minimum_size.x = 140
		var amount = D.spin(line, "%s_%s" % [key.capitalize(), good], 0, limit, 0.1 * scale, shown * scale)
		amount.custom_arrow_step = 10.0 * scale
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.button(
			line,
			"设定",
			func(): g.act("stock_rule", {"region": region, "resource": good, key: amount.value / scale}),
			"按吨输入",
			"Set_%s_%s" % [key, good]
		)
		D.button(
			line,
			"自动",
			func(): g.act("stock_rule", {"region": region, "resource": good, key: -1.0}),
			"回到默认规则",
			"Auto_%s_%s" % [key, good]
		)
