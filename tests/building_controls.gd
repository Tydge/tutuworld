extends SceneTree
const Layout=preload("res://scripts/building/layout.gd")
const Site=preload("res://scripts/building/site.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func key(code: Key,down: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;Input.parse_input_event(event);await process_frame
func drag(relative: Vector2,shift_: bool=false) -> void:
	var pos:=root.get_final_transform()*Vector2(730,420)
	var down:=InputEventMouseButton.new();down.position=pos;down.button_index=MOUSE_BUTTON_RIGHT;down.pressed=true;Input.parse_input_event(down);await process_frame
	var motion:=InputEventMouseMotion.new();motion.position=pos;motion.relative=root.get_final_transform().basis_xform(relative);motion.shift_pressed=shift_;Input.parse_input_event(motion);await process_frame
	down.pressed=false;Input.parse_input_event(down);await process_frame
func horizontal(vector: Vector3) -> Vector3:return Vector3(vector.x,0,vector.z).normalized()
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建造操作验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout
	city.build_mode.open_editor();editor=city.build_mode;editor.set_process(false);editor.yaw=0.;editor.update_camera()
	var player: Vector3=city.bunny.position
	for quarter in range(4):
		await drag(Vector2(-PI*.5/.006,0));editor.update_camera()
		check(absf(editor.yaw-(quarter+1)*PI*.5)<.001,"Actual right drag rotates the construction view: "+str(quarter))
		for code in [KEY_W,KEY_A,KEY_S,KEY_D]:
			editor.focus=Site.CENTER;editor.update_camera()
			var before: Vector3=editor.focus
			var forward: Vector3=horizontal(-city.camera.global_basis.z);var right: Vector3=horizontal(city.camera.global_basis.x)
			var expected: Vector3={KEY_W:forward,KEY_S:-forward,KEY_D:right,KEY_A:-right}[code]
			await key(code,true);editor._process(.1);await key(code,false)
			var moved: Vector3=editor.focus-before
			check(moved.length()>.5 and horizontal(moved).dot(expected)>.999,"WASD follows the rotated camera, key="+str(code)+" quarter="+str(quarter))
		editor.focus=Site.CENTER;editor.update_camera();var before: Vector3=editor.focus;var left: Vector3=horizontal(-city.camera.global_basis.x)
		await drag(Vector2(30,0),true)
		check((editor.focus-before).length()>.1 and horizontal(editor.focus-before).dot(left)>.999,"Shift-right drag follows the same rotated screen axes: "+str(quarter))
	check(city.bunny.position.distance_to(player)<.01,"Construction camera controls do not move the player")
	var shell:=preload("res://scripts/building/templates.gd").cottage();shell.elements=shell.elements.filter(func(row):return row.type!="object")
	check(editor.commit(shell),"Existing structural layout accepts precise wall placement")
	for item in [["forest_cabinet",Vector2(77,5.5)],["bookshelf",Vector2(83.5,5.5)]]:
		editor.choose_tool("object:"+item[0]);check(editor.place_at(item[1]),"Normal placement tool snaps storage to the wall: "+item[0])
		var row: Dictionary=editor.layout.elements[-1];var module: Node3D=editor.room.get_node("Furnishing/"+row.id)
		var collider: StaticBody3D=module.find_child("CabinetCollision" if item[0]=="forest_cabinet" else "BookshelfCollision",true,false)
		var shape: BoxShape3D=collider.get_child(0).shape
		var rear: Vector3=collider.to_global(Vector3(0,0,-shape.size.z*.5))
		check(absf(rear.z-5.20)<.002,"Rendered module and real collision share the precise wall pose: "+item[0])
	var cabinet: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="forest_cabinet")[0]
	var saved_position: Array=cabinet.position.duplicate();editor.choose_tool("select");editor.selected_id=cabinet.id;editor.rotate_selected()
	check(Layout.find(editor.layout,cabinet.id).yaw==90.,"Rotating near a wall rechecks and snaps the wider furniture body")
	editor.undo();check(Layout.find(editor.layout,cabinet.id).position==saved_position,"Undo restores the precise wall-snapped placement")
	check(Layout.normalize(JSON.parse_string(JSON.stringify(session.state().build_layout)))==editor.layout,"Snapped placement survives the exact persisted layout representation")
	check(not editor.room.has_node("Lighting/RoomKey") and not editor.room.has_node("Lighting/RoomFill"),"Unlit construction has no invisible room key or fill lights")
	editor.close_editor();city.set_process(false);session.active=false;city.hud.hide();city.bunny.can_move=false;city.bunny.position=Vector3(79,.2,11);city.bunny.reset_physics_interpolation()
	city.camera.position=Vector3(89,10,21);city.camera.look_at(Vector3(79,1.4,9));city.update_lighting(.92)
	for i in range(30):
		editor.room._process(.1);await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/storage-against-wall-night.png")
	print("BUILDING_CONTROLS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
