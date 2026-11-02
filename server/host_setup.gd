extends RefCounted
const DB=preload("res://scripts/services/game_data.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
static func setup(host: Node3D) -> void:
	host.scenery=load("res://scenes/valley_map.scn" if host.map_id=="valley" else "res://scenes/city_map.tscn").instantiate()
	host.add_child(host.scenery)
	for node in host.scenery.find_children("*","Node3D",true,false):
		if node.get_script()==load("res://scripts/city/seabreeze_home.gd"):node.set_process(false);node.city=host
	host.home=host.scenery.get_node_or_null("ValleyHome" if host.map_id=="valley" else "SeabreezeHome")
	host.bunny=Animals.create()
	host.add_child(host.bunny)
	host.bunny.position=Vector3(0,-50,0);host.bunny.collision_layer=0;host.bunny.collision_mask=0
	host.set_meta("idle_bunny",host.bunny)
	host.navigation=preload("res://scripts/city/wander_navigation.gd").new()
	host.add_child(host.navigation)
	host.spawn_npcs()
	if host.map_id=="city":
		host.targets.home_bed={"kind":"bed","position":host.home.get_node("Furnishing/bed/ActionAnchor").global_position,"node":host.home.get_node("Furnishing/bed")}
		host.targets.home_door={"kind":"door","position":host.home.door_action_position()}
		host.targets.kitchen={"kind":"kitchen","position":host.scenery.get_node("Kitchen/PotSteam").global_position}
		host.targets.dining={"kind":"dining","position":host.scenery.get_node("DiningTable/MealAnchor").global_position}
		for plot in DB.plots():host.targets[plot.id]={"kind":"plot","position":Vector3(plot.x,0,plot.z)}
	for id in ["home_sofa","home_desk"]:
		var seat: Node3D=host.home.seat_node(id)
		host.targets[id]={"kind":"bench","position":seat.get_node("ExitAnchor").global_position,"node":seat}
	for node in host.scenery.find_children("Bench*","Node3D",true,false):
		if node.has_node("SeatAnchor"):host.targets[str(node.name)]={"kind":"bench","position":node.global_position,"node":node}
	for source in DB.resources(host.map_id):host.targets[source.id]={"kind":"resource","position":Vector3(source.x,source.get("y",0),source.z),"item":source.item}
static func update(host: Node3D) -> void:
	var closest:=INF
	var chosen: CharacterBody3D
	for pawn in host.manager.pawns.values():
		if pawn.get_parent()!=host:continue
		var distance: float=pawn.position.length_squared()
		if distance<closest:closest=distance;chosen=pawn
	host.bunny=chosen if chosen else host.get_meta("idle_bunny")
	for id in host.targets:
		var target: Dictionary=host.targets[id]
		if target.get("kind","") in ["npc","shop"] and is_instance_valid(target.get("node")):target.position=target.node.position
