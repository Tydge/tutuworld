extends SceneTree
## Run two production transports against an isolated, loopback-only town.
const Server = preload("res://server/world_server.gd")
const Transport = preload("res://scripts/services/remote_transport.gd")
const Court = preload("res://scripts/jade/imperial_court.gd")
const Profiles = preload("res://scripts/city/npc_profiles.gd")
const Gestures = preload("res://scripts/city/dialogue_gestures.gd")
const RELEASE = preload("res://scripts/services/release.gd")
const DAY := 3600.
const MORNING := 8. * 150.

var server: Node
var host: Node3D
var emperor: CharacterBody3D
var throne: Node3D
var court: RefCounted
var clients: Array = [null, null]
var ids: Array = ["", ""]
var received: Array = [{}, {}]
var endpoint := ""
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> bool:
	print("PASS " if ok else "FAIL ", description)
	if not ok: failures += 1
	return ok

func new_connection(index: int) -> bool:
	var client := Transport.new()
	root.add_child(client)
	clients[index] = client
	received[index].clear()
	client.message_received.connect(func(message: Dictionary):
		if message.get("type", "") == "motion":
			for row: Dictionary in message.actors:
				received[index][row.id] = row)
	if not check(await client.ensure_connected(endpoint), "Connect local client %d" % index):
		return false
	# Only account identity is a fixture. Both clients select characters,
	# travel, talk, sit, stand and receive snapshots over the normal socket.
	server.peers[server.serial].account = "palace-flow-%d" % index
	if ids[index] == "":
		var create: Dictionary = await client.request("create_character", {
			"name":"朝会验收%d" % index, "species":["bunny", "panda"][index], "starter":"bow_rose"})
		if not check(create.get("ok", false), "Create independent character %d" % index):
			return false
		ids[index] = create.character
	var join: Dictionary = await client.request("join", {"character":ids[index]})
	return check(join.get("ok", false), "Join character %d" % index)

func place(index: int, position: Vector3) -> void:
	var pawn: CharacterBody3D = server.pawns[ids[index]]
	pawn.position = position
	pawn.velocity = Vector3.ZERO
	pawn.reset_physics_interpolation()

func both_saw(resident: String, fields: Dictionary) -> bool:
	for rows: Dictionary in received:
		var row: Dictionary = rows.get(resident, {})
		if row.is_empty(): return false
		for key in fields:
			# The host omits neutral emote fields until the first gesture.
			var value: Variant = row.get(key, "" if key == "emote" else null)
			if value != fields[key]: return false
	return true

func expect_rows(resident: String, fields: Dictionary, description: String) -> void:
	server.broadcast_motion()
	var deadline := Time.get_ticks_msec() + 2500
	while not both_saw(resident, fields) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(both_saw(resident, fields), description)

func advance(elapsed: float) -> void:
	court.update(host, true, elapsed)

func sit(index: int) -> bool:
	place(index, throne.to_global(Vector3(0, .025, 1.65)))
	var result: Dictionary = await clients[index].request("sit", {"target":Court.THRONE})
	return check(result.get("ok", false), "Player %d occupies the free throne" % index)

func stand(index: int) -> void:
	var result: Dictionary = await clients[index].request("stand", {})
	check(result.get("ok", false), "Player %d can voluntarily stand" % index)
	place(index, throne.to_global(Vector3(4. + index, .025, 3.)))

func run() -> void:
	Engine.max_fps = 45
	var reserve := TCPServer.new()
	if not check(reserve.listen(0, "127.0.0.1") == OK, "Reserve an isolated game port"):
		quit(1)
		return
	var port := reserve.get_local_port()
	reserve.stop()
	OS.set_environment("TUTU_GAME_PORT", str(port))
	OS.set_environment("TUTU_STATE_DIR", ProjectSettings.globalize_path(
		"res://.qa-artifacts/palace-network-%d" % Time.get_ticks_usec()))
	endpoint = "ws://127.0.0.1:%d" % port
	server = Server.new()
	root.add_child(server)
	while not server.ready_for_players: await process_frame
	var old_client := Transport.new()
	old_client.set_meta("build", RELEASE.BUILD - 1)
	root.add_child(old_client)
	check(not await old_client.ensure_connected(endpoint) and old_client.required_version == RELEASE.VERSION,
		"A previous client gets the current version before it can join")
	old_client.close()
	old_client.queue_free()
	for i in 2:
		if not await new_connection(i):
			quit(1)
			return
	for i in 2:
		place(i, Vector3(13, .2, 41.5))
		var travel: Dictionary = await clients[i].request("travel", {"destination":"jade"})
		if not check(travel.get("ok", false), "Enter Jade via the port %d" % i):
			quit(1)
			return
	host = server.maps.jade
	var daily: Node = host.get_node("StreetLife")
	court = daily.imperial_court
	emperor = host.targets[Court.EMPEROR].node
	throne = host.targets[Court.THRONE].node
	# Move only the court schedule manually. Socket I/O, storage, collision,
	# character poses and the emote clocks still advance on the normal host.
	await create_timer(.5).timeout
	daily.set_physics_process(false)
	server.world.state.time = MORNING
	daily.update_market()
	var shopper: Node = host.targets["JadeCitizen_%d" % daily.CUSTOMERS[0]].node.get_node("NeighbourWalk")
	var market_route: Array = shopper.route.duplicate()
	var official: Node = host.targets["JadeCitizen_34"].node.get_node("NeighbourWalk")
	check(official.route.size() == 1, "The official takes a morning post")
	court.update(host, false)
	if not await sit(0):
		quit(1)
		return
	advance(.01)
	await expect_rows(Court.EMPEROR, {"court_request":ids[0], "court_stage":1}, "Both clients agree who received the first reminder")
	var first_seq := int(received[0].get(Court.EMPEROR, {}).get("court_seq", -1))
	await clients[0].request("end_talk")
	check(server.locks.get("jade:" + Court.THRONE, {}).get("owner") == ids[0] and server.pawns[ids[0]].seated,
		"A late conversation close cannot release the player's seat")
	advance(9.5)
	await expect_rows(Court.EMPEROR, {"court_seq":first_seq, "court_stage":1}, "The same reminder is not repeated before ten seconds")
	await stand(0)
	if not await sit(1):
		quit(1)
		return
	advance(.6)
	await expect_rows(Court.EMPEROR, {"court_request":ids[1], "court_stage":1}, "A replacement gets a personal first reminder")
	advance(9.0)
	await expect_rows(Court.EMPEROR, {"court_request":ids[1], "court_stage":1}, "A replacement gets their full grace period")
	advance(1.1)
	await expect_rows(Court.EMPEROR, {"court_request":ids[1], "court_stage":2, "emote":"angry"}, "Occupant and bystander both receive the second reminder and anger")
	var second_seq := int(received[1].get(Court.EMPEROR, {}).get("court_seq", -1))
	check(second_seq > first_seq, "Switching reminders advances their sequence")
	await create_timer(.3).timeout
	check(float(received[0].get(Court.EMPEROR, {}).get("emote_age", 0.)) > 0., "A bystander receives the running expression clock")
	await expect_rows(Court.EMPEROR, {"emote":"", "court_stage":2}, "Both clients return to a neutral expression after two seconds")
	clients[1].close()
	var deadline := Time.get_ticks_msec() + 4000
	while server.actors.has(ids[1]) and Time.get_ticks_msec() < deadline: await process_frame
	check(not server.locks.has("jade:" + Court.THRONE), "Disconnect releases the occupied throne")
	emperor.position = throne.to_global(Vector3(2.08, .03, 1.04))
	advance(16.)
	check(emperor.seated and throne.has_meta("resident_occupant"), "Disconnect during the second reminder lets the emperor sit")
	clients[1].queue_free()
	if not await new_connection(1):
		quit(1)
		return
	await expect_rows(Court.EMPEROR, {"court_stage":0, "court_request":""}, "Reconnect clears old summons on both clients")
	check(received[1].get(Court.EMPEROR, {}).get("pose", {}).get("kind", "") == "sit", "A reconnect sees the emperor on the throne")
	place(1, throne.to_global(Vector3(5., .025, 3.)))
	court.update(host, false)
	emperor.position = emperor.get_meta("court_post")
	if not await sit(0):
		quit(1)
		return
	advance(.01)
	advance(10.1)
	advance(14.)
	check(int(emperor.get_meta("court_stage", 0)) == 2, "The third reminder waits another fifteen seconds")
	var save_path: String = server.save_path
	server.save_path = save_path.path_join("unwritable")
	advance(1.1)
	check(int(emperor.get_meta("court_stage", 0)) == 2 and int(server.world.state.get("jade_court_dismissed_day", -1)) != 0,
		"A failed world save keeps the audience open without announcing dismissal")
	server.save_path = save_path
	advance(2.1)
	await expect_rows(Court.EMPEROR, {"court_request":ids[0], "court_stage":3}, "Both clients receive the dismissal")
	var third_seq := int(received[0].get(Court.EMPEROR, {}).get("court_seq", -1))
	daily.update_market()
	check(daily.market_period == 1 and shopper.route == market_route and official.route.size() > 1,
		"Dismissal releases the officials while the south market keeps its morning routes")
	advance(1.)
	await expect_rows(Court.EMPEROR, {"court_seq":third_seq}, "The dismissal is announced only once")
	await stand(0)
	emperor.position = throne.to_global(Vector3(2.08, .03, 1.04))
	advance(.4)
	check(not emperor.seated and not throne.has_meta("resident_occupant"), "A seat freed after dismissal stays free that morning")
	check(server.save_world(), "Save the dismissed audience")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(server.save_path))
	check(int(saved.world.get("jade_court_dismissed_day", -2)) == 0, "The dismissal belongs to the shared world and its calendar day")
	for id: String in ids:
		check(not saved.characters[id].has("jade_court_dismissed_day"), "Player records do not own the day's decision")
	# Use a fresh court and reload the world exactly as a restart would.
	server.world.state.erase("jade_court_dismissed_day")
	server.load_world()
	court = Court.new()
	advance(.4)
	check(not emperor.seated, "Reloading during the same morning preserves dismissal")
	server.world.state.time = DAY + MORNING
	daily.update_market()
	check(official.route.size() == 1, "Officials return to their posts the following morning")
	emperor.position = throne.to_global(Vector3(2.08, .03, 1.04))
	advance(.4)
	check(emperor.seated and throne.has_meta("resident_occupant"), "The next morning's audience proceeds")
	await check_dialogue()
	for client in clients:
		client.close()
		client.queue_free()
	server.listener.stop()
	server.queue_free()
	await process_frame
	await process_frame
	print("PALACE_MULTIPLAYER_FLOW failures=", failures)
	quit(1 if failures else 0)

func check_dialogue() -> void:
	var target_id := ""
	var available: Array = []
	var best_coverage := 0.
	for id: String in host.targets:
		if not id.begins_with("JadeCitizen_"): continue
		var lines: Array = Profiles.available_lines(id, 8.)
		var count := 0
		for line: String in lines:
			if Gestures.BY_LINE.has(line): count += 1
		var coverage := float(count) / maxi(1, lines.size())
		if coverage < 1. and coverage > best_coverage:
			target_id = id
			available = lines
			best_coverage = coverage
	if not check(target_id != "", "A Jade resident has a matching morning gesture"): return
	var resident: CharacterBody3D = host.targets[target_id].node
	var actor: CharacterBody3D = server.pawns[ids[0]]
	var gestures_seen := false
	var neutral_after_gesture := false
	var previous_gesture := ""
	var previous_line := ""
	# The production server randomly selects, and never repeats the last line.
	# Keep the ordinary town RNG deterministic while exercising this path.
	seed(139)
	for attempt in range(35):
		for direction: Vector3 in [Vector3.BACK, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD]:
			place(0, resident.position + direction * 1.15)
			if preload("res://scripts/city/conversation_access.gd").can_talk(host, actor, host.targets[target_id]):
				break
		var result: Dictionary = await clients[0].request("talk", {"target":target_id})
		if not check(result.get("ok", false), "Talk to a real resident on the host"): return
		var line := str(result.get("line", ""))
		check(available.has(line) and line != previous_line, "The reply matches the resident, clock and anti-repeat choice")
		previous_line = line
		var deadline := Time.get_ticks_msec() + 2500
		server.broadcast_motion()
		while received[1].get(ids[0], {}).get("pose", {}).get("line", "") != line and Time.get_ticks_msec() < deadline:
			await process_frame
		check(received[1].get(ids[0], {}).get("pose", {}).get("line", "") == line, "The bystander receives the exact line chosen for the speaker")
		var expected := str(Gestures.BY_LINE.get(line, ""))
		if expected.is_empty() and not previous_gesture.is_empty():
			neutral_after_gesture = true
			check(resident.emote.is_empty(), "A new neutral line immediately clears the previous line's expression")
		previous_gesture = expected
		await expect_rows(target_id, {"emote":expected}, "Both clients get the gesture selected for this line")
		gestures_seen = gestures_seen or expected != ""
		place(1, resident.position + Vector3.BACK * 1.5)
		var blocked: Dictionary = await clients[1].request("talk", {"target":target_id})
		check(not blocked.get("ok", true), "A second talk cannot replace the first line")
		var finish: Dictionary = await clients[0].request("end_talk")
		check(finish.get("ok", false), "Release the conversation")
		if neutral_after_gesture: break
	check(neutral_after_gesture, "A quick transition from an annotated line to a neutral one is covered")
	check(gestures_seen, "An annotated dialogue triggers its existing expression over the network")

	var counter: Node3D = host.targets.JadeVendor_silk.node
	var shop: Node3D = host.scenery.get_node("Shop_silk")
	for index in 2:
		place(index, counter.position + shop.global_basis.z * .95 + shop.global_basis.x * (.3 if index else -.3))
	var first: Dictionary = await clients[0].request("greet", {"target":"JadeVendor_silk"})
	var second: Dictionary = await clients[1].request("greet", {"target":"JadeVendor_silk"})
	check(first.get("ok", false) and second.get("ok", false) and not str(first.get("line", "")).is_empty() and first.get("line") == second.get("line"),
		"Two customers share the shopkeeper's greeting without evicting one another")
	check(not server.locks.has("jade:JadeVendor_silk"), "The merchant remains available while greeting")
	var bought: Dictionary = await clients[1].request("buy", {"shop":"silk", "item":"ruyi_lock"})
	check(bought.get("ok", false) and server.actors[ids[1]].count("ruyi_lock") == 1,
		"The second customer can buy a palace garment during the greeting")
