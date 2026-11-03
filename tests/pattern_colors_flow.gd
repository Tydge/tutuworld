extends SceneTree
const A=preload("res://scripts/building/appearance.gd")
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array[String]=[]
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=5) -> void:
	for i in count:await process_frame;RenderingServer.force_draw()
func photo(id: String) -> void:
	await frames(7);root.get_texture().get_image().save_png(out+"/"+id+".png")
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("布纹分区验收兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,1000);await create_timer(1.2).timeout;await frames()
	session.active=false;city.set_process(false);city.bunny.set_physics_process(false)
	var editor: Node=city.build_mode;editor.open_editor();editor.focus=Vector3(79,0,10);editor.distance_=26;editor.update_camera();editor.commit(preload("res://scripts/building/templates.gd").cottage())
	var bed: Dictionary=editor.layout.elements.filter(func(r):return r.get("kind","")=="bed")[0];editor.selected_id=bed.id;editor.refresh_ui()
	var panel: Control=editor.ui.appearance_panel;panel.open(bed)
	check(not panel.accent_box.visible,"The original wooden frame shows only its meaningful color channel")
	panel.parts.select(panel.slot_ids.find("quilt"));panel.parts.item_selected.emit(panel.parts.selected)
	check(panel.accent_box.visible and panel.accent.color==Color("e8dfbf"),"The original bed quilt exposes its actual existing accent color")
	for id in ["tartan","sprig","stripes","dots","daisies"]:
		panel.materials.select(panel.material_ids.find(id));panel.materials.item_selected.emit(panel.materials.selected)
		check(panel.accent_box.visible,"Every existing and new SVG/AI fabric exposes both colors: "+id)
		var before:=JSON.stringify(editor.layout);panel.color.color=Color("789eaa");panel.color.color_changed.emit(panel.color.color);panel.accent.color=Color("c76c82");panel.accent.color_changed.emit(panel.accent.color);await frames()
		check(JSON.stringify(editor.layout)==before and editor.highlighted.is_empty(),"Dual-color live preview neither saves nor applies a selection overlay: "+id)
		panel.find_child("ApplyPartAppearance",true,false).pressed.emit();await frames()
		bed=L.find(editor.layout,bed.id);var quilt: MeshInstance3D=editor.room.get_node("Furnishing/"+bed.id).find_child("Quilt",true,false)
		check(bed.appearance.quilt.accent=="c76c82" and bed.appearance.quilt.color=="789eaa" and quilt.material_override.get_shader_parameter("accent")==Color("c76c82"),"Apply stores both colors and updates the actual model: "+id)
		if id in ["dots","daisies"]:await photo("two-colors-"+id)
	var saved: Dictionary=bed.appearance.duplicate(true);panel.accent.color=Color("00ff00");panel.accent.color_changed.emit(panel.accent.color);panel.close();await frames()
	var quilt: MeshInstance3D=editor.room.get_node("Furnishing/"+bed.id).find_child("Quilt",true,false)
	check(L.find(editor.layout,bed.id).appearance==saved and quilt.material_override.get_shader_parameter("accent")==Color("c76c82"),"Closing cancels an unsaved secondary color preview")
	editor.reset_appearance("quilt");check(not L.find(editor.layout,bed.id).appearance.quilt.has("accent"),"Resetting a part removes its secondary color override")
	editor.undo();check(L.find(editor.layout,bed.id).appearance.quilt.accent=="c76c82","Undo restores both pattern color channels")
	editor.selected_id=bed.id;editor.refresh_ui();panel.open(L.find(editor.layout,bed.id));panel.parts.select(panel.slot_ids.find("quilt"));panel.parts.item_selected.emit(panel.parts.selected)
	panel.materials.select(panel.material_ids.find("solid"));panel.materials.item_selected.emit(panel.materials.selected);check(not panel.accent_box.visible,"Switching to solid hides the unused pattern color")
	panel.materials.select(panel.material_ids.find("dots"));panel.materials.item_selected.emit(panel.materials.selected)
	root.size=Vector2i(1280,720);await create_timer(.7).timeout;await frames()
	check(root.get_visible_rect().encloses(panel.get_global_rect()),"The two-color panel fits a 720px-high window")
	await photo("two-color-panel-720")
	panel.close();var path:=out+"/isolated-save.json";session.save_path=path;session.test_mode=false;var written: bool=session.save_game();session.test_mode=true
	var recovered=load("res://scripts/services/session.gd").new();recovered.name="ColorsRecovered";root.add_child(recovered);recovered.save_path=path;recovered.load_save()
	check(written and L.find(recovered.state().build_layout,bed.id).appearance==L.find(editor.layout,bed.id).appearance,"A real isolated save reloads the full independent color appearance")
	print("PATTERN_COLORS_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
