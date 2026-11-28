extends SceneTree
const Server=preload("res://server/world_server.gd")
const Land=preload("res://scripts/building/parcels.gd")
const L=preload("res://scripts/building/layout.gd")
var server: Node
var ids: Array=[]
var checks:=0
var failures: Array=[]
var serial:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func place(index: int,p: Vector3) -> void:
	var pawn=server.pawns[ids[index]];pawn.position=p;pawn.velocity=Vector3.ZERO;pawn.reset_network_motion();server.actors[ids[index]].state.player_position=[p.x,p.y,p.z]
func request(index: int,verb: String,args: Dictionary={},token: String="") -> Dictionary:
	serial+=1;return server.execute_player(index+1,{"id":token if token!="" else "building-rule-%d"%serial},verb,args)
func finish(index: int,parcel: String,lease: String,rows: Array,revision: int=0,token: String="") -> Dictionary:
	return request(index,"build_finish",{"parcel_id":parcel,"lease":lease,"expected_revision":revision,"elements":rows},token)
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18918");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/building-rules-"+str(Time.get_ticks_usec())))
	server=Server.new();root.add_child(server)
	while not server.ready_for_players:await process_frame
	for npc in server.maps.city.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0
	for i in range(3):
		var account:="building-account-"+str(i)
		var result: Dictionary=server.create_character(account,{"name":"施工测试"+str(i),"species":["bunny","cat_teacher","panda"][i],"starter":"bow_rose"})
		check(result.ok,"Create isolated character "+str(i));ids.append(result.character)
		server.peers[i+1]={"account":account,"character":"","socket":WebSocketPeer.new()}
		check(server.join_world(i+1,result.character).ok,"Join shared physics map "+str(i))
	check(not request(0,"buy_land",{"parcel_id":"east_nw"}).ok,"Server rejects a purchase far from the board")
	place(0,Land.sign_position("east_nw")+Vector3(0,.1,1.6));place(1,Land.sign_position("east_nw")+Vector3(2,.1,1.5))
	check(request(0,"buy_land",{"parcel_id":"east_nw"},"purchase-once").ok,"Owner purchases land through server authority")
	check(request(0,"buy_land",{"parcel_id":"east_nw"},"purchase-once").ok and server.actors[ids[0]].state.coins==400,"Duplicate purchase token charges once")
	check(not request(1,"buy_land",{"parcel_id":"east_nw"}).ok and server.actors[ids[1]].state.coins==500,"Second player cannot buy the same parcel")
	check(not request(1,"build_begin",{"parcel_id":"east_nw"}).ok,"Nonowner cannot start construction")
	place(1,Vector3(86,.1,-4));place(2,Vector3(91,.1,-4))
	var bad_path: String=server.save_path;server.save_path=bad_path.path_join("cannot-write")
	check(not request(0,"build_begin",{"parcel_id":"east_nw"}).ok,"Failed evacuation save rejects construction")
	check(server.building.leases.is_empty() and server.pawns[ids[1]].position==Vector3(86,.1,-4) and server.pawns[ids[2]].position==Vector3(91,.1,-4),"Save failure rolls back both visitors and the lease")
	server.save_path=bad_path
	var begin:=request(0,"build_begin",{"parcel_id":"east_nw"})
	check(begin.ok and not str(begin.get("lease","")).is_empty(),"Owner gets a private construction lease")
	var lease: String=begin.get("lease","")
	check(not Land.bounds("east_nw").grow(.55).has_point(Vector2(server.pawns[ids[1]].position.x,server.pawns[ids[1]].position.z)) and not Land.bounds("east_nw").grow(.55).has_point(Vector2(server.pawns[ids[2]].position.x,server.pawns[ids[2]].position.z)),"Every visitor is moved to safe ground outside the parcel")
	check(server.pawns[ids[1]].position.distance_to(server.pawns[ids[2]].position)>1.8,"Evacuated visitors receive different safe landing positions")
	check(not server.maps.city.can_walk(Vector3(86,.1,-4)) and server.maps.city.has_node("ConstructionSites/east_nw"),"Authority blocks entering the fenced parcel")
	check(not server.pawns[ids[0]].can_move and not request(0,"sit",{"target":"home_sofa"}).ok,"Owner is stationary and cannot start other interactions while editing")
	check(not request(0,"build_begin",{"parcel_id":"east_nw"}).ok,"A second construction session cannot replace the lease")
	check(request(0,"build_ping",{"parcel_id":"east_nw","lease":lease}).ok,"Owner renews the construction lease")
	check(not request(1,"build_cancel",{"parcel_id":"east_nw","lease":lease}).ok,"Even a copied lease cannot grant another player editing rights")
	var draft:=L.add(L.empty(),{"type":"floor","a":[80.,-10.],"b":[96.,2.]})
	check(server.state().build_layout.elements.is_empty(),"Draft preparation does not change the shared map")
	check(not finish(0,"east_nw",lease,draft.elements,1).ok,"Stale parcel revision is rejected")
	check(not finish(0,"east_nw","forged",draft.elements).ok,"Forged construction token is rejected")
	var outside:=L.add(L.empty(),{"type":"floor","a":[120.,-10.],"b":[130.,0.]})
	check(not finish(0,"east_nw",lease,outside.elements).ok,"Server independently rejects rows belonging to another parcel")
	check(not finish(0,"east_nw",lease,[{"id":"invalid","type":"object","kind":{},"position":[85,0]}]).ok,"Malformed network rows return a failure instead of crashing")
	server.save_path=bad_path.path_join("cannot-write")
	check(not finish(0,"east_nw",lease,draft.elements).ok,"Publication requires a successful atomic save")
	check(server.state().build_layout.elements.is_empty() and server.building.leases.has("east_nw") and not server.pawns[ids[0]].can_move,"Failed publication keeps original map and active construction session")
	server.save_path=bad_path
	check(finish(0,"east_nw",lease,draft.elements,0,"publish-once").ok,"Confirming completion publishes the finished parcel")
	check(server.state().build_layout.elements.size()==1 and server.state().land_parcels.plots.east_nw.revision==1,"Layout and parcel revision commit together")
	check(server.building.leases.is_empty() and server.pawns[ids[0]].can_move and server.maps.city.can_walk(Vector3(86,.1,-4)),"Successful completion removes exclusion and restores movement")
	check(server.built_room!=null and not server.built_room.render_cache.is_empty(),"Published floor has real scene geometry and collision")
	check(finish(0,"east_nw",lease,draft.elements,0,"publish-once").ok and server.state().land_parcels.plots.east_nw.revision==1,"Repeated completion does not apply a second edit")
	place(1,Land.sign_position("east_ne")+Vector3(0,.1,1.7));check(request(1,"buy_land",{"parcel_id":"east_ne"}).ok,"Another player purchases a separate parcel")
	var begin_b:=request(1,"build_begin",{"parcel_id":"east_ne"});check(begin_b.ok,"Independent parcel can be under construction")
	var other_draft:=L.add(L.empty(),{"type":"floor","a":[122.,-10.],"b":[136.,2.]})
	check(finish(1,"east_ne",begin_b.get("lease",""),other_draft.elements).ok,"Conflicting temporary element IDs are merged without replacing the first owner's floor")
	check(server.state().build_layout.elements.size()==2 and L.validate(server.state().build_layout).ok,"Concurrent parcel results have unique IDs and preserve both buildings")
	place(0,Land.sign_position("east_nw")+Vector3(0,.1,1.7));begin=request(0,"build_begin",{"parcel_id":"east_nw"})
	check(request(0,"build_cancel",{"parcel_id":"east_nw","lease":begin.get("lease","")}).ok and server.state().build_layout.elements.size()==2,"Discarding a draft restores access without publishing changes")
	begin=request(0,"build_begin",{"parcel_id":"east_nw"});server.building.leases.east_nw.expires=0;server.building.expire()
	check(server.building.leases.is_empty() and server.state().build_layout.elements.size()==2,"Expired sessions reopen the parcel and keep the published map")
	begin=request(0,"build_begin",{"parcel_id":"east_nw"});server.leave_world(1)
	check(server.building.leases.is_empty() and server.state().build_layout.elements.size()==2,"Disconnect releases construction without publishing the draft")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(server.save_path))
	check(saved.world.build_layout.elements.size()==2 and saved.world.land_parcels.plots.size()==2 and not saved.world.has("building_sites"),"World save contains completed buildings and ownership, no transient leases")
	check(not JSON.stringify(saved).contains(lease),"Private construction tokens never persist through the deduplication cache")
	check(saved.characters.values().all(func(row):return not row.has("build_layout") and not row.has("land_parcels")),"Building and land state never leak into per-character saves")
	server.load_world();check(server.state().build_layout.elements.size()==2 and server.state().land_parcels.plots.size()==2,"Loading the server save preserves shared buildings and ownership")
	await furniture_checks()
	capability_checks()
	server.listener.stop();server.queue_free();await process_frame
	print("BUILDING_MULTIPLAYER_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)

func furniture_checks() -> void:
	server.set_process(false)
	check(server.join_world(1,ids[0]).ok,"Owner rejoins the saved shared world")
	place(0,Land.sign_position("east_nw")+Vector3(0,.1,1.7))
	var fixture:=L.empty()
	fixture=L.add(fixture,{"type":"floor","a":[80.,-10.],"b":[96.,2.]})
	for data in [["sofa",84.,-7.],["bed",92.,-6.],["cooking_counter",92.,-.5],["dining_table",84.,-1.],["dining_chair",83.1,-2.55]]:fixture=L.add(fixture,{"type":"object","kind":data[0],"position":[data[1],data[2]],"yaw":0.})
	var checked:=L.validate(fixture);check(checked.ok,"Furniture integration fixture obeys building rules")
	if not checked.ok:print(checked);return
	var begin:=request(0,"build_begin",{"parcel_id":"east_nw"})
	var result:=finish(0,"east_nw",begin.get("lease",""),fixture.elements,1)
	check(result.ok,"Server publishes functional furniture through the same completion transaction")
	if not result.ok:print(result);return
	await physics_frame;await physics_frame
	var targets: Dictionary={}
	for row in server.state().build_layout.elements:
		if row.type=="object":targets[row.kind]="build:"+row.id
	place(1,Vector3(83.2,.2,-4.8));result=request(1,"sit",{"target":targets.sofa})
	check(result.ok and server.pawns[ids[1]].seated,"A visitor can sit on another owner's completed sofa")
	check(request(1,"stand").ok,"Visitor safely leaves the built sofa")
	server.maps.city.home.bed_occupant=server.pawns[ids[2]]
	place(1,Vector3(89.8,.2,-6.));result=request(1,"rest",{"target":targets.bed})
	check(result.ok and server.pawns[ids[1]].sleeping and server.actors[ids[1]].state.net_pose.target==targets.bed,"Built beds use their own authoritative sleep pose")
	begin=request(0,"build_begin",{"parcel_id":"east_nw"})
	check(begin.ok and not server.pawns[ids[1]].sleeping and server.actors[ids[1]].state.net_pose.is_empty(),"Starting construction also evacuates sleeping visitors and clears their pose")
	check(not server.locks.values().any(func(lock):return lock.owner==ids[1]),"Evacuation releases the visitor's furniture lock")
	check(server.maps.city.home.bed_occupant==server.pawns[ids[2]],"Using or evacuating a built bed preserves another bed's occupant")
	server.maps.city.home.bed_occupant=null
	request(0,"build_cancel",{"parcel_id":"east_nw","lease":begin.get("lease","")})
	place(1,Vector3(83.1,.2,-4.1));server.actors[ids[1]].add("food_carrot_soup",1)
	result=request(1,"eat",{"target":targets.dining_table,"item":"food_carrot_soup","seat":"forged-chair"})
	check(result.ok and server.actors[ids[1]].job.get("seat","")!= "forged-chair" and server.actors[ids[1]].state.net_pose.has("meal_position"),"Server chooses a real paired dining chair and meal position, ignoring a forged chair")
	if result.ok:
		var checkpoint: Dictionary=server.runtime_checkpoint(ids[1])
		server.restore_runtime(ids[1],checkpoint)
		check(server.pawns[ids[1]].action=="eat" and server.actor_packet(ids[1]).job.item=="food_carrot_soup","Restoring an active meal preserves the eating pose and food for observers")
	request(1,"cancel")
	check(server.actors[ids[1]].count("food_carrot_soup")==1,"Cancelling a built-table meal keeps the food")
	var counter: Node3D=server.maps.city.targets[targets.cooking_counter].node
	place(1,counter.get_node("ActionAnchor").global_position+Vector3(0,.02,.4))
	var recipe: Dictionary=preload("res://scripts/services/game_data.gd").recipe("carrot_soup")
	for item in recipe.get("ingredients",{}):server.actors[ids[1]].add(item,int(recipe.ingredients[item]))
	result=request(1,"craft",{"target":targets.cooking_counter,"recipe":"carrot_soup"})
	if not result.ok:print("COOK_RESULT ",result)
	check(result.ok and server.actors[ids[1]].job.get("target","")==targets.cooking_counter,"Visitors can cook at the completed placed kitchen counter")
	request(1,"cancel")

func capability_checks() -> void:
	var session=preload("res://scripts/services/session.gd").new();session.transport_mode="remote_authority"
	var old:=session.state().duplicate(true);session.receive_online_snapshot({"state":old})
	var host=preload("res://scripts/city/city_world.gd").new();host.session=session
	check(not session.online_building_available and not host.has_building_world(),"An old server without the capability flag keeps construction disabled")
	check(not host.can_walk(Vector3(90,.1,-3)) and host.navigation_bounds().size.x==105,"Old-server fallback keeps the original movement envelope")
	session.receive_online_snapshot({"building_protocol":1,"state":old.duplicate(true)})
	check(session.online_building_available and host.has_building_world() and host.can_walk(Vector3(90,.1,-3)),"A capable source server enables the extended world explicitly")
	host.free();session.free()
