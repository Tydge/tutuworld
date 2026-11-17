extends SceneTree
var checks:=0
var failures: Array=[]
var camera: Camera3D
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func capture() -> Image:
	for frame in range(5):await process_frame;RenderingServer.force_draw()
	return viewport.get_texture().get_image()
func run() -> void:
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1024,768);Engine.max_fps=60
	viewport=SubViewport.new();viewport.size=Vector2i(1024,768);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();world.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("99afbf")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.25
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=50;sun.shadow_normal_bias=.1;world.add_child(sun)
	var point_light:=OmniLight3D.new();point_light.position=Vector3(-3,7,1);point_light.omni_range=22;point_light.light_energy=4;point_light.shadow_enabled=true;point_light.shadow_normal_bias=.1;world.add_child(point_light)
	var spot:=SpotLight3D.new();spot.position=Vector3(3,9,3);spot.spot_range=25;spot.spot_angle=50;spot.light_energy=6;spot.shadow_enabled=true;spot.shadow_normal_bias=.1;world.add_child(spot);spot.look_at(Vector3.ZERO)
	var floor_:=MeshInstance3D.new();floor_.mesh=PlaneMesh.new();floor_.mesh.size=Vector2(30,30)
	var ground:=StandardMaterial3D.new();ground.albedo_color=Color("a9b99b");ground.roughness=1;floor_.material_override=ground;world.add_child(floor_)
	camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(9,11,15);camera.look_at(Vector3(0,0,0));camera.current=true
	var caster:=MeshInstance3D.new();caster.mesh=BoxMesh.new();caster.mesh.size=Vector3(2,4,2);caster.position=Vector3(0,4,0);world.add_child(caster)
	var exclusion:=Rect2();var first:=true
	for x in [-1.,1.]:
		for y in [2.,6.]:
			for z in [-1.,1.]:
				var screen:=camera.unproject_position(Vector3(x,y,z))
				if first:exclusion=Rect2(screen,Vector2.ZERO);first=false
				else:exclusion=exclusion.expand(screen)
	exclusion=exclusion.grow(4.)
	var out:=preload("res://tests/test_support.gd").output_dir()
	var lights: Array=[sun,point_light,spot]
	for light_index in range(lights.size()):
		for i in range(lights.size()):lights[i].visible=i==light_index
		for shader in ["occlusion_fade","tree_bark"]:
			var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/"+shader+".gdshader");caster.material_override=material
			if shader=="tree_bark":material.set_shader_parameter("bark_texture",load("res://assets/terrain/warm_tree_bark_v1.png"))
			caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var unshadowed: Image=await capture()
			caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var full: Image=await capture();full.save_png(out+"/"+str(light_index)+"-"+shader+"-full.png")
			material.set_shader_parameter("opacity",0.)
			# Local light shadow maps are cached. Force an actual light-view render
			# so retaining yesterday's map cannot make a broken shader pass the test.
			lights[light_index].shadow_enabled=false;await process_frame;lights[light_index].shadow_enabled=true
			var cut: Image=await capture();cut.save_png(out+"/"+str(light_index)+"-"+shader+"-cut.png")
			var count_:=0;var difference:=0.;var maximum:=0.
			for y in range(full.get_height()):
				for x in range(full.get_width()):
					if exclusion.has_point(Vector2(x,y)):continue
					var shade:=full.get_pixel(x,y).get_luminance()
					if unshadowed.get_pixel(x,y).get_luminance()-shade<.06:continue
					var delta:=absf(cut.get_pixel(x,y).get_luminance()-shade);count_+=1;difference+=delta;maximum=maxf(maximum,delta)
			var center:=Vector2i(camera.unproject_position(caster.position))
			check(full.get_pixelv(center).get_luminance()-cut.get_pixelv(center).get_luminance()>.03 or Vector3(full.get_pixelv(center).r,full.get_pixelv(center).g,full.get_pixelv(center).b).distance_to(Vector3(cut.get_pixelv(center).r,cut.get_pixelv(center).g,cut.get_pixelv(center).b))>.1,"Main camera still cuts the obstructing tree: "+shader+" light="+str(light_index))
			var mean:=difference/maxi(1,count_)
			print("TREE_SHADOW_STABILITY ",JSON.stringify({"light":light_index,"shader":shader,"shadow_pixels":count_,"mean_change":mean,"max_change":maximum}))
			check(count_>100 and mean<.003 and maximum<.025,"Ground shadow stays whole when the tree fades for the player: "+shader+" light="+str(light_index))
	world.queue_free();await process_frame
	print("WOODLAND_SHADOW_STABILITY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
