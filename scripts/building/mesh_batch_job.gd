extends RefCounted
## Identical batching for immediate builds and time-budgeted map updates.
const G=preload("res://scripts/geometry.gd")
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
var builder: RefCounted
var parent: Node3D
var parts: Array=[]
var batches: Array=[]
var groups: Dictionary={}
var cursor:=0
var batch_cursor:=0
var done:=false
func _init(source: RefCounted,target: Node3D) -> void:
	builder=source;parent=target;parts=parent.find_children("*","MeshInstance3D",true,false)
func advance(limit: int) -> void:
	var work:=0
	while not done and work<limit:
		work+=1
		if cursor<parts.size():
			var part: MeshInstance3D=parts[cursor];cursor+=1;append_part(part)
			if cursor==parts.size():batches=groups.values()
		elif batch_cursor<batches.size():var entry: Dictionary=batches[batch_cursor];batch_cursor+=1;append_batch(entry)
		else:done=true
func append_part(part: MeshInstance3D) -> void:
	if part.get_meta("dynamic_mesh",false): return
	var m: Material=part.material_override
	if m==null: return
	var shape: Mesh=part.mesh
	var dye:=Color.WHITE
	var pattern:=-1
	var rough:=.94
	var snow:=false
	if m is ShaderMaterial and m.shader==load("res://assets/shaders/home_surface.gdshader"):
		dye=m.get_shader_parameter("tint")
		pattern=int(m.get_shader_parameter("pattern"))
		rough=float(m.get_shader_parameter("roughness_value"))
		snow=m.get_shader_parameter("roof_snow")==true
	elif m is StandardMaterial3D and m.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not m.emission_enabled and m.roughness>.69:
		dye=m.albedo_color;pattern=0
	elif m is ShaderMaterial and m.shader==Fabric.shader_for("") and not m.get_shader_parameter("patterned"):
		dye=m.get_shader_parameter("dye");pattern=0
	if pattern>=0:
		var cache_key:=str(pattern)+str(rough)+str(snow)
		if not builder.batch_materials.has(cache_key):
			var shared:=ShaderMaterial.new();shared.shader=load("res://assets/shaders/home_surface.gdshader")
			shared.set_shader_parameter("tint",Color.WHITE);shared.set_shader_parameter("vertex_tint",true)
			shared.set_shader_parameter("pattern",pattern);shared.set_shader_parameter("roughness_value",rough)
			shared.set_shader_parameter("roof_snow",snow)
			if snow:shared.set_shader_parameter("roof_snow_texture",preload("res://assets/terrain/winter/powder_snow_v1.png"))
			builder.batch_materials[cache_key]=shared
		m=builder.batch_materials[cache_key]
		var colored:=ArrayMesh.new()
		for surface in range(shape.get_surface_count()):
			var arrays:=shape.surface_get_arrays(surface)
			var colors:=PackedColorArray();colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(dye.srgb_to_linear())
			arrays[Mesh.ARRAY_COLOR]=colors
			colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		shape=colored
	var key:=str(m.get_instance_id())+str(part.cast_shadow)
	if not groups.has(key): groups[key]={"material":m,"shadow":part.cast_shadow,"st":SurfaceTool.new()};groups[key].st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var transform_: Transform3D=parent.global_transform.affine_inverse()*part.global_transform
	# Normalize indexed primitives and unindexed bevel meshes before merging.
	# Mixing formats leaves only the first primitive referenced by the index buffer.
	var triangles:=SurfaceTool.new();triangles.create_from(shape,0);triangles.deindex()
	groups[key].st.append_from(triangles.commit(),0,transform_)
	part.get_parent().remove_child(part);part.free()
func append_batch(entry: Dictionary) -> void:
	var shape: ArrayMesh=entry.st.commit()
	if shape==null: return
	var n:=G.mesh(parent,shape,Vector3.ZERO,entry.material,"ModuleBatch");n.cast_shadow=entry.shadow
