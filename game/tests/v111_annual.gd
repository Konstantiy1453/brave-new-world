extends SceneTree
## 1.11 phase D: the company's annual ship and the ratchet report.
## - schedule: the first ship a year after landing, then every anniversary; a delay (supply_delay's
##   waiting option) holds the ship and the report;
## - tallies: mined minerals and food grown or caught are counted as they are produced; the report
##   takes the year's tally and starts the next;
## - the three ways to report, their outcomes, money and distrust, booked;
## - the ratchet: next target = max(base of the stage then, reported x growth);
## - the gap opens with a claim beyond the actual, later surplus fills it first;
## - while a gap is open the audit stories weigh more and start at their exposure scene: fine of
##   gap x export price x fine_factor, more distrust, gap closed, targets left alone;
## - 矿权抵押: the tribute is loaded from the capital's ore, a shortfall is a miss, no claims;
## - amendments: deadline shift, company share, next year's targets, a clause added and one
##   removed (no more aid), all recorded in the contract;
## - a report left unsigned goes as it is; a save keeps an open gap and a waiting report; a 1.10
##   save gets its ship on its next anniversary; the screen and the HUD show it.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const AnnualReport = preload("res://simulation/annual_report.gd")
const Contract = preload("res://simulation/contract.gd")
const Company = preload("res://simulation/company.gd")
const Events = preload("res://simulation/events_v2.gd")
const ReportPage = preload("res://ui/annual_report_page.gd")
const ContractPage = preload("res://ui/contract_page.gd")
const SEED: int = 20261029
const OLD_SAVE: String = "res://../docs/v17/placement/save_files/after-1.10.1.save"

var checks: int = 0
var failures: Array[String] = []


class FakeGame:
	extends Node
	var sim: RefCounted
	var acted: Array = []

	func act(action: String, args: Dictionary) -> String:
		acted.append([action, args])
		return sim.act(action, args)

	func populate_current_page() -> void:
		pass

	func open_page(_page: String) -> void:
		pass


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_schedule()
	_tallies()
	_choices()
	_ratchet_and_gap()
	_audits()
	_tribute()
	_amendments()
	_unsigned_and_saved()
	_old_save()
	_interface()
	print("V111_ANNUAL_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(origin: String = "capital") -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, origin, 1)
	sim.act("settle", {"region": _site(sim)})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	return sim


func _site(sim: RefCounted) -> int:
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) == "":
			return int(reg.id)
	return 0


## A day of a colony that builds nothing: fed, and kept clear of the company's process (a bare
## colony would be taken over in its second year), so the ship's calendar can be followed.
func _tick(sim: RefCounted) -> void:
	for town: Dictionary in sim.state.settlements:
		sim._produce(town, "food", maxf(0.0, 400.0 - float(town.stock.food)), "TEST food")
	sim.state.company.distrust = 0.0
	sim.state.company.stage = "normal"
	sim.state.company.deadline = -1
	sim.tick()


## Ticks to `day` (at most 4,000 ticks).
func _until(sim: RefCounted, day: int) -> void:
	var guard: int = 0
	while int(sim.state.day) < day and guard < 4000:
		_tick(sim)
		guard += 1


## Ticks to the day before the next ship, sets the year's tally and targets, and lets it arrive.
func _arrive(sim: RefCounted, mining: float, farming: float, targets: Dictionary) -> Dictionary:
	var a: Dictionary = sim.state.annual
	_until(sim, int(a.next_ship) - 1)
	a.targets = targets.duplicate()
	a.tally = {"mining": mining, "farming": farming}
	_tick(sim)
	return a.pending


func _schedule() -> void:
	var sim: RefCounted = _colony()
	var year: int = int(Rules.read("career").calendar.year_days)
	check(int(sim.state.annual.next_ship) == year, "the first ship comes a year after landing")
	check(AnnualReport.days_to_ship(sim) == year, "and the days to it count down from %d" % year)
	var pending: Dictionary = _arrive(sim, 10.0, 10.0, {"mining": 5.0, "farming": 5.0})
	check(
		not pending.is_empty() and int(sim.state.day) == year,
		"it arrives on the anniversary with the report"
	)
	check(int(sim.state.annual.next_ship) == 2 * year, "the next one a year later")
	sim.act("annual_report", {})
	var waiting: Dictionary = Events.definitions().definitions.supply_delay
	var held: int = 0
	for option: Dictionary in waiting.nodes.start.choices:
		held = maxi(held, int(option.get("ship_delay", 0)))
	check(held > 0, "waiting out the supply delay holds the ship %d days" % held)
	AnnualReport.apply_terms(sim, {"ship_delay": held})
	_until(sim, 2 * year)
	check(
		sim.state.annual.pending.is_empty(), "no report on the anniversary while the ship is late"
	)
	_until(sim, 2 * year + held)
	check(not sim.state.annual.pending.is_empty(), "it comes with the ship")
	check(int(sim.state.annual.next_ship) == 3 * year, "and the next ship keeps the anniversary")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _tallies() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	var before: Dictionary = sim.state.annual.tally.duplicate()
	sim.Production.produce(sim, town, "ore", 7.0, sim.Keys.SOURCE_MINING)
	sim.Production.produce(sim, town, "food", 3.0, sim.Keys.SOURCE_FARMING)
	sim.Production.produce(sim, town, "food", 2.0, sim.Keys.SOURCE_CATCH)
	sim.Production.produce(sim, town, "ore", 50.0, sim.Keys.SOURCE_IMPORT)
	sim.Production.produce(sim, town, "materials", 5.0, sim.Keys.SOURCE_PROCESSING)
	sim.Production.produce(sim, town, "nickel", 9.0, sim.Keys.SOURCE_MINING)
	var tally: Dictionary = sim.state.annual.tally
	check(
		is_equal_approx(float(tally.mining) - float(before.mining), 7.0),
		"mined ore is counted; imports and frozen nickel are not"
	)
	check(
		is_equal_approx(float(tally.farming) - float(before.farming), 5.0),
		"food grown and caught is counted"
	)
	var pending: Dictionary = _arrive(sim, 33.0, 22.0, {"mining": 1.0, "farming": 1.0})
	check(
		(
			is_equal_approx(float(pending.actual.mining), 33.0)
			and is_zero_approx(float(sim.state.annual.tally.mining))
		),
		"the report takes the year's tally and the next year starts from zero"
	)


func _choices() -> void:
	var rule: Dictionary = Rules.read("progression").annual_report
	var targets: Dictionary = {"mining": 100.0, "farming": 100.0}
	var cases: Array = [
		["honest", 90.0, "missed"], ["met", 100.0, "met"], ["exceed", 120.0, "exceed"]
	]
	for row: Array in cases:
		var sim: RefCounted = _colony()
		_arrive(sim, 90.0, 130.0, targets)
		var distrust: float = 30.0
		sim.state.company.distrust = distrust
		var cash: float = float(sim.state.cash)
		check(
			sim.act("annual_report", {"mining": row[0], "farming": "honest"}) == "",
			"a report signed %s on mining" % str(row[0])
		)
		var entry: Dictionary = sim.state.annual.history.back()
		check(
			(
				is_equal_approx(float(entry.reported.mining), float(row[1]))
				and str(entry.outcomes.mining) == str(row[2])
			),
			"reports %.0f, %s" % [float(entry.reported.mining), str(entry.outcomes.mining)]
		)
		var scale: float = Events.money_scale(sim)
		var expected: float = 0.0
		var moved: float = -float(rule.exceed_trust)
		match str(row[2]):
			"missed":
				expected = float(rule.exceed_reward) * scale
				moved = float(rule.miss_distrust) - float(rule.exceed_trust)
			"met":
				expected = (float(rule.met_reward) + float(rule.exceed_reward)) * scale
			"exceed":
				expected = 2.0 * float(rule.exceed_reward) * scale
				moved = -2.0 * float(rule.exceed_trust)
		check(
			is_equal_approx(float(sim.state.cash) - cash, expected),
			"the company pays ¥%.0f (farming exceeded at 130)" % expected
		)
		check(
			is_equal_approx(
				float(sim.state.company.distrust), clampf(distrust + moved, 0.0, 100.0)
			),
			"and distrust moves by %+.1f" % moved
		)
		var booked: bool = false
		for line: Dictionary in sim.state.ledger:
			booked = booked or str(line.key) == AnnualReport.REWARD
		check(booked, "the reward is booked as %s" % AnnualReport.REWARD)
	var sim: RefCounted = _colony()
	check(sim.act("annual_report", {}) != "", "nothing to sign between ships")
	_arrive(sim, 1.0, 1.0, targets)
	check(
		sim.act("annual_report", {"mining": "lots"}) != "", "an unknown way of reporting is refused"
	)


func _ratchet_and_gap() -> void:
	var sim: RefCounted = _colony()
	var rule: Dictionary = Rules.read("progression").annual_report
	var growth: float = float(rule.ratchet_growth.capital)
	_arrive(sim, 80.0, 50.0, {"mining": 100.0, "farming": 40.0})
	sim.act("annual_report", {"mining": "exceed", "farming": "honest"})
	var a: Dictionary = sim.state.annual
	var base: Dictionary = AnnualReport.base_targets(sim, int(sim.state.contract.stage))
	check(
		is_equal_approx(float(a.targets.mining), maxf(float(base.mining), 120.0 * growth)),
		(
			"next year's mining target is max(base, 120 x %.2f): %.1f"
			% [growth, float(a.targets.mining)]
		)
	)
	check(
		is_equal_approx(float(a.targets.farming), maxf(float(base.farming), 50.0 * growth)),
		"and farming's from its honest 50: %.1f" % float(a.targets.farming)
	)
	check(is_equal_approx(float(a.gap.mining), 40.0), "claiming 120 on 80 opens a gap of 40")
	var next: Dictionary = _arrive(sim, 150.0, 60.0, {"mining": 100.0, "farming": 40.0})
	check(
		is_zero_approx(float(a.gap.mining)) and is_equal_approx(float(next.actual.mining), 110.0),
		"the next year's 150 of ore fills the gap of 40 first: 110 counts for the report"
	)
	sim.act("annual_report", {"mining": "honest", "farming": "honest"})
	check(
		str(a.history.back().outcomes.mining) == "met",
		"so an honest report of it meets a target of 100 but no longer exceeds it"
	)
	check(sim.audit().is_empty(), "the audit holds with an open gap: %s" % str(sim.audit()))


func _audits() -> void:
	var sim: RefCounted = _colony()
	check(
		is_equal_approx(AnnualReport.audit_weight(sim, "company_audit"), 1.0),
		"no gap, no extra weight on the audit stories"
	)
	_arrive(sim, 50.0, 50.0, {"mining": 100.0, "farming": 50.0})
	sim.act("annual_report", {"mining": "exceed", "farming": "honest"})
	var a: Dictionary = sim.state.annual
	var weight: float = AnnualReport.audit_weight(sim, "company_audit")
	var expected: float = (
		1.0
		+ (
			float(Rules.read("progression").annual_report.audit_k)
			* float(a.gap.mining)
			/ float(a.targets.mining)
		)
	)
	check(
		is_equal_approx(weight, expected) and weight > 1.0,
		"an open gap weighs the audit stories %.2fx" % weight
	)
	check(
		is_equal_approx(AnnualReport.audit_weight(sim, "price_window"), 1.0), "and no other story"
	)
	var ids: Array = AnnualReport.AUDIT_EVENTS
	var all_have: bool = true
	for id: String in ids:
		all_have = (
			all_have and str(Events.definitions().definitions[id].get("gap_node", "")) == "gap"
		)
	check(all_have, "the three audit stories each have an exposure scene")
	var inst: Dictionary = Events._open(sim, "company_audit", int(sim.state.settlements[0].region))
	check(str(inst.node) == "gap", "while the gap is open, an audit story starts there")
	var gap: float = float(a.gap.mining)
	var targets: Dictionary = a.targets.duplicate()
	var distrust: float = float(sim.state.company.distrust)
	var cash: float = float(sim.state.cash)
	sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "accept_finding"})
	var rule: Dictionary = Rules.read("progression").annual_report
	var fine: float = gap * float(sim.config.prices.ore) * float(rule.fine_factor)
	check(
		is_equal_approx(cash - float(sim.state.cash), fine),
		"the exposure fines gap x ore price x %.1f: ¥%.0f" % [float(rule.fine_factor), fine]
	)
	check(
		is_equal_approx(
			float(sim.state.company.distrust),
			clampf(distrust + float(rule.exposure_distrust), 0.0, 100.0)
		),
		"adds %.0f distrust" % float(rule.exposure_distrust)
	)
	check(
		is_zero_approx(float(a.gap.mining)) and a.targets == targets,
		"closes the gap and leaves the targets"
	)
	var letter: Dictionary = sim.state.company.letters.back()
	check(str(letter.kind) == "report_exposure", "and the company writes about it")
	var fresh: Dictionary = Events._open(sim, "vp_visit", int(sim.state.settlements[0].region))
	check(str(fresh.node) == "start", "with the books closed, an audit story starts as before")


func _tribute() -> void:
	var sim: RefCounted = _colony("mining_pledge")
	var capital: Dictionary = sim.state.settlements[0]
	var due: float = float(sim.config.openings.mining_pledge.rules.tribute[0])
	check(
		is_equal_approx(float(sim.state.annual.targets.mining), due),
		"矿权抵押's mining target is its tribute"
	)
	var a: Dictionary = sim.state.annual
	_until(sim, int(a.next_ship) - 1)
	sim._consume(capital, "ore", float(capital.stock.ore))
	sim._produce(capital, "ore", due * 0.5, "TEST ore")
	var sunk: float = float(sim.state.resource_sinks.ore)
	_tick(sim)
	check(
		(
			is_equal_approx(float(a.pending.actual.mining), due * 0.5)
			and is_zero_approx(float(capital.stock.ore))
		),
		"the ship loads what ore the capital holds"
	)
	check(
		is_equal_approx(float(sim.state.resource_sinks.ore) - sunk, due * 0.5),
		"booked as ore leaving the colony"
	)
	sim.act("annual_report", {"mining": "exceed", "farming": "honest"})
	var entry: Dictionary = a.history.back()
	check(
		str(entry.tiers.mining) == "honest" and str(entry.outcomes.mining) == "missed",
		"half the tribute is a miss, and it cannot be claimed otherwise"
	)
	check(is_zero_approx(float(a.gap.mining)), "so no gap opens on it")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _amendments() -> void:
	var sim: RefCounted = _colony()
	var region: int = int(sim.state.settlements[0].region)
	var all_have: bool = true
	for id: String in AnnualReport.AMENDMENT_EVENTS:
		all_have = all_have and Events.definitions().definitions[id].nodes.has("amendment")
	check(all_have, "the five amendment stories each have an amendment scene")
	var stage: int = int(sim.state.contract.stage)
	var deadline: int = Contract.deadline(sim, stage)
	var rate: float = Contract.company_rate(sim)
	check(Events.trigger(sim, "industry", region, "amendment"), "the ship can bring an amendment")
	var inst: Dictionary = sim.state.events_v2.instances.back()
	check(str(inst.node) == "amendment", "opened at its amendment scene")
	sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "sign"})
	check(sim.state.contract.amendments.size() == 1, "signing records 补充协议 1")
	check(Contract.deadline(sim, stage) == deadline + 60, "the stage deadline moves 60 days")
	check(
		is_equal_approx(float(sim.state.annual.kpi_scale), 1.15),
		"and next year's targets will be x1.15"
	)
	_arrive(sim, 100.0, 100.0, {"mining": 50.0, "farming": 50.0})
	sim.act("annual_report", {})
	var growth: float = float(Rules.read("progression").annual_report.ratchet_growth.capital)
	check(
		is_equal_approx(
			float(sim.state.annual.targets.mining),
			(
				maxf(
					float(AnnualReport.base_targets(sim, int(sim.state.contract.stage)).mining),
					100.0 * growth
				)
				* 1.15
			)
		),
		"which they are: %.1f" % float(sim.state.annual.targets.mining)
	)
	check(sim.audit().is_empty(), "the audit follows the scaled ratchet: %s" % str(sim.audit()))
	Events.trigger(sim, "price_window", region, "amendment")
	inst = sim.state.events_v2.instances.back()
	sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "sign"})
	check(
		is_equal_approx(Contract.company_rate(sim), rate + 0.03),
		"a share amendment raises the company's share after the award by 3 points"
	)
	Events.trigger(sim, "investor_offer", region, "amendment")
	inst = sim.state.events_v2.instances.back()
	sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "sign"})
	sim.state.company.stage = "warning"
	check(
		Company.accept(sim, "liquidity").contains("删除"),
		"with the aid clause signed away, the company offers no aid"
	)
	Events.trigger(sim, "second_ship", region, "amendment")
	inst = sim.state.events_v2.instances.back()
	sim.act("event_v2", {"instance_id": inst.instance_id, "choice": "sign"})
	var titles: String = ""
	for row: Dictionary in ContractPage.clauses(sim):
		titles += str(row.title) + "|"
	check(
		titles.contains("移民接收配额") and titles.contains("已由补充协议删除"),
		"the contract shows the clause added and the one removed"
	)
	check(
		ContractPage.amendment_terms(sim, sim.state.contract.amendments[0]).contains("顺延 60 日"),
		"and says what each amendment changed"
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _unsigned_and_saved() -> void:
	var sim: RefCounted = _colony()
	_arrive(sim, 30.0, 50.0, {"mining": 40.0, "farming": 60.0})
	sim.act("annual_report", {"mining": "exceed", "farming": "honest"})
	_arrive(sim, 10.0, 70.0, {"mining": 60.0, "farming": 60.0})
	check(
		sim.save_game("user://v111_annual.save") == "",
		"a game with an open gap and a waiting report saves"
	)
	var again: RefCounted = Sim.new()
	check(again.load_game("user://v111_annual.save") == "", "and loads")
	var a: Dictionary = again.state.annual
	check(
		is_equal_approx(float(a.gap.mining), 8.0) and not a.pending.is_empty(),
		(
			"with its gap (18, less the 10 the next year filled: %.0f) and its report"
			% float(a.gap.mining)
		)
	)
	var days: int = int(Rules.read("progression").annual_report.report_days)
	for _day: int in range(days + 1):
		_tick(again)
	var entry: Dictionary = a.history.back()
	check(
		a.pending.is_empty() and bool(entry.automatic) and str(entry.tiers.mining) == "honest",
		"left unsigned for %d days, it goes as it is" % days
	)
	check(again.audit().is_empty(), "the audit holds: %s" % str(again.audit()))


func _old_save() -> void:
	var path: String = ProjectSettings.globalize_path(OLD_SAVE)
	if not FileAccess.file_exists(path):
		check(false, "the 1.10 save fixture exists: " + path)
		return
	var sim: RefCounted = Sim.new()
	check(sim.load_game(path) == "", "a 1.10 save loads")
	var year: int = int(Rules.read("career").calendar.year_days)
	var a: Dictionary = sim.state.annual
	check(
		int(a.next_ship) > int(sim.state.day) and int(a.next_ship) % year == 0,
		"its first ship comes on the next anniversary (day %d)" % int(a.next_ship)
	)
	sim.tick()
	check(not a.targets.is_empty(), "with targets from its stage")
	check(sim.audit().is_empty(), "and plays on: %s" % str(sim.audit()))


func _interface() -> void:
	var sim: RefCounted = _colony()
	_arrive(sim, 50.0, 70.0, {"mining": 60.0, "farming": 60.0})
	var fake := FakeGame.new()
	fake.sim = sim
	root.add_child(fake)
	var box := VBoxContainer.new()
	fake.add_child(box)
	ReportPage.page(fake, box)
	var buttons: int = 0
	for node: Node in box.find_children("Report_*", "Button", true, false):
		buttons += 1
	check(buttons == 6, "the report shows three ways to report each line (%d buttons)" % buttons)
	var exceed: Button = box.find_child("Report_mining_exceed", true, false)
	exceed.pressed.emit()
	var sign: Button = box.find_child("SignAnnualReport", true, false)
	sign.pressed.emit()
	check(
		not fake.acted.is_empty() and str(fake.acted.back()[1].get("mining", "")) == "exceed",
		"picking a way and signing sends it"
	)
	check(sim.state.annual.pending.is_empty(), "and the report is signed")
	fake.queue_free()
