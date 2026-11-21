extends RefCounted
## Lines of the town panel added in 1.11: who is working and who is not (workers looking for a job,
## research teams that can be put on a project, crews free to send, staff kept on at facilities that
## made nothing today), what the town sold (export receipts apart from local sales), its supply
## orders, what its warehouse can sell, and a facility's status line when it stands idle.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Keys = preload("res://simulation/keys.gd")

const IDLE_REASONS: Dictionary = {
	Keys.B_TARGET_FULL: "库存已达减产线",
	Keys.B_NO_INPUT: "缺原料",
	Keys.B_IDLE: "缺电、缺水或缺人",
	Keys.B_DEPLETED: "矿已挖完",
	Keys.B_DISABLED: "已停用",
}
const WAREHOUSE_GOODS: Array[String] = ["food", "materials", "parts", "ore", "copper"]


static func employment(g, b: Control, s: Dictionary) -> void:
	var view: Dictionary = g.sim.Population.employment_view(g.sim, s)
	var line: Label = D.label(
		b,
		(
			"找工作的职工 %d · 可派研究团队 %d · 可派工程队 %d / %d"
			% [int(view.seeking), int(view.research_free), int(view.crews_free), int(view.crews)]
		),
		15,
		D.INK
	)
	D.named(line, "TownEmployment")
	if int(view.retained_idle) > 0:
		var kept: Label = D.label(
			b,
			(
				"%d 名职工留在今天没有产出的设施上，日工资 ¥%.0f%s"
				% [
					int(view.retained_idle),
					float(view.retained_cost),
					(
						"（%d 座已减班）" % int(view.reduced_facilities)
						if int(view.reduced_facilities) > 0
						else ""
					),
				]
			),
			14,
			D.GOLD
		)
		D.named(kept, "TownRetained")


## Export receipts (they count towards the charter's export goal) apart from local sales.
static func sales(g, b: Control, s: Dictionary) -> void:
	var month: Dictionary = g.sim.Supply.sales(s, int(g.sim.state.day), 30)
	var line: Label = D.label(
		b,
		(
			"近 30 日 · 出口 ¥%s · 供货合同 ¥%s（都计入合同出口目标）· 本地销售 ¥%s（不计入）"
			% [
				g.money(float(month.export)),
				g.money(float(month.supply)),
				g.money(float(month.local)),
			]
		),
		14,
		D.MUTED
	)
	D.named(line, "TownSales")


## The buyer's orders at this town: open ones with their progress, or the offer and its terms.
static func supply(g, b: Control, s: Dictionary) -> void:
	var day: int = int(g.sim.state.day)
	D.label(b, "供货合同（只收本地产出，不动居民口粮）", 14, D.TEAL)
	for row: Dictionary in g.sim.Supply.offers(g.sim, s):
		var kind: String = str(row.kind)
		var order: Dictionary = row.open
		var line: HBoxContainer = D.row(b)
		var words: String = ""
		if not order.is_empty():
			words = (
				"%s 第 %d 期：%s / %s · ¥%.1f/百吨 · 还剩 %d 天"
				% [
					str(row.name),
					int(order.round),
					Labels.t(float(order.delivered)),
					Labels.t(float(order.size)),
					float(order.price),
					maxi(0, int(order.due_day) - day),
				]
			)
			words += "（每天约 %s 可交）" % Labels.t(float(row.standing))
		elif str(row.refusal) == "":
			words = (
				"%s：可签 · 首期 %d 天交 %s · ¥%.1f/百吨 · 现有产能每天 %s"
				% [
					str(row.name),
					int(row.days),
					Labels.t(float(row.size)),
					float(row.price),
					Labels.t(float(row.standing) + float(row.building)),
				]
			)
		else:
			words = "%s：%s" % [str(row.name), str(row.refusal)]
		var text: Label = D.label(line, words, 14, D.INK if order.is_empty() else D.TEAL)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		D.named(text, "Supply_" + kind)
		var region: int = int(s.region)
		if order.is_empty() and str(row.refusal) == "":
			var sign_up: Button = D.button(
				line,
				"签约",
				func(): g.act("supply_sign", {"site": region, "kind": kind}),
				(
					"需要%s；付款按实际交付的本地产出计，计入出口目标"
					% ("货运站或小型码头" if kind == "food" else "小型码头")
				),
				"SupplySign_" + kind,
				"chip"
			)
			D.font_size(sign_up, 13)
		elif not order.is_empty():
			var stop: Button = D.button(
				line,
				"终止",
				func(): g.act("supply_cancel", {"site": region, "kind": kind}),
				"已交付的部分照常结算，不再续签",
				"SupplyCancel_" + kind,
				"chip"
			)
			D.font_size(stop, 12)


## What the warehouse holds of the main goods and what of it can be sold: the figure the trade uses.
static func warehouse(g, b: Control, s: Dictionary) -> void:
	var parts: PackedStringArray = []
	for good: String in WAREHOUSE_GOODS:
		var row: Dictionary = g.sim.Stocks.availability(g.sim, s, good)
		if float(row.total) <= 0.0:
			continue
		parts.append(
			(
				"%s %s（可售 %s）"
				% [
					str(Labels.RESOURCE_NAMES.get(good, good)),
					Labels.t(float(row.total)),
					Labels.t(float(row.sellable))
				]
			)
		)
	if parts.is_empty():
		return
	var line: Label = D.label(b, "仓库：" + " · ".join(parts), 14, D.MUTED)
	D.named(line, "TownWarehouse")


## A facility that made nothing today: the staff it keeps, its output, why, and what it costs.
static func facility(g, b: Control, s: Dictionary, item: Dictionary) -> void:
	var view: Dictionary = g.sim.Production.facility_view(g.sim, s, item)
	if not bool(view.idle):
		if bool(view.producing_role) and float(view.output) > 0.0:
			D.label(b, "　今日产出 %s" % Labels.t(float(view.output)), 13, D.MUTED)
		return
	var reason: String = str(IDLE_REASONS.get(str(view.status), Labels.building_status(item)))
	var words: String = (
		"　%d 名职工保留岗位，今日产出 0，%s · 每日开支 ¥%.0f（工资 ¥%.0f + 维护 ¥%.0f）"
		% [
			int(view.retained),
			reason,
			float(view.daily_cost),
			float(view.wages),
			float(view.upkeep)
		]
	)
	if bool(view.reduced):
		words += " · 减班中（全班工资 ¥%.0f），需求回升自动恢复" % float(view.full_wages)
	var line: Label = D.label(b, words, 13, D.GOLD)
	D.named(line, "FacilityStatus")
