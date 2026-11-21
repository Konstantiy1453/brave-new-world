extends RefCounted
## The contract's outlook (1.11): for each goal of the current stage, whether it will be met under
## the colony's current arrangements or needs the player, how it has moved lately, when it should be
## met where that can be supported, what holds it back, and the action that helps with its cost and
## likely effect. Population tells housing from jobs; technologies list the projects that count, when
## each should finish, and what commissioning them would change. The stage's own date follows from
## its goals. Read-only: `record` keeps the short history of goal values the trends need.

const Keys = preload("res://simulation/keys.gd")
const Stats = preload("res://simulation/stats.gd")
const Research = preload("res://simulation/research.gd")

const MET: String = "met"
const ON_TRACK: String = "on_track"
const LATE: String = "late"
const ACTION: String = "needs_action"
const HISTORY_EVERY: int = 5
const HISTORY_KEEP: int = 30
const TREND_DAYS: int = 30
const MIN_TREND_SPAN: int = 10
const NEVER: int = 1 << 20


## Every few days the current stage's goal values are kept for the trends (a short history).
static func record(sim: RefCounted) -> void:
	var contract: Dictionary = sim.state.contract
	if not contract.has("history"):
		contract.history = []
	if int(sim.state.day) % HISTORY_EVERY != 0:
		return
	var stage: int = int(contract.stage)
	if stage > sim.Contract.STAGE_COUNT:
		return
	var values: Dictionary = {}
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		values[str(goal.key)] = float(goal.value)
	contract.history.append({"day": int(sim.state.day), "stage": stage, "values": values})
	while contract.history.size() > HISTORY_KEEP:
		contract.history.pop_front()


## The change a day of one goal over about the last month of this stage, or null-like {span: 0}.
static func trend(sim: RefCounted, key: String, value: float) -> Dictionary:
	var history: Array = sim.state.contract.get("history", [])
	var today: int = int(sim.state.day)
	var stage: int = int(sim.state.contract.stage)
	var start: Dictionary = {}
	for row: Dictionary in history:
		if int(row.stage) != stage or not row.values.has(key):
			continue
		if today - int(row.day) <= TREND_DAYS:
			start = row
			break
	if start.is_empty() or today - int(start.day) < MIN_TREND_SPAN:
		return {"span": 0, "per_day": 0.0}
	var span: int = today - int(start.day)
	return {"span": span, "per_day": (value - float(start.values[key])) / span}


static func view(sim: RefCounted) -> Dictionary:
	var stage: int = int(sim.state.contract.stage)
	if stage > sim.Contract.STAGE_COUNT or sim.state.status in ["success", "failed"]:
		return {"stage": stage, "goals": [], "eta": -1}
	var deadline: int = sim.Contract.deadline(sim, stage)
	var rows: Array = []
	var eta: int = int(sim.state.day)
	var supported: bool = true
	var bottleneck: String = ""
	for goal: Dictionary in sim.Contract.stage_goals(sim, stage):
		var row: Dictionary = _goal(sim, goal, deadline)
		rows.append(row)
		if str(row.status) == MET:
			continue
		if int(row.eta) < 0:
			supported = false
			bottleneck = str(goal.key) if bottleneck == "" else bottleneck
		elif int(row.eta) > eta:
			eta = int(row.eta)
			bottleneck = str(goal.key)
	var waiting: bool = supported
	for row: Dictionary in rows:
		if str(row.status) == ACTION:
			waiting = false
	return {
		"stage": stage,
		"deadline": deadline,
		"goals": rows,
		"eta": eta if supported else -1,
		"bottleneck": bottleneck,
		# Every goal met or on its way: the stage completes if the colony is left to run.
		"completes_by_waiting": waiting,
	}


## One goal: its status, trend, date, what holds it, and the action.
static func _goal(sim: RefCounted, goal: Dictionary, deadline: int) -> Dictionary:
	var key: String = str(goal.key)
	var value: float = float(goal.value)
	var target: float = float(goal.target)
	var today: int = int(sim.state.day)
	var row: Dictionary = {
		"key": key,
		"value": value,
		"target": target,
		"status": MET if bool(goal.ok) else ACTION,
		"trend": trend(sim, key, value),
		"eta": today if bool(goal.ok) else -1,
		"holding": "",
		"action": {},
	}
	if bool(goal.ok):
		return row
	match key:
		"exports_total":
			_exports(sim, row)
		"stage_streak":
			_streak(sim, row)
		"processing_days":
			_counting(sim, row, _processing_today(sim), "加工厂今天没有运转", "build")
		"technologies":
			_technologies(sim, row)
		"population", "capital_population":
			_population(sim, row)
		"connected":
			_connected(sim, row)
		"research_staffed":
			_research_staffed(sim, row)
		"food_days":
			row.holding = "有据点存粮不足 %.0f 天" % target
			row.action = {
				"page": "build", "category": "food", "text": "建农场或让货运站多进口食品", "need": "food"
			}
		_:
			_by_trend(sim, row)
	if int(row.eta) >= 0 and str(row.status) != MET:
		row.status = ON_TRACK if int(row.eta) <= deadline else LATE
	return row


## A goal that climbs at its recent pace: on its way while it climbs.
static func _by_trend(sim: RefCounted, row: Dictionary) -> void:
	var per_day: float = float(row.trend.per_day)
	if int(row.trend.span) > 0 and per_day > 0.0:
		row.eta = int(sim.state.day) + ceili((float(row.target) - float(row.value)) / per_day)
	elif int(row.trend.span) == 0:
		row.holding = "数据还不够，看不出走势"
	else:
		row.holding = "近 %d 天没有进展" % int(row.trend.span)


## Exports: the receipts of the last month a day (exports, supply orders, food and event orders).
static func _exports(sim: RefCounted, row: Dictionary) -> void:
	var window: Dictionary = sim.stats_window(TREND_DAYS)
	var days: float = maxf(1.0, float(window.get("days", 1)))
	var income: Dictionary = window.get("income", {})
	var per_day: float = 0.0
	for key: String in ["export", "supply.income", "food_order.income", "event.order_income"]:
		per_day += float(income.get(key, 0.0)) / days
	var local: float = (
		(float(income.get("food.sales", 0.0)) + float(income.get("commerce.income", 0.0))) / days
	)
	row.per_day = per_day
	row.local_per_day = local
	if per_day > 0.0:
		row.eta = int(sim.state.day) + ceili((float(row.target) - float(row.value)) / per_day)
		row.holding = "出口收入每天约 ¥%.0f；本地销售每天约 ¥%.0f 不计入" % [per_day, local]
	else:
		row.holding = (
			"还没有出口收入；本地销售每天约 ¥%.0f 不计入合同" % local
			if local > 0.0
			else "还没有出口收入"
		)
	row.action = {
		"page": "build",
		"category": "extraction",
		"text": "建矿场、签供货合同或保持货运站运转",
		"need": "exports",
	}


## A count that grows by one each day while its condition holds today.
static func _counting(
	sim: RefCounted, row: Dictionary, holds: bool, holding: String, page: String
) -> void:
	if holds:
		row.eta = int(sim.state.day) + int(float(row.target) - float(row.value))
	else:
		row.holding = holding
		row.action = {
			"page": page, "category": "industry", "text": "建复合加工厂并保证铁矿和铜矿供应", "need": "processing"
		}


static func _processing_today(sim: RefCounted) -> bool:
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if (
				str(sim.config.buildings.get(b.kind, {}).get("role", "")) == "factory"
				and str(b.status) in [Keys.B_RUNNING, Keys.B_TARGET_FULL]
			):
				return true
	return false


static func _streak(sim: RefCounted, row: Dictionary) -> void:
	var history: Array = sim.state.operating_history
	var net: float = 0.0
	for index: int in range(maxi(0, history.size() - 7), history.size()):
		net += float(history[index].net)
	if int(row.value) > 0 or net >= 0.0:
		row.eta = int(sim.state.day) + int(float(row.target) - float(row.value))
	else:
		row.holding = "近 7 天经营结余 ¥%.0f：亏损时连续天数清零" % net
		row.action = {"page": "economy", "text": "减少开支或增加收入，让一周合计不为负"}


## Population: the trend, and what limits it in each town: housing or jobs (or food, or appeal).
static func _population(sim: RefCounted, row: Dictionary) -> void:
	_by_trend(sim, row)
	var housing: int = 0
	var jobs: int = 0
	var beds_short: Array = []
	var jobless: Array = []
	for s: Dictionary in sim.state.settlements:
		if str(row.key) == "capital_population" and s != sim.state.settlements[0]:
			continue
		var v: Dictionary = sim.population_view(int(s.region))
		var free: int = int(v.get("free_beds", 0))
		var prospects: float = float(v.get("prospects", 1.0))
		if free <= 0:
			housing += 1
			beds_short.append(str(s.name))
		elif prospects < 0.999:
			jobs += 1
			jobless.append(str(s.name))
	var home: Dictionary = sim.config.buildings.get("habitat", {})
	if housing > 0 and housing >= jobs:
		row.limit = "housing"
		row.holding = "住房不足：%s 没有空床位，想来的人进不来" % "、".join(PackedStringArray(beds_short))
		row.action = {
			"page": "build",
			"category": "people",
			"kind": "habitat",
			"text": "建住房",
			"cost": float(home.get("cost", 0.0)),
			"effect": "+%d 床" % int(sim.Population.habitat_beds(sim, {"kind": "habitat", "level": 1})),
			"need": "housing",
		}
	elif jobs > 0:
		row.limit = "jobs"
		row.holding = "工作不足：%s 失业的人多，新移民不来" % "、".join(PackedStringArray(jobless))
		row.action = {
			"page": "build",
			"category": "extraction",
			"text": "建能雇人的设施（矿场、农场、工厂）",
			"effect": "每座约 8–10 个岗位",
			"need": "jobs",
		}
	elif str(row.holding) == "":
		row.limit = "appeal"
		row.holding = "住房和工作都够：增长靠吸引力和时间"


## Technologies: the projects at work that count, when each should finish at its team's pace, and
## the day the count is reached with each category taking up its next topic at the same pace;
## then the same with every running project commissioned at the top level, and what that costs.
static func _technologies(sim: RefCounted, row: Dictionary) -> void:
	var needed: int = int(float(row.target) - float(row.value))
	var projects: Array = []
	var plain: Array = []
	var fast: Array = []
	var commission_cost: float = 0.0
	var levels: int = sim.progression.research.get("commission", {}).get("speedup", []).size()
	for key: String in sim.state.research.projects:
		var p: Dictionary = sim.state.research.projects[key]
		if sim.state.research.completed.has(key) or int(p.staff) <= 0:
			continue
		var left: int = Research.days_left(sim, key)
		var pace: float = float(p.get("rate", 0.0))
		# The category's next topic: the cards on offer beside this one cost what they cost.
		var cost: float = _next_cost(sim, key)
		var entry: Dictionary = {
			"tech": key,
			"name": str(sim.config.techs[key].name),
			"days_left": left,
			"progressing": left >= 0,
			"reason": str(p.get("reason", "")),
		}
		projects.append(entry)
		if left < 0 or pace <= 0.0:
			continue
		plain.append({"first": left, "every": ceili(cost / pace)})
		if levels > 1:
			var quote: Dictionary = Research.commission_quote(sim, key, levels - 1)
			var extra: float = float(quote.extra)
			var remaining: float = maxf(
				0.0, float(sim.config.techs[key].cost) - float(p.get("work", 0.0))
			)
			fast.append(
				{
					"first": ceili(remaining / (pace + extra)),
					"every": ceili(cost / (pace + extra)),
				}
			)
			commission_cost += float(quote.cost)
	row.projects = projects
	var today: int = int(sim.state.day)
	var days: int = _days_to(plain, needed)
	if days >= 0:
		row.eta = today + days
	else:
		row.holding = (
			"没有在研的课题"
			if projects.is_empty()
			else "在研课题没有进展：" + str(projects[0].reason)
		)
	var faster: int = _days_to(fast, needed)
	if faster >= 0 and days >= 0 and faster < days:
		row.commission = {"eta": today + faster, "cost_per_day": commission_cost, "saves": days - faster}
	row.action = {
		"page": "research",
		"text": "派研究团队做课题；委托研究可以加快",
		"teams": int(Research.assignable(sim).teams),
	}


## What the next topic in a project's category is likely to cost: the mean of the other cards on
## offer there, else the project's own cost.
static func _next_cost(sim: RefCounted, tech: String) -> float:
	var category: String = str(sim.config.techs[tech].category)
	var total: float = 0.0
	var count: int = 0
	for key: String in sim.state.research.get("offers", {}).get(category, []):
		if key == tech or sim.state.research.completed.has(key):
			continue
		total += float(sim.config.techs[key].cost)
		count += 1
	return total / count if count > 0 else float(sim.config.techs[tech].cost)


## Days until `needed` completions, each running project finishing after `first` days and its
## category taking up the next topic every `every` days; -1 when nothing runs.
static func _days_to(runs: Array, needed: int) -> int:
	if needed <= 0:
		return 0
	if runs.is_empty():
		return -1
	var day: int = 0
	while day < 5000:
		day += 1
		var done: int = 0
		for run: Dictionary in runs:
			if day >= int(run.first):
				done += 1 + (day - int(run.first)) / maxi(1, int(run.every))
		if done >= needed:
			return day
	return -1


static func _connected(sim: RefCounted, row: Dictionary) -> void:
	var soonest: int = -1
	for road: Dictionary in sim.state.roads:
		var ready: int = int(road.get("ready_day", 0))
		if ready > int(sim.state.day) and not sim.Logistics.is_shuttle(road):
			soonest = ready if soonest < 0 else mini(soonest, ready)
	var towns: int = sim.state.settlements.size()
	if towns < int(row.target):
		row.holding = "据点只有 %d 处，要 %d 处相连" % [towns, int(row.target)]
		row.action = {"page": "", "text": "在地图上选地点派远征队", "need": "settlement"}
	elif soonest >= 0:
		row.eta = soonest
		row.holding = "在修的路第 %d 天通车" % soonest
	else:
		row.holding = "据点之间还没有相连的路"
		row.action = {"page": "transport", "text": "修路或开航线"}


static func _research_staffed(sim: RefCounted, row: Dictionary) -> void:
	var teams: Dictionary = Research.assignable(sim)
	row.holding = (
		"有 %d 支研究团队可派" % int(teams.teams)
		if int(teams.teams) >= 3
		else "可派的研究团队不足 3 支：%s" % (str(teams.reason) if str(teams.reason) != "" else "先建研究所")
	)
	row.action = {"page": "research", "text": "给一个课题派 3 支以上团队", "teams": int(teams.teams)}


## The towns that can carry out a goal's action, each with why it qualifies (1.11): for exports a
## town with free deposit plots, a supply order it can sign or has, or factories selling their
## output, and a working cargo station or harbour; for housing a town where homes can be built; for
## jobs one with people looking for work and free ground; for food one with farmland or a port.
## [{region, name, why}].
static func candidates(sim: RefCounted, need: String) -> Array:
	var rows: Array = []
	for s: Dictionary in sim.state.settlements:
		if int(s.get("arrival", 0)) > 0:
			continue
		var why: PackedStringArray = []
		var region: int = int(s.region)
		var free: Dictionary = sim.Sites.free_counts(sim, region)
		var category: String = ""
		match need:
			"exports":
				for good: String in ["ore", "copper", "crystal"]:
					if int(free.get(good, 0)) > 0:
						why.append(
							(
								"%s矿地块 %d 块"
								% [{"ore": "铁", "copper": "铜", "crystal": "晶体"}[good], int(free[good])]
							)
						)
						category = "extraction" if category == "" else category
				for offer: Dictionary in sim.Supply.offers(sim, s):
					if not offer.open.is_empty():
						why.append("%s在执行" % str(offer.name))
					elif str(offer.refusal) == "":
						why.append("可签%s" % str(offer.name))
					else:
						continue
					if category == "":
						category = "food" if str(offer.kind) == "food" else "utilities"
				for good: String in ["materials", "parts"]:
					if float(s.get("exportable", {}).get(good, 0.0)) > 0.0:
						why.append("加工品在出口")
						category = "industry" if category == "" else category
						break
				var outlet: bool = sim.Logistics._has_port(s) or sim.Bay.harbor_working(sim, s)
				if not why.is_empty() and not outlet:
					why.append("先建货运站")
					category = "utilities"
			"housing":
				if str(s.kind) == Keys.SITE_RESIDENTIAL and int(free.general) > 0:
					why.append(
						(
							"空床 %d · 空地 %d 块"
							% [maxi(0, int(s.housing) - int(s.population)), int(free.general)]
						)
					)
					category = "people"
			"jobs":
				var seeking: int = maxi(0, int(s.workers) - int(s.get("employed_workers", 0)))
				if seeking > 0 and int(free.general) + int(free.farm) > 0:
					why.append(
						"找工作的职工 %d · 空地 %d 块" % [seeking, int(free.general) + int(free.farm)]
					)
					category = "extraction"
			"food":
				if int(free.farm) > 0 or sim.Logistics._has_port(s):
					why.append(
						"存粮 %.0f 天 · 空农田 %d 块" % [float(s.get("food_days", 0.0)), int(free.farm)]
					)
					category = "food"
			"processing":
				if float(s.stock.ore) > 0.0 or int(free.get("ore", 0)) > 0:
					why.append("有铁矿供应")
					category = "industry"
			_:
				why.append(_kind_words(s))
		if not why.is_empty():
			rows.append(
				{"region": region, "name": str(s.name), "why": "；".join(why), "category": category}
			)
	return rows


static func _kind_words(s: Dictionary) -> String:
	return "居住据点" if str(s.get("kind", "")) == Keys.SITE_RESIDENTIAL else "边疆据点"
