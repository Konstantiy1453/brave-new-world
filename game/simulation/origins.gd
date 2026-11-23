extends RefCounted
## Origins (1.11 C): each opening is a type of contract, economy.json `openings` by the id a save
## keeps in `state.advantage`, with a story, gains, costs and one unique rule:
## - workers (工程承包): `crews` crews at landing; the wage policy never goes below `wage_floor`;
## - science (科研托管): the research-contract technology from landing; research-contract income and
##   research funding by `contract_income` and `research_funding`;
## - resettlement (移民安置): each month for `subsidy_days`, `subsidy_per_resident` for every
##   resident with both a bed and a job, booked as operating income (安置补贴);
## - mining_pledge (矿权抵押): an ore tribute on each annual ship (1.11 D reads `tribute`);
## - archipelago (群岛开发): the first settlement must be on the coast.
## An origin's `effects` are the third source of Research.bonus, after technologies and great works.
## Old saves keep their opening id and play on; rules that act at landing touch only new games.

const Rules = preload("res://simulation/rules.gd")
const SUBSIDY: String = "origin.subsidy"
const STANDARD: String = "capital"


static func entry(sim: RefCounted) -> Dictionary:
	return sim.config.openings.get(str(sim.state.get("advantage", STANDARD)), {})


static func rules(sim: RefCounted) -> Dictionary:
	return entry(sim).get("rules", {})


static func effects(sim: RefCounted) -> Dictionary:
	return entry(sim).get("effects", {})


static func name_of(sim: RefCounted) -> String:
	return str(entry(sim).get("name", ""))


static func factor(sim: RefCounted, key: String) -> float:
	return float(rules(sim).get(key, 1.0))


## The lowest wage policy the contract allows, as a multiple of base wages; 0 when there is none.
static func wage_floor(sim: RefCounted) -> float:
	return float(rules(sim).get("wage_floor", 0.0))


static func wage_refusal(sim: RefCounted, wage: float) -> String:
	var floor_value: float = wage_floor(sim)
	if floor_value > 0.0 and wage < floor_value - 0.0001:
		return "%s合同规定工资不得低于基准的 %.2f 倍" % [name_of(sim), floor_value]
	return ""


static func crews_at_landing(sim: RefCounted, fallback: int) -> int:
	return int(rules(sim).get("crews", fallback))


static func coastal_first(sim: RefCounted) -> bool:
	return bool(rules(sim).get("coastal_first", false))


## Why the first settlement cannot be founded on this ground under the contract ("" when it can).
static func founding_refusal(sim: RefCounted, coastal: bool) -> String:
	if coastal_first(sim) and sim.state.get("settlements", []).is_empty() and not coastal:
		return "%s合同：首个据点必须建在海岸，内陆不能落脚" % name_of(sim)
	return ""


## A new game's state under its contract: the wage policy starts at the floor.
static func begin(sim: RefCounted) -> void:
	var floor_value: float = wage_floor(sim)
	if floor_value > float(sim.state.policy.get("wage", 1.0)):
		sim.state.policy.wage = floor_value


## At landing (the first settlement): the technology the contract hands over.
static func land(sim: RefCounted) -> void:
	if bool(rules(sim).get("grant_contract_tech", false)):
		sim.Research.grant_by_contract(sim, str(sim.progression.research.contract_tech))


## Residents who have both a bed and a job: in each settled town, the employed up to its beds.
static func housed_and_employed(sim: RefCounted) -> int:
	var count: int = 0
	for s: Dictionary in sim.state.settlements:
		if int(s.get("arrival", 0)) > 0:
			continue
		count += mini(int(s.get("employed", 0)), int(s.get("housing", 0)))
	return count


## The resettlement subsidy, paid on the first day of each month while it lasts.
static func daily(sim: RefCounted) -> void:
	var per: float = float(rules(sim).get("subsidy_per_resident", 0.0))
	if per <= 0.0 or sim.state.settlements.is_empty():
		return
	var day: int = int(sim.state.day)
	var month: int = int(Rules.read("career").calendar.month_days)
	if day <= 0 or day % month != 0 or day > int(rules(sim).get("subsidy_days", 0)):
		return
	var people: int = housed_and_employed(sim)
	if people <= 0:
		return
	sim._transfer("external", "public", per * people, SUBSIDY, true)
	sim._log("安置补贴：%d 位居民有床位也有工作，公司拨付 ¥%.0f。" % [people, per * people])
