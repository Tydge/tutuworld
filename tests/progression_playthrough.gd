extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const A=preload("res://scripts/services/local_authority.gd")
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func travel(p: Vector3) -> void:
	game.bunny.position=p
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	session.set_player_position(p)
	await create_timer(.4).timeout
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func button_with(key: String,value: String) -> Button:
	for node in game.hud.content.find_children("*","Button",true,false):
		if node.get_meta(key,"")==value: return node
	return null
func shown_items() -> Array[String]:
	var ids: Array[String]=[]
	for node in game.hud.content.find_children("*","PanelContainer",true,false):
		if node.has_meta("item_id"): ids.append(node.get_meta("item_id"))
	return ids
func shift() -> void:
	Input.action_press("sprint")
	await create_timer(.07).timeout
	Input.action_release("sprint")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.authority=A.new()
		session.settings.player_species=species
		session.state().coins=4000
		game=load("res://scenes/city.tscn").instantiate()
		root.add_child(game)
		await create_timer(1).timeout
		session.active=false
		check(game.navigation.ready_for_paths,"Shared obstacle grid ready: "+species)
		var detour: PackedVector3Array=game.navigation.path_between(Vector3(-5.8,0,8),Vector3(-5.8,0,13))
		check(detour.size()>2 and Array(detour).any(func(p): return absf(p.x+5.8)>2),"Path detours around welcome sign: "+species)
		var npc: CharacterBody3D=game.get_node("Passerby0" if species=="bunny" else "CatTeacher")
		var driver: Node
		for other in game.npcs:
			for child in other.get_children():
				if child.get_script()==load("res://scripts/city/npc_driver.gd"):
					if other==npc: driver=child
					else: child.set_physics_process(false)
			if other!=npc: other.position=Vector3(-38+game.npcs.find(other)*2,.2,34)
		npc.position=Vector3(-5.8,.15,11.6)
		npc.velocity=Vector3.ZERO
		npc.reset_physics_interpolation()
		driver.path=PackedVector3Array([Vector3(-5.8,0,8)])
		driver.path_index=0
		driver.wait=0
		driver.cooldown=0
		var initial: Vector3=npc.position
		await create_timer(5.5).timeout
		check(driver.recovery_count>0,"Wall contact triggers recovery and fresh route: "+species)
		check(npc.position.distance_to(initial)>1.2 and driver.repath_count>1,"NPC leaves the wall without teleporting: "+species+" at "+str(npc.position))
		# Cosmetic setup is restored for the real merchant checks.
		var farm: Node3D=game.get_node("Merchant_farm")
		check(farm.get_meta("equipment").body=="apron_sage","Seed merchant wears the new apron")
		check(game.get_node("Merchant_tools").get_meta("equipment").head=="beret_plaid_honey","One existing beret wearer uses tartan")
		await travel(Vector3(6,.2,-20))
		for id in DB.catalog().items:
			if id.begins_with("beret_plaid_") or id.begins_with("apron_"):
				check(session.dispatch("buy",{"shop":"clothes","item":id}).ok,"New clothing purchasable: "+species+" "+id)
		session.authority.add("sea_salt",3)
		session.authority.add("carrot",2)
		game.hud.shop="clothes"
		game.hud.filters.shop_clothes_buy="head"
		game.hud.open_panel("shop")
		await create_timer(.3).timeout
		check(shown_items().all(func(id): return DB.item(id).slot=="head") and shown_items().has("beret_plaid_rose"),"Shop category shows only headwear: "+species)
		game.hud.close_panel()
		session.dispatch("equip",{"slot":"head","item":"beret_plaid_rose"})
		session.dispatch("equip",{"slot":"body","item":"apron_sage"})
		game.hud.filters.wardrobe="head"
		game.hud.open_panel("wardrobe")
		await create_timer(.3).timeout
		var worn:=button_with("equipment_item","beret_plaid_rose")
		check(worn!=null and worn.text=="已穿戴" and not worn.disabled,"Worn item button remains clickable: "+species)
		worn.pressed.emit()
		await create_timer(.15).timeout
		check(session.state().equipment.head=="" and session.authority.count("beret_plaid_rose")==1,"Clicking worn item unequips without losing it: "+species)
		button_with("equipment_item","beret_plaid_rose").pressed.emit()
		await create_timer(.15).timeout
		check(session.state().equipment.head=="beret_plaid_rose","The same button equips again: "+species)
		button_with("category_filter","body").pressed.emit()
		await create_timer(.2).timeout
		check(shown_items().size()==3 and shown_items().all(func(id): return DB.item(id).slot=="body"),"Wardrobe body filter contains new owned aprons: "+species)
		await capture("成长验证-"+species+"-围裙分类")
		game.hud.close_panel()
		game.hud.filters.bag="ingredient"
		game.hud.open_panel("bag")
		await create_timer(.2).timeout
		check(shown_items()==["sea_salt"],"Bag category hides unrelated inventory: "+species)
		game.hud.close_panel()
		session.state().food_effect={"item":"food_carrot_soup","expires_at":session.state().time+1800}
		session.changed.emit()
		check(game.hud.buff_icon.visible and absf(game.hud.buff_icon.progress-.5)<.001,"Buff ring represents remaining duration: "+species)
		check(game.hud.coin_label.get_parent().get_child_count()==2,"Right HUD contains time and coins, no buff text")
		Input.warp_mouse(Vector2(60,60))
		var hover:=InputEventMouseMotion.new()
		hover.position=Vector2(60,60)
		root.push_input(hover)
		await create_timer(.4).timeout
		check(game.hud.buff_icon.details.visible and game.hud.buff_icon.description.contains("15%"),"Hover shows the in-game buff description: "+species)
		await capture("成长验证-"+species+"-Buff悬浮")
		Input.warp_mouse(Vector2(1000,700))
		# One real work action gains one XP; profile presents the actual worn model.
		session.state().plots.plot_00={"crop":"carrot","growth":0.0,"water_stage":-1,"weed_stage":0}
		session.authority.add("watering_can",1)
		await travel(Vector3(22,.2,-4.5))
		session.active=true
		check(game.begin_action("water","plot_00").ok,"Start real XP-bearing work: "+species)
		await create_timer(2.2).timeout
		check(session.state().experience==1,"Exactly one XP awarded for real completion: "+species)
		game.hud.open_panel("profile")
		await create_timer(.5).timeout
		check(game.hud.character_sheet.experience.text.contains("1"),"Character panel displays experience: "+species)
		check(game.hud.character_sheet.preview.actor.rig_profile.species_id==species,"Portrait uses the selected species: "+species)
		check(game.hud.character_sheet.preview.actor.has_node("Visual/Wardrobe_body"),"Portrait includes currently equipped clothing: "+species)
		check(game.hud.character_sheet.values.move.text=="+15%" and game.hud.character_sheet.values.stamina_capacity.text=="+0%","Attribute panel aggregates active modifiers without formulas: "+species)
		await capture("成长验证-"+species+"-属性")
		game.hud.character_sheet.pages.current_tab=1
		await create_timer(.2).timeout
		var skills: Array=game.hud.character_sheet.find_children("*","Label",true,false).filter(func(label_): return label_.has_meta("skill"))
		check(skills.size()==5 and skills.all(func(label_): return label_.text.begins_with("Lv.")),"Five skill levels render: "+species)
		game.hud.close_panel()
		var portrait_id: int=game.hud.character_sheet.preview.get_instance_id()
		game.hud.open_panel("wardrobe")
		session.dispatch("equip",{"slot":"body","item":"apron_rose"})
		game.hud.close_panel()
		game.hud.open_panel("profile")
		await create_timer(.2).timeout
		check(game.hud.character_sheet.preview.get_instance_id()==portrait_id,"Preview render world survives menu switching: "+species)
		var apron_material: ShaderMaterial=game.hud.character_sheet.preview.actor.get_node("Visual/Wardrobe_body/ApronCloth").material_override
		check(apron_material.get_shader_parameter("dye")==Color(DB.item("apron_rose").color),"Cached portrait refreshes newly equipped clothing: "+species)
		game.hud.close_panel()
		session.dispatch("equip",{"slot":"body","item":"apron_sage"})
		var hat:=Fabric.material(DB.item("beret_plaid_rose"))
		var scarf:=Fabric.material(DB.item("scarf_red"))
		check(hat.get_shader_parameter("fabric_mask")==scarf.get_shader_parameter("fabric_mask"),"Hat and scarf reuse one texture resource")
		var recolored:=Fabric.material(DB.item("beret_plaid_sage"))
		check(hat.shader==recolored.shader and hat.get_shader_parameter("dye")!=recolored.get_shader_parameter("dye"),"Color changes independently of texture and shader")
		# Shift press / release is a toggle, not a hold requirement.
		session.state().food_effect={}
		session.state().stamina=100
		game.bunny.run_enabled=false
		await travel(Vector3(0,.2,24))
		game.yaw=0
		Input.action_press("move_down")
		await create_timer(.4).timeout
		var phase: float=game.bunny.step_phase
		await create_timer(.8).timeout
		var walking_rate: float=(game.bunny.step_phase-phase)/.8
		await shift()
		await create_timer(.6).timeout
		check(game.bunny.run_enabled and game.bunny.is_running and not Input.is_action_pressed("sprint"),"Running persists after releasing Shift: "+species)
		phase=game.bunny.step_phase
		var run_start: float=session.state().stamina
		await create_timer(.8).timeout
		var run_rate: float=(game.bunny.step_phase-phase)/.8
		check(run_rate>walking_rate and run_rate<walking_rate*1.26,"Run cadence is only modestly faster: "+species+" rates="+str([walking_rate,run_rate]))
		check(session.state().stamina<=run_start and session.state().stamina>=run_start-1 and game.hud.stamina_meter.visible,"Real running drains stamina and shows meter: "+species)
		await shift()
		await create_timer(.25).timeout
		check(not game.bunny.run_enabled and not game.bunny.is_running,"Second Shift press returns to walk: "+species)
		await shift()
		await create_timer(.15).timeout
		session.state().stamina=0
		await create_timer(.25).timeout
		check(not game.bunny.run_enabled and not game.bunny.is_running,"Exhaustion automatically returns to walking: "+species)
		Input.action_release("move_down")
		session.active=false
		session.authority.running=false
		session.state().stamina=0
		session.state().stamina_recovery_elapsed=0
		session.authority.tick(15)
		check(session.state().stamina==0,"Fifteen seconds keep an incomplete recovery interval: "+species)
		session.authority.tick(15)
		await create_timer(.6).timeout
		check(session.state().stamina==1 and game.hud.stamina_meter.visible,"Thirty seconds recover one point in the status meter: "+species)
		# New progression fields persist; older saves retain their inventory with fresh defaults.
		session.state().attributes.move=.2
		session.state().stamina=42
		session.test_mode=false
		session.save_path="user://qa_progress_%s.json"%species
		check(session.save_game(),"Progression saves atomically: "+species)
		var restored=load("res://scripts/services/session.gd").new()
		restored.save_path=session.save_path
		restored.load_save()
		check(restored.state().experience==1 and absf(restored.state().stamina-42)<.2 and restored.authority.bonus("move")==.2,"XP, stamina and attributes survive reload: "+species)
		restored.free()
		var raw={"schema":2,"saved_at":Time.get_unix_time_from_system(),"state":session.snapshot(),"settings":session.settings.duplicate()}
		for key in ["experience","stamina","attributes","skills","skill_experience"]: raw.state.erase(key)
		var file:=FileAccess.open(session.save_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(raw)); file.close()
		restored=load("res://scripts/services/session.gd").new()
		restored.save_path=session.save_path
		restored.load_save()
		check(restored.state().experience==0 and restored.state().stamina==100 and restored.state().equipment.body=="apron_sage","Legacy save migrates without losing equipment: "+species)
		restored.free()
		DirAccess.remove_absolute(session.save_path)
		DirAccess.remove_absolute(session.save_path+".bak")
		session.test_mode=true
		game.queue_free()
		await process_frame
		await process_frame
	print("PROGRESSION_PLAYTHROUGH_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
