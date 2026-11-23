extends RefCounted
## The settlement statement (结算单, 1.11 E), shown at every ending and at the takeover: per stage
## what was promised and delivered, the annual reports and their gaps, the amendments, rewards and
## fines, the shares, the landmarks. After the award it offers the two endings that can still
## follow: 收购 (buy the company out with the career fund) and 自治 (declare autonomy).
## Functional; a later interface pass restyles it.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Endings = preload("res://simulation/endings.gd")
const ENDING_NAMES: Dictionary = {
	"loyal": "效忠：总督资格，移交经营",
	"buyout": "收购：买断公司分成",
	"autonomy": "自治：殖民地自主经营",
	"takeover": "公司接管：合同终止",
}
const OUTCOME_NAMES: Dictionary = {"missed": "未达标", "met": "达标", "exceed": "超额"}


static func page(g, b) -> void:
	var sim: RefCounted = g.sim
	var report: Dictionary = Endings.statement(sim)
	var kind: String = str(report.ending.get("kind", ""))
	D.label(b, "%s 项目结算单" % str(sim.state.contract.get("code", "")), 24, D.GOLD)
	D.label(b, str(ENDING_NAMES.get(kind, "合同履行中")), 20, D.TEAL)
	_stages(b, report)
	_reports(b, report)
	_money(b, report)
	_amendments(g, b, report)
	_landmarks(b, report)
	if str(sim.state.status) == "success" and kind in ["", "loyal"]:
		_choices(g, b)
	var row: HBoxContainer = D.row(b)
	if str(sim.state.status) != "failed":
		D.button(row, "继续经营（沙盒）", g.close_modal)
	D.button(row, "生涯与下一份合同", func(): g.open_page("career"))


static func _stages(b, report: Dictionary) -> void:
	D.heading(b, "阶段：承诺与交付")
	for row: Dictionary in report.stages:
		var name: String = str(Labels.STAGE_NAMES.get(row.id, row.id))
		var done: int = int(row.accepted)
		var text: String = (
			"%s　期限 %s　·　%s"
			% [
				name,
				Labels.short_date(int(row.deadline)),
				("验收 " + Labels.short_date(done)) if done >= 0 else "未交付"
			]
		)
		var late: bool = done > int(row.deadline) or done < 0
		D.label(b, text, 16, D.RED if late else D.INK)


static func _reports(b, report: Dictionary) -> void:
	D.heading(b, "年度报告")
	if report.reports.is_empty():
		D.label(b, "没有年度报告。", 15, D.MUTED)
	for row: Dictionary in report.reports:
		D.label(
			b,
			(
				"第 %d 年度　矿业 实际 %s / 报 %s（%s）　农业 实际 %s / 报 %s（%s）"
				% [
					int(row.year),
					Labels.t(float(row.actual.mining)),
					Labels.t(float(row.reported.mining)),
					OUTCOME_NAMES.get(str(row.outcomes.mining), ""),
					Labels.t(float(row.actual.farming)),
					Labels.t(float(row.reported.farming)),
					OUTCOME_NAMES.get(str(row.outcomes.farming), "")
				]
			),
			15
		)
	var gap: Dictionary = report.gap
	if float(gap.get("mining", 0.0)) + float(gap.get("farming", 0.0)) > 0.0:
		D.label(
			b,
			(
				"尚未补上的账面差额：矿业 %s，农业 %s"
				% [
					Labels.t(float(gap.get("mining", 0.0))),
					Labels.t(float(gap.get("farming", 0.0)))
				]
			),
			15,
			D.RED
		)


static func _money(b, report: Dictionary) -> void:
	D.heading(b, "奖励、罚款与分成")
	var money: Dictionary = report.money
	D.label(
		b,
		(
			"阶段发展资金 ¥%.0f · 年度奖励 ¥%.0f · 年度罚款 ¥%.0f · 事件收入 ¥%.0f · 贡矿 %s"
			% [
				float(money.get("contract.reward", 0.0)),
				float(report.rewards_paid),
				float(report.fines_paid),
				float(money.get("event.reward", 0.0)),
				Labels.t(float(report.tribute))
			]
		),
		15
	)
	D.label(
		b,
		(
			"授权后公司分成 %.0f%% · 承包人分成 %.0f%% · 生涯资金 ¥%.0f"
			% [
				float(report.company_rate) * 100.0,
				float(report.player_share) * 100.0,
				float(report.career_fund)
			]
		),
		15,
		D.MUTED
	)


static func _amendments(g, b, report: Dictionary) -> void:
	if report.amendments.is_empty():
		return
	D.heading(b, "补充协议")
	var page: GDScript = load("res://ui/contract_page.gd")
	for index: int in range(report.amendments.size()):
		var row: Dictionary = report.amendments[index]
		D.label(
			b,
			(
				"补充协议 %d　%s：%s"
				% [index + 1, str(row.get("title", "")), page.amendment_terms(g.sim, row)]
			),
			15
		)


static func _landmarks(b, report: Dictionary) -> void:
	if report.landmarks.is_empty():
		return
	D.heading(b, "地标")
	for mark: Dictionary in report.landmarks.slice(-8):
		D.label(b, "◆ %s · %s" % [str(mark.get("name", "")), str(mark.get("text", ""))], 15, D.GOLD)


## After the award: buy the company out, or declare autonomy.
static func _choices(g, b) -> void:
	var sim: RefCounted = g.sim
	D.heading(b, "结局")
	var price: float = Endings.buyout_price(sim)
	var fund: float = float(sim.state.career.balance)
	var buy: Button = D.button(
		b,
		"收购：以生涯资金 ¥%.0f 买断公司分成（现有 ¥%.0f）" % [price, fund],
		func(): g.act("buyout", {}),
		"收购价 = 倍数 × 公司分成 × 过去一年经营利润，不低于底价。生涯资金靠总督阶段的转存积累。",
		"EndingBuyout"
	)
	buy.disabled = fund < price
	var terms: Dictionary = Endings.autonomy_terms(sim)
	var free: Button = D.button(
		b,
		(
			"宣布自治（民心 %.0f · 人口 %d · 公司评级 %s%s）"
			% [
				float(terms.morale),
				int(terms.population),
				str(terms.rating),
				" · 已公开附件七" if bool(terms.disclosed) else ""
			]
		),
		func(): g.act("declare_autonomy", {}),
		"自治需要足够的民心、人口和公司评级；若附件七答复为公开，只看民心。",
		"EndingAutonomy"
	)
	free.disabled = not bool(terms.ok)
