extends PanelContainer
## The company's distrust as a standing gauge beside the map: where it is, where each stage of the
## company process begins, and how fast it is moving today. Click it to open the company page.

const D = preload("res://ui/design.gd")
const BAR_WIDTH: float = 16.0
const BAR_HEIGHT: int = 170
const STAGE_NAMES: Dictionary = {
	"normal": "正常",
	"warning": "关注",
	"review": "审查",
	"intervention": "介入",
	"recovery": "恢复",
}

var game: Node
var value_label: Label
var delta_label: Label
var stage_label: Label
var bar: Control
var distrust: float = 0.0
var marks: Array = []


func setup(owner_game: Node) -> void:
	game = owner_game
	name = "DistrustGauge"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", D.box(Color(0.07, 0.14, 0.2, 0.92), Color("304756"), 8))
	var column: VBoxContainer = D.col(self)
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = D.label(column, "不信任", 13, D.MUTED, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label = D.label(column, "0", 22, D.INK, false)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar = Control.new()
	bar.custom_minimum_size = Vector2(52, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	column.add_child(bar)
	delta_label = D.label(column, "", 13, D.TEAL, false)
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label = D.label(column, "", 14, D.MUTED, false)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		game.open_page("company")


## Called with the company state and the thresholds of the current difficulty.
func show_state(company: Dictionary, warning: float, review: float, intervention: float) -> void:
	var value: float = float(company.get("distrust", 0.0))
	var delta: float = float(company.get("delta", 0.0))
	var stage: String = str(company.get("stage", "normal"))
	var text: String = "%.0f" % value
	if value_label.text != text:
		value_label.text = text
	delta_label.text = "%+.2f /日" % delta
	delta_label.add_theme_color_override(
		"font_color", D.RED if delta > 0.0 else (D.TEAL if delta < 0.0 else D.MUTED)
	)
	var words: String = str(STAGE_NAMES.get(stage, stage))
	var left: int = int(company.get("deadline", -1)) - int(game.sim.state.get("day", 0))
	if int(company.get("deadline", -1)) >= 0 and left >= 0:
		words += " %d天" % left
	stage_label.text = words
	stage_label.add_theme_color_override(
		"font_color", D.RED if stage in ["review", "intervention"] else D.MUTED
	)
	var new_marks: Array = [warning, review, intervention]
	if not is_equal_approx(value, distrust) or new_marks != marks:
		distrust = value
		marks = new_marks
		bar.queue_redraw()
	tooltip_text = _explain(company, words)


func _explain(company: Dictionary, words: String) -> String:
	var lines: PackedStringArray = ["公司不信任 %.1f / 100 · %s" % [distrust, words]]
	for source: Variant in company.get("sources", {}).values():
		if float(source.get("rate", 0.0)) > 0.0:
			lines.append("%+.2f /日 · %s" % [float(source.rate), str(source.reason)])
	if lines.size() == 1:
		lines.append("现在没有履约风险，不信任每天慢慢回落。")
	lines.append("点击查看公司关系页。")
	return "\n".join(lines)


func _zone_color(from: float) -> Color:
	if marks.is_empty() or from < float(marks[0]):
		return Color("3f8f7f")
	if from < float(marks[1]):
		return Color("c9a24f")
	if from < float(marks[2]):
		return Color("d0793f")
	return Color("c9503f")


func _draw_bar() -> void:
	var height: float = bar.size.y
	var left: float = 4.0
	var edges: Array = [0.0] + marks + [100.0]
	for index: int in range(edges.size() - 1):
		var low: float = float(edges[index])
		var high: float = float(edges[index + 1])
		var top: float = height * (1.0 - high / 100.0)
		var bottom: float = height * (1.0 - low / 100.0)
		var zone := Rect2(left, top, BAR_WIDTH, bottom - top)
		bar.draw_rect(zone, _zone_color(low).darkened(0.45))
		var filled_top: float = maxf(top, height * (1.0 - distrust / 100.0))
		if filled_top < bottom:
			bar.draw_rect(
				Rect2(left, filled_top, BAR_WIDTH, bottom - filled_top), _zone_color(low)
			)
	bar.draw_rect(Rect2(left, 0.0, BAR_WIDTH, height), Color("304756"), false, 1.0)
	var font: Font = bar.get_theme_default_font()
	var names: Array = ["关注", "审查", "介入"]
	for index: int in range(marks.size()):
		var y: float = height * (1.0 - float(marks[index]) / 100.0)
		bar.draw_line(
			Vector2(left - 2.0, y), Vector2(left + BAR_WIDTH + 2.0, y), Color("e7eef2"), 1.0
		)
		if font != null:
			bar.draw_string(
				font,
				Vector2(left + BAR_WIDTH + 5.0, y + 4.0),
				str(names[index]),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				12,
				D.MUTED
			)
	var marker: float = height * (1.0 - distrust / 100.0)
	bar.draw_line(
		Vector2(left - 3.0, marker), Vector2(left + BAR_WIDTH + 3.0, marker), Color.WHITE, 2.0
	)
