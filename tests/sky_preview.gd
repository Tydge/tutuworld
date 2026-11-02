extends SceneTree
var session: Node
var game: Node3D
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
	print("CAPTURE ",label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	for entry in [[.5,"晴日"],[.76,"黄昏"],[.92,"星夜"]]:
		session.authority.state.time=3600*float(entry[0])
		game.bunny.position=Vector3(-8,.1,-16)
		game.bunny.reset_physics_interpolation()
		game.pitch=.20
		game.yaw=-.13
		game.distance_=16
		await create_timer(2).timeout
		await capture("天空-商业街-"+entry[1])
	game.set_process(false)
	game.bunny.can_move=false
	game.hud.visible=false
	game.camera.position=Vector3(0,3,37)
	game.camera.look_at(Vector3(-8,7,-35))
	await create_timer(.5).timeout
	await capture("天空-星月")
	game.camera.position=Vector3(13,3,40)
	game.camera.look_at(Vector3(13,5,140))
	await create_timer(.5).timeout
	await capture("天空-海天衔接-夜")
	session.authority.state.time=1800
	game.update_lighting()
	await create_timer(.5).timeout
	await capture("天空-海天衔接-日")
	game.queue_free()
	await process_frame
	var title=load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await create_timer(1).timeout
	await capture("新版-标题")
	quit()
