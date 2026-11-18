extends SceneTree
const Server=preload("res://server/world_server.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
const L=preload("res://scripts/valley/valley_layout.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Travel=preload("res://scripts/valley/boat_travel.gd")
var server: Node
var session: Node
var friend: Node
var game: Node3D
var owner_id: String
var friend_id: String
var friend_motion: Dictionary={}
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func place(id: String,desired: Vector3) -> bool:
	var pawn: CharacterBody3D=server.pawns[id];var map_id: String=server.actors[id].state.map_id
	var landing: Dictionary=server.safe_position(map_id,desired,id,pawn)
	if landing.is_empty():return false
	pawn.stand_up(landing.position);pawn.reset_network_motion();server.actors[id].state.player_position=server.vector_array(pawn.position)
	for peer_id in server.peers:
		if server.peers[peer_id].character==id:server.send_snapshot(peer_id)
	server.broadcast_motion();return true
func wait_scene(map_id: String) -> bool:
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(current_scene) and current_scene.map_id==map_id and not current_scene.preparing and is_instance_valid(current_scene.online_view):
			game=current_scene;return true
		await process_frame
	return false
func floor_at(host: Node3D,p: Vector2) -> Vector3:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,90,p.y),Vector3(p.x,-10,p.y),8)
	var hit: Dictionary=host.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position",Vector3.INF)
func receive_friend(data: Dictionary) -> void:
	if data.get("type","")!="motion":return
	for row in data.get("actors",[]):
		if row.get("npc",false):friend_motion[str(row.id)]=row
func visitors_walk(label_: String) -> void:
	var starts: Dictionary={}
	for id in ["ValleyVisitor0","ValleyVisitor1"]:starts[id]=server.maps.valley.targets[id].node.position
	await create_timer(4.).timeout
	for id in starts:
		var authority: CharacterBody3D=server.maps.valley.targets[id].node
		var replica: CharacterBody3D=game.targets[id].node
		var received: Dictionary=friend_motion.get(id,{})
		var travelled: float=authority.position.distance_to(starts[id])
		check(travelled>1. and replica.position.distance_to(authority.position)<.55,"Rabbit walks on authority and rendered online client ("+label_+"): "+id)
		check(not received.is_empty() and server.vector_from(received.position).distance_to(authority.position)<.3,"Second real client receives the same moving rabbit ("+label_+"): "+id)
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18932");OS.set_environment("TUTU_AUTH_PORT","18919")
	OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/valley-online-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	while not server.ready_for_players:await process_frame
	var suffix:=Crypto.new().generate_random_bytes(5).hex_encode();var initial=Transport.new();root.add_child(initial)
	check(await initial.ensure_connected("ws://127.0.0.1:18932"),"Migration fixture connects through real transport")
	var result: Dictionary=await initial.request("register",{"username":"valley_owner_"+suffix,"password":"valley-release-test"})
	var token: String=result.get("token","")
	check(result.get("ok",false),"Isolated owner account registers")
	result=await initial.request("create_character",{"name":"山谷熊"+suffix.left(4),"species":"panda","starter":"bow_rose"})
	if not result.get("ok",false):print(result);quit(1);return
	owner_id=result.character
	friend=Transport.new();root.add_child(friend);friend.message_received.connect(receive_friend);check(await friend.ensure_connected("ws://127.0.0.1:18932"),"Second real client connects")
	result=await friend.request("register",{"username":"valley_peer_"+suffix,"password":"valley-release-test"})
	check(result.get("ok",false),"Second isolated account registers")
	result=await friend.request("create_character",{"name":"山谷猫"+suffix.left(4),"species":"cat_teacher","starter":"bow_rose"})
	if not result.get("ok",false):print(result);quit(1);return
	friend_id=result.character
	server.records[owner_id].map_id="valley";server.records[owner_id].player_position=[-8.,.1,32.];server.records[owner_id].erase("valley_landscape_revision")
	check(server.save_world(),"Offline legacy online character fixture is durably saved")
	server.load_world()
	var expected:=L.legacy_position(Vector3(-8,.1,32))
	check(server.vector_from(server.records[owner_id].player_position).is_equal_approx(expected),"Real server load migrates the offline valley resident")
	initial.close();initial.queue_free()
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.background_throttle=false;Engine.max_fps=60
	result=await session.login_online("resume",{"token":token},"ws://127.0.0.1:18932");check(result.get("ok",false),"Owner resumes the migrated account")
	result=await session.select_online_character(owner_id);check(result.get("ok",false),"Migrated resident joins the new valley physics world")
	if not result.get("ok",false):print(result);quit(1);return
	result=await friend.request("join",{"character":friend_id});check(result.get("ok",false),"Visitor joins the city")
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);current_scene=game
	check(await wait_scene("valley"),"Real online client loads the valley scene")
	await create_timer(.8).timeout
	check(game.bunny.position.distance_to(expected)<1. and server.pawns[owner_id].position.distance_to(expected)<1.,"Client and authority spawn beside the migrated position")
	check(session.state().valley_landscape_revision==L.REVISION and session.state().species=="panda" and session.state().coins==500,"Online snapshot retains species, currency and migration marker")
	for point in [Vector2(-78,L.ascent_path_z(-78)),Vector2(-15,10),Vector2(0,10),L.DOCK,Vector2(L.HOUSE.x,L.HOUSE.z)]:
		var a:=floor_at(game,point);var b:=floor_at(server.maps.valley,point)
		check(a.is_finite() and b.is_finite() and a.distance_to(b)<.01,"Client/server saved collision surface agrees "+str(point))
	game.yaw=0.;var start: Vector3=game.bunny.position
	Input.action_press("move_up");await create_timer(1.2).timeout;Input.action_release("move_up");await create_timer(.6).timeout
	check(game.bunny.position.distance_to(start)>1. and game.bunny.position.distance_to(server.pawns[owner_id].position)<.4,"Real keyboard walking predicts and converges on the new valley")
	var ground: float=game.bunny.position.y;Input.action_press("jump");await create_timer(.08).timeout;Input.action_release("jump");await create_timer(.18).timeout
	check(game.bunny.position.y>ground+.25,"Networked valley jumping rises above the terrain")
	await create_timer(1.).timeout
	var source: Dictionary=DB.resources("valley").filter(func(row):return row.item=="branch")[0]
	var near:=Vector3(source.x+2.,L.walk_height(source.x+2.,source.z)+.035,source.z)
	check(place(owner_id,near),"Authority finds a real safe landing beside a valley resource")
	await create_timer(.7).timeout
	var before: int=session.authority.count("branch")
	result=await session.request_online("gather",{"target":source.id});check(result.get("ok",false),"Actual network command starts gathering on the new map")
	var deadline:=Time.get_ticks_msec()+8000
	while session.authority.count("branch")==before and Time.get_ticks_msec()<deadline:await process_frame
	check(session.authority.count("branch")>before and not server.state().resources[source.id].available,"Real timed gathering awards once and consumes the shared resource")
	check(place(owner_id,Vector3(L.DOCK.x,.2,L.DOCK.y)),"Valley return pier has a safe authority landing")
	await create_timer(.6).timeout
	var coins: int=session.state().coins;var branches: int=session.authority.count("branch")
	await Travel.go(game);check(await wait_scene("city"),"Real online return changes to the city scene")
	await create_timer(.8).timeout
	check(session.state().coins==coins and session.authority.count("branch")==branches,"Free return retains gathered inventory")
	await Travel.go(game,"valley");check(await wait_scene("valley"),"Real outbound boat returns to the new valley")
	await create_timer(.8).timeout
	check(session.state().coins==coins-10 and session.authority.count("branch")==branches,"Round trip charges the outward fare exactly once and keeps progress")
	check(place(friend_id,Vector3(13,.2,41.5)),"Visitor reaches the city's real boat departure point")
	result=await friend.request("travel",{"destination":"valley"});check(result.get("ok",false),"Second live client independently travels to the new valley")
	await create_timer(.8).timeout
	check(game.online_view.replicas.has(friend_id) and game.online_view.buffers.has("Panda"),"Online valley renders the other player and buffered NPC movement")
	server.world.state.time=1800.;await create_timer(1.3).timeout
	await visitors_walk("daytime")
	var visitor: CharacterBody3D=server.maps.valley.targets.ValleyVisitor0.node
	check(place(friend_id,visitor.position+Vector3(2,0,0)),"Second player reaches a real safe position beside the rabbit")
	result=await friend.request("talk",{"target":"ValleyVisitor0"});check(result.get("ok",false),"Second player starts a real authority conversation")
	var talking_at: Vector3=visitor.position;await create_timer(.6).timeout
	check(visitor.position.distance_to(talking_at)<.08 and not visitor.walking,"Rabbit stops naturally while another player talks")
	result=await friend.request("end_talk");check(result.get("ok",false),"Second player ends the conversation")
	check(place(friend_id,server.maps.valley.respawn_position()),"Conversation partner leaves room for the rabbit to resume")
	await create_timer(2.5).timeout
	check(visitor.position.distance_to(talking_at)>.6,"Rabbit resumes roaming after the conversation")
	server.world.state.time=3300.;await create_timer(1.4).timeout
	for id in ["ValleyVisitor0","ValleyVisitor1"]:
		check(server.maps.valley.targets[id].node.get_meta("presence")==0 and game.targets[id].node.get_meta("presence")==0 and float(friend_motion.get(id,{}).get("presence",-1))==0,"Night absence reaches both real clients: "+id)
	server.world.state.time=900.;await create_timer(1.4).timeout
	for id in ["ValleyVisitor0","ValleyVisitor1"]:
		check(server.maps.valley.targets[id].node.get_meta("interaction_available") and game.targets[id].node.get_meta("interaction_available"),"Dawn restores rabbit interaction on authority and client: "+id)
	await visitors_walk("after dawn")
	RenderingServer.force_draw();root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/online-valley.png")
	await friend.request("leave");friend.close();friend.queue_free();await session.leave_online()
	current_scene=null;game.queue_free();await process_frame;server.listener.stop();server.queue_free();await process_frame
	print("VALLEY_MULTIPLAYER_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
