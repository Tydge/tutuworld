extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const G=preload("res://scripts/geometry.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps=30;root.size=Vector2i(1440,1000)
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("dfe8dc");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("dae5df");env.ambient_light_energy=.55;environment.environment=env;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);sun.light_energy=1.20;sun.shadow_enabled=true;stage.add_child(sun)
	G.cylinder(stage,Vector3(0,-.05,0),1.1,.10,G.mat("c7d8b9"))
	var actor:=Animals.create("panda");stage.add_child(actor)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.05;camera.position=Vector3(0,1.90,7);stage.add_child(camera);camera.look_at(Vector3(0,1.38,0));camera.current=true
	for pose in [[0.0,"正面"],[PI*.5,"侧面"],[PI,"背面"],[-.55,"四分之三"]]:
		actor.visual.rotation.y=pose[0];await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/熊猫模型-"+pose[1]+".png")
	Outfit.apply(actor,{"head":"beret_plaid_sage","neck":"scarf_red"});actor.visual.rotation.y=-.35
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/熊猫模型-又木.png")
	for look in [
		{"head":"bow_rose","body":"overalls_sage","neck":"bell_blue"},
		{"head":"beret_honey","body":"apron_rose","neck":"scarf_blue"},
		{"head":"beret_plaid_sage","body":"vest_honey","neck":"bell_green"}]:
		Outfit.apply(actor,look);actor.visual.rotation.y=-.35
		await create_timer(.2).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/熊猫服饰-"+look.body+".png")
	print("PANDA_MODEL_PREVIEW_COMPLETE");quit()
