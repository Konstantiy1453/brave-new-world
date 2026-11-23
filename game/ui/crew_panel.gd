extends RefCounted
## The engineering crews on the construction page (1.10 plan C1): each crew, where it is, what it
## builds and until when; the orders waiting for a crew; training a worker as a crew; sending a
## crew to another town. What one more order means for the queue is on the order's ledger
## (`start_line`). The town's sidebar and the colony's building list show each project's start and
## finish from its crews (`Crews.eta`), and a waiting order can be told to go next (先建).

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")


static func strip(g, b: Control, s: Dictionary) -> void:
	var view: Dictionary = g.sim.Crews.view(g.sim)
	var card: VBoxContainer = D.card(b)
	card.add_theme_constant_override("separation", 4)
	var head: HBoxContainer = D.row(card)
	var here: Array = []
	for team: Dictionary in view.teams:
		if int(team.region) == int(s.region) or int(team.get("target", -1)) == int(s.region):
			here.append(team)
	D.label(head, "工程队 · 本地 %d 支 · 全殖民地 %d 支" % [here.size(), view.teams.size()], 18, D.TEAL, false)
	var rule: Dictionary = g.sim.pop_rules.get("crews", {})
	var dearer: String = (
		"殖民地每多一支工程队，培训和招募都贵 %.0f%%（前 %d 支不加价）"
		% [float(rule.get("growth_per_crew", 0.0)) * 100.0, int(rule.get("free_crews", 0))]
	)
	var train: Button = D.button(
		head,
		(
			"培训一支工程队 · ¥ %.0f · %d 天"
			% [float(view.get("train_price", 0.0)), int(rule.get("train_days", 0))]
		),
		func(): g.act("crew_train", {"region": int(s.region)}),
		"从本地职工中培训：人口不变，培训期间不能派工。" + dearer,
		"CrewTrain"
	)
	D.font_size(train, D.SMALL)
	var region: int = int(s.region)
	var hire: Button = D.button(
		head,
		(
			"招募一支工程队 · ¥ %.0f · %d 天"
			% [
				g.sim.Population.campaign_cost(g.sim, "crew", 1),
				int(g.sim.pop_rules.recruitment.travel_days)
			]
		),
		func(): g.act("recruit", {"region": region, "kind": "crew", "count": 1}),
		"从殖民地外招募：抵达后人口加 1，要占一张床位。" + dearer,
		"CrewRecruit"
	)
	D.font_size(hire, D.SMALL)
	_orders(g, card, region, str(view.get("orders", {}).get(region, "oldest")))
	for team: Dictionary in here:
		_team_row(g, card, team)
	var waiting: Array = view.waiting.get(int(s.region), [])
	if not waiting.is_empty():
		D.label(card, "等工程队开工（按开工顺序）：" + "、".join(PackedStringArray(waiting)), D.SMALL, D.GOLD)
	D.label(
		card,
		(
			"总是先修本地缺水、缺电、缺粮的工程（手头的工程暂停、进度保留），再建标了「先建」的；"
			+ "其余按上面的常设指令。陆路的修建和升级也要工程队，没有工程队的日子工期顺延；"
			+ "工程队抢修落石封路，每天多清一天；实地勘察和钻探由最近据点的一支工程队带队。"
		),
		D.CAPTION,
		D.MUTED
	)


## The town's standing order for its crews, one of three, the current one marked.
static func _orders(g, parent: Control, region: int, current: String) -> void:
	var line: HBoxContainer = D.row(parent)
	D.label(line, "常设指令：", D.SMALL, D.INK, false)
	var choices: Array = [
		["oldest", "按下单顺序（落石先抢修）", "设施和道路按下单先后开工；封路先抢修"],
		["roads", "道路与抢修优先", "先抢修封路、修路和升级道路，再建设施"],
		["facilities", "设施优先", "先建设施，再抢修和修路"],
	]
	for choice: Array in choices:
		var order: String = str(choice[0])
		var chip: Button = D.button(
			line,
			("● " if order == current else "") + str(choice[1]),
			func(): g.act("crew_order", {"site": region, "order": order}),
			str(choice[2]),
			"CrewOrder_%s" % order,
			"chip"
		)
		D.font_size(chip, D.CAPTION)
		chip.disabled = order == current


static func _team_row(g, parent: Control, team: Dictionary) -> void:
	var line: HBoxContainer = D.row(parent)
	var day: int = int(g.sim.state.day)
	var text: String = "工程队 #%d · 空闲，下一项工程自动开工" % int(team.id)
	match str(team.task):
		"build", "road", "repair":
			text = (
				"工程队 #%d · %s %s，还要 %d 天"
				% [
					int(team.id),
					"在建" if str(team.task) == "build" else "在做",
					str(team.get("project", "")),
					int(team.get("days_left", 0))
				]
			)
		"field":
			text = (
				"工程队 #%d · 带%s队在野外，%d 天后回来"
				% [int(team.id), str(team.get("project", "")), int(team.get("days_left", 0))]
			)
		"train":
			text = "工程队 #%d · 培训中，还要 %d 天" % [int(team.id), maxi(0, int(team.until) - day)]
		"travel":
			var to: Dictionary = g.sim.settlement(int(team.target))
			text = (
				"工程队 #%d · 前往 %s，%d 天后到"
				% [int(team.id), str(to.get("name", "")), maxi(0, int(team.until) - day)]
			)
			if bool(team.get("held", false)):
				text += "（线路封闭，停在途中等待，与货运相同）"
	var words: Label = D.label(line, text, D.SMALL, D.INK, false)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(team.task) in ["train", "travel", "field"]:
		return
	for other: Dictionary in g.sim.state.settlements:
		var to: int = int(other.region)
		if to == int(team.region):
			continue
		var link: Dictionary = g.sim.Crews.travel_link(g.sim, int(team.region), to)
		var days: int = int(link.days)
		if days < 0:
			# A closed link is shown, so the player sees why the crew cannot go.
			if str(link.reason).contains("封闭"):
				var closed: Label = D.label(
					line, "%s：%s" % [str(other.name), str(link.reason)], D.CAPTION, D.MUTED, false
				)
				D.named(closed, "CrewRouteClosed_%d" % to)
			continue
		var crew: int = int(team.id)
		var send: Button = D.button(
			line,
			"派往 %s（%d 天）" % [str(other.name), days],
			func(): g.act("crew_send", {"crew": crew, "to": to}),
			_send_delay(g, team, days),
			"CrewSend_%d_%d" % [crew, to],
			"chip"
		)
		D.font_size(send, D.CAPTION)


## What sending this crew away delays: its project and the queue it leaves, and when it arrives.
static func _send_delay(g, team: Dictionary, days: int) -> String:
	var arrive: String = "%d 天后到达，接手那里排队的工程" % days
	if not str(team.task) in ["build", "road", "repair"]:
		return arrive
	var others: int = 0
	for other: Dictionary in g.sim.Crews.teams_at(g.sim, int(team.region)):
		if int(other.id) != int(team.id) and str(other.task) != "train":
			others += 1
	var waiting: int = g.sim.Crews.view(g.sim).waiting.get(int(team.region), []).size()
	var project: String = (
		"「%s」还差 %d 天" % [str(team.get("project", "")), int(team.get("days_left", 0))]
	)
	if others == 0:
		return "派走后本地没有工程队：%s，连同排队的 %d 项工程一起停工。%s" % [project, waiting, arrive]
	return "派走后%s，等本地另外 %d 支工程队空出来再接手。%s" % [project, others, arrive]


## When one more order of this kind here would start: at once if it fixes a shortage the town has
## (the crews' standing instruction) or a crew is free, otherwise behind the queue.
static func start_line(g, s: Dictionary, kind: String = "") -> String:
	var view: Dictionary = g.sim.Crews.view(g.sim)
	var idle: int = 0
	var builders: int = 0
	var busy_left: Array = []
	for team: Dictionary in view.teams:
		if int(team.region) != int(s.region):
			continue
		match str(team.task):
			"":
				idle += 1
			"build", "road", "repair":
				builders += 1
				busy_left.append(int(team.get("days_left", 0)))
			"train", "field":
				busy_left.append(maxi(0, int(team.until) - int(g.sim.state.day)))
	var urgent: bool = kind != "" and g.sim.Crews.fixes_shortage(g.sim, s, {"kind": kind})
	var urgent_ahead: int = int(view.get("urgent", {}).get(int(s.region), 0))
	if urgent and idle + builders > 0 and urgent_ahead == 0:
		return "开工：它能解决本地短缺，工程队会先修它（手头的工程暂停，进度保留）"
	if urgent and idle + builders > 0:
		return "开工：它能解决本地短缺，排在 %d 项抢修工程之后、其他工程之前" % urgent_ahead
	var queued: int = view.waiting.get(int(s.region), []).size()
	if idle > queued:
		return "开工：本地有空闲工程队，下令即开工"
	if busy_left.is_empty():
		return "开工：本地没有工程队，需要培训或从别处派来"
	busy_left.sort()
	return "开工：工程队都在忙，前面还有 %d 项等工，最早约 %d 天后有队空出" % [queued, int(busy_left[0])]


## The town's projects under way in its sidebar, each with its progress and when it finishes.
static func underway(g, b: Control, s: Dictionary) -> void:
	var plans: Dictionary = g.sim.Crews.eta(g.sim, s)
	var first: bool = true
	for item: Dictionary in s.buildings:
		if int(item.remaining) <= 0 and int(item.get("upgrade_days", 0)) <= 0:
			continue
		if first:
			D.label(b, "在建", 14, D.GOLD)
			first = false
		_underway_row(g, b, s, item, plans.get(int(item.get("uid", 0)), {}))


## One project: building or upgrading, its progress, and its finish: who builds it, or when a crew
## is expected to start it, with 先建 to put it ahead of the older orders.
static func _underway_row(g, b: Control, s: Dictionary, item: Dictionary, plan: Dictionary) -> void:
	var day: int = int(g.sim.state.day)
	var card: Control = D.card(b)
	var line: HBoxContainer = D.row(card)
	D.building_icon(line, str(item.kind), Labels.icon_key(g.sim.config, str(item.kind)), 32)
	var building: bool = int(item.remaining) > 0
	var left: int = int(item.remaining) if building else int(item.upgrade_days)
	var words: String = Labels.building_name(g.sim.config, item.kind)
	if not building:
		words += " 升级到 %d 级" % (int(item.level) + 1)
	var caption: Label = D.label(line, words, 15, D.INK)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var total: int = maxi(left, int(item.get("total_days", left)))
	if not building:
		total = maxi(left, _upgrade_total(g, item))
	D.progress(card, 1.0 - float(left) / maxi(1, total), D.GOLD)
	if not building or plan.is_empty():
		D.label(card, "%s 完工 · 还要 %d 天" % [Labels.short_date(day + left), left], 13, D.MUTED)
		return
	if int(plan.finish) < 0:
		D.label(card, "等工程队 · 本地没有工程队：培训一支或从别处派来", 13, D.GOLD)
		return
	var finish: int = int(plan.finish)
	if int(plan.start) <= day + 1:
		var who: String = " · 工程队 #%d" % int(plan.crew) if int(plan.crew) > 0 else ""
		D.label(
			card, "%s 完工 · 还要 %d 天%s" % [Labels.short_date(finish), finish - day, who], 13, D.MUTED
		)
		return
	var wait: HBoxContainer = D.row(card)
	var note: Label = D.label(
		wait,
		"等工程队 · 约 %s 开工，%s 完工" % [Labels.short_date(int(plan.start)), Labels.short_date(finish)],
		13,
		D.GOLD,
		false
	)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var uid: int = int(item.get("uid", 0))
	var region: int = int(s.region)
	if g.sim.Crews.chosen_next(g.sim, region) == uid:
		D.label(wait, "下一项", D.CAPTION, D.TEAL, false)
		return
	var next: Button = D.button(
		wait,
		"先建",
		func(): g.act("crew_next", {"site": region, "uid": uid}),
		"让本地工程队手头的工程完工后先建它（抢修短缺的工程仍然优先）",
		"CrewNext_%d" % uid,
		"chip"
	)
	D.font_size(next, D.CAPTION)


static func _upgrade_total(g, item: Dictionary) -> int:
	var rules: Array = g.sim.config.get("upgrades", {}).get(item.kind, [])
	var step: int = int(item.get("level", 1)) - 1
	return int(rules[step].days) if step >= 0 and step < rules.size() else 0


## The colony's projects under way on the buildings page, soonest first: days to the expected
## finish (from the crews), what waits for a crew, and expeditions on their way.
static func colony_underway(g, b: Control) -> void:
	var underway: Array = []
	for s: Dictionary in g.sim.state.settlements:
		if int(s.arrival) > 0:
			underway.append({"days": int(s.arrival), "text": "远征队前往 %s" % str(s.name), "note": ""})
		var plans: Dictionary = g.sim.Crews.eta(g.sim, s)
		for item: Dictionary in s.buildings:
			var name: String = Labels.building_name(g.sim.config, item.kind)
			if int(item.remaining) > 0:
				underway.append(
					_colony_row(g, s, item, name, plans.get(int(item.get("uid", 0)), {}))
				)
			elif int(item.get("upgrade_days", 0)) > 0:
				var upgrade: String = "%s 升级到 %d 级 · %s" % [name, int(item.level) + 1, str(s.name)]
				underway.append({"days": int(item.upgrade_days), "text": upgrade, "note": ""})
	underway.sort_custom(_sooner)
	D.label(b, "在建工程 %d 项" % underway.size(), 21, D.GOLD)
	if underway.is_empty():
		D.label(b, "现在没有在建的工程。", 16, D.MUTED)
	var grid: GridContainer = D.grid(D.card(b), 2)
	for row: Dictionary in underway:
		var text: Label = D.label(grid, str(row.text), 16, D.INK, false)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var left: String = "没有工程队" if int(row.days) < 0 else "还需 %d 天" % int(row.days)
		var tone: Color = D.GOLD if bool(row.get("waiting", false)) or int(row.days) < 0 else D.TEAL
		D.label(grid, left + str(row.note), 16, tone, false)


static func _colony_row(
	g, s: Dictionary, item: Dictionary, name: String, plan: Dictionary
) -> Dictionary:
	var day: int = int(g.sim.state.day)
	var text: String = "%s · %s" % [name, str(s.name)]
	var spec: Dictionary = g.sim.config.buildings.get(item.kind, {})
	var total: String = " / 共 %d 天" % maxi(int(spec.get("days", 0)), int(item.remaining))
	if plan.is_empty():
		return {"days": int(item.remaining), "text": text, "note": total}
	if int(plan.finish) < 0:
		return {"days": -1, "text": text, "note": ""}
	if int(plan.start) > day + 1:
		var wait: String = "（等工程队，工期 %d 天）" % int(item.remaining)
		return {"days": int(plan.finish) - day, "text": text, "note": wait, "waiting": true}
	return {"days": int(plan.finish) - day, "text": text, "note": total}


static func _sooner(x: Dictionary, y: Dictionary) -> bool:
	var a: int = int(x.days) if int(x.days) >= 0 else 1 << 30
	var c: int = int(y.days) if int(y.days) >= 0 else 1 << 30
	if a == c:
		return str(x.text) < str(y.text)
	return a < c


## Who works at a road that needs a crew (crews.gd): the crew on it, or that it waits for one and
## its finish moves a day later for each day without; empty for a road that needs none today.
static func road_line(g, road: Dictionary) -> String:
	var work: Dictionary = g.sim.Crews.road_work(g.sim, road)
	if work.is_empty():
		return ""
	var what: String = "抢修" if str(work.kind) == "repair" else "施工"
	for team: Dictionary in g.sim.Crews.view(g.sim).teams:
		if str(team.task) == str(work.kind) and int(team.target) == int(road.id):
			return "工程队 #%d 正在%s，按现在的进度约 %d 天" % [int(team.id), what, int(work.remaining)]
	if str(work.kind) == "repair":
		return "没有工程队抢修：按原定日期自行恢复；派一支工程队可以快一倍"
	return "等工程队：两端据点的工程队空出来才开工，没有工程队的日子工期顺延"
