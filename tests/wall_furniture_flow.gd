extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const W=preload("res://scripts/building/wall_mount.gd")
const G=preload("res://scripts/geometry.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func photo(name_: String) -> void:
	for i in range(4):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func mouse(p: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=root.get_final_transform()*p;event.pressed=down;event.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(event);await process_frame
func motion(p: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=root.get_final_transform()*p;Input.parse_input_event(event);await process_frame
func run() -> void:
	var original_occlusion: bool=root.use_occlusion_culling
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("墙面陈设测试","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;city.set_process(false);city.bunny.set_physics_process(false);city.bunny.hide();city.bunny.collision_layer=0;session.active=false
	var editor=city.build_mode;editor.open_editor();editor.set_process(false);var data:=L.empty()
	for level in range(4):
		data=L.add(data,{"type":"floor","a":[70.,1.],"b":[82.,13.],"storey":level})
		for line in [[[70.,1.],[82.,1.]],[[70.,1.],[70.,13.]],[[82.,1.],[82.,13.]],[[70.,13.],[82.,13.]]]:data=L.add(data,{"type":"wall","a":line[0],"b":line[1],"storey":level})
	check(editor.commit(data),"Four-storey wall display fixture")
	for level in [1,2,3]:
		editor.set_storey(level);editor.set_roof_visible(true)
		check(editor.room.render_cache.values().all(func(entry):return entry.row.type!="wall" or int(entry.row.get("storey",0))>level or entry.node.visible),"Complete walls includes every lower floor: "+str(level+1))
		check(editor.room.render_cache.values().all(func(entry):return entry.row.type!="wall" or int(entry.row.get("storey",0))<=level or not entry.node.visible),"Higher floor walls remain hidden: "+str(level+1))
		editor.set_roof_visible(false);check(editor.room.render_cache.values().all(func(entry):return entry.row.type!="wall" or int(entry.row.get("storey",0))>=level or not entry.node.visible),"Returning to cutaway restores floor isolation")
	editor.set_storey(1);editor.set_roof_visible(true);editor.focus=Vector3(76,4.7,7);editor.distance_=27.;editor.update_camera();await photo("complete-lower-walls")
	data=L.add(L.empty(),{"type":"floor","a":[70.,1.],"b":[82.,13.]});data=L.add(data,{"type":"wall","a":[70.,1.],"b":[82.,1.]})
	for entry in [["wall_botanical",71.5],["wall_mirror",74.],["wall_clock",76.],["wall_sconce",78.]]:
		var row:=W.attach(data,{"type":"object","kind":entry[0],"position":[entry[1],1.],"yaw":0.},Vector2(entry[1],1),Vector2(76,7));data=L.add(data,row)
	data=L.add(data,{"type":"object","kind":"kitchen_cart","position":[78.,3.],"yaw":0.});var cart_id: String=data.elements[-1].id;var jars:=L.attach_at(data,{"type":"object","kind":"spice_jars","position":[78.,3.],"yaw":0.},Vector2(78,3),cart_id);data=L.add(data,jars)
	check(editor.commit(data),"Six new objects validate and build together");editor.set_storey(0);editor.set_roof_visible(true);await physics_frame;await physics_frame
	editor.choose_tool("object:wall_botanical");city.camera.position=Vector3(76,3.0,8);city.camera.look_at(Vector3(76,2.4,1.14));var mouse: Vector2=city.camera.unproject_position(Vector3(80.,2.7,1.14));var point: Variant=editor.point_at(mouse);var sample: Dictionary=editor.row_at(point)
	check(sample.get("support","")!="" and is_equal_approx(sample.mount_height,2.0),"Actual camera ray places a wall object at mouse height")
	editor.choose_tool("select");editor.ui.hide();editor.grid.hide()
	var art: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="wall_botanical")[0];var art_id: String=art.id;var start: Vector2=city.camera.unproject_position(Vector3(71.5,2.405,1.25));var end: Vector2=city.camera.unproject_position(Vector3(71.85,2.805,1.25))
	await motion(start);await mouse(start,true)
	for i in range(1,5):await motion(start.lerp(end,i/4.));await create_timer(.06).timeout
	await mouse(end,false);await physics_frame;await physics_frame
	var dragged:=L.find(editor.layout,art_id);check(dragged.mount_height>art.mount_height+.25 and dragged.position[0]>art.position[0]+.1,"Actual direct drag moves wall decoration horizontally and vertically")
	city.camera.position=Vector3(76,3.4,7.8);city.camera.look_at(Vector3(75.7,2.1,1.6));await create_timer(.3).timeout;await photo("wall-decor-and-kitchen-cart")
	var manager: Node=city.get_node("MirrorReflections");check(manager.active_count==1 and manager.slots.size()==1,"Only visible nearby mirror allocates a reflection view")
	var mirror: Node3D=editor.room.get_node("Furnishing").get_children().filter(func(n):return n.get_meta("furniture_kind","")=="wall_mirror")[0];var face: MeshInstance3D=mirror.find_child("MirrorFace",true,false)
	city.camera.position=Vector3(74,2.5,7);city.camera.look_at(face.global_position)
	var red:=G.box(city,Vector3(74,2.4,10),Vector3(1.5,1.5,.4),G.mat("ef3025"));await create_timer(.45).timeout
	check(face.material_override.get_shader_parameter("reflection_ready"),"Visible mirror receives an actual rendered planar texture")
	var slot: Dictionary=manager.slot_for(face);var img: Image=slot.viewport.get_texture().get_image();var reds:=0
	for y in range(0,img.get_height(),3):
		for x in range(0,img.get_width(),3):
			var c:=img.get_pixel(x,y)
			if c.r>.45 and c.r>c.g*1.7 and c.r>c.b*1.6:reds+=1
	check(city.camera.is_position_behind(red.global_position) and reds>20,"Mirror reflects a real red object behind the main camera, beyond screen-space reflection")
	var extent: Vector2=face.mesh.size;var corner: Vector2=slot.camera.unproject_position(face.to_global(Vector3(-extent.x*.5,-extent.y*.5,0)))
	var uv_x: Vector3=face.material_override.get_shader_parameter("reflection_uv_x");var uv_y: Vector3=face.material_override.get_shader_parameter("reflection_uv_y");var lower_left:=Vector3(0,1,1)
	check(corner.distance_to(Vector2(lower_left.dot(uv_x),lower_left.dot(uv_y))*Vector2(slot.viewport.size))<.01,"Off-axis projection maps mirror corners to the rendered texture without stretching")
	check(slot.camera.cull_mask & (1<<19)==0 and slot.camera.near>5.,"Reflection excludes recursive mirror faces and clips the wall behind its plane")
	img.save_png(preload("res://tests/test_support.gd").output_dir()+"/reflection-texture.png");await photo("real-planar-reflection")
	var before: int=slot.updates
	for i in range(24):red.position.x=74+sin(i*.3)*.5;await process_frame;RenderingServer.force_draw()
	check(slot.updates-before>=23,"Stationary main camera keeps the moving reflection at the main frame rate")
	before=manager.render_count
	city.camera.position=Vector3(74,2.5,-3);city.camera.look_at(face.global_position);await create_timer(.15).timeout;before=manager.render_count;await create_timer(.2).timeout;check(manager.active_count==0 and manager.render_count==before,"Back-facing mirror stops reflection rendering")
	red.free();city.camera.position=Vector3(76,3.0,7);city.camera.look_at(face.global_position);city.bunny.show();city.bunny.position=Vector3(72.76,.2,4.8);city.bunny.visual.rotation.y=atan2(face.global_position.x-city.bunny.position.x,face.global_position.z-city.bunny.position.z);await create_timer(.3).timeout;await photo("bunny-in-real-mirror");city.bunny.hide()
	var many: Dictionary=editor.layout
	for row in many.elements.duplicate():
		if row.get("kind","") in ["wall_clock","wall_botanical"]:many=L.remove(many,row.id)
	for x in [72.,76.]:many=L.add(many,W.attach(many,{"type":"object","kind":"wall_mirror","position":[x,1.],"yaw":0.},Vector2(x,1),Vector2(74,7)))
	check(editor.commit(many),"Multiple-mirror fixture validates");editor.set_roof_visible(true);city.camera.position=Vector3(74,2.5,7);city.camera.look_at(Vector3(74,2.43,1.245));await create_timer(.4).timeout
	check(manager.active_count==3 and manager.active_view_count==1,"Three coplanar mirrors all reflect using one shared view")
	var active_slot: Dictionary=manager.slots.filter(func(entry):return not entry.faces.is_empty())[0]
	var handles: Array=[];var offsets: Array=[]
	for mirror_face in active_slot.faces:
		handles.append(mirror_face.material_override.get_shader_parameter("reflection_texture").get_rid());offsets.append(mirror_face.material_override.get_shader_parameter("reflection_uv_x"))
	check(handles.size()==3 and handles[0]==handles[1] and handles[1]==handles[2] and offsets[0]!=offsets[1] and offsets[1]!=offsets[2],"Shared texture has a distinct correct window for every mirror")
	city.camera.position=Vector3(74,2.5,4);city.camera.look_at(Vector3(74,2.43,1.245));await create_timer(.12).timeout
	var close_pixels: int=active_slot.viewport.size.x*active_slot.viewport.size.y
	check(manager.active_count==3 and close_pixels>327680,"Close mirrors can exceed the old total pixel budget while keeping all three reflections")
	before=manager.face_update_count
	for i in range(24):city.camera.position.x=74+sin(i*.2)*.3;city.camera.look_at(Vector3(74,2.43,1.245));await process_frame;RenderingServer.force_draw()
	check(manager.face_update_count-before>=3*23,"All three mirrors refresh every main frame without alternating")
	for distance in [17.,19.,26.,35.]:
		city.camera.position=Vector3(74,2.5,distance);city.camera.look_at(Vector3(74,2.4,1.2));await create_timer(.12).timeout
		for i in range(3):await process_frame;RenderingServer.force_draw()
		check(manager.active_count==3 and manager.slots.filter(func(entry):return not entry.faces.is_empty()).all(func(entry):return entry.faces.all(func(f):return f.material_override.get_shader_parameter("reflection_ready"))),"Visible mirrors keep their real reflection past the old distance limit: "+str(distance))
	await create_timer(1.2).timeout
	var pixels:=0
	for entry in manager.slots:
		if not entry.faces.is_empty():pixels+=entry.viewport.size.x*entry.viewport.size.y
	check(pixels<close_pixels*.2,"Far mirrors reduce rendered pixels instead of dropping animation frames")
	city.camera.position=Vector3(74,2.5,7);city.camera.look_at(Vector3(74,2.4,1.2));await create_timer(.12).timeout
	var blocker:=Node3D.new();city.add_child(blocker);blocker.position=Vector3(74,2.43,4)
	G.box(blocker,Vector3.ZERO,Vector3(.24,.24,.2),G.mat("637865"));preload("res://scripts/city/prop_collisions.gd").box(blocker,"MirrorOccluder",Vector3.ZERO,Vector3(.24,.24,.2))
	await physics_frame;await physics_frame;await create_timer(.12).timeout
	check(manager.slots.any(func(entry):return entry.faces.has(face)),"A blocked centre does not disable the visible edges of a mirror")
	blocker.scale=Vector3(30,30,1);await physics_frame;await physics_frame;await create_timer(.12).timeout;before=manager.render_count
	for i in range(6):await process_frame;RenderingServer.force_draw()
	check(manager.active_count==0 and manager.render_count==before,"Fully occluded mirrors do no additional scene renders");blocker.free()
	city.camera.position=Vector3(74,2.5,7);city.camera.look_at(Vector3(74,2.5,20));await create_timer(.12).timeout;before=manager.render_count
	for i in range(6):await process_frame;RenderingServer.force_draw()
	check(manager.active_count==0 and manager.render_count==before,"Off-screen mirrors do no additional scene renders")
	var roofed:=L.add(editor.layout,{"type":"roof","a":[70.,1.],"b":[82.,13.]})
	check(editor.commit(roofed),"Mirror fixture includes a real collidable roof");editor.set_storey(0);editor.set_roof_visible(true)
	city.camera.position=Vector3(74,12,7);city.camera.look_at(Vector3(74,2.43,1.245));await physics_frame;await physics_frame
	for i in range(8):await process_frame;RenderingServer.force_draw()
	check(manager.active_count==3,"Invisible editor roof does not block reflection visibility")
	check(editor.commit(preload("res://scripts/building/templates.gd").player_sample("two_storey")),"Updated player house builds as actual catalog template")
	editor.set_storey(0);editor.set_roof_visible(true);editor.ui.hide();editor.grid.hide();city.camera.position=Vector3(142.5,2.5,12.2);city.camera.look_at(Vector3(140.2,1.25,9.7));await create_timer(.15).timeout
	var fireplace: Node3D=editor.room.get_node("Furnishing/build_169");var body: StaticBody3D=fireplace.get_node("HearthCollision");var shape: BoxShape3D=body.get_child(0).shape
	check(absf(body.global_position.z-shape.size.z*.5-9.13)<.002,"Actual fireplace collision has one centimetre clearance from the wall face")
	await photo("updated-template-fireplace-against-wall")
	city.queue_free();await create_timer(.15).timeout
	check(root.use_occlusion_culling==original_occlusion,"Leaving the city restores the root viewport occlusion setting")
	print("WALL_FURNITURE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
