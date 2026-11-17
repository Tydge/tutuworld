extends SceneTree
## Manual local clients use only the isolated server launched by local_multiplayer.py.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var endpoint:=OS.get_environment("TUTU_TEST_ENDPOINT")
	if not args.has("--test") or not endpoint.begins_with("ws://127.0.0.1:"):
		push_error("请使用本地双人测试入口，避免连接正式服或读取真实进度。");quit(1);return
	var visitor:=args.has("--visitor")
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.settings.fullscreen=false;session.settings.background_throttle=false;Engine.max_fps=60
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_title("本地双人测试 · "+("访客猫咪" if visitor else "建造兔兔"))
		DisplayServer.window_set_size(Vector2i(1000,700));DisplayServer.window_set_position(Vector2i(360,150) if visitor else Vector2i(40,40))
	var suffix:=Crypto.new().generate_random_bytes(8).hex_encode()
	var result: Dictionary=await session.login_online("register",{"username":"local_"+suffix,"password":"local-building-preview"},endpoint)
	if result.get("ok",false):result=await session.create_online_character("访客猫咪" if visitor else "建造兔兔","cat_teacher" if visitor else "bunny","bow_rose")
	if not result.get("ok",false):push_error(str(result));quit(1);return
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.preparing or city.build_mode==null or city.online_view==null:await process_frame
	city.hud.notify("本地双人测试：可各自到东岸购地建造。关闭窗口即可退出，正式进度不受影响。")
	if args.has("--preview-check"):
		var deadline:=Time.get_ticks_msec()+15000
		while city.online_view.replicas.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
		if city.online_view.replicas.is_empty():push_error("本地第二位玩家未出现。");quit(1);return
	print("LOCAL_MULTIPLAYER_PREVIEW_READY role=","visitor" if visitor else "builder"," peers=",city.online_view.replicas.size()," isolated=",session.test_mode)
	if args.has("--preview-check"):
		await create_timer(2.).timeout
		await session.leave_online();city.queue_free();await process_frame;quit()
