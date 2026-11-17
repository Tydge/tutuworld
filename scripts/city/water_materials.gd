extends RefCounted
const NORMALS=preload("res://assets/terrain/water_ripple_normals_v1.png")
const OCEAN=preload("res://assets/shaders/island_ocean.gdshader")
const FOUNTAIN=preload("res://assets/shaders/fountain_water.gdshader")
static func apply(world: Node3D) -> void:
	var seen: Dictionary={}
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var material: Material=node.material_override
		if not material is ShaderMaterial or material.shader not in [OCEAN,FOUNTAIN] or seen.has(material):continue
		seen[material]=true;material.set_shader_parameter("ripple_normal",NORMALS)
		if material.shader==FOUNTAIN:continue
		material.set_shader_parameter("flow",Vector2(.015,.008))
		material.set_shader_parameter("ripple_strength",.45)
