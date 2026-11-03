extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const G=preload("res://scripts/geometry.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1600,1000);Engine.max_fps=30
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("dfe8dc");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.55;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
	var floor_:=G.solid_box(stage,Vector3(0,-.10,0),Vector3(12,.20,5));floor_.collision_layer=8
	G.box(stage,Vector3(0,-.055,0),Vector3(12,.10,5),G.mat("c7d8b9"))
	var actors: Array=[]
	for species in Animals.Catalog.ids():
		var actor:=Animals.create(species);stage.add_child(actor);actor.set_physics_process(false);actor.position=Vector3(-2.4+actors.size()*2.4,.06,0);actors.append(actor)
		for frame in range(12):
			await physics_frame;actor.velocity=Vector3(0,-1,0);actor.move_on_ground(1.0/60)
		Outfit.apply(actor,{"body":"overalls_sage"})
		for limb_name in ["LeftLeg","RightLeg"]:
			var leg: Node3D=actor.get_node("Visual/"+limb_name)
			var trouser: MeshInstance3D=leg.get_node("Wardrobe_body_leg/TrouserLeg")
			check(trouser.mesh is ArrayMesh,"Clean cuff mesh attached to moving leg: "+species+" "+limb_name)
			var vertices: PackedVector3Array=trouser.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var axis: Vector3=actor.rig_profile.leg_end.normalized();var minimum:=100.0
			for point in vertices:
				var radial: float=(point-axis*point.dot(axis)).length();minimum=minf(minimum,radial)
			check(minimum>actor.rig_profile.leg_radius+.005,"Cloth stays outside the black/white leg surface: "+species)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.9;camera.position=Vector3(0,2.5,12);stage.add_child(camera);camera.look_at(Vector3(0,1.4,0));camera.current=true
	for pose in ["站立","走路","跑步"]:
		for actor in actors:
			actor.walking=pose!="站立";actor.velocity=Vector3(0,0,4.76 if pose=="跑步" else 2.8);actor.step_phase=1.10
			for i in range(30): actor.animate_pose(1.0/60)
			check(actor.get_node("Visual/LeftLeg/Wardrobe_body_leg").get_parent()==actor.left_leg,"Cuff follows the shared animated leg: "+actor.rig_profile.species_id+" "+pose)
		await create_timer(.15).timeout
		for frame in range(3):await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/裤腿修正-三角色-"+pose+".png")
	check(Outfit.trouser_meshes.size()==3,"Cuff geometry is cached once per species and reused")
	print("TROUSER_COMPATIBILITY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	stage.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
