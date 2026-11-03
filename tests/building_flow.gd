extends SceneTree
const Site=preload("res://scripts/building/site.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func photo(name_: String) -> void:
	for i in range(12):
		await process_frame
		RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out+"/"+name_+".png")
func walk(actor: CharacterBody3D,from: Vector3,to: Vector3) -> bool:
	actor.position=from;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	for i in range(220):
		await physics_frame
		var direction:=to-actor.position;direction.y=0
		if direction.length()<.20:return true
		actor.velocity=direction.normalized()*2.8+Vector3(0,-.6,0);actor.move_on_ground(1./60)
	return false
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建造验收兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout
	check(city.scenery.has_node("EastBuildingSite") and city.can_walk(Vector3(80,0,10)),"Expanded east plot is present and walkable")
	check(city.scenery.get_node("Workshop").door_open,"Workshop starts with its real door open")
	var open: Button=city.hud.root_ui.find_child("OpenBuildingEditor",true,false)
	check(open!=null,"Single-player HUD exposes the building mode")
	open.pressed.emit();await process_frame
	var editor=city.build_mode
	check(editor.active and not city.bunny.can_move and city.paused and not session.active,"Build mode pauses gameplay and controls its own camera")
	var resident_position: Vector3=city.npcs[0].position;await create_timer(.2).timeout
	check(city.npcs[0].position.distance_to(resident_position)<.001,"Residents also pause while the construction camera is active")
	var sample: Button=editor.ui.root_ui.find_child("PlaceSampleRoom",true,false);sample.pressed.emit();editor.place_at(Vector2(79,10));await physics_frame
	check(editor.layout.elements.size()==42 and is_instance_valid(editor.room),"In-game sample command builds editable structure and independently editable furnishings")
	await photo("editor-room")
	check(editor.room.get_node("Doors/build_6").door_open,"Player-built doorway starts open with a real independent door leaf")
	editor.selected_id="build_10";editor.refresh_ui();editor.paint_selected(Color("86a9b2"),"wood")
	check(Layout.find(editor.layout,"build_10").appearance.frame.color=="86a9b2","Inspector part color and material changes are persisted")
	editor.selected_id="build_14";editor.delete_selected();check(editor.layout.elements.size()==23,"Delete removes the selected module")
	editor.undo();check(editor.layout.elements.size()==42,"Undo restores the deleted module")
	editor.redo();check(editor.layout.elements.size()==23,"Redo removes it again")
	editor.undo()
	var before_collision: Vector3=editor.room.get_node("Furnishing/build_14").find_children("*","StaticBody3D",true,false)[0].global_position
	editor.selected_id="build_14";editor.begin_move();check(editor.place_at(Vector2(83.5,12.5)),"Moving a bookshelf commits its new position")
	var after_collision: Vector3=editor.room.get_node("Furnishing/build_14").find_children("*","StaticBody3D",true,false)[0].global_position
	check((after_collision-before_collision).distance_to(Vector3(-.5,0,0))<.001,"Furniture collision actually follows the edited module")
	editor.close_editor();await create_timer(.3).timeout
	check(not editor.active and city.bunny.can_move and not city.paused and session.active,"Finishing restores normal player controls at the current location")
	var door: Node3D=editor.room.get_node("Doors/build_6")
	var door_visual: MeshInstance3D=door.hinge.find_children("*","MeshInstance3D",true,false)[0] if not door.hinge.find_children("*","MeshInstance3D",true,false).is_empty() else null
	check(is_instance_valid(door_visual),"Constructed door keeps its rendered leaf beneath the moving hinge")
	var open_basis: Basis=door_visual.global_basis if is_instance_valid(door_visual) else Basis.IDENTITY
	check(door.toggle_door(city.bunny).ok,"Constructed door supports normal closing interaction")
	await create_timer(.8).timeout
	check(not door.door_open and not door.portal.disabled,"Closing the constructed door restores its real portal collision")
	check(is_instance_valid(door_visual) and door_visual.global_basis.x.distance_to(open_basis.x)>1.,"Rendered door leaf actually rotates together with its physical collider")
	check(door.toggle_door(city.bunny).ok,"Constructed door can reopen")
	await create_timer(.8).timeout
	city.set_process(false);city.bunny.can_move=false;session.active=false
	city.bunny.position=Vector3(60,.2,20);city.bunny.reset_physics_interpolation()
	for npc in city.npcs:npc.collision_layer=0;npc.set_physics_process(false)
	for species in Animals.Catalog.ids():
		var actor=Animals.create(species);city.add_child(actor);actor.world=city;actor.set_physics_process(false)
		check(await walk(actor,Vector3(51,.2,13),Vector3(60,.2,13)),"Physical causeway connects the original island to the east plot: "+species)
		check(await walk(actor,Vector3(79,.25,19),Vector3(79,.25,12)),"Actual actor enters constructed doorway without jumping: "+species)
		actor.queue_free();await process_frame
	city.hud.hide();city.bunny.position=Vector3(79,.2,12);city.bunny.reset_physics_interpolation();city.camera.position=Vector3(88,11,22);city.camera.look_at(Vector3(79,2,10))
	for i in range(30):editor.room._process(1./30);await process_frame
	await photo("constructed-interior")
	check(editor.room.inside and editor.room.roof_hidden,"Constructed room uses normal interior lighting and real roof cutaway")
	check(not editor.room.contains_position(Vector3(91,.2,10)),"Outdoor plot is not treated as an indoor room")
	print("BUILDING_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
