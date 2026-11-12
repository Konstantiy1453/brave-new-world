extends RefCounted
const D = preload("res://ui/design.gd")
const Career = preload("res://simulation/career.gd")
const Labels = preload("res://ui/labels.gd")
const ResearchPage = preload("res://ui/research_page.gd")


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
			D.label(
				c,
				(
					"调查进度 %.1f / %.1f · 已保留科研团队"
					% [investigation.get("progress", 0), investigation.get("work", 0)]
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
		var next_size = D.option(
			next_row,
			"NextSize",
			["小型 · 0.6 地球半径", "中型 · 1.0 地球半径", "大型 · 1.3 地球半径"],
			int(g.sim.state.world.size)
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
								"size": next_size.selected,
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
	D.label(b, s.name + " / 批量生产与库存目标", 24, D.TEAL)
	D.label(b, "停用住区会撤销该设施住房；保留建材和部件供本地建设与跨区调拨，只有真正余量自动出口。", 17, D.MUTED)
	for category in ["all", "production"]:
		var row = D.row(b)
		var cat = category
		var caption = D.label(row, "全部公共设施" if cat == "all" else "生产设施", 18)
		caption.custom_minimum_size.x = 150
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.button(
			row,
			"批量启用",
			func(): g.act("batch_toggle", {"region": g.selected, "category": cat, "enabled": true})
		)
		D.button(
			row,
			"批量停用",
			func(): g.act("batch_toggle", {"region": g.selected, "category": cat, "enabled": false})
		)
	for key in ["food", "materials", "parts"]:
		var row = D.row(b)
		var caption = D.label(
			row, {"food": "食品目标（吨）", "materials": "建材目标（吨）", "parts": "部件目标（吨）"}[key], 18
		)
		caption.custom_minimum_size.x = 180
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Shown and typed in tonnes; the rules keep hundreds of tonnes (economy.json `display`).
		var scale: float = Labels.tonnes_per_unit()
		var amount = D.spin(
			row,
			"Target_" + key,
			0,
			maxf(10000, g.sim._target(s, key)) * scale,
			0.000001 * scale,
			g.sim._target(s, key) * scale
		)
		amount.custom_arrow_step = 0.1 * scale
		var resource = key
		D.button(
			row,
			"设置目标",
			func():
				g.act(
					"stock_target",
					{"region": g.selected, "resource": resource, "target": amount.value / scale}
				)
		)
