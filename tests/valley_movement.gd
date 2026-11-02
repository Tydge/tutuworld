extends SceneTree
const Layout=preload("res://scripts/valley/valley_layout.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array=[]
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func drive(actor: CharacterBody3D,from: Vector3,to: Vector3) -> bool:
	actor.position=from+Vector3(0,.08,0);actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	var elapsed:=0.0
	while elapsed<12:
		await physics_frame
		var delta: float=Engine.time_scale/Engine.physics_ticks_per_second;elapsed+=delta
		var direction:=to-actor.position;direction.y=0
		if direction.length()<.2: return true
		var move:=direction.normalized()*3.0
		actor.velocity.x=move.x;actor.velocity.z=move.z
		actor.velocity.y=-.5 if actor.is_on_floor() else actor.velocity.y-18*delta
		actor.move_on_ground(delta);actor.walking=true;actor.step_phase+=delta*8.6;actor.animate_pose(delta)
	return false
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().player_position=[-8,.1,32]
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(2).timeout
	session.active=false;game.bunny.can_move=false
	while not game.navigation.ready_for_paths: await physics_frame
	print("VALLEY_COMPONENTS ",game.navigation.destinations.size())
	for source in DB.resources("valley"):
		var path: PackedVector3Array=game.navigation.path_between(Vector3(-8,0,32),Vector3(source.x,source.y,source.z))
		check(path.size()>1,"Reachable resource "+source.id)
		if path.size()>1: check(path[-1].y>1.8 if source.z< -12 else true,"Height-aware path "+source.id)
	var bed_exit: Vector3=game.home.get_node("Furnishing/bed/SleepExit").global_position
	check(game.navigation.path_between(Vector3(-8,0,32),bed_exit).size()>1,"Connected cottage doorway and bed approach")
	Engine.time_scale=3
	game.bunny.hide();game.bunny.collision_layer=0
	for species in ["bunny","cat_teacher","panda"]:
		var actor: CharacterBody3D=preload("res://scripts/characters/animal_factory.gd").create(species);game.add_child(actor)
		actor.set_physics_process(false);actor.world=null
		for section in [[Vector3(22,0,-5),Vector3(22,2,-13),"up low"],[Vector3(22,2,-23),Vector3(22,4,-31),"up high"],[Vector3(22,4,-31),Vector3(22,2,-23),"down high"],[Vector3(12,2,-20),Vector3(12,4,-28),"cottage steps"],[Vector3(-7,0,5),Vector3(7,0,5),"bridge"]]:
			var arrived: bool=await drive(actor,section[0],section[1])
			check(arrived,"Physical traversal "+species+" "+section[2])
			check(absf(actor.position.y-section[1].y)<.3,"Feet on actual height "+species+" "+section[2]+" y="+str(actor.position.y))
		actor.queue_free();await process_frame
	Engine.time_scale=1
	print("VALLEY_MOVEMENT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
