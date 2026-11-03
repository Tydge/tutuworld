extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Grid=preload("res://scripts/building/grid_layout.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frame(count: int=2) -> void:
	for i in range(count):await process_frame;RenderingServer.force_draw()
func photo(id: String) -> void:
	await frame(6);root.get_texture().get_image().save_png(out+"/"+id+".png")
func mouse(p: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=p;Input.parse_input_event(event);await process_frame
func press(p: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=p;event.global_position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func screen(p: Vector3) -> Vector2:return root.get_final_transform()*city.camera.unproject_position(p)
func click(p: Vector3) -> void:
	var pos:=screen(p);await mouse(pos);await press(pos,true);await press(pos,false);await physics_frame
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("网格建造验收兔","bunny","bow_rose");session.settings.interior_view_mode=0
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout
	editor=city.build_mode;editor.open_editor();editor.focus=Vector3(76,0,5);editor.distance_=27;editor.update_camera()
	var data:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[82.,10.]});data=L.add(data,{"type":"wall","a":[71.,4.],"b":[76.,4.]});data=L.add(data,{"type":"wall","a":[76.,4.],"b":[81.,4.]})
	check(editor.commit(data),"Build adjacent wall drags on a continuous floor")
	check(editor.room.get_node("Structure/Walls").get_child_count()==1 and editor.room.get_node("Joints").get_child_count()==2,"Only real wall endpoints receive trim; straight join has no post")
	await photo("continuous-wall")
	var root_id: int=editor.room.get_instance_id();var old_chunks: Dictionary={}
	for child in editor.room.get_node("Structure/Floor").get_children():old_chunks[child.name]=child.get_instance_id()
	editor.choose_tool("delete")
	await click(Vector3(73.25,.55,4))
	check(is_equal_approx(L.usage(editor.layout).wall_length,9.5),"Hammer click deletes one half-metre wall edge")
	editor.undo();check(is_equal_approx(L.usage(editor.layout).wall_length,10.),"One undo restores the wall edge")
	editor.choose_tool("delete")
	var start:=screen(Vector3(74.25,.55,4));var finish:=screen(Vector3(75.75,.18,4.25))
	await mouse(start);await press(start,true);await mouse(finish);await frame(2)
	check(editor.demolition_dragging and is_equal_approx(L.usage(editor.layout).wall_length,10.),"Dragging previews demolition without changing committed geometry")
	check(is_equal_approx(L.usage(editor.demolition_candidate).wall_length,8.),"Visible drag preview and committed range identify the same two metres")
	await photo("wall-range-preview");await press(finish,false);await physics_frame
	check(is_equal_approx(L.usage(editor.layout).wall_length,8.),"Mouse drag removes precisely the selected wall range")
	check(editor.room.get_instance_id()==root_id,"Structural edits keep the building root instance")
	var reused_floor:=true
	for child in editor.room.get_node("Structure/Floor").get_children():
		if old_chunks.get(child.name)!=child.get_instance_id():reused_floor=false
	check(reused_floor,"Wall demolition reuses all untouched floor geometry")
	editor.undo();editor.choose_tool("delete")
	start=screen(Vector3(73.25,.18,1.25));finish=screen(Vector3(74.75,.18,2.75));await mouse(start);await press(start,true);await mouse(finish);await frame(2);await photo("floor-range-preview");await press(finish,false);await physics_frame
	check(L.usage(editor.layout).floor_cells==464,"Range demolition removes sixteen individual floor cells")
	check(not L.supported(Rect2(70,0,12,10),editor.layout.elements.filter(func(row):return row.type=="floor")),"The demolished floor hole is detected by exact support validation")
	check(editor.room.last_sync.created<=4 and editor.room.last_sync.reused>0,"Floor edit rebuilds only touched render chunks")
	await photo("floor-hole");editor.undo();check(L.usage(editor.layout).floor_cells==480,"One undo restores all floor cells in the drag")
	# The gesture owns its mouse release even when the pointer ends on the dock.
	editor.choose_tool("delete");var snapshot:=JSON.stringify(editor.layout);start=screen(Vector3(73.25,.18,1.25));finish=screen(Vector3(74.75,.18,2.75))
	await mouse(start);await press(start,true);await mouse(finish);await frame(2)
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;Input.parse_input_event(escape);await process_frame;escape.pressed=false;Input.parse_input_event(escape);await press(finish,false)
	check(editor.demolition_start==null and JSON.stringify(editor.layout)==snapshot,"Escape cancels a live demolition drag without changing layout")
	editor.choose_tool("delete");await mouse(start);await press(start,true);var dock: Control=editor.ui.root_ui.find_child("Tool_select",true,false);finish=root.get_final_transform()*(dock.get_global_transform_with_canvas()*(dock.size*.5));await mouse(finish);await frame(2);await press(finish,false)
	check(editor.demolition_start==null and JSON.stringify(editor.layout)!=snapshot,"Releasing a demolition drag above the dock completes the owned gesture")
	editor.undo();check(JSON.stringify(editor.layout)==snapshot,"One undo restores a range demolition completed over the dock")

	# Appearance changes affect only the selected unit and its render chunk.
	editor.choose_tool("select");await click(Vector3(71.25,.18,1.25));check(not editor.selected_unit.is_empty() and editor.selected_unit.type=="floor","Picking a merged floor addresses an individual editable cell")
	editor.paint_selected(Color("ba8177"),"plaster");check(L.usage(editor.layout).floor_cells==480 and editor.room.last_sync.created==1,"Painting one floor cell changes exactly one floor chunk")
	# A tiny furniture move reuses its mesh, all other modules, and the light instance.
	data=preload("res://scripts/building/templates.gd").cottage();editor.commit(data);var desk: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="desk")[0];var lamp: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="table_lamp")[0]
	var desk_node: Node3D=editor.room.get_node("Furnishing/"+desk.id);var desk_id:=desk_node.get_instance_id();var lamp_node: Node3D=editor.room.get_node("Furnishing/"+lamp.id);var lamp_id:=lamp_node.get_instance_id();var move:=desk.duplicate(true);move.position[0]+=.5
	check(editor.commit(L.replace(editor.layout,move)),"Furniture can move through the incremental update path")
	check(editor.room.get_node("Furnishing/"+desk.id).get_instance_id()==desk_id and editor.room.get_node("Furnishing/"+lamp.id).get_instance_id()==lamp_id and editor.room.last_sync.created==0,"Furniture movement preserves meshes and unrelated fixture instances")
	# Painting an edge within a door aperture must preserve both world anchor and live door state.
	var door_row: Dictionary=editor.layout.elements.filter(func(row):return row.type=="door")[0];var door_node: Node3D=editor.room.get_node("Doors/"+door_row.id);var door_instance:=door_node.get_instance_id();var door_position:=door_node.global_position;var angle: float=door_node.door_angle
	var edge_unit:=L.unit_at(editor.layout,door_row.wall,Vector2(door_row.anchor[0]+.25,door_row.anchor[1]));var recolor:=edge_unit.duplicate(true);recolor.color="ba8177";recolor.style="brick"
	check(editor.commit(L.replace_unit(editor.layout,edge_unit,recolor)),"A door may span wall edges with different appearances")
	check(editor.room.get_node("Doors/"+door_row.id).get_instance_id()==door_instance and door_node.global_position==door_position and is_equal_approx(door_node.door_angle,angle),"Wall repaint preserves the door instance, anchor and angle")
	var passable:=true
	for x in [-1.2,-.2,.2,1.2]:
		var query:=PhysicsRayQueryParameters3D.create(door_position+Vector3(x,1.6,-.6),door_position+Vector3(x,1.6,.6),4);var hit:=city.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():passable=false
	check(passable,"No wall collision is rebuilt inside a door spanning several material runs")

	# Two rooms share one roof mesh: only the current room's pixels are cut away.
	data=L.empty();data=L.add(data,{"type":"floor","a":[70.,0.],"b":[82.,10.]})
	for points in [[[70.,0.],[82.,0.]],[[82.,0.],[82.,10.]],[[82.,10.],[70.,10.]],[[70.,10.],[70.,0.]],[[76.,0.],[76.,10.]]]:data=L.add(data,{"type":"wall","a":points[0],"b":points[1]})
	data=L.add(data,{"type":"roof","a":[70.,0.],"b":[82.,10.]});editor.commit(data);editor.close_editor();city.set_process(false);city.bunny.set_physics_process(false);city.bunny.position=Vector3(73,.2,5);city.camera.position=Vector3(73,12,13);city.camera.look_at(Vector3(76,1,5));editor.room.refresh_view(city.camera.position,city.bunny.position)
	check(editor.room.plan.rooms.size()==2 and editor.room.hidden_at(Vector2(73,5)) and not editor.room.hidden_at(Vector2(79,5)),"Shared roof is cut only over the occupied room, not its neighboring room")
	check(editor.room.contains_position(Vector3(73,.2,5)) and not editor.room.contains_position(Vector3(85,.2,5)),"Interior classification follows enclosed rooms and actual floor support")
	await photo("independent-room-roof")
	# A separate house has a separate room mask even though both belong to one editable world.
	var pair:=data.duplicate(true);pair=L.add(pair,{"type":"floor","a":[85.,15.],"b":[95.,25.]})
	for points in [[[85.,15.],[95.,15.]],[[95.,15.],[95.,25.]],[[95.,25.],[85.,25.]],[[85.,25.],[85.,15.]]]:pair=L.add(pair,{"type":"wall","a":points[0],"b":points[1]})
	pair=L.add(pair,{"type":"roof","a":[85.,15.],"b":[95.,25.]});editor.commit(pair);editor.room.refresh_view(city.camera.position,city.bunny.position)
	check(editor.room.plan.rooms.size()==3 and not editor.room.hidden_at(Vector2(90,20)),"Entering one house leaves the separate house's roof visible")

	var changed:=L.demolish(editor.layout,Rect2(69.75,4,.5,1),"wall");editor.commit(changed);editor.room.refresh_view(city.camera.position,city.bunny.position)
	check(not editor.room.contains_position(city.bunny.position),"Removing exterior wall enclosure makes that room outdoors")
	print("BUILDING_GRID_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
