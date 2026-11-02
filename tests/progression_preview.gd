extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
	print("CAPTURE ",label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.2).timeout
	session.active=false
	for id in DB.catalog().items:
		if DB.item(id).kind=="clothing": session.authority.add(id,1)
	session.authority.add("carrot",3)
	session.authority.add("sea_salt",5)
	session.state().experience=37
	session.state().food_effect={"item":"food_carrot_soup","expires_at":session.state().time+2800}
	session.dispatch("equip",{"slot":"head","item":"beret_plaid_rose"})
	session.dispatch("equip",{"slot":"body","item":"apron_sage"})
	game.hud.toast.hide()
	await create_timer(.5).timeout
	await capture("成长更新-小图标界面")
	game.hud.open_panel("profile")
	await create_timer(.7).timeout
	await capture("成长更新-属性与角色")
	game.hud.character_sheet.pages.current_tab=1
	await create_timer(.3).timeout
	await capture("成长更新-技能页")
	game.hud.close_panel()
	game.hud.filters.wardrobe="body"
	game.hud.open_panel("wardrobe")
	await create_timer(.4).timeout
	await capture("成长更新-换装分类")
	game.hud.close_panel()
	game.hud.filters.bag="ingredient"
	game.hud.open_panel("bag")
	await create_timer(.4).timeout
	await capture("成长更新-背包分类")
	game.hud.close_panel()
	game.hud.shop="clothes"
	game.hud.filters.shop_clothes_buy="head"
	game.hud.open_panel("shop")
	await create_timer(.4).timeout
	await capture("成长更新-商店分类")
	game.hud.close_panel()
	Input.warp_mouse(Vector2(60,60))
	var hover:=InputEventMouseMotion.new()
	hover.position=Vector2(60,60)
	root.push_input(hover)
	await create_timer(.9).timeout
	await capture("成长更新-Buff悬浮")
	Input.warp_mouse(Vector2(1000,700))
	game.bunny.position=Vector3(0,.2,18)
	game.bunny.reset_physics_interpolation()
	game.yaw=.2
	game.pitch=.35
	game.distance_=9
	session.active=true
	Input.action_press("sprint")
	Input.action_press("move_down")
	await create_timer(.1).timeout
	Input.action_release("sprint")
	await create_timer(1.6).timeout
	await capture("成长更新-奔跑耐力")
	Input.action_release("move_down")
	print("PROGRESSION_PREVIEW_COMPLETE navready=",game.navigation.ready_for_paths)
	quit()
