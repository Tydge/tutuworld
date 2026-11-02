extends SceneTree
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func travel(p: Vector3) -> void:
	game.bunny.position=p;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.set_player_position(p)
	await create_timer(.4).timeout
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label_+".png")
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		check(session.create_character("云朵兔" if species=="bunny" else "午睡猫",species,"vest_sage").ok,"Create "+species)
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		await create_timer(1).timeout
		session.active=false;session.state().time=1800;game.update_lighting();game.hud.toast.hide()
		var bed: Node3D=game.home.get_node("Furnishing/bed")
		await travel(bed.get_node("ActionAnchor").global_position)
		game.update_target();await create_timer(.2).timeout
		check(game.current_target=="home_bed","Bed is selected from a real standing position: "+species)
		check(game.hud.prompt_card.visible and root.get_visible_rect().encloses(game.hud.prompt_card.get_global_rect()) and game.hud.prompt.text.contains("E "),"E prompt is actually on screen: "+species)
		check(game.hud.player_status.portrait.actor.rig_profile.species_id==species and game.hud.player_status.name_label.text==session.state().character_name,"Head portrait and name use the selected character")
		session.state().stamina=80;session.state().stamina_recovery_elapsed=0
		game.interact();await create_timer(1).timeout
		check(game.sleep_active and game.bunny.sleeping and session.state().rest_mode=="sleep","E lies in bed: "+species)
		check(absf(game.bunny.visual.rotation.x-game.bunny.SleepPose.BODY_ANGLE)<.01 and game.bunny.eyes.scale.y<.06,"Shared lying pose closes the eyes: "+species)
		check(bed.get_node("Quilt").material_override.get_shader_parameter("occupancy")>.99,"Separate quilt covers the sleeping character")
		var layout: Dictionary=game.bunny.SleepPose.layout(game.bunny.rig_profile)
		var head_bottom: float=bed.to_local(game.bunny.head.global_position).y-layout.head_vertical
		check(absf(head_bottom-(.90+layout.pillow_height))<.015,"Head rests on the pillow surface: "+species)
		check(absf(game.bunny.head.rotation.x-game.bunny.SleepPose.HEAD_ANGLE)<.01,"Small head angle uses the neck pivot")
		check(bed.to_local(game.bunny.head.global_position).z>-.75 and bed.get_node("Pillow").position.z<bed.to_local(game.bunny.head.global_position).z-.20,"Character moves toward the foot; pillow supports upper head")
		check((bed.global_basis.inverse()*game.bunny.head.global_basis.z).y>.94,"Head is reclined toward the ceiling rather than sitting upright")
		game.yaw=.35;game.distance_=10.0;await create_timer(.6).timeout
		await capture("新版睡眠-"+species)
		game.yaw=1.40;game.pitch=.25;await create_timer(.3).timeout;await capture("新版睡眠侧面-"+species)
		game.pitch=.46
		var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)
		await create_timer(.4).timeout
		check(not game.sleep_active and not game.bunny.seated and game.bunny.is_on_floor() and session.state().rest_mode=="","E gets out safely: "+species)
		for kind in ["farm","tools","clothes"]:
			var shop: Node3D=game.scenery.get_node("Shop_"+kind)
			await travel(shop.to_global(Vector3(0,.2,5.4)))
			var scene_id: int=game.get_instance_id()
			game.yaw=0;game.distance_=13.5
			Input.action_press("move_up");await create_timer(2.5).timeout;Input.action_release("move_up")
			await create_timer(.3).timeout
			check(shop.inside and game.get_instance_id()==scene_id,"Walks through the open entrance without scene loading: "+species+" "+kind)
			check(absf(game.bunny.position.y-shop.floor_level)<.04,"Shop floor supports both species: "+str(game.bunny.position)+" expected="+str(shop.floor_level))
			game.update_target()
			check(game.current_target=="Merchant_"+kind,"Seller is reached inside: "+kind+" actual="+game.current_target)
			game.interact();await create_timer(.2).timeout
			check(game.hud.mode=="shop" and game.hud.shop==kind,"Indoor seller opens the right shop")
			game.hud.close_panel()
			if species=="bunny": await capture("开放小店-"+kind)
			Input.action_press("move_down");await create_timer(2.8).timeout;Input.action_release("move_down");await create_timer(.2).timeout
			check(not shop.inside,"Can leave the shop through its actual doorway")
		game.queue_free();await process_frame;await process_frame
	print("STATUS_SLEEP_SHOPS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
