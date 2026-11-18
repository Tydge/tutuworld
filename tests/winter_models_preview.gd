extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("718aa7");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);stage.add_child(sun)
	var cam:=Camera3D.new();cam.position=Vector3(16,15,21);cam.look_at_from_position(cam.position,Vector3(0,4,0));stage.add_child(cam);cam.current=true
	var model: Node3D=load("res://scenes/winter/chalet.scn").instantiate();stage.add_child(model)
	for i in range(10):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/chalet.png")
	print("WINTER_MODELS_PREVIEW_RESULT PASS");quit()
