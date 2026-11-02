extends Control
var progress := 0.0
func _ready() -> void:
	size=Vector2(72,72)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_circle(Vector2(36,36),32,Color("fff9e9",.96))
	draw_arc(Vector2(36,36),25,0,TAU,64,Color("dbe4cc"),5,true)
	draw_arc(Vector2(36,36),25,-PI*.5,-PI*.5+TAU*clampf(progress,0,1),64,Color("609b7d"),5,true)
	draw_circle(Vector2(36,36),5,Color("e4bd75"))
