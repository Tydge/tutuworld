extends SceneTree
## Fixed gameplay cameras with a measured walk, an orbit and the occupied edit viewport.
const Support = preload("res://tests/test_support.gd")
const VIEWS = [
	["plaza", Vector3(0, .12, 9), .12, .22, .36],
	["shops", Vector3(-8, .12, -13), .24, .19, .46],
	["quay", Vector3(13, .2, 39), -2.85, .17, .711],
	["lamplight", Vector3(-4, .12, 11), -.40, .23, .88],
	["parcel", Vector3(79, .12, 7), .35, .8, .39],
]
var failures: Array[String] = []
var city: Node3D
var session: Node
var samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

var last_draw_usec:=0

func rendered_frame() -> void:
	await process_frame
	var now:=Time.get_ticks_usec()
	var elapsed:=float(now-last_draw_usec)/1000000. if last_draw_usec!=0 else 1./60.
	last_draw_usec=now
	# The manual renderer advances shader TIME only when its frame step is supplied.
	RenderingServer.force_draw(true,elapsed)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Coastal walk requires a rendered game window")
		quit(1)
		return
	RenderingServer.set_render_loop_enabled(false)
	session = preload("res://scripts/services/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	session.settings.background_throttle = false
	session.create_character("海岛散步", "bunny", "scarf_green")
	city = preload("res://scenes/city.tscn").instantiate()
	root.add_child(city)
	current_scene = city
	while city.camera == null or city.preparing or not city.navigation.ready_for_paths:
		await rendered_frame()
	session.active = false
	Engine.max_fps = 60
	var output := Support.output_dir()
	var args:=OS.get_cmdline_user_args()
	var sustained_view: String="lamplight" if args.has("--night-soak") else ("parcel" if args.has("--build-soak") else "")
	var sample_us := 4000000 if sustained_view.is_empty() else 60000000
	for view in VIEWS:
		if not sustained_view.is_empty() and view[0] != sustained_view:continue
		city.bunny.position = view[1]
		city.bunny.velocity = Vector3.ZERO
		city.bunny.reset_physics_interpolation()
		session.set_player_position(city.bunny.position)
		session.state().time = view[4] * 3600.
		city.update_lighting(view[4])
		city.yaw = view[2]
		city.pitch = view[3]
		var editing: bool = view[0] == "parcel"
		if editing:
			if not session.buy_land("east_nw").ok or not city.build_mode.open_nearby_parcel().ok:
				push_error("Could not enter the purchased plot")
				quit(1)
				return
		for i in range(110):
			await rendered_frame()
		if not editing:
			city.hud.hide()
		await rendered_frame()
		var shot := root.get_texture().get_image()
		shot.resize(1440, roundi(1440. * shot.get_height() / shot.get_width()), Image.INTERPOLATE_LANCZOS)
		shot.save_jpg(output.path_join(str(view[0]) + ".jpg"), .93)
		if not editing:
			city.hud.show()
		var walking: bool = view[0] == "shops"
		if walking:
			Input.action_press("move_right")
		# Keep the camera path deterministic at different frame rates.
		var intervals: Array[float] = []
		var draws := 0
		var first := Time.get_ticks_usec()
		var last := first
		while last - first < sample_us:
			var angle: float = view[2] + .6 * sin((last - first) * .0000014)
			if editing:
				city.build_mode.yaw = angle
				city.build_mode.update_camera()
			else:
				city.yaw = angle
			await rendered_frame()
			var now := Time.get_ticks_usec()
			var ms:=(now-last)/1000.
			intervals.append(ms)
			if ms>50.:
				print("COASTAL_SLOW_FRAME ",view[0]," ms=",ms," since_start_ms=",(now-first)/1000.," cpu_setup_ms=",RenderingServer.get_frame_setup_time_cpu())
			last = now
			draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if walking:
			Input.action_release("move_right")
			if city.bunny.position.distance_to(view[1]) < 2.:
				push_error("Shop walk did not move the player")
				quit(1)
				return
		intervals.sort()
		var row := {"view": view[0], "frames": intervals.size(), "fps": intervals.size() * 1e6 / (last - first),
			"p95_ms": intervals[floori(intervals.size() * .95)], "p99_ms": intervals[floori(intervals.size() * .99)],
			"max_ms": intervals[-1], "over50": intervals.filter(func(ms): return ms > 50.).size(), "draws": draws}
		if row.fps < 58. or row.p95_ms > 25. or row.over50 > 0:
			failures.append(view[0])
		samples.append(row)
		print("COASTAL_TOWN ", JSON.stringify(row))
	var file := FileAccess.open(output.path_join("timings.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"views": samples, "width": root.size.x, "height": root.size.y,
		"scale_3d": root.scaling_3d_scale, "msaa": root.msaa_3d, "fps_cap": Engine.max_fps, "seconds_per_view": sample_us / 1000000}, "\t"))
	file.close()
	print("COASTAL_TOWN_WALK_RESULT ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	quit(0 if failures.is_empty() else 1)
