extends RefCounted


## Each scientist is either investigating or assigned once to a funded project.
static func ensure(sim) -> void:
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


## R(n) = R10 * (n / 10)^a with a = ln 0.6 / ln 0.5, so R(5) / R(10) = 0.6 and R(0) = 0.
static func rate(staff: float, reference: float = 1.0) -> float:
	return 0.0 if staff <= 0 else reference * pow(staff / 10.0, log(0.6) / log(0.5))


static func total(sim) -> int:
	var n: int = 0
	for s in sim.state.settlements:
		n += int(s.scientists)
	return n


static func investigating(sim) -> int:
	var n: int = 0
	for reservation in sim.state.research.investigations.values():
		n += int(reservation.staff)
	return n


static func reserve_investigation(sim, id: String, staff: int) -> String:
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


static func release_investigation(sim, id: String) -> void:
	sim.state.research.investigations.erase(id)
	rebalance(sim, false)


static func allocate(sim, tech: String, staff: int) -> String:
	ensure(sim)
	if not sim.config.techs.has(tech):
		return "无此研究项目"
	if sim.state.research.completed.has(tech):
		return "此技术已经完成"
	if staff < 0:
		return "分配人数不能为负数"
	for req in sim.config.techs[tech].requires:
		if not sim.state.research.completed.has(req):
			return "需要前置技术：" + sim.config.techs[req].name
	var reserved: int = investigating(sim)
	for key in sim.state.research.projects:
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


static func rebalance(sim, advance: bool) -> void:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var cfg: Dictionary = sim.progression.research
	var seats: int = 0
	var labs: int = 0
	var eligible: int = 0
	var local_capacity: Dictionary = {}
	for s in sim.state.settlements:
		var local_seats: int = 0
		for b in s.buildings:
			if b.kind == "lab" and b.enabled and b.remaining <= 0 and (b.active or not advance):
				local_seats += int(cfg.seats_per_lab)
				labs += 1
		seats += local_seats
		eligible += mini(local_seats, int(s.scientists))
		local_capacity[int(s.region)] = mini(local_seats, int(s.scientists))
	var left: int = total(sim)
	var used_investigation: int = 0
	# Stable insertion order is the priority: earlier investigations, then projects.
	for reservation in r.investigations.values():
		reservation.staff = mini(int(reservation.staff), left)
		left -= int(reservation.staff)
		used_investigation += int(reservation.staff)
	var requested_left: int = left
	for p in r.projects.values():
		p.staff = mini(int(p.staff), requested_left)
		requested_left -= int(p.staff)
	var field_by_region: Dictionary = {}
	var field_left: int = used_investigation
	# Put field staff in colonies without laboratory seats first.
	for s in sim.state.settlements:
		var spare: int = maxi(0, int(s.scientists) - int(local_capacity[int(s.region)]))
		field_by_region[int(s.region)] = mini(field_left, spare)
		field_left -= int(field_by_region[int(s.region)])
	for s in sim.state.settlements:
		var n: int = mini(field_left, int(local_capacity[int(s.region)]))
		field_by_region[int(s.region)] += n
		local_capacity[int(s.region)] -= n
		field_left -= n
	var usable: int = 0
	for seats_here in local_capacity.values():
		usable += int(seats_here)
	var max_projects: int = labs * int(cfg.projects_per_lab)
	var project_count: int = 0
	var research_used: int = 0
	for key in r.projects:
		var p: Dictionary = r.projects[key]
		p.effective = 0
		p.rate = 0.0
		p.reason = "已完成" if r.completed.has(key) else "已暂停"
		if int(p.staff) <= 0 or r.completed.has(key):
			continue
		var n: int = mini(int(p.staff), usable)
		if project_count >= max_projects:
			p.reason = "实验所未运作：检查维护工人、水电与停用状态；分配项目时优先保障实验所技术工"
			continue
		if n < int(sim.config.techs[key].get("minimum_staff", 3)):
			p.reason = "可用人员或当地科研席位不足；调查优先"
			continue
		var funding: float = (
			float(sim.config.techs[key].funding)
			* rate(n)
			* (0.5 if sim.state.advantage == "science" else 1.0)
		)
		if sim.state.cash < funding:
			p.reason = "科研经费不足；保留研究量"
			continue
		p.effective = n
		p.rate = (
			rate(n, float(cfg.reference_rate)) * (1.35 if sim.state.advantage == "science" else 1.0)
		)
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
	if advance:
		var employ: int = research_used
		for s in sim.state.settlements:
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
	for key in r.projects:
		if int(r.projects[key].staff) > 0 and not r.completed.has(key):
			r.current = key
			r.progress = float(r.projects[key].work)
			break


static func tick(sim) -> void:
	rebalance(sim, true)


static func view(sim) -> Dictionary:
	ensure(sim)
	var r: Dictionary = sim.state.research
	var rows: Array = []
	var allocated: int = 0
	var capacity: int = 0
	for s in sim.state.settlements:
		for b in s.buildings:
			if b.kind == "lab" and b.enabled and b.remaining <= 0:
				capacity += int(sim.progression.research.seats_per_lab)
	for key in r.projects:
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
		"projects": rows
	}


static func validate(sim, candidate: Dictionary) -> String:
	var r: Dictionary = candidate.research
	var err: String = sim._save_shape(r, {"projects": {}, "investigations": {}}, "research")
	if err != "":
		return err
	var total_staff: int = 0
	var allocated: int = 0
	for settlement in candidate.settlements:
		total_staff += int(settlement.scientists)
	for key in r.projects:
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
			or p.work > float(sim.config.techs[key].cost)
		):
			return "科研分配或工作量无效"
	for reservation in r.investigations.values():
		err = sim._save_shape(reservation, {"staff": 0}, "research.investigations")
		if err != "":
			return err
		if reservation.staff < 0 or float(reservation.staff) != float(int(reservation.staff)):
			return "调查人数无效"
		allocated += int(reservation.staff)
	if allocated > total_staff:
		return "科研与调查总人数超过真实人员"
	return ""
