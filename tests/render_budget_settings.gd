extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	var title=load("res://scenes/title.tscn").instantiate();root.add_child(title)
	while not title.characters_ready: await process_frame
	var budget:=root.get_node("RenderBudget")
	check(is_equal_approx(root.scaling_3d_scale,1.0),"Default-size window keeps full-resolution 3D")
	title.settings_card.show();await create_timer(.3).timeout
	var options: Array=title.settings_card.find_children("*","OptionButton",true,false)
	check(options.size()==2,"Game-style settings expose picture quality and FPS choices")
	var choice: OptionButton=options[0]
	var panel: Control=title.settings_card.get_child(1)
	check(panel.get_global_rect().end.y<root.get_visible_rect().size.y,"Expanded settings card stays inside the window")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/画面设置-均衡与原生.png")
	root.size=Vector2i(2400,1440);await create_timer(.6).timeout
	var modern:=RenderingServer.get_current_rendering_method()=="forward_plus"
	check(root.scaling_3d_scale<.85,"Dense window budgets the 3D buffer; compatibility remains supported")
	var before: Vector2=root.get_texture().get_size()
	choice.select(1);choice.item_selected.emit(1);await create_timer(.4).timeout
	check(session.settings.render_quality=="native" and is_equal_approx(root.scaling_3d_scale,1.0),"Native-quality selection restores the full 3D buffer")
	choice.select(0);choice.item_selected.emit(0);await create_timer(.4).timeout
	check(session.settings.render_quality=="balanced" and root.get_texture().get_size()==before,"Balanced selection preserves native-resolution UI and output")
	title.queue_free();await process_frame;await process_frame
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	await create_timer(.8).timeout
	check(root.get_node("RenderBudget")==budget,"Title and city share a single persistent renderer budget")
	game.hud.open_panel("settings");await create_timer(.3).timeout
	check(game.hud.content.find_children("*","OptionButton",true,false).size()==2,"In-game settings offer the same quality control")
	print("RENDER_BUDGET_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
