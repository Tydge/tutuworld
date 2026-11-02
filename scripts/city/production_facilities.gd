extends RefCounted
## Stable instance IDs and local anchors keep placement, collision and use together.
static var objects: Array=[]
static var workshop: Dictionary={}
static func object_definitions() -> Array:
	if objects.is_empty(): objects=JSON.parse_string(FileAccess.get_file_as_string("res://data/production_objects.json")).objects
	return objects
static func workshop_definition() -> Dictionary:
	if workshop.is_empty(): workshop=JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/crafting_workshop.json"))
	return workshop
static func vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
static func defaults() -> Dictionary:
	var result: Dictionary={}
	for row in object_definitions():
		var transform_:=Transform3D(Basis(Vector3.UP,deg_to_rad(row.yaw)),vector(row.origin))
		result[row.id]={"kind":row.kind,"position":transform_*vector(row.anchors.ActionAnchor)}
	var house:=workshop_definition()
	for item in house.furniture:
		if not item.has("facility"): continue
		var offset:=vector(item.position)+Vector3(0,house.floor_height,0)
		var transform_:=Transform3D(Basis(Vector3.UP,deg_to_rad(item.yaw)),vector(house.origin)+offset)
		result[item.facility.id]={"kind":item.facility.kind,"position":transform_*vector(item.facility.anchors.ActionAnchor)}
	return result
static func configure(node: Node3D,row: Dictionary) -> void:
	node.set_meta("facility_id",row.id);node.set_meta("facility_kind",row.kind);node.set_meta("facility_name",row.name)
	for id in row.anchors:
		var anchor:=Marker3D.new();anchor.name=id;anchor.position=vector(row.anchors[id]);node.add_child(anchor)
static func register(host: Node3D) -> void:
	for node in host.scenery.find_children("*","Node3D",true,false):
		if node.has_meta("facility_id"):
			var id: String=node.get_meta("facility_id")
			var building: Node=node
			while building!=host.scenery and not building.has_meta("building_definition"): building=building.get_parent()
			host.targets[id]={"building":building,"kind":node.get_meta("facility_kind"),"name":node.get_meta("facility_name"),"node":node,"anchor":node.get_node("ActionAnchor"),"work_anchor":node.get_node("WorkAnchor"),"effect_anchor":node.get_node("EffectAnchor"),"position":node.get_node("ActionAnchor").global_position,"radius":2.5}
		if node.has_meta("door_id"):
			host.targets[node.get_meta("door_id")]={"kind":"home_door","node":node,"anchor":node.get_node("Door/ActionAnchor"),"position":node.door_action_position(),"radius":4.6,"name":node.get_meta("building_name","工坊")}
static func refresh(host: Node3D,authority: RefCounted=null) -> void:
	for id in host.targets:
		var row: Dictionary=host.targets[id]
		if row.has("anchor"):
			row.position=row.anchor.global_position
			if authority!=null and row.kind in ["well","workshop"]:
				authority.facility_positions[id]=Vector2(row.position.x,row.position.z)
				authority.facility_kinds[id]=row.kind
