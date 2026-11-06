extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const D=preload("res://scripts/building/dining.gd")
const Service=preload("res://scripts/city/dining_service.gd")
var city: Node3D
var session: Node
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func approach(p: Vector3) -> void:
	city.bunny.stand_up(p);city.bunny.velocity=Vector3.ZERO;session.set_player_position(p);await physics_frame;await physics_frame;city.update_target()
func key(code: Key) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);await process_frame
func photo(name_: String) -> void:
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func run() -> void:
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("餐桌验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout
	var editor=city.build_mode;editor.open_editor();var data:=L.add(L.empty(),{"type":"floor","a":[68.,-1.],"b":[84.,12.]})
	data=L.add(data,{"type":"object","kind":"dining_table","position":[75.,5.],"yaw":0.});var table: Dictionary=data.elements[-1].duplicate(true);var ids: Array=[]
	for i in [2,3,0]:
		var slot: Dictionary=D.slots(table)[i];data=L.add(data,{"type":"object","kind":"dining_chair","position":[slot.position.x,slot.position.y],"yaw":slot.yaw});ids.append(data.elements[-1].id)
	check(editor.commit(data),"Place independent dining table and three chairs")
	for id in [table.id]+ids:
		var node: Node3D=editor.room.render_cache[id].node
		check(node.get_meta("appearance_unmatched",[]).is_empty() and node.has_node("Part_frame"),"New model supports every appearance part: "+str(id))
	editor.selected_id=table.id;editor.selected_unit.clear();editor.begin_move();editor.update_ghost(Vector2(77,5))
	check(ids.all(func(id):return not editor.room.render_cache[id].node.visible) and editor.preview.get_child_count()>3,"Moving table hides original chairs and previews entire group")
	check(editor.place_at(Vector2(77,5)),"Table group move commits as one operation")
	check(L.find(editor.layout,ids[0]).position[0]==76.1,"Chair follows actual editor move")
	editor.undo();check(L.find(editor.layout,ids[0]).position[0]==74.1,"One undo restores table and all chairs")
	editor.selected_id=table.id;editor.rotate_selected();check(D.links(editor.layout).size()==3 and L.find(editor.layout,ids[0]).yaw==270.,"R rotates table with chairs and preserves pairings")
	editor.undo();editor.close_editor();session.active=false;city.bunny.set_physics_process(false)
	var target: String="build:"+table.id;var first: Node3D=editor.room.render_cache[ids[0]].node;var second: Node3D=editor.room.render_cache[ids[1]].node
	await approach(Vector3(74.1,.2,7.7));check(city.current_target==target,"Real nearby E prompt uses placed dining table")
	await key(KEY_E);check(city.hud.mode=="dining" and city.dining_target==target,"E opens existing food panel bound to this table")
	city.hud.close_panel();session.authority.add("food_carrot_soup",3)
	var result: Dictionary=city.begin_dining("food_carrot_soup")
	check(result.ok and city.dining_chair==first and city.bunny.seated,"Meal automatically chooses nearest accessible chair")
	check(city.bunny.visual.rotation.y==first.global_rotation.y,"Seated actor faces the table")
	check(city.culinary.meal.global_position.distance_to(Service.meal_position(city,target,first))<.01,"Existing food visual appears on this table in front of chosen seat")
	city.set_process(false);city.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;city.camera.position=Vector3(79,6.2,11);city.camera.look_at(Vector3(75,1,5));await photo("dining-nearest-chair");city.set_process(true)
	session.authority.tick(5.9);check(session.authority.count("food_carrot_soup")==3,"Dining does not consume food before six seconds")
	var events: Array=session.authority.tick(.11)
	for event in events:city.on_event(event)
	check(session.authority.count("food_carrot_soup")==2 and session.state().food_effect.item=="food_carrot_soup","Existing completion consumes one meal and applies its effect")
	check(not city.dining_active and not city.bunny.seated and city.bunny.can_move,"Meal finishes with safe standing beside chosen chair")
	var guest=preload("res://scripts/characters/animal_factory.gd").create("bunny");city.add_child(guest);guest.set_physics_process(false);guest.position=first.get_node("SeatAnchor").global_position
	await approach(Vector3(74.1,.2,7.7));var chosen:=Service.choose(city,target)
	check(chosen.get("node")==second,"Occupied nearest chair automatically falls back to next nearest free chair")
	result=city.begin_dining("food_carrot_soup");check(result.ok and city.dining_chair==second,"Actual meal also uses the next available chair without seat selection")
	city.cancel_action();check(session.authority.count("food_carrot_soup")==2 and not city.bunny.seated,"Cancelling placed-table meal returns safely and preserves food")
	guest.free();await physics_frame
	await approach(Vector3(74.1,.2,7.7));var obstacle:=preload("res://scripts/geometry.gd").solid_box(city,Vector3(74.1,1.1,7.),Vector3(.85,2.2,.22),"BlockedNearestChair");obstacle.collision_layer=4;await physics_frame;await physics_frame
	chosen=Service.choose(city,target);check(not chosen.is_empty() and chosen.node==second,"Blocked closest chair automatically chooses clear next chair")
	obstacle.free();await physics_frame
	await approach(Vector3(74.1,5.,7.7));check(Service.choose(city,target).is_empty(),"Another floor cannot select these chairs")
	await approach(Vector3(74.1,.2,7.7));result=city.begin_dining("food_carrot_soup")
	var cage:=preload("res://scripts/geometry.gd").solid_box(city,first.global_position+Vector3.UP,Vector3(5.,2.5,5.),"BlockedExit");cage.collision_layer=4;await physics_frame;await physics_frame;city.cancel_action()
	check(city.nap_active and city.bunny.seated,"No safe exit keeps diner seated instead of teleporting through obstacles")
	cage.free();await physics_frame;await physics_frame;check(city.leave_seat() and not city.bunny.seated,"Clearing an exit allows normal E standing")
	var folder:=ProjectSettings.globalize_path("res://.qa-artifacts/dining-save-"+str(Time.get_ticks_usec()));DirAccess.make_dir_recursive_absolute(folder);session.save_path=folder+"/save.json";session.test_mode=false;var saved: bool=session.save_game();session.test_mode=true
	var recovered=load("res://scripts/services/session.gd").new();root.add_child(recovered);recovered.save_path=session.save_path;recovered.load_save();check(saved and D.links(recovered.state().build_layout)==D.links(editor.layout),"Real isolated save/reload derives same dining pairs without new save fields")
	city.queue_free();await create_timer(.15).timeout
	print("DINING_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
