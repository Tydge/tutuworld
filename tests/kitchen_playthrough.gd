extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
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
	if OS.get_cmdline_user_args().has("--no-capture"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func travel(p: Vector3) -> void:
	game.bunny.position=p
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	session.set_player_position(p)
	await create_timer(.5).timeout
func watch_job() -> Dictionary:
	var low:=100.0
	var high:=-100.0
	var frames:=0
	var deadline:=Time.get_ticks_msec()+15000
	while not session.job().is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame
		low=minf(low,game.bunny.right_arm.rotation.x)
		high=maxf(high,game.bunny.right_arm.rotation.x)
		frames+=1
	return {"range":high-low,"finished":session.job().is_empty()}
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.authority=Authority.new()
		session.settings.player_species=species
		game=load("res://scenes/city.tscn").instantiate()
		root.add_child(game)
		await create_timer(.7).timeout
		check(game.bunny.rig_profile.species_id==species,"Active controlled species: "+species)
		check(game.scenery.has_node("Kitchen") and not game.scenery.has_node("Bakery"),"Kitchen replaces bakery: "+species)
		check(game.bunny.collision_mask&2!=0,"Player and NPC collision layer enabled: "+species)
		if species=="cat_teacher": check(game.bunny.has_node("Visual/Tail/RoundTail"),"Cat has a spherical white tail")
		await travel(Vector3(1,.3,9))
		check(game.bunny.position.y>=.109 and game.bunny.position.y<.14,"Feet meet plaza paving instead of underlying ground: "+species)
		game.yaw=PI
		game.pitch=.20
		game.distance_=5
		game.bunny.visual.rotation.y=PI
		await create_timer(.5).timeout
		await capture("厨房更新-"+species+"-脚底落地")
		# Walk from lower grass onto the raised stone road, rather than getting stuck on the edge.
		await travel(Vector3(7,.2,21))
		game.yaw=0
		Input.action_press("move_left")
		await create_timer(1.55).timeout
		Input.action_release("move_left")
		await create_timer(.3).timeout
		check(game.bunny.position.x<3.2 and game.bunny.position.y>=.045,"Walks up curb onto road without sinking: "+species)
		# Both E and F must use the currently floating marked plot.
		session.active=false
		session.authority.state.plots.plot_00={"crop":"carrot","growth":0.0,"water_stage":-1,"weed_stage":0}
		session.authority.add("watering_can",1)
		game.refresh_world()
		await travel(Vector3(23.5,.15,-5.4))
		game.update_target()
		check(game.current_target=="plot_01" and game.find_quick_action().is_empty(),"Empty selected bed does not redirect F to neighboring crop: "+species)
		await travel(Vector3(22.4,.15,-6.2))
		game.update_target()
		check(game.find_quick_action().get("target","")==game.current_target,"Marked crop is the sole quick target: "+species)
		check(game.quick_interact().ok and session.job().target==game.current_target,"F dispatches same target: "+species)
		game.cancel_action()
		for crop in ["carrot","lettuce","tomato","pumpkin"]: session.authority.add(crop,10)
		for id in ["sea_salt","olive_oil","cream"]: session.authority.add(id,10)
		session.active=true
		var dishes: Array=["carrot_soup","pumpkin_soup"] if species=="bunny" else ["garden_salad","tomato_stew"]
		for id in dishes:
			var recipe:=DB.recipe(id)
			await travel(Vector3(21,.2,-19.6))
			game.current_target="kitchen"
			game.interact()
			check(game.hud.mode=="kitchen","E opens recipe cards: "+species+" "+id)
			game.yaw=.85
			game.pitch=.68
			game.distance_=9
			if id==dishes[0]: await capture("厨房更新-"+species+"-菜谱")
			var button: Button
			for candidate in game.hud.content.find_children("*","Button",true,false):
				if candidate.get_meta("recipe","")==id: button=candidate
			check(button!=null and not button.disabled,"Ingredient counts enable recipe: "+id)
			var started:=Time.get_ticks_msec()
			button.pressed.emit()
			check(session.job().get("verb","")=="craft" and game.bunny.action=="cook","Recipe button starts shared cook action: "+species+" "+id)
			await create_timer(1.0).timeout
			check(game.tools.verb=="cook" and game.culinary.steam.visible and game.hud.ring.visible,"Spoon, steam and timed ring active: "+species)
			await capture("厨房更新-"+species+"-烹饪-"+id)
			var motion:=await watch_job()
			check(motion.finished and motion.range>.15,"Stirring animates through completion: "+species+" "+id)
			check(Time.get_ticks_msec()-started>=int(recipe.seconds*1000)-120 and session.authority.count(recipe.output)==1,"Real cooking duration yields exactly one meal: "+id)
			await travel(Vector3(28.2,.2,-17.5))
			game.yaw=PI-.65
			game.pitch=.43
			game.distance_=8.2
			game.current_target="dining"
			game.interact()
			check(game.hud.mode=="dining","Table opens food selection: "+species)
			game.hud.close_panel()
			check(game.begin_dining(recipe.output).ok,"Begin seated meal: "+species+" "+id)
			await create_timer(1.1).timeout
			check(game.bunny.seated and game.dining_active and is_instance_valid(game.culinary.meal),"Food served and actor sits on the chair: "+species)
			check(game.bunny.left_leg.rotation.x<-.8 and game.tools.verb=="eat","Shared sitting legs and eating spoon: "+species)
			var start: Vector3=game.bunny.position
			await capture("厨房更新-"+species+"-用餐-"+id)
			var eating:=await watch_job()
			check(eating.finished and eating.range>.8,"Eating arm moves for this species: "+species)
			check(not game.bunny.seated and not game.dining_active and not is_instance_valid(game.culinary.meal),"Meal completion clears plate and stands safely: "+species)
			check(session.authority.count(recipe.output)==0 and session.state().food_effect.item==recipe.output,"Meal consumed once and matching buff applied: "+species+" "+id)
			await create_timer(.6).timeout
			check(game.hud.buff_icon.visible and game.hud.buff_icon.description.contains(recipe.effect_text),"Food effect HUD visible: "+species)
			await capture("厨房更新-"+species+"-美味记忆")
		# Mid-meal cancellation preserves food, ends seated state and clears props.
		session.authority.add("food_carrot_soup",1)
		await travel(Vector3(28.2,.2,-17.5))
		game.begin_dining("food_carrot_soup")
		await create_timer(.7).timeout
		game.cancel_action()
		check(session.authority.count("food_carrot_soup")==1 and not game.bunny.seated and not is_instance_valid(game.culinary.meal),"Cancel meal returns safely without charging food: "+species)
		# Exercise the remaining work actions with both bodies, not only the new poses.
		session.state().food_effect={}
		session.active=true
		session.state().plots.plot_02=session.authority.empty_plot()
		session.authority.add("seed_carrot",1)
		session.authority.add("herbicide",1)
		await travel(Vector3(26.5,.2,-4.5))
		for verb in ["plant","water","weed","harvest"]:
			if verb=="weed":
				session.state().plots.plot_02.growth=1200
				session.state().plots.plot_02.water_stage=1
			if verb=="harvest": session.state().plots.plot_02.growth=3600
			game.refresh_world()
			check(game.begin_action(verb,"plot_02","seed_carrot" if verb=="plant" else "").ok,"Start shared garden action: "+species+" "+verb)
			await create_timer(.4).timeout
			check(game.bunny.action==verb and game.hud.ring.visible,"Garden pose and progress active: "+species+" "+verb)
			await watch_job()
		check(session.state().plots.plot_02.crop=="" and session.authority.count("watering_can")==1,"Garden cycle finishes and retains can: "+species)
		for resource in DB.resources().slice(0,3):
			var tool: String=DB.item(resource.item).get("tool","")
			if tool!="": session.authority.add(tool,1)
			await travel(Vector3(resource.x,.2,resource.z+1.4))
			check(game.begin_action("gather",resource.id).ok,"Start shared gathering: "+species+" "+resource.item)
			await create_timer(.4).timeout
			check(game.bunny.action.begins_with("gather_") and game.hud.ring.visible,"Gather pose and ring active: "+species+" "+resource.item)
			if resource.item=="copper": await capture("厨房更新-"+species+"-采矿动作")
			await watch_job()
			check(session.authority.count(resource.item)>0 and (tool=="" or session.authority.count(tool)==1),"Gather material gained, tool retained: "+species+" "+resource.item)
		# Move bonus measured through real shared player controls on an unobstructed street.
		session.active=false
		session.state().food_effect={}
		await travel(Vector3(0,.15,24))
		game.yaw=0
		var z: float=game.bunny.position.z
		Input.action_press("move_down")
		await create_timer(1.5).timeout
		Input.action_release("move_down")
		var normal: float=game.bunny.position.z-z
		await create_timer(.2).timeout
		session.state().food_effect={"item":"food_carrot_soup","expires_at":session.state().time+3600}
		await travel(Vector3(0,.15,24))
		z=game.bunny.position.z
		Input.action_press("move_down")
		await create_timer(1.5).timeout
		Input.action_release("move_down")
		var faster: float=game.bunny.position.z-z
		check(faster>normal*1.10,"Movement food increases measured travel distance: "+species)
		# Buff survives save/reload; a legacy save with no food_effect loads safely.
		session.test_mode=false
		session.save_path="user://qa_kitchen_%s.json"%species
		check(session.save_game(),"Save food effect: "+species)
		var restored=load("res://scripts/services/session.gd").new()
		restored.save_path=session.save_path
		restored.load_save()
		check(restored.authority.multiplier("move")>1,"Reload food effect: "+species)
		restored.free()
		DirAccess.remove_absolute(session.save_path)
		DirAccess.remove_absolute(session.save_path+".bak")
		session.test_mode=true
		game.queue_free()
		await process_frame
		await process_frame
	print("KITCHEN_PLAYTHROUGH_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
