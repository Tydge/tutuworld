extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const C=preload("res://scripts/building/structure_catalog.gd")
var checks:=0
var failures: Array=[]
var out: String
var editor: Node
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func select_unit(type: String,point: Vector2) -> void:
	var source: Dictionary
	if type=="floor":source=L.compiled(editor.layout).floors[preload("res://scripts/building/grid_layout.gd").cell(point)]
	else:source=L.compiled(editor.layout).walls[Vector3i(floori(point.x*2.),roundi(point.y*2.),0)]
	editor.choose_tool("select");editor.selected_id=source.id;editor.selected_unit=L.unit_at(editor.layout,source.id,point);editor.refresh_ui()
func apply(color: String,style: String) -> void:
	editor.ui.color.color=Color(color);editor.ui.style.select(C.STYLES.find(style));editor.ui.apply_button.pressed.emit()
func photo(id: String) -> void:
	for i in range(5):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out+"/"+id+".png")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("房间装修兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await create_timer(.5).timeout
	editor=city.build_mode;editor.open_editor();var data:=L.add(L.empty(),{"type":"floor","a":[66.,0.],"b":[90.,12.],"style":"wood","color":"cda56e"})
	for pair in [[[66.,0.],[90.,0.]],[[90.,0.],[90.,12.]],[[90.,12.],[66.,12.]],[[66.,12.],[66.,0.]],[[78.,0.],[78.,12.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
	check(editor.commit(data),"Two neighboring rooms are editable through the ordinary session boundary")
	select_unit("floor",Vector2(68.25,4.25));check(editor.ui.batch_paint.visible and editor.ui.batch_paint.button_pressed,"A selected tile exposes the default room-wide choice")
	apply("dbcdbb","terrazzo")
	check(L.compiled(editor.layout).floors.values().filter(func(row):return row.style=="terrazzo").size()==576,"The visible Apply button paints matching tiles in only this room")
	check(L.compiled(editor.layout).floors[Vector2i(164,8)].style=="wood","Adjacent room stays unchanged through the actual UI action")
	editor.undo();check(L.compiled(editor.layout).floors[Vector2i(136,8)].style=="wood","One undo restores the entire room paint transaction")
	editor.redo();select_unit("floor",Vector2(68.25,4.25));editor.ui.batch_paint.button_pressed=false;apply("b7906e","herringbone")
	check(L.compiled(editor.layout).floors.values().filter(func(row):return row.style=="herringbone").size()==1,"Turning off the choice limits the UI action to exactly one cell")
	select_unit("wall",Vector2(68.25,0));editor.ui.batch_paint.button_pressed=true;editor.ui.wall_face.select(0);apply("a6b398","botanical")
	var row: Dictionary=L.compiled(editor.layout).walls[Vector3i(136,0,0)];check(C.surface(row,"positive").style=="botanical" and C.surface(row,"negative").style=="original","Inside paint preserves the exterior finish")
	editor.ui.batch_paint.button_pressed=false;editor.ui.wall_face.select(1);editor.ui.wall_face.item_selected.emit(1);apply("c8a892","brick")
	row=L.compiled(editor.layout).walls[Vector3i(136,0,0)];check(C.surface(row,"positive").style=="botanical" and C.surface(row,"negative").style=="brick","The exterior selector changes the opposite face independently")
	var checkbox: CheckButton=editor.ui.root_ui.find_child("ShowRoof",true,false);checkbox.button_pressed=true
	check(editor.show_roof and editor.room.sections.all(func(section):return not section.get("editor_hidden",false)),"Complete roof/wall switch exposes all walls through its real control")
	await photo("wall-face-controls-720")
	# Show each new floor finish at a useful size, using the same model/material path.
	for index in range(3):
		var style: String=["herringbone","terrazzo","botanical"][index];var painted:=L.empty();painted=L.add(painted,{"type":"floor","a":[72.,4.],"b":[86.,16.],"style":style,"color":["c5a37c","ddd0bb","b7c5ad"][index]});editor.commit(painted);editor.focus=Vector3(79,0,10);editor.distance_=16.;editor.pitch=1.05;editor.update_camera();editor.ui.hide();editor.grid.hide();await photo("surface-"+style);editor.ui.show();editor.grid.show()
	print("BUILDING_SURFACE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
