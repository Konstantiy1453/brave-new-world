extends RefCounted
## The workers on a shuttle keep their beds and consume food in their home settlement.
## A building's commuter map records each home and its workers on this shift.

const Keys = preload("res://simulation/keys.gd")


static func seats(sim: RefCounted) -> int:
	return int(sim.Research.bonus(sim, "shuttle_seats"))


static func begin_day(sim: RefCounted) -> Dictionary:
	var pool: Dictionary = {}
	var capacity: int = seats(sim)
	if capacity <= 0:
		return pool
	for home: Dictionary in sim.state.settlements:
		home.commute_out = 0
		home.commute_in = 0
		for building: Dictionary in home.buildings:
			building.erase("commuters")
		if int(home.arrival) > 0 or str(home.kind) != Keys.SITE_RESIDENTIAL:
			continue
		var available: int = mini(capacity, sim.Production.free_workers(sim, home))
		if available > 0:
			pool[int(home.region)] = {"reserved": available, "left": available, "home": home}
	return pool


static func assign(pool: Dictionary, work: Dictionary, building: Dictionary, vacant: int) -> int:
	if vacant <= 0:
		return 0
	var filled: int = 0
	for region: int in pool:
		if region == int(work.region):
			continue
		var source: Dictionary = pool[region]
		var count: int = mini(vacant - filled, int(source.left))
		if count <= 0:
			continue
		if not building.has("commuters"):
			building.commuters = {}
		building.commuters[str(region)] = count
		source.left = int(source.left) - count
		source.home.commute_out = int(source.home.commute_out) + count
		work.commute_in = int(work.commute_in) + count
		filled += count
		if filled == vacant:
			break
	return filled


static func finish_day(pool: Dictionary) -> void:
	for source: Dictionary in pool.values():
		var home: Dictionary = source.home
		home.employed_workers = int(home.employed_workers) + int(home.commute_out)
		home.employed = int(home.employed) + int(home.commute_out)


static func visitors(building: Dictionary) -> int:
	var total: int = 0
	for count: int in building.get("commuters", {}).values():
		total += count
	return total


## Reconcile assignments when a worker leaves the workforce during today's shift.
static func trim_outgoing(sim: RefCounted, home: Dictionary, available: int) -> void:
	var excess: int = int(home.get("commute_out", 0)) - available
	if excess <= 0:
		return
	var key: String = str(home.region)
	for work: Dictionary in sim.state.settlements:
		for building: Dictionary in work.buildings:
			var riders: Dictionary = building.get("commuters", {})
			var count: int = mini(excess, int(riders.get(key, 0)))
			if count <= 0:
				continue
			riders[key] = int(riders[key]) - count
			if riders[key] == 0:
				riders.erase(key)
			work.commute_in = int(work.commute_in) - count
			home.commute_out = int(home.commute_out) - count
			excess -= count
			if excess == 0:
				return


## Closing a workplace ends its shifts immediately, including its visitors' jobs.
static func release(sim: RefCounted, work: Dictionary, building: Dictionary) -> void:
	var riders: Dictionary = building.get("commuters", {})
	for key: String in riders:
		var home: Dictionary = sim.settlement(int(key))
		var count: int = int(riders[key])
		home.commute_out = int(home.commute_out) - count
		home.employed_workers = int(home.employed_workers) - count
		home.employed = int(home.employed) - count
		work.commute_in = int(work.commute_in) - count
	building.erase("commuters")


static func vacancies(s: Dictionary) -> int:
	var at_work: int = int(s.employed) - int(s.get("commute_out", 0)) + int(s.get("commute_in", 0))
	return maxi(0, int(s.jobs) - at_work)


## Route counts shown at either end, from the workers actually assigned to facilities today.
static func routes(sim: RefCounted, region: int) -> PackedStringArray:
	var rows: PackedStringArray = []
	for work: Dictionary in sim.state.settlements:
		var by_home: Dictionary = {}
		for building: Dictionary in work.buildings:
			var riders: Dictionary = building.get("commuters", {})
			for key: String in riders:
				if int(work.region) == region or int(key) == region:
					by_home[key] = int(by_home.get(key, 0)) + int(riders[key])
		for key: String in by_home:
			rows.append("%s → %s　%d 人" % [sim.settlement(int(key)).name, work.name, by_home[key]])
	return rows


static func validate(_sim: RefCounted, state: Dictionary) -> String:
	var sent: Dictionary = {}
	for work: Dictionary in state.settlements:
		var received: int = 0
		for building: Dictionary in work.buildings:
			var riders: Variant = building.get("commuters", {})
			if not riders is Dictionary:
				return "通勤班次无效"
			for key: Variant in riders:
				if not key is String or not key.is_valid_int() or str(int(key)) != key or int(key) == int(work.region):
					return "通勤出发据点无效"
				if not riders[key] is int or int(riders[key]) <= 0:
					return "通勤人数无效"
				received += int(riders[key])
				sent[key] = int(sent.get(key, 0)) + int(riders[key])
		if not work.get("commute_in", 0) is int or work.get("commute_in", 0) != received:
			return "通勤到达人数不符"
	for home: Dictionary in state.settlements:
		var key: String = str(home.region)
		var assigned: int = int(sent.get(key, 0))
		if not home.get("commute_out", 0) is int or home.get("commute_out", 0) != assigned or assigned > int(home.employed_workers):
			return "通勤出发人数不符"
		if assigned > 0 and str(home.kind) != Keys.SITE_RESIDENTIAL:
			return "通勤出发据点须为居住据点"
		sent.erase(key)
	return "" if sent.is_empty() else "通勤出发据点不存在"
