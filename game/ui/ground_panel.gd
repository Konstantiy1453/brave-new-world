extends RefCounted
## The ground the player picked on the globe or the flat map (1.10 free placement): where it is, what
## the ground there is (terrain, relief, fresh water, coast, mineral signals from orbit, room to build),
## how far the nearest town and road are, and whether a settlement can be founded there now, with the
## reason when not. For a later town: the departure town, the route, its days and the expedition's
## cost. The founding button acts on this point and nothing else. Reads `Placement.view`.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Keys = preload("res://simulation/keys.gd")

const SIGNAL_NAMES: Dictionary = {"ore": "铁", "copper": "铜", "crystal": "工业晶体"}
const LEVELS: Dictionary = {
	"signal": "轨道粗测",
	"scan": "轨道观测",
	"field": "实地勘察",
	"drilled": "钻探",
}
## The ground cover the maps draw (plates.gd `biome_at`).
const COVER_NAMES: Dictionary = {
	"forest": "森林",
	"grassland": "草地",
	"steppe": "干草原",
	"tundra": "苔原",
	"alpine": "高山",
	"desert": "荒漠",
	"ocean": "海洋",
}

## The coordinate in words: 北纬 21.25° · 西经 117.25°.
static var _cached: Dictionary = {}


static func coordinate_text(lat: float, lon: float) -> String:
	return (
		"%s %.2f° · %s %.2f°"
		% ["北纬" if lat >= 0.0 else "南纬", absf(lat), "东经" if lon >= 0.0 else "西经", absf(lon)]
	)


## What the game says about the picked ground, priced for the kind of town that would be founded:
## the one chosen in the naming dialog while it is open, else the default for the next town (the
## capital lives where people settle; a later town starts as a frontier town, as its dialog does).
## The full card (`Placement.preview`) is kept for the day, the cash and the choices it depends on.
static func view(g) -> Dictionary:
	var key: String = (
		"%.4f|%.4f|%d|%s|%d|%d|%d"
		% [
			float(g.ground.lat),
			float(g.ground.lon),
			int(g.ground_from),
			kind(g),
			int(g.sim.state.day),
			int(float(g.sim.state.cash)),
			g.sim.state.settlements.size(),
		]
	)
	if str(_cached.get("key", "")) != key:
		_cached = {
			"key": key,
			"report":
			g.sim.Placement.preview(
				g.sim, float(g.ground.lat), float(g.ground.lon), int(g.ground_from), kind(g)
			),
		}
	return _cached.report


static func kind(g) -> String:
	if g.sim.state.settlements.is_empty():
		return Keys.SITE_RESIDENTIAL
	if bool(g.naming_ground):
		return str(g.naming_kind)
	return Keys.SITE_FRONTIER


## The one site card (1.11): for the capital and every later town, for a recommended site's point
## and for any other ground alike. Where it is, the ground, building costs, water, the coast and its
## fishery, buildable plots by type, each mineral's estimate with the survey behind it, farmland and
## what a farm grows, what the first town here can sell first, the neighbourhood, and whether a
## town can be founded here now.
static func panel(g, b: Control) -> void:
	var report: Dictionary = view(g)
	var marker: int = int(g.ground.get("marker", -1))
	var head: HBoxContainer = D.row(b)
	var caption: String = "GROUND  /  自选地点"
	if marker >= 0 and marker < g.sim.state.world.regions.size():
		caption = "推荐地点  /  " + Labels.site_label(g.sim.state.world.regions[marker])
	var tag: Label = D.label(head, caption, 13, D.TEAL, false)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_toggle(g, head)
	var where: Label = D.label(b, coordinate_text(float(report.lat), float(report.lon)), 24, D.INK)
	D.named(where, "GroundCoordinates")
	var precision: float = float(g.ground.get("precision", 0.0))
	var km: float = deg_to_rad(precision) * float(g.sim.geo.get("radius_km", 6371.0))
	D.label(
		b,
		(
			"推荐地点的坐标；规则与任何一块地相同"
			if marker >= 0
			else (
				"点选精度 ±%.2f°（约 %.0f km）· 在%s上选定"
				% [precision, km, "球面" if str(g.ground.get("view", "")) == "planet" else "平铺地图"]
			)
		),
		14,
		D.MUTED
	)
	if not bool(report.land):
		D.label(b, "海面", 18, D.INK)
	else:
		_ground_lines(g, b, report)
	D.label(b, _distance_words(report), 15, D.MUTED)
	if not bool(report.first) and str(report.refusal) == "" or not report.route.is_empty():
		_expedition_lines(g, b, report)
	var refusal: String = str(report.refusal)
	var verdict: Label
	if refusal == "":
		verdict = D.label(b, "✓ 可以在这里建立" + ("首府" if bool(report.first) else "据点"), 17, D.TEAL)
	else:
		verdict = D.label(b, "✗ " + refusal, 17, D.RED)
	D.named(verdict, "GroundVerdict")


## The ground's lines on the card, in the order a founder reads them.
static func _ground_lines(g, b: Control, report: Dictionary) -> void:
	var cover: String = str(COVER_NAMES.get(str(report.biome), str(report.biome)))
	var terrain: Label = D.label(b, "地表：%s · 地点类型：%s" % [cover, report.terrain], 16, D.INK)
	D.named(terrain, "GroundTerrain")
	var building: Dictionary = report.get("building", {})
	var cost_words: String = ""
	if not building.is_empty():
		cost_words = " · 建设费用 ×%.2f" % float(building.cost_factor)
	var elevation: Label = D.label(
		b,
		(
			"海拔 %.0f m · 地势%s（周围高差 %.0f m）%s · %.1f°C"
			% [
				float(report.elevation),
				report.slope_word,
				float(report.relief),
				cost_words,
				float(report.temperature)
			]
		),
		15,
		D.INK
	)
	D.named(elevation, "GroundElevation")
	var water: String = "淡水：" + _water_words(report)
	if report.has("water_supply"):
		water += " · 一座净水泵站约供水 %.0f" % float(report.water_supply.pump)
	D.label(b, water, 15, D.INK)
	var fishing: Dictionary = report.get("fishing", {})
	var coast: String = "海岸：内陆，货物要走陆路"
	if bool(report.coast):
		coast = "海岸：靠海，可以建小型码头、走海运"
		if not fishing.is_empty():
			coast += (
				" · 渔场%s：一座小型码头每天约 %s 渔获" % [str(fishing.word), Labels.t(float(fishing.catch))]
			)
	var coast_line: Label = D.label(b, coast, 15, D.INK)
	D.named(coast_line, "GroundCoast")
	if not report.has("has_site"):
		D.label(b, "矿产信号（轨道观测）：" + _signal_words(report.signals), 15, D.INK)
		return
	_plot_lines(g, b, report)
	_mineral_lines(g, b, report)
	_plan_lines(g, b, report)


## Buildable plots by type and what a farm would grow on the best field.
static func _plot_lines(_g, b: Control, report: Dictionary) -> void:
	var plots: Dictionary = report.plots
	var farming: Dictionary = report.farming
	var words: String = "可建设地块：城区 %d 块 · 农田 %d 块" % [int(plots.general), int(plots.farm)]
	var line: Label = D.label(b, words, 15, D.INK)
	D.named(line, "GroundPlots")
	if int(farming.plots) > 0:
		var farm: Label = (
			D
			. label(
				b,
				(
					"农业潜力：%s · 一座温室农场约 %s–%s/天（最好的一块地，气候系数 %.2f），够 %d 人吃"
					% [
						str(farming.word),
						Labels.t(float(farming.per_farm_low)),
						Labels.t(float(farming.per_farm_high)),
						float(farming.climate),
						int(farming.feeds),
					]
				),
				15,
				D.INK
			)
		)
		D.named(farm, "GroundFarming")
	else:
		D.label(b, "农业潜力：没有农田地块，只能靠进口、渔获或以后的水培温室", 15, D.MUTED)


## Each mineral: its estimate in tonnes and plots with the survey behind it, a scan that found
## nothing said so, and the next survey of that resource alone.
static func _mineral_lines(g, b: Control, report: Dictionary) -> void:
	var sim: RefCounted = g.sim
	var lat: float = float(report.lat)
	var lon: float = float(report.lon)
	var here: Array = sim.Prospecting.anomalies_at(sim, lat, lon)
	D.label(b, "矿产估计（每种矿产单独勘测，越细的勘测误差越小）", 14, D.TEAL)
	for resource: String in SIGNAL_NAMES:
		var mineral: Dictionary = report.minerals[resource]
		var line: HBoxContainer = D.row(b)
		var words: String = _mineral_words(mineral, str(SIGNAL_NAMES[resource]))
		var text: Label = D.label(
			line, words, 14, D.TEAL if str(mineral.level) != "signal" else D.INK, true
		)
		D.named(text, "Mineral_" + resource)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var known: Dictionary = {}
		for entry: Dictionary in here:
			if str(entry.resource) == resource and known.is_empty():
				known = entry
		var step: String = "orbital"
		if not known.is_empty():
			step = {"orbital": "field", "field": "drill"}.get(str(known.stage), "")
		if step == "":
			continue
		var quote: Dictionary = sim.Prospecting.quote(sim, step, lat, lon, int(known.get("id", 0)))
		var action: String = {"orbital": "轨道观测", "field": "实地勘察", "drill": "钻探"}[step]
		var id: int = int(known.get("id", 0))
		var button: Button = D.button(
			line,
			"%s · ¥%.0f · %d 天" % [action, float(quote.cost), int(quote.days)],
			func():
				if step == "orbital":
					g.act("prospect_observe", {"resource": resource, "lat": lat, "lon": lon})
				else:
					g.act("prospect_send", {"step": step, "id": id}),
			(
				str(quote.refusal)
				if str(quote.refusal) != ""
				else "只勘测%s，不涉及其他矿产" % SIGNAL_NAMES[resource]
			),
			"Prospect_%s_%s" % [resource, step],
			"chip"
		)
		button.disabled = str(quote.refusal) != ""
		D.font_size(button, 13)
	if int(report.plots.get("deep", 0)) > 0:
		D.label(b, "另有 %d 块深层矿床，要深层采矿技术才能开采" % int(report.plots.deep), 13, D.MUTED)


## One mineral in words: 「铁：轨道信号强 · 估计 9,000–25,000 t · 矿床地块 2–4 块（轨道粗测，±60%）」.
static func _mineral_words(mineral: Dictionary, name: String) -> String:
	var level: String = str(mineral.level)
	var source: String = str(LEVELS.get(level, level))
	if bool(mineral.none_detected):
		return "%s：本次轨道观测未探测到%s（第 %d 天的%s）" % [name, name, int(mineral.day), source]
	var reading: String = "轨道信号%s" % str(mineral.signal_word)
	if float(mineral.high) <= 0.0:
		return (
			"%s：%s · 地点范围内估计没有可开采的矿床（%s，±%.0f%%）"
			% [name, reading, source, float(mineral.band) * 100.0]
		)
	var plots: String = (
		"%d 块" % int(mineral.plots_low)
		if int(mineral.plots_low) == int(mineral.plots_high)
		else "%d–%d 块" % [int(mineral.plots_low), int(mineral.plots_high)]
	)
	var amount: String = (
		Labels.t(float(mineral.mid))
		if float(mineral.band) <= 0.0
		else "%s–%s" % [Labels.t(float(mineral.low)), Labels.t(float(mineral.high))]
	)
	var band: String = (
		"精确" if float(mineral.band) <= 0.0 else "±%.0f%%" % (float(mineral.band) * 100.0)
	)
	return "%s：%s · 估计 %s · 矿床地块 %s（%s，%s）" % [name, reading, amount, plots, source, band]


## What the first town here can sell first: each plan with what it needs, its first shipment and
## what that does for the charter's export goal; the best first.
static func _plan_lines(g, b: Control, report: Dictionary) -> void:
	var plans: Array = report.get("plans", [])
	D.label(b, "在这里先卖什么", 15, D.GOLD)
	if plans.is_empty():
		D.label(b, "这里看不到能马上出口的东西：没有矿床信号、农田太少、也不靠海。", 14, D.RED)
		return
	for plan: Dictionary in plans:
		var card: VBoxContainer = D.card(b)
		card.add_theme_constant_override("separation", 2)
		var title: Label = D.label(
			card,
			("★ " if bool(plan.best) else "") + str(plan.title),
			15,
			D.GOLD if bool(plan.best) else D.INK
		)
		D.named(title, "Plan_" + str(plan.key) + "_" + str(plan.good))
		var needs: PackedStringArray = []
		for need: Dictionary in plan.needs:
			var words: String = (
				"%s ¥%s（第 %d 天建成）"
				% [str(need.name), g.money(float(need.cost)), int(need.ready_day)]
			)
			if int(need.get("road_days", 0)) > 0:
				words += "，含矿区道路 %d 天" % int(need.road_days)
			needs.append(words)
		var landing: String = "；货运站、电站、水站随登陆运到" if bool(report.first) else ""
		D.label(
			card,
			"需要（首支工程队依次建设）：" + "；".join(needs) + landing + "；合计 ¥%s" % g.money(float(plan.cost)),
			13,
			D.MUTED
		)
		var first: String = (
			"首批：约第 %d 天，约 %s；全部建成后每天约 ¥%.0f"
			% [int(plan.first_day), Labels.t(float(plan.first_amount)), float(plan.per_day)]
		)
		D.label(card, first, 13, D.TEAL)
		if plan.has("goal"):
			var goal: Dictionary = plan.goal
			var line: Label = D.label(
				card,
				(
					"合同：第 %d 阶段出口目标还差 ¥%s，单靠这一项约第 %d 天达成（期限第 %d 天%s）；每批出口都计入目标"
					% [
						int(goal.stage),
						g.money(float(goal.left)),
						int(plan.goal_day),
						int(goal.deadline),
						"，会超期：要再加一项" if bool(plan.get("late", false)) else ""
					]
				),
				13,
				D.GOLD if bool(plan.get("late", false)) else D.INK
			)
			D.named(line, "PlanGoal_" + str(plan.key) + "_" + str(plan.good))
		D.label(card, str(plan.note), 12, D.MUTED)
		if bool(plan.get("uncertain", false)):
			D.label(card, "储量只是轨道粗测：先做一次轨道观测再决定更稳妥", 12, D.GOLD)


## Recommended sites on the maps: a filter that can also hide them all (the overlay is optional).
static func overlay_toggle(g, b: Control) -> void:
	var names: Array = []
	for row: Array in Labels.SITE_FILTERS:
		names.append(row[1])
	var picker: OptionButton = D.option(
		b,
		"SiteFilter",
		names,
		g.site_filter,
		func(id):
			g.site_filter = id
			g.map.set_marker_filter(Labels.SITE_FILTERS[id][0])
	)
	D.font_size(picker, 13)
	picker.tooltip_text = "推荐地点只是地图上的提示：任何一块合适的陆地都能点开、都能建"


## Before anything is picked: how picking works, and the recommended sites as a list.
static func intro(g, b: Control) -> void:
	var head: HBoxContainer = D.row(b)
	var title: Label = D.label(head, "选择地点", 22, D.INK, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_toggle(g, head)
	D.label(
		b,
		"在球面或平铺地图上点任意一块陆地，右侧会写出那里的地势、淡水、海岸、可建地块、矿产估计和先卖什么。带编号的圆点是推荐地点，规则和其他地面完全一样，可以在右上角隐藏。",
		15,
		D.MUTED
	)
	var names: Array = ["推荐地点列表…"]
	var ids: Array = [-1]
	for reg: Dictionary in g.sim.state.world.regions:
		if bool(reg.get("placed", false)) or not g.sim.settlement(int(reg.id)).is_empty():
			continue
		names.append(Labels.site_label(reg))
		ids.append(int(reg.id))
	var chooser: OptionButton = D.option(
		b,
		"RegionChooser",
		names,
		0,
		func(index: int):
			if index > 0:
				g.select_region(int(ids[index]))
	)
	D.font_size(chooser, 15)
	var cap: Dictionary = g.sim.Contract.cap_view(g.sim)
	D.label(
		b,
		(
			"据点上限：本阶段 %s 处（含首府），已建 %d 处"
			% ["不限" if bool(cap.unlimited) else str(int(cap.cap)), int(cap.used)]
		),
		14,
		D.TEAL
	)


static func _water_words(report: Dictionary) -> String:
	var words: PackedStringArray = []
	if bool(report.river):
		words.append("有河流")
	if bool(report.lake):
		words.append("附近有湖")
	var water: float = float(report.water)
	words.append(
		"水源%s（%.2f）" % ["充足" if water >= 0.55 else ("一般" if water >= 0.3 else "偏少"), water]
	)
	return "，".join(words)


static func _signal_words(signals: Dictionary) -> String:
	var words: PackedStringArray = []
	for good: String in SIGNAL_NAMES:
		var strength: float = float(signals.get(good, 0.0))
		var word: String = "无"
		if strength >= 0.6:
			word = "强"
		elif strength >= 0.3:
			word = "中"
		elif strength > 0.05:
			word = "弱"
		words.append("%s %s" % [SIGNAL_NAMES[good], word])
	return " · ".join(words)


static func _distance_words(report: Dictionary) -> String:
	var nearest: Dictionary = report.nearest_town
	if nearest.is_empty():
		return "周边：还没有据点和公路"
	var words: String = "周边：最近的据点「%s」%.0f km" % [nearest.name, float(nearest.km)]
	if float(report.nearest_road_km) >= 0.0:
		words += "；最近的公路 %.0f km" % float(report.nearest_road_km)
	else:
		words += "；还没有公路"
	return words


## The departure town (changeable), the route, its length and days, and the expedition's cost.
static func _expedition_lines(g, b: Control, report: Dictionary) -> void:
	var towns: Array = []
	var names: Array = ["最近的可出发据点"]
	for s: Dictionary in g.sim.state.settlements:
		if int(s.arrival) > 0:
			continue
		towns.append(int(s.region))
		names.append(str(s.name))
	var chosen: int = towns.find(int(g.ground_from)) + 1
	var line: HBoxContainer = D.row(b)
	D.label(line, "出发据点", 15, D.MUTED, false)
	var picker: OptionButton = D.option(
		line,
		"GroundDeparture",
		names,
		chosen,
		func(index: int):
			g.ground_from = -1 if index <= 0 else int(towns[index - 1])
			g.refresh_sidebar()
	)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.font_size(picker, 15)
	var route: Dictionary = report.route
	if route.is_empty():
		return
	if not bool(route.reachable):
		return
	var variant: String = str(route.get("variant", "valley"))
	var road_name: String = str(g.sim.config.roads.get(variant, {}).get("name", variant))
	var words: String = (
		"从「%s」出发：%s · %.0f km · 单程 %d 天 · 远征费用 ¥ %.0f（%s）"
		% [
			str(report.get("from_name", "")),
			road_name,
			float(route.get("distance", 0.0)),
			int(route.get("days", 0)),
			float(report.cost),
			str(Labels.SITE_KIND_NAMES.get(str(report.kind), str(report.kind))),
		]
	)
	var route_line: Label = D.label(b, words, 15, D.TEAL)
	D.named(route_line, "GroundRoute")


## The founding button for the picked ground, and a way back to the recommended sites.
static func actions(g, b: Control) -> void:
	var report: Dictionary = view(g)
	var line: HBoxContainer = D.row(b)
	var found: Button = D.button(
		line,
		"在这里建立首府" if bool(report.first) else "派遣远征队到这里",
		func(): g.ask_ground_name(),
		str(report.refusal) if str(report.refusal) != "" else "按此处的坐标建立据点",
		"SettleGroundButton",
		"primary"
	)
	found.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	found.disabled = str(report.refusal) != ""
	var back: Button = D.button(line, "取消选择", func(): g.clear_ground(), "", "ClearGround")
	D.font_size(back, 14)


## The naming dialog's lines for a settlement founded on picked ground.
static func naming_lines(g, b: Control) -> void:
	var report: Dictionary = view(g)
	var place: String = "自选地点 · " + coordinate_text(float(report.lat), float(report.lon))
	var heading: Label = D.label(b, place, 20, D.TEAL)
	D.named(heading, "GroundNamingCoordinates")
	var cover: String = str(COVER_NAMES.get(str(report.biome), str(report.biome)))
	D.label(
		b,
		"%s · %s · %s" % [cover, str(report.terrain), "靠海" if bool(report.coast) else "内陆"],
		16,
		D.MUTED
	)
	if not bool(report.first) and not report.route.is_empty() and bool(report.route.reachable):
		(
			D
			. label(
				b,
				(
					"从「%s」出发，单程 %d 天，远征费用 ¥ %.0f（%s）"
					% [
						str(report.get("from_name", "")),
						int(report.route.days),
						float(report.cost),
						str(Labels.SITE_KIND_NAMES.get(str(report.kind), str(report.kind))),
					]
				),
				16,
				D.MUTED
			)
		)


## Opens the naming dialog for the picked ground, unless founding there is refused right now.
static func ask_name(g) -> void:
	if g.ground.is_empty():
		return
	g.naming_kind = kind(g)
	var refusal: String = str(view(g).refusal)
	if refusal != "":
		g.toast(refusal)
		return
	g.naming_ground = true
	g.naming_again = false
	g.open_page("name_site")
	var edit: LineEdit = g.modal_box.find_child("SiteNameEdit", true, false)
	edit.text = ""
	edit.grab_focus.call_deferred()


## Founds the settlement on the picked ground under the typed name; on success the new site is the
## selection, as any site is. Returns the refusal or "".
static func found(g, typed: String) -> String:
	var regions: int = g.sim.state.world.regions.size()
	var error: String = g.act(
		"settle_at",
		{
			"lat": float(g.ground.lat),
			"lon": float(g.ground.lon),
			"from": g.ground_from,
			"name": typed,
			"kind": g.naming_kind
		}
	)
	if error == "" and g.sim.state.world.regions.size() > regions:
		g.naming_ground = false
		g.ground = {}
		g.map.set_ground({})
		g.selected = regions
		g.map.selected_region = regions
		g.map.sync_state(g.sim.state)
	return error


static func _km(sim: RefCounted, degrees: float) -> float:
	return deg_to_rad(degrees) * float(sim.geo.get("radius_km", 6371.0))
