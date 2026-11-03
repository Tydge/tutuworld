extends SceneTree
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=3) -> void:
	for i in range(count):await process_frame;RenderingServer.force_draw()
func screen(p: Vector3) -> Vector2:return root.get_final_transform()*city.camera.unproject_position(p)
func mouse(p: Vector2) -> void:
	var e:=InputEventMouseMotion.new();e.position=p;Input.parse_input_event(e);await process_frame
func press(p: Vector2,down: bool) -> void:
	var e:=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e);await process_frame
func click(p: Vector2) -> void:await mouse(p);await press(p,true);await press(p,false);await physics_frame
func button(id: String) -> void:
	var control: Control=editor.ui.root_ui.find_child(id,true,false);await click(root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5)))
func photo(id: String) -> void:
	await frames(5);root.get_texture().get_image().save_png(out+"/"+id+".png")
func kind(id: String) -> Dictionary:
	for row in editor.layout.elements:
		if row.get("kind","")==id:return row
	return {}
func visible(id: String) -> bool:
	var node: Node3D=editor.room.get_node_or_null("Furnishing/"+id)
	if node==null or not node.is_visible_in_tree():return false
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.is_visible_in_tree():return true
	return false
func base() -> Dictionary:return L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[88.,14.]})
func demolition_fixture() -> Dictionary:
	var data:=base();data=L.add(data,{"type":"wall","a":[72.,5.],"b":[84.,5.]});var wall: String=data.elements[-1].id
	data=L.add(data,{"type":"door","wall":wall,"offset":6.});data=L.add(data,{"type":"roof","a":[84.,8.],"b":[88.,12.]})
	data=L.add(data,{"type":"object","kind":"bedside","position":[76.,7.]});var support: String=data.elements[-1].id
	return L.add(data,{"type":"object","kind":"table_lamp","position":[76.,7.],"support":support})
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建造修复验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout
	editor=city.build_mode;editor.open_editor();editor.focus=Vector3(79,0,7);editor.distance_=32;editor.update_camera()
	for i in range(45):
		if editor.ui.studio.cache.has("floor"):break
		await frames(1)
	var floor_image: Texture2D=editor.ui.card_images.floor.texture
	check(floor_image!=null and floor_image.get_image().get_used_rect().has_area(),"Floor catalog thumbnail contains rendered pixels on first load")
	if floor_image!=null:floor_image.get_image().save_png(out+"/floor-thumbnail.png")
	await frames(8);await button("Tool_floor");await frames(3)
	check(editor.tool=="floor","The visible floor catalog card activates the floor tool")
	check(editor.ui.selected_preview.texture!=null and editor.ui.selection.text=="地板","Choosing the floor tool also displays its thumbnail in the detail panel")
	check(editor.ui.root_ui.find_child("DemolitionFilter",true,false)==null,"Hammer has no demolition-effect selector")
	await photo("floor-tool-thumbnail")
	var data:=base();data=L.add(data,{"type":"object","kind":"desk","position":[78.,9.]});var desk: String=data.elements[-1].id
	data=L.add(data,{"type":"object","kind":"table_lamp","position":[78.8,9.],"support":desk});var lamp: String=data.elements[-1].id
	data=L.add(data,{"type":"object","kind":"letter","position":[77.6,9.],"support":desk});var letter: String=data.elements[-1].id
	check(editor.commit(data),"Create a desk with an attached lamp and letter")
	editor.choose_tool("select");editor.selected_id=desk;editor.refresh_ui();var instance: int=editor.room.get_node("Furnishing/"+desk).get_instance_id();await button("MoveBuildElement")
	check(not visible(desk) and not visible(lamp),"Move preview temporarily hides the source furniture and its attachments")
	await click(screen(Vector3(78,.18,11)));await frames()
	check(editor.tool=="select" and L.find(editor.layout,desk).position==[78.,11.],"A world click completes the furniture move")
	check(visible(desk) and visible(lamp) and visible(letter),"Moving restores visible furniture, lamp and ornament meshes")
	check(editor.room.get_node("Furnishing/"+desk).get_instance_id()==instance and editor.room.last_sync.created==0,"Restoring visibility keeps incremental mesh reuse")
	check(editor.room.get_node("Furnishing/"+lamp+"/FixtureLight").is_visible_in_tree(),"Moved lamp resumes actual illumination")
	await photo("moved-furniture-visible")
	editor.begin_move();check(editor.place_at(Vector2(78,11)),"Dropping at the original position is a valid no-op")
	check(visible(desk) and visible(lamp),"A no-op move also restores the original models")
	editor.begin_move();var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;Input.parse_input_event(escape);await process_frame;escape.pressed=false;Input.parse_input_event(escape);await frames()
	check(visible(desk) and visible(lamp) and editor.tool=="select","Cancelling a move restores all source models")
	data=demolition_fixture();check(editor.commit(data),"Create adjacent floor, wall, doorway, roof and furnished area")
	editor.choose_tool("delete");var before:=L.usage(editor.layout);var first:=screen(Vector3(74.25,.55,5));var last:=screen(Vector3(85.25,.18,10.75))
	await mouse(first);await press(first,true);await mouse(last);await frames(2)
	var after:=L.usage(editor.demolition_candidate)
	check(after.wall_edges<before.wall_edges and after.floor_cells==before.floor_cells and after.objects==before.objects and after.roofs==before.roofs,"Default wall drag locks to walls and protects floor, furniture and roof")
	await photo("wall-drag-type-locked");await press(last,false);await physics_frame
	after=L.usage(editor.layout);check(after.floor_cells==before.floor_cells and after.objects==before.objects and after.roofs==before.roofs,"Committing the wall drag preserves other object types")
	check(not editor.layout.elements.any(func(row):return row.type=="door"),"A removed wall still removes its dependent doorway")
	editor.undo();check(L.usage(editor.layout)==before,"One undo restores the wall and its doorway")
	editor.choose_tool("delete");first=screen(Vector3(73.25,.18,1.25));last=screen(Vector3(82.75,.18,8.75));await mouse(first);await press(first,true);await mouse(last);await frames(2)
	after=L.usage(editor.demolition_candidate)
	check(after.floor_cells<before.floor_cells and after.wall_edges==before.wall_edges,"Default floor drag locks to floors even when crossing a wall")
	check(after.objects==0 and after.roofs==before.roofs,"Floor demolition removes unsupported furniture and its lamp without sweeping the separate roof")
	await photo("floor-drag-type-locked");await press(last,false);await physics_frame
	check(L.usage(editor.layout).wall_edges==before.wall_edges and kind("bedside").is_empty() and kind("table_lamp").is_empty(),"Floor drag commits its own cells and supported-furniture cascade")
	editor.undo();check(L.usage(editor.layout)==before,"Undo restores the floor and all cascaded furniture")
	editor.choose_tool("delete");first=screen(Vector3(76,.55,7));last=screen(Vector3(86.25,.18,10.75));await mouse(first);await press(first,true);await mouse(last);await frames(2)
	after=L.usage(editor.demolition_candidate);check(after.floor_cells==before.floor_cells and after.wall_edges==before.wall_edges and after.roofs==before.roofs,"Dragging from furniture cannot sweep floor, wall or roof")
	await press(last,false)
	print("BUILDING_EDITING_REGRESSION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
