extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const C=preload("res://scripts/building/catalog.gd")
var city: Node3D
var editor: Node
var checks:=0
var failures: Array=[]
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=3) -> void:
	for i in range(count):
		await process_frame
		RenderingServer.force_draw()
func photo(name_: String) -> Image:
	await frames(8)
	var img:=root.get_texture().get_image();img.save_png(out+"/"+name_+".png");return img
func mouse_at(pos: Vector2) -> void:
	var e:=InputEventMouseMotion.new();e.position=pos;Input.parse_input_event(e);await process_frame
func click(pos: Vector2,double_: bool=false) -> void:
	await mouse_at(pos)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=pos;event.global_position=pos;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.double_click=double_;Input.parse_input_event(event);await process_frame
	await physics_frame
func world(p: Vector3,double_: bool=false) -> void:await click(root.get_final_transform()*city.camera.unproject_position(p),double_)
func button(id: String) -> void:
	var control: Control=editor.ui.root_ui.find_child(id,true,false);check(control!=null and control.is_visible_in_tree(),"Bottom control is visible: "+id)
	if control!=null:await click(root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5)))
func key(code: Key) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;Input.parse_input_event(e);await process_frame
func kind(id: String) -> Dictionary:
	for row in editor.layout.elements:
		if row.get("kind","")==id:return row
	return {}
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建造交互验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout;await frames()
	editor=city.build_mode;editor.open_editor();editor.distance_=26;editor.update_camera()
	var data:=L.add(L.empty(),{"type":"floor","a":[69.,1.],"b":[90.,22.]});check(editor.commit(data),"Create a clean supported construction area")
	for category in C.CATEGORIES:editor.ui.show_category(category)
	for i in range(180):
		if editor.ui.studio.cache.size()>=C.OBJECTS.size()+6:break
		await frames(1)
	check(editor.ui.studio.cache.size()==C.OBJECTS.size()+6,"All catalog cards have rendered real-model thumbnails")
	var dock: Control=editor.ui.root_ui.get_node("BuildDock");check(dock.position.y>root.get_visible_rect().size.y*.6,"Construction controls occupy only the bottom of the scene")
	await button("Category_桌柜");await button("Tool_object_desk");await world(Vector3(77,.18,10))
	check(not kind("desk").is_empty(),"Desk is placed independently from its chair and decorations")
	await button("Category_照明");await button("Tool_object_table_lamp");await world(Vector3(77,1.32,10))
	var lamp:=kind("table_lamp");var desk:=kind("desk")
	check(not lamp.is_empty() and lamp.get("support","")==desk.get("id","missing"),"Actual mouse ray places a lamp onto the desk surface")
	if lamp.is_empty():quit(1);return
	var fixture: OmniLight3D=editor.room.get_node("Furnishing/"+lamp.id+"/FixtureLight")
	check(is_equal_approx(fixture.global_position.y,1.66) and fixture.shadow_enabled,"Lamp light follows the actual fixture height and casts shadows")
	check(not editor.room.has_node("Lighting/RoomKey") and not editor.room.has_node("Lighting/RoomFill"),"There are no hidden automatic room lights")
	await button("Category_装饰");await button("Tool_object_letter");await world(Vector3(77.8,1.32,10))
	var letter:=kind("letter");check(not letter.is_empty(),"Small decoration is placed separately on the same surface")
	await button("Tool_select");await world(Vector3(letter.position[0],1.35,letter.position[1]))
	check(editor.selected_id==letter.id,"Thin tabletop decoration can be selected without the desk collision stealing the click")
	await world(Vector3(77,1.85,10))
	check(editor.selected_id==lamp.id and editor.ui.selection.text=="暖光台灯" and editor.ui.selected_preview.texture!=null,"Selection panel shows the clicked lamp name and thumbnail")
	await photo("bottom-catalog-selection")
	# Preview both a valid placement and an overlapping object without process changing the pointer.
	editor.set_process(false);editor.choose_tool("object:bed");editor.update_ghost(Vector2(83,9))
	check(is_instance_valid(editor.preview) and editor.preview.find_child("Quilt",true,false)!=null and editor.ghost.scale.y<.1,"Valid preview shows the actual bed, with only a thin footprint marker")
	await photo("real-model-preview-valid")
	editor.choose_tool("object:desk");editor.update_ghost(Vector2(77,10))
	var meshes: Array=editor.preview.find_children("*","MeshInstance3D",true,false)
	check(not meshes.is_empty() and meshes[0].material_overlay.albedo_color.r>.9,"Invalid preview remains a recognizable desk with a red overlay")
	await photo("real-model-preview-conflict")
	for type in ["floor","wall","roof","door","window"]:
		if type in ["door","window"]:
			var wall:=L.add(editor.layout,{"type":"wall","a":[70.,2.],"b":[88.,2.]});editor.commit(wall)
		editor.choose_tool(type);editor.start_point=Vector2(80,14);editor.update_ghost(Vector2(86,19) if type not in ["door","window"] else Vector2(80,2))
		check(is_instance_valid(editor.preview) and not editor.preview.find_children("*","MeshInstance3D",true,false).is_empty() and not editor.ghost.visible,"Structure preview uses real geometry: "+type)
		if type in ["door","window"]:editor.undo()
	editor.choose_tool("select");editor.set_process(true)
	# Move the support with its lamp and letter, then cancel another move.
	editor.selected_id=desk.id;editor.refresh_ui();await button("MoveBuildElement");await key(KEY_R);await world(Vector3(80,.18,10))
	desk=L.find(editor.layout,desk.id);lamp=L.find(editor.layout,lamp.id)
	check(desk.yaw==90. and lamp.yaw==90. and Vector2(lamp.position[0],lamp.position[1]).distance_to(Vector2(80,10))<.001,"Mouse move and R rotate the support and its attached light together")
	fixture=editor.room.get_node("Furnishing/"+lamp.id+"/FixtureLight");check(absf(fixture.global_position.x-80)<.001,"Actual light instance moves to the new fixture position")
	var before: Dictionary=editor.layout.duplicate(true);editor.selected_id=desk.id;editor.begin_move();await key(KEY_ESCAPE)
	check(editor.layout==before and editor.room.get_node("Furnishing/"+desk.id).visible,"Esc cancels moving without changing the layout or hiding the original")
	await button("Tool_delete");await world(Vector3(80.8,1.32,10))
	check(kind("desk").is_empty() and kind("table_lamp").is_empty() and kind("letter").is_empty(),"Hammer click removes support, lamp and decoration together")
	check(editor.tool=="delete","Hammer remains active for repeated demolition")
	await button("BuildUndo");check(not kind("desk").is_empty() and not kind("table_lamp").is_empty() and not kind("letter").is_empty(),"One undo restores the complete surface group")
	var roof:=L.add(editor.layout,{"type":"roof","a":[69.,1.],"b":[90.,22.]});editor.commit(roof)
	await button("Category_照明");await button("Tool_object_pendant");await world(Vector3(81,4.58,12))
	var pendant:=kind("pendant");check(not pendant.is_empty() and pendant.support=="ceiling:0","Mouse places a pendant at the real ceiling height")
	await button("Tool_select");await button("NightPreview");editor.choose_tool("select");await mouse_at(Vector2(30,30))
	await photo("fixture-lighting-night")
	# Pixel evidence that fixtures contribute to the room, beyond their own bulb geometry.
	var lights: Array=editor.room.find_children("*","OmniLight3D",true,false);var on:=await photo("lights-on")
	for light in lights:light.hide()
	var off:=await photo("lights-off");var changed:=0
	for y in range(150,mini(on.get_height()-500,1200),8):
		for x in range(600,mini(on.get_width()-300,2400),8):
			var a:=on.get_pixel(x,y);var b:=off.get_pixel(x,y)
			if (a.r+a.g+a.b)-(b.r+b.g+b.b)>.04:changed+=1
	check(changed>10,"Real fixtures visibly illuminate surrounding surfaces at night")
	for light in lights:light.show()
	# Templates follow the mouse and can be placed beside existing construction.
	editor.commit(L.empty());editor.distance_=38.;editor.focus=Vector3(79,0,10);editor.update_camera()
	await button("PlaceSampleRoom");check(editor.ui.form_family=="template" and editor.layout.elements.is_empty(),"Sample button opens the bottom catalog without changing the layout");await button("Tool_template_single_one");check(editor.tool=="template","House card enters placement mode")
	await mouse_at(root.get_final_transform()*city.camera.unproject_position(Vector3(69,.18,1)));await frames(3)
	check(is_instance_valid(editor.preview) and editor.preview.has_node("Structure/Roof"),"Whole-house preview follows the pointer with actual roof and walls")
	await photo("template-placement-preview");await world(Vector3(69,.18,1));var count: int=editor.layout.elements.size();check(count==preload("res://scripts/building/templates.gd").player_sample("single_one").elements.size(),"Mouse chooses the first whole-house position")
	editor.focus=Vector3(88,0,19);editor.update_camera();await world(Vector3(88,.18,19));check(editor.layout.elements.size()==count*2,"A second house can be mouse-placed beside the existing house")
	await world(Vector3(88,.18,19));check(editor.layout.elements.size()==count*2,"Overlapping whole-house placement is rejected")
	await key(KEY_ESCAPE);editor.focus=Vector3(79,0,10);editor.update_camera();editor.set_night_preview(false);await photo("two-houses-bottom-catalog")
	await button("BuildUndo");check(editor.layout.elements.size()==count,"One undo removes only the most recently placed whole house")
	await button("BuildRedo");check(editor.layout.elements.size()==count*2,"One redo restores the complete second house with its attachments")
	# Door sweep can pass through an actor; closed doors retain normal blocking.
	var sample:=preload("res://scripts/building/templates.gd").cottage();editor.commit(sample)
	editor.focus=Vector3(79,0,10);editor.distance_=27.;editor.update_camera();editor.ui.show_category("桌柜");editor.selected_id=kind("table_lamp").id;editor.refresh_ui();editor.set_night_preview(false);await mouse_at(Vector2(20,20));await photo("new-building-interface")
	editor.set_night_preview(true);await photo("furnished-room-fixture-lighting")
	editor.close_editor();city.set_process(false);city.bunny.can_move=false
	var door: Node3D=editor.room.get_node("Doors/build_6");city.bunny.position=door.global_position;city.bunny.velocity=Vector3.ZERO;city.bunny.set_physics_process(false)
	check(door.toggle_door(city.bunny).ok,"Constructed door closes even while the player occupies its sweep")
	await physics_frame;check(door.portal.disabled and door.leaf.disabled,"Door portal and leaf allow passage throughout the swing")
	await create_timer(1.).timeout;check(not door.portal.disabled and not door.leaf.disabled,"Closed door restores normal collision after its animation")
	var home: Node3D=city.home;home.door_tweening=false;home.door_open=true;home.door_angle=1.78;home.door_target=1.78;home.hinge.rotation.y=1.78;city.bunny.position=home.get_node("Door").global_position
	check(home.toggle_door(city.bunny).ok,"Existing town home also closes without asking the player to move away")
	await physics_frame;check(home.portal_shape.disabled and home.leaf_shape.disabled,"Existing home disables both blockers during the sweep")
	await create_timer(1.).timeout;check(not home.portal_shape.disabled and not home.leaf_shape.disabled,"Existing home restores its closed-door collision")
	print("BUILDING_REVISION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
