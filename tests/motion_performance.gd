extends SceneTree
var session: Node
var game: Node3D
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	while game.preparing: await process_frame
	session.active=false
	game.hud.toast.hide()
	for test in [["night_first_orbit",.92,Vector3(0,.1,9)],["night_repeat_orbit",.92,Vector3(0,.1,9)],["day_orbit",.5,Vector3(0,.1,9)],["day_walk",.5,Vector3(0,.1,13)],["night_walk",.92,Vector3(0,.1,13)]]:
		session.authority.state.time=3600*float(test[1])
		game.bunny.position=test[2]
		game.bunny.reset_physics_interpolation()
		game.pitch=.42
		game.yaw=0
		await create_timer(1).timeout
		var times: Array[float]=[]
		var processes: Array[float]=[]
		var start:=Time.get_ticks_usec()
		var last:=start
		var over_25:=0
		var over_50:=0
		var far_lights:=0
		var total_lights:=0
		for lamp_ in game.lamps:
			if lamp_.get_node("NightLight").visible:
				total_lights+=1
				if lamp_.position.distance_to(game.bunny.position)>30: far_lights+=1
		var walking: bool=str(test[0]).ends_with("walk")
		if walking: Input.action_press("move_right")
		while Time.get_ticks_usec()-start<6000000:
			if not walking: game.yaw=float(Time.get_ticks_usec()-start)/1000000*TAU/6.0
			await process_frame
			var now:=Time.get_ticks_usec()
			var ms:=float(now-last)/1000
			times.append(ms)
			processes.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			if ms>25: over_25+=1
			if ms>50: over_50+=1
			last=now
		Input.action_release("move_right")
		times.sort()
		processes.sort()
		print("MOTION_BENCH ",test[0]," frames=",times.size()," median=",times[times.size()/2]," p95=",times[int(times.size()*.95)]," p99=",times[int(times.size()*.99)]," max=",times[-1]," over25=",over_25," over50=",over_50," cpu95=",processes[int(processes.size()*.95)]," lights=",total_lights," far_lights=",far_lights," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
