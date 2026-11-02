extends SceneTree
var failures: Array[String]=[]
var session: Node
var game: Node3D
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	session.authority.state.time=1800
	game.bunny.position=Vector3(0,.1,13)
	game.bunny.reset_physics_interpolation()
	await create_timer(3).timeout
	for action in ["move_right","move_left"]:
		Input.action_press(action)
		await create_timer(.35).timeout
		var error:=0.0
		for frame in range(65):
			await physics_frame
			var right:=Vector3(cos(game.yaw),0,-sin(game.yaw))
			var v: Vector3=game.bunny.velocity
			v.y=0
			if v.length()>.5: error=maxf(error,absf(v.normalized().dot(Vector3(-right.z,0,right.x))))
		Input.action_release(action)
		print("LATERAL_ERROR ",action," ",error)
		check(error<.001,"Steady horizontal heading "+action)
		await create_timer(.25).timeout
	game.bunny.position=Vector3(0,.1,9)
	game.bunny.reset_physics_interpolation()
	game.yaw=.16
	game.pitch=.46
	await create_timer(1).timeout
	await capture("新版-公园")
	var n: CharacterBody3D=game.npcs[3]
	n.position=game.bunny.position+Vector3(1.6,0,.6)
	n.reset_physics_interpolation()
	game.current_target=str(n.name)
	game.interact()
	await create_timer(.8).timeout
	check(game.hud.bubble.visible and not game.hud.overlay.visible,"NPC uses an in-world bubble")
	check(Vector2(n.velocity.x,n.velocity.z).length()<.001,"NPC stops during conversation")
	var direction: Vector3=game.bunny.position-n.position
	check(absf(angle_difference(n.visual.rotation.y,atan2(direction.x,direction.z)))<.02,"NPC faces the player")
	await capture("新版-NPC气泡")
	game.end_dialogue()
	check(not game.hud.bubble.visible,"Conversation dismisses cleanly")
	game.hud.open_panel("bag")
	var first: int=game.hud.content.get_child(0).get_instance_id()
	await create_timer(2.2).timeout
	check(first==game.hud.content.get_child(0).get_instance_id(),"Clock updates preserve existing inventory controls")
	game.hud.close_panel()
	game.bunny.position=Vector3(-8,.1,-16)
	game.bunny.reset_physics_interpolation()
	game.yaw=-.13
	game.pitch=.40
	await create_timer(1.5).timeout
	await capture("新版-商业街")
	var frames: Array[float]=[]
	var start:=Time.get_ticks_usec()
	var last:=start
	while Time.get_ticks_usec()-start<5000000:
		await process_frame
		var now:=Time.get_ticks_usec()
		frames.append(float(now-last)/1000)
		last=now
	frames.sort()
	print("FRAME_TIMES frames=",frames.size()," median_ms=",frames[frames.size()/2]," p95_ms=",frames[int(frames.size()*.95)]," max_ms=",frames[-1])
	print("CITY_REVISION_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
