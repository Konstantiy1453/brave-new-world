extends RefCounted
## The colony table in the top bar (split from main.gd in 1.11): one small cell per total, with its
## change a day, built once into the main scene `g` (`top_stats`, `top_cells`) and refreshed with it.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Stats = preload("res://simulation/stats.gd")
const Contract = preload("res://simulation/contract.gd")

## Days whose mean is the change shown after each amount.
const DAILY_WINDOW: int = 7
const MONTH_DAYS: float = 30.0
const TOP_CELLS: Array = [
	["money", "¥", "公共资金"],
	["labour", "crew", "劳动力"],
	["places", "据", "据点"],
	["food", "food", "食品"],
	["power", "power", "电力"],
	["water", "water", "水"],
	["ore", "ore", "铁矿"],
	["copper", "copper", "铜矿"],
	["crystal", "crystal", "工业晶体"],
	["materials", "materials", "建材"],
	["parts", "parts", "部件"],
	["components", "components", "电子元件"],
]
const TOP_GOODS: Array[String] = [
	"food", "ore", "copper", "crystal", "materials", "parts", "components"
]


## Colony totals with their change over a month, one small cell each: icons where there are icons.
static func build_table(g, parent: Control) -> void:
	var top_stats := GridContainer.new()
	g.top_stats = top_stats
	top_stats.name = "TopStats"
	top_stats.columns = 6
	top_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_stats.add_theme_constant_override("h_separation", 10)
	top_stats.add_theme_constant_override("v_separation", 6)
	parent.add_child(top_stats)
	for row: Array in TOP_CELLS:
		var cell := HBoxContainer.new()
		cell.name = "Top_" + str(row[0])
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_stats.add_child(cell)
		if ResourceLoader.exists("res://assets/icons/%s.svg" % str(row[1])):
			var mark: TextureRect = D.icon(cell, str(row[1]), 20)
			# Iron, copper and crystal in their map colours, so the three read apart.
			mark.self_modulate = Labels.GOOD_COLORS.get(str(row[0]), Color.WHITE)
		else:
			D.label(cell, str(row[1]), 15, D.GOLD, false)
		var value: Label = D.label(cell, "", 16, D.INK, false)
		var delta: Label = D.label(cell, "", 13, D.TEAL, false)
		g.top_cells[str(row[0])] = {"cell": cell, "value": value, "delta": delta}


## Engineering crews in every town (1.10), apart from the labour force.
static func crew_count(state: Dictionary) -> int:
	var total: int = 0
	for s: Dictionary in state.get("settlements", []):
		total += int(s.get("crew", 0))
	return total


## Colony totals and what the last month did to them, scaled up while the colony is younger than that.
## Returns the month's window for the advisor.
static func refresh(g) -> Dictionary:
	var sim: RefCounted = g.sim
	var state: Dictionary = sim.state
	var window: Dictionary = sim.stats_window(int(MONTH_DAYS))
	# The figure after each amount is its change a day: the mean of the last week's days.
	var week: Dictionary = sim.stats_window(DAILY_WINDOW)
	var per_day: float = 1.0 / maxi(1, int(week.days))
	var income: float = 0.0
	var expense: float = 0.0
	for key: String in window.income:
		income += float(window.income[key])
	for key: String in window.expense:
		expense += float(window.expense[key])
	var cover_line: String = Labels.cover_text(sim.cover_view())
	var net_per_day: float = float(sim.summary().operating_average)
	_set_cell(
		g,
		"money",
		float(state.cash),
		net_per_day,
		(
			(
				"公共资金 ¥ %.0f\n后面的数字是每日经营结余（近 7 日平均）¥ %+.0f/日。\n近 30 日经营收入 ¥ %.0f，支出 ¥ %.0f；建设和融资不计入。"
				% [float(state.cash), net_per_day, income, expense]
			)
			+ ("" if cover_line == "" else "\n" + cover_line)
		)
	)
	var people: int = 0
	var employed: int = 0
	var children: int = 0
	var power: float = 0.0
	var power_used: float = 0.0
	var water: float = 0.0
	var water_used: float = 0.0
	var stock: Dictionary = {}
	var places: PackedStringArray = []
	for s: Dictionary in state.settlements:
		people += int(s.population)
		employed += int(s.get("employed", 0))
		children += int(s.get("children", 0))
		power += float(s.power_supply)
		power_used += float(s.power_demand)
		water += float(s.water_supply)
		water_used += float(s.water_demand)
		places.append(
			(
				"%s：电 %.0f/%.0f · 水 %.0f/%.0f"
				% [s.name, s.power_supply, s.power_demand, s.water_supply, s.water_demand]
			)
		)
		for good: String in TOP_GOODS:
			stock[good] = float(stock.get(good, 0.0)) + float(s.stock.get(good, 0.0))
	var labour: int = Stats.labour(state)
	_set_cell(
		g,
		"labour",
		labour,
		Stats.labour_change(state, DAILY_WINDOW),
		(
			(
				"劳动力 %d：职工和研究团队；另有工程队 %d 支（施工、维修、外勤）\n"
				+ "人口 %d · 就业 %d · 未成年 %d\n后面的数字是每日变化（近 7 日平均）。"
			)
			% [labour, crew_count(state), people, employed, children]
		)
	)
	var cap: Dictionary = Contract.cap_view(sim)
	_set_cell_text(
		g,
		"places",
		"%d / %s" % [int(cap.used), "不限" if bool(cap.unlimited) else str(int(cap.cap))],
		"",
		0.0,
		"已建立的据点（含首府）/ 本阶段合同允许的上限：第一阶段 2 处，第二阶段 3 处，第三阶段 5 处，之后不限"
	)
	var utility_note: String = "\n电和水不能储存：第一个数是全部据点的供给，后面是供给减需求。\n"
	_set_cell_flow(g, "power", power, power - power_used, "电力" + utility_note + "\n".join(places))
	_set_cell_flow(g, "water", water, water - water_used, "水" + utility_note + "\n".join(places))
	for good: String in TOP_GOODS:
		var flows: Array = week.goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
		var change: float = (
			float(flows[Stats.PRODUCED])
			+ float(flows[Stats.IMPORTED])
			- float(flows[Stats.CONSUMED])
			- float(flows[Stats.EXPORTED])
		)
		var month: Array = window.goods.get(good, [0.0, 0.0, 0.0, 0.0, 0.0])
		_set_cell(
			g,
			good,
			Labels.tonnes(float(stock.get(good, 0.0))),
			Labels.tonnes(change * per_day),
			(
				Labels.flow_text(
					str(Labels.RESOURCE_NAMES[good]), float(stock.get(good, 0.0)), month
				)
				+ "\n后面的数字是每日变化（近 7 日平均，吨）。"
			)
		)
	return window


static func _set_cell(g, key: String, value: float, change: float, hint: String) -> void:
	var sign_text: String = "+" if change >= 0.0 else ""
	_set_cell_text(
		g, key, Labels.amount_text(value), sign_text + Labels.amount_text(change), change, hint
	)


## Power and water: a rate, not a stock, so the sign is the surplus and red means somebody is short.
static func _set_cell_flow(g, key: String, supply: float, surplus: float, hint: String) -> void:
	var sign_text: String = "+" if surplus >= 0.0 else ""
	_set_cell_text(
		g, key, Labels.compact(supply), sign_text + Labels.compact(surplus), surplus, hint
	)


static func _set_cell_text(
	g, key: String, value: String, change: String, amount: float, hint: String
) -> void:
	var cell: Dictionary = g.top_cells[key]
	if cell.value.text != value:
		cell.value.text = value
	if cell.delta.text != change:
		cell.delta.text = change
		cell.delta.add_theme_color_override("font_color", D.TEAL if amount >= 0.0 else D.RED)
	cell.cell.tooltip_text = hint
