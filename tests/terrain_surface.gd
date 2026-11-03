extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("地面验收兔","bunny","bow_rose")
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null:await process_frame
	await create_timer(.5).timeout;session.set_process(false);game.set_process(false);game.bunny.can_move=false
	var scenery: Node3D=game.scenery
	check(scenery.get_meta("street_surface_revision",0)==2,"Latest continuous road surface is loaded")
	check(scenery.get_meta("terrain_material_revision",0)==1,"Latest shared terrain materials are loaded")
	# Raycast both sides of former road divisions, including two crossroads.
	for point in [Vector3(3.1,0,20),Vector3(3.6,0,20),Vector3(0,0,13),Vector3(3.4,0,13),Vector3(0,0,-19),Vector3(3.4,0,-19)]:
		var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP,8)
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y-.047)<.005,"Former curb and road junction are level: "+str(point))
	for species in Animals.Catalog.ids():
		var actor=Animals.create(species);game.add_child(actor);actor.set_physics_process(false)
		for route in [[Vector3(2.8,.08,20),Vector3(3.55,.08,20)],[Vector3(2.7,.08,13),Vector3(5,.08,13)],[Vector3(2.7,.08,-19),Vector3(5,.08,-19)]]:
			actor.position=route[0];actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
			var reached:=false
			for i in range(100):
				await physics_frame
				var direction: Vector3=route[1]-actor.position;direction.y=0
				if direction.length()<.12:reached=true;break
				actor.velocity.x=direction.normalized().x*2.8;actor.velocity.z=direction.normalized().z*2.8
				actor.velocity.y=-.2 if actor.is_on_floor() else actor.velocity.y-18./Engine.physics_ticks_per_second
				actor.move_on_ground(1./Engine.physics_ticks_per_second)
			check(reached,"Walk across former road divider without jumping: "+species+" "+str(route[1]))
		actor.queue_free();await process_frame
	var beds:=scenery.find_children("PlazaFlowerbed*","Node3D",true,false)
	check(beds.size()==4,"Four plaza flowerbeds replace the former flat disks")
	if beds.size()==4:
		check(beds[0].get_node("MixedFlowersAndLeaves").mesh==beds[3].get_node("MixedFlowersAndLeaves").mesh,"Flowerbeds share geometry instead of duplicating meshes")
		var bed: Node3D=beds[0];var collision: Node3D=bed.get_node("FlowerbedCollision");var position_: Vector3=collision.global_position
		bed.position.x+=.7;bed.rotation.y+=.4
		check(absf(collision.global_position.x-position_.x-.7)<.001,"Moving a flowerbed also moves its collision")
		bed.position.x-=.7;bed.rotation.y-=.4
		check(bed.get_node("PlantingSoil").material_override.get_shader_parameter("soil_texture").resource_path=="res://assets/terrain/cultivated_soil_v1.png","Flowerbed uses actual soil instead of a green disk")
	for id in ["spring_lawn_v1","packed_earth_path_v1","cultivated_soil_v1","village_stone_paving_v1"]:
		var settings:=ConfigFile.new();settings.load("res://assets/terrain/"+id+".png.import")
		check(settings.get_value("params","compress/mode",0)==2 and not settings.get_value("params","compress/high_quality",true) and settings.get_value("params","mipmaps/generate",false),"Supported VRAM compression and mipmaps: "+id)
	game.process_mode=Node.PROCESS_MODE_DISABLED;game.hud.hide();root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080)
	var out: String=preload("res://tests/test_support.gd").output_dir()+"/"
	game.bunny.position=Vector3(0,.15,9);game.bunny.reset_physics_interpolation();game.camera.position=Vector3(4,7,22);game.camera.look_at(Vector3(0,.7,-7));game.update_lighting(.5)
	for i in range(25):await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"continuous-stone-roads.png")
	game.bunny.position=Vector3(5,.15,9);game.bunny.reset_physics_interpolation();game.camera.position=Vector3(11,3.5,12);game.camera.look_at(Vector3(8,.55,7))
	for i in range(25):await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"plaza-flowerbed.png")
	print("TERRAIN_SURFACE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
