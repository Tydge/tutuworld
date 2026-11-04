extends SceneTree
## Uncapped, same-time camera/walking path; diagnostic interventions are restored.
const L=preload("res://scripts/building/layout.gd")
const View=preload("res://scripts/city/interior_view.gd")
var city: Node3D
var session: Node
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func quantile(values: Array,fraction: float) -> float:
	values.sort();return values[mini(values.size()-1,int(values.size()*fraction))] if not values.is_empty() else 0.
func fixture() -> Dictionary:
	var data:=L.add(L.empty(),{"type":"floor","a":[73.,5.],"b":[85.,15.]})
	for pair in [[[73.,5.],[85.,5.]],[[85.,5.],[85.,15.]],[[85.,15.],[73.,15.]],[[73.,15.],[73.,5.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
	data=L.add(data,{"type":"roof","a":[73.,5.],"b":[85.,15.]});var roof: String=data.elements[-1].id
	for p in [[76.,8.],[79.,8.],[82.,12.]]:data=L.add(data,{"type":"object","kind":"pendant","position":p,"yaw":0.,"support":roof})
	for p in [[74.1,6.1],[83.9,13.9]]:data=L.add(data,{"type":"object","kind":"floor_lamp","position":p,"yaw":0.})
	data=L.add(data,{"type":"object","kind":"hearth","position":[79.,6.],"yaw":0.})
	return data
func run() -> void:
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(.5).timeout
	var output:=preload("res://tests/test_support.gd").output_dir();var data:=fixture();var private:=OS.get_cmdline_user_args().has("--private-repro")
	if private:data=JSON.parse_string(FileAccess.get_file_as_string("res://.qa-artifacts/indoor-repro-layout.json"))
	var validated:=L.validate(data)
	if not validated.ok:print("FAIL invalid performance fixture ",validated);quit(1);return
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("室内性能兔","bunny","bow_rose");session.settings.interior_view_mode=2;session.state().build_layout=validated.layout;session.state().time=.78*3600.
	var center:=Vector3(92.,.2,19.8) if private else Vector3(79.,.2,10.);session.state().player_position=[center.x,center.y,center.z]
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;session.active=false;city.bunny.set_physics_process(false)
	var studio: Node=city.build_mode.ui.studio
	while studio.busy or not studio.pending.is_empty():await process_frame
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.5).timeout
	city.distance_=7.;city.pitch=.22;city.yaw=1.2
	if private:
		var extra:=Node3D.new();extra.position=Vector3(94.7,.18,21.5);city.scenery.add_child(extra);preload("res://scripts/building/module_factory.gd").builder(extra).build_item(extra,"floor_lamp")
	var room: Node3D=city.build_mode.room;var lamps: Array=[];var local_shadow_count:=0
	for light in city.scenery.find_children("*","Light3D",true,false):
		lamps.append({"node":light,"shadow":light.shadow_enabled,"visible":light.visible})
		if light.shadow_enabled and not light is DirectionalLight3D:local_shadow_count+=1
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);OS.low_processor_usage_mode=false
	var scale_: float=root.scaling_3d_scale;var rid:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
	var msaa_: int=root.msaa_3d;var ssao_: bool=city.atmosphere.ssao_enabled;var sun_distance: float=city.sun.directional_shadow_max_distance
	# This is CPU work only, independently measured from the rendering queue.
	var start:=Time.get_ticks_usec()
	for i in range(1000):View.targets(room.sections,center+Vector3(sin(i*.07)*6.,3.,cos(i*.07)*6.),center)
	var scan_usec: float=(Time.get_ticks_usec()-start)/1000.
	var detail:=OS.get_cmdline_user_args().has("--lighting-detail")
	for mode_ in ([2,1] if detail else [2,0,1]):
		for intervention in (["normal","two_x_msaa","near_sun_shadows","no_sun_shadows","no_ssao","normal_repeat"] if detail else ["normal","no_local_shadows","no_local_lights","half_pixels","normal_repeat"]):
			for entry in lamps:
				entry.node.shadow_enabled=entry.shadow and (intervention!="no_local_shadows" or entry.node is DirectionalLight3D)
				entry.node.visible=entry.visible and (intervention!="no_local_lights" or entry.node is DirectionalLight3D)
			root.scaling_3d_scale=scale_*.70710678 if intervention=="half_pixels" else scale_;session.settings.interior_view_mode=mode_
			root.msaa_3d=Viewport.MSAA_2X if intervention=="two_x_msaa" else msaa_;city.sun.directional_shadow_max_distance=35. if intervention=="near_sun_shadows" else sun_distance;city.sun.shadow_enabled=intervention!="no_sun_shadows";city.atmosphere.ssao_enabled=ssao_ and intervention!="no_ssao"
			city.bunny.position=center;city.bunny.reset_physics_interpolation();city.yaw=1.2;city.camera_focus=center+Vector3.UP*1.35;city.camera.position=city.camera_focus+Vector3(5,3,4)
			await create_timer(.5).timeout
			var frames: Array=[];var cpu: Array=[];var gpu: Array=[];var physics: Array=[];var draws: Array=[];var visible_draws: Array=[];var shadow_draws: Array=[];var process_ms: Array=[];var shader_writes: int=room.get("material_updates") if "material_updates" in room else -1
			var compiles: Array=[]
			for i in range(34,39):compiles.append(Performance.get_monitor(i))
			var window_start:=root.size;var last:=Time.get_ticks_usec();start=last
			while Time.get_ticks_usec()-start<2500000:
				var t: float=(Time.get_ticks_usec()-start)/1000000.;city.yaw=1.2+sin(t*1.9)*1.15;city.bunny.position=center+Vector3(sin(t*.9)*.50,0,cos(t*1.3)*.35);city.bunny.reset_physics_interpolation()
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid));physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.);process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.);draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));visible_draws.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME));shadow_draws.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
			var compile_delta: Array=[]
			for i in range(34,39):compile_delta.append(Performance.get_monitor(i)-compiles[i-34])
			var row:={"mode":View.NAMES[mode_],"condition":intervention,"frames":frames.size(),"frame_median_ms":quantile(frames,.5),"frame_p95_ms":quantile(frames,.95),"render_cpu_median_ms":quantile(cpu,.5),"render_gpu_median_ms":quantile(gpu,.5),"process_median_ms":quantile(process_ms,.5),"physics_median_ms":quantile(physics,.5),"draws_median":quantile(draws,.5),"visible_draws_median":quantile(visible_draws,.5),"shadow_draws_median":quantile(shadow_draws,.5),"pipeline_compilation_delta":compile_delta,"material_writes":int(room.get("material_updates"))-shader_writes if shader_writes>=0 else -1};rows.append(row);print("INDOOR_PERFORMANCE ",JSON.stringify(row))
			row.window=str(root.size);row.stable_window=root.size==window_start;row.scale=root.scaling_3d_scale;row.msaa=root.msaa_3d
			if intervention=="normal":root.get_texture().get_image().save_png(output+"/mode-"+str(mode_)+".png")
	var result:={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"window":str(root.size),"scale":scale_,"msaa":root.msaa_3d,"layout_elements":validated.layout.elements.size(),"private_repro":private,"local_shadow_lights":local_shadow_count,"occlusion_cpu_usec_per_call":scan_usec,"metric":"Wall-clock complete frames with uncapped/vsync-off; render CPU is a separate submission metric. Zero GPU timing means unavailable, not zero cost. One short path; other local Godot processes may affect wall time.","rows":rows}
	FileAccess.open(output.get_base_dir()+"/indoor-performance.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("INDOOR_PERFORMANCE_RESULT PASS conditions=",rows.size()," occlusion_cpu_usec_per_call=",scan_usec);quit()
