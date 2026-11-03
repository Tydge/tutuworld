extends VBoxContainer
const UI=preload("res://scripts/ui/ui_kit.gd")
const View=preload("res://scripts/city/interior_view.gd")
var session: Node
var button: MenuButton
var hint: PanelContainer
var hint_elapsed:=0.
var hint_started:=false
var hint_finished:=false
func _ready() -> void:
	name="IndoorCameraControl";custom_minimum_size.x=274;add_theme_constant_override("separation",8)
	button=MenuButton.new();button.name="IndoorCameraButton";button.flat=false;button.custom_minimum_size=Vector2(274,40);button.theme=UI.theme();button.focus_mode=Control.FOCUS_NONE;button.tooltip_text="切换室内视角 · V"
	button.add_theme_stylebox_override("normal",UI.box(UI.CREAM,12,9));button.add_theme_stylebox_override("hover",UI.box(Color("e4ecd7"),12,9));button.add_theme_color_override("font_color",UI.INK)
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,UI.INK)
	add_child(button)
	for label_ in View.NAMES:button.get_popup().add_radio_check_item(label_)
	button.get_popup().add_theme_stylebox_override("panel",UI.box(UI.CREAM,12,10));button.get_popup().add_theme_stylebox_override("hover",UI.box(Color("d9e8ce"),8,8));button.get_popup().add_theme_color_override("font_color",UI.INK)
	var icon:=Control.new();icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.position=Vector2(13,10);icon.size=Vector2(24,20);button.add_child(icon)
	icon.draw.connect(func():
		icon.draw_style_box(UI.box(Color("426e5c"),3,0),Rect2(1,4,22,15));icon.draw_rect(Rect2(5,1,9,5),Color("426e5c"));icon.draw_circle(Vector2(12,11.5),5.,UI.CREAM);icon.draw_circle(Vector2(12,11.5),3.2,Color("426e5c")))
	button.get_popup().id_pressed.connect(select_mode)
	button.about_to_popup.connect(func():finish_hint())
	hint=UI.panel(Color("fff5cf",.98),14,12);hint.name="IndoorCameraFirstHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hint)
	var text:=UI.label("室内可以切换视角\n点击上方相机按钮，或按 V 试试",13,UI.INK);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.x=242;hint.add_child(text);hint.hide()
	session.settings_changed.connect(func(key):if key=="interior_view_mode":refresh())
	refresh();hide()
func refresh() -> void:
	var mode: int=int(session.settings.interior_view_mode);button.text="    相机 · "+View.NAMES[mode]+"  ▾"
	for i in range(3):button.get_popup().set_item_checked(i,i==mode)
func select_mode(index: int) -> void:
	session.set_setting("interior_view_mode",index);finish_hint();refresh()
func cycle() -> void:
	if visible:select_mode((int(session.settings.interior_view_mode)+1)%3)
func finish_hint() -> void:
	hint.hide();hint_finished=true
	if not session.settings.interior_view_hint_seen:session.set_setting("interior_view_hint_seen",true)
func update_context(enabled: bool,delta: float) -> void:
	visible=enabled
	if not enabled:
		button.get_popup().hide();hint.hide()
		if hint_started:hint_finished=true
		return
	if not hint_finished and not session.settings.interior_view_hint_seen:
		hint_started=true;hint.show();hint_elapsed+=delta
		session.set_setting("interior_view_hint_seen",true)
		if hint_elapsed>=9.:finish_hint()
	elif hint_started and not hint_finished:
		hint_elapsed+=delta;hint.visible=hint_elapsed<9.
		if hint_elapsed>=9.:hint_finished=true
