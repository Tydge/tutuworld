extends SceneTree
const L=preload("res://scripts/icefield/icefield_layout.gd")
var session: Node
var game: Node3D
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	# Drive exactly one render per sample. Mixing automatic rendering with force_draw
	# creates two vsync waits and incorrectly reports a stable 60 Hz scene as 30 Hz.
	RenderingServer.set_render_loop_enabled(false)
	root.size=Vector2i(2400,1440);Engine.max_fps=60
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.background_throttle=false
	session.create_character("冰原性能测试","panda","scarf_red");session.state().map_id="icefield";session.state().player_position=L.arrival();session.state().time=1800.
	Engine.max_fps=60
	game=load("res://scenes/icefield.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null or not game.navigation.ready_for_paths or game.preparing:await process_frame
	session.active=false;game.bunny.can_move=false
	var results: Array=[]
	for view in [[-79.,12.,.5,"town-day"],[-63.,43.,.92,"festival-night"],[45.,26.,.73,"ice-sunset"],[18.,32.,.5,"ice-fishing"],[-104.,116.,.5,"harbor"]]:
		game.bunny.position=Vector3(view[0],L.walk_height(view[0],view[1])+.035,view[1]);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.state().time=view[2]*3600.;game.update_lighting();game.yaw=.25;game.pitch=.28
		var warm_start:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-warm_start<1800000:game.yaw+=.012;await process_frame;RenderingServer.force_draw()
		var samples: Array[float]=[];var cpu: Array[float]=[];var draws:=0;var start:=Time.get_ticks_usec();var last:=start
		while Time.get_ticks_usec()-start<3000000:
			game.yaw+=.009;await process_frame;RenderingServer.force_draw()
			var now:=Time.get_ticks_usec();samples.append((now-last)/1000.);last=now
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
			draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var actual: float=(last-start)/1000000.;samples.sort();var slow: int=samples.filter(func(v):return v>50.).size()
		cpu.sort()
		var row:={"view":view[3],"fps":samples.size()/actual,"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples[-1],"over50":slow,"draws":draws,"cpu_p95_ms":cpu[int(cpu.size()*.95)],"frame_setup_ms":RenderingServer.get_frame_setup_time_cpu(),"engine_cap":Engine.max_fps,"reflection_updates":game.get_node("LakeReflection").updates}
		results.append(row);print("ICEFIELD_PERF ",JSON.stringify(row))
		if slow>0 or row.p95_ms>25.0:failures.append(view[3])
	var output:=preload("res://tests/test_support.gd").output_dir();var file:=FileAccess.open(output+"/performance.json",FileAccess.WRITE);file.store_string(JSON.stringify({"output_pixels":[root.size.x,root.size.y],"scale_3d":root.scaling_3d_scale,"draw_policy":"one_forced_draw_per_process_frame","samples":results,"failures":failures},"\t"));file=null
	print("ICEFIELD_PERFORMANCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
