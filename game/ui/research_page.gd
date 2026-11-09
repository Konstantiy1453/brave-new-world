extends RefCounted
## The research page (知识就是生产力 / 科研教育), drawn in the lively research variant: four
## directions side by side, each with its colour and icon, its team, and the topics dealt to it.
## A topic reads top to bottom: its state, what it is, what it does, what it unlocks, how far it
## has come, and what can be done with it. The figures and actions are the research rules' own
## (Research.cards and research_view); only the presentation changed.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
## Each direction's line icon (assets/icons/research_<category>.svg).
const ICON_PREFIX: String = "research_"


static func research(g, b):
	var v: Dictionary = g.sim.research_view()
	var columns: Array = g.sim.research_cards()
	_header(b, v, columns)
	var grid = D.grid(b, columns.size())
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for column: Dictionary in columns:
		_research_column(g, grid, column, v)
	_research_contract(g, b, v)
	_finished(b, columns)


## The teams and places the colony has, and how the page works.
static func _header(b, v: Dictionary, columns: Array) -> void:
	var finished: int = 0
	var pool: int = 0
	for column: Dictionary in columns:
		finished += column.finished.size()
		pool += int(column.pool)
	var strip: HBoxContainer = D.row(b)
	strip.add_theme_constant_override("separation", 26)
	var title: VBoxContainer = D.col(strip)
	title.add_theme_constant_override("separation", 0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(title, "已完成 %d / %d 项课题" % [finished, pool], D.CAPTION, D.MUTED, false)
	D.label(title, "科研 / 四个方向的课题", 22, D.INK, false)
	D.stat(strip, "研究团队", str(int(v.total)), D.GOLD, "研究所培养的研究团队总数")
	D.stat(strip, "调查", str(int(v.investigating)), D.INK, "正在做地点调查的团队")
	D.stat(strip, "可用", str(int(v.available)), D.TEAL, "还没有分配的团队")
	D.stat(strip, "科研席位", str(int(v.capacity)), D.INK)
	D.stat(strip, "实验台", str(int(v.benches)), D.INK, "每个在研项目占用一个实验台")
	D.label(
		b,
		"每个方向同时做一个课题，候选是随机出现的。挑一张，再派研究团队：5 支的速度是 10 支的 60%。换课题不丢进度；课题完成后，这个方向会出现新的候选。",
		D.SMALL,
		D.MUTED
	)


static func _research_column(g, grid, column: Dictionary, v: Dictionary):
	var id: String = str(column.id)
	var tint: Color = D.category_color(id)
	var box = D.col(grid)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var head: VBoxContainer = D.card(box)
	head.add_theme_constant_override("separation", 6)
	D.rule(head, tint, 3)
	var title: HBoxContainer = D.row(head)
	title.add_theme_constant_override("separation", 10)
	var mark: TextureRect = D.tinted_icon(title, ICON_PREFIX + id, 34, tint)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words: VBoxContainer = D.col(title)
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(words, str(column.name), D.SECTION, tint, false)
	D.label(words, str(column.description), D.CAPTION, D.MUTED)
	var running: Dictionary = column.running
	if running.is_empty():
		D.tag(title, "○ 待选", D.MUTED)
	else:
		D.tag(title, "● 在研", D.TEAL)
	var wanted: int = int(g.research_team.get(id, clampi(int(v.available), 3, 10)))
	var line = D.row(head)
	line.add_theme_constant_override("separation", 8)
	var caption: Label = D.label(line, "研究团队", D.SMALL, D.MUTED, false)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var count = D.spin(
		line,
		"Staff_" + id,
		0,
		maxi(10, int(v.total)),
		1,
		int(running.staff) if not running.is_empty() else wanted
	)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not running.is_empty():
		var tech: String = str(running.id)
		var apply = D.button(
			line,
			"调整",
			func(): g.act("research_allocate", {"tech": tech, "staff": int(count.value)}),
			"0 支就是暂停，已做的研究量不丢"
		)
		D.font_size(apply, D.SMALL)
		apply.custom_minimum_size = Vector2(60, 34)
	for row: Dictionary in column.offers:
		_tech_card(g, box, row, count)
	if column.offers.is_empty():
		D.label(box, "这个方向暂时没有新课题。", D.SMALL, D.MUTED)
	var category: String = id
	var again = D.button(
		box,
		"重新调研 · ¥ %.0f" % float(g.sim.Research.reshuffle_cost(g.sim)),
		func(): g.act("research_reshuffle", {"category": category}),
		"付钱换掉还没开工的候选课题",
		"Reshuffle_" + id,
		"chip"
	)
	D.font_size(again, D.SMALL)
	again.custom_minimum_size.y = 34


## One dealt topic. Active (its team is on it), available (it can be picked), or waiting for a
## prerequisite; the state is written on the card as well as coloured.
static func _tech_card(g, parent, row: Dictionary, count):
	var running: bool = int(row.staff) > 0
	var missing: Array = row.get("missing", [])
	var blocked: bool = not running and not missing.is_empty()
	var role: String = "card_on" if running else ("card_quiet" if blocked else "card")
	var c = D.card(parent, role)
	c.add_theme_constant_override("separation", 5)
	var top = D.row(c)
	top.add_theme_constant_override("separation", 6)
	if running:
		D.tag(top, "● 进行中", D.TEAL)
	elif blocked:
		D.tag(top, "× 需前置", D.RED)
	else:
		D.tag(top, "○ 可选", D.tone("accent_2"))
	var level: Label = D.label(
		top, "第 %d 级 · %.0f 点" % [int(row.tier), float(row.cost)], D.CAPTION, D.MUTED, false
	)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	D.label(c, str(row.name), 18, D.TEAL if running else (D.MUTED if blocked else D.INK))
	D.label(c, str(row.description), D.SMALL, D.MUTED if blocked else D.INK)
	_unlocks(g, c, str(row.id), row.get("unlocks", []))
	if bool(row.charter):
		D.label(c, "★ 总督资格必需：这张课题不会被洗掉", D.CAPTION, D.GOLD)
	if blocked:
		D.label(c, "需要前置技术：" + "、".join(PackedStringArray(missing)), D.CAPTION, D.RED)
	var work: float = float(row.work)
	if work > 0.0:
		var bar_line = D.row(c)
		bar_line.add_theme_constant_override("separation", 8)
		var bar: ProgressBar = D.progress(
			bar_line, work / float(row.cost), D.TEAL if running else D.MUTED, 8
		)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		D.label(
			bar_line,
			"%.0f%%" % (100.0 * clampf(work / float(row.cost), 0.0, 1.0)),
			D.CAPTION,
			D.TEAL if running else D.MUTED,
			false
		)
	if running:
		if float(row.rate) > 0.0:
			var left: int = ceili((float(row.cost) - work) / float(row.rate))
			D.label(
				c,
				(
					"%d 支团队 · 还要 %d 天（%s）"
					% [int(row.effective), left, Labels.short_date(int(g.sim.state.day) + left)]
				),
				D.SMALL,
				D.TEAL
			)
		else:
			D.label(c, str(row.reason), D.SMALL, D.GOLD)
		_commission_switch(g, c, row)
		return
	# How long it would take with each team size: three figures that wrap between, not within.
	var timing = D.flow(c)
	timing.add_theme_constant_override("h_separation", 12)
	D.tinted_icon(timing, "time", 16, D.MUTED)
	for preview: Dictionary in row.previews:
		D.label(
			timing, "%d 支 %d 天" % [int(preview.staff), int(preview.days)], D.CAPTION, D.MUTED, false
		)
	var tech: String = str(row.id)
	var pick = D.button(
		c,
		"选这个课题",
		func(): g.act("research_allocate", {"tech": tech, "staff": int(count.value)}),
		"需要前置技术：" + "、".join(PackedStringArray(missing)) if blocked else "按上面的团队人数开工",
		"Card_" + tech,
		"primary"
	)
	D.font_size(pick, D.SMALL)
	pick.custom_minimum_size.y = 36
	pick.disabled = blocked


## What a topic opens up: the facilities it unlocks, with their icons, named as the rules name them.
static func _unlocks(g, c, tech: String, names: Array) -> void:
	if names.is_empty():
		return
	var line = D.row(c)
	line.add_theme_constant_override("separation", 6)
	for kind: String in g.sim.config.buildings:
		if str(g.sim.config.buildings[kind].get("requires_tech", "")) == tech:
			var picture: TextureRect = D.building_icon(
				line, kind, Labels.icon_key(g.sim.config, kind), 30
			)
			picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text: Label = D.label(
		line, "解锁：" + "、".join(PackedStringArray(names)), D.CAPTION, D.tone("accent_2")
	)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Commissioned research: a two-step switch on a project its own team is working on, each step
## with its cost a day and the days it saves.
static func _commission_switch(g, c, row: Dictionary) -> void:
	var quotes: Array = row.get("commission_quotes", [])
	if quotes.is_empty():
		return
	D.label(c, "外部实验室委托", D.CAPTION, D.MUTED, false)
	var line = D.flow(c)
	line.add_theme_constant_override("h_separation", 6)
	var tech: String = str(row.id)
	var current: int = int(row.commission)
	var off = D.button(
		line,
		"关",
		func(): g.act("research_commission", {"tech": tech, "level": 0}),
		"外部实验室按研究点收费，只加在有自己团队的课题上",
		"Commission_%s_0" % tech,
		"chip_on" if current == 0 else "chip"
	)
	_switch_look(off, current == 0)
	var saved: PackedStringArray = []
	for quote: Dictionary in quotes:
		var level: int = int(quote.level)
		var button = D.button(
			line,
			"%d 级 · ¥%.0f/日" % [level, float(quote.cost)],
			func(): g.act("research_commission", {"tech": tech, "level": level}),
			"按研究点付费，从公共现金按日支付（计入投资）；现金不够的那天暂停，不会欠债",
			"Commission_%s_%d" % [tech, level],
			"chip_on" if current == level else "chip"
		)
		_switch_look(button, current == level)
		saved.append("%d 级 %d 天" % [level, int(quote.days_saved)])
	D.label(c, "预计提前：" + "，".join(saved), D.CAPTION, D.MUTED)
	if current > 0:
		var state: String = str(quotes[mini(current, quotes.size()) - 1].state)
		if state == "no_team":
			D.label(c, "团队没有在做这个课题，委托暂停", D.CAPTION, D.GOLD)
		elif state == "no_cash":
			D.label(c, "现金不够今天的委托（先留足日常开支），委托暂停", D.CAPTION, D.GOLD)


## A step of the commission switch: a toggle whose chosen state shows as pressed.
static func _switch_look(button: Button, on: bool) -> void:
	button.toggle_mode = true
	button.button_pressed = on
	D.font_size(button, D.CAPTION)
	button.custom_minimum_size.y = 30


## Paid outside work for the labs, once the academic network exists.
static func _research_contract(g, b, v: Dictionary):
	var needed: String = str(g.sim.progression.research.contract_tech)
	if not g.sim.state.research.completed.has(needed):
		return
	var contract: Dictionary = v.contract
	var c = D.card(b)
	D.label(c, "科研委托", D.SECTION, D.TEAL)
	D.label(
		c,
		(
			"占用一个实验台和研究团队，按研究量收取外部付款（每点 ¥ %.0f）。分配 %d 支 / 实投 %d 支 · 累计收入 ¥ %.0f"
			% [
				float(g.sim.progression.research.contract_point_price),
				int(contract.staff),
				int(contract.effective),
				float(contract.earned)
			]
		),
		D.BODY
	)
	var line = D.row(c)
	var count = D.spin(line, "ContractStaff", 0, maxi(10, int(v.total)), 1, int(contract.staff))
	D.button(line, "应用委托人数", func(): g.act("research_contract", {"staff": int(count.value)}))


## What each direction has finished, with its colour, so the page also reads as a record.
static func _finished(b, columns: Array) -> void:
	for column: Dictionary in columns:
		if column.finished.is_empty():
			continue
		var line = D.row(b)
		line.add_theme_constant_override("separation", 8)
		var mark: Label = D.tag(line, "✓ 已完成", D.tone("good"))
		mark.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var text: Label = D.label(
			line,
			(
				"%s %d / %d：%s"
				% [
					column.name,
					column.finished.size(),
					int(column.pool),
					"、".join(PackedStringArray(column.finished))
				]
			),
			D.SMALL,
			D.MUTED
		)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
