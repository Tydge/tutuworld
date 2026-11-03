extends Control
const Swatch=preload("res://scripts/ui/fabric_swatch.gd")
var definition: Dictionary={}
var item_id := ""
var icon_extent:=56
func _ready() -> void:
	custom_minimum_size=Vector2(icon_extent,icon_extent)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c:=size*.5
	var scale_:=minf(size.x,size.y)/56
	draw_set_transform(c,0,Vector2.ONE*scale_)
	var color:=Color(definition.get("color","a9b98a"))
	draw_circle(Vector2.ZERO,25,Color("eff0dc"))
	var kind: String=definition.get("kind","")
	var shape: String=definition.get("style",definition.get("icon",item_id))
	if kind=="food" and shape in ["honey_wheat_cake","rustic_wheat_bread","vegetable_omelette"]:
		draw_set_transform(c,0,Vector2(scale_,scale_*.72))
		draw_circle(Vector2(0,5),22,Color("f7ebce"))
		draw_arc(Vector2(0,5),21,0,TAU,40,Color("739d91"),2,true)
		if shape=="honey_wheat_cake":
			for i in range(3):
				var point:=Vector2(-7+i*7,5-i*3)
				draw_circle(point,11,Color("c89043"))
				draw_circle(point+Vector2(0,-3),10,color)
				draw_arc(point+Vector2(0,-3),5,.2,4.8,18,Color("a77127"),2,true)
		elif shape=="rustic_wheat_bread":
			draw_style_box(_box(color),Rect2(-18,-11,36,28))
			for x in [-10,0,10]: draw_line(Vector2(x-2,-8),Vector2(x+3,7),Color("f2d7a0"),3,true)
		else:
			draw_circle(Vector2(0,5),17,color)
			for i in range(7): draw_circle(Vector2(sin(i*2.4)*11,5+cos(i*2.4)*10),2.6,Color("679655") if i%2 else Color("c5694e"))
	elif kind=="food":
		draw_set_transform(c,0,Vector2(scale_,scale_*.60))
		draw_circle(Vector2(0,5),22,Color("f7ebce"))
		draw_arc(Vector2(0,5),21,0,TAU,40,Color("739d91"),2,true)
		draw_circle(Vector2(0,5),17,color)
		if shape=="garden_salad":
			for i in range(6): draw_circle(Vector2(sin(i*2.4)*10,cos(i*2.4)*10+5),7,Color("79ad61"))
			for i in range(3): draw_circle(Vector2(sin(i*2)*10,cos(i*2)*8+5),4,Color("d77b59"))
		else:
			for i in range(4): draw_circle(Vector2(sin(i*2)*10,cos(i*2)*8+5),2.5,Color("f7e5b8"))
			if shape=="tomato_stew": draw_rect(Rect2(-7,-2,7,7),Color("e5b571"))
	elif kind=="ingredient":
		if item_id=="egg":
			draw_set_transform(c,0,Vector2(scale_*.75,scale_))
			draw_circle(Vector2(0,1),19,color)
			draw_circle(Vector2(-6,-6),4,color.lightened(.15))
		elif item_id=="honey":
			draw_style_box(_box(color),Rect2(-14,-11,28,30))
			draw_rect(Rect2(-14,-16,28,8),Color("927346"))
			draw_circle(Vector2(0,4),8,Color("f5e4b3"))
			draw_circle(Vector2(0,4),4,Color("b68b35"))
		elif item_id=="sea_salt":
			draw_style_box(_box(color),Rect2(-13,-15,26,34))
			draw_rect(Rect2(-13,-15,26,7),Color("8fa6a0"))
			draw_circle(Vector2(0,5),7,Color("faf3dc"))
		else:
			draw_style_box(_box(color),Rect2(-10,-10,20,29))
			draw_rect(Rect2(-5,-20,10,12),color.darkened(.12))
			draw_rect(Rect2(-6,-23,12,5),Color("b89660"))
			draw_rect(Rect2(-8,0,16,12),Color("f5ead1"))
	elif kind=="seed":
		draw_style_box(_box(color),Rect2(-15,-18,30,36))
		draw_circle(Vector2(0,2),8,Color("fff4d6"))
		draw_line(Vector2(0,9),Vector2(0,-7),Color("5f9466"),3,true)
		draw_circle(Vector2(-4,-4),4,Color("83aa63"))
	elif shape=="bow":
		for side in [-1,1]:
			cloth_polygon(PackedVector2Array([Vector2(side*4,-4),Vector2(side*20,-13),Vector2(side*22,-9),Vector2(side*22,10),Vector2(side*19,13),Vector2(side*4,4)]),color)
			draw_line(Vector2(side*6,0),Vector2(side*18,-3),color.darkened(.15),2,true)
		draw_style_box(_box(color.darkened(.05)),Rect2(-5,-6,10,12))
	elif shape=="beret":
		draw_set_transform(c,0,Vector2(scale_,scale_*.65))
		var outline:=PackedVector2Array()
		for i in range(40):outline.append(Vector2(cos(i*TAU/40)*20,1+sin(i*TAU/40)*20))
		cloth_polygon(outline,color)
		draw_line(Vector2(-17,10),Vector2(17,10),color.darkened(.2),5,true)
		draw_line(Vector2(1,-15),Vector2(3,-23),color,4,true)
	elif shape=="scarf":
		draw_arc(Vector2(0,-6),14,0,PI,24,color,10,true)
		cloth_polygon(PackedVector2Array([Vector2(-12,-2),Vector2(-2,-2),Vector2(-2,21),Vector2(-12,21)]),color)
		cloth_polygon(PackedVector2Array([Vector2(0,-2),Vector2(10,-2),Vector2(10,16),Vector2(0,16)]),color)
	elif shape=="bell":
		draw_arc(Vector2(0,-9),17,0,PI,24,color,7,true)
		draw_circle(Vector2(0,9),11,Color("efc34d"))
		draw_circle(Vector2(0,9),2,Color("926628"))
		draw_line(Vector2(0,11),Vector2(0,19),Color("926628"),2,true)
	elif shape=="apron":
		cloth_polygon(PackedVector2Array([Vector2(-9,-15),Vector2(9,-15),Vector2(10,0),Vector2(18,19),Vector2(-18,19),Vector2(-10,0)]),color)
		draw_arc(Vector2(0,-16),8,PI,TAU,20,Color("f6e7c8"),3,true)
		draw_line(Vector2(-16,2),Vector2(16,2),Color("f6e7c8"),3,true)
	elif kind=="clothing":
		draw_style_box(_box(color),Rect2(-16,-14,32,32))
		cloth_polygon(PackedVector2Array([Vector2(-15,-13),Vector2(15,-13),Vector2(15,17),Vector2(-15,17)]),color)
		draw_line(Vector2(-9,-20),Vector2(-9,-5),color,6,true)
		draw_line(Vector2(9,-20),Vector2(9,-5),color,6,true)
		if shape=="overalls":
			draw_rect(Rect2(-15,12,11,10),color)
			draw_rect(Rect2(4,12,11,10),color)
		else: draw_line(Vector2(0,-14),Vector2(0,18),Color("fff8df"),4,true)
	elif shape=="watering_can":
		draw_style_box(_box(color),Rect2(-13,-6,24,23))
		draw_line(Vector2(9,0),Vector2(23,-10),color,6,true)
		draw_arc(Vector2(-2,-8),11,PI,TAU,20,color,4,true)
	elif shape in ["pickaxe","stone_hammer","copper_axe"]:
		draw_line(Vector2(-13,19),Vector2(9,-12),Color("ac855a"),6,true)
		draw_line(Vector2(-5,-18),Vector2(22,0),Color("8da39e"),9 if shape=="stone_hammer" else 5,true)
	elif shape=="herbicide":
		draw_style_box(_box(color),Rect2(-11,-14,22,33))
		draw_rect(Rect2(-7,-21,14,8),Color("7c8f76"))
		draw_rect(Rect2(-8,-2,16,13),Color("f9efd0"))
	elif shape=="orange":
		draw_circle(Vector2(0,3),18,Color("d8862a"))
		draw_circle(Vector2(-2,1),16,color)
		draw_circle(Vector2(-7,-5),4,Color("f6bd58"))
		draw_line(Vector2(0,-13),Vector2(1,-20),Color("89744a"),3,true)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-16),Vector2(7,-23),Vector2(15,-19),Vector2(7,-14)]),Color("609359"))
	elif shape=="wheat":
		for offset in [-8,8]:
			draw_line(Vector2(offset,20),Vector2(offset-2,-17),Color("aa8c46"),2,true)
			for row in range(4):
				for side in [-1,1]:
					var point:=Vector2(offset+side*4,-12+row*7)
					draw_set_transform(c+point*scale_,side*-.55,Vector2(scale_*3.4,scale_*5))
					draw_circle(Vector2.ZERO,1,color)
			draw_set_transform(c,0,Vector2.ONE*scale_)
	elif shape in ["branch","birch"]:
		draw_line(Vector2(-16,16),Vector2(14,-15),color,6,true)
		draw_line(Vector2(0,0),Vector2(-2,-16),color,4,true)
	elif shape in ["limestone","copper","iron","sandstone"]:
		draw_colored_polygon(PackedVector2Array([Vector2(-19,12),Vector2(-17,-5),Vector2(-5,-16),Vector2(14,-11),Vector2(22,9),Vector2(7,18)]),color)
		draw_line(Vector2(-7,-10),Vector2(0,4),color.lightened(.25),4,true)
	else:
		draw_circle(Vector2(0,4),16,color)
		draw_circle(Vector2(-7,-13),7,Color("75a567"))
		draw_circle(Vector2(5,-14),6,Color("88b46f"))
func cloth_polygon(points: PackedVector2Array,color: Color) -> void:
	var pattern:=Swatch.texture(definition)
	if pattern==null:
		draw_colored_polygon(points,color);return
	var uv:=PackedVector2Array()
	for point in points:uv.append((point+Vector2(28,28))/56.)
	draw_polygon(points,PackedColorArray([Color.WHITE]),uv,pattern)
func _box(color: Color) -> StyleBoxFlat:
	var b:=StyleBoxFlat.new()
	b.bg_color=color
	b.set_corner_radius_all(5)
	return b
