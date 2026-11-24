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

# Build position-only shadow surfaces per material culling mode.
static func append_depth(groups: Dictionary,mesh: Mesh,i: int,t: Transform3D,mode: int) -> void:
	if not groups.has(mode):
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[mode]=st
	var surface: SurfaceTool=groups[mode]
	var arrays:=mesh.surface_get_arrays(i)
	var points:=t*PackedVector3Array(arrays[Mesh.ARRAY_VERTEX])
	if arrays[Mesh.ARRAY_INDEX]==null:
		for point in points:surface.add_vertex(point)
	else:
		for index in arrays[Mesh.ARRAY_INDEX]:surface.add_vertex(points[index])

static func depth_mesh(groups: Dictionary,materials: Dictionary) -> ArrayMesh:
	var lod:=ImporterMesh.new()
	for mode in groups:
		if not materials.has(mode):
			var mat:=StandardMaterial3D.new()
			mat.cull_mode=mode
			materials[mode]=mat
		var surface: SurfaceTool=groups[mode]
		surface.index()
		lod.add_surface(Mesh.PRIMITIVE_TRIANGLES,surface.commit_to_arrays(),[],{},materials[mode])
	lod.generate_lods(55.,80.,[])
	return lod.get_mesh()

static func culling(mat: Material) -> int:
	if mat is StandardMaterial3D and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:return mat.cull_mode
	if mat is ShaderMaterial and mat.shader in [preload("res://assets/shaders/jade_silk_lantern.gdshader"),preload("res://assets/shaders/jade_window.gdshader")]:return BaseMaterial3D.CULL_BACK
	return -1

static func bake_fixed_shadows(world: Node3D) -> void:
	var cells: Dictionary={}
	var materials: Dictionary={}
	var sections: Dictionary={}
	for fixture in world.get_children():
		if fixture.has_meta("building_definition"):
			# Only geometry which follows the same cutaway switch can share one caster.
			for section in ["Front","Rear","West","East","Exterior","UpperFloor","OutsideStair"]:
				var part:=fixture.get_node_or_null(NodePath(section)) as Node3D
				if part:collect_depth(part,part,cells,materials,sections)
		elif fixture is Node3D and not fixture.get_script() and not fixture.has_meta("grove"):
			collect_depth(fixture,world,cells,materials,sections)
	for key: Vector2i in cells:
		var caster:=G.mesh(world,depth_mesh(cells[key],materials),Vector3(key.x*24.,0,key.y*24.),null,"StreetShadow")
		caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.lod_bias=.35

static func collect_depth(root: Node3D,space: Node3D,cells: Dictionary,materials: Dictionary,sections: Dictionary) -> void:
	var local_groups: Dictionary={}
	var street:=root!=space
	var pieces: Array=[]
	var candidates:=root.find_children("*","GeometryInstance3D",true,false)
	if root is GeometryInstance3D:candidates.append(root)
	for node: GeometryInstance3D in candidates:
		if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON or not node.is_visible_in_tree():continue
		if node.visibility_range_begin>0. or node.visibility_range_end>0.:continue
		var parent: Node=node
		while parent!=space and not parent.get_script():parent=parent.get_parent()
		if parent!=space:continue
		var mesh: Mesh
		var placements:=1
		if node is MeshInstance3D:
			mesh=node.mesh
		elif node is MultiMeshInstance3D and node.multimesh and not node.multimesh.use_custom_data:
			mesh=node.multimesh.mesh
			placements=node.multimesh.instance_count
		if not mesh:continue
		var modes:=PackedInt32Array()
		for i in mesh.get_surface_count():
			var mat: Material=node.get_active_material(i) if node is MeshInstance3D else mesh.surface_get_material(i)
			modes.append(culling(node.material_override if node.material_override else mat))
		if modes.has(-1):continue
		var relative:=Transform3D.IDENTITY
		parent=node
		while parent!=space:
			relative=parent.transform*relative
			parent=parent.get_parent()
		for j in placements:
			var t:=relative
			if node is MultiMeshInstance3D:t=t*node.multimesh.get_instance_transform(j)
			if street:
				var at:=t*mesh.get_aabb().get_center()
				var key:=Vector2i(floori(at.x/24.),floori(at.z/24.))
				t.origin-=Vector3(key.x*24.,0,key.y*24.)
				if not cells.has(key):cells[key]={}
				for i in modes.size():append_depth(cells[key],mesh,i,t,modes[i])
			else:pieces.append([mesh,t,modes])
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not pieces.is_empty():
		if not sections.has(pieces):
			for piece: Array in pieces:
				for i in piece[2].size():append_depth(local_groups,piece[0],i,piece[1],piece[2][i])
			sections[pieces]=depth_mesh(local_groups,materials)
		var caster:=G.mesh(space,sections[pieces],Vector3.ZERO,null,"SectionShadow")
		caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.lod_bias=.35

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
		caster.lod_bias=.35
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
		var mode:=culling(source.surface_get_material(i))
		if mode<0:return null
		append_depth(groups,source,i,Transform3D.IDENTITY,mode)
	return depth_mesh(groups,materials)
