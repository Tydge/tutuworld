extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
static func build(hud: CanvasLayer) -> void:
	hud.content.add_child(UI.label("北宫苑 · 中玉带河 · 南市与渡口　　西南农田与井 · 东南六里宅地",17,UI.MUTED))
	var map:=Control.new();map.custom_minimum_size=Vector2(890,480);hud.content.add_child(map);hud.map_draw=map
	map.draw.connect(func():
		map.draw_set_transform(Vector2(445,233),0,Vector2(1.45,1.06))
		map.draw_rect(Rect2(-240,-206,480,412),Color("b8bd99"));map.draw_rect(Rect2(-240,-206,480,124),Color("ceb997"))
		var stream:=PackedVector2Array();var lane:=PackedVector2Array()
		for x in range(-240,241,5):stream.append(Vector2(x,J.river_z(x)))
		for z in range(-184,211,3):lane.append(Vector2(J.lane(z),z))
		map.draw_polyline(stream,Color("79a7a6"),17.,true);map.draw_polyline(lane,Color("e7dac2"),6.,true)
		for x in J.BRIDGES:map.draw_rect(Rect2(x-3.6,J.river_z(x)-14,7.2,28),Color("91795c"))
		for path in preload("res://scripts/jade/court_ground.gd").ALLEYS:
			map.draw_polyline(PackedVector2Array(path),Color("d6c8a5"),2.4,true)
		for side: float in [-1.,1.]:
			map.draw_line(Vector2(side*17.,J.PALACE_GATE_Z),Vector2(side*49.,J.PALACE_GATE_Z),Color("9c6150"),2.6,true)
			map.draw_line(Vector2(side*7.1,J.PALACE_GATE_Z),Vector2(side*9.5,J.PALACE_GATE_Z),Color("9c6150"),2.6,true)
			map.draw_line(Vector2(side*13.2,J.PALACE_GATE_Z-4.),Vector2(side*13.2,J.PALACE_GATE_Z+4.),Color("e7dac2"),4.,true)
		for h in J.HOUSES:
			draw_house(map,h)
		map.draw_circle(Vector2(120,-40),7.,Color("87a99b"))
		map.draw_rect(Rect2(-3.5,198,7,15),Color("997351"))
		for id in J.LOTS:map.draw_rect(Land.bounds(id),Color("87a98b") if Land.owns(hud.session.state(),id) else Color("dbca96"));map.draw_rect(Land.bounds(id),Color("8a7659"),false,1.)
		map.draw_rect(Rect2(-177,117,21,10),Color("8d704e"))
		var p: Vector3=hud.city.bunny.position;map.draw_circle(Vector2(p.x,p.z),4.,Color.WHITE);map.draw_circle(Vector2(p.x,p.z),2.6,Color("c15c4d")))

static func draw_house(map: Control,house: Array) -> void:
	var center := J.center(house)
	var angle := -J.door_angle(house)
	var d := J.dims(house[4])
	var plan := PackedVector2Array([Vector2(-d.x,-d.z),Vector2(d.x,-d.z),Vector2(d.x,d.z),Vector2(-d.x,d.z)])
	if house[4] == "pavilion":
		plan = PackedVector2Array([Vector2(-d.x,-d.z*.6),Vector2(-d.x*.6,-d.z),Vector2(d.x*.6,-d.z),Vector2(d.x,-d.z*.6),Vector2(d.x,d.z*.6),Vector2(d.x*.6,d.z),Vector2(-d.x*.6,d.z),Vector2(-d.x,d.z*.6)])
	elif house[4] == "court":
		plan.append_array(PackedVector2Array([Vector2(-d.x,d.z*.18),Vector2(-d.x-3.9,d.z*.18),Vector2(-d.x-3.9,-d.z)]))
	for i in range(plan.size()):
		plan[i] = center + plan[i].rotated(angle)
	map.draw_colored_polygon(plan,Color("ab6853") if house[3] < -82 else Color("657d70"))
	var door := center + Vector2(0,d.z).rotated(angle)
	map.draw_circle(door,1.1,Color("eee3be"))
