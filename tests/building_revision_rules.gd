extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const C=preload("res://scripts/building/catalog.gd")
const F=preload("res://scripts/building/module_factory.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func floor_layout() -> Dictionary:
	return L.add(L.empty(),{"type":"floor","a":[65.,-3.],"b":[94.,24.]})
func object(kind: String,p:=Vector2(79,10),yaw:=0.,support: String="") -> Dictionary:
	return {"type":"object","kind":kind,"position":[p.x,p.y],"yaw":yaw,"support":support}
func run() -> void:
	for yaw in [0.,90.,180.,270.]:
		var row:=object("cup",Vector2(79,10),yaw)
		var expected:=Basis(Vector3.UP,deg_to_rad(yaw))*Vector3(.055,0,0)
		check(C.footprint(row).get_center().distance_to(Vector2(79+expected.x,10+expected.z))<.0001,"Asymmetric offset follows engine Y rotation: "+str(yaw))
		for kind in ["bed","desk"]:
			var n:=Node3D.new();root.add_child(n);n.position=Vector3(79,.18,10);n.rotation.y=deg_to_rad(yaw);F.builder(n).build_item(n,kind)
			var collider: StaticBody3D=n.find_child("BedCollision" if kind=="bed" else "DeskCollision",true,false)
			var shape: BoxShape3D=collider.get_child(0).shape;var footprint:=C.footprint(object(kind,Vector2(79,10),yaw));var aligned:=true
			for x in [-.5,.5]:
				for z in [-.5,.5]:
					var p: Vector3=collider.to_global(Vector3(x*shape.size.x,0,z*shape.size.z))
					if not footprint.grow(.001).has_point(Vector2(p.x,p.z)):aligned=false
			check(aligned,"Real standalone collider fits rotated footprint: "+kind+" "+str(yaw));n.free()
		var legacy:={"schema":1,"next_id":3,"elements":[{"id":"floor","type":"floor","a":[73.,5.],"b":[85.,15.]},{"id":"bed","type":"object","kind":"bed","position":[82.,8.],"yaw":yaw}]}
		var migrated:=L.normalize(legacy)
		check(migrated.schema==4 and migrated.elements.size()==4,"Legacy bed splits into three independent elements without losing room: "+str(yaw))
		var bedside: Dictionary=migrated.elements.filter(func(item):return item.get("kind","")=="bedside")[0]
		var lamp: Dictionary=migrated.elements.filter(func(item):return item.get("kind","")=="table_lamp")[0]
		var offset: Vector3=Basis(Vector3.UP,deg_to_rad(yaw))*Vector3(-1.9,0,-.9)
		check(Vector2(bedside.position[0]-82,bedside.position[1]-8).distance_to(Vector2(offset.x,offset.z))<.001 and lamp.support==bedside.id,"Legacy bedside and attached lamp retain actual world pose: "+str(yaw))
		check(L.normalize(JSON.parse_string(JSON.stringify(migrated)))==migrated,"Migration is idempotent across disk serialization: "+str(yaw))
		var overlap:=L.add(migrated,object("bed",Vector2(82,8),yaw));check(not L.validate(overlap).ok,"Legacy exceptions do not permit new furniture overlap: "+str(yaw))
	var data:=floor_layout();data=L.add(data,object("desk"));var desk: Dictionary=data.elements[-1]
	for kind in ["table_lamp","small_plant","book","cup","letter","clock"]:
		var item:=L.attach_at(data,object(kind),Vector2(79,10))
		check(item.support==desk.id and L.validate(L.add(data,item)).ok,"Independent object snaps onto a valid tabletop: "+kind)
		check(not L.validate(L.add(floor_layout(),object(kind))).ok,"Surface object cannot float unsupported: "+kind)
	var lamp:=L.attach_at(data,object("table_lamp"),Vector2(79.9,10.3));data=L.validate(L.add(data,lamp)).layout;lamp=data.elements[-1]
	var old_pos:=Vector2(lamp.position[0],lamp.position[1]);desk=L.find(data,desk.id).duplicate(true);desk.position=[83.,11.];desk.yaw=90.
	var moved:=L.replace(data,desk);var child:=L.find(moved,lamp.id);var expected:=Vector2(83,11)+C.rotate_xz(old_pos-Vector2(79,10),90.)
	check(Vector2(child.position[0],child.position[1]).distance_to(expected)<.001 and child.yaw==90.,"Moving and rotating a desk carries its attached light")
	check(L.validate(moved).ok,"Moved surface group remains valid")
	var removed:=L.remove(moved,desk.id);check(L.find(removed,lamp.id).is_empty() and removed.elements.size()==1,"Deleting a support deletes attached objects as one layout operation")
	var independent:=L.remove(data,lamp.id);check(not L.find(independent,desk.id).is_empty(),"Deleting a lamp leaves its table intact")
	var another:=L.add(data,object("desk",Vector2(86,10)));var attached:=L.attach_at(another,lamp,Vector2(86,10));var changed:=L.replace(another,attached)
	check(L.validate(changed).ok and L.find(changed,lamp.id).support==another.elements[-1].id,"A lamp can move independently to another table")
	var roof:=L.add(floor_layout(),{"type":"roof","a":[70.,0.],"b":[90.,20.]});var roof_id: String=roof.elements[-1].id
	var pendant:=L.attach_at(roof,object("pendant"),Vector2(79,10));roof=L.add(roof,pendant)
	check(L.validate(roof).ok and is_equal_approx(L.base_height(roof,pendant)+float(C.OBJECTS.pendant.height),4.4),"Pendant is attached to ceiling height with a valid roof")
	check(not L.validate(L.add(floor_layout(),object("pendant"))).ok,"A pendant requires ceiling support")
	check(L.remove(roof,roof_id).elements.size()==1,"Removing a roof also removes its pendant")
	var bad:={"schema":2,"next_id":9,"elements":[{"id":"bad","type":"object","kind":"missing","position":[79,10]}]}
	var recovered:=L.normalize(bad);check(recovered.has("recovery_source") and recovered.recovery_source==bad,"Unreadable layout retains original data for recovery")
	var sample:=preload("res://scripts/building/templates.gd").cottage()
	var first:=L.merge_template(L.empty(),sample,Vector2(69,1));check(L.validate(first).ok,"Whole house can be placed at a chosen point")
	var second:=L.merge_template(first,sample,Vector2(88,19));check(L.validate(second).ok and second.elements.size()==sample.elements.size()*2,"A second complete house fits on empty space beside an existing one")
	var overlap:=L.merge_template(first,sample,Vector2(69,1));check(not L.validate(overlap).ok,"Whole-house overlap is rejected before placement")
	var ids: Dictionary={};var unique:=true
	for item in second.elements:
		if ids.has(item.id):unique=false
		ids[item.id]=true
	check(unique and L.normalize(JSON.parse_string(JSON.stringify(second)))==L.validate(second).layout,"Template copies receive unique stable IDs and correct support references")
	print("BUILDING_REVISION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
