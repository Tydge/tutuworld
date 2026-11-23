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

# A cutaway section still controls its own shadow. Opaque pigments share the
# same depth pass, with the original triangle positions and face culling.
static func bake_shadow_sections(world: Node3D) -> void:
	var templates: Dictionary={}
	var materials: Dictionary={}
	var count:=0
	for node: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON or node.material_override!=null:continue
		var source: ArrayMesh
		if node is MeshInstance3D:
			if node.get_surface_override_material_count()>0:
				var has_override:=false
				for i in range(node.get_surface_override_material_count()):
					if node.get_surface_override_material(i)!=null:has_override=true;break
				if has_override:continue
			source=node.mesh as ArrayMesh
		elif node is MultiMeshInstance3D and node.multimesh:
			source=node.multimesh.mesh as ArrayMesh
		if source==null or source.get_surface_count()<3:continue
		if not templates.has(source):templates[source]=opaque_shadow(source,materials)
		var shadow: ArrayMesh=templates[source]
		if shadow==null:continue
		var caster: GeometryInstance3D
		if node is MultiMeshInstance3D:
			var batch:=MultiMeshInstance3D.new()
			batch.multimesh=node.multimesh.duplicate(false)
			batch.multimesh.mesh=shadow
			caster=batch
		else:
			var piece:=MeshInstance3D.new()
			piece.mesh=shadow
			caster=piece
		caster.name="OpaqueShadow"
		caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.layers=node.layers
		caster.visibility_range_begin=node.visibility_range_begin
		caster.visibility_range_end=node.visibility_range_end
		caster.visibility_range_begin_margin=node.visibility_range_begin_margin
		caster.visibility_range_end_margin=node.visibility_range_end_margin
		caster.visibility_range_fade_mode=node.visibility_range_fade_mode
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(caster)
		count+=1
	print("JADE_SHADOW_SECTIONS ",count)

static func opaque_shadow(source: ArrayMesh,materials: Dictionary) -> ArrayMesh:
	var groups: Dictionary={}
	for i in range(source.get_surface_count()):
		var mat:=source.surface_get_material(i)
		var mode:=BaseMaterial3D.CULL_BACK
		if mat is StandardMaterial3D and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
			mode=mat.cull_mode
		elif mat is ShaderMaterial and mat.shader in [preload("res://assets/shaders/jade_silk_lantern.gdshader"),preload("res://assets/shaders/jade_window.gdshader")]:
			mode=BaseMaterial3D.CULL_BACK
		else:return null
		if not groups.has(mode):
			var group:=SurfaceTool.new();group.begin(Mesh.PRIMITIVE_TRIANGLES);groups[mode]=group
		var surface: SurfaceTool=groups[mode]
		var arrays:=source.surface_get_arrays(i)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for p in points:surface.add_vertex(p)
		else:
			for index in indices:surface.add_vertex(points[index])
	var levels:=ImporterMesh.new()
	for mode in groups:
		if not materials.has(mode):
			var mat:=StandardMaterial3D.new();mat.cull_mode=mode;materials[mode]=mat
		var surface: SurfaceTool=groups[mode]
		surface.index()
		levels.add_surface(Mesh.PRIMITIVE_TRIANGLES,surface.commit_to_arrays(),[],{},materials[mode])
	levels.generate_lods(55.,80.,[])
	return levels.get_mesh()
