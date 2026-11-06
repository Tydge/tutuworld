extends SceneTree
## Hidden roofs must never intercept editing, including complete-wall mode.
const L=preload("res://scripts/building/layout.gd")
const S=preload("res://scripts/building/storeys.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("逐层选取测试","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;city.set_process(false);city.bunny.set_physics_process(false)
	var editor=city.build_mode;editor.open_editor();editor.set_process(false)
	check(editor.ui.root_ui.find_child("EntireBuilding",true,false)==null and editor.ui.root_ui.find_child("ShowRoof",true,false).text=="完整墙壁","Build UI has one complete-wall switch")
	for levels in [2,4]:
		var data:=L.empty()
		for level in range(levels):
			data=L.add(data,{"type":"floor","a":[70.,1.],"b":[82.,13.],"storey":level})
			for line in [[[70.,1.],[82.,1.]],[[70.,1.],[70.,13.]],[[82.,1.],[82.,13.]],[[70.,13.],[82.,13.]]]:data=L.add(data,{"type":"wall","a":line[0],"b":line[1],"storey":level})
			data=L.add(data,{"type":"object","kind":"chair","position":[76.,7.],"yaw":0.,"storey":level})
		data=L.add(data,{"type":"roof","a":[70.,1.],"b":[82.,13.],"storey":levels-1})
		check(editor.commit(data),"Stacked pick fixture: "+str(levels)+" floors")
		await physics_frame;await physics_frame
		for level in range(levels):
			for full in [false,true]:
				editor.set_storey(level);editor.set_roof_visible(full)
				var base: float=level*S.HEIGHT
				city.camera.position=Vector3(76,base+18,13);city.camera.look_at(Vector3(76,base+1,7))
				for sample in [["object",Vector3(76,base+.9,7)],["floor",Vector3(78,base+.18,7)],["wall",Vector3(76,base+.5,1)]]:
					var id: String=editor.pick_at(city.camera.unproject_position(sample[1]));var row:=L.find(editor.layout,id)
					check(row.get("type","")==sample[0] and S.of(row)==level,"Pick %s on %dF/%dF, complete=%s (got %s)"%[sample[0],level+1,levels,full,row.get("type","")])
			editor.set_roof_visible(true);editor.set_storey(level)
			check(editor.show_roof,"Changing floor retains the complete-wall preference")
		editor.focus=Vector3(76,(levels-1)*S.HEIGHT,7);editor.pitch=.95;editor.distance_=27;editor.update_camera()
		editor.select_at(city.camera.unproject_position(Vector3(76,(levels-1)*S.HEIGHT+.9,7)))
		for i in range(4):await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/complete-walls-%df-selection.png"%levels)
		editor.set_storey(levels)
		city.camera.position=Vector3(76,levels*S.HEIGHT+18,13);city.camera.look_at(Vector3(76,levels*S.HEIGHT,7))
		var roof:=L.find(editor.layout,editor.pick_at(city.camera.unproject_position(Vector3(76,levels*S.HEIGHT+.5,7))))
		check(roof.get("type","")=="roof","Roof remains selectable in the explicit roof view")
	city.free();session.free();await process_frame
	print("BUILDING_SELECTION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
