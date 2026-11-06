extends SceneTree
## Fixed-camera wall fades isolate visibility changes from camera/texture resizing.
const L=preload("res://scripts/building/layout.gd")
const W=preload("res://scripts/building/wall_mount.gd")
const View=preload("res://scripts/city/interior_view.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var session: Node
var room: Node3D
var manager: Node
var output: String
var rows: Array=[]
var trace: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func quantile(values: Array,fraction: float) -> float:
	var sorted:=values.duplicate();sorted.sort();return sorted[mini(sorted.size()-1,int(sorted.size()*fraction))] if not sorted.is_empty() else 0.
func fixture() -> Dictionary:
	var data:=L.add(L.empty(),{"type":"floor","a":[70.,1.],"b":[82.,18.]})
	for pair in [[[70.,1.],[82.,1.]],[[82.,1.],[82.,13.]],[[82.,13.],[70.,13.]],[[70.,13.],[70.,1.]]]:
		data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1],"painted":true,"color":"d83868","style":"plaster"})
	var front: Dictionary=data.elements.filter(func(row):return row.type=="wall" and row.a[1]==13. and row.b[1]==13.)[0]
	data=L.add(data,{"type":"window","wall":front.id,"offset":3.})
	data=L.add(data,W.attach(data,{"type":"object","kind":"wall_mirror","position":[76.,1.],"yaw":0.},Vector2(76,1),Vector2(76,7),1.35))
	return data
func draw(blocked: bool) -> Dictionary:
	await process_frame
	var started:=Time.get_ticks_usec()
	room.refresh_view(city.camera.global_position,Vector3(76,.2,16 if blocked else 7))
	var view_usec:=Time.get_ticks_usec()-started
	# Diagnostic A/B: reproduce the old native descriptor churn on identical code.
	if OS.get_cmdline_user_args().has("--rebind-mask"):
		for section in room.sections:
			if section.alpha>0. and section.alpha<1.:
				for material in section.materials:material.set_shader_parameter("building_cut_mask",room.mask_texture)
	started=Time.get_ticks_usec()
	if is_instance_valid(manager):manager._process(1./120.)
	var mirror_usec:=Time.get_ticks_usec()-started
	RenderingServer.force_draw()
	return {"view_us":view_usec,"mirror_us":mirror_usec}
func reflection() -> Image:
	var slot: Dictionary=manager.slots.filter(func(entry):return not entry.faces.is_empty())[0]
	return slot.viewport.get_texture().get_image()
func compare(a: Image,b: Image) -> Dictionary:
	if a.get_size()!=b.get_size():return {"mean":1.,"p99":1.}
	var errors: Array=[];var total:=0.
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y);var error:=maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)));errors.append(error);total+=error
	return {"mean":total/maxi(1,errors.size()),"p99":quantile(errors,.99)}
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("避挡诊断兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;session.active=false;city.set_process(false);city.bunny.set_physics_process(false);city.bunny.hide();city.hud.hide()
	var editor: Node=city.build_mode;editor.open_editor();editor.set_process(false);editor.ui.hide();editor.grid.hide()
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await process_frame
	check(editor.commit(fixture()),"Wall fade fixture with an actual mirror commits")
	room=editor.room;room.set_process(false);room.set_editor_view(false,false);session.settings.interior_view_mode=View.FULL
	for interior in city.interiors:interior.set_process(false)
	city.camera.position=Vector3(76,2.5,10);city.camera.look_at(Vector3(76,2.43,1.245));city.update_lighting(.4)
	manager=city.get_node("MirrorReflections");manager.set_process(false)
	await physics_frame;await physics_frame
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);OS.low_processor_usage_mode=false;RenderingServer.render_loop_enabled=false
	for i in range(80):await draw(false)
	var reference:=reflection();reference.save_png(output+"/reflection-full.png")
	session.settings.interior_view_mode=View.OCCLUSION
	await draw(true)
	check(room.sections.any(func(section):return section.alpha>.002 and section.alpha<.999),"Probe includes a partially faded wall")
	var partial:=compare(reference,reflection())
	check(partial.mean<.005 and partial.p99<.02,"Reflected wall also stays opaque throughout the dither transition")
	for i in range(80):await draw(true)
	var faded:=reflection();faded.save_png(output+"/reflection-faded.png")
	var difference:=compare(reference,faded);print("WALL_OCCLUSION_IMAGE ",JSON.stringify(difference))
	check(room.sections.any(func(section):return section.alpha<.002),"Blocking wall fully fades in the main view")
	check(difference.mean<.005 and difference.p99<.02,"Reflected wall retains full-view pixels when the main view hides it")
	check((city.camera.cull_mask & View.REFLECTION_LAYER)==0,"Main camera excludes the reflection-only layer")
	check(not root.use_occlusion_culling,"Main view cannot be incorrectly culled by intact reflection walls")
	var hidden_glass: Array=[]
	for section in room.sections:
		if section.alpha<.002:
			for pane in section.glass:hidden_glass.append(pane)
	check(not hidden_glass.is_empty() and hidden_glass.all(func(pane):return pane.visible and pane.layers==View.REFLECTION_LAYER),"Faded window glass remains visible only to reflections")
	var solid_occluders: Array=[]
	for entry in manager.occluders.boxes:
		if entry.wall:solid_occluders.append(entry.occluder.visible)
	check(solid_occluders.size()>=4 and solid_occluders.all(func(shown):return shown),"Real walls keep stable native reflection occluders while fading")
	if OS.get_cmdline_user_args().has("--no-mirror"):manager.free();manager=null
	# Separate sustained frame costs from the frame where a mesh/occluder toggles.
	var frames: Dictionary={"stable":[],"fade":[],"toggle":[]};var view_cost: Array=[];var mirror_cost: Array=[];var compiles: Array=[]
	for i in range(34,39):compiles.append(Performance.get_monitor(i))
	var occluder_toggles:=0
	var last:=Time.get_ticks_usec()
	for i in range(960):
		var before: Array=[]
		for section in room.sections:before.append([section.alpha,section.visuals[0].visible,section.visuals[0].layers])
		var occluder_states: Array=[]
		if is_instance_valid(manager):
			for entry in manager.occluders.boxes:occluder_states.append(entry.occluder.visible)
		var costs:=await draw((i/80)%2==0);var now:=Time.get_ticks_usec();var elapsed: float=(now-last)/1000.;last=now
		if is_instance_valid(manager):
			for j in range(occluder_states.size()):
				if manager.occluders.boxes[j].occluder.visible!=occluder_states[j]:occluder_toggles+=1
		var kind:="stable"
		for j in range(room.sections.size()):
			var section: Dictionary=room.sections[j]
			if section.visuals[0].visible!=before[j][1] or section.visuals[0].layers!=before[j][2]:kind="toggle";break
			if not is_equal_approx(section.alpha,before[j][0]):kind="fade"
		frames[kind].append(elapsed);view_cost.append(costs.view_us);mirror_cost.append(costs.mirror_us)
		trace.append([i,elapsed,kind,costs.view_us,costs.mirror_us])
	for kind in frames:
		var values: Array=frames[kind]
		rows.append({"kind":kind,"frames":values.size(),"median_ms":quantile(values,.5),"p95_ms":quantile(values,.95),"p99_ms":quantile(values,.99),"max_ms":values.max() if not values.is_empty() else 0.,"over_16_7_ms":values.filter(func(v):return v>16.7).size()})
	check(occluder_toggles==0,"Repeated free-camera fades never rebuild native wall occluders")
	if OS.get_cmdline_user_args().has("--benchmark"):
		for row in rows:check(row.frames>0 and row.p99_ms<16.7,"Wall transition P99 stays within 16.7ms: "+row.kind)
	var compile_delta: Array=[]
	for i in range(34,39):compile_delta.append(Performance.get_monitor(i)-compiles[i-34])
	var report:={"args":OS.get_cmdline_user_args(),"rows":rows,"view_us_p99":quantile(view_cost,.99),"mirror_us_p99":quantile(mirror_cost,.99),"pipeline_compilation_delta":compile_delta,"image_difference":difference,"occluder_toggles":occluder_toggles,"trace":trace,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"window":str(root.size),"scale":root.scaling_3d_scale}
	print("WALL_OCCLUSION_PERFORMANCE ",JSON.stringify(rows)," view_us_p99=",report.view_us_p99," mirror_us_p99=",report.mirror_us_p99," pipeline_delta=",compile_delta)
	FileAccess.open(output.get_base_dir()+"/wall-occlusion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await verify_openings()
	await verify_modes()
	RenderingServer.render_loop_enabled=true;city.free();session.free();await process_frame
	print("WALL_OCCLUSION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)

func verify_modes() -> void:
	# Look straight at the blocking wall: main-view pixels must really disappear.
	city.camera.position=Vector3(76,2.5,10)
	city.camera.look_at(Vector3(76,2.43,13))
	session.settings.interior_view_mode=View.FULL
	for i in range(40):await draw(false)
	var full:=root.get_texture().get_image();full.save_png(output+"/main-full.png")
	session.settings.interior_view_mode=View.OCCLUSION
	for i in range(60):await draw(true)
	var hidden:=root.get_texture().get_image();hidden.save_png(output+"/main-faded.png")
	var area:=Rect2i(full.get_size()/2-Vector2i(24,24),Vector2i(48,48))
	check(compare(full.get_region(area),hidden.get_region(area)).mean>.1,"Main camera sees through the wall while reflection geometry stays intact")
	# Mode switches restore camera layers and preserve the existing editor cutaway.
	for mode_ in [View.FULL,View.AUTO]:
		session.settings.interior_view_mode=mode_
		for i in range(4):await draw(false)
		check(room.sections.all(func(section):return section.visuals.all(func(visual):return visual.layers==visual.get_meta("view_layers",visual.layers))),"Switching mode restores original geometry layers: "+View.NAMES[mode_])
	room.set_editor_view(true,false,0,false)
	for i in range(4):await draw(false)
	check(room.sections.all(func(section):return section.materials.all(func(material):return not material.get_shader_parameter("camera_occlusion"))),"Building cutaway does not inherit the free-camera shader override")
	room.set_editor_view(true,true,0,false)
	for i in range(4):await draw(false)
	check(room.sections.all(func(section):return section.visuals.all(func(visual):return visual.visible and visual.layers==visual.get_meta("view_layers",visual.layers))),"Complete-wall editor view restores all original wall instances")
	# The prebuilt houses use their own fade loop; exercise it on the actual home.
	var home: Node3D=city.home
	city.bunny.position=home.to_global(Vector3(0,.2,0));city.bunny.reset_physics_interpolation()
	city.camera.position=home.to_global(Vector3(0,3,12));city.camera.look_at(city.bunny.position+Vector3.UP)
	session.settings.interior_view_mode=View.OCCLUSION
	for i in range(12):home._process(.05)
	var faded_sections: Array=home.sections.filter(func(section):return section.alpha<.002)
	check(not faded_sections.is_empty() and faded_sections.all(func(section):return section.visuals.all(func(visual):return visual.visible and visual.layers==View.REFLECTION_LAYER)),"Actual prebuilt home also preserves faded walls and roof for reflection cameras")
	session.settings.interior_view_mode=View.FULL
	for i in range(12):home._process(.05)
	check(home.sections.all(func(section):return section.visuals.all(func(visual):return visual.visible and visual.layers==visual.get_meta("view_layers"))),"Prebuilt home restores full geometry when leaving free occlusion")
	session.settings.interior_view_mode=View.AUTO
	for i in range(12):home._process(.05)
	check(home.sections.any(func(section):return section.roof and section.visuals.any(func(visual):return not visual.visible)),"Prebuilt automatic view still hides its roof")
	if is_instance_valid(manager):
		check(city.build_mode.commit(L.empty()),"Removing the entire mirror building commits")
		manager._process(.016);RenderingServer.force_draw()
		check(manager.active_count==0 and manager.occluders.boxes.is_empty(),"Removing the last mirror building clears reflection occluders and handles the missing room")

func opening_frames(eye: Vector3,actor: Vector3,count: int=45,min_seconds: float=.40) -> void:
	city.camera.position=eye;city.camera.look_at(actor+Vector3.UP*1.35)
	# Recovery uses a real .18s hold plus a 1/7s fade. At uncapped FPS,
	# 45 rendered frames alone can finish before that time has elapsed.
	var until:=Time.get_ticks_usec()+int(min_seconds*1000000.)
	var frames:=0
	while frames<count or Time.get_ticks_usec()<until:
		frames+=1
		await process_frame
		room.refresh_view(eye,actor)
		if is_instance_valid(manager):manager._process(.016)
		RenderingServer.force_draw()
func verify_openings() -> void:
	var window: Dictionary=room.render_cache.values().filter(func(entry):return entry.row.type=="window")[0]
	var wall: Dictionary=room.render_cache[window.row.wall]
	var wall_section: Dictionary=room.sections.filter(func(section):return section.node==wall.node)[0]
	var face: String=View.face(wall_section)
	var front: Array=room.sections.filter(func(section):return View.face(section)==face)
	var eye:=Vector3(79,4,16);var actor:=Vector3(79,.2,10)
	session.settings.interior_view_mode=View.FULL
	await opening_frames(eye,actor,4,0.);await physics_frame;await physics_frame
	var clear:=true
	for point in View.probes(eye,actor):
		var ray:=PhysicsRayQueryParameters3D.create(eye,point,4)
		if not city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():clear=false
	check(clear,"All nine actual sightlines pass through the real window opening without hitting wall collision")
	session.settings.interior_view_mode=View.OCCLUSION
	await opening_frames(eye,actor)
	check(front.size()>=2 and front.all(func(section):return section.target==0. and section.alpha<.002),"Seeing the actor through a real window hides the entire wall and window frame")
	check(room.sections.any(func(section):return section.node!=wall.node and section.node.get_meta("module_type","")=="wall" and section.alpha>.99),"Window sightlines retain unrelated walls")
	city.bunny.position=actor;city.bunny.reset_physics_interpolation();city.bunny.show()
	await opening_frames(eye,actor,1,0.);root.get_texture().get_image().save_png(output+"/window-wall-faded.png");city.bunny.hide()
	await opening_frames(Vector3(79,3,8),actor)
	check(front.all(func(section):return section.alpha>.99),"The window wall restores when camera and actor are on the same side")
	# Use an actual open door, including its rotated collision leaf.
	var data:=L.add(city.build_mode.layout,{"type":"door","wall":wall.row.id,"offset":9.,"default_open":true})
	check(city.build_mode.commit(data),"Open-door sightline fixture commits")
	room=city.build_mode.room;room.set_process(false);room.set_editor_view(false,false)
	var door: Dictionary=room.render_cache.values().filter(func(entry):return entry.row.type=="door")[0]
	var door_face: String=View.face(room.sections.filter(func(section):return section.node==door.node)[0])
	var door_sections: Array=room.sections.filter(func(section):return View.face(section)==door_face)
	await physics_frame;await physics_frame
	check(absf(door.node.hinge.rotation.y)>1.,"Door fixture is physically open")
	await opening_frames(Vector3(73,2,16),Vector3(73,.2,10))
	check(door_sections.size()>=3 and door_sections.all(func(section):return section.target==0. and section.alpha<.002),"Seeing the actor through an open doorway hides its wall, frame and door leaf together")
