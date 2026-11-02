extends SceneTree
const S=preload("res://scripts/services/session.gd")
var session: Node
var title: Node3D
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func capture(label_: String) -> void:
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label_+".png")
	print("CAPTURE ",label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	session=S.new()
	session.name="Session"
	root.add_child(session)
	title=load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	while not title.characters_ready: await process_frame
	title.start_game()
	var menu: Control=title.character_menu
	menu.name_input.text="软糖"
	menu.name_input.text_changed.emit("软糖")
	await capture("角色创建-兔兔与初始服饰")
	menu.draft_species="cat_teacher"
	menu.clothing_category="neck"
	menu.draft_item="scarf_blue"
	menu.build_create()
	await capture("角色创建-猫咪与围巾")
	menu.clothing_category="body"
	menu.draft_item="vest_sage"
	menu.build_create()
	await capture("角色创建-猫咪与马甲")
	session.create_character("软糖","bunny","bow_rose")
	session.state().experience=12
	session.create_character("团子","cat_teacher","scarf_blue")
	menu.open()
	await capture("角色选择-共用小岛的两位邻居")
	title.queue_free()
	await process_frame
	var game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(.8).timeout
	game.hud.open_panel("profile")
	await capture("角色名字-猫咪属性面板")
	print("CHARACTER_ROSTER_PREVIEW_COMPLETE")
	quit()
