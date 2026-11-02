extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("试钟猫","cat_teacher","vest_sage")
	session.state().time=7*3600+1200
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	await create_timer(.8).timeout
	session.active=false;game.bunny.can_move=false
	game.bunny.position=game.home.to_global(Vector3(0,.3,.5));game.bunny.reset_physics_interpolation()
	await create_timer(.6).timeout
	game.hud.open_panel("settings");game.hud.toast.hide()
	await create_timer(.3).timeout
	var controls: Array=game.hud.content.find_children("TestingTimeControls","VBoxContainer",true,false)
	check(controls.size()==1 and controls[0].visible,"Single-player settings show the time control")
	var clock: Node=controls[0]
	var scroll: ScrollContainer=game.hud.content.get_node("SettingsScroll")
	check(game.hud.modal.get_global_rect().end.y<=root.get_visible_rect().size.y and scroll.size.y>=490,"Settings and time controls stay in a scrollable game panel")
	for hour in [6,12,18,22]:
		var button: Button=clock.find_child("Time%02d"%hour,true,false)
		button.pressed.emit()
		check(is_equal_approx(float(session.state().time),7*3600+hour*150),"Preset really chooses "+str(hour)+":00 on the current day")
		check(game.hud.clock_label.text.contains("%02d : 00"%hour),"HUD clock updates immediately")
	check(game.sun.light_energy<.1 and game.home.key_light.light_energy>4,"22:00 immediately updates outdoor and indoor light")
	check(game.lamps[0].get_node("NightLight").visible,"Night preset immediately turns streetlights on")
	clock.hours.value=16;clock.minutes.value=45
	var apply_button: Button=clock.find_child("ApplyTime",true,false);apply_button.pressed.emit()
	check(is_equal_approx(float(session.state().time),7*3600+2512.5),"Exact 16:45 works through the actual settings button")
	check(clock.heading.text.contains("第 8 天 16:45"),"The date stays unchanged in the visible control")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/设置-单人时间调节.png")
	clock.hours.get_line_edit().grab_focus();clock.hours.get_line_edit().text="9"
	clock.minutes.value=5;apply_button.pressed.emit()
	check(is_equal_approx(float(session.state().time),7*3600+1362.5),"Typed hour is committed when applying from the focused field")
	clock.hours.get_line_edit().release_focus()
	# Keep in-progress input while normal clock/UI refreshes continue.
	clock.hours.value=10;clock.minutes.value=37;session.changed.emit()
	check(clock.hours.value==10 and clock.minutes.value==37,"Clock refresh does not overwrite a time being entered")
	game.hud.close_panel();await create_timer(.8).timeout
	check(game.home.inside and game.home.interior_weight>.99,"Time adjustment keeps the player inside the same house")
	session.transport_mode="remote";game.hud.open_panel("settings");await create_timer(.2).timeout
	check(game.hud.content.find_children("TestingTimeControls","VBoxContainer",true,false).is_empty(),"Online-mode settings omit the control")
	check(not session.set_testing_time(12,0).ok,"Calling the setter cannot bypass the multiplayer guard")
	print("TESTING_CLOCK_UI_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
