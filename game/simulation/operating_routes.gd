extends RefCounted
## Stage three's operating routes (1.10, the November 20 brief): the contract's network stage is
## met by a colony that works as a network in any one of three ways, measured over the last 30 days
## (contract.json `routes`, windows `routes`):
## - a food corridor: food carried between towns by road or sea, with the colony growing most of
##   what it eats;
## - a remote mining network: ore, copper and crystal mined in towns other than the capital, in at
##   least two of them;
## - a coastal trade network: cargo carried between towns on sea links and sold abroad through
##   working harbours (not the everyday imports), with at least two coastal towns in it.
## 600 people is an achievement of its own with a reward (`achievements`), no longer a condition.
## The flows are recorded as they happen (logistics, production, consignments) and kept as daily
## windows in `state.contract.route_windows`.

const KEYS: Array[String] = ["food_moved", "remote_mined", "sea_cargo"]
const MINED: Array[String] = ["ore", "copper", "crystal", "nickel", "cobalt"]


static func ensure_state(state: Dictionary) -> void:
	var contract: Dictionary = state.get("contract", {})
	if contract.is_empty():
		return
	if not contract.has("route_windows"):
		contract.route_windows = {"food_moved": [], "remote_mined": [], "sea_cargo": []}
	if not contract.has("route_today"):
		contract.route_today = {"food_moved": 0.0, "remote_mined": 0.0, "sea_cargo": 0.0}
	if not contract.has("achievements"):
		contract.achievements = {}


## Adds today's flow of one kind (goods units).
static func add(sim: RefCounted, key: String, amount: float) -> void:
	if amount <= 0.0:
		return
	ensure_state(sim.state)
	var today: Dictionary = sim.state.contract.route_today
	today[key] = float(today.get(key, 0.0)) + amount


## Closes the day: each flow joins its window.
static func close_day(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var contract: Dictionary = sim.state.contract
	var keep: int = int(sim.contract_rules.windows.get("routes", 30))
	for key: String in KEYS:
		var window: Array = contract.route_windows[key]
		window.append(float(contract.route_today.get(key, 0.0)))
		contract.route_today[key] = 0.0
		while window.size() > keep:
			window.pop_front()


static func total(sim: RefCounted, key: String) -> float:
	var sum: float = 0.0
	for value: Variant in sim.state.contract.get("route_windows", {}).get(key, []):
		sum += float(value)
	return sum


## Towns on the sea: a working harbour, or a finished sea link.
static func coastal_towns(sim: RefCounted) -> int:
	var count: int = 0
	var buildings: Dictionary = sim.config.buildings
	for s: Dictionary in sim.state.settlements:
		var on_sea: bool = sim.Bay.harbor_working(sim, s)
		for road: Dictionary in sim.state.get("roads", []):
			if str(road.get("variant", "")) != "sea" or bool(road.get("retired", false)):
				continue
			if int(road.get("ready_day", 0)) >= int(sim.state.day):
				continue
			if int(road.a) == int(s.region) or int(road.b) == int(s.region):
				on_sea = true
		if on_sea and not buildings.is_empty():
			count += 1
	return count


## Towns other than the capital with a working mine.
static func mining_towns(sim: RefCounted) -> int:
	var count: int = 0
	for index: int in range(1, sim.state.settlements.size()):
		var s: Dictionary = sim.state.settlements[index]
		for b: Dictionary in s.buildings:
			var spec: Dictionary = sim.config.buildings.get(str(b.kind), {})
			if str(spec.get("role", "")) == "mine" and bool(b.get("active", false)):
				count += 1
				break
	return count


## Each route with its measures against its targets: [{id, name, ok, parts: [{label, value,
## target, ok}]}]. Values in goods units over the window, shares as fractions.
static func view(sim: RefCounted) -> Array:
	var rules: Dictionary = sim.contract_rules.get("routes", {})
	var days: int = sim.state.contract.get("route_windows", {}).get("food_moved", []).size()
	var full: bool = days >= int(sim.contract_rules.windows.get("routes", 30))
	var rows: Array = []
	for id: String in rules:
		var rule: Dictionary = rules[id]
		var parts: Array = []
		match id:
			"food_corridor":
				parts.append(_part("城际运粮", total(sim, "food_moved"), float(rule.food_moved), full))
				parts.append(
					_part(
						"本地粮食占比",
						sim.Contract.local_food_share(sim),
						float(rule.local_food_share),
						true
					)
				)
			"mining_network":
				parts.append(
					_part("首府以外的矿产", total(sim, "remote_mined"), float(rule.remote_mined), full)
				)
				parts.append(
					_part("采矿据点", float(mining_towns(sim)), float(rule.mining_towns), true)
				)
			"coastal_trade":
				parts.append(_part("海运货物", total(sim, "sea_cargo"), float(rule.sea_cargo), full))
				parts.append(
					_part("沿海据点", float(coastal_towns(sim)), float(rule.coastal_towns), true)
				)
		var ok: bool = true
		for part: Dictionary in parts:
			ok = ok and bool(part.ok)
		rows.append({"id": id, "name": str(rule.name), "ok": ok, "parts": parts})
	return rows


static func _part(label: String, value: float, target: float, counted: bool) -> Dictionary:
	return {"label": label, "value": value, "target": target, "ok": counted and value >= target}


## 1 when any route works, else 0: the stage goal `operating_route`.
static func operating(sim: RefCounted) -> float:
	for row: Dictionary in view(sim):
		if bool(row.ok):
			return 1.0
	return 0.0


## Achievements the contract rewards beyond its stages (600 people): paid once, the day they are
## reached, whatever the stage.
static func check_achievements(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var reached: Dictionary = sim.state.contract.achievements
	for rule: Dictionary in sim.contract_rules.get("achievements", []):
		if reached.has(str(rule.id)):
			continue
		if sim.Contract.goal_value(sim, str(rule.goal)) < float(rule.target):
			continue
		reached[str(rule.id)] = int(sim.state.day)
		if float(rule.reward_cash) > 0.0:
			sim._transfer(
				"external",
				"public",
				float(rule.reward_cash),
				"contract.reward",
				false,
				str(rule.id)
			)
		sim._log("合同成就「%s」达成，公司奖励 %.0f。" % [str(rule.name), float(rule.reward_cash)])
