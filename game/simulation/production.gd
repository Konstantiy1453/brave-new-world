extends RefCounted
## Facility staffing, utilities, output and construction.

const Keys = preload("res://simulation/keys.gd")
const Research = preload("res://simulation/research.gd")
const Market = preload("res://simulation/market.gd")
const Population = preload("res://simulation/population.gd")
const Company = preload("res://simulation/company.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const Sites = preload("res://simulation/sites.gd")
const Stats = preload("res://simulation/stats.gd")
const Pollution = preload("res://simulation/pollution.gd")
const Copies = preload("res://simulation/copies.gd")
const UTILITY_ROLES: Array[String] = ["power", "water", "port"]
const LOWEST_JOB_FACTOR: float = 0.2
const LOWEST_USE_FACTOR: float = 0.3
const POLLUTED_ROLES: Array[String] = [
	"mine", "harvest", "farm", "indoor_farm", "factory", "foodworks"
]
const RATIONED_ROLES: Array[String] = ["mine", "farm", "indoor_farm", "factory"]
const EVENT_KINDS: Dictionary = {
	"mine": "mine", "harvest": "mine", "farm": "farm", "indoor_farm": "farm", "factory": "processor"
}


## Adds what older saves lack: goods added since, building levels and construction totals.
static func ensure_state(state: Dictionary) -> void:
	for key: String in ["resource_sources", "resource_sinks"]:
		for good: String in Keys.RESOURCES:
			if not state[key].has(good):
				state[key][good] = 0.0
	for s: Dictionary in state.settlements:
		for key: String in ["stock", "stock_delta"]:
			for good: String in Keys.RESOURCES:
				if not s[key].has(good):
					s[key][good] = 0.0
		for b: Dictionary in s.buildings:
			if not b.has("level"):
				b.level = 1
				b.upgrade_days = 0
			if not b.has("total_days"):
				b.total_days = int(b.remaining)


static func role_of(sim: RefCounted, kind: String) -> String:
	return str(sim.config.buildings.get(kind, {}).get("role", ""))


## The rule of this building's current level, or an empty dictionary at level 1.
static func level_rule(sim: RefCounted, b: Dictionary) -> Dictionary:
	var level: int = int(b.get("level", 1))
	if level <= 1:
		return {}
	var rules: Array = sim.config.get("upgrades", {}).get(b.kind, [])
	if level - 2 >= rules.size():
		return {}
	return rules[level - 2]


static func jobs_for(sim: RefCounted, b: Dictionary) -> int:
	var jobs: int = int(sim.config.buildings[b.kind].jobs) + int(level_rule(sim, b).get("jobs", 0))
	var role: String = role_of(sim, b.kind)
	var change: float = 0.0
	if role == "mine":
		change = Research.bonus(sim, "mine_jobs")
	elif role == "factory":
		change = Research.bonus(sim, "factory_jobs")
	return ceili(jobs * maxf(LOWEST_JOB_FACTOR, 1.0 + change))


static func output_factor(sim: RefCounted, b: Dictionary) -> float:
	return float(level_rule(sim, b).get("output", 1.0))


## The next upgrade open to this building, with its price and what stands in the way.
static func upgrade_preview(sim: RefCounted, region: int, index: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or index < 0 or index >= s.buildings.size():
		return {}
	var b: Dictionary = s.buildings[index]
	var rules: Array = sim.config.get("upgrades", {}).get(b.kind, [])
	var step: int = int(b.get("level", 1)) - 1
	if step >= rules.size():
		return {}
	var rule: Dictionary = rules[step].duplicate(true)
	rule.disabled_reason = ""
	if not sim._has(rule.tech):
		rule.disabled_reason = "需要技术：" + str(sim.config.techs[rule.tech].name)
	elif int(b.remaining) > 0:
		rule.disabled_reason = "设施尚在施工"
	elif int(b.upgrade_days) > 0:
		rule.disabled_reason = "升级施工中"
	elif float(sim.state.cash) < float(rule.cost):
		rule.disabled_reason = "公共资金不足：需要 %.0f" % float(rule.cost)
	elif (
		float(s.stock.materials) < float(rule.materials) or float(s.stock.parts) < float(rule.parts)
	):
		rule.disabled_reason = "本地仓库不足：需要 %.0f 建材 / %.0f 部件" % [rule.materials, rule.parts]
	return rule


static func upgrade(sim: RefCounted, region: int, index: int) -> String:
	var rule: Dictionary = upgrade_preview(sim, region, index)
	if rule.is_empty():
		return "此设施没有可用的升级"
	if rule.disabled_reason != "":
		return rule.disabled_reason
	var s: Dictionary = sim.settlement(region)
	var b: Dictionary = s.buildings[index]
	sim._transfer("public", "external", float(rule.cost), "invest.upgrade", false, b.kind)
	consume(sim, s, "materials", float(rule.materials))
	consume(sim, s, "parts", float(rule.parts))
	# The building keeps working at its old level until the upgrade is finished.
	b.upgrade_days = int(rule.days)
	sim._log(
		(
			"%s · %s开始升级到 %d 级，工期 %d 天。"
			% [s.name, sim.config.buildings[b.kind].name, int(rule.level), int(rule.days)]
		)
	)
	return ""


static func _advance_upgrade(sim: RefCounted, s: Dictionary, b: Dictionary) -> void:
	if int(b.upgrade_days) <= 0:
		return
	b.upgrade_days = int(b.upgrade_days) - 1
	if int(b.upgrade_days) == 0:
		b.level = int(b.level) + 1
		sim._log("%s · %s升级完成。" % [s.name, sim.config.buildings[b.kind].name])


static func new_building(_sim: RefCounted, kind: String, remaining: int) -> Dictionary:
	return {
		"kind": kind,
		"remaining": remaining,
		"active": remaining == 0,
		"enabled": true,
		"status": Keys.B_BUILDING if remaining > 0 else Keys.B_PENDING,
		"employed": 0,
		"specialists": 0,
		"efficiency": 0.0,
		"owner": "public",
		"level": 1,
		"upgrade_days": 0,
		"total_days": remaining,
		"plot": -1
	}


static func build_preview(sim: RefCounted, region: int, kind: String) -> Dictionary:
	if not sim.config.buildings.has(kind) or region < 0 or region >= sim.state.world.regions.size():
		return {}
	var d: Dictionary = sim.config.buildings[kind].duplicate(true)
	d.kind_id = kind
	var great: bool = bool(d.get("megaproject", false))
	var cheaper: float = Research.bonus(sim, "build_cost")
	var faster: float = Research.bonus(sim, "build_speed")
	if great:
		cheaper += Research.bonus(sim, "great_cost")
		faster += Research.bonus(sim, "great_speed")
	d.cost *= (
		float(sim.state.world.regions[region].get("development_multiplier", 1.0))
		* maxf(0.3, 1.0 + cheaper)
	)
	# Every further copy of a kind costs a little more cash. Great works are one of a kind, and homes
	# are what the charter's population needs, so neither pays it.
	var exempt: Array = sim.config.economy.get("copy_surcharge_exempt_roles", [])
	var copies: int = (
		0 if great or str(d.get("role", "")) in exempt else Copies.count_kind(sim, kind)
	)
	var surcharge: float = minf(
		float(sim.config.economy.get("copy_surcharge", 0.0)) * copies,
		float(sim.config.economy.get("copy_surcharge_cap", 1.0)) - 1.0
	)
	d.cost *= 1.0 + surcharge
	d.copy_number = copies + 1
	d.copy_surcharge = surcharge
	d.days = ceili(float(d.days) / (1.0 + maxf(0.0, faster)))
	return d


static func build_refusal(sim: RefCounted, region: int, kind: String, plot: int = -1) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return "请先建立据点"
	if s.arrival > 0:
		return "远征队尚在途中，请等待抵达"
	if not sim.config.buildings.has(kind):
		return "无此设施"
	var d: Dictionary = build_preview(sim, region, kind)
	var reg: Dictionary = sim.state.world.regions[region]
	var place_refusal: String = _place_refusal(s, reg, d)
	if place_refusal != "":
		return place_refusal
	var chosen: int = plot if plot >= 0 else Sites.find_plot(sim, region, kind)
	if chosen < 0:
		return _no_plot_reason(kind)
	if chosen >= reg.plots.size() or not Sites.plot_fits(sim, reg.plots[chosen], kind):
		return "这块地不适合此设施"
	for existing: Dictionary in s.buildings:
		if int(existing.plot) == chosen:
			return "这块地已被占用"
	if d.has("requires_tech") and not sim._has(str(d.requires_tech)):
		return "需要技术：" + str(sim.config.techs[d.requires_tech].name)
	if bool(d.get("megaproject", false)):
		for place: Dictionary in sim.state.settlements:
			for existing: Dictionary in place.buildings:
				if existing.kind == kind:
					return "每颗星球只能建设一座"
	if (
		str(d.role) == "farm"
		and not d.has("fertility_floor")
		and (reg.fertility < 0.20 or reg.temperature < -5)
		and not sim._has("adaptation")
	):
		return "土地或气温不适合当前温室技术"
	var short: bool = s.stock.materials < float(d.materials) or s.stock.parts < float(d.parts)
	if short and not bool(d.get("megaproject", false)) and not _port_ready(s):
		return "本地仓库不足：需要 %.0f 建材 / %.0f 部件；没有货运站时要靠道路运来" % [d.materials, d.parts]
	var total: float = float(d.cost) + _supply_train_cost(sim, s, d)
	if sim.state.cash < total:
		if total > float(d.cost):
			return "公共资金不足：需要 %.0f（含工程物资采购）" % total
		return "公共资金不足：需要 %.0f" % d.cost
	return ""


## A working port can buy what a building site lacks, at import price.
static func _port_ready(s: Dictionary) -> bool:
	for b: Dictionary in s.buildings:
		if str(b.kind) == "port" and int(b.remaining) <= 0 and bool(b.get("active", false)):
			return true
	return false


## Whether this kind of building belongs in this kind of settlement on this ground.
static func _place_refusal(s: Dictionary, reg: Dictionary, d: Dictionary) -> String:
	var kinds: Array = d.get("site_kinds", [])
	if not kinds.is_empty() and not kinds.has(str(s.kind)):
		return "只能建在居住据点" if kinds.has(Keys.SITE_RESIDENTIAL) else "只能建在边疆据点"
	if bool(d.get("needs_coast", false)) and not bool(reg.get("coast", false)):
		return "只能建在沿海地点"
	if float(reg.get("ruggedness", 0.0)) < float(d.get("needs_rugged", 0.0)):
		return "只能建在地形崎岖的地点"
	if bool(d.get("unique_local", false)):
		for b: Dictionary in s.buildings:
			if str(b.kind) == str(d.get("kind_id", "")):
				return "每个据点只能有一座"
	return ""


static func _no_plot_reason(kind: String) -> String:
	var ground: String = Sites.plot_kind(kind)
	if ground == "deposit":
		return "本地区没有可用的矿床地块"
	if ground == "farm":
		return "本地区没有可用的农田地块"
	return "本地区没有空闲的建设用地；拆掉用不着的设施或废矿能腾出地块"


static func build(sim: RefCounted, region: int, kind: String, plot: int = -1) -> String:
	var refusal: String = build_refusal(sim, region, kind, plot)
	if refusal != "":
		return refusal
	var s: Dictionary = sim.settlement(region)
	var d: Dictionary = build_preview(sim, region, kind)
	_buy_supply_train(sim, s, d)
	sim._transfer("public", "external", float(d.cost), "invest.build", false, kind)
	consume(sim, s, "materials", float(d.materials))
	consume(sim, s, "parts", float(d.parts))
	var building: Dictionary = new_building(sim, kind, int(d.days))
	building.plot = plot if plot >= 0 else Sites.find_plot(sim, region, kind)
	s.buildings.append(building)
	sim._log(s.name + "开始建设" + d.name + "，工期 %d 天。" % int(d.days))
	return ""


## Pulls a building down and frees its plot. Nothing comes back; a dead mine at least stops costing.
static func demolish(sim: RefCounted, region: int, index: int) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or index < 0 or index >= s.buildings.size():
		return "设施不存在"
	var b: Dictionary = s.buildings[index]
	if str(b.get("owner", "public")) != "public":
		return "民营设施不能拆除"
	if bool(sim.config.buildings.get(b.kind, {}).get("megaproject", false)):
		return "巨型工程不能拆除"
	if str(b.kind) in ["port", "power", "water"] and _last_of(s, str(b.kind)):
		return "这是本据点最后一座，不能拆除"
	s.buildings.remove_at(index)
	_reclaim_plot(sim, s, b)
	sim._log("%s · 拆除了%s。" % [s.name, sim.config.buildings[b.kind].name])
	sim._refresh(s)
	sim._reconcile_jobs(s)
	Research.rebalance(sim, false)
	return ""


## A dug-out deposit becomes ordinary building ground once its mine is gone.
static func _reclaim_plot(sim: RefCounted, s: Dictionary, b: Dictionary) -> void:
	var at: int = int(b.get("plot", -1))
	var reg: Dictionary = sim.state.world.regions[int(s.region)]
	if at < 0 or at >= reg.plots.size():
		return
	var ground: Dictionary = reg.plots[at]
	if str(ground.kind) == "deposit" and float(ground.reserves) <= 0.0:
		reg.plots[at] = {"kind": "general", "x": ground.x, "z": ground.z}


static func _last_of(s: Dictionary, kind: String) -> bool:
	var count: int = 0
	for other: Dictionary in s.buildings:
		if str(other.kind) == kind:
			count += 1
	return count <= 1


## What the local store lacks for a megaproject, bought at import price and delivered with it.
static func _supply_train_cost(sim: RefCounted, s: Dictionary, d: Dictionary) -> float:
	var total: float = 0.0
	for key: String in ["materials", "parts"]:
		total += maxf(0.0, float(d[key]) - float(s.stock[key])) * _import_price(sim, key)
	return total


static func _buy_supply_train(sim: RefCounted, s: Dictionary, d: Dictionary) -> void:
	for key: String in ["materials", "parts"]:
		var missing: float = maxf(0.0, float(d[key]) - float(s.stock[key]))
		if missing <= 0.0:
			continue
		sim._transfer(
			"public", "external", missing * _import_price(sim, key), "import.stock", false, key
		)
		produce(sim, s, key, missing, Keys.SOURCE_IMPORT)


static func _import_price(sim: RefCounted, key: String) -> float:
	return float(sim.config.prices[key]) * (1.0 + float(sim.config.economy.port_fee))


static func run_settlement(sim: RefCounted, s: Dictionary) -> void:
	s.shortages = []
	s.jobs = 0
	s.employed_workers = 0
	s.employed_scientists = 0
	s.port_capacity = 0.0
	s.port_used = 0.0
	s.power_supply = 0.0
	s.water_supply = 0.0
	s.power_demand = 0.0
	s.water_demand = 0.0
	var reg: Dictionary = sim.state.world.regions[int(s.region)]
	var work_order: Array = s.buildings.duplicate()
	var research_requested: bool = int(sim.state.research.contract.staff) > 0
	for project in sim.state.research.projects.values():
		if int(project.staff) > 0:
			research_requested = true
	if research_requested:
		# A staffed project reserves its lab technicians after essential utilities.
		# This moves actual workers out of extraction, never duplicates personnel.
		work_order.sort_custom(func(a, b): return _work_rank(sim, a) < _work_rank(sim, b))
	for b in work_order:
		b.active = false
		b.employed = 0
		b.specialists = 0
		b.efficiency = 0.0
		_advance_upgrade(sim, s, b)
		if b.remaining > 0:
			b.remaining -= 1
			if b.remaining == 0:
				sim._log(
					(
						s.name
						+ " · "
						+ str(sim.config.buildings.get(b.kind, {"name": "社区服务社"}).name)
						+ "竣工。"
					)
				)
		if b.remaining > 0:
			b.status = Keys.B_BUILDING
			continue
		if not b.get("enabled", true):
			b.status = Keys.B_DISABLED
			continue
		if b.kind == "service":
			continue
		if _depleted(sim, s, b):
			b.status = Keys.B_DEPLETED
			sim._short(s, Keys.SH_DEPLETED, b.kind)
			continue
		var d: Dictionary = sim.config.buildings[b.kind]
		var role: String = str(d.role)
		var private_reserved: int = (
			6
			if (
				not sim.state.enterprise.is_empty()
				and int(sim.state.enterprise.region) == int(s.region)
				and sim.state.enterprise.status != Keys.E_CLOSED
			)
			else 0
		)
		var required: int = jobs_for(sim, b)
		var special: int = int(d.get("specialists", 0))
		s.jobs += required + special
		b.employed = mini(
			required, maxi(0, int(s.workers) - private_reserved - int(s.employed_workers))
		)
		b.specialists = mini(special, maxi(0, int(s.scientists) - int(s.employed_scientists)))
		s.employed_workers += b.employed
		s.employed_scientists += b.specialists
		b.efficiency = 1.0
		if required > 0:
			b.efficiency = float(b.employed) / required
		if special > 0:
			b.efficiency = minf(b.efficiency, float(b.specialists) / special)
		if b.efficiency < 1.0:
			sim._short(
				s,
				Keys.SH_JOBS_SPECIALISTS if special > int(b.specialists) else Keys.SH_JOBS_WORKERS,
				b.kind
			)
		b.active = b.efficiency > 0.0
		if role == "power":
			s.power_supply += (
				float(d.capacity)
				* b.efficiency
				* EventsV2.modifier(sim, int(s.region), "power")
				* (1.0 + Research.bonus(sim, "power_output"))
			)
		if role == "water":
			s.water_supply += (
				float(d.capacity)
				* (float(d.site_floor) + float(reg.water) * float(d.site_gain))
				* b.efficiency
				* water_factor(sim)
				* EventsV2.modifier(sim, int(s.region), "water")
				* (1.0 + Research.bonus(sim, "water_output"))
			)
		var pf: float = maxf(LOWEST_USE_FACTOR, 1.0 + Research.bonus(sim, "power_use"))
		var wf: float = maxf(LOWEST_USE_FACTOR, 1.0 + Research.bonus(sim, "water_use"))
		if role == "farm":
			wf = maxf(LOWEST_USE_FACTOR, wf + Research.bonus(sim, "farm_water"))
		var extra_power: float = float(level_rule(sim, b).get("power", 0.0))
		s.power_demand += (float(d.power) + extra_power) * b.efficiency * pf
		s.water_demand += float(d.water) * b.efficiency * wf
	var power_ratio: float = minf(1.0, float(s.power_supply) / maxf(0.001, s.power_demand))
	# Pump stations cannot provide free water with no electricity.
	s.water_supply *= power_ratio
	var water_ratio: float = minf(1.0, float(s.water_supply) / maxf(0.001, s.water_demand))
	if power_ratio < 0.999:
		sim._short(s, Keys.SH_POWER)
	if water_ratio < 0.999:
		sim._short(s, Keys.SH_WATER)
	var clean_air: float = Pollution.factor(sim)
	var field_bonus: float = _field_bonus(sim, s)
	var upkeep_factor: float = maxf(0.2, 1.0 + Research.bonus(sim, "upkeep"))
	for b in s.buildings:
		if b.kind == "service" or b.remaining > 0 or not b.get("enabled", true):
			continue
		if _depleted(sim, s, b):
			continue
		var d: Dictionary = sim.config.buildings[b.kind]
		var role: String = str(d.role)
		var eff: float = float(b.efficiency)
		if role in POLLUTED_ROLES:
			eff *= clean_air
		eff *= EventsV2.modifier(sim, int(s.region), str(EVENT_KINDS.get(role, b.kind)))
		if float(d.power) > 0:
			eff *= power_ratio
		if float(d.water) > 0:
			eff *= water_ratio
		if ration_active(sim) and role in RATIONED_ROLES:
			eff *= 0.85
		b.efficiency = eff
		b.active = eff > 0.001
		b.status = Keys.B_RUNNING if b.active else Keys.B_IDLE
		sim._public_expense(
			(
				float(b.employed) * Population.worker_wage(sim)
				+ float(b.specialists) * Population.scientist_wage(sim)
			),
			"wages.public",
			"residents",
			b.kind
		)
		var cost_factor: float = upkeep_factor
		if role == "mine":
			cost_factor = maxf(0.2, cost_factor + Research.bonus(sim, "mine_upkeep"))
		sim._public_expense(
			float(d.maintenance) * cost_factor, "upkeep.facility", "external", b.kind
		)
		if eff <= 0.001:
			continue
		match role:
			"port":
				s.port_capacity += (
					float(d.capacity)
					* eff
					* float(level_rule(sim, b).get("capacity", 1.0))
					* Megaprojects.port_factor(sim, s)
					* (1.0 + Research.bonus(sim, "port_capacity"))
				)
			"mine":
				var resource: String = d.output
				var seam: Dictionary = Sites.plot_of(sim, s, b)
				var amount: float = minf(
					float(seam.reserves),
					(
						float(d.rate)
						* float(seam.grade)
						* eff
						* field_bonus
						* _good_bonus(sim, resource)
						* output_factor(sim, b)
					)
				)
				seam.reserves = float(seam.reserves) - amount
				if int(seam.depth) == 0 or bool(reg.get("deep_known", false)):
					reg.deposits[resource] = maxf(0.0, float(reg.deposits[resource]) - amount)
				produce(sim, s, resource, amount, "矿产开采")
				if amount <= 0.001:
					b.active = false
					b.status = Keys.B_DEPLETED
					sim._short(s, Keys.SH_DEPLETED, b.kind)
			"harvest":
				for good: String in d.outputs:
					var made: float = (
						float(d.outputs[good]) * eff * field_bonus * _good_bonus(sim, good)
					)
					produce(sim, s, good, made, "矿产开采")
			"indoor_farm":
				var grown: float = minf(
					maxf(0, target(sim, s, "food") - float(s.stock.food)),
					float(d.rate) * eff * field_bonus * (1.0 + Research.bonus(sim, "hydro_output"))
				)
				produce(sim, s, "food", grown, "农业生产")
				sim.state.contract.today_food = float(sim.state.contract.today_food) + grown
				if grown <= 0:
					b.status = Keys.B_TARGET_FULL
			"farm":
				var climate: float = farm_climate(sim, int(s.region))
				var field: Dictionary = Sites.plot_of(sim, s, b)
				var soil: float = maxf(
					float(field.get("fertility", reg.fertility)),
					float(d.get("fertility_floor", 0.0))
				)
				var amount: float = minf(
					maxf(0, target(sim, s, "food") - float(s.stock.food)),
					(
						float(d.rate)
						* soil
						* climate
						* eff
						* field_bonus
						* (1.0 + Research.bonus(sim, "farm_output"))
						* output_factor(sim, b)
					)
				)
				produce(sim, s, "food", amount, "农业生产")
				sim.state.contract.today_food = float(sim.state.contract.today_food) + amount
				if amount <= 0:
					b.status = Keys.B_TARGET_FULL
			"commerce":
				var served: float = minf(float(d.customers), float(s.population)) * eff
				sim._transfer(
					"residents", "public", served * float(d.spend), "commerce.income", true, b.kind
				)
			"income":
				var limited: float = Copies.factor_for(
					sim, b, float(sim.config.economy.get("income_copy_factor", 1.0)), 1
				)
				sim._transfer(
					"external",
					"public",
					float(d.daily_income) * eff * limited,
					"service.income",
					true,
					b.kind
				)
			"factory":
				var boost: float = _factory_boost(sim, b) * output_factor(sim, b)
				var scale: float = 0.0
				var wanted_any: bool = false
				# Coproduct recipe runs when either output has genuine demand; no stock deletion.
				for output in d.outputs:
					var wanted: float = maxf(0, target(sim, s, output) - float(s.stock[output]))
					wanted = maxf(
						wanted,
						(
							EventsV2.reserved(sim, int(s.region), output)
							- float(s.get("exportable", {}).get(output, 0))
						)
					)
					wanted_any = wanted_any or wanted > 0.0
					scale = maxf(scale, wanted / (float(d.outputs[output]) * boost))
				scale = minf(eff, scale)
				for key in d.inputs:
					scale = minf(scale, float(s.stock[key]) / float(d.inputs[key]))
				if scale < eff and wanted_any:
					sim._short(s, Keys.SH_PROCESSOR_INPUT)
				for key in d.inputs:
					consume(sim, s, key, float(d.inputs[key]) * scale)
				for key in d.outputs:
					produce(
						sim, s, key, float(d.outputs[key]) * scale * boost, Keys.SOURCE_PROCESSING
					)
				if scale <= 0:
					b.active = false
					b.status = Keys.B_NO_INPUT if wanted_any else Keys.B_TARGET_FULL
	s.employed = int(s.employed_workers) + int(s.employed_scientists)


static func _work_rank(sim: RefCounted, b: Dictionary) -> int:
	var role: String = role_of(sim, b.kind)
	if role in UTILITY_ROLES:
		return 0
	return 1 if role == "lab" else 2


## Frontier settlements get more out of the ground; everyone else digs at the plain rate.
static func _field_bonus(sim: RefCounted, s: Dictionary) -> float:
	if str(s.get("kind", Keys.SITE_RESIDENTIAL)) != Keys.SITE_FRONTIER:
		return 1.0
	return (
		1.0 + float(sim.config.site_rules.frontier_output) + Research.bonus(sim, "frontier_output")
	)


static func _good_bonus(sim: RefCounted, good: String) -> float:
	return 1.0 + Research.bonus(sim, "mine_output") + Research.bonus(sim, good + "_output")


static func _factory_boost(sim: RefCounted, b: Dictionary) -> float:
	var boost: float = 1.0 + Research.bonus(sim, "factory_output")
	if str(b.kind) == "processor":
		boost += Research.bonus(sim, "processor_output")
	if sim.config.buildings[b.kind].outputs.has("alloy"):
		boost += Research.bonus(sim, "alloy_output")
	return boost


## Export income at risk (1.9 advisor): the share of a window's export value that depends on mines
## with under `mine_warning_days` of reserves left at their full rate. A raw good is at risk by the
## share of its supply (mines and renewable harvest) from such mines; a factory needs every input,
## so what it makes carries the highest risk among them. Read-only: mines without a plot yet are
## skipped rather than given one.
static func mine_outlook(sim: RefCounted, window: Dictionary) -> Dictionary:
	var limit: float = float(sim.config.economy.get("mine_warning_days", 360.0))
	var supply: Dictionary = {}
	var ending: Dictionary = {}
	var factories: Array = []
	for s: Dictionary in sim.state.settlements:
		var plots: Array = sim.state.world.regions[int(s.region)].plots
		var field_bonus: float = _field_bonus(sim, s)
		for b: Dictionary in s.buildings:
			if int(b.get("remaining", 0)) > 0 or not b.get("enabled", true):
				continue
			var d: Dictionary = sim.config.buildings.get(str(b.kind), {})
			var role: String = str(d.get("role", ""))
			if role == "harvest":
				for good: String in d.outputs:
					var made: float = float(d.outputs[good]) * field_bonus * _good_bonus(sim, good)
					supply[good] = float(supply.get(good, 0.0)) + made
			elif role == "factory":
				factories.append(d)
			elif role == "mine" and int(b.get("plot", -1)) >= 0:
				var seam: Dictionary = plots[int(b.plot)]
				var reserves: float = float(seam.get("reserves", 0.0))
				if reserves <= 0.0:
					continue
				var good: String = str(d.output)
				var rate: float = (
					float(d.rate)
					* float(seam.get("grade", 1.0))
					* field_bonus
					* _good_bonus(sim, good)
					* output_factor(sim, b)
				)
				supply[good] = float(supply.get(good, 0.0)) + rate
				if reserves / maxf(rate, 0.001) < limit:
					ending[good] = float(ending.get(good, 0.0)) + rate
	var risk: Dictionary = {}
	for good: String in supply:
		risk[good] = float(ending.get(good, 0.0)) / maxf(float(supply[good]), 0.001)
	# Processing chains are short (ore -> parts -> components -> machinery): a few passes settle.
	for _pass: int in range(4):
		var weighted: Dictionary = {}
		var made: Dictionary = {}
		for d: Dictionary in factories:
			var inputs_risk: float = 0.0
			for good: String in d.inputs:
				inputs_risk = maxf(inputs_risk, float(risk.get(good, 0.0)))
			for good: String in d.outputs:
				weighted[good] = (
					float(weighted.get(good, 0.0)) + inputs_risk * float(d.outputs[good])
				)
				made[good] = float(made.get(good, 0.0)) + float(d.outputs[good])
		for good: String in made:
			risk[good] = float(weighted[good]) / float(made[good])
	var total: float = 0.0
	var at_risk: float = 0.0
	for good: String in window.get("goods", {}):
		var value: float = float(window.goods[good][Stats.EXPORTED]) * Market.price(sim, good)
		total += value
		at_risk += value * float(risk.get(good, 0.0))
	return {
		"share": at_risk / total if total > 0.0 else 0.0,
		"export_value": total,
		"at_risk": at_risk,
		"days": limit,
	}


## A mine with nothing left to dig lets its crew go and stops costing money.
static func _depleted(sim: RefCounted, s: Dictionary, b: Dictionary) -> bool:
	if not str(b.kind).begins_with("mine_"):
		return false
	var seam: Dictionary = Sites.plot_of(sim, s, b)
	return seam.is_empty() or float(seam.reserves) <= 0.0


## Farm yield factor from local temperature, shifted by a climate regulator nearby.
static func farm_climate(sim: RefCounted, region: int) -> float:
	var reg: Dictionary = sim.state.world.regions[region]
	var shift: Dictionary = Megaprojects.climate(sim, region)
	var temperature: float = float(reg.temperature) + float(shift.temperature)
	return clampf(1.0 - absf(temperature - 20.0) / 42.0, 0.25, 1.0) * float(shift.rainfall)


static func water_factor(sim: RefCounted) -> float:
	if (
		int(sim.state.day) < int(sim.state.effects.get("drought_start", 999999))
		or int(sim.state.day) >= int(sim.state.effects.get("drought_until", 0))
	):
		return 1.0
	return 1.0 if sim.state.effects.get("drought_choice", "") == "protect" else 0.8


static func ration_active(sim: RefCounted) -> bool:
	return (
		sim.state.effects.get("drought_choice", "") == "ration"
		and int(sim.state.day) >= int(sim.state.effects.get("drought_start", 999999))
		and int(sim.state.day) < int(sim.state.effects.get("drought_until", 0))
	)


## Workers not spoken for by any enabled facility, including those still under construction.
static func free_workers(sim: RefCounted, s: Dictionary) -> int:
	var committed: int = 0
	for b in s.buildings:
		if b.kind == "service" or not b.get("enabled", true) or _depleted(sim, s, b):
			continue
		committed += jobs_for(sim, b)
	if (
		not sim.state.enterprise.is_empty()
		and int(sim.state.enterprise.region) == int(s.region)
		and sim.state.enterprise.status != Keys.E_CLOSED
	):
		committed += 6
	return maxi(0, int(s.workers) - committed)


## Scientists not assigned to facility specialist posts, research projects or field work.
static func free_specialists(sim: RefCounted, s: Dictionary) -> int:
	var committed: int = 0
	for b in s.buildings:
		if b.kind == "service" or not b.get("enabled", true):
			continue
		committed += int(sim.config.buildings[b.kind].get("specialists", 0))
	return maxi(0, int(s.scientists) - committed - int(s.employed_scientists))


static func produce(
	sim: RefCounted, s: Dictionary, resource: String, amount: float, _source: String
) -> void:
	if amount <= 0:
		return
	s.stock[resource] += amount
	sim.state.resource_sources[resource] += amount
	Stats.goods(
		sim.state,
		resource,
		Stats.IMPORTED if _source == Keys.SOURCE_IMPORT else Stats.PRODUCED,
		amount
	)
	if _source == Keys.SOURCE_PROCESSING:
		if not s.has("exportable"):
			s.exportable = {"materials": 0.0, "parts": 0.0}
		s.exportable[resource] = float(s.exportable.get(resource, 0.0)) + amount


static func consume(sim: RefCounted, s: Dictionary, resource: String, amount: float) -> void:
	amount = minf(maxf(0.0, amount), float(s.stock[resource]))
	s.stock[resource] -= amount
	sim.state.resource_sinks[resource] += amount
	Stats.goods(sim.state, resource, Stats.CONSUMED, amount)
	if s.has("exportable") and s.exportable.has(resource):
		s.exportable[resource] = maxf(0.0, float(s.exportable[resource]) - amount)


static func target(sim: RefCounted, s: Dictionary, resource: String) -> float:
	if s.get("targets", {}).has(resource):
		return float(s.targets[resource])
	if resource == "food":
		return maxf(
			float(sim.progression.production.food_min_target),
			(
				float(s.population)
				* float(sim.config.economy.food_per_person)
				* float(sim.progression.production.target_days)
			)
		)
	return sim.progression.production.default_targets.get(resource, 120.0)


static func set_stock_target(sim: RefCounted, args: Dictionary) -> String:
	var s: Dictionary = sim.settlement(int(args.get("region", -1)))
	var resource: String = str(args.get("resource", ""))
	var target: float = float(args.get("target", 0))
	if s.is_empty() or not resource in Keys.RESOURCES:
		return "请选择有效据点与物资"
	if not is_finite(target) or target < 0 or target > 10000:
		return "目标库存应在 0—10000 之间"
	if not s.has("targets"):
		s.targets = {}
	s.targets[resource] = target
	return ""


static func toggle_preview(sim: RefCounted, region: int, index: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or index < 0 or index >= s.buildings.size():
		return {}
	var b: Dictionary = s.buildings[index]
	var housing: int = int(s.housing)
	if role_of(sim, b.kind) == "housing" and b.remaining <= 0:
		housing += Population.habitat_beds(sim, b) * (-1 if b.enabled else 1)
	return {
		"housing_after": housing,
		"housing_shortfall": maxi(0, int(s.population) - housing),
		"enabled_after": not bool(b.enabled)
	}


static func batch_toggle(sim: RefCounted, args: Dictionary) -> String:
	var s: Dictionary = sim.settlement(int(args.get("region", -1)))
	if s.is_empty():
		return "请选择已建立的据点"
	var category: String = str(args.get("category", "all"))
	for b in s.buildings:
		if b.get("owner", "public") == "private":
			continue
		if (
			category == "all"
			or category == b.kind
			or (
				category == "production"
				and role_of(sim, b.kind) in ["mine", "harvest", "farm", "factory", "foodworks"]
			)
		):
			b.enabled = bool(args.get("enabled", true))
		if not b.enabled:
			b.active = false
			b.status = Keys.B_DISABLED
	sim._refresh(s)
	Research.rebalance(sim, false)
	return ""


static func toggle(sim: RefCounted, region: int, index: int) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or index < 0 or index >= s.buildings.size():
		return "设施不存在"
	var building: Dictionary = s.buildings[index]
	building.enabled = not bool(building.get("enabled", true))
	if not building.enabled:
		building.active = false
		building.status = Keys.B_DISABLED
	sim._refresh(s)
	Research.rebalance(sim, false)
	return ""


## Everything a player or bot needs before committing: cost, output, money per day, payback.
static func build_forecast(
	sim: RefCounted, region: int, kind: String, plot: int = -1
) -> Dictionary:
	var spec: Dictionary = build_preview(sim, region, kind)
	if spec.is_empty():
		return {}
	var s: Dictionary = sim.settlement(region)
	var reg: Dictionary = sim.state.world.regions[region]
	var chosen: int = plot if plot >= 0 else Sites.find_plot(sim, region, kind)
	var ground: Dictionary = reg.plots[chosen] if chosen >= 0 else {}
	var fee: float = float(sim.config.economy.port_fee)
	var outputs: Dictionary = {}
	var revenue: float = 0.0
	var role: String = str(spec.role)
	var reserve_days: float = -1.0
	var field_bonus: float = _field_bonus(sim, s) if not s.is_empty() else 1.0
	if role == "mine":
		var good: String = spec.output
		var rate: float = (
			float(spec.rate)
			* float(ground.get("grade", reg.grade.get(good, 1.0)))
			* field_bonus
			* _good_bonus(sim, good)
		)
		outputs[good] = rate
		revenue = rate * Market.price(sim, good) * (1.0 - fee)
		reserve_days = float(ground.get("reserves", 0.0)) / maxf(0.001, rate)
	elif role == "harvest":
		for good: String in spec.outputs:
			var made: float = float(spec.outputs[good]) * field_bonus * _good_bonus(sim, good)
			outputs[good] = made
			revenue += made * Market.price(sim, good) * (1.0 - fee)
	elif role == "farm":
		var climate: float = farm_climate(sim, region)
		var soil: float = maxf(
			float(ground.get("fertility", reg.fertility)), float(spec.get("fertility_floor", 0.0))
		)
		var rate: float = (
			float(spec.rate)
			* soil
			* climate
			* field_bonus
			* (1.0 + Research.bonus(sim, "farm_output"))
		)
		outputs.food = rate
		revenue = rate * float(sim.config.prices.food) * (1.0 + fee)
	elif role == "indoor_farm":
		var rate: float = (
			float(spec.rate) * field_bonus * (1.0 + Research.bonus(sim, "hydro_output"))
		)
		outputs.food = rate
		revenue = rate * float(sim.config.prices.food) * (1.0 + fee)
	elif role == "factory":
		var boost: float = _factory_boost(sim, {"kind": kind})
		# What the colony builds with replaces imports: worth the import price, not the export one.
		var local: Array = sim.config.economy.get("forecast_import_valued", [])
		for good: String in spec.outputs:
			var made: float = float(spec.outputs[good]) * boost
			outputs[good] = made
			if good in local:
				revenue += (
					made * maxf(_import_price(sim, good), Market.price(sim, good) * (1.0 - fee))
				)
			else:
				revenue += made * Market.price(sim, good) * (1.0 - fee)
		for good: String in spec.inputs:
			revenue -= float(spec.inputs[good]) * Market.price(sim, good) * (1.0 - fee)
	elif role == "foodworks":
		var order: float = Copies.next_factor(
			sim,
			kind,
			float(sim.config.economy.get("foodworks_copy_factor", 1.0)),
			int(sim.config.economy.get("foodworks_free_copies", 0))
		)
		revenue = (
			(
				float(spec.daily_payment)
				* order
				* (1.0 + Research.bonus(sim, "foodworks"))
				* (1.0 - fee)
			)
			- float(spec.food_input) * float(sim.config.prices.food) * (1.0 + fee)
		)
	elif role == "commerce":
		revenue = float(spec.customers) * float(spec.spend)
	elif role == "income":
		revenue = (
			float(spec.daily_income)
			* Copies.next_factor(
				sim, kind, float(sim.config.economy.get("income_copy_factor", 1.0)), 1
			)
		)
	var jobs: int = jobs_for(sim, {"kind": kind, "level": 1})
	var wages: float = (
		jobs * Population.worker_wage(sim)
		+ float(spec.get("specialists", 0)) * Population.scientist_wage(sim)
	)
	var net: float = revenue - wages - float(spec.maintenance)
	var outlay: float = (
		float(spec.cost)
		+ float(spec.materials) * float(sim.config.prices.materials)
		+ float(spec.parts) * float(sim.config.prices.parts)
	)
	return {
		"kind": kind,
		"name": spec.name,
		"cost": float(spec.cost),
		"materials": float(spec.materials),
		"parts": float(spec.parts),
		"days": int(spec.days),
		"jobs": jobs,
		"specialists": int(spec.get("specialists", 0)),
		"power": float(spec.power),
		"water": float(spec.water),
		"maintenance": float(spec.maintenance),
		"outputs": outputs,
		"revenue_per_day": revenue,
		"wages_per_day": wages,
		"net_per_day": net,
		"payback_days": outlay / net if net > 0.0 else -1.0,
		"reserve_days": reserve_days,
		"free_workers": free_workers(sim, s) if not s.is_empty() else 0,
		"plot": chosen,
		"disabled_reason": build_refusal(sim, region, kind, plot),
	}
