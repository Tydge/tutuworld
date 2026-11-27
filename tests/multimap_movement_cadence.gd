extends SceneTree
var server: Node
var players: Dictionary = {}
var sequence: Dictionary = {}
const FINAL_SCENARIO := "four maps+six players"
var passed := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	OS.set_environment("TUTU_GAME_PORT", "18957")
	var state_dir := ProjectSettings.globalize_path("res://.qa-artifacts/multimap-cadence-" + str(Time.get_ticks_usec()))
	OS.set_environment("TUTU_STATE_DIR", state_dir)
	Engine.max_fps=30
	Engine.physics_ticks_per_second=60
	server=load("res://server/world_server.gd").new()
	root.add_child(server)
	while not server.ready_for_players or server.maps.values().any(func(host): return not host.navigation.ready_for_paths):
		await process_frame
	print("MULTIMAP_WARM")
	server.world.state.time = 145500.0
	add_player("city",Vector3(-8,.1,9))
	await create_timer(.8).timeout
	await measure("city",6.)
	var j: GDScript=load("res://scripts/jade/layout.gd")
	add_player("jade",j.point(j.lane(147.),147.))
	await create_timer(.8).timeout
	await measure("city+jade",8.)
	add_player("icefield",Vector3(-79,6.,4))
	add_player("valley",server.maps.valley.respawn_position())
	add_player("jade",j.point(82.,-118.))
	add_player("jade",j.point(-137.,34.))
	await create_timer(1.0).timeout
	await measure(FINAL_SCENARIO, 12.)
	print("MULTIMAP_RESULT ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func add_player(map_id: String, position: Vector3) -> void:
	var i := players.size()+1
	var account := "cadence-"+str(i)
	var created: Dictionary=server.create_character(account,{"name":"步频"+str(i),"species":"bunny","starter":"bow_rose"})
	if not created.ok:
		print("MULTIMAP_SETUP_FAIL ",map_id," create")
		quit(2)
		return
	var id: String=created.character
	server.records[id].map_id=map_id
	server.records[id].player_position=[position.x,position.y,position.z]
	server.peers[i]={"account":account,"character":"","socket":WebSocketPeer.new()}
	var joined: Dictionary=server.join_world(i,id)
	server.peers.erase(i)
	if not joined.ok:
		print("MULTIMAP_SETUP_FAIL ",map_id," ",joined.message)
		quit(2)
		return
	players[id]=map_id
	sequence[id]=0
	print("MULTIMAP_JOIN ",map_id," index=",i)

func measure(label: String, seconds: float) -> void:
	var begin:=Time.get_ticks_usec()
	var last:=begin
	var physics:=Engine.get_physics_frames()
	var times: Array[float]=[]
	var buffer:=0
	var move_seen: Dictionary={}
	var last_positions: Dictionary={}
	var before:=sequence.duplicate()
	while Time.get_ticks_usec()-begin < int(seconds*1000000):
		await process_frame
		var now:=Time.get_ticks_usec()
		var elapsed: float=(now-begin)/1000000.
		var frame_gap: float=(now-last)/1000.
		times.append(frame_gap)
		last=now
		for id in players:
			var pawn: CharacterBody3D=server.pawns[id]
			var should_send:=floori(elapsed*60.) + int(before[id])
			buffer=maxi(buffer,pawn.network_queue.size())
			var axis:=1 if fposmod(elapsed,3.)<1.45 else -1
			while sequence[id]<should_send and pawn.network_queue.size()<160:
				sequence[id]+=1
				pawn.network_queue.append({"seq":sequence[id],"direction":[axis,0,0],"running":false,"jump":false})
		for host in server.maps.values():
			for npc: CharacterBody3D in host.npcs:
				var key: String=host.map_id+":"+str(npc.name)
				if npc.position.distance_squared_to(last_positions.get(key,npc.position))>.00025:
					var active: Dictionary = move_seen.get(host.map_id,{})
					active[key]=true
					move_seen[host.map_id]=active
				last_positions[key]=npc.position
	times.sort()
	var moved: Dictionary={}
	for id in move_seen:
		moved[id]=move_seen[id].size()
	var live: Dictionary={}
	for host in server.maps.values():
		live[host.map_id]=host.npcs.filter(func(npc): return npc.can_process()).size()
	var max_pending:=0
	for id in players:
		max_pending=maxi(max_pending,int(sequence[id])-int(server.pawns[id].network_ack))
	var wall: float=(last-begin)/1000000.
	var physics_hz := (Engine.get_physics_frames()-physics)/wall
	if label == FINAL_SCENARIO:
		var all_npcs_active := true
		for host in server.maps.values():
			all_npcs_active = all_npcs_active and live[host.map_id] == host.npcs.size()
		passed = all_npcs_active and moved.size() == 4 and max_pending <= 10 and physics_hz >= 58.0
	print("MULTIMAP_METRICS ",label," fps=",snappedf(times.size()/wall,.1)," hz=",snappedf(physics_hz,.1)," p95_ms=",snappedf(times[int((times.size()-1)*.95)],.1)," max_ms=",snappedf(times[-1],.1)," max_buffer=",buffer," pending=",max_pending," moving_npcs=",moved," active=",live)
	for id in players:
		server.pawns[id].network_queue.clear()
