extends SceneTree
const Land=preload("res://scripts/building/parcels.gd")
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var session: Node
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=4) -> void:
	for i in range(count):await process_frame;RenderingServer.force_draw()
func photo(name_: String) -> void:
	await frames(4);root.get_texture().get_image().save_png(output+"/"+name_+".png")
func move_to(p: Vector3) -> void:
	city.bunny.position=p;city.bunny.reset_physics_interpolation();session.set_player_position(p)
func click(control: Control) -> void:
	var p: Vector2=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5));var motion:=InputEventMouseMotion.new();motion.position=p;Input.parse_input_event(motion);await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=p;event.global_position=p;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func press_interact() -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("地皮验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;session.active=false;city.set_process(false);city.bunny.set_physics_process(false)
	var editor: Node=city.build_mode
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await frames(1)
	check(editor.layout.elements.is_empty(),"Fresh parcel world never auto-installs the old showcase house")
	check(not editor.open_nearby_parcel().ok,"Build entry refuses a remote player")
	var site: Node3D=city.scenery.get_node("EastBuildingSite")
	check(site.has_node("WideSandBeach") and site.has_node("SlopingShore"),"Island has actual wide beach and sloping shore meshes")
	check(site.get_node("GardenCommons").get_children().filter(func(n):return str(n.name).begins_with("PublicTree")).size()>=20,"Public areas contain authored trees")
	check(site.get_node("GardenCommons").get_children().filter(func(n):return str(n.name).begins_with("PlazaFlowerbed")).size()==3,"Public gardens contain the plaza and two planted axial accents")
	var supported:=true
	for id in Land.IDS:
		var rect:=Land.bounds(id)
		for point in [rect.get_center(),rect.position+Vector2.ONE,rect.end-Vector2.ONE]:
			var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,3,point.y),Vector3(point.x,-3,point.y),8)
			var hit: Dictionary=city.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.9:supported=false
	check(supported,"Every parcel has real upward-facing walkable ground across its corners and centre")
	var shore: Dictionary=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(110,3,38),Vector3(110,-3,38),8))
	check(not shore.is_empty() and shore.position.y<0. and shore.position.y>-.6,"Beach-to-sea slope has matching walkable collision")
	var bridge: Node3D=site.get_node("GardenBridge")
	check(bridge.has_node("StoneArch") and bridge.has_node("TimberDeck") and bridge.has_node("ContinuousRailCollision"),"Entrance is a real arched bridge with timber deck and physical railings")
	var bridge_support:=true;var previous_height:=.047
	for i in range(45):
		var x: float=40.+i*.5;var hit: Dictionary=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,4,13),Vector3(x,-2,13),8))
		if hit.is_empty() or absf(hit.position.y-previous_height)>.20:bridge_support=false
		if not hit.is_empty():previous_height=hit.position.y
	check(bridge_support,"Bridge deck supports the full crossing without holes or abrupt steps")
	move_to(Vector3(40,.12,13));city.bunny.can_move=true
	var crossed:=true
	for i in range(275):
		await physics_frame
		city.bunny.velocity=Vector3(5.,-1.,0.);city.bunny.move_and_slide()
		if city.bunny.position.y<-.2:crossed=false
	check(crossed and city.bunny.position.x>61.8,"Actual character crosses from town to the parcel island along the curved bridge")
	city.bunny.velocity=Vector3.ZERO;city.bunny.can_move=false
	city.hud.hide();city.camera.position=Vector3(53,9,33);city.camera.look_at(Vector3(52,.7,13));await photo("garden-bridge")
	city.hud.hide();city.camera.position=Vector3(140,65,80);city.camera.look_at(Vector3(110,0,10));await photo("island-four-parcels")
	city.hud.show();move_to(Vector3(79,.1,9.1));await frames()
	check(not editor.open_nearby_parcel().ok,"Unpurchased nearby parcel cannot open build mode")
	check(city.hud.root_ui.find_child("BuyLand",true,false)==null and city.hud.build_button.disabled,"Bottom menu has no purchase button and unowned land cannot be built")
	city.update_target();check(city.current_target=="land:east_nw" and city.hud.prompt.text.contains("E"),"Approaching the actual unowned board offers E interaction")
	await press_interact()
	await frames();check(city.hud.mode=="land" and city.hud.overlay.visible,"E at the board opens its purchase confirmation")
	check(city.hud.content.find_children("Purchase_*","Button",true,false).size()==1 and city.hud.content.find_child("Purchase_east_nw",true,false)!=null,"Confirmation contains only the exact interacted parcel")
	await photo("purchase-parcel-panel")
	var before: int=session.state().coins
	await click(city.hud.content.find_child("CancelLandPurchase",true,false));await frames()
	check(session.state().coins==before and not Land.owns(session.state(),"east_nw") and not city.hud.overlay.visible,"Cancelling the single-parcel offer spends nothing and returns to walking")
	city.update_target();await press_interact();await frames()
	var button: Button=city.hud.content.find_child("Purchase_east_nw",true,false);await click(button);await frames()
	check(Land.owns(session.state(),"east_nw") and session.state().coins==before-100,"Actual purchase card deducts 100 coins and records the owner")
	check(not city.hud.overlay.visible and not city.hud.build_button.disabled,"Purchase returns to walking with construction now available")
	await click(city.hud.build_button);await frames()
	check(editor.active and editor.parcel_id=="east_nw" and editor.grid.mesh.size==Vector2(24,20),"Build button opens only the nearby owned 24 by 20 parcel")
	var data:=L.add(editor.layout,{"type":"floor","a":[80.,-10.],"b":[94.,3.]})
	check(editor.commit(data),"Owned northern parcel saves in-bounds floor construction")
	var snapshot:=JSON.stringify(editor.layout)
	check(not editor.commit(L.add(editor.layout,{"type":"floor","a":[99.,-10.],"b":[105.,3.]})) and JSON.stringify(editor.layout)==snapshot,"Commit rejects public-land spill with no partial changes")
	check(editor.row_at(Vector2(122,-4)).is_empty() and not editor.place_at(Vector2(122,-4)),"Placement tools cannot target another parcel")
	editor.pan_camera(Vector2(500,500));check(Land.includes(Land.bounds(editor.parcel_id),Vector2(editor.focus.x,editor.focus.z)),"Editor camera focus stays inside the active parcel")
	editor.undo();check(editor.layout.elements.is_empty(),"Undo affects current parcel construction")
	editor.redo();check(not editor.layout.elements.is_empty(),"Redo restores current parcel construction")
	await photo("editing-one-parcel");editor.close_editor();city.set_process(false);session.active=false
	move_to(Vector3(121,.1,7));var bought: Dictionary=session.buy_land("east_ne");check(bought.ok,"A second independent parcel can be purchased")
	check(editor.open_nearby_parcel().ok and editor.parcel_id=="east_ne" and editor.undo_stack.is_empty(),"Entering a second parcel resets editing context and undo history")
	var first_region: Array=Land.outside(editor.layout,"east_ne").duplicate(true)
	check(editor.commit(L.add(editor.layout,{"type":"floor","a":[122.,-10.],"b":[138.,3.]})),"Second parcel saves its own floor")
	check(Land.outside(editor.layout,"east_ne")==first_region,"Editing second parcel preserves first parcel exactly")
	editor.clear_plot();check(Land.outside(editor.layout,"east_ne")==first_region and editor.layout.elements.size()==first_region.size(),"Clear plot removes only the active parcel's buildings")
	editor.place_template("two_storey")
	check(editor.place_at(Land.bounds("east_ne").get_center()),"Actual catalog places the updated two-storey house on the active parcel")
	check(editor.layout.elements.size()==first_region.size()+98 and Land.outside(editor.layout,"east_ne")==first_region,"Template preserves all 98 house records without altering the first parcel")
	editor.ui.hide();editor.grid.hide();city.camera.position=Vector3(150,22,23);city.camera.look_at(Vector3(131,3,-4));await photo("updated-two-storey-on-parcel")
	editor.clear_plot()
	editor.close_editor();city.set_process(false);session.active=false
	# Ownership, coins and layout use a single full-save transaction and read back.
	var folder:=output.get_base_dir()+"/isolated-save";DirAccess.make_dir_recursive_absolute(folder);session.save_path=folder+"/world.json";session.test_mode=false
	check(session.save_game(),"Parcel state writes a complete isolated save")
	var recovered=load("res://scripts/services/session.gd").new();recovered.name="RecoveredLandSession";root.add_child(recovered);recovered.save_path=session.save_path;recovered.load_save()
	check(recovered.state().land_parcels==session.state().land_parcels and recovered.state().coins==session.state().coins and recovered.state().build_layout==session.state().build_layout,"Full reload preserves ownership, wallet and each parcel's buildings")
	# Failed purchase and edit must roll back ownership, wallet and parcel revisions.
	move_to(Vector3(79,.1,13));session.save_path=folder+"/missing/blocked/world.json";var old: Dictionary=session.snapshot()
	check(not session.buy_land("east_sw").ok and session.snapshot()==old,"Failed purchase save rolls back both coins and ownership")
	# Existing owned parcel edit failure is tested at the first parcel.
	move_to(Vector3(79,.1,7));old=session.snapshot();var change:=L.add(session.state().build_layout,{"type":"floor","a":[80.,-13.],"b":[94.,-11.]})
	check(not session.set_parcel_layout("east_nw",change).ok and session.snapshot()==old,"Failed building save restores the full world and parcel revision")
	session.test_mode=true;recovered.free();city.free();session.free();await process_frame
	call_deferred("finish")
func finish() -> void:
	print("LAND_PARCELS_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
