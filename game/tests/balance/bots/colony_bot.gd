extends "res://tests/balance/bots/bot.gd"
## Shared decision logic for bots that play to win. Each day: answer events, fix shortages in the
## order food, water and power, labour, housing; keep a cash cushion; then invest in the best
## affordable option. The balanced, rush and research-first bots only change the parameters.

const INVEST_KINDS: Array[String] = [
	"mine_ore", "mine_copper", "mine_crystal", "processor", "component_plant"
]
const MEGAPROJECTS: Array[String] = ["university", "lift_port", "climate_regulator"]
const PLANTS_PER_PEOPLE: int = 200
const MEGAPROJECT_RESERVE_FACTOR: float = 1.5
const SCIENCE_TECH: String = "education"
const VALLEY_ROAD_DAYS: int = 6
const EXPEDITION_DAYS: int = 10
const SITE_TRIES: int = 5
const MIN_TOWN_PLOTS: int = 6
const MIN_IDLE_WORKERS: int = 8
const IDLE_SHARE: float = 0.15
const MIN_JOB_NET: float = -20.0
const JOB_KINDS: Array[String] = [
	"mine_crystal",
	"mine_copper",
	"mine_ore",
	"component_plant",
	"processor",
	"foodworks",
	"farm",
	"hydroponic_farm",
	"clinic",
	"lab",
]
const OUTPOST_CASH: float = 650.0
const UTILITY_MARGIN: float = 5.0
const PROCESSORS_PER_PEOPLE: int = 150
const MIN_FARM_OUTPUT: float = 15.0
const MIN_LOCAL_FARM_OUTPUT: float = 6.0
const WAGE_STEP: float = 0.1
const MIN_RESERVE_DAYS: float = 150.0
const POLLUTION_LIMIT: float = 32.0
const PORT_BUSY_SHARE: float = 0.9
const WAGE_LIMIT: float = 1.3
const WAGE_REVIEW_FROM_DAY: int = 30
const WAGE_REVIEW_PERIOD: int = 30

var home: int = 0
var reserve_days: float = 30.0
var payback_limit: float = 120.0
var recruit_batch: int = 10
var recruit_buffer: float = 500.0
var science_target: float = 0.12
var lab_day: int = 8
var population_goal: int = 100000
var last_wage_change: int = -1000
var fixed_wage: float = 0.0
var tech_order: Array[String] = [
	"survey",
	"education",
	"adaptation",
	"processing",
	"irrigation",
	"medicine",
	"logistics",
	"research_network",
	"deep_mining",
	"electronics",
	"efficiency",
	"hydroponics",
	"remediation",
	"paved_roads",
	"prospecting",
	"shipping",
	"automation",
	"university",
	"lift_port",
	"climate"
]


func on_day() -> void:
	if sim.state.settlements.is_empty():
		_land()
	answer_events()
	if sim.state.settlements.is_empty():
		return
	home = int(sim.state.settlements[0].region)
	var reserve: float = daily_expense() * reserve_days
	_utilities()
	_environment()
	_laboratory(reserve)
	_staff_research()
	_second_settlement(reserve)
	_food(reserve)
	_housing(reserve)
	_enterprise()
	_pave_busy_roads(reserve)
	if not _saving_for_road():
		_create_jobs(reserve)
		_invest(reserve)
		_clinic(reserve)
		_upgrades(reserve)
		_megaprojects(reserve)
	_research_contract()
	_wages()


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


func _option_value(options: Array, id: String) -> float:
	for option: Dictionary in options:
		if option.id != id:
			continue
		var value: float = float(option.get("reward", 0.0)) - float(option.get("pay", 0.0))
		for good: String in option.get("goods_reward", {}):
			value += float(option.goods_reward[good]) * float(sim.config.prices[good])
		for good: String in option.get("goods_cost", {}):
			value -= float(option.goods_cost[good]) * float(sim.config.prices[good])
		for effect: Dictionary in option.get("effects", []):
			value += (float(effect.factor) - 1.0) * 500.0
		if option.has("build"):
			value -= 400.0
		if option.has("investigate"):
			value += 50.0
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
		if power_margin < UTILITY_MARGIN and _affordable(region, "power", 0.0):
			if not _building_underway(region, "power"):
				act("build", {"region": region, "kind": "power"})
		var water_margin: float = float(place.water_supply) - float(place.water_demand)
		if water_margin < UTILITY_MARGIN and _affordable(region, "water", 0.0):
			if not _building_underway(region, "water"):
				act("build", {"region": region, "kind": "water"})


func _building_underway(region: int, kind: String) -> bool:
	for building: Dictionary in sim.settlement(region).get("buildings", []):
		if building.kind == kind and int(building.remaining) > 0:
			return true
	return false


func _laboratory(reserve: float) -> void:
	if today() < lab_day or _building_underway(home, "lab"):
		return
	if not has_building(home, "lab"):
		if _affordable(home, "lab", reserve * 0.5):
			act("build", {"region": home, "kind": "lab"})
		return
	# More scientists than seats: another laboratory puts them to work.
	var view: Dictionary = sim.research_view()
	if _saving_for_road() or int(view.total) <= int(view.capacity) + 2:
		return
	if _affordable(home, "lab", reserve):
		act("build", {"region": home, "kind": "lab"})


func _staff_research() -> void:
	if not has_building(home, "lab"):
		return
	var view: Dictionary = sim.research_view()
	var available: int = mini(int(view.available), int(view.capacity) - int(view.allocated))
	if available < 3 or _staffed_projects() >= int(view.benches):
		return
	var order: Array[String] = tech_order
	if _land_sites_left() < sim.Contract.settlement_cap(sim) - sim.state.settlements.size() + 1:
		order = ["logistics", "shipping"]
		order.append_array(tech_order)
	for tech: String in order:
		if sim.state.research.completed.has(tech):
			continue
		if int(sim.state.research.projects.get(tech, {}).get("staff", 0)) > 0:
			continue
		if act("research_allocate", {"tech": tech, "staff": mini(10, available)}) == "":
			return


func _staffed_projects() -> int:
	var count: int = 0
	for project: Dictionary in sim.state.research.projects.values():
		if int(project.staff) > 0:
			count += 1
	return count


## The contract needs the settlements connected: nothing else is worth delaying that for.
func _saving_for_road() -> bool:
	return sim.state.settlements.size() > 1 and not _unconnected().is_empty()


func _unconnected() -> Array:
	var missing: Array = []
	for at: int in range(1, sim.state.settlements.size()):
		var place: Dictionary = sim.state.settlements[at]
		var joined: bool = false
		for road: Dictionary in sim.state.roads:
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
		elif sim._has("shipping"):
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
		# Food and materials wait on this road: it comes before any cushion.
		if not link.is_empty() and float(sim.state.cash) >= float(link.cost) + reserve * 0.1:
			act("connect", {"a": int(link.from), "b": int(site), "variant": link.variant})
		return


## A road that runs full holds up everything behind it.
func _pave_busy_roads(reserve: float) -> void:
	if not sim._has(str(sim.config.road_upgrade.tech)):
		return
	for road: Dictionary in sim.state.roads:
		if bool(road.get("paved", false)) or str(road.get("variant", "")) == "sea":
			continue
		var cost: float = float(road.cost) * float(sim.config.road_upgrade.cost_factor)
		if float(road.sent_today) > float(road.capacity) and float(sim.state.cash) > cost + reserve:
			act("upgrade_road", {"road": int(road.id)})
			return


## Idle hands turn into a company review. Wages mostly come back as food sales, so work that
## only pays for itself is still worth creating.
func _create_jobs(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var idle: int = sim.free_workers(place)
		var adults: int = int(place.workers) + int(place.scientists)
		if idle < MIN_IDLE_WORKERS or float(idle) / maxi(1, adults) < IDLE_SHARE:
			continue
		for kind: String in JOB_KINDS:
			var forecast: Dictionary = sim.build_forecast(region, kind)
			if forecast.is_empty() or forecast.disabled_reason != "" or int(forecast.jobs) > idle:
				continue
			if float(forecast.net_per_day) < MIN_JOB_NET:
				continue
			if float(sim.state.cash) >= float(forecast.cost) + reserve * 0.25:
				act("build", {"region": region, "kind": kind})
				return


## True while the contract still wants a bigger share of income from outside the mines.
func _needs_other_income() -> bool:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		return false
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "non_mining_share" and not goal.ok:
			return true
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
	return capacity


## The next site worth a settlement: food first, then whatever the ground holds, near home.
func _next_site(reserve: float) -> Dictionary:
	var hungry: bool = _farm_capacity() < _food_need() * 1.2
	var scored: Array = []
	for reg: Dictionary in sim.state.world.regions:
		var id: int = int(reg.id)
		if not sim.settlement(id).is_empty():
			continue
		var on_land: bool = false
		for place: Dictionary in sim.state.settlements:
			on_land = on_land or int(place.region) in reg.neighbors
		if not on_land and not (sim._has("shipping") and bool(reg.coast)):
			continue
		var known: Dictionary = sim.site_view(id)
		if int(known.plots.general) < MIN_TOWN_PLOTS:
			continue
		# Yield falls with the soil and the road gets longer with distance: soil counts twice.
		var score: float = pow(float(known.fertility.mid), 3.0) * 1000.0
		if not hungry:
			score = sim.Sites.start_score(sim, id) * 0.01
		scored.append([score / (0.4 + _angle_between(id, _nearest_settled(id))), id])
	scored.sort_custom(
		func(a: Array, b: Array) -> bool:
			return (
				int(a[1]) < int(b[1]) if float(a[0]) == float(b[0]) else float(a[0]) > float(b[0])
			)
	)
	# A settlement is only worth it with the money for the road that keeps it alive.
	for row: Array in scored.slice(0, SITE_TRIES):
		var link: Dictionary = _best_link(int(row[1]))
		if link.is_empty() or int(link.days) > EXPEDITION_DAYS:
			continue
		if float(sim.state.cash) >= OUTPOST_CASH + float(link.cost) + reserve * 0.5:
			return {"site": int(row[1]), "from": int(link.from)}
	return {}


## Sites still in reach by land. Few left means it is time to learn to cross water.
func _land_sites_left() -> int:
	var left: int = 0
	for reg: Dictionary in sim.state.world.regions:
		if not sim.settlement(int(reg.id)).is_empty():
			continue
		for place: Dictionary in sim.state.settlements:
			if int(place.region) in reg.neighbors:
				left += 1
				break
	return left


func _second_settlement(reserve: float) -> void:
	_connect_settlements(reserve)
	if _saving_for_road() or sim.state.settlements.size() >= sim.Contract.settlement_cap(sim):
		return
	var next: Dictionary = _next_site(reserve)
	if not next.is_empty():
		act("settle", {"site": next.site})


func _farm_output(region: int) -> float:
	var forecast: Dictionary = sim.build_forecast(region, "farm")
	if forecast.is_empty():
		return 0.0
	return float(forecast.outputs.get("food", 0.0))


func _food(reserve: float) -> void:
	var consumption: float = 0.0
	var capacity: float = 0.0
	for place: Dictionary in sim.state.settlements:
		var region: int = int(place.region)
		consumption += float(place.population) * float(sim.config.economy.food_per_person)
		capacity += building_count(region, "farm") * _farm_output(region)
	# The contract counts what the colony grew, not what it could have grown.
	var wants_local: bool = _wants_local_food()
	if capacity >= consumption and not wants_local:
		return
	# Imported food costs little more than poor land yields; only farm land worth farming.
	var best_region: int = -1
	var best_output: float = MIN_LOCAL_FARM_OUTPUT if wants_local else MIN_FARM_OUTPUT
	for place: Dictionary in _places():
		var output: float = _farm_output(int(place.region))
		if output > best_output and sim.free_workers(place) >= int(sim.config.buildings.farm.jobs):
			best_output = output
			best_region = int(place.region)
	if best_region < 0 or _building_underway(best_region, "farm"):
		return
	# The first farm is a shortage to fix, not an investment to weigh.
	var spare: float = 0.0 if capacity <= 0.0 else reserve * 0.5
	if _affordable(best_region, "farm", spare):
		act("build", {"region": best_region, "kind": "farm"})


func _wants_local_food() -> bool:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		return false
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "local_food_share" and not goal.ok:
			return true
	return false


func _housing(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var slack: int = maxi(4, int(float(place.housing) * 0.08))
		if (
			sim.Population.free_beds(sim, place) < slack
			and not _building_underway(region, "habitat")
		):
			var full: bool = int(place.housing) <= int(place.population)
			if _affordable(region, "habitat", 0.0 if full else reserve * 0.5):
				act("build", {"region": region, "kind": "habitat"})


func _enterprise() -> void:
	if not sim.state.enterprise.is_empty() or not sim.state.policy.private_allowed:
		return
	if float(sim.enterprise_preview(home).get("estimated_profit", -1.0)) >= 0.0:
		act("enterprise", {"region": home})


## Investments open to the colony, best payback first, ignoring only whether workers are free.
func _options(reserve: float) -> Array:
	var options: Array = []
	var other_income: bool = _needs_other_income()
	for place: Dictionary in _places():
		var region: int = int(place.region)
		for kind: String in INVEST_KINDS:
			if other_income and kind.begins_with("mine_"):
				continue
			if kind == "processor":
				var allowed: int = 1 + sim.Contract.population_total(sim) / PROCESSORS_PER_PEOPLE
				allowed += 2 if other_income else 0
				if building_count(region, "processor") >= allowed or region != home:
					continue
			if kind == "component_plant" and not _plant_wanted(region):
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
			if float(sim.state.cash) < float(forecast.cost) + reserve:
				continue
			options.append(
				{"region": region, "kind": kind, "jobs": int(forecast.jobs), "payback": payback}
			)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.payback < b.payback)
	return options


## People the contract still asks for; once it is met, only as many as there are open jobs.
func _people_goal() -> int:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		var total: int = sim.Contract.population_total(sim)
		for place: Dictionary in sim.state.settlements:
			total += maxi(0, int(place.jobs) - int(place.employed))
		return total
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		if goal.key == "population":
			return mini(population_goal, int(goal.target))
	return 0


## Recruiting pays back within weeks once there is work waiting or a people goal to meet.
func _recruit(region: int, wanted: int, reserve: float) -> bool:
	if recruit_batch <= 0:
		return false
	var counts: Dictionary = _adult_counts()
	var kind: String = "worker"
	if (
		float(counts.scientists) / maxi(1, int(counts.adults)) < science_target
		and sim._has(SCIENCE_TECH)
		and has_building(home, "lab")
	):
		kind = "scientist"
		region = home
	var place: Dictionary = sim.settlement(region)
	var batch: int = mini(mini(recruit_batch, wanted), sim.Population.free_beds(sim, place))
	if batch < 1:
		return false
	var cost: float = sim.Population.campaign_price(sim, kind) * batch
	if float(sim.state.cash) < cost + reserve + recruit_buffer:
		return false
	return act("recruit", {"region": region, "kind": kind, "count": batch}) == ""


func _adult_counts() -> Dictionary:
	var adults: int = 0
	var scientists: int = 0
	for place: Dictionary in sim.state.settlements:
		adults += int(place.workers) + int(place.scientists)
		scientists += int(place.scientists)
	return {"adults": adults, "scientists": scientists}


func _goal_projects(reserve: float) -> void:
	var needs_processing: bool = false
	for goal: Dictionary in sim.Contract.stage_goals(sim, mini(int(sim.state.contract.stage), 3)):
		if goal.key == "processing_days" and not goal.ok:
			needs_processing = true
	if needs_processing and not has_building(home, "processor"):
		if sim.free_workers(sim.settlement(home)) >= int(sim.config.buildings.processor.jobs):
			if _affordable(home, "processor", reserve * 0.5):
				act("build", {"region": home, "kind": "processor"})
		else:
			_recruit(home, int(sim.config.buildings.processor.jobs), reserve * 0.5)


## Workers without a job in other towns on the network: a vacancy here will draw them.
func _idle_elsewhere(region: int) -> int:
	var idle: int = 0
	for place: Dictionary in _places():
		if int(place.region) != region:
			idle += sim.free_workers(place)
	return idle


func _environment() -> void:
	for place: Dictionary in _places():
		if float(place.get("pollution", 0.0)) > POLLUTION_LIMIT:
			act("company", {"operation": "cleanup", "region": int(place.region)})


## A port near capacity turns away the most valuable exports last; add one before it costs money.
func _ports(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		var capacity: float = float(place.port_capacity)
		if capacity <= 0.0 or _building_underway(region, "port"):
			continue
		if (
			float(place.port_used) / capacity > PORT_BUSY_SHARE
			and _affordable(region, "port", reserve)
		):
			act("build", {"region": region, "kind": "port"})


## Food works turn farm surplus into export income that does not run out.
func _food_works(reserve: float) -> void:
	if not sim._has("adaptation"):
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
	_goal_projects(reserve)
	_ports(reserve)
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
	if lowest < 1.0 and wage < WAGE_LIMIT:
		act("policy", {"wage": wage + WAGE_STEP})
		last_wage_change = today()
	elif lowest > 1.4 and lowest < 2.0 and wage > 1.0:
		act("policy", {"wage": wage - WAGE_STEP})
		last_wage_change = today()


## Components need crystal and parts on hand: only where both are already produced.
func _plant_wanted(region: int) -> bool:
	if not has_building(region, "mine_crystal") or not has_building(region, "processor"):
		return false
	return (
		building_count(region, "component_plant")
		< 1 + sim.Contract.population_total(sim) / PLANTS_PER_PEOPLE
	)


## A clinic pays for itself in people staying and arriving.
func _clinic(reserve: float) -> void:
	for place: Dictionary in _places():
		var region: int = int(place.region)
		if has_building(region, "clinic") or int(place.population) < 40:
			continue
		if sim.free_workers(place) < int(sim.config.buildings.clinic.jobs):
			continue
		if _affordable(region, "clinic", reserve):
			act("build", {"region": region, "kind": "clinic"})
			return


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


## Once the contract is met, the great works are where surplus money goes.
func _megaprojects(reserve: float) -> void:
	if sim.state.status != "success":
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
