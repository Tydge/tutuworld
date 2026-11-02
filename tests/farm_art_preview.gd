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
	session.authority.state.time=1700
	game.bunny.position=Vector3(29,.1,10.9)
	game.bunny.reset_physics_interpolation()
	game.yaw=.35
	game.pitch=.66
	game.distance_=18
	await create_timer(2).timeout
	await capture("重做-菜园空地")
	for row in range(6):
		for col in range(5):
			var id:="plot_%02d"%(row*8+col)
			var crop: String=["carrot","lettuce","tomato","pumpkin"][col%4]
			var days: float=preload("res://scripts/services/game_data.gd").crop(crop).days
			session.authority.state.plots[id]={"crop":crop,"growth":days*3600*(.95 if row<4 else .35),"water_stage":2,"weed_stage":2}
	game.refresh_world()
	await create_timer(.5).timeout
	await capture("重做-菜园种植效果")
	game.bunny.position=Vector3(0,.1,9)
	game.bunny.reset_physics_interpolation()
	game.yaw=-.38
	game.pitch=.38
	game.distance_=16
	await create_timer(2).timeout
	await capture("重做-公园树冠")
	quit()
