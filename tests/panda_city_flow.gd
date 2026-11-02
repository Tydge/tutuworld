extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func button(node: Node,key: String,value: String) -> Button:
	for child in node.find_children("*","Button",true,false):
		if child.get_meta(key,"")==value: return child
	return null
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func travel(point: Vector3) -> void:
	game.bunny.position=point;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.set_player_position(point);await create_timer(.35).timeout
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=S.new();session.name="Session";root.add_child(session);Engine.max_fps=30
	var menu=load("res://scripts/ui/character_menu.gd").new();menu.session=session;root.add_child(menu);menu.open()
	check(button(menu,"species_id","panda")!=null,"Creation offers the panda option")
	menu.name_input.text="小竹";menu.name_input.text_changed.emit("小竹");button(menu,"species_id","panda").pressed.emit()
	button(menu,"starter_category","body").pressed.emit();button(menu,"starter_item","vest_sage").pressed.emit()
	await create_timer(.4).timeout
	check(menu.draft_name=="小竹" and menu.portrait_subtitle.text=="熊猫" and menu.preview.actor.rig_profile.species_id=="panda","Panda selection keeps the name and displays the right preview and label")
	check(root.get_visible_rect().encloses(menu.card.get_global_rect()),"Three-species creation layout fits")
	await capture("熊猫角色-创建")
	var requests: Array=[];menu.play_requested.connect(func(id): requests.append(id));menu.primary.pressed.emit()
	check(requests.size()==1 and session.state().species=="panda" and session.state().character_name=="小竹","Create-and-play submits the panda through the normal character flow")
	menu.queue_free();await process_frame;await process_frame
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.8).timeout
	while not game.navigation.ready_for_paths: await process_frame
	check(game.bunny.rig_profile.species_id=="panda" and game.hud.player_status.portrait.actor.rig_profile.species_id=="panda","Panda is the controlled player and the HUD portrait")
	check(game.npcs.size()==9 and game.has_node("Youmu"),"Youmu is added alongside existing island residents")
	var youmu: Node3D=game.get_node("Youmu")
	check(youmu.rig_profile.species_id=="panda" and youmu.get_meta("equipment").head=="beret_plaid_sage" and youmu.get_meta("equipment").neck=="scarf_red","Youmu wears the shared beret and scarf equipment")
	session.state().time=1800;game.update_lighting();game.hud.toast.hide();game.yaw=-.35;game.pitch=.40;game.distance_=8
	await travel(youmu.position+Vector3(0,.15,2.3));game.update_target();game.current_target="Youmu";game.interact();await create_timer(.4).timeout
	check(game.talking_npc=="Youmu" and game.hud.bubble.visible and game.hud.bubble_name.text=="又木","Youmu uses the existing named speech bubble")
	check(Vector2(youmu.velocity.x,youmu.velocity.z).length()<.02,"Youmu stops walking during conversation")
	await capture("又木-小岛相遇");game.end_dialogue()
	for id in DB.catalog().items:
		if DB.item(id).kind=="clothing": session.authority.add(id,1)
	game.hud.open_panel("wardrobe")
	for id in ["bow_honey","overalls_sage","bell_green"]:
		button(game.hud.content,"equipment_item",id).pressed.emit();await create_timer(.15).timeout
	check(game.hud.character_sheet.preview.species=="panda" and game.hud.character_sheet.preview.equipment==session.state().equipment,"Existing wardrobe previews and applies all three panda slots")
	await capture("熊猫角色-换装");game.hud.close_panel()
	await travel(Vector3(0,.2,27));game.yaw=0;var start: Vector3=game.bunny.position
	Input.action_press("move_right");await create_timer(.6).timeout
	check(game.bunny.position.x-start.x>1 and game.bunny.walking,"Panda walks upright with the shared controls")
	Input.action_press("sprint");await physics_frame;Input.action_release("sprint");await create_timer(.4).timeout
	check(game.bunny.run_enabled and game.bunny.is_running and game.bunny.run_blend>.5,"Panda shares toggle running and the run cycle")
	Input.action_press("jump");await physics_frame;Input.action_release("jump");await create_timer(.18).timeout
	check(not game.bunny.is_on_floor() and game.bunny.left_arm.rotation.z<-.20 and not game.bunny.mood_label.text.contains("!"),"Panda shares the open-arm jump without an exclamation mark")
	await capture("熊猫角色-跳跃");Input.action_release("move_right");game.bunny.run_enabled=false
	await create_timer(.7).timeout
	# Complete the remaining production poses with the new body, on real targets.
	await travel(Vector3(22,.2,-7.6))
	check(game.begin_action("plant","plot_00","seed_carrot").ok,"Panda can sow with the existing seed action")
	await create_timer(.4).timeout
	check(game.bunny.action=="plant" and game.hud.ring.visible,"Shared planting pose and progress ring work")
	while not session.job().is_empty(): await process_frame
	session.state().plots.plot_00.growth=3600;session.state().plots.plot_00.water_stage=10;session.state().plots.plot_00.weed_stage=10;game.refresh_world()
	check(game.begin_action("harvest","plot_00").ok,"Panda can harvest the selected mature crop")
	await create_timer(.4).timeout
	check(game.bunny.action=="harvest","Shared two-arm harvesting pose works")
	while not session.job().is_empty(): await process_frame
	var branch: Dictionary={}
	for resource in DB.resources():
		if resource.item=="branch": branch=resource;break
	await travel(Vector3(branch.x,.2,branch.z+1.4))
	check(game.begin_action("gather",branch.id).ok,"Panda gathers branches without a tool")
	while not session.job().is_empty(): await process_frame
	check(session.authority.count("branch")>0,"Shared branch gathering completes")
	for pair in [["carrot",2],["sea_salt",1]]: session.authority.add(pair[0],pair[1])
	await travel(Vector3(21,.2,-19.6));game.yaw=.85;game.pitch=.68;game.distance_=9
	check(game.begin_cooking("carrot_soup").ok,"Panda starts cooking with the existing station and recipe")
	await create_timer(.8).timeout
	check(game.tools.verb=="cook" and game.bunny.action=="cook" and game.culinary.steam.visible,"Panda holds the existing spoon and stirs")
	await capture("熊猫角色-烹饪")
	while not session.job().is_empty(): await process_frame
	check(session.authority.count("food_carrot_soup")==1,"Shared cooking completes for panda")
	await travel(Vector3(28.2,.2,-17.5));game.yaw=PI-.65;game.pitch=.43;game.distance_=8.2
	check(game.begin_dining("food_carrot_soup").ok,"Panda can use the existing dining chair")
	await create_timer(1).timeout
	check(game.bunny.seated and game.tools.verb=="eat" and is_instance_valid(game.culinary.meal),"Panda sits, holds the spoon and eats")
	await capture("熊猫角色-吃饭")
	while not session.job().is_empty(): await process_frame
	check(not game.bunny.seated and session.state().food_effect.item=="food_carrot_soup","Meal finishes and grants the normal buff")
	game.queue_free();await process_frame;await process_frame
	print("PANDA_CITY_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
