extends SceneTree
const Layout=preload("res://scripts/valley/valley_layout.gd")
const Factory=preload("res://scripts/characters/animal_factory.gd")
var game: Node3D
var session: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func release() -> void:
	for key in ["move_left","move_right","move_up","move_down","jump"]: Input.action_release(key)
func point_input(direction: Vector3) -> void:
	release()
	Input.action_press("move_right" if direction.x>=0 else "move_left",absf(direction.x))
	Input.action_press("move_down" if direction.z>=0 else "move_up",absf(direction.z))
func place(actor: CharacterBody3D,p: Vector3) -> void:
	release();actor.position=p;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	for frame in range(12): await physics_frame
func drive(actor: CharacterBody3D,target: Vector3,seconds:=9.) -> Dictionary:
	var elapsed:=0.;var max_dy:=0.;var last_y: float=actor.position.y;var surface_error:=0.
	while elapsed<seconds:
		var direction:=target-actor.position;direction.y=0
		if direction.length()<.22: release();return {"arrived":true,"max_dy":max_dy,"surface_error":surface_error}
		point_input(direction.normalized());await physics_frame
		elapsed+=Engine.time_scale/Engine.physics_ticks_per_second
		max_dy=maxf(max_dy,absf(actor.position.y-last_y));last_y=actor.position.y
		if actor.is_on_floor(): surface_error=maxf(surface_error,absf(actor.position.y-Layout.walk_height(actor.position.x,actor.position.z)))
	release();print("FAILED_POSITION ",actor.position," target=",target)
	return {"arrived":false,"max_dy":max_dy,"surface_error":surface_error}
func run() -> void:
	root.size=Vector2i(1200,750)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().player_position=Layout.arrival("valley")
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game)
	while game.preparing or game.camera==null: await process_frame
	session.active=false;game.set_process(false);game.paused=false;game.yaw=0
	for npc in game.npcs:
		npc.set_physics_process(false);npc.collision_layer=0
		for child in npc.get_children(): child.set_physics_process(false);child.set_process(false)
	var original: CharacterBody3D=game.bunny
	game.bunny.set_physics_process(false);game.bunny.hide();game.bunny.collision_layer=0
	check(game.scenery.get_node_or_null("WoodlandSteps")==null and game.scenery.get_meta("continuous_heightfield",false),"Continuous terrain replaces all former terrace ramps")
	for position_ in [Vector3(-78,Layout.height_at(-78,Layout.ascent_path_z(-78)),Layout.ascent_path_z(-78)),Vector3(-16.8,.18,94.4)]:
		var saved: Dictionary=session.snapshot();saved.map_id="valley";saved.player_position=[position_.x,position_.y,position_.z];saved.valley_landscape_revision=Layout.REVISION
		var restored=session.restore_state(saved)
		check(Vector3(restored.state.player_position[0],restored.state.player_position[1],restored.state.player_position[2]).is_equal_approx(position_),"Restore current mountain / pier coordinate without double scaling "+str(position_))
	Engine.time_scale=3
	for species in ["bunny","cat_teacher","panda"]:
		var actor: CharacterBody3D=Factory.create(species);game.add_child(actor);actor.world=game;game.bunny=actor
		for side in [-1,1]:
			for up in [true,false]:
				var x0:=58. if up else 70.;var x1:=70. if up else 58.
				var start:=Vector3(side*x0,Layout.height_at(side*x0,Layout.ascent_path_z(x0))+.035,Layout.ascent_path_z(x0))
				var end:=Vector3(side*x1,Layout.height_at(side*x1,Layout.ascent_path_z(x1)),Layout.ascent_path_z(x1))
				await place(actor,start)
				var result: Dictionary=await drive(actor,end,12.)
				var label_: String=species+" bank="+str(side)+(" uphill" if up else " downhill")
				check(result.arrived,"Real player input on mountain trail "+label_)
				check(result.max_dy<.22 and result.surface_error<.35,"Continuous grounded motion "+label_+" dy="+str(result.max_dy)+" error="+str(result.surface_error))
		await place(actor,Vector3(-15,Layout.height_at(-15,10)+.05,10))
		var bridge: Dictionary=await drive(actor,Vector3(15,Layout.height_at(15,10),10),15.)
		check(bridge.arrived,"Cross both bridge approaches through real input "+species)
		await place(actor,Vector3(-22,Layout.height_at(-22,88)+.05,88))
		var approach: Dictionary=await drive(actor,Vector3(-21,.18,94.4))
		var pier: Dictionary=await drive(actor,Vector3(-14.2,.18,94.4))
		check(approach.arrived and pier.arrived,"Walk from valley trail onto return pier "+species)
		game.bunny=original;actor.queue_free();await process_frame
	Engine.time_scale=1;release()
	print("VALLEY_TRAVERSAL_REGRESSION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
