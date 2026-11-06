extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const D=preload("res://scripts/building/dining.gd")
const A=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data:=L.add(L.empty(),{"type":"floor","a":[65.,-5.],"b":[85.,15.]})
	data=L.add(data,{"type":"object","kind":"dining_table","position":[75.,5.],"yaw":0.});var table: Dictionary=data.elements[-1].duplicate(true);var ids: Array=[]
	for slot in D.slots(table):
		data=L.add(data,{"type":"object","kind":"dining_chair","position":[slot.position.x,slot.position.y],"yaw":slot.yaw});ids.append(data.elements[-1].id)
	check(L.validate(data).ok,"One table and six independently placed chairs validate")
	check(ids.all(func(id):return preload("res://scripts/building/catalog.gd").rotate_xz(Vector2.DOWN,L.find(data,id).yaw).dot((D.position(table)-D.position(L.find(data,id))).normalized())>.8),"Both end chairs and side chairs physically face inward")
	check(D.links(data).size()==6,"Every inward-facing chair pairs with one distinct seat")
	var source:=JSON.stringify(data);var moved:=table.duplicate(true);moved.position=[77.,7.];moved.yaw=90.
	var next:=L.replace(data,moved)
	check(L.validate(next).ok and D.links(next).size()==6,"Moving and rotating table preserves all six pairings")
	for id in ids:
		var old:=L.find(data,id);var chair:=L.find(next,id);var expected:=Vector2(77,7)+preload("res://scripts/building/catalog.gd").rotate_xz(D.position(old)-D.position(table),90.)
		check(D.position(chair).distance_to(expected)<.002 and chair.yaw==fposmod(old.yaw+90.,360.),"Chair follows table transform: "+id)
	check(JSON.stringify(data)==source,"Group preview leaves original layout unchanged")
	var chair:=L.find(data,ids[0]).duplicate(true);chair.position=[68.,3.];next=L.replace(data,chair)
	check(L.find(next,table.id)==table and L.find(next,ids[1])==L.find(data,ids[1]) and D.links(next).size()==5,"Moving chair leaves table and other chairs in place and unpairs it")
	check(L.find(L.remove(data,table.id),ids[0]).kind=="dining_chair","Deleting table keeps independently placed chairs")
	chair=L.find(data,ids[0]).duplicate(true);chair.yaw=180.;check(not D.links(L.replace(data,chair)).has(chair.id),"Outward-facing chair is not a dining seat")
	chair=L.find(data,ids[0]).duplicate(true);chair.storey=1;check(not D.links(L.replace(data,chair)).has(chair.id),"Chairs on another floor never pair")
	var isolated:=L.remove(data,ids[0]);var slot: Dictionary=D.slots(table)[0];chair={"type":"object","kind":"dining_chair","position":[slot.position.x+.2,slot.position.y+.2],"yaw":90.}
	var snapped:=L.snap_object(isolated,chair);check(D.position(snapped).distance_to(slot.position)<.002 and snapped.yaw==slot.yaw,"Placing near a free seat gently snaps position and orientation")
	var wall:=L.add(isolated,{"type":"wall","a":[73.,4.],"b":[75.,4.]});check(D.position(L.snap_object(wall,chair)).distance_to(slot.position)>.05,"A wall blocks pairing and dining snap")
	var occupied:=L.add(data,{"type":"object","kind":"dining_chair","position":L.find(data,ids[0]).position,"yaw":0.});check(D.links(occupied).size()==6,"A duplicate chair cannot claim an occupied seat slot")
	var obstacle:=L.add(data,{"type":"object","kind":"woven_basket","position":[79.,5.],"yaw":0.});moved=table.duplicate(true);moved.position=[77.,5.]
	check(not L.validate(L.replace(obstacle,moved)).ok,"Moving table is refused when any carried chair collides")
	for recipe in DB.recipes_for_station("kitchen"):
		var a:=A.new();a.state.build_layout=data;a.state.player_position=[74.1,.2,2.5];a.state.stamina=40.;var food: String=DB.recipe(recipe).output;a.add(food,2)
		check(a.execute({"verb":"eat","target":"build:"+table.id,"seat":ids[0],"item":food}).ok and a.job.duration==6.,"Existing six-second meal starts at placed table: "+food)
		a.tick(5.9);check(a.count(food)==2,"Food waits until completion: "+food);a.execute({"verb":"cancel"});check(a.count(food)==2,"Cancel keeps food: "+food)
		a.execute({"verb":"eat","target":"build:"+table.id,"seat":ids[0],"item":food});a.tick(6.01)
		check(a.count(food)==1 and (a.state.food_effect.get("item","")==food if not DB.item(food).get("effect",{}).is_empty() else is_equal_approx(a.state.stamina,70.)),"Existing effect/stamina and exact consumption are reused: "+food)
	var a:=A.new();a.state.build_layout=data;a.add("food_carrot_soup",2);a.state.player_position=[74.1,4.8,3.55]
	check(not a.execute({"verb":"eat","target":"build:"+table.id,"seat":ids[0],"item":"food_carrot_soup"}).ok,"Authority rejects wrong-floor eating")
	a.state.player_position=[74.1,.2,3.55]
	check(not a.execute({"verb":"eat","target":"build:"+table.id,"seat":ids[0],"item":"carrot"}).ok,"Raw food cannot bypass existing cooked-food rules")
	check(not a.execute({"verb":"eat","target":"build:"+table.id,"item":"food_carrot_soup"}).ok,"A custom table requires a bound paired chair")
	a.execute({"verb":"eat","target":"build:"+table.id,"seat":ids[0],"item":"food_carrot_soup"});a.state.build_layout=L.remove(data,ids[0]);a.tick(6.01)
	check(a.count("food_carrot_soup")==2,"Removing bound chair cancels completion without consuming food")
	print("DINING_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
