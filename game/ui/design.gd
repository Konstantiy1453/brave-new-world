extends RefCounted
## Palette, theme and widgets. Pages are written top to bottom as plain calls. Between begin()
## and finish() every widget call reuses the control already at that position when its type
## matches, so running a page again updates it in place: nodes, focus and scroll all survive.
## Outside begin()/finish() the same calls simply append new controls.
##
## Styling is one system with three variants: a neutral foundation for the shell and most pages,
## research (lively turquoise, cyan and yellow) and industry (charcoal, gray-teal, muted gold) for
## construction and facility pages. A page sets its variant with use() before it is drawn; the
## semantic colours INK, MUTED, TEAL, GOLD and RED then resolve through that variant, and cards,
## bars and buttons take its styles. Every reused control is restyled or reset on each pass, so no
## page keeps another page's look. Style boxes are built once and cached.

const INK = Color("e7eef2")
const MUTED = Color("a6bac8")
const TEAL = Color("62c7c5")
const GOLD = Color("d8b16a")
const RED = Color("e46f68")
const NEUTRAL: String = "neutral"
const RESEARCH: String = "research"
const INDUSTRY: String = "industry"
## Type scale: page title, section heading, body, secondary, caption. Values use the body size.
const TITLE: int = 24
const SECTION: int = 19
const BODY: int = 17
const SMALL: int = 15
const CAPTION: int = 14
## Tokens per variant. text/muted/accent/gold/bad stand behind INK/MUTED/TEAL/GOLD/RED; the
## neutral variant keeps the original values, so pages without a variant look as they did.
const PALETTES: Dictionary = {
	"neutral":
	{
		"bg": Color("0f1a24"),
		"card": Color("12202c"),
		"raised": Color("182938"),
		"well": Color("0a131b"),
		"line": Color("2b3d4a"),
		"line_soft": Color("203039"),
		"line_strong": Color("4f6878"),
		"text": Color("e7eef2"),
		"muted": Color("a6bac8"),
		"faint": Color("6d808c"),
		"accent": Color("62c7c5"),
		"accent_2": Color("78b8d8"),
		"gold": Color("d8b16a"),
		"bad": Color("e46f68"),
		"good": Color("6cc59b"),
		"select": Color("62c7c5"),
		"primary": Color("62c7c5"),
		"focus": Color("ecd592"),
	},
	"research":
	{
		"bg": Color("0a1822"),
		"card": Color("0e2230"),
		"raised": Color("12293a"),
		"well": Color("06111a"),
		"line": Color("1f4657"),
		"line_soft": Color("173544"),
		"line_strong": Color("2c95a6"),
		"text": Color("e8f5f6"),
		"muted": Color("9cc3cb"),
		"faint": Color("62909a"),
		"accent": Color("2fe0c8"),
		"accent_2": Color("38c9f2"),
		"gold": Color("ffd24a"),
		"bad": Color("ff6b63"),
		"good": Color("3fe0a0"),
		"select": Color("2fe0c8"),
		"primary": Color("2fe0c8"),
		"focus": Color("ffe07a"),
	},
	"industry":
	{
		"bg": Color("14181a"),
		"card": Color("191e20"),
		"raised": Color("20262a"),
		"well": Color("0e1112"),
		"line": Color("333b3e"),
		"line_soft": Color("272e31"),
		"line_strong": Color("5d6b6a"),
		"text": Color("e3e5e0"),
		"muted": Color("a3aaa5"),
		"faint": Color("737c78"),
		"accent": Color("7fa39d"),
		"accent_2": Color("8b9fa8"),
		"gold": Color("c4a166"),
		"bad": Color("cb6c62"),
		"good": Color("87b397"),
		"select": Color("c4a166"),
		"primary": Color("c4a166"),
		"focus": Color("e2d29d"),
	},
}
## Research categories keep their own lively hues: industry and construction warm, agriculture
## and society cool. Any category not listed takes the research accent.
const CATEGORY_COLORS: Dictionary = {
	"industry": Color("ff9650"),
	"construction": Color("ffd24a"),
	"agriculture": Color("37dca6"),
	"society": Color("3cc6f4"),
}
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
const BUTTON_COLORS: Array[String] = [
	"font_color",
	"font_hover_color",
	"font_pressed_color",
	"font_hover_pressed_color",
	"font_focus_color",
	"font_disabled_color",
]
const CURSOR: StringName = &"_ui_cursor"
const META_SIZE: StringName = &"_ui_size"
const META_COLOR: StringName = &"_ui_color"
const META_FN: StringName = &"_ui_fn"
const META_LAST: StringName = &"_ui_last"
const META_SKIN: StringName = &"_ui_skin"
const META_KEY: StringName = &"_ui_key"
const BUILDING_ICONS: String = "res://assets/icons/buildings/"
const LineChart = preload("res://ui/line_chart.gd")

static var _variant: String = NEUTRAL
static var _styles: Dictionary = {}


## The variant pages drawn from now on take; main.gd sets it around each page and resets it.
static func use(variant: String) -> void:
	_variant = variant if PALETTES.has(variant) else NEUTRAL


static func variant() -> String:
	return _variant


## A token of the current variant, or of the one given.
static func tone(token: String, of_variant: String = "") -> Color:
	var palette: Dictionary = PALETTES[of_variant if PALETTES.has(of_variant) else _variant]
	return palette.get(token, palette.text)


## The semantic colours resolve through the current variant; any other colour stays as it is.
static func ink(color: Color) -> Color:
	if _variant == NEUTRAL:
		return color
	if color == INK:
		return tone("text")
	if color == MUTED:
		return tone("muted")
	if color == TEAL:
		return tone("accent")
	if color == GOLD:
		return tone("gold")
	if color == RED:
		return tone("bad")
	return color


static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, tone("accent", RESEARCH))


static func box(
	color: Color = Color("132333"), border: Color = Color("304756"), margin: int = 18
) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(5)
	b.set_content_margin_all(margin)
	return b


## A flat panel with fine borders and two cut corners (top left, bottom right): the geometric
## detail every surface shares. `left` widens the left edge into a selection bar.
static func _flat(
	fill: Color,
	border: Color,
	margin_x: int,
	margin_y: int,
	cut: int = 0,
	width: int = 1,
	left: int = -1
) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	if left >= 0:
		b.border_width_left = left
	b.set_corner_radius_all(1)
	if cut > 0:
		b.corner_radius_top_left = cut
		b.corner_radius_bottom_right = cut
	# One segment per corner: the rounded corner becomes a straight cut.
	b.corner_detail = 1
	b.content_margin_left = margin_x
	b.content_margin_right = margin_x
	b.content_margin_top = margin_y
	b.content_margin_bottom = margin_y
	return b


## A style of a variant by role, built once.
static func style(role: String, of_variant: String = "") -> StyleBox:
	var v: String = of_variant if PALETTES.has(of_variant) else _variant
	var key: String = v + "|" + role
	if not _styles.has(key):
		_styles[key] = _make(PALETTES[v], role)
	return _styles[key]


static func _make(p: Dictionary, role: String) -> StyleBox:
	var clear := Color(0, 0, 0, 0)
	match role:
		"modal":
			var modal_bg: Color = p.bg
			modal_bg.a = 0.97
			var modal: StyleBoxFlat = _flat(modal_bg, p.line, 20, 16, 12)
			modal.shadow_color = Color(0, 0, 0, 0.35)
			modal.shadow_size = 14
			return modal
		"panel":
			var panel_bg: Color = p.bg
			panel_bg.a = 0.93
			return _flat(panel_bg, p.line, 12, 10, 8)
		"card":
			return _flat(p.card, p.line_soft, 14, 12, 7)
		"card_on":
			return _flat(p.raised, p.select, 14, 12, 7, 1, 3)
		"card_quiet":
			return _flat(p.well, p.line_soft, 12, 10, 5)
		"item":
			return _flat(p.card, p.line_soft, 4, 3, 4)
		"item_on":
			return _flat(p.raised, p.select, 4, 3, 4, 1, 3)
		"well":
			return _flat(p.well, p.line_soft, 10, 8, 4)
		"row":
			return _flat(clear, clear, 8, 6, 0, 0, 3)
		"row_hover":
			return _flat(p.raised, p.line, 8, 6, 0, 0, 3)
		"row_on":
			return _flat(p.raised, p.select, 8, 6, 0, 0, 3)
		"button":
			return _flat(p.raised, p.line, 10, 5, 4)
		"button_hover":
			return _flat((p.raised as Color).lightened(0.06), p.line_strong, 10, 5, 4)
		"button_pressed":
			return _flat(p.card, p.select, 10, 5, 4)
		"button_disabled":
			return _flat(p.well, p.line_soft, 10, 5, 4)
		"primary":
			return _flat((p.card as Color).lerp(p.primary, 0.2), p.primary, 12, 6, 5)
		"primary_hover":
			return _flat((p.card as Color).lerp(p.primary, 0.3), p.primary, 12, 6, 5)
		"primary_pressed":
			return _flat((p.card as Color).lerp(p.primary, 0.42), p.primary, 12, 6, 5)
		"chip":
			return _flat(p.card, p.line_soft, 8, 4, 3)
		"chip_hover":
			return _flat(p.raised, p.line_strong, 8, 4, 3)
		"chip_on":
			return _flat((p.card as Color).lerp(p.select, 0.16), p.select, 8, 4, 3)
		"focus":
			var focus: StyleBoxFlat = _flat(clear, p.focus, 0, 0, 4, 2)
			focus.draw_center = false
			focus.set_expand_margin_all(2)
			return focus
		"bar_bg":
			return _flat(p.well, p.line_soft, 0, 0, 0)
		"tooltip":
			return _flat(p.bg, p.accent, 12, 8, 6)
		"popup":
			return _flat(p.bg, p.line, 8, 6, 6)
		"popup_hover":
			return _flat((p.card as Color).lerp(p.select, 0.2), clear, 6, 4, 0, 0)
		"scroll":
			return _flat(clear, clear, 3, 3, 0, 0)
		"grabber":
			return _flat(p.line_strong, clear, 3, 3, 0, 0)
		"grabber_on":
			return _flat(p.select, clear, 3, 3, 0, 0)
		"field":
			return _flat(p.well, p.line, 10, 6, 3)
		"field_focus":
			return _flat(p.well, p.select, 10, 6, 3)
		"scroll_area":
			# Keeps a scroll area's content clear of its bar.
			var area := StyleBoxEmpty.new()
			area.content_margin_right = 10
			return area
	return _flat(p.card, p.line, 10, 8, 0)


## A coloured fill or tag box, cached by colour.
static func _tinted(color: Color, role: String) -> StyleBoxFlat:
	var key: String = role + "|" + color.to_html()
	if not _styles.has(key):
		match role:
			"fill":
				_styles[key] = _flat(color, color, 0, 0, 0, 0)
			_:
				var tint: Color = color
				tint.a = 0.14
				_styles[key] = _flat(tint, Color(color, 0.7), 7, 2, 3)
	return _styles[key]


static func theme() -> Theme:
	var t = Theme.new()
	t.default_font = load("res://assets/fonts/main_medium.ttf")
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", TEAL)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("647986"))
	t.set_stylebox("normal", "Button", style("button", NEUTRAL))
	t.set_stylebox("hover", "Button", style("button_hover", NEUTRAL))
	t.set_stylebox("pressed", "Button", style("button_pressed", NEUTRAL))
	t.set_stylebox("disabled", "Button", style("button_disabled", NEUTRAL))
	t.set_stylebox("focus", "Button", style("focus", NEUTRAL))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", TEAL)
	t.set_stylebox("panel", "PanelContainer", style("panel", NEUTRAL))
	t.set_stylebox("normal", "LineEdit", style("field", NEUTRAL))
	t.set_stylebox("focus", "LineEdit", style("field_focus", NEUTRAL))
	t.set_stylebox("panel", "PopupMenu", style("popup", NEUTRAL))
	t.set_stylebox("hover", "PopupMenu", style("popup_hover", NEUTRAL))
	t.set_stylebox("panel", "TooltipPanel", style("tooltip", NEUTRAL))
	t.set_font_size("font_size", "TooltipLabel", 17)
	t.set_color("font_color", "TooltipLabel", INK)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, style("scroll", NEUTRAL))
		t.set_stylebox("grabber", bar, style("grabber", NEUTRAL))
		t.set_stylebox("grabber_highlight", bar, style("grabber_on", NEUTRAL))
		t.set_stylebox("grabber_pressed", bar, style("grabber_on", NEUTRAL))
	t.set_stylebox("background", "ProgressBar", style("bar_bg", NEUTRAL))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "HFlowContainer", 8)
	t.set_constant("v_separation", "HFlowContainer", 8)
	return t


## Starts an in-place pass over a container's children.
static func begin(parent: Node) -> void:
	parent.set_meta(CURSOR, 0)


## Ends the pass: children past the cursor go away, nested containers finish too.
static func finish(parent: Node) -> void:
	if not parent.has_meta(CURSOR):
		return
	var cursor: int = parent.get_meta(CURSOR)
	while parent.get_child_count() > cursor:
		var extra: Node = parent.get_child(parent.get_child_count() - 1)
		parent.remove_child(extra)
		extra.queue_free()
	parent.remove_meta(CURSOR)
	for child: Node in parent.get_children():
		finish(child)


static func _take(parent: Node, type_name: String) -> Node:
	if not parent.has_meta(CURSOR):
		var fresh: Node = ClassDB.instantiate(type_name)
		parent.add_child(fresh)
		return fresh
	var cursor: int = parent.get_meta(CURSOR)
	parent.set_meta(CURSOR, cursor + 1)
	if cursor < parent.get_child_count():
		var existing: Node = parent.get_child(cursor)
		if existing.get_class() == type_name:
			return existing
		parent.remove_child(existing)
		existing.queue_free()
	var made: Node = ClassDB.instantiate(type_name)
	parent.add_child(made)
	parent.move_child(made, cursor)
	return made


## A page that changes shape can leave the old holder of a name standing until the end of the pass:
## the name goes to the node that is wanted now, or find_child would miss it.
static func _take_name(n: Node, key: String) -> void:
	n.set_meta(META_KEY, key)
	if str(n.name) == key:
		return
	var parent: Node = n.get_parent()
	if parent != null:
		var holder: Node = parent.get_node_or_null(NodePath(key))
		if holder != null and holder != n:
			holder.name = "old_%d" % holder.get_instance_id()
	n.name = key


static func _container(parent: Node, type_name: String) -> Node:
	var made: Node = _take(parent, type_name)
	if parent.has_meta(CURSOR):
		begin(made)
	return made


static func font_size(control: Control, size: int) -> void:
	if int(control.get_meta(META_SIZE, -1)) != size:
		control.add_theme_font_size_override("font_size", size)
		control.set_meta(META_SIZE, size)


static func label(
	parent: Node, text: String, size: int = 18, color: Color = INK, wrap: bool = true
) -> Label:
	var n: Label = _take(parent, "Label")
	if n.text != text:
		n.text = text
	font_size(n, size)
	var shown: Color = ink(color)
	if not n.has_meta(META_COLOR) or n.get_meta(META_COLOR) != shown:
		n.add_theme_color_override("font_color", shown)
		n.set_meta(META_COLOR, shown)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## `kind` picks the button's role: "plain" (the variant's ordinary button, the theme's in the
## neutral variant), "primary" (the page's main action), "chip" / "chip_on" (filters) or "row" /
## "row_on" (selectable list rows).
static func button(
	parent: Node,
	text: String,
	fn: Callable,
	hint: String = "",
	key: String = "",
	kind: String = "plain"
) -> Button:
	var b: Button = _take(parent, "Button")
	if not b.has_meta(META_FN):
		b.custom_minimum_size.y = 43
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_press.bind(b))
	b.set_meta(META_FN, fn)
	if b.text != text:
		b.text = text
	if b.tooltip_text != hint:
		b.tooltip_text = hint
	b.disabled = false
	# A reused button may have served another panel: what callers tune starts from the default.
	b.clip_text = false
	b.size_flags_stretch_ratio = 1.0
	if kind == "plain" and _variant == NEUTRAL:
		unskin(b)
	else:
		skin(b, kind)
	if key != "":
		_take_name(b, key)
	elif b.has_meta(META_KEY):
		# A reused button that served a named one loses that name, or a lookup would find it.
		b.remove_meta(META_KEY)
		b.name = "Button_%d" % b.get_instance_id()
	return b


## Gives a button the styles of a role in the current variant. Only a change of role or variant
## touches the button, so a refresh costs nothing.
static func skin(b: Button, kind: String = "plain", of_variant: String = "") -> void:
	var v: String = of_variant if PALETTES.has(of_variant) else _variant
	var key: String = v + "|" + kind
	if str(b.get_meta(META_SKIN, "")) == key:
		return
	var p: Dictionary = PALETTES[v]
	var roles: Dictionary = {
		"normal": "button",
		"hover": "button_hover",
		"pressed": "button_pressed",
		"disabled": "button_disabled",
		"focus": "focus",
	}
	var text: Color = p.text
	var hover: Color = p.accent
	var pressed: Color = p.text
	match kind:
		"primary":
			roles.normal = "primary"
			roles.hover = "primary_hover"
			roles.pressed = "primary_pressed"
			hover = p.text
		"chip":
			# A toggle chip shows its pressed style while it is the chosen one.
			roles.normal = "chip"
			roles.hover = "chip_hover"
			roles.pressed = "chip_on"
			text = p.muted
			hover = p.text
			pressed = p.select
		"chip_on":
			roles.normal = "chip_on"
			roles.hover = "chip_on"
			roles.pressed = "chip_on"
			text = p.select
			hover = p.select
		"row":
			roles.normal = "row"
			roles.hover = "row_hover"
			roles.pressed = "row_on"
			roles.disabled = "row"
		"row_on":
			roles.normal = "row_on"
			roles.hover = "row_on"
			roles.pressed = "row_on"
			roles.disabled = "row_on"
	for state: String in roles:
		b.add_theme_stylebox_override(state, style(roles[state], v))
	b.add_theme_color_override("font_color", text)
	b.add_theme_color_override("font_hover_color", hover)
	b.add_theme_color_override("font_pressed_color", pressed)
	b.add_theme_color_override("font_hover_pressed_color", pressed if kind == "chip" else hover)
	b.add_theme_color_override("font_focus_color", text)
	b.add_theme_color_override("font_disabled_color", p.faint)
	b.set_meta(META_SKIN, key)


## Back to the theme's styles: what skin() set goes, what a page set itself stays.
static func unskin(b: Button) -> void:
	if not b.has_meta(META_SKIN):
		return
	for state: String in BUTTON_STATES:
		b.remove_theme_stylebox_override(state)
	for color: String in BUTTON_COLORS:
		b.remove_theme_color_override(color)
	b.remove_meta(META_SKIN)


static func _press(b: Button) -> void:
	var fn: Callable = b.get_meta(META_FN)
	fn.call()


static func row(parent: Node) -> HBoxContainer:
	return _container(parent, "HBoxContainer")


static func col(parent: Node) -> VBoxContainer:
	return _container(parent, "VBoxContainer")


## A row that wraps onto the next line when it runs out of width (filters, tags).
static func flow(parent: Node) -> HFlowContainer:
	return _container(parent, "HFlowContainer")


static func grid(parent: Node, columns: int) -> GridContainer:
	var g: GridContainer = _container(parent, "GridContainer")
	g.columns = columns
	return g


## A panel of the current variant; `role` is "card", "card_on" (selected or running),
## "card_quiet" or "well".
static func card(parent: Node, role: String = "card") -> VBoxContainer:
	var p: PanelContainer = _container(parent, "PanelContainer")
	if not p.has_meta(META_LAST):
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.set_meta(META_LAST, true)
	panel_style(p, role)
	return col(p)


## Sets a panel's style for a role of the current variant, when it changed.
static func panel_style(p: PanelContainer, role: String = "panel", of_variant: String = "") -> void:
	var v: String = of_variant if PALETTES.has(of_variant) else _variant
	var key: String = v + "|" + role
	if str(p.get_meta(META_SKIN, "")) != key:
		p.add_theme_stylebox_override("panel", style(role, v))
		p.set_meta(META_SKIN, key)


## A scrolling list inside a page, for a column beside fixed panels: `height` tall, or as tall as
## its parent leaves when `height` is 0. Keyboard focus scrolls what it reaches into view.
static func scroll(parent: Node, key: String, height: int = 0) -> VBoxContainer:
	var s: ScrollContainer = _container(parent, "ScrollContainer")
	_take_name(s, key)
	if not s.has_meta(META_LAST):
		s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.follow_focus = true
		s.set_meta(META_LAST, true)
	s.custom_minimum_size.y = height
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL if height <= 0 else Control.SIZE_FILL
	s.add_theme_stylebox_override("panel", style("scroll_area"))
	var inner: VBoxContainer = col(s)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return inner


## One line of a ledger: an icon (assets/icons/<icon>.svg, or a blank of the same width), a
## caption, its value, and an optional note at the right edge.
static func pair(
	parent: Node,
	caption: String,
	value: String,
	color: Color = INK,
	note: String = "",
	note_color: Color = MUTED,
	icon_key: String = ""
) -> HBoxContainer:
	var line: HBoxContainer = row(parent)
	line.add_theme_constant_override("separation", 8)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mark: TextureRect = _icon_from(
		line, "res://assets/icons/" + icon_key + ".svg" if icon_key != "" else "", 18
	)
	mark.self_modulate = tone("faint")
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label: Label = label(line, caption, SMALL, MUTED, false)
	name_label.custom_minimum_size.x = 64
	var value_label: Label = label(line, value, BODY, color, false)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var aside: Label = label(line, note, CAPTION, note_color, false)
	aside.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return line


## A figure under its caption, for the summary strip at the top of a page.
static func stat(
	parent: Node, caption: String, value: String, color: Color = INK, hint: String = ""
) -> VBoxContainer:
	var box: VBoxContainer = col(parent)
	box.add_theme_constant_override("separation", 0)
	label(box, caption, CAPTION, MUTED, false)
	label(box, value, SECTION, color, false)
	box.tooltip_text = hint
	box.mouse_filter = Control.MOUSE_FILTER_PASS if hint != "" else Control.MOUSE_FILTER_IGNORE
	return box


## A section heading inside a column: small, spaced, in the variant's muted tone, with a rule.
static func heading(parent: Node, text: String, color: Color = MUTED) -> Label:
	var line: HBoxContainer = row(parent)
	line.add_theme_constant_override("separation", 8)
	var caption: Label = label(line, text, SMALL, color, false)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stroke: ColorRect = rule(line)
	stroke.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return caption


## A thin line in the current variant's border colour, or in `color`.
static func rule(parent: Node, color: Color = Color(0, 0, 0, 0), height: int = 1) -> ColorRect:
	var line: ColorRect = _take(parent, "ColorRect")
	line.color = tone("line") if color.a == 0.0 else ink(color)
	line.custom_minimum_size = Vector2(0, height)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## A small framed word in a colour: a category or a state, always with text, never colour alone.
static func tag(parent: Node, text: String, color: Color, size: int = CAPTION) -> Label:
	var p: PanelContainer = _container(parent, "PanelContainer")
	var shown: Color = ink(color)
	var key: String = "tag|" + shown.to_html()
	if str(p.get_meta(META_SKIN, "")) != key:
		p.add_theme_stylebox_override("panel", _tinted(shown, "tag"))
		p.set_meta(META_SKIN, key)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label(p, text, size, shown, false)


## A number field. Only a new program value overwrites it, so a daily refresh never clobbers
## what the player is typing.
static func spin(
	parent: Node,
	key: String,
	low: float,
	high: float,
	step: float,
	value: float,
	suffix: String = ""
) -> SpinBox:
	var n: SpinBox = _take(parent, "SpinBox")
	_take_name(n, key)
	n.min_value = low
	n.max_value = high
	n.step = step
	n.suffix = suffix
	if not n.has_meta(META_LAST) or float(n.get_meta(META_LAST)) != value:
		n.set_value_no_signal(value)
		n.set_meta(META_LAST, value)
	return n


static func option(
	parent: Node, key: String, items: Array, selected: int, fn: Callable = Callable()
) -> OptionButton:
	var n: OptionButton = _take(parent, "OptionButton")
	_take_name(n, key)
	if _variant == NEUTRAL:
		unskin(n)
	else:
		skin(n)
	if fn.is_valid():
		if not n.has_meta(META_FN):
			n.item_selected.connect(_selected.bind(n))
		n.set_meta(META_FN, fn)
	var same: bool = n.item_count == items.size()
	if same:
		for index: int in range(items.size()):
			if n.get_item_text(index) != str(items[index]):
				same = false
	if not same:
		n.clear()
		for item: Variant in items:
			n.add_item(str(item))
	if not n.has_meta(META_LAST) or int(n.get_meta(META_LAST)) != selected:
		n.select(selected)
		n.set_meta(META_LAST, selected)
	return n


static func _selected(index: int, n: OptionButton) -> void:
	var fn: Callable = n.get_meta(META_FN)
	fn.call(index)


## A line chart: each row of `series` is {values: PackedFloat32Array, color: Color}.
static func line_chart(parent: Node, key: String, series: Array, height: int = 150) -> Control:
	var n: Control = _take(parent, "Control")
	if n.get_script() != LineChart:
		n.set_script(LineChart)
	_take_name(n, key)
	n.custom_minimum_size = Vector2(0, height)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.call("set_series", series)
	return n


static func line_edit(parent: Node, key: String, text: String) -> LineEdit:
	var n: LineEdit = _take(parent, "LineEdit")
	_take_name(n, key)
	if not n.has_meta(META_LAST) or str(n.get_meta(META_LAST)) != text:
		n.text = text
		n.set_meta(META_LAST, text)
	return n


## A thin bar, full at ratio 1, for anything that takes time.
static func progress(
	parent: Node, ratio: float, color: Color = TEAL, height: int = 8
) -> ProgressBar:
	var bar: ProgressBar = _take(parent, "ProgressBar")
	if not bar.has_meta(META_LAST):
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.step = 0.001
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_meta(META_LAST, true)
	var back: String = _variant + "|bar_bg"
	if str(bar.get_meta(META_SKIN, "")) != back:
		bar.add_theme_stylebox_override("background", style("bar_bg"))
		bar.set_meta(META_SKIN, back)
	var fill: Color = ink(color)
	if not bar.has_meta(META_COLOR) or bar.get_meta(META_COLOR) != fill:
		bar.add_theme_stylebox_override("fill", _tinted(fill, "fill"))
		bar.set_meta(META_COLOR, fill)
	bar.custom_minimum_size.y = height
	bar.value = clampf(ratio, 0.0, 1.0)
	return bar


static func portrait(parent: Node, who: String, width: int = 185, height: int = 245) -> TextureRect:
	var p: TextureRect = _take(parent, "TextureRect")
	var path: String = "res://assets/portraits/" + who + ".png"
	if str(p.get_meta(META_LAST, "")) != path:
		p.texture = load(path)
		p.set_meta(META_LAST, path)
	p.custom_minimum_size = Vector2(width, height)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p.self_modulate = Color.WHITE
	return p


## A picture filling `size`, cropped to cover it; empty when the file does not exist.
static func picture(parent: Node, path: String, size: Vector2) -> TextureRect:
	var p: TextureRect = _take(parent, "TextureRect")
	if str(p.get_meta(META_LAST, "")) != path:
		p.texture = load(path) if ResourceLoader.exists(path) else null
		p.set_meta(META_LAST, path)
	p.custom_minimum_size = size
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.self_modulate = Color.WHITE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func icon(parent: Node, key: String, size: int = 27) -> TextureRect:
	return _icon_from(parent, "res://assets/icons/" + key + ".svg", size)


## A line icon (assets/icons/*.svg, drawn in light strokes) in a colour of the current variant.
static func tinted_icon(parent: Node, key: String, size: int, color: Color) -> TextureRect:
	var picture_rect: TextureRect = icon(parent, key, size)
	picture_rect.self_modulate = ink(color)
	return picture_rect


## A building's own icon, baked from its model (tests/art/bake_icons.gd); the SVG of `fallback`
## (Labels.icon_key) for a kind without one.
static func building_icon(
	parent: Node, kind: String, fallback: String, size: int = 27
) -> TextureRect:
	var path: String = BUILDING_ICONS + kind + ".webp"
	if not ResourceLoader.exists(path):
		return _icon_from(parent, "res://assets/icons/" + fallback + ".svg", size)
	var picture_rect: TextureRect = _icon_from(parent, path, size)
	# Drawn at a fraction of its 128 px: mipmaps keep the small sizes clean.
	picture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return picture_rect


static func _icon_from(parent: Node, path: String, size: int) -> TextureRect:
	var p: TextureRect = _take(parent, "TextureRect")
	if str(p.get_meta(META_LAST, "")) != path:
		p.texture = load(path) if ResourceLoader.exists(path) else null
		p.set_meta(META_LAST, path)
	p.custom_minimum_size = Vector2(size, size)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Reused controls start from the default filter and colour; callers set their own.
	p.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	p.self_modulate = Color.WHITE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
