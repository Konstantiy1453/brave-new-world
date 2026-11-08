extends SceneTree
## 1.9's money rules as the simulation applies them: dearer copies, saturating fixed incomes, an
## administration that grows a little faster than the colony, a lower market floor, and the public
## services budget with its costs, effects, refusal to run into debt and its place in saves.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Copies = preload("res://simulation/copies.gd")
const Population = preload("res://simulation/population.gd")
const Market = preload("res://simulation/market.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Keys = preload("res://simulation/keys.gd")
const Stats = preload("res://simulation/stats.gd")
const Research = preload("res://simulation/research.gd")
const ResearchBot = preload("res://tests/balance/bots/research_first_bot.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Sites = preload("res://simulation/sites.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Production = preload("res://simulation/production.gd")
const LATE_WORKS: Array[String] = [
	"terraforming", "capital_district", "exchange", "shipyard", "emergency_net"
]

const SEED: int = 260129
const SAVE_PATH: String = "user://v19_money.save"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func make() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1, "normal")
	sim.act("settle", {"site": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


## Money in and out through the ledger, so the audit still balances.
func fund(sim: RefCounted, amount: float) -> void:
	sim._transfer("external", "public", amount, "test.windfall", false)


func drain(sim: RefCounted) -> void:
	sim._transfer("public", "external", float(sim.state.cash), "test.drain", false)


func run() -> void:
	_copies()
	_fixed_incomes()
	_administration()
	_market_floor()
	_services()
	_services_save()
	_cover()
	_admin_view()
	_market_view()
	_mine_outlook()
	_sinks()
	_career_transfer()
	_commissions()
	_old_schema_save()
	_great_works()
	_shuttle()
	print("V19_MONEY_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _fake(kind: String, active: bool = true) -> Dictionary:
	return {"kind": kind, "active": active, "enabled": true, "remaining": 0, "plot": -1, "level": 1}


func _copies() -> void:
	var sim: RefCounted = make()
	var place: Dictionary = sim.state.settlements[0]
	var region: int = int(place.region)
	var rules: Dictionary = sim.config.economy
	var first: float = float(sim.build_preview(region, "farm").cost)
	var standing: int = Copies.count_kind(sim, "farm")
	for _index: int in range(3):
		place.buildings.append(_fake("farm"))
	var fourth: Dictionary = sim.build_preview(region, "farm")
	var step: float = float(rules.copy_surcharge)
	check(
		is_equal_approx(
			float(fourth.cost) / first, (1.0 + step * (standing + 3)) / (1.0 + step * standing)
		),
		"each further copy costs copy_surcharge more cash"
	)
	check(int(fourth.copy_number) == standing + 4, "the preview says which copy this is")
	for _index: int in range(60):
		place.buildings.append(_fake("farm"))
	var capped: Dictionary = sim.build_preview(region, "farm")
	check(
		is_equal_approx(float(capped.copy_surcharge), float(rules.copy_surcharge_cap) - 1.0),
		"the surcharge stops at its cap"
	)
	var great: Dictionary = sim.build_preview(region, "university")
	check(float(great.get("copy_surcharge", 0.0)) == 0.0, "great works pay no copy surcharge")
	for _index: int in range(5):
		place.buildings.append(_fake("habitat"))
	var home: Dictionary = sim.build_preview(region, "habitat")
	check(float(home.get("copy_surcharge", 0.0)) == 0.0, "homes pay no copy surcharge")
	fund(sim, 1.0e9)
	var forecast: Dictionary = sim.build_forecast(region, "farm")
	check(
		is_equal_approx(float(forecast.cost), float(capped.cost)), "the forecast pays the surcharge"
	)


func _fixed_incomes() -> void:
	var sim: RefCounted = make()
	var place: Dictionary = sim.state.settlements[0]
	var rules: Dictionary = sim.config.economy
	var centres: Array = []
	for _index: int in range(3):
		var building: Dictionary = _fake("data_center")
		place.buildings.append(building)
		centres.append(building)
	var factor: float = float(rules.income_copy_factor)
	check(
		is_equal_approx(Copies.factor_for(sim, centres[0], factor, 1), 1.0),
		"first data centre earns in full"
	)
	check(
		is_equal_approx(Copies.factor_for(sim, centres[1], factor, 1), factor),
		"second earns the factor"
	)
	check(
		is_equal_approx(Copies.factor_for(sim, centres[2], factor, 1), factor * factor),
		"third earns the factor twice"
	)
	centres[0].active = false
	check(
		is_equal_approx(Copies.factor_for(sim, centres[1], factor, 1), 1.0),
		"an idle copy does not count against the others"
	)
	check(
		is_equal_approx(Copies.next_factor(sim, "data_center", factor, 1), factor * factor),
		"the forecast for one more counts the working copies"
	)
	var works: Array = []
	for _index: int in range(8):
		var building: Dictionary = _fake("foodworks")
		place.buildings.append(building)
		works.append(building)
	var food_factor: float = float(rules.foodworks_copy_factor)
	var free: int = int(rules.foodworks_free_copies)
	check(
		is_equal_approx(Copies.factor_for(sim, works[free - 1], food_factor, free), 1.0),
		"the free foodworks are paid in full"
	)
	check(
		is_equal_approx(Copies.factor_for(sim, works[free], food_factor, free), food_factor),
		"the first foodworks over the quota is paid less"
	)


func _administration() -> void:
	var sim: RefCounted = make()
	var rules: Dictionary = sim.config.economy
	var place: Dictionary = sim.state.settlements[0]
	place.population = 3000
	var saved: float = sim.Research.bonus(sim, "admin")
	for s: Dictionary in sim.state.settlements:
		saved += Population.service_total(sim, s, "admin")
	var crowding: float = 3000.0 / float(rules.admin_resident_scale)
	var expected: float = (
		maxf(0.3, 1.0 + saved)
		* (
			float(rules.admin)
			+ float(rules.admin_per_resident) * 3000.0 * (1.0 + crowding)
			+ float(rules.admin_per_settlement) * sim.state.settlements.size()
		)
	)
	check(
		is_equal_approx(sim._admin_cost(), expected), "administration grows with the colony's size"
	)


func _market_floor() -> void:
	var sim: RefCounted = make()
	sim.state.market.saturation.ore = 1.0e9
	check(
		is_equal_approx(Market.factor(sim, "ore"), float(sim.market_rules.floor)),
		"a flooded market pays the floor"
	)
	check(float(sim.market_rules.floor) < 0.6, "the floor is below 1.8's")


func _services() -> void:
	var sim: RefCounted = make()
	var place: Dictionary = sim.state.settlements[0]
	var before: float = float(Population.attractiveness(sim, place).value)
	fund(sim, 1.0e6)
	sim.act("policy", {"services": 2})
	check(int(sim.state.policy.services) == 2, "the policy sets the level")
	sim.act("policy", {"services": 9})
	check(
		int(sim.state.policy.services) == int(sim.pop_rules.services.levels),
		"the level is clamped to the table"
	)
	sim.act("policy", {"services": 2})
	var cost: float = Population.services_cost(sim, 2)
	var cash: float = float(sim.state.cash)
	sim.tick()
	var paid: float = 0.0
	for entry: Dictionary in sim.state.ledger:
		if (
			str(entry.key) == "services.budget"
			and int(entry.get("day", sim.state.day)) == int(sim.state.day)
		):
			paid += float(entry.amount)
	check(is_equal_approx(paid, cost) and cost > 0.0, "a day's budget is paid per resident")
	check(Population.services_level(sim) == 2, "the paid level works today")
	var parts: Dictionary = Population.attractiveness(sim, place).parts
	check(
		is_equal_approx(float(parts.get("budget", 0.0)), float(sim.pop_rules.services.appeal[2])),
		"the budget shows in the attractiveness breakdown"
	)
	check(
		float(Population.attractiveness(sim, place).value) > before - 1.0,
		"attractiveness still computes"
	)
	check(
		is_equal_approx(
			Population.services_effect(sim, "departures"),
			float(sim.pop_rules.services.departures[2])
		),
		"fewer people leave"
	)
	drain(sim)
	sim.tick()
	check(Population.services_level(sim) == 0, "an unpaid day has no effect and makes no debt")
	check(sim.audit().is_empty(), "the ledger balances with the budget")
	check(cash > 0.0, "the colony had cash to start with")


func _services_save() -> void:
	var sim: RefCounted = make()
	fund(sim, 1.0e6)
	sim.act("policy", {"services": 3})
	sim.tick()
	var error: String = sim.save_game(SAVE_PATH)
	check(error == "", "a game with a services budget saves")
	var loaded: RefCounted = Sim.new()
	var load_error: String = loaded.load_game(SAVE_PATH)
	check(load_error == "", "and loads: " + load_error)
	if load_error != "":
		return
	check(int(loaded.state.policy.get("services", -1)) == 3, "the level survives the round trip")
	var old: RefCounted = make()
	old.state.policy.erase("services")
	Population.ensure_state(old.state)
	check(int(old.state.policy.services) == 0, "a 1.8 state gets the budget switched off")


func _cover() -> void:
	var sim: RefCounted = make()
	var rules: Dictionary = sim.config.economy
	for _day: int in range(5):
		sim.tick()
	var view: Dictionary = sim.cover_view()
	var history: Array = sim.state.operating_history
	var spent: float = 0.0
	for entry: Dictionary in history:
		spent += float(entry.expense)
	var mean: float = spent / history.size()
	check(
		is_equal_approx(float(view.cover), float(sim.state.cash) / maxf(1.0, mean)),
		"cash cover is public cash over the mean daily operating expense"
	)
	check(int(view.days) == history.size(), "cover counts the days seen so far")
	check(is_equal_approx(sim.cash_cover(), float(view.cover)), "the bots read the same cover")
	check(str(view.band) != Keys.COVER_IDLE, "money is not called idle before a full window")
	fund(sim, 1.0e8)
	for _day: int in range(int(rules.cover_window_days)):
		sim.tick()
	view = sim.cover_view()
	check(int(view.days) == int(rules.cover_window_days), "the window stops at its length")
	check(
		float(view.cover) >= float(rules.cover_idle_days) and str(view.band) == Keys.COVER_IDLE,
		"a full window with a large pile is idle money"
	)
	drain(sim)
	check(str(sim.cover_view().band) == Keys.COVER_SHORT, "an empty account is short")
	check(sim.audit().is_empty(), "the ledger balances after the cover days")


func _admin_view() -> void:
	var sim: RefCounted = make()
	var rules: Dictionary = sim.config.economy
	var place: Dictionary = sim.state.settlements[0]
	place.population = 1200
	var view: Dictionary = sim.admin_view()
	check(is_equal_approx(float(view.daily), sim._admin_cost()), "the line shows today's cost")
	check(
		int(view.residents_step) == int(rules.admin_preview_residents),
		"the resident step comes from the rules"
	)
	var today: float = sim._admin_cost()
	place.population += int(view.residents_step)
	check(
		is_equal_approx(sim._admin_cost() - today, float(view.per_residents)),
		"what more residents add is what they would cost"
	)
	place.population -= int(view.residents_step)
	var saved: float = sim.Research.bonus(sim, "admin")
	for s: Dictionary in sim.state.settlements:
		saved += Population.service_total(sim, s, "admin")
	var places: int = sim.state.settlements.size()
	var growth: float = float(rules.admin_settlement_growth)
	var expected: float = (
		maxf(0.3, 1.0 + saved)
		* float(rules.admin_per_settlement)
		* ((places + 1) * (1.0 + growth * places) - places * (1.0 + growth * (places - 1)))
	)
	check(
		is_equal_approx(float(view.per_settlement), expected),
		"one more settlement costs its share and the growth on the others"
	)


func _market_row(sim: RefCounted, good: String) -> Dictionary:
	for row: Dictionary in sim.market_view():
		if str(row.good) == good:
			return row
	return {}


func _market_view() -> void:
	var sim: RefCounted = make()
	var row: Dictionary = _market_row(sim, "ore")
	check(not row.is_empty() and not bool(row.at_floor), "a fresh market is above its floor")
	check(
		is_equal_approx(float(row.price), Market.price(sim, "ore")),
		"the page shows the price exports get"
	)
	var ahead: float = float(sim.market_rules.preview_tonnes)
	check(
		is_equal_approx(
			float(row.ahead_price),
			Market.price_at(sim, "ore", Market.factor_at(sim, "ore", float(row.saturation) + ahead))
		),
		"the price ahead is the price after another preview_tonnes are sold"
	)
	check(float(row.ahead_price) < float(row.price), "selling more lowers the price ahead")
	sim.state.market.saturation.ore = 1.0e9
	row = _market_row(sim, "ore")
	check(bool(row.at_floor), "a flooded market is at its floor")
	check(is_equal_approx(float(row.price), float(row.floor_price)), "and sells at the floor price")


## One ore seam with a mine on it, and one day of exports in the stats.
func _mine_outlook() -> void:
	var sim: RefCounted = make()
	var rules: Dictionary = sim.config.economy
	var place: Dictionary = sim.state.settlements[0]
	place.buildings.clear()
	var plots: Array = sim.state.world.regions[int(place.region)].plots
	var seam: Dictionary = {
		"kind": "deposit", "resource": "ore", "grade": 1.0, "reserves": 1.0, "depth": 0
	}
	plots.append(seam)
	var mine: Dictionary = _fake("mine_ore")
	mine.plot = plots.size() - 1
	place.buildings.append(mine)
	var unplaced: Dictionary = _fake("mine_copper")
	place.buildings.append(unplaced)
	# The civic service slot is a building without an entry in the building rules.
	place.buildings.append(_fake("service"))
	Stats.goods(sim.state, "ore", Stats.EXPORTED, 100.0)
	Stats.close_day(sim.state)
	var outlook: Dictionary = sim.mine_outlook(sim.stats_window(30))
	check(
		is_equal_approx(float(outlook.share), 1.0),
		"all export income comes from a mine about to run out"
	)
	check(
		float(outlook.share) >= float(rules.mine_warning_share), "which is past the warning share"
	)
	check(int(unplaced.plot) == -1, "the outlook does not give a mine without a plot one")
	Stats.goods(sim.state, "parts", Stats.EXPORTED, 100.0)
	Stats.close_day(sim.state)
	outlook = sim.mine_outlook(sim.stats_window(30))
	var ore: float = 100.0 * Market.price(sim, "ore")
	var parts: float = 100.0 * Market.price(sim, "parts")
	check(
		is_equal_approx(float(outlook.share), ore / (ore + parts)),
		"other exports dilute the share by their value"
	)
	seam.reserves = 1.0e9
	outlook = sim.mine_outlook(sim.stats_window(30))
	check(float(outlook.share) == 0.0, "a seam with years left is no risk")
	seam.reserves = 1.0
	mine.enabled = false
	outlook = sim.mine_outlook(sim.stats_window(30))
	check(float(outlook.share) == 0.0, "a mine switched off earns nothing to lose")
	mine.enabled = true
	place.buildings.append(_fake("processor"))
	outlook = sim.mine_outlook(sim.stats_window(30))
	check(
		is_equal_approx(float(outlook.share), 1.0),
		"parts made from the dying seam's ore are at risk with it"
	)
	place.buildings.append(_fake("tailings_plant"))
	outlook = sim.mine_outlook(sim.stats_window(30))
	check(
		float(outlook.share) > 0.0 and float(outlook.share) < 1.0,
		"ore from tailings, which never run out, dilutes the risk"
	)


## Spending by sink: each payment from public cash lands in its year and its sink.
func _sinks() -> void:
	var sim: RefCounted = make()
	fund(sim, 1.0e6)
	var region: int = int(sim.state.settlements[0].region)
	var built: String = sim.act("build", {"region": region, "kind": "farm"})
	var years: Array = sim.sinks_by_year()
	check(
		built == "" and float(years[0].get(Keys.SINK_BUILDINGS, 0.0)) > 0.0,
		"building lands under buildings in year 1: " + built
	)
	sim._transfer("public", "external", 100.0, "invest.build", false, "university")
	check(
		is_equal_approx(float(sim.sinks_by_year()[0].get(Keys.SINK_GREAT_WORKS, 0.0)), 100.0),
		"a great work's construction lands under great works"
	)
	sim._transfer("public", "external", 40.0, "invest.upgrade", false, "university")
	check(
		is_equal_approx(float(sim.sinks_by_year()[0].get(Keys.SINK_GREAT_WORKS, 0.0)), 140.0),
		"and so does its upgrade"
	)
	sim._transfer("public", "external", 25.0, "import.food", true)
	var keys: int = sim.sinks_by_year()[0].size()
	check(keys == 2, "running costs are not a sink")
	sim.state.day = 400
	sim._transfer("public", "external", 60.0, "recruit", false, "workers")
	years = sim.sinks_by_year()
	check(
		years.size() == 2 and is_equal_approx(float(years[1].get("recruitment", 0.0)), 60.0),
		"day 400 is the second year"
	)
	check(Stats.validate(sim.state) == "", "a state with sinks validates")
	var broken: Dictionary = sim.state.duplicate(true)
	broken.stats.sinks = [{"buildings": "lots"}]
	check(Stats.validate(broken) != "", "a sink that is not a number is refused")
	check(sim.audit().is_empty(), "the ledger balances")


## Career transfer: after the award only, 2 : 1, capped a colony year, never into debt.
func _career_transfer() -> void:
	var sim: RefCounted = make()
	var rules: Dictionary = sim.Career.cfg().transfer
	fund(sim, 1.0e6)
	check(sim.act("career_transfer", {"amount": 1000.0}) != "", "no transfer before the award")
	sim.state.status = "success"
	var cash: float = float(sim.state.cash)
	var balance: float = float(sim.state.career.balance)
	check(sim.act("career_transfer", {"amount": 1000.0}) == "", "a transfer after the award")
	check(
		is_equal_approx(cash - float(sim.state.cash), 1000.0 * float(rules.public_per_career)),
		"public cash pays the rate"
	)
	check(
		is_equal_approx(float(sim.state.career.balance) - balance, 1000.0),
		"the career balance receives the amount"
	)
	check(
		is_equal_approx(
			float(sim.sinks_by_year()[0].get("transfer", 0.0)),
			1000.0 * float(rules.public_per_career)
		),
		"the transfer is a sink"
	)
	var room: float = float(sim.Career.transfer_preview(sim).room)
	check(is_equal_approx(room, float(rules.yearly_cap) - 1000.0), "the year's room shrinks")
	check(sim.act("career_transfer", {"amount": room + 1.0}) != "", "the cap holds")
	check(sim.act("career_transfer", {"amount": room}) == "", "up to the cap")
	check(sim.audit().is_empty(), "the ledger balances")
	var career_error: String = sim.Career.validate(sim.state)
	check(career_error == "", "the career record stays conserved: " + career_error)
	var tampered: Dictionary = sim.state.duplicate(true)
	tampered.career.transferred = float(tampered.career.transferred) + 5.0
	check(sim.Career.validate(tampered) != "", "a tampered transfer total is refused")
	# The year by the colony's own clock; the career clock is not part of this check.
	sim.state.day = 360
	check(
		is_equal_approx(float(sim.Career.transfer_preview(sim).room), float(rules.yearly_cap)),
		"a new colony year opens the cap again"
	)
	drain(sim)
	check(sim.act("career_transfer", {"amount": 10.0}) != "", "no transfer without the cash")


func _ledger_today(sim: RefCounted, key: String) -> float:
	var total: float = 0.0
	for entry: Dictionary in sim.state.ledger:
		if str(entry.key) == key and int(entry.day) == int(sim.state.day):
			total += float(entry.amount)
	return total


## Commissioned research on a colony whose labs are at work: the research-first bot plays 150 days
## with its own commissions off, then the test drives them.
func _commissions() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "science", 1, "normal")
	sim.state.events_v2.next_draw = 99999
	var bot: RefCounted = ResearchBot.new()
	bot.uses_commissions = false
	bot.begin(sim, SEED)
	for _day: int in range(150):
		bot.on_day()
		sim.tick()
	var rules: Dictionary = sim.progression.research.commission
	var working: Array = []
	for key: String in sim.state.research.projects:
		if int(sim.state.research.projects[key].effective) > 0:
			working.append(key)
	check(working.size() >= 2, "the labs run two projects to commission: %d" % working.size())
	if working.size() < 2:
		return
	fund(sim, 1.0e7)
	var first: String = working[0]
	var second: String = working[1]
	var quote: Dictionary = Research.commission_quote(sim, first, 1)
	var p: Dictionary = sim.state.research.projects[first]
	check(
		is_equal_approx(float(quote.extra), float(p.rate) * float(rules.speedup[1])),
		"level 1 adds half the team's own points"
	)
	check(
		is_equal_approx(
			float(quote.cost),
			(
				float(quote.extra)
				* float(rules.price_per_point_by_tier[int(sim.config.techs[first].tier) - 1])
			)
		),
		"priced by the project's tier"
	)
	check(int(quote.days_saved) > 0, "and it saves days")
	check(sim.act("research_commission", {"tech": first, "level": 1}) == "", "commissioned")
	var work: float = float(p.work)
	sim.tick()
	var paid: float = _ledger_today(sim, "research.commission")
	check(paid > 0.0, "the day's commission is paid")
	check(
		float(p.work) > work + float(p.rate) * 1.4,
		"the project gains its team's points and the commission's"
	)
	check(
		float(sim.sinks_by_year()[0].get("commissions", 0.0)) >= paid,
		"commissions are a spending sink"
	)
	var crowded: Dictionary = Research.commission_quote(sim, second, 1)
	check(
		is_equal_approx(
			float(crowded.cost) / float(crowded.extra),
			Research.commission_price(sim, second, 0) * (1.0 + float(rules.crowding))
		),
		"each other commission makes points dearer"
	)
	check(sim.act("research_commission", {"tech": second, "level": 1}) == "", "a second one")
	check(
		sim.act("research_commission", {"tech": first, "level": 9}) != "",
		"no level beyond the table"
	)
	check(sim.act("research_allocate", {"tech": second, "staff": 0}) == "", "team stood down")
	check(
		sim.act("research_commission", {"tech": second, "level": 2}) != "",
		"no commission without a team"
	)
	drain(sim)
	sim.tick()
	check(_ledger_today(sim, "research.commission") == 0.0, "no cash, no commission today")
	check(
		(
			float(sim.progression.research.contract_point_price)
			< float(rules.price_per_point_by_tier[0])
		),
		"selling points stays cheaper than buying them"
	)
	check(sim.audit().is_empty(), "the ledger balances")


## A 1.8 save (schema 4, none of the 1.9 fields) loads, gets the defaults and a log line, plays
## on, and its file is not touched.
func _old_schema_save() -> void:
	var sim: RefCounted = make()
	for _day: int in range(3):
		sim.tick()
	var old: Dictionary = sim.state.duplicate(true)
	old.schema = 4
	old.policy.erase("services")
	old.policy.erase("services_paid_day")
	old.stats.erase("sinks")
	for key: String in ["transferred", "transfer_year", "transfer_year_total"]:
		old.career.erase(key)
	for project: Dictionary in old.research.projects.values():
		project.erase("commission")
	var path: String = "user://v19_from_1_8.save"
	var snap: Dictionary = SaveIo.snapshot(sim, path)
	snap.raw = var_to_bytes(old)
	snap.header.version = 4
	check(SaveIo.write_snapshot(snap) == "", "a schema 4 file is written")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var loaded: RefCounted = Sim.new()
	var error: String = loaded.load_game(path)
	check(error == "", "a 1.8 save loads: " + error)
	if error != "":
		return
	check(int(loaded.state.schema) == SaveIo.SCHEMA, "and is brought to schema 5")
	check(int(loaded.state.policy.get("services", -1)) == 0, "with the services budget off")
	check(loaded.state.stats.get("sinks") is Array, "with an empty spending record")
	check(
		str(loaded.state.log.back().text).begins_with("1.8 存档按 1.9 规则继续经营"),
		"the log says it now plays by 1.9 rules"
	)
	check(loaded.Career.validate(loaded.state) == "", "the career record is valid")
	loaded.tick()
	check(loaded.audit().is_empty(), "it plays on with a balanced ledger")
	check(FileAccess.get_file_as_bytes(path) == before, "the 1.8 file is left as it was")
	var again: String = "user://v19_from_1_8_again.save"
	check(loaded.save_game(again) == "", "it saves")
	check(
		int(SaveIo.read_header(again).get("version", 0)) == SaveIo.SCHEMA,
		"as a schema 5 file of its own"
	)


## A finished great work in the first settlement, at a level; the day's effect totals refreshed.
func _place_work(sim: RefCounted, kind: String, level: int) -> Dictionary:
	var work: Dictionary = _fake(kind)
	work.level = level
	work.upgrade_days = 0
	sim.state.settlements[0].buildings.append(work)
	sim.great_effects_day = -1
	return work


## The late great works (plan A2.7): unlocked by tier 4-5 technologies, each with its effect.
func _great_works() -> void:
	var sim: RefCounted = make()
	var place: Dictionary = sim.state.settlements[0]
	var region: int = int(place.region)
	var rules: Dictionary = sim.config.megaprojects
	for kind: String in LATE_WORKS:
		var tech: String = str(sim.config.buildings[kind].requires_tech)
		check(
			int(sim.config.techs[tech].tier) >= 4 and bool(sim.config.buildings[kind].megaproject),
			"%s is a great work unlocked in tier 4-5" % kind
		)
		check(kind in Megaprojects.KINDS, "%s counts toward the great works milestone" % kind)
	check(sim.config.techs.size() >= 100, "the pool keeps at least 100 technologies")
	sim.state.research.completed.append("capital_district")
	fund(sim, 1.0e6)
	var refusal: String = Production.build_refusal(sim, region, "capital_district")
	check(
		refusal.contains(str(sim.config.buildings.capital_hall.name)),
		"the capital district needs the capital hall in its town: " + refusal
	)
	# Exchange: every market holds 50% more before the price falls.
	var before: float = Market.factor_at(sim, "ore", 3000.0)
	_place_work(sim, "exchange", 1)
	check(Market.factor_at(sim, "ore", 3000.0) > before, "the exchange deepens the markets")
	# Shipyard: cheaper expeditions and sea routes, faster ships.
	var expedition: float = Sites.expedition_cash(sim)
	var sea_days: int = Logistics.road_days(sim, {"variant": "sea", "days": 10})
	_place_work(sim, "shipyard", 1)
	check(
		is_equal_approx(
			Sites.expedition_cash(sim),
			expedition * (1.0 + float(rules.shipyard.effects.expedition_cost))
		),
		"the shipyard cuts the expedition's cost"
	)
	check(Logistics.road_days(sim, {"variant": "sea", "days": 10}) < sea_days, "ships are faster")
	# Emergency network: fewer closures, smaller losses, shorter closures from events.
	var closure: float = Logistics.closure_chance(sim, {"variant": "engineered"})
	place.stock.food = 500.0
	_place_work(sim, "emergency_net", 1)
	check(
		Logistics.closure_chance(sim, {"variant": "engineered"}) < closure,
		"the emergency network makes closures rarer"
	)
	EventsV2._apply_colony(sim, place, {"lose_goods": {"food": 100.0}})
	check(
		is_equal_approx(
			500.0 - float(place.stock.food),
			100.0 * (1.0 + float(rules.emergency_net.effects.event_losses))
		),
		"and an event takes less"
	)
	# Capital district, level 3: beds, appeal in its town, cheaper administration.
	var admin: float = sim._admin_cost()
	sim.Population.refresh(sim, place)
	var beds: int = int(place.housing)
	_place_work(sim, "capital_district", 3)
	sim.Population.refresh(sim, place)
	check(
		int(place.housing) - beds == 3 * int(rules.capital_district.beds),
		"three district levels add their beds"
	)
	var parts: Dictionary = sim.Population.attractiveness(sim, place).parts
	check(
		is_equal_approx(
			float(parts.get("district", 0.0)), 3 * float(rules.capital_district.appeal)
		),
		"and their appeal shows in the breakdown"
	)
	check(sim._admin_cost() < admin, "and administration costs less")
	# Terraforming, two stages: warmer or cooler toward the comfortable band, wetter, more fertile.
	var reg: Dictionary = sim.state.world.regions[region]
	var shift: Dictionary = Megaprojects.climate(sim, region)
	var work: Dictionary = _place_work(sim, "terraforming", 2)
	var terraformed: Dictionary = Megaprojects.climate(sim, region)
	var gap: float = float(rules.terraforming.comfort_temperature) - float(reg.temperature)
	check(
		(
			absf(float(terraformed.temperature) - float(shift.temperature)) <= 2.0 + 0.0001
			and signf(float(terraformed.temperature) - float(shift.temperature)) == signf(gap)
		),
		"two stages move the climate up to 2 C toward the comfortable band"
	)
	check(
		is_equal_approx(
			float(terraformed.rainfall),
			float(shift.rainfall) * pow(1.0 + float(rules.terraforming.rainfall_step), 2)
		),
		"and bring more rain"
	)
	check(
		is_equal_approx(
			Megaprojects.fertility_bonus(sim), 2.0 * float(rules.terraforming.fertility_step)
		),
		"and richer soil"
	)
	check(
		is_equal_approx(
			float(Production.level_rule(sim, work).get("maintenance", 0.0)),
			float(sim.config.upgrades.terraforming[0].maintenance)
		),
		"the second stage has its own upkeep"
	)
	work.level = 1
	sim.state.research.completed.append("terraforming")
	fund(sim, 1.0e6)
	var index: int = place.buildings.find(work)
	var next: Dictionary = sim.upgrade_preview(region, index)
	check(
		(
			int(next.get("level", 0)) == 2
			and is_equal_approx(float(next.cost), float(sim.config.upgrades.terraforming[0].cost))
		),
		"the next stage is an upgrade at its own price"
	)
	check(Megaprojects.count(sim) >= 5, "five finished kinds count for the milestone")


## The short-range shuttle (1.9): an early, dear, small and fast link that stands down when a road
## between the same two settlements opens, and is not part of the contract's network.
func _shuttle() -> void:
	var sim: RefCounted = make()
	fund(sim, 1.0e6)
	var home: int = int(sim.state.settlements[0].region)
	Production.produce(sim, sim.state.settlements[0], "materials", 500.0, "test")
	# The expedition licence of contract stage 1, so a second settlement may be founded.
	sim.state.contract.licences.append("expedition")
	var spec: Dictionary = sim.config.roads[Keys.ROUTE_SHUTTLE]
	var near: int = -1
	var far: int = -1
	for site: int in range(sim.state.world.regions.size()):
		if site == home:
			continue
		var quote: Dictionary = sim.road_quote(home, site, Keys.ROUTE_SHUTTLE)
		if not bool(quote.reachable):
			far = site if far < 0 else far
			continue
		if near < 0 and sim.road_quote(home, site, "valley").reachable:
			if sim.act("settle", {"site": site, "from": home}) == "":
				near = site
	check(near >= 0, "a settlement within shuttle range")
	check(far >= 0, "and a site beyond it")
	if near < 0:
		return
	check(
		str(sim.road_quote(home, far, Keys.ROUTE_SHUTTLE).reason).contains("航程"),
		"beyond the range the reason says so"
	)
	var quote: Dictionary = sim.road_quote(home, near, Keys.ROUTE_SHUTTLE)
	check(float(quote.distance) <= float(spec.max_km), "within the range")
	check(
		is_equal_approx(
			float(quote.cost),
			float(spec.base_cost) + float(quote.distance) * float(spec.cost_per_km)
		),
		"priced at its base and per kilometre, with no technology needed"
	)
	check(int(quote.build_days) == int(spec.build_days), "its pads are built in days")
	var road: Dictionary = sim.road_quote(home, near, "valley")
	check(int(quote.days) <= int(road.days), "it is at least as fast as the road")
	check(int(quote.capacity) < int(road.capacity) / 4, "and carries a fraction of it")
	check(
		sim.act("connect", {"a": home, "b": near, "variant": Keys.ROUTE_SHUTTLE}) == "",
		"a shuttle line is built"
	)
	check(
		sim.act("connect", {"a": home, "b": near, "variant": Keys.ROUTE_SHUTTLE}) != "",
		"not two of them"
	)
	var line: Dictionary = sim.state.roads.back()
	check(Logistics.largest_connected(sim) == 1, "a shuttle line is not the contract's network")
	check(sim.act("upgrade_road", {"road": int(line.id)}) != "", "and is never paved")
	for _day: int in range(int(spec.build_days) + 2):
		sim.tick()
	check(not sim.WorldGen.road_building(line, int(sim.state.day)), "the pads are ready")
	check(
		sim.Logistics._road_capacity(sim, line) <= float(spec.capacity) + 0.001,
		"it carries its small load"
	)
	var valley: String = sim.act("connect", {"a": home, "b": near, "variant": "valley"})
	check(valley == "", "a road can still be built where the shuttle flies: " + valley)
	var ground: Dictionary = sim.state.roads.back()
	for _day: int in range(int(ground.build_days) + 2):
		sim.tick()
	check(bool(line.get("retired", false)), "when the road opens the shuttle stands down")
	check(
		int(sim.Logistics.road_between(sim, home, near).get("id", -1)) == int(ground.id),
		"and the road is the link between the two"
	)
	var upkeep_before: float = _ledger_today(sim, "road.upkeep")
	sim.tick()
	check(
		_ledger_today(sim, "road.upkeep") <= float(ground.upkeep) + 0.001,
		(
			"the stood-down line costs no upkeep: %.1f then %.1f"
			% [upkeep_before, _ledger_today(sim, "road.upkeep")]
		)
	)
	var issues: Array = sim.audit()
	check(issues.is_empty(), "the ledger balances: " + str(issues).left(300))
