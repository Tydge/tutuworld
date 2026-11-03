extends RefCounted
## Shared surface assets; geometry, movement and game state stay independent.
const EARTH=preload("res://assets/terrain/packed_earth_path_v1.png")
const SOIL=preload("res://assets/terrain/cultivated_soil_v1.png")
const PAVING=preload("res://assets/terrain/village_stone_paving_v1.png")
const SOIL_SHADER=preload("res://assets/shaders/farm_soil.gdshader")
const PAVING_SHADER=preload("res://assets/shaders/paving.gdshader")
const FOREST_SHADER=preload("res://assets/shaders/forest_floor.gdshader")
static func apply(world: Node3D) -> void:
	if world.get_meta("terrain_material_revision",0)>=1: return
	var materials: Dictionary={}
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var original: Material=node.material_override
		if original==null: continue
		var kind:=""
		if original is ShaderMaterial:
			if original.shader==PAVING_SHADER: kind="paving"
			elif original.shader==SOIL_SHADER: kind="cultivated" if original.get_shader_parameter("soil_texture")==SOIL else "earth"
			elif original.shader==FOREST_SHADER: kind="forest"
		elif original is StandardMaterial3D and original.vertex_color_use_as_albedo and original.albedo_color.is_equal_approx(Color("805330")):
			kind="cultivated"
		if kind=="": continue
		var id:=original.get_instance_id()
		if not materials.has(id):
			var material: ShaderMaterial
			if kind=="cultivated" and original is StandardMaterial3D:
				material=ShaderMaterial.new();material.shader=SOIL_SHADER
				material.set_shader_parameter("soil_color",original.albedo_color)
				material.set_shader_parameter("vertex_tint",true)
				material.set_shader_parameter("detail_strength",.48)
			else: material=original.duplicate()
			if kind=="paving": material.set_shader_parameter("paving_texture",PAVING)
			elif kind=="forest": material.set_shader_parameter("path_texture",EARTH)
			else:
				material.set_shader_parameter("soil_texture",SOIL if kind=="cultivated" else EARTH)
				material.set_shader_parameter("texture_mean",Vector3(.185,.064,.0215) if kind=="cultivated" else Vector3(.644,.309,.086))
			material.set_meta("terrain_kind",kind)
			materials[id]=material
		node.material_override=materials[id]
	world.set_meta("terrain_material_revision",1)
