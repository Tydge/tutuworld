extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const E=preload("res://scripts/building/room_edit.gd")
var editor: Node
var city: Node3D
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func point(p: Vector3) -> Vector2:return root.get_final_transform()*city.camera.unproject_position(p)
func motion(p: Vector2) -> void:
	var e:=InputEventMouseMotion.new();e.position=p;Input.parse_input_event(e);await process_frame
func mouse(p: Vector2,down: bool) -> void:
	var e:=InputEventMouseButton.new();e.position=p;e.global_position=p;e.pressed=down;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e);await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;Input.parse_input_event(e);await process_frame
func drag(a: Vector3,b: Vector3,capture_: String="") -> void:
	await motion(point(a));await mouse(point(a),true)
	for i in range(1,5):await motion(point(a.lerp(b,float(i)/4.)));await create_timer(.06).timeout
	if capture_!="":await capture(capture_)
	await mouse(point(b),false);await physics_frame;await physics_frame
func capture(name_: String) -> void:
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建房操作兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,1000);await create_timer(.7).timeout
	editor=city.build_mode;editor.open_editor();editor.focus=Vector3(72,0,2);editor.distance_=18.;editor.update_camera();await key(KEY_T)
	check(editor.top_down and city.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"T selects true orthographic top view")
	check(absf(city.camera.global_basis.z.y-1.)<.001,"Top view looks vertically down without perspective distortion")
	editor.choose_tool("room");await drag(Vector3(70,.18,0),Vector3(74,.18,4),"drag-room-preview")
	check(L.compiled(editor.layout).floors.size()==64 and L.compiled(editor.layout).walls.size()==32,"Actual mouse drag creates a complete 4x4 room")
	var before:=JSON.stringify(editor.layout);editor.choose_tool("select")
	await drag(Vector3(70,.18,2),Vector3(69,.18,2))
	check(L.compiled(editor.layout).floors.size()==80,"Dragging a room wall expands 4x4 to 5x4")
	editor.undo();check(JSON.stringify(editor.layout)==before,"One undo restores entire room adjustment")
	editor.choose_tool("room");await drag(Vector3(74,.18,0),Vector3(78,.18,4));editor.choose_tool("select")
	await drag(Vector3(74,.18,2),Vector3(75,.18,2),"shared-wall-and-dimensions")
	var plan=preload("res://scripts/building/room_plan.gd").make(L.compiled(editor.layout));var widths: Array=[]
	for room in plan.rooms.values():widths.append(E.bounds(room.cells).size.x)
	widths.sort();check(widths==[3.,5.],"Dragging shared wall grows one room and shrinks its neighbor")
	var furniture:=L.add(editor.layout,{"type":"object","kind":"woven_basket","position":[72.,2.],"yaw":0.,"appearance":{"weave":{"material":"wood","color":"987952"},"throw":{"material":"sprig","color":"8fae9c","accent":"f2e5cf"}}})
	check(editor.commit(furniture),"Place actual movable object")
	var row: Dictionary=editor.layout.elements.filter(func(item):return item.get("kind","")=="woven_basket")[0];var id: String=row.id
	await motion(point(Vector3(72,.6,2)));await mouse(point(Vector3(72,.6,2)),true);await mouse(point(Vector3(72,.6,2)),false)
	check(editor.selected_id==id,"Click selects actual object")
	for i in range(3):await process_frame
	check(editor.drafting.halo.visible and editor.drafting.halo.get_child_count()>0,"Selected object has an actual edge halo")
	await capture("selected-object-edge")
	await drag(Vector3(72,.6,2),Vector3(73,.6,2))
	check(L.find(editor.layout,id).position[0]>72.5 and editor.tool=="select","Direct object drag moves and returns to selection")
	await key(KEY_G);check(editor.tool=="move" and editor.moving_id==id,"G starts moving selected object")
	await key(KEY_ESCAPE);check(editor.tool=="select" and editor.room.render_cache[id].node.visible,"Escape cancels a move and restores the original")
	await key(KEY_E);editor.drafting.sample(city.camera.unproject_position(Vector3(73,.6,2)))
	check(editor.tool=="object:woven_basket" and editor.drafting.brush.get("kind","")=="woven_basket","Eyedropper switches to the actual sampled object")
	check(editor.place_at(Vector2(76.5,2)),"Sampled object can be placed independently")
	check(L.find(editor.layout,id).appearance==editor.layout.elements[-1].appearance,"Eyedropper preserves per-part materials and both fabric colors")
	check(editor.layout.elements.filter(func(item):return item.get("kind","")=="woven_basket").size()==2,"Eyedropper adds a new object instead of moving the source")
	var sample_unit:=L.unit_at(editor.layout,L.compiled(editor.layout).floors[Vector2i(141,7)].id,Vector2(70.75,3.75));var styled:=sample_unit.duplicate(true);styled.color="cba76d";styled.style="herringbone";styled.painted=true;check(editor.commit(L.replace_unit(editor.layout,sample_unit,styled)),"Surface eyedropper fixture")
	editor.choose_tool("eyedropper");editor.drafting.sample(city.camera.unproject_position(Vector3(70.75,.19,3.75)))
	check(editor.tool=="floor" and editor.drafting.brush.style=="herringbone","Eyedropper samples actual floor material")
	check(editor.drafting.paint(city.camera.unproject_position(Vector3(77,.19,3.5))) and L.compiled(editor.layout).floors[Vector2i(154,7)].style=="herringbone","Sampled floor style paints another room through the existing room scope")
	editor.choose_tool("room");var unchanged:=JSON.stringify(editor.layout)
	await motion(point(Vector3(80,.18,0)));await mouse(point(Vector3(80,.18,0)),true);await motion(point(Vector3(83,.18,3)));await key(KEY_ESCAPE);await mouse(point(Vector3(83,.18,3)),false)
	check(JSON.stringify(editor.layout)==unchanged and editor.tool=="select" and editor.drafting.mode=="","Escape cancels an uncommitted room drag")
	editor.set_storey(1);editor.choose_tool("room");await drag(Vector3(70,4.88,0),Vector3(73,4.88,4))
	check(editor.editing_storey==1 and not editor.roof_view and L.compiled(editor.layout,1).floors.size()==48 and L.validate(editor.layout).ok,"Room tool in roof view builds a supported upstairs room on the correct level")
	await key(KEY_T);check(not editor.top_down and city.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"T restores perspective")
	city.queue_free();await create_timer(.15).timeout
	print("DRAFTING_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
