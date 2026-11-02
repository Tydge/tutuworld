extends SceneTree
const Travel=preload("res://scripts/valley/boat_travel.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("乘风旅行","panda","beret_sage")
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);current_scene=game
	await create_timer(.8).timeout
	game.bunny.position=Vector3(-5,.2,-26.5);game.bunny.velocity=Vector3.ZERO;session.set_player_position(game.bunny.position)
	game.hud.shop="tools";game.hud.open_panel("shop");await process_frame
	check(game.hud.shop_rows.has("copper_axe"),"Copper axe available in real tool shop")
	var initial_coins: int=session.state().coins
	game.hud.shop_rows.copper_axe.buy.pressed.emit()
	check(session.authority.count("copper_axe")==1 and session.state().coins==initial_coins-160,"Buy permanent copper axe through shop UI")
	game.hud.close_panel()
	game.bunny.position=Vector3(13,.2,40.5);game.bunny.velocity=Vector3.ZERO;game.bunny.can_move=false;session.set_player_position(game.bunny.position);game.update_target()
	check(game.current_target=="boat" and game.hud.prompt.text.contains("10"),"Boat selection and fare hint")
	var before_coins: int=session.state().coins;var before_xp: int=session.state().experience
	session.state().skill_experience.mining=73
	session.state().resources.resource_00.available=false;session.state().resources.resource_00.respawn_at=session.state().time+4000
	await Travel.go(game)
	var deadline:=Time.get_ticks_msec()+15000
	while (current_scene==null or current_scene.name!="MianfengValley") and Time.get_ticks_msec()<deadline: await process_frame
	check(current_scene!=null and current_scene.name=="MianfengValley","Actual outbound scene transition")
	if current_scene==null or current_scene.name!="MianfengValley": quit(1);return
	game=current_scene;await create_timer(1).timeout
	check(session.state().coins==before_coins-10 and session.state().map_id=="valley","Exactly one outward debit")
	check(game.bunny.position.distance_to(Vector3(-11,.18,43))<.5,"Arrival position survives outgoing world")
	check(game.resources.size()==27 and game.npcs.size()==3 and game.targets.Panda.name=="潘达","Valley resources and resident")
	check(not session.state().resources.resource_00.available and session.state().experience==before_xp,"Shared island progress retained")
	game.hud.open_panel("map");await create_timer(.2).timeout
	check(game.hud.mode=="map" and game.hud.map_draw!=null,"Valley map interface")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/山谷-地图.png")
	game.hud.close_panel();game.bunny.position=Vector3(-5.8,.2,47.2);game.bunny.velocity=Vector3.ZERO;session.set_player_position(game.bunny.position);game.update_target()
	check(game.current_target=="boat" and game.hud.prompt.text.contains("免费"),"Free return hint")
	await Travel.go(game)
	deadline=Time.get_ticks_msec()+15000
	while (current_scene==null or current_scene.name!="IslandCity") and Time.get_ticks_msec()<deadline: await process_frame
	check(current_scene!=null and current_scene.name=="IslandCity","Actual return scene transition")
	if current_scene!=null and current_scene.name=="IslandCity":
		game=current_scene;await create_timer(.5).timeout
		check(session.state().coins==before_coins-10 and session.state().map_id=="city","No return charge")
		check(game.bunny.position.distance_to(Vector3(13,.15,39.5))<.5,"Return to city pier")
		check(root.find_children("FramePacer","Node",false,false).size()==1,"Single pacing service across maps")
		check(session.state().skill_experience.mining==73,"Skill XP survives outbound and return journey")
	print("VALLEY_JOURNEY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
