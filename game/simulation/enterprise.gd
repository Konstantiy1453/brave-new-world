extends RefCounted
## The private enterprise: licensing, daily operation and recovery.

const Keys = preload("res://simulation/keys.gd")
const Population = preload("res://simulation/population.gd")
const Sites = preload("res://simulation/sites.gd")


static func found(sim: RefCounted, region: int) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or s.arrival > 0:
		return "需要已经运转的据点"
	var ground: int = Sites.find_plot(sim, region, "service")
	if ground < 0:
		return "本地区没有空闲的建设用地"
	if not sim.state.enterprise.is_empty():
		return "这颗星球已有一家民营企业"
	if not sim.state.policy.private_allowed:
		return "当前政策未允许商业服务业"
	var forecast: Dictionary = preview(sim, region)
	if float(forecast.estimated_profit) < 0.0:
		return "当地需求不足：预计每日亏损 %.1f；需要更多居民" % -float(forecast.estimated_profit)
	var rules: Dictionary = sim.config.enterprise
	var materials: float = float(rules.materials)
	var parts: float = float(rules.parts)
	if s.stock.materials < materials or s.stock.parts < parts:
		return "企业要向本地仓库购买 %.0f 建材和 %.0f 部件" % [materials, parts]
	sim._transfer("external", "enterprise", float(rules.capital), "enterprise.capital", false)
	var inputs: float = materials * sim.config.prices.materials + parts * sim.config.prices.parts
	sim._transfer("enterprise", "public", inputs, "enterprise.inputs", false)
	sim._consume(s, "materials", materials)
	sim._consume(s, "parts", parts)
	sim._transfer("enterprise", "external", float(rules.fitout), "enterprise.fitout", false)
	sim.state.enterprise = {
		"name": "远岸生活服务社",
		"region": region,
		"industry": "service",
		"status": Keys.E_FITTING,
		"remaining": int(rules.days),
		"employees": 0,
		"profit": 0.0,
		"sales_total": 0.0,
		"wages_total": 0.0,
		"tax_total": 0.0,
		"loss_days": 0,
		"reason": Keys.ER_FITTING,
		"rent": float(rules.rent),
		"profit_days": 0
	}
	var b: Dictionary = sim._building("service", int(rules.days))
	b.owner = "private"
	b.plot = ground
	s.buildings.append(b)
	sim._log("远岸生活服务社获准落地：私人实缴 %.0f，自主装修、雇人、销售并纳税。" % float(rules.capital))
	return ""


static func run(sim: RefCounted) -> void:
	if sim.state.enterprise.is_empty():
		return
	var e: Dictionary = sim.state.enterprise
	var s: Dictionary = sim.settlement(int(e.region))
	var rules: Dictionary = sim.config.enterprise
	var staff: int = int(rules.employees)
	var lasts: int = int(rules.loss_days_to_close)
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
	s.jobs += staff
	if not b.enabled:
		b.active = false
		e.status = Keys.E_PAUSED
		e.reason = Keys.ER_PAUSED
		return
	var employees: int = mini(staff, maxi(0, int(s.workers) - int(s.employed_workers)))
	var wages: float = employees * Population.worker_wage(sim)
	var equipment: float = float(rules.equipment)
	var fixed: float = equipment + float(e.rent)
	var too_few: bool = employees < int(rules.min_employees)
	if float(sim.state.enterprise_cash) < wages + fixed or too_few:
		e.loss_days += 1
		e.status = Keys.E_RESTRICTED
		e.reason = Keys.ER_NO_WORKERS if too_few else Keys.ER_NO_CASH
		b.active = false
		b.status = Keys.B_RESTRICTED
		if e.loss_days >= lasts:
			e.status = Keys.E_CLOSED
			sim._log("服务社已停业：可雇用工程队或现金不足持续 %d 天。" % lasts)
		return
	e.employees = employees
	s.employed_workers += employees
	s.employed += employees
	b.employed = employees
	b.active = true
	b.status = Keys.B_PRIVATE_OPEN
	sim._transfer("enterprise", "residents", wages, "enterprise.wages", false)
	sim._transfer("enterprise", "public", float(e.rent), "enterprise.rent", true)
	sim._transfer("enterprise", "external", equipment, "enterprise.upkeep", false)
	# Residents purchase useful aggregate repair / laundry / communication services.
	var demand: float = minf(
		float(s.population) * float(rules.demand_per_person),
		employees * float(rules.sales_per_employee)
	)
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
	e.profit_days = int(e.get("profit_days", 0)) + 1 if profit > 0 else 0
	e.status = Keys.E_OPEN
	e.reason = Keys.ER_RUNNING
	if e.loss_days >= lasts:
		e.status = Keys.E_CLOSED
		b.active = false
		sim._log("服务社连续亏损 %d 天，停止营业；居民购买力不足。" % lasts)


static func preview(sim: RefCounted, region: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return {}
	var rules: Dictionary = sim.config.enterprise
	var staff: int = int(rules.employees)
	var overhead: float = float(rules.rent) + float(rules.equipment)
	var wages: float = staff * Population.worker_wage(sim)
	var sales: float = minf(
		float(s.population) * float(rules.demand_per_person),
		staff * float(rules.sales_per_employee)
	)
	return {
		"region": region,
		"population": s.population,
		"workers": maxi(0, int(s.workers) - int(s.employed_workers)),
		"daily_demand": sales,
		"daily_cost": wages + overhead,
		"estimated_profit": sales - wages - overhead,
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
