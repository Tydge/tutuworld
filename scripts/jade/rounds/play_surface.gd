extends "res://scripts/jade/rounds/tableau.gd"
## Focusable transparent targets sit on the illustrated objects themselves.
signal pressed_object(index: int)
var objects: Array[Button]=[]
var hover_index:=-1
var last_press:=-1
var glint:=0.
var clay_start:=-1

func count_objects() -> int:
	if rule.grid_count:return rule.grid_count
	match rule.house:
		"music":return 5
		"audience","herbal":return 3
		"pipa","stage","dojo","banquet","incense","noodle","oil","hostel","baihe","books","garden","farmhouse","tailorhome":return rule.labels.size()
	return 0
func squares() -> Rect2:
	match rule.house:
		"weir":return Rect2(4,27,222,156)
		"sail","archive","silversmith","chamber":return Rect2(22,27,188,156)
		"basket":return Rect2(46,48,150,135)
		"paper","carver","stitch":return Rect2(36,28,160,155)
		"pastry":return Rect2(10,40,210,132)
		"caligraphy":return Rect2(9,39,212,138)
	return Rect2()
func region(i: int) -> Rect2:
	if rule.grid_count:
		var field:=squares();var w:int=rule.grid_width
		var cell:=field.size/Vector2(w,ceili(float(rule.grid_count)/w))
		return Rect2(field.position+Vector2(i%w,i/w)*cell,cell)
	match rule.house:
		"herbal":return Rect2(7+i*73,143,68,36)
		"audience":return Rect2(12+i*71,35,64,117)
		"hostel":return Rect2(30+rule.data.x[i]*39-23,35+rule.data.y[i]*29-17,46,36)
		"baihe":return Rect2(11+i*52,57,49,71)
		"books":return Rect2(14+i*40,105,37,41)
		"garden":
			var trunk:=53.+floori(i/3.)*116.
			var center:=Vector2(trunk+[0,-35,35][i%3], [119,71,64][i%3])
			return Rect2(center-Vector2(19,19),Vector2(38,38))
		"farmhouse":return Rect2(13,34+i*40,204,38)
		"tailorhome":return Rect2(7,30+i*25,205,24)
		"music","pipa":return Rect2(3+i*44,32,44,138)
		"stage":return Rect2(5+i*55,43,54,116)
		"dojo":return Rect2(19+i*99,49,91,104)
		"banquet":
			var at:=Vector2(110,102)+Vector2.from_angle(i*PI*.5)*57
			return Rect2(at-Vector2(24,22),Vector2(48,44))
		"incense":return Rect2(9+i*71,36,69,143)
		"oil":return Rect2(5+i*44,138,42,47)
		"noodle":
			var spacing:=198./float(rule.data.length)
			return Rect2(16+(i+.5)*spacing,56,spacing,97)
	return Rect2()
func local_scale() -> float:return minf(size.x/230.,size.y/188.)
func origin() -> Vector2:return (size-Vector2(230,188)*local_scale())*.5
func update_objects(locked: bool) -> void:
	if objects.size()!=count_objects():
		for b in objects:remove_child(b);b.queue_free()
		objects.clear()
		for i in count_objects():
			var b:=Button.new();b.flat=true;b.mouse_default_cursor_shape=CURSOR_POINTING_HAND;b.focus_mode=FOCUS_ALL
			for style in ["normal","hover","pressed","disabled","focus","hover_pressed"]:b.add_theme_stylebox_override(style,StyleBoxEmpty.new())
			b.mouse_entered.connect(func():hover_index=i;queue_redraw())
			b.mouse_exited.connect(func():hover_index=-1;queue_redraw())
			b.focus_entered.connect(queue_redraw);b.focus_exited.connect(queue_redraw)
			b.pressed.connect(func():pressed_object.emit(i))
			add_child(b);objects.append(b)
	for i in objects.size():
		var label_:String=str(rule.labels[i]);var b:=objects[i]
		b.disabled=locked or not rule.enabled(i);b.accessibility_name=label_
		b.tooltip_text=("%d 行 %d 列 · "%[i/rule.grid_width+1,i%rule.grid_width+1] if rule.grid_count else "")+label_
	position_objects();queue_redraw()
func position_objects() -> void:
	if rule==null:return
	for i in objects.size():
		var rect:=region(i)
		objects[i].position=origin()+rect.position*local_scale()
		objects[i].size=rect.size*local_scale()
func _ready() -> void:
	super()
	resized.connect(position_objects)
	gui_input.connect(clay_drag)
	mouse_filter=MOUSE_FILTER_STOP
func clay_drag(event: InputEvent) -> void:
	if rule==null or rule.house!="potter" or rule.done or not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return
	var p:Vector2=(event.position-origin())/local_scale()
	var band:=clampi(roundi((p.y-52)/46.),0,2)
	if event.pressed:clay_start=band if p.x>44 and p.x<184 else -1
	elif clay_start>=0:
		var actions:Dictionary={Vector2i(0,1):0,Vector2i(1,0):1,Vector2i(1,2):2,Vector2i(2,1):3}
		var key:=Vector2i(clay_start,band);clay_start=-1
		if actions.has(key):pressed_object.emit(actions[key]);accept_event()
func feedback(i: int,reduced: bool) -> void:
	if reduced:return
	last_press=i;glint=1.
	var tween:=create_tween()
	tween.tween_method(func(t:float):glint=t;queue_redraw(),1.,0.,.24)
func _draw() -> void:
	if rule==null:return
	if rule.grid_count:
		draw_set_transform(origin(),0,Vector2.ONE*local_scale())
		draw_board()
	elif rule.house=="oil":
		super()
		for i in count_objects():
			var rr:=region(i).grow(-1.5)
			draw_rect(rr,Color("c6a779") if not rule.active(i) else JADE)
			piece(10,rr.get_center()-Vector2(0,6),Vector2(29,28))
			txt(rr.position.x+4,rr.end.y-4,str(rule.labels[i]),12,DARK)
	else:super()
	if rule.house=="potter":
		for i in 3:txt(181,57+i*46,["口","腹","足"][i],15)
	for i in objects.size():
		var rect:=region(i).grow(-1.)
		if ((i==hover_index and not objects[i].disabled) or objects[i].has_focus()):
			draw_rect(rect,GOLD,false,2.,true)
		if last_press==i and glint>0:draw_rect(rect,Color(GOLD,glint*.26))
func draw_board() -> void:
	var h:String=rule.house;var d:Dictionary=rule.data;var v:Array=rule.v
	var grid_area:=squares()
	tag({"weir":"水务沙盘","archive":"文渊旧舆图","sail":"南津航图","paper":"套色花笺","basket":"席心 · 看行列挑篾","pastry":"竹笼 · 排杏花模","carver":"手中印石","stitch":"燕尾 · 运针","silversmith":"钗心 · 錾银","chamber":"栖梧星盘","caligraphy":"墨池残帖"}[h])
	var stock:=Color("d3b98b")
	if h in ["paper","caligraphy","carver"]:stock=Color("efdebb")
	if h in ["weir","archive","sail"]:stock=Color("b8b786")
	if h in ["chamber","silversmith"]:stock=Color("29474b")
	draw_rect(grid_area.grow(2),GOLD);draw_rect(grid_area,stock)
	for i in rule.grid_count:
		var tile:=region(i);var p:=tile.get_center();var x:=p.x;var y:=p.y
		draw_rect(tile,Color(DARK,.31),false,1.)
		match h:
			"weir","sail","archive":
				var ground:String=d.map[i] if h=="weir" else ("#" if h=="sail" and i in d.reefs else ".")
				var opened:bool=i in v and h=="weir"
				if opened or h=="sail":draw_rect(tile.grow(-.4),Color("79a797"))
				if ground=="#":
					piece(4,p,tile.size*Vector2(.84,.92))
					continue
				if h=="weir":
					for j in 3:
						var at:=tile.position+Vector2(5+j*9,6+(i+j)%4);draw_line(at,at+Vector2(4,-2),Color("919268"),1)
					if opened:
						for n in rule.neighbors(i,6,24):
							if n in v:draw_line(p,p+(region(n).get_center()-p)*.51,Color("487f78"),5,true)
					match ground:
						"R","M","F","S":
							piece({"R":1,"M":2,"F":3,"S":0}[ground],p-Vector2(0,4),Vector2(24,24))
							txt(x-10,y+16,{"R":"稻田","M":"桑田","F":"鱼塘","S":"泉眼"}[ground],10,DARK)
						_:
							if not rule.done and rule.enabled(i):draw_arc(p,6,0,TAU,16,Color("76623d"),1.5);txt(x-3,y+3,"+",10,DARK)
				elif h=="archive":
					if i in d.beacons:
						panel(x-6,y-11,12,20,Color("776e54"));txt(x-5,y+5,"甲" if i==d.beacons[0] else "乙",10,CREAM)
					else:txt(x-3,y+3,"·",17,DARK)
				else:
					if i==v[0]:piece(5,p,Vector2(38,37))
					elif i==rule.goal[1] or (i==rule.goal[0] and rule.step==0):piece(7 if i==rule.goal[1] else 6,p,Vector2(31,33))
					else:seg(x-7,y+2,x+6,y,CREAM,1.3)
			"basket":
				var on:bool=i in v;draw_rect(tile.grow(-1),Color("c19a5e") if on else Color("dec695"))
				for j in 4:
					var pos:Vector2=tile.position+Vector2(5+j*8,5+j*8)
					if on:seg(tile.position.x+2,pos.y,tile.end.x-2,pos.y,Color("946c42"),2)
					else:seg(pos.x,tile.position.y+2,pos.x,tile.end.y-2,Color("ad8d5b"),2)
			"paper":pass
			"carver":
				if i in v:draw_rect(tile.grow(-2),Color("b55343"))
			"caligraphy":
				if rule.v[i]!=5:
					draw_rect(tile.grow(-1.6),CREAM);txt(x-9,y+7,rule.labels[i],22,DARK)
				else:draw_rect(tile.grow(-2),Color("9c9279"))
			"stitch":pass
			"pastry":
				if i in d.block:dot(x,y,10,Color("776957"))
				else:
					dot(x,y,15,Color("b28d54"));dot(x,y,12,Color("dcba7c"))
					if i in v:piece(8,p,Vector2(34,32))
					if i==rule.picked:draw_arc(p,17,0,TAU,28,DARK,2)
			"chamber","silversmith":
				if h=="chamber":dot(x,y,6 if i in v else 3,GOLD if i in v else CREAM)
				elif i in d.pins:dot(x,y,5,Color("c59057"))
				elif i==v[0]:dot(x,y,10,Color("b9c7bf"));dot(x-2,y-3,3,CREAM)
				elif i==rule.goal[0]:flower(p,14,0,RED)
				elif rule.enabled(i):draw_arc(p,5,0,TAU,12,GOLD,1)
	if h=="paper":
		var layers:Array=album if not album.is_empty() else d.layers
		for layer in layers:flower(region(layer[0]).get_center(),17,layer[1],PALETTE[layer[2]])
		if layers.is_empty() or (hover_index>=0 and hover_index<9 and album.is_empty()):
			flower(region(hover_index if hover_index>=0 and hover_index<9 else 4).get_center(),15,d.motif,Color(PALETTE[d.ink],.32))
	if h=="basket":
		for j in 3:
			txt(region(j).get_center().x-8,43,rule.runs([j,j+3,j+6]),14);txt(16,region(j*3).get_center().y+5,rule.runs([j*3,j*3+1,j*3+2]),14)
	if h=="stitch":
		for e in d.edges:
			draw_line(region(int(e)/9).get_center(),region(int(e)%9).get_center(),Color("a34b3d") if e in v else Color("8b836b"),3,true)
		for j in 9:
			var p:=region(j).get_center();draw_circle(p,8,Color("a44d3d") if j==rule.picked else CREAM);txt(p.x-4,p.y+4,str(j+1),12,DARK if j!=rule.picked else CREAM)
	if h=="chamber":
		for j in range(1,v.size()):draw_line(region(v[j-1]).get_center(),region(v[j]).get_center(),GOLD,2,true)
		var start:=region(rule.goal[0]).get_center();txt(start.x+6,start.y+4,"起",11)
