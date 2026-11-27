extends PanelContainer
## The two meters beside the map (1.11), in the slot the distrust gauge had:
## - 公司评级: the company's rating of the contractor, a letter A-D from distrust (bands in
##   progression.json `company`), with the day's change and the company stage; the number of
##   distrust, its sources and the bands are on hover. A click opens the company page.
## - 民心: the colonists' mood, the population-weighted mean of the settlements' appeal shown 0-100
##   (population.json `morale`). A click opens the population page, where the services budget is.

const D = preload("res://ui/design.gd")
const Company = preload("res://simulation/company.gd")
const Population = preload("res://simulation/population.gd")
const AnnualReport = preload("res://simulation/annual_report.gd")
const STAGE_NAMES: Dictionary = {
	"normal": "正常",
	"warning": "关注",
	"review": "审查",
	"intervention": "介入",
	"recovery": "恢复",
}
const RATING_COLORS: Dictionary = {
	"A": Color("62c7c5"),
	"B": Color("c9a24f"),
	"C": Color("d0793f"),
	"D": Color("e46f68"),
}

var game: Node
var rating_label: Label
var delta_label: Label
var stage_label: Label
var morale_box: VBoxContainer
var morale_label: Label
var morale_bar: ProgressBar
var rating: String = ""
var morale: float = -1.0
var ship_box: VBoxContainer
var ship_label: Label


func setup(owner_game: Node) -> void:
	game = owner_game
	name = "DistrustGauge"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", D.box(Color(0.07, 0.14, 0.2, 0.92), Color("304756"), 8))
	var column: VBoxContainer = D.col(self)
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centered(D.label(column, "公司评级", 13, D.MUTED, false))
	rating_label = _centered(D.label(column, "A", 30, D.INK, false))
	rating_label.name = "CompanyRating"
	delta_label = _centered(D.label(column, "", 13, D.TEAL, false))
	stage_label = _centered(D.label(column, "", 14, D.MUTED, false))
	D.rule(column)
	morale_box = D.col(column)
	morale_box.name = "Morale"
	morale_box.add_theme_constant_override("separation", 2)
	morale_box.mouse_filter = Control.MOUSE_FILTER_STOP
	morale_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	morale_box.gui_input.connect(_morale_input)
	_centered(D.label(morale_box, "民心", 13, D.MUTED, false))
	morale_label = _centered(D.label(morale_box, "50", 22, D.INK, false))
	morale_label.name = "MoraleValue"
	morale_bar = D.progress(morale_box, 0.5, D.TEAL, 6)
	# The days to the company's annual ship (1.11 D); a click opens the annual report.
	D.rule(column)
	ship_box = D.col(column)
	ship_box.name = "ShipDays"
	ship_box.mouse_filter = Control.MOUSE_FILTER_STOP
	ship_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ship_box.gui_input.connect(_ship_input)
	_centered(D.label(ship_box, "公司船", 13, D.MUTED, false))
	ship_label = _centered(D.label(ship_box, "", 16, D.INK, false))
	custom_minimum_size.x = 68


func _centered(caption: Label) -> Label:
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return caption


func _gui_input(event: InputEvent) -> void:
	if _clicked(event):
		game.open_page("company")


func _ship_input(event: InputEvent) -> void:
	if _clicked(event):
		game.open_page("annual_report")


func _morale_input(event: InputEvent) -> void:
	if _clicked(event):
		game.open_page("population")


func _clicked(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	)


## Called on every refresh of the top of the screen.
func show_pair(sim: RefCounted) -> void:
	var company: Dictionary = sim.state.get("company", {})
	var value: float = float(company.get("distrust", 0.0))
	var delta: float = float(company.get("delta", 0.0))
	var stage: String = str(company.get("stage", "normal"))
	var letter: String = Company.rating(sim)
	if letter != rating:
		rating = letter
		rating_label.text = letter
		rating_label.add_theme_color_override("font_color", RATING_COLORS.get(letter, D.INK))
	delta_label.text = "%+.2f /日" % delta
	delta_label.add_theme_color_override(
		"font_color", D.RED if delta > 0.0 else (D.TEAL if delta < 0.0 else D.MUTED)
	)
	var words: String = "首年豁免" if Company.first_year_exempt(sim) else str(STAGE_NAMES.get(stage, stage))
	var left: int = int(company.get("deadline", -1)) - int(sim.state.get("day", 0))
	if int(company.get("deadline", -1)) >= 0 and left >= 0:
		words += " %d天" % left
	stage_label.text = words
	stage_label.add_theme_color_override(
		"font_color", D.RED if stage in ["review", "intervention"] else D.MUTED
	)
	tooltip_text = _explain(sim, company, value, words)
	var mood: float = Population.morale(sim)
	_show_ship(sim)
	if not is_equal_approx(mood, morale):
		morale = mood
		morale_label.text = "%.0f" % mood
		morale_bar.value = mood / 100.0
		morale_box.tooltip_text = _explain_morale(sim, mood)


func _explain(sim: RefCounted, company: Dictionary, value: float, words: String) -> String:
	var cfg: Dictionary = sim.progression.company
	var lines: PackedStringArray = [
		"公司评级 %s · 不信任 %.1f / 100 · %s" % [rating, value, words],
		(
			"A：不信任低于 %.0f · B：低于 %.0f · C：低于 %.0f · D：%.0f 及以上"
			% [
				float(cfg.get("rating_a_below", 20.0)),
				float(cfg.review_threshold),
				float(cfg.intervention_threshold),
				float(cfg.intervention_threshold)
			]
		),
	]
	for source: Variant in company.get("sources", {}).values():
		if float(source.get("rate", 0.0)) > 0.0:
			lines.append("%+.2f /日 · %s" % [float(source.rate), str(source.reason)])
	if Company.first_year_exempt(sim):
		lines.append("从第二年一月一日起，公司开始计入不信任。")
	elif lines.size() == 2:
		lines.append("现在没有履约风险，不信任每天慢慢回落。")
	lines.append("点击查看公司关系页。")
	return "\n".join(lines)


func _explain_morale(sim: RefCounted, mood: float) -> String:
	var level: int = int(sim.state.get("policy", {}).get("services", 0))
	return (
		"\n"
		. join(
			[
				"民心 %.0f / 100：各据点吸引力按人口加权的平均。" % mood,
				"公共服务预算是提高民心的手段（现在 %s）。" % ("关" if level == 0 else "%d 级" % level),
				"点击查看人口与移民页。",
			]
		)
	)


func _show_ship(sim: RefCounted) -> void:
	var pending: bool = not sim.state.get("annual", {}).get("pending", {}).is_empty()
	var days: int = AnnualReport.days_to_ship(sim)
	var text: String = "待签" if pending else ("—" if days < 0 else "%d日" % days)
	if ship_label.text != text:
		ship_label.text = text
		ship_label.add_theme_color_override("font_color", D.GOLD if pending else D.INK)
	ship_box.tooltip_text = (
		"公司年度船已到，年度报告待签署。点击打开。" if pending else "距下一艘公司年度船抵达还有 %d 日；船到时提交年度报告。点击查看。" % maxi(0, days)
	)
