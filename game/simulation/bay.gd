extends RefCounted
## The bay (1.10 plan C): what a coastal landing offers its one crew.
## - A deposit beyond the town's haul reach needs a mine road before a mine there can ship ore. The
##   road is built with the mine, by the same crew: its days and cost rise with the distance.
## - A small harbour (小型码头) lands fish and takes sea freight, so food and building stock come in
##   cheaper than by orbit, and it is the base for surveying the offshore signal. It stays useful
##   when the signal turns out poor.
## - Each coastal town has one offshore signal, a promising but uncertain mineral reading fixed by
##   the seed: a survey from a working harbour tells whether it is rich, for later development.
## Every number is in economy.json `bay`; the harbour is the building `harbor`.

const Features = preload("res://simulation/features.gd")
const Keys = preload("res://simulation/keys.gd")

## Days of imports a harbour's forecast looks back over.
const SAVINGS_WINDOW: int = 30
const SIGNAL_GOODS: Array[String] = ["copper", "crystal"]


static func rules(sim: RefCounted) -> Dictionary:
	return sim.config.get("bay", {})


## The extra days and cost a mine's road adds on a plot beyond the haul reach: {days, cost, units}.
## A road already built to one of the town's mines carries the next: from the nearest of them only
## the spur is built, if that is shorter than the way from the edge of the reach.
static func haul(sim: RefCounted, region: int, plot: int) -> Dictionary:
	var rule: Dictionary = rules(sim)
	var plots: Array = sim.state.world.regions[region].get("plots", [])
	if rule.is_empty() or plot < 0 or plot >= plots.size():
		return {"days": 0, "cost": 0.0, "units": 0.0}
	var at := Vector2(float(plots[plot].x), float(plots[plot].z))
	var beyond: float = maxf(0.0, at.length() - float(rule.haul_reach))
	# The mine whose road this one would branch from (its uid), 0 for a road from the town's edge.
	var via: int = 0
	for b: Dictionary in sim.settlement(region).get("buildings", []):
		var index: int = int(b.get("plot", -1))
		if index < 0 or index >= plots.size() or index == plot:
			continue
		if str(sim.config.buildings.get(str(b.kind), {}).get("role", "")) != "mine":
			continue
		var spur: float = at.distance_to(Vector2(float(plots[index].x), float(plots[index].z)))
		if spur < beyond:
			beyond = spur
			via = int(b.get("uid", 0))
	if beyond <= 0.0:
		return {"days": 0, "cost": 0.0, "units": 0.0, "via": 0}
	return {
		"days": ceili(beyond * float(rule.haul_days_per_unit)),
		"cost": beyond * float(rule.haul_cost_per_unit),
		"units": beyond,
		"via": via,
	}


## A mine cancelled before it was finished takes its unbuilt road with it: a mine ordered to branch
## off that road builds the main road itself. Its days grow by the difference; the road money the
## cancelled mine had paid covers the extra cost first, and the rest is charged now.
static func reroute(sim: RefCounted, s: Dictionary, gone: Dictionary) -> void:
	var uid: int = int(gone.get("uid", 0))
	if uid <= 0 or int(gone.get("remaining", 0)) <= 0:
		return
	var budget: float = float(gone.get("haul", {}).get("cost", 0.0))
	for b: Dictionary in s.get("buildings", []):
		var before: Dictionary = b.get("haul", {})
		if int(before.get("via", 0)) != uid or int(b.remaining) <= 0:
			continue
		var fresh: Dictionary = haul(sim, int(s.region), int(b.get("plot", -1)))
		var extra_days: int = maxi(0, int(fresh.days) - int(before.get("days", 0)))
		var extra_cost: float = maxf(0.0, float(fresh.cost) - float(before.get("cost", 0.0)))
		var covered: float = minf(budget, extra_cost)
		budget -= covered
		var charged: float = sim._transfer(
			"public", "external", extra_cost - covered, "invest.build", false, str(b.kind)
		)
		b.remaining = int(b.remaining) + extra_days
		b.total_days = int(b.get("total_days", 0)) + extra_days
		b.haul = fresh
		var name: String = str(sim.config.buildings.get(str(b.kind), {}).get("name", b.kind))
		sim._log(
			(
				"%s · 原定接在被取消的矿场道路上的%s改修自己的矿区道路：工期 +%d 天，费用 +¥%.0f（其中 ¥%.0f 由已付的道路款抵扣，补交 ¥%.0f）。"
				% [s.name, name, extra_days, extra_cost, covered, charged]
			)
		)


## What sea freight would save this town a day on what it imports now: the discount on its share
## (by people) of the colony's food, materials and parts imports over the last 30 days. Only reads.
static func sea_savings(sim: RefCounted, s: Dictionary) -> float:
	var rule: Dictionary = rules(sim)
	if rule.is_empty() or s.is_empty():
		return 0.0
	var window: Dictionary = sim.stats_window(SAVINGS_WINDOW)
	var spent: float = 0.0
	for key: String in ["import.food", "import.stock"]:
		spent += float(window.get("expense", {}).get(key, 0.0))
	var days: float = maxf(1.0, float(window.get("days", SAVINGS_WINDOW)))
	var people: float = maxf(1.0, float(sim.Contract.population_total(sim)))
	return float(rule.sea_discount) * spent / days * minf(1.0, float(s.population) / people)


## A town with a working harbour.
static func harbor_working(sim: RefCounted, s: Dictionary) -> bool:
	for b: Dictionary in s.get("buildings", []):
		if str(sim.config.buildings.get(b.kind, {}).get("role", "")) != "harbor":
			continue
		if int(b.remaining) <= 0 and bool(b.get("active", false)):
			return true
	return false


## What sea freight saves on an import at this town: a share of the price, 0 without a harbour.
static func sea_discount(sim: RefCounted, s: Dictionary, good: String) -> float:
	var rule: Dictionary = rules(sim)
	if rule.is_empty() or not good in rule.get("sea_goods", []):
		return 0.0
	return float(rule.sea_discount) if harbor_working(sim, s) else 0.0


## The town's offshore signal: which good, whether it is rich and how much it holds. Empty for an
## inland town, and for a coastal one until its first day (`daily` places it). Only reads: the
## pages ask for it, and what a player looks at must not change the game.
static func offshore_signal(sim: RefCounted, region: int) -> Dictionary:
	return sim.state.world.regions[region].get("offshore", {})


## Places a settled coastal town's signal, from the seed and the town alone.
static func _place_signal(sim: RefCounted, region: int) -> void:
	var reg: Dictionary = sim.state.world.regions[region]
	if not bool(reg.get("coast", false)) or rules(sim).is_empty():
		return
	if not reg.has("offshore"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:offshore:%d" % [str(sim.state.world.seed), region])
		var rule: Dictionary = rules(sim)
		var rich: bool = rng.randf() < float(rule.signal_rich_chance)
		reg.offshore = {
			"good": _signal_goods(rule)[rng.randi_range(0, _signal_goods(rule).size() - 1)],
			"rich": rich,
			"tonnes":
			roundf(
				(
					float(rule.signal_rich_tonnes if rich else rule.signal_poor_tonnes)
					* rng.randf_range(0.8, 1.2)
				)
			),
			"surveyed": false,
			"survey_until": -1
		}


static func _signal_goods(rule: Dictionary) -> Array:
	var goods: Array = []
	for good: String in rule.get("signal_goods", SIGNAL_GOODS):
		if not Features.resource_frozen(good):
			goods.append(good)
	return goods


## The survey boat's price and days: the offshore surveying technology halves both.
static func survey_terms(sim: RefCounted) -> Dictionary:
	var rule: Dictionary = rules(sim)
	var share: float = clampf(1.0 - sim.Research.bonus(sim, "offshore_survey"), 0.2, 1.0)
	return {
		"cost": float(rule.survey_cost) * share,
		"days": maxi(1, roundi(float(rule.survey_days) * share)),
	}


## Sends a survey boat from the town's harbour to read the offshore signal: paid now, answered on
## the day it returns.
static func survey(sim: RefCounted, region: int) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return "请选择已建立的据点"
	var reading: Dictionary = offshore_signal(sim, region)
	if reading.is_empty():
		return "这里没有近海信号"
	if bool(reading.surveyed):
		return "近海信号已经查明"
	if int(reading.survey_until) >= 0:
		return "测量船已经出海"
	if not harbor_working(sim, s):
		return "需要一座运转的小型码头"
	var terms: Dictionary = survey_terms(sim)
	if float(sim.state.cash) < float(terms.cost):
		return "公共资金不足：需要 %.0f" % float(terms.cost)
	sim._transfer("public", "external", float(terms.cost), "invest.survey", false, "offshore")
	reading.survey_until = int(sim.state.day) + int(terms.days)
	sim._log("%s · 测量船出海，%d 天后带回近海信号的结果。" % [s.name, int(terms.days)])
	return ""


## Why a seabed mine cannot stand at this town: it needs the offshore signal surveyed and rich.
static func seabed_refusal(sim: RefCounted, region: int) -> String:
	var reading: Dictionary = offshore_signal(sim, region)
	if reading.is_empty():
		return "这里没有近海信号"
	if not bool(reading.surveyed):
		return "先派测量船查明码头外的近海信号"
	if not bool(reading.rich):
		return "近海信号只是一层沉积，没有可采的矿体"
	if float(reading.tonnes) <= 0.0:
		return "近海矿体已经采完"
	return ""


## A seabed mine's day (production.gd): it works the town's surveyed offshore deposit, and its
## barges land the ore at the town's working harbour, a cargo recorded as it lands. Without a
## working harbour nothing is landed. Returns the units landed.
static func seabed_day(sim: RefCounted, s: Dictionary, b: Dictionary, share: float) -> float:
	var reading: Dictionary = offshore_signal(sim, int(s.region))
	if reading.is_empty() or not bool(reading.get("surveyed", false)) or not bool(reading.rich):
		return 0.0
	if not harbor_working(sim, s):
		sim._short(s, Keys.SH_NO_HARBOUR, str(b.kind))
		return 0.0
	var spec: Dictionary = sim.config.buildings[str(b.kind)]
	var good: String = str(reading.good)
	var amount: float = minf(float(reading.tonnes), float(spec.rate) * share)
	if amount <= 0.0:
		return 0.0
	reading.tonnes = float(reading.tonnes) - amount
	sim.Production.produce(sim, s, good, amount, "海底采矿")
	sim.Consignments.landed(sim, s, b, good, amount)
	return amount


## Each day: a new coastal town gets its signal, and a survey boat back in port tells what it is.
static func daily(sim: RefCounted) -> void:
	for s: Dictionary in sim.state.get("settlements", []):
		_place_signal(sim, int(s.region))
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		var reading: Dictionary = reg.get("offshore", {})
		if reading.is_empty() or bool(reading.surveyed) or int(reading.survey_until) < 0:
			continue
		if int(sim.state.day) < int(reading.survey_until):
			continue
		reading.surveyed = true
		var name: String = str(sim.config.resources.get(reading.good, reading.good))
		if bool(reading.rich):
			sim._log(
				(
					"%s · 近海信号查明：海底有一处%s富矿，约 %.0f 吨，待海底开采技术成熟后可以开发。"
					% [s.name, name, float(reading.tonnes) * 100.0]
				)
			)
		else:
			sim._log("%s · 近海信号查明：只是一层含%s的沉积，不值得开采。码头照常使用。" % [s.name, name])
