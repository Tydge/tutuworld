extends RefCounted
const DB=preload("res://scripts/services/game_data.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
static func setup(host: Node3D) -> void:
	host.scenery=load(preload("res://scripts/services/map_routes.gd").scenery(host.map_id)).instantiate()
	host.add_child(host.scenery)
	if host.map_id=="city":
		preload("res://scripts/city/town_shore.gd").ensure(host.scenery)
		preload("res://scripts/building/site.gd").ensure(host.scenery)
	for node in host.scenery.find_children("*","Node3D",true,false):
		if node.get_script()==load("res://scripts/city/seabreeze_home.gd"):node.set_process(false);node.city=host;host.interiors.append(node)
	host.home=host.scenery.get_node_or_null("ValleyHome" if host.map_id=="valley" else "SeabreezeHome")
	host.bunny=Animals.create()
	host.add_child(host.bunny)
	host.bunny.set_physics_process(false)
	host.bunny.position=Vector3(0,-50,0);host.bunny.collision_layer=0;host.bunny.collision_mask=0
	host.set_meta("idle_bunny",host.bunny)
	host.navigation=preload("res://scripts/city/wander_navigation.gd").new()
	host.add_child(host.navigation)
	if host.map_id=="icefield":
		preload("res://scripts/building/site.gd").build_winter(host.scenery)
		host.register_winter_rooms(false)
	preload("res://scripts/city/room_activities.gd").outfit_shop(host)
	if host.map_id=="jade":host.register_city(false)
	host.spawn_npcs()
	for npc in host.npcs:
		npc.server_resident = true
	set_resident_simulation(host, false)
	if host.map_id=="city":
		host.targets.home_bed={"kind":"bed","position":host.home.get_node("Furnishing/bed/ActionAnchor").global_position,"node":host.home.get_node("Furnishing/bed")}
		host.targets.home_door={"kind":"door","position":host.home.door_action_position(),"node":host.home}
		host.targets.kitchen={"kind":"kitchen","position":host.scenery.get_node("Kitchen/PotSteam").global_position}
		host.targets.dining={"kind":"dining","position":host.scenery.get_node("DiningTable/MealAnchor").global_position}
		for plot in DB.plots():host.targets[plot.id]={"kind":"plot","position":Vector3(plot.x,0,plot.z)}
	for id in ["home_sofa","home_desk"]:
		if not is_instance_valid(host.home):continue
		var seat: Node3D=host.home.seat_node(id)
		preload("res://scripts/city/seating.gd").ensure(seat,2 if id=="home_sofa" else 1)
		host.targets[id]={"kind":"bench","position":seat.get_node("ExitAnchor").global_position,"node":seat}
	preload("res://scripts/city/production_facilities.gd").register(host)
	preload("res://scripts/city/interaction_targets.gd").add_benches(host)
	for source in DB.resources(host.map_id):host.targets[source.id]={"kind":"resource","position":Vector3(source.x,source.get("y",0),source.z),"item":source.item}
static func update(host: Node3D) -> void:
	var closest := INF
	var chosen: CharacterBody3D
	for pawn in host.manager.pawns.values():
		if pawn.get_parent() != host:
			continue
		var distance: float = pawn.position.length_squared()
		if distance < closest:
			closest = distance
			chosen = pawn
	var has_players := chosen != null
	if has_players != bool(host.get_meta("has_visitors", false)):
		set_resident_simulation(host, has_players)
		host.set_meta("has_visitors", has_players)
	host.bunny = chosen if chosen else host.get_meta("idle_bunny")
	if not has_players:
		return

	preload("res://scripts/city/production_facilities.gd").refresh(host)
	for id in host.targets:
		var target: Dictionary = host.targets[id]
		if target.get("kind", "") in ["npc", "shop"] and is_instance_valid(target.get("node")):
			target.position = target.node.position

static func set_resident_simulation(host: Node3D, enabled: bool) -> void:
	# The server still keeps buildings, reservations and NPC colliders available
	# for arrivals even when the map has no one to observe its residents.
	var street_life := host.get_node_or_null("StreetLife")
	if street_life != null:
		street_life.set_physics_process(enabled)
	for npc: CharacterBody3D in host.npcs:
		var paused: bool = npc.has_meta("server_resident_mode")
		if enabled and paused:
			var previous_mode: Node.ProcessMode = npc.get_meta("server_resident_mode")
			npc.remove_meta("server_resident_mode")
			npc.process_mode = previous_mode
		elif not enabled and not paused and npc.process_mode != Node.PROCESS_MODE_DISABLED:
			npc.set_meta("server_resident_mode", npc.process_mode)
			npc.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			npc.velocity = Vector3.ZERO
			npc.walking = false
			npc.process_mode = Node.PROCESS_MODE_DISABLED
