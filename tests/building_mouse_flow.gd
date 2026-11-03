extends SceneTree
const Layout=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func click(pos: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=pos;Input.parse_input_event(motion);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=pos;event.global_position=pos;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
	await physics_frame
func button(id: String) -> void:
	var control: Control=editor.ui.root_ui.find_child(id,true,false)
	check(control!=null,"Visible editor control exists: "+id)
	if control!=null:await click(root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5)))
func world(point_: Vector3) -> void:await click(root.get_final_transform()*city.camera.unproject_position(point_))
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("鼠标建造兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout;await create_timer(.2).timeout
	# Route an actual shortcut through the game's normal unhandled-input path.
	var key:=InputEventKey.new();key.keycode=KEY_F6;key.pressed=true;Input.parse_input_event(key);await process_frame;key.pressed=false;Input.parse_input_event(key);await process_frame
	editor=city.build_mode;check(editor.active,"F6 actually opens the in-game construction UI")
	if not editor.active:quit(1);return
	var actor_before: Vector3=city.bunny.position
	await button("Tool_floor");check(editor.tool=="floor","Floor catalog click activates the floor tool");await world(Vector3(73,.18,5));await world(Vector3(85,.18,15))
	check(editor.layout.elements.size()==1 and editor.layout.elements[0].type=="floor","Two mouse clicks create the actual floor rectangle")
	await button("Tool_wall")
	for segment in [[Vector3(73,.18,15),Vector3(85,.18,15)],[Vector3(85,.18,5),Vector3(73,.18,5)],[Vector3(73,.18,5),Vector3(73,.18,15)],[Vector3(85,.18,15),Vector3(85,.18,5)]]:
		await world(segment[0]);await world(segment[1])
	check(editor.layout.elements.size()==5,"Mouse tool creates all four walls from scratch")
	await button("Tool_door");await world(Vector3(79,1.6,15))
	check(editor.layout.elements.any(func(row):return row.type=="door"),"Mouse attaches a door to a real wall")
	await button("Tool_window");await world(Vector3(81,2,5))
	check(editor.layout.elements.any(func(row):return row.type=="window"),"Mouse attaches a window with a real wall opening")
	await button("Tool_roof");await world(Vector3(73,.18,5));await world(Vector3(85,.18,15))
	check(editor.layout.elements.any(func(row):return row.type=="roof"),"Mouse tool creates a supported gabled roof")
	await button("Category_床");await button("Tool_object_bed");await world(Vector3(82,.18,8))
	check(editor.layout.elements.any(func(row):return row.get("kind","")=="bed"),"Furniture can be placed through the visible palette and world click")
	check(city.bunny.position.distance_to(actor_before)<.03,"Construction clicks and shortcuts do not move the player")
	editor.pitch=.35;editor.update_camera();await process_frame
	await button("Tool_select");await world(Vector3(82,.8,8))
	check(Layout.find(editor.layout,editor.selected_id).get("kind","")=="bed","Mouse ray selects furniture through a wall cutaway at a low camera angle")
	await button("EditFurnitureAppearance");editor.ui.appearance_panel.color.color=Color("9c8bb8")
	await button("ApplyPartAppearance")
	check(Layout.find(editor.layout,editor.selected_id).get("appearance",{}).get("frame",{}).get("color","")=="9c8bb8","Inspector apply button commits only the chosen furniture part")
	editor.ui.appearance_panel.close()
	await button("DeleteBuildElement");check(not editor.layout.elements.any(func(row):return row.get("kind","")=="bed"),"Delete button removes furniture without touching walls")
	await button("BuildUndo");check(editor.layout.elements.any(func(row):return row.get("kind","")=="bed"),"Undo button restores the same stable furniture ID")
	await button("BuildRedo");check(not editor.layout.elements.any(func(row):return row.get("kind","")=="bed"),"Redo button repeats deletion")
	await button("BuildUndo")
	var before: int=editor.layout.elements.size();await button("Category_床");await button("Tool_object_bed");await world(Vector3(82,.18,8));check(editor.layout.elements.size()==before,"Invalid overlapping placement is rejected through the mouse UI")
	editor.choose_tool("select");editor.pitch=.80;editor.distance_=30;editor.ui.message("鼠标从空地搭建：地板、四面墙、门窗、屋顶、家具与改色均已完成")
	for i in range(15):
		await process_frame
		RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/built-from-empty.png")
	print("BUILDING_MOUSE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
