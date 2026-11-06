extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var city: Node3D
var editor: Node
var checks:=0
var failures: Array=[]
var output: String
func check(value: bool,label_: String) -> void:
	checks+=1;print("PASS " if value else "FAIL ",label_)
	if not value:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func walk(actor: CharacterBody3D,path: PackedVector3Array) -> bool:
	for target in path:
		var frames:=0
		while Vector2(actor.position.x-target.x,actor.position.z-target.z).length()>.13 and frames<360:
			var direction: Vector3=target-actor.position;direction.y=0;actor.simulate_movement(1./60.,direction.normalized(),false,false);frames+=1;await physics_frame
		if frames>=360:print("STUCK ",actor.position," target=",target);return false
	for i in range(20):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
	return absf(actor.position.y-path[-1].y)<.25
func capture(name_: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/"+name_+".png")
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("楼梯测试兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout
	if DisplayServer.get_name()!="headless":root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,1000);await create_timer(.3).timeout
	editor=city.build_mode;editor.open_editor();editor.set_process(false);city.set_process(false);city.bunny.set_physics_process(false);city.bunny.hide();editor.ui.hide();editor.grid.hide()
	check(city.scenery.get_meta("building_site_revision",0)==preload("res://scripts/building/site.gd").REVISION and city.can_walk(Vector3(158,0,10)),"Old packed map expands east at runtime")
	for form in ([] if OS.get_cmdline_user_args().has("--skip-walk") or OS.get_cmdline_user_args().has("--four-only") else Stairs.FORMS.keys()):
		var data:=L.empty()
		for level in [0,1]:data=L.add(data,{"type":"floor","a":[110.,-5.],"b":[128.,25.],"storey":level})
		data=L.add(data,{"type":"stairs","position":[119.,10.],"form":form,"yaw":0.})
		check(editor.commit(data),"Commit walkable "+form+" stairs")
		await physics_frame;await physics_frame
		var row: Dictionary=editor.layout.elements.filter(func(item):return item.type=="stairs")[0];var path:=Stairs.route(row)
		for species in ["bunny","cat_teacher","panda"]:
			var actor:=Animals.create(species);city.add_child(actor);actor.world=city;actor.collision_mask=15;actor.set_physics_process(false);actor.position=path[0]+Vector3.UP*.1;actor.velocity=Vector3.ZERO;city.paused=false
			for i in range(20):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
			check(await walk(actor,path),"Walk upstairs without teleport: "+form+"/"+species)
			var reversed:=path.duplicate();reversed.reverse();check(await walk(actor,reversed),"Walk downstairs without teleport: "+form+"/"+species)
			actor.free();city.paused=true
	if not OS.get_cmdline_user_args().has("--skip-walk"):
		var four:=L.empty()
		for level in range(4):four=L.add(four,{"type":"floor","a":[110.,-6.],"b":[157.,26.],"storey":level})
		for level in range(3):four=L.add(four,{"type":"stairs","form":"u","position":[118.+level*13.,9.],"yaw":0.,"storey":level})
		check(editor.commit(four),"Build a complete four-storey physics fixture");await physics_frame;await physics_frame
		var path:=PackedVector3Array()
		var ordered: Array=editor.layout.elements.filter(func(row):return row.type=="stairs");ordered.sort_custom(func(a,b):return S.of(a)<S.of(b))
		for row in ordered:path.append_array(Stairs.route(row))
		var actor:=Animals.create("bunny");city.add_child(actor);actor.world=city;actor.collision_mask=15;actor.set_physics_process(false);actor.position=path[0]+Vector3.UP*.1;city.paused=false
		for i in range(20):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
		check(await walk(actor,path) and actor.position.y>14.,"Physically walk all three connections to 4F")
		path.reverse();check(await walk(actor,path) and actor.position.y<.5,"Physically return from 4F to the ground floor")
		actor.free();city.paused=true
	check(editor.commit(preload("res://scripts/building/templates.gd").two_storey()),"Commit finished 240sqm two-floor showcase")
	await physics_frame;await physics_frame
	city.bunny.position=Vector3(139,1,25);city.bunny.show();city.paused=false
	editor.set_storey(1);editor.set_roof_visible(false);editor.focus=Vector3(139,4.7,10);editor.yaw=.5;editor.pitch=.95;editor.distance_=33.;editor.update_camera();editor.ui.show();await capture("two-storey-edit-2f")
	check(editor.room.render_cache.values().all(func(entry):return not entry.node.visible or S.of(entry.row)==1 or entry.row.type in ["floor_chunk","stairs"]),"Editing 2F isolates all walls and furniture to that floor")
	editor.set_storey(0);editor.set_roof_visible(false);editor.focus=Vector3(139,0,10);editor.pitch=.95;editor.distance_=33.;editor.update_camera();await capture("two-storey-edit-1f")
	editor.ui.hide();editor.set_roof_visible(true);city.camera.position=Vector3(143.4,2.75,8.3);city.camera.look_at(Vector3(143.5,1.5,3.65));await capture("kitchen-tiles-and-counter")
	editor.set_storey(1);editor.ui.show()
	editor.set_storey(preload("res://scripts/building/storeys.gd").highest(editor.layout)+1);editor.distance_=46.;editor.pitch=.65;editor.update_camera();await capture("two-storey-exterior")
	check(editor.room.render_cache.values().all(func(entry):return entry.node.visible),"Whole-building exterior shows both storeys")
	editor.ui.hide();editor.close_editor();city.bunny.set_physics_process(false);city.set_process(false)
	for i in range(4):await physics_frame
	while not city.navigation.sampling_ready:await physics_frame
	for level in [0,1]:
		city.bunny.position=Vector3(144,.2+4.7*level,12);editor.room.refresh_view(Vector3(146,7+4.7*level,22),city.bunny.position)
		check(editor.room.visible_storey==level,"Normal play follows actor floor automatically: "+str(level+1))
		check(not editor.room.hidden_camera_bodies.is_empty() if level==0 else editor.room.render_cache.values().all(func(entry):return S.of(entry.row)!=level or entry.node.visible),"Hidden geometry is excluded from camera sweeps; current floor stays present")
	if DisplayServer.get_name()!="headless":
		city.hud.open_panel("map");await capture("expanded-east-map");city.hud.close_panel()
	for audio in city.find_children("*","AudioStreamPlayer",true,false)+city.find_children("*","AudioStreamPlayer3D",true,false):audio.stop()
	await create_timer(.15).timeout;city.free();await create_timer(.15).timeout;session.free()
	print("MULTISTOREY_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);call_deferred("finish",0 if failures.is_empty() else 1)

func finish(code: int) -> void:quit(code)
