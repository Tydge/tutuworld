extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(1).timeout
	game.set_process(false);game.bunny.can_move=false;session.active=false
	game.update_lighting(.5)
	game.camera.position=Vector3(7,6,33);game.camera.look_at(Vector3(15,-.5,56))
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/城镇更新-海水远岛.png")
	game.camera.position=Vector3(21,9,22);game.camera.look_at(Vector3(10,2,5));await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/城镇更新-橘子树.png")
	print("TOWN_COAST_PREVIEW_COMPLETE");quit()
