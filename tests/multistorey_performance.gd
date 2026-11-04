extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const T=preload("res://scripts/building/templates.gd")
var city: Node3D
var session: Node
var results: Array=[]
func _initialize() -> void:call_deferred("run")
func percentile(values: Array,at: float) -> float:
	values.sort();return values[mini(values.size()-1,int(values.size()*at))] if not values.is_empty() else 0.
func run() -> void:
	var old:=T.cottage();var private:="res://.qa-artifacts/multistorey-private-source.json"
	if FileAccess.file_exists(private):old=L.normalize(JSON.parse_string(FileAccess.get_file_as_string(private)))
	var merged:=preload("res://scripts/building/showcase.gd").ensure(old);var checked:=L.validate(merged)
	if not checked.ok:print("FAIL ",checked.message);quit(1);return
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("多层性能兔","bunny","bow_rose");session.state().build_layout=checked.layout;session.state().player_position=[143.5,.2,7.4];session.state().time=.78*3600.
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;session.active=false;city.bunny.set_physics_process(false)
	while city.build_mode.ui.studio.busy or not city.build_mode.ui.studio.pending.is_empty():await process_frame
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.5).timeout
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);OS.low_processor_usage_mode=false
	var room: Node3D=city.build_mode.room;var rid:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
	for level in ([] if OS.get_cmdline_user_args().has("--preview-only") else [0,1]):
		for mode_ in [0,1,2]:
			session.settings.interior_view_mode=mode_;var center:=Vector3(143.5,.2,7.4) if level==0 else Vector3(141.65,4.9,11.5)
			city.bunny.position=center;city.camera_focus=center+Vector3.UP*1.35;city.distance_=7.;city.pitch=.28;city.yaw=1.1;city.camera.position=city.camera_focus+Vector3(4,3,5);await create_timer(.5).timeout
			var frames: Array=[];var draws: Array=[];var shadows: Array=[];var cpu: Array=[];var updates: int=room.material_updates;var start:=Time.get_ticks_usec();var last:=start;var window:=root.size
			while Time.get_ticks_usec()-start<2000000:
				var t: float=(Time.get_ticks_usec()-start)/1000000.;city.yaw=1.1+sin(t*1.9)*1.05;city.bunny.position=center+Vector3(sin(t)*.15,0,cos(t*.8)*.12);city.bunny.reset_physics_interpolation()
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now;draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));shadows.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
			var record:={"storey":level+1,"camera_mode":mode_,"frame_median_ms":percentile(frames,.5),"frame_p95_ms":percentile(frames,.95),"draws_median":percentile(draws,.5),"shadow_draws_median":percentile(shadows,.5),"render_submission_median_ms":percentile(cpu,.5),"frames":frames.size(),"window":str(root.size),"stable_window":root.size==window,"scale":root.scaling_3d_scale,"material_writes":room.material_updates-updates};results.append(record);print("MULTISTOREY_PERFORMANCE ",JSON.stringify(record))
	# Measure hot preview updates with the current local save and two extra empty slabs.
	var editor: Node=city.build_mode;city.bunny.position=Vector3(139,.2,25);editor.open_editor();editor.set_process(false);editor.ui.hide();var data: Dictionary=editor.layout
	for level in [0,1]:data=L.add(data,{"type":"floor","a":[105.,-6.],"b":[129.,26.],"storey":level})
	if not editor.commit(data):print("FAIL Preview performance fixture");quit(1);return
	var previews: Array=[]
	for form in ["straight","l","u"]:
		editor.choose_tool("stairs:"+form);var timings: Array=[]
		for i in range(24):
			var start:=Time.get_ticks_usec();editor.update_ghost(Vector2(113.+(i%8)*.5,9.+floori(i/8.)*.5));timings.append((Time.get_ticks_usec()-start)/1000.)
		var first: float=timings.pop_front();previews.append({"form":form,"first_ms":first,"hot_median_ms":percentile(timings,.5),"hot_p95_ms":percentile(timings,.95)})
	var output:=preload("res://tests/test_support.gd").output_dir().get_base_dir()+"/performance.json";FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),"usage":L.usage(checked.layout),"msaa":root.msaa_3d,"rows":results,"preview":previews,"metric":"Uncapped, vsync-off complete frames; short orbit in two rooms. Submission CPU is not GPU time. Other local Godot processes may affect wall time; no steady-60FPS claim."},"  "))
	for audio in city.find_children("*","AudioStreamPlayer",true,false)+city.find_children("*","AudioStreamPlayer3D",true,false):audio.stop()
	await create_timer(.15).timeout;city.free();await create_timer(.15).timeout;session.free();print("MULTISTOREY_PERFORMANCE_RESULT PASS cases=",results.size()," previews=3");call_deferred("finish")
func finish() -> void:quit()
