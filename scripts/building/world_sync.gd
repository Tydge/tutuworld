extends RefCounted
## Shared scene geometry and interaction registration for clients and authority.
static func apply(city: Node3D,layout: Dictionary,room: Node3D,comfort_enabled: bool=true) -> Node3D:
	var factory=preload("res://scripts/building/module_factory.gd")
	if is_instance_valid(room):factory.sync(room,layout,city)
	else:room=factory.make(layout,city)
	register(city,layout,room,comfort_enabled)
	return room
static func register(city: Node3D,layout: Dictionary,room: Node3D,comfort_enabled: bool=true) -> void:
	city.interiors=city.interiors.filter(func(r):return is_instance_valid(r) and not r.has_meta("player_prefab"))
	for id in city.targets.keys():
		if str(id).begins_with("build:"):city.targets.erase(id)
	if is_instance_valid(room):
		if not city.interiors.has(room):city.interiors.append(room)
		room.update_lighting(city.ambient_day)
		for door in room.get_node("Doors").get_children():
			if not door.has_method("door_action_position"):continue
			city.targets["build:"+str(door.name)]={"kind":"home_door","name":"我的小屋","node":door,"anchor":door.get_node("ActionAnchor"),"position":door.door_action_position(),"radius":3.8}
		for module in room.get_node("Furnishing").get_children():
			if module.get_meta("furniture_kind","") in ["jade_street_gallery","jade_street_gallery_reverse","jade_gate"]:
				var crossing:=module.get_node_or_null("Carpentry") as Node3D
				if crossing:crossing.set("city",city);crossing.set_process(comfort_enabled)
			if module.get_meta("furniture_kind","") in preload("res://scripts/jade/prefabs.gd").KINDS:
				var shell:=module.get_node_or_null("Carpentry") as Node3D
				if shell:
					shell.set("city",city);shell.set_meta("player_prefab",true);shell.set_process(comfort_enabled);city.interiors.append(shell)
			preload("res://scripts/city/room_activities.gd").register(city,"build:"+str(module.name),module)
			if module.has_node("WorkAnchor"):
				var fixture: Array={"jade_well_kit":["well","辘轳水井"],"jade_workbench":["workshop","百工案"]}.get(module.get_meta("furniture_kind",""),["kitchen","青瓷料理台"])
				city.targets["build:"+str(module.name)]={"kind":fixture[0],"node":module,"name":fixture[1],"anchor":module.get_node("ActionAnchor"),"work_anchor":module.get_node("WorkAnchor"),"effect_anchor":module.get_node("EffectAnchor"),"position":module.get_node("ActionAnchor").global_position,"radius":2.6}
			if module.has_node("SeatAnchor") and module.has_node("ExitAnchor"):city.targets["build:"+str(module.name)]={"kind":"bench","node":module,"position":module.global_position,"radius":1.65,"label":"坐下来休息一会"}
			if module.has_node("SleepExit"):
				city.targets["build:"+str(module.name)]={"kind":"bed","node":module,"position":module.global_position,"radius":1.65}
				if comfort_enabled:preload("res://scripts/building/bed_comfort.gd").attach(module,city,"build:"+str(module.name))
		preload("res://scripts/city/dining_service.gd").register_world(city,layout,room)
