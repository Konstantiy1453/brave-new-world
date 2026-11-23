extends RefCounted
## Weather that matters (1.11 F). Weather systems are born from the seed and the day and move once a
## day in Sim.tick(): cyclones over warm ocean, dust over dry interiors, cold waves in cold
## climates, heavy rain over river basins, fog on coasts (geography.json `weather`). State holds the
## active systems; the views draw them from it.
## - A system heading for a settlement within its warning days raises a warning (logged, a notice
##   and a map marker). A weather station within range doubles the warning days, the forecasting
##   technology adds more. The player can pay to prepare a warned town, which cuts its losses.
## - A system reaching a settlement opens that kind's story (EventsV2.trigger); those stories leave
##   the random draw while weather is on.
## - Force majeure: within `claim_days` of a disaster, a claim is accepted when a station covered
##   the town or the warning was logged. It moves the current stage's deadline by the disaster's
##   days and waives that year's miss on the report line the disaster hit.
## Same seed and day give the same weather at any game speed: every roll is seeded by seed, day and
## kind, never by frame or clock.

const Rules = preload("res://simulation/rules.gd")
const Features = preload("res://simulation/features.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const PREPARE: String = "weather.prepare"


static func rules() -> Dictionary:
	return Rules.read("geography").get("weather", {})


static func on() -> bool:
	return Features.on("weather")


## Whether weather runs in this game: the feature is on and the world has the climate grid the
## zones are read from. Worlds from before the grid (1.6 and 1.7 saves) keep the cosmetic storms
## and their weather stories in the random draw.
static func active(sim: RefCounted) -> bool:
	return on() and sim.geo.has("grid_width")


## The stories the weather opens, which leave the random draw while it is on.
static func stories() -> Array:
	var ids: Array = []
	for kind: Dictionary in rules().get("kinds", {}).values():
		ids.append(str(kind.event))
	return ids


static func ensure_state(state: Dictionary) -> void:
	if not state.has("weather"):
		state.weather = {"systems": [], "next_id": 1, "strikes": [], "claims": [], "lost": {}}
	if not state.weather.has("lost"):
		state.weather.lost = {}


## Degrees of arc between two points.
static func arc(lat_a: float, lon_a: float, lat_b: float, lon_b: float) -> float:
	var a: float = deg_to_rad(lat_a)
	var b: float = deg_to_rad(lat_b)
	var d_lat: float = b - a
	var d_lon: float = deg_to_rad(wrapf(lon_b - lon_a, -180.0, 180.0))
	var h: float = sin(d_lat / 2.0) ** 2 + cos(a) * cos(b) * sin(d_lon / 2.0) ** 2
	return rad_to_deg(2.0 * asin(sqrt(clampf(h, 0.0, 1.0))))


## Where a system is `days` from now along its heading.
static func ahead(system: Dictionary, days: float) -> Vector2:
	var heading: float = deg_to_rad(float(system.heading))
	var step: float = float(system.speed) * days
	var lat: float = clampf(float(system.lat) + cos(heading) * step, -85.0, 85.0)
	var spread: float = maxf(0.2, cos(deg_to_rad(lat)))
	var lon: float = wrapf(float(system.lon) + sin(heading) * step / spread, -180.0, 180.0)
	return Vector2(lat, lon)


static func town_point(sim: RefCounted, s: Dictionary) -> Vector2:
	var reg: Dictionary = sim.state.world.regions[int(s.region)]
	return Vector2(float(s.get("lat", reg.lat)), float(s.get("lon", reg.lon)))


## Each day: new systems, every system a day further, warnings, strikes, and old ones gone.
static func daily(sim: RefCounted) -> void:
	ensure_state(sim.state)
	if not active(sim) or sim.state.settlements.is_empty():
		return
	var w: Dictionary = sim.state.weather
	for kind: String in rules().get("kinds", {}):
		_genesis(sim, kind)
	var kept: Array = []
	for system: Dictionary in w.systems:
		var next: Vector2 = ahead(system, 1.0)
		system.lat = next.x
		system.lon = next.y
		system.age = int(system.age) + 1
		_warn(sim, system)
		_strike(sim, system)
		if int(system.age) < int(system.life):
			kept.append(system)
	w.systems = kept


## A new system of `kind` may be born today, from the seed, the day and the kind alone.
static func _genesis(sim: RefCounted, kind: String) -> void:
	var rule: Dictionary = rules().kinds[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:weather:%d:%s" % [str(sim.state.world.seed), int(sim.state.day), kind])
	if rng.randf() >= float(rule.chance):
		return
	var zone: Dictionary = rule.zone
	for _try: int in range(int(rules().get("genesis_tries", 24))):
		var lat: float = rng.randf_range(-float(zone.lat_max), float(zone.lat_max))
		var lon: float = rng.randf_range(-180.0, 180.0)
		if absf(lat) < float(zone.get("lat_min", 0.0)):
			continue
		var cell: Dictionary = sim.geo.grid[SiteGen.cell_at(sim.geo, lat, lon)]
		if not _fits(cell, zone):
			continue
		var w: Dictionary = sim.state.weather
		var heading: float = float(rule.heading) + rng.randf_range(-1.0, 1.0) * float(rule.spread)
		if str(rule.get("poleward", "")) == "toward" and lat < 0.0:
			heading = 180.0 - heading
		elif str(rule.get("poleward", "")) == "away" and lat < 0.0:
			heading = 180.0 - heading
		(
			w
			. systems
			. append(
				{
					"id": int(w.next_id),
					"kind": kind,
					"lat": lat,
					"lon": lon,
					"born": [lat, lon],
					"heading": fposmod(heading, 360.0),
					"speed": rng.randf_range(float(rule.speed[0]), float(rule.speed[1])),
					"radius": rng.randf_range(float(rule.radius[0]), float(rule.radius[1])),
					"age": 0,
					"life": rng.randi_range(int(rule.life[0]), int(rule.life[1])),
					"warned": {},
					"struck": {},
					"prepared": {},
				}
			)
		)
		w.next_id = int(w.next_id) + 1
		return


static func _fits(cell: Dictionary, zone: Dictionary) -> bool:
	var land: bool = bool(cell.get("land", false))
	match str(zone.surface):
		"ocean":
			if land:
				return false
		"land":
			if not land:
				return false
		"coast":
			if not (land and bool(cell.get("coast", false))):
				return false
	if float(cell.get("temperature", 0.0)) < float(zone.get("min_temperature", -999.0)):
		return false
	if float(cell.get("temperature", 0.0)) > float(zone.get("max_temperature", 999.0)):
		return false
	if float(cell.get("risk_arid", 0.0)) < float(zone.get("min_arid", 0.0)):
		return false
	if float(cell.get("risk_flood", 0.0)) < float(zone.get("min_flood", 0.0)):
		return false
	if bool(zone.get("inland", false)) and bool(cell.get("coast", false)):
		return false
	return true


## The warning days a town gets: the base, doubled under a weather station, more with the
## forecasting technology.
static func warning_days(sim: RefCounted, s: Dictionary) -> int:
	var days: float = float(rules().get("warning_days", 3))
	if covered(sim, s):
		days *= 2.0
	days += sim.Research.bonus(sim, "weather_warning")
	return int(round(days))


## Whether a weather station stands within its range of the town.
static func covered(sim: RefCounted, s: Dictionary) -> bool:
	var reach: float = float(rules().get("station_range_degrees", 0.0))
	var here: Vector2 = town_point(sim, s)
	for other: Dictionary in sim.state.settlements:
		for b: Dictionary in other.buildings:
			if str(b.kind) != "weather_station" or int(b.remaining) > 0:
				continue
			if not bool(b.get("enabled", true)):
				continue
			var there: Vector2 = town_point(sim, other)
			if arc(here.x, here.y, there.x, there.y) <= reach:
				return true
	return false


static func _warn(sim: RefCounted, system: Dictionary) -> void:
	for s: Dictionary in sim.state.settlements:
		var key: String = str(s.region)
		if system.warned.has(key) or system.struck.has(key) or int(s.arrival) > 0:
			continue
		var here: Vector2 = town_point(sim, s)
		var days: int = warning_days(sim, s)
		for step: int in range(1, days + 1):
			var at: Vector2 = ahead(system, float(step))
			if arc(at.x, at.y, here.x, here.y) <= float(system.radius):
				system.warned[key] = int(sim.state.day)
				sim._log(
					(
						"气象预警：%s预计 %d 日内影响%s。"
						% [str(rules().kinds[system.kind].name), step, str(s.name)]
					)
				)
				break


static func _strike(sim: RefCounted, system: Dictionary) -> void:
	for s: Dictionary in sim.state.settlements:
		var key: String = str(s.region)
		if system.struck.has(key) or int(s.arrival) > 0:
			continue
		var here: Vector2 = town_point(sim, s)
		if arc(float(system.lat), float(system.lon), here.x, here.y) > float(system.radius):
			continue
		system.struck[key] = int(sim.state.day)
		var rule: Dictionary = rules().kinds[system.kind]
		(
			sim
			. state
			. weather
			. strikes
			. append(
				{
					"system": int(system.id),
					"kind": str(system.kind),
					"region": int(s.region),
					"day": int(sim.state.day),
					"warned": system.warned.has(key),
					"covered": covered(sim, s),
					"prepared": system.prepared.has(key),
					"losses": {},
				}
			)
		)
		while sim.state.weather.strikes.size() > int(rules().get("strikes_kept", 40)):
			sim.state.weather.strikes.pop_front()
		sim._log("%s抵达%s。" % [str(rule.name), str(s.name)])
		sim.EventsV2.trigger(sim, str(rule.event), int(s.region))


## Pays to prepare a warned town for a system on its way: what it loses when it comes is cut.
static func prepare(sim: RefCounted, system_id: int, region: int) -> String:
	ensure_state(sim.state)
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return "请选择据点"
	for system: Dictionary in sim.state.weather.systems:
		if int(system.id) != system_id:
			continue
		if not system.warned.has(str(region)) or system.struck.has(str(region)):
			return "只能为已发预警、尚未抵达的天气做准备"
		if system.prepared.has(str(region)):
			return "已经做好准备"
		var cost: float = prepare_cost(sim)
		if float(sim.state.cash) < cost:
			return "防灾准备需要 ¥%.0f" % cost
		sim._public_expense(cost, PREPARE, "external")
		system.prepared[str(region)] = int(sim.state.day)
		sim._log("%s做好了防灾准备。" % str(s.name))
		return ""
	return "没有这个天气系统"


static func prepare_cost(sim: RefCounted) -> float:
	return float(rules().get("prepare_cost", 0.0)) * sim.EventsV2.money_scale(sim)


## What a town keeps of what an event takes: the planetary emergency network's cut (1.9), then
## the weather's (`kept`).
static func kept_losses(sim: RefCounted, s: Dictionary) -> float:
	return maxf(0.0, 1.0 + sim.Research.bonus(sim, "event_losses")) * kept(sim, s)


## The latest strike at a town within `loss_days`, or {}: what an event takes there in those days
## counts as the weather's loss.
static func recent_strike(sim: RefCounted, s: Dictionary) -> Dictionary:
	var latest: Dictionary = {}
	var window: int = int(rules().get("loss_days", 15))
	for strike: Dictionary in sim.state.get("weather", {}).get("strikes", []):
		if int(strike.region) == int(s.region) and int(sim.state.day) - int(strike.day) <= window:
			latest = strike
	return latest


## What a town keeps of the weather's losses: less with the disaster engineering technology, less
## again when it was prepared for the system that struck it. Other losses stay whole.
static func kept(sim: RefCounted, s: Dictionary) -> float:
	var strike: Dictionary = recent_strike(sim, s)
	if strike.is_empty():
		return 1.0
	var share: float = maxf(0.0, 1.0 + sim.Research.bonus(sim, "weather_losses"))
	if bool(strike.prepared):
		share *= float(rules().get("prepared_losses", 1.0))
	return share


## An event's losses at a town after the cuts, through the ledger. The weather's share is written
## on its strike and in the running total that audit() holds against the ledger's sinks.
static func take_losses(sim: RefCounted, s: Dictionary, goods: Dictionary) -> void:
	var strike: Dictionary = recent_strike(sim, s)
	var factor: float = kept_losses(sim, s)
	for good: String in goods:
		var lost: float = minf(float(goods[good]) * factor, float(s.stock[good]))
		sim._consume(s, good, lost)
		if strike.is_empty() or lost <= 0.0:
			continue
		if not strike.has("losses"):
			strike.losses = {}
		strike.losses[good] = float(strike.losses.get(good, 0.0)) + lost
		ensure_state(sim.state)
		sim.state.weather.lost[good] = float(sim.state.weather.lost.get(good, 0.0)) + lost


## A force majeure claim for the latest disaster at a town. Returns the refusal, "" if accepted.
static func claim(sim: RefCounted, region: int) -> String:
	ensure_state(sim.state)
	var w: Dictionary = sim.state.weather
	var latest: Dictionary = {}
	for strike: Dictionary in w.strikes:
		if int(strike.region) == region:
			latest = strike
	if latest.is_empty():
		return "这个据点最近没有天气灾害"
	if int(sim.state.day) - int(latest.day) > int(rules().get("claim_days", 15)):
		return "不可抗力申请须在灾害发生后 %d 日内提出" % int(rules().get("claim_days", 15))
	for row: Dictionary in w.claims:
		if int(row.system) == int(latest.system) and int(row.region) == region:
			return "这次灾害已经申请过"
	var rule: Dictionary = rules().kinds[str(latest.kind)]
	var accepted: bool = bool(latest.covered) or bool(latest.warned)
	var record: Dictionary = {
		"system": int(latest.system),
		"region": region,
		"day": int(sim.state.day),
		"accepted": accepted,
		"days": int(rule.get("disaster_days", 0)) if accepted else 0,
		"line": str(rule.get("report_line", "")),
	}
	w.claims.append(record)
	if not accepted:
		sim._log("不可抗力申请被驳回：既无气象站记录，也没有登记在案的预警。")
		return "没有气象站记录，也没有登记在案的预警，申请被驳回"
	var contract: Dictionary = sim.state.contract
	var stage: int = clampi(int(contract.stage), 1, sim.Contract.STAGE_COUNT)
	contract.deadline_shifts[str(stage)] = (
		int(contract.deadline_shifts.get(str(stage), 0)) + int(record.days)
	)
	var annual: Dictionary = sim.state.get("annual", {})
	if not annual.is_empty() and str(record.line) != "":
		if not annual.has("waivers"):
			annual.waivers = []
		if not str(record.line) in annual.waivers:
			annual.waivers.append(str(record.line))
	sim._log("不可抗力申请获准：本阶段期限顺延 %d 日，本年度报告相应一项不计未达标。" % int(record.days))
	return ""


## The systems as the views draw them: where each is, how big, which way it is going.
static func view(sim: RefCounted) -> Array:
	var out: Array = []
	for system: Dictionary in sim.state.get("weather", {}).get("systems", []):
		out.append(system.duplicate(true))
	return out


## The weather's books: systems where they can be, strikes and claims that agree, the deadline
## days that accepted claims gave, and the losses put on the weather within the ledger's sinks.
static func audit(sim: RefCounted) -> Array:
	var errors: Array = []
	var w: Dictionary = sim.state.get("weather", {})
	if w.is_empty():
		return errors
	var kinds: Dictionary = rules().get("kinds", {})
	var ids: Dictionary = {}
	for system: Dictionary in w.systems:
		var id: int = int(system.id)
		if not kinds.has(str(system.kind)) or ids.has(id) or id >= int(w.next_id):
			errors.append("weather system invalid")
		ids[id] = true
		if absf(float(system.lat)) > 90.0 or absf(float(system.lon)) > 180.0:
			errors.append("weather system off the planet")
		if float(system.radius) <= 0.0 or int(system.age) < 0 or int(system.age) > int(system.life):
			errors.append("weather system size or age")
	var lost: Dictionary = w.get("lost", {})
	var struck: Dictionary = {}
	for strike: Dictionary in w.strikes:
		if not kinds.has(str(strike.kind)) or int(strike.day) > int(sim.state.day):
			errors.append("weather strike invalid")
		struck["%d:%d" % [int(strike.system), int(strike.region)]] = int(strike.day)
		var losses: Dictionary = strike.get("losses", {})
		for good: String in losses:
			if (
				float(losses[good]) < 0.0
				or float(losses[good]) > float(lost.get(good, 0.0)) + 0.001
			):
				errors.append("weather losses beyond their total " + good)
	var claimed: Dictionary = {}
	var granted: int = 0
	for row: Dictionary in w.claims:
		var key: String = "%d:%d" % [int(row.system), int(row.region)]
		if claimed.has(key):
			errors.append("force majeure claimed twice")
		claimed[key] = true
		if struck.has(key) and int(row.day) - int(struck[key]) > int(rules().get("claim_days", 15)):
			errors.append("force majeure claimed late")
		if bool(row.accepted):
			granted += int(row.days)
	var shifted: int = 0
	for days: Variant in sim.state.contract.get("deadline_shifts", {}).values():
		shifted += int(days)
	if granted > shifted:
		errors.append("force majeure days missing from the deadlines")
	for good: String in lost:
		var sunk: float = float(sim.state.resource_sinks.get(good, 0.0))
		if float(lost[good]) < 0.0 or float(lost[good]) > sunk + 0.001:
			errors.append("weather losses outside the ledger " + good)
	return errors


static func validate(_sim: RefCounted, candidate: Dictionary) -> String:
	var weather: Variant = candidate.get("weather")
	if not weather is Dictionary:
		return "存档缺少天气"
	for key: String in ["systems", "next_id", "strikes", "claims"]:
		if not weather.has(key):
			return "天气缺少字段：" + key
	if not weather.systems is Array or not weather.strikes is Array or not weather.claims is Array:
		return "天气数据无效"
	if weather.has("lost") and not weather.lost is Dictionary:
		return "天气数据无效"
	return ""
