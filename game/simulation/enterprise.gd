extends RefCounted
## The private enterprise: licensing, daily operation and recovery.

const Keys = preload("res://simulation/keys.gd")


static func found(sim: RefCounted, region: int) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or s.arrival > 0:
		return "需要已经运转的据点"
	if s.buildings.size() >= 24:
		return "本地区已经达到 24 处设施的土地开发上限"
	if not sim.state.enterprise.is_empty():
		return "本 Demo 已有一家民营企业"
	if not sim.state.policy.private_allowed:
		return "当前政策未允许商业服务业"
	if sim.state.day < 15 or sim.state.exports_total < 100:
		return "投资人要求运营至少 15 天且累计出口达到 100"
	if s.stock.materials < 8 or s.stock.parts < 2:
		return "企业要向本地仓库购买 8 建材和 2 部件"
	sim._transfer("external", "enterprise", 900.0, "enterprise.capital", false)
	var inputs: float = 8.0 * sim.config.prices.materials + 2.0 * sim.config.prices.parts
	sim._transfer("enterprise", "public", inputs, "enterprise.inputs", false)
	sim._consume(s, "materials", 8.0)
	sim._consume(s, "parts", 2.0)
	sim._transfer("enterprise", "external", 260.0, "enterprise.fitout", false)
	sim.state.enterprise = {
		"name": "远岸生活服务社",
		"region": region,
		"industry": "service",
		"status": Keys.E_FITTING,
		"remaining": 4,
		"employees": 0,
		"profit": 0.0,
		"sales_total": 0.0,
		"wages_total": 0.0,
		"tax_total": 0.0,
		"loss_days": 0,
		"reason": Keys.ER_FITTING,
		"rent": 2.0
	}
	var b: Dictionary = sim._building("service", 4)
	b.owner = "private"
	s.buildings.append(b)
	sim._log("远岸生活服务社获准落地：私人实缴 900，自主装修、雇人、销售并纳税。")
	return ""


static func run(sim: RefCounted) -> void:
	if sim.state.enterprise.is_empty():
		return
	var e: Dictionary = sim.state.enterprise
	var s: Dictionary = sim.settlement(int(e.region))
	e.employees = 0
	e.profit = 0.0
	if e.status == Keys.E_CLOSED:
		return
	if e.remaining > 0:
		e.remaining -= 1
		if e.remaining > 0:
			return
	var b: Dictionary = {}
	for item in s.buildings:
		if item.kind == "service":
			b = item
	if b.is_empty():
		return
	s.jobs += 6
	if not b.enabled:
		b.active = false
		e.status = Keys.E_PAUSED
		e.reason = Keys.ER_PAUSED
		return
	var employees: int = mini(6, maxi(0, int(s.workers) - int(s.employed_workers)))
	var wages: float = employees * float(sim.config.economy.wage)
	var fixed: float = 3.0 + float(e.rent)
	if float(sim.state.enterprise_cash) < wages + fixed or employees < 2:
		e.loss_days += 1
		e.status = Keys.E_RESTRICTED
		e.reason = Keys.ER_NO_WORKERS if employees < 2 else Keys.ER_NO_CASH
		b.active = false
		b.status = Keys.B_RESTRICTED
		if e.loss_days >= 15:
			e.status = Keys.E_CLOSED
			sim._log("服务社已停业：可雇用工人或现金不足持续 15 天。")
		return
	e.employees = employees
	s.employed_workers += employees
	s.employed += employees
	b.employed = employees
	b.active = true
	b.status = Keys.B_PRIVATE_OPEN
	sim._transfer("enterprise", "residents", wages, "enterprise.wages", false)
	sim._transfer("enterprise", "public", float(e.rent), "enterprise.rent", true)
	sim._transfer("enterprise", "external", 3.0, "enterprise.upkeep", false)
	# Residents purchase useful aggregate repair / laundry / communication services.
	var demand: float = minf(float(s.population) * 0.35, employees * 4.2)
	var sales: float = minf(float(sim.state.resident_cash), demand)
	sim._transfer("residents", "enterprise", sales, "enterprise.sales", false)
	var profit: float = sales - wages - fixed
	var tax: float = maxf(0.0, profit) * float(sim.state.policy.tax)
	sim._transfer("enterprise", "public", tax, "enterprise.tax", true)
	e.profit = profit - tax
	e.sales_total += sales
	e.wages_total += wages
	e.tax_total += tax
	e.loss_days = int(e.loss_days) + 1 if profit < 0 else 0
	e.status = Keys.E_OPEN
	e.reason = Keys.ER_RUNNING
	if e.loss_days >= 15:
		e.status = Keys.E_CLOSED
		b.active = false
		sim._log("服务社连续亏损 15 天，停止营业；居民购买力不足。")


static func preview(sim: RefCounted, region: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return {}
	var wages: float = 6 * float(sim.config.economy.wage)
	var sales: float = minf(float(s.population) * 0.35, 25.2)
	return {
		"region": region,
		"population": s.population,
		"workers": maxi(0, int(s.workers) - int(s.employed_workers)),
		"daily_demand": sales,
		"daily_cost": wages + 5,
		"estimated_profit": sales - wages - 5,
		"recovery_cost": float(sim.progression.production.enterprise_recovery),
		"reason": "居民服务需求取决于当地人口与购买力；小型前哨可能亏损，复业可迁至所选据点。"
	}


static func recover(sim: RefCounted, region: int) -> String:
	if sim.state.enterprise.is_empty():
		return "尚未设立企业"
	var dst: Dictionary = sim.settlement(region)
	if dst.is_empty() or dst.arrival > 0:
		return "需要已经运转的据点"
	var cost: float = float(sim.progression.production.enterprise_recovery)
	if float(sim.state.cash) < cost:
		return "复业重组需要 %.0f 资金" % cost
	var src: Dictionary = sim.settlement(int(sim.state.enterprise.region))
	var target: Dictionary = {}
	for b in src.buildings:
		if b.kind == "service":
			target = b
			break
	if target.is_empty():
		return "原企业设施缺失"
	if int(src.region) != region and dst.buildings.size() >= 24:
		return "目的地设施已满"
	sim._transfer("public", "enterprise", cost, "enterprise.recovery", false)
	if int(src.region) != region:
		src.buildings.erase(target)
		dst.buildings.append(target)
	target.enabled = true
	target.remaining = 3
	target.active = false
	sim.state.enterprise.region = region
	sim.state.enterprise.remaining = 3
	sim.state.enterprise.loss_days = 0
	sim.state.enterprise.status = Keys.E_FITTING
	sim.state.enterprise.reason = Keys.ER_RECOVERING
	sim._log("服务社有偿重组完成；公共账户投入 %.0f，3 日后在 %s 复业。" % [cost, dst.name])
	return ""
