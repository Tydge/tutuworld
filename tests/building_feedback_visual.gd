extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const T=preload("res://scripts/building/templates.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func capture(name_: String) -> void:
	for i in range(4):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("接缝验证兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout
	var editor=city.build_mode;editor.open_editor();editor.set_process(false);editor.ui.hide();editor.grid.hide()
	check(editor.commit(T.player_sample("two_storey")),"Edited house fixture")
	editor.set_storey(1);editor.set_roof_visible(true);editor.grid.hide()
	var internal_faces:=0;var exposed_faces:=0
	var walkable: Dictionary=L.walkable_grid(editor.layout,1).floors
	for mesh in editor.room.get_node("Structure/Floor").find_children("*","MeshInstance3D",true,false):
		if mesh.global_position.y<4.:continue
		var arrays: Array=mesh.mesh.surface_get_arrays(0)
		for i in range(0,arrays[Mesh.ARRAY_INDEX].size(),3):
			var idx: int=arrays[Mesh.ARRAY_INDEX][i];var normal: Vector3=arrays[Mesh.ARRAY_NORMAL][idx]
			if absf(normal.y)>.5:continue
			var center:=Vector3.ZERO
			for j in range(3):center+=mesh.to_global(arrays[Mesh.ARRAY_VERTEX][arrays[Mesh.ARRAY_INDEX][i+j]])/3.
			var side:=Vector2(center.x,center.z)+Vector2(normal.x,normal.z)*.01
			if walkable.has(preload("res://scripts/building/grid_layout.gd").cell(side)):internal_faces+=1
			else:exposed_faces+=1
	check(internal_faces==0 and exposed_faces>0,"Mixed-material slab has no internal coplanar sides, while exposed edges remain")
	city.camera.position=Vector3(138,5.6,23);city.camera.look_at(Vector3(140.5,4.85,17.5));await capture("balcony-material-seam")
	city.camera.position=Vector3(129,2.1,34);city.camera.look_at(Vector3(129,2,27.8));await capture("sign-depth-separated")
	var lights:=L.add(L.empty(),{"type":"floor","a":[61.,-7.],"b":[120.,27.]})
	for i in range(L.MAX_LIGHTS):lights=L.add(lights,{"type":"object","kind":"floor_lamp","position":[63.+(i%12)*4.,-5.+floori(i/12.)*4.],"yaw":0.})
	check(editor.commit(lights),"48 real lamps build and render")
	editor.set_storey(0);editor.grid.hide();editor.set_night_preview(true)
	var actual: Array=editor.room.get_node("Furnishing").find_children("*","Light3D",true,false)
	check(actual.size()==48 and actual.all(func(light):return light.visible and light.distance_fade_enabled),"48 active fixtures retain distance and shadow culling")
	city.camera.position=Vector3(84,30,40);city.camera.look_at(Vector3(84,0,3));await capture("48-lamps-night")
	print("BUILDING_FEEDBACK_VISUAL_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
