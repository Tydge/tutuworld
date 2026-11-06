extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
var city: Node3D
var editor: Node
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func click(pos: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=pos;Input.parse_input_event(motion);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=pos;event.global_position=pos;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func button(id: String) -> void:
	var control: Control=editor.ui.root_ui.find_child(id,true,false);check(is_instance_valid(control) and control.is_visible_in_tree(),"Visible floor-aware control: "+id)
	if is_instance_valid(control):await click(root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5)))
func key(code: Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down;Input.parse_input_event(event);await process_frame
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("逐层编辑兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;editor=city.build_mode;editor.open_editor();var original: Vector3=city.bunny.position
	var data:=L.empty()
	for level in [0,1]:
		data=L.add(data,{"type":"floor","a":[65.,-4.],"b":[89.,20.],"storey":level})
		for pair in [[[65.,-4.],[89.,-4.]],[[89.,-4.],[89.,20.]],[[89.,20.],[65.,20.]],[[65.,20.],[65.,-4.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1],"storey":level})
		data=L.add(data,{"type":"object","kind":"chair","position":[70.,0.],"yaw":0.,"storey":level})
	check(editor.commit(data),"Stacked floors, walls and chairs validate independently");await process_frame;await process_frame
	await button("FloorUp");check(editor.editing_storey==1 and city.bunny.position==original,"Floor button edits 2F without moving player")
	await key(KEY_PAGEUP);await key(KEY_PAGEUP);await key(KEY_PAGEUP);check(editor.editing_storey==1 and editor.roof_view,"PageUp stops at roof above existing 2F")
	await key(KEY_PAGEDOWN);check(editor.editing_storey==1,"PageDown selects the exact editing floor")
	editor.focus=Vector3(77,4.7,8);editor.pitch=.95;editor.distance_=37.;editor.update_camera();await process_frame
	var hit: String=editor.pick_at(city.camera.unproject_position(Vector3(70,5.6,0)));check(L.find(editor.layout,hit).get("kind","")=="chair" and S.of(L.find(editor.layout,hit))==1,"Picker selects only the upper of two stacked chairs")
	var floor_id: String=L.compiled(editor.layout,1).floors.values()[0].id;var unit:=L.unit_at(editor.layout,floor_id,Vector2(76.25,8.25));editor.selected_id=unit.id;editor.selected_unit=unit;var lower_before:=JSON.stringify(L.compiled(editor.layout,0).floors)
	editor.paint_selected(Color("f4e8cf"),"cottage_tile");check(JSON.stringify(L.compiled(editor.layout,0).floors)==lower_before and L.compiled(editor.layout,1).floors.values().any(func(row):return row.style=="cottage_tile"),"Room finish paint on 2F leaves 1F unchanged")
	var candidate:=L.demolish(editor.layout,Rect2(76,8,1,1),"floor",null,1);check(L.compiled(candidate,1).floors.size()==L.compiled(editor.layout,1).floors.size()-4 and L.compiled(candidate,0).floors.size()==L.compiled(editor.layout,0).floors.size(),"2F range hammer cuts exactly that storey")
	editor.choose_tool("object:chair");check(editor.place_at(Vector2(74,0)) and S.of(editor.selected_row())==1 and editor.selected_row().get("kind","")=="chair","New upper-floor placement selects that actual new object")
	editor.set_roof_visible(true);editor.choose_tool("window:arch");var point: Variant=editor.point_at(city.camera.unproject_position(Vector3(80,7.,20)));check(point!=null and S.of(L.find(editor.layout,editor.row_at(point).wall))==1,"Wall placement ray selects 2F wall at its real height")
	if point!=null:
		editor.update_ghost(point);check(is_instance_valid(editor.preview) and is_equal_approx(editor.preview.position.y,4.7) and editor.preview_walls.is_empty(),"Upper window preview keeps wall geometry and lighting stable")
	editor.choose_tool("select");editor.set_storey(0);editor.focus=Vector3(79,0,8);editor.pitch=.9;editor.distance_=35.;editor.update_camera()
	await button("Category_结构");await button("Tool_stairs");check(editor.ui.form_family=="stairs","Stair catalog opens its shape subcategory")
	for form in Stairs.FORMS:
		await button("Tool_stairs_"+form);check(editor.tool=="stairs" and editor.structure_form==form,"Select stair shape "+form)
		editor.update_ghost(Vector2(79,8));check(is_instance_valid(editor.preview) and editor.preview.find_children("*","CollisionObject3D",true,false).all(func(body):return body.collision_layer==0),"Real stair preview never changes world collision: "+form)
	editor.set_roof_visible(false);editor.choose_tool("stairs:u");var snapshot:=JSON.stringify(editor.layout);editor.update_ghost(Vector2(79,8));check(not editor.preview_walls.is_empty() and JSON.stringify(editor.layout)==snapshot,"Stair preview updates the upper ceiling shadow opening without saving")
	var openings: Array=editor.preview.find_children("StairOpeningPreview*","Node3D",true,false)
	check(not openings.is_empty() and openings.all(func(node):return node.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)),"Preview keeps the upper ceiling hidden while cutting its shadow")
	editor.choose_tool("select");check(editor.preview_walls.is_empty(),"Cancelling stair preview restores all original floor chunks")
	editor.choose_tool("stairs:u");check(editor.place_at(Vector2(79,8)),"Commit the selected U stair from build mode")
	var stair: Dictionary=editor.layout.elements.filter(func(row):return row.type=="stairs")[0];var opening_count: int=L.compiled(editor.layout,1).floors.size()-L.walkable_grid(editor.layout,1).floors.size();check(opening_count>0,"Placement creates only a derived, owned opening")
	editor.undo();check(editor.layout.elements.all(func(row):return row.type!="stairs") and L.walkable_grid(editor.layout,1).floors.size()==L.compiled(editor.layout,1).floors.size(),"Undo removes stair and restores its opening atomically")
	editor.redo();check(not L.find(editor.layout,stair.id).is_empty(),"Redo restores same stair ID and opening")
	check(city.bunny.position==original,"All floor edits leave the player at their real location")
	editor.ui.message("逐层选取、门窗预览、三种楼梯与撤销均已验证")
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/stair-subcatalog.png")
	var marked: Dictionary=editor.layout.duplicate(true);marked.multistorey_showcase=1;editor.commit(marked);editor.clear_plot();check(editor.layout.elements.is_empty() and int(editor.layout.get("multistorey_showcase",0))==1,"Clearing the plot keeps the once-only sample marker so it cannot respawn")
	for audio in city.find_children("*","AudioStreamPlayer",true,false)+city.find_children("*","AudioStreamPlayer3D",true,false):audio.stop()
	await create_timer(.15).timeout;city.free();await create_timer(.15).timeout;session.free();print("MULTISTOREY_EDITOR_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:quit(code)
