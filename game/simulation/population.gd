extends RefCounted
## Feeding, housing, migration, births and training.

const Keys = preload("res://simulation/keys.gd")


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


static func daily(sim: RefCounted) -> void:
	for s in sim.state.settlements:
		if s.arrival > 0:
			continue
		refresh(sim, s)
		if (
			int(sim.state.day) % int(sim.config.economy.immigration_period) == 0
			and s.housing >= s.population + 2
			and s.food_days >= 7.0
			and s.jobs >= s.employed + 2
		):
			s.workers += 2
			s.population += 2
			sim.state.immigrants_total += 2
			sim._transfer("external", "residents", 120.0, "savings.immigrants", false)
			sim._log(s.name + "新增 2 名工人移民，自带积蓄 120。")
		if (
			int(sim.state.day) % int(sim.config.economy.birth_period) == 0
			and s.housing > s.population
			and s.starvation == 0
		):
			s.children += 1
			s.population += 1
			sim.state.births_total += 1
			s.cohorts.append(
				{"count": 1, "mature_day": int(sim.state.day) + int(sim.config.economy.mature_days)}
			)
		var keep: Array = []
		for cohort in s.cohorts:
			if int(cohort.mature_day) <= int(sim.state.day):
				s.children -= int(cohort.count)
				s.workers += int(cohort.count)
			else:
				keep.append(cohort)
		s.cohorts = keep
		var period: int = 15 if sim._has("education") else 30
		var training_capacity: int = 0
		for facility in s.buildings:
			if facility.kind == "lab" and facility.enabled and facility.remaining <= 0:
				training_capacity += int(sim.progression.research.seats_per_lab)
		if int(sim.state.day) % period == 0 and s.workers > 8 and s.scientists < training_capacity:
			for b in s.buildings:
				if b.kind == "lab" and b.active:
					s.workers -= 1
					s.scientists += 1
					reconcile_jobs(sim, s)
					sim._log(s.name + "教学研究所完成 1 名工人的科研职业培训。")
					break


static func refresh(sim: RefCounted, s: Dictionary) -> void:
	s.housing = int(s.base_housing)
	for b in s.buildings:
		if b.kind == "habitat" and b.remaining <= 0 and b.get("enabled", true):
			s.housing += int(sim.config.buildings.habitat.housing)
	s.food_days = (
		float(s.stock.food) / maxf(0.001, float(s.population) * sim.config.economy.food_per_person)
	)
	if s.housing < s.population:
		sim._short(s, Keys.SH_HOUSING)


static func reconcile_jobs(sim: RefCounted, s: Dictionary) -> void:
	# Rebalance snapshot assignments after migration/training without producing or billing twice.
	var available: int = int(s.workers)
	var building_specialists: int = 0
	for building in s.buildings:
		building_specialists += int(building.get("specialists", 0))
	var research_employed: int = mini(
		int(s.scientists), maxi(0, int(s.employed_scientists) - building_specialists)
	)
	var specialists: int = int(s.scientists) - research_employed
	s.employed_workers = 0
	s.employed_scientists = research_employed
	for b in s.buildings:
		b.employed = mini(int(b.get("employed", 0)), available)
		b.specialists = mini(int(b.get("specialists", 0)), specialists)
		available -= int(b.employed)
		specialists -= int(b.specialists)
		s.employed_workers += int(b.employed)
		s.employed_scientists += int(b.specialists)
		if b.kind == "service" and not sim.state.enterprise.is_empty():
			sim.state.enterprise.employees = b.employed
	s.employed = int(s.employed_workers) + int(s.employed_scientists)
