extends RefCounted
## The company's annual ship and the ratchet report (1.11 D).
## - The ship arrives at the capital on each landing anniversary (`career.json` year_days); an event
##   can delay it (`ship_delay`), and the report with it. Its arrival opens the year's report.
## - Two lines: 矿业, minerals mined in the year (frozen ones left out), and 农业, food grown or
##   caught in the year, tallied as they are produced. Targets by contract stage live in
##   progression.json `annual_report`.
## - Per line the contractor reports 如实 (the actual), 报达标 (at least the target) or 报超额 (at
##   least the target x exceed_factor), and signs once. Below the target is a miss (distrust),
##   at it pays met_reward, above exceed_factor pays exceed_reward and wins back trust; money
##   scales like event money.
## - The ratchet: next year's target is the larger of the base target of the stage then and the
##   reported value x the origin's growth (x any signed kpi_scale). What is claimed beyond the
##   actual opens a gap (账面差额); a later year's production fills it first, before it counts
##   for that year's report. While a gap is open the audit
##   stories come more often and, when they do, start at their exposure scene: a fine of gap x
##   export price x fine_factor, more distrust, the gap closed, targets left where they are.
## - 矿权抵押: the mining line is the ore tribute, loaded from the capital's stock on arrival, unpaid;
##   a shortfall is a miss and nothing can be claimed for it.
## - The ship may carry a contract amendment: one of the stories with an `amendment` node opens
##   there; choices that change the contract for good are applied by `apply_terms`.

const Rules = preload("res://simulation/rules.gd")
const Keys = preload("res://simulation/keys.gd")
const Features = preload("res://simulation/features.gd")
const Origins = preload("res://simulation/origins.gd")
const MINING: String = "mining"
const FARMING: String = "farming"
const LINES: Array[String] = ["mining", "farming"]
const HONEST: String = "honest"
const MET: String = "met"
const EXCEED: String = "exceed"
const TIERS: Array[String] = ["honest", "met", "exceed"]
const MISSED: String = "missed"
const REWARD: String = "annual.reward"
const FINE: String = "annual.fine"
const MINED_GOODS: Array[String] = ["ore", "copper", "crystal", "nickel", "cobalt"]
## The stories a ship can bring as an amendment, and those that audit an open gap.
const AMENDMENT_EVENTS: Array[String] = [
	"industry", "price_window", "second_ship", "new_tax_letter", "investor_offer"
]
const AUDIT_EVENTS: Array[String] = ["company_audit", "ledger_hole", "vp_visit"]
const EPSILON: float = 0.0001


static func rules(sim: RefCounted) -> Dictionary:
	return sim.progression.get("annual_report", {})


static func year_days() -> int:
	return int(Rules.read("career").calendar.year_days)


static func _zero() -> Dictionary:
	return {"mining": 0.0, "farming": 0.0}


## A save from before the ship: a landed colony's next ship comes on its next anniversary.
static func ensure_state(state: Dictionary) -> void:
	if state.has("annual"):
		return
	var landed: bool = not state.get("settlements", []).is_empty()
	var year: int = year_days()
	state.annual = {
		"landing_day": 0 if landed else -1,
		"next_ship": (floori(float(state.get("day", 0)) / year) + 1) * year if landed else -1,
		"year": floori(float(state.get("day", 0)) / year) if landed else 0,
		"tally": _zero(),
		"targets": {},
		"gap": _zero(),
		"pending": {},
		"history": [],
		"kpi_scale": 1.0,
		"rewards_paid": 0.0,
		"fines_paid": 0.0,
		"tribute_delivered": 0.0,
	}


## The first settlement is founded: the first ship comes a year later.
static func land(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var a: Dictionary = sim.state.annual
	a.landing_day = int(sim.state.day)
	a.next_ship = int(sim.state.day) + year_days()
	a.targets = base_targets(sim, _stage(sim))


static func _stage(sim: RefCounted) -> int:
	return clampi(int(sim.state.contract.stage), 1, sim.Contract.STAGE_COUNT)


## A stage's base targets, in goods units a year; the mining pledge's line is its tribute.
static func base_targets(sim: RefCounted, stage: int) -> Dictionary:
	var base: Dictionary = rules(sim).get("base_targets", {})
	var targets: Dictionary = {}
	for line: String in LINES:
		var row: Array = base.get(line, [0.0])
		targets[line] = float(row[clampi(stage - 1, 0, row.size() - 1)])
	var tribute: Array = Origins.rules(sim).get("tribute", [])
	if not tribute.is_empty():
		targets[MINING] = float(tribute[clampi(stage - 1, 0, tribute.size() - 1)])
	return targets


static func pledged(sim: RefCounted) -> bool:
	return not Origins.rules(sim).get("tribute", []).is_empty()


## Called by Production.produce for every good made: the year's mined minerals and food.
static func tally(sim: RefCounted, good: String, amount: float, source: String) -> void:
	var a: Dictionary = sim.state.get("annual", {})
	if a.is_empty() or int(a.landing_day) < 0:
		return
	if source == Keys.SOURCE_MINING and good in MINED_GOODS and not Features.resource_frozen(good):
		a.tally[MINING] = float(a.tally[MINING]) + amount
	elif good == "food" and source in [Keys.SOURCE_FARMING, Keys.SOURCE_CATCH]:
		a.tally[FARMING] = float(a.tally[FARMING]) + amount


## Days until the next ship (-1 before the landing).
static func days_to_ship(sim: RefCounted) -> int:
	var a: Dictionary = sim.state.get("annual", {})
	if a.is_empty() or int(a.next_ship) < 0:
		return -1
	return maxi(0, int(a.next_ship) - int(sim.state.day))


## Each day: targets for a colony loaded from before the ship, the ship on its day, and a report
## left unsigned past its days signed as it is (如实).
static func daily(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var a: Dictionary = sim.state.annual
	if int(a.landing_day) < 0 or sim.state.settlements.is_empty():
		return
	if a.targets.is_empty():
		a.targets = base_targets(sim, _stage(sim))
	if not a.pending.is_empty() and int(sim.state.day) >= int(a.pending.deadline):
		sign_report(sim, {}, true)
	if int(sim.state.day) >= int(a.next_ship):
		_arrive(sim)


## An event holds the ship back (supply_delay): the report waits with it.
static func delay(sim: RefCounted, days: int) -> void:
	var a: Dictionary = sim.state.get("annual", {})
	if days <= 0 or a.is_empty() or int(a.next_ship) < 0:
		return
	a.next_ship = int(a.next_ship) + days
	sim._log("公司年度船延误 %d 日，年度报告随船顺延。" % days)


static func _arrive(sim: RefCounted) -> void:
	var a: Dictionary = sim.state.annual
	var capital: Dictionary = sim.state.settlements[0]
	var report: Dictionary = {
		"day": int(sim.state.day),
		"year": int(a.year) + 1,
		"stage": _stage(sim),
		"actual": a.tally.duplicate(),
		"targets": a.targets.duplicate(),
		"fixed": [],
		"deadline": int(sim.state.day) + int(rules(sim).get("report_days", 30)),
		"tribute": 0.0,
		"produced": a.tally.duplicate(),
		"filled": _zero(),
	}
	# Production first makes good what earlier reports claimed but the colony never made.
	for line: String in LINES:
		var filled: float = minf(float(a.gap[line]), float(a.tally[line]))
		a.gap[line] = float(a.gap[line]) - filled
		report.filled[line] = filled
		report.actual[line] = float(a.tally[line]) - filled
	if pledged(sim):
		var due: float = float(report.targets[MINING])
		var loaded: float = minf(due, float(capital.stock.get("ore", 0.0)))
		if loaded > 0.0:
			sim._consume(capital, "ore", loaded)
		report.actual[MINING] = loaded
		report.tribute = loaded
		report.fixed = [MINING]
		a.tribute_delivered = float(a.tribute_delivered) + loaded
	a.pending = report
	a.tally = _zero()
	a.year = int(a.year) + 1
	a.next_ship = int(a.landing_day) + (int(a.year) + 1) * year_days()
	sim._log(
		(
			"公司年度船抵达%s：第 %d 年度报告待签署（%d 日内）。"
			% [str(capital.name), int(report.year), int(rules(sim).get("report_days", 30))]
		)
	)
	_amendment(sim, int(capital.region), int(report.year))


## The ship may bring one amendment, from the second year on, by the colony's own random stream.
static func _amendment(sim: RefCounted, region: int, year: int) -> void:
	var rule: Dictionary = rules(sim)
	if year < int(rule.get("amendment_from_year", 2)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:amendment:%d" % [str(sim.state.world.seed), year])
	if rng.randf() >= float(rule.get("amendment_chance", 0.5)):
		return
	var start: int = rng.randi_range(0, AMENDMENT_EVENTS.size() - 1)
	for step: int in range(AMENDMENT_EVENTS.size()):
		var id: String = AMENDMENT_EVENTS[(start + step) % AMENDMENT_EVENTS.size()]
		if sim.EventsV2.trigger(sim, id, region, "amendment"):
			return


## What the contractor reports on a line for a tier.
static func reported(actual: float, target: float, tier: String, exceed: float) -> float:
	match tier:
		MET:
			return maxf(actual, target)
		EXCEED:
			return maxf(actual, target * exceed)
	return actual


static func outcome(value: float, target: float, exceed: float) -> String:
	if value < target - EPSILON:
		return MISSED
	if value >= target * exceed - EPSILON:
		return EXCEED
	return MET


## Signs the pending report: `choices` gives a tier per line (如实 when missing); fixed lines are
## always as they are. Returns the refusal, "" when signed.
static func sign_report(sim: RefCounted, choices: Dictionary, automatic: bool = false) -> String:
	var a: Dictionary = sim.state.get("annual", {})
	if a.is_empty() or a.pending.is_empty():
		return "现在没有待签署的年度报告"
	for line: String in choices:
		if not line in LINES or not str(choices[line]) in TIERS:
			return "年度报告的选项无效"
	var rule: Dictionary = rules(sim)
	var exceed: float = float(rule.get("exceed_factor", 1.2))
	var p: Dictionary = a.pending
	var stage_now: int = _stage(sim)
	var base_now: Dictionary = base_targets(sim, stage_now)
	var growth: float = float(rule.get("ratchet_growth", {}).get(str(sim.state.advantage), 1.1))
	var scale: float = sim.EventsV2.money_scale(sim)
	var entry: Dictionary = {
		"year": int(p.year),
		"day": int(sim.state.day),
		"stage": int(p.stage),
		"stage_after": stage_now,
		"actual": p.actual.duplicate(),
		"targets": p.targets.duplicate(),
		"fixed": p.fixed.duplicate(),
		"base": base_now.duplicate(),
		"tiers": {},
		"reported": {},
		"outcomes": {},
		"reward": 0.0,
		"distrust": 0.0,
		"gap": {},
		"next_targets": {},
		"growth": growth,
		"kpi_scale": float(a.kpi_scale),
		"tribute": float(p.tribute),
		"automatic": automatic,
	}
	for line: String in LINES:
		var tier: String = str(choices.get(line, HONEST))
		if line in p.fixed:
			tier = HONEST
		var actual: float = float(p.actual[line])
		var target: float = float(p.targets[line])
		var value: float = reported(actual, target, tier, exceed)
		var result: String = outcome(value, target, exceed)
		entry.tiers[line] = tier
		entry.reported[line] = value
		entry.outcomes[line] = result
		if result == MISSED:
			entry.distrust = float(entry.distrust) + float(rule.get("miss_distrust", 0.0))
		elif result == EXCEED:
			entry.reward = float(entry.reward) + float(rule.get("exceed_reward", 0.0)) * scale
			entry.distrust = float(entry.distrust) - float(rule.get("exceed_trust", 0.0))
		else:
			entry.reward = float(entry.reward) + float(rule.get("met_reward", 0.0)) * scale
		a.gap[line] = maxf(0.0, float(a.gap[line]) + value - actual)
		entry.gap[line] = float(a.gap[line])
		entry.next_targets[line] = next_target(
			line in p.fixed, float(base_now[line]), value, growth, float(a.kpi_scale)
		)
	if float(entry.reward) > 0.0:
		sim._transfer("external", "public", float(entry.reward), REWARD, false)
		a.rewards_paid = float(a.rewards_paid) + float(entry.reward)
	var c: Dictionary = sim.state.company
	c.distrust = clampf(float(c.distrust) + float(entry.distrust), 0.0, 100.0)
	a.targets = entry.next_targets.duplicate()
	a.kpi_scale = 1.0
	a.history.append(entry)
	a.pending = {}
	sim.Company.letter(sim, "annual_receipt", _receipt_values(sim, entry))
	return ""


## The ratchet: a fixed line (the tribute) follows its base; another the larger of the base and
## the reported value x growth, x any amendment's scale.
static func next_target(
	fixed: bool, base: float, value: float, growth: float, kpi_scale: float
) -> float:
	if fixed:
		return base
	return maxf(base, value * growth) * kpi_scale


static func _receipt_values(sim: RefCounted, entry: Dictionary) -> Dictionary:
	var words: Dictionary = {MISSED: "未达标", MET: "达标", EXCEED: "超额"}
	return {
		"year": int(entry.year),
		"mining_outcome": str(words.get(entry.outcomes[MINING], "")),
		"farming_outcome": str(words.get(entry.outcomes[FARMING], "")),
		"reward": "%.0f" % float(entry.reward),
		"mining_target": "%.0f" % sim.tonnes(float(entry.next_targets[MINING])),
		"farming_target": "%.0f" % sim.tonnes(float(entry.next_targets[FARMING])),
	}


static func gap_open(sim: RefCounted) -> bool:
	var a: Dictionary = sim.state.get("annual", {})
	if a.is_empty():
		return false
	for line: String in LINES:
		if float(a.gap[line]) > EPSILON:
			return true
	return false


## A story's weight factor: the audits while the books are open, the stories tied to Annex VII.
static func story_weight(sim: RefCounted, id: String) -> float:
	return audit_weight(sim, id) * sim.Annex.event_weight(sim, id)


## How much more often an audit story is drawn while the books are open: 1 + k x gap / target.
static func audit_weight(sim: RefCounted, id: String) -> float:
	if not id in AUDIT_EVENTS or not gap_open(sim):
		return 1.0
	var a: Dictionary = sim.state.annual
	var share: float = 0.0
	for line: String in LINES:
		share += float(a.gap[line]) / maxf(1.0, float(a.targets.get(line, 1.0)))
	return 1.0 + float(rules(sim).get("audit_k", 0.0)) * share


## Where a story starts: an audit story at its exposure scene while a gap is open.
static func start_node(sim: RefCounted, definition: Dictionary, asked: String) -> String:
	if asked != "start":
		return asked if definition.nodes.has(asked) else "start"
	var gap_node: String = str(definition.get("gap_node", ""))
	if gap_node != "" and definition.nodes.has(gap_node) and gap_open(sim):
		return gap_node
	return "start"


## The exposure: a fine of gap x export price x fine_factor per line, more distrust, gaps closed;
## the targets stay where the claims put them.
static func expose(sim: RefCounted) -> float:
	var a: Dictionary = sim.state.get("annual", {})
	if a.is_empty() or not gap_open(sim):
		return 0.0
	var rule: Dictionary = rules(sim)
	var prices: Dictionary = {MINING: float(sim.config.prices.ore), FARMING: 0.0}
	prices[FARMING] = float(sim.config.prices.food)
	var fine: float = 0.0
	for line: String in LINES:
		fine += float(a.gap[line]) * float(prices[line]) * float(rule.get("fine_factor", 1.0))
		a.gap[line] = 0.0
	sim._public_expense(fine, FINE, "external")
	a.fines_paid = float(a.fines_paid) + fine
	var c: Dictionary = sim.state.company
	c.distrust = clampf(float(c.distrust) + float(rule.get("exposure_distrust", 0.0)), 0.0, 100.0)
	sim._log("账面差额被查实：罚款 ¥%.0f，差额清零，指标不变。" % fine)
	sim.Company.letter(sim, "report_exposure", {"fine": "%.0f" % fine})
	return fine


## Event choices that change the contract or the ship (1.11 D): `ship_delay` (days),
## `report_exposure`, and the amendment keys `deadline_shift` (days on the current stage),
## `company_share` (points on the company's share after the award), `kpi_scale` (next year's
## targets), `add_clause` and `remove_clause`. An amendment is recorded in the contract.
static func apply_terms(sim: RefCounted, option: Dictionary) -> void:
	if int(option.get("ship_delay", 0)) > 0:
		delay(sim, int(option.ship_delay))
	if bool(option.get("report_exposure", false)):
		expose(sim)
	var terms: Dictionary = {}
	for key: String in [
		"deadline_shift", "company_share", "kpi_scale", "add_clause", "remove_clause"
	]:
		if option.has(key):
			terms[key] = option[key]
	if terms.is_empty():
		return
	sim.Contract.amend(sim, terms, str(option.get("amendment", option.get("label", ""))))
	if terms.has("kpi_scale"):
		ensure_state(sim.state)
		sim.state.annual.kpi_scale = float(sim.state.annual.kpi_scale) * float(terms.kpi_scale)


## The report as the screen shows it: the pending one (or {}), the gap, the days to the ship.
static func view(sim: RefCounted) -> Dictionary:
	ensure_state(sim.state)
	var a: Dictionary = sim.state.annual
	var rule: Dictionary = rules(sim)
	return {
		"pending": a.pending.duplicate(true),
		"gap": a.gap.duplicate(),
		"targets": a.targets.duplicate(),
		"tally": a.tally.duplicate(),
		"days_to_ship": days_to_ship(sim),
		"exceed_factor": float(rule.get("exceed_factor", 1.2)),
		"history": a.history.duplicate(true),
		"pledged": pledged(sim),
	}


## The books hold: gaps and tallies never below zero; the rewards paid equal the history's; every
## target set by a report follows the ratchet from that report's base, claim, growth and scale.
static func audit(sim: RefCounted) -> Array:
	var errors: Array = []
	var a: Dictionary = sim.state.get("annual", {})
	if a.is_empty():
		return errors
	for line: String in LINES:
		if float(a.gap.get(line, 0.0)) < -EPSILON or float(a.tally.get(line, 0.0)) < -EPSILON:
			errors.append("annual report " + line + " below zero")
	var paid: float = 0.0
	for entry: Dictionary in a.history:
		paid += float(entry.reward)
		for line: String in LINES:
			var expected: float = next_target(
				line in entry.fixed,
				float(entry.base[line]),
				float(entry.reported[line]),
				float(entry.growth),
				float(entry.kpi_scale)
			)
			if absf(expected - float(entry.next_targets[line])) > maxf(0.001, expected * 0.000001):
				errors.append("annual report ratchet")
	if absf(paid - float(a.rewards_paid)) > maxf(0.01, paid * 0.000001):
		errors.append("annual report rewards")
	return errors


static func validate(_sim: RefCounted, candidate: Dictionary) -> String:
	var annual: Variant = candidate.get("annual")
	if not annual is Dictionary:
		return "存档缺少年度报告"
	for key: String in ["landing_day", "next_ship", "year", "tally", "targets", "gap", "pending"]:
		if not annual.has(key):
			return "年度报告缺少字段：" + key
	for key: String in ["history", "kpi_scale", "rewards_paid", "fines_paid", "tribute_delivered"]:
		if not annual.has(key):
			return "年度报告缺少字段：" + key
	if not annual.tally is Dictionary or not annual.gap is Dictionary:
		return "年度报告数据无效"
	for line: String in LINES:
		if not (annual.gap.get(line) is float or annual.gap.get(line) is int):
			return "年度报告账面差额无效"
	if not annual.history is Array or not annual.pending is Dictionary:
		return "年度报告数据无效"
	return ""
