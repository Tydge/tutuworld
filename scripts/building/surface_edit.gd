extends RefCounted
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const R=preload("res://scripts/building/room_plan.gd")
const C=preload("res://scripts/building/structure_catalog.gd")
static func room_sides(plan: Dictionary,row: Dictionary) -> Dictionary:
	var p:=L.rect(row).get_center();var n:=C.normal(row)*.26
	return {"positive":R.room_at(plan,p+n,false),"negative":R.room_at(plan,p-n,false)}
static func inside_side(plan: Dictionary,row: Dictionary,camera: Vector2) -> String:
	var sides:=room_sides(plan,row)
	if sides.positive!="" and sides.negative=="":return "positive"
	if sides.negative!="" and sides.positive=="":return "negative"
	return "positive" if (camera-L.rect(row).get_center()).dot(C.normal(row))>=0. else "negative"
static func paint(layout: Dictionary,unit: Dictionary,color: Color,style: String,batch: bool,face_mode: int,camera: Vector2) -> Dictionary:
	var source:=L.compiled(layout,int(unit.get("storey",0)));var plan:=R.make(source)
	var grid:={"floors":source.floors.duplicate(),"walls":source.walls.duplicate()}
	var finish:={"color":color.to_html(false),"style":style,"painted":true}
	if unit.type=="floor":
		var first: Vector2i=G.coordinates(unit)[0];var room:=R.room_at(plan,G.point(first)+Vector2.ONE*.25);var match_key:=C.surface_key(unit)
		for c in grid.floors:
			if c!=first and (not batch or room=="" or plan.cell_rooms.get(c,"")!=room or C.surface_key(grid.floors[c])!=match_key):continue
			var row: Dictionary=grid.floors[c].duplicate(true);row.merge(finish,true);grid.floors[c]=row
	else:
		var first: Vector3i=G.edges(unit)[0];var inside:=inside_side(plan,unit,camera)
		var room: String=room_sides(plan,unit)[inside]
		if batch and face_mode==1 and room!="":return paint_exterior(layout,unit,plan,room,finish)
		for edge in grid.walls:
			var row: Dictionary=grid.walls[edge].duplicate(true);var target_inside:=inside
			if edge!=first:
				if not batch or room=="":continue
				var sides:=edge_rooms(plan,edge)
				if sides.positive!=room and sides.negative!=room:continue
				target_inside="positive" if sides.positive==room else "negative"
			if face_mode==2:row.merge(finish,true);row.erase("faces")
			else:
				var target_side:=target_inside if face_mode==0 else opposite(target_inside)
				row["faces"]=row.get("faces",{}).duplicate(true);row.faces[target_side]=finish.duplicate()
			grid.walls[edge]=row
	return G.compress(layout,grid,int(unit.get("storey",0)))
static func opposite(side: String) -> String:return "negative" if side=="positive" else "positive"
static func edge_rooms(plan: Dictionary,edge: Vector3i) -> Dictionary:
	var a:=Vector2i(edge.x,edge.y);var b:=a-(Vector2i.DOWN if edge.z==0 else Vector2i.RIGHT)
	return {"positive":plan.cell_rooms.get(a,""),"negative":plan.cell_rooms.get(b,"")}
static func paint_exterior(layout: Dictionary,unit: Dictionary,plan: Dictionary,room: String,finish: Dictionary) -> Dictionary:
	var level:=int(unit.get("storey",0));var seed: Vector2i=plan.rooms[room].cells.keys()[0]
	var extension=preload("res://scripts/building/storey_extension.gd")
	var layers: Dictionary={level:extension.footprint(L.compiled(layout,level),G.point(seed)+Vector2.ONE*.25)}
	# Rooms on adjacent storeys with overlapping enclosed footprints form this house.
	for direction in [-1,1]:
		var previous: Dictionary=layers[level]
		for step in range(1,4):
			var story: int=level+step*direction
			if story<0 or story>=4:break
			var source:=L.compiled(layout,story);var story_plan:=R.make(source);var cells: Dictionary={}
			for c in previous:
				if story_plan.cell_rooms.has(c) and not cells.has(c):cells.merge(extension.footprint(source,G.point(c)+Vector2.ONE*.25))
			if cells.is_empty():break
			layers[story]=cells;previous=cells
	var next:=layout
	for story in layers:
		var source:=L.compiled(next,story);var story_plan:=R.make(source);var cells: Dictionary=layers[story]
		var changed:={"floors":source.floors.duplicate(),"walls":source.walls.duplicate()}
		for edge in changed.walls:
			var a:=Vector2i(edge.x,edge.y);var b:=a-(Vector2i.DOWN if edge.z==0 else Vector2i.RIGHT)
			if cells.has(a)==cells.has(b):continue
			var outside: Vector2i=b if cells.has(a) else a
			if story_plan.cell_rooms.has(outside):continue
			var row: Dictionary=changed.walls[edge].duplicate(true)
			row["faces"]=row.get("faces",{}).duplicate(true);row.faces["negative" if cells.has(a) else "positive"]=finish.duplicate()
			changed.walls[edge]=row
		next=G.compress(next,changed,story)
	return next
