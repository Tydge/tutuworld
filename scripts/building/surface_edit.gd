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
		var first: Vector3i=G.edges(unit)[0];var inside:=inside_side(plan,unit,camera);var side:=inside if face_mode==0 else ("negative" if inside=="positive" else "positive")
		var room: String=room_sides(plan,unit)[inside];var match_key:=C.surface_key(unit,side);var whole_key:=C.surface_key(unit,"positive")+":"+C.surface_key(unit,"negative")
		for edge in grid.walls:
			var row: Dictionary=grid.walls[edge].duplicate(true);var target_side:=side
			if edge!=first:
				if not batch or room=="":continue
				var endpoints:=G.ends(edge);var piece:=row.duplicate();piece.a=[endpoints[0].x*.5,endpoints[0].y*.5];piece.b=[endpoints[1].x*.5,endpoints[1].y*.5]
				var sides:=room_sides(plan,piece)
				if sides.positive!=room and sides.negative!=room:continue
				var target_inside: String="positive" if sides.positive==room else "negative"
				target_side=target_inside if face_mode==0 else ("negative" if target_inside=="positive" else "positive")
				if face_mode==2 and C.surface_key(row,"positive")+":"+C.surface_key(row,"negative")!=whole_key:continue
				if face_mode!=2 and C.surface_key(row,target_side)!=match_key:continue
			if face_mode==2:row.merge(finish,true);row.erase("faces")
			else:
				row["faces"]=row.get("faces",{}).duplicate(true);row.faces[target_side]=finish.duplicate()
			grid.walls[edge]=row
	return G.compress(layout,grid,int(unit.get("storey",0)))
