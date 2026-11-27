extends RefCounted
## The annual report (1.11 D), one screen: for 矿业 and 农业 this year's actual and target, and three
## ways to report it, each with what it would bring (the outcome, money or distrust, the book gap
## it opens and next year's target); the gap already open (账面差额); one signature sends it back
## with the ship. Between ships it shows the days to the next one and the last receipt.
## Functional; a later interface pass restyles it.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const AnnualReport = preload("res://simulation/annual_report.gd")
const LINE_NAMES: Dictionary = {"mining": "矿业", "farming": "农业"}
const TIER_NAMES: Dictionary = {"honest": "如实", "met": "报达标", "exceed": "报超额"}
const OUTCOME_NAMES: Dictionary = {"missed": "未达标", "met": "达标", "exceed": "超额"}

## The tiers picked on screen for the pending report, by line; cleared for each new report.
static var picks: Dictionary = {}
static var picks_year: int = -1


static func page(g, b) -> void:
	var view: Dictionary = AnnualReport.view(g.sim)
	var p: Dictionary = view.pending
	var code: String = str(g.sim.state.contract.get("code", ""))
	if p.is_empty():
		_between(b, view, code)
		return
	if int(p.year) != picks_year:
		picks = {}
		picks_year = int(p.year)
	D.label(b, "%s 项目第 %d 年度报告" % [code, int(p.year)], 24, D.GOLD)
	D.label(
		b,
		(
			"公司年度船 %s 抵达%s。请于 %s 前签署寄回；逾期未签，按如实寄回。"
			% [
				Labels.short_date(int(p.day)),
				str(g.sim.state.settlements[0].name),
				Labels.short_date(int(p.deadline))
			]
		),
		17,
		D.MUTED
	)
	for line: String in AnnualReport.LINES:
		_line(g, b, view, line)
	var sign: Button = D.button(
		b,
		"签署并随船寄回",
		func(): g.act("annual_report", picks.duplicate()),
		"一份报告只签一次：寄回后结果当即生效。",
		"SignAnnualReport",
		"primary"
	)
	sign.custom_minimum_size.y = 44


static func _line(g, b, view: Dictionary, line: String) -> void:
	var p: Dictionary = view.pending
	var rule: Dictionary = AnnualReport.rules(g.sim)
	var exceed: float = float(view.exceed_factor)
	var actual: float = float(p.actual[line])
	var target: float = float(p.targets[line])
	var card: VBoxContainer = D.card(b)
	var fixed: bool = line in p.fixed
	var head: String = "%s　实际 %s　·　指标 %s" % [LINE_NAMES[line], Labels.t(actual), Labels.t(target)]
	if fixed:
		head = "%s（贡矿）　装船 %s　·　应交 %s" % [LINE_NAMES[line], Labels.t(actual), Labels.t(target)]
	D.label(card, head, 19, D.GOLD)
	if float(view.gap[line]) > 0.0:
		D.label(card, "账面差额：%s（此前多报、尚未补上的部分）" % Labels.t(float(view.gap[line])), 15, D.RED)
	if fixed:
		D.label(card, "矿权抵押合同：这一项就是装船的实物，不能多报。", 15, D.MUTED)
		return
	var row: HBoxContainer = D.row(card)
	var chosen: String = str(picks.get(line, AnnualReport.HONEST))
	for tier: String in AnnualReport.TIERS:
		var value: float = AnnualReport.reported(actual, target, tier, exceed)
		var result: String = AnnualReport.outcome(value, target, exceed)
		var picked: String = tier
		var choice: Button = D.button(
			row,
			"%s · 报 %s" % [TIER_NAMES[tier], Labels.t(value)],
			func():
				picks[line] = picked
				g.populate_current_page(),
			_explain(g, rule, actual, value, result),
			"Report_%s_%s" % [line, tier],
			"chip_on" if tier == chosen else "chip"
		)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_now: float = AnnualReport.reported(actual, target, chosen, exceed)
	D.label(
		card,
		_explain(g, rule, actual, value_now, AnnualReport.outcome(value_now, target, exceed)),
		15,
		D.TEAL if value_now <= actual else D.RED
	)


## What a way of reporting brings: the outcome and its money or distrust, the gap it opens and the
## target it sets for next year.
static func _explain(g, rule: Dictionary, actual: float, value: float, result: String) -> String:
	var scale: float = g.sim.EventsV2.money_scale(g.sim)
	var words: PackedStringArray = [str(OUTCOME_NAMES[result])]
	match result:
		AnnualReport.MISSED:
			if g.sim.Company.first_year_exempt(g.sim):
				words.append("不信任：首年豁免")
			else:
				words.append("不信任 +%s" % _number(float(rule.get("miss_distrust", 0.0))))
		AnnualReport.EXCEED:
			words.append("奖励 ¥%.0f" % (float(rule.get("exceed_reward", 0.0)) * scale))
			words.append("不信任 −%s" % _number(float(rule.get("exceed_trust", 0.0))))
		_:
			words.append("奖励 ¥%.0f" % (float(rule.get("met_reward", 0.0)) * scale))
	if value > actual:
		words.append("账面差额 +%s" % Labels.t(value - actual))
	var growth: float = float(rule.get("ratchet_growth", {}).get(str(g.sim.state.advantage), 1.1))
	words.append("明年指标不低于 %s" % Labels.t(value * growth))
	return "，".join(words)


static func _between(b, view: Dictionary, code: String) -> void:
	D.label(b, "%s 项目年度报告" % code, 24, D.GOLD)
	var days: int = int(view.days_to_ship)
	if days >= 0:
		D.label(b, "下一艘公司年度船 %d 日后抵达。" % days, 18, D.TEAL)
	var targets: Dictionary = view.targets
	var tally: Dictionary = view.tally
	for line: String in AnnualReport.LINES:
		D.label(
			b,
			(
				"%s　今年至今 %s　·　本年指标 %s"
				% [
					LINE_NAMES[line],
					Labels.t(float(tally.get(line, 0.0))),
					Labels.t(float(targets.get(line, 0.0)))
				]
			),
			17
		)
		if float(view.gap[line]) > 0.0:
			D.label(b, "　账面差额 %s" % Labels.t(float(view.gap[line])), 15, D.RED)
	var history: Array = view.history
	if history.is_empty():
		return
	var last: Dictionary = history.back()
	D.heading(b, "上一份报告（第 %d 年度）" % int(last.year))
	for line: String in AnnualReport.LINES:
		D.label(
			b,
			(
				"%s：实际 %s，报 %s（%s），%s"
				% [
					LINE_NAMES[line],
					Labels.t(float(last.actual[line])),
					Labels.t(float(last.reported[line])),
					TIER_NAMES.get(str(last.tiers[line]), ""),
					OUTCOME_NAMES.get(str(last.outcomes[line]), "")
				]
			),
			16,
			D.MUTED
		)


static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return ("%.2f" % value).rstrip("0")
