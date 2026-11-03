extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("原地完成建造兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;city.set_process(false);city.bunny.set_physics_process(false)
	var editor: Node=city.build_mode
	for index in 3:
		var position_: Vector3=[Vector3(30,.2,3),Vector3(65,.2,25),Vector3(79,.33,13)][index]
		city.bunny.position=position_;city.bunny.reset_physics_interpolation();session.set_player_position(position_)
		check(editor.open_editor().ok,"Build mode opens at an arbitrary player location: "+str(index))
		editor.commit(preload("res://scripts/building/templates.gd").cottage())
		if index==0:editor.ui.root_ui.find_child("FinishBuilding",true,false).pressed.emit()
		else:
			var event:=InputEventKey.new();event.keycode=KEY_ESCAPE if index==1 else KEY_F6;event.pressed=true;Input.parse_input_event(event);await process_frame
		check(not editor.active and city.bunny.can_move and not city.paused and session.active,"Finish button / Esc / F6 restores normal controls: "+str(index))
		check(city.bunny.position==position_,"Finishing preserves the exact player location: "+str(index))
		check(session.state().player_position==[position_.x,position_.y,position_.z],"The saved player position uses the current location: "+str(index))
		check(city.camera_focus.distance_to(position_+Vector3.UP*1.35)<.001,"The gameplay camera returns to the player at their actual location: "+str(index))
		var released:=InputEventKey.new();released.keycode=KEY_ESCAPE if index==1 else KEY_F6;released.pressed=false;Input.parse_input_event(released);await process_frame
	print("BUILDING_EXIT_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
