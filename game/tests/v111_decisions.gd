extends SceneTree
## 1.11 "decisions" rules, the simulation side: settlement caps by stage; the one site card's preview
## against the town a founding there finds; a scan that finds nothing; supply orders that buy only
## local produce above the residents' reserve and renew; stock reserves that stop exports and hold a
## planned project's stock; reduced shifts; the checkout's four answers against what then happens;
## order withdrawal accounted once; the contract outlook and the advance stops; event pacing, the
## interruption cap, node-bound choices and the two-town crew diversion; the honest reshuffle; one
## count of assignable research teams. Every run is audited.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Keys = preload("res://simulation/keys.gd")
const Stats = preload("res://simulation/stats.gd")
const SAVE_PATH: String = "user://v111_decisions.save"
## Seed 3's two coasts from the 1.10.1 report: an iron coast and a fertile valley on the sea.
const NORTH: Vector2 = Vector2(39.9747, 122.1984)
const SOUTH: Vector2 = Vector2(-4.9780, 163.5193)

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 1500.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_caps()
	_markers_read_the_card()
	_preview_matches_arrival()
	_scan_finds_nothing()
	_supply_orders()
	_stock_reserve()
	_shifts_and_status()
	_checkout_and_withdraw()
	_outlook_and_advance()
	_goal_choice()
	_events()
	_reshuffle_and_teams()
	print(
		"V111_DECISIONS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)]
	)
	quit(0 if failures.is_empty() else 1)


func _game(seed_value: Variant = "3") -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1, "normal", 1.0)
	return sim


func _run(sim: RefCounted, days: int) -> bool:
	for _day: int in range(days):
		sim.tick()
		var errors: Array = sim.audit()
		if not errors.is_empty():
			check(false, "audit on day %d: %s" % [int(sim.state.day), str(errors)])
			return false
	return true


func _caps() -> void:
	var sim: RefCounted = _game()
	var cap: Dictionary = sim.Contract.cap_view(sim)
	check(
		int(cap.cap) == 2 and int(cap.next_cap) == 3,
		"stage one allows two settlements, capital included"
	)
	check(
		sim.act("settle_at", {"lat": SOUTH.x, "lon": SOUTH.y, "name": "S"}) == "",
		"the capital is founded at the southern coordinate"
	)
	sim.act("build", {"site": int(sim.state.settlements[0].region), "kind": "port"})
	_run(sim, 30)
	# A second town in stage one, before the export goal: the expedition is affordable at once.
	var second: Dictionary = _land_point(sim, sim.state.settlements[0], 9.0, 16.0)
	check(not second.is_empty(), "an eligible unmarked point for the second town")
	var view: Dictionary = sim.Placement.view(
		sim, float(second.lat), float(second.lon), -1, Keys.SITE_FRONTIER
	)
	check(
		str(view.refusal) == "",
		"stage one: the expedition to the second town is allowed (%s)" % str(view.refusal)
	)
	check(
		float(sim.state.exports_total) < 40000.0,
		"the export goal is not yet met when the second town goes"
	)
	check(
		(
			sim.act(
				"settle_at",
				{"lat": second.lat, "lon": second.lon, "kind": Keys.SITE_FRONTIER, "name": "T"}
			)
			== ""
		),
		"the second town is founded in stage one"
	)
	var travelling: Dictionary = sim.state.settlements[-1]
	var waits: bool = int(travelling.get("arrival", 0)) > 0
	for row: Dictionary in sim.Supply.offers(sim, travelling):
		waits = waits and str(row.refusal) != ""
	check(waits, "no supply order is offered to a town still on its way")
	var third: Dictionary = _land_point(sim, sim.state.settlements[0], 9.0, 20.0, [second])
	var refused: Dictionary = sim.Placement.view(sim, float(third.lat), float(third.lon))
	var rule: String = sim.Contract.cap_refusal(sim)
	check(
		rule != "" and str(refused.refusal) == rule,
		"a third is refused with the cap's own words: " + rule
	)
	var unsettled: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if sim.settlement(int(reg.id)).is_empty() and not bool(reg.get("placed", false)):
			unsettled = int(reg.id)
			break
	check(
		sim.Sites.settle_refusal(sim, unsettled, -1) == rule,
		"the recommended-site path gives the same refusal"
	)
	for stage: int in [2, 3, 4, 5]:
		sim.state.contract.stage = stage
		var at: Dictionary = sim.Contract.cap_view(sim)
		var expected: int = [0, 0, 3, 5, sim.Contract.UNLIMITED, sim.Contract.UNLIMITED][stage]
		check(
			int(at.cap) == expected,
			(
				"stage %d allows %s"
				% [stage, "no limit" if expected >= sim.Contract.UNLIMITED else str(expected)]
			)
		)


## A land point `low`..`high` degrees from a town, clear of the given points, that a town may take.
func _land_point(
	sim: RefCounted, from: Dictionary, low: float, high: float, avoid: Array = []
) -> Dictionary:
	var reg: Dictionary = sim.state.world.regions[int(from.region)]
	for ring: float in [low, (low + high) * 0.5, high]:
		for step: int in range(24):
			var angle: float = TAU * step / 24.0
			var lat: float = clampf(float(reg.lat) + ring * sin(angle), -70.0, 70.0)
			var lon: float = wrapf(
				float(reg.lon) + ring * cos(angle) / maxf(0.3, cos(deg_to_rad(lat))), -180.0, 180.0
			)
			var clear: bool = true
			for other: Dictionary in avoid:
				if absf(float(other.lat) - lat) + absf(float(other.lon) - lon) < 8.0:
					clear = false
			if not clear:
				continue
			var view: Dictionary = sim.Placement.view(sim, lat, lon, -1, Keys.SITE_FRONTIER)
			if bool(view.land) and int(view.slots) >= 18 and float(view.relief) < 2500.0:
				if str(view.refusal) == "" or str(view.refusal).begins_with("据点已达"):
					return {"lat": float(view.lat), "lon": float(view.lon)}
	return {}


## A recommended site's marker stands for the site its card shows: the deposits it is filtered and
## ranked by, and the bots' start score, are the card's, not the generator's own draw.
func _markers_read_the_card() -> void:
	var sim: RefCounted = _game("1")
	var same: bool = true
	var scored: bool = true
	for reg: Dictionary in sim.state.world.regions.slice(0, 8):
		var marker: Dictionary = sim.Placement.marker_site(sim, reg)
		var card: Dictionary = sim.Placement.preview(sim, float(reg.lat), float(reg.lon))
		if card.get("minerals", {}).is_empty():
			continue
		for good: String in ["ore", "copper", "crystal"]:
			var truth: float = float(card.minerals[good].truth.tonnes)
			same = same and is_equal_approx(float(marker.deposits.get(good, 0.0)), truth)
		scored = (
			scored
			and is_equal_approx(
				sim.Sites.start_score(sim, int(reg.id)), sim.Placement.site_score(sim, reg)
			)
		)
	check(same, "a marker's deposits are the ones its card shows")
	check(scored, "the start score is the card site's")


## What the card says before founding is what the town finds: plots by type exactly, each mineral's
## tonnage and plots inside the stated band; the coordinate survives a save.
func _preview_matches_arrival() -> void:
	var points: Array = [NORTH, SOUTH]
	var probe: RefCounted = _game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1111
	while points.size() < 8:
		var lat: float = rng.randf_range(-60.0, 60.0)
		var lon: float = rng.randf_range(-180.0, 180.0)
		var view: Dictionary = probe.Placement.view(probe, lat, lon)
		if str(view.refusal) == "":
			points.append(Vector2(lat, lon))
	var inside: int = 0
	var exact: int = 0
	var saved: int = 0
	for point: Vector2 in points:
		var sim: RefCounted = _game()
		var card: Dictionary = sim.Placement.preview(sim, point.x, point.y)
		if sim.act("settle_at", {"lat": point.x, "lon": point.y, "name": "P"}) != "":
			check(false, "founding at %s" % str(point))
			continue
		var s: Dictionary = sim.state.settlements[0]
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		var plots: Dictionary = {"general": 0, "farm": 0, "ore": 0, "copper": 0, "crystal": 0}
		for plot: Dictionary in reg.plots:
			if str(plot.kind) == "deposit":
				if not bool(plot.hidden) and int(plot.depth) == 0:
					plots[str(plot.resource)] += 1
			else:
				plots[str(plot.kind)] += 1
		if (
			int(plots.general) == int(card.plots.general)
			and int(plots.farm) == int(card.plots.farm)
		):
			exact += 1
		var all_inside: bool = true
		for good: String in ["ore", "copper", "crystal"]:
			var mineral: Dictionary = card.minerals[good]
			var tonnes: float = float(reg.deposits[good])
			all_inside = (
				all_inside
				and tonnes >= float(mineral.low) - 0.01
				and tonnes <= float(mineral.high) + 0.01
			)
			all_inside = (
				all_inside
				and int(plots[good]) >= int(mineral.plots_low)
				and int(plots[good]) <= int(mineral.plots_high)
			)
		if all_inside:
			inside += 1
		sim.save_game(SAVE_PATH)
		var again: RefCounted = Sim.new()
		if again.load_game(SAVE_PATH) == "":
			var back: Dictionary = again.state.world.regions[int(again.state.settlements[0].region)]
			if (
				absf(float(back.lat) - snappedf(point.x, 0.0001)) < 0.00006
				and absf(float(back.lon) - snappedf(point.y, 0.0001)) < 0.00006
			):
				saved += 1
	check(
		exact == points.size(),
		(
			"town and farm plots on the card equal the founded town's (%d / %d)"
			% [exact, points.size()]
		)
	)
	check(
		inside == points.size(),
		(
			"every mineral's tonnage and plots fall inside the card's band (%d / %d)"
			% [inside, points.size()]
		)
	)
	check(
		saved == points.size(),
		"the chosen coordinate survives a save and reload (%d / %d)" % [saved, points.size()]
	)
	var card: Dictionary = probe.Placement.preview(probe, SOUTH.x, SOUTH.y)
	var keys: Array = []
	for plan: Dictionary in card.plans:
		keys.append(str(plan.key))
	check(
		keys.has("food") and keys.has("catch"),
		"the fertile southern coast offers the food and catch contracts: %s" % str(keys)
	)
	check(not keys.has("mine"), "it shows no mining plan where there is no ore")
	var north: Dictionary = probe.Placement.preview(probe, NORTH.x, NORTH.y)
	var mines: Array = north.plans.filter(
		func(plan: Dictionary) -> bool: return str(plan.key) == "mine"
	)
	check(
		not mines.is_empty() and str(north.minerals.ore.signal_word) == "强",
		"the iron coast's strong signal supports a mining plan"
	)
	for plan: Dictionary in card.plans + north.plans:
		var ok: bool = (
			not plan.needs.is_empty()
			and int(plan.first_day) > 0
			and float(plan.per_day) > 0.0
			and plan.has("goal")
		)
		check(
			ok,
			"plan %s names its facilities, first shipment and the charter goal" % str(plan.title)
		)


## An orbital scan of one resource that finds nothing says so on the card for that resource only.
func _scan_finds_nothing() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": SOUTH.x, "lon": SOUTH.y, "name": "S"})
	var before: Dictionary = sim.Placement.preview(sim, SOUTH.x + 2.0, SOUTH.y)
	check(
		(
			sim.act("prospect_observe", {"resource": "ore", "lat": SOUTH.x + 2.0, "lon": SOUTH.y})
			== ""
		),
		"an iron scan is ordered"
	)
	_run(sim, 4)
	var after: Dictionary = sim.Placement.preview(sim, SOUTH.x + 2.0, SOUTH.y)
	var ore: Dictionary = after.minerals.ore
	check(str(ore.level) == "scan", "the scan is the iron estimate's source now")
	if float(ore.truth.tonnes) <= 0.0:
		check(bool(ore.none_detected), "no iron found: the card says the survey detected none")
	check(
		str(after.minerals.copper.level) == str(before.minerals.copper.level),
		"copper's estimate is untouched by the iron scan"
	)
	var logged: bool = false
	for line: Dictionary in sim.state.log:
		logged = logged or str(line.text).contains("未探测到") or str(line.text).contains("异常")
	check(logged, "the scan's report is logged")


## Food grown or landed here is bought; imported food is not; the residents' reserve stays.
func _supply_orders() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": SOUTH.x, "lon": SOUTH.y, "name": "S"})
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	var early: String = sim.act("supply_sign", {"site": region, "kind": "food"})
	check(early.contains("温室农场"), "no farm standing or ordered: the order waits: " + early)
	sim.act("build", {"site": region, "kind": "farm"})
	sim.act("build", {"site": region, "kind": "harbor"})
	check(
		sim.act("supply_sign", {"site": region, "kind": "food"}) == "",
		"the food supply contract is signed once a farm is ordered"
	)
	check(
		sim.act("supply_sign", {"site": region, "kind": "catch"}) == "",
		"the catch contract is signed once a harbour is ordered"
	)
	check(
		sim.act("supply_sign", {"site": region, "kind": "food"}) != "",
		"a second food contract is refused"
	)
	var building: int = mini(
		int(sim.config.buildings.farm.days), int(sim.config.buildings.harbor.days)
	)
	_run(sim, building - 2)
	check(
		float(sim.state.exports_total) == 0.0,
		(
			"nothing grown or landed yet: nothing is paid for imported food (exports ¥%.0f)"
			% float(sim.state.exports_total)
		)
	)
	var low_stock: float = INF
	for _day: int in range(150):
		sim.tick()
		low_stock = minf(
			low_stock,
			float(s.stock.food) + float(s.population) * float(sim.config.economy.food_per_person)
		)
	check(sim.audit().is_empty(), "audited after 150 days of deliveries")
	var keep: float = sim.Stocks.keep(sim, s, "food")
	check(
		low_stock >= keep * 0.9,
		"the residents' reserve stayed (lowest %.0f against %.0f)" % [low_stock, keep]
	)
	var paid: float = 0.0
	var renewed: bool = false
	for order: Dictionary in sim.state.supply.orders:
		paid += float(order.paid)
		renewed = renewed or int(order.round) > 1
	check(
		paid > 0.0 and absf(paid - float(sim.state.exports_total)) < 1.0,
		"every delivery is an export receipt (¥%.0f)" % paid
	)
	check(renewed, "orders renew")
	var grew: bool = false
	for order: Dictionary in sim.state.supply.orders:
		if str(order.status) == "filled":
			for other: Dictionary in sim.state.supply.orders:
				if str(other.kind) == str(order.kind) and int(other.round) == int(order.round) + 1:
					grew = grew or float(other.size) > float(order.size)
	check(grew, "a filled order renews larger")
	var month: Dictionary = sim.Supply.sales(s, int(sim.state.day), 30)
	check(
		float(month.supply) > 0.0 and float(month.local) > 0.0,
		"the town keeps supply receipts apart from local sales"
	)


## A reserve above the stock stops ordinary exports of that good; the warehouse fills; the figure
## the trade sells is the availability the pages quote.
func _stock_reserve() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": NORTH.x, "lon": NORTH.y, "name": "N"})
	sim.Crews.unlimited(sim)
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	for kind: String in ["mine_ore", "mine_ore", "processor", "power"]:
		sim.act("build", {"site": region, "kind": kind})
	s.stock.copper = 300.0
	sim.state.resource_sources.copper = float(sim.state.resource_sources.copper) + 300.0
	# The factory's copper stays home: a reserve keeps it from being sold.
	check(
		sim.act("stock_rule", {"region": region, "resource": "copper", "reserve": 300.0}) == "",
		"copper kept for the factory"
	)
	_run(sim, 60)
	var sold_before: Dictionary = sim.Supply.sales(s, int(sim.state.day), 30)
	check(
		float(sold_before.goods.get("materials", 0.0)) > 0.0,
		"with automatic controls the town sells its processed materials"
	)
	for good: String in ["materials", "parts"]:
		check(
			sim.act("stock_rule", {"region": region, "resource": good, "reserve": 500.0}) == "",
			"reserve 50,000 t of %s" % good
		)
	var held_from: float = float(s.stock.materials)
	_run(sim, 30)
	var month: Dictionary = sim.Supply.sales(s, int(sim.state.day), 30)
	check(
		(
			float(month.goods.get("materials", 0.0)) == 0.0
			and float(month.goods.get("parts", 0.0)) == 0.0
		),
		"below the reserve no materials or parts are exported (%s)" % JSON.stringify(month.goods)
	)
	check(
		float(s.stock.materials) > held_from,
		"the warehouse accumulates output (%.0f → %.0f)" % [held_from, float(s.stock.materials)]
	)
	var row: Dictionary = sim.Stocks.availability(sim, s, "materials")
	check(
		float(row.sellable) == 0.0 and float(row.keep) == 500.0,
		(
			"availability: total %.0f, held %.0f, sellable %.0f"
			% [float(row.total), float(row.held_total), float(row.sellable)]
		)
	)
	check(
		sim.Production.target(sim, s, "materials") >= 500.0,
		"the slowdown level rises to the reserve"
	)
	check(
		sim.act("reserve_for", {"region": region, "kind": "lab"}) == "",
		"one action holds a planned project's stock"
	)
	var planned: bool = false
	for entry: Dictionary in sim.Stocks.availability(sim, s, "materials").held:
		planned = planned or str(entry.key) == "planned"
	check(planned, "the planned project shows among what is held")
	sim.act("build", {"site": region, "kind": "lab"})
	check(s.reservations.is_empty(), "ordering the project ends its hold")


func _shifts_and_status() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": SOUTH.x, "lon": SOUTH.y, "name": "S"})
	sim.Crews.unlimited(sim)
	var s: Dictionary = sim.state.settlements[0]
	sim.act("build", {"site": int(s.region), "kind": "farm"})
	sim.act("stock_rule", {"region": int(s.region), "resource": "food", "slowdown": 1.0})
	_run(sim, 32)
	var farm: Dictionary = {}
	for b: Dictionary in s.buildings:
		if str(b.kind) == "farm":
			farm = b
	var view: Dictionary = sim.Production.facility_view(sim, s, farm)
	check(
		bool(view.idle) and str(view.status) == Keys.B_TARGET_FULL,
		"a farm at the slowdown level stands idle"
	)
	check(
		int(view.retained) > 0 and float(view.output) == 0.0,
		"its status: %d workers retained, output today 0" % int(view.retained)
	)
	check(
		bool(view.reduced) and float(view.wages) < float(view.full_wages),
		(
			"it works reduced shifts (¥%.1f against ¥%.1f)"
			% [float(view.wages), float(view.full_wages)]
		)
	)
	var employment: Dictionary = sim.Population.employment_view(sim, s)
	check(
		int(employment.retained_idle) >= int(view.retained),
		"the town counts staff kept at idle facilities apart"
	)
	sim.act("stock_rule", {"region": int(s.region), "resource": "food", "slowdown": -1.0})
	_run(sim, 2)
	view = sim.Production.facility_view(sim, s, farm)
	check(
		not bool(view.reduced) and float(view.output) > 0.0,
		"demand returns: full shifts and output again"
	)


## The order screen's answers hold: cash taken equals cash quoted; the crew, place and dates hold;
## a withdrawal before work returns cash and stock once.
func _checkout_and_withdraw() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": NORTH.x, "lon": NORTH.y, "name": "N"})
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	_run(sim, 3)
	var first: Dictionary = sim.checkout(region, "mine_ore")
	var cash: float = float(sim.state.cash)
	sim.act("build", {"site": region, "kind": "mine_ore"})
	check(
		absf(cash - float(sim.state.cash) - float(first.cash_now)) < 0.01,
		"the cash taken is the cash quoted (¥%.0f)" % float(first.cash_now)
	)
	sim._consume(s, "materials", float(s.stock.materials))
	sim._consume(s, "parts", float(s.stock.parts))
	var second: Dictionary = sim.checkout(region, "power")
	check(
		float(second.bought) > 0.0,
		"missing stock bought at import price is in the total (¥%.0f)" % float(second.bought)
	)
	cash = float(sim.state.cash)
	sim.act("build", {"site": region, "kind": "power"})
	check(
		absf(cash - float(sim.state.cash) - float(second.cash_now)) < 0.01, "…and taken as quoted"
	)
	var plan: Dictionary = second.crew
	check(
		int(plan.crew) > 0 and int(plan.place) >= 2,
		"the second order waits for the same crew, place %d" % int(plan.place)
	)
	var uid: int = int(s.buildings.back().uid)
	var started: int = -1
	var finished: int = -1
	for _day: int in range(80):
		sim.tick()
		var index: int = sim.Production.index_of(s, uid)
		var b: Dictionary = s.buildings[index]
		if started < 0 and int(b.remaining) < int(b.total_days):
			started = int(sim.state.day)
		if finished < 0 and int(b.remaining) <= 0:
			finished = int(sim.state.day)
	check(
		started == int(plan.start) and finished == int(plan.finish),
		(
			"it starts and enters service as quoted (%d→%d, quoted %d→%d)"
			% [started, finished, int(plan.start), int(plan.finish)]
		)
	)
	# Withdrawal.
	var before_cash: float = float(sim.state.cash)
	var before_materials: float = float(s.stock.materials)
	sim.act("build", {"site": region, "kind": "habitat"})
	var paid: Dictionary = s.buildings.back().paid
	var withdrawn: int = int(s.buildings.back().uid)
	check(
		sim.act("withdraw", {"site": region, "uid": withdrawn}) == "",
		"an unstarted order is withdrawn"
	)
	check(
		absf(float(sim.state.cash) - (before_cash - float(paid.bought))) < 0.01,
		"its cash comes back once, what was bought in stays as stock"
	)
	var expected: float = maxf(before_materials, float(paid.materials))
	check(
		absf(float(s.stock.materials) - expected) < 0.01,
		"its materials are back in the warehouse (%.1f)" % float(s.stock.materials)
	)
	check(
		sim.act("withdraw", {"site": region, "uid": withdrawn}) != "",
		"it cannot be withdrawn twice"
	)
	check(sim.audit().is_empty(), "audited after the withdrawal")
	sim.act("build", {"site": region, "kind": "habitat"})
	var busy: int = int(s.buildings.back().uid)
	_run(sim, 40)
	var index: int = sim.Production.index_of(s, busy)
	if (
		index >= 0
		and int(s.buildings[index].remaining) > 0
		and int(s.buildings[index].remaining) < int(s.buildings[index].total_days)
	):
		check(
			sim.act("withdraw", {"site": region, "uid": busy}) != "",
			"a started order cannot be withdrawn"
		)


func _outlook_and_advance() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": NORTH.x, "lon": NORTH.y, "name": "N"})
	var region: int = int(sim.state.settlements[0].region)
	sim.act("build", {"site": region, "kind": "mine_ore"})
	_run(sim, 60)
	var outlook: Dictionary = sim.outlook_view()
	var exports: Dictionary = {}
	for row: Dictionary in outlook.goals:
		if str(row.key) == "exports_total":
			exports = row
	check(
		not exports.is_empty() and str(exports.status) in ["on_track", "late", "needs_action"],
		"the export goal has a status: %s" % str(exports.get("status", ""))
	)
	if float(exports.get("per_day", 0.0)) > 0.0:
		check(
			int(exports.eta) > int(sim.state.day),
			"with exports flowing it has a date (%d)" % int(exports.eta)
		)
	var towns: Array = sim.Outlook.candidates(sim, "exports")
	check(
		towns.size() == 1 and int(towns[0].region) == region,
		"the export action opens the capital: %s" % str(towns)
	)
	var run: Dictionary = sim.Advance.begin(sim, "days30")
	var reason: String = ""
	for _day: int in range(40):
		sim.tick()
		reason = sim.Advance.stop_reason(sim, run)
		if reason != "":
			break
	check(
		reason != "" and int(sim.state.day) - int(run.day) <= 30,
		"advance stops by the milestone or earlier: %s" % reason
	)
	var summary: Dictionary = sim.Advance.summary(sim, run, reason)
	check(int(summary.to) > int(summary.from), "the run has a summary of what happened")


## With several towns able to carry out a goal's action, the choice lists each with why it
## qualifies; a town still on its way is not offered.
func _goal_choice() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": SOUTH.x, "lon": SOUTH.y, "name": "S"})
	var capital: Dictionary = sim.state.settlements[0]
	sim.act("build", {"site": int(capital.region), "kind": "port"})
	sim.act("build", {"site": int(capital.region), "kind": "farm"})
	_run(sim, 30)
	var point: Dictionary = _land_point(sim, capital, 9.0, 16.0)
	sim.act(
		"settle_at",
		{"lat": point.get("lat", 0.0), "lon": point.get("lon", 0.0), "kind": Keys.SITE_FRONTIER}
	)
	check(sim.state.settlements.size() == 2, "a second town is founded for the choice")
	if sim.state.settlements.size() < 2:
		return
	var second: Dictionary = sim.state.settlements[1]
	var offered: Array = sim.Outlook.candidates(sim, "exports")
	var regions: Array = []
	for row: Dictionary in offered:
		regions.append(int(row.region))
	check(
		not regions.has(int(second.region)),
		"a town still on its way is not offered (%s)" % str(regions)
	)
	for _day: int in range(120):
		if int(second.get("arrival", 0)) <= 0:
			break
		sim.tick()
	sim.act("build", {"site": int(second.region), "kind": "farm"})
	sim.act("build", {"site": int(second.region), "kind": "port"})
	offered = sim.Outlook.candidates(sim, "exports")
	var reasons: bool = not offered.is_empty()
	for row: Dictionary in offered:
		reasons = reasons and str(row.get("why", "")) != ""
	check(
		offered.size() == 2,
		"both towns can carry out the export goal (%d offered)" % offered.size()
	)
	check(reasons, "each offered town says why: %s" % str(offered))


func _events() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": NORTH.x, "lon": NORTH.y, "name": "N"})
	check(int(sim.state.events_v2.next_draw) >= 75, "no drawn event before day 75")
	var forced_days: Array = []
	for _day: int in range(360):
		sim.tick()
		for inst: Dictionary in sim.state.events_v2.instances:
			if int(inst.created_day) == int(sim.state.day) and bool(inst.pause_required):
				forced_days.append(int(sim.state.day))
	var worst: int = 0
	for day: int in forced_days:
		var within: int = (
			forced_days
			. filter(func(other: int) -> bool: return other >= day and other < day + 30)
			. size()
		)
		worst = maxi(worst, within)
	check(
		worst <= 2, "at most two forced interruptions in any 30 days of the first year (%d)" % worst
	)
	check(sim.audit().is_empty(), "audited through a year of events")
	# A choice answers the step it was shown for.
	var definitions: Dictionary = sim.EventsV2.definitions().definitions
	var inst: Dictionary = sim.EventsV2._open(
		sim, "pump_seal", int(sim.state.settlements[0].region)
	)
	var refusal: String = sim.act(
		"event_v2", {"instance_id": str(inst.instance_id), "choice": "decline", "node": "other"}
	)
	check(
		refusal != "" and str(inst.status) == "pending",
		"a choice for another step is refused and changes nothing"
	)
	check(
		(
			sim.act(
				"event_v2",
				{"instance_id": str(inst.instance_id), "choice": "decline", "node": "start"}
			)
			== ""
		),
		"the choice for its step is taken"
	)
	check(
		(
			sim.act(
				"event_v2",
				{"instance_id": str(inst.instance_id), "choice": "decline", "node": "start"}
			)
			!= ""
		),
		"and only once"
	)
	check(definitions.has("frontier_water_station"), "the two-town water station decision exists")


func _reshuffle_and_teams() -> void:
	var sim: RefCounted = _game()
	sim.act("settle_at", {"lat": NORTH.x, "lon": NORTH.y, "name": "N"})
	var category: String = str(sim.state.research.offers.keys()[0])
	var hand: Array = sim.state.research.offers[category].duplicate()
	for key: String in hand:
		sim.state.research.projects[key] = {
			"staff": 0, "work": 1.0, "effective": 0, "rate": 0.0, "reason": ""
		}
	var preview: Dictionary = sim.Research.reshuffle_preview(sim, category)
	var cash: float = float(sim.state.cash)
	check(
		int(preview.changes) == 0 and sim.act("research_reshuffle", {"category": category}) != "",
		"every card protected: the reshuffle explains and refuses"
	)
	check(float(sim.state.cash) == cash, "…and charges nothing")
	sim.state.research.projects.erase(hand[0])
	preview = sim.Research.reshuffle_preview(sim, category)
	var before: Array = sim.state.research.offers[category].duplicate()
	if int(preview.changes) > 0:
		check(
			sim.act("research_reshuffle", {"category": category}) == "",
			"a reshuffle with a loose card goes ahead"
		)
		var after: Array = sim.state.research.offers[category]
		var changed: int = 0
		for key: String in before:
			if not after.has(key):
				changed += 1
		check(
			changed == int(preview.changes),
			"it replaces exactly the %d card(s) it said" % int(preview.changes)
		)
	var view: Dictionary = sim.research_view()
	check(
		int(view.assignable.teams) == int(sim.Research.assignable(sim).teams),
		"one count of assignable research teams"
	)
