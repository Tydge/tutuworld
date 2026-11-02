extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=load("res://scripts/services/session.gd").new()
	s.name="Session"
	root.add_child(s)
	var world=load("res://scenes/city.tscn").instantiate()
	root.add_child(world)
	for test in [["park",Vector3(0,.1,9),.35],["farm",Vector3(29,.1,11),.35],["night",Vector3(0,.1,9),.90]]:
		world.bunny.position=test[1]
		s.authority.state.time=3600*test[2]
		await create_timer(4).timeout
		print("BENCHMARK ",test[0]," fps=",Engine.get_frames_per_second()," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)," frame=",Performance.get_monitor(Performance.TIME_PROCESS)," physics=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	quit()
