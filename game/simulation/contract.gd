extends RefCounted
## Contract goals and their daily check.

const Keys = preload("res://simulation/keys.gd")
const WorldGen = preload("res://world/world_gen.gd")


static func progress(sim: RefCounted) -> Dictionary:
	var p: Dictionary = {
		"connected":
		(
			sim.state.settlements.size() >= 2
			and not sim.state.route.is_empty()
			and not WorldGen.road_blocked(sim.state.route, int(sim.state.day))
		),
		"food": true,
		"housing": true,
		"employment": true,
		"industry": false,
		"enterprise":
		(
			not sim.state.enterprise.is_empty()
			and sim.state.enterprise.get("status", "") == Keys.E_OPEN
		),
		"solvent": sim.state.debt < 0.001,
		"streak": int(sim.state.streak),
		"required_streak": int(sim.config.contract.streak_days)
	}
	for s in sim.state.settlements:
		if s.arrival > 0 or s.food_days < float(sim.config.contract.food_days):
			p.food = false
		if s.housing < s.population:
			p.housing = false
		if (
			float(s.employed) / maxf(1.0, float(s.workers) + float(s.scientists))
			< float(sim.config.contract.min_employment)
		):
			p.employment = false
		for b in s.buildings:
			if b.kind in ["farm", "processor", "foodworks"] and b.active:
				p.industry = true
	return p


static func daily(sim: RefCounted) -> void:
	if sim.state.operating_net >= -0.000001 and sim.state.debt < 0.001:
		sim.state.streak += 1
	else:
		sim.state.streak = 0
	sim.state.grace_days = int(sim.state.grace_days) + 1 if sim.state.debt > 0.001 else 0
	if sim.state.status == "success":
		return
	var p: Dictionary = progress(sim)
	if (
		p.connected
		and p.food
		and p.housing
		and p.employment
		and p.industry
		and p.enterprise
		and p.solvent
		and sim.state.streak >= int(sim.config.contract.streak_days)
	):
		sim.state.status = "success"
		sim.state.success_day = sim.state.day
		sim._log("合同履约完成：总督资格生效。明日起按公共账户正经营结余的 15% 缴纳公司分成；可继续经营。")
