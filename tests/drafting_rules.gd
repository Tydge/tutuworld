extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const E=preload("res://scripts/building/room_edit.gd")
const G=preload("res://scripts/building/grid_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func room(a: Vector2,b: Vector2,base: Dictionary=L.empty(),level: int=0) -> Dictionary:
	var context:=E.prepare(base,level);var result:=E.create(context,Rect2(a,b-a),{});check(result.ok,"Room plan "+str(a)+str(b)+result.get("message",""))
	return L.normalize(E.materialize(context,result)) if result.ok else base
func wall(data: Dictionary,level: int,p: Vector2,camera: Vector2) -> Dictionary:
	var grid:=L.compiled(data,level)
	for edge in grid.walls:
		var ends:=G.ends(edge);var a:=G.point(ends[0]);var b:=G.point(ends[1])
		if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<.001:
			var unit:=L.unit_at(data,grid.walls[edge].id,(a+b)*.5);return E.wall_context(E.prepare(data,level),unit,camera)
	return {}
func run() -> void:
	var data:=room(Vector2(70,0),Vector2(74,4));check(L.compiled(data).floors.size()==64 and L.compiled(data).walls.size()==32,"Drag room creates floor and four walls")
	var left:=wall(data,0,Vector2(70,2),Vector2(65,2));check(not left.is_empty(),"Closed room wall is resizable")
	var grown:=E.resize(left,-2);check(grown.ok,"Grow 4x4 room to 5x4: "+grown.get("message",""))
	if grown.ok:
		check(grown.bounds.size==Vector2(5,4),"One metre drag gives exact 5x4 dimensions")
		check(L.validate(E.materialize(left.base,grown)).ok,"Expanded room fully validates")
	var shrunk:=E.resize(left,2);check(shrunk.ok and shrunk.bounds.size==Vector2(3,4),"Shrink 4x4 to 3x4")
	check(not E.resize(left,8).ok,"Cannot collapse or invert the room")
	var second:=room(Vector2(74,0),Vector2(78,4),data);var middle:=wall(second,0,Vector2(74,2),Vector2(72,2));var changed:=E.resize(middle,2)
	check(changed.ok,"Shared partition moves: "+changed.get("message",""))
	if changed.ok:
		var widths: Array=[]
		for cells in changed.rooms.values():widths.append(E.bounds(cells).size.x)
		widths.sort();check(widths==[3.,5.] and changed.grid.floors.size()==128,"One room grows while neighbor shrinks; combined floor unchanged")
		check(L.validate(E.materialize(middle.base,changed)).ok,"Shared-wall result fully validates")
	data=L.add(data,{"type":"object","kind":"bookshelf","position":[70.55,2.],"yaw":90.})
	var shelf: String=data.elements[-1].id
	data=L.add(data,{"type":"object","kind":"standing_book","position":[70.55,2.],"yaw":90.,"support":shelf,"support_level":1})
	var book: String=data.elements[-1].id
	var wall_id: String=L.compiled(data).walls[Vector3i(140,2,1)].id
	data=L.add(data,{"type":"window","wall":wall_id,"offset":2.});data=L.normalize(data)
	check(not data.elements.is_empty(),"Attached shelf/book/window fixture validates")
	left=wall(data,0,Vector2(70,2),Vector2(65,2));var snapshot:=JSON.stringify(data);grown=E.resize(left,-2)
	check(grown.ok and grown.moves.has(shelf) and grown.moves.has(book),"Wall-adjacent furniture and supported decorations follow the wall")
	if grown.ok:
		var next:=L.validate(E.materialize(left.base,grown));check(next.ok,"Moved window and furniture fully validate: "+next.get("message",""))
		if next.ok:
			check(is_equal_approx(L.find(next.layout,shelf).position[0],69.55) and L.find(next.layout,book).support==shelf,"Furniture distance and decoration attachment remain intact")
			check(next.layout.elements.filter(func(row):return row.type=="window")[0].anchor[0]==69.,"Window follows wall plane")
	check(JSON.stringify(data)==snapshot,"Preview never mutates source layout or IDs")
	var unsupported:=room(Vector2(90,0),Vector2(94,4));unsupported=room(Vector2(90,0),Vector2(94,4),unsupported,1)
	var upper:=wall(unsupported,1,Vector2(90,2),Vector2(85,2));check(not E.resize(upper,-2).ok,"2F expansion requires lower-floor support")
	var lower:=wall(unsupported,0,Vector2(90,2),Vector2(85,2));check(not E.resize(lower,2).ok,"1F shrink cannot leave upper floor unsupported")
	var occupied:=room(Vector2(70,0),Vector2(74,4));occupied=L.add(occupied,{"type":"object","kind":"woven_basket","position":[70.675,2.],"yaw":0.});occupied=L.add(occupied,{"type":"object","kind":"woven_basket","position":[72.5,2.],"yaw":0.});occupied=L.normalize(occupied)
	var blocked:=E.resize(wall(occupied,0,Vector2(70,2),Vector2(65,2)),2);check(not blocked.ok,"Shrinking with a carried-object collision is refused")
	var square:=room(Vector2(100,0),Vector2(104,4))
	for entry in [[Vector2(100,2),Vector2(95,2),-2],[Vector2(104,2),Vector2(109,2),2],[Vector2(102,0),Vector2(102,-5),-2],[Vector2(102,4),Vector2(102,9),2]]:
		var ctx:=wall(square,0,entry[0],entry[1]);var extension:=E.resize(ctx,entry[2]);var reduction:=E.resize(ctx,-entry[2])
		check(extension.ok and is_equal_approx(extension.bounds.get_area(),20.) and L.validate(E.materialize(ctx.base,extension)).ok,"Every exterior side expands and validates: "+str(entry[0]))
		check(reduction.ok and is_equal_approx(reduction.bounds.get_area(),12.) and L.validate(E.materialize(ctx.base,reduction)).ok,"Every exterior side shrinks and validates: "+str(entry[0]))
	var backwards:=E.resize(middle,-2);check(backwards.ok and backwards.grid.floors.size()==128 and L.validate(E.materialize(middle.base,backwards)).ok,"Shared partition also moves in the opposite direction")
	var roofed:=L.add(square,{"type":"roof","a":[100.,0.],"b":[104.,4.]});roofed=L.normalize(roofed)
	var roof_context:=wall(roofed,0,Vector2(100,2),Vector2(95,2));var roof_result:=E.resize(roof_context,-2)
	check(roof_result.ok and L.rect(roof_result.roofs.values()[0]).size==Vector2(5,4) and L.validate(E.materialize(roof_context.base,roof_result)).ok,"Matching roof edge follows the enlarged room")
	var door_room:=L.add(square,{"type":"door","wall":L.compiled(square).walls[Vector3i(202,0,0)].id,"offset":2.});door_room=L.normalize(door_room)
	check(not E.resize(wall(door_room,0,Vector2(100,2),Vector2(95,2)),4).ok,"Shrinking cannot squeeze an end-wall doorway into a corner")
	var outside:=L.add(L.add(square,{"type":"floor","a":[98.,0.],"b":[100.,4.]}),{"type":"object","kind":"woven_basket","position":[99.,2.],"yaw":0.});outside=L.normalize(outside)
	check(not E.resize(wall(outside,0,Vector2(100,2),Vector2(95,2)),-3).ok,"Expansion is refused when outdoor-area furniture occupies the new room")
	var lower_roof:=L.add(square,{"type":"roof","a":[100.,0.],"b":[104.,4.]});var upper_context:=E.prepare(lower_roof,1);var upstairs:=E.create(upper_context,Rect2(100,0,4,4),{})
	check(upstairs.ok and L.validate(E.materialize(upper_context,upstairs)).ok and not E.materialize(upper_context,upstairs).elements.any(func(row):return row.type=="roof" and int(row.get("storey",0))==0),"Drawing supported upstairs room replaces fully covered lower roof")
	var supported:=L.add(square,{"type":"floor","a":[98.,0.],"b":[100.,4.]});supported=room(Vector2(100,0),Vector2(104,4),supported,1)
	var upper_context2:=wall(supported,1,Vector2(100,2),Vector2(95,2));var supported_result:=E.resize(upper_context2,-2)
	check(supported_result.ok and L.validate(E.materialize(upper_context2.base,supported_result)).ok,"Upper expansion succeeds when the lower floor provides full support")
	var unsupported_lamp:=L.add(supported,{"type":"object","kind":"pendant","position":[100.6,2.],"yaw":0.,"support":"ceiling:0"});unsupported_lamp=L.normalize(unsupported_lamp)
	check(not E.resize(wall(unsupported_lamp,1,Vector2(100,2),Vector2(95,2)),2).ok,"Upper shrink preserves ceiling support for a lower-floor lamp")
	var stair_room:=room(Vector2(110,-5),Vector2(128,25));stair_room=room(Vector2(110,-5),Vector2(128,25),stair_room,1);stair_room=L.add(stair_room,{"type":"stairs","position":[119.,10.],"form":"straight","yaw":0.});stair_room=L.normalize(stair_room)
	check(not stair_room.elements.is_empty(),"Valid room with stairs fixture")
	check(not E.resize(wall(stair_room,1,Vector2(110,10),Vector2(105,10)),22).ok,"Moving a wall through stairs or its landing is refused")
	check(not unsupported_lamp.elements.is_empty(),"Supported lower-floor lamp fixture validates")
	var dining_room:=room(Vector2(100,0),Vector2(106,6));dining_room=L.add(dining_room,{"type":"object","kind":"dining_table","position":[101.8,3.],"yaw":0.});var dining_table: Dictionary=dining_room.elements[-1]
	for slot in preload("res://scripts/building/dining.gd").slots(dining_table).slice(2,4):dining_room=L.add(dining_room,{"type":"object","kind":"dining_chair","position":[slot.position.x,slot.position.y],"yaw":slot.yaw})
	dining_room=L.normalize(dining_room);check(not dining_room.elements.is_empty(),"Near-wall dining set fixture validates")
	var dining_context:=wall(dining_room,0,Vector2(100,3),Vector2(95,3));var dining_result:=E.resize(dining_context,-2)
	check(dining_result.ok and dining_result.moves.size()==3 and L.validate(E.materialize(dining_context.base,dining_result)).ok,"Room wall carries near-wall table and its associated chairs as one set")
	check(not E.create(E.prepare(lower_roof,1),Rect2(100,0,2,4),{}).ok,"Partial upstairs room cannot silently intersect a lower roof")
	var large:=room(Vector2(100,-6),Vector2(140,26));var prepared:=wall(large,0,Vector2(100,10),Vector2(95,10));var times: Array=[]
	for i in range(12):
		var start:=Time.get_ticks_usec();E.resize(prepared,-1-i%4);times.append((Time.get_ticks_usec()-start)/1000.)
	times.sort();print("DRAFT_PREVIEW_MS median=",times[times.size()/2]," p95=",times[-1])
	print("DRAFTING_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
