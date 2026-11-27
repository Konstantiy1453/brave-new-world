extends RefCounted
const Keys = preload("res://simulation/keys.gd")
const Contract = preload("res://simulation/contract.gd")
const Population = preload("res://simulation/population.gd")
const Stats = preload("res://simulation/stats.gd")
const Pollution = preload("res://simulation/pollution.gd")
const Rules = preload("res://simulation/rules.gd")
## The fields every company letter carries since 1.11 (structured letters, letters.json).
const LETTER_FIELDS: Dictionary = {
	"department": "", "subject": "", "cc": [], "body": "", "note": ""
}


## One causal source per economic and social chain, retained stage letters. Pollution is not one
## of them: it has its own consequences in pollution.gd.
static func ensure(sim) -> void:
	if not sim.state.has("company"):
		sim.state.company = {
			"distrust": 0.0,
			"delta": 0.0,
			"stage": "normal",
			"stage_day": int(sim.state.day),
			"deadline": -1,
			"sources": {},
			"letters": [],
			"aid": [],
			"claimed": [],
			"stable": 0,
			"extension_used": false,
			"failure_report": {}
		}
	if not sim.state.has("departed_total"):
		sim.state.departed_total = 0
	for s in sim.state.settlements:
		if not s.has("social_days"):
			s.social_days = 0


static func social_environment(sim) -> void:
	ensure(sim)
	var cfg: Dictionary = sim.progression.company
	for s in sim.state.settlements:
		if s.arrival > 0:
			continue
		var adult: int = int(s.workers) + int(s.scientists)
		var underemployment: bool = (
			int(sim.state.day) > 20 and float(s.employed) < float(adult) * 0.35
		)
		var low_appeal: bool = (
			float(s.get("attractiveness", 1.0)) < float(sim.pop_rules.departure.threshold)
		)
		var distressed: bool = (
			s.housing < s.population or s.starvation > 0 or underemployment or low_appeal
		)
		s.social_days = int(s.social_days) + 1 if distressed else maxi(0, int(s.social_days) - 1)
		if (
			int(s.social_days) >= int(cfg.departure_after)
			and int(s.social_days) % _departure_period(sim, cfg, s) == 0
			and s.workers > 2
		):
			var leaving: int = mini(
				int(s.workers) - 2,
				maxi(
					1,
					int(
						(
							float(s.population)
							* float(sim.pop_rules.departure.share)
							* Population.services_effect(sim, "departures")
						)
					)
				)
			)
			s.workers -= leaving
			s.population -= leaving
			sim.state.departed_total += leaving
			Stats.people(sim.state, int(s.region), false, leaving)
			sim._reconcile_jobs(s)
			sim._log("%s：持续缺乏住房、工作或食品，%d 名职工离开星球。" % [s.name, leaving])


## The settlement that most lacks what this aid carries; ties go to the earliest settlement.
## Better wages keep people through hard times: departures come less often.
static func _departure_period(sim: RefCounted, cfg: Dictionary, s: Dictionary) -> int:
	var period: float = (
		float(cfg.departure_period)
		* Population.wage_multiplier(sim)
		* (
			1.0
			+ Population.service_total(sim, s, "departure")
			+ sim.Research.bonus(sim, "departure")
		)
	)
	return maxi(1, int(round(period)))


## Distress counts in proportion to the people it touches, so a small outpost in trouble cannot
## cost the whole charter at the full rate. Floor and slope are in progression.json.
static func _population_weight(sim: RefCounted, s: Dictionary, cfg: Dictionary) -> float:
	var total: int = 0
	for place: Dictionary in sim.state.settlements:
		total += int(place.population)
	var share: float = float(s.population) / maxi(1, total)
	return clampf(share * float(cfg.social_share_slope), float(cfg.social_share_floor), 1.0)


static func aid_target(sim, d: Dictionary) -> int:
	var best: int = -1
	var worst: float = -INF
	for s in sim.state.settlements:
		if int(s.arrival) > 0:
			continue
		var score: float = 0.0
		if float(d.food) > 0:
			score += maxf(0.0, 10.0 - float(s.food_days)) / 10.0 + float(s.starvation)
		if float(d.materials) > 0:
			score += maxf(0.0, 35.0 - float(s.stock.materials)) / 35.0
		if float(d.parts) > 0:
			score += maxf(0.0, 12.0 - float(s.stock.parts)) / 12.0
		if score > worst:
			worst = score
			best = int(s.region)
	return best


static func accept(sim, offer: String, region: int = -1) -> String:
	ensure(sim)
	var c: Dictionary = sim.state.company
	var cfg: Dictionary = sim.progression.company
	if not cfg.offers.has(offer):
		return "无此援助方案"
	if "aid" in sim.state.contract.get("removed_clauses", []):
		return "补充协议已删除有条件援助条款，公司不再提供援助"
	if c.stage == "normal":
		return "公司援助在关注预警后开放；可先贸易、调拨或收缩"
	if c.claimed.has(offer):
		return "该援助已领取，不可重复签约"
	if sim.state.settlements.is_empty():
		return "需要已登陆据点接收援助"
	var d: Dictionary = cfg.offers[offer]
	var terms: Dictionary = d.duplicate(true)
	terms.id = offer
	terms.accepted_day = int(sim.state.day)
	terms.arrival_day = int(sim.state.day) + int(d.arrival_days)
	terms.end_day = int(terms.arrival_day) + int(d.duration)
	terms.status = "in_transit"
	terms.paid = 0.0
	terms.surcharge_paid = 0.0
	terms.region = region if not sim.settlement(region).is_empty() else aid_target(sim, d)
	if int(terms.region) < 0:
		terms.region = int(sim.state.settlements[0].region)
	c.aid.append(terms)
	c.claimed.append(offer)
	if int(c.deadline) >= 0 and not c.extension_used:
		c.deadline += int(cfg.aid_grace_extension)
		c.extension_used = true
	letter(
		sim,
		"aid_signed",
		{
			"aid_name": str(d.name),
			"arrival_days": int(d.arrival_days),
			"repayment": "%.0f" % float(d.repayment),
			"surcharge_pct": "%.0f" % (float(d.surcharge) * 100.0),
		}
	)
	return ""


static func act(sim, args: Dictionary) -> String:
	match str(args.get("operation", "accept")):
		"accept":
			return accept(sim, str(args.get("offer", "")), int(args.get("region", -1)))
		"cleanup":
			return Pollution.cleanup(sim)
	return "未知公司行动"


static func aid_tick(sim) -> void:
	for a in sim.state.company.aid:
		if a.status == "in_transit" and int(sim.state.day) >= int(a.arrival_day):
			var dst: Dictionary = sim.settlement(int(a.region))
			if dst.is_empty():
				a.status = "cancelled"
				continue
			if float(a.cash) > 0:
				sim._transfer("external", "public", float(a.cash), "aid.cash", false, str(a.id))
			for key in ["food", "materials", "parts"]:
				sim._produce(dst, key, float(a[key]), "公司援助物资")
			a.status = "active"
			sim._log(a.name + "已到达；开始执行偿还与追加分成义务。")
		if a.status in ["active", "breached"]:
			var fee: float = (
				maxf(0.0, float(sim.state.operating_net)) * float(a.surcharge)
				if int(sim.state.day) < int(a.end_day)
				else 0.0
			)
			if fee > 0:
				sim._public_expense(fee, "aid.surcharge", "external", str(a.id))
				a.surcharge_paid += fee
			var remaining: float = maxf(0, float(a.repayment) - float(a.paid))
			var installment: float = minf(remaining, float(a.repayment) / float(a.duration))
			if a.status == "breached":
				installment = remaining
			installment = minf(installment, maxf(0, float(sim.state.cash) - float(a.cash_floor)))
			a.paid += sim._transfer(
				"public", "external", installment, "aid.repay", false, str(a.id)
			)
			if int(sim.state.day) >= int(a.end_day):
				if float(a.paid) + 0.00001 >= float(a.repayment):
					a.status = "fulfilled"
					sim._log(a.name + "义务履行完成。")
				else:
					a.status = "breached"


## A letter from the company (1.11): the template for `kind` in letters.json (the sending
## department, the subject, the departments copied in, the body and the liaison's handwritten note),
## filled from the rules, the state and `values`. `reason` keeps the subject, for older readers.
static func letter(sim, kind: String, values: Dictionary = {}) -> void:
	var c: Dictionary = sim.state.company
	var book: Dictionary = Rules.read("letters")
	var template: Dictionary = book.letters.get(kind, {})
	var fill: Dictionary = letter_values(sim, values)
	var entry: Dictionary = {"day": int(sim.state.day), "kind": kind, "deadline": int(c.deadline)}
	if template.is_empty():
		var line: String = str(values.get("reason", kind))
		entry.merge({"reason": line, "department": "", "subject": line, "cc": []})
		entry.merge({"body": line, "note": ""})
	else:
		var copied: Array = []
		for department: String in template.get("cc", []):
			copied.append(str(book.departments.get(department, department)))
		var subject: String = fill_text(str(template.subject), fill)
		entry.reason = subject
		entry.department = str(book.departments.get(str(template.department), template.department))
		entry.subject = subject
		entry.cc = copied
		entry.body = fill_text(str(template.body), fill)
		entry.note = fill_text(str(template.get("note", "")), fill)
	c.letters.append(entry)
	while c.letters.size() > 30:
		c.letters.pop_front()
	sim._log("公司来信 · %s：%s" % [str(entry.department), str(entry.subject)])


## What a letter's {placeholders} can name: the colony's company code, the thresholds and windows
## of the current difficulty, the company deadline, and the caller's own values.
static func letter_values(sim, values: Dictionary) -> Dictionary:
	var cfg: Dictionary = sim.progression.company
	var diff: Dictionary = sim.progression.difficulty[sim.state.get("difficulty", "normal")]
	var fill: Dictionary = {
		"code": str(sim.state.get("contract", {}).get("code", "")),
		"review_threshold": "%.0f" % float(cfg.review_threshold),
		"intervention_threshold": "%.0f" % float(cfg.intervention_threshold),
		"review_days": int(diff.review_days),
		"intervention_days": int(diff.intervention_days),
		"deadline_day": int(sim.state.company.get("deadline", -1)),
	}
	fill.merge(values, true)
	return fill


static func fill_text(text: String, values: Dictionary) -> String:
	for key: String in values:
		text = text.replace("{%s}" % key, str(values[key]))
	return text


## Letters from before 1.11 get the structured fields: their one line becomes subject and body.
## Runs before an old save is validated, so it leaves whatever is malformed for the validator.
static func ensure_state(state: Dictionary) -> void:
	var company: Variant = state.get("company")
	if not company is Dictionary or not company.get("letters") is Array:
		return
	for entry: Variant in company.letters:
		if not entry is Dictionary:
			continue
		for field: String in LETTER_FIELDS:
			if not entry.has(field):
				entry[field] = LETTER_FIELDS[field].duplicate() if field == "cc" else ""
		if str(entry.subject) == "":
			entry.subject = str(entry.get("reason", entry.get("kind", "")))
		if str(entry.body) == "":
			entry.body = str(entry.get("reason", ""))


## The company's rating of the contractor from distrust: A below `rating_a_below`, B below the
## review threshold, C below the intervention threshold, D above.
static func rating(sim) -> String:
	var cfg: Dictionary = sim.progression.company
	var value: float = float(sim.state.get("company", {}).get("distrust", 0.0))
	if value < float(cfg.get("rating_a_below", 20.0)):
		return "A"
	if value < float(cfg.review_threshold):
		return "B"
	if value < float(cfg.intervention_threshold):
		return "C"
	return "D"


static func transition(sim, stage: String, days: int, letter_kind: String) -> void:
	var c: Dictionary = sim.state.company
	c.stage = stage
	c.stage_day = int(sim.state.day)
	c.deadline = int(sim.state.day) + days if days > 0 else -1
	letter(sim, letter_kind)


## Colony dates start at day zero: day year_days is the first day of year two.
static func first_year_exempt(sim: RefCounted) -> bool:
	return int(sim.state.day) < int(sim.progression.units.year_days)


static func apply_distrust(sim: RefCounted, amount: float) -> void:
	if amount > 0.0 and first_year_exempt(sim):
		return
	var company: Dictionary = sim.state.company
	company.distrust = clampf(float(company.distrust) + amount, 0.0, 100.0)


## An active save from before the exemption may already be under review. Keep its letters and aid.
static func restore_first_year_exemption(sim: RefCounted) -> void:
	if sim.state.status == "failed" or not first_year_exempt(sim):
		return
	var company: Dictionary = sim.state.company
	company.distrust = 0.0
	company.delta = 0.0
	company.stage = "normal"
	company.stage_day = 0
	company.deadline = -1
	company.stable = 0
	company.sources.clear()


static func tick(sim) -> void:
	ensure(sim)
	aid_tick(sim)
	# Bought out or autonomous (1.11 E): the company no longer reviews the colony.
	if first_year_exempt(sim) or sim.Endings.company_released(sim):
		return
	var c: Dictionary = sim.state.company
	var cfg: Dictionary = sim.progression.company
	var diff: Dictionary = sim.progression.difficulty[sim.state.difficulty]
	var economic: float = 0.0
	var social: float = 0.0
	var reason: String = ""
	if float(sim.state.debt) > 0.01:
		economic = minf(
			float(cfg.debt_cap),
			float(cfg.debt_base) + float(sim.state.grace_days) * float(cfg.debt_per_day)
		)
		reason = "必要支出逾期；偿还欠款、收缩支出或申请周转资金"
	for s in sim.state.settlements:
		if int(s.starvation) > 0:
			economic = maxf(
				economic,
				(
					minf(
						float(cfg.starving_cap),
						float(cfg.starving_base) + float(s.starvation) * float(cfg.starving_per_day)
					)
					* _population_weight(sim, s, cfg)
				)
			)
			reason = "必要食品短缺；进口、开港、调拨、限产或申请物资"
		if int(s.social_days) > 0 and int(s.starvation) == 0:
			var rate: float = minf(
				float(cfg.social_rate_cap), float(s.social_days) * float(cfg.social_rate_per_day)
			)
			social = maxf(social, rate * _population_weight(sim, s, cfg))
	if Contract.overdue(sim):
		economic = maxf(economic, float(sim.contract_rules.overdue_distrust_per_day))
		reason = "主要合同超过期限；完成未达目标后停止此项风险"
	for a in c.aid:
		if a.status == "breached":
			economic = maxf(economic, float(cfg.breached_rate))
			reason = "援助偿还逾期；补足偿还后停止处罚"
	var next_sources: Dictionary = {}
	for item in [["economic", economic, reason], ["social", social, "持续住房或就业不足；人口正向星球外流失"]]:
		var previous: Dictionary = c.sources.get(item[0], {})
		var days: int = int(previous.get("days", 0)) + 1 if float(item[1]) > 0 else 0
		next_sources[item[0]] = {"rate": float(item[1]), "days": days, "reason": item[2]}
	c.sources = next_sources
	var risk: float = (economic + social) * float(diff.risk)
	# One small town's troubles are the governor's business, not the company's.
	if risk <= float(cfg.tolerated_risk):
		risk = 0.0
	var level: float = float(c.distrust)
	var moved: float = risk if risk > 0 else -float(cfg.recovery_per_day)
	apply_distrust(sim, moved)
	c.delta = float(c.distrust) - level
	c.stable = int(c.stable) + 1 if risk <= 0 else 0
	var days_in_stage: int = int(sim.state.day) - int(c.stage_day)
	if int(c.stable) >= int(cfg.stable_days) and c.stage in ["review", "intervention"]:
		transition(sim, "recovery", 0, "recovery_stable")
		return
	match str(c.stage):
		"normal", "recovery":
			if risk > 0 and c.distrust >= float(diff.warning):
				transition(sim, "warning", 0, "warning")
			elif c.distrust <= 0 and c.stage == "recovery":
				transition(sim, "normal", 0, "normal")
		"warning":
			if (
				c.distrust >= float(cfg.review_threshold)
				and days_in_stage >= int(cfg.minimum_stage_days)
			):
				transition(sim, "review", int(diff.review_days), "review")
			elif c.stable >= int(cfg.stable_days):
				transition(sim, "recovery", 0, "recovery_solved")
		"review":
			if int(sim.state.day) >= int(c.deadline) and risk > 0:
				transition(sim, "intervention", int(diff.intervention_days), "intervention")
		"intervention":
			if int(sim.state.day) >= int(c.deadline) and risk > 0:
				c.failure_report = {
					"day": int(sim.state.day),
					"causes": c.sources.duplicate(true),
					"letters": c.letters.duplicate(true),
					"aid": c.aid.duplicate(true)
				}
				sim._fail("公司接管：审查和有条件介入窗口结束，持续违约仍未解决。" + reason)


static func view(sim) -> Dictionary:
	ensure(sim)
	var c: Dictionary = sim.state.company.duplicate(true)
	if first_year_exempt(sim):
		c.summary = "首年不信任豁免：从第二年一月一日起，公司开始计入不信任并执行审查。"
	c.offers = []
	for key in sim.progression.company.offers:
		var row: Dictionary = sim.progression.company.offers[key].duplicate(true)
		row.id = key
		row.claimed = sim.state.company.claimed.has(key)
		row.target_region = aid_target(sim, row)
		c.offers.append(row)
	c.next_condition = ("解决原因并稳定 %d 日可阻止升级；后续不信任逐日恢复" % int(sim.progression.company.stable_days))
	return c


static func validate(sim, candidate: Dictionary) -> String:
	var err: String = sim._save_shape(
		candidate.get("company"),
		{
			"distrust": 0,
			"delta": 0,
			"stage": "",
			"stage_day": 0,
			"deadline": 0,
			"sources": {},
			"letters":
			[
				{
					"day": 0,
					"kind": "",
					"reason": "",
					"deadline": 0,
					"department": "",
					"subject": "",
					"cc": [],
					"body": "",
					"note": ""
				}
			],
			"aid": [],
			"claimed": [""],
			"stable": 0,
			"extension_used": false,
			"failure_report": {}
		},
		"company"
	)
	if err != "":
		return err
	var c: Dictionary = candidate.company
	if (
		c.distrust < 0
		or c.distrust > 100
		or not c.stage in ["normal", "warning", "review", "intervention", "recovery"]
	):
		return "公司阶段或不信任无效"
	for source in c.sources.values():
		err = sim._save_shape(source, {"rate": 0, "days": 0, "reason": ""}, "company.sources")
		if err != "":
			return err
	var ids: Array = []
	for a in c.aid:
		err = sim._save_shape(
			a,
			{
				"id": "",
				"name": "",
				"cash": 0,
				"food": 0,
				"materials": 0,
				"parts": 0,
				"arrival_days": 0,
				"repayment": 0,
				"duration": 0,
				"surcharge": 0,
				"cash_floor": 0,
				"accepted_day": 0,
				"arrival_day": 0,
				"end_day": 0,
				"status": "",
				"paid": 0,
				"surcharge_paid": 0,
				"region": 0
			},
			"company.aid"
		)
		if err != "":
			return err
		if not sim.progression.company.offers.has(a.id) or ids.has(a.id) or not c.claimed.has(a.id):
			return "援助唯一领取记录无效"
		if (
			a.paid < 0
			or a.repayment < 0
			or a.duration <= 0
			or a.region < 0
			or a.region >= candidate.world.regions.size()
			or not a.status in ["in_transit", "active", "fulfilled", "breached", "cancelled"]
		):
			return "援助条款无效"
		for field in [
			"cash",
			"food",
			"materials",
			"parts",
			"arrival_days",
			"repayment",
			"duration",
			"surcharge",
			"cash_floor",
			"accepted_day",
			"arrival_day",
			"end_day",
			"paid",
			"surcharge_paid"
		]:
			if float(a[field]) < 0:
				return "援助数值不能为负数"
		if (
			a.surcharge > 1
			or a.paid > a.repayment
			or a.arrival_day < a.accepted_day
			or a.end_day < a.arrival_day
		):
			return "援助日期或费用口径无效"
		for field in [
			"arrival_days", "duration", "accepted_day", "arrival_day", "end_day", "region"
		]:
			if float(a[field]) != float(int(a[field])):
				return "援助日期与地区应为整数"
		ids.append(a.id)
	return ""
