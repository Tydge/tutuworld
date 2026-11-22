extends RefCounted
const G=preload("res://scripts/geometry.gd")
static var carved: ArrayMesh
static func arm_mesh() -> ArrayMesh:
	if carved:return carved
	# The stepped ends of a gong carry the purlin. Recessed cheeks leave a real contact shadow.
	var rim:=PackedVector2Array([Vector2(-.82,.28),Vector2(.82,.28),Vector2(.82,.17),Vector2(.72,.16),Vector2(.66,.04),Vector2(.49,.04),Vector2(.39,-.09),Vector2(.26,-.09),Vector2(.20,-.27),Vector2(-.20,-.27),Vector2(-.26,-.09),Vector2(-.39,-.09),Vector2(-.49,.04),Vector2(-.66,.04),Vector2(-.72,.16),Vector2(-.82,.17)])
	var tris:=Geometry2D.triangulate_polygon(rim);var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		for i in range(0,tris.size(),3):
			var order: Array=[0,1,2] if side<0 else [0,2,1]
			for j in order:
				var p:=rim[tris[i+j]];st.set_uv(Vector2(p.x/1.64+.5,.49-p.y*1.76));st.add_vertex(Vector3(p.x,p.y,side*.14))
	for j in range(rim.size()):
		var p:=rim[j];var q:=rim[(j+1)%rim.size()]
		for v in [Vector3(p.x,p.y,-.14),Vector3(p.x,p.y,.14),Vector3(q.x,q.y,.14),Vector3(p.x,p.y,-.14),Vector3(q.x,q.y,.14),Vector3(q.x,q.y,-.14)]:
			st.set_uv(Vector2(v.x/1.64+.5,v.z+.5));st.add_vertex(v)
	st.index();st.generate_normals();carved=st.commit();return carved
static func place(n: Node3D,center: Vector3,wood: Material) -> void:
	var base:=G.mesh(n,arm_mesh(),center,wood);base.rotation.y=PI/2;base.scale=Vector3(.86,.85,1.05)
	G.mesh(n,arm_mesh(),center+Vector3(0,.20,.21),wood)
	var top:=G.mesh(n,arm_mesh(),center+Vector3(0,.38,.29),wood);top.rotation.y=PI/2;top.scale=Vector3(.92,.60,1.)
