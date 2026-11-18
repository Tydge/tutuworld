extends SceneTree
const Server=preload("res://server/world_server.gd")
const L=preload("res://scripts/icefield/icefield_layout.gd")
const DB=preload("res://scripts/services/game_data.gd")
var server: Node
var ids: Array=[]
var serial:=0
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func request(index: int,verb: String,args: Dictionary,token: String="") -> Dictionary:
	serial+=1;return server.execute_player(index+1,{"id":token if token!="" else "icefield-rule-%d"%serial},verb,args)
func place(index: int,p: Vector3) -> void:
	var pawn: CharacterBody3D=server.pawns[ids[index]];pawn.position=p;pawn.velocity=Vector3.ZERO;pawn.reset_network_motion();pawn.reset_physics_interpolation();server.actors[ids[index]].state.player_position=[p.x,p.y,p.z]
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18947");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/icefield-authority-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	while not server.ready_for_players or not server.maps.icefield.navigation.ready_for_paths:await process_frame
	server.set_process(false) # Fixture sockets are in-memory, not connected peers.
	check(server.maps.size()==3 and server.maps.icefield.npcs.size()==9,"Authority loads three independent collision worlds and new residents")
	for i in range(3):
		var account:="frost-account-"+str(i);var created: Dictionary=server.create_character(account,{"name":"冰原联机"+str(i),"species":["bunny","cat_teacher","panda"][i],"starter":"bow_rose"});ids.append(created.character)
		server.peers[i+1]={"account":account,"character":"","socket":WebSocketPeer.new()}
		check(server.join_world(i+1,created.character).ok,"Authority joins species "+str(i))
		place(i,Vector3(13,.2,41.5));var before: int=server.actors[ids[i]].state.coins
		check(request(i,"travel",{"destination":"icefield"},"ice-out-"+str(i)).ok,"Authoritative ferry enters icefield "+str(i))
		check(server.pawns[ids[i]].world==server.maps.icefield and server.actors[ids[i]].state.coins==before-10,"World, position and fare change together "+str(i))
		check(request(i,"travel",{"destination":"icefield"},"ice-out-"+str(i)).ok and server.actors[ids[i]].state.coins==before-10,"Repeated travel token cannot double debit "+str(i))
	for i in range(3):
		for j in range(i):check(server.pawns[ids[i]].position.distance_to(server.pawns[ids[j]].position)>1.65,"Shared harbor finds separated arrival places")
	var actor=server.actors[ids[0]];var pawn: CharacterBody3D=server.pawns[ids[0]]
	check(not request(0,"travel",{"destination":"valley"}).ok,"Authority rejects an unlisted inter-island route")
	place(0,Vector3(50,.84,25));pawn.network_sequenced=false;pawn.network_direction=Vector3.ZERO
	for frame in range(12):await physics_frame
	pawn.network_direction=Vector3.RIGHT
	await create_timer(.5).timeout;check(pawn.velocity.x>.3 and pawn.velocity.x<1.6,"Authority uses same slow ice acceleration")
	pawn.network_direction=Vector3.ZERO;var released:=pawn.position;await create_timer(.6).timeout
	check(pawn.position.distance_to(released)>.25,"Authority preserves glide after release")
	pawn.network_sequenced=true;pawn.network_direction=Vector3.ZERO
	for index in range(3):
		var runner: CharacterBody3D=server.pawns[ids[index]];var rules: RefCounted=server.actors[ids[index]]
		place(index,Vector3(48+index*12,.84,40));runner.network_sequenced=false;runner.network_direction=Vector3.ZERO
		for frame in range(12):await physics_frame
		runner.network_direction=Vector3.RIGHT;runner.run_enabled=false
		await create_timer(1.7).timeout
		check(absf(runner.velocity.x-3.5)<.08,"Actual authority walk speed is +25 percent for species "+str(index))
		runner.run_enabled=true;runner.stamina_fraction=0.
		await create_timer(1.2).timeout
		check(absf(runner.velocity.x-5.95)<.08 and runner.run_enabled,"Actual authority sprint is +25 percent even at zero stamina for species "+str(index))
		rules.state.stamina=13;rules.state.stamina_recovery_elapsed=0.;rules.state.stamina_run_elapsed=2.9;rules.running=true;rules.tick_stamina(20.)
		check(rules.state.stamina==13 and rules.state.stamina_run_elapsed==0.,"Authority sprint has no cost or legacy debt for species "+str(index))
		runner.network_direction=Vector3.ZERO;runner.network_sequenced=true;runner.run_enabled=false
	for r in DB.resources("icefield"):
		var found: Dictionary=server.safe_position("icefield",Vector3(r.x,r.y+.035,r.z),ids[0],pawn)
		check(not found.is_empty() and found.position.distance_to(Vector3(r.x,r.y,r.z))<2.8,"Physical approach to resource "+r.id)
	var target: Dictionary=DB.resources("icefield")[0];place(0,Vector3(target.x,target.y+.035,target.z))
	check(request(0,"gather",{"target":target.id}).ok,"Authority starts icefield gathering")
	if not actor.job.is_empty():actor.job.duration=.02
	await create_timer(.1).timeout;server.tick_actor(ids[0],.2)
	check(actor.count("branch")>0 and not server.state().resources[target.id].available,"Authority grants and saves shared icefield resource")
	server.broadcast_motion();check(server.actor_packet(ids[0]).map=="icefield","New map participates in motion packets")
	place(0,Vector3(L.DOCK.x,L.DOCK_HEIGHT+.035,L.DOCK.y));var coins: int=actor.state.coins
	check(request(0,"travel",{"destination":"city"}).ok and actor.state.coins==coins,"Authority returns for free")
	place(0,Vector3(13,.2,41.5));var original: String=server.save_path;server.save_path=original.path_join("invalid")
	check(not request(0,"travel",{"destination":"icefield"}).ok and actor.state.map_id=="city" and actor.state.coins==coins and pawn.get_parent()==server.maps.city,"Failed durable save rolls back world transfer and fare")
	server.save_path=original;check(server.save_world(),"Isolated server snapshot saves")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original));check(saved.characters[ids[1]].map_id=="icefield" and saved.characters[ids[2]].species=="panda","Offline records retain new map and species")
	server.listener.stop();server.queue_free();await process_frame
	print("ICEFIELD_SERVER_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
