extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const E=preload("res://scripts/building/storey_extension.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func capture(name_: String) -> void:
	for i in range(3):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func click(control: Control) -> void:
	var p:=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))
	var motion:=InputEventMouseMotion.new();motion.position=p;Input.parse_input_event(motion);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=p;event.global_position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func walk(actor: CharacterBody3D,path: PackedVector3Array) -> bool:
	for target in path:
		var frames:=0
		while Vector2(actor.position.x-target.x,actor.position.z-target.z).length()>.13 and frames<360:
			var direction: Vector3=target-actor.position;direction.y=0;actor.simulate_movement(1./60.,direction.normalized(),false,false);frames+=1;await physics_frame
		if frames>=360:print("STUCK ",actor.position," target=",target);return false
	for i in range(20):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
	return absf(actor.position.y-path[-1].y)<.25
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("扩建验证兔","bunny","bow_rose")
	check(session.settings.show_other_storey_objects,"New and existing preferences default to showing other storeys")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,1000);await create_timer(.7).timeout
	editor=city.build_mode;editor.open_editor();editor.set_process(false);city.set_process(false);city.bunny.set_physics_process(false);city.bunny.hide()
	for form in Stairs.FORMS:
		for turn in [0.,90.,180.,270.]:
			var base:=L.add(L.empty(),{"type":"floor","a":[108.,-6.],"b":[138.,26.],"style":"herringbone"})
			check(editor.commit(base),"Ground-only fixture "+form+"/"+str(turn));editor.set_storey(0);editor.choose_tool("stairs:"+form);editor.rotation=turn
			var before:=JSON.stringify(editor.layout);editor.update_ghost(Vector2(120,10))
			check(editor.preview.has_node("LandingPreview"),"Stair preview includes the actual upper landing")
			check(editor.preview.find_children("*","CollisionObject3D",true,false).all(func(body):return body.collision_layer==0),"Preview never adds real collision")
			check(JSON.stringify(editor.layout)==before,"Preview does not save a floor or stair")
			check(editor.place_at(Vector2(120,10)),"Stairs first commits atomically")
			var row: Dictionary=editor.selected_row();check(row.type=="stairs" and L.compiled(editor.layout,1).floors.size()==3840-Stairs.hole_cells(row).size(),"Commit selects stair and builds the connected upstairs floor")
			await physics_frame;await physics_frame
			var guard: Node3D=editor.room.render_cache[row.id].node.get_node("UpperGuard");var supported:=true
			for body in guard.find_children("*","StaticBody3D",true,false):
				var points: PackedVector3Array=body.get_child(0).shape.points
				for i in [0,4]:
					var found:=false
					for index in [i,i+2]:
						var local: Vector3=points[index].lerp(points[index+4 if i==0 else index-4],.002)
						var foot: Vector3=body.global_transform*local
						if not city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.06,foot-Vector3.UP*.3,8)).is_empty():found=true
					if not found:supported=false;print("UNSUPPORTED ",form,"/",turn," ",body.get_path()," ",body.global_transform*points[i])
			check(supported and not guard.get_children().is_empty(),"Landing rails have real floor support in this rotation")
			if form=="u" and turn==0.:
				editor.set_storey(1);editor.focus=Vector3(120,4.7,10);editor.distance_=26.;editor.pitch=.9;editor.update_camera();await capture("stairs-first-platform")
				var actor:=Animals.create("bunny");city.add_child(actor);actor.world=city;actor.collision_mask=15;actor.set_physics_process(false);var path:=Stairs.route(row);actor.position=path[0]+Vector3.UP*.1;city.paused=false
				for i in range(20):actor.simulate_movement(1./60.,Vector3.ZERO,false,false);await physics_frame
				check(await walk(actor,path),"Physically walk onto an automatically generated platform")
				path.reverse();check(await walk(actor,path),"Physically walk back down from the minimal platform");actor.free();city.paused=true
			editor.undo();check(JSON.stringify(editor.layout)==before,"One undo removes the stair, platform and guard together")
			editor.redo();check(L.compiled(editor.layout,1).floors.size()==3840-Stairs.hole_cells(row).size(),"Redo restores stair and upstairs floor together")
	var cottage:=preload("res://scripts/building/templates.gd").cottage();cottage.elements=cottage.elements.filter(func(row):return row.type!="object")
	check(editor.commit(cottage),"Roofed house fixture");editor.set_storey(1);editor.focus=Vector3(79,0,10);editor.distance_=30.;editor.update_camera()
	var before:=JSON.stringify(editor.layout)
	await click(editor.ui.root_ui.find_child("GenerateUpperFloor",true,false));check(editor.tool=="upper_floor" and is_instance_valid(editor.preview),"Visible button opens an actual upstairs floor preview")
	check(not editor.upper_floor_locked and editor.ui.upper_floor_confirm.disabled,"Preview requires explicit range selection before confirmation")
	editor.update_upper_floor(Vector2(79,10),true);await capture("upper-floor-preview")
	check(not editor.preview_walls.is_empty() and editor.preview_walls.all(func(pair):return not pair[0].visible),"Roofs to replace are visually hidden so the new slab preview is visible")
	check(editor.upper_floor_plan.removed_roofs==1 and JSON.stringify(editor.layout)==before,"Roof replacement is shown before saving anything")
	await click(editor.ui.upper_floor_confirm)
	check(editor.editing_storey==1 and not editor.roof_view and L.compiled(editor.layout,1).floors.size()==480,"Confirm builds upstairs and enters the new floor")
	check(editor.layout.elements.all(func(row):return row.type!="roof"),"Roof is replaced in the same committed operation")
	editor.undo();check(JSON.stringify(editor.layout)==before,"Undo restores the roof and removes the new floor")
	await click(editor.ui.root_ui.find_child("GenerateUpperFloor",true,false));editor.update_upper_floor(Vector2(79,10),true)
	await click(editor.ui.root_ui.find_child("CancelUpperFloor",true,false));check(editor.tool=="select" and JSON.stringify(editor.layout)==before,"Cancel discards the upstairs plan without saving")
	check(editor.room.get_node("Structure/Roof").get_children().all(func(roof):return roof.visible),"Cancelling restores the original roof visuals")
	var houses:=L.empty();var ids: Dictionary={}
	for index in [0,1]:
		var x: float=70.+index*24.
		for level in [0,1]:
			houses=L.add(houses,{"type":"floor","a":[x,0.],"b":[x+12.,10.],"storey":level})
			for pair in [[[x,0.],[x+12.,0.]],[[x+12.,0.],[x+12.,10.]],[[x+12.,10.],[x,10.]],[[x,10.],[x,0.]]]:houses=L.add(houses,{"type":"wall","a":pair[0],"b":pair[1],"storey":level})
			houses=L.add(houses,{"type":"object","kind":"chair","position":[x+4.,4.],"yaw":0.,"storey":level});ids[str(index)+str(level)]=houses.elements[-1].id
	check(editor.commit(houses),"Two detached furnished houses coexist");editor.close_editor();city.set_process(false);city.bunny.set_physics_process(false);var room: Node3D=editor.room;room.set_process(false)
	session.settings.interior_view_mode=1;city.bunny.position=Vector3(74,.18,4);room.refresh_view(Vector3(76,3,12),city.bunny.position)
	check(ids.values().all(func(id):return room.render_cache[id].node.is_visible_in_tree()),"Default setting shows upstairs and downstairs furnishings")
	city.hud.open_panel("settings");var toggle: CheckButton=city.hud.root_ui.find_child("ShowOtherStoreyObjects",true,false)
	check(toggle!=null and toggle.button_pressed,"Settings exposes the default-on furniture switch")
	await capture("furniture-visibility-setting");await click(toggle);room.refresh_view(city.camera.global_position,city.bunny.position)
	check(not session.settings.show_other_storey_objects and not room.render_cache[ids["01"]].node.visible,"Switch off restores current-house floor culling immediately")
	check(room.render_cache[ids["11"]].node.visible,"Another house's upstairs remains furnished when switch is off")
	city.bunny.position=Vector3(74,4.88,4);room.refresh_view(city.camera.global_position,city.bunny.position)
	check(not room.render_cache[ids["00"]].node.visible and room.render_cache[ids["10"]].node.visible,"Upstairs culling affects only the occupied house's covered lower floor")
	session.save_path=preload("res://tests/test_support.gd").output_dir()+"/visibility-save.json";session.test_mode=false
	check(session.save_game(),"Write actual settings to an isolated save path");session.test_mode=true
	var loaded=load("res://scripts/services/session.gd").new();loaded.test_mode=true;loaded.save_path=session.save_path;loaded.load_save()
	check(not loaded.settings.show_other_storey_objects,"Furniture switch survives a real isolated save reload");loaded.free()
	await click(toggle);room.refresh_view(city.camera.global_position,city.bunny.position)
	check(session.settings.show_other_storey_objects and ids.values().all(func(id):return room.render_cache[id].node.visible),"Switch on restores all storey furnishings without rebuilding")
	city.bunny.position=Vector3(88,.18,15);session.set_setting("show_other_storey_objects",false);room.refresh_view(city.camera.global_position,city.bunny.position)
	check(ids.values().all(func(id):return room.render_cache[id].node.visible),"Outdoor observation does not hide either house's furniture")
	check(city.home.get_node("Furnishing").is_visible_in_tree(),"Existing packed houses also keep interiors visible from outside")
	print("STOREY_EXTENSION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
