extends RefCounted
## The three endings (1.11 E), after the governor award:
## - 效忠 (loyal): the award as before, then the handover; it is the ending unless another follows.
## - 收购 (buyout): `buy_out` succeeds when the career fund covers the price, a multiple x the
##   company's share x the trailing 360-day operating profit, with a floor (career.json `buyout`).
##   The company's share of the surplus ends.
## - 自治 (autonomy): `declare_autonomy` succeeds when 民心, population and the company rating meet
##   career.json `autonomy`, or when Annex VII was answered 公开 and 民心 meets its own threshold.
##   The company's share ends and its process stops; no embargo in 1.11.
## Every ending, and the takeover, has a settlement statement (结算单), built by `statement`.

const Rules = preload("res://simulation/rules.gd")
const Population = preload("res://simulation/population.gd")
const LOYAL: String = "loyal"
const BUYOUT: String = "buyout"
const AUTONOMY: String = "autonomy"
const TAKEOVER: String = "takeover"
const RATING_ORDER: Array[String] = ["A", "B", "C", "D"]


static func rules() -> Dictionary:
	return Rules.read("career")


static func ensure_state(state: Dictionary) -> void:
	if not state.has("ending"):
		state.ending = {"kind": "", "day": -1, "price": 0.0}


## The trailing year's operating profit, the basis of the buyout price.
static func year_profit(sim: RefCounted) -> float:
	var total: float = 0.0
	var history: Array = sim.state.get("operating_history", [])
	var days: int = int(rules().calendar.year_days)
	for index: int in range(maxi(0, history.size() - days), history.size()):
		total += float(history[index].net)
	return total


static func buyout_price(sim: RefCounted) -> float:
	var rule: Dictionary = rules().get("buyout", {})
	var share: float = sim.Contract.company_rate(sim)
	return maxf(
		float(rule.get("floor", 0.0)),
		float(rule.get("multiple", 1.0)) * share * maxf(0.0, year_profit(sim))
	)


static func _open(sim: RefCounted) -> String:
	ensure_state(sim.state)
	if str(sim.state.status) != "success":
		return "取得总督资格后才能选择结局"
	if str(sim.state.ending.kind) in [BUYOUT, AUTONOMY]:
		return "这个殖民地已经选择了结局"
	return ""


static func buy_out(sim: RefCounted) -> String:
	var refusal: String = _open(sim)
	if refusal != "":
		return refusal
	var price: float = buyout_price(sim)
	var fund: float = float(sim.state.career.balance)
	if fund + 0.000001 < price:
		return "生涯资金不足：收购价 ¥%.0f，现有 ¥%.0f" % [price, fund]
	sim.state.career.balance = fund - price
	_end(sim, BUYOUT, price)
	sim._log("收购完成：以生涯资金 ¥%.0f 买断公司在%s的经营分成。" % [price, str(sim.state.settlements[0].name)])
	return ""


## What autonomy asks for, and whether each part holds now.
static func autonomy_terms(sim: RefCounted) -> Dictionary:
	var rule: Dictionary = rules().get("autonomy", {})
	var morale: float = Population.morale(sim)
	var people: int = int(sim.Contract.population_total(sim))
	var rating: String = sim.Company.rating(sim)
	var best: String = str(rule.get("rating_at_least", "B"))
	var disclosed: bool = str(sim.state.get("annex", {}).get("answer", "")) == "disclose"
	var standard: bool = (
		morale >= float(rule.get("morale", 0.0))
		and people >= int(rule.get("population", 0))
		and RATING_ORDER.find(rating) <= RATING_ORDER.find(best)
	)
	var by_disclosure: bool = disclosed and morale >= float(rule.get("disclosed_morale", 0.0))
	return {
		"morale": morale,
		"population": people,
		"rating": rating,
		"disclosed": disclosed,
		"ok": standard or by_disclosure,
	}


static func declare_autonomy(sim: RefCounted) -> String:
	var refusal: String = _open(sim)
	if refusal != "":
		return refusal
	var terms: Dictionary = autonomy_terms(sim)
	if not bool(terms.ok):
		return "自治的条件尚未满足：民心、人口与公司评级（或附件七公开后的民心）"
	_end(sim, AUTONOMY, 0.0)
	sim._log("%s宣布自治：公司的经营分成与审查到此为止。" % str(sim.state.settlements[0].name))
	return ""


static func _end(sim: RefCounted, kind: String, price: float) -> void:
	sim.state.ending = {"kind": kind, "day": int(sim.state.day), "price": price}


## After a buyout or autonomy the company takes no share and runs no process.
static func company_released(sim: RefCounted) -> bool:
	return str(sim.state.get("ending", {}).get("kind", "")) in [BUYOUT, AUTONOMY]


## The award, when it comes, is the loyal ending until another is chosen.
static func on_award(sim: RefCounted) -> void:
	ensure_state(sim.state)
	if str(sim.state.ending.kind) == "":
		_end(sim, LOYAL, 0.0)


static func on_takeover(sim: RefCounted) -> void:
	ensure_state(sim.state)
	_end(sim, TAKEOVER, 0.0)


## The settlement statement (结算单): per stage what was promised and delivered; the annual reports
## and their gaps; the amendments; rewards and fines; the player's share; landmarks.
static func statement(sim: RefCounted) -> Dictionary:
	var stages: Array = []
	for row: Dictionary in sim.Contract.document(sim).stages:
		stages.append({"id": row.id, "deadline": int(row.deadline), "accepted": int(row.accepted)})
	var annual: Dictionary = sim.state.get("annual", {})
	var reports: Array = []
	for entry: Dictionary in annual.get("history", []):
		(
			reports
			. append(
				{
					"year": int(entry.year),
					"actual": entry.actual.duplicate(),
					"reported": entry.reported.duplicate(),
					"outcomes": entry.outcomes.duplicate(),
				}
			)
		)
	var money: Dictionary = {}
	for key: String in ["contract.reward", "annual.reward", "annual.fine", "event.reward"]:
		money[key] = 0.0
	for line: Dictionary in sim.state.get("ledger", []):
		if money.has(str(line.key)):
			money[str(line.key)] = float(money[str(line.key)]) + float(line.amount)
	return {
		"ending": sim.state.get("ending", {}).duplicate(),
		"lean": str(sim.state.get("ending_lean", "")),
		"stages": stages,
		"reports": reports,
		"gap": annual.get("gap", {}).duplicate(),
		"amendments": sim.state.contract.get("amendments", []).duplicate(true),
		"rewards_paid": float(annual.get("rewards_paid", 0.0)),
		"fines_paid": float(annual.get("fines_paid", 0.0)),
		"tribute": float(annual.get("tribute_delivered", 0.0)),
		"money": money,
		"company_rate": sim.Contract.company_rate(sim),
		"player_share": float(rules().management.player_share),
		"career_fund": float(sim.state.get("career", {}).get("balance", 0.0)),
		"landmarks": sim.state.get("events_v2", {}).get("landmarks", []).duplicate(true),
	}
