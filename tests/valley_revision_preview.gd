extends SceneTree
var OUT=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().player_position=[3.40448,.05,-8.78934];session.state().time=1800
	var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);while game.preparing or game.camera==null: await process_frame
	await create_timer(.6).timeout
	Engine.max_fps=30;session.active=false;game.bunny.can_move=false;game.set_process(false);game.hud.visible=false
	print("BOAT_POSITION ",game.scenery.get_node("TravelBoat").global_position)
	var views: Array=[
		[Vector3(3.4,.1,-8.4),Vector3(15,9,4),Vector3(0,1,-10),"山谷修订-溪流与落水"],
		[Vector3(-9,.2,47),Vector3(-23,10,34),Vector3(-3,1,52),"山谷修订-南岸码头"],
		[Vector3(22,2.1,-17),Vector3(35,13,-9),Vector3(22,3,-21),"山谷修订-平滑阶梯"],
		[Vector3(44,.1,0),Vector3(35,10,-3),Vector3(53,4,0),"山谷修订-连续山体"],
		[Vector3(-9,.2,47),Vector3(3,4,53),Vector3(-1.5,0,48.2),"山谷修订-小船"],
		[Vector3(-7,.2,47.2),Vector3(-23,10,34),Vector3(-3,1,52),"山谷修订-南岸夜色",.92]]
	for view in views:
		game.bunny.position=view[0];game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();game.camera.position=view[1];game.camera.look_at(view[2]);game.update_lighting(view[4] if view.size()>4 else .5);game.update_occluders(1.)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+view[3]+".png")
	print("BOAT_VISIBLE ",game.scenery.get_node("TravelBoat/Hull").is_visible_in_tree()," aabb=",game.scenery.get_node("TravelBoat/Hull").get_aabb());print("VALLEY_REVISION_PREVIEW_COMPLETE");quit()
