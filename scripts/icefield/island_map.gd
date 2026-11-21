extends RefCounted
const L=preload("res://scripts/icefield/icefield_layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
static func build(hud: CanvasLayer) -> void:
	hud.content.add_child(UI.label("西 · 霜光雪镇与雪松林     东 · 蓝冰原     北 · 极光钟楼与雪山\n南岸码头免费回城 · 棕色边框为可购地皮 · 北坡书屋有踏雪路线",17,UI.MUTED))
	var map:=Control.new();map.custom_minimum_size=Vector2(890,480);hud.content.add_child(map);hud.map_draw=map
	map.draw.connect(func():
		map.draw_set_transform(Vector2(445,233),0,Vector2(1.44,1.36))
		var outline:=PackedVector2Array()
		for i in range(96):var a: float=i*TAU/96.;outline.append(Vector2(cos(a)*178.,sin(a)*158.))
		map.draw_colored_polygon(outline,Color("bad4e4"))
		for z in range(-150,151,4):
			for x in range(-174,175,4):
				if L.can_walk(Vector3(x,0,z)) and x<L.shore_x(z)+5.:map.draw_rect(Rect2(x,z,4,4),Color("e3eaf0"))
		if hud.city.has_building_world():
			for id in Land.ids_for("icefield"):
				var rect:=Land.bounds(id);var mine:=Land.owns(hud.session.state(),id)
				map.draw_rect(rect,Color("87ac9b") if mine else Color("dfcdad",.8))
				map.draw_rect(rect,Color("827968"),false,.9)
		var trail:=PackedVector2Array([Vector2(-104,118),Vector2(-79,74),Vector2(-79,-92)])
		map.draw_polyline(trail,Color("b4a496"),2.8,true);map.draw_line(Vector2(-118,16),Vector2(-22,16),Color("b4a496"),2.8,true)
		for b in L.BUILDINGS:map.draw_rect(Rect2(b.x-5.,b.z-4.,10.,8.),Color("b58b69") if b.kind=="shop" else Color("8d9cac"))
		map.draw_circle(Vector2(-63,24),3.,Color("d9b56e"))
		for r in preload("res://scripts/services/game_data.gd").resources("icefield"):map.draw_circle(Vector2(r.x,r.z),1.1,Color("7f9aab"))
		map.draw_rect(Rect2(-108,119,14,4),Color("a88b6b"))
		var p: Vector3=hud.city.bunny.position;map.draw_circle(Vector2(p.x,p.z),3.2,Color("ffffff"));map.draw_circle(Vector2(p.x,p.z),2.,Color("c47563")))
