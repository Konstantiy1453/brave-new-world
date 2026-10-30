extends RefCounted
## Tier 3 megaprojects: long builds, large costs, effects the whole colony can feel.
## Each is an ordinary building marked `megaproject` in economy.json; numbers live under
## `megaprojects` in the same file.

const KINDS: Array[String] = ["university", "lift_port", "climate_regulator"]


## The settlement holding a finished, enabled copy of this megaproject, or an empty dictionary.
static func host(sim: RefCounted, kind: String) -> Dictionary:
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if b.kind == kind and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
				return s
	return {}


static func active(sim: RefCounted, kind: String) -> bool:
	return not host(sim, kind).is_empty()


static func count(sim: RefCounted) -> int:
	var total: int = 0
	for kind: String in KINDS:
		if active(sim, kind):
			total += 1
	return total


static func research_factor(sim: RefCounted) -> float:
	return float(sim.config.megaprojects.university.research) if active(sim, "university") else 1.0


static func scientist_share_bonus(sim: RefCounted) -> float:
	return (
		float(sim.config.megaprojects.university.scientist_share)
		if active(sim, "university")
		else 0.0
	)


static func export_factor(sim: RefCounted) -> float:
	return (
		float(sim.config.megaprojects.lift_port.export_price) if active(sim, "lift_port") else 1.0
	)


static func port_factor(sim: RefCounted, s: Dictionary) -> float:
	var at: Dictionary = host(sim, "lift_port")
	if at.is_empty() or int(at.region) != int(s.region):
		return 1.0
	return float(sim.config.megaprojects.lift_port.port)


## Local climate change near a finished regulator, for the region at this index.
static func climate(sim: RefCounted, region: int) -> Dictionary:
	var at: Dictionary = host(sim, "climate_regulator")
	if at.is_empty():
		return {"temperature": 0.0, "rainfall": 1.0}
	var rules: Dictionary = sim.config.megaprojects.climate_regulator
	var here: Dictionary = sim.state.world.regions[region]
	var there: Dictionary = sim.state.world.regions[int(at.region)]
	if _angle(here, there) > float(rules.radius_degrees):
		return {"temperature": 0.0, "rainfall": 1.0}
	return {"temperature": float(rules.temperature), "rainfall": float(rules.rainfall)}


static func _angle(a: Dictionary, b: Dictionary) -> float:
	return rad_to_deg(_unit(float(a.lat), float(a.lon)).angle_to(_unit(float(b.lat), float(b.lon))))


static func _unit(lat: float, lon: float) -> Vector3:
	var a: float = deg_to_rad(lat)
	var b: float = deg_to_rad(lon)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))
