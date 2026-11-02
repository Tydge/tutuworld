extends SceneTree
const Server=preload("res://server/world_server.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Calendar=preload("res://scripts/services/island_calendar.gd")
var server: Node
var clients: Array=[]
var ids: Array=[]
var checks:=0
var failures: Array=[]
var parallel: Dictionary={}
var chats: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label_: String) -> void:
	checks+=1
	if not value:failures.append(label_);print("FAIL ",label_)
func wait(seconds: float=.12) -> void:await create_timer(seconds).timeout
func place(index: int,p: Vector3) -> void:
	var pawn=server.pawns[ids[index]];pawn.position=p;pawn.velocity=Vector3.ZERO;pawn.network_direction=Vector3.ZERO
	server.actors[ids[index]].state.player_position=[p.x,p.y,p.z]
func park() -> void:
	for i in range(ids.size()):place(i,Vector3(-20+i*3,.2,20))
func start_request(client: Node,verb: String,args: Dictionary,key: String) -> void:
	parallel[key]=await client.request(verb,args)
func race(verb: String,args: Dictionary) -> Dictionary:
	parallel.clear();start_request(clients[0],verb,args,"a");start_request(clients[1],verb,args,"b")
	var start:=Time.get_ticks_msec()
	while parallel.size()<2 and Time.get_ticks_msec()-start<20000:await process_frame
	check(parallel.size()==2,"Both concurrent requests answered: "+verb)
	check(int(parallel.get("a",{}).get("ok",false))+int(parallel.get("b",{}).get("ok",false))==1,"Exactly one owner: "+verb)
	return parallel.duplicate(true)
func finish_jobs() -> void:
	for id in server.actors:
		if not server.actors[id].job.is_empty():server.actors[id].job.duration=.04
	await wait(.2)
func request(index: int,verb: String,args: Dictionary={}) -> Dictionary:return await clients[index].request(verb,args)
func run() -> void:
	Engine.max_fps=45
	OS.set_environment("TUTU_GAME_PORT","18893")
	OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/多人开发/rules-state-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	var start:=Time.get_ticks_msec()
	while not server.ready_for_players and Time.get_ticks_msec()-start<30000:await process_frame
	check(server.ready_for_players,"Server starts with both physics maps")
	if not server.ready_for_players:quit(1);return
	var invalid=Transport.new();invalid.set_meta("build",2);root.add_child(invalid)
	check(not await invalid.ensure_connected("ws://127.0.0.1:18893") and invalid.required_version=="0.3.0","Old build rejected before account login")
	invalid.close();invalid.queue_free()
	var suffix:=Crypto.new().generate_random_bytes(5).hex_encode()
	for i in range(5):
		var client=Transport.new();root.add_child(client);clients.append(client)
		client.message_received.connect(func(message: Dictionary):
			if message.get("type","")=="chat":chats.append(message))
		check(await client.ensure_connected("ws://127.0.0.1:18893"),"Connect "+str(i))
		var result: Dictionary=await client.request("register",{"username":"qa_"+suffix+str(i),"password":"test-island-123"})
		check(result.get("ok",false) and result.get("token","")!="","Register and receive session "+str(i))
		result=await client.request("create_character",{"name":"联机验收"+suffix.left(4)+str(i),"species":["bunny","cat_teacher","panda"][i%3],"starter":"bow_rose"})
		check(result.get("ok",false),"Create character "+str(i))
		if not result.get("ok",false):print(result);quit(1);return
		ids.append(result.character)
		result=await client.request("join",{"character":result.character})
		check(result.get("ok",false),"Join "+str(i))
		var actor=server.actors[ids[i]]
		check(actor.state.coins==500 and actor.state.inventory=={"bow_rose":1},"500 coins, no seeds, one starter "+str(i))
	await wait(.2)
	for a in range(5):
		for b in range(a):
			check(server.pawns[ids[a]].position.distance_to(server.pawns[ids[b]].position)>1.65,"Same saved spawn gets separate safe space")
	var result: Dictionary=await request(1,"join",{"character":ids[0]})
	check(not result.ok,"Cannot enter another account's character")
	var time_before: float=server.state().time
	result=await request(0,"set_testing_time",{"hour":12,"minute":0})
	check(not result.ok and server.state().time-time_before<2,"Client cannot change world clock")
	var old_position: Vector3=server.pawns[ids[0]].position
	clients[0].send({"type":"motion","direction":[0,0,0],"position":[999,999,999],"running":false})
	await wait()
	check(server.pawns[ids[0]].position.distance_to(old_position)<1,"Client position is not authoritative")
	var path: String=server.save_path
	server.save_path=path.path_join("cannot-write-here")
	result=await request(0,"equip",{"slot":"head","item":""})
	check(not result.ok and server.actors[ids[0]].state.equipment.head=="bow_rose","Failed commit rolls back equipment and result cache")
	server.save_path=path
	result=await request(0,"chat",{"text":"你好，小岛！🍊🐰✨"})
	await wait()
	check(result.ok and chats.size()==5 and chats[0].text=="你好，小岛！🍊🐰✨","Emoji and Chinese broadcast to five players without history")
	park()
	var plot: Dictionary=DB.plots()[0];var point:=Vector3(plot.x,.2,plot.z)
	for i in range(2):
		var actor=server.actors[ids[i]];actor.add("seed_carrot",1);actor.add("watering_can",1);actor.add("herbicide",1)
		place(i,point+Vector3(-1.1 if i==0 else 1.1,0,0))
	await wait()
	await race("plant",{"target":plot.id,"item":"seed_carrot"})
	await finish_jobs()
	check(server.state().plots[plot.id].crop=="carrot","One shared crop planted")
	check(server.actors[ids[0]].count("seed_carrot")+server.actors[ids[1]].count("seed_carrot")==1,"Only one seed consumed")
	check(not server.locks.has("city:"+plot.id),"Plant lock released")
	await race("water",{"target":plot.id})
	await finish_jobs()
	check(server.care_history[plot.id].current.size()==2,"Shared care history records successful plant and water only")
	server.state().plots[plot.id].growth=float(DB.crop("carrot").days)*3600/3+.01
	result=await request(1,"weed",{"target":plot.id})
	check(result.ok,"Another player can weed public crop")
	await finish_jobs()
	check(server.care_history[plot.id].current[-1].player==ids[1],"Care history records actual operator")
	server.state().plots[plot.id].growth=float(DB.crop("carrot").days)*3600
	var expected: int=server.actors[ids[0]].crop_yield(server.state().plots[plot.id])
	await race("harvest",{"target":plot.id})
	await finish_jobs()
	check(server.state().plots[plot.id].crop=="","Shared harvest clears crop")
	check(server.actors[ids[0]].count("carrot")+server.actors[ids[1]].count("carrot")==expected,"Harvest credited exactly once")
	check(server.care_history[plot.id].current.size()==4,"Harvest recorded with care history")
	result=await request(0,"history",{"target":plot.id})
	check(result.ok and result.history.current.size()==4,"Care history available through real network request")
	var seed_count: int=server.actors[ids[0]].count("seed_pumpkin")
	server.actors[ids[0]].add("seed_pumpkin",1)
	result=await request(0,"plant",{"target":plot.id,"item":"seed_pumpkin"})
	check(not result.ok and server.actors[ids[0]].count("seed_pumpkin")==seed_count+1,"Skill requirement still enforced in public farm")
	park()
	var source: Dictionary={}
	for row in DB.resources("city"):
		if row.item=="branch":source=row;break
	point=Vector3(source.x,source.get("y",0)+.2,source.z)
	place(0,point+Vector3(-1.1,0,0));place(1,point+Vector3(1.1,0,0));await wait()
	await race("gather",{"target":source.id})
	server.save_path=path.path_join("cannot-write-here")
	await finish_jobs()
	check(server.state().resources[source.id].available and server.actors[ids[0]].count("branch")+server.actors[ids[1]].count("branch")==0,"Failed job commit does not award or consume shared resource")
	server.save_path=path
	await finish_jobs()
	check(not server.state().resources[source.id].available,"Resource consumed once")
	var gathered: int=server.actors[ids[0]].count("branch")+server.actors[ids[1]].count("branch")
	check(gathered in [1,2],"Gather produces one reward or one crit reward")
	var actor=server.actors[ids[0]]
	var seen: Array=actor.seen_commands.keys()
	if not seen.is_empty():
		clients[0].send({"type":"request","id":seen[-1],"verb":"gather","args":{"target":source.id}});await wait()
		check(actor.count("branch")+server.actors[ids[1]].count("branch")==gathered and not server.locks.has("city:"+source.id),"Duplicate request cannot re-award or re-lock node")
	park()
	var host=server.maps.city
	var bed_exit: Vector3=host.home.get_node("Furnishing/bed/SleepExit").global_position
	place(0,bed_exit);await wait()
	result=await request(0,"rest",{"target":"home_bed"})
	check(result.ok,"First player can use bed")
	place(1,bed_exit);await wait()
	result=await request(1,"rest",{"target":"home_bed"})
	check(not result.ok,"Second player cannot use occupied bed")
	result=await request(0,"wake")
	check(result.ok and server.pawns[ids[0]].position.distance_to(server.pawns[ids[1]].position)>1.65,"Wake finds different point when exit occupied")
	check(not server.locks.has("city:home_bed"),"Wake releases bed")
	park()
	var meal: String=DB.recipe(DB.catalog().recipes.keys()[0]).output
	point=host.targets.dining.position
	for i in range(2):
		server.actors[ids[i]].add(meal,1);place(i,point+Vector3(-2.4 if i==0 else 2.4,0,0))
	await wait()
	await race("eat",{"target":"dining","item":meal})
	await finish_jobs()
	check(not server.locks.has("city:dining"),"Dining seat is exclusive and released after meal")
	check(server.actors[ids[0]].count(meal)+server.actors[ids[1]].count(meal)==1,"Exactly one dish eaten")
	park()
	var valley_arrival: Array=preload("res://scripts/valley/valley_layout.gd").arrival("valley")
	var dock: Vector2=preload("res://scripts/valley/valley_layout.gd").dock("city")
	for i in range(2):place(i,Vector3(dock.x+i*2,.2,dock.y))
	await wait()
	var before_coins: int=server.actors[ids[0]].state.coins
	start_request(clients[0],"travel",{"destination":"valley"},"trip_a");start_request(clients[1],"travel",{"destination":"valley"},"trip_b")
	start=Time.get_ticks_msec()
	while not parallel.has("trip_a") or not parallel.has("trip_b"):
		if Time.get_ticks_msec()-start>20000:break
		await process_frame
	check(parallel.get("trip_a",{}).get("ok",false) and parallel.get("trip_b",{}).get("ok",false),"Two players can travel independently")
	check(server.actors[ids[0]].state.coins==before_coins-10,"Boat fare charged once")
	check(server.pawns[ids[0]].position.distance_to(server.pawns[ids[1]].position)>1.65,"Shared boat arrival reserves separate points")
	var before_time: float=server.state().time
	for client in clients:await client.request("leave")
	await wait(.25)
	check(server.actors.is_empty() and server.locks.is_empty(),"Leaving clears avatars and all locks")
	check(server.state().time>before_time,"World advances with no players")
	var resource: Dictionary=server.state().resources[source.id]
	var remaining: float=float(resource.respawn_at)-float(server.state().time)
	check(server.align_clock_to_hours(),"One-time hourly clock alignment succeeds")
	check(absf(fposmod(server.epoch,3600))<.00001,"Reality whole hours map to game midnight")
	check(absf((float(resource.respawn_at)-float(server.state().time))-remaining)<.01,"Alignment preserves resource cooldown remaining time")
	check(not server.align_clock_to_hours(),"Restart or repeated request cannot realign a second time")
	var epoch: float=server.epoch
	check(server.save_world(),"World checkpoint saved")
	var reload_server=Server.new();reload_server.save_path=server.save_path;reload_server.load_world()
	check(reload_server.epoch==epoch,"Epoch survives loading without rounding")
	check(reload_server.clock_alignment.get("version",0)==1,"Clock alignment marker survives loading")
	check(reload_server.care_history[plot.id].current.size()==4,"Care history survives loading")
	reload_server.free()
	check(Calendar.parts(59*3600).month==3 and Calendar.parts(59*3600).day==1,"February always has 28 days")
	check(Calendar.parts(365*3600).year==2 and Calendar.parts(365*3600).month==1 and Calendar.parts(365*3600).day==1,"365-day year rolls over")
	for client in clients:client.close()
	server.listener.stop();server.queue_free()
	print("MULTIPLAYER_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
