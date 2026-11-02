extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks := 0
var output := preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func check(condition: bool,label_: String) -> void:
	checks+=1
	if condition: print("PASS ",label_)
	else: failures.append(label_); push_error(label_)
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name_+".png")==OK,"Capture "+name_)
func travel(pos: Vector3) -> void:
	game.bunny.position=pos
	game.bunny.velocity=Vector3.ZERO
	session.set_player_position(pos)
	await create_timer(.3).timeout
func wait_action() -> void:
	await create_timer(2.15).timeout
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	session.authority.state.coins=10000
	var title=load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	while not title.characters_ready: await process_frame
	check(title.actor.visible and title.title_sky is ShaderMaterial and title.clock>0,"Title has live island, rabbit and drifting clouds")
	await capture("标题界面")
	title.queue_free()
	await process_frame
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(1).timeout
	var b: CharacterBody3D=game.bunny
	check(b.is_on_floor(),"Player stands on city terrain")
	check(game.npcs.size()==9,"Three merchants, four wandering rabbits, cat teacher and Youmu")
	var npc_start: Vector3=game.npcs[4].position
	await create_timer(.8).timeout
	check(game.npcs[4].position.distance_to(npc_start)>.1,"Passerby walks independently")
	await travel(Vector3(DB.shops().tools.x,.18,DB.shops().tools.y+2.3))
	game.current_target="Merchant_tools"
	game.interact()
	check(game.hud.mode=="shop" and game.hud.shop=="tools","Tool merchant opens correct shop")
	for id in ["watering_can","stone_hammer","pickaxe"]: check(session.dispatch("buy",{"shop":"tools","item":id}).ok,"Buy permanent tool "+id)
	await create_timer(.25).timeout
	await capture("工具商店")
	game.hud.close_panel()
	await travel(Vector3(DB.shops().farm.x,.18,DB.shops().farm.y+2.3))
	check(session.dispatch("buy",{"shop":"farm","item":"herbicide","quantity":5}).ok,"Buy herbicide at seed shop")
	await travel(Vector3(DB.shops().clothes.x,.18,DB.shops().clothes.y+2.3))
	for id in DB.catalog().items:
		if DB.item(id).kind=="clothing": check(session.dispatch("buy",{"shop":"clothes","item":id}).ok,"Buy clothing "+id)
	for id in DB.catalog().items:
		var item: Dictionary=DB.item(id)
		if item.kind=="clothing":
			check(session.dispatch("equip",{"slot":item.slot,"item":id}).ok,"Wear clothing "+id)
			await process_frame
	check(b.get_node("Visual/Head").has_node("Wardrobe_head"),"Head wearable attaches without modifying original model")
	check(b.get_node("Visual").has_node("Wardrobe_body"),"Body wearable attaches independently")
	game.hud.open_panel("wardrobe")
	await create_timer(.3).timeout
	await capture("换装衣橱")
	game.hud.close_panel()
	await travel(Vector3(22,.1,-4.3))
	check(game.begin_action("plant","plot_00","seed_carrot").ok,"Planting starts in the real world")
	await create_timer(.65).timeout
	check(game.hud.ring.visible and game.hud.ring.progress>.20 and game.hud.ring.progress<.7,"Overhead ring follows two-second action")
	await capture("播种进度")
	await create_timer(1.5).timeout
	check(session.state().plots.plot_00.crop=="carrot","Planting completes in world")
	var tools_before: int=session.authority.count("watering_can")
	check(game.begin_action("water","plot_00").ok,"Watering starts")
	await create_timer(.75).timeout
	check(game.tools.verb=="water" and game.tools.prop.visible,"Rabbit holds watering can during action")
	await capture("浇水动作")
	await create_timer(1.4).timeout
	check(session.authority.count("watering_can")==tools_before,"Watering tool survives successful action")
	session.authority.tick(1201)
	game.refresh_world()
	check(session.authority.needs(session.state().plots.plot_00).weed,"Growing crop requests weeding")
	var weed_before: int=session.authority.count("herbicide")
	check(game.begin_action("weed","plot_00").ok,"Weeding starts")
	await wait_action()
	check(session.authority.count("herbicide")==weed_before-1,"Only herbicide is consumed")
	game.begin_action("water","plot_00")
	await wait_action()
	session.authority.tick(1201)
	game.refresh_world()
	game.begin_action("weed","plot_00"); await wait_action()
	game.begin_action("water","plot_00"); await wait_action()
	session.authority.tick(1201)
	game.refresh_world()
	check(session.authority.needs(session.state().plots.plot_00).ready,"Crop reaches harvest stage after care gates")
	game.begin_action("harvest","plot_00")
	await wait_action()
	check(session.authority.count("carrot")==3,"Harvest grants crops to bag")
	for i in range(3):
		var resource: Dictionary=DB.resources()[i]
		await travel(Vector3(resource.x,.1,resource.z+1.4))
		check(game.begin_action("gather",resource.id).ok,"Start real resource gathering "+resource.item)
		await create_timer(.65).timeout
		if i<2:
			check(game.tools.prop.visible,"Held gathering tool is visible")
			await capture("采集工具-"+resource.item)
		await create_timer(1.5).timeout
		check(session.authority.count(resource.item)>0,"Gathered material reaches bag "+resource.item)
	check(session.authority.count("stone_hammer")==1 and session.authority.count("pickaxe")==1,"Both gathering tools remain owned")
	await travel(Vector3(DB.shops().farm.x,.18,DB.shops().farm.y+2.3))
	var money_before: int=session.state().coins
	check(session.dispatch("sell",{"shop":"farm","item":"carrot","quantity":3}).ok,"Sell harvested crops at seed shop")
	check(session.state().coins==money_before+54,"Sale pays correct amount")
	game.hud.open_panel("bag")
	await create_timer(.3).timeout
	await capture("海岛城-背包")
	game.hud.close_panel()
	session.test_mode=false
	session.save_path="user://qa_city_%d.json"%Time.get_ticks_usec()
	check(session.save_game(),"City save is written atomically")
	var restored=load("res://scripts/services/session.gd").new()
	restored.save_path=session.save_path
	restored.load_save()
	check(restored.authority.count("pickaxe")==1 and restored.authority.state.equipment==session.state().equipment,"Inventory and clothing survive reload")
	DirAccess.remove_absolute(session.save_path)
	DirAccess.remove_absolute(session.save_path+".bak")
	session.test_mode=true
	restored.free()
	await travel(Vector3(0,.1,9))
	session.authority.state.time=3600*.88
	game.update_lighting()
	var lit:=0
	for lamp in game.scenery.get_node("Streetlights").get_children():
		if lamp.get_node("NightLight").visible: lit+=1
	check(lit>0 and game.sun.light_energy<.1,"Night enables nearby lamps and dims sunlight")
	await create_timer(.6).timeout
	await capture("海岛城-夜色")
	print("CITY_INTEGRATION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
