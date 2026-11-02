extends RefCounted
## Container and seat order distinguish even anonymous/repeated prop names.
static func add_benches(host: Node3D) -> void:
	for container_name in ["CentralPark","SouthBeach"]:
		var container: Node3D=host.scenery.get_node_or_null(container_name)
		if container==null:continue
		var index:=0
		for node in container.get_children():
			if not node is Node3D or not node.has_node("SeatAnchor") or not node.has_node("ExitAnchor"):continue
			var id:="bench:%s:%d"%[container_name,index];index+=1
			host.targets[id]={"kind":"bench","position":node.global_position,"radius":2.4,"node":node}
