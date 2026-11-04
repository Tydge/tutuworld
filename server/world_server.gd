extends Node
const Authority=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Catalog=preload("res://scripts/characters/animal_catalog.gd")
const Release=preload("res://scripts/services/release.gd")
const Codec=preload("res://scripts/services/packet_codec.gd")
var world=Authority.new()
var peers: Dictionary={}
var records: Dictionary={}
var actors: Dictionary={}
var pawns: Dictionary={}
var maps: Dictionary={}
var locks: Dictionary={}
var care_history: Dictionary={}
var doors: Dictionary={}
var epoch:=0.0
var listener:=TCPServer.new()
var serial:=0
var ready_for_players:=false
var movement_timer:=0.0
var snapshot_timer:=0.0
var save_timer:=0.0
var last_wall:=0.0
var save_path: String
var auth_url: String
var clock_alignment: Dictionary={}
var admin_timer:=0.0
var metrics_timer:=0.0
var metrics_frames:=0
var metrics_max_frame:=0.0
var metrics_elapsed:=0.0
func state() -> Dictionary:return world.state
func _ready() -> void:
	var directory:=OS.get_environment("TUTU_STATE_DIR")
	if directory=="":directory="user://multiplayer-server"
	DirAccess.make_dir_recursive_absolute(directory)
	save_path=directory.path_join("world.json")
	auth_url="http://127.0.0.1:"+env("TUTU_AUTH_PORT","18892")+"/"
	load_world()
	for id in ["city","valley"]:
		var viewport:=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(16,16)
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
		var host=load("res://server/"+id+"_host.gd").new()
		host.map_id=id;host.manager=self;viewport.add_child(host);maps[id]=host
	await get_tree().physics_frame
	await get_tree().physics_frame
	apply_door_states()
	if epoch<=0:epoch=Time.get_unix_time_from_system();world.state.time=0
	var now:=Time.get_unix_time_from_system()
	world.tick(maxf(0,now-epoch-float(world.state.time)))
	last_wall=now
	if not save_world():push_error("World storage is not writable");get_tree().quit(2);return
	var error:=listener.listen(int(env("TUTU_GAME_PORT","18891")),"127.0.0.1")
	if error!=OK:push_error("Game socket failed");get_tree().quit(3);return
	ready_for_players=true
	print("TUTU_SERVER_READY version=",Release.VERSION," build=",Release.BUILD)
func env(key: String,fallback: String) -> String:
	var value:=OS.get_environment(key)
	return fallback if value=="" else value
func load_world() -> void:
	var data: Dictionary={}
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path):continue
		var raw=JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Dictionary and raw.get("schema",0)==1 and raw.get("world") is Dictionary:data=raw;break
	if data.is_empty():return
	epoch=float(data.epoch);records=data.get("characters",{});care_history=data.get("care_history",{});doors=data.get("doors",{})
	clock_alignment=data.get("clock_alignment",{})
	world.state.merge(data.world,true)
	for record in records.values():
		record.rest_mode="";record.rest_bed="";record.net_pose={}
func apply_door_states() -> void:
	for map_id in maps:
		var host=maps[map_id]
		for id in host.targets:
			var row: Dictionary=host.targets[id]
			if row.kind not in ["door","home_door"] or not row.has("node"): continue
			var value: Dictionary=doors.get(map_id if id=="home_door" else map_id+":"+id,{})
			row.node.door_open=value.get("open",false);row.node.door_target=float(value.get("target",0));row.node.door_tweening=true
func character_record(id: String) -> Dictionary:
	var a=actors[id]
	var record: Dictionary=a.state.duplicate(true)
	for key in ["plots","resources","world_id","time","net_pose"]:record.erase(key)
	record.stamina=minf(a.stamina_max(),float(record.stamina)+a.reserved_work_stamina(a.job))
	record.rest_mode="";record.rest_bed=""
	if pawns.has(id):record.player_position=standing_exit(id)
	record.saved_at=Time.get_unix_time_from_system()
	record.seen=a.seen_commands.duplicate(true)
	return record
func save_world() -> bool:
	for id in actors:records[id]=character_record(id)
	var data:={"schema":1,"epoch":epoch,"clock_alignment":clock_alignment,"world":{"time":world.state.time,"plots":world.state.plots,"resources":world.state.resources},"characters":records,"care_history":care_history,"doors":doors}
	var old: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
	var backup_valid: bool=old is Dictionary and old.get("schema",0)==1 and old.get("world") is Dictionary
	return preload("res://scripts/services/atomic_file.gd").write(save_path,JSON.stringify(data,"",false,true),backup_valid)

func _process(delta: float) -> void:
	if not ready_for_players:return
	metrics_timer+=delta;metrics_elapsed+=delta;metrics_frames+=1;metrics_max_frame=maxf(metrics_max_frame,delta*1000)
	if metrics_timer>=30:
		if not actors.is_empty():
			var queued:=0
			for pawn in pawns.values():queued+=pawn.network_queue.size()
			print("NET_SERVER players=",actors.size()," queued_inputs=",queued," frame_ms_avg=",snappedf(metrics_elapsed*1000/maxi(1,metrics_frames),.1)," frame_ms_max=",snappedf(metrics_max_frame,.1))
		metrics_timer=0;metrics_elapsed=0;metrics_frames=0;metrics_max_frame=0
	while listener.is_connection_available():
		var tcp:=listener.take_connection()
		if peers.size()>=32:tcp.disconnect_from_host();continue
		var socket:=WebSocketPeer.new();socket.inbound_buffer_size=Codec.MAX_BYTES;socket.outbound_buffer_size=Codec.MAX_BYTES
		socket.heartbeat_interval=10
		if socket.accept_stream(tcp)!=OK:continue
		serial+=1
		peers[serial]={"socket":socket,"account":"","character":"","hello":false,"authenticating":false,"last":Time.get_ticks_msec(),"chat_at":0,"burst":0,"burst_at":Time.get_ticks_msec()}
	for peer_id in peers.keys():
		if not peers.has(peer_id):continue
		var peer: Dictionary=peers[peer_id];var socket: WebSocketPeer=peer.socket
		socket.poll()
		if socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:disconnect_peer(peer_id);continue
		var consumed:=0
		while socket.get_available_packet_count()>0 and consumed<64:
			consumed+=1;peer.last=Time.get_ticks_msec()
			if peer.last-int(peer.burst_at)>2000:peer.burst_at=peer.last;peer.burst=0
			peer.burst+=1
			if peer.burst>100:socket.close(1008,"Too many requests");break
			var data:=Codec.decode(socket.get_packet())
			if not data.is_empty():receive(peer_id,data)
		if Time.get_ticks_msec()-int(peer.last)>45000:socket.close(1001,"Connection timed out")
	var now:=Time.get_unix_time_from_system()
	var elapsed:=maxf(0,now-last_wall);last_wall=maxf(last_wall,now)
	world.tick(elapsed)
	for id in actors.keys():tick_actor(id,elapsed)
	refresh_occupancy()
	movement_timer+=delta;snapshot_timer+=delta;save_timer+=delta
	if movement_timer>=.10:movement_timer=0;broadcast_motion()
	if snapshot_timer>=.75:
		snapshot_timer=0
		for peer_id in peers:
			if peers[peer_id].character!="":send_snapshot(peer_id)
	if save_timer>=10:save_timer=0;save_world()
	admin_timer+=delta
	if admin_timer>=1:
		admin_timer=0
		var request:=save_path.get_base_dir().path_join("align-hour.request")
		if FileAccess.file_exists(request):
			if not clock_alignment.is_empty() or align_clock_to_hours():DirAccess.remove_absolute(request)
func align_clock_to_hours() -> bool:
	if not clock_alignment.is_empty():return false
	var old_time: float=world.state.time
	var now:=Time.get_unix_time_from_system()
	var phase:=fposmod(now,3600)
	var day:=int(floor(old_time/3600))
	if day*3600+phase<old_time:day+=1
	var new_epoch: float=floorf(now/3600)*3600-day*3600
	var new_time: float=now-new_epoch
	var shift: float=new_time-old_time
	var previous:={"epoch":epoch,"world":world.state.duplicate(true),"records":records.duplicate(true),"actors":{}}
	for id in actors:previous.actors[id]={"time":actors[id].state.time,"food_effect":actors[id].state.food_effect.duplicate(true)}
	for resource in world.state.resources.values():
		if not resource.available:resource.respawn_at=float(resource.respawn_at)+shift
	for id in records:
		if actors.has(id):continue
		var effect: Dictionary=records[id].get("food_effect",{})
		if not effect.is_empty():effect.expires_at=float(effect.expires_at)+shift
	for a in actors.values():
		if not a.state.food_effect.is_empty():a.state.food_effect.expires_at=float(a.state.food_effect.expires_at)+shift
		a.state.time=new_time
	world.state.time=new_time;epoch=new_epoch
	clock_alignment={"version":1,"aligned_at":now,"shift":shift,"real_hour_game_hour":0,"real_half_hour_game_hour":12}
	if not save_world():
		epoch=previous.epoch;world.state=previous.world;records=previous.records;clock_alignment={}
		for id in actors:
			actors[id].state.time=previous.actors[id].time;actors[id].state.food_effect=previous.actors[id].food_effect
			actors[id].state.plots=world.state.plots;actors[id].state.resources=world.state.resources
		return false
	print("TUTU_CLOCK_ALIGNED hour=00 half_hour=12")
	for peer_id in peers:
		if peers[peer_id].character!="":send_snapshot(peer_id)
	return true
func send(peer_id: int,data: Dictionary) -> void:
	if peers.has(peer_id) and peers[peer_id].socket.get_ready_state()==WebSocketPeer.STATE_OPEN:peers[peer_id].socket.put_packet(Codec.encode(data))
func answer(peer_id: int,request: Dictionary,result: Dictionary) -> void:
	if peers.has(peer_id) and peers[peer_id].character!="":send_snapshot(peer_id)
	send(peer_id,{"type":"result","id":str(request.get("id","")),"result":result})
func receive(peer_id: int,data: Dictionary) -> void:
	var peer: Dictionary=peers[peer_id]
	var kind: String=str(data.get("type",""))
	if kind=="hello":
		var required:=required_release()
		if int(data.get("build",0))!=Release.BUILD or int(data.get("protocol",0))!=Release.PROTOCOL or int(data.get("build",0))!=int(required.build):
			send(peer_id,{"type":"update_required","build":required.build,"version":required.version});return
		peer.hello=true;send(peer_id,{"type":"welcome","build":Release.BUILD,"version":Release.VERSION});return
	if not peer.hello:return
	if kind=="ping":send(peer_id,{"type":"pong"});return
	if kind=="motion":
		if peer.character=="" or not pawns.has(peer.character):return
		var pawn=pawns[peer.character]
		var inputs=data.get("inputs",[])
		if int(data.get("generation",0))!=pawn.network_generation or not inputs is Array or inputs.size()>12:return
		for input in inputs:
			if not input is Dictionary:return
			var direction=input.get("direction",[])
			if not direction is Array or direction.size()!=3:return
			for n in direction:
				if not (n is float or n is int) or not is_finite(float(n)):return
			var seq:=int(input.get("seq",0))
			if seq<=pawn.network_received:continue
			if seq!=pawn.network_received+1 or pawn.network_queue.size()>=120:
				pawn.reset_network_motion();send_snapshot(peer_id);return
			var limited:=Vector3(float(direction[0]),0,float(direction[2])).limit_length(1)
			pawn.network_queue.append({"seq":seq,"direction":[limited.x,0,limited.z],"running":bool(input.get("running",false)),"jump":bool(input.get("jump",false))})
			pawn.network_received=seq
		peer.motion_at=Time.get_ticks_msec()
		return
	if kind!="request" or str(data.get("id","")).length()>128:return
	var verb: String=str(data.get("verb",""));var args=data.get("args",{})
	if not args is Dictionary:return
	if args.has("quantity"):
		var value=args.quantity
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)) or absf(float(value))>99999:answer(peer_id,data,fail("数量不正确。"));return
	if verb in ["register","login","resume"]:
		if peer.authenticating:return
		peer.authenticating=true
		authenticate(peer_id,data,verb,args);return
	if peer.account=="":answer(peer_id,data,fail("先登录，再去岛上看看吧。"));return
	if verb=="characters":answer(peer_id,data,{"ok":true,"characters":roster(peer.account)});return
	if verb=="logout":logout_account(peer_id,data,args);return
	if verb=="create_character":answer(peer_id,data,create_character(peer.account,args));return
	if verb=="join":answer(peer_id,data,join_world(peer_id,str(args.get("character",""))));return
	if verb=="leave":leave_world(peer_id);answer(peer_id,data,{"ok":true});return
	if peer.character=="":answer(peer_id,data,fail("请选择角色。"));return
	if verb=="chat":chat(peer_id,data,str(args.get("text","")));return
	answer(peer_id,data,execute_player(peer_id,data,verb,args))
func authenticate(peer_id: int,request: Dictionary,action: String,args: Dictionary) -> void:
	var http:=HTTPRequest.new();http.timeout=12;http.use_threads=true;add_child(http)
	var error:=http.request(auth_url+action,PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(args))
	var result: Dictionary=fail("暂时联系不到登录服务，请稍后再试。")
	if error==OK:
		var response: Array=await http.request_completed
		if int(response[0])==HTTPRequest.RESULT_SUCCESS and int(response[1])==200:
			var value=JSON.parse_string(response[3].get_string_from_utf8())
			if value is Dictionary:result=value
	http.queue_free()
	if not peers.has(peer_id):return
	peers[peer_id].authenticating=false
	if result.get("ok",false):
		if peers[peer_id].character!="":leave_world(peer_id)
		peers[peer_id].account=str(result.account_id);result.erase("account_id")
		result.characters=roster(peers[peer_id].account)
	answer(peer_id,request,result)
func roster(account: String) -> Array:
	var out: Array=[]
	for id in records:
		if records[id].get("account_id","")==account:
			var record: Dictionary=records[id]
			out.append({"id":id,"character_name":record.character_name,"species":record.species,"equipment":record.equipment,"experience":record.experience})
	return out
func logout_account(peer_id: int,request: Dictionary,args: Dictionary) -> void:
	var http:=HTTPRequest.new();http.timeout=10;add_child(http)
	if http.request(auth_url+"logout",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"token":str(args.get("token",""))}))==OK:await http.request_completed
	http.queue_free()
	if not peers.has(peer_id):return
	leave_world(peer_id);peers[peer_id].account="";answer(peer_id,request,{"ok":true})
func create_character(account: String,args: Dictionary) -> Dictionary:
	var display_name: String=str(args.get("name","")).strip_edges()
	if display_name.length()<1 or display_name.length()>12:return fail("名字要有1～12个字哦。")
	for c in display_name:
		if c.unicode_at(0)<32 or c.unicode_at(0)==127:return fail("名字不能包含换行或控制字符。")
	for record in records.values():
		if str(record.character_name).nocasecmp_to(display_name)==0:return fail("岛上已经有这个名字啦。")
	var species: String=str(args.get("species","bunny"));var starter: String=str(args.get("starter",""))
	if not Catalog.supports(species) or starter not in DB.starter_clothes():return fail("请选择角色和一件初始服饰。")
	var a=Authority.new();var id:="char_"+Crypto.new().generate_random_bytes(12).hex_encode()
	a.state.merge({"player_id":id,"account_id":account,"character_name":display_name,"species":species,"coins":500,"inventory":{starter:1},"saved_at":Time.get_unix_time_from_system()},true)
	a.state.equipment[DB.item(starter).slot]=starter
	var record: Dictionary=a.state.duplicate(true)
	for key in ["plots","resources","time","world_id"]:record.erase(key)
	records[id]=record
	if not save_world():records.erase(id);return fail("角色还没有保存成功，请稍后再试。")
	return {"ok":true,"character":id,"characters":roster(account)}
func join_world(peer_id: int,id: String) -> Dictionary:
	var peer: Dictionary=peers[peer_id]
	if not records.has(id) or records[id].get("account_id","")!=peer.account:return fail("找不到这位角色。")
	if peer.character!="":return fail("你已经在岛上啦。")
	for other in peers.values():
		if other.account==peer.account and other.character!="":return fail("这个账号已经在另一处进入岛上了。")
	var record: Dictionary=records[id];var a=Authority.new();a.state.merge(record,true);a.normalize_production_state()
	a.state.plots=world.state.plots;a.state.resources=world.state.resources;a.state.time=world.state.time;a.state.net_pose={}
	a.seen_commands=record.get("seen",{}).duplicate(true)
	a.tick_stamina(maxf(0,Time.get_unix_time_from_system()-float(record.get("saved_at",Time.get_unix_time_from_system()))))
	var map_id: String=str(a.state.get("map_id","city"))
	if not maps.has(map_id):map_id="city";a.state.map_id=map_id
	var pawn=Animals.create(a.state.species);pawn.name=id;pawn.network_controlled=true;pawn.network_sequenced=true;pawn.world=maps[map_id]
	maps[map_id].add_child(pawn)
	var old: Array=a.state.player_position
	var desired:=Vector3(float(old[0]),float(old[1]),float(old[2]))
	var point:=safe_position(map_id,desired,id,pawn)
	if point.is_empty():point=safe_position(map_id,maps[map_id].respawn_position(),id,pawn)
	if point.is_empty():pawn.queue_free();return fail("落脚的地方有点挤，稍等一下再进来吧。")
	pawn.position=point.position;pawn.reset_physics_interpolation()
	actors[id]=a;pawns[id]=pawn;peer.character=id
	pawn.set_meta("peer_id",peer_id)
	a.state.player_position=vector_array(pawn.position)
	return {"ok":true,"character":id}
func key_for(map_id: String,target: String) -> String:return map_id+":"+target
func lock_reason(map_id: String,target: String,id: String) -> String:
	var key:=key_for(map_id,target)
	if locks.has(key) and locks[key].owner!=id:return str(locks[key].name)+"正在使用，稍等一下吧。"
	return ""
func occupy(map_id: String,target: String,id: String,kind: String) -> void:
	locks[key_for(map_id,target)]={"owner":id,"name":actors[id].actor_name(),"kind":kind,"target":target,"map":map_id}
func release_all(id: String) -> void:
	for key in locks.keys():
		if locks[key].owner==id:
			var row: Dictionary=locks[key]
			if row.kind=="talk":maps[row.map].talking_npc=""
			locks.erase(key)
func standing_exit(id: String) -> Array:
	var a=actors[id];var pawn=pawns[id];var pose: Dictionary=a.state.get("net_pose",{})
	if pose.has("exit"):return pose.exit
	return vector_array(pawn.position)
func execute_player(peer_id: int,request: Dictionary,verb: String,args: Dictionary) -> Dictionary:
	var id: String=peers[peer_id].character
	var backup:=runtime_checkpoint(id)
	var result:=apply_player(peer_id,request,verb,args)
	if result.get("ok",false) and verb!="history" and not save_world():
		restore_runtime(id,backup)
		return fail("进度暂未保存成功，请稍后再试。")
	return result
func runtime_checkpoint(id: String) -> Dictionary:
	return {"world":world.state.duplicate(true),"records":records.duplicate(true),"locks":locks.duplicate(true),"history":care_history.duplicate(true),"doors":doors.duplicate(true),"state":actors[id].state.duplicate(true),"job":actors[id].job.duplicate(true),"seen":actors[id].seen_commands.duplicate(true),"revision":actors[id].revision,"random":actors[id].reward_random.state,"position":pawns[id].position}
func restore_runtime(id: String,backup: Dictionary) -> void:
	world.state=backup.world;records=backup.records;locks=backup.locks;care_history=backup.history;doors=backup.doors
	apply_door_states()
	var a=actors[id];a.state=backup.state;a.job=backup.job;a.seen_commands=backup.seen;a.revision=backup.revision
	a.reward_random.state=backup.random
	for other in actors.values():other.state.plots=world.state.plots;other.state.resources=world.state.resources
	var pawn=pawns[id];var host=maps[a.state.map_id]
	if pawn.get_parent()!=host:pawn.reparent(host,false);pawn.world=host
	pawn.stand_up(backup.position);pawn.work_align_active=false
	var pose: Dictionary=a.state.get("net_pose",{})
	if pose.get("kind","")=="sleep":pawn.lie_in_bed(host.home.get_node("Furnishing/bed"));host.home.bed_occupant=pawn
	elif pose.get("kind","")=="sit" and host.targets.has(pose.target):pawn.sit_on_surface(preload("res://scripts/city/seating.gd").seat(host.targets[pose.target].node,int(pose.get("slot",0))));pawn.play_action("nap",INF)
	elif pose.get("kind","") in ["eat","waiting_exit"]:pawn.sit_on_surface(host.scenery.get_node("DiningTable/SeatAnchor").global_transform);pawn.play_action("nap",INF)
	elif not a.job.is_empty():begin_job_pose(id)
	pawn.position=backup.position;pawn.reset_network_motion()
func apply_player(peer_id: int,request: Dictionary,verb: String,args: Dictionary) -> Dictionary:
	var id: String=peers[peer_id].character;var a=actors[id];var pawn=pawns[id]
	var command_id:=str(request.get("id",""))
	if command_id!="" and a.seen_commands.has(command_id):return a.seen_commands[command_id].duplicate(true)
	var map_id: String=a.state.map_id;var host=maps[map_id]
	preload("res://scripts/city/production_facilities.gd").refresh(host,a)
	a.state.player_position=vector_array(pawn.position);a.state.time=world.state.time
	var target: String=str(args.get("target",""))
	if verb=="history":return {"ok":true,"history":care_history.get(target,{})}
	if verb=="unstuck":return relocate(id,vector_from(standing_exit(id)),true)
	if verb in ["stand","wake"]:return relocate(id,vector_from(standing_exit(id)),false)
	if verb=="end_talk":release_all(id);a.state.net_pose={};return {"ok":true,"message":""}
	if verb=="door":
		var door_id: String=target if target!="" else "home_door"
		if not host.targets.has(door_id) or host.targets[door_id].kind not in ["door","home_door"] or pawn.position.distance_to(host.targets[door_id].position)>4.8:return fail("先来到门边吧。")
		var house: Node3D=host.targets[door_id].get("node",host.home)
		var result: Dictionary=house.toggle_door(pawn)
		if result.ok: doors[map_id if door_id=="home_door" else map_id+":"+door_id]={"open":house.door_open,"target":house.door_target}
		return result
	if verb in ["sit","talk"]:
		if not a.job.is_empty() or not a.state.get("net_pose",{}).is_empty():return fail("先结束手上的事情吧。")
		if not host.targets.has(target):return fail("这里暂时不能互动。")
		var object_: Dictionary=host.targets[target]
		if verb=="sit":
			if object_.kind!="bench" or not preload("res://scripts/city/furniture_access.gd").reachable(host,object_.node,pawn,2.0):return fail("再靠近座位一点吧。")
		elif pawn.position.distance_to(object_.position)>4:return fail("再靠近一点吧。")
		var reason:=lock_reason(map_id,target,id)
		if reason!="" and verb=="talk":return fail(reason)
		if verb=="talk":
			if object_.kind!="npc" or not object_.node.get_meta("interaction_available",true) or object_.node.sleeping:return fail("现在先别打扰它吧。")
			if not preload("res://scripts/city/conversation_access.gd").can_talk(host,pawn,object_):return fail("请来到面前，隔着墙听不清哦。")
			occupy(map_id,target,id,"talk");host.talking_npc=target;host.bunny=pawn
			a.state.net_pose={"kind":"talk","target":target}
		else:
			if object_.kind!="bench":return fail("这里不是座位。")
			var seat: Node3D=object_.node
			var seating=preload("res://scripts/city/seating.gd");var slot:=-1
			for index in range(seating.capacity(seat)):
				if lock_reason(map_id,seating.lock_target(target,index),id)!="":continue
				if seat_clear(map_id,seating.seat(seat,index).origin,id,target):slot=index;break
			if slot<0:return fail("座位已坐满，或旁边有人，稍等一下吧。")
			var exit_: Array=vector_array(pawn.position)
			pawn.sit_on_surface(seating.seat(seat,slot));pawn.play_action("nap",INF)
			a.state.net_pose={"kind":"sit","target":target,"slot":slot,"exit":exit_}
			occupy(map_id,seating.lock_target(target,slot),id,"sit");pawn.reset_network_motion()
		return {"ok":true,"message":""}
	if verb=="cancel":
		var result: Dictionary=a.execute(command_for(id,request,verb,args))
		release_all(id);finish_pose(id);return result
	if verb=="travel":
		if not a.job.is_empty() or not a.state.get("net_pose",{}).is_empty():return fail("先结束当前动作吧。")
		var destination: String=str(args.get("destination",""))
		if destination not in ["city","valley"]:return fail("航线不正确。")
		var arrival: Array=preload("res://scripts/valley/valley_layout.gd").arrival(destination)
		var point:=safe_position(destination,vector_from(arrival),id,pawn)
		if point.is_empty():return fail("码头有点挤，稍等一下再出发吧。")
		var result: Dictionary=a.execute(command_for(id,request,verb,args))
		if result.ok:
			release_all(id);pawn.reparent(maps[destination],false);pawn.world=maps[destination];pawn.position=point.position;pawn.velocity=Vector3.ZERO
			a.state.player_position=vector_array(pawn.position);pawn.reset_network_motion()
		return result
	if verb not in ["buy","sell","equip","plant","water","weed","harvest","gather","craft","refill","eat","snack","rest"]:return fail("这项操作暂时不能使用。")
	if verb in ["buy","sell"] and not preload("res://scripts/city/conversation_access.gd").can_trade(host,pawn,str(args.get("shop",""))):return fail("请走进店里，来到商人面前再交易。")
	var needs_lock:=verb in ["plant","water","weed","harvest","gather","craft","refill","eat","rest"]
	if not a.state.get("net_pose",{}).is_empty():return fail("先起身或结束交谈吧。")
	if needs_lock:
		if not host.targets.has(target):return fail("请来到对应地点。")
		if verb=="rest":
			if host.targets[target].kind!="bed" or not preload("res://scripts/city/furniture_access.gd").reachable(host,host.targets[target].node,pawn,2.0):return fail("再靠近床边一点吧。")
		elif pawn.position.distance_to(host.targets[target].position)>4:return fail("再靠近一点吧。")
		var reason:=lock_reason(map_id,target,id)
		if reason!="":return fail(reason)
		if host.targets[target].kind=="workshop" and not host.targets[target].building.contains_position(pawn.global_position): return fail("先走进工坊，再使用工作台吧。")
		if verb in ["craft","refill","eat","rest"]:
			var anchor: Vector3
			if host.targets[target].has("work_anchor"): anchor=host.targets[target].work_anchor.global_position
			else: anchor=host.scenery.get_node("Kitchen/CookAnchor").global_position if verb=="craft" else (host.scenery.get_node("DiningTable/SeatAnchor").global_position if verb=="eat" else host.home.get_node("Furnishing/bed").global_position)
			if not body_clear(map_id,anchor,id):return fail("操作的位置有人，稍等一下吧。")
	var result: Dictionary=a.execute(command_for(id,request,verb,args))
	if result.ok:
		if needs_lock:occupy(map_id,target,id,"sleep" if verb=="rest" else "job")
		if verb=="rest":
			var bed: Node3D=host.home.get_node("Furnishing/bed")
			var exit_: Array=vector_array(pawn.position)
			pawn.lie_in_bed(bed);host.home.bed_occupant=pawn
			a.state.net_pose={"kind":"sleep","target":target,"exit":exit_};pawn.reset_network_motion()
		elif not a.job.is_empty():begin_job_pose(id)
	return result
func command_for(id: String,request: Dictionary,verb: String,args: Dictionary) -> Dictionary:
	var out:=args.duplicate(true)
	out.merge({"id":str(request.get("id","")),"player_id":id,"protocol":1,"verb":verb},true)
	return out
func begin_job_pose(id: String) -> void:
	var a=actors[id];var pawn=pawns[id];var host=maps[a.state.map_id];var j: Dictionary=a.job
	pawn.can_move=false;pawn.velocity=Vector3.ZERO
	var animation: String=j.verb
	if j.verb=="craft":
		pawn.position=host.targets[j.target].work_anchor.global_position if host.targets[j.target].has("work_anchor") else host.scenery.get_node("Kitchen/CookAnchor").global_position
		animation="gather_stone" if j.get("station","")=="workshop" else "cook"
		pawn.visual.rotation.y=host.targets[j.target].work_anchor.global_rotation.y+PI if host.targets[j.target].has("work_anchor") else PI
	elif j.verb=="refill": pawn.position=host.targets[j.target].work_anchor.global_position
	elif j.verb=="eat":
		pawn.sit_on_surface(host.scenery.get_node("DiningTable/SeatAnchor").global_transform)
		a.state.net_pose={"kind":"eat","target":"dining","exit":vector_array(host.scenery.get_node("DiningTable/ExitAnchor").global_position)}
	elif j.verb=="gather":animation={"limestone":"gather_stone","copper":"gather_copper","branch":"gather_branch","orange":"harvest_tree","birch":"gather_wood","iron":"gather_copper","sandstone":"gather_stone"}.get(j.item,"gather_branch")
	if host.targets.has(j.target):
		var point: Vector3=host.targets[j.target].position
		if j.verb not in ["craft","eat"]:pawn.visual.rotation.y=atan2(point.x-pawn.position.x,point.z-pawn.position.z)
		if j.verb in ["water","weed","gather"] and animation!="harvest_tree":pawn.align_work(point,1.30 if j.verb=="gather" else 1.45)
	pawn.play_action(animation,INF);a.state.player_position=vector_array(pawn.position);pawn.reset_network_motion()
func finish_pose(id: String) -> void:
	var a=actors[id];var pawn=pawns[id]
	var point:=pose_landing(id,vector_from(standing_exit(id)))
	if point.is_empty() and (pawn.seated or pawn.sleeping):
		var pose: Dictionary=a.state.get("net_pose",{})
		pose.kind="sleep" if pawn.sleeping else "waiting_exit";a.state.net_pose=pose
		occupy(a.state.map_id,str(pose.get("target","dining")),id,"sleep" if pawn.sleeping else "seat")
		if pawn.seated:pawn.play_action("nap",INF)
		return
	if pawn.sleeping:maps[a.state.map_id].home.bed_occupant=null
	pawn.stand_up(point.position if not point.is_empty() else pawn.position)
	pawn.work_align_active=false;pawn.network_direction=Vector3.ZERO;a.state.net_pose={};a.state.rest_mode="";a.sleeping=false;pawn.reset_network_motion()
	a.state.player_position=vector_array(pawn.position)
func relocate(id: String,desired: Vector3,unstuck: bool) -> Dictionary:
	var a=actors[id];var pawn=pawns[id]
	var point:=safe_position(a.state.map_id,desired,id,pawn) if unstuck else pose_landing(id,desired)
	if point.is_empty() and unstuck:point=safe_position(a.state.map_id,maps[a.state.map_id].respawn_position(),id,pawn)
	if point.is_empty():return fail("附近有点挤，稍等一下再试吧。")
	a.execute({"verb":"cancel"});release_all(id)
	if pawn.sleeping:maps[a.state.map_id].home.bed_occupant=null
	pawn.stand_up(point.position);pawn.work_align_active=false;pawn.network_direction=Vector3.ZERO
	a.state.net_pose={};a.state.rest_mode="";a.state.rest_bed="";a.sleeping=false;a.state.player_position=vector_array(pawn.position);pawn.reset_network_motion()
	return {"ok":true,"message":"找到可以落脚的地方啦。" if unstuck else ""}
func pose_landing(id: String,desired: Vector3) -> Dictionary:
	var a=actors[id];var host=maps[a.state.map_id];var pose: Dictionary=a.state.get("net_pose",{});var target: Dictionary=host.targets.get(str(pose.get("target","")),{})
	if pose.get("kind","") in ["sit","sleep","waiting_exit"] and target.get("kind","") in ["bed","bench"] and is_instance_valid(target.get("node")):
		var result:=preload("res://scripts/city/furniture_access.gd").landing(host,target.node,pawns[id],desired)
		return result if not result.is_empty() and body_clear(a.state.map_id,result.position,id) else {}
	return safe_position(a.state.map_id,desired,id,pawns[id])
func tick_actor(id: String,delta: float) -> void:
	var a=actors[id];var pawn=pawns[id]
	var peer: Dictionary=peers.get(int(pawn.get_meta("peer_id",0)),{})
	if Time.get_ticks_msec()-int(peer.get("motion_at",0))>1000:pawn.network_direction=Vector3.ZERO;pawn.network_jump=false
	a.state.time=world.state.time;a.state.plots=world.state.plots;a.state.resources=world.state.resources
	preload("res://scripts/city/production_facilities.gd").refresh(maps[a.state.map_id],a)
	a.state.player_position=vector_array(pawn.position);a.running=pawn.is_running;a.sleeping=pawn.sleeping
	pawn.speed_multiplier=a.multiplier("move");pawn.run_speed_multiplier=a.multiplier("run_speed");pawn.stamina_fraction=float(a.state.stamina)/a.stamina_max()
	a.tick_stamina(delta)
	if not a.state.food_effect.is_empty() and float(a.state.food_effect.expires_at)<=float(world.state.time):a.state.food_effect={};a.state.stamina=minf(a.stamina_max(),a.state.stamina)
	if a.job.is_empty():
		if a.state.get("net_pose",{}).get("kind","")=="waiting_exit":
			var point:=safe_position(a.state.map_id,vector_from(standing_exit(id)),id,pawn)
			if not point.is_empty():release_all(id);finish_pose(id)
		return
	a.job.elapsed+=delta
	if float(a.job.elapsed)<float(a.job.duration):return
	var backup:=runtime_checkpoint(id)
	var job: Dictionary=a.job.duplicate(true);a.job.clear()
	var crop: String=str(world.state.plots.get(job.target,{}).get("crop",""))
	var event: Dictionary=a.complete(job)
	if event.type=="completed" and job.verb in ["plant","water","weed","harvest"]:
		if job.verb=="plant":crop=DB.item(job.item).crop
		record_care(id,job,event,crop)
	release_all(id);finish_pose(id)
	if not save_world():restore_runtime(id,backup);return
	for peer_id in peers:
		if peers[peer_id].character==id:send_snapshot(peer_id);send(peer_id,{"type":"event","event":event})
func record_care(id: String,job: Dictionary,event: Dictionary,crop: String) -> void:
	var history: Dictionary=care_history.get(job.target,{"current":[],"previous":[]})
	if job.verb=="plant":history.previous=history.current;history.current=[]
	history.current.append({"player":id,"name":actors[id].actor_name(),"time":world.state.time,"verb":job.verb,"crop":crop,"quality":event.get("quality_increased",false),"amount":event.get("amount",0)})
	care_history[job.target]=history
func refresh_occupancy() -> void:
	for key in locks.keys():
		if not locks.has(key):continue
		var row: Dictionary=locks[key];var id: String=row.owner
		if not actors.has(id):locks.erase(key);continue
		if row.kind=="talk":
			var target: Dictionary=maps[row.map].targets.get(row.target,{})
			if target.is_empty() or pawns[id].position.distance_to(target.position)>4 or not target.node.get_meta("interaction_available",true) or not preload("res://scripts/city/conversation_access.gd").can_talk(maps[row.map],pawns[id],target):
				release_all(id);actors[id].state.net_pose={}
func seat_clear(map_id: String,point: Vector3,ignore: String,target: String) -> bool:
	for id in pawns:
		if id==ignore or actors[id].state.map_id!=map_id:continue
		var other: Vector3=pawns[id].position;var pose: Dictionary=actors[id].state.get("net_pose",{})
		var radius: float=pawns[ignore].rig_profile.head_radii.x+pawns[id].rig_profile.head_radii.x+.06 if pose.get("kind","")=="sit" and pose.get("target","")==target else 1.85
		if absf(other.y-point.y)<2.6 and Vector2(other.x-point.x,other.z-point.z).length()<radius:return false
	for npc in maps[map_id].npcs:
		if npc.visible and not npc.sleeping and absf(npc.position.y-point.y)<2.6 and Vector2(npc.position.x-point.x,npc.position.z-point.z).length()<1.85:return false
	return true
func body_clear(map_id: String,point: Vector3,ignore: String) -> bool:
	for id in pawns:
		if id==ignore or actors[id].state.map_id!=map_id:continue
		var other: Vector3=pawns[id].position
		if absf(other.y-point.y)<2.6 and Vector2(other.x-point.x,other.z-point.z).length()<1.85:return false
	for npc in maps[map_id].npcs:
		if not npc.visible or npc.sleeping:continue
		var other: Vector3=npc.position
		if absf(other.y-point.y)<2.6 and Vector2(other.x-point.x,other.z-point.z).length()<1.85:return false
	return true
func safe_position(map_id: String,desired: Vector3,ignore: String,pawn: CharacterBody3D) -> Dictionary:
	if not desired.is_finite():return {}
	var host=maps[map_id];var space: PhysicsDirectSpaceState3D=host.get_world_3d().direct_space_state
	var floor_query:=PhysicsRayQueryParameters3D.new();floor_query.collision_mask=8
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=5;query.collide_with_areas=false;query.exclude=[pawn.get_rid()]
	var capsule:=CylinderShape3D.new();capsule.radius=.36;capsule.height=1.0
	var sphere:=SphereShape3D.new();sphere.radius=maxf(pawn.rig_profile.head_collision_radius,pawn.rig_profile.head_radii.x+.03)
	capsule.radius=maxf(.36,pawn.rig_profile.body_radii.x+.04)
	var component: int=-1
	if host.navigation.sampling_ready:
		component=host.navigation.component_of.get(host.navigation.closest_free(desired),-1)
	for ring in range(10):
		var count_: int=1 if ring==0 else 16
		for i in range(count_):
			var angle:=float(i)*TAU/count_
			var p:=desired+Vector3(cos(angle),0,sin(angle))*ring*.85
			if not host.can_walk(p):continue
			if component>=0 and host.navigation.component_of.get(host.navigation.closest_free(p),-1)!=component:continue
			floor_query.from=p+Vector3(0,1.1,0);floor_query.to=p-Vector3(0,1.6,0)
			var floor_hit:=space.intersect_ray(floor_query)
			if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
			p.y=float(floor_hit.position.y)+.025
			if absf(p.y-desired.y)>1.2 or not body_clear(map_id,p,ignore):continue
			query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,.65,0))
			if not space.intersect_shape(query,1).is_empty():continue
			query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,p+pawn.rig_profile.head_center)
			if not space.intersect_shape(query,1).is_empty():continue
			return {"position":p}
	return {}
func actor_packet(id: String) -> Dictionary:
	var a=actors[id];var pawn=pawns[id]
	return {"generation":pawn.network_generation,"ack":pawn.network_ack,"id":id,"name":a.actor_name(),"species":a.state.species,"map":a.state.map_id,"position":vector_array(pawn.position),"velocity":vector_array(pawn.velocity),"yaw":pawn.visual.rotation.y,"equipment":a.state.equipment,"watering_can":a.watering_can_id(),"action":pawn.action,"walking":pawn.walking,"grounded":pawn.is_on_floor(),"pose":a.state.get("net_pose",{}),"job":a.job}
func broadcast_motion() -> void:
	var batches: Dictionary={"city":[],"valley":[]}
	for id in actors:batches[actors[id].state.map_id].append(actor_packet(id))
	for map_id in maps:
		for npc in maps[map_id].npcs:
			batches[map_id].append({"id":str(npc.name),"npc":true,"position":vector_array(npc.position),"velocity":vector_array(npc.velocity),"yaw":npc.visual.rotation.y,"walking":npc.walking,"grounded":npc.is_on_floor(),"action":npc.action,"sleeping":npc.sleeping,"presence":npc.get_meta("presence",1.0),"equipment":npc.get_meta("equipment",{})})
	for peer_id in peers:
		var id: String=peers[peer_id].character
		if actors.has(id):send(peer_id,{"type":"motion","tick":Engine.get_physics_frames(),"actors":batches[actors[id].state.map_id]})
func send_snapshot(peer_id: int) -> void:
	if not peers.has(peer_id):return
	var id: String=peers[peer_id].character
	if not actors.has(id):return
	var a=actors[id];var snapshot: Dictionary=a.state.duplicate(true)
	snapshot.erase("account_id");snapshot.erase("seen");snapshot.time=world.state.time
	send(peer_id,{"type":"snapshot","state":snapshot,"job":a.job,"locks":locks,"care_history":care_history,"doors":doors,"epoch":epoch,"movement":actor_packet(id)})
func chat(peer_id: int,request: Dictionary,text: String) -> void:
	var peer: Dictionary=peers[peer_id]
	text=text.strip_edges()
	if text=="" or text.length()>120:return
	if Time.get_ticks_msec()-int(peer.chat_at)<700:answer(peer_id,request,fail("慢一点说，大家才听得清。"));return
	for c in text:
		if c.unicode_at(0)<32:return
	peer.chat_at=Time.get_ticks_msec()
	var id: String=peer.character;var map_id: String=actors[id].state.map_id
	for receiver in peers:
		var other: String=peers[receiver].character
		if actors.has(other) and actors[other].state.map_id==map_id:send(receiver,{"type":"chat","id":id,"name":actors[id].actor_name(),"text":text})
	answer(peer_id,request,{"ok":true})
func leave_world(peer_id: int) -> void:
	if not peers.has(peer_id):return
	var id: String=peers[peer_id].character
	if actors.has(id):
		actors[id].execute({"verb":"cancel"});release_all(id)
		records[id]=character_record(id)
		if pawns[id].sleeping:maps[actors[id].state.map_id].home.bed_occupant=null
		pawns[id].collision_layer=0;pawns[id].queue_free();pawns.erase(id);actors.erase(id);peers[peer_id].character="";save_world()
func disconnect_peer(peer_id: int) -> void:leave_world(peer_id);peers.erase(peer_id)
func fail(message: String) -> Dictionary:return {"ok":false,"message":message}
func required_release() -> Dictionary:
	var path:=OS.get_environment("TUTU_RELEASE_MANIFEST")
	if path!="" and FileAccess.file_exists(path):
		var envelope=JSON.parse_string(FileAccess.get_file_as_string(path))
		var verified:=preload("res://scripts/services/update_client.gd").verify_envelope(envelope)
		if not verified.is_empty():return {"build":verified.build,"version":verified.version}
	return {"build":Release.BUILD,"version":Release.VERSION}
func vector_array(p: Vector3) -> Array:return [p.x,p.y,p.z]
func vector_from(p: Array) -> Vector3:return Vector3(float(p[0]),float(p[1]),float(p[2]))
