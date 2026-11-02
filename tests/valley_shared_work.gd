extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const Factory=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().player_position=[-8,.1,32]
	var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(.7).timeout
	session.active=false
	for species in ["bunny","cat_teacher","panda"]:
		var old: CharacterBody3D=game.bunny;game.remove_child(old);old.queue_free()
		var actor: CharacterBody3D=Factory.create(species);actor.name="Player";game.add_child(actor);game.bunny=actor;actor.world=game;actor.can_move=false;game.tools.bunny=actor
		game.camera_query.exclude=[actor.get_rid()]
		session.settings.player_species=species;session.state().species=species
		preload("res://scripts/city/outfit.gd").apply(actor,{"head":"beret_plaid_sage","neck":"scarf_red","body":"overalls_sage"})
		for type_ in ["birch","iron","sandstone"]:
			var id: String="valley_"+type_+"_0";var r:=DB.resource(id)
			session.authority.add(DB.item(type_).tool,1);session.state().resources[id].available=true
			actor.position=Vector3(r.x,r.y+.08,r.z+1.3);actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation();session.set_player_position(actor.position)
			var before: int=session.authority.count(type_)
			var result: Dictionary=game.begin_action("gather",id)
			check(result.ok and is_equal_approx(session.job().duration,5.0),"New five-second action "+species+" "+type_)
			await create_timer(.2).timeout
			var grip_error:=0.0;var hit_error:=999.0
			for i in range(9):
				actor.action_time=.18+i*.92/8.;actor.animate_pose(0);game.tools._physics_process(0)
				for side in ["R","L"]:
					var arm: Node3D=actor.right_arm if side=="R" else actor.left_arm
					var grip: Vector3=actor.rig_profile.grip_offset
					if side=="L": grip.x=-grip.x
					grip_error=maxf(grip_error,arm.to_global(grip).distance_to(game.tools.prop.get_node("Grip"+side).global_position))
				hit_error=minf(hit_error,game.tools.prop.get_node("Impact").global_position.distance_to(game.tools.target_point))
			check(grip_error<.015,"Both hands stay on shared tool "+species+" "+type_+" error="+str(grip_error))
			check(hit_error<.02,"Working edge hits selected source "+species+" "+type_)
			if type_=="birch":
				game.camera.position=actor.position+Vector3(3,3,4);game.camera.look_at(actor.position+Vector3(0,1.1,0));game.hud.visible=false
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/山谷-伐木-"+species+".png");game.hud.visible=true
			for event in session.authority.tick(5.0): game.on_event(event)
			check(session.authority.count(type_)==before+1 and not game.resources[id].visible,"Harvested T2 item and hidden model "+species+" "+type_)
			check(session.authority.count(DB.item(type_).tool)>0,"Permanent tool retained "+species+" "+type_)
	print("VALLEY_SHARED_WORK_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
