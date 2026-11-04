extends SceneTree
const Access=preload("res://scripts/city/conversation_access.gd")
const G=preload("res://scripts/geometry.gd")
var checks:=0
var failures: Array=[]
var serial:=0
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func place(city: Node3D,p: Vector3) -> void:
	city.bunny.stand_up(p);city.bunny.velocity=Vector3.ZERO;city.bunny.reset_physics_interpolation();city.session.set_player_position(p);await physics_frame;await physics_frame;city.update_target()
func request(server: Node,verb: String,args: Dictionary) -> Dictionary:
	serial+=1;return server.execute_player(77,{"id":"wall-"+str(serial)},verb,args)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("店门前的小兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.3).timeout;city.set_process(false);city.bunny.set_physics_process(false);session.active=false
	for npc in city.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED
	for shop in ["farm","tools","clothes"]:
		var id: String="Merchant_"+shop;var building: Node3D=city.scenery.get_node("Shop_"+shop);var item: String={"farm":"seed_carrot","tools":"watering_can_copper","clothes":"beret_sage"}[shop]
		await place(city,building.to_global(Vector3(0,.2,-4.3)));check(city.current_target!=id,"The merchant has no E prompt through the back wall: "+shop);city.current_target=id;city.interact();check(city.talking_npc=="" and not city.hud.overlay.visible,"A stale selection cannot open conversation/shop through the wall: "+shop)
		var before: Dictionary=session.snapshot();check(not session.dispatch("buy",{"shop":shop,"item":item}).ok and session.state().coins==before.coins and session.state().inventory==before.inventory,"Offline authority denies buying through a wall without changing assets: "+shop)
		if shop=="farm":session.authority.add("carrot",1);check(not session.dispatch("sell",{"shop":shop,"item":"carrot"}).ok,"Selling is denied outside the shop as well")
		await place(city,building.to_global(Vector3(0,.2,0)));check(city.current_target==id,"The actual counter approach keeps its merchant prompt: "+shop);city.interact();check(city.talking_npc==id,"Normal face-to-face merchant dialogue still works: "+shop);city.interact();check(city.hud.overlay.visible and city.hud.mode=="shop","The second E interaction opens the correct shop: "+shop);city.hud.close_panel()
		if shop=="farm":check(session.dispatch("buy",{"shop":shop,"item":"seed_carrot"}).ok,"Buying at the real counter succeeds")
	var npc: CharacterBody3D=city.targets.Passerby0.node;npc.position=Vector3(80,.2,18);var wall:=G.solid_box(city,Vector3(79,2,18),Vector3(.24,4,4));wall.collision_layer=4;await place(city,Vector3(78,.2,18));check(city.current_target!="Passerby0","Ordinary NPCs also suppress their prompt through a wall");city.current_target="Passerby0";city.interact();check(city.talking_npc=="","Direct ordinary-NPC interaction is blocked through a wall");wall.free();await physics_frame;city.update_target();check(city.current_target=="Passerby0","Clearing the wall restores the ordinary NPC prompt");city.interact();check(city.talking_npc=="Passerby0","Unobstructed ordinary NPC dialogue works");city.end_dialogue();city.queue_free();await process_frame;session.queue_free();await process_frame
	# The server independently checks forged/stale talk and trade requests.
	OS.set_environment("TUTU_GAME_PORT","18916");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/wall-authority-"+str(Time.get_ticks_usec())))
	var server=load("res://server/world_server.gd").new();root.add_child(server)
	while not server.ready_for_players:await physics_frame
	server.set_process(false);var host: Node3D=server.maps.city
	for map_ in server.maps.values():
		for other in map_.npcs:other.process_mode=Node.PROCESS_MODE_DISABLED;other.collision_layer=0;other.set_meta("interaction_available",true)
	var authority=load("res://scripts/services/local_authority.gd").new();authority.state.player_id="walls";server.actors.walls=authority;server.peers[77]={"character":"walls"};var pawn=preload("res://scripts/characters/animal_factory.gd").create();host.add_child(pawn);pawn.set_physics_process(false);pawn.world=host;server.pawns.walls=pawn
	var shop: Node3D=host.scenery.get_node("Shop_farm");pawn.position=shop.to_global(Vector3(0,.2,-4.3));await physics_frame;await physics_frame;var coins: int=authority.state.coins
	check(not request(server,"buy",{"shop":"farm","item":"seed_carrot"}).ok and authority.state.coins==coins,"Server denies an outside-wall buy request independently")
	pawn.position=shop.to_global(Vector3(0,.2,0));await physics_frame;await physics_frame;check(request(server,"buy",{"shop":"farm","item":"seed_carrot"}).ok,"Server accepts a valid counter transaction")
	var target: Dictionary=host.targets.Passerby0;target.node.position=Vector3(30,.2,20);target.position=target.node.position;pawn.position=Vector3(28,.2,20);wall=G.solid_box(host,Vector3(29,2,20),Vector3(.24,4,4));wall.collision_layer=4;await physics_frame;await physics_frame;check(not request(server,"talk",{"target":"Passerby0"}).ok,"Server denies NPC conversation through a wall");wall.free();await physics_frame;check(request(server,"talk",{"target":"Passerby0"}).ok,"Server accepts unobstructed NPC conversation")
	request(server,"end_talk",{});server.peers.clear();server.listener.stop();server.queue_free();await process_frame
	print("CONVERSATION_WALLS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
