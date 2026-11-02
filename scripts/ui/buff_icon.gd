extends Control
const UI=preload("res://scripts/ui/ui_kit.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Icon=preload("res://scripts/ui/item_icon.gd")
var progress:=1.0
var item_id:=""
var icon: Control
var last_progress:=-1.0
var description:=""
var hover_time:=0.0
var details: PanelContainer
var details_text: Label
func _ready() -> void:
	custom_minimum_size=Vector2(64,64)
	size=custom_minimum_size
	mouse_default_cursor_shape=Control.CURSOR_HELP
	icon=Icon.new()
	icon.icon_extent=46
	icon.position=Vector2(9,9)
	icon.size=Vector2(46,46)
	icon.custom_minimum_size=Vector2(46,46)
	add_child(icon)
	details=UI.panel(UI.CREAM,17,13)
	details.position=Vector2(0,72)
	details.custom_minimum_size=Vector2(250,0)
	details.mouse_filter=Control.MOUSE_FILTER_IGNORE
	details.theme=UI.theme()
	details_text=UI.label("",15)
	details_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	details.add_child(details_text)
	add_child(details)
	details.hide()
func set_effect(effect: Dictionary,now: float) -> void:
	visible=not effect.is_empty() and float(effect.get("expires_at",0))>now
	if not visible:
		item_id=""
		if is_instance_valid(details): details.hide()
		return
	var id: String=effect.item
	if item_id!=id:
		item_id=id
		icon.item_id=id
		icon.definition=DB.item(id)
		icon.queue_redraw()
	progress=clampf((float(effect.expires_at)-now)/3600,0,1)
	var hours:=maxf(0,float(effect.expires_at)-now)/3600*24
	description="%s\n%s\n剩余 %d 时 %02d 分"%[DB.item(id).name,DB.item(id).effect_text,int(hours),int(fmod(hours,1)*60)]
	details_text.text=description
	if absf(progress-last_progress)>.00005:
		last_progress=progress
		queue_redraw()
func _draw() -> void:
	draw_circle(Vector2(32,32),30,Color("fff9e9",.96))
	draw_arc(Vector2(32,32),29,0,TAU,64,Color("d9ddc4"),4,true)
	draw_arc(Vector2(32,32),29,-PI*.5,-PI*.5+TAU*progress,64,Color("71a180"),4,true)
func _process(delta: float) -> void:
	var inside:=visible and get_global_rect().has_point(get_global_mouse_position())
	hover_time=hover_time+delta if inside else 0.0
	details.visible=hover_time>.25
