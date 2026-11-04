extends RefCounted
## Interaction follows the furniture footprint; exits never search across walls.
const Catalog=preload("res://scripts/building/catalog.gd")
const Landing=preload("res://scripts/city/local_landing.gd")
const REACH:=1.65
const BED_HALF:=Vector2(1.3,2.17)
static func bed_distance(point: Vector2) -> float:
	return (point.abs()-BED_HALF).max(Vector2.ZERO).length()
static func bounds(node: Node3D) -> Rect2:
	if node.has_node("SleepExit"):return Rect2(-BED_HALF,BED_HALF*2.)
	var anchor: Vector3=node.get_node("SeatAnchor").position
	var kind:=str(node.get_meta("furniture_kind",node.get_meta("module_type","")))
	var size_: Vector2=Catalog.OBJECTS.get(kind,{}).get("size",Vector2(3.5,1.6) if int(node.get_meta("seat_capacity",1))==2 else Vector2(1.1,1.1))
	if kind=="desk":size_=Vector2(1.1,1.1)
	return Rect2(Vector2(anchor.x,anchor.z)-size_*.5,size_)
static func closest(node: Node3D,point: Vector3) -> Vector3:
	var p:=node.to_local(point);var area:=bounds(node);var q:=Vector2(p.x,p.z).clamp(area.position,area.end)
	return node.to_global(Vector3(q.x,.65,q.y))
static func distance(node: Node3D,point: Vector3) -> float:
	if absf(point.y-node.global_position.y)>1.7:return INF
	var q:=closest(node,point);return Vector2(point.x-q.x,point.z-q.z).length()
static func excluded(node: Node3D,actor: CharacterBody3D) -> Array[RID]:
	var ids: Array[RID]=[actor.get_rid()]
	for body in node.find_children("*","CollisionObject3D",true,false):ids.append(body.get_rid())
	return ids
static func clear_segment(host: Node3D,node: Node3D,actor: CharacterBody3D,from: Vector3,to: Vector3) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(from,to,5,excluded(node,actor))
	return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
static func reachable(host: Node3D,node: Node3D,actor: CharacterBody3D,reach: float=REACH) -> bool:
	return distance(node,actor.global_position)<=reach and clear_segment(host,node,actor,actor.global_position+Vector3.UP,closest(node,actor.global_position))
static func same_room(host: Node3D,node: Node3D,point: Vector3) -> bool:
	for room in host.interiors:
		if not is_instance_valid(room) or not room.contains_position(node.global_position):continue
		if not room.contains_position(point):return false
		if "plan" in room:
			var rooms=preload("res://scripts/building/room_plan.gd")
			return rooms.room_at(room.plan,Vector2(node.global_position.x,node.global_position.z))==rooms.room_at(room.plan,Vector2(point.x,point.z))
	return true
static func landing(host: Node3D,node: Node3D,actor: CharacterBody3D,preferred: Vector3) -> Dictionary:
	var area:=bounds(node);var center:=area.get_center();var margin: float=maxf(.65,actor.rig_profile.head_radii.x+.13)
	var edge:=area.grow(margin);var candidates: Array[Vector3]=[]
	for p in [Vector2(center.x,edge.end.y),Vector2(edge.position.x,center.y),Vector2(edge.end.x,center.y),Vector2(center.x,edge.position.y),edge.position,edge.end,Vector2(edge.position.x,edge.end.y),Vector2(edge.end.x,edge.position.y)]:candidates.append(node.to_global(Vector3(p.x,.02,p.y)))
	candidates.sort_custom(func(a,b):return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
	if preferred.is_finite() and distance(node,preferred)<3.0:candidates.push_front(preferred)
	var origin:=node.to_global(Vector3(center.x,1.35,center.y))
	for p in candidates:
		if not same_room(host,node,p) or not clear_segment(host,node,actor,origin,p+Vector3.UP*1.35):continue
		var result:=Landing.find(host,p,actor,false)
		if not result.is_empty():return result
	return {}
