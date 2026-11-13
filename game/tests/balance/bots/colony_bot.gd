extends "res://tests/balance/bots/bot.gd"
## Shared decision logic for bots that play to win. Each day: answer events, fix shortages in the
## order food, water and power, labour, housing; keep a cash cushion; then invest in the best
## affordable option. The balanced, rush and research-first bots only change the parameters.

const INVEST_ROLES: Array[String] = ["mine", "harvest", "factory", "income", "commerce"]
const EXTRACTION_ROLES: Array[String] = ["mine", "harvest"]
const MEGAPROJECTS: Array[String] = ["university", "climate_regulator", "lift_port"]
const MEGAPROJECT_RESERVE_FACTOR: float = 1.5
const SCIENCE_TECH: String = "education"
const DECISION_PERIOD: int = 5
const VALLEY_ROAD_DAYS: int = 18
const EXPEDITION_DAYS: int = 30
const SITE_TRIES: int = 5
const MIN_TOWN_PLOTS: int = 6
const MIN_IDLE_WORKERS: int = 8
const IDLE_SHARE: float = 0.15
const MIN_JOB_NET: float = -20.0
const JOB_ROLES: Array[String] = [
	"mine", "harvest", "factory", "commerce", "foodworks", "farm", "indoor_farm"
]
const UTILITY_MARGIN: float = 5.0
const POWER_KINDS: Array[String] = ["fusion", "fission", "geothermal", "wind_farm", "power"]
const WATER_KINDS: Array[String] = ["desalination", "atmospheric_water", "deep_well", "water"]
const HOUSING_KINDS: Array[String] = [
	"arcology", "apartment", "habitat", "frontier_lodge", "crew_quarters"
]
const BIG_BUILDING_CASH_SHARE: float = 0.3
const FACTORY_PEOPLE: int = 150
const MIN_FARM_OUTPUT: float = 15.0
const MIN_LOCAL_FARM_OUTPUT: float = 6.0
const WAGE_STEP: float = 0.1
const MIN_RESERVE_DAYS: float = 300.0
const MIN_MARKET_FACTOR: float = 0.8
const OTHER_INCOME_MARGIN: float = 1.15
const DIVERSIFY_CUSHION: float = 0.4
const DOMINANT_SHARE: float = 0.5
const EXPORT_WINDOW_DAYS: int = 30
## Event effects in the bot's valuation (`_option_value`): the days a lasting effect counts for,
## and the share of the colony's daily income each kind of effect touches.
const EFFECT_YEAR: float = 360.0
const EFFECT_SHARE: Dictionary = {
	"all": 1.0,
	"export_price": 0.6,
	"mine": 0.45,
	"processor": 0.3,
	"port": 0.2,
	"road_capacity": 0.2,
	"power": 0.15,
	"farm": 0.1,
	"water": 0.1,
	"research": 0.05,
	"appeal": 0.05,
}
const EFFECT_SHARE_OTHER: float = 0.1
const POLLUTION_CLEANUP_AT: float = 0.03
const SCRUBBER_AT: float = 0.005
const PORT_BUSY_SHARE: float = 0.9
const WAGE_LIMIT: float = 1.3
const WAGE_REVIEW_FROM_DAY: int = 60
const WAGE_REVIEW_PERIOD: int = 60
const RICH_CASH: float = 120000.0
const FAR_EXPEDITION_DAYS: int = 90
const JOBLESS_ELSEWHERE: int = 40
const CHARTER_TEAM_FACTOR: int = 2
const LARGE_SCIENCE_SHARE: float = 0.15
const LARGE_CAMPAIGN: int = 20
const HOUSING_TECHS: Array[String] = ["apartments", "frontier_lodges", "arcology_design"]
const LAB_SEATS: int = 10
const TEAM_SMALLEST: int = 5
const TEAM_SMALL: int = 10
const TEAM_LARGE: int = 20
const SERVICE_PEOPLE: Dictionary = {
	"clinic": 40,
	"park": 60,
	"school": 90,
	"civic_center": 200,
	"culture_center": 150,
	"hospital": 350,
}
const COMMERCE_PEOPLE: int = 150
const HALL_TECH: String = "capital_planning"
const RESHUFFLE_PERIOD: int = 90
const IDLE_STATUSES: Array[String] = ["no_input", "idle", "target_full"]
const RECRUIT_JOBLESS_LIMIT: float = 0.15
const HARVESTERS_PER_TOWN: int = 3
const COMFORTABLE_NET: float = 150.0
const DEADLINE_PRESSED: float = 0.7
const SECOND_LAB_INCOME: float = 600.0
const LOW_FOOD_DAYS: float = 12.0
const PORT_PEOPLE: int = 100
const SWAP_KINDS: Array[String] = ["apartment", "arcology"]
const SWAP_FREE_BEDS: int = 35
## Public services budget (1.9): raise a level with this much cash cover, lower it below the other.
const SERVICES_UP_COVER: float = 120.0
const SERVICES_DOWN_COVER: float = 45.0
const SERVICES_REVIEW_PERIOD: int = 60
## Career transfer (1.9): after the award, cash above this much cover goes to the career balance.
const TRANSFER_COVER: float = 240.0
const TRANSFER_REVIEW_PERIOD: int = 60
## Commissioned research (1.9): level 1 from this much cover, level 2 from twice it, all stopped
## below the floor.
const COMMISSION_FLOOR_COVER: float = 45.0
const COMMISSION_REVIEW_PERIOD: int = 10
## Late great works (1.9): built, staged and levelled from this much cash cover once unlocked.
const LATE_WORKS: Array[String] = [
	"capital_district", "exchange", "terraforming", "shipyard", "emergency_net"
]
## After the award the next late great work is saved for, and built when cash pays for it and
## still keeps this many days of expenses.
const LATE_WORKS_RESERVE_DAYS: float = 10.0
## Before the award the charter comes first: a late great work only out of this much spare cash.
const LATE_WORKS_EARLY_RESERVE_DAYS: float = 60.0
## Blocked upgrade steps are kept apart from blocked builds of the same kind.
const UPGRADE_KEY: String = "upgrade:"
const LATE_WORK_TECH_VALUE: float = 6.0
## A great work whose build was refused for anything but money is left alone this long.
const LATE_WORK_RETRY_DAYS: int = 360
## After the award the charter is won: the techs behind the late great works come first.
const LATE_WORK_TECH_VALUE_AFTER_AWARD: float = 40.0

var home: int = 0
var reserve_days: float = 8.0
var payback_limit: float = 450.0
var recruit_batch: int = 10
var recruit_buffer: float = 2000.0
var science_target: float = 0.12
var lab_day: int = 15
var population_goal: int = 100000
var last_reshuffle: int = -1000
var research_full_income: float = 1000.0
var last_wage_change: int = -1000
var fixed_wage: float = 0.0
## Whether this bot uses the public services budget (passive and sloppy players do not).
var uses_services: bool = false
var uses_transfer: bool = false
var uses_commissions: bool = false
## Commission every running project, not only the one the charter needs next.
var commission_all: bool = false
var commission_cover: float = 90.0
var uses_great_works: bool = false
## Day a late great work's build was last refused, by kind.
var late_work_blocked: Dictionary = {}
## Short-range shuttle lines to new outposts while their roads are saved for and built (1.9).
var uses_shuttle: bool = false
var clean_air: bool = true
var tech_order: Array[String] = [
	"survey",
	"education",
	"adaptation",
	"irrigation",
	"processing",
	"medicine",
	"logistics",
	"road_crews",
	"prefab_modules",
	"research_network",
	"deep_mining",
	"heavy_machinery",
	"apartments",
	"commerce_law",
	"school_system",
	"electronics",
	"alloy_smelting",
	"hydroponics",
	"efficiency",
	"remediation",
	"automation",
	"university",
]


func on_day() -> void:
	if sim.state.settlements.is_empty():
		_land()
	answer_events()
	if sim.state.settlements.is_empty():
		return
	if today() % DECISION_PERIOD != 0 and today() > DECISION_PERIOD:
		return
	home = int(sim.state.settlements[0].region)
	var reserve: float = daily_expense() * reserve_days
	_utilities()
	_environment(reserve)
	# Before the day's other building, so neither the plot nor the money it saved goes elsewhere.
	_late_great_works()
	_laboratory(reserve)
	_staff_research(reserve)
	_second_settlement(reserve)
	_feed_towns(reserve)
	_food(reserve)
	_housing(reserve)
	_enterprise()
	_upgrade_busy_links(reserve)
	_megaprojects(reserve)
	_ports(reserve)
	_goal_projects(reserve)
	var saving: bool = _saving_for_road() or _saving_for_port() or _saving_for_settlement()
	# Saving is for the poor: with this much in the bank nothing has to wait for anything else.
	if float(sim.state.cash) >= RICH_CASH:
		saving = false
	if not saving and not _saving_for_hall() and not _saving_for_great_work():
		_create_jobs(reserve)
		_invest(reserve)
		_services(reserve)
		_upgrades(reserve)
	_research_contract()
	_wages()
	_public_services()
	_commissions()
	_seek_late_work_tech()
	_career_transfer()


## Lands on the start that looks richest from orbit, among those with a farming partner in reach.
func _land() -> void:
	var best: float = -1.0
	for pair: Array in sim.geo.get("playability", {}).get("pairs", [[0, 1]]):
		var score: float = sim.Sites.start_score(sim, int(pair[0]))
		if score > best:
			best = score
			home = int(pair[0])
	act("settle", {"site": home})
	act("build", {"site": home, "kind": "mine_ore"})
	act("build", {"site": home, "kind": "mine_copper"})


func answer_events() -> void:
	var definitions: Dictionary = EventsV2.definitions().definitions
	for node: Dictionary in EventsV2.view(sim).pending:
		var options: Array = definitions[node.id].nodes[node.node].choices
		var best: String = ""
		var best_score: float = -INF
		for choice: Dictionary in node.choices:
			if choice.id == "defer" or not choice.enabled:
				continue
			var score: float = _option_value(options, str(choice.id))
			if score > best_score:
				best_score = score
				best = choice.id
		if best != "":
			act("event_v2", {"instance_id": node.instance_id, "choice": best})


## What an event option is worth in money: payments and rewards as the game scales them with the
## colony's income, goods at their prices, and each effect over its days (EFFECT_YEAR when it
## lasts) on the share of daily income its production touches, less its daily upkeep. A flat value
## per effect, whatever its length, made the bot take every long production cut over paying to
## avoid it.
func _option_value(options: Array, id: String) -> float:
	var scale: float = EventsV2.money_scale(sim)
	var daily: float = scale * float(EventsV2.definitions().sampling.reference_income)
	for option: Dictionary in options:
		if option.id != id:
			continue
		var value: float = (
			(float(option.get("reward", 0.0)) - float(option.get("pay", 0.0))) * scale
		)
		for good: String in option.get("goods_reward", {}):
			value += float(option.goods_reward[good]) * float(sim.config.prices[good])
		for good: String in option.get("goods_cost", {}):
			value -= float(option.goods_cost[good]) * float(sim.config.prices[good])
		for effect: Dictionary in option.get("effects", []):
			var days: float = float(effect.get("duration_days", 0.0))
			if days <= 0.0:
				days = EFFECT_YEAR
			var share: float = float(EFFECT_SHARE.get(str(effect.kind), EFFECT_SHARE_OTHER))
			value += (float(effect.factor) - 1.0) * days * daily * share
			value -= float(effect.get("maintenance", 0.0)) * days
		if option.has("build"):
			value -= 400.0 * scale
		if option.has("investigate"):
			value += 50.0 * scale
		return value
	return 0.0


func _places() -> Array:
	var ready: Array = []
	for place: Dictionary in sim.state.settlements:
		if int(place.arrival) <= 0:
			ready.append(place)
	return ready


func _affordable(region: int, kind: String, reserve: float) -> bool:
	var forecast: Dictionary = sim.build_forecast(region, kind)
	return (
		not forecast.is_empty()
		and forecast.disabled_reason == ""
		and float(sim.state.cash) >= float(forecast.cost) + reserve
	)


func _utilities() -> void:
	# Supply figures are only meaningful once a settlement has run for a day.
	if today() <= 2:
		return
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var power_margin: float = float(place.power_supply) - float(place.power_demand)
		if power_margin < UTILITY_MARGIN:
			_build_utility(region, POWER_KINDS)
		var water_margin: float = float(place.water_supply) - float(place.water_demand)
		if water_margin < UTILITY_MARGIN:
			_build_utility(region, WATER_KINDS)


## The largest plant of this list the colony can open without emptying the till.
func _build_utility(region: int, kinds: Array[String]) -> void:
	for kind: String in kinds:
		if _building_underway(region, kind):
			return
	for kind: String in kinds:
		var forecast: Dictionary = sim.build_forecast(region, kind)
		if forecast.is_empty() or forecast.disabled_reason != "":
			continue
		var last_resort: bool = kind == kinds[kinds.size() - 1]
		if last_resort or float(forecast.cost) <= float(sim.state.cash) * BIG_BUILDING_CASH_SHARE:
			act("build", {"region": region, "kind": kind})
			return


func _building_underway(region: int, kind: String) -> bool:
	for building: Dictionary in sim.settlement(region).get("buildings", []):
		if building.kind == kind and int(building.remaining) > 0:
			return true
	return false


func _laboratory(reserve: float) -> void:
	if today() < lab_day or _building_underway(home, "lab"):
		return
	if not has_building(home, "lab"):
		if _affordable(home, "lab", reserve * 0.1):
			act("build", {"region": home, "kind": "lab"})
		return
	# Four categories want four benches: that is two laboratories, and a third late on.
	var labs: int = building_count(home, "lab")
	var wanted: int = 2 if int(sim.state.contract.stage) < 4 else 3
	# A colony that trains more teams than it has seats wants the seats to go with them.
	if science_target >= LARGE_SCIENCE_SHARE:
		wanted = maxi(wanted, int(sim.research_view().total) / LAB_SEATS + 1)
	if _saving_for_road() or labs >= wanted or int(sim.state.contract.stage) < 2:
		return
	if float(sim.state.income_daily) < SECOND_LAB_INCOME:
		return
	if _affordable(home, "lab", reserve):
		act("build", {"region": home, "kind": "lab"})


func _staffed_projects() -> int:
	var count: int = 0
	for project: Dictionary in sim.state.research.projects.values():
		if int(project.staff) > 0:
			count += 1
	return count


## Picks a card for every idle team that has a bench, and keeps teams at a useful size.
func _staff_research(reserve: float) -> void:
	var view: Dictionary = sim.research_view()
	if int(view.benches) <= 0:
		return
	var columns: Array = sim.research_cards()
	var staffed: int = 0
	for column: Dictionary in columns:
		if not column.running.is_empty():
			staffed += 1
	var free: int = mini(int(view.available), int(view.capacity) - int(view.allocated))
	var benches: int = mini(int(view.benches), columns.size())
	var seats: int = mini(int(view.capacity), int(view.total))
	var wanted: int = clampi(seats / maxi(1, benches), TEAM_SMALLEST, TEAM_LARGE)
	# Science is paid for out of what the mines earn: a small colony runs a small programme.
	var income: float = float(sim.state.income_daily)
	if income < research_full_income:
		benches = mini(benches, 1 if income < research_full_income * 0.4 else 2)
		wanted = mini(wanted, 6 if income < research_full_income * 0.4 else TEAM_SMALL)
	var chain_first: Dictionary = _hall_chain()
	# A team bigger than its share keeps a whole direction of research waiting for a seat.
	for column: Dictionary in columns:
		var large: Dictionary = column.running
		if large.is_empty() or chain_first.has(str(large.id)):
			continue
		if int(large.staff) > wanted and staffed < benches:
			if act("research_allocate", {"tech": large.id, "staff": wanted}) == "":
				free += int(large.staff) - wanted
	# What the final stage cannot do without gets the first seat.
	var chain: Dictionary = _hall_chain()
	var ordered: Array = columns.filter(func(c: Dictionary) -> bool: return _offers_any(c, chain))
	for column: Dictionary in columns:
		if not ordered.has(column):
			ordered.append(column)
	for column: Dictionary in ordered:
		var running: Dictionary = column.running
		if running.is_empty():
			if staffed >= benches or free < int(sim.progression.research.minimum_staff):
				continue
			var card: String = _best_card(column)
			if card == "":
				continue
			var team: int = mini(wanted * _team_factor(card, chain), free)
			if act("research_allocate", {"tech": card, "staff": team}) == "":
				staffed += 1
				free -= team
		elif int(running.staff) < wanted * _team_factor(str(running.id), chain) and free > 0:
			var goal: int = wanted * _team_factor(str(running.id), chain)
			var more: int = mini(goal - int(running.staff), free)
			if (
				act("research_allocate", {"tech": running.id, "staff": int(running.staff) + more})
				== ""
			):
				free -= more
	_seek_hall_technology(reserve)


## What the charter needs gets the larger team.
func _team_factor(tech: String, chain: Dictionary) -> int:
	return CHARTER_TEAM_FACTOR if chain.has(tech) else 1


func _offers_any(column: Dictionary, techs: Dictionary) -> bool:
	for row: Dictionary in column.offers:
		if techs.has(str(row.id)):
			return true
	return false


func _best_card(column: Dictionary) -> String:
	var best: String = ""
	var top: float = -INF
	for row: Dictionary in column.offers:
		var value: float = _card_value(row)
		if value > top:
			top = value
			best = str(row.id)
	return best


## Goal-critical first, then what the bot's plan asks for, then whatever unlocks most for least.
func _card_value(row: Dictionary) -> float:
	var id: String = str(row.id)
	var value: float = float(row.unlocks.size()) * 3.0
	value += float(sim.config.techs[id].effects.size())
	value -= float(row.cost) / 300.0
	var rank: int = tech_order.find(id)
	if rank >= 0:
		value += 12.0 + float(tech_order.size() - rank) * 0.5
	if _hall_chain().has(id):
		value += 25.0 if int(sim.state.contract.stage) >= 3 else 6.0
	if _out_of_farm_land() and id in ["adaptation", "irrigation", "hydroponics", "aquaculture"]:
		value += 30.0
	if _mines_running_out() and id in ["survey", "deep_mining", "prospecting", "tailings_recovery"]:
		value += 30.0
	if id in HOUSING_TECHS and _short_of_ground():
		value += 30.0
	if uses_great_works and str(sim.state.status) == "success":
		if _late_chain().has(id):
			value += LATE_WORK_TECH_VALUE_AFTER_AWARD
	elif uses_great_works and _unlocks_late_work(id):
		value += LATE_WORK_TECH_VALUE
	return value


## Before the award only the technology that unlocks a late great work counts, a little.
func _unlocks_late_work(tech: String) -> bool:
	for kind: String in LATE_WORKS:
		if str(sim.config.buildings[kind].requires_tech) == tech:
			return true
	return false


## Every technology still missing on the way to a late great work, prerequisites included.
func _late_chain() -> Dictionary:
	var chain: Dictionary = {}
	var open: Array = []
	for kind: String in LATE_WORKS:
		open.append(str(sim.config.buildings[kind].requires_tech))
	while not open.is_empty():
		var tech: String = str(open.pop_back())
		if chain.has(tech) or sim._has(tech):
			continue
		chain[tech] = true
		open.append_array(sim.config.techs[tech].requires)
	return chain


## After the award, pays to redraw a research direction when no card on the way to a late great
## work is on offer, as a player chasing one would.
func _seek_late_work_tech() -> void:
	if not uses_great_works or str(sim.state.status) != "success":
		return
	if today() - last_reshuffle < RESHUFFLE_PERIOD:
		return
	var chain: Dictionary = _late_chain()
	for tech: String in chain:
		var category: String = str(sim.config.techs[tech].category)
		if sim.state.research.offers.get(category, []).has(tech):
			return
	var keep: float = _late_work_keep()
	if float(sim.state.cash) < sim.Research.reshuffle_cost(sim) + keep:
		return
	for tech: String in chain:
		var open: bool = true
		for need: String in sim.config.techs[tech].requires:
			open = open and sim._has(need)
		if open:
			act("research_reshuffle", {"category": str(sim.config.techs[tech].category)})
			last_reshuffle = today()
			return


## Everything between here and the technology the final stage cannot do without.
func _hall_chain() -> Dictionary:
	var chain: Dictionary = {}
	var open: Array = [HALL_TECH]
	while not open.is_empty():
		var tech: String = str(open.pop_back())
		if chain.has(tech) or sim._has(tech):
			continue
		chain[tech] = true
		open.append_array(sim.config.techs[tech].requires)
	return chain


## Late in the contract, pays to redraw when no card leads to the capital's hall.
func _seek_hall_technology(reserve: float) -> void:
	if int(sim.state.contract.stage) < 4 or sim._has(HALL_TECH):
		return
	if today() - last_reshuffle < RESHUFFLE_PERIOD:
		return
	var chain: Dictionary = _hall_chain()
	for tech: String in chain:
		var category: String = str(sim.config.techs[tech].category)
		if sim.state.research.offers.get(category, []).has(tech):
			return
	var cost: float = sim.Research.reshuffle_cost(sim)
	if float(sim.state.cash) < cost + reserve:
		return
	for tech: String in chain:
		var category: String = str(sim.config.techs[tech].category)
		var open: bool = true
		for need: String in sim.config.techs[tech].requires:
			open = open and sim._has(need)
		if open:
			act("research_reshuffle", {"category": category})
			last_reshuffle = today()
			return


## The contract needs the settlements connected: nothing else is worth delaying that for.
func _saving_for_road() -> bool:
	return sim.state.settlements.size() > 1 and not _unconnected().is_empty()


func _unconnected() -> Array:
	var missing: Array = []
	for at: int in range(1, sim.state.settlements.size()):
		var place: Dictionary = sim.state.settlements[at]
		var joined: bool = false
		for road: Dictionary in sim.state.roads:
			# A shuttle line is a stopgap: the outpost still needs its road or sea route.
			if str(road.get("variant", "")) == sim.Keys.ROUTE_SHUTTLE:
				continue
			joined = joined or int(road.a) == int(place.region) or int(road.b) == int(place.region)
		if not joined:
			missing.append(int(place.region))
	return missing


func _angle_between(a: int, b: int) -> float:
	var regions: Array = sim.state.world.regions
	var from: Vector3 = sim.WorldGen.unit_point(float(regions[a].lat), float(regions[a].lon))
	return from.angle_to(sim.WorldGen.unit_point(float(regions[b].lat), float(regions[b].lon)))


func _nearest_settled(site: int) -> int:
	var nearest: int = -1
	var closest: float = INF
	for place: Dictionary in sim.state.settlements:
		var region: int = int(place.region)
		if region == site:
			continue
		var angle: float = _angle_between(site, region)
		if angle < closest:
			closest = angle
			nearest = region
	return nearest


## The way to tie a site to the network: the nearest settlement that any allowed road can reach.
func _best_link(site: int) -> Dictionary:
	var from_sites: Array = []
	for place: Dictionary in sim.state.settlements:
		if int(place.region) != site:
			from_sites.append([_angle_between(site, int(place.region)), int(place.region)])
	from_sites.sort_custom(
		func(a: Array, b: Array) -> bool:
			return (
				int(a[1]) < int(b[1]) if float(a[0]) == float(b[0]) else float(a[0]) < float(b[0])
			)
	)
	var regions: Array = sim.state.world.regions
	for row: Array in from_sites:
		var from: int = int(row[1])
		if int(regions[from].landmass) == int(regions[site].landmass):
			var road: Dictionary = sim.road_quote(from, site, "valley")
			if not bool(road.reachable) or int(road.days) > VALLEY_ROAD_DAYS:
				road = sim.road_quote(from, site, "engineered")
			if bool(road.reachable):
				return {
					"from": from,
					"variant": str(road.variant),
					"cost": float(road.cost),
					"days": int(road.days),
				}
		else:
			var voyage: Dictionary = sim.road_quote(from, site, "sea")
			if bool(voyage.reachable):
				return {
					"from": from,
					"variant": "sea",
					"cost": float(voyage.cost),
					"days": int(voyage.days)
				}
	return {}


func _connect_settlements(reserve: float) -> void:
	for site: Variant in _unconnected():
		var link: Dictionary = _best_link(int(site))
		# A shuttle carries a little at once while the road is saved for and built.
		if uses_shuttle and not link.is_empty():
			_shuttle_to(int(link.from), int(site), reserve)
		# Food and materials wait on this road: it comes before any cushion.
		if not link.is_empty() and float(sim.state.cash) >= float(link.cost) + reserve * 0.1:
			act("connect", {"a": int(link.from), "b": int(site), "variant": link.variant})
		return


## A shuttle line to a new outpost with no link yet, when the cash is there.
func _shuttle_to(from: int, site: int, reserve: float) -> void:
	if not sim.Logistics.road_between(sim, from, site).is_empty():
		return
	var quote: Dictionary = sim.road_quote(from, site, sim.Keys.ROUTE_SHUTTLE)
	if str(quote.refusal) == "" and float(sim.state.cash) >= float(quote.cost) + reserve:
		act("connect", {"a": from, "b": site, "variant": sim.Keys.ROUTE_SHUTTLE})


## A link that runs full holds up everything behind it: pave or widen the road, or enlarge the
## docks, when the next level is open and the money is there.
func _upgrade_busy_links(reserve: float) -> void:
	for road: Dictionary in sim.state.roads:
		if float(road.sent_today) <= float(road.capacity):
			continue
		var step: Dictionary = sim.Logistics.next_level(sim, road)
		if step.is_empty() or str(step.refusal) != "":
			continue
		if float(sim.state.cash) > float(step.cost) + reserve:
			act("upgrade_road", {"road": int(road.id)})
			return


## Idle hands turn into a company review. Wages mostly come back as food sales, so work that
## only pays for itself is still worth creating.
func _create_jobs(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var idle: int = sim.free_workers(place)
		var adults: int = int(place.workers) + int(place.scientists)
		# Crews without work in a town with no ground left will move for a job down the road.
		var elsewhere: int = _idle_elsewhere(region)
		var idle_here: bool = (
			idle >= MIN_IDLE_WORKERS and float(idle) / maxi(1, adults) >= IDLE_SHARE
		)
		if not idle_here and elsewhere < JOBLESS_ELSEWHERE:
			continue
		for kind: String in _kinds_with_roles(JOB_ROLES, place):
			var role: String = sim.Production.role_of(sim, kind)
			if role == "factory" and not _factory_wanted(region, kind):
				continue
			if role == "commerce" and not _commerce_wanted(place):
				continue
			if role == "foodworks" and not _food_to_spare():
				continue
			if role == "harvest" and building_count(region, kind) >= HARVESTERS_PER_TOWN:
				continue
			var forecast: Dictionary = sim.build_forecast(region, kind)
			if forecast.is_empty() or forecast.disabled_reason != "":
				continue
			if int(forecast.jobs) > idle + elsewhere:
				continue
			if float(forecast.net_per_day) < MIN_JOB_NET:
				continue
			if (
				float(forecast.reserve_days) >= 0.0
				and float(forecast.reserve_days) < MIN_RESERVE_DAYS
			):
				continue
			if float(sim.state.cash) >= float(forecast.cost) + reserve * 0.25:
				act("build", {"region": region, "kind": kind})
				return


## Building kinds of these roles that this settlement could ever hold, by what is researched.
func _kinds_with_roles(roles: Array[String], place: Dictionary) -> Array:
	var kinds: Array = []
	for kind: String in sim.config.buildings:
		var spec: Dictionary = sim.config.buildings[kind]
		if not str(spec.role) in roles:
			continue
		if spec.has("requires_tech") and not sim._has(str(spec.requires_tech)):
			continue
		if spec.has("site_kinds") and not spec.site_kinds.has(str(place.kind)):
			continue
		kinds.append(kind)
	return kinds


## True while the contract still wants a bigger share of income from outside the mines.
func _needs_other_income() -> bool:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		return false
	# With a margin: a new mine would otherwise push the share straight back under the goal.
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "non_mining_share":
			return float(goal.value) < float(goal.target) * OTHER_INCOME_MARGIN
	return false


func _food_need() -> float:
	var need: float = 0.0
	for place: Dictionary in sim.state.settlements:
		need += float(place.population) * float(sim.config.economy.food_per_person)
	return need


func _farm_capacity() -> float:
	var capacity: float = 0.0
	for place: Dictionary in sim.state.settlements:
		var region: int = int(place.region)
		capacity += building_count(region, "farm") * _farm_output(region)
		for kind: String in [
			"field_station", "ranch", "hydroponic_farm", "aquafarm", "vertical_farm"
		]:
			var count: int = building_count(region, kind)
			if count > 0:
				capacity += count * float(sim.build_forecast(region, kind).outputs.get("food", 0.0))
	return capacity


## The next site worth a settlement and what kind to found there: food first, then people, then
## whatever the ground holds, near home.
func _next_site(reserve: float) -> Dictionary:
	var hungry: bool = _farm_capacity() < _food_need() * 1.2
	var towns: int = 0
	for place: Dictionary in sim.state.settlements:
		if str(place.kind) == sim.Keys.SITE_RESIDENTIAL:
			towns += 1
	var wants_town: bool = not hungry and towns < 1 + sim.state.settlements.size() / 3
	var kind: String = sim.Keys.SITE_RESIDENTIAL if wants_town else sim.Keys.SITE_FRONTIER
	var scored: Array = []
	var farm_land_in_reach: bool = false
	for reg: Dictionary in sim.state.world.regions:
		var id: int = int(reg.id)
		if not sim.settlement(id).is_empty():
			continue
		var on_land: bool = false
		for place: Dictionary in sim.state.settlements:
			on_land = on_land or int(place.region) in reg.neighbors
		if not on_land and not bool(reg.coast):
			continue
		var known: Dictionary = sim.site_view(id)
		if int(known.plots.general) < MIN_TOWN_PLOTS:
			continue
		# Yield falls with the soil and the climate, and the road gets longer with distance.
		var soil: float = float(known.farm_yield) / float(sim.config.buildings.farm.rate)
		var score: float = pow(soil, 3.0) * 1000.0
		if wants_town:
			score = float(known.plots.general) * (0.5 + float(known.water.mid)) * 10.0
		elif not hungry:
			score = sim.Sites.start_score(sim, id) * 0.01
		scored.append(
			[score / (0.4 + _angle_between(id, _nearest_settled(id))), id, float(known.farm_yield)]
		)
		farm_land_in_reach = farm_land_in_reach or float(known.farm_yield) >= MIN_LOCAL_FARM_OUTPUT
	scored.sort_custom(
		func(a: Array, b: Array) -> bool:
			return (
				int(a[1]) < int(b[1]) if float(a[0]) == float(b[0]) else float(a[0]) > float(b[0])
			)
	)
	# A settlement is only worth it with the money for the road that keeps it alive.
	for row: Array in scored.slice(0, SITE_TRIES):
		# Better to wait for the money than to settle barren ground because it is cheap to reach.
		if hungry and farm_land_in_reach and float(row[2]) < MIN_LOCAL_FARM_OUTPUT:
			continue
		var link: Dictionary = _best_link(int(row[1]))
		var stage: int = mini(int(sim.state.contract.stage), sim.Contract.STAGE_COUNT)
		var longest: int = FAR_EXPEDITION_DAYS if _pressed_for_time(stage) else EXPEDITION_DAYS
		if link.is_empty() or int(link.days) > longest:
			continue
		var fare: float = sim.Sites.expedition_cash(sim, kind)
		if float(sim.state.cash) >= fare + float(link.cost) + reserve * 0.3:
			return {"site": int(row[1]), "from": int(link.from), "kind": kind}
	return {}


func _second_settlement(reserve: float) -> void:
	_connect_settlements(reserve)
	if _saving_for_road() or sim.state.settlements.size() >= sim.Contract.settlement_cap(sim):
		return
	var next: Dictionary = _next_site(reserve)
	if not next.is_empty():
		act("settle", {"site": next.site, "from": next.from, "kind": next.kind})


func _farm_output(region: int) -> float:
	var forecast: Dictionary = sim.build_forecast(region, "farm")
	if forecast.is_empty():
		return 0.0
	return float(forecast.outputs.get("food", 0.0))


func _food(reserve: float) -> void:
	# A road to the farms is worth more than another farm nobody can reach.
	if _saving_for_road() and _farm_capacity() > 0.0:
		return
	var consumption: float = 0.0
	var capacity: float = _farm_capacity()
	for place: Dictionary in sim.state.settlements:
		consumption += float(place.population) * float(sim.config.economy.food_per_person)
	# The contract counts what the colony grew, not what it could have grown.
	var wants_local: bool = _wants_local_food()
	if capacity >= consumption and not wants_local:
		return
	# Imported food costs little more than poor land yields; only farm land worth farming.
	var best_region: int = -1
	var best_kind: String = "farm"
	var best_output: float = MIN_LOCAL_FARM_OUTPUT if wants_local else MIN_FARM_OUTPUT
	for place: Dictionary in _places():
		for kind: String in ["field_station", "farm", "ranch"]:
			var forecast: Dictionary = sim.build_forecast(int(place.region), kind)
			if forecast.is_empty() or forecast.disabled_reason != "":
				continue
			if sim.free_workers(place) + _idle_elsewhere(int(place.region)) < int(forecast.jobs):
				continue
			var output: float = float(forecast.outputs.get("food", 0.0))
			if output > best_output:
				best_output = output
				best_region = int(place.region)
				best_kind = kind
	# Under glass one greenhouse does the work of several farms on poor land.
	if best_region < 0 and wants_local:
		_greenhouse(reserve)
		return
	if best_region < 0 or _building_underway(best_region, best_kind):
		return
	# The first farm is a shortage to fix, not an investment to weigh.
	var spare: float = 0.0 if capacity <= 0.0 else reserve * 0.5
	if _affordable(best_region, best_kind, spare):
		act("build", {"region": best_region, "kind": best_kind})


## One road feeds fewer than two hundred people. A town that outgrows its road, or is running
## short, gets a port of its own; a town short of food in spite of its port grows some indoors.
func _feed_towns(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var short: bool = float(place.food_days) < LOW_FOOD_DAYS
		if float(place.port_capacity) <= 0.0 and (short or int(place.population) >= PORT_PEOPLE):
			if not _building_underway(region, "port") and _affordable(region, "port", 0.0):
				act("build", {"region": region, "kind": "port"})
			continue
		if not short or not _port_full(place):
			continue
		for kind: String in _kinds_with_roles(["indoor_farm"], place):
			if not _building_underway(region, kind) and _affordable(region, kind, reserve * 0.5):
				act("build", {"region": region, "kind": kind})
				break


## Out of farm land with a food goal still open: grow it under glass.
func _greenhouse(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		for kind: String in _kinds_with_roles(["indoor_farm"], place):
			if sim.free_workers(place) < int(sim.config.buildings[kind].jobs):
				continue
			if not _building_underway(region, kind) and _affordable(region, kind, reserve * 0.5):
				act("build", {"region": region, "kind": kind})
				return


## A settlement out of building ground needs taller housing before it needs anything else.
func _short_of_ground() -> bool:
	for place: Dictionary in sim.state.settlements:
		if int(sim.Sites.free_counts(sim, int(place.region)).general) <= 2:
			return true
	return false


## A depleted mine anywhere is the moment to learn to dig deeper.
func _mines_running_out() -> bool:
	for place: Dictionary in sim.state.settlements:
		for building: Dictionary in place.buildings:
			if str(building.status) == sim.Keys.B_DEPLETED:
				return true
	return false


## A food goal with no good land left needs a technology, not more waiting.
func _out_of_farm_land() -> bool:
	if not _wants_local_food():
		return false
	for place: Dictionary in sim.state.settlements:
		if _farm_output(int(place.region)) >= MIN_FARM_OUTPUT:
			if sim.build_forecast(int(place.region), "farm").plot >= 0:
				return false
	return true


func _wants_local_food() -> bool:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		return false
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "local_food_share" and not goal.ok:
			return true
	return false


## Worked-out mines give their ground back when the town has run out of room to build.
func _clear_spent_mines() -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		if int(sim.Sites.free_counts(sim, region).general) > 0:
			continue
		for index: int in range(place.buildings.size()):
			if str(place.buildings[index].status) == sim.Keys.B_DEPLETED:
				act("demolish", {"region": region, "index": index})
				break


func _housing(reserve: float) -> void:
	_clear_spent_mines()
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var slack: int = maxi(4, int(float(place.housing) * 0.08))
		if sim.Population.free_beds(sim, place) >= slack:
			continue
		var busy: bool = false
		for kind: String in HOUSING_KINDS:
			busy = busy or _building_underway(region, kind)
		if busy:
			continue
		var full: bool = int(place.housing) <= int(place.population)
		var spare: float = 0.0 if full else reserve * 0.5
		if int(sim.Sites.free_counts(sim, region).general) <= 0:
			_make_room(place, spare)
			continue
		for kind: String in HOUSING_KINDS:
			var forecast: Dictionary = sim.build_forecast(region, kind)
			if forecast.is_empty() or forecast.disabled_reason != "":
				continue
			if (
				float(forecast.cost) > float(sim.state.cash) * BIG_BUILDING_CASH_SHARE
				and kind != "habitat"
				and kind != "crew_quarters"
			):
				continue
			if _affordable(region, kind, spare):
				act("build", {"region": region, "kind": kind})
			break


## No ground left: fit more beds into the old blocks, then pull one down for something taller.
func _make_room(place: Dictionary, reserve: float) -> void:
	var region: int = int(place.region)
	var oldest: int = -1
	for index: int in range(place.buildings.size()):
		if str(place.buildings[index].kind) != "habitat":
			continue
		if int(place.buildings[index].remaining) > 0:
			continue
		oldest = index
		var rule: Dictionary = sim.upgrade_preview(region, index)
		if rule.is_empty():
			continue
		if rule.disabled_reason == "" and float(sim.state.cash) >= float(rule.cost) + reserve:
			act("upgrade", {"region": region, "index": index})
			return
	# Pulling down a block with nowhere for its people to go is how a review starts.
	if sim.Population.free_beds(sim, place) < SWAP_FREE_BEDS:
		return
	for kind: String in SWAP_KINDS:
		var spec: Dictionary = sim.config.buildings[kind]
		if not sim._has(str(spec.get("requires_tech", ""))) or oldest < 0:
			continue
		if float(sim.state.cash) >= float(spec.cost) * 2.0 + reserve:
			act("demolish", {"region": region, "index": oldest})
			act("build", {"region": region, "kind": kind})
			return


## Once its technology is known, the money goes to the hall before anything that can wait.
func _saving_for_hall() -> bool:
	var unbuilt: bool = sim._has(HALL_TECH) and not _anywhere("capital_hall")
	return unbuilt and float(sim.state.cash) < RICH_CASH


func _pressed_for_time(stage: int) -> bool:
	return int(sim.state.day) > sim.Contract.deadline(sim, stage) * DEADLINE_PRESSED


## The contract asks for another connected town and the licence is there: that comes first.
func _saving_for_settlement() -> bool:
	if sim.state.settlements.size() >= sim.Contract.settlement_cap(sim):
		return false
	var stage: int = mini(int(sim.state.contract.stage), sim.Contract.STAGE_COUNT)
	# Saving out of a thin income takes for ever; better to grow it first, unless time is short.
	var pressed: bool = int(sim.state.day) > sim.Contract.deadline(sim, stage) * DEADLINE_PRESSED
	if float(sim.summary().operating_average) < COMFORTABLE_NET and not pressed:
		return false
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key in ["connected", "frontiers"] and not goal.ok:
			return (
				float(sim.state.settlements.size()) < float(goal.target) or goal.key == "frontiers"
			)
	return false


## A full port is worth more than anything else money can buy: nothing else until it has company.
func _saving_for_port() -> bool:
	for place: Dictionary in _places():
		if _port_full(place):
			return true
	return false


## Whether this town's exports already fill its port, counting a port still being built as room.
func _port_full(place: Dictionary) -> bool:
	if _building_underway(int(place.region), "port"):
		return false
	var capacity: float = float(place.port_capacity)
	return capacity > 0.0 and float(place.port_used) / capacity > PORT_BUSY_SHARE


func _enterprise() -> void:
	if not sim.state.enterprise.is_empty() or not sim.state.policy.private_allowed:
		return
	if int(sim.state.contract.stage) < 2:
		return
	if float(sim.enterprise_preview(home).get("estimated_profit", -1.0)) >= 0.0:
		act("enterprise", {"region": home})


## Investments open to the colony, best payback first, ignoring only whether workers are free.
func _options(reserve: float) -> Array:
	var options: Array = []
	var other_income: bool = _needs_other_income()
	var leading_good: String = _dominant_export()
	for place: Dictionary in _places():
		var region: int = int(place.region)
		for kind: String in _kinds_with_roles(INVEST_ROLES, place):
			var role: String = sim.Production.role_of(sim, kind)
			if other_income and role in EXTRACTION_ROLES:
				continue
			if role == "factory" and not _factory_wanted(region, kind):
				continue
			if role == "commerce" and not _commerce_wanted(place):
				continue
			if role == "harvest" and building_count(region, kind) >= HARVESTERS_PER_TOWN:
				continue
			var forecast: Dictionary = sim.build_forecast(region, kind)
			if forecast.is_empty() or forecast.disabled_reason != "":
				continue
			var payback: float = float(forecast.payback_days)
			if payback <= 0.0 or payback > payback_limit:
				continue
			var reserves: float = float(forecast.reserve_days)
			if reserves >= 0.0 and reserves < MIN_RESERVE_DAYS:
				continue
			# Another mine into a market already flooded earns less than its forecast says.
			if role == "mine" and _flooded(str(sim.config.buildings[kind].output)):
				continue
			# Ore the port cannot ship earns nothing at all.
			if role in EXTRACTION_ROLES and _port_full(place):
				continue
			var cushion: float = reserve
			if leading_good != "" and not forecast.outputs.has(leading_good):
				cushion *= DIVERSIFY_CUSHION
			if float(sim.state.cash) < float(forecast.cost) + cushion:
				continue
			options.append(
				{"region": region, "kind": kind, "jobs": int(forecast.jobs), "payback": payback}
			)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.payback < b.payback)
	return options


## A factory needs its inputs within reach and enough people around to be worth running.
func _factory_wanted(region: int, kind: String) -> bool:
	for building: Dictionary in sim.settlement(region).buildings:
		if str(building.kind) == kind and str(building.status) in IDLE_STATUSES:
			return false
	var other_income: bool = _needs_other_income()
	var allowed: int = 1 + sim.Contract.population_total(sim) / FACTORY_PEOPLE
	allowed += 2 if other_income else 0
	if building_count(region, kind) >= allowed:
		return false
	for good: String in sim.config.buildings[kind].inputs:
		if not _made_within_reach(region, str(good)):
			return false
	return true


func _made_within_reach(region: int, good: String) -> bool:
	for place: Dictionary in sim.state.settlements:
		var here: bool = int(place.region) == region
		if (
			not here
			and sim.road_quote(int(place.region), region, "valley").get("refusal", "") == ""
		):
			continue
		for building: Dictionary in place.buildings:
			if str(building.status) == sim.Keys.B_DEPLETED:
				continue
			var spec: Dictionary = sim.config.buildings.get(building.kind, {})
			if str(spec.get("output", "")) == good or spec.get("outputs", {}).has(good):
				return true
	return good == "food"


func _commerce_wanted(place: Dictionary) -> bool:
	return building_count(int(place.region), "commerce") < int(place.population) / COMMERCE_PEOPLE


## People the contract still asks for; once it is met, only as many as there are open jobs.
func _people_goal() -> int:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		var total: int = sim.Contract.population_total(sim)
		for place: Dictionary in sim.state.settlements:
			total += maxi(0, int(place.jobs) - int(place.employed))
		return total
	var goal_people: int = 0
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "population":
			goal_people = mini(population_goal, int(goal.target))
	return goal_people


## Recruiting pays back within weeks once there is work waiting or a people goal to meet.
func _recruit(region: int, wanted: int, reserve: float, for_goal: bool = false) -> bool:
	if recruit_batch <= 0 or (not for_goal and _jobless_share() > RECRUIT_JOBLESS_LIMIT):
		return false
	if _saving_for_hall():
		return false
	var counts: Dictionary = _adult_counts()
	var kind: String = "worker"
	if (
		float(counts.scientists) / maxi(1, int(counts.adults)) < science_target
		and sim._has(SCIENCE_TECH)
		and has_building(home, "lab")
		and sim.Population.free_beds(sim, sim.settlement(home)) > 0
	):
		kind = "scientist"
		region = home
	var place: Dictionary = sim.settlement(region)
	# The price goes up with every campaign: a goal is met with fewer, larger ones.
	var limit: int = LARGE_CAMPAIGN if for_goal else recruit_batch
	var batch: int = mini(mini(limit, wanted), sim.Population.free_beds(sim, place))
	if batch < 1:
		return false
	var cost: float = sim.Population.campaign_price(sim, kind) * batch
	if float(sim.state.cash) < cost + reserve + recruit_buffer:
		return false
	return act("recruit", {"region": region, "kind": kind, "count": batch}) == ""


func _jobless_share() -> float:
	var adults: int = 0
	var employed: int = 0
	for place: Dictionary in sim.state.settlements:
		adults += int(place.workers) + int(place.scientists)
		employed += int(place.employed)
	return 1.0 - float(employed) / maxi(1, adults)


func _adult_counts() -> Dictionary:
	var adults: int = 0
	var scientists: int = 0
	for place: Dictionary in sim.state.settlements:
		adults += int(place.workers) + int(place.scientists)
		scientists += int(place.scientists)
	return {"adults": adults, "scientists": scientists}


func _goal_projects(reserve: float) -> void:
	var stage: int = mini(int(sim.state.contract.stage), sim.Contract.STAGE_COUNT)
	var needs_processing: bool = false
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "processing_days" and not goal.ok:
			needs_processing = true
	if needs_processing and not has_building(home, "processor"):
		if sim.free_workers(sim.settlement(home)) >= int(sim.config.buildings.processor.jobs):
			if _affordable(home, "processor", reserve * 0.5):
				act("build", {"region": home, "kind": "processor"})
		else:
			_recruit(home, int(sim.config.buildings.processor.jobs), reserve * 0.5)
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "capital_population" and not goal.ok:
			_recruit(home, int(goal.target) - int(goal.value), reserve, true)
		# With the deadline close, people count whether or not there is work for all of them yet.
		if goal.key == "population" and not goal.ok and _pressed_for_time(stage):
			for place: Dictionary in _places():
				if _recruit(int(place.region), int(goal.target) - int(goal.value), reserve, true):
					break


## Workers without a job in other towns on the network: a vacancy here will draw them.
func _idle_elsewhere(region: int) -> int:
	var idle: int = 0
	for place: Dictionary in _places():
		if int(place.region) != region:
			idle += sim.free_workers(place)
	return idle


## Cleaner air once it starts to cost something; a scrubber as soon as there is anything to scrub.
func _environment(reserve: float) -> void:
	if not clean_air:
		return
	var loss: float = sim.Pollution.penalty(sim)
	if loss >= SCRUBBER_AT and sim._has("scrubbing") and not _anywhere_underway("scrubber"):
		for place: Dictionary in _places():
			if _affordable(int(place.region), "scrubber", reserve):
				act("build", {"region": int(place.region), "kind": "scrubber"})
				break
	if loss >= POLLUTION_CLEANUP_AT:
		if float(sim.state.cash) > sim.Pollution.cleanup_cost(sim) + reserve:
			act("company", {"operation": "cleanup"})


func _anywhere_underway(kind: String) -> bool:
	for place: Dictionary in sim.state.settlements:
		if _building_underway(int(place.region), kind):
			return true
	return false


## A port near capacity turns away the most valuable exports last; add one before it costs money.
func _ports(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var capacity: float = float(place.port_capacity)
		if capacity <= 0.0 or _building_underway(region, "port"):
			continue
		if (
			float(place.port_used) / capacity > PORT_BUSY_SHARE
			and _affordable(region, "port", reserve * 0.1)
		):
			act("build", {"region": region, "kind": "port"})


## Farms grow more than people and the food works already take, by a working margin.
func _food_to_spare() -> bool:
	var used: float = _food_need()
	for place: Dictionary in sim.state.settlements:
		used += (
			building_count(int(place.region), "foodworks")
			* float(sim.config.buildings.foodworks.food_input)
		)
	return _farm_capacity() > used + float(sim.config.buildings.foodworks.food_input) * 1.5


## Food works turn farm surplus into export income that does not run out.
func _food_works(reserve: float) -> void:
	if not sim._has("adaptation") or not _food_to_spare():
		return
	var jobs: int = int(sim.config.buildings.foodworks.jobs)
	for place: Dictionary in _places():
		var region: int = int(place.region)
		if has_building(region, "foodworks") or sim.free_workers(place) < jobs:
			continue
		if region != home and building_count(region, "farm") == 0:
			continue
		if float(place.port_capacity) <= 0.0:
			if _affordable(region, "port", reserve) and not _building_underway(region, "port"):
				act("build", {"region": region, "kind": "port"})
			continue
		if _affordable(region, "foodworks", reserve):
			act("build", {"region": region, "kind": "foodworks"})
			return


func _invest(reserve: float) -> void:
	_food_works(reserve)
	for option: Dictionary in _options(reserve):
		var free: int = sim.free_workers(sim.settlement(int(option.region)))
		if free + _idle_elsewhere(int(option.region)) >= int(option.jobs):
			act("build", {"region": option.region, "kind": option.kind})
			return
		if _recruit(int(option.region), int(option.jobs) - free, reserve):
			return
	var missing: int = _people_goal() - sim.Contract.population_total(sim)
	if missing > 0:
		for place: Dictionary in _places():
			if _recruit(int(place.region), missing, reserve):
				return


## Public cash over the mean daily operating expense of the recent past (`Sim.cash_cover`).
func cash_cover() -> float:
	return sim.cash_cover()


## Money with nothing better to do buys people a better life, a level at a time.
func _public_services() -> void:
	if not uses_services or today() % SERVICES_REVIEW_PERIOD != 0:
		return
	var level: int = int(sim.state.policy.get("services", 0))
	var cover: float = cash_cover()
	if cover >= SERVICES_UP_COVER and level < int(sim.pop_rules.services.levels):
		act("policy", {"services": level + 1})
	elif cover < SERVICES_DOWN_COVER and level > 0:
		act("policy", {"services": level - 1})


## Late great works: the next stage or level of one that stands, else the next one unlocked, when
## cash pays for it and keeps `LATE_WORKS_RESERVE_DAYS` of expenses. One step a review.
func _late_great_works() -> void:
	if not uses_great_works or today() % COMMISSION_REVIEW_PERIOD != 0:
		return
	var step: Dictionary = _next_late_work()
	if step.is_empty() or float(sim.state.cash) < float(step.cost) + _late_work_keep():
		return
	var region: int = int(step.region)
	var kind: String = str(step.kind)
	# The cost counts the supplies, so a refusal is something saving cannot fix: the step is left
	# alone for a while. Great works need no crews to work, so none are waited for.
	if str(step.action) == "upgrade":
		if act("upgrade", {"region": region, "index": int(step.index)}) != "":
			late_work_blocked[UPGRADE_KEY + kind] = today()
		return
	if sim.Sites.find_plot(sim, region, kind) < 0 and not _clear_ground(region):
		late_work_blocked[kind] = today()
		return
	# The plot just cleared goes to the great work at once.
	if act("build", {"region": region, "kind": kind}) != "":
		late_work_blocked[kind] = today()


## The next late great work step open now: {action, region, index or kind, cost}, or empty.
func _next_late_work() -> Dictionary:
	for place: Dictionary in _places():
		for index: int in range(place.buildings.size()):
			if not place.buildings[index].kind in LATE_WORKS:
				continue
			var rule: Dictionary = sim.upgrade_preview(int(place.region), index)
			if (
				rule.is_empty()
				or not sim._has(str(rule.tech))
				or int(place.buildings[index].remaining) > 0
			):
				continue
			if int(place.buildings[index].get("upgrade_days", 0)) > 0:
				continue
			var kind: String = str(place.buildings[index].kind)
			if _late_work_waiting(UPGRADE_KEY + kind):
				continue
			return {
				"action": "upgrade",
				"region": int(place.region),
				"index": index,
				"kind": kind,
				"cost": float(rule.cost) + float(rule.get("supply_cost", 0.0)),
			}
	for kind: String in LATE_WORKS:
		if not sim._has(str(sim.config.buildings[kind].requires_tech)) or _anywhere(kind):
			continue
		var at: int = _late_work_site(kind)
		if at < 0 or _late_work_waiting(kind):
			continue
		var forecast: Dictionary = sim.build_forecast(at, kind)
		if forecast.is_empty():
			continue
		return {"action": "build", "region": at, "kind": kind, "cost": _with_supplies(forecast)}
	return {}


func _late_work_waiting(key: String) -> bool:
	return today() - int(late_work_blocked.get(key, -LATE_WORK_RETRY_DAYS)) < LATE_WORK_RETRY_DAYS


## A build's price with its materials and parts bought at import price, as an empty warehouse
## would have it.
func _with_supplies(forecast: Dictionary) -> float:
	var supplies: float = (
		float(forecast.materials) * float(sim.config.prices.materials)
		+ float(forecast.parts) * float(sim.config.prices.parts)
	)
	return float(forecast.cost) + supplies * (1.0 + float(sim.config.economy.port_fee))


## Where a late great work can stand, by the rules and not the money: a town of the kind it needs
## with a plot for it, home first; when every such town is full, the first with a public factory to
## pull down for it. The capital district goes only in the hall's town, cleared the same way. -1
## when there is none.
func _late_work_site(kind: String) -> int:
	if kind == "capital_district":
		return _hall_town()
	var towns: Array[int] = [home]
	for place: Dictionary in _places():
		if int(place.region) != home:
			towns.append(int(place.region))
	var fallback: int = -1
	for region: int in towns:
		var place: Dictionary = sim.settlement(region)
		var spec: Dictionary = sim.build_preview(region, kind)
		var ground: Dictionary = sim.state.world.regions[region]
		if sim.Production._place_refusal(place, ground, spec) != "":
			continue
		if sim.Sites.find_plot(sim, region, kind) >= 0:
			return region
		if fallback < 0 and _public_factory(place) >= 0:
			fallback = region
	return fallback


## The first public factory in a town, which a great work may replace; -1 when there is none.
func _public_factory(place: Dictionary) -> int:
	for index: int in range(place.buildings.size()):
		var building: Dictionary = place.buildings[index]
		if str(building.get("owner", "public")) != "public" or int(building.remaining) > 0:
			continue
		if sim.Production.role_of(sim, str(building.kind)) == "factory":
			return index
	return -1


func _late_work_keep() -> float:
	var days: float = (
		LATE_WORKS_RESERVE_DAYS
		if str(sim.state.status) == "success"
		else LATE_WORKS_EARLY_RESERVE_DAYS
	)
	return days * float(sim.cover_view().expense)


## After the award, new investment waits while the next late great work is being saved for.
func _saving_for_great_work() -> bool:
	if not uses_great_works or str(sim.state.status) != "success":
		return false
	var step: Dictionary = _next_late_work()
	return not step.is_empty() and float(sim.state.cash) < float(step.cost) + _late_work_keep()


## The settlement with the capital hall, or -1.
func _hall_town() -> int:
	for place: Dictionary in _places():
		for b: Dictionary in place.buildings:
			if b.kind == "capital_hall" and int(b.remaining) <= 0:
				return int(place.region)
	return -1


## Commissions on what the charter needs next (or on every running project), by cash cover.
func _commissions() -> void:
	if not uses_commissions or today() % COMMISSION_REVIEW_PERIOD != 0:
		return
	var cover: float = cash_cover()
	var level: int = 0
	if cover >= commission_cover * 2.0:
		level = 2
	elif cover >= commission_cover:
		level = 1
	var chain: Dictionary = _hall_chain()
	var targets: Array = []
	for column: Dictionary in sim.research_cards():
		var running: Dictionary = column.running
		if not running.is_empty():
			targets.append(str(running.id))
	if not commission_all:
		var goal: Array = targets.filter(func(tech: String) -> bool: return chain.has(tech))
		targets = goal.slice(0, 1) if not goal.is_empty() else targets.slice(0, 1)
	var projects: Dictionary = sim.state.research.projects
	for tech: String in projects:
		var wanted: int = level if targets.has(tech) else 0
		if cover < COMMISSION_FLOOR_COVER:
			wanted = 0
		if (
			int(projects[tech].get("commission", 0)) != wanted
			and not sim.state.research.completed.has(tech)
		):
			act("research_commission", {"tech": tech, "level": wanted})


## After the award, money a finished colony has no use for goes to the career balance, keeping
## `TRANSFER_COVER` days of expenses at home.
func _career_transfer() -> void:
	if not uses_transfer or today() % TRANSFER_REVIEW_PERIOD != 0:
		return
	if str(sim.state.status) != "success":
		return
	var cover: Dictionary = sim.cover_view()
	var spare: float = float(sim.state.cash) - TRANSFER_COVER * float(cover.expense)
	var view: Dictionary = sim.Career.transfer_preview(sim)
	var amount: float = floorf(minf(float(view.room), spare / float(view.rate)))
	if amount >= 1.0:
		act("career_transfer", {"amount": amount})


## Raises pay only when people are staying away for lack of appeal, not for lack of beds or food.
func _wages() -> void:
	if fixed_wage > 0.0:
		if not is_equal_approx(float(sim.state.policy.wage), fixed_wage):
			act("policy", {"wage": fixed_wage})
		return
	if today() < WAGE_REVIEW_FROM_DAY:
		return
	var lowest: float = 2.0
	for place: Dictionary in _places():
		if sim.Population.free_beds(sim, place) > 0 and float(place.food_days) >= 7.0:
			lowest = minf(lowest, float(place.attractiveness))
	if today() - last_wage_change < WAGE_REVIEW_PERIOD:
		return
	var wage: float = float(sim.state.policy.wage)
	if _tight():
		if wage > 1.0:
			act("policy", {"wage": wage - WAGE_STEP})
			last_wage_change = today()
	elif lowest < 1.0 and wage < WAGE_LIMIT:
		act("policy", {"wage": wage + WAGE_STEP})
		last_wage_change = today()
	elif lowest > 1.4 and lowest < 2.0 and wage > 1.0:
		act("policy", {"wage": wage - WAGE_STEP})
		last_wage_change = today()


## People stay where there is something to stay for: each town gets what its size calls for.
func _services(reserve: float) -> void:
	for place: Dictionary in _places():
		if str(place.kind) != sim.Keys.SITE_RESIDENTIAL:
			continue
		var region: int = int(place.region)
		for kind: String in SERVICE_PEOPLE:
			if has_building(region, kind) or int(place.population) < int(SERVICE_PEOPLE[kind]):
				continue
			var forecast: Dictionary = sim.build_forecast(region, kind)
			if forecast.is_empty() or forecast.disabled_reason != "":
				continue
			if sim.free_workers(place) < int(forecast.jobs):
				continue
			if float(sim.state.cash) >= float(forecast.cost) + reserve:
				act("build", {"region": region, "kind": kind})
				return


## The good bringing in over half of recent export money, if there is one: depending on a single
## market is worth spending some of the cushion to end.
func _dominant_export() -> String:
	if str(sim.state.status) != "success":
		return ""
	var goods: Dictionary = sim.stats_window(EXPORT_WINDOW_DAYS).goods
	var total: float = 0.0
	var top: float = 0.0
	var leader: String = ""
	for good: String in goods:
		var value: float = float(goods[good][sim.Stats.EXPORTED]) * sim.Market.price(sim, good)
		total += value
		if value > top:
			top = value
			leader = good
	return leader if total > 0.0 and top / total > DOMINANT_SHARE else ""


func _flooded(good: String) -> bool:
	return sim.Market.factor(sim, good) < MIN_MARKET_FACTOR


## A week of losses and little cash left: no bigger bills until the books recover.
func _tight() -> bool:
	return (
		float(sim.summary().operating_average) < 0.0
		and float(sim.state.cash) < daily_expense() * reserve_days
	)


func _upgrades(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		for index: int in range(place.buildings.size()):
			var rule: Dictionary = sim.upgrade_preview(region, index)
			if rule.is_empty() or rule.disabled_reason != "":
				continue
			if float(sim.state.cash) < float(rule.cost) + reserve:
				continue
			if not _upgrade_worthwhile(place, place.buildings[index], rule):
				continue
			if act("upgrade", {"region": region, "index": index}) == "":
				return


func _upgrade_worthwhile(place: Dictionary, building: Dictionary, rule: Dictionary) -> bool:
	# Great works grow by their own rule, from cash cover (_late_great_works).
	if bool(sim.config.buildings[building.kind].get("megaproject", false)):
		return false
	var extra_jobs: int = int(rule.get("jobs", 0))
	match str(building.kind):
		"mine_ore", "mine_copper", "mine_crystal":
			var seam: Dictionary = sim.state.world.regions[int(place.region)].plots[int(
				building.plot
			)]
			var rate: float = float(sim.config.buildings[building.kind].rate)
			return float(seam.reserves) > rate * MIN_RESERVE_DAYS * 2.0
		"lab":
			return true
		"habitat":
			return sim.Population.free_beds(sim, place) < 10
		"port":
			return float(place.port_used) / maxf(1.0, float(place.port_capacity)) > PORT_BUSY_SHARE
	return sim.free_workers(place) >= extra_jobs


## The hall is what the final stage asks for; the other great works wait for spare money.
func _megaprojects(reserve: float) -> void:
	if sim._has(HALL_TECH) and not _anywhere("capital_hall"):
		var site: int = _hall_site()
		if site < 0:
			# Only when the money and the crews are there: the plot goes straight to the hall.
			var hall: Dictionary = sim.build_preview(home, "capital_hall")
			var ready: bool = float(sim.state.cash) >= float(hall.cost) + reserve
			if ready and sim.free_workers(sim.settlement(home)) >= int(hall.jobs):
				_clear_ground(home)
				act("build", {"region": home, "kind": "capital_hall"})
			return
		if sim.free_workers(sim.settlement(site)) < int(sim.config.buildings.capital_hall.jobs):
			_recruit(site, int(sim.config.buildings.capital_hall.jobs), reserve)
			return
		if _affordable(site, "capital_hall", reserve * 0.5):
			act("build", {"region": site, "kind": "capital_hall"})
		return
	if str(sim.state.status) != "success" and int(sim.state.contract.stage) < 4:
		return
	for kind: String in MEGAPROJECTS:
		var needed: String = str(sim.config.buildings[kind].requires_tech)
		if not sim._has(needed) or _anywhere(kind):
			continue
		# Scientists live at home: a university anywhere else would stand empty.
		var at: int = home if int(sim.Sites.free_counts(sim, home).general) > 0 else _roomiest()
		if at < 0:
			return
		if sim.free_workers(sim.settlement(at)) < int(sim.config.buildings[kind].jobs):
			_recruit(at, int(sim.config.buildings[kind].jobs), reserve)
			return
		if _affordable(at, kind, reserve * MEGAPROJECT_RESERVE_FACTOR):
			act("build", {"region": at, "kind": kind})
		return


## The hall goes up in a residential town with ground to spare, the capital if it can.
func _hall_site() -> int:
	var best: int = -1
	var most: int = 0
	for place: Dictionary in _places():
		if str(place.kind) != sim.Keys.SITE_RESIDENTIAL:
			continue
		var region: int = int(place.region)
		var free: int = int(sim.Sites.free_counts(sim, region).general)
		if free > 0 and region == home:
			return home
		if free > most:
			most = free
			best = region
	return best


## Makes way for something that matters more than a factory that can stand elsewhere: pulls down
## the first public factory the town lets go. False when there is none.
func _clear_ground(region: int) -> bool:
	var place: Dictionary = sim.settlement(region)
	for index: int in range(place.buildings.size()):
		var building: Dictionary = place.buildings[index]
		if str(building.get("owner", "public")) != "public":
			continue
		if sim.Production.role_of(sim, str(building.kind)) != "factory":
			continue
		if act("demolish", {"region": region, "index": index}) == "":
			return true
	return false


func _anywhere(kind: String) -> bool:
	for place: Dictionary in sim.state.settlements:
		if has_building(int(place.region), kind):
			return true
	return false


## The settlement with the most free building ground.
func _roomiest() -> int:
	var best: int = -1
	var most: int = 0
	for place: Dictionary in _places():
		var free: int = int(sim.Sites.free_counts(sim, int(place.region)).general)
		if free > most:
			most = free
			best = int(place.region)
	return best


## Spare scientists earn money once there is nothing left they could research right now.
func _research_contract() -> void:
	if not sim._has(str(sim.progression.research.contract_tech)):
		return
	var view: Dictionary = sim.research_view()
	var spare: int = mini(int(view.available), int(view.capacity) - int(view.allocated))
	if (
		spare >= int(sim.progression.research.minimum_staff)
		and _staffed_projects() + 1 <= int(view.benches)
	):
		act("research_contract", {"staff": int(sim.state.research.contract.staff) + spare})
