extends SceneTree
## Independent loopback clients share one live Jade map. Only account provisioning and spawn positions are fixtures.
const Server = preload("res://server/world_server.gd")
const Transport = preload("res://scripts/services/remote_transport.gd")
const Land = preload("res://scripts/building/parcels.gd")
const Layout = preload("res://scripts/building/layout.gd")
const Templates = preload("res://scripts/building/templates.gd")
var server: Node
var clients: Array = []
var failures: Array[String] = []
var finishing := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func run() -> void:
	Engine.max_fps = 30
	var port := "18968"
	OS.set_environment("TUTU_GAME_PORT", port)
	OS.set_environment("TUTU_STATE_DIR", ProjectSettings.globalize_path("res://.qa-artifacts/builders-" + str(Time.get_ticks_usec())))
	server = Server.new()
	root.add_child(server)
	while not server.ready_for_players or server.maps.values().any(func(host): return not host.navigation.ready_for_paths):
		await process_frame
	for i in 6:
		var client := Transport.new()
		root.add_child(client)
		var account := "builder-" + str(i)
		var plot: String = Land.ids_for("jade")[i]
		var sign_pos := Land.sign_position(plot) + Vector3(0,.1,1.6)
		var who: Dictionary = server.create_character(account, {"name":"并建" + str(i), "species":"bunny", "starter":"bow_rose"})
		var id: String = who.character
		server.records[id].map_id = "jade"
		server.records[id].player_position = [sign_pos.x,sign_pos.y,sign_pos.z]
		var info := {"client":client, "plot":plot, "id":id, "npc":0, "snapshots":0, "motion":0, "latest":{}, "published":{}}
		clients.append(info)
		client.message_received.connect(func(packet): observe(info, packet))
		if not await client.ensure_connected("ws://127.0.0.1:" + port):
			quit(2);return
		server.peers[server.serial].account = account
		var joined: Dictionary = await client.request("join", {"character":id})
		var owned: Dictionary = await client.request("buy_land", {"parcel_id":plot})
		if not joined.ok or not owned.ok:
			print("SETUP ", joined, owned);quit(2);return
	for i in 6:
		var info: Dictionary = clients[i]
		var result: Dictionary = await info.client.request("build_begin", {"parcel_id":info.plot})
		if not result.ok:
			print("BEGIN ", result);quit(2);return
		info.lease = result.lease
		var draft := Layout.merge_template(Layout.empty("jade"), Templates.player_sample("jade_palace"), Land.bounds(info.plot).get_center())
		info.elements = draft.elements
		if i+1 in [1,2,6]:
			await measure(i+1)
	check(server.state().jade_build_layout.elements.is_empty(), "All six drafts are private")
	var pings := 0
	for info: Dictionary in clients:
		var ping: Dictionary = await info.client.request("build_ping", {"parcel_id":info.plot,"lease":info.lease})
		if ping.ok:pings += 1
	check(pings == 6, "All six renewals keep the correct lease")
	var publish_started := Time.get_ticks_msec()
	finishing = clients.size()
	for info: Dictionary in clients:
		publish(info)
	var deadline := Time.get_ticks_msec() + 95000
	while finishing > 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(finishing == 0 and server.building.leases.is_empty(), "Concurrent completion reopens every lot")
	var update: Dictionary=server.jade_built_room.last_sync
	check(update.created==update.modules and update.reused==0, "One geometry swap publishes all six palaces")
	print("CONCURRENT_PUBLISH elapsed_ms=",Time.get_ticks_msec()-publish_started," created=",update.created," modules=",update.modules)
	await create_timer(1.2).timeout
	var final_layout: Dictionary = server.state().jade_build_layout
	for info: Dictionary in clients:
		var rows: Array = final_layout.elements.filter(func(row): return Land.contains_row(info.plot,row,final_layout))
		check(rows.size()==info.elements.size() and rows.size()>10, "All pieces survive on " + str(info.plot))
		check(info.published.elements.size()==final_layout.elements.size() and info.latest.building_sites.is_empty(), "Owner sees every published lot")
		check(info.npc>0, "Walking view resumes resident movement")
	# Compare the geometry examined by a real drag against the shared world.
	var plot: String = clients[0].plot
	var local_layout := final_layout.duplicate()
	local_layout.elements = final_layout.elements.filter(func(row): return Land.contains_row(plot,row,final_layout))
	var edit = preload("res://scripts/building/room_edit.gd")
	var rooms = preload("res://scripts/building/room_plan.gd")
	rooms.cache.clear()
	var started := Time.get_ticks_usec()
	var whole: Dictionary = edit.prepare(final_layout, 0)
	var all_usec := Time.get_ticks_usec()-started
	rooms.cache.clear()
	started=Time.get_ticks_usec()
	var local: Dictionary = edit.prepare(local_layout, 0)
	print("CONCURRENT_DRAG_PLAN all_cells=%d own_cells=%d all_ms=%.2f own_ms=%.2f" % [whole.grid.floors.size(),local.grid.floors.size(),all_usec/1000.,(Time.get_ticks_usec()-started)/1000.])
	check(whole.grid.floors.size()==6*local.grid.floors.size() and local.plan.rooms.size()==1,"Drag inspects only the owner's palace")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(server.save_path))
	check(saved.world.jade_build_layout.elements.size() == final_layout.elements.size(), "Combined layout persisted")
	print("CONCURRENT_BUILDING_RESULT ", "PASS" if failures.is_empty() else "FAIL", " rows=", final_layout.elements.size(), " failures=",failures)
	quit(0 if failures.is_empty() else 1)

func observe(info: Dictionary, packet: Dictionary) -> void:
	if packet.type == "snapshot":
		info.snapshots += 1
		info.latest = packet.state
		if packet.state.has("jade_build_layout"):info.published = packet.state.jade_build_layout
	elif packet.type == "motion":
		info.motion += 1
		for actor in packet.actors:
			if actor.get("npc",false):info.npc += 1

func measure(count_: int) -> void:
	await create_timer(.3).timeout
	for info: Dictionary in clients:
		info.npc=0;info.snapshots=0;info.motion=0
	var gaps: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var tick := Engine.get_physics_frames()
	while Time.get_ticks_usec()-start < 3100000:
		await process_frame
		var now := Time.get_ticks_usec()
		gaps.append((now-previous)/1000.)
		previous=now
	gaps.sort()
	var hz := (Engine.get_physics_frames()-tick)*1000000./(previous-start)
	print("CONCURRENT_BUILDING_METRICS builders=%d physics_hz=%.1f frame_p95_ms=%.1f builder_npc_rows=%d builder_full_snapshots=%d player_packets=%d" % [count_,hz,gaps[floori((gaps.size()-1)*.95)],clients[0].npc,clients[0].snapshots,clients[0].motion])
	for i in clients.size():
		var info: Dictionary = clients[i]
		check(info.motion>=10,"Player presence stays live during editing")
		if i<count_:
			check(info.npc==0 and info.snapshots==0,"Quiet private editor at concurrency %d"%count_)
		else:
			check(info.npc>0 and info.snapshots>0,"Walkers continue receiving the full world")
	check(hz>=56., "Authority keeps physics cadence while editing")

func publish(info: Dictionary) -> void:
	var result: Dictionary = await info.client.request("build_finish", {"parcel_id":info.plot,"lease":info.lease,"expected_revision":0,"elements":info.elements})
	check(result.ok, "Saved " + str(info.plot) + " " + str(result.get("message","")))
	finishing -= 1
