extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const DB=preload("res://scripts/services/game_data.gd")
var failures: Array[String]=[]
var game: Node3D
var session: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func sweep(body: CharacterBody3D,start: Vector3,velocity_: Vector3,frames: int=70) -> Vector3:
	body.position=start
	body.reset_physics_interpolation()
	for i in range(frames):
		await physics_frame
		body.velocity=velocity_
		body.move_and_slide()
	return body.position
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(1).timeout
	var cat: CharacterBody3D=game.get_node("CatTeacher")
	check(game.npcs.size()==9,"Four rabbit passersby, three merchants, named cat and panda NPCs")
	check(cat.get_script()==game.bunny.get_script().get_base_script(),"Cat and rabbit share one animation/action controller")
	check(cat.rig_profile.species_id=="cat_teacher","Species uses its own measurements")
	var base_cat:=Animals.create("cat_teacher")
	check(base_cat.find_children("Wardrobe*","Node3D",true,false).is_empty(),"Base cat has no baked clothing")
	base_cat.free()
	check(cat.has_node("Visual/Wardrobe_neck"),"Named NPC wears its red-band bell through shared clothing")
	for id in DB.catalog().items:
		var item: Dictionary=DB.item(id)
		if item.kind!="clothing": continue
		Outfit.apply(cat,{item.slot:id})
		check(not cat.find_children("Wardrobe_"+item.slot,"Node3D",true,false).is_empty(),"Shared clothes fit cat: "+id)
	Outfit.apply(cat,{})
	cat.play_action("water",2)
	await create_timer(.5).timeout
	check(cat.right_arm.rotation.x<-.5,"Shared action poses animate cat's arm")
	cat.action=""
	var cat_start:=cat.position
	await create_timer(1).timeout
	check(cat.position.distance_to(cat_start)>.05,"Cat walks using the shared NPC driver")
	game.bunny.position=cat.position+Vector3(1.6,0,1.4)
	game.bunny.reset_physics_interpolation()
	game.current_target="CatTeacher"
	game.interact()
	await create_timer(.5).timeout
	check(game.hud.bubble.visible and game.hud.bubble_name.text=="猫咪老师","Cat stops and speaks through the shared dialogue bubble")
	check(Vector2(cat.velocity.x,cat.velocity.z).length()<.01,"Cat stops during dialogue")
	game.end_dialogue()
	var body:=Animals.create("bunny")
	body.collision_layer=0
	body.collision_mask=5
	game.add_child(body)
	body.set_physics_process(false)
	body.visual.hide()
	var p: Vector3=await sweep(body,Vector3(2.7,.1,5),Vector3(3.5,-1,0))
	check(p.x<3.65 and p.x>3.3,"Body and large head stop before the lamp post")
	p=await sweep(body,Vector3(29,.1,11.2),Vector3(0,-1,-3.5))
	check(p.z<8.5,"Farm gate remains walkable")
	p=await sweep(body,Vector3(25,.1,11.2),Vector3(0,-1,-3.5))
	check(p.z>10.2,"Farm fence blocks walking through rails")
	check(game.camera_query.collision_mask==1,"Small props do not cause follow-camera zoom jumps")
	print("ANIMALS_COLLISIONS_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
