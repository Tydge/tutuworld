extends RefCounted
const SAMPLE_NAMES:={"single_one":"温馨小屋","two_storey":"两层楼阁"}
const Layout=preload("res://scripts/building/layout.gd")
static func cottage() -> Dictionary:
	var data:={"schema":1,"next_id":1,"elements":[]}
	data=Layout.add(data,{"type":"floor","a":[73.,5.],"b":[85.,15.],"color":"cda56e","style":"wood"})
	for endpoints in [[[73.,15.],[85.,15.]],[[85.,5.],[73.,5.]],[[73.,5.],[73.,15.]],[[85.,15.],[85.,5.]]]:data=Layout.add(data,{"type":"wall","a":endpoints[0],"b":endpoints[1],"color":"eadcc5","style":"plaster"})
	data=Layout.add(data,{"type":"door","wall":"build_2","offset":6.,"color":"739b8d","style":"wood"})
	data=Layout.add(data,{"type":"window","wall":"build_3","offset":4.,"color":"eee2c6","style":"wood"})
	data=Layout.add(data,{"type":"window","wall":"build_4","offset":4.5,"color":"eee2c6","style":"wood"})
	data=Layout.add(data,{"type":"roof","a":[73.,5.],"b":[85.,15.],"color":"688d81","style":"original"})
	for item in [["bed",82.,8.,0],["sofa",75.,11.5,90],["tea_table",77.,11.5,90],["desk",75.5,7.,0],["bookshelf",84.,12.5,90],["forest_rug",77.5,11.5,0],["forest_planter",84.,6.5,0]]:data=Layout.add(data,{"type":"object","kind":item[0],"position":[item[1],item[2]],"yaw":item[3],"color":"b8c4a3","style":"original"})
	data=Layout.normalize(data)
	data=Layout.add(data,{"type":"object","kind":"pendant","position":[79.,10.],"yaw":0.,"support":"build_9","color":"eadcc5","style":"original"})
	return Layout.validate(data).layout

static func sample_row(data: Dictionary,row: Dictionary,level: int=0) -> Dictionary:
	row=row.duplicate(true);row.storey=level
	for key in ["a","b","position"]:
		if row.has(key):row[key]=[139.+row[key][0],10.+row[key][1]]
	return Layout.add(data,row)
static func sample_wall(data: Dictionary,a: Array,b: Array,level: int=0,openings: Array=[]) -> Dictionary:
	data=sample_row(data,{"type":"wall","a":a,"b":b,"color":"eadcc5","style":"plaster","faces":{"positive":{"color":"e9e1c9","style":"plaster"},"negative":{"color":"d5dfcf","style":"plaster"}}},level)
	var wall: String=data.elements[-1].id
	for hole in openings:
		data=sample_row(data,{"type":hole[0],"wall":wall,"offset":hole[1],"form":hole[2],"color":"739b8d" if hole[0]=="door" else "eee2c6","style":"wood","default_open":hole[3] if hole.size()>3 else true},level)
	return data
static var _two_storey: Dictionary={}
static func two_storey() -> Dictionary:
	if not _two_storey.is_empty():return _two_storey.duplicate(true)
	var data:=Layout.empty()
	for level in [0,1]:data=sample_row(data,{"type":"floor","a":[-8.,-7.5],"b":[8.,7.5],"color":"cda56e","style":"herringbone"},level)
	# Ground floor: generous entrance/gallery, living room and a separate kitchen.
	data=sample_wall(data,[-8.,7.5],[8.,7.5],0,[["door",3.5,"arch"],["window",12.5,"arch"]])
	data=sample_wall(data,[-8.,-7.5],[8.,-7.5],0,[["window",11.5,"classic"]])
	data=sample_wall(data,[-8.,-7.5],[-8.,7.5],0,[["window",12.,"round"]])
	data=sample_wall(data,[8.,-7.5],[8.,7.5],0,[["window",3.5,"classic"],["window",10.5,"arch"]])
	data=sample_wall(data,[-.5,-1.],[8.,-1.],0,[["door",4.5,"glass",false]])
	data=sample_row(data,{"type":"stairs","form":"u","position":[-4.5,-1.5],"yaw":0.,"color":"c6a373","style":"wood"})
	# Upper floor: landing gallery, study, bedroom and an open terrace.
	data=sample_wall(data,[-8.,-7.5],[8.,-7.5],1,[["window",12.5,"arch"]])
	data=sample_wall(data,[-8.,-7.5],[-8.,7.5],1,[["window",12.5,"round"]])
	data=sample_wall(data,[8.,-7.5],[8.,4.5],1,[["window",3.,"classic"],["window",9.,"arch"]])
	data=sample_wall(data,[-8.,7.5],[1.5,7.5],1,[["window",4.5,"arch"]])
	data=sample_wall(data,[1.5,-7.5],[1.5,4.5],1,[["door",2.5,"arch",false],["door",9.,"classic",false]])
	data=sample_wall(data,[1.5,-3.],[8.,-3.],1)
	data=sample_wall(data,[1.5,4.5],[8.,4.5],1,[["door",3.,"glass"]])
	for line in [[[1.5,4.5],[1.5,7.5]],[[1.5,7.5],[8.,7.5]],[[8.,7.5],[8.,4.5]]]:data=sample_row(data,{"type":"railing","a":line[0],"b":line[1],"color":"a78358","style":"wood"},1)
	data=sample_row(data,{"type":"roof","a":[-8.,-7.5],"b":[8.,4.5],"form":"hip","color":"688d81","style":"original"},1)
	data=sample_row(data,{"type":"roof","a":[-8.,4.5],"b":[1.5,7.5],"form":"shed","color":"688d81","style":"original"},1)
	for item in [["cooking_counter",4.5,-6.4,0,0],["forest_cabinet",6.8,-2.2,0,0],["sofa",4.7,3.1,0,0],["tea_table",4.7,5.3,0,0],["forest_rug",4.7,4.2,0,0],["hearth",.3,3.,90,0],["forest_planter",7.,6.5,0,0],["canopy_bed",5.,0.,0,1],["bedside",7.,.2,0,1],["desk",5.,-6.2,180,1],["chair",5.,-4.4,180,1],["bookshelf",7.3,-5.,90,1],["petal_armchair",7.,5.8,270,1],["forest_planter",4.,6.9,0,1],["forest_settee",-4.5,5.8,180,1],["floor_lamp",-7.,6.3,0,1]]:
		data=sample_row(data,{"type":"object","kind":item[0],"position":[item[1],item[2]],"yaw":item[3],"color":"b8c4a3","style":"original"},item[4])
	for item in [["lotus_pendant",4.5,2.,0],["pendant",4.5,-4.,0],["lotus_pendant",2.9,1.,1],["pendant",5.,-4.5,1]]:
		var row:={"type":"object","kind":item[0],"position":[139.+item[1],10.+item[2]],"yaw":0.,"storey":item[3],"color":"eadcc5","style":"original"}
		row=Layout.attach_at(data,row,Vector2(row.position[0],row.position[1]));data=Layout.add(data,row)
	for entry in [["tea_service",4.8,5.3,"tea_table",0],["ceramic_vases",6.8,-2.2,"forest_cabinet",0],["field_journal",5.,-6.2,"desk",1],["table_lamp",7.,.2,"bedside",1]]:
		var parent: Dictionary=data.elements.filter(func(row):return row.get("kind","")==entry[3] and int(row.get("storey",0))==entry[4])[0]
		var row:={"type":"object","kind":entry[0],"position":[139.+entry[1],10.+entry[2]],"yaw":0.,"storey":entry[4],"color":"eadcc5","style":"original"};row=Layout.attach_at(data,row,Vector2(row.position[0],row.position[1]),parent.id);data=Layout.add(data,row)
	for entry in [["pressed_leaves",4.1,-6.2,"desk",1]]:
		var parent: Dictionary=data.elements.filter(func(row):return row.get("kind","")==entry[3] and int(row.get("storey",0))==entry[4])[0]
		var row:={"type":"object","kind":entry[0],"position":[139.+entry[1],10.+entry[2]],"yaw":180.,"storey":entry[4],"color":"eadcc5","style":"original"};row=Layout.attach_at(data,row,Vector2(row.position[0],row.position[1]),parent.id);data=Layout.add(data,row)
	var shelf: Dictionary=data.elements.filter(func(row):return row.get("kind","")=="bookshelf")[0]
	for i in range(5):
		var p:=Vector2(shelf.position[0],shelf.position[1])+preload("res://scripts/building/catalog.gd").rotate_xz(Vector2(-.45+i*.19,.02),float(shelf.yaw))
		data=Layout.add(data,{"type":"object","kind":"standing_book","position":[p.x,p.y],"yaw":shelf.yaw,"storey":1,"support":shelf.id,"support_level":1,"color":["789b8d","bd9a78","b8b58a","9295ab","c6b6a0"][i],"style":"original","painted":true})
	var upper:=Layout.compiled(data,1);upper={"floors":upper.floors.duplicate(),"walls":upper.walls.duplicate()}
	for cell in upper.floors:
		var p:=preload("res://scripts/building/grid_layout.gd").point(cell)+Vector2.ONE*.25
		if p.x>=140.5 and p.y>=14.5:
			var stone: Dictionary=upper.floors[cell].duplicate(true);stone.color="d9cfb5";stone.style="terrazzo";stone.painted=true;upper.floors[cell]=stone
	data=preload("res://scripts/building/grid_layout.gd").compress(data,upper,1)
	var grid:=Layout.compiled(data,0);grid={"floors":grid.floors.duplicate(),"walls":grid.walls.duplicate()}
	var kitchen:=Rect2(138.5,2.5,8.5,6.5)
	for cell in grid.floors:
		if kitchen.has_point(preload("res://scripts/building/grid_layout.gd").point(cell)+Vector2.ONE*.25):
			var tile: Dictionary=grid.floors[cell].duplicate(true);tile.color="f4e8cf";tile.style="cottage_tile";tile.painted=true;grid.floors[cell]=tile
	for edge in grid.walls:
		var ends:=preload("res://scripts/building/grid_layout.gd").ends(edge);var mid: Vector2=Vector2(ends[0]+ends[1])*.25;var side:=""
		if absf(mid.y-2.5)<.01 and mid.x>=138.5:side="positive"
		elif absf(mid.x-147.)<.01 and mid.y<9.:side="negative"
		elif absf(mid.y-9.)<.01 and mid.x>=138.5:side="negative"
		if side!="":
			var wall: Dictionary=grid.walls[edge].duplicate(true);wall.faces=wall.get("faces",{}).duplicate(true);wall.faces[side]={"color":"f2e8d4","style":"glazed_tile","painted":true};grid.walls[edge]=wall
	data=preload("res://scripts/building/grid_layout.gd").compress(data,grid,0)
	_two_storey=data.duplicate(true)
	return data

static var _player_samples: Dictionary={}
static func player_sample(kind: String) -> Dictionary:
	if kind not in ["single_one","two_storey"]:return cottage()
	if not _player_samples.has(kind):
		var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_templates/"+kind+".json"))
		var result:=Layout.validate(raw)
		if not result.ok:push_error("Invalid building template: "+kind+" "+str(result.get("message")));return {}
		_player_samples[kind]=result.layout
	return _player_samples[kind].duplicate(true)
