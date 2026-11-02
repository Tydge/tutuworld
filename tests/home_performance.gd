extends SceneTree
const S=preload("res://scripts/services/session.gd")
var session: Node
var game: Node3D
var direction:=""
func _initialize() -> void: call_deferred("run")
func set_direction(action: String) -> void:
	if action==direction: return
	if direction!="": Input.action_release(direction)
	direction=action
	if direction!="": Input.action_press(direction)
func sample(label_: String,seconds: float,mode: String) -> void:
	var values: Array[float]=[];var cpu: Array[float]=[]
	var last:=Time.get_ticks_usec();var start:=last
	var over25:=0;var over50:=0
	while Time.get_ticks_usec()-start<seconds*1000000:
		var t: float=(Time.get_ticks_usec()-start)/1000000.0
		if mode=="orbit": game.yaw=t*TAU/seconds
		elif mode=="entry":
			set_direction("move_up" if t>.8 and t<3.7 else ("move_down" if t>4.5 and t<7.5 else ""))
		await process_frame
		var now:=Time.get_ticks_usec();var ms: float=(now-last)/1000.0
		values.append(ms);cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		if ms>25: over25+=1
		if ms>50: over50+=1
		last=now
	set_direction("");values.sort();cpu.sort()
	print("HOME_BENCH ",label_," frames=",values.size()," p95=",values[int(values.size()*.95)]," p99=",values[int(values.size()*.99)]," max=",values[-1]," over25=",over25," over50=",over50," cpu95=",cpu[int(cpu.size()*.95)]," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func place(p: Vector3) -> void:
	game.bunny.position=game.home.to_global(p);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.yaw=0;game.pitch=.46;game.distance_=13.5
	await create_timer(.7).timeout
func run() -> void:
	root.size=Vector2i(1440,900)
	session=S.new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.create_character("风铃" if species=="bunny" else "奶糖",species,"vest_sage")
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		while game.preparing: await process_frame
		session.active=false;game.hud.toast.hide()
		for time_ in [.5,.92]:
			session.state().time=time_*3600;game.update_lighting()
			var phase: String="day" if time_==.5 else "night"
			await place(Vector3(0,.3,8.2))
			await sample(species+"_"+phase+"_outside_orbit",4,"orbit")
			await place(Vector3(0,.3,8.0))
			if not game.home.door_open: game.home.toggle_door(game.bunny)
			await sample(species+"_"+phase+"_door_enter_exit",8,"entry")
			await place(Vector3(0,.3,.2))
			await sample(species+"_"+phase+"_inside_orbit",4,"orbit")
		game.queue_free();await process_frame;await process_frame
	print("HOME_PERFORMANCE_COMPLETE");quit()
