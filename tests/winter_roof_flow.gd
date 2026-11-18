extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Factory=preload("res://scripts/building/module_factory.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func snowy_parts(node: Node3D) -> Array:
	return node.find_children("*","MeshInstance3D",true,false).filter(func(part):return part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and part.material_override is ShaderMaterial and part.material_override.get_shader_parameter("roof_snow")==true)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.background_throttle=false
	session.create_character("积雪屋顶测试","bunny","scarf_red")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null or city.preparing:await process_frame
	var editor: Node=city.build_mode;editor.open_editor()
	var data:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[80.,10.]})
	data=L.add(data,{"type":"roof","a":[70.,0.],"b":[80.,10.]})
	check(editor.commit(data),"Normal build layout accepts a roof without new settings")
	var roof: Dictionary=editor.layout.elements.filter(func(row):return row.type=="roof")[0]
	editor.selected_id=roof.id;editor.refresh_ui()
	var toggle: CheckButton=editor.ui.root_ui.find_child("RoofSnow",true,false)
	check(toggle.visible and not toggle.button_pressed,"Selecting a roof exposes the off-by-default snow control")
	toggle.button_pressed=true
	check(L.find(editor.layout,roof.id).get("snow",false) and not snowy_parts(editor.room.get_node("Structure/Roof")).is_empty(),"Real control saves snow and preserves it through mesh batching")
	editor.undo();check(not L.find(editor.layout,roof.id).get("snow",false),"One undo removes roof snow")
	editor.redo();check(L.find(editor.layout,roof.id).get("snow",false),"Redo restores roof snow")
	check(L.validate(JSON.parse_string(JSON.stringify(editor.layout))).layout==editor.layout,"Roof snow round-trips through durable layout validation")
	var bad: Dictionary=editor.layout.duplicate(true)
	for row in bad.elements:
		if row.type=="roof":row.snow="true"
	check(not L.validate(bad).ok,"Authority rejects malformed snow settings")
	for form in ["classic","hip","shed"]:
		var model:=Node3D.new();city.add_child(model);var b:=Factory.builder(model);b.blueprint.snow=true;b.roof_form=form;b.build_roof(model);b.bake_section(model)
		check(not snowy_parts(model).is_empty(),"Snow survives batching for "+form+" roof")
		model.free()
	editor.selected_id=roof.id;editor.refresh_ui();toggle.button_pressed=false
	check(not L.find(editor.layout,roof.id).get("snow",false) and snowy_parts(editor.room.get_node("Structure/Roof")).is_empty(),"Turning snow off restores the ordinary roof")
	editor.close_editor()
	print("WINTER_ROOF_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	city.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
