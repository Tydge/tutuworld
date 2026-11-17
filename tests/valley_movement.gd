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
	print("BLOCKED_TRAVERSAL position=",actor.position," target=",to)
	for i in range(actor.get_slide_collision_count()):print("BLOCKED_COLLIDER ",actor.get_slide_collision(i).get_collider())
	return false
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().player_position=Layout.arrival("valley")
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(2).timeout
	session.active=false;game.bunny.can_move=false
	while not game.navigation.ready_for_paths: await physics_frame
	print("VALLEY_COMPONENTS ",game.navigation.destinations.size())
	for source in DB.resources("valley"):
		var path: PackedVector3Array=game.navigation.path_between(Vector3(-22,0,86),Vector3(source.x,source.y,source.z))
		check(path.size()>1,"Reachable resource "+source.id)
		if path.size()>1:
			check(absf(path[-1].y-Layout.walk_height(path[-1].x,path[-1].z))<.3,"Height-aware path "+source.id)
			check(Vector2(path[-1].x-source.x,path[-1].z-source.z).length()<game.targets[source.id].radius and absf(path[-1].y-source.y)<1.7,"Resource can be interacted with from its connected approach "+source.id)
	var bed_exit: Vector3=game.home.get_node("Furnishing/bed/SleepExit").global_position
	check(game.navigation.path_between(Vector3(-22,0,86),bed_exit).size()>1,"Connected cottage doorway and bed approach")
	# Isolate floor / bridge traversal from random roaming actors. Their schedules
	# and dialogue have dedicated resident and visitor integration checks.
	for npc in game.npcs:
		npc.collision_layer=0;npc.set_physics_process(false)
		for child in npc.get_children():child.set_physics_process(false);child.set_process(false)
	Engine.time_scale=3
	game.bunny.hide();game.bunny.collision_layer=0
	for species in ["bunny","cat_teacher","panda"]:
		var actor: CharacterBody3D=preload("res://scripts/characters/animal_factory.gd").create(species);game.add_child(actor)
		actor.set_physics_process(false);actor.world=null
		var routes: Array=[[Vector2(-16,10),Vector2(16,10),"river bridge"],[Vector2(-22,88),Vector2(-16.8,94.4),"harbor"],[Vector2(24,-60),Vector2(24,-66),"cottage approach"]]
		for side in [-1,1]:
			for x in range(34,78,6):routes.append([Vector2(side*x,Layout.ascent_path_z(x)),Vector2(side*(x+6),Layout.ascent_path_z(x+6)),"mountain ascent "+str(side)+" "+str(x)])
		for section in routes:
			var start:=Vector3(section[0].x,Layout.walk_height(section[0].x,section[0].y),section[0].y)
			var end:=Vector3(section[1].x,Layout.walk_height(section[1].x,section[1].y),section[1].y)
			var arrived: bool=await drive(actor,start,end)
			check(arrived,"Physical traversal "+species+" "+section[2])
			check(absf(actor.position.y-Layout.walk_height(actor.position.x,actor.position.z))<.3,"Feet on actual slope "+species+" "+section[2]+" y="+str(actor.position.y))
		actor.queue_free();await process_frame
	Engine.time_scale=1
	print("VALLEY_MOVEMENT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
