extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const E=preload("res://scripts/building/room_edit.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const P=preload("res://scripts/building/surface_edit.gd")
const C=preload("res://scripts/building/structure_catalog.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func room(data: Dictionary,level: int,a: Vector2,b: Vector2) -> Dictionary:
	var base:=E.prepare(data,level);var result:=E.create(base,Rect2(a,b-a),{})
	check(result.ok,"Room fixture "+str(level)+result.get("message",""))
	return L.normalize(E.materialize(base,result)) if result.ok else data
func unit(data: Dictionary,level: int,p: Vector2) -> Dictionary:
	for edge in L.compiled(data,level).walls:
		var ends:=G.ends(edge);var a:=G.point(ends[0]);var b:=G.point(ends[1])
		if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<.001:return L.unit_at(data,L.compiled(data,level).walls[edge].id,(a+b)*.5)
	return {}
func resize(data: Dictionary,level: int,p: Vector2,delta: int) -> Dictionary:
	var ctx:=E.wall_context(E.prepare(data,level),unit(data,level,p),p+Vector2(2,2));var result:=E.resize(ctx,delta)
	check(result.ok,"Stack resize "+str(p)+" "+str(delta)+result.get("message",""))
	return E.materialize(ctx.base,result) if result.ok else data
func run() -> void:
	var data:=L.empty()
	for level in range(4):data=room(data,level,Vector2(90,0),Vector2(98,8))
	data=L.normalize(L.add(data,{"type":"roof","storey":3,"a":[90.,0.],"b":[98.,8.]}))
	var original:=JSON.stringify(data)
	for entry in [[Vector2(90,2),-2],[Vector2(98,2),2],[Vector2(92,0),-2],[Vector2(92,8),2]]:
		for direction in [1,-1]:
			var next:=resize(data,0,entry[0],entry[1]*direction)
			check(L.validate(next).ok,"All four sides and directions fully validate")
			for level in range(4):check(L.compiled(next,level).floors.size()==256+32*direction,"Every slab follows at level "+str(level))
			var roof: Dictionary=next.elements.filter(func(row):return row.type=="roof")[0]
			check(is_equal_approx(L.rect(roof).get_area(),64+8*direction),"Top roof follows changed footprint")
	check(JSON.stringify(data)==original,"Stack plans preserve source records and IDs")
	# Different partitions between floors must not leave a strip of missing upstairs.
	var split:=room(L.empty(),0,Vector2(90,0),Vector2(94,4));split=room(split,0,Vector2(90,4),Vector2(94,8));split=room(split,1,Vector2(90,0),Vector2(94,8))
	split=L.normalize(L.add(split,{"type":"roof","storey":1,"a":[90.,0.],"b":[94.,8.]}))
	var extended:=resize(split,0,Vector2(90,2),-2)
	check(L.compiled(extended,0).floors.size()==160 and L.compiled(extended,1).floors.size()==160 and L.validate(extended).ok,"Different partitions carry the complete aligned facade, slabs and roof")
	var setback:=room(L.empty(),0,Vector2(90,0),Vector2(98,8));setback=room(setback,1,Vector2(90,0),Vector2(98,4));setback=L.normalize(L.add(setback,{"type":"roof","storey":1,"a":[90.,0.],"b":[98.,4.]}))
	var shifted:=resize(setback,0,Vector2(90,2),-2)
	check(L.compiled(shifted,0).floors.size()==288 and L.compiled(shifted,1).floors.size()==144 and L.validate(shifted).ok,"Aligned partial upper facade keeps its intentional setback")
	var unfinished:=room(L.empty(),0,Vector2(90,0),Vector2(98,8));unfinished=L.normalize(L.add(unfinished,{"type":"floor","storey":1,"a":[90.,0.],"b":[98.,8.]}))
	var unfinished_grow:=resize(unfinished,0,Vector2(90,2),-2);var unfinished_shrink:=resize(unfinished,0,Vector2(90,2),2)
	check(L.compiled(unfinished_grow,1).floors.size()==288 and L.validate(unfinished_grow).ok,"Unfinished upper slab follows expansion before its walls are built")
	check(L.compiled(unfinished_shrink,1).floors.size()==224 and L.validate(unfinished_shrink).ok,"Unfinished upper slab follows shrinking without overhang")
	# Nonaligned upper exterior cannot be extended beyond the actual supporting slab.
	var offset:=room(L.empty(),0,Vector2(90,0),Vector2(98,8));offset=room(offset,1,Vector2(91,0),Vector2(98,8))
	var ctx:=E.wall_context(E.prepare(offset,1),unit(offset,1,Vector2(91,2)),Vector2(93,2))
	check(not E.resize(ctx,-4).ok,"Nonaligned upper wall still rejects unsupported expansion")
	# Paint mixed existing finishes across the selected room; preserve opposite sides.
	var selected:=unit(split,0,Vector2(90,2));var mixed:=P.paint(split,selected,Color("ff0000"),"brick",false,0,Vector2(92,2))
	var painted:=P.paint(mixed,selected,Color("00ff00"),"botanical",true,0,Vector2(92,2));var plan: Dictionary=E.prepare(painted,0).plan
	var target: String=P.room_sides(plan,selected)[P.inside_side(plan,selected,Vector2(92,2))]
	var inside_count:=0
	for edge in L.compiled(painted).walls:
		var row: Dictionary=L.compiled(painted).walls[edge];var sides:=P.edge_rooms(plan,edge)
		for side in sides:
			if sides[side]==target:inside_count+=1;check(C.surface(row,side).color=="00ff00","Mixed room wall finish replaced")
	check(inside_count==32,"Exactly the selected closed room was painted")
	var separate:=room(split,0,Vector2(102,0),Vector2(106,4));var external:=P.paint(separate,selected,Color("3366aa"),"stone",true,1,Vector2(92,2))
	for level in [0,1]:
		var grid:=L.compiled(external,level);var info: Dictionary=E.prepare(external,level).plan
		for edge in grid.walls:
			var sides:=P.edge_rooms(info,edge);var row: Dictionary=grid.walls[edge]
			if edge.x>=204:check(C.surface(row,"positive").color!="3366aa" and C.surface(row,"negative").color!="3366aa","Separate house keeps both faces");continue
			if (sides.positive=="")!=(sides.negative==""):
				var outer: String="positive" if sides.positive=="" else "negative"
				check(C.surface(row,outer).color=="3366aa","Every outside face painted on every storey")
				check(C.surface(row,P.opposite(outer)).color!="3366aa","Interior face preserved")
			else:check(C.surface(row,"positive").color!="3366aa" and C.surface(row,"negative").color!="3366aa","Shared partitions preserved")
	check(L.validate(external).ok,"Batch wall painting fully validates")
	for sample in ["single_one","two_storey"]:
		var template:=preload("res://scripts/building/templates.gd").player_sample(sample)
		var points: Array=[[Vector2(71,5),-2],[Vector2(84,5),2],[Vector2(74,3),-2],[Vector2(74,10),2]] if sample=="single_one" else [[Vector2(131,5),-2],[Vector2(147,5),2],[Vector2(134,2.5),-2],[Vector2(134,17.5),2]]
		for pair in points:
			var template_ctx:=E.wall_context(E.prepare(template,0),unit(template,0,pair[0]),pair[0]+Vector2.ONE)
			var changed:=E.resize(template_ctx,pair[1]);check(changed.ok,"Furnished template facade expands: "+sample+str(pair[0])+changed.get("message",""))
			if changed.ok:
				var final:=L.validate(E.materialize(template_ctx.base,changed));check(final.ok,"Furnished template expansion validates: "+sample+str(pair[0])+final.get("message",""))
				if final.ok:
					check(final.layout.elements.filter(func(row):return row.get("kind","")=="wall_mirror").size()==template.elements.filter(func(row):return row.get("kind","")=="wall_mirror").size(),"Template mirrors remain attached")
	print("RELEASE04_BUILDING_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
