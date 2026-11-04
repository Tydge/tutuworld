extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Access=preload("res://scripts/city/furniture_access.gd")
const Factory=preload("res://scripts/building/module_factory.gd")
var city: Node3D
var session: Node
var checks:=0
var failures: Array=[]
var output: String
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func press_e() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=false;Input.parse_input_event(event);await process_frame
func approach(point: Vector3) -> void:
	city.bunny.stand_up(point);city.bunny.velocity=Vector3.ZERO;city.bunny.reset_physics_interpolation();session.set_player_position(point)
	await physics_frame;await physics_frame;city.update_target()
func photo(name_: String) -> void:
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/"+name_+".png")
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("床边互动兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);session.active=false
	var editor: Node=city.build_mode;var data:=L.add(L.empty(),{"type":"floor","a":[62.,0.],"b":[96.,25.]})
	for pair in [[[64.,1.],[69.,1.]],[[69.,1.],[69.,11.]],[[69.,11.],[64.,11.]],[[64.,11.],[64.,1.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
	for kind in ["bed","canopy_bed","cloud_bed"]:
		editor.open_editor();var layout:=L.add(data,{"type":"object","kind":kind,"position":[65.6,5.],"yaw":0.});check(editor.commit(layout),"A bed fits a narrow room with its left approach behind a wall: "+kind);editor.close_editor()
		var row: Dictionary=editor.layout.elements.filter(func(item):return item.get("kind","")==kind)[0];var bed: Node3D=editor.room.render_cache[row.id].node;var id:="build:"+str(row.id)
		for point in [Vector3(67.8,.2,5.),Vector3(65.6,.2,8.2)]:
			await approach(point);check(city.current_target==id and city.hud.prompt.text.contains("躺下来"),"A real E prompt appears at the right side or foot without selecting a target: "+kind)
			await press_e();check(city.sleep_active and city.bunny.sleeping and session.state().rest_bed==id,"The actual E key sleeps in the nearby furniture: "+kind)
			if city.sleep_active:await press_e()
			check(not city.sleep_active and city.bunny.can_move and city.bunny.position.distance_to(point)<.2,"E wakes on the same accessible side inside the room: "+kind)
		await approach(Vector3(62.8,.2,5.));check(city.current_target!=id,"A nearby bed cannot be used through its left wall: "+kind)
		await approach(Vector3(65.6,.2,8.2));await press_e()
		var blocked_approach:=preload("res://scripts/geometry.gd").solid_box(city,Vector3(65.6,1.2,8.2),Vector3(1.8,2.4,1.5),"BlockedApproach");blocked_approach.collision_layer=4;await physics_frame;await physics_frame;await press_e()
		check(not city.sleep_active and Access.same_room(city,bed,city.bunny.position) and city.bunny.position.x>66.9,"An occupied approach chooses a clear side of the same room, never the fixed left exit: "+kind)
		blocked_approach.free();await physics_frame;await approach(Vector3(65.6,.2,8.2));await press_e()
		var obstruction:=preload("res://scripts/geometry.gd").solid_box(city,Vector3(66.5,1.2,6.),Vector3(5.,2.4,10.1),"TemporarilyBlockedRoom");obstruction.collision_layer=4;await physics_frame;await physics_frame
		await press_e();check(city.sleep_active and city.bunny.sleeping,"No clear exit keeps the sleeper in bed instead of teleporting outside: "+kind)
		obstruction.free();await physics_frame;await physics_frame;await press_e();check(not city.sleep_active and Access.same_room(city,bed,city.bunny.position),"Freeing a real exit permits waking in the same room: "+kind)
		city.camera.position=Vector3(71,5,13);city.camera.look_at(bed.global_position+Vector3.UP);await photo(kind+"-bedside")
	# Every buildable seat uses its own object perimeter and the actual keyboard path.
	for kind in ["sofa","forest_settee","chair","petal_armchair"]:
		editor.open_editor();var layout:=L.add(data,{"type":"object","kind":kind,"position":[80.,8.],"yaw":90.});check(editor.commit(layout),"Rotated seating fixture: "+kind);editor.close_editor()
		var row: Dictionary=editor.layout.elements.filter(func(item):return item.get("kind","")==kind)[0];var seat: Node3D=editor.room.render_cache[row.id].node;var side: float=2.6 if kind in ["sofa","forest_settee"] else 1.6;var point:=seat.to_global(Vector3(side,.02,.1))
		await approach(point);check(city.current_target=="build:"+str(row.id) and city.hud.prompt.text.contains("坐下来"),"E is offered at the furniture side, away from its authored exit: "+kind)
		await press_e();check(city.nap_active and city.bunny.seated,"E sits on the actual rotated chair: "+kind);await press_e();check(not city.nap_active and not city.bunny.seated and city.bunny.position.distance_to(point)<.2,"E leaves the chair through the approach side: "+kind)
	# Exercise the original fixed house bed from the foot as well.
	var home_bed: Node3D=city.home.get_node("Furnishing/bed");await approach(home_bed.to_global(Vector3(0,.02,3.2)));check(city.current_target=="home_bed","The original house bed also exposes interaction at its foot");await press_e();check(city.sleep_active,"The original bed still sleeps via E");if city.sleep_active:await press_e()
	print("FURNITURE_ACCESS_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
