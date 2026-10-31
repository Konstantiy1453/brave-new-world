extends RefCounted
## Deterministic one-day economy. Rendering and wall clock never enter state.
## `state` holds everything mutable and saved as plain data. `geo` holds derived geography,
## regenerated from the seed on load. Modules are static and take this object as `sim`.
## Tick order is documented in docs/v17/DESIGN.md.

const WorldGen = preload("res://world/world_gen.gd")
const Rules = preload("res://simulation/rules.gd")
const Keys = preload("res://simulation/keys.gd")
const Research = preload("res://simulation/research.gd")
const Company = preload("res://simulation/company.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Career = preload("res://simulation/career.gd")
const Production = preload("res://simulation/production.gd")
const Logistics = preload("res://simulation/logistics.gd")
const Population = preload("res://simulation/population.gd")
const Enterprise = preload("res://simulation/enterprise.gd")
const Contract = preload("res://simulation/contract.gd")
const Sites = preload("res://simulation/sites.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Market = preload("res://simulation/market.gd")
const Stats = preload("res://simulation/stats.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const Pollution = preload("res://simulation/pollution.gd")
const SAVE_VERSION: int = 4
const KEYS: Array[String] = Keys.RESOURCES
const LEDGER_LIMIT: int = 1800
const LOG_LIMIT: int = 120
const HISTORY_LIMIT: int = 90

var state: Dictionary = {}
var geo: Dictionary = {}
var config: Dictionary = {}
var progression: Dictionary = {}
var pop_rules: Dictionary = {}
var contract_rules: Dictionary = {}
var market_rules: Dictionary = {}
var blobs: Dictionary = {"checkpoint": PackedByteArray(), "archives": {}}
## What finished technologies add up to. Derived from state, rebuilt when the list grows.
var tech_effects: Dictionary = {}
var tech_effects_count: int = -1


func _init() -> void:
	config = Rules.economy()
	progression = Rules.progression()
	pop_rules = Rules.read("population")
	contract_rules = Rules.read("contract")
	market_rules = Rules.read("market")


func new_game(
	seed_value: Variant, advantage: String, size: int = 1, difficulty: String = "normal"
) -> void:
	if not progression.difficulty.has(difficulty):
		difficulty = "normal"
	if not config.openings.has(advantage):
		advantage = "capital"
	geo = WorldGen.new().build(seed_value, size)
	blobs = {"checkpoint": PackedByteArray(), "archives": {}}
	tech_effects_count = -1
	state = {
		"schema": SAVE_VERSION,
		"world": WorldGen.world_record(geo),
		"day": 0,
		"advantage": advantage,
		"cash": 0.0,
		"resident_cash": 0.0,
		"enterprise_cash": 0.0,
		"initial_money": 0.0,
		"external_in": 0.0,
		"external_out": 0.0,
		"settlements": [],
		"roads": [],
		"surveys": [],
		"shipments": [],
		"research": {"current": "", "progress": 0.0, "completed": [], "priority": 1.0},
		"events": [],
		"event": {},
		"effects": {},
		"log": [],
		"ledger": [],
		"status": "planning",
		"streak": 0,
		"operating_net": 0.0,
		"operating_history": [],
		"income_daily": 0.0,
		"expense_daily": 0.0,
		"debt": 0.0,
		"arrears": [],
		"grace_days": 0,
		"enterprise": {},
		"policy": {"tax": 0.18, "food_reserve": 12.0, "private_allowed": true},
		"exports_total": 0.0,
		"imports_total": 0.0,
		"transported_total": 0.0,
		"company_tax_total": 0.0,
		"success_day": -1,
		"failure_reason": "",
		"resource_sources": _stock(),
		"resource_sinks": _stock(),
		"rng_state": 0,
		"births_total": 0,
		"immigrants_total": 0
	}
	state.difficulty = difficulty
	state.rng_state = (absi(int(state.world.seed)) % 2147483646) + 1
	state.policy.wage = float(pop_rules.wage.default)
	Research.ensure(self)
	Company.ensure(self)
	ensure_systems(state)
	_transfer(
		"external",
		"public",
		float(config.openings[advantage].cash) * float(progression.difficulty[difficulty].capital),
		"capital.initial",
		false
	)
	_transfer("external", "residents", 2200.0, "savings.settlers", false)
	_log("合同已签署。请勘察后选择登陆点。")
	Career.ensure(self)
	EventsV2.ensure(self)


## Adds the state of systems newer than a save. Safe to run on any state, any number of times.
static func ensure_systems(target: Dictionary) -> void:
	Contract.ensure_state(target)
	Population.ensure_state(target)
	Pollution.ensure_state(target)
	Market.ensure_state(target)
	Production.ensure_state(target)
	Research.ensure_state(target)
	Logistics.ensure_state(target)
	Sites.ensure_state(target)
	EventsV2.ensure_state(target)
	Stats.ensure_state(target)


func _stock() -> Dictionary:
	var stock: Dictionary = {}
	for key: String in KEYS:
		stock[key] = 0.0
	return stock


func settlement(region: int) -> Dictionary:
	for s: Dictionary in state.get("settlements", []):
		if int(s.region) == region:
			return s
	return {}


func act(action: String, args: Dictionary = {}) -> String:
	if state.is_empty():
		return "请先开始新游戏"
	if state.status == "failed":
		return "本局已经结束，请读取存档或开始新局"
	match action:
		"settle":
			return Sites.settle(
				self,
				_site_arg(args),
				int(args.get("from", -1)),
				str(args.get("name", "")),
				str(args.get("kind", Keys.SITE_RESIDENTIAL))
			)
		"rename":
			return Sites.rename(self, _site_arg(args), str(args.get("name", "")))
		"build":
			return Production.build(
				self, _site_arg(args), str(args.get("kind", "")), int(args.get("plot", -1))
			)
		"connect":
			return Logistics.connect_road(
				self,
				int(args.get("a", -1)),
				int(args.get("b", -1)),
				bool(args.get("mountain", false)),
				str(args.get("variant", ""))
			)
		"survey":
			return Sites.survey(self, _site_arg(args))
		"tutorial_begin":
			return Tutorial.begin(self)
		"tutorial_shortage":
			return Tutorial.start_shortage(self, _site_arg(args))
		"recruit":
			return Population.recruit(
				self,
				int(args.get("region", -1)),
				str(args.get("kind", "worker")),
				int(args.get("count", 0))
			)
		"enterprise":
			return Enterprise.found(self, int(args.get("region", -1)))
		"enterprise_recover":
			return Enterprise.recover(self, int(args.get("region", -1)))
		"research_allocate":
			return Research.allocate(self, str(args.get("tech", "")), int(args.get("staff", 0)))
		"research_reshuffle":
			return Research.reshuffle(self, str(args.get("category", "")))
		"demolish":
			return Production.demolish(self, int(args.get("region", -1)), int(args.get("index", -1)))
		"company":
			return Company.act(self, args)
		"batch_toggle":
			return Production.batch_toggle(self, args)
		"stock_target":
			return Production.set_stock_target(self, args)
		"policy":
			return _set_policy(args)
		"event_v2":
			return EventsV2.act(self, args)
		"event":
			return _resolve_event(str(args.get("choice", "")))
		"toggle":
			return Production.toggle(self, int(args.get("region", -1)), int(args.get("index", -1)))
		"upgrade":
			return Production.upgrade(self, int(args.get("region", -1)), int(args.get("index", -1)))
		"upgrade_road":
			return Logistics.upgrade_road(self, int(args.get("road", 0)))
		"research_contract":
			return Research.set_contract(self, int(args.get("staff", 0)))
	return "未知操作"


## `site` is the location argument; `region` stays accepted for older action logs and tests.
func _site_arg(args: Dictionary) -> int:
	return int(args.get("site", args.get("region", -1)))


## Survey rules and site tables. A method, so modules need no second copy of the file.
func progression_geo() -> Dictionary:
	return Rules.read("geography")


func _set_policy(args: Dictionary) -> String:
	state.policy.tax = clampf(float(args.get("tax", state.policy.tax)), 0.0, 0.5)
	state.policy.food_reserve = clampf(
		float(args.get("food_reserve", state.policy.food_reserve)), 3.0, 25.0
	)
	state.policy.private_allowed = bool(args.get("private_allowed", state.policy.private_allowed))
	state.policy.wage = clampf(
		float(args.get("wage", state.policy.wage)),
		float(pop_rules.wage.min),
		float(pop_rules.wage.max)
	)
	if args.get("event_pause", "") in [EventsV2.PAUSE_ALL, EventsV2.PAUSE_CRITICAL]:
		state.policy.event_pause = str(args.event_pause)
	_log("贸易保留 %.0f 天食品，企业利润税 %.0f%%。" % [state.policy.food_reserve, state.policy.tax * 100.0])
	return ""


func tick() -> void:
	if state.is_empty() or state.status in ["planning", "failed"]:
		return
	state.day += 1
	state.operating_net = 0.0
	state.income_daily = 0.0
	state.expense_daily = 0.0
	var stocks: Dictionary = {}
	for s: Dictionary in state.settlements:
		stocks[str(s.region)] = s.stock.duplicate(true)
	_repay()
	Logistics.advance_shipments(self)
	for s: Dictionary in state.settlements:
		if s.arrival > 0:
			s.arrival -= 1
		Production.run_settlement(self, s)
	Research.tick(self)
	for s: Dictionary in state.settlements:
		if s.arrival <= 0:
			Logistics.trade(self, s)
	Enterprise.run(self)
	for s: Dictionary in state.settlements:
		if s.arrival <= 0:
			Population.feed(self, s)
	Logistics.dispatch(self)
	Logistics.road_daily(self)
	Sites.daily(self)
	Market.daily(self)
	_public_expense(_admin_cost(), "admin", "external")
	Population.daily(self)
	Company.social_environment(self)
	Pollution.daily(self)
	_event_tick()
	if state.status == "success" and state.day > state.success_day:
		var tax: float = (
			maxf(0.0, float(state.operating_net)) * float(config.contract.company_tax_rate)
		)
		if tax > 0:
			_public_expense(tax, "governor.share", "external")
			state.company_tax_total += tax
	for s: Dictionary in state.settlements:
		Population.refresh(self, s)
		for key: String in KEYS:
			s.stock_delta[key] = float(s.stock[key]) - float(stocks[str(s.region)][key])
	Contract.daily(self)
	Company.tick(self)
	state.operating_history.append(
		{
			"day": state.day,
			"net": state.operating_net,
			"income": state.income_daily,
			"expense": state.expense_daily
		}
	)
	if state.operating_history.size() > HISTORY_LIMIT:
		state.operating_history.pop_front()
	while state.ledger.size() > LEDGER_LIMIT:
		state.ledger.pop_front()
	Stats.close_day(state)
	Career.tick(self)


## Growth has running costs: a base, a per-resident part and a per-settlement part.
func _admin_cost() -> float:
	var residents: int = 0
	for s: Dictionary in state.settlements:
		residents += int(s.population)
	var saved: float = Research.bonus(self, "admin")
	for s: Dictionary in state.settlements:
		saved += Population.service_total(self, s, "admin")
	return (
		maxf(0.3, 1.0 + saved)
		* (
			float(config.economy.admin)
			+ float(config.economy.admin_per_resident) * residents
			+ float(config.economy.admin_per_settlement) * state.settlements.size()
		)
	)


func _event_tick() -> void:
	if not state.event.is_empty() and not state.event.has("instance_id"):
		if int(state.day) >= int(state.event.get("expires", 999999)):
			_resolve_event("ration" if state.event.id == "drought" else "decline")
		return
	EventsV2.tick(self)


## Answers a pending event, including the three fixed events of very old saves.
func _resolve_event(choice: String) -> String:
	if state.event.has("instance_id"):
		return EventsV2.act(self, {"instance_id": str(state.event.instance_id), "choice": choice})
	if state.event.is_empty():
		return "当前没有待处理事件"
	var id: String = state.event.id
	var valid: bool = false
	for c: Dictionary in state.event.choices:
		if c.id == choice:
			valid = true
	if not valid:
		return "请选择有效的事件方案"
	var error: String = _resolve_legacy_event(id, choice)
	if error != "":
		return error
	state.event = {}
	return ""


func _resolve_legacy_event(id: String, choice: String) -> String:
	match id:
		"drought":
			if choice == "protect":
				if state.cash < 160:
					return "调蓄工程需要 160 资金"
				_transfer("public", "external", 160.0, "legacy.event", false)
			state.effects.drought_start = int(state.day) + 1
			state.effects.drought_until = int(state.day) + 1 + int(state.event.duration)
			state.effects.drought_choice = choice
			_log("缺水应对：" + ("调蓄工程保障供水。" if choice == "protect" else "节水减产 15%，持续 12 天。"))
		"market":
			if choice == "accept":
				if state.cash < 120:
					return "港务协调需要 120 资金"
				_transfer("public", "external", 120.0, "legacy.event", false)
				state.effects.market_start = int(state.day) + 1
				state.effects.market_until = int(state.day) + 1 + int(state.event.duration)
				_log("铜矿报价 +35%，持续 18 天。")
		"talent":
			if choice == "invite":
				var s: Dictionary = state.settlements[0]
				if s.housing < s.population + 8:
					return "首府需要 8 个空闲住房名额"
				if state.cash < 180:
					return "人才安置需要 180 资金"
				_transfer("public", "external", 180.0, "legacy.event", false)
				_transfer("external", "residents", 800.0, "savings.immigrants", false)
				s.workers += 4
				s.scientists += 4
				s.population += 8
				state.immigrants_total += 8
				_log("4 名研究员与 4 名工人入住首府。")
	return ""


func _fail(reason: String) -> void:
	state.status = "failed"
	state.failure_reason = reason
	_log("经营终止：" + reason)


func _has(tech: String) -> bool:
	return state.research.completed.has(tech)


func _short(s: Dictionary, key: String, detail: String = "") -> void:
	for existing: Dictionary in s.shortages:
		if existing.key == key and existing.detail == detail:
			return
	s.shortages.append({"key": key, "detail": detail})


func _log(message: String) -> void:
	state.log.append({"day": state.day, "text": message})
	while state.log.size() > LOG_LIMIT:
		state.log.pop_front()


func _account(name: String) -> String:
	return {"public": "cash", "residents": "resident_cash", "enterprise": "enterprise_cash"}.get(
		name, ""
	)


## Moves money between accounts and records it. `key` is English; ui/labels.gd names it.
func _transfer(
	from: String, to: String, amount: float, key: String, operating: bool, detail: String = ""
) -> float:
	if amount <= 0:
		return 0.0
	var source: String = _account(from)
	var dest: String = _account(to)
	if source != "":
		amount = minf(amount, maxf(0.0, float(state[source])))
	if amount <= 0:
		return 0.0
	if source != "":
		state[source] -= amount
	else:
		state.external_in += amount
	if dest != "":
		state[dest] += amount
	else:
		state.external_out += amount
	state.ledger.append(
		{
			"day": state.day,
			"key": key,
			"detail": detail,
			"amount": amount,
			"from": from,
			"to": to,
			"operating": operating
		}
	)
	if operating:
		if to == "public":
			state.operating_net += amount
			state.income_daily += amount
			Stats.money(state, "income", key, amount)
		if from == "public":
			state.operating_net -= amount
			state.expense_daily += amount
			Stats.money(state, "expense", key, amount)
	elif from == "public":
		Stats.money(state, "invest", key, amount)
	elif to == "public":
		Stats.money(state, "funding", key, amount)
	return amount


func _public_expense(amount: float, key: String, to: String, detail: String = "") -> void:
	if amount <= 0:
		return
	# Operating result includes today's payable bills even if cash cannot settle them.
	var paid: float = _transfer("public", to, amount, key, true, detail)
	var due: float = amount - paid
	if due > 0.000001:
		state.operating_net -= due
		state.expense_daily += due
		Stats.money(state, "expense", key, due)
		state.debt += due
		state.arrears.append({"to": to, "amount": due, "key": key})


func _repay() -> void:
	var keep: Array = []
	for bill: Dictionary in state.arrears:
		var paid: float = _transfer(
			"public", bill.to, float(bill.amount), "arrears", false, str(bill.key)
		)
		bill.amount -= paid
		state.debt -= paid
		if bill.amount > 0.000001:
			keep.append(bill)
	state.arrears = keep
	state.debt = maxf(0.0, state.debt)


func summary() -> Dictionary:
	var population: int = 0
	var employed: int = 0
	var food: float = 0.0
	var days: float = 999.0
	for s: Dictionary in state.settlements:
		population += int(s.population)
		employed += int(s.employed)
		food += float(s.stock.food)
		days = minf(days, float(s.food_days))
	var net: float = 0.0
	var count: int = mini(7, state.operating_history.size())
	for i: int in range(state.operating_history.size() - count, state.operating_history.size()):
		net += float(state.operating_history[i].net)
	if count > 0:
		net /= count
	return {
		"population": population,
		"employed": employed,
		"food": food,
		"food_days": 0.0 if days == 999.0 else days,
		"operating_average": net,
		"runway": float(state.cash) / (-net) if net < -0.01 else -1.0,
		"debt": state.debt,
		"contract": contract_progress()
	}


func audit() -> Array:
	var errors: Array = []
	var total: float = float(state.cash) + float(state.resident_cash) + float(state.enterprise_cash)
	if (
		absf(
			(
				total
				- (
					float(state.initial_money)
					+ float(state.external_in)
					- float(state.external_out)
				)
			)
		)
		> 0.00001
	):
		errors.append("cash conservation")
	var holdings: Dictionary = _stock()
	for s: Dictionary in state.settlements:
		if int(s.population) != int(s.children) + int(s.workers) + int(s.scientists):
			errors.append("population partition")
		if s.employed_workers > s.workers or s.employed_scientists > s.scientists:
			errors.append("duplicate job allocation")
		if int(s.workers) < 0 or int(s.scientists) < 0 or int(s.children) < 0:
			errors.append("negative population")
		if float(s.attractiveness) < 0.0 or float(s.attractiveness) > 2.0:
			errors.append("attractiveness out of range")
		for key: String in KEYS:
			if s.stock[key] < -0.00001:
				errors.append("negative stock " + key)
			holdings[key] += float(s.stock[key])
	for cargo: Dictionary in state.shipments:
		holdings[cargo.resource] += float(cargo.amount)
	for party: Dictionary in state.recruits:
		if int(party.count) <= 0 or settlement(int(party.region)).is_empty():
			errors.append("recruit party invalid")
	errors.append_array(_audit_sites())
	if float(state.pollution.load) < 0.0:
		errors.append("negative pollution")
	for s: Dictionary in state.settlements:
		if not str(s.kind) in [Keys.SITE_RESIDENTIAL, Keys.SITE_FRONTIER]:
			errors.append("unknown settlement kind")
	var offered: Dictionary = {}
	for hand: Array in state.research.get("offers", {}).values():
		for tech: String in hand:
			if offered.has(tech):
				errors.append("technology offered twice")
			offered[tech] = true
			if state.research.completed.has(tech):
				errors.append("finished technology offered")
	for good: String in state.market.saturation:
		if float(state.market.saturation[good]) < 0.0:
			errors.append("negative market saturation")
	for key: String in KEYS:
		if (
			absf(
				(
					float(holdings[key])
					- float(state.resource_sources[key])
					+ float(state.resource_sinks[key])
				)
			)
			> 0.00001
		):
			errors.append("material conservation " + key)
	return errors


func _audit_sites() -> Array:
	var errors: Array = []
	for s: Dictionary in state.settlements:
		var plots: Array = state.world.regions[int(s.region)].plots
		var used: Dictionary = {}
		for b: Dictionary in s.buildings:
			var plot: int = int(b.plot)
			if plot < 0:
				continue
			if plot >= plots.size():
				errors.append("building on missing plot")
			elif used.has(plot):
				errors.append("plot used twice")
			used[plot] = true
	for reg: Dictionary in state.world.regions:
		var known: Dictionary = {"ore": 0.0, "copper": 0.0, "crystal": 0.0}
		for plot: Dictionary in reg.plots:
			if plot.kind != "deposit":
				continue
			if float(plot.reserves) < -0.00001:
				errors.append("negative reserves")
			if (
				not bool(plot.hidden)
				and (int(plot.depth) == 0 or bool(reg.get("deep_known", false)))
			):
				known[plot.resource] += float(plot.reserves)
		for good: String in known:
			if absf(float(known[good]) - float(reg.deposits[good])) > 0.01:
				errors.append("deposit total differs from plots")
	for road: Dictionary in state.roads:
		if settlement(int(road.a)).is_empty() or settlement(int(road.b)).is_empty():
			errors.append("road to no settlement")
	return errors


func save_game(path: String) -> String:
	return SaveIo.save(self, path)


func load_game(path: String) -> String:
	return SaveIo.load_file(self, path)


func _validate_save(candidate: Variant) -> String:
	return SaveIo.validate(self, candidate)


func _save_shape(value: Variant, pattern: Variant, path: String) -> String:
	return SaveIo.shape(value, pattern, path)


func research_view() -> Dictionary:
	return Research.view(self)


func research_reserve(id: String, staff: int) -> String:
	return Research.reserve_investigation(self, id, staff)


func research_release(id: String) -> void:
	Research.release_investigation(self, id)


func company_view() -> Dictionary:
	return Company.view(self)


func build_forecast(region: int, kind: String, plot: int = -1) -> Dictionary:
	return Production.build_forecast(self, region, kind, plot)


func site_view(site: int) -> Dictionary:
	return Sites.view(self, site)


func settle_refusal(site: int, kind: String = Keys.SITE_RESIDENTIAL) -> String:
	return Sites.settle_refusal(self, site, -1, kind)


func site_links(site: int) -> Dictionary:
	return Sites.links(self, site)


func plot_choices(site: int, kind: String) -> Array:
	return Sites.plot_choices(self, site, kind)


func stats_window(days: int = 30) -> Dictionary:
	return Stats.window(state, days)


func stats_series() -> Dictionary:
	return Stats.series(state)


func road_quote(a: int, b: int, variant: String) -> Dictionary:
	return Logistics.quote(self, a, b, variant)


func population_view(region: int) -> Dictionary:
	return Population.view(self, region)


func upgrade_preview(region: int, index: int) -> Dictionary:
	return Production.upgrade_preview(self, region, index)


func research_tree() -> Array:
	return Research.tree(self)


func research_cards() -> Array:
	return Research.cards(self)


func pollution_view() -> Dictionary:
	return Pollution.view(self)


func contract_view() -> Dictionary:
	return Contract.view(self)


func market_view() -> Array:
	return Market.view(self)


func contract_progress() -> Dictionary:
	return Contract.progress(self)


func build_preview(region: int, kind: String) -> Dictionary:
	return Production.build_preview(self, region, kind)


func enterprise_preview(region: int) -> Dictionary:
	return Enterprise.preview(self, region)


func logistics_view(region: int) -> Dictionary:
	return Logistics.view(self, region)


func toggle_preview(region: int, index: int) -> Dictionary:
	return Production.toggle_preview(self, region, index)


func free_workers(s: Dictionary) -> int:
	return Production.free_workers(self, s)


func free_specialists(s: Dictionary) -> int:
	return Production.free_specialists(self, s)


func _building(kind: String, remaining: int) -> Dictionary:
	return Production.new_building(self, kind, remaining)


func _produce(s: Dictionary, resource: String, amount: float, source: String) -> void:
	Production.produce(self, s, resource, amount, source)


func _consume(s: Dictionary, resource: String, amount: float) -> void:
	Production.consume(self, s, resource, amount)


func _target(s: Dictionary, resource: String) -> float:
	return Production.target(self, s, resource)


func _refresh(s: Dictionary) -> void:
	Population.refresh(self, s)


func _feed(s: Dictionary) -> void:
	Population.feed(self, s)


func _reconcile_jobs(s: Dictionary) -> void:
	Population.reconcile_jobs(self, s)


func _population() -> void:
	Population.daily(self)


func _trade(s: Dictionary) -> void:
	Logistics.trade(self, s)


func _dispatch() -> void:
	Logistics.dispatch(self)


func _advance_shipments() -> void:
	Logistics.advance_shipments(self)


func _incoming(region: int, resource: String) -> float:
	return Logistics.incoming(self, region, resource)


func _reserved(s: Dictionary) -> Dictionary:
	return Logistics.reserved(self, s)


func _water_factor() -> float:
	return Production.water_factor(self)


func _ration_active() -> bool:
	return Production.ration_active(self)
