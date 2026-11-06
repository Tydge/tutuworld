extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const E=preload("res://scripts/building/storey_extension.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func walls(layout: Dictionary,a: Vector2,b: Vector2) -> Dictionary:
	for pair in [[a,Vector2(b.x,a.y)],[Vector2(b.x,a.y),b],[b,Vector2(a.x,b.y)],[Vector2(a.x,b.y),a]]:layout=L.add(layout,{"type":"wall","a":[pair[0].x,pair[0].y],"b":[pair[1].x,pair[1].y]})
	return layout
func run() -> void:
	for form in Stairs.FORMS:
		for turn in [0.,90.,180.,270.]:
			for level in [0,1,2]:
				var base:=L.add(L.empty(),{"type":"floor","a":[100.,-6.],"b":[140.,26.],"storey":level,"color":"cda56e","style":"herringbone"});var before:=JSON.stringify(base)
				var row:={"type":"stairs","position":[120.,10.],"form":form,"yaw":turn,"storey":level}
				var candidate:=E.place_stair(base,row);var result:=L.validate(candidate);var preview:=E.preview_stair(base,row)
				check(result.ok and preview.ok,"Stairs first: %s/%d/%d %s"%[form,turn,level,result.get("message","")])
				check(L.compiled(candidate,level+1).floors.size()==5120-Stairs.hole_cells(row).size(),"First stair generates the connected upstairs floor while preserving its opening")
				check(G.covered(Stairs.world_rect(row,Stairs.definition(form).top),L.walkable_grid(candidate,level+1).floors),"Auto landing is actually walkable at top endpoint")
				check(L.compiled(candidate,level+1).floors.values().all(func(floor_):return floor_.style=="herringbone"),"Landing inherits lower entry finish")
				var guards:=Stairs.upper_guard_edges(row,L.walkable_grid(candidate,level+1).floors);var length_:=0.
				for edge in guards:length_+=L.rect(edge).size.length()
				var end: Vector3=Stairs.route(row)[-1];var direction: Vector3=Stairs.route(row)[-1]-Stairs.route(row)[-2];direction.y=0;direction=direction.normalized()
				var exit: Vector2=Stairs.local_point(row,Vector2(end.x,end.z))+Vector2(direction.x,direction.z).rotated(deg_to_rad(turn))*1.5
				check(not guards.any(func(edge):return Geometry2D.get_closest_point_to_segment(exit,Vector2(edge.a[0],edge.a[1]),Vector2(edge.b[0],edge.b[1])).distance_to(exit)<.01),"A real floor beyond the landing keeps its exit open")
				check(JSON.stringify(base)==before,"Stair preview and plan never mutate base")
				if level==0:
					var plan:=E.plan(result.layout,0,Vector2(120,20));check(not plan.ok and plan.get("message","").contains("已经铺好"),"First stair has already completed the upper floor")
					if plan.ok:
						for cell in Stairs.hole_cells(row):check(not L.compiled(plan.layout,1).floors.has(cell),"New slab preserves the stair opening")
	var base:=L.add(L.empty(),{"type":"floor","a":[100.,-6.],"b":[140.,26.]})
	var stair:={"type":"stairs","position":[120.,10.],"form":"u","yaw":0.}
	base=L.add(base,{"type":"floor","a":[120.,12.],"b":[121.5,15.],"storey":1,"color":"f4e8cf","style":"cottage_tile"})
	var checked:=L.validate(E.place_stair(base,stair));check(checked.ok,"Partial existing landing can be completed")
	if checked.ok:check(L.compiled(checked.layout,1).floors.values().filter(func(row):return row.style=="cottage_tile").size()==18,"Existing landing finish is untouched")
	check(not E.preview_stair(L.empty(),stair).ok,"A lower entry floor is still required")
	var roof:=L.add(base,{"type":"roof","a":[100.,-6.],"b":[140.,26.]})
	check(not E.preview_stair(roof,stair).ok,"Stairs cannot silently cut a solid old roof")
	var small:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[82.,10.],"style":"herringbone"})
	small=walls(small,Vector2(70,0),Vector2(82,10));small=L.add(small,{"type":"wall","a":[76.,0.],"b":[76.,10.]})
	small=L.add(small,{"type":"floor","a":[82.,4.],"b":[94.,6.]})
	small=L.add(small,{"type":"floor","a":[94.,0.],"b":[102.,10.]});small=walls(small,Vector2(94,0),Vector2(102,10))
	small=L.add(small,{"type":"floor","a":[71.,1.],"b":[73.,3.],"storey":1,"color":"f4e8cf","style":"cottage_tile"})
	var original:=JSON.stringify(small);var plan:=E.plan(small,0,Vector2(72,2))
	check(plan.ok,"Connected indoor rooms form an upstairs plan")
	if plan.ok:
		check(is_equal_approx(plan.area,116.),"Copy connected rooms, excluding connecting outdoor path and second house")
		var floors: Dictionary=L.compiled(plan.layout,1).floors
		check(floors.size()==480 and not floors.has(G.cell(Vector2(90,5))) and not floors.has(G.cell(Vector2(96,2))),"No road, patio or other house is copied")
		check(floors[G.cell(Vector2(72,2))].style=="cottage_tile","An existing upstairs tile keeps its finish")
	check(JSON.stringify(small)==original,"Upstairs preview leaves source layout unchanged")
	check(not E.plan(small,3,Vector2(72,2)).ok,"Fifth floor is rejected")
	check(not E.plan(small,0,Vector2(110,24)).ok,"Empty ground is not treated as a house")
	var shape:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[74.,10.]});shape=L.add(shape,{"type":"floor","a":[74.,6.],"b":[80.,10.]})
	var shaped:=E.plan(shape,0,Vector2(72,2));check(shaped.ok and shaped.area==64.,"Unwalled L-shaped foundation preserves its concave outline")
	shape=L.add(shape,{"type":"roof","a":[70.,0.],"b":[74.,10.]});var replaced:=E.plan(shape,0,Vector2(72,2))
	check(replaced.ok and replaced.removed_roofs==1 and replaced.layout.elements.all(func(row):return row.type!="roof"),"Complete upper slab replaces old roof in the same plan")
	var manual:=L.add(E.place_stair(base,stair),{"type":"railing","a":[120.,15.],"b":[123.,15.],"storey":1})
	var guarded:=Stairs.upper_guard_edges(stair,L.walkable_grid(manual,1).floors,Stairs.explicit_guard_edges(manual,1));var length_:=0.
	for edge in guarded:length_+=L.rect(edge).size.length()
	check(is_equal_approx(length_,6.),"Authored landing railing replaces automatic edge instead of overlapping it")
	print("STOREY_EXTENSION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
