extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const C=preload("res://scripts/building/catalog.gd")
const W=preload("res://scripts/building/wall_mount.gd")
const E=preload("res://scripts/building/room_edit.gd")
const G=preload("res://scripts/building/grid_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var data:=L.empty()
	for level in [0,1]:
		data=L.add(data,{"type":"floor","a":[70.,1.],"b":[82.,13.],"storey":level})
		for line in [[[70.,1.],[82.,1.]],[[70.,1.],[70.,13.]],[[82.,1.],[82.,13.]],[[70.,13.],[82.,13.]]]:data=L.add(data,{"type":"wall","a":line[0],"b":line[1],"storey":level})
	for kind in ["wall_botanical","wall_mirror","wall_clock","wall_sconce"]:
		for level in [0,1]:
			for pair in [[Vector2(76,1),Vector2(76,5)],[Vector2(76,13),Vector2(76,9)],[Vector2(70,7),Vector2(75,7)],[Vector2(82,7),Vector2(77,7)]]:
				var row:=W.attach(data,{"type":"object","kind":kind,"position":[pair[0].x,pair[0].y],"yaw":0.,"storey":level},pair[0],pair[1]);var result:=L.validate(L.add(data,row))
				check(result.ok,"Wall attachment validates on each facing/storey: "+kind+str(level)+str(pair[0]))
				if result.ok:
					var saved: Dictionary=result.layout.elements.filter(func(item):return item.type=="object")[0]
					check(not W.support(result.layout,saved).is_empty() and is_equal_approx(L.base_height(result.layout,saved),4.7*level+W.height(saved)),"Mount retains real support and height")
	var art:=W.attach(data,{"type":"object","kind":"wall_botanical","position":[76.,1.],"yaw":0.},Vector2(76,1),Vector2(76,5));var adorned:=L.normalize(L.add(data,art));art=adorned.elements.filter(func(row):return row.get("kind","")=="wall_botanical")[0]
	var unit:=L.unit_at(adorned,art.support,Vector2(75.25,1));var changed:=unit.duplicate(true);changed.style="brick";changed.painted=true;var split:=L.validate(L.replace_unit(adorned,unit,changed))
	check(split.ok and not L.find(split.layout,art.id).is_empty(),"Changing a wall material/splitting runs retains mounted objects")
	var context:=E.wall_context(E.prepare(adorned,0),L.unit_at(adorned,art.support,Vector2(76,1)),Vector2(76,5));var moved:=E.resize(context,-2)
	check(moved.ok and moved.moves.has(art.id) and L.validate(E.materialize(context.base,moved)).ok,"Wall drag carries mounted decoration and rebinds support")
	var erased:=L.demolish(adorned,Rect2(75.5,.8,1.,.4),"wall",null,0);check(L.find(erased,art.id).is_empty() and L.validate(erased).ok,"Removing supporting wall cells removes the mounted item without orphaning it")
	var door:=L.add(data,{"type":"door","wall":L.compiled(data).walls[Vector3i(150,2,0)].id,"offset":6.});check(not L.validate(L.add(door,art)).ok,"Wall art cannot cover a real doorway")
	var invalid:=art.duplicate(true);invalid.mount_height=4.;check(not L.validate(L.add(data,invalid)).ok,"Object must fit within wall height")
	invalid=art.duplicate(true);invalid.position=[76.,2.];check(not L.validate(L.add(data,invalid)).ok,"Wall object cannot float away from supporting wall")
	var hearth:={"type":"object","kind":"hearth","position":[76.,1.95],"yaw":0.};hearth=L.snap_object(data,hearth)
	check(is_equal_approx(hearth.position[1],1.58) and L.validate(L.add(data,hearth)).ok,"Fireplace snaps its actual back to one centimetre beyond the wall face")
	var cart:=L.add(data,{"type":"object","kind":"kitchen_cart","position":[76.,7.],"yaw":0.});var cart_id: String=cart.elements[-1].id
	var jars:=L.attach_at(cart,{"type":"object","kind":"spice_jars","position":[76.,7.],"yaw":0.},Vector2(76,7),cart_id);cart=L.normalize(L.add(cart,jars))
	check(not cart.elements.is_empty(),"Floor kitchen cart supports independently placed spice jars")
	var old:=L.find(cart,cart_id).duplicate(true);old.position=[78.,8.];old.yaw=90.;var group:=L.replace(cart,old)
	check(L.validate(group).ok and group.elements[-1].support==cart_id,"Moving/rotating kitchen cart carries its supported spice tray")
	var template:=preload("res://scripts/building/templates.gd").player_sample("two_storey")
	check(template.elements.size()==87 and template.elements.any(func(row):return row.get("kind","")=="hearth" and row.position==[140.2,9.58]),"Catalog contains the updated eastern house with its flush-wall fireplace")
	for turn in [0.,90.,180.,270.]:check(L.validate(L.merge_template(L.empty(),template,Vector2(120,10),turn)).ok,"Updated sample rotates and validates: "+str(turn))
	print("WALL_FURNITURE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
