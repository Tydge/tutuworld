extends SceneTree
var session: Node
var game: Node3D
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func capture(label_: String,local: Vector3,yaw_: float,pitch_: float,distance_: float,time_: float) -> void:
	session.state().time=time_*3600
	game.update_lighting()
	game.bunny.position=game.home.to_global(local)
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	game.yaw=yaw_;game.pitch=pitch_;game.distance_=distance_
	await create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label_+".png")
	print("CAPTURE ",label_," indoor=",game.home.inside," weight=",game.home.interior_weight)
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	await create_timer(1).timeout
	session.active=false
	game.bunny.can_move=false
	game.hud.photo_mode=true;game.hud.root_ui.hide()
	await capture("海风小屋-日间外观",Vector3(0,.3,8.2),.48,.54,19,.50)
	await capture("海风小屋-黄昏外观",Vector3(0,.3,8.2),.48,.54,19,.735)
	await capture("海风小屋-夜间外观",Vector3(0,.3,8.2),.48,.54,19,.92)
	game.home.toggle_door(game.bunny)
	await create_timer(.8).timeout
	await capture("海风小屋-敞门与玄关",Vector3(0,.3,7.5),.30,.43,12,.50)
	await capture("海风小屋-日间室内",Vector3(0,.3,.7),.38,.60,14.5,.50)
	await capture("海风小屋-夜间室内",Vector3(0,.3,.7),.38,.60,14.5,.92)
	await capture("海风小屋-窗边细节",Vector3(2.0,.3,1.5),.35,.48,8.8,.50)
	await capture("海风小屋-沙发与壁炉",Vector3(-2.6,.3,-.1),-.42,.56,9.7,.92)
	session.active=false
	game.bunny.position=Vector3(0,.2,9);game.bunny.reset_physics_interpolation();game.yaw=.2;game.pitch=.33;game.distance_=13
	for row in [["光影更新-日间公园",.5],["光影更新-夜间公园",.92]]:
		session.state().time=row[1]*3600;game.update_lighting();await create_timer(1).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+row[0]+".png")
	print("HOME_ART_PREVIEW_COMPLETE");quit()
