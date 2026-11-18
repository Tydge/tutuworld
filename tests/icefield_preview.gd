extends SceneTree
const L=preload("res://scripts/icefield/icefield_layout.gd")
var session: Node
var game: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func point(x: float,z: float) -> Vector3:return Vector3(x,L.walk_height(x,z)+.035,z)
func capture(id: String,p: Vector3,offset: Vector3,aim: Vector3,time_: float=.5) -> void:
	game.bunny.position=p;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.state().time=time_*3600.;game.update_lighting(time_)
	game.camera.position=p+offset;game.camera.look_at(p+aim)
	for i in range(12):await process_frame;RenderingServer.force_draw()
	RenderingServer.force_draw();root.get_texture().get_image().save_png(output+"/"+id+".png")
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.fullscreen=false;session.settings.background_throttle=false
	session.create_character("冰原访客","bunny","scarf_red");session.state().map_id="icefield";session.state().player_position=L.arrival();session.state().time=1800
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,1000)
	game=load("res://scenes/icefield.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null or not game.navigation.ready_for_paths:await process_frame
	session.active=false;game.set_process(false);game.bunny.can_move=false;game.hud.hide()
	await capture("01-frostlight-town",point(-69,40),Vector3(34,26,34),Vector3(-17,5,-40),.73)
	await capture("02-blue-ice",point(24,27),Vector3(12,5,16),Vector3(20,5,-70),.73)
	await capture("03-lakeside-town",point(55,6),Vector3(13,8,18),Vector3(-110,10,-10),.72)
	await capture("04-snow-street",point(-79,3),Vector3(4,5.5,13),Vector3(0,2,-17),.5)
	await capture("05-festival-night",point(-63,43),Vector3(13,9,20),Vector3(0,4,-16),.92)
	await capture("06-island-wide",point(10,20),Vector3(70,110,145),Vector3(-35,0,-10),.5)
	await capture("07-arrival",point(-106,116),Vector3(11,6,15),Vector3(3,6,-35),.72)
	await capture("08-campfire",point(-38,37),Vector3(5,3,7),Vector3(0,.6,-4),.94)
	await capture("09-midnight-before",point(96,108),Vector3(8,4,13),Vector3(0,3,70),.999)
	await capture("10-midnight-after",point(96,108),Vector3(8,4,13),Vector3(0,3,70),.001)
	await capture("11-mountain-edge",point(127,58),Vector3(-6,5,12),Vector3(85,12,12),.72)
	await capture("12-southern-coast",point(62,132),Vector3(7,7,-12),Vector3(0,1,20),.70)
	print("ICEFIELD_PREVIEW_RESULT PASS");game.queue_free();await process_frame;quit()
