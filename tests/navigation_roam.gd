extends SceneTree
var session: Node
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	while game.preparing: await process_frame
	session.active=false
	var drivers: Array=[]
	var records: Dictionary={}
	for npc in game.npcs:
		for child in npc.get_children():
			if child.get_script()==load("res://scripts/city/npc_driver.gd"):
				drivers.append(child)
				records[npc.name]={"distance":0.0,"last":npc.position,"stalls":0,"same_place":0}
	# Observe a minute of wandering, including corners and other moving actors.
	Engine.time_scale=2.0
	for sample in range(60):
		await create_timer(1).timeout
		for driver in drivers:
			var npc: Node3D=driver.bunny
			var row: Dictionary=records[npc.name]
			var delta: float=npc.position.distance_to(row.last)
			row.distance+=delta
			row.last=npc.position
			row.same_place=row.same_place+1 if delta<.15 and driver.wait<=0 else 0
			row.stalls=maxi(row.stalls,row.same_place)
	var failures: Array=[]
	for driver in drivers:
		var row: Dictionary=records[driver.bunny.name]
		print("ROAM ",driver.bunny.name," distance=",snappedf(row.distance,.01)," recoveries=",driver.recovery_count," repaths=",driver.repath_count," max_stall_seconds=",row.stalls)
		if row.distance<15 or row.stalls>5: failures.append(driver.bunny.name)
	Engine.time_scale=1
	print("NAVIGATION_ROAM_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
