extends SceneTree
var session: Node
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var retina:=OS.get_cmdline_user_args().has("--retina-test")
	root.size=Vector2i(3024,1964) if retina else Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	while game.preparing: await process_frame
	session.active=false;game.hud.toast.hide()
	var method: String=RenderingServer.get_current_rendering_method()
	var quality:=OS.get_cmdline_user_args().has("--quality-test")
	print("RENDER_DEVICE ",RenderingServer.get_video_adapter_name()," method=",method," driver=",RenderingServer.get_current_rendering_driver_name()," resolution=",root.size," scale=",root.scaling_3d_scale," upscale=",root.scaling_3d_mode)
	if quality:
		game.atmosphere.ssao_enabled=true;game.atmosphere.ssao_radius=.65;game.atmosphere.ssao_intensity=.85
		game.atmosphere.ssao_power=1.15;game.atmosphere.ssao_detail=.6;game.atmosphere.ssao_light_affect=.12
		game.sun.light_angular_distance=.35
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for row in [["park_day",.5,Vector3(0,.2,9)],["park_night",.92,Vector3(0,.2,9)],["home_day",.5,Vector3(-34,.25,-1.5)],["home_night",.92,Vector3(-34,.25,-1.5)]]:
		session.state().time=row[1]*3600;game.update_lighting();game.bunny.position=row[2];game.bunny.reset_physics_interpolation();game.yaw=.25;game.pitch=.46;game.distance_=13.5
		await create_timer(.8).timeout
		var times: Array[float]=[];var gpu: Array[float]=[];var cpu: Array[float]=[]
		var start:=Time.get_ticks_usec();var last:=start
		while Time.get_ticks_usec()-start<4000000:
			game.yaw=(Time.get_ticks_usec()-start)/4000000.0*TAU
			await process_frame
			var now:=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		times.sort();gpu.sort();cpu.sort()
		print("RENDER_PROBE ",method," quality=",quality," ",row[0]," frame95=",times[int(times.size()*.95)]," max=",times[-1]," gpu95=",gpu[int(gpu.size()*.95)]," render_cpu95=",cpu[int(cpu.size()*.95)]," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		game.yaw=.25;game.hud.root_ui.hide();await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/渲染对比-"+method+("-AO" if quality else "")+"-"+row[0]+".png")
		game.hud.root_ui.show()
	print("RENDER_PROBE_COMPLETE");quit()
