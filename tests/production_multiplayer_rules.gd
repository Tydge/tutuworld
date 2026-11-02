extends SceneTree
const Server=preload("res://server/world_server.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
const Facilities=preload("res://scripts/city/production_facilities.gd")
const DB=preload("res://scripts/services/game_data.gd")
var server: Node
var clients: Array=[]
var ids: Array=[]
var checks:=0
var failures: Array=[]
var parallel: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func place(index: int,p: Vector3) -> void:
	var pawn=server.pawns[ids[index]];pawn.position=p;pawn.velocity=Vector3.ZERO;pawn.network_direction=Vector3.ZERO;pawn.reset_network_motion()
	server.actors[ids[index]].state.player_position=[p.x,p.y,p.z]
func request(index: int,verb: String,args: Dictionary={}) -> Dictionary: return await clients[index].request(verb,args)
func start_request(index: int,verb: String,args: Dictionary) -> void: parallel[index]=await request(index,verb,args)
func race(verb: String,args: Dictionary) -> int:
	parallel.clear();start_request(0,verb,args);start_request(1,verb,args)
	var deadline:=Time.get_ticks_msec()+15000
	while parallel.size()<2 and Time.get_ticks_msec()<deadline: await process_frame
	check(parallel.size()==2,"Concurrent station requests return")
	check(int(parallel.get(0,{}).get("ok",false))+int(parallel.get(1,{}).get("ok",false))==1,"Exactly one owner for "+verb)
	return 0 if parallel.get(0,{}).get("ok",false) else 1
func finish_jobs() -> void:
	for a in server.actors.values():
		if not a.job.is_empty(): a.job.duration=.02
	await create_timer(.18).timeout
func run() -> void:
	Engine.max_fps=60;OS.set_environment("TUTU_GAME_PORT","18903");OS.set_environment("TUTU_AUTH_PORT","18912")
	OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/production-multi-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	var deadline:=Time.get_ticks_msec()+20000
	while not server.ready_for_players and Time.get_ticks_msec()<deadline: await process_frame
	check(server.ready_for_players,"Isolated local multiplayer world starts with new modules")
	if not server.ready_for_players: quit(1);return
	var suffix:=Crypto.new().generate_random_bytes(5).hex_encode()
	for index in range(2):
		var client=Transport.new();root.add_child(client);clients.append(client)
		check(await client.ensure_connected("ws://127.0.0.1:18903"),"Local websocket connection")
		var result: Dictionary=await request(index,"register",{"username":"prod_"+suffix+str(index),"password":"test-local-production"})
		check(result.get("ok",false),"Isolated test account registered")
		result=await request(index,"create_character",{"name":"工坊"+suffix.left(4)+str(index),"species":"bunny" if index==0 else "panda","starter":"bow_rose"})
		check(result.get("ok",false),"Test character created")
		if not result.get("ok",false): quit(1);return
		ids.append(result.character);result=await request(index,"join",{"character":result.character});check(result.get("ok",false),"Test character joins")
		server.actors[ids[index]].add("watering_can",1)
	var host: Node3D=server.maps.city
	Facilities.refresh(host)
	var well: Vector3=host.targets.garden_well.work_anchor.global_position
	place(0,well+Vector3(0,0,-2));place(1,well+Vector3(0,0,2));await create_timer(.12).timeout
	var winner:=await race("refill",{"target":"garden_well"})
	check(server.actors[ids[winner]].job.get("duration",0)==2.0 and server.locks.has("city:garden_well"),"Refill is a real two-second exclusive well job")
	await finish_jobs()
	check(server.actors[ids[winner]].water_left()==6 and server.actors[ids[1-winner]].water_left()==0,"Refill water belongs only to the actual operator")
	check(not server.locks.has("city:garden_well"),"Well lock releases after success")
	var plot: Dictionary=DB.plots()[0];server.world.state.plots[plot.id].crop="carrot"
	place(winner,Vector3(plot.x,.2,plot.z+1.6));place(1-winner,Vector3(plot.x+2,.2,plot.z+1.6));await create_timer(.1).timeout
	var result: Dictionary=await request(1-winner,"water",{"target":plot.id})
	check(not result.ok,"Another player cannot use someone else's filled can")
	result=await request(winner,"water",{"target":plot.id});check(result.ok,"Owner can water the shared crop")
	await finish_jobs();check(server.actors[ids[winner]].water_left()==5 and server.care_history[plot.id].current.size()==1,"Multiplayer watering consumes one private charge and appends one care entry")
	var bench: Vector3=host.targets.workshop_bench.work_anchor.global_position
	for index in range(2):
		server.actors[ids[index]].add("copper",18);server.actors[ids[index]].add("branch",8)
		place(index,bench+Vector3(-2 if index==0 else 2,0,1.35))
	await create_timer(.12).timeout
	winner=await race("craft",{"target":"workshop_bench","recipe":"copper_watering_can"})
	check(server.actors[ids[winner]].job.get("station","")=="workshop" and server.pawns[ids[winner]].action=="gather_stone","Server chooses workshop authority / shared hammer pose")
	check(server.locks.has("city:workshop_bench") and not server.locks.has("city:kitchen"),"Workbench lock is distinct from kitchen lock")
	await finish_jobs()
	check(server.actors[ids[winner]].count("copper_watering_can")==1 and server.actors[ids[winner]].count("copper")==8 and server.actors[ids[1-winner]].count("copper")==18,"Only one owner receives tool and pays materials")
	check(server.actors[ids[winner]].state.skill_experience.manufacturing==5 and server.actors[ids[1-winner]].state.skill_experience.manufacturing==0,"Manufacturing XP is private")
	place(1-winner,Vector3(0,.2,9));place(winner,bench);await create_timer(.1).timeout
	var peer: int=server.pawns[ids[winner]].get_meta("peer_id")
	var same:={"id":"production-idempotent-axe"}
	result=server.execute_player(peer,same,"craft",{"target":"workshop_bench","recipe":"copper_axe"});check(result.ok,"Axe manufacturing starts")
	await finish_jobs()
	var before: Dictionary=server.actors[ids[winner]].state.duplicate(true)
	result=server.execute_player(peer,same,"craft",{"target":"workshop_bench","recipe":"copper_axe"})
	check(result.ok and server.actors[ids[winner]].job.is_empty() and before==server.actors[ids[winner]].state,"Replayed manufacture request cannot repeat materials, XP or output")
	var path: String=server.save_path
	server.actors[ids[winner]].state.watering_water.copper_watering_can=2
	place(winner,well);await create_timer(.1).timeout
	result=await request(winner,"refill",{"target":"garden_well"});check(result.ok,"Refill starts before failed-save probe")
	server.save_path=path.path_join("cannot-write");await finish_jobs()
	check(server.actors[ids[winner]].water_left()==2 and not server.actors[ids[winner]].job.is_empty(),"Failed server completion save rolls water back and retains job for retry")
	server.save_path=path;await create_timer(.15).timeout
	check(server.actors[ids[winner]].water_left()==12 and server.actors[ids[winner]].job.is_empty(),"Successful retry commits one copper refill")
	var well_node: Node3D=host.scenery.get_node("GardenWell");well_node.position.z+=5;Facilities.refresh(host)
	place(winner,well);server.actors[ids[winner]].state.watering_water.copper_watering_can=1;await create_timer(.1).timeout
	result=await request(winner,"refill",{"target":"garden_well"});check(not result.ok,"Server rejects old coordinates after well moves")
	place(winner,host.targets.garden_well.work_anchor.global_position);await create_timer(.1).timeout
	result=await request(winner,"refill",{"target":"garden_well"});check(result.ok,"Moved well remains usable through current anchors")
	await finish_jobs();well_node.position.z-=5;Facilities.refresh(host)
	place(winner,Vector3(34,.2,-20.0));await create_timer(.1).timeout
	result=await request(winner,"door",{"target":"workshop_door"})
	check(result.ok and host.scenery.get_node("Workshop").door_open and not host.home.door_open,"Workshop door is independent from home door")
	result=await request(winner,"door",{"target":"home_door"});check(not result.ok,"Cannot toggle distant home by standing at workshop")
	server.clock_alignment={"version":1};var epoch: float=server.epoch
	check(server.save_world(),"New character fields and workshop door persist")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.characters[ids[winner]].watering_water.copper_watering_can==12 and saved.characters[ids[winner]].skill_experience.manufacturing==10 and saved.doors.has("city:workshop_door"),"Disk retains exact water, manufacturing XP and separate door state")
	check(saved.epoch==epoch and saved.clock_alignment.version==1,"Production changes preserve world epoch and clock alignment")
	for client in clients: client.close()
	server.queue_free();await process_frame;await process_frame
	print("PRODUCTION_MULTIPLAYER_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
