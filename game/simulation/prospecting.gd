extends RefCounted
## Prospecting one resource at a time (1.10, the November 20 brief), on the planet's own deposits
## (geology.gd), anywhere a player looks:
## - an orbital observation of a resource at a point shows each deposit of it that orbit can see
##   within the reading's reach as a broad anomaly: a zone drawn on the maps, its centre up to
##   `offset_degrees` off the deposit's;
## - a field survey, sent from a town within reach, narrows one anomaly to a small zone close to
##   the deposit: enough to choose where to found a town;
## - drilling, once the field survey is in, establishes the deposit's grade, depth and the reserve
##   left, and shows its plots in every town that reaches it.
## Numbers in geography.json `prospecting`. State: `state.prospecting` {anomalies, jobs, next_id}.

const Geology = preload("res://world/geo2/geology.gd")
const WorldGen = preload("res://world/world_gen.gd")

const STAGES: Array[String] = ["orbital", "field", "drilled"]
const NAMES: Dictionary = {"ore": "铁矿", "copper": "铜矿", "crystal": "工业晶体"}


static func ensure_state(state: Dictionary) -> void:
	if not state.has("prospecting"):
		state.prospecting = {"anomalies": [], "jobs": [], "next_id": 1}
	# 1.11: each orbital observation is kept, with what it found, so the site card can say that a
	# scan saw nothing of a resource at a point.
	if not state.prospecting.has("scans"):
		state.prospecting.scans = []


static func rules(sim: RefCounted) -> Dictionary:
	return sim.progression_geo().prospecting


static func _degrees(sim: RefCounted, km: float) -> float:
	return km / maxf(1.0, deg_to_rad(1.0) * float(sim.geo.get("radius_km", 6371.0)))


static func _km(sim: RefCounted, degrees: float) -> float:
	return deg_to_rad(degrees) * float(sim.geo.get("radius_km", 6371.0))


## The anomalies whose zone covers a point, nearest centre first.
static func anomalies_at(sim: RefCounted, lat: float, lon: float) -> Array:
	ensure_state(sim.state)
	var here: Vector3 = WorldGen.unit_point(lat, lon)
	var found: Array = []
	for anomaly: Dictionary in sim.state.prospecting.anomalies:
		var centre: Vector3 = WorldGen.unit_point(float(anomaly.lat), float(anomaly.lon))
		var gap: float = rad_to_deg(here.angle_to(centre))
		if gap <= float(anomaly.zone):
			found.append({"anomaly": anomaly, "degrees": gap})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.degrees < b.degrees)
	return found.map(func(entry: Dictionary) -> Dictionary: return entry.anomaly)


static func anomaly(sim: RefCounted, id: int) -> Dictionary:
	ensure_state(sim.state)
	for entry: Dictionary in sim.state.prospecting.anomalies:
		if int(entry.id) == id:
			return entry
	return {}


static func _busy(sim: RefCounted, key: String) -> bool:
	for job: Dictionary in sim.state.prospecting.jobs:
		if str(job.key) == key:
			return true
	return false


## The nearest town to a point, by a great-circle distance in km: {town, km}; empty with no town.
static func _nearest_town(sim: RefCounted, lat: float, lon: float) -> Dictionary:
	var here: Vector3 = WorldGen.unit_point(lat, lon)
	var best: Dictionary = {}
	for s: Dictionary in sim.state.settlements:
		if int(s.get("arrival", 0)) > 0:
			continue
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		var km: float = _km(
			sim, rad_to_deg(here.angle_to(WorldGen.unit_point(float(reg.lat), float(reg.lon))))
		)
		if best.is_empty() or km < float(best.km):
			best = {"town": s, "km": km}
	return best


## What a step would cost and why it cannot go now: {cost, days, refusal}.
static func quote(sim: RefCounted, step: String, lat: float, lon: float, id: int = 0) -> Dictionary:
	ensure_state(sim.state)
	var rule: Dictionary = rules(sim)[step]
	var result: Dictionary = {"cost": float(rule.cost), "days": int(rule.days), "refusal": ""}
	if sim.state.settlements.is_empty():
		result.refusal = "先建立首府，才有人去观测和勘察"
	elif float(sim.state.cash) < float(rule.cost):
		result.refusal = "需要 %.0f 资金" % float(rule.cost)
	elif step != "orbital":
		var target: Dictionary = anomaly(sim, id)
		var wanted: String = "orbital" if step == "field" else "field"
		var town: Dictionary = _nearest_town(
			sim, float(target.get("lat", lat)), float(target.get("lon", lon))
		)
		if target.is_empty() or str(target.stage) != wanted:
			result.refusal = "先完成%s" % ("轨道观测" if step == "field" else "实地勘察")
		elif _busy(sim, "%s:%d" % [step, id]):
			result.refusal = "队伍已经出发"
		elif town.is_empty() or float(town.km) > float(rule.reach_km):
			result.refusal = (
				"最近的据点也远在 %.0f km 外，队伍最远走 %.0f km"
				% [float(town.get("km", INF)), float(rule.reach_km)]
			)
		else:
			result.from = str(town.town.name)
	return result


## An orbital observation of `resource` at a point: reported after its days.
static func observe(sim: RefCounted, resource: String, lat: float, lon: float) -> String:
	if not resource in NAMES:
		return "未知资源"
	var q: Dictionary = quote(sim, "orbital", lat, lon)
	if str(q.refusal) != "":
		return str(q.refusal)
	sim._transfer("public", "external", float(q.cost), "invest.survey", false, "orbital")
	(
		sim
		. state
		. prospecting
		. jobs
		. append(
			{
				"key": "orbital:%s:%.2f:%.2f" % [resource, lat, lon],
				"step": "orbital",
				"resource": resource,
				"lat": lat,
				"lon": lon,
				"until": int(sim.state.day) + int(q.days),
			}
		)
	)
	sim._log("轨道观测：%s 异常，北纬 %.1f°、东经 %.1f° 一带，%d 天后出结果。" % [NAMES[resource], lat, lon, int(q.days)])
	return ""


## A field survey (`field`) or drilling (`drill`) of one anomaly.
static func send(sim: RefCounted, step: String, id: int) -> String:
	if not step in ["field", "drill"]:
		return "未知勘探步骤"
	var target: Dictionary = anomaly(sim, id)
	if target.is_empty():
		return "没有这个异常区"
	var q: Dictionary = quote(sim, step, float(target.lat), float(target.lon), id)
	if str(q.refusal) != "":
		return str(q.refusal)
	sim._transfer("public", "external", float(q.cost), "invest.survey", false, step)
	sim.state.prospecting.jobs.append(
		{
			"key": "%s:%d" % [step, id],
			"step": step,
			"id": id,
			"until": int(sim.state.day) + int(q.days)
		}
	)
	sim._log(
		(
			"%s：从%s出发，%d 天后回报。"
			% ["实地勘察队" if step == "field" else "钻探队", str(q.get("from", "")), int(q.days)]
		)
	)
	return ""


static func daily(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var keep: Array = []
	for job: Dictionary in sim.state.prospecting.jobs:
		if int(sim.state.day) < int(job.until):
			keep.append(job)
			continue
		match str(job.step):
			"orbital":
				_report_orbit(sim, str(job.resource), float(job.lat), float(job.lon))
			"field":
				_report_field(sim, anomaly(sim, int(job.id)))
			"drill":
				_report_drill(sim, anomaly(sim, int(job.id)))
	sim.state.prospecting.jobs = keep


## The deposits of a resource orbit can see within the reading's reach become anomalies, each
## drawn off its true centre by a seeded amount (one deposit, one anomaly).
static func _report_orbit(sim: RefCounted, resource: String, lat: float, lon: float) -> void:
	var rule: Dictionary = rules(sim).orbital
	var reach: float = _degrees(sim, float(rule.reach_km))
	var known: Dictionary = {}
	for entry: Dictionary in sim.state.prospecting.anomalies:
		known[str(entry.deposit)] = true
	var found: int = 0
	for hit: Dictionary in Geology.reaching(sim.geo, lat, lon, reach):
		var deposit: Dictionary = hit.deposit
		if str(deposit.resource) != resource or bool(deposit.hidden) or known.has(str(deposit.id)):
			continue
		known[str(deposit.id)] = true
		var at: Vector2 = _drawn_centre(sim, deposit, float(rule.offset_degrees), "orbital")
		(
			sim
			. state
			. prospecting
			. anomalies
			. append(
				{
					"id": int(sim.state.prospecting.next_id),
					"deposit": str(deposit.id),
					"resource": resource,
					"lat": at.x,
					"lon": at.y,
					"zone": float(rule.zone_degrees),
					"stage": "orbital",
					"day": int(sim.state.day),
				}
			)
		)
		sim.state.prospecting.next_id = int(sim.state.prospecting.next_id) + 1
		found += 1
	(
		sim
		. state
		. prospecting
		. scans
		. append(
			{
				"resource": resource,
				"lat": lat,
				"lon": lon,
				"reach": reach,
				"day": int(sim.state.day),
				"found": found,
			}
		)
	)
	sim._log(
		(
			(
				"轨道观测结果：%s 异常 %d 处（地图上的大圈，每处约 ±%.0f km）。"
				% [NAMES[resource], found, _km(sim, float(rule.zone_degrees))]
			)
			if found > 0
			else (
				"轨道观测结果：本次观测未探测到%s（北纬 %.1f°、东经 %.1f° 周围 %.0f km）。"
				% [NAMES[resource], lat, lon, float(rule.reach_km)]
			)
		)
	)


static func _report_field(sim: RefCounted, target: Dictionary) -> void:
	if target.is_empty():
		return
	var rule: Dictionary = rules(sim).field
	var deposit: Dictionary = _deposit(sim, str(target.deposit))
	var at: Vector2 = _drawn_centre(sim, deposit, float(rule.offset_degrees), "field")
	target.lat = at.x
	target.lon = at.y
	target.zone = float(rule.zone_degrees)
	target.stage = "field"
	target.kind = str(deposit.kind)
	(
		sim
		. _log(
			(
				"实地勘察完成：%s 矿体在北纬 %.2f°、东经 %.2f° 附近（约 ±%.0f km），是一条%s。"
				% [
					NAMES[str(target.resource)],
					at.x,
					at.y,
					_km(sim, float(rule.zone_degrees)),
					"矿脉" if str(deposit.kind) == "vein" else "矿囊",
				]
			)
		)
	)


static func _report_drill(sim: RefCounted, target: Dictionary) -> void:
	if target.is_empty():
		return
	var deposit: Dictionary = _deposit(sim, str(target.deposit))
	var left: float = float(
		sim.state.get("geology", {}).get("remaining", {}).get(str(deposit.id), deposit.reserve)
	)
	target.stage = "drilled"
	target.grade = float(deposit.grade)
	target.depth = int(deposit.depth)
	target.reserve = left
	# Its plots show in every town that reaches it, deep ones too: the drill has seen them.
	for reg: Dictionary in sim.state.world.regions:
		var touched: bool = false
		for plot: Dictionary in reg.get("plots", []):
			if str(plot.get("deposit", "")) == str(deposit.id):
				plot.hidden = false
				touched = true
		if touched:
			sim.Sites.SiteGen.refresh_deposits(reg)
	(
		sim
		. _log(
			(
				"钻探结果：%s 品位 %.2f，%s，剩余储量约 %.0f t。"
				% [
					NAMES[str(target.resource)],
					float(deposit.grade),
					"浅层，轻型矿场就能开采" if int(deposit.depth) == 0 else "深层，要深层采矿技术",
					sim.tonnes(left),
				]
			)
		)
	)


## What the colony's prospecting knows of one resource at a point, for the site card: the best of a
## drilled or field-surveyed anomaly on a deposit the site reaches (`deposits`, its plots' deposit
## ids), and the latest orbital scan of that resource whose reach covers the point. {level:
## "drilled" | "field" | "scan" | "", day, found (the scan's anomaly count)}.
static func knowledge(
	sim: RefCounted, resource: String, lat: float, lon: float, deposits: Dictionary
) -> Dictionary:
	ensure_state(sim.state)
	var best: Dictionary = {"level": "", "day": -1, "found": -1}
	for entry: Dictionary in sim.state.prospecting.anomalies:
		if str(entry.resource) != resource or not deposits.has(str(entry.deposit)):
			continue
		var stage: String = str(entry.stage)
		if stage == "drilled":
			return {"level": "drilled", "day": int(entry.get("day", -1)), "found": 1}
		if stage == "field":
			best = {"level": "field", "day": int(entry.get("day", -1)), "found": 1}
	if str(best.level) != "":
		return best
	var here: Vector3 = WorldGen.unit_point(lat, lon)
	for scan: Dictionary in sim.state.prospecting.get("scans", []):
		if str(scan.resource) != resource:
			continue
		var centre: Vector3 = WorldGen.unit_point(float(scan.lat), float(scan.lon))
		if rad_to_deg(here.angle_to(centre)) > float(scan.reach):
			continue
		if int(scan.day) >= int(best.day):
			best = {"level": "scan", "day": int(scan.day), "found": int(scan.found)}
	return best


## Deposits a drill has seen are visible in every town that reaches them, a town founded later too.
static func drilled_deposits(sim: RefCounted) -> Dictionary:
	ensure_state(sim.state)
	var seen: Dictionary = {}
	for entry: Dictionary in sim.state.prospecting.anomalies:
		if str(entry.stage) == "drilled":
			seen[str(entry.deposit)] = true
	return seen


static func _deposit(sim: RefCounted, id: String) -> Dictionary:
	for deposit: Dictionary in Geology.deposits(sim.geo):
		if str(deposit.id) == id:
			return deposit
	return {}


## Where an anomaly is drawn: the deposit's centre moved by a fixed, seeded amount up to `offset`.
static func _drawn_centre(
	sim: RefCounted, deposit: Dictionary, offset: float, stage: String
) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|prospect|%s|%s" % [int(sim.geo.seed), str(deposit.id), stage])
	var angle: float = rng.randf() * TAU
	var reach: float = rng.randf() * offset
	var lat: float = clampf(float(deposit.lat) + sin(angle) * reach, -89.0, 89.0)
	var lon: float = wrapf(
		float(deposit.lon) + cos(angle) * reach / maxf(0.2, cos(deg_to_rad(lat))), -180.0, 180.0
	)
	return Vector2(lat, lon)


static func audit(state: Dictionary) -> Array:
	var errors: Array = []
	for entry: Dictionary in state.get("prospecting", {}).get("anomalies", []):
		if not str(entry.get("stage", "")) in STAGES:
			errors.append("prospecting anomaly in an unknown stage")
	return errors
