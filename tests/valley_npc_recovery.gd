extends SceneTree
const Server=preload("res://server/world_server.gd")
# Captured after normal roaming: the nearest grid cell is legal, but a narrow
# slope strip blocks the direct approach. Repathing to that cell cannot help.
const STUCK=Vector3(-12.04554271698,3.22191667556763,13.6766376495361)
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18955")
	OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/valley-npc-recovery-"+str(Time.get_ticks_usec())))
	var server:=Server.new();root.add_child(server)
	while not server.ready_for_players:await process_frame
	server.set_process(false);server.world.state.time=1800.
	var host: Node3D=server.maps.valley
	while not host.navigation.ready_for_paths:await physics_frame
	for npc in host.npcs:
		npc.collision_layer=0;npc.set_physics_process(false)
		for child in npc.get_children():child.set_physics_process(false)
	var cell: Vector2i=host.navigation.closest_free(STUCK)
	var toward:=Vector3(cell.x-STUCK.x,0,cell.y-STUCK.z).normalized()
	check(cell==Vector2i(-12,14) and not host.navigation.can_step(STUCK,STUCK+toward*.02),"Captured slope blocks the direct approach to the nearest free cell")
	Engine.physics_ticks_per_second=600;Engine.max_physics_steps_per_frame=64;Engine.time_scale=10
	for id in ["ValleyVisitor0","ValleyVisitor1"]:
		var npc: CharacterBody3D=host.targets[id].node
		var driver: Node=npc.get_node("VisitorRoutine")
		npc.position=STUCK;npc.velocity=Vector3.ZERO;npc.reset_physics_interpolation()
		driver.presence=1.;driver.apply_presence();driver.rng.seed=427
		driver.path=host.navigation.path_between(STUCK,Vector3(25,0,-35));driver.path_index=0
		driver.wait=0.;driver.recovery_time=0.;driver.cooldown=0.;driver.progress_clock=0.;driver.progress_origin=STUCK;driver.speed=1.45
		check(driver.path.size()>2,"Real server navigation provides a route through the blocked first cell: "+id)
		driver.set_physics_process(true)
		var last:=STUCK;var travelled:=0.;var max_step:=0.;var stayed_on_land:=true;var late_start:=STUCK
		for frame in range(480):
			await physics_frame
			var step:=npc.position.distance_to(last);travelled+=step;max_step=maxf(max_step,step);last=npc.position
			stayed_on_land=stayed_on_land and host.can_walk(npc.position) and npc.position.y>0
			if frame==360:late_start=npc.position
		print("VALLEY_NPC_RECOVERY ",JSON.stringify({"id":id,"position":str(npc.position),"travelled":travelled,"displacement":npc.position.distance_to(STUCK),"late_displacement":npc.position.distance_to(late_start),"max_step":max_step,"recoveries":driver.recovery_count}))
		check(npc.position.distance_to(STUCK)>1.5 and npc.position.distance_to(late_start)>.4,"Visitor escapes and continues walking rather than retrying in place: "+id)
		check(stayed_on_land and max_step<.15,"Recovery keeps real collision and supported movement without teleporting: "+id)
		driver.set_physics_process(false);npc.set_physics_process(false);npc.collision_layer=0;npc.position=Vector3(0,-50,0)
	Engine.time_scale=1.;Engine.physics_ticks_per_second=60;Engine.max_physics_steps_per_frame=8
	server.listener.stop();server.queue_free();await process_frame
	print("VALLEY_NPC_RECOVERY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
