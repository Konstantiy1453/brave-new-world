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
## Beyond buildings (1.10.1, the November 20 brief): a land road ordered now, and a road's upgrade,
## move on only on a day a crew from one of its towns works on them (a day without one puts the
## finish a day later); a crew on a road closed by rockfall clears it twice as fast; a field survey
## or a drilling takes a crew from the nearest town into the field for its days. Each town has a
## standing order for what its crews take after the shortages (`ORDERS`), and every crew the colony
## adds beyond the first ones costs more to train or hire (`expansion_factor`).

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")
const Stats = preload("res://simulation/stats.gd")

const IDLE: String = ""
const BUILD: String = "build"
const TRAVEL: String = "travel"
const TRAIN: String = "train"
const ROAD: String = "road"
const REPAIR: String = "repair"
const FIELD: String = "field"
## A town's standing order (`crews.orders`), after the projects that fix a shortage, which always
## come first, and the one chosen to go next: everything in the order it was given, with a closed
## road cleared first (the default); repairs and roads before facilities; or facilities before
## repairs and roads.
const ORDER_OLDEST: String = "oldest"
const ORDER_ROADS: String = "roads"
const ORDER_FACILITIES: String = "facilities"
const ORDERS: Array[String] = [ORDER_OLDEST, ORDER_ROADS, ORDER_FACILITIES]


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
			if int(team.region) != int(src.region) or str(team.task) in [TRAVEL, TRAIN, FIELD]:
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


## The crews at a town: not on the way somewhere and not out in the field.
static func teams_at(sim: RefCounted, region: int) -> Array:
	var found_teams: Array = []
	for team: Dictionary in sim.state.get("crews", {}).get("teams", []):
		if int(team.region) == region and not str(team.task) in [TRAVEL, FIELD]:
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
		elif str(team.task) in [TRAIN, FIELD] and day >= int(team.until):
			if str(team.task) == FIELD:
				var home: Dictionary = sim.settlement(int(team.region))
				sim._log("%s · 工程队 #%d 从野外回来。" % [str(home.get("name", "")), int(team.id)])
			team.task = IDLE
			team.target = 0
	var working: Dictionary = {}
	sim.state.crews.working = working
	for team: Dictionary in sim.state.crews.teams:
		match str(team.task):
			BUILD:
				var s: Dictionary = sim.settlement(int(team.region))
				var index: int = sim.Production.index_of(s, int(team.target))
				if index < 0 or int(s.buildings[index].remaining) <= 0:
					team.task = IDLE
					team.target = 0
				else:
					working[int(team.target)] = true
			ROAD, REPAIR:
				var work: Dictionary = road_work(sim, _road(sim, int(team.target)))
				if work.is_empty() or str(work.kind) != str(team.task):
					team.task = IDLE
					team.target = 0
				else:
					working[road_key(int(team.target))] = true
	for team: Dictionary in sim.state.crews.teams:
		if str(team.task) != IDLE:
			continue
		var waiting: Array = queue(sim, sim.settlement(int(team.region)), working)
		if not waiting.is_empty():
			_take(team, waiting[0], working)
	_shortages_first(sim, working)
	_forget_finished_choices(sim)
	return working


## A crew takes a queue item: a building (its uid) or road work (its road, by kind).
static func _take(team: Dictionary, item: Dictionary, working: Dictionary) -> void:
	working[int(item.get("uid", 0))] = true
	if item.has("road"):
		team.task = str(item.kind)
		team.target = int(item.road)
	else:
		team.task = BUILD
		team.target = int(item.get("uid", 0))


static func _forget_finished_choices(sim: RefCounted) -> void:
	var chosen: Dictionary = sim.state.crews.get("next", {})
	for key: String in chosen.keys():
		var s: Dictionary = sim.settlement(int(key))
		var index: int = -1 if s.is_empty() else sim.Production.index_of(s, int(chosen[key]))
		if index < 0 or int(s.buildings[index].remaining) <= 0:
			chosen.erase(key)


## An urgent project nobody works on takes a crew off a project at its town that is not urgent: a
## building, a road or a repair (each keeps its progress).
static func _shortages_first(sim: RefCounted, working: Dictionary) -> void:
	for team: Dictionary in sim.state.crews.teams:
		if not str(team.task) in [BUILD, ROAD, REPAIR]:
			continue
		var s: Dictionary = sim.settlement(int(team.region))
		var key: int = int(team.target)
		if str(team.task) == BUILD:
			var index: int = sim.Production.index_of(s, key)
			if index < 0 or fixes_shortage(sim, s, s.buildings[index]):
				continue
		else:
			key = road_key(int(team.target))
		var waiting: Array = queue(sim, s, working)
		if waiting.is_empty() or not fixes_shortage(sim, s, waiting[0]):
			continue
		working.erase(key)
		_take(team, waiting[0], working)


## The first project in a town's queue: a building's uid, a road work key (`road_key`), or 0.
static func next_project(sim: RefCounted, region: int, working: Dictionary) -> int:
	var waiting: Array = queue(sim, sim.settlement(region), working)
	if waiting.is_empty():
		return 0
	return int(waiting[0].get("uid", 0))


## What a town's crews still have to take, in the order they take it: the buildings that fix a
## shortage the town has today, the one chosen to go next, then by the town's standing order
## (`ORDERS`) the other buildings and the road work at its roads (`road_items`). A building is a
## building record; road work is {uid (its road_key), road, kind, remaining, ordered, name}.
static func queue(sim: RefCounted, s: Dictionary, working: Dictionary) -> Array:
	var urgent: Array = []
	var chosen: Array = []
	var rest: Array = []
	var next_uid: int = chosen_next(sim, int(s.get("region", -1)))
	for b: Dictionary in s.get("buildings", []):
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
	var repairs: Array = []
	var roads: Array = []
	for item: Dictionary in road_items(sim, s, working):
		if str(item.kind) == REPAIR:
			repairs.append(item)
		else:
			roads.append(item)
	match order_of(sim, int(s.get("region", -1))):
		ORDER_ROADS:
			return _roads_first(urgent + chosen + repairs + roads + rest)
		ORDER_FACILITIES:
			return _roads_first(urgent + chosen + rest + repairs + roads)
	var merged: Array = rest + roads
	merged.sort_custom(_ordered_before)
	return _roads_first(urgent + repairs + chosen + merged)


## Buildings and road works in the order they were given: by the day ordered (a building from
## before 1.10.1 counts as the oldest), a building before a road on the same day, then by uid or id.
static func _ordered_before(a: Dictionary, b: Dictionary) -> bool:
	var day_a: int = int(a.get("ordered", 0))
	var day_b: int = int(b.get("ordered", 0))
	if day_a != day_b:
		return day_a < day_b
	var road_a: bool = a.has("road")
	var road_b: bool = b.has("road")
	if road_a != road_b:
		return road_b
	if road_a:
		return int(a.road) < int(b.road)
	return _older(a, b)


## The key a road's work has among the projects under work: negative, apart from building uids.
static func road_key(road: int) -> int:
	return -1 - road


static func _road(sim: RefCounted, road: int) -> Dictionary:
	var roads: Array = sim.state.get("roads", [])
	if road < 0 or road >= roads.size():
		return {}
	return roads[road]


## Whether a road is a land road (not a sea link or a shuttle line).
static func _land(r: Dictionary) -> bool:
	var variant: String = str(r.get("variant", "valley"))
	return variant != Keys.ROUTE_SEA and variant != Keys.ROUTE_SHUTTLE


## What a road needs from a crew today, as a queue item, or empty: building a land road ordered
## since crews build roads (`crew_built`), its upgrade (`upgrade_crew`), or a rockfall closure.
static func road_work(sim: RefCounted, r: Dictionary) -> Dictionary:
	if r.is_empty() or bool(r.get("retired", false)) or not _land(r):
		return {}
	var day: int = int(sim.state.day)
	var kind: String = ""
	var remaining: int = 0
	if WorldGen.road_building(r, day):
		if not bool(r.get("crew_built", false)):
			return {}
		kind = ROAD
		remaining = maxi(1, int(r.ready_day) - day)
	elif r.has("upgrade_to") and int(r.get("paving_until", 0)) >= day:
		if not bool(r.get("upgrade_crew", false)):
			return {}
		kind = ROAD
		remaining = maxi(1, int(r.paving_until) - day)
	elif WorldGen.road_blocked(r, day):
		kind = REPAIR
		remaining = maxi(1, ceili(float(int(r.blocked_until) - day + 1) / 2.0))
	else:
		return {}
	var names: Array = []
	for end: int in [int(r.a), int(r.b)]:
		names.append(str(sim.settlement(end).get("name", "?")))
	return {
		"uid": road_key(int(r.id)),
		"road": int(r.id),
		"kind": kind,
		"remaining": remaining,
		"ordered": int(r.get("ordered", 0)),
		"name": ("抢修 %s ↔ %s" if kind == REPAIR else "修路 %s ↔ %s") % names,
	}


## The road work a town's crews can take: at each of its roads that needs a crew and has none.
static func road_items(sim: RefCounted, s: Dictionary, working: Dictionary) -> Array:
	var items: Array = []
	for r: Dictionary in sim.state.get("roads", []):
		if int(r.a) != int(s.get("region", -1)) and int(r.b) != int(s.get("region", -1)):
			continue
		if working.has(road_key(int(r.get("id", -1)))):
			continue
		var work: Dictionary = road_work(sim, r)
		if not work.is_empty():
			items.append(work)
	return items


## Whether a road being built moves on today: a crew works at it (or every site moves on without
## crews, as in the suites for other systems).
static func road_worked(sim: RefCounted, r: Dictionary) -> bool:
	var crews: Dictionary = sim.state.get("crews", {})
	if bool(crews.get("all_sites", false)):
		return true
	return crews.get("working", {}).has(road_key(int(r.get("id", -1))))


## Whether a crew is clearing this closed road today (only a crew does: a closure keeps its days
## without one).
static func road_repaired(sim: RefCounted, r: Dictionary) -> bool:
	return sim.state.get("crews", {}).get("working", {}).has(road_key(int(r.get("id", -1))))


## A town's standing order for its crews (`ORDERS`).
static func order_of(sim: RefCounted, region: int) -> String:
	return str(sim.state.get("crews", {}).get("orders", {}).get(str(region), ORDER_OLDEST))


## The player's standing order to a town's crews.
static func set_order(sim: RefCounted, region: int, order: String) -> String:
	ensure_state(sim.state)
	if sim.settlement(region).is_empty():
		return "请选择已建立的据点"
	if not order in ORDERS:
		return "未知的常设指令"
	if not sim.state.crews.has("orders"):
		sim.state.crews.orders = {}
	sim.state.crews.orders[str(region)] = order
	return ""


## A crew goes into the field with a survey or a drilling team from its town until `until`: an idle
## one if there is one, else one off its project (which waits). Its id, or 0 when the town has none
## at home.
static func take_for_field(sim: RefCounted, region: int, until: int, job: String) -> int:
	ensure_state(sim.state)
	for idle_only: bool in [true, false]:
		for team: Dictionary in teams_at(sim, region):
			if str(team.task) == TRAIN or (idle_only and str(team.task) != IDLE):
				continue
			team.task = FIELD
			team.target = 0
			team.until = until
			team.job = job
			return int(team.id)
	return 0


## Whether a town has a crew at home that could go into the field.
static func can_take_for_field(sim: RefCounted, region: int) -> bool:
	for team: Dictionary in teams_at(sim, region):
		if str(team.task) != TRAIN:
			return true
	return false


## What one more crew costs against the base price: 1, plus `growth_per_crew` for each crew the
## colony has (and `extra` more about to be added) beyond its first `free_crews`.
static func expansion_factor(sim: RefCounted, extra: int = 0) -> float:
	var rule: Dictionary = rules(sim)
	var count: int = sim.state.get("crews", {}).get("teams", []).size() + extra
	var beyond: int = maxi(0, count - int(rule.get("free_crews", 0)))
	return 1.0 + float(rule.get("growth_per_crew", 0.0)) * float(beyond)


## Training one more crew today.
static func train_price(sim: RefCounted) -> float:
	return float(rules(sim).get("train_cost", 0.0)) * expansion_factor(sim)


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


## When each project at a town is expected to start and finish, from its crews and its queue as
## they stand today: {uid: {"start", "finish", "crew"}}, the first and the last working day;
## both -1 for a project no crew here can reach (none at the town, none coming). A crew's last busy
## day is tracked: one that ends its training or arrives works that same day. A shortage tomorrow
## can change it.
static func eta(sim: RefCounted, s: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var day: int = int(sim.state.day)
	var crews: Dictionary = sim.state.get("crews", {})
	var everywhere: bool = bool(crews.get("all_sites", false))
	var free_at: Array = []
	var ids: Array = []
	for team: Dictionary in crews.get("teams", []):
		var here: bool = int(team.region) == int(s.region)
		var coming: bool = str(team.task) == TRAVEL and int(team.target) == int(s.region)
		if str(team.task) == TRAVEL and not coming:
			continue
		if not here and not coming:
			continue
		var at: int = day
		if str(team.task) in [TRAVEL, TRAIN, FIELD]:
			at = maxi(day, int(team.until) - 1)
		elif str(team.task) == BUILD:
			var index: int = sim.Production.index_of(s, int(team.target))
			if index >= 0:
				at = day + int(s.buildings[index].remaining)
				result[int(team.target)] = {"start": day + 1, "finish": at, "crew": int(team.id)}
		elif str(team.task) in [ROAD, REPAIR]:
			var work: Dictionary = road_work(sim, _road(sim, int(team.target)))
			if not work.is_empty():
				at = day + int(work.remaining)
				result[road_key(int(team.target))] = {
					"start": day + 1, "finish": at, "crew": int(team.id)
				}
		free_at.append(at)
		ids.append(int(team.id))
	for b: Dictionary in s.get("buildings", []):
		var uid: int = int(b.get("uid", 0))
		if int(b.remaining) > 0 and (everywhere or bool(b.get("prefab", false))):
			result[uid] = {"start": day + 1, "finish": day + int(b.remaining), "crew": 0}
	if everywhere:
		return result
	for b: Dictionary in queue(sim, s, crews.get("working", {})):
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
	if str(team.task) == FIELD:
		return "这支工程队正在野外勘察，回来后才能派走"
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
	var cost: float = train_price(sim)
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
		match str(team.task):
			BUILD:
				var index: int = sim.Production.index_of(s, int(team.target))
				if index >= 0:
					var b: Dictionary = s.buildings[index]
					row.project = str(sim.config.buildings.get(b.kind, {}).get("name", b.kind))
					row.days_left = int(b.remaining)
			ROAD, REPAIR:
				var work: Dictionary = road_work(sim, _road(sim, int(team.target)))
				if not work.is_empty():
					row.project = str(work.name)
					row.days_left = int(work.remaining)
			FIELD:
				row.project = "实地勘察" if str(team.get("job", "")).begins_with("field") else "钻探"
				row.days_left = maxi(0, int(team.until) - int(sim.state.day))
		rows.append(row)
	var waiting: Dictionary = {}
	var urgent: Dictionary = {}
	var working: Dictionary = crews.get("working", {})
	for s: Dictionary in sim.state.get("settlements", []):
		var names: Array = []
		for b: Dictionary in queue(sim, s, working):
			if b.has("road"):
				names.append(str(b.name))
				continue
			names.append(str(sim.config.buildings.get(b.kind, {}).get("name", b.kind)))
			if fixes_shortage(sim, s, b):
				urgent[int(s.region)] = int(urgent.get(int(s.region), 0)) + 1
		if not names.is_empty():
			waiting[int(s.region)] = names
	var orders: Dictionary = {}
	for s: Dictionary in sim.state.get("settlements", []):
		orders[int(s.region)] = order_of(sim, int(s.region))
	return {
		"teams": rows,
		"waiting": waiting,
		"urgent": urgent,
		"orders": orders,
		"train_price": train_price(sim),
	}


## Checks for the audit: every crew where a crew can be, each town's count matching its teams.
static func audit(state: Dictionary) -> Array:
	var errors: Array = []
	if not state.has("crews"):
		return errors
	var counted: Dictionary = {}
	for team: Dictionary in state.crews.teams:
		if str(team.task) == TRAVEL:
			continue
		counted[int(team.region)] = int(counted.get(int(team.region), 0)) + 1
	for s: Dictionary in state.get("settlements", []):
		if int(s.get("crew", 0)) != int(counted.get(int(s.region), 0)):
			errors.append("crew count does not match its teams")
	return errors
