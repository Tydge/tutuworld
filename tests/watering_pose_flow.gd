extends SceneTree
const DB = preload("res://scripts/services/game_data.gd")
const Pour = preload("res://scripts/city/watering_pose.gd")
const Animals = preload("res://scripts/characters/animal_factory.gd")
var failures: Array[String] = []
var output := preload("res://tests/test_support.gd").output_dir()
var session: Node
var game: Node
var trials := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func trial(species: String, offset: Vector2, index: int) -> void:
	var center: Vector3=game.target_position("plot_19")
	var actor: CharacterBody3D=game.bunny
	actor.position=center+Vector3(offset.x,.14,offset.y)
	actor.velocity=Vector3.ZERO
	actor.reset_physics_interpolation()
	session.set_player_position(actor.position)
	var can_id: String="watering_can" if index%2==0 else "copper_watering_can"
	session.state().inventory.erase("copper_watering_can")
	session.state().inventory[can_id]=1
	session.state().watering_water[can_id]=3
	session.state().plots.plot_19={"crop":"tomato","growth":0.,"water_stage":-1,"weed_stage":-1}
	game.refresh_world()
	var result: Dictionary=game.begin_action("water","plot_19")
	var label_: String="%s/%s/%s"%[species,can_id,offset]
	check(result.ok,"Start "+label_)
	if not result.ok:return
	for i in 67: await physics_frame
	var tools: Node=game.tools
	tools._process(0.)
	check(tools.effects.visible and tools.splash.visible and not session.job().is_empty(),"Visible pour at "+label_)
	if session.job().is_empty():return
	var nozzle: Transform3D=tools.prop.get_node("Outlet").get_global_transform_interpolated()
	for side in ["R","L"]:
		var grip: Vector3=actor.rig_profile.grip_offset
		if side=="L":grip.x=-grip.x
		var arm: Node3D=actor.right_arm if side=="R" else actor.left_arm
		check(arm.to_global(grip).distance_to(tools.prop.get_node("Grip"+side).global_position)<.025,"Palm holds handle "+side+" "+label_)
	for i in tools.streams.size():
		var material: ShaderMaterial=tools.streams[i].material_override
		var source: Vector3=material.get_shader_parameter("start")
		var end: Vector3=material.get_shader_parameter("finish")
		var fall: float=material.get_shader_parameter("fall")
		var hole: Vector2=Pour.HOLES[i]
		var axis:=Pour.velocity(nozzle.basis,hole).normalized()
		var tangent:=(end-source+Vector3.UP*fall).normalized()
		check(source.distance_to(nozzle*Vector3(hole.x,hole.y,0))<.008,"Jet starts at rose perforation "+label_)
		check(axis.dot(tangent)>.998 and tangent.y<-.20,"Jet follows tilted nozzle "+label_)
		check(maxf(absf(end.x-center.x),absf(end.z-center.z))<.91 and end.y<.16 and end.y>.035,"Drops reach soil inside chosen plot "+label_)
	if index==2 and DisplayServer.get_name()!="headless":
		game.hud.hide()
		game.set_process(false)
		game.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var forward: Vector3=actor.visual.global_basis.z
		var focus: Vector3=actor.position+Vector3.UP*.88+forward*.47
		game.camera.position=focus+actor.visual.global_basis*Vector3(2.9,1.25,2.3)
		game.camera.look_at(focus)
		game.camera.reset_physics_interpolation()
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(output+"/pour-"+species+".png")
		game.set_process(true)
	session._process(float(session.job().duration))
	check(session.job().is_empty() and session.authority.water_left()==2 and not tools.effects.visible,"Finish, debit one charge and stop effects "+label_)
	trials+=1

func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,800)
	session=preload("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	for species in Animals.Catalog.ids():
		session.create_character("菜园"+species,species,"bow_rose")
		game=preload("res://scenes/city.tscn").instantiate()
		root.add_child(game)
		game.update_lighting(.46)
		for i in 4:await physics_frame
		var angles: Array[Vector2]=[Vector2.ZERO,Vector2(.27,-.13),Vector2(-1.18,1.12),Vector2(0,-1.9),Vector2(3.15,.47)]
		for i in angles.size():await trial(species,angles[i],i)
		game.free()
		await physics_frame
	print("WATERING_POSE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," trials=",trials," failures=",failures)
	quit(0 if failures.is_empty() else 1)
