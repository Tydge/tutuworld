extends SceneTree
const Factory=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array[String]=[]
var game: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func release() -> void:
	for key in ["move_left","move_right","move_up","move_down"]:Input.action_release(key)
func place(actor: CharacterBody3D,p: Vector3) -> void:
	release();actor.position=p;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	for i in range(15):await physics_frame
func drive(actor: CharacterBody3D,target: Vector3) -> Dictionary:
	var min_y: float=actor.position.y;var max_step:=0.;var elapsed:=0.;var last: float=actor.position.y
	while elapsed<5.:
		var direction: Vector3=target-actor.position;direction.y=0
		if direction.length()<.18:release();return {"arrived":true,"min_y":min_y,"max_step":max_step}
		direction=direction.normalized();release()
		Input.action_press("move_right" if direction.x>=0 else "move_left",absf(direction.x));Input.action_press("move_down" if direction.z>=0 else "move_up",absf(direction.z))
		await physics_frame;elapsed+=Engine.time_scale/Engine.physics_ticks_per_second
		min_y=minf(min_y,actor.position.y);max_step=maxf(max_step,absf(actor.position.y-last));last=actor.position.y
	release();print("PIER_STUCK position=",actor.position," target=",target," logical_next=",game.can_walk(actor.position+(target-actor.position).normalized()*.1))
	return {"arrived":false,"min_y":min_y,"max_step":max_step}
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("码头验收兔","bunny","bow_rose")
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game);current_scene=game
	while game.preparing or game.camera==null:await process_frame
	session.active=false;game.set_process(false);game.paused=false;game.yaw=0
	for npc in game.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0
	var original: CharacterBody3D=game.bunny
	game.bunny.set_physics_process(false);game.bunny.hide();game.bunny.collision_layer=0
	check(game.can_walk(Vector3(13,0,45.4)) and game.can_walk(Vector3(16,0,44.9)),"Visible dry sand beyond the pier is logically walkable")
	check(not game.can_walk(Vector3(13,-1.5,52)),"Open sea remains outside the walking region")
	var saved: Dictionary=session.snapshot();saved.player_position=[13.,.02,45.4]
	check(session.restore_state(saved).state.player_position==saved.player_position,"Reload preserves a position on the newly walkable beach")
	check(not preload("res://scripts/valley/valley_layout.gd").valid_saved_position("city",Vector3(13,-1.5,52)),"Save validation also rejects open-water positions")
	Engine.time_scale=3.
	for species in ["bunny","cat_teacher","panda"]:
		var actor: CharacterBody3D=Factory.create(species);game.add_child(actor);actor.world=game;game.bunny=actor
		await place(actor,Vector3(13,.25,42.3));var outward:=await drive(actor,Vector3(13,0,45.4))
		check(outward.arrived and outward.min_y>-.45,"Real player input leaves the pier end onto sand without sticking: "+species)
		var back:=await drive(actor,Vector3(13,.15,41.5))
		check(back.arrived and back.max_step<.32,"Return from sand onto the pier without jumping: "+species)
		game.update_target();check(game.current_target=="boat","Boat prompt remains reachable: "+species)
		await place(actor,Vector3(9.8,.3,44.9));var cross:=await drive(actor,Vector3(16,0,44.9))
		check(cross.arrived and cross.min_y>-.45,"Walk across the beach beyond both end posts: "+species)
		game.bunny=original;actor.queue_free();await process_frame
	Engine.time_scale=1.;release();game.hud.hide();game.update_lighting(.4);game.camera.position=Vector3(23,10,35);game.camera.look_at(Vector3(13,.2,44))
	for i in range(6):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/pier-dry-sand-walkway.png")
	print("PIER_SHORE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
