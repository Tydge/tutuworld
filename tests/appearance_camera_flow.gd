extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const A=preload("res://scripts/building/appearance.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
var session: Node
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=4) -> void:
	for i in range(count):await process_frame;RenderingServer.force_draw()
func photo(id: String) -> void:
	await frames(7);root.get_texture().get_image().save_png(out+"/"+id+".png")
func click(control: Control) -> void:
	var p: Vector2=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5));var motion:=InputEventMouseMotion.new();motion.position=p;Input.parse_input_event(motion);await process_frame
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.global_position=p;e.pressed=down;Input.parse_input_event(e);await process_frame
func key(code: int) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;Input.parse_input_event(e);await process_frame
func place_actor(p: Vector3) -> void:
	city.bunny.position=p;city.bunny.reset_physics_interpolation()
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("外观与视角验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout;await frames(8);session.active=false;city.bunny.set_physics_process(false);city.set_process(false)
	var control: Control=city.hud.camera_control
	check(session.settings.interior_view_mode==2 and not control.visible,"Default free-occlusion camera has no outdoor HUD button")
	place_actor(city.home.to_global(Vector3(0,.2,0)));city.camera.position=city.home.to_global(Vector3(0,9,12));city.camera.look_at(city.bunny.position+Vector3.UP);await frames()
	check(control.visible and control.hint.visible and session.settings.interior_view_hint_seen,"First indoor entry displays the camera button and one-time nearby hint")
	await photo("first-indoor-camera-hint")
	await click(control.button);check(control.button.get_popup().visible,"The indoor camera button opens all three named modes");control.button.get_popup().id_pressed.emit(1);control.button.get_popup().hide();await frames(12)
	check(session.settings.interior_view_mode==1 and not control.hint.visible,"Selecting full view records the choice and dismisses the hint")
	var full:=true
	for section in city.home.sections:
		if section.target<.99:full=false
		for material in section.materials:
			if float(material.get_shader_parameter("opacity"))<.99:full=false
	check(full,"Full view retains walls and roof with no cutaway shader")
	city.pitch=.9;city.distance_=14;city.camera_focus=city.bunny.position+Vector3.UP*1.35
	for i in range(20):city.update_camera(.1)
	check(city.home.to_local(city.camera.position).y<4.4 and city.camera_query.collision_mask==13,"Full-view camera respects real walls and ceiling instead of crossing them")
	await photo("free-full-indoor-camera")
	await key(KEY_V);check(session.settings.interior_view_mode==2,"V cycles from full view to free occlusion")
	city.pitch=.18
	for i in range(25):city.update_camera(.1)
	await frames();var relative: Vector3=(city.camera.position-city.camera_focus).normalized();check(relative.y<.35,"Free occlusion preserves the player's shallow pitch indoors")
	var hidden_walls:=0;var visible_walls:=0
	for section in city.home.sections:
		if section.roof or section.get("door",false):continue
		if section.target<.5:hidden_walls+=1
		else:visible_walls+=1
	check(hidden_walls>0 and visible_walls>0,"Free occlusion hides whole blocking wall faces while retaining other walls")
	await photo("free-occlusion-indoor-camera")
	await key(KEY_V);city.pitch=.18
	for i in range(25):city.update_camera(.1)
	check(session.settings.interior_view_mode==0 and (city.camera.position-city.camera_focus).normalized().y>.5,"Automatic view retains the original raised indoor pitch")
	await photo("automatic-indoor-camera")
	place_actor(Vector3(0,.2,9));await frames();check(not control.visible and not control.hint.visible,"Leaving indoors hides both camera button and guidance")
	await key(KEY_V);check(session.settings.interior_view_mode==0,"The indoor shortcut does not change camera modes outdoors")
	place_actor(city.home.to_global(Vector3(0,.2,0)));await frames();check(control.visible and not control.hint.visible and session.settings.interior_view_mode==0,"Re-entering preserves mode without repeating the first-time hint")
	place_actor(Vector3(59,.2,13));editor=city.build_mode;editor.open_editor();editor.focus=Vector3(79,0,10);editor.distance_=26;editor.update_camera();editor.commit(preload("res://scripts/building/templates.gd").cottage())
	check(not city.hud.visible,"Construction keeps its own camera and hides the gameplay camera control")
	editor.choose_tool("object:bed");check(not editor.ui.paint_row.visible,"Furniture placement does not expose a whole-object color brush");editor.choose_tool("select")
	var bed: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="bed")[0];editor.selected_id=bed.id;editor.refresh_ui();await frames();await click(editor.ui.appearance_button);await frames()
	check(editor.ui.appearance_panel.visible and editor.ui.appearance_panel.slot_ids==["frame","sheet","quilt","pillow"],"The actual appearance button exposes four named bed parts")
	var panel: Control=editor.ui.appearance_panel;await frames(25)
	check(editor.highlighted.is_empty(),"Selecting a material part leaves no persistent selection tint")
	var snapshot:=JSON.stringify(editor.layout);panel.color.color=Color("986a96");panel.color.color_changed.emit(panel.color.color);await frames()
	check(JSON.stringify(editor.layout)==snapshot,"Live appearance preview does not save or modify layout")
	check(editor.highlighted.is_empty() and editor.part_hint_left<=0.,"Changing color shows the real material with no green or identification overlay")
	await photo("bed-frame-appearance-preview");await click(panel.find_child("ApplyPartAppearance",true,false));await frames()
	bed=L.find(editor.layout,bed.id);check(bed.get("appearance",{}).get("frame",{}).get("color","")=="986a96" and bed.get("appearance",{}).size()==1,"Apply persists only the chosen frame appearance")
	panel.parts.select(2);panel.parts.item_selected.emit(2);panel.materials.select(panel.material_ids.find("sprig"));panel.materials.item_selected.emit(panel.materials.selected);panel.color.color=Color("789eaa");panel.color.color_changed.emit(panel.color.color);await click(panel.find_child("ApplyPartAppearance",true,false));await frames()
	bed=L.find(editor.layout,bed.id);check(bed.appearance.quilt.material=="sprig" and bed.appearance.frame.color=="986a96" and not bed.appearance.has("pillow"),"Applying a patterned quilt preserves the frame and original pillow")
	await photo("bed-part-colors-and-pattern");var wanted: String=editor.ui.selected_thumb_key
	for i in range(60):
		if editor.ui.studio.cache.has(wanted):break
		await frames(1)
	check(wanted.contains("@") and editor.ui.selected_preview.texture==editor.ui.studio.cache.get(wanted),"The selection thumbnail shows the saved custom part appearance")
	var saved_parts: Dictionary=L.find(editor.layout,bed.id).appearance.duplicate(true);panel.color.color=Color("ff0000");panel.color.color_changed.emit(panel.color.color);await key(KEY_ESCAPE);await frames()
	check(not panel.visible and L.find(editor.layout,bed.id).appearance==saved_parts,"Escape closes the appearance panel and cancels unsaved material preview")
	var quilt_mesh: MeshInstance3D=editor.room.get_node("Furnishing/"+bed.id).find_child("Quilt",true,false)
	check(quilt_mesh.material_override.get_shader_parameter("dye").to_html(false)=="789eaa","Cancelling preview restores the saved quilt color on the actual model")
	panel.close();var saved: Dictionary=editor.layout.duplicate(true);editor.begin_move();check(editor.place_at(Vector2(82,9)),"A customized bed remains movable");check(not L.find(editor.layout,bed.id).appearance.is_empty() and editor.room.get_node("Furnishing/"+bed.id).is_visible_in_tree(),"Moving preserves part appearance and model visibility")
	editor.undo();editor.selected_id=bed.id;editor.refresh_ui();editor.ui.appearance_panel.open(L.find(editor.layout,bed.id));editor.reset_appearance("frame");check(L.find(editor.layout,bed.id).appearance.frame=={"material":"original"} and L.find(editor.layout,bed.id).appearance.has("quilt"),"Resetting a part restores only that part")
	editor.reset_appearance("");check(not L.find(editor.layout,bed.id).has("appearance") and not L.find(editor.layout,bed.id).painted,"Reset all restores the furniture's complete original appearance")
	editor.undo();check(L.find(editor.layout,bed.id).appearance.has("quilt"),"One undo restores a reset custom appearance")
	editor.selected_id=bed.id;editor.refresh_ui();editor.apply_appearance_preset("sea");check(L.find(editor.layout,bed.id).appearance.size()==4,"A coordinated preset assigns each bed part separately")
	# One continuous wall includes a differently decorated cell: the whole face must hide together.
	var front: Dictionary=editor.layout.elements.filter(func(row):return row.type=="wall" and is_equal_approx(row.a[1],15.) and is_equal_approx(row.b[1],15.))[0]
	var unit:=L.unit_at(editor.layout,front.id,Vector2(81.25,15));var recolor:=unit.duplicate(true);recolor.color="9b759c";editor.commit(L.replace_unit(editor.layout,unit,recolor))
	editor.commit(L.merge_template(editor.layout,preload("res://scripts/building/templates.gd").cottage(),Vector2(91,21)))
	editor.close_editor();session.set_setting("interior_view_mode",2);place_actor(Vector3(79,.2,10));city.camera.position=Vector3(84,10,22);city.camera.look_at(Vector3(79,1,10));await frames(20)
	var complete_face:=true;var strips:=0;var isolated_roof:=false
	for section in editor.room.sections:
		var row: Dictionary=editor.room.render_cache.get(str(section.node.name),{}).get("row",{})
		if row.get("type","")=="wall" and is_equal_approx(row.a[1],15.) and is_equal_approx(row.b[1],15.):
			strips+=1
			if section.target>.5 or section.alpha>.1:complete_face=false
		if row.get("type","")=="roof" and L.rect(row).has_point(Vector2(91,21)):isolated_roof=section.target>.99 and section.alpha>.99
	check(complete_face and strips>=3,"All material runs on the blocking wall hide together, leaving no hole or colored strip")
	check(isolated_roof,"The separate house's non-blocking roof remains visible")
	await photo("custom-room-whole-wall-occlusion")

	var free_wall:=L.add(L.empty(),{"type":"wall","a":[74.,5.],"b":[80.,5.]});editor.commit(free_wall);place_actor(Vector3(77,.2,3));city.camera.position=Vector3(77,3,10);city.camera.look_at(Vector3(77,1,3));await frames(20)
	var complete_endcaps:=true
	for section in editor.room.sections:
		if section.alpha>.1:complete_endcaps=false
	check(complete_endcaps,"A hidden standalone wall also hides its endpoint trims, leaving no floating posts")
	print("APPEARANCE_CAMERA_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
