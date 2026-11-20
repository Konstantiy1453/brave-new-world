extends RefCounted
## The first shipments a player watches for (1.10), each a real consignment recorded when it moves:
## - "ore": the first mined ore (iron, copper or crystal) a town's mine sends by truck to the town's
##   cargo station and sells: the town, the mine, the good, the tonnes and what it fetched;
## - "ship": the first cargo a ship lands or loads at a working harbour: the town, the harbour, in
##   or out, the good, the tonnes and its value.
## They are kept in `state.firsts`. Each town with a harbour also keeps its latest sea cargo
## (`sea_cargo`): the maps sail a ship to a harbour only while it has one. The notice, the vehicle
## and the town the notice opens all read these records, so they agree, whichever town it is.

const Keys = preload("res://simulation/keys.gd")
const Bay = preload("res://simulation/bay.gd")
const OperatingRoutes = preload("res://simulation/operating_routes.gd")

const MINED: Array[String] = ["ore", "copper", "crystal"]
const VEHICLES: Dictionary = {"ore": "矿车", "ship": "货船"}


## Saves from before the records: what the colony has evidently done already counts as announced
## (`legacy`), so loading one does not announce a first that happened long ago.
static func ensure_state(state: Dictionary) -> void:
	if state.has("firsts"):
		return
	state.firsts = {}
	var sold: Dictionary = state.get("market", {}).get("saturation", {})
	for good: String in MINED:
		if float(sold.get(good, 0.0)) > 0.0:
			state.firsts.ore = {"legacy": true}
	for s: Dictionary in state.get("settlements", []):
		for b: Dictionary in s.get("buildings", []):
			if str(b.get("kind", "")) == "harbor" and int(b.get("remaining", 0)) <= 0:
				state.firsts.ship = {"legacy": true}


## A town's cargo station sold `amount` of `good` for `value`.
static func exported(
	sim: RefCounted, s: Dictionary, good: String, amount: float, value: float
) -> void:
	if amount <= 0.0:
		return
	ensure_state(sim.state)
	if good in MINED:
		_ore(sim, s, good, amount, value)
	_by_sea(sim, s, "export", good, amount, value)


## A truckload of ore: from the selling town's own mine, or from a linked town's mine whose ore came
## in by road. The mine's town keeps it as its latest ore cargo (`ore_cargo`): the district runs a
## truck from that mine to the cargo station while it is recent. The first is the colony's first
## truckload. Ore with no mine behind it (a gift, a salvage) is not a truckload.
static func _ore(sim: RefCounted, s: Dictionary, good: String, amount: float, value: float) -> void:
	var origin: Dictionary = s
	var mine: Dictionary = _mine_for(sim, s, good)
	if mine.is_empty():
		for other: Dictionary in sim.state.settlements:
			if int(other.region) == int(s.region) or not _linked(sim, other, s):
				continue
			mine = _mine_for(sim, other, good)
			if not mine.is_empty():
				origin = other
				break
	if mine.is_empty():
		return
	origin.ore_cargo = {
		"day": int(sim.state.day),
		"building": int(mine.get("uid", 0)),
		"resource": good,
		"amount": amount,
		"value": value,
		"sold_at": int(s.region),
	}
	if sim.state.firsts.has("ore"):
		return
	var entry: Dictionary = _record(sim, origin, mine, "export", good, amount, value, "ore")
	entry.sold_at = int(s.region)
	entry.sold_town = str(s.name)
	sim.state.firsts.ore = entry
	var via: String = "" if origin == s else "，经公路运到「%s」" % s.name
	sim._log(
		(
			"%s · 第一车矿石：%s的 %.0f 吨%s%s，在货运站卖出 ¥ %.0f。"
			% [
				origin.name,
				_building_name(sim, mine),
				sim.tonnes(amount),
				_good_name(sim, good),
				via,
				value
			]
		)
	)


static func _linked(sim: RefCounted, a: Dictionary, b: Dictionary) -> bool:
	for road: Dictionary in sim.state.get("roads", []):
		if bool(road.get("retired", false)):
			continue
		var ends: Array = [int(road.a), int(road.b)]
		if ends.has(int(a.region)) and ends.has(int(b.region)):
			return true
	return false


## A town's cargo station bought `amount` of `good` for `value`.
static func imported(
	sim: RefCounted, s: Dictionary, good: String, amount: float, value: float
) -> void:
	if amount <= 0.0:
		return
	_by_sea(sim, s, "import", good, amount, value)


## Cargo through a working harbour goes by ship: the town keeps it as its latest sea cargo, and the
## first such cargo anywhere is the colony's first ship.
static func _by_sea(
	sim: RefCounted, s: Dictionary, direction: String, good: String, amount: float, value: float
) -> void:
	var harbour: Dictionary = _harbour(sim, s)
	if harbour.is_empty():
		return
	ensure_state(sim.state)
	# Stage three's coastal trade counts what is sold abroad by sea, not the everyday imports.
	if direction == "export":
		OperatingRoutes.add(sim, "sea_cargo", amount)
	s.sea_cargo = {
		"day": int(sim.state.day),
		"direction": direction,
		"resource": good,
		"amount": amount,
		"value": value,
	}
	if sim.state.firsts.has("ship"):
		return
	sim.state.firsts.ship = _record(sim, s, harbour, direction, good, amount, value, "ship")
	(
		sim
		. _log(
			(
				"%s · 第一艘货船靠上新码头：%s %.0f 吨%s（¥ %.0f）。"
				% [
					s.name,
					"卸下" if direction == "import" else "装走",
					sim.tonnes(amount),
					_good_name(sim, good),
					value,
				]
			)
		)
	)


static func _record(
	sim: RefCounted,
	s: Dictionary,
	building: Dictionary,
	direction: String,
	good: String,
	amount: float,
	value: float,
	kind: String
) -> Dictionary:
	return {
		"day": int(sim.state.day),
		"region": int(s.region),
		"town": str(s.name),
		"building": int(building.get("uid", 0)),
		"building_kind": str(building.kind),
		"direction": direction,
		"resource": good,
		"amount": amount,
		"value": value,
		"vehicle": str(VEHICLES[kind]),
	}


## The town's oldest finished mine of a good.
static func _mine_for(sim: RefCounted, s: Dictionary, good: String) -> Dictionary:
	for b: Dictionary in s.get("buildings", []):
		var spec: Dictionary = sim.config.buildings.get(str(b.kind), {})
		if str(spec.get("role", "")) != "mine" or int(b.remaining) > 0:
			continue
		if str(spec.get("output", "")) == good:
			return b
	return {}


static func _harbour(sim: RefCounted, s: Dictionary) -> Dictionary:
	if not Bay.harbor_working(sim, s):
		return {}
	for b: Dictionary in s.get("buildings", []):
		if str(sim.config.buildings.get(str(b.kind), {}).get("role", "")) == "harbor":
			if int(b.remaining) <= 0 and bool(b.get("active", false)):
				return b
	return {}


static func _building_name(sim: RefCounted, b: Dictionary) -> String:
	return str(sim.config.buildings.get(str(b.kind), {}).get("name", str(b.kind)))


static func _good_name(sim: RefCounted, good: String) -> String:
	return str(sim.config.resources.get(good, good))


## Whether a ship calls at a town: its harbour has had sea cargo within the bay rules'
## `ship_call_days`, or freight is under way on one of its sea links.
static func ship_calling(state: Dictionary, s: Dictionary, call_days: int) -> bool:
	var day: int = int(state.get("day", 0))
	var cargo: Dictionary = s.get("sea_cargo", {})
	if not cargo.is_empty() and day - int(cargo.get("day", -999999)) <= call_days:
		return true
	var roads: Array = state.get("roads", [])
	for shipment: Dictionary in state.get("shipments", []):
		var road: int = int(shipment.get("road", -1))
		if road < 0 or road >= roads.size() or str(roads[road].get("variant", "")) != "sea":
			continue
		if (
			int(shipment.get("from", -1)) == int(s.region)
			or int(shipment.get("to", -1)) == int(s.region)
		):
			return true
	return false


## The mine whose ore a town's trucks carry to its cargo station: its uid while the town has sold ore
## within `call_days`, else 0.
static func ore_run(state: Dictionary, s: Dictionary, call_days: int) -> int:
	var cargo: Dictionary = s.get("ore_cargo", {})
	if cargo.is_empty() or int(state.get("day", 0)) - int(cargo.get("day", -999999)) > call_days:
		return 0
	return int(cargo.get("building", 0))


## Records refer to towns that exist.
static func audit(state: Dictionary) -> Array:
	var errors: Array = []
	for kind: String in state.get("firsts", {}):
		var entry: Dictionary = state.firsts[kind]
		if bool(entry.get("legacy", false)):
			continue
		var found: bool = false
		for s: Dictionary in state.get("settlements", []):
			found = found or int(s.region) == int(entry.get("region", -1))
		if not found:
			errors.append("first %s recorded at a town that does not exist" % kind)
	return errors
