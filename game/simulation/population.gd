extends RefCounted
## Feeding, housing, attractiveness, immigration, recruitment, births and training.
## Numbers are in data/v17/population.json.

const Keys = preload("res://simulation/keys.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const Research = preload("res://simulation/research.gd")


static func ensure_state(state: Dictionary) -> void:
	if not state.has("recruits"):
		state.recruits = []
	if not state.has("recruit_campaigns"):
		state.recruit_campaigns = []
	if not state.policy.has("wage"):
		state.policy.wage = 1.0
	for s: Dictionary in state.settlements:
		if not s.has("arrival_accrual"):
			s.arrival_accrual = 0.0
			s.science_accrual = 0.0
			s.birth_accrual = 0.0
			s.attractiveness = 1.0
			s.attractiveness_parts = {}


static func feed(sim: RefCounted, s: Dictionary) -> void:
	var need: float = float(s.population) * float(sim.config.economy.food_per_person)
	var amount: float = minf(need, float(s.stock.food))
	sim._consume(s, "food", amount)
	s.food_consumed = amount
	var paid: float = minf(float(sim.state.resident_cash), amount * float(sim.config.prices.food))
	sim._transfer("residents", "public", paid, "food.sales", true)
	if amount + 0.00001 < need:
		s.starvation += 1
		sim._short(s, Keys.SH_STARVING, str(s.starvation))
	else:
		s.starvation = 0


static func wage_multiplier(sim: RefCounted) -> float:
	return float(sim.state.policy.get("wage", 1.0))


static func worker_wage(sim: RefCounted) -> float:
	return float(sim.config.economy.wage) * wage_multiplier(sim)


static func scientist_wage(sim: RefCounted) -> float:
	return float(sim.config.economy.scientist_wage) * wage_multiplier(sim)


## Attractiveness 0-2 with its breakdown, from conditions the player can see and change.
static func attractiveness(sim: RefCounted, s: Dictionary) -> Dictionary:
	var rules: Dictionary = sim.pop_rules.attractiveness
	var parts: Dictionary = {}
	var free: int = int(s.housing) - int(s.population)
	if free < 0:
		parts.beds = float(rules.beds_over)
	elif free == 0:
		parts.beds = float(rules.beds_none)
	elif float(free) / maxi(1, int(s.housing)) >= float(rules.beds_roomy_share):
		parts.beds = float(rules.beds_roomy)
	var food_days: float = float(s.food_days)
	if food_days < float(rules.food_critical_days):
		parts.food = float(rules.food_critical)
	elif food_days < float(rules.food_low_days):
		parts.food = float(rules.food_low)
	elif food_days >= float(rules.food_good_days):
		parts.food = float(rules.food_good)
	var adults: int = maxi(1, int(s.workers) + int(s.scientists))
	var unemployed: int = maxi(0, adults - int(s.employed))
	var vacancies: int = maxi(0, int(s.jobs) - int(s.employed))
	if float(unemployed) / adults >= float(rules.jobless_share):
		parts.jobs = float(rules.jobless)
	elif float(vacancies) / adults >= float(rules.jobs_open_share):
		parts.jobs = float(rules.jobs_open)
	parts.wage = (wage_multiplier(sim) - 1.0) * float(rules.wage_per_multiplier)
	var enterprise: Dictionary = sim.state.enterprise
	if (
		not enterprise.is_empty()
		and int(enterprise.region) == int(s.region)
		and enterprise.status == Keys.E_OPEN
	):
		parts.services = float(rules.service_enterprise)
	if has_clinic(s):
		parts.services = float(parts.get("services", 0.0)) + float(rules.service_clinic)
	var pollution: float = float(s.get("pollution", 0.0))
	if pollution > float(rules.pollution_threshold):
		parts.pollution = (
			(pollution - float(rules.pollution_threshold)) * float(rules.pollution_per_point)
		)
	for shortage: Dictionary in s.shortages:
		if shortage.key in [Keys.SH_POWER, Keys.SH_WATER]:
			parts.shortages = float(rules.shortage)
			break
	if sim.state.get("company", {}).get("stage", "normal") in ["review", "intervention"]:
		parts.company = float(rules.company_review)
	var value: float = float(rules.base)
	for key: String in parts:
		value += float(parts[key])
	return {
		"value": clampf(value, float(rules.min), float(rules.max)),
		"parts": parts,
	}


static func has_clinic(s: Dictionary) -> bool:
	for b: Dictionary in s.buildings:
		if b.kind == "clinic" and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
			return true
	return false


static func labs_at(s: Dictionary) -> int:
	var count: int = 0
	for b: Dictionary in s.buildings:
		if b.kind == "lab" and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
			count += 1
	return count


static func _reserved_beds(sim: RefCounted, region: int) -> int:
	var reserved: int = 0
	for party: Dictionary in sim.state.recruits:
		if int(party.region) == region:
			reserved += int(party.count)
	return reserved


static func free_beds(sim: RefCounted, s: Dictionary) -> int:
	return int(s.housing) - int(s.population) - _reserved_beds(sim, int(s.region))


static func _admit(sim: RefCounted, s: Dictionary, workers: int, scientists: int) -> void:
	var count: int = workers + scientists
	if count <= 0:
		return
	s.workers += workers
	s.scientists += scientists
	s.population += count
	sim.state.immigrants_total += count
	sim._transfer(
		"external",
		"residents",
		float(count) * float(sim.pop_rules.immigration.savings_per_person),
		"savings.immigrants",
		false
	)


static func _immigration(sim: RefCounted, s: Dictionary) -> void:
	var rules: Dictionary = sim.pop_rules.immigration
	var result: Dictionary = attractiveness(sim, s)
	s.attractiveness = result.value
	s.attractiveness_parts = result.parts
	s.arrival_accrual = (
		float(s.arrival_accrual) + float(rules.base_per_month) * float(result.value) / 30.0
	)
	var whole: int = int(floor(float(s.arrival_accrual)))
	var beds: int = free_beds(sim, s)
	var arrivals: int = mini(whole, maxi(0, beds))
	if arrivals > 0:
		s.arrival_accrual = float(s.arrival_accrual) - arrivals
		var share: float = (
			minf(
				float(rules.scientist_share_max), float(rules.scientist_share_per_lab) * labs_at(s)
			)
			+ Megaprojects.scientist_share_bonus(sim)
		)
		s.science_accrual = float(s.science_accrual) + share * arrivals
		var scientists: int = mini(arrivals, int(floor(float(s.science_accrual))))
		s.science_accrual = float(s.science_accrual) - scientists
		_admit(sim, s, arrivals - scientists, scientists)
	# Would-be arrivals do not queue up behind a full town.
	s.arrival_accrual = minf(float(s.arrival_accrual), 1.0)


static func _births(sim: RefCounted, s: Dictionary) -> void:
	var adults: int = int(s.workers) + int(s.scientists)
	var yearly: float = float(sim.pop_rules.births.per_adult_per_year)
	if has_clinic(s):
		yearly *= float(sim.pop_rules.births.clinic_factor)
	s.birth_accrual = float(s.birth_accrual) + adults * yearly / 360.0
	if float(s.birth_accrual) < 1.0:
		return
	if s.housing > s.population and s.starvation == 0:
		s.birth_accrual = float(s.birth_accrual) - 1.0
		s.children += 1
		s.population += 1
		sim.state.births_total += 1
		s.cohorts.append(
			{"count": 1, "mature_day": int(sim.state.day) + int(sim.config.economy.mature_days)}
		)
	else:
		s.birth_accrual = 1.0


static func _mature(sim: RefCounted, s: Dictionary) -> void:
	var keep: Array = []
	for cohort: Dictionary in s.cohorts:
		if int(cohort.mature_day) <= int(sim.state.day):
			s.children -= int(cohort.count)
			s.workers += int(cohort.count)
		else:
			keep.append(cohort)
	s.cohorts = keep


static func _train(sim: RefCounted, s: Dictionary) -> void:
	var period: int = 15 if sim._has("education") else 30
	var training_capacity: int = 0
	for facility: Dictionary in s.buildings:
		if facility.kind == "lab" and facility.enabled and facility.remaining <= 0:
			training_capacity += Research.lab_seats(sim, facility)
	if int(sim.state.day) % period == 0 and s.workers > 8 and s.scientists < training_capacity:
		for b: Dictionary in s.buildings:
			if b.kind == "lab" and b.active:
				s.workers -= 1
				s.scientists += 1
				reconcile_jobs(sim, s)
				sim._log(s.name + "教学研究所完成 1 名工人的科研职业培训。")
				break


static func _recruit_arrivals(sim: RefCounted) -> void:
	var keep: Array = []
	for party: Dictionary in sim.state.recruits:
		if int(party.arrive_day) > int(sim.state.day):
			keep.append(party)
			continue
		var s: Dictionary = sim.settlement(int(party.region))
		if s.is_empty():
			continue
		var scientists: int = int(party.count) if party.kind == "scientist" else 0
		_admit(sim, s, int(party.count) - scientists, scientists)
		sim._log("%s：%d 名招募人员抵达。" % [s.name, int(party.count)])
	sim.state.recruits = keep


static func daily(sim: RefCounted) -> void:
	_recruit_arrivals(sim)
	for s: Dictionary in sim.state.settlements:
		if s.arrival > 0:
			continue
		refresh(sim, s)
		_immigration(sim, s)
		_births(sim, s)
		_mature(sim, s)
		_train(sim, s)


static func campaign_price(sim: RefCounted, kind: String) -> float:
	var rules: Dictionary = sim.pop_rules.recruitment
	var base: float = float(rules.scientist_price if kind == "scientist" else rules.worker_price)
	var window: int = int(rules.window_days)
	var recent: int = 0
	for day: Variant in sim.state.recruit_campaigns:
		if int(day) > int(sim.state.day) - window:
			recent += 1
	return base * (1.0 + float(rules.price_step) * recent)


static func recruit_refusal(sim: RefCounted, region: int, kind: String, count: int) -> String:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty() or int(s.arrival) > 0:
		return "需要已经运转的据点"
	if not kind in ["worker", "scientist"]:
		return "未知招募类型"
	var rules: Dictionary = sim.pop_rules.recruitment
	if kind == "scientist" and not sim._has(str(rules.scientist_tech)):
		return "招募研究员需要技术：" + str(sim.config.techs[rules.scientist_tech].name)
	if count < 1 or count > int(rules.max_per_campaign):
		return "每次招募 1—%d 人" % int(rules.max_per_campaign)
	if free_beds(sim, s) < count:
		return "需要 %d 张空床位，目前可用 %d 张" % [count, maxi(0, free_beds(sim, s))]
	var cost: float = campaign_price(sim, kind) * count
	if float(sim.state.cash) < cost:
		return "招募需要 %.0f 资金" % cost
	return ""


static func recruit(sim: RefCounted, region: int, kind: String, count: int) -> String:
	var refusal: String = recruit_refusal(sim, region, kind, count)
	if refusal != "":
		return refusal
	var rules: Dictionary = sim.pop_rules.recruitment
	sim._transfer("public", "external", campaign_price(sim, kind) * count, "recruit", false, kind)
	sim.state.recruit_campaigns.append(int(sim.state.day))
	var window: int = int(rules.window_days)
	while (
		not sim.state.recruit_campaigns.is_empty()
		and int(sim.state.recruit_campaigns[0]) <= int(sim.state.day) - window
	):
		sim.state.recruit_campaigns.pop_front()
	(
		sim
		. state
		. recruits
		. append(
			{
				"region": region,
				"kind": kind,
				"count": count,
				"arrive_day": int(sim.state.day) + int(rules.travel_days),
			}
		)
	)
	return ""


static func view(sim: RefCounted, region: int) -> Dictionary:
	var s: Dictionary = sim.settlement(region)
	if s.is_empty():
		return {}
	var result: Dictionary = attractiveness(sim, s)
	var rate: float = float(sim.pop_rules.immigration.base_per_month) * float(result.value)
	return {
		"attractiveness": result.value,
		"parts": result.parts,
		"arrivals_per_month": rate,
		"free_beds": free_beds(sim, s),
		"wage": wage_multiplier(sim),
		"worker_price": campaign_price(sim, "worker"),
		"scientist_price": campaign_price(sim, "scientist"),
		"travel_days": int(sim.pop_rules.recruitment.travel_days),
		"in_transit": _reserved_beds(sim, region),
	}


static func habitat_beds(sim: RefCounted, b: Dictionary) -> int:
	var rule: Dictionary = sim.config.upgrades.habitat[0]
	if int(b.get("level", 1)) >= int(rule.level):
		return int(rule.housing)
	return int(sim.config.buildings.habitat.housing)


static func refresh(sim: RefCounted, s: Dictionary) -> void:
	s.housing = int(s.base_housing)
	for b: Dictionary in s.buildings:
		if b.kind == "habitat" and b.remaining <= 0 and b.get("enabled", true):
			s.housing += habitat_beds(sim, b)
	s.food_days = (
		float(s.stock.food) / maxf(0.001, float(s.population) * sim.config.economy.food_per_person)
	)
	if s.housing < s.population:
		sim._short(s, Keys.SH_HOUSING)


static func reconcile_jobs(sim: RefCounted, s: Dictionary) -> void:
	# Rebalance snapshot assignments after migration/training without producing or billing twice.
	var available: int = int(s.workers)
	var building_specialists: int = 0
	for building: Dictionary in s.buildings:
		building_specialists += int(building.get("specialists", 0))
	var research_employed: int = mini(
		int(s.scientists), maxi(0, int(s.employed_scientists) - building_specialists)
	)
	var specialists: int = int(s.scientists) - research_employed
	s.employed_workers = 0
	s.employed_scientists = research_employed
	for b: Dictionary in s.buildings:
		b.employed = mini(int(b.get("employed", 0)), available)
		b.specialists = mini(int(b.get("specialists", 0)), specialists)
		available -= int(b.employed)
		specialists -= int(b.specialists)
		s.employed_workers += int(b.employed)
		s.employed_scientists += int(b.specialists)
		if b.kind == "service" and not sim.state.enterprise.is_empty():
			sim.state.enterprise.employees = b.employed
	s.employed = int(s.employed_workers) + int(s.employed_scientists)
