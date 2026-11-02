extends SceneTree
const Session=preload("res://scripts/services/session.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
var friend: Node
var checks:=0
var failures: Array=[]
var endpoint:="ws://127.0.0.1:18891"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func wait(seconds: float) -> void:await create_timer(seconds).timeout
func run() -> void:
	if OS.get_environment("TUTU_TEST_ENDPOINT")!="":endpoint=OS.get_environment("TUTU_TEST_ENDPOINT")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1440,960)
	session=Session.new();session.name="Session";root.add_child(session)
	check(session.settings.fullscreen and session.settings.fps_limit==60 and session.settings.render_quality=="balanced","New install defaults fullscreen 60 FPS balanced")
	var offline= session.authority
	var suffix:=Crypto.new().generate_random_bytes(4).hex_encode()
	var login=preload("res://scripts/ui/online_login.gd").new();login.session=session;login.endpoint=endpoint;root.add_child(login)
	login.open();login.toggle_mode();login.username.text="ui_"+suffix;login.password.text="island-ui-test-123";login.confirmation.text="mismatch"
	await login.submit();check(login.feedback.text.contains("不一样"),"Registration form checks password confirmation")
	await capture("账号注册")
	login.confirmation.text=login.password.text;await login.submit()
	check(session.is_online(),"Registration form logs in through real transport")
	if not session.is_online():print(login.feedback.text);quit(1);return
	login.queue_free()
	var result: Dictionary
	result=await session.create_online_character("验收兔"+suffix.left(4),"bunny","bow_plaid_sage" if "bow_plaid_sage" in DB.starter_clothes() else "bow_rose")
	check(result.get("ok",false) and session.online_joined,"Client character creation joins shared world")
	check(session.state().coins==500 and not session.state().inventory.has("seed_carrot"),"Client receives 500 and no starter seeds")
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	await wait(2)
	check(game.online_view!=null,"Multiplayer world view attached")
	check(game.hud.toast_timer<=0,"No entry welcome or exploration toast")
	check(game.hud.clock_label.text.begins_with("海岛年"),"Island date shown in actual HUD")
	check(not session.can_adjust_time(),"Time controls blocked online")
	game.hud.open_panel("settings");await wait(.2)
	check(game.hud.content.find_children("TestingTimeControls","",true,false).is_empty(),"No multiplayer time-setting controls")
	var unstuck:=false
	for button in game.hud.content.find_children("*","Button",true,false):
		if button.text=="脱离卡住":unstuck=true
	check(unstuck,"Unstuck action visible in settings")
	await capture("多人设置")
	game.hud.close_panel()
	friend=Transport.new();root.add_child(friend)
	check(await friend.ensure_connected(endpoint),"Second client connects")
	result=await friend.request("register",{"username":"friend_"+suffix,"password":"island-ui-test-123"})
	check(result.get("ok",false),"Second account registers")
	result=await friend.request("create_character",{"name":"验收猫"+suffix.left(4),"species":"cat_teacher","starter":"vest_sage"})
	check(result.get("ok",false),"Second client creates cat")
	if not result.get("ok",false):print(result);quit(1);return
	result=await friend.request("join",{"character":result.character})
	check(result.get("ok",false),"Second client enters same world")
	await wait(.6)
	check(game.online_view.replicas.size()==1,"Second species appears as remote avatar")
	await friend.request("chat",{"text":"你好呀！🍊🐰✨"})
	await wait(.4)
	check(game.online_view.bubbles.size()==1,"Emoji message displayed as world bubble")
	await capture("多人相遇与聊天")
	var initial: Vector3=game.bunny.position
	Input.action_press("move_right");await wait(1.5);Input.action_release("move_right");await wait(.7)
	check(game.bunny.position.distance_to(initial)>1,"Keyboard movement reconciles with authoritative server")
	var p: Array=session.state().player_position
	check(game.bunny.position.distance_to(Vector3(float(p[0]),float(p[1]),float(p[2])))<1,"Server and client positions converge")
	game.current_target=DB.plots()[0].id;game.hud.open_panel("plot")
	await wait(.2)
	var records_button:=false
	for button in game.hud.content.find_children("*","Button",true,false):
		if button.text=="照料记录":records_button=true
	check(records_button,"Crop E panel includes care records")
	game.hud.show_plot_history(game.current_target);await capture("作物照料记录入口")
	game.hud.close_panel()
	await session.request_online("unstuck")
	await wait(.4)
	check(session.online_joined,"Unstuck keeps connection and world progress")
	await friend.request("leave");friend.close();await wait(.4)
	check(game.online_view.replicas.is_empty(),"Leaving removes remote avatar")
	game.queue_free();await process_frame
	await session.leave_online()
	check(not session.is_online() and session.authority==offline,"Leaving restores original single-player session")
	var title=load("res://scenes/title.tscn").instantiate();root.add_child(title)
	for i in range(400):
		if title.characters_ready:break
		await process_frame
	check(title.multiplayer_button!=null and not title.multiplayer_button.disabled,"Title exposes multiplayer after version check")
	await capture("030标题与更新")
	print("MULTIPLAYER_CLIENT_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
