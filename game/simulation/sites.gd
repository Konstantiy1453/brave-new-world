extends RefCounted
## Founding settlements at candidate sites.

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Contract = preload("res://simulation/contract.gd")


static func settle(sim: RefCounted, region: int) -> String:
	if region < 0 or region >= sim.state.world.regions.size():
		return "请选择候选地区"
	if not sim.settlement(region).is_empty():
		return "此地区已经建立据点"
	if sim.state.settlements.size() >= Contract.settlement_cap(sim):
		return "需要先完成合同阶段，取得下一处据点的远征许可"
	var first: bool = sim.state.settlements.is_empty()
	var reg: Dictionary = sim.state.world.regions[region]
	if first:
		var expandable: bool = false
		for other in sim.state.world.candidates:
			if int(other) == region:
				continue
			if WorldGen.new().route(sim.geo, region, int(other), true).reachable:
				expandable = true
				break
		if not expandable:
			return "该登陆点没有可达的第二陆地据点，无法履行双据点合同"
	if not first:
		var src: Dictionary = sim.state.settlements[0]
		var road: Dictionary = WorldGen.new().route(sim.geo, int(src.region), region, false)
		if not road.reachable:
			road = WorldGen.new().route(sim.geo, int(src.region), region, true)
		if not road.reachable:
			return "此地区没有可达陆路；当前不具备海运能力"
		if sim.state.cash < 650:
			return "建立前哨需要 650 资金"
		if src.workers < 22:
			return "首府技术工人不足 22 人"
		if src.stock.materials < 35 or src.stock.parts < 6 or src.stock.food < 100:
			return "首府需备齐 35 建材、6 部件、100 食品作为前哨远征物资"
		sim._transfer("public", "external", 650.0, "invest.outpost", false)
		sim._consume(src, "materials", 35.0)
		sim._consume(src, "parts", 6.0)
		# Expedition population migrates; food stays physically in its convoy until arrival.
		src.workers -= 18
		src.population -= 18
		sim._reconcile_jobs(src)
	var op: Dictionary = sim.config.openings[sim.state.advantage]
	var workers: int = int(op.workers) if first else 18
	var scientists: int = int(op.scientists) if first else 0
	var children: int = int(op.children) if first else 0
	var landing_beds: int = int(
		sim.pop_rules.housing.capital if first else sim.pop_rules.housing.outpost
	)
	var s: Dictionary = {
		"region": region,
		"name": reg.name,
		"population": workers + scientists + children,
		"children": children,
		"workers": workers,
		"scientists": scientists,
		"stock": sim._stock(),
		"stock_delta": sim._stock(),
		"buildings": [],
		"jobs": 0,
		"housing": landing_beds,
		"base_housing": landing_beds,
		"arrival_accrual": 0.0,
		"science_accrual": 0.0,
		"birth_accrual": 0.0,
		"attractiveness": 1.0,
		"attractiveness_parts": {},
		"food_days": 0.0,
		"shortages": [],
		"employed": 0,
		"employed_workers": 0,
		"employed_scientists": 0,
		"power_supply": 0.0,
		"power_demand": 0.0,
		"water_supply": 0.0,
		"water_demand": 0.0,
		"starvation": 0,
		"arrival": 0,
		"cohorts": [],
		"port_used": 0.0,
		"port_capacity": 0.0,
		"food_consumed": 0.0
	}
	if first:
		for res in ["materials", "parts", "food"]:
			sim._produce(s, res, float(op[res]), "初始公司物资")
		for kind in ["power", "water", "port"]:
			s.buildings.append(sim._building(kind, 0))
		for kind: String in op.get("prefab", []):
			s.buildings.append(sim._building(kind, 0))
		for tech: String in op.get("head_start", {}):
			sim.state.research.projects[tech] = {
				"staff": 0,
				"work": float(op.head_start[tech]),
				"effective": 0,
				"rate": 0.0,
				"reason": ""
			}
		# Initial child cohorts age after 8 simulated years, adults are aggregate groups.
		s.cohorts.append({"count": children, "mature_day": 2880})
	else:
		var src: Dictionary = sim.state.settlements[0]
		var road: Dictionary = WorldGen.new().route(sim.geo, int(src.region), region, true)
		s.arrival = int(road.days)
		for kind in ["power", "water"]:
			s.buildings.append(sim._building(kind, int(road.days)))
		src.stock.food -= 100.0
		sim.state.shipments.append(
			{
				"from": src.region,
				"to": region,
				"resource": "food",
				"amount": 100.0,
				"remaining": int(road.days),
				"total_days": int(road.days),
				"expedition": true
			}
		)
		# Construction stores travel in the one-time expedition, funded above.
		# The prefab frame consumed 15 materials + 2 parts; remaining kit travels.
		sim.state.resource_sinks.materials -= 20.0
		sim.state.resource_sinks.parts -= 4.0
		for pair in [["materials", 20.0], ["parts", 4.0]]:
			sim.state.shipments.append(
				{
					"from": src.region,
					"to": region,
					"resource": pair[0],
					"amount": pair[1],
					"remaining": int(road.days),
					"total_days": int(road.days),
					"expedition": true
				}
			)
	sim.state.settlements.append(s)
	sim.state.status = "active" if sim.state.status == "planning" else sim.state.status
	sim._refresh(s)
	sim._log(
		(
			("登陆完成：" if first else "远征队出发：")
			+ reg.name
			+ ("。建设轻型矿场即可开始出口。" if first else "；物资和人员抵达后开始运行。")
		)
	)
	return ""
