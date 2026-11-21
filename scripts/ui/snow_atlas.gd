extends RefCounted
const UI=preload("res://scripts/ui/ui_kit.gd")
const Trail=preload("res://scripts/icefield/snow_trail.gd")

class Seal extends Control:
	var mark: String
	var ink: Color
	func _ready() -> void:custom_minimum_size=Vector2(40,40)
	func _draw() -> void:
		var center:=size*.5
		draw_arc(center,16.,0.,TAU,36,ink,2.,true)
		draw_arc(center,13.,0.,TAU,32,ink,.7,true)
		match mark:
			"harbor":
				draw_colored_polygon(PackedVector2Array([center+Vector2(-9,2),center+Vector2(9,2),center+Vector2(5,7),center+Vector2(-5,7)]),ink)
				draw_colored_polygon(PackedVector2Array([center+Vector2(-6,0),center+Vector2(0,-9),center+Vector2(0,0)]),ink)
				draw_line(center+Vector2(1,-9),center+Vector2(1,3),ink,1.3,true)
			"bell":
				draw_circle(center+Vector2(0,-1),6.,ink)
				draw_colored_polygon(PackedVector2Array([center+Vector2(-5,-2),center+Vector2(5,-2),center+Vector2(8,5),center+Vector2(-8,5)]),ink)
				draw_circle(center+Vector2(0,8),1.5,ink)
			"ice":
				for i in range(6):
					var arm:=Vector2.RIGHT.rotated(i*TAU/6.)
					var stem:=center+arm*5.5
					draw_line(center,center+arm*9.,ink,1.7,true)
					for side in [-1.,1.]:draw_line(stem,stem+arm.rotated(side*.92)*3.5,ink,1.4,true)

static func build(hud: CanvasLayer) -> void:
	var trail: Dictionary=Trail.normalize(hud.session.state().get("snow_trail",{}))
	var pages:=UI.row(12);hud.content.add_child(pages)
	var front:=PanelContainer.new();front.custom_minimum_size=Vector2(330,430);front.add_theme_stylebox_override("panel",UI.box(Color("f1e3c5"),7,24));pages.add_child(front)
	var cover:=UI.column(20);front.add_child(cover)
	cover.add_child(UI.label("霜  光  雪  镇",17,Color("987452")))
	cover.add_child(UI.label("沿 途 拓 印",26,Color("5b6156")))
	var verse:=UI.label("沿着脚印去看海、听钟、找冰花。每到一处，在木牌旁按 E 把那里的印章带回来。",17,Color("675d4d"))
	verse.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;cover.add_child(verse)
	for id in Trail.STAMPS:
		var stamped: bool=id in trail.stamps
		var stamp: Dictionary=Trail.STAMPS[id]
		var line:=UI.row(9);cover.add_child(line)
		var seal:=Seal.new();seal.mark=id;seal.ink=Color(stamp.color) if stamped else Color("b7a589");line.add_child(seal)
		var label:=UI.label(stamp.name if stamped else stamp.name+" · 待拓印",18,seal.ink)
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;line.add_child(label)
	var back:=PanelContainer.new();back.size_flags_horizontal=Control.SIZE_EXPAND_FILL;back.add_theme_stylebox_override("panel",UI.box(Color("f6ecd2"),7,24));pages.add_child(back)
	var notes:=UI.column(16);back.add_child(notes)
	for id in Trail.STAMPS:
		var stamp: Dictionary=Trail.STAMPS[id]
		notes.add_child(UI.label(stamp.name,20,Color(stamp.color)))
		var clue:=UI.label(stamp.clue,16,Color("675d4d"));clue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notes.add_child(clue)
	if trail.claimed:notes.add_child(UI.label("旅途回礼已经夹进图册。",16,UI.GREEN))
	elif trail.stamps.size()==Trail.STAMPS.size():
		var claim:=UI.button("夹上最后一页 · 领取回礼",func():hud.city.finish_snow_trail(),true)
		claim.name="ClaimSnowTrail";notes.add_child(claim)
