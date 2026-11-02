extends SceneTree
const G=preload("res://scripts/geometry.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
var stage: Node3D
var cat: CharacterBody3D
var camera: Camera3D
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
	print("CAPTURE ",label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	stage=Node3D.new()
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("cbd9cf")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d5dfd2")
	env.ambient_light_energy=.5
	environment.environment=env
	stage.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-35,0)
	sun.light_energy=.5
	sun.shadow_enabled=true
	stage.add_child(sun)
	G.box(stage,Vector3(0,-.05,0),Vector3(20,.10,20),G.mat("b5c9b5"))
	cat=Animals.create("cat_teacher")
	stage.add_child(cat)
	camera=Camera3D.new()
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.6
	stage.add_child(camera)
	for entry in [["正面",Vector3(0,1.65,6)],["三视角",Vector3(4,2.3,6)],["侧面",Vector3(6,1.8,.1)],["背面",Vector3(-3,2.3,-6)]]:
		camera.position=entry[1]
		camera.look_at(Vector3(0,.95,0))
		await create_timer(.45).timeout
		await capture("猫咪老师-"+entry[0])
	camera.position=Vector3(4,2.3,6)
	camera.look_at(Vector3(0,.95,0))
	Outfit.apply(cat,{"head":"beret_sage","body":"vest_sage"})
	await create_timer(.4).timeout
	await capture("共用换装-猫咪老师")
	Outfit.apply(cat,{})
	var bunny:=Animals.create("bunny")
	stage.add_child(bunny)
	cat.position.x=-1.25
	bunny.position.x=1.25
	camera.size=5.4
	camera.position=Vector3(4,2.7,8)
	camera.look_at(Vector3(0,1.15,0))
	await create_timer(.5).timeout
	await capture("角色对比-兔兔与猫咪老师")
	quit()
