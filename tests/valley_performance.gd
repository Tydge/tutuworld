extends SceneTree
var session: Node
var game: Node3D
var town:=false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(2400,1440);Engine.max_fps=60
	town=OS.get_cmdline_user_args().has("--city")
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("林间慢慢","panda","scarf_green");session.state().map_id="city" if town else "valley";session.state().player_position=[0,.1,9] if town else [-8,.1,32];session.state().time=1800
	game=load("res://scenes/city.tscn" if town else "res://scenes/valley.tscn").instantiate();root.add_child(game)
	while game.preparing or game.camera==null: await process_frame
	await create_timer(.8).timeout;session.active=false;game.bunny.can_move=false
	var failures: Array=[]
	var views: Array=[[Vector3(-7,.1,5),.5,"bridge-day"],[Vector3(22,2.1,-16),.5,"terraces-day"],[Vector3(12,4.2,-30),.92,"cottage-night"],[game.home.to_global(Vector3(-1,.3,1)),.92,"interior-night"]]
	if not town: views.append_array([[Vector3(3.4,.1,-8.4),.5,"cascade-day"],[Vector3(-7,.2,47.2),.5,"harbor-day"],[Vector3(-7,.2,47.2),.92,"harbor-night"]])
	if town: views=[[Vector3(0,.1,9),.5,"park-day"],[Vector3(0,.1,9),.92,"park-night"],[Vector3(15,.1,33),.5,"coast-day"]]
	for view in views:
		game.bunny.position=view[0];game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.state().time=view[1]*3600;game.update_lighting()
		game.distance_=13.5;game.yaw=.35;await create_timer(.8).timeout
		var compilations: Array=[]
		for monitor_ in range(34,39): compilations.append(Performance.get_monitor(monitor_))
		var samples: Array[float]=[];var draws:=0;var start:=Time.get_ticks_usec();var last:=start
		while Time.get_ticks_usec()-start<2000000:
			game.yaw+=.012;await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();samples.append((now-last)/1000.);last=now
			if samples[-1]>40:
				var live: Array=[]
				for monitor_ in range(34,39): live.append(Performance.get_monitor(monitor_))
				print("SLOW_FRAME ",view[2]," ms=",samples[-1]," cpu_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," render_setup=",RenderingServer.get_frame_setup_time_cpu()," pipelines=",live," starting=",compilations)
			draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		samples.sort();var slow: int=samples.filter(func(v):return v>50.).size()
		print("TOWN_PERF " if town else "VALLEY_PERF ",view[2]," fps=",samples.size()/2.," p95_ms=",samples[int(samples.size()*.95)]," max_ms=",samples[-1]," over50=",slow," draws=",draws)
		if slow>0 or samples[int(samples.size()*.95)]>34: failures.append(view[2])
	print("TOWN_PERFORMANCE_RESULT " if town else "VALLEY_PERFORMANCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
