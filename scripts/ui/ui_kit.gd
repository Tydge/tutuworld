extends RefCounted
const INK := Color("355c50")
const MUTED := Color("87947d")
const CREAM := Color("fff9e9")
const GREEN := Color("588b72")
static func theme() -> Theme:
	var t:=Theme.new()
	t.default_font=load("res://assets/fonts/NotoSansSC.ttf")
	t.default_font_size=17
	t.set_stylebox("panel","TooltipPanel",box(Color("294d43"),12,14))
	t.set_color("font_color","TooltipLabel",CREAM)
	t.set_font_size("font_size","TooltipLabel",15)
	t.set_color("font_color","Label",INK)
	t.set_color("font_color","Button",INK)
	t.set_color("font_color","LineEdit",INK)
	t.set_color("font_placeholder_color","LineEdit",Color("526c59"))
	t.set_color("caret_color","LineEdit",INK)
	t.set_color("selection_color","LineEdit",Color("b8d4bd"))
	t.set_color("font_selected_color","LineEdit",INK)
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: t.set_color(state,"CheckButton",INK)
	return t
static func label(text: String,size_: int=18,color: Color=INK) -> Label:
	var n:=Label.new()
	n.text=text
	n.add_theme_font_size_override("font_size",size_)
	n.add_theme_color_override("font_color",color)
	return n
static func box(color: Color=CREAM,radius: int=24,padding: int=22) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.content_margin_left=padding
	s.content_margin_right=padding
	s.content_margin_top=padding
	s.content_margin_bottom=padding
	s.shadow_color=Color("254d3e",.12)
	s.shadow_size=8
	s.shadow_offset=Vector2(0,5)
	return s
static func panel(color: Color=CREAM,radius: int=24,padding: int=22) -> PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",box(color,radius,padding))
	return p
static func button(text: String,callback: Callable=Callable(),accent: bool=false) -> Button:
	var b:=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,48)
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",box(GREEN if accent else Color("ebefdb"),18,12))
	b.add_theme_stylebox_override("hover",box(Color("74a48a") if accent else Color("d9e8ce"),18,12))
	b.add_theme_stylebox_override("pressed",box(Color("3f745f") if accent else Color("c5dabc"),18,12))
	b.add_theme_stylebox_override("disabled",box(Color("e8e6d8"),18,12))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	b.add_theme_color_override("font_color",CREAM if accent else INK)
	b.add_theme_color_override("font_hover_color",CREAM if accent else INK)
	b.add_theme_color_override("font_pressed_color",CREAM if accent else INK)
	b.add_theme_color_override("font_disabled_color",Color("a0a491"))
	b.mouse_entered.connect(func():
		b.pivot_offset=b.size*.5
		b.create_tween().tween_property(b,"scale",Vector2.ONE*1.025,.12).set_trans(Tween.TRANS_SINE))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b,"scale",Vector2.ONE,.12))
	if callback.is_valid(): b.pressed.connect(callback)
	return b
static func column(gap: int=12) -> VBoxContainer:
	var c:=VBoxContainer.new()
	c.add_theme_constant_override("separation",gap)
	return c
static func row(gap: int=12) -> HBoxContainer:
	var r:=HBoxContainer.new()
	r.add_theme_constant_override("separation",gap)
	return r
static func clear(n: Node) -> void:
	for child in n.get_children():
		n.remove_child(child)
		child.queue_free()
static func pop(control: Control) -> void:
	control.pivot_offset=control.size*.5
	control.scale=Vector2.ONE*.95
	control.modulate.a=0
	var t:=control.create_tween().set_parallel(true)
	t.tween_property(control,"scale",Vector2.ONE,.23).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(control,"modulate:a",1.0,.15)
