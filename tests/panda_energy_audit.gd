extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
var session: Node
var game: Node3D
func _initialize() -> void: call_deferred("run")
func casters(actor: Node) -> int:
	var count_:=0
	for mesh in actor.find_children("InkOutline","MeshInstance3D",true,false):
		if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: count_+=1
	return count_
func sample(label_: String,seconds: float) -> void:
	var frames: Array[float]=[];var cpu: Array[float]=[];var render: Array[float]=[]
	var start:=Time.get_ticks_usec();var last:=start;var max_draws:=0.0;var over50:=0
	while Time.get_ticks_usec()-start<seconds*1000000:
		await process_frame
		var now:=Time.get_ticks_usec();var ms: float=(now-last)/1000.0;last=now
		frames.append(ms);cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		render.append(RenderingServer.get_frame_setup_time_cpu())
		max_draws=maxf(max_draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if ms>50: over50+=1
	frames.sort();cpu.sort();render.sort()
	print("ENERGY_AUDIT ",label_," fps=",frames.size()/seconds," p95_ms=",frames[int(frames.size()*.95)]," max_ms=",frames[-1]," over50=",over50," cpu_process95_ms=",cpu[int(cpu.size()*.95)]," render_setup95_ms=",render[int(render.size()*.95)]," draws_max=",max_draws)
func run() -> void:
	root.size=Vector2i(2400,1440)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("能耗检查","panda","vest_sage");session.settings.render_quality="balanced"
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
	while game.preparing or not game.navigation.ready_for_paths: await process_frame
	session.active=false;game.bunny.can_move=false
	print("ENERGY_CONFIG max_fps=",Engine.max_fps," vsync=",DisplayServer.window_get_vsync_mode()," screen_hz=",DisplayServer.screen_get_refresh_rate()," output=",root.size," scale=",root.scaling_3d_scale," msaa=",root.msaa_3d," ssao=",game.atmosphere.ssao_enabled)
	for species in Animals.Catalog.ids():
		var raw: Node=load(Animals.SCENES[species]).instantiate();var actual:=Animals.create(species)
		print("OUTLINE_CASTERS ",species," raw=",casters(raw)," runtime=",casters(actual));raw.free();actual.free()
	game.hud.open_panel("profile");await create_timer(.25).timeout;game.hud.close_panel()
	var preview: Control=game.hud.character_sheet.preview;var clock: float=preview.actor.clock
	await create_timer(.4).timeout
	print("HIDDEN_PREVIEW visible=",preview.is_visible_in_tree()," can_process=",preview.can_process()," pose_clock_change=",preview.actor.clock-clock," viewport_update_mode=",preview.viewport.render_target_update_mode)
	for phase in ["day","night"]:
		session.state().time=1800 if phase=="day" else 3300;game.update_lighting()
		game.bunny.position=Vector3(0,.2,7);game.bunny.reset_physics_interpolation();game.yaw=.2;game.distance_=13.5
		await create_timer(.5).timeout
		await sample(phase+"_balanced_default",4)
	print("PANDA_ENERGY_AUDIT_COMPLETE");game.queue_free();await process_frame;await process_frame;quit()
