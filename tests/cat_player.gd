extends SceneTree
var game: Node3D
var session: Node
var failures: Array[String]=[]
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	session.settings.player_species="cat_teacher"
	session.authority.state.player_position=[0,.1,13]
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(1).timeout
	check(game.bunny.rig_profile.species_id=="cat_teacher","Cat can be instantiated as the controlled player")
	check(game.get_node("CatTeacher")!=game.bunny,"Cat NPC and cat player have independent identities")
	var start: Vector3=game.bunny.position
	Input.action_press("move_right")
	Input.action_press("sprint")
	await create_timer(.9).timeout
	check(game.bunny.position.distance_to(start)>3.0 and game.bunny.walking,"Shared player controls run the biped cat")
	await capture("猫主角-共用走跑")
	Input.action_release("move_right")
	Input.action_release("sprint")
	game.bunny.position=Vector3(22,.1,-4.2)
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	await create_timer(.4).timeout
	var seeds: int=session.authority.count("seed_carrot")
	var result: Dictionary=game.begin_action("plant","plot_00","seed_carrot")
	check(result.ok,"Cat uses the same planting command")
	await create_timer(.4).timeout
	check(game.hud.ring.visible and game.tools.verb=="plant","Cat uses the same progress ring and held item")
	await capture("猫主角-共用种植")
	await create_timer(1.9).timeout
	check(session.state().plots.plot_00.crop=="carrot" and session.authority.count("seed_carrot")==seeds-1,"Cat finishes planting with shared inventory rules")
	session.authority.state.inventory.watering_can=1
	result=game.begin_action("water","plot_00")
	check(result.ok,"Cat uses the same watering command")
	await create_timer(.5).timeout
	await capture("猫主角-共用浇水")
	await create_timer(1.8).timeout
	check(session.authority.count("watering_can")==1 and session.job().is_empty(),"Cat watering preserves the permanent tool")
	game.bunny.position=Vector3(0,.1,9)
	game.bunny.reset_physics_interpolation()
	var teacher: CharacterBody3D=game.get_node("CatTeacher")
	teacher.position=Vector3(1.9,.1,9.8)
	teacher.reset_physics_interpolation()
	game.current_target="CatTeacher"
	game.interact()
	await create_timer(.6).timeout
	await capture("猫咪老师-NPC与猫主角")
	print("CAT_PLAYER_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
