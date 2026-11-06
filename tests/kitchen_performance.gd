extends SceneTree
const A=preload("res://scripts/services/local_authority.gd")
var session: Node
var game: Node3D
func _initialize() -> void: call_deferred("run")
func sample(label_: String,seconds: float) -> void:
	var times: Array[float]=[]
	var start:=Time.get_ticks_usec()
	var last:=start
	while Time.get_ticks_usec()-start<seconds*1000000:
		await process_frame
		var now:=Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last=now
	times.sort()
	print("KITCHEN_BENCH ",label_," frames=",times.size()," median=",times[times.size()/2]," p95=",times[int(times.size()*.95)]," max=",times[-1]," over50=",times.filter(func(t): return t>50).size())
func run() -> void:
	root.size=Vector2i(1440,900);Engine.max_fps=60
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	for species in ["bunny","cat_teacher","panda"]:
		session.authority=A.new()
		session.settings.player_species=species
		session.state().species=species;session.state().skills.cooking=5;session.state().skill_experience.cooking=preload("res://scripts/services/character_stats.gd").skill_start(5)
		session.state().time=3300
		game=load("res://scenes/city.tscn").instantiate()
		root.add_child(game)
		while game.preparing: await process_frame
		game.bunny.position=Vector3(21,.15,-19.8)
		game.bunny.reset_physics_interpolation()
		session.set_player_position(game.bunny.position)
		game.yaw=.8
		game.pitch=.55
		game.distance_=9
		for id in ["pumpkin","sea_salt","cream"]: session.authority.add(id,3)
		await create_timer(.5).timeout
		var start:=Time.get_ticks_usec()
		var cooking: Dictionary=game.begin_cooking("pumpkin_soup")
		if not cooking.ok:push_error("Performance fixture could not start cooking: "+str(cooking));quit(1);return
		print("KITCHEN_START ",species," cook_ms=",(Time.get_ticks_usec()-start)/1000.0)
		await sample(species+"_cooking",5)
		game.cancel_action()
		session.authority.add("food_pumpkin_soup",1)
		game.bunny.position=Vector3(28.2,.15,-17.5)
		game.bunny.reset_physics_interpolation()
		session.set_player_position(game.bunny.position)
		game.yaw=PI-.65
		game.pitch=.42
		game.distance_=8
		await create_timer(.5).timeout
		start=Time.get_ticks_usec()
		var eating: Dictionary=game.begin_dining("food_pumpkin_soup")
		if not eating.ok:push_error("Performance fixture could not start eating: "+str(eating));quit(1);return
		print("KITCHEN_START ",species," eat_ms=",(Time.get_ticks_usec()-start)/1000.0)
		await sample(species+"_eating",5)
		game.cancel_action()
		game.queue_free()
		await process_frame
		await process_frame
	print("KITCHEN_PERFORMANCE_COMPLETE")
	quit()
