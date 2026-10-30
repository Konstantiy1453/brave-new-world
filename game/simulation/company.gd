extends RefCounted
const Keys = preload("res://simulation/keys.gd")
const Contract = preload("res://simulation/contract.gd")
const Population = preload("res://simulation/population.gd")


## One causal source per economic/social/environmental chain, retained stage letters.
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
		if not s.has("pollution"):
			s.pollution = 0.0
		if not s.has("social_days"):
			s.social_days = 0


static func environmental_factor(s: Dictionary) -> float:
	return clampf(1.0 - maxf(0.0, float(s.get("pollution", 0)) - 35.0) * 0.006, 0.55, 1.0)


static func social_environment(sim) -> void:
	ensure(sim)
	var cfg: Dictionary = sim.progression.company
	for s in sim.state.settlements:
		if s.arrival > 0:
			continue
		var pollution: float = 0.0
		for b in s.buildings:
			if not b.active:
				continue
			if b.kind.begins_with("mine_"):
				pollution += float(sim.progression.production.mine_pollution) * float(b.efficiency)
			if b.kind == "processor":
				pollution += (
					float(sim.progression.production.processor_pollution) * float(b.efficiency)
				)
		s.pollution = clampf(
			float(s.pollution) + pollution - float(sim.progression.production.pollution_decay),
			0.0,
			100.0
		)
		if s.pollution > float(cfg.pollution_threshold):
			sim._public_expense(
				(float(s.pollution) - float(cfg.pollution_threshold)) * 0.10,
				"company.health",
				"external"
			)
			sim._short(s, Keys.SH_POLLUTION)
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
			and int(s.social_days) % _departure_period(sim, cfg) == 0
			and s.workers > 2
		):
			var leaving: int = mini(
				int(s.workers) - 2,
				maxi(1, int(float(s.population) * float(sim.pop_rules.departure.share)))
			)
			s.workers -= leaving
			s.population -= leaving
			sim.state.departed_total += leaving
			sim._reconcile_jobs(s)
			sim._log("%s：持续缺乏住房、工作或食品，%d 名工人离开星球。" % [s.name, leaving])


## The settlement that most lacks what this aid carries; ties go to the earliest settlement.
## Better wages keep people through hard times: departures come less often.
static func _departure_period(sim: RefCounted, cfg: Dictionary) -> int:
	return maxi(1, int(round(float(cfg.departure_period) * Population.wage_multiplier(sim))))


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
		"援助签署",
		(
			d.name
			+ "；"
			+ str(d.arrival_days)
			+ " 日后抵达，偿还 "
			+ str(d.repayment)
			+ "，正经营结余追加分成 "
			+ str(float(d.surcharge) * 100)
			+ "%，期限 "
			+ str(d.duration)
			+ " 日。"
		)
	)
	return ""


static func act(sim, args: Dictionary) -> String:
	match str(args.get("operation", "accept")):
		"accept":
			return accept(sim, str(args.get("offer", "")), int(args.get("region", -1)))
		"cleanup":
			var s: Dictionary = sim.settlement(int(args.get("region", -1)))
			if s.is_empty():
				return "请选择据点"
			var cost: float = float(sim.progression.production.cleanup_cost)
			if sim.state.cash < cost:
				return "治理需要 %.0f 资金" % cost
			sim._transfer("public", "external", cost, "company.cleanup", false)
			s.pollution = maxf(
				0.0, float(s.pollution) - float(sim.progression.production.cleanup_amount)
			)
			return ""
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


static func letter(sim, kind: String, reason: String) -> void:
	var c: Dictionary = sim.state.company
	c.letters.append(
		{"day": int(sim.state.day), "kind": kind, "reason": reason, "deadline": int(c.deadline)}
	)
	while c.letters.size() > 30:
		c.letters.pop_front()
	sim._log("公司" + kind + "：" + reason)


static func transition(sim, stage: String, days: int, reason: String) -> void:
	var c: Dictionary = sim.state.company
	c.stage = stage
	c.stage_day = int(sim.state.day)
	c.deadline = int(sim.state.day) + days if days > 0 else -1
	letter(sim, stage, reason)


static func tick(sim) -> void:
	ensure(sim)
	aid_tick(sim)
	var c: Dictionary = sim.state.company
	var cfg: Dictionary = sim.progression.company
	var diff: Dictionary = sim.progression.difficulty[sim.state.difficulty]
	var economic: float = 0.0
	var social: float = 0.0
	var environment: float = 0.0
	var reason: String = ""
	if float(sim.state.debt) > 0.01:
		economic = minf(2.0, 0.5 + float(sim.state.grace_days) * 0.08)
		reason = "必要支出逾期；偿还欠款、收缩支出或申请周转资金"
	for s in sim.state.settlements:
		if int(s.starvation) > 0:
			economic = maxf(economic, minf(2.4, 0.6 + float(s.starvation) * 0.12))
			reason = "必要食品短缺；进口、开港、调拨、限产或申请物资"
		if int(s.social_days) > 0 and int(s.starvation) == 0:
			var rate: float = minf(
				float(cfg.social_rate_cap), float(s.social_days) * float(cfg.social_rate_per_day)
			)
			social = maxf(social, rate * _population_weight(sim, s, cfg))
		if float(s.pollution) > float(cfg.pollution_threshold):
			environment = maxf(
				environment, (float(s.pollution) - float(cfg.pollution_threshold)) * 0.02
			)
	if Contract.overdue(sim):
		economic = maxf(economic, float(sim.contract_rules.overdue_distrust_per_day))
		reason = "主要合同超过期限；完成未达目标后停止此项风险"
	for a in c.aid:
		if a.status == "breached":
			economic = maxf(economic, 1.8)
			reason = "援助偿还逾期；补足偿还后停止处罚"
	var next_sources: Dictionary = {}
	for item in [
		["economic", economic, reason],
		["social", social, "持续住房或就业不足；人口正向星球外流失"],
		["environment", environment, "污染地区健康成本增加、生产效率下降；治理或限产"]
	]:
		var previous: Dictionary = c.sources.get(item[0], {})
		var days: int = int(previous.get("days", 0)) + 1 if float(item[1]) > 0 else 0
		next_sources[item[0]] = {"rate": float(item[1]), "days": days, "reason": item[2]}
	c.sources = next_sources
	var risk: float = (economic + social + environment) * float(diff.risk)
	c.delta = risk if risk > 0 else -float(cfg.recovery_per_day)
	c.distrust = clampf(float(c.distrust) + float(c.delta), 0.0, 100.0)
	c.stable = int(c.stable) + 1 if risk <= 0 else 0
	var days_in_stage: int = int(sim.state.day) - int(c.stage_day)
	if int(c.stable) >= int(cfg.stable_days) and c.stage in ["review", "intervention"]:
		transition(sim, "recovery", 0, "整改已稳定，停止升级；不信任随持续稳定逐日恢复。")
		return
	match str(c.stage):
		"normal", "recovery":
			if risk > 0 and c.distrust >= float(diff.warning):
				transition(sim, "warning", 0, "出现持续履约风险；可贸易、调拨、企业复业、治理或查看有条件援助。")
			elif c.distrust <= 0 and c.stage == "recovery":
				transition(sim, "normal", 0, "持续稳定恢复正常经营。")
		"warning":
			if (
				c.distrust >= float(cfg.review_threshold)
				and days_in_stage >= int(cfg.minimum_stage_days)
			):
				transition(
					sim, "review", int(diff.review_days), "正式整改：解决当前经济、社会与环境原因。现有合同到期不会绕过此窗口。"
				)
			elif c.stable >= int(cfg.stable_days):
				transition(sim, "recovery", 0, "问题已解决，持续稳定将恢复评价。")
		"review":
			if int(sim.state.day) >= int(c.deadline) and risk > 0:
				transition(
					sim,
					"intervention",
					int(diff.intervention_days),
					"整改期限结束仍有风险；最后介入窗口，可接受尚未使用的援助并执行义务。"
				)
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
	c.offers = []
	for key in sim.progression.company.offers:
		var row: Dictionary = sim.progression.company.offers[key].duplicate(true)
		row.id = key
		row.claimed = sim.state.company.claimed.has(key)
		row.target_region = aid_target(sim, row)
		c.offers.append(row)
	c.next_condition = "解决原因并稳定 10 日可阻止升级；后续不信任逐日恢复"
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
			"letters": [{"day": 0, "kind": "", "reason": "", "deadline": 0}],
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
			or a.region >= 6
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
