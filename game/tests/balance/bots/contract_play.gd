extends RefCounted
## How the colony bots play the contract (1.11): where they land under a contract type, and how they
## answer the annual report. Kept apart from colony_bot.gd, which holds the colony's own play.


## Lands on the start that looks richest from orbit, among those with a farming partner in reach;
## under a coastal-only contract (群岛开发), among the coastal sites of those pairs, else on the
## richest coastal site the contract accepts. Two mines are ordered at once.
static func land(bot: RefCounted) -> void:
	var sim: RefCounted = bot.sim
	var best: float = -1.0
	var coastal: bool = sim.Origins.coastal_first(sim)
	for pair: Array in sim.geo.get("playability", {}).get("pairs", [[0, 1]]):
		for site: int in [int(pair[0]), int(pair[1])] if coastal else [int(pair[0])]:
			if coastal and sim.settle_refusal(site) != "":
				continue
			var score: float = sim.Sites.start_score(sim, site)
			if score > best:
				best = score
				bot.home = site
	if coastal and best < 0.0:
		for reg: Dictionary in sim.state.world.regions:
			if sim.settle_refusal(int(reg.id)) != "":
				continue
			var score: float = sim.Sites.start_score(sim, int(reg.id))
			if score > best:
				best = score
				bot.home = int(reg.id)
	bot.act("settle", {"site": bot.home})
	bot.act("build", {"site": bot.home, "kind": "mine_ore"})
	bot.act("build", {"site": bot.home, "kind": "mine_copper"})


## Signs a waiting annual report by the bot's policy; under a mining pledge, keeps the year's ore
## tribute in the capital from `tribute_lead_days` before the ship, and lets it go after.
static func annual_report(bot: RefCounted) -> void:
	var sim: RefCounted = bot.sim
	var annual: Dictionary = sim.state.get("annual", {})
	if annual.is_empty():
		return
	if not annual.pending.is_empty():
		var choices: Dictionary = {}
		for line: String in sim.AnnualReport.LINES:
			choices[line] = bot.report_policy
		bot.act("annual_report", choices)
	if not sim.AnnualReport.pledged(sim):
		return
	var capital: Dictionary = sim.state.settlements[0]
	var days: int = sim.AnnualReport.days_to_ship(sim)
	var keep: float = float(sim.progression.production.default_targets.get("ore", 120.0))
	if days >= 0 and days <= int(bot.tribute_lead_days):
		keep = maxf(keep, float(annual.targets.get("mining", 0.0)) * 1.05)
	keep = minf(keep, float(sim.progression.production.get("max_stock_target", 10000.0)))
	if not is_equal_approx(float(sim.Production.target(sim, capital, "ore")), keep):
		bot.act("stock_target", {"region": int(capital.region), "resource": "ore", "target": keep})
