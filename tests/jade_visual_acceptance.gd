extends SceneTree
## Independent player-eye captures and moving-frame timings. See --compare for the other islands.
const Routes=preload("res://scripts/services/map_routes.gd")
const J=preload("res://scripts/jade/layout.gd")
const Ice=preload("res://scripts/icefield/icefield_layout.gd")
const Valley=preload("res://scripts/valley/valley_layout.gd")
const SAMPLE_SECONDS=4.0
const WARMUP_SECONDS=1.8
var session: Node
var game: Node3D
var output: String
var rows: Array=[]
var failures: Array=[]
var startup_ms: Dictionary={}
func _initialize() -> void:call_deferred("run")

func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	RenderingServer.set_render_loop_enabled(false)
	root.size=Vector2i(2400,1440)
	session=preload("res://scripts/services/session.gd").new()
	session.name="Session";root.add_child(session)
	session.settings.background_throttle=false
	session.settings.render_quality="balanced"
	session.create_character("玉京踏查","bunny","scarf_green")
	Engine.max_fps=60
	var maps: Array=["city","valley","icefield","jade"] if OS.get_cmdline_user_args().has("--compare") else ["jade"]
	for map in maps:await visit(map)
	var report:={"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"output_px":[root.size.x,root.size.y],"scale_3d":root.scaling_3d_scale,"actual_cap":Engine.max_fps,"startup_ms":startup_ms,"warmup_seconds":WARMUP_SECONDS,"sample_seconds":SAMPLE_SECONDS,"samples":rows,"failures":failures}
	var file:=FileAccess.open(output+"/motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("JADE_FRAME_BUDGET failures=",failures)
	session.free();quit(int(not failures.is_empty()))

func views(map: String) -> Array:
	match map:
		"city":return [["fountain-day",0.,9.,.5,.26],["quay-night",12.,38.,.91,.0]]
		"valley":return [["woods-day",-13.,10.,.5,.0],["valley-port-night",-16.8,94.4,.91,.0]]
		"icefield":return [["shops-day",-79.,12.,.5,.0],["town-night",-63.,43.,.91,.0]]
		_:return [["south-market",J.lane(163),163.,.48,.05],["lantern-market",J.lane(134),134.,.91,.0],["bridge",0.,11.,.40,.0],["garden",105.,-20.,.5,-.3],["palace",2.,-136.,.43,.0]]

func floor_at(map: String,x: float,z: float) -> float:
	match map:
		"jade":return J.foot(x,z)
		"valley":return Valley.walk_height(x,z)
		"icefield":return Ice.walk_height(x,z)
		_:return .1

func visit(map: String) -> void:
	var entered:=Time.get_ticks_usec()
	session.state().map_id=map
	session.state().player_position=Routes.arrival(map)
	game=load(Routes.scene(map)).instantiate()
	root.add_child(game);current_scene=game
	while game.preparing or not is_instance_valid(game.camera) or not game.navigation.ready_for_paths:
		await process_frame;RenderingServer.force_draw()
	startup_ms[map]=snappedf((Time.get_ticks_usec()-entered)/1000.,.1)
	session.active=false
	for view in views(map):await sample_route(map,view)
	if map=="jade":
		if OS.get_cmdline_user_args().has("--repeat-market"):
			for i in range(3):
				var market: Array=views(map)[0].duplicate()
				market[0]+="-repeat-"+str(i+1)
				await sample_route(map,market)
		await capture_landmarks()
		if OS.get_cmdline_user_args().has("--capture-market-hours"):await capture_market_hours()
	game.free();await process_frame

func sample_route(map: String,view: Array) -> void:
	game.bunny.position=Vector3(view[1],floor_at(map,view[1],view[2])+.06,view[2])
	game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	session.state().time=view[3]*3600.;game.update_lighting()
	game.distance_=11.5;game.pitch=.19;game.yaw=view[4]
	game.camera_focus=game.bunny.position+Vector3.UP*1.35
	var warm:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm<int(WARMUP_SECONDS*1e6):
		await process_frame;RenderingServer.force_draw()
	var foot_start: Vector3=game.bunny.position
	var samples: Array[float]=[];var process_ms: Array[float]=[];var calls:=0;var primitives:=0
	var slow_frames: Array[Dictionary]=[]
	var start:=Time.get_ticks_usec();var last:=start
	Input.action_press("move_up")
	while last-start<int(SAMPLE_SECONDS*1e6):
		var secs:=(last-start)/1e6
		game.yaw=view[4]+.12*sin(secs*PI/2.)
		await process_frame;RenderingServer.force_draw()
		var now:=Time.get_ticks_usec();samples.append((now-last)/1000.);last=now
		if samples[-1]>25.:
			var foot: Vector3=game.bunny.position
			slow_frames.append({"elapsed_s":snappedf((now-start)*.000001,.001),"frame_ms":snappedf(samples[-1],.01),"position":[snappedf(foot.x,.01),snappedf(foot.z,.01)],"draws":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))})
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
		calls=maxi(calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives=maxi(primitives,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	Input.action_release("move_up")
	var displacement:=foot_start.distance_to(game.bunny.position)
	samples.sort();process_ms.sort()
	var row:={"map":map,"view":view[0],"n":samples.size(),"moved_m":snappedf(displacement,.01),"fps":snappedf(samples.size()*1e6/(last-start),.1),"p50_ms":quantile(samples,.5),"p95_ms":quantile(samples,.95),"p99_ms":quantile(samples,.99),"max_ms":samples[-1],"over25":samples.filter(func(t):return t>25.).size(),"over50":samples.filter(func(t):return t>50.).size(),"sampled_process_monitor_p95_ms":quantile(process_ms,.95),"output_px":[root.size.x,root.size.y],"scale_3d":root.scaling_3d_scale,"max_draws":calls,"max_primitives":primitives,"slow_frames":slow_frames}
	rows.append(row);print("MOTION_SAMPLE ",JSON.stringify(row))
	# Same spike and P95 limits as the existing icefield-performance test.
	if row.p95_ms>25. or row.over50>0:
		failures.append(map+"/"+view[0]+"/frames")
	# The public stairs span the route from z=-136 toward z=-150 at walking speed.
	if displacement<(9. if map=="jade" and view[0]=="palace" else 1.):
		failures.append(map+"/"+view[0]+"/obstructed")
	await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_jpg(output+"/"+map+"-"+str(view[0])+".jpg",.90)

func quantile(sorted: Array[float],q: float) -> float:
	return sorted[clampi(ceili(q*sorted.size())-1,0,sorted.size()-1)]

func capture_landmarks() -> void:
	# These stills are outside timed samples. They use the player's actual collision-resolved camera.
	var tea: Node3D=game.scenery.get_node("Hall_tea")
	var inn: Node3D=game.scenery.get_node("Hall_inn")
	var plots: Array=J.farm()
	var field: Vector3=J.point(plots[0].x+8.,plots[0].z+7.)
	var shots: Array=[
		["arrival",game.respawn_position(),0.,.18,12.,.46],
		["post-from-street",J.point(-45.8,36.5),.12,.19,10.5,.44],
		["river-side-alley",J.point(-52.,18.),1.53,.24,10.5,.44],
		["artisan-yard",J.point(-51.,139.),.03,.24,10.4,.42],
		["eaves-from-street",J.point(J.lane(51.)+4.,51.),-1.22,.12,7.4,.35],
		["forecourt-approach",J.point(-.5,-39.),-.08,.19,10.3,.41],
		["drum-terrace",J.point(-6.2,-57.),.91,.17,8.2,.39],
		["baihe-terrace",J.point(6.4,-65.),-.92,.20,8.5,.40],
		["bronze-crane-court",J.point(4.7,-135.),-.12,.19,9.,.37],
		["bailian-shopfront",J.point(J.lane(111.)-.7,111.),1.1,.21,7.7,.39],
		["steamers-and-sweets",J.point(J.lane(128.)-4.7,128.),1.44,.20,7.1,.73],
		["almond-trays",J.point(J.lane(72.)+6.5,72.),-1.37,.20,7.1,.39],
		["street-level-arcade",J.point(J.lane(112)-3.2,112.),.45,.20,9.7,.39],
		["evening-spice-house",J.point(J.lane(130.)-3.,130.),.98,.18,8.5,.78],
		["garden-under-pine",J.point(121.,-39.),-.46,.20,8.3,.53],
		["river-garden",J.point(124.,-42.),.38,.22,8.3,.47],
		["well-field",field,-1.24,.32,12.,.37],
		["residential-lots",J.point(J.LOT_ORIGINS[0].x-2.,J.LOT_ORIGINS[0].y+13.),-1.35,.23,12.,.50],
		["teahouse-interior",tea.to_global(Vector3(1.1,tea.floor_level+.07,.55)),tea.rotation.y+.64,.37,7.3,.81],
		["inn-upper-gallery",inn.to_global(Vector3(-1.6,inn.wall_height+.08,1.2)),inn.rotation.y-.55,.25,7.6,.55]]

	# Inspect the pastry counter along its frontage as well as from underneath the public staircase.
	var pastry_room: Node3D=game.scenery.get_node("Shop_almond")
	var pastry_counter: Node3D=pastry_room.get_node("Front").get_children().filter(func(node):return node.get_meta("furniture_kind","")=="jade_pastry_board")[0]
	var pastry: Vector3=pastry_counter.global_position
	shots.append(["almond-counter-from-lane",J.point(pastry.x-1.8,pastry.z+3.8),-.02,.22,5.3,.45])
	shots.append(["almond-counter-from-corner",J.point(pastry.x-3.3,pastry.z-2.3),-1.96,.27,5.2,.60])
	var seed_shop: Node3D=game.scenery.get_node("Shop_farm")
	var seeds: Node3D=seed_shop.get_node("Front").get_children().filter(func(node):return node.get_meta("furniture_kind","")=="jade_seed_bins")[0]
	var seed_view: Vector3=seeds.to_global(Vector3(1.8,0,3.6))
	shots.append(["grain-shop-counter",J.point(seed_view.x,seed_view.z),seed_shop.rotation.y+.12,.24,6.3,.42])
	shots.append(["almond-counter-side",J.point(pastry.x-4.3,pastry.z+3.3),.15,.20,6.6,.47])
	var seed_side: Vector3=seeds.to_global(Vector3(-4.15,0,3.9))
	shots.append(["grain-bins-side",J.point(seed_side.x,seed_side.z),seed_shop.rotation.y+.24,.24,6.7,.42])
	var bell: Node3D=game.scenery.get_node("Hall_duty")
	if bell.shell_kind=="clocktower":
		shots.append(["bell-gallery",bell.to_global(Vector3(-1.25,bell.wall_height+.08,1.85)),bell.rotation.y-.44,.33,7.4,.43])
	var upstairs:=inn.to_global(Vector3(-1.6,inn.wall_height+.08,1.2))
	for angle in [1.35,2.83]:shots.append(["inn-upper-orbit-"+str(angle),upstairs,inn.rotation.y+angle,.28,7.6,.55])
	var bridges: Array=game.scenery.get_children().filter(func(n):return n.get_meta("furniture_kind","") in ["jade_street_gallery","jade_street_gallery_reverse"])
	for bridge in bridges:
		if bridge.position.z<90.:
			var top: Vector3=bridge.to_global(Vector3(1.35,4.59,0))
			shots.append(["market-upper-view",top,bridge.rotation.y+.45,.25,7.,.39])
			shots.append(["market-upper-reverse",top,bridge.rotation.y-2.1,.25,7.,.39])
		else:
			var point: Vector3=bridge.to_global(Vector3(1.5,0.,3.6))
			shots.append(["market-under-gallery",J.point(point.x,point.z),bridge.rotation.y-.63,.25,8.7,.64])
	for shot in shots:
		game.bunny.global_position=shot[1]+Vector3.UP*.035
		game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
		game.camera_focus=game.bunny.position+Vector3.UP*1.35
		game.yaw=shot[2];game.pitch=shot[3];game.distance_=shot[4]
		session.state().time=shot[5]*3600.;game.update_lighting()
		var changed:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-changed<900000:
			await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_jpg(output+"/jade-"+str(shot[0])+".jpg",.90)
		print("PLAYER_VIEW ",shot[0]," grounded=",game.bunny.is_on_floor()," position=",game.bunny.global_position)

func capture_market_hours() -> void:
	var original_scale:=Engine.time_scale
	var original_ticks:=Engine.physics_ticks_per_second
	for event in [[8.,146.,"sort_seed","morning-customers"],[18.,127.,"tea","evening-customers"]]:
		var hour: float=event[0]
		var z: float=event[1]
		var actor_point:=J.point(J.lane(z+7.)+1.2,z+7.)
		game.bunny.global_position=actor_point;game.bunny.velocity=Vector3.ZERO
		game.bunny.reset_physics_interpolation();game.camera_focus=actor_point+Vector3.UP*1.35
		game.pitch=.17;game.yaw=.33;game.distance_=11.
		session.state().time=hour*150.;game.update_lighting()
		# All residents retain their real drivers. Advance at the same simulated physics interval.
		Engine.physics_ticks_per_second=original_ticks*4;Engine.time_scale=original_scale*4.
		var crowd: Array=[]
		var gathering_seen:=false
		for frame in range(original_ticks*150):
			await physics_frame
			if frame%12!=0:continue
			crowd.clear()
			var acting:=false
			for id in [1,2,8]:
				var resident=game.targets["JadeCitizen_"+str(id)].node
				if absf(resident.position.x-J.lane(z)+3.)<11. and absf(resident.position.z-z)<11.:
					crowd.append([id,resident.position,resident.action])
					acting=acting or resident.action==event[2]
			if crowd.size()==3 and acting:
				gathering_seen=true;break
		if not gathering_seen:failures.append("jade/"+str(event[3])+"/customers")
		Engine.physics_ticks_per_second=original_ticks;Engine.time_scale=original_scale
		for frame in range(5):await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_jpg(output+"/jade-"+str(event[3])+".jpg",.90)
		print("MARKET_PERIOD_VIEW ",event[3]," observed=",crowd)
