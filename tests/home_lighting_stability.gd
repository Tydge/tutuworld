extends SceneTree
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(2400,1440)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.interior_view_mode=0
	for species in ["bunny","cat_teacher"]:
		check(session.create_character("稳稳兔" if species=="bunny" else "稳稳猫",species,"vest_sage").ok,"Create "+species)
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		await create_timer(.6).timeout
		session.active=false;game.bunny.can_move=false
		game.bunny.position=game.home.to_global(Vector3(0,.3,.5));game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
		game.yaw=.35;game.pitch=.45;game.distance_=13.5
		for quality in ["balanced","native"]:
			session.settings.render_quality=quality
			root.get_node("RenderBudget").apply()
			check(root.scaling_3d_scale<1 if quality=="balanced" else is_equal_approx(root.scaling_3d_scale,1.0),"Actually exercises "+quality+" rendering")
			for fraction in [.5,.92]:
				session.state().time=fraction*3600;game.update_lighting()
				await create_timer(.9).timeout
				var low:=10.0;var high:=-1.0;var color_jump:=0.0;var last:=Color.BLACK
				var roof_restores:=0;var start:=Time.get_ticks_msec()
				while Time.get_ticks_msec()-start<2100:
					await RenderingServer.frame_post_draw
					var energy: float=game.atmosphere.ambient_light_energy
					low=minf(low,energy);high=maxf(high,energy)
					var color: Color=game.atmosphere.ambient_light_color
					if last!=Color.BLACK: color_jump=maxf(color_jump,absf(color.r-last.r)+absf(color.g-last.g)+absf(color.b-last.b))
					last=color
					if game.home.sections[0].alpha>.001: roof_restores+=1
				var label_: String=species+" "+quality+" "+str(fraction)
				print("INDOOR_STABILITY ",label_," energy_range=",high-low," color_jump=",color_jump," roof_restores=",roof_restores)
				check(high-low<.0001 and color_jump<.0001,"No periodic ambient flash: "+label_)
				check(roof_restores==0,"Hidden roof remains hidden: "+label_)
		game.queue_free();await process_frame;await process_frame
	print("HOME_LIGHTING_STABILITY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
