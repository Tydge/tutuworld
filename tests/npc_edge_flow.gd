extends SceneTree
const Driver=preload("res://scripts/city/npc_driver.gd")
var checks:=0
var failures: Array[String]=[]
var city: Node3D
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func settle(actor: CharacterBody3D,p: Vector3) -> void:
	# Start above the actual deck, which now arches a metre above the old plane.
	var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*4.,p-Vector3.UP*3.,8))
	if not hit.is_empty():p.y=maxf(p.y,hit.position.y+.2)
	actor.position=p;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	for i in 12:
		await physics_frame;actor.velocity=Vector3(0,-.6,0);actor.move_on_ground(1./60.)
func follow(driver: Node,target: Vector3) -> Dictionary:
	driver.path=city.navigation.path_between(driver.bunny.position,target);driver.path_index=0;driver.wait=0.;driver.recovery_time=0.;driver.cooldown=0.;driver.speed=1.65;driver.rng.seed=427
	var min_y: float=driver.bunny.position.y;var arrived:=false
	for i in 1500:
		await physics_frame;driver._physics_process(1./60.)
		min_y=minf(min_y,driver.bunny.position.y)
		if Vector2(driver.bunny.position.x-target.x,driver.bunny.position.z-target.z).length()<.65:arrived=true;break
		if driver.bunny.position.y<-.8:break
	return {"arrived":arrived,"min_y":min_y,"position":driver.bunny.position}
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("岸边检查兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.preparing or not city.navigation.ready_for_paths:await process_frame
	session.active=false;city.set_process(false);city.bunny.set_physics_process(false);city.bunny.position=Vector3(35,.2,7)
	for npc in city.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED
	var nav: Node=city.navigation
	check(city.scenery.get_node("Island/GroundCollision").collision_layer==8 and nav.supported(Vector3(-10,0,17.7),city.get_world_3d().direct_space_state),"Mainland grass is registered as real walkable ground, including the cat teacher spawn")
	check(not city.can_walk(Vector3(57,0,16.4)),"The logical connector excludes the unsupported strip beyond its real collision surface")
	check(nav.grid.is_point_solid(Vector2i(58,17)) and nav.grid.is_point_solid(Vector2i(57,16)),"Bridge/land corner nodes with unsupported feet are excluded from navigation")
	check(not nav.can_step(Vector3(58.5,-.30,17.5),Vector3(58.4,-.30,17.5)),"Real-time steering cannot walk a supported actor outward over the corner")
	check(nav.can_step(Vector3(58.3,-.30,17.5),Vector3(58.4,-.30,17.5)),"An actor displaced to the edge can retreat toward safe land naturally")
	var route: PackedVector3Array=nav.path_between(Vector3(54,.05,13),Vector3(65,.05,20));var supported:=route.size()>2
	for point in route:
		if not nav.supported(point,city.get_world_3d().direct_space_state):supported=false
	check(supported,"The connector retains a continuous path with real floor support at every node")
	Engine.time_scale=3.0
	for species in ["bunny","cat_teacher","panda"]:
		var actor: CharacterBody3D=city.spawn_npc("Edge_"+species,"岸边检查",Vector3(59,.2,17.5),{},species);actor.set_physics_process(false)
		var driver:=Driver.new();driver.city=city;driver.bunny=actor;actor.add_child(driver);driver.set_physics_process(false)
		await settle(actor,Vector3(59.1,.2,17.5));driver.path=PackedVector3Array([Vector3(57.9,0,17.5)]);driver.path_index=0;driver.speed=1.65;driver.wait=0.;driver.rng.seed=42
		var min_y: float=actor.position.y;var stayed_on_land:=true
		for i in 240:
			await physics_frame;driver._physics_process(1./60.);min_y=minf(min_y,actor.position.y)
			if not city.can_walk(actor.position):stayed_on_land=false
		print("EDGE_STEERING ",species," minimum_y=",min_y," position=",actor.position," stayed_on_land=",stayed_on_land)
		check(min_y>-.5 and stayed_on_land,"Unsafe corner steering is corrected without falling or teleporting: "+species)
		await settle(actor,Vector3(54,.2,13));var outward:=await follow(driver,Vector3(65,0,20))
		check(outward.arrived and outward.min_y>-.5,"The real NPC driver walks from the town across the connector onto land: "+species)
		var back:=await follow(driver,Vector3(54,0,13));check(back.arrived and back.min_y>-.5,"The real NPC driver walks back around the same corner without dropping: "+species)
		print("EDGE_WALK ",species," outward=",outward," return=",back)
		city.npcs.erase(actor);actor.queue_free();await process_frame
	Engine.time_scale=1.
	city.camera.position=Vector3(65,10,25);city.camera.look_at(Vector3(57,0,16))
	for i in 7:await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out+"/supported-bridge-corner.png")
	print("NPC_EDGE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
