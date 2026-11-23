extends RefCounted
## The contract as a document (1.11): the company's title for the project, the numbered clauses
## (第 N 条) written from contract.json `document` and the rules, the five stages as milestones that
## receive an acceptance stamp when completed, the signed amendments (补充协议 N) and the sealed
## Annex VII. The goals of the stage in progress stay under its milestone, with their shortcuts.
## Functional only: a later interface pass restyles it without touching the rules.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Contract = preload("res://simulation/contract.gd")
const OriginCards = preload("res://ui/origin_cards.gd")
const STAMP_COLOR: Color = Color("d0604f")
const STATUS_WORDS: Dictionary = {
	"planning": "待签署",
	"active": "履行中",
	"success": "已履行完毕",
	"failed": "已终止",
}


static func page(g, b) -> void:
	_header(g, b)
	D.heading(b, "合同条款")
	for clause: Dictionary in clauses(g.sim):
		var card: VBoxContainer = D.card(b, "card_quiet")
		D.label(card, "第 %d 条　%s" % [int(clause.number), str(clause.title)], 19, D.GOLD)
		D.label(card, str(clause.text), 16)
	D.heading(b, "阶段验收")
	var view: Dictionary = g.sim.contract_view()
	for stage: Dictionary in view.stages:
		_milestone(g, b, stage, int(view.current))
	if str(g.sim.state.status) == "success":
		D.label(b, "行星里程碑（可选）：已达成 %d 项" % view.milestones.size(), 18, D.TEAL)
	_amendments(g, b)
	_annex(g, b)


## The standard clauses in order, then the clauses of the colony's contract type (1.11 origins),
## numbered and filled from the rules: {id, number, title, text}.
static func clauses(sim: RefCounted) -> Array:
	var values: Dictionary = clause_values(sim)
	var out: Array = []
	var document: Dictionary = sim.contract_rules.get("document", {})
	var removed: Array = sim.state.contract.get("removed_clauses", [])
	for clause: Dictionary in document.get("clauses", []):
		var gone: bool = str(clause.id) in removed
		(
			out
			. append(
				{
					"id": str(clause.id),
					"number": out.size() + 1,
					"title": str(clause.title) + ("（已由补充协议删除）" if gone else ""),
					"text": "本条已删除。" if gone else fill(str(clause.text), values),
				}
			)
		)
	var entry: Dictionary = origin_entry(sim)
	for id: Variant in entry.get("clauses", []):
		var clause: Dictionary = document.get("origin_clauses", {}).get(str(id), {})
		if clause.is_empty():
			continue
		(
			out
			. append(
				{
					"id": str(id),
					"number": out.size() + 1,
					"title": str(clause.title),
					"text": OriginCards.fill(sim, entry, str(clause.text)),
				}
			)
		)
	for id: Variant in sim.state.contract.get("added_clauses", []):
		var added: Dictionary = document.get("amendment_clauses", {}).get(str(id), {})
		if not added.is_empty():
			(
				out
				. append(
					{
						"id": str(id),
						"number": out.size() + 1,
						"title": str(added.title),
						"text": fill(str(added.text), values),
					}
				)
			)
	return out


## What a signed amendment changed, in words, from its terms (contract.gd `amend`).
static func amendment_terms(sim: RefCounted, record: Dictionary) -> String:
	var document: Dictionary = sim.contract_rules.get("document", {})
	var parts: PackedStringArray = []
	if record.has("deadline_shift"):
		parts.append(
			"第 %d 阶段验收期限顺延 %d 日" % [int(record.get("stage", 1)), int(record.deadline_shift)]
		)
	if record.has("company_share"):
		parts.append("授权后公司经营分成提高 %s 个百分点" % _number(float(record.company_share)))
	if record.has("kpi_scale"):
		parts.append("下一年度报告指标 ×%s" % _number(float(record.kpi_scale)))
	if record.has("add_clause"):
		var added: Dictionary = document.get("amendment_clauses", {}).get(
			str(record.add_clause), {}
		)
		parts.append("增加条款「%s」" % str(added.get("title", record.add_clause)))
	if record.has("remove_clause"):
		var title: String = str(record.remove_clause)
		for clause: Dictionary in document.get("clauses", []):
			if str(clause.id) == title:
				title = str(clause.title)
		parts.append("删除条款「%s」" % title)
	return "；".join(parts) + "。"


## The colony's contract type as signed: its entry, with the advance as the difficulty scales it.
static func origin_entry(sim: RefCounted) -> Dictionary:
	var entry: Dictionary = sim.config.openings.get(str(sim.state.advantage), {}).duplicate(true)
	if entry.has("cash"):
		var difficulty: Dictionary = sim.progression.difficulty[sim.state.get(
			"difficulty", "normal"
		)]
		entry.cash = float(entry.cash) * float(difficulty.capital)
	return entry


## The document's title for this colony: "CC-NN 项目殖民开发承包合同（对赌协议）".
static func title(sim: RefCounted) -> String:
	var rule: Dictionary = sim.contract_rules.get("document", {})
	return fill(str(rule.get("title", "{code}")), clause_values(sim))


## What the clause templates can name, as text: the code, the stage deadlines and rewards, the
## overdue distrust, the rating bands, the thresholds and windows, and the post-award share.
static func clause_values(sim: RefCounted) -> Dictionary:
	var doc: Dictionary = Contract.document(sim)
	var deadlines: PackedStringArray = []
	var rewards: PackedStringArray = []
	for stage: Dictionary in doc.stages:
		var name: String = str(Labels.STAGE_NAMES.get(stage.id, stage.id))
		deadlines.append("%s %s 前" % [name, Labels.date(int(stage.deadline))])
		if float(stage.reward) > 0.0:
			rewards.append("%s ¥ %.0f" % [name, float(stage.reward)])
	return {
		"code": str(doc.code),
		"stage_deadlines": "；".join(deadlines),
		"stage_rewards": "；".join(rewards),
		"overdue_distrust": _number(float(doc.overdue_distrust)),
		"rating_a_below": "%.0f" % float(doc.rating_a_below),
		"warning_threshold": "%.0f" % float(doc.warning_threshold),
		"review_threshold": "%.0f" % float(doc.review_threshold),
		"intervention_threshold": "%.0f" % float(doc.intervention_threshold),
		"review_days": "%d" % int(doc.review_days),
		"intervention_days": "%d" % int(doc.intervention_days),
		"player_share": "%.0f" % (float(doc.player_share) * 100.0),
	}


static func fill(text: String, values: Dictionary) -> String:
	for key: String in values:
		text = text.replace("{%s}" % key, str(values[key]))
	return text


## 0.3 as "0.3", 2.0 as "2": a rule's number as a person writes it.
static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return ("%.2f" % value).rstrip("0")


static func _header(g, b) -> void:
	var state: Dictionary = g.sim.state
	var row: HBoxContainer = D.row(b)
	D.portrait(row, "liaison", 210, 320)
	var v: VBoxContainer = D.col(row)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(v, title(g.sim), 24, D.GOLD)
	var status: String = str(state.status)
	var entry: Dictionary = origin_entry(g.sim)
	D.label(
		v,
		"合同类型：%s　·　状态：%s" % [str(entry.get("name", "")), str(STATUS_WORDS.get(status, status))],
		18,
		D.TEAL
	)
	D.label(v, str(entry.get("story", "")), 16, D.MUTED)
	D.label(v, "分五个阶段，用六到八年建起一座配得上首府之名的城市。完成阶段可获得发展资金和新据点许可；错过期限不会立刻判负，但公司的不信任会慢慢上升。", 17)
	_opening_line(g, v)
	if status == "planning":
		D.button(v, "接受协议，开始勘察  →", g.close_modal)
	elif status == "success":
		D.button(v, "继续担任总督 / 沙盒经营", g.close_modal)
		D.button(v, "查看 B 代管与下一颗星球", func(): g.open_page("career"))
	elif status == "failed":
		D.label(v, str(state.get("failure_reason", "经营条件未达标。")), 18, D.RED)
		D.button(v, "失败报告 / 恢复登陆检查点", func(): g.open_page("career"))
		D.button(v, "查看公司审查经过", func(): g.open_page("company"))
	else:
		D.button(v, "返回经营", g.close_modal)


static func _opening_line(g, v: VBoxContainer) -> void:
	var state: Dictionary = g.sim.state
	var op: Dictionary = g.sim.config.openings[state.advantage]
	var capital: float = float(
		g.sim.progression.difficulty[state.get("difficulty", "normal")].capital
	)
	var crews: int = int(g.sim.pop_rules.get("crews", {}).get("opening", 0))
	D.label(
		v,
		(
			"开局支持：¥ %.0f；食品 %s、建材 %s、部件 %s。职工 %d 人、工程队 %d 支（每支计 1 人）、研究团队 %d 支（每支计 1 人）、未成年 %d 人。"
			% [
				float(op.cash) * capital,
				Labels.t(float(op.food)),
				Labels.t(float(op.materials)),
				Labels.t(float(op.parts)),
				int(op.workers) - crews,
				crews,
				op.scientists,
				op.children
			]
		),
		17,
		D.TEAL
	)


## One stage as a milestone: its deadline and rewards, the stamp once accepted, and the goals of
## the stage in progress.
static func _milestone(g, b, stage: Dictionary, current: int) -> void:
	var card: VBoxContainer = D.card(b, "card_on" if int(stage.stage) == current else "card")
	var done: bool = int(stage.completed_day) >= 0
	var line: HBoxContainer = D.row(card)
	var head: String = str(Labels.STAGE_NAMES.get(stage.id, stage.id))
	if not done:
		head += "  ·  期限 %s" % Labels.short_date(int(stage.deadline))
	var caption: Label = D.label(
		line, head, 21, D.GOLD if int(stage.stage) == current else D.TEAL, false
	)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if done:
		var word: String = str(g.sim.contract_rules.get("document", {}).get("stamp", "已验收"))
		D.tag(
			line, "%s · %s" % [word, Labels.short_date(int(stage.completed_day))], STAMP_COLOR, 16
		)
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
	for goal_row: Dictionary in stage.goals:
		_goal(g, card, goal_row)


static func _goal(g, card: VBoxContainer, goal_row: Dictionary) -> void:
	var text: Dictionary = Labels.goal(goal_row)
	var line: HBoxContainer = D.row(card)
	var caption: Label = D.label(
		line,
		"%s  %s" % ["✓" if goal_row.ok else "○", text.text],
		17,
		D.TEAL if goal_row.ok else D.INK
	)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not goal_row.ok and str(text.page) != "":
		var page_key: String = text.page
		var fix: Button = D.button(line, "去处理", func(): g.open_page(page_key), str(text.hint))
		D.font_size(fix, 14)
		fix.custom_minimum_size.y = 30
	elif not goal_row.ok:
		D.label(line, str(text.hint), 15, D.MUTED, false)
	if str(goal_row.key) == "operating_route":
		_route_lines(g, card)


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


## Signed amendments (补充协议 N), brought by the annual ship (1.11 D).
static func _amendments(g, b) -> void:
	D.heading(b, "补充协议")
	var signed: Array = g.sim.state.contract.get("amendments", [])
	if signed.is_empty():
		D.label(b, "暂无补充协议。", 16, D.MUTED)
		return
	for index: int in range(signed.size()):
		var amendment: Dictionary = signed[index]
		var card: VBoxContainer = D.card(b, "card_quiet")
		D.label(
			card,
			(
				"补充协议 %d　%s　·　签署于 %s"
				% [
					index + 1,
					str(amendment.get("title", "")),
					Labels.short_date(int(amendment.day))
				]
			),
			18,
			D.GOLD
		)
		D.label(card, amendment_terms(g.sim, amendment), 16)


## Annex VII, sealed until stage four is accepted (opened in 1.11 E).
static func _annex(g, b) -> void:
	var rule: Dictionary = g.sim.contract_rules.get("document", {}).get("annex", {})
	var card: VBoxContainer = D.card(b, "well")
	D.label(card, str(rule.get("title", "附件七（密封）")), 19, D.GOLD)
	D.label(card, str(rule.get("sealed", "")), 16, D.MUTED)
