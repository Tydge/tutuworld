extends RefCounted
## Install only the orchard model on either map. Existing ground collision and resource IDs belong to the map.
const OLIVE := preload("res://scenes/coastal/olive.res")

static func install(tree: Node3D, fruit: bool) -> void:
	if tree.has_node("OrchardTree"):return
	var crown: Node3D=tree.get_node("Crown")
	for part in tree.find_children("*","GeometryInstance3D",true,false):
		part.get_parent().remove_child(part)
		part.free()
	var model:=preload("res://scenes/coastal/orchard_tree.tscn").instantiate()
	var size_: Vector2=tree.get_meta("fruit_crown_size",Vector2(1.65,1.5))
	var width:=clampf(size_.x/1.65,.90,1.15)
	model.scale=Vector3(width,clampf(crown.position.y/3.65,.82,1.16),width)
	model.rotation.y=fposmod(tree.position.x*.71+tree.position.z*.38,TAU)
	tree.add_child(model)
	if fruit:
		preload("res://scripts/city/coastal/fruit_spurs.gd").attach(crown,model)
	else:
		model.get_node("WoodAndLeaves").mesh=OLIVE
		model.get_node("LeafShadows").mesh=preload("res://scenes/coastal/olive_shadow.res")
