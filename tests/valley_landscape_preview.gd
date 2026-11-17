extends SceneTree
const L=preload("res://scripts/valley/valley_layout.gd")
var session: Node
var game: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func point(x: float,z: float) -> Vector3:return Vector3(x,L.walk_height(x,z)+.035,z)
func capture(name_: String,actor: Vector3,offset: Vector3,target_offset: Vector3=Vector3(0,1.35,0),time_: float=.5) -> void:
	game.bunny.position=actor;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();game.camera.position=actor+offset;game.camera.look_at(actor+target_offset);game.update_lighting(time_)
	for i in range(15):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/"+name_+".png")
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.settings.fullscreen=false;session.create_character("新山谷访客","panda","scarf_green");session.state().map_id="valley";session.state().player_position=L.arrival("valley");session.state().time=1800
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,1000)
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null or not game.navigation.ready_for_paths:await process_frame
	await create_timer(.7).timeout;session.active=false;game.set_process(false);game.bunny.can_move=false;game.hud.hide()
	await capture("01-valley-arrival",point(-22,86),Vector3(-10,6,14),Vector3(0,4,-14))
	await capture("02-river-bridge",point(-5,10),Vector3(-12,7,15),Vector3(5,2,-4))
	await capture("03-forest-trail",point(L.west_path(-28),-28),Vector3(3.5,4.8,12),Vector3(0,3,-10))
	await capture("04-hillside",point(44,-35),Vector3(9,6,14),Vector3(-7,3,-15))
	await capture("05-cottage-clearing",point(24,-61),Vector3(10,7,16),Vector3(0,3,-9))
	game.bunny.hide()
	await capture("06-wide-valley",point(-28,20),Vector3(32,37,46),Vector3(16,5,-24))
	game.bunny.show()
	await capture("09-west-overlook",point(-72,L.ascent_path_z(-72)),Vector3(-9,10,-9),Vector3(35,-12,6))
	await capture("10-valley-floor",point(-11,-23),Vector3(6,3.7,10),Vector3(-35,12,-15))
	await capture("11-sunlit-water",point(-17,94.4),Vector3(8,7,-12),Vector3(15,-.5,8),.34)
	await capture("07-water-close",point(-11,94.4),Vector3(7,4,9),Vector3(10,-.5,0))
	game.queue_free();await process_frame;session.state().map_id="city";session.state().player_position=[14,.2,37]
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null:await process_frame
	await create_timer(.8).timeout;game.set_process(false);game.bunny.can_move=false;game.hud.hide()
	await capture("08-town-ocean",Vector3(14,.2,39),Vector3(8,5,9),Vector3(18,0,16))
	print("VALLEY_LANDSCAPE_PREVIEW_RESULT PASS");quit()
