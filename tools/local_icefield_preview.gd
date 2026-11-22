extends SceneTree
## Opt-in isolated preview. This does not read the user's real progress.
const L=preload("res://scripts/icefield/icefield_layout.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		push_error("This preview requires --test.");quit(1);return
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	var jade:=OS.get_cmdline_user_args().has("--jade")
	var map_id:="jade" if jade else "icefield"
	session.create_character("玉京散步" if jade else "冰原散步","bunny","scarf_red");session.state().map_id=map_id;session.state().player_position=preload("res://scripts/jade/layout.gd").arrival() if jade else L.arrival();session.state().time=2600.;session.settings.fps_limit=60;Engine.max_fps=60
	for id in ["pickaxe","hammer","copper_axe","shovel"]:
		if not preload("res://scripts/services/game_data.gd").item(id).is_empty():session.authority.add(id,1)
	var game=load(preload("res://scripts/services/map_routes.gd").scene(map_id)).instantiate();root.add_child(game);current_scene=game
	while game.camera==null or game.preparing or not game.navigation.ready_for_paths:await process_frame
	game.pitch=.22;game.yaw=.05
	if jade:
		game.hud.notify("南津渡到了。沿灯市街北行可到漕运钟楼，过河后登阶入宫。");print("LOCAL_JADE_PREVIEW_READY isolated=true");return
	game.hud.notify("冰原岛预览：雪地会留下脚印，冰面刹车较慢。南岸码头免费回城；使用独立测试角色。")
	print("LOCAL_ICEFIELD_PREVIEW_READY isolated=true")
