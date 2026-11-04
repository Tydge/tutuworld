extends RefCounted
## Shared physical checks for prompts, conversations and authoritative trades.
static func can_talk(host: Node3D,actor: CharacterBody3D,target: Dictionary) -> bool:
	var other: Node3D=target.get("node")
	if not is_instance_valid(other):return false
	if actor.global_position.distance_to(other.global_position)>float(target.get("radius",3.3))+.15:return false
	if target.get("kind","")=="shop":
		var shop: Node3D=host.scenery.get_node_or_null("Shop_"+str(target.get("shop","")))
		if not is_instance_valid(shop) or not shop.contains_position(actor.global_position):return false
	var excluded: Array[RID]=[actor.get_rid()]
	if other is CollisionObject3D:excluded.append(other.get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.15,other.global_position+Vector3.UP*1.15,5,excluded)
	return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
static func can_trade(host: Node3D,actor: CharacterBody3D,shop: String) -> bool:
	for target in host.targets.values():
		if target.get("kind","")=="shop" and target.get("shop","")==shop:return can_talk(host,actor,target)
	return false
