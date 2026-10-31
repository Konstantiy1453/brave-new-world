extends RefCounted
## Research teams work one category at a time. Each category offers a few cards drawn at random
## from what its prerequisites allow; finishing one redraws that category. The pool is not shown as
## a tree. R(n) = R10 * (n / 10)^a with a = ln 0.6 / ln 0.5, so R(5) / R(10) = 0.6 and R(0) = 0.
## Numbers: `research` in progression.json, technologies in techs.json.

const Megaprojects = preload("res://simulation/megaprojects.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Rules = preload("res://simulation/rules.gd")
const PREVIEW_STAFF: Array[int] = [5, 10, 20]
const MAX_RNG: int = 2147483647


static func ensure_state(state: Dictionary) -> void:
	var r: Dictionary = state.research
	if not r.has("contract"):
		r.contract = {"staff": 0, "effective": 0, "earned": 0.0}
	if not r.has("projects"):
		r.projects = {}
		var old: String = str(r.get("current", ""))
		if old != "" and Rules.read("techs").techs.has(old):
			r.projects[old] = {
				"staff": 4,
				"work": float(r.get("progress", 0.0)),
				"effective": 0,
				"rate": 0.0,
				"reason": "旧档研究量已迁移"
			}
	if not r.has("investigations"):
		r.investigations = {}
	if not r.has("offers"):
		r.offers = {}
		r.rng_state = (absi(int(state.world.seed)) * 7 % (MAX_RNG - 1)) + 1
		for category: String in Rules.read("techs").categories:
			_draw(r, category, [])


static func ensure(sim: RefCounted) -> void:
	ensure_state(sim.state)


## What finished technologies add up to for one effect, as a fraction. 0 when nothing touches it.
static func bonus(sim: RefCounted, key: String) -> float:
	var done: Array = sim.state.research.completed
	if int(sim.tech_effects_count) != done.size():
		var totals: Dictionary = {}
		for tech: String in done:
			var effects: Dictionary = sim.config.techs.get(tech, {}).get("effects", {})
			for name: String in effects:
				totals[name] = float(totals.get(name, 0.0)) + float(effects[name])
		sim.tech_effects = totals
		sim.tech_effects_count = done.size()
	return float(sim.tech_effects.get(key, 0.0))


static func _roll(r: Dictionary) -> float:
	r.rng_state = (int(r.rng_state) * 48271) % MAX_RNG
	return float(r.rng_state) / float(MAX_RNG)


static func _offer_size(r: Dictionary) -> int:
	var rules: Dictionary = Rules.read("techs")
	var size: int = int(rules.offers)
	for tech: String in r.completed:
		size += int(rules.techs.get(tech, {}).get("effects", {}).get("offers", 0.0))
	return size


## Technologies the colony could start in this category right now.
static func _eligible(r: Dictionary, category: String, skip: Array) -> Array:
	var techs: Dictionary = Rules.read("techs").techs
	var rows: Array = []
	for key: String in techs:
		var t: Dictionary = techs[key]
		if str(t.category) != category or r.completed.has(key) or skip.has(key):
			continue
		var open: bool = true
		for need: String in t.requires:
			open = open and r.completed.has(need)
		if open:
			rows.append(key)
	return rows


## Deals a category's hand. Work under way stays on the table; `avoid` are cards just thrown back.
static func _draw(r: Dictionary, category: String, avoid: Array) -> void:
	var rules: Dictionary = Rules.read("techs")
	var hand: Array = []
	for key: String in r.projects:
		if not rules.techs.has(key) or str(rules.techs[key].category) != category:
			continue
		var project: Dictionary = r.projects[key]
		if r.completed.has(key):
			continue
		if float(project.work) > 0.0 or int(project.staff) > 0:
			hand.append(key)
	if not r.offers.has(category):
		for key: String in rules.first_offers.get(category, []):
			if not r.completed.has(key) and not hand.has(key):
				hand.append(key)
	# What the charter cannot be finished without is never left to the luck of the draw.
	for key: String in _eligible(r, category, hand):
		if rules.get("always_dealt", []).has(key):
			hand.append(key)
	var size: int = _offer_size(r)
	while hand.size() < size:
		var pool: Array = _eligible(r, category, hand + avoid)
		if pool.is_empty():
			pool = _eligible(r, category, hand)
		if pool.is_empty():
			break
		var total: float = 0.0
		for key: String in pool:
			total += float(rules.techs[key].weight)
		var pick: float = _roll(r) * total
		var chosen: String = str(pool[pool.size() - 1])
		for key: String in pool:
			pick -= float(rules.techs[key].weight)
			if pick <= 0.0:
				chosen = key
				break
		hand.append(chosen)
	r.offers[category] = hand


## Puts one technology on the table now, if its prerequisites are met: a lead found by an event.
static func add_lead(sim: RefCounted, tech: String) -> bool:
	var t: Dictionary = sim.config.techs.get(tech, {})
	var r: Dictionary = sim.state.research
	if t.is_empty() or r.completed.has(tech):
		return false
	for need: String in t.requires:
		if not r.completed.has(need):
			return false
	var hand: Array = r.offers.get(str(t.category), [])
	if not hand.has(tech):
		hand.append(tech)
	r.offers[str(t.category)] = hand
	return true


static func reshuffle_cost(sim: RefCounted) -> float:
	var rules: Dictionary = Rules.read("techs")
	return float(rules.reshuffle_cost) + float(rules.reshuffle_tier_cost) * _highest_tier(sim)


static func _highest_tier(sim: RefCounted) -> int:
	var top: int = 0
	for tech: String in sim.state.research.completed:
		top = maxi(top, int(sim.config.techs.get(tech, {}).get("tier", 0)))
	return top


## Pays to throw back the cards nobody has started and deal again.
static func reshuffle(sim: RefCounted, category: String) -> String:
	var r: Dictionary = sim.state.research
	if not Rules.read("techs").categories.has(category):
		return "没有这个科研类别"
	var cost: float = reshuffle_cost(sim)
	if float(sim.state.cash) < cost:
		return "重新调研需要 %.0f 资金" % cost
	var old: Array = r.offers.get(category, [])
	sim._transfer("public", "external", cost, "research.reshuffle", false, category)
	_draw(r, category, old)
	return ""


static func rate(staff: float, reference: float = 1.0) -> float:
	return 0.0 if staff <= 0 else reference * pow(staff / 10.0, log(0.6) / log(0.5))


static func total(sim: RefCounted) -> int:
	var n: int = 0
	for s: Dictionary in sim.state.settlements:
		n += int(s.scientists)
	return n


static func investigating(sim: RefCounted) -> int:
	var n: int = 0
	for reservation: Dictionary in sim.state.research.investigations.values():
		n += int(reservation.staff)
	return n


static func _speed_factor(sim: RefCounted) -> float:
	var factor: float = (
		Megaprojects.research_factor(sim)
		* EventsV2.colony_modifier(sim, "research")
		* (1.0 + bonus(sim, "research_speed"))
	)
	if sim.state.advantage == "science":
		factor *= float(sim.progression.research.science_opening_rate)
	return factor


static func _funding_factor(sim: RefCounted) -> float:
	if sim.state.advantage == "science":
		return float(sim.progression.research.science_opening_funding)
	return 1.0


## Days to finish a technology at a staffing level, from the work already done.
static func days_to_finish(sim: RefCounted, tech: String, staff: int) -> int:
	var work: float = float(sim.state.research.projects.get(tech, {}).get("work", 0.0))
	var left: float = maxf(0.0, float(sim.config.techs[tech].cost) - work)
	var speed: float = (
		rate(staff, float(sim.progression.research.reference_rate)) * _speed_factor(sim)
	)
	return ceili(left / speed) if speed > 0.0 else -1


static func reserve_investigation(sim: RefCounted, id: String, staff: int) -> String:
	ensure(sim)
	if staff < 0:
		return "调查人数不能为负数"
	var already: int = int(sim.state.research.investigations.get(id, {}).get("staff", 0))
	if investigating(sim) - already + staff > total(sim):
		return "可用研究团队不足；调查与项目共享人员"
	if staff == 0:
		sim.state.research.investigations.erase(id)
	else:
		sim.state.research.investigations[id] = {"staff": staff}
	rebalance(sim, false)
	return ""


static func release_investigation(sim: RefCounted, id: String) -> void:
	sim.state.research.investigations.erase(id)
	rebalance(sim, false)


## Sets who works on a card. A category runs one project: starting one stands the other down,
## with its work kept on the table.
static func allocate(sim: RefCounted, tech: String, staff: int) -> String:
	ensure(sim)
	var r: Dictionary = sim.state.research
	if not sim.config.techs.has(tech):
		return "无此研究项目"
	if r.completed.has(tech):
		return "此技术已经完成"
	if staff < 0:
		return "分配人数不能为负数"
	var category: String = str(sim.config.techs[tech].category)
	if staff > 0 and not r.offers.get(category, []).has(tech):
		return "这项课题目前不在候选之中"
	for req: String in sim.config.techs[tech].requires:
		if not r.completed.has(req):
			return "需要前置技术：" + sim.config.techs[req].name
	var reserved: int = investigating(sim) + int(r.contract.staff)
	var stood_down: Array = []
	for key: String in r.projects:
		if key == tech:
			continue
		if str(sim.config.techs[key].category) == category and staff > 0:
			stood_down.append(key)
			continue
		reserved += int(r.projects[key].staff)
	if reserved + staff > total(sim):
		return "研究团队不足；请先减少其他项目或调查投入"
	if staff > 0 and staff < int(sim.config.techs[tech].get("minimum_staff", 3)):
		return "项目至少需要 3 支团队；0 支暂停并保留研究量"
	for key: String in stood_down:
		r.projects[key].staff = 0
	if not r.projects.has(tech):
		r.projects[tech] = {"staff": 0, "work": 0.0, "effective": 0, "rate": 0.0, "reason": ""}
	r.projects[tech].staff = staff
	rebalance(sim, false)
	return ""


## Paid external research: it uses research teams a project could have had.
static func set_contract(sim: RefCounted, staff: int) -> String:
	ensure(sim)
	var r: Dictionary = sim.state.research
	if staff < 0:
		return "分配人数不能为负数"
	var tech: String = str(sim.progression.research.contract_tech)
	if not sim._has(tech):
		return "科研委托需要技术：" + str(sim.config.techs[tech].name)
	var reserved: int = investigating(sim)
	for project: Dictionary in r.projects.values():
		reserved += int(project.staff)
	if reserved + staff > total(sim):
		return "研究团队不足；请先减少其他项目或调查投入"
	r.contract.staff = staff
	rebalance(sim, false)
	return ""


static func is_lab(sim: RefCounted, b: Dictionary) -> bool:
	return str(sim.config.buildings.get(b.kind, {}).get("role", "")) == "lab"


static func lab_seats(sim: RefCounted, b: Dictionary) -> int:
	if int(b.get("level", 1)) >= 2:
		return int(sim.config.upgrades.lab[0].seats)
	return int(sim.config.buildings[b.kind].seats)


static func lab_projects(sim: RefCounted, b: Dictionary) -> int:
	if int(b.get("level", 1)) >= 2:
		return int(sim.config.upgrades.lab[0].projects)
	return int(sim.config.buildings[b.kind].benches)


static func _finish(sim: RefCounted, key: String) -> void:
	var r: Dictionary = sim.state.research
	if r.completed.has(key):
		return
	r.completed.append(key)
	var project: Dictionary = r.projects[key]
	project.staff = 0
	project.effective = 0
	project.rate = 0.0
	sim._log("科研完成：" + sim.config.techs[key].name)
	sim.Sites.on_technology(sim, key)
	_draw(r, str(sim.config.techs[key].category), [])


static func rebalance(sim: RefCounted, advance: bool) -> void:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var cfg: Dictionary = sim.progression.research
	var max_projects: int = 0
	var local_capacity: Dictionary = {}
	for s: Dictionary in sim.state.settlements:
		var local_seats: int = 0
		for b: Dictionary in s.buildings:
			if is_lab(sim, b) and b.enabled and b.remaining <= 0 and (b.active or not advance):
				local_seats += lab_seats(sim, b)
				max_projects += lab_projects(sim, b)
		local_capacity[int(s.region)] = mini(local_seats, int(s.scientists))
	var left: int = total(sim)
	var used_investigation: int = 0
	# Stable insertion order is the priority: earlier investigations, then projects, then contracts.
	for reservation: Dictionary in r.investigations.values():
		reservation.staff = mini(int(reservation.staff), left)
		left -= int(reservation.staff)
		used_investigation += int(reservation.staff)
	var requested_left: int = left
	for p: Dictionary in r.projects.values():
		p.staff = mini(int(p.staff), requested_left)
		requested_left -= int(p.staff)
	r.contract.staff = mini(int(r.contract.staff), requested_left)
	var field_by_region: Dictionary = {}
	var field_left: int = used_investigation
	# Put field staff in colonies without laboratory seats first.
	for s: Dictionary in sim.state.settlements:
		var spare: int = maxi(0, int(s.scientists) - int(local_capacity[int(s.region)]))
		field_by_region[int(s.region)] = mini(field_left, spare)
		field_left -= int(field_by_region[int(s.region)])
	for s: Dictionary in sim.state.settlements:
		var n: int = mini(field_left, int(local_capacity[int(s.region)]))
		field_by_region[int(s.region)] += n
		local_capacity[int(s.region)] -= n
		field_left -= n
	var usable: int = 0
	for seats_here: Variant in local_capacity.values():
		usable += int(seats_here)
	var project_count: int = 0
	var research_used: int = 0
	var reference: float = float(cfg.reference_rate)
	var finished: Array = []
	for key: String in r.projects:
		var p: Dictionary = r.projects[key]
		p.effective = 0
		p.rate = 0.0
		p.reason = "已完成" if r.completed.has(key) else "已暂停"
		if int(p.staff) <= 0 or r.completed.has(key):
			continue
		var n: int = mini(int(p.staff), usable)
		if project_count >= max_projects:
			p.reason = "实验台已满或研究所未运作：检查维护工程队、水电与停用状态"
			continue
		if n < int(sim.config.techs[key].get("minimum_staff", 3)):
			p.reason = "可用团队或当地科研席位不足；调查优先"
			continue
		var funding: float = float(sim.config.techs[key].funding) * rate(n) * _funding_factor(sim)
		if sim.state.cash < funding:
			p.reason = "科研经费不足；保留研究量"
			continue
		p.effective = n
		p.rate = rate(n, reference) * _speed_factor(sim)
		p.reason = "研究中（实验所技术工优先于公共生产）" if n == int(p.staff) else "团队不足，按登记顺序缩编"
		usable -= n
		research_used += n
		project_count += 1
		if advance:
			sim._public_expense(funding, "research.funding", "external", key)
			p.work = minf(float(sim.config.techs[key].cost), float(p.work) + float(p.rate))
			if p.work >= float(sim.config.techs[key].cost):
				finished.append(key)
	for key: String in finished:
		_finish(sim, key)
	r.contract.effective = 0
	if int(r.contract.staff) > 0 and project_count < max_projects:
		var n: int = mini(int(r.contract.staff), usable)
		if n >= int(cfg.minimum_staff):
			r.contract.effective = n
			usable -= n
			research_used += n
			if advance:
				var income: float = (
					rate(n, reference)
					* Megaprojects.research_factor(sim)
					* float(cfg.contract_point_price)
				)
				sim._transfer("external", "public", income, "research.contract", true)
				r.contract.earned = float(r.contract.earned) + income
	if advance:
		var employ: int = research_used
		for s: Dictionary in sim.state.settlements:
			var researchers_here: int = mini(employ, int(local_capacity[int(s.region)]))
			var n: int = researchers_here + int(field_by_region[int(s.region)])
			s.employed_scientists = n
			s.employed = int(s.employed_workers) + n
			s.jobs += n
			employ -= researchers_here
			sim._public_expense(
				(
					n
					* float(sim.config.economy.scientist_wage)
					* float(sim.state.policy.get("wage", 1.0))
				),
				"research.wages",
				"residents"
			)
	r.current = ""
	r.progress = 0.0
	for key: String in r.projects:
		if int(r.projects[key].staff) > 0 and not r.completed.has(key):
			r.current = key
			r.progress = float(r.projects[key].work)
			break


static func tick(sim: RefCounted) -> void:
	rebalance(sim, true)


## Windfall research goes to the project with the most work already done.
static func add_progress(sim: RefCounted, points: float) -> void:
	var r: Dictionary = sim.state.research
	var best: String = ""
	var most: float = -1.0
	for key: String in r.projects:
		if int(r.projects[key].effective) > 0 and float(r.projects[key].work) > most:
			most = float(r.projects[key].work)
			best = key
	if best == "":
		return
	var project: Dictionary = r.projects[best]
	var cost: float = float(sim.config.techs[best].cost)
	project.work = minf(cost, float(project.work) + points)
	if float(project.work) >= cost:
		_finish(sim, best)


static func view(sim: RefCounted) -> Dictionary:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var rows: Array = []
	var allocated: int = int(r.contract.staff)
	var capacity: int = 0
	var benches: int = 0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if is_lab(sim, b) and b.enabled and b.remaining <= 0:
				capacity += lab_seats(sim, b)
				benches += lab_projects(sim, b)
	for key: String in r.projects:
		var p: Dictionary = r.projects[key]
		allocated += int(p.staff)
		var remaining: float = maxf(0, float(sim.config.techs[key].cost) - float(p.work))
		rows.append(
			{
				"tech": key,
				"name": sim.config.techs[key].name,
				"staff": p.staff,
				"effective": p.effective,
				"work": p.work,
				"rate": p.rate,
				"remaining": remaining,
				"eta": ceili(remaining / float(p.rate)) if float(p.rate) > 0 else -1,
				"reason": p.reason
			}
		)
	return {
		"total": total(sim),
		"allocated": allocated,
		"available": maxi(0, total(sim) - allocated - investigating(sim)),
		"investigating": investigating(sim),
		"capacity": capacity,
		"benches": benches,
		"projects": rows,
		"contract": r.contract,
	}


static func _row(sim: RefCounted, key: String) -> Dictionary:
	var r: Dictionary = sim.state.research
	var t: Dictionary = sim.config.techs[key]
	var missing: Array = []
	for req: String in t.requires:
		if not r.completed.has(req):
			missing.append(sim.config.techs[req].name)
	var previews: Array = []
	for staff: int in PREVIEW_STAFF:
		previews.append({"staff": staff, "days": days_to_finish(sim, key, staff)})
	var project: Dictionary = r.projects.get(key, {})
	return {
		"id": key,
		"name": t.name,
		"category": t.category,
		"branch": t.branch,
		"tier": int(t.tier),
		"charter": Rules.read("techs").get("always_dealt", []).has(key),
		"cost": float(t.cost),
		"funding": float(t.funding),
		"description": t.description,
		"unlocks": _unlocks(sim, key),
		"done": r.completed.has(key),
		"missing": missing,
		"work": float(project.get("work", 0.0)),
		"staff": int(project.get("staff", 0)),
		"effective": int(project.get("effective", 0)),
		"rate": float(project.get("rate", 0.0)),
		"reason": str(project.get("reason", "")),
		"previews": previews,
	}


static func _unlocks(sim: RefCounted, tech: String) -> Array:
	var names: Array = []
	for kind: String in sim.config.buildings:
		if str(sim.config.buildings[kind].get("requires_tech", "")) == tech:
			names.append(str(sim.config.buildings[kind].name))
	return names


## Every technology with its state, whether or not it has been offered.
static func tree(sim: RefCounted) -> Array:
	ensure(sim)
	var rows: Array = []
	for key: String in sim.config.techs:
		rows.append(_row(sim, key))
	return rows


## What the research page shows: per category the running project, the cards and what is finished.
static func cards(sim: RefCounted) -> Array:
	ensure(sim)
	var rules: Dictionary = Rules.read("techs")
	var r: Dictionary = sim.state.research
	var columns: Array = []
	for category: String in rules.categories:
		var offers: Array = []
		var running: Dictionary = {}
		for key: String in r.offers.get(category, []):
			var row: Dictionary = _row(sim, key)
			offers.append(row)
			if int(row.staff) > 0:
				running = row
		var finished: Array = []
		var pool: int = 0
		for key: String in sim.config.techs:
			if str(sim.config.techs[key].category) != category:
				continue
			pool += 1
			if r.completed.has(key):
				finished.append(str(sim.config.techs[key].name))
		(
			columns
			. append(
				{
					"id": category,
					"name": str(rules.categories[category].name),
					"description": str(rules.categories[category].description),
					"offers": offers,
					"running": running,
					"finished": finished,
					"pool": pool,
				}
			)
		)
	return columns


## Categories whose team has nothing to do while the colony could run a project.
static func idle_categories(sim: RefCounted) -> Array:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var idle: Array = []
	var staffed: Dictionary = {}
	for key: String in r.projects:
		if int(r.projects[key].staff) > 0:
			staffed[str(sim.config.techs[key].category)] = true
	var benches: int = int(view(sim).benches)
	if staffed.size() >= benches:
		return idle
	for category: String in Rules.read("techs").categories:
		if not staffed.has(category) and not r.offers.get(category, []).is_empty():
			idle.append(category)
	return idle


## `costs` overrides technology costs, for saves written under older ones.
static func validate(sim: RefCounted, candidate: Dictionary, costs: Dictionary = {}) -> String:
	var r: Dictionary = candidate.research
	var err: String = sim._save_shape(r, {"projects": {}, "investigations": {}}, "research")
	if err != "":
		return err
	var total_staff: int = 0
	var allocated: int = int(r.get("contract", {}).get("staff", 0))
	for settlement: Dictionary in candidate.settlements:
		total_staff += int(settlement.scientists)
	for hand: Variant in r.get("offers", {}).values():
		if not hand is Array:
			return "科研候选无效"
		for key: Variant in hand:
			if not sim.config.techs.has(key):
				return "未知科研项目"
	for key: Variant in r.projects:
		if not sim.config.techs.has(key):
			return "未知科研项目"
		err = sim._save_shape(
			r.projects[key],
			{"staff": 0, "work": 0, "effective": 0, "rate": 0, "reason": ""},
			"research.projects"
		)
		if err != "":
			return err
		var p: Dictionary = r.projects[key]
		if float(p.staff) != float(int(p.staff)) or float(p.effective) != float(int(p.effective)):
			return "科研人数必须为整数"
		allocated += int(p.staff)
		if p.effective > p.staff:
			return "科研实际投入超过分配"
		if (
			p.staff < 0
			or p.work < 0
			or p.effective < 0
			or p.rate < 0
			or p.work > float(costs.get(key, sim.config.techs[key].cost))
		):
			return "科研分配或工作量无效"
	for reservation: Variant in r.investigations.values():
		err = sim._save_shape(reservation, {"staff": 0}, "research.investigations")
		if err != "":
			return err
		if reservation.staff < 0 or float(reservation.staff) != float(int(reservation.staff)):
			return "调查人数无效"
		allocated += int(reservation.staff)
	if allocated > total_staff:
		return "科研与调查总人数超过真实人员"
	return ""
