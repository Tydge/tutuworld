extends RefCounted
## The shipped town can render opaque, matte wood trims of different colours in one draw.
## Only the baked map uses these meshes. Editable copies retain the original material boundaries.
const G=preload("res://scripts/geometry.gd")
const Architecture=preload("res://scripts/jade/architecture.gd")

static func bake(world: Node3D) -> void:
	var pigments: Dictionary={}
	for material: StandardMaterial3D in G.palette.values():
		if not is_equal_approx(material.roughness,.85) or material.emission_enabled or material.metallic>0. or material.albedo_texture!=null:
			continue
		if material.albedo_color.a==1. and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK:
			pigments[material]=material.albedo_color
	var matte:=StandardMaterial3D.new()
	matte.roughness=.85;matte.vertex_color_use_as_albedo=true;matte.vertex_color_is_srgb=true
	var replacements: Dictionary={}
	var saved:=0
	for source: ArrayMesh in Architecture.baked.values():
		if replacements.has(source):continue
		var surfaces: Array[int]=[]
		for i in range(source.get_surface_count()):
			if pigments.has(source.surface_get_material(i)):surfaces.append(i)
		if surfaces.size()<3:continue
		var compact:=ArrayMesh.new()
		var joined:=SurfaceTool.new();joined.begin(Mesh.PRIMITIVE_TRIANGLES);joined.set_material(matte)
		for i in range(source.get_surface_count()):
			var material:=source.surface_get_material(i)
			var arrays:=source.surface_get_arrays(i)
			if not pigments.has(material):
				compact.add_surface_from_arrays(source.surface_get_primitive_type(i),arrays)
				compact.surface_set_material(compact.get_surface_count()-1,material)
				continue
			var colours:=PackedColorArray();colours.resize(arrays[Mesh.ARRAY_VERTEX].size());colours.fill(pigments[material])
			arrays[Mesh.ARRAY_COLOR]=colours
			var part:=ArrayMesh.new();part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			G.append_indexed(joined,part,0,Transform3D.IDENTITY)
		joined.commit(compact)
		replacements[source]=compact
		saved+=surfaces.size()-1
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.material_override==null and replacements.has(node.mesh):
			node.mesh=replacements[node.mesh]
	print("JADE_STATIC_COLOURS templates=",replacements.size()," merged_surfaces=",saved)
