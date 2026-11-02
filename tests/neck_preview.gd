extends SceneTree
const G=preload("res://scripts/geometry.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const DB=preload("res://scripts/services/game_data.gd")
var stage: Node3D
var camera: Camera3D
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func run() -> void:
	root.size=Vector2i(1800,1120)
	stage=Node3D.new()
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("d7e1d7")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d5dfd2")
	env.ambient_light_energy=.55
	environment.environment=env
	stage.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-35,0)
	sun.light_energy=.5
	stage.add_child(sun)
	camera=Camera3D.new()
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=9.2
	stage.add_child(camera)
	camera.position=Vector3(0,3.5,20)
	camera.look_at(Vector3(0,3.5,0))
	var actors: Array[Node3D]=[]
	var items: Array[String]=["scarf_red","scarf_blue","scarf_green","bell_red","bell_blue","bell_green"]
	for i in range(items.size()):
		var anchor:=Node3D.new()
		stage.add_child(anchor)
		anchor.position=Vector3((i%3-1)*4.9,4.1 if i<3 else .1,0)
		for j in range(2):
			var animal:=Animals.create("bunny" if j==0 else "cat_teacher")
			anchor.add_child(animal)
			animal.position.x=-.95 if j==0 else .95
			animal.scale=Vector3.ONE*.88
			Outfit.apply(animal,{"neck":items[i]})
			actors.append(animal)
		var label_:=G.text3d(anchor,DB.item(items[i]).name,Vector3(0,-.25,.3),25,Color("3c6655"))
		label_.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	await create_timer(.4).timeout
	await capture("更新-六款脖子饰品")
	for actor in actors: actor.get_parent().hide()
	var cat:=Animals.create("cat_teacher")
	stage.add_child(cat)
	cat.position.x=-1.15
	Outfit.apply(cat,{"neck":"bell_red"})
	var bunny:=Animals.create("bunny")
	stage.add_child(bunny)
	bunny.position.x=1.15
	Outfit.apply(bunny,{"head":"bow_rose","neck":"scarf_blue"})
	camera.size=4.2
	camera.position=Vector3(1.7,2.4,10)
	camera.look_at(Vector3(0,1.4,0))
	await create_timer(.3).timeout
	await capture("更新-猫咪老师与耳侧蝴蝶结")
	Outfit.apply(cat,{"head":"bow_rose","neck":"bell_red"})
	bunny.hide()
	cat.position.x=0
	camera.size=3.3
	camera.position=Vector3(-3,2.2,6)
	camera.look_at(Vector3(0,1.15,0))
	await create_timer(.3).timeout
	await capture("更新-猫咪老师耳侧蝴蝶结")
	Outfit.apply(cat,{"neck":"scarf_red"})
	Outfit.apply(bunny,{"head":"bow_rose","neck":"scarf_blue"})
	bunny.show()
	cat.position.x=-1.15
	bunny.position.x=1.15
	camera.size=5.0
	camera.position=Vector3(-6,2.6,5)
	camera.look_at(Vector3(0,1.35,0))
	await create_timer(.3).timeout
	await capture("更新-饰品侧面贴合")
	quit()
