extends RefCounted
const INK = Color("e7eef2")
const MUTED = Color("a6bac8")
const TEAL = Color("62c7c5")
const GOLD = Color("d8b16a")
const RED = Color("e46f68")
static func box(color:Color=Color("132333"), border:Color=Color("304756"), margin:int=18)->StyleBoxFlat:
	var b=StyleBoxFlat.new()
	b.bg_color=color
	b.border_color=border
	b.set_border_width_all(1)
	b.set_corner_radius_all(5)
	b.set_content_margin_all(margin)
	return b
static func theme()->Theme:
	var t=Theme.new()
	t.default_font=load("res://assets/fonts/main_medium.ttf")
	t.default_font_size=18
	t.set_color("font_color","Label",INK)
	t.set_color("font_color","Button",INK)
	t.set_color("font_hover_color","Button",TEAL)
	t.set_color("font_disabled_color","Button",Color("647986"))
	t.set_stylebox("normal","Button",box(Color("1a3042")))
	t.set_stylebox("hover","Button",box(Color("264553"),TEAL))
	t.set_stylebox("pressed","Button",box(Color("31565e"),TEAL))
	t.set_stylebox("disabled","Button",box(Color("132330")))
	t.set_stylebox("focus","Button",box(Color(0,0,0,0),GOLD,0))
	t.set_stylebox("panel","PanelContainer",box())
	t.set_stylebox("normal","LineEdit",box(Color("0c1925")))
	t.set_stylebox("panel","PopupMenu",box())
	t.set_stylebox("panel","TooltipPanel",box(Color("102430"),TEAL))
	t.set_font_size("font_size","TooltipLabel",17)
	t.set_constant("separation","VBoxContainer",12)
	t.set_constant("separation","HBoxContainer",12)
	return t
static func label(parent:Node,text:String,size:int=18,color:Color=INK,wrap:bool=true)->Label:
	var n=Label.new()
	n.text=text
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	if wrap:n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n
static func button(parent:Node,text:String,fn:Callable,hint:String="")->Button:
	var b=Button.new()
	b.text=text
	b.tooltip_text=hint
	b.custom_minimum_size.y=43
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(fn)
	parent.add_child(b)
	return b
static func row(parent:Node)->HBoxContainer:
	var h=HBoxContainer.new()
	parent.add_child(h)
	return h
static func col(parent:Node)->VBoxContainer:
	var v=VBoxContainer.new()
	parent.add_child(v)
	return v
static func card(parent:Node)->VBoxContainer:
	var p=PanelContainer.new()
	p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel",box(Color("10202e"),Color("294251"),15))
	parent.add_child(p)
	return col(p)
static func portrait(parent:Node,who:String,width:int=185,height:int=245)->TextureRect:
	var p=TextureRect.new()
	p.texture=load("res://assets/portraits/"+who+".png")
	p.custom_minimum_size=Vector2(width,height)
	p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(p)
	return p
static func icon(parent:Node,key:String,size:int=27)->TextureRect:
	var p=TextureRect.new()
	var path="res://assets/icons/"+key+".svg"
	if ResourceLoader.exists(path):p.texture=load(path)
	p.custom_minimum_size=Vector2(size,size)
	p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(p)
	return p
