extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	Engine.max_fps=60
	var viewport:=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();world.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=1.
	var white:=Image.create(4,4,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
	var texture:=ImageTexture.create_from_image(white)
	for mode in [1,2]:
		var node:=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_colors=true
		var quad:=QuadMesh.new();quad.size=Vector2(4,4);node.multimesh.mesh=quad;node.multimesh.instance_count=1;node.multimesh.set_instance_transform(0,Transform3D.IDENTITY);node.multimesh.set_instance_color(0,Color.RED if mode==1 else Color.BLUE)
		var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/ancient_foliage.gdshader");material.set_shader_parameter("foliage_atlas",texture);material.set_shader_parameter("forest_lod",mode);node.material_override=material;node.position.y=2.;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(node)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true
	var weights: Array[float]=[];var out:=preload("res://tests/test_support.gd").output_dir()
	for distance in [55.,64.,74.,84.,94.,104.,114.]:
		camera.position=Vector3(0,2,distance);camera.look_at(Vector3(0,2,0));camera.fov=rad_to_deg(2.*atan(3./distance))
		for frame in range(5):await process_frame;RenderingServer.force_draw()
		var image:=viewport.get_texture().get_image();var red:=0.;var blue:=0.;var covered:=0
		for y in range(160,352):
			for x in range(160,352):
				var color:=image.get_pixel(x,y);red+=color.r;blue+=color.b
				if color.r+color.b>.05:covered+=1
		var weight:=red/maxf(.001,red+blue);weights.append(weight)
		print("TREE_LOD_BLEND ",JSON.stringify({"distance":distance,"near_weight":weight,"covered_fraction":covered/36864.}))
		check(covered>36500,"Complementary LODs leave no transparent hole at "+str(distance)+"m")
		image.save_png(out+"/lod-"+str(int(distance))+".png")
	check(weights[0]>.99 and weights[-1]<.01,"GPU uses the detailed tree nearby and the distant silhouette far away")
	check(weights[2]>.65 and weights[2]<.95 and weights[3]>.4 and weights[3]<.6 and weights[4]>.05 and weights[4]<.35,"GPU crossfades through intermediate coverage instead of switching the whole batch")
	var monotonic:=true
	for i in range(1,weights.size()):monotonic=monotonic and weights[i]<=weights[i-1]+.01
	check(monotonic,"LOD coverage changes monotonically through the transition")
	var map=load("res://scenes/valley_map.scn").instantiate();var trees: int=map.get_meta("ancient_tree_count");var shadow_instances:=0;var independent:=true;var bounds_safe:=true
	for node in map.get_node("AncientForest").find_children("*","MultiMeshInstance3D",true,false):
		if node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			shadow_instances+=node.multimesh.instance_count
			independent=independent and int(node.material_override.get_shader_parameter("forest_lod"))==0 and node.visibility_range_begin==0 and node.visibility_range_end==0
		elif int(node.material_override.get_shader_parameter("forest_lod"))==1:
			var center: Vector3=node.multimesh.get_aabb().get_center()
			for i in range(node.multimesh.instance_count):bounds_safe=bounds_safe and node.visibility_range_end>=104.+node.multimesh.get_instance_transform(i).origin.distance_to(center)
	check(shadow_instances==trees*2 and independent,"Every tree has a complete shadow silhouette independent of visual LOD and camera cutaway")
	check(bounds_safe,"Coarse batch culling cannot interrupt an individual tree's fade")
	map.free();viewport.queue_free();await process_frame
	print("WOODLAND_LOD_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
