extends SceneTree
## Same moving subject/camera, old/new comparable wall-clock frames and refresh cadence.
const L=preload("res://scripts/building/layout.gd")
const W=preload("res://scripts/building/wall_mount.gd")
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func quantile(values: Array,fraction: float) -> float:
	values.sort();return values[mini(values.size()-1,int(values.size()*fraction))] if not values.is_empty() else 0.
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("镜面性能测试","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;city.set_process(false);city.bunny.set_physics_process(false);session.active=false
	var editor=city.build_mode;editor.open_editor();editor.set_process(false);editor.ui.hide();editor.grid.hide()
	var data:=L.add(L.empty(),{"type":"floor","a":[70.,1.],"b":[82.,13.]});data=L.add(data,{"type":"wall","a":[70.,1.],"b":[82.,1.]})
	for x in [73.4,74.6]:data=L.add(data,W.attach(data,{"type":"object","kind":"wall_mirror","position":[x,1.],"yaw":0.},Vector2(x,1),Vector2(74,7)))
	if not editor.commit(data):quit(1);return
	editor.set_roof_visible(true);city.bunny.show();city.bunny.position=Vector3(74,.2,4)
	var manager: Node=city.get_node("MirrorReflections");var output:=preload("res://tests/test_support.gd").output_dir()
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);OS.low_processor_usage_mode=false
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await process_frame;RenderingServer.force_draw()
	# Explicit draws keep macOS background tests alive. Disable automatic draws so
	# each measured iteration still contains exactly one complete rendered frame.
	RenderingServer.render_loop_enabled=false
	var rid:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
	for condition in ["disabled","near_static_camera","near_moving_camera","far_moving_camera","disabled_repeat"]:
		var disabled: bool=condition.begins_with("disabled");manager.set_process(not disabled)
		if disabled:
			for slot in manager.slots:slot.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		city.camera.position=Vector3(74,2.5,27 if condition=="far_moving_camera" else 7);city.camera.look_at(Vector3(74,2.4,1.24))
		await create_timer(.8).timeout
		var frames: Array=[];var cpu: Array=[];var gpu: Array=[];var changes: Array=[];var samples:=0;var before: int=manager.render_count;var last:=Time.get_ticks_usec();var start:=last
		while Time.get_ticks_usec()-start<2200000:
			var t: float=(Time.get_ticks_usec()-start)/1000000.;city.bunny.position.x=74+sin(t*4.)*.65;city.bunny.reset_physics_interpolation()
			if condition.ends_with("moving_camera"):city.camera.position.x=74+sin(t*2.);city.camera.look_at(Vector3(74,2.4,1.24))
			var previous: int=manager.render_count
			await process_frame;RenderingServer.force_draw()
			var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now;samples+=1;changes.append(manager.render_count-previous)
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		var pixels:=0
		for slot in manager.slots:pixels+=slot.viewport.size.x*slot.viewport.size.y
		var result:={"condition":condition,"frames":samples,"frame_median_ms":quantile(frames,.5),"frame_p95_ms":quantile(frames,.95),"main_render_cpu_median_ms":quantile(cpu,.5),"main_render_gpu_median_ms":quantile(gpu,.5),"active_mirrors":manager.active_count,"reflection_draws":manager.render_count-before,"draws_per_main_frame":float(manager.render_count-before)/samples,"target_pixels":pixels};rows.append(result);print("MIRROR_PERFORMANCE ",JSON.stringify(result))
		if not disabled:root.get_texture().get_image().save_png(output+"/"+condition+".png")
	RenderingServer.render_loop_enabled=true
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"window":str(root.size),"scale":root.scaling_3d_scale,"metric":"Uncapped vsync-off, one explicit draw per process iteration with automatic render loop disabled for macOS background reliability. Complete frame wall-clock; main viewport GPU timing excludes separate reflection targets, zero means unavailable. Two visible mirrors, moving subject in every condition.","rows":rows}
	FileAccess.open(output.get_base_dir()+"/mirror-performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("MIRROR_PERFORMANCE_RESULT PASS conditions=",rows.size());quit()
