extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
const ORIGIN:=Vector2(445,233)
const SCALE:=Vector2(1.45,1.06)
const Games=preload("res://scripts/jade/house_games.gd")
const LABELS={"tide_stone":"水则碑","beacon":"听潮亭","audience":"含章殿","academy":"临川书院","garden":"藕香水榭","bridge_0":"西桥","bridge_1":"中桥","bridge_2":"东桥","fields":"公田","lots":"六里宅地","clothes":"云锦庄","silk":"尚衣局","market":"南市","pier":"南津渡"}
const SERVICES={"seed_shop":"买种子、卖收成","pastry_shop":"买杏仁酥","steamer":"买桂花糕、蒸点心","silk_shop":"挑玉京新衣","iron_shop":"选购工具","carpentry_shop":"挑家具","craft":"织布、打造工具","lodging":"上榻歇息","read":"翻阅手记","kitchen":"备料做饭","tea":"煮茶","chime":"击磬听五音","footwork":"踏梅花步","dye":"试染衣裳"}
static func build(hud: CanvasLayer) -> void:
	var journal: Dictionary=hud.session.state().jade_visits
	var destination: String={"hostel":"post","post":"hostel"}.get(journal.letter,"")
	var row:=UI.row();hud.content.add_child(row)
	var picker:=OptionButton.new();picker.add_item("按名称找去处");row.add_child(picker)
	picker.get_popup().max_size.y=480
	picker.custom_minimum_size=Vector2(174,38)
	for state in ["normal","hover","pressed"]:picker.add_theme_stylebox_override(state,UI.box(Color("e4e9d6") if state=="normal" else Color("d4e1c7"),9,8))
	for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color"]:picker.add_theme_color_override(state,UI.INK)
	picker.get_popup().add_theme_stylebox_override("panel",UI.box(UI.CREAM,10,8))
	picker.get_popup().add_theme_stylebox_override("hover",UI.box(UI.GREEN,6,4))
	picker.get_popup().add_theme_color_override("font_color",UI.INK)
	var line:=UI.label("点选去处　·　坊印 %d / %d"%[journal.marks.size(),Games.STATIONS.size()],18)
	row.add_child(line)
	var map:=Control.new();map.custom_minimum_size=Vector2(890,480);hud.content.add_child(map);hud.map_draw=map
	map.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var places: Dictionary={}
	for house in J.HOUSES:
		var id: String=house[0]
		var info: Dictionary=Games.entry(id)
		places[id]=[house[1],info.get("action",SERVICES.get(Games.NATIVE.get(id,""),"")),J.center(house)]
	places["silk"][1]="楼下向绣筠试穿选购，楼上衣架可试染"
	for id in J.LANDMARKS:
		var landmark: Dictionary=J.LANDMARKS[id]
		places[id]=[landmark.name,landmark.label,landmark.at]
	for i in J.LOTS.size():places[J.LOTS[i]]=[J.LOT_NAMES[i],"查看地牌",Land.bounds(J.LOTS[i]).get_center()]
	places["pier"]=["南津渡","坐船回海岛城",J.DOCK]
	places["fields"]=["西郊公田","耕作、到田边井打水",J.FIELD_BOUNDS.get_center()]
	places["lots"]=["六里宅地","在各里的地牌前认购",Vector2(131,111)]
	places["market"]=["南市","沿主街可达云锦庄和百炼铺",Vector2(J.lane(101),101)]
	for i in J.BRIDGES.size():
		var id:="bridge_"+str(i)
		var x: float=J.BRIDGES[i]
		places[id]=[LABELS[id],"步行过玉带河",Vector2(x,J.river_z(x))]
	var captions: Dictionary={}
	for id in LABELS:
		var offset:=Vector2(-42,-5) if id=="market" else Vector2(8,-4)
		var at: Vector2=ORIGIN+places[id][2]*SCALE+offset
		var font:=map.get_theme_default_font()
		var label_size:=font.get_string_size(LABELS[id],HORIZONTAL_ALIGNMENT_LEFT,-1,14)
		captions[id]=Rect2(at-Vector2(0,font.get_ascent(14)),label_size)
	for id in places:
		picker.add_item(places[id][0]);picker.set_item_metadata(picker.item_count-1,id)
	var select:=func(id: String):
		if not places.has(id):return
		hud.jade_map_target=id
		map.set_meta("selected_house",id)
		picker.select(places.keys().find(id)+1)
		line.text=str(places[id][0])+"　·　"+str(places[id][1])+("　·　已钤印" if id in journal.marks else "")+("　·　驿袋送到这里" if id==destination else "")
		map.queue_redraw()
	picker.item_selected.connect(func(index: int):
		if index>0:select.call(picker.get_item_metadata(index))
		else:
			hud.jade_map_target="";map.set_meta("selected_house","");line.text="点选去处　·　坊印 %d / %d"%[journal.marks.size(),Games.STATIONS.size()];map.queue_redraw())
	select.call(hud.jade_map_target)
	map.gui_input.connect(func(event):
		if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
		var point: Vector2=(event.position-ORIGIN)/SCALE
		for house in J.HOUSES:
			if Geometry2D.is_point_in_polygon(point,house_plan(house)):
				select.call(house[0]);return
		for id in captions:
			if captions[id].has_point(event.position):select.call(id);return
		if J.FIELD_BOUNDS.has_point(point):select.call("fields");return
		for id in J.LOTS:
			if Land.bounds(id).has_point(point):select.call(id);return
		for id in places:
			if point.distance_squared_to(places[id][2])<36.:select.call(id);return)
	map.draw.connect(func():
		map.draw_set_transform(ORIGIN,0,SCALE)
		map.draw_rect(Rect2(-240,-206,480,412),Color("b8bd99"));map.draw_rect(Rect2(-240,-206,480,124),Color("ceb997"))
		var stream:=PackedVector2Array();var lane:=PackedVector2Array()
		for x in range(-240,241,5):stream.append(Vector2(x,J.river_z(x)))
		for z in range(-184,211,3):lane.append(Vector2(J.lane(z),z))
		map.draw_polyline(stream,Color("79a7a6"),17.,true);map.draw_polyline(lane,Color("e7dac2"),6.,true)
		for x in J.BRIDGES:map.draw_rect(Rect2(x-3.6,J.river_z(x)-14,7.2,28),Color("91795c"))
		for path in preload("res://scripts/jade/court_ground.gd").alleys:
			map.draw_polyline(PackedVector2Array(path),Color("d6c8a5"),2.4,true)
		for side: float in [-1.,1.]:
			map.draw_line(Vector2(side*17.,J.PALACE_GATE_Z),Vector2(side*49.,J.PALACE_GATE_Z),Color("9c6150"),2.6,true)
			map.draw_line(Vector2(side*7.1,J.PALACE_GATE_Z),Vector2(side*9.5,J.PALACE_GATE_Z),Color("9c6150"),2.6,true)
			map.draw_line(Vector2(side*13.2,J.PALACE_GATE_Z-4.),Vector2(side*13.2,J.PALACE_GATE_Z+4.),Color("e7dac2"),4.,true)
		for h in J.HOUSES:
			draw_house(map,h)
			var c:=J.center(h)
			if h[0] in journal.marks:map.draw_circle(c,2.2,Color("efbd6c"))
			if h[0]==destination:
				map.draw_arc(c,9.,0,TAU,24,Color("ae392e"),2.,true)
		for center_: Vector2 in J.PONDS:
			var rim:=PackedVector2Array()
			for i in J.POND_SEGMENTS:rim.append(center_+J.pond_rim(i*TAU/J.POND_SEGMENTS))
			map.draw_colored_polygon(rim,Color("599a99"))
		for mark in J.LANDMARKS.values():map.draw_circle(mark.at,3.,Color("72512f"))
		map.draw_rect(Rect2(-3.5,198,7,15),Color("997351"))
		for id in J.LOTS:map.draw_rect(Land.bounds(id),Color("87a98b") if Land.owns(hud.session.state(),id) else Color("dbca96"));map.draw_rect(Land.bounds(id),Color("8a7659"),false,1.)
		map.draw_rect(J.FIELD_BOUNDS,Color("8d704e"))
		if places.has(hud.jade_map_target):map.draw_arc(places[hud.jade_map_target][2],10.,0,TAU,32,Color("a2372a"),2.,true)
		map.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		var font:=map.get_theme_default_font()
		for id in captions:
			var baseline: Vector2=captions[id].position+Vector2(0,font.get_ascent(14))
			map.draw_string_outline(font,baseline,LABELS[id],HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,Color("f6ebcf"))
			map.draw_string(font,baseline,LABELS[id],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("3d5146"))
		var pos: Vector3=hud.city.bunny.position
		var at:=ORIGIN+Vector2(pos.x,pos.z)*SCALE
		var heading: float=hud.city.bunny.visual_heading()
		var forward:=(Vector2(sin(heading),cos(heading))*SCALE).normalized()
		var side:=forward.orthogonal()
		map.draw_circle(at,7.,Color("fff6df"))
		map.draw_colored_polygon(PackedVector2Array([at+forward*9.,at-forward*5.+side*5.,at-forward*3.,at-forward*5.-side*5.]),Color("ab392d")))

static func house_plan(house: Array) -> PackedVector2Array:
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
	return plan

static func draw_house(map: Control,house: Array) -> void:
	var d:=J.dims(house[4])
	map.draw_colored_polygon(house_plan(house),Color("ab6853") if house[3] < -82 else Color("657d70"))
	var door := J.center(house) + Vector2(0,d.z).rotated(-J.door_angle(house))
	map.draw_circle(door,1.1,Color("eee3be"))
