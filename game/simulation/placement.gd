extends RefCounted
## Free placement (1.10): a settlement can be founded at any coordinate the player picks on the globe
## or the flat map, the capital and every later town alike. The ground there is read from the world
## (`site_gen.ground`) and judged against geography.json `placement`, with a specific reason when it
## is unsuitable. Founded, the point becomes a site of its own (`site_gen.site_at`) appended to
## `state.world.regions`, so its district, plots and deposits, roads, lights and saves all follow from
## the chosen point. Recommended sites stay as shortcuts. Plots on one planetary deposit share its
## reserve, in every town that reaches it (`share`).

const Origins = preload("res://simulation/origins.gd")
const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const Routes = preload("res://world/routes.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Contract = preload("res://simulation/contract.gd")

## Stored coordinates keep four decimals of a degree (a few metres on any planet in the game).
const PRECISION: float = 10000.0
const RESOURCES: Array[String] = ["ore", "copper", "crystal", "nickel", "cobalt"]


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
	if sim.state.settlements.size() >= Contract.settlement_cap(sim):
		return "需要先完成合同阶段，取得下一处据点的远征许可"
	var contract: String = Origins.founding_refusal(sim, bool(report.get("coast", false)))
	if bool(report.first) and contract != "":
		return contract
	if bool(report.first) and not can_expand(sim, report):
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
## with room for another district. `ground` is a ground report or a site placed at a coordinate
## (both carry `coast` and `landmass`); the founding judges a placed site by this same rule.
static func can_expand(sim: RefCounted, ground: Dictionary) -> bool:
	if bool(ground.coast) and bool(sim.progression_geo().validator.get("sea_partners", false)):
		return true
	var sizes: Array = sim.geo.get("landmass_sizes", [])
	var landmass: int = int(ground.landmass)
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
	var site: Dictionary = SiteGen.site_at(
		sim.geo, sim.progression_geo(), float(report.lat), float(report.lon), id
	)
	for plot: Dictionary in site.plots:
		var shared: String = str(plot.get("deposit", ""))
		if shared == "":
			continue
		if sim.state.geology.remaining.has(shared):
			plot.reserves = float(sim.state.geology.remaining[shared])
		else:
			sim.state.geology.remaining[shared] = float(plot.reserves)
	SiteGen.refresh_deposits(site)
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
