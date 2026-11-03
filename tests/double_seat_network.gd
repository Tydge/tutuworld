extends SceneTree
const Server=preload("res://server/world_server.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
var clients: Array=[]
var ids: Array=[]
var snapshots: Dictionary={}
var answers: Dictionary={}
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func submit(index: int) -> void:answers[index]=await clients[index].request("sit",{"target":"home_sofa"})
func _initialize() -> void:call_deferred("run")
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18908");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/seat-network-"+str(Time.get_ticks_usec())))
	var server:=Server.new();root.add_child(server)
	while not server.ready_for_players:await process_frame
	for host in server.maps.values():
		for npc in host.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0;npc.hide()
	var suffix:=Crypto.new().generate_random_bytes(4).hex_encode()
	for i in range(3):
		var client:=Transport.new();root.add_child(client);clients.append(client);client.snapshot_received.connect(func(snapshot):snapshots[i]=snapshot)
		check(await client.ensure_connected("ws://127.0.0.1:18908"),"Real WebSocket connection: "+str(i))
		var result: Dictionary=await client.request("register",{"username":"seat_"+suffix+str(i),"password":"test-seats-123"})
		check(result.get("ok",false),"Isolated account registration: "+str(i))
		result=await client.request("create_character",{"name":"双人坐席"+suffix.left(3)+str(i),"species":["bunny","cat_teacher","panda"][i],"starter":"bow_rose"})
		if not result.get("ok",false):check(false,"Create network fixture");print(result);finish(server);return
		ids.append(result.character);result=await client.request("join",{"character":result.character});check(result.get("ok",false),"Join the shared physical world: "+str(i))
	var seat: Node3D=server.maps.city.targets.home_sofa.node
	for i in range(3):var pawn=server.pawns[ids[i]];pawn.position=seat.to_global(Vector3((i-1)*1.8,.2,3.2));pawn.velocity=Vector3.ZERO;pawn.reset_network_motion()
	await create_timer(.2).timeout;submit(0);submit(1)
	var deadline:=Time.get_ticks_msec()+12000
	while answers.size()<2 and Time.get_ticks_msec()<deadline:await process_frame
	check(answers.size()==2 and answers.get(0,{}).get("ok",false) and answers.get(1,{}).get("ok",false),"Two concurrent interactions claim different automatic seats")
	var third: Dictionary=await clients[2].request("sit",{"target":"home_sofa"});check(not third.get("ok",false),"Third network client receives a full-seat rejection")
	await create_timer(.2).timeout
	check(snapshots.get(0,{}).get("state",{}).get("net_pose",{}).get("slot",-1)!=snapshots.get(1,{}).get("state",{}).get("net_pose",{}).get("slot",-1),"Both client snapshots carry their own physical slot")
	var standing: Dictionary=await clients[0].request("stand");check(standing.get("ok",false) and server.pawns[ids[1]].seated,"Standing releases only that player's seat")
	third=await clients[2].request("sit",{"target":"home_sofa"});check(third.get("ok",false),"One interaction automatically reuses the released slot")
	clients[2].close();await create_timer(.3).timeout;check(server.pawns.has(ids[1]) and server.pawns[ids[1]].seated and not server.pawns.has(ids[2]),"Disconnect releases the correct slot and preserves the other seated player")
	finish(server)
func finish(server: Node) -> void:
	for client in clients:client.close();client.queue_free()
	await process_frame;server.listener.stop();server.queue_free();await process_frame
	print("DOUBLE_SEAT_NETWORK_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
