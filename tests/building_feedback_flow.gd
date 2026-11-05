extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const T=preload("res://scripts/building/templates.gd")
const S=preload("res://scripts/building/storeys.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func capture(name_: String) -> void:
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建造验证兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout;root.size=Vector2i(1440,900)
	var editor=city.build_mode;editor.open_editor();editor.set_process(false)
	check(editor.commit(T.player_sample("two_storey")),"Player's edited two-storey template commits in isolated world")
	editor.set_storey(0);editor.set_roof_visible(true)
	check(not editor.room.get_node("Structure/Roof").visible,"Complete walls on 1F keep roof hidden")
	editor.set_storey(editor.view_level()+1)
	check(editor.editing_storey==1 and not editor.roof_view,"Up from 1F enters existing 2F")
	check(not editor.room.get_node("Structure/Roof").visible and editor.show_roof,"Complete-wall preference persists on 2F without roof")
	editor.focus=Vector3(139,4.7,10);editor.distance_=34.;editor.pitch=.9;editor.update_camera();await capture("second-floor-full-walls")
	editor.set_storey(editor.view_level()+1)
	check(editor.roof_view and editor.room.get_node("Structure/Roof").visible,"Up from highest storey shows roof")
	check(editor.ui.root_ui.find_child("FloorUp",true,false).disabled,"No phantom third or fourth floor in navigation")
	await capture("roof-navigation")
	editor.set_storey(editor.view_level()-1)
	check(editor.editing_storey==1 and not editor.roof_view and not editor.room.get_node("Structure/Roof").visible,"Down from roof returns to 2F interior")
	editor.ui.show_templates()
	for i in range(40):await process_frame;RenderingServer.force_draw()
	await capture("sample-catalog")
	for kind in ["single_one","two_storey"]:check(editor.ui.cards["template:"+kind].visible and editor.ui.card_images["template:"+kind].texture!=null,"Template choice exists: "+kind)
	editor.ui.choose_card("template:two_storey");check(editor.template_kind=="two_storey" and editor.tool=="template","Template card selects placement tool")
	editor.ui.show_category("结构")
	var window: Dictionary=editor.layout.elements.filter(func(row):return row.type=="window" and S.of(row)==1)[0]
	editor.choose_tool("select");editor.selected_id=window.id;editor.begin_move()
	var row:=window.duplicate(true);row.erase("anchor");editor.update_structure_preview(row,true);var instance: int=editor.preview.get_instance_id();var elapsed: Array=[]
	for i in range(80):
		row.offset=2.+(i%16)*.5
		var start:=Time.get_ticks_usec();var result:=L.preview_opening(editor.layout,row,window.id);editor.update_structure_preview(row,result.ok);elapsed.append((Time.get_ticks_usec()-start)/1000.)
		check(editor.preview.get_instance_id()==instance,"Window move retains cached instance")
	elapsed.sort();print("WINDOW_PREVIEW_MS median=",elapsed[40]," p95=",elapsed[76]," max=",elapsed[-1]);editor.choose_tool("select")
	# Constructing a new storey from the roof must remain possible, without arbitrary floor selection.
	check(editor.commit(T.cottage()),"Single-storey fixture")
	editor.set_storey(1);editor.choose_tool("floor");editor.start_point=Vector2(73,5)
	check(editor.row_at(Vector2(85,15)).storey==1,"Floor tool in roof view targets the new upper level")
	check(editor.place_at(Vector2(85,15)),"New floor replaces fully covered lower roof")
	check(editor.editing_storey==1 and not editor.roof_view,"Successful extension enters the newly built floor")
	editor.set_storey(0);editor.set_storey(1);check(not editor.roof_view,"Newly built upper floor remains editable before stairs are installed")
	print("BUILDING_FEEDBACK_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
