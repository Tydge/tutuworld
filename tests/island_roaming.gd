extends SceneTree
var session: Node
var game: Node3D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1280,800)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);Engine.max_fps=30
	session.create_character("看风景","panda","vest_sage")
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	while not game.navigation.ready_for_paths: await process_frame
	session.active=false
	var nav: Node=game.navigation;var rng:=RandomNumberGenerator.new();rng.seed=5732
	var source:=Vector3(0,0,9);var seen: Dictionary={};var recent: Array[int]=[];var reachable:=true;var legal:=true
	var extents:=Vector4(100,-100,100,-100)
	for i in range(54):
		var goal: Dictionary=nav.random_destination(source,rng,recent)
		if goal.is_empty(): reachable=false;break
		var path: PackedVector3Array=nav.path_between(source,goal.position)
		reachable=reachable and path.size()>1
		for point in path: legal=legal and game.can_walk(point) and not nav.grid.is_point_solid(Vector2i(roundi(point.x),roundi(point.z)))
		seen[goal.zone]=true;source=goal.position;recent.append(goal.zone)
		if recent.size()>4: recent.pop_front()
		extents.x=minf(extents.x,source.x);extents.y=maxf(extents.y,source.x);extents.z=minf(extents.z,source.z);extents.w=maxf(extents.w,source.z)
		if i%6==0: await process_frame
	check(reachable and legal,"Random destinations have real connected, obstacle-free paths inside the island")
	check(seen.size()==9,"Destination sampling covers all nine island regions")
	check(extents.x< -35 and extents.y>35 and extents.z< -30 and extents.w>30,"Destinations extend to west/east neighborhoods and north/south shores: "+str(extents))
	var drivers: Array=[];var rows: Dictionary={};var visited_zones: Dictionary={}
	for npc in game.npcs:
		for node in npc.get_children():
			if node.get_script()!=load("res://scripts/city/npc_driver.gd"): continue
			drivers.append(node);rows[npc.name]={"last":npc.position,"distance":0.0,"stall":0,"longest":0}
			check(node.route.is_empty(),"Resident uses island-wide destinations, not a fixed street loop: "+str(npc.name))
	Engine.time_scale=2.0
	for i in range(60):
		await create_timer(1).timeout
		for driver in drivers:
			var row: Dictionary=rows[driver.bunny.name];var step: float=driver.bunny.position.distance_to(row.last)
			row.distance+=step;row.last=driver.bunny.position
			row.stall=row.stall+1 if step<.15 and driver.wait<=0 else 0;row.longest=maxi(row.longest,row.stall)
			visited_zones[nav.zone(driver.bunny.position)]=true
	Engine.time_scale=1.0
	for driver in drivers:
		var row: Dictionary=rows[driver.bunny.name]
		print("ISLAND_ROAM ",driver.bunny.name," distance=",row.distance," longest_stall=",row.longest," recoveries=",driver.recovery_count)
		check(row.distance>20 and row.longest<=5,"Resident keeps moving without repeated-wall stalls: "+str(driver.bunny.name))
	check(visited_zones.size()>=5,"Observed residents actually spread beyond the park and commercial street: "+str(visited_zones.keys()))
	print("ISLAND_ROAMING_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
