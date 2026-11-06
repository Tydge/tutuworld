extends SceneTree
## Twenty actual catalog mirrors: all visible, different planes, a furnished room,
## and pixel comparisons against independent per-mirror captures.
const L=preload("res://scripts/building/layout.gd")
const W=preload("res://scripts/building/wall_mount.gd")
const G=preload("res://scripts/geometry.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
var manager: Node
var rows: Array=[]
var output: String
var benchmark:=false
var only_layout:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func quantile(values: Array,fraction: float) -> float:
	values.sort();return values[mini(values.size()-1,int(values.size()*fraction))] if not values.is_empty() else 0.
func add_mirror(data: Dictionary,p: Vector2,viewer: Vector2,height_: float=1.35) -> Dictionary:
	return L.add(data,W.attach(data,{"type":"object","kind":"wall_mirror","position":[p.x,p.y],"yaw":0.},p,viewer,height_))
func fixture(kind: String) -> Dictionary:
	var data:=L.add(L.empty(),{"type":"floor","a":[70.,1.],"b":[115.,25.]})
	if kind=="independent":
		for i in range(20):
			var x:=72.+i*2.1;var z:=2.+i*.5
			data=L.add(data,{"type":"wall","a":[floorf(x)-1.,z],"b":[floorf(x)+2.,z]})
			data=add_mirror(data,Vector2(x,z),Vector2(92,45))
	elif kind=="room":
		for pair in [[[76.,4.],[94.,4.]],[[94.,4.],[94.,22.]],[[94.,22.],[76.,22.]],[[76.,22.],[76.,4.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
		for i in range(5):
			var offset:=3.+i*3.
			for p in [Vector2(76+offset,4),Vector2(94,4+offset),Vector2(94-offset,22),Vector2(76,22-offset)]:data=add_mirror(data,p,Vector2(85,13))
	else:
		data=L.add(data,{"type":"wall","a":[75.,4.],"b":[95.,4.]})
		for i in range(10):
			for h in [.25,2.35]:data=add_mirror(data,Vector2(78.9+i*1.35,4),Vector2(85,18),h)
	# Real furniture and lamps, in addition to the full town, not empty quads.
	for i in range(12):
		data=L.add(data,{"type":"object","kind":"chair","position":[79.+(i%6)*2.4,(16.+floori(i/6.)*5.) if kind=="independent" else (9.+floori(i/6.)*8.)],"yaw":float((i%4)*90)})
	for p in ([[77.5,14.],[110.,14.],[77.5,23.],[110.,23.]] if kind=="independent" else [[77.5,7.],[92.5,7.],[77.5,19.],[92.5,19.]]):data=L.add(data,{"type":"object","kind":"floor_lamp","position":p,"yaw":0.})
	return data
func draw() -> void:
	await process_frame;RenderingServer.force_draw()
func installed_faces() -> Array:
	var result: Array=[]
	for entry in manager.mirrors:
		var face: MeshInstance3D=entry.face.get_ref()
		if is_instance_valid(face):result.append(face)
	return result
func ready_faces() -> int:
	var count:=0
	for face in installed_faces():
		if face.material_override.get_shader_parameter("reflection_ready"):count+=1
	return count
func sample(img: Image,uv: Vector2) -> Color:
	var p:=uv*Vector2(img.get_size())-Vector2(.5,.5);var x:=floori(p.x);var y:=floori(p.y)
	var a:=img.get_pixel(clampi(x,0,img.get_width()-1),clampi(y,0,img.get_height()-1));var b:=img.get_pixel(clampi(x+1,0,img.get_width()-1),clampi(y,0,img.get_height()-1))
	var c:=img.get_pixel(clampi(x,0,img.get_width()-1),clampi(y+1,0,img.get_height()-1));var d:=img.get_pixel(clampi(x+1,0,img.get_width()-1),clampi(y+1,0,img.get_height()-1))
	return a.lerp(b,p.x-x).lerp(c.lerp(d,p.x-x),p.y-y)
func reflected_samples() -> Dictionary:
	var result: Dictionary={};var images: Dictionary={}
	for face in installed_faces():
		if not face.material_override.get_shader_parameter("reflection_ready"):continue
		var slot: Dictionary=manager.slot_for(face);var rid: RID=slot.viewport.get_viewport_rid()
		if not images.has(rid):images[rid]=slot.viewport.get_texture().get_image()
		var mat: ShaderMaterial=face.material_override;var u: Vector3=mat.get_shader_parameter("reflection_uv_x");var v: Vector3=mat.get_shader_parameter("reflection_uv_y");var colors: Array=[]
		for y in range(3,18):
			for x in range(3,18):
				var p:=Vector3(x/20.,y/20.,1.);colors.append(sample(images[rid],Vector2(p.dot(u),p.dot(v))))
		result[face.get_instance_id()]=colors
	return result
func compare_quality() -> void:
	# A static, high-contrast board behind the main camera isolates mapping and
	# detail from animation/time. Each mirror must see its own correct subregion.
	var board:=Node3D.new();city.add_child(board)
	for i in range(40):
		var material:=G.mat(["d73540","36aa68","306bc4","e7c842"][i%4]);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		G.box(board,Vector3(66.+i,3,28),Vector3(.98,6,.15),material)
	manager.fixed_density=128./1.67
	city.camera.position=Vector3(85,3.,20);city.camera.look_at(Vector3(85,2.4,4.245));city.bunny.hide();city.update_lighting(.4)
	for i in range(40):await draw()
	var shared:=reflected_samples();check(shared.size()==20,"All twenty mirrors provide actual rendered pixels for quality comparison")
	root.get_texture().get_image().save_png(output+"/quality-shared.png")
	manager.use_wall_occlusion=false
	for i in range(8):await draw()
	var uncull:=reflected_samples();var cull_errors: Array=[]
	for id in shared:
		for i in range(shared[id].size()):
			var a: Color=shared[id][i];var b: Color=uncull[id][i]
			cull_errors.append(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	var cull_p99:=quantile(cull_errors,.99)
	check(cull_p99<.005,"Opaque wall/slab culling preserves reflected pixels against uncullled reference")
	manager.use_wall_occlusion=true
	for i in range(8):await draw()
	var max_projection_error:=0.
	for face in installed_faces():
		var slot: Dictionary=manager.slot_for(face);var mat: ShaderMaterial=face.material_override;var u: Vector3=mat.get_shader_parameter("reflection_uv_x");var v: Vector3=mat.get_shader_parameter("reflection_uv_y");var extent: Vector2=face.mesh.size
		for point in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			var p:=Vector3(point.x,point.y,1.);var actual: Vector2=slot.camera.unproject_position(face.to_global(Vector3((point.x-.5)*extent.x,(.5-point.y)*extent.y,0)))
			max_projection_error=maxf(max_projection_error,actual.distance_to(Vector2(p.dot(u),p.dot(v))*Vector2(slot.viewport.size)))
	check(max_projection_error<.01,"Shared capture maps every mirror corner within 0.01 texture pixel")
	manager.share_coplanar=false
	for i in range(40):await draw()
	var reference:=reflected_samples();var errors: Array=[];var board_errors: Array=[];var total:=0.;var board_total:=0.
	root.get_texture().get_image().save_png(output+"/quality-reference.png")
	for id in shared:
		if not reference.has(id):continue
		for i in range(shared[id].size()):
			var a: Color=shared[id][i];var b: Color=reference[id][i];var error:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));errors.append(error);total+=error
			if maxf(b.r,maxf(b.g,b.b))-minf(b.r,minf(b.g,b.b))>.35:board_errors.append(error);board_total+=error
	var report:={"mirrors":shared.size(),"samples":errors.size(),"mean_channel_error":total/maxi(1,errors.size()),"p99_channel_error":quantile(errors,.99),"projection_error_pixels":max_projection_error,"occlusion_p99_error":cull_p99};print("MIRROR_MANY_QUALITY ",JSON.stringify(report))
	report.board_samples=board_errors.size();report.board_mean_error=board_total/maxi(1,board_errors.size());report.board_p99_error=quantile(board_errors,.99);print("MIRROR_MANY_BOARD ",JSON.stringify(report))
	FileAccess.open(output.get_base_dir()+"/mirror-many-quality.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	check(errors.size()==4500 and board_errors.size()>1800 and report.board_mean_error<.003 and report.board_p99_error<.015,"Shared image preserves the independent capture's colour board at matched sampling density")
	manager.share_coplanar=true
	for i in range(4):await draw()
	# Read back changing geometry at each mirror's centre, in addition to counters.
	var probes: Array=[];var signal_material:=G.mat("ef3025");signal_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for face in installed_faces():
		var slot: Dictionary=manager.slot_for(face);var direction: Vector3=(face.global_position-slot.camera.global_position).normalized()
		var probe:=G.box(city,face.global_position+direction*.4,Vector3(.2,.2,.2),signal_material);probe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;probes.append(probe)
	for frame in range(6):
		signal_material.albedo_color=Color("ef3025") if frame%2==0 else Color("28e64b")
		await draw()
		var images: Dictionary={};var matches:=0
		for face in installed_faces():
			var slot: Dictionary=manager.slot_for(face);var rid: RID=slot.viewport.get_viewport_rid()
			if not images.has(rid):images[rid]=slot.viewport.get_texture().get_image()
			var mat: ShaderMaterial=face.material_override;var p:=Vector3(.5,.5,1);var u: Vector3=mat.get_shader_parameter("reflection_uv_x");var v: Vector3=mat.get_shader_parameter("reflection_uv_y");var color:=sample(images[rid],Vector2(p.dot(u),p.dot(v)))
			if (color.r>color.g*1.5 if frame%2==0 else color.g>color.r*1.5):matches+=1
		check(matches==20,"All twenty actual mirror images show the current animated colour on frame "+str(frame))
	for probe in probes:probe.free()
	manager.fixed_density=0.;board.free();city.bunny.show()
func measure(kind: String,condition: String,seconds: float=4.) -> void:
	var enabled:=condition!="disabled";manager.set_process(enabled)
	if not enabled:
		for slot in manager.slots:slot.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var trace: Array=[];var synchronous:=true
	var frames: Array=[];var active: Array=[];var views: Array=[];var before: int=manager.render_count;var last:=Time.get_ticks_usec();var start:=last
	while Time.get_ticks_usec()-start<int(seconds*1000000.):
		var t: float=(Time.get_ticks_usec()-start)/1000000.;city.bunny.position=Vector3(85+sin(t*3.)*2.,.2,15.);city.bunny.reset_physics_interpolation();city.bunny.walking=true;city.bunny.step_phase=t*7.;city.bunny.animate_pose(0.)
		if kind=="room":
			var angle:=t*.65;city.camera.position=Vector3(85+sin(t)*.4,2.8,13+cos(t)*.4);city.camera.look_at(city.camera.position+Vector3(sin(angle),-.015,-cos(angle)))
		else:
			var center:=Vector3(91.8,2.6,7) if kind=="independent" else Vector3(85,2.4,4.245)
			city.camera.position=Vector3(91.8+sin(t*1.2)*.8,6,45) if kind=="independent" else Vector3(85+sin(t*1.2)*.6,3.,20)
			city.camera.look_at(center)
		var face_before: int=manager.face_update_count
		await draw()
		var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now;active.append(manager.active_count);views.append(manager.active_view_count)
		if enabled:synchronous=synchronous and manager.face_update_count-face_before==manager.active_count
		if OS.get_cmdline_user_args().has("--trace"):
			var targets: Array=[]
			for slot in manager.slots:
				if not slot.faces.is_empty():targets.append([str(slot.viewport.size),slot.camera.near,slot.camera.far,slot.camera.cull_mask])
			trace.append([t,frames[-1],manager.process_usec,targets])
	if not trace.is_empty():FileAccess.open(output.get_base_dir()+"/"+kind+"-"+condition+"-trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
	var pixels:=0
	var visible_draws:=0;var shadow_draws:=0;var primitives:=0
	for slot in manager.slots:
		if not enabled or slot.faces.is_empty():continue
		pixels+=slot.viewport.size.x*slot.viewport.size.y
		var rid: RID=slot.viewport.get_viewport_rid()
		visible_draws+=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		shadow_draws+=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		primitives+=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var result:={"layout":kind,"condition":condition,"frames":frames.size(),"frame_median_ms":quantile(frames,.5),"frame_p95_ms":quantile(frames,.95),"frame_p99_ms":quantile(frames,.99),"frame_max_ms":frames.max(),"over_16_7_ms":frames.filter(func(value):return value>16.7).size(),"installed_mirrors":installed_faces().size(),"active_min":active.min(),"active_max":active.max(),"views_median":quantile(views,.5),"reflection_draws_per_frame":float(manager.render_count-before)/frames.size(),"target_pixels":pixels,"ready_faces":ready_faces(),"every_visible_face_updated_each_frame":synchronous};rows.append(result);print("MIRROR_MANY_PERFORMANCE ",JSON.stringify(result))
	result.visible_draws=visible_draws;result.shadow_draws=shadow_draws;result.primitives=primitives;print("MIRROR_MANY_DRAWS ",kind," ",condition," visible=",visible_draws," shadow=",shadow_draws," primitives=",primitives)
	if enabled:
		check(result.active_max>=20 if kind!="room" else result.active_max>=5,"Twenty installed mirrors have no two-face limit: "+kind+"/"+condition)
		check(synchronous,"Every visible mirror updates on every frame: "+kind+"/"+condition)
		if benchmark:check(result.frame_p99_ms<16.7,"99% of complete frames stay within the 60 FPS budget: "+kind+"/"+condition)
		root.get_texture().get_image().save_png(output+"/"+kind+"-"+condition+".png")
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	benchmark=OS.get_cmdline_user_args().has("--benchmark")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):only_layout=arg.trim_prefix("--layout=")
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("二十镜验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;city.set_process(false);city.bunny.set_physics_process(false);session.active=false
	if OS.get_cmdline_user_args().has("--no-sun-shadows"):city.sun.shadow_enabled=false
	editor=city.build_mode;editor.open_editor();editor.set_process(false);editor.ui.hide();editor.grid.hide()
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);OS.low_processor_usage_mode=false
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await draw()
	RenderingServer.render_loop_enabled=false
	for kind in ["coplanar","independent","room"]:
		if only_layout!="" and kind!=only_layout:continue
		var data:=fixture(kind);var validated:=L.validate(data)
		check(validated.ok,"Actual catalog fixture with twenty mirrors validates: "+kind+" "+str(validated.get("message","")))
		if not validated.ok:continue
		check(editor.commit(data),"Commit twenty mirrors: "+kind)
		manager=city.get_node("MirrorReflections")
		if OS.get_cmdline_user_args().has("--no-occlusion"):manager.use_wall_occlusion=false
		editor.set_storey(0);editor.set_roof_visible(true);city.bunny.show()
		city.camera.position=Vector3(91.8,6,45) if kind=="independent" else Vector3(85,3,20);city.camera.look_at(Vector3(91.8,2.6,7) if kind=="independent" else Vector3(85,2.4,4.245))
		await physics_frame;await physics_frame
		var cold: Array=[]
		for i in range(30):
			var start:=Time.get_ticks_usec();await draw();cold.append((Time.get_ticks_usec()-start)/1000.)
		print("MIRROR_MANY_COLD ",kind," frames=30 max_ms=",cold.max()," p95_ms=",quantile(cold,.95))
		check(installed_faces().size()==20,"Exactly twenty actual mirror faces are installed: "+kind)
		for i in range(60):await draw()
		await measure(kind,"disabled",4.)
		manager.set_process(true);city.update_lighting(.4)
		for i in range(60):await draw()
		await measure(kind,"day")
		city.update_lighting(.92)
		for i in range(60):await draw()
		await measure(kind,"night")
		if kind=="coplanar":await compare_quality()
	RenderingServer.render_loop_enabled=true
	var report:={"diagnostic_args":OS.get_cmdline_user_args(),"sun_shadows":city.sun.shadow_enabled,"main_msaa":root.msaa_3d,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"window":str(root.size),"scale":root.scaling_3d_scale,"metric":"Uncapped vsync-off complete frames: one explicit draw per process frame, automatic render loop disabled; full town plus 20 real catalog mirrors, furniture, lamps, moving camera and animated character. P99 threshold 16.7ms. GPU timings are not used as total frame time.","rows":rows}
	FileAccess.open(output.get_base_dir()+"/mirror-many-performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));city.free();session.free();await process_frame
	print("MIRROR_MANY_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
