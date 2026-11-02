extends SceneTree
var session: Node
var game: Node3D
var OUT=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("山谷访客","panda","scarf_green");session.state().map_id="valley";session.state().player_position=[-8,.2,32];session.state().time=1800
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(2).timeout
	game.set_process(false);session.active=false;game.bunny.can_move=false;game.hud.visible=false
	var views: Array=[
		[Vector3(-8,.1,29),Vector3(-17,13,41),Vector3(-1,1,14),"山谷-入口"],
		[Vector3(-5,.3,5),Vector3(-11,10,17),Vector3(-1,1.3,5),"山谷-溪流小桥"],
		[Vector3(22,2,-18),Vector3(37,17,-10),Vector3(21,5,-28),"山谷-林地阶梯"],
		[Vector3(12,4.2,-29),Vector3(26,17,-18),Vector3(12,6,-35),"山谷-潘达小屋"]]
	for view in views:
		game.bunny.position=view[0];game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
		game.camera.position=view[1];game.camera.look_at(view[2]);game.update_lighting(.5)
		game.update_target();game.update_occluders(.5)
		await create_timer(.5).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+view[3]+".png")
	session.state().time=3300;game.update_lighting(.92)
	var panda=game.targets.Panda.node;panda.get_node("PandaRoutine").sleep_now()
	game.bunny.position=game.home.to_global(Vector3(-1,.3,1));game.bunny.velocity=Vector3.ZERO
	game.camera.position=game.home.to_global(Vector3(10,13,14));game.camera.look_at(game.home.to_global(Vector3(0,1.5,0)))
	await create_timer(1).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"山谷-潘达夜眠.png")
	print("VALLEY_PREVIEW_COMPLETE");quit()
