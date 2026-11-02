extends SceneTree
var session: Node
var game: Node3D
var output := preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name_+".png")
	print("CAPTURE ",name_)
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/title.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.5).timeout
	await capture("标题界面")
	game.queue_free()
	await process_frame
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.3).timeout
	await capture("海岛城-公园")
	game.bunny.position=Vector3(29,.1,11)
	game.bunny.velocity=Vector3.ZERO
	game.yaw=.25
	game.pitch=.55
	game.distance_=15
	await create_timer(1.1).timeout
	await capture("海岛城-菜园")
	game.hud.open_panel("bag")
	await create_timer(.3).timeout
	await capture("海岛城-背包")
	game.hud.close_panel()
	game.bunny.position=Vector3(2,.1,9)
	session.authority.state.time=3600*.9
	await create_timer(1).timeout
	await capture("海岛城-夜色")
	print("PREVIEW_FPS ",Engine.get_frames_per_second())
	game.queue_free()
	await process_frame
	quit()
