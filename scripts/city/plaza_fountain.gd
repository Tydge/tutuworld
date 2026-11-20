extends RefCounted
## The plaza and the furniture catalog instantiate the same model and local-space effects.
const MODEL:=preload("res://scenes/coastal/plaza_fountain.tscn")

static func build(parent: Node3D, point:=Vector3.ZERO, _bake:=true) -> Node3D:
	var fountain:=MODEL.instantiate() as Node3D
	fountain.position=point
	for part in fountain.get_children():
		if part is MeshInstance3D and part.has_meta("appearance_part"):
			part.material_override=part.mesh.surface_get_material(0)
	parent.add_child(fountain)
	return fountain

static func install(park: Node3D) -> void:
	var old:=park.get_node("Fountain") as Node3D
	if old.scene_file_path==MODEL.resource_path:return
	var pose:=old.transform
	park.remove_child(old)
	old.free()
	var fountain:=build(park)
	fountain.transform=pose
