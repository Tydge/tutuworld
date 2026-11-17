extends Node
## Bounded material updates, independent of tree count. The shader preserves shadow views.
var city: Node3D
var materials: Array=[]
func _ready() -> void:
	var copies: Dictionary={}
	for path in ["AncientForest","WoodedRidges"]:
		var root: Node3D=city.scenery.get_node_or_null(path)
		if root==null:continue
		for node in root.find_children("*","GeometryInstance3D",true,false):
			var original: Material=node.material_override
			# Only near trees can obstruct the short camera/player corridor.
			# Far silhouettes and independent shadow casters need no per-frame writes.
			if not original is ShaderMaterial or int(original.get_shader_parameter("forest_lod"))!=1:continue
			if not copies.has(original):copies[original]=original.duplicate();materials.append(copies[original])
			node.material_override=copies[original]
	for material in materials:material.set_shader_parameter("forest_cut_enabled",true)
func _process(_delta: float) -> void:
	if not is_instance_valid(city.bunny) or not is_instance_valid(city.camera):return
	for material in materials:
		material.set_shader_parameter("forest_focus",city.bunny.global_position+Vector3.UP*1.4)
		material.set_shader_parameter("forest_view",city.camera.global_position)
