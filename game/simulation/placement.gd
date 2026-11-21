extends RefCounted
## Free placement (1.10): a settlement can be founded at any coordinate the player picks on the globe
## or the flat map, the capital and every later town alike. The ground there is read from the world
## (`site_gen.ground`) and judged against geography.json `placement`, with a specific reason when it
## is unsuitable. Founded, the point becomes a site of its own (`site_gen.site_at`) appended to
## `state.world.regions`, so its district, plots and deposits, roads, lights and saves all follow from
## the chosen point. Recommended sites stay as shortcuts. Plots on one planetary deposit share its
## reserve, in every town that reaches it (`share`).

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Routes = preload("res://world/routes.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Contract = preload("res://simulation/contract.gd")

## Stored coordinates keep four decimals of a degree (a few metres on any planet in the game).
const PRECISION: float = 10000.0
const SITE_CACHE_LIMIT: int = 64
const RESOURCES: Array[String] = ["ore", "copper", "crystal"]
const LEVEL_NAMES: Dictionary = {
	"signal": "轨道粗测",
	"scan": "轨道观测",
	"field": "实地勘察",
	"drilled": "钻探",
}

## The world part of `site_for` by point (it depends on the seed and the point alone).
static var _site_cache: Dictionary = {}


static func ensure_state(state: Dictionary) -> void:
	if not state.has("geology"):
		state.geology = {"remaining": {}}


static func rules(sim: RefCounted) -> Dictionary:
	return sim.progression_geo().placement


static func snap(value: float) -> float:
	return roundf(value * PRECISION) / PRECISION


## The ground at a coordinate and whether a settlement can be founded there now: the world's report
## (terrain, slope, water, coast, orbital signals, land slots), the nearest town and road in km, for a
## later town the departure town and the expedition's route, cost and days, and `refusal`, the reason
## it cannot be founded ("" when it can). Changes nothing.
static func view(
	sim: RefCounted, lat: float, lon: float, from: int = -1, kind: String = Keys.SITE_RESIDENTIAL
) -> Dictionary:
	lat = snap(clampf(lat, -89.99, 89.99))
	lon = snap(wrapf(lon, -180.0, 180.0))
	var report: Dictionary = SiteGen.ground(sim.geo, sim.progression_geo(), lat, lon)
	report.merge(_infrastructure(sim, lat, lon), true)
	report.first = sim.state.settlements.is_empty()
	report.kind = kind if not report.first else Keys.SITE_RESIDENTIAL
	report.from = -1
	report.route = {}
	report.cost = 0.0
	report.refusal = _ground_refusal(sim, report)
	if report.refusal == "" and not report.first:
		_expedition(sim, report, from)
	return report


## What makes the ground itself unsuitable, in the order a player would want to hear it.
static func _ground_refusal(sim: RefCounted, report: Dictionary) -> String:
	var rule: Dictionary = rules(sim)
	if not sim.state.status in ["planning", "active"]:
		return "本局已经结束，请读取存档或开始新局"
	if not bool(report.land):
		return "这里是海面，不能建立据点"
	if bool(report.get("lake_here", false)):
		return "这里是湖面，不能建立据点"
	if absf(float(report.lat)) > float(rule.max_latitude):
		return (
			"太靠近极地：纬度 %.1f°，据点最远建在纬度 %.0f° 以内" % [absf(float(report.lat)), float(rule.max_latitude)]
		)
	if float(report.relief) > float(rule.max_relief_m):
		return (
			"地势太陡：周围高差 %.0f m，超过 %.0f m 就平整不出城区和工地"
			% [float(report.relief), float(rule.max_relief_m)]
		)
	if int(report.slots) < int(rule.min_land_slots):
		return "可建设的陆地太少：周围只有 %d 块地，至少要 %d 块" % [int(report.slots), int(rule.min_land_slots)]
	var nearest: Dictionary = report.nearest_town
	if not nearest.is_empty() and float(nearest.degrees) < float(rule.min_separation_degrees):
		return (
			"离「%s」太近（%.0f km）：两处据点的地区会重叠，至少相隔 %.0f km"
			% [str(nearest.name), float(nearest.km), _km(sim, float(rule.min_separation_degrees))]
		)
	var capped: String = Contract.cap_refusal(sim)
	if capped != "":
		return capped
	if bool(report.first) and not _can_expand(sim, report):
		return "这里既没有陆路能到的其他地点，也不靠海，以后无法建立第二处据点"
	return ""


## The expedition to a point: the departure town (the one asked for, else the nearest that can go),
## the route it would travel, its cost and days, and the refusal when none can go.
static func _expedition(sim: RefCounted, report: Dictionary, from: int) -> void:
	var outpost: Dictionary = sim.config.outpost
	var choices: Array = []
	for s: Dictionary in sim.state.settlements:
		if int(s.arrival) > 0:
			continue
		if from >= 0 and int(s.region) != from:
			continue
		var route: Dictionary = _route(sim, int(s.region), float(report.lat), float(report.lon))
		choices.append({"town": s, "route": route})
	if choices.is_empty():
		report.refusal = "请选择出发据点" if from >= 0 else "没有可以派出远征队的据点"
		return
	choices.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a.route.reachable) != bool(b.route.reachable):
				return bool(a.route.reachable)
			return float(a.route.get("distance", INF)) < float(b.route.get("distance", INF))
	)
	var pick: Dictionary = choices[0]
	var src: Dictionary = pick.town
	report.from = int(src.region)
	report.from_name = str(src.name)
	report.route = pick.route
	if not bool(pick.route.reachable):
		report.refusal = str(pick.route.get("reason", "从%s没有陆路或航线能到这里" % str(src.name)))
		return
	var kind: String = str(report.kind)
	var fare: float = sim.Sites.expedition_cash(sim, kind)
	var kit: float = sim.Sites._kit_shortfall_cost(sim, src)
	report.cost = fare + kit
	report.kit_cost = kit
	report.workers = sim.Sites.expedition_workers(sim, kind)
	if int(src.workers) < int(outpost.min_source_workers):
		report.refusal = "出发据点职工不足 %d 名" % int(outpost.min_source_workers)
	elif kit > 0.0 and not Logistics._has_port(src):
		report.refusal = "出发据点缺远征物资，又没有货运站可以现买"
	elif float(sim.state.cash) < fare + kit:
		report.refusal = "派出远征队需要 %.0f 资金（含 %.0f 物资采购）" % [fare + kit, kit]


## The route an expedition from a town would take: a road where one can be built, else by sea from a
## working cargo dock.
static func _route(sim: RefCounted, from: int, lat: float, lon: float) -> Dictionary:
	var roads: Dictionary = sim.config.roads
	var road: Dictionary = Routes.find_to_point(sim.geo, from, lat, lon, "engineered", roads)
	if bool(road.reachable):
		return road
	var sea: Dictionary = Routes.find_to_point(sim.geo, from, lat, lon, "sea", roads)
	if not bool(sea.reachable):
		return road
	if not Logistics._has_port(sim.settlement(from)):
		sea.reachable = false
		sea.reason = "只能走海路，而出发据点没有运转的货运站"
	return sea


## The nearest town and the nearest finished road, in degrees and km.
static func _infrastructure(sim: RefCounted, lat: float, lon: float) -> Dictionary:
	var here: Vector3 = WorldGen.unit_point(lat, lon)
	var nearest: Dictionary = {}
	for s: Dictionary in sim.state.settlements:
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		var angle: float = here.angle_to(WorldGen.unit_point(float(reg.lat), float(reg.lon)))
		var degrees: float = rad_to_deg(angle)
		if nearest.is_empty() or degrees < float(nearest.degrees):
			nearest = {
				"region": int(s.region),
				"name": str(s.name),
				"degrees": degrees,
				"km": _km(sim, degrees),
			}
	var road_km: float = -1.0
	for road: Dictionary in sim.state.get("roads", []):
		if bool(road.get("retired", false)):
			continue
		for point: Array in road.get("coordinates", []):
			var degrees: float = rad_to_deg(
				here.angle_to(WorldGen.unit_point(float(point[0]), float(point[1])))
			)
			var km: float = _km(sim, degrees)
			if road_km < 0.0 or km < road_km:
				road_km = km
	return {"nearest_town": nearest, "nearest_road_km": road_km}


static func _km(sim: RefCounted, degrees: float) -> float:
	return deg_to_rad(degrees) * float(sim.geo.get("radius_km", 1000.0))


## A capital must be able to reach a second town: by sea from a coast, or overland on a landmass
## with room for another district.
static func _can_expand(sim: RefCounted, report: Dictionary) -> bool:
	if bool(report.coast) and bool(sim.progression_geo().validator.get("sea_partners", false)):
		return true
	var sizes: Array = sim.geo.get("landmass_sizes", [])
	var landmass: int = int(report.landmass)
	if landmass < 0 or landmass >= sizes.size():
		return false
	return int(sizes[landmass]) >= int(rules(sim).expansion_cells)


## Founds a settlement at a coordinate: the capital, or an expedition from a town. Judged as `view`
## judges it; the site is made only when the founding goes ahead.
static func settle_at(
	sim: RefCounted,
	lat: float,
	lon: float,
	from: int = -1,
	typed_name: String = "",
	kind: String = Keys.SITE_RESIDENTIAL
) -> String:
	ensure_state(sim.state)
	var report: Dictionary = view(sim, lat, lon, from, kind)
	if str(report.refusal) != "":
		return str(report.refusal)
	var regions: Array = sim.state.world.regions
	var id: int = regions.size()
	# The very site the card showed (`site_for`): the same plots, deposits and reserves.
	var site: Dictionary = site_for(sim, float(report.lat), float(report.lon)).duplicate(true)
	site.id = id
	site.name = SiteGen.site_number(id)
	for plot: Dictionary in site.plots:
		var shared: String = str(plot.get("deposit", ""))
		if shared != "" and not sim.state.geology.remaining.has(shared):
			sim.state.geology.remaining[shared] = float(plot.reserves)
	if bool(site.get("coast", false)):
		site.fishery = float(sim.Bay.fishery_at(sim, float(site.lat), float(site.lon)).factor)
	for other: Dictionary in regions:
		if int(other.get("landmass", -2)) == int(site.landmass):
			site.neighbors.append(int(other.id))
			other.neighbors.append(id)
	regions.append(site)
	var refusal: String = sim.Sites.settle(sim, id, int(report.from), typed_name, str(report.kind))
	if refusal != "":
		# Nothing may be left behind by a founding that did not happen.
		regions.pop_back()
		for other: Dictionary in regions:
			other.neighbors.erase(id)
		return refusal
	sim._log(
		"%s · 据点建在 北纬 %.2f°、东经 %.2f°（玩家选定的地面）。" % [str(site.name), float(site.lat), float(site.lon)]
	)
	return ""


## After a plot on a planetary deposit has been mined, every plot on that deposit, in every town,
## shows the reserve that is left, and each town's known totals follow.
static func share(sim: RefCounted, plot: Dictionary) -> void:
	var shared: String = str(plot.get("deposit", ""))
	if shared == "":
		return
	ensure_state(sim.state)
	var left: float = float(plot.reserves)
	sim.state.geology.remaining[shared] = left
	for reg: Dictionary in sim.state.world.regions:
		if not bool(reg.get("placed", false)):
			continue
		var touched: bool = false
		for other: Dictionary in reg.get("plots", []):
			if str(other.get("deposit", "")) == shared:
				other.reserves = left
				touched = true
		if touched:
			SiteGen.refresh_deposits(reg)


## A revision of a town's known reserves (an event): each visible deposit scaled once, a shared one
## for every town on it.
static func scale_reserves(sim: RefCounted, site: Dictionary, factor: float) -> void:
	var scaled: Dictionary = {}
	for plot: Dictionary in site.plots:
		if plot.kind != "deposit" or bool(plot.hidden):
			continue
		var shared: String = str(plot.get("deposit", ""))
		if shared != "" and scaled.has(shared):
			continue
		plot.reserves = float(plot.reserves) * factor
		if shared != "":
			scaled[shared] = true
			share(sim, plot)
	SiteGen.refresh_deposits(site)


## The site a town founded at this coordinate would get, as of today: `site_at` from the world (the
## same rules whether the point is a recommended site or not), with the reserve each shared deposit
## has left and the deposits a drill has seen made visible. Read-only; the world part is cached.
## settle_at founds exactly this site, so what the card showed is what the town finds.
## A recommended site as founding there would make it (1.11): the site its card shows at its
## coordinate (`site_for`). Markers, their filters and labels, and a bot's choice of start read this
## rather than the world generator's own draw for the site, so a marker never promises what founding
## at its point does not give. A town or a picked point is its own record.
static func marker_site(sim: RefCounted, reg: Dictionary) -> Dictionary:
	if bool(reg.get("placed", false)) or not sim.settlement(int(reg.get("id", -1))).is_empty():
		return reg
	return site_for(sim, float(reg.lat), float(reg.lon))


## What founding on a site is worth from what its card shows: the known deposits at their grades and
## prices, more with water, per unit of the site's building cost (the bots' choice of start).
static func site_score(sim: RefCounted, reg: Dictionary) -> float:
	var site: Dictionary = marker_site(sim, reg)
	var value: float = 0.0
	for good: String in RESOURCES:
		value += (
			float(site.get("deposits", {}).get(good, 0.0))
			* float(sim.config.prices[good])
			* float(site.get("grade", {}).get(good, 1.0))
		)
	value *= 0.7 + 0.6 * float(site.get("water", 0.5))
	return value / maxf(0.1, float(site.get("development_multiplier", 1.0)))


static func site_for(sim: RefCounted, lat: float, lon: float) -> Dictionary:
	lat = snap(clampf(lat, -89.99, 89.99))
	lon = snap(wrapf(lon, -180.0, 180.0))
	var key: String = (
		"%s|%s|%.4f|%.4f"
		% [str(sim.geo.get("seed", 0)), str(sim.geo.get("radius_km", 0)), lat, lon]
	)
	if not _site_cache.has(key):
		if _site_cache.size() > SITE_CACHE_LIMIT:
			_site_cache.clear()
		var id: int = sim.state.world.regions.size()
		_site_cache[key] = SiteGen.site_at(sim.geo, sim.progression_geo(), lat, lon, id)
	var site: Dictionary = _site_cache[key].duplicate(true)
	var remaining: Dictionary = sim.state.get("geology", {}).get("remaining", {})
	var drilled: Dictionary = sim.Prospecting.drilled_deposits(sim)
	for plot: Dictionary in site.plots:
		var shared: String = str(plot.get("deposit", ""))
		if shared == "":
			continue
		if remaining.has(shared):
			plot.reserves = float(remaining[shared])
		if drilled.has(shared):
			plot.hidden = false
	site.deep_known = sim._has("deep_mining")
	SiteGen.refresh_deposits(site)
	return site


## Everything the one site card shows about a coordinate (1.11), for the capital and every later
## town, recommended point or not: the ground (`view`: terrain, relief, water, coast, signals,
## eligibility, the expedition), and from the site a town would get here (`site_for`): buildable
## plots by type, each mineral's estimate with the band of the survey behind it, farmland and what
## a farm would grow, the fishery, what building here costs, and plans for what the first town here
## can sell first. Changes nothing.
static func preview(
	sim: RefCounted, lat: float, lon: float, from: int = -1, kind: String = Keys.SITE_RESIDENTIAL
) -> Dictionary:
	var report: Dictionary = view(sim, lat, lon, from, kind)
	if not bool(report.land) or bool(report.get("lake_here", false)) or int(report.slots) <= 0:
		return report
	var site: Dictionary = site_for(sim, float(report.lat), float(report.lon))
	report.has_site = true
	report.plots = _plot_counts(sim, site)
	report.minerals = _minerals(sim, site)
	report.farming = _farming(sim, site, str(report.kind))
	report.fishing = _fishing(sim, site)
	report.building = _building(sim, site)
	report.water_supply = _water(sim, site)
	report.plans = _plans(sim, report, site)
	return report


## Plots a town here would have, by type: general ground for the town, farmland, and deposits
## by resource (shallow ones, deep ones too once deep mining is known; hidden ones not at all).
static func _plot_counts(sim: RefCounted, site: Dictionary) -> Dictionary:
	var counts: Dictionary = {
		"general": 0, "farm": 0, "deposits": {"ore": 0, "copper": 0, "crystal": 0}, "deep": 0
	}
	var deep: bool = sim._has("deep_mining")
	for plot: Dictionary in site.plots:
		match str(plot.kind):
			"general":
				counts.general = int(counts.general) + 1
			"farm":
				counts.farm = int(counts.farm) + 1
			"deposit":
				if bool(plot.hidden):
					continue
				if int(plot.depth) > 0 and not deep:
					counts.deep = int(counts.deep) + 1
					continue
				counts.deposits[str(plot.resource)] = int(counts.deposits[str(plot.resource)]) + 1
	return counts


## Each mineral at this site: the true tonnage and plots a town would find (`site_for`), seen
## through the best survey of that resource covering the point: its band, the range shown (always
## holding the truth, off centre by a seeded amount), the free orbital signal's word, and for a
## scan that found nothing, `none_detected`.
static func _minerals(sim: RefCounted, site: Dictionary) -> Dictionary:
	var bands: Dictionary = rules(sim).get("estimate_bands", {})
	var signals: Dictionary = SiteGen.Geology.orbital_signals(
		sim.geo,
		float(site.lat),
		float(site.lon),
		SiteGen.signal_degrees(sim.geo, sim.progression_geo())
	)
	var counts: Dictionary = _plot_counts(sim, site)
	var result: Dictionary = {}
	var salt: int = 0
	for good: String in RESOURCES:
		salt += 1
		var ids: Dictionary = {}
		var grade_sum: float = 0.0
		var grade_count: int = 0
		for plot: Dictionary in site.plots:
			if str(plot.kind) != "deposit" or str(plot.resource) != good or bool(plot.hidden):
				continue
			if str(plot.get("deposit", "")) != "":
				ids[str(plot.deposit)] = true
			grade_sum += float(plot.grade)
			grade_count += 1
		var tonnes: float = float(site.deposits.get(good, 0.0))
		var plots: int = int(counts.deposits[good])
		var known: Dictionary = sim.Prospecting.knowledge(
			sim, good, float(site.lat), float(site.lon), ids
		)
		var level: String = str(known.level) if str(known.level) != "" else "signal"
		var band: float = float(bands.get(level, 0.6))
		var range: Dictionary = estimate(sim, site, tonnes, band, salt + 10 * _level_rank(level))
		var plot_low: int = plots
		var plot_high: int = plots
		if band > 0.0:
			plot_low = maxi(0, floori(plots * (1.0 - band)))
			plot_high = ceili(plots * (1.0 + band))
		var strength: float = float(signals.get(good, 0.0))
		result[good] = {
			"level": level,
			"band": band,
			"day": int(known.day),
			"low": float(range.low),
			"high": float(range.high),
			"mid": float(range.mid),
			"plots_low": plot_low,
			"plots_high": plot_high,
			"signal": strength,
			"signal_word": signal_word(strength),
			"none_detected": level == "scan" and tonnes <= 0.0,
			"grade": grade_sum / grade_count if grade_count > 0 else 0.0,
			"truth": {"tonnes": tonnes, "plots": plots},
		}
	return result


static func _level_rank(level: String) -> int:
	return {"signal": 0, "scan": 1, "field": 2, "drilled": 3}.get(level, 0)


## A free orbital reading in words (the ground card's mineral signals).
static func signal_word(strength: float) -> String:
	if strength >= 0.6:
		return "强"
	if strength >= 0.3:
		return "中"
	if strength > 0.05:
		return "弱"
	return "无"


## A true value seen through a band: a range `band` of the value wide on either side in all (2 x
## band x value), placed off centre by a fixed amount per point and salt so the truth is always
## inside but not in the middle; a closer survey visibly narrows towards it.
static func estimate(
	sim: RefCounted, site: Dictionary, value: float, band: float, salt: int
) -> Dictionary:
	if band <= 0.0 or value <= 0.0:
		return {"low": value, "high": value, "mid": value}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		(
			"%d|estimate|%.4f|%.4f|%d"
			% [int(sim.geo.get("seed", 0)), float(site.lat), float(site.lon), salt]
		)
	)
	var u: float = rng.randf_range(0.15, 0.85)
	var low: float = maxf(0.0, value * (1.0 - 2.0 * band * u))
	var high: float = value * (1.0 + 2.0 * band * (1.0 - u))
	return {"low": low, "high": high, "mid": (low + high) * 0.5}


## Farmland here: plots, their soil, what one greenhouse farm would grow a day on the best of them
## (a range by the soil band), and how many people that feeds.
static func _farming(sim: RefCounted, site: Dictionary, kind: String) -> Dictionary:
	var fertility: Array = []
	for plot: Dictionary in site.plots:
		if str(plot.kind) == "farm":
			fertility.append(float(plot.get("fertility", site.fertility)))
	fertility.sort()
	fertility.reverse()
	var climate: float = sim.Production.farm_climate_of(sim, site)
	var spec: Dictionary = sim.config.buildings.farm
	var frontier: float = 1.0
	if kind == Keys.SITE_FRONTIER:
		frontier += float(sim.config.site_rules.frontier_output)
	var bonus: float = 1.0 + sim.Research.bonus(sim, "farm_output")
	var outputs: Array = []
	for soil: float in fertility:
		outputs.append(float(spec.rate) * soil * climate * frontier * bonus)
	var band: float = float(rules(sim).get("estimate_bands", {}).get("soil", 0.15))
	var best: float = float(outputs[0]) if not outputs.is_empty() else 0.0
	var total: float = 0.0
	for value: float in outputs:
		total += value
	var range: Dictionary = estimate(sim, site, best, band, 41)
	return {
		"plots": fertility.size(),
		"fertility": float(fertility[0]) if not fertility.is_empty() else 0.0,
		"climate": climate,
		"per_farm": best,
		"per_farm_low": float(range.low),
		"per_farm_high": float(range.high),
		"all_farms": total,
		"feeds": floori(best / float(sim.config.economy.food_per_person)),
		"temperature": float(site.temperature),
		"word": _soil_word(best),
	}


static func _soil_word(per_farm: float) -> String:
	if per_farm >= 14.0:
		return "肥沃"
	if per_farm >= 8.0:
		return "中等"
	if per_farm > 0.0:
		return "贫瘠"
	return "没有农田"


## The sea off the point: the fishery factor and what a small harbour would land a day.
static func _fishing(sim: RefCounted, site: Dictionary) -> Dictionary:
	if not bool(site.get("coast", false)):
		return {"coast": false, "factor": 0.0, "catch": 0.0, "word": "内陆"}
	var reading: Dictionary = sim.Bay.fishery_at(sim, float(site.lat), float(site.lon))
	var fish: float = float(sim.config.buildings.harbor.get("fish", 0.0))
	return {
		"coast": true,
		"factor": float(reading.factor),
		"catch": fish * float(reading.factor),
		"word": sim.Bay.fishery_word(sim, float(reading.factor)),
		"shelf_share": float(reading.shelf_share),
		"sea_temperature": float(reading.sea_temperature),
		"river": bool(reading.river),
	}


## What building here costs against a plain site, and for each mineral the mine road its first
## mine would need: a mine takes the richest plot (Sites.find_plot), and beyond the haul reach its
## road is built with it (bay.gd).
static func _building(sim: RefCounted, site: Dictionary) -> Dictionary:
	var bay: Dictionary = sim.config.get("bay", {})
	var reach: float = float(bay.get("haul_reach", INF))
	var roads: Dictionary = {}
	var far: int = 0
	for good: String in RESOURCES:
		var best: Dictionary = {}
		for plot: Dictionary in site.plots:
			if str(plot.kind) != "deposit" or str(plot.resource) != good or bool(plot.hidden):
				continue
			if int(plot.depth) > 0 and not sim._has("deep_mining"):
				continue
			if best.is_empty() or float(plot.grade) > float(best.grade):
				best = plot
		if best.is_empty():
			continue
		var beyond: float = maxf(0.0, Vector2(float(best.x), float(best.z)).length() - reach)
		if beyond > 0.0:
			far += 1
		roads[good] = {
			"days": ceili(beyond * float(bay.get("haul_days_per_unit", 0.0))),
			"cost": beyond * float(bay.get("haul_cost_per_unit", 0.0)),
		}
	return {
		"cost_factor": float(site.get("development_multiplier", 1.0)),
		"ruggedness": float(site.get("ruggedness", 0.0)),
		"far_deposits": far,
		"roads": roads,
	}


## What one water pump would supply here: its capacity on this site's water (Production rules).
static func _water(sim: RefCounted, site: Dictionary) -> Dictionary:
	var spec: Dictionary = sim.config.buildings.water
	var supply: float = (
		float(spec.capacity) * (float(spec.site_floor) + float(site.water) * float(spec.site_gain))
	)
	return {"pump": supply, "water": float(site.water)}


## What the first town here can sell first: a plan per way of earning, best first. Each names the
## facilities it needs (up to two mines or farms, or one harbour, as the estimates allow, built one
## after the other by the town's first crew), what they cost and when each is working, a reasonable
## first shipment (when, how much, what it fetches), the daily earnings once all stand, and what
## that does for the charter's export goal of the current stage.
static func _plans(sim: RefCounted, report: Dictionary, _site: Dictionary) -> Array:
	var plans: Array = []
	var first: bool = bool(report.first)
	var cost_factor: float = float(report.building.cost_factor)
	var fee: float = float(sim.config.economy.port_fee)
	var goal: Dictionary = _export_goal(sim)
	var people: int = _people(sim, first, str(report.kind))
	var eaten: float = people * float(sim.config.economy.food_per_person)
	var port_here: bool = first or str(report.get("route", {}).get("variant", "")) == "sea"
	var frontier: float = 1.0
	if str(report.kind) == Keys.SITE_FRONTIER:
		frontier += float(sim.config.site_rules.frontier_output)
	for good: String in RESOURCES:
		var mineral: Dictionary = report.minerals[good]
		if float(mineral.mid) <= 0.0 or int(mineral.plots_high) <= 0:
			continue
		var kind: String = "mine_" + good
		var spec: Dictionary = sim.config.buildings[kind]
		var rate: float = (
			float(spec.rate)
			* maxf(0.5, float(mineral.grade))
			* sim.Production._good_bonus(sim, good)
			* frontier
		)
		var price: float = sim.Market.price(sim, good) * (1.0 - fee)
		var road: Dictionary = report.building.roads.get(good, {"days": 0, "cost": 0.0})
		var count: int = clampi(
			roundi((int(mineral.plots_low) + int(mineral.plots_high)) * 0.5), 1, 2
		)
		var steps: Array = []
		for index: int in range(count):
			var days: int = int(spec.days) + (int(road.days) if index == 0 else 0)
			(
				steps
				. append(
					{
						"kind": kind,
						"name": str(spec.name),
						"cost":
						float(spec.cost) * cost_factor + (float(road.cost) if index == 0 else 0.0),
						"days": days,
						"road_days": int(road.days) if index == 0 else 0,
						"rate": rate,
						"value": rate * price,
					}
				)
			)
		if not port_here:
			steps.push_front(_port_need(sim, cost_factor))
		var reserve: float = float(sim.config.economy.export_reserve.get(good, 0.0))
		var note: String = (
			"每座约 %s/天，按卖出价 ¥%.1f/百吨（市场越卖越便宜）；储量估计 %s–%s（%s）"
			% [
				_t(sim, rate),
				sim.Market.price(sim, good),
				_t(sim, float(mineral.low)),
				_t(sim, float(mineral.high)),
				LEVEL_NAMES.get(str(mineral.level), "")
			]
		)
		plans.append(
			_plan(
				"mine",
				good,
				"%s出口" % str(sim.config.resources.get(good, good)),
				steps,
				ceili(reserve / maxf(0.1, rate)),
				goal,
				note,
				str(mineral.level) == "signal"
			)
		)
	var farming: Dictionary = report.farming
	var food_rule: Dictionary = sim.config.get("supply", {}).get("food", {})
	if int(farming.plots) > 0 and not food_rule.is_empty():
		var spec: Dictionary = sim.config.buildings.farm
		var farms: int = mini(int(farming.plots), 2)
		var grown: float = float(farming.per_farm) * farms
		if grown >= float(food_rule.get("min_daily", 0.0)):
			var price: float = float(food_rule.price) * (1.0 - fee)
			var steps: Array = []
			if not port_here:
				steps.append(_port_need(sim, cost_factor))
			for index: int in range(farms):
				(
					steps
					. append(
						{
							"kind": "farm",
							"name": str(spec.name),
							"cost": float(spec.cost) * cost_factor,
							"days": int(spec.days),
							"rate": float(farming.per_farm),
							"value": float(farming.per_farm) * price,
						}
					)
				)
			var note: String = (
				"每座温室农场约 %s/天（%s，%s–%s）；%d 人每天吃 %s，%.0f 天口粮储备留在仓库、由货运站补足；合同价 ¥%.1f/百吨，首期 %s、%d 天，交齐后续签加量"
				% [
					_t(sim, float(farming.per_farm)),
					str(farming.word),
					_t(sim, float(farming.per_farm_low)),
					_t(sim, float(farming.per_farm_high)),
					people,
					_t(sim, eaten),
					float(sim.state.policy.food_reserve) + 1.0,
					float(food_rule.price),
					_t(sim, float(food_rule.first_size)),
					int(food_rule.days)
				]
			)
			plans.append(_plan("food", "food", str(food_rule.name), steps, 0, goal, note, false))
	var fishing: Dictionary = report.fishing
	var catch_rule: Dictionary = sim.config.get("supply", {}).get("catch", {})
	if (
		bool(fishing.coast)
		and not catch_rule.is_empty()
		and float(fishing.catch) >= float(catch_rule.get("min_daily", 0.0))
	):
		var spec: Dictionary = sim.config.buildings.harbor
		var price: float = float(catch_rule.price) * (1.0 - fee)
		var steps: Array = [
			{
				"kind": "harbor",
				"name": str(spec.name),
				"cost": float(spec.cost) * cost_factor,
				"days": int(spec.days),
				"rate": float(fishing.catch),
				"value": float(fishing.catch) * price,
			}
		]
		var note: String = (
			"渔场%s：一座小型码头每天约 %s；合同价 ¥%.1f/百吨，首期 %s、%d 天；码头还能走海运，进口便宜 %.0f%%"
			% [
				str(fishing.word),
				_t(sim, float(fishing.catch)),
				float(catch_rule.price),
				_t(sim, float(catch_rule.first_size)),
				int(catch_rule.days),
				float(sim.config.bay.sea_discount) * 100.0
			]
		)
		plans.append(_plan("catch", "food", str(catch_rule.name), steps, 0, goal, note, false))
	plans.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a.goal_day) < int(b.goal_day)
	)
	if not plans.is_empty():
		plans[0].best = true
	return plans


static func _t(sim: RefCounted, units: float) -> String:
	var tonnes: float = sim.tonnes(units)
	if tonnes >= 10000.0:
		return "%.1f 万 t" % (tonnes / 10000.0)
	return "%.0f t" % tonnes


static func _port_need(sim: RefCounted, cost_factor: float) -> Dictionary:
	var spec: Dictionary = sim.config.buildings.port
	return {
		"kind": "port",
		"name": str(spec.name),
		"cost": float(spec.cost) * cost_factor,
		"days": int(spec.days)
	}


## The people a town founded here starts with: the landing party, or an expedition.
static func _people(sim: RefCounted, first: bool, kind: String) -> int:
	if first:
		var opening: Dictionary = sim.config.openings[sim.state.advantage]
		return int(opening.workers) + int(opening.scientists) + int(opening.children)
	return sim.Sites.expedition_workers(sim, kind)


## The current stage's export goal: {target, value, left, deadline}; empty when the stage has none.
static func _export_goal(sim: RefCounted) -> Dictionary:
	var stage: int = int(sim.state.get("contract", {}).get("stage", 1))
	if stage > Contract.STAGE_COUNT:
		return {}
	var goals: Dictionary = sim.contract_rules.stages[stage - 1].goals
	if not goals.has("exports_total"):
		return {}
	var target: float = Contract.goal_target(sim, stage, "exports_total")
	var value: float = float(sim.state.get("exports_total", 0.0))
	return {
		"stage": stage,
		"target": target,
		"value": value,
		"left": maxf(0.0, target - value),
		"deadline": Contract.deadline(sim, stage),
	}


## A plan from its steps, built one after the other by the town's first crew from day 1: the first
## shipment the day after the first earning facility works (plus `lag` days to fill its export
## reserve), the daily earnings once all stand, and the day the stage's export goal would be met.
static func _plan(
	key: String,
	good: String,
	title: String,
	steps: Array,
	lag: int,
	goal: Dictionary,
	note: String,
	uncertain: bool
) -> Dictionary:
	var cost: float = 0.0
	var day: int = 0
	var first_day: int = -1
	var first_amount: float = 0.0
	var timeline: Array = []
	for step: Dictionary in steps:
		cost += float(step.cost)
		day += int(step.days)
		step.ready_day = day
		if float(step.get("value", 0.0)) > 0.0:
			timeline.append([day + 1 + lag, float(step.value)])
			if first_day < 0:
				first_day = day + 1 + lag
				first_amount = float(step.rate)
	var per_day: float = 0.0
	for entry: Array in timeline:
		per_day += float(entry[1])
	var plan: Dictionary = {
		"key": key,
		"good": good,
		"title": title,
		"needs": steps,
		"cost": cost,
		"first_day": first_day,
		"first_amount": first_amount,
		"per_day": per_day,
		"note": note,
		"uncertain": uncertain,
		"best": false,
		"goal_day": 1 << 20,
	}
	if goal.is_empty() or per_day <= 0.0:
		return plan
	# Day by day: what is earned as each facility comes in, until the goal's remainder is covered.
	var earned: float = 0.0
	var at: int = first_day
	while earned < float(goal.left) and at < first_day + 20000:
		for entry: Array in timeline:
			if at >= int(entry[0]):
				earned += float(entry[1])
		at += 1
	plan.goal = goal
	plan.goal_day = at
	plan.goal_days = at - first_day
	plan.late = at > int(goal.deadline)
	return plan
