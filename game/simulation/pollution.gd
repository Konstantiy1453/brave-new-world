extends RefCounted
## Planet-wide pollution. A planet swallows what a few towns emit; only what outruns its absorption
## piles up, and the penalty grows exponentially with the pile. It hurts output, appeal and the
## health bill. The company does not hold it against anyone. Numbers: `pollution` in progression.json.

const Keys = preload("res://simulation/keys.gd")
const Research = preload("res://simulation/research.gd")

## Worlds from before planets had their true size count as a medium planet.
const SMALL_OLD_WORLD_KM: float = 2000.0


static func ensure_state(state: Dictionary) -> void:
	if not state.has("pollution"):
		state.pollution = {"load": 0.0, "emitted": 0.0, "absorbed": 0.0, "stage": 0}


static func _rules(sim: RefCounted) -> Dictionary:
	return sim.progression.pollution


## Surface area against the reference planet: a big planet takes more before it shows.
static func area(sim: RefCounted) -> float:
	var radius: float = float(sim.state.world.get("radius_km", 0.0))
	if radius < SMALL_OLD_WORLD_KM:
		return 1.0
	var ratio: float = radius / float(_rules(sim).reference_radius_km)
	return ratio * ratio


## What the planet and the colony's green works take out of the air each day.
static func absorption(sim: RefCounted) -> float:
	var natural: float = (
		float(_rules(sim).absorption_per_day)
		* area(sim)
		* (1.0 + Research.bonus(sim, "absorption"))
	)
	var built: float = 0.0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if not bool(b.get("active", false)):
				continue
			built += float(sim.config.buildings.get(b.kind, {}).get("absorb", 0.0))
	return natural + built


static func emission(sim: RefCounted) -> float:
	var total: float = 0.0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if not bool(b.get("active", false)):
				continue
			total += (
				float(sim.config.buildings.get(b.kind, {}).get("pollution", 0.0))
				* float(b.get("efficiency", 0.0))
			)
	return total * maxf(0.1, 1.0 + Research.bonus(sim, "pollution"))


## Share of output lost: a(e^x - 1), tiny for a long time, then all at once.
static func penalty(sim: RefCounted) -> float:
	var rules: Dictionary = _rules(sim)
	# A larger planet dilutes the same pile, though less than it out-absorbs it.
	var x: float = float(sim.state.pollution.load) / (float(rules.scale) * sqrt(area(sim)))
	return clampf(float(rules.strength) * (exp(x) - 1.0), 0.0, float(rules.cap))


static func factor(sim: RefCounted) -> float:
	return 1.0 - penalty(sim)


static func stage(sim: RefCounted) -> int:
	var value: float = penalty(sim)
	var reached: int = 0
	for threshold: Variant in _rules(sim).stages:
		if value >= float(threshold):
			reached += 1
	return reached


static func daily(sim: RefCounted) -> void:
	var p: Dictionary = sim.state.pollution
	var out: float = emission(sim)
	var taken: float = absorption(sim)
	p.emitted = out
	p.absorbed = taken
	p.load = maxf(0.0, float(p.load) + out - taken)
	var loss: float = penalty(sim)
	if loss >= float(_rules(sim).notice):
		var bill: float = 0.0
		for s: Dictionary in sim.state.settlements:
			bill += float(s.population) * float(_rules(sim).health_per_person) * loss
			sim._short(s, Keys.SH_POLLUTION)
		sim._public_expense(bill, "company.health", "external")
	var now: int = stage(sim)
	if now > int(p.stage):
		p.stage = now
		sim._log(
			"污染开始显出后果：产出损失约 %.0f%%。净化塔、清洁技术和治理都能把它压下去。" % (loss * 100.0)
		)
		_outbreak(sim, now)
	elif now < int(p.stage):
		p.stage = now


static func _outbreak(sim: RefCounted, reached: int) -> void:
	if sim.state.settlements.is_empty():
		return
	var ids: Array = ["smog_season", "acid_rain", "dead_bay"]
	var home: int = int(sim.state.settlements[0].region)
	var index: int = clampi(reached - 1, 0, ids.size() - 1)
	sim.EventsV2.trigger(sim, str(ids[index]), home)


## An event or accident adds this many points; one point is `event_load_per_point` of load.
static func add_points(sim: RefCounted, points: float) -> void:
	var p: Dictionary = sim.state.pollution
	p.load = maxf(0.0, float(p.load) + points * float(_rules(sim).event_load_per_point))


static func cleanup_cost(sim: RefCounted) -> float:
	return (
		float(sim.progression.production.cleanup_cost)
		* maxf(0.1, 1.0 + Research.bonus(sim, "cleanup_cost"))
	)


static func cleanup(sim: RefCounted) -> String:
	var cost: float = cleanup_cost(sim)
	if float(sim.state.pollution.load) <= 0.0:
		return "现在没有需要治理的污染"
	if float(sim.state.cash) < cost:
		return "治理需要 %.0f 资金" % cost
	sim._transfer("public", "external", cost, "company.cleanup", false)
	var p: Dictionary = sim.state.pollution
	p.load = maxf(0.0, float(p.load) - float(sim.progression.production.cleanup_amount))
	return ""


static func view(sim: RefCounted) -> Dictionary:
	var p: Dictionary = sim.state.pollution
	return {
		"load": float(p.load),
		"emitted": float(p.emitted),
		"absorbed": float(p.absorbed),
		"penalty": penalty(sim),
		"stage": stage(sim),
		"cleanup_cost": cleanup_cost(sim),
		"cleanup_amount": float(sim.progression.production.cleanup_amount),
	}
