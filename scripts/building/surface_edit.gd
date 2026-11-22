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
static func paint(layout: Dictionary,unit: Dictionary,color: Color,style: String,batch: bool,face_mode: int,camera: Vector2,parcel_id: String="") -> Dictionary:
	if parcel_id=="":return paint_connected(layout,unit,color,style,batch,face_mode,camera)
	var land=preload("res://scripts/building/parcels.gd")
	var original:=L.find(layout,unit.id)
	if original.is_empty() or not land.contains_row(parcel_id,original,layout):return layout
	var local:=layout.duplicate()
	local.elements=layout.elements.filter(func(row):return land.contains_row(parcel_id,row,layout))
	var result:=paint_connected(local,unit,color,style,batch,face_mode,camera)
	result.elements=land.outside(layout,parcel_id)+result.elements
	return result

static func floor_patch(first: Vector2i,grid: Dictionary,plan: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i]=[first]
	var visited: Dictionary={first:true}
	var room: String=plan.cell_rooms.get(first,"")
	var cursor:=0
	while cursor<cells.size():
		var current:=cells[cursor]
		cursor+=1
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next:=current+direction
			if visited.has(next) or not grid.floors.has(next) or plan.cell_rooms.get(next,"")!=room:continue
			var edge:=Vector3i(maxi(current.x,next.x),maxi(current.y,next.y),int(direction.x!=0))
			if grid.walls.has(edge):continue
			visited[next]=true
			cells.append(next)
	return cells

static func wall_patch(first: Vector3i,walls: Dictionary) -> Array[Vector3i]:
	var incident:=G.vertex_degrees(walls)
	var edges: Array[Vector3i]=[first]
	var visited: Dictionary={first:true}
	var cursor:=0
	while cursor<edges.size():
		var edge:=edges[cursor]
		cursor+=1
		for vertex in G.ends(edge):
			for neighbor in incident[vertex]:
				if visited.has(neighbor):continue
				visited[neighbor]=true
				edges.append(neighbor)
	return edges

static func paint_connected(layout: Dictionary,unit: Dictionary,color: Color,style: String,batch: bool,face_mode: int,camera: Vector2) -> Dictionary:
	var source:=L.compiled(layout,int(unit.get("storey",0)));var plan:=R.make(source)
	var grid:={"floors":source.floors.duplicate(),"walls":source.walls.duplicate()}
	var finish:={"color":color.to_html(false),"style":style,"painted":true}
	if unit.type=="floor":
		var first: Vector2i=G.coordinates(unit)[0]
		for c in (floor_patch(first,grid,plan) if batch else [first]):
			var row: Dictionary=grid.floors[c].duplicate(true);row.merge(finish,true);grid.floors[c]=row
	else:
		var first: Vector3i=G.edges(unit)[0];var inside:=inside_side(plan,unit,camera)
		var room: String=room_sides(plan,unit)[inside]
		if batch and face_mode==1 and room!="":return paint_exterior(layout,unit,plan,room,finish)
		for edge in (wall_patch(first,grid.walls) if batch else [first]):
			var row: Dictionary=grid.walls[edge].duplicate(true);var target_inside:=inside
			if edge!=first and room!="" and face_mode!=2:
				var sides:=edge_rooms(plan,edge)
				if sides.positive!=room and sides.negative!=room:continue
				target_inside="positive" if sides.positive==room else "negative"
			elif edge!=first and room=="":target_inside=inside_side(plan,row,camera)
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
	var level:=int(unit.get("storey",0));var seed: Vector2i
	for c in plan.rooms[room].cells:
		if plan.floors.has(c):seed=c;break
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
