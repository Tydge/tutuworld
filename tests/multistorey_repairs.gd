extends SceneTree
const T=preload("res://scripts/building/templates.gd")
const S=preload("res://scripts/building/storeys.gd")
var failures: Array=[]
var checks:=0
var city: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func capture(label_: String,eye: Vector3,target: Vector3) -> void:
	city.camera.position=eye;city.camera.look_at(target)
	city.hud.hide();city.bunny.hide()
	city.build_mode.room.refresh_view(eye,city.bunny.position)
	if DisplayServer.get_name()=="headless":return
	for i in range(8):await process_frame;RenderingServer.force_draw()
	var frame:=root.get_texture().get_image()
	frame.save_png(output+"/"+label_+".png")
	if label_ in ["ground-mode1","stairs-mode1"]:
		var sky:=0;var samples:=0
		for y in range(int(frame.get_height()*.15),int(frame.get_height()*.65),12):
			for x in range(int(frame.get_width()*.25),int(frame.get_width()*.75),12):
				var pixel:=frame.get_pixel(x,y);samples+=1
				if pixel.b>pixel.r*1.3 and pixel.b>pixel.g*1.1:sky+=1
		check(float(sky)/maxi(1,samples)<.01,"M02/M03 rendered ceiling has no sky: "+label_)
	if label_.begins_with("ocean-"):
		var sum:=0.;var samples:=0
		for y in range(int(frame.get_height()*.5),int(frame.get_height()*.6),12):
			for x in range(int(frame.get_width()*.3),int(frame.get_width()*.7),12):
				var pixel:=frame.get_pixel(x,y);sum+=pixel.r/maxf(.01,pixel.b);samples+=1
		check(sum/maxi(1,samples)<.35,"M01 rendered ocean rather than blue sky: "+label_)
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("修复验证兔","bunny","bow_rose");session.state().build_layout=T.two_storey();session.state().player_position=[134.5,.2,11.5];session.state().time=.4*3600.
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;session.active=false;city.set_process(false);city.bunny.set_physics_process(false);city.build_mode.room.set_process(false)
	if DisplayServer.get_name()!="headless":root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,800)
	var room: Node3D=city.build_mode.room
	var sea: Material=city.scenery.get_node("Island").get_meta("sea_material");var count:=0
	for node in city.scenery.find_children("*","GeometryInstance3D",true,false):
		if node.material_override==sea:count+=1;check(node.visibility_range_end==0.,"M01 ocean has unlimited range")
	check(count>0,"M01 actual packed ocean found")
	for mode_ in [1,2,0,1]:
		session.settings.interior_view_mode=mode_
		for place in [["ground",Vector3(143.5,.18,12.)],["stairs",Vector3(133.,2.53,5.)],["upper",Vector3(139.,4.88,13.)]]:
			city.bunny.position=place[1];room.refresh_view(place[1]+Vector3(0,2,3),place[1])
			for entry in room.render_cache.values():
				if entry.row.type not in ["roof","floor_chunk","wall"]:continue
				if mode_!=0:check(entry.node.is_visible_in_tree() and (entry.row.type!="floor_chunk" or entry.visuals.all(func(v):return v.visible and v.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)),"M02/M03 shell present %s mode%d %s"%[place[0],mode_,entry.row.id])
				if entry.row.type=="roof":check(entry.visuals.any(func(v):return v.is_visible_in_tree() and v.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY),"M02 persistent roof shadow retained")
			await capture("%s-mode%d"%[place[0],mode_],place[1]+Vector3(0,1.5,2),place[1]+Vector3(0,4,-2))
	session.settings.interior_view_mode=1
	city.bunny.position=Vector3(143.5,.18,12)
	var pivot: Vector3=city.bunny.position+Vector3.UP*1.35
	var safe: Vector3=city.camera_safe_position(pivot,pivot+Vector3(0,10,0))
	check(safe.y<4.58,"M03 camera cannot cross upper floor")
	city.bunny.position=Vector3(133,2.53,5)
	pivot=city.bunny.position+Vector3.UP*1.35
	safe=city.camera_safe_position(pivot,pivot+Vector3.UP*15)
	check(safe.y>4.7 and safe.y<9.28,"M03 stair opening allows upper space but stops camera below real roof")
	# Probe the full horizontal slab band at exterior walls, including beside the stairwell.
	var space:=city.get_world_3d().direct_space_state
	for z in [3.,5.,8.,11.,15.,17.]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(130,4.73,z),Vector3(132,4.73,z),4))
		check(not hit.is_empty(),"M05 solid inter-storey perimeter z="+str(z))
	city.bunny.position=Vector3(139,4.88,13)
	await capture("exterior-seam",Vector3(123,5,18),Vector3(133,4.7,10))
	await capture("stair-guards",Vector3(139,8,13),Vector3(133,3,7))
	city.bunny.position=Vector3(144,4.88,16)
	for x in [140,146,154,165]:await capture("ocean-%d"%x,Vector3(x,7,20),Vector3(190,0,30))
	city.update_lighting(.85)
	for mode_ in [0,1,2]:
		session.settings.interior_view_mode=mode_;city.bunny.position=Vector3(133,2.53,5)
		await capture("night-stairs-mode%d"%mode_,Vector3(134,4.4,7),Vector3(133,7,3.5))
	city.update_lighting(.4)
	# Use actual generated safety-panel endpoints to probe support, on every form/rotation.
	var L=preload("res://scripts/building/layout.gd")
	var Stairs=preload("res://scripts/building/stairs.gd")
	city.bunny.position=Vector3(139,.2,25);city.build_mode.open_editor();city.build_mode.set_process(false);city.build_mode.ui.hide()
	for form in Stairs.FORMS:
		for yaw in [0,90,180,270]:
			var data: Dictionary=L.empty()
			for level in [0,1]:data=L.add(data,{"type":"floor","a":[110.,-6.],"b":[130.,26.],"storey":level})
			data=L.add(data,{"type":"stairs","position":[120.,10.],"form":form,"yaw":yaw})
			check(city.build_mode.commit(data),"M04 fixture %s/%d"%[form,yaw]);await physics_frame;await physics_frame
			var stair: Node3D
			for entry in room.render_cache.values():
				if entry.row.type=="stairs":stair=entry.node
			var supported:=true
			for body in stair.find_children("RailCollision*","StaticBody3D",true,false):
				var shape: CollisionShape3D=body.get_child(0)
				var points: PackedVector3Array=shape.shape.points
				for start in [0,4]:
					var found:=false
					for index in [start,start+2]:
						# Sample inside the post footprint, avoiding zero-area triangle edges after rotation.
						var local: Vector3=points[index].lerp(points[index+4 if start==0 else index-4],.002)
						var foot: Vector3=body.global_transform*local
						var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.04,foot-Vector3.UP*.28,8))
						if not hit.is_empty():found=true
					if not found:supported=false;print("UNSUPPORTED ",form,"/",yaw," ",body.get_path()," ",body.global_transform*points[start])
			check(supported,"M04 rail ends meet physical slab/platform/flight %s/%d"%[form,yaw])
			city.build_mode.set_storey(2);city.build_mode.set_roof_visible(true)
			await capture("rails-%s-%d"%[form,yaw],Vector3(133,15,26),Vector3(120,3,10))
	city.free();session.free();print("MULTISTOREY_REPAIRS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
