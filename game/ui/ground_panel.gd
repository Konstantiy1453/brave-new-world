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
static func coordinate_text(lat: float, lon: float) -> String:
	return (
		"%s %.2f° · %s %.2f°"
		% ["北纬" if lat >= 0.0 else "南纬", absf(lat), "东经" if lon >= 0.0 else "西经", absf(lon)]
	)


## What the game says about the picked ground, priced for the kind of town that would be founded:
## the one chosen in the naming dialog while it is open, else the default for the next town (the
## capital lives where people settle; a later town starts as a frontier town, as its dialog does).
static func view(g) -> Dictionary:
	return g.sim.Placement.view(
		g.sim, float(g.ground.lat), float(g.ground.lon), int(g.ground_from), kind(g)
	)


static func kind(g) -> String:
	if g.sim.state.settlements.is_empty():
		return Keys.SITE_RESIDENTIAL
	if bool(g.naming_ground):
		return str(g.naming_kind)
	return Keys.SITE_FRONTIER


static func panel(g, b: Control) -> void:
	var report: Dictionary = view(g)
	D.label(b, "GROUND  /  自选地点", 13, D.TEAL)
	var where: Label = D.label(b, coordinate_text(float(report.lat), float(report.lon)), 24, D.INK)
	D.named(where, "GroundCoordinates")
	var precision: float = float(g.ground.get("precision", 0.0))
	var km: float = deg_to_rad(precision) * float(g.sim.geo.get("radius_km", 6371.0))
	D.label(
		b,
		(
			"点选精度 ±%.2f°（约 %.0f km）· 在%s上选定"
			% [precision, km, "球面" if str(g.ground.get("view", "")) == "planet" else "平铺地图"]
		),
		14,
		D.MUTED
	)
	if not bool(report.land):
		D.label(b, "海面", 18, D.INK)
	else:
		var cover: String = str(COVER_NAMES.get(str(report.biome), str(report.biome)))
		var terrain: Label = D.label(b, "地表：%s · 地点类型：%s" % [cover, report.terrain], 16, D.INK)
		D.named(terrain, "GroundTerrain")
		D.label(
			b,
			(
				"海拔 %.0f m · 地势%s（周围高差 %.0f m）"
				% [float(report.elevation), report.slope_word, float(report.relief)]
			),
			16,
			D.INK
		)
		D.label(b, "淡水：" + _water_words(report), 15, D.INK)
		D.label(b, "海岸：" + ("靠海，可以建码头、走海运" if bool(report.coast) else "内陆，货物要走陆路"), 15, D.INK)
		D.label(b, "矿产信号（轨道观测）：" + _signal_words(report.signals), 15, D.INK)
		_prospecting_lines(g, b, report)
		D.label(
			b, "可建设地块约 %d 块 · %.1f°C" % [int(report.slots), float(report.temperature)], 15, D.MUTED
		)
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


## Prospecting one resource at this point (prospecting.gd): the anomaly that covers it and what
## is known of it, or an orbital observation to order; the next step for what is known.
static func _prospecting_lines(g, b: Control, report: Dictionary) -> void:
	var sim: RefCounted = g.sim
	var lat: float = float(report.lat)
	var lon: float = float(report.lon)
	var here: Array = sim.Prospecting.anomalies_at(sim, lat, lon)
	D.label(b, "勘探（每次选一种矿产）", 14, D.TEAL)
	for resource: String in SIGNAL_NAMES:
		var line: HBoxContainer = D.row(b)
		var known: Dictionary = {}
		for entry: Dictionary in here:
			if str(entry.resource) == resource and known.is_empty():
				known = entry
		var words: String = "%s：" % SIGNAL_NAMES[resource]
		var step: String = "orbital"
		if known.is_empty():
			words += "未观测"
		elif str(known.stage) == "orbital":
			words += "轨道异常区（约 ±%.0f km），位置还很粗" % _km(sim, float(known.zone))
			step = "field"
		elif str(known.stage) == "field":
			words += (
				"实地勘察：%s，约 ±%.0f km"
				% [
					"矿脉" if str(known.get("kind", "")) == "vein" else "矿囊",
					_km(sim, float(known.zone))
				]
			)
			step = "drill"
		else:
			words += (
				"钻探：品位 %.2f · %s · 剩余约 %s"
				% [
					float(known.grade),
					"浅层" if int(known.depth) == 0 else "深层",
					Labels.t(float(known.reserve))
				]
			)
			step = ""
		var text: Label = D.label(line, words, 14, D.INK if known.is_empty() else D.TEAL, true)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			str(quote.refusal),
			"Prospect_%s_%s" % [resource, step],
			"chip"
		)
		button.disabled = str(quote.refusal) != ""
		D.font_size(button, 13)


static func _km(sim: RefCounted, degrees: float) -> float:
	return deg_to_rad(degrees) * float(sim.geo.get("radius_km", 6371.0))
