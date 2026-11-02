extends SceneTree
const A=preload("res://scripts/services/local_authority.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func sample(label_: String,seconds: float) -> void:
	var times: Array[float]=[]
	var last:=Time.get_ticks_usec()
	var stop:=last+int(seconds*1000000)
	var over50:=0
	while Time.get_ticks_usec()<stop:
		await process_frame
		var now:=Time.get_ticks_usec()
		var ms: float=(now-last)/1000.0
		times.append(ms)
		if ms>50: over50+=1
		last=now
	times.sort()
	print("PROGRESS_BENCH ",label_," frames=",times.size()," p95=",times[int(times.size()*.95)]," max=",times[-1]," over50=",over50)
	if over50>0: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.authority=A.new()
		session.settings.player_species=species
		for id in load("res://scripts/services/game_data.gd").catalog().items:
			if load("res://scripts/services/game_data.gd").item(id).kind=="clothing": session.authority.add(id,1)
		session.state().equipment={"head":"beret_plaid_rose","body":"apron_sage","neck":""}
		game=load("res://scenes/city.tscn").instantiate()
		root.add_child(game)
		while game.preparing: await process_frame
		game.hud.toast.hide()
		game.bunny.position=Vector3(0,.2,-33)
		game.bunny.reset_physics_interpolation()
		game.yaw=0
		await create_timer(.4).timeout
		Input.action_press("sprint")
		Input.action_press("move_down")
		await create_timer(.1).timeout
		Input.action_release("sprint")
		await sample(species+"_run",4)
		Input.action_release("move_down")
		await create_timer(.3).timeout
		var before:=Time.get_ticks_usec()
		game.hud.open_panel("profile")
		print("PROFILE_CREATE ",species," ms=",(Time.get_ticks_usec()-before)/1000.0)
		await sample(species+"_profile_first_open",3)
		game.hud.close_panel()
		game.hud.open_panel("wardrobe")
		await sample(species+"_wardrobe_all",2)
		for category in ["head","body","neck"]:
			before=Time.get_ticks_usec()
			game.hud.filters.wardrobe=category
			game.hud.rebuild()
			print("FILTER_REBUILD ",species," ",category," ms=",(Time.get_ticks_usec()-before)/1000.0)
			await process_frame
		before=Time.get_ticks_usec()
		game.hud.open_panel("profile")
		print("PROFILE_REOPEN ",species," ms=",(Time.get_ticks_usec()-before)/1000.0)
		await sample(species+"_profile_reopen",2)
		game.queue_free()
		await process_frame
		await process_frame
	print("PROGRESS_PERFORMANCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
