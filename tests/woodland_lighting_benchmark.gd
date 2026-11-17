extends SceneTree
const L=preload("res://scripts/valley/valley_layout.gd")
var game: Node3D
var session: Node
func _initialize() -> void:call_deferred("run")
func point(x: float,z: float) -> Vector3:return Vector3(x,L.walk_height(x,z)+.035,z)
func run() -> void:
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("光影性能检查","panda","scarf_green");session.state().map_id="valley";session.state().player_position=L.arrival("valley");session.state().time=1800
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);current_scene=game
	while game.preparing or game.camera==null or not game.navigation.ready_for_paths:await process_frame
	session.active=false;game.bunny.can_move=false;game.set_process(false);game.hud.hide();Engine.max_fps=0
	var out:=preload("res://tests/test_support.gd").output_dir();var results: Array=[]
	var views: Array=[
		["forest-noon",point(-35,-28),Vector3(6,5,12),Vector3(-5,3,-12),.5],
		["forest-morning-safe",point(44,-35),Vector3(-9,10,14),Vector3(-7,3,-15),.30],
		["overlook",point(-72,L.ascent_path_z(-72)),Vector3(-9,10,-9),Vector3(35,-12,6),.5],
		["bridge",point(-5,10),Vector3(-12,7,15),Vector3(5,2,-4),.42],
		["cottage-night",point(24,-61),Vector3(10,7,16),Vector3(0,3,-9),.92]]
	for view in views:
		game.bunny.position=view[1];game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();game.camera.position=view[1]+view[2];game.camera.look_at(view[1]+view[3]);game.update_lighting(view[4])
		await create_timer(1.).timeout
		var times: Array[float]=[];var cpu: Array[float]=[];var setup: Array[float]=[];var draws:=0;var triangles:=0
		var started:=Time.get_ticks_usec();var last:=started
		while Time.get_ticks_usec()-started<2000000:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();times.append((now-last)/1000.);last=now
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.);setup.append(RenderingServer.get_frame_setup_time_cpu())
			draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)));triangles=maxi(triangles,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		times.sort();cpu.sort();setup.sort()
		var row:={"view":view[0],"frames":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"max_ms":times[-1],"cpu_median_ms":cpu[cpu.size()/2],"setup_median_ms":setup[setup.size()/2],"draw_calls":draws,"primitives":triangles,"vram_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.}
		results.append(row);print("WOODLAND_LIGHTING_BENCH ",JSON.stringify(row))
		root.get_texture().get_image().save_png(out+"/"+view[0]+".png")
	var report:={"output":str(root.size),"scale":root.scaling_3d_scale,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"uncapped":true,"views":results}
	var file:=FileAccess.open(out+"/benchmark.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	current_scene=null;game.queue_free();await process_frame;await process_frame
	print("WOODLAND_LIGHTING_BENCHMARK_RESULT PASS");quit()
