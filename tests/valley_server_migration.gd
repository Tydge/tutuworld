extends SceneTree
const Server=preload("res://server/world_server.gd")
const A=preload("res://scripts/services/local_authority.gd")
const L=preload("res://scripts/valley/valley_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var server=Server.new();server.save_path=preload("res://tests/test_support.gd").output_dir()+"/legacy-world.json"
	server.epoch=1793584800.;server.clock_alignment={"version":1,"aligned_at":1793584800.,"shift":17.}
	var expected: Dictionary={}
	for species in ["bunny","cat_teacher","panda"]:
		for old in [Vector3(-8,.1,32),Vector3(22,4.2,-31),Vector3(12,4.2,-36),Vector3(-5.8,.18,47.2)]:
			var id:="migration_"+str(expected.size());var a=A.new()
			a.state.merge({"player_id":id,"account_id":"migration-account","species":species,"map_id":"valley","player_position":[old.x,old.y,old.z],"coins":378,"inventory":{"copper_axe":1,"branch":23},"experience":42},true)
			a.state.skill_experience.mining=73;server.records[id]=a.state.duplicate(true)
			expected[id]=L.legacy_position(old)
	var city=A.new();city.state.player_position=[88.,5.2,-4.];server.records.city=city.state.duplicate(true)
	var high=A.new();high.state.map_id="valley";high.state.valley_landscape_revision=L.REVISION
	var x:=-78.;var z:=L.ascent_path_z(x);high.state.player_position=[x,L.walk_height(x,z)+.035,z];server.records.high=high.state.duplicate(true)
	var source: Dictionary=JSON.parse_string(JSON.stringify(server.records))
	check(server.save_world(),"Legacy fixture saves through the real atomic server writer")
	var db=preload("res://scripts/services/game_data.gd")
	var ice_resources: Array=db.resources("icefield")
	var old_resource: String=db.resources("valley")[0].id
	var old_state: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(server.save_path))
	for resource in ice_resources:old_state.world.resources.erase(resource.id)
	var stored_resource:={"available":false,"respawn_at":1250.,"generation":3}
	old_state.world.resources[old_resource]=stored_resource
	var fixture:=FileAccess.open(server.save_path,FileAccess.WRITE)
	fixture.store_string(JSON.stringify(old_state));fixture.close()
	server.load_world()
	var restored_resource: Dictionary=server.state().resources.get(old_resource,{})
	check(not restored_resource.get("available",true) and restored_resource.get("respawn_at")==1250. and int(restored_resource.get("generation",-1))==3,"Existing resource cooldown and generation are preserved")
	var new_resources_ready:=true
	for resource in ice_resources:
		if server.state().resources.get(resource.id,{})!={"available":true,"respawn_at":0.,"generation":0}:new_resources_ready=false
	check(new_resources_ready,"Legacy world receives all icefield resources")
	for id in expected:
		var record: Dictionary=server.records[id]
		check(server.vector_from(record.player_position).is_equal_approx(expected[id]) and record.valley_landscape_revision==L.REVISION,"Server migrates old valley position "+id)
		var retained:=true
		for key in ["player_id","account_id","species","coins","inventory","equipment","experience","attributes","skills","skill_experience","stamina","watering_water"]:
			if record[key]!=source[id][key]:retained=false
		check(retained,"Migration preserves identity, assets, species and progression "+id)
	check(server.records.city.player_position==source.city.player_position and server.records.city.valley_landscape_revision==L.REVISION,"City coordinates stay unchanged but receive the revision marker")
	check(server.vector_from(server.records.high.player_position).is_equal_approx(server.vector_from(source.high.player_position)),"Current high valley save is never scaled again")
	var once:=JSON.stringify(server.records)
	check(server.save_world(),"Migrated records persist successfully")
	server.load_world();check(JSON.parse_string(JSON.stringify(server.records))==JSON.parse_string(once),"Restart is idempotent for every character")
	check(server.epoch==1793584800. and server.clock_alignment=={"version":1.,"aligned_at":1793584800.,"shift":17.},"World epoch and existing clock alignment stay unchanged")
	var created: Dictionary=server.create_character("new-account",{"name":"新版谷客","species":"panda","starter":"bow_rose"})
	check(created.ok and server.records[created.character].valley_landscape_revision==L.REVISION,"New online characters start with the current landscape revision")
	server.records[created.character].map_id="valley";server.records[created.character].player_position=L.arrival("valley")
	server.save_world();server.load_world()
	check(server.vector_from(server.records[created.character].player_position).is_equal_approx(server.vector_from(L.arrival("valley"))),"A new character's first valley visit survives a restart without legacy scaling")
	server.free()
	print("VALLEY_SERVER_MIGRATION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
