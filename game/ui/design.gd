extends RefCounted
## Palette, theme and widgets. Pages are written top to bottom as plain calls. Between begin()
## and finish() every widget call reuses the control already at that position when its type
## matches, so running a page again updates it in place: nodes, focus and scroll all survive.
## Outside begin()/finish() the same calls simply append new controls.

const INK = Color("e7eef2")
const MUTED = Color("a6bac8")
const TEAL = Color("62c7c5")
const GOLD = Color("d8b16a")
const RED = Color("e46f68")
const CURSOR: StringName = &"_ui_cursor"
const META_SIZE: StringName = &"_ui_size"
const META_COLOR: StringName = &"_ui_color"
const META_FN: StringName = &"_ui_fn"
const META_LAST: StringName = &"_ui_last"


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


static func theme() -> Theme:
	var t = Theme.new()
	t.default_font = load("res://assets/fonts/main_medium.ttf")
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", TEAL)
	t.set_color("font_disabled_color", "Button", Color("647986"))
	t.set_stylebox("normal", "Button", box(Color("1a3042")))
	t.set_stylebox("hover", "Button", box(Color("264553"), TEAL))
	t.set_stylebox("pressed", "Button", box(Color("31565e"), TEAL))
	t.set_stylebox("disabled", "Button", box(Color("132330")))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 0))
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("normal", "LineEdit", box(Color("0c1925")))
	t.set_stylebox("panel", "PopupMenu", box())
	t.set_stylebox("panel", "TooltipPanel", box(Color("102430"), TEAL))
	t.set_font_size("font_size", "TooltipLabel", 17)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
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
	if not n.has_meta(META_COLOR) or n.get_meta(META_COLOR) != color:
		n.add_theme_color_override("font_color", color)
		n.set_meta(META_COLOR, color)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


static func button(
	parent: Node, text: String, fn: Callable, hint: String = "", key: String = ""
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
	if key != "":
		b.name = key
	return b


static func _press(b: Button) -> void:
	var fn: Callable = b.get_meta(META_FN)
	fn.call()


static func row(parent: Node) -> HBoxContainer:
	return _container(parent, "HBoxContainer")


static func col(parent: Node) -> VBoxContainer:
	return _container(parent, "VBoxContainer")


static func grid(parent: Node, columns: int) -> GridContainer:
	var g: GridContainer = _container(parent, "GridContainer")
	g.columns = columns
	return g


static func card(parent: Node) -> VBoxContainer:
	var p: PanelContainer = _container(parent, "PanelContainer")
	if not p.has_meta(META_LAST):
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", box(Color("10202e"), Color("294251"), 15))
		p.set_meta(META_LAST, true)
	return col(p)


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
	n.name = key
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
	n.name = key
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


static func line_edit(parent: Node, key: String, text: String) -> LineEdit:
	var n: LineEdit = _take(parent, "LineEdit")
	n.name = key
	if not n.has_meta(META_LAST) or str(n.get_meta(META_LAST)) != text:
		n.text = text
		n.set_meta(META_LAST, text)
	return n


static func portrait(parent: Node, who: String, width: int = 185, height: int = 245) -> TextureRect:
	var p: TextureRect = _take(parent, "TextureRect")
	var path: String = "res://assets/portraits/" + who + ".png"
	if str(p.get_meta(META_LAST, "")) != path:
		p.texture = load(path)
		p.set_meta(META_LAST, path)
	p.custom_minimum_size = Vector2(width, height)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return p


static func icon(parent: Node, key: String, size: int = 27) -> TextureRect:
	var p: TextureRect = _take(parent, "TextureRect")
	var path: String = "res://assets/icons/" + key + ".svg"
	if str(p.get_meta(META_LAST, "")) != path:
		p.texture = load(path) if ResourceLoader.exists(path) else null
		p.set_meta(META_LAST, path)
	p.custom_minimum_size = Vector2(size, size)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return p
