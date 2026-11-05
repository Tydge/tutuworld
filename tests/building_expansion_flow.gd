extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const C=preload("res://scripts/building/catalog.gd")
const Forms=preload("res://scripts/building/structure_catalog.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
var out: String
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func photo(name_: String) -> void:
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out+"/"+name_+".png")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("扩充验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await create_timer(.6).timeout;editor=city.build_mode;editor.open_editor()
	check(editor.ui.batch_paint.button_pressed,"Room-wide matching paint is enabled by default")
	check(editor.ui.root_ui.find_child("ShowRoof",true,false).text=="查看完整墙壁","The complete-wall switch is independent of roof navigation")
	for family in Forms.FORMS:
		editor.ui.show_category("结构");editor.ui.tools[family].pressed.emit();await process_frame
		var count_:=0
		for id in editor.ui.cards:
			if editor.ui.cards[id].visible:count_+=1
		check(count_==3 and editor.ui.breadcrumb.visible,"A structural parent opens exactly three form cards: "+family)
		for form in Forms.FORMS[family]:editor.ui.tools[family+":"+form].pressed.emit();check(editor.tool==family and editor.structure_form==form,"Visible form card chooses the real placement model: "+family+"/"+form)
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await process_frame
	await photo("roof-subcatalog-720")
	var data:=L.add(L.empty(),{"type":"floor","a":[62.,-6.],"b":[96.,26.],"color":"cda56e","style":"wood"});data=L.add(data,{"type":"wall","a":[63.,4.],"b":[95.,4.],"faces":{"positive":{"color":"9bad95","style":"botanical"},"negative":{"color":"cfb49a","style":"brick"}}});var wall: String=data.elements[-1].id
	var index:=0
	for family in ["door","window"]:
		for form in Forms.FORMS[family]:data=L.add(data,{"type":family,"form":form,"wall":wall,"offset":3.+index*5.});index+=1
	var roofs: Array=[];index=0
	for form in Forms.FORMS.roof:data=L.add(data,{"type":"roof","form":form,"a":[63.+index*12.,7.],"b":[72.+index*12.,14.],"color":"688d81"});roofs.append(data.elements[-1].id);index+=1
	index=0
	for kind in ["bed","canopy_bed","cloud_bed"]:data=L.add(data,{"type":"object","kind":kind,"position":[67.+index*8.,-2.],"yaw":0.});index+=1
	data=L.add(data,{"type":"object","kind":"petal_armchair","position":[89.,-2.],"yaw":0.});data=L.add(data,{"type":"object","kind":"floor_lamp","position":[93.,-2.],"yaw":0.})
	index=0
	for kind in ["tea_service","field_journal","pressed_leaves","ceramic_vases"]:
		var x:=65.+index*8.;data=L.add(data,{"type":"object","kind":"desk","position":[x,18.],"yaw":0.});var support: String=data.elements[-1].id;data=L.add(data,{"type":"object","kind":kind,"position":[x,18.],"yaw":0.,"support":support});index+=1
	for row in [{"kind":"moon_mobile","position":[67.,10.],"support":roofs[0]},{"kind":"lotus_pendant","position":[79.,10.],"support":roofs[1]},{"kind":"woven_basket","position":[94.,18.]},{"kind":"rose_arch","position":[66.,23.]},{"kind":"lily_pond","position":[75.,23.]}]:row.type="object";row.yaw=0.;data=L.add(data,row)
	check(editor.commit(data),"All new models and all nine structural forms coexist in one valid layout")
	if not failures.is_empty():print("FIXTURE ",L.validate(data));finish();return
	editor.set_storey(preload("res://scripts/building/storeys.gd").highest(editor.layout)+1);editor.set_roof_visible(true);editor.focus=Vector3(79,1,10);editor.distance_=45.;editor.pitch=.90;editor.update_camera();await photo("full-building-showcase")
	for section in editor.room.sections:check(not section.get("editor_hidden",false),"Complete view keeps every wall face visible")
	for kind in ["bed","canopy_bed","cloud_bed"]:
		var row: Dictionary=editor.layout.elements.filter(func(item):return item.get("kind","")==kind)[0];var module: Node3D=editor.room.render_cache[row.id].node;var target:="build:"+str(row.id)
		check(city.targets.has(target) and city.targets[target].kind=="bed","Every bed registers its own sleeping target: "+kind)
		editor.close_editor();city.bunny.position=module.get_node("ActionAnchor").global_position;city.bunny.velocity=Vector3.ZERO;city.bunny.reset_physics_interpolation();city.current_target=target;session.set_player_position(city.bunny.position);await physics_frame;city.enter_sleep()
		check(city.sleep_active and city.bunny.sleeping and session.state().rest_bed==target,"Normal interaction lies in the chosen actual bed: "+kind)
		await create_timer(.3).timeout
		if kind=="canopy_bed":city.camera.position=module.global_position+Vector3(5,4,6);city.camera.look_at(module.global_position+Vector3(0,1,0));await photo("canopy-sleep")
		city.wake_from_bed();check(not city.sleep_active and not city.bunny.sleeping and city.bunny.can_move,"Waking finds real floor outside bed collision: "+kind);editor.open_editor()
	for kind in ["sofa","forest_settee","chair","petal_armchair"]:
		var model:=Node3D.new();city.add_child(model);preload("res://scripts/building/module_factory.gd").builder(model).build_item(model,kind)
		check(model.has_node("SeatSlot0") and preload("res://scripts/city/seating.gd").capacity(model)==int(C.OBJECTS[kind].get("seats",1)),"Every buildable chair exposes its declared physical seating: "+kind);model.queue_free()
	# Ask the same studio for every added model and every structural form.
	var keys: Array=[]
	for kind in ["tea_service","field_journal","pressed_leaves","ceramic_vases","woven_basket","moon_mobile","petal_armchair","floor_lamp","lotus_pendant","canopy_bed","cloud_bed","rose_arch","lily_pond"]:keys.append(kind);editor.ui.studio.request(kind)
	for family in Forms.FORMS:
		for form in Forms.FORMS[family]:keys.append(family+":"+form);editor.ui.studio.request(family+":"+form)
	var deadline:=Time.get_ticks_msec()+45000
	while (editor.ui.studio.busy or not editor.ui.studio.pending.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
	for key in keys:
		check(editor.ui.studio.cache.has(key) and editor.ui.studio.valid_image(editor.ui.studio.cache[key].get_image()),"A real nonempty thumbnail is available: "+key)
		if editor.ui.studio.cache.has(key):editor.ui.studio.cache[key].get_image().save_png(out+"/model-"+str(key).replace(":","-")+".png")
	editor.ui.show_category("床");editor.focus=Vector3(79,1,0);editor.distance_=27.;editor.update_camera();await photo("beds-catalog-720")
	finish()
func finish() -> void:
	print("BUILDING_EXPANSION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
