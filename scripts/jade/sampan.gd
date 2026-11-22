extends RefCounted
## A shallow clinker-built river boat with a curved bamboo awning and a long sculling oar.
const G=preload("res://scripts/geometry.gd")
static func chine(t: float,side: float,band: float) -> Vector3:
	var width:=.075+pow(maxf(0.,1.-t*t),.74)*.99
	return Vector3(side*width*lerpf(.49,1.,band),.10+.68*band+.39*pow(absf(t),3.2),4.05*t)
static func tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for v in [a,b,c]:
		st.set_uv(Vector2(v.z*.57,(v.x+v.y)*.83));st.add_vertex(v)
static func draw(m: Node3D) -> void:
	var art=load("res://scripts/jade/architecture.gd")
	var wood:=StandardMaterial3D.new();wood.albedo_texture=preload("res://assets/terrain/coastal/quay_oak.png");wood.albedo_color=Color("9c8566");wood.roughness=.81;wood.cull_mode=BaseMaterial3D.CULL_DISABLED
	var hull:=SurfaceTool.new();hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var t:=i/8.-1.;var next:=(i+1)/8.-1.
		for side in [-1.,1.]:
			for j in range(4):
				var low:=j*.25;var high:=(j+1)*.25
				var a:=chine(t,side,low);var b:=chine(next,side,low);var c:=chine(next,side,high);var d:=chine(t,side,high)
				tri(hull,a,b,c);tri(hull,a,c,d)
				var rim:=Vector3(side*.014,0,0)
				art.beam(m,c+rim,d+rim,.038 if j<3 else .076,"685741" if j<3 else "836947")
		tri(hull,chine(t,1,0),chine(next,1,0),chine(t,-1,0));tri(hull,chine(next,1,0),chine(next,-1,0),chine(t,-1,0))
	hull.index();hull.generate_normals();G.mesh(m,hull.commit(),Vector3.ZERO,wood)
	for i in range(15):
		var z: float=(i-7)*.45;var w:=chine(z/4.05,1,.45).x
		G.box(m,Vector3(0,.39,z),Vector3(w*1.90,.07,.44),wood)
	for z in [-2.31,-.83,.76,2.35]:G.box(m,Vector3(0,.73,z),Vector3(2*chine(z/4.,1,.83).x,.10,.27),wood)
	var cover:=SurfaceTool.new();cover.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(12):
		var a:=PI*j/12.;var b:=PI*(j+1)/12.
		var l:=Vector3(cos(a)*.94,.88+sin(a)*1.49,-1.24);var r:=Vector3(cos(b)*.94,.88+sin(b)*1.49,-1.24)
		tri(cover,l,r,r+Vector3.BACK*2.75);tri(cover,l,r+Vector3.BACK*2.75,l+Vector3.BACK*2.75)
		for z in [-1.26,.14,1.53]:
			art.beam(m,Vector3(l.x*1.04,l.y+.026,z),Vector3(r.x*1.04,r.y+.026,z),.063,"70553a")
	cover.index();cover.generate_normals()
	var canvas:=art.finish("swallows") as StandardMaterial3D;G.mesh(m,cover.commit(),Vector3.ZERO,canvas)
	art.beam(m,Vector3(-.84,1.44,-2.6),Vector3(1.48,-.15,-3.36),.079,"916e46")
	var paddle:=G.box(m,Vector3(1.32,.005,-3.30),Vector3(.60,.063,.29),wood);paddle.rotation.z=-.53
	art.lantern(m,Vector3(.67,1.48,1.55),.41)
static func make(n: Node3D) -> void:
	var art=load("res://scripts/jade/architecture.gd")
	art.mesh_part(n,"CanalSampan",draw)
