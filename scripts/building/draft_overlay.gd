extends Control
const FONT=preload("res://assets/fonts/NotoSansSC.ttf")
var editor: Node
var area:=Rect2()
var floor_y:=.22
var color:=Color("5bbd96")
var wall: Array=[]
var second:=Rect2()
var bubble:=preload("res://scripts/ui/ui_kit.gd").box(Color("fff9e9"),7,0)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func label_at(text_: String,p: Vector2) -> void:
	var extent:=FONT.get_string_size(text_,HORIZONTAL_ALIGNMENT_LEFT,-1,14);var rect:=Rect2(p-extent*.5-Vector2(8,8),extent+Vector2(16,16))
	rect.position.x=clampf(rect.position.x,6.,size.x-rect.size.x-6.);rect.position.y=clampf(rect.position.y,6.,maxf(6.,size.y-340.-rect.size.y))
	draw_style_box(bubble,rect)
	draw_string(FONT,rect.position+Vector2(8,extent.y+3),text_,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("355c50"))
func project(p: Vector2) -> Vector2:return editor.city.camera.unproject_position(Vector3(p.x,floor_y,p.y))
func _draw() -> void:
	if not is_instance_valid(editor) or not editor.active:return
	if area.size!=Vector2.ZERO:
		var points:=PackedVector2Array([project(area.position),project(Vector2(area.end.x,area.position.y)),project(area.end),project(Vector2(area.position.x,area.end.y))]);points.append(points[0]);draw_polyline(points,color,2.,true)
		if points[0].distance_to(points[1])>130.:label_at("%.1f m"%area.size.x,(points[0]+points[1])*.5-Vector2(0,20))
		if points[0].distance_to(points[3])>130.:label_at("%.1f m"%area.size.y,(points[0]+points[3])*.5-Vector2(38,0))
		label_at("%.1f × %.1f m · %.1f㎡"%[area.size.x,area.size.y,area.get_area()],project(area.get_center()))
	if second.size!=Vector2.ZERO:label_at("相邻 %.1f × %.1f m"%[second.size.x,second.size.y],project(second.get_center()))
	if wall.size()==2:
		var a:=project(wall[0]);var b:=project(wall[1]);draw_line(a,b,color,4.,true)
		var direction: Vector2=(b-a).normalized().orthogonal();var center: Vector2=(a+b)*.5
		for sign_ in [-1,1]:
			var tip: Vector2=center+direction*sign_*18.;draw_line(center,tip,color,2.,true)
			draw_line(tip,tip-direction*sign_*5.+direction.orthogonal()*4.,color,2.,true);draw_line(tip,tip-direction*sign_*5.-direction.orthogonal()*4.,color,2.,true)
