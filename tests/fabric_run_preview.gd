extends SceneTree
const G=preload("res://scripts/geometry.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
var stage: Node3D
var camera: Camera3D
var actors: Array[CharacterBody3D]=[]
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func run() -> void:
	root.size=Vector2i(1600,1000)
	stage=Node3D.new()
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("dfe7da")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e9eedf")
	env.ambient_light_energy=.55
	environment.environment=env
	stage.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=.65
	stage.add_child(sun)
	camera=Camera3D.new()
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=10.8
	stage.add_child(camera)
	camera.position=Vector3(0,3.4,20)
	camera.look_at(Vector3(0,3.4,0))
	for row in range(2):
		for col in range(3):
			var species: String="bunny" if row==0 else "cat_teacher"
			var actor:=Animals.create(species)
			stage.add_child(actor)
			actor.position=Vector3((col-1)*4.6,3.7 if row==0 else .1,0)
			actor.visual.rotation.y=-.28 if col!=1 else .15
			var color_: String=["rose","sage","honey"][col]
			Outfit.apply(actor,{"head":"beret_plaid_"+color_,"body":"apron_"+color_})
			G.cylinder(stage,actor.position+Vector3(0,-.055,0),1.13,.08,G.mat("c0ceb6"))
			actors.append(actor)
	await create_timer(.4).timeout
	await capture("成长更新-新布料六套搭配")
	for actor in actors:
		actor.visual.rotation.y=.85
	await create_timer(.2).timeout
	await capture("成长更新-围裙侧面")
	for actor in actors: actor.queue_free()
	actors.clear()
	await process_frame
	var floor_:=G.solid_box(stage,Vector3(0,-.1,0),Vector3(100,.2,100))
	floor_.collision_layer=8
	G.box(stage,Vector3(0,-.11,0),Vector3(100,.2,100),G.mat("c0ceb6"))
	for species in ["bunny","cat_teacher"]:
		var actor:=Animals.create(species)
		stage.add_child(actor)
		await physics_frame
		actor.velocity.y=-1
		actor.move_and_slide()
		actor.set_physics_process(false)
		camera.size=3.8
		camera.position=Vector3(-3.7,2.0,6)
		camera.look_at(Vector3(0,1.45,0))
		for gait in ["walk","run"]:
			actor.walking=true
			actor.velocity=Vector3(0,0,actor.move_speed*(1.7 if gait=="run" else 1.0))
			actor.gait_blend=1
			actor.run_blend=1 if gait=="run" else 0
			for i in range(8):
				actor.step_phase=TAU*i/8.0
				actor.animate_pose(.4)
				await capture("姿态-%s-%s-%d"%[species,gait,i])
		actor.queue_free()
		await process_frame
	print("FABRIC_RUN_PREVIEW_COMPLETE")
	quit()
