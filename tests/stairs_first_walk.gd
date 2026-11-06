extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const E=preload("res://scripts/building/storey_extension.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var city: Node3D
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func walk(actor: CharacterBody3D,path: PackedVector3Array) -> bool:
	for target in path:
		var frames:=0
		while Vector2(actor.position.x-target.x,actor.position.z-target.z).length()>.13 and frames<270:
			var direction:=target-actor.position;direction.y=0;actor.simulate_movement(1./60.,direction.normalized(),false,false);frames+=1;await physics_frame
		if frames>=270:print("STUCK ",actor.position," target=",target);return false
	for i in range(15):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
	return absf(actor.position.y-path[-1].y)<.25
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("楼梯出口测试","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout
	var editor=city.build_mode;editor.open_editor();editor.set_process(false);city.set_process(false);city.bunny.set_physics_process(false);city.bunny.hide();city.bunny.collision_layer=0;editor.ui.hide()
	for form in Stairs.FORMS:
		for turn in [0.,90.,180.,270.]:
			var ground:=L.add(L.empty(),{"type":"floor","a":[108.,-6.],"b":[138.,26.]});var row:={"type":"stairs","position":[120.,10.],"form":form,"yaw":turn}
			check(editor.commit(E.place_stair(ground,row)),"Stairs-only-upper fixture "+form+str(turn));await physics_frame;await physics_frame
			var path:=Stairs.route(row);var heading:=path[-1]-path[-2];heading.y=0;path.append(path[-1]+heading.normalized()*3.);var actor:=Animals.create("bunny");city.add_child(actor);actor.world=city;actor.set_physics_process(false);actor.position=path[0]+Vector3.UP*.1;city.paused=false
			for i in range(15):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
			check(await walk(actor,path),"Enter landing through stair mouth "+form+str(turn));path.reverse();check(await walk(actor,path),"Leave landing through stair mouth "+form+str(turn));actor.free();city.paused=true
	city.queue_free();await create_timer(.1).timeout
	print("STAIRS_FIRST_WALK_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
