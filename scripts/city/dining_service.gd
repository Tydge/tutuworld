extends RefCounted
const D=preload("res://scripts/building/dining.gd")
const Access=preload("res://scripts/city/furniture_access.gd")
const Seats=preload("res://scripts/city/seating.gd")
static func register(editor: Node) -> void:
	var pairs:=D.links(editor.layout);var tables: Dictionary={}
	for row in editor.layout.elements:
		if row.get("kind","")!="dining_table" or not editor.room.render_cache.has(row.id):continue
		var node: Node3D=editor.room.render_cache[row.id].node;tables[row.id]=node
		node.set_meta("dining_chairs",[])
		editor.city.targets["build:"+row.id]={"kind":"dining","node":node,"position":node.global_position,"radius":3.3}
	for chair in pairs:
		if not tables.has(pairs[chair]) or not editor.room.render_cache.has(chair):continue
		var node: Node3D=editor.room.render_cache[chair].node;var chairs: Array=tables[pairs[chair]].get_meta("dining_chairs");chairs.append(node)
		editor.city.targets.erase("build:"+chair)
static func chairs(host: Node3D,id: String) -> Array:
	var node: Node3D=host.targets.get(id,{}).get("node")
	return node.get_meta("dining_chairs",[]) if is_instance_valid(node) else []
static func candidates(host: Node3D,id: String) -> Array:
	var list:=chairs(host,id).filter(func(node):return is_instance_valid(node) and Access.distance(node,host.bunny.global_position)<3.3)
	list.sort_custom(func(a,b):return a.global_position.distance_squared_to(host.bunny.global_position)<b.global_position.distance_squared_to(host.bunny.global_position))
	return list
static func proximity(host: Node3D,id: String) -> float:
	for node in candidates(host,id):
		if Access.same_room(host,node,host.bunny.global_position) and Access.reachable(host,node,host.bunny,3.3):return Access.distance(node,host.bunny.global_position)
	return INF
static func choose(host: Node3D,id: String) -> Dictionary:
	for node in candidates(host,id):
		if not Access.same_room(host,node,host.bunny.global_position) or not Access.reachable(host,node,host.bunny,3.3) or Seats.local_slot(host,node,host.bunny)<0:continue
		var exit_:=Access.landing(host,node,host.bunny,host.bunny.global_position)
		if exit_.is_empty():continue
		return {"node":node,"exit":exit_.position,"seat":str(node.name)}
	return {}
static func accessible(host: Node3D,id: String,chair: String) -> bool:
	for node in chairs(host,id):
		if str(node.name)==chair:return Access.same_room(host,node,host.bunny.global_position) and Access.reachable(host,node,host.bunny,3.3) and Seats.local_slot(host,node,host.bunny)>=0
	return false
static func meal_position(host: Node3D,id: String,chair: Node3D) -> Vector3:
	var table: Node3D=host.targets[id].node;var local:=table.to_local(chair.global_position)
	var p:=Vector2(local.x,local.z).clamp(Vector2(-1.25,-.58),Vector2(1.25,.58))
	return table.to_global(Vector3(p.x,1.15,p.y))
