extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
var session: Node
var game: Node3D
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func button(node: Node,key: String,value: String) -> Button:
	for child in node.get_children():
		if child is Button and str(child.get_meta(key,""))==value: return child
		var found:=button(child,key,value)
		if found!=null: return found
	return null
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func run() -> void:
	root.size=Vector2i(1440,960)
	session=S.new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher","panda"]:
		var created: Dictionary=session.create_character({"bunny":"验收兔","cat_teacher":"验收猫","panda":"验收熊猫"}[species],species,"bow_rose")
		check(created.ok,"Create intended species "+species)
		for skill in session.state().skills:
			session.state().skill_experience[skill]=Stats.skill_start(5);session.state().skills[skill]=5
		session.authority.add("orange",3);session.authority.add("bow_plaid_sage",1)
		session.dispatch("equip",{"slot":"head","item":"bow_plaid_sage"})
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		await create_timer(1.4).timeout
		check(game.bunny.rig_profile.species_id==species,"Actual world actor uses intended species "+species)
		for i in range(100):
			if not game.preparing: break
			await process_frame
		game.bunny.position=Vector3(0,.1,10);game.bunny.reset_physics_interpolation();game.yaw=.0;game.pitch=.22;game.distance_=5.5
		await create_timer(.2).timeout
		session.state().stamina=80;session.state().stamina_recovery_elapsed=0
		game.hud.open_panel("bag");await process_frame
		var eat:=button(game.hud.content,"eat_item","orange")
		check(eat!=null and not eat.disabled,"Orange inventory action exists "+species)
		if eat!=null: eat.pressed.emit()
		await create_timer(.65).timeout
		check(session.job().get("verb","")=="snack" and game.bunny.action=="snack","Inventory starts three-second snack "+species)
		check(not game.bunny.seated and not game.bunny.can_move,"Snack stands in place "+species)
		check(game.tools.prop.has_node("Orange"),"Orange rendered in hand "+species)
		var distance: float=game.tools.prop.global_position.distance_to(game.bunny.right_arm.to_global(game.bunny.rig_profile.grip_offset))
		check(distance<.20,"Hand reaches held orange "+species)
		session.active=false
		await capture("吃橘子-"+species)
		game.cancel_action();session.active=true
		check(session.authority.count("orange")==3,"Graphic snack cancel keeps fruit "+species)
		game.begin_snack("orange");await create_timer(3.2).timeout
		check(session.job().is_empty() and session.authority.count("orange")==2 and session.state().stamina==83,"Graphic snack completes once "+species)
		check(game.bunny.can_move and not game.tools.prop.visible,"Snack cleanup restores movement and hides prop "+species)
		var fruit:=DB.resource("city_orange_0")
		game.bunny.position=Vector3(fruit.x,.1,fruit.z+2.4);game.bunny.reset_physics_interpolation();session.set_player_position(game.bunny.position)
		check(game.begin_action("gather",fruit.id).ok,"Start real orange picking "+species)
		await create_timer(.6).timeout
		check(game.bunny.action=="harvest_tree","Tree picking uses safe shared reach "+species)
		session.active=false;await capture("摘橘子-"+species);game.cancel_action();session.active=true
		if species=="bunny":
			session.state().food_effect={"item":"food_tomato_stew","expires_at":session.state().time+3600}
			game.hud.open_panel("profile");await create_timer(.25).timeout
			var sheet: Control=game.hud.character_sheet
			check(sheet.values.wood.text=="+25%" and sheet.values.wood.tooltip_text.contains("番茄炖蔬菜") and sheet.values.wood.tooltip_text.contains("+5%"),"Real attribute UI shows food plus skill sources")
			check(sheet.values.has("run_speed"),"Running stat visible in character panel")
			await capture("技能与食物-属性来源")
			sheet.pages.current_tab=1;await create_timer(.2).timeout
			check(not sheet.skill_controls.planting.level.tooltip_text.is_empty(),"Skill hover explanation attached")
			await capture("技能与食物-技能页")
			game.hud.close_panel()
			var merchant: Dictionary=game.targets.Merchant_farm
			game.bunny.position=merchant.position+Vector3(0,0,2);game.bunny.reset_physics_interpolation();session.set_player_position(game.bunny.position);game.current_target="Merchant_farm"
			game.interact();await process_frame
			check(game.talking_npc=="Merchant_farm" and game.hud.bubble.visible and not game.hud.overlay.visible,"Merchant first E shows a speech bubble")
			await capture("商人第一步-招呼气泡")
			game.interact();await process_frame
			check(game.talking_npc=="" and game.hud.overlay.visible and game.hud.shop=="farm","Merchant second E opens shop")
			game.hud.close_panel()
			game.bunny.position=Vector3(22,.1,-6);game.bunny.reset_physics_interpolation();session.set_player_position(game.bunny.position)
			session.authority.add("seed_wheat",1)
			game.current_target="plot_00";game.hud.open_panel("plot");await process_frame
			var wheat:=button(game.hud.content,"plant_seed","seed_wheat")
			check(wheat!=null and not wheat.disabled,"Wheat appears and unlocks in seed selector")
			game.hud.close_panel()
			for i in range(5):
				var crop_id: String=DB.catalog().crops.keys()[i]
				session.state().plots["plot_%02d"%i]={"crop":crop_id,"growth":float(DB.crop(crop_id).days)*3600*.88,"water_stage":3,"weed_stage":3,"quality":3}
			game.refresh_world();game.bunny.position=Vector3(29,.1,.5);game.bunny.reset_physics_interpolation();game.yaw=.1;game.pitch=.7;game.distance_=16
			await create_timer(.65).timeout;await capture("小麦与四种作物")
			game.hud.open_panel("kitchen");await process_frame
			check(button(game.hud.content,"recipe","honey_wheat_cake")!=null and button(game.hud.content,"recipe","rustic_wheat_bread")!=null and button(game.hud.content,"recipe","vegetable_omelette")!=null,"All three level-five dishes appear")
			session.state().skill_experience.cooking=0;game.hud.rebuild()
			var locked_recipe:=button(game.hud.content,"recipe","pumpkin_soup")
			check(locked_recipe.disabled and locked_recipe.text=="需要烹饪 Lv.3","Recipe button prioritizes level before missing materials")
			session.state().skill_experience.cooking=Stats.skill_start(5);game.hud.rebuild()
			await capture("七道料理-菜单")
			game.hud.filters.kitchen="baked";game.hud.rebuild();await process_frame;await capture("两道麦料理")
			game.hud.close_panel()
			# Demonstrate that the bonus changes running while leaving walking alone.
			session.state().food_effect={"item":"food_rustic_wheat_bread","expires_at":session.state().time+3600}
			await create_timer(.08).timeout
			check(is_equal_approx(game.bunny.run_speed_multiplier,1.2) and is_equal_approx(game.bunny.speed_multiplier,1.0),"World applies running bonus separately")
		game.queue_free();await process_frame;await process_frame
	print("GAMEPLAY_REVISION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
