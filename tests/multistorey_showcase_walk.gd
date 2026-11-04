extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
var city: Node3D
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func walk(points: Array) -> bool:
	for target: Vector3 in points:
		var frames:=0
		while Vector2(city.bunny.position.x-target.x,city.bunny.position.z-target.z).length()>.12 and frames<420:
			var direction: Vector3=target-city.bunny.position;direction.y=0;city.bunny.simulate_movement(1./60.,direction.normalized(),false,false);frames+=1;await physics_frame
		if frames>=420:print("STUCK ",city.bunny.position," target=",target);return false
	for i in range(10):city.bunny.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
	return absf(city.bunny.position.y-points[-1].y)<.25
func press_e() -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=down;Input.parse_input_event(event);await process_frame
func open_door(point: Vector3) -> void:
	for entry in city.build_mode.room.render_cache.values():
		if entry.row.type!="door" or entry.node.global_position.distance_to(point)>.4:continue
		if not entry.node.door_open:
			city.update_target();check(city.current_target=="build:"+str(entry.row.id),"Real door E prompt is available from the walking approach");await press_e()
		while entry.node.door_tweening:await physics_frame
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("样板通行兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout;var editor: Node=city.build_mode;editor.open_editor();editor.set_process(false);check(editor.commit(preload("res://scripts/building/templates.gd").two_storey()),"Furnished showcase validates");editor.close_editor();city.bunny.set_physics_process(false);session.active=false;city.bunny.position=Vector3(134.5,.3,19.5)
	for i in range(25):city.bunny.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
	check(await walk([Vector3(134.5,.18,16.),Vector3(133,.18,14.5)]),"Walk through the real front door into the furnished entrance")
	var stair: Dictionary=editor.layout.elements.filter(func(row):return row.type=="stairs")[0];var route:=Stairs.route(stair)
	check(await walk(Array(route)),"Walk the sample's U stair with its real walls, ceilings and furniture")
	check(await walk([Vector3(139,4.88,12),Vector3(139,4.88,5)]),"Walk the clear upstairs corridor before opening the study door")
	await open_door(Vector3(140.5,4.88,5))
	check(await walk([Vector3(141.5,4.88,5),Vector3(142.,4.88,5.9)]),"Reach the actual upstairs study through its door")
	check(await walk([Vector3(141.5,4.88,5),Vector3(139,4.88,5),Vector3(139,4.88,11.5)]),"Return through the landing toward the bedroom")
	await open_door(Vector3(140.5,4.88,11.5))
	check(await walk([Vector3(141.55,4.88,11.5)]),"Reach the bedroom from the shared landing corridor")
	check(await walk([Vector3(141.55,4.88,13.35),Vector3(143.5,4.88,13.35),Vector3(143.5,4.88,15.8)]),"Walk around the bed and through its glass door onto the balcony")
	editor.room.refresh_view(city.camera.position,city.bunny.position);check(not editor.room.contains_position(city.bunny.position) and not editor.room.has_roof_at(Vector2(city.bunny.position.x,city.bunny.position.z)),"Balcony remains outdoors and has open sky")
	check(await walk([Vector3(144.4,4.88,15.8)]),"Walk into the balcony chair's real approach space")
	city.update_target();var chair: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="petal_armchair")[0];check(city.current_target=="build:"+str(chair.id),"Balcony chair can be selected naturally beside the glass door");await press_e();check(city.nap_active,"Actual E sits on the balcony chair");if city.nap_active:await press_e()
	check(not city.nap_active and city.bunny.position.y>4.7,"Leaving the balcony chair stays on 2F")
	check(await walk([Vector3(143.5,4.88,15.8),Vector3(143.5,4.88,13.35),Vector3(141.55,4.88,13.35),Vector3(141.55,4.88,11.5),Vector3(139,4.88,11.5),Vector3(139,4.88,12)]),"Return from the balcony through the bedroom to the landing")
	route.reverse();check(await walk(Array(route)),"Descend the furnished sample's stair")
	check(await walk([Vector3(136,.18,12),Vector3(136,.18,10.2),Vector3(143,.18,10.2)]),"Walk from the stair to the closed kitchen door")
	await open_door(Vector3(143,.18,9))
	check(await walk([Vector3(143,.18,7.5),Vector3(143.5,.18,5.4)]),"Walk from the kitchen door up to its cooking counter")
	city.update_target();check(city.targets.get(city.current_target,{}).get("kind","")=="kitchen","Kitchen interaction is available after physically walking there")
	for audio in city.find_children("*","AudioStreamPlayer",true,false)+city.find_children("*","AudioStreamPlayer3D",true,false):audio.stop()
	await create_timer(.15).timeout;city.free();await create_timer(.15).timeout;session.free();print("MULTISTOREY_SHOWCASE_WALK_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:quit(code)
