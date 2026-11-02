extends SceneTree
const Stats=preload("res://scripts/services/character_stats.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher","panda"]:
		session.create_character("采摘"+species.left(5),species,"scarf_green");session.state().map_id="valley";session.state().player_position=[-8,.1,32];session.state().time=1800
		var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(.8).timeout
		session.active=false;game.bunny.can_move=false;Engine.max_fps=30
		var target: Dictionary=DB.resource("valley_orange_0")
		session.state().resources[target.id].available=true;session.state().skill_experience.planting=99;session.state().skills.planting=1
		game.bunny.position=Vector3(target.x+1.7,target.y+.1,target.z);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.set_player_position(game.bunny.position)
		var began: Dictionary=game.begin_action("gather",target.id)
		check(began.ok,"Actual harvest starts for "+species)
		var result: Array=session.authority.tick(2.01)
		for event in result: session.event_received.emit(event)
		session.changed.emit();await create_timer(.3).timeout
		check(session.state().skill_experience.planting==100 and session.state().skills.planting==2,"Actual completion crosses skill threshold "+species)
		game.hud.open_panel("profile");await create_timer(.2).timeout
		var sheet: Control=game.hud.character_sheet;sheet.pages.current_tab=1
		check(sheet.skill_controls.planting.level.text=="Lv.2" and sheet.skill_controls.planting.xp.text=="0 / 150" and sheet.skill_controls.planting.progress.max_value==150,"Live skill panel reflects XP and next threshold "+species)
		if species=="panda":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/技能成长-角色面板.png")
		game.queue_free();await process_frame;await process_frame
	print("SKILL_EXPERIENCE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
