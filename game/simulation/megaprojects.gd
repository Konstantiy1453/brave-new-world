extends RefCounted
## Megaprojects: long builds, large costs, effects the whole colony can feel. Each is an ordinary
## building marked `megaproject` in economy.json; numbers live under `megaprojects` in the same file.
## The late great works of 1.9 (terraforming, capital district, exchange, shipyard, emergency
## network) add to colony-wide effects the way technologies do; two of them grow by levels.

const KINDS: Array[String] = [
	"university",
	"lift_port",
	"climate_regulator",
	"capital_hall",
	"terraforming",
	"capital_district",
	"exchange",
	"shipyard",
	"emergency_net",
]
## Reserved key in the day's effect totals: the terraforming stages finished.
const STAGES_KEY: String = "_terraforming_stages"


## The settlement holding a finished, enabled copy of this megaproject, or an empty dictionary.
static func host(sim: RefCounted, kind: String) -> Dictionary:
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if b.kind == kind and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
				return s
	return {}


static func active(sim: RefCounted, kind: String) -> bool:
	return not host(sim, kind).is_empty()


## The level of a finished, enabled great work (stages, district levels), 0 when there is none.
## An upgrade under way counts at the level already finished.
static func level(sim: RefCounted, kind: String) -> int:
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if b.kind == kind and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
				return int(b.get("level", 1))
	return 0


## What the great works add to one colony-wide effect, as a fraction, the way technologies do:
## each finished work's `effects` times its level. Computed once a day.
static func effect(sim: RefCounted, key: String) -> float:
	if (
		int(sim.great_effects_day) != int(sim.state.day)
		or not is_same(sim.great_effects_state, sim.state)
	):
		var totals: Dictionary = {}
		for kind: String in KINDS:
			var effects: Dictionary = sim.config.megaprojects.get(kind, {}).get("effects", {})
			if effects.is_empty():
				continue
			var at: int = level(sim, kind)
			for name: String in effects:
				totals[name] = float(totals.get(name, 0.0)) + float(effects[name]) * at
		totals[STAGES_KEY] = float(level(sim, "terraforming"))
		sim.great_effects = totals
		sim.great_effects_day = int(sim.state.day)
		sim.great_effects_state = sim.state
	return float(sim.great_effects.get(key, 0.0))


static func terraforming_stages(sim: RefCounted) -> int:
	return int(effect(sim, STAGES_KEY))


## Farm fertility the terraforming programme has added, planet-wide.
static func fertility_bonus(sim: RefCounted) -> float:
	var rules: Dictionary = sim.config.megaprojects.get("terraforming", {})
	return float(rules.get("fertility_step", 0.0)) * terraforming_stages(sim)


## Beds the capital district adds to the settlement it stands in.
static func district_beds(sim: RefCounted, s: Dictionary) -> int:
	return int(sim.config.megaprojects.capital_district.beds) * _district_level_at(s)


## Attractiveness the capital district adds to the settlement it stands in.
static func district_appeal(sim: RefCounted, s: Dictionary) -> float:
	return float(sim.config.megaprojects.capital_district.appeal) * _district_level_at(s)


static func _district_level_at(s: Dictionary) -> int:
	for b: Dictionary in s.buildings:
		if b.kind == "capital_district" and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
			return int(b.get("level", 1))
	return 0


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


## Climate change at the region at this index: near a finished regulator, and planet-wide for
## every terraforming stage (temperature toward the comfortable band, more rain).
static func climate(sim: RefCounted, region: int) -> Dictionary:
	var shift: Dictionary = {"temperature": 0.0, "rainfall": 1.0}
	var here: Dictionary = sim.state.world.regions[region]
	var at: Dictionary = host(sim, "climate_regulator")
	if not at.is_empty():
		var rules: Dictionary = sim.config.megaprojects.climate_regulator
		var there: Dictionary = sim.state.world.regions[int(at.region)]
		if _angle(here, there) <= float(rules.radius_degrees):
			shift = {"temperature": float(rules.temperature), "rainfall": float(rules.rainfall)}
	var stages: int = terraforming_stages(sim)
	if stages > 0:
		var terra: Dictionary = sim.config.megaprojects.terraforming
		var gap: float = (
			float(terra.comfort_temperature) - float(here.temperature) - float(shift.temperature)
		)
		var step: float = float(terra.temperature_step) * stages
		shift.temperature = float(shift.temperature) + clampf(gap, -step, step)
		shift.rainfall = float(shift.rainfall) * pow(1.0 + float(terra.rainfall_step), stages)
	return shift


static func _angle(a: Dictionary, b: Dictionary) -> float:
	return rad_to_deg(_unit(float(a.lat), float(a.lon)).angle_to(_unit(float(b.lat), float(b.lon))))


static func _unit(lat: float, lon: float) -> Vector3:
	var a: float = deg_to_rad(lat)
	var b: float = deg_to_rad(lon)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))
