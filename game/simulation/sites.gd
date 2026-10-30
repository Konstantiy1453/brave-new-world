extends RefCounted
## Candidate sites and their plots: founding settlements, what is known about a site, surveys,
## and which plot a building stands on. `state.world.regions` is the list of sites.

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Contract = preload("res://simulation/contract.gd")
const Logistics = preload("res://simulation/logistics.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Rules = preload("res://simulation/rules.gd")

const GOODS: Array[String] = ["ore", "copper", "crystal"]
const PLOT_SPACING: float = 6.0
const LEGACY_TOWN_OFFSET: float = 12.0
const MINE_KINDS: Dictionary = {
	"mine_ore": "ore", "mine_copper": "copper", "mine_crystal": "crystal"
}
const FARM_KINDS: Array[String] = ["farm"]
const LEGACY_FREE_GENERAL: int = 8
const LEGACY_MIN_GENERAL: int = 20
const LEGACY_MIN_FARMS: int = 4


## Saves from before sites gain plots, survey state and the fields sites have now.
static func ensure_state(state: Dictionary) -> void:
	if not state.has("surveys"):
		state.surveys = []
	for reg: Dictionary in state.world.regions:
		if not reg.has("plots"):
			_legacy_site(state, reg)
	for s: Dictionary in state.settlements:
		for b: Dictionary in s.buildings:
			if not b.has("plot"):
				b.plot = -1
		_legacy_claims(state, s)


static func _legacy_site(state: Dictionary, reg: Dictionary) -> void:
	reg.archetype = str(reg.get("archetype", ""))
	var joined: bool = not reg.get("neighbors", []).is_empty()
	reg.landmass = int(reg.get("landmass", 0 if joined else -1 - int(reg.id)))
	reg.ruggedness = float(reg.get("ruggedness", 0.0))
	reg.coast = bool(reg.get("coast", false))
	reg.survey = 1
	reg.risks = {"cold": 0.0, "arid": 0.0, "flood": 0.0}
	var buildings: Array = []
	for s: Dictionary in state.settlements:
		if int(s.region) == int(reg.id):
			buildings = s.buildings
	reg.plots = _legacy_plots(reg, buildings)


## Plots for a site that never had any, sized so every existing building has a matching one.
static func _legacy_plots(reg: Dictionary, buildings: Array) -> Array:
	var rules: Dictionary = Rules.read("geography").plots
	var mines: Dictionary = {"ore": 0, "copper": 0, "crystal": 0}
	var farms: int = 0
	var others: int = 0
	for b: Dictionary in buildings:
		if MINE_KINDS.has(b.kind):
			mines[MINE_KINDS[b.kind]] += 1
		elif b.kind == "farm":
			farms += 1
		else:
			others += 1
	var offset: float = LEGACY_TOWN_OFFSET if bool(reg.get("river", false)) else 0.0
	var plots: Array = []
	var slot: int = 0
	for _i: int in range(maxi(others + LEGACY_FREE_GENERAL, LEGACY_MIN_GENERAL)):
		var at: Vector2 = _spiral(slot, offset)
		plots.append({"kind": "general", "x": at.x, "z": at.y})
		slot += 1
	for _i: int in range(maxi(farms, LEGACY_MIN_FARMS)):
		var at: Vector2 = _spiral(slot, offset)
		plots.append({"kind": "farm", "fertility": float(reg.fertility), "x": at.x, "z": at.y})
		slot += 1
	for good: String in GOODS:
		var tonnes: float = float(reg.deposits[good])
		var count: int = int(mines[good])
		if tonnes > 0.0:
			count = maxi(
				count,
				mini(
					ceili(tonnes / float(rules.tonnes_per_plot[good])), int(rules.max_deposit_plots)
				)
			)
		for _i: int in range(count):
			var at: Vector2 = _spiral(slot, offset)
			(
				plots
				. append(
					{
						"kind": "deposit",
						"resource": good,
						"grade": float(reg.grade[good]),
						"reserves": tonnes / count,
						"depth": 0,
						"hidden": false,
						"x": at.x,
						"z": at.y,
					}
				)
			)
			slot += 1
	return plots


## Square rings around the town, leaving the main street free.
static func _spiral(index: int, offset: float) -> Vector2:
	var ring: int = 1
	var left: int = index
	while left >= ring * 8:
		left -= ring * 8
		ring += 1
	var side: int = left / (ring * 2)
	var along: int = left % (ring * 2) - ring
	var x: int = ring
	var z: int = along
	match side:
		1:
			x = -along
			z = ring
		2:
			x = -ring
			z = -along
		3:
			x = along
			z = -ring
	return Vector2(x * PLOT_SPACING + offset + 3.0, z * PLOT_SPACING + 3.0)


static func _legacy_claims(state: Dictionary, s: Dictionary) -> void:
	var reg: Dictionary = state.world.regions[int(s.region)]
	var taken: Dictionary = {}
	for b: Dictionary in s.buildings:
		if int(b.plot) >= 0:
			taken[int(b.plot)] = true
	for b: Dictionary in s.buildings:
		if int(b.plot) >= 0:
			continue
		var want: String = plot_kind(str(b.kind))
		for index: int in range(reg.plots.size()):
			var plot: Dictionary = reg.plots[index]
			if taken.has(index) or plot.kind != want:
				continue
			if want == "deposit" and plot.resource != MINE_KINDS[b.kind]:
				continue
			b.plot = index
			taken[index] = true
			break


static func plot_kind(building_kind: String) -> String:
	if MINE_KINDS.has(building_kind):
		return "deposit"
	return "farm" if building_kind in FARM_KINDS else "general"


static func _taken(s: Dictionary) -> Dictionary:
	var taken: Dictionary = {}
	for b: Dictionary in s.buildings:
		if int(b.get("plot", -1)) >= 0:
			taken[int(b.plot)] = true
	return taken


## Whether a building of this kind may stand on this plot, ignoring whether it is free.
static func plot_fits(sim: RefCounted, plot: Dictionary, building_kind: String) -> bool:
	if plot.kind != plot_kind(building_kind):
		return false
	if plot.kind != "deposit":
		return true
	if plot.resource != MINE_KINDS[building_kind] or bool(plot.hidden):
		return false
	if float(plot.reserves) <= 0.0:
		return false
	return int(plot.depth) == 0 or sim._has("deep_mining")


## The best free plot for a building, or -1. Richest ground first; the town fills from the centre.
static func find_plot(sim: RefCounted, region: int, building_kind: String) -> int:
	var reg: Dictionary = sim.state.world.regions[region]
	var s: Dictionary = sim.settlement(region)
	var taken: Dictionary = _taken(s) if not s.is_empty() else {}
	var best: int = -1
	var best_score: float = -INF
	for index: int in range(reg.plots.size()):
		var plot: Dictionary = reg.plots[index]
		if taken.has(index) or not plot_fits(sim, plot, building_kind):
			continue
		var score: float = -float(index)
		if plot.kind == "deposit":
			score = float(plot.grade)
		elif plot.kind == "farm":
			score = float(plot.fertility)
		if score > best_score:
			best_score = score
			best = index
	return best


## The plot a mine digs or a farm tills, claiming one for a building that has none yet.
static func plot_of(sim: RefCounted, s: Dictionary, b: Dictionary) -> Dictionary:
	var region: int = int(s.region)
	if int(b.plot) < 0:
		b.plot = find_plot(sim, region, str(b.kind))
	if int(b.plot) < 0:
		return {}
	return sim.state.world.regions[region].plots[int(b.plot)]


## Free plots at a site by kind, for the build page and the bots.
static func free_counts(sim: RefCounted, region: int) -> Dictionary:
	var reg: Dictionary = sim.state.world.regions[region]
	var s: Dictionary = sim.settlement(region)
	var taken: Dictionary = _taken(s) if not s.is_empty() else {}
	var counts: Dictionary = {"general": 0, "farm": 0, "ore": 0, "copper": 0, "crystal": 0}
	for index: int in range(reg.plots.size()):
		if taken.has(index):
			continue
		var plot: Dictionary = reg.plots[index]
		if plot.kind == "deposit":
			if not bool(plot.hidden) and float(plot.reserves) > 0.0:
				if int(plot.depth) == 0 or sim._has("deep_mining"):
					counts[plot.resource] += 1
		else:
			counts[plot.kind] += 1
	return counts


static func _band(sim: RefCounted, reg: Dictionary) -> float:
	var rules: Dictionary = sim.progression_geo().survey
	if int(reg.survey) >= 1 or not sim.settlement(int(reg.id)).is_empty():
		return 0.0 if sim._has("survey") else float(rules.ground_band)
	return float(rules.orbital_band)


## A true value seen through the survey band: `low..high` always holds it, off centre by a fixed
## amount per site, so better information visibly narrows towards the truth.
static func _estimate(
	sim: RefCounted, reg: Dictionary, value: float, band: float, salt: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = (absi(int(sim.state.world.seed)) * 131 + int(reg.id) * 977 + salt) * 1000003 + 3
	var u: float = rng.randf()
	var low: float = value * (1.0 - band * (0.5 + u))
	var high: float = value * (1.0 + band * (1.5 - u))
	return {"low": low, "high": high, "mid": (low + high) * 0.5}


## What the colony knows about a site right now.
static func view(sim: RefCounted, site: int) -> Dictionary:
	if site < 0 or site >= sim.state.world.regions.size():
		return {}
	var reg: Dictionary = sim.state.world.regions[site]
	var band: float = _band(sim, reg)
	var deposits: Dictionary = {}
	var grades: Dictionary = {}
	var salt: int = 1
	for good: String in GOODS:
		deposits[good] = _estimate(sim, reg, float(reg.deposits[good]), band, salt)
		grades[good] = _estimate(sim, reg, float(reg.grade[good]), band * 0.5, salt + 10)
		salt += 1
	return {
		"id": site,
		"name": reg.name,
		"terrain": reg.terrain,
		"archetype": reg.get("archetype", ""),
		"band": band,
		"survey": int(reg.survey),
		"surveying": _surveying(sim, site),
		"deposits": deposits,
		"grades": grades,
		"fertility": _estimate(sim, reg, float(reg.fertility), band * 0.5, 30),
		"water": _estimate(sim, reg, float(reg.water), band * 0.5, 31),
		"temperature": float(reg.temperature),
		"elevation": float(reg.elevation),
		"coast": bool(reg.coast),
		"river": bool(reg.river),
		"risks": reg.risks,
		"development": float(reg.development_multiplier),
		"plots": free_counts(sim, site),
		"neighbors": reg.neighbors,
	}


static func _surveying(sim: RefCounted, site: int) -> int:
	for entry: Dictionary in sim.state.surveys:
		if int(entry.site) == site:
			return int(entry.days)
	return 0


static func survey_cost(sim: RefCounted) -> float:
	var rules: Dictionary = sim.progression_geo().survey
	var cost: float = float(rules.cost)
	if sim._has("prospecting"):
		cost *= float(rules.prospecting_cost_factor)
	return cost


## Sends a ground survey team. With prospecting it also uncovers hidden deposits nearby.
static func survey(sim: RefCounted, site: int) -> String:
	if site < 0 or site >= sim.state.world.regions.size():
		return "请选择候选地点"
	var reg: Dictionary = sim.state.world.regions[site]
	if int(reg.survey) >= 1 and not sim._has("prospecting"):
		return "此地点已完成地面勘察"
	if _surveying(sim, site) > 0:
		return "勘察队已在途中"
	var cost: float = survey_cost(sim)
	if float(sim.state.cash) < cost:
		return "地面勘察需要 %.0f 资金" % cost
	sim._transfer("public", "external", cost, "invest.survey", false)
	sim.state.surveys.append({"site": site, "days": int(sim.progression_geo().survey.days)})
	return ""


static func daily(sim: RefCounted) -> void:
	var keep: Array = []
	for entry: Dictionary in sim.state.surveys:
		entry.days = int(entry.days) - 1
		if int(entry.days) > 0:
			keep.append(entry)
			continue
		var reg: Dictionary = sim.state.world.regions[int(entry.site)]
		reg.survey = maxi(int(reg.survey), 1)
		sim._log("%s地面勘察完成。" % reg.name)
		if sim._has("prospecting"):
			_reveal_nearby(sim, reg)
	sim.state.surveys = keep


static func _reveal_nearby(sim: RefCounted, reg: Dictionary) -> void:
	var radius: float = deg_to_rad(float(sim.progression_geo().survey.prospecting_radius_degrees))
	var here: Vector3 = WorldGen.unit_point(float(reg.lat), float(reg.lon))
	var found: int = 0
	for other: Dictionary in sim.state.world.regions:
		if here.angle_to(WorldGen.unit_point(float(other.lat), float(other.lon))) > radius:
			continue
		for plot: Dictionary in other.plots:
			if plot.kind == "deposit" and bool(plot.hidden):
				plot.hidden = false
				found += 1
		SiteGen.refresh_deposits(other)
	if found > 0:
		sim._log("远程勘测在 %s 周边发现 %d 处隐藏矿床。" % [reg.name, found])


## Deep deposits count once the colony can mine them.
static func on_technology(sim: RefCounted, tech: String) -> void:
	if tech != "deep_mining":
		return
	for reg: Dictionary in sim.state.world.regions:
		reg.deep_known = true
		SiteGen.refresh_deposits(reg)


## What starting here looks like from orbit, for the map and for bots choosing a site.
static func start_score(sim: RefCounted, site: int) -> float:
	var known: Dictionary = view(sim, site)
	var value: float = 0.0
	for good: String in GOODS:
		value += (
			float(known.deposits[good].mid)
			* float(sim.config.prices[good])
			* float(known.grades[good].mid)
		)
	value *= 0.7 + 0.6 * float(known.water.mid)
	return value / float(known.development)


static func _expedition_source(sim: RefCounted, region: int, from: int) -> Dictionary:
	if from >= 0:
		return sim.settlement(from)
	# The nearest settlement that can reach the site, preferring one with people and supplies.
	var rules: Dictionary = sim.config.outpost
	var there: Dictionary = sim.state.world.regions[region]
	var at: Vector3 = WorldGen.unit_point(float(there.lat), float(there.lon))
	var best: Dictionary = {}
	var best_angle: float = INF
	for s: Dictionary in sim.state.settlements:
		if int(s.arrival) > 0:
			continue
		var ready: bool = (
			int(s.workers) >= int(rules.min_source_workers)
			and float(s.stock.materials) >= float(rules.materials)
			and float(s.stock.parts) >= float(rules.parts)
			and float(s.stock.food) >= float(rules.food)
		)
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		var angle: float = at.angle_to(WorldGen.unit_point(float(reg.lat), float(reg.lon)))
		if not ready:
			angle += TAU
		if not bool(_expedition_route(sim, int(s.region), region).reachable):
			angle += TAU * 2.0
		if angle < best_angle:
			best_angle = angle
			best = s
	return best


## How an expedition would travel: by land if it can, by sea with the technology and a port.
static func _expedition_route(sim: RefCounted, from: int, to: int) -> Dictionary:
	var road: Dictionary = Logistics.route_between(sim, from, to, "engineered")
	if bool(road.reachable):
		return road
	var sea: Dictionary = Logistics.route_between(sim, from, to, "sea")
	if not bool(sea.reachable):
		return sea
	if not sim._has(str(sim.config.roads.sea.tech)):
		sea.reachable = false
		sea.reason = "此地点没有可达陆路；需要沿海航运技术"
	elif not Logistics._has_port(sim.settlement(from)):
		sea.reachable = false
		sea.reason = "海上远征需要出发地有运转的货运站"
	return sea


static func settle(sim: RefCounted, region: int, from: int = -1) -> String:
	if region < 0 or region >= sim.state.world.regions.size():
		return "请选择候选地区"
	if not sim.settlement(region).is_empty():
		return "此地区已经建立据点"
	if sim.state.settlements.size() >= Contract.settlement_cap(sim):
		return "需要先完成合同阶段，取得下一处据点的远征许可"
	var first: bool = sim.state.settlements.is_empty()
	var reg: Dictionary = sim.state.world.regions[region]
	if first and not _can_expand_from(sim, region):
		return "该登陆点没有可达的第二陆地据点，无法履行双据点合同"
	var src: Dictionary = {}
	var road: Dictionary = {}
	var rules: Dictionary = sim.config.outpost
	if not first:
		src = _expedition_source(sim, region, from)
		if src.is_empty():
			return "请选择出发据点"
		road = _expedition_route(sim, int(src.region), region)
		if not bool(road.reachable):
			return str(road.get("reason", "此地区没有可达陆路；当前不具备海运能力"))
		if sim.state.cash < float(rules.cash):
			return "建立前哨需要 %.0f 资金" % float(rules.cash)
		if int(src.workers) < int(rules.min_source_workers):
			return "出发据点技术工人不足 %d 人" % int(rules.min_source_workers)
		if (
			float(src.stock.materials) < float(rules.materials)
			or float(src.stock.parts) < float(rules.parts)
			or float(src.stock.food) < float(rules.food)
		):
			return (
				"出发据点需备齐 %.0f 建材、%.0f 部件、%.0f 食品作为前哨远征物资"
				% [float(rules.materials), float(rules.parts), float(rules.food)]
			)
		sim._transfer("public", "external", float(rules.cash), "invest.outpost", false)
		sim._consume(src, "materials", float(rules.materials))
		sim._consume(src, "parts", float(rules.parts))
		# Expedition population migrates; food stays physically in its convoy until arrival.
		src.workers -= int(rules.workers)
		src.population -= int(rules.workers)
		sim._reconcile_jobs(src)
	var op: Dictionary = sim.config.openings[sim.state.advantage]
	var workers: int = int(op.workers) if first else int(rules.workers)
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
	sim.state.settlements.append(s)
	if first:
		for res in ["materials", "parts", "food"]:
			sim._produce(s, res, float(op[res]), "初始公司物资")
		for kind in ["power", "water", "port"]:
			_place_prefab(sim, s, kind, 0)
		for kind: String in op.get("prefab", []):
			_place_prefab(sim, s, kind, 0)
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
		s.arrival = int(road.days)
		for kind in ["power", "water"]:
			_place_prefab(sim, s, kind, int(road.days))
		# A landing by sea brings its own terminal: nothing else could supply it.
		if str(road.variant) == "sea":
			_place_prefab(sim, s, "port", int(road.days))
		src.stock.food -= float(rules.food)
		_expedition_cargo(sim, src, region, "food", float(rules.food), int(road.days))
		# Construction stores travel in the one-time expedition, funded above.
		# The prefab frame consumed 15 materials + 2 parts; remaining kit travels.
		var kit_materials: float = float(rules.materials) - 15.0
		var kit_parts: float = float(rules.parts) - 2.0
		sim.state.resource_sinks.materials -= kit_materials
		sim.state.resource_sinks.parts -= kit_parts
		_expedition_cargo(sim, src, region, "materials", kit_materials, int(road.days))
		_expedition_cargo(sim, src, region, "parts", kit_parts, int(road.days))
	reg.survey = maxi(int(reg.survey), 1)
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


static func _can_expand_from(sim: RefCounted, region: int) -> bool:
	if str(sim.geo.version) == WorldGen.VERSION:
		return not sim.state.world.regions[region].neighbors.is_empty()
	for other: Variant in sim.state.world.candidates:
		if int(other) != region:
			if WorldGen.new().route(sim.geo, region, int(other), true).reachable:
				return true
	return false


static func _place_prefab(sim: RefCounted, s: Dictionary, kind: String, days: int) -> void:
	var building: Dictionary = sim._building(kind, days)
	building.plot = find_plot(sim, int(s.region), kind)
	s.buildings.append(building)


static func _expedition_cargo(
	sim: RefCounted, src: Dictionary, region: int, good: String, amount: float, days: int
) -> void:
	(
		sim
		. state
		. shipments
		. append(
			{
				"from": src.region,
				"to": region,
				"resource": good,
				"amount": amount,
				"remaining": days,
				"total_days": days,
				"expedition": true,
				"road": -1,
			}
		)
	)
