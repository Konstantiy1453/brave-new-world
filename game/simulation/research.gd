extends RefCounted
## Limited scientists, each investigating, on one funded project, or on a paid contract.
## R(n) = R10 * (n / 10)^a with a = ln 0.6 / ln 0.5, so R(5) / R(10) = 0.6 and R(0) = 0.
## Numbers: `research` in progression.json, `techs` in economy.json.

const Megaprojects = preload("res://simulation/megaprojects.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const PREVIEW_STAFF: Array[int] = [5, 10, 20]


static func ensure_state(state: Dictionary) -> void:
	if not state.research.has("contract"):
		state.research.contract = {"staff": 0, "effective": 0, "earned": 0.0}


static func ensure(sim: RefCounted) -> void:
	ensure_state(sim.state)
	var r: Dictionary = sim.state.research
	if not r.has("projects"):
		r.projects = {}
		if r.current != "" and sim.config.techs.has(r.current):
			r.projects[r.current] = {
				"staff": 4,
				"work": float(r.progress),
				"effective": 0,
				"rate": 0.0,
				"reason": "旧档研究量已迁移"
			}
	if not r.has("investigations"):
		r.investigations = {}


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
		Megaprojects.research_factor(sim) * EventsV2.colony_modifier(sim, "research")
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
		return "可用研究人员不足；调查与项目共享人员"
	if staff == 0:
		sim.state.research.investigations.erase(id)
	else:
		sim.state.research.investigations[id] = {"staff": staff}
	rebalance(sim, false)
	return ""


static func release_investigation(sim: RefCounted, id: String) -> void:
	sim.state.research.investigations.erase(id)
	rebalance(sim, false)


static func allocate(sim: RefCounted, tech: String, staff: int) -> String:
	ensure(sim)
	if not sim.config.techs.has(tech):
		return "无此研究项目"
	if sim.state.research.completed.has(tech):
		return "此技术已经完成"
	if staff < 0:
		return "分配人数不能为负数"
	for req: String in sim.config.techs[tech].requires:
		if not sim.state.research.completed.has(req):
			return "需要前置技术：" + sim.config.techs[req].name
	var reserved: int = investigating(sim) + int(sim.state.research.contract.staff)
	for key: String in sim.state.research.projects:
		if key != tech:
			reserved += int(sim.state.research.projects[key].staff)
	if reserved + staff > total(sim):
		return "科研人员不足；请先减少其他项目或调查投入"
	if staff > 0 and staff < int(sim.config.techs[tech].get("minimum_staff", 3)):
		return "项目至少需要 3 人；0 人暂停并保留研究量"
	if not sim.state.research.projects.has(tech):
		sim.state.research.projects[tech] = {
			"staff": 0, "work": 0.0, "effective": 0, "rate": 0.0, "reason": ""
		}
	sim.state.research.projects[tech].staff = staff
	rebalance(sim, false)
	return ""


## Paid external research: it uses scientists a project could have had.
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
		return "科研人员不足；请先减少其他项目或调查投入"
	r.contract.staff = staff
	rebalance(sim, false)
	return ""


static func lab_seats(sim: RefCounted, b: Dictionary) -> int:
	if int(b.get("level", 1)) >= 2:
		return int(sim.config.upgrades.lab[0].seats)
	return int(sim.progression.research.seats_per_lab)


static func lab_projects(sim: RefCounted, b: Dictionary) -> int:
	if int(b.get("level", 1)) >= 2:
		return int(sim.config.upgrades.lab[0].projects)
	return int(sim.progression.research.projects_per_lab)


static func rebalance(sim: RefCounted, advance: bool) -> void:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var cfg: Dictionary = sim.progression.research
	var max_projects: int = 0
	var local_capacity: Dictionary = {}
	for s: Dictionary in sim.state.settlements:
		var local_seats: int = 0
		for b: Dictionary in s.buildings:
			if b.kind == "lab" and b.enabled and b.remaining <= 0 and (b.active or not advance):
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
	for key: String in r.projects:
		var p: Dictionary = r.projects[key]
		p.effective = 0
		p.rate = 0.0
		p.reason = "已完成" if r.completed.has(key) else "已暂停"
		if int(p.staff) <= 0 or r.completed.has(key):
			continue
		var n: int = mini(int(p.staff), usable)
		if project_count >= max_projects:
			p.reason = "实验台已满或研究所未运作：检查维护工人、水电与停用状态"
			continue
		if n < int(sim.config.techs[key].get("minimum_staff", 3)):
			p.reason = "可用人员或当地科研席位不足；调查优先"
			continue
		var funding: float = float(sim.config.techs[key].funding) * rate(n) * _funding_factor(sim)
		if sim.state.cash < funding:
			p.reason = "科研经费不足；保留研究量"
			continue
		p.effective = n
		p.rate = rate(n, reference) * _speed_factor(sim)
		p.reason = "研究中（实验所技术工优先于公共生产）" if n == int(p.staff) else "人员不足，按登记顺序缩编"
		usable -= n
		research_used += n
		project_count += 1
		if advance:
			sim._public_expense(funding, "research.funding", "external", key)
			p.work = minf(float(sim.config.techs[key].cost), float(p.work) + float(p.rate))
			if p.work >= float(sim.config.techs[key].cost):
				r.completed.append(key)
				p.staff = 0
				p.effective = 0
				p.rate = 0.0
				sim._log("科研完成：" + sim.config.techs[key].name)
				sim.Sites.on_technology(sim, key)
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
	if float(project.work) >= cost and not r.completed.has(best):
		r.completed.append(best)
		project.staff = 0
		project.effective = 0
		project.rate = 0.0
		sim._log("科研完成：" + sim.config.techs[best].name)
		sim.Sites.on_technology(sim, best)


static func view(sim: RefCounted) -> Dictionary:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var rows: Array = []
	var allocated: int = int(r.contract.staff)
	var capacity: int = 0
	var benches: int = 0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if b.kind == "lab" and b.enabled and b.remaining <= 0:
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


## Every technology with its state and staffing previews, for the tech tree.
static func tree(sim: RefCounted) -> Array:
	ensure(sim)
	var rows: Array = []
	var r: Dictionary = sim.state.research
	for key: String in sim.config.techs:
		var t: Dictionary = sim.config.techs[key]
		var missing: Array = []
		for req: String in t.requires:
			if not r.completed.has(req):
				missing.append(sim.config.techs[req].name)
		var previews: Array = []
		for staff: int in PREVIEW_STAFF:
			previews.append({"staff": staff, "days": days_to_finish(sim, key, staff)})
		var project: Dictionary = r.projects.get(key, {})
		(
			rows
			. append(
				{
					"id": key,
					"name": t.name,
					"branch": t.branch,
					"tier": int(t.tier),
					"cost": float(t.cost),
					"description": t.description,
					"done": r.completed.has(key),
					"missing": missing,
					"work": float(project.get("work", 0.0)),
					"staff": int(project.get("staff", 0)),
					"effective": int(project.get("effective", 0)),
					"rate": float(project.get("rate", 0.0)),
					"reason": str(project.get("reason", "")),
					"previews": previews,
				}
			)
		)
	return rows


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
