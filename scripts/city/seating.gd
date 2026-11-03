extends RefCounted
## One interaction target, with independent occupancy per physical seat.
static func ensure(node: Node3D,capacity: int=1) -> void:
	if not node.has_node("SeatAnchor"):return
	node.set_meta("seat_capacity",capacity)
	for index in range(capacity):
		var id:="SeatSlot%d"%index
		if node.has_node(NodePath(id)):continue
		var anchor:=Marker3D.new();anchor.name=id;anchor.transform=node.get_node("SeatAnchor").transform
		if capacity==2:anchor.position.x=(-.82 if index==0 else .82)
		node.add_child(anchor)
static func capacity(node: Node3D) -> int:return int(node.get_meta("seat_capacity",1))
static func seat(node: Node3D,index: int=0) -> Transform3D:
	var anchor:=node.get_node_or_null("SeatSlot%d"%clampi(index,0,capacity(node)-1))
	return (anchor if anchor!=null else node.get_node("SeatAnchor")).global_transform
static func exit_position(node: Node3D,index: int=0) -> Vector3:
	var point: Vector3=node.get_node("ExitAnchor").position
	if capacity(node)==2:point.x=-.82 if index==0 else .82
	return node.to_global(point)
static func lock_target(target: String,index: int) -> String:return target if index==0 else target+":seat:"+str(index)
static func local_slot(host: Node3D,node: Node3D,actor: CharacterBody3D) -> int:
	for index in range(capacity(node)):
		var point:=seat(node,index).origin;var clear:=true
		for other in host.find_children("*","CharacterBody3D",true,false):
			if other==actor or not other.visible or other.collision_layer==0:continue
			var distance:=Vector2(other.global_position.x-point.x,other.global_position.z-point.z).length()
			var radius: float=maxf(.4,actor.rig_profile.head_radii.x)+maxf(.4,other.rig_profile.head_radii.x)+.06 if "rig_profile" in other else 1.6
			if absf(other.global_position.y-point.y)<2.4 and distance<radius:clear=false;break
		if clear:return index
	return -1
