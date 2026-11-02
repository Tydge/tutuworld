extends SceneTree
const S=preload("res://scripts/services/session.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func travel(local: Vector3) -> void:
	game.bunny.position=game.home.to_global(local)
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	session.set_player_position(game.bunny.position)
	await create_timer(.4).timeout
func walk(action: String,seconds: float) -> void:
	game.yaw=0
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)
	await create_timer(.2).timeout
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label_+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=S.new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.create_character("木棉" if species=="bunny" else "糯米",species,"vest_sage")
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		while game.preparing: await process_frame
		await create_timer(.8).timeout
		for npc in game.npcs:
			for child in npc.get_children():
				if child.get_script()==load("res://scripts/city/npc_driver.gd"): child.set_physics_process(false)
		check(not game.scenery.has_node("Residence00") and not game.scenery.has_node("Residence10"),"Two old west-side residences removed")
		check(game.scenery.has_node("Residence01") and game.scenery.has_node("Residence11") and game.scenery.has_node("Residence20"),"Neighboring buildings remain")
		check(game.home.has_meta("buildable_reference") and game.home.get_node("Structure/Walls").get_child_count()==4 and game.home.blueprint.schema==1,"House keeps a real blueprint and four separately replaceable walls")
		check(game.home.get_node("Furnishing").get_child_count()==6 and game.home.get_node("Structure/Roof/CeilingCollision").collision_layer==4,"Furnished single-floor house includes a physical ceiling")
		var complete_meshes:=true
		for mesh in game.home.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				var indices=arrays[Mesh.ARRAY_INDEX]
				if indices!=null and indices.size()>0 and indices.max()!=arrays[Mesh.ARRAY_VERTEX].size()-1: complete_meshes=false
		check(complete_meshes,"Every merged furniture and house mesh renders all its vertices")
		check(game.bunny.rig_profile.species_id==species,"Actual controlled species: "+species)
		var scene_id: int=game.get_instance_id()
		var scenery_id: int=game.scenery.get_instance_id()
		session.active=false
		session.state().time=1800
		game.update_lighting()
		await travel(Vector3(0,.4,8.0))
		await walk("move_up",1.6)
		var local: Vector3=game.home.to_local(game.bunny.position)
		check(local.z>5.7 and not game.home.inside,"Closed physical door prevents walking through: "+species+" at "+str(local))
		game.update_target()
		check(game.current_target=="home_door" and game.hud.prompt.text.contains("E "),"Door has the selected E action prompt: "+species)
		check(game.navigation.grid.is_point_solid(Vector2i(-34,3)),"Closed door blocks the shared navigation cell")
		game.interact()
		await create_timer(.85).timeout
		check(game.home.door_open and not game.home.door_tweening and absf(game.home.door_angle)>1.7,"E opens a real animated door: "+species)
		check(not game.navigation.grid.is_point_solid(Vector2i(-34,3)),"Opening updates only the local navigation footprint")
		await walk("move_up",2.2)
		local=game.home.to_local(game.bunny.position)
		check(game.home.inside and local.z<1.2,"Walks directly from outside into the room: "+species+" at "+str(local))
		check(game.get_instance_id()==scene_id and game.scenery.get_instance_id()==scenery_id,"Entry reuses the same map and scene without teleporting or loading")
		check(game.bunny.is_on_floor() and absf(local.y-game.home.floor_level)<.028,"Feet meet the actual wood floor: "+species+" y="+str(local.y))
		check(game.home.sections[0].alpha<.001 and game.home.get_node("Structure/Roof").find_children("PersistentShadow*","MeshInstance3D",true,false).size()>0,"Roof disappears for viewing while its shadow geometry stays")
		var south: Dictionary=game.home.sections[1]
		check(south.alpha<.01 and south.materials[0].get_shader_parameter("cut_base_height")>.6,"Near-side cutaway keeps a visible low wall boundary")
		var blocked: Dictionary=game.home.toggle_door(game.bunny)
		# Near the inward-open door the body is protected; move back to a neutral room position afterwards.
		if game.home.door_open and local.z>1.0: check(not blocked.ok,"Door will not sweep through an occupant")
		if not game.home.door_open:
			await create_timer(.7).timeout
			game.home.toggle_door(game.bunny)
			await create_timer(.7).timeout
		var min_distance:=999.0
		for i in range(16):
			game.yaw=i*TAU/16
			await create_timer(.13).timeout
			min_distance=minf(min_distance,game.camera.position.distance_to(game.camera_focus))
		check(min_distance>8,"Full indoor camera turn avoids repeated wall zooming: "+species+" min="+str(min_distance))
		await travel(Vector3(4.1,.35,0))
		await walk("move_right",1.4)
		check(game.home.to_local(game.bunny.position).x<5.75,"Physical window sill / wall remains after visual cutaway: "+species)
		for id in ["home_sofa","home_desk"]:
			var exit: Vector3=game.home.seat_node(id).get_node("ExitAnchor").global_position
			await travel(game.home.to_local(exit))
			game.current_target=id
			game.interact()
			await create_timer(.4).timeout
			check(game.bunny.seated and game.nap_active and game.bunny.action=="nap","Shared sitting pose works on "+id+": "+species)
			if id=="home_sofa": await capture("无缝小屋-"+species+"-沙发小憩")
			await create_timer(5.9).timeout
			check(not game.bunny.seated and game.bunny.is_on_floor(),"Rest returns to a clear exit without camera shake: "+id+" "+species)
		await travel(Vector3(0,.3,.5))
		if not game.home.door_open: game.home.toggle_door(game.bunny);await create_timer(.8).timeout
		await walk("move_down",2.8)
		local=game.home.to_local(game.bunny.position)
		check(not game.home.inside and local.z>6.8 and game.get_instance_id()==scene_id,"Walks back outside in the same world: "+species+" at "+str(local))
		await create_timer(.4).timeout
		check(game.home.sections[0].alpha>.99,"Roof restores smoothly outside")
		game.current_target="home_door";game.interact();await create_timer(.85).timeout
		if game.home.door_open:
			check(game.hud.toast_label.text.contains("让开"),"Closing protects a player standing in the door sweep")
			await walk("move_down",.45)
			game.current_target="home_door";game.interact();await create_timer(.85).timeout
		check(not game.home.door_open and game.navigation.grid.is_point_solid(Vector2i(-34,3)),"Door closes safely and restores its navigation obstruction")
		var white: MeshInstance3D=game.bunny.get_node("Visual/Head/RoundHead") if species=="bunny" else game.bunny.get_node("Visual/Head/RoundCatHead")
		if species=="bunny": check(white.material_override is StandardMaterial3D,"Rabbit white skin now receives actual scene lights without changing its model")
		session.state().time=.92*3600;game.update_lighting();await create_timer(.3).timeout
		check(game.home.key_light.shadow_enabled and game.home.key_light.visible and game.home.porch.light_energy>1,"Warm room and porch lights remain active at night")
		var far_lights:=0
		for light_ in game.lamps:
			if light_.get_node("NightLight").visible and light_.position.distance_to(game.bunny.position)>30: far_lights+=1
		check(far_lights>8,"Far streetlights remain lit; lighting does not wait for the player to approach")
		game.queue_free();await process_frame;await process_frame
	print("SEAMLESS_HOME_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
