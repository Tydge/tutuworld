extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.8).timeout
	game.set_process(false);session.active=false;game.bunny.position=Vector3(13,.2,42);game.bunny.velocity=Vector3.ZERO;game.bunny.can_move=false;game.hud.visible=false
	game.update_lighting(.5);game.camera.position=Vector3(8,5,38);game.camera.look_at(Vector3(15,-.6,47))
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/城镇更新-沙滩小船.png")
	print("BOAT_ART_PREVIEW_COMPLETE");quit()
