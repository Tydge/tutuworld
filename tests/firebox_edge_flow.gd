extends SceneTree
const Factory=preload("res://scripts/building/module_factory.gd")
const Repair=preload("res://scripts/city/hearth_backing.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var output: String
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func black_depths(model: Node3D) -> Array:
	var depths: Array=[];var black:=Color("4d5148").srgb_to_linear()
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for s in range(mesh.mesh.get_surface_count()):
			var arrays: Array=mesh.mesh.surface_get_arrays(s);var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(colors.size()):
				var delta:=Vector3(colors[i].r-black.r,colors[i].g-black.g,colors[i].b-black.b)
				if delta.length()>.01:continue
				var p:=model.to_local(mesh.to_global(vertices[i]))
				if absf(p.x)<.801 and p.y>.249 and p.y<1.411 and not depths.has(snappedf(p.z,.001)):depths.append(snappedf(p.z,.001))
	depths.sort();return depths
func pixel_luma(img: Image,point: Vector3) -> float:
	var pixel: Vector2=city.camera.unproject_position(point)*Vector2(img.get_size())/city.camera.get_viewport().get_visible_rect().size;var c:=img.get_pixel(int(pixel.x),int(pixel.y));return c.r*.2126+c.g*.7152+c.b*.0722
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("背板检查兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await create_timer(.5).timeout;s.active=false;city.set_process(false);city.hud.hide();city.bunny.hide();city.atmosphere.ssao_enabled=false;city.sun.shadow_enabled=false;city.update_lighting(.5)
	var model:=Node3D.new();model.position=Vector3(80,.18,18);city.add_child(model);Factory.builder(model).build_item(model,"hearth");model.get_node("Part_effects").hide();model.get_node("FixtureFireLight").hide()
	var depths:=black_depths(model);check(depths.size()==2 and is_equal_approx(depths[0],-.27) and is_equal_approx(depths[1],-.19),"New hearth backing has four centimetres of separation from the pillar rear, including its overlapped edges")
	var fixed: Node3D=city.home.get_node("Furnishing/hearth");var old:=black_depths(fixed);check(old.size()==2 and is_equal_approx(old[0],-.27),"An existing packed house hearth is repaired at load without rebuilding the map")
	# The actual rear pillar surface must stay stone throughout a slow orbit.
	var minimum:=INF;var maximum:=0.
	for i in range(17):
		var angle:=deg_to_rad(-55.+i*110./16.);city.camera.position=model.to_global(Vector3(sin(angle)*3.,1.4,-cos(angle)*3.));city.camera.look_at(model.to_global(Vector3(0,.9,0)))
		for frame in range(3):await process_frame;RenderingServer.force_draw()
		var img:=root.get_texture().get_image()
		for side in [-1,1]:
			for y in [.6,.85,1.1]:
				var edge:=pixel_luma(img,model.to_global(Vector3(side*.75,y,-.311)));var stone:=pixel_luma(img,model.to_global(Vector3(side*1.03,y,-.311)));var ratio:=edge/maxf(stone,.001);minimum=minf(minimum,ratio);maximum=maxf(maximum,ratio)
		if i in [0,8,16]:img.save_png(output+"/rear-orbit-"+str(i)+".png")
	print("BACK_EDGE_ORBIT min_stone_ratio=",minimum," max_stone_ratio=",maximum," frames=51 samples=102 flame_effects=hidden")
	check(minimum>.55,"Rear pillar edge pixels stay stone through seventeen angles with all flame effects hidden")
	var before: Array=fixed.find_children("*","MeshInstance3D",true,false).map(func(mesh):return mesh.mesh);Repair.repair_legacy(fixed);check(fixed.find_children("*","MeshInstance3D",true,false).map(func(mesh):return mesh.mesh)==before,"The packed-mesh repair runs only once per loaded hearth")
	print("FIREBOX_EDGE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
