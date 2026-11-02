extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
func _initialize() -> void: call_deferred("run")
func sample(label_: String,seconds: float,orbit: bool=true) -> void:
	var values: Array[float]=[]
	var last:=Time.get_ticks_usec();var start:=last;var over50:=0;var draws:=0.0
	while Time.get_ticks_usec()-start<seconds*1000000:
		var t: float=(Time.get_ticks_usec()-start)/1000000.0
		if orbit: game.yaw=t*TAU/seconds
		await process_frame
		var now:=Time.get_ticks_usec();var ms: float=(now-last)/1000.0
		values.append(ms);last=now
		if ms>50: over50+=1
		draws=maxf(draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	values.sort()
	print("STAMINA_BENCH ",label_," frames=",values.size()," p95=",values[int(values.size()*.95)]," max=",values[-1]," over50=",over50," draws=",draws)
func travel(p: Vector3) -> void:
	game.bunny.position=p;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.set_player_position(p);await create_timer(.5).timeout
func run() -> void:
	Engine.max_fps=60
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.create_character("晨兔" if species=="bunny" else "夜猫",species,"vest_sage")
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		while game.preparing: await process_frame
		session.active=false;game.hud.toast.hide();game.distance_=13.5;game.pitch=.46
		for phase in ["day","night"]:
			session.state().time=1800 if phase=="day" else 3300;game.update_lighting()
			await travel(Vector3(0,.2,7));await sample(species+"_"+phase+"_park",2.5)
			await travel(Vector3(-5,.2,-25.7));await sample(species+"_"+phase+"_shop",2.5)
		game.hud.open_panel("wardrobe");await sample(species+"_wardrobe",2,false);game.hud.close_panel()
		if species=="cat_teacher":
			session.state().time=1800;game.update_lighting();session.authority.add("watering_can",1)
			session.state().plots.plot_00={"crop":"carrot","growth":0,"water_stage":-1,"weed_stage":0};game.refresh_world()
			await travel(Vector3(22,.2,-7.6));session.active=true;game.begin_action("water","plot_00");await sample("cat_water_effect",2.3,false)
		game.queue_free();await process_frame;await process_frame
	print("STAMINA_SCENE_PERFORMANCE_COMPLETE");quit()
