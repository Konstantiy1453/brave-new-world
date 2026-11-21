extends RefCounted
## Mobile engineering crews (工程队), 1.10 plan C: a few teams that put up buildings, apart from the
## residents who work the facilities (职工). A building under construction moves on only on a day a
## crew works on it. The standing instruction: a project that fixes a shortage the town has today
## (water, power, food) comes first, even off a project under way, then the one the player chose to
## build next, then the oldest order. A crew can be sent to another town over a finished link,
## which takes the link's
## days. Crews are residents: each team is one adult population unit (`s.crew`), with a bed and a
## wage. Training turns a worker into a crew (the town keeps its people); a crew recruited from
## outside arrives later and adds one. Prefabricated kits that arrive with an expedition assemble
## on their own.

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Stats = preload("res://simulation/stats.gd")

const IDLE: String = ""
const BUILD: String = "build"
const TRAVEL: String = "travel"
const TRAIN: String = "train"
## Away on a repair an event asked for (1.11): counted at no town until it is back home.
const REPAIR: String = "repair"


static func rules(sim: RefCounted) -> Dictionary:
	return sim.pop_rules.get("crews", {})


## Adds crews to a state that has none. A save from before crews gets one crew for each project it
## had under way and at least one a town, taken from its workers, so nothing in it stalls and every
## town keeps its people.
static func ensure_state(state: Dictionary) -> void:
	if state.has("crews"):
		return
	state.crews = {"next_id": 1, "teams": [], "working": {}}
	for s: Dictionary in state.get("settlements", []):
		if not s.has("crew"):
			s.crew = 0
		var under_way: Array = []
		for b: Dictionary in s.get("buildings", []):
			if int(b.get("remaining", 0)) > 0 and not bool(b.get("prefab", false)):
				under_way.append(int(b.get("uid", 0)))
		var wanted: int = maxi(1, under_way.size())
		var taken: int = mini(wanted, int(s.get("workers", 0)))
		s.workers = int(s.workers) - taken
		s.crew = int(s.crew) + taken
		_release_jobs(s)
		for index: int in range(taken):
			var team: Dictionary = _new_team(state, int(s.region))
			if index < under_way.size():
				team.task = BUILD
				team.target = int(under_way[index])
			state.crews.teams.append(team)


## Workers who became crews leave their posts: the day's employment never counts more workers
## than the town has. The next day's work hands the posts out again.
static func _release_jobs(s: Dictionary) -> void:
	var over: int = int(s.get("employed_workers", 0)) - int(s.get("workers", 0))
	if over <= 0:
		return
	s.employed_workers = int(s.employed_workers) - over
	s.employed = maxi(0, int(s.get("employed", 0)) - over)
	var buildings: Array = s.get("buildings", [])
	for index: int in range(buildings.size() - 1, -1, -1):
		if over <= 0:
			break
		var b: Dictionary = buildings[index]
		var freed: int = mini(over, int(b.get("employed", 0)))
		b.employed = int(b.get("employed", 0)) - freed
		over -= freed


static func _new_team(state: Dictionary, region: int) -> Dictionary:
	var id: int = int(state.crews.next_id)
	state.crews.next_id = id + 1
	return {"id": id, "region": region, "task": IDLE, "target": 0, "until": 0}


## A landing or a new town's first crews, made from its workers: the town keeps its people.
static func found(sim: RefCounted, s: Dictionary, count: int) -> void:
	ensure_state(sim.state)
	var taken: int = mini(count, int(s.workers))
	s.workers = int(s.workers) - taken
	s.crew = int(s.get("crew", 0)) + taken
	_release_jobs(s)
	for _index: int in range(taken):
		sim.state.crews.teams.append(_new_team(sim.state, int(s.region)))


## An expedition takes up to `count` crews from the town it leaves, idle ones first, then busy
## ones (their projects wait), but leaves the town at least one: they travel with it and are
## counted in the new town when it arrives.
static func join_expedition(
	sim: RefCounted, src: Dictionary, region: int, days: int, count: int
) -> void:
	ensure_state(sim.state)
	if src.is_empty():
		return
	var at_home: int = teams_at(sim, int(src.region)).size()
	count = mini(count, at_home - 1)
	var sent: int = 0
	for idle_only: bool in [true, false]:
		for team: Dictionary in sim.state.crews.teams:
			if sent >= count:
				return
			if int(team.region) != int(src.region) or str(team.task) in [TRAVEL, TRAIN]:
				continue
			if idle_only and str(team.task) != IDLE:
				continue
			team.task = TRAVEL
			team.target = region
			team.until = int(sim.state.day) + maxi(1, days)
			src.crew = int(src.get("crew", 0)) - 1
			src.population = int(src.population) - 1
			Stats.count(sim.state, "moves", int(src.region), -1)
			sent += 1


static func teams_at(sim: RefCounted, region: int) -> Array:
	var found_teams: Array = []
	for team: Dictionary in sim.state.get("crews", {}).get("teams", []):
		if int(team.region) == region and not str(team.task) in [TRAVEL, REPAIR]:
			found_teams.append(team)
	return found_teams


## The day's work, before construction moves: crews that have arrived settle in, training ends,
## each idle crew takes the first project in its town's queue, and a project that fixes a shortage
## takes a crew off one that does not (that one keeps its progress). Returns the uids under work.
static func daily(sim: RefCounted) -> Dictionary:
	ensure_state(sim.state)
	var day: int = int(sim.state.day)
	for team: Dictionary in sim.state.crews.teams:
		# On a closed link a crew waits where it is, as freight does (logistics._waiting_on_closure).
		if str(team.task) == TRAVEL and _link_closed(sim, team):
			team.until = int(team.until) + 1
			team.held = true
			continue
		team.erase("held")
		if str(team.task) == TRAVEL and day >= int(team.until):
			var s: Dictionary = sim.settlement(int(team.target))
			team.region = int(team.target)
			team.task = IDLE
			team.target = 0
			if not s.is_empty():
				s.crew = int(s.get("crew", 0)) + 1
				s.population = int(s.population) + 1
				Stats.count(sim.state, "moves", int(s.region), 1)
				sim._log("%s · 一支工程队抵达。" % s.name)
		elif str(team.task) == TRAIN and day >= int(team.until):
			team.task = IDLE
			team.target = 0
		elif str(team.task) == REPAIR and day >= int(team.until):
			# The repair is done: the town's water is whole again, and the crew heads home.
			sim.EventsV2.end_repair(sim, str(team.get("repair_source", "")))
			team.task = TRAVEL
			team.target = int(team.get("home", team.region))
			team.until = day + maxi(1, int(team.get("travel_back", 1)))
			team.erase("repair_source")
			sim._log("工程队 #%d 修好了水站，正在返回。" % int(team.id))
	var working: Dictionary = {}
	sim.state.crews.working = working
	for team: Dictionary in sim.state.crews.teams:
		if str(team.task) == BUILD:
			var s: Dictionary = sim.settlement(int(team.region))
			var index: int = sim.Production.index_of(s, int(team.target))
			if index < 0 or int(s.buildings[index].remaining) <= 0:
				team.task = IDLE
				team.target = 0
			else:
				working[int(team.target)] = true
	for team: Dictionary in sim.state.crews.teams:
		if str(team.task) != IDLE:
			continue
		var next: int = next_project(sim, int(team.region), working)
		if next > 0:
			team.task = BUILD
			team.target = next
			working[next] = true
	_shortages_first(sim, working)
	_forget_finished_choices(sim)
	return working


static func _forget_finished_choices(sim: RefCounted) -> void:
	var chosen: Dictionary = sim.state.crews.get("next", {})
	for key: String in chosen.keys():
		var s: Dictionary = sim.settlement(int(key))
		var index: int = -1 if s.is_empty() else sim.Production.index_of(s, int(chosen[key]))
		if index < 0 or int(s.buildings[index].remaining) <= 0:
			chosen.erase(key)


## An urgent project nobody works on takes a crew off a project at its town that is not urgent.
static func _shortages_first(sim: RefCounted, working: Dictionary) -> void:
	for team: Dictionary in sim.state.crews.teams:
		if str(team.task) != BUILD:
			continue
		var s: Dictionary = sim.settlement(int(team.region))
		var index: int = sim.Production.index_of(s, int(team.target))
		if index < 0 or fixes_shortage(sim, s, s.buildings[index]):
			continue
		var waiting: Array = queue(sim, s, working)
		if waiting.is_empty() or not fixes_shortage(sim, s, waiting[0]):
			continue
		working.erase(int(team.target))
		team.target = int(waiting[0].get("uid", 0))
		working[int(team.target)] = true


## The first project in a town's queue: its uid, or 0.
static func next_project(sim: RefCounted, region: int, working: Dictionary) -> int:
	var waiting: Array = queue(sim, sim.settlement(region), working)
	if waiting.is_empty():
		return 0
	return int(waiting[0].get("uid", 0))


## A town's buildings still waiting for a crew, in the order crews take them: those that fix a
## shortage the town has today first, then the one chosen to go next, then the oldest order.
static func queue(
	sim: RefCounted, s: Dictionary, working: Dictionary, extra: Dictionary = {}
) -> Array:
	var urgent: Array = []
	var chosen: Array = []
	var rest: Array = []
	var next_uid: int = chosen_next(sim, int(s.get("region", -1)))
	var all: Array = s.get("buildings", []).duplicate()
	if not extra.is_empty():
		all.append(extra)
	for b: Dictionary in all:
		if int(b.remaining) <= 0 or bool(b.get("prefab", false)):
			continue
		if working.has(int(b.get("uid", 0))):
			continue
		if fixes_shortage(sim, s, b):
			urgent.append(b)
		elif int(b.get("uid", 0)) == next_uid:
			chosen.append(b)
		else:
			rest.append(b)
	urgent.sort_custom(_older)
	rest.sort_custom(_older)
	return _roads_first(urgent + chosen + rest)


## A mine that branches off another mine's road waits for that mine: the main road is built first.
static func _roads_first(order: Array) -> Array:
	var result: Array = order.duplicate()
	for b: Dictionary in order:
		var via: int = int(b.get("haul", {}).get("via", 0))
		if via <= 0:
			continue
		var at: int = result.find(b)
		var road: int = -1
		for index: int in range(result.size()):
			if int(result[index].get("uid", 0)) == via:
				road = index
		if road > at:
			result.remove_at(at)
			result.insert(road, b)
	return result


## The project the player chose to build next at a town, while it still waits: its uid, or 0.
static func chosen_next(sim: RefCounted, region: int) -> int:
	return int(sim.state.get("crews", {}).get("next", {}).get(str(region), 0))


## The player's order to the town's crews: build this project next. It goes ahead of every older
## order but not of a project that fixes a shortage; a crew already on another project finishes it.
static func choose_next(sim: RefCounted, region: int, uid: int) -> String:
	ensure_state(sim.state)
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return "请选择已建立的据点"
	var index: int = sim.Production.index_of(s, uid)
	if index < 0 or int(s.buildings[index].remaining) <= 0:
		return "这项工程已经完工或不存在"
	if bool(s.buildings[index].get("prefab", false)):
		return "预制件自行组装，不需要工程队"
	if not sim.state.crews.has("next"):
		sim.state.crews.next = {}
	sim.state.crews.next[str(region)] = uid
	return ""


## A project taken back before work began (Production.withdraw): a crew that had taken it up is free
## for the next one, and it is no longer the town's chosen next project.
static func release_target(sim: RefCounted, region: int, uid: int) -> void:
	ensure_state(sim.state)
	for team: Dictionary in sim.state.crews.teams:
		if str(team.task) == BUILD and int(team.target) == uid and int(team.region) == region:
			team.task = IDLE
			team.target = 0
	sim.state.crews.get("working", {}).erase(uid)
	if int(sim.state.crews.get("next", {}).get(str(region), 0)) == uid:
		sim.state.crews.next.erase(str(region))


## When each project at a town is expected to start and finish, from its crews and its queue as
## they stand today: {uid: {"start", "finish", "crew"}}, the first and the last working day;
## both -1 for a project no crew here can reach (none at the town, none coming). A crew's last busy
## day is tracked: one that ends its training or arrives works that same day. A shortage tomorrow
## can change it.
static func eta(sim: RefCounted, s: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var day: int = int(sim.state.day)
	var crews: Dictionary = sim.state.get("crews", {})
	var everywhere: bool = bool(crews.get("all_sites", false))
	var free_at: Array = []
	var ids: Array = []
	for team: Dictionary in crews.get("teams", []):
		var here: bool = int(team.region) == int(s.region)
		var coming: bool = str(team.task) == TRAVEL and int(team.target) == int(s.region)
		# A crew away on a repair comes back home after it.
		var returning: bool = (
			str(team.task) == REPAIR and int(team.get("home", -1)) == int(s.region)
		)
		if str(team.task) == TRAVEL and not coming:
			continue
		if str(team.task) == REPAIR and not returning:
			continue
		if not here and not coming and not returning:
			continue
		var at: int = day
		if str(team.task) in [TRAVEL, TRAIN]:
			at = maxi(day, int(team.until) - 1)
		elif returning:
			at = maxi(day, int(team.until) + int(team.get("travel_back", 0)) - 1)
		elif str(team.task) == BUILD:
			var index: int = sim.Production.index_of(s, int(team.target))
			if index >= 0:
				at = day + int(s.buildings[index].remaining)
				result[int(team.target)] = {"start": day + 1, "finish": at, "crew": int(team.id)}
		free_at.append(at)
		ids.append(int(team.id))
	for b: Dictionary in s.get("buildings", []):
		var uid: int = int(b.get("uid", 0))
		if int(b.remaining) > 0 and (everywhere or bool(b.get("prefab", false))):
			result[uid] = {"start": day + 1, "finish": day + int(b.remaining), "crew": 0}
	if everywhere:
		return result
	for b: Dictionary in queue(sim, s, crews.get("working", {}), extra):
		var uid: int = int(b.get("uid", 0))
		if result.has(uid):
			continue
		if free_at.is_empty():
			result[uid] = {"start": -1, "finish": -1, "crew": 0}
			continue
		var first: int = 0
		for index: int in range(1, free_at.size()):
			if int(free_at[index]) < int(free_at[first]):
				first = index
		var start: int = int(free_at[first]) + 1
		free_at[first] = int(free_at[first]) + int(b.remaining)
		result[uid] = {"start": start, "finish": int(free_at[first]), "crew": int(ids[first])}
	return result


## What one more order of `kind` taking `days` would get at this town if placed now (1.11), by the
## same queue rules the crews follow (`queue`, `eta`): the crew expected to build it (here, or on its
## way here), its place in the line of that crew's work with what comes before it and when each is
## done, and the days it would start and finish. start -1 when no crew is here or coming, with the
## nearest crew elsewhere that could be sent.
static func projection(sim: RefCounted, s: Dictionary, kind: String, days: int) -> Dictionary:
	ensure_state(sim.state)
	var uid: int = int(sim.state.get("next_building_uid", 1)) + 1000000
	var phantom: Dictionary = {"kind": kind, "remaining": days, "uid": uid, "total_days": days}
	var plans: Dictionary = eta(sim, s, phantom)
	var plan: Dictionary = plans.get(uid, {"start": -1, "finish": -1, "crew": 0})
	var result: Dictionary = {
		"start": int(plan.start),
		"finish": int(plan.finish),
		"crew": int(plan.crew),
		"ahead": [],
		"place": 1,
		"crew_state": "",
		"urgent": fixes_shortage(sim, s, phantom),
		"send": {},
	}
	if int(plan.crew) > 0:
		var team: Dictionary = _team(sim, int(plan.crew))
		result.crew_state = str(team.get("task", ""))
		if str(team.task) in [TRAVEL, TRAIN]:
			result.crew_until = int(team.until)
		# The work this crew does before the new order, in order.
		var rows: Array = []
		for other: int in plans:
			if other == uid or int(plans[other].crew) != int(plan.crew):
				continue
			if int(plans[other].start) > int(plan.start):
				continue
			var index: int = sim.Production.index_of(s, other)
			if index < 0:
				continue
			var b: Dictionary = s.buildings[index]
			(
				rows
				. append(
					{
						"uid": other,
						"name": str(sim.config.buildings.get(str(b.kind), {}).get("name", b.kind)),
						"start": int(plans[other].start),
						"finish": int(plans[other].finish),
						"started": int(b.remaining) < int(b.get("total_days", b.remaining)),
					}
				)
			)
		rows.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return int(a.start) < int(b.start)
		)
		result.ahead = rows
		result.place = rows.size() + 1
	elif int(plan.start) < 0:
		result.send = _nearest_free_crew(sim, int(s.region))
	return result


## The crew elsewhere that could reach a town soonest: {crew, from, days}, or empty.
static func _nearest_free_crew(sim: RefCounted, region: int) -> Dictionary:
	var best: Dictionary = {}
	for team: Dictionary in sim.state.crews.teams:
		if int(team.region) == region or str(team.task) in [TRAVEL, TRAIN]:
			continue
		var days: int = travel_days(sim, int(team.region), region)
		if days < 0:
			continue
		var busy: int = 0
		if str(team.task) == BUILD:
			var there: Dictionary = sim.settlement(int(team.region))
			var index: int = sim.Production.index_of(there, int(team.target))
			busy = int(there.buildings[index].remaining) if index >= 0 else 0
		if best.is_empty() or days + busy < int(best.days) + int(best.busy):
			best = {
				"crew": int(team.id),
				"from": str(sim.settlement(int(team.region)).get("name", "")),
				"days": days,
				"busy": busy,
			}
	return best


static func _older(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("uid", 0)) < int(b.get("uid", 0))


## Whether a building of this kind fixes a shortage its town has today: its role is listed under
## one of the town's shortages in the crew rules (`urgent`). Beds are not: a growing town is
## nearly always short of them, and the crew would never leave its housing.
static func fixes_shortage(sim: RefCounted, s: Dictionary, b: Dictionary) -> bool:
	var urgent: Dictionary = rules(sim).get("urgent", {})
	var role: String = str(sim.config.buildings.get(str(b.get("kind", "")), {}).get("role", ""))
	if role == "":
		return false
	for entry: Dictionary in s.get("shortages", []):
		if role in urgent.get(str(entry.get("key", "")), []):
			return true
	return false


## Whether this building moves on today: a crew is on it, or it is a kit that assembles itself.
static func works_on(sim: RefCounted, b: Dictionary) -> bool:
	if bool(b.get("prefab", false)):
		return true
	var crews: Dictionary = sim.state.get("crews", {})
	if bool(crews.get("all_sites", false)):
		return true
	return crews.get("working", {}).has(int(b.get("uid", 0)))


## For the suites that test other systems: every site moves on without a crew, as before 1.10.
## No game sets it.
static func unlimited(sim: RefCounted) -> void:
	ensure_state(sim.state)
	sim.state.crews.all_sites = true


## Sends a crew to another town over a finished link: it leaves its project, travels the link's
## days and takes the first project waiting there.
static func send(sim: RefCounted, crew_id: int, to: int) -> String:
	ensure_state(sim.state)
	var team: Dictionary = _team(sim, crew_id)
	if team.is_empty():
		return "没有这支工程队"
	if str(team.task) in [TRAVEL, TRAIN]:
		return "这支工程队正在路上或培训中"
	var from: Dictionary = sim.settlement(int(team.region))
	var dest: Dictionary = sim.settlement(to)
	if dest.is_empty() or to == int(team.region):
		return "请选择另一个已建立的据点"
	var link: Dictionary = travel_link(sim, int(team.region), to)
	var days: int = int(link.days)
	if days < 0:
		return str(link.reason)
	from.crew = int(from.get("crew", 0)) - 1
	from.population = int(from.population) - 1
	Stats.count(sim.state, "moves", int(from.region), -1)
	team.task = TRAVEL
	team.target = to
	team.road = int(link.road)
	team.until = int(sim.state.day) + days
	sim._log("%s · 一支工程队出发前往%s，%d 天后到达。" % [from.name, dest.name, days])
	return ""


## Days a crew needs between two towns: the quickest open link, -1 when there is none.
static func travel_days(sim: RefCounted, from: int, to: int) -> int:
	return int(travel_link(sim, from, to).days)


## The quickest link a crew can take between two towns today, by the rule freight follows
## (logistics._dispatch_road): built, not closed, not retired, at freight's days. {"days", "road",
## "reason"}; days -1 and the reason when there is none.
static func travel_link(sim: RefCounted, from: int, to: int) -> Dictionary:
	var best: Dictionary = {"days": -1, "road": -1, "reason": "两地之间还没有通车的线路"}
	var day: int = int(sim.state.day)
	for road: Dictionary in sim.state.get("roads", []):
		var ends: Array = [int(road.a), int(road.b)]
		if not (ends.has(from) and ends.has(to)) or bool(road.get("retired", false)):
			continue
		if WorldGen.road_blocked(road, day):
			if not WorldGen.road_building(road, day):
				best.reason = "两地之间的线路封闭中，货运同样停运"
			continue
		var days: int = sim.Logistics.road_days(sim, road)
		if int(best.days) < 0 or days < int(best.days):
			best = {"days": days, "road": int(road.get("id", -1)), "reason": ""}
	return best


static func _link_closed(sim: RefCounted, team: Dictionary) -> bool:
	var road: int = int(team.get("road", -1))
	var roads: Array = sim.state.get("roads", [])
	if road < 0 or road >= roads.size():
		return false
	return WorldGen.road_blocked(roads[road], int(sim.state.day))


## Trains one of a town's workers as a crew: the town keeps its people, pays the fee, and the
## crew starts work once trained.
static func train(sim: RefCounted, region: int) -> String:
	ensure_state(sim.state)
	var s: Dictionary = sim.settlement(region)
	var rule: Dictionary = rules(sim)
	if s.is_empty():
		return "请选择已建立的据点"
	if int(s.workers) - int(s.employed_workers) < 1 and int(s.workers) < 2:
		return "没有可以培训的职工"
	var cost: float = float(rule.get("train_cost", 0.0))
	if float(sim.state.cash) < cost:
		return "公共资金不足：需要 %.0f" % cost
	sim._transfer("public", "external", cost, "invest.crew", false, "train")
	s.workers = int(s.workers) - 1
	s.crew = int(s.get("crew", 0)) + 1
	_release_jobs(s)
	var team: Dictionary = _new_team(sim.state, region)
	team.task = TRAIN
	team.until = int(sim.state.day) + int(rule.get("train_days", 0))
	sim.state.crews.teams.append(team)
	sim._log("%s · 一名职工开始接受工程队培训，%d 天后可以派工。" % [s.name, int(rule.get("train_days", 0))])
	return ""


static func _team(sim: RefCounted, crew_id: int) -> Dictionary:
	for team: Dictionary in sim.state.get("crews", {}).get("teams", []):
		if int(team.id) == crew_id:
			return team
	return {}


## Crews' wages, paid daily like the other wages.
static func wages(sim: RefCounted) -> float:
	var count: int = sim.state.get("crews", {}).get("teams", []).size()
	return (
		float(count) * float(rules(sim).get("wage", 0.0)) * float(sim.state.policy.get("wage", 1.0))
	)


## What the construction page shows: every crew with where it is, what it does and until when,
## the projects waiting at each town in the order crews take them, and how many of those fix a
## shortage (they come first).
static func view(sim: RefCounted) -> Dictionary:
	var crews: Dictionary = sim.state.get("crews", {})
	var rows: Array = []
	for team: Dictionary in crews.get("teams", []):
		var row: Dictionary = team.duplicate()
		var s: Dictionary = sim.settlement(int(team.region))
		row.place = str(s.get("name", ""))
		if str(team.task) == BUILD:
			var index: int = sim.Production.index_of(s, int(team.target))
			if index >= 0:
				var b: Dictionary = s.buildings[index]
				row.project = str(sim.config.buildings.get(b.kind, {}).get("name", b.kind))
				row.days_left = int(b.remaining)
		rows.append(row)
	var waiting: Dictionary = {}
	var urgent: Dictionary = {}
	var working: Dictionary = crews.get("working", {})
	for s: Dictionary in sim.state.get("settlements", []):
		var names: Array = []
		for b: Dictionary in queue(sim, s, working):
			names.append(str(sim.config.buildings.get(b.kind, {}).get("name", b.kind)))
			if fixes_shortage(sim, s, b):
				urgent[int(s.region)] = int(urgent.get(int(s.region), 0)) + 1
		if not names.is_empty():
			waiting[int(s.region)] = names
	return {"teams": rows, "waiting": waiting, "urgent": urgent}


## Checks for the audit: every crew where a crew can be, each town's count matching its teams.
static func audit(state: Dictionary) -> Array:
	var errors: Array = []
	if not state.has("crews"):
		return errors
	var counted: Dictionary = {}
	for team: Dictionary in state.crews.teams:
		if str(team.task) in [TRAVEL, REPAIR]:
			continue
		counted[int(team.region)] = int(counted.get(int(team.region), 0)) + 1
	for s: Dictionary in state.get("settlements", []):
		if int(s.get("crew", 0)) != int(counted.get(int(s.region), 0)):
			errors.append("crew count does not match its teams")
	return errors
