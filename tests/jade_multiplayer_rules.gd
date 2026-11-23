extends SceneTree
const Server=preload("res://server/world_server.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Land=preload("res://scripts/building/parcels.gd")
const J=preload("res://scripts/jade/layout.gd")
var server: Node
var ids: Array=[]
var serial:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label_: String) -> void:
	print("PASS " if value else "FAIL ",label_)
	if not value:failures+=1
func request(i: int,verb: String,args: Dictionary,token: String="") -> Dictionary:
	serial+=1;return server.execute_player(i+1,{"id":token if token!="" else "jade-rule-%d"%serial},verb,args)
func place(i: int,p: Vector3) -> void:
	var actor: CharacterBody3D=server.pawns[ids[i]];actor.position=p;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
func finish(i: int) -> void:
	var actor: RefCounted=server.actors[ids[i]];actor.job.duration=.01;server.tick_actor(ids[i],.04)
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18954");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/jade-authority-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	while not server.ready_for_players:await process_frame
	server.set_process(false)
	check(server.maps.size()==4,"Four separate authoritative maps")
	for i in range(2):
		var account:="jade-fixture-"+str(i)
		var record: Dictionary=server.create_character(account,{"name":"玉京测试"+str(i),"species":["bunny","panda"][i],"starter":"bow_rose"});ids.append(record.character)
		server.peers[i+1]={"account":account,"character":"","socket":WebSocketPeer.new()}
		check(server.join_world(i+1,record.character).ok,"Join")
		place(i,Vector3(13,.2,41.5));check(request(i,"travel",{"destination":"jade"}).ok,"Reach Jade from harbor")
	var host: Node3D=server.maps.jade;var a: RefCounted=server.actors[ids[0]];var b: RefCounted=server.actors[ids[1]]
	var pawn: CharacterBody3D=server.pawns[ids[0]]
	place(0,Vector3(-170.3563,-2.3960,-11.8178))
	pawn.simulate_movement(1./60.,Vector3.ZERO,false,false)
	check(pawn.position.distance_to(host.respawn_position())<.1,"Authoritative pawn recovers from the reported riverbed")
	check(server.safe_position("jade",Vector3(0,-2.4,0),ids[0],pawn,Callable(),1).is_empty(),"The riverbed underneath a bridge is never a join position")
	var daily:=host.get_node("StreetLife")
	daily._physics_process(20.)
	for trade in preload("res://scripts/jade/street_life.gd").TRADES:
		var shopkeeper: CharacterBody3D=host.targets["JadeVendor_"+trade].node
		check(shopkeeper.action==preload("res://scripts/jade/street_life.gd").TRADES[trade],"Authoritative profession pose "+trade)
	for actor in [a,b]:
		for skill in actor.state.skills:actor.state.skills[skill]=8;actor.state.skill_experience[skill]=1800
	var public_stove: Dictionary=host.targets.jade_steamer
	var bun_recipe:=DB.recipe("honey_wheat_cake")
	place(0,public_stove.anchor.global_position)
	for mat in bun_recipe.ingredients:a.add(mat,bun_recipe.ingredients[mat])
	var bake:=request(0,"craft",{"target":"jade_steamer","recipe":"honey_wheat_cake"})
	check(bake.ok,"Use the public steamer at the tea shop "+str(bake.message))
	if bake.ok:finish(0)
	for offer in [["almond","almond_biscuit"],["spice","sweet_osmanthus"]]:
		var counter: Node3D=host.targets["JadeVendor_"+offer[0]].node
		place(0,counter.position+Vector3(.17,0,.12))
		var sale:=request(0,"buy",{"shop":offer[0],"item":offer[1],"quantity":1})
		check(sale.ok and a.count(offer[1])==1,"Buy a local refreshment at "+offer[0])
	var shop: Vector2=J.shops().farm;place(0,J.point(shop.x,shop.y)+Vector3(0,.11,.9))
	check(request(0,"buy",{"shop":"farm","item":"seed_cotton","quantity":1}).ok,"Buy cotton seed from real merchant")
	var plot: Dictionary=DB.plots("jade")[0];var field:=J.point(plot.x,plot.z)
	place(0,field);var plant:=request(0,"plant",{"target":plot.id,"item":"seed_cotton"});check(plant.ok,"First neighbour sows cotton")
	if plant.ok:finish(0)
	b.add("watering_can",1);place(1,host.targets.jade_well.position)
	var refill:=request(1,"refill",{"target":"jade_well"});check(refill.ok,"Second neighbour refills at the shared well")
	if refill.ok:finish(1)
	place(1,field+Vector3(.6,0,.6));var water:=request(1,"water",{"target":plot.id});check(water.ok,"Second neighbour waters the same crop")
	if water.ok:finish(1)
	check(server.world.state.plots[plot.id].water_stage>=0,"Shared plot keeps the second character's care")
	var merch: Node3D=host.targets.JadeVendor_furniture.node
	place(0,merch.position+Vector3(0,0,1.1))
	check(request(0,"buy",{"shop":"furniture","item":"jade_screen","quantity":2}).ok and a.count("jade_screen")==2,"Buy two screens into personal storage")
	check(not request(0,"buy",{"shop":"furniture","item":"jade_chime","quantity":1}).ok,"Handmade chimes unavailable for sale")
	place(0,Land.sign_position(J.LOTS[0])+Vector3.UP*.05)
	check(request(0,"buy_land",{"parcel_id":J.LOTS[0]}).ok,"Buy jade parcel")
	var begin:=request(0,"build_begin",{"parcel_id":J.LOTS[0]});check(begin.ok,"Start owned parcel lease")
	if begin.ok:
		a.add("cedar",2);a.add("silver_ore",3);a.add("copper",2)
		var made:=request(0,"make_furniture",{"parcel_id":J.LOTS[0],"item":"jade_chime"},"make-once")
		check(made.ok and a.count("jade_chime")==1 and a.count("cedar")==0,"Workshop-exclusive chime crafted in Build mode")
		request(0,"make_furniture",{"parcel_id":J.LOTS[0],"item":"jade_chime"},"make-once")
		check(a.count("jade_chime")==1,"Retry leaves exactly one finished piece")
		var row:={"id":"build_1","type":"object","kind":"jade_chime","position":[80,92],"yaw":0,"storey":0}
		var publish:={"parcel_id":J.LOTS[0],"lease":begin.lease,"expected_revision":begin.parcel_revision,"elements":[row]}
		var other:=row.duplicate();other.id="build_2";other.position=[85,92]
		check(not request(0,"build_finish",publish.merged({"elements":[row,other]},true)).ok and a.count("jade_chime")==1,"Publishing two from one is refused atomically")
		check(request(0,"build_finish",publish).ok and a.count("jade_chime")==0 and server.world.state.jade_build_layout.elements.size()==1,"Publish consumes exactly one chime")
		var second:=request(0,"build_begin",{"parcel_id":J.LOTS[0]})
		if second.ok:check(request(0,"build_finish",{"parcel_id":J.LOTS[0],"lease":second.lease,"expected_revision":second.parcel_revision,"elements":[]}).ok and a.count("jade_chime")==1,"Taking it back restores one chime")
		var private_lease:=request(0,"build_begin",{"parcel_id":J.LOTS[0]})
		if private_lease.ok:
			var stations: Array=[]
			for entry in [["build_2","jade_well_kit",79],["build_3","jade_workbench",86],["build_4","jade_steam_table",74]]:
				stations.append({"id":entry[0],"kind":entry[1],"type":"object","position":[entry[2],94],"yaw":0,"storey":0})
			var result:=request(0,"build_finish",{"parcel_id":J.LOTS[0],"lease":private_lease.lease,"expected_revision":private_lease.parcel_revision,"elements":stations})
			check(result.ok,"Build a working well and workbench on the same lot "+str(result.message))
			if result.ok:
				a.add("watering_can",1);a.add("cotton",2)
				for entry in [["build:build_2","refill"],["build:build_3","craft"]]:
					check(host.targets.has(entry[0]),"Register private "+entry[1]+" target")
					if not host.targets.has(entry[0]):continue
					place(0,host.targets[entry[0]].anchor.global_position)
					var job:=request(0,entry[1],{"target":entry[0],"recipe":"cotton_cloth"})
					check(job.ok,"Use private "+entry[1]+" station "+str(job.message))
					if job.ok:finish(0)
				check(a.count("cotton_cloth")==1,"Weave cloth at the home workbench")
				place(0,host.targets["build:build_4"].anchor.global_position)
				var before: int=a.count(bun_recipe.output)
				for mat in bun_recipe.ingredients:a.add(mat,bun_recipe.ingredients[mat])
				var steamed:=request(0,"craft",{"target":"build:build_4","recipe":"honey_wheat_cake"})
				check(steamed.ok,"Cook a meal with a privately built steamer "+str(steamed.message))
				if steamed.ok:finish(0)
				check(a.count(bun_recipe.output)>before,"Home cooking reaches the backpack")
		check(b.count("jade_chime")==0,"Other neighbour's warehouse stays personal")
	var bench: Dictionary=host.targets.jade_workshop
	place(0,bench.position)
	for tool in ["forged_axe","forged_pick","forged_hammer"]:
		for mat in DB.recipe(tool).ingredients:a.add(mat,DB.recipe(tool).ingredients[mat])
		var craft:=request(0,"craft",{"target":"jade_workshop","recipe":tool});check(craft.ok,"Forge "+tool+" "+str(craft.message))
		if craft.ok:finish(0)
	for item in ["cedar","silver_ore","nephrite"]:
		var source: Dictionary=DB.resources("jade").filter(func(r):return r.item==item)[0];place(0,J.point(source.x,source.z))
		var gather:=request(0,"gather",{"target":source.id});check(gather.ok,"Gather "+item+" with forged tool")
		if gather.ok:finish(0)
	place(0,bench.position);a.add("cotton",8);a.add("ramie",8)
	for cloth in ["cotton_cloth","ramie_cloth"]:
		for i in range(3):
			var weave:=request(0,"craft",{"target":"jade_workshop","recipe":cloth});check(weave.ok,"Weave repeatable cloth")
			if weave.ok:finish(0)
	var garment:=request(0,"craft",{"target":"jade_workshop","recipe":"night_moth"})
	check(garment.ok,"Cut a rare garment using woven cloth")
	if garment.ok:finish(0)
	check(a.count("night_moth")==1 and request(0,"equip",{"item":"night_moth","slot":"head"}).ok,"Wear the newly made headpiece")
	var oil: Dictionary=host.targets["jade:oil:Trade"]
	var task:={"target":"jade:oil:Trade","moves":[0,2]}
	var purse: int=a.state.coins
	check(not request(0,"jade_visit",task).ok,"Oil press refuses a distant result")
	place(0,oil.position)
	check(not request(0,"jade_visit",{"target":task.target,"moves":[0]}).ok,"A partial weighing earns no seal")
	check(request(0,"jade_visit",task,"oil-receipt").ok,"The host accepts the completed weighing")
	request(0,"jade_visit",task,"oil-receipt");request(0,"jade_visit",task)
	check(a.state.coins==purse+6 and a.state.jade_visits.marks==["oil"] and b.state.jade_visits.marks.is_empty(),"One personal seal and one reward after retries")
	place(0,host.targets["jade:hostel:Trade"].position)
	check(request(0,"jade_visit",{"target":"jade:hostel:Trade"}).ok,"Collect a letter at the inn")
	check(not request(0,"jade_visit",{"target":"jade:hostel:Trade"}).ok,"Letters need to cross town")
	check(server.save_world(),"Persist the character journal")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(server.save_path))
	check(saved.characters[ids[0]].jade_visits==a.state.jade_visits and saved.characters[ids[1]].jade_visits==b.state.jade_visits,"Saved journals keep each character's parcel and seal")
	# Publishing several drafts starts asynchronous clearance updates in the host.
	for tick in range(3):await physics_frame
	for world in server.maps.values():
		while not world.navigation.ready_for_paths or not world.navigation.sampling_ready:await physics_frame
	print("JADE_MULTIPLAYER_RULES failures=",failures)
	server.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
