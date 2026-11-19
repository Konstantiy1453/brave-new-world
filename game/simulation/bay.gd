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

const Keys = preload("res://simulation/keys.gd")

const SIGNAL_GOODS: Array[String] = ["copper", "crystal"]


static func rules(sim: RefCounted) -> Dictionary:
	return sim.config.get("bay", {})


## The extra days and cost a mine's road adds on a plot beyond the haul reach: {days, cost, units}.
static func haul(sim: RefCounted, region: int, plot: int) -> Dictionary:
	var rule: Dictionary = rules(sim)
	var plots: Array = sim.state.world.regions[region].get("plots", [])
	if rule.is_empty() or plot < 0 or plot >= plots.size():
		return {"days": 0, "cost": 0.0, "units": 0.0}
	var reach: float = Vector2(float(plots[plot].x), float(plots[plot].z)).length()
	var beyond: float = maxf(0.0, reach - float(rule.haul_reach))
	if beyond <= 0.0:
		return {"days": 0, "cost": 0.0, "units": 0.0}
	return {
		"days": ceili(beyond * float(rule.haul_days_per_unit)),
		"cost": beyond * float(rule.haul_cost_per_unit),
		"units": beyond
	}


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
			"good": SIGNAL_GOODS[rng.randi_range(0, SIGNAL_GOODS.size() - 1)],
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
	var rule: Dictionary = rules(sim)
	if float(sim.state.cash) < float(rule.survey_cost):
		return "公共资金不足：需要 %.0f" % float(rule.survey_cost)
	sim._transfer("public", "external", float(rule.survey_cost), "invest.survey", false, "offshore")
	reading.survey_until = int(sim.state.day) + int(rule.survey_days)
	sim._log("%s · 测量船出海，%d 天后带回近海信号的结果。" % [s.name, int(rule.survey_days)])
	return ""


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
