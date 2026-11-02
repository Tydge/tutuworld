extends Control
var fraction:=1.0
var shown_fraction:=1.0
func _ready() -> void:
	custom_minimum_size=Vector2(188,18)
	size=custom_minimum_size;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(false)
func set_fraction(value: float) -> void:
	fraction=clampf(value,0,1)
	set_process(absf(fraction-shown_fraction)>.0001)
	queue_redraw()
func _process(delta: float) -> void:
	shown_fraction=move_toward(shown_fraction,fraction,delta*1.5)
	queue_redraw()
	if is_equal_approx(shown_fraction,fraction): set_process(false)
func pill(color: Color,radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(radius);return style
func _draw() -> void:
	var width_: float=maxf(12,size.x)
	draw_style_box(pill(Color("d8c398"),9),Rect2(0,0,width_,18))
	draw_style_box(pill(Color("3c665d"),7),Rect2(2,2,width_-4,14))
	var extent: float=(width_-6)*shown_fraction
	if extent>1:
		var shade:=Color("d39762").lerp(Color("79bca2"),smoothstep(.05,.45,shown_fraction))
		draw_style_box(pill(shade,6),Rect2(3,3,extent,12))
		draw_style_box(pill(shade.lightened(.30),3),Rect2(5,4,maxf(0,extent-4),4))
	for i in range(1,4):
		var x:=3+(width_-6)*i*.25
		draw_line(Vector2(x,6),Vector2(x,12),Color("fff3cc",.38),1,true)
