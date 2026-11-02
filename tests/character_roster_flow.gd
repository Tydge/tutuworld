extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func button_in(node: Node,key: String,value: String) -> Button:
	for button in node.find_children("*","Button",true,false):
		if button.get_meta(key,"")==value: return button
	return null
func title_ready() -> Node:
	while current_scene==null or not current_scene.get("characters_ready"): await process_frame
	return current_scene
func wait_city(previous: Node) -> Node:
	while current_scene==null or (is_instance_valid(previous) and current_scene==previous): await process_frame
	var game: Node=current_scene
	while game.preparing: await process_frame
	await create_timer(.35).timeout
	return game
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label_+".png")
func travel(game: Node,p: Vector3) -> void:
	game.bunny.position=p
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	session.set_player_position(p)
	await create_timer(.3).timeout
func run() -> void:
	root.size=Vector2i(1440,900)
	session=S.new()
	session.name="Session"
	root.add_child(session)
	var title=load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	await title_ready()
	var first_id:=""
	var cat_id:=""
	for species in ["bunny","cat_teacher"]:
		title=await title_ready()
		check(title.start_button.text=="开始游戏" and not title.start_button.disabled,"Title enables start after cached character previews are ready")
		title.start_button.pressed.emit()
		var menu: Control=title.character_menu
		check(menu.visible and (menu.mode=="create" if first_id=="" else menu.mode=="choose"),"Start opens character selection / creation")
		if menu.mode=="choose":
			check(session.characters.size()==1,"Existing rabbit appears without a second phantom character")
			menu.begin_create()
		check(menu.primary.disabled,"Creation requires a name")
		menu.name_input.text="软糖" if species=="bunny" else "团子"
		menu.name_input.text_changed.emit(menu.name_input.text)
		button_in(menu,"species_id",species).pressed.emit()
		check(menu.draft_name==("软糖" if species=="bunny" else "团子") and menu.preview.actor.rig_profile.species_id==species,"Model switching preserves the typed name and shows the actual species")
		for slot in ["head","neck","body"]:
			button_in(menu,"starter_category",slot).pressed.emit()
			check(menu.clothing_grid.get_child_count()==3,"Three basic choices in "+slot+" for "+species)
		var starter: String="vest_sage" if species=="bunny" else "scarf_blue"
		button_in(menu,"starter_category",DB.item(starter).slot).pressed.emit()
		button_in(menu,"starter_item",starter).pressed.emit()
		check(menu.draft_item==starter and menu.preview.equipment.size()==1 and menu.preview.equipment[DB.item(starter).slot]==starter,"Selecting from another slot replaces the one starter preview")
		check(not menu.primary.disabled,"Valid named character can depart")
		await create_timer(.3).timeout
		await capture("角色实测-"+species+"-创建")
		menu.primary.pressed.emit()
		var game=await wait_city(title)
		check(game.bunny.rig_profile.species_id==species and session.state().species==species,"Creation enters the island with the chosen playable body")
		check(session.state().character_name==("软糖" if species=="bunny" else "团子"),"Name reaches the live player state")
		check(session.authority.count(starter)==1 and session.state().inventory.size()==5 and session.state().equipment[DB.item(starter).slot]==starter,"Exactly one starter is owned and visibly equipped")
		check(game.bunny.is_on_floor(),"Selected player stands on the real floor")
		game.hud.open_panel("profile")
		await create_timer(.35).timeout
		check(game.hud.character_sheet.character_name.text==session.state().character_name and game.hud.character_sheet.preview.actor.rig_profile.species_id==species,"Attribute portrait displays the chosen name and correct body")
		await capture("角色实测-"+species+"-名字与属性")
		game.hud.close_panel()
		if species=="bunny":
			first_id=session.active_character_id
			session.authority.add("watering_can",1)
			session.authority.add("pickaxe",1)
			await travel(game,Vector3(22,.2,-4.5))
			check(game.begin_action("plant","plot_00","seed_carrot").ok,"Rabbit plants in the shared world")
			await create_timer(2.15).timeout
			check(game.begin_action("water","plot_00").ok,"Rabbit waters using the same shared animation system")
			await create_timer(2.15).timeout
			session.authority.tick(120)
			session.state().coins=321
			check(session.state().experience==2,"Rabbit earns its own work experience")
		else:
			cat_id=session.active_character_id
			check(session.state().experience==0 and session.state().coins==650 and session.authority.count("watering_can")==0 and session.authority.count("pickaxe")==0,"Cat begins with its own XP, coins and bag")
			check(session.state().plots.plot_00.crop=="carrot" and session.state().plots.plot_00.growth>=120,"Cat sees the rabbit's existing crop")
			var source: Dictionary=DB.resources()[2]
			await travel(game,Vector3(source.x,.2,source.z+1.4))
			check(game.begin_action("gather",source.id).ok,"Cat performs a real gathering job")
			await create_timer(2.15).timeout
			check(session.state().experience==1 and session.authority.count("branch")==3,"Gathered items and XP belong to the cat")
			session.authority.add("watering_can",1)
			session.state().plots.plot_00.water_stage=-1
			game.refresh_world()
			await travel(game,Vector3(22.4,.15,-6.2))
			game.update_target()
			check(game.current_target=="plot_00" and game.hud.prompt.text.contains("E ") and game.hud.prompt.text.contains("F ") and game.hud.prompt.text.contains("浇水"),"Essential E / F action guidance remains visible for the selected plot")
			check(game.quick_interact().ok,"Cat can quick-water the same shared crop")
			await create_timer(2.15).timeout
			check(session.state().experience==2 and session.authority.count("watering_can")==1,"Cat action completes and permanent tool survives")
		session.save_game()
		game.return_to_title()
		while current_scene==game: await process_frame
		await title_ready()
	title=current_scene
	title.start_button.pressed.emit()
	var menu: Control=title.character_menu
	check(session.character_list().size()==2 and menu.mode=="choose","Both saved characters appear in the selection screen")
	button_in(menu,"character_id",first_id).pressed.emit()
	check(menu.preview.actor.rig_profile.species_id=="bunny" and menu.portrait_name.text=="软糖","Clicking a saved character changes the live preview and name")
	await capture("角色实测-选择已有角色")
	menu.primary.pressed.emit()
	var game=await wait_city(title)
	check(session.active_character_id==first_id and session.state().experience==2 and session.state().coins==321 and session.authority.count("branch")==0,"Returning rabbit retains independent progress")
	check(session.state().plots.plot_00.crop=="carrot" and not session.state().resources.resource_02.available,"World crop and cat's resource depletion remain shared")
	check(session.characters[cat_id].experience==2 and session.characters[cat_id].inventory.branch==3,"Inactive cat's progress is preserved")
	print("CHARACTER_ROSTER_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
