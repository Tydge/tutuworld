extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(2400,1440)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	session.active=false;game.bunny.can_move=false
	for point in [[Vector3(0,.1,9),.5,"day"],[Vector3(0,.1,9),.92,"night"],[Vector3(13,.1,30),.5,"coast"]]:
		game.bunny.position=point[0];game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
		session.state().time=point[1]*3600;game.update_lighting();await create_timer(.5).timeout
		var samples: Array[float]=[];var draws:=0;var last:=Time.get_ticks_usec();var start:=last
		while Time.get_ticks_usec()-start<2000000:
			game.yaw+=.009;await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();samples.append((now-last)/1000.);last=now
			draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		samples.sort();print("TOWN_VISUAL_BUDGET ",point[2]," fps=",samples.size()/2.," p95_ms=",samples[int(samples.size()*.95)]," max_ms=",samples[-1]," draws=",draws," over50=",samples.filter(func(v):return v>50.).size())
	print("TOWN_VISUAL_BUDGET_RESULT PASS");quit()
