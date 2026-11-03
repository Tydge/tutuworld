extends SceneTree
var session: Node
var game: Node3D
var rows: Array=[]
var out:="/Users/wangtaizhi/兔兔的世界/.qa-artifacts/environment-polish-local"
var phase:="before"
func _initialize() -> void:call_deferred("run")
func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+phase+"-"+id+".png")
func measure(id: String,round_: int) -> void:
	for i in range(50):await RenderingServer.frame_post_draw
	var samples: Array[float]=[];var start:=Time.get_ticks_usec();var previous:=start;var draws:=0;var triangles:=0
	while Time.get_ticks_usec()-start<1200000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.);previous=now
		draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		triangles=maxi(triangles,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	samples.sort();var row:={"view":id,"phase":phase,"round":round_,"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"frames":samples.size(),"draws":draws,"primitives":triangles};rows.append(row);print("ENV_PERF ",JSON.stringify(row))
	var f:=FileAccess.open(out+"/"+phase+"-performance.json",FileAccess.WRITE);f.store_string(JSON.stringify({"driver":RenderingServer.get_current_rendering_driver_name(),"output_window":root.size,"output_texture":root.get_texture().get_size(),"scale":root.scaling_3d_scale,"rows":rows},"  "));f.close()
func run() -> void:
	if OS.get_cmdline_user_args().has("--after"):phase="after"
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("环境验收兔","bunny","bow_rose")
	root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1920,1080);root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	for map_id in ["city","valley"]:
		session.state().map_id=map_id;game=load("res://scenes/"+map_id+".tscn").instantiate();root.add_child(game);current_scene=game
		while game.camera==null:await process_frame
		await create_timer(.7).timeout;root.size=Vector2i(1920,1080);root.scaling_3d_scale=sqrt(2000000./(1920.*1080.))
		session.set_process(false);game.hud.hide();game.process_mode=Node.PROCESS_MODE_DISABLED
		var views: Array=[]
		if map_id=="city":
			views=[["fountain",Vector3(0,.2,8),Vector3(8,5,13),Vector3(0,1,0)],["beach",Vector3(5,.2,39),Vector3(12,5,48),Vector3(2,-.6,48)],["walls",Vector3(-6,.2,-19),Vector3(1,3.4,-17),Vector3(-5,2.2,-25)]]
			var closest: Node3D;var distance_:=999.
			for tree in game.scenery.get_children():
				if not str(tree.name).begins_with("Tree"):continue
				var d: float=tree.position.distance_to(Vector3(12,0,6))
				if d<distance_:closest=tree;distance_=d
			var p: Vector3=closest.global_position
			views.append(["bark",p+Vector3(2,.2,2),p+Vector3(2.8,2.1,3),p+Vector3(0,1.3,0)])
		else:
			views=[["bridge",Vector3(-9,.2,7),Vector3(10,5,16),Vector3(-2,.7,4)],["cascade",Vector3(-5,.2,-3),Vector3(5,5.5,-1.5),Vector3(0,1.1,-9)],["cottage",Vector3(11,4.2,-29),Vector3(22,11,-20),Vector3(11,5,-36)],["woodland",Vector3(-23,.2,18),Vector3(-30,5,25),Vector3(-21,.5,15)],["valley-wide",Vector3(-18,2.2,-14),Vector3(-27,12,5),Vector3(0,2,-16)]]
		for view in views:
			game.bunny.visible=view[0]!="bark"
			game.bunny.position=view[1];game.bunny.reset_physics_interpolation();game.camera.position=view[2];game.camera.look_at(view[3]);game.update_lighting(.5)
			for building in game.interiors:building._process(.6)
			game.update_occluders(.6)
			for round_ in range(2):
				await measure(view[0],round_)
				if round_==0:await capture(view[0])
			if map_id=="valley" and view[0]=="cascade":
				game.update_lighting(.90)
				for i in range(20):await RenderingServer.frame_post_draw
				await capture("cascade-night")
		game.queue_free();current_scene=null;await process_frame;await process_frame
	print("ENVIRONMENT_PREVIEW_RESULT PASS groups=",rows.size());quit()
