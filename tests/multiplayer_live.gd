extends SceneTree
const Release=preload("res://scripts/services/release.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
var clients: Array=[]
var tokens: Array=[]
var ids: Array=[]
var snapshots: Dictionary={}
var chats:=0
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func run() -> void:
	Engine.max_fps=45
	var endpoint:=OS.get_environment("TUTU_TEST_ENDPOINT")
	if endpoint=="":endpoint="ws://127.0.0.1:18895"
	var old=Transport.new();old.set_meta("build",2);root.add_child(old)
	check(not await old.ensure_connected(endpoint) and old.required_version==Release.VERSION,"Live server rejects outdated build")
	old.close();old.queue_free()
	var suffix:=Crypto.new().generate_random_bytes(5).hex_encode()
	for i in range(5):
		var client=Transport.new();root.add_child(client);clients.append(client)
		client.snapshot_received.connect(func(s: Dictionary):snapshots[i]=s)
		client.message_received.connect(func(m: Dictionary):
			if m.get("type","")=="chat":chats+=1)
		check(await client.ensure_connected(endpoint),"Live connection "+str(i))
		var result: Dictionary=await client.request("register",{"username":"live_"+suffix+str(i),"password":"island-live-123"})
		check(result.get("ok",false),"Live registration "+str(i));tokens.append(result.get("token",""))
		result=await client.request("create_character",{"name":"验服"+suffix.left(5)+str(i),"species":["bunny","cat_teacher","panda"][i%3],"starter":"bow_rose"})
		check(result.get("ok",false),"Live character "+str(i))
		if not result.get("ok",false):print(result);quit(1);return
		ids.append(result.character)
		result=await client.request("join",{"character":result.character})
		check(result.get("ok",false),"Live join "+str(i))
	await create_timer(1).timeout
	for i in range(5):
		var state: Dictionary=snapshots.get(i,{}).get("state",{})
		var inventory: Dictionary=state.get("inventory",{})
		check(int(state.get("coins",0))==500 and inventory.size()==1 and int(inventory.get("bow_rose",0))==1,"Live starting supplies "+str(i))
		var p: Array=state.get("player_position",[0,0,0])
		for j in range(i):
			var q: Array=snapshots[j].state.player_position
			check(Vector3(p[0],p[1],p[2]).distance_to(Vector3(q[0],q[1],q[2]))>1.65,"Live reserved spawns")
	var result: Dictionary=await clients[0].request("chat",{"text":"海岛验收 🍊🐰✨"})
	await create_timer(.4).timeout
	check(result.get("ok",false) and chats==5,"Five live clients receive emoji")
	result=await clients[0].request("set_testing_time",{"hour":0})
	check(not result.get("ok",false),"Live time command rejected")
	await clients[0].request("leave");clients[0].close();await create_timer(.4).timeout
	check(await clients[0].ensure_connected(endpoint),"Reconnect transport")
	result=await clients[0].request("resume",{"token":tokens[0]})
	check(result.get("ok",false) and result.get("characters",[]).size()==1,"Resume saved account and character")
	result=await clients[0].request("join",{"character":ids[0]})
	check(result.get("ok",false),"Rejoin saved character")
	for i in range(5):
		await clients[i].request("leave")
		await clients[i].request("logout",{"token":tokens[i]})
	result=await clients[0].request("resume",{"token":tokens[0]})
	check(not result.get("ok",false),"Logout revokes token")
	for client in clients:client.close()
	print("MULTIPLAYER_LIVE_RESULT ","PASS" if failures.is_empty() else "FAIL"," endpoint=",endpoint," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
