extends SceneTree
const Authority=preload("res://scripts/services/local_authority.gd")
var game: Node3D
var session: Node
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func travel(p: Vector3,yaw_: float,pitch_: float,distance_: float) -> void:
	game.bunny.position=p
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	session.set_player_position(p)
	game.yaw=yaw_
	game.pitch=pitch_
	game.distance_=distance_
	await create_timer(.7).timeout
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.authority=Authority.new()
		session.settings.player_species=species
		session.state().species=species;session.state().skill_experience.cooking=preload("res://scripts/services/character_stats.gd").skill_start(5)
		session.state().time=1650
		game=load("res://scenes/city.tscn").instantiate()
		root.add_child(game)
		await create_timer(.5).timeout
		session.active=false
		for id in ["carrot","lettuce","tomato","pumpkin","sea_salt","olive_oil","cream"]: session.authority.add(id,10)
		await travel(Vector3(24,.15,-17.5),.15,.45,16)
		game.hud.toast.hide()
		game.hud.visible=false
		await capture("厨房更新-厨房与餐桌-"+species)
		game.hud.visible=true
		await travel(Vector3(21,.15,-19.8),.75,.58,10)
		game.current_target="kitchen"
		game.interact()
		await create_timer(.4).timeout
		await capture("厨房更新-"+species+"-菜谱")
		game.hud.close_panel()
		session.active=true
		check(game.begin_cooking("pumpkin_soup" if species=="bunny" else "garden_salad").ok,"Art preview starts actual cooking: "+species)
		await create_timer(1.2).timeout
		await capture("厨房更新-"+species+"-料理台动作")
		game.cancel_action()
		session.active=false
		for food in ["food_carrot_soup","food_garden_salad","food_tomato_stew","food_pumpkin_soup"]: session.authority.add(food,1)
		await travel(Vector3(28.2,.15,-17.5),PI-.65,.42,7)
		game.current_target="dining"
		game.interact()
		await create_timer(.4).timeout
		await capture("厨房更新-"+species+"-餐桌菜单")
		game.hud.close_panel()
		for food in (["food_carrot_soup","food_pumpkin_soup"] if species=="bunny" else ["food_garden_salad","food_tomato_stew"]):
			await travel(Vector3(28.2,.15,-17.5),PI-.65,.47,6.8)
			session.active=true
			check(game.begin_dining(food).ok,"Art preview starts actual meal: "+species+" "+food)
			await create_timer(1.10).timeout
			var mouth_mesh: MeshInstance3D=game.bunny.mouth.get_child(0)
			var mouth_center: Vector3=game.bunny.head.to_local(mouth_mesh.to_global(mouth_mesh.get_aabb().get_center()))
			check(absf(mouth_center.y-game.bunny.mouth.position.y)<.035,"Chewing remains anchored on face: "+species)
			var bowl: Node3D=game.tools.prop.get_node("FoodContact")
			var distance_: float=bowl.global_position.distance_to(game.bunny.mouth.global_position)
			check(distance_<.14,"Utensil reaches mouth during bite: "+species+" distance="+str(distance_))
			await capture("厨房更新-"+species+"-餐桌-"+food)
			game.hud.visible=false
			await capture("厨房更新-"+species+"-用餐特写-"+food)
			game.hud.visible=true
			await create_timer(5.25).timeout
			check(session.job().is_empty() and not game.bunny.seated and session.state().food_effect.get("item","")==food,"Full seated meal completes after final alignment: "+species)
			if not session.job().is_empty(): game.cancel_action()
			session.active=false
		game.bunny.position=Vector3(25,.2,-17.3)
		game.bunny.reset_physics_interpolation()
		await create_timer(.3).timeout
		session.state().time=3300
		game.update_lighting()
		game.yaw=.1
		game.pitch=.4
		game.distance_=15
		game.hud.visible=false
		await create_timer(1).timeout
		await capture("厨房更新-夜间厨房-"+species)
		game.queue_free()
		await process_frame
		await process_frame
	print("KITCHEN_ART_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
