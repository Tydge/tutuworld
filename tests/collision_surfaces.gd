extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
var game: Node3D
var session: Node
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func sweep(body: CharacterBody3D,p: Vector3,velocity_: Vector3,frames: int=75) -> Vector3:
	body.position=p
	body.reset_physics_interpolation()
	for i in range(frames):
		await physics_frame
		body.velocity=velocity_
		body.move_on_ground(1.0/60)
	return body.position
func run() -> void:
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(.7).timeout
	session.active=false
	game.bunny.position=Vector3(-40,.1,35)
	for npc in game.npcs:
		for node in npc.get_children():
			if node.get_script()==load("res://scripts/city/npc_driver.gd"): node.set_physics_process(false)
		npc.velocity=Vector3.ZERO
	for species in ["bunny","cat_teacher"]:
		var body:=Animals.create(species)
		game.add_child(body)
		body.set_physics_process(false)
		var p:=await sweep(body,Vector3(7,.15,21),Vector3(-3,-1,0),100)
		check(p.x<3.0 and p.y>.045,"Crosses curb and stands on paving: "+species+" "+str(p))
		p=await sweep(body,Vector3(-5.8,.15,13),Vector3(0,-1,-3))
		check(p.z>10.75,"Welcome sign blocks actor: "+species+" "+str(p))
		p=await sweep(body,Vector3(26.3,.15,13),Vector3(0,-1,-3))
		check(p.z>10.65,"Garden sign and fence block actor: "+species)
		p=await sweep(body,Vector3(29,.15,11.2),Vector3(0,-1,-3))
		check(p.z<8.8,"Farm entrance remains open: "+species)
		p=await sweep(body,Vector3(10,.15,38),Vector3(3,-1,0))
		check(p.x>11.7 and p.y>=.10,"Wooden pier supports feet: "+species+" "+str(p))
		body.queue_free()
		await process_frame
	var a: CharacterBody3D=game.get_node("Passerby0")
	var b: CharacterBody3D=game.get_node("Passerby1")
	a.position=Vector3(-2,.15,22)
	b.position=Vector3(2,.15,22)
	for i in range(90):
		await physics_frame
		a.velocity=Vector3(2,-1,0)
		b.velocity=Vector3(-2,-1,0)
		a.move_on_ground(1.0/60)
		b.move_on_ground(1.0/60)
	check(a.position.x<b.position.x and a.position.distance_to(b.position)>1.67,"Actual NPCs cannot walk through each other")
	var cat: CharacterBody3D=game.get_node("CatTeacher")
	a.position=Vector3(-2,.15,22)
	cat.position=Vector3(2,.15,22)
	b.position=Vector3(-20,.15,18)
	for i in range(90):
		await physics_frame
		a.velocity=Vector3(2,-1,0)
		cat.velocity=Vector3(-2,-1,0)
		a.move_on_ground(1.0/60)
		cat.move_on_ground(1.0/60)
	check(a.position.x<cat.position.x and a.position.distance_to(cat.position)>1.5,"Rabbit and cat NPC collision prevents overlapping bodies and heads")
	print("COLLISION_SURFACES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
