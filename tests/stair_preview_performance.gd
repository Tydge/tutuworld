extends SceneTree
const L=preload("res://scripts/building/layout.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("楼板预览性能","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	while not city.navigation.sampling_ready:await physics_frame
	# This CPU-only headless probe does not mix audio. Release the looping
	# playbacks before measuring and allow their audio-server commands to flush.
	for player in city.find_children("*","AudioStreamPlayer",true,false)+city.find_children("*","AudioStreamPlayer3D",true,false):
		player.stop();player.stream=null
	await create_timer(.5).timeout
	city.set_process(false);city.bunny.set_physics_process(false);var editor=city.build_mode;editor.open_editor();editor.set_process(false)
	var data:=L.add(L.empty(),{"type":"floor","a":[110.,1.],"b":[126.,16.]})
	for line in [[[110.,1.],[126.,1.]],[[110.,1.],[110.,16.]],[[126.,1.],[126.,16.]],[[110.,16.],[126.,16.]]]:data=L.add(data,{"type":"wall","a":line[0],"b":line[1]})
	check(editor.commit(data),"240 sqm closed-room preview fixture");editor.choose_tool("stairs:u");var start:=Time.get_ticks_usec();editor.update_ghost(Vector2(119,7));var cold: float=(Time.get_ticks_usec()-start)/1000.;var keys: Array=editor.floor_preview_cache.keys();var times: Array=[]
	for i in range(12):
		start=Time.get_ticks_usec();editor.update_ghost(Vector2(119+(i%4)*.5,7));times.append((Time.get_ticks_usec()-start)/1000.)
	times.sort();var shared:=0
	for key in keys:
		if editor.floor_preview_cache.has(key):shared+=1
	check(shared>keys.size()/2 and editor.floor_preview_cache.size()<384,"Whole-slab previews retain shared chunk mesh resources with bounded cache")
	check(editor.preview.find_children("*","CollisionObject3D",true,false).all(func(body):return body.collision_layer==0),"Reused preview never introduces physical collision")
	print("STAIR_SLAB_PREVIEW_CPU_MS cold=",cold," warm_median=",times[times.size()/2]," warm_max=",times[-1]," cached_chunks=",editor.floor_preview_cache.size())
	city.queue_free();await create_timer(.1).timeout
	print("STAIR_PREVIEW_PERFORMANCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
