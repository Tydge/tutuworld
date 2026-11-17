extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("林间光线检查","panda","scarf_green");session.state().map_id="valley";session.state().player_position=preload("res://scripts/valley/valley_layout.gd").arrival("valley");session.state().time=1800
	var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);current_scene=game
	while game.preparing or not game.navigation.ready_for_paths:await process_frame
	session.active=false;game.set_process(false);game.bunny.can_move=false
	game.update_lighting(.5)
	var noon: Color=game.sun.light_color
	var old: Quaternion=game.sun.quaternion
	session.state().time=1810.;game.update_lighting()
	var initial_error: float=old.angle_to(game.sun_target)
	check(initial_error>.001 and old.angle_to(game.sun.quaternion)<.00001,"Clock refresh sets a new sunlight target without jumping the current shadow")
	var largest:=0.;var last:=old
	for frame in range(60):
		game._process(1./60.)
		largest=maxf(largest,last.angle_to(game.sun.quaternion));last=game.sun.quaternion
	check(largest<initial_error*.2 and game.sun.quaternion.angle_to(game.sun_target)<.001,"Sunlight converges gradually between clock refreshes")
	print("SUNLIGHT_CONTINUITY ",JSON.stringify({"target_change_radians":initial_error,"largest_frame_change":largest,"remaining_error":game.sun.quaternion.angle_to(game.sun_target)}))
	game.update_lighting(.30)
	var morning: Color=game.sun.light_color
	check(morning.r/morning.b>noon.r/noon.b,"Low sunlight is warmer than midday light")
	game.home.set_process(false);game.home.interior_weight=.7
	game.update_lighting(.5)
	var energy: float=game.atmosphere.ambient_light_energy;var color: Color=game.atmosphere.ambient_light_color
	game.update_ambient_lighting()
	check(is_equal_approx(energy,game.atmosphere.ambient_light_energy) and color.is_equal_approx(game.atmosphere.ambient_light_color),"Clock and per-frame room blending agree on ambient light")
	check(game.sun.directional_shadow_max_distance==160. and game.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and game.sun.directional_shadow_blend_splits,"Saved valley uses the measured two-cascade shadow profile and soft split transitions")
	game.update_lighting(.92)
	check(is_equal_approx(game.sun.light_energy,.30) and game.sun.shadow_opacity<.5,"Moonlight retains a gentle, readable nighttime floor")
	current_scene=null;game.queue_free();await process_frame;await process_frame
	print("WOODLAND_LIGHTING_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
