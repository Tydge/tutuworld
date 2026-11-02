extends Node
## Keep the UI at native resolution while budgeting only the 3D buffer on dense displays.
const UI=preload("res://scripts/ui/ui_kit.gd")
const MAX_3D_PIXELS:=2000000.0
var pending:=false
static func ensure(context: Node) -> void:
	preload("res://scripts/city/frame_pacer.gd").ensure(context)
	var window:=context.get_tree().root
	if window.has_meta("render_budget"): return
	window.set_meta("render_budget",true)
	var budget=load("res://scripts/city/render_budget.gd").new()
	budget.name="RenderBudget"
	window.add_child.call_deferred(budget)
static func add_control(parent: Control,session: Node) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18)
	parent.add_child(row)
	var label_:=Label.new();label_.text="画面";label_.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label_)
	var choice:=OptionButton.new();choice.custom_minimum_size=Vector2(210,44)
	choice.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	choice.tooltip_text="均衡适配高清屏幕；原生画质保留完整 3D 分辨率。"
	choice.add_theme_stylebox_override("normal",UI.box(Color("ebefdb"),16,10))
	choice.add_theme_stylebox_override("hover",UI.box(Color("d9e8ce"),16,10))
	choice.add_theme_stylebox_override("pressed",UI.box(Color("c5dabc"),16,10))
	choice.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color"]: choice.add_theme_color_override(state,UI.INK)
	var popup:=choice.get_popup()
	popup.add_theme_stylebox_override("panel",UI.box(UI.CREAM,16,12))
	popup.add_theme_stylebox_override("hover",UI.box(UI.GREEN,10,8))
	popup.add_theme_color_override("font_color",UI.INK)
	popup.add_theme_color_override("font_hover_color",UI.CREAM)
	choice.add_item("均衡");choice.add_item("原生画质")
	choice.selected=1 if session.settings.get("render_quality","balanced")=="native" else 0
	choice.item_selected.connect(func(index):
		session.set_setting("render_quality","native" if index==1 else "balanced")
		var budget:=session.get_node_or_null("/root/RenderBudget")
		if is_instance_valid(budget): budget.schedule()
	)
	row.add_child(choice)
func _ready() -> void:
	get_tree().root.size_changed.connect(schedule)
	apply()
func schedule() -> void:
	if pending: return
	pending=true;apply.call_deferred()
func apply() -> void:
	pending=false
	var window:=get_tree().root
	var session:=get_node_or_null("/root/Session")
	var native: bool=is_instance_valid(session) and session.settings.get("render_quality","balanced")=="native"
	var modern:=RenderingServer.get_current_rendering_method()=="forward_plus"
	var pixels: float=maxf(1.0,float(window.size.x)*window.size.y)
	var scale_: float=1.0 if native or not modern else minf(1.0,sqrt(MAX_3D_PIXELS/pixels))
	if scale_>.99: scale_=1.0
	var mode:=Viewport.SCALING_3D_MODE_BILINEAR
	if scale_<1.0:
		mode=Viewport.SCALING_3D_MODE_METALFX_SPATIAL if RenderingServer.get_current_rendering_driver_name()=="metal" else Viewport.SCALING_3D_MODE_FSR
	window.scaling_3d_mode=mode
	window.scaling_3d_scale=scale_
	window.fsr_sharpness=.35
	print("RENDER_BUDGET output=",window.size," scale=",snappedf(scale_,.001)," mode=",mode," quality=","native" if native else "balanced")
