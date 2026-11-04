extends RefCounted
## Batched bevelled treads and rails, without hundreds of temporary mesh nodes.
const HOME=preload("res://assets/shaders/home_surface.gdshader")
var groups: Dictionary={}
var shapes: Dictionary={}
var builder: RefCounted
func _init(owner_: RefCounted) -> void:builder=owner_
func add(shape: Mesh,pose: Transform3D,material: Material) -> void:
	var pattern: int=material.get_shader_parameter("pattern");var rough: float=material.get_shader_parameter("roughness_value");var tint: Color=material.get_shader_parameter("tint");tint=tint.srgb_to_linear();var key:=str(pattern)+":"+str(rough)
	if not groups.has(key):groups[key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array(),"pattern":pattern,"roughness":rough}
	var group: Dictionary=groups[key];var arrays:=shape.surface_get_arrays(0);var offset: int=group.vertices.size();var normals:=pose.basis.inverse().transposed()
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		group.vertices.append(pose*arrays[Mesh.ARRAY_VERTEX][i]);group.normals.append((normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized());group.uv.append(arrays[Mesh.ARRAY_TEX_UV][i]);group.colors.append(tint)
	if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty():
		for index in arrays[Mesh.ARRAY_INDEX]:group.indices.append(offset+index)
	else:
		for index in range(arrays[Mesh.ARRAY_VERTEX].size()):group.indices.append(offset+index)
func box(center: Vector3,size_: Vector3,material: Material,radius: float=0.) -> void:
	if radius<=0.:
		if not shapes.has("box"):
			var unit:=BoxMesh.new();unit.size=Vector3.ONE;shapes["box"]=unit
		add(shapes.box,Transform3D(Basis.from_scale(size_),center),material);return
	var key: String="stair_bevel:"+str(size_)+":"+str(radius)
	if not builder.rounded_cache.has(key):builder.rounded_cache[key]=bevel(size_,radius)
	add(builder.rounded_cache[key],Transform3D(Basis.IDENTITY,center),material)
func capsule(a: Vector3,b: Vector3,radius: float,material: Material) -> void:
	var length_:=a.distance_to(b);var key:=str(length_)+":"+str(radius)
	if not shapes.has(key):
		var shape:=CapsuleMesh.new();shape.radius=radius;shape.height=length_+radius*2.;shape.radial_segments=8;shape.rings=2;shapes[key]=shape
	add(shapes[key],Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5),material)
func finish(parent: Node3D) -> void:
	for group in groups.values():
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=group.vertices;arrays[Mesh.ARRAY_NORMAL]=group.normals;arrays[Mesh.ARRAY_TEX_UV]=group.uv;arrays[Mesh.ARRAY_COLOR]=group.colors;arrays[Mesh.ARRAY_INDEX]=group.indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material:=ShaderMaterial.new();material.shader=HOME;material.set_shader_parameter("tint",Color.WHITE);material.set_shader_parameter("vertex_tint",true);material.set_shader_parameter("pattern",group.pattern);material.set_shader_parameter("roughness_value",group.roughness)
		preload("res://scripts/geometry.gd").mesh(parent,mesh,Vector3.ZERO,material,"StairBatch")
static func bevel(size_: Vector3,radius: float) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var half:=size_*.5;radius=minf(radius,minf(half.x,minf(half.y,half.z))*.85);var inner:=half-Vector3.ONE*radius
	for basis in [Basis(Vector3.RIGHT,Vector3.UP,Vector3.BACK),Basis(Vector3.LEFT,Vector3.UP,Vector3.FORWARD),Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT),Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT),Basis(Vector3.RIGHT,Vector3.BACK,Vector3.DOWN),Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)]:
		var u: Vector3=basis.x;var v: Vector3=basis.y;var n: Vector3=basis.z;var a: float=half.dot(u.abs());var b: float=half.dot(v.abs());var c: float=half.dot(n.abs());var xs: Array=[-a,-a+radius,a-radius,a];var ys: Array=[-b,-b+radius,b-radius,b]
		for y in range(3):
			for x in range(3):
				for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var q: Vector3=u*float(xs[x+corner.x])+v*float(ys[y+corner.y])+n*c;var core:=q.clamp(-inner,inner);var normal: Vector3=(q-core).normalized();st.set_normal(normal);st.set_uv(Vector2(float(xs[x+corner.x]),float(ys[y+corner.y]))/size_.length());st.add_vertex(core+normal*radius)
	return st.commit()
