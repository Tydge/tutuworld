extends SceneTree
const Server=preload("res://server/world_server.gd")
const A=preload("res://scripts/services/local_authority.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Seats=preload("res://scripts/city/seating.gd")
var checks:=0
var failures: Array=[]
var serial:=0
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func act(server: Node,peer: int,verb: String,target: String="") -> Dictionary:
	serial+=1;return server.execute_player(peer,{"id":"seat-"+str(serial)},verb,{"target":target})
func _initialize() -> void:call_deferred("run")
func run() -> void:
	OS.set_environment("TUTU_GAME_PORT","18907");OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/double-seat-"+str(Time.get_ticks_usec())))
	var server:=Server.new();root.add_child(server)
	while not server.ready_for_players:await physics_frame
	server.set_process(false);var host: Node3D=server.maps.city
	for map_ in server.maps.values():
		for npc in map_.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0;npc.hide()
	for i in range(3):
		var id:="test"+str(i);var a:=A.new();a.state.player_id=id;a.state.character_name=id;a.state.species=Animals.Catalog.ids()[i];server.actors[id]=a;server.peers[100+i]={"character":id}
		var pawn:=Animals.create(a.state.species);pawn.name=id;pawn.world=host;host.add_child(pawn);pawn.set_physics_process(false);pawn.position=Vector3(40,.2,20);server.pawns[id]=pawn
	var ids: Array=["home_sofa"]
	for id in host.targets:
		if str(id).begins_with("bench:"):ids.append(id)
	for kind in ["sofa","forest_settee","chair","petal_armchair"]:
		var model:=Node3D.new();host.add_child(model);model.position=Vector3(20,.18,30);preload("res://scripts/building/module_factory.gd").builder(model).build_item(model,kind)
		var id: String="built:"+kind;host.targets[id]={"kind":"bench","node":model,"position":model.get_node("ExitAnchor").global_position};ids.append(id)
	for target in ids:
		var node: Node3D=host.targets[target].node;var count_:=Seats.capacity(node)
		for i in range(3):
			var id:="test"+str(i);server.release_all(id);server.actors[id].state.net_pose={};server.pawns[id].stand_up(node.to_global(Vector3(0,.2,3.3+i*.12)))
		await physics_frame
		var first:=act(server,100,"sit",target);if not first.ok:print("SEAT_REJECT ",target," ",first)
		check(first.ok,"Single interaction automatically finds the first seat: "+target)
		var second:=act(server,101,"sit",target);check(second.ok==(count_==2),"Capacity allows the second character only on a double seat: "+target)
		check(not act(server,102,"sit",target).ok,"A third character is rejected at capacity: "+target)
		if count_==2 and first.ok and second.ok:
			check(server.actors.test0.state.net_pose.slot!=server.actors.test1.state.net_pose.slot and server.pawns.test0.position.distance_to(server.pawns.test1.position)>1.5,"Two different species occupy separate real positions: "+target)
			var stood:=act(server,100,"stand");check(stood.ok and not server.pawns.test0.seated and server.pawns.test1.seated and server.locks.has("city:"+Seats.lock_target(target,1)),"Standing finds a clear landing and preserves the other occupant: "+target)
			server.pawns.test0.stand_up(node.to_global(Vector3(0,.2,5.)))
			var previous:=server.locks.duplicate(true);var path: String=server.save_path;server.save_path=path+"/missing/save.json"
			var failed:=act(server,102,"sit",target);server.save_path=path
			check(not failed.ok and server.locks==previous and not server.pawns.test2.seated,"A failed save rolls back only the new seat claim: "+target)
			check(act(server,102,"sit",target).ok and server.actors.test2.state.net_pose.slot==0,"The next interaction automatically fills the released seat: "+target)
		for i in range(3):
			var id:="test"+str(i);server.release_all(id);server.pawns[id].stand_up(Vector3(40+i*3,.2,20));server.actors[id].state.net_pose={}
	server.peers.clear();server.listener.stop();server.queue_free();await process_frame
	print("DOUBLE_SEAT_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
