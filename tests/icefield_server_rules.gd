extends SceneTree
const Server=preload("res://server/world_server.gd")
const L=preload("res://scripts/icefield/icefield_layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Trail=preload("res://scripts/icefield/snow_trail.gd")
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
func winter_playground(actor: RefCounted) -> void:
	var host: Node3D=server.maps.icefield
	var rack: Dictionary=host.targets.get("shop_clothing_rack",{})
	check(not rack.is_empty(),"Snow tailor exposes its walk-up display")
	if not rack.is_empty():
		var design:={"pattern":"tartan","color":"719684","accent":"ebc996"}
		var dye:={"target":"shop_clothing_rack","item":"bow_rose","design":design}
		place(0,Vector3(40,.84,40))
		check(not request(0,"tailor",dye).ok,"Remote dye request is rejected")
		place(0,rack.position+Vector3(.55,.04,0))
		check(not request(0,"tailor",dye.merged({"item":"duffle_berry"},true)).ok,"Cannot dye someone else's or an unowned garment")
		check(request(0,"tailor",dye).ok and server.actor_packet(ids[0]).clothing_designs.get("bow_rose")==design,"Customized worn fabric is sent to other clients")
	for id in Trail.LODGE_BEDS:
		var bed: Node3D=host.targets.get(id,{}).get("node")
		check(is_instance_valid(bed),"Authority recognizes lodge bed "+id)
		if not is_instance_valid(bed):continue
		place(0,bed.to_global(Vector3(-1.9 if bed.position.x>0. else 1.9,.035,0)))
		var slept:=request(0,"rest",{"target":id})
		check(slept.ok and actor.state.net_pose.get("target","")==id,"Server lies down on the inn bed "+id+" "+str(slept.message))
		if slept.ok:check(request(0,"wake",{}).ok and not server.locks.has("icefield:"+id),"Server wakes safely and releases the inn bed")
	var parcel:="ice_south_1";var sign:=Land.sign_position(parcel)
	place(0,sign+Vector3(0,.035,-1.5))
	check(not request(0,"buy_land",{"parcel_id":"east_nw"}).ok,"Rejects a city purchase while on the icefield")
	check(request(0,"buy_land",{"parcel_id":parcel}).ok,"Purchases an ice lot at its sign")
	var point:=Land.bounds(parcel).get_center()
	place(2,Vector3(point.x,L.ICE_LEVEL+.04,point.y))
	for frame in range(3):await physics_frame
	var opening:=request(0,"build_begin",{"parcel_id":parcel})
	check(opening.ok,"Icefield lot enters a real construction lease "+str(opening.message))
	if opening.ok:
		var visitor: Vector3=server.pawns[ids[2]].position
		check(Land.distance_to(parcel,visitor)>1.,"Visitor is evacuated outside the icefield site")
		var plan:=Layout.add(Layout.empty("icefield"),{"type":"floor","a":[point.x-3.,point.y-3.],"b":[point.x+3.,point.y+3.],"style":"wood","color":"c6a373"})
		var published:=request(0,"build_finish",{"parcel_id":parcel,"lease":opening.lease,"expected_revision":0,"elements":plan.elements})
		check(published.ok and server.state().icefield_build_layout.elements.size()==1 and server.state().build_layout.elements.is_empty(),"Publish keeps icefield and city layouts independent")
		check(is_equal_approx(server.icefield_built_room.global_position.y,L.ICE_LEVEL),"Server builds using the same ice grade")
	var stamps: Array=Trail.STAMPS.keys()
	for mark in stamps:
		var target: String="snow_stamp:"+mark
		var stamp: Dictionary=host.targets.get(target,{})
		if stamp.is_empty():check(false,"Stamp loaded: "+mark);continue
		place(0,stamp.position+Vector3(0,.045,.6))
		check(request(0,"stamp",{"target":target}).ok,"Server records the physical stamp "+mark)
		check(not request(0,"stamp",{"target":target}).ok,"A stamp cannot be duplicated "+mark)
	var facilities: Dictionary={}
	for id in host.targets:
		var kind: String=host.targets[id].kind
		if str(id).begins_with("winter:") and kind in ["atlas","bakery","tea","hearth"] and (kind!="tea" or str(id).begins_with("winter:home_c:")):facilities[kind]=id
	for kind in ["atlas","bakery","tea","hearth"]:
		check(facilities.has(kind),"Indoor station exists on the authoritative map: "+kind)
	if facilities.has("atlas"):
		place(0,host.targets[facilities.atlas].position+Vector3(0,.05,.33))
		var before: int=actor.state.coins
		check(request(0,"claim_trail",{"target":facilities.atlas}).ok and actor.state.coins==before+36,"Atlas trades collected marks for a one-time reward")
		check(not request(0,"claim_trail",{"target":facilities.atlas}).ok,"The trail reward cannot be farmed repeatedly")
	if facilities.has("tea"):
		place(0,host.targets[facilities.tea].position+Vector3(1.55,-.69,.10))
		actor.add("branch",1)
		var brewed:=request(0,"brew_tea",{"target":facilities.tea})
		check(brewed.ok,"Tea can be brewed at a real tea table "+str(brewed.message))
		if brewed.ok:
			actor.job.duration=.02
			server.tick_actor(ids[0],.1)
			check(actor.state.food_effect.item==Trail.TEA and is_equal_approx(actor.multiplier("stamina_regen"),1.5),"Tea changes stamina recovery on the authority")
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18947");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/icefield-authority-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	while not server.ready_for_players or not server.maps.icefield.navigation.ready_for_paths:await process_frame
	server.set_process(false) # Fixture sockets are in-memory, not connected peers.
	check(server.maps.size()==3 and server.maps.icefield.npcs.size()==10,"Authority loads three independent collision worlds and new residents")
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
	var outfit:={"head":"pompom_cap_frost"}
	check(not request(0,"dress_resident",{"target":"SnowBaker","outfit":outfit}).ok,"Cannot dress a resident remotely")
	var tailor: Node3D=server.maps.icefield.targets.FrostMerchant_clothes.node
	place(0,tailor.position+Vector3(0,0,2.05))
	check(not request(0,"dress_resident",{"target":"SnowBaker","outfit":outfit}).ok,"A fitting requires ownership")
	check(request(0,"buy",{"shop":"clothes","item":"pompom_cap_frost"}).ok,"Buy the winter garment at the snow tailor")
	var actor_worn: Dictionary=actor.state.equipment.duplicate()
	var fitting:={"target":"SnowBaker","outfit":outfit}
	check(request(0,"dress_resident",fitting,"baker-cap").ok and request(0,"dress_resident",fitting,"baker-cap").ok,"Repeated fitting is idempotent")
	check(server.state().winter_outfits.SnowBaker==outfit and server.maps.icefield.targets.SnowBaker.node.get_meta("equipment").head==outfit.head and actor.state.equipment==actor_worn,"Authoritative resident and player wear independent outfits")
	var path: String=server.save_path
	server.save_path=path.path_join("invalid")
	check(not request(0,"dress_resident",{"target":"SnowBaker","outfit":{}}).ok and server.state().winter_outfits.SnowBaker==outfit and server.maps.icefield.targets.SnowBaker.node.get_meta("equipment").head==outfit.head,"Failed save preserves previous visible and durable outfit")
	server.save_path=path
	await winter_playground(actor)
	server.broadcast_motion();check(server.actor_packet(ids[0]).map=="icefield","New map participates in motion packets")
	place(0,Vector3(L.DOCK.x,L.DOCK_HEIGHT+.035,L.DOCK.y));var coins: int=actor.state.coins
	check(request(0,"travel",{"destination":"city"}).ok and actor.state.coins==coins,"Authority returns for free")
	place(0,Vector3(13,.2,41.5));var original: String=server.save_path;server.save_path=original.path_join("invalid")
	check(not request(0,"travel",{"destination":"icefield"}).ok and actor.state.map_id=="city" and actor.state.coins==coins and pawn.get_parent()==server.maps.city,"Failed durable save rolls back world transfer and fare")
	server.save_path=original;check(server.save_world(),"Isolated server snapshot saves")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original));check(saved.characters[ids[1]].map_id=="icefield" and saved.characters[ids[2]].species=="panda","Offline records retain new map and species")
	check(saved.world.winter_outfits.SnowBaker==outfit,"Shared outfits survive a server save")
	check(saved.world.icefield_build_layout.elements.size()==1 and saved.characters[ids[0]].snow_trail.claimed,"Winter buildings and trail stamps survive server save")
	server.listener.stop();server.queue_free();await process_frame
	print("ICEFIELD_SERVER_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
