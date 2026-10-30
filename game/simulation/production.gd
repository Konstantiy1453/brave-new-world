extends RefCounted
## Facility staffing, utilities, output and construction.

const Keys = preload("res://simulation/keys.gd")
const Research = preload("res://simulation/research.gd")
const Market = preload("res://simulation/market.gd")
const Population = preload("res://simulation/population.gd")
const Company = preload("res://simulation/company.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const SITE_BUILDING_CAP: int = 40
const AUTOMATED_KINDS: Array[String] = [
	"mine_ore", "mine_copper", "mine_crystal", "processor", "component_plant"
]
const AUTOMATION_JOB_FACTOR: float = 0.7
const FACTORY_KINDS: Array[String] = ["processor", "component_plant", "farm", "hydroponic_farm"]


## Adds what older saves lack: the components column and building levels.
static func ensure_state(state: Dictionary) -> void:
	for key: String in ["resource_sources", "resource_sinks"]:
		if not state[key].has("components"):
			state[key].components = 0.0
	for s: Dictionary in state.settlements:
		for key: String in ["stock", "stock_delta"]:
			if not s[key].has("components"):
				s[key].components = 0.0
		for b: Dictionary in s.buildings:
			if not b.has("level"):
				b.level = 1
				b.upgrade_days = 0


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
	if sim._has("automation") and b.kind in AUTOMATED_KINDS:
		jobs = ceili(jobs * AUTOMATION_JOB_FACTOR)
	return jobs


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
		"upgrade_days": 0
	}


static func build_preview(sim: RefCounted, region: int, kind: String) -> Dictionary:
	if not sim.config.buildings.has(kind) or region < 0 or region >= sim.state.world.regions.size():
		return {}
	var d: Dictionary = sim.config.buildings[kind].duplicate(true)
	d.cost *= float(sim.state.world.regions[region].get("development_multiplier", 1.0))
	return d


static func build_refusal(sim: RefCounted, region: int, kind: String) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return "请先建立据点"
	if s.arrival > 0:
		return "远征队尚在途中，请等待抵达"
	if not sim.config.buildings.has(kind):
		return "无此设施"
	if s.buildings.size() >= SITE_BUILDING_CAP:
		return "本地区已达到 %d 处设施的土地开发上限" % SITE_BUILDING_CAP
	var d: Dictionary = build_preview(sim, region, kind)
	var reg: Dictionary = sim.state.world.regions[region]
	if kind.begins_with("mine_") and float(reg.deposits.get(d.output, 0)) <= 0:
		return "本地区没有剩余的已探明矿床"
	if d.has("requires_tech") and not sim._has(str(d.requires_tech)):
		return "需要技术：" + str(sim.config.techs[d.requires_tech].name)
	if bool(d.get("megaproject", false)):
		for place: Dictionary in sim.state.settlements:
			for existing: Dictionary in place.buildings:
				if existing.kind == kind:
					return "每颗星球只能建设一座"
	if (
		kind == "farm"
		and (reg.fertility < 0.20 or reg.temperature < -5)
		and not sim._has("adaptation")
	):
		return "土地或气温不适合当前温室技术"
	if bool(d.get("megaproject", false)):
		var total: float = float(d.cost) + _supply_train_cost(sim, s, d)
		return "" if sim.state.cash >= total else "公共资金不足：需要 %.0f（含工程物资采购）" % total
	if sim.state.cash < float(d.cost):
		return "公共资金不足：需要 %.0f" % d.cost
	if s.stock.materials < float(d.materials) or s.stock.parts < float(d.parts):
		return "本地仓库不足：需要 %.0f 建材 / %.0f 部件；远方库存需运输" % [d.materials, d.parts]
	return ""


static func build(sim: RefCounted, region: int, kind: String) -> String:
	var refusal: String = build_refusal(sim, region, kind)
	if refusal != "":
		return refusal
	var s: Dictionary = sim.settlement(region)
	var d: Dictionary = build_preview(sim, region, kind)
	if bool(d.get("megaproject", false)):
		_buy_supply_train(sim, s, d)
	sim._transfer("public", "external", float(d.cost), "invest.build", false, kind)
	consume(sim, s, "materials", float(d.materials))
	consume(sim, s, "parts", float(d.parts))
	s.buildings.append(new_building(sim, kind, int(d.days)))
	sim._log(s.name + "开始建设" + d.name + "，工期 %d 天。" % int(d.days))
	return ""


## What the local store lacks for a megaproject, bought at import price and delivered with it.
static func _supply_train_cost(sim: RefCounted, s: Dictionary, d: Dictionary) -> float:
	var total: float = 0.0
	for key: String in ["materials", "parts"]:
		total += maxf(0.0, float(d[key]) - float(s.stock[key])) * _import_price(sim, key)
	return total


static func _buy_supply_train(sim: RefCounted, s: Dictionary, d: Dictionary) -> void:
	for key: String in ["materials", "parts"]:
		var missing: float = maxf(0.0, float(d[key]) - float(s.stock[key]))
		sim._transfer(
			"public", "external", missing * _import_price(sim, key), "import.stock", false, key
		)
		produce(sim, s, key, missing, "外部进口")


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
		work_order.sort_custom(
			func(a, b):
				var pa: int = (
					0 if a.kind in ["power", "water", "port"] else (1 if a.kind == "lab" else 2)
				)
				var pb: int = (
					0 if b.kind in ["power", "water", "port"] else (1 if b.kind == "lab" else 2)
				)
				return pa < pb
		)
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
		if b.kind == "power":
			s.power_supply += float(d.capacity) * b.efficiency
		if b.kind == "water":
			s.water_supply += (
				float(d.capacity)
				* (0.48 + float(reg.water) * 0.70)
				* b.efficiency
				* water_factor(sim)
				* EventsV2.modifier(sim, int(s.region), "water")
			)
		var pf: float = 0.75 if sim._has("efficiency") else 1.0
		var wf: float = 0.7 if b.kind == "farm" and sim._has("irrigation") else 1.0
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
	for b in s.buildings:
		if b.kind == "service" or b.remaining > 0 or not b.get("enabled", true):
			continue
		if _depleted(sim, s, b):
			continue
		var d: Dictionary = sim.config.buildings[b.kind]
		var eff: float = float(b.efficiency)
		if b.kind.begins_with("mine_") or b.kind in FACTORY_KINDS or b.kind == "foodworks":
			eff *= Company.environmental_factor(s)
		eff *= EventsV2.modifier(
			sim, int(s.region), "mine" if b.kind.begins_with("mine_") else str(b.kind)
		)
		if float(d.power) > 0:
			eff *= power_ratio
		if float(d.water) > 0:
			eff *= water_ratio
		if ration_active(sim) and (b.kind.begins_with("mine_") or b.kind in FACTORY_KINDS):
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
		sim._public_expense(
			float(d.maintenance) * (0.8 if sim._has("efficiency") else 1.0),
			"upkeep.facility",
			"external",
			b.kind
		)
		if eff <= 0.001:
			continue
		match str(b.kind):
			"port":
				s.port_capacity += (
					float(d.capacity)
					* eff
					* float(level_rule(sim, b).get("capacity", 1.0))
					* Megaprojects.port_factor(sim, s)
				)
			"mine_ore", "mine_copper", "mine_crystal":
				var resource: String = d.output
				var amount: float = minf(
					float(reg.deposits[resource]),
					(
						float(d.rate)
						* float(reg.grade.get(resource, 1.0))
						* eff
						* (1.2 if sim._has("survey") else 1.0)
						* output_factor(sim, b)
					)
				)
				reg.deposits[resource] -= amount
				produce(sim, s, resource, amount, "矿产开采")
				if amount <= 0.001:
					b.active = false
					b.status = Keys.B_DEPLETED
					sim._short(s, Keys.SH_DEPLETED, b.kind)
			"hydroponic_farm":
				var grown: float = minf(
					maxf(0, target(sim, s, "food") - float(s.stock.food)), float(d.rate) * eff
				)
				produce(sim, s, "food", grown, "农业生产")
				sim.state.contract.today_food = float(sim.state.contract.today_food) + grown
				if grown <= 0:
					b.status = Keys.B_TARGET_FULL
			"farm":
				var climate: float = farm_climate(sim, int(s.region))
				var amount: float = minf(
					maxf(0, target(sim, s, "food") - float(s.stock.food)),
					(
						float(d.rate)
						* float(reg.fertility)
						* climate
						* eff
						* (1.2 if sim._has("irrigation") else 1.0)
						* output_factor(sim, b)
					)
				)
				produce(sim, s, "food", amount, "农业生产")
				sim.state.contract.today_food = float(sim.state.contract.today_food) + amount
				if amount <= 0:
					b.status = Keys.B_TARGET_FULL
			"processor", "component_plant":
				var boost: float = 1.3 if sim._has("processing") and b.kind == "processor" else 1.0
				boost *= output_factor(sim, b)
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
			"lab":
				pass
			"foodworks":
				pass
	s.employed = int(s.employed_workers) + int(s.employed_scientists)


## A mine with nothing left to dig lets its crew go and stops costing money.
static func _depleted(sim: RefCounted, s: Dictionary, b: Dictionary) -> bool:
	if not str(b.kind).begins_with("mine_"):
		return false
	var output: String = sim.config.buildings[b.kind].output
	return float(sim.state.world.regions[int(s.region)].deposits[output]) <= 0.0


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
	if _source == Keys.SOURCE_PROCESSING:
		if not s.has("exportable"):
			s.exportable = {"materials": 0.0, "parts": 0.0}
		s.exportable[resource] = float(s.exportable.get(resource, 0.0)) + amount


static func consume(sim: RefCounted, s: Dictionary, resource: String, amount: float) -> void:
	amount = minf(maxf(0.0, amount), float(s.stock[resource]))
	s.stock[resource] -= amount
	sim.state.resource_sinks[resource] += amount
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
	return {"materials": 160.0, "parts": 40.0}.get(resource, 120.0)


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
	if b.kind == "habitat" and b.remaining <= 0:
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
				and (b.kind.begins_with("mine_") or b.kind in ["farm", "processor", "foodworks"])
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
static func build_forecast(sim: RefCounted, region: int, kind: String) -> Dictionary:
	var spec: Dictionary = build_preview(sim, region, kind)
	if spec.is_empty():
		return {}
	var s: Dictionary = sim.settlement(region)
	var reg: Dictionary = sim.state.world.regions[region]
	var fee: float = float(sim.config.economy.port_fee)
	var outputs: Dictionary = {}
	var revenue: float = 0.0
	var kind_name: String = kind
	var reserve_days: float = -1.0
	if kind_name.begins_with("mine_"):
		var good: String = spec.output
		var rate: float = (
			float(spec.rate)
			* float(reg.grade.get(good, 1.0))
			* (1.2 if sim._has("survey") else 1.0)
		)
		outputs[good] = rate
		revenue = rate * Market.price(sim, good) * (1.0 - fee)
		var mines: float = 1.0
		for b: Dictionary in s.get("buildings", []):
			if b.kind == kind:
				mines += output_factor(sim, b)
		reserve_days = float(reg.deposits.get(good, 0.0)) / maxf(0.001, rate * mines)
	elif kind_name == "farm":
		var climate: float = farm_climate(sim, region)
		var rate: float = (
			float(spec.rate)
			* float(reg.fertility)
			* climate
			* (1.2 if sim._has("irrigation") else 1.0)
		)
		outputs.food = rate
		revenue = rate * float(sim.config.prices.food) * (1.0 + fee)
	elif kind_name == "hydroponic_farm":
		outputs.food = float(spec.rate)
		revenue = float(spec.rate) * float(sim.config.prices.food) * (1.0 + fee)
	elif kind_name in ["processor", "component_plant"]:
		var boost: float = 1.3 if sim._has("processing") and kind_name == "processor" else 1.0
		for good: String in spec.outputs:
			var made: float = float(spec.outputs[good]) * boost
			outputs[good] = made
			revenue += made * Market.price(sim, good) * (1.0 - fee)
		for good: String in spec.inputs:
			revenue -= float(spec.inputs[good]) * Market.price(sim, good) * (1.0 - fee)
	elif kind_name == "foodworks":
		revenue = (
			float(spec.daily_payment) * (1.0 - fee)
			- float(spec.food_input) * float(sim.config.prices.food) * (1.0 + fee)
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
		"disabled_reason": build_refusal(sim, region, kind),
	}
