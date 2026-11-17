extends SceneTree
const Server=preload("res://server/world_server.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
const L=preload("res://scripts/building/layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
var checks:=0
var failures: Array=[]
var server: Node
var session: Node
var city: Node3D
var client: Node
var other_id: String
var snapshot: Dictionary={}
var notices: Array=[]
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count_: int=3) -> void:
	for i in range(count_):await process_frame;RenderingServer.force_draw()
func place(id: String,p: Vector3) -> void:
	var pawn=server.pawns[id];pawn.position=p;pawn.velocity=Vector3.ZERO;pawn.reset_network_motion();server.actors[id].state.player_position=[p.x,p.y,p.z]
	if id==session.active_character_id and is_instance_valid(city):city.bunny.position=p;city.bunny.reset_physics_interpolation()
func run() -> void:
	Engine.max_fps=60;output=preload("res://tests/test_support.gd").output_dir()
	OS.set_environment("TUTU_GAME_PORT","18920");OS.set_environment("TUTU_AUTH_PORT","18919");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/building-flow-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	while not server.ready_for_players:await process_frame
	for host in server.maps.values():
		for npc in host.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	var suffix:=Crypto.new().generate_random_bytes(4).hex_encode()
	var result: Dictionary=await session.login_online("register",{"username":"build_ui_"+suffix,"password":"test-construction-flow"},"ws://127.0.0.1:18920")
	check(result.get("ok",false),"Real owner connection registers an isolated account")
	if not result.get("ok",false):print(result);quit(1);return
	result=await session.create_online_character("施工兔"+suffix.left(3),"bunny","bow_rose");check(result.get("ok",false),"Owner joins through the real Session transport")
	client=Transport.new();root.add_child(client)
	client.snapshot_received.connect(func(data):
		var previous: Dictionary=snapshot.get("state",{}).get("build_layout",L.empty());snapshot=data.duplicate(true)
		if not snapshot.state.has("build_layout"):snapshot.state.build_layout=previous)
	client.message_received.connect(func(data):
		if data.get("type","")=="event":notices.append(data.event))
	check(await client.ensure_connected("ws://127.0.0.1:18920"),"Second real client connects")
	result=await client.request("register",{"username":"build_peer_"+suffix,"password":"test-construction-flow"});check(result.get("ok",false),"Visitor registers an isolated account")
	result=await client.request("create_character",{"name":"施工猫"+suffix.left(3),"species":"cat_teacher","starter":"bow_rose"})
	if not result.get("ok",false):print(result);quit(1);return
	other_id=result.character;result=await client.request("join",{"character":other_id});check(result.get("ok",false),"Visitor joins the shared world")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null or city.build_mode==null:await process_frame
	await create_timer(.5).timeout;city.bunny.set_physics_process(false)
	var editor: Node=city.build_mode
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await frames(1)
	place(session.active_character_id,Land.sign_position("east_nw")+Vector3(0,.1,1.6));place(other_id,Vector3(90,.1,-3))
	result=await session.request_online("buy_land",{"parcel_id":"east_nw"});check(result.get("ok",false),"Real online purchase updates owner state and HUD")
	await frames();check(city.hud.build_button!=null and editor.layout.elements.is_empty(),"Multiplayer city exposes the existing building controls")
	result=await editor.open_nearby_parcel();check(result.get("ok",false) and editor.active,"Online building entry acquires the construction lease")
	await frames();check(notices.any(func(row):return str(row.get("message","")).contains("送到地皮外")),"Evacuated visitor receives the actual network notice")
	check(not city.can_walk(Vector3(90,.1,-3)) and snapshot.state.building_sites.has("east_nw"),"Client prediction and visitor snapshot both see the closed parcel")
	var sample:=preload("res://scripts/building/templates.gd").player_sample("two_storey")
	var draft:=L.merge_template(editor.layout,sample,Land.bounds("east_nw").get_center())
	check(editor.commit(draft),"The 99-record two-storey house can be edited locally")
	await frames();check(server.state().build_layout.elements.is_empty() and snapshot.state.build_layout.elements.is_empty(),"Unfinished construction stays invisible to the server and visitor")
	check(editor.undo_stack.size()==1,"Draft retains ordinary undo history")
	editor.undo();check(editor.layout.elements.is_empty(),"Undo changes the private draft only")
	editor.redo();check(editor.layout.elements.size()==99,"Redo restores the private draft")
	var city_identity:=city.get_instance_id();var player_identity: int=city.bunny.get_instance_id();var scenery_identity: int=city.scenery.get_instance_id()
	editor.ui.root_ui.find_child("FinishBuilding",true,false).pressed.emit()
	var deadline:=Time.get_ticks_msec()+100000
	while editor.active and Time.get_ticks_msec()<deadline:
		await frames(1)
		if editor.active and not editor.online_pending:print("COMPLETION_STATUS ",editor.ui.status.text);quit(1);return
	check(not editor.active and not editor.online_pending,"Completion button waits for confirmation, then resumes walking")
	if editor.active:print("COMPLETION_TIMEOUT ",editor.ui.status.text);quit(1);return
	check(server.state().build_layout.elements.size()==99 and snapshot.state.build_layout.elements.size()==99,"Only confirmed completion updates both clients and persisted world")
	check(city.get_instance_id()==city_identity and city.bunny.get_instance_id()==player_identity and city.scenery.get_instance_id()==scenery_identity,"Publication keeps the same scene, map and player nodes")
	check(not city.has_node("ConstructionSites/east_nw") and not snapshot.state.building_sites.has("east_nw"),"Finished parcel reopens for visitors")
	await create_timer(.7).timeout
	await check_new_doors(editor)
	city.set_process(false);city.update_lighting(.5);city.camera.position=Vector3(118,23,25);city.camera.look_at(Vector3(89,4,-4));await frames(4);root.get_texture().get_image().save_png(output+"/completed-online-house.png");city.set_process(true)
	var identities: Dictionary={}
	for id in editor.room.render_cache:identities[id]=editor.room.render_cache[id].node.get_instance_id()
	place(other_id,Land.sign_position("east_ne")+Vector3(0,.1,1.6));result=await client.request("buy_land",{"parcel_id":"east_ne"});check(result.get("ok",false),"Second owner buys a separate parcel")
	result=await client.request("build_begin",{"parcel_id":"east_ne"});check(result.get("ok",false),"Second owner starts independent construction")
	var lease: String=result.get("lease","");var other:=L.merge_template(L.empty(),sample,Land.bounds("east_ne").get_center())
	result=await client.request("build_finish",{"parcel_id":"east_ne","lease":lease,"expected_revision":0,"elements":other.elements});check(result.get("ok",false),"Second owner confirms another full two-storey house")
	if not result.get("ok",false):print(result);quit(1);return
	deadline=Time.get_ticks_msec()+100000
	while (editor.online_updating or editor.layout.elements.size()!=198) and Time.get_ticks_msec()<deadline:await frames(1)
	check(editor.layout.elements.size()==198,"Spectator receives the second house without changing scenes")
	var reused:=true
	for id in identities:
		if not editor.room.render_cache.has(id) or editor.room.render_cache[id].node.get_instance_id()!=identities[id]:reused=false
	check(reused,"Every unchanged first-house module retains its node identity")
	check(editor.room.last_sync.get("yields",0)>4 and editor.room.last_sync.get("created",0)>0,"Changed geometry is prepared across multiple frames")
	check(editor.room.last_sync.get("max_slice_usec",1000000)<33333,"Two-house update keeps every measured script slice below 33.3 ms")
	check(editor.room.last_sync.get("phases",{}).get("swap",1000000)<16667,"Final model and collision swap stays within a 16.7 ms script budget")
	print("BUILDING_UPDATE_METRICS ",JSON.stringify(editor.room.last_sync))
	city.set_process(false);city.update_lighting(.5);city.camera.position=Vector3(143,36,38);city.camera.look_at(Vector3(110,3,-3));await frames(4);root.get_texture().get_image().save_png(output+"/two-online-houses.png");city.set_process(true)
	var doors_ok:=true
	for door in editor.room.get_node("Doors").get_children():
		if door.has_method("toggle_door"):
			if door.get_node("Hinge/LeafCollision").collision_layer!=4:doors_ok=false
			for child in door.find_children("*","Node",true,false):
				if child.has_meta("build_element_id") and child.get_meta("build_element_id")!=str(door.name):doors_ok=false
	check(doors_ok,"Cached doors retain real collision and their own selection IDs")
	var second_rows: Array=server.state().build_layout.elements.filter(func(row):return Land.contains_row("east_ne",row,server.state().build_layout)).duplicate(true)
	var changed: Dictionary={}
	for row in second_rows:
		if row.get("kind","")=="sofa":row.color="cc8866";row.painted=true;changed=row;break
	var replaced: int=editor.room.render_cache[changed.id].node.get_instance_id()
	result=await client.request("build_begin",{"parcel_id":"east_ne"});check(result.get("ok",false),"Second owner reopens a completed parcel")
	result=await client.request("build_finish",{"parcel_id":"east_ne","lease":result.get("lease",""),"expected_revision":1,"elements":second_rows});check(result.get("ok",false),"An existing building accepts a second completed edit")
	deadline=Time.get_ticks_msec()+60000
	while (editor.online_updating or editor.room.render_cache[changed.id].node.get_instance_id()==replaced) and Time.get_ticks_msec()<deadline:await frames(1)
	check(editor.room.render_cache[changed.id].node.get_instance_id()!=replaced and editor.room.last_sync.get("removed",0)==1 and editor.room.last_sync.get("created",0)==1,"A one-object change replaces only that object and retires its old geometry")
	check(identities.keys().all(func(id):return editor.room.render_cache[id].node.get_instance_id()==identities[id]),"Publishing a later edit still preserves the other owner's complete house")
	place(session.active_character_id,Land.sign_position("east_nw")+Vector3(0,.1,1.7));await frames()
	result=await editor.open_nearby_parcel();check(result.get("ok",false),"Owner can reopen a completed house for another editing session")
	# Change the other parcel while this owner's private draft remains open.
	result=await client.request("build_begin",{"parcel_id":"east_ne"});check(result.get("ok",false),"Other owner can edit concurrently with this private draft")
	for row in second_rows:
		if row.get("kind","")=="sofa":row.color="bb7755"
	result=await client.request("build_finish",{"parcel_id":"east_ne","lease":result.get("lease",""),"expected_revision":2,"elements":second_rows});check(result.get("ok",false),"Concurrent publication updates the other parcel")
	await frames(4)
	editor.choose_tool("object:forest_planter");editor.update_ghost(Vector2(77.,-13.))
	check(editor.ghost_material.albedo_color.r>.8 and not editor.place_at(Vector2(77.,-13.)),"Preview and placement both reject an object crossing the parcel boundary")
	editor.update_ghost(Vector2(78.,-13.))
	check(editor.ghost_material.albedo_color.g>.6,"Legal new object preview stays green after another parcel publishes")
	check(editor.place_at(Vector2(78.,-13.)),"The green preview and the actual private placement agree")
	editor.undo()
	var own_rows: Array=editor.editing_layout().elements;check(editor.commit(L.remove(editor.layout,own_rows[-1].id)),"Owner can revise their private draft before discarding")
	await editor.discard_online();check(not editor.active and server.state().build_layout.elements.size()==198,"Explicit discard reopens the parcel and keeps the published buildings")
	result=await editor.open_nearby_parcel();check(result.get("ok",false),"Owner starts the 0.4 facade and finish transaction")
	var edit=preload("res://scripts/building/room_edit.gd");var grid=preload("res://scripts/building/grid_layout.gd")
	var own: Dictionary=editor.editing_layout();var ground: Dictionary=L.compiled(own,0);var facade: Variant=null
	for edge in ground.walls:
		if edge.z==1 and (facade==null or edge.x<facade.x):facade=edge
	var ends: Array=grid.ends(facade);var point: Vector2=(grid.point(ends[0])+grid.point(ends[1]))*.5
	var wall:=L.unit_at(editor.layout,ground.walls[facade].id,point);var ctx: Dictionary=edit.wall_context(edit.prepare(editor.layout,0),wall,point+Vector2.RIGHT*2.)
	var planned: Dictionary=edit.resize(ctx,-2);check(planned.ok,"A furnished online two-storey facade expands atomically")
	var published_before:=JSON.stringify(server.state().build_layout)
	if planned.ok:
		check(editor.commit(edit.materialize(ctx.base,planned)),"Online draft accepts the linked floors, roof, openings and mirrors")
		point.x-=1.;var painted_wall: Dictionary={}
		for edge in L.compiled(editor.layout).walls:
			if edge.z==1 and edge.x==facade.x-2 and edge.y==facade.y:painted_wall=L.compiled(editor.layout).walls[edge];break
		editor.selected_id=painted_wall.id;editor.selected_unit=L.unit_at(editor.layout,painted_wall.id,point);editor.refresh_ui();editor.ui.wall_face.select(1);editor.ui.batch_paint.button_pressed=true
		editor.paint_selected(Color("9a8067"),"brick")
		check(JSON.stringify(server.state().build_layout)==published_before,"Facade expansion and exterior painting remain private before completion")
		await editor.close_editor()
		check(not editor.active and city.get_instance_id()==city_identity,"Finishing 0.4 facade changes keeps the running city")
		check(L.compiled(server.state().build_layout,0).floors.has(Vector2i(facade.x-1,facade.y)) and L.compiled(server.state().build_layout,1).floors.has(Vector2i(facade.x-1,facade.y)),"Both published storeys contain the expansion strip")
		var wire_layout: Dictionary=JSON.parse_string(JSON.stringify(server.state().build_layout))
		deadline=Time.get_ticks_msec()+5000
		while snapshot.state.build_layout!=wire_layout and Time.get_ticks_msec()<deadline:await frames(1)
		var final_check:=L.validate(server.state().build_layout)
		check(final_check.ok,"Published facade still passes full structural validation: "+final_check.get("message",""))
		for side in ["server","visitor"]:
			var file:=FileAccess.open(output+"/facade-"+side+".json",FileAccess.WRITE);file.store_string(JSON.stringify(server.state().build_layout if side=="server" else snapshot.state.build_layout));file.close()
		print("FACADE_SNAPSHOT_REVISIONS ",snapshot.state.get("building_revision",-1)," ",server.state().get("building_revision",-1))
		check(snapshot.state.build_layout==wire_layout,"Visitor receives the complete validated facade update")
		check(JSON.stringify(server.state().build_layout.elements.filter(func(row):return Land.contains_row("east_ne",row,server.state().build_layout)))==JSON.stringify(second_rows),"Facade transaction preserves the other owner's published rows")
	client.close();client.queue_free();await session.leave_online();city.queue_free();await process_frame;server.listener.stop();server.queue_free();await process_frame
	print("BUILDING_MULTIPLAYER_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)

func check_new_doors(editor: Node) -> void:
	var matching:=true;var first: Node3D
	for row in editor.layout.elements:
		if row.type!="door":continue
		var key: String="city:build:"+str(row.id)
		var local: Node3D=editor.room.render_cache[row.id].node
		var authority: Node3D=server.maps.city.targets["build:"+str(row.id)].node
		var expected: bool=row.get("default_open",true)
		if server.doors.get(key,{}).get("open")!=expected or local.door_open!=expected or authority.door_open!=expected or local.portal.disabled!=expected or authority.portal.disabled!=expected:matching=false
		if first==null and expected and int(row.get("storey",0))==0:first=local
	check(matching,"Fresh open and closed doors agree in snapshots, client visuals and authority collision")
	if first==null:check(false,"Template has a ground-floor door for real movement");return
	var id: String=str(first.name);var pawn: CharacterBody3D=server.pawns[other_id]
	pawn.set_physics_process(false)
	for pair in [[server.maps.city.targets["build:"+id].node,pawn],[first,city.bunny]]:
		var door: Node3D=pair[0];var actor: CharacterBody3D=pair[1];var normal: Vector3=door.global_basis.z.normalized()
		var start: Vector3=door.global_position+normal*1.4+Vector3.UP*.02
		actor.position=start;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation();await physics_frame
		for i in range(60):actor.simulate_movement(1./60.,-normal,false,false,true)
		check((actor.position-start).dot(normal)<-2.2,"Real actor enters a freshly built open door without toggling: "+("server visitor" if actor==pawn else "local owner"))
	pawn.set_physics_process(true)
	place(session.active_character_id,Land.sign_position("east_nw")+Vector3(0,.1,1.6));place(other_id,Land.sign_position("east_ne")+Vector3(0,.1,1.6))
