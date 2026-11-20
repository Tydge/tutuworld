extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
var viewport: SubViewport
var camera: Camera3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func valley_sun() -> DirectionalLight3D:
	# Exercise the real runtime profile, including its override of the city light.
	var source=load("res://scenes/valley_map.scn").instantiate()
	var profile=load("res://scripts/valley/valley_world.gd").new()
	profile.map_id="valley";profile.scenery=source;profile.sun=source.get_node("Sun");profile.atmosphere=source.get_node("Atmosphere").environment.duplicate(true)
	profile.update_lighting(.42)
	var sun: DirectionalLight3D=profile.sun.duplicate();profile.free();source.free();return sun
func capture() -> Image:
	for frame in range(4):await process_frame;RenderingServer.force_draw()
	return viewport.get_texture().get_image()
func head_rect(head: MeshInstance3D) -> Rect2:
	var rect:=Rect2()
	for i in range(8):
		var point:=camera.unproject_position(head.to_global(head.get_aabb().get_endpoint(i)))
		rect=Rect2(point,Vector2.ZERO) if i==0 else rect.expand(point)
	return rect
func measure(full: Image,reference: Image,rect: Rect2) -> Dictionary:
	var count_:=0;var affected:=0;var total:=0.
	var center:=rect.get_center();var radii:=rect.size*.45
	for y in range(maxi(0,int(rect.position.y)),mini(full.get_height(),int(rect.end.y))):
		for x in range(maxi(0,int(rect.position.x)),mini(full.get_width(),int(rect.end.x))):
			if ((Vector2(x,y)-center)/radii).length_squared()>1.:continue
			var color:=reference.get_pixel(x,y)
			if color.get_luminance()<.35 or maxf(absf(color.r-color.g),absf(color.g-color.b))>.15:continue
			var delta:=maxf(0.,color.get_luminance()-full.get_pixel(x,y).get_luminance())
			count_+=1;total+=delta
			if delta>.015:affected+=1
	return {"pixels":count_,"affected":affected/maxf(1.,count_),"mean":total/maxf(1.,count_)}
func run() -> void:
	Engine.max_fps=60
	viewport=SubViewport.new();viewport.size=Vector2i(1024,1024);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("87a4b4");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c6d9eb");env.environment.ambient_light_energy=.46;world.add_child(env)
	var sun:=valley_sun();world.add_child(sun)
	camera=Camera3D.new();world.add_child(camera);camera.fov=48;camera.current=true
	var out:=preload("res://tests/test_support.gd").output_dir();var results: Array=[]
	for species in ["sphere","bunny","cat_teacher","panda"]:
		var actor: Node3D=Node3D.new() if species=="sphere" else Animals.create(species);world.add_child(actor);actor.set_physics_process(false)
		var head: MeshInstance3D
		if species=="sphere":
			head=MeshInstance3D.new();head.mesh=SphereMesh.new();head.mesh.radius=.8;head.mesh.height=1.6;head.mesh.radial_segments=48;head.mesh.rings=24;head.position.y=1.8
			var material:=StandardMaterial3D.new();material.albedo_color=Color("f9f8f3");material.roughness=.94;material.metallic_specular=.18;head.material_override=material;actor.add_child(head)
		else:head=actor.get_node("Visual/Head/"+{"bunny":"RoundHead","cat_teacher":"RoundCatHead","panda":"PlushHead"}[species])
		# Isolate the actual convex skin geometry. Features/ears would add valid
		# cast shadows and prevent a clean reference for unwanted self-shadowing.
		for part in actor.find_children("*","MeshInstance3D",true,false):
			if part!=head:part.hide()
		for far in [false,true]:
			camera.position=Vector3(2.1,1.,3.2)*(3.5 if far else 1.)+Vector3(0,1.8,0);camera.look_at(Vector3(0,1.8,0))
			for rotation in [Vector3(-70,0,0),Vector3(-50,-20,0),Vector3(-25,-40,0)]:
				sun.rotation_degrees=rotation;head.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var reference: Image=await capture();head.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				var full: Image=await capture();var row:=measure(full,reference,head_rect(head));row.species=species;row.far=far;row.rotation=str(rotation);results.append(row)
				print("CURVED_SHADOW ",JSON.stringify(row))
				check(row.pixels>100,"Convex skin sample is visible: "+species+" "+str(far)+" "+str(rotation))
				check(row.affected<.006 and row.mean<.0003,"Convex skin stays free of shadow waves: "+species+" "+str(far)+" "+str(rotation))
				if not far and rotation==Vector3(-50,-20,0):full.save_png(out+"/"+species+".png")
		actor.queue_free();await process_frame
	# A touching box must still darken the ground beside its foot. This catches
	# excessive bias or a fix that simply disables cast/received shadows.
	var ground:=MeshInstance3D.new();ground.mesh=PlaneMesh.new();ground.mesh.size=Vector2(20,20);var material:=StandardMaterial3D.new();material.albedo_color=Color("9bb782");ground.material_override=material;world.add_child(ground)
	var box:=MeshInstance3D.new();box.mesh=BoxMesh.new();box.position.y=.5;world.add_child(box)
	sun.rotation_degrees=Vector3(-50,-20,0);camera.position=Vector3(4,5,-7);camera.look_at(Vector3.ZERO)
	box.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var unshadowed: Image=await capture()
	box.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;var shadowed: Image=await capture()
	var direction: Vector3=-sun.global_basis.z;direction.y=0;direction=direction.normalized()
	var edge:=.5/maxf(absf(direction.x),absf(direction.z))
	for gap in [.04,.25]:
		var pixel:=Vector2i(camera.unproject_position(direction*(edge+gap)))
		var delta:=unshadowed.get_pixelv(pixel).get_luminance()-shadowed.get_pixelv(pixel).get_luminance()
		print("SHADOW_CONTACT ",JSON.stringify({"gap_m":gap,"luminance_difference":delta}))
		check(delta>.06,"Real cast shadow stays attached to ground within "+str(gap)+"m")
	shadowed.save_png(out+"/contact.png")
	var report:=FileAccess.open(out+"/curved-shadow.json",FileAccess.WRITE);report.store_string(JSON.stringify({"bias":sun.shadow_bias,"normal_bias":sun.shadow_normal_bias,"samples":results},"\t"));report.close()
	viewport.queue_free();await process_frame
	print("CURVED_SHADOW_SURFACE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
