extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().player_position=[-8,.1,32];session.state().time=1800
	var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(2).timeout
	session.active=false;game.bunny.can_move=false
	while not game.navigation.ready_for_paths: await physics_frame
	var panda: CharacterBody3D=game.targets.Panda.node;var routine: Node=panda.get_node("PandaRoutine")
	check(panda.rig_profile.species_id=="panda" and panda.get_meta("equipment").size()==3,"Random clothing on shared panda rig")
	Engine.time_scale=3
	var original: Vector3=panda.position
	await create_timer(6).timeout
	check(panda.position.distance_to(original)>2 and not panda.sleeping,"Daytime outdoor wander")
	panda.position=Vector3(22,2.1,-17);panda.velocity=Vector3.ZERO;panda.reset_physics_interpolation()
	routine.path.clear();routine.wait=0;routine.returning=false
	session.state().time=21*3600./24;game.update_lighting()
	var began:=Time.get_ticks_msec();var sim:=0.0
	while not panda.sleeping and sim<100:
		await physics_frame;sim+=Engine.time_scale/Engine.physics_ticks_per_second
	check(panda.sleeping,"Walk home and lie in bed at night; seconds="+str(sim))
	check(panda.position.distance_to(game.home.global_position)<7 and panda.collision_layer==0,"Sleeping inside own cottage")
	await create_timer(.8).timeout
	check(game.home.quilt_occupancy>.9 and game.home.bed_occupant==panda,"Quilt follows resident sleeping pose")
	game.current_target="Panda";game.talking_npc="";game.interact()
	check(panda.sleeping and game.talking_npc=="" and not game.hud.bubble.visible,"Interaction does not wake resident")
	game.bunny.position=game.home.to_global(Vector3(-1,.2,1));game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.set_process(false);game.camera.position=game.home.to_global(Vector3(10,13,14));game.camera.look_at(game.home.to_global(Vector3(0,1.4,0)))
	await create_timer(.8).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/山谷-潘达夜眠.png")
	session.state().time=7*3600./24;game.update_lighting()
	await create_timer(.5).timeout
	check(not panda.sleeping and panda.collision_layer==2 and game.home.bed_occupant==null,"Morning restores normal pose and collision")
	var exit: Vector3=game.home.get_node("Furnishing/bed/SleepExit").global_position
	await create_timer(8).timeout
	check(panda.position.distance_to(exit)>2,"Morning stroll leaves bedside")
	game.queue_free();await process_frame;await process_frame
	session.state().time=22*3600./24
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(.5).timeout;session.active=false
	check(game.targets.Panda.node.sleeping,"Night map arrival finds resident asleep")
	Engine.time_scale=1
	print("PANDA_VALLEY_ROUTINE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
