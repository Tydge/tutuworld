extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const Land=preload("res://scripts/building/parcels.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Dining=preload("res://scripts/building/dining.gd")
const Online=preload("res://scripts/city/online_world.gd")
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	print("PASS " if ok else "FAIL ",label_)
	if not ok:errors.append(label_)
func run() -> void:
	for map_id in ["city","icefield","jade"]:await explore(map_id)
	print("REGIONAL_MEALS_RESULT ","PASS" if errors.is_empty() else "FAIL",errors)
	quit(int(not errors.is_empty()))

func explore(map_id: String) -> void:
	var session:=preload("res://scripts/services/session.gd").new()
	session.name="Session";root.add_child(session)
	session.create_character("尝鲜兔","bunny","bow_rose")
	var state:=session.state();state.map_id=map_id
	var center:=Land.bounds(Land.ids_for(map_id)[0]).get_center()
	var plan:=Layout.add(Layout.empty(map_id),{"type":"floor","a":[center.x-4.,center.y-4.],"b":[center.x+4.,center.y+4.]})
	plan=Layout.add(plan,{"type":"object","kind":"dining_table","position":[center.x,center.y],"yaw":90.})
	var table: Dictionary=plan.elements.back()
	var slot: Dictionary=Dining.slots(table)[2]
	plan=Layout.add(plan,{"type":"object","kind":"dining_chair","position":[slot.position.x,slot.position.y],"yaw":slot.yaw})
	state[Land.layout_key(map_id)]=plan
	var city: Node3D=load("res://scenes/"+map_id+".tscn").instantiate()
	root.add_child(city)
	session.active=false
	city.bunny.set_physics_process(false)
	await physics_frame;await physics_frame
	city.dining_target="build:"+table.id
	var chair: Node3D=city.targets[city.dining_target].node.get_meta("dining_chairs")[0]
	var exit_point: Vector3=chair.get_node("ExitAnchor").global_position
	city.bunny.stand_up(exit_point);session.set_player_position(exit_point)
	state.stamina=30.;session.authority.add("sweet_osmanthus",2)
	var meal: Dictionary=city.begin_dining("sweet_osmanthus")
	check(meal.ok and city.bunny.action=="eat" and city.bunny.seated and city.tools.prop.visible,map_id+" built-table seating, meal and handheld pose")
	if meal.ok:
		session.job().elapsed=2.9;city.culinary._process(0.)
		var own_plate: Node3D=city.culinary.meal
		check(own_plate.get_meta("item")=="sweet_osmanthus" and own_plate.get_meta("portion")==2,map_id+" real local dish advances two bites")
		# Observe an already eating player while this player's own meal is still in progress.
		var client:=Online.new();client.city=city;client.session=session
		var pos:=exit_point+Vector3(3,0,1)
		var pose:={"kind":"eat","target":city.dining_target,"meal_position":[pos.x,pos.y+1.15,pos.z]}
		if map_id=="city":pose={"kind":"eat","target":"dining"}
		var row:={"id":"guest","name":"同桌","species":"panda","position":[pos.x,pos.y,pos.z],"action":"eat","equipment":{},"pose":pose,"job":{"verb":"eat","item":"almond_biscuit","elapsed":1.25,"duration":6.}}
		client.make_replica(row);client.motion.guest=row
		client._process(0.)
		var guest: Dictionary=client.replicas.guest
		check(guest.meal.get_meta("item")=="almond_biscuit" and guest.meal.get_meta("portion")==1 and city.culinary.meal==own_plate and guest.meal!=own_plate,map_id+" independent portions for local and remote tables")
		row.pose={};row.action="snack";row.job={"verb":"snack","item":"sweet_osmanthus","duration":3.,"elapsed":1.}
		client._process(0.)
		row.job.item="almond_biscuit";client._process(0.)
		check(guest.meal==null and guest.props.prop.has_node("AlmondBiscuit") and guest.actor.action=="snack",map_id+" remote consecutive snacks change in hand")
		client.free();guest.props.free();guest.actor.free()
		city.cancel_action()
		check(not city.bunny.seated and city.culinary.meal==null and session.authority.count("sweet_osmanthus")==2,map_id+" cancellation clears food and retains inventory")
	for item: String in DB.catalog().items:
		if not DB.item(item).has("edible"):continue
		state.stamina=30.;session.authority.add(item,1)
		city.hud.open_panel("bag")
		var button: Button
		for control in city.hud.content.find_children("*","Button",true,false):
			if control.get_meta("eat_item","")==item:button=control;break
		if button:button.pressed.emit()
		check(city.bunny.action=="snack" and city.tools.prop.get_meta("item")==item and city.tools.prop.get_child_count()>0,map_id+" bag button animates "+item)
		city.cancel_action()
	var drank:=false
	for id: String in city.targets:
		if city.targets[id].kind!="tea":continue
		var position: Vector3=city.targets[id].position+Vector3(0,0,1.)
		city.bunny.stand_up(position);session.set_player_position(position);session.authority.add("branch",1)
		if not city.activity_access(id,"tea"):continue
		city.interact_with_activity(id,"tea")
		check(city.bunny.action=="tea" and city.tools.prop.has_node("TeaCup") and not city.bunny.held_cup.visible,map_id+" brews and lifts one pine tea cup")
		drank=true
		city.cancel_action()
		break
	if map_id!="city":check(drank,map_id+" has a reachable tea service")
	while not city.navigation.ready_for_paths or not city.navigation.sampling_ready:await physics_frame
	city.free();session.free()
	await process_frame
