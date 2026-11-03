extends SceneTree
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var out: String
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func photo(name_: String) -> Image:
	for i in range(5):await process_frame;RenderingServer.force_draw()
	var img:=root.get_texture().get_image();img.save_png(out+"/"+name_+".png");return img
func rms(capture: AudioEffectCapture,voice: AudioStreamPlayer3D) -> float:
	voice.play(1.);await create_timer(.25).timeout;capture.clear_buffer();await create_timer(.7).timeout
	var frames:=capture.get_frames_available()
	if frames<=0:return 0.
	var samples:=capture.get_buffer(frames);var total:=0.
	for sample in samples:total+=sample.length_squared()
	return sqrt(total/(samples.size()*2.))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("火光与声音兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await create_timer(.4).timeout
	var ambience: Node=city.get_node("SpatialAmbience")
	check(ambience.listener.is_current() and ambience.get_children().filter(func(node):return node is AudioStreamPlayer3D).size()==2,"City uses one avatar listener and only two spatial looping voices")
	for player in [ambience.waves,ambience.gulls]:check(player.stream.loop and player.stream.get_length()>20 and player.max_distance>0 and player.doppler_tracking==0,"Imported ambience loops continuously and is culled beyond its audible radius")
	var bus:=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(bus,"AmbienceQA");var capture:=AudioEffectCapture.new();capture.buffer_length=2.;AudioServer.add_bus_effect(bus,capture);ambience.waves.bus="AmbienceQA"
	city.set_process(false);city.bunny.set_physics_process(false);city.bunny.position=Vector3(48,.2,0);city.bunny.reset_physics_interpolation();ambience.update_sources();ambience.update_listener();var near: float=await rms(capture,ambience.waves)
	var listener_before: Vector3=ambience.listener.global_position;city.camera.position+=Vector3(0,30,30);ambience.update_listener();check(ambience.listener.global_position.is_equal_approx(listener_before),"Camera zoom does not change the avatar's hearing position")
	city.bunny.position=Vector3(0,.2,0);city.bunny.reset_physics_interpolation();ambience.update_sources();ambience.update_listener();var far: float=await rms(capture,ambience.waves)
	print("SPATIAL_AUDIO_RMS near=",near," far=",far)
	check(near>.00001 and far<near*.4,"Real audio mix becomes substantially quieter away from the coast")
	ambience.waves.bus="Master";AudioServer.remove_bus(bus)
	var data:=L.add(L.empty(),{"type":"floor","a":[73.,5.],"b":[85.,15.],"color":"cda56e","style":"wood"})
	for pair in [[[73.,5.],[85.,5.]],[[85.,5.],[85.,15.]],[[85.,15.],[73.,15.]],[[73.,15.],[73.,5.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
	data=L.add(data,{"type":"roof","a":[73.,5.],"b":[85.,15.]});data=L.add(data,{"type":"object","kind":"hearth","position":[79.,6.],"yaw":0.})
	var editor: Node=city.build_mode;editor.open_editor();check(editor.commit(data),"The fireplace occupies a real independently editable room")
	var row: Dictionary=editor.layout.elements.filter(func(item):return item.get("kind","")=="hearth")[0];var fire: SpotLight3D=editor.room.render_cache[row.id].node.get_node("FixtureFireLight")
	editor.set_process(false);editor.ui.hide();editor.grid.hide();editor.room.set_editor_view(true,false);city.bunny.position=Vector3(79,.2,10);city.bunny.reset_physics_interpolation();city.update_lighting(.92);city.camera.position=Vector3(84,5,15);city.camera.look_at(Vector3(79,1,8))
	var effects: Node3D=editor.room.render_cache[row.id].node.get_node("Part_effects");effects.hide()
	fire.hide();var off:=await photo("firelight-off");fire.show();var on:=await photo("firelight-on");var difference:=0.
	for y in range(0,on.get_height(),4):
		for x in range(0,on.get_width(),4):
			var a:=off.get_pixel(x,y);var b:=on.get_pixel(x,y);difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	check(difference>10.,"Actual fireplace light changes nearby walls and floor pixels with animated flames hidden");effects.show();await photo("firelight-atmosphere")
	editor.close_editor();city.queue_free();await process_frame
	city=load("res://scenes/valley.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout
	var valley: Node=city.get_node("SpatialAmbience");check(valley.creek!=null and valley.creek.stream.loop and valley.get_children().filter(func(node):return node is AudioStreamPlayer3D).size()==3,"Valley adds one continuous creek voice, without duplicating decoders along the river")
	var point: Vector3=valley.creek_point(Vector2(10,-15));check(absf(point.x-preload("res://scripts/valley/valley_layout.gd").river_x(point.z))<.03,"The stream emitter follows the actual river shape and water height")
	city.queue_free();await process_frame;await create_timer(.2).timeout
	print("AMBIENT_FIRE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);call_deferred("finish")
func finish() -> void:quit(0 if failures.is_empty() else 1)
