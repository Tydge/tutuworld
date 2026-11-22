extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
static func build(hud: CanvasLayer) -> void:
	hud.content.add_child(UI.label("北宫苑 · 中玉带河 · 南市与渡口　　西南桑田与井 · 东南六里宅地",17,UI.MUTED))
	var map:=Control.new();map.custom_minimum_size=Vector2(890,480);hud.content.add_child(map);hud.map_draw=map
	map.draw.connect(func():
		map.draw_set_transform(Vector2(445,233),0,Vector2(1.45,1.06))
		map.draw_rect(Rect2(-240,-206,480,412),Color("b8bd99"));map.draw_rect(Rect2(-240,-206,480,124),Color("ceb997"))
		var stream:=PackedVector2Array();var lane:=PackedVector2Array()
		for x in range(-240,241,5):stream.append(Vector2(x,J.river_z(x)))
		for z in range(-184,211,3):lane.append(Vector2(J.lane(z),z))
		map.draw_polyline(stream,Color("79a7a6"),17.,true);map.draw_polyline(lane,Color("e7dac2"),6.,true)
		for x in J.BRIDGES:map.draw_rect(Rect2(x-3.6,J.river_z(x)-14,7.2,28),Color("91795c"))
		for h in J.HOUSES:map.draw_rect(Rect2(J.center(h)-Vector2(4.8,4),Vector2(9.6,8)),Color("ab6853") if h[3]< -82 else Color("657d70"))
		for id in J.LOTS:map.draw_rect(Land.bounds(id),Color("87a98b") if Land.owns(hud.session.state(),id) else Color("dbca96"));map.draw_rect(Land.bounds(id),Color("8a7659"),false,1.)
		map.draw_rect(Rect2(-177,117,21,10),Color("8d704e"))
		var p: Vector3=hud.city.bunny.position;map.draw_circle(Vector2(p.x,p.z),4.,Color.WHITE);map.draw_circle(Vector2(p.x,p.z),2.6,Color("c15c4d")))
