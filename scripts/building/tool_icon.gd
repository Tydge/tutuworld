extends Control
var kind:="select"
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(24,24)
func _draw() -> void:
	var c:=Color("426f60");var center:=size*.5
	match kind:
		"delete":
			draw_line(center+Vector2(-6,9),center+Vector2(5,-4),c,4,true)
			var points:=PackedVector2Array([center+Vector2(-4,-9),center+Vector2(9,-2),center+Vector2(6,3),center+Vector2(-7,-4)])
			draw_colored_polygon(points,c)
		"move":
			for v in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				draw_line(center,center+v*9,c,2,true);draw_line(center+v*9,center+v*5+v.orthogonal()*3,c,2,true);draw_line(center+v*9,center+v*5-v.orthogonal()*3,c,2,true)
		_:
			var points:=PackedVector2Array([center+Vector2(-6,-10),center+Vector2(-4,8),center+Vector2(0,3),center+Vector2(5,10),center+Vector2(8,8),center+Vector2(3,1),center+Vector2(9,0)])
			draw_colored_polygon(points,c)
