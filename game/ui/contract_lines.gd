extends RefCounted
## The contract page's cards (split from pages.gd in 1.11): the current stage's outlook, each stage
## with its goals, their trend and the action that helps, stage three's routes; and the two pages
## that come from the contract's controls — the summary of an "advance to the next decision" run and
## the short choice of towns that can carry out a goal's action.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")


## Several towns can carry out a goal's action: each with why it qualifies.
static func goal_choice(g, b):
	var choice: Dictionary = g.goal_choice
	D.label(b, "哪个据点来做：%s" % str(choice.get("action", {}).get("text", "")), 20, D.GOLD)
	for town: Dictionary in choice.get("towns", []):
		var line: HBoxContainer = D.row(b)
		var words: Label = D.label(line, "%s：%s" % [str(town.name), str(town.why)], 16, D.INK)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var region: int = int(town.region)
		var action: Dictionary = choice.action
		var category: String = str(town.get("category", ""))
		D.button(
			line, "去这里", func(): g._open_for(region, action, category), "", "GoalTown_%d" % region
		)


## What happened while the colony ran on its own, and why it stopped.
static func advance_summary(g, b):
	var run: Dictionary = g.advance_summary
	if run.is_empty():
		D.label(b, "还没有推进过。", 18, D.MUTED)
		return
	var head: Label = D.label(
		b,
		"%s → %s · 停在：%s" % [Labels.date(int(run.from)), Labels.date(int(run.to)), str(run.reason)],
		21,
		D.GOLD
	)
	D.named(head, "AdvanceReason")
	(
		D
		. label(
			b,
			(
				"%d 天 · 资金 %+.0f · 出口和交付 +¥%s · 人口 %+d · 完工 %d 项 · 新技术 %d 项 · 合同第 %d 阶段"
				% [
					int(run.to) - int(run.from),
					float(run.cash),
					g.money(float(run.exports)),
					int(run.population),
					int(run.built),
					int(run.techs),
					int(run.stage),
				]
			),
			17,
			D.INK
		)
	)
	var outlook: Dictionary = g.sim.outlook_view()
	if int(outlook.get("eta", -1)) >= 0 and bool(outlook.get("completes_by_waiting", false)):
		D.label(b, "照现在的安排，本阶段约 %s 完成，不需要新的命令。" % Labels.short_date(int(outlook.eta)), 16, D.TEAL)
	var row: HBoxContainer = D.row(b)
	D.button(row, "继续推进", func(): g.start_advance(), "", "AdvanceAgain", "primary")
	D.button(row, "看合同", func(): g.open_page("contract"), "", "AdvanceContract")
	D.label(b, "途中的消息（%d 条）" % run.lines.size(), 16, D.TEAL)
	var shown: Array = run.lines.slice(maxi(0, run.lines.size() - 60))
	D.label(b, "\n".join(PackedStringArray(shown)), 14, D.MUTED)


static func stage_card(g, b, stage: Dictionary, current: int):
	var card = D.card(b)
	var done: bool = int(stage.completed_day) >= 0
	var head: String = str(Labels.STAGE_NAMES.get(stage.id, stage.id))
	if done:
		head += "  ·  %s 完成" % Labels.short_date(int(stage.completed_day))
	elif int(stage.stage) == current:
		head += "  ·  期限 %s" % Labels.short_date(int(stage.deadline))
	D.label(card, head, 21, D.GOLD if int(stage.stage) == current else D.TEAL)
	var rewards: PackedStringArray = []
	if float(stage.reward_cash) > 0.0:
		rewards.append("发展资金 ¥ %.0f" % float(stage.reward_cash))
	if str(stage.licence) != "":
		rewards.append(str(Labels.LICENCE_NAMES.get(stage.licence, stage.licence)))
	if int(stage.stage) == g.sim.Contract.STAGE_COUNT:
		rewards.append("总督资格")
	D.label(card, "奖励：" + "、".join(rewards), 16, D.MUTED)
	if done or int(stage.stage) > current:
		return
	var outlook: Dictionary = {}
	if int(stage.stage) == current and g.sim.state.status == "active":
		for row: Dictionary in g.sim.outlook_view().get("goals", []):
			outlook[str(row.key)] = row
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
		var look: Dictionary = outlook.get(str(goal_row.key), {})
		if not look.is_empty() and not goal_row.ok:
			_status_tag(line, look)
		if not goal_row.ok and (str(text.page) != "" or not look.get("action", {}).is_empty()):
			var action: Dictionary = look.get("action", {}).duplicate()
			if action.is_empty():
				action = {"page": str(text.page), "text": str(text.hint)}
			var fix = D.button(
				line,
				"去处理",
				func(): g.goal_action(action),
				str(action.get("text", text.hint)),
				"GoalFix_" + str(goal_row.key)
			)
			D.font_size(fix, 14)
			fix.custom_minimum_size.y = 30
		elif not goal_row.ok:
			D.label(line, str(text.hint), 15, D.MUTED, false)
		if not look.is_empty() and not goal_row.ok:
			_outlook_lines(g, card, look)
		if str(goal_row.key) == "operating_route":
			_route_lines(g, card)


## The current stage at a glance (1.11): when it should complete and what limits it, whether that
## happens if the colony is left to run, and the settlement cap.
static func outlook_head(g, b) -> void:
	var outlook: Dictionary = g.sim.outlook_view()
	var card: VBoxContainer = D.card(b)
	var cap: Dictionary = g.sim.Contract.cap_view(g.sim)
	var words: String = ""
	if int(outlook.get("eta", -1)) >= 0:
		words = (
			"本阶段预计 %s 完成（期限 %s）"
			% [Labels.short_date(int(outlook.eta)), Labels.short_date(int(outlook.deadline))]
		)
		if str(outlook.bottleneck) != "":
			words += (
				"，最慢的是「%s」"
				% (
					str(Labels.goal({"key": outlook.bottleneck, "value": 0, "target": 0}).text)
					. split(" ")[0]
				)
			)
		if bool(outlook.completes_by_waiting):
			words += "。照现在的安排就能完成，不需要新的命令：可以用「⏩ 下一个决定」推进"
	else:
		words = "本阶段照现在的安排完不成：下面标「需要你出手」的目标在等你"
	var head: Label = D.label(
		card, words, 17, D.TEAL if bool(outlook.get("completes_by_waiting", false)) else D.GOLD
	)
	D.named(head, "OutlookHead")
	for row: Dictionary in outlook.get("goals", []):
		if row.has("commission"):
			var commission: Dictionary = row.commission
			var line: Label = D.label(
				card,
				(
					"委托研究：在研课题全部委托（每天约 ¥%.0f），完成技术约提前 %d 天，到 %s"
					% [
						float(commission.cost_per_day),
						int(commission.saves),
						Labels.short_date(int(commission.eta))
					]
				),
				15,
				D.INK
			)
			D.named(line, "OutlookCommission")
	D.label(
		card,
		(
			"据点：%d / %s 处（含首府；本阶段上限，完成后升为 %s）"
			% [
				int(cap.used),
				"不限" if bool(cap.unlimited) else str(int(cap.cap)),
				"不限" if bool(cap.next_unlimited) else "%d 处" % int(cap.next_cap)
			]
		),
		15,
		D.MUTED
	)


static func _status_tag(line: Control, look: Dictionary) -> void:
	match str(look.status):
		"on_track":
			D.tag(line, "会完成 · %s" % Labels.short_date(int(look.eta)), D.TEAL)
		"late":
			D.tag(line, "会完成但超期 · %s" % Labels.short_date(int(look.eta)), D.GOLD)
		_:
			D.tag(line, "需要你出手", D.RED)


## A goal's trend, what holds it back, and the projects that count for technologies.
static func _outlook_lines(_g, card: Control, look: Dictionary) -> void:
	var trend: Dictionary = look.get("trend", {})
	var parts: PackedStringArray = []
	if int(trend.get("span", 0)) > 0:
		var per_day: float = float(trend.per_day)
		var value: String = (
			"%+.1f%%" % (per_day * 100.0) if float(look.target) <= 1.0 else "%+.1f" % per_day
		)
		parts.append("近 %d 天每天 %s" % [int(trend.span), value])
	if str(look.get("holding", "")) != "":
		parts.append("卡在：" + str(look.holding))
	var action: Dictionary = look.get("action", {})
	if action.has("cost"):
		parts.append(
			"办法：%s，¥%.0f，%s" % [str(action.text), float(action.cost), str(action.get("effect", ""))]
		)
	elif action.has("teams"):
		parts.append("可派研究团队 %d 支" % int(action.teams))
	if not parts.is_empty():
		var line: Label = D.label(card, "　" + " · ".join(parts), 14, D.MUTED)
		D.named(line, "Outlook_" + str(look.key))
	for project: Dictionary in look.get("projects", []):
		D.label(
			card,
			(
				"　　%s：%s"
				% [
					str(project.name),
					(
						"约 %d 天后完成" % int(project.days_left)
						if bool(project.progressing)
						else "没有进展（%s）" % str(project.reason)
					)
				]
			),
			13,
			D.MUTED
		)


## Stage three's three routes, each with its measures over the last 30 days (operating_routes.gd).
static func _route_lines(g, card: Control) -> void:
	for route: Dictionary in g.sim.Contract.OperatingRoutes.view(g.sim):
		var parts: PackedStringArray = []
		for part: Dictionary in route.parts:
			var value: float = float(part.value)
			var target: float = float(part.target)
			if target < 1.0:
				parts.append("%s %.0f%% / %.0f%%" % [part.label, value * 100.0, target * 100.0])
			elif str(part.label) == "沿海据点":
				parts.append("%s %d / %d" % [part.label, int(value), int(target)])
			else:
				parts.append("%s %s / %s" % [part.label, Labels.t(value), Labels.t(target)])
		D.label(
			card,
			"　%s %s：%s" % ["✓" if bool(route.ok) else "·", route.name, " · ".join(parts)],
			15,
			D.TEAL if bool(route.ok) else D.MUTED
		)
